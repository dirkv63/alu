@echo off
@echo Get Locations from ESL (locations_from_esl.pl)
perl locations_from_esl.pl
@echo and Location Data (create_locations.pl)
perl create_locations.pl
@echo Get Hardware from ESL for CMO (hw_from_esl.pl)
perl hw_from_esl.pl
@echo Find Blade Servers and Blade Enclosures (hw_type_from_esl.pl)
perl hw_type_from_esl.pl
@echo Create Hardware Files (create_hw.bat)
call create_hw.bat
