=head1 NAME

a7_solution_relations - Extract Solutions Relations from A7.

=head1 VERSION HISTORY

version 1.1 18 April 2012 DV

=over 4

=item *

Read Server Hostname and Domain Name from relation file, don't try to get it from a7_servers table. The a7_servers table doesn't have the OVSD Servers, while there are some in the relations table.

This works for Hostname from relation in Distant field, but not if OVSD Hostname is in Local field. For Local field we don't have Domain Name.

=back

version 1.0 21 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Solution Relations Information from A7.

Approach is to work in three steps:

First get Solution to Solution Relations. Read Impact Direction to understand relation. If impact direction not available, use alphabetical relation. Get Relation Type to verify if it is known.

Then get Server to Solution Relation. This is always Installed On or Depends On, depending on the Relation Type.

Then get Solution to Server Relation. This should be same handling as previous one. Review if information is available already, or if it is new information.

=head1 SYNOPSIS

 a7_solution_relations.pl [-t] [-l log_dir] [-c]

 a7_solution_relations.pl -h    Usage
 a7_solution_relations.pl -h 1  Usage and description of the options
 a7_solution_relations.pl -h 2  All documentation

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
use DbUtil qw(db_connect do_stmt do_execute create_record get_field);
use ALU_Util qw(exit_application cons_fqdn translate);
use Data::Dumper;

#############
# subroutines
#############

# ==========================================================================

