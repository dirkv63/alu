=head1 NAME

create_product_rels - This script will create a Computer Relations Data File.

=head1 VERSION HISTORY

version 1.1 03 February 2012 DV

=over 4

=item *

Remove 'Business Product Instance Depends Upon ComputerSystem' processing. This is done in script create_bpi_rels.pl.

=back

version 1.0 21 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract relations data for Product Files.

=head1 SYNOPSIS

 create_product_rels.pl [-t] [-l log_dir]

 create_product_rels -h         Usage
 create_product_rels -h 1       Usage and description of the options
 create_product_rels -h 2       All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -c, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
###########

my $version = "3659";

#####
# use
#####

use warnings;                       # show warning messages
use strict;
use Carp;
use Getopt::Std;                    # Handle input params
use Pod::Usage;                     # Allow Usage information
use Log::Log4perl qw(:easy);
use ALU_Util qw(getsource installed2instance replace_cr);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_execute);
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

=pod

head2 PrdInstalledOnCS Product Installed On ComputerSystem

Links Installed Product CIs with Computersystems on which they are installed.

A7: SOL_INSTANCE and SOL_SOLUTION class of products, with solution-type relations to ComputerSystem (not with Backup, Security, Scheduling).

OVSD: Database Instances with Depends on ComputerSystem relation (not with Backup Relation).

ESL: ESL Instances of TechnicalProduct CIs.

=cut

sub handle_prdcs($$) {
        my ($dbt, $source) = @_;

        my $data_log = Log::Log4perl->get_logger('Data');

        # Initialize datafiles for output
        # Product Installed On ComputerSystem
        my $PrdCS = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'PrdInstalledOnCS', version => $version });

        unless ($PrdCS) {
          ERROR("Could not open output file, exiting...");
          return;
        }

        my $sth = do_execute($dbt, "
SELECT left_name, right_name
  FROM relations
  WHERE relation like '%installed%'
    AND left_type = 'ComputerSystem'
    AND source_system like '$source%'") or return;

        while (my $ref = $sth->fetchrow_hashref) {
                my $LeftName = $ref->{left_name} || "";
                my $RightName = $ref->{right_name} || "";
                $RightName = installed2instance($RightName);
                my $directory = "";
                # FQDN, InstalledProductId, directory
                unless ($PrdCS->write($LeftName, $RightName, $directory)) {
                  ERROR("write PrdCS failed");
                  return;
                }
        }

        # close all datafiles for output in an orderly fashion.
        $PrdCS->close or return;
        return 1;
}

=pod

=head2 Installed Product link to its Product and to its Instance

This information is available in the tables application and application_instance. Find all application_instances from applications of type TechnicalProduct. Get application_tag and application_instance_tag. Convert application_instance_tag to installed_application_tag.

Product - Installed Product and Installed Product - Instance of a Product are available at the same time.

=cut

sub handle_prdprd($$) {
        my ($dbt, $source) = @_;

        # Initialize datafiles for output
        # Installed Product CI relation to its Product
        my $PrdPrd = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'PrdInstalledPrd', version => $version });

        # Installed Product CI relation to Product Instance
        my $PrdInstance = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'prdInstOfInstalledPrd', version => $version });

        unless ($PrdPrd && $PrdInstance) {
          ERROR("Could not open output file, exiting...");
          return;
        }

        my $sth = do_execute($dbt, "
SELECT i.application_instance_tag, a.application_tag
  FROM application_instance i, application a
  WHERE a.application_id = i.application_id
    AND a.application_type =  'TechnicalProduct'") or return;

        while (my $ref = $sth->fetchrow_hashref) {
                my $application_tag = $ref->{application_tag} || "";
                my $application_instance_tag = $ref->{application_instance_tag} || "";
                my $installed_application_tag = installed2instance($application_instance_tag);

                # Technical Product to Installed Product link
                my $LeftName = replace_cr($application_tag);
                my $RightName = $installed_application_tag;
                # ProductId, InstalledProductId
                unless ($PrdPrd->write($LeftName, $RightName)) {
                  ERROR("write PrdPrd failed");
                  return;
                }

                # Installed Product to Product Instance link
                $LeftName = $application_instance_tag;
                $RightName = $installed_application_tag;
                # ProductInstanceId, InstalledProductId
                unless ($PrdInstance->write($LeftName, $RightName)) {
                  ERROR("write PrdInstance failed");
                  return;
                }

        }

        # close all datafiles for output in an orderly fashion.
        $PrdPrd->close or return;
        $PrdInstance->close or return;
        return 1;
}

