=head1 NAME

create_computersystem - This script will create a Computersystem Template

=head1 VERSION HISTORY

version 1.0 10 August 2011 DV

=over 4

=item *

Initial release.

=back

version 1.1 01 September 2011 DV

=over 4

Update to version 0.3 of Computersystem Template.

=back

=head1 DESCRIPTION

This script will extract computersystem information for the computersystem template.

=head1 SYNOPSIS

 create_computersystem.pl [-t] [-l log_dir]

 create_computersystem -h	Usage
 create_computersystem -h 1  Usage and description of the options
 create_computersystem -h 2  All documentation

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

my $template = 'ComputerSystem_interface_template.xlsx';
my $version = "2324";					# Version Number
# output files
my ($CompSys, $ServiceLevel, $ServiceFunction_FH, $SystemUsage, $Notes, $Contacts, $Remote, $ESL, $SrvrHw, $Backup);

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
use DbUtil qw(db_connect do_execute);
use ALU_Util qw(get_field get_info_type getsource hw_tag replace_cr translate val_available);
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

  # Initialize datafiles for output

  # ComputerSystem Main File

  $CompSys = TM_CSV->new({ source => $source, comp_name => 'ComputerSystem', tabname => 'Component', version => $version });

  unless ($CompSys) {
    ERROR("Could not open output file, exiting...");
    return;
  }

  # System Identification File
#  $SysId = TM_CSV->new({ source => $source, comp_name => 'ComputerSystem', tabname => 'SystemIdentification', version => $version });
#
#  unless ($SysId) {
#    ERROR("Could not open output file, exiting...");
#    return;
#  }

  # System Configuration File
#  $SysCfg = TM_CSV->new({ source => $source, comp_name => 'ComputerSystem', tabname => 'SystemConfiguration', version => $version });
#
#  unless ($SysCfg) {
#    ERROR("Could not open output file, exiting...");
#    return;
#  }

  # Service File
  $ServiceLevel = TM_CSV->new({ source => $source, comp_name => 'ComputerSystem', tabname => 'ServiceLevelList', version => $version });

  unless ($ServiceLevel) {
    ERROR("Could not open output file, exiting...");
    return;
  }

  # Service Function
  $ServiceFunction_FH = TM_CSV->new({ source => $source, comp_name => 'ComputerSystem', tabname => 'ServiceFunctionList', version => $version });

  unless ($ServiceFunction_FH) {
    ERROR("Could not open output file, exiting...");
    return;
  }

  # Service Usage
  $SystemUsage = TM_CSV->new({ source => $source, comp_name => 'ComputerSystem', tabname => 'SystemUsageList', version => $version });

  unless ($SystemUsage) {
    ERROR("Could not open output file, exiting...");
    return;
  }

  # Notes File
  $Notes = TM_CSV->new({ source => $source, comp_name => 'ComputerSystem', tabname => 'NoteList', version => $version });

  unless ($Notes) {
    ERROR("Could not open output file, exiting...");
    return;
  }

  # Contacts File
  $Contacts = TM_CSV->new({ source => $source, comp_name => 'ComputerSystem', tabname => 'AssignedContactList', version => $version });

  unless ($Contacts) {
    ERROR("Could not open output file, exiting...");
    return;
  }

  # Remote Access File
  $Remote = TM_CSV->new({ source => $source, comp_name => 'ComputerSystem', tabname => 'RemoteAccessList', version => $version });

  unless ($Remote) {
    ERROR("Could not open output file, exiting...");
    return;
  }

  # ESL File
  $ESL = TM_CSV->new({ source => $source, comp_name => 'ComputerSystem', tabname => 'ESL', version => $version });

  unless ($ESL) {
    ERROR("Could not open output file, exiting...");
    return;
  }

  # Backup File
  $Backup = TM_CSV->new({ source => $source, comp_name => 'ComputerSystem', tabname => 'StorageBackup', version => $version });

  unless ($Backup) {
    ERROR("Could not open output file, exiting...");
    return;
  }


  # PhysicalServerOnHardware
  # Relations => Do not use $comp_name, use "Relations" instead!
  $SrvrHw = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'physicalSrvrOnHardware', version => $version });

  unless ($SrvrHw) {
    ERROR("Could not open output file, exiting...");
    return;
  }

  return 1;
}

