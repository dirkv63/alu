# ==========================================================================
# $Source$
# $Author$ [pauwel]
# $Date$
# CDate: Thu Jun 14 12:34:44 2012
# $Revision$
#
# ==========================================================================
#
# ident "$Id$"
#
# ==========================================================================

=pod

TODO
- als waarden undef zijn een lege sting in de CSV steken
- write met DOS EOL (ook vanop unix)

Schrijven van de 'csv' files die gebruik worden door de JAVA toepassing

classe variabele : timestamp

Default filedir = "d:/temp/alucmdb/";

Mogelijke waarden van comp_name
Application, ComputerSystem, Datacenter, Hardware, InstalledProduct, Person, Product, ProductInstance, Renaming, cd

Mogelijke waarden van tabname
AssignedContactList,Component,DBInstance,ESL,LocationList,NoteList,PrdInstalledOnCS,PrdInstalledPrd,ProcessorList,RemoteAccessList,Renaming,ServiceFunctionLiServiceLevelList,SystemUsageList,WebInstance,appComposition,appInstComposition,appInstDependsUponCS,bladeInEnclosure,clusterComposition,clusterPackageCompositidodgyRelationships,farmComposition,farmManager,physicalSrvrOnHardware,prdInstOfInstalledPrd,prdInstRelationships,virtualSrvrOnCS


$filename = $filedir . $source . "_" . $comp_name . "_" . $tabname . "_" . $ts . ".csv";

source = 'master'

create_acronym_renaming.pl:	my $filename = $filedir . "master_application_renaming_" . $ts . ".csv";
my $comp_name = "Application"; 	my $tabname = "Renaming";

create_ci_renaming.pl:	my $filename = $filedir . "master_Renaming_component_" . $ts . ".csv";
my $comp_name = "Renaming";	my $tabname = "Component";

create_person.pl:	my $filename = $filedir . "master_Person_component_" . $ts . ".csv";
my $comp_name = "Person"; my $tabname = "Component";

create_locations.pl:	my $filename = $filedir . "master_DataCenter_component" . "_" . $ts . ".csv";
comp_name = "Datacenter"; my $tabname = "";


=cut

package TM_CSV;

use strict;
use warnings;
use Carp;
use File::Spec;
use Config::IniFiles;
use Cwd;
use Log::Log4perl qw(:easy);

use Data::Dumper;

# Make sure that all files have the same time tick stamp
our $timestamp = time;

BEGIN {
  use Exporter ();
  our ($VERSION, @ISA);

  $VERSION = '1.0';

  @ISA         = qw(Exporter);
}

my %def_attr = (
                filedir     => undef,
                source      => undef,
                comp_name   => undef,
                tabname     => undef,
                suffix      => undef,
                version     => undef,
               );

# ==========================================================================

=item new(file, { attributes, ... } )

Attributes are :
                filedir
                source
                comp_name
                tabname
                suffix
                version

Default is filedir = "d:/temp/alucmdb", maar dat kan je hier overschrijven

=cut

