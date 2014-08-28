=head1 NAME

cs_rels_from_ovsd_servers - Script to extract Server Relations for OVSD.

=head1 VERSION HISTORY

version 1.0 07 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract ComputerSystem to ComputerSystem Relations from OVSD.

=head1 SYNOPSIS

 cs_rels_from_ovsd_servers.pl [-t] [-l log_dir] [-c]

 cs_rels_from_ovsd_servers.pl -h    Usage
 cs_rels_from_ovsd_servers.pl -h 1  Usage and description of the options
 cs_rels_from_ovsd_servers.pl -h 2  All documentation

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
use DbUtil qw(db_connect do_stmt do_execute create_record get_recordid get_field);
use ALU_Util qw(exit_application fqdn_ovsd translate update_record val_available);

#############
# subroutines
#############

# ==========================================================================

=pod

=head2 Set Cluster Type

This script will get a ComputerSystem Source System Element ID. It will set the Cluster Type for the Computersystem by creating a Cluster record if it didn't exist before, or by modifying the existing record.

=cut

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

=pod

=head2 Set Virtualization Role

This script will get a ComputerSystem Source System Element ID. It will set the Virtualization Role for the Computersystem by creating a Virtualization_CI record if it didn't exist before, or by modifying the existing record.

=cut

sub set_virt_role($$$) {
        my ($dbt, $source_system_element_id, $virt_role) = @_;
        # Get Computersystem ID
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $computersystem_id;
        defined ($computersystem_id = get_recordid($dbt, "computersystem", \@fields, \@vals)) or return;
        if ($computersystem_id ne "") {
                # Computersystem must exist in Dataset extract,
                # otherwise ignore value
                # Now check if Cluster Record already exist.
                # Modify virtualization_role if it exist.
                # Create record, set virtualization_role if it does not exist.
                @fields = ("computersystem_id");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                my $virtual_ci_id;
                defined ($virtual_ci_id = get_field($dbt, "computersystem", "virtual_ci_id", \@fields, \@vals)) or return;
                if (length($virtual_ci_id) > 0) {
                        # Update record
                        @fields = ("virtual_ci_id", "virtualization_role");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        update_record($dbt, "virtual_ci", \@fields, \@vals);
                } else {
                        # Create record
                        @fields = ("virtualization_role");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        $virtual_ci_id = create_record($dbt, "virtual_ci", \@fields, \@vals) or return;
                        # Update virtual_ci_id for computersystem
                        @fields = ("computersystem_id", "virtual_ci_id");
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

my $computersystem_source_id = "OVSD_".time;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("relations") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

# Initialize source system
my $source_system = $computersystem_source_id;

$summary_log->info("Getting System Relations");

# Initialize types
my $left_type = "ComputerSystem";
my $right_type = "ComputerSystem";

=pod

=head2 Physical Servers that make Cluster Nodes

Get Physical Servers that are cluster nodes making a cluster. Three pieces of information come from this query:

1. The relation between a cluster and its cluster nodes.
2. Left side component need to be flagged as a cluster. This has been done already, since Search Code and Category are in line. Script Computersystem_from_ovsd has set Cluster.
3. Right side component need to be set as a cluster node. This is information that was not known before.

=cut

# Initialize relation
my $relation = "has cluster node";

my $sth = do_execute($dbs, "
SELECT `FROM-CIID`, `FROM-NAME`, `TO-CIID`, `TO-NAME`
  FROM ovsd_server_rels
  WHERE `FROM-CATEGORY` = 'Cluster'
    AND `TO-CATEGORY` = 'Server'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # First add the relation
        my ($relations_id);
        my $left_name = $ref->{'FROM-NAME'} || '';
        $left_name = fqdn_ovsd($left_name);
        my $right_name = $ref->{'TO-NAME'} || '';
        $right_name = fqdn_ovsd($right_name);
        my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
        }

        # Then add the Right systems as Cluster node
        # Therefore find the id of the computersystem
        my ($computersystem_id);
        my $source_system_element_id = $ref->{'TO-CIID'} || "";
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
			my $host_type = "cluster node";
                        @fields = ("computersystem_id", "host_type");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        update_record($dbt, "computersystem", \@fields, \@vals);
		}
	}
}

=pod

=head2 Cluster Packages on Clusters

Get Cluster Packages on Clusters.

In case of Cluster Package, modify the Cluster Type to Cluster Package. A Virtual Host can be an Alias or it can be a Cluster Package.

=cut

# Initialize relation
$relation = "Cluster Package On";
$sth = do_execute($dbs, "
SELECT `FROM-CIID`, `FROM-NAME`, `TO-CIID`, `TO-NAME`
  FROM ovsd_server_rels
  WHERE `FROM-CATEGORY` = 'Cluster'
    AND `TO-CATEGORY` = 'Virtual Host'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # First add the relation
        my ($relations_id);
        my $left_name = $ref->{'FROM-NAME'} || '';
        $left_name = fqdn_ovsd($left_name);
        my $right_name = $ref->{'TO-NAME'} || '';
        $right_name = fqdn_ovsd($right_name);
        my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
        }

        # Then add the Right systems as Cluster Package
        # Therefore find the id of the computersystem
        my ($computersystem_id);
        my $source_system_element_id = $ref->{'TO-CIID'} || "";
        set_cluster_type($dbt, $source_system_element_id, "Cluster Package") or exit_application(2);
        # And remove the virtual_ci_id for the computersystem (if it exists)
        my $virtual_ci_id = "";
	my $cs_type = "cluster package";
        @fields = ("source_system_element_id", "cs_type", "virtual_ci_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        update_record($dbt, "computersystem", \@fields, \@vals);

}

