=head1 NAME

ovsd_other_ci_types - This script will extract all other CI types from the Applications CI Relationship File.

=head1 VERSION HISTORY

version 1.0 08 September 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract all 'other' CI types from the Applications CI Relationship file. This CI types are TO-PARENT CATEGORY "Interface", "Logical Entity" and "Software".

TO-PARENT CATEGORY "Application" is in table ovsd_applications. 

TO-PARENT CATEGORY "System" is in table ovsd_servers.

The CI Table will be created in two steps: first select distinct records, then rename all fields by removing TO- from the field.

=head1 SYNOPSIS

 ovsd_other_ci_types.pl [-t] [-l log_dir] [-c]

 ovsd_other_ci_types -h	Usage
 ovsd_other_ci_types -h 1  Usage and description of the options
 ovsd_other_ci_types -h 2  All documentation

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

my ($logdir, $dbs, $dbt, $physicalbox_source_id);
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

sub change_field($$$$) {
	my ($dbh, $table, $c_field, $n_field) = @_;
	my $query = "ALTER TABLE  `ovsd_other_cis` 
				 CHANGE  `$c_field`  `$n_field` VARCHAR( 255 ) 
				 CHARACTER SET latin1 COLLATE latin1_swedish_ci 
				 NULL DEFAULT NULL";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
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
my $query = "DROP TABLE IF EXISTS ovsd_other_cis";
my $sth = $dbs->prepare($query);
my $rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Remove NULL Lines from table
$query = "DELETE FROM ovsd_apps_rels
	      WHERE `FROM-CIID` is NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

my $msg = "Creating table";
print "$msg\n";
logging($msg);

# Then create the table
$query = "CREATE TABLE ovsd_other_cis
		  SELECT distinct 
		  `TO-CIID`, `TO-SEARCH CODE`, `TO-NAME`, `TO-ALIAS NAMES (4000)`, `TO-SERIAL NUMBER`, `TO-CAPITAL ASSET TAG`, `TO-HOST ID`, `TO-DESCRIPTION (4000)`, `TO-PARENT CATEGORY`, `TO-CATEGORY`, `TO-STATUS`, `TO-ENVIRONMENT`, `TO-PURPOSE/FUNCTION`, `TO-FORMER ALCATEL`, `TO-MASTER CMDB`, `TO-ASSET TAG`, `TO-ASSET CENTER CI RESPONSIBLE`, `TO-ASSET CENTER FIXED ASSET NUMBER`, `TO-ASSET CENTER OWNER`, `TO-ASSET CENTER PO`, `TO-ASSET CENTER REFERENCE`, `TO-ASSET CENTER SITE`, `TO-ROUTE EVENT TO`, `TO-MONITORED BY`, `TO-SOX`, `TO-REMEDIATION COMPLETE`, `TO-SOX TIER`, `TO-LAST CMDB  AUDIT DATE`, `TO-OWNER ORGANIZATION SEARCH CODE`, `TO-OWNER PERSON SEARCH CODE`, `TO-OWNER PERSON NAME`, `TO-DOMAIN ANALYST`, `TO-WORKGROUP`, `TO-ADMIN PRIMARY CONTACT SEARCH CODE`, `TO-ADMIN PRIMARY CONTACT NAME`, `TO-ADMIN SECONDARY CONTACT SEARCH CODE`, `TO-ADMIN SECONDARY CONTACT NAME`, `TO-SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE`, `TO-LOCATION DETAILS`, `TO-LOCATION`, `TO-STREET ADDRESS`, `TO-CITY`, `TO-STATE/PROVINCE`, `TO-ZIP CODE/POSTAL`, `TO-COUNTRY`, `TO-REGION`, `TO-NOTES`, `TO-DOC REFERENCE URL`, `TO-BRAND`, `TO-MODEL`, `TO-LEASED`, `TO-IP ADDRESS`, `TO-SECONDARY/VIRTUAL IP ADDRESS (4000)`, `TO-OS CATEGORY`, `TO-OS NAME/VERSION`, `TO-MEMORY SIZE`, `TO-CPU MODEL AND SPEED`, `TO-NO OF CPUs INSTALLED`, `TO-NO OF DISKS X DISK SIZE`, `TO-USABLE DISK SPACE`, `TO-TAPE DRIVES PORTS`, `TO-REMOTE ACCESS`, `TO-TIME ZONE`, `TO-MAINTENANCE WINDOW`, `TO-MISC INFO`, `TO-BACKUP SOFTWARE`, `TO-BACKUP STORAGE`, `TO-BACKUP RETENTION`, `TO-BACKUP MODE`, `TO-BACKUP SCHEDULE`, `TO-BACKUP RESTARTABLE`, `TO-BACKUP SERVER`, `TO-BACKUP MEDIA SERVER`, `TO-BACKUP INFORMATION`, `TO-BACKUP RESTORE PROCEDURES`, `TO-DISASTER RECOVERY TIER`, `TO-MAINTENANCE CONTRACT`, `TO-COVERAGE END DATE`, `TO-GHD SUPPORT DETAILS`, `TO-BOOK CLOSE IMPACTING`, `TO-BUSINESS STAKEHOLDER NAME`, `TO-BUSINESS STAKEHOLDER ORGANIZATION`, `TO-OPS LEAD`, `TO-REGISTRATION CREATED DATE`, `TO-RESOURCE UNIT` 
		  FROM `ovsd_apps_rels`
		  WHERE `TO-PARENT CATEGORY` = 'Interface' 
			 OR `TO-PARENT CATEGORY` = 'Software'
		     OR `TO-PARENT CATEGORY` = 'Logical Entity'";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

$msg = "Renaming Fields";
print "$msg\n";
logging($msg);

# And remove "TO-" from all column names.
$query = "SHOW COLUMNS FROM ovsd_other_cis";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
my $replstring = "TO-";
while (my $ref = $sth->fetchrow_hashref) {
	my $c_field = $ref->{Field};
	if (index($c_field,$replstring) > -1) {
		my $n_field = substr($c_field, length($replstring));
		change_field($dbs, "ovsd_other_cis", $c_field, $n_field);
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
