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

Module specific for ci_create_ddl.pl and ci_load_data.p, to reduce the module count for these two scripts

=cut

package CI_Util;

use strict;
use warnings;
use Carp;
use Log::Log4perl qw(:easy);
use Text::CSV_XS;

use Data::Dumper;

BEGIN {
  use Exporter ();
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK);

  $VERSION = '1.0';

  @ISA         = qw(Exporter);

  @EXPORT    = qw();

  @EXPORT_OK = qw(scan_ci_csv csv_header
                  from_AA
                  get_xls_column_number
                  get_xls_worksheet_cell
                  subtract_array
                  where_exists
                  where_not_exists
                  duplicates
                );
}

# ==========================================================================
# CSV helper functions
# ==========================================================================

=pod

scan csv for ci types, used columns and column lengths

Return a structure like this :

$VAR1 = {
          'terminalserver' => {
                                'ROWS' => 353,
                                'COLS' => {
                                            'data_operationstate' => [ 'M', 8 ],
                                            'host_model' => [ 'O', 58 ],
                                            ...
                                            'sm_data_primary_incident_resolution_group' => [ 'O', 21 ],
                              },
          ...
          }


This is a hash, with the different ci_type as keys.
ROWS = the number of rows with this ci_type

For every ci_type, list the columns with
data. 'M' means mandatory. This means the column always has data. 'O' means optional. This means the
column sometimes has data. The second element is the maximum byte length of the column

=cut

sub scan_ci_csv {
    my $csv_file = shift;

    my $type_column = 'ci_type';

    my $ioref = new IO::File;
    $ioref->open("< $csv_file") or die("ERROR: open `$csv_file' failed : $^E\n");

    my $csv = Text::CSV_XS->new ({ always_quote => 0, blank_is_undef => 0, binary => 1, quote_null => 0, allow_loose_quotes => 1, eol => "\n" });
    #my $csv = Text::CSV_XS->new ({ always_quote => 0, blank_is_undef => 0, binary => 1, quote_null => 0, eol => "\n" });

    unless ($csv) {
        ERROR("".Text::CSV_XS->error_diag());
        return;
    }

    # I believe this file in in code page 1252
    binmode $ioref, ':crlf:encoding(cp1252)';
    #binmode $ioref;

    # direct de header lezen ?
    my $header = $csv->getline($ioref);

    unless (defined $header) {
        ERROR("Failed to read HEADER from the csv file `$csv' !");
        $ioref->close;
        return;
    }

    my $col_count = $#$header;

    my $header_index;
    my $i = 0;
    map { $header_index->{$_} = $i++ } (@$header);

    my $type_column_i = $header_index->{$type_column};

    my $line_nr = 0;

    my $data;
    my $has_data;
    my $data_len;

    # Reading the CSV file is tricky (the file has dangling quotes)

    while (1) {
        while (my $row = $csv->getline($ioref)) {
            #print STDERR "row = ", Dumper($row);

            $line_nr++;
            # check number of columns

            if ($#$row != $col_count) {
                ERROR("Invalid nr of columns at line `$line_nr' !");
            }

            my $type = $row->[$type_column_i];
            #print "$type\n";

            # remove type column
            #print Dumper($row);
            #splice @$row, $type_column_i, 1;
            #print Dumper($row);

            $data->{$type}{ROWS}++;

            for (my $i = 0; $i <= $col_count; $i++) {
                next if ($i == $type_column_i); # skip type column

                my $col_name = $header->[$i];

                my $value = $row->[$i];

                unless (defined $value) {
                    ERROR("Undefined column value at line `$line_nr', column $i !");
                    next;
                }

                my $l;
                if ($value =~ m/^\s*$/) {
                  # no data in this column
                  $value = 0;
                  $l = 0;
                }
                else {
                  $l = length($value);
                  $value = 1;
                }


                $data_len->{$type}{$col_name} = 0 unless (exists $data_len->{$type}{$col_name});

                if ($l > $data_len->{$type}{$col_name}) {
                    $data_len->{$type}{$col_name} = $l;
                }

                # Count the number of times the column has data (=> to determine 'M' or 'O')
                $has_data->{$type}{$col_name}{$value}++;
            }
        }

        # getline returns undef => either are done or it is an error
        last if ($csv->eof);

        print "ERROR at line $line_nr: ";
        $csv->error_diag ();

        $line_nr++;
    }

    my $current_pos = unpack 'I', $ioref->getpos;

    $ioref->seek (0, 2);

    my $end_pos = unpack 'I', $ioref->getpos;

    if ($current_pos != $end_pos) {
        ERROR("CSV file `$csv_file' was not read till the end !");
        $ioref->close;
        return;
    }

    $ioref->close;

    # now only keep the columns with some data

    #print Dumper($data);

    foreach my $type (keys %$data) {
        my $cnt = $data->{$type}{ROWS};

        foreach my $col (keys %{$has_data->{$type}}) {
            my $data_cnt = $has_data->{$type}{$col}{1};
            my $empty_cnt = $has_data->{$type}{$col}{0};

            $data_cnt = 0 unless (defined $data_cnt);
            $empty_cnt = 0 unless (defined $empty_cnt);

            if ($data_cnt + $empty_cnt != $cnt) {
                die "Internal error !";
            }

            if ($data_cnt + $empty_cnt == 0) {
                die "Internal error !";
            }

            if ($data_cnt == $cnt) {
                $data->{$type}{COLS}{$col}[0] = 'M';
                $data->{$type}{COLS}{$col}[1] = $data_len->{$type}{$col};
            }
            elsif ($empty_cnt == $cnt) {
              # don't keep this column
            }
            else {
                $data->{$type}{COLS}{$col}[0] = 'O';
                $data->{$type}{COLS}{$col}[1] = $data_len->{$type}{$col};
            }
        }

        # XXX The columns display_label, root_createtime, root_lastaccesstime, root_updatetime
        # are available in every CI type, but they are not really data from the CI => skip those.

        foreach my $col ('display_label', 'root_createtime', 'root_lastaccesstime', 'root_updatetime') {
          delete $data->{$type}{COLS}{$col};
        }
    }

    return $data;
}

# ==========================================================================

sub csv_header {
  my $csv_file = shift;

  my $ioref = new IO::File;
  $ioref->open("< $csv_file") or do { ERROR("open `$csv_file' failed : $^E\n"); return; };

  my $csv = Text::CSV_XS->new ({ always_quote => 0, blank_is_undef => 0, binary => 1, quote_null => 0, eol => "\n" });

  unless ($csv) {
    ERROR("".Text::CSV_XS->error_diag());
    return;
  }

  # I believe this file is in code page 1252
  binmode $ioref, ':crlf:encoding(cp1252)';

  # direct de header lezen ?
  my $header = $csv->getline($ioref);

  $ioref->close;

  return $header;
}

# ==========================================================================
# XLS helper functions
# ==========================================================================

sub fromAA ($) {
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

sub get_xls_column_number {
  confess("Illegal argument count") unless (@_ == 2);
  my ($oSheet, $title) = @_;

  my $column;

  my $iR = $oSheet->{MinRow};

  my $count = 0;
  for (my $iC = $oSheet->{MinCol}; defined $oSheet->{MaxCol} && $iC <= $oSheet->{MaxCol}; $iC++) {
    my $cell = get_xls_worksheet_cell($oSheet, $iR, $iC, 4);
    next unless (defined $cell);
    ($count++, $column = $iC) if ($cell eq $title);
  }

  if ($count == 0) {
    my $bfile = basename($oSheet->{_Book}->{File});
    ERROR("Column `$title' not found in `$bfile' !");
    return;
  }
  elsif ($count == 1) {
    return $column;
  }
  else {
    my $bfile = basename($oSheet->{_Book}->{File});
    ERROR("Duplicate column `$title' found in `$bfile' !");
    return;
  }
}
# =========================================================================

# return cleaned up data from excel cell
# an empty cell (even with space) returns undef

sub get_xls_worksheet_cell {
  my ($oSheet, $iR, $iC, $trim_spaces) = (shift, shift, shift, shift);
  my $rtc;

  if ($oSheet->{Cells}[$iR][$iC] && defined $oSheet->{Cells}[$iR][$iC]->Value)
    {
      my $d = $oSheet->{Cells}[$iR][$iC]->Value;

      # trim leading and trailing spaces

      if ($trim_spaces == 4) { # trim both leading and trailing spaces and emdedded newlines
	$d =~ s/^\s*//;
	$d =~ s/\s*$//;
        $d =~ s/\n/ /g;
        $d =~ s/\s+/ /g;

      } elsif ($trim_spaces == 3) { # trim both leading and trailing spaces
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


sub subtract_array {
  my ($aref1, $aref2) = @_;

  # a1 - a2

  my $h_aref1 = { map { $_ => 1 } @$aref1 };

  foreach (@$aref2) {
    delete $h_aref1->{$_} if (exists $h_aref1->{$_});
  }

  return [ sort keys %$h_aref1 ];

}

# ==========================================================================

=item where_exists(a, b)

Gegeven een array a, geef alle elementen van a die bestaan in b (met behoud van de volgorde van a)
Dit is dus een subset van a.

b kan een array zijn, of een enkel element

=cut

sub where_exists {
  LOGCONFESS "usage: where_exists(a, b)" unless @_ == 2;

  my ($a, $b) = @_;

  my %h;

  unless (ref($b)) {
    %h = map { $_ => 1 } $b;
  }
  elsif (ref($b) eq 'ARRAY') {
    %h = map { $_ => 1 } @$b;
  }
  else {
    WARN("Invalid parameter: $b");
    return;
  }

  my @tmp = grep { exists $h{$_} } @$a;

  return @tmp;
}

# ==========================================================================

=item where_not_exists(a, b)

Gegeven een array a, geef alle elementen van a die NIET bestaan in b (met behoud van de volgorde van a)
Dit is dus een subset van a.

De elementen blijven in volgorde. Elementen die dubbel voorkomen blijven dubbel voorkomen.

=cut

sub where_not_exists {
  LOGCONFESS "usage: where_not_exists(a, b)" unless @_ == 2;

  my ($a, $b) = @_;

  my %h;

  unless (ref($b)) {
    %h = map { $_ => 1 } $b;
  }
  elsif (ref($b) eq 'ARRAY') {
    %h = map { $_ => 1 } @$b;
  }
  else {
    WARN("Invalid parameter: $b");
    return;
  }

  my @tmp = grep { ! exists $h{$_} } @$a;

  return @tmp;
}

# ==========================================================================

=item duplicates(a)

Gegeven een ARRAY of ARRAYREF a, geef alle elementen van a die meerdere keren voorkomen
Return value is een ARRAY met de duplicates.

=cut

sub duplicates {
  my $a;

  if (@_ == 1 && ref($_[0]) eq 'ARRAY') {
    $a = $_[0];
  }
  else {
    $a = [ @_ ];
  }

  my @tmp = grep { defined $_ } @{$a};

  if (@tmp != @{$a}) {
    WARN("Set::duplicates: array has undefined values. These are ignored.\n");
  }

  my %h;
  map { $h{$_}++; } @tmp;
  my @duplicates = grep { $h{$_} > 1; } keys %h;

  return @duplicates;
}

# ==========================================================================


1;
