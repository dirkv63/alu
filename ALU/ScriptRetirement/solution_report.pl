=head1 NAME

solution_report - This script will get a portfolio ID as input and find all related information. Everywhere :)

=head1 VERSION HISTORY

version 1.0 08 September 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will get a portfolio ID as input and find all related information.

=head1 SYNOPSIS

 solution_report.pl [-t] [-l log_dir] -p portfolio_id

 solution_report -h	Usage
 solution_report -h 1  Usage and description of the options
 solution_report -h 2  All documentation

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

my ($logdir, $dbs, $pfid, %rels);
my $printerror = 0;
my $a7_rel_sol_srv = "HP_ALU_SLM_2011_09_03_RELATION_SOL_SRV_V2.xlsx";
my $a7_glob_rel = "Global_ELEA_Mapping_SOL_LOG to physical SRV_2908.xlsx";

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

sub get_rel_sol_srv($$) {
	my ($dbs, $appl_id_name) = @_;
	# Get relations from a7_rel_sol_srv
	my $query = "SELECT * FROM a7_rel_sol_srv
				 WHERE `*_ Serial # (*_ Local CI)` = '$appl_id_name'";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	while (my $ref = $sth->fetchrow_hashref) {
		my $a7_host = $ref->{"*_ Hostname / inst (*_ Distant CI)"} || "";
		my $master = get_a7_server($dbs, $a7_host);
	}
}

sub get_glob_rel($$);

sub get_glob_rel($$) {
	my ($dbs, $appl_id_name) = @_;
	# Get relations from a7_glob_rel, the relations that have been extracted from GLOBAL_SOL_LOG
	my $query = "SELECT SourceName, Source
				 FROM a7_glob_rel
				 WHERE TargetName = '$appl_id_name'";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	while (my $ref = $sth->fetchrow_hashref) {
		my $sourcename = $ref->{"SourceName"} || "";
		my $source = $ref->{"Source"} || "";
		if ($source eq "Sol1") {
			get_a7_solution($dbs, $sourcename);
			get_glob_rel($dbs, $sourcename);
		} elsif ($source ne "PhysServer") {
			# Logical / Virtual Server connection
			get_a7_server($dbs, $sourcename);
			get_glob_rel($dbs, $sourcename); 
		} else {
			get_a7_server($dbs, $sourcename);
		}
	}
}

sub get_a7_solution($$) {
	my ($dbh, $appl_id_name) = @_;
	my $query = "SELECT * 
				 FROM  `a7_solutions` 
				 WHERE  `*_ Serial #` = '$appl_id_name'";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	my ($master);
	if (my $ref = $sth->fetchrow_hashref) {
		# There should be one record only, since the name is unique
		my $asset_tag = $ref->{"Asset tag"} || "";
		my $application_category_a7 = $ref->{"Prefix (*_ Category)"} || "";
		my $application_class_a7 = $ref->{"*_ CI class"} || "";
		my $ci_responsible = $ref->{"*_ CI Responsible"} || "";
		my $appl_id_acronym = $ref->{"*_ Inventory #"} || "";
		my $appl_id_name = $ref->{"*_ Serial #"} || "";
		my $application_group = $ref->{"*_ Brand"} || "";
		my $runtime_environment = $ref->{"* Model (*_ Product)"} || "";
		my $application_status = $ref->{"*_ Status"} || "";
		my $support_code = $ref->{"*_ Support code"} || "";
		my $sourcing_accountable = $ref->{"Sourcing Accountable"} || "";
		$master = $ref->{"* Master flag"} || "";
		my @fields = ("asset_tag", "application_category_a7", "application_class_a7", "ci_responsible", "appl_id_acronym", "application_group", "runtime_environment", "application_status", "support_code", "sourcing_accountable", "master");
		print "A7 Solution: $appl_id_name\n";
		print "===========\n";
		foreach my $key (@fields) {
			my ($val) =  map { eval ("\$" . $_ ) } $key;
			print "$key: $val\n";
		}
		print "\n";
	} else {
		print "Solution $appl_id_name not found in Solution table a7_solution\n";
		$master = "UNKNOWN";
	}
	return $master;
}

