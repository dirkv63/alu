charset utf8;
use cim;

-- ====================================================================================================================================
-- == ALU_SNAPSHOT : Data timestamp & Last run timestamp                                                                             ==
-- ====================================================================================================================================
INSERT INTO `alu_snapshot`
	set snapshot_data_timestamp = (select max(snapshot_data_timestamp) from alu_cmdb.alu_snapshot);

update `alu_snapshot`
	set snapshot_lastrun_timestamp= (select current_timestamp);
