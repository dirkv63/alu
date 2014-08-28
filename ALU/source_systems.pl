=head1 NAME

source_systems - This script will collect source system files
/
=head1 VERSION HISTORY

version 1.0 02 December 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will collect the source system files.

=head1 SYNOPSIS

 source_systems.pl [-t] [-l log_dir] [-i input_directory]

 source_systems.pl -h    Usage
 source_systems.pl -h 1  Usage and description of the options
 source_systems.pl -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=item B<-i input_directory>

Specifies the directory where the extract files are stored. Default: d:/temp/alucmdb

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -c, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
########### 

my $filedir = "d:/temp/alucmdb/";		# Output directory

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
use ALU_Util qw(exit_application);

#############
# subroutines
#############

######
# Main
######
# Handle input values
my %options;
getopts("tl:h:i:", \%options) or pod2usage(-verbose => 0);

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

# Input directory
if ($options{"i"}) {
        $filedir = $options{"i"} ."/";  # Add slash to directory
        #$filedir = $options{"i"};
}

# Show input parameters
while (my($key, $value) = each %options) {
  DEBUG("$key: $value");
}

# End handle input values
# ==========================================================================

my %sources;

if (not(opendir(DIR, $filedir))) {
        ERROR("Could not open directory $filedir, exiting...");
        exit_application(2);
}

my @filelist = readdir(DIR);
foreach my $filename (@filelist) {
        # Handle only .csv files
        if (index($filename, ".csv") > 0) {
                # Get Filename components
                my @fncomps = split /_/, $filename;
                # Get source name
                my $source = shift @fncomps;
                # New source?
                if (not(exists $sources{$source})) {
                        print "$source\n";
                        $sources{$source} = 1;
                }
        }
}


$summary_log->info("Exit `$scriptname' application with success");
exit(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