sub new {
  my $oThis = shift;

  my $class = ref($oThis) || $oThis or return;
  @_ > 0 &&   ref $_[0] ne "HASH"  and return;
  my $attr  = shift || {};

  #print STDERR Dumper($attr);

  for (keys %{$attr}) {
    if (m/^[a-z]/ && exists $def_attr{$_}) {
      next;
    }

    WARN("Unknown attribute `$_' !");
    return;
  }


  # overschrijven met info uit de alu.ini (als die bestaat)
  # Daarmee kan ik ook aan mijn unix folders

  my $ini_datadir;

  my $INI_FOLDER = File::Spec->catdir(cwd(), 'properties');

  if (-d $INI_FOLDER) {
    ## Lees de alu.ini file

    my $alu_ini = File::Spec->catfile($INI_FOLDER, 'alu.ini');

    if (-f $alu_ini) {
      my $alu_cfg = new Config::IniFiles( -file => $alu_ini );
      unless (defined $alu_cfg) {
        ERROR("failed to parse ini-file `$alu_ini'");
      }
      else {
        if ($alu_cfg->SectionExists('DEFAULT')) {
          if ($alu_cfg->val('DEFAULT', 'DS_STEP1')) {
            $ini_datadir = $alu_cfg->val('DEFAULT', 'DS_STEP1');
          }
        }
      }
    }
  }

  # we fall back on d:\temp\log if there is no useable ini file
  my $datadir = (defined $ini_datadir) ? $ini_datadir : 'd:\temp\alucmdb';

  my $self;

  if ($attr->{filedir}) {
    $self->{filedir} = $attr->{filedir};
  } else {
    $self->{filedir} = $datadir;
  }


  foreach my $a (qw(source comp_name tabname suffix version)) {
    $self->{$a} = $attr->{$a} if (defined $attr->{$a});
  }

  bless $self, $class;


  my $filedir = $self->{filedir} if (defined $self->{filedir});
  my $source = $self->{source} if (defined $self->{source});
  my $comp_name = $self->{comp_name} if (defined $self->{comp_name});
  my $tabname = $self->{tabname} if (defined $self->{tabname});
  my $suffix = $self->{suffix} if (defined $self->{suffix});
  my $version = $self->{version} if (defined $self->{version});

  #
  unless (-d $filedir) {
    ERROR("output directory `$filedir' ain't a directory !");
    return;
  }

  unless (defined $source && $source ne "") {
    ERROR("source is not set !");
    return;
  }

  # op passen : soms bevat source speciale tekens (':' bijvoorbeeld), en daar kan windows niet tegen
  $source =~ s/:/%/g;

  unless (defined $comp_name && $comp_name ne "") {
    ERROR("comp_name is not set !");
    return;
  }

  # tabname kan leeg zijn
  unless (defined $tabname) {
    ERROR("tabname is not defined !");
    return;
  }


  # normaal de SVN versie van de template sheet waarop we ons baseren
  $version = '1000' unless (defined $version && $version ne "");

  my $basefile = $source . "_" . $comp_name;

  if (defined $tabname && $tabname ne '') {
    $basefile .= '_' . $tabname;
  }

  if (defined $suffix && $suffix ne '') {
    $basefile .= '_' . $suffix;

    # opdat de HEADER lijn identiek zou zijn aan vroeger
    $tabname .= '_' . $suffix;
  }

  # speciale logica om compatibel te zijn met oude quircks

  if ($basefile =~ m/^master_application_renaming$/i) {
    $basefile = 'master_application_renaming';
  }
  elsif ($basefile =~ m/^master_renaming_component$/i) {
    $basefile = 'master_Renaming_component';
  }
  elsif ($basefile =~ m/^master_person_component$/i) {
    $basefile = 'master_Person_component';
  }
  elsif ($basefile =~ m/^master_datacenter_component$/i || $basefile =~ m/^master_datacenter$/i)  {
    $basefile = 'master_DataCenter_component';
  }

  my $filename = File::Spec->catfile($filedir, $basefile . "_" . $timestamp . ".csv");

  $self->{FILE} = $filename;

  # bestaande file
  if (-f $filename) {
    ERROR("output file `$filename' already exists !");
    return;
  }

  my $ioref = new IO::File;
  $ioref->open("> $filename");

  if (not defined $ioref) {
    ERROR("could not open `$filename' for writing !");
    return;
  }


  $self->{_IO} = $ioref;

  binmode $ioref, ':crlf :encoding(UTF-8)';

  # Cremers, Michel : Pauwel, voor ons zijn alleen de 1e, 2e en laatste kolom van het header record
  # van belang, dus H, component name en EOR. De rest negeren we.

  # Print Header Line

  # Afwijkende HEADERs (XXX volgens mij zijn dat fouten , maar kom)
  # Volgens Michel zijn dat geen fouten (zie bv. bug 386), maar de uitleg waarom deze headers moeten
  # afwijken heb ik egenlijk niet begrepen.
  if (   ($comp_name eq 'ProductInstance' && $tabname eq 'DBInstance')
      || ($comp_name eq 'ProductInstance' && $tabname eq 'WebInstance')
      || ($comp_name eq 'ProductInstance' && $tabname eq 'ApplicationInstance')) {
    $self->{_IO}->print(join ('|', ('H', $tabname, $version, 'EOR', '')) . "\n");
  }
  else {
    $self->{_IO}->print(join ('|', ('H', $comp_name, $tabname, $version, 'EOR', '')) . "\n");
  }

  # Initialize Counter
  $self->{CNT} = 0;

  return $self;

}

# ==========================================================================

=item write

Write a line of data
 - warn if all the columns are empty or undef
 - since we don't use Text::CSV_XS, replace undef values with an empty string.
 - check for '|' in the data (an give a data warning)
 - replace EOL charachters with <br>


		my @outarray = ($LeftName, $RightName, $directory, "EOR");
		print PrdCS "D$delim" . join($delim, @outarray) . "\n";
		$prdcs_cnt++;

TODO :

mekkeren als er een kolom undef is ?


=cut

sub write {
  my $self = shift;
  my @data = @_;

  my $data_log = Log::Log4perl->get_logger('Data');


  unless (defined $self->{COL_CNT}) {
    $self->{COL_CNT} = @data;
  }

  unless ($self->{COL_CNT} == @data) {
    WARN("invalid number of columns !");
  }

  $self->{CNT}++;

  foreach (@data) {
    $_ = '' unless defined $_;
  }

  my $some_data = 0;

  foreach (@data) {
    next if ($_ eq '');

    $some_data++;

    if ($_ =~ m/\|/) {
      $data_log->warn("Replace pipe symbol in data `$_'");
      $_ =~ s/\|/!/g;
    }

    $_ =~ s/\r\n|\r|\n/<br>/g;
  }

  if ($some_data) {
    $self->{_IO}->print(join('|', ('D', @data, 'EOR')) . "\n");
  }
  else {
    $data_log->warn("Completely empty record not written to output file");
  }
}

# ==========================================================================

=item close

	# Product Installed On ComputerSystem
	my @tl = ("T", "Total", $prdcs_cnt, "EOR");
	print PrdCS join ($delim, @tl), "$delim";
	close PrdCS;


=cut

sub close {
  my $self = shift;

  if (defined $self->{_IO}) {
    my $cnt = $self->{CNT};

    # !! zonder newline !
    $self->{_IO}->print(join ('|', ('T', 'Total', $cnt, 'EOR', '')));

    $self->{_IO}->close();

    if ($cnt == 0) {
      my $data_log = Log::Log4perl->get_logger('Data');

      my $file = $self->{FILE};

      $data_log->debug("No records written to the TM csv file `$file'");
    }

  }
  else {
    ERROR("No IO handle defined, close failed !");
    return;
  }

  return $self;
}

# ==========================================================================

1;
