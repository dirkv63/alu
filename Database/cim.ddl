DROP DATABASE IF EXISTS `cim`;

SET character_set_client = utf8;

CREATE DATABASE `cim` 
  DEFAULT CHARACTER SET utf8
  DEFAULT COLLATE utf8_general_ci;

USE `cim`;

--
-- Table structure for table `a7_products`
--
DROP TABLE IF EXISTS `a7_products`;
CREATE TABLE `a7_products` (
  `count(*)` bigint(21) NOT NULL DEFAULT '0',
  `* Oper System` varchar(255) DEFAULT NULL,
  `esl_solution` varchar(255) DEFAULT NULL,
  `esl_category` varchar(255) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `acronym_mapping`
--
DROP TABLE IF EXISTS `acronym_mapping`;
CREATE TABLE `acronym_mapping` (
  `acronym_mapping_id` int(11) NOT NULL AUTO_INCREMENT,
  `application_id` int(11) DEFAULT NULL,
  `appl_name_normalized_acronym` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`acronym_mapping_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `address`
--
DROP TABLE IF EXISTS `address`;
CREATE TABLE `address` (
  `address_id` int(11) NOT NULL AUTO_INCREMENT,
  `building` varchar(255) DEFAULT NULL,
  `city` varchar(255) DEFAULT NULL,
  `country` varchar(255) DEFAULT NULL,
  `country_iso_code` varchar(255) DEFAULT NULL,
  `country_iso_name` varchar(255) DEFAULT NULL,
  `floor` varchar(255) DEFAULT NULL,
  `full_shipping_address` varchar(512) DEFAULT NULL,
  `state_province` varchar(255) DEFAULT NULL,
  `streetaddress` varchar(255) DEFAULT NULL,
  `zip` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`address_id`)
) ENGINE=MyISAM AUTO_INCREMENT=22 DEFAULT CHARSET=utf8;

--
-- Table structure for table `admin`
--
DROP TABLE IF EXISTS `admin`;
CREATE TABLE `admin` (
  `admin_id` int(11) NOT NULL AUTO_INCREMENT,
  `application_type_group` varchar(255) DEFAULT NULL,
  `customer_notes` varchar(512) DEFAULT NULL,
  `lifecyclestatus` varchar(255) DEFAULT NULL,
  `management_region` varchar(255) DEFAULT NULL,
  `nsa` varchar(255) DEFAULT NULL,
  `security_level` varchar(255) DEFAULT NULL,
  `service_provider` varchar(255) DEFAULT NULL,
  `sox_system` varchar(255) DEFAULT NULL,
  `time_zone` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`admin_id`)
) ENGINE=MyISAM AUTO_INCREMENT=10292 DEFAULT CHARSET=utf8;

--
-- Table structure for table `alu_addresses`
--
DROP TABLE IF EXISTS `alu_addresses`;
CREATE TABLE `alu_addresses` (
  `aui` varchar(255) NOT NULL DEFAULT '',
  `uli` varchar(255) DEFAULT NULL,
  `usi` varchar(255) DEFAULT NULL,
  `s` varchar(255) DEFAULT NULL,
  `gn` varchar(255) DEFAULT NULL,
  `log` varchar(255) DEFAULT NULL,
  `mail` varchar(255) DEFAULT NULL,
  `atn` varchar(255) DEFAULT NULL,
  `tn` varchar(255) DEFAULT NULL,
  `mobile` varchar(255) DEFAULT NULL,
  `hid` varchar(255) DEFAULT NULL,
  `rn` varchar(255) DEFAULT NULL,
  `costcenter` varchar(255) DEFAULT NULL,
  `Manager` varchar(255) DEFAULT NULL,
  `o` varchar(255) DEFAULT NULL,
  `ou` varchar(255) DEFAULT NULL,
  `c` varchar(255) DEFAULT NULL,
  `l` varchar(255) DEFAULT NULL,
  `userType` varchar(255) DEFAULT NULL,
  `dn` varchar(255) DEFAULT NULL,
  `dept` varchar(255) DEFAULT NULL,
  `ftn` varchar(255) DEFAULT NULL,
  `country` varchar(255) DEFAULT NULL,
  `currency` varchar(255) DEFAULT NULL,
  `Language_code` varchar(255) DEFAULT NULL,
  `sst` varchar(255) DEFAULT NULL,
  `legalEntity` varchar(255) DEFAULT NULL,
  `lastModifiedDate` varchar(255) DEFAULT NULL,
  `Contact name` varchar(255) DEFAULT NULL,
  `Departement` varchar(255) DEFAULT NULL,
  `Location` varchar(255) DEFAULT NULL,
  `ManagerName` varchar(255) DEFAULT NULL,
  `HP-ALU Contract Location ID` varchar(255) DEFAULT NULL,
  `safewordTokenNumber` varchar(255) DEFAULT NULL,
  `safewordRoles` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`aui`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `application`
--
DROP TABLE IF EXISTS `application`;
CREATE TABLE `application` (
  `application_id` int(11) NOT NULL AUTO_INCREMENT,
  `application_tag` varchar(255) DEFAULT NULL,
  `appl_name_acronym` varchar(255) DEFAULT NULL,
  `appl_name_description` varchar(2300) DEFAULT NULL,   -- if you extend this varchar please extend also acronym_mapping !!
  `appl_name_long` varchar(255) DEFAULT NULL,
  `application_category` varchar(512) DEFAULT NULL,
  `application_class` varchar(255) DEFAULT NULL,
  `application_group` varchar(255) DEFAULT NULL,
  `application_status` varchar(255) DEFAULT NULL,
  `application_type` varchar(255) DEFAULT NULL,
  `business_critical` varchar(255) DEFAULT NULL,
  `security_class` varchar(255) DEFAULT NULL,
  `security_category` varchar(255) DEFAULT NULL,
  `ci_owner_company` varchar(255) DEFAULT NULL,
  `cma` varchar(255) DEFAULT NULL,
  `oper_system` varchar(255) DEFAULT NULL,
  `portfolio_obj_id` int(11) DEFAULT NULL,
  `portfolio_id` varchar(255) DEFAULT NULL,
  `contactrole_id` int(11) DEFAULT NULL,
  `compsys_esl_id` int(11) DEFAULT NULL,
  `manufacturer` varchar(255) DEFAULT NULL,
  `nsa` varchar(255) DEFAULT NULL,
  `os_type` varchar(255) DEFAULT NULL,
  `source_system` varchar(255) DEFAULT NULL,
  `source_system_element_id` varchar(255) DEFAULT NULL,
  `ext_source_system` varchar(255) DEFAULT NULL,
  `ext_source_system_element_id` varchar(255) DEFAULT NULL,
  `sourcing_accountable` varchar(255) DEFAULT NULL,
  `ucmdb_application_type` varchar(30) DEFAULT NULL,
  `version` varchar(255) DEFAULT NULL,
  `esl_cnt` int(11) DEFAULT NULL,
  `a7_cnt` int(11) DEFAULT NULL,
  `ovsd_cnt` int(11) DEFAULT NULL,
  PRIMARY KEY (`application_id`),
  KEY `application_tag` (`application_tag`)
) ENGINE=MyISAM AUTO_INCREMENT=2258 DEFAULT CHARSET=utf8;


--
-- Table structure for table `application_instance`
--
DROP TABLE IF EXISTS `application_instance`;
CREATE TABLE `application_instance` (
  `application_instance_id` int(11) NOT NULL AUTO_INCREMENT,
  `application_instance_tag` varchar(255) DEFAULT NULL,
  `appl_name_acronym` varchar(255) DEFAULT NULL,
  `appl_name_description` varchar(2300) DEFAULT NULL,
  `appl_name_long` varchar(255) DEFAULT NULL,
  `application_region` varchar(255) DEFAULT NULL,
  `application_status` varchar(255) DEFAULT NULL,
  `ci_owner` varchar(255) DEFAULT NULL,
  `ci_owner_company` varchar(255) DEFAULT NULL,
  `ci_responsible` varchar(255) DEFAULT NULL,
  `cluster_package_name` varchar(255) DEFAULT NULL,
  `connectivity_instruction` varchar(512) DEFAULT NULL,
  `db_type` varchar(255) DEFAULT NULL,
  `doc_ref_url` varchar(255) DEFAULT NULL,
  `explode_flag` varchar(255) DEFAULT NULL,
  `application_id` int(11) DEFAULT NULL,
  `assignment_id` int(11) DEFAULT NULL,
  `availability_id` int(11) DEFAULT NULL,
  `operations_id` int(11) DEFAULT NULL,
  `billing_id` int(11) DEFAULT NULL,
  `contactrole_id` int(11) DEFAULT NULL,
  `home_directory` varchar(255) DEFAULT NULL,
  `installed_application_status` varchar(255) DEFAULT NULL,
  `instance_category` varchar(255) DEFAULT NULL,
  `instance_category_a7` varchar(255) DEFAULT NULL,
  `lifecyclestatus` varchar(255) DEFAULT NULL,
  `listener_ports` varchar(255) DEFAULT NULL,
  `managed_url` varchar(255) DEFAULT NULL,
  `monitoring_solution` varchar(255) DEFAULT NULL,
  `detailedlocation_id` int(11) DEFAULT NULL,
  `ovsd_searchcode` varchar(255) DEFAULT NULL,
  `portfolio_id_long` varchar(255) DEFAULT NULL,
  `risk_acceptance` varchar(255) DEFAULT NULL,
  `service_provider` varchar(255) DEFAULT NULL,
  `source_system` varchar(255) DEFAULT NULL,
  `source_system_element_id` varchar(255) DEFAULT NULL,
  `sox_system` varchar(255) DEFAULT NULL,
  `support_code` varchar(255) DEFAULT NULL,
  `time_zone` varchar(255) DEFAULT NULL,
  `version` varchar(255) DEFAULT NULL,
  `ucmdb_application_type` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`application_instance_id`),
  KEY `application_id` (`application_id`),
  KEY `source_system_element_id` (`source_system_element_id`),
  KEY `installed_application_tag` (`application_instance_tag`)
) ENGINE=MyISAM AUTO_INCREMENT=10200 DEFAULT CHARSET=utf8;


--
-- Table structure for table `application_relation`
--
DROP TABLE IF EXISTS `application_relation`;
CREATE TABLE `application_relation` (
  `source_system` varchar(255) NOT NULL,
  `source_system_element_id` varchar(255) NOT NULL,
  `application_id` int(11) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `asset`
--
DROP TABLE IF EXISTS `asset`;
CREATE TABLE `asset` (
  `asset_id` int(11) NOT NULL AUTO_INCREMENT,
  `assetnumber` varchar(255) DEFAULT NULL,
  `ordernumber` varchar(255) DEFAULT NULL,
  `orderdate` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`asset_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1388 DEFAULT CHARSET=utf8;

--
-- Table structure for table `assignment`
--
DROP TABLE IF EXISTS `assignment`;
CREATE TABLE `assignment` (
  `assignment_id` int(11) NOT NULL AUTO_INCREMENT,
  `escalation_assignment_group` varchar(255) DEFAULT NULL,
  `initial_assignment_group` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`assignment_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `availability`
--
DROP TABLE IF EXISTS `availability`;
CREATE TABLE `availability` (
  `availability_id` int(11) NOT NULL AUTO_INCREMENT,
  `impact` varchar(255) DEFAULT NULL,
  `impact_description` varchar(1024) DEFAULT NULL,
  `minimum_availability` varchar(255) DEFAULT NULL,
  `possible_downtime` varchar(255) DEFAULT NULL,
  `runtime_environment` varchar(255) DEFAULT NULL,
  `service_level_code` varchar(255) DEFAULT NULL,
  `servicecoverage_window` varchar(255) DEFAULT NULL,
  `slo` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`availability_id`)
) ENGINE=MyISAM AUTO_INCREMENT=2313 DEFAULT CHARSET=utf8;


--
-- Table structure for table `billing`
--
DROP TABLE IF EXISTS `billing`;
CREATE TABLE `billing` (
  `billing_id` int(11) NOT NULL AUTO_INCREMENT,
  `billing_change_category` varchar(255) DEFAULT NULL,
  `billing_change_date` varchar(255) DEFAULT NULL,
  `billing_change_request_id` varchar(255) DEFAULT NULL,
  `billing_resourceunit_code` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`billing_id`)
) ENGINE=MyISAM AUTO_INCREMENT=18848 DEFAULT CHARSET=utf8;


--
-- Table structure for table `ci_renaming`
--
DROP TABLE IF EXISTS `ci_renaming`;
CREATE TABLE `ci_renaming` (
  `application_tag` varchar(255) DEFAULT NULL,
  `new_appl_name_acronym` varchar(255) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `cluster`
--
DROP TABLE IF EXISTS `cluster`;
CREATE TABLE `cluster` (
  `cluster_id` int(11) NOT NULL AUTO_INCREMENT,
  `cluster_type` varchar(255) DEFAULT NULL,
  `cluster_architecture` varchar(255) DEFAULT NULL,
  `cluster_technology` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`cluster_id`)
) ENGINE=MyISAM AUTO_INCREMENT=318 DEFAULT CHARSET=utf8;


--
-- Table structure for table `compsys_esl`
--
DROP TABLE IF EXISTS `compsys_esl`;
CREATE TABLE `compsys_esl` (
  `compsys_esl_id` int(11) NOT NULL AUTO_INCREMENT,
  `esl_category` varchar(255) DEFAULT NULL,
  `esl_id` varchar(255) DEFAULT NULL,
  `esl_business` varchar(255) DEFAULT NULL,
  `esl_subbusiness` varchar(255) DEFAULT NULL,
  `esl_system_type` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`compsys_esl_id`),
  KEY `esl_id` (`esl_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `computersystem`
--
DROP TABLE IF EXISTS `computersystem`;
CREATE TABLE `computersystem` (
  `computersystem_id` int(11) NOT NULL AUTO_INCREMENT,
  `computersystem_source` varchar(255) NOT NULL,
  `fqdn` varchar(255) DEFAULT NULL,
  `isvirtual` varchar(255) DEFAULT NULL,
  `ci_owner_company` varchar(255) DEFAULT NULL,
  `host_type` varchar(255) DEFAULT NULL,
  `cs_type` varchar(255) DEFAULT NULL,
  `admin_id` int(11) DEFAULT NULL,
  `assignment_id` int(11) DEFAULT NULL,
  `availability_id` int(11) DEFAULT NULL,
  `billing_id` int(11) DEFAULT NULL,
  `diskspace_id` int(11) DEFAULT NULL,
  `compsys_esl_id` int(11) DEFAULT NULL,
  `maintenance_contract_id` int(11) DEFAULT NULL,
  `operatingsystem_id` int(11) DEFAULT NULL,
  `ovsd_searchcode` varchar(255) DEFAULT NULL,
  `processor_id` int(11) DEFAULT NULL,
  `cluster_id` int(11) DEFAULT NULL,
  `virtual_ci_id` int(11) DEFAULT NULL,
  `physicalbox_tag` varchar(255) DEFAULT NULL,
  `source_system_element_id` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`computersystem_id`),
  UNIQUE KEY `source_system_element_id` (`source_system_element_id`)
) ENGINE=MyISAM AUTO_INCREMENT=3325 DEFAULT CHARSET=utf8;


--
-- Table structure for table `contactrole`
--
DROP TABLE IF EXISTS `contactrole`;
CREATE TABLE `contactrole` (
  `contactrole_id` int(11) NOT NULL AUTO_INCREMENT,
  `computersystem_id` int(11) DEFAULT NULL,
  `application_id` int(11) DEFAULT NULL,
  `application_instance_id` int(11) DEFAULT NULL,
  `contact_for_patch` varchar(255) DEFAULT NULL,
  `contact_type` varchar(255) DEFAULT NULL,
  `person_id` varchar(255) DEFAULT NULL,
  `preferred_contact_method` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`contactrole_id`),
  KEY `computersystem_id` (`computersystem_id`),
  KEY `person_id` (`person_id`)
) ENGINE=MyISAM AUTO_INCREMENT=3070 DEFAULT CHARSET=utf8;


--
-- Table structure for table `cpu`
--
DROP TABLE IF EXISTS `cpu`;
CREATE TABLE `cpu` (
  `cpu_id` int(11) NOT NULL AUTO_INCREMENT,
  `clockspeed` varchar(255) DEFAULT NULL,
  `corespercpu` varchar(255) DEFAULT NULL,
  `cputype` varchar(255) DEFAULT NULL,
  `cpufamily` varchar(255) DEFAULT NULL,
  `logical_cpus` varchar(255) DEFAULT NULL,
  `numberofcpus` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`cpu_id`)
) ENGINE=MyISAM AUTO_INCREMENT=3034 DEFAULT CHARSET=utf8;


