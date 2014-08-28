#!/usr/bin/perl
# ==========================================================================
# $Source$
# $Author$ [pauwel]
# $Date$
# CDate: Mon Jun 11 14:10:46 2012
# $Revision$
#
# ==========================================================================
#
# ident "$Id$"
#
# ==========================================================================

=pod
    
    Basic validation of the ESL source files
    - validation of the header line
    - check the header line against alu_cmdb => neen, want die hoeft nog niet te bestaan, de check gebeurt zo snel mogelijk in de flow.
    - check nr of rows
    
    De file cs_service_level.csv wordt niet (meer ?) gebruikt
    
=cut
    
use strict;
use Getopt::Long;
use File::Basename;
use File::Glob qw(:glob);
use File::Spec;
use Log::Log4perl qw(:easy);

use Text::CSV_XS;
use Spreadsheet::ParseExcel::Recursive;
use Spreadsheet::ParseExcel::Fmt8Bit;
use IniUtil qw(load_alu_ini);
use Set qw(where_not_exists);
use ALU_Util qw(validate_row_count);
use Data::Dumper;

# ==========================================================================

use vars qw($scriptname $opt_help);
use vars qw($opt_verbose);
use vars qw($opt_ini);

sub usage
{
    die "@_" . "Try '$scriptname -h' for more information\n" if @_;
    
    die "Usage:
   $scriptname [OPTION] RUN

  --help|-h            display this help and exit

  --verbose|-v         guess what

  --ini|-i DIR         alternative location of the ini files (normally in the properties folder of
                       the current directory)

Validate incoming esl data files. RUN is the symbolic name for the specific run, that can be found
in the ini file.

";
}

# ==========================================================================

$scriptname = basename($0,"");

$| = 1;                         # flush output sooner

# ==========================================================================

my @GetOptArgv;
push @GetOptArgv, "verbose|v";
push @GetOptArgv, "ini|i=s";
GetOptions("help|h|?", @GetOptArgv) or usage "Illegal option : ";

usage if $main::opt_help;

@ARGV = map { bsd_glob($_, GLOB_NOCHECK | GLOB_NOCASE) } @ARGV if @ARGV;

# XXX usage "Need at least one argument !\n" if @ARGV < 1;
usage "Need one argument !\n" if @ARGV != 1;

my $run = $ARGV[0];

Log::Log4perl->easy_init($WARN);

## Read the alu.ini file
my $ini_attr;
$ini_attr->{ini_folder} = $opt_ini if ($opt_ini);
my $alu_cfg = load_alu_ini($ini_attr) or do { ERROR("Failed to parse ALU ini-file !"); exit(2) };

# ==========================================================================

## Read from the alu.ini file
unless ($alu_cfg->SectionExists($run)) { ERROR("Run `$run' does not exists in alu.ini !"); exit(2); }
my $ds_step = $alu_cfg->val($run, 'DS_STEP0') or do { ERROR("DS_STEP0 missing in [$run] section in alu.ini !"); exit(2) };

my $tables = esl_tables();

my $err_cnt = 0;
foreach my $table (@$tables) {
    my $csv_file = $table;

    my $columns = esl_table_columns($table);

    #print Dumper($columns);
    
    $csv_file .= '.csv' unless ($csv_file =~ m/\.csv$/i);
    
    $csv_file = File::Spec->catfile($ds_step, $csv_file);
    my $bfile = basename($csv_file);
    
    print "Validating csv file $csv_file ...\n";
    
    my $ioref = new IO::File;
    
    unless ($ioref->open("< $csv_file")) {
        warn("ERROR: open `$csv_file' failed : $^E\n");
        $err_cnt++;
        next;
    }
    
    my $csv = Text::CSV_XS->new ({ always_quote => 1, blank_is_undef => 1, binary => 1, quote_null => 0, eol => "\n" })
        or die "".Text::CSV_XS->error_diag ();
    
    binmode $ioref, ':encoding(ISO-8859-1)';
    
    # direct de header lezen ?
    
    my $colref = $csv->getline($ioref);
    
    # laatste kolom is telkens undef (er staat een komma teveel)
    if (defined $colref->[-1]) {
        warn("WARNING : $bfile : last character of the line is expected to be a ',' !\n");
    }
    
    pop @$colref unless defined $colref->[-1];
    my $col_count = $#$colref;
    
    # vergelijken van de kolommen met het schema
    my @extra_in_file = where_not_exists($colref, $columns);
    
    if (@extra_in_file) {
        warn("WARNING : $bfile has extra columns: " . join(', ', @extra_in_file) . " !\n");
    }
    
    my @missing_in_file = where_not_exists($columns, $colref);
    
    if (@missing_in_file) {
        warn("WARNING : $bfile has missing columns: " . join(', ', @missing_in_file) . " !\n");
    }
    
    # tel het aantal lijnen
    my $col_names;
    
    my $row_count = 0;
    
    my $data;
    
    while (my $row = $csv->getline($ioref)) {
        # check aantal cols
        pop @$row unless defined $row->[-1];
        
        if ($#$row != $col_count) {
            print "$bfile : Invalid nr of columns (line nr $row_count) : ", join(", ", @$row);
        }
        
        $row_count++;
    }
    
    # vergelijken van het aantal verwachte rijen.

    my $expected_row_count = esl_table_row_count($table);

    #print "row_count = $row_count / $expected_row_count\n";
    
    unless (validate_row_count($expected_row_count, $row_count)) {
        warn("CSV file `$csv_file' has an invalid number of rows ($row_count). Expected $expected_row_count rows !\n");
    }

}
#print Dumper($data);


