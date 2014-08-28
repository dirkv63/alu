=head1 NAME

cs_rels_from_a7_Clustering - This script manages the cluster relationships between cluster nodes, cluster packages and cluster

=head1 VERSION HISTORY

version 1.0.25 August 2012 FM

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script extracts build the relations between CIs that are involved in a HA cluster architecture. The manage relations are:
- Cluster to Cluster Node relations
- Cluster to Cluster Package relation.

=head1 SYNOPSIS

 cs_rels_from_a7_Clustering.pl [-t] [-l log_dir] [-c]

 cs_rels_from_a7_Clustering.pl -h    Usage
 cs_rels_from_a7_Clustering.pl -h 1  Usage and description of the options
 cs_rels_from_a7_Clustering.pl -h 2  All documentation

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
use ALU_Util qw(exit_application update_record val_available);

#############
# subroutines
#############

# ==========================================================================

sub set_cluster_info($$$$) {
        my ($dbt, $source_system_element_id, $cluster_architecture, $cluster_technology) = @_;
        # Get Computersystem ID
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $computersystem_id;
        defined ($computersystem_id = get_recordid($dbt, "computersystem", \@fields, \@vals)) or return;
        if ($computersystem_id ne "") {
                # Computersystem must exist in Assetcenter extract,
                # otherwise ignore value
                # Now check if Virtual CI Record already exist.
                # Modify virtual_role if it exist.
                # Create record, set virtual_role if it does not exist.
                @fields = ("computersystem_id");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                my $cluster_id;
                defined ($cluster_id = get_field($dbt, "computersystem", "cluster_id", \@fields, \@vals)) or return;
                if (length($cluster_id) > 0) {
                        # Update record
                        @fields = ("cluster_id", "cluster_architecture","cluster_technology");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        update_record($dbt, "cluster", \@fields, \@vals);
                } else {
                        # Create record
                        @fields = ("cluster_architecture","cluster_technology");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        $cluster_id = create_record($dbt, "cluster", \@fields, \@vals) or return;
                        # Update Virtual_id for computersystem
                        @fields = ("computersystem_id", "cluster_id");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        update_record($dbt, "computersystem", \@fields, \@vals);
                }
        }

        return 1;
}


