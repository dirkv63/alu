=head1 NAME

a7_to_esl_solution - A7 to ESL Solution translation table.

=head1 VERSION HISTORY

version 1.0 17 August 2012 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will extract the Assetcenter (Oper System) to ESL Solution and Category table from the translation table.

Each Assetcenter technical product is identified by the product in field 'Oper System'. This product is translated into an ESL Solution name and ESL Solution Category. The script will get this information from the translation table.

=head1 SYNOPSIS

 a7_to_esl_solution.pl [-t] [-l log_dir] 
 a7_to_esl_solution -h	Usage
 a7_to_esl_solution -h 1  Usage and description of the options
 a7_to_esl_solution -h 2  All documentation

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

my ($dbt, $summary_log, $data_log);

#####
# use
#####

use warnings;			    # show warning messages
use strict 'vars';
use strict 'refs';
use strict 'subs';
use Getopt::Std;		    # Handle input params
use Pod::Usage;			    # Allow Usage information
use Log::Log4perl qw(:easy);
use LogUtil qw(setup_logging);
use DbUtil qw(db_connect do_stmt create_record);
use ALU_Util qw(get_field trim update_record);

#############
# subroutines
#############

sub exit_application($) {
    my ($return_code) = @_;
	if (defined $dbt) {
		$dbt->disconnect;
	}

	$summary_log->info("Exit application with return code $return_code.\n");
    exit $return_code;
}

######
# Main
######

# Handle input values
my %options;
getopts("tl:h:i:", \%options) or pod2usage(-verbose => 0);
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

# Get Properties Directory
my $opt_ini;
if (defined $options{"i"}) {
	$opt_ini = $options{"i"};
} else {
	$opt_ini = "C:/Temp/artifacts/trunk/analysisdeliverables/sourceprep/ALU";
}
# Trace and Log processing
my $level = 0;
# Trace required?
$level = 3 if (defined $options{"t"});
my $attr = { level => $level };	# HashRef, not a hash
$attr->{ini_folder} = $opt_ini;
# Find log file directory
$attr->{logdir} = $options{"l"} if ($options{"l"});
setup_logging($attr);
$summary_log = Log::Log4perl->get_logger('Summary');
$data_log = Log::Log4perl->get_logger('Data');
$summary_log->info("Start application");
# Show input parameters
while (my($key, $value) = each %options) {
    DEBUG("$key: $value");
}
# End handle input values


# Make database connection for target database
$dbt = db_connect("cim") or exit_application(1);

# Drop table if exists
my $query = "DROP TABLE IF EXISTS a7_to_esl_sols";
do_stmt($dbt, $query) or exit_application(1);

# Create table
$query = "CREATE TABLE `a7_to_esl_sols` (
			`oper system` varchar(255) DEFAULT NULL,
			`esl solution` varchar(255) DEFAULT NULL,
			`esl category` varchar(255) DEFAULT NULL
			) ENGINE=MyISAM CHARSET=utf8";
do_stmt($dbt, $query) or exit_application(1);

# Populate with A7 Solutions and ESL Solutions
$query = "INSERT INTO a7_to_esl_sols (`oper system`, `esl solution`)
		  SELECT src_value, tx_value FROM translation 
		  WHERE component = 'a7_solutions' AND attribute = 'Oper System'";
do_stmt($dbt, $query) or exit_application(1);

# and get ESL Categories
$query = "UPDATE a7_to_esl_sols a, translation t
		  SET a.`esl category` = t.tx_value
		  WHERE a.`esl solution` = t.src_value
		    AND t.component = 'ESL Solution'
			AND t.attribute = 'Category'";
do_stmt($dbt, $query) or exit_application(1);

exit_application(0);

=head1 To Do

=over 4

=item *

Count number of distinct records. For now the assumption is that the table only has unique records.

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
