@echo off
@echo Reading from tables ovsd_servers and ovsd_server_rels
@echo Get Locations from OVSD (locations_from_ovsd.pl)
perl locations_from_ovsd.pl
@echo Get Hardware from OVSD (hw_from_ovsd.pl)
perl hw_from_ovsd.pl
@echo Find Blade Servers and Blade Enclosures (hw_type_from_ovsd.pl)
perl hw_type_from_ovsd.pl
@echo Create Hardware Files (create_hw.bat)
call create_hw.bat
