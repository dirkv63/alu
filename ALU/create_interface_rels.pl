=head1 NAME

create_interface_rels - This script will create a TM Data File with the interaces between applications.

=head1 VERSION HISTORY

version 1.0 14 Jun 2012 PC

=over 4

=item *

Initial release.

=item *

version 1.1 17 Sep 2012 PC. Switch source and target.

=back

=head1 DESCRIPTION

This script will extract relations data for Application Files.

=head1 SYNOPSIS

 create_interface_rels.pl [-t] [-l log_dir]

 create_interface_rels -h     Usage
 create_interface_rels -h 1	Usage and description of the options
 create_interface_rels -h 2	All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are changed in the alu.ini file

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
###########

my $template = 'componentdependency_interface_template.xlsx';
my $version = "3700";

$| = 1;                         # flush output sooner


#####
# use
#####

use warnings;			    # show warning messages
use strict;
use Carp;
use Getopt::Std;		    # Handle input params
use Pod::Usage;			    # Allow Usage information
use Log::Log4perl qw(:easy);
use ALU_Util qw(replace_cr getsource);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_execute do_prepare sth_singleton_select);
use TM_CSV;
use Data::Dumper;

#############
# subroutines
#############

sub exit_application($) {
    my ($return_code) = @_;

    my $summary_log = Log::Log4perl->get_logger('Summary');
    $summary_log->info("Exit application with error code $return_code.");

    exit($return_code);
}


=head2 appInstRelationships - Interfaces between application instances

Link between ApplicationInstances. Only for OVSD.

Data comes from the tables cim.interface and cim.relation

+--------------+------------------------------+--------------------------+--------------------------------+----------------------+------------------------+--------------------------------------------------------+-------------------+--------------------+----------------------+--------------------------+---------------------------+
| interface_id | interface_tag                | source_system_element_id | ovsd_searchcode                | application_category | appl_name_long         | appl_name_description                                  | interface_data    | interface_partners | interface_technology | interface_external_input | interface_external_output |
+--------------+------------------------------+--------------------------+--------------------------------+----------------------+------------------------+--------------------------------------------------------+-------------------+--------------------+----------------------+--------------------------+---------------------------+
|            1 | allview-sap_e_box-01:int:alu | 7649                     | SW-INF-ALLVIEW/SAP-EBOX-E1P-01 | Interface            | SyncProject001(Update) | See the attached location for the BOD details http:... | Project           | None               | Webmethods           |                          |                           |
|            2 | allview-surround-01:int:alu  | 7377                     | SW-INF-ALLVIEW/SURROUND-01     | Interface            | Quote Information      | Subscribe to AddQuote BOD                              | Quote Information | None               | Webmethods           |                          |                           |

+--------------+-----------------+----------------+-------------------------------+---------------+-------------------------+------------+
| relations_id | source_system   | left_type      | left_name                     | relation      | right_name              | right_type |
+--------------+-----------------+----------------+-------------------------------+---------------+-------------------------+------------+
|            1 | OVSD_1339678317 | Interface      | allview-sap_e_box-01:int:alu  | receives from | sw-cus-allview-prd      | Instance   |
|            2 | OVSD_1339678317 | Interface      | allview-sap_e_box-01:int:alu  | sends to      | sw-cus-sap-ebox-e1p-prd | Instance   |


Beware, for every interface we have two rows in the relations table.

Beware, cim.interface is only for OVSD.

=cut

