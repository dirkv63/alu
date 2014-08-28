=head1 NAME

computersystem_from_ovsd - This script will extract the ComputerSystem Information from OVSD.

=head1 VERSION HISTORY

version 1.3 01 March 2012 DV

=over 4

=item *

Remove ESL Category Processing. In previous versions ESL Category contained Server category, which was wrong. ESL Category is only Trade / HP Trade or HP Infra, not used in OVSD.

=back

version 1.2 29 February 2012 DV

=over 4

=item *

Add Hosting Service (billing code 45) processing. Target system is ESL for these CIs.

=back

version 1.0 09 August 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the ComputerSystem information from OVSD.

=head1 SYNOPSIS

 computersystem_from_ovsd.pl [-t] [-l log_dir] [-c]

 computersystem_from_ovsd.pl -h    Usage
 computersystem_from_ovsd.pl -h 1  Usage and description of the options
 computersystem_from_ovsd.pl -h 2  All documentation

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

my ($computersystem_source_id, $clear_tables);

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
use ALU_Util qw(exit_application trim ovsd_person add_ip remove_cr fqdn_ovsd os_translation translate create_available_record update_record tx_resourceunit conv_date val_available ntranslate rval_available is_true);
use MyIp qw(IsValidIp);

use Data::Dumper;

#############
# subroutines
#############

# ==========================================================================

=pod

=head2 Handle Alias IP

This procedure will attempt to split up the field "ALIAS_NAMES (4000)" into IP aliases. Default behaviour is that the alias names are separated by commas. Sometimes there are semicolons.
Strip leading and trailing spaces and CR characters.

=cut

sub handle_alias_ip($$$) {
  my ($dbt, $computersystem_id, $alias_string) = @_;
  # split on , or ; or <CR>
  my @alias_arr = split /,|;|\r\n|\r|\n/, $alias_string;
  # remove leading and trailing blanks, also remove CR
  @alias_arr = map { trim $_ } @alias_arr;
  foreach my $alias (@alias_arr) {
    # Only add no blanks
    if (length($alias) > 0) {
      add_ip($dbt, $computersystem_id, "Alias", "", "IP Name", $alias);
    }
  }
}

# ==========================================================================

=pod

=head2 Handle Alternate IP Addresses

This procedure will split alternate IP Addresses into IP aliases. Default behaviour is that alternate IP Addresses are separated by commas. Sometimes there are semicolons or CR characters. Strip leading and trailing spaces and CR characters.

=cut

sub handle_alternate_ip($$$$$) {
  my ($dbt, $fqdn, $source_system_element_id, $computersystem_id, $alias_string) = @_;
  # split on , or ; or <CR>
  my @ip_array = split /,|;|\r\n|\r|\n/, $alias_string;
  # remove leading and trailing blanks, also remove CR
  @ip_array = map { trim $_ } @ip_array;
  # Get Valid IP Addresses
  foreach my $ip (@ip_array) {
    if (IsValidIp($ip)) {
      add_ip($dbt, $computersystem_id, "Alternate IP", "", "IP Address", $ip);
    } else {
      my $data_log = Log::Log4perl->get_logger('Data');
      $data_log->info("System $fqdn (CI ID: $source_system_element_id) alternate IP invalid format: ***$ip***");
    }
  }
}

# ==========================================================================

=head2 handle_person

This subroutine creates an N-M relation between person and computersystem.

ovsd_person creates a new person record.

=cut


sub handle_person($$$$$) {
  my ($dbt, $fname, $searchcode, $contactrole, $computersystem_id) = @_;

  if (length($fname) == 0) {
    # No Name defined, do nothing
    return;
  }

  my $person_id = ovsd_person($dbt, $fname, $searchcode);

  # IT Contact in OVSD is in Lastname, Firstname format
  # No email, no upi code, so key is LASTNAME.FIRSTNAME
  # Now assign role to person

  if (length($person_id) > 0) {
    my $contact_type = $contactrole;
    my @fields = ("contact_type", "person_id", "computersystem_id");
    my (@vals) = map { eval ("\$" . $_ ) } @fields;
    my $contactrole_id = create_available_record($dbt, "contactrole", \@fields, \@vals);
  }
}

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

