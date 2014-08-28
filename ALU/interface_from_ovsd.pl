=head1 NAME

interface_from_ovsd - This script will extract the Interface Information from OVSD.

=head1 VERSION HISTORY

version 1.0 25 May 2012 PC

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Interface information from OVSD.
This script uses the normalized acronym names, to generate a unique tag for every interface.

=head1 SYNOPSIS

 interface_from_ovsd.pl [-t] [-l log_dir] [-c]

 interface_from_ovsd -h	Usage
 interface_from_ovsd -h 1  Usage and description of the options
 interface_from_ovsd -h 2  All documentation

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

# ==========================================================================

###########
# Variables
###########

my ($clear_tables);

#####
# use
#####

use warnings;			    # show warning messages
use strict;
use File::Basename;
use Carp;
use Getopt::Std;		    # Handle input params
use Pod::Usage;			    # Allow Usage information
use Log::Log4perl qw(:easy);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_prepare sth_singleton_select do_select create_record);
use Set qw(where_not_exists duplicates);

use Data::Dumper;

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
my $data_log = Log::Log4perl->get_logger('Data');

my $scriptname = basename($0,"");

$summary_log->info("Start `$scriptname' application");

# Clear data by default
$clear_tables = "Yes" unless (defined $options{"c"});

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values
# ==========================================================================

my $interface_source_id = "OVSD_".time;

# Make database connection for source database
my $dbs = db_connect('alu_cmdb') or exit_application(1);

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

# Clear tables if required
# PCO : ik zou veronderstellen dat hier enkel de tabellen staan die in dit script gevuld worden

if (defined $clear_tables) {
  my @tables = ('interface');

  foreach my $table (@tables) {

    $summary_log->info("Truncate table $table");

    unless ($dbt->do("truncate $table")) {
      ERROR("Could not truncate table `$table'. Error: ". $dbt->errstr);
      exit_application(1);
    }
  }

  # partial clean up of the relations table
  unless ($dbt->do("DELETE FROM relations WHERE left_type = 'Interface' AND right_type = 'Instance'")) {
    ERROR("Could not remove rows from relations table. Error: ". $dbt->errstr);
    exit_application(1);
  }
}

# Check on number of columns => PCO : hoezo ?
# Wat is daar het doel van ?

# Initialize WHERE values

#my @initvalues = ( 'FROM SEARCHCODE', 'TO SEARCHCODE');
#init2blank($dbs,"ovsd_interface", \@initvalues);

# opbouwen van een mapping tabel met nieuwe acronymen

# Opvullen van de tabel cim.acronym_mapping. Eerst met de door de klant aangeleverde stuff.
# In die mate dat we App ID terug vinden in cim.application.portfolio_id

unless (validate_acronym_mappings()) {
  ERROR("validate_acronym_mappings failed");
  exit_application(1);
}

=pod

=head2 Interfaces uit OVSD

Sommige interfaces komen meer dan 1 keer voor => Neem die interfaces waar from en to zoveel mogelijk ingevuld zijn.

=cut

# ID moet uniek zijn, als ik de filtering op 'FROM SEARCHCODE' en 'TO SEARCHCODE' toepas.

