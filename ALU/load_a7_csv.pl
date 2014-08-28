#!/usr/bin/perl
# ==========================================================================
# $Source$
# $Author$ [philip]
# $Date$
# CDate: Wed Jul 4 08:53:54 2012
# $Revision$
#
# ==========================================================================
#
# ident "$Id$"
#
# ==========================================================================

=pod

=head1 NAME

load_a7_csv - Load asset center files in the alu_cmdb database

=head1 SYNOPSIS

 load_a7_csv.pl [OPTIONS] RUN
 load_a7_csv.pl [OPTIONS] 
 load_a7_csv.pl -h    Show script synopsis
 load_a7_csv.pl -h 1  Show script synopsis and description of the options
 load_a7_csv.pl -h 2  Show all documentation

=head1 DESCRIPTION

This script will load asset center files in the alu_cmdb database. The asset center files are *.xlsx
files. To load the files with this script, they have to be converted to *.csv files first. To do
this perform a 'Save As' *.csv from excel. This only works with excel workbooks that have only one
sheet. This is the case for the asset center files, so no problem here.

The reason to use *.csv files instead of *.xls files is that the *.xls file format is limited to
65536 rows. There is currently one asset center file (*ALL_RELATIONSHIP.xlsl) that has too many rows
and that must be loaded with this script.

If two parameters are given, the RUN parameters refers to the section of the alu.ini file where we look
for the parameter DS_STEP1. This parameters refers to the directory where the csv file resides.
If one parameter is given, the DEFAULT section of the alu.ini file is used.

The name of the table comes from the WorkFlow.xls sheet

The mysql tables must exist. This is used to check the columns in the sheet versus the columns in the table.

Default behaviour is to truncate the data in the existing table first.

=head1 OPTIONS

=over 4

=item B<-h [VERBOSE_LEVEL], --help[=VERBOSE_LEVEL]>

 -h    Usage
 -h 1  Usage and description of the options
 -h 2  All documentation

=item B<-t, --trace>

 Tracing enabled, default: no tracing

=item B<-l LOGDIR, --log=LOGDIR>

 default: d:\temp\log

=item B<-i DIR, --ini=DIR>

 alternative location of the ini files (normally in the properties folder of the current directory)

=item B<-d DATABASE, --database=DATABASE>

 change the database name (default is 'alu_cmdb')

=item B<-m, --merge>

 See MERGE

=back

=head1 MERGE

An option to merge the data from the sheet with the data from the table could be added : To merge,
we have to know the key columns of the table. Still need to figure out where/how to get this
information.

=head1 VERSION HISTORY

version 1.0 21 August 2012 PCO

=over 4

=item *

Initial release.

=back

=cut

use strict;
use Encode;
use Encode::Guess qw/UTF-8 ISO-8859-1/;
use Getopt::Long;
use File::Basename;
use File::Glob qw(:glob);
use File::Spec;
use Pod::Usage;			    # Allow Usage information
use Log::Log4perl qw(:easy);
use Text::CSV_XS;
use IniUtil qw(load_alu_ini);
use LogUtil qw(setup_logging);
use ALU_Util qw(normalize_file_column_names validate_row_count glob2pat);
use DbUtil qw(db_connect do_select do_prepare mysql_datatype_length);
use Set qw(where_not_exists where_exists);
use WorkFlow qw(read_A7_SOURCE);
use XlsUtil qw(tabglob2tab small_cell_handler import_sheet);

use Data::Dumper;

# ==========================================================================

use vars qw($scriptname $opt_help);
use vars qw($opt_trace);
use vars qw($opt_log);
use vars qw($opt_ini);
use vars qw($opt_database);
use vars qw($opt_merge);

# ==========================================================================

$scriptname = basename($0,"");

$| = 1;                         # flush output sooner

# ==========================================================================

my @GetOptArgv;
push @GetOptArgv, "trace|t";
push @GetOptArgv, "log|l=s";
push @GetOptArgv, "ini|i=s";
push @GetOptArgv, "database|d=s";
push @GetOptArgv, "merge|m";
GetOptions("help|h|?:i", @GetOptArgv) or pod2usage();

if (defined $opt_help) {
    if    ($opt_help == 0) { pod2usage(-verbose => 0); }
    elsif ($opt_help == 1) { pod2usage(-verbose => 1); }
    else                   { pod2usage(-verbose => 2); }
}

@ARGV = map { bsd_glob($_, GLOB_NOCHECK | GLOB_NOCASE) } @ARGV if @ARGV;

my $run;

if (@ARGV == 0) {
    $run = 'DEFAULT';
}
elsif (@ARGV == 1) {
    $run = $ARGV[0];
}
else {
    pod2usage("Need one or two arguments !\n");
}

$opt_trace ? Log::Log4perl->easy_init($DEBUG) : Log::Log4perl->easy_init($ERROR);

pod2usage("Merge option not supported (yet) !\n") if ($opt_merge);