sub get_fqdn($$) {
        my ($dbs, $assettag) = @_;
        my ($fqdn);
        my $sth = do_execute($dbs, "
SELECT `*_ Hostname / inst`, `* IP domain`
  FROM a7_servers
  WHERE `Asset tag` = '$assettag'") or return;
        if (my $ref = $sth->fetchrow_hashref) {
                my $hostname = $ref->{'*_ Hostname / inst'} || "";
                my $domainname = $ref->{'* IP domain'} || "";
                $fqdn = cons_fqdn($hostname, $domainname);
        } else {
                $fqdn = "";
        }

        return $fqdn;
}

# ==========================================================================

=pod

=head2 Create Appl Inst

The Application Instance is found in OVSD. Since it is needed in Assetcenter, copy it over and modify it to appear as an assetcenter Instance.

No need to worry about the Product, this is still in the application table.

=cut

sub create_appl_inst($$$$) {
        my ($dbt, $application_instance_tag, $a7_id, $source_system) = @_;
        my (@fields, @vals);
        # Get record from application_instance_tag table
        my $sth = do_execute($dbt, "
SELECT *
  FROM ovsd_application_instance
  WHERE application_instance_tag = '$application_instance_tag'") or return;

        if (my $ref = $sth->fetchrow_hashref) {
                while (my ($key, $value) = each %$ref) {
                        if (not($key eq 'application_instance_id')) {
                                if ($key eq 'source_system_element_id') {
                                        push @fields, $key;
                                        push @vals, $a7_id;
                                } elsif ($key eq 'source_system') {
                                        push @fields, $key;
                                        push @vals, $source_system;
                                } else {
                                        push @fields, $key;
                                        push @vals, $value;
                                }
                        }
                }
                my $application_instance_id = create_record($dbt, "application_instance", \@fields, \@vals) or return;
        } else {
          my $data_log = Log::Log4perl->get_logger('Data');
          $data_log->error("No record found in ovsd_application_instance for tag $application_instance_tag");
        }

        return 1;
}

# ==========================================================================

sub handle_srv_sol($$$$$) {
        my ($dbt, $fqdn, $application_instance_tag, $relation_type, $source_system) = @_;
        my ($relation);

        if (($relation_type eq "Backup") ||
                ($relation_type eq "Scheduling") ||
                ($relation_type eq "Security")) {
                $relation = "has depending solution";
        } else {
                # If Solution is ApplicationInstance, then relation is "has depending solution"
                # otherwise relation is "has installed
                my @fields = ("application_instance_tag");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                my $instance_category;
                defined ($instance_category = get_field($dbt, "application_instance", "instance_category", \@fields, \@vals)) or return;
                if (length($instance_category) == 0) {
                        my $data_log = Log::Log4perl->get_logger('Data');
                        $data_log->info("Instance Category not found for $application_instance_tag");
                        return 1;
                }
                if (lc($instance_category) eq "applicationinstance") {
                        $relation = "has depending solution";
                } else {
                        $relation = "has installed";
                }
        }
        my $left_type = "ComputerSystem";
        my $left_name = $fqdn;
        my $right_type = "Solution";
        my $right_name = $application_instance_tag;
        my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $relations_id = create_record($dbt, "relations", \@fields, \@vals) or return;


        return 1;
}

# ==========================================================================

=pod

=head2 Get Application Instance Tag

Use the Asset Tag to find the application_instance_tag in Assetcenter. In a number of cases the application instance is from OVSD. In this case the CIID happens to be in the Hostname field for Distant CIs (although only  successful for 3 cases) or in the OVSD ID for Local CIs. This field is used to find a matching Application Instance Tag in the ovsd copy.

If the record is found in OVSD, then copy it to application_instance table and modify source_system_element_id to point to Assetcenter tag.

=cut

sub get_appl_inst_tag($$$$) {
        my ($dbt, $a7_id, $ovsd_id, $source_system) = @_;

        # Try to get Assetcenter Application Instance Tag
        my $source_system_element_id = $a7_id;
        # Get Instance ID for this Installed Product
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $application_instance_tag;
        defined ($application_instance_tag = get_field($dbt, "application_instance", "application_instance_tag", \@fields, \@vals)) or return;
        if (length($application_instance_tag) == 0) {
                # Check if this is a known OVSD Application Instance
                $source_system_element_id = $ovsd_id;
                @fields = ("source_system_element_id");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                defined ($application_instance_tag = get_field($dbt, "ovsd_application_instance", "application_instance_tag", \@fields, \@vals)) or return;
                if (length($application_instance_tag) == 0) {
                        my $data_log = Log::Log4perl->get_logger('Data');
                        $data_log->info("Application Instance not found for $a7_id ($ovsd_id)");
                } else {
                        # Application Instance is found in OVSD, get it here!
                        create_appl_inst($dbt, $application_instance_tag, $a7_id, $source_system) or return;
                }
        }
        return $application_instance_tag;
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

my $source_system = "A7_" . time;
my (%rels, %unksrv);

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("relations") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

$summary_log->info("Getting A7 Solution to Solution Relations");

my ($left_name, $right_name);
my $relation = "depends on";
my $left_type = "Solution";
my $right_type = "Solution";
my $local2distant = 0;
my $distant2local = 0;
my $dirunknown = 0;
my $dupl = 0;

# Make empty SQL
my $sth = do_execute($dbs, "
SELECT `Asset tag (*_ Distant CI)`, `Asset tag (*_ Local CI)`, `*_ CI class (*_ Distant CI)`, `*_ CI class (*_ Local CI)`,
       `*_ Hostname / inst (*_ Distant CI)`, `*_ Hostname / inst (*_ Local CI)`, `*_ Relation type`, `*_ Impact direction`
  FROM a7_all_relations
  WHERE (`Reason (*_ Distant CI)` IS NULL)
    AND ((`*_ Status (*_ Distant CI)` = 'In Use') AND (`*_ Status (*_ Local CI)` = 'In Use'))
    AND ((`*_ CI class (*_ Distant CI)` LIKE 'SOL\_%') AND (`*_ CI class (*_ Local CI)` LIKE 'SOL\_%'))
	AND (1=2)
") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
        #print Dumper($ref);

        # Get the Distant Application Instance Tag
        my $a7_id = $ref->{'Asset tag (*_ Distant CI)'} || "";
        my $ovsd_id = $ref->{'*_ Hostname / inst (*_ Distant CI)'} || "";
        my $distant_tag;
        defined ($distant_tag = get_appl_inst_tag($dbt, $a7_id, $ovsd_id, $source_system)) or exit_application(2);
        if (length($distant_tag) == 0) {
                # No application Instance found, skip relation record
                next;
        }
        # Get the Local Application Instance
        $a7_id = $ref->{'Asset tag (*_ Local CI)'} || "";
        $ovsd_id = $ref->{'*_ Hostname / inst (*_ Local CI)'} || "";
        my $local_tag;
        defined ($local_tag = get_appl_inst_tag($dbt, $a7_id, $ovsd_id, $source_system)) or exit_application(2);
        if (length($local_tag) == 0) {
                next;
        }

        # A7 Solution Relation used to take 'Impact Direction' into account.
        # However this is not relevant as the target systems only know about dependencies.
        # It is important though that if there is a dependency between an application
        # and a technical product, the application is in the left part of the relation.
        # For application - application or product - product relations, sort alphabetically.
        #
        # First get distant and local Application or TechnicalProduct
        my $distant_class = $ref->{'*_ CI class (*_ Distant CI)'} || "";
        $distant_class = translate($dbt, "a7_solutions", "CI Class", $distant_class, "ErrMsg");
        my $local_class = $ref->{'*_ CI class (*_ Local CI)'} || "";
        $local_class = translate($dbt, "a7_solutions", "CI Class", $local_class, "ErrMsg");
        if ($distant_class eq $local_class) {
                # Both Applications or both Technical Products,
                # (or both in Error)
                # order alphabetically
                if ($local_tag lt $distant_tag) {
                        $left_name = $local_tag;
                        $right_name = $distant_tag;
                } else {
                        $left_name = $distant_tag;
                        $right_name = $local_tag;
                }
        } elsif (lc($distant_class) eq "application") {
                $left_name = $distant_tag;
                $right_name = $local_tag;
        } else {
                # No error handling if one of the classes is in error
                $left_name = $local_tag;
                $right_name = $distant_tag;
        }

        # Now check if info is known already
        if (exists($rels{lc("$left_name*$right_name")})) {
                $dupl++;
        } else {
                my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                my $relations_id = create_record($dbt, "relations", \@fields, \@vals);
                $rels{lc("$left_name*$right_name")} = 1;
        }
}

$summary_log->info("Distant depends on Local: $local2distant * Local depends on Distant: $distant2local * Unknown or Both (Review!): $dirunknown");
$summary_log->info("$dupl duplicate records found");
$summary_log->info("Getting A7 Server to Solution Relations");

undef %rels;
$dupl = 0;
my $new_rels = 0;
my $unksrv_cnt = 0;

# Now get Server to Solution Relations
$sth = do_execute($dbs, "
SELECT `Asset tag (*_ Distant CI)`, `Asset tag (*_ Local CI)`, `*_ Relation type`, `*_ Impact direction`, `OVSD ID (*_ Local CI)`,
       `*_ Hostname / inst (*_ Distant CI)`, `* IP domain (*_ Distant CI)`
  FROM a7_all_relations
  WHERE (`Reason (*_ Distant CI)` IS NULL)
    AND ((`*_ Status (*_ Distant CI)` = 'In Use') AND (`*_ Status (*_ Local CI)` = 'In Use'))
    AND ((`*_ CI class (*_ Distant CI)` LIKE 'SRV\_%') AND (`*_ CI class (*_ Local CI)` LIKE 'SOL\_%'))
    AND NOT (`*_ Relation type` <=> 'Monitoring')
	AND `Asset tag (*_ Local CI)` = 'SIN1455828'
	") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        my $relation = $ref->{'*_ Relation type'} || "";
        # Get the Local Application Instance Tag
        my $a7_id = $ref->{'Asset tag (*_ Local CI)'} || "";
        my $ovsd_id = $ref->{'OVSD ID (*_ Local CI)'} || "";
        my $application_instance_tag;
        defined ($application_instance_tag = get_appl_inst_tag($dbt, $a7_id, $ovsd_id, $source_system)) or exit_application(2);
        if (length($application_instance_tag) == 0) {
                next;
        }
        my $source_system_element_id = $ref->{'Asset tag (*_ Distant CI)'} || "";
        # Get FQDN for this server
        my $hostname = $ref->{'*_ Hostname / inst (*_ Distant CI)'} || "";
        my $domainname = $ref->{'* IP domain (*_ Distant CI)'} || "";
        my $fqdn = cons_fqdn($hostname, $domainname);
        # And check if fqdn is found
        if (length($fqdn) == 0) {
                if (not exists $unksrv{$source_system_element_id}) {
                        $unksrv{$source_system_element_id} = 1;
                        $unksrv_cnt++;
                }
                next;
        }
        # Now check if info is known already
        if (exists($rels{lc("$fqdn*$application_instance_tag*$relation")})) {
                $dupl++;
                $data_log->info("$fqdn*$application_instance_tag*$relation");
        } else {
                handle_srv_sol($dbt, $fqdn, $application_instance_tag, $relation, $source_system) or exit_application(2);
                $rels{lc("$fqdn*$application_instance_tag*$relation")} = 1;
                $new_rels++;
        }
}
$summary_log->info("$new_rels new relations, $dupl duplicates, $unksrv_cnt unknown servers");
$summary_log->info("Getting A7 Solution to Server Relations");

$dupl = 0;
$new_rels = 0;
$unksrv_cnt = 0;

# Now get Solution to Server Relations
$sth = do_execute($dbs, "
SELECT `Asset tag (*_ Distant CI)`, `Asset tag (*_ Local CI)`, `*_ Relation type`, `*_ Impact direction`, `*_ Hostname / inst (*_ Distant CI)`
  FROM a7_all_relations
  WHERE (`Reason (*_ Distant CI)` IS NULL)
    AND ((`*_ Status (*_ Distant CI)` = 'In Use') AND (`*_ Status (*_ Local CI)` = 'In Use'))
    AND ((`*_ CI class (*_ Distant CI)` LIKE 'SOL\_%') AND (`*_ CI class (*_ Local CI)` LIKE 'SRV\_%'))
    AND NOT (`*_ Relation type` <=> 'Monitoring')
	AND (1=2)") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        my $relation = $ref->{'*_ Relation type'} || "";
        # Get the Distant Application Instance Tag
        my $a7_id = $ref->{'Asset tag (*_ Distant CI)'} || "";
        my $ovsd_id = $ref->{'*_ Hostname / inst (*_ Distant CI)'} || "";
        my $application_instance_tag;
        defined ($application_instance_tag = get_appl_inst_tag($dbt, $a7_id, $ovsd_id, $source_system)) or exit_application(2);
        if (length($application_instance_tag) == 0) {
                next;
        }
        my $source_system_element_id = $ref->{'Asset tag (*_ Local CI)'} || "";
        # Get FQDN for this Server
        my $fqdn;
        defined ($fqdn = get_fqdn($dbs, $source_system_element_id)) or exit_application(2);
        # And check if fqdn is found
        if (length($fqdn) == 0) {
                if (not exists $unksrv{$source_system_element_id}) {
                        $unksrv{$source_system_element_id} = 1;
                        $unksrv_cnt++;
                }
                next;
        }
        # Now check if info is known already
        if (exists($rels{lc("$fqdn*$application_instance_tag*$relation")})) {
                $dupl++;
        } else {
                handle_srv_sol($dbt, $fqdn, $application_instance_tag, $relation, $source_system) or exit_application(2);
                $rels{lc("$fqdn*$application_instance_tag*$relation")} = 1;
                $new_rels++;
        }
}
$summary_log->info("$new_rels new relations, $dupl duplicates, $unksrv_cnt unknown servers");

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
