=head1 NAME

computersystem_from_a7 - This script will extract the ComputerSystem Information from Assetcenter.

=head1 VERSION HISTORY

version 1.5 01 March 2012 DV

=over 4

=item *

Add ovsd_searchcode processing for uCMDB ExternalID feed for ALU Retained computersystems.

=back

version 1.4 29 February 2012 DV

=over 4

=item *

Add Hosting Service (billing code 45) processing. Target system is ESL for these CIs.

=back

version 1.3 26 January 2012 DV

=over 4

=item *

Add ALU Retained vs HP Owned Infrastructure.

=back

version 1.2 28 October 2011 DV

=over 4

=item *

Logical / Virtual system logic has been moved to script computersystem_rels_knowl_from_a7.pl. This script computersystem_from_a7.pl will extract attributes only. Cluster / Virtual data is extracted in computersystem_rels_knowl_from_a7.pl.

=back

version 1.1 21 October 2011 DV

=over 4

=item *

Add Logical / Virtual systems to Extract, as discussed in Workshop in Mechelen on 27.09.2011 - see Meeting Minutes "ALU-HP_Workshop20110927.docs".

=item *

Check for Field "* Logical CI type".

=item *

If value is Logical Server, then this CI is a Cluster Package.

=item *

If value is Virtual Server, then this CI is a Virtual Guest.

=item *

Relationship information is available from the Global_EMEA_Mapping_SOL_LOG_Virtual ... monthly extract.

=back

version 1.0 09 August 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the ComputerSystem information from Assetcenter.

=head1 SYNOPSIS

 computersystem_from_a7.pl [-t] [-l log_dir] [-c]

 computersystem_from_a7.pl -h    Usage
 computersystem_from_a7.pl -h 1  Usage and description of the options
 computersystem_from_a7.pl -h 2  All documentation

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
use DbUtil qw(db_connect do_stmt do_execute create_record get_field);
use ALU_Util qw(exit_application translate update_record val_available cons_fqdn add_ip os_translation a7_person tx_resourceunit conv_date);

#############
# subroutines
#############

# ==========================================================================

