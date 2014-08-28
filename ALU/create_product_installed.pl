=head1 NAME

create_product_installed - This script will create a Product Data Template.

=head1 VERSION HISTORY

version 1.0 16 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract installed product information for the installed product template.

=head1 SYNOPSIS

 create_product_installed.pl [-t] [-l log_dir]

 create_product_installed -h	Usage
 create_product_installed -h 1  Usage and description of the options
 create_product_installed -h 2  All documentation

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

my $template = 'installedproduct_interface_template.xlsx';
my $version = "1520";					# Version Number

# output files (a hash ref !)
my ($CompSys);

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
use DbUtil qw(db_connect do_select do_execute);
use ALU_Util qw(getsource installed2instance);
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

=head2 Init Outfiles

This procedure will open and initialize all data files for output.

=cut

sub init_outfiles {
  # Get Source system
  my ($source, $subbusiness) = @_;

  # Installed Product Main File

  # only use sub-business names for ESL
  $subbusiness = '' unless ($source eq 'ESL');

  unless (exists $CompSys->{$subbusiness}) {
    my $subbusiness_suffix = ($subbusiness eq '' ) ? '' : '-' . $subbusiness;

    $CompSys->{$subbusiness} = TM_CSV->new({ source => $source . $subbusiness_suffix, comp_name => 'InstalledProduct',
                                             tabname => 'Component', version => $version });

    unless ($CompSys->{$subbusiness}) {
      ERROR("Could not open output file, exiting...");
      return;
    }

  }

  return $CompSys->{$subbusiness};

}

# ==========================================================================

=pod

=head2 Close OutFiles

This procedure will close all datafiles for output in an orderly fashion.

=cut

sub close_outfiles {
  # Product Main File

  foreach my $k (keys %$CompSys) {
    $CompSys->{$k}->close or return;
  }

  return 1;
}

# ==========================================================================

{

  # build a map of all esl_id => esl_subbusiness. This is (much) faster than performing one query for every esl_id.
  # (from 4 minutes to 10 seconds)
  my $esl_map;

  sub esl_subbusiness($$) {
    my ($dbt, $esl_id) = @_;

    my $rtv = [ ];

    unless (defined $esl_map) {
      my $esl_data = do_select($dbt, "SELECT DISTINCT esl_id, esl_subbusiness FROM compsys_esl") or return;
      foreach my $row (@$esl_data) {
        my $esl_id = $row->[0] || '';
        my $esl_subbusiness = $row->[1] || '';

        if (length($esl_subbusiness) > 0) {
          push @{ $esl_map->{$esl_id} }, $esl_subbusiness;
        }
      }
    }

    $rtv = [ @{ $esl_map->{$esl_id} } ] if (exists $esl_map->{$esl_id});

#    my $sth = do_execute($dbt, "SELECT esl_subbusiness FROM compsys_esl WHERE esl_id = $esl_id") or return;
#
#    while (my $ref = $sth->fetchrow_hashref) {
#      my $esl_subbusiness = $ref->{esl_subbusiness} || "";
#      if (length($esl_subbusiness) > 0) {
#        push @$rtv, $esl_subbusiness;
#      }
#    }

    return wantarray ? @$rtv : $rtv;
  }
}

# ==========================================================================

sub handle_comp($$) {
  my ($dbt, $source) = @_;

  # Get Installed Product Data from Installed Application table
  my $sth = do_execute($dbt, "
SELECT a.application_tag, i.application_instance_tag, i.source_system_element_id
  FROM application a, application_instance i
  WHERE i.source_system like '$source%'
    AND a.application_type = 'TechnicalProduct'
    AND a.application_id = i.application_id") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    # Product Component
    my $InstalledProductID = $ref->{application_instance_tag} || "";
    $InstalledProductID = installed2instance($InstalledProductID);
    my $InstalledProduct = "InstalledProduct";
    my $SourceSystemElementID = $ref->{source_system_element_id} || "";

    # Print Information to Installed Product output file
    # InstalledProductID, InstalledProduct, SourceSystemElementID

    my @subbus_arr = ('');
    if ($source eq 'ESL') {
      # Get ESL Sub Business Array
      @subbus_arr = esl_subbusiness($dbt, $SourceSystemElementID);
    }

    foreach my $subbusiness (@subbus_arr) {
      # get the file handle for this sub business

      my $FH = init_outfiles($source, $subbusiness) or return;

      unless ($FH->write($InstalledProductID, $InstalledProduct, $SourceSystemElementID))
        { ERROR("write CompSys failed"); return; }
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

$summary_log->info("Create InstalledProduct Extract for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

# Get Source system for Installed Application
my $sourcearr = getsource($dbt, "application_instance", "source_system");

unless ($sourcearr) {
  ERROR("Found no sources in the cim.application_instance table !");
  exit_application(1);
}

foreach my $source (@$sourcearr) {
  $summary_log->info("Processing 'InstalledProduct' data for Source $source");

  # Handle Data for Product
  handle_comp($dbt, $source) or exit_application(1);

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
