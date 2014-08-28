# Module containing parameters for DB Connection

package dbParams_aluCMDB;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw($server $port $username $password $dbsource $dbtarget get_info_type init2blank create_record get_recordid clear_tables val_available replace_cr remove_cr getsource getsourcesystem replace_delim update_record add_ip add_note get_field clear_fields get_virtual_esl change_field check_table a7_person ovsd_person esl_person cons_fqdn hw_tag installed2instance translate os_translation conv_date flush_table fqdn_ovsd tx_resourceunit);

###########
# Variables
###########

# Database

$port = 3306;
# $port = 8009;
$dbsource = "alu_cmdb";
$dbtarget = "cim";
$server = "localhost";
$username = "root";
$password = "Monitor1";

#####
# use
#####

use warnings;
use strict;
use File::Basename;	    # Logfilename translation
use Sys::Hostname;	    # Get Hostname
use Log;
use ALU_Util;

#############
# subroutines
# The subroutines are (slowly) moved to ALU_Util.pm, because ALU_Util.pm does not EXPORT the subroutines by default (it uses EXPORT_OK instead).
# This makes it possible to mix subroutines from different modules without interference.
#############

sub trim {
  return ALU_Util::trim(@_);
}

=pod

=head2 Initialize System Identification / System Configuration Types

This subroutine is used to determine the network information type. Network information is either Configuration information or Identification Information. In CIM Configuration information is modelled differently than Identification Information, hence it needs to be provided in different files.

=cut

sub get_info_type($) {
  return ALU_Util::get_info_type($_[0]);
}

=pod

=head2 init2blank(database_handle, tablename, array of fields)

This procedure will replace null values by blanks for all fields in the array. This is required for SELECT WHERE statements. The union of (SELECT WHERE CONDITION) AND (SELECT WHERE NOT CONDITION) is not the complete set of records, since records where field values are NULL are excluded from both extracts.

=cut

sub init2blank ($$$) {
	my ($dbh, $table) = @_;
	my (@fields) = @{$_[2]};
	while (my $field = shift @fields) {
		my $query = "UPDATE `$table` SET `$field` = '' WHERE `$field` is NULL";
		my $sth = $dbh->prepare($query);
		my $rv = $sth->execute();
		if (not defined $rv) {
			error("Could not execute query $query, Error: ".$sth->errstr);
		}
	}
}

=pod

=head2 Clear Fields (database_handle, tablename, array of fields)

This procedures will insert NULL values in specific field values. This is required to re-run scripts that will work on a subset of a component.

=cut

sub clear_fields($$$) {
	my ($dbh, $table) = @_;
	my (@fields) = @{$_[2]};
	# Create update string
	my $updstr = "";
	while (my $field = shift @fields) {
		$updstr .= "$field = null, ";
	}
	# remove last comma - space from string
	$updstr = substr($updstr, 0, -2);
	my $query = "UPDATE `$table` SET $updstr";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
}



=pod

=head2 Create Record(database_handle, tablename, array  of fieldnames, array of fieldvalues)

This procedure will create a record in the table. Fieldnames are in the array fieldnames, field values are in the array of field values.

Return value is the ID of the record that has been inserted - or blank if no record could be inserted.

=cut

sub create_record ($$$$) {
	my ($dbt, $table) = @_;
	my (@fields) = @{$_[2]};
	my (@values) = @{$_[3]};
	# quote values according to db specifications
	@values = map { $dbt->quote($_) } @values;
	my $fieldstr = "(`" . join ("`,`", @fields) . "`)";
	my $valstr = "(" . join (", ", @values) . ")";
	my $query = "INSERT INTO $table $fieldstr VALUES $valstr";
	my $sth= $dbt->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
	my $id = $dbt->{'mysql_insertid'} || "";
	return $id;
}

=pod

=head2 Update Rcord(database_handle, tablename, array of fieldnames, array of fieldvalues)

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
	my $query = "UPDATE $table SET $updatestring WHERE $wherefield = $wherevalue";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
	return;
}


=pod

