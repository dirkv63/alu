=head1 NAME

products_from_pf - Extract Product Information from Portfolio File.

=head1 VERSION HISTORY

version 1.1 27 January 2012 DV

=over 4

=item *

Update to handle ALU Retained infra from Application Portfolio File.

=back

version 1.0 10 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract unique Product information from Portfolio File. It should run as the first script for CMO Product extract.

=head1 SYNOPSIS

 products_from_pf.pl [-t] [-l log_dir] [-c]

 products_from_pf -h	Usage
 products_from_pf -h 1  Usage and description of the options
 products_from_pf -h 2  All documentation

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

my ($clear_tables, %apps);

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
use DbUtil qw(db_connect do_stmt do_execute create_record);
use ALU_Util qw(exit_application trim replace_cr check_table val_available);

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

my $source_system = "PF_".time;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(1);
my $dbt = db_connect('cim') or exit_application(1);

# Check on number of columns
my $columns = 9;
my $rows = 1220;
check_table($dbs, "pf", $columns, $rows);

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("application", "acronym_mapping") {
    do_stmt($dbt, "truncate $table") or exit_application(1);
  }
}

$summary_log->info("Getting ALU Portfolio Application Attributes");

my $sth = do_execute($dbs, "
SELECT ID, `App ID`, `App Acronym`, `App Name`, `App Desc`, `Sourcing Accountable`, source, `NSA Indicator`, `Business Critical App Identification`
  FROM pf") or exit_application(1);

while (my $ref = $sth->fetchrow_hashref) {

  # Application Information
  my $portfolio_id = $ref->{'App ID'} || "";
  # unique technical key
  # XXX to minimize diff => old beahviour
  #my $source_system_element_id = $ref->{'ID'} || "";
  my $source_system_element_id = "";
  # This triggers a bug in instances_from_esl.pl : application is searched via source_system_element_id (and this is not unique !!)
  # so we link with the wrong application_id

  my $appl_name_long = $ref->{'App Name'} || "NotDefined";
  $appl_name_long = replace_cr($appl_name_long);

  my $application_tag = lc($appl_name_long);
  # Check if $application_tag exists and not null
  if (exists($apps{lc(trim($application_tag))})) {
    # Appl name exists already, convert to unique name
    $application_tag = "PF_DuplName*$application_tag*$portfolio_id";
  }
  $apps{lc(trim($application_tag))} = 1;

  my $appl_name_description = $ref->{'App Desc'} || "";
  $appl_name_description = replace_cr($appl_name_description);

  my $appl_name_acronym = $ref->{'App Acronym'} || "";
  my $sourcing_accountable = $ref->{'Sourcing Accountable'} || "";

  # Check if I know about 'Retained' info
  my $ci_owner_company = lc($sourcing_accountable);
  if (index($ci_owner_company, "retained") > -1) {
    $ci_owner_company = "ALU Retained";
  } else {
    $ci_owner_company = "";
  }

  my $application_group = $ref->{'source'} || "";
  my $application_category = "business application";
  my $application_type = "Application";

  my $nsa = $ref->{'NSA Indicator'} || "";
  if (index(lc($nsa), "nsa") > -1) {
    $nsa = "Yes";
  } else {
    $nsa = "";
  }

  my $business_critical = $ref->{'Business Critical App Identification'} || "";
  if (length($business_critical) > 0) {
    $business_critical = "Yes";
  } else {
    $business_critical = "";
  }

  my @fields = ("appl_name_long", "appl_name_description", "appl_name_acronym", "application_group",
                "application_category", "source_system", "source_system_element_id",
                "portfolio_id", "application_tag", "application_type",
                "ci_owner_company", "nsa", "business_critical");
  my (@vals) = map { eval ("\$" . $_ ) } @fields;

  my ($application_id);
  if ( val_available(\@vals) eq "Yes") {
    $application_id = create_record($dbt, "application", \@fields, \@vals);
  } else {
    $application_id = "";
  }

}

$dbs->disconnect;
$dbt->disconnect;
$summary_log->info("Exit application with success");
exit(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
