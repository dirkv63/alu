=head1 NAME

create_acronym_rename - Create Acronym Rename Master Data File

=head1 VERSION HISTORY

version 1.0 05 June 2012 PC

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will generate the Acronym Rename Master Data file

=head1 SYNOPSIS

 create_acronym_rename.pl [-t] [-l log_dir]

 create_acronym_rename -h    Usage
 create_acronym_rename -h 1  Usage and description of the options
 create_acronym_rename -h 2  All documentation

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

###########
# Variables
###########

my $template = 'reference_interface_template.xlsx';
my $version = '1222';
# output files
my ($Acronym_Rename);

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
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_execute);
use ALU_Util qw(exit_application);
use TM_CSV;
use Data::Dumper;

#############
# subroutines
#############

# ==========================================================================

=pod

=head2 Init Outfiles

This procedure will open and initialize all data files for output.

=cut

sub init_outfiles() {

  # Acronym Rename Master File
  $Acronym_Rename = TM_CSV->new({ source => 'master', comp_name => 'Application', tabname => 'Renaming', version => $version });

  unless ($Acronym_Rename) {
    ERROR("Could not open output file, exiting...");
    return;
  }

  return 1;
}

# ==========================================================================

=pod

=head2 Close OutFiles

This procedure will close all datafiles for output in an orderly fashion.

=cut

sub close_outfiles {
  # Acronym Rename Master File
  $Acronym_Rename->close or return;

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

$summary_log->info("Create Acronym Rename Extract for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

init_outfiles() or exit_application(1);

my $sth = do_execute($dbt, "
SELECT a.application_tag, am.appl_name_normalized_acronym
  FROM application a, acronym_mapping am
  WHERE a.application_id = am.application_id
") or exit_application(1);

while (my $ref = $sth->fetchrow_hashref) {
  my $ProductID = $ref->{'application_tag'} || "";
  my $New_Acronym = $ref->{appl_name_normalized_acronym} || "";

  # ProductID, New Acronym
  unless ($Acronym_Rename->write($ProductID, $New_Acronym)) {
    ERROR("write Acronym Rename Extract failed");
    exit_application(1);
  }
}

close_outfiles() or exit_application(1);

$dbt->disconnect;
$summary_log->info("Exit application with success");
exit(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
