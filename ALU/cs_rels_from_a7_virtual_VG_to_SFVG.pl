=head1 NAME

cs_rels_from_a7_virtual_VG_to_SFVG - This script extracts Virtual Guests to Server For Virtual Guests Relations knowledge from Assetcenter.

=head1 VERSION HISTORY

version 1.0.25 March 2012 FM

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script extracts the ComputerSystem virtual server information from Assetcenter. It uses the Asset Centre relations extract to build the relations between the Virtual Guests (Virtual machines) and Server For Virtual Guest. The results are loaded into the CIM database.

=head1 SYNOPSIS

 cs_rels_from_a7_virtual_VG_to_SFVG.pl [-t] [-l log_dir] [-c]

 cs_rels_from_a7_virtual_VG_to_SFVG.pl -h    Usage
 cs_rels_from_a7_virtual_VG_to_SFVG.pl -h 1  Usage and description of the options
 cs_rels_from_a7_virtual_VG_to_SFVG.pl -h 2  All documentation

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
use DbUtil qw(db_connect do_stmt do_execute get_recordid get_field create_record);
use ALU_Util qw(exit_application update_record val_available translate);

#############
# subroutines
#############

# ==========================================================================

sub set_virtual_info($$$$) {
        my ($dbt, $source_system_element_id, $virtualization_role, $virtualization_technology) = @_;
        # Get Computersystem ID
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $computersystem_id;
        defined ($computersystem_id = get_recordid($dbt, "computersystem", \@fields, \@vals)) or return;
        if ($computersystem_id ne "") {
                # Computersystem must exist in Assetcenter extract,
                # otherwise ignore value
                # Now check if Virtual CI Record already exist.
                # Modify virtual_role if it exist.
                # Create record, set virtual_role if it does not exist.
                @fields = ("computersystem_id");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                my $virtual_ci_id;
                defined ($virtual_ci_id = get_field($dbt, "computersystem", "virtual_ci_id", \@fields, \@vals)) or return;
                if (length($virtual_ci_id) > 0) {
                        # Update record
                        @fields = ("virtual_ci_id", "virtualization_role","virtualization_technology");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        update_record($dbt, "virtual_ci", \@fields, \@vals);
                } else {
                        # Create record
                        @fields = ("virtualization_role","virtualization_technology");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        $virtual_ci_id = create_record($dbt, "virtual_ci", \@fields, \@vals) or return;
                        # Update Virtual_id for computersystem
                        @fields = ("computersystem_id", "virtual_ci_id");
                        (@vals) = map { eval ("\$" . $_ ) } @fields;
                        update_record($dbt, "computersystem", \@fields, \@vals);
                }
        }

        return 1;
}

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

my $computersystem_source_id = "A7_".time;

# Initialize source system
my $source_system = $computersystem_source_id;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

=pod

=head2 Virtual Configurations

Virtual Guests are identified by the Logical CI Types, and processed in the computersystem_from_a7.pl.
As per the 'Logical-Virtual servers in the CMDB' document, virtual configurations are represented in Asset Center as per the following:

Logical CI Type is used to define the role of the CI.

=over 4

=item *

Logical CI Type = NULL - The CI is a physical server then a Server For Virtual Guest.

=item *

Logical CI Type = 'Virtual Server' - The CI is a virtual machine.

=item *

Logical CI Type = 'Logical Server' - The CI is a Cluster represented a group of physical servers resources.

=back

There are 3 type of clusters that can be recognized based on the `* Oper System` field:

=over 4

=item *

* Oper System = Unix Cluster

=item *

* Oper System = ESX Cluster - Describes ESX virtual environment

=item *

* Oper System = WINTEL Cluste - Describes ESX virtual environment

=back

=head3 Relations between CI

Any relation is define by 2 records in the Asset Center. If CI A impacts CI B then Asset Center will manage 2 records from the relations tables:

=over 4

=item *

A impacts B

=item *

B is impacted By A

=back

Any relation is defined by a quadruplet E<lt> Relation type, Local CI Logical Type, Distant CI Logical Type, Impact Direction E<gt> where:

=over 4

=item *

Relation type = Logical Server or Virtual Server.

=item *

Impact Direction = 'Local impacts Distant', 'Local impacted By Distant', 'Both' and 'NULL'.

=back

The relations that are taken into considerations for Virtualization are:

=over 4

=item *

