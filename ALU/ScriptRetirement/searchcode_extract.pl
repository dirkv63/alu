=head1 NAME

searchcode_extract - This script will split-up the SearchCode into ParentClass - Class - Name - Environment.

=head1 VERSION HISTORY

version 1.0 30 August 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Hardware information from ESL dump.

=head1 SYNOPSIS

 searchcode_extract.pl [-t] [-l log_dir] [-c] [-m mysql_table]
 searchcode_extract -h	Usage
 searchcode_extract -h 1  Usage and description of the options
 searchcode_extract -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=item B<-c>

If specified, then do NOT clear tables in CIM before populating them.

=item B<-m mysql_table>

Table where Searchcode need to be extracted. Default: ovsd_applications. Target fields: sc_parent - sc_class - sc_name - sc_environment.

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -c, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
########### 

my ($logdir, $dbs, $dbt);
my $printerror = 0;
my $tbl = "ovsd_applications";

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

######
# Main
######

# Handle input values
my %options;
getopts("tl:h:cs:m:", \%options) or pod2usage(-verbose => 0);
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
# Get table
if ($options{"m"}) {
	$tbl = $options{"m"};
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

my $msg = "DROP Table if exists";
print "$msg\n";
logging($msg);

# Create OVSD Application Table without Inactive Applications
my $query = "DROP TABLE IF EXISTS ovsd_applications";
my $sth = $dbs->prepare($query);
my $rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

$msg = "Remove Inactive applications";
print "$msg\n";
logging($msg);

# Create OVSD Application Table without Inactive Applications
$query = "CREATE TABLE ovsd_applications
			 SELECT * FROM ovsd_applications_all
			 WHERE not (status = 'Inactive')";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Remove Empty fields
$msg = "Remove Empty fields 46 and 47";
print "$msg\n";
logging($msg);

$query = "ALTER TABLE ovsd_applications
		  DROP `Field46`,
		  DROP `Field47`";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

# Add additional fields 
# Searchcode: sc_parent, sc_name, sc_environment
# Portfolio: pf

$msg = "Add fields for Search Code and Portfolio number";
print "$msg\n";
logging($msg);

$query = "ALTER TABLE `ovsd_applications`
		  ADD `sc_parent` VARCHAR(255) NULL,
		  ADD `sc_class` VARCHAR(255) NULL,
		  ADD `sc_name` VARCHAR(255) NULL,
		  ADD `sc_environment` VARCHAR(255) NULL,
		  ADD `pf` VARCHAR(255) NULL";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}

$msg = "Add data in the fields";
print "$msg\n";
logging($msg);

# Create the Query Statement
$query = "SELECT SEARCHCODE, `SOLUTIONS PORTFOLIO ID`
			 from $tbl";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
while (my $ref = $sth->fetchrow_hashref) {

	my $SEARCHCODE = $ref->{"SEARCHCODE"};
	my @searcharr = split /-/, $SEARCHCODE;
	my ($sc_name, $sc_environment);
	my $sc_parent = shift @searcharr;
	my $sc_class = shift @searcharr;
	# Check for number of elements left
	# If 2 or more, then last element is environment
	# If only one, then no environment is specified.
	my $searcharr_length = @searcharr;
	if ($searcharr_length > 1) {
		$sc_environment = pop @searcharr;
		$sc_name = join ("-", @searcharr);
	} else {
		$sc_environment = "NotDefined";
		$sc_name = join ("-", @searcharr);
	}
	my $pf = $ref->{"SOLUTIONS PORTFOLIO ID"} || "";
	$pf = substr($pf, 0, 5);
	my @fields = ("SEARCHCODE", "sc_parent", "sc_class", "sc_name", "sc_environment", "pf");
	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	update_record($dbs, $tbl, \@fields, \@vals);

}

exit_application(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
