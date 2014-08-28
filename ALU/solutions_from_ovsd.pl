=head1 NAME

solutions_from_ovsd - Extract Solutions Information from OVSD

=head1 VERSION HISTORY

version 1.2 26 April 2012 DV

=over 4

=item *

If an application needs to be generated from an application instance, use 'product' as identifier for the application tag. This will ensure that the application name does not conflict with the application instance name.

=back

version 1.1 17 November 2011 DV

=over 4

=item *

Get Product Application Information from Product Portfolio File.

=back

version 1.0 10 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Solutions Attribute information from OVSD.

=head1 SYNOPSIS

 solutions_from_ovsd.pl [-t] [-l log_dir] [-c]

 solutions_from_ovsd.pl -h    Usage
 solutions_from_ovsd.pl -h 1  Usage and description of the options
 solutions_from_ovsd.pl -h 2  All documentation

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

my ($clear_tables);
my $appl_cnt = 0;
my $pf_cnt = 0;
my $unk_cnt = 0;

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
use DbUtil qw(db_connect do_stmt do_execute create_record get_recordid);
use ALU_Util qw(exit_application trim replace_cr remove_cr val_available translate ovsd_person tx_resourceunit conv_date);

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
   WHERE `FROM-CIID` = '$ciid' AND `RELATIONSHIP` = 'Consists Of'") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $source_system_element_id = $ref->{'TO-CIID'} || "";
    my @fields = ("source_system_element_id");
    my (@vals) = map { eval ("\$" . $_ ) } @fields;
    $application_id = get_recordid($dbt, "application", \@fields, \@vals);
    if (length($application_id) == 0) {
      my $data_log = Log::Log4perl->get_logger('Data');
      $data_log->error("Link Appl to Std SW defined for Std SW $source_system_element_id, but not found in applications file");
    } else {
      $appl_cnt++;
    }
  } else {
    $application_id = "";
  }

  return $application_id;
}

# ==========================================================================

=pod

=head2 Get CI Owner Company

Get the CI Owner Company for the OVSD Application Instance.

Initially we were told that ALU Retained / HP Managed depends on the application category, applying the logic below:

If application category = 'Custom Application', then this is ALU Owned, HP Managed Application.

If application category = 'BU Managed Application', then this is a ALU Retained Application.

If application category = 'R+D Application', then use 'Service Provider/Outsourced to SearchCode'. If this contains 'Retained', then the CI is ALU Retained. Otherwise the CI is HP Owned.



Later on this had to be changed to using the values of attributes 'Service Provider' and 'Sourcing Accountable'. If the attributes contained the string 'retained', then the application was ALU Retained. Otherwise it is an ALU Owned, HP Managed application (application to uCMDB, synchronize to ESL). One exception: 'R+D Applications' that are not ALU Retained are HP Owned and HP Managed (there are only approx. 20 R+D Applications in this situation).

Still later on an additional selection criteria was needed:

IF ((sourcing accountable = CG-Direct) AND (service_provider = 'CAPGEMINI')) THEN ApplicationInstance is ALU_Retained.

=cut

