=head1 NAME

locations_from_esl - Extract Location information from ESL.

=head1 VERSION HISTORY

version 1.0 12 October 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract location information from ESL. This will be done in some steps.

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

 locations_from_esl.pl [-t] [-l log_dir] [-c]

 locations_from_esl.pl -h    Usage
 locations_from_esl.pl -h 1  Usage and description of the options
 locations_from_esl.pl -h 2  All documentation

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

# Timezone translation
my (%txzones);
$txzones{"GMT"} = "(GMT) Greenwich Mean Time : Dublin, Edinburgh, Lisbon, London";
$txzones{"GMT+1"} = "(GMT+01:00) Brussels, Copenhagen, Madrid, Paris";
$txzones{"GMT+2"} = "(GMT+02:00) Athens, Bucharest, Istanbul";
$txzones{"GMT+3"} = "(GMT+03:00) Moscow, St. Petersburg, Volgograd";
$txzones{"GMT+3.5"} = "(GMT+03:30) Tehran";
$txzones{"GMT+4"} = "(GMT+04:00) Abu Dhabi, Muscat";
$txzones{"GMT+5"} = "(GMT+05:00) Islamabad, Karachi, Tashkent";
$txzones{"GMT+5.5"} = "(GMT+05:30) Chennai, Kolkata, Mumbai, New Delhi";
$txzones{"GMT+6"} = "(GMT+06:00) Almaty, Novosibirsk";
$txzones{"GMT+7"} = "(GMT+07:00) Bangkok, Hanoi, Jakarta";
$txzones{"GMT+8"} = "(GMT+08:00) Kuala Lumpur, Singapore";
$txzones{"GMT+9"} = "(GMT+09:00) Osaka, Sapporo, Tokyo";
$txzones{"GMT+10"} = "(GMT+10:00) Canberra, Melbourne, Sydney";
$txzones{"GMT+12"} = "(GMT+12:00) Fiji, Kamchatka, Marshall Is.";
$txzones{"GMT-3"} = "(GMT-03:00) Buenos Aires, Georgetown";
$txzones{"GMT-4"} = "(GMT-04:00) Caracas, La Paz";
$txzones{"GMT-5"} = "(GMT-05:00) Bogota, Lima, Quito, Rio Branco";
$txzones{"GMT-6"} = "(GMT-06:00) Central Time (US & Canada)";
$txzones{"GMT-7"} = "(GMT-07:00) Mountain Time (US & Canada)";
$txzones{"GMT-8"} = "(GMT-08:00) Tijuana, Baja California";

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
use DbUtil qw(db_connect do_stmt do_execute create_record get_field);
use ALU_Util qw(exit_application val_available replace_cr);
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
  foreach my $table ("address", "detailedlocation", "location") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

# Get distinct Location / Address values

my $sth = do_execute($dbs, "
SELECT DISTINCT `DC Name`, `DC Owner`, `DC Category`, `DC Tier`, `DC Timezone`, `DC Country`, `DC Country ISO Code`,
                `DC Country ISO Name`, `DC Post Code`, `DC Town`, `DC Street`, `DC Building`, `DC Floor`, `Full Shipping Address`,
                `DC Notes`, `DC Access`
  FROM esl_locations") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # Location data
        my $location_code = $ref->{"DC Name"} || "";
        my @fields = ("location_code");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $location_id;
        defined ($location_id = get_field($dbt, "location", "location_id", \@fields, \@vals)) or exit_application(2);
        if (length($location_id) == 0) {
                # New Location, add address first
                # Address data
                my ($address_id);
                my $city = $ref->{"DC Town"} || "";
                my $country = $ref->{"DC Country"} || "";
                my $country_iso_code = $ref->{"DC Country ISO Code"} || "";
                my $country_iso_name = $ref->{"DC Country ISO Name"} || "";
                my $full_shipping_address = $ref->{"Full Shipping Address"} || "";
                $full_shipping_address = replace_cr($full_shipping_address);
                my $streetaddress = $ref->{"DC Street"} || "";
                my $zip = $ref->{"DC Post Code"} || "";
                my $building = $ref->{"DC Building"} || "";
                my $floor = $ref->{"DC Floor"} || "";
                @fields = ("city", "country", "country_iso_code", "country_iso_name", "full_shipping_address", "state_province", "streetaddress", "zip", "building", "floor");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                if ( val_available(\@vals) eq "Yes") {
                        $address_id = create_record($dbt, "address", \@fields, \@vals)or exit_application(2);
                } else {
                        $data_log->error("Trying to create address record, but no data available.");
                        $address_id = 1;
                }
                # Then add Location Data
                my $location_access = $ref->{"DC Access"} || "";
                my $location_category = $ref->{"DC Category"} || "";
                my $location_notes = $ref->{"DC Notes"} || "";
                my $location_owner = $ref->{"DC Owner"} || "";
                my $location_tier = $ref->{"DC Tier"} || "";
                my $time_zone = $ref->{"DC Timezone"} || "";
                if ((length($time_zone) > 0) && (exists($txzones{$time_zone}))) {
                        $time_zone = $txzones{$time_zone};
                }
                @fields = ("location_access", "location_category", "location_code", "location_notes", "location_owner", "location_tier", "time_zone", "address_id");
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
SELECT `Full Nodename`, `Floor Space/Slot`, `DC Name`, `System ID`
  FROM esl_locations") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        my ($detailedlocation_id);
        my $source_system_element_id = $ref->{"System ID"} || "";
        my $object_name = $ref->{"Full Nodename"} || "";
        my $floor_slot = $ref->{"Floor Space/Slot"} || "";
        my $location_code = $ref->{"DC Name"} || "";
        my @fields = ("location_code");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $location_id;
        defined ($location_id = get_field($dbt, "location", "location_id", \@fields, \@vals)) or exit_application(2);
        @fields = ("source_system_element_id", "object_name", "floor_slot", "location_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $location_id = create_record($dbt, "detailedlocation", \@fields, \@vals) or exit_application(2);
        } else {
                ERROR("Trying to create detailedlocation record, but no data available. Exiting...");
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
