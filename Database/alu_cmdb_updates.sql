use `alu_cmdb`; 

INSERT INTO alu_snapshot (SELECT CURRENT_TIMESTAMP);

-- Delete all portfolio id's smaller than 10.000 because these id's aren't allowed
delete from alu_acronym_mapping where `App ID` < 10000;