=head1 NAME

solutions_from_ovsd - Extract Solutions Information from OVSD

=head1 VERSION HISTORY

version 1.1 17 November 2011 DV

=over 4

=item *

Get Product Application Information from Product Portfolio File.

=back

version 1.0 10 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Solutions Attribute information from OVSD.

=head1 SYNOPSIS

 solutions_from_ovsd.pl [-t] [-l log_dir] [-c]

 solutions_from_ovsd -h	Usage
 solutions_from_ovsd -h 1  Usage and description of the options
 solutions_from_ovsd -h 2  All documentation

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

my ($logdir, $dbs, $dbt, $source_system, $clear_tables);
my $printerror = 0;
my $appl_cnt = 0;
my $pf_cnt = 0;
my $unk_cnt = 0;

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

=pod

=head2 Get Application to Standard Software Link

*** Should no longer be used ***

This procedure will get the link between the Application Instance and the Standard Software. The link is in the table ovsd_apps_rels. Search for Relation Type 'Consists Of' and TO-CATEGORY "SW-STD" (Standard Software). There should be max. one link.

Find the CIID from the Standard Software, then get application_id for this CIID.

Note that this information is only relevant for Databases, to link the database with its Database type (Oracle, 

=cut

sub get_appl_sw($$$) {
	my ($dbs, $dbt, $ciid) = @_;
	my ($application_id);
	my $query = "SELECT `TO-CIID`
	             FROM ovsd_apps_rels
				 WHERE `FROM-CIID` = '$ciid'
				   AND `RELATIONSHIP` = 'Consists Of'";
	my $sth = $dbs->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		my $source_system_element_id = $ref->{'TO-CIID'} || "";
		my @fields = ("source_system_element_id");
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		$application_id = get_recordid($dbt, "application", \@fields, \@vals);
		if (length($application_id) == 0) {
			error("Link Appl to Std SW defined for Std SW $source_system_element_id, but not found in applications file");
		} else {
			$appl_cnt++;
		}
	} else {
		$application_id = "";
	}
	return $application_id;
}

=pod

=head2 Get CI Owner Company

Get the CI Owner Company for the OVSD Application Instance.

If application category = 'Custom Application', then this is ALU Owned, HP Managed Application.

If application category = 'BU Managed Application', then this is a ALU Retained Application.

If application category = 'R+D Application', then use 'Service Provider/Outsourced to SearchCode'. If this contains 'Retained', then the CI is ALU Retained. Otherwise the CI is HP Owned.

=cut

