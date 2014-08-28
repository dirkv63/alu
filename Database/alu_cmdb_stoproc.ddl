DELIMITER $$

SET character set utf8;
SET names utf8;

-- A7_SERVERS : indexes
DROP procedure IF EXISTS `alu_cmdb`.`create_index_a7_servers`;
CREATE PROCEDURE `alu_cmdb`.`create_index_a7_servers`()
BEGIN

DECLARE TBL01 INT DEFAULT 0;
DECLARE IND_IDX101 INT DEFAULT 0;
DECLARE IND_IDX102 INT DEFAULT 0;
DECLARE IND_IDX103 INT DEFAULT 0;
DECLARE IND_IDX104 INT DEFAULT 0;

SELECT COUNT(*) INTO TBL01
FROM information_schema.tables
where table_name = "a7_servers";

IF (TBL01 > 0) THEN
	SELECT COUNT(*) INTO IND_IDX101
	FROM information_schema.statistics 
	where index_name = "a7_servers_idx01";

	SELECT COUNT(*) INTO IND_IDX102
	FROM information_schema.statistics 
	where index_name = "a7_servers_idx02";

	SELECT COUNT(*) INTO IND_IDX103
	FROM information_schema.statistics 
	where index_name = "a7_servers_idx03";

	SELECT COUNT(*) INTO IND_IDX104
	FROM information_schema.statistics 
	where index_name = "a7_servers_idx04";

	IF (IND_IDX101 > 0) THEN 
		DROP INDEX a7_servers_idx01 ON a7_servers; 
	END IF;

	IF (IND_IDX102 > 0) THEN
		DROP INDEX a7_servers_idx02 ON a7_servers;
	END IF;

	IF (IND_IDX103 > 0) THEN
		DROP INDEX a7_servers_idx03 ON a7_servers;
	END IF;

	IF (IND_IDX104 > 0) THEN
		DROP INDEX a7_servers_idx04 ON a7_servers;
	END IF;

	CREATE INDEX a7_servers_idx01 
	ON a7_servers (	`* Logical CI type` ASC, 
					`*_ Hostname / inst` ASC);

	CREATE INDEX a7_servers_idx02 
	ON a7_servers (`Asset tag` ASC);

	CREATE INDEX a7_servers_idx03 
	ON a7_servers (`*_ Hostname / inst` ASC);
	
	CREATE INDEX a7_servers_idx04
	ON a7_servers (`*_ Status` ASC);
END IF;

END$$

-- A7_ALL_RELATIONS : indexes
DROP procedure IF EXISTS `alu_cmdb`.`create_index_a7_all_relations`;
CREATE PROCEDURE `alu_cmdb`.`create_index_a7_all_relations`()
BEGIN

DECLARE TBL02 INT DEFAULT 0;
DECLARE IND_IDX201 INT DEFAULT 0;
DECLARE IND_IDX202 INT DEFAULT 0;
DECLARE IND_IDX203 INT DEFAULT 0;
DECLARE IND_IDX204 INT DEFAULT 0;
DECLARE IND_IDX205 INT DEFAULT 0;

SELECT COUNT(*) INTO TBL02
FROM information_schema.tables
where table_name = "a7_all_relations";