sub IsVirtualFarm ($$$) {
        # Check if the configuration item is a Farm a return the corresponding HostType
        # Return empty HostType if the CI is not a Farm
        my ($dbs, $hostname,$os_name) = @_;
        my ($HostType);
        if (($os_name eq "ESX Cluster") || ($os_name eq "VMWARE ESX")) {
                $HostType = "Farm";
        } else {
                my $sth = do_execute($dbs, "
SELECT DISTINCT `*_ Hostname / inst (*_ Distant CI)`
  FROM a7_all_relations, a7_servers
  WHERE `*_ Hostname / inst (*_ Distant CI)` = '$hostname'
    AND `*_ Impact direction` = 'Local impacted by Distant'
    AND `*_ Relation type` = 'Virtual Server'
    AND `* Logical CI type` = 'Virtual Server'
    AND `*_ Hostname / inst` = `*_ Hostname / inst (*_ Local CI)`") or return;

                if (my $ref = $sth->fetchrow_hashref) {
                        $HostType = "Farm";
                } else {
                        $HostType = "";
                }
        }

        return $HostType;
}
# ==========================================================================

sub IsCluster ($$$) {
        # Check if the configuration item is a Cluster a return the corresponding HostType
        # Return empty HostType if the CI is not a Cluster
        my ($dbs, $hostname,$os_name) = @_;
        my ($HostType);

        # Checking if the CI is a Unix Cluster

        if (($os_name eq "Unix Cluster") || ($os_name eq "WINTEL Cluster")) {
                $HostType = "Cluster";
        } else {
                # Checking Logical-Logical relation
                # Relation Type = Logical Server
                # Input CI as a Distant
                # Relation = Local Impacted By Distant
                my $sth = do_execute($dbs, "
SELECT `*_ Hostname / inst (*_ Distant CI)`
  FROM a7_all_relations, a7_servers
  WHERE `*_ Hostname / inst (*_ Distant CI)` = '$hostname'
    AND `*_ Impact direction` = 'Local impacted by Distant'
    AND `*_ Relation type` = 'Logical Server'
    AND `* Logical CI type` = 'Logical Server'
    AND `*_ Hostname / inst` = `*_ Hostname / inst (*_ Local CI)`") or return;

                if (my $ref = $sth->fetchrow_hashref) {
                        $HostType = "Cluster";
                } else {
                        # Checking Logical-Logical relation
                        # Relation Type = Logical Server
                        # Input CI as a Local CI in the relation
                        # Relation = Local Impacts Distant
                        my $sth = do_execute($dbs, "
SELECT `*_ Hostname / inst (*_ Local CI)`
  FROM a7_all_relations
  WHERE `*_ Hostname / inst (*_ Local CI)` = '$hostname'
    AND `*_ Impact direction` = 'Local impacts Distant'
    AND `*_ Relation type` = 'Logical Server'
    AND `* Logical CI type (*_ Distant CI)` = 'Logical Server'") or return;

                        if (my $ref = $sth->fetchrow_hashref) {
                                $HostType = "Cluster";
                        } else {
                                $HostType="";
                        }
                }
        }

        return $HostType;
}

# ==========================================================================

sub IsClusterPackage ($$) {
        # Check if the configuration item is a ClusterPackage a return the corresponding HostType
        # Return empty HostType if the CI is not a ClusterPackage
        my ($dbs, $hostname) = @_;
        my ($HostType);
        my $sth = do_execute($dbs, "
SELECT `*_ Hostname / inst (*_ Local CI)`
  FROM a7_all_relations
  WHERE `*_ Hostname / inst (*_ Local CI)` = '$hostname'
    AND `*_ Impact direction` = 'Local impacted by Distant'
    AND `*_ Relation type` = 'Logical Server'
    AND `* Logical CI type (*_ Distant CI)` = 'Logical Server'") or return;

        if (my $ref = $sth->fetchrow_hashref) {
                $HostType = "ClusterPackage";
        } else {
                my $sth = do_execute($dbs, "
SELECT `*_ Hostname / inst (*_ Distant CI)`
  FROM a7_all_relations, a7_servers
  WHERE `*_ Hostname / inst (*_ Distant CI)` = '$hostname'
    AND `*_ Impact direction` = 'Local impacts Distant'
    AND `*_ Relation type` = 'Logical Server'
    AND `*_ Hostname / inst (*_ Local CI)` = `*_ Hostname / inst`
    AND `* Logical CI type` = 'Logical Server'") or exit_application(2);

                if (my $ref = $sth->fetchrow_hashref) {
                        $HostType = "ClusterPackage";
                } else {
                        $HostType="";
                }
        }
        return $HostType;
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

my $data_log = Log::Log4perl->get_logger('Data');

my $computersystem_source_id = "A7_".time;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

# Check on number of columns
# This check has been done in the Hardware for A7 script.

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("admin", "assignment", "availability", "billing", "compsys_esl",
                     "computersystem", "contactrole", "cluster", "diskspace", "ip_attributes", "ip_connectivity",
                     "maintenance_contract", "notes", "operatingsystem", "processor", "remote_access_info",
                     "servicefunction", "system_usage", "virtual_ci", "backup" ) {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

=pod

=head2 ComputerSystem Selection Criteria for AssetCenter

Documentation from CI Sync.

Status: In Use OR Awaiting Delivery, with a blank (stock) reason: Only active Hardware boxes are important for Configuration Management.

Status: In Stock, then (stock) reason needs to be 'Delivered' or 'FMO Transition'.

Master: NULL or AssetCenter included, so ESL and OVSD are excluded.

CI Responsible like ICT-APAC%ASB is excluded, see email with Raymond Ducrocq 2/02/2012 - 17:31.

NCC (Non-Consolidated Countries) are included for now. The debate is still going on.

=cut

my $sth = do_execute($dbs, "
SELECT `*_ Hostname / inst`, `* IP domain`, `* IP address`, `*_ Status`, `Reason`, `Billing Change Category`,
       `*_ ABC: CI destination / RU`, `* Main solution`, `* Billing: Hosting type`, `Last Billing Change Date`,
       `Billing Request Number`, `* Owner`, `*_ Support code`, `* Logical CI type`, `* Contract elements`,
       `* Oper System`, `* Operating System Version`, `* Operating System Level`, `*_ Disk assigned (GB)`,
       `Name (* Maint contract* Company)`, `* Corp ref # (* Maint contract)`, `Install date`, `_ IT contact`,
       `*Region (* Location)`, `Asset Tag` , `*_ Brand`, `* Model (*_ Product)`, `* CI Ownership`
  FROM a7_servers
  WHERE ((`*_ Status` <=> 'In Use')
         OR ((`*_ Status` <=> 'Awaiting Delivery') AND (`Reason` <=> ''))
         OR ((`*_ Status` <=> 'In Stock') AND ((`Reason` <=> 'DELIVERED') OR (`Reason` <=> 'FMO TRANSITION'))))
    AND NOT (`* Master flag` <=> 'ESL')
    AND NOT (`* Master flag` <=> 'OVSD')
    AND NOT (`* Master flag` <=> 'AC without sync to ESL')
    AND NOT (`*_ CI Responsible` LIKE 'ICT-APAC%ASB')
    AND NOT (`*_ Hostname / inst` LIKE 'z-%')") or exit_application(2);
#    AND NOT (`*_ CI Responsible` LIKE 'NCC%')";

while (my $ref = $sth->fetchrow_hashref) {
        my ($computersystem_id, $maintenance_contract_id, $availability_id);

        # ComputerSystem
        my $source_system_element_id = $ref->{"Asset Tag"} || "";
        my $computersystem_source = $computersystem_source_id;
        # Get FQDN as tag name
        my $hostname = $ref->{"*_ Hostname / inst"} || "unknown";
        my $domainname = $ref->{"* IP domain"} || "no.dns.entry.com";
        my $os_name = $ref->{"* Oper System"} || "";
        my $fqdn = cons_fqdn($hostname, $domainname);

        # If physical server, set physicalbox tag to FQDN
        # This will require more thinking to distinguish between physical and logical systems!

        # Logical / Virtual CI Type
        # 3 fields determine Physical or Virtual / Logical Server:
        # *_ Brand: Alcanet
        # * Model (*_ Product): Logical-Virtual Server
        # * Logical CI Type: Logical Server OR Virtual Server.
        my ($isvirtual, $physicalbox_tag, $host_type, $cs_type);
        my $logical_ci_type = $ref->{'* Logical CI type'} || "";
        my $brand = $ref->{'*_ Brand'} || "";
        my $product = $ref->{'* Model (*_ Product)'} || "";
        if ((length($logical_ci_type) > 0) ||
                ($product eq 'LOGICAL-VIRTUAL SERVER') ||
                ($brand eq 'ALCANET')) {
                $isvirtual = "TRUE";
                if ( $logical_ci_type eq "Logical Server" ) {
                        # The CI is either a Farm or a Cluster or a Cluster Package
                        defined ($host_type = IsVirtualFarm($dbs,$hostname,$os_name)) or exit_application(2);
                        if (length($host_type) == 0) {
                                defined ($host_type = IsCluster($dbs,$hostname,$os_name)) or exit_application(2);
                                if (length($host_type) == 0) {
                                        defined ($host_type = IsClusterPackage($dbs,$hostname)) or exit_application(2);
					if (length($host_type) > 0) {
						$cs_type="cluster package";
					}
                                } else {
					$cs_type="cluster";
				}
                        } else {
				$cs_type="farm";
			}
                        if (length($host_type) == 0) {
                                # the CI is an Alias.
                                $host_type = "Alias";
                        }
                } elsif ( $logical_ci_type eq "Virtual Server" ) {
                        # The CI Type is "Virtual Server"
                        $host_type = "Virtual Server";
                } else {
                        $data_log->error("The Logical CI Type $logical_ci_type is not properly managed");
                }
                $physicalbox_tag = "";
        } else {
                # Logical CI Type is NULL for Physical Servers.
                $isvirtual = "FALSE";
                $physicalbox_tag = $fqdn;
                $host_type = "Physical Server";
        }

        # Create ComputerSystem record ID, for further records
        my @fields = ("computersystem_source", "fqdn", "host_type", "cs_type", "source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $computersystem_id = create_record($dbt, "computersystem", \@fields, \@vals) or exit_application(2);
        } else {
                ERROR("Trying to create computersystem record, but no data available. Exiting...");
                exit_application(2);
        }

        # Get OVSD Search Code
        my ($ovsd_searchcode);
        my $ASSETTAG = $ref->{"Asset Tag"} || "";
        @fields = ("ASSETTAG");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $ovsd_searchcode = get_field($dbs, "ovsd_servers", "SEARCH CODE", \@fields, \@vals);
        }
        if ((not defined $ovsd_searchcode) ||
                (length($ovsd_searchcode) == 0)) {
                # Undefined SearchCode
                $ovsd_searchcode = "Undef-Searchcode-" . $ASSETTAG;
        }

        # Maintenance Contract
        my $contract_elements = $ref->{"* Contract elements"} || "";
        my $maint_contract_name = $ref->{"Name (* Maint contract* Company)"} || "";
        my $maint_contract_details = $ref->{"* Corp ref # (* Maint contract)"} || "";
        # Create Maintenance Contract
        @fields = ("contract_elements", "maint_contract_name", "maint_contract_details");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $maintenance_contract_id = create_record($dbt, "maintenance_contract", \@fields, \@vals) or exit_application(2);
        } else {
                $maintenance_contract_id = undef;
        }

        # Availability
        my $runtime_environment = "Production";
        my $servicecoverage_window = $ref->{"*_ Support code"} || "";
        # Create Availability
        @fields = ("runtime_environment", "servicecoverage_window");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $availability_id = create_record($dbt, "availability", \@fields, \@vals) or exit_application(2);
        } else {
                $availability_id = undef;
        }

        # IP Connectivity
        my ($network_id_type, $ip_attributes_id);
        my $network_id_value = $ref->{"* IP address"} || "";
        # Create IP attribute
        if (length($network_id_value) > 0) {
                add_ip($dbt, $computersystem_id, "Primary IP", "", "IP Address", $network_id_value);
        }

        # Operating System
        my ($operatingsystem_id, $os_version, $os_type);
        if (length($os_name) > 0) {
                $os_version = $ref->{"* Operating System Version"} || "";
                ($os_type, $os_version) = os_translation($dbt, $os_name, $os_version);
                my $os_patchlevel = $ref->{"* Operating System Level"} || "";
                my $os_installationdate = $ref->{"Install date"} || "";
                @fields = ("os_name", "os_version", "os_patchlevel", "os_installationdate", "os_type");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                if ( val_available(\@vals) eq "Yes") {
                # OS known, now add the install date
                # push @fields, "os_installationdate";
                # push @vals, $os_installationdate;
                        $operatingsystem_id = create_record($dbt, "operatingsystem", \@fields, \@vals) or exit_application(2);
                } else {
                        $operatingsystem_id = undef;
                }
        } else {
                $operatingsystem_id = "";
        }

        # Contact Role - Technical Owner
        my ($contactrole_id, $contact_type);
        # Handle Person
        my $fname = $ref->{"_ IT contact"} || "";
        my $person_id = a7_person($dbt, $fname);
        # Now assign role to person
        if (length($person_id) > 0) {
                $contact_type = "Technical Owner";
                @fields = ("contact_type", "person_id", "computersystem_id");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                if ( val_available(\@vals) eq "Yes") {
                        $contactrole_id = create_record($dbt, "contactrole", \@fields, \@vals) or exit_application(2);
                } else {
                        $contactrole_id = undef;
                }
        }

        # Billing
        my ($billing_id);
        my $billing_change_category = $ref->{"Billing Change Category"} || "";
        my $billing_resourceunit_code = $ref->{"*_ ABC: CI destination / RU"} || "";
        $billing_resourceunit_code = tx_resourceunit($billing_resourceunit_code);
        my $billing_change_date = $ref->{"Last Billing Change Date"} || "";
        $billing_change_date = conv_date($billing_change_date);
        my $billing_change_request_id = $ref->{"Billing Request Number"} || "";
        @fields = ("billing_change_category", "billing_resourceunit_code", "billing_change_date", "billing_change_request_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $billing_id = create_record($dbt, "billing", \@fields, \@vals) or exit_application(2);
        } else {
                $billing_id = undef;
        }

        # CI Owner Company
        # Mail Raymond Ducrocq 26/07/2012
        # ALU Retained for 'ABC CI Destination / RU Code', must be '0C - Not Billable - ALU Managed'.
        my ($ci_owner_company);
        if (lc($billing_resourceunit_code) eq '0c') {
                $ci_owner_company = "ALU Retained";
        } else {
                $ci_owner_company = "HP";
        }

        # Legacy processing, before mail 26/07/2012
        # my $ci_owner_company = $ref->{'* CI Ownership'} || "";
        # if (index(lc($ci_owner_company), "retained") > -1) {
        #       $ci_owner_company = "ALU Retained";
        # } else {
        #       $ci_owner_company = "HP";
        # }
        # If billing_resourceunit_code 45, then Hosting Service.
        # Set owner company to HP
        # if (index($billing_resourceunit_code, "45") > -1) {
        #       $ci_owner_company = "HP";
        # }

        # Diskspace
        my ($diskspace_id);
        my $available_diskspace = $ref->{"*_ Disk assigned (GB)"} || "";
        @fields = ("available_diskspace");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $diskspace_id = create_record($dbt, "diskspace", \@fields, \@vals) or exit_application(2);
        } else {
                $diskspace_id = undef;
        }

        # Admin
        my ($admin_id);
        my $lifecyclestatus = $ref->{"*_ Status"} || "";
        $lifecyclestatus = translate($dbt, "a7_servers", "Status", $lifecyclestatus, "ErrMsg");
        my $customer_notes = $ref->{"* Owner"} || "";
        my $application_type_group = $ref->{"* Billing: Hosting type"} || "";
        my $management_region = $ref->{"*Region (* Location)"} || "";
        $management_region = translate($dbt, "a7_servers", "Region", $management_region, "ErrMsg");
        @fields = ("lifecyclestatus", "customer_notes", "management_region", "application_type_group");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $admin_id = create_record($dbt, "admin", \@fields, \@vals) or exit_application(2);
        } else {
                $admin_id = undef;
        }

        # ComputerSystem
        @fields = ("computersystem_id", "admin_id", "availability_id", "billing_id",
                       "diskspace_id", "maintenance_contract_id",
                           "operatingsystem_id", "source_system_element_id", "isvirtual",
                           "physicalbox_tag", "ovsd_searchcode", "ci_owner_company");
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
