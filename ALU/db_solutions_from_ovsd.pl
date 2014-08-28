=head1 NAME

db_solutions_from_ovsd - Extract Solutions Information from OVSD.

=head1 VERSION HISTORY

version 1.1 17 November 2011 DV

=over 4

=item *

Update to link from OS Name to Application / Product File.

=back

version 1.0 10 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Database Solutions Attribute information from OVSD.

=head1 SYNOPSIS

 db_solutions_from_ovsd.pl [-t] [-l log_dir] [-c]

 db_solutions_from_ovsd.pl -h    Usage
 db_solutions_from_ovsd.pl -h 1  Usage and description of the options
 db_solutions_from_ovsd.pl -h 2  All documentation

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
use DbUtil qw(db_connect do_execute create_record get_recordid);
use ALU_Util qw(exit_application val_available translate tx_resourceunit conv_date ovsd_person);
use Data::Dumper;

#############
# subroutines
#############

# ==========================================================================

=pod

=head2 Get DB Standard Software Link

This procedure will get the link between the Database and the Standard Software. The link is in the table ovsd_db_rels. Search for Relation Type 'Consists Of' and TO-CATEGORY "SW-STD" (Standard Software). There should be max. one link.

Find the CIID from the Standard Software, then get application_id for this CIID.

This subroutine is NOT used for now ?

=cut

sub get_db_sw($$$) {
  my ($dbs, $dbt, $ciid) = @_;
  my ($application_id);

  my $sth = do_execute($dbs, "
SELECT `TO-CIID`
  FROM ovsd_db_rels
  WHERE `FROM-CIID` = '$ciid'
    AND `RELATION_TYPE` = 'Consists Of'") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $source_system_element_id = $ref->{'TO-CIID'} || "";
    my @fields = ("source_system_element_id");
    my (@vals) = map { eval ("\$" . $_ ) } @fields;
    $application_id = get_recordid($dbt, "application", \@fields, \@vals);

    if (length($application_id) == 0) {
      my $data_log = Log::Log4perl->get_logger('Data');
      $data_log->error("Link DB to Std SW defined for Std SW $source_system_element_id, but not found in applications file");
    }
  } else {
    $application_id = "";
  }

  return $application_id;
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
        undef $clear_tables;
} else {
        $clear_tables = "Yes";
}

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values
# ==========================================================================

my $source_system = "OVSD_".time;
my $newapp_cnt = 0;
my $extapp_cnt = 0;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

