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

load_sheet - Generic script to load an excel workbook in a mysql database

=head1 SYNOPSIS

 load_sheet.pl [OPTIONS] RUN WORKBOOK.xls
 load_sheet.pl [OPTIONS] WORKBOOK.xls
 load_sheet.pl -h    Show script synopsis
 load_sheet.pl -h 1  Show script synopsis and description of the options
 load_sheet.pl -h 2  Show all documentation

=head1 DESCRIPTION

This script will load all the sheets of an excel workbook into a mysql database.
If two parameters are given, the RUN parameters refers to the section of the alu.ini file where we look
for the parameter DS_SRC_MASTER. This parameters refers to the directory where the workbook resides.
If one parameter is given, the DEFAULT section of the alu.ini file is used.

The name of the database and the name of the table is taken by default from the sheet name. Sheet names like Sheet1, Sheet2, ... are ignored.

An example of a valid sheet name is 'cim.person', ie. The name of the database + the name of the table, separated by a dot.

The mysql tables must exist. This is used to check the columns in the sheet versus the columns in the table.

The sheet must contain data in the UTF-8 format.

The sheet must not be an .xlsx file. It must be an .xls file.

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

 change the database name (default comes from the sheet name)

=item B<-m, --merge>

 See MERGE

=back

=head1 MERGE

An option to merge the data from the sheet with the data from the table could be added :
To merge, we have to know the key columns of the table

 => Take all the non-autoincrement columns
 => Take unique index. If multiple unique indexes, take the first.
 => The order of indexes is the order they are created in, not the alphabetical order.

=head1 VERSION HISTORY

version 1.0 20 August 2012 PCO

=over 4

=item *

Initial release.

=back

=cut

#####
# use
#####

use warnings;			    # show warning messages
use strict;
use Getopt::Long;
use File::Basename;
use File::Glob qw(:glob);
use File::Spec;
use Pod::Usage;			    # Allow Usage information
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseExcel::Fmt8Bit;
use Log::Log4perl qw(:easy);

use IniUtil qw(load_alu_ini);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect);
use XlsUtil qw(small_cell_handler tabglob2tab import_sheet);

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

my $workbook_file;
my $run;

if (@ARGV == 1) {
    $run = 'DEFAULT';
    $workbook_file = $ARGV[0];
}
elsif (@ARGV == 2) {
    $run = $ARGV[0];
    $workbook_file = $ARGV[1];
}
else {
    pod2usage("Need one or two arguments !\n");
}

pod2usage("Merge option not supported (yet) !\n") if ($opt_merge);

# I should put ini-file processing before the logging setup. Ini-file processing is closely related to the processing of the script options.
# By default the ini-file is searched in the current folder and the section is 'DEFAULT'

my $ini_attr;
$ini_attr->{ini_folder} = $opt_ini if ($opt_ini);
my $alu_cfg = load_alu_ini($ini_attr) or do { ERROR("Failed to parse ALU ini-file !"); exit(2) };

# Also ini-file processing must be done before database connect
# For the logging setup, I use the opt_ini parameter, but for the database parameters I don't => this really sucks !

my $level = 0;
$level = 3 if ($opt_trace);

my $attr = { level => $level };
$attr->{ini_section} = $run;

setup_logging($attr);

my $summary_log = Log::Log4perl->get_logger('Summary');
my $data_log = Log::Log4perl->get_logger('Data');

# ==========================================================================
######
# Main
######

$summary_log->info("Start `$scriptname' application");

## Read from the alu.ini file
unless ($alu_cfg->SectionExists($run)) { ERROR("Run `$run' does not exists in alu.ini !"); exit(2); }
my $ds_step = $alu_cfg->val($run, 'DS_SRC_MASTER') or do { ERROR("DS_SRC_MASTER missing in [$run] section in alu.ini !"); exit(2) };

# Determine path of workbook

my $xls_file = File::Spec->catfile($ds_step, $workbook_file);

unless (-f $xls_file) { ERROR("Excel file `$xls_file' does not exists !"); exit(2); }

my $bfile = basename($xls_file);

## Start reading the sheet

my $InExcel;
my $oFmt;

unless (defined $InExcel) {
    $InExcel = Spreadsheet::ParseExcel->new(CellHandler => \&small_cell_handler, NotSetCell => 1) or croak("ERROR: can't lauch EXCEL !\n");
}

unless (defined $oFmt) {
    $oFmt = new Spreadsheet::ParseExcel::Fmt8Bit or croak("ERROR: can't lauch excel Formatter !\n");
}

my $workbook = $InExcel->parse($xls_file);

unless (defined $workbook) {
    ERROR("Failed to parse `$bfile' :" . $InExcel->error() . " !");
    exit(2);
}


# get the tabs out of the xls file
my $worksheets;

for my $worksheet ( $workbook->worksheets() ) {
    my $worksheet_name = $worksheet->get_name;

    if ($worksheet_name =~ m/heet[0-9]+$/) {
        print STDERR "Skipping sheet `$worksheet_name' ...\n";
        next;
    }

    # get database / table name from the tab name.

    my ($database, $table);

    if ($worksheet_name =~ m/\./) {
        ($database, $table) = split(/\./, $worksheet_name, 2);
    }
    else {
        # no dot => no database, need opt_database or it will fail.
        $table = $worksheet_name;
    }

    # overwrite database from sheet
    $database = $opt_database if ($opt_database);

    # connect with the database
    my $dbh = db_connect($database) or do { ERROR("Can't connect to the $database database !"); exit(2) };

    $summary_log->info("Importing `$bfile|$worksheet_name' in the $database.$table table");

    my $source_row_count = import_sheet($worksheet, $dbh, $table);

    unless (defined $source_row_count) {
        ERROR("Failed to import sheet in the table $database.$table");
        exit(2);
    }

    $summary_log->info("Import `$bfile|$worksheet_name' ($source_row_count rows) finished.");

    $dbh->disconnect;
}

exit(0);

# ==========================================================================

__END__