--
-- Table structure for table `detailedlocation`
--
DROP TABLE IF EXISTS `detailedlocation`;
CREATE TABLE `detailedlocation` (
  `detailedlocation_id` int(11) NOT NULL AUTO_INCREMENT,
  `source_system_element_id` varchar(255) NOT NULL,
  `object_name` varchar(255) NOT NULL DEFAULT '',
  `floor_slot` varchar(255) DEFAULT NULL,
  `location_id` int(11) NOT NULL,
  PRIMARY KEY (`detailedlocation_id`),
  KEY `location_id` (`location_id`),
  KEY `source_system_element_id` (`source_system_element_id`)
) ENGINE=MyISAM AUTO_INCREMENT=370 DEFAULT CHARSET=utf8;

--
-- Table structure for table `diskspace`
--
DROP TABLE IF EXISTS `diskspace`;
CREATE TABLE `diskspace` (
  `diskspace_id` int(11) NOT NULL AUTO_INCREMENT,
  `available_diskspace` varchar(255) DEFAULT NULL,
  `local_appl_diskspace` varchar(255) DEFAULT NULL,
  `physical_diskspace` varchar(255) DEFAULT NULL,
  `used_diskspace` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`diskspace_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `interface`
--
-- Volgende kolommen worden niet overgenomen uit alu_cmdb.ovsd_interfaces :
-- alu_cmdb.ovsd_interfaces.RECEIVES FROM
-- alu_cmdb.ovsd_interfaces.SENDS TO
-- alu_cmdb.ovsd_interfaces.RECEIVES FROM OWNER ORGANIZATION
-- alu_cmdb.ovsd_interfaces.RECEIVES FROM OWNER PERSON
-- alu_cmdb.ovsd_interfaces.RECEIVES FROM DOMAIN ANALYST
-- alu_cmdb.ovsd_interfaces.SENDS TO OWNER ORGANIZATION
-- alu_cmdb.ovsd_interfaces.SENDS TO OWNER PERSON
-- alu_cmdb.ovsd_interfaces.SENDS TO DOMAIN ANALYST
--
-- Met deze wordt de relations tabel aangevuld:
-- alu_cmdb.ovsd_interfaces.FROM SEARCHCODE
-- alu_cmdb.ovsd_interfaces.TO SEARCHCODE
--
-- Wat doe ik met alu_cmdb.ovsd_interfaces.NAME ? => Vragen aan Dirk

DROP TABLE IF EXISTS `interface`;
CREATE TABLE `interface` (
  `interface_id` int(11) NOT NULL AUTO_INCREMENT,
  `interface_tag` varchar(255) DEFAULT NULL,            -- combinatie from acronym, to acronym en volgnummer
  `source_system_element_id` varchar(255) DEFAULT NULL, -- komt uit alu_cmdb.ovsd_interfaces.ID, komt uit INTERFACES_REPORT.ID
  `ovsd_searchcode` varchar(255) DEFAULT NULL,          -- komt uit alu_cmdb.ovsd_interfaces.SEARCH_CODE
  `application_category` varchar(512) DEFAULT NULL,     -- komt uit alu_cmdb.ovsd_interfaces.CATEGORY
  `appl_name_long` varchar(255) DEFAULT NULL,           -- omgevormde naam zoals uit ppt 'CI Naming for apps - Meeting Result.ppt'
  `appl_name_description` varchar(2300) DEFAULT NULL,    -- langste waarde in de aangeleverde excel is 258,
                                                        -- komt uit alu_cmdb.ovsd_interfaces.DESCRIPTION_4000
  `interface_data` varchar(400) DEFAULT NULL,           -- komt uit alu_cmdb.ovsd_interfaces.APPLICATION  INTERFACE_DATA
  `interface_partners` varchar(255) DEFAULT NULL,       -- komt uit alu_cmdb.ovsd_interfaces.APPLICATION INTERFACE_PARTNERS
  `interface_technology` varchar(512) DEFAULT NULL,     -- komt uit alu_cmdb.ovsd_interfaces.APPLICATION INTERFACE_TECHNOLOGY
  `interface_external_input` varchar(400) DEFAULT NULL, -- komt uit alu_cmdb.ovsd_interfaces.INTERFACE_EXTERNAL_INPUT
  `interface_external_output` varchar(400) DEFAULT NULL,-- komt uit alu_cmdb.ovsd_interfaces.INTERFACE_EXTERNAL_OUTPUT
  PRIMARY KEY (`interface_id`)
) ENGINE=MyISAM AUTO_INCREMENT=18848 DEFAULT CHARSET=utf8;


--
-- Table structure for table `ip_attributes`
--
DROP TABLE IF EXISTS `ip_attributes`;
CREATE TABLE `ip_attributes` (
  `ip_attributes_id` int(11) NOT NULL AUTO_INCREMENT,
  `ip_connectivity_id` int(11) NOT NULL,
  `network_id_type` varchar(255) DEFAULT NULL,
  `network_id_value` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ip_attributes_id`),
  KEY `ip_connectivity_id` (`ip_connectivity_id`)
) ENGINE=MyISAM AUTO_INCREMENT=22710 DEFAULT CHARSET=utf8;


