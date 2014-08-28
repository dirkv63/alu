=head1 NAME

create_person - Create Person Master Data File

=head1 VERSION HISTORY

version 1.0 01 December 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will generate the Person Master Data file

=head1 SYNOPSIS

 create_person.pl [-t] [-l log_dir]

 create_person -h	Usage
 create_person -h 1  Usage and description of the options
 create_person -h 2  All documentation

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
my $version = "1222";

# output files
my ($Person);

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

# ==========================================================================

=pod

=head2 Init Outfiles

This procedure will open and initialize all data files for output. 

=cut

sub init_outfiles() {

  # Person Master File
  $Person = TM_CSV->new({ source => 'master', comp_name => 'Person', tabname => 'Component', version => $version })
    or do { ERROR("Could not open output file, exiting..."); return; };

  return 1;
}

=pod

=head2 Close OutFiles

This procedure will close all datafiles for output in an orderly fashion.

=cut

sub close_outfiles {
  # Person Master File
  $Person->close or return;

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

$summary_log->info("Create Hardware Extract for Template $template version $version");

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(1);

init_outfiles() or exit_application(1);

my $sth = do_execute($dbt, "
SELECT person_code, email, upi, firstname, lastname
  FROM person") or exit_application(1);

while (my $ref = $sth->fetchrow_hashref) {
  my $ContactID = $ref->{'person_code'} || "";
  my $E_Mail = $ref->{email} || "";
  my $ALU_ID = $ref->{upi} || "";
  my $name = $ref->{firstname} || "";
  my $surname = $ref->{lastname} || "";

  # ContactID, person, E-Mail, ALU-ID, name, surname, mobileNumber, telephoneNumber
  unless ($Person->write($ContactID, 'person', $E_Mail, $ALU_ID, $name, $surname, '', '')) { ERROR("write Person failed"); exit_application(1); }
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
