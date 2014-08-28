=head1 NAME

uat_extract - Extract the UAT Data.

=head1 VERSION HISTORY

version 1.0 16 January 2012 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract all data that is required to build an application / infrastructure  configuration.

The script starts with Portfolio IDs, for the Portfolio Applications in Scope. Then the script will find all related application instances. 

From application instances, dependencies to product instances, application instances and systems are extracted. 

Each Product instance will get it's installed product object and the product itself. Also the computersystem will be added to the checklist.

Then all computersystems will be handled. 

As a result all objects that are related to the application will be available in the uat table. This can then be used to remove all data that is not related. When all data is removed, then the normal extract can be done.

=head1 SYNOPSIS

 uat_extract.pl [-t] [-l log_dir] -i

 uat_extract -h	Usage
 uat_extract -h 1  Usage and description of the options
 uat_extract -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=item B<-i>

Initialize. If specified, then clear uat table and fill with pfids.

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -c, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
########### 

my ($logdir, $dbt, $init_uat);
my $printerror = 0;
my $delim = "|";						# Delimiter
my @pfids = (70362,			# PDM
	         80006          # LMS
		    );

			 

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

=head2 Update UAT

This procedure will update the UAT table if required. It will check if the table / tag exists. If so, then no change will be done. If not,then table tag will be added with status check or keep. Status check is default, status keep should be used for applications only.

=cut

sub update_uat($$$$) {
	my ($dbh, $tag, $table, $status) = @_;
	# Check if the application instance does not yet exist in uat
	# It doesn't matter what the status is, but if status exists then the record exists
	my @fields = ('tag', 'table');
	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	my $uat_status = get_field($dbh, 'uat', 'status', \@fields, \@vals);
	if (length($uat_status) == 0) {
		# UAT Status field empty, so record does not exist.
		# Add it to uat table
		@fields = ('tag', 'table', 'status');
		(@vals) = map { eval ("\$" . $_ ) } @fields;
		my $uat_id = create_record($dbh, 'uat', \@fields, \@vals);
	}
}

=pod

=head2 Application Instance to Application Instance Relation

This procedure will collect the Application Instance - Application Instance relationship. These are the 'depends on' relations. We need to search for the right name component.

=cut

sub get_appl_inst_appl_inst($$) {
	my ($dbh, $left_name) = @_;
	my $relation = 'depends on';
	my $query = "SELECT right_name
				 FROM relations
				 WHERE relation = '$relation'
				   AND left_name = '$left_name'";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	while (my $ref = $sth->fetchrow_hashref) {
		my $right_name = $ref->{right_name} || '';
		update_uat($dbh, $right_name, 'application_instance', 'check');
	}
}

=pod

=head2 Application Instance to Server Relation

This procedure will collect the Application Instance to Server relationships. This relationship can be a 'has installed' relation (for Products installed on a computersystem) or a 'has depending solution' relation (for Applications depending on a system).

=cut

sub get_appl_inst_server($$$) {
	my ($dbh, $right_name, $relation) = @_;
	my $query = "SELECT left_name
				 FROM relations
				 WHERE relation = '$relation'
				   AND right_name = '$right_name'";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	while (my $ref = $sth->fetchrow_hashref) {
		my $fqdn = $ref->{left_name} || '';
		update_uat($dbh, $fqdn, 'computersystem', 'keep');
	}
}

=pod

=head2 Handle Application Instances

This procedure will handle the Application Instances. It will search for all application instances with status 'check'.

First it will set the status on 'keep' for the application instance.

Then it will find the application (or product) related to the application instance. The application/product will be added to the uat table if it wasn't already in.

In case of type application, related application_instances will be searched and added to uat table. Then application_instance - system dependencies will be added.

In case of type product, only the systems on which the application instance is installed will be added.

=cut

sub handle_application_instances($) {
	my ($dbh) = @_;
	my $query = "SELECT tag
				 FROM uat
				 WHERE `table` = 'application_instance'
				   AND `status` = 'check'";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	while (my $ref = $sth->fetchrow_hashref) {
		my $tag = $ref->{tag} || '';

		# Set status to keep
		my $status = 'keep';
		my @fields = ('tag', 'status');
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		update_record($dbh, 'uat', \@fields, \@vals);

		# Find Application
		# Both Business Applications and Technical Products have a link to the Application ID.
		my ($application_type);
		my $application_instance_tag = $tag;
		# 1. Find application_id for the application_instance
		@fields = ('application_instance_tag');
		(@vals) = map { eval ("\$" . $_ ) } @fields;
		my $application_id = get_field($dbh, 'application_instance', 'application_id', \@fields, \@vals);
		# 2. Find application_tag associated with the application_id
		@fields = ('application_id');
		(@vals) = map { eval ("\$" . $_ ) } @fields;
		my $application_tag = get_field($dbh, 'application', 'application_tag', \@fields, \@vals);
		# 3. Check if application is already in uat, add if not. Ignore if it is already in uat.
		update_uat($dbh, $application_tag, 'application', 'keep');

		# Get application type for the application
		@fields = ('application_tag');
		(@vals) = map { eval ("\$" . $_ ) } @fields;
		if ( val_available(\@vals) eq "Yes") {
			$application_type = get_field($dbh, 'application', 'application_type', \@fields, \@vals);
		} else {
			error("Application Tag not found, shouldn't be the case. Exiting...");
			exit_application(1);
		}
		# Product Instance or Application_instance?
		if ($application_type eq 'Application') {
			# Application Instance
			# Get Application Instances to Application Instance Dependency
			get_appl_inst_appl_inst($dbh, $application_instance_tag);
			# Get Server Dependency
			get_appl_inst_server($dbh, $application_instance_tag, 'has depending solution');
		} elsif ($application_type eq 'TechnicalProduct') {
			# Installed Product for the Product Instance
			# is generated automatically, no need to find it.
			# Get Server on which the application is installed
			get_appl_inst_server($dbh, $application_instance_tag, 'has installed');
		} else {
			error("Application type $application_type is not known, please review!");
			exit_application(1);
		}
	}
}

