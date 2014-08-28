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

package ALU_Util;

=pod

Elementary functions that are copied all over the place ...

=cut

use strict;
use warnings;
use utf8;
use Carp;
use DBI;
use Log::Log4perl qw(:easy);
use DbUtil qw(do_prepare do_select singleton_select sth_singleton_select do_stmt do_execute create_record rcreate_record);
use Set qw(duplicates where_not_exists multiple_occurences);

use Data::Dumper;


BEGIN {
  use Exporter ();
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK);

  $VERSION = '1.0';

  @ISA         = qw(Exporter);

  @EXPORT    = qw();

  @EXPORT_OK = qw(exit_application

                  reserve_acronym_name

                  use_acronym_name
                  is_acronym_name_used

                  normalize_acronym
                  is_normalized_acronym

                  add_unique_acronym_name

                  trim
                  get_info_type
                  init2blank
                  get_recordid
                  create_available_record
                  val_available
                  rval_available
                  is_true
                  replace_cr
                  remove_cr
                  getsource
                  getsourcesystem
                  update_record
                  add_ip add_note
                  get_field
                  check_table

                  ovsd_person a7_person esl_person

                  cons_fqdn
                  hw_tag
                  installed2instance
                  translate
                  ntranslate
                  os_translation
                  conv_date
                  fqdn_ovsd
                  tx_resourceunit
		  get_virtual_esl
                  normalize_file_column_names
                  validate_row_count
                  glob2pat
                  generate_portfolio_id
                  load_uuid
                  all_uuids
                  current_uuids
                  get_uuid
                  remove_uuid
                  add_uuid

                );
}

# ==========================================================================

sub exit_application($) {
  my ($return_code) = @_;

  my $summary_log = Log::Log4perl->get_logger('Summary');
  $summary_log->info("Exit application with error code $return_code.");

  exit($return_code);
}

# ==========================================================================
#
# Pure copies of the routines from dbParams_aluCMDB.pm, but with logging based on Log4perl.
# We need most of the routines, so we can avoid 'use'-ing dbParams_aluCMDB
#
# ==========================================================================

sub trim {
    my @out = @_;
    for (@out) {
        s/^\s+//;
        s/\s+$//;
    }
    return wantarray ? @out : $out[0];
}

# ==========================================================================

sub get_recordid($$$$) {
  return DbUtil::get_recordid($_[0], $_[1], $_[2], $_[3]);
}

# ==========================================================================

=pod

=head2 create_available_record(database_handle, tablename, array of fieldnames, array of fieldvalues)

This procedure will create a record in the table if the array of field values is not completely empty.
Fieldnames are in the array fieldnames, field values are in the array of field values.

Return value is the ID of the record that has been inserted - or blank if no record was inserted because the input was all empty.
If the insert failed for some reason, undef is returned.

=cut

sub create_available_record ($$$$) {
  my ($dbt, $table) = @_;
  my (@fields) = @{$_[2]};
  my (@values) = @{$_[3]};

  # check if there are any values
  my $val_available = 0;
  foreach ( @values ) {
    if ( defined $_ && length($_) > 0 ) {
      $val_available = 1;
      last;
    }
  }

  return '' unless ($val_available);

  my $statement = "INSERT INTO $table (" . join (', ', map { "`$_`" } @fields) . ") VALUES (" . join (', ', map { "?" } @fields) . ")";

  do_stmt($dbt, $statement, undef, @values) or return;

  my $id = $dbt->{'mysql_insertid'} || '';

  return $id;
}

# ==========================================================================

=pod

=head2 Get Field(database_handle, tablename, field, array of fieldnames, array of fieldvalues)

This procedure will get the field value for the fields in array. If the record doesn't exist, it will return an empty string.

This is used for example to extract admin_id record, to add application type group.

=cut

sub get_field($$$$$) {
  return DbUtil::get_field($_[0], $_[1], $_[2], $_[3], $_[4]);
}
# ==========================================================================

sub check_table($$$$) {
  my ($dbh, $table, $colcnt, $rowcnt) = @_;

  my $data_log = Log::Log4perl->get_logger('Data');

  # Check number of columns
  my $sth = do_execute($dbh, "SELECT * FROM `$table` LIMIT 1") or return;

  if (my @refarray = $sth->fetchrow_array) {
    my $ret_col = @refarray;
    if ($ret_col == $colcnt) {
      $data_log->info("$colcnt columns expected, found!");
    } else {
      $data_log->warn("$colcnt columns expected, found $ret_col");
    }
  } else {
    ERROR("Could not extract row to count columns, exiting...");
    return;
  }

  # Now check the number of rows
  # Use margin of 10%
  my $margin = int($rowcnt * 0.1);
  $sth = do_execute($dbh, "SELECT count(*) as cnt FROM `$table`") or return;

  if (my $ref = $sth->fetchrow_hashref) {
    my $rows = $ref->{cnt};
    if ( ($rows < ($rowcnt - $margin)) || ($rows > ($rowcnt + $margin))) {
      $data_log->warn("$rows found, $rowcnt expected with margin of $margin");
    } else {
      $data_log->info("$rows found, $rowcnt expected with margin of $margin");
    }
  } else {
    ERROR("Could not extract row count, exiting...");
    return;
  }

  return;
}

# ==========================================================================

=pod

=head2 Initialize System Identification / System Configuration Types

This subroutine is used to determine the network information type. Network information is either Configuration information or Identification Information. In CIM Configuration information is modelled differently than Identification Information, hence it needs to be provided in different files.

=cut

sub get_info_type($) {
  my ($ip_type) = @_;

  # Initialize variables
  my $id = "Identification";
  my $cfg = "Configuration";
  my $ignore = "Ignore";
  my (%info_type, $network_info);

  # Initialize hash
  $info_type{"Alias"} = $id;
  $info_type{"Alternate IP"} = $id;
  $info_type{"Backup LAN"} = $cfg;
  $info_type{"Cluster Name"} = $id;
  $info_type{"deinstalled"} = $id;
  $info_type{"Device WWN"} = $id;
  $info_type{"DNS Server"} = $cfg;
  $info_type{"Gateway"} = $cfg;
  $info_type{"Heartbeat LAN"} = $id;
  $info_type{"Internet facing IP"} = $id;
  $info_type{"Load Balanced IP"} = $id;
  $info_type{"Management LAN"} = $id;
  $info_type{"NAT"} = $id;
  $info_type{"NIC"} = $id;
  $info_type{"NTP Server"} = $cfg;
  $info_type{"Package Name"} = $id;
  $info_type{"Primary IP"} = $id;
  $info_type{"Primary WINS Server"} = $cfg;
  $info_type{"Radia detected - change"} = $cfg;
  $info_type{"Remote Service Board IP"} = $id;
  $info_type{"Secondary WINS Server"} = $cfg;
  $info_type{"Storage Array"} = $cfg;
  $info_type{"Storage Management Server"} = $cfg;
  $info_type{"Third WINS Server"} = $cfg;
  $info_type{"Virtual Connect IP"} = $id;
  $info_type{"Virtual IP"} = $id;
  $info_type{"Virtual Network Interface"} = $id;

  if (defined $info_type{$ip_type}) {
    $network_info = $info_type{$ip_type};
  } else {
    $network_info = "Not defined";
  }

  return $network_info;
}

