=head1 NAME

bus_apps_instances_from_esl - Extract Business Application Instance Information from ESL.

=head1 VERSION HISTORY

version 1.1 26 April 2012 DV

=over 4

=item *

Add product to application tag, so that it does not conflict with application instance names.

=back

version 1.0 09 December 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Business Application Instance Attribute information from ESL for the Business Applications. These attributes need to go to ESL Solution fields.

=head1 SYNOPSIS

 bus_apps_instances_from_esl.pl [-t] [-l log_dir] [-c]

 bus_apps_instances_from_esl.pl -h    Usage
 bus_apps_instances_from_esl.pl -h 1  Usage and description of the options
 bus_apps_instances_from_esl.pl -h 2  All documentation

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
use ALU_Util qw(exit_application esl_person replace_cr);

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
                my ($contactrole_id);
                my $email = $ref->{"email"} || "";
                my $person_id = esl_person($dbt, $email);
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

my $source = "ESL";
my $source_system = $source . "_" . time;

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

$summary_log->info("Getting ESL Business Application Attributes");

my ($found, $not_found);

$sth = do_execute($dbs, "
SELECT DISTINCT `Solution ID`, `Solution Category`, `Solution Name`, `Solution Description`, `Solution CMA`, `Business`,
                `External Application ID`, `External Tool`, `External Source ID`
  FROM esl_instance_work
  WHERE (`Solution Category` = 'business application')") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # Application Information
        my $appl_name_long = $ref->{'Solution Name'} || "NotAvailable";
        $appl_name_long = replace_cr($appl_name_long);
        my $appl_name_acronym = $appl_name_long;
        my $appl_name_description = $ref->{'Solution Description'} || "";
        my $source_system_element_id = $ref->{'External Source ID'} || "";
        # Verify if this Solution is known from one of the Source Systems
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $application_id;
        defined ($application_id = get_field($dbt, "application_relation", "application_id", \@fields, \@vals)) or exit_application(2);
        if (length($application_id) == 0) {
                $not_found++;
                # Need to add the application
                my $portfolio_id = $ref->{'External Application ID'} || "";
                my $application_category = $ref->{'Solution Category'} || "";
                my $cma = $ref->{'Solution CMA'} || "";
                my $ext_source_system = $ref->{'External Tool'} || "";
                my $application_type = "Application";
                # Unique Application Tag since Solution Name is unique
                my $application_tag = "product" . lc($appl_name_long);
                # Verify if application is known already
                my @fields = ("application_tag");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                defined ($application_id = get_field($dbt, "application", "application_id", \@fields, \@vals)) or exit_application(2);
                if (length($application_id) == 0) {
                        # Unknown Application, so create one
                        $source_system_element_id = $ref->{'Solution ID'} || "";
                        @fields = ("application_category", "appl_name_long", "appl_name_description",
                               "cma", "source_system", "source_system_element_id", "compsys_esl_id",
                                   "portfolio_obj_id", "ext_source_system", "application_type",
                                   "appl_name_acronym", "application_tag");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        $application_id = create_record($dbt, "application", \@fields, \@vals) or exit_application(2);
                } else {
                        $found++;
                }
        } else {
                $found++;
        }

        # Now get Application Instance Information for the Business Application Instance
        my ($application_instance_id);
        my $instance_category = "ApplicationInstance";
        my $application_instance_tag = lc($appl_name_long);
        $source_system_element_id = $ref->{'Solution ID'} || "";

        # Create Installed Application Record
        @fields = ("source_system", "source_system_element_id",
                           "appl_name_long", "appl_name_description", "instance_category",
                            "application_id", "application_instance_tag");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        $application_instance_id = create_record($dbt, "application_instance", \@fields, \@vals) or exit_application(2);
}

$summary_log->info("Found $found references to CMO Source Application, did not find $not_found references");

# Now work on the Contact Types for Installed Applications
my @contact_types = ("Solution Customer Instance Owner", "Solution Customer Instance Support", "Solution Delivery Instance Owner", "Solution Delivery Instance Support");
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