# ==========================================================================

=pod

=head2 Close OutFiles

This procedure will close all datafiles for output in an orderly fashion.

=cut

sub close_outfiles {

  # ComputerSystem
  $CompSys->close or return;

  # System Identification
#  $SysId->close or return;

  # System Configuration
#  $SysCfg->close or return;

  # ServiceLevel
  $ServiceLevel->close or return;

  # Service Function
  $ServiceFunction_FH->close or return;

  # Service Usage
  $SystemUsage->close or return;

  # Notes
  $Notes->close or return;

  # Contacts
  $Contacts->close or return;

  # Remote
  $Remote->close or return;

  # ESL
  $ESL->close or return;

  $Backup->close or return;

  # PhysicalServerOnHardware
  $SrvrHw->close or return;

  return 1;
}

# ==========================================================================

sub get_os($$) {
  my ($dbt, $operatingsystem_id) = @_;

  # Initialize Variables
  my $rtv = [ map { '' } 1 .. 4 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($operatingsystem_id) > 0) && ($operatingsystem_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT os_type, os_version, os_language, time_zone
  FROM operatingsystem
  WHERE operatingsystem_id = $operatingsystem_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $os_type = $ref->{os_type} || "";
    my $os_version = $ref->{os_version} || "";
    my $os_language = $ref->{os_language} || "";
    my $time_zone = $ref->{time_zone} || "";

    $rtv = [ $os_type, $os_version, $os_language, $time_zone ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_admin($$) {
  my ($dbt, $admin_id) = @_;

  # Initialize Variables
  my $rtv = [ map { '' } 1 .. 7 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($admin_id) > 0) && ($admin_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT management_region, sox_system, security_level, application_type_group, nsa, service_provider, lifecyclestatus
  FROM admin
  WHERE admin_id = $admin_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $management_region = $ref->{management_region} || "";
    my $sox_system = $ref->{sox_system} || "";
    my $security_level = $ref->{security_level} || "";
    my $application_type_group = $ref->{application_type_group} || "";
    my $nsa = $ref->{nsa} || "FALSE";
    my $service_provider = $ref->{service_provider} || "";
    my $lifecyclestatus = $ref->{lifecyclestatus} || "";
    $rtv = [ $management_region, $sox_system, $security_level, $application_type_group, $nsa, $service_provider, $lifecyclestatus ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_availability($$) {
  my ($dbt, $availability_id) = @_;

  # Initialize Variables
  my $rtv = [ map { '' } 1 .. 8 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($availability_id) > 0) && ($availability_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT minimum_availability, runtime_environment, impact, impact_description, service_level_code, servicecoverage_window, possible_downtime, slo
  FROM availability
  WHERE availability_id = $availability_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $minimum_availability = $ref->{minimum_availability} || "";
    my $runtime_environment = $ref->{runtime_environment} || "";
    my $impact = $ref->{impact} || "";
    my $impact_description = $ref->{impact_description} || "";
    my $service_level_code = $ref->{service_level_code} || "";
    my $servicecoverage_window = $ref->{servicecoverage_window} || "";
    my $possible_downtime = $ref->{possible_downtime} || "";
    my $slo = $ref->{slo} || "";

    $rtv = [ $minimum_availability, $runtime_environment, $impact, $impact_description, $service_level_code, $possible_downtime, $servicecoverage_window, $slo ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_assignment($$) {
  my ($dbt, $assignment_id) = @_;

  # Initialize Variables
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

sub get_billing($$) {
  my ($dbt, $billing_id) = @_;

  # Initialize Variables
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

sub get_cluster($$) {
  my ($dbt, $cluster_id) = @_;

  # Initialize Variables
  my $rtv = [ map { '' } 1 .. 2 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($cluster_id) > 0) && ($cluster_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT cluster_architecture, cluster_technology
  FROM cluster
  WHERE cluster_id = $cluster_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $cluster_architecture = $ref->{cluster_architecture} || "";
    my $cluster_technology = $ref->{cluster_technology} || "";
    $rtv = [ $cluster_architecture, $cluster_technology ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_virtual_ci($$) {
  my ($dbt, $virtual_ci_id) = @_;

  # Initialize Variables
  my $rtv = [ map { '' } 1 .. 2 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($virtual_ci_id) > 0) && ($virtual_ci_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT virtualization_role, virtualization_technology
  FROM virtual_ci
  WHERE virtual_ci_id = $virtual_ci_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $virtualization_role = $ref->{virtualization_role} || "";
    my $virtualization_technology = $ref->{virtualization_technology} || "";

    $rtv = [ $virtualization_role, $virtualization_technology ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_diskspace($$) {
  my ($dbt, $diskspace_id) = @_;

  # Initialize Variables
  my $rtv = [ map { '' } 1 .. 2 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($diskspace_id) > 0) && ($diskspace_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT available_diskspace, used_diskspace
  FROM diskspace
  WHERE diskspace_id = $diskspace_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $available_diskspace = $ref->{available_diskspace} || "";
    my $used_diskspace = $ref->{used_diskspace} || "";

    $rtv = [ $available_diskspace, $used_diskspace ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_compsys_esl($$) {
  my ($dbt, $compsys_esl_id) = @_;

  # Initialize variables
  my $rtv = [ map { '' } 1 .. 4 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($compsys_esl_id) > 0) && ($compsys_esl_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT esl_category, esl_subbusiness, esl_system_type
  FROM compsys_esl
  WHERE compsys_esl_id = $compsys_esl_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $esl_category = $ref->{esl_category} || "";
    my $esl_business = 'Alcatel-Lucent'; # hardcoded value
    my $esl_subbusiness = $ref->{esl_subbusiness} || "";
    my $esl_system_type = $ref->{esl_system_type} || "";
    $rtv = [ $esl_category, $esl_business, $esl_subbusiness, $esl_system_type ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_processor($$) {
  my ($dbt, $processor_id) = @_;
  # Initialize Variables
  my $rtv = [ map { '' } 1 .. 1 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($processor_id) > 0) && ($processor_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT enabled_cores
  FROM processor
  WHERE processor_id = $processor_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $enabled_cores = $ref->{enabled_cores} || "";
    $rtv = [ $enabled_cores ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================
# From here on, subs that write out
# ==========================================================================

sub get_contactrole($$$) {
  my ($dbt, $computersystem_id, $fqdn) = @_;
  # Initialize Variables
  # Get Values
  my $sth = do_execute($dbt, "
SELECT contact_type, preferred_contact_method, contact_for_patch, firstname, lastname, email, person_code
  FROM contactrole c, person p
  WHERE c.computersystem_id = $computersystem_id
    AND c.person_id = p.person_id") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    # Initialize Variables
    my $contact_by_phone = "FALSE";
    my $contact_by_mail = "TRUE";
    # Process Variables
    my $CS_Contact_Role = $ref->{contact_type} || "";
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
    my $ContactID = $ref->{person_code} || "";

    unless ($Contacts->write($fqdn, $ContactID, $CS_Contact_Role, $contact_by_phone, $contact_by_mail, $Contact_for_Patch)) {
      ERROR("write Contacts failed");
      return;
    }
  }
  return 1;
}

# ==========================================================================

sub get_ip_connectivity($$$) {
  my ($dbt, $computersystem_id, $fqdn) = @_;
  # Initialize Variables
  # Get Values
  my $sth = do_execute($dbt, "
SELECT c.ip_type, c.ip_connectivity_id, a.network_id_type, a.network_id_value
  FROM ip_connectivity c, ip_attributes a
  WHERE c.computersystem_id = $computersystem_id
    AND c.ip_connectivity_id = a.ip_connectivity_id") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    my $Network_Identity_Role = $ref->{ip_type} || "";
    my $Network_Identity_Role_Label = $ref->{ip_connectivity_id} || "";
    my $Network_Identity_Type = $ref->{network_id_type} || "";
    my $Network_Identity_Value = $ref->{network_id_value} || "";
    # Now find if the Network information is Identity or Configuration Information
    my $network_info = get_info_type($Network_Identity_Role);
    if ($network_info eq "Identification") {
#      unless ($SysId->write($fqdn, $Network_Identity_Role, $Network_Identity_Role_Label, $Network_Identity_Type, $Network_Identity_Value)) {
#        ERROR("write SysId failed");
#        return;
#      }
    } elsif ($network_info eq "Configuration") {
#      unless ($SysCfg->write($fqdn, $Network_Identity_Role, $Network_Identity_Role_Label, $Network_Identity_Type, $Network_Identity_Value)) {
#        ERROR("write SysCfg failed");
#        return;
#      }
    } elsif ($network_info eq "Ignore") {
      # Ignore the network information
    } else {
      # Error message - unknown network identity role
      ERROR("$fqdn - $Network_Identity_Role unknown Network Identity Role");
    }
  }
  return 1;
}

# ==========================================================================

sub get_notes($$$) {
  my ($dbt, $computersystem_id, $fqdn) = @_;
  #Initialize Variables
  # Get Values
  my $sth = do_execute($dbt, "
SELECT note_type, note_value
  FROM notes
  WHERE computersystem_id = $computersystem_id") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    my $NoteTypeCode = $ref->{note_type} || "";
    my $NoteComment = $ref->{note_value} || "";
    unless ($Notes->write($fqdn, $NoteTypeCode, $NoteComment)) {
      ERROR("write Notes failed");
      return;
    }
  }
  return 1;
}

# ==========================================================================

sub get_servicefunction($$$) {
  my ($dbt, $computersystem_id, $fqdn) = @_;
  #Initialize Variables
  # Get Values
  my $sth = do_execute($dbt, "
SELECT servicegroup, servicefunction, serviceprovider
  FROM servicefunction
  WHERE computersystem_id = $computersystem_id") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    my $ServiceName = $ref->{servicegroup} || "";
    my $ServiceFunction = $ref->{servicefunction} || "";
    my $OrganisationName = $ref->{serviceprovider} || "";
    # REVIEW: TM Expects ServiceName and ServiceFunction Switched!!
    unless ($ServiceFunction_FH->write($fqdn, $ServiceFunction, $ServiceName, $OrganisationName)) {
      ERROR("write ServiceFunction_FH failed");
      return;
    }
  }

  return 1;
}

# ==========================================================================

sub get_systemusage($$$) {
  my ($dbt, $computersystem_id, $fqdn) = @_;
  #Initialize Variables
  my $primary = "";
  # Get Values
  my $sth = do_execute($dbt, "
SELECT system_service_usage_code, system_usage_details
  FROM system_usage
  WHERE computersystem_id = $computersystem_id") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    my $SystemUsageCode = $ref->{system_service_usage_code} || "";
    my $SystemUsageDetail = $ref->{system_usage_details} || "";
    unless ($SystemUsage->write($fqdn, $SystemUsageCode, $SystemUsageDetail, $primary)) {
      ERROR("write SystemUsage failed");
      return;
    }
  }

  return 1;
}

# ==========================================================================

sub get_remote_access($$$) {
  my ($dbt, $computersystem_id, $fqdn) = @_;
  # Initialize Variables
  # Get Values
  my $sth = do_execute($dbt, "
SELECT remote_console_ip, remote_console_name, remote_console_port, remote_console_notes, remote_console_type
  FROM remote_access_info
  WHERE computersystem_id = $computersystem_id") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    my $console_ip = $ref->{remote_console_ip} || "";
    my $console_name = $ref->{remote_console_name} || "";
    my $console_port = $ref->{remote_console_port} || "";
    my $console_notes = $ref->{remote_console_notes} || "";
    my $console_type = $ref->{remote_console_type} || "";
    unless ($Remote->write($fqdn, $console_type, $console_ip, $console_name, $console_port, $console_notes)) {
      ERROR("write Remote failed");
      return;
    }
  }

  return 1;
}

# ==========================================================================

sub get_backup($$$) {
  my ($dbt, $computersystem_id, $fqdn) = @_;

  # Get Values
  my $sth = do_execute($dbt, "
SELECT backup_storage, backup_retention, backup_mode, backup_schedule, backup_restartable,
       backup_server, backup_media_server, backup_information, backup_restore_procedures
  FROM backup
  WHERE computersystem_id = $computersystem_id") or return;

  while (my $ref = $sth->fetchrow_hashref) {

    my $backup_storage = $ref->{backup_storage} || '';
    my $backup_retention = $ref->{backup_retention} || '';
    my $backup_mode = $ref->{backup_mode} || '';
    my $backup_schedule = $ref->{backup_schedule} || '';
    my $backup_restartable = $ref->{backup_restartable} || '';
    my $backup_server = $ref->{backup_server} || '';
    my $backup_media_server = $ref->{backup_media_server} || '';
    my $backup_information = $ref->{backup_information} || '';
    my $backup_restore_procedures = $ref->{backup_restore_procedures} || '';

    # Print Information to Backup output file, if there is any
    # FQDN, BACKUP STORAGE, BACKUP RETENTION, BACKUP MODE, BACKUP SCHEDULE, BACKUP RESTARTABLE,
    # BACKUP SERVER, BACKUP MEDIA SERVER, BACKUP INFORMATION, BACKUP RESTORE PROCEDURES

    my @outarray = ($backup_storage, $backup_retention, $backup_mode, $backup_schedule, $backup_restartable,
                    $backup_server, $backup_media_server, $backup_information, $backup_restore_procedures);

    if (val_available(\@outarray) eq "Yes") {
      # Add FQDN at start of Array
      # Print to Backup file
      unless ($Backup->write($fqdn, @outarray)) {
        ERROR("write Backup failed");
        return;
      }
    }
  }

  return 1;
}

# ==========================================================================

sub handle_computersystem($$) {
  my ($dbt, $source) = @_;

  # Get Data
  my $sth = do_execute($dbt, "
SELECT computersystem_id, computersystem_source, fqdn, ci_owner_company, host_type, cs_type, admin_id,
       assignment_id, availability_id, billing_id, diskspace_id, compsys_esl_id, operatingsystem_id,
       ovsd_searchcode, processor_id, cluster_id, virtual_ci_id, physicalbox_tag, source_system_element_id
  FROM computersystem
  WHERE computersystem_source like '$source%'") or return;

  while (my $ref = $sth->fetchrow_hashref) {

    # Computer System
    my $computersystem_id = $ref->{computersystem_id};
    my $fqdn = $ref->{fqdn} || "";
    my $SystemType = $ref->{cs_type} || "";
    my $SourceSystemID = $ref->{computersystem_source} || "";
    my $hostType = $ref->{host_type} || "";
    my $SourceSystemElementID = $ref->{source_system_element_id} || "";
    my $SearchCode = $ref->{ovsd_searchcode} || "";
    my $CustomerRetained = $ref->{ci_owner_company} || "";
    my ($hpOwned, $hpManaged);
    if (index(lc($CustomerRetained), "hp") > -1) {
      $hpOwned = "TRUE";
      $hpManaged = "TRUE";
    } elsif (index(lc($CustomerRetained), "retained") > -1) {
      $hpOwned = "FALSE";
      $hpManaged = "FALSE";
    } else {
      $hpOwned = "UNKNOWN";
      $hpManaged = "UNKNOWN";
    }

    # Admin
    # Get Information
    my $admin_id = $ref->{admin_id} || 0;

    my ($managementRegion, $SarbanesOxleyActCompliant, $SecuritySensitivity, $PurposeFunction, $NSA, $ServiceProvider, $Operational_Status) = get_admin($dbt, $admin_id) or return;

    # Assignment
    # Get Information
    my $assignment_id = $ref->{assignment_id} || 0;
    my ($InitialAssignmentGroup, $EscalationAssignmentGroup) = get_assignment($dbt, $assignment_id) or return;

    # Availability
    # Get Information
    my $availability_id = $ref->{availability_id} || 0;
    my ($MinAvailability, $RuntimeEnvironment, $Impact, $ImpactDescription, $serviceLevel, $planned_Outage_Coverage_Details, $serviceCoverageWindow, $SLO) = get_availability($dbt, $availability_id) or return;
    $planned_Outage_Coverage_Details = replace_cr($planned_Outage_Coverage_Details);

    # Billing
    # Get Information
    my $billing_id = $ref->{billing_id} || 0;
    my ($Billing_ResourceUnit_code, $Billing_Change_request_ID, $Billing_Change_Category, $Billing_Change_Date) = get_billing($dbt, $billing_id) or return;

    get_contactrole($dbt, $computersystem_id, $fqdn) or return;

    # Cluster Information
    # Get Information
    my $cluster_id = $ref->{cluster_id} || 0;
    my ($ClusterArchitecture, $ClusterTechnology) = get_cluster($dbt, $cluster_id) or return;

    # Diskspace
    # Get Information
    my $diskspace_id = $ref->{diskspace_id} || "";
    my ($AvailableDiskSpace, $UsedDiskSpace) = get_diskspace($dbt, $diskspace_id) or return;

    # ESL Specific Values
    # Get Information
    my $compsys_esl_id = $ref->{compsys_esl_id} || "";
    my ($Category, $Business, $Sub_Business, $SystemType2) = get_compsys_esl($dbt, $compsys_esl_id) or return;

    # Here is something special happening : SystemType comes from $ref->{cs_type}.
    # If get_compsys_esl() found a record in the table compsys_esl, then SystemType is coming from there
    # To mimic the logic from before I have to duplicate the conditional expression from get_compsys_esl
    # This only has an impact for ESL :
    # $ref->{cs_type} comes from alu_cmdb.esl_cs_techn_gen.System Type
    # and cim.compsys_esl.esl_system_type comes from alu_cmdb.esl_cs_admin.System Type
    # The data in both source tables is indentical so id doesn't matter at all.

    if ((length($compsys_esl_id) > 0) && ($compsys_esl_id > 0)) {
      $SystemType = $SystemType2;
    }

    # IP Connectivity
    #get_ip_connectivity($dbt, $computersystem_id, $fqdn) or return;

    # Notes
    get_notes($dbt, $computersystem_id, $fqdn) or return;

    # Operating System
    # Get Information
    my $operatingsystem_id = $ref->{operatingsystem_id} || 0;
    my ($OSType, $OSVersion, $OSLanguage, $CurrentTimeZone) = get_os($dbt, $operatingsystem_id) or return;

    # Processor
    # Get Information
    my $processor_id = $ref->{processor_id} || 0;
    my ($number_of_logical_cores) = get_processor($dbt, $processor_id) or return;

    # Remote Access
    get_remote_access($dbt, $computersystem_id, $fqdn) or return;

    # Service Function
    get_servicefunction($dbt, $computersystem_id, $fqdn) or return;

    # System Usage
    get_systemusage($dbt, $computersystem_id, $fqdn) or return;

    # Backup
    get_backup($dbt, $computersystem_id, $fqdn) or return;

    # Relation Physical Server on Hardware
    my $AssetTag = $ref->{physicalbox_tag} || "";
    # Only extend AssetTag if data available
    # (not really required here, since hw_tag procedure will also verify if
    # data is available)
    if (length($AssetTag) > 0) {
      $AssetTag = hw_tag($AssetTag);
    }

    # Virtual Information
    # Get Information
    my $virtual_ci_id = $ref->{virtual_ci_id} || 0;
    my ($VirtualizationRole, $VirtualizationTechnology) = get_virtual_ci($dbt, $virtual_ci_id) or return;

    # Host Type
    # Cluster or Virtual Type?
    my ($cluster_type, $virtualization_role);
    # Virtualization
    $virtual_ci_id = $ref->{virtual_ci_id} || "";
    my @fields = ("virtual_ci_id");
    my (@vals) = map { eval ("\$" . $_ ) } @fields;
    # If Virtual CI ID is available
    if ( val_available(\@vals) eq "Yes") {
      $virtualization_role = get_field($dbt, "virtual_ci", "virtualization_role", \@fields, \@vals);
    } else {
      $virtualization_role = "";
    }
    # Cluster
    $cluster_id = $ref->{cluster_id} || "";
    @fields = ("cluster_id");
    (@vals) = map { eval ("\$" . $_ ) } @fields;
    # If Cluster ID is available
    if ( val_available(\@vals) eq "Yes") {
      $cluster_type = get_field($dbt, "cluster", "cluster_type", \@fields, \@vals);
    } else {
      $cluster_type = "";
    }
    if ((lc($virtualization_role) eq 'virtual guest') ||
        (lc($virtualization_role) eq 'farm')) {
      $hostType = $virtualization_role;
    } elsif ((lc($cluster_type) eq 'cluster') ||
             (lc($cluster_type) eq 'cluster package')) {
      $hostType = $cluster_type;
    } elsif (lc($cluster_type) eq 'cluster node') {
      $hostType = "Physical Server";
      $SystemType = "cluster node";
    } elsif (length($hostType) == 0) {
      $hostType = "Physical Server";
    }

    $hostType = translate($dbt, "computersystem", "cs_type", $hostType, "ErrMsg");

    # To Be Defined
    my $AssignedMemory = "";
    my $HyperThreadingEnabled = "FALSE";

    # Print Information to ComputerSystem output file
    unless ($CompSys->write($fqdn, $hostType, $SystemType, $Operational_Status, $RuntimeEnvironment, $Impact, $ImpactDescription, $managementRegion, $CurrentTimeZone, $SarbanesOxleyActCompliant, $HyperThreadingEnabled, $number_of_logical_cores, $SecuritySensitivity, $AssignedMemory, $AvailableDiskSpace, $UsedDiskSpace, $ClusterArchitecture, $ClusterTechnology, $VirtualizationRole, $VirtualizationTechnology, $Billing_ResourceUnit_code, $Billing_Change_request_ID, $Billing_Change_Category, $Billing_Change_Date, $NSA, $ServiceProvider, $hpOwned, $hpManaged, $SourceSystemElementID, $SearchCode, $PurposeFunction)) {
      ERROR("write CompSys failed");
      return;
    }

    my @outarray;
    # Print Information to Service Levels output file, if there is any
    @outarray = ($serviceLevel, $serviceCoverageWindow, $planned_Outage_Coverage_Details, $InitialAssignmentGroup, $EscalationAssignmentGroup, $MinAvailability);
    if (val_available(\@outarray) eq "Yes") {
      # Add FQDN at start of Array
      # Print to Service file
      unless ($ServiceLevel->write($fqdn, @outarray)) {
        ERROR("write ServiceLevel failed");
        return;
      }
    }

    # Print Information to ESL output file, if there is any
    @outarray = ($Category, $Business, $Sub_Business);
    if (val_available(\@outarray) eq "Yes") {
      # Add FQDN at start of Array
      # Print to ESL file
      unless ($ESL->write($fqdn, @outarray)) {
        ERROR("write ESL failed");
        return;
      }
    }

    # Print Relation Physical Server on Hardware
    @outarray = ($AssetTag);
    if (val_available(\@outarray) eq "Yes") {
      # Add FQDN at start of Array
      # Print to SrvrHw file
      unless ($SrvrHw->write($fqdn, @outarray)) {
        ERROR("write SrvrHw failed");
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

$summary_log->info("Create ComputerSystem Extract for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

# Get Source system
my $sourcearr = getsource($dbt, "computersystem", "computersystem_source");

unless ($sourcearr) {
  ERROR("Found no sources in the computersystem table !");
  exit_application(1);
}

foreach my $source (@$sourcearr) {
  $summary_log->info("Processing for Source $source");

  # Initialize datafiles for output
  init_outfiles($source) or exit_application(1);

  # Handle Data from ComputerSystem
  handle_computersystem($dbt, $source) or exit_application(1);

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