# ==========================================================================

=pod

=head2 Get Source getsource(dbhandle, table, field)

This procedure will get the source identifiers. The source identifier is anything before the first _ character in the table.field.
Multiple Source identifiers will be returned as a string with delimiter charachter as delimiter.

=cut

sub getsource($$$) {
  my ($dbh, $table, $field) = @_;

  my $query = "SELECT distinct substring_index($field,'_',1) as source FROM $table";
  my $sth = $dbh->prepare($query);
  my $rv = $sth->execute();
  if (not defined $rv) {
    ERROR("Could not execute query $query, Error: ".$sth->errstr);
    return;
  }
  my $sources = [];

  while (my $ref = $sth->fetchrow_hashref) {
    push @$sources, $ref->{source} || "";
  }

  return wantarray ? @$sources : $sources;
}


# ==========================================================================

=pod

=head2 Get Source getsourcesystem(dbhandle, table, field)

This procedure will get the sourcesystem. The source system is anything before the first _ character and before the first - character in the table.field.

There should be one sourcesystem only.

=cut

sub getsourcesystem($$$) {
  my ($dbh, $table, $field) = @_;
  my $sourcesystem;
  my $query = "SELECT $field as sourcesystem FROM $table
                                 LIMIT 0,1";
  my $sth = $dbh->prepare($query);
  my $rv = $sth->execute();
  if (not defined $rv) {
    ERROR("Could not execute query $query, Error: ".$sth->errstr);
    return;
  }

  if (my $ref = $sth->fetchrow_hashref) {
    $sourcesystem = $ref->{sourcesystem} || "";
    ($sourcesystem, undef) = split /_/, $sourcesystem;
    ($sourcesystem, undef) = split /-/, $sourcesystem;
  }
  return $sourcesystem;
}

# ==========================================================================

=pod

=head2 update_record(database_handle, tablename, array of fieldnames, array of fieldvalues)

This procedure is used to update the record with identifier in the first position in the fieldnames and fieldvalues.

=cut

sub update_record($$$$) {
  my ($dbh, $table) = @_;
  my (@fields) = @{$_[2]};
  my (@values) = @{$_[3]};
  my ($updatestring);
  # quote values according to db specifications
  my @values_w = map { $dbh->quote($_) } @values;
  # Create WHERE String
  my $wherefield = shift @fields;
  my $wherevalue = shift @values_w;
  # Create UPDATE String
  foreach my $field (@fields) {
    my $val = shift @values_w;
    $updatestring .= "$field = $val, ";
  }
  # Remove last ", " from the wherestring
  $updatestring = substr($updatestring, 0, -2);

  do_stmt($dbh, "SET SESSION sql_mode=''") or do { WARN("Can't set database in strict mode !"); };

  my $query = "UPDATE $table SET $updatestring WHERE $wherefield = $wherevalue";

  my $sth = $dbh->prepare($query);
  my $rv = $sth->execute();
  if (not defined $rv) {
    ERROR("Could not execute query $query, Error: ".$sth->errstr);
  }

  do_stmt($dbh, "SET SESSION sql_mode='STRICT_ALL_TABLES'") or do { WARN("Can't set database in strict mode !"); };

  return;
}

# ==========================================================================

=pod

=head2 Add IP

This procedure will add data to IP Connectivity and IP Attributes tables. It requires computersystem_id, IP Type, Network Type and Network Value.

It will try to find IP Type for the Computersystem. If not found, IP Connectivity information will be created. Then it will create the IP Attributes information.

The procedure will return ip_connectivity_id number, or blank if no records have been created.

=cut

sub add_ip($$$$$$) {
	my ($dbh, $computersystem_id, $ip_type, $ip_connectivity_id, $network_id_type, $network_id_value) = @_;
	$network_id_value = replace_cr($network_id_value);
	if (length($ip_connectivity_id) == 0) {
		my @fields = ("computersystem_id", "ip_type");
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		$ip_connectivity_id = create_record($dbh, "ip_connectivity", \@fields, \@vals);
	}
	# Now create IP Attribute information
	my @fields = ("ip_connectivity_id", "network_id_type", "network_id_value");
	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		my $ip_attributes_id = create_record($dbh, "ip_attributes", \@fields, \@vals);
	}
	return $ip_connectivity_id;
}

# ==========================================================================

=pod

=head2 Add Notes

This procedure will add Notes type and Notes Value information. It requires computersystem_id, Notes Type and Notes value.

The procedure will return notes_id or blank if no records have been created.

=cut

sub add_note($$$$) {
	my ($dbh, $computersystem_id, $note_type, $note_value) = @_;
	$note_value = replace_cr($note_value);
	my ($notes_id);
	my @fields = ("computersystem_id", "note_type", "note_value");
	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	if ( val_available(\@vals) eq "Yes") {
		$note_value = replace_cr($note_value);
		$notes_id = create_record($dbh, "notes", \@fields, \@vals) or return;
	}
	return $notes_id;
}

# ==========================================================================

=pod

=head2 Cons FQDN(hostname, domainname)

This procedure will combine a Hostname and Domainname into FQDN for Assetcenter. It will handle all hostname and domain name conversions in the same way.

=cut

sub cons_fqdn($$) {
	my ($hostname, $domainname) = @_;
	my ($fqdn);
	if (length($hostname) == 0) {
		$fqdn = "";
	} else {
		$fqdn = lc(trim($hostname)) . "." . lc(trim($domainname));
	}
	return $fqdn;
}

# ==========================================================================

=pod

=head2 HW Tag

This procedure will convert the AssetTag to a unique identifier. A AssetTag is the FQDN of the physical computer where it is running on. However as a new requirement, each key needs to be unique over the full range of CIs. Being unique within it's own CI type is no longer sufficient.

This procedure will make the AssetTag unique from the ComputerSystem fqdn, by adding a 'hw.' identifier in front of it.

When AssetTag is empty, then an empty string will be returned.

=cut

sub hw_tag($) {
  my ($hw_id) = @_;
  if (length($hw_id) > 0) {
    $hw_id = 'hw.' . trim($hw_id);
  } else {
    $hw_id = '';
  }
  return $hw_id;
}

# ==========================================================================

=pod

=head2 Instance2Installed

This procedure will convert an Instance Product Name to an Installed Product Name.

In the current configuration, there is only one instance per installed product. The system keeps track of instances. This procedure will prepend "INSTALLED "to a product instance name.

=cut

sub installed2instance($) {
  my ($installed_product_name) = @_;
  if (length($installed_product_name) > 0) {
    $installed_product_name = "INSTALLED " . $installed_product_name;
  } else {
    $installed_product_name = "";
  }
  return $installed_product_name;
}

