=head1 NAME

a7_all_relations - This script will work on ALL Relations File.

=head1 VERSION HISTORY

version 1.1 04 November 2011 DV

=over 4

=item *

Add and populate Logical CI Type for Local CI.

=back

version 1.0 24 October 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will remove from the relations file all CI Classes that are not in scope for data migration.

Also only relations with "Reason (*_ Distant CI)" NULL are kept. All other relations are about no longer used CIs, so should not be taken into account.

Data will be published in a new relations file a7_all_relations_work.

=head1 SYNOPSIS

 a7_all_relations.pl [-t] [-l log_dir]

 a7_all_relations.pl -h Usage
 a7_all_relations.pl -h 1  Usage and description of the options
 a7_all_relations.pl -h 2  All documentation

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

use warnings;                       # show warning messages
use strict;
use File::Basename;
use Getopt::Std;                    # Handle input params
use Pod::Usage;                     # Allow Usage information
use Log::Log4perl qw(:easy);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_stmt);
use ALU_Util qw(exit_application);

#############
# subroutines
#############

######
# Main
######

# Handle input values
my %options;
getopts("tl:h:c", \%options) or pod2usage(-verbose => 0);

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
my $level = 0;
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

# Make database connection for source database
my $dbs = db_connect('alu_cmdb') or exit_application(1);

# First REMOVE a work copy of the table if it exists
do_stmt($dbs,"DROP TABLE IF EXISTS a7_all_relations_work") or exit_application(1);

# Then create work physical server - logical server and solutions relations
do_stmt($dbs, "
        CREATE TABLE `a7_all_relations_work` ENGINE=MyISAM CHARSET=utf8
                SELECT * FROM a7_all_relations
                WHERE `Reason (*_ Distant CI)` is NULL
                AND `Field9` is NULL
        AND ((`*_ CI class (*_ Distant CI)` like 'SOL%') OR
                     (`*_ CI class (*_ Distant CI)` like 'SRV%') OR
                         (`*_ CI class (*_ Distant CI)` like 'STO%'))
                AND ((`Full name (*_ Local CI*_ Category)` like '/INFRASTRUCTURE/SERVER%') OR
                         (`Full name (*_ Local CI*_ Category)` like '/INFRASTRUCTURE/STORAGE%') OR
                         (`Full name (*_ Local CI*_ Category)` like '/SOLUTIONS%'))
                AND (`*_ Relation type` not like 'OVSD%')") or exit_application(1);

do_stmt($dbs,"ALTER TABLE  `a7_all_relations_work` ADD  `* Logical CI type (*_ Local CI)` VARCHAR( 50 ) NULL") or exit_application(1);

# Add Logical CI Type for Local CI
do_stmt($dbs,"
        UPDATE a7_all_relations_work, a7_servers
        SET `* Logical CI type (*_ Local CI)` = `* Logical CI type`
        WHERE `Asset tag (*_ Local CI)` = `Asset tag`") or exit_application(1);

# Remove Relations that where one of the Components is not "In Use"
do_stmt($dbs,"
        DELETE FROM a7_all_relations_work
        WHERE NOT ((`*_ Status (*_ Distant CI)`= 'In Use') AND
                   (`*_ Status (*_ Local CI)`= 'In Use'))") or exit_application(1);

$dbs->disconnect;
$summary_log->info("Exit `$scriptname' application with success");
exit(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
