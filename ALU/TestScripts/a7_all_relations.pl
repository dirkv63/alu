=head1 NAME

a7_all_relations - This script will work on ALL Relations File.

=head1 VERSION HISTORY

version 1.1 04 November 2011 DV

=over 4

=item *

Add and populate Logical CI Type for Local CI.

=back

version 1.0 24 October 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will remove from the relations file all CI Classes that are not in scope for data migration. 

Also only relations with "Reason (*_ Distant CI)" NULL are kept. All other relations are about no longer used CIs, so should not be taken into account.

Data will be published in a new relations file a7_all_relations_work.

=head1 SYNOPSIS

 a7_all_relations.pl [-t] [-l log_dir]

 a7_all_relations -h	Usage
 a7_all_relations -h 1  Usage and description of the options
 a7_all_relations -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -c, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
########### 

my ($logdir, $dbs, $dbt, $clear_tables);
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
my $query = "DROP TABLE IF EXISTS a7_all_relations_work";
my $sth = $dbs->prepare($query);
my $rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Then create work physical server - logical server and solutions relations
$query = "CREATE TABLE `a7_all_relations_work` 
		  SELECT * FROM a7_all_relations 
		  WHERE `Reason (*_ Distant CI)` is NULL
		    AND `Field9` is NULL
            AND ((`*_ CI class (*_ Distant CI)` like 'SOL%') OR
			     (`*_ CI class (*_ Distant CI)` like 'SRV%') OR
				 (`*_ CI class (*_ Distant CI)` like 'STO%'))
			AND ((`Full name (*_ Local CI*_ Category)` like '/INFRASTRUCTURE/SERVER%') OR
				 (`Full name (*_ Local CI*_ Category)` like '/INFRASTRUCTURE/STORAGE%') OR
				 (`Full name (*_ Local CI*_ Category)` like '/SOLUTIONS%'))
			AND (`*_ Relation type` not like 'OVSD%')";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

$query = "ALTER TABLE  `a7_all_relations_work` ADD  `* Logical CI type (*_ Local CI)` VARCHAR( 255 ) NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Add Logical CI Type for Local CI
$query = "UPDATE a7_all_relations_work, a7_servers
		  SET `* Logical CI type (*_ Local CI)` = `* Logical CI type`
		  WHERE `Asset tag (*_ Local CI)` = `Asset tag`";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Remove Relations that where one of the Components is not "In Use"
$query = "DELETE FROM a7_all_relations_work
		  WHERE NOT ((`*_ Status (*_ Distant CI)`= 'In Use') AND
		             (`*_ Status (*_ Local CI)`= 'In Use'))";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Add Master Flag (Distant) to a7_all_relations table
$query = "ALTER TABLE  `a7_all_relations` ADD  `* Master flag (*_ Distant CI)` VARCHAR( 255 ) NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Populate Master Flag (Distant) from a7_servers
$query = "UPDATE a7_all_relations, a7_servers
		  SET `* Master flag (*_ Distant CI)` = `* Master flag`
		  WHERE `Asset tag (*_ Local CI)` = `Asset tag`";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Populate Master Flag (Distant) from a7_solutions
$query = "UPDATE a7_all_relations, a7_solutions
		  SET `* Master flag (*_ Distant CI)` = `* Master flag`
		  WHERE `Asset tag (*_ Local CI)` = `Asset tag`";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Populate Master Flag (Distant) from a7_storage
$query = "UPDATE a7_all_relations, a7_storage
		  SET `* Master flag (*_ Distant CI)` = `* Master flag`
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
