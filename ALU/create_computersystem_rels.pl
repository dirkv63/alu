=head1 NAME

create_product_rels - This script will create a Computer Relations Data File.

=head1 VERSION HISTORY

version 1.0 21 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract relations data for Product Files.

=head1 SYNOPSIS

 create_product_rels.pl [-t] [-l log_dir]

 create_product_rels -h		Usage
 create_product_rels -h 1	Usage and description of the options
 create_product_rels -h 2	All documentation

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

my $template = 'componentdependency_interface_template.xlsx';
my $version = "1223";
# output files
my ($clComp, $clPComp, $farmComp, $farmMgr, $virtOnCS, $Dodgy);

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
use DbUtil qw(db_connect do_execute);
use ALU_Util qw(getsource);
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
  # Get Source system
  my ($source) = @_;

  # clusterComposition
  $clComp = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'clusterComposition', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # clusterPackageComposition
  $clPComp = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'clusterPackageComposition', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # farmComposition
  $farmComp = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'farmComposition', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # farmManager
  $farmMgr = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'farmManager', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # Virtual Server On ComputerSystem
  $virtOnCS = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'virtualSrvrOnCS', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # Dodgy Relation
  $Dodgy = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'dodgyRelationships', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  return 1;
}

=pod

=head2 Close OutFiles

This procedure will close all datafiles for output in an orderly fashion.

=cut

sub close_outfiles {
  # clusterComposition
  $clComp->close or return;

  # Instance Depends on ComputerSystem
  $clPComp->close or return;

  # Instance Depends On Instance
  $farmComp->close or return;

  # Instance Depends On Instance
  $farmMgr->close or return;

  # Product Installed On ComputerSystem
  $virtOnCS->close or return;

  # Dodgy Relations
  $Dodgy->close or return;

  return 1;
}

# ==========================================================================

# clusterComposition
sub handle_clcomp($$) {
  my ($dbt, $source) = @_;
  # ESL or OVSD?
  if (index($source, "ESL") == 0) {
    return handle_clcomp_esl($dbt, $source);
  } elsif (index($source, "OVSD") == 0) {
    return handle_clcomp_ovsd($dbt, $source);
  } elsif (index($source, "A7") == 0) {
    return handle_clcomp_a7($dbt, $source);
  } else {
    my $data_log = Log::Log4perl->get_logger('Data');
    $data_log->error("Source $source not found for Relation clusterComposition handling");
    return;
  }
}

sub handle_clcomp_esl($$) {
  my ($dbt, $source) = @_;

  my $sth = do_execute($dbt, "
SELECT left_name, right_name
  FROM relations
  WHERE relation = 'Cluster'
    AND source_system like '$source%'") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    # XXXXX Die zijn hier gewisseld !
    my $LeftName = $ref->{right_name} || "";
    my $RightName = $ref->{left_name} || "";
    # ClusterFQDN, ContainedFQDN
    unless ($clComp->write($LeftName, $RightName)) { ERROR("write clComp failed"); return; }
  }

  return 1;
}

sub handle_clcomp_ovsd($$) {
  my ($dbt, $source) = @_;

  my $sth = do_execute($dbt, "
SELECT left_name, right_name
  FROM relations
  WHERE relation = 'has cluster node'
    AND source_system like '$source%'") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    my $LeftName = $ref->{left_name} || "";
    my $RightName = $ref->{right_name} || "";
    # ClusterFQDN, ContainedFQDN
    unless ($clComp->write($LeftName, $RightName)) { ERROR("write clComp failed"); return; }
  }

  return 1;
}

