=head1 NAME

create_bpi_rels - This script will create the Business Product Instance Relationships.

=head1 VERSION HISTORY

version 1.0 12 January 2012 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will create the Business Product Instance Relationship file.

A Business Product Instance is a 'Dependency' relationship for most systems, including Assetcenter, OVSD and uCMDB.

In ESL, the dependency is implemented as an ESL Instance. The attributes that go with the dependency need to be specified in the interface template.

=head1 SYNOPSIS

 create_bpi_rels.pl [-t] [-l log_dir]

 create_bpi_rels -h		Usage
 create_bpi_rels -h 1	Usage and description of the options
 create_bpi_rels -h 2	All documentation

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

my $template = 'componentdependency_interface_template.xlsx';
my $version = '2066';
# output files (a hash ref !)
my ($BpiCS);

$| = 1;                         # flush output sooner

#####
# use
#####

use warnings;			    # show warning messages
use strict;
use Carp;
use Getopt::Std;		    # Handle input params
use Pod::Usage;			    # Allow Usage information
use Log::Log4perl qw(:easy);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_execute do_select);
use ALU_Util qw(get_field getsource replace_cr);
use TM_CSV;
use Data::Dumper;

#############
# subroutines
#############

sub exit_application($) {
    my ($return_code) = @_;

    my $summary_log = Log::Log4perl->get_logger('Summary');
    $summary_log->info("Exit application with error code $return_code.");

    exit($return_code);
}

# ==========================================================================

=pod

=head2 Init Outfiles

This procedure will open and initialize all data files for output.

=cut

sub init_outfiles {
  # Get Source system
  my ($source, $subbusiness) = @_;

  # Business Product Instance Depends Upon ComputerSystem

  # only use sub-business names for ESL
  $subbusiness = '' unless ($source eq 'ESL');

  unless (exists $BpiCS->{$subbusiness}) {
    my $subbusiness_suffix = ($subbusiness eq '' ) ? '' : '-' . $subbusiness;

    $BpiCS->{$subbusiness} = TM_CSV->new({ source => $source . $subbusiness_suffix, comp_name => 'cd', tabname => 'appInstDependsUponCS', version => $version });

    unless ($BpiCS->{$subbusiness}) {
      ERROR("Could not open output file, exiting...");
      return;
    }

  }

  return $BpiCS->{$subbusiness};

}

# ==========================================================================

=pod

=head2 Close OutFiles

This procedure will close all datafiles for output in an orderly fashion.

=cut

sub close_outfiles {
  # Business Product Instance Depends Upon ComputerSystem

  foreach my $k (keys %$BpiCS) {
    $BpiCS->{$k}->close or return;
  }

  return 1;
}

# ==========================================================================