IF (TBL02 > 0) THEN
	SELECT COUNT(*) INTO IND_IDX201
	FROM information_schema.statistics 
	where index_name = "a7_all_relations_idx01";

	SELECT COUNT(*) INTO IND_IDX202
	FROM information_schema.statistics 
	where index_name = "a7_all_relations_idx02";

	SELECT COUNT(*) INTO IND_IDX203
	FROM information_schema.statistics 
	where index_name = "a7_all_relations_idx03";

	SELECT COUNT(*) INTO IND_IDX204
	FROM information_schema.statistics 
	where index_name = "a7_all_relations_idx04";

	SELECT COUNT(*) INTO IND_IDX205
	FROM information_schema.statistics 
	where index_name = "a7_all_relations_idx05";

	IF (IND_IDX201 > 0) THEN 
		DROP INDEX a7_all_relations_idx01 ON a7_all_relations; 
	END IF;

	IF (IND_IDX202 > 0) THEN 
		DROP INDEX a7_all_relations_idx02 ON a7_all_relations; 
	END IF;

	IF (IND_IDX203 > 0) THEN 
		DROP INDEX a7_all_relations_idx03 ON a7_all_relations; 
	END IF;

	IF (IND_IDX204 > 0) THEN 
		DROP INDEX a7_all_relations_idx04 ON a7_all_relations; 
	END IF;

	IF (IND_IDX205 > 0) THEN 
		DROP INDEX a7_all_relations_idx05 ON a7_all_relations; 
	END IF;

	CREATE INDEX a7_all_relations_idx01 
	ON a7_all_relations (`Reason (*_ Distant CI)` ASC);
	
	CREATE INDEX a7_all_relations_idx02 
	ON a7_all_relations (	`*_ Hostname / inst (*_ Distant CI)` ASC, 
							`*_ Impact direction` ASC, 
							`*_ Relation type` ASC,
							`*_ Hostname / inst (*_ Local CI)` ASC);

	CREATE INDEX a7_all_relations_idx03 
	ON a7_all_relations ( `*_ Hostname / inst (*_ Local CI)` ASC);

	CREATE INDEX a7_all_relations_idx04 
	ON a7_all_relations ( `Asset tag (*_ Local CI)` ASC);

	CREATE INDEX a7_all_relations_idx05 
	ON a7_all_relations ( `Asset tag (*_ Distant CI)` ASC);

END IF;

END$$

-- ESL_HARWARE_EXTRACT : indexes
DROP procedure IF EXISTS `alu_cmdb`.`create_index_esl_hardware_extract`;
CREATE PROCEDURE `alu_cmdb`.`create_index_esl_hardware_extract`()
BEGIN

DECLARE TBL03 INT DEFAULT 0;
DECLARE IND_IDX301 INT DEFAULT 0;
DECLARE IND_IDX302 INT DEFAULT 0;
DECLARE IND_IDX303 INT DEFAULT 0;

SELECT COUNT(*) INTO TBL03
FROM information_schema.tables
where table_name = "esl_hardware_extract";

IF (TBL03 > 0) THEN
	SELECT COUNT(*) INTO IND_IDX301
	FROM information_schema.statistics 
	where index_name = "esl_hardware_extract_idx01";

	SELECT COUNT(*) INTO IND_IDX302
	FROM information_schema.statistics 
	where index_name = "esl_hardware_extract_idx02";
	
	SELECT COUNT(*) INTO IND_IDX303
	FROM information_schema.statistics 
	where index_name = "esl_hardware_extract_idx03";

	IF (IND_IDX301 > 0) THEN 
		DROP INDEX esl_hardware_extract_idx01 ON esl_hardware_extract; 
	END IF;

	IF (IND_IDX302 > 0) THEN 
		DROP INDEX esl_hardware_extract_idx02 ON esl_hardware_extract; 
	END IF;

	IF (IND_IDX303 > 0) THEN 
		DROP INDEX esl_hardware_extract_idx03 ON esl_hardware_extract; 
	END IF;

	CREATE INDEX esl_hardware_extract_idx01 
	ON esl_hardware_extract (`Asset Number` ASC);

	CREATE INDEX esl_hardware_extract_idx02 
	ON esl_hardware_extract (`Full Nodename` ASC,`Asset Type` ASC);

	CREATE INDEX esl_hardware_extract_idx03 
	ON esl_hardware_extract (`Full Nodename` ASC,`Asset Number` ASC,`Asset Type` ASC);
END IF;

END$$

-- ESL_CS_AVAILABILITY : indexes
DROP procedure IF EXISTS `alu_cmdb`.`create_index_esl_cs_availability`;
CREATE PROCEDURE `alu_cmdb`.`create_index_esl_cs_availability`()
BEGIN

