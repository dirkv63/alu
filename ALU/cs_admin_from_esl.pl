=head1 NAME

cs_admin_from_ESL - This script will extract the ComputerSystem Technical Admin Information from ESL.

=head1 VERSION HISTORY

version 1.0 17 August 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the ComputerSystem Technical Admin Information from ESL.

=head1 SYNOPSIS

 cs_admin_from_esl.pl [-t] [-l log_dir] [-c]

 cs_admin_from_esl.pl -h    Usage
 cs_admin_from_esl.pl -h 1  Usage and description of the options
 cs_admin_from_esl.pl -h 2  All documentation

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
use DbUtil qw(db_connect do_stmt do_execute create_record get_recordid get_field clear_fields);
use ALU_Util qw(exit_application trim update_record val_available add_note tx_resourceunit);

#############
# subroutines
#############

# ==========================================================================

sub conv_esl_date($) {
        my ($esl_date) = @_;
        my ($conv_date);
        my @months = ("JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC");
        $esl_date = trim($esl_date);
        my ($day, $mnth, $yr) = split / /, $esl_date;
        my $mnthnr = 0;
        while (my $month = shift(@months)) {
                if (lc($month) eq lc($mnth)) {
                        $mnthnr++;
                        last;
                }
                $mnthnr++;
        }
        if ($mnthnr == 0) {
                my $data_log = Log::Log4perl->get_logger('Data');
                $data_log->error("Could not convert date $esl_date, *$mnth* not found");
                $conv_date = "";
        } else {
                $conv_date = sprintf "%04d%02d%02d" , $yr, $mnthnr, $day;
        }
        return $conv_date;
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

my $computersystem_source_id = "ESL_".time;

my $data_log = Log::Log4perl->get_logger('Data');

# Make database connection for source & target database
my $dbs = db_connect("alu_cmdb") or exit_application(2);
my $dbt = db_connect("cim") or exit_application(2);

$summary_log->info("Make sure that this script runs AFTER cs_availability_from_esl.pl!\n\n");

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("admin", "billing", "compsys_esl", "notes") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }

  # Clear indexes for cleared tables
  my @indexes = ("admin_id", "billing_id", "compsys_esl_id");
  clear_fields($dbt, "computersystem", \@indexes) or exit_application(2);
}

=pod

=head2 ComputerSystem Selection Criteria from AssetCenter

Status: In Use - Only active Hardware boxes are important for Configuration Management.

Master: NULL or AssetCenter included, so ESL and OVSD are excluded.

To exclude Logical / Virtual Servers, information from 'Model' field and from 'Logical CI Type' is used.
Model: All records, except 'Logical / Virtual Servers. 'Logical CI Type': all NULL records, so exclude Logical and Virtual Servers.

=cut

# First work on Tables Compsys_ESL, Admin
$summary_log->info("Processing data for Admin and Compsys_ESL");

my $sth = do_execute($dbs, "
SELECT DISTINCT `Full Nodename`, `Category`, `Sub Business Name`, `Customer Notes`, `Management Region`, `NSA`,
                `Security Class`, `System Status`, `Timezone`, `SOX Classification`, `System Type`, `System ID`
  FROM esl_cs_admin") or exit_application(2);

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

        # Admin
        my ($admin_id, $application_type_group);
        my $customer_notes = $ref->{"Customer Notes"} || "";
        my $management_region = $ref->{"Management Region"} || "";
        my $nsa = $ref->{"NSA"} || "";
        if (lc($nsa) eq "yes") {
                $nsa = "TRUE";
        } else {
                $nsa = "FALSE";
        }
        my $security_level = $ref->{"Security Class"} || "";
        my $sox_system = $ref->{"SOX Classification"} || "";
        my $lifecyclestatus = $ref->{"System Status"} || "";
        my $time_zone = $ref->{"Timezone"} || "";
        @fields = ("customer_notes", "management_region", "nsa", "security_level", "sox_system", "lifecyclestatus", "time_zone");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $admin_id = create_record($dbt, "admin", \@fields, \@vals) or exit_application(2);
        } else {
                $admin_id = undef;
        }

        # Compsys_ESL
        my ($compsys_esl_id);
        my $esl_category = $ref->{"Category"} || "";
        my $esl_subbusiness = $ref->{"Sub Business Name"} || "";
        my $esl_system_type = $ref->{"System Type"} || "";
        my $esl_id = $ref->{"System ID"} || "";
        @fields = ("esl_category", "esl_subbusiness", "esl_system_type", "esl_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $compsys_esl_id = create_record($dbt, "compsys_esl", \@fields, \@vals) or exit_application(2);
        } else {
                $compsys_esl_id = undef;
        }



        # ComputerSystem Update
        @fields = ("source_system_element_id", "admin_id", "compsys_esl_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                update_record($dbt, "computersystem", \@fields, \@vals);
        }

}

