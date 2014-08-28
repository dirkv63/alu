@echo off
@echo Get Computersystem attributes from OVSD (computersystem_from_ovsd.pl)
perl computersystem_from_ovsd.pl
@echo Get Computersystem Relation Information (cs_rels_from_ovsd_servers.pl)
perl cs_rels_from_ovsd_servers.pl
@echo Create ComputerSystem Output (create_computersystem.bat)
call create_computersystem.bat
@echo Create OS Product (create_os_product.bat)
call create_os_product.bat
