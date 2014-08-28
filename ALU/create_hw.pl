=head1 NAME

create_hw - This script will create a Hardware Template

=head1 VERSION HISTORY

version 1.1 08 May 2012 DV

=over 4

=item *

Remove AllLocations processing. This is replaced with the Master Locations File.

=back

version 1.0 28 July 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract hardware information for the hardware template.

=head1 SYNOPSIS

 create_hw.pl [-t] [-l log_dir]

 create_hw -h	Usage
 create_hw -h 1  Usage and description of the options
 create_hw -h 2  All documentation

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

my $template = 'hardware_interface_template.xlsx';
my $version = "1186";

# output files
my ($HW, $Location, $Processor);

$| = 1;                         # flush output sooner

#####
# use
#####

use warnings;			    # show warning messages
use strict;
use Carp;
use Getopt::Std;                    # Handle input params
use Pod::Usage;                     # Allow Usage information
use Log::Log4perl qw(:easy);
use ALU_Util qw(hw_tag getsource);
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

sub init_outfiles($) {
  my ($source) = @_;

  # Initialize datafiles for output

  # Hardware Main File
  $HW = TM_CSV->new({ source => $source, comp_name => 'Hardware', tabname => 'Component', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # Location File
  $Location = TM_CSV->new({ source => $source, comp_name => 'Hardware', tabname => 'LocationList', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  # Processor File
  $Processor = TM_CSV->new({ source => $source, comp_name => 'Hardware', tabname => 'ProcessorList', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  return 1;
}

# ==========================================================================

=pod

=head2 Close OutFiles

This procedure will close all datafiles for output in an orderly fashion.

=cut

sub close_outfiles {
  # Hardware
  $HW->close or return;

  # Locations
  $Location->close or return;

  # Processor
  $Processor->close or return;

  return 1;
}

# ==========================================================================

sub get_asset($$) {
  my ($dbt, $asset_id) = @_;

  my $rtv = [ map { '' } 1 .. 3 ];

  unless ((length($asset_id) > 0) && ($asset_id > 0)) {
    return wantarray ? @$rtv : $rtv;
  }

  # Get Info
  my $sth = do_execute($dbt, "
SELECT assetnumber, ordernumber, orderdate
  FROM asset
  WHERE asset_id = $asset_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
     $rtv = [ $ref->{assetnumber} || "", $ref->{ordernumber} || "", $ref->{orderdate} || "" ];
   }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_detailedlocation($$$) {
  my ($dbt, $AssetTag, $detailedlocation_id) = @_;

  # Get Values
  my $sth = do_execute($dbt, "
SELECT location_code, floor_slot
  FROM detailedlocation d, location l
  WHERE detailedlocation_id = $detailedlocation_id
    AND d.location_id = l.location_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $LocationDescription = $ref->{floor_slot} || ""; # XXX not used ???
    my $DataCenterID = $ref->{location_code} || "";

    # Print Information to output file
    # AssetTag, DataCenterID, Building, Wing, Floor, Room, RoomLocation, LocationDescription
    unless ($Location->write($AssetTag, $DataCenterID, '', '', '', '', '', '')) { ERROR("write Location failed"); return; }
  }

  return 1;
}

# ==========================================================================

sub get_product($$$) {
  my ($dbt, $assettag, $physicalproduct_id) = @_;

  my $rtv = [ map { '' } 1 .. 8 ];

  unless (length($physicalproduct_id) > 0) {
    return wantarray ? @$rtv : $rtv;
  }

  # Get Values
  my $sth = do_execute($dbt, "
SELECT serialnumber, memcapacity, partnumber, vendorequipmenttype, manufacturer, model, physical_diskspace, hw_type, cpu_id
  FROM physicalproduct
  WHERE physicalproduct_id = $physicalproduct_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $serialnumber = $ref->{serialnumber} || "";
    my $memcapacity = $ref->{memcapacity} || "";
    my $partnumber = $ref->{partnumber} || "";
    my $vendorequipmenttype = $ref->{vendorequipmenttype} || "";
    my $manufacturer = $ref->{manufacturer} || "";
    my $model = $ref->{model} || "";
    my $physical_diskspace = $ref->{physical_diskspace} || "";
    my $hw_type = $ref->{"hw_type"} || "";
    my $cpu_id = $ref->{"cpu_id"} || "";

    # Get CPU Information
    if (length($cpu_id) > 0) {
      get_processor($dbt, $assettag, $cpu_id) or return;
    }

     $rtv = [ $memcapacity, $manufacturer, $partnumber, $serialnumber, $model, $vendorequipmenttype, $physical_diskspace, $hw_type ];
  }

  return wantarray ? @$rtv : $rtv;
}

# ==========================================================================

sub get_processor($$$) {
  # Initialize Variables
  my ($dbt, $AssetTag, $cpu_id) = @_;

  # Get Values
  my $sth = do_execute($dbt, "
SELECT clockspeed, corespercpu,cputype, cpufamily, numberofcpus
  FROM cpu
  WHERE cpu_id = $cpu_id") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $numberofcpus = $ref->{numberofcpus} || "";
    my $MaxClockSpeed = $ref->{clockspeed} || "";
    my $CPU_Family = $ref->{cpufamily} || "";
    my $cores_per_CPU = $ref->{corespercpu} || "";
    my $CPU_Type = $ref->{cputype} || "";
    if ($numberofcpus eq "") {
      $numberofcpus = 1;
    }

    for (my $DeviceID = 1; $DeviceID <= $numberofcpus; $DeviceID++) {
      # Print Information to output file
      # AssetTag, DeviceID, MaxClockSpeed, CPU Family, number of cores, CPU Type

      unless ($Processor->write($AssetTag, $DeviceID, $MaxClockSpeed, $CPU_Family, $cores_per_CPU, $CPU_Type))
        { ERROR("write Processor failed"); return; }
    }
  }

  return 1;
}

# ==========================================================================

sub handle_physicalbox($$) {
  my ($dbt, $source) = @_;

  # Get Physical Box Data
  my $sth = do_execute($dbt, "
SELECT tag, owner, lifecyclestatus, physicalproduct_id, asset_id, source_system, source_system_element_id, physicalbox_id, detailedlocation_id
  FROM physicalbox
  WHERE source_system like '$source%'") or return;

while (my $ref = $sth->fetchrow_hashref) {

	# Physical Box
	my $AssetTag = $ref->{tag} || "";
	$AssetTag = hw_tag($AssetTag);
#	my $SourceSystemID = $ref->{source_system} || "";
	my $SourceSystemElementID = $ref->{source_system_element_id} || "";
	my $LifeCycleStatus = $ref->{lifecyclestatus} || "";
	my $Owner = $ref->{owner} || "";
	my $physicalproduct_id = $ref->{physicalproduct_id} || "";
	my $asset_id = $ref->{asset_id} || "";
	my $physicalbox_id = $ref->{physicalbox_id} || "";
	my $detailedlocation_id = $ref->{detailedlocation_id} || "";
	my $Billing_ResourceUnit_code = "";
	my $Billing_Change_request_ID = "";
	my $Billing_Change_Category = "";
	my $Billing_Change_Date = "";

	# Asset
        my ($AssetNumber, $Ordernumber, $Orderdate) = get_asset($dbt, $asset_id) or return;

	# Location
	# Get Information & write to file
	if ((length($detailedlocation_id) > 0) && ($detailedlocation_id > 0)) {
          get_detailedlocation($dbt, $AssetTag, $detailedlocation_id) or return;
	}

	# Physical Product
        my ($MemCapacity, $Manufacturer, $Partnumber, $SerialNumber, $Model,
            $vendor_equipment_type, $Physical_Diskspace, $HWType) = get_product($dbt, $AssetTag, $physicalproduct_id) or return;

	# Print Information to output file

        # AssetTag, HWType, MemCapacity, Manufacturer, Partnumber, SerialNumber, Model,
        # vendor equipment type, Physical Diskspace, LifeCycleStatus, Owner, AssetNumber,
        # Ordernumber, Orderdate, Billing ResourceUnit code, Billing Change request ID,
        # Billing Change Category, Billing Change Date, SourceSystemElementID

        unless ($HW->write($AssetTag, $HWType, $MemCapacity, $Manufacturer, $Partnumber,
                           $SerialNumber, $Model, $vendor_equipment_type, $Physical_Diskspace, $LifeCycleStatus,
                           $Owner, $AssetNumber, $Ordernumber, $Orderdate, $Billing_ResourceUnit_code,
                           $Billing_Change_request_ID, $Billing_Change_Category, $Billing_Change_Date,
                           $SourceSystemElementID))
          { ERROR("write HW failed"); return; }
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

$summary_log->info("Create Hardware Extract for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

# Get Source system
my $sourcearr = getsource($dbt, "physicalbox", "source_system");
unless ($sourcearr) {
  ERROR("Found no sources in the physicalbox table !");
  exit_application(1);
}

foreach my $source (@$sourcearr) {

  $summary_log->info("Processing for Source $source");

  # Initialize datafiles for output
  init_outfiles($source) or exit_application(1);

  # Handle Data from ComputerSystem
  handle_physicalbox($dbt, $source) or exit_application(1);

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
