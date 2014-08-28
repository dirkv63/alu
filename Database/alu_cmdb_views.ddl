use alu_cmdb;

create or replace view esl_cs_admin_slo as
select *
from esl_cs_admin
WHERE  `System Group Type` =  "slo";

create or replace view esl_cs_admin_billing_group as
select *
from esl_cs_admin
WHERE  `System Group Type` =  "billing group";

create or replace view esl_cs_admin_application as
select *
from esl_cs_admin
WHERE  `System Group Type` =  "application";