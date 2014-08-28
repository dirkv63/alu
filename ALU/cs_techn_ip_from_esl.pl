=head1 NAME

cs_techn_ip_from_esl - This script will extract the ComputerSystem Technical General Information from ESL.

=head1 VERSION HISTORY

version 1.0 09 August 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the ComputerSystem Technical General Information from ESL. This script needs to run first for ESL ComputerSystem.

=head1 SYNOPSIS

 cs_techn_ip_from_esl.pl [-t] [-l log_dir] [-c]

 cs_techn_ip_from_esl.pl -h    Usage
 cs_techn_ip_from_esl.pl -h 1  Usage and description of the options
 cs_techn_ip_from_esl.pl -h 2  All documentation

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
use DbUtil qw(db_connect do_stmt do_execute get_recordid);
use ALU_Util qw(exit_application val_available add_ip);

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

# Make database connection for source & target database
my $dbs = db_connect("alu_cmdb") or exit_application(2);
my $dbt = db_connect("cim") or exit_application(2);

=pod

=head2 ComputerSystem Selection Criteria from AssetCenter

Status: In Use - Only active Hardware boxes are important for Configuration Management.

Master: NULL or AssetCenter included, so ESL and OVSD are excluded.

To exclude Logical / Virtual Servers, information from 'Model' field and from 'Logical CI Type' is used.
Model: All records, except 'Logical / Virtual Servers. 'Logical CI Type': all NULL records, so exclude Logical and Virtual Servers.

=cut

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("ip_connectivity", "ip_attributes") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

my $sth = do_execute($dbs, "
SELECT `Full Nodename`, `IP Type`, `Alias/IP Name`, `IP Address`, `IP last detected on`, `Subnet Name`, `Subnet Mask`,
       `LAN Speed`, `Duplex Mode`, `MAC Address`, `Switch Name`, `Port`, `IP Notes`, `Reachable from HP Mgmt LAN`, `System ID`
  FROM esl_cs_techn_ip
  WHERE NOT ( (`IP Type` IS NULL)
             OR (`IP Type` = 'CI ID')
             OR (`IP Type` = 'CI Searchcode')
             OR (`IP Type` = 'Asset Tag')
             OR (`IP Type` = 'auto detected - change'))") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # Find ComputerSystem ID
        my $source_system_element_id = $ref->{"System ID"} || "";
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $computersystem_id;
        defined ($computersystem_id = get_recordid($dbt, "computersystem", \@fields, \@vals)) or exit_application(2);
        if (length($computersystem_id) == 0) {
                # Computersystem ID not found, so ignore this record.
                next;
        }
        # Get FQDN as tag name
        my $fqdn = $ref->{"Full Nodename"} || '';

        # IP Connectivity
        my $ip_connectivity_id = "";
        my $ip_type = $ref->{"IP Type"} || "";
        # Check if IP Type is defined
        if (not(length($ip_type) >0)) {
                $data_log->error("IP Type not defined for $fqdn, please review!");
                next;
        }

        # Now handle all IP Attributes
        # IP Name
        my $value = $ref->{"Alias/IP Name"} || "";
        if (length($value) > 0) {
                $ip_connectivity_id = add_ip($dbt, $computersystem_id, $ip_type, $ip_connectivity_id, "IP Name", $value);
        }
        # IP Address
        $value = $ref->{"IP Address"} || "";
        if (length($value) > 0) {
                $ip_connectivity_id = add_ip($dbt, $computersystem_id, $ip_type, $ip_connectivity_id, "IP Address", $value);
        }
        # Subnet Name
        $value = $ref->{"Subnet Name"} || "";
        if (length($value) > 0) {
                $ip_connectivity_id = add_ip($dbt, $computersystem_id, $ip_type, $ip_connectivity_id, "Subnet Name", $value);
        }
        # Subnet Mask
        $value = $ref->{"Subnet Mask"} || "";
        if (length($value) > 0) {
                $ip_connectivity_id = add_ip($dbt, $computersystem_id, $ip_type, $ip_connectivity_id, "Subnet Mask", $value);
        }
        # LAN Speed
        $value = $ref->{"LAN Speed"} || "";
        if (length($value) > 0) {
                $ip_connectivity_id = add_ip($dbt, $computersystem_id, $ip_type, $ip_connectivity_id, "LAN Speed", $value);
        }
        # Duplex Mode
        $value = $ref->{"Duplex Mode"} || "";
        if (length($value) > 0) {
                $ip_connectivity_id = add_ip($dbt, $computersystem_id, $ip_type, $ip_connectivity_id, "Duplex Mode", $value);
        }
        # MAC Address
        $value = $ref->{"MAC Address"} || "";
        if (length($value) > 0) {
                $ip_connectivity_id = add_ip($dbt, $computersystem_id, $ip_type, $ip_connectivity_id, "MAC Address", $value);
        }
        # Switch Name
        $value = $ref->{"Switch Name"} || "";
        if (length($value) > 0) {
                $ip_connectivity_id = add_ip($dbt, $computersystem_id, $ip_type, $ip_connectivity_id, "Switch Name", $value);
        }
        # Port
        $value = $ref->{"Port"} || "";
        if (length($value) > 0) {
                $ip_connectivity_id = add_ip($dbt, $computersystem_id, $ip_type, $ip_connectivity_id, "Port", $value);
        }
        # IP Notes
        $value = $ref->{"IP Notes"} || "";
        if (length($value) > 0) {
                $ip_connectivity_id = add_ip($dbt, $computersystem_id, $ip_type, $ip_connectivity_id, "IP Notes", $value);
        }
        # Reachable from HP Mgmt LAN
        $value = $ref->{"Reachable from HP Mgmt LAN"} || "";
        if (length($value) > 0) {
                $ip_connectivity_id = add_ip($dbt, $computersystem_id, $ip_type, $ip_connectivity_id, "Reachable from HP Mgmt LAN", $value);
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
