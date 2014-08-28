# ==========================================================================
# $Source: /export/development/cvs/aro/Tools/Library/ErrorMessage.pm,v $
# $Author: u75706 $ [U75706 (EDS)]
# $Date: 2004/10/14 11:06:50 $
# CDate: Thu Oct 17 17:44:51 2002
# $Revision: 1.4 $
#
# ==========================================================================
#
# ident "$Id: ErrorMessage.pm,v 1.4 2004/10/14 11:06:50 u75706 Exp $ [EDS]"
#
# ==========================================================================

#
##
## Module for trace, warnings, errors, info
## Messages of same type go to the same destination (global
## for the application : trace file, error log, ...)
##
#

######################################################################
package ErrorMessage;
######################################################################

use strict;
use Carp;
use IO::Scalar;
use Fcntl;

use Data::Dumper;

# constants

sub E_INVAL ()  { 1 }		# the user gave some invalid data
sub E_RANGE ()  { 2 }		# a value is out of range
sub E_NFOUND () { 3 }		# not found
sub E_EXIST ()  { 4 }		# a value already exists

sub E_NFILE ()  { 5 }		# File does not exists
sub E_EMPTY ()  { 6 }		# No data
sub E_NOEXEC () { 7 }		# Can't lauch
sub E_OFLOW ()  { 8 }		# overflow
sub E_FAULT ()  { 9 }		# Some global error we don't know exactly what

sub E_2BIG  () { 10 }		# value is to big
sub E_2MANY () { 11 }		# more than allowed

sub E_MAX () { E_2MANY }

## message types

sub M_INFO () { 1 }		# informational messages
sub M_WARN () { 2 }		# warnings
sub M_ERROR () { 3 }		# errors
sub M_TRACE () { 4 }		# tracing (for debugging purposes)

sub M_MIN () { M_INFO }
sub M_MAX () { M_TRACE }

# ==========================================================================

BEGIN {
  use Exporter ();

  my @e_constants  = qw(E_INVAL E_RANGE E_NFOUND E_EXIST E_NFILE E_EMPTY E_NOEXEC E_OFLOW E_FAULT E_2BIG E_2MANY);
  my @e_subs = qw(error error_init error_set error_flush error_clear error_num error_msg);

  my @m_constants =  qw(M_INFO M_WARN M_ERROR M_TRACE);
  my @m_subs = qw(message_init message message_set message_flush message_clear);

  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

  # set the version for version checking
  $VERSION = substr q$Revision: 1.4 $, 10;
  @ISA         = qw(Exporter);

  @EXPORT      = ( );

  @EXPORT_OK = (@e_constants, @e_subs, @m_constants, @m_subs);

  %EXPORT_TAGS = (
		  ERROR => [(@e_constants, @e_subs)],
		  MESSAGE => [(@m_constants, @m_subs)]
		 );

}

# --------------------------------------------------------------------

INIT {
  for (my $i = M_MIN; $i <= M_MAX; $i++) {
    message_init($i);
  }
}

# --------------------------------------------------------------------

our %Message;
our %MessageBuffer;
our $ErrorNum;
our $ErrorMsg;

# ==========================================================================

# Any error in these function will result in a confess. The error
# handling should work without any flaws.
# We never have to check the return value of the error fuctions

# ==========================================================================

# TODO XXX :
# should we confess when arg count is wrong ?
# eg. error_num doesn't care -> shouldn't we continue ?

#
# Output flags :
# -> perror like string (yes or no)
# -> file / line
# -> a stack trace ? (where we are called from ?)#
# -> exit on error (STOP_ON_ERROR optie : default no, main program should decide to stop)
# -> flush moment (immediate / deferred, on newline, on everey call, ...)
# -> timestap
# -> user
# -> prefix for message type (INFO, WARN, ...)
# -> prefix moment (eg. prefix, timestamp : everey line, every block, every call, ...)
#
# Attributes
# - Type
# - Level (the higher the level, the more messages)
# - Message text
# - exit code: bv. via optie EXIT => $code
# - output channel (stderr, log file)

# All these parameters should be set in messages_init
# output is through format string -> decide on %X characters, so we can control the formatting

# ==========================================================================

# Usage XXX :
# enable warnings / or more error detail -w  of -d x, met x een level
# on the command line -> how do we call init ???

# --------------------------------------------------------------------

# this function returns undef so it can be used in a return statement
# the undef is not an indication of failure

