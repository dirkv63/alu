=head1 NAME

create_workgroup - This script will create a Product Data Template.

=head1 VERSION HISTORY

version 1.0 31 August 2012 PCO

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract instance product information for the instance product template.

=head1 SYNOPSIS

 create_workgroup.pl [-t] [-l log_dir]

 create_workgroup.pl -h    Usage
 create_workgroup.pl -h 1  Usage and description of the options
 create_workgroup.pl -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -c, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
###########

# Only the tab 'ApplicationInstance'is used
my $template = 'productinstance_interface_template.xlsx';
my $version = "4446";                                   # Version Number

# output files
my ($ApplicationInstance);

$| = 1;                         # flush output sooner

#####
# use
#####

use warnings;                       # show warning messages
use strict;
use Carp;
use Getopt::Std;                    # Handle input params
use Pod::Usage;                     # Allow Usage information
use Log::Log4perl qw(:easy);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_execute);
use ALU_Util qw(exit_application getsource val_available);
use TM_CSV;
use Data::Dumper;

#############
# subroutines
#############

# ==========================================================================

=pod

=head2 Init Outfiles

This procedure will open and initialize all data files for output.

=cut

sub init_outfiles {
  my ($source) = @_;

  $ApplicationInstance = TM_CSV->new({ source => $source, comp_name => 'ProductInstance', tabname => 'ApplicationInstance', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  return 1;
}

# ==========================================================================

=pod

=head2 Close OutFiles

This procedure will close all datafiles for output in an orderly fashion.

=cut

sub close_outfiles {
  $ApplicationInstance->close or return;
  return 1;
}

# ==========================================================================

sub get_workgroups($$) {
  my ($dbt, $application_instance_id) = @_;

  # Initialize variables
  my $rtv = [ map { '' } 1 .. 6 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($application_instance_id) > 0) && ($application_instance_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT configgroup, supervisor, implementer, management, approver, assignment
  FROM workgroups
  WHERE application_instance_id = $application_instance_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $configgroup = $ref->{configgroup} ||'';
    my $supervisor = $ref->{supervisor} ||'';
    my $implementer = $ref->{implementer} ||'';
    my $management = $ref->{management} ||'';
    my $approver = $ref->{approver} ||'';
    my $assignment = $ref->{assignment} ||'';
    $rtv = [ $configgroup, $supervisor, $implementer, $management, $approver, $assignment ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================
######
# Main
######

# Handle input values
my %options;
getopts("tl:h:", \%options) or pod2usage(-verbose => 0);

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

$summary_log->info("Start application");

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values
# ==========================================================================

$summary_log->info("Create Workgroup Extract for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(2);

# Get Source system
my $sourcearr = getsource($dbt, "application_instance", "source_system");

unless ($sourcearr) {
  ERROR("Found no sources in the cim.application_instance table !");
  exit_application(2);
}

foreach my $source (@$sourcearr) {
  $summary_log->info("Processing Workgroup data for Source $source");

  # Initialize datafiles for output
  init_outfiles($source) or exit_application(2);

  my $sth = do_execute($dbt, "
SELECT ai.application_instance_id, ai.application_instance_tag, ai.ucmdb_application_type
  FROM application_instance ai, application a
  WHERE ai.source_system like '$source%'
    AND ai.application_id = a.application_id
    AND a.application_type = 'Application'") or exit_application(2);

  while (my $ref = $sth->fetchrow_hashref) {
    my $application_instance_id = $ref->{application_instance_id} || '';
    my $InstanceID = $ref->{application_instance_tag} || '';
    my $applicationType = $ref->{ucmdb_application_type} || '';

    my @outarray = get_workgroups($dbt, $application_instance_id) or exit_application(2);
    push @outarray, $applicationType;

    if (val_available(\@outarray) eq "Yes") {
      # Add InstanceID at start of Array
      # Print to ApplicationInstance file

      # InstanceID, configgroup, cm3supervisor, cm3implementer, cm3management, cm3approver, assignment, applicationType
      unless ($ApplicationInstance->write($InstanceID, @outarray)) {
        ERROR("write ApplicationInstance failed");
        exit_application(2);
      }
    }
  }
  close_outfiles() or exit_application(2);
}

$dbt->disconnect;
$summary_log->info("Exit application with success");
exit(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