=pod

=head2 Find Application Instances

This procedure will find all application instances that are related to an application. If the application instance does not exist in uat table, then it will be added. Otherwise it will be ignored.

=cut

sub find_appl_instances($$) {
	my ($dbh, $tag) = @_;
	my $table = 'application_instance';
	my $query = "SELECT i.application_instance_tag
				 FROM application_instance i, application a
				 WHERE a.application_tag = '$tag'
				   AND a.application_id = i.application_id";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	while (my $ref = $sth->fetchrow_hashref) {
		my $tag = $ref->{application_instance_tag} || '';
		update_uat($dbh, $tag, $table, 'check');
	}
	return;
}

=pod

=head2 Handle Applications

This script will handle application CIs. First the application CI status will be changed to 'keep', to indicate that the application has been handled. Then all application instances related to this application will be collected in the uat table.

=cut

sub handle_applications($) {
	my ($dbh) = @_;
	my $query = "SELECT tag
				 FROM uat
				 WHERE `table` = 'application'
				   AND `status` = 'check'";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	while (my $ref = $sth->fetchrow_hashref) {
		my $tag = $ref->{tag} || '';
		# Set status to Keep
		my $status = 'keep';
		my @fields = ('tag', 'status');
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		update_record($dbh, 'uat', \@fields, \@vals);
		# Then find all application instances related to this application
		find_appl_instances($dbh, $tag);
	}
	return;
}

=pod

=head2 Verify CIs

This procedure will verify if there are more CIs to check in the UAT table. If so, all CI classes will be handled.

=cut

sub verify_cis($) {
	my ($dbh) = @_;
	my ($cnt);
	my $query = "SELECT count(*) as cnt
				 FROM uat
				 WHERE `status` = 'check'";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
		exit_application(1);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		$cnt = $ref->{cnt} || 0;
	} else {
		error("Could not count status fields in table uat, exiting...");
		exit_application(1);
	}
	if ($cnt > 0) {
		my $msg = "$cnt CIs need to be verified";
		print "$msg\n";
		logging($msg);
		handle_applications($dbh);
		handle_application_instances($dbh);
#		handle_computersystems($dbh);
	}
	return $cnt;
}

sub init_uat($) {
	my ($dbh) = @_;
	my $msg = "Initialize UAT table";
	print "$msg\n";
	logging($msg);
	# Clear Table
	my @tables = ("uat");
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
	# Now convert all application IDs to application tags
	# and add the tags to the uat table
	my $status = 'check';
	my $table = 'application';
	foreach my $portfolio_id (@pfids) {
		# Get Application Tag
		my @fields = ('portfolio_id');
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		my $tag = get_field($dbh, 'application', 'application_tag', \@fields, \@vals);
		@fields = ('table', 'tag', 'status');
		(@vals) = map { eval ("\$" . $_ ) } @fields;
		my $uat_id = create_record($dbh, 'uat', \@fields, \@vals);
	}
}

######
# Main
######

# Handle input values
my %options;
getopts("itl:h:c", \%options) or pod2usage(-verbose => 0);
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
if (defined $options{i}) {
	$init_uat = "Yes";
} else {
	$init_uat = "No";
}
# Show input parameters
while (my($key, $value) = each %options) {
    logging("$key: $value");
    trace("$key: $value");
}
# End handle input values

# Make database connection for target database
my $connectionstring = "DBI:mysql:database=$dbtarget;host=$server;port=$port";
$dbt = DBI->connect($connectionstring, $username, $password,
		   {'PrintError' => $printerror,    # Set to 1 for debug info
		    'RaiseError' => 0});	    	# Do not die on error
if (not defined $dbt) {
   	error("Could not open $dbtarget, exiting...");
   	exit_application(1);
}

if ($init_uat eq 'Yes') {
	init_uat($dbt);
}

my $cnt = 1;	# Counter = 1 to kick off process
while ($cnt > 0) {
	$cnt = verify_cis($dbt);
}

exit_application(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
