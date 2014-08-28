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

#####
# use
#####

use warnings;			    # show warning messages
use strict;
use File::Basename;
use Getopt::Std;		    # Handle input params
use Pod::Usage;			    # Allow Usage information
use Log::Log4perl qw(:easy);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_stmt);
use ALU_Util qw(exit_application);

# ==========================================================================

######
# Main
######

# Handle input values
my %options;
getopts("tl:h:", \%options) or pod2usage(-verbose => 0);

if (defined $options{"h", }) {
  if    ($options{"h"} == 0) { pod2usage(-verbose => 0); }
  elsif ($options{"h"} == 1) { pod2usage(-verbose => 1); }
  else                       { pod2usage(-verbose => 2); }
}

my $level = 0;
# Trace required?
$level = 3 if (defined $options{"t"});

my $attr = { level => $level };

# Find log file directory
$attr->{logdir} = $options{"l"} if ($options{"l"});

setup_logging($attr);
my $summary_log = Log::Log4perl->get_logger('Summary');

my $scriptname = basename($0,"");

$summary_log->info("Start `$scriptname' application");

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values
# ==========================================================================

$summary_log->info("Copy table application_instance to ovsd_application_instance");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

my @tables = ("ovsd_application_instance");

foreach my $table (@tables) {
  $summary_log->info("Truncate table $table");

  unless ($dbt->do("truncate $table")) {
    ERROR("Could not truncate table `$table'. Error: ". $dbt->errstr);
    exit_application(1);
  }
}

# Copy application instance table
do_stmt($dbt, "
INSERT INTO ovsd_application_instance
  SELECT *
    FROM application_instance") or exit_application(1);

$dbt->disconnect;
$summary_log->info("Exit `$scriptname' application with success");
exit(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
