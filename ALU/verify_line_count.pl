=head1 NAME

verify_line_count - This script will verify line count in Data Extract files.

=head1 VERSION HISTORY

version 1.0 02 December 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will verify the number of lines in Data File Extracts. First read the header line, and the number of lines in the header line. Then read number of lines as specified in header. Then read next line. This needs to be the trailer line. If not, raise an error.

=head1 SYNOPSIS

 verify_line_count.pl [-t] [-l log_dir] [-i ini_directory]

 verify_line_count.pl -h    Usage
 verify_line_count.pl -h 1  Usage and description of the options
 verify_line_count.pl -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=item B<-i ini_directory>

Alternative location of the ini-file (normally in the properties folder of the current directory)

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -c, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
###########

my $run = 'DEFAULT';

#####
# use
#####

use warnings;                       # show warning messages
use strict;
use File::Basename;
use File::Spec;
use Getopt::Std;                    # Handle input params
use Pod::Usage;                     # Allow Usage information
use Log::Log4perl qw(:easy);
use LogUtil qw(setup_logging);
use IniUtil qw(load_alu_ini);
use ALU_Util qw(exit_application);

#############
# subroutines
#############

# ==========================================================================

sub handle_file($) {
        my ($filename) = @_;

  my $summary_log = Log::Log4perl->get_logger('Summary');

        my ($prev_line);
        my $line_cnt = 0;
        $summary_log->info ("Investigating $filename");
        my $openres = open(File, $filename);
        if (not defined $openres) {
                ERROR("Cannot open $filename for reading");
                return;
        }
        # Read Header line
        my $line = <File>;
        # Then count number of lines
        while ($line = <File>) {
                if (index($line, "EOR") == -1) {
                        ERROR("No EOR in file $filename");
                        $line_cnt = -1;
                        last;
                }
                $line_cnt++;
                # Remember last valid line
                $prev_line = $line;
        }
        # Check if EOF reached, or EOR error encountered.
        if ($line_cnt > 0) {
                # Now verify if line_cnt is number of lines specified
                # Subtract 1 from line count to remove trailer line.
                $line_cnt--;
                my ($id, $tot, $rep_lines, $eor) = split /\|/, $prev_line;
                if (not ($line_cnt == $rep_lines)) {
                        ERROR("$line_cnt lines counted, $rep_lines reported in $filename");
                }
        }
        close File;
        return;
}

# ==========================================================================

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

Log::Log4perl->easy_init($ERROR);

## Read the alu.ini file
my $ini_attr;
$ini_attr->{ini_folder} = $options{i} if (defined $options{i});
my $alu_cfg = load_alu_ini($ini_attr) or do { ERROR("Failed to parse ALU ini-file !"); exit(2) };

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

## Read from the alu.ini file
unless ($alu_cfg->SectionExists($run)) { ERROR("Run `$run' does not exists in alu.ini !"); exit(2); }
my $filedir = $alu_cfg->val($run, 'DS_STEP1') or do { ERROR("DS_STEP1 missing in [$run] section in alu.ini !"); exit(2) };

if (not(opendir(DIR, $filedir))) {
        ERROR("Could not open directory $filedir, exiting...");
        exit_application(2);
}

my @filelist = readdir(DIR);
foreach my $filename (@filelist) {
        # Handle only .csv files
        if (index($filename, ".csv") > 0) {
                handle_file(File::Spec->catfile($filedir, $filename));
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
