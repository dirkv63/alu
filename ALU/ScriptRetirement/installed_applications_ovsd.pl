=head1 NAME

installed_application_ovsd - Get OVSD Installed Application relations

=head1 VERSION HISTORY

version 1.0 13 December 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script is to link installed applications (databases) to the system on which they are installed. 

The goal is to verify that each installed application is on one system only.

=head1 SYNOPSIS

 installed_application_ovsd.pl [-t] [-l log_dir] [-c]

 installed_application_ovsd -h	Usage
 installed_application_ovsd -h 1  Usage and description of the options
 installed_application_ovsd -h 2  All documentation

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

my ($logdir, $dbs, $dbt, $source_system, $clear_tables, %rels);
my $printerror = 0;
my $source = "OVSD";
my $dupl_cnt = 0;
my $rels_cnt = 0;
my $delim = "|";
my $filedir = "d:/temp/alucmdb/";
my $comp_name = "DB";

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
	close DbIssues;
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

sub get_server($$) {
	my ($dbh, $ciid) = @_;
	my ($servername);
	my $query = "SELECT NAME
			     FROM ovsd_servers
				 WHERE CIID = '$ciid'";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		$servername = $ref->{'NAME'} || "";
	} else {
		$servername = "";
	}
	return $servername;
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

# Clear tables if required
if (defined $clear_tables) {
	my @tables = ("installed_application");
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
my @initvalues = ();
init2blank($dbs,"a7_all_relations", \@initvalues);

# Issue File
my $filename = $filedir . $source . "_" . $comp_name . ".csv";
my $openres = open(DbIssues, ">$filename");
if (not defined $openres) {
	error("Could not open file $filename for writing, exiting...");
	exit_application(1);
}

my $msg = "OVSD Installed Application Links";
print "$msg\n";
logging($msg);
my $query = "SELECT `FROM-CIID`, `FROM-SEARCHCODE`, `TO-CIID`, `TO-BACKUP-SERVER`
		  FROM ovsd_db_rels
		  WHERE ((`TO-SEARCHCODE` like  'HW-SVR%') OR
		         ((`TO-SEARCHCODE` like  'LE%') AND 
			      NOT (`TO-SEARCHCODE` like  'LE-WPA%')))
			AND ((`FROM-STATUS` = 'Active') OR
			     (`FROM-STATUS` = 'New'))";
my $sth = $dbs->prepare($query);
my $rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
while (my $ref = $sth->fetchrow_hashref) {
	
	my ($appl_name_long, $fqdn);	
	my $source_system_element_id = $ref->{'FROM-CIID'} || "";
	my $fromsearchcode = $ref->{'FROM-SEARCHCODE'} || "";
	# Get Instance tag for this Installed Product
	# This instance tag should be appl_name_long
	my @fields = ("source_system_element_id");
	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	my $right_name = get_field($dbt, "application_instance", "application_instance_tag", \@fields, \@vals);
	$source_system_element_id = $ref->{'TO-CIID'} || "";
	my $left_name = get_server($dbs, $source_system_element_id);
	if (length($right_name) == 0) {
		error("No DB Attributes for $fromsearchcode - $left_name");
		my @outarray = ($source_system_element_id, $fromsearchcode, $left_name, "No DB Attribute data");
		print DbIssues join($delim, @outarray), "\n";
		next;
	} else {
		$appl_name_long = $right_name;
	}
	if (length($left_name) == 0) {
		error("No Server Data for $fromsearchcode");
		my @outarray = ($fromsearchcode, $left_name, "No System Data");
		print DbIssues join($delim, @outarray), "\n";
		next;
	} else {
		$fqdn = $left_name;
	}
	my $backup_server = $ref->{'TO-BACKUP-SERVER'} || "";
	if (length($backup_server) == 0) {
		# Add record
		@fields = ("fqdn", "appl_name_long");
		(@vals) = map { eval ("\$" . $_ ) } @fields;
		create_record($dbt, "installed_application", \@fields, \@vals);
	} else {
		# Not interested in DB Backup Servers this time, ignore
		next;
	}
	# Now check if info is known already
	if (exists($rels{lc("$left_name*$right_name")})) {
		$dupl_cnt++;
	} else {
		$rels{lc("$left_name*$right_name")} = 1;
		$rels_cnt++;
	}
}
$msg = "$rels_cnt ComputerSystem to DB relations found, $dupl_cnt duplicates";
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
