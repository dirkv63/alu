#!/usr/bin/perl
# ==========================================================================
# $Source$
# $Author$ [pauwel]
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

ci_load_data - Load the uCMDB CI's into a mysql database.

=head1 SYNOPSIS

 ci_load_data.pl [OPTIONS] CI_CSV_FILE RELATIONS_CSV_FILE
 ci_load_data.pl [OPTIONS]
 ci_load_data.pl -h    Show script synopsis
 ci_load_data.pl -h 1  Show script synopsis and description of the options
 ci_load_data.pl -h 2  Show all documentation

=head1 DESCRIPTION

This script will load the uCMDB data into a mysql database.
The database must be created with the DDL that was genereted with the script ci_create_ddl.

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

 The default ini-file is the file alu.ini in the properties folder of the current directory.
 This option allows to specify an alternative location of the alu.ini file.

 The alu.ini file should contain a section for the validation database (below is an example):

 [validation]
 server=localhost
 username=demo
 password=Monitor1

 Otherwise the default connection parameters are used (port=3306, server=localhost, username=root and password=Monitor1)

=item B<-d DATABASE, --database=DATABASE>

 change the database name (default is 'validation')

=back

=head1 VERSION HISTORY

version 1.0 12 September 2012 PCO

=over 4

=item *

Initial release.

=back

=cut

use strict;
use Getopt::Long;
use File::Basename;
use File::Glob qw(:glob);
use File::Spec;
use Pod::Usage;			    # Allow Usage information
use Log::Log4perl qw(:easy);
use Text::CSV_XS;

use Spreadsheet::ParseExcel;
use Spreadsheet::ParseExcel::FmtUnicode;
use Spreadsheet::ParseExcel::Utility qw(ExcelFmt ExcelLocaltime);

use IniUtil qw(load_alu_ini);
use CI_Util qw(scan_ci_csv csv_header where_not_exists where_exists);
use DbUtil qw(db_connect do_select do_prepare mysql_datatype_length);

use Data::Dumper;

# ==========================================================================

use vars qw($scriptname $opt_help);
use vars qw($opt_trace);
use vars qw($opt_log);
use vars qw($opt_ini);
use vars qw($opt_database);

# ==========================================================================

$scriptname = basename($0,"");

$| = 1;                         # flush output sooner

Log::Log4perl->easy_init($ERROR);

# ==========================================================================

my @GetOptArgv;
push @GetOptArgv, "trace|t";
push @GetOptArgv, "log|l=s";
push @GetOptArgv, "ini|i=s";
push @GetOptArgv, "database|d=s";
GetOptions("help|h|?:i", @GetOptArgv) or pod2usage();

if (defined $opt_help) {
    if    ($opt_help == 0) { pod2usage(-verbose => 0); }
    elsif ($opt_help == 1) { pod2usage(-verbose => 1); }
    else                   { pod2usage(-verbose => 2); }
}

@ARGV = map { bsd_glob($_, GLOB_NOCHECK | GLOB_NOCASE) } @ARGV if @ARGV;

die "Need two arguments !\n" if @ARGV != 2;

# I believe this file is in code page 1252
my $csv_file = $ARGV[0];
my $relations_csv_file = $ARGV[1];

$opt_trace ? Log::Log4perl->easy_init($DEBUG) : Log::Log4perl->easy_init($ERROR);

# I should put ini-file processing before the logging setup. Ini-file processing is closely related to the processing of the script options.
# By default the ini-file is searched in the current folder and the section is 'DEFAULT'

my $ini_attr;
$ini_attr->{ini_folder} = $opt_ini if ($opt_ini);

my $alu_cfg = load_alu_ini($ini_attr) or do { ERROR("Failed to parse ALU ini-file !"); exit(2) };

# Also ini-file processing must be done before database connect
# For the logging setup, I use the opt_ini parameter, but for the database parameters I don't => this really sucks !

## connect with the database

