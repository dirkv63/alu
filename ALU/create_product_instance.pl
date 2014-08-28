=head1 NAME

create_product_instance - This script will create a Product Data Template.

=head1 VERSION HISTORY

version 1.1 12 January 2012 DV

=over 4

=item *

Update Extract Process to exclude ESL Business Product Instances from the extract. The CIs ESL Business Product Instances are requested as Relation Attributes.

=back

version 1.0 16 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract instance product information for the instance product template.

=head1 SYNOPSIS

 create_product_instance.pl [-t] [-l log_dir]

 create_product_instance -h	Usage
 create_product_instance -h 1  Usage and description of the options
 create_product_instance -h 2  All documentation

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

# XXX Strange : the tabs 'SAPInstance' and 'ApplicationInstance' are not used !!
my $template = 'productinstance_interface_template.xlsx';
my $version = "2066";					# Version Number

# output files (these are hash refs to hash refs !)
my ($OutFiles);

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
use ALU_Util qw(getsource replace_cr translate);
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
  my ($type, $source, $subbusiness) = @_;

  # Installed Product Main File, AssignedContactList, ServiceLevelList, DBInstance, WebInstance
  my $type_map = { 'CompSys' => 'Component',
                   'Contact' => 'AssignedContactList',
                   'Service' => 'ServiceLevelList',
                   'DB'      => 'DBInstance',
                   'Web'     => 'WebInstance',
			       'Note'    => 'NoteList' };

  # only use sub-business names for ESL
  $subbusiness = '' unless ($source eq 'ESL');

  unless (exists $type_map->{$type}) { ERROR("Invalid output file type ($type), exiting ..."); return; }

  unless (exists $OutFiles->{$subbusiness}->{$type}) {

    my $subbusiness_suffix = ($subbusiness eq '' ) ? '' : '-' . $subbusiness;

    # open all the different file types at once (this was the old behaviour for non-ESL, keep it)
    my @type_list = ($source eq 'ESL') ? ($type) : (keys %$type_map);

    foreach my $t (@type_list) {

      unless (exists $OutFiles->{$subbusiness}->{$t}) {

        my $tabname = $type_map->{$t};

        $OutFiles->{$subbusiness}->{$t} = TM_CSV->new({ source => $source . $subbusiness_suffix, comp_name => 'ProductInstance',
                                                        tabname => $tabname, version => $version });
        unless ($OutFiles->{$subbusiness}->{$t}) {
          ERROR("Could not open output file, exiting...");
          return;
        }
      }
    }
  }

  return $OutFiles->{$subbusiness}->{$type};
}

# ==========================================================================

=pod

=head2 Close OutFiles

This procedure will close all datafiles for output in an orderly fashion.

=cut

