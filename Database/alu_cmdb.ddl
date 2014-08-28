DROP DATABASE IF EXISTS alu_cmdb;

SET character_set_client = utf8;

CREATE DATABASE alu_cmdb
  DEFAULT CHARACTER SET utf8
  DEFAULT COLLATE utf8_general_ci;
  
USE `alu_cmdb`;

-- ***************************************************************************************************************************
-- Portfolio Tables 
--   pf_business_mgd
--   pf_is_it_mgd
--   pf_it_other
-- ***************************************************************************************************************************

DROP TABLE IF EXISTS `pf_business_mgd`;
CREATE TABLE `pf_business_mgd` (
  `ID`                                                       int(11) NOT NULL AUTO_INCREMENT,
  `App ID`                                                   VARCHAR(012) DEFAULT NULL, -- portfolio_id
  `App Acronym`                                              VARCHAR(100) DEFAULT NULL,
  `App Name`                                                 VARCHAR(150) DEFAULT NULL,
  `App Desc`                                                 VARCHAR(3072) DEFAULT NULL,
  `App Lifecycle Status`                                     VARCHAR(100) DEFAULT NULL,
  `ALS Notes`                                                VARCHAR(3072) DEFAULT NULL,
  `Decomm Date`                                              VARCHAR(50) DEFAULT NULL,
  `Target Date for Read Only to Stop Fully`                  VARCHAR(50) DEFAULT NULL,
  `Target Solution`                                          VARCHAR(255) DEFAULT NULL,
  `Main Region`                                              VARCHAR(50) DEFAULT NULL,
  `Countries`                                                VARCHAR(100) DEFAULT NULL,
  `User Display Languages`                                   VARCHAR(150) DEFAULT NULL,
  `Incl in Scorecard`                                        VARCHAR(50) DEFAULT NULL,
  `Book Close Impacting`                                     VARCHAR(50) DEFAULT NULL,
  `NSA Indicator`                                            VARCHAR(50) DEFAULT NULL,
  `Functional Mapping (L1) -- renamed from Business Area`    VARCHAR(150) DEFAULT NULL,
  `Functional Mapping (L2) -- Renamed from Business Subarea` VARCHAR(150) DEFAULT NULL,
  `Business Stakeholder Org`                                 VARCHAR(150) DEFAULT NULL,
  `Business Stakeholder Name`                                VARCHAR(100) DEFAULT NULL,
  `Key Business User`                                        VARCHAR(255) DEFAULT NULL,
  `B&ITT Process Domain`                                     VARCHAR(100) DEFAULT NULL,
  `ER Approver`                                              VARCHAR(50) DEFAULT NULL,
  `IS/IT App Mgd Org`                                        VARCHAR(50) DEFAULT NULL,
  `IS/IT Infra Mgd`                                          VARCHAR(50) DEFAULT NULL,
  `App Director`                                             VARCHAR(100) DEFAULT NULL,
  `App Manager`                                              VARCHAR(100) DEFAULT NULL,
  `Solution Lead`                                            VARCHAR(50) DEFAULT NULL,
  `Ops Lead`                                                 VARCHAR(50) DEFAULT NULL,
  `Sourcing Accountable`                                     VARCHAR(50) DEFAULT NULL,
  `Outsource Responsible`                                    VARCHAR(50) DEFAULT NULL,
  `Outsource/Sourcing Comments`                              VARCHAR(512) DEFAULT NULL,
  `Active User Count`                                        VARCHAR(100) DEFAULT NULL,
  `Service Level`                                            VARCHAR(50) DEFAULT NULL,
  `Service Window (Proposed)`                                VARCHAR(50) DEFAULT NULL,
  `Service Window Comment`                                   VARCHAR(512) DEFAULT NULL,
  `Support Staff Count`                                      VARCHAR(50) DEFAULT NULL,
  `Primary Helpdesk`                                         VARCHAR(60) DEFAULT NULL,
  `Service Request Tool`                                     VARCHAR(50) DEFAULT NULL,
  `Change Management Tool`                                   VARCHAR(50) DEFAULT NULL,
  `Defect Reporting Tool`                                    VARCHAR(50) DEFAULT NULL,
  `ER-Tool`                                                  VARCHAR(50) DEFAULT NULL,
  `Knowledge Management Tool`                                VARCHAR(50) DEFAULT NULL,
  `OVSD ID`                                                  VARCHAR(50) DEFAULT NULL,
  `AssetCtr ID`                                              VARCHAR(50) DEFAULT NULL,
  `Ticket Volume Changes`                                    VARCHAR(50) DEFAULT NULL,
  `Ticket Volume DR`                                         VARCHAR(50) DEFAULT NULL,
  `Ticket Volume ER`                                         VARCHAR(50) DEFAULT NULL,
  `Ticket Volume SR`                                         VARCHAR(50) DEFAULT NULL,
  `Server O/S`                                               VARCHAR(50) DEFAULT NULL,
  `Server Comments`                                          VARCHAR(255) DEFAULT NULL,
  `Web Browsers Supported`                                   VARCHAR(100) DEFAULT NULL,
  `Client Comments`                                          VARCHAR(155) DEFAULT NULL,
  `Desktop Client O/S Supported`                             VARCHAR(55) DEFAULT NULL,
  `MS Office Integration Required`                           VARCHAR(55) DEFAULT NULL,
  `App Security`                                             VARCHAR(155) DEFAULT NULL,
  `Security Comments`                                        VARCHAR(105) DEFAULT NULL,
  `Database & Version`                                       VARCHAR(255) DEFAULT NULL,
  `SW Package`                                               VARCHAR(255) DEFAULT NULL,
  `SW Release`                                               VARCHAR(255) DEFAULT NULL,
  `Dev Language and Tools`                                   VARCHAR(255) DEFAULT NULL,
  `Backup Req (Retention Period)`                            VARCHAR(155) DEFAULT NULL,
  `Backup Notes`                                             VARCHAR(155) DEFAULT NULL,
  `Documentation Quality`                                    VARCHAR(55) DEFAULT NULL,
  `PWD Change Process`                                       VARCHAR(55) DEFAULT NULL,
  `PWD Expiration Notice`                                    VARCHAR(55) DEFAULT NULL,
  `Date App Moved to Production`                             VARCHAR(55) DEFAULT NULL,
  `Date Added to Portfolio`                                  VARCHAR(55) DEFAULT NULL,
  `Reason For Add`                                           VARCHAR(1024) DEFAULT NULL,
  `Origin`                                                   VARCHAR(55) DEFAULT NULL,
  `Date Marked Stopped`                                      VARCHAR(55) DEFAULT NULL,
  `Modified By`                                              VARCHAR(55) DEFAULT NULL,
  `Modified`                                                 VARCHAR(55) DEFAULT NULL,
  `Created By`                                               VARCHAR(55) DEFAULT NULL,
  `Created`                                                  VARCHAR(55) DEFAULT NULL,
  `Change Notes`                                             VARCHAR(512) DEFAULT NULL,
  `Core Program`                                             VARCHAR(55) DEFAULT NULL,
  `HP T-E2E Decom Assessment`                                VARCHAR(55) DEFAULT NULL,
  `Business Critical App Identification`                     VARCHAR(55) DEFAULT NULL,
  `Managed BY`                                               VARCHAR(55) DEFAULT NULL,
  `R&D Tool`                                                 VARCHAR(55) DEFAULT NULL,
  `IT Contact`                                               VARCHAR(55) DEFAULT NULL,
  `Business App Contact`                                     VARCHAR(55) DEFAULT NULL,
  `Item Type`                                                VARCHAR(55) DEFAULT NULL,
  `Path`                                                     VARCHAR(155) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `func_key` (`App ID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `pf_is_it_mgd`;
CREATE TABLE `pf_is_it_mgd` (
  `ID`                                                       int(11) NOT NULL AUTO_INCREMENT,
  `App ID`                                                   varchar(12) DEFAULT NULL,
  `App Acronym`                                              varchar(100) DEFAULT NULL,
  `App Name`                                                 varchar(150) DEFAULT NULL,
  `App Desc`                                                 varchar(2303) DEFAULT NULL,
  `App Lifecycle Status`                                     varchar(50) DEFAULT NULL,
  `ALS Notes`                                                varchar(2560) DEFAULT NULL,
  `Decomm Date`                                              varchar(15) DEFAULT NULL,
  `Target Date for Read Only to Stop Fully`                  varchar(15) DEFAULT NULL,
  `Target Solution`                                          varchar(512) DEFAULT NULL,
  `Main Region`                                              varchar(16) DEFAULT NULL,
  `Countries`                                                varchar(256) DEFAULT NULL,
  `User Display Languages`                                   varchar(150) DEFAULT NULL,
  `Incl in Scorecard`                                        varchar(10) DEFAULT NULL,
  `Book Close Impacting`                                     varchar(50) DEFAULT NULL,
  `NSA Indicator`                                            varchar(25) DEFAULT NULL,
  `Functional Mapping (L1) -- (renamed from Business Area)`  varchar(255) DEFAULT NULL,
  `Functional Mapping (L2) -- renamed from Business Subarea` varchar(100) DEFAULT NULL,
  `Business Stakeholder Org`                                 varchar(100) DEFAULT NULL,
  `Business Stakeholder Name`                                varchar(512) DEFAULT NULL,
  `Key Business User`                                        varchar(4500) DEFAULT NULL,
  `B&ITT Process Domain`                                     varchar(100) DEFAULT NULL,
  `ER Approver`                                              varchar(25) DEFAULT NULL,
  `IS/IT App Mgd Org`                                        varchar(10) DEFAULT NULL,
  `IS/IT Infra Mgd`                                          varchar(50) DEFAULT NULL,
  `Application Director (SAM)`                               varchar(32) DEFAULT NULL,
  `App Manager (SAM)`                                        varchar(50) DEFAULT NULL,
  `Solution Lead (SAM)`                                      varchar(100) DEFAULT NULL,
  `Ops Lead`                                                 varchar(64) DEFAULT NULL,
  `Sourcing Accountable`                                     varchar(50) DEFAULT NULL,
  `Outsource Responsible`                                    varchar(50) DEFAULT NULL,
  `Outsource/Sourcing Comments`                              varchar(800) DEFAULT NULL,
  `Active User Count`                                        varchar(100) DEFAULT NULL,
  `Service Level`                                            varchar(16) DEFAULT NULL,
  `Service Window (Proposed)`                                varchar(25) DEFAULT NULL,
  `Service Window Comment`                                   varchar(100) DEFAULT NULL,
  `Support Staff Count`                                      varchar(10) DEFAULT NULL,
  `Primary Helpdesk`                                         varchar(60) DEFAULT NULL,
  `Service Request Tool`                                     varchar(75) DEFAULT NULL,
  `Change Management Tool`                                   varchar(50) DEFAULT NULL,
  `Defect Reporting Tool`                                    varchar(75) DEFAULT NULL,
  `ER-Tool`                                                  varchar(150) DEFAULT NULL,
  `Knowledge Management Tool`                                varchar(150) DEFAULT NULL,
  `OVSD ID`                                                  varchar(100) DEFAULT NULL,
  `AssetCtr ID`                                              varchar(25) DEFAULT NULL,
  `Ticket Volume Changes`                                    int(5) DEFAULT NULL,
  `Ticket Volume DR`                                         int(5) DEFAULT NULL,
  `Ticket Volume ER`                                         int(5) DEFAULT NULL,
  `Ticket Volume SR`                                         int(5) DEFAULT NULL,
  `Server O/S`                                               varchar(255) DEFAULT NULL,
  `Server Comments`                                          varchar(800) DEFAULT NULL,
  `Web Browsers Supported`                                   varchar(200) DEFAULT NULL,
  `Client Comments`                                          varchar(1024) DEFAULT NULL,
  `Desktop Client O/S Supported`                             varchar(100) DEFAULT NULL,
  `MS Office Integration Required`                           varchar(10) DEFAULT NULL,
  `App Security`                                             varchar(100) DEFAULT NULL,
  `Security Comments`                                        varchar(512) DEFAULT NULL,
  `Database & Version`                                       varchar(150) DEFAULT NULL,
  `SW Package`                                               varchar(300) DEFAULT NULL,
  `SW Release`                                               varchar(300) DEFAULT NULL,
  `Dev Language and Tools`                                   varchar(300) DEFAULT NULL,
  `Backup Req (Retention Period)`                            varchar(100) DEFAULT NULL,
  `Backup Notes`                                             varchar(150) DEFAULT NULL,
  `Documentation Quality`                                    varchar(25) DEFAULT NULL,
  `PWD Change Process`                                       varchar(40) DEFAULT NULL,
  `PWD Expiration Notice`                                    varchar(10) DEFAULT NULL,
  `Date App Moved to Production`                             varchar(10) DEFAULT NULL,
  `Date Added to Portfolio`                                  varchar(10) DEFAULT NULL,
  `Reason For Add`                                           varchar(1024) DEFAULT NULL,
  `Origin`                                                   varchar(10) DEFAULT NULL,
  `Date Marked Stopped`                                      varchar(10) DEFAULT NULL,
  `Modified By`                                              varchar(55) DEFAULT NULL,
  `Modified`                                                 varchar(25) DEFAULT NULL, 
  `Created By`                                               varchar(55) DEFAULT NULL,
  `Created`                                                  varchar(25) DEFAULT NULL,
  `Change Notes`                                             varchar(300) DEFAULT NULL,
  `Core Program`                                             varchar(100) DEFAULT NULL,
  `HP T-E2E Decom Assessment`                                varchar(25) DEFAULT NULL,
  `Business Critical App Identification`                     varchar(25) DEFAULT NULL,
  `Managed BY`                                               varchar(25) DEFAULT NULL,
  `R&D Tool`                                                 varchar(10) DEFAULT NULL,
  `ER Lead (AD)`                                             varchar(40) DEFAULT NULL,
  `Key Application`                                          varchar(10) DEFAULT NULL,
  `Domain Lead (AD)`                                         varchar(200) DEFAULT NULL,
  `App Director (AD)`                                        varchar(40) DEFAULT NULL,
  `Cluster`                                                  varchar(40) DEFAULT NULL,
  `Sub-Cluster`                                              varchar(90) DEFAULT NULL,
  `Item Type`                                                varchar(10) DEFAULT NULL,
  `Path`                                                     varchar(100) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `func_key` (`App ID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `pf_it_other`;
CREATE TABLE `pf_it_other` (
  `ID`                                                       int(11) NOT NULL AUTO_INCREMENT,
  `App ID`                                                   varchar(012) DEFAULT NULL,
  `App Acronym`                                              varchar(100) DEFAULT NULL,
  `App Name`                                                 varchar(150) DEFAULT NULL,
  `App Desc`                                                 varchar(2303) DEFAULT NULL,
  `App Lifecycle Status`                                     varchar(50) DEFAULT NULL,
  `ALS Notes`                                                varchar(2560) DEFAULT NULL,
  `Decomm Date`                                              varchar(25) DEFAULT NULL,
  `Target Date for Read Only to Stop Fully`                  varchar(25) DEFAULT NULL,
  `Target Solution`                                          varchar(512) DEFAULT NULL,
  `App Info Link`                                            varchar(255) DEFAULT NULL,
  `Main Region`                                              varchar(25) DEFAULT NULL,
  `Countries`                                                varchar(512) DEFAULT NULL,
  `User Display Languages`                                   varchar(150) DEFAULT NULL,
  `Incl in Scorecard`                                        varchar(25) DEFAULT NULL,
  `Book Close Impacting`                                     varchar(50) DEFAULT NULL,
  `NSA Indicator`                                            varchar(25) DEFAULT NULL,
  `Functional Mapping (L1) -- (renamed from Business Area)`  varchar(255) DEFAULT NULL,
  `Functional Mapping (L1) -- renamed from Business Subarea` varchar(150) DEFAULT NULL,
  `Business Stakeholder Org`                                 varchar(100) DEFAULT NULL,
  `Business Stakeholder Name`                                varchar(512) DEFAULT NULL,
  `Key Business User`                                        varchar(512) DEFAULT NULL,
  `B&ITT Process Domain`                                     varchar(100) DEFAULT NULL,
  `ER Approver`                                              varchar(25) DEFAULT NULL,
  `IS/IT App Mgd Org`                                        varchar(25) DEFAULT NULL,
  `IS/IT Infra Mgd`                                          varchar(50) DEFAULT NULL,
  `App Director (SAM)`                                       varchar(50) DEFAULT NULL,
  `App Manager (SAM)`                                        varchar(50) DEFAULT NULL,
  `Solution Lead (SAM)`                                      varchar(100) DEFAULT NULL,
  `Ops Lead`                                                 varchar(100) DEFAULT NULL,
  `Sourcing Accountable`                                     varchar(50) DEFAULT NULL,
  `Outsource Responsible`                                    varchar(50) DEFAULT NULL,
  `Outsource/Sourcing Comments`                              varchar(800) DEFAULT NULL,
  `Active User Count`                                        varchar(255) DEFAULT NULL,
  `Service Level (Proposed)`                                 varchar(25) DEFAULT NULL,
  `Service Window (Proposed)`                                varchar(25) DEFAULT NULL,
  `Service Window Comment`                                   varchar(255) DEFAULT NULL,
  `Support Staff Count`                                      varchar(50) DEFAULT NULL,
  `Primary Helpdesk`                                         varchar(60) DEFAULT NULL,
  `Service Request Tool`                                     varchar(100) DEFAULT NULL,
  `Change Management Tool`                                   varchar(100) DEFAULT NULL,
  `Defect Reporting Tool`                                    varchar(100) DEFAULT NULL,
  `ER-Tool`                                                  varchar(150) DEFAULT NULL,
  `Knowledge Management Tool`                                varchar(150) DEFAULT NULL,
  `OVSD ID`                                                  varchar(100) DEFAULT NULL,
  `AssetCtr ID`                                              varchar(25) DEFAULT NULL,
  `Ticket Volume Changes`                                    int(5) DEFAULT NULL,
  `Ticket Volume DR`                                         int(5) DEFAULT NULL,
  `Ticket Volume ER`                                         int(5) DEFAULT NULL,
  `Ticket Volume SR`                                         int(5) DEFAULT NULL,
  `Server O/S`                                               varchar(255) DEFAULT NULL,
  `Server Comments`                                          varchar(512) DEFAULT NULL,
  `Web Browsers Supported`                                   varchar(255) DEFAULT NULL,
  `Client Comments`                                          varchar(512) DEFAULT NULL,
  `Desktop Client O/S Supported`                             varchar(150) DEFAULT NULL,
  `MS Office Integration Required`                           varchar(25) DEFAULT NULL,
  `App Security`                                             varchar(100) DEFAULT NULL,
  `Security Comments`                                        varchar(512) DEFAULT NULL,
  `Database & Version`                                       varchar(150) DEFAULT NULL,
  `SW Package`                                               varchar(512) DEFAULT NULL,
  `SW Release`                                               varchar(512) DEFAULT NULL,
  `Dev Language and Tools`                                   varchar(512) DEFAULT NULL,
  `Backup Req (Retention Period)`                            varchar(100) DEFAULT NULL,
  `Backup Notes`                                             varchar(150) DEFAULT NULL,
  `Documentation Quality`                                    varchar(25) DEFAULT NULL,
  `PWD Change Process`                                       varchar(50) DEFAULT NULL,
  `PWD Expiration Notice`                                    varchar(25) DEFAULT NULL,
  `Date App Moved to Production`                             varchar(25) DEFAULT NULL,
  `Date Added to Portfolio`                                  varchar(25) DEFAULT NULL,
  `Reason for Add`                                           varchar(512) DEFAULT NULL,
  `Origin`                                                   varchar(25) DEFAULT NULL,
  `Date Marked Stopped`                                      varchar(25) DEFAULT NULL,
  `Modified By`                                              varchar(55) DEFAULT NULL,
  `Modified`                                                 varchar(25) DEFAULT NULL, 
  `Created By`                                               varchar(55) DEFAULT NULL,
  `Created`                                                  varchar(25) DEFAULT NULL,
  `Change Notes`                                             varchar(512) DEFAULT NULL,
  `Core Program`                                             varchar(100) DEFAULT NULL,
  `HP T-E2E Decom Assessment`                                varchar(25) DEFAULT NULL,
  `Business Critical App Identification`                     varchar(25) DEFAULT NULL,
  `Portfolio Type`                                           varchar(255) DEFAULT NULL,
  `R&D Tool`                                                 varchar(255) DEFAULT NULL,
  `Item Type`                                                varchar(25) DEFAULT NULL,
  `Path`                                                     varchar(100) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `func_key` (`App ID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


-- ***************************************************************************************************************************
DROP TABLE IF EXISTS `alu_acronym_mapping`;
CREATE TABLE `alu_acronym_mapping` (
  `ID`            int(11) NOT NULL AUTO_INCREMENT,
  `App ID`        varchar(012) DEFAULT NULL, -- portfolio_id
  `App Acronym`   varchar(512) DEFAULT NULL, -- dit is puur informatief en wordt niet overgenomen in cim.acronym_mapping
  `App Name`      varchar(255) DEFAULT NULL, -- dit is puur informatief en wordt niet overgenomen in cim.acronym_mapping
  `App Desc`      varchar(2303) DEFAULT NULL, -- dit is puur informatief en wordt niet overgenomen in cim.acronym_mapping
  `New Acronym`   varchar(255) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `func_key` (`App ID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table with one row to track the origin of the data
--
CREATE TABLE `alu_snapshot` (
  snapshot_data_timestamp TIMESTAMP NOT NULL DEFAULT 0,
  PRIMARY KEY (snapshot_data_timestamp)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table with per row the file loaded into which table
--
CREATE TABLE `alu_snapshot_files` (
  snapshot_table VARCHAR(60) NOT NULL DEFAULT "",
  snapshot_folder VARCHAR(255) NOT NULL DEFAULT "",
  snapshot_filename VARCHAR(60) NOT NULL DEFAULT "",
  snapshot_table_added_timestamp TIMESTAMP NOT NULL DEFAULT 0,
  PRIMARY KEY (snapshot_table)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- *************************************************************************************************************************** --
-- TABLES FOR ESL                                                                                                              --
--   esl_asset_info		  	??
--   esl_cs_admin		  	loaded
--   esl_cs_availability	loaded
--   esl_cs_functions		loaded
--   esl_cs_techn_cons      loaded
--   esl_cs_techn_gen       loaded
--   esl_cs_techn_ip        loaded
--   esl_cs_usage           loaded
--   esl_hardware_extract   loaded
--   esl_instance           loaded
--   esl_instance_work      ??
--   esl_locations          loaded
--   esl_relations          loaded
-- *************************************************************************************************************************** --

--
-- Table structure for table `esl_cs_admin`
--
DROP TABLE IF EXISTS `esl_cs_admin`;
CREATE TABLE `esl_cs_admin` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Full Nodename` varchar(100) DEFAULT NULL,
  `Application Notes` varchar(255) DEFAULT NULL,
  `Backup Notes` varchar(255) DEFAULT NULL,
  `Category` varchar(100) DEFAULT NULL,
  `Contract Notes` varchar(1024) DEFAULT NULL,
  `Customer Notes` varchar(1024) DEFAULT NULL,
  `General Notes` varchar(1024) DEFAULT NULL,
  `Hardware Notes` varchar(1024) DEFAULT NULL,
  `Management Region` varchar(100) DEFAULT NULL,
  `NSA` varchar(50) DEFAULT NULL,
  `Other Notes` varchar(255) DEFAULT NULL,
  `Patch Notes` varchar(1024) DEFAULT NULL,
  `Security Class` varchar(50) DEFAULT NULL,
  `Security Notes` varchar(255) DEFAULT NULL,
  `Service Notes` varchar(50) DEFAULT NULL,
  `SOX Classification` varchar(50) DEFAULT NULL,
  `System Status` varchar(50) DEFAULT NULL,
  `System Type` varchar(50) DEFAULT NULL,
  `Timezone` varchar(100) DEFAULT NULL,
  `Sub Business Name` varchar(100) DEFAULT NULL,
  `Product Number` varchar(100) DEFAULT NULL,
  `Asset Type` varchar(50) DEFAULT NULL,
  `Project ID` varchar(100) DEFAULT NULL,
  `Start Date` varchar(50) DEFAULT NULL,
  `Asset Notes` varchar(1024) DEFAULT NULL,
  `System Group Name` varchar(100) DEFAULT NULL,
  `System Group Type` varchar(50) DEFAULT NULL,
  `System Group Description` varchar(512) DEFAULT NULL,
  `System ID` varchar(50) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `esl_cs_availability`
--
DROP TABLE IF EXISTS `esl_cs_availability`;
CREATE TABLE `esl_cs_availability` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Full Nodename` varchar(255) DEFAULT NULL,
  `Assignment Group` varchar(255) DEFAULT NULL,
  `Availability` varchar(255) DEFAULT NULL,
  `Coverage` varchar(255) DEFAULT NULL,
  `Environment` varchar(255) DEFAULT NULL,
  `Escalation Assignment Group` varchar(255) DEFAULT NULL,
  `Impact` varchar(255) DEFAULT NULL,
  `Impact Description` MEDIUMTEXT DEFAULT NULL,
  `Possible Downtime` varchar(255) DEFAULT NULL,
  `Service Level` varchar(255) DEFAULT NULL,
  `Authorized Reboot Requestor` varchar(255) DEFAULT NULL,
  `Capacity Management Contact` varchar(255) DEFAULT NULL,
  `Customer Change Coordinator` varchar(255) DEFAULT NULL,
  `Downtime Contact` varchar(255) DEFAULT NULL,
  `Restore Contact` varchar(255) DEFAULT NULL,
  `Technical Owner` varchar(255) DEFAULT NULL,
  `Technical Owner Backup` varchar(255) DEFAULT NULL,
  `Technical Lead` varchar(255) DEFAULT NULL,
  `Technical Lead Backup` varchar(255) DEFAULT NULL,
  `Sub Business Name` varchar(255) DEFAULT NULL,
  `System ID` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `esl_cs_functions`
--
DROP TABLE IF EXISTS `esl_cs_functions`;
CREATE TABLE `esl_cs_functions` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Full Nodename` varchar(255) DEFAULT NULL,
  `Sub Business Name` varchar(255) DEFAULT NULL,
  `Function` varchar(255) DEFAULT NULL,
  `Function Provider` varchar(255) DEFAULT NULL,
  `Function Provider Location` varchar(255) DEFAULT NULL,
  `Parent Function Provider` varchar(255) DEFAULT NULL,
  `Function Service Name` varchar(255) DEFAULT NULL,
  `System ID` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `esl_cs_techn_cons`
--
DROP TABLE IF EXISTS `esl_cs_techn_cons`;
CREATE TABLE `esl_cs_techn_cons` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Full Nodename` varchar(255) DEFAULT NULL,
  `Sub Business Name` varchar(255) DEFAULT NULL,
  `Console IP` varchar(255) DEFAULT NULL,
  `Console Name` varchar(255) DEFAULT NULL,
  `Console Type` varchar(255) DEFAULT NULL,
  `Console Port` varchar(255) DEFAULT NULL,
  `Console Notes` MEDIUMTEXT DEFAULT NULL,
  `System ID` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `esl_cs_techn_gen`
--
DROP TABLE IF EXISTS `esl_cs_techn_gen`;
CREATE TABLE `esl_cs_techn_gen` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Full Nodename` varchar(255) DEFAULT NULL,
  `Available Diskspace` varchar(255) DEFAULT NULL,
  `Cluster Architecture` varchar(255) DEFAULT NULL,
  `Cluster Technology` varchar(255) DEFAULT NULL,
  `Local Appl Disk Space` varchar(255) DEFAULT NULL,
  `OS Class` varchar(255) DEFAULT NULL,
  `OS Disk Space` varchar(255) DEFAULT NULL,
  `OS Installation Date` varchar(255) DEFAULT NULL,
  `OS Language` varchar(255) DEFAULT NULL,
  `OS Version` varchar(255) DEFAULT NULL,
  `Patch Level` varchar(255) DEFAULT NULL,
  `Patch Notes` MEDIUMTEXT DEFAULT NULL,
  `Physical Diskspace` varchar(255) DEFAULT NULL,
  `System Model` varchar(255) DEFAULT NULL,
  `System Type` varchar(255) DEFAULT NULL,
  `Timezone` varchar(255) DEFAULT NULL,
  `Used Diskspace` varchar(255) DEFAULT NULL,
  `Virtualization Role` varchar(255) DEFAULT NULL,
  `Virtualization Technology` varchar(255) DEFAULT NULL,
  `Sub Business Name` varchar(255) DEFAULT NULL,
  `System ID` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `esl_cs_techn_ip`
--
DROP TABLE IF EXISTS `esl_cs_techn_ip`;
CREATE TABLE `esl_cs_techn_ip` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Full Nodename` varchar(255) DEFAULT NULL,
  `Sub Business Name` varchar(255) DEFAULT NULL,
  `IP Type` varchar(255) DEFAULT NULL,
  `Alias/IP Name` varchar(255) DEFAULT NULL,
  `IP Address` varchar(255) DEFAULT NULL,
  `IP last detected on` varchar(255) DEFAULT NULL,
  `Subnet Name` varchar(255) DEFAULT NULL,
  `Subnet Mask` varchar(255) DEFAULT NULL,
  `LAN Speed` varchar(255) DEFAULT NULL,
  `Duplex Mode` varchar(255) DEFAULT NULL,
  `MAC Address` varchar(255) DEFAULT NULL,
  `Switch Name` varchar(255) DEFAULT NULL,
  `Port` varchar(255) DEFAULT NULL,
  `IP Notes` varchar(255) DEFAULT NULL,
  `Reachable from HP Mgmt LAN` varchar(255) DEFAULT NULL,
  `System ID` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `esl_cs_usage`
--
DROP TABLE IF EXISTS `esl_cs_usage`;
CREATE TABLE `esl_cs_usage` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Full Nodename` varchar(255) DEFAULT NULL,
  `Sub Business Name` varchar(255) DEFAULT NULL,
  `Usage` varchar(275) DEFAULT NULL,
  `Detailed Usage` varchar(255) DEFAULT NULL,
  `System ID` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `esl_hardware_extract`
--
DROP TABLE IF EXISTS `esl_hardware_extract`;
CREATE TABLE `esl_hardware_extract` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Full Nodename` varchar(100) DEFAULT NULL,
  `Asset Owner` varchar(255) DEFAULT NULL,
  `Clock Speed` varchar(255) DEFAULT NULL,
  `CPU Type` varchar(255) DEFAULT NULL,
  `Installed Memory` varchar(255) DEFAULT NULL,
  `Manufacturer` varchar(255) DEFAULT NULL,
  `Number of Cores per CPU` varchar(255) DEFAULT NULL,
  `Number of physical CPUs` varchar(255) DEFAULT NULL,
  `Order Number` varchar(255) DEFAULT NULL,
  `Physical Diskspace` varchar(255) DEFAULT NULL,
  `Processor Type` varchar(255) DEFAULT NULL,
  `Serial Number` varchar(255) DEFAULT NULL,
  `System Model` varchar(255) DEFAULT NULL,
  `System Status` varchar(255) DEFAULT NULL,
  `System Type` varchar(255) DEFAULT NULL,
  `Virtualization Role` varchar(255) DEFAULT NULL,
  `Virtualization Technology` varchar(255) DEFAULT NULL,
  `Sub Business Name` varchar(255) DEFAULT NULL,
  `DC Name` varchar(255) DEFAULT NULL,
  `DC Country` varchar(255) DEFAULT NULL,
  `DC Country ISO Name` varchar(255) DEFAULT NULL,
  `DC Town` varchar(255) DEFAULT NULL,
  `Asset Number` varchar(50) DEFAULT NULL,
  `Asset Type` varchar(50) DEFAULT NULL,
  `Product Number` varchar(255) DEFAULT NULL,
  `System ID` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `esl_instance`
-- Field10 => duplicate Customer Instance Owner column
-- Field11 => duplicate Customer Instance Support column
-- Field13 => duplicate Delivery Instance Owner column
-- Field14 => duplicate Delivery Instance Support column
-- 
DROP TABLE IF EXISTS `esl_instance`;
CREATE TABLE `esl_instance` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Full Nodename` varchar(120) DEFAULT NULL,
  `Sub Business Name` varchar(100) DEFAULT NULL,
  `Customer Instance Owner` varchar(100) DEFAULT NULL,
  `Customer Instance Support` varchar(100) DEFAULT NULL,
  `Delivery Instance Owner` varchar(100) DEFAULT NULL,
  `Delivery Instance Support` varchar(100) DEFAULT NULL,
  `Instance Authorised Requestor` varchar(100) DEFAULT NULL,
  `Instance Downtime Contact` varchar(100) DEFAULT NULL,
  `Third Party Instance Owner` varchar(100) DEFAULT NULL,
  `Field10` varchar(100) DEFAULT NULL,
  `Field11` varchar(100) DEFAULT NULL,
  `Customer Instance Support Escalation` varchar(100) DEFAULT NULL,
  `Field13` varchar(100) DEFAULT NULL,
  `Field14` varchar(100) DEFAULT NULL,
  `Instance Account Delivery Manager` varchar(100) DEFAULT NULL,
  `Instance Service Lead` varchar(100) DEFAULT NULL,
  `Solution ID` varchar(40) DEFAULT NULL,
  `Solution Category` varchar(100) DEFAULT NULL,
  `<I><font color=green>or </font></I>Solution Name <I>(free-text)<` varchar(512) DEFAULT NULL,
  `Instance ID` varchar(40) DEFAULT NULL,
  `Instance Name` varchar(150) DEFAULT NULL,
  `Instance URL` varchar(255) DEFAULT NULL,
  `Virtual Node` varchar(100) DEFAULT NULL,
  `Instance Assignment Group` varchar(100) DEFAULT NULL,
  `Instance Version` varchar(100) DEFAULT NULL,
  `Instance Status` varchar(100) DEFAULT NULL,
  `Instance Status Date` varchar(26) DEFAULT NULL,
  `Instance Create Date` varchar(26) DEFAULT NULL,
  `Instance Decommission Date` varchar(26) DEFAULT NULL,
  `Instance Last Modified Date` varchar(26) DEFAULT NULL,
  `Instance Production Date` varchar(26) DEFAULT NULL,
  `Instance Environment` varchar(100) DEFAULT NULL,
  `Last detected on` varchar(100) DEFAULT NULL,
  `Instance Impact` varchar(100) DEFAULT NULL,
  `Instance Service Level` varchar(100) DEFAULT NULL,
  `Instance Availability` varchar(40) DEFAULT NULL,
  `Instance Coverage` varchar(100) DEFAULT NULL,
  `Support Provider` varchar(100) DEFAULT NULL,
  `Instance Type` varchar(100) DEFAULT NULL,
  `Instance Order Number` varchar(100) DEFAULT NULL,
  `GOC RTPA Date` varchar(26) DEFAULT NULL,
  `Instance Reporting` varchar(40) DEFAULT NULL,
  `Instance Billable?` varchar(40) DEFAULT NULL,
  `Instance Billing Start` varchar(26) DEFAULT NULL,
  `Instance Billing End` varchar(26) DEFAULT NULL,
  `Business Description` varchar(255) DEFAULT NULL,
  `Instance Number` varchar(40) DEFAULT NULL,
  `Instance Customer` varchar(100) DEFAULT NULL,
  `Transformation Status` varchar(100) DEFAULT NULL,
  `BCRS Category` varchar(100) DEFAULT NULL,
  `Cluster Type` varchar(100) DEFAULT NULL,
  `Package Name` varchar(255) DEFAULT NULL,
  `Monitoring Solution` varchar(100) DEFAULT NULL,
  `Primary Management Account` varchar(100) DEFAULT NULL,
  `Listener Ports` varchar(40) DEFAULT NULL,
  `Connect String` varchar(100) DEFAULT NULL,
  `Connectivity Instructions` varchar(512) DEFAULT NULL,
  `BAC enabled?` varchar(40) DEFAULT NULL,
  `Total Instance Size (GB)` varchar(40) DEFAULT NULL,
  `Total Used Instance Size (GB)` varchar(40) DEFAULT NULL,
  `Number of Users` varchar(40) DEFAULT NULL,
  `Number of Instances` varchar(40) DEFAULT NULL,
  `Capacity Management Notes` varchar(100) DEFAULT NULL,
  `Daylight Savings Sensitivity` varchar(40) DEFAULT NULL,
  `Instance Startup Notes` varchar(100) DEFAULT NULL,
  `Instance Shutdown Notes` varchar(100) DEFAULT NULL,
  `Regular Processing/Jobs` varchar(100) DEFAULT NULL,
  `Instance License Notes` varchar(255) DEFAULT NULL,
  `Instance Patch Notes` varchar(100) DEFAULT NULL,
  `Additional Notes` varchar(255) DEFAULT NULL,
  `Backup Notes` varchar(1024) DEFAULT NULL,
  `Transaction Log Notes` varchar(255) DEFAULT NULL,
  `Restore/Recovery Notes` varchar(255) DEFAULT NULL,
  `Instance Master Server` varchar(100) DEFAULT NULL,
  `Instance Patch Level` varchar(100) DEFAULT NULL,
  `Product ID` varchar(100) DEFAULT NULL,
  `Product Level` varchar(100) DEFAULT NULL,
  `Product Edition` varchar(100) DEFAULT NULL,
  `Kernel Version` varchar(100) DEFAULT NULL,
  `Build Number` varchar(40) DEFAULT NULL,
  `Home Directory` varchar(255) DEFAULT NULL,
  `Load Balanced URL` varchar(100) DEFAULT NULL,
  `URL Monitoring Flag` varchar(100) DEFAULT NULL,
  `URL Monitoring SLA Level` varchar(100) DEFAULT NULL,
  `URL Response Time` varchar(40) DEFAULT NULL,
  `Used Components` varchar(100) DEFAULT NULL,
  `Full CI Name` varchar(255) DEFAULT NULL,
  `Business` varchar(100) DEFAULT NULL,
  `Solution Description` varchar(4000) DEFAULT NULL,
  `Business Criticality` varchar(100) DEFAULT NULL,
  `External Application ID` varchar(100) DEFAULT NULL,
  `Solution CMA` varchar(100) DEFAULT NULL,
  `External Source ID` varchar(100) DEFAULT NULL,
  `External Tool` varchar(40) DEFAULT NULL,
  `System ID` varchar(100) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `esl_locations`
--
DROP TABLE IF EXISTS `esl_locations`;
CREATE TABLE `esl_locations` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Full Nodename` varchar(255) DEFAULT NULL,
  `Sub Business Name` varchar(255) DEFAULT NULL,
  `Region` varchar(255) DEFAULT NULL,
  `Floor Space/Slot` varchar(255) DEFAULT NULL,
  `DC Name` varchar(255) DEFAULT NULL,
  `DC Owner` varchar(255) DEFAULT NULL,
  `DC Category` varchar(255) DEFAULT NULL,
  `DC Tier` varchar(255) DEFAULT NULL,
  `DC Timezone` varchar(255) DEFAULT NULL,
  `DC Country` varchar(255) DEFAULT NULL,
  `DC Country ISO Code` varchar(255) DEFAULT NULL,
  `DC Country ISO Name` varchar(255) DEFAULT NULL,
  `DC Post Code` varchar(255) DEFAULT NULL,
  `DC Town` varchar(255) DEFAULT NULL,
  `DC Street` varchar(255) DEFAULT NULL,
  `DC Building` varchar(255) DEFAULT NULL,
  `DC Floor` varchar(255) DEFAULT NULL,
  `Full Shipping Address` varchar(255) DEFAULT NULL,
  `DC Notes` MEDIUMTEXT DEFAULT NULL,
  `DC Access` varchar(255) DEFAULT NULL,
  `REWS Code` varchar(255) DEFAULT NULL,
  `Customer Alias` varchar(255) DEFAULT NULL,
  `OVSC Location Name` varchar(255) DEFAULT NULL,
  `OVSD Loc Code` varchar(255) DEFAULT NULL,
  `System ID` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `esl_relations`
--
DROP TABLE IF EXISTS `esl_relations`;
CREATE TABLE `esl_relations` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Full Nodename` varchar(255) DEFAULT NULL,
  `Sub Business Name` varchar(255) DEFAULT NULL,
  `Parent System` varchar(255) DEFAULT NULL,
  `Parent Relation Type` varchar(255) DEFAULT NULL,
  `Parent Provisioned Space` varchar(255) DEFAULT NULL,
  `Parent Used Space` varchar(255) DEFAULT NULL,
  `Parent Storage Tier` varchar(255) DEFAULT NULL,
  `Parent Relation Comment` varchar(255) DEFAULT NULL,
  `System ID` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;



















-- *************************************************************************************************************************** --
-- TABLES FOR OVSD                                                                                                              --
--   OVSD_SERVERS		  	loaded
--   OVSD_SERVER_RELS		loaded
--   OVSD_INTERFACE			loaded
--   OVSD_DB_RELS		    loaded
--   OVSD_DB		        loaded
--   OVSD_APPS_RELS	        loaded
--   OVSD_APPLICATIONS      loaded
--   ...      ??
-- *************************************************************************************************************************** --

--
-- Table structure for table `OVSD_SERVERS`
--
DROP TABLE IF EXISTS `ovsd_servers`;
CREATE TABLE `ovsd_servers` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `CIID` double DEFAULT NULL,
  `SEARCH CODE` varchar(100) DEFAULT NULL,
  `NAME` varchar(100) DEFAULT NULL,
  `ALIAS_NAMES (4000)` varchar(512) DEFAULT NULL,
  `SERIAL NUMBER` varchar(100) DEFAULT NULL,
  `CAPITAL ASSET TAG` varchar(100) DEFAULT NULL,
  `HOST_ID` varchar(100) DEFAULT NULL,
  `DESCRIPTION 4000` varchar(1024) DEFAULT NULL,
  `PARENT CATEGORY` varchar(100) DEFAULT NULL,
  `CATEGORY` varchar(100) DEFAULT NULL,
  `STATUS` varchar(100) DEFAULT NULL,
  `ENVIRONMENT` varchar(100) DEFAULT NULL,
  `Purpose/Function` varchar(100) DEFAULT NULL,
  `FORMER_ALCATEL` varchar(100) DEFAULT NULL,
  `MASTER_CMDB` varchar(100) DEFAULT NULL,
  `ASSETTAG` varchar(100) DEFAULT NULL,
  `ASSET CENTER CI RESPONSIBLE` varchar(100) DEFAULT NULL,
  `ASSET CENTER FIXED ASSET NUMBER` varchar(100) DEFAULT NULL,
  `ASSET CENTER OWNER` varchar(100) DEFAULT NULL,
  `ASSET CENTER PO` varchar(100) DEFAULT NULL,
  `ASSET CENTER REFERENCE` varchar(100) DEFAULT NULL,
  `ASSET CENTER SITE` varchar(100) DEFAULT NULL,
  `ROUTE_EVENT_TO` varchar(100) DEFAULT NULL,
  `MONITORED_BY` varchar(100) DEFAULT NULL,
  `SOX` varchar(100) DEFAULT NULL,
  `REMEDIATION COMPLETE` varchar(100) DEFAULT NULL,
  `SOX_TIER` varchar(100) DEFAULT NULL,
  `NSA` varchar(100) DEFAULT NULL,
  `LAST CMDB AUDIT DATE` datetime DEFAULT NULL,
  `OWNER ORGANIZATION SEARCH CODE` varchar(100) DEFAULT NULL,
  `OWNER PERSON SEARCH CODE` varchar(100) DEFAULT NULL,
  `OWNER PERSON NAME` varchar(100) DEFAULT NULL,
  `DOMAIN ANALYST` varchar(100) DEFAULT NULL,
  `ADMIN WORKGROUP` varchar(100) DEFAULT NULL,
  `ADMIN PRIMARY CONTACT SEARCH CODE` varchar(100) DEFAULT NULL,
  `ADMIN PRIMARY CONTACT NAME` varchar(100) DEFAULT NULL,
  `ADMIN SECONDARY CONTACT SEARCH CODE` varchar(100) DEFAULT NULL,
  `ADMIN SECONDARY CONTACT NAME` varchar(100) DEFAULT NULL,
  `SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE` varchar(100) DEFAULT NULL,
  `LOCATION DETAILS` varchar(255) DEFAULT NULL,
  `LOCATION` varchar(100) DEFAULT NULL,
  `STREET ADDRESS` varchar(255) DEFAULT NULL,
  `CITY` varchar(100) DEFAULT NULL,
  `STATE/PROVINCE` varchar(100) DEFAULT NULL,
  `ZIP CODE/POSTAL` varchar(100) DEFAULT NULL,
  `COUNTRY` varchar(100) DEFAULT NULL,
  `REGION` varchar(100) DEFAULT NULL,
  `NOTES` varchar(512) DEFAULT NULL,
  `DOC REFERENCE URL` varchar(512) DEFAULT NULL,
  `BRAND` varchar(100) DEFAULT NULL,
  `MODEL` varchar(100) DEFAULT NULL,
  `LEASED` varchar(100) DEFAULT NULL,
  `IP ADDRESS` varchar(100) DEFAULT NULL,
  `Secondary/Virtual IP Addresses (4000)` varchar(512) DEFAULT NULL,
  `OS CATEGORY` varchar(100) DEFAULT NULL,
  `OS NAME/VERSION` varchar(255) DEFAULT NULL,
  `OS NAME` varchar(100) DEFAULT NULL,
  `OS VER/REL/SP` varchar(100) DEFAULT NULL,
  `MEMORY SIZE` varchar(100) DEFAULT NULL,
  `CPU MODEL AND SPEED` varchar(100) DEFAULT NULL,
  `CPU MODEL` varchar(100) DEFAULT NULL,
  `CPU SPEED (MHZ)` varchar(100) DEFAULT NULL,
  `NO OF CPUs INSTALLED` varchar(100) DEFAULT NULL,
  `NO_OF_DISKS_X_DISK_SIZE` varchar(100) DEFAULT NULL,
  `USABLE_DISK_SPACE` varchar(100) DEFAULT NULL,
  `TAPE_DRIVES_PORTS` varchar(100) DEFAULT NULL,
  `REMOTE_ACCESS` varchar(512) DEFAULT NULL,
  `TIME_ZONE` varchar(100) DEFAULT NULL,
  `MAINTENANCE WINDOW` varchar(512) DEFAULT NULL,
  `MISC INFO` varchar(512) DEFAULT NULL,
  `BACKUP SOFTWARE` varchar(100) DEFAULT NULL,
  `BACKUP STORAGE` varchar(100) DEFAULT NULL,
  `BACKUP RETENTION` varchar(255) DEFAULT NULL,
  `BACKUP MODE` varchar(100) DEFAULT NULL,
  `BACKUP SCHEDULE` varchar(3072) DEFAULT NULL,
  `BACKUP RESTARTABLE` varchar(100) DEFAULT NULL,
  `BACKUP SERVER` varchar(100) DEFAULT NULL,
  `BACKUP MEDIA SERVER` varchar(100) DEFAULT NULL,
  `BACKUP INFORMATION` varchar(512) DEFAULT NULL,
  `BACKUP RESTORE PROCEDURES` varchar(512) DEFAULT NULL,
  `DISASTER RECOVERY TIER` varchar(100) DEFAULT NULL,
  `MAINTENANCE CONTRACT` varchar(100) DEFAULT NULL,
  `COVERAGE END DATE` datetime DEFAULT NULL,
  `GHD SUPPORT DETAILS` varchar(512) DEFAULT NULL,
  `DECOMMISSIONED DATE` datetime DEFAULT NULL,
  `RESOURCE UNIT` varchar(100) DEFAULT NULL,
  `E-INV DATE` varchar(100) DEFAULT NULL,
  `E-INV STATUS` varchar(100) DEFAULT NULL,
  `REGISTRATION CREATED DATE` datetime DEFAULT NULL,
  `BILLING CHANGE CATEGORY` varchar(100) DEFAULT NULL,
  `BILLING REQUEST NUMBER` varchar(100) DEFAULT NULL,
  `LAST BILLING CHANGE DATE` varchar(100) DEFAULT NULL,
  `ESL ID` varchar(50) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `OVSD_SERVER_RELS`
--
DROP TABLE IF EXISTS `ovsd_server_rels`;
CREATE TABLE `ovsd_server_rels` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `FROM-CIID` double DEFAULT NULL,
  `FROM-SEARCH CODE` varchar(100) DEFAULT NULL,
  `FROM-NAME` varchar(100) DEFAULT NULL,
  `FROM-ALIAS NAMES (4000)` varchar(3072) DEFAULT NULL,
  `FROM-SERIAL NUMBER` varchar(100) DEFAULT NULL,
  `FROM-CAPITAL ASSET TAG` varchar(100) DEFAULT NULL,
  `FROM-HOST ID` varchar(100) DEFAULT NULL,
  `FROM-DESCRIPTION (4000)` varchar(512) DEFAULT NULL,
  `FROM-CATEGORY` varchar(100) DEFAULT NULL,
  `RELATIONSHIP` varchar(100) DEFAULT NULL,
  `TO-CIID` double DEFAULT NULL,
  `TO-SEARCH CODE` varchar(100) DEFAULT NULL,
  `TO-NAME` varchar(100) DEFAULT NULL,
  `TO-ALIAS NAMES (4000)` varchar(3072) DEFAULT NULL,
  `TO-SERIAL NUMBER` varchar(100) DEFAULT NULL,
  `TO-CAPITAL ASSET TAG` varchar(100) DEFAULT NULL,
  `TO-HOST ID` varchar(100) DEFAULT NULL,
  `TO-DESCRIPTION (4000)` varchar(2048) DEFAULT NULL,
  `TO-CATEGORY` varchar(100) DEFAULT NULL,
  `TO-STATUS` varchar(100) DEFAULT NULL,
  `TO-ENVIRONMENT` varchar(100) DEFAULT NULL,
  `TO-PURPOSE/FUNCTION` varchar(100) DEFAULT NULL,
  `TO-MASTER CMDB` varchar(100) DEFAULT NULL,
  `TO-ASSET TAG` varchar(100) DEFAULT NULL,
  `TO-ROUTE EVENT TO` varchar(100) DEFAULT NULL,
  `TO-MONITORED BY` varchar(100) DEFAULT NULL,
  `TO-SOX` varchar(100) DEFAULT NULL,
  `TO-NSA` varchar(100) DEFAULT NULL,
  `TO-SOX TIER` varchar(100) DEFAULT NULL,
  `TO-OWNER ORGANIZATION SEARCH CODE` varchar(100) DEFAULT NULL,
  `TO-OWNER PERSON SEARCH CODE` varchar(100) DEFAULT NULL,
  `TO-OWNER PERSON NAME` varchar(100) DEFAULT NULL,
  `TO-DOMAIN ANALYST` varchar(100) DEFAULT NULL,
  `TO-WORKGROUP` varchar(100) DEFAULT NULL,
  `TO-ADMIN PRIMARY CONTACT SEARCH CODE` varchar(100) DEFAULT NULL,
  `TO-ADMIN PRIMARY CONTACT NAME` varchar(100) DEFAULT NULL,
  `TO-ADMIN SECONDARY CONTACT SEARCH CODE` varchar(100) DEFAULT NULL,
  `TO-ADMIN SECONDARY CONTACT NAME` varchar(100) DEFAULT NULL,
  `TO-SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE` varchar(100) DEFAULT NULL,
  `TO-LOCATION DETAILS` varchar(255) DEFAULT NULL,
  `TO-LOCATION` varchar(100) DEFAULT NULL,
  `TO-STREET ADDRESS` varchar(255) DEFAULT NULL,
  `TO-CITY` varchar(100) DEFAULT NULL,
  `TO-STATE/PROVINCE` varchar(100) DEFAULT NULL,
  `TO-ZIP CODE/POSTAL` varchar(100) DEFAULT NULL,
  `TO-COUNTRY` varchar(100) DEFAULT NULL,
  `TO-REGION` varchar(100) DEFAULT NULL,
  `TO-BRAND` varchar(100) DEFAULT NULL,
  `TO-MODEL` varchar(100) DEFAULT NULL,
  `TO-IP ADDRESS` varchar(100) DEFAULT NULL,
  `TO-SECONDARY/VIRTUAL IP ADDRESS (4000)` varchar(512) DEFAULT NULL,
  `TO-OS CATEGORY` varchar(100) DEFAULT NULL,
  `TO-OS NAME/VERSION` varchar(100) DEFAULT NULL,
  `TO-OS NAME` varchar(100) DEFAULT NULL,
  `TO-OS VER/REL/SP` varchar(100) DEFAULT NULL,
  `TO-MEMORY SIZE` varchar(100) DEFAULT NULL,
  `TO-CPU MODEL` varchar(100) DEFAULT NULL,
  `TO-CPU SPEED (MHZ)` double DEFAULT NULL,
  `TO-NO OF CPUs INSTALLED` double DEFAULT NULL,
  `TO-NO OF DISKS X DISK SIZE` varchar(100) DEFAULT NULL,
  `TO-USABLE DISK SPACE` varchar(100) DEFAULT NULL,
  `TO-TAPE DRIVES PORTS` varchar(100) DEFAULT NULL,
  `TO-REMOTE ACCESS` varchar(512) DEFAULT NULL,
  `TO-TIME ZONE` varchar(100) DEFAULT NULL,
  `TO-MAINTENANCE WINDOW` varchar(1024) DEFAULT NULL,
  `TO-DISASTER RECOVERY TIER` varchar(100) DEFAULT NULL,
  `TO-RESOURCE UNIT` varchar(100) DEFAULT NULL,
  `TO-E-INV DATE` varchar(100) DEFAULT NULL,
  `TO-E-INV STATUS` varchar(100) DEFAULT NULL,
  `TO-REGISTRATION CREATED DATE` datetime DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `OVSD_INTERFACE`
--
DROP TABLE IF EXISTS `ovsd_interface`;
CREATE TABLE `ovsd_interface` (
  `ID1` int(11) NOT NULL AUTO_INCREMENT,
  `ID` double DEFAULT NULL,
  `SEARCH_CODE` varchar(255) DEFAULT NULL,
  `RECEIVES FROM` varchar(255) DEFAULT NULL,
  `FROM SEARCHCODE` varchar(255) DEFAULT NULL,
  `SENDS TO` varchar(255) DEFAULT NULL,
  `TO SEARCHCODE` varchar(255) DEFAULT NULL,
  `CATEGORY` varchar(255) DEFAULT NULL,
  `NAME` varchar(255) DEFAULT NULL,
  `DESCRIPTION_4000` varchar(1024) DEFAULT NULL,
  `APPLICATION  INTERFACE_DATA` varchar(255) DEFAULT NULL,
  `APPLICATION INTERFACE_PARTNERS` varchar(255) DEFAULT NULL,
  `APPLICATION INTERFACE_TECHNOLOGY` varchar(255) DEFAULT NULL,
  `INTERFACE_EXTERNAL_INPUT` varchar(255) DEFAULT NULL,
  `INTERFACE_EXTERNAL_OUTPUT` varchar(255) DEFAULT NULL,
  `RECEIVES FROM OWNER ORGANIZATION` varchar(255) DEFAULT NULL,
  `RECEIVES FROM OWNER PERSON` varchar(255) DEFAULT NULL,
  `RECEIVES FROM DOMAIN ANALYST` varchar(255) DEFAULT NULL,
  `SENDS TO OWNER ORGANIZATION` varchar(255) DEFAULT NULL,
  `SENDS TO OWNER PERSON` varchar(255) DEFAULT NULL,
  `SENDS TO DOMAIN ANALYST` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID1)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `OVSD_DB_RELS`
--
DROP TABLE IF EXISTS `ovsd_db_rels`;
CREATE TABLE `ovsd_db_rels` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `FROM-CIID` double DEFAULT NULL,
  `FROM-SEARCHCODE` varchar(255) DEFAULT NULL,
  `FROM-STATUS` varchar(255) DEFAULT NULL,
  `FROM ENVIRONMENT` varchar(255) DEFAULT NULL,
  `FROM-SOX-INDICATOR` varchar(255) DEFAULT NULL,
  `FROM-OS NAME` varchar(255) DEFAULT NULL,
  `FROM-OS VER/REL/SP` varchar(255) DEFAULT NULL,
  `RELATION_TYPE` varchar(255) DEFAULT NULL,
  `TO-CIID` double DEFAULT NULL,
  `TO-SEARCHCODE` varchar(255) DEFAULT NULL,
  `TO-STATUS` varchar(255) DEFAULT NULL,
  `TO-ENVIRONMENT` varchar(255) DEFAULT NULL,
  `TO-SOX-INDICATOR` varchar(255) DEFAULT NULL,
  `TO-BACKUP-SERVER` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `OVSD_DB`
--
DROP TABLE IF EXISTS `ovsd_db`;
CREATE TABLE `ovsd_db` (
  `ID1` int(11) NOT NULL AUTO_INCREMENT,
  `ID` int(11) DEFAULT NULL,
  `SEARCHCODE` varchar(255) DEFAULT NULL,
  `NAME` varchar(255) DEFAULT NULL,
  `ALIAS_NAMES_4000_` varchar(1024) DEFAULT NULL,
  `DESCRIPTION_4000_` varchar(1024) DEFAULT NULL,
  `CATEGORY` varchar(255) DEFAULT NULL,
  `STATUS` varchar(255) DEFAULT NULL,
  `ENVIRONMENT` varchar(255) DEFAULT NULL,
  `SOX` varchar(255) DEFAULT NULL,
  `OWNER_ORG_SC` varchar(255) DEFAULT NULL,
  `OWNER_PERSON_SC` varchar(255) DEFAULT NULL,
  `OWNER_PERSON_NAME` varchar(255) DEFAULT NULL,
  `DOMAIN_ANALYST` varchar(255) DEFAULT NULL,
  `ADMIN_WORKGROUP_NAME` varchar(255) DEFAULT NULL,
  `ADMIN_PRI_CONTACT_SC` varchar(255) DEFAULT NULL,
  `ADMIN_PRIMARY_CONTACT_NAME` varchar(255) DEFAULT NULL,
  `ADMIN_SEC_CONTACT_SC` varchar(255) DEFAULT NULL,
  `ADMIN_SECONDARY_CONTACT_NAME` varchar(255) DEFAULT NULL,
  `OUTSOURCED_TO_SC` varchar(255) DEFAULT NULL,
  `NOTES` varchar(255) DEFAULT NULL,
  `MISC_INFO` varchar(255) DEFAULT NULL,
  `REGISTRATION CREATED DATE` datetime DEFAULT NULL,
  `OS_NAME` varchar(255) DEFAULT NULL,
  `OS_VER_REL_SP` varchar(255) DEFAULT NULL,
  `RESOURCE_UNIT` varchar(255) DEFAULT NULL,
  `E_INV_DATE` varchar(255) DEFAULT NULL,
  `E_INV_STATUS` varchar(255) DEFAULT NULL,
  `BILLING_CHANGE_CATEGORY` varchar(255) DEFAULT NULL,
  `BILLING_REQUEST_NUMBER` varchar(255) DEFAULT NULL,
  `LAST_BILLING_CHANGE_DATE` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID1)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `OVSD_APPS_RELS`
--
DROP TABLE IF EXISTS `ovsd_apps_rels`;
CREATE TABLE `ovsd_apps_rels` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `FROM-CIID` double DEFAULT NULL,
  `FROM-SEARCH CODE` varchar(100) DEFAULT NULL,
  `FROM-NAME` varchar(120) DEFAULT NULL,
  `FROM-PARENT CATEGORY` varchar(50) DEFAULT NULL,
  `FROM-CATEGORY` varchar(120) DEFAULT NULL,
  `RELATIONSHIP` varchar(70) DEFAULT NULL,
  `TO-CIID` double DEFAULT NULL,
  `TO-SEARCH CODE` varchar(100) DEFAULT NULL,
  `TO-NAME` varchar(255) DEFAULT NULL,
  `TO-ALIAS NAMES (4000)` varchar(3072) DEFAULT NULL,
  `TO-SERIAL NUMBER` varchar(50) DEFAULT NULL,
  `TO-CAPITAL ASSET TAG` varchar(40) DEFAULT NULL,
  `TO-HOST ID` varchar(80) DEFAULT NULL,
  `TO-DESCRIPTION (4000)` varchar(1024) DEFAULT NULL,
  `TO-PARENT CATEGORY` varchar(50) DEFAULT NULL,
  `TO-CATEGORY` varchar(100) DEFAULT NULL,
  `TO-STATUS` varchar(50) DEFAULT NULL,
  `TO-ENVIRONMENT` varchar(50) DEFAULT NULL,
  `TO-PURPOSE/FUNCTION` varchar(50) DEFAULT NULL,
  `TO-FORMER ALCATEL` varchar(20) DEFAULT NULL,
  `TO-MASTER CMDB` varchar(100) DEFAULT NULL,
  `TO-ASSET TAG` varchar(50) DEFAULT NULL,
  `TO-ASSET CENTER CI RESPONSIBLE` varchar(100) DEFAULT NULL,
  `TO-ASSET CENTER FIXED ASSET NUMBER` varchar(50) DEFAULT NULL,
  `TO-ASSET CENTER OWNER` varchar(100) DEFAULT NULL,
  `TO-ASSET CENTER PO` varchar(100) DEFAULT NULL,
  `TO-ASSET CENTER REFERENCE` varchar(50) DEFAULT NULL,
  `TO-ASSET CENTER SITE` varchar(50) DEFAULT NULL,
  `TO-ROUTE EVENT TO` varchar(20) DEFAULT NULL,
  `TO-MONITORED BY` varchar(100) DEFAULT NULL,
  `TO-SOX` varchar(20) DEFAULT NULL,
  `TO-REMEDIATION COMPLETE` varchar(255) DEFAULT NULL,
  `TO-SOX TIER` varchar(20) DEFAULT NULL,
  `TO-LAST CMDB  AUDIT DATE` datetime DEFAULT NULL,
  `TO-OWNER ORGANIZATION SEARCH CODE` varchar(100) DEFAULT NULL,
  `TO-OWNER PERSON SEARCH CODE` varchar(100) DEFAULT NULL,
  `TO-OWNER PERSON NAME` varchar(100) DEFAULT NULL,
  `TO-DOMAIN ANALYST` varchar(100) DEFAULT NULL,
  `TO-WORKGROUP` varchar(100) DEFAULT NULL,
  `TO-ADMIN PRIMARY CONTACT SEARCH CODE` varchar(100) DEFAULT NULL,
  `TO-ADMIN PRIMARY CONTACT NAME` varchar(100) DEFAULT NULL,
  `TO-ADMIN SECONDARY CONTACT SEARCH CODE` varchar(100) DEFAULT NULL,
  `TO-ADMIN SECONDARY CONTACT NAME` varchar(100) DEFAULT NULL,
  `TO-SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE` varchar(100) DEFAULT NULL,
  `TO-LOCATION DETAILS` varchar(255) DEFAULT NULL,
  `TO-LOCATION` varchar(255) DEFAULT NULL,
  `TO-STREET ADDRESS` varchar(255) DEFAULT NULL,
  `TO-CITY` varchar(100) DEFAULT NULL,
  `TO-STATE/PROVINCE` varchar(100) DEFAULT NULL,
  `TO-ZIP CODE/POSTAL` varchar(50) DEFAULT NULL,
  `TO-COUNTRY` varchar(50) DEFAULT NULL,
  `TO-REGION` varchar(20) DEFAULT NULL,
  `TO-NOTES` varchar(255) DEFAULT NULL,
  `TO-DOC REFERENCE URL` varchar(100) DEFAULT NULL,
  `TO-BRAND` varchar(50) DEFAULT NULL,
  `TO-MODEL` varchar(100) DEFAULT NULL,
  `TO-LEASED` varchar(20) DEFAULT NULL,
  `TO-IP ADDRESS` varchar(100) DEFAULT NULL,
  `TO-SECONDARY/VIRTUAL IP ADDRESS (4000)` varchar(1024) DEFAULT NULL,
  `TO-OS CATEGORY` varchar(50) DEFAULT NULL,
  `TO-OS NAME/VERSION` varchar(255) DEFAULT NULL,
  `TO-MEMORY SIZE` varchar(50) DEFAULT NULL,
  `TO-CPU MODEL AND SPEED` varchar(100) DEFAULT NULL,
  `TO-NO OF CPUs INSTALLED` double DEFAULT NULL,
  `TO-NO OF DISKS X DISK SIZE` varchar(100) DEFAULT NULL,
  `TO-USABLE DISK SPACE` varchar(50) DEFAULT NULL,
  `TO-TAPE DRIVES PORTS` varchar(255) DEFAULT NULL,
  `TO-REMOTE ACCESS` varchar(255) DEFAULT NULL,
  `TO-TIME ZONE` varchar(100) DEFAULT NULL,
  `TO-MAINTENANCE WINDOW` varchar(255) DEFAULT NULL,
  `TO-MISC INFO` varchar(1024) DEFAULT NULL,
  `TO-BACKUP SOFTWARE` varchar(100) DEFAULT NULL,
  `TO-BACKUP STORAGE` varchar(50) DEFAULT NULL,
  `TO-BACKUP RETENTION` varchar(255) DEFAULT NULL,
  `TO-BACKUP MODE` varchar(50) DEFAULT NULL,
  `TO-BACKUP SCHEDULE` varchar(2048) DEFAULT NULL,
  `TO-BACKUP RESTARTABLE` varchar(50) DEFAULT NULL,
  `TO-BACKUP SERVER` varchar(100) DEFAULT NULL,
  `TO-BACKUP MEDIA SERVER` varchar(20) DEFAULT NULL,
  `TO-BACKUP INFORMATION` varchar(1024) DEFAULT NULL,
  `TO-BACKUP RESTORE PROCEDURES` varchar(255) DEFAULT NULL,
  `TO-DISASTER RECOVERY TIER` varchar(50) DEFAULT NULL,
  `TO-MAINTENANCE CONTRACT` varchar(100) DEFAULT NULL,
  `TO-COVERAGE END DATE` datetime DEFAULT NULL,
  `TO-GHD SUPPORT DETAILS` varchar(255) DEFAULT NULL,
  `TO-BOOK CLOSE IMPACTING` varchar(255) DEFAULT NULL,
  `TO-BUSINESS STAKEHOLDER NAME` varchar(100) DEFAULT NULL,
  `TO-BUSINESS STAKEHOLDER ORGANIZATION` varchar(50) DEFAULT NULL,
  `TO-OPS LEAD` varchar(100) DEFAULT NULL,
  `TO-REGISTRATION CREATED DATE` datetime DEFAULT NULL,
  `TO-RESOURCE UNIT` varchar(100) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `OVSD_APPLICATIONS`
--
DROP TABLE IF EXISTS `ovsd_applications`;
CREATE TABLE `ovsd_applications` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `CIID` double DEFAULT NULL,
  `SEARCHCODE` varchar(255) DEFAULT NULL,
  `NAME` varchar(255) DEFAULT NULL,
  `ALIAS NAMES (4000)` varchar(1024) DEFAULT NULL,
  `DESCRIPTION 4000` varchar(2048) DEFAULT NULL,
  `PARENT CATEGORY` varchar(255) DEFAULT NULL,
  `CATEGORY` varchar(255) DEFAULT NULL,
  `STATUS` varchar(255) DEFAULT NULL,
  `ENVIRONMENT` varchar(255) DEFAULT NULL,
  `FORMER ALCATEL` varchar(255) DEFAULT NULL,
  `MASTER CMDB` varchar(255) DEFAULT NULL,
  `ASSET TAG` varchar(255) DEFAULT NULL,
  `ASSET CENTER CI RESPONSIBLE` varchar(255) DEFAULT NULL,
  `SOX` varchar(255) DEFAULT NULL,
  `SOX_TIER` varchar(255) DEFAULT NULL,
  `LAST CMDB AUDIT DATE` datetime DEFAULT NULL,
  `OWNER ORGANIZATION SEARCH CODE` varchar(255) DEFAULT NULL,
  `OWNER ORGANIZATION NAME` varchar(255) DEFAULT NULL,
  `OWNER PERSON SEARCH CODE` varchar(255) DEFAULT NULL,
  `OWNER PERSON NAME` varchar(255) DEFAULT NULL,
  `DOMAIN_ANALYST` varchar(255) DEFAULT NULL,
  `SERVICE PROVIDER/OUTSOURCED TO SEARCH CODE` varchar(255) DEFAULT NULL,
  `LOCATION` varchar(255) DEFAULT NULL,
  `NOTES` varchar(1024) DEFAULT NULL,
  `DOC REF URL` varchar(255) DEFAULT NULL,
  `DECOMMISSION DATE` datetime DEFAULT NULL,
  `DISASTER RECOVERY TIER` varchar(255) DEFAULT NULL,
  `ASSET CENTER FIXED ASSET NUMBER` varchar(255) DEFAULT NULL,
  `ASSET CENTER OWNER` varchar(255) DEFAULT NULL,
  `ASSET CENTER PO` varchar(255) DEFAULT NULL,
  `ASSET CENTER REFERENCE` varchar(255) DEFAULT NULL,
  `ASSET CENTER SITE` varchar(255) DEFAULT NULL,
  `SOLUTIONS PORTFOLIO ID` varchar(255) DEFAULT NULL,
  `SOLUTIONS PORTFOLIO - IAD SOLUTION LEAD` varchar(255) DEFAULT NULL,
  `SOLUTIONS PORTFOLIO - IAD MANAGER` varchar(255) DEFAULT NULL,
  `SOURCING ACCOUNTABLE` varchar(255) DEFAULT NULL,
  `BOOK CLOSE IMPACTING` varchar(255) DEFAULT NULL,
  `BUSINESS STAKEHOLDER NAME` varchar(255) DEFAULT NULL,
  `BUSINESS STAKEHOLDER ORGANIZATION` varchar(255) DEFAULT NULL,
  `OPS LEAD` varchar(255) DEFAULT NULL,
  `REGISTRATION CREATED DATE` datetime DEFAULT NULL,
  `RESOURCE UNIT` varchar(255) DEFAULT NULL,
  `BILLING CHANGE CATEGORY` varchar(255) DEFAULT NULL,
  `BILLING REQUEST NUMBER` varchar(255) DEFAULT NULL,
  `LAST BILLING CHANGE DATE` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


















-- *************************************************************************************************************************** --
-- TABLES FOR ASSETCENTER                                                                                                              --
--   a7_all_relations	  	loaded
--   a7_servers				loaded
--   a7_solutions			loaded
-- *************************************************************************************************************************** --
--
-- Table structure for table `a7_all_relations`
--
DROP TABLE IF EXISTS `a7_all_relations`;
CREATE TABLE `a7_all_relations` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Asset tag (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `*_ Hostname / inst (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `*_ Serial # (*_ Distant CI)` varchar(100) DEFAULT NULL,
  `Country (*_ Distant CI* Location)` varchar(50) DEFAULT NULL,
  `City (*_ Distant CI* Location)` varchar(50) DEFAULT NULL,
  `*_ CI class (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `*_ Status (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `Reason (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `Field9` varchar(50) DEFAULT NULL,
  `*_ ABC: CI destination / RU (*_ Distant CI)` varchar(100) DEFAULT NULL,
  `* Billing: Hosting type (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `* Main solution (*_ Distant CI)` varchar(100) DEFAULT NULL,
  `*_ CI Responsible (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `* Owner (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `Billing Request Number (*_ Distant CI)` varchar(100) DEFAULT NULL,
  `*_ Support code (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `* Contract elements (*_ Distant CI)` varchar(100) DEFAULT NULL,
  `* Logical CI type (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `* Reconc status (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `* Office (*_ Distant CI)` varchar(100) DEFAULT NULL,
  `*_ Brand (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `* Model (*_ Distant CI*_ Product)` varchar(100) DEFAULT NULL,
  `* IP domain (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `IP address (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `* Oper System (*_ Distant CI)` varchar(100) DEFAULT NULL,
  `* Operating System Version (*_ Distant CI)` varchar(150) DEFAULT NULL,
  `* Operating System Level (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `Processeur: Type (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `Processeur: Vitesse (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `* Number of CPUs (*_ Distant CI)` double DEFAULT NULL,
  `Mémoire vive (RAM) (*_ Distant CI)` varchar(50) DEFAULT NULL,
  `Asset tag (*_ Local CI)` varchar(50) DEFAULT NULL,
  `*_ Inventory # (*_ Local CI)` varchar(50) DEFAULT NULL,
  `*_ Serial # (*_ Local CI)` varchar(100) DEFAULT NULL,
  `*_ Brand (*_ Local CI)` varchar(50) DEFAULT NULL,
  `* Model (*_ Local CI*_ Product)` varchar(100) DEFAULT NULL,
  `Full name (*_ Local CI*_ Category)` varchar(50) DEFAULT NULL,
  `*_ Hostname / inst (*_ Local CI)` varchar(50) DEFAULT NULL,
  `*_ Status (*_ Local CI)` varchar(50) DEFAULT NULL,
  `*_ CI class (*_ Local CI)` varchar(50) DEFAULT NULL,
  `*_ Support code (*_ Local CI)` varchar(50) DEFAULT NULL,
  `*_ CI Responsible (*_ Local CI)` varchar(50) DEFAULT NULL,
  `*_ ABC: CI destination / RU (*_ Local CI)` varchar(100) DEFAULT NULL,
  `* Billing: Hosting type (*_ Local CI)` varchar(100) DEFAULT NULL,
  `_ SOX application (*_ Local CI)` varchar(100) DEFAULT NULL,
  `_ IT contact (*_ Local CI)` varchar(100) DEFAULT NULL,
  `_ User (*_ Local CI)` varchar(100) DEFAULT NULL,
  `_ Key users (*_ Local CI)` varchar(100) DEFAULT NULL,
  `*_ Impact direction` varchar(100) DEFAULT NULL,
  `*_ Relation type` varchar(100) DEFAULT NULL,
  `* Master flag (*_ Local CI)` varchar(100) DEFAULT NULL,
  `OVSD ID (*_ Local CI)` varchar(100) DEFAULT NULL,
  `_ OPS product (*_ Local CI)` varchar(100) DEFAULT NULL,
  `_ Additional info` varchar(100) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `a7_servers`
--
DROP TABLE IF EXISTS `a7_servers`;
CREATE TABLE `a7_servers` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Country (* Location)` varchar(50) DEFAULT NULL,
  `City (* Location)` varchar(50) DEFAULT NULL,
  `Prefix (*_ Category)` varchar(50) DEFAULT NULL,
  `*_ CI class` varchar(50) DEFAULT NULL,
  `*_ CI Responsible` varchar(100) DEFAULT NULL,
  `* Fixed asset #` varchar(50) DEFAULT NULL,
  `*_ Inventory #` varchar(100) DEFAULT NULL,
  `*_ Serial #` varchar(100) DEFAULT NULL,
  `* Product ref (*_ Product)` varchar(50) DEFAULT NULL,
  `*_ Brand` varchar(50) DEFAULT NULL,
  `* Model (*_ Product)` varchar(100) DEFAULT NULL,
  `*_ Hostname / inst` varchar(100) DEFAULT NULL,
  `* IP domain` varchar(100) DEFAULT NULL,
  `* IP address` varchar(50) DEFAULT NULL,
  `* Logical CI type` varchar(50) DEFAULT NULL,
  `*_ Status` varchar(50) DEFAULT NULL,
  `Reason` varchar(50) DEFAULT NULL,
  `Full name (* Location)` varchar(100) DEFAULT NULL,
  `* Office` varchar(100) DEFAULT NULL,
  `Billing Change Category` varchar(50) DEFAULT NULL,
  `*_ ABC: CI destination / RU` varchar(150) DEFAULT NULL,
  `* Main solution` varchar(100) DEFAULT NULL,
  `* Billing: Availability level` varchar(50) DEFAULT NULL,
  `* Billing: Hosting type` varchar(50) DEFAULT NULL,
  `Last Billing Change Date` datetime DEFAULT NULL,
  `Billing Request Number` varchar(100) DEFAULT NULL,
  `* Owner` varchar(100) DEFAULT NULL,
  `*_ Support code` varchar(100) DEFAULT NULL,
  `* Contract elements` varchar(100) DEFAULT NULL,
  `* Oper System` varchar(100) DEFAULT NULL,
  `* Operating System Version` varchar(100) DEFAULT NULL,
  `* Operating System Level` varchar(100) DEFAULT NULL,
  `* CPU type` varchar(50) DEFAULT NULL,
  `* CPU speed` double DEFAULT NULL,
  `* Number of CPUs` double DEFAULT NULL,
  `* Memory` double DEFAULT NULL,
  `*_ Disk assigned (GB)` varchar(50) DEFAULT NULL,
  `* Billing: Product Size (*_ Product)` varchar(50) DEFAULT NULL,
  `Name (* Maint contract* Company)` varchar(50) DEFAULT NULL,
  `* Corp ref # (* Maint contract)` varchar(50) DEFAULT NULL,
  `* Reconc status` varchar(50) DEFAULT NULL,
  `Install date` datetime DEFAULT NULL,
  `Expiration` datetime DEFAULT NULL,
  `* Number of drives (tape library)` double DEFAULT NULL,
  `* Drive type(s) (tape library)` varchar(50) DEFAULT NULL,
  `Date of request without billing impact` varchar(50) DEFAULT NULL,
  `* Customer Business Group` varchar(50) DEFAULT NULL,
  `Asset tag` varchar(50) NOT NULL,
  `OVSD ID` varchar(50) DEFAULT NULL,
  `_ IT contact` varchar(100) DEFAULT NULL,
  `* Master flag` varchar(50) DEFAULT NULL,
  `*Region (* Location)` varchar(50) DEFAULT NULL,
  `* CI Ownership` varchar(50) DEFAULT NULL,
  `_ SR/PO #` varchar(50) DEFAULT NULL,
  `E-inventory status` varchar(50) DEFAULT NULL,
  `Scanner version` varchar(50) DEFAULT NULL,
  `E-Inventory date` varchar(50) DEFAULT NULL,
  `*_ Last Change #` varchar(50) DEFAULT NULL,
  `Asset Id` double DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `a7_solutions`
--
DROP TABLE IF EXISTS `a7_solutions`;
CREATE TABLE `a7_solutions` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Country (* Location)` varchar(100) DEFAULT NULL,
  `City (* Location)` varchar(100) DEFAULT NULL,
  `Prefix (*_ Category)` varchar(100) DEFAULT NULL,
  `*_ CI class` varchar(100) DEFAULT NULL,
  `*_ CI Responsible` varchar(100) DEFAULT NULL,
  `*_ Inventory #` varchar(100) DEFAULT NULL,
  `*_ Serial #` varchar(100) DEFAULT NULL,
  `* Product ref (*_ Product)` varchar(100) DEFAULT NULL,
  `*_ Brand` varchar(100) DEFAULT NULL,
  `* Model (*_ Product)` varchar(100) DEFAULT NULL,
  `*_ Hostname / inst` varchar(100) DEFAULT NULL,
  `*_ Status` varchar(100) DEFAULT NULL,
  `Reason` varchar(100) DEFAULT NULL,
  `Full name (* Location)` varchar(100) DEFAULT NULL,
  `Billing Change Category` varchar(100) DEFAULT NULL,
  `*_ ABC: CI destination / RU` varchar(100) DEFAULT NULL,
  `* Main solution` varchar(100) DEFAULT NULL,
  `* Billing: Availability level` varchar(100) DEFAULT NULL,
  `* Billing: Hosting type` varchar(100) DEFAULT NULL,
  `Last Billing Change Date` datetime DEFAULT NULL,
  `Billing Request Number` varchar(100) DEFAULT NULL,
  `*_ Support code` varchar(100) DEFAULT NULL,
  `Install date` datetime DEFAULT NULL,
  `Asset tag` varchar(100) NOT NULL DEFAULT '',
  `OVSD ID` varchar(100) DEFAULT NULL,
  `_ User` varchar(100) DEFAULT NULL,
  `_ IT contact` varchar(100) DEFAULT NULL,
  `* Master flag` varchar(100) DEFAULT NULL,
  `_ SOX application` double DEFAULT NULL,
  `_ Sox_Tier` varchar(100) DEFAULT NULL,
  `Sourcing Accountable` varchar(100) DEFAULT NULL,
  `_ Tier Application Type` varchar(100) DEFAULT NULL,
  `* Oper System` varchar(100) DEFAULT NULL,
  `* Operating System Version` varchar(100) DEFAULT NULL,
  `* CI Ownership` varchar(100) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table structure for table `alu_pf_security`
--
DROP TABLE IF EXISTS `alu_pf_security`;
CREATE TABLE `alu_pf_security` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Application Name` varchar(255) DEFAULT NULL,
  `Portfolio ID` varchar(012) DEFAULT NULL,
  `Security Class` varchar(255) DEFAULT NULL,
  `Security Category` varchar(255) DEFAULT NULL,
  `Data Element Global Rating` varchar(255) DEFAULT NULL,
  `Data Element Personal Classification` varchar(255) DEFAULT NULL,
  `Data Element Personal Rating` varchar(255) DEFAULT NULL,
  `Data Element Customer Classification` varchar(255) DEFAULT NULL,
  `Data Element Customer Rating` varchar(255) DEFAULT NULL,
  `Data Element Finance Classification` varchar(255) DEFAULT NULL,
  `Data Element Finance Rating` varchar(255) DEFAULT NULL,
  `Data Element Product Classification` varchar(255) DEFAULT NULL,
  `Data Element Product Rating` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Table alu_workgroups
--
DROP TABLE IF EXISTS `alu_workgroups`;
CREATE TABLE `alu_workgroups` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Portfolio ID` varchar(012) DEFAULT NULL,
  `Change Management Workgroup` varchar(255) DEFAULT NULL,
  `Primary Incident Resolution Group` varchar(255) DEFAULT NULL,
  `Approver Groups` varchar(255) DEFAULT NULL,
  `Change Coordinator Workgroup` varchar(255) DEFAULT NULL,
  `Change Implementer Workgroup` varchar(255) DEFAULT NULL,
  `Change Supervisor Workgroup` varchar(255) DEFAULT NULL,
  `Config Management Workgroup` varchar(255) DEFAULT NULL,
  PRIMARY KEY (ID),
  UNIQUE KEY `func_key` (`Portfolio ID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
