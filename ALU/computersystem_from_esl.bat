@echo off
@echo ******************************************
@echo ComputerSystem General Information for ALU (cs_techn_gen_from_esl.pl)
perl cs_techn_gen_from_esl.pl
@echo ComputerSystem IP Information (omited cs_techn_ip_from_esl.pl)
rem perl cs_techn_ip_from_esl.pl
@echo ComputerSystem Remote Console Information (omited cs_techn_cons_from_esl.pl)
rem perl cs_techn_cons_from_esl.pl
@echo ComputerSystem Availability Information (cs_availability_from_esl.pl)
perl cs_availability_from_esl.pl
@echo ComputerSystem Administrative Information (cs_admin_from_esl.pl)
perl cs_admin_from_esl.pl
@echo ComputerSystem Functionality Information (cs_function_from_esl.pl)
perl cs_function_from_esl.pl
@echo ComputerSystem Usage Information (cs_usage_from_esl.pl)
perl cs_usage_from_esl.pl
@echo ComputerSytem Relations (cs_rels_from_esl.pl)
perl cs_rels_from_esl.pl
@echo Create ComputerSystem Output (create_computersystem.bat)
call create_computersystem.bat
@echo Create OS Product (create_os_product.bat)
call create_os_product.bat
