# ==========================================================================
# $Source$
# $Author$ [pauwel]
# $Date$
# CDate: Wed Jul 11 13:30:01 2012
# $Revision$
#
# ==========================================================================
#
# ident "$Id$"
#
# ==========================================================================

=pod

Set of routines to ain in EXCEL access
- reduce memory usage of Spreadsheet::ParseExcel

=cut

package XlsUtil;

use strict;
use warnings;
use Carp;
use Log::Log4perl qw(:easy);
use Spreadsheet::ParseExcel::Utility qw(ExcelFmt ExcelLocaltime);
use Scalar::Util qw(looks_like_number);
use Encode;
use Encode::Guess qw/UTF-8 ISO-8859-1/;

use ALU_Util qw(glob2pat normalize_file_column_names);
use Set qw(where_not_exists where_exists);
use DbUtil qw(do_select do_prepare mysql_datatype_length);

use Data::Dumper;

BEGIN {
  use Exporter ();
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK);

  $VERSION = '1.0';

  @ISA         = qw(Exporter);

  @EXPORT    = qw();

  @EXPORT_OK = qw(transform_datetime
                  transform_varchar
                  transform_double
                  transform_int
                  tabglob2tab
                  small_cell_handler
                  get_cell_data
                  import_sheet
                );
}

# ==========================================================================

=pod

Conversion routines from an excel format to an MySQL format.
The Excel data is a two-dimensional array of cells.
Each cell is an array ref with three or four elements :
[ Type, FormatNo, Value, Unformatted Value ]

These elements are a minimal subset of the attributes that are in a Spreadsheet::ParseExcel::Cell object.

The unformatted value is optional and only exists when it differs from the formatted value.

The type_info is information about the datatypes that comes from MySQL.


=cut


# ==========================================================================

sub transform_datetime {
    my $cell = shift;
    my $type_info = shift;

    my ($type, $format, $value, $unfor) = @$cell;

    return undef unless defined $value;
    $value =~ s/\s*$//;
    return undef if ($value eq '');

    #print Dumper($cell);

#    if ($value ne $unfor) {
#        print "value = $value\n";
#        print "unfor = $unfor\n";
#    }

    if ($type =~ m/^text$/i) {
      $value =~ s/\s//g;

      # '8/20/2004' (mm-dd-yyyy)
      if ($value =~ m/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/) {
        $value = sprintf("%04d-%02d-%02d", $3, $1, $2);
      }
      else {
        my $data_log = Log::Log4perl->get_logger('Data');
        $data_log->error("No conversion for date ($value)");
        return undef;
      }

    }
    elsif ($type =~ m/^date$/i) {

      # default date format MySQL : YYYY-MM-DD HH:MI:SS
      $value = ExcelFmt('yyyy-mm-dd hh:mm:ss', $unfor);
    }

    return $value;
}

# ==========================================================================

sub transform_varchar {
  my $cell = shift;
  my $type_info = shift;

  my ($type, $format, $value, $unfor) = @$cell;

  return undef unless (defined $value);

  if ($type =~ m/^text$/i) {

    unless ($value =~ m/^[[:ascii:]]*$/s) {
      # het is reeds UTF-8 => moeten we niks doen he
      if (utf8::is_utf8($value)) {
        ;
      }
      else {
        my $data = $value;

        my $decoder = Encode::Guess->guess($data);

        if (ref($decoder)) {
          $value = $decoder->decode($data);
        }
        elsif ($decoder eq "utf-8-strict or iso-8859-1 or utf8") {
          # neem dan UTF-8
          $value = decode( 'UTF-8', $data, Encode::FB_CROAK);
        }
        else {
          print Dumper($data);
          die $decoder;
        }
      }

      #exit;
    }


    # lege chars op einde van een veld zijn weg via access => trimmen dus.
    # blanko's achteraan trimmen

    $value =~ s/\s*$//;

    #$value =~ s/ *$//;

    if (my $l = $type_info->{LENGTH}) {
      if (length($value) > $l) {
        my $data_log = Log::Log4perl->get_logger('Data');
        my $col = $type_info->{NAME};
        $data_log->error("Column `$col' is too long (> $l) and will be truncated");
      }
    }
    return $value;
  }
  elsif ($type =~ m/^numeric$/i) {
    if (defined $unfor) {
      return $unfor;
    }

    # dot is a decimal point => comma
    if ($value =~ m/^[+-]?\d+$/) {
      return $value;
    }
    elsif ($value =~ m/^([+-]?\d+)\.$/) {
      return $1 . ',';
    }
    elsif ($value =~ m/^([+-]?\d+)\.(\d+)$/) {
      return $1 . ',' . $2;
    }
    elsif ($value =~ m/^([+-]?\d+)\.(\d+[eE]\+\d+)$/) {
      # here we have cases like this :
      # 1.03938058100882e+17
      # 1.05761020101027e+17

      # What happens:
      #  - I have no clue, but we do the conversion in the same was as access, so it is not worse than before.
      # This is excel "helping" the user that kicks us in the but.

      return $1 . ',' . $2;
    }
    else {
      my $data_log = Log::Log4perl->get_logger('Data');
      my $col = $type_info->{NAME};
      $data_log->warn("Column `$col' contains an unhandeld numeric value ($value)");
      return $value;
    }
  }
  else {
    my $data_log = Log::Log4perl->get_logger('Data');
    my $col = $type_info->{NAME};
    $data_log->error("Column `$col' contains an unhandeld excel type ($type/$value/$unfor)");
    return $value;
  }
}

