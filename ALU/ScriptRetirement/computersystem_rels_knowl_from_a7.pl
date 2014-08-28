=head1 NAME

computersystem_rels_knowl_from_a7 - This script will extract the ComputerSystem Relations knowledge from Assetcenter.

=head1 VERSION HISTORY

version 1.0 24 October 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the ComputerSystem relations knowledge information from Assetcenter. It will extract the knowledge that is available in the Relations file and feed it into the tables in the CIM database.

=head1 SYNOPSIS

 computersystem_rels_from_a7.pl [-t] [-l log_dir] [-c]

 computersystem_rels_knowl_from_a7 -h	Usage
 computersystem_rels_knowl_from_a7 -h 1  Usage and description of the options
 computersystem_rels_knowl_from_a7 -h 2  All documentation

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

my ($logdir, $dbs, $dbt, $computersystem_source_id, $clear_tables);
my $printerror = 0;

#####
# use
#####

use warnings;			    # show warning messages
use strict 'vars';
use strict 'refs';
use strict 'subs';
use Getopt::Std;		    # Handle input params
use Pod::Usage;			    # Allow Usage information
use DBI();
use Log;
use dbParams_aluCMDB;

################
# Trace Warnings
################

use Carp;
$SIG{__WARN__} = sub { Carp::confess( @_ ) };

#############
# subroutines
#############

sub exit_application($) {
    my ($return_code) = @_;
	if (defined $dbs) {
		$dbs->disconnect;
	}
	if (defined $dbt) {
		$dbt->disconnect;
	}
	logging("Exit application with return code $return_code.\n");
    close_log();
    exit $return_code;
}

sub trim {
    my @out = @_;
    for (@out) {
        s/^\s+//;
        s/\s+$//;
    }
    return wantarray ? @out : $out[0];
}

sub set_cluster_type($$) {
	my ($dbt, $source_system_element_id) = @_;
	# Get Computersystem ID
	my @fields = ("source_system_element_id");
   	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	my $computersystem_id = get_recordid($dbt, "computersystem", \@fields, \@vals);
	if ($computersystem_id ne "") {
		# Computersystem must exist in Assetcenter extract,
		# otherwise ignore value
		# Now check if Cluster Record already exist.
		# Modify cluster_type if it exist.
		# Create record, set cluster_type if it does not exist.
		@fields = ("computersystem_id");
		(@vals) = map { eval ("\$" . $_ ) } @fields;
		my $cluster_id = get_field($dbt, "computersystem", "cluster_id", \@fields, \@vals);
		my $cluster_type = "cluster node";
		if (length($cluster_id) > 0) {
			# Update record
			@fields = ("cluster_id", "cluster_type");
			(@vals) = map { eval ("\$" . $_ ) } @fields;
			update_record($dbt, "cluster", \@fields, \@vals);
		} else {
			# Create record
			@fields = ("cluster_type");
			(@vals) = map { eval ("\$" . $_ ) } @fields;
			$cluster_id = create_record($dbt, "cluster", \@fields, \@vals);
			# Update cluster_id for computersystem
			@fields = ("computersystem_id", "cluster_id");
			(@vals) = map { eval ("\$" . $_ ) } @fields;
			update_record($dbt, "computersystem", \@fields, \@vals);
		}
	}
}

sub set_sfvg($$) {
	my ($dbt, $source_system_element_id) = @_;
	# Get Computersystem ID
	my @fields = ("source_system_element_id");
   	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	my $computersystem_id = get_recordid($dbt, "computersystem", \@fields, \@vals);
	if ($computersystem_id ne "") {
		# Computersystem must exist in Assetcenter extract,
		# otherwise ignore value
		# Now check if Virtual CI Record already exist.
		# Modify virtual_role if it exist.
		# Create record, set virtual_role if it does not exist.
		@fields = ("computersystem_id");
		(@vals) = map { eval ("\$" . $_ ) } @fields;
		my $virtual_ci_id = get_field($dbt, "computersystem", "virtual_ci_id", \@fields, \@vals);
		my $virtualization_role = "Server for Virtual Guest";
		if (length($virtual_ci_id) > 0) {
			# Update record
			@fields = ("virtual_ci_id", "virtualization_role");
			(@vals) = map { eval ("\$" . $_ ) } @fields;
			update_record($dbt, "virtual_ci", \@fields, \@vals);
		} else {
			# Create record
			@fields = ("virtualization_role");
			(@vals) = map { eval ("\$" . $_ ) } @fields;
			$virtual_ci_id = create_record($dbt, "virtual_ci", \@fields, \@vals);
			# Update cluster_id for computersystem
			@fields = ("computersystem_id", "virtual_ci_id");
			(@vals) = map { eval ("\$" . $_ ) } @fields;
			update_record($dbt, "computersystem", \@fields, \@vals);
		}
	}
}