=pod

=head2 Server to Server Connections

This relation shows the connection between two servers.

=cut
$sth = do_execute($dbs, "
SELECT `FROM-CIID`, `FROM-NAME`, `RELATIONSHIP`, `TO-CIID`, `TO-NAME`
  FROM ovsd_server_rels
  WHERE `FROM-CATEGORY` = 'Server'
    AND `TO-CATEGORY` = 'Server'
    AND ((`RELATIONSHIP` = 'CONNECTED')
         OR (`RELATIONSHIP` = 'Depends On'))") or exit_application(2);
#   AND (`FROM-NAME` < `TO-NAME`)";

while (my $ref = $sth->fetchrow_hashref) {

        # First add the relation
        my ($relations_id);
        my $left_name = $ref->{'FROM-NAME'} || '';
        $left_name = fqdn_ovsd($left_name);
        my $right_name = $ref->{'TO-NAME'} || '';
        $right_name = fqdn_ovsd($right_name);
        my $relation = $ref->{'RELATIONSHIP'} || '';
        if ($relation eq 'Connected') {
                $relation = "is connected to";
        } else {
                $relation = "depends on";
        }
        my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
        }

}

=pod

=head2 Server and Server Farm Alias

This part will extract Alias information for a Server or a Server Farm.

=cut
$relation = "is Alias For";
$sth = do_execute($dbs, "
SELECT `FROM-CIID`, `FROM-NAME`, `TO-CIID`, `TO-NAME`
  FROM ovsd_server_rels
  WHERE `FROM-CATEGORY` = 'Virtual Host'
    AND ((`TO-CATEGORY` = 'Server')
         OR (`TO-CATEGORY` = 'Server Farm'))") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # First add the relation
        my ($relations_id);
        my $left_name = $ref->{'FROM-NAME'} || '';
        $left_name = fqdn_ovsd($left_name);
        my $right_name = $ref->{'TO-NAME'} || '';
        $right_name = fqdn_ovsd($right_name);
        $right_name = translate($dbt, "ovsd_servers", "NAME", $right_name, "SourceVal");
        my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
        }

}

=pod

=head2 Virtual Guest Running on Physical Server

This part will extract Virtual Guests running on a Physical Server. The Physical Server Virtual Type for the physical server need to be set to "Server for Virtual Guest".

=cut

$relation = "is running on server";
my (%sfvgs);
$sth = do_execute($dbs, "
SELECT `FROM-CIID`, `FROM-NAME`, `TO-CIID`, `TO-NAME`
  FROM ovsd_server_rels
  WHERE `FROM-CATEGORY` = 'Server'
    AND `TO-CATEGORY` = 'Virtual Server'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # First add the relation
        my ($relations_id);
        # $!$!$!$ left name and right name are changed, DO NOT COPY
        my $left_name = $ref->{'TO-NAME'} || '';
        $left_name = fqdn_ovsd($left_name);
        my $right_name = $ref->{'FROM-NAME'} || '';
        $right_name = fqdn_ovsd($right_name);
        my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
        }

        # Set Virtualization Role for Physical Server
        if (not(exists $sfvgs{$right_name})) {
                my $source_system_element_id = $ref->{'FROM-CIID'} || '';
                set_virt_role($dbt, $source_system_element_id, "Server for Virtual Guest") or exit_application(2);
                $sfvgs{$right_name} = 1;
        }

}

=pod

=head2 Servers making up Server Farm

This part will get the servers that make up the Server Farm. Physical Servers need to get the "Server for Virtual Guests" virtual type.

=cut

$relation = "is part of farm";
$sth = do_execute($dbs, "
SELECT `FROM-CIID`, `FROM-NAME`, `TO-CIID`, `TO-NAME`
  FROM ovsd_server_rels
  WHERE `FROM-CATEGORY` = 'Server'
    AND `TO-CATEGORY` = 'Server Farm'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # First add the relation
        my ($relations_id);
        my $left_name = $ref->{'FROM-NAME'} || '';
        $left_name = fqdn_ovsd($left_name);
        my $right_name = $ref->{'TO-NAME'} || '';
        $right_name = fqdn_ovsd($right_name);
        $right_name = translate($dbt, "ovsd_servers", "NAME", $right_name, "SourceVal");
        my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
        }

        # Set Virtualization Role for Physical Server
        my $source_system_element_id = $ref->{'FROM-CIID'} || '';
        set_virt_role($dbt, $source_system_element_id, "Server for Virtual Guest") or exit_application(2);

}

=pod

=head2 Virtual Servers running on Server Farm

This part will get the Virtual servers that are running on the Server Farm. No need to set Virtual Server Type, since the this has been read from the Category already.

=cut

$relation = "is running on farm";
$sth = do_execute($dbs, "
SELECT `FROM-CIID`, `FROM-NAME`, `TO-CIID`, `TO-NAME`
  FROM ovsd_server_rels
  WHERE `FROM-CATEGORY` = 'Virtual Server'
    AND `TO-CATEGORY` = 'Server Farm'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # First add the relation
        my ($relations_id);
        my $left_name = $ref->{'FROM-NAME'} || '';
        $left_name = fqdn_ovsd($left_name);
        my $right_name = $ref->{'TO-NAME'} || '';
        $right_name = fqdn_ovsd($right_name);
        $right_name = translate($dbt, "ovsd_servers", "NAME", $right_name, "SourceVal");
        my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
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
