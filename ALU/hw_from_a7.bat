@echo off
@echo Get Locations from A7 (locations_from_a7.pl)
perl locations_from_a7.pl
@echo Get Hardware from A7 (hw_from_a7.pl)
perl hw_from_a7.pl
rem @echo Find Blade Servers and Blade Enclosures
rem @echo No Blade Server / Blade Enclosure data available in Assetcenter. (omited hw_type_from_a7.pl)
rem perl hw_type_from_a7.pl
@echo Create Hardware Files (create_hw.bat)
call create_hw.bat
