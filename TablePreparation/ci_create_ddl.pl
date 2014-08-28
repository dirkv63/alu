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

ci_create_ddl - create a DDL for storing the uCMDB CI's into a mysql database.

=head1 SYNOPSIS

 ci_create_ddl.pl [OPTIONS] XLS_FILE CI_CSV_FILE RELATIONS_CSV_FILE
 ci_create_ddl.pl [OPTIONS]
 ci_create_ddl.pl -h    Show script synopsis
 ci_create_ddl.pl -h 1  Show script synopsis and description of the options
 ci_create_ddl.pl -h 2  Show all documentation

=head1 DESCRIPTION

This script gets information from the following sources and makes a DDL file:
- The sheet "ALU Specific uCMDB Attribute Specification v1_30 Final.xls"
- The CIs.csv file

Both sources are compared and mismatches are reported. A set of DDL statements is generated.
that can be loaded into a database. Afterwards the data can be loaded with the script ci_load_data.pl.

This script can not read an .xlsx sheet, so if needed convert the excel sheet beforehand.

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

=back

=head1 VERSION HISTORY

version 1.0 12 September 2012 PCO

=over 4

=item *

Initial release.

=back

=cut

use feature "state";
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

use CI_Util qw(scan_ci_csv csv_header get_xls_column_number subtract_array where_exists duplicates);
use Scalar::Util qw(looks_like_number);

use Data::Dumper;

# ==========================================================================

use vars qw($scriptname $opt_help);
use vars qw($opt_trace);
use vars qw($opt_log);
use vars qw($opt_ini);

# ==========================================================================

my $database = 'validation';

my $ci_summary = [ 'ci_type', 'cmdb_id', 'data_description', 'data_externalid',
                   'sm_data_technical_owner', 'data_name', 'data_origin',
                   'rde_data_solution_lead_email', 'rde_data_solution_lead_details',
                   'sm_data_sourcing_accountable', 'sm_data_slo_group_enum' ];

$scriptname = basename($0,"");

$| = 1;                         # flush output sooner

Log::Log4perl->easy_init($ERROR);

# ==========================================================================

my @GetOptArgv;
push @GetOptArgv, "trace|t";
push @GetOptArgv, "log|l=s";
push @GetOptArgv, "ini|i=s";
GetOptions("help|h|?:i", @GetOptArgv) or pod2usage();

if (defined $opt_help) {
    if    ($opt_help == 0) { pod2usage(-verbose => 0); }
    elsif ($opt_help == 1) { pod2usage(-verbose => 1); }
    else                   { pod2usage(-verbose => 2); }
}

@ARGV = map { bsd_glob($_, GLOB_NOCHECK | GLOB_NOCASE) } @ARGV if @ARGV;

die "Need three arguments !\n" if @ARGV != 3;

my $xls_file = $ARGV[0];
my $csv_file = $ARGV[1];
my $relations_csv_file = $ARGV[2];

my $relations_header = csv_header($relations_csv_file) or do { ERROR("Failed to get the header of the csv file `$relations_csv_file' !"); die };
#print STDERR Dumper($relations_header);

my $csv_header = csv_header($csv_file) or do { ERROR("Failed to get the header of the csv file `$csv_file' !"); die };
#print STDERR Dumper($csv_header);

if (my @tmp = duplicates($csv_header)) {
    print STDERR "WARNING: The csv file `$csv_file' has duplicate column names: ", join(', ', @tmp), "\n";
}
# XXX TODO : remove duplicate columns from header

##
## Compare subset of CI columns and CSV
##

{
    my $extra_subset = subtract_array($ci_summary, $csv_header);

    if (@$extra_subset) {
        print STDERR "WARNING: The following columns are requested in the summary, but are not available in the CSV : ", join(', ', @$extra_subset), "\n";

        $ci_summary = subtract_array($ci_summary, $extra_subset);
    }
}

##
## Read the csv file to determine tables, column types and lengths
##

