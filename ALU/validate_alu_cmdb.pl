#!/usr/bin/perl
# ==========================================================================
# $Source$
# $Author$ [pauwel]
# $Date$
# CDate: Mon Jun 11 14:10:46 2012
# $Revision$
#
# ==========================================================================
#
# ident "$Id$"
#
# ==========================================================================

=pod
    
    Basic validation of the ALU_CMDB mysql database

=cut
    
use strict;
use Getopt::Long;
use File::Basename;
use File::Glob qw(:glob);
use File::Spec;
use Log::Log4perl qw(:easy);

use Spreadsheet::ParseExcel::Recursive;
use Spreadsheet::ParseExcel::Fmt8Bit;

use IniUtil qw(load_alu_ini);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_select);
use ALU_Util qw(validate_row_count);

use Data::Dumper;

# ==========================================================================

use vars qw($scriptname $opt_help);
use vars qw($opt_trace);
use vars qw($opt_log);
use vars qw($opt_ini);

sub usage
{
    die "@_" . "Try '$scriptname -h' for more information\n" if @_;
    
    die "Usage:
   $scriptname [OPTION] RUN

  --help|-h            display this help and exit
  --trace|-t           Tracing enabled, default: no tracing
  --log|-l LOGDIR      default comes from alu.ini file
  --ini|-i DIR         alternative location of the ini files (normally in the properties folder of
                       the current directory)

Validate alu_cmdb database.
";
}

# ==========================================================================

$scriptname = basename($0,"");

$| = 1;                         # flush output sooner

# ==========================================================================

my @GetOptArgv;
push @GetOptArgv, "trace|t";
push @GetOptArgv, "log|l=s";
push @GetOptArgv, "ini|i=s";
GetOptions("help|h|?", @GetOptArgv) or usage "Illegal option : ";

usage if $main::opt_help;

@ARGV = map { bsd_glob($_, GLOB_NOCHECK | GLOB_NOCASE) } @ARGV if @ARGV;

my $run = 'DEFAULT';

if    (@ARGV > 1)  { usage "Need at most one argument !\n"; }
elsif (@ARGV == 1) { $run = $ARGV[0]; }

Log::Log4perl->easy_init($ERROR);

## Read the alu.ini file
my $ini_attr;
$ini_attr->{ini_folder} = $opt_ini if ($opt_ini);
my $alu_cfg = load_alu_ini($ini_attr) or do { ERROR("Failed to parse ALU ini-file !"); exit(2) };

my $level = 0;
# Trace required?
$level = 3 if ($opt_trace);

my $attr = { level => $level };

# Find log file directory
$attr->{logdir} = $opt_log if ($opt_log);
$attr->{ini_section} = $run;

setup_logging($attr);

my $summary_log = Log::Log4perl->get_logger('Summary');
my $data_log = Log::Log4perl->get_logger('Data');

# ==========================================================================

$summary_log->info("Validation of the tables in the alu_cmdb database");

# connect with the database

# Make database connection for target database
my $dbs = db_connect('alu_cmdb') or do { ERROR("Failed to connect to the alu_cmdb database !"); exit(2) };

my $db_tables = do_select($dbs, "show tables");

unless ($db_tables && @$db_tables) {
    ERROR("Failed to get table information of the alu_cmdb database");
    exit(2);
}

my $err_cnt = 0;
my $data_err_cnt = 0;
my $table_cnt = 0;