my $database = ($opt_database) ? $opt_database : 'validation';
my $dbh = db_connect($database) or do { ERROR("Can't connect to the $database database !"); exit(2) };

##
## First load the relations file
##

#my $csv = Text::CSV_XS->new ({ always_quote => 0, blank_is_undef => 0, binary => 1, quote_null => 0, eol => "\n" });
my $csv = Text::CSV_XS->new ({ always_quote => 0, blank_is_undef => 0, binary => 1, quote_null => 0, allow_loose_quotes => 1, eol => "\n" });

unless ($csv) {
    ERROR("".Text::CSV_XS->error_diag());
    die;
}


# load summary table
{
    my $row_count = load_csv($dbh, 'ci_summary', $csv, $csv_file) or do { ERROR("Failed to load the csv file $csv_file !"); die; };

    print "Loaded `$row_count' rows in the ci_summary table.\n";
}


##
## Second load the CIs.csv file
##

my $table_count = load_ci_csv($dbh, $csv, $csv_file) or do { ERROR("Failed to load the csv file $csv_file !"); die; };

print "Loaded `$table_count' tables in the database.\n";

{ 
    my $row_count = load_csv($dbh, 'relations', $csv, $relations_csv_file) or do { ERROR("Failed to load the csv file $relations_csv_file !"); die; };

    print "Loaded `$row_count' rows in the relations table.\n";
}

exit(0);

# ==========================================================================

=pod load_csv

Load a simple csv file in a database table that has a one-to-one column mapping

=cut