# ==========================================================================

sub transform_double {
    my $cell = shift;
    my $type_info = shift;

    #print Dumper($cell);
    #print Dumper($type_info);

    # lege chars op einde van een veld zijn weg via access => trimmen dus.
    # blanko's achteraan trimmen
    my $value = $cell->[2];

    return undef unless defined $value;

    $value =~ s/\s*$//;

    return undef if ($value eq '');

    if (my $l = $type_info->{LENGTH}) {
        if (length($value) >= $l) {
          my $data_log = Log::Log4perl->get_logger('Data');
          my $col = $type_info->{NAME};
          $data_log->error("Column `$col' is too long (> $l) and will be truncated");
        }
    }

    return $value;
}

# ==========================================================================

sub transform_int {
    my $cell = shift;
    my $type_info = shift;

    #print Dumper($cell);
    #print Dumper($type_info);

    my $value = $cell->[2];

    return undef unless defined $value;

    $value =~ s/\s*$//;

    return undef if ($value eq '');

    if (my $l = $type_info->{LENGTH}) {
        if (length($value) >= $l) {
          my $data_log = Log::Log4perl->get_logger('Data');
          my $col = $type_info->{NAME};
          $data_log->error("Column `$col' is too long (> $l) and will be truncated");
        }
    }

    return $value;
}

# ==========================================================================

sub tabglob2tab {
    my $workbook = shift;
    my $glob = shift;

    my $regexp = glob2pat($glob);

    my $worksheet_count = $workbook->worksheet_count();

    my @matching_sheets = grep { my $worksheet = $workbook->worksheet($_); $worksheet->get_name =~ m/$regexp/; } (0 .. $worksheet_count - 1);

    if (@matching_sheets < 1) {
        ERROR("Couldn't find sheet `$glob' !");
        return;
    }

    if (@matching_sheets > 1) {
        ERROR("Multiple sheets found that match the pattern `$glob' !");
        return;
    }

    my $worksheet = $workbook->worksheet( $matching_sheets[0] );

    return $worksheet->get_name;
}


# ==========================================================================

=item small_cell_handler

The parse method reads a complete workbook
We could optimize even more and only keep the data for the sheets we really want
but we only can get the names of the sheets after we have called the parse method
So I leave that optimization out (for now).

small_cell_handler is a bit gefoefel.
We store our small cells inside the workbook

=cut

