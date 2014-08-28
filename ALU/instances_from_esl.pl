=head1 NAME

instances_from_esl - Extract Technical Product Instance Information from ESL.

=head1 VERSION HISTORY

version 1.2 23 April 2012 DV

=over 4

=item *

Bug 416 - Exclude OS Solutions for ESL Technical Product Extract.

=item *

On request of Transition Model team (meeting 23/04/2012), do not extract information from ESL Solution Category 'business service'. This category shows up in ESL only and not in a Source for Transformation Assetcenter or OVSD so Transition Model will never have to create a business service.

=back

version 1.1 09 December 2011 DV

=over 4

=item *

Review script to work on Technical Product Instances only.

=back

version 1.0 10 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Instance Attribute information from ESL for the Technical Products.

=head1 SYNOPSIS

 instances_from_esl.pl [-t] [-l log_dir] [-c]

 instances_from_esl.pl -h    Usage
 instances_from_esl.pl -h 1  Usage and description of the options
 instances_from_esl.pl -h 2  All documentation

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
use DbUtil qw(db_connect do_stmt do_execute create_record get_recordid get_recordid_from_source);
use ALU_Util qw(exit_application val_available esl_person translate add_note);
use Data::Dumper;

#############
# subroutines
#############

# ==========================================================================

=pod

=head2 Get Contacts

This procedure will handle all contacts for a specific type

=cut