=head2 Get Record ID(database_handle, tablename, array of fieldnames, array of fieldvalues)

This procedure will get the record id for the fields in array. If the record doesn't exist, it will return an empty string.

This is used for example to extract people details from the person table, or to get computersystem ID.

If the ID value should never be NULL.

=cut

sub get_recordid($$$$) {
	my ($dbh, $table) = @_;
	my (@fields) = @{$_[2]};
	my (@values) = @{$_[3]};
	# quote values according to db specifications
	my @values_w = map { $dbh->quote($_) } @values;
	# Create WHERE String
	my ($wherestring, $id);
	foreach my $field (@fields) {
		my $val = shift @values_w;
		$wherestring .= "$field = $val AND ";
	}
	# Remove last " AND " from the wherestring
	$wherestring = substr($wherestring, 0, -5);
	my $rec_id = $table . "_id";
	my $query = "SELECT $rec_id as id
				 FROM $table
				 WHERE $wherestring";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		$id = $ref->{id};
		if (not(defined($id))) {
			error("Unexpected NULL value found in $table, field $rec_id");
			$id = "";
		}


                # check or we have duplicate rows in the select (only expect 1 !)
                my $href2  = $sth->fetchrow_hashref();
                if ($href2) {
                  my $query = $sth->{Statement};
                  error("get_recordid: `$query' returns more than the expected 1 row !");
                }

	} else {
		# Record doesn't exist already, return empty string
		$id = "";
	}
	return $id;
}


=pod

=head2 Get Field(database_handle, tablename, field, array of fieldnames, array of fieldvalues)

This procedure will get the field value for the fields in array. If the record doesn't exist, it will return an empty string.

This is used for example to extract admin_id record, to add application type group.

=cut

sub get_field($$$$$) {
	my ($dbh, $table, $qfield) = @_;
	my (@fields) = @{$_[3]};
	my (@values) = @{$_[4]};
	# quote values according to db specifications
	my @values_w = map { $dbh->quote($_) } @values;
	# Create WHERE String
	my ($wherestring, $qvalue);
	foreach my $field (@fields) {
		my $val = shift @values_w;
		$wherestring .= "`$field` = $val AND ";
	}
	# Remove last " AND " from the wherestring
	$wherestring = substr($wherestring, 0, -5);
	my $rec_id = $table . "_id";
	my $query = "SELECT `$qfield` as qvalue
				 FROM $table
				 WHERE $wherestring";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		$qvalue = $ref->{qvalue} || "";
	} else {
		# Record doesn't exist already, return empty string
		$qvalue = "";
	}
	return $qvalue;
}


=pod

=head2 Clear Tables(database_handle, array of tablenames)

This procedure will empty all tables in the array of tablenames.

=cut

sub clear_tables ($$) {
	my ($dbh) = @_;
	my (@tables) = @{$_[1]};
	while (@tables) {
		my $table = shift @tables;
		my $query = "truncate $table";
		my $sth = $dbh->prepare($query);
		my $rv = $sth->execute();
		if (not defined $rv) {
			error("Could not execute query $query, Error: ".$sth->errstr);
		} else {
			logging("Truncating $table");
		}
	}
}

=pod

=head2 Values Available val_available(array)

This procedure will check the array for values available. If a value with length > 0 is found, TRUE is returned, otherwise false.

=cut

sub val_available($) {
  return ALU_Util::val_available($_[0]);
}

=pod

=head2 replace_cr($)

This procedure takes a variable as input and replaces all Control-M (Carriage Return) by <br> characters.

=cut

sub replace_cr($) {
  return ALU_Util::replace_cr($_[0]);
}

=pod

=head2 remove_cr($)

This procedure takes a variable as input and removes all Control-M (Carriage Return) characters.

=cut

sub remove_cr($) {
  return ALU_Util::remove_cr($_[0]);
}

=pod

=head2 replace_delim($)

This procedure will replace delimiter | with character ;

=cut

sub replace_delim($) {
	my($var) = @_;
	$var =~ s/\|/;/g;
	return $var;
}

=pod

