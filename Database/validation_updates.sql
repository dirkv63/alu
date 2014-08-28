USE validation;

-- ALTER TABLE validation.ci ADD PRIMARY KEY (cmdb_id);
-- commit;

CREATE INDEX ci_idx01 ON validation.ci (data_externalid);
CREATE INDEX ci_idx02 on validation.ci (ci_type);

commit;
select "indexes for validation.ci created.";

CREATE INDEX relations_idx01 ON validation.relations (source_cmdbid);
CREATE INDEX relations_idx02 ON validation.relations (source_ciexternalid);

commit;
select "indexes for validation.relations created.";

ALTER TABLE validation.relations ADD FOREIGN KEY (source_cmdbid) REFERENCES CI(cmdb_id);
ALTER TABLE validation.relations ADD FOREIGN KEY (source_ciexternalid) REFERENCES CI(data_externalid);

commit;
select "foreign keys for validation.relations created.";