# Then work on Notes
$summary_log->info("Processing data for Notes - Get Query");

$sth = do_execute($dbs, "
SELECT DISTINCT `Full Nodename`, `Application Notes`, `Backup Notes`, `Contract Notes`, `Customer Notes`,
                `General Notes`, `Hardware Notes`, `Other Notes`, `Patch Notes`, `Security Notes`, `Service Notes`, `System ID`
  FROM esl_cs_admin") or exit_application(2);

$summary_log->info("Processing data for Notes - Process data");

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

        # Application Notes
        my $note_value = $ref->{"Application Notes"} || "";
        if (length($note_value) > 0) {
                add_note($dbt, $computersystem_id, "ApplicationNote", $note_value) or exit_application(2);
        }

        # Backup Notes
        $note_value = $ref->{"Backup Notes"} || "";
        if (length($note_value) > 0) {
                add_note($dbt, $computersystem_id, "BackupNote", $note_value) or exit_application(2);
        }

        # Contract Notes
        $note_value = $ref->{"Contract Notes"} || "";
        if (length($note_value) > 0) {
                add_note($dbt, $computersystem_id, "ContractNote", $note_value) or exit_application(2);
        }

        # Customer Notes
        $note_value = $ref->{"Customer Notes"} || "";
        if (length($note_value) > 0) {
                add_note($dbt, $computersystem_id, "CustomerNote", $note_value) or exit_application(2);
        }

        # General Notes
        $note_value = $ref->{"General Notes"} || "";
        if (length($note_value) > 0) {
                add_note($dbt, $computersystem_id, "GeneralNote", $note_value) or exit_application(2);
        }

        # Hardware Notes
        $note_value = $ref->{"Hardware Notes"} || "";
        if (length($note_value) > 0) {
                add_note($dbt, $computersystem_id, "HardwareNote", $note_value) or exit_application(2);
        }

        # Other Notes
        $note_value = $ref->{"Other Notes"} || "";
        if (length($note_value) > 0) {
                add_note($dbt, $computersystem_id, "AdditionalNote", $note_value) or exit_application(2);
        }

        # Patch Notes
        $note_value = $ref->{"Patch Notes"} || "";
        if (length($note_value) > 0) {
                add_note($dbt, $computersystem_id, "PatchNote", $note_value) or exit_application(2);
        }

        # Security Notes
        $note_value = $ref->{"Security Notes"} || "";
        if (length($note_value) > 0) {
                add_note($dbt, $computersystem_id, "SecurityNote", $note_value) or exit_application(2);
        }

        # Service Notes
        $note_value = $ref->{"Service Notes"} || "";
        if (length($note_value) > 0) {
                add_note($dbt, $computersystem_id, "ServiceNote", $note_value) or exit_application(2);
        }

}

$summary_log->info("Processing data for Application Type - Query");

