=head1 NAME

create_locations - Create Master Location File.

=head1 VERSION HISTORY

version 1.0 28 October 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Master Location Data.

=head1 SYNOPSIS

 create_locations.pl [-t] [-l log_dir]

 create_locations -h	Usage
 create_locations -h 1  Usage and description of the options
 create_locations -h 2  All documentation

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

my $template = 'reference_interface_template.xlsx';
my $version = "1";
# output files
my ($Location);

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
  # XXX speciaal geval : tabname is leeg !!!

  # Hardware Relations File
  $Location = TM_CSV->new({ source => 'master', comp_name => 'Datacenter', tabname => '', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  return 1;
}

# ==========================================================================

=pod

=head2 Close OutFiles

This procedure will close all datafiles for output in an orderly fashion.

=cut

sub close_outfiles {

  # Hardware Relations
  $Location->close or return;

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

$summary_log->info("Create Location Master for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

init_outfiles() or exit_application(1);

# Get Physical Box Data
my $sth = do_execute($dbt, "
SELECT `location_access`, `location_category`, `location_code`, `location_notes`, `location_owner`, `location_tier`,
       `time_zone`, `building`, `city`, `country`, `country_iso_code`, `country_iso_name`, `floor`, `full_shipping_address`,
       `state_province`, `streetaddress`, `zip`
  FROM  location l, address a
  WHERE l.address_id = a.address_id") or exit_application(1);
# WHERE a.address_id = 1";

while (my $ref = $sth->fetchrow_hashref) {
  # my $access = $ref->{location_access} || "";
  my $access = "";
  my $category = $ref->{location_category} || "";
  my $code = $ref->{location_code} || "";
  # my $notes = $ref->{location_notes} || "";
  my $notes = "";
  my $owner = $ref->{location_owner} || "";
  my $tier = $ref->{location_tier} || "";
  # Time Zone reporting for Datacenters is different than any other ESL Time Zone reporting
  # However as Datacenters should not be created by Data Migration
  # a default value in TM expected format will be provided.
  my $time_zone = "(GMT+01:00) Brussels, Copenhagen, Madrid, Paris";
  my $building = $ref->{building} || "";
  my $city = $ref->{city} || "";
  my $country = $ref->{country} || "";
  my $floor = $ref->{floor} || "";
  # my $full_shipping_address = $ref->{full_shipping_address} || "";
  my $full_shipping_address = "";
  my $state_province = $ref->{state_province} || "";
  my $streetaddress = $ref->{streetaddress} || "";
  my $zip = $ref->{zip} || "";

  # Print Information to output file
  # DataCenterID, datacenter, category, accessNotes, notes, owner, tier, timezone, building, floor, street1,
  # city, state, postalcode, isoCountryCode, full_shipping_address
  unless ($Location->write($code, 'datacenter', $category, $access, $notes, $owner, $tier, $time_zone, $building, $floor, $streetaddress,
                           $city, $state_province, $zip, $country, $full_shipping_address))
    { ERROR("write Location failed"); exit_application(1); }
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
