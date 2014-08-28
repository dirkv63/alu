=head1 NAME

products_from_ovsd - Extract Product Information from Standard Software Information.

=head1 VERSION HISTORY

version 1.0 23 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Standard Solution Software from Application Relations and from Database Relations.

Standard Software Category and Consists of Relation apparantly are not up to date. For Databases, equivalent and more up-to-date information is available in the OS Name and OS Version fields. For Solutions, the consists of or Depends on link to Standardard Software is not up-to-date. There is no room in ESL to store this information. 

Approach now is to extract as much information as possible. Decision not to use information can be taken later.

Standard Software is handled as a product.

=head1 SYNOPSIS

 products_from_ovsd.pl [-t] [-l log_dir] [-c]

 products_from_ovsd -h	Usage
 products_from_ovsd -h 1  Usage and description of the options
 products_from_ovsd -h 2  All documentation

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

my ($logdir, $dbs, $dbt, $source_system, $clear_tables, %apps);
my $printerror = 0;
my $source = "OVSD";

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

$source_system = $source . "_" .time;

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
# No check on columns, this is done in other applications.

# Clear tables if required
# No tables should be cleared
if (defined $clear_tables) {
	my @tables = ();
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
init2blank($dbs,"pf", \@initvalues);

my $msg = "Getting Standard Solutions from Application Relation File";
print "$msg\n";
logging($msg);

my $query = "SELECT distinct `TO-CIID`, `TO-NAME`,  
                    `TO-DESCRIPTION (4000)`, `TO-CATEGORY`, `TO-STATUS`, 
					`TO-SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE`, 
					`TO-LOCATION` 
			 FROM `ovsd_apps_rels` 
			 WHERE `TO-CATEGORY` = 'Standard Application'";
my $sth = $dbs->prepare($query);
my $rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
while (my $ref = $sth->fetchrow_hashref) {

	# Application Information
	my ($application_id);
	my $source_system_element_id = $ref->{'TO-CIID'} || "";
	my $appl_name_long = $ref->{'TO-NAME'} || "";
	my ($appl_name_acronym, @verstring) = split /\//, $appl_name_long;
	$appl_name_acronym = trim($appl_name_acronym);
	my $version = join("/", @verstring);
	my $appl_name_description = $ref->{'TO-DESCRIPTION (4000)'} || "";
	my $sourcing_accountable = $ref->{'TO-SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE'} || "";
	# Check if I know about 'Retained' info
	# Note that "Standard Application" doesn't have Retained Data
	# (as logical expected)
	my $ci_owner_company = lc($sourcing_accountable);
	if (index($ci_owner_company, "retained") > -1) {
		$ci_owner_company = "ALU Retained";
	} else {
		$ci_owner_company = "";
	}
	my $application_group = $ref->{'TO-CATEGORY'} || "";
	my $application_category = "customer software";
	my $application_type = "TechnicalProduct";
	my $application_tag = lc($appl_name_long);
	my @fields = ("appl_name_long", "appl_name_description", "appl_name_acronym", "application_group", 
				  "application_category", "source_system", "source_system_element_id",
			      "sourcing_accountable", "version", "application_tag",
			      "application_type", "ci_owner_company");
	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$application_id = create_record($dbt, "application", \@fields, \@vals);
	} else {
		$application_id = "";
	}

}

$msg = "Getting Standard Solutions from Database Relation File";
print "$msg\n";
logging($msg);
my $found_cnt = 0;
my $new_cnt = 0;
$query = "SELECT distinct `TO-CIID`, `TO-STATUS`, `FROM-OS NAME`
			 FROM `ovsd_db_rels` 
			 WHERE `TO-SEARCHCODE` like 'SW-STD%'
			   AND `FROM-OS NAME` is not null";
$sth = $dbs->prepare($query);
$rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
while (my $ref = $sth->fetchrow_hashref) {

	# Application Information
	my ($application_id);
	my $source_system_element_id = $ref->{'TO-CIID'} || "";
	my $appl_name_acronym = $ref->{'FROM-OS NAME'} || "";
	my $appl_name_long = $ref->{'FROM-OS_NAME'} || "";
	my $application_group = "STANDARD SOFTWARE";
	my $application_category = "Database";
	my $application_type = "TechnicalProduct";
	# Check if I know about 'Retained' info
	# Note that "Standard Application" doesn't have Retained Qualifiers
	my $ci_owner_company = "";
	# Verify that application has not been defined
	my @fields = ("source_system_element_id");
	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	$application_id = get_recordid($dbt, "application", \@fields, \@vals);
	if (length($application_id) > 0) {
		$found_cnt++;
	} else {
		my $application_tag = "New_Std_SW_DB*" . lc($appl_name_long) ."*$source_system_element_id";
		my @fields = ("appl_name_long", "appl_name_acronym", "application_tag", "application_type",
					  "application_category", "source_system", "source_system_element_id",
					  "ci_owner_company", "application_group");
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		if ( val_available(\@vals) eq "Yes") {
			$application_id = create_record($dbt, "application", \@fields, \@vals);
		} else {
			$application_id = "";
		}
		$new_cnt++;
	}
}
$msg = "$found_cnt Database Standard SW Products found, $new_cnt DB Products new created";
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