sub error {
  confess("Illegal argument count") unless (@_ >= 2 && (scalar(@_) % 2) == 0);
  my ($err, $msg, %options) = @_;

  confess ("Illegal error number `$err'") unless ($err >= 0 && $err <= E_MAX);

  $ErrorNum = $err;
  $ErrorMsg = $msg;		# unprocessed error message

#  use Carp qw(cluck);
#  cluck($msg);

  message(M_ERROR, 1, $msg, %options);

  return wantarray ? () : undef;
}

# --------------------------------------------------------------------

sub error_init {
  confess("Illegal argument count") unless (@_ >= 0 && (scalar(@_) % 2) == 0);
  message_init(M_ERROR, @_);
  return;
}

# --------------------------------------------------------------------
# set attribute for the error handler

sub error_set {
  confess "Illegal argument count" unless (@_ == 2);
  return message_set(M_ERROR, @_);
}

# --------------------------------------------------------------------

sub error_flush {
  confess "Illegal argument count" unless (@_ == 0);
  return message_flush(M_ERROR);
}

# --------------------------------------------------------------------

sub error_clear {
  confess "Illegal argument count" unless (@_ == 0);
  $ErrorNum = 0;
  $ErrorMsg = '';
  return message_clear(M_ERROR);
}

# --------------------------------------------------------------------

sub error_num {
  confess "Illegal argument count" unless (@_ == 0);
  return $ErrorNum;
}

sub error_msg {
  confess "Illegal argument count" unless (@_ == 0);
  return $ErrorMsg;
}

# ==========================================================================
# Messages
# ==========================================================================

sub message_init {
  confess("Illegal argument count") unless (@_ >= 1 && (scalar(@_) % 2) == 1);
  my ($type, %options) = @_;

  confess "Illegal message type `$type'" unless ($type >= M_MIN && $type <= M_MAX);

  my (%allowed_options, @wrong_options);

  %allowed_options = map { $_ => 1 } qw(LEVEL FH PREFIX);
  # check for options
  @wrong_options = grep { ! $allowed_options{$_}; } keys %options;

  confess "Illegal option : `$wrong_options[0]'" if (@wrong_options > 0);

  my ($level, $out, $prefix);

  $level = (defined $options{LEVEL}) ? $options{LEVEL} : 0;
  $out = $options{FH} ? $options{FH} : *STDERR;


  if ($type == M_INFO) {
    $out = $options{FH} ? $options{FH} : *STDOUT;
    $prefix = $options{PREFIX} ? $options{PREFIX} : 'INFO';
  }
  elsif ($type == M_WARN) {
    $prefix = $options{PREFIX} ? $options{PREFIX} : 'WARN';
  }
  elsif ($type == M_ERROR) {
    # default behaviour: error messages are shown
    $level = (defined $options{LEVEL}) ? $options{LEVEL} : 1;
    $prefix = $options{PREFIX} ? $options{PREFIX} : 'ERROR';
  }
  elsif ($type == M_TRACE) {
    $prefix = $options{PREFIX} ? $options{PREFIX} : 'TRACE';
  }

  message_set($type, LEVEL => $level);
  message_set($type, FH => $out);
  message_set($type, PREFIX => $prefix);

  return;
}

# --------------------------------------------------------------------

# options given to the message call are for this call only

sub message {
  confess("Illegal argument count") unless (@_ >= 3 && (scalar(@_) % 2) == 1);
  my ($type, $level, $msg, %options) = @_;

  confess "Illegal message type `$type'" unless ($type >= M_MIN && $type <= M_MAX);

  ## options processing
  # XXX no options allowed for the moment
  confess("No options allowed yet !") if (keys(%options) > 0);

  my ($prefix, $fh);

  return unless ($level <= $Message{$type}{LEVEL});

  $prefix = $Message{$type}{PREFIX};
  $fh = $Message{$type}{FH};

  $msg .= "\n" unless ($msg =~ m/\n$/);

  ## XXX always immediate output for the moment, hmmm

  return unless (defined $fh);

  print $fh "$prefix: $msg"  or confess "print failed !";

  return;
}

# --------------------------------------------------------------------
# set attribute of the message output object
#
# type : the class of the message (warnings, errors, ...)
# key/value : the attribute to set and it's value

