=head1 NAME

create_uuid_map - This script will create an excel sheet with the data of the uuid map table

=head1 VERSION HISTORY

version 1.0 20 August 2012 PCO

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will create an excel sheet with the data of the uuid map table. The purpose of this is
to saveguard the generated uuid's in a file. Before every new data load, the uuid's will be loaded
from the sheet into the database, so that the generated uuid's remain stable across several data loads.

And if you can refrase the above sentence, feel free to do so.

=head1 SYNOPSIS

 create_uuid_map.pl [--help|-h [VERBOSE_LEVEL]] [--force|-f] [--trace|-t] [--log LOGDIR|-l LOGDIR] [--ini|-i DIR] [--database|-d DB] RUN

 create_uuid_map.pl -h    Usage
 create_uuid_map.pl -h 1  Usage and description of the options
 create_uuid_map.pl -h 2  All documentation

=head1 OPTIONS

RUN is the symbolic name for the specific run, that can be found as a section in the ini-file. In
this ini-file section we look for the parameter DS_SRC_MASTER.  This way we find the folder to store the sheet.

=over 4

=item B<-f, --force>

 If a destination file already exist, remove it

=item B<-t, --trace>

 Tracing enabled, default: no tracing

=item B<-l LOGDIR, --log=LOGDIR>

 default: d:\temp\log

=item B<-i DIR, --ini=DIR>

 alternative location of the ini files (normally in the properties folder of the current directory)

=item B<-d DATABASE, --database=DATABASE>

change the database name (default 'cim')

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -c, -d options).

=head1 ADDITIONAL DOCUMENTATION

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
use Log::Log4perl qw(:easy);
use IniUtil qw(load_alu_ini);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_select);
use Spreadsheet::WriteExcel;
use Data::Dumper;

# ==========================================================================

use vars qw($scriptname $opt_help);
use vars qw($opt_force);
use vars qw($opt_trace);
use vars qw($opt_log);
use vars qw($opt_ini);
use vars qw($opt_database);

# ==========================================================================

$scriptname = basename($0,"");

$| = 1;                         # flush output sooner

# ==========================================================================
# Handle input values

my @GetOptArgv;
push @GetOptArgv, "force|f";
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

pod2usage("Need one argument !\n") if @ARGV != 1;

my $run = $ARGV[0];

$opt_trace ? Log::Log4perl->easy_init($DEBUG) : Log::Log4perl->easy_init($WARN);

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

my $database = ($opt_database) ? $opt_database : 'cim';

# End handle input values
# ==========================================================================

######
# Main
######

$summary_log->info("Start `$scriptname' application");

unless ($alu_cfg->SectionExists($run)) { ERROR("Run `$run' does not exists in alu.ini !"); exit(2); }
my $ds_step = $alu_cfg->val($run, 'DS_SRC_MASTER') or do { ERROR("DS_SRC_MASTER missing in [$run] section in alu.ini !"); exit(2) };
unless (-d $ds_step) { ERROR("DS_SRC_MASTER directory `$ds_step' ain't a directory !"); exit(2); }

my $file = File::Spec->catfile($ds_step, 'master_uuid_map.xls');

if (-f $file) {
  if ($opt_force) {
    unlink($file) or do { ERROR("Failed to remove the existing output file `$file' !"); exit(2) }
  }
  else {
    ERROR("Output file `$file' already exists !");
    exit(2);
  }
}

$summary_log->info("Dumping the uuid_map table into an Excel sheet `$file'");

# Make database connection for target database
my $dbt = db_connect($database) or do { ERROR("Can't connect to the $database database !"); exit(2) };

my $data = do_select($dbt, "
SELECT uuid_type, application_key, uuid_value
  FROM uuid_map
  ORDER BY uuid_type ASC, uuid_map_id ASC") or do { ERROR("Failed to read the uuid_map table !"); exit(2) };

#print Dumper($data);

# Write the data into an excel sheet

# Create a new workbook and add a worksheet.
my $workbook = Spreadsheet::WriteExcel->new($file) or die;
my $worksheet = $workbook->add_worksheet("$database.uuid_map") or die;

my $header_format = $workbook->add_format() or die;
$header_format->set_bold();
$header_format->set_bg_color('yellow');
$header_format->set_align('center');

# The general syntax is write($row, $column, $token).
# Note that row and column are zero indexed.

my $iR = 0;
my $l;

# Write the header line

my $header = [ 'uuid_type', 'application_key', 'uuid_value' ];

for my $iC (0 .. $#$header) {
  $worksheet->write($iR, $iC, $header->[$iC], $header_format) and die;
  $l->[$iC] = length($header->[$iC]);
}

$iR++;

# Write the data
foreach my $row (@$data) {

  for my $iC (0 .. $#$header) {
    $worksheet->write($iR, $iC, $row->[$iC]) and die;
    $l->[$iC] = length($row->[$iC]) if (length($row->[$iC]) > $l->[$iC]);
  }

  $iR++;
}

# Set the column widths
for my $iC (0 .. $#$header) {
  $worksheet->set_column($iC, $iC, $l->[$iC]);
}

$workbook->close() or die;

$dbt->disconnect;
$summary_log->info("Exit application with success");
exit(0);