=head2 Get Source getsource(dbhandle, table, field)

This procedure will get the source identifiers. The source identifier is anything before the first _ character in the table.field.
Multiple Source identifiers will be returned as a string with delimiter charachter as delimiter.

=cut

sub getsource($$$) {
	my ($dbh, $table, $field) = @_;
	my $sourcestr;
	my $query = "SELECT distinct substring_index($field,'_',1) as source FROM $table";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
	while (my $ref = $sth->fetchrow_hashref) {
		my $source = $ref->{source} || "";
#		($source, undef) = split /_/, $source;
		$sourcestr .= $source . "|";
	}
	return $sourcestr;
}

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
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		$sourcesystem = $ref->{sourcesystem} || "";
		($sourcesystem, undef) = split /_/, $sourcesystem;
		($sourcesystem, undef) = split /-/, $sourcesystem;
	}
	return $sourcesystem;
}

=pod

=head2 Add IP

This procedure will add data to IP Connectivity and IP Attributes tables. It requires computersystem_id, IP Type, Network Type and Network Value.

It will try to find IP Type for the Computersystem. If not found, IP Connectivity information will be created. Then it will create the IP Attributes information.

The procedure will return ip_connectivity_id number, or blank if no records have been created.

=cut

sub add_ip($$$$$$) {
  return ALU_Util::add_ip($_[0], $_[1], $_[2], $_[3], $_[4], $_[5]);
}

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
		$notes_id = create_record($dbh, "notes", \@fields, \@vals);
	}
	return $notes_id;
}

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

sub change_field($$$$) {
	my ($dbh, $table, $c_field, $n_field) = @_;
	my $query = "ALTER TABLE  `$table`
				 CHANGE  `$c_field`  `$n_field` VARCHAR( 255 )
				 CHARACTER SET latin1 COLLATE latin1_swedish_ci
				 NULL DEFAULT NULL";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
}

sub check_table($$$$) {
	my ($dbh, $table, $colcnt, $rowcnt) = @_;
	# Check number of columns
	my $query = "SELECT * FROM `$table` LIMIT 1";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
	if (my @refarray = $sth->fetchrow_array) {
		my $ret_col = @refarray;
		if ($ret_col == $colcnt) {
			logging("$colcnt columns expected, found!");
		} else {
			error("$colcnt columns expected, found $ret_col");
		}
	} else {
		error("Could not extract row to count columns, exiting...");
	}
	# Now check the number of rows
	# Use margin of 10%
	my $margin = int($rowcnt * 0.1);
	$query = "SELECT count(*) as cnt FROM `$table`";
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		my $rows = $ref->{cnt};
		if ( ($rows < ($rowcnt - $margin)) || ($rows > ($rowcnt + $margin))) {
			error("$rows found, $rowcnt expected with margin of $margin");
		} else {
			logging("$rows found, $rowcnt expected with margin of $margin");
		}
	}
	return;
}

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

=pod

=head2 OVSD Person

This script will take an OVSD Person and return the Person ID. Person Information in OVSD is Lastname, Firstname format. There is no email and no upi code. The person code is LASTNAME.FIRSTNAME.

A new person record will be created if none exists for this one.

=cut

sub ovsd_person($$$) {
  return ALU_Util::ovsd_person($_[0], $_[1], $_[2]);
}

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
			$person_id = get_recordid($dbt, "person", \@fields, \@vals);
			if (length($person_id) == 0) {
				# Create person_id if it did not exist
				@fields = ("email", "person_code");
				(@vals) = map { eval ("\$" . $_ ) } @fields;
				$person_id = create_record($dbt, "person",  \@fields, \@vals);
			}
		} else {
			$person_id = "";
		}
	}
	return $person_id;
}

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

=pod

=head2 HW Tag

This procedure will convert the AssetTag to a unique identifier. A AssetTag is the FQDN of the physical computer where it is running on. However as a new requirement, each key needs to be unique over the full range of CIs. Being unique within it's own CI type is no longer sufficient.

