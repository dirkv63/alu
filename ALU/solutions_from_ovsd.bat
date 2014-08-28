@echo off
@echo Get Solution Attributes from OVSD (solutions_from_ovsd.pl)
perl solutions_from_ovsd.pl
@echo Generate missing portfolio id's to the application table (pf_generate.pl)
perl pf_generate.pl
@echo Get Application Solution Interfaces (interface_from_ovsd.pl)
perl interface_from_ovsd.pl
@echo Get DB Solution Attributes from OVSD (db_solutions_from_ovsd.pl)
perl db_solutions_from_ovsd.pl
@echo Get webMethods Adapter Objects from OVSD (sw_wma_from_ovsd.pl)
perl sw_wma_from_ovsd.pl
@echo Generate missing portfolio id's to the application table (pf_generate.pl)
perl pf_generate.pl
@echo Copy application_instance to ovsd_application_instance (copy_app_inst.pl)
perl copy_app_inst.pl
@echo Get OVSD Solution - Relations from OVSD (ovsd_solution_relations.pl)
perl ovsd_solution_relations.pl
@echo Remember Application Instance to Application Relation (remember_source_application.pl)
perl remember_source_application.pl
@echo Explode TechnicalProductInstances to individual items per computersystem (explode_instances.pl)
perl explode_instances.pl
@echo Add workgroup information (workgroup_from_appl_instance.pl)
perl workgroup_from_appl_instance.pl
@echo Remember Exploded Application Instances for removing duplicates from A7 (copy_expl_app_inst.pl)
perl copy_expl_app_inst.pl
@echo Create Application Interfaces File (create_application_rels.pl)
perl create_interface_rels.pl
@echo (create_solutions.bat)
call create_solutions.bat
