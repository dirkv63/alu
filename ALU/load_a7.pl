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

Load of asset center XLSX sheets in the alu_cmdb database.
The sheets have to be converted to XLS before they can be loaded.

The corresponding mysql tables must exists. This is used to check the columns in the sheet versus
the columns in the table.

Validation of the number of rows.
Toevoegen van de info in de alu_snapshot_files tabel

- welke file geladen
- wanneer
- ook data log en summary log
- max lengte van kolommen.

Wat betreft de data en de charsets:
- Inlezen in binmode geeft een beter resultaat dan met access
- ik denk dat sommige kolommen latin1 data bevatten en sommige kolommen bevatten UTF-8 data

TODO
- only keep the data of the sheets we really want

=cut

use strict;
use Getopt::Long;
use File::Basename;
use File::Glob qw(:glob);
use File::Spec;
use Log::Log4perl qw(:easy);

use Spreadsheet::ParseExcel;
use Spreadsheet::ParseExcel::Fmt8Bit;
use IniUtil qw(load_alu_ini);
use ALU_Util qw(validate_row_count glob2pat);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect);
use WorkFlow qw(read_A7_SOURCE);
use XlsUtil qw(tabglob2tab small_cell_handler import_sheet);

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
  --file|-f FILE       only process this file (FILE is a regexp)
  --ini|-i DIR         alternative location of the ini files (normally in the properties folder of
                       the current directory)
  --database|-d DB     change the database name (default alu_cmdb)

Load incoming asset center files. RUN is the symbolic name for the specific run, that can be found
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

$summary_log->info("Importing asset center files in the $database database");

## Read from the alu.ini file
unless ($alu_cfg->SectionExists($run)) { ERROR("Run `$run' does not exists in alu.ini !"); exit(2); }
my $ds_step = $alu_cfg->val($run, 'DS_STEP1') or do { ERROR("DS_STEP1 missing in [$run] section in alu.ini !"); exit(2) };

my $a7_info = read_A7_SOURCE();

# connect with the database
my $dbs = db_connect($database) or do { ERROR("Can't connect to the $database database !"); exit(2) };

my $err_cnt = 0;

my $wanted_tables;

foreach my $a7_item (@$a7_info) {
    my ($table, $file, $charset, $expected_row_count) = map { $a7_item->{$_} } qw(Table File CharSet RowCount);

    # filter away csv files or (more correctly) only keep xls files
    next unless ($file =~ m/xls/i);

    # File is a file pattern + tab name (eg. Database CI Report on *.xls|DB_CI_Relationships)

    # Beware, the tab name is a glob expression too
    my ($xls_glob, $tab_glob) = split(/\|/, $file);

    # filtering is done with a glob.
    if ($opt_file) {
        my $re = glob2pat($opt_file);
        next unless ($xls_glob =~ qr/$re/);
    }

    # sort files|sheet per excel file (so we need to parse it only once)
    $wanted_tables->{$xls_glob}->{$tab_glob} = [ $table, $charset, $expected_row_count ];
}

if (keys %$wanted_tables < 1) { ERROR("No file matching the file pattern `$opt_file' found in WorkFlow.xls !"); exit(2); };

#print STDERR Dumper($wanted_tables);

foreach my $xls_glob (keys %$wanted_tables) {
    # xls is a shell wildcard pattern (glob it)

    my $file_pattern = File::Spec->catfile($ds_step, $xls_glob);

    my @files = map { bsd_glob($_, GLOB_NOCHECK | GLOB_NOCASE) } ($file_pattern);

    if (@files > 1) { ERROR("Multiple files matching the file pattern `$file_pattern' (" . join(', ', @files) . ") !"); $err_cnt++; next; };
    if (@files < 1) { ERROR("No file matching the file pattern `$file_pattern' !"); $err_cnt++; next; };

    my $xls_file = $files[0];
    my $bfile = basename($xls_file);

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
        $err_cnt++; next;
    }

    # get the tabs out of the xls file
    my $worksheets;

    for my $worksheet ( $workbook->worksheets() ) {
        my $worksheet_name = $worksheet->get_name;

        $worksheets->{$worksheet_name} = $worksheet;
    }

    foreach my $tab_glob (keys %{$wanted_tables->{$xls_glob}}) {
        # tab_glob => tab

        my $tab = tabglob2tab($workbook, $tab_glob) or do { ERROR("The sheet `$tab_glob' is not available in the file `$bfile' !"); $err_cnt++; next; };

        unless (exists $worksheets->{$tab}) {
            ERROR("The sheet `$tab' is not available in the file `$bfile' !");
            $err_cnt++; next;
        }

        my ($table, $charset, $expected_row_count) = @{ $wanted_tables->{$xls_glob}->{$tab_glob} };

        $summary_log->info("Importing `$bfile|$tab' in the $database.$table table");

        my $worksheet = $worksheets->{$tab};

        my $source_row_count = import_sheet($worksheet, $dbs, $table);

        unless (defined $source_row_count) {
            ERROR("Failed to import sheet in the table $database.$table");
            $err_cnt++;
            next;
        }

        # vergelijken van het aantal verwachte rijen.

        unless (validate_row_count($expected_row_count, $source_row_count)) {
            $data_log->warn("CSV file `$bfile' has an invalid number of rows ($source_row_count). Expected $expected_row_count rows !\n");
        }
        else {
            $data_log->info("Imported $source_row_count rows (expected about $expected_row_count rows)");
        }
    }

    $summary_log->info("Import `$bfile' finished.");
}

# ==========================================================================

__END__
