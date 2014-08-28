# ==========================================================================
# $Source$
# $Author$ [pauwel]
# $Date$
# CDate: Fri May 25 14:40:57 2012
# $Revision$
#
# ==========================================================================
#
# ident "$Id$"
#
# ==========================================================================

package IniUtil;

=pod

=cut

use strict;
use warnings;
use Carp;
use File::Spec;
use Cwd;
use Config::IniFiles;
use Log::Log4perl qw(:easy);
use Data::Dumper;

BEGIN {
  use Exporter ();
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK);

  $VERSION = '1.0';

  @ISA         = qw(Exporter);

  @EXPORT    = qw();

  @EXPORT_OK = qw(load_alu_ini get_alu_ini);
}

# ================================================================================
{

  my $alu_cfg;
  my $alu_ini_file;

  sub load_alu_ini {
    confess "usage: load_alu_ini([ options ])" unless @_ < 2;

    my $attr  = shift || {};

    # By default, look for the ini-file in the properties subfolder of the current directory
    my $INI_FOLDER = File::Spec->catdir(cwd(), 'properties');
    $INI_FOLDER = $attr->{ini_folder} if (exists $attr->{ini_folder});

    my $current_alu_ini_file = File::Spec->catfile($INI_FOLDER, 'alu.ini');


    # Never read more than one ini-file, to avoid confusion about what file is actually used.
    if (defined $alu_ini_file) {
      # Warn, if the ini file location changes
      # Possible causes :
      # - use of a module that calls "get_alu_ini" BEFORE the main script calls "load_alu_ini".
      # - multiple calls to load_alu_ini with different parameters
      unless ($alu_ini_file eq $current_alu_ini_file) {
        WARN("Multiple ini-file locations passed ($alu_ini_file, $current_alu_ini_file). This can cause confusion. We stick with `$alu_ini_file'");
      }

      # but re-read the same file is allowed

      if (defined $alu_cfg) {
        DEBUG("Re-reading ini file ...");
        my $rv = $alu_cfg->ReadConfig;

        unless (defined $rv) {
          ERROR("Failed to re-read the ini file `$alu_ini_file'");
          $alu_cfg = undef;
          return;
        }

        return $alu_cfg;
      }
    }
    else {
      $alu_ini_file = $current_alu_ini_file;
    }

    unless (-f $alu_ini_file) {
      ERROR("alu.ini ini-file `$alu_ini_file' does not exists !");
      return;
    }

    DEBUG("Reading ini file `$alu_ini_file' ...");
    $alu_cfg = new Config::IniFiles( -file => $alu_ini_file );

    unless (defined $alu_cfg) {
      ERROR("Failed to parse ini-file `$alu_ini_file' !");
      return;
    }

    # Additional check if a section name is passed
#    if (exists $attr->{ini_section}) {
#      my $section = $attr->{ini_section};
#
#      unless ($alu_cfg->SectionExists($section)) {
#        ERROR("Section `$section' does not exists in $alu_ini_file !");
#        return;
#      }
#    }

    return $alu_cfg;
  }

  sub get_alu_ini {

    return $alu_cfg if (defined $alu_cfg);

    # for main scripts that don't load the ini-file, we load the ini-file now.
    # The possibility to switch to an ini-file in a different loaction is lost, but thats ok because
    # the main script has no $opt_ini parameter in the first place.

    return load_alu_ini();
  }

}

# ================================================================================

1;