# Clear tables if required
# REVERSE LOGIC: default is NOT to clear tables.
# Only clear tables if flag is specified.
# Clear tables if required
# REVERSE LOGIC REVERSE LOGIC REVERSE LOGIC
if (defined $clear_tables) {
  foreach my $table ("application", "availability", "application_instance", "contactrole", "person", "assignment", "operations", "compsys_esl") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

$summary_log->info("Getting OVSD DB Applications and Attributes");

my $sth = do_execute($dbs, "
SELECT ID, NAME, `DESCRIPTION_4000_`, CATEGORY, SEARCHCODE, STATUS, ENVIRONMENT, SOX, OUTSOURCED_TO_SC,
       NOTES, MISC_INFO, OS_NAME, OS_VER_REL_SP, RESOURCE_UNIT, BILLING_CHANGE_CATEGORY,
       BILLING_REQUEST_NUMBER, LAST_BILLING_CHANGE_DATE, OWNER_PERSON_NAME, OWNER_PERSON_SC
  FROM ovsd_db
  WHERE ((STATUS = 'Active') OR (STATUS = 'New'))") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
        # Application Instance Information
        my ($application_instance_id);
        my $source_system_element_id = $ref->{"ID"} || "";
        my $appl_name_description = $ref->{'DESCRIPTION_4000_'} || "";
        my $lifecyclestatus = $ref->{'STATUS'} || "";
        $lifecyclestatus = translate($dbt, "ovsd_applications", "STATUS", $lifecyclestatus, "ErrMsg");
        my $ovsd_searchcode = $ref->{'SEARCHCODE'} || "";
        my $sox_system = $ref->{'SOX'} || "";
        if (lc($sox_system) eq "yes") {
                $sox_system = "SOX";
        } else {
                $sox_system = "";
        }
        my $ci_owner = $ref->{'OWNER_PERSON_NAME'} || "";
        my $person_searchcode = $ref->{'OWNER_PERSON_SC'} || '';
        my $service_provider = $ref->{'OUTSOURCED_TO_SC'} || "";
        # Get ALU Retained Information
        my $ci_owner_company = $service_provider;
        if (index(lc($ci_owner_company), "retained") > -1) {
                $ci_owner_company = "ALU Retained";
        } else {
                $ci_owner_company = "HP";
        }
        my $version = $ref->{'OS_VER_REL_SP'} || "";
        my $instance_category = "DBInstance";

        # Application Information
        # The Application (Database) Name is concatenation (OS_Name, OS_Version)
        # There are a few Database instances with NULL in OS_NAME. In this case
        # use 'oracle' as the default value.
        my $appl_name_acronym = $ref->{'OS_NAME'} || "oracle";
        my $appl_name_long = lc($appl_name_acronym) . "*" . lc($version);
        my $application_tag = $appl_name_long;
        my @fields = ("application_tag");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $application_id = get_recordid($dbt, "application", \@fields, \@vals);
        if (length($application_id) == 0) {
                # Application not known, create one
                my $application_category = $ref->{'CATEGORY'} || ""; # Value is database
                my $application_type = "TechnicalProduct";
                my @fields = ("application_category", "appl_name_long", "appl_name_acronym",
                                      "source_system_element_id", "source_system", "application_tag",
                                      "application_type", "version");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                if ( val_available(\@vals) eq "Yes") {
                        $application_id = create_record($dbt, "application", \@fields, \@vals) or exit_application(2);
                } else {
                        $application_id = undef;
                }
                $newapp_cnt++;
        } else {
                $extapp_cnt++;
        }

        # Application Instance Information
        $appl_name_acronym = $ref->{'NAME'} || "";
        $appl_name_long = $ref->{'SEARCHCODE'} || "";
        my $application_instance_tag = $ref->{'SEARCHCODE'} || "";
        $application_instance_tag = lc($application_instance_tag);

        # Availability
        my ($availability_id);
        my $runtime_environment = $ref->{'ENVIRONMENT'} || "";
        @fields = ("runtime_environment");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $availability_id = create_record($dbt, "availability", \@fields, \@vals) or exit_application(2);
        } else {
                $availability_id = undef;
        }

        # Billing
        my ($billing_id);
        my $billing_change_category = $ref->{"BILLING_CHANGE_CATEGORY"} || "";
        my $billing_resourceunit_code = $ref->{"RESOURCE_UNIT"} || "";
        $billing_resourceunit_code = tx_resourceunit($billing_resourceunit_code);
        my $billing_change_date = $ref->{"LAST_BILLING_CHANGE_DATE"} || "";
        $billing_change_date = conv_date($billing_change_date);
        my $billing_change_request_id = $ref->{"BILLING_REQUEST_NUMBER"} || "";
        @fields = ("billing_change_category", "billing_resourceunit_code", "billing_change_date", "billing_change_request_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $billing_id = create_record($dbt, "billing", \@fields, \@vals) or exit_application(2);
        } else {
                $billing_id = undef;
        }

        # Create Application Instance Record
        @fields = ("source_system", "source_system_element_id", "appl_name_acronym",
                       "appl_name_description", "lifecyclestatus", "ovsd_searchcode",
                           "sox_system", "service_provider", "availability_id", "appl_name_long",
                           "application_id", "billing_id", "application_instance_tag",
                       "instance_category", "ci_owner_company", "ci_owner", "version");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $application_instance_id = create_record($dbt, "application_instance", \@fields, \@vals) or exit_application(2);
        }

        # Handle Technical Owner Contact
        my $person_id = ovsd_person($dbt, $ci_owner, $person_searchcode);
        if (length($person_id) > 0) {
                my $contact_type = "Customer Instance Owner";
                my @fields = ("application_instance_id", "contact_type", "person_id");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                if ( val_available(\@vals) eq "Yes") {
                        my $contactrole_id = create_record($dbt, "contactrole", \@fields, \@vals) or exit_application(2);
                }
        }

}

$summary_log->info("$extapp_cnt databases coupled to existing products, $newapp_cnt new products created");

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
