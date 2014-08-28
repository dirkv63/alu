=head1 NAME

explode_instances - This script will explode Assetcenter Instances.

=head1 VERSION HISTORY

version 1.0 03 February 2012 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will explode Instances in the application_instance table and in the relations table. The Data Migration model expects Applications (Depends On) or Technical Products (Installed On). Since a Technical Product must be installed on a Computersystem, the instance name must be unique. However Source Systems do not necessarily make this split-up. One Technical Product Instance can have links to multiple ComputerSystems. This script will walk through application_instance and relations tables to make sure that each technical product instance is unique per computersystem.

First flush the relations table, to remove duplicate records.

Then in relations table, find "Computersystem - has installed" relations. For each record, create a new record with fqdn attached to the application_instance_tag.

Then create a new record in the application_instance table. This record is a copy of the record, with only a modification on the application_instance_tag field. Set the new record indicator.

Then update the 'depends on' relations in the relation table. For each occurence of the application_instance_tag, create a record with the new application_instance_tag.

As a result, each application_instance_tag from a TechnicalProductInstance is modified. Remove from the relations table the application_instance_tags that were not modified.

And finally remove the TechnicalApplicationInstance tags from application_instance table that have not been modified.

=head1 SYNOPSIS

 explode_instances.pl [-t] [-l log_dir]

 explode_instances.pl -h    Usage
 explode_instances.pl -h 1  Usage and description of the options
 explode_instances.pl -h 2  All documentation

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
use DbUtil qw(db_connect do_execute do_stmt create_record flush_table);
use ALU_Util qw(exit_application);
use Data::Dumper;

#############
# subroutines
#############

# ==========================================================================