# ==========================================================================

=item esl_tables

give list of known esl tables

=cut


sub esl_tables {

    my $info = _read_ESL_CSV();

    return unless (defined $info);

    my @tables = map { $_->{'Table'}; } @$info ;
    
    return wantarray ? @tables : [ @tables ];
}

# ==========================================================================

sub esl_table_columns {
    my $t = shift;
    
    my $info = _read_ESL_CSV();
    
    return unless (defined $info);
    
    my @table_info = grep { $_->{'Table'} eq $t; } @$info ;

    unless (@table_info == 1) {
        warn("Can't find info for table `$t'");
        return;
    }

    #print Dumper(@table_info);

    my @columns = map { $_->{Column}; } @{ $table_info[0]->{Columns} };

    return wantarray ? @columns : [ @columns ];
}

# ==========================================================================

sub esl_table_row_count {
    my $t = shift;
    
    my $info = _read_ESL_CSV();
    
    return unless (defined $info);
    
    my @table_info = grep { $_->{'Table'} eq $t; } @$info ;

    unless (@table_info == 1) {
        warn("Can't find info for table `$t'");
        return;
    }

    return $table_info[0]->{RowCount};
}

# ==========================================================================
# ==========================================================================
# Lezen EXCEL sheet
# ==========================================================================
# ==========================================================================

=item _read_ESL_CSV()
    
    Read the definition of the cvs header from an excel sheet.
    
    Layout van de data uit de sheet omvormen naar andere layout

$ESL_CSV = [
          {
            'Table' => 'admin', 'RowCount' => '46850'
            'Columns' => [ { 'Column' => 'Full Nodename' }, { 'Column' => 'Application Notes' }, ...  ],

          },
          {
            'Table' => 'availability', 'RowCount' => '60097'
            'Columns' => [ { 'Column' => 'Full Nodename' }, { 'Column' => 'Assignment Group' }, ... ],
          }, ... ]


=cut


{
    my $ESL_CSV;
    
    sub _read_ESL_CSV {
        #my $ExcelFile = shift;
        
        # We search the sheet in de properties folder of the current directory
        # We could use the ini-file but for the moment KISS.

        my $ExcelFile = File::Spec->catfile('properties', 'DataValidation.xls');

        my $bfile = basename($ExcelFile);
        
        unless (defined $ESL_CSV) {
            
            my $InExcel;
            my $oFmt;
            
            unless (defined $InExcel) {
                $InExcel = new Spreadsheet::ParseExcel::Recursive or croak("ERROR: can't lauch EXCEL !\n");
            }
            
            unless (defined $oFmt) {
                $oFmt = new Spreadsheet::ParseExcel::Fmt8Bit or croak("ERROR: can't lauch Formatter !\n");
            }
            
            $InExcel->Parse($ExcelFile, $oFmt) or croak("ERROR: Parse of excel file `$bfile' failed !");
            
            my $DDL = { TABLE => 'ESL_CSV', COLUMNS => [ 'Table', 'RowCount', { TABLE => 'Columns', COLUMNS => [ 'Column' ] } ] };
            
            my $data = $InExcel->oread($DDL);# or croak "ERROR: Could't read EXCEL file `$file' !";
            
            $ESL_CSV = $data->{'ESL_CSV'};
            
            #print Dumper($ESL_CSV);
            
        }
        
        return $ESL_CSV;
    }
}

# ==========================================================================
__END__