######
# Main
######


# Handle input values
my %options;
getopts("tl:h:c", \%options) or pod2usage(-verbose => 0);
# my $arglength = scalar keys %options;  
# if ($arglength == 0) {			# If no options specified,
#	$options{"h"} = 0;			# display usage.
#}
#Print Usage
if (defined $options{"h"}) {
    if ($options{"h"} == 0) {
        pod2usage(-verbose => 0);
    } elsif ($options{"h"} == 1) {
        pod2usage(-verbose => 1);
    } else {
		pod2usage(-verbose => 2);
	}
}
# Trace required?
if (defined $options{"t"}) {
    Log::trace_flag(1);
    trace("Trace enabled");
}
# Find log file directory
if ($options{"l"}) {
    $logdir = logdir($options{"l"});
    if (not(defined $logdir)) {
		error("Could not set $logdir as Log directory, exiting...");
		exit_application(1);
    }
} else {
    $logdir = logdir();
    if (not(defined $logdir)) {
		error("Could not find default Log directory, exiting...");
		exit_application(1);
    }
}
if (-d $logdir) {
    trace("Logdir: $logdir");
} else {
    pod2usage(-msg     => "Cannot find log directory $logdir",
	      -verbose => 0);
}
# Logdir found, start logging
open_log();
logging("Start application");
# Clear data
if (not defined $options{"c"}) {
	$clear_tables = "Yes";
}
# Show input parameters
while (my($key, $value) = each %options) {
    logging("$key: $value");
    trace("$key: $value");
}
# End handle input values

$computersystem_source_id = "A7_".time;

# Make database connection for source database
my $connectionstring = "DBI:mysql:database=$dbsource;host=$server;port=$port";
$dbs = DBI->connect($connectionstring, $username, $password,
		   {'PrintError' => $printerror,    # Set to 1 for debug info
		    'RaiseError' => 0});	    	# Do not die on error
if (not defined $dbs) {
   	error("Could not open $dbsource, exiting...");
   	exit_application(1);
}

# Make database connection for target database
$connectionstring = "DBI:mysql:database=$dbtarget;host=$server;port=$port";
$dbt = DBI->connect($connectionstring, $username, $password,
		   {'PrintError' => $printerror,    # Set to 1 for debug info
		    'RaiseError' => 0});	    	# Do not die on error
if (not defined $dbs) {
   	error("Could not open $dbsource, exiting...");
   	exit_application(1);
}

# Clear tables if required
if (defined $clear_tables) {
	my @tables = ("cluster", "relations");
	while (@tables) {
		my $table = shift @tables;
		my $query = "truncate $table";
		my $sth = $dbt->prepare($query);
		my $rv = $sth->execute();
		if (defined $rv) {
			logging($query);
		} else {
			error("Could not execute query $query, Error: ".$sth->errstr);
		}
	}
}

=pod

=head2 Cluster Nodes

Get the cluster nodes by checking the 

Get all cluster nodes from a7_all_relations_work
Clusters are represented in Assetcenter by listing all links between 
cluster nodes as 'primary-failover cluster nodes' relation.
Remark that this is relation may contain duplicate information. To be discussed if 
this script should filter the relations info or if the transformation model can 
remove the duplicate information.

The hostname (Distant CI) and (Local CI) are cluster nodes, and need to be indicated as
cluster nodes in the cluster file.

