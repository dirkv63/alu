=head1 NAME

esl_instance_handling - This file will handle the ESL Instance Report.

=head1 VERSION HISTORY

version 1.0 15 September 2011 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will create the esl_instance_work table from the esl_instance table.

=head1 SYNOPSIS

 esl_instance_handling.pl [-t] [-l log_dir] 

 esl_instance_handling -h	Usage
 esl_instance_handling -h 1  Usage and description of the options
 esl_instance_handling -h 2  All documentation

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
use DbUtil qw(db_connect do_stmt);
use ALU_Util qw(exit_application);

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

# Make database connection for source database
my $dbs = db_connect('alu_cmdb') or exit_application(1);

my $orig_table = "esl_instance";
my $work_table = "esl_instance_work";

$summary_log->info("Remove work copy of the table");

# First REMOVE a work copy of the table if it exists
do_stmt($dbs, "DROP TABLE IF EXISTS $work_table") or exit_application(1);

$summary_log->info("Create work copy of the table");

# Then create a work copy of the table
do_stmt($dbs, "
CREATE TABLE `$work_table` ENGINE=MyISAM CHARSET=utf8
  SELECT * FROM $orig_table") or exit_application(1);

# PCO : I think this is not needed any more. Null lines are not loaded any more in the first place.
$summary_log->info("Remove NULL Lines from table");

# Remove NULL Lines from table
do_stmt($dbs, "DELETE FROM $work_table WHERE `Solution ID` is NULL") or exit_application(1);

$summary_log->info("Rename fields");

# Rename Fields
# Define Field Names
my %fieldname = (
                 "Field10" => "Solution Customer Instance Owner",
                 "Field11" => "Solution Customer Instance Support",
                 "Field13" => "Solution Delivery Instance Owner",
                 "Field14" => "Solution Delivery Instance Support",
                 "<I><font color=green>or </font></I>Solution Name <I>(free-text)<" => "Solution Name"
                );

# Now rename the fields
while (my ($c_field, $n_field) = each %fieldname) {
  #change_field($dbs, $work_table, $c_field, $n_field);

  do_stmt($dbs, "
ALTER TABLE `$work_table`
  CHANGE  `$c_field` `$n_field` VARCHAR(255)
  NULL DEFAULT NULL") or exit_application(1);
}

$dbs->disconnect;
$summary_log->info("Exit `$scriptname' application with success");
exit(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