sub get_a7_server($$) {
	my ($dbh, $a7_host) = @_;
	my $query = "SELECT * 
				 FROM  `a7_servers` 
				 WHERE `*_ Hostname / inst` = '$a7_host'";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	my ($master);
	if (my $ref = $sth->fetchrow_hashref) {
		# There should be one record only, since the name is unique
		my $a7_domain =  $ref->{"* IP domain"} || "";
		my $fqdn = $a7_host . "." . $a7_domain;
		my $manufacturer = $ref->{"*_ Brand"} || "";
		my $model = $ref->{"* Model"} || "";
		my $logical_type = $ref->{"* Logical CI type"} || "";
		$master = $ref->{"* Master flag"} || "";
		my @fields = ("fqdn", "logical_type", "manufacturer", "model", "master");
		print "A7 Server: $a7_host\n";
		print "=========\n";
		foreach my $key (@fields) {
			my ($val) =  map { eval ("\$" . $_ ) } $key;
			print "$key: $val\n";
		}
		print "\n";
	} else {
		print "Server $a7_host not found in Server table a7_servers\n";
		$master = "UNKNOWN";
	}
	return $master;
}

sub get_target($$$) {
	my ($service_provider, $parent_category, $category) = @_;
	my $target = "Not Found";
	if (index($service_provider, "RETAINED") > -1) {
		$target = "uCMDB - ALU Retained";
		return $target;
	}
	if ($parent_category eq "Application") {
		if ($category eq "Custom Application") {
			$target = "uCMDB - Business Application";
			return $target;
		} elsif ($category eq "BU Managed Application") {
			$target = "uCMDB - ALU Retained";
			return $target;
		} elsif ($category eq "R+D Application") {
			$target = "ESL - Non-Business Application";
			return $target;
		}
	}
	# Server Parent Category Classes
	if (($parent_category eq "Hardware") ||
		($parent_category eq "Printer")  ||
		($parent_category eq "System Component")) {
		$target = "CI Not Migrated";
		return $target;
	}
	if ($parent_category eq "Storage") {
		$target = "ESL";
		return $target;
	}
	if ($parent_category eq "Logical Entity") {
		if (($category eq "Source Code Control Instance") ||
			($category eq "Work Process Area")) {
			$target = "CI Not Migrated";
			return $target;
		} else {
			$target = "ESL";
			return $target;
		}
	}
	if ($parent_category eq "Interface") {
		if (index($category, "External") > -1) {
			$target = "uCMDB - ALU Retained";
			return $target;
		} else {
			$target = "uCMDB - Business Application";
			return $target;
		}
	}
	if ($parent_category eq "System") {
		if (($category eq "Server") ||
			($category eq "Workstation") ||
			($category eq "Mainframe") ||
			($category eq "Appliance") ||
			($category eq "Blade Chassis")) {
			$target = "ESL";
			return $target;
		} else {
			$target = "CI Not Migrated";
			return $target;
		}
	}
	return $target;
}

sub get_ovsd_apps_rels($$) {
	my ($dbh, $source_system_element_id) = @_;
	my $query = "SELECT *
			     FROM ovsd_apps_rels
				 WHERE `FROM-CIID` = $source_system_element_id";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	while (my $ref = $sth->fetchrow_hashref) {
		my $to_source_system_element_id = $ref->{"TO-CIID"} || "";
		my $to_parent_category = $ref->{"TO-PARENT CATEGORY"} || "";
		my $to_category = $ref->{"TO-CATEGORY"} || "";
		my $relation = $ref->{"RELATIONSHIP"} || "";
		handle_relation($dbh, $source_system_element_id, $to_source_system_element_id, $to_parent_category, $to_category, $relation);
	}
}

sub get_ovsd_db_rels($$) {
	my ($dbh, $source_system_element_id) = @_;
	my $query = "SELECT *
			     FROM ovsd_db_rels
				 WHERE `FROM-CIID` = $source_system_element_id";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	while (my $ref = $sth->fetchrow_hashref) {
		my $to_source_system_element_id = $ref->{"TO-CIID"} || "";
		my $to_parent_category = $ref->{"TO-PARENT CATEGORY"} || ""; # DOES NOT EXIST
		my $to_category = $ref->{"TO-CATEGORY"} || ""; # DOES NOT EXIST
		my $relation = $ref->{"RELATIONSHIP_TYPE"} || "";
		handle_relation($dbh, $source_system_element_id, $to_source_system_element_id, $to_parent_category, $to_category, $relation);
	}
}