=pod

=head2 Business Product Composition

This links the Business Product into the different Business Product Instances.

=cut

sub handle_busprd($$) {
        my ($dbt, $source) = @_;

        # Initialize datafiles for output
        # Business Product Composition
        my $BusPrd = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'appComposition', version => $version });

        unless ($BusPrd) {
          ERROR("Could not open output file, exiting...");
          return;
        }

        my $sth = do_execute($dbt, "
SELECT i.application_instance_tag, a.application_tag
  FROM application_instance i, application a
  WHERE a.application_id = i.application_id
    AND a.application_type =  'Application'") or return;

        while (my $ref = $sth->fetchrow_hashref) {
                my $application_tag = $ref->{application_tag} || "";
                my $application_instance_tag = $ref->{application_instance_tag} || "";
                my $LeftName = $application_instance_tag;
                my $RightName = replace_cr($application_tag);
                # ProductInstanceID, ProductID
                unless ($BusPrd->write($LeftName, $RightName)) {
                  ERROR("write BusPrd failed");
                  return;
                }
        }

        # close all datafiles for output in an orderly fashion.
        $BusPrd->close or return;
        return 1;

}

=pod

=head2 Business Product Instance Composition

This procedure will collect Business Product Instance Dependencies.

=head3 Instance to Instance dependency

OVSD: Dependency between the Business Application and another Business Application, or between the Business Application and the Database.

A7: Dependency between the Business Application and another Business Application, or betweeen the Business Application and a Middleware (SOL_SOLUTION or SOL_INSTANCE).

The relations table is populated using the scripts a7_solution_relations.pl (for A7) and ovsd_solution_relations.pl (for OVSD).

ESL: Solution to Solution, Solution to Instance and Instance to Instance reports not yet available.

Split-up between TechnicalProductInstance Dependency and ApplicationInstance Dependency. Note that ApplicationInstance to ApplicationInstance Dependency is not yet available.

=cut

sub handle_busprdinst($$) {
        my ($dbt, $source) = @_;

        # Initialize datafiles for output

        # Application Instance Composition
        my $AppInstComp = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'appInstComposition', version => $version });

        # Product Instance Relationships
        my $TechPrdInstRel = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'techPrdInstRelationships', version => $version });

        unless ($AppInstComp && $TechPrdInstRel) {
          error("Could not open output file, exiting...");
          return;
        }

        my $sth = do_execute($dbt, "
SELECT left_name, application_type, application_instance_id, i.application_id, right_name
  FROM relations r, application_instance i, application a
  WHERE relation = 'depends on'
    AND right_type = 'Solution'
    AND left_name = application_instance_tag
    AND i.application_id = a.application_id
    AND r.source_system like '$source%'") or return;

        while (my $ref = $sth->fetchrow_hashref) {
                my $LeftName = $ref->{left_name} || "";
                my $RightName = $ref->{right_name} || "";
                my $application_type = $ref->{application_type} || "";
                if (lc($application_type) eq "application") {
                  # BusinessProductInstanceId, ChildProductInstanceId
                  unless ($AppInstComp->write($LeftName, $RightName)) {
                    ERROR("write AppInstComp failed");
                    return;
                  }
                } elsif (lc($application_type) eq "technicalproduct") {
                  my $type = "Cooperate";
                  # ParentTechnicalProductInstanceID, ChildTechnicalProductInstanceID, type
                  unless ($TechPrdInstRel->write($LeftName, $RightName, $type)) {
                    ERROR("write TechPrdInstRel failed");
                    return;
                  }
                }
        }

        # close all datafiles for output in an orderly fashion.
        $AppInstComp->close or return;
        $TechPrdInstRel->close or return;
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

$summary_log->info("Start application");

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}
# End handle input values

# ==========================================================================

$summary_log->info("Create Product Relations for Template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

# Get Source system for Installed Application
my $sourcearr = getsource($dbt, "relations", "source_system");

unless ($sourcearr) {
  ERROR("Found no sources in the relations table !");
  exit_application(1);
}

if (not(@$sourcearr == 1)) {
  ERROR("Found multiple sources (" . join(', ', @$sourcearr) . "), only one expected");
  exit_application(1);
}

foreach my $source (@$sourcearr) {
  $summary_log->info("Processing `cd' data for Source $source");

  # Handle All Relations
  handle_prdcs($dbt, $source) or exit_application(1);
  handle_prdprd($dbt, $source) or exit_application(1);
  handle_busprd($dbt, $source) or exit_application(1);
  handle_busprdinst($dbt, $source) or exit_application(1);
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