# I should put ini-file processing before the logging setup. Ini-file processing is closely related to the processing of the script options.
# By default the ini-file is searched in the current folder and the section is 'DEFAULT'

my $ini_attr;
$ini_attr->{ini_folder} = $opt_ini if ($opt_ini);

my $alu_cfg = load_alu_ini($ini_attr) or do { ERROR("Failed to parse ALU ini-file !"); exit(2) };

# Also ini-file processing must be done before database connect
# For the logging setup, I use the opt_ini parameter, but for the database parameters I don't => this really sucks !

my $database = ($opt_database) ? $opt_database : 'alu_cmdb';

my $level = 0;
$level = 3 if ($opt_trace);

my $attr = { level => $level };
$attr->{ini_section} = $run;

setup_logging($attr);

my $summary_log = Log::Log4perl->get_logger('Summary');
my $data_log = Log::Log4perl->get_logger('Data');

# ==========================================================================

$summary_log->info("Importing asset center (csv) files in the $database database");

## Read from the alu.ini file
unless ($alu_cfg->SectionExists($run)) { ERROR("Run `$run' does not exists in alu.ini !"); exit(2); }
my $ds_step = $alu_cfg->val($run, 'DS_STEP1') or do { ERROR("DS_STEP1 missing in [$run] section in alu.ini !"); exit(2) };

my $opt_file;
my $a7_info = read_A7_SOURCE();

# connect with the database
my $dbh = db_connect($database) or do { ERROR("Can't connect to the $database database !"); exit(2) };

my $err_cnt = 0;

my $wanted_tables;

foreach my $a7_item (@$a7_info) {
    my ($table, $file, $charset, $expected_row_count) = map { $a7_item->{$_} } qw(Table File CharSet RowCount);

    # filter away xls files or (more correctly) only keep csv files
    next unless ($file =~ m/csv/i);

    # File is a file pattern (eg. Database CI Report on *.csv)

    # Beware, the tab name is a glob expression too
    my $csv_glob = $file;

    # filtering is done with a glob.
    if ($opt_file) {
        my $re = glob2pat($opt_file);
        next unless ($csv_glob =~ qr/$re/);
    }

    $wanted_tables->{$csv_glob} = [ $table, $charset, $expected_row_count ];
}

if (keys %$wanted_tables < 1) { ERROR("No file matching the file pattern `$opt_file' found in WorkFlow.xls !"); exit(2); };