# Application Type Group
$sth = do_execute($dbs, "
SELECT `System Group Name`, `System Group Type`, `System ID`
  FROM esl_cs_admin
  WHERE `System Group Type` = 'application'") or exit_application(2);

$summary_log->info("Processing data for Application Type - Process data");

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

        my $application_type_group = $ref->{"System Group Name"} || "Review Application Type Group";
        # Find admin_id
        @fields = ("computersystem_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $admin_id;
        defined ($admin_id = get_field($dbt, "computersystem", "admin_id", \@fields, \@vals)) or exit_application(2);
        if (length($admin_id) > 0) {
                @fields = ("admin_id", "application_type_group");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                update_record($dbt, "admin", \@fields, \@vals);
        } else {
                # Create admin record and update computer record
                @fields = ("application_type_group");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                $admin_id = create_record($dbt, "admin", \@fields, \@vals) or exit_application(2);
                @fields = ("computersystem_id", "admin_id");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                update_record($dbt, "computersystem", \@fields, \@vals);
        }
}

$summary_log->info("Processing data for slo Availability - Query");

# Application Type Group
$sth = do_execute($dbs, "
SELECT `System Group Name`, `System Group Type`, `System ID`
  FROM esl_cs_admin
  WHERE `System Group Type` = 'slo'") or exit_application(2);

$summary_log->info("Processing data for slo Availability - Process data");

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

        my $slo = $ref->{"System Group Name"} || "Review SLO Group";
        # Find availability_id
        @fields = ("computersystem_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $availability_id;
        defined ($availability_id = get_field($dbt, "computersystem", "availability_id", \@fields, \@vals)) or exit_application(2);
        if (length($availability_id) > 0) {
                @fields = ("availability_id", "slo");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                update_record($dbt, "availability", \@fields, \@vals);
        } else {
                # Create availability record and update computer record
                @fields = ("slo");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                $availability_id = create_record($dbt, "availability", \@fields, \@vals) or exit_application(2);
                @fields = ("computersystem_id", "availability_id");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                update_record($dbt, "computersystem", \@fields, \@vals);
        }
}

$summary_log->info("Processing data for Billing Change Request - Query");

# Billing Resourceunit Code
$sth = do_execute($dbs, "
SELECT DISTINCT `System ID`, `Product Number`, `Start Date`, `Asset Notes`
  FROM esl_cs_admin
  WHERE `Project ID` = 'Billing Chg Code'") or exit_application(2);

$summary_log->info("Processing data for Billing Change Request - Process data");

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

        # Billing data
        my ($billing_id);
        my $billing_change_category = $ref->{"Asset Notes"} || "";
        my $billing_change_date = $ref->{"Start Date"} || "";
        if (length($billing_change_date) > 0) {
                $billing_change_date = conv_esl_date($billing_change_date);
        }
        my $billing_change_request_id = $ref->{"Product Number"} || "";
        @fields = ("billing_change_category", "billing_change_date", "billing_change_request_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $billing_id = create_record($dbt, "billing", \@fields, \@vals) or exit_application(2);
        } else {
                $billing_id = undef;
        }



        # ComputerSystem Update
        @fields = ("source_system_element_id", "billing_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                update_record($dbt, "computersystem", \@fields, \@vals);
        }
}

$summary_log->info("Processing data for Billing Resource Unit Code - Query");

# Billing Resourceunit Code
$sth = do_execute($dbs, "
SELECT `System Group Name`, `System Group Type`, `System ID`
  FROM esl_cs_admin
  WHERE `System Group Type` = 'billing group'") or exit_application(2);

$summary_log->info("Processing data for Billing Resource Unit Code - Process data");

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

        my $billing_resourceunit_code = $ref->{"System Group Name"} || "";
        $billing_resourceunit_code = tx_resourceunit($billing_resourceunit_code);
        # Find admin_id
        @fields = ("computersystem_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $billing_id;
        defined ($billing_id = get_field($dbt, "computersystem", "billing_id", \@fields, \@vals)) or exit_application(2);
        if (length($billing_id) > 0) {
                @fields = ("billing_id", "billing_resourceunit_code");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                update_record($dbt, "billing", \@fields, \@vals);
        } else {
                # Create billing record and update computer record
                @fields = ("billing_resourceunit_code");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                $billing_id = create_record($dbt, "billing", \@fields, \@vals) or exit_application(2);
                @fields = ("computersystem_id", "billing_id");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
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
