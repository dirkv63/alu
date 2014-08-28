USE `cim`;

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

