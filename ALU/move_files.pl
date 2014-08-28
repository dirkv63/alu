#!/usr/bin/perl
# ==========================================================================
# $Source$
# $Author$ [pauwel]
# $Date$
# CDate: Tue Jun 19 15:01:31 2012
# $Revision$
#
# ==========================================================================
#
# ident "$Id$"
#
# ==========================================================================

use strict;
use Getopt::Long;
use File::Basename;
use File::Glob qw(:glob);
use File::Spec;
use File::Copy;
use File::Path qw(make_path);
use Spreadsheet::ParseExcel::Recursive;
use Spreadsheet::ParseExcel::Fmt8Bit;
use Log::Log4perl qw(:easy);
use IniUtil qw(load_alu_ini);

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

Move files to the transition file system.
Replacement of the mvdata2.bat script. The list of files comes from tke WorkFlow.xls(Files) sheet.
The folder are specified in the alu.ini file.

TODO:
 create folders if needed.
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

usage "Need one argument !\n" if @ARGV != 1;

my $run = $ARGV[0];

Log::Log4perl->easy_init($ERROR);

## Read the alu.ini file
my $ini_attr;
$ini_attr->{ini_folder} = $opt_ini if ($opt_ini);
my $alu_cfg = load_alu_ini($ini_attr) or do { ERROR("Failed to parse ALU ini-file !"); exit(2) };

unless ($alu_cfg->SectionExists($run)) { ERROR("Run `$run' does not exists in alu.ini !"); exit(2); }

# ==========================================================================

my $files = _read_FILES();

# extract <> tags from the data and resolve with the ini file

#$files = [ { File => '<kiek> <koek>'} ];

my $tags;

map { $tags->{$_}++ } map { $_->{File} =~ m/(<[a-zA-Z0-9_]*>)/g } @$files;
map { $tags->{$_}++ } map { $_->{Destination} =~ m/(<[a-zA-Z0-9_]*>)/g } @$files;


foreach my $tag (keys %$tags) {
  my $attr = $tag;
  $attr =~ s/^<//;
  $attr =~ s/>$//;

  my $value = $alu_cfg->val($run, $attr) || die("ERROR: `$attr' missing in [$run] section in alu.ini !\n");

  $tags->{$tag} = $value;
}

# check that all the folders in the <tags> exists

my $err_cnt = 0;
foreach my $tag (keys %$tags) {
  my $d = $tags->{$tag};
  unless (-d $d) {
    print STDERR "ERROR : the folder $d ($tag) does not exist !\n";
    $err_cnt++;
  }
}

die if $err_cnt;

# perform the Move/Copy/Delete actions

$err_cnt = 0;
foreach my $spec (@$files) {
  my $action = $spec->{Action};
  my $skip = $spec->{Skip};
  my $file = $spec->{File};
  my $destination = $spec->{Destination};

  unless ($action =~ m/^(m|c)$/i) {
      print STDERR "ERROR : Invalid action ($action) for `$file'\n";
      $err_cnt++;
      next;
  }

  if (defined $skip && $skip =~ m/y/i) {
    next;
  }

  foreach my $tag (keys %$tags) {
    my $value = $tags->{$tag};
    $file =~ s/$tag/$value/g;
    $destination =~ s/$tag/$value/g;
  }

  # destination must be folder folder
  $destination = File::Spec->canonpath($destination);

  if (-e $destination && ( ! -d $destination)) {
      die "ERROR: Destination `$destination' must be a folder !";
  }

  # eventuele sub-directories wel aanmaken.
  unless (-d $destination) {
    make_path($destination) or die "ERROR: failed to make destination folder `$destination' !";
  }


  #$file = File::Spec->canonpath($file);

  my @file_set;

  if (-f $file) {
      @file_set = ($file);
  }
  else {
      # source file does not exist
      # maybe it is a glob

      my @file_list = bsd_glob($file, GLOB_NOCHECK | GLOB_NOCASE | GLOB_QUOTE);

      if (@file_list == 1 && $file_list[0] eq $file) {
          print STDERR "ERROR : the source file `$file' does not exists !\n";
          $err_cnt++;
          next;
      }
          
      foreach my $file (@file_list) {
          unless (-f $file) {
              print STDERR "ERROR : the source file `$file' does not exists !\n";
              $err_cnt++;
              next;
          }

          push @file_set, $file;
      }
  }

  foreach my $file (@file_set) {
      my $rv = ($action =~ m/^c$/i) ? copy($file, $destination) : move($file, $destination);

      unless ($rv) {
          my $what = ($action =~ m/^c$/i) ? 'copy' : 'move';
          print STDERR "ERROR : failed to $what `$file' : $!\n";
          $err_cnt++;
      }
  }
}

if ($err_cnt) {
  print STDERR "There were `$err_cnt' errors during file move/copy !\n";
  exit(1);
}

print "File move/copy was successful !\n";
exit(0);

# ==========================================================================

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
    my $FILES;

    sub _read_FILES {
        #my $ExcelFile = shift;

        # We search the sheet in de properties folder of the current directory
        # We could use the ini-file but for the moment KISS.

        my $ExcelFile = File::Spec->catfile('properties', 'WorkFlow.xls');

        my $bfile = basename($ExcelFile);

        unless (defined $FILES) {

            my $InExcel;
            my $oFmt;

            unless (defined $InExcel) {
                $InExcel = new Spreadsheet::ParseExcel::Recursive or croak("ERROR: can't lauch EXCEL !\n");
            }

            unless (defined $oFmt) {
                $oFmt = new Spreadsheet::ParseExcel::Fmt8Bit or croak("ERROR: can't lauch Formatter !\n");
            }

            $InExcel->Parse($ExcelFile, $oFmt) or croak("ERROR: Parse of excel file `$bfile' failed !");

            my $DDL = { TABLE => 'Files', COLUMNS => [ 'Action', 'File', 'Destination', 'Skip' ] };

            my $data = $InExcel->oread($DDL);# or croak "ERROR: Could't read EXCEL file `$file' !";

            $FILES = $data->{'Files'};

            #print Dumper($FILES);

        }

        return $FILES;
    }
}

# ==========================================================================
__END__
