=head1 NAME

a7_sol_log_srv_relations - This script is handling relations from SOL_LOG_SRV file.

=head1 VERSION HISTORY

version 1.1 21 October 2011 DV

=over 4

=item *

Add the relationship type between the different relations.

=back

version 1.0 06 September 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will handle the freshly imported SOL_LOG_SRV file, modify the column names (Fieldxx) and extract all solutions to a separate table a7_sol_extract.

Although this script should no longer be used since the all_relations file is avaialble now, it will be used as a temporary source of relation information until all_relations is fully understood.

=head1 SYNOPSIS

 a7_log_srv_relations.pl [-t] [-l log_dir] [-c]

 a7_log_srv_relations -h	Usage
 a7_log_srv_relations -h 1  Usage and description of the options
 a7_log_srv_relations -h 2  All documentation

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

my ($logdir, $dbs, $dbt, $physicalbox_source_id, $clear_tables);
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

# Make database connection for source database
my $connectionstring = "DBI:mysql:database=$dbsource;host=$server;port=$port";
$dbs = DBI->connect($connectionstring, $username, $password,
		   {'PrintError' => $printerror,    # Set to 1 for debug info
		    'RaiseError' => 0});	    	# Do not die on error
if (not defined $dbs) {
   	error("Could not open $dbsource, exiting...");
   	exit_application(1);
}

# First REMOVE a work copy of the table if it exists
my $query = "DROP TABLE IF EXISTS a7_glob_rel";
my $sth = $dbs->prepare($query);
my $rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Then create work physical server - logical server relations
$query = "CREATE TABLE a7_glob_rel
		  SELECT distinct `Physical server` as SourceName, 
		         'PhysServer'as Source, `Logical/Virtual Server` as TargetName, 
		         'Log/Virt' as Target, 
				 `Relation Type with the Physical Server`as Relation
		  FROM `a7_sol_log_srv_work` 
		  WHERE `Logical/Virtual Server` is not null";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# And Logical / Logical relations
$query = "INSERT INTO a7_glob_rel
		  SELECT distinct `Logical/Virtual Server` as SourceName, 
				 'Log/Virt'as Source, `Logical/Virtual Server 2` as TargetName, 
			     'Log/Virt 2' as Target, 
				 `Relation Type with the Physical 2`as Relation
		  FROM `a7_sol_log_srv_work` 
		  WHERE `Logical/Virtual Server 2` is not null";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Create Solution / Solution relations
$query = "INSERT INTO a7_glob_rel
		  SELECT distinct `SOL_1 Full Name` as SourceName, 
				 'Sol1'as Source, `SOL_2 Full Name` as TargetName, 
			     'Sol2' as Target, 'Dependency'
		  FROM `a7_sol_log_srv_work` 
		  WHERE `SOL_2 Full Name` is not null";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Create Solution / Log/Virt2 relations
$query =  "INSERT INTO a7_glob_rel
		   SELECT DISTINCT  `Logical/Virtual Server 2` AS SourceName,  
			      'Log/Virt 2' AS Source,  `SOL_1 Full Name` AS TargetName,  
				  'Sol1' AS Target, 'Running On'
		   FROM  `a7_sol_log_srv_work` 
		   WHERE  `SOL_1 Full Name` IS NOT NULL 
             AND  `Logical/Virtual Server 2` IS NOT NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Create Solution / Log/Virt relations
$query =  "INSERT INTO a7_glob_rel
		   SELECT DISTINCT  `Logical/Virtual Server` AS SourceName,  
			      'Log/Virt' AS Source,  `SOL_1 Full Name` AS TargetName,  
				  'Sol1' AS Target, 'Running On'
		   FROM  `a7_sol_log_srv_work` 
		   WHERE  `SOL_1 Full Name` IS NOT NULL 
             AND  `Logical/Virtual Server 2` IS NULL
			 AND  `Logical/Virtual Server` IS NOT NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Create Solution / Physical Server relations
$query =  "INSERT INTO a7_glob_rel
		   SELECT DISTINCT  `Physical Server` AS SourceName,  
			      'PhysServer' AS Source,  `SOL_1 Full Name` AS TargetName,  
				  'Sol1' AS Target, 'Running On'
		   FROM  `a7_sol_log_srv_work` 
		   WHERE  `SOL_1 Full Name` IS NOT NULL 
             AND  `Logical/Virtual Server 2` IS NULL
			 AND  `Logical/Virtual Server` IS NULL";
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
