=head1 NAME

hw_type_from_esl - This script will extract the Hardware Type Information from ESL relation dump.

=head1 VERSION HISTORY

version 1.0 05 October 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Hardware Type information from ESL Relation Dump.

The ESL Parent Relation Type has two types that can help to determine the Hardware Type (Box, Blade Enclosure, Blade Server). The Relation Type "Blade Server" is used in only 7 cases, investigation learned that it does not contain thrustworthy information. The Relation Type "Blade Enclosure" in a Parent Relation Type points from a Blade Server to a Parent System that is the Blade Enclosure.

=head1 SYNOPSIS

 hw_type_from_esl.pl [-t] [-l log_dir] [-s subbusiness]

 hw_type_from_esl.pl -h    Usage
 hw_type_from_esl.pl -h 1  Usage and description of the options
 hw_type_from_esl.pl -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=item B<-s subbusiness>

Sub business Name for the data extract. Default: 'CMO Martinique'. Other options: 'AGEO', 'Alcatel-DE-VMS', 'ALU-AMS', 'ALU-APJ', 'ALU-EMEA', 'ALU-Transformation'
For the moment this does not work.

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
########### 

my $enclcnt = 0;
my $srvcnt = 0;

#####
# use
#####

use warnings;                       # show warning messages
use strict;
use File::Basename;
use Getopt::Std;                    # Handle input params
use Pod::Usage;                     # Allow Usage information
use Log::Log4perl qw(:easy);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_execute);
use ALU_Util qw(exit_application);

#############
# subroutines
#############

# ==========================================================================

sub set_enclosure($$) {
        my ($dbh, $tag) = @_;

        my $sth = do_execute($dbh, "
UPDATE physicalproduct p, physicalbox b
  SET p.hw_type = 'BladeEnclosure'
  WHERE b.tag = '$tag'
    AND b.physicalproduct_id = p.physicalproduct_id") or return;

        my $rows = $sth->rows;

        if ($rows == 1) {
                $enclcnt++;
        } else {
                my $data_log = Log::Log4perl->get_logger('Data');
                $data_log->error("Trying to set $tag to BladeEnclosure, $rows rows updated");
        }
        return 1;
}

# ==========================================================================

sub set_bladeserver($$$) {
        my ($dbh, $in_enclosure, $tag) = @_;

        my $sth = do_execute($dbh, "
UPDATE physicalproduct p,physicalbox b
  SET b.in_enclosure = '$in_enclosure', p.hw_type = 'BladeServer'
  WHERE b.tag = '$tag'
    AND b.physicalproduct_id = p.physicalproduct_id") or return;

        my $rows = $sth->rows;

        if ($rows == 2) {
                $srvcnt++;
        } else {
                my $data_log = Log::Log4perl->get_logger('Data');
                $data_log->error("Trying to set $tag as BladeServer in $in_enclosure, $rows rows updated");
        }

        return 1;
}

# ==========================================================================
######
# Main
######

# Handle input values
my %options;
getopts("tl:h:s", \%options) or pod2usage(-verbose => 0);

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

my $data_log = Log::Log4perl->get_logger('Data');
my (%enclarr, %srvarr);

# Make database connection for source & target database
my $dbs = db_connect("alu_cmdb") or exit_application(2);
my $dbt = db_connect("cim") or exit_application(2);

# Create Select statement
# Get distinct relations only. Some systems are attached to more than one
# sub system. Handling these only once is enough.

my $sth = do_execute($dbs, "
SELECT DISTINCT `Full Nodename`, `Parent System`
  FROM esl_relations
  WHERE `Parent Relation Type` = 'Blade Enclosure'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
        my $blade_enclosure = $ref->{"Parent System"};
        my $blade_server = $ref->{"Full Nodename"};
        if (not (exists $enclarr{$blade_enclosure})) {
                set_enclosure($dbt, $blade_enclosure) or exit_application(2);
                $enclarr{$blade_enclosure} = 1;
        }
        if (exists $srvarr{$blade_server}) {
                $data_log->error("Blade Server $blade_server was in " . $srvarr{$blade_server} . ", try to reassign to $blade_enclosure");
        } else {
                set_bladeserver($dbt, $blade_enclosure, $blade_server) or exit_application(2);
                $srvarr{$blade_server} = $blade_enclosure;
        }

}

$dbs->disconnect;
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