$computersystem_source_id = "OVSD_".time;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("admin", "assignment", "availability", "billing", "compsys_esl",
                     "computersystem", "contactrole", "diskspace", "cluster", "virtual_ci",
                     "ip_attributes", "ip_connectivity", "maintenance_contract", "notes",
                     "operatingsystem", "processor", "remote_access_info", "servicefunction",
                     "system_usage", "backup") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

=pod

=head2 ComputerSystem Selection Criteria from OVSD

Status / Environment: include everything except Status inactive and Environment Decommissioned - see Meeting Minutes Workshop 29.09.2011.

Exclude RFSWORLD Devices - not part of contract. See email from Karen Ulven 9/02/2012 14:17.

Excluded ASB Devices, except for a small number of devices that are hosting services. see Mail Bill L'Hotta 22/03/12 15:39

=cut

# Check on number of columns
# This check has been done already on the Hardware script for OVSD.

my $sth = do_execute($dbs, "
SELECT `CIID`, `NAME`, `ALIAS_NAMES (4000)`, `DESCRIPTION 4000`,
       `CATEGORY`, `STATUS`, `ENVIRONMENT`, `Purpose/Function`,
       `SOX`, `NSA`, `SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE`,
       `REGION`, `IP ADDRESS`, `Secondary/Virtual IP Addresses (4000)`,
       `OS NAME`, `OS VER/REL/SP`, `REMOTE_ACCESS`, `TIME_ZONE`,
       `MAINTENANCE WINDOW`, `MAINTENANCE CONTRACT`, `COVERAGE END DATE`,
       `RESOURCE UNIT`, `BILLING CHANGE CATEGORY`, `BILLING REQUEST NUMBER`,
       `LAST BILLING CHANGE DATE`, `PARENT CATEGORY`,
       `SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE`, `OWNER PERSON NAME`,
       `ADMIN PRIMARY CONTACT NAME`, `ADMIN SECONDARY CONTACT NAME`,
       `OWNER PERSON SEARCH CODE`, `ADMIN PRIMARY CONTACT SEARCH CODE`,
       `ADMIN SECONDARY CONTACT SEARCH CODE`, `SEARCH CODE`, `NOTES`,
       `BACKUP STORAGE`, `BACKUP RETENTION`, `BACKUP MODE`, `BACKUP SCHEDULE`, `BACKUP RESTARTABLE`,
       `BACKUP SERVER`, `BACKUP MEDIA SERVER`, `BACKUP INFORMATION`, `BACKUP RESTORE PROCEDURES`
  FROM ovsd_servers
  WHERE (`MASTER_CMDB` IS NULL OR `MASTER_CMDB` <=> '' OR `MASTER_CMDB` = 'Mastered in AssetCenter and OVSD')
    AND NOT ((`STATUS` <=> 'inactive') AND (`ENVIRONMENT` <=> 'Decommissioned'))
    AND ((`PARENT CATEGORY` <=> 'System') OR (`PARENT CATEGORY` <=> 'Logical Entity'))
    AND NOT ((`SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE` <=> 'ASB-MANAGED') AND NOT (`RESOURCE UNIT` LIKE '45%'))
    AND NOT (`SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE` <=> 'RFS-MANAGED')
    AND NOT (`NAME` LIKE 'z-%')") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # ComputerSystem
        my ($isvirtual, $physicalbox_tag);
        my $source_system_element_id = $ref->{"CIID"} || "";
        my $computersystem_source = $computersystem_source_id;
        # Get FQDN as tag name
        my $fqdn = $ref->{"NAME"} || '';
        # Some FQDNs have <CR>, so they will get a <br>...
        $fqdn = remove_cr($fqdn);
        $fqdn = fqdn_ovsd($fqdn);
        # Get Virtual / Physical Box
        if (lc($ref->{"PARENT CATEGORY"}) eq "system") {
                $isvirtual = "FALSE";
                $physicalbox_tag = $fqdn;
        } else {
                $isvirtual = "TRUE";
                $physicalbox_tag = "";
        }
        # Set physicalbox tag to FQDN
        # This will require more thinking to distinguish between physical and logical systems!

        # Cluster and Virtual_CI Types
        my $virtualization_role = "";
        my $cluster_type = "";
        my $cs_type = $ref->{'CATEGORY'} || "";
        if ($cs_type eq "Virtual Server") {
                $virtualization_role = "Virtual Guest";
        } elsif ($cs_type eq "Server Farm") {
                $virtualization_role = "Farm";
                $fqdn = translate($dbt, "ovsd_servers", "NAME", $fqdn, "SourceVal");
        # Virtual Host can be Cluster Package or Alias (in case it is related to single server)
        # Set virtualization_role to Virtual Guest
        # But remove virtualization_role in cs_rels_from_ovsd_servers.pl
        # if we find that this is a Cluster Package.
        } elsif ($cs_type eq "Virtual Host") {
                $virtualization_role = "Virtual Guest";
        } elsif ($cs_type eq "Cluster") {
                $cluster_type = "Cluster";
        }
        # Translate cs_type and initiate host_type
        my $host_type = translate($dbt, "host_type", "CATEGORY", $cs_type, "ErrMsg");
        $cs_type = translate($dbt, "ovsd_servers", "CATEGORY", $cs_type, "ErrMsg");

        # Check to create virtual_ci_id
        my @fields = ("virtualization_role");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $virtual_ci_id = create_available_record($dbt, "virtual_ci", \@fields, \@vals);

        # Get Search Code
        my $ovsd_searchcode = $ref->{'SEARCH CODE'} || "";

        # Create ComputerSystem record ID, for further records
        @fields = ("computersystem_source", "fqdn", "host_type", "cs_type", "physicalbox_tag", "isvirtual",
                   "ovsd_searchcode", "source_system_element_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        defined (my $computersystem_id = create_available_record($dbt, "computersystem", \@fields, \@vals)) or exit_application(2);

        if ($computersystem_id eq '') {
          ERROR("Trying to create computersystem record, but no data available. Exiting...");
          exit_application(2);
        }

        # Handle Status and Environment
        my $lifecyclestatus = $ref->{"STATUS"} || "";
        my $runtime_environment = $ref->{"ENVIRONMENT"} || "";
        if (index(lc($runtime_environment),"transition") > -1) {
                $lifecyclestatus = "move to obsolescence";
                $runtime_environment = "Standby";
        } elsif (lc($lifecyclestatus) eq "active") {
                $lifecyclestatus = "in production";
                $runtime_environment = translate($dbt, "ovsd_servers", "ENVIRONMENT", $runtime_environment, "ErrMsg");
        } elsif (lc($lifecyclestatus) eq "inactive") {
                # In this case, lifecyclestatus depends on runtime environment
                # So twist in translation is required to avoid confusion in translation table.
                # "STATUS" / $runtime_environment combination is on purpose!!
                $lifecyclestatus = translate($dbt, "ovsd_servers", "STATUS", $runtime_environment, "ErrMsg");
                $runtime_environment = "Standby";
        } elsif (lc($lifecyclestatus) eq "new") {
                $lifecyclestatus = "installed in DC";
                # Don't go to tranlation table, it will cause duplicates
                if ((lc($runtime_environment) eq "being built") ||
                        (lc($runtime_environment) eq "reuse pool")) {
                        $runtime_environment = "Staging";
                } elsif (lc($runtime_environment) eq "non production") {
                        $runtime_environment = "Training";
                } else {
                        ERROR("Status New Environment $runtime_environment is not translated in CI Sync table");
                }
        } else {
                ERROR("Status $lifecyclestatus Environment $runtime_environment is not translated in CI Sync table");
        }

        # Admin
        my $application_type_group = $ref->{"Purpose/Function"} || "";
        my $management_region = $ref->{"REGION"} || "";
        $management_region = translate($dbt, "ovsd_servers", "REGION", $management_region, "SourceVal");
        my $sox_system = $ref->{"SOX"} || "";
        if (lc($sox_system) eq "yes") {
                $sox_system = "SOX";
        } else {
                $sox_system = "";
        }
        my $nsa = $ref->{"NSA"} || "";
        if (lc($nsa) eq "yes") {
                $nsa = "TRUE";
        } else {
                $nsa = "FALSE";
        }
        @fields = ("lifecyclestatus", "management_region", "application_type_group", "sox_system", "nsa");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        defined (my $admin_id = create_available_record($dbt, "admin", \@fields, \@vals)) or exit_application(2);

        # Availability
        my $possible_downtime = $ref->{"MAINTENANCE WINDOW"} || "";
        # Create Availability
        @fields = ("runtime_environment", "possible_downtime");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        defined (my $availability_id = create_available_record($dbt, "availability", \@fields, \@vals)) or exit_application(2);

        # Billing
        my $billing_change_category = $ref->{"BILLING CHANGE CATEGORY"} || "";
        my $billing_resourceunit_code = $ref->{"RESOURCE UNIT"} || "";
        $billing_resourceunit_code = tx_resourceunit($billing_resourceunit_code);
        my $billing_change_date = $ref->{"LAST BILLING CHANGE DATE"} || "";
        $billing_change_date = conv_date($billing_change_date);
        my $billing_change_request_id = $ref->{"BILLING REQUEST NUMBER"} || "";
        @fields = ("billing_change_category", "billing_resourceunit_code", "billing_change_date", "billing_change_request_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        defined (my $billing_id = create_available_record($dbt, "billing", \@fields, \@vals)) or exit_application(2);

        # CI Owner Company
        my $ci_owner_company = $ref->{'SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE'} || "";
        if (index(lc($ci_owner_company), "retained") > -1) {
                $ci_owner_company = "ALU Retained";
        } else {
                $ci_owner_company = "HP";
        }
        # If billing_resourceunit_code 45, then Hosting Service.
        # Set owner company to HP
        if (index($billing_resourceunit_code, "45") > -1) {
                $ci_owner_company = "HP";
        }

        # Check to create cluster record
        @fields = ("cluster_type");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        defined (my $cluster_id = create_available_record($dbt, "cluster", \@fields, \@vals)) or exit_application(2);

        # CompSys_ESL
#       my $esl_system_type = $ref->{"CATEGORY"} || "";
#       $esl_system_type = translate($dbt, "ovsd_servers", "CATEGORY", $esl_system_type);
#       @fields = ("esl_system_type");
#       (@vals) = map { eval ("\$" . $_ ) } @fields;
#       defined (my $compsys_esl_id = create_available_record($dbt, "compsys_esl", \@fields, \@vals)) or exit_application(2);

        # Contact Roles
        # Domain Analyst is not handled, since name not in Lastname, Firstname format
        # Technical Owner is in 'OWNER PERSON NAME'
        my $fname = $ref->{"OWNER PERSON NAME"} || "";
        my $name_code = $ref->{"OWNER PERSON SEARCH CODE"} || "";
        handle_person($dbt, $fname, $name_code, "Technical Owner", $computersystem_id);
        $fname = $ref->{"ADMIN PRIMARY CONTACT NAME"} || "";
        $name_code = $ref->{"Technical Lead"} || "";
        handle_person($dbt, $fname, $name_code, "Admin Primary", $computersystem_id);
        $fname = $ref->{"ADMIN SECONDARY CONTACT NAME"} || "";
        $name_code = $ref->{"ADMIN SECONDARY CONTACT SEARCH CODE"} || "";
        handle_person($dbt, $fname, $name_code, "Technical Lead Backup", $computersystem_id);

        # Notes record
        my $note_value = $ref->{"NOTES"} || "";
        if (length($note_value) > 0) {
                my $note_type = "GeneralNote";
                @fields = ("computersystem_id", "note_type", "note_value");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
        defined (my $notes_id = create_available_record($dbt, "notes", \@fields, \@vals)) or exit_application(2);
        }



        # IP Connectivity
        # Primary IP Address
        my $network_id_value = $ref->{"IP ADDRESS"} || "";
        # Create IP attribute
        if (length($network_id_value) > 0) {
          $network_id_value = trim $network_id_value;
          # Add IP Address if Valid, otherwise add warning if invalid format is available
          if (not (IsValidIp($network_id_value))) {
            $network_id_value = "Please review OVSD for CIID $source_system_element_id";
            my $data_log = Log::Log4perl->get_logger('Data');
            $data_log->info("System $fqdn (CI ID: $source_system_element_id) Primary IP invalid format: ***$network_id_value***");
          }
          add_ip($dbt, $computersystem_id, "Primary IP", "", "IP Address", $network_id_value);
        }

        # Alternate IP Addresses
        my $alternate_ips = $ref->{"Secondary/Virtual IP Addresses (4000)"} || "";
        if (length($alternate_ips) > 0) {
          handle_alternate_ip($dbt, $fqdn, $source_system_element_id, $computersystem_id, $alternate_ips);
        }
        # Alias names
        my $alias_names = $ref->{"ALIAS_NAMES (4000)"} || "";
        if (length($alias_names) > 0) {
          handle_alias_ip($dbt, $computersystem_id, $alias_names);
        }

        # Create Maintenance Contract
        my $maintenance_contract_id;
        {
          my $record;
          $record->{maint_contract_name} = $ref->{"MAINTENANCE CONTRACT"};
          $record->{coverage_end_date} = $ref->{"COVERAGE END DATE"};

          if (rval_available($record)) {
            defined ($maintenance_contract_id = rcreate_record($dbt, "maintenance_contract", $record)) or exit_application(2);
          }
        }

        # Operating System
        my ($operatingsystem_id, $os_type);
        my $os_name = $ref->{"OS NAME"} || "";
        if (length($os_name) > 0) {
          my $os_version = $ref->{"OS VER/REL/SP"} || "";
          ($os_type, $os_version) = os_translation($dbt, $os_name, $os_version);
          my $time_zone = $ref->{"TIME_ZONE"} || "";
          @fields = ("os_name", "os_version", "os_type", "time_zone");
          (@vals) = map { eval ("\$" . $_ ) } @fields;
          defined ($operatingsystem_id = create_available_record($dbt, "operatingsystem", \@fields, \@vals)) or exit_application(2);
        } else {
          $operatingsystem_id = "";
        }

        # Backup
        my $backup_id;

        {
          # TODO : this is a simple mapping of an input record (in $ref) to an output record (in $record)
          # Do the mapping based on a mapping description, e.g. translate(source record, source cols, target record, target cols, [ sub ])
          # The mapping description could be read from a sheet
          my $record;
          $record->{computersystem_id} = $computersystem_id;

          $record->{backup_storage}      = ntranslate($dbt, "ovsd_servers", "BACKUP_STORAGE", $ref->{'BACKUP STORAGE'});
          $record->{backup_mode}         = ntranslate($dbt, "ovsd_servers", "BACKUP_MODE", $ref->{'BACKUP MODE'});
          $record->{backup_restartable}  = ntranslate($dbt, "ovsd_servers", "BACKUP_RESTARTABLE", $ref->{'BACKUP RESTARTABLE'});
          $record->{backup_media_server} = ntranslate($dbt, "ovsd_servers", "BACKUP_MEDIA_SERVER", $ref->{'BACKUP MEDIA SERVER'});

          $record->{backup_retention}          = $ref->{'BACKUP RETENTION'};
          $record->{backup_schedule}           = $ref->{'BACKUP SCHEDULE'};
          $record->{backup_server}             = $ref->{'BACKUP SERVER'};
          $record->{backup_information}        = $ref->{'BACKUP INFORMATION'};
          $record->{backup_restore_procedures} = $ref->{'BACKUP RESTORE PROCEDURES'};

          # Beware : backup_media_server always has a value (either Yes or No). This makes that we always create a row, even if all
          # the other columns are empty. => now corrected

          if (rval_available($record, [ qw(backup_storage backup_retention backup_mode backup_schedule backup_restartable
                                            backup_server backup_information backup_restore_procedures) ])
              || is_true($record->{backup_media_server})) {

            # If we would prepare the statement beforehand (eg. based on an example record) we would have an automatic check for missing values
            defined ($backup_id = rcreate_record($dbt, "backup", $record)) or exit_application(2);
          }
        }

        # ComputerSystem
        @fields = ("computersystem_id", "admin_id", "availability_id", "billing_id",
                   "compsys_esl_id", "maintenance_contract_id", "cluster_id", "ci_owner_company",
                   "virtual_ci_id", "operatingsystem_id", "source_system_element_id");

        (@vals) = map { eval ("\$" . $_ ) } @fields;

        if ( val_available(\@vals) eq "Yes") {
          update_record($dbt, "computersystem", \@fields, \@vals);
        }
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
