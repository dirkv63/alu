=head1 NAME

create_hw_rels - This script will create a Hardware Relations Data File.

=head1 VERSION HISTORY

version 1.0 14 October 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract hardware relations data for the hardware relations template.

=head1 SYNOPSIS

 create_hw_rels.pl [-t] [-l log_dir]

 create_hw_rels -h	Usage
 create_hw_rels -h 1  Usage and description of the options
 create_hw_rels -h 2  All documentation

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
my ($HW_Rels);

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
use ALU_Util qw(getsourcesystem hw_tag);
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

sub init_outfiles {
  # Get Source system
  my $source = shift;

  # Hardware Relations File
  $HW_Rels = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'bladeInEnclosure', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  return 1;
}

=pod

=head2 Close OutFiles

This procedure will close all datafiles for output in an orderly fashion.

=cut

sub close_outfiles {
  # Hardware Relations
  $HW_Rels->close or return;

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

$summary_log->info("Create Hardware Relations for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

# Get Source system
my $source = getsourcesystem($dbt, "physicalbox", "source_system");

unless ($source) {
  ERROR("Found no source in the physicalbox table !");
  exit_application(1);
}

init_outfiles($source) or exit_application(1);

# Get Physical Box Data
my $sth = do_execute($dbt, "
SELECT `tag` , `in_enclosure`
  FROM physicalbox
  WHERE in_enclosure IS NOT NULL") or exit_application(1);

while (my $ref = $sth->fetchrow_hashref) {
  my $Enclosure = $ref->{in_enclosure} || "";
  my $BladeServer = $ref->{tag} || "";
  $Enclosure = hw_tag($Enclosure);
  $BladeServer = hw_tag($BladeServer);

  # Print Information to output file
  # HostedAssetTag, HostingAssetTag
  unless ($HW_Rels->write($BladeServer, $Enclosure)) { ERROR("write HW_Rels failed"); exit_application(1); }
}

close_outfiles() or exit_application(1);


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
