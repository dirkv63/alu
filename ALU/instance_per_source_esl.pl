=head1 NAME

instance_per_source_esl - This script will allow to list instances per source.

=head1 VERSION HISTORY

version 1.0 1 February 2012 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will allow to list the instances per source for ESL.

=head1 SYNOPSIS

 instance_per_source_esl.pl [-t] [-l log_dir]

 instance_per_source_esl.pl -h    Usage
 instance_per_source_esl.pl -h 1  Usage and description of the options
 instance_per_source_esl.pl -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -d options).

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
use DbUtil qw(db_connect do_stmt do_execute create_record);
use ALU_Util qw(exit_application);

#############
# subroutines
#############

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

my $source = "ESL";
my $source_system = $source . "_" . time;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

$summary_log->info("Getting ESL Sub Businesses per Instance");

my $sth = do_execute($dbs, "
SELECT DISTINCT `Instance ID`, `Business`, `Sub Business Name`
  FROM esl_instance_work
  WHERE `Instance ID` IS NOT NULL
    AND NOT (`Sub Business Name` LIKE 'ALU-CMO-%')") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        my $esl_id = $ref->{'Instance ID'} || "";
        my $esl_business = $ref->{'Business'} || "";
        my $esl_subbusiness = $ref->{'Sub Business Name'} || "";
        my @fields = ("esl_id", "esl_business", "esl_subbusiness");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $compsys_esl_id = create_record($dbt, "compsys_esl", \@fields, \@vals) or exit_application(2);
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