sub handle_clcomp_a7($$) {
  my ($dbt, $source) = @_;

  my $sth = do_execute($dbt, "
SELECT distinct left_name, right_name
  FROM relations
  WHERE relation = 'has cluster node'
    AND source_system like '%$source%'") or return;
  while (my $ref = $sth->fetchrow_hashref) {
    my $LeftName = $ref->{left_name} || "";
    my $RightName = $ref->{right_name} || "";
    # LeftComponent, RightComponent, Behaviour
    unless ($clComp->write($LeftName, $RightName)) { ERROR("write Dodgy failed"); return; }
  }

  return 1;
}

# ==========================================================================

# Cluster Package Composition
# Cluster Package only in ESL or OVSD.
# but similar node in A7 - avoid

sub handle_clpcomp($$) {
  my ($dbt, $source) = @_;

  # First get ESL Cluster Package Relations
  my $sth = do_execute($dbt, "
SELECT left_name, right_name
  FROM relations
  WHERE relation like 'Cluster Node%'
    AND source_system like 'ESL%'") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    my $LeftName = $ref->{left_name} || "";
    my $RightName = $ref->{right_name} || "";
    # ClusterPackageFQDN, ContainedFQDN, role
    unless ($clPComp->write($LeftName, $RightName, '')) { ERROR("write clPComp failed"); return; }
  }

  # Then get OVSD Cluster Package Relations or A7 Cluster Package Relations
  $sth = do_execute($dbt, "
SELECT left_name, right_name
  FROM relations
  WHERE relation = 'Cluster Package On'
    AND source_system like '$source%'") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    my $LeftName = $ref->{left_name} || "";
    my $RightName = $ref->{right_name} || "";
    # ClusterPackageFQDN, ContainedFQDN, role
    unless ($clPComp->write($LeftName, $RightName, '')) { ERROR("write clPComp failed"); return; }
  }

  return 1;
}

# ==========================================================================

=pod

=head2 Farm Composition

This relation expects the Farm in the right name component and the virtual or physical
server in the left name component. The Transition Model template expects the Farm on first position and the virtual server or the physical server on the second position.

The theory a Virtual server can also be a 'Server for Virtual Guest'. The Role of the server is in 'virtualization role' attribute.

=cut

# Farm Composition
sub handle_farmcomp($$) {
  my ($dbt, $source) = @_;

  my $sth = do_execute($dbt, "
SELECT left_name, right_name
  FROM relations
  WHERE ((relation like '%farm%') OR (relation = 'Is Physical Server For'))
    AND source_system like '$source%'") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    my $LeftName = $ref->{right_name} || "";
    my $RightName = $ref->{left_name} || "";
    # FarmFQDN, ContainedFQDN
    unless ($farmComp->write($LeftName, $RightName)) { ERROR("write farmComp failed"); return; }
  }

  # Also extract Virtual Center Manager devices for the Farm
  # In case of Virtual Center Manager relation, the
  # farm is in the left name, the computersystem with role 'Virtual Center Manager'
  # is in the right name.

  $sth = do_execute($dbt, "
SELECT left_name, right_name
  FROM relations
  WHERE relation = 'Virtual Center Manager'") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    my $LeftName = $ref->{left_name} || "";
    my $RightName = $ref->{right_name} || "";
    # FarmFQDN, ManagerFQDN
    unless ($farmMgr->write($LeftName, $RightName)) { ERROR("write farmMgr failed"); return; }
  }

  return 1;
}

# ==========================================================================

# Virtual Server on ComputerSystem
sub handle_virtoncs($$) {
  my ($dbt, $source) = @_;

  my $sth = do_execute($dbt, "
SELECT left_name, right_name
  FROM relations
  WHERE ((relation = 'is virtual server on') OR
		 (relation = 'Server for Virtual Guest') OR 
	     (relation = 'is running on server') OR 
		 (relation = 'Virtual Host'))
    AND source_system like '$source%'") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    my $LeftName = $ref->{left_name} || "";
    my $RightName = $ref->{right_name} || "";
    # HostedFQDN, HostingFQDN
    unless ($virtOnCS->write($LeftName, $RightName)) { ERROR("write virtOnCS failed"); return; }
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


$summary_log->info("Start application");

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values
# ==========================================================================

$summary_log->info("Create Product Relations for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

# Get Source system for Installed Application
my $sourcearr = getsource($dbt, "relations", "source_system");

unless ($sourcearr) {
  ERROR("Found no sources in the relations table !");
  exit_application(1);
}

foreach my $source (@$sourcearr) {
  $summary_log->info("Processing `cd' for Source $source");

  # Initialize datafiles for output
  init_outfiles($source) or exit_application(1);

  # Handle All Relations
  handle_clcomp($dbt, $source) or exit_application(1);
  handle_clpcomp($dbt, $source) or exit_application(1);
  handle_farmcomp($dbt, $source) or exit_application(1);
  handle_virtoncs($dbt, $source) or exit_application(1);

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