sub get_contacts($$$$$) {
        my ($dbs, $dbt, $table, $contact_type, $target_table) = @_;

        my $summary_log = Log::Log4perl->get_logger('Summary');

        $summary_log->info("Processing data for $contact_type in $target_table - Get Query");

        my ($source_field, $id_name, $application_id, $application_instance_id);

        if ($target_table eq "application") {
                $source_field = "Solution ID";
                $id_name = "application_id";
        } elsif ($target_table eq "application_instance") {
                $source_field = "Instance ID";
                $id_name = "application_instance_id";
        } else {
                ERROR("Get Contacts unknown Target table $target_table");
                return;
        }

        my $sth = do_execute($dbs, "
SELECT DISTINCT  `$source_field` AS source_system_element_id, `$contact_type` AS email
  FROM $table
  WHERE `$contact_type` IS NOT NULL") or return;

        $summary_log->info("Processing data for $contact_type - Process data");

        while (my $ref = $sth->fetchrow_hashref) {

                # Find CI ID
                my $source_system_element_id = $ref->{source_system_element_id} || "";
                my @fields = ("source_system_element_id");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                my $id;
                defined ($id = get_recordid($dbt, $target_table, \@fields, \@vals)) or return;
                if (length($id) == 0) {
                        # (Installed) Application ID not found, so ignore this record.
                        next;
                } else {
                        # Assign both Application ID and Installed Application ID to ID
                        # Only one will be selected.
                        $application_id = $id;
                        $application_instance_id = $id;
                }

                # Handle Contact Role
                my ($contactrole_id);
                my $email = $ref->{"email"} || "";
                my $person_id;
                defined ($person_id = esl_person($dbt, $email)) or return;
                if (length($person_id) > 0) {
                        @fields = ("person_id", "contact_type", $id_name);
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        if ( val_available(\@vals) eq "Yes") {
                                $contactrole_id = create_record($dbt, "contactrole", \@fields, \@vals) or return;
                        } else {
                                $contactrole_id = "";
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

my $source = "ESL";
my $source_system = $source . "_" . time;
my (%inst_list, %appl_inst_names);

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

# Contact names need to be email addresses,
# Verify if this is the case

my $sth = do_execute($dbs, "
SELECT `Solution Customer Instance Owner` AS contact
  FROM esl_instance_work
  WHERE `Solution Customer Instance Owner` IS NOT NULL
  LIMIT 0,1") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # Find contact
        my $email_address = $ref->{"contact"} || "";
        if (index($email_address, "@") > 0) {
                $summary_log->info("esl_instance_work table seems to have emails as contact");
        } else {
                ERROR("esl_instance_work does not seem to have email addresses as contacts, exiting...");
                exit_application(2);
        }
}

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("availability", "application_instance", "notes", "assignment", "operations", "relations", "workgroups") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

$summary_log->info("Getting ESL Application Attributes");

$sth = do_execute($dbs, "
SELECT `Instance ID`, `Solution ID`, `Instance Name`, `Business Description`, `Instance URL`, `Instance Version`,
       `Instance Status`, `Instance Type`, `Package Name`, `Home Directory`, `Monitoring Solution`, `Solution Category`,
       `Full Nodename`, `Listener Ports`, `Connectivity Instructions`, `Instance Assignment Group`, `Instance Environment`,
       `Instance Impact`, `Instance Service Level`, `Instance Availability`, `Instance Coverage`, `Total Instance Size (GB)`,
       `Total Used Instance Size (GB)`, `Capacity Management Notes`, `Daylight Savings Sensitivity`, `Instance Startup Notes`,
       `Instance Shutdown Notes`, `Instance Patch Notes`, `Backup Notes`, `Transaction Log Notes`, `Restore/Recovery Notes`, `Additional Notes`
  FROM esl_instance_work
  WHERE NOT (`Solution Category` <=> 'business application')
    AND NOT (`Solution Category` <=> 'os')
    AND NOT (`Solution Category` <=> 'business service')") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # Instance ID should be unique
        # However due to contact processing and due to instance in multiple subbusinesses, instances can show up multiple times.
        # Only handle the first time that an instance appears
        my $source_system_element_id = $ref->{'Instance ID'} || "";
        if (exists($inst_list{$source_system_element_id})) {
                next;
        } else {
                $inst_list{$source_system_element_id} = 1;
        }

        # Application Information
        my ($application_id);
        $source_system_element_id = $ref->{'Solution ID'};
        # Get Application ID
        defined ($application_id = get_recordid_from_source($dbt, "application", $source, $source_system_element_id)) or exit_application(2);
        if (length($application_id) == 0) {
                $data_log->error("Solution ID $source_system_element_id not found in Application Table");
                next;
        }

        # Application Instance Information
        my ($application_instance_id, $application_instance_tag);
        $source_system_element_id = $ref->{"Instance ID"} || "";
        my $appl_name_long = $ref->{'Instance Name'} || "";
        my $appl_name_description = $ref->{'Business Description'} || "";
        my $managed_url = $ref->{'Instance URL'} || "";
        my $version = $ref->{'Instance Version'} || "";
        my $lifecyclestatus = $ref->{'Instance Status'} || "";
        my $db_type = $ref->{'Instance Type'} || "";
        my $cluster_package_name = $ref->{'Package Name'} || "";
        my $home_directory = $ref->{'Home Directory'} || "";
        my $monitoring_solution = $ref->{'Monitoring Solution'} || "";
        my $solution_category = $ref->{'Solution Category'} || "";
        my $instance_category = translate($dbt, "esl_instance_work", "Solution Category", $solution_category, "ErrMsg");
        # 20120402 - Get Technical Instance Name in line with Requirements
        my $fqdn = $ref->{"Full Nodename"} || "";
        # my $application_instance_tag = "ESL_Inst*" . lc($appl_name_long) . "*$source_system_element_id";
        # ESL Instances can have duplicate names or no names
        # Special handling for OperatingSystems
        if (lc($instance_category) eq "operatingsysteminstance") {
                $application_instance_tag = "os." . $fqdn;
        } else {
                $application_instance_tag = lc($appl_name_long) . "." .$fqdn;
        }
        if (exists $appl_inst_names{$application_instance_tag}) {
                # ESL Instance name already exists, so use Instance ID as identifier
                # This identifier must be unique.
                $application_instance_tag = $source_system_element_id . "." . $fqdn;
                # Do an additional check, although this application_instance_tag must be unique
                if (exists $appl_inst_names{$application_instance_tag}) {
                        $data_log->error("Duplicate Application Instance $application_instance_tag, don't know what to do");
                }
        }
        $appl_inst_names{$application_instance_tag} = $fqdn;

        my $listener_ports = $ref->{'Listener Ports'} || "";
        my $connectivity_instruction = $ref->{'Connectivity Instructions'} || "";

        # Assignment
        my ($assignment_id);
        my $initial_assignment_group = $ref->{'Instance Assignment Group'} || "";
        my @fields = ("initial_assignment_group");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $assignment_id = create_record($dbt, "assignment", \@fields, \@vals) or exit_application(2);
        } else {
                $assignment_id = undef;
        }

        # Availability
        my ($availability_id);
        my $runtime_environment = $ref->{'Instance Environment'} || "";
        my $impact = $ref->{'Instance Impact'} || "";
        my $service_level_code = $ref->{'Instance Service Level'} || "";
        my $minimum_availability = $ref->{'Instance Availability'} || "";
        my $servicecoverage_window = $ref->{'Instance Coverage'} || "";
        @fields = ("runtime_environment", "impact", "service_level_code", "minimum_availability", "servicecoverage_window");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $availability_id = create_record($dbt, "availability", \@fields, \@vals) or exit_application(2);
        } else {
                $availability_id = undef;
        }

        # Operations
        my ($operations_id);
        my $op_total_size = $ref->{'Total Instance Size (GB)'} || "";
        my $op_total_used_size = $ref->{'Total Used Instance Size (GB)'} || "";
        my $op_cap_mgmt = $ref->{'Capacity Management Notes'} || "";
        my $op_daylight_savings = $ref->{'Daylight Savings Sensitivity'} || "";
        my $op_startup_notes = $ref->{'Instance Startup Notes'} || "";
        my $op_shutdown_notes = $ref->{'Instance Shutdown Notes'} || "";
        my $op_patch_notes = $ref->{'Instance Patch Notes'} || "";
        my $op_backup_notes = $ref->{'Backup Notes'} || "";
        my $op_tx_log = $ref->{'Transaction Log Notes'} || "";
        my $op_restore = $ref->{'Restore/Recovery Notes'} || "";
        @fields = ("op_total_size", "op_total_used_size", "op_cap_mgmt", "op_daylight_savings",
                   "op_startup_notes", "op_shutdown_notes", "op_patch_notes", "op_backup_notes",
                       "op_tx_log", "op_restore");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $operations_id = create_record($dbt, "operations", \@fields, \@vals) or exit_application(2);
        } else {
                $operations_id = undef;
        }

        # Create Installed Application Record
        @fields = ("source_system", "source_system_element_id", "managed_url",
                           "appl_name_long", "appl_name_description", "version", "lifecyclestatus",
                           "db_type", "cluster_package_name", "monitoring_solution", "instance_category",
                           "listener_ports", "connectivity_instruction", "operations_id",
                            "availability_id", "application_id", "assignment_id", "application_instance_tag");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $application_instance_id = create_record($dbt, "application_instance", \@fields, \@vals) or exit_application(2);
        }

        # Create Dependency Record for Installed Product
        my $left_type = "ComputerSystem";
        my $left_name = $ref->{'Full Nodename'} || "";
        my $right_name = "$application_instance_tag";
        my $right_type = "Instance";
        my $relation = "has installed product";
        @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                my $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
        }

        # Create Dependency Record for Installed Product - Product Instance
        $left_type = "Instance";
        $left_name = $right_name;
        $right_type = "Instance";
        $relation = "is instance from";
        @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                my $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
        }

	# Handle Notes
	# Additional Notes
        # WRONG_COL_XXX : COLUMN does not exists
	# my $note_value = $ref->{"Additional Notes"} || "";
	my $note_value = '';
	if (length($note_value) > 0) {
		add_note($dbt, $application_instance_id, "AdditionalNote", $note_value) or exit_application(2);
	}

	# Instance Shutdown Notes
	$note_value = $ref->{"Instance Shutdown Notes"} || "";
	if (length($note_value) > 0) {
		add_note($dbt, $application_instance_id, "ShutdownNote", $note_value) or exit_application(2);
	}

}

# Now work on the Contact Types for Installed Applications
my @contact_types = ("Customer Instance Owner", "Customer Instance Support", "Delivery Instance Owner", "Delivery Instance Support", "Instance Authorised Requestor", "Instance Downtime Contact", "Third Party Instance Owner");
foreach my $contact_type (@contact_types) {
        get_contacts($dbs, $dbt, "esl_instance_work", $contact_type, "application_instance") or exit_application(2);
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
