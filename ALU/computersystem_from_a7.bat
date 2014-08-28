@echo off
@echo Get Computersystem attributes from A7 (computersystem_from_a7.pl)
perl computersystem_from_a7.pl
@echo Prepare Relations table (a7_all_relations.pl)
perl a7_all_relations.pl
@echo Get SFVG to Farm Relation Information (cs_rels_from_a7_virtual_sfvg_to_farm.pl)
perl cs_rels_from_a7_virtual_SFVG_to_Farm.pl
@echo Get VG to Farm Relation Information (cs_rels_from_a7_virtual_vg_to_farm.pl)
perl cs_rels_from_a7_virtual_VG_to_Farm.pl
@echo Get VG to SFVG Relation Information (cs_rels_from_a7_virtual_vg_to_sfvg.pl)
perl cs_rels_from_a7_virtual_VG_to_SFVG.pl
@echo Get Cluster relations
perl cs_rels_from_a7_Clustering.pl
@echo Get Alias relations
perl  cs_rels_from_a7_Alias.pl
@echo Create ComputerSystem Output (create_computersystem.bat)
call create_computersystem.bat
@echo Create OS Product (create_os_product.bat)
call create_os_product.bat
