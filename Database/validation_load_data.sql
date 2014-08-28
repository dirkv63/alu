use validation;
charset utf8 

LOAD DATA INFILE 'd:ci.csv'
INTO TABLE CI
character set utf8
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';

show warnings;
select "load ci.csv completed";

LOAD DATA INFILE 'd:relations.csv'
INTO TABLE RELATIONS
character set utf8
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';

show warnings;
select "load relations.csv completed";

-- Alle definities voor de ci-type opladen.
LOAD DATA INFILE 'd:citypdef.csv'
INTO TABLE CITYPDEF
character set utf8
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';

show warnings;
select "load citypdef.csv completed";