=head1 NAME

hw_from_ovsd - This script will extract the Hardware Information from OVSD dump.

=head1 VERSION HISTORY

version 1.0 04 August 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Hardware information from OVSD dump.

=head1 SYNOPSIS

 hw_from_ovsd.pl [-t] [-l log_dir] [-c]

 hw_from_ovsd.pl -h    Usage
 hw_from_ovsd.pl -h 1  Usage and description of the options
 hw_from_ovsd.pl -h 2  All documentation

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

my $clear_tables;

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
use DbUtil qw(db_connect do_stmt do_execute create_record get_field);
use ALU_Util qw(exit_application remove_cr replace_cr val_available fqdn_ovsd);

#############
# subroutines
#############

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

my $data_log = Log::Log4perl->get_logger('Data');

my $sourcesystem = "OVSD";
my $source_system = $sourcesystem . "_" .time;

# Make database connection for source & target database
my $dbs = db_connect("alu_cmdb") or exit_application(2);
my $dbt = db_connect("cim") or exit_application(2);

# Clear tables in target database for initialization, if flag is set
if (defined $clear_tables) {
  foreach my $table ("asset", "cpu", "physicalbox", "physicalproduct") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

=pod

=head2 Hardware Selection Criteria from ESL

Note that the fields in the WHERE clause should not have NULL values. Replace all NULL values with blanks!

Parent Category: Hardware, Printer, System Component Excluded. - no CIs in scope for transformation (see 'CI Scope and Target.xlsx').

Parent Category: Logical Entity - Always a logical or virtual CI, never a Hardware Box.

Only Parent Category System or Storage included.

Status / Environment: include everything except Status inactive and Environment Decommissioned - see Meeting Minutes Workshop 29.09.2011.

Exclude RFSWORLD Devices - not part of contract.

=cut

# Create Select statement
my $sth = do_execute($dbs, "
SELECT NAME, STATUS, `SERIAL NUMBER`, `CAPITAL ASSET TAG`, LOCATION, BRAND, MODEL, `MEMORY SIZE`,
       `CPU MODEL`, `CPU SPEED (MHZ)`, `SEARCH CODE`, CIID, CATEGORY, `SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE`,
       `NO OF CPUs INSTALLED`
  FROM ovsd_servers
  WHERE (MASTER_CMDB IS NULL OR MASTER_CMDB <=> '' OR MASTER_CMDB <=> 'Mastered in AssetCenter and OVSD')
    AND NOT ((STATUS <=> 'Inactive') AND (ENVIRONMENT <=> 'Decommissioned'))
    AND ((`PARENT CATEGORY` <=> 'Storage') OR (`PARENT CATEGORY` <=> 'System'))
    AND NOT (`SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE` <=> 'ASB-MANAGED')
    AND NOT (`SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE` <=> 'RFS-MANAGED')
    AND NOT (NAME LIKE 'z-%' AND NAME IS NOT NULL)") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # Physical Box
        my ($physicalbox_id);
        my $tag = $ref->{'NAME'} || "";
        $tag = remove_cr($tag);
        $tag = fqdn_ovsd($tag);
        my $lifecyclestatus = $ref->{'STATUS'} || "";
        my $owner = $ref->{"SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE"} || "";
        if (index($owner, "RETAINED") > -1) {
                $owner = "Customer";
        } else {
                $owner = "HP";
        }
#       my $source_system_element_id = $ref->{"SEARCH CODE"} || "";
        my $source_system_element_id = $ref->{"CIID"} || "";

        # Get DetailedLocation
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $detailedlocation_id;
        defined ($detailedlocation_id = get_field($dbt, "detailedlocation", "detailedlocation_id", \@fields, \@vals)) or exit_application(2);
        $detailedlocation_id = undef if ($detailedlocation_id eq '');

        # Asset
        my ($asset_id);
        my $assetnumber = $ref->{'CAPITAL ASSET TAG'} || "";
        # Create Asset
        @fields = ("assetnumber");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $asset_id = create_record($dbt, "asset", \@fields, \@vals) or exit_application(2);
        } else {
                $asset_id = undef;
        }

        # CPU
        my ($cpu_id);
        my $clockspeed = $ref->{'CPU SPEED (MHZ)'} || "";
        my $cputype = $ref->{'CPU MODEL'} || "";
        # WRONG_COL_XXX : COLUMN does not exists, but it is not important, because no of cpu is done by automatic discovery !
        #my $numberofcpus = $ref->{'NO# OF CPUs INSTALLED'} || "";
        my $numberofcpus = $ref->{'NO OF CPUs INSTALLED'} || "";
        # Create CPU
        @fields = ("cputype", "clockspeed", "numberofcpus");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $cpu_id = create_record($dbt, "cpu", \@fields, \@vals) or exit_application(2);
        } else {
                $cpu_id = undef;
        }

        # Physical Product
        my ($physicalproduct_id, $hw_type);
        my $serialnumber = $ref->{'SERIAL NUMBER'} || "";
        my $memcapacity = $ref->{'MEMORY SIZE'} || "";
        my $manufacturer = $ref->{'BRAND'} || "";
        my $vendorequipmenttype = $ref->{"CATEGORY"} || "";
        my $model = $ref->{'MODEL'} || "";
        # Model field can have CR - replace with <br>
        $model = replace_cr($model);
        # Find hw_type
        if ($vendorequipmenttype eq "Blade Chassis") {
                $hw_type = "BladeEnclosure";
        } else {
                $hw_type = "Box";
        }
        # Create Physical Product
        @fields = ("serialnumber", "manufacturer", "memcapacity", "cpu_id", "model", "hw_type", "vendorequipmenttype");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $physicalproduct_id = create_record($dbt, "physicalproduct", \@fields, \@vals);
        } else {
                $physicalproduct_id = "";
        }

        # Create Physical Box
        @fields = ("source_system", "tag", "lifecyclestatus", "source_system_element_id",  "physicalproduct_id", "asset_id", "owner", "detailedlocation_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $physicalbox_id = create_record($dbt, "physicalbox", \@fields, \@vals);
        } else {
                $data_log->error("No physical Box created since no data in record available!");
                next;
        }

}

$dbs->disconnect;
$dbt->disconnect;
$summary_log->info("Exit `$scriptname' application with success");
exit(0);

=head1 To Do

=over 4

=item *

Handle the BU Mgd Devices.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
