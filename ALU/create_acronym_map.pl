=head1 NAME

create_acronym_map - This script will create an excel sheet with the data of the acronym_mapping table

=head1 VERSION HISTORY

version 1.0 23 August 2012 PCO

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will create an excel sheet with the data of the acronym_mapping table. This data is maintained by Ken.
To aid we can also deliver only the changes.

=head1 SYNOPSIS

 create_acronym_map.pl [--help|-h [VERBOSE_LEVEL]] [--force|-f] [--trace|-t] [--log LOGDIR|-l LOGDIR] [--ini|-i DIR] [--diff|-d] RUN

 create_acronym_map.pl -h    Usage
 create_acronym_map.pl -h 1  Usage and description of the options
 create_acronym_map.pl -h 2  All documentation

=head1 OPTIONS

RUN is the symbolic name for the specific run, that can be found as a section in the ini-file. In
this ini-file section we look for the parameter DS_STEP5.  This way we find the folder to store the sheet.

=over 4

=item B<-f, --force>

 If a destination file already exist, remove it

=item B<-t, --trace>

 Tracing enabled, default: no tracing

=item B<-l LOGDIR, --log=LOGDIR>

 default: d:\temp\log

=item B<-i DIR, --ini=DIR>

 alternative location of the ini files (normally in the properties folder of the current directory)

=item B<-d, --diff>

Report only the changes

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
use vars qw($opt_diff);

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
push @GetOptArgv, "diff|d";
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

# End handle input values
# ==========================================================================

######
# Main
######

$summary_log->info("Start `$scriptname' application");

unless ($alu_cfg->SectionExists($run)) { ERROR("Run `$run' does not exists in alu.ini !"); exit(2); }
my $ds_step = $alu_cfg->val($run, 'DS_STEP5') or do { ERROR("DS_STEP5 missing in [$run] section in alu.ini !"); exit(2) };
unless (-d $ds_step) { ERROR("DS_STEP5 directory `$ds_step' ain't a directory !"); exit(2); }

my $file = File::Spec->catfile($ds_step, 'master_acronym_mapping.xls');

if (-f $file) {
  if ($opt_force) {
    unlink($file) or do { ERROR("Failed to remove the existing output file `$file' !"); exit(2) }
  }
  else {
    ERROR("Output file `$file' already exists !");
    exit(2);
  }
}

$summary_log->info("Dumping the acronym_mapping table into an Excel sheet `$file'");

# Make database connection for target database
my $dbt = db_connect('cim') or do { ERROR("Can't connect to the `cim' database !"); exit(2) };

# portfolio id from application and portfolio id from acronym_mapping should be the same
# I checked this and it is the same !