sub handle_relation($$$$$$) {
	my ($dbh, $source_id, $target_id, $parent_category, $category, $relation) = @_;
	print "Relation: $relation FROM $source_id TO $target_id\n";
	# Check if the relation exists already,
	# add if it did not exist before.
	if (check_relation($source_id, $target_id, $relation) eq "Exist") {
		print "Relation $source_id - $target_id ($relation) already listed\n\n";
	} else {
		if ($category eq "Database") {
			get_ovsd_db($dbh, $target_id);
			check_relation($source_id, $target_id, $relation);
			# Find how this database is further related to anything
			print "Further investigation Database $target_id\n";
			print "Find related Databases\n\n";
			# get_ovsd_db_rels($dbh, $target_id);
		} elsif ($parent_category eq "Application") {
			get_ovsd_applications($dbh, $target_id);
			check_relation($source_id, $target_id, $relation);
			# And find how this application is further related to anything
			print "Further investigation Application $target_id\n";
			print "Find related Applications\n\n";
			get_ovsd_apps_rels($dbh, $target_id);
			print "Find related Servers\n\n";
			get_ovsd_server_rels($dbh, $target_id);
		} elsif ( ($parent_category eq "System") || 
			     (($parent_category eq "Logical Entity") && ($category ne "Work Process Area"))) {
			get_ovsd_servers($dbh, $target_id);
			check_relation($source_id, $target_id, $relation);
		} elsif (($parent_category eq "Interface") || ($parent_category eq "Software") 
											  	   || ($category eq "Work Process Area")) {
			get_ovsd_other_cis($dbh, $target_id);
			check_relation($source_id, $target_id, $relation);
		} else {
			print "CIID: $target_id Parent Category: $parent_category not known\n";
		}
	}
}

sub get_ovsd_server_rels($$) {
	my ($dbh, $source_system_element_id) = @_;
	my $query = "SELECT *
			     FROM ovsd_server_rels
				 WHERE `TO-CIID` = $source_system_element_id";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	while (my $ref = $sth->fetchrow_hashref) {
		my $from_source_system_element_id = $ref->{"FROM-CIID"} || "";
		my $from_parent_category = $ref->{"FROM-PARENT CATEGORY"} || "";
		my $from_category = $ref->{"FROM-CATEGORY"} || "";
		my $relation = $ref->{"RELATIONSHIP"} || "";
		handle_relation($dbh, $source_system_element_id, $from_source_system_element_id, $from_parent_category, $from_category, $relation);
	}
}



sub get_ovsd_db($$) {
	my ($dbh, $ciid) = @_;
	my $query = "SELECT `NAME`, `DESCRIPTION_4000_`, `CATEGORY`, `STATUS`, 
			            `ENVIRONMENT`, `SOX`, `OUTSOURCED_TO_SC`, `OS_NAME`,
						`OS_VER_REL_SP` 
				 FROM `ovsd_db`
				 WHERE `ID` = $ciid";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		# DB Name can have CR/LF !
		my $appl_id_acronym = trim ($ref->{"NAME"} || "");
		my $appl_id_description = $ref->{"DESCRIPTION_4000_"} || "";
		my $appl_id_category_ovsd = $ref->{"CATEGORY"} || "";
		my $application_status = $ref->{"STATUS"} || "";
		my $runtime_system = $ref->{"ENVIRONMENT"} || "";
		my $sox_system = $ref->{"SOX"} || "";
		my $service_provider = $ref->{"OUTSOURCED_TO_SC"} || "";
		my $product_name = $ref->{"OS_NAME"} || "";
		my $product_version = $ref->{"OS_VER_REL_SP"} || "";
		my $target = "ESL";
		my @fields = ("ciid", "appl_id_description", "appl_id_category_ovsd", "application_status", "runtime_system", "sox_system", "service_provider", "product_name", "product_version", "target");
		print "OVSD Database: $appl_id_acronym\n";
		print "=============\n";
		foreach my $key (@fields) {
			my ($val) =  map { eval ("\$" . $_ ) } $key;
			print "$key: $val\n";
		}
		print "\n";
	} else {
		print "Database $ciid not found in table\n";
	}
	return;
}

