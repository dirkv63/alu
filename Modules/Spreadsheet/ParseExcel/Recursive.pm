# =========================================================================
# $Source: /export/development/cvs/aro/Tools/Spreadsheet-ParseExcel-Recursive/Recursive.pm,v $
# $Author: u75706 $ [Pauwel Coppieters]
# $Date: 2006/10/18 10:35:58 $
# CDate: 2001/05/09 16:51:44
# $Revision: 1.7 $
#
# ==========================================================================
#
# ident "$Id: Recursive.pm,v 1.7 2006/10/18 10:35:58 u75706 Exp $ [EDS]"
#
# ==========================================================================

package Spreadsheet::ParseExcel::Recursive;
use Spreadsheet::ParseExcel;

use strict;
use Carp;
use File::Basename;
use Data::Dumper;

use ErrorMessage qw(:ERROR :MESSAGE);

our ($VERSION);
$VERSION = substr q$Revision: 1.7 $, 10;

# ==========================================================================

=head1 NAME

Spreadsheet::ParseExcel::Recursive - Read table data recursively

=head1 DESCRIPTION

This module reads all the data in a excel sheet in a perl data structure.


Given a set of columns, return the data (recursive array of hashes)

table_definition :

Dit definieert layout van XLS spreadsheet
dit komt overeen met data die door write_enum_xml gebruikt wordt
! hieruit volgt dat alle kolommen aan andere header/naam moeten hebben.

ik zou ook met col nummers kunnenwerken dan mogen sommige cols dezelfde
naam hebben, maar dat heeft volgens mij geen zin
excel laat te gemakkelijk toe om kolom in te voegen -> nr kan veranderen
namen verschillend maken is geen enkel probleem

definitie van de tabellen en subtabellen in de spreadsheet.
ik kan ook proberen dit automatisch uit te vissen door naar de data
en de lege lijnen te kijken. maar voorlopig houden we het simpeler

EXAMPLE
 my $XLS_Table_Definition =
   { TABLE => 'ENUMS',
     COLUMNS => [ 'Id', 'Name', { TABLE => 'CODES',
                                  COLUMNS => [ 'Code', 'Description' ],
                                }
                ],
  };

Aanpassing voor Lieven : description wordt nu gebuikt voor zowel tabel
als sub-tabel. Dit houdt in dat een sub-table altijd 1 row lager begint.

Column titles can be shared between tables or private
Everey parent table must have at least one private column to determine row
the boundaries of the sub table
The column must not be used by sub(sub) tables.


=head1 TODO

In plaats van een data structuur een object terug geven (table object)
Attributen : Name, MaxRow, Column(Names)
Row object, Cell object, 
Cell via column name.

Kijk naar word objecten ... (complex table ...)

=cut

# ==========================================================================

sub new {
  my $type = shift;
  my $class = ref($type) || $type;
  my $self = {};

  my %params = @_;

  $self->{oExcel} = Spreadsheet::ParseExcel->new;

  $self->{_trim_spaces} = 3;	# default, trim both leading and trailing spaces

  # options
  if ($params{TrimBoth}) {
    $self->{_trim_spaces} = 3;
  } elsif ($params{TrimLeading}) {
    $self->{_trim_spaces} = 2;
  } elsif ($params{TrimTrailing}) {
    $self->{_trim_spaces} = 1;
  } elsif ($params{TrimNone}) {
    $self->{_trim_spaces} = 0;
  }

  # no Column headers in the first row of the sheet
  # In the DDL we use the excel column notation A, AA, ...

  if ($params{NoHeaders}) {
    $self->{_noheaders} = 1;
  } else {
    $self->{_noheaders} = 0;
  }

  bless ($self, $class);

  return $self;
}
# ==========================================================================

# separate parse method so we can get column_info first before doing the read

sub Parse {
  my ($self, $file, $formatter) = (shift, shift, shift);

  my $bfile = basename($file);

  my $oBook = $self->{oExcel}->Parse($file, $formatter) or return error(E_FAULT, "Parse of excel file `$bfile' failed !");

  $self->{oBook} = $oBook;

  return $self;
}

# ==========================================================================

sub read {
  my ($self, $file, $table_definition, $formatter) = (shift, shift, shift, shift);

  my $bfile = basename($file);
  my $oBook = $self->{oExcel}->Parse($file, $formatter) or return error(E_FAULT, "Parse of excel file `$bfile' failed !");

  return $self->_read($oBook, $bfile, $table_definition);

}

