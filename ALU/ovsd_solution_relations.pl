=head1 NAME

ovsd_solution_relations - Extract Solutions Relations from OVSD.

=head1 VERSION HISTORY

version 1.1 27 February 2012 DV

=over 4

=item *

Review DB Backup processing on OVSD Servers. Apparantly one record contained two pieces of information. DB Backup processing is now removed.

=back

version 1.0 23 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Solution Relations Information from OVSD.

Approach is to work in steps:

First get the ComputerSystem to Solution Relations.

Then get the Solution to Solution Relations.

=head1 SYNOPSIS

 ovsd_solution_relations.pl [-t] [-l log_dir]

 ovsd_solution_relations.pl -h.pl    Usage
 ovsd_solution_relations.pl -h.pl 1  Usage and description of the options
 ovsd_solution_relations.pl -h.pl 2  All documentation

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
use DbUtil qw(db_connect do_execute create_record get_field);
use ALU_Util qw(exit_application val_available remove_cr fqdn_ovsd);
use Data::Dumper;

#############
# subroutines
#############

# ==========================================================================

sub get_server($$) {
  my ($dbh, $ciid) = @_;
  my ($servername);

  my $sth = do_execute($dbh, "SELECT NAME FROM ovsd_servers WHERE CIID = '$ciid'") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    $servername = $ref->{'NAME'} || "";
  } else {
    $servername = "";
  }

  return $servername;
}

# ==========================================================================
######
# Main
######
# Handle input values
my %options;
getopts("tl:h", \%options) or pod2usage(-verbose => 0);

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

my $data_log = Log::Log4perl->get_logger('Data');
my $source_system = 'OVSD' . "_" . time;
my %rels;

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

$summary_log->info("DB to Server Relation: Backup and Installed On");

my $dupl_cnt = 0;
my $rels_cnt = 0;
my ($relation);
my $left_type = "ComputerSystem";
my $right_type = "Solution";

my $sth = do_execute($dbs, "
SELECT `FROM-CIID`, `TO-CIID`, `TO-BACKUP-SERVER`
  FROM ovsd_db_rels
  WHERE (`TO-SEARCHCODE` LIKE 'HW-SVR%')
     OR ((`TO-SEARCHCODE` LIKE 'LE%') AND NOT (`TO-SEARCHCODE` LIKE 'LE-WPA%'))") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
        my $source_system_element_id = $ref->{'FROM-CIID'} || "";
        # Get Instance tag for this Installed Product
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my ($left_name, $right_name);
        defined ($right_name = get_field($dbt, "application_instance", "application_instance_tag", \@fields, \@vals)) or exit_application(2);
        if (length($right_name) == 0) {
                #       $data_log->error("No application data found for $source_system_element_id in DB relationship");
                next;
        }
        $source_system_element_id = $ref->{'TO-CIID'} || "";

        defined ($left_name = get_server($dbs, $source_system_element_id)) or exit_application(2);
        if (length($left_name) == 0) {
                # $data_log->error("Could not find servername for $source_system_element_id");
                next;
        }

# Note that BACKUP-SERVER processing is not working.
# Apparantly the 'TO-CIID' is the server on which the DB in installed
# and the BACKUP-SERVER is the backup server
# (2 pieces of info in 1 record)
#       my $backup_server = $ref->{'TO-BACKUP-SERVER'} || "";
#       if (length($backup_server) == 0) {
                $relation = "has installed";
#       } else {
#               $relation = "backup for db";
#       }
        # Now check if info is known already
        if (exists($rels{lc("$left_name*$right_name")})) {
                $dupl_cnt++;
        } else {
                my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                my $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
                $rels{lc("$left_name*$right_name")} = 1;
                $rels_cnt++;
        }
}
$summary_log->info("$rels_cnt ComputerSystem to DB relations found, $dupl_cnt duplicates");

$summary_log->info("Getting OVSD ComputerSystem with installed Solution Relations");

$dupl_cnt = 0;
$rels_cnt = 0;
$relation = "is dependent upon by";

