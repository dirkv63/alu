@echo off
@echo Portfolio Table Consolidation (pf_handling.pl)
perl pf_handling.pl
@echo Get Portfolio Information (products_from_pf.pl)
perl products_from_pf.pl
@echo Add Security Information to the Portfolio entries (pf_security.pl)
perl pf_security.pl
@echo Generate missing portfolio id's to the application table (pf_generate.pl)
perl pf_generate.pl