=cut

# Initialize source system
my $source_system = $computersystem_source_id;

my $msg = "Getting Cluster Nodes";
print "$msg\n";
logging ($msg);

# Initialize types
my $left_type = "ComputerSystem";
my $right_type = "ComputerSystem";

# Initialize relation
my $relation = "cluster node";

my $query = "SELECT  `*_ Hostname / inst (*_ Distant CI)` ,  `*_ Hostname / inst (*_ Local CI)`,
					  `Asset tag (*_ Distant CI)`, `Asset tag (*_ Local CI)`
			 FROM  `a7_all_relations_work` 
			 WHERE  `*_ Relation type` =  'Primary-failover cluster nodes'";
my $sth = $dbs->prepare($query);
my $rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
while (my $ref = $sth->fetchrow_hashref) {

	# First add the relation
	my ($relations_id, $distant_name, $local_name, $left_name, $right_name);
	# Get FQDN for left computersystem
	my $source_system_element_id = $ref->{'Asset tag (*_ Distant CI)'} || "";
	my @fields = ("source_system_element_id");
   	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$distant_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals);
		if ($distant_name eq "") {
			error("Could not find FQDN for Assettag $source_system_element_id (left)");
			next;
		}
	}
	# Get FQDN for right computersystem
	$source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
	@fields = ("source_system_element_id");
   	(@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$local_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals);
		if ($local_name eq "") {
			error("Could not find FQDN for Assettag $source_system_element_id (right)");
			next;
		}
	}
	
	# Order relations alphabetically
	if ($distant_name lt $local_name) {
		$left_name = $distant_name;
		$right_name = $local_name;
	} else {
		$right_name = $distant_name;
		$left_name = $local_name;
	}
	@fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
   	(@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$relations_id = create_record($dbt, "relations", \@fields, \@vals);
	}

	# Then add the systems as Cluster nodes
	# Therefore find the id of the computersystem
	my ($computersystem_id);
	# First the Distant CI
	$source_system_element_id = $ref->{'Asset tag (*_ Distant CI)'} || "";
	set_cluster_type($dbt, $source_system_element_id);
	# Then handle the Local Distant CI
	$source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
	set_cluster_type($dbt, $source_system_element_id);

}

=pod

=head2 Virtual Configurations

Virtual Guests are identified by the Logical CI Types, and processed in the computersystem_from_a7.pl.

Virtual Server Relations indicate the relation between a virtual guest and the host server. In a 'Virtual Server' relation, the 'Server for Virtual Guest' is on the other side compared to the 'Virtual Guest', according to 'Logical-virtual Servers in the CMDB' document.

So for Relation Type 'Virtual Server' when checking the Logical CI types for Local and Distant CIs, one would expect exactly one 'Virtual Server', and one Logical Server (in case of a farm) or Physical Server (not sure if this is a single Server for Virtual Guest, or a farm). 

However this is not the case, other Logical CI Type combinations (Virtual Server - Virtual Server and Logical Server - Logical Server) are also displayed.

These cases are listed in A7 Relations:

NULL - NULL: Logical CI Type Virtual Server missing, add relation in no specific order. => no further action.

NULL - Logical Server: SUN Solaris zones on physical server => Add 'Server for Virtual Guest' on Physical Server (Logical CI Type: NULL) (if it is OS type Solaris?)

NULL - Virtual Server: Virtual Guest on Physical Server => Add 'Server for Virtual Guest' on Physical server (Logical CI Type NULL)

Logical Server - Logical Server: Cluster Package on Cluster (not on cluster nodes!) => but unsure how to know who is the cluster and who is the cluster package, no further action

Logical Server - Virtual Server: Virtual Guests on Cluster / Virtual Farm. => but unsure how to handle Logical Server, no further action.

Virtual Server - Virtual Server: One of both should not be this type 'Virtual Server', add relation only. 

The impact direction does not seem to provide additional information, since all combinations are possible.

=cut

$msg = "Getting Virtual Systems";
print "$msg\n";
logging ($msg);

# Initialize types
$left_type = "ComputerSystem";
$right_type = "ComputerSystem";

