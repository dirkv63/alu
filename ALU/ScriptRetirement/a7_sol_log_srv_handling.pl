=head1 NAME

a7_sol_log_srv_handling - This script is  handling modifications and extracts from a freshly imported SOL_LOG_SRV file.

=head1 VERSION HISTORY

version 1.0 06 September 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will handle the freshly imported SOL_LOG_SRV file, modify the column names (Fieldxx) and extract all solutions to a separate table a7_sol_extract.

This script should run first when a new Global_EMEA_SOL_LOG_SRV file is received.

=head1 SYNOPSIS

 a7_sol_log_handling.pl [-t] [-l log_dir] [-c]

 a7_sol_log_handling -h	Usage
 a7_sol_log_handling -h 1  Usage and description of the options
 a7_sol_log_handling -h 2  All documentation

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

$physicalbox_source_id = "A7_".time;

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
my $query = "DROP TABLE IF EXISTS a7_sol_log_srv_work";
my $sth = $dbs->prepare($query);
my $rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Then create work copy of the table
$query = "CREATE TABLE a7_sol_log_srv_work
			 SELECT * FROM a7_sol_log_srv";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Now modify Field Names
# Field4 -> Logical/Virtual 2
$query = "ALTER TABLE  `a7_sol_log_srv_work` CHANGE  `Field4`  `Logical/Virtual Server 2` VARCHAR( 255 ) CHARACTER SET latin1 COLLATE latin1_swedish_ci NULL DEFAULT NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
# Field5 -> Relation Type with the Physical 2
$query = "ALTER TABLE  `a7_sol_log_srv_work` CHANGE  `Field5`  `Relation Type with the Physical 2` VARCHAR( 255 ) CHARACTER SET latin1 COLLATE latin1_swedish_ci NULL DEFAULT NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
# Field45 -> Application Name From ID Portfolio 2
$query = "ALTER TABLE  `a7_sol_log_srv_work` CHANGE  `Field45`  `Application Name From ID Portfolio 2` VARCHAR( 255 ) CHARACTER SET latin1 COLLATE latin1_swedish_ci NULL DEFAULT NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
# Field46 -> Application Description from Portfolio 2
$query = "ALTER TABLE  `a7_sol_log_srv_work` CHANGE  `Field46`  `Application Description from Portfolio 2` VARCHAR( 255 ) CHARACTER SET latin1 COLLATE latin1_swedish_ci NULL DEFAULT NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
# Field47 -> Service Level from ID portfolio 2
$query = "ALTER TABLE  `a7_sol_log_srv_work` CHANGE  `Field47`  `Service Level from Portfolio 2` VARCHAR( 255 ) CHARACTER SET latin1 COLLATE latin1_swedish_ci NULL DEFAULT NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Now extract Solution data
# First dump work table if exists
$query = "DROP TABLE IF EXISTS a7_sol_extract";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Then create TEMP Table with data extract from Solution 1
$query = "CREATE TEMPORARY TABLE a7_sol_extract_work 
		  SELECT DISTINCT `SOL_1 PortFolio ID` as portfolio_id, 
				 `SOL_1 Sourcing Accountable` as sourcing_accountable, 
				 `SOL_1Tier Application Type` as application_tier, 
				 `Application Name From ID Portfolio` as appl_id_acronym, 
				 `Application Description from ID Porfolio` as appl_id_description, 
				 `Service Level from ID portfolio` as service_level, 
				 `SOL_1 Category` as category, 
				 `SOL_1 CI class` as class, 
				 `SOL_1 Full Name` as appl_id_name,
				 `SOL_1 Environment` as environment,
				 `SOL_1 RU Code` as ru_code, 
				 `SOL_1 Support Code` as support_code,
				 `SOL_1 Customer` as customer,
				 `SOL_1 IT contact` as it_contact,
				 `SOL_1 CI Responsible` as ci_responsible,
				 'solution 1' as sol_source
				 FROM `a7_sol_log_srv_work`";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Add data from Solution 2
$query = "INSERT INTO a7_sol_extract_work 
		  SELECT DISTINCT `SOL_2 PortFolio ID` as portfolio_id, 
				 `SOL_2 Sourcing Accountable` as sourcing_accountable, 
				 `SOL_2 Tier Application Type` as application_tier, 
				 `Application Name From ID Portfolio 2` as appl_id_acronym, 
				 `Application Description from Portfolio 2` as appl_id_description, 
				 `Service Level from Portfolio 2` as service_level, 
				 `SOL_2 Category` as category, 
				 `SOL_2 CI class` as class, 
				 `SOL_2 Full Name` as appl_id_name,
				 '' as environment,
				 `SOL_2 RU Code` as ru_code, 
				 `SOL_2 Support code` as support_code,
				 `SOL_2 Customer` as customer,
				 `SOL_2 IT contact` as it_contact,
				 `SOL_2 CI Responsible` as ci_responsible,
				 'solution 2' as sol_source
				 FROM `a7_sol_log_srv_work`
				 WHERE `SOL_2 Category` is not null";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# And create A7 Solution table
$query = "CREATE TABLE a7_sol_extract
		  SELECT DISTINCT *  FROM a7_sol_extract_work";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Remove NULL record in a7_sol_extract
$query = "DELETE FROM a7_sol_extract WHERE appl_id_name is null";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Remove the duplicate for portfolio id 70300
$query = "DELETE FROM a7_sol_extract WHERE appl_id_acronym = 'Local Intranet Switzerland'";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Add index on appl_id_name 
$query = "ALTER TABLE  `a7_sol_extract` ADD INDEX (`appl_id_name`)";
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