sub close_outfiles {

  # Product Main File, AssignedContactList, ServiceLevelList, DBInstance and WebInstance
  foreach my $subbusiness (keys %$OutFiles) {
    foreach my $type (keys %{$OutFiles->{$subbusiness}}) {
      $OutFiles->{$subbusiness}->{$type}->close or return;
    }
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

sub get_application($$) {
  # Return String: ($DBInstanceType, $NSA_Restricted, $Critical_Application)
  my ($dbt, $application_id) = @_;

  # Initialize variables
  my $rtv = [ map { '' } 1 .. 3 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($application_id) > 0) && ($application_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT appl_name_acronym, nsa, business_critical
  FROM application
  WHERE application_id = $application_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $appl_name_acronym = $ref->{appl_name_acronym} || "";
    my $nsa = $ref->{nsa} || "";
    $nsa = (length($nsa) > 0) ? 'TRUE' : 'FALSE';

    my $business_critical = $ref->{business_critical} || "";
    $business_critical = (length($business_critical) > 0) ? 'TRUE' : 'FALSE';

    $rtv = [ $appl_name_acronym, $nsa, $business_critical ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_operations($$) {
  my ($dbt, $operations_id) = @_;

  # Initialize variables
  my $rtv = [ map { '' } 1 .. 10 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($operations_id) > 0) && ($operations_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT op_total_size, op_total_used_size, op_restore, op_tx_log, op_daylight_savings
  FROM operations
  WHERE operations_id = $operations_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $op_total_size = $ref->{op_total_size} || "";
    my $op_total_used_size = $ref->{op_total_used_size} || "";
    my $op_restore = $ref->{op_restore} || "";
    my $op_tx_log = $ref->{op_tx_log} || "";
    my $op_daylight_savings = $ref->{op_daylight_savings} || "";

    $rtv = [ $op_total_size, $op_total_used_size, $op_restore, $op_tx_log, $op_daylight_savings ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_availability($$) {
  my ($dbt, $availability_id) = @_;

  # Initialize variables
  my $rtv = [ map { '' } 1 .. 6 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($availability_id) > 0) && ($availability_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
 SELECT minimum_availability, runtime_environment, impact, service_level_code, servicecoverage_window, possible_downtime, slo
   FROM availability
   WHERE availability_id = $availability_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $minimum_availability = $ref->{minimum_availability} || "";

    my $runtime_environment = $ref->{runtime_environment} || "";
    my $impact = $ref->{impact} || "";

    # Note: as part of ENUMERATION Meeting service_level_code is replaced with slo
    #my $service_level_code = $ref->{service_level_code} || "";
    my $slo = $ref->{slo} || "";
    my $servicecoverage_window = $ref->{servicecoverage_window} || "24x7 (00:00-24:00 Mon-Sun)";
    my $possible_downtime = $ref->{possible_downtime} || "";

    $rtv = [ $minimum_availability, $runtime_environment, $impact, $slo, $servicecoverage_window, $possible_downtime ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_billing($$) {
  my ($dbt, $billing_id) = @_;
  # Initialize variables
  my $rtv = [ map { '' } 1 .. 5 ];

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

sub get_contactrole($$$$$) {
  my ($dbt, $application_instance_id, $InstanceID, $source, $subbus_arr_ref) = @_;

  # Get Values
  my $sth = do_execute($dbt, "
SELECT contact_type, preferred_contact_method, contact_for_patch, firstname, lastname, email, person_code
  FROM contactrole c, person p
  WHERE c.application_instance_id = $application_instance_id
    AND c.person_id = p.person_id") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    # Initialize Variables
    my $contact_by_phone = "FALSE";
    my $contact_by_mail = "FALSE";
    # Process Variables
    my $Instance_Contact_Role = $ref->{contact_type} || "";
    my $preferred_contact_method = $ref->{preferred_contact_method} || "";
    if (lc($preferred_contact_method) eq "phone") {
      $contact_by_phone = "TRUE";
    } elsif (lc($preferred_contact_method) eq "mail") {
      $contact_by_mail = "TRUE";
    }
    my $Contact_for_Patch = $ref->{contact_for_patch} || "";
    if (length($Contact_for_Patch) > 0) {
      $Contact_for_Patch = "TRUE";
    } else {
      $Contact_for_Patch = "FALSE";
    }

    #my $Contact_Name = $ref->{firstname} || "";
    #my $Contact_Surname = $ref->{lastname} || "";
    my $ContactID = $ref->{person_code} || "";
    #my $Contact_email_address = $ref->{email} || "";

    foreach my $subbusiness (@$subbus_arr_ref) {
      # get the file handle for this sub business
      my $FH = init_outfiles('Contact', $source, $subbusiness) or return;

      # (DB Instance/SID) InstanceID, ContactID, Instance Contact Role, contact by phone, contact by mail, Contact for Patch
      unless ($FH->write($InstanceID, $ContactID, $Instance_Contact_Role, $contact_by_phone, $contact_by_mail, $Contact_for_Patch))
        { ERROR("write Contact failed"); return; }
    }
  }

  return 1;
}

# ==========================================================================

sub get_notes($$$$$) {
  my ($dbt, $application_instance_id, $InstanceID, $source, $subbus_arr_ref) = @_;

  # Get Values
  my $sth = do_execute($dbt, "
SELECT note_type, note_value
  FROM notes
  WHERE computersystem_id = $application_instance_id
") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    # Process Variables
    my $NoteTypeCode = $ref->{note_type} || "";
    my $NoteComment = $ref->{note_value} || "";
    foreach my $subbusiness (@$subbus_arr_ref) {
      # get the file handle for this sub business
      my $FH = init_outfiles('Note', $source, $subbusiness) or return;

      # (DB Instance/SID) InstanceID, NoteTypeCode, NoteComment
      unless ($FH->write($InstanceID, $NoteTypeCode, $NoteComment))
        { ERROR("write Note failed"); return; }
    }
  }

  return 1;
}

# ==========================================================================

=pod

=head2 ESL Subbusiness for ESL ID

ESL Technical Product Instances are implemened on Systems. The Transition Model expects these Technical Product Instance Components from the ESL Subbusiness, not from the ESL. Therefore for each Technical Product Instance, the ESL Sub Business is appended to the the Print Line in the CSV file. Another application will then extract the ESL Sub Business and put the line in the ESL Sub Business specific file.

This does not work for Application Instances, since an Application Instance is not a ESL Instance but an ESL Solution. As a first work-around, Application Instances will be added to the sub business ESL CMO Martinique.

ESL CMO Martinique will also be the default sub-business if no other sub-businesses can be found.

=cut

{
  # build a map of all esl_id => esl_subbusiness. This is (much) faster than performing one query for every esl_id.
  # (from 4 minutes to 10 seconds)

  my $esl_map;

  sub esl_subbusiness($$) {
    my ($dbt, $esl_id) = @_;

    #my $sth = do_execute($dbt, "SELECT esl_subbusiness FROM compsys_esl WHERE esl_id = $esl_id") or return;

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

    my $rtv = [ ];

    $rtv = [ @{ $esl_map->{$esl_id} } ] if (exists $esl_map->{$esl_id});

    # CMO Martinique as the default ESL Sub Business
    push @$rtv, 'CMO Martinique' if (@$rtv == 0);

    return wantarray ? @$rtv : $rtv;
  }

}

# ==========================================================================

sub handle_comp($$) {
  my ($dbt, $source) = @_;

  # Get Instance Product Data from Installed Application table
  # Do not get ESLBusinessProductInstance since these CIs are
  # the additional attributes in relation cd_appInstDependsUponCS

  my $sth = do_execute($dbt, "
SELECT application_instance_id, appl_name_long, instance_category, appl_name_description, lifecyclestatus, time_zone,
       sox_system, connectivity_instruction, cluster_package_name, ovsd_searchcode, version, listener_ports, managed_url,
       source_system_element_id, application_instance_tag, ci_owner_company, assignment_id, application_id,
       availability_id, billing_id, operations_id, appl_name_long, home_directory, connectivity_instruction
  FROM application_instance
  WHERE source_system like '$source%'
    AND NOT (instance_category = 'ESLBusinessProductInstance')") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    # Instance Product Component
    my $application_instance_id = $ref->{application_instance_id};
    my $ProductInstance_Name = $ref->{appl_name_long} || "";
    $ProductInstance_Name = replace_cr($ProductInstance_Name);
    my $Product_Instance = $ref->{instance_category} || "";
    my $Business_Description = $ref->{appl_name_description} || "Business Description";
    $Business_Description = replace_cr($Business_Description);
    my $Instance_Operational_Status = $ref->{lifecyclestatus} || "Unknown";
    my $Time_Zone = $ref->{time_zone} || "(GMT+01:00) Brussels, Copenhagen, Madrid, Paris";
    my $SarbanesOxleyActCompliant = $ref->{sox_system} || "Unknown";
    my $ClusterType = "To Be Defined";
    # XXXX FOUT : hier stond connectivity_instructions (met een 's' teveel !!!)
    my $ConnectString = $ref->{connectivity_instruction} || "";
    my $PackageName = $ref->{cluster_package_name} || "";
    my $Search_Code = $ref->{ovsd_searchcode} || "";

    # To Be Defined Section
    my $MngtAccount = "To Be Defined";
    my $LicenseNotes = "";
    my $AdditionalNotes = "";
    my $NumberUsers = ""; # field will be removed from template RDB 20120411
    my $Jobs = "";

    my $InstanceVersion = $ref->{version} || "";
    my $ListenerPort = $ref->{listener_ports} || "";
    my $URL = $ref->{managed_url} || "";
    my $SourceSystemElementID = $ref->{source_system_element_id} || "";
    my $InstanceID = $ref->{application_instance_tag} || "";

    # Get CI Ownership and Managemement
    my ($hpOwned, $hpManaged);
    my $ci_owner_company = $ref->{ci_owner_company} || "";
    if (index(lc($ci_owner_company), "retained") > -1) {
      $hpOwned = "FALSE";
      $hpManaged = "FALSE";
    } elsif (index(lc($ci_owner_company), "alu owned") > -1) {
      $hpOwned = "FALSE";
      $hpManaged = "TRUE";
    } elsif (index(lc($ci_owner_company), "hp") > -1) {
      $hpOwned = "TRUE";
      $hpManaged = "TRUE";
    } elsif ($source eq "ESL") {
      # IF ESL is source and ci_owner_company is not one of the previous values,
      # then I don't know (Previously: hpOwned, hpManaged is a safe guess)
      $hpOwned = "UNKNOWN";
      $hpManaged = "UNKNOWN";
    } else {
      $hpOwned = "UNKNOWN";
      $hpManaged = "UNKNOWN";
    }

    # Assignment Information
    # Get Information
    my $assignment_id = $ref->{assignment_id} || "";
    my ($AssignmentGroup, $EscalationAssignmentGroup) = get_assignment($dbt, $assignment_id) or return;

    # Application Information
    # Get Information
    my $application_id = $ref->{application_id} || "";
    my ($DBInstanceType, $NSA_Restricted, $Critical_Application) = get_application($dbt, $application_id) or return;

    # Availability Information
    # Get Information
    my $availability_id = $ref->{availability_id} || "";
    my ($MinAvailability, $InstanceEnvironment, $Impact, $serviceLevel, $serviceCoverageWindow,
        $planned_Outage_Coverage_Details) = get_availability($dbt, $availability_id) or return;

    # Billing Information
    # Get Information
    my $billing_id = $ref->{billing_id} || "";
    my ($Billing_ResourceUnit_code, $Billing_Change_request_ID, $Billing_Change_Category,
        $Billing_Change_Date) = get_billing($dbt, $billing_id) or return;

    # Get SubBusiness Array for ESL Instances
    my @subbus_arr = ('');

    if ($source eq 'ESL') {
      @subbus_arr = esl_subbusiness($dbt, $SourceSystemElementID) or return;
    }

    get_contactrole($dbt, $application_instance_id, $InstanceID, $source, \@subbus_arr) or return;
    get_notes($dbt, $application_instance_id, $InstanceID, $source, \@subbus_arr) or return;

    # Operations Information
    # Get Information
    my $operations_id = $ref->{operations_id} || "";
    my ($TotalSize, $UsedSize, $RestoreNotes, $TransactionLogNotes, $DaylightSavings) = get_operations($dbt, $operations_id) or return;

    # To Be Defined
    my $ImpactDescription = "";
    my $Language = "";	# Will be removed from template

    foreach my $subbusiness (@subbus_arr) {
      # get the file handle for this sub business
      my $CompSys_FH = init_outfiles('CompSys', $source, $subbusiness) or return;

      # Print Information to Instance Product output file

      # (DB Instance/SID) InstanceID, Product Instance, ProductInstance Name, Business Description,
      # Instance Environment, Instance Operational Status, Impact, Billing ResourceUnit code,
      # Billing Change request ID, Billing Change Category, Billing Change Date, Time Zone,
      # SarbanesOxleyActCompliant, ClusterType, ConnectString, PackageName, MngtAccount,
      # AssignmentGroup, 
      # TotalSize, UsedSize, Jobs, InstanceVersion, 
      # ImpactDescription, hpOwned, hpManaged, Search Code,
      # SourceSystemElementID

      # XXX laatste twee zijn gewisseld !
      unless ($CompSys_FH->write($InstanceID, $Product_Instance, $ProductInstance_Name, $Business_Description, $InstanceEnvironment,
                                $Instance_Operational_Status, $Impact, $Billing_ResourceUnit_code, $Billing_Change_request_ID,
                                $Billing_Change_Category, $Billing_Change_Date, $Time_Zone, $SarbanesOxleyActCompliant,
                                $ClusterType, $ConnectString, $PackageName, $MngtAccount, $AssignmentGroup, 
                                $TotalSize, $UsedSize, $Jobs, $InstanceVersion, 
                                $ImpactDescription, $hpOwned, $hpManaged, $Search_Code, $SourceSystemElementID ))
        { ERROR("write CompSys failed"); return; }


      # get the file handle for this sub business
      my $Service_FH = init_outfiles('Service', $source, $subbusiness) or return;

      # Print Information to ServiceLevelList
      # (DB Instance/SID) InstanceID, serviceLevel, serviceCoverageWindow, planned Outage Coverage Details, InitialAssignmentGroup, EscalationAssignmentGroup
      unless ($Service_FH->write($InstanceID, $serviceLevel, $serviceCoverageWindow, $planned_Outage_Coverage_Details,
                                 $AssignmentGroup, $EscalationAssignmentGroup, $MinAvailability))
        { ERROR("write Service failed"); return; }
    }

    if (lc($Product_Instance) eq "dbinstance") {
      # Translation table (a7_solutions, Oper systems) has translation from A7/OVSD Operating System value to ESL Solution
      $DBInstanceType = translate($dbt, "a7_solutions", "Oper System", $DBInstanceType, "ErrMsg");
      my $BusinessInstance = $ref->{appl_name_long} || "";
      my $HomeDirectory = $ref->{home_directory} || "";
      my $ConnectionNotes = $ref->{connectivity_instruction} || "";

      # Print Information to DBInstance
      # (DB Instance/SID) InstanceID, DBInstanceType, BusinessInstance, HomeDirectory, ListenerPort, ConnectionNotes,
      # RestoreNotes, TransactionLogNotes, DaylightSavings

      foreach my $subbusiness (@subbus_arr) {
        my $DB_FH = init_outfiles('DB', $source, $subbusiness) or return;

        unless ($DB_FH->write($InstanceID, $DBInstanceType, $BusinessInstance, $HomeDirectory, $ListenerPort, $ConnectionNotes,
                              $RestoreNotes, $TransactionLogNotes, $DaylightSavings))
          { ERROR("write DB failed"); return; }
      }
    }
    elsif (lc($Product_Instance) eq "webinstance") {
      # Print Information to WebInstance
      # InstanceID, InstanceName, VirtualNode, URLMonitorFlag, URLRepsonseTimes, URL

      foreach my $subbusiness (@subbus_arr) {
        my $Web_FH = init_outfiles('Web', $source, $subbusiness) or return;

        unless ($Web_FH->write($InstanceID, $ProductInstance_Name, '', '','', $URL))
          { ERROR("write Web failed"); return; }
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

$summary_log->info("Create ProductInstance Extract for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

# Get Source system

my $sourcearr = getsource($dbt, "application_instance", "source_system");

unless ($sourcearr) {
  ERROR("Found no sources in the cim.application_instance table !");
  exit_application(1);
}

foreach my $source (@$sourcearr) {
  $summary_log->info("Processing ProductInstance data for Source $source");

  # Handle Data for Product
  handle_comp($dbt, $source) or exit_application(1);

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