--
-- Table structure for table `ip_connectivity`
--
DROP TABLE IF EXISTS `ip_connectivity`;
CREATE TABLE `ip_connectivity` (
  `ip_connectivity_id` int(11) NOT NULL AUTO_INCREMENT,
  `computersystem_id` int(11) NOT NULL,
  `ip_type` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ip_connectivity_id`),
  KEY `computersystem_id` (`computersystem_id`)
) ENGINE=MyISAM AUTO_INCREMENT=22710 DEFAULT CHARSET=utf8;


--
-- Table structure for table `issue_log`
--
DROP TABLE IF EXISTS `issue_log`;
CREATE TABLE `issue_log` (
  `issue_log_id` int(11) NOT NULL AUTO_INCREMENT,
  `source_system_element_id` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `category` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`issue_log_id`)
) ENGINE=MyISAM AUTO_INCREMENT=489 DEFAULT CHARSET=utf8;


--
-- Table structure for table `location`
--
DROP TABLE IF EXISTS `location`;
CREATE TABLE `location` (
  `location_id` int(11) NOT NULL AUTO_INCREMENT,
  `location_access` varchar(400) DEFAULT NULL,
  `location_category` varchar(255) DEFAULT NULL,
  `location_code` varchar(255) DEFAULT NULL,
  `location_notes` varchar(1024) DEFAULT NULL,
  `location_owner` varchar(255) DEFAULT NULL,
  `location_tier` varchar(255) DEFAULT NULL,
  `time_zone` varchar(255) DEFAULT NULL,
  `address_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`location_id`),
  UNIQUE KEY `location_code` (`location_code`)
) ENGINE=MyISAM AUTO_INCREMENT=989 DEFAULT CHARSET=utf8;


