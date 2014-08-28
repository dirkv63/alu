=head1 NAME

computersystem_rels_from_a7 - This script will extract the ComputerSystem Relations from Assetcenter.

=head1 VERSION HISTORY

version 1.0 24 October 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the ComputerSystem relations information from Assetcenter. It will convert the relation file as imported from Assetcenter into a format that is easier to use in processing, from table a7_all_relations to the table a7_all_relations_work.

=head1 SYNOPSIS

 computersystem_rels_from_a7.pl [-t] [-l log_dir] [-c]

 computersystem_rels_from_a7 -h	Usage
 computersystem_rels_from_a7 -h 1  Usage and description of the options
 computersystem_rels_from_a7 -h 2  All documentation

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

# Check on number of columns
my $columns = 55;
my $rows = 18913;
check_table($dbs, "a7_all_relations_work", $columns, $rows);


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

=pod

=head2 ComputerSystem to ComputerSystem Selection Criteria for AssetCenter

Only interested in ComputerSystem to ComputerSystem Relations.

=cut

# Initialize WHERE values 
# my @initvalues = ("* Master flag", "*_ Status", "Reason");
# init2blank($dbs,"a7_servers", \@initvalues);

# First DROP work copy of the table if it exists
my $query = "DROP TABLE IF EXISTS x_a7_srv_rels";
my $sth = $dbs->prepare($query);
my $rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Then create (temp) table limited to server relations in scope.
$query = "CREATE TABLE x_a7_srv_rels
			 SELECT  `Asset tag (*_ Distant CI)` ,  `*_ Hostname / inst (*_ Distant CI)` ,  
			         `Asset tag (*_ Local CI)` ,  `*_ Hostname / inst (*_ Local CI)` ,  
					 `*_ Impact direction` ,  `*_ Relation type` 
			 FROM  `a7_all_relations_work` 
			 WHERE  `*_ CI class (*_ Distant CI)` LIKE  'SRV\_%'
			   AND  `Full name (*_ Local CI*_ Category)` =  '/INFRASTRUCTURE/SERVER/'";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Then add fields for fqdn and logical ci type for Distant and local CI
$query = "ALTER TABLE  `x_a7_srv_rels` ADD  `* IP domain (*_ Distant CI)` VARCHAR( 255 ) NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
$query = "ALTER TABLE  `x_a7_srv_rels` ADD  `* IP domain (*_ Local CI)` VARCHAR( 255 ) NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
$query = "ALTER TABLE  `x_a7_srv_rels` ADD  `* Logical CI type (*_ Local CI)` VARCHAR( 255 ) NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
$query = "ALTER TABLE  `x_a7_srv_rels` ADD  `* Logical CI type (*_ Distant CI)` VARCHAR( 255 ) NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Then remove relations with Distant Server CIs that are not known in the a7_server table
$query = "DELETE FROM x_a7_srv_rels 
		  WHERE `Asset tag (*_ Distant CI)` NOT IN 
			(SELECT `Asset tag` FROM a7_servers)";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
} else {
	my $msg = "$rv rows deleted for relations where distant server CI could not be found.";
	print "$msg\n";
	logging ($msg);
}

# and remove relations with Local Server CIs that are not known in the a7_server table
$query = "DELETE FROM x_a7_srv_rels 
		  WHERE `Asset tag (*_ Local CI)` NOT IN 
			(SELECT `Asset tag` FROM a7_servers)";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
} else {
	my $msg = "$rv rows deleted for relations where local server CI could not be found.";
	print "$msg\n";
	logging ($msg);
}

# Add IP Domain and Logical CI Type for Distant CI
$query = "UPDATE x_a7_srv_rels, a7_servers
		  SET `* IP domain (*_ Distant CI)` = `* IP domain`,
			  `* Logical CI type (*_ Distant CI)` = `* Logical CI type`
		  WHERE `Asset tag (*_ Distant CI)` = `Asset tag`";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Add IP Domain and Logical CI Type for Local CI
$query = "UPDATE x_a7_srv_rels, a7_servers
		  SET `* IP domain (*_ Local CI)` = `* IP domain`,
			  `* Logical CI type (*_ Local CI)` = `* Logical CI type`
		  WHERE `Asset tag (*_ Local CI)` = `Asset tag`";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

exit_application(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