my $data = do_select($dbs, "
SELECT ID
  FROM ovsd_interface WHERE ID1 IN (SELECT T1.ID1
                                      FROM (SELECT ID1, ID, IFNULL(LENGTH(LEFT(`FROM SEARCHCODE`, 1)),0) + IFNULL(LENGTH(LEFT(`TO SEARCHCODE`, 1)),0) AS LENGTE
                                              FROM ovsd_interface) AS T1,
                                           (SELECT ID, MAX(IFNULL(LENGTH(LEFT(`FROM SEARCHCODE`, 1)),0) + IFNULL(LENGTH(LEFT(`TO SEARCHCODE`, 1)),0)) AS MAX_LENGTE
                                              FROM ovsd_interface GROUP BY ID) AS T2
                                      WHERE T1.ID = T2.ID
                                        AND T1.LENGTE = T2.MAX_LENGTE)
");

unless ($data && @$data) {
  ERROR("Could not execute ovsd_interface query, Error: ".$dbs->errstr);
  exit_application(1);
}

# controle dat deze ID wel degelijk uniek zijn.
my %seen;
map { $seen{$_}++ } map { $_->[0] } @$data;
if (my @tmp = grep { $seen{$_} != 1 } keys %seen) {
  ERROR("Some duplicate rows remain in ovsd_interface : " . join(', ', @tmp) . " ! exiting...");
  exit_application(1);
}

my $acronym_sth = do_prepare($dbt, "
SELECT AM.appl_name_normalized_acronym
  FROM application_instance AI LEFT OUTER JOIN acronym_mapping AM
    ON AI.application_id = AM.application_id
  WHERE AI.ovsd_searchcode = ?");

unless ($acronym_sth) {
  ERROR("Could not prepare acronym mapping query, Error: ".$acronym_sth->errstr);
  exit_application(1);
}

my $instance_sth = do_prepare($dbt, "
SELECT application_instance_tag
  FROM application_instance
  WHERE ovsd_searchcode = ?");

unless ($instance_sth) {
  ERROR("Could not prepare instance query, Error: ".$instance_sth->errstr);
  exit_application(1);
}

# Nu deze data ophalen en overhevelen naar CIM database.
my $interface_sth = do_prepare($dbs, "
SELECT ID, SEARCH_CODE, `FROM SEARCHCODE`, `TO SEARCHCODE`, CATEGORY, NAME, DESCRIPTION_4000,
       `APPLICATION  INTERFACE_DATA`, `APPLICATION INTERFACE_PARTNERS`,
       `APPLICATION INTERFACE_TECHNOLOGY`, INTERFACE_EXTERNAL_INPUT, INTERFACE_EXTERNAL_OUTPUT
  FROM ovsd_interface WHERE ID1 IN (SELECT T1.ID1
                                      FROM (SELECT ID1, ID, IFNULL(LENGTH(LEFT(`FROM SEARCHCODE`, 1)),0) + IFNULL(LENGTH(LEFT(`TO SEARCHCODE`, 1)),0) AS LENGTE
                                              FROM ovsd_interface) AS T1,
                                           (SELECT ID, MAX(IFNULL(LENGTH(LEFT(`FROM SEARCHCODE`, 1)),0) + IFNULL(LENGTH(LEFT(`TO SEARCHCODE`, 1)),0)) AS MAX_LENGTE
                                              FROM ovsd_interface GROUP BY ID) AS T2
                                      WHERE T1.ID = T2.ID
                                        AND T1.LENGTE <=> T2.MAX_LENGTE)
");

unless ($interface_sth) {
  ERROR("Could not prepare ovsd_interface query, Error: ".$dbs->errstr);
  exit_application(1);
}

my $rv = $interface_sth->execute();
if (not defined $rv) {
  ERROR("Could not ovsd_interface query, Error: ".$interface_sth->errstr);
  exit_application(1);
}


my @interface_fields = ('interface_tag', 'source_system_element_id', 'ovsd_searchcode',
                        'application_category', 'appl_name_long', 'appl_name_description',
                        'interface_data', 'interface_partners', 'interface_technology',
                        'interface_external_input', 'interface_external_output');

my @relation_fields = ("source_system", "left_type", "left_name", "relation", "right_name", "right_type");

my $interface_tags;

while (my $ref = $interface_sth->fetchrow_hashref) {
  my $source_system_element_id = $ref->{ID} || '';
  my $ovsd_searchcode = $ref->{SEARCH_CODE} || '';
  my $application_category = $ref->{CATEGORY} || '';
  my $appl_name_long = $ref->{NAME} || '';
  my $appl_name_description = $ref->{DESCRIPTION_4000} || '';
  my $interface_data = $ref->{'APPLICATION  INTERFACE_DATA'} || '';
  my $interface_partners = $ref->{'APPLICATION INTERFACE_PARTNERS'} || '';
  my $interface_technology = $ref->{'APPLICATION INTERFACE_TECHNOLOGY'} || '';
  my $interface_external_input = $ref->{INTERFACE_EXTERNAL_INPUT} || '';
  my $interface_external_output = $ref->{INTERFACE_EXTERNAL_OUTPUT} || '';

  # search code vertalen via cim.application_instance.application_id -> cim.acronym_mapping
  my $acronyms;

  foreach my $key (('FROM SEARCHCODE', 'TO SEARCHCODE')) {
    my $value = $ref->{$key};

    if (defined $value && $value ne '') {
      my $data = sth_singleton_select($acronym_sth, $ref->{$key});

      unless ($data && @$data && $data->[0]->[0]) {
        my $sc = $ref->{$key};
        $data_log->error("Could not find acronym for searchcode `$sc'");
        $acronyms->{$key} = 'UNKNOWN_SEARCHCODE'
      }
      else {
        $acronyms->{$key} = $data->[0]->[0];
      }
    }
    else {
      # This means the search code field is not filled in in the sheet.
      $acronyms->{$key} = 'MISSING_SEARCHCODE';
    }
  }

  my $tag = $acronyms->{'FROM SEARCHCODE'} . '-' . $acronyms->{'TO SEARCHCODE'};

  $interface_tags->{$tag}++;

  my $purpose = sprintf("%02d", $interface_tags->{$tag});

  my $interface_tag = "${tag}-${purpose}:int:alu";

  my (@vals) = map { eval ("\$" . $_ ) } @interface_fields;
  my $interface_id = create_record($dbt, "interface", \@interface_fields, \@vals);

  ##
  ## Nu opvullen van de relations tabel
  ##

  # search codes linken aan application_interface_tag (voor opvullen van de relations tabel)

  my $ai_tags;

  foreach my $key (('FROM SEARCHCODE', 'TO SEARCHCODE')) {
    my $value = $ref->{$key};

    if (defined $value && $value ne '') {
      my $data = sth_singleton_select($instance_sth, $ref->{$key});

      unless ($data && @$data) {
        my $sc = $ref->{$key};
        $data_log->error("Could not find application_interface_tag for searchcode `$sc'");
        $ai_tags->{$key} = 'UNKNOWN_SEARCHCODE'
      }
      else {
        $ai_tags->{$key} = $data->[0]->[0];
      }
    }
    else {
      $ai_tags->{$key} = 'MISSING_SEARCHCODE';
    }
  }

  my $source_system = $interface_source_id;

  # Q: volgens mij moet from en to omgewisseld worden
  # In relations gekeken en de relaties gaan telkens van 1 -> N, bv. 1 ComputerSystem has N depending Solutions.
  # Dus application_instance sends to/receives from interface.
  # maar de interface data kijkt natuurlijk vanuit het standpunt van de interface.
  # Antwoord Dirk : niet omwisselen, wil relaties zien vanuit het standpunt van de interface.

  my $relation_names = { 'FROM SEARCHCODE' => 'receives from', 'TO SEARCHCODE' => 'sends to' };

  foreach my $key (('FROM SEARCHCODE', 'TO SEARCHCODE')) {
    my $left_type = 'Interface';
    my $left_name = $interface_tag;

    my $right_type = 'Instance';
    my $right_name = $ai_tags->{$key};

    my $relation = $relation_names->{$key};

    my (@vals) = map { eval ("\$" . $_ ) } @relation_fields;
    my $relations_id = create_record($dbt, "relations", \@relation_fields, \@vals);
  }
}


$dbs->disconnect;
$dbt->disconnect;
$summary_log->info("Exit application with success");
exit(0);

# ==========================================================================

#############
# subroutines
#############

# ==========================================================================

=head2 validate_acronym_mappings

Mapping controleren van ovsd searchcodes naar application acronymen. Deze mapping komen uit de tabel
cim.acronym_mapping.

=cut

sub validate_acronym_mappings {

  my $data_log = Log::Log4perl->get_logger('Data');

  # CHECK 1:
  # check relatie tussen application en application_instance
  # wat ik moet doen als ik er zo vind ? => stoppen volgens mij
  {
    my $cim_data = do_select($dbt, "
SELECT Q1.application_instance_id
  FROM (SELECT AI.application_instance_id, A.application_id
  FROM application_instance AI LEFT OUTER JOIN application A
  ON AI.application_id = A.application_id) Q1
WHERE Q1.application_id IS NULL");

    if (@$cim_data) {
      $data_log->error("Some application_instance rows have no relation with an application");
      foreach (@$cim_data) {
        my $col = $_->[0];

        $data_log->error("application_instance.application_instance_id: $col");
      }
    }
  }

  # ophalen alle search codes uit de bron
  # ALU_CMDB database
  my $alu_cmdb_data = do_select($dbs, "
SELECT DISTINCT SC
FROM (SELECT distinct `FROM SEARCHCODE` AS SC FROM ovsd_interface WHERE `FROM SEARCHCODE` IS NOT NULL AND `FROM SEARCHCODE` != ''
        UNION
      SELECT distinct `TO SEARCHCODE` AS SC FROM ovsd_interface WHERE `TO SEARCHCODE` IS NOT NULL AND `TO SEARCHCODE` != '') Q1");

  unless ($alu_cmdb_data) {
    ERROR("Could not execute query. Error: ".$dbs->errstr);
    return;
  }

  #print Dumper($alu_cmdb_data);

  my @alu_search_codes = map { $_->[0] } @{ $alu_cmdb_data };

  # Dat levert ongeveer 150 search codes op => 'IN' statement op query in de target database te doen.

  # CHECK 2:
  # Zijn alle search codes gekend in de application_instance tabel.
  my $missing_search_codes;

  {

    my $in_set = join(', ', map { "'$_'" } @alu_search_codes);
    #print Dumper($in_set);

    my $cim_data = do_select($dbt, "
SELECT AI.ovsd_searchcode
  FROM application_instance AI
  WHERE AI.ovsd_searchcode IN ($in_set)");

    #print Dumper($cim_data);

    # check of we voor elke search code wel een application hebben
    if (@alu_search_codes != @$cim_data) {
      $data_log->warn("Not every search code is available in cim database !");

      my @missing = where_not_exists([ @alu_search_codes ], [ map {  $_->[0] } @{ $cim_data }]);

      foreach (@missing) {
        $data_log->warn("Search code `$_' is missing in application_instance.ovsd_searchcode");
        $missing_search_codes->{$_}++;
      }
    }
  }

  @alu_search_codes = grep { ! exists $missing_search_codes->{$_} } @alu_search_codes;

  # CHECK 3:
  ## Soms verwijzen search codes naar een verkeerd cim.application.application_type (moet 'Application' zijn)

  my $invalid_search_codes;

  {

    my $in_set = join(', ', map { "'$_'" } @alu_search_codes);
    #print Dumper($in_set);

    my $cim_data = do_select($dbt, "
SELECT AI.ovsd_searchcode
  FROM application_instance AI, application A
  WHERE AI.application_id = A.application_id
    AND A.application_type = 'Application'
    AND AI.ovsd_searchcode IN ($in_set)");

    #print Dumper($cim_data);

    # check of we voor elke search code wel een application hebben
    if (@alu_search_codes != @$cim_data) {
      $data_log->warn("Not every search code is for an application with application_type 'Application' !");

      my @invalid = where_not_exists([ @alu_search_codes ], [ map {  $_->[0] } @{ $cim_data }]);

      foreach (@invalid) {
        $data_log->warn("Search code `$_' has a wrong application_type");
        $invalid_search_codes->{$_}++;
      }
    }
  }

  # CHECK 4:
  # Heeft elke search code een application.appl_name_acronym

  @alu_search_codes = grep { ! exists $invalid_search_codes->{$_} } @alu_search_codes;
  #print "known_search_codes: ", Dumper(@alu_search_codes);

  my $missing_acronyms;

  {
    my $in_set = join(', ', map { "'$_'" } @alu_search_codes);
    #print Dumper($in_set);

    my $cim_data = do_select($dbt, "
SELECT AI.ovsd_searchcode, AM.appl_name_normalized_acronym
  FROM application_instance AI LEFT OUTER JOIN acronym_mapping AM
  ON AI.application_id = AM.application_id
  WHERE AI.ovsd_searchcode IN ($in_set)");

    #print Dumper($cim_data);

    # Deze check zou niet mogen falen want we hebben de probleem search codes weg gehaald.
    if (@alu_search_codes != @$cim_data) {
      ERROR("Not every search code is available in cim database. This should not happen !");
      return;
    }

    # check of elke application instance wel een acronym naam heeft

    # XXXX wat ik doe als er geen acronym is weet ik nog niet. Hoeft ook geen probleem te zijn als
    # ik het acronym vind in de klant tabel (maar dan zou het al in cim.acronym_mapping zitten !)

    if (my @missing = grep { (! defined $_->[1]) || $_->[1] eq '' } @{ $cim_data }) {

      $data_log->error("Not every search code has an acronym !");

      foreach (@missing) {
        my $sc = $_->[0];

        $data_log->error("Search code `$sc' has no acronym");
        $missing_acronyms->{$sc}++;
      }
    }

    #print Dumper($missing_acronyms);
  }

  # CHECK 5:
  # check dat elk acronym uniek is. Op zich vind ik het vreemd dat we
  # cim.application.appl_name_acronym gebruiken en niet cim.application_instance.appl_name_acronym.
  # Je zou verwachten dat je duplicates krijgt in de acronym (als dezelfde applicatie bv. 2 instances heeft)
  # XXX te vragen aan Dirk.
  # Momenteel meld ik dit alleen maar. Geen verdere actie.
  # Dirk : Geen probleem omdat interfaces er enkel zijn voor 'PRD' application instances. Er zitten
  # geen 'TST' of 'DEV' instances in de interfaces.

  {
    my $in_set = join(', ', map { "'$_'" } @alu_search_codes);
    #print Dumper($in_set);

    my $cim_data = do_select($dbt, "
SELECT AM.appl_name_normalized_acronym
  FROM application_instance AI LEFT OUTER JOIN acronym_mapping AM
  ON AI.application_id = AM.application_id
  WHERE AI.ovsd_searchcode IN ($in_set)");


    if (my @duplicate_acronyms = duplicates([ map { $_->[0] } @$cim_data ])) {
      ERROR ("The application.appl_name_acronym kolom bevat duplicates");

      foreach (@duplicate_acronyms) {
        my $col = $_;

        ERROR("Duplicate acronyms: `$col'");
      }
    }
  }

  return 1;
}

# ==========================================================================

sub exit_application {
  my ($return_code) = @_;

  if (defined $dbs) {
    $dbs->disconnect;
  }
  if (defined $dbt) {
    $dbt->disconnect;
  }
  INFO("Exit application with return code $return_code.\n");
  
  exit $return_code;
}

# ==========================================================================


=head1 To Do

=over 4

=item *

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>

=cut