# ==========================================================================

# same as read but now from a sheet object and not from a file

sub oread {
  my ($self, $table_definition) = (shift, shift);

  my $oBook = $self->{oBook};
  return error(E_INVAL, "Workbook object missing in Spreadsheet::ParseExcel::Recursive object") unless (defined $oBook);

  # TODO : get file name of Workbook object
  my $bfile = basename($oBook->{File});

  return $self->_read($oBook, $bfile, $table_definition);
}

# ==========================================================================

# internal function

sub _read {
  my ($self, $oBook, $bfile, $table_definition) = @_;

  my $sheet_name = $table_definition->{TABLE} or return error(E_INVAL, "Table name missing in table definition !");

  my $sheet;
  my $count = 0;
  for (my $i = 0; $i < $oBook->{SheetCount}; $i++) {
    ($count++, $sheet = $oBook->{Worksheet}[$i]) if ($oBook->{Worksheet}[$i]->{Name} eq $sheet_name);
  }

  return error(E_EXIST, "Duplicate sheet `$sheet_name' found in `$bfile' !") if ($count > 1);
  return error(E_NFOUND, "Can't find sheet `$sheet_name' in `$bfile' !") if ($count < 1);

  # now get a name -> column mapping for this layout
  my $physical_table_definition = $self->_r_table_definition_mapping($sheet, $table_definition) or return undef;

  #print Dumper($physical_table_definition);

  my $trim_spaces = $self->{_trim_spaces};

  my $minrow = $sheet->{MinRow};
  $minrow++ unless ($self->{_noheaders});

  my $table = _r_get_xls_htable_data($sheet, $physical_table_definition, $minrow, $sheet->{MaxRow}, $trim_spaces) or return undef;

  return { $sheet_name => $table };
}

# ==========================================================================

=item column_info

Same function as Sheet_column_info from ExcelOLEUtil.pm
But then via Spreadsheet::ParseExcel and not via OLE.

The column_info function gives information about the columns of
the sheet.

It returns a reference to a hash with the column names as keys and a
hash reference containing the column info. For now, the column info
has only an 'ORDER' key. The value of the 'ORDER' key contains the
column number in the excel sheet and starts from 1.

=cut

sub column_info {
  my ($self, $sheet_name) = (shift, shift);

  my $oBook = $self->{oBook};

  return error(E_INVAL, "Workbook object missing in Spreadsheet::ParseExcel::Recursive object") unless (defined $oBook);

  if ($self->{_noheaders}) {
    # XXX
    return error(E_INVAL, "column_info not supported for sheets without headers !")
  }

  my $oSheet;
  my $count = 0;
  for (my $i = 0; $i < $oBook->{SheetCount}; $i++) {
    ($count++, $oSheet = $oBook->{Worksheet}[$i]) if ($oBook->{Worksheet}[$i]->{Name} eq $sheet_name);
  }

  # TODO : get file name of Workbook object
  my $bfile = basename($oBook->{File});

  return error(E_EXIST, "Duplicate sheet `$sheet_name' found in `$bfile' !") if ($count > 1);
  return error(E_NFOUND, "Can't find sheet `$sheet_name' in `$bfile' !") if ($count < 1);

  my $column_info = {};

  my $iR = $oSheet->{MinRow};
  for(my $iC = $oSheet->{MinCol} ; defined $oSheet->{MaxCol} && $iC <= $oSheet->{MaxCol} ; $iC++) {
    my $oCell = $oSheet->{Cells}[$iR][$iC] or next;
    my $name = $oCell->Value or next;

    $name =~ s/^\s*//; $name =~ s/\s*$//;

    next if ($name eq ''); # skip columns without name

    my $sheet_name = $oSheet->{Name};
    message(M_WARN, 2, "duplicate column `$name' in `$sheet_name'"), next if defined $column_info->{$name};

    $column_info->{$name}->{ORDER} = $iC + 1; # order starts from 1
  }

  return $column_info;
}

# =========================================================================

# map table definition structure to something we can use
# verify layout and spreadsheet match