my $data = do_select($dbt, "
SELECT a.appl_name_description, a.appl_name_long, a.portfolio_id, a.appl_name_acronym, am.appl_name_normalized_acronym
  FROM application a, acronym_mapping am
  WHERE a.application_id = am.application_id
  ORDER BY a.portfolio_id ASC") or do { ERROR("Failed to read the acronym_mapping table !"); exit(2) };

$dbt->disconnect or do { ERROR("Can't disconnect from the `cim' database !"); exit(2) };

#print Dumper($data);

# Write the data into an excel sheet

# Create a new workbook and add a worksheet.
my $workbook = Spreadsheet::WriteExcel->new($file) or die;

my $worksheet = $workbook->add_worksheet("acronym_mapping") or die;

my $header_format = $workbook->add_format() or die;
$header_format->set_bold();
$header_format->set_bg_color('yellow');
$header_format->set_align('center');

# The general syntax is write($row, $column, $token).
# Note that row and column are zero indexed.

my $iR = 0;
my $l;

# Write the header line
#App ID, App Acronym, New Acronym, App Desc, App Name
my $header = [ 'App ID', 'App Acronym', 'New Acronym', 'App Desc', 'App Name' ];
my $data_map = [ 2, 3, 4, 0, 1 ];

for my $iC (0 .. $#$header) {
  $worksheet->write($iR, $iC, $header->[$iC], $header_format) and die;
  $l->[$iC] = length($header->[$iC]);
}

$iR++;

# Write the data
foreach my $row (@$data) {

  for my $iC (0 .. $#$header) {
    my $iD = $data_map->[$iC];

    my $elem = $row->[$iD] || '';

    $worksheet->write($iR, $iC, $elem) and die;
    $l->[$iC] = length($elem) if (length($elem) > $l->[$iC]);
  }

  $iR++;
}

# Set the column widths
for my $iC (0 .. $#$header) {
  $worksheet->set_column($iC, $iC, $l->[$iC]);
}


###
### DIFFS
###

if ($opt_diff) {

  my $dbs = db_connect('alu_cmdb') or do { ERROR("Can't connect to the `alu_cmdb' database !"); exit(2) };

  # select the original data
  my $old_data = do_select($dbs, "
SELECT `App ID`, `App Acronym`, `New Acronym`, `App Desc`, `App Name`
  FROM alu_acronym_mapping
  ORDER BY `App ID` ASC") or do { ERROR("Failed to read the acronym_mapping table !"); exit(2) };

  $dbs->disconnect or do { ERROR("Can't disconnect from the `alu_cmdb' database !"); exit(2) };

  # transform new data in same format als the old data
  # old : `App ID`, `App Acronym`, `New Acronym`, `App Desc`, `App Name` (same order as the sheet)
  # new: a.appl_name_description, a.appl_name_long, a.portfolio_id, am.portfolio_id, a.appl_name_acronym, am.appl_name_normalized_acronym

  # old[0] <=> new[2]
  # old[1] <=> new[3]
  # old[2] <=> new[4]
  # old[3] <=> new[0]
  # old[4] <=> new[1]

  my $new_data = [ map { [ $_->[2], $_->[3], $_->[4], $_->[0], $_->[1] ] } @$data ];

  # to minimize diffs, remove trailing blanks and make NULL values an empty string
  normalize_data($old_data);
  normalize_data($new_data);

  my $diffs = compare_data($old_data, $new_data);
  #print Dumper($diffs);

  my $worksheet = $workbook->add_worksheet("acronym_mapping_diff") or die;

  # The general syntax is write($row, $column, $token).
  # Note that row and column are zero indexed.

  my $iR = 0;
  my $l;

  # Write the header line
  # Change, App ID, App Acronym, New Acronym, App Desc, App Name
  my $header = [ 'Change', 'App ID', 'App Acronym', 'New Acronym', 'App Desc', 'App Name' ];

  for my $iC (0 .. $#$header) {
    $worksheet->write($iR, $iC, $header->[$iC], $header_format) and die;
    $l->[$iC] = length($header->[$iC]);
    $l->[0] += 1;               # fix column width of first column
  }

  $iR++;

  # Write the data
  foreach my $set (@$diffs) {
    foreach my $row (@$set) {

      for my $iC (0 .. $#$header) {
        $worksheet->write($iR, $iC, $row->[$iC]) and die;
        $l->[$iC] = length($row->[$iC]) if (length($row->[$iC]) > $l->[$iC]);
      }

      $iR++;
    }
  }


  # Set the column widths
  for my $iC (0 .. $#$header) {
    $worksheet->set_column($iC, $iC, $l->[$iC]);
  }

  ## Add a sheet with a description of the diff sheet, so that Ken Hughes knows what he is looking at.

  my $worksheet2 = $workbook->add_worksheet("INFO about acronym_mapping_diff") or die;

  # Create a "text wrap" format
  my $wrap_format = $workbook->add_format();
  $wrap_format->set_text_wrap();

  $worksheet2->write(0, 0, "Description", $header_format) and die;

  my $msg1 = "The acronym_mapping_diff sheet contains three parts:

First part are all the lines that have a '-' sign in the Change column. These are lines from the master_acronym_mapping.xls sheet provided by Ken that are not used any more.

The second part are all the lines that have a '+' sign in the Change column. These are applications that where missing in the master_acronym_mapping.xls sheet provided by Ken and should be added to this sheet.

The third part are all the pairs of lines that have a '-' sign and a '+' sign in the Change column.
These are the applications where either the App Acronym column or the New Acronym column was changed.

The line with the '-' sign contains the original data. The line with the '+' sign contains the new data.

The data can change for the following reasons :
    If New Acronym is not unique, it is made unique by adding a numbered suffix (eg. '__1' or '__2'). See the line with the '+' sign.

    If App Acronym in the Portfolio sheet is different from App Acronym in the master_acronym_mapping.xls sheet the value from the Portfolio sheet is used.
";

  $worksheet2->write(1, 0, $msg1, $wrap_format) and die;

  my $msg2 = "The acronym_mapping sheet contains the data from the original master_acronym_mapping.xls sheet provided by Ken with all the changes that are mentioned in the acronym_mapping_diff applied.";

  $worksheet2->write(2, 0, $msg2, $wrap_format) and die;

  $worksheet2->set_column(0, 0, 100);

}

$workbook->close() or die;

$summary_log->info("Exit application with success");
exit(0);

# ==========================================================================

# report the changes
# we have two columns that are unique (and can be used as key, the portfolio id and the new acronym name).

sub compare_data {
  my ($old, $new) = @_;

  #print Dumper($new);

  my $data_log = Log::Log4perl->get_logger('Data');

  my $old_h;
  my $new_h;

  my $del = [];
  my $add = [];
  my $change = [];

  # use portfolio id as key
  for (my $i = 0; $i <= $#$old; $i++) {
    my $key = $old->[$i][0];

    if (exists $old_h->{$key}) {
      $data_log->error("Portfolio id `$key' is not unique in the source data!");
      # add it to the deleted rows, just to report it
      push @$del, $old->[$i];
      next;
    }

    $old_h->{$key} = $old->[$i];
  }

  for (my $i = 0; $i <= $#$new; $i++) {
    my $key = $new->[$i][0];

    if (exists $new_h->{$key}) {
      $data_log->error("Portfolio id `$key' is not unique in the target data!");
      # add it to the added rows, just to report it
      push @$add, $new->[$i];
      next;
    }

    $new_h->{$key} = $new->[$i];
  }

  # compare
  foreach my $key (keys %$old_h) {
    unless (exists $new_h->{$key}) {
      push @$del, $old_h->{$key};
      delete $old_h->{$key};
    }
  }

  foreach my $key (keys %$new_h) {
    unless (exists $old_h->{$key}) {
      push @$add, $new_h->{$key};
      delete $new_h->{$key};
    }
  }

  #print Dumper($del);
  #print Dumper($add);

  # what remains should be the common keys
  foreach my $key (keys %$old_h) {
    unless (exists $new_h->{$key}) {
      ERROR("Internal error"); die;
    }
  }

  foreach my $key (keys %$new_h) {
    unless (exists $old_h->{$key}) {
      ERROR("Internal error"); die;
    }
  }

  foreach my $key (keys %$old_h) {
    if (compare_row($old_h->{$key}, $new_h->{$key})) {
      push @$change, [ [ '-', @{ $old_h->{$key} } ], [ '+', @{ $new_h->{$key} } ] ];
    }
  }

  #print Dumper($change);

  # report results back

  my $result;
  my @tmp;
  foreach (sort { $a->[0] cmp $b->[0] } @$del) {
    push @tmp, [ '-', @$_ ];
  }
  push @$result, [ @tmp ];

  @tmp = ();

  foreach (sort { $a->[0] cmp $b->[0] } @$add) {
    push @tmp, [ '+', @$_ ];
  }

  push @$result, [ @tmp ];

  foreach (sort { $a->[0][1] cmp $b->[0][1] } @$change) {
    push @$result, $_;
  }


  return $result;
}

# ==========================================================================

# return true if different

sub compare_row {
  my ($old, $new) = @_;

  return 1 unless ($#$old == $#$new);

  for (my $i = 0; $i <= $#$old; $i++) {
    # skip appl_name_description, because it is not used from this sheet anyway.
    next if ($i == 3);

    # skip a.appl_name_long, because it is not used from this sheet anyway.
    next if ($i == 4);

    return 1 if ((defined $old->[$i] && (! defined $new->[$i]))
                 || (defined $new->[$i] && (! defined $old->[$i])));

    return 1 if (defined $old->[$i] && defined $new->[$i] && $old->[$i] ne $new->[$i]);
  }

  return 0;
}
# ==========================================================================

sub normalize_data {
  my $data = shift;

  foreach my $row (@$data) {
    foreach (@$row) {
      $_ = '' unless (defined $_);

      s/\s*$//;

    }
  }
}
# ==========================================================================