sub set_cluster_type($$$) {
        my ($dbt, $source_system_element_id, $cluster_type) = @_;
        # Get Computersystem ID
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $computersystem_id;
        defined ($computersystem_id = get_recordid($dbt, "computersystem", \@fields, \@vals)) or return;
        if ($computersystem_id ne "") {
                # Computersystem must exist in Dataset extract,
                # otherwise ignore value
                # Now check if Cluster Record already exist.
                # Modify cluster_type if it exist.
                # Create record, set cluster_type if it does not exist.
                @fields = ("computersystem_id");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                my $cluster_id;
                defined ($cluster_id = get_field($dbt, "computersystem", "cluster_id", \@fields, \@vals)) or return;
                if (length($cluster_id) > 0) {
                        # Update record
                        @fields = ("cluster_id", "cluster_type");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        update_record($dbt, "cluster", \@fields, \@vals);
                } else {
                        # Create record
                        @fields = ("cluster_type");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        $cluster_id = create_record($dbt, "cluster", \@fields, \@vals) or return;
                        # Update cluster_id for computersystem
                        @fields = ("computersystem_id", "cluster_id");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        update_record($dbt, "computersystem", \@fields, \@vals);
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

=head2 Cluster Configurations

All clusters and cluster package are represented by Logical Servers in Asset Center.

=head2 Windows Clustering

Windows cluster follow the rules below:

=over 4

=item *

Windows Clusters have a Logical CI Type = Logical Server and Oper System = WINTEL Cluster

=item *

Windows Cluster packages have a Logical CI Type = Logical Server and Oper System = CLUSTER PACKAGE

=item *

Windows Clusters have a Logical Server relation to Cluster Nodes.

=item *

Windows Cluster Package have a Logical Server relation to Clusters. There are no relations between cluster package and cluster nodes.

=back

=head3 Unix Clustering

Unix cluster follow the rules below:

=over 4

=item *

Unix Cluster have a Logical CI Type = Logical Server and Oper System = Unix Cluster

=item *

The notion of Cluster Package doesn't exist for Unix Operating system.

=item *

Unix Cluster have a Logical Server relation to Cluster Node that have a Logical CI Type = NULL

=cut

$summary_log->info("Getting Unix Cluster to Physical server relations");

# Initialize types
my $left_type = "ComputerSystem";
my $right_type = "ComputerSystem";

# Initialize relation
my $relation = "has cluster node";

# Define Logical CI Types to reduce typing errors.
my $null_type = "";
my $logical_type = "Logical Server";
my $virtual_type = "Virtual Server";

# Manage Unix and Wintel Cluster relations to cluster node.

# Select All "Unix Cluster" and "WINTEL Cluster" Logical Server CIs that are involved in a relation with a physical server whereas the Unix Cluster is the Distant CI and the cluster node the local CI.

my $sth = do_execute($dbs, "
SELECT `Asset tag (*_ Distant CI)`, `*_ Hostname / inst (*_ Distant CI)`, `* Logical CI type (*_ Distant CI)`,
       `* Oper System (*_ Distant CI)`, `Asset tag (*_ Local CI)`, `*_ Hostname / inst (*_ Local CI)`,
       `* Oper System`, `* Logical CI type`, `*_ Relation type`, `*_ Impact direction`
  FROM a7_servers, a7_all_relations
  WHERE `* Oper System (*_ Distant CI)` IN ('Unix Cluster', 'WINTEL Cluster')
    AND `*_ Hostname / inst (*_ Local CI)` = `*_ Hostname / inst`
    AND `*_ Relation type` = 'Logical Server'
    AND `* Logical CI type` IS NULL") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
        # Declare variable for the relation table
        my ($relations_id, $distant_name, $local_name, $left_name, $right_name);

        # First get the fqdns for computersystems in the relation

        # Get FQDN for local computersystem.

        my $source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($right_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals)) or exit_application(2);
                if ($right_name eq "") {
                        # Only add relations for systems known in A7
                        $data_log->info("Could not find FQDN for Assettag $source_system_element_id (local)");
                        next;
                }
        }

        # Get fqdn for distant CI.

        $source_system_element_id = $ref->{'Asset tag (*_ Distant CI)'} || '';
        @fields = ("source_system_element_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($left_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals)) or exit_application(2);
                if ($left_name eq "") {
                        # Only add relations for systems known in A7
                        $data_log->info("Could not find FQDN for Assettag $source_system_element_id (distant)");
                        next;
                }
        }

        # Insert the relation into the relation table if doesn't already exist.
        @fields = ("source_system","left_type", "left_name", "relation", "right_name", "right_type");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($relations_id = get_recordid($dbt, "relations", \@fields, \@vals)) or exit_application(2);
                if (length($relations_id) == 0) {
                        $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
                }
        }
        
	# Then add the Right systems as Cluster node
        # Therefore find the id of the computersystem
        my ($computersystem_id);
	$source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
        set_cluster_type($dbt, $source_system_element_id, "Cluster Node") or exit_application(2);


	# Update the HostType to "cluster node" from the computersystem table.
	# Fix for feedback from Data Validation
        @fields = ("source_system_element_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {	
		defined ($computersystem_id = get_recordid($dbt, "computersystem", \@fields, \@vals)) or return;
		if (length($computersystem_id) > 0) {
                        # Update hostype for computersystem
			my $host_type = "PhysicalServer";
			my $cs_type = "cluster node";
                        @fields = ("computersystem_id", "host_type", "cs_type");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        update_record($dbt, "computersystem", \@fields, \@vals);
		}
	}
}

# Select All "Unix Cluster" and "WINTEL Cluster" Logical Server CIs that are involved in a relation with a physical server where the Unix Cluster is the Local CI and the cluster node the Distant CI.

