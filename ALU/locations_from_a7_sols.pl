=head1 NAME

locations_from_a7_sols - Extract Location information from A7 Solutions.

=head1 VERSION HISTORY

version 1.0 09 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract location information from A7 Solutions. This will be done in some steps.

=over 4

=item *

Empty Location tables detailedlocation, location and address.

=item *

Extract distinct location / address information from ESL Location table. Add data into location and address tables.

=item *

Extract detailed location information per system. Remember source_system_element_id, since Location information can be used for hardware boxes, computersystems and applications.

=item *

Do not clean location records that are not referenced from the source system. This can be done from the Extract script.

=back

=head1 SYNOPSIS

 locations_from_a7_sols.pl [-t] [-l log_dir] [-c]

 locations_from_a7_sols.pl -h    Usage
 locations_from_a7_sols.pl -h 1  Usage and description of the options
 locations_from_a7_sols.pl -h 2  All documentation

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
use DbUtil qw(db_connect do_execute do_stmt create_record get_field);
use ALU_Util qw(exit_application val_available);
use Data::Dumper;

#############
# subroutines
#############

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

my $data_log = Log::Log4perl->get_logger('Data');

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("detailedlocation") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

# Get distinct Location / Address values
my $sth = do_execute($dbs, "
SELECT distinct `Country (* Location)`, `City (* Location)`, `Full name (* Location)`
  FROM a7_solutions
  WHERE `Country (* Location)` is not null") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # Location data
        my $location_code = $ref->{"Full name (* Location)"} || "";
        my @fields = ("location_code");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $location_id;
        defined ($location_id = get_field($dbt, "location", "location_id", \@fields, \@vals)) or exit_application(2);
        if (length($location_id) == 0) {
                # New Location, add address first
                # Address data
                my ($address_id);
                my $city = $ref->{"City (* Location)"} || "";
                my $country = $ref->{"Country (* Location)"} || "";
                @fields = ("city", "country");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                if ( val_available(\@vals) eq "Yes") {
                        $address_id = create_record($dbt, "address", \@fields, \@vals) or exit_application(2);
                } else {
                        $data_log->error("Trying to create address record, but no data available.");
                        $address_id = 1;
                }
                @fields = ("location_code", "address_id");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                if ( val_available(\@vals) eq "Yes") {
                        $location_id = create_record($dbt, "location", \@fields, \@vals) or exit_application(2);
                } else {
                        $data_log->error("Trying to create location record, but no data available.");
                }
        }
}

# Now add Detailed Location data for each CI
$sth = do_execute($dbs, "
SELECT `Full name (* Location)`, `Asset tag`
  FROM a7_solutions
  WHERE `Country (* Location)` IS NOT NULL") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        my ($detailedlocation_id);
        my $source_system_element_id = $ref->{"Asset tag"} || "";
        my $location_code = $ref->{"Full name (* Location)"} || "";
        my @fields = ("location_code");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $location_id;
        defined ($location_id = get_field($dbt, "location", "location_id", \@fields, \@vals)) or exit_application(2);
        @fields = ("source_system_element_id", "location_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $location_id = create_record($dbt, "detailedlocation", \@fields, \@vals) or exit_application(2);
        } else {
                ERROR("Trying to create detailedlocation record, but no data available. Exiting...");
                exit_application(2);
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
