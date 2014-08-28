@echo off
@echo Prepare Instance Report (esl_instance_handling.pl)
perl esl_instance_handling.pl
@echo Get Product Attributes from ESL (products_from_esl.pl)
perl products_from_esl.pl
@echo Get Instance Attributes from ESL (instances_from_esl.pl)
perl instances_from_esl.pl
@echo Get Business Application ESL Instance Attributes (bus_apps_instances_from_esl.pl)
perl bus_apps_instances_from_esl.pl
@echo Generate missing portfolio id's to the application table (pf_generate.pl)
perl pf_generate.pl
@echo Get Business Application to Server Dependency (bus_apps_srv_from_esl.pl)
perl bus_apps_srv_from_esl.pl
@echo Get ESL Instances per Source (instance_per_source_esl.pl)
perl instance_per_source_esl.pl
@echo Create Solutions for ESL (create_solutions.bat)
call create_solutions.bat