sub get_assignment($$) {
  my ($dbt, $assignment_id) = @_;
  # Initialize variables
  my $rtv = [ map { '' } 1 .. 2 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($assignment_id) > 0) && ($assignment_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT initial_assignment_group, escalation_assignment_group
  FROM assignment
  WHERE assignment_id = $assignment_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $initial_assignment_group = $ref->{initial_assignment_group} || "";
    my $escalation_assignment_group = $ref->{escalation_assignment_group} || "";
    $rtv = [ $initial_assignment_group, $escalation_assignment_group ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_availability($$) {
  my ($dbt, $availability_id) = @_;

  # Initialize variables
  my $rtv = [ map { '' } 1 .. 5 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($availability_id) > 0) && ($availability_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT runtime_environment, impact, service_level_code, servicecoverage_window, possible_downtime
  FROM availability
  WHERE availability_id = $availability_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $runtime_environment = $ref->{runtime_environment} || "";
    my $impact = $ref->{impact} || "";
    my $service_level_code = $ref->{service_level_code} || "";
    my $servicecoverage_window = $ref->{servicecoverage_window} || "24x7 (00:00-24:00 Mon-Sun)";
    my $possible_downtime = $ref->{possible_downtime} || "";

    $rtv = [ $runtime_environment, $impact, $service_level_code, $servicecoverage_window, $possible_downtime ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_billing($$) {
  my ($dbt, $billing_id) = @_;

  # Initialize variables
  my $rtv = [ map { '' } 1 .. 4 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($billing_id) > 0) && ($billing_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT billing_resourceunit_code, billing_change_request_id, billing_change_category, billing_change_date
 FROM billing
 WHERE billing_id = $billing_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $billing_resourceunit_code = $ref->{billing_resourceunit_code} || "";
    my $billing_change_request_id = $ref->{billing_change_request_id} || "";
    my $billing_change_category = $ref->{billing_change_category} || "";
    my $billing_change_date = $ref->{billing_change_date} || "";

    $rtv = [ $billing_resourceunit_code, $billing_change_request_id, $billing_change_category, $billing_change_date ];
  }

  return wantarray ? @$rtv : $rtv;
}
# ==========================================================================

=pod

=head2 Get BPI

This procedure will get the ESL Instance from the Business Product Instance (ESL Solution) on the System. The Business Product Instance name is the 'left_name' in the relation 'ESLBusinessProductInstance', where the ESL Instance is the right name component.

Each ESL Instance is unique and has exactly one relation to a system / server and one relation to a ESL Solution (Business Product Instance). Therefore

=cut

sub get_bpi($$) {
  my ($dbh, $right_name) = @_;
  my $relation = 'ESLBusinessProductInstance';
  my @fields = ('relation', 'right_name');
  my (@vals) = map { eval ("\$" . $_ ) } @fields;
  my $left_name = get_field($dbh, 'relations', 'left_name', \@fields, \@vals);
  if ((not defined $left_name) || (length($left_name) == 0)) {
    my $data_log = Log::Log4perl->get_logger('Data');
    $data_log->error("Could not find Business Product Instance for ESL Instance tag $right_name");
    $left_name = '';	# Set left_name to blanks
  }

  return $left_name;
}

# ==========================================================================

=pod

=head2 Get ESL Instance Attributes for Business Product Instance

This procedure will get the dependency attributes for the ESL Instance that couples a ESL Solution / Business Product Instance to a ComputerSystem.

Each ESLBusinessProductInstance has exactly 1 link to a ComputerSystem and 1 link to a BusinessProductInstance.

=cut

sub get_attributes($$) {
  my ($dbh, $application_instance_tag) = @_;
  my $BusinessProductInstanceId = get_bpi($dbh, $application_instance_tag);
  # Now collect Attributes for the ESL Instance Object

  my $sth = do_execute($dbh, "
SELECT application_instance_id, appl_name_long, appl_name_description, time_zone, version, source_system_element_id,
       application_instance_tag, assignment_id, availability_id, billing_id
  FROM application_instance
  WHERE application_instance_tag = '$application_instance_tag'") or return;

  my $ref = $sth->fetchrow_hashref;

  unless ($ref) {
    my $data_log = Log::Log4perl->get_logger('Data');
    $data_log->error("Could not find ESLBusinessProductInstance Attributes for $application_instance_tag");
    return;
  }

  # Instance Product
  my $application_instance_id = $ref->{application_instance_id};
  my $ProductInstance_Name = $ref->{appl_name_long} || "";
  $ProductInstance_Name = replace_cr($ProductInstance_Name);
  my $Business_Description = $ref->{appl_name_description} || "Business Application Instance Business Description";
  $Business_Description = replace_cr($Business_Description);
  my $Time_Zone = $ref->{time_zone} || "";
  my $InstanceVersion = $ref->{version} || "";
  my $SourceSystemElementID = $ref->{source_system_element_id} || "";
  my $InstanceID = $ref->{application_instance_tag} || "";

  # Assignment Information
  my $assignment_id = $ref->{assignment_id} || "";
  my ($AssignmentGroup, $EscalationAssignmentGroup) = get_assignment($dbh, $assignment_id) or return;

  # Availability Information
  my $availability_id = $ref->{availability_id} || "";
  my ($Environment, $Impact, $serviceLevel, $serviceCoverageWindow, $planned_Outage_Coverage_Details) = get_availability($dbh, $availability_id) or return;

  # Billing Information
  my $billing_id = $ref->{billing_id} || "";
  my ($Billing_ResourceUnit_code, $Billing_Change_request_ID, $Billing_Change_Category, $Billing_Change_Date) = get_billing($dbh, $billing_id) or return;

  my $rtv = [ $BusinessProductInstanceId, $ProductInstance_Name, $Business_Description, $Environment, $Impact, $Billing_ResourceUnit_code, $Billing_Change_request_ID, $Billing_Change_Category, $Billing_Change_Date, $Time_Zone, $AssignmentGroup, $InstanceVersion, $serviceLevel, $serviceCoverageWindow, $planned_Outage_Coverage_Details, $AssignmentGroup, $EscalationAssignmentGroup, $SourceSystemElementID ];

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

{

  # build a map of all esl_id => esl_subbusiness. This is (much) faster than performing one query for every esl_id.
  # (from 4 minutes to 10 seconds)
  my $esl_map;

  sub esl_subbusiness($$) {
    my ($dbt, $esl_id) = @_;

    #my $sth = do_execute($dbt, "SELECT esl_subbusiness FROM compsys_esl WHERE esl_id = $esl_id") or return;

    my $rtv = [ ];

    unless (defined $esl_map) {
      my $esl_data = do_select($dbt, "SELECT DISTINCT esl_id, esl_subbusiness FROM compsys_esl") or return;
      foreach my $row (@$esl_data) {
        my $esl_id = $row->[0] || '';
        my $esl_subbusiness = $row->[1] || '';

        if (length($esl_subbusiness) > 0) {
          push @{ $esl_map->{$esl_id} }, $esl_subbusiness;
        }
      }
    }

    $rtv = [ @{ $esl_map->{$esl_id} } ] if (exists $esl_map->{$esl_id});

    return wantarray ? @$rtv : $rtv;
  }
}

# ==========================================================================

=pod

=head2 Business Product instance Depends Upon ComputerSystem

This type of relationship is the Business Product Instance Upon ComputerSystem. For A7 and OVSD, this is a direct link (ComputerSystem - has depending solution - Solution). All requested attributes will be blanks.

For ESL this is a link implemented via the ESL Instance ESLBusinessProductInstance. The requested attributes need to be specified.

=cut

sub handle_bpics($$) {
  my ($dbt, $source) = @_;

  my $sth = do_execute($dbt, "
SELECT left_name, right_name
  FROM relations
  WHERE relation = 'has depending solution'
    AND left_type = 'ComputerSystem'
   AND source_system like '$source%'") or return;

  while (my $ref = $sth->fetchrow_hashref) {

    # Get Information
    my $bpi_tag = $ref->{right_name} || "";

    my $CS_FQDN = $ref->{left_name} || "";
    # ComputerSystem can have <CR> in the name
    $CS_FQDN = replace_cr($CS_FQDN);

    # XXXX Hier zat een heel eigenaardig stukje code :
    # Voor ESL werd er een kolom teveel aan de file toegevoegd. Die files gaan dan nog door die fucking splitter, die er weer juiste files van maakt.

    if ($source eq 'ESL') {
      my ($BusinessProductInstanceId, $ProductInstance_Name, $Business_Description, $Environment, $Impact,
          $Billing_ResourceUnit_code, $Billing_Change_request_ID, $Billing_Change_Category, $Billing_Change_Date,
          $Time_Zone, $AssignmentGroup, $InstanceVersion, $serviceLevel, $serviceCoverageWindow,
          $planned_Outage_Coverage_Details, $InitialAssignmentGroup, $EscalationAssignmentGroup,
          $SourceSystemElementID) = get_attributes($dbt, $bpi_tag) or return;

      my @subbus_arr = esl_subbusiness($dbt, $SourceSystemElementID) or return;

      # ApplicationInstanceId, CS FQDN, ApplicationInstance Name, Business Description, InstanceEnvironment, Impact, Billing ResourceUnit code,
      # Billing Change request ID, Billing Change Category, Billing Change Date, Time Zone, AssignmentGroup, InstanceVersion, serviceLevel,
      # serviceCoverageWindow, planned Outage Coverage Details, InitialAssignmentGroup, EscalationAssignmentGroup, SourceSystemElementID

      foreach my $subbusiness (@subbus_arr) {
        # get the file handle for this sub business

        my $FH = init_outfiles($source, $subbusiness) or return;

        unless ($FH->write($BusinessProductInstanceId, $CS_FQDN, $ProductInstance_Name, $Business_Description, $Environment,
                                           $Impact, $Billing_ResourceUnit_code, $Billing_Change_request_ID, $Billing_Change_Category, $Billing_Change_Date,
                                           $Time_Zone, $AssignmentGroup, $InstanceVersion, $serviceLevel, $serviceCoverageWindow,
                                           $planned_Outage_Coverage_Details, $InitialAssignmentGroup, $EscalationAssignmentGroup,
                                           $SourceSystemElementID))
          { ERROR("write BpiCS failed"); return; }
      }
    } else {
      # Not an ESL System, so only BusinessProductInstanceId and

      my $BusinessProductInstanceId = $bpi_tag;

      my $FH = init_outfiles($source) or return;

      unless ($FH->write($BusinessProductInstanceId, $CS_FQDN, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '')) {
        ERROR("write BpiCS failed");
        return;
      }
    }
  }

  return 1;
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

$summary_log->info("Create Product Relations for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

# Get Source system for Installed Application
my $sourcearr = getsource($dbt, "relations", "source_system");

unless ($sourcearr) {
  ERROR("Found no sources in the cim.relations table !");
  exit_application(1);
}

unless (@$sourcearr == 1) {
  ERROR("Found multiple sources (" . join(', ', @$sourcearr) . "), only one expected");
  exit_application(1);
}

foreach my $source (@$sourcearr) {
  $summary_log->info("Processing 'cd' data for Source $source");

  # Handle All Relations
  handle_bpics($dbt, $source) or exit_application(1);

  # handle_csdb($dbt, $source) or exit_application(1);

  close_outfiles() or exit_application(1);
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
