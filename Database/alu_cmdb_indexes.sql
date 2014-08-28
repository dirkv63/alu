USE `alu_cmdb`;

charset utf8;

call create_index_a7_servers();
call create_index_a7_all_relations();
call create_index_esl_hardware_extract();
call create_index_esl_cs_availability();
call create_index_ovsd_server_rels();
call create_index_ovsd_servers();
