=head1 NAME

cs_rels_from_esl - Extract Relations from ESL.

=head1 VERSION HISTORY

version 1.0 19 October 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Relations from ESL. Note that System to System Relations can go across Sub-business boundaries, so there should be one relations file only.

Cluster Node Primary and Cluster Node Alternate relations are the first ones to extract.

=head1 SYNOPSIS

 cs_rels_from_esl.pl [-t] [-l log_dir] [-c]

 cs_rels_from_esl.pl -h    Usage
 cs_rels_from_esl.pl -h 1  Usage and description of the options
 cs_rels_from_esl.pl -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=item B<-c>

If specified, then do NOT clear tables in CIM before populating them.

=item B<-s>

Specifies to run script for CMO or FMO ESL Data. If specified, then ESL ALU subbusiness data is extracted, otherwise ESL CMO data is extracted.
For the moment this does not work.

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -c, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
###########

my $clear_tables;

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
use ALU_Util qw(exit_application val_available);

#############
# subroutines
#############

# ==========================================================================
######
# Main
######

# Handle input values
my %options;
getopts("tl:h:cs", \%options) or pod2usage(-verbose => 0);

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

# Clear data
if (not defined $options{"c"}) {
        $clear_tables = "Yes";
}

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values
# ==========================================================================

my $source_system_id = "ESL_" . time;

# Make database connection for source & target database
my $dbs = db_connect("alu_cmdb") or exit_application(2);
my $dbt = db_connect("cim") or exit_application(2);

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("relations") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

my $left_type = "ComputerSystem";
my $right_type = "ComputerSystem";
my $source_system = $source_system_id;

$summary_log->info("Get Cluster Relations");

my $sth = do_execute($dbs, "
SELECT `Full Nodename`, `Parent System`, `Parent Relation Type`
  FROM esl_relations
  WHERE `Parent Relation Type` like 'Cluster%'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        my ($relations_id);
        my $left_name = $ref->{"Full Nodename"} || "";
        my $right_name = $ref->{"Parent System"} || "";
        my $relation = $ref->{"Parent Relation Type"} || "";
        my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
        } else {
                ERROR("Trying to create relation record, but no data available. Exiting...");
                exit_application(2);
        }

}

$summary_log->info("Get Virtual Environment Relations");

$sth = do_execute($dbs, "
SELECT `Full Nodename`, `Parent System`, `Parent Relation Type`
  FROM esl_relations
  WHERE `Parent Relation Type` LIKE '%Farm%'
     OR `Parent Relation Type` LIKE '%Virtual%'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        my ($relations_id);
        my $left_name = $ref->{"Full Nodename"} || "";
        my $right_name = $ref->{"Parent System"} || "";
        my $relation = $ref->{"Parent Relation Type"} || "";
        my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
        } else {
                ERROR("Trying to create relation record, but no data available. Exiting...");
                exit_application(1);
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
