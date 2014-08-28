=head1 NAME

pf_handling - Portfolio Handling Script

=head1 VERSION HISTORY

version 1.1 29 February 2012 DV

=over 4

=item *

Add NSA and Business Criticallity indicator

=back

version 1.0 30 January 2012 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will consolidate the 3 portfolio Tables into a single pf table.

=head1 SYNOPSIS

 pf_handling.pl [-t] [-l log_dir]

 pf_handling -h	Usage
 pf_handling -h 1  Usage and description of the options
 pf_handling -h 2  All documentation

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

# Make database connection for source database
my $dbs = db_connect('alu_cmdb') or exit_application(1);

# First REMOVE a work copy of the table if it exists
do_stmt($dbs, "DROP TABLE IF EXISTS pf") or exit_application(1);

# Then create table from pf_is_it_mgd
# We also add an auto increment column, that will later be used for the source_system_element_id
do_stmt($dbs, "
CREATE TABLE pf (`ID` int(11) NOT NULL AUTO_INCREMENT, source VARCHAR(255), PRIMARY KEY (`ID`)) ENGINE=MyISAM DEFAULT CHARSET=utf8
  SELECT NULL AS ID, `App ID`, `App Acronym`, `App Name`, `App Desc`,
         'pf_is_it_mgd' AS source, `Sourcing Accountable`, `NSA Indicator`, `Business Critical App Identification`
    FROM pf_is_it_mgd") or exit_application(1);

# Add data from pf_business_mgd
do_stmt($dbs, "
INSERT INTO pf
  SELECT NULL AS ID, `App ID`, `App Acronym`, `App Name`, `App Desc`,
         'pf_business_mgd', `Sourcing Accountable`, `NSA Indicator`, `Business Critical App Identification`
    FROM pf_business_mgd") or exit_application(1);

# Add data from pf_it_other
do_stmt($dbs, "
INSERT INTO pf
  SELECT NULL AS ID, `App ID`, `App Acronym`, `App Name`, `App Desc`,
         'pf_it_other', `Sourcing Accountable`, `NSA Indicator`, `Business Critical App Identification`
    FROM pf_it_other") or exit_application(1);

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