$sth = do_execute($dbs, "
SELECT `FROM-NAME`, `FROM-CIID`, `FROM-CATEGORY`, `TO-NAME`, `TO-CIID`, `TO-CATEGORY`
  FROM ovsd_server_rels
  WHERE `FROM-CATEGORY` IN ('Cluster', 'Mainframe', 'Server', 
                            'Server Farm', 'Virtual Host', 'Virtual Server')
    AND `TO-CATEGORY` IN ('BU Managed Application', 'Custom Application', 'Database',
                          'Infrastructure Application', 'R+D Application', 'webMethods Adapter')") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        my $left_name = $ref->{'FROM-NAME'} || "";
        $left_name = fqdn_ovsd($left_name);
        my $source_system_element_id = $ref->{'TO-CIID'} || "";
        # Get Instance tag for this Installed Product
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $right_name;
        defined ($right_name = get_field($dbt, "application_instance", "application_instance_tag", \@fields, \@vals)) or exit_application(2);
        if (length($right_name) == 0) {
                my $category = $ref->{'TO-CATEGORY'} || "";
                my $name = $ref->{'TO-NAME'} || "";
                $name = remove_cr($name);
                @fields = ("source_system_element_id", "name", "category");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
#               my $issue_log_id = create_record($dbt, "issue_log", \@fields, \@vals) or exit_application(2);
#               $data_log->error("No application attributes found for $source_system_element_id in Server to Solution Relation");
                next;
        }
        # Now check if info is known already
        if (exists($rels{lc("$left_name*$right_name")})) {
                $dupl_cnt++;
# print "Duplicate: $left_name*$right_name\n";
        } else {
                my $to_category = $ref->{'TO-CATEGORY'} || "";
                if ($to_category eq 'Database') {
                        $relation = "has installed";
                } else {
                        $relation = "has depending solution";
                }
                my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                my $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
                $rels{lc("$left_name*$right_name")} = 1;
                $rels_cnt++;
        }
}

$summary_log->info("$rels_cnt ComputerSystem to Solution relations found, $dupl_cnt duplicates");

$summary_log->info("Getting Solution Depends on Database");

$left_type = "Solution";
$dupl_cnt = 0;
$rels_cnt = 0;
$relation = "depends on";