my $csv_info = scan_ci_csv($csv_file) or do { ERROR("Failed to scan the csv file `$csv_file' !"); die };
#print STDERR Dumper($csv_info);

# csv_info has length of columns per type
# consolidate these lengths for the ci_summary table

my $ci_all_info;

foreach my $ci_type (sort keys %$csv_info) {
    foreach my $col (sort keys %{$csv_info->{$ci_type}{COLS}}) {
        my $max_len = $csv_info->{$ci_type}{COLS}{$col}[1];

        $ci_all_info->{$col} = 0 unless (exists $ci_all_info->{$col});
        if ($max_len > $ci_all_info->{$col}) {
            $ci_all_info->{$col} = $max_len;
        }
    }
}

##
## Read the sheet 
##

unless (-f $xls_file) {
    ERROR("The excel sheet `$xls_file' does not exists !");
    die;
}

my $tab = 'XML Attrib\'s by CIT';
my $xls_colums1 = 'CiTechInternal';
my $xls_colums2 = [ 'Attribute Tech Name', 'Attribute Type', 'Value Size', 'Reporting Req' ];

my $oFmt = new Spreadsheet::ParseExcel::FmtUnicode or croak("ERROR: can't lauch Formatter !\n");

my $parser = Spreadsheet::ParseExcel->new();

my $workbook = $parser->parse($xls_file, $oFmt);

if ( !defined $workbook ) {
    ERROR("Failed to parse the excel sheet: ", $parser->error());
    die;
}

my $sheet;

for my $worksheet ( $workbook->worksheets() ) {
  next unless ($worksheet->get_name() eq $tab);
  $sheet = $worksheet;
}

unless (defined $sheet) {
  ERROR("The sheet `$tab' is not found in $xls_file !");
  die;
}

my ($xls_colums_idx1, $xls_colums_idx2);

$xls_colums_idx1 = get_xls_column_number($sheet, $xls_colums1);

foreach my $c (@$xls_colums2) {
  push @$xls_colums_idx2, get_xls_column_number($sheet, $c);
}

my $xls_info;

my ( $row_min, $row_max ) = $sheet->row_range();

for my $iR ( $row_min + 1 .. $row_max ) {

  my $ci = $sheet->get_cell( $iR, $xls_colums_idx1 )->value();

  my $row;
  for my $col (@$xls_colums_idx2) {

    my $cell = $sheet->get_cell( $iR, $col );

    push @$row, ($cell ? $cell->value() : undef);
  }

  #[ 'Attribute Tech Name', 'Attribute Type', 'Value Size', 'Reporting Req' ];

  # XXX An error in the name from the sheet and the name from the csv : cmdbid <=> cmdb_id
  if ($row->[0] eq 'cmdbid') {

      state $first_time = 1;
      print STDERR "WARNING: The column cmdbid form the sheet is called cmdb_id in the csv !\n" if ($first_time);
      $first_time = 0;

      $row->[0] = 'cmdb_id';
  }

  push @{ $xls_info->{$ci} }, $row;
}

#print STDERR Dumper($xls_info);

##
## Compare CSV and XLS definitions
##

# 1) compare ci types (tables)

my $xls_ci_types = [ sort keys %$xls_info ];
my $csv_ci_types = [ sort keys %$csv_info ];

my $extra_xls = subtract_array($xls_ci_types, $csv_ci_types);
my $extra_csv = subtract_array($csv_ci_types, $xls_ci_types);

if (@$extra_xls) {
    print STDERR "WARNING: The following ci_types are defined in the XLS but are not available in the CSV : ", join(', ', @$extra_xls), "\n";
}

if (@$extra_csv) {
    print STDERR "WARNING: The following ci_types are defined in the CSV but are not available in the XLS : ", join(', ', @$extra_csv), "\n";
}

# 2) compare column definitions

