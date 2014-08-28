=head1 NAME

create_os_product - This script will create a OS Product Data from the operatingsystem table.

=head1 VERSION HISTORY

version 1.1 25 April 2012 DV

=over 4

=item *

Add OS Name as appl_acronym name for Product Name (bug 421). Add additional processing to extract ESL Product Name for Operating Systems.

=back

version 1.0 14 November 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract os information for the os template.

=head1 SYNOPSIS

 create_os_product.pl [-t] [-l log_dir]

 create_os_product.pl -h    Usage
 create_os_product.pl -h 1  Usage and description of the options
 create_os_product.pl -h 2  All documentation

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
use DbUtil qw(db_connect do_stmt do_execute get_recordid create_record);
use ALU_Util qw(exit_application update_record);

#############
# subroutines
#############

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

# Make database connection for target database
my $dbt = db_connect('cim') or exit_application(2);

# Clear tables if required
if (defined $clear_tables) {
  foreach my $table ("application") {
    do_stmt($dbt, "truncate $table") or exit_application(2);
  }
}

my $sth = do_execute($dbt, "
SELECT operatingsystem_id, os_name, os_version, os_patchlevel, os_language, os_type
  FROM operatingsystem") or exit_application(2);

while (my $ref = $sth->fetchrow_hashref) {

        my $operatingsystem_id = $ref->{operatingsystem_id} || "";
        my $os_name = $ref->{os_name} || "";
        my $os_version = $ref->{os_version} || "";
        my $os_patchlevel = $ref->{os_patchlevel} || "";
        my $os_language = $ref->{os_language} || "";
        my $os_type = $ref->{os_type} || "";
        my $application_tag = "$os_name * $os_version * $os_patchlevel * $os_language";
        # Check if the application tag does exist already
        my @fields = ("application_tag");
        my (@vals) = map { eval ("\$" . $_ ) } @fields;
        my $application_id;
        defined ($application_id = get_recordid($dbt, "application", \@fields, \@vals)) or exit_application(2);
        if (length($application_id) == 0) {
                # Create application
                my $appl_name_long = $os_name;
                my $appl_name_acronym = $os_name;
                # ESL OS Name - related field is stored in OS Class
                # but sometimes no info is available
                if (length($appl_name_acronym) == 0) {
                        $appl_name_acronym = $os_type;
                        if (length($appl_name_acronym) == 0) {
                                $appl_name_acronym = "Unknown but valid as agreed";
                        }
                }
                my $version = $os_version;
                my $application_category = "OS";
                my $application_type = "TechnicalProduct";
                @fields = ("application_tag", "appl_name_long", "appl_name_acronym", "version", "application_category", "application_type", "os_type");
                (@vals) = map { eval ("\$" . $_ ) } @fields;
                $application_id = create_record($dbt, "application", \@fields, \@vals) or exit_application(2);
        }
        @fields = ("operatingsystem_id", "application_id");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        update_record($dbt, "operatingsystem", \@fields, \@vals);
}

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