DECLARE TBL04 INT DEFAULT 0;
DECLARE IND_IDX401 INT DEFAULT 0;
DECLARE IND_IDX402 INT DEFAULT 0;
DECLARE IND_IDX403 INT DEFAULT 0;
DECLARE IND_IDX404 INT DEFAULT 0;
DECLARE IND_IDX405 INT DEFAULT 0;
DECLARE IND_IDX406 INT DEFAULT 0;
DECLARE IND_IDX407 INT DEFAULT 0;
DECLARE IND_IDX408 INT DEFAULT 0;
DECLARE IND_IDX409 INT DEFAULT 0;
DECLARE IND_IDX410 INT DEFAULT 0;

SELECT COUNT(*) INTO TBL04
FROM information_schema.tables
where table_name = "esl_cs_availability";

IF (TBL04 > 0) THEN
	SELECT COUNT(*) INTO IND_IDX401
	FROM information_schema.statistics 
	where index_name = "esl_cs_availability_idx01";

	SELECT COUNT(*) INTO IND_IDX402
	FROM information_schema.statistics 
	where index_name = "esl_cs_availability_idx02";
	
	SELECT COUNT(*) INTO IND_IDX403
	FROM information_schema.statistics 
	where index_name = "esl_cs_availability_idx03";
	
	SELECT COUNT(*) INTO IND_IDX403
	FROM information_schema.statistics 
	where index_name = "esl_cs_availability_idx03";
	
	SELECT COUNT(*) INTO IND_IDX404
	FROM information_schema.statistics 
	where index_name = "esl_cs_availability_idx04";
	
	SELECT COUNT(*) INTO IND_IDX405
	FROM information_schema.statistics 
	where index_name = "esl_cs_availability_idx05";
	
	SELECT COUNT(*) INTO IND_IDX406
	FROM information_schema.statistics 
	where index_name = "esl_cs_availability_idx06";
	
	SELECT COUNT(*) INTO IND_IDX407
	FROM information_schema.statistics 
	where index_name = "esl_cs_availability_idx07";
	
	SELECT COUNT(*) INTO IND_IDX408
	FROM information_schema.statistics 
	where index_name = "esl_cs_availability_idx08";
	
	SELECT COUNT(*) INTO IND_IDX409
	FROM information_schema.statistics 
	where index_name = "esl_cs_availability_idx09";

	SELECT COUNT(*) INTO IND_IDX410
	FROM information_schema.statistics 
	where index_name = "esl_cs_availability_idx10";

	IF (IND_IDX401 > 0) THEN 
		DROP INDEX esl_cs_availability_idx01 ON esl_cs_availability; 
	END IF;

	IF (IND_IDX402 > 0) THEN 
		DROP INDEX esl_cs_availability_idx02 ON esl_cs_availability; 
	END IF;

	IF (IND_IDX403 > 0) THEN 
		DROP INDEX esl_cs_availability_idx03 ON esl_cs_availability; 
	END IF;

	IF (IND_IDX404 > 0) THEN 
		DROP INDEX esl_cs_availability_idx04 ON esl_cs_availability; 
	END IF;

	IF (IND_IDX405 > 0) THEN 
		DROP INDEX esl_cs_availability_idx05 ON esl_cs_availability; 
	END IF;

	IF (IND_IDX406 > 0) THEN 
		DROP INDEX esl_cs_availability_idx06 ON esl_cs_availability; 
	END IF;

	IF (IND_IDX407 > 0) THEN 
		DROP INDEX esl_cs_availability_idx07 ON esl_cs_availability; 
	END IF;

	IF (IND_IDX408 > 0) THEN 
		DROP INDEX esl_cs_availability_idx08 ON esl_cs_availability; 
	END IF;

	IF (IND_IDX409 > 0) THEN 
		DROP INDEX esl_cs_availability_idx09 ON esl_cs_availability; 
	END IF;

	IF (IND_IDX410 > 0) THEN 
		DROP INDEX esl_cs_availability_idx10 ON esl_cs_availability; 
	END IF;

	create index esl_cs_availability_idx01
	on esl_cs_availability (`Technical Owner` ASC);

	create index esl_cs_availability_idx02
	on esl_cs_availability (`Authorized Reboot Requestor` ASC);
	
	create index esl_cs_availability_idx03
	on esl_cs_availability (`Capacity Management Contact` ASC);
	
	create index esl_cs_availability_idx04
	on esl_cs_availability (`Customer Change Coordinator`);
	
	create index esl_cs_availability_idx05
	on esl_cs_availability (`Downtime Contact`);
	
	create index esl_cs_availability_idx06
	on esl_cs_availability (`Restore Contact`);
	
	create index esl_cs_availability_idx07 
	on esl_cs_availability (`Technical Owner`);
	
	create index esl_cs_availability_idx08 
	on esl_cs_availability (`Technical Owner Backup`);
	
	create index esl_cs_availability_idx09 
	on esl_cs_availability (`Technical Lead`);
	
	create index esl_cs_availability_idx10 
	on esl_cs_availability (`Technical Lead Backup`);

