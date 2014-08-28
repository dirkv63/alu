=head1 NAME

hw_from_esl - This script will extract the Hardware Information from ESL dump.

=head1 VERSION HISTORY

version 1.0 29 July 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Hardware information from ESL dump.

=head1 SYNOPSIS

 hw_from_esl.pl [-t] [-l log_dir] [-c] [-s]

 hw_from_esl.pl -h    Usage
 hw_from_esl.pl -h 1  Usage and description of the options
 hw_from_esl.pl -h 2  All documentation

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
my $sourcesystem = "ESL";
my $hw_tbl = "esl_hardware_extract";
my $hw_work = "temp_" . $hw_tbl;
my $asset_tbl = "esl_asset_info";

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
use ALU_Util qw(exit_application update_record get_virtual_esl val_available);

#############
# subroutines
#############

# ==========================================================================

sub create_esl_asset($$$$) {
        my ($dbh, $asset_tbl, $hw_tbl, $hw_work) = @_;

        my $summary_log = Log::Log4perl->get_logger('Summary');

        # Drop esl_asset table if it exists
        $summary_log->info("Drop table $asset_tbl");
        do_stmt($dbh, "DROP TABLE IF EXISTS $asset_tbl") or return;

        # Create Table esl_assets_info
        $summary_log->info("Create table $asset_tbl");
        do_stmt($dbh, "CREATE TABLE $asset_tbl ENGINE=MyISAM DEFAULT CHARSET=utf8
                         SELECT DISTINCT `Full Nodename`, `Asset Number`, `Asset Type`
                           FROM $hw_tbl
                           WHERE `Asset Number` IS NOT NULL;") or return;

        # Create TEMPORARY hardware table
        $summary_log->info("Create Temporary Hardware table");

        my $hw_copy = $hw_tbl . "_copy";
        do_stmt($dbh, "CREATE TEMPORARY TABLE $hw_copy ENGINE=MyISAM DEFAULT CHARSET=utf8
                         SELECT * FROM $hw_tbl") or return;

        # Remove asset info, then duplicate records from Hardware table.
        $summary_log->info("Drop columns from $hw_copy");
        do_stmt($dbh, "ALTER TABLE $hw_copy
                         DROP `Asset Number`, DROP `Asset Type`, DROP `ID`") or return;

        # Remove duplicates
        $summary_log->info("Remove duplicates from $hw_copy into $hw_work");
        do_stmt($dbh, "DROP TABLE IF EXISTS $hw_work") or return;

        do_stmt($dbh, "CREATE TEMPORARY TABLE $hw_work ENGINE=MyISAM DEFAULT CHARSET=utf8
                                SELECT DISTINCT * FROM $hw_copy") or return;

        return 1;
}

# ==========================================================================

sub get_asset_data($$$) {
        my ($dbh, $fqdn, $asset_tbl) = @_;
        my $assetnumber = "";
        my $sth = do_execute($dbh, "
SELECT `Asset Number`
  FROM $asset_tbl
  WHERE `Full Nodename` = '$fqdn'
  AND NOT (`Asset Type` <=> 'other')") or return;

        while (my $ref = $sth->fetchrow_hashref()) {
                # Note that there should be 1 row as maximum!
                # For multiple rows, an error message is displayed and the last number is taken.
                if (length($assetnumber) > 0) {
                        my $data_log = Log::Log4perl->get_logger('Data');

                        $data_log->error("Asset Info is available already for $fqdn ($assetnumber).");
                }
                $assetnumber = $ref->{'Asset Number'};
        }

        return $assetnumber;
}

# ==========================================================================

=pod

=head2 Handle Duplicate System IDs

The assumption is that a duplicate System ID comes from systems that are in more than one sub-business. If so, assumption is that one forgot to remove the CMO Martinique sub-business.

If a record is found, then assign subsystems in order: ALU-EMEA, ALU-APJ, ALU-AMS, CMO Martinique, don't change.

Don't process records further if one is found.

=cut

{

  my %p_box;

sub handle_dupl($$$$) {

        # Return Value 'Continue To Process'
        # Return Value YES -> record does not exist already, continue to process and load physicalproduct.
        # Return Value NO  -> record does exist already, do not continue to process (do not load the physicalproduct).
        my ($dbt, $source_system_element_id, $subbusiness, $source_system_new) = @_;
        my ($source_system);

        # Get Subbusiness from computersystem
        # Maintain data in a hash, this reduces processing from 8 minutes to 4 min
        if (exists($p_box{$source_system_element_id})) {
                $source_system = $p_box{$source_system_element_id}
        } else {
                $p_box{$source_system_element_id} = $source_system_new;
                # Record does not exist, so load the physicalproduct
                return "Yes";
        }

        # Record does exist already, check if we want to process the subbusiness.
        # Check if this is a usable subbusiness
        if (not ((lc($subbusiness) eq 'alu-ams') ||
                     (lc($subbusiness) eq 'alu-apj') ||
                     (lc($subbusiness) eq 'alu-emea') ||
                     (lc($subbusiness) eq 'cmo martinique'))) {
                 # The new record does not bring useful sub-business information, no further handling required
                 return "No";
        }

        # Record does exist already.
        # Update sub-business if it is now one of the FMO subbusinesses and if it was cmo martinique.
        # Ignore in all other cases.
        if ((index(lc($source_system), "esl-cmo martinique") > -1) &&
                (not((lc($subbusiness) eq 'cmo martinique')))) {
                # Set computersystem_source to new value
                $source_system = $source_system_new;
                # Update record in computersystem table
                my @fields = ("source_system_element_id", "source_system");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                update_record($dbt, "physicalbox", \@fields, \@vals);
        }

        return "No";
}

}

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

my $data_log = Log::Log4perl->get_logger('Data');

# Make database connection for source & target database
my $dbs = db_connect("alu_cmdb") or exit_application(2);
my $dbt = db_connect("cim") or exit_application(2);

# Clear tables in target database for initialization, if flag is set
if (defined $clear_tables) {
  foreach my $table ("asset", "cpu", "physicalbox", "physicalproduct") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

# Extract Asset Information from Hardware Information
# There can be multiple Asset records (depending on the Asset Type).
# Create a 1-to-many table to store the Asset information
create_esl_asset($dbs, $asset_tbl, $hw_tbl, $hw_work) or exit_application(2);

=pod

=head2 Hardware Selection Criteria

Note that the fields in the WHERE clause should not have NULL values. Replace all NULL values with blanks! (or use the NULL SAVE comparison).

Status: In Use - Only active Hardware boxes are important for Configuration Management. (However this is not implemented here but only for Assetcenter and OVSD, Status is not used in WHERE clause).

Master: All ESL Records are included.

To exclude all virtual boxes.

=cut

# Guarantee same timestamp through process
my $ts = time;

$summary_log->info("Process hardware records from $hw_work");

# Create Select statement but select on subsystem
# Do not include Sub Business Name ALU-CMO-%
my $sth = do_execute($dbs, "
SELECT `Full Nodename`, `Clock Speed`, `CPU Type`, `Installed Memory`, `Manufacturer`,
       `Number of Cores per CPU`, `Number of physical CPUs`, `Order Number`, `Processor Type`,
       `Serial Number`, `System Model`, `System Status`, `System Type`, `DC Name`, `DC Country`,
       `Virtualization Role`, `System ID`, `Physical Diskspace`, `Product Number`, `Asset Owner`, `Sub Business Name`
  FROM $hw_work
  WHERE NOT (`Sub Business Name` like 'ALU-CMO-%')") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # Check for Physical or Virtual box
        my $cs_type = $ref->{"System Type"} || "";
        my $v_role = $ref->{"Virtualization Role"} || "";
        my $cs_model = $ref->{"System Model"} || "";
        my $isvirtual = get_virtual_esl($cs_type, $cs_model, $v_role);
        # If Computersystem is virtual, set physicalbox_tag to blank
        if ($isvirtual eq "Yes") {
                next;   # Ignore record, get next record
        }

        # Physical Box
        my ($physicalbox_id);
        my $tag = $ref->{'Full Nodename'} || "";
        my $lifecyclestatus = $ref->{'System Status'} || "";
        my $owner = $ref->{"Asset Owner"} || "";
        my $subbusiness = $ref->{"Sub Business Name"} || "";
        my $source_system = $sourcesystem . "-" . $subbusiness . "_" . $ts;
        my $source_system_element_id = $ref->{"System ID"} || "";

        # Check if record does exist already, update sub business if required
        my $continue_to_process = handle_dupl($dbt, $source_system_element_id, $subbusiness, $source_system);
        if (lc($continue_to_process) eq "no") {
                # Record does exist, so handle next record in loop
                next;
        }

        # Get DetailedLocation
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $detailedlocation_id;
        defined ($detailedlocation_id = get_field($dbt, "detailedlocation", "detailedlocation_id", \@fields, \@vals)) or exit_application(2);
        if (length($detailedlocation_id) == 0) {
                $detailedlocation_id = undef;
        }

        # Asset
        my ($asset_id, $assetnumber);
        defined ($assetnumber = get_asset_data($dbs, $tag, $asset_tbl)) or exit_application(2);
        my $ordernumber = $ref->{'Order Number'} || "";
        # Create Asset
        @fields = ("assetnumber", "ordernumber");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $asset_id = create_record($dbt, "asset", \@fields, \@vals) or exit_application(2);
        } else {
                $asset_id = undef;
        }

        # CPU
        my ($cpu_id);
        my $clockspeed = $ref->{'Clock Speed'} || "";
        my $corespercpu = $ref->{'Number of Cores per CPU'} || "";
        my $numberofcpus = $ref->{'Number of physical CPUs'} || "";
        my $cpufamily = $ref->{'Processor Type'} || "";
        my $cputype = $ref->{'CPU Type'} || "";
        # Create CPU
        @fields = ("numberofcpus", "clockspeed", "corespercpu", "cpufamily", "cputype");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $cpu_id = create_record($dbt, "cpu", \@fields, \@vals) or exit_application(2);
        } else {
                $cpu_id = undef;
        }

        # Physical Product
        my ($physicalproduct_id, $hw_type);
        my $serialnumber = $ref->{'Serial Number'} || "";
        my $memcapacity = $ref->{'Installed Memory'} || "";
        my $physical_diskspace = $ref->{"Physical Diskspace"} || "";
        my $manufacturer = $ref->{'Manufacturer'} || "";
        my $model = $ref->{'System Model'} || "";
        my $partnumber = $ref->{"Product Number"} || "";
        my $vendorequipmenttype = $ref->{"System Type"} || "";
        # Get HW Type
        if ($vendorequipmenttype eq "cabinet") {
                $hw_type = "BladeEnclosure";
        } else {
                $hw_type = "Box";
        }

        # Create Physical Product
        @fields = ("serialnumber", "manufacturer", "memcapacity", "physical_diskspace", "model", "vendorequipmenttype", "partnumber", "hw_type", "cpu_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $physicalproduct_id = create_record($dbt, "physicalproduct", \@fields, \@vals)or exit_application(2);
        } else {
                $data_log->error("No physical product for physical box $source_system_element_id");
                $physicalproduct_id = undef;
        }

        # Create Physical Box
        @fields = ("source_system", "tag", "lifecyclestatus", "owner", "source_system_element_id", "physicalproduct_id", "asset_id", "detailedlocation_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $physicalbox_id = create_record($dbt, "physicalbox", \@fields, \@vals) or exit_application(2);
        } else {
                $data_log->error("No physical Box created since no data in record available!");
                next;
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