--
-- Table structure for table `maintenance_contract`
--
DROP TABLE IF EXISTS `maintenance_contract`;
CREATE TABLE `maintenance_contract` (
  `maintenance_contract_id` int(11) NOT NULL AUTO_INCREMENT,
  `contract_elements` varchar(255) DEFAULT NULL,
  `coverage_end_date` varchar(255) DEFAULT NULL,
  `maint_contract_details` varchar(255) DEFAULT NULL,
  `maint_contract_name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`maintenance_contract_id`)
) ENGINE=MyISAM AUTO_INCREMENT=7386 DEFAULT CHARSET=utf8;


--
-- Table structure for table `notes`
--
DROP TABLE IF EXISTS `notes`;
CREATE TABLE `notes` (
  `notes_id` int(11) NOT NULL AUTO_INCREMENT,
  `computersystem_id` int(11) NOT NULL,
  `note_type` varchar(255) DEFAULT NULL,
  `note_value` varchar(1024) DEFAULT NULL,
  PRIMARY KEY (`notes_id`),
  KEY `computersystem_id` (`computersystem_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `operatingsystem`
--
DROP TABLE IF EXISTS `operatingsystem`;
CREATE TABLE `operatingsystem` (
  `operatingsystem_id` int(11) NOT NULL AUTO_INCREMENT,
  `os_installationdate` varchar(255) DEFAULT NULL,
  `os_language` varchar(255) DEFAULT NULL,
  `os_name` varchar(255) DEFAULT NULL,
  `os_patchlevel` varchar(255) DEFAULT NULL,
  `os_type` varchar(255) DEFAULT NULL,
  `os_version` varchar(255) DEFAULT NULL,
  `time_zone` varchar(255) DEFAULT NULL,
  `application_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`operatingsystem_id`)
) ENGINE=MyISAM AUTO_INCREMENT=8824 DEFAULT CHARSET=utf8;


--
-- Table structure for table `operations`
--

DROP TABLE IF EXISTS `operations`;
CREATE TABLE `operations` (
  `operations_id` int(11) NOT NULL AUTO_INCREMENT,
  `op_backup_notes` varchar(512) DEFAULT NULL,
  `op_cap_mgmt` varchar(255) DEFAULT NULL,
  `op_daylight_savings` varchar(255) DEFAULT NULL,
  `op_patch_notes` varchar(255) DEFAULT NULL,
  `op_restore` varchar(400) DEFAULT NULL,
  `op_shutdown_notes` varchar(255) DEFAULT NULL,
  `op_startup_notes` varchar(255) DEFAULT NULL,
  `op_total_size` varchar(255) DEFAULT NULL,
  `op_total_used_size` varchar(255) DEFAULT NULL,
  `op_tx_log` varchar(400) DEFAULT NULL,
  PRIMARY KEY (`operations_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `os_translation`
--
DROP TABLE IF EXISTS `os_translation`;
CREATE TABLE `os_translation` (
  `cmo_os_system` varchar(255) DEFAULT NULL,
  `cmo_os_version` varchar(255) DEFAULT NULL,
  `os_class` varchar(255) DEFAULT NULL,
  `os_version` varchar(255) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `ovsd_application_instance`
--
DROP TABLE IF EXISTS `ovsd_application_instance`;
CREATE TABLE `ovsd_application_instance` (
  `application_instance_id` int(11) NOT NULL AUTO_INCREMENT,
  `application_instance_tag` varchar(255) DEFAULT NULL,
  `appl_name_acronym` varchar(255) DEFAULT NULL,
  `appl_name_description` varchar(2300) DEFAULT NULL,
  `appl_name_long` varchar(255) DEFAULT NULL,
  `application_region` varchar(255) DEFAULT NULL,
  `application_status` varchar(255) DEFAULT NULL,
  `ci_owner` varchar(255) DEFAULT NULL,
  `ci_owner_company` varchar(255) DEFAULT NULL,
  `ci_responsible` varchar(255) DEFAULT NULL,
  `cluster_package_name` varchar(255) DEFAULT NULL,
  `connectivity_instruction` varchar(512) DEFAULT NULL,
  `db_type` varchar(255) DEFAULT NULL,
  `doc_ref_url` varchar(400) DEFAULT NULL,
  `explode_flag` varchar(255) DEFAULT NULL,
  `application_id` int(11) DEFAULT NULL,
  `assignment_id` int(11) DEFAULT NULL,
  `availability_id` int(11) DEFAULT NULL,
  `operations_id` int(11) DEFAULT NULL,
  `billing_id` int(11) DEFAULT NULL,
  `contactrole_id` int(11) DEFAULT NULL,
  `home_directory` varchar(255) DEFAULT NULL,
  `installed_application_status` varchar(255) DEFAULT NULL,
  `instance_category` varchar(255) DEFAULT NULL,
  `instance_category_a7` varchar(255) DEFAULT NULL,
  `lifecyclestatus` varchar(255) DEFAULT NULL,
  `listener_ports` varchar(255) DEFAULT NULL,
  `managed_url` varchar(255) DEFAULT NULL,
  `monitoring_solution` varchar(255) DEFAULT NULL,
  `detailedlocation_id` int(11) DEFAULT NULL,
  `ovsd_searchcode` varchar(255) DEFAULT NULL,
  `portfolio_id_long` varchar(255) DEFAULT NULL,
  `risk_acceptance` varchar(255) DEFAULT NULL,
  `service_provider` varchar(255) DEFAULT NULL,
  `source_system` varchar(255) DEFAULT NULL,
  `source_system_element_id` varchar(255) DEFAULT NULL,
  `sox_system` varchar(255) DEFAULT NULL,
  `support_code` varchar(255) DEFAULT NULL,
  `time_zone` varchar(255) DEFAULT NULL,
  `version` varchar(255) DEFAULT NULL,
  `ucmdb_application_type` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`application_instance_id`),
  KEY `application_id` (`application_id`),
  KEY `source_system_element_id` (`source_system_element_id`),
  KEY `installed_application_tag` (`application_instance_tag`)
) ENGINE=MyISAM AUTO_INCREMENT=2664 DEFAULT CHARSET=utf8;


--
-- Table structure for table `ovsd_expl_application_instance`
--
DROP TABLE IF EXISTS `ovsd_expl_application_instance`;
CREATE TABLE `ovsd_expl_application_instance` (
  `application_instance_id` int(11) NOT NULL AUTO_INCREMENT,
  `application_instance_tag` varchar(255) DEFAULT NULL,
  `appl_name_acronym` varchar(255) DEFAULT NULL,
  `appl_name_description` varchar(2300) DEFAULT NULL,
  `appl_name_long` varchar(255) DEFAULT NULL,
  `application_region` varchar(255) DEFAULT NULL,
  `application_status` varchar(255) DEFAULT NULL,
  `ci_owner` varchar(255) DEFAULT NULL,
  `ci_owner_company` varchar(255) DEFAULT NULL,
  `ci_responsible` varchar(255) DEFAULT NULL,
  `cluster_package_name` varchar(255) DEFAULT NULL,
  `connectivity_instruction` varchar(512) DEFAULT NULL,
  `db_type` varchar(255) DEFAULT NULL,
  `doc_ref_url` varchar(400) DEFAULT NULL,
  `explode_flag` varchar(255) DEFAULT NULL,
  `application_id` int(11) DEFAULT NULL,
  `assignment_id` int(11) DEFAULT NULL,
  `availability_id` int(11) DEFAULT NULL,
  `operations_id` int(11) DEFAULT NULL,
  `billing_id` int(11) DEFAULT NULL,
  `contactrole_id` int(11) DEFAULT NULL,
  `home_directory` varchar(255) DEFAULT NULL,
  `installed_application_status` varchar(255) DEFAULT NULL,
  `instance_category` varchar(255) DEFAULT NULL,
  `instance_category_a7` varchar(255) DEFAULT NULL,
  `lifecyclestatus` varchar(255) DEFAULT NULL,
  `listener_ports` varchar(255) DEFAULT NULL,
  `managed_url` varchar(255) DEFAULT NULL,
  `monitoring_solution` varchar(255) DEFAULT NULL,
  `detailedlocation_id` int(11) DEFAULT NULL,
  `ovsd_searchcode` varchar(255) DEFAULT NULL,
  `portfolio_id_long` varchar(255) DEFAULT NULL,
  `risk_acceptance` varchar(255) DEFAULT NULL,
  `service_provider` varchar(255) DEFAULT NULL,
  `source_system` varchar(255) DEFAULT NULL,
  `source_system_element_id` varchar(255) DEFAULT NULL,
  `sox_system` varchar(255) DEFAULT NULL,
  `support_code` varchar(255) DEFAULT NULL,
  `time_zone` varchar(255) DEFAULT NULL,
  `version` varchar(255) DEFAULT NULL,
  `ucmdb_application_type` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`application_instance_id`),
  KEY `application_id` (`application_id`),
  KEY `source_system_element_id` (`source_system_element_id`),
  KEY `installed_application_tag` (`application_instance_tag`)
) ENGINE=MyISAM AUTO_INCREMENT=2664 DEFAULT CHARSET=utf8;


--
-- Table structure for table `person`
-- uit cim.sql :
--  UNIQUE KEY `id_pk` (`person_id`),
--  KEY `id_index` (`person_id`)
-- vervangen door 
--  PRIMARY KEY (`person_id`)
-- uit person.sql 
-- Tabel ik ook InnoDB ??? => mischien gefoefel om sneller te gaan ?

DROP TABLE IF EXISTS `person`;
CREATE TABLE `person` (
  `person_id` int(11) NOT NULL AUTO_INCREMENT,
  `person_code` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `firstname` varchar(255) DEFAULT NULL,
  `lastname` varchar(255) DEFAULT NULL,
  `upi` varchar(255) DEFAULT NULL,
  `person_searchcode` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`person_id`),
  KEY `person_code` (`person_code`)
) ENGINE=MyISAM AUTO_INCREMENT=1294 DEFAULT CHARSET=utf8;


