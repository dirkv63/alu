=head1 NAME

a7_solution_relations - Extract Solutions Relations from A7.

=head1 VERSION HISTORY

version 1.1 18 April 2012 DV

=over 4

=item *

Read Server Hostname and Domain Name from relation file, don't try to get it from a7_servers table. The a7_servers table doesn't have the OVSD Servers, while there are some in the relations table.

This works for Hostname from relation in Distant field, but not if OVSD Hostname is in Local field. For Local field we don't have Domain Name.

=back

version 1.0 21 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Solution Relations Information from A7.

Approach is to work in three steps:

First get Solution to Solution Relations. Read Impact Direction to understand relation. If impact direction not available, use alphabetical relation. Get Relation Type to verify if it is known.

Then get Server to Solution Relation. This is always Installed On or Depends On, depending on the Relation Type.

Then get Solution to Server Relation. This should be same handling as previous one. Review if information is available already, or if it is new information. 

=head1 SYNOPSIS

 a7_solution_relations.pl [-t] [-l log_dir] [-c]

 a7_solution_relations -h	Usage
 a7_solution_relations -h 1  Usage and description of the options
 a7_solution_relations -h 2  All documentation

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

my ($logdir, $dbs, $dbt, $source_system, $clear_tables, %rels, %unksrv);
my $printerror = 0;
my $source = "A7";

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

sub get_fqdn($$) {
	my ($dbh, $assettag) = @_;
	my ($fqdn);
	my $query = "SELECT `*_ Hostname / inst`, `* IP domain`
				 FROM a7_servers
				 WHERE `Asset tag` = '$assettag'";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		my $hostname = $ref->{'*_ Hostname / inst'} || "";
		my $domainname = $ref->{'* IP domain'} || "";
		$fqdn = cons_fqdn($hostname, $domainname);
	} else {
		$fqdn = "";
	}
	return $fqdn;
}

=pod

=head2 Create Appl Inst

The Application Instance is found in OVSD. Since it is needed in Assetcenter, copy it over and modify it to appear as an assetcenter Instance.

No need to worry about the Product, this is still in the application table.

=cut

sub create_appl_inst($$$) {
	my ($dbt, $application_instance_tag, $a7_id) = @_;
	my (@fields, @vals);
	# Get record from application_instance_tag table
	my $query = "SELECT *
			     FROM ovsd_application_instance
				 WHERE application_instance_tag = '$application_instance_tag'";
	my $sth = $dbt->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		while (my ($key, $value) = each %$ref) {
			if (not($key eq 'application_instance_id')) {
				if ($key eq 'source_system_element_id') {
					push @fields, $key;
					push @vals, $a7_id;
				} elsif ($key eq 'source_system') {
					push @fields, $key;
					push @vals, $source_system;
				} else {
					push @fields, $key;
					push @vals, $value;
				}
			}
		}
		my $application_instance_id = create_record($dbt, "application_instance", \@fields, \@vals);
	} else {
		error("No record found in ovsd_application_instance for tag $application_instance_tag");
	}
	return;
}

sub handle_srv_sol($$$$) {
	my ($dbt, $fqdn, $application_instance_tag, $relation_type) = @_;
	my ($relation);
	if (($relation_type eq "Backup") ||
		($relation_type eq "Scheduling") ||
		($relation_type eq "Security")) {
		$relation = "has depending solution";
	} else {
		# If Solution is ApplicationInstance, then relation is "has depending solution"
		# otherwise relation is "has installed
		my @fields = ("application_instance_tag");
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		my $instance_category = get_field($dbt, "application_instance", "instance_category", \@fields, \@vals);
		if (length($instance_category) == 0) {
			logging("Instance Category not found for $application_instance_tag");
			return;
		}
		if (lc($instance_category) eq "applicationinstance") {
			$relation = "has depending solution";
		} else {
			$relation = "has installed";
		}
	}
	my $left_type = "ComputerSystem";
	my $left_name = $fqdn;
	my $right_type = "Solution";
	my $right_name = $application_instance_tag;
	my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	my $relations_id = create_record($dbt, "relations", \@fields, \@vals);
	return;
}

=pod

=head2 Get Application Instance Tag

Use the Asset Tag to find the application_instance_tag in Assetcenter. In a number of cases the application instance is from OVSD. In this case the CIID happens to be in the Hostname field for Distant CIs (although only  successful for 3 cases) or in the OVSD ID for Local CIs. This field is used to find a matching Application Instance Tag in the ovsd copy.

If the record is found in OVSD, then copy it to application_instance table and modify source_system_element_id to point to Assetcenter tag.

=cut