# ==========================================================================

=pod

=head2 replace_cr($)

This procedure takes a variable as input and replaces all Control-M (Carriage Return) by <br> characters.

=cut

sub replace_cr($) {
  my ($var) = @_;
  # CR can be represented by \r\n (DOS), \n (UNIX) or \r (Old MAC)
  $var =~ s/\r\n|\r|\n/<br>/g;
  #     $var =~ s/\r\n|\r|\n|\x0D/<br>/g;
  return $var;
}

=head2 remove_cr($)

This procedure takes a variable as input and removes all Control-M (Carriage Return) characters.

=cut

sub remove_cr($) {
	my ($var) = @_;
	# CR can be represented by \r\n (DOS), \n (UNIX) or \r (Old MAC)
	$var =~ s/\r\n|\r|\n//g;
#	$var =~ s/\r\n|\r|\n|\x0D/<br>/g;
	return $var;
}

# ==========================================================================

=pod

=head2 Translate (dbhandle, component, attribute, sourcevalue, NotFoundHandling)

The Translate module will translate a one value into another value for a specific component and field.
Empty Source value can be translated into other value. Component-Source combination must be unique.

If no value is found, the sourcevalue is returned.

The attribute 'NotFoundHandling' specifies what to do if no value is found. Current possibilities are 'ErrMsg' (print an error message, return source value), 'ReturnCode' (log value not found, return 'NotFound'), 'SourceVal" (return the source value if nothing found - no error message).

Component value must be the component / input file that is currently processed, attribute should be as close as possible to the component/input file attribute value.

Do not use any of the special * or _ characters in A7 labels, since character encoding isn't friendly between MySQL, Excel and the different systems on which the application is running. And we don't go for the perfect world here.

=cut

sub translate($$$$$) {
  my ($dbh, $component, $attribute, $src_value, $errmsg) = @_;
  my ($tx_value);
  my $query = "SELECT tx_value
                             FROM translation
                                 WHERE component = '$component'
                                   AND attribute = '$attribute'
                                   AND src_value = '$src_value'";
  my $sth = $dbh->prepare($query);
  my $rv = $sth->execute();

  if (not defined $rv) {
    ERROR("Could not execute query $query, Error: ".$sth->errstr);
    return;
  }
  if (my $ref = $sth->fetchrow_hashref) {
    $tx_value = $ref->{tx_value} || "";
  } else {
    my $data_log = Log::Log4perl->get_logger('Data');

    $tx_value = $src_value; # Default behaviour for "SourceVal"

    if (lc($errmsg) eq "errmsg") {
      $data_log->error("No translation found for $src_value for component $component and attribute $attribute");
    } elsif (lc($errmsg) eq "returncode") {

      $data_log->warn("No translation found for $src_value for component $component and attribute $attribute");
      $tx_value = "NotFound";
    } elsif (lc($errmsg) eq "sourceval") {
	  # No processing required
	} else {
      $data_log->info("No translation found for $src_value for component $component and attribute $attribute (Unknown NotFoundHandling: $errmsg)");
    }
  }

  return $tx_value;
}

# ==========================================================================

# ==========================================================================

=pod

=head2 ntranslate (dbhandle, component, attribute, sourcevalue, defaultvalue)

Translate an enumeration value. In addition to the translate subroutine this routine also performs some "sensible" null handling:
- if the input value is undef => return undef
- if the input value is an empty string => return an empty string

Sometimes we have elists (enumeration lists) that are very stable. For example the ISO-2 code of a
language => these are easy, the enumeration mapping must be complete or it is an error.

Other elist are more like codes that come from a foreign system and are very volatile. At this point
we would like to specify what to do with unknown input values :
 - return the input value
 - return a default value (could be undef).

This are attributes at the level of the elist. In the cim datamodel, the translation table should be normalised in Elist 1--N Elist Values
But for now we solve it like this :

ntranslate with 4 parameters => must be an exact elist. missing values give a data error.
ntranslate with 5 parameters => is an approx elist, values can be missing. The fifth parameter is the
default value. If you pass the source value as fifth parameter, you will pass missing values unchanged.


=cut

sub ntranslate {
  my ($dbh, $component, $attribute, $src_value, $default_value) = @_;

  unless (@_ == 4 || @_ == 5) { ERROR("invalid number of arguments"); return; }

  # src_value = '' => '' (unless explicit mapping)
  # src_value = NULL (undef) => NULL (unless explicit mapping, but code does not supports this yet)
  #
  # @_ == 4 :
  # src_value = value => mapped_value or undef (+ error message)
  #
  # @_ == 5 :
  # src_value = value => mapped_value or default (+ info message)

  if (defined $src_value) {
    my $sth = do_execute($dbh, "SELECT tx_value FROM translation WHERE component = '$component' AND attribute = '$attribute' AND src_value = '$src_value'");
    unless ($sth) {
      ERROR("Internal error. Failed to query the cim.translation table !");
      return;
    }

    my $ary_ref = $sth->fetchall_arrayref();

    if ($sth->err) {
      my $query = $sth->{Statement};
      ERROR("Could not fetchall_arrayref query `$query'. Error: " . $sth->errstr);
      $sth->finish();
      return;
    }

    if (@$ary_ref == 1) {
      return $ary_ref->[0][0];
    }
    else {
      my $data_log = Log::Log4perl->get_logger('Data');

      # an error in the contents of the translation table
      if (@$ary_ref > 1) {
        my $query = $sth->{Statement};
        $data_log->error("singleton query `$query' returns too many rows !");
        $sth->finish();
        # take the first result
        return $ary_ref->[0][0];
      }

      # no data found
      else {

        return '' if ($src_value eq '');

        if (@_ == 4) {
          # no data found, only allowed if src_value is blank
          $data_log->error("No translation found for `$src_value' for component `$component' and attribute `$attribute'");
          return undef;
        }
        elsif (@_ == 5) {
          # no data found, this is not uncommon
          $data_log->info("No translation found for `$src_value' for component `$component' and attribute `$attribute'");
          return $default_value;
        }
      }
    }
  }
  else {
    # We could first query for "... AND src_value IS NULL", to allow a translation of a NULL value too, but we don't need that for now.

    return undef;
  }
}

# ==========================================================================

=pod

=head2 os_translation (dbhandle, os_name, os_version)

This will translate cmo os name and os version into FMO os class and os version.

=cut

