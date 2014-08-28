=head1 NAME

create_product - This script will create a Product Data Template.

=head1 VERSION HISTORY

version 1.1 24 April 2012 DV

=over 4

=item *

Bug 415, Application and Technical Product Information needs to be delivered in separate files.

=item *

Extend Usage Count subroutine to include Application to Server dependencies (next to Application to Technical Product dependencies).

=back

version 1.1 26 April 2012 DV

=over 4

=item *

Add a test to trap empty Product Names (bug 421).

=back

version 1.0 14 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract Product information for the Product template. There is a split-up in output between Applications and Technical Products. Also the script can handle 'all' products and Operating Systems, depending on an input variable.

=head1 SYNOPSIS

 create_product.pl [-t] [-l log_dir] [-o]

 create_product -h	Usage
 create_product -h 1  Usage and description of the options
 create_product -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=item B<-o>

If specified, then add file name for OS extenstion.

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -c, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
###########

my $template = 'product_interface_template.xlsx';
my $version = "2344";				# Version Number
# output files
my ($os_product);
my ($CompSys_app, $CompSys_tp);

$| = 1;                         # flush output sooner

#####
# use
#####

use warnings;			    # show warning messages
use strict;
use Carp;
use Getopt::Std;		    # Handle input params
use Pod::Usage;			    # Allow Usage information
use Log::Log4perl qw(:easy);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_execute do_stmt);
use ALU_Util qw(getsource replace_cr remove_cr);
use TM_CSV;
use Data::Dumper;

#############
# subroutines
#############

sub exit_application($) {
    my ($return_code) = @_;

    my $summary_log = Log::Log4perl->get_logger('Summary');
    $summary_log->info("Exit application with error code $return_code.");

    exit($return_code);
}

# ==========================================================================

=pod

=head2 Init Outfiles

This procedure will open and initialize all data files for output.

=cut