sub handle_interface {
  my ($dbt, $source) = @_;

  my $data_log = Log::Log4perl->get_logger('Data');

  # Initialize datafiles for output

  # Product Installed On ComputerSystem
  my $Interface_CSV = TM_CSV->new({ source => $source, comp_name => 'cd', tabname => 'appInstRelationships', version => $version });

  unless ($Interface_CSV) {
    ERROR("Could not open output file, exiting...");
    exit_application(1);
  }

  my $sth_from = do_prepare($dbt, "
SELECT right_name
  FROM relations
  WHERE source_system like '$source%'
    AND left_type = 'Interface'
    AND right_type = 'Instance'
    AND relation = 'receives from'
    AND left_name = ?") or return;

  my $sth_to = do_prepare($dbt, "
SELECT right_name
  FROM relations
  WHERE source_system like '$source%'
    AND left_type = 'Interface'
    AND right_type = 'Instance'
    AND relation = 'sends to'
    AND left_name = ?") or return;

  my $sth = do_execute($dbt, "
SELECT interface_id, interface_tag, source_system_element_id, ovsd_searchcode, application_category, appl_name_long, appl_name_description,
       interface_data, interface_partners, interface_technology, interface_external_input, interface_external_output
  FROM interface") or return;

  while (my $ref = $sth->fetchrow_hashref) {
    my $interface_id = $ref->{interface_id};
    my $interface_tag = $ref->{interface_tag};
    my $source_system_element_id = $ref->{source_system_element_id};
    my $ovsd_searchcode = $ref->{ovsd_searchcode};
    my $application_category = $ref->{application_category} || '';
    my $appl_name_long = $ref->{appl_name_long} || '';
    my $appl_name_description = $ref->{appl_name_description} || '';
    my $interface_data = $ref->{interface_data} || '';
    my $interface_partners = $ref->{interface_partners} || '';
    my $interface_technology = $ref->{interface_technology} || '';
    my $interface_external_input = $ref->{interface_external_input} || '';
    my $interface_external_output = $ref->{interface_external_output} || '';

    # ophalen from en to application
    mandatory($interface_tag, "interface tag is empty for interface id `$interface_id'") or next;

    my $from_row = sth_singleton_select($sth_from, $interface_tag);

    unless (defined $from_row && @$from_row) {
      $data_log->warn("No `FROM' application found for interface `$interface_id - $interface_tag'. Skipping this interface");
      next;
    }

    my $to_row = sth_singleton_select($sth_to, $interface_tag);

    unless (defined $to_row && @$to_row) {
      $data_log->warn("No `TO' application found for interface `$interface_id - $interface_tag'. Skipping this interface");
      next;
    }

    my ($from_instance) = @{$from_row->[0]};
    my ($to_instance) = @{$to_row->[0]};

    mandatory($from_instance, "'FROM' application instance is empty for interface `$interface_id - $interface_tag'") or next;
    mandatory($to_instance, "'TO' application instance is empty for interface `$interface_id - $interface_tag'") or next;
    mandatory($ovsd_searchcode, "OVSD searchcode is empty for interface `$interface_id - $interface_tag'") or next;

    # data is vuil (bevat soms ^M). Zouden we dat niet beter bij het laden van de tabel com.interface opkuisen ?

    $appl_name_long = replace_cr($appl_name_long);
    $appl_name_description = replace_cr($appl_name_description);
    $interface_data = replace_cr($interface_data);
    $interface_partners = replace_cr($interface_partners);
    $interface_technology = replace_cr($interface_technology);
    $interface_external_input = replace_cr($interface_external_input);
    $interface_external_output = replace_cr($interface_external_output);

    # SourceApplicationInstanceID, TargetApplicationInstanceID, uid, searchCode, type, name,
    # description, contentDescription,partner, technology, externalInput,externalOutput,
    # Environment, SystemStatus, outsourced_to

    # we leave Environment empty, (it will be defaulted in the java app to production)
	# - however, this didn't happen in java app so defaulting to production is done here.
    # we leave outsourced_to empty, (it will be defaulted in the java app)

    # these are values of the system_status_int enum (New, Active or Inactive)
    my $SystemStatus = ($application_category =~ m/Archived\s+CIs/i) ? 'Inactive' : 'Active';

    # 17/9/2012: switch from and to. Will see if is stays that way.
    unless ($Interface_CSV->write($to_instance, $from_instance, $interface_tag, $ovsd_searchcode,
                                  $application_category, $appl_name_long, $appl_name_description,
                                  $interface_data, $interface_partners, $interface_technology,
                                  $interface_external_input, $interface_external_output,
                                  'Production', $SystemStatus, '')) {
      ERROR("write Interface_CSV failed");
    }
  }

  # close all datafiles for output in an orderly fashion.
  $Interface_CSV->close or return;

  return 1;
}

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

$summary_log->info("Start application");

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values

# ==========================================================================

$summary_log->info("Create Application Interfaces for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

# Get Source system for Installed Application
my $sourcearr = getsource($dbt, "relations", "source_system");

unless ($sourcearr) {
  ERROR("Found no sources in the relations table !");
  exit_application(1);
}

if (not(@$sourcearr == 1)) {
  ERROR("Found multiple sources (" . join(', ', @$sourcearr) . "), only one expected");
  exit_application(1);
}

foreach my $source (@$sourcearr) {

  $summary_log->info("Processing cd_appInstRelationships data for Source $source");

  unless ($source =~ m/ovsd/i) {
      $summary_log->info("Intertace is only for OVSD. Doing nothing for `$source'.");
      next;
  }

  # Handle the Interface relation between Application Instances
  handle_interface($dbt, $source) or exit_application(1);
}

$dbt->disconnect;
$summary_log->info("Exit application with success");
exit(0);

# ==========================================================================

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>

=cut

# ==========================================================================

sub mandatory {
  my ($value, $msg) = @_;

  unless (defined $value && $value ne "") {
    my $data_log = Log::Log4perl->get_logger('Data');

    $data_log->warn($msg);
    return;
  }

  return 1;
}

# ==========================================================================