foreach my $ci_type (sort keys %$csv_info) {

    next unless exists $xls_info->{$ci_type};

    #print STDERR "Processing ci type $ci_type ...\n";

    my $xls_ci_info = $xls_info->{$ci_type};
    my $csv_ci_info = $csv_info->{$ci_type};

    my $xls_all_cols = [ map { $_->[0] } @$xls_ci_info ];

    my $cnt = {};
    map { $cnt->{$_}++ } @$xls_all_cols;

    my @double_cols = grep { $cnt->{$_} > 1; } @$xls_all_cols;
    if (@double_cols) {
        print STDERR "ERROR: in the XLS sheet the following column(s) are specified multiple times for ci type `$ci_type' : ", join(', ', @double_cols), "\n";
    }

    # The columns that should be exported
    my $xls_X_cols = [ map { $_->[0] } grep { defined $_->[3] && $_->[3] =~ m/X/i } @$xls_ci_info ];

    # The columns that are NOT exported
    my $xls_NX_cols = subtract_array($xls_all_cols, $xls_X_cols);

    my $csv_cols = [ sort keys %{$csv_ci_info->{COLS}} ];

    my $extra_xls_cols = subtract_array($xls_X_cols, $csv_cols);
    my $extra_csv_cols = subtract_array($csv_cols, $xls_X_cols);

    # A number of columns are marked for export in the XLS, but have no data in the CSV file. This
    # could be, because there is no data in uCMDB for this column, so there is no data in the csv.
    # We could create these columns in the DDL (but they will remain empty).
    # => $extra_xls_cols is not empty. Don't mention it

    # XXX add extra_xls_cols in the DDL ?

    if (@$extra_csv_cols) {
        print STDERR "WARNING: The following columns for ci type `$ci_type' have data in the CSV but are not available in the XLS : ", join(', ', @$extra_csv_cols), "\n";

        # maybe these extra columns should not be exported
        my @tmp = where_exists($extra_csv_cols, $xls_NX_cols);

        if (@tmp) {
            print STDERR "          and these columns should not have been exported : ", join(', ', @tmp), "\n";
        }
    }

    # 3) Compare length and data type

    foreach my $col (sort keys %{$csv_ci_info->{COLS}}) {

        my @xls_col_info = grep { $_->[0] eq $col } @$xls_ci_info;
        next unless (@xls_col_info);

        my $csv_col_info = $csv_ci_info->{COLS}{$col};
        my $xls_col_info = $xls_col_info[0];

        my $max_len = $csv_col_info->[1];

        my $type = $xls_col_info->[1];
        my $type_len = $xls_col_info->[2];

        $type_len = '' unless (defined $type_len);

        if (length($type_len) > 0) {
            unless (looks_like_number($type_len)) {
                print STDERR "ERROR: XLS length defined for $ci_type.$col is not a number : $type_len !\n";
                $type_len = $max_len;
            }
        }

        # silly length
        if (length($type_len) > 0 && $type_len > 32000) {
            print STDERR "ERROR: XLS length for $ci_type.$col is ridiculously large : $type_len !\n";
            $type_len = '';
        }

        # Compare sheet definitions with the real data

        if    ($type =~ m/^string$/i)  { $type_len = 0   if ($type_len eq ''); }
        # containes the string 'true' or 'false'
        elsif ($type =~ m/^boolean$/i) { $type_len = 5   if ($type_len eq ''); } # 'false' 
        elsif ($type =~ m/^integer$/i) { $type_len = 9   if ($type_len eq ''); } # int32 => 9 posities
        # no idea if it is a blob or a number
        elsif ($type =~ m/^long$/i)    { $type_len = 255 if ($type_len eq ''); }
        elsif ($type =~ m/^date$/i)    { $type_len = 19  if ($type_len eq ''); }
        elsif ($type =~ m/_enum$/i)    { $type_len = $max_len if ($type_len eq ''); }
        else {
            print STDERR "ERROR: Unknown XLS type definition for $ci_type.$col: $type !\n";
            print STDERR Dumper($xls_col_info);

            $type_len = 0 if ($type_len eq '');
        }

        my $len = $type_len;
        if ($type_len < $max_len) {
            print STDERR "ERROR: XLS length definition for $ci_type.$col ($type) is too small : $type_len needs to be $max_len !\n";
            $len = $max_len;
        }

        if    ($type =~ m/^string$/i)  { $csv_col_info->[2] = "VARCHAR($len)"; }
        # containes the string 'true' or 'false'
        elsif ($type =~ m/^boolean$/i) { $csv_col_info->[2] = "VARCHAR($len)"; }
        elsif ($type =~ m/^integer$/i) { $csv_col_info->[2] = "INT($len)"; }
        # no idea if it is a blob or a number
        elsif ($type =~ m/^long$/i)    { $csv_col_info->[2] = "VARCHAR($len)"; }
        # Don't know what to do here if length is wrong
        elsif ($type =~ m/^date$/i)    { $csv_col_info->[2] = "DATETIME"; }
        elsif ($type =~ m/_enum$/i)    { $csv_col_info->[2] = "VARCHAR($len)"; }
        else                           { $csv_col_info->[2] = "VARCHAR($len)"; }
    }
}



