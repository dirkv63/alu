#!/usr/bin/perl
# ==========================================================================
# $Source$
# $Author$ [pauwel]
# $Date$
# CDate: Thu Jun 21 16:43:54 2012
# $Revision$
#
# ==========================================================================
#
# ident "$Id$"
#
# ==========================================================================

=pod

Laden van esl csv files in de alu_cmdb database.
Tabellen moeten bestaan (daarmee kan ik de kolom headers checken)

Validatie van het aantal rijen.
Toevoegen van de info in de alu_snapshot tabel

- welke file geladen
- wanneer
- ook data log en summary log
- max lengte van kolommen.


Wat betreft de data en de charsets:
- Inlezen in binmode geeft een beter resultaat dan met access
- ik denk dat sommige kolommen latin1 data bevatten en sommige kolommen bevatten UTF-8 data


=cut

use strict;
use Encode;
use Encode::Guess qw/UTF-8 ISO-8859-1/;
use Getopt::Long;
use File::Basename;
use File::Glob qw(:glob);
use File::Spec;
use Log::Log4perl qw(:easy);
use Text::CSV_XS;
use IniUtil qw(load_alu_ini);
use ALU_Util qw(normalize_file_column_names validate_row_count);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_select do_prepare mysql_datatype_length);
use Set qw(where_not_exists where_exists);
use WorkFlow qw(read_ESL_SOURCE);

use Data::Dumper;

# ==========================================================================

use vars qw($scriptname $opt_help);
use vars qw($opt_verbose);
use vars qw($opt_file);
use vars qw($opt_ini);
use vars qw($opt_database);

sub usage
{
  die "@_" . "Try '$scriptname -h' for more information\n" if @_;

  die "Usage:
   $scriptname [OPTION] RUN

  --help|-h            display this help and exit

  --verbose|-v         increase level of verbosity (can be repeated)
  --file|-f FILE       only process this file
  --ini|-i DIR         alternative location of the ini files (normally in the properties folder of
                       the current directory)
  --database|-d DB     change the database name (default alu_cmdb)

Load incoming ESL files. RUN is the symbolic name for the specific run, that can be found
in the ini file. This way we find the source files.
";
}

# ==========================================================================

$scriptname = basename($0,"");

$| = 1;                         # flush output sooner

# ==========================================================================

my @GetOptArgv;
push @GetOptArgv, "verbose|v+";
push @GetOptArgv, "ini|i=s";
push @GetOptArgv, "file|f=s";
push @GetOptArgv, "database|d=s";
GetOptions("help|h|?", @GetOptArgv) or usage "Illegal option : ";

usage if $main::opt_help;

@ARGV = map { bsd_glob($_, GLOB_NOCHECK | GLOB_NOCASE) } @ARGV if @ARGV;

# XXX usage "Need at least one argument !\n" if @ARGV < 1;
usage "Need one argument !\n" if @ARGV != 1;

my $run = $ARGV[0];

Log::Log4perl->easy_init($ERROR);

## Read the alu.ini file
my $ini_attr;
$ini_attr->{ini_folder} = $opt_ini if ($opt_ini);
my $alu_cfg = load_alu_ini($ini_attr) or do { ERROR("Failed to parse ALU ini-file !"); exit(2) };

my $database = ($opt_database) ? $opt_database : 'alu_cmdb';

my $level = 0;
$level += $opt_verbose if ($opt_verbose);

my $attr = { level => $level };
$attr->{ini_section} = $run;

setup_logging($attr);

my $summary_log = Log::Log4perl->get_logger('Summary');
my $data_log = Log::Log4perl->get_logger('Data');

# ==========================================================================

$summary_log->info("Importing ESL files in the $database database");

## Read from the alu.ini file
unless ($alu_cfg->SectionExists($run)) { ERROR("Run `$run' does not exists in alu.ini !"); exit(2); }
my $ds_step = $alu_cfg->val($run, 'DS_STEP1') or do { ERROR("DS_STEP1 missing in [$run] section in alu.ini !"); exit(2) };

my $esl_info = read_ESL_SOURCE();

# connect with the database
my $dbs = db_connect($database) or do { ERROR("Can't connect to the $database database !"); exit(2) };

my $err_cnt = 0;

foreach my $esl_item (@$esl_info) {
    my ($table, $file, $charset, $expected_row_count) = map { $esl_item->{$_} } qw(Table File CharSet RowCount);

    if ($opt_file) {
        next unless ($file eq $opt_file);
    }

    $file .= '.csv' unless ($file =~ m/\.csv$/i);

    $file = File::Spec->catfile($ds_step, $file);

    my $bfile = basename($file);

    $summary_log->info("Importing `$bfile' in the $database database");

    # lees de CSV file in
    my $ioref = new IO::File;

    unless ($ioref->open("< $file")) {
        ERROR("open `$file' failed : $^E");
        $err_cnt++;
        next;
    }

    my $csv = Text::CSV_XS->new ({ always_quote => 1, blank_is_undef => 1, empty_is_undef => 1, binary => 1, quote_null => 0, eol => "\n" })
        or die "".Text::CSV_XS->error_diag ();

    if ($charset eq 'UTF-8') {
        binmode $ioref, ':crlf :encoding(UTF-8)';
    }
    elsif ($charset eq 'ISO-8859-1') {
        binmode $ioref, ':crlf :encoding(ISO-8859-1)';
    }
    elsif ($charset eq 'BIN') {
        binmode $ioref, ':crlf';
    }
    else {
        ERROR("Unknown character set `$charset'. Using UTF-8 !");
        binmode $ioref, ':crlf :encoding(UTF-8)';
    }

    # direct de header lezen ?

    my $file_cols = $csv->getline($ioref);

    # laatste kolom is telkens undef (er staat een komma teveel)
    if (defined $file_cols->[-1]) {
        $data_log->warn("Import `$bfile' : last character of the line is expected to be a ',', but it's not !");
    }

    pop @$file_cols unless defined $file_cols->[-1];

    # soms heeft de file duplicate columns of te lange column names
    my $normalized_file_cols = normalize_file_column_names($file_cols);

    my $file_col_count = $#$file_cols;

    # Field, Type, Null, Key, Default, Extra
    my $table_col_info = do_select($dbs, "desc $table");
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
    $dbs->do("truncate $table") or do { ERROR("Failed to truncate `$table'. Error: " . $dbs->errstr); $err_cnt++; next };

    my @active_cols = where_exists($file_cols, $table_cols);

    if (@active_cols == 0) { ERROR("Import `$bfile': no columns left to process !"); ; $err_cnt++; next }

    # prepare statement
    my $sth = do_prepare($dbs, "INSERT INTO $table (" . join (', ', map { "`$_`" } @active_cols) . ") VALUES (" . join (', ', map { '?' } @active_cols) . ")");

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
        pop @$source_row unless defined $source_row->[-1];

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
            $data_log->error("Import `$bfile' : Invalid nr of columns (line nr $source_row_count) : " . join(', ', @$source_row));
            next;
        }

        # lege chars op einde van een veld zijn weg via access => trimmen dus.
        # But sometimes the fields end with a CR-LF
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