sub os_translation($$$) {
	my ($dbh, $cmo_os_system, $cmo_os_version) = @_;
	my ($os_class, $os_version);
	if (length($cmo_os_system) == 0) {
		$os_class = "Unknown";
		$os_version = "Unknown";
	} else {
		my $query = "SELECT os_class, os_version
				     FROM os_translation
					 WHERE IFNULL(cmo_os_system, '') = '$cmo_os_system'
					   AND IFNULL(cmo_os_version, '') = '$cmo_os_version'";
		my $sth = $dbh->prepare($query);
		my $rv = $sth->execute();
		if (not defined $rv) {
			ERROR("Could not execute query $query, Error: ".$sth->errstr);
		}
		if (my $ref = $sth->fetchrow_hashref) {
			$os_class = $ref->{os_class} || "";
			$os_version = $ref->{os_version} || "";
		} else {
			ERROR("No translation for $cmo_os_system * $cmo_os_version");
			$os_class = "Unknown";
			$os_version = "Unknown";
			my @fields = ("cmo_os_system", "cmo_os_version", "os_class", "os_version");
			my (@vals) = map { eval ("\$" . $_ ) } @fields;
			my $os_translation_id = create_record($dbh, "os_translation", \@fields, \@vals);
		}
	}
	return ($os_class, $os_version);
}

# ==========================================================================

=pod

=head2 Convert Date

This procedure will convert the datefield from m/d/yyyy to yyyymmdd format.

This is used now for the Billing Change Date.

=cut

sub conv_date($) {
  my ($datefield) = @_;
  if (not(length($datefield) == 0)) {
    my ($mnt, $day, $year);
    if ($datefield =~ m/^(\d+)-(\d+)-(\d+) 00:00:00/) {
      ($year, $mnt, $day) = ($1, $2, $3);
    }
    else {
      ($mnt, $day, $year) = split /\//, $datefield;
    }

    # Check for integers in mnt, day, year
    if (($mnt =~ /^[0-9]*$/) &&
        ($day =~ /^[0-9]*$/) &&
        ($year =~ /^[0-9]*$/)) {
      # OK, all integers. Now valid month and day
      if (($mnt < 13) &&
          ($day < 32)) {
        $datefield = sprintf "%04d%02d%02d",$year, $mnt, $day;
      } else {
        error("Invalid date format $datefield");
        $datefield = "";
      }
    } else {
      error("Invalid date format $datefield");
      $datefield = "";
    }
  }
  return $datefield;
}


# ==========================================================================

=pod

=head2 FQDN OVSD

This procedure will investigate if there is a domain name attached to a system name. If not, then the domain name .no.dns.entry.com will be added.

ESL requires system names with domain names.

=cut

sub fqdn_ovsd($) {
	my ($fqdn) = @_;
	my @components = split /\./, $fqdn;
	my $nr_of_components = @components;
	if ($nr_of_components == 1) {
		$fqdn .= ".no.dns.entry.com";
	}
	return $fqdn;
}

# ==========================================================================

=pod

=head2 ResourceUnit Code translations

This section will translate the Billing Resource Unit Codes to the expected enumerated values.

Billing ResourceUnit Codes are expected in the format 'xX -', with or without a leading zero (small x). Three steps will be done in this procedure:

1. Recognize the pattern. Read the first 4 characters from the string. Trim the string and check the last character. If it is a '-', then this looks like a billing resourceunit code. Otherwise return blank string.

2. Split the string on blank. First part is enumeration index, second part is '-'.

3. Use the index to read the value for the billing code from the hash.

Update return codes - Transition Model uses both unknown and blanks.

The script allows to return the 2 character code or the ESL Group name for the Billing Resource Unit Code.

=cut

sub tx_resourceunit($) {
	my ($resourceunit) = @_;
	my ($code, $tx_resourceunit_code);

	# Initialize hash
	my (%resourceunitcodes);
	$resourceunitcodes{"01"} = "01 - Unix: Type A - High Availability/Clustered Servers";
	$resourceunitcodes{"02"} = "02 - Unix: Type B - High Complexity";
	$resourceunitcodes{"03"} = "03 - Unix: Type C - Medium Complexity";
	$resourceunitcodes{"04"} = "04 - Unix: Type D - Low Complexity";
	$resourceunitcodes{"05"} = "05 - Wintel: Type A - High Availability/Clustered Servers";
	$resourceunitcodes{"06"} = "06 - Wintel: Type B - High Complexity";
	$resourceunitcodes{"07"} = "07 - Wintel: Type C - Medium Complexity";
	$resourceunitcodes{"08"} = "08 - Wintel: Type D - Low Complexity";
	$resourceunitcodes{"09"} = "09 - Linux: Type A - High Availability/Clustered Servers";
	$resourceunitcodes{"0A"} = "0A - Not categorized";
	$resourceunitcodes{"0B"} = "0B- Not Billable - HP Managed";
	$resourceunitcodes{"0D"} = "0D- Not Billable - Not billable - HP Application Support";
	$resourceunitcodes{"0C"} = "0C - Not Billable - ALU Managed";
	$resourceunitcodes{"10"} = "10 - Linux: Type B - High Complexity";
	$resourceunitcodes{"11"} = "11 - Linux: Type C - Medium Complexity";
	$resourceunitcodes{"12"} = "12 - Linux: Type D - Low Complexity";
	$resourceunitcodes{"13"} = "13 - Other: Type A - High Availability/Clustered Servers";
	$resourceunitcodes{"14"} = "14 - Other: Type B - High Complexity";
	$resourceunitcodes{"15"} = "15 - Other: Type C - Medium Complexity";
	$resourceunitcodes{"16"} = "16 - Other: Type D - Low Complexity";
	$resourceunitcodes{"17"} = "17 - Platinum High Complexity Application";
	$resourceunitcodes{"18"} = "18 - Gold Application - High Complexity";
	$resourceunitcodes{"19"} = "19 - Silver Application - High Complexity";
	$resourceunitcodes{"20"} = "20 - Bronze Application - High Complexity";
	$resourceunitcodes{"21"} = "21 - Platinum Application - Medium Complexity";
	$resourceunitcodes{"22"} = "22 - Gold Application - Medium Complexity";
	$resourceunitcodes{"23"} = "23 - Silver Application - Medium Complexity";
	$resourceunitcodes{"24"} = "24 - Bronze Application - Medium Complexity";
	$resourceunitcodes{"25"} = "25 - Platinum Application - Low Complexity";
	$resourceunitcodes{"26"} = "26 - Gold Application - Low Complexity";
	$resourceunitcodes{"27"} = "27 - Silver Application - Low Complexity";
	$resourceunitcodes{"28"} = "28 - Bronze Application - Low Complexity";
	$resourceunitcodes{"29"} = "29 - Advanced Database Instance - High Complexity";
	$resourceunitcodes{"30"} = "30 - Business Database Instance - Medium Complexity";
	$resourceunitcodes{"31"} = "31 - Basic Database Instance - Low Complexity";
	$resourceunitcodes{"32"} = "32 - Usable Disk Storage GBs - Attached";
	$resourceunitcodes{"33"} = "33 - Usable Disk Storage GBs - Shared Tier 1 - Mission Critical";
	$resourceunitcodes{"34"} = "34 - Usable Disk Storage GBs - Shared Tier 2 - Business Critical";
	$resourceunitcodes{"35"} = "35 - Usable Disk Storage GBs - Shared Tier 3 - Mass Storage";
	$resourceunitcodes{"36"} = "36 - Usable Disk Storage GBs - Shared Tier 4 - Archive";
	$resourceunitcodes{"45"} = "45 - Hosting";
	$resourceunitcodes{"91"} = "91 - Non Billable - HP Managed";
	$resourceunitcodes{"99"} = "99 - Special Handling";



	# Process Resourceunit code
	if (length($resourceunit) > 0) {
		# Remove leading blanks
		$resourceunit = trim($resourceunit);
		# Get first 4 characters
		$resourceunit = substr ($resourceunit, 0, 4);
		# Now remove trailing blanks
		$resourceunit = trim($resourceunit);
		# Check if (last) character is '-'
		if (index($resourceunit, "-") > -1) {
			# Exception for code "0B-" and "0D-"
			if (($resourceunit eq "0B-") || ($resourceunit eq "0D-")) {
				$code = substr($resourceunit,0,2);
			} else {
				# OK, so split on blank to get code index
				($code, undef) = split /\ /, $resourceunit;
				if (length($code) == 1) {
					$code = "0" . $code;
				} elsif (not (length($code) == 2)) {
					ERROR ("Invalid code length for Resourceunit code $resourceunit");
					$code = "Unknown";
				}
			}
		} else {
			# Invalid Resource Unit Code, set to blank
			$code = "";
		}
		if (defined($resourceunitcodes{$code})) {
			$tx_resourceunit_code = $resourceunitcodes{$code};
		} else {
			$tx_resourceunit_code = "";
		}
	} else {
		$tx_resourceunit_code = "";
		$code = "";
	}

	return $code;
}

