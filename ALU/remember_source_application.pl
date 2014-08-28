=head1 NAME

remember_source_application - Script to remember the link between Source System and Application.

=head1 VERSION HISTORY

version 1.0 09 December 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will collect the link between Source Systems and Portfolio Application. 

ESL Business Application is a copy from A7 and OVSD Application Instance. The ESL Business Application has the link to the Source System. 

Processing at Source System layer understood the link between A7 / OVSD Business Application Instance and Portfolio Application. ESL needs to read this link to create full structure.

The script needs to run after full OVSD solution data collection and after full Assetcenter solution Data collection and before ESL solution data collection.

=head1 SYNOPSIS

 remember_source_application.pl [-t] [-l log_dir] [-c]

 remember_source_application -h	Usage
 remember_source_application -h 1  Usage and description of the options
 remember_source_application -h 2  All documentation

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

my ($clear_tables);

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
getopts("tl:h:c", \%options) or pod2usage(-verbose => 0);

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
my $data_log = Log::Log4perl->get_logger('Data');

my $scriptname = basename($0,"");

$summary_log->info("Start `$scriptname' application");

# Clear data by default
$clear_tables = "Yes" unless (defined $options{"c"});

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values
# ==========================================================================

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

# Clear tables if required
if (defined $clear_tables) {
  my @tables = ("application_relation");

  foreach my $table (@tables) {
    $summary_log->info("Truncate table $table");

    unless ($dbt->do("truncate $table")) {
      ERROR("Could not truncate table `$table'. Error: ". $dbt->errstr);
      exit_application(1);
    }
  }
}

do_stmt($dbt, "
INSERT INTO application_relation
  SELECT source_system, source_system_element_id, application_id
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
