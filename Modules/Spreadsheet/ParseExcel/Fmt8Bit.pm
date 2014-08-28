# Spreadsheet::ParseExcel::Fmt8Bit
#  by Pauwel Coppieters
# based on work by Kawai, Takanori (Hippo2000) 2001.2.2
#==============================================================================
package Spreadsheet::ParseExcel::Fmt8Bit;
use Spreadsheet::ParseExcel::FmtDefault;

use strict;

our (@ISA, $VERSION);

@ISA = qw(Spreadsheet::ParseExcel::FmtDefault);

$VERSION = substr q$Revision: 1.5 $, 10;

#------------------------------------------------------------------------------
# new (for Spreadsheet::ParseExcel::Fmt8Bit)
#------------------------------------------------------------------------------
sub new($;%) {
    my($sPkg, %hKey) = @_;
    my $oThis = {};
    bless $oThis;
    return $oThis;
}
#------------------------------------------------------------------------------
# TextFmt (for Spreadsheet::ParseExcel::Fmt8Bit)
#------------------------------------------------------------------------------

## conversion of special chars in a spreadsheet -> to 8-bit entities
## ^S | 0x13 | '-'  | &ndash;
## ^Y | 0x19 | '`'  | &lsquo;  left single quotation mark
## ^Z | 0x1A | '´'  | &rsquo;  right single quotation mark
## ^\ | 0x1C | '``' | &ldquo;  left double quotation mark
## ^] | 0x1D | '´´' | &rdquo;  right double quotation mark
##             '<<' | &laquo;  left-pointing double angle quotation mark
##             '>>' | &raquo;  right-pointing double angle quotation mark
## ?? | ???? | '''  | &apos;   apostrophe (but this name does not exist in HTML 4.01 -> use &#39;

# 32 172 | 0x20 0XAC | euro sign (dit komt altijd voor in de format strings van excel sheets)

# wat met ^M (carriage return ?)

sub TextFmt($$;$) {
    my($oThis, $sTxt, $sCode) = @_;

    my $text;

    if ((! defined($sCode)) || ($sCode eq '_native_')) {

      foreach my $char (split('', $sTxt)) {

#	if ($char eq "\r")  { $char = "\n"; }

	$text .= $char;
      }
    } else {

	# sTxt is a string with 2 bytes per character
	# normal characters have a MSB of ^@
	# special chars seem to have somethings else as MSB

	foreach my $wchar (unpack('n*', $sTxt)) {
	    my ($msb, $lsb) = unpack('CC', pack('n', $wchar));
	    my $char;

	    my $message =
"I found a 16-bit character in the spreadsheet that I can't map (yet)
to an 8-bit value. Look in the result for the string 8BIT_CONV_PROBLEM
to locate the guilty character !";

	    if    ($msb == 0) {
		$char = pack('C', $lsb);

#		if ($char = "\r") { $char = "\n"; }

	    }
	    elsif ($msb == 32) {
		if    ($lsb == 19) { $char = pack('C', 0226); }
		elsif ($lsb == 24) { $char = pack('C', 0221); }
		elsif ($lsb == 25) { $char = "'"; }
		elsif ($lsb == 28) { $char = pack('C', 0223); }
		elsif ($lsb == 29) { $char = pack('C', 0224); }
		elsif ($lsb == 38) { $char = pack('C', 0205); }
		elsif ($lsb == 172) { $char = pack('C', 0200); }
		else               {
                  our $char_hash;

                  print STDERR "WARNING: $message (technical info : msb = $msb, lsb = $lsb)\n" unless defined $char_hash->{$lsb};
                  $char_hash->{$lsb}++;

                  $char = '8BIT_CONV_PROBLEM1';
                }


	    } else {
		print STDERR "WARNING: $message (technical info : msb = $msb, lsb = $lsb)\n";
                $char = '8BIT_CONV_PROBLEM2';
	    }

	    ##		printf "msb = %d, lsb = %d, $char\n", $msb, $lsb;
	    $text .= $char;
	}
    }

    return $text;
}
#==============================================================================
1;