sub init_outfiles($) {
  my ($source) = @_;

  my $os_ext = ($os_product eq "Yes") ? '_os' : '';

  # Component Main File for Applications
  $CompSys_app = TM_CSV->new({ source => $source, comp_name => 'Product', tabname => 'Component', suffix => 'Application' . $os_ext, version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # Component Main File for Technical Products
  $CompSys_tp = TM_CSV->new({ source => $source, comp_name => 'Product', tabname => 'Component', suffix => 'TechnicalProduct' . $os_ext, version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  return 1;
}


=pod

=head2 Close OutFiles

This procedure will close all datafiles for output in an orderly fashion.

=cut

sub close_outfiles {
  # Product Component File for Applications
  $CompSys_app->close or return;

  # Product Component File for Technical Products
  $CompSys_tp->close or return;

  return 1;
}

# ==========================================================================

sub get_compsys_esl($$) {
  my ($dbt, $compsys_esl_id) = @_;

  # Initialize variables
  my $rtv = [ map { '' } 1 .. 2 ];

  return (wantarray ? @$rtv : $rtv) unless ((length($compsys_esl_id) > 0) && ($compsys_esl_id > 0));

  # Get Values
  my $sth = do_execute($dbt, "
SELECT esl_business, esl_subbusiness
  FROM compsys_esl
  WHERE compsys_esl_id = $compsys_esl_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $esl_business = $ref->{esl_business} || "";
    my $esl_subbusiness = $ref->{esl_subbusiness} || "";

    $rtv = [ $esl_business, $esl_subbusiness ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub handle_comp($$) {
  my ($dbt, $source) = @_;

  my $data_log = Log::Log4perl->get_logger('Data');

  # Get Product Data from Application table or OperatingSystem Table
  my ($appsid_table);
  if ($os_product eq "Yes") {
    $appsid_table = "operatingsystem";
  } else {
    $appsid_table = "application_instance";
  }

  my $sth = do_execute($dbt, "
SELECT application_id, application_type, appl_name_acronym, application_tag, manufacturer, appl_name_description,
       version, sourcing_accountable, os_type, application_category, cma, ci_owner_company, source_system_element_id,
       security_category, security_class, compsys_esl_id, portfolio_id
  FROM application
  WHERE application_id IN (SELECT DISTINCT(application_id)
                             FROM $appsid_table)") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    # Product Component
    my $application_id = $ref->{application_id};
    my $Product = $ref->{application_type} || "";
    my $Product_Name = $ref->{appl_name_acronym} || "";
    $Product_Name = remove_cr($Product_Name);
    if (length($Product_Name) == 0) {
      $data_log->error("No Product Name defined for $application_id");
    }
    my $ProductID = $ref->{application_tag} || "";
    $ProductID = remove_cr($ProductID);
    my $Vendor = $ref->{manufacturer} || "";
    my $Product_Description = $ref->{appl_name_description} || "";
    $Product_Description = replace_cr($Product_Description);
    my $Product_Version = $ref->{version} || "";
    my $Sourcing_Accountable = $ref->{sourcing_accountable} || "";
    my $OSType = $ref->{os_type} || "";
    my $External_Source_ID = "";	# To Be Defined
    my $External_Tool = "";			# To Be Defined
    my $Application_Category = $ref->{application_category} || "";
    my $CMA_Code = $ref->{cma} || "";
    my $CI_Owner = $ref->{ci_owner_company} || "";
    my ($hpOwned, $hpManaged);

    if (index(lc($CI_Owner), "retained") > -1) {
      $hpOwned = "FALSE";
      $hpManaged = "FALSE";
    } elsif (index(lc($CI_Owner), "alu owned") > -1) {
      $hpOwned = "FALSE";
      $hpManaged = "TRUE";
    } elsif (index(lc($CI_Owner), "hp") > -1) {
      $hpOwned = "TRUE";
      $hpManaged = "TRUE";
    } else {
      $hpOwned = "UNKNOWN";
      $hpManaged = "UNKNOWN";
    }
    my $SourceSystemElementID = $ref->{source_system_element_id} || "";
    my $SecurityCategory = $ref->{security_category} || "";
    my $SecurityClass = $ref->{security_class} || "";

    # Compsys ESL
    # Get Information
    my $compsys_esl_id = $ref->{compsys_esl_id} || "";
    my ($Customer_Business, $Customer_SubBusiness) = get_compsys_esl($dbt, $compsys_esl_id) or return;

    # Portfolio Data
    my $PortfolioID = $ref->{portfolio_id} || "";

    # Notes
    # get_notes($dbt, $computersystem_id, $fqdn);

    # Print Information to Product output file

    my $CompSys;
    if (lc($Product) eq 'application') {
      $CompSys = $CompSys_app;
    } elsif (lc($Product) eq "technicalproduct") {
      $CompSys = $CompSys_tp;
    } else {
      $data_log->error("Unknown Product (application_type) $Product for $ProductID");
      next;
    }

    # ProductID, Product, Product Name, Customer Business, Customer Sub-Business, PortfolioID, Vendor,
    # Product Description, Product Version, Sourcing Accountable, OSType, External Source ID, External Tool,
    # Application Category, CMA Code, hpOwned, hpManaged, SourceSystemElementID, SecurityCategory, SecurityClass

    unless ($CompSys->write($ProductID, $Product, $Product_Name, $Customer_Business,  $Customer_SubBusiness, $PortfolioID, $Vendor,
                            $Product_Description, $Product_Version, $Sourcing_Accountable, $OSType, $External_Source_ID, $External_Tool,
                            $Application_Category, $CMA_Code, $hpOwned, $hpManaged, $SourceSystemElementID, $SecurityCategory, $SecurityClass))
      { ERROR("write CompSys ($Product) failed"); return; }
  }

  return 1;
}

# ==========================================================================

sub update_applcnt ($$$$) {
  my ($dbt, $source, $application_id, $cnt) = @_;
  my ($sourcefld);

  my $data_log = Log::Log4perl->get_logger('Data');

  if (lc($source) eq "esl") {
    $sourcefld = "esl_cnt";
  } elsif (lc($source) eq "a7") {
    $sourcefld = "a7_cnt";
  } elsif (lc($source) eq "ovsd") {
    $sourcefld = "ovsd_cnt";
  } else {
    $data_log->error("Source $source not known");
    return;
  }

  do_stmt($dbt,
"UPDATE application SET $sourcefld = $cnt
   WHERE application_id = $application_id") or return;

  return 1;
}

# ==========================================================================

=pod

=head2 Reference Count

This procedure will count how many times a product or application is referenced in a source. This is done by counting the number of application instances that are linked to the application. The number of Application instances to an application should be limited to one for each environment: 1 for production, 1 for development, 1 for testing....

Application_id can be NULL for ESL Instances from ESL Business Application Solutions.

If there is no application instance for an application, then the application itself can be removed.

There should be no Technical Products without Technical Product Instances, due to the way Technical Products are created in cim. A Technical Product is created only if it there is a reference to a Technical Product Instance.

=cut

sub handle_refcnt($$) {
  my ($dbt, $source) = @_;

  my $sth = do_execute($dbt, "
SELECT count(*) as cnt, application_id
  FROM application_instance
  WHERE application_id is not null
  GROUP BY application_id") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    my $application_id = $ref->{application_id} || "";
    my $cnt = $ref->{cnt} || "";
    update_applcnt($dbt, $source, $application_id, $cnt) or return;
  }

  return 1;
}

# ==========================================================================
######
# Main
######

# Handle input values
my %options;
getopts("tl:h:o", \%options) or pod2usage(-verbose => 0);

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

$summary_log->info("Start application");

# OS File name extenstion?
$os_product = (defined($options{o})) ? 'Yes' : 'No';

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values
# ==========================================================================

$summary_log->info("Create Product Extract for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

# Get Source system for Installed Application
# Don't take Application, since this is a collection of Sources.
my ($tablename, $fieldname);
if ($os_product eq 'Yes') {
  $tablename = "computersystem";
  $fieldname = "computersystem_source";
} else {
  $tablename = "application_instance";
  $fieldname = "source_system";
}

my $sourcearr = getsource($dbt, $tablename, $fieldname);

unless ($sourcearr) {
  ERROR("Found no sources in the `$tablename' table !");
  exit_application(1);
}

unless (@$sourcearr == 1) {
  if (grep { $_ =~ m/ESL/ } @$sourcearr) {
    $sourcearr = [ 'ESL' ];
  } else {
    ERROR("Found multiple sources (" . join(', ', @$sourcearr) . "), only one expected");
    exit_application(1);
  }
}

foreach my $source (@$sourcearr) {
  $summary_log->info("Processing Product data for Source $source");

  # Initialize datafiles for output
  init_outfiles($source) or exit_application(1);

  # Handle Data for Product
  handle_comp($dbt, $source) or exit_application(1);
  handle_refcnt($dbt, $source) or exit_application(1);

  close_outfiles() or exit_application(1);
}

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