E<lt>Virtual Server, NULL, Virtual Server, Local impacts DistantE<gt> OR E<lt>Virtual Server, Virtual Server, NULL, Local impacted  By DistantsE<gt>:
Both records reflects the relations between a Virtual Guest and a Server For Virtual Guest.

=item *

E<lt>Virtual Server, Logical Server, Virtual Server, Local impacts DistantE<gt> OR E<lt>Virtual Server, Virtual Server, NULL, Local impacted  By DistantsE<gt>:
Both records refects the relations between Virtual Guests and Clusters.

=item *

<Logical Server, NULL, Logical Server, Local impacts Distant> or <Logical Server, Logical Server, NULL, Local impacted By Distant>:
Both records reflects the relations between Clusters and Server For Virtual Guest.

=back

=cut

$summary_log->info("Getting Virtual Guest to Server For Virtual Guests relations");

# Initialize types
my $left_type = "ComputerSystem";
my $right_type = "ComputerSystem";

# Initialize relation
my $relation = "is virtual server on";

# Define Logical CI Types to reduce typing errors.
my $null_type = "";
my $logical_type = "Logical Server";
my $virtual_type = "Virtual Server";

# Manage the 'Virtual Guest' for 'Server For Virtual Guest'

# Select the quadruplet <Virtual Server, NULL, Virtual Server, Local impacts Distant> for 'Virtual Guest' to 'Server For Virtual Guest' relation

my $sth = do_execute($dbs, "
SELECT `Asset tag (*_ Local CI)`, `*_ Hostname / inst (*_ Local CI)`, `* Logical CI type (*_ Local CI)`, `* Oper System`,
       `Asset tag (*_ Distant CI)`, `*_ Hostname / inst (*_ Distant CI)`, `* Logical CI type (*_ Distant CI)`,
       `* Oper System (*_ Distant CI)`
  FROM a7_all_relations_work LEFT JOIN a7_servers svr2 ON `*_ Hostname / inst (*_ Local CI)` = svr2.`*_ Hostname / inst`
  WHERE `*_ Relation type` = 'Virtual Server'
    AND `* Logical CI type (*_ Local CI)` IS NULL
    AND `* Logical CI type (*_ Distant CI)` = 'Virtual Server'
    AND `*_ Impact direction` = 'Local impacts Distant'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
        # Declare variable for the relation table
        my ($relations_id, $distant_name, $local_name, $left_name, $right_name);

        # First get the fqdns for computersystems in the relation

        # Get FQDN for local computersystem.

        my $source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($right_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals)) or exit_application(2);
                if ($right_name eq "") {
                        # Only add relations for systems known in A7
                        $data_log->info("Could not find FQDN for Assettag $source_system_element_id (local)");
                        next;
                }
        }

        # Get fqdn for distant CI.

        $source_system_element_id = $ref->{'Asset tag (*_ Distant CI)'} || '';
        @fields = ("source_system_element_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                defined ($left_name = get_field($dbt, "computersystem", "fqdn", \@fields, \@vals)) or exit_application(2);
                if ($left_name eq "") {
                        # Only add relations for systems known in A7
                        $data_log->info("Could not find FQDN for Assettag $source_system_element_id (distant)");
                        next;
                }
        }

        # Insert the relation into the relation table.
        @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        if ( val_available(\@vals) eq "Yes") {
                $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
        }

        # Identify the Virtualization technology
        my $virtualization_os = $ref->{'* Oper System'} || "";

        # Map the Server For Virtual Guest to Virtualization technology from the translate table

        my $virtualtechno = translate($dbt, "cs_rels_from_a7_virtual", "virtualization_techno", $virtualization_os, "ErrMsg");

        # update the Virtual_CI table.

        # Set local_name to 'Server for Virtual Guest'
        $source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
        set_virtual_info($dbt, $source_system_element_id, "Server For Virtual Guest", $virtualtechno) or exit_application(2);

        # Set Distant_name to 'virtual guest'
        $source_system_element_id = $ref->{'Asset tag (*_ Distant CI)'} || "";
        set_virtual_info($dbt, $source_system_element_id, "Virtual Guest", $virtualtechno) or exit_application(2);
}

$dbs->disconnect;
$dbt->disconnect;
$summary_log->info("Exit `$scriptname' application with success");
exit(0);

=head1 To Do

=over 4

=item *

Nothing for now.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>fabrizio.mancuso@hp.comE<gt>