# ==========================================================================

=pod

=head2 Values Available val_available(array)

This procedure will check the array for values available. If a value with length > 0 is found, TRUE is returned, otherwise false.

=cut

sub val_available($) {
  foreach ( @{$_[0]} ) {
    return 'Yes' if ( defined($_) && length($_) > 0 );
  }

  # No values found with data, return FALSE
  return 'No';
}


=head2 rval_available(hrecord, [ array ])


This procedure will check the hash record for values available. If a value with length > 0 is found, TRUE is returned, otherwise false.
Only the attributes mentioned in array are checked. If array is missing, chek all the values

=cut

sub rval_available {
  my ($hrecord, $array) = @_;

  if (@_ >= 2) {
    foreach my $key (@$array) {
      if (exists $hrecord->{$key}) {
        return 1 if (defined $hrecord->{$key} && length($hrecord->{$key}) > 0);
      }
      else {
        ERROR("Invalid record key `$key'. Allowed keys are : " . join(', ', sort keys %$hrecord) . ".");
      }
    }
  }
  else {
    foreach my $key (keys %$hrecord) {
      return 1 if (defined $hrecord->{$key} && length($hrecord->{$key}) > 0);
    }
  }

  # No values found with data, return FALSE
  return 0;
}

# ==========================================================================

sub is_true {
  return unless (defined $_[0]);
  return 1 if ($_[0] =~ m/^True$/i || $_[0] =~ m/^Yes$/i || $_[0] =~ m/^Y$/i || $_[0] =~ m/^1$/);
  return 0;
}

# ==========================================================================

=pod

=head2 init2blank(database_handle, tablename, array of fields)

This procedure will replace null values by blanks for all fields in the array. This is required for SELECT WHERE statements. The union of (SELECT WHERE CONDITION) AND (SELECT WHERE NOT CONDITION) is not the complete set of records, since records where field values are NULL are excluded from both extracts.

=cut

sub init2blank ($$$) {
        my ($dbh, $table) = @_;
        my (@fields) = @{$_[2]};
        while (my $field = shift @fields) {
                do_stmt($dbh,"UPDATE `$table` SET `$field` = '' WHERE `$field` is NULL") or return;
        }

        return 1;
}


# ==========================================================================

=pod

=head2 OVSD Person

This script will take an OVSD Person and return the Person ID. Person Information in OVSD is Lastname, Firstname format. There is no email and no upi code. The person code is LASTNAME.FIRSTNAME.

A new person record will be created if none exists for this one.

=cut

sub ovsd_person($$$) {
	my ($dbt, $fname, $person_searchcode) = @_;
	my ($person_id);
	if (length($fname) == 0) {
		$person_id = "";
	} else {
		my ($lastname, $firstname) = split /,/ , $fname;
		$lastname = trim($lastname);
		$firstname = trim($firstname);
#		my $person_code = uc($lastname) . "." . uc($firstname);
		my $person_code = $person_searchcode;
		my @fields = ("person_code");
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		if ( val_available(\@vals) eq "Yes") {
			# Find record if it exists already
			$person_id = get_recordid($dbt, "person", \@fields, \@vals);
			if (length($person_id) == 0) {
				# Create person_id if it did not exist
				@fields = ("firstname", "lastname", "person_code", "person_searchcode");
				(@vals) = map { eval ("\$" . $_ ) } @fields;
				$person_id = create_record($dbt, "person",  \@fields, \@vals);
			}
		} else {
			$person_id = "";
		}
	}
	return $person_id;
}


# ================================================================================

=pod

=head2 A7 Person

This script will take a A7 Person and return the Person ID. Assetcenter person information is Lastname, Firstname - upi code. The upi code is the person code.

A new person record will be created if none exists for this one.

=cut

sub a7_person($$) {
	my ($dbt, $contactname) = @_;
	my ($person_id);
	# IT Contact always of the format comma dash
	# Include space before / after dash,
	# to distinguish with dash in family or first name.
	my ($name, $upi) = split / - /, $contactname;
	if (defined $upi && length($upi) > 0) {
		$upi = trim ($upi);
		# Find if person is defined already
		my $person_code = $upi;
		my @fields = ("person_code");
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		if ( val_available(\@vals) eq "Yes") {
			# Find record if it exists already
			$person_id = get_recordid($dbt, "person", \@fields, \@vals);
			if (length($person_id) == 0) {
				# Create person_id if it did not exist
				my ($lastname, $firstname) = split /,/, $name;
				$lastname = trim ($lastname);
				$firstname = trim($firstname);
				@fields = ("person_code", "firstname", "lastname", "upi");
				(@vals) = map { eval ("\$" . $_ ) } @fields;
				$person_id = create_record($dbt, "person",  \@fields, \@vals);
			}
		}
	} else {
		# Unexpected A7 Format
		# or no name available
		$person_id = "";
	}
	return $person_id;
}

# ================================================================================

=pod

=head2 ESL Person

This script will take ESL Person (email) and return the Person ID.

A new person record will be created if none exists for this one.

=cut

sub esl_person($$) {
  my ($dbt, $email) = @_;
  my ($person_id);
  if (length($email) == 0) {
    $person_id = "";
  } else {
    my $person_code = $email || "";
    my @fields = ("person_code");
    my (@vals) = map { eval ("\$" . $_ ) } @fields;
    if ( val_available(\@vals) eq "Yes") {
      # Find record if it exists already
      defined ($person_id = get_recordid($dbt, "person", \@fields, \@vals)) or return;
      if (length($person_id) == 0) {
        # Create person_id if it did not exist
        @fields = ("email", "person_code");
        (@vals) = map { eval ("\$" . $_ ) } @fields;
        $person_id = create_record($dbt, "person",  \@fields, \@vals) or return;
      }
    } else {
      $person_id = "";
    }
  }
  return $person_id;
}

