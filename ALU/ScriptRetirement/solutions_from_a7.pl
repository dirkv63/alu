=head1 NAME

solutions_from_a7 - Extract Solutions Information from A7

=head1 VERSION HISTORY

version 1.1 17 November 2011 DV

=over 4

=item *

Update to get Product Data from Portfolio File

=back

version 1.0 09 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Solutions Attribute information from Assetcenter.

=head1 SYNOPSIS

 solutions_from_a7.pl [-t] [-l log_dir] [-c]

 solutions_from_a7 -h	Usage
 solutions_from_a7 -h 1  Usage and description of the options
 solutions_from_a7 -h 2  All documentation

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
my $pf_conv = 0;
my $sol_cnt = 0;
my $new_sol_cnt = 0;

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

=head2 Get Portfolio ID from Portfolio ID Long

Portfolio ID is in Assetcenter field `*_ Hostname / inst'. If PF ID exists, then get part before first underscore. If this is a 5 digit number, then it is a Portfolio ID.

=cut

sub get_pf($) {
	my ($portfolio_id_long) = @_;
	my ($portfolio_id, undef) = split /\_/, $portfolio_id_long;
	# Check if Portfolio ID is numeric and 5 characters long
	if (defined($portfolio_id) &&
	    (length($portfolio_id) == 5) && 
	    ($portfolio_id =~ /^[0-9][0-9]*$/)) {
		# OK - found valid Portfolio ID
		$pf_conv++;
	} else {
		# Not a valid Portfolio ID
		$portfolio_id = "";
	}
	return $portfolio_id;
}

=pod

=head2 Get CI Owner Company

Technical Products are always owned by HP, when they come from Assetcenter. For Applications, review the Class:

If Class = SOL_A&S, then Business application, not part of CSM. ALU Owned, HP Managed.

If Class = SOL_CUS, then Business application, part of CSM. ALU Owned, HP Managed.

If Class = SOL_BU: then Application no longer managed by IS: ALU Retained. In this case there should be no links to Assetcenter Products.

=cut

sub get_ci_owner_company($) {
	my ($application_class) = @_;
	my ($ci_owner_company);
	$application_class = lc($application_class);
	# First Get Technical Products
	if (($application_class eq "sol_solution") || ($application_class eq "sol_instance")) {
		$ci_owner_company = "HP";
	} elsif (($application_class eq "sol_a&s") || ($application_class eq "sol_cus")) {
		$ci_owner_company = "ALU Owned";
	} elsif ($application_class eq "sol_bu") {
		$ci_owner_company = "ALU Retained";
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

$source_system = "A7_".time;

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
my $columns = 36;
my $rows = 4715;
check_table($dbs, "a7_solutions", $columns, $rows);

# Clear tables if required
if (defined $clear_tables) {
	my @tables = ("availability", "application_instance",
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
my @initvalues = ("* Master flag", "*_ Status");
init2blank($dbs,"a7_servers", \@initvalues);

my $msg = "Getting Solution Attributes - Run after OVSD Product";
print "$msg\n";
logging($msg);

my $query = "SELECT `Prefix (*_ Category)`, `*_ CI class`, `*_ CI Responsible`, 
				    `*_ Inventory #`, `*_ Serial #`, `*_ Brand`, `_ User`, 
					`* Model (*_ Product)`, `*_ Status`, `Full name (* Location)`, 
					`Billing Change Category`, `*_ ABC: CI destination / RU`, 
					`Last Billing Change Date`, `Billing Request Number`, `_ Sox_Tier`,
					`*_ Support code`, `Asset tag`, `_ IT contact`, `_ SOX application`, 
					`Sourcing Accountable`, `* CI Ownership`, `*_ Hostname / inst`,
					`* Oper System`, `* Operating System Version`
			 FROM `a7_solutions` 
			 WHERE (`*_ Status` = 'In Use')
			   AND ((`* Master flag` = '') OR 
					(`* Master flag` like 'AssetCenter%'))";