--
-- Table structure for table `person_old`
--
DROP TABLE IF EXISTS `person_old`;
CREATE TABLE `person_old` (
  `person_id` int(11) NOT NULL AUTO_INCREMENT,
  `person_code` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `firstname` varchar(255) DEFAULT NULL,
  `lastname` varchar(255) DEFAULT NULL,
  `upi` varchar(255) DEFAULT NULL,
  `person_searchcode` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`person_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1258 DEFAULT CHARSET=utf8;

--
-- Table structure for table `physicalbox`
--
DROP TABLE IF EXISTS `physicalbox`;
CREATE TABLE `physicalbox` (
  `physicalbox_id` int(11) NOT NULL AUTO_INCREMENT,
  `source_system` varchar(255) NOT NULL,
  `owner` varchar(255) DEFAULT NULL,
  `lifecyclestatus` varchar(255) DEFAULT NULL,
  `tag` varchar(255) DEFAULT NULL,
  `in_enclosure` varchar(255) DEFAULT NULL,
  `physicalproduct_id` int(11) DEFAULT NULL,
  `asset_id` int(11) DEFAULT NULL,
  `source_system_element_id` varchar(255) DEFAULT NULL,
  `detailedlocation_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`physicalbox_id`)
) ENGINE=MyISAM AUTO_INCREMENT=3121 DEFAULT CHARSET=utf8;


