=head1 NAME

file_mover.pl - Move Files from and to FileSplitter directory.

=head1 VERSION HISTORY

version 1.0 02 February 2012 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will copy selected files from Source Directory to File Splitter directory, or it will copy all splitted files back to the Source Directory.

=head1 SYNOPSIS

 file_mover.pl [-t] [-l log_dir] [-f]

 file_mover -h	Usage
 file_mover -h 1  Usage and description of the options
 file_mover -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-t>

Tracing enabled, default: no tracing

=item B<-l logfile_directory>

default: d:\temp\log

=item B<-f>

From - If specified, then moves from Source to Splitter Directory. If not specified, moves from splitter directory back.

=back

=head1 SUPPORTED PLATFORMS

The script has been developed and tested on Windows XP, Perl v5.10.0, build 1005 provided by ActiveState.

The script should run unchanged on UNIX platforms as well, on condition that all directory settings are provided as input parameters (-l, -p, -c, -d options).

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
########### 

my ($logdir);
my $sourcedir = "d:/temp/alucmdb/";		# Output directory
my $delim = "|";						# Delimiter
my $insplitterdir = "d:/temp/FileRewriter/inputDir";
my $outsplitterdir = "d:/temp/FileRewriter/outputDir";
my $from_source = "No";					# Default outsplitterdir TO sourcedir
# Specify Filenames that need to be splitted
my @filenames = ("ESL_InstalledProduct", 
				 "ESL_ProductInstance",
				 "ESL_cd_appInstDependsUponCS");

#####
# use
#####

use warnings;			    # show warning messages
use strict 'vars';
use strict 'refs';
use strict 'subs';
use Getopt::Std;		    # Handle input params
use Pod::Usage;			    # Allow Usage information
use Log;
use File::Basename;
use File::Copy;

################
# Trace Warnings
################

use Carp;
$SIG{__WARN__} = sub { Carp::confess( @_ ) };

#############
# subroutines
#############

sub exit_application($) {
    my ($return_code) = @_;
	logging("Exit application with return code $return_code.\n");
    close_log();
    exit $return_code;
}

sub trim {
    my @out = @_;
    for (@out) {
        s/^\s+//;
        s/\s+$//;
    }
    return wantarray ? @out : $out[0];
}

sub handle_file($) {
	my ($filename) = @_;
	my ($prev_line);
	my $line_cnt = 0;
	logging ("Investigating $filename");
	my $openres = open(File, $filename);
	if (not defined $openres) {
		error("Cannot open $filename for reading");
		return;
	}
	# Read Header line
	my $line = <File>;
	# Then count number of lines
	while ($line = <File>) {
		if (index($line, "EOR") == -1) {
			error("No EOR in file $filename");
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
			error("$line_cnt lines counted, $rep_lines reported in $filename");
		}
	}
	close File;
	return;
}

sub filecandidate($) {
	my ($filename) = @_;
	my $file_to_move = "No";
	foreach my $filepart (@filenames) {
		if (index($filename, $filepart) > -1) {
			$file_to_move = "Yes";
			last;
		}
	}
	return $file_to_move;
}

=pod

=head2 To InSplitDir

This procedure will copy files from the source directory to the target directory. A filecandidate procedure will be called to check if the file should be copied.

=cut

sub to_insplitdir() {
	if (not(opendir (Sourcedir, $sourcedir))) {
		error("Opendir $sourcedir failed!");
		exit_application(1);
	}
	my @dirlist = readdir(Sourcedir);
	foreach my $filename (@dirlist) {
		my $file_to_move = filecandidate($filename);
		if ($file_to_move eq "Yes") {
			my $sourcefile = "$sourcedir/$filename";
			my $targetfile = "$insplitterdir/$filename";
			my $move_res = move($sourcefile, $targetfile);
			if ($move_res == 1) {
				my $msg = "Moved $sourcefile to $targetfile";
				print $msg."\n";
				logging($msg);
			} else {
				error("Couldn't move $sourcefile to $targetfile: ". $!);
				exit_application(1);
			}
		}
	}
}

sub from_outsplitdir() {
	if (not(opendir (Outsplitdir, $outsplitterdir))) {
		error("Opendir $outsplitterdir failed!");
		exit_application(1);
	}
	my @dirlist = readdir(Outsplitdir);
	foreach my $filename (@dirlist) {
		# Only move .csv files, not . .. or anything else left behind
		if (index($filename, ".csv") > -1) {
			my $sourcefile = "$outsplitterdir/$filename";
			my $targetfile = "$sourcedir/" . "ESL-" . $filename;
			my $move_res = move($sourcefile, $targetfile);
			if ($move_res == 1) {
				my $msg = "Moved $sourcefile to $targetfile";
				print $msg."\n";
				logging($msg);
			} else {
				error("Couldn't move $sourcefile to $targetfile: ". $!);
				exit_application(1);
			}
		}
	}
}

######
# Main
######

# Handle input values
my %options;
getopts("tl:h:i:f", \%options) or pod2usage(-verbose => 0);
# my $arglength = scalar keys %options;  
# if ($arglength == 0) {			# If no options specified,
#	$options{"h"} = 0;			# display usage.
#}
#Print Usage
if (defined $options{"h"}) {
    if ($options{"h"} == 0) {
        pod2usage(-verbose => 0);
    } elsif ($options{"h"} == 1) {
        pod2usage(-verbose => 1);
    } else {
		pod2usage(-verbose => 2);
	}
}
# Trace required?
if (defined $options{"t"}) {
    Log::trace_flag(1);
    trace("Trace enabled");
}
# Find log file directory
if ($options{"l"}) {
    $logdir = logdir($options{"l"});
    if (not(defined $logdir)) {
		error("Could not set $logdir as Log directory, exiting...");
		exit_application(1);
    }
} else {
    $logdir = logdir();
    if (not(defined $logdir)) {
		error("Could not find default Log directory, exiting...");
		exit_application(1);
    }
}
if (-d $logdir) {
    trace("Logdir: $logdir");
} else {
    pod2usage(-msg     => "Cannot find log directory $logdir",
	      -verbose => 0);
}
# Logdir found, start logging
open_log();
logging("Start application");
# Input directory
if (exists $options{"f"}) {
	$from_source = "Yes";	# Copy souredir TO insplitterdir
}
# Show input parameters
while (my($key, $value) = each %options) {
    logging("$key: $value");
    trace("$key: $value");
}
# End handle input values

if ($from_source eq "Yes") {
	to_insplitdir;
} else {
	from_outsplitdir;
}

exit_application(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