sub small_cell_handler {
  my $workbook    = $_[0];
  my $sheet_index = $_[1];
  my $row         = $_[2];
  my $col         = $_[3];
  my $cell        = $_[4];

  my $small_cell;

=pod
$VAR1 = bless( {
                 'Code' => undef,
                 'Type' => 'Text',
                 'Val' => 'SW-DB-CAOTTS041-DEFAULT-UNIFIEDLOGIN',
                 '_Value' => 'SW-DB-CAOTTS041-DEFAULT-UNIFIEDLOGIN',
                 'FormatNo' => 65,
                 '_Kind' => 'PackedIdx',
                 'Format' => { ... }
               }, 'Spreadsheet::ParseExcel::Cell' );

=cut

  # We only keep the Type, FormatNo and Value of a cell
  # And if the unformatted value is different, we keep that too
  # To reduce memory usage even further we could replace Type with a TypeNo

  if ($cell->{_Value} eq '') {
    if ($cell->{_Kind} eq 'BLANK') {
      $small_cell = [ $cell->{Type}, $cell->{FormatNo}, undef ];
    }
    elsif ($cell->{_Kind} eq 'MulBlank') {
      $small_cell = [ $cell->{Type}, $cell->{FormatNo}, undef ];
    }
    else {
      $small_cell = [ $cell->{Type}, $cell->{FormatNo}, '' ];
    }
  }
  else {
    $small_cell = [ $cell->{Type}, $cell->{FormatNo}, $cell->{_Value} ];
  }

  # append unformatted data if it is different
  push @$small_cell, $cell->{Val} if ($cell->{Val} ne $cell->{_Value});

#  print Dumper($small_cell);

  # this is gefoefel
  $workbook->{Worksheet}[$sheet_index]->{SmallCells}[$row][$col] = $small_cell;
}

# ==========================================================================

sub get_cell_data {
  my $sheet = shift;

  return $sheet->{SmallCells};
}

# ==========================================================================
# ==========================================================================

