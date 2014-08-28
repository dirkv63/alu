@echo off
@echo Get Solution Locations from A7 (locations_from_a7_sols.pl)
perl locations_from_a7_sols.pl
@echo Get Solution Attributes from A7 (solutions_from_a7.pl)
perl solutions_from_a7.pl
@echo Generate missing portfolio id's to the application table (pf_generate.pl)
perl pf_generate.pl
@echo Get Solution Relations from A7 (a7_solution_relations.pl)
perl a7_solution_relations.pl
@echo Remember Application Instance to Application Relation (remember_source_application.pl -c)
perl remember_source_application.pl -c
@echo Explode TechnicalProductInstances to individual items per computersystem (explode_instances.pl)
perl explode_instances.pl
@echo Remove duplicate instances from Assetcenter (remove_dupl_instances.pl)
perl remove_dupl_instances.pl
@echo Add workgroup information (workgroup_from_appl_instance.pl)
perl workgroup_from_appl_instance.pl
@echo ** create_solutions.bat
call create_solutions.bat
