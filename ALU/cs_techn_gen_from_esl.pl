=head1 NAME

cs_techn_gen_from_ESL - This script will extract the ComputerSystem Technical General Information from ESL.

=head1 VERSION HISTORY

version 1.0 09 August 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the ComputerSystem Technical General Information from ESL. This script needs to run first for ESL ComputerSystem.

=head1 SYNOPSIS

 cs_techn_gen_from_ESL.pl [-t] [-l log_dir] [-c] [-s]

 cs_techn_gen_from_ESL.pl -h    Usage
 cs_techn_gen_from_ESL.pl -h 1  Usage and description of the options
 cs_techn_gen_from_ESL.pl -h 2  All documentation

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
use ALU_Util qw(exit_application update_record get_virtual_esl val_available translate);

#############
# subroutines
#############

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
        # Return Value YES -> record does not exist already, continue to process and load computersystem.
        # Return Value NO  -> record does exist already, do not continue to process (do not load the computersystem).
        my ($dbt, $source_system_element_id, $subbusiness, $computersystem_source_new) = @_;
        my ($computersystem_source);

        # Get Subbusiness from computersystem
        if (exists($p_box{$source_system_element_id})) {
                $computersystem_source = $p_box{$source_system_element_id}
        } else {
                $p_box{$source_system_element_id} = $computersystem_source_new;
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
        if ((index(lc($computersystem_source), "esl-cmo martinique") > -1) &&
                (not((lc($subbusiness) eq 'cmo martinique')))) {
                # Set computersystem_source to new value
                $computersystem_source = $computersystem_source_new;
                # Update record in computersystem table
                my @fields = ("source_system_element_id", "computersystem_source");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                update_record($dbt, "computersystem", \@fields, \@vals);
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

my $computersystem_source_id = "ESL-";

# Make database connection for source & target database
my $dbs = db_connect("alu_cmdb") or exit_application(2);
my $dbt = db_connect("cim") or exit_application(2);

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("admin", "assignment", "availability", "billing", "compsys_esl", "computersystem", "contactrole", "diskspace",
                     "ip_attributes", "ip_connectivity", "maintenance_contract", "notes", "operatingsystem", "processor",
                     "remote_access_info", "servicefunction", "system_usage", "cluster", "virtual_ci", "backup") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

$summary_log->info("Process ComputerSystem records from esl_cs_techn_gen");

my $ts = time;  # Make sure only one time stamp is used for the whole process.

=pod

=head2 ComputerSystem Selection Criteria from ESL

Status: Do not select on status, accept any status for now (active, obsolete, ...)

Do not include sub business ALU-CMO-%. This is the new subbusiness configuration. The (documented as a risk) assumption is that systems are part of 'CMO Martinique'. They can be part of any ALU-CMO-%, but not exclusively part of ALU-CMO-*

Exclude System Type 'tape drive' (mail Rejane 27/03/12 18:35). These are consumables only.

=cut

# Do not read from sub business 'ALU-CMO-*'
my $sth = do_execute($dbs, "
SELECT `Full Nodename`, `Available Diskspace`, `Cluster Architecture`, `Cluster Technology`, `Local Appl Disk Space`,
       `OS Class`, `OS Disk Space`, `OS Installation Date`, `OS Language`, `OS Version`, `Patch Level`, `Patch Notes`,
       `Physical Diskspace`, `Timezone`, `Used Diskspace`, `Sub Business Name`, `System ID`, `System Model`,
       `System Type`, `Virtualization Role`, `Virtualization Technology`
  FROM esl_cs_techn_gen
  WHERE NOT (`Sub Business Name` LIKE 'ALU-CMO-%')") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        # ComputerSystem
        my ($computersystem_id,$host_type);
        my $source_system_element_id = $ref->{"System ID"} || "";
        my $subbusiness = $ref->{"Sub Business Name"} || "";
        my $computersystem_source = $computersystem_source_id . $subbusiness . "_" . $ts;
        # Get FQDN as tag name
        my $fqdn = $ref->{"Full Nodename"} || '';
        # Set physicalbox tag to FQDN
        # This will require more thinking to distinguish between physical and logical systems!
        my $physicalbox_tag = $fqdn;
        # System Type and Virtualization Role
        my $cs_type = $ref->{"System Type"} || "";
        my $v_role = $ref->{"Virtualization Role"} || "";
        my $cs_model = $ref->{"System Model"} || "";
        $host_type = translate($dbt,"computersystem", "cs_type", $cs_type, "SourceVal");
        my $isvirtual = get_virtual_esl($cs_type, $cs_model, $v_role);
        # If Computersystem is virtual, set physicalbox_tag to blank
        # and set the host_type to 'VirtualServer' if it was 'PhysicalServer'
        # otherwise leave host_type as it is.
        if ($isvirtual eq "Yes") {
                $physicalbox_tag = "";
                if ($host_type eq "PhysicalServer") {
                        $host_type = "VirtualServer";
                }
        }

        # Check if record does exist already, update sub business if required
        my $continue_to_process = handle_dupl($dbt, $source_system_element_id, $subbusiness, $computersystem_source);
        if (lc($continue_to_process) eq "no") {
                # Record does exist, so handle next record in loop
                next;
        }

        # Create ComputerSystem record ID, for further records
        my @fields = ("computersystem_source", "fqdn", "host_type", "cs_type", "isvirtual", "physicalbox_tag", "source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $computersystem_id = create_record($dbt, "computersystem", \@fields, \@vals) or exit_application(2);
                # Check if record is created
                # Record must be created now, since handle_dupl is done in previous step
                if (length($computersystem_id) == 0) {
                        ERROR("Duplicate system found, should not be the case here. Verify code :(");
                        # Stop processing this record
                        next;
                }
        } else {
                ERROR("Trying to create computersystem record, but no data available. Exiting...");
                exit_application(2);
        }

        # Cluster Attributes
        my ($cluster_id, $cluster_type);
        # In ESL, Cluster type is listed in the System Type
        if (index($cs_type, "cluster") > -1) {
                $cluster_type = $cs_type;
        } else {
                $cluster_type = "";
        }
        my $cluster_architecture = $ref->{"Cluster Architecture"} || "";
        my $cluster_technology = $ref->{"Cluster Technology"} || "";
        @fields = ("cluster_type", "cluster_architecture", "cluster_technology");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $cluster_id = create_record($dbt, "cluster", \@fields, \@vals) or exit_application(2);
        } else {
                $cluster_id = undef;
        }

        # Diskspace
        my ($diskspace_id);
        my $available_diskspace = $ref->{"Available Diskspace"} || "";
        my $local_appl_diskspace = $ref->{"Local Appl Disk Space"} || "";
        my $physical_diskspace = $ref->{"Physical Diskspace"} || "";
        my $used_diskspace = $ref->{"Used Diskspace"} || "";
        @fields = ("available_diskspace", "local_appl_diskspace", "physical_diskspace", "used_diskspace");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $diskspace_id = create_record($dbt, "diskspace", \@fields, \@vals) or exit_application(2);
        } else {
                $diskspace_id = undef;
        }

        # Operating System
        my ($operatingsystem_id);
        my $os_type = $ref->{"OS Class"} || "";
        my $os_version = $ref->{"OS Version"} || "";
        my $os_installationdate = $ref->{"OS Installation Date"} || "";
        my $os_language = $ref->{"OS Language"} || "";
        my $os_patchlevel = $ref->{"Patch Level"} || "";
        my $time_zone = $ref->{"Timezone"} || "";
        @fields = ("os_type", "os_version", "os_installationdate", "os_language", "os_patchlevel", "time_zone");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $operatingsystem_id = create_record($dbt, "operatingsystem", \@fields, \@vals) or exit_application(2);
        } else {
                $operatingsystem_id = undef;
        }

        # Owner Company
        # This is unknown in ESL, but 'HP' is the best possible guess
        # that will make life of Transformation process easier
        my $ci_owner_company = "HP";

        # Virtual CI Attributes
        my ($virtual_ci_id);
        my $virtualization_role = $ref->{"Virtualization Role"} || "";
        my $virtualization_technology = $ref->{"Virtualization Technology"} || "";
        @fields = ("virtualization_role", "virtualization_technology");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $virtual_ci_id = create_record($dbt, "virtual_ci", \@fields, \@vals) or exit_application(2);
        } else {
                $virtual_ci_id = undef;
        }


        # ComputerSystem
        @fields = ("computersystem_id", "diskspace_id", "operatingsystem_id",
                       "cluster_id", "virtual_ci_id", "ci_owner_company");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                update_record($dbt, "computersystem", \@fields, \@vals);
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