$sth = do_execute($dbs, "
SELECT `Asset tag (*_ Distant CI)`, `*_ Hostname / inst (*_ Distant CI)`, `* Logical CI type (*_ Distant CI)`,
       `* Oper System (*_ Distant CI)`, `Asset tag (*_ Local CI)`, `*_ Hostname / inst (*_ Local CI)`,
       `* Oper System`, `* Logical CI type`, `*_ Relation type`, `*_ Impact direction`
  FROM a7_servers, a7_all_relations
  WHERE `* Oper System` IN ('Unix Cluster','WINTEL Cluster')
    AND `*_ Hostname / inst (*_ Local CI)` = `*_ Hostname / inst`
    AND `*_ Relation type` = 'Logical Server'
    AND `* Logical CI type (*_ Distant CI)` IS NULL") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
        # Declare variable for the relation table
        my ($relations_id, $distant_name, $local_name, $left_name, $right_name);

        # First get the fqdns for computersystems in the relation

        # Get FQDN for local computersystem.

        my $source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($left_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals)) or exit_application(2);
                if ($left_name eq "") {
                        # Only add relations for systems known in A7
                        $data_log->info("Could not find FQDN for Assettag $source_system_element_id (local)");
                        next;
                }
        }

        # Get fqdn for distant CI.

        $source_system_element_id = $ref->{'Asset tag (*_ Distant CI)'} || '';
        @fields = ("source_system_element_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($right_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals)) or exit_application(2);
                if ($right_name eq "") {
                        # Only add relations for systems known in A7
                        $data_log->info("Could not find FQDN for Assettag $source_system_element_id (distant)");
                        next;
                }
        }

        # Insert the relation into the relation table if doesn't already exist.
        @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($relations_id = get_recordid($dbt, "relations", \@fields, \@vals)) or exit_application(2);
                if (length($relations_id) == 0) {
                        $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
                }
        }

        
	# Then add the Right systems as Cluster node
        # Therefore find the id of the computersystem
        my ($computersystem_id);
	$source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
        set_cluster_type($dbt, $source_system_element_id, "Cluster Node") or exit_application(2);

	# Update the HostType to "cluster node" from the computersystem table.
	# Fix for feedback from Data Validation
        @fields = ("source_system_element_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {	
		my $computersystem_id;
		defined ($computersystem_id = get_recordid($dbt, "computersystem", \@fields, \@vals)) or return;
		if (length($computersystem_id) > 0) {
                        # Update hostype for computersystem
			my $host_type = "PhysicalServer";
			my $cs_type = "cluster node";
                        @fields = ("computersystem_id", "host_type","cs_type");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        update_record($dbt, "computersystem", \@fields, \@vals);
		}
	}
}


# Initialize relation
$relation = "Cluster Package On";

# Manage Wintel Cluster Package relations to cluster.
# IMPORTANT NOTE: such relation doesn't apply to Unix clusters.

# Select All "WINTEL Cluster" Logical Server CIs that are involved in a relation with a physical server whereas the Unix Cluster is the Distant CI and the cluster node the local CI.

$sth = do_execute($dbs, "
SELECT `Asset tag (*_ Distant CI)`, `*_ Hostname / inst (*_ Distant CI)`, `* Logical CI type (*_ Distant CI)`,
       `* Oper System (*_ Distant CI)`, `Asset tag (*_ Local CI)`, `*_ Hostname / inst (*_ Local CI)`,
       `* Oper System`, `* Logical CI type`, `*_ Relation type`, `*_ Impact direction`
  FROM a7_servers, a7_all_relations
  WHERE `* Oper System` = 'CLUSTER PACKAGE'
    AND `*_ Hostname / inst (*_ Local CI)` = `*_ Hostname / inst`
    AND `*_ Relation type` = 'Logical Server'
    AND `* Logical CI type (*_ Distant CI)` = 'Logical Server'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
        # Declare variable for the relation table
        my ($relations_id, $distant_name, $local_name, $left_name, $right_name);

        # First get the fqdns for computersystems in the relation

        # Get FQDN for local computersystem.

        my $source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($right_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals)) or exit_application(2);
                if ($right_name eq "") {
                        # Only add relations for systems known in A7
                        $data_log->info("Could not find FQDN for Assettag $source_system_element_id (local)");
                        next;
                }
        }

        # Get fqdn for distant CI.

        $source_system_element_id = $ref->{'Asset tag (*_ Distant CI)'} || '';
        @fields = ("source_system_element_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($left_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals)) or exit_application(2);
                if ($left_name eq "") {
                        # Only add relations for systems known in A7
                        $data_log->info("Could not find FQDN for Assettag $source_system_element_id (distant)");
                        next;
                }
        }

        # Insert the relation into the relation table if doesn't already exist.
        @fields = ("source_system","left_type", "left_name", "relation", "right_name", "right_type");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($relations_id = get_recordid($dbt, "relations", \@fields, \@vals)) or exit_application(2);
                if (length($relations_id) == 0) {
                        $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
                }
        }

        # Then add the Right systems as Cluster Package
        # Therefore find the id of the computersystem
        my ($computersystem_id);
        $source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
        set_cluster_type($dbt, $source_system_element_id, "Cluster Package") or exit_application(2);
        # And remove the virtual_ci_id for the computersystem (if it exists)
        my $virtual_ci_id = "";
	my $host_type = "ClusterPackage";
	my $cs_type = "cluster package";
        @fields = ("source_system_element_id", "host_type", "cs_type", "virtual_ci_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        update_record($dbt, "computersystem", \@fields, \@vals);
}