sub _r_table_definition_mapping {
  return error(E_INVAL, "Illegal argument count") unless (@_ == 3);

  my ($self, $oSheet, $ddl) = @_;
  my ($physical_ddl, %count, $all_columns);

  return error(E_INVAL, "Table definition is not an HASHREF !") unless (ref($ddl) eq 'HASH');
  return error(E_INVAL, "Table definition 'COLUMNS' missing !") unless $ddl->{COLUMNS};
  return error(E_INVAL, "Table definition `COLUMNS' is not an ARRAYREF !") unless (ref($ddl->{COLUMNS}) eq 'ARRAY');

  $physical_ddl->{TABLE_NAME} = $ddl->{TABLE} or return error(E_INVAL, "Table name missing in table definition !");

  ## check we don't use the same name twice

  foreach (@{ $ddl->{COLUMNS} }) {
    next if ref($_);
    $count{$_}++;
    return error(E_EXIST, "Invalid DDL : duplicate column name `$_' !") if ($count{$_} > 1);
  }

  # ok layout seems not terribly wrong
  ## first do sub-table definitions

  foreach my $column (@{ $ddl->{COLUMNS} }) {
    next unless ref($column);

    # a sub-table definition
    my $td = $self->_r_table_definition_mapping($oSheet, $column) or return undef;

    push @{ $physical_ddl->{TABLE_DEFINITIONS} }, $td;

    # keep column names of all sub-tables
    foreach (keys %{ $td->{ALL_COLUMNS} } ) {
      $all_columns->{$_} += $td->{ALL_COLUMNS}->{$_};
    }
  }

  ## then the definition of my own table

  my $found_cnt = 0;
  foreach my $column (@{ $ddl->{COLUMNS} }) {
    next if ref($column);

    # a colum is shared (between table and sub-table) if it is in a sub-table definition

    if ($all_columns->{$column}) {
      push @{ $physical_ddl->{SHARED}}, $column;
    } else {
      push @{ $physical_ddl->{PRIVATE}}, $column;
    }

    # a column name -> column number mapping

    my ($fh, $msg, $err, $iC);
    $fh = error_set(FH => undef); # suppres error message (can't use it : has the prefix ERROR in it)
    $iC = $self->_get_xls_column_number($oSheet, $column);
    error_set(FH => $fh);	# and back to normal

    unless (defined $iC) {
      $msg = error_msg();
      return error($err, "_get_xls_column_number failed: $msg" ) unless (($err = error_num()) == E_NFOUND);
      error_clear();
      message(M_WARN, 2, "$msg");
      $physical_ddl->{MAPPING}->{$column} = -1;
    } else {
      $found_cnt++;
      $physical_ddl->{MAPPING}->{$column} = $iC;
    }
  }

  ## we must have found at least one column
  return error(E_INVAL, "Invalid DDL : none of the column titles was found in the sheet `$ddl->{TABLE}' !") if ($found_cnt == 0);

  ## we must have at least one private column (to determine table boundaries of sub-tables)
  return error(E_INVAL, "Invalid DDL : all columns of table `$ddl->{TABLE}' shared with sub-tables !") if ( $#{$physical_ddl->{PRIVATE} } < 0);

  ## add my own columns to all the used columns

  foreach (@{ $ddl->{COLUMNS} }) {
    next if ref($_);		# a sub-table
    $physical_ddl->{ALL_COLUMNS}->{$_}++;
  }

  ## add columns of sub-tables

  foreach (keys %{ $all_columns }) { $physical_ddl->{ALL_COLUMNS}->{$_} += $all_columns->{$_}; }

  return $physical_ddl;
}
# ==========================================================================

# return cleaned up data from excel cell
# an empty cell (even with space) returns undef

sub _get_xls_worksheet_cell {
  my ($oSheet, $iR, $iC, $trim_spaces) = (shift, shift, shift, shift);
  my $rtc;

  if ($oSheet->{Cells}[$iR][$iC] && defined $oSheet->{Cells}[$iR][$iC]->Value)
    {
      my $d = $oSheet->{Cells}[$iR][$iC]->Value;

      # trim leading and trailing spaces

      if ($trim_spaces == 3) { # trim both leading and trailing spaces
	$d =~ s/^\s*//;
	$d =~ s/\s*$//;
      } elsif ($trim_spaces == 2) { # trim only leading spaces
	$d =~ s/^\s*//;
      } elsif ($trim_spaces == 1) { # trim only trailing spaces
	$d =~ s/\s*$//;
      }

      $rtc = $d if ($d ne '');
    }

  return $rtc;
}

# ==========================================================================
# =========================================================================

# given a set of columns, return the data (array of hashes)

sub _r_get_xls_htable_data {
  return error(E_INVAL, "Illegal argument count") unless (@_ == 5);

  my ($oSheet, $ddl, $first_row, $last_row, $trim_spaces) = (shift, shift, shift, shift, shift);
  my ($table, $prev_row, $prev_start);

  $table = [];
  for (my $iR = $first_row; $iR <= $last_row; $iR++) {
    my ($row, $data, $iC);

    foreach my $col (@{ $ddl->{PRIVATE} } ) {
      # not every columns is mapped to a column number
      # maybe the column was not available in the spread sheet

      next if (($iC = $ddl->{MAPPING}->{$col}) == -1);

      $row->{$col} = $data if (defined ($data = _get_xls_worksheet_cell($oSheet, $iR, $iC, $trim_spaces)));
    }

    next unless (defined $row); # this skips rows that are completely empty

    # save the current row
    push @$table, $row;

    # give every column a value
    map { $row->{$_} = '' unless (defined $row->{$_}); } @{ $ddl->{PRIVATE} };

    # if private columns started a new row, take shared columns with this row also
    # give every column a value
    foreach my $col (@{ $ddl->{SHARED} } ) {
      # not every columns is mapped to a column number
      # maybe the column was not available in the spread sheet

      next if (($iC = $ddl->{MAPPING}->{$col}) == -1);

      $row->{$col} = $data if (defined ($data = _get_xls_worksheet_cell($oSheet, $iR, $iC, $trim_spaces)));

      $row->{$col} = '' unless (defined $row->{$col});
    }

    # get sub-table that belongs to the previous row
    if (defined $prev_row) {
      foreach my $def (@{ $ddl->{TABLE_DEFINITIONS} } ) {
	$prev_row->{$def->{TABLE_NAME}} = _r_get_xls_htable_data($oSheet, $def, $prev_start, $iR - 1, $trim_spaces);
      }
    }

    # store row info ref for later use
    $prev_row = $row;

    # new row in the parent table determines the boundary for the child table
    $prev_start = $iR + 1;
  }

  # potential final sub-table

  if (defined $prev_row) {
    foreach my $def (@{ $ddl->{TABLE_DEFINITIONS} } ) {
      $prev_row->{$def->{TABLE_NAME}} = _r_get_xls_htable_data($oSheet, $def, $prev_start, $last_row, $trim_spaces);
    }
  }

  return $table;
}

# =========================================================================

# given a column title, return the column number

sub _get_xls_column_number {
  return error(E_INVAL, "Illegal argument count") unless (@_ == 3);
  my ($self, $oSheet, $title) = @_;

  my $column;

  if ($self->{_noheaders}) {
    $column = _fromAA($title);

    unless (defined $column) {
      return error(E_INVAL, "Column `$title' is not a standard excel column name!");
    }

    return $column;
  } else {

    my $iR = $oSheet->{MinRow};

    my $count = 0;
    for (my $iC = $oSheet->{MinCol}; defined $oSheet->{MaxCol} && $iC <= $oSheet->{MaxCol}; $iC++) {
      my $cell = _get_xls_worksheet_cell($oSheet, $iR, $iC, 3);
      next unless (defined $cell);
      ($count++, $column = $iC) if ($cell eq $title);
    }

    if ($count == 0) {
      my $bfile = basename($oSheet->{_Book}->{File});
      return error(E_NFOUND, "Column `$title' not found in `$bfile' !");
    }
    elsif ($count == 1) {
      return $column;
    }
    else {
      my $bfile = basename($oSheet->{_Book}->{File});
      return error(E_EXIST, "Duplicate column `$title' found in `$bfile' !");
    }
  }
}
# =========================================================================

# XXX TODO
sub _fromAA ($) {
  my $cc = shift ;

  unless ($cc =~ m/^[A-Za-z@]{1,2}$/) {
    warn "Invalid column name `$cc' !\n";
    return undef;
  }

  my $iC = 0;

  while($cc =~ s/^([A-Z])//) {
    $iC = 26 * $iC + 1 + ord ($1) - ord ("A");
  }

  return($iC - 1);
}

# =========================================================================

1;  # don't forget to return a true value from the file