# ================================================================================

# ==========================================================================
#
# Acronymen
#
# ==========================================================================

use constant ACRONYM_LENGTH => 31;

# --------------------------------------------------------------------------

# Regels :
# - vervang alle speciale tekens door '_'
# - vervang reeksen van meerde '_' door één enkele '_'
# - truncate op de maximale lengte
# - acronym moet uniek zijn.
#

sub normalize_acronym {
  my $acronym = shift;

  my $data_log = Log::Log4perl->get_logger('Data');

  unless (defined $acronym) {
    $data_log->error("The acronym is undefined and can not be normalized");
    return 'undefined_acronym';
  }

  if ($acronym =~ /^\s*$/ ) {
    $data_log->error("The acronym is empty and can not be normalized");
    return 'empty_acronym';
  }

  $acronym = lc($acronym);
  $acronym =~ s/[^0-9a-z]/_/g;
  $acronym =~ s/__*/_/g;
  $acronym =~ s/_$//;
  $acronym = substr($acronym, 0, ACRONYM_LENGTH);
  $acronym =~ s/_$//; # nog eens, want na een substr kan er weer een '_' als laatste char achterblijven.

  return $acronym;
}

# --------------------------------------------------------------------------

sub is_normalized_acronym {
  my $acronym = shift;
  my $msg = shift;

  unless (defined $acronym) {
    $$msg = "Invalid acronym : undef" if (ref($msg) eq 'SCALAR');
    return;
  }

  if (length($acronym) == 0) {
    $$msg = "Invalid acronym : empty string" if (ref($msg) eq 'SCALAR');
    return;
  }

  if (length($acronym) > ACRONYM_LENGTH) {
    $$msg = "Invalid acronym ($acronym): too long" if (ref($msg) eq 'SCALAR');
    return;
  }

#  unless ($acronym =~ m/^[0-9a-zA-Z_]+$/) {
  unless ($acronym =~ m/^[0-9a-z_]+$/) {
    $$msg = "Invalid acronym ($acronym): invalid characters" if (ref($msg) eq 'SCALAR');
    return;
  }

  return 1;
}

# ==========================================================================
#
# These subroutines manage the acronym set : a set of acronyms that are valid, normalized and unique
#
# ==========================================================================

{
  my $reserved_acronym_set;
  my $unique_acronym_set;

=item reserve_acronym_name(list)

Mark a set of acronym names as reserved by an external entity. Never let the acronym generator return them.

=cut

  sub reserve_acronym_name {
    my $list = shift;

    foreach (@$list) {
      $reserved_acronym_set->{$_}++;
      # The logic to reserve the normalized acronym too is wrong,
      # because I now exclude the acronyms I would normally generate from the appl_name_acronym column by normalizing it.
      # $reserved_acronym_set->{ normalize_acronym($_) }++;
    }

    return 1;
  }


=item use_acronym_name(name)

Mark a set of acronym names as in use, so we can check an acronym is unique.

=cut

  sub is_acronym_name_used {
    my $name = shift;

    return (exists $unique_acronym_set->{$name}) ? 1 : 0;
  }


  sub use_acronym_name {
    my $name = shift;

    my $data_log = Log::Log4perl->get_logger('Data');

    unless (is_normalized_acronym($name)) {
      $data_log->warn("Acronym `$name' is not normalised and should not be used !");
      return;
    }

    if (exists $unique_acronym_set->{$name}) {
      $data_log->warn("Acronym `$name' is not unique and should not be used more than once !");
      return;
    }

    $unique_acronym_set->{$name} = 0;

    return 1;
  }



=item add_unique_acronym_name

Return a unique acronym name, starting from a base name.

=cut

  sub add_unique_acronym_name {
    my $acronym = shift;

    my $base_acronym = $acronym;

    # we blijven het volgnummer verhogen tot we een uniek acronym bekomen.

    while (1) {
      if (! exists $unique_acronym_set->{$acronym} && ! exists $reserved_acronym_set->{$acronym}) {
        $unique_acronym_set->{$acronym} = 0;
        last;
      }

      $unique_acronym_set->{$base_acronym}++; # volgnummer om duplicate acronyms tegen te gaan

      my $volgnummer = $unique_acronym_set->{$base_acronym};

      # twee underscores voorkomt dat we toevalling clashen met een bestaande naam met een volgnummer
      # en maakt dat we de volgnummers van ons ook herkennen

      my $suffix = "__$volgnummer";
      my $l = length($suffix);

      $acronym = substr($base_acronym, 0, ACRONYM_LENGTH - $l) . $suffix;
    }

    unless (is_normalized_acronym($acronym)) {
      ERROR("The unique-ified acronym `$acronym' is invalid. This should not happen.");
      return $acronym;
    }

    return $acronym;
  }
}

# ==========================================================================

=item normalize_file_columns(column, column, ...)

normalize file column names so that they fit table creation in a mysql database
- max length of column name is 64 chars
- no duplicate column names allowed
- dots are removed from cols names by access => same logic

- the UTF-8 'DEGREE SIGN' is replaced with an underscore

=cut

