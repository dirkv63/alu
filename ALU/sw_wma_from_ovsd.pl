=head1 NAME

sw_wma_from_ovsd - webMethod Adapter Processing for OVSD.

=head1 VERSION HISTORY

version 1.0 27 April 2012 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will process the Category 'webMethods Adapter'. The CIs are available only in the TO- section of the ovsd_server_rels table. Each distinct CI needs to be converted into a business application and an ALU owned HP managed business application instance. The script ovsd_solution_relations.pl script need to read and process the server relations.

=head1 SYNOPSIS

 sw_wma_from_ovsd.pl [-t] [-l log_dir]

 sw_wma_from_ovsd.pl -h    Usage
 sw_wma_from_ovsd.pl -h 1  Usage and description of the options
 sw_wma_from_ovsd.pl -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=item B<-c>

The option to clear tables is not available here.

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
use ALU_Util qw(exit_application val_available remove_cr translate tx_resourceunit conv_date ovsd_person);
use Data::Dumper;

#############
# subroutines
#############

# ==========================================================================

=pod

=head2 Get Application to Standard Software Link

*** Should no longer be used ***

This procedure will get the link between the Application Instance and the Standard Software. The link is in the table ovsd_apps_rels. Search for Relation Type 'Consists Of' and TO-CATEGORY "SW-STD" (Standard Software). There should be max. one link.

Find the CIID from the Standard Software, then get application_id for this CIID.