# Select All "Unix Cluster" and "WINTEL Cluster" Logical Server CIs that are involved in a relation with a physical server where the Unix Cluster is the Local CI and the cluster node the Distant CI.

$sth = do_execute($dbs, "
SELECT `Asset tag (*_ Distant CI)`, `*_ Hostname / inst (*_ Distant CI)`, `* Logical CI type (*_ Distant CI)`,
       `* Oper System (*_ Distant CI)`, `Asset tag (*_ Local CI)`, `*_ Hostname / inst (*_ Local CI)`,
       `* Oper System`, `* Logical CI type`, `*_ Relation type`, `*_ Impact direction`
  FROM a7_servers, a7_all_relations
  WHERE `* Oper System (*_ Distant CI)` = 'WINTEL Cluster'
    AND `*_ Hostname / inst (*_ Local CI)` = `*_ Hostname / inst`
    AND `*_ Relation type` = 'Logical Server'
    AND `* Logical CI type` = 'Logical Server'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
        # Declare variable for the relation table
        my ($relations_id, $distant_name, $local_name, $left_name, $right_name);

        # First get the fqdns for computersystems in the relation

        # Get FQDN for local computersystem.

        my $source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($left_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals)) or exit_application(2);
                if ($left_name eq "") {
                        # Only add relations for systems known in A7
                        $data_log->info("Could not find FQDN for Assettag $source_system_element_id (local)");
                        next;
                }
        }

        # Get fqdn for distant CI.

        $source_system_element_id = $ref->{'Asset tag (*_ Distant CI)'} || '';
        @fields = ("source_system_element_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($right_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals)) or exit_application(2);
                if ($right_name eq "") {
                        # Only add relations for systems known in A7
                        $data_log->info("Could not find FQDN for Assettag $source_system_element_id (distant)");
                        next;
                }
        }

        # Insert the relation into the relation table if doesn't already exist.
        @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($relations_id = get_recordid($dbt, "relations", \@fields, \@vals)) or exit_application(2);
                if (length($relations_id) == 0) {
                        $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
                }
        }
        # Then add the Right systems as Cluster Package
        # Therefore find the id of the computersystem
        my ($computersystem_id);
        $source_system_element_id = $ref->{'Asset tag (*_ Distant CI)'} || '';
        set_cluster_type($dbt, $source_system_element_id, "Cluster Package") or exit_application(2);
        # And remove the virtual_ci_id for the computersystem (if it exists)
        my $virtual_ci_id = "";
	my $host_type = "ClusterPackage";
	my $cs_type = "cluster package";
        @fields = ("source_system_element_id", "host_type", "cs_type", "virtual_ci_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        update_record($dbt, "computersystem", \@fields, \@vals);

}

$dbs->disconnect;
$dbt->disconnect;
$summary_log->info("Exit `$scriptname' application with success");
exit(0);

=back

=head1 To Do

=over 4

=item *

Nothing for now.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>fabrizio.mancuso@hp.comE<gt>