foreach my $row (@$db_tables) {
    my $table = $row->[0];
    $table_cnt++;

    my $title = "Table $table";
    $summary_log->info("$title");

    #$title =~ s/./=/g;
    #$summary_log->info("$title");

    my $expected_size = alu_cmdb_table_info($table);

    unless (defined $expected_size) {
        ERROR("Failed to retrieve table spec for $table\n");
        $err_cnt++;
        next;
    }

    # Field, Type, Null, Key, Default, Extra
    my $cols = do_select($dbs, "desc $table");
    #print Dumper($cols);
    
    unless ($cols && @$cols) {
        ERROR("Failed to get column information of the table alu_cmdb.$table");
        $err_cnt++;
        next;
    }

    my $col_count = @$cols;

    my $expected_cols = $expected_size->{Columns};

    if ($expected_cols >= 0) {
        if ($col_count != $expected_cols) {
            $data_log->error("table alu_cmdb.$table has invalid number of columns ($col_count instead of $expected_cols) !");
            $data_err_cnt++;
        }
    }
    else {
        $data_log->info("table alu_cmdb.$table has currently $col_count columns (not checked)");
    }

    my $rows = do_select($dbs, "select count(*) from $table");

    unless ($rows && @$rows) {
        ERROR("Failed to get row information of the table alu_cmdb.$table");
        $err_cnt++;
        next;
    }

    my $row_count = $rows->[0]->[0];

    my $expected_rows = $expected_size->{Rows};

    if ($expected_rows >= 0) {
    
        unless (validate_row_count($expected_rows, $row_count)) {
            $data_log->error("table alu_cmdb.$table has invalid number of rows ($row_count). Expected $expected_rows rows !");
            $data_err_cnt++;
        }
        else {
            $summary_log->info("table alu_cmdb.$table has currently $row_count rows") if ($opt_trace);
        }

    }
    else {
        $data_log->info("table alu_cmdb.$table has currently $row_count rows (not checked)");
    }

    # additional validation : count the total number of filled columns (rows * cols * data)
    # generate statement

    my $total = @$cols * $row_count;
    my $active_cols = 0;

    if ($total > 0) {
        # count nr of cols with some kind of data
        my $statement = '
SELECT IFNULL(SUM(COL_CNT), 0)
  FROM (SELECT (' . join(' + ', map { "IF ((`$_->[0]` IS NULL OR `$_->[0]` <=> '' OR `$_->[0]` <=> 0), 0, 1)" } @$cols) . ") AS COL_CNT FROM $table) AS Q1";

        my $rows = do_select($dbs, $statement);

        $active_cols = $rows->[0][0];

        my $percent = (int (100 * (100 * $active_cols) / $total)) / 100;

        my $expected = $expected_size->{ActiveColumns};

        if ($expected >= 0) {
            unless (validate_row_count($expected, $percent)) {
                $data_log->error("table alu_cmdb.$table has invalid percentage of active columns ($percent). Expected ${expected}% active columns !");
                $data_err_cnt++;
            }
            else {
                $summary_log->info("table alu_cmdb.$table has currently ${percent}% active columns") if ($opt_trace);
            }
        } 
    }


    if ($active_cols > 0) {

        # and this is the total data length;
        my $statement = '
SELECT IFNULL(SUM(COL_CNT), 0)
  FROM (SELECT (' . join(' + ', map { "LENGTH(IFNULL(`$_->[0]`, ''))" } @$cols) . ") AS COL_CNT FROM $table) AS Q1";

        my $rows = do_select($dbs, $statement);
      
        my $average_length = (int (10 * ($rows->[0][0] / $active_cols))) / 10;

        my $expected = $expected_size->{AverageLength};

        if ($expected >= 0) {
            unless (validate_row_count($expected, $average_length)) {
                $data_log->error("table alu_cmdb.$table has invalid average column length ($average_length). Expected ${expected} average length !");
                $data_err_cnt++;
            }
            else {
                $summary_log->info("table alu_cmdb.$table has currently ${average_length} average length") if ($opt_trace);
            }
        } 
    }
   1    
}
continue {
    #$summary_log->info('');
}

$summary_log->info("Checked `$table_cnt' tables. Found `$err_cnt' error(s) and `$data_err_cnt' data error(s) !");

# ==========================================================================

sub alu_cmdb_column_info {
    my $t = shift;
    
    my $info = _read_ALU_CMDB();

    unless (defined $info) {
        ERROR("No table info available");
        return;
    }
   
    my @table_info = grep { $_->{'Table'} eq $t; } @$info ;

    unless (@table_info == 1) {
        return 0;
    }

    return $table_info[0]->{Columns};
}

# ==========================================================================

sub alu_cmdb_row_info {
    my $t = shift;
    
    my $info = _read_ALU_CMDB();

    unless (defined $info) {
        ERROR("No table info available");
        return;
    }
   
    my @table_info = grep { $_->{'Table'} eq $t; } @$info ;

    unless (@table_info == 1) {
        return 0;
    }

    return $table_info[0]->{Rows};
}

# ==========================================================================

sub alu_cmdb_table_info {
    my $t = shift;
    
    my $info = _read_ALU_CMDB();

    unless (defined $info) {
        ERROR("No table info available");
        return;
    }
   
    my @table_info = grep { $_->{'Table'} eq $t; } @$info ;

    unless (@table_info == 1) {
        INFO("Can't find info for table `$t'");
        
        return { 'Table' => $t, 'Columns' => -1, 'Rows' => -1, 'ActiveColumns' => -1, 'AverageLength' => -1 };
    }

    return $table_info[0];
}

# ==========================================================================
# ==========================================================================
# Lezen EXCEL sheet
# ==========================================================================
# ==========================================================================

{
    my $ALU_CMDB;
    
    sub _read_ALU_CMDB {
        #my $ExcelFile = shift;
        
        # We search the sheet in de properties folder of the current directory
        # We could use the ini-file but for the moment KISS.

        my $ExcelFile = File::Spec->catfile('properties', 'DataValidation.xls');

        my $bfile = basename($ExcelFile);
        
        unless (defined $ALU_CMDB) {
            
            my $InExcel;
            my $oFmt;
            
            unless (defined $InExcel) {
                $InExcel = new Spreadsheet::ParseExcel::Recursive or croak("ERROR: can't lauch EXCEL !\n");
            }
            
            unless (defined $oFmt) {
                $oFmt = new Spreadsheet::ParseExcel::Fmt8Bit or croak("ERROR: can't lauch Formatter !\n");
            }
            
            $InExcel->Parse($ExcelFile, $oFmt) or croak("ERROR: Parse of excel file `$bfile' failed !");
            
            my $DDL = { TABLE => 'ALU_CMDB', COLUMNS => [ 'Table', 'Columns', 'Rows', 'ActiveColumns', 'AverageLength' ] };
            
            my $data = $InExcel->oread($DDL);# or croak "ERROR: Could't read EXCEL file `$file' !";
            
            $ALU_CMDB = $data->{'ALU_CMDB'};
            
            #print Dumper($ALU_CMDB);
            
        }
        
        return $ALU_CMDB;
    }
}

# ==========================================================================
__END__