sub create_appl_inst($$$$) {
        my ($dbt, $fqdn, $application_instance_tag_orig, $application_instance_tag_new) = @_;
        my (@fields, @vals);

        # Get record from application_instance_tag table
        my $sth = do_execute($dbt, "
SELECT *
  FROM application_instance
  WHERE application_instance_tag = '$application_instance_tag_orig'") or return;

        if (my $ref = $sth->fetchrow_hashref) {
                while (my ($key, $value) = each %$ref) {
                        if (not($key eq 'application_instance_id')) {
                                if ($key eq 'application_instance_tag') {
                                        push @fields, $key;
                                        push @vals, $application_instance_tag_new;
                                } elsif ($key eq 'explode_flag') {
                                        push @fields, $key;
                                        push @vals, "Yes";
                                } else {
                                        push @fields, $key;
                                        push @vals, $value;
                                }
                        }
                }
                my $application_instance_id = create_record($dbt, "application_instance", \@fields, \@vals) or return;
        } else {
          my $data_log = Log::Log4perl->get_logger('Data');
          $data_log->error("No record found in application_instance for tag $application_instance_tag_orig");
        }

        return 1;
}

# ==========================================================================

sub create_installed_rel($$$$) {
        my ($dbt, $fqdn, $application_instance_tag_orig, $application_instance_tag_new) = @_;
        my (@fields, @vals);
        # Get record from relation table
        my $sth = do_execute($dbt, "
SELECT *
  FROM relations
  WHERE left_name = '$fqdn'
    AND right_name = '$application_instance_tag_orig'
    AND relation = 'has installed'") or return;

        if (my $ref = $sth->fetchrow_hashref) {
                while (my ($key, $value) = each %$ref) {
                        if (not($key eq 'relations_id')) {
                                if ($key eq 'right_name') {
                                        push @fields, $key;
                                        push @vals, $application_instance_tag_new;
                                } else {
                                        push @fields, $key;
                                        push @vals, $value;
                                }
                        }
                }
                my $relations_id = create_record($dbt, "relations", \@fields, \@vals) or return;
                undef @fields;
                undef @vals;
        } else {
          my $data_log = Log::Log4perl->get_logger('Data');
          $data_log->error("No record found in relations for $fqdn - $application_instance_tag_orig");
        }
        return 1;
}

# ==========================================================================

sub create_depends_rel($$$$) {
        my ($dbt, $fqdn, $application_instance_tag_orig, $application_instance_tag_new) = @_;
        my (@fields, @vals);
        # Get record from relation table - right_name match
        my $sth = do_execute($dbt, "
SELECT *
  FROM relations
  WHERE right_name = '$application_instance_tag_orig'
    AND relation = 'depends on'") or return;

        while (my $ref = $sth->fetchrow_hashref) {
                while (my ($key, $value) = each %$ref) {
                        if (not($key eq 'relations_id')) {
                                if ($key eq 'right_name') {
                                        push @fields, $key;
                                        push @vals, $application_instance_tag_new;
                                } else {
                                        push @fields, $key;
                                        push @vals, $value;
                                }
                        }
                }
                my $relations_id = create_record($dbt, "relations", \@fields, \@vals) or return;
                undef @fields;
                undef @vals;
        }
        # Get record from relation table - left_name match
        $sth = do_execute($dbt, "
SELECT *
  FROM relations
  WHERE left_name = '$application_instance_tag_orig'
   AND relation = 'depends on'") or return;

        while (my $ref = $sth->fetchrow_hashref) {
                while (my ($key, $value) = each %$ref) {
                        if (not($key eq 'relations_id')) {
                                if ($key eq 'left_name') {
                                        push @fields, $key;
                                        push @vals, $application_instance_tag_new;
                                } else {
                                        push @fields, $key;
                                        push @vals, $value;
                                }
                        }
                }
                my $relations_id = create_record($dbt, "relations", \@fields, \@vals) or return;
                undef @fields;
                undef @vals;
        }
        return 1;
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

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(2);

$summary_log->info("Flush Relations Table");

flush_table($dbt, "relations") or exit_application(2);

$summary_log->info("Handle ComputerSystem - has installed relations");

my $sth = do_execute($dbt, "
SELECT left_name, right_name
  FROM relations
  WHERE relation = 'has installed'") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        my $fqdn = $ref->{"left_name"} || "Undefined_FQDN";
        my $application_instance_tag_orig = $ref->{"right_name"} || "Undefined_Appl_Inst";
        my $application_instance_tag_new = $application_instance_tag_orig . "." . $fqdn;
        create_appl_inst($dbt, $fqdn, $application_instance_tag_orig, $application_instance_tag_new) or exit_application(2);
        create_installed_rel($dbt, $fqdn, $application_instance_tag_orig, $application_instance_tag_new) or exit_application(2);
        create_depends_rel($dbt, $fqdn, $application_instance_tag_orig, $application_instance_tag_new) or exit_application(2);
}

$summary_log->info("Remove old application_instance relations from relations table");

do_stmt($dbt, "
DELETE FROM relations
  WHERE right_name in
    (SELECT application_instance_tag
       FROM application_instance i, application a
       WHERE explode_flag IS NULL
         AND i.application_id = a.application_id
         AND a.application_type = 'TechnicalProduct')") or exit_application(2);

do_stmt($dbt, "
DELETE FROM relations
  WHERE left_name in
    (SELECT application_instance_tag
       FROM application_instance i, application a
       WHERE explode_flag IS NULL
         AND i.application_id = a.application_id
         AND a.application_type = 'TechnicalProduct')") or exit_application(2);

$summary_log->info("Remove old application_instance relations from application_instance table");

# Set explode_flag for all records that should not be deleted
do_stmt($dbt, "
UPDATE application_instance i, application a
  SET explode_flag = 'Appl'
  WHERE explode_flag IS NULL
    AND i.application_id = a.application_id
    AND NOT (a.application_type = 'TechnicalProduct')") or exit_application(2);

# Now delete where explode flag is still null
do_stmt($dbt, "
DELETE FROM application_instance
   WHERE `explode_flag` IS NULL") or exit_application(2);

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
