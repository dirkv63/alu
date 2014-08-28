=head1 NAME

workgroup_from_appl_instance - Extract Workgroup Information for OVSD and A7

=head1 VERSION HISTORY

version 1.0 31 August 2012 PCO

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Workgroup Information for OVSD and AssetCenter.

=head1 SYNOPSIS

 workgroup_from_appl_instance.pl [-t] [-l log_dir] [-c]

 workgroup_from_appl_instance.pl -h    Usage
 workgroup_from_appl_instance.pl -h 1  Usage and description of the options
 workgroup_from_appl_instance.pl -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=item B<-c>

If specified, then do NOT clear tables in CIM before populating them.

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -c, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
###########

my $clear_tables;

#####
# use
#####

use warnings;                       # show warning messages
use strict;
use File::Basename;
use Getopt::Std;                    # Handle input params
use Pod::Usage;                     # Allow Usage information
use Log::Log4perl qw(:easy);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_stmt do_execute rcreate_record);
use ALU_Util qw(exit_application rval_available);
use Data::Dumper;

#############
# subroutines
#############

# ==========================================================================

######
# Main
######

# Handle input values
my %options;
getopts("tl:h:c", \%options) or pod2usage(-verbose => 0);

if (defined $options{"h", }) {
  if    ($options{"h"} == 0) { pod2usage(-verbose => 0); }
  elsif ($options{"h"} == 1) { pod2usage(-verbose => 1); }
  else                       { pod2usage(-verbose => 2); }
}

my $level = 0;
# Trace required?
$level = 3 if (defined $options{"t"});

my $attr = { level => $level };

# Find log file directory
$attr->{logdir} = $options{"l"} if ($options{"l"});

setup_logging($attr);
my $summary_log = Log::Log4perl->get_logger('Summary');

my $scriptname = basename($0,"");

$summary_log->info("Start `$scriptname' application");

# Clear data
if (not defined $options{"c"}) {
        $clear_tables = "Yes";
}

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values
# ==========================================================================

my $data_log = Log::Log4perl->get_logger('Data');

my $source_system_counter;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("workgroups") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

$summary_log->info("Getting Workgroups Information");

# Get all the application instances from the CIM database

my $sth = do_execute($dbt, "
SELECT ai.application_instance_id, ai.application_instance_tag, ai.source_system, a.application_id, a.portfolio_id, a.application_type
  FROM application_instance ai LEFT JOIN application a ON ai.application_id = a.application_id") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
  my $application_instance_id = $ref->{application_instance_id};
  my $application_instance_tag = $ref->{application_instance_tag};

  my $source_system = (split(/_/, ($ref->{'source_system'} || '')))[0] || 'UNKNOWN_SOURCE_SYSTEM';

  my $application_id = $ref->{application_id};
  my $portfolio_id = $ref->{'portfolio_id'};

  $source_system_counter->{$source_system}->{TOTAL}++;

  unless (defined $application_id && length($application_id) > 0) {
    $source_system_counter->{$source_system}->{NO_APPL}++;
    $data_log->error("The application_instance `$application_instance_id / $application_instance_tag` has no parent application !");
    next;
  }

=pod

=head2 Store Workgroup Data

This procedure will store the workgroup data related to the CI Type. Input parameters are db handle
for source, target, ci type (currently only application_instance_id is known), ID for the ci type
and unique identifier for the CI from the source system.

A query is done to find if any information is found. If so, evaluate field per field if it contains
workgroup information. If so, add the workgroup information to the workgroups table for this CI ID.

For every application instance we look for the corresponding application (these should be there)
and take the portfolio id from this application. With this portfolio id we look for workgroup info

=cut

  if (defined $portfolio_id && length($portfolio_id) > 0) {
    $source_system_counter->{$source_system}->{PF}++;

    # Get the Workgroup information from alu_workgroups table
    # search for this portfolio id in the alu_workgroups

    # `Change Coordinator Workgroup` is not used
    my $sth = do_execute($dbs, "
SELECT `Config Management Workgroup`, `Change Supervisor Workgroup`, `Change Implementer Workgroup`, `Change Management Workgroup`,
       `Approver Groups`, `Primary Incident Resolution Group`
  FROM alu_workgroups
  WHERE `Portfolio ID` = '$portfolio_id'") or exit_application(2);

    my @fields = ('application_instance_id', 'configgroup', 'supervisor', 'implementer', 'management', 'approver', 'assignment');

    if (my $ref = $sth->fetchrow_hashref) {

      $source_system_counter->{$source_system}->{PF_WG}++;

      my $workgroups_id;

      my $record;

      $record->{configgroup} = $ref->{'Config Management Workgroup'};
      $record->{supervisor} = $ref->{'Change Supervisor Workgroup'};
      $record->{implementer} = $ref->{'Change Implementer Workgroup'};
      $record->{management} = $ref->{'Change Management Workgroup'};
      $record->{approver} = $ref->{'Approver Groups'};
      $record->{assignment} = $ref->{'Primary Incident Resolution Group'};

      if (rval_available($record)) {
        $record->{application_instance_id} = $application_instance_id;

        $workgroups_id = rcreate_record($dbt, "workgroups", $record) or return;
      }

      ### check only one row exists
      my $ref = $sth->fetchrow_hashref;

      if (defined $ref || defined $sth->err()) {
        $data_log->error("Multiple workgroup rows found for application instance `$application_instance_id'");
      }
    }
  }
  else {
    # Technical applications have no portfolio id
    if (lc($ref->{application_type} || '') eq 'application') {
      $source_system_counter->{$source_system}->{NO_PF}++;
      $data_log->warn("The application `$application_id / $application_instance_tag` has no portfolio id !");
    }
  }
}


# Report what we've done
foreach my $source_system (keys %$source_system_counter) {
  # A7 : $VAR1 = { 'PF_WG' => 265, 'TOTAL' => 4754, 'NO_PF' => 4346, 'PF' => 408 };

  my $wg_count = $source_system_counter->{$source_system}->{'PF_WG'} || 0;

  $summary_log->info("Created $wg_count workgroup records for source system `$source_system'");
}


$dbs->disconnect;
$dbt->disconnect;
$summary_log->info("Exit `$scriptname' application with success");
exit(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