##
## make DDL
##

print "DROP DATABASE IF EXISTS $database;

SET character_set_client = utf8;

CREATE DATABASE $database
  DEFAULT CHARACTER SET utf8
  DEFAULT COLLATE utf8_general_ci;
  
USE `$database`;

";

{
    print "-- ci_summary\n";
    print "CREATE TABLE `ci_summary` (\n";

    my $id = 0;
    my $firstcol = 1;
    foreach my $col (@$ci_summary) {
        $id = 1 if ($col eq 'cmdb_id');

        print ",\n" unless ($firstcol);
        $firstcol = 0;

        my $l = $ci_all_info->{$col} || 255;
    
        print "  `$col` VARCHAR($l) DEFAULT NULL";
    }

    print ",\n  PRIMARY KEY (cmdb_id)" if $id;
    print "\n) ENGINE=MyISAM DEFAULT CHARSET=utf8;\n";
    print "\n";
    print "SHOW WARNINGS;\n";
    print "COMMIT;\n";
    print "SELECT \"Table ci_summary created.\";\n";
    print "\n";
}

{
    print "-- relations\n";
    print "CREATE TABLE `relations` (\n";
    
    my $firstcol = 1;
    foreach my $col (@$relations_header) {
        print ",\n" unless ($firstcol);
        $firstcol = 0;
        
        print "  `$col` VARCHAR(255) DEFAULT NULL";
    }
    
    print "\n) ENGINE=MyISAM DEFAULT CHARSET=utf8;\n";
    print "\n";
    print "SHOW WARNINGS;\n";
    print "COMMIT;\n";
    print "SELECT \"Table relations created.\";\n";
    print "\n";
}

foreach my $table (sort keys %$csv_info) {
    my @cols = keys %{$csv_info->{$table}{COLS}};

    print "-- $table\n";
    print "CREATE TABLE `$table` (\n";

    my $id = 0;
    my $firstcol = 1;

    foreach my $col (@$csv_header) {
        if (exists $csv_info->{$table}{COLS}{$col}) {

            my $type;
            if (defined $csv_info->{$table}{COLS}{$col}[2]) {
                $type = $csv_info->{$table}{COLS}{$col}[2];
            }
            elsif (index($col, "root_") == 0) {
				$type = 'datetime';
			} else {
                $type = 'VARCHAR(' . $csv_info->{$table}{COLS}{$col}[1] . ')';
            }
           
            $id = 1 if ($col eq 'cmdb_id');

            print ",\n" unless ($firstcol);
            $firstcol = 0;

            print "  `$col` $type DEFAULT NULL";
        }
    }

    print ",\n  PRIMARY KEY (cmdb_id)" if $id;
    print "\n) ENGINE=MyISAM DEFAULT CHARSET=utf8;\n";
    print "\n";
    print "SHOW WARNINGS;\n";
    print "COMMIT;\n";
    print "SELECT \"Table $table created.\";\n";
    print "\n";
}

# ==========================================================================