Note that this information is only relevant for Databases, to link the database with its Database type (Oracle,

=cut

sub get_appl_sw($$$) {
  my ($dbs, $dbt, $ciid) = @_;
  my ($application_id);

  my $sth = do_execute($dbs, "
SELECT `TO-CIID`
  FROM ovsd_apps_rels
  WHERE `FROM-CIID` = '$ciid'
    AND `RELATIONSHIP` = 'Consists Of'") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $source_system_element_id = $ref->{'TO-CIID'} || "";
    my @fields = ("source_system_element_id");
    my (@vals) = map { eval ("\$" . $_ ) } @fields;
    $application_id = get_recordid($dbt, "application", \@fields, \@vals);

    if (length($application_id) == 0) {
      my $data_log = Log::Log4perl->get_logger('Data');
      $data_log->error("Link Appl to Std SW defined for Std SW $source_system_element_id, but not found in applications file");
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
  $clear_tables = "Yes";
}

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values
# ==========================================================================

my $data_log = Log::Log4perl->get_logger('Data');

my $source_system = "OVSD_".time;
my $appl_cnt = 0;
my $pf_cnt = 0;
my $unk_cnt = 0;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

$summary_log->info("Getting OVSD webMethods Adapter Attributes.");

# XXX Dit lijkt me een bug :
# De kolommen `BILLING_CHANGE_CATEGORY`, `LAST BILLING CHANGE DATE`, `BILLING REQUEST NUMBER` bestaan niet in ovsd_server_rels

my $sth = do_execute($dbs, "
SELECT `TO-CIID`, `TO-NAME`, `TO-SEARCH CODE`, `TO-DESCRIPTION (4000)`, `TO-SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE`,
       `TO-LOCATION`, `TO-OWNER PERSON NAME`, `TO-OWNER PERSON SEARCH CODE`, `TO-ENVIRONMENT`, `TO-CATEGORY`,
       `TO-STATUS`, `TO-RESOURCE UNIT`
  FROM ovsd_server_rels
  WHERE ((`TO-STATUS` = 'Active') OR (`TO-STATUS` = 'New'))
    AND (`TO-CATEGORY` = 'webMethods Adapter')") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
        # Application Instance Information
        my ($application_instance_id);
        my $source_system_element_id = $ref->{"TO-CIID"} || "";
        my $appl_name_acronym = $ref->{'TO-NAME'} || "";
        $appl_name_acronym = remove_cr($appl_name_acronym);
        my $appl_name_long = $ref->{'TO-SEARCH CODE'} || "";
        my $appl_name_description = $ref->{'TO-DESCRIPTION (4000)'} || "";
        my $service_provider = $ref->{'TO-SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE'} || "";
        my $application_region = $ref->{'TO-LOCATION'} || "";
        my $application_instance_tag = $ref->{'TO-SEARCH CODE'} || "";
        $application_instance_tag = lc($application_instance_tag);
        my $instance_category = "ApplicationInstance";
        my $ci_owner = $ref->{"TO-OWNER PERSON NAME"} || "";
        my $person_searchcode = $ref->{"TO-OWNER PERSON SEARCH CODE"} || "";
        my $ovsd_searchcode = $ref->{"TO-SEARCH CODE"} || "";

        # Availability
        # Handle Availability first since ENVIRONMENT is required for Application
        my ($availability_id);
        my $runtime_environment = $ref->{'TO-ENVIRONMENT'} || "";
        # As it happens, the TO-ENVIRONMENT and the environment acronym are not in line.
        # Use environment acronym
        my @env_acr_arr = split /-/, $appl_name_long;
        my $env_acr = pop @env_acr_arr;
        if (lc($env_acr) eq "tst") {
                $runtime_environment = "Test";
        } elsif (lc($env_acr) eq "dev") {
                $runtime_environment = "Development";
        }
        my @fields = ("runtime_environment");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $availability_id = create_record($dbt, "availability", \@fields, \@vals) or exit_application(2);
        } else {
                $availability_id = undef;
        }

        # Get Application Information
        my ($application_id);
        my $portfolio_id = "";
        my $application_group = $ref->{'TO-CATEGORY'} || "";
        my $application_type = "Application";
        my $application_category = "business application";
        my $lifecyclestatus = $ref->{'TO-STATUS'} || "";
        $lifecyclestatus = translate($dbt, "ovsd_applications", "STATUS", $lifecyclestatus, "ErrMsg");

        # Application not known, try to find a match on Name (product acronym name) first
        if (not(defined($application_id)) || (length($application_id) == 0)) {
                # Set Application name to acronym name
                my $application_tag = "product".lc($appl_name_acronym);
                my @fields = ("application_tag");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                $application_id = get_recordid($dbt, "application",\@fields, \@vals);
                if (length($application_id) == 0) {
                        my @fields = ("source_system", "source_system_element_id", "portfolio_id",
                                       "appl_name_acronym", "appl_name_long", "appl_name_description",
                                           "application_category",
                                                "application_tag", "application_type", "application_group");
                        my (@vals) = map { eval ("\$" . $_ ) } @fields;
                        if ( val_available(\@vals) eq "Yes") {
                                $application_id = create_record($dbt, "application", \@fields, \@vals) or exit_application(2);
                        } else {
                                $data_log->error("Application could not be created for $source_system_element_id");
                                next;
                        }
                        $unk_cnt++;
                }
        }

        # Get Owner Company and Retained Information
        my $ci_owner_company = "ALU owned";

        # Billing
        my ($billing_id);
        #my $billing_change_category = $ref->{"BILLING CHANGE CATEGORY"} || ""; # does not exists
        my $billing_change_category = '';
        my $billing_resourceunit_code = $ref->{"TO-RESOURCE UNIT"} || "";
        $billing_resourceunit_code = tx_resourceunit($billing_resourceunit_code);
        #my $billing_change_date = $ref->{"LAST BILLING CHANGE DATE"} || ""; # does not exists
        my $billing_change_date = '';
        $billing_change_date = conv_date($billing_change_date);
        # my $billing_change_request_id = $ref->{"BILLING REQUEST NUMBER"} || ""; # does not exists
        my $billing_change_request_id = '';
        @fields = ("billing_change_category", "billing_resourceunit_code", "billing_change_date", "billing_change_request_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $billing_id = create_record($dbt, "billing", \@fields, \@vals) or exit_application(2);
        } else {
                $billing_id = undef;

        }

        # Create Application Instance Record
        @fields = ("source_system", "source_system_element_id", "appl_name_acronym",
                       "appl_name_long", "appl_name_description", "lifecyclestatus",
                           "service_provider", "application_region", "ovsd_searchcode",
                           "availability_id", "application_id", "billing_id",
                           "application_instance_tag", "instance_category", "ci_owner_company", "ci_owner");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $application_instance_id = create_record($dbt, "application_instance", \@fields, \@vals) or exit_application(2);
        }

        # Get Workgroup Information
        # store_workgroup_data($dbs, $dbt, "application_instance_id", $application_instance_id, $source_system_element_id);

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
$summary_log->info("$pf_cnt instances from portfolio applications, $appl_cnt instances from standard software, $unk_cnt instances from unknown product");

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
