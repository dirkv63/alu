# ==========================================================================
# $Source$
# $Author$ [pauwel]
# $Date$
# CDate: Tue Jul 12 15:24:21 2011
# $Revision$
#
# ==========================================================================
#
# ident "$Id$"
#
# ==========================================================================

package Set;

use strict;
use warnings;
use Carp;
use Log::Log4perl qw(:easy);

use Data::Dumper;

BEGIN {
  use Exporter ();
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK);

  $VERSION = '1.0';

  @ISA         = qw(Exporter);

  @EXPORT    = qw();

  @EXPORT_OK = qw(intersection
                  where_exists
                  where_not_exists
                  duplicates
                  multiple_occurences);
}

# ==========================================================================

=item intersection

return an array ref to the intersection of two array refs

=cut

sub intersection {
  confess "usage: intersection(a, b)" unless @_ == 2;

  #my $a, $b;
}


# ==========================================================================

=item where_exists(a, b)

Gegeven een array a, geef alle elementen van a die bestaan in b (met behoud van de volgorde van a)
Dit is dus een subset van a.

b kan een array zijn, of een enkel element

Array's met undefined values :
 - ofwel elk element checken met defined
 - ofwel deze eruit gooien

=cut

sub where_exists {
  confess "usage: where_exists(a, b)" unless @_ == 2;

  my ($a, $b) = @_;

  my $b_ref;

  unless (ref($b)) {
    $b_ref = [ $b ];
  }
  elsif (ref($b) eq 'ARRAY') {
    $b_ref = [ @$b ];
  }
  else {
    ERROR("Set::where_exists: Invalid parameter: b");
    return;
  }


  my @a_tmp = grep { defined $_ } @$a;

  if (@a_tmp != @$a) {
    WARN("Set::where_exists: first array has undefined values. These are ignored.\n");

    
  }

  my @b_tmp = grep { defined $_ } @$b_ref;

  if (@b_tmp != @$b_ref) {
    WARN("Set::where_exists: second array has undefined values. These are ignored.\n");
  }

  my %h = map { $_ => 1 } @b_tmp;

  my @tmp = grep { exists $h{$_} } @a_tmp;

  return @tmp;
}

# ==========================================================================

=item where_not_exists(a, b)

Gegeven een array a, geef alle elementen van a die NIET bestaan in b (met behoud van de volgorde van a)
Dit is dus een subset van a.

De elementen blijven in volgorde. Elementen die dubbel voorkomen blijven dubbel voorkomen.

=cut

sub where_not_exists {
  confess "usage: where_not_exists(a, b)" unless @_ == 2;

  my ($a, $b) = @_;

  my $b_ref;

  unless (ref($b)) {
    $b_ref = [ $b ];
  }
  elsif (ref($b) eq 'ARRAY') {
    $b_ref = [ @$b ];
  }
  else {
    ERROR("Set::where_not_exists: Invalid parameter: b");
    return;
  }


  my @a_tmp = grep { defined $_ } @$a;

  if (@a_tmp != @$a) {
    WARN("Set::where_not_exists: first array has undefined values. These are ignored.\n");
  }

  my @b_tmp = grep { defined $_ } @$b_ref;

  if (@b_tmp != @$b_ref) {
    WARN("Set::where_not_exists: second array has undefined values. These are ignored.\n");
  }

  my %h = map { $_ => 1 } @b_tmp;

  my @tmp = grep { ! exists $h{$_} } @a_tmp;

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

=item multiple_occurences(a)

Gegeven een array a, geef alle elementen van a die meerdere keren voorkomen

De elementen blijven in volgorde.

Dat wil zeggen dat die elementen ook N keer voorkomen in het resultaat.

=cut

sub multiple_occurences {
  my $a;

  if (@_ == 1 && ref($_[0]) eq 'ARRAY') {
    $a = $_[0];
  }
  else {
    $a = [ @_ ];
  }

  my @tmp = grep { defined $_ } @{$a};

  if (@tmp != @{$a}) {
    warn("Set::multiple_occurences: array has undefined values. These are ignored.\n");
  }

  my %h;
  map { $h{$_}++; } @tmp;
  my @duplicates = grep { $h{$_} > 1; } keys %h;

  return where_exists(\@tmp, \@duplicates);
}

# ==========================================================================

1;
