# ==========================================================================
# $Source$
# $Author$ [pauwel]
# $Date$
# CDate: Wed Jul 11 10:24:38 2012
# $Revision$
#
# ==========================================================================
#
# ident "$Id$"
#
# ==========================================================================

package WorkFlow;

=pod

Read the WorkFlow.xls EXCEL sheet

Todo :
- make a singleton "object" to keep the ini settings at hand, so these ini's can be used in various modules
  or
- pass the excel file name as a parameter

=cut


use strict;
use warnings;
use Carp;
use File::Basename;
use Log::Log4perl qw(:easy);

use Spreadsheet::ParseExcel::Recursive;
use Spreadsheet::ParseExcel::Fmt8Bit;

use Data::Dumper;

BEGIN {
  use Exporter ();
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK);

  $VERSION = '1.0';

  @ISA         = qw(Exporter);

  @EXPORT    = qw();

  @EXPORT_OK = qw(read_ESL_SOURCE
                  read_ovsd_SOURCE
                  read_A7_SOURCE
                  read_Portfolio_SOURCE
                  read_master_SOURCE);
}

# ==========================================================================

=item read_ESL_SOURCE()

    Read the mapping of the esl tables versus the files

=cut


{
  my $ESL_SOURCE;

  sub read_ESL_SOURCE {
    #my $ExcelFile = shift;

    # We search the sheet in de properties folder of the current directory
    # We could use the ini-file but for the moment KISS.

    my $ExcelFile = File::Spec->catfile('properties', 'WorkFlow.xls');

    unless (-f $ExcelFile) {
        ERROR("Excel file `$ExcelFile' does not exists !");
        return;
    }

    my $bfile = basename($ExcelFile);

    unless (defined $ESL_SOURCE) {

      my $InExcel;
      my $oFmt;

      unless (defined $InExcel) {
        $InExcel = new Spreadsheet::ParseExcel::Recursive or croak("ERROR: can't lauch EXCEL !\n");
      }

      unless (defined $oFmt) {
        $oFmt = new Spreadsheet::ParseExcel::Fmt8Bit or croak("ERROR: can't lauch Formatter !\n");
      }

      $InExcel->Parse($ExcelFile, $oFmt) or croak("ERROR: Parse of excel file `$bfile' failed !");

      my $DDL = { TABLE => 'ESL_SOURCE', COLUMNS => [ 'File', 'Table', 'CharSet', 'RowCount' ] };

      my $data = $InExcel->oread($DDL);# or croak "ERROR: Could't read EXCEL file `$file' !";

      $ESL_SOURCE = $data->{'ESL_SOURCE'};

      #print Dumper($ESL_SOURCE);

    }

    return $ESL_SOURCE;
  }
}

# ==========================================================================


=item esl_tables

give list of known esl tables

=cut


# not used
sub esl_tables {

    my $info = read_ESL_SOURCE();

    return unless (defined $info);

    my @tables = map { $_->{'Table'}; } @$info ;

    return wantarray ? @tables : [ @tables ];
}

# ==========================================================================

