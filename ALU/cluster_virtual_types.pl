=head1 NAME

copy_app_inst - Copy Application Instance Table for OVSD usage.

=head1 VERSION HISTORY

version 1.0 19 April 2012 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will keep the application instance file with OVSD instances. This is required to keep track of the OVSD Application Instance names for links with Assetcenter.

This must be done before the explode_instances.pl script.

=head1 SYNOPSIS

 copy_app_inst.pl [-t] [-l log_dir]

 copy_app_inst -h	 Usage
 copy_app_inst -h 1  Usage and description of the options
 copy_app_inst -h 2  All documentation

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

my ($logdir, $dbt);
my $printerror = 0;
my $filedir = "d:/temp/alucmdb/";
my $delim = "|";

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
# Show input parameters
while (my($key, $value) = each %options) {
    logging("$key: $value");
    trace("$key: $value");
}
# End handle input values

my $msg = "Copy table application_instance to ovsd_application_instance";
print $msg."\n";
logging($msg);

# Make database connection for target database
my $connectionstring = "DBI:mysql:database=$dbtarget;host=$server;port=$port";
$dbt = DBI->connect($connectionstring, $username, $password,
		   {'PrintError' => $printerror,    # Set to 1 for debug info
		    'RaiseError' => 0});	    	# Do not die on error
if (not defined $dbt) {
   	error("Could not open $dbtarget, exiting...");
   	exit_application(1);
}

my @tables = ("ovsd_application_instance");
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

# Copy application instance table
my $query = "INSERT INTO `ovsd_application_instance` SELECT * FROM `application_instance`";
my $sth = $dbt->prepare($query);
my $rv = $sth->execute();
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