--
-- Table structure for table `physicalproduct`
--
DROP TABLE IF EXISTS `physicalproduct`;
CREATE TABLE `physicalproduct` (
  `physicalproduct_id` int(11) NOT NULL AUTO_INCREMENT,
  `serialnumber` varchar(255) DEFAULT NULL,
  `memcapacity` varchar(255) DEFAULT NULL,
  `physical_diskspace` varchar(255) DEFAULT NULL,
  `partnumber` varchar(255) DEFAULT NULL,
  `vendorequipmenttype` varchar(255) DEFAULT NULL,
  `manufacturer` varchar(255) DEFAULT NULL,
  `model` varchar(255) DEFAULT NULL,
  `hw_type` varchar(255) DEFAULT NULL,
  `cpu_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`physicalproduct_id`)
) ENGINE=MyISAM AUTO_INCREMENT=3121 DEFAULT CHARSET=utf8;


--
-- Table structure for table `portfolio_obj`
--
DROP TABLE IF EXISTS `portfolio_obj`;
CREATE TABLE `portfolio_obj` (
  `portfolio_obj_id` int(11) NOT NULL AUTO_INCREMENT,
  `portfolio_id` int(11) DEFAULT NULL,
  `book_close_impact` varchar(255) DEFAULT NULL,
  `business_area` varchar(255) DEFAULT NULL,
  `business_stakeholder_name` varchar(255) DEFAULT NULL,
  `business_stakeholder_organization` varchar(255) DEFAULT NULL,
  `nsa` varchar(255) DEFAULT NULL,
  `pf_critical_application` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`portfolio_obj_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `processor`
--

DROP TABLE IF EXISTS `processor`;
CREATE TABLE `processor` (
  `processor_id` int(11) NOT NULL AUTO_INCREMENT,
  `enabled_cores` varchar(255) DEFAULT NULL,
  `hyperthreading_enabled` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`processor_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `relations`
--
DROP TABLE IF EXISTS `relations`;
CREATE TABLE `relations` (
  `relations_id` int(11) NOT NULL AUTO_INCREMENT,
  `source_system` varchar(255) DEFAULT NULL,
  `left_type` varchar(255) NOT NULL,
  `left_name` varchar(255) NOT NULL,
  `relation` varchar(255) NOT NULL,
  `right_name` varchar(255) NOT NULL,
  `right_type` varchar(255) NOT NULL,
  PRIMARY KEY (`relations_id`),
  KEY `right_name` (`right_name`)
) ENGINE=MyISAM AUTO_INCREMENT=21898 DEFAULT CHARSET=utf8;


--
-- Table structure for table `remote_access_info`
--
DROP TABLE IF EXISTS `remote_access_info`;
CREATE TABLE `remote_access_info` (
  `remote_access_id` int(11) NOT NULL AUTO_INCREMENT,
  `computersystem_id` int(11) NOT NULL,
  `remote_console_ip` varchar(255) DEFAULT NULL,
  `remote_console_name` varchar(255) DEFAULT NULL,
  `remote_console_port` varchar(255) DEFAULT NULL,
  `remote_console_notes` varchar(255) DEFAULT NULL,
  `remote_console_type` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`remote_access_id`),
  KEY `computersystem_id` (`computersystem_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `servicefunction`
--
DROP TABLE IF EXISTS `servicefunction`;
CREATE TABLE `servicefunction` (
  `servicefunction_id` int(11) NOT NULL AUTO_INCREMENT,
  `computersystem_id` int(11) NOT NULL,
  `servicefunction` varchar(255) DEFAULT NULL,
  `serviceprovider` varchar(255) DEFAULT NULL,
  `servicegroup` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`servicefunction_id`),
  KEY `computersystem_id` (`computersystem_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `system_usage`
--

DROP TABLE IF EXISTS `system_usage`;
CREATE TABLE `system_usage` (
  `system_usage_id` int(11) NOT NULL AUTO_INCREMENT,
  `computersystem_id` int(11) NOT NULL,
  `system_service_usage_code` varchar(255) DEFAULT NULL,
  `system_usage_details` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`system_usage_id`),
  KEY `computersystem_id` (`computersystem_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `translation`
--
DROP TABLE IF EXISTS `translation`;
CREATE TABLE `translation` (
  `component` varchar(255) DEFAULT NULL,
  `attribute` varchar(255) DEFAULT NULL,
  `src_value` varchar(255) DEFAULT NULL,
  `tx_value` varchar(255) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `translation_backup`
--
DROP TABLE IF EXISTS `translation_backup`;
CREATE TABLE `translation_backup` (
  `component` varchar(255) DEFAULT NULL,
  `attribute` varchar(255) DEFAULT NULL,
  `src_value` varchar(255) DEFAULT NULL,
  `tx_value` varchar(255) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `uat`
--
DROP TABLE IF EXISTS `uat`;
CREATE TABLE `uat` (
  `uat_id` int(11) NOT NULL AUTO_INCREMENT,
  `table` varchar(255) NOT NULL,
  `tag` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL,
  PRIMARY KEY (`uat_id`)
) ENGINE=MyISAM AUTO_INCREMENT=60 DEFAULT CHARSET=utf8;


--
-- Table structure for table `virtual_ci`
--
DROP TABLE IF EXISTS `virtual_ci`;
CREATE TABLE `virtual_ci` (
  `virtual_ci_id` int(11) NOT NULL AUTO_INCREMENT,
  `virtualization_role` varchar(255) DEFAULT NULL,
  `virtualization_technology` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`virtual_ci_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1926 DEFAULT CHARSET=utf8;


--
-- Table structure for table `workgroups`
--
DROP TABLE IF EXISTS workgroups;
CREATE TABLE workgroups (
  workgroups_id           int(11) NOT NULL AUTO_INCREMENT,
  application_instance_id int(11) DEFAULT NULL,
  configgroup             varchar(255) DEFAULT NULL,
  supervisor              varchar(255) DEFAULT NULL,
  implementer             varchar(255) DEFAULT NULL,
  management              varchar(255) DEFAULT NULL,
  approver                varchar(255) DEFAULT NULL,
  assignment              varchar(255) DEFAULT NULL,
  PRIMARY KEY (`workgroups_id`),
  KEY `application_instance_id` (`application_instance_id`)
) ENGINE=MyISAM AUTO_INCREMENT=31 DEFAULT CHARSET=utf8;

--
-- Table to keep track of run date & data date
--

DROP TABLE IF EXISTS `alu_snapshot`;
CREATE TABLE IF NOT EXISTS `alu_snapshot` (
  snapshot_data_timestamp TIMESTAMP NOT NULL DEFAULT 0,
  snapshot_lastrun_timestamp TIMESTAMP NOT NULL DEFAULT 0,
  PRIMARY KEY (snapshot_data_timestamp)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `backup`
--
DROP TABLE IF EXISTS `backup`;
CREATE TABLE `backup` (
  `backup_id`                 int(11) NOT NULL AUTO_INCREMENT,
  `computersystem_id`         int(11) DEFAULT NULL,
  `backup_storage`            varchar(100) DEFAULT NULL,
  `backup_retention`          varchar(255) DEFAULT NULL,
  `backup_mode`               varchar(100) DEFAULT NULL,
  `backup_schedule`           varchar(3072) DEFAULT NULL,
  `backup_restartable`        varchar(100) DEFAULT NULL,
  `backup_server`             varchar(100) DEFAULT NULL,
  `backup_media_server`       varchar(100) DEFAULT NULL,
  `backup_information`        varchar(512) DEFAULT NULL,
  `backup_restore_procedures` varchar(512) DEFAULT NULL,
  PRIMARY KEY (`backup_id`),
  KEY `computersystem_id` (`computersystem_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


--
-- Table structure for table `uuid_map`
-- uuid_map is used to generate unique and stable id's
--

DROP TABLE IF EXISTS uuid_map;
CREATE TABLE uuid_map (
  uuid_map_id       int(11) NOT NULL AUTO_INCREMENT,
  uuid_type         varchar(100) NOT NULL, -- either the string 'portfolio_id' or 'acronym'
  application_key   varchar(255) NOT NULL, -- this is currently the application tag
  uuid_value        varchar(255) DEFAULT NULL, -- this is a portfolio_id or an acronym
  PRIMARY KEY (uuid_map_id),
  -- UNIQUE KEY `unique_key` (uuid_type, application_key)
  UNIQUE KEY `unique_value` (uuid_type, uuid_value)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