$sth = do_execute($dbs, "
SELECT `FROM-CIID`, `FROM-NAME`, `RELATIONSHIP`, `TO-CIID`, `TO-NAME`
  FROM ovsd_apps_rels
  WHERE `TO-CATEGORY` = 'Database'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        my $source_system_element_id = $ref->{'FROM-CIID'} || "";
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my ($left_name, $right_name);
        defined ($left_name = get_field($dbt, "application_instance", "application_instance_tag", \@fields, \@vals)) or exit_application(2);
        if (length($left_name) == 0) {
                # Source System Not Found...
                next;
        }
        $source_system_element_id = $ref->{'TO-CIID'} || "";
        # Get Instance tag for this Installed Product
        @fields = ("source_system_element_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        defined ($right_name = get_field($dbt, "application_instance", "application_instance_tag", \@fields, \@vals)) or exit_application(2);
        if (length($right_name) == 0) {
#               my $category = $ref->{'TO-CATEGORY'} || "";
#               my $name = $ref->{'TO-NAME'} || "";
#               @fields = ("source_system_element_id", "name", "category");
#               (@vals) = map { eval ("\$" . $_ ) } @fields;
#               my $issue_log_id = create_record($dbt, "issue_log", \@fields, \@vals) or exit_application(2);
#               $data_log->error("No application attributes found for $source_system_element_id in Server to Solution Relation");
                next;
        }
        # Now check if info is known already
        if (exists($rels{lc("$left_name*$right_name")})) {
                $dupl_cnt++;
# print "Duplicate: $left_name*$right_name\n";
        } else {
                my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                my $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
                $rels{lc("$left_name*$right_name")} = 1;
                $rels_cnt++;
        }
}

$summary_log->info("$rels_cnt Solution depends on Database relations found, $dupl_cnt duplicates");

$summary_log->info("Getting Solution Depends on Custom Application");

$dupl_cnt = 0;
$rels_cnt = 0;
$relation = "depends on";
$sth = do_execute($dbs, "
SELECT `FROM-CIID`, `TO-CIID`, `TO-NAME`
  FROM ovsd_apps_rels
  WHERE `TO-CATEGORY` = 'Custom Application'
    AND `RELATIONSHIP` = 'Depends On'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        my $source_system_element_id = $ref->{'FROM-CIID'} || "";
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my ($left_name, $right_name);
        defined ($left_name = get_field($dbt, "application_instance", "application_instance_tag", \@fields, \@vals)) or exit_application(2);
        if (length($left_name) == 0) {
                # Source System Not Found...
                next;
        }
        $source_system_element_id = $ref->{'TO-CIID'} || "";
        # Get Instance tag for this Installed Product
        @fields = ("source_system_element_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        defined ($right_name = get_field($dbt, "application_instance", "application_instance_tag", \@fields, \@vals)) or exit_application(2);
        if (length($right_name) == 0) {
#               my $category = $ref->{'TO-CATEGORY'} || "";
#               my $name = $ref->{'TO-NAME'} || "";
#               @fields = ("source_system_element_id", "name", "category");
#               (@vals) = map { eval ("\$" . $_ ) } @fields;
#               my $issue_log_id = create_record($dbt, "issue_log", \@fields, \@vals) or exit_application(2);
#               $data_log->error("No application attributes found for $source_system_element_id in Server to Solution Relation");
                next;
        }
        # Now check if info is known already
        if (exists($rels{lc("$left_name*$right_name")})) {
                $dupl_cnt++;
# print "Duplicate: $left_name*$right_name\n";
        } else {
                my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                my $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
                $rels{lc("$left_name*$right_name")} = 1;
                $rels_cnt++;
        }
}

$summary_log->info("$rels_cnt Solution depends on Custom Application relations found, $dupl_cnt duplicates");


$summary_log->info("Getting Solution 'Is Part Of' Custom Application");

# The only relation that is available in uCDMB is 'depends on' => so we use that.
# But we switch both sides , because if 'FROM' Is Part Of 'TO' (eg. a solution is part of a group of solutions)
# The we say that the group depends on the member.
# => FROM => right, TO => left


$dupl_cnt = 0;
$rels_cnt = 0;
$relation = "depends on";
$sth = do_execute($dbs, "
SELECT `FROM-CIID`, `TO-CIID`
  FROM ovsd_apps_rels
  WHERE `TO-CATEGORY` = 'Custom Application'
    AND `RELATIONSHIP` = 'Is Part Of'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {
        my $source_system_element_id = $ref->{'TO-CIID'} || "";
        my @fields = ("source_system_element_id");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my ($left_name, $right_name);
        defined ($left_name = get_field($dbt, "application_instance", "application_instance_tag", \@fields, \@vals)) or exit_application(2);
        if (length($left_name) == 0) {
                # Source System Not Found...
                next;
        }
        $source_system_element_id = $ref->{'FROM-CIID'} || "";
        # Get Instance tag for this Installed Product
        @fields = ("source_system_element_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        defined ($right_name = get_field($dbt, "application_instance", "application_instance_tag", \@fields, \@vals)) or exit_application(2);
        if (length($right_name) == 0) {
                next;
        }

        # Now check if info is known already
        if (exists($rels{lc("$left_name*$right_name")})) {
                $dupl_cnt++;
# print "Duplicate: $left_name*$right_name\n";
        } else {
                my @fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");
                my (@vals) = map { eval ("\$" . $_ ) } @fields;
                my $relations_id = create_record($dbt, "relations", \@fields, \@vals) or exit_application(2);
                $rels{lc("$left_name*$right_name")} = 1;
                $rels_cnt++;
        }
}

$summary_log->info("$rels_cnt Solution 'Is Part Of' Custom Application relations found, $dupl_cnt duplicates");


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
