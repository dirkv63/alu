=head1 NAME

hw_from_a7 - This script will extract the Hardware Information from Assetcenter.

=head1 VERSION HISTORY

version 1.0 28 July 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Hardware information from Assetcenter.

=head1 SYNOPSIS

 hw_from_a7.pl [-t] [-l log_dir] [-c]

 hw_from_a7.pl -h    Usage
 hw_from_a7.pl -h 1  Usage and description of the options
 hw_from_a7.pl -h 2  All documentation

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
use ALU_Util qw(exit_application val_available cons_fqdn);

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
my $source_system_id = "A7_".time;

# Make database connection for source & target database
my $dbs = db_connect("alu_cmdb") or exit_application(2);
my $dbt = db_connect("cim") or exit_application(2);

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("asset", "cpu", "physicalbox", "physicalproduct") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

=pod

=head2 Hardware Selection Criteria from AssetCenter

Documentation from CI Sync.

Status: In Use OR Awaiting Delivery, with a blank (stock) reason: Only active Hardware boxes are important for Configuration Management.

Status: In Stock, then (stock) reason needs to be 'Delivered' or 'FMO Transition'.

Master: NULL or AssetCenter included, so ESL and OVSD are excluded.

To exclude Logical / Virtual Servers, information from 'Model' field and from 'Logical CI Type' is used.
Model: All records, except 'Logical / Virtual Servers. 'Logical CI Type': all NULL records, so exclude Logical and Virtual Servers.

=cut

my $sth = do_execute($dbs, "
SELECT `* Fixed asset #`, `*_ Serial #`, `*_ Brand`, `* Model (*_ Product)`, `* CPU type`, `* CPU speed`, `* Number of CPUs`, `* Memory`,
       `Asset tag`, `*_ Hostname / inst`, `* IP domain`, `Country (* Location)`, `City (* Location)`, `Full name (* Location)`,
       `*Region (* Location)`, `* Owner`, `*_ Status`, `* CI Ownership`
  FROM a7_servers
  WHERE ((`*_ Status` = 'In Use')
         OR ((`*_ Status` = 'Awaiting Delivery') AND (`Reason` = ''))
         OR ((`*_ Status` = 'In Stock')
             AND ((`Reason` = 'DELIVERED') OR (`Reason` = 'FMO TRANSITION'))))
    AND NOT `* Master flag` <=> 'ESL'
    AND NOT `* Master flag` <=> 'OVSD'
    AND NOT ((`* Model (*_ Product)` <=> 'LOGICAL-VIRTUAL SERVER')
             OR (`*_ Brand` <=> 'ALCANET')
             OR (NOT (`* Logical CI type` IS NULL)))
    AND NOT (`*_ CI Responsible` LIKE  'ICT-APAC%ASB')
    AND NOT (`*_ Hostname / inst` LIKE 'z-%')") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
        # Physical Box
        my ($physicalbox_id);
        my $source_system_element_id = $ref->{"Asset tag"} || "";
        my $source_system = $source_system_id;
        # Get FQDN as tag name
        my $hostname = $ref->{"*_ Hostname / inst"} || "unknown";
        my $domainname = $ref->{"* IP domain"} || "no.dns.entry.com";
        my $fqdn = cons_fqdn($hostname, $domainname);
        my $tag = lc($fqdn);
        my $owner = $ref->{"* CI Ownership"} || "";
        if (index($owner, 'ALU') > -1) {
                $owner = 'Customer';
        } else {
                $owner = 'HP';
        }
        my $lifecyclestatus = $ref->{"*_ Status"} || "";

        # Get DetailedLocation
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $detailedlocation_id;
        defined ($detailedlocation_id = get_field($dbt, "detailedlocation", "detailedlocation_id", \@fields, \@vals)) or exit_application(2);

        # Asset
        my ($asset_id);
        my $assetnumber = $ref->{"* Fixed asset #"} || "";
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
        my $cputype = $ref->{"* CPU type"} || "";
        my $clockspeed = $ref->{"* CPU speed"} || "";
        my $numberofcpus = $ref->{"* Number of CPUs"} || "";
        # Create CPU
        @fields = ("cputype", "clockspeed", "numberofcpus");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $cpu_id = create_record($dbt, "cpu", \@fields, \@vals) or exit_application(2);
        } else {
                $cpu_id = undef;
        }

        # Physical Product
        my ($physicalproduct_id);
        my $serialnumber = $ref->{"*_ Serial #"} || "";
        my $memcapacity = $ref->{"* Memory"} || "";
        my $manufacturer = $ref->{"*_ Brand"} || "";
        my $model = $ref->{"* Model (*_ Product)"} || "";
        my $hw_type = "Box";
        # Create Physical Product
        @fields = ("serialnumber", "manufacturer", "memcapacity", "cpu_id", "model", "hw_type");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $physicalproduct_id = create_record($dbt, "physicalproduct", \@fields, \@vals) or exit_application(2);
        } else {
                $physicalproduct_id = undef;
        }

        # Create Physical Box
        @fields = ("source_system", "tag", "lifecyclestatus", "physicalproduct_id", "asset_id", "source_system_element_id", "owner", "detailedlocation_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $physicalbox_id = create_record($dbt, "physicalbox", \@fields, \@vals) or exit_application(2);
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

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