my $sth = $dbs->prepare($query);
my $rv = $sth->execute();
if (not defined $rv) {
	error("Could not execute query $query, Error: ".$sth->errstr);
	exit_application(1);
}
while (my $ref = $sth->fetchrow_hashref) {

	# Application Instance Information
	my ($application_instance_id, $sox_system);
	my $source_system_element_id = $ref->{"Asset tag"} || "";
	my $ci_responsible = $ref->{'*_ CI Responsible'} || "";
	my $support_code = $ref->{'*_ Support code'} || "";
	my $sox_appl = $ref->{'_ SOX application'} || 0;
	my $sox_tier = $ref->{'_ Sox_Tier'} || "";
	if (($sox_appl == 1) || (length($sox_tier) > 0)) {
		$sox_system = "SOX";
	} else {
		$sox_system = "";
	}
	my $ci_owner = $ref->{'_ User'} || "";
	my $appl_name_long = $ref->{'*_ Serial #'} || "";
	my $application_instance_tag = lc($appl_name_long);
	my $version = "";
	# Assetcenter Instances never have an OVSD Search Code.
	my $ovsd_searchcode = "Undef-Searchcode-" . $source_system_element_id;
	my $oper_system = $ref->{'* Oper System'} || "";	# I'll need Oper System later, better keep it as separate attribute

	# Application Information
	my ($application_id, $appl_name_acronym, $application_tag);
	my $lifecyclestatus = $ref->{'*_ Status'} || "";
	$lifecyclestatus = translate($dbt, "a7_solutions", "Status", $lifecyclestatus, "Errmsg");
	my $sourcing_accountable = $ref->{'Sourcing Accountable'} || "";
	my $portfolio_id_long = $ref->{'*_ Hostname / inst'} || "";


=pod

=head2 Application and Instance Category

Usage of Application Category to be reviewed. 

The Instance Category is used to understand the ESL Solution category in which the application instance will end up in. 

However this is not done based on Assetcenter Category, but rather on the Product Value from the attribute '* Oper System' field. There are two conditions: there is a value available for '* Oper System' or there is no value available. 

In the first condition, in case there is a value available, then there is a translation table available that will translate the '* Oper System' field to the ESL Solution Name. Each ESL Solution is defined in a category already, so starting from the ESL Solution one can read the corresponding category. The ESL Solution name needs to end up in the acronym name of the application to become the Product name. The Category needs to end up in the instance_category name.

In the second condition, in case there is no value available in '* Oper System', it is not easily possible to understand the product and the corresponding ESL Solution. The product name is derived from the '# Serial' field (see further). Each product will become a separate ESL Solution in the ESL 'Customer Software' category. Also here the resulting solution name needs to end up in the application acronym name to become the Product name. The instance_category is 'Customer Software'.

=cut

	my ($application_category, $instance_category);
	my $application_class = $ref->{'*_ CI class'} || "";
	my $application_type = translate($dbt, "a7_solutions", "CI class", $application_class, "Errmsg");
	my $application_group = $ref->{'*_ Brand'} || "";
	if ($application_type eq "Application") {
		$application_category = "business application"; 
		$instance_category = "ApplicationInstance";
	} else {
		if (length($oper_system) == 0) {
			# No Product Name known, so ESL Solution Customer Software
			$instance_category = "Customer Software";
			$application_category = "TechnicalProductInstance";
		} else {
			# Application Category translation from A7 Category is no longer used
			$instance_category = translate($dbt, "a7_solutions", "Brand", $application_group, "Errmsg");
			$application_category = translate($dbt, "a7_solutions", "application_category", $application_group, "Errmsg");
		}
		if (length($application_category) == 0) {
			error("No Application Category translation for $application_group to ESL Category (a7_solutions, application_category)");
		}
	}

=pod

=head2 Assetcenter Application or Product Name

=head3 Application Name

The application instance should be linked to an application in the Portfolio file. The Portfolio ID is in the field '*_ Hostname / inst'. If a portfolio ID can be extracted then it is verified if an entry with this Portfolio ID exists. If so, the Application Instance is linked to the existing Application from the Portfolio file. If there is no entry in the Portfolio file for this portfolio ID, then the Portfolio ID is remembered and the Application name is extracted from '# Serial' field as described elsewhere. Application Instance to Application mapping is done based on name as described below.

If no Portfolio ID can be extracted, then application instance to application name is done based on the name. The application name is extracted from the '# Serial' field as described elsewhere. 

In case Application Instance to Application mapping is done based on the application name, the application name is extracted as described above. In case the application name did not exist already in the application table then it will be added together with all attributes that can be extracted from this A7 Solution record. In case the application did exist already, then the application instance is mapped to this existing application based on the name. The Portfolio ID will be lost in this case (for now).

=head3 Product Name

The Application name or the Technical Product Name needs to be extracted from the '# Serial' field. Split-up between Application and Technical Product is done based on 'CI Class' value, see there.

For Technical Products, the product name is taken from the value in '* Oper System'. Then the product name is translated to get the corresponding ESL Solution. 

=head3 Application or Product Name from Serial Field

Standard convention for the values in '# Serial' field is three words: Category Solution Environment. In this case the middle word is extracted as the Product name.

There are exceptions: '# Serial' field has two words and '# Serial' has more than 3 words. 

When '# Serial' field has two words it is not possible to understand if the Category or the Environment has been omitted. The two words are combined to form the Product name. 

When '# Serial' field has more than 3 words, then the first and third field are removed. The other fields make up the Product name. 

For Applications the name is extracted from the '# Serial' field, using the same logic as for Technical Product name in case '* Oper System' is not available.

=cut

	# Get Middlename according to strategy described above
	my ($middlename);
	my @namelist = split /\ /, $appl_name_long;
	my $nr_of_names = @namelist;
	if ($nr_of_names < 3) {
		# Unexpected name, don't bother try to get out middleword
		$middlename = $appl_name_long;
	} else {
		# Three words or longer, start by collecting middleword
		$middlename = $namelist[1];
	}
	# Now drop words 1 .. 3 in application name, use the remaining part to make appl name
	# Longer than 3 should be an exception!
	if ($nr_of_names > 3) {
		# lousy procedure to get rid of first and third word
		shift @namelist;
		shift @namelist;
		shift @namelist;
		# now get rest of the name
		$middlename = $middlename . " " . join(" ", @namelist);
	}

	# Handle Applications and TechnicalProducts differently
	my ($portfolio_id);
	if (lc($application_type) eq "application") {
		# Check if Application has Portfolio ID in Hostname / Inst field
		$portfolio_id = get_pf($portfolio_id_long);
		if (length($portfolio_id) > 0) {
			# Portfolio ID exist, check if application is defined in Application table
			my @fields = ("portfolio_id");
			my (@vals) = map { eval ("\$" . $_ ) } @fields;
			$application_id = get_recordid($dbt, "application", \@fields, \@vals);
		}
		# Prepare appl_name variables. They will be loaded only if application_id is still blank
		# Otherwise they will be ignored.
		$appl_name_acronym = $middlename;
		# $appl_name_long = $middlename;	# Appl name long is 'Serial', same approach as SearchCode OVSD.
		# For Applications, application_tag is unique application name
		$application_tag = lc($appl_name_acronym);	
		$version = "";
		# Get Application ID for this application tag if it exist already
		if (length($application_tag) > 0) {
			my @fields = ("application_tag");
			my (@vals) = map { eval ("\$" . $_ ) } @fields;
			$application_id = get_recordid($dbt, "application", \@fields, \@vals);
		}
	} elsif (lc($application_type) eq "technicalproduct") {
		# Technical Application, check Solution Name in '* Oper System' field
		# For Customer Solutions, use Middlename as the Customer Solution Name
		# Use appl_name_acronym to consolidate on Solution
		$appl_name_acronym = $ref->{'* Oper System'} || $middlename;
		# Is translation from Application to ESL Solution to be done here or in Migration Application?
		# Doing it here allows to capture missing Operating Systems earlier.
		# Therefore use dummy_appl_name_acronym
		if (not($appl_name_acronym) eq $middlename) {
			my $dummy_appl_name_acronym = translate($dbt, "a7_solutions", "Oper System", $appl_name_acronym, "ErrMsg");
		}
		$version = $ref->{'* Operating System Version'} || "";
		# but use Product Name & Version to consolidate on Products
		$appl_name_long = $appl_name_acronym . "*" . $version;
		$application_tag = lc($appl_name_long);
		# Get Application ID for this application tag if it exists already
		if (length($application_tag) > 0) {
			my @fields = ("application_tag");
			my (@vals) = map { eval ("\$" . $_ ) } @fields;
			$application_id = get_recordid($dbt, "application", \@fields, \@vals);
		}
	} else {
		# Unknown Application Type
		error ("Unknown Application Type $application_type for $source_system_element_id");
		$application_tag = $source_system_element_id;
		$appl_name_acronym = "";
		$version = "";
	}
	if (not(defined $application_id) || (length($application_id) == 0)) {
		# Application or Product did not exist already, add them to the application table
		my @fields = ("application_category", "application_class", "application_group",
				      "sourcing_accountable", "appl_name_acronym",
					  "appl_name_long", "source_system_element_id", "source_system",
				      "portfolio_id", "version", "application_tag", "application_type");
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		if ( val_available(\@vals) eq "Yes") {
			$application_id = create_record($dbt, "application", \@fields, \@vals);
		} else {
			$application_id = "";
		}
		$new_sol_cnt++;
	} else {
		$sol_cnt++;
	}
	
	
	# Application Instance Information
	$appl_name_acronym = $ref->{'*_ Inventory #'} || "";
	$appl_name_long = $ref->{'*_ Serial #'} || "";
	$application_instance_tag = lc($appl_name_long);
	
	# Availability
	my ($availability_id);
	my $runtime_environment = $ref->{'* Model (*_ Product)'} || "";
	# Standardize runtime_environment
	if (index(lc($runtime_environment), "file_access production") > -1) {
		$runtime_environment = "PRODUCTION";
	} elsif (index(lc($runtime_environment), "pre_production") > -1) {
		$runtime_environment = "Pre Production";
	}

	my @fields = ("runtime_environment");
	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$availability_id = create_record($dbt, "availability", \@fields, \@vals);
	} else {
		$availability_id = "";
	}

	# Billing
	my ($billing_id);
	my $billing_change_category = $ref->{"Billing Change Category"} || "";
	my $billing_resourceunit_code = $ref->{"*_ ABC: CI destination / RU"} || "";
	$billing_resourceunit_code = tx_resourceunit($billing_resourceunit_code);
	my $billing_change_date = $ref->{"Last Billing Change Date"} || "";
	$billing_change_date = conv_date($billing_change_date);
	my $billing_change_request_id = $ref->{"Billing Request Number"} || "";
	@fields = ("billing_change_category", "billing_resourceunit_code", "billing_change_date", "billing_change_request_id");
	(@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$billing_id = create_record($dbt, "billing", \@fields, \@vals);
	} else {
		$billing_id = "";
	}

	# CI Owner Company
	my $ci_owner_company = get_ci_owner_company($application_class);

	# DetailedLocation
	@fields = ("source_system_element_id");
	(@vals) = map { eval ("\$" . $_ ) } @fields;
	my $detailedlocation_id = get_field($dbt, "detailedlocation", "detailedlocation_id", \@fields, \@vals);

	# Create Application Instance Record
	@fields = ("source_system", "source_system_element_id", "ci_responsible", "support_code",
	   	       "sox_system", "ci_owner", "portfolio_id_long", "appl_name_acronym", 
			   "appl_name_long", "application_id", "billing_id", "detailedlocation_id",
			   "availability_id", "application_instance_tag", "instance_category", 'ci_owner_company',
		       "lifecyclestatus", "ovsd_searchcode");
   	(@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$application_instance_id = create_record($dbt, "application_instance", \@fields, \@vals);
	}

	# Get Workgroup Information
	store_workgroup_data($dbs, $dbt, "application_instance_id", $application_instance_id, $source_system_element_id);

		# Contact Role - User Contact
	my $contactname = $ref->{'_ User'} || "";
	my $person_id = a7_person($dbt, $contactname);
	# Now assign role to person
	if (length($person_id) > 0) {
		my $contact_type = "Technical Owner";
		@fields = ("application_instance_id", "contact_type", "person_id");
		(@vals) = map { eval ("\$" . $_ ) } @fields;
		if ( val_available(\@vals) eq "Yes") {
			my $contactrole_id = create_record($dbt, "contactrole", \@fields, \@vals);
		}
	}
	
	# Contact Role - IT Contact
	$contactname = $ref->{'_ IT contact'} || "";
	$person_id = a7_person($dbt, $contactname);
	# Now assign role to person
	if (length($person_id) > 0) {
		my $contact_type = "Technical Lead";
		@fields = ("application_instance_id", "contact_type", "person_id");
		(@vals) = map { eval ("\$" . $_ ) } @fields;
		if ( val_available(\@vals) eq "Yes") {
			my $contactrole_id = create_record($dbt, "contactrole", \@fields, \@vals);
		}
	}
}

$msg = "$pf_conv Portfolio IDs found, $new_sol_cnt New Solutions $sol_cnt records linked with existing solutions";
print $msg."\n";
logging($msg);

exit_application(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