sub load_csv {
    my ($dbh, $table, $csv, $file) = @_;

    my $commit_interval = 1000;

    my $file_header = csv_header($file);

    unless (defined $file_header) {
        ERROR("Failed to read HEADER from the csv file `$file' !");
        return;
    }

    my $file_col_count = $#$file_header;

    # Field, Type, Null, Key, Default, Extra
    my $table_col_info = do_select($dbh, "desc `$table`");

    unless ($table_col_info && @$table_col_info) {
        my $database = (map { s/^database=//i; $_ } grep { $_ =~ /^database=/i } split(/;/, $dbh->{Name}))[0];

        ERROR("Failed to get column information of the table $database.$table");
        return;
    }

    # print STDERR Dumper($table_col_info);
    my $i = 0;
    my $htable_col_info = { map { $_->[0] => { NAME =>  $_->[0],
                                               ORDER => $i++,
                                               TYPE => $_->[1],
                                               LENGTH => mysql_datatype_length($_->[1]),
                                               NULL => $_->[2],
                                               KEY => $_->[3],
                                               DEFAULT => $_->[4] } } @$table_col_info };

    #print Dumper($htable_col_info);

    # skip the auto_increment kolommen (zit in Extra)
    my $table_cols = [ map { $_->[0] } grep { $_->[5] !~ m/auto_increment/i } @$table_col_info ];
    #print Dumper($table_cols);

    my $table_col_length = { map { $_->[0] => mysql_datatype_length($_->[1]) } @$table_col_info };
    # print Dumper($table_col_length);

    # vergelijken van de kolommen met de tabel
    my @extra_in_file = where_not_exists($file_header, $table_cols);

    if (@extra_in_file) {
        WARN("CSV file `$file' has extra columns: " . join(', ', @extra_in_file) . " !");
    }

     my @missing_in_file = where_not_exists($table_cols, $file_header);

    if (@missing_in_file) {
        ERROR("CSV file `$file' has missing columns: " . join(', ', @missing_in_file) . " !");
    }

    my @active_cols = where_exists($file_header, $table_cols);

    if (@active_cols == 0) { ERROR("CSV file `$file': no columns left to process !"); return }
    #print STDERR "Active cols : ", Dumper(@active_cols);


    
    # For performance, we make an array of indexes of the columns in the source file that we want to extract
    # The order of the columns must match the above INSERT statement.
    # Additionally we do some checks

    my $column_mapping;
    foreach my $c (@active_cols) {
        # search in file_header
        my $i;
        for ($i = 0; $i <= $#$file_header; $i++) {
            last if ($c eq $file_header->[$i]);
        }

        if ($i > $#$file_header) {
            ERROR("Import `$file' : Column $c not found in the file header. This should not happen !");
            return;
        }

        push @$column_mapping, $i;
    }

    # Check the length of the source data, versus the size of the mysql columns

    my $length_mapping;
    foreach my $fc (@$file_header) {

        my $l = 0;

        foreach my $tc (@active_cols) {
            if ($fc eq $tc) {
                $l = $table_col_length->{$tc};
                last;
            }
        }

        push @$length_mapping, $l;
    }

    #print Dumper($length_mapping);
    
    ##
    ## Start pumping data
    ##

    # SOURCE is the file
    my $ioref = new IO::File;
    $ioref->open("< $file") or do { ERROR("open `$file' failed : $^E"); return; };

    # I believe this file in in code page 1252
    binmode $ioref, ':crlf:encoding(cp1252)';

    # remove header
    $csv->getline($ioref) or do { ERROR("Remove csv header line of `$file' failed : $^E"); return; };
    

    # TARGET is the database
    # prepare statement
    my $stmt = "INSERT INTO `$table` (" . join (', ', map { "`$_`" } @active_cols) . ") VALUES (" . join (', ', map { '?' } @active_cols) . ")";
    my $sth = do_prepare($dbh, $stmt);

    unless ($sth) { ERROR("Import `$file': failed to prepare insert statement !"); return; }

    # Maak de tabel leeg en vul op
    $dbh->do("truncate `$table`") or do { ERROR("Failed to truncate `$table'. Error: " . $dbh->errstr); return };

    # If the table is an InnoDB table, the impact of autocommit on performance is enormous
    my $autocommit = $dbh->{AutoCommit};
    $dbh->{AutoCommit} = 0;

    my $source_row_count = 0;

    while (1) {
        while (my $row = $csv->getline($ioref)) {
            #print "row = ", Dumper($row);

            if ($source_row_count % $commit_interval == 0) {
                $dbh->commit or do { ERROR("Database commit failed !"); return; };
            }

            # check number of columns
            if ($#$row != $file_col_count) {
                ERROR("Import `$file' : Invalid nr of columns (line nr $source_row_count) : " . join(', ', map { defined $_ ? $_ : 'UNDEF' } @$row));
                next;
            }

            
            # lege chars op einde van een veld zijn weg via access => trimmen dus.
            # maar effe niet om te kunnen diffen
            map { $_ && $_=~ s/ *$// } @$row;

            for (my $i = 0; $i <= $#$row; $i++) {
                $row->[$i] = undef if ($row->[$i] eq '');

                my $l = $length_mapping->[$i];
                next unless ($l > 0);

                my $data = $row->[$i];
                next unless defined $data;

                if (length($data) > $l) {
                    my $col = $file_header->[$i];
                    ERROR("Import `$file' : column `$col' is too long (> $l) and will be truncated");
                }
            }

            # pass the data of the file in the correct order
            $sth->execute( map { $row->[$_] } @$column_mapping ) or
                do { ERROR("failed to insert row (line nr $source_row_count) : " . join(', ', map { $_ || 'NULL' } @$row)) };

            $source_row_count++;
        }

        # getline returns undef => either are done or it is an error
        last if ($csv->eof);

        print "ERROR at line $source_row_count: ";
        $csv->error_diag ();

        $source_row_count++;
    }

    $dbh->commit or do { ERROR("Database commit failed !"); return; };
    $dbh->{AutoCommit} = $autocommit;

    my $current_pos = unpack 'I', $ioref->getpos;

    $ioref->seek (0, 2);

    my $end_pos = unpack 'I', $ioref->getpos;

    if ($current_pos != $end_pos) {
        ERROR("CSV file `$csv_file' was not read till the end !");
        $ioref->close;
        return;
    }
    
    $ioref->close;

    return $source_row_count;
}
# ==========================================================================


# ==========================================================================

=pod load_ci_csv

Load a complex csv file in multiple database tables.

=cut

sub load_ci_csv {
    my ($dbh, $csv, $file) = @_;

    my $type_column = 'ci_type';
    my $commit_interval = 1000;

    my $file_header = csv_header($file);

    unless (defined $file_header) {
        ERROR("Failed to read HEADER from the csv file `$file' !");
        return;
    }

    my $file_col_count = $#$file_header;

    my $header_index;
    my $i = 0;
    map { $header_index->{$_} = $i++ } (@$file_header);

    my $type_column_i = $header_index->{$type_column};

    my $csv_info = scan_ci_csv($file) or do { ERROR("Failed to scan the csv file `$file' !"); return };

    my $load_info;
    my $tables = [ sort keys %$csv_info ];

    foreach my $table (@$tables) {
        my $file_cols = [ sort keys %{$csv_info->{$table}{COLS}} ];

        # Field, Type, Null, Key, Default, Extra
        my $table_col_info = do_select($dbh, "desc `$table`");

        unless ($table_col_info && @$table_col_info) {
            my $database = (map { s/^database=//i; $_ } grep { $_ =~ /^database=/i } split(/;/, $dbh->{Name}))[0];

            ERROR("Failed to get column information of the table $database.$table");
            return;
        }

        # print STDERR Dumper($table_col_info);
        my $i = 0;
        my $htable_col_info = { map { $_->[0] => { NAME =>  $_->[0],
                                                   ORDER => $i++,
                                                   TYPE => $_->[1],
                                                   LENGTH => mysql_datatype_length($_->[1]),
                                                   NULL => $_->[2],
                                                   KEY => $_->[3],
                                                   DEFAULT => $_->[4] } } @$table_col_info };

        #print Dumper($htable_col_info);

        # skip the auto_increment kolommen (zit in Extra)
        my $table_cols = [ map { $_->[0] } grep { $_->[5] !~ m/auto_increment/i } @$table_col_info ];
        #print Dumper($table_cols);

        my $table_col_length = { map { $_->[0] => mysql_datatype_length($_->[1]) } @$table_col_info };
        # print Dumper($table_col_length);

        # vergelijken van de kolommen met de tabel
        my @extra_in_file = where_not_exists($file_cols, $table_cols);

        if (@extra_in_file) {
            WARN("CSV file `$file' has extra columns for table `$table': " . join(', ', @extra_in_file) . " !");
        }

        my @missing_in_file = where_not_exists($table_cols, $file_cols);

        if (@missing_in_file) {
            ERROR("CSV file `$file' has missing columns for table `$table': " . join(', ', @missing_in_file) . " !");
        }

        my @active_cols = where_exists($file_header, $table_cols);

        if (@active_cols == 0) { ERROR("CSV file `$file': no columns left to process for table `$table' !"); $load_info->{$table} = undef; next; }

        #print STDERR "Active cols : ", Dumper(@active_cols);

        # For performance, we make an array of indexes of the columns in the source file that we want to extract
        # The order of the columns must match the above INSERT statement.
        # Additionally we do some checks

        my $column_mapping;
        foreach my $c (@active_cols) {
            # search in file_header
            my $i;
            for ($i = 0; $i <= $#$file_header; $i++) {
                last if ($c eq $file_header->[$i]);
            }

            if ($i > $#$file_header) {
                ERROR("Import `$file' : Column $c not found in the file header. This should not happen !");
                return;
            }

            push @$column_mapping, $i;
        }

        $load_info->{$table}{COLUMN_MAPPING} = $column_mapping;

        # Check the length of the source data, versus the size of the mysql columns

        my $length_mapping;
        foreach my $fc (@$file_header) {

            my $l = 0;

            foreach my $tc (@active_cols) {
                if ($fc eq $tc) {
                    $l = $table_col_length->{$tc};
                    last;
                }
            }

            push @$length_mapping, $l;
        }

        #print Dumper($length_mapping);
        $load_info->{$table}{LENGTH_MAPPING} = $length_mapping;

        my $stmt = "INSERT INTO `$table` (" . join (', ', map { "`$_`" } @active_cols) . ") VALUES (" . join (', ', map { '?' } @active_cols) . ")";
        my $sth = do_prepare($dbh, $stmt);

        unless ($sth) { ERROR("Import `$file': failed to prepare insert statement !"); return; }

        $load_info->{$table}{STH} = $sth;
    }


    # Emty the tables before we start loading
    foreach my $table (@$tables) {
        $dbh->do("truncate `$table`") or do { ERROR("Failed to truncate `$table'. Error: " . $dbh->errstr); return };
    }

    ##
    ## Start pumping data
    ##

    # SOURCE is the file
    my $ioref = new IO::File;
    $ioref->open("< $file") or do { ERROR("open `$file' failed : $^E"); return; };

    # I believe this file in in code page 1252
    binmode $ioref, ':crlf:encoding(cp1252)';

    # remove header
    $csv->getline($ioref) or do { ERROR("Remove csv header line of `$file' failed : $^E"); return; };


    
    my $table_row_count;
    my $source_row_count = 0;

    # If the table is an InnoDB table, the impact of autocommit on performance is enormous
    my $autocommit = $dbh->{AutoCommit};
    $dbh->{AutoCommit} = 0;

    while (1) {
        while (my $row = $csv->getline($ioref)) {
            #print "row = ", Dumper($row);

            if ($source_row_count % $commit_interval == 0) {
                $dbh->commit or do { ERROR("Database commit failed !"); return; };
            }

            # check number of columns
            if ($#$row != $file_col_count) {
                ERROR("Import `$file' : Invalid nr of columns (line nr $source_row_count) : " . join(', ', map { defined $_ ? $_ : 'UNDEF' } @$row));
                next;
            }

            my $table = $row->[$type_column_i];
            #print "table = $table\n";

            my $length_mapping = $load_info->{$table}{LENGTH_MAPPING};
            my $column_mapping = $load_info->{$table}{COLUMN_MAPPING};
            my $sth = $load_info->{$table}{STH};

            
            # lege chars op einde van een veld zijn weg via access => trimmen dus.
            # maar effe niet om te kunnen diffen
            map { $_ && $_=~ s/ *$// } @$row;

            for (my $i = 0; $i <= $#$row; $i++) {
                $row->[$i] = undef if ($row->[$i] eq '');

                my $l = $length_mapping->[$i];
                next unless ($l > 0);

                my $data = $row->[$i];
                next unless defined $data;

                if (length($data) > $l) {
                    my $col = $file_header->[$i];
                    ERROR("Import `$file' : column `$table.$col' is too long (> $l) and will be truncated");
                }
            }

            # pass the data of the file in the correct order
            $sth->execute( map { $row->[$_] } @$column_mapping ) or
                do { ERROR("failed to insert row (line nr $source_row_count) : " . join(', ', map { $_ || 'NULL' } @$row)) };

            $source_row_count++;
            $table_row_count->{$table}++;
        }

        # getline returns undef => either are done or it is an error
        last if ($csv->eof);

        print "ERROR at line $source_row_count: ";
        $csv->error_diag ();

        $source_row_count++;
        #$table_row_count->{$table}++;
    }

    $dbh->commit or do { ERROR("Database commit failed !"); return; };
    $dbh->{AutoCommit} = $autocommit;

    my $current_pos = unpack 'I', $ioref->getpos;

    $ioref->seek (0, 2);

    my $end_pos = unpack 'I', $ioref->getpos;

    if ($current_pos != $end_pos) {
        ERROR("CSV file `$csv_file' was not read till the end !");
        $ioref->close;
        return;
    }
    
    $ioref->close;

    
    my $table_count =  keys %{$table_row_count};
    
    print "Loaded $source_row_count rows in $table_count tables\n";

    return $table_count;
}
# ==========================================================================
