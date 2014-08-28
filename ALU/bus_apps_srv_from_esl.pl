=head1 NAME

bus_apps_srv_from_esl - Extract Business Applications to Server Relations from ESL.

=head1 VERSION HISTORY

version 1.0 09 December 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Business Application to Server dependency relation from ESL.

=head1 SYNOPSIS

 bus_apps_srv_from_esl.pl [-t] [-l log_dir]

 bus_apps_srv_from_esl.pl -h    Usage
 bus_apps_srv_from_esl.pl -h 1  Usage and description of the options
 bus_apps_srv_from_esl.pl -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
###########

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
use DbUtil qw(db_connect do_stmt do_execute create_record get_recordid get_field);
use ALU_Util qw(exit_application val_available esl_person replace_cr);

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
SELECT DISTINCT `$source_field` AS source_system_element_id, `$contact_type` AS email
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
                my ($contactrole_id, $person_id);
                my $email = $ref->{"email"} || "";
                @fields = ("email");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                if ( val_available(\@vals) eq "Yes") {
                        # Find record if it exists already
                        defined ($person_id = get_recordid($dbt, "person", \@fields, \@vals)) or return;
                        if (length($person_id) == 0) {
                                # Create person_id if it did not exist
                                $person_id = create_record($dbt, "person",  \@fields, \@vals) or return;
                        }
                } else {
                        $person_id = "";
                }
                if (length($person_id) > 0) {
                        @fields = ("person_id", "contact_type", $id_name);
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        if ( val_available(\@vals) eq "Yes") {
                                $contactrole_id = create_record($dbt, "contactrole", \@fields, \@vals) or return;
                        } else {
                                $contactrole_id = undef;
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

my $scriptname = basename($0,"");

$summary_log->info("Start `$scriptname' application");

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values
# ==========================================================================

my %inst_list;
my $source = "ESL";
my $source_system = $source . "_" . time;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

$summary_log->info("Getting ESL Business Application to Server Dependency Attributes");

my $sth = do_execute($dbs, "
SELECT `Instance ID`, `Instance Name`, `Business Description`, `Instance Version`, `Instance Status`,
       `Monitoring Solution`, `Instance Assignment Group`, `Instance Environment`, `Instance Impact`,
       `Instance Service Level`, `Instance Availability`, `Instance Coverage`, `Full Nodename`, `Solution ID`
  FROM esl_instance_work
  WHERE (`Solution Category` = 'business application')") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # Instance ID should be unique
        # However due to contact processing, instances can show up multiple times.
        # Only handle the first time that an instance appears
        my $source_system_element_id = $ref->{'Instance ID'} || "";
        if (exists($inst_list{$source_system_element_id})) {
                next;
        } else {
                $inst_list{$source_system_element_id} = 1;
        }

        # Installed Application Information
        my ($application_instance_id);
        $source_system_element_id = $ref->{"Instance ID"} || "";
        my $appl_name_long = $ref->{'Instance Name'} || "";
        my $appl_name_description = $ref->{'Business Description'} || "";
        my $version = $ref->{'Instance Version'} || "";
        my $lifecyclestatus = $ref->{'Instance Status'} || "";
        my $monitoring_solution = $ref->{'Monitoring Solution'} || "";
        my $application_instance_tag = lc($appl_name_long);
        my $instance_category = "ESLBusinessProductInstance";
        if (length($appl_name_long) > 0) {
                # Installed Application Tag must be unique
                my @fields = ("application_instance_tag");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                defined ($application_instance_id = get_recordid($dbt, "application_instance", \@fields, \@vals)) or exit_application(2);
                if (length($application_instance_id) > 0) {
                        $application_instance_tag = "ESL_Instance_Dupl_Name*$appl_name_long*$source_system_element_id";
                }
        } else {
                $application_instance_tag = "ESL_Instance*$source_system_element_id";
        }

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
        @fields = ("runtime_environment", "impact", "service_level_code",
                       "minimum_availability", "servicecoverage_window");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $availability_id = create_record($dbt, "availability", \@fields, \@vals) or exit_application(2);
        } else {
                $availability_id = undef;
        }

        # Create Installed Application Record
        @fields = ("source_system", "source_system_element_id",
                           "appl_name_long", "appl_name_description", "version", "lifecyclestatus",
                           "monitoring_solution", "instance_category",
                            "availability_id", "assignment_id", "application_instance_tag");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $application_instance_id = create_record($dbt, "application_instance", \@fields, \@vals) or exit_application(2);
        }

        # Create Dependency Record for ESLBusinessProductInstance to ComputerSystem
        my $left_type = "ComputerSystem";
        my $left_name = $ref->{'Full Nodename'} || "";
        my $right_name = "$application_instance_tag";
        my $right_type = "Instance";
        my $relation = "has depending solution";
        @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                my $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
        }

        # Business Application Instance Information - For Relation Data
        my ($application_id);
        $left_type = "Instance";
        $right_type = $instance_category;
        $right_name = $application_instance_tag;
        $relation = $instance_category;
        $source_system_element_id = $ref->{'Solution ID'} || "";
        # Get Application ID
        @fields = ("source_system_element_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        defined ($application_instance_tag = get_field($dbt, "application_instance", "application_instance_tag", \@fields, \@vals)) or exit_application(2);
        if (length($application_instance_tag) == 0) {
                my $data_log = Log::Log4perl->get_logger('Data');

                $data_log->error("Solution ID $source_system_element_id not found in Application Instance Table");
                next;
        } else {
                $left_name = $application_instance_tag;
        }
        @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                my $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
        }

}

# Now work on the Contact Types for Installed Applications
my @contact_types = ("Customer Instance Owner", "Customer Instance Support", "Delivery Instance Owner", "Delivery Instance Support", "Instance Authorised Requestor", "Instance Downtime Contact", "Third Party Instance Owner");
foreach my $contact_type (@contact_types) {
#       get_contacts($dbs, $dbt, "esl_instance_work", $contact_type, "application_instance") or exit_application(2);
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