sub get_ci_owner_company($$$) {
	my ($application_group, $service_provider, $sourcing_accountable) = @_;
	my ($ci_owner_company);
	$application_group = lc($application_group);
	$sourcing_accountable = lc($sourcing_accountable);
	if ((index($sourcing_accountable, "retained") > -1) || 
		(index($service_provider, "retained") > -1)) {
		$ci_owner_company = "ALU Retained";
	} elsif (($application_group eq "custom application") || ($application_group eq "bu managed application")) {
		$ci_owner_company = "ALU Owned";
#	} elsif ($application_group eq "bu managed application") {
#		$ci_owner_company = "ALU Retained";
	} elsif ($application_group eq "r+d application") {
		# No need to test for Service Provider anymore, has been done before
		$ci_owner_company = "HP";
	} else {
		error("Unknown Category $application_group in ovsd_applications");
		$ci_owner_company = "";
	}
	return $ci_owner_company;
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

$source_system = "OVSD_".time;

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
my $columns = 48;
my $rows = 1943;
check_table($dbs, "ovsd_applications", $columns, $rows);

# Clear tables if required
if (defined $clear_tables) {
	my @tables = ("availability", "application_instance", "billing",
	    	      "contactrole", "assignment", "operations", "workgroups");
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
init2blank($dbs,"ovsd_applications", \@initvalues);

my $msg = "Getting OVSD Application Attributes - Run DB Attributes collection after this";
print "$msg\n";
logging($msg);

my $query = "SELECT `CIID`, `NAME`, `ALIAS NAMES (4000)`, `DESCRIPTION 4000`,
					`CATEGORY`, `STATUS`, `ENVIRONMENT`, `SOX`, 
					`SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE`, `LOCATION`,
				   	`NOTES`, `DOC REF URL`, `SOLUTIONS PORTFOLIO ID`, 
					`SOURCING ACCOUNTABLE`, `BUSINESS STAKEHOLDER NAME`,
				   	`BUSINESS STAKEHOLDER ORGANIZATION`, `RESOURCE UNIT`,
				   	`BILLING CHANGE CATEGORY`, `BILLING REQUEST NUMBER`, 
					`LAST BILLING CHANGE DATE`, `SEARCHCODE`, `OWNER PERSON NAME`,
					`OWNER PERSON SEARCH CODE`
			 FROM `ovsd_applications` 
			 WHERE ((`STATUS` = 'Active') OR (`STATUS` = 'New'))
			   AND (`MASTER CMDB` is NULL)
			   AND (`CIID` = 13175)";
my $sth = $dbs->prepare($query);
my $rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
while (my $ref = $sth->fetchrow_hashref) {

	# Application Instance Information
	my ($application_instance_id);
	my $sox_system = $ref->{'SOX'} || "";
	if (lc($sox_system) eq "yes") {
		$sox_system = "SOX";
	} else {
		$sox_system = "";
	}
	my $source_system_element_id = $ref->{"CIID"} || "";
	my $appl_name_acronym = $ref->{'NAME'} || "";
	my $appl_name_long = $ref->{'SEARCHCODE'} || "";
	my $appl_name_description = $ref->{'DESCRIPTION 4000'} || "";
	my $service_provider = $ref->{'SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE'} || "";
	my $application_region = $ref->{'LOCATION'} || "";
	my $notes = $ref->{'NOTES'} || "";
	my $doc_ref_url = $ref->{'DOC REF URL'} || "";
	my $application_instance_tag = $ref->{'SEARCHCODE'} || "";
	$application_instance_tag = lc($application_instance_tag);
	my $instance_category = "ApplicationInstance";
	my $ci_owner = $ref->{"OWNER PERSON NAME"} || "";
	my $person_searchcode = $ref->{"OWNER PERSON SEARCH CODE"} || "";
	my $ovsd_searchcode = $ref->{"SEARCHCODE"} || "";

	# Availability 
	# Handle Availability first since ENVIRONMENT is required for Application
	my ($availability_id);
	my $runtime_environment = $ref->{'ENVIRONMENT'} || "";
	my @fields = ("runtime_environment");
	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$availability_id = create_record($dbt, "availability", \@fields, \@vals);
	} else {
		$availability_id = "";
	}

	# Get Application Information
	my ($application_id);
	my $portfolio_id = $ref->{'SOLUTIONS PORTFOLIO ID'} || "";
	my $application_group = $ref->{'CATEGORY'} || "";
	my $application_type = translate($dbt, "ovsd_applications", "CATEGORY", $application_group);
	my $application_category = "business application";
	my $lifecyclestatus = $ref->{'STATUS'} || "";
	$lifecyclestatus = translate($dbt, "ovsd_applications", "STATUS", $lifecyclestatus);

	my $sourcing_accountable = $ref->{'SOURCING ACCOUNTABLE'} || "";
	# First review if this is the instance of a product
	# Note: this applies to 'Consists Of' relation, 
	# which is only relevant for Databases
	# $application_id = get_appl_sw($dbs, $dbt, $source_system_element_id);
	# Application not known, find link to Portfolio ID
	if (not(defined($application_id)) || (length($application_id) == 0)) {
		if (length($portfolio_id) > 0) {
			# Check if Application has been defined with the Portfolio ID
			my @fields = ("portfolio_id");
			my (@vals) = map { eval ("\$" . $_ ) } @fields;
			# If Application is known, use application_id
			$application_id = get_recordid($dbt, "application",\@fields, \@vals);
			if (length($application_id) > 0) {
				# Instance from a Portfolio Application
				$pf_cnt++;
			}
		} else {
			# Portfolio ID not available
			# but try CI ID for Production Solution Instances. 
			# It has been seen that CI ID is often the Portfolio ID
			# for the earlier solutions.
			# This will solve approx. 40 from the 290 Instances (leaves 250 issue records)
			if (lc($runtime_environment) eq "production") {
				$portfolio_id = $source_system_element_id;
				my @fields = ("portfolio_id");
				my (@vals) = map { eval ("\$" . $_ ) } @fields;
				$application_id = get_recordid($dbt, "application",\@fields, \@vals);
				if (length($application_id) > 0) {
					# Instance from a Portfolio Application
					# Apparantly CI ID was the Portfolio ID
					$pf_cnt++;
				} else {
					# CI ID was not Portfolio ID
					# Reset Portfolio ID to blank
					$portfolio_id = "";
				}
			}
		}
	}
	# Application not known, create an application link
	if (not(defined($application_id)) || (length($application_id) == 0)) {
		# Set Application name to unknown OVSD App
		my $application_tag = "Unknown_OVSD*" . lc($appl_name_long);
		my @fields = ("source_system", "source_system_element_id", "portfolio_id", 
			       "appl_name_acronym", "appl_name_long", "appl_name_description", 
				   "application_category", "sourcing_accountable",
			       "application_tag", "application_type", "application_group");
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		if ( val_available(\@vals) eq "Yes") {
			$application_id = create_record($dbt, "application", \@fields, \@vals);
		} else {
			error("Application could not be created for $source_system_element_id");
			next;
		}
		$unk_cnt++;
	}

	# Get Owner Company and Retained Information
	my $ci_owner_company = get_ci_owner_company($application_group, $service_provider, $sourcing_accountable);

	# Billing
	my ($billing_id);
	my $billing_change_category = $ref->{"BILLING CHANGE CATEGORY"} || "";
	my $billing_resourceunit_code = $ref->{"RESOURCE UNIT"} || "";
	$billing_resourceunit_code = tx_resourceunit($billing_resourceunit_code);
	my $billing_change_date = $ref->{"LAST BILLING CHANGE DATE"} || "";
	$billing_change_date = conv_date($billing_change_date);
	my $billing_change_request_id = $ref->{"BILLING REQUEST NUMBER"} || "";
	@fields = ("billing_change_category", "billing_resourceunit_code", "billing_change_date", "billing_change_request_id");
	(@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$billing_id = create_record($dbt, "billing", \@fields, \@vals);
	} else {
		$billing_id = "";
	}

	# Create Application Instance Record
	@fields = ("source_system", "source_system_element_id", "appl_name_acronym",
	   	       "appl_name_long", "appl_name_description", "lifecyclestatus", 
			   "sox_system", "service_provider", "application_region", "ovsd_searchcode", 
			   "doc_ref_url", "availability_id", "application_id", "billing_id", 
			   "application_instance_tag", "instance_category", "ci_owner_company", "ci_owner");
   	(@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$application_instance_id = create_record($dbt, "application_instance", \@fields, \@vals);
	}
	
	# Get Workgroup Information
	store_workgroup_data($dbs, $dbt, "application_instance_id", $application_instance_id, $source_system_element_id);

	# Handle Technical Owner Contact
	my $person_id = ovsd_person($dbt, $ci_owner, $person_searchcode);
	if (length($person_id) > 0) {
		my $contact_type = "Technical Owner";
		my @fields = ("application_instance_id", "contact_type", "person_id");
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		if ( val_available(\@vals) eq "Yes") {
			my $contactrole_id = create_record($dbt, "contactrole", \@fields, \@vals);
		}
	}

}
$msg = "$pf_cnt instances from portfolio applications, $appl_cnt instances from standard software, $unk_cnt instances from unknown product";
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
