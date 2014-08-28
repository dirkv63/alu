=head1 NAME

pf_generate - Generate stable and unique portfolio-id's for those business applications that don't have one
              and add unique, stable, clean and normalized acronyms to every application that needs it.

=head1 VERSION HISTORY

version 1.0 13 August 2012 PCO

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script wil generate a stable and unique portfolio-id for the business applications that don't
have a portfolio-id. There are about 300 OVSD business applications without a portfolio-id, about 40
AssetCenter applications and about 160 ESL applications.

This script will also add a unique, stable, clean and normalized acronym to every application that needs it.

The cim.application table has a column to store the acronym name that comes from the source system.
Contrary to the portfolio id's, the acronyms that come from the source often have duplicates.
We generate unique acronyms, but can not store them in the same column, because we want to keep the
acronym from the source system.

Also the acronyms must follow certain rules (eg. only lowercase), so sometimes the acronyms from the
source are invalid.

Therefore a second table is made to store this information (we could as well have added an extra
column to the application table).

This unique, stable and normalized acronym is then used to generate the name for the interfaces
between two applications. This is currently only used for OVSD.

We run this script every time the cim.application table is expanded with new rows, coming from a new
source system.


=head1 SYNOPSIS

 pf_generate.pl [-t] [-l log_dir]

 pf_generate.pl -h	   Usage
 pf_generate.pl -h 1  Usage and description of the options
 pf_generate.pl -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -c, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

#####
# use
#####

use warnings;			    # show warning messages
use strict;
use File::Basename;
use Getopt::Std;		    # Handle input params
use Pod::Usage;			    # Allow Usage information
use Log::Log4perl qw(:easy);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_execute do_select rupdate_record create_record) ;
use ALU_Util qw(exit_application generate_portfolio_id reserve_acronym_name use_acronym_name normalize_acronym is_normalized_acronym is_acronym_name_used all_uuids add_unique_acronym_name get_uuid add_uuid);
use Data::Dumper;

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

my $data_log = Log::Log4perl->get_logger('Data');

$summary_log->info("Generating Portfolio-ID's");

# Make database connection for source & target database
my $dbs = db_connect('alu_cmdb') or exit_application(2);
my $dbt = db_connect('cim') or exit_application(2);

##
## Portfolio handling
##

# Select all the distinct portfolio-id's from the source system(s)
# The portfolio-id generator should never return one of those values or we have a conflict with the source system(s).

{
  my $source_pf_id;

  my $pf_data = do_select($dbs, "
SELECT DISTINCT `App ID`
  FROM pf
  WHERE (`App ID` <> '' AND `App ID` IS NOT NULL)") or exit_application(2);

  map { $source_pf_id->{$_->[0]}++ } @$pf_data;

  my $acronym_data = do_select($dbs, "
SELECT DISTINCT `App ID`
  FROM alu_acronym_mapping
  WHERE (`App ID` <> '' AND `App ID` IS NOT NULL)") or exit_application(2);

  map { $source_pf_id->{$_->[0]}++ } @$acronym_data;

  # There are still other sources that contain portfolio-id's. So it is still possible that the
  # generated portfolio-id is in conflict with a portfolio-id from a source system, but the odds are
  # limited because the generated portfolio-id's are in the range 0001 - 9999.

  my $source_pf_id_list = [ keys %$source_pf_id ];

  my $sth = do_execute($dbt, "
SELECT application_id, application_tag, source_system
  FROM application
  WHERE application_type = 'Application'
    AND (portfolio_id = '' or portfolio_id IS NULL)") or exit_application(2);

  my $source_system_counter;
  my $source_system_range;

  while (my $ref = $sth->fetchrow_hashref) {

    my $application_id = $ref->{'application_id'};
    my $application_tag = $ref->{'application_tag'};

    # The application_id is an auto-generated key. It should always be defined !
    unless (defined $application_id) {
      ERROR("Query returns an application without an ID !");
      exit_application(2);
    }

    # Application tag is needed as a key to find the generated portfolio-id's.
    unless (defined $application_tag) {
      $data_log->error("Application `$application_id' has no application_tag. Skipping this application !");
      next;
    }

    my $source_system = $ref->{'source_system'} || 'UNKNOWN_SOURCE_SYSTEM';

    $source_system_counter->{$source_system}++;

    my $id = generate_portfolio_id($dbt, $application_tag, $source_pf_id_list) or exit_application(2);

    $source_system_range->{$source_system}->{MIN} = 99999 unless defined $source_system_range->{$source_system}->{MIN};
    $source_system_range->{$source_system}->{MAX} = 0 unless defined $source_system_range->{$source_system}->{MAX};

    $source_system_range->{$source_system}->{MIN} = $id if ($id < $source_system_range->{$source_system}->{MIN});
    $source_system_range->{$source_system}->{MAX} = $id if ($id > $source_system_range->{$source_system}->{MAX});

    $data_log->debug("Generated portfolio ID for application `$application_tag' = $id");

    # undef it, so we don't pass it to generate_portfolio_id a second time (this should be a little bit faster)
    $source_pf_id_list = undef;

    my $key = { 'application_id' => $application_id };
    my $record = { 'portfolio_id' => $id };

    rupdate_record($dbt, "application", $key, $record) or exit_application(2);
  }

  # Report what we've done
  foreach my $source_system (keys %$source_system_counter) {
    my $cnt = $source_system_counter->{$source_system};

    my $min = $source_system_range->{$source_system}->{MIN};
    my $max = $source_system_range->{$source_system}->{MAX};

    $summary_log->info("Generated $cnt portfolio id's for source system `$source_system' (between $min and $max)");
  }
}

##
## Acronym handling
##

=pod

The logic for acronyms differs significantly from the logic for portfolio id's.

We have the following sets with portfolio id / acronym pairs (with normalized acronyms):
1) alu_cmdb.alu_acronym_mapping.App ID + alu_cmdb.alu_acronym_mapping.New Acronym
   (this data comes from source, acronyms should be normalized)

2) cim.application.portfolio_id + cim.application.appl_name_acronym (acronym possibly not normalized)
   this data comes from source, use this value as a start when we need to generate a normalized, unique acronym.

3) cim.application.portfolio_id + cim.uuid_map.uuid_value (relation : cim.application.application_tag = cim.uuid_map.application_key)
   (this is a remembered acronym, acronym should be normalized (unless rules have changed)).

   I use the application_tag as unique key because we pass application_tag + normalized acronym in
   the file master_application_renaming.csv to the TM application.

