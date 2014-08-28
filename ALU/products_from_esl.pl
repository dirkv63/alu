=head1 NAME

products_from_esl - Extract Product Information from ESL.

=head1 VERSION HISTORY

version 1.1 23 April 2012 DV

=item *

Bug 416 - Do not extract ESL Solution OS as Technical Product, use OS description from attributes instead.

=back

version 1.1 24 April 2012 DV

=over 4

=item *

Bug 416 - Exclude OS Solutions for ESL Technical Product Extract.

=item *

On request of Transition Model team (meeting 23/04/2012), do not extract information from ESL Solution Category 'business service'. This category shows up in ESL only and not in a Source for Transformation Assetcenter or OVSD so Transition Model will never have to create a business service.

=back

version 1.0 10 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract unique Product / Solution information from ESL. Solutions from ESL are Business Product Instances, that need to be linked to the Product file, or Technical Products, that need to go into the Product File.

Business Product Instances are Solution Categories: business application.

Technical Products are all other categories: business service, collaboration, database, management tool, os, standard software, webcomponent.

This script will extract Technical Products from ESL and add them to the Application table.

=head1 SYNOPSIS

 products_from_esl.pl [-t] [-l log_dir] [-c]

 products_from_esl -h	Usage
 products_from_esl -h 1  Usage and description of the options
 products_from_esl -h 2  All documentation

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

#####
# use
#####

use warnings;			    # show warning messages
use strict;
use File::Basename;
use Getopt::Std;		    # Handle input params
use Pod::Usage;			    # Allow Usage information
use Log::Log4perl qw(:easy);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_execute create_record) ;
use ALU_Util qw(exit_application replace_cr val_available);

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

# Clear data by default
$clear_tables = "Yes" unless (defined $options{"c"});

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values
# ==========================================================================

my $source_system = "ESL_".time;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(1);
my $dbt = db_connect('cim') or exit_application(1);

# Contact names need to be email addresses,
# Verify if this is the case

my $sth = do_execute($dbs, "
SELECT `Solution Customer Instance Owner` as contact
  FROM esl_instance_work
  WHERE `Solution Customer Instance Owner` is not null
  LIMIT 0,1") or exit_application(1);

while (my $ref = $sth->fetchrow_hashref) {
  # Find contact
  my $email_address = $ref->{"contact"} || "";
  if (index($email_address, "@") > 0) {
    $summary_log->info("esl_instance_work table seems to have emails as contact");
  }
  else {
    ERROR("esl_instance_work does not seem to have email addresses as contacts, exiting...");
    exit_application(1);
  }
}

# Clear tables if required
if (defined $clear_tables) {
  my @tables = ("contactrole", "compsys_esl");

  foreach my $table (@tables) {
    $summary_log->info("Truncate table $table");

    unless ($dbt->do("truncate $table")) {
      ERROR("Could not truncate table `$table'. Error: ". $dbt->errstr);
      exit_application(1);
    }
  }
}

$summary_log->info("Getting ESL Product Application Attributes");

$sth = do_execute($dbs, "
SELECT DISTINCT `Solution ID`, `Solution Category`, `Solution Name`, `Solution Description`, `Solution CMA`, Business,
                `External Application ID`, `External Tool`
  FROM esl_instance_work
  WHERE NOT (`Solution Category` = 'business application')
    AND NOT (`Solution Category` = 'os')
    AND NOT (`Solution Category` = 'business service')") or exit_application(1);

while (my $ref = $sth->fetchrow_hashref) {
  # Compsys_ESL information
  my ($compsys_esl_id);
  my $esl_business = $ref->{'Business'} || "";
  my @fields = ("esl_business");
  my (@vals) = map { eval ("\$" . $_ ) } @fields;
  if ( val_available(\@vals) eq "Yes") {
    $compsys_esl_id = create_record($dbt, "compsys_esl", \@fields, \@vals) or exit_application(1);
  } else {
    $compsys_esl_id = undef;
  }

  # Application Information
  my ($application_id);
  my $portfolio_id = $ref->{'External Application ID'} || "";
  my $source_system_element_id = $ref->{'Solution ID'} || "";
  my $application_category = $ref->{'Solution Category'} || "";
  my $appl_name_long = $ref->{'Solution Name'} || "NotAvailable";
  $appl_name_long = replace_cr($appl_name_long);
  my $appl_name_description = $ref->{'Solution Description'} || "";
  my $cma = $ref->{'Solution CMA'} || "";
  my $ext_source_system = $ref->{'External Tool'} || "";
  my $application_type = "TechnicalProduct";
  # Ensure ESL Specific Application Tag.
  # ESL Solution Name is unique, no need for verification (yet?)
  my $application_tag = "ESL*" . lc($appl_name_long);
  my $appl_name_acronym = lc($appl_name_long);


  @fields = ("application_category", "appl_name_long", "appl_name_description", "appl_name_acronym",
             "cma", "source_system", "source_system_element_id", "compsys_esl_id",
             "portfolio_obj_id", "ext_source_system", "application_type", "application_tag");
  (@vals) = map { eval ("\$" . $_ ) } @fields;

  if ( val_available(\@vals) eq "Yes") {
    $application_id = create_record($dbt, "application", \@fields, \@vals) or exit_application(1);
  } else {
    $application_id = "";
  }
}

# No work on Contact Types for Application
# ESL Solutions - Category Technical Products does not require Contact Persons.
# my @contact_types = ("Solution Customer Instance Owner", "Solution Customer Instance Support", "Customer Instance Support Escalation", "Solution Delivery Instance Owner", "Solution Delivery Instance Support", "Instance Account Delivery Manager", "Instance Service Lead");
# foreach my $contact_type (@contact_types) {
#	get_contacts($dbs, $dbt, "esl_instance_work", $contact_type, "application");
# }

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
