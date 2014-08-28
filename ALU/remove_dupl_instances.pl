=head1 NAME

remove_dupl_instances - Remove Duplicate Application Instances for Assetcenter

=head1 VERSION HISTORY

version 1.0 2 May 2012 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will remove the duplicate application instances from assetcenter processing. The transition model doesn't accept duplicate objects so data extract needs to implement this work-around.

For now there is no guideline on relations, so duplicate relations will be send for processing (Source for Transformation vs Source for Reference can be mixed in a relationship, therefore relationships can come from different sources and duplicates can be accepted).

=head1 SYNOPSIS

 remove_dupl_instances.pl [-t] [-l log_dir]

 remove_dupl_instances -h	Usage
 remove_dupl_instances -h 1  Usage and description of the options
 remove_dupl_instances -h 2  All documentation

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

$summary_log->info("Remove duplicate Application Instance Relations");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

do_stmt($dbt, "
DELETE a
  FROM application_instance a, ovsd_expl_application_instance o
  WHERE a.application_instance_tag = o.application_instance_tag") or exit_application(1);

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