sub get_ovsd_applications($$) {
	my ($dbh, $ciid) = @_;
	my $query = "SELECT `NAME`, `ALIAS NAMES (4000)`, `PARENT CATEGORY`,
						`DESCRIPTION 4000`, `CATEGORY`, `STATUS`,
						`ENVIRONMENT`, `MASTER CMDB`, `SOX`,
						`SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE`,
						`SOURCING ACCOUNTABLE`
				 FROM `ovsd_applications`
				 WHERE `CIID` = $ciid";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		my $appl_id_acronym = $ref->{"NAME"} || "";
		my $appl_id_name = $ref->{"ALIAS NAMES (4000)"} || "";
		my $appl_id_description = $ref->{"DESCRIPTION 4000"} || "";
		my $parent_category = $ref->{"PARENT CATEGORY"} || "";
		my $appl_id_category_ovsd = $ref->{"CATEGORY"} || "";
		my $application_status = $ref->{"STATUS"} || "";
		my $runtime_system = $ref->{"ENVIRONMENT"} || "";
		my $sox_system = $ref->{"SOX"} || "";
		my $service_provider = $ref->{"SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE"} || "";
		my $sourcing_accountable = $ref->{"SOURCING ACCOUNTABLE"} || "";
		my $master = $ref->{"MASTER CMDB"} || "";
		my $target = get_target($service_provider, $parent_category, $appl_id_category_ovsd);
		my @fields = ("ciid", "appl_id_name", "appl_id_description", "parent_category", "appl_id_category_ovsd", "application_status", "runtime_system", "sox_system", "service_provider", "sourcing_accountable", "target");
		print "OVSD Application: $appl_id_acronym\n";
		print "================\n";
		foreach my $key (@fields) {
			my ($val) =  map { eval ("\$" . $_ ) } $key;
			print "$key: $val\n";
		}
		print "\n";
	} else {
		print "Application $ciid not found in table\n";
	}
	return;
}

sub get_ovsd_servers($$) {
	my ($dbh, $ciid) = @_;
	my $query = "SELECT `NAME`, `ALIAS_NAMES (4000)`, `PARENT CATEGORY`,
						`DESCRIPTION 4000`, `CATEGORY`, `STATUS`,
						`ENVIRONMENT`, `MASTER_CMDB`, `SOX`,
						`SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE`,
						`OS NAME`, `OS VER/REL/SP`
				 FROM `ovsd_servers`
				 WHERE `CIID` = $ciid";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		my $appl_id_acronym = $ref->{"NAME"} || "";
		my $appl_id_name = $ref->{"ALIAS_NAMES (4000)"} || "";
		my $appl_id_description = $ref->{"DESCRIPTION 4000"} || "";
		my $parent_category = $ref->{"PARENT CATEGORY"} || "";
		my $appl_id_category_ovsd = $ref->{"CATEGORY"} || "";
		my $application_status = $ref->{"STATUS"} || "";
		my $runtime_system = $ref->{"ENVIRONMENT"} || "";
		my $sox_system = $ref->{"SOX"} || "";
		my $service_provider = $ref->{"SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE"} || "";
		my $os_name = $ref->{"OS NAME"} || "";
		my $os_version = $ref->{"OS VER/REL/SP"} || "";
		my $master = $ref->{"MASTER CMDB"} || "";
		my $target = get_target($service_provider, $parent_category, $appl_id_category_ovsd);
		my @fields = ("ciid", "appl_id_name", "appl_id_description", "parent_category", "appl_id_category_ovsd", "application_status", "runtime_system", "sox_system", "service_provider", "os_name", "os_version", "target");
		print "OVSD Server: $appl_id_acronym\n";
		print "===========\n";
		foreach my $key (@fields) {
			my ($val) =  map { eval ("\$" . $_ ) } $key;
			print "$key: $val\n";
		}
		print "\n";
	} else {
		print "Server $ciid not found in table\n";
	}
	return;
}

sub get_ovsd_other_cis($$) {
	my ($dbh, $ciid) = @_;
	my $query = "SELECT `NAME`, `ALIAS NAMES (4000)`, `PARENT CATEGORY`,
						`DESCRIPTION (4000)`, `CATEGORY`, `STATUS`,
						`ENVIRONMENT`, `MASTER CMDB`, `SOX`,
						`SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE`,
						`OS NAME/VERSION`
				 FROM `ovsd_other_cis`
				 WHERE `CIID` = $ciid";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		my $appl_id_acronym = $ref->{"NAME"} || "";
		my $appl_id_name = $ref->{"ALIAS NAMES (4000)"} || "";
		my $appl_id_description = $ref->{"DESCRIPTION (4000)"} || "";
		my $parent_category = $ref->{"PARENT CATEGORY"} || "";
		my $appl_id_category_ovsd = $ref->{"CATEGORY"} || "";
		my $application_status = $ref->{"STATUS"} || "";
		my $runtime_system = $ref->{"ENVIRONMENT"} || "";
		my $sox_system = $ref->{"SOX"} || "";
		my $service_provider = $ref->{"SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE"} || "";
		my $os_name = $ref->{"OS NAME/VERSION"} || "";
		my $master = $ref->{"MASTER CMDB"} || "";
		my $target = get_target($service_provider, $parent_category, $appl_id_category_ovsd);
		my @fields = ("ciid", "appl_id_name", "appl_id_description", "parent_category", "appl_id_category_ovsd", "application_status", "runtime_system", "sox_system", "service_provider", "os_name", "target");
		print "OVSD Other CI: $appl_id_acronym\n";
		print "===========\n";
		foreach my $key (@fields) {
			my ($val) =  map { eval ("\$" . $_ ) } $key;
			print "$key: $val\n";
		}
		print "\n";
	} else {
		print "Server $ciid not found in table\n";
	}
	return;
}