This procedure will make the AssetTag unique from the ComputerSystem fqdn, by adding a 'hw.' identifier in front of it.

When AssetTag is empty, then an empty string will be returned.

=cut

sub hw_tag($) {
	my ($hw_id) = @_;
	if (length($hw_id) > 0) {
		$hw_id = trim($hw_id);
		$hw_id = "hw." . $hw_id;
	} else {
		$hw_id = "";
	}
	return $hw_id;
}

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

=pod

=head2 Translate (dbhandle, component, attribute, sourcevalue, NotFoundHandling)

The Translate module will translate a one value into another value for a specific component and field.
Empty Source value can be translated into other value. Component-Source combination must be unique.

If no value is found, the sourcevalue is returned.

The attribute 'NotFoundHandling' specifies what to do if no value is found. Current possibilities are 'ErrMsg' (print an error message, return source value), 'ReturnCode' (log value not found, return 'NotFound'), 'SourceVal" (return the source value if nothing found - no error message).

Component value must be the component / input file that is currently processed, attribute should be as close as possible to the component/input file attribute value.

Do not use any of the special * or UTF-8 'degree sign' characters in A7 labels, since character encoding isn't friendly between MySQL, Excel and the different systems on which the application is running. And we don't go for the perfect world here.

=cut

sub translate($$$$$) {
  # NOT replaced with ALU_Util::translate because of the different logging.
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
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
	if (my $ref = $sth->fetchrow_hashref) {
		$tx_value = $ref->{tx_value} || "";
	} else {
		$tx_value = $src_value; # Default behaviour for "SourceVal"
		if (lc($errmsg) eq "errmsg") {
			error("No translation found for $src_value for component $component and attribute $attribute");
		} elsif (lc($errmsg) eq "returncode") {
			logging("No translation found for $src_value for component $component and attribute $attribute");
			$tx_value = "NotFound";
		}
	}
	return $tx_value;
}

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
			error("Could not execute query $query, Error: ".$sth->errstr);
		}
		if (my $ref = $sth->fetchrow_hashref) {
			$os_class = $ref->{os_class} || "";
			$os_version = $ref->{os_version} || "";
		} else {
			error("No translation for $cmo_os_system * $cmo_os_version");
			$os_class = "Unknown";
			$os_version = "Unknown";
			my @fields = ("cmo_os_system", "cmo_os_version", "os_class", "os_version");
			my (@vals) = map { eval ("\$" . $_ ) } @fields;
			my $os_translation_id = create_record($dbh, "os_translation", \@fields, \@vals);
		}
	}
	return ($os_class, $os_version);
}

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

=pod

=head2 Flush Table

This script will get a table, create a new temp table without the table index, empty the original table and restore only the unique records in the original table.

The table id column will contain different values

=cut

sub flush_table($$) {
	my ($dbh, $table) = @_;
	my $temp_table = "TEMP_" . $table;
	# First remove the id column from the table
	my $id = $table . "_id";
	my $query = "ALTER TABLE $table DROP $id";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
	# Then create the temp table with DISTINCT values only
	$query = "CREATE TEMPORARY TABLE $temp_table
				 SELECT DISTINCT *
				 FROM $table";
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
	# Empty the original table
	$query = "TRUNCATE TABLE $table";
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
	# Move original items back into table
	$query = "INSERT INTO $table
			  SELECT * FROM $temp_table";
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
	# And add the id column again to the table
	$query = "ALTER TABLE `$table`
			  ADD `$id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST";
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();
	if (not defined $rv) {
		error("Could not execute query $query, Error: ".$sth->errstr);
	}
}

=pod

=head2 FQDN OVSD

This procedure will investigate if there is a domain name attached to a system name. If not, then the domain name .no.dns.entry.com will be added.

ESL requires system names with domain names.

=cut

sub fqdn_ovsd($) {
  return ALU_Util::fqdn_ovsd($_[0]);
}

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
	$resourceunitcodes{"0D"} = "0D- Not Billable - Not billable – HP Application Support";
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
					error ("Invalid code length for Resourceunit code $resourceunit");
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

1;