sub normalize_file_column_names {
    my $columns;

    if (@_ == 1 && ref($_[0]) eq 'ARRAY') {
        $columns = $_[0];
    }
    else {
        $columns = [ @_ ];
    }

    # remove any dots in a name
    map { s/\.//g } @$columns;

    # replace 'degree sign' (0xC2 0xB0 or \302 \260) in a name with an underscore
    foreach (@$columns) {
      if (utf8::is_utf8($_)) {
        s/°/_/g;                # this degree sign is an utf-8 character (this source file is in utf-8)
      }
      else {
        s/\302\260/_/g;      # if the string was not decoded into utf-8, but contains raw utf-8 data
        s/\260/_/g;          # and this is the degree sign in iso-8859
      }
    }

    my @dups = multiple_occurences($columns);

    if (@dups) {
      my $data_log = Log::Log4perl->get_logger('Data');
      $data_log->warn("Import file has duplicate columns: " . join(', ', @dups) . " !");
    }

    my $seen = {};
    for (my $i = 0; $i <=$#$columns; $i++) {
        $seen->{$columns->[$i]}++;

        if ($seen->{$columns->[$i]} > 1) {
            $seen->{$columns->[$i]}--;

            #$columns->[$i] .= '_duplicate' . sprintf('%d', $i + 1);

            # zelfde logica als ms*access gebruiken
            $columns->[$i] = 'Field' . sprintf('%d', $i + 1);

            $seen->{$columns->[$i]}++;

            if ($seen->{$columns->[$i]} > 1) {
              my $data_log = Log::Log4perl->get_logger('Data');
              $data_log->error("Duplicate after duplicate. This is not supported !"); die;
            }
        }
    }

    $columns = _max_len_file_columns($columns);

    @dups = multiple_occurences($columns);

    if (@dups) {
      my $data_log = Log::Log4perl->get_logger('Data');
      $data_log->error("Duplicate after max length reduction. This is not supported !"); die;
    }

    return wantarray ? @$columns : $columns;
}


# pas op, een kolom naam in mysql is maximaal 64 chars lang !!

sub _max_len_file_columns {
    my $columns;

    if (@_ == 1 && ref($_[0]) eq 'ARRAY') {
        $columns = $_[0];
    }
    else {
        $columns = [ @_ ];
    }

    my @tmp = grep { length($_) > 64 } @$columns;

    if (@tmp) {
      my $data_log = Log::Log4perl->get_logger('Data');
      $data_log->warn("Import file has columns with overly long names: " . join(', ', @tmp) . " !");
    }

    map { $_ = substr($_, 0, 64) if (length($_) > 64) } @$columns;

    return wantarray ? @$columns : $columns;
}

# ==========================================================================


=item validate_row_count(expected, actual)

Return true if the difference between the actual number of rows and the expected number of rows is less than 10%.
Return false otherwise.


=cut


sub validate_row_count {
    my ($expected, $actual) = @_;

    # grens op 10 %
    if ($expected < 0) {
        WARN("Invalid number of expected rows ($expected) !\n");
        return;
    }

    if ($actual < 0) {
        WARN("Invalid number of actual rows ($actual) !\n");
        return;
    }

    if ($expected > 0) {
      my $i = (100 * ($expected - $actual)) / $expected;

      if ( abs((100 * ($expected - $actual)) / $expected) > 10) {
        return;
      }
    }
    else {
      # expected == 0 => moet juist zijn
      return unless ($expected == $actual);
    }

    return 1;
}

# ==========================================================================

=item glob2pat

transform a glob into a regexp

Allows to do file-like globbing on random arrays

=cut


sub glob2pat {
    my $globstr = shift;
    my %patmap = (
        '*' => '.*',
        '?' => '.',
        '[' => '[',
        ']' => ']',
    );
    $globstr =~ s{(.)} { $patmap{$1} || "\Q$1" }ge;
    return '^' . $globstr . '$';
}

# ==========================================================================
#
# Key-Value generator for portfolio id's
#
# ==========================================================================

{
  my $portfolio_id_sequence;
  my $reserved_portfolio_id;

=item reserve_portfolio_id(list)

Mark a set of portfolio id's as reserved by an external entity. Never return them.

=cut

  sub reserve_portfolio_id {
    my $list = shift;

    map  { $reserved_portfolio_id->{$_}++; } @$list;

    return 1;
  }

=item next_portfolio_id

return a new unique portfolio_id

=cut

  sub next_portfolio_id {
    unless (defined $portfolio_id_sequence) {
      $portfolio_id_sequence = 0;
    }

    $portfolio_id_sequence++;

    # TODO : put portfolio_id_sequence also in the list as a formatted string (char(4) or char(5))
    # so that we reserve both '1' and '0001' and '00001'
    while (exists $reserved_portfolio_id->{$portfolio_id_sequence}) {
      $portfolio_id_sequence++;
    }

    $reserved_portfolio_id->{portfolio_id_sequence} = 1;

    return $portfolio_id_sequence;
  }
}

# ================================================================================

=item generate_portfolio_id(dbh, key, [ preload ]).

Simple subroutine to generate a unique portfolio ID.
This is a number in the range 0001 - 9999 (represented as a character string).

We also pass the portfolio id's of the source systems, to avoid generating values that conflict with existing values.

Parameters : dbh is the database connection handle with the database that contains the uuid table.
key : the application key
preload : an optional list of reserved uuid's

We have in fact three sources of uuid's :
- the data that comes form the client source systems.
- the remembered uuid that where generated earlier.
- the currently generated uuid.

Conflicts can arise between remembered uuid's and client uuid's.



Generate a unique identifier for an item identified by 'key', and always generate the same
identifier. This is needed for portfolio_id's and acronyms.

Also pre-load the uuid_map with existing values of portfolio_id's and acronyms, so that we don't
generate a value that conflicts with an existing portfolio_id or acronym.

If the pre-load set is extended, and we now have a conflict, we simply remove the old generated row
and generate a new value.

So, at that moment the generated value is NOT stable (because of a conflict with the source).

We need to know whether a value is generated or not. If the value is generated, it should not be
passed in the preload set or we will report conflicts for all of them.


=cut

{
  my $all_uuids;

  sub generate_portfolio_id {
    my $dbh = shift;
    my $key = shift;
    my $preload = shift;

    my $generator_name = (caller(0))[3];

    # Do this only once
    unless (defined $all_uuids) {
      $all_uuids = all_uuids($dbh, $generator_name);
      # mark these portfolio_id as in use
      reserve_portfolio_id($all_uuids);
    }

    # These are the values that come from other sources (not generated). Is is not needed to pass it every time.
    if (defined $preload) {
      my $data_log = Log::Log4perl->get_logger('Data');

      reserve_portfolio_id($preload);

      my $used_uuids = current_uuids($dbh, $generator_name);

      # check for conflicts

      foreach my $uuid (@$preload) {
        if (grep { $uuid eq $_ } @$used_uuids) {

          # A (new) uuid value coming from the source systems conflicts with the remembered uuid values.
          # Remove this conflicting key from the stored/remembered set. It will be generated again if needed.

          my $conflicting_key = remove_uuid($dbh, $generator_name, $uuid) or return;

          $data_log->warn("Preload value `$uuid' conflicts with the generated/stored value for key `$conflicting_key'.");
        }
      }
    }

    # get stored uuid
    my $uuid = get_uuid($dbh, $generator_name, $key);
    return $uuid if (defined $uuid);

    # not found =>  generate a new uuid
    $uuid = next_portfolio_id();

    # and store it for later
    add_uuid($dbh, $generator_name, $key, $uuid);

    return $uuid;
  }
}
# ================================================================================
# UUID storage
# ================================================================================

=pod

This is the UUID store (UUID can be portfolio ID or acronym name).

There is a 1-to-1 relation between a key (application_tag for example) and a unique identifier.

=cut

{
  my $uuid_map;

  # --------------------------------------------------------------------------------

  # Load the remembered/stored uuid's from the database and perform some checks

  sub load_uuid {
    my ($dbh, $type) = @_;

    #print "load_uuid ($type)\n";

    my $data_log = Log::Log4perl->get_logger('Data');


    # only read the database once
    unless (defined $uuid_map->{$type}) {

      # get all the earlier generated key-value pairs.
      my $data = do_select($dbh, "
SELECT application_key, uuid_value
  FROM uuid_map
  WHERE uuid_type = '$type'
  ORDER BY uuid_map_id ASC");

      #print STDERR "data = ", Dumper($data);

      $uuid_map->{$type} = $data;
    }

    # UUID should be unique (even if they are not used any more)
    my $unique_uuid;
    foreach my $row (@{ $uuid_map->{$type} }) {
      my ($app_key, $uuid_value) = @$row;

      if (exists $unique_uuid->{$uuid_value}) {
          my $key2 = $unique_uuid->{$uuid_value};
          $data_log->error("UUID value `$uuid_value' for $type is not unique. It is used for key `$app_key' and for key `$key2'");
          # What to do ? I think this should not happen (if my code has no bugs :-).
        }

      $unique_uuid->{$uuid_value} = $app_key;
    }

    return 1;
  }

  # --------------------------------------------------------------------------------

  # return all uuids (in use or not) => to pass on the the uuid generator to avoid generating conflicting values

  sub all_uuids {
    my ($dbh, $type) = @_;

    load_uuid($dbh, $type);

    my $uuids;
    foreach my $row (@{ $uuid_map->{$type} }) {
      my ($app_key, $uuid_value) = @$row;
      $uuids->{$uuid_value}++;
    }

    return wantarray ? (keys %$uuids) : [ keys %$uuids ];
  }

  # --------------------------------------------------------------------------------

  # return all used uuids (to verify against the uuids from the external source systems)

  sub current_uuids {
    my ($dbh, $type) = @_;

    my $data_log = Log::Log4perl->get_logger('Data');

    load_uuid($dbh, $type);

    my $uuids;
    foreach my $row (@{ $uuid_map->{$type} }) {
      my ($app_key, $uuid_value) = @$row;

      # The same key has multiple matching rows. This is not abnormal, eg. if a value became a conflict, a new value has been generated.
      if (exists $uuids->{$app_key}) {
        my $old_uuid_value = $uuids->{$app_key};
        $data_log->info("Earlier value ($old_uuid_value) for key `$app_key' is now replaced with `$uuid_value'");
      }

      $uuids->{$app_key} = $uuid_value;
    }

    return wantarray ? (values %$uuids) : [ values %$uuids ];
  }

  # --------------------------------------------------------------------------------


  sub get_uuid {
    my ($dbh, $type, $key) = @_;

    load_uuid($dbh, $type);

    my $uuids;
    foreach my $row (@{ $uuid_map->{$type} }) {
      my ($app_key, $uuid_value) = @$row;
      # It can be that the same key has multiple uuid's. Only the last one is used.
      # This happens when we need to generate a new uuid for a key because the previous id became unavailable

      $uuids->{$app_key} = $uuid_value;
    }

    if (exists $uuids->{$key}) {
      return $uuids->{$key};
    }

    return;
  }

  # --------------------------------------------------------------------------------


=item remove_uuid

Remove a uuid that was generated for a key. A reason can be that the uuid that was generated before,
now has a conflict with a uuid that comes from the source system.

=cut

  sub remove_uuid {
    my ($dbh, $type, $uuid) = @_;

    print "remove_uuid $type $uuid\n";

    load_uuid($dbh, $type);

    my $rows;
    my $key;
    foreach my $row (@{ $uuid_map->{$type} }) {
      my ($app_key, $uuid_value) = @$row;

      if ($uuid_value eq $uuid) {

        if (defined $key) {
          my $data_log = Log::Log4perl->get_logger('Data');
          $data_log->error("UUID `$uuid' is related to multiple keys. This should not happen.");
        }

        $key = $app_key;
        next;
      }

      push @$rows, $row;
    }

    unless (defined $key) {
      my $data_log = Log::Log4perl->get_logger('Data');
      $data_log->error("Invalid uuid `$uuid'. It does not exists, so it can not be removed");
      return;
    }

    $uuid_map->{$type} = $rows;

    $type = $dbh->quote($type);
    $uuid = $dbh->quote($uuid);

    do_stmt($dbh, "
DELETE FROM uuid_map
  WHERE uuid_type = $type
    AND uuid_value = $uuid") or do { ERROR("failed to DELETE uuid `$uuid' from the database"); return };

    return $key;
  }

  # --------------------------------------------------------------------------------

  sub add_uuid {
    my ($dbh, $type, $key, $uuid) = @_;

    #print "add_uuid $type $key $uuid\n";

    load_uuid($dbh, $type);

    foreach my $row (@{ $uuid_map->{$type} }) {
      my ($app_key, $uuid_value) = @$row;

      if ($uuid_value eq $uuid) {
        my $data_log = Log::Log4perl->get_logger('Data');
        $data_log->error("UUID `$uuid' already exists. It wil not be added to the stored/remembered id's");
        return;
      }
    }

    my $uuids;
    foreach my $row (@{ $uuid_map->{$type} }) {
      my ($app_key, $uuid_value) = @$row;
      # It can be that the same key has multiple uuid's. Only the last one is used.
      # This happens when we need to generate a new uuid for a key because the previous id became unavailable

      $uuids->{$app_key} = $uuid_value;
    }

    if (exists $uuids->{$key}) {
      my $old_uuid = $uuids->{$key};

      my $data_log = Log::Log4perl->get_logger('Data');

      $data_log->warn("Old UUID `$old_uuid' is replaced with `$uuid' for key `$key'");
    }

    push @{ $uuid_map->{$type} }, [ $key, $uuid ];

    $type = $dbh->quote($type);
    $key = $dbh->quote($key);
    $uuid = $dbh->quote($uuid);

    do_stmt($dbh, "
INSERT
  INTO uuid_map (uuid_type, application_key, uuid_value)
  VALUES        ($type, $key, $uuid)") or ERROR("failed to INSERT uuid `$uuid' into the database");

    my $id = $dbh->{'mysql_insertid'} || '';
    return $id;
  }
}

# ================================================================================

=pod

=head2 Get Virtual ESL

Check for ESL if the Computersystem is a virtual computer system. Default is physical computersystem, unless it can be proven that it is a virtual computersystem.

A virtual computersystem has virtualization role Farm or virtual guest. Virtualization Role 'Server for Virtual Guest' is a physical server. Server role 'Virtual Center Manager' is unsure - can be physical or virtual.

If virtualization role did not conclude that the computersystem is virtual, then system type can help. System types cluster, cluster package and farm are virtual computersystems. Others are virtual or physical.

Returns 'Yes' for virtual computersystems or 'No' for physical computersystems.

=cut

sub get_virtual_esl($$$) {
	my ($cs_type, $cs_model, $v_role) = @_;
	$cs_type = lc($cs_type);
	$cs_model = lc($cs_model);
	$v_role = lc($v_role);
	my $isvirtual = "No";
	if (($v_role eq "farm") ||
		($v_role eq "virtual guest")) {
		$isvirtual = "Yes";
	} elsif (($cs_type eq "cluster") ||
		     ($cs_type eq "cluster package") ||
			 ($cs_type eq "farm")) {
		$isvirtual = "Yes";
	} elsif ($cs_model eq "logical-virtual server") {
		$isvirtual = "Yes";
	}
	return $isvirtual;
}

# ================================================================================

1;