foreach my $csv_glob (sort keys %$wanted_tables) {
    # csv is a shell wildcard pattern (glob it)

    my $file_pattern = File::Spec->catfile($ds_step, $csv_glob);

    my @files = map { bsd_glob($_, GLOB_NOCHECK | GLOB_NOCASE) } ($file_pattern);

    if (@files > 1) { ERROR("Multiple files matching the file pattern `$file_pattern' (" . join(', ', @files) . ") !"); $err_cnt++; next; };
    if (@files < 1) { ERROR("No file matching the file pattern `$file_pattern' !"); $err_cnt++; next; };

    my $csv_file = $files[0];
    my $bfile = basename($csv_file);

    my ($table, $charset, $expected_row_count) = @{ $wanted_tables->{$csv_glob} };

    $summary_log->info("Importing `$bfile' in the $database.$table table");

    # lees de CSV file in
    my $ioref = new IO::File;

    unless ($ioref->open("< $csv_file")) {
        ERROR("open `$csv_file' failed : $^E");
        $err_cnt++;
        next;
    }

    my $csv = Text::CSV_XS->new ({ always_quote => 1, blank_is_undef => 1, empty_is_undef => 1, binary => 1, quote_null => 0, eol => "\n", sep_char => ';' })
        or die "".Text::CSV_XS->error_diag ();

    if ($charset eq 'UTF-8') {
        binmode $ioref, ':encoding(UTF-8)';
    }
    elsif ($charset eq 'ISO-8859-1') {
        binmode $ioref, ':encoding(ISO-8859-1)';
    }
    elsif ($charset eq 'BIN') {
        binmode $ioref;
    }
    else {
        ERROR("Unknown character set `$charset'. Using UTF-8 !");
        binmode $ioref, ':encoding(UTF-8)';
    }

    # direct de header lezen ?

    my $file_cols = $csv->getline($ioref);

    # soms heeft de file duplicate columns of te lange column names
    my $normalized_file_cols = normalize_file_column_names($file_cols);

    my $file_col_count = $#$file_cols;

    # Field, Type, Null, Key, Default, Extra
    my $table_col_info = do_select($dbh, "desc $table");
    #print Dumper($table_col_info);

    unless ($table_col_info && @$table_col_info) {
        ERROR("Failed to get column information of the table $database.$table");
        $err_cnt++;
        next;
    }

    # skip the auto_increment kolommen (zit in Extra)
    my $table_cols = [ map { $_->[0] } grep { $_->[5] !~ m/auto_increment/i } @$table_col_info ];

    #print Dumper($table_cols);

    my $table_col_length = { map { $_->[0] => mysql_datatype_length($_->[1]) } @$table_col_info };

    # print Dumper($table_col_length);

    # vergelijken van de kolommen met de tabel
    my @extra_in_file = where_not_exists($normalized_file_cols, $table_cols);

    if (@extra_in_file) {
        $data_log->warn("Import `$bfile' has extra columns: " . join(', ', @extra_in_file) . " !");
    }

    my @missing_in_file = where_not_exists($table_cols, $normalized_file_cols);

    if (@missing_in_file) {
        $data_log->error("Import `$bfile' has missing columns: " . join(', ', @missing_in_file) . " !");
    }

    # Maak de tabel leeg en vul op
    $dbh->do("truncate $table") or do { ERROR("Failed to truncate `$table'. Error: " . $dbh->errstr); $err_cnt++; next };

    my @active_cols = where_exists($file_cols, $table_cols);

    if (@active_cols == 0) { ERROR("Import `$bfile': no columns left to process !"); ; $err_cnt++; next }

    # prepare statement
    my $sth = do_prepare($dbh, "INSERT INTO $table (" . join (', ', map { "`$_`" } @active_cols) . ") VALUES (" . join (', ', map { '?' } @active_cols) . ")");

    unless ($sth) { ERROR("Import `$bfile': failed to prepare insert statement !"); ; $err_cnt++; next }

    # For performance, we make an array of indexes of the columns in the source file that we want to extract
    # The order of the columns must match the above INSERT statement.
    # Additionally we do some checks

    my $column_mapping;
    foreach my $c (@active_cols) {
        # search in normalized_file_cols
        my $i;
        for ($i = 0; $i <= $#$normalized_file_cols; $i++) {
            last if ($c eq $normalized_file_cols->[$i]);
        }

        if ($i > $#$normalized_file_cols) {
            ERROR("Import `$bfile' : Column $c not found in the normalized file columns. This should not happen !");
            die;
        }

        push @$column_mapping, $i;
    }

    # Check the length of the source data, versus the size of the mysql columns

    my @length_mapping;
    foreach my $fc (@$normalized_file_cols) {

        my $l = 0;

        foreach my $tc (@active_cols) {
            if ($fc eq $tc) {
                $l = $table_col_length->{$tc};
                last;
            }
        }

        push @length_mapping, $l;
    }

    #print Dumper(@length_mapping);

    my $source_row_count = 0;

    while (my $source_row = $csv->getline($ioref)) {
        #print Dumper($source_row);

        if ($charset eq 'BIN') {
            # de logica is speciaal : als guess niet kan bepalen of het UTF-8 of ISO-8859-1 is, dan ga ik ervan uit dat het UTF-8 is
            for (my $i = 0; $i <= $#$source_row; $i++) {
                my $data = $source_row->[$i];
                next unless defined $data;
                next if ($data eq '');

                next if ($data =~ m/^[[:ascii:]]*$/s);

                my $decoder = Encode::Guess->guess($data);

                if (ref($decoder)) {
                    $source_row->[$i] = $decoder->decode($data);
                }
                elsif ($decoder eq "utf-8-strict or iso-8859-1 or utf8") {
                    # neem dan UTF-8
                    $source_row->[$i] = decode( 'UTF-8', $data, Encode::FB_CROAK);
                }
                else {
                    print Dumper($data);
                    die $decoder;
                }

            }
        }

        # check aantal cols
        if ($#$source_row != $file_col_count) {
            $data_log->error("Import `$bfile' : Invalid nr of columns (line nr $source_row_count) : " . join(', ', map { defined $_ ? $_ : 'UNDEF' } @$source_row));
            next;
        }

        # lege chars op einde van een veld zijn weg via access => trimmen dus.
        # maar effe niet om te kunnen diffen
        map { $_ && $_=~ s/ *$// } @$source_row;

        for (my $i = 0; $i <= $#$source_row; $i++) {
            my $l = $length_mapping[$i];
            next unless ($l > 0);

            my $data = $source_row->[$i];
            next unless defined $data;

            if (length($data) >= $l) {

                my $col = $normalized_file_cols->[$i];
                $data_log->error("Import `$bfile' : column `$col' is too long (> $l) and will be truncated");
            }
        }

        # pass the data of the file in the correct order
        $sth->execute( map { $source_row->[$_] } @$column_mapping ) or
            do { ERROR("failed to insert row (line nr $source_row_count) : " . join(', ', map { $_ || 'NULL' } @$source_row)) };

        $source_row_count++;
    }





    # vergelijken van het aantal verwachte rijen.

    unless (validate_row_count($expected_row_count, $source_row_count)) {
        $data_log->warn("CSV file `$bfile' has an invalid number of rows ($source_row_count). Expected $expected_row_count rows !\n");
    }
    else {
        $data_log->info("Imported $source_row_count rows (expected about $expected_row_count rows)");
    }

    $summary_log->info("Import `$bfile' finished.");
}

# ==========================================================================

__END__