# Initialize relation
$relation = "Is Virtual Server On";

$query = "SELECT `Asset tag (*_ Distant CI)`, `*_ Hostname / inst (*_ Distant CI)`,
				 `* Logical CI type (*_ Distant CI)`, `Asset tag (*_ Local CI)`, 
				 `*_ Hostname / inst (*_ Local CI)`, `* Logical CI type (*_ Local CI)`
		  FROM `a7_all_relations_work` 
		  WHERE `*_ Relation type` = 'Virtual Server'";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
while (my $ref = $sth->fetchrow_hashref) {

	my ($relations_id, $distant_name, $local_name, $left_name, $right_name);

	# Define Logical CI Types to reduce typing errors.
	my $null_type = "";
	my $logical_type = "Logical Server";
	my $virtual_type = "Virtual Server";
	
	# First get the fqdns for computersystems in the relation
	# Get fqdn for distant CI.
	my $source_system_element_id = $ref->{'Asset tag (*_ Distant CI)'} || '';
	my @fields = ("source_system_element_id");
   	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$distant_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals);
		if ($distant_name eq "") {
			# Only add relations for systems known in A7
			logging("Could not find FQDN for Assettag $source_system_element_id (distant)");
			next;
		}
	}
	# Get FQDN for local computersystem.
	$source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
	@fields = ("source_system_element_id");
   	(@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$local_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals);
		if ($local_name eq "") {
			# Only add relations for systems known in A7
			logging("Could not find FQDN for Assettag $source_system_element_id (local)");
			next;
		}
	}

	# Get Logical CI Type component
	my $distant_logical_ci = $ref->{'* Logical CI type (*_ Distant CI)'} || '';
	my $local_logical_ci = $ref->{'* Logical CI type (*_ Local CI)'} || '';

	# Check all possible cases
	if ((($distant_logical_ci eq $null_type) && ($local_logical_ci eq $null_type)) ||
		(($distant_logical_ci eq $virtual_type) && ($local_logical_ci eq $virtual_type)) ||
		(($distant_logical_ci eq $logical_type) && ($local_logical_ci eq $logical_type))) {
		# Unsure who is virtual guest and who is Server for virtual guest.
		# Alphabetical order for now.
		if ($distant_name lt $local_name) {
			$left_name = $distant_name;
			$right_name = $local_name;
		} else {
			$right_name = $distant_name;
			$left_name = $local_name;
		}
	} elsif ((($distant_logical_ci eq $null_type) && ($local_logical_ci eq $logical_type)) ||
			 (($distant_logical_ci eq $null_type) && ($local_logical_ci eq $virtual_type))) {
		$left_name = $local_name;
		$right_name = $distant_name;
		# Set distant_name to 'Server for Virtual Guest'
		$source_system_element_id = $ref->{'Asset tag (*_ Distant CI)'} || '';
		set_sfvg($dbt, $source_system_element_id);
	} elsif ((($distant_logical_ci eq $logical_type) && ($local_logical_ci eq $null_type)) ||
			 (($distant_logical_ci eq $virtual_type) && ($local_logical_ci eq $null_type))) {
		$left_name = $distant_name;
		$right_name = $local_name;
		# Set local_name to 'Server for Virtual Guest'
		$source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || '';
		set_sfvg($dbt, $source_system_element_id);
	} elsif (($distant_logical_ci eq $logical_type) && ($local_logical_ci eq $virtual_type)) {
		$left_name = $local_name;
		$right_name = $distant_name;
	} elsif (($distant_logical_ci eq $virtual_type) && ($local_logical_ci eq $logical_type)) {
		$left_name = $distant_name;
		$right_name = $local_name;
	} else {
		my $msg = "Unexpected combination of Logical CI Types - distant $distant_logical_ci, local $local_logical_ci for distant host $distant_name and local host $local_name";
		error($msg);
		$left_name = "Invalid";
		$right_name = "Invalid";
	}
	@fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
   	(@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$relations_id = create_record($dbt, "relations", \@fields, \@vals);
	}
}

exit_application(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