sub check_relation($$$) {
	my ($from_id, $to_id, $relation) = @_;
	my ($rel_id, $rel);
	if ($from_id < $to_id) {
		$rel_id = $from_id . "." . $to_id;
	} else {
		$rel_id = $to_id . "." . $from_id;
	}
	if (defined $rels{$rel_id}) {
		$rel = "Exist";
	} else {
		$rels{$rel_id} = $relation;
		$rel = "New";
	}
	return $rel;
}

######
# Main
######

# Handle input values
my %options;
getopts("tl:h:p:", \%options) or pod2usage(-verbose => 0);
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
if ($options{"p"}) {
	$pfid = $options{"p"};
} else {
	error("Portfolio ID missing, exiting...");
	exit_application(1);
}
# Show input parameters
while (my($key, $value) = each %options) {
    logging("$key: $value");
    trace("$key: $value");
}
# End handle input values

# Make database connection for source database
my $connectionstring = "DBI:mysql:database=$dbsource;host=$server;port=$port";
$dbs = DBI->connect($connectionstring, $username, $password,
		   {'PrintError' => $printerror,    # Set to 1 for debug info
		    'RaiseError' => 0});	    	# Do not die on error
if (not defined $dbs) {
   	error("Could not open $dbsource, exiting...");
   	exit_application(1);
}

print "ASSETCENTER\n";
print "===========\n\n";
# AssetCenter
# Find Portfolio ID in solutions table
my $query = "SELECT `*_ Serial #` , `*_ Hostname / inst`
			 FROM  `a7_solutions` 
			 WHERE  `*_ Hostname / inst` LIKE  '$pfid%'";
my $sth = $dbs->prepare($query);
my $rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
while (my $ref = $sth->fetchrow_hashref) {
	my $appl_id_name = $ref->{"*_ Serial #"} || "";
	my $portfolio_id = $ref->{"*_ Hostname / inst"} || "";
	print "Portfolio ID: $portfolio_id - Application Name: $appl_id_name\n\n";
	my $master = get_a7_solution($dbs, $appl_id_name);
	# if (index($master, "Asset") > -1) {
		print "Looking for Solution $appl_id_name in $a7_rel_sol_srv\n";
		print "====================\n\n";
		get_rel_sol_srv($dbs, $appl_id_name);
		print "Looking for Solution $appl_id_name in $a7_glob_rel\n";
		print "====================\n\n";
		get_glob_rel($dbs, $appl_id_name);
	#}
}

print "OVSD\n";
print "====\n\n";
# OVSD
# Find Portfolio ID in Applications Table
$query = "SELECT CIID, NAME, `SOLUTIONS PORTFOLIO ID`, SEARCHCODE
		  FROM ovsd_applications
		  WHERE `SOLUTIONS PORTFOLIO ID` like '$pfid%'";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
while (my $ref = $sth->fetchrow_hashref) {
	my $source_system_element_id = $ref->{"CIID"} || "";
	my $appl_id_acronym = $ref->{"NAME"} || "";
	my $portfolio_id = $ref->{"SOLUTIONS PORTFOLIO ID"} || "";
	my $searchcode = $ref->{"SEARCHCODE"} || "";
	print "Portfolio ID: $portfolio_id - Application Name: $appl_id_acronym - Searchcode: $searchcode\n\n";
	print "Looking for Application $appl_id_acronym in Application Relation Table\n";
	print "=======================\n\n";
	get_ovsd_applications($dbs, $source_system_element_id);
	get_ovsd_apps_rels($dbs, $source_system_element_id);
	print "Looking for Application $appl_id_acronym in Server Relation Table\n";
	print "=======================\n\n";
	get_ovsd_server_rels($dbs, $source_system_element_id);
}

exit_application(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
