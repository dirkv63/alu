=head1 NAME

cs_rels_from_a7_Alias - This script manages the Aliases that are mainly used for incident routing in Asset Center.

=head1 VERSION HISTORY

version 1.0.25 August 2012 FM

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script manages Aliases by:
- Creating a relation between the ComputerSystem and the Alias.
- Removing the Alias for the ComputerSystem table.

=head1 SYNOPSIS

 cs_rels_from_a7_Alias.pl [-t] [-l log_dir] [-c]

 cs_rels_from_a7_Alias.pl -h    Usage
 cs_rels_from_a7_Alias.pl -h 1  Usage and description of the options
 cs_rels_from_a7_Alias.pl -h 2  All documentation

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
use DbUtil qw(db_connect do_stmt do_execute get_recordid get_field create_record);
use ALU_Util qw(exit_application val_available);

#############
# subroutines
#############

# ==========================================================================

# Retrieve the physical server to have a relation with the Alias.
# Server for alias is the server that has the same IP as the Alias CI.
# Return an empty string if no CI is found for the Alias.
sub get_Windows_Server_For_Alias ($$$) {
        my ($dbs, $hostname,$ip_address) = @_;
        my ($asset_tag);

        my $sth = do_execute($dbs, "
SELECT DISTINCT `Asset tag`
  FROM a7_servers
  WHERE `Asset tag` <> '$hostname'
    AND `* Logical CI Type` IN ('WINTEL Cluster', 'CLUSTER PACKAGE')
    AND `* IP address` = '$ip_address'") or return;

        if (my $ref = $sth->fetchrow_hashref) {
                $asset_tag = $ref->{'Asset tag'} || ""
        } else {
                $asset_tag = "";
        }
        return $asset_tag;
}

# ==========================================================================

# Retrieve the physical server to have a relation with the Alias.
# Return empty string if no relation is found.
sub get_Unix_Server_For_Alias ($$) {
        my ($dbs, $hostname) = @_;
        my ($asset_tag);

        my $sth = do_execute($dbs, "
SELECT DISTINCT `Asset tag (*_ Distant CI)`
  FROM a7_all_relations
  WHERE `Asset tag (*_ Local CI)` = '$hostname'
    AND `* Logical CI type (*_ Distant CI)` IS NULL
    AND `*_ Relation type` = 'Logical Server'") or return;

        if (my $ref = $sth->fetchrow_hashref) {
                $asset_tag = $ref->{'Asset tag (*_ Distant CI)'} || ""
        } else {

                my $sth = do_execute($dbs, "
SELECT DISTINCT `Asset tag (*_ Local CI)`
  FROM a7_all_relations, a7_servers
  WHERE `Asset tag (*_ Distant CI)` = '$hostname'
    AND `Asset tag (*_ Local CI)` = `Asset tag`
    AND `* Logical CI type` IS NULL
    AND `*_ Relation type` = 'Logical Server'") or return;

                if (my $ref = $sth->fetchrow_hashref) {
                        $asset_tag = $ref->{'Asset tag (*_ Local CI)'} || ""
                } else {
                        $asset_tag = "";
                }
        }

        return $asset_tag;
}

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

my $computersystem_source_id = "A7_".time;

# Initialize source system
my $source_system = $computersystem_source_id;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

=pod

=head2 Alias management

Aliases apply to both Unix and Windows operating systems.
Unix alias are used to represent logical CI that are running on servers. Those CIs are used by the monitoring solution to route incident directly to the delivery team  supporting that CI.
Windows aliases are additional DNS entries that have the same IP as some Windows cluster packages.


=over 4

=item *

Unix Alias have a Logical CI Type = Logical Server. The Oper System is not Unix Cluster.

=item *

Unix Aliases have a Logical Server relation to the physical server on which they are running.

=item *

Windows Aliases have a Logical CI Type = Logical Server and a Oper System different from WINTEL Cluster and CLUSTER PACKAGE.

=item *

Windows Aliases do not have specific relations that would allow to identify the package. They are then hardcoded.

=back

=cut

$summary_log->info("Managing Aliases relations");

# Initialize types
my $left_type = "ComputerSystem";
my $right_type = "ComputerSystem";

# Initialize relation
my $relation = "is Alias For";

# Define Logical CI Types to reduce typing errors.
my $null_type = "";
my $logical_type = "Logical Server";
my $virtual_type = "Virtual Server";

# Manage Unix and Wintel Cluster relations to cluster node.

# Select All "Unix Cluster" and "WINTEL Cluster" Logical Server CIs that are involved in a relation with a physical server whereas the Unix Cluster is the Distant CI and the cluster node the local CI.

my $sth = do_execute($dbt, "
SELECT computersystem_id, source_system_element_id, fqdn
  FROM computersystem
  WHERE computersystem_source like 'A7%'
    AND host_type = 'Alias'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
        # Declare variable for the relation table
        my ($relations_id, $distant_name, $local_name, $left_name, $right_name);
        my ($CI_CLASS);

        $right_name = "";
        $left_name = "";
        my $source_system_element_id = $ref->{'source_system_element_id'} || "";
        my $computer_system_id = $ref->{'computersystem_id'} || "";

        # Get FQDN for local computersystem.
        $left_name = $ref->{'fqdn'} || "";
        if ($left_name eq "") {
                # Only add relations for systems known in A7
                $data_log->info("Could not find FQDN for Assettag $source_system_element_id (local)");
                next;
        }
        # Get the CI Class for the Alias

        my @fields = ("Asset tag");
        my (@vals)=($source_system_element_id);
        if ( val_available(\@vals) eq "Yes") {
                defined ($CI_CLASS = get_field($dbs, "a7_servers", "*_ CI Class", \@fields, \@vals)) or exit_application(2);
        }
        if ((not defined ($CI_CLASS)) || (length($CI_CLASS) == 0)) {
                next;
        }


        if ( ($CI_CLASS =~/SRV_WINTEL/i)) {

                # Getting the Alias (ComputerSystem with the same IP)
                # Retrieve IP Address
                my $IP_ADDR;
                 @fields = ("Asset tag");
                (@vals)=($source_system_element_id);
                if ( val_available(\@vals) eq "Yes") {
                        defined ($IP_ADDR = get_field($dbs, "a7_servers", "* IP address", \@fields, \@vals)) or exit_application(2);
                }
                defined ($source_system_element_id = get_Windows_Server_For_Alias ($dbs, $source_system_element_id,$IP_ADDR)) or exit_application(2);
                @fields = ("source_system_element_id");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                if ( val_available(\@vals) eq "Yes") {
                        defined ($right_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals)) or exit_application(2);
                        if ($right_name eq "") {
                                # Only add relations for systems known in A7
                                $data_log->info("Could not find FQDN for Assettag $source_system_element_id (distant)");
                                next;
                        } else {
                                # Insert the relation into the relation table if doesn't already exist.
                                @fields = ("source_system","left_type", "left_name", "relation", "right_name", "right_type");
                                (@vals) = map { eval ("\$" . $_ ) } @fields;
                                if ( val_available(\@vals) eq "Yes") {
                                        defined ($relations_id = get_recordid($dbt, "relations", \@fields, \@vals)) or exit_application(2);
                                        if (length($relations_id) == 0) {
                                                $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
                                        }
                                }
                        }
                }
        } elsif ( ($CI_CLASS =~/SRV_LINUX/i) or ($CI_CLASS =~/SRV_UNIX/i) ) {
                # Getting the physical related CI for the Alias.
                defined ($source_system_element_id = get_Unix_Server_For_Alias ($dbs, $source_system_element_id)) or exit_application(2);
                @fields = ("source_system_element_id");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                if ( val_available(\@vals) eq "Yes") {
                        defined ($right_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals)) or exit_application(2);
                        if ($right_name eq "") {
                                # Only add relations for systems known in A7
                                $data_log->info("Could not find FQDN for Assettag $source_system_element_id (distant)");
                                next;
                        } else {
                                # Insert the relation into the relation table if doesn't already exist.
                                @fields = ("source_system","left_type", "left_name", "relation", "right_name", "right_type");
                                (@vals) = map { eval ("\$" . $_ ) } @fields;
                                if ( val_available(\@vals) eq "Yes") {
                                        defined ($relations_id = get_recordid($dbt, "relations", \@fields, \@vals)) or exit_application(2);
                                        if (length($relations_id) == 0) {
                                                $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
                                        }
                                }
                        }
                }
        } else {
                # The Alias isn't recognized.
        }

}

# Delete the ComputerSystem that is an Alias.
do_stmt($dbt, "DELETE FROM computersystem WHERE host_type = 'Alias'") or exit_application(2);

$dbs->disconnect;
$dbt->disconnect;
$summary_log->info("Exit `$scriptname' application with success");
exit(0);

=head1 To Do

=over 4

=item *

Nothing for now.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>fabrizio.mancuso@hp.comE<gt>