sub get_appl_inst_tag($$$) {
	my ($dbt, $a7_id, $ovsd_id) = @_;
	# Try to get Assetcenter Application Instance Tag
	my $source_system_element_id = $a7_id;
	# Get Instance ID for this Installed Product
	my @fields = ("source_system_element_id");
	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	my $application_instance_tag = get_field($dbt, "application_instance", "application_instance_tag", \@fields, \@vals);
	if (length($application_instance_tag) == 0) {
		# Check if this is a known OVSD Application Instance
		$source_system_element_id = $ovsd_id;
		@fields = ("source_system_element_id");
		(@vals) = map { eval ("\$" . $_ ) } @fields;
		$application_instance_tag = get_field($dbt, "ovsd_application_instance", "application_instance_tag", \@fields, \@vals);
		if (length($application_instance_tag) == 0) {
			logging("Application Instance not found for $a7_id ($ovsd_id)");
		} else {
			# Application Instance is found in OVSD, get it here!
			create_appl_inst($dbt, $application_instance_tag, $a7_id);
		}
	}
	return $application_instance_tag;
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
		logging("Could not set $logdir as Log directory, exiting...");
		exit_application(1);
    }
} else {
    $logdir = logdir();
    if (not(defined $logdir)) {
		logging("Could not find default Log directory, exiting...");
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

$source_system = $source . "_" . time;

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

# Check on number of columns
my $columns = 55;
my $rows = 29805;
check_table($dbs, "a7_all_relations", $columns, $rows);

# Clear tables if required
if (defined $clear_tables) {
	my @tables = ("relations");
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

# Initialize WHERE values 
my @initvalues = ("*_ Impact direction", '*_ Relation type');
init2blank($dbs,"a7_all_relations", \@initvalues);

my $msg = "Getting A7 Solution to Solution Relations";
print "$msg\n";
logging($msg);

my ($left_name, $right_name);
my $relation = "depends on";
my $left_type = "Solution";
my $right_type = "Solution";
my $local2distant = 0;
my $distant2local = 0;
my $dirunknown = 0;
my $dupl = 0;
my $query = "SELECT `Asset tag (*_ Distant CI)`, `Asset tag (*_ Local CI)`, 
				    `*_ Hostname / inst (*_ Distant CI)`, `*_ Hostname / inst (*_ Local CI)`
                    `*_ Relation type`, `*_ Impact direction` 
		     FROM `a7_all_relations` 
		     WHERE (`Reason (*_ Distant CI)` is null)
		       AND ((`*_ Status (*_ Distant CI)` = 'In Use') AND
		            (`*_ Status (*_ Local CI)` = 'In Use'))
		       AND ((`*_ CI class (*_ Distant CI)` like 'SOL\_%') AND
		            (`*_ CI class (*_ Local CI)` like 'SOL\_%'))";
my $sth = $dbs->prepare($query);
my $rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
while (my $ref = $sth->fetchrow_hashref) {

	# Get the Distant Application Instance Tag
	my $a7_id = $ref->{'Asset tag (*_ Distant CI)'} || "";
	my $ovsd_id = $ref->{'*_ Hostname / inst (*_ Distant CI)'} || "";
	my $distant_tag = get_appl_inst_tag($dbt, $a7_id, $ovsd_id);
	if (length($distant_tag) == 0) {
		# No application Instance found, skip relation record
		next;
	}
	# Get the Local Application Instance
	$a7_id = $ref->{'Asset tag (*_ Local CI)'} || "";
	$ovsd_id = $ref->{'*_ Hostname / inst (*_ Local CI)'} || "";
	my $local_tag = get_appl_inst_tag($dbt, $a7_id, $ovsd_id);
	if (length($local_tag) == 0) {
		next;
	}
	my $direction = $ref->{'*_ Impact direction'} || "";
	if (($direction eq 'Local impacts Distant')) {
		$left_name = $distant_tag;
		$right_name = $local_tag;
		$local2distant++;
	} elsif ($direction eq 'Local impacted by Distant') {
		$left_name = $local_tag;
		$right_name = $distant_tag;
		$distant2local++;
	} elsif (($direction eq 'Both directions') ||
		     ($direction eq '')) {
		# Unknown dependency, order alphabetically
		if ($local_tag lt $distant_tag) {
			$left_name = $local_tag;
			$right_name = $distant_tag;
		} else {
			$left_name = $distant_tag;
			$right_name = $local_tag;
		}
		$dirunknown++;
	} else {
		error("Unknown impact direction $direction for relation $local_tag to $distant_tag");
		next;
	}

	# Now check if info is known already
	if (exists($rels{lc("$left_name*$right_name")})) {
		$dupl++;
	} else {
		my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		my $relations_id = create_record($dbt, "relations", \@fields, \@vals);
		$rels{lc("$left_name*$right_name")} = 1;
	}
}
$msg = "Distant depends on Local: $local2distant * Local depends on Distant: $distant2local * Unknown or Both (Review!): $dirunknown";
print "$msg\n";
logging($msg);
$msg = "$dupl duplicate records found";
print "$msg\n\n";
logging($msg);

$msg = "Getting A7 Server to Solution Relations";
print "$msg\n";
logging($msg);

undef %rels;
$dupl = 0;
my $new_rels = 0;
my $unksrv_cnt = 0;
# Now get Server to Solution Relations
$query = "SELECT `Asset tag (*_ Distant CI)`, `Asset tag (*_ Local CI)`, 
                 `*_ Relation type`, `*_ Impact direction`, `OVSD ID (*_ Local CI)`,
				 `*_ Hostname / inst (*_ Distant CI)`, `* IP domain (*_ Distant CI)`
		  FROM `a7_all_relations` 
		  WHERE (`Reason (*_ Distant CI)` is null)
		    AND ((`*_ Status (*_ Distant CI)` = 'In Use') AND
		         (`*_ Status (*_ Local CI)` = 'In Use'))
		    AND ((`*_ CI class (*_ Distant CI)` like 'SRV\_%') AND
		         (`*_ CI class (*_ Local CI)` like 'SOL\_%'))
			AND NOT (`*_ Relation type` = 'Monitoring')";
#			AND (`*_ Hostname / inst (*_ Distant CI)` = 'BRSPOSORA01')";
#			AND NOT (`*_ Relation type` like 'OVSD%')";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
while (my $ref = $sth->fetchrow_hashref) {

	my $relation = $ref->{'*_ Relation type'} || "";
	# Get the Local Application Instance Tag
	my $a7_id = $ref->{'Asset tag (*_ Local CI)'} || "";
	my $ovsd_id = $ref->{'OVSD ID (*_ Local CI)'} || "";
	my $application_instance_tag = get_appl_inst_tag($dbt, $a7_id, $ovsd_id);
	if (length($application_instance_tag) == 0) {
		next;
	}
	my $source_system_element_id = $ref->{'Asset tag (*_ Distant CI)'} || "";
	# Get FQDN for this server
	my $hostname = $ref->{'*_ Hostname / inst (*_ Distant CI)'} || "";
	my $domainname = $ref->{'* IP domain (*_ Distant CI)'} || "";
	my $fqdn = cons_fqdn($hostname, $domainname);
	# And check if fqdn is found
	if (length($fqdn) == 0) {
		if (not exists $unksrv{$source_system_element_id}) {
			$unksrv{$source_system_element_id} = 1;
			$unksrv_cnt++;
		}
		next;
	}
	# Now check if info is known already
	if (exists($rels{lc("$fqdn*$application_instance_tag*$relation")})) {
		$dupl++;
		logging("$fqdn*$application_instance_tag*$relation");
	} else {
		handle_srv_sol($dbt, $fqdn, $application_instance_tag, $relation);
		$rels{lc("$fqdn*$application_instance_tag*$relation")} = 1;
		$new_rels++;
	}
}
$msg = "$new_rels new relations, $dupl duplicates, $unksrv_cnt unknown servers";
print "$msg\n";
logging($msg);

$msg = "Getting A7 Solution to Server Relations";
print "$msg\n";
logging($msg);

$dupl = 0;
$new_rels = 0;
$unksrv_cnt = 0;
# Now get Solution to Server Relations
$query = "SELECT `Asset tag (*_ Distant CI)`, `Asset tag (*_ Local CI)`, 
                 `*_ Relation type`, `*_ Impact direction`, `*_ Hostname / inst (*_ Distant CI)`
		  FROM `a7_all_relations` 
		  WHERE (`Reason (*_ Distant CI)` is null)
		    AND ((`*_ Status (*_ Distant CI)` = 'In Use') AND
		         (`*_ Status (*_ Local CI)` = 'In Use'))
		    AND ((`*_ CI class (*_ Distant CI)` like 'SOL\_%') AND
		         (`*_ CI class (*_ Local CI)` like 'SRV\_%'))
			AND NOT (`*_ Relation type` = 'Monitoring')";
#			AND NOT (`*_ Relation type` like 'OVSD%')";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
while (my $ref = $sth->fetchrow_hashref) {

	my $relation = $ref->{'*_ Relation type'} || "";
	# Get the Distant Application Instance Tag
	my $a7_id = $ref->{'Asset tag (*_ Distant CI)'} || "";
	my $ovsd_id = $ref->{'*_ Hostname / inst (*_ Distant CI)'} || "";
	my $application_instance_tag = get_appl_inst_tag($dbt, $a7_id, $ovsd_id);
	if (length($application_instance_tag) == 0) {
		next;
	}
	my $source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
	# Get FQDN for this Server
	my $fqdn = get_fqdn($dbs, $source_system_element_id);
	# And check if fqdn is found
	if (length($fqdn) == 0) {
		if (not exists $unksrv{$source_system_element_id}) {
			$unksrv{$source_system_element_id} = 1;
			$unksrv_cnt++;
		}
		next;
	}
	# Now check if info is known already
	if (exists($rels{lc("$fqdn*$application_instance_tag*$relation")})) {
		$dupl++;
	} else {
		handle_srv_sol($dbt, $fqdn, $application_instance_tag, $relation);
		$rels{lc("$fqdn*$application_instance_tag*$relation")} = 1;
		$new_rels++;
	}
}
$msg = "$new_rels new relations, $dupl duplicates, $unksrv_cnt unknown servers";
print "$msg\n";
logging($msg);

exit_application(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