sub message_set {
  confess "Illegal argument count" unless (@_ == 3);
  my ($type, $key, $value) = @_;
  my ($old_value);

  # print "message_set : type = $type, key = $key, value = $value\n";

  confess "Illegal message type `$type'" unless ($type >= M_MIN && $type <= M_MAX);

  if ($key eq 'LEVEL') {
    $old_value = $Message{$type}{$key};
    $value = 9 if ($value > 9);
    $value = 0 if ($value < 0);
    $Message{$type}{$key} = $value;

  } elsif ($key eq 'PREFIX') {
    $old_value = $Message{$type}{$key};
    $Message{$type}{$key} = "$value";

  } elsif ($key eq 'FH') {
    $old_value = $Message{$type}{$key};

    my $fh;

    if ( ! defined $value) {	# value undefined -> no output
      $fh = undef;
    }
    elsif ( ! ref($value)) {
      if (UNIVERSAL::isa(\$value, 'GLOB')) { # een glob (geen ref)
	$fh = $value;
	confess "No associated fileno !" unless (defined fileno($fh));
	binmode($fh) or confess("Couldn't swicth to binmode !");
      }
      elsif ($value eq '-') {	# Special file name `-' XXX could this also mean STDERR ???
	$fh = new IO::Handle;
	# XXX gracefully reopen STDOUT ???
	$fh->fdopen(fileno(STDOUT), "w") or confess "fdopen `STDOUT' failed !";
	confess "No associated fileno !" unless (defined fileno($fh));
	binmode($fh) or confess("Couldn't swicth to binmode !");
      }
      else {			# a simple file name
	$fh = new IO::File;
	$fh->open("> $value") or confess "open `$value' failed !";
	confess "No associated fileno !" unless (defined fileno($fh));
	binmode($fh) or confess("Couldn't swicth to binmode !");
      }
    }
    else {			# a reference
      if (UNIVERSAL::isa($value, 'IO::Handle')) {
        if (UNIVERSAL::isa($value, 'IO::Scalar')) {
          $fh = $value;
        }
        else {
          $fh = $value;
          confess "No associated fileno !" unless (defined fileno($fh));
          binmode($fh) or confess("Couldn't swicth to binmode !");
        }
      }
      elsif (UNIVERSAL::isa($value, 'GLOB')) {
	confess "Should be GLOB ref !\n" unless (ref($value) eq 'GLOB');
	$fh = $value;
	confess "No associated fileno !" unless (defined fileno($fh));
	binmode($fh) or confess("Couldn't swicth to binmode !");
      }
      elsif (ref($value) eq 'SCALAR') {
        # seems to be a bug (or at least very strange behaviour to me)
        # if $value is a REFERENCE to a SCALAR with an undefined value

        # after the new, $fh is normal object
        # after the open, $fh in not defined any more, but is still an IO::Scalar object
        # so we can have something that iss undefined and blessed ???
        # so to avoid this I initialize value, and then $fh stays defined.

        $$value = '';           # initialize the value

	$fh = new IO::Scalar;
	$fh->open($value, O_WRONLY) or confess "open `" . ref($value) . "' failed !\n";
      } else {
	confess("Illegal FH value `$value' !");
      }
    }

    $Message{$type}{$key} = $fh;
  } else {
    confess "Illegal message option `$key'";
  }

  return $old_value;
}

# --------------------------------------------------------------------

sub message_flush {
  confess "Illegal argument count" unless (@_ == 1);
  my ($type) = (shift);

  confess "Illegal message type `$type'" unless ($type >= M_MIN && $type <= M_MAX);

  my ($buffer);

  return unless ($buffer = $MessageBuffer{$type}); #  nothing to flush

  confess "Illegal buffer type" unless (ref($buffer) eq 'ARRAY');

  foreach my $msg (@$buffer) {
    print { $Message{$type}{FH} } $msg or confess "print failed !";
  }

  message_clear($type);

  return;
}

# --------------------------------------------------------------------

sub message_clear {
  confess "Illegal argument count" unless (@_ == 1);
  my ($type) = (shift);
  confess "Illegal message type `$type'" unless ($type >= M_MIN && $type <= M_MAX);

  $MessageBuffer{$type} = [];

  return;
}


# ==========================================================================
# Tracing
# ==========================================================================

# trace : PID.trc.txt 
# at runtime
# output to : file strings, ... (zie IO::
# sturen van trace info : level, verbositeit, stack
#
# keywords : kenmerk van trace : niet dezelfde mate van detail
# van de boodschappen: bepaalde stukken zeer gedetailleerd.
# doel is bepaalde stukken nauwkeurig te kunnen volgen

# --------------------------------------------------------------------

END {
##  flush everything
}       # module clean-up code here (global destructor)

# --------------------------------------------------------------------

1;  # don't forget to return a true value from the file