We need to fill in cim.application.portfolio_id + cim.acronym_mapping.appl_name_normalized_acronym
(relation : cim.application.application_id = cim.acronym_mapping.application_id)

Logic:

We run this script every time the cim.application table is expanded (4 times, after loading pf,
after loading ovsd, after loading a7 and after loading esl).

For all applications without a normalized acronym, we add a unique normalize acronym
- first look in the customer supplied acronyms (in the table alu_cmdb.alu_acronym_mapping), and check if this acronym is valid and unique.
- then look at the acronym in the column cim.application.appl_name_acronym.
- then see if we can find an acronym in the cim.uuid_map table (the remembered set)
- then generate a new unique normalized acronym and store it in the cim.uuid_map table (for the next run).

When we generate a new acronym, we start from the acronym we find in the column
cim.application.appl_name_acronym, and if needed we make the acronym unique by adding sequential
numbers. During this process, we exclude acronyms from the remembered set and from the customer supplied acronyms.


=cut

$summary_log->info("Generating Acronyms");

# all the apps WITH a normalized acronym
my $data = do_select($dbt, "
SELECT count(*)
  FROM application a
  WHERE a.application_type = 'Application'
    AND EXISTS (SELECT 1 FROM acronym_mapping am WHERE am.application_id = a.application_id)") or exit_application(2);

# If there a no applications with a normalized acronym, it is the first time we run => report errors
# Second time don't report the errors any more
my $initial_run = ($data->[0]->[0] == 0) ? 1 : 0;

# all the apps WITHOUT a normalized acronym
my $application_data = do_select($dbt, "
SELECT a.application_id, a.application_tag, a.portfolio_id
  FROM application a
  WHERE a.application_type = 'Application'
    AND NOT EXISTS (SELECT 1 FROM acronym_mapping am WHERE am.application_id = a.application_id)") or exit_application(2);

unless (@$application_data > 0) {
  $dbs->disconnect;
  $dbt->disconnect;
  $summary_log->info("All applications already have a valid normalized acronym");
  $summary_log->info("Exit `$scriptname' application with success");
  exit(0);
}

# at this point, every application should have a unique portfolio id (or we have a bug in our code)
foreach (@$application_data) {
  unless (defined $_->[2] && $_->[2] ne '') { ERROR("The application `$_->[1]' has a NULL portfolio_id. This is a bug"); exit_application(2); }
}

my $current_portfolio_id_set = {};

foreach (@$application_data) {
  if (++$current_portfolio_id_set->{$_->[2]} > 1) {
    $data_log->error("The portfolio_id `$_->[2]' for the application `$_->[1]' in the cim.application table is not unique !");
  }
}

my $portfolio_count = values %$current_portfolio_id_set;

$summary_log->info("There are $portfolio_count applications without a normalized acronym");

#print Dumper($current_portfolio_id_set);

# alu_cmdb.alu_acronym_mapping comes from the source system and we can not rely on this data :
# - check no duplicate App ID's (portfolio id's)
# - check no duplicate normalized acronyms
# - if any problem found, don't use these rows

# 1) alu_acronym_mapping

my $alu_acronym_mapping_set;

{
  my $data = do_select($dbs, "
SELECT `App ID`, `New Acronym`
  FROM alu_acronym_mapping") or exit_application(2);

  # put all the acronyms in the reserved set (even if it are not valid acronyms, that is not important).
  my $reserved_acronyms;
  map { $reserved_acronyms->{$_->[1]}++ } @$data;

  # mark the acronyms in use, so that we don't generate an acronym from this set.
  reserve_acronym_name([ keys %$reserved_acronyms]);

  # Basic checks
  # First check portfolio id for uniqueness
  my $unique_id;

  my $used_data = [];
  my $ignored_data = [];

  foreach (@$data) {
    push @{( (++$unique_id->{$_->[0]} > 1 ) ? $ignored_data : $used_data)}, $_;
  }

  # Check that alu_cmdb.alu_acronym_mapping.App ID is usable as key (must be unique)
  # but only report this for the initial run
  if ($initial_run && @$ignored_data) {
    $data_log->warn("The table alu_cmdb.alu_acronym_mapping contains duplicates in the column `App ID` ! The duplicates wil be ignored.");

    foreach (@$ignored_data) {
      my $id = $_->[0];
      $data_log->warn("    Ignoring duplicate App ID = $_->[0]");
    }
  }

  # Then check acronym for uniqueness
  $data = $used_data;
  my $unique_acronym;

  $used_data = [];
  $ignored_data = [];

  foreach (@$data) {
    push @{( (++$unique_acronym->{$_->[1]} > 1 ) ? $ignored_data : $used_data)}, $_;
  }

  if ($initial_run && @$ignored_data) {
    $data_log->warn("The table alu_cmdb.alu_acronym_mapping contains duplicates in the column `New Acronym` ! The duplicates wil be ignored.");

    foreach (@$ignored_data) {
      $data_log->warn("    Ignoring duplicate New Acronym = $_->[1]");
    }
  }

  # check that the acronyms are valid
  $data = $used_data;

  # all the acronyms, valid or not
  map { $alu_acronym_mapping_set->{$_->[0]} = $_->[1]; } @$data;

  if ($initial_run) {
    foreach (@$data) {
      my $msg;
      unless (is_normalized_acronym($_->[1], \$msg)) {
        # it will be normalized before use, but we expect them to be normalized already
        $data_log->error("Invalid New Acronym`$_->[1]' ($msg). This customer supplied acronym will not be used !");
      }
    }
  }
}

# 2) cim.application.portfolio_id + cim.application.appl_name_acronym

my $appl_name_acronym_set;

{
  my $data = do_select($dbt, "
SELECT portfolio_id, appl_name_acronym
  FROM application
  WHERE application_type = 'Application'") or exit_application(2);

  # put all the acronyms in the exclude set (even if it are not valid acronyms, that is not important).
  my $reserved_acronyms;

  foreach (@$data) {
    $_->[1] = lc($_->[1]);

    $reserved_acronyms->{$_->[1]}++;
  }

  #print "reserved acronyms = ", Dumper($reserved_acronyms);

  # mark the acronyms in use, so that we don't generate an acronym from this set.
  reserve_acronym_name([ keys %$reserved_acronyms]);

  # all the acronyms, valid or not
  map { $appl_name_acronym_set->{$_->[0]} = $_->[1]; } @$data;
}

# Add all previously generated and remembered acronyms to the reserved set, so that we don't generate an acronym from this set.
my $all_uuids = all_uuids($dbt, "ALU_Util::generate_acronym_name");

# mark these as in use
reserve_acronym_name($all_uuids);

# ---------------------------------------

## get the acronyms that are currently already in use. This is to build the set of unique acronyms

my $acronym_data = do_select($dbt, "
SELECT a.application_id, a.application_tag, a.portfolio_id, am.appl_name_normalized_acronym
  FROM application a, acronym_mapping am
  WHERE a.application_type = 'Application'
    AND a.application_id = am.application_id") or exit_application(2);

my $unique_acronym_set = {};

foreach (@$acronym_data) {
  next unless (defined $_->[3] && $_->[3] ne '');
  use_acronym_name($_->[3]);
}

my $acronym_report;

foreach my $row (@$application_data) {
  my ($application_id, $application_tag, $portfolio_id) = @$row;

  $acronym_report->{APPLICATION}++;

  my $source;

  # There must always be an acronym deliverd by the customer
  my $customer_acronym;

  if (exists $alu_acronym_mapping_set->{$portfolio_id}) {
    $source = 'ALU_ACRONYM_MAPPING';
    $customer_acronym = $alu_acronym_mapping_set->{$portfolio_id};
  }
  elsif (exists $appl_name_acronym_set->{$portfolio_id}) {
    $source = 'APPL_NAME_ACRONYM';
    $customer_acronym = $appl_name_acronym_set->{$portfolio_id};
  }
  else {
    $data_log->error("The application `$application_tag' has no acronym name. This should not happen !");
    # we skip this application
    next;
  }

  unless (defined $customer_acronym) {
    $data_log->error("The application `$application_tag' has no customer defined acronym name. This should not happen !");
    next;
  }

  # see if customer acronym is normalized and unique
  if (is_normalized_acronym($customer_acronym) && ! is_acronym_name_used($customer_acronym)) {

    use_acronym_name($customer_acronym);

    create_acronym_mapping($dbt, $application_id, $customer_acronym);
    $acronym_report->{$source}++;
    next;
  }

  # customer acronym is not directly usable. Did we correct this before ?
  my $remembered_acronym = get_uuid($dbt, "ALU_Util::generate_acronym_name", $application_tag);

  if (defined $remembered_acronym && is_normalized_acronym($remembered_acronym) && ! is_acronym_name_used($remembered_acronym)) {
    $source = 'UUID_TABLE';

    use_acronym_name($remembered_acronym);

    create_acronym_mapping($dbt, $application_id, $remembered_acronym);
    $acronym_report->{$source}++;

    next;
  }

  # or there was no remembered acronym or it was not usable
  # generate an valid, unique acronym starting from the customer acronym

  my $new_acronym;

  if (is_normalized_acronym($customer_acronym)) {
    $source = 'DEDUP';

    $data_log->warn("Customer supplied acronym `$customer_acronym' for application `$application_tag' is duplicate");

    $new_acronym = add_unique_acronym_name($customer_acronym);

  }
  else {
    $source = 'NORMALIZE';

    my $normalized_acronym = normalize_acronym($customer_acronym);

    $new_acronym = add_unique_acronym_name($normalized_acronym);
  }

  $acronym_report->{$source}++;

  create_acronym_mapping($dbt, $application_id, $new_acronym);

  # and store it for later
  add_uuid($dbt, "ALU_Util::generate_acronym_name", $application_tag, $new_acronym);

}

# Report what we've done
{ my $cnt = $acronym_report->{APPLICATION} || 0; $summary_log->info("We have processed $cnt applications") if ($cnt); }
{ my $cnt = $acronym_report->{ALU_ACRONYM_MAPPING} || 0; $summary_log->info("There were $cnt applications with an acronym delivered by the source") if ($cnt); }
{ my $cnt = $acronym_report->{APPL_NAME_ACRONYM} || 0; $summary_log->info("There were $cnt applications with an usable default acronym") if ($cnt); }
{ my $cnt = $acronym_report->{UUID_TABLE} || 0; $summary_log->info("There were $cnt applications with a remembered acronym") if ($cnt); }
{ my $cnt = $acronym_report->{DEDUP} || 0; $summary_log->info("There were $cnt applications where the acronym was a duplicate that was made unique") if ($cnt); }
{ my $cnt = $acronym_report->{NORMALIZE} || 0; $summary_log->info("There were $cnt applications where the acronym was normalized and made unique") if ($cnt); }

# all the remainig applications without a normalized acronym

$application_data = do_select($dbt, "
SELECT a.application_id, a.application_tag, a.portfolio_id, a.appl_name_acronym
  FROM application a
  WHERE a.application_type = 'Application'
    AND NOT EXISTS (SELECT 1 FROM acronym_mapping am WHERE am.application_id = a.application_id)") or exit_application(2);

if (@$application_data > 0) {
  my $count = @$application_data;
  $data_log->error("There are still $count applications without an acronym. This should not happen !");
}

$dbs->disconnect;
$dbt->disconnect;
$summary_log->info("Exit `$scriptname' application with success");
exit(0);

=head1 To Do

=over 4

=item *

Nothing for now...

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>

=cut

# ==========================================================================

sub create_acronym_mapping {
  my ($dbh, $application_id, $appl_name_normalized_acronym) = @_;

  my @fields = ('application_id', 'appl_name_normalized_acronym');

  my (@vals) = map { eval ("\$" . $_ ) } @fields;

  my $acronym_id = create_record($dbh, "acronym_mapping", \@fields, \@vals);

  return $acronym_id;
}

# ==========================================================================
