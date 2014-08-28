=head1 NAME

cs_availability_from_esl - This script will extract the ComputerSystem Availability Information from ESL.

=head1 VERSION HISTORY

version 1.1 25 April 2012 DV

=over 4

=item *

Add sth->finish line in procedure for invalid email address.

=back

version 1.0 18 August 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the ComputerSystem Availability and Assignment Information from ESL.

=head1 SYNOPSIS

 cs_availability_from_esl.pl [-t] [-l log_dir] [-c]

 cs_availability_from_esl.pl -h    Usage
 cs_availability_from_esl.pl -h 1  Usage and description of the options
 cs_availability_from_esl.pl -h 2  All documentation

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
use DbUtil qw(db_connect do_stmt do_execute create_record get_recordid clear_fields);
use ALU_Util qw(exit_application replace_cr update_record val_available esl_person);

#############
# subroutines
#############

# ==========================================================================

=pod

=head2 Get Contacts

This procedure will handle all contacts for a specific type

=cut

sub get_contacts($$$$) {
        my ($dbs, $dbt, $table, $contact_type) = @_;

        my $summary_log = Log::Log4perl->get_logger('Summary');

        $summary_log->info("Processing data for $contact_type - Get Query");

        my $sth = do_execute($dbs, "
SELECT DISTINCT  `Full Nodename`, `$contact_type` as email, `System ID`
  FROM $table
  WHERE `$contact_type` IS NOT NULL") or return;

        $summary_log->info("Processing data for $contact_type - Process data");

        while (my $ref = $sth->fetchrow_hashref) {

                # Find ComputerSystem ID
                my $source_system_element_id = $ref->{"System ID"} || "";
                my @fields = ("source_system_element_id");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                my $computersystem_id;
                defined ($computersystem_id = get_recordid($dbt, "computersystem", \@fields, \@vals)) or return;
                if (length($computersystem_id) == 0) {
                        # Computersystem ID not found, so ignore this record.
                        next;
                }

                # Handle Contact Role
                my ($contactrole_id);
                my $email = $ref->{"email"} || "";
                my $person_id = esl_person($dbt, $email);
                if (length($person_id) > 0) {
                        @fields = ("person_id", "contact_type", "computersystem_id");
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

# Make database connection for source & target database
my $dbs = db_connect("alu_cmdb") or exit_application(2);
my $dbt = db_connect("cim") or exit_application(2);

$summary_log->info("Do run cs_admin_from_esl.pl AFTER this script!\n\n");

my $computersystem_source_id = "ESL_".time;

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("availability", "contactrole", "assignment") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }

  # Clear indexes for cleared tables
  my @indexes = ("availability_id", "assignment_id");
  clear_fields($dbt, "computersystem", \@indexes) or exit_application(2);
}


=pod

=head2 ComputerSystem Selection Criteria from AssetCenter

Status: In Use - Only active Hardware boxes are important for Configuration Management.

Master: NULL or AssetCenter included, so ESL and OVSD are excluded.

To exclude Logical / Virtual Servers, information from 'Model' field and from 'Logical CI Type' is used.
Model: All records, except 'Logical / Virtual Servers. 'Logical CI Type': all NULL records, so exclude Logical and Virtual Servers.

=cut

# Contact names need to be email addresses,
# Verify if this is the case

my $sth = do_execute($dbs, "
SELECT `Technical Owner` as contact
  FROM esl_cs_availability
  WHERE `Technical Owner` IS NOT NULL
  LIMIT 0,1") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # Find contact
        my $email_address = $ref->{"contact"} || "";
        if (index($email_address, "@") > 0) {
                $summary_log->info("esl_cs_availablility table seems to have emails as contact");
        } else {
                ERROR("esl_cs_availability does not seem to have email addresses as contacts, exiting...");
                exit_application(2);
        }
}

# First work on Tables Compsys_ESL, Admin
$summary_log->info("Processing data for Availability and Assignment - Get Query");

$sth = do_execute($dbs, "
SELECT DISTINCT `Full Nodename`, `Availability`, `Coverage`, `Environment`, `Impact`, `Impact Description`,
                `Possible Downtime`, `Service Level`, `System ID`, `Assignment Group`, `Escalation Assignment Group`
  FROM esl_cs_availability") or exit_application(2);

$summary_log->info("Processing data for Availability and Assignment - Process data");

while (my $ref = $sth->fetchrow_hashref) {

        # Find ComputerSystem ID
        my $source_system_element_id = $ref->{"System ID"} || "";
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $computersystem_id;
        defined ($computersystem_id = get_recordid($dbt, "computersystem", \@fields, \@vals)) or exit_application(2);
        if (length($computersystem_id) == 0) {
                # Computersystem ID not found, so ignore this record.
                next;
        }
        # Get FQDN as tag name
        my $fqdn = $ref->{"Full Nodename"} || '';

        # Availability
        my ($availability_id);
        my $impact = $ref->{"Impact"} || "";
        my $impact_description = $ref->{"Impact Description"} || "";
        $impact_description = replace_cr($impact_description);
        my $minimum_availability = $ref->{"Availability"} || "";
        my $possible_downtime = $ref->{"Possible Downtime"} || "";
        my $runtime_environment = $ref->{"Environment"} || "";
        my $service_level_code = $ref->{"Service Level"} || "";
        my $servicecoverage_window = $ref->{"Coverage"} || "";
        @fields = ("impact", "impact_description", "minimum_availability", "possible_downtime", "runtime_environment", "service_level_code", "servicecoverage_window");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $availability_id = create_record($dbt, "availability", \@fields, \@vals) or exit_application(2);
        } else {
                $availability_id = undef;
        }

        # Assignment Group
        my ($assignment_id);
        my $initial_assignment_group = $ref->{"Assignment Group"} || "";
        my $escalation_assignment_group = $ref->{"Escalation Assignment Group"} || "";
        @fields = ("initial_assignment_group", "escalation_assignment_group");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $assignment_id = create_record($dbt, "assignment", \@fields, \@vals) or exit_application(2);
        } else {
                $assignment_id = undef;
        }


        # ComputerSystem Update
        @fields = ("source_system_element_id", "availability_id", "assignment_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                update_record($dbt, "computersystem", \@fields, \@vals);
        }

}

# Then work on Authorized Reboot Requestors
my @contact_types = ("Authorized Reboot Requestor", "Capacity Management Contact", "Customer Change Coordinator",
                     "Downtime Contact", "Restore Contact", "Technical Owner", "Technical Owner Backup", 
                     "Technical Lead", "Technical Lead Backup");
foreach my $contact_type (@contact_types) {
        get_contacts($dbs, $dbt, "esl_cs_availability", $contact_type) or exit_application(2);
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