END IF;

END$$


-- OVSD_SERVER_RELS : indexes
DROP procedure IF EXISTS `alu_cmdb`.`create_index_ovsd_server_rels`;
CREATE PROCEDURE `alu_cmdb`.`create_index_ovsd_server_rels`()
BEGIN

DECLARE TBL01 INT DEFAULT 0;
DECLARE IND_IDX501 INT DEFAULT 0;
DECLARE IND_IDX502 INT DEFAULT 0;

SELECT COUNT(*) INTO TBL01
FROM information_schema.tables
where table_name = "ovsd_server_rels";

IF (TBL01 > 0) THEN
	SELECT COUNT(*) INTO IND_IDX501
	FROM information_schema.statistics 
	where index_name = "ovsd_server_rels_idx01";

	SELECT COUNT(*) INTO IND_IDX502
	FROM information_schema.statistics 
	where index_name = "ovsd_server_rels_idx02";
	
	IF (IND_IDX501 > 0) THEN 
		DROP INDEX ovsd_server_rels_idx01 ON ovsd_server_rels; 
	END IF;

	IF (IND_IDX502 > 0) THEN
		DROP INDEX ovsd_server_rels_idx02 ON ovsd_server_rels;
	END IF;

	CREATE INDEX ovsd_server_rels_idx01 
	ON ovsd_server_rels (	`From-Category` ASC, 
							`To-Category` 	ASC);

	CREATE INDEX ovsd_server_rels_idx02 
	ON ovsd_server_rels (	`To-Status` 	ASC
						,	`To-Category`	ASC);

END IF;

END$$

-- OVSD_SERVERS : indexes
DROP procedure IF EXISTS alu_cmdb.create_index_ovsd_servers;
CREATE PROCEDURE alu_cmdb.create_index_ovsd_servers()
BEGIN

DECLARE TBL01 INT DEFAULT 0;
DECLARE IND_IDX01 INT DEFAULT 0;

SELECT COUNT(*) INTO TBL01
FROM information_schema.tables
where table_name = "ovsd_servers";

IF (TBL01 > 0) THEN
	SELECT COUNT(*) INTO IND_IDX01
	FROM information_schema.statistics 
	where index_name = "ovsd_servers_idx01";
	
	IF (IND_IDX01 > 0) THEN 
		DROP INDEX ovsd_servers_idx01 ON ovsd_servers; 
	END IF;

	CREATE INDEX ovsd_servers_idx01 
	ON ovsd_servers (`ASSETTAG` ASC);
END IF;

END$$

-- check table
DROP procedure IF EXISTS `alu_cmdb`.`check_table`;
CREATE PROCEDURE `alu_cmdb`.`check_table`(IN CheckTable VARCHAR(100))
BEGIN

DECLARE RowCount INT DEFAULT 0;

select count(*) INTO RowCount
from information_schema.tables 
where table_name = CheckTable;

IF (RowCount = 1) THEN
	select "ok";
ELSE
	select concat("more than one table ",CheckTAble," in mysql.");
END IF;

END$$
