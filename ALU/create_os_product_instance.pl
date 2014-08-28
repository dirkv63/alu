=head1 NAME

create_os_product_instance - This script will create OS Product Instance Information.

=head1 VERSION HISTORY

version 1.0 7 February 2012 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract OS instance product information for the instance product template.

=head1 SYNOPSIS

 create_os_product_instance.pl [-t] [-l log_dir]

 create_os_product_instance -h	Usage
 create_os_product_instance -h 1  Usage and description of the options
 create_os_product_instance -h 2  All documentation

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

# Deze gebruikt meerdere interface sheets :
# productinstance_interface_template.xlsx
# installedproduct_interface_template.xlsx
# componentdependency_interface_template.xlsx

my $template = 'productinstance_interface_template.xlsx';
my $version = "2066";					# Version Number

# output files
my ($CompSys, $InstP, $PrdCS, $PrdInstance, $PrdPrd, $Contact, $Service);

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
use ALU_Util qw(trim installed2instance getsource);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_execute);
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

sub init_outfiles($) {
  my ($source) = @_;

  # The '_os' suffix on the tabname is not present in the xlsx template sheets !

  # Instance Product Main File
  $CompSys = TM_CSV->new({ source => $source, comp_name => 'ProductInstance', tabname => 'Component', suffix => 'os', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # Installed Product
  $InstP = TM_CSV->new({ source => $source, comp_name => 'InstalledProduct', tabname => 'Component', suffix => 'os', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # Product Installed On ComputerSystem
  $PrdCS = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'PrdInstalledOnCS', suffix => 'os', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # Product Installed On ComputerSystem
  $PrdInstance = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'prdInstOfInstalledPrd', suffix => 'os', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # Installed Product CI relation to its Product
  $PrdPrd = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'PrdInstalledPrd', suffix => 'os', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # AssignedContactList
  $Contact = TM_CSV->new({ source => $source, comp_name => 'ProductInstance', tabname => 'AssignedContactList', suffix => 'os', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # ServiceLevelList
  $Service = TM_CSV->new({ source => $source, comp_name => 'ProductInstance', tabname => 'ServiceLevelList', suffix => 'os', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  return 1;
}

# ==========================================================================

=pod

=head2 Close OutFiles

This procedure will close all datafiles for output in an orderly fashion.

=cut

sub close_outfiles {
  # Product Instance Main File
  $CompSys->close or return;

  # InstalledProduct Main File
  $InstP->close or return;

  # Product Installed On ComputerSystem
  $PrdCS->close or return;

  # Product Installed - Product Instance
  $PrdInstance->close or return;

  # Installed Product CI relation to its Product
  $PrdPrd->close or return;

  # AssignedContactList
  $Contact->close or return;

  # ServiceLevelList
  $Service->close or return;

  return 1;
}

# ==========================================================================

sub get_assignment($$) {
  my ($dbt, $assignment_id) = @_;

  my $rtv = [ map { '' } 1 .. 2 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($assignment_id) > 0) && ($assignment_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT initial_assignment_group, escalation_assignment_group
  FROM assignment
  WHERE assignment_id = $assignment_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    $rtv = [ $ref->{initial_assignment_group} || "", $ref->{escalation_assignment_group} || "" ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_operations($$) {
  my ($dbt, $operations_id) = @_;

  my $rtv = [ map { '' } 1 .. 10 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($operations_id) > 0) && ($operations_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT op_cap_mgmt, op_shutdown_notes, op_backup_notes, op_patch_notes, op_startup_notes,
       op_total_size, op_total_used_size, op_restore, op_tx_log, op_daylight_savings
  FROM operations
  WHERE operations_id = $operations_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $op_cap_mgmt = $ref->{op_cap_mgmt} || "";
    my $op_shutdown_notes = $ref->{op_shutdown_notes} || "";
    my $op_backup_notes = $ref->{op_backup_notes} || "";
    my $op_patch_notes = $ref->{op_patch_notes} || "";
    my $op_startup_notes = $ref->{op_startup_notes} || "";
    my $op_total_size = $ref->{op_total_size} || "";
    my $op_total_used_size = $ref->{op_total_used_size} || "";
    my $op_restore = $ref->{op_restore} || "";
    my $op_tx_log = $ref->{op_tx_log} || "";
    my $op_daylight_savings = $ref->{op_daylight_savings} || "";

    $rtv = [ $op_cap_mgmt, $op_shutdown_notes, $op_backup_notes, $op_patch_notes, $op_startup_notes, $op_total_size, $op_total_used_size, $op_restore, $op_tx_log, $op_daylight_savings ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_availability($$) {
  my ($dbt, $availability_id) = @_;

  my $rtv = [ map { '' } 1 .. 5 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($availability_id) > 0) && ($availability_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT runtime_environment, impact, service_level_code, servicecoverage_window, possible_downtime, slo
  FROM availability
  WHERE availability_id = $availability_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $runtime_environment = $ref->{runtime_environment} || "";
    my $impact = $ref->{impact} || "";

    # Note: as part of ENUMERATION Meeting service_level_code is replaced with slo
    # my $service_level_code = $ref->{service_level_code} || ""; # not used
    my $slo = $ref->{slo} || "";

    my $servicecoverage_window = $ref->{servicecoverage_window} || "24x7 (00:00-24:00 Mon-Sun)";
    my $possible_downtime = $ref->{possible_downtime} || "";

    $rtv = [ $runtime_environment, $impact, $slo, $servicecoverage_window, $possible_downtime ];
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

sub handle_comp($$) {
  my ($dbt, $source) = @_;

  # Get Instance Product Data from Installed Application table
  my $query = "SELECT o.operatingsystem_id, os_name, os_version, time_zone,
					    c.source_system_element_id, fqdn, application_tag,
						availability_id
				 FROM operatingsystem o, computersystem c, application a
				 WHERE o.operatingsystem_id = c.operatingsystem_id
				   AND o.application_id = a.application_id
				   AND computersystem_source like '$source%'";
  my $sth = $dbt->prepare($query);
  my $rv = $sth->execute();
  if (not defined $rv) {
    ERROR("Could not execute query $query, Error: ".$sth->errstr);
    return;
  }

  while (my $ref = $sth->fetchrow_hashref) {

    # Instance Product Component
    my $application_instance_id = $ref->{operatingsystem_id};
    my $fqdn = $ref->{fqdn} || "";
    # 20120402DV - TechnicalKey consistent across sources
    # my $InstanceID = "$fqdn * " . $ref->{operatingsystem_id};
    # Remove leading and trailing spaces
    $fqdn = trim($fqdn);
    my $InstanceID = "os.$fqdn";
    my $ProductInstance_Name = $ref->{os_name} || "";
    my $Product_Instance = "OperatingSystemInstance";
    my $Business_Description = "OS Business Description";
    my $operational_status = "In Production";
    my $Time_Zone = $ref->{time_zone} || "(GMT+01:00) Brussels, Copenhagen, Madrid, Paris";
    my $SarbanesOxleyActCompliant = "";
    my $ClusterType = "";
    my $ConnectString = "";
    my $PackageName = "";
    my $MngtAccount = "";
    my $LicenseNotes = "";
    my $AdditionalNotes = "";
    my $NumberUsers = "";
    my $Jobs = "";
    my $InstanceVersion = $ref->{os_version} || "";
    my $Critical_Application = "FALSE";	# Critical Application identifier should not be used - only in Portfolio File
    # ComputerSystem NSA is attribute of the ComputerSystem, not OS.
    # NSA only in Portfolio File and for Solutions
    my $NSA_Restricted = "FALSE";
    my $ListenerPort = "";
    my $URL = "";
    my $SourceSystemElementID = $ref->{source_system_element_id} || "";
    my $hpOwned = "UNKNOWN";
    my $hpManaged = "UNKNOWN";
    my $application_tag = $ref->{application_tag} || "";

    # assignment_id, billing_id and operations_id are not used. This is historic (started from a copy of create_product_instance.pl)
    # This is ok, it is not a bug.
    # Assignment Information
    #my $assignment_id = $ref->{assignment_id} || "";
    #my ($AssignmentGroup, $EscalationAssignmentGroup) = get_assignment($dbt, $assignment_id) or return;
    my ($AssignmentGroup, $EscalationAssignmentGroup) = map { '' } 1 .. 2;

    # Availability Information
    my $availability_id = $ref->{availability_id} || "";
    my ($Environment, $Impact, $serviceLevel, $serviceCoverageWindow, $planned_Outage_Coverage_Details) = get_availability($dbt, $availability_id) or return;

    # Billing Information
    #my $billing_id = $ref->{billing_id} || "";
    #my ($Billing_ResourceUnit_code, $Billing_Change_request_ID, $Billing_Change_Category, $Billing_Change_Date) = get_billing($dbt, $billing_id) or return;
    my ($Billing_ResourceUnit_code, $Billing_Change_request_ID, $Billing_Change_Category, $Billing_Change_Date) = map { '' } 1 .. 4;

    # get_contactrole($dbt, $application_instance_id, $InstanceID, $source, \@subbus_arr);

    # Operations Information
    #my $operations_id = $ref->{operations_id} || "";
    #my ($CapacityNotes, $ShutdownNotes, $BackupNotes, $PatchNotes, $StartupNotes,
    #    $TotalSize, $UsedSize, $RestoreNotes, $TransactionLogNotes, $DaylightSavings) = get_operations($dbt, $operations_id) or return;

    my ($CapacityNotes, $ShutdownNotes, $BackupNotes, $PatchNotes, $StartupNotes,
       $TotalSize, $UsedSize, $RestoreNotes, $TransactionLogNotes, $DaylightSavings) = map { '' } 1 .. 10;

    # To Be Defined
    my $ImpactDescription = "";
    my $Language = "";	# Will be removed from template
    my $Search_Code = "";

    # Print Information to Instance Product output file
    # (DB Instance/SID) InstanceID, Product Instance, ProductInstance Name, Business Description,
    # Instance Environment, Instance Operational Status, Impact, Billing ResourceUnit code, Billing
    # Change request ID, Billing Change Category, Billing Change Date, Time Zone,
    # SarbanesOxleyActCompliant, ClusterType, ConnectString, PackageName, MngtAccount,
    # AssignmentGroup, CapacityNotes, ShutdownNotes, LicenseNotes, AdditionalNotes, BackupNotes,
    # PatchNotes, StartupNotes, TotalSize, UsedSize, NumberUsers, Jobs, InstanceVersion, Critical
    # Application, NSA Restricted, ImpactDescription, Language, hpOwned, hpManaged, Search Code,
    # SourceSystemElementID

    # BUG 322 : TargetSystemType is erbij gekomen XXX => vanwaar moet dat komen ??
    # en TargetSystemType is weer weg gehaald.

	# Bug 402 - New template implemented

    unless ($CompSys->write($InstanceID, $Product_Instance, $ProductInstance_Name, $Business_Description, $Environment,
                                $operational_status, $Impact, $Billing_ResourceUnit_code, $Billing_Change_request_ID,
                                $Billing_Change_Category, $Billing_Change_Date, $Time_Zone, $SarbanesOxleyActCompliant,
                                $ClusterType, $ConnectString, $PackageName, $MngtAccount, $AssignmentGroup,
                                $TotalSize, $UsedSize, $Jobs, $InstanceVersion,
                                $ImpactDescription, $hpOwned, $hpManaged, $Search_Code, $SourceSystemElementID)) {
      ERROR("write CompSys failed");
      return;
    }


    my $InstalledProductID = installed2instance($InstanceID);

    # Installed Product Component
    # InstalledProductID, InstalledProduct, SourceSystemElementID
    unless ($InstP->write($InstalledProductID, 'InstalledProduct', $SourceSystemElementID)) {
      ERROR("write InstP failed");
      return;
    }

    # Relation Product Installed on ComputerSystem
    # FQDN, InstalledProductId, directory
    unless ($PrdCS->write($fqdn, $InstalledProductID, "")) {
      ERROR("write PrdCS failed");
      return;
    }

    # Relation Product Installed - Product Instance
    # ProductInstanceId, InstalledProductId
    unless ($PrdInstance->write($InstanceID, $InstalledProductID)) {
      ERROR("write PrdInstance failed");
      return;
    }

    # Installed Product CI Relation to its Product
    # ProductId, InstalledProductId
    unless ($PrdPrd->write($application_tag, $InstalledProductID)) {
      ERROR("write PrdPrd failed");
      return;
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

$summary_log->info("Create ProductInstance Extract for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

# Get Source system
my $sourcearr = getsource($dbt, "computersystem", "computersystem_source");

unless ($sourcearr) {
  ERROR("Found no sources in the computersystem table !");
  exit_application(1);
}

foreach my $source (@$sourcearr) {
  $summary_log->info("Processing ProductInstance data for Source $source");

  # Initialize datafiles for output
  init_outfiles($source) or exit_application(1);

  # Handle Data for Product Instance
  handle_comp($dbt, $source) or exit_application(1);

  # Handle Data for Installed Product
  close_outfiles() or exit_application(1);
}

exit_application(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
