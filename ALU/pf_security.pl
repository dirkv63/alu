=head1 NAME

pf_security - Extract Security Class and Category for Portfolio Applications.

=head1 VERSION HISTORY

version 1.0 24 April 2012 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Security fields (Class and Category) from the Archer extract and add them to the Application table.

=head1 SYNOPSIS

 pf_security.pl [-t] [-l log_dir]

 pf_security -h	Usage
 pf_security -h 1  Usage and description of the options
 pf_security -h 2  All documentation

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
use DbUtil qw(db_connect do_execute rupdate_record) ;
use ALU_Util qw(exit_application rval_available);

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

$summary_log->info("Getting ALU Portfolio Security Attributes");

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(1);
my $dbt = db_connect('cim') or exit_application(1);

my $sth = do_execute($dbs, "
SELECT `Portfolio ID`, `Security Class`, `Security Category`
  FROM alu_pf_security
  WHERE `Portfolio ID` > 0") or exit_application(1);

while (my $ref = $sth->fetchrow_hashref) {
  # Application Information
  my $key = { 'portfolio_id' => $ref->{'Portfolio ID'} };
  my $record = {
                'security_class' => $ref->{'Security Class'} || '',
                'security_category' => $ref->{'Security Category'} || ''
               };

  if (rval_available($record)) {
    rupdate_record($dbt, "application", $key, $record) or exit_application(1);
  }
}

$dbs->disconnect;
$dbt->disconnect;
$summary_log->info("Exit `$scriptname' application with success");
exit(0);

=head1 To Do

=over 4

=item *

Nothing for now...

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