# not used
sub esl_table_columns {
    my $t = shift;

    my $info = read_ESL_SOURCE();

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

# not used
sub esl_table_row_count {
    my $t = shift;

    my $info = read_ESL_SOURCE();

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

=item read_ovsd_SOURCE()

    Read the mapping of the ovsd tables versus the excel files

=cut


{
  my $ovsd_SOURCE;

  sub read_ovsd_SOURCE {
    #my $ExcelFile = shift;

    # We search the sheet in de properties folder of the current directory
    # We could use the ini-file but for the moment KISS.

    my $ExcelFile = File::Spec->catfile('properties', 'WorkFlow.xls');

    unless (-f $ExcelFile) {
        ERROR("Excel file `$ExcelFile' does not exists !");
        return;
    }

    my $bfile = basename($ExcelFile);

    unless (defined $ovsd_SOURCE) {

      my $InExcel;
      my $oFmt;

      unless (defined $InExcel) {
        $InExcel = new Spreadsheet::ParseExcel::Recursive or croak("ERROR: can't lauch EXCEL !\n");
      }

      unless (defined $oFmt) {
        $oFmt = new Spreadsheet::ParseExcel::Fmt8Bit or croak("ERROR: can't lauch Formatter !\n");
      }

      $InExcel->Parse($ExcelFile, $oFmt) or croak("ERROR: Parse of excel file `$bfile' failed !");

      my $DDL = { TABLE => 'ovsd_SOURCE', COLUMNS => [ 'File', 'Table', 'CharSet', 'RowCount' ] };

      my $data = $InExcel->oread($DDL);# or croak "ERROR: Could't read EXCEL file `$file' !";

      $ovsd_SOURCE = $data->{'ovsd_SOURCE'};

      #print Dumper($ovsd_SOURCE);

    }

    return $ovsd_SOURCE;
  }
}

# ==========================================================================

=item ovsd_tables

give list of known ovsd tables

=cut


# not used
sub ovsd_tables {

    my $info = read_ovsd_SOURCE();

    return unless (defined $info);

    my @tables = map { $_->{'Table'}; } @$info ;

    return wantarray ? @tables : [ @tables ];
}

# ==========================================================================

# not used
sub ovsd_table_columns {
    my $t = shift;

    my $info = read_ovsd_SOURCE();

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


# not used
# ==========================================================================

sub ovsd_table_row_count {
    my $t = shift;

    my $info = read_ovsd_SOURCE();

    return unless (defined $info);

    my @table_info = grep { $_->{'Table'} eq $t; } @$info ;

    unless (@table_info == 1) {
        warn("Can't find info for table `$t'");
        return;
    }

    return $table_info[0]->{RowCount};
}


# ==========================================================================

=item read_A7_SOURCE()

    Read the mapping of the AssetCenter tables versus the excel files

=cut


{
  my $A7_SOURCE;

  sub read_A7_SOURCE {
    #my $ExcelFile = shift;

    # We search the sheet in de properties folder of the current directory
    # We could use the ini-file but for the moment KISS.

    my $ExcelFile = File::Spec->catfile('properties', 'WorkFlow.xls');

    unless (-f $ExcelFile) {
        ERROR("Excel file `$ExcelFile' does not exists !");
        return;
    }

    my $bfile = basename($ExcelFile);

    unless (defined $A7_SOURCE) {

      my $InExcel;
      my $oFmt;

      unless (defined $InExcel) {
        $InExcel = new Spreadsheet::ParseExcel::Recursive or croak("ERROR: can't lauch EXCEL !\n");
      }

      unless (defined $oFmt) {
        $oFmt = new Spreadsheet::ParseExcel::Fmt8Bit or croak("ERROR: can't lauch Formatter !\n");
      }

      $InExcel->Parse($ExcelFile, $oFmt) or croak("ERROR: Parse of excel file `$bfile' failed !");

      my $DDL = { TABLE => 'A7_SOURCE', COLUMNS => [ 'File', 'Table', 'CharSet', 'RowCount' ] };

      my $data = $InExcel->oread($DDL);# or croak "ERROR: Could't read EXCEL file `$file' !";

      $A7_SOURCE = $data->{'A7_SOURCE'};

      #print Dumper($A7_SOURCE);
    }

    return $A7_SOURCE;
  }
}

# ==========================================================================

=item read_Portfolio_SOURCE()

    Read the mapping of the Portfolio tables versus the portfolio excel file

=cut


{
  my $SOURCE;

  sub read_Portfolio_SOURCE {
    #my $ExcelFile = shift;

    # We search the sheet in de properties folder of the current directory
    # We could use the ini-file but for the moment KISS.

    my $ExcelFile = File::Spec->catfile('properties', 'WorkFlow.xls');

    unless (-f $ExcelFile) {
        ERROR("Excel file `$ExcelFile' does not exists !");
        return;
    }

    my $bfile = basename($ExcelFile);

    unless (defined $SOURCE) {

      my $InExcel;
      my $oFmt;

      unless (defined $InExcel) {
        $InExcel = new Spreadsheet::ParseExcel::Recursive or croak("ERROR: can't lauch EXCEL !\n");
      }

      unless (defined $oFmt) {
        $oFmt = new Spreadsheet::ParseExcel::Fmt8Bit or croak("ERROR: can't lauch Formatter !\n");
      }

      $InExcel->Parse($ExcelFile, $oFmt) or croak("ERROR: Parse of excel file `$bfile' failed !");

      my $DDL = { TABLE => 'Portfolio_SOURCE', COLUMNS => [ 'File', 'Table', 'CharSet', 'RowCount' ] };

      my $data = $InExcel->oread($DDL);# or croak "ERROR: Could't read EXCEL file `$file' !";

      $SOURCE = $data->{'Portfolio_SOURCE'};

      #print Dumper($SOURCE);
    }

    return $SOURCE;
  }
}

# ==========================================================================

=item read_master_SOURCE()

    Read the mapping of the master tables versus the master excel file

=cut


{
  my $SOURCE;

  sub read_master_SOURCE {
    #my $ExcelFile = shift;

    # We search the sheet in de properties folder of the current directory
    # We could use the ini-file but for the moment KISS.

    my $ExcelFile = File::Spec->catfile('properties', 'WorkFlow.xls');

    unless (-f $ExcelFile) {
        ERROR("Excel file `$ExcelFile' does not exists !");
        return;
    }

    my $bfile = basename($ExcelFile);

    unless (defined $SOURCE) {

      my $InExcel;
      my $oFmt;

      unless (defined $InExcel) {
        $InExcel = new Spreadsheet::ParseExcel::Recursive or croak("ERROR: can't lauch EXCEL !\n");
      }

      unless (defined $oFmt) {
        $oFmt = new Spreadsheet::ParseExcel::Fmt8Bit or croak("ERROR: can't lauch Formatter !\n");
      }

      $InExcel->Parse($ExcelFile, $oFmt) or croak("ERROR: Parse of excel file `$bfile' failed !");

      my $DDL = { TABLE => 'master_SOURCE', COLUMNS => [ 'File', 'Table', 'CharSet', 'RowCount' ] };

      my $data = $InExcel->oread($DDL);# or croak "ERROR: Could't read EXCEL file `$file' !";

      $SOURCE = $data->{'master_SOURCE'};

      #print Dumper($SOURCE);
    }

    return $SOURCE;
  }
}

# ==========================================================================

1;