sub import_sheet {
  my ($worksheet, $dbh, $table) = @_;

  my $database = $dbh->{Name};

  my $data_log = Log::Log4perl->get_logger('Data');

  my $small_cell_data = get_cell_data($worksheet) or die "ERROR: get_cell_data failed !";

  my $sheet_name = $worksheet->get_name;
  # direct de header lezen ?

  # Header ophalen

  my $header = $small_cell_data->[0];

  # Beware, this currently only works if col_min == 0. I'm not prepared yet to offset the columns
  # This is currently working, but not correct => only works if min == 0
  my ( $col_min, $col_max ) = $worksheet->col_range();
  my ( $row_min, $row_max ) = $worksheet->row_range();

  unless ($col_min == 0) { ERROR("Sheet col min should be zero !"); exit(1); }
  unless ($row_min == 0) { ERROR("Sheet row min should be zero !"); exit(1); }

  # Excel is a dirty file format !! Often we have empty cell (because it's not visible to the
  # user) that are not important and should be skipped

  my $file_cols;

  for my $col ( 0 .. $col_max ) {

    my $cell = $small_cell_data->[0][$col];

    unless ($cell) {
      push @$file_cols, undef;
      next;
    }

    # transform_varchar performs utf8 conversion => is_utf8 is set (and value is a valid utf-8 string)
    my $value = transform_varchar($cell, {});

    if (defined $value) {
      $value =~ s/^\s*//;
      $value =~ s/\s*$//;
    }

    #next if ($value eq '');
    push @$file_cols, $value;
  }

  # als de sheet achteraan undef colommen heeft
  while (! (defined $file_cols->[-1] && $file_cols->[-1] ne '')) {
    pop @$file_cols;
  }

  # check of er nog undefined header cols zijn
  for (my $i = 0; $i <= $#$file_cols; $i++) {
    unless (defined $file_cols->[$i] && $file_cols->[$i] ne '') {
      ERROR("Undefined column header in column `$i'");
    }
  }

  #print STDERR "file header : ", Dumper($file_cols);

  my $file_col_count = $#$file_cols;

  #print STDERR "file header column count : ", Dumper($file_col_count);

  # soms heeft de file duplicate columns of te lange column names
  my $normalized_file_cols = normalize_file_column_names($file_cols);

  #print STDERR Dumper($normalized_file_cols);

  # Field, Type, Null, Key, Default, Extra
  my $table_col_info = do_select($dbh, "desc $table");

  unless ($table_col_info && @$table_col_info) {
    ERROR("Failed to get column information of the table $database.$table");
    return;
  }

  # print STDERR Dumper($table_col_info);
  my $htable_col_info = { map { $_->[0] => { NAME =>  $_->[0],
                                             TYPE => $_->[1],
                                             LENGTH => mysql_datatype_length($_->[1]),
                                             NULL => $_->[2],
                                             KEY => $_->[3],
                                             DEFAULT => $_->[4] } } @$table_col_info };

  #print Dumper($htable_col_info);

  # skip the auto_increment kolommen (zit in Extra)
  my $table_cols = [ map { $_->[0] } grep { $_->[5] !~ m/auto_increment/i } @$table_col_info ];

  # vergelijken van de kolommen met de tabel
  my @extra_in_file = where_not_exists($normalized_file_cols, $table_cols);

  if (@extra_in_file) {
    $data_log->warn("Excel sheet `$sheet_name' has extra columns: " . join(', ', @extra_in_file) . " !");
  }

  my @missing_in_file = where_not_exists($table_cols, $normalized_file_cols);

  if (@missing_in_file) {
    $data_log->error("Excel sheet `$sheet_name' has missing columns: " . join(', ', @missing_in_file) . " !");
  }

  # Maak de tabel leeg en vul op
  $dbh->do("truncate $table") or do { ERROR("Failed to truncate `$table'. Error: " . $dbh->errstr); return };

  my @active_cols = where_exists($file_cols, $table_cols);

  if (@active_cols == 0) { ERROR("Excel sheet `$sheet_name': no columns left to process !"); return }

  #print STDERR "Active cols : ", Dumper(@active_cols);

  my $active_col_count = $#active_cols;

  # prepare statement
  my $sth = do_prepare($dbh, "INSERT INTO $table (" . join (', ', map { "`$_`" } @active_cols) . ") VALUES (" . join (', ', map { '?' } @active_cols) . ")");

  unless ($sth) { ERROR("Excel sheet `$sheet_name': failed to prepare insert statement !"); return }

  # For performance, we make an array of indexes of the columns in the source file that we want to extract
  # The order of the columns must match the above INSERT statement.
  # Additionally we do some checks

  # Hier doen we het anders dan bij de ESL load.
  # Ik neem enkel de cellen uit de sheet die we willen, eventueel via een conversie functie
  # die de data omzet van excel formaat naar een mysql formaat (het gaat dan over datetime)

  my $column_index;
  my $transform_sub;
  my $active_col_type;

  foreach my $c (@active_cols) {
    # search in normalized_file_cols
    my $i;
    for ($i = 0; $i <= $#$normalized_file_cols; $i++) {
      last if ($c eq $normalized_file_cols->[$i]);
    }

    if ($i > $#$normalized_file_cols) {
      ERROR("Excel sheet `$sheet_name': Column $c not found in the normalized file columns. This should not happen !");
      die;
    }

    push @$column_index, $i;

    my $type = $htable_col_info->{$c}->{TYPE};

    push @$active_col_type, $htable_col_info->{$c};

    if ($type eq 'datetime') {
      push @$transform_sub, \&transform_datetime;
    } elsif ($type eq 'double') {
      push @$transform_sub, \&transform_double;
    } elsif ($type =~ m/^varchar\(/) {
      push @$transform_sub, \&transform_varchar;
    } elsif ($type =~ m/^int\(/) {
      push @$transform_sub, \&transform_int;
    }
    else {
      die "unknown type $type\n";
    }
  }

  #print Dumper($column_index);
  #print Dumper($transform_sub);
  #print Dumper($active_col_type);

  ##
  ## Lezen data en inladen
  ##

  my $source_row_count = 0;     # starten vanaf 1 en de header lijn erbij => +2

  for (my $row = $row_min + 1; $row <= $row_max; $row++) {

    my $source_row;

    my $data_cnt = 0;

    for (my $i = 0; $i <= $#$column_index; $i++) {

      my $cell = $small_cell_data->[$row][$column_index->[$i]];
      #my $cell = $worksheet->get_cell($row, $col_min + $column_index->[$i] );

      unless ($cell) {
        push @$source_row, undef;
        next;
      }

      my $value = &{ $transform_sub->[$i] }($cell, $active_col_type->[$i]);

      push @$source_row, $value;

      $data_cnt++ if (defined $value && $value ne '');
    }

    # sometimes a row has nothing but undef values !
    next unless ($data_cnt > 0);

    # check aantal cols
    if ($#$source_row != $active_col_count) {
      $data_log->error("Excel sheet `$sheet_name': Invalid nr of columns (line nr ${\($source_row_count + 2)}) : " . join(', ', map { defined $_ ? $_ : 'UNDEF' } @$source_row));
      next;
    }

    # pass the data of the file in the correct order
    $sth->execute( @$source_row ) or
      do { ERROR("failed to insert row (line nr ${\($source_row_count + 2)}) : " . join(', ', map { $_ || 'NULL' } @$source_row)); $source_row_count-- };

    $source_row_count++;

    #exit if ($source_row_count > 5);
  }

  return $source_row_count;
}

# ==========================================================================

1;