sub get_ci_owner_company($$$) {
  my ($application_group, $service_provider, $sourcing_accountable) = @_;

  my ($ci_owner_company);
  $application_group = lc($application_group);
  $sourcing_accountable = lc($sourcing_accountable);
  $service_provider = lc($service_provider);

  if ((index($sourcing_accountable, "retained") > -1) || (index($service_provider, "retained") > -1)) {
    $ci_owner_company = "ALU Retained";
  }
  elsif (($sourcing_accountable eq 'cg-direct') && ($service_provider eq 'capgemini')) {
    $ci_owner_company = "ALU Retained";
  }
  elsif (($application_group eq "custom application") || ($application_group eq "bu managed application")) {
    $ci_owner_company = "ALU Owned";
    #   } elsif ($application_group eq "bu managed application") {
    #           $ci_owner_company = "ALU Retained";
  }
  elsif ($application_group eq "r+d application") {
    # No need to test for Service Provider anymore, has been done before
    $ci_owner_company = "HP";
  }
  else {
    my $data_log = Log::Log4perl->get_logger('Data');
    $data_log->error("Unknown Category $application_group in ovsd_applications");
    $ci_owner_company = "";
  }

  return $ci_owner_company;
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

my $source_system = "OVSD_".time;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("availability", "application_instance", "billing", "contactrole", "assignment", "operations", "relations") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

$summary_log->info("Getting OVSD Application Attributes - Run DB Attributes collection after this");

=pod

=head2 OVSD Solution Selection Criteria

Status must be Active or New and the Master CMDB must be NULL (so the solution must be mastered in OVSD.

Category must be BU Managed Application, Custom Application or R+D Application. Recently a few solution records with category 'Application' were added to OVSD, but these records are excluded from processing.

=cut

my $sth = do_execute($dbs, "
SELECT CIID, NAME, `ALIAS NAMES (4000)`, `DESCRIPTION 4000`, CATEGORY, STATUS, ENVIRONMENT, SOX,
       `SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE`, LOCATION, NOTES, `DOC REF URL`, `SOLUTIONS PORTFOLIO ID`,
       `SOURCING ACCOUNTABLE`, `BUSINESS STAKEHOLDER NAME`, `BUSINESS STAKEHOLDER ORGANIZATION`, `RESOURCE UNIT`,
       `BILLING CHANGE CATEGORY`, `BILLING REQUEST NUMBER`, `LAST BILLING CHANGE DATE`, SEARCHCODE, `OWNER PERSON NAME`,
       `OWNER PERSON SEARCH CODE`
  FROM ovsd_applications
  WHERE ((STATUS = 'Active') OR (STATUS = 'New'))
    AND (`MASTER CMDB` is NULL)
    AND (NOT (CATEGORY <=> 'Application'))") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

  # Application Instance Information
  my ($application_instance_id);
  my $sox_system = $ref->{'SOX'} || "";
  if (lc($sox_system) eq "yes") {
    $sox_system = "SOX";
  } else {
    $sox_system = "";
  }
  my $source_system_element_id = $ref->{"CIID"} || "";
  my $appl_name_acronym = $ref->{'NAME'} || "";
  $appl_name_acronym = remove_cr($appl_name_acronym);
  my $appl_name_long = $ref->{'SEARCHCODE'} || "";
  my $appl_name_description = $ref->{'DESCRIPTION 4000'} || "";
  $appl_name_description = replace_cr($appl_name_description);
  my $service_provider = $ref->{'SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE'} || "";
  my $application_region = $ref->{'LOCATION'} || "";
  my $notes = $ref->{'NOTES'} || "";
  my $doc_ref_url = $ref->{'DOC REF URL'} || "";
  my $application_instance_tag = $ref->{'SEARCHCODE'} || "";
  $application_instance_tag = lc($application_instance_tag);
  my $instance_category = "ApplicationInstance";
  my $ci_owner = $ref->{"OWNER PERSON NAME"} || "";
  my $person_searchcode = $ref->{"OWNER PERSON SEARCH CODE"} || "";
  my $ovsd_searchcode = $ref->{"SEARCHCODE"} || "";

  # Availability
  # Handle Availability first since ENVIRONMENT is required for Application
  my ($availability_id);
  my $runtime_environment = $ref->{'ENVIRONMENT'} || "";
  my @fields = ("runtime_environment");
  my (@vals) = map { eval ("\$" . $_ ) } @fields;
  if ( val_available(\@vals) eq "Yes") {
    $availability_id = create_record($dbt, "availability", \@fields, \@vals);
  } else {
    #$availability_id = "";
    $availability_id = undef;
  }

  # Get Application Information
  my ($application_id);
  my $portfolio_id = $ref->{'SOLUTIONS PORTFOLIO ID'} || "";
  my $application_group = $ref->{'CATEGORY'} || "";
  my $application_type = translate($dbt, "ovsd_applications", "CATEGORY", $application_group, "ErrMsg");
  my $application_category = "business application";
  my $lifecyclestatus = $ref->{'STATUS'} || "";
  $lifecyclestatus = translate($dbt, "ovsd_applications", "STATUS", $lifecyclestatus, "ErrMsg");

  my $sourcing_accountable = $ref->{'SOURCING ACCOUNTABLE'} || "";
  # First review if this is the instance of a product
  # Note: this applies to 'Consists Of' relation,
  # which is only relevant for Databases
  # defined ($application_id = get_appl_sw($dbs, $dbt, $source_system_element_id)) or exit_application(2);
  # Application not known, find link to Portfolio ID
  if (not(defined($application_id)) || (length($application_id) == 0)) {
    if (length($portfolio_id) > 0) {
      # Check if Application has been defined with the Portfolio ID
      my @fields = ("portfolio_id");
      my (@vals) = map { eval ("\$" . $_ ) } @fields;
      # If Application is known, use application_id
      $application_id = get_recordid($dbt, "application",\@fields, \@vals);
      if (length($application_id) > 0) {
        # Instance from a Portfolio Application
        $pf_cnt++;
      }
    } else {
      # Portfolio ID not available
      # but try CI ID for Production Solution Instances.
      # It has been seen that CI ID is often the Portfolio ID
      # for the earlier solutions.
      # This will solve approx. 40 from the 290 Instances (leaves 250 issue records)
      if (lc($runtime_environment) eq "production") {
        $portfolio_id = $source_system_element_id;
        my @fields = ("portfolio_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        $application_id = get_recordid($dbt, "application",\@fields, \@vals);
        if (length($application_id) > 0) {
          # Instance from a Portfolio Application
          # Apparantly CI ID was the Portfolio ID
          $pf_cnt++;
        } else {
          # CI ID was not Portfolio ID
          # Reset Portfolio ID to blank
          $portfolio_id = "";
        }
      }
    }
  }
  # Application not known, try to find a match on Name (product acronym name) first
  if (not(defined($application_id)) || (length($application_id) == 0)) {
    # Set Application name to acronym name
    # Map applications on equal appl_name_acronym
    my $application_tag = trim(lc($appl_name_acronym));
    my @fields = ("application_tag");
    my (@vals) = map { eval ("\$" . $_ ) } @fields;
    $application_id = get_recordid($dbt, "application",\@fields, \@vals);
    if (length($application_id) == 0) {
      my @fields = ("source_system", "source_system_element_id", "portfolio_id",
                    "appl_name_acronym", "appl_name_long", "appl_name_description",
                    "application_category", "sourcing_accountable",
                    "application_tag", "application_type", "application_group");
      my (@vals) = map { eval ("\$" . $_ ) } @fields;
      if ( val_available(\@vals) eq "Yes") {
        $application_id = create_record($dbt, "application", \@fields, \@vals);
      } else {
        error("Application could not be created for $source_system_element_id");
        next;
      }
      $unk_cnt++;
    }
  }

  # Get Owner Company and Retained Information
  my $ci_owner_company = get_ci_owner_company($application_group, $service_provider, $sourcing_accountable);

  # Billing
  my ($billing_id);
  my $billing_change_category = $ref->{"BILLING CHANGE CATEGORY"} || "";
  my $billing_resourceunit_code = $ref->{"RESOURCE UNIT"} || "";
  $billing_resourceunit_code = tx_resourceunit($billing_resourceunit_code);
  my $billing_change_date = $ref->{"LAST BILLING CHANGE DATE"} || "";
  $billing_change_date = conv_date($billing_change_date);
  my $billing_change_request_id = $ref->{"BILLING REQUEST NUMBER"} || "";
  @fields = ("billing_change_category", "billing_resourceunit_code", "billing_change_date", "billing_change_request_id");
  (@vals) = map { eval ("\$" . $_ ) } @fields;
  if ( val_available(\@vals) eq "Yes") {
    $billing_id = create_record($dbt, "billing", \@fields, \@vals);
  } else {
    # The empty string is an invalid integer value, so use undef instead (=> becomes NULL in the database)
    #$billing_id = "";
    $billing_id = undef;
  }

  # UCMDB Application Type
  my $ucmdb_application_type;
  if ($ci_owner_company eq 'ALU Retained') {
    if (defined $ref->{'CATEGORY'} && $ref->{'CATEGORY'} eq 'R+D Application') {
      $ucmdb_application_type = 'R&D';
    }
    else {
      $ucmdb_application_type = 'BU-IT'
    }
  }
  else {
    $ucmdb_application_type = 'Business Application';
  }

  # Create Application Instance Record
  @fields = ("source_system", "source_system_element_id", "appl_name_acronym",
             "appl_name_long", "appl_name_description", "lifecyclestatus",
             "sox_system", "service_provider", "application_region", "ovsd_searchcode",
             "doc_ref_url", "availability_id", "application_id", "billing_id",
             "application_instance_tag", "instance_category", "ci_owner_company", "ci_owner", "ucmdb_application_type");
  (@vals) = map { eval ("\$" . $_ ) } @fields;
  if ( val_available(\@vals) eq "Yes") {
    $application_instance_id = create_record($dbt, "application_instance", \@fields, \@vals);
  }

  # Handle Technical Owner Contact
  my $person_id = ovsd_person($dbt, $ci_owner, $person_searchcode);
  if (length($person_id) > 0) {
    my $contact_type = "Customer Instance Owner";
    my @fields = ("application_instance_id", "contact_type", "person_id");
    my (@vals) = map { eval ("\$" . $_ ) } @fields;
    if ( val_available(\@vals) eq "Yes") {
      my $contactrole_id = create_record($dbt, "contactrole", \@fields, \@vals);
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
