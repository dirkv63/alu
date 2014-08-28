@echo off
@echo Move suspect files to In Splitter Directory (file_mover.pl -f)
perl file_mover.pl -f
@echo Split the files (runfilesplitter.bat)
call runFileSplitter.bat
@echo and move the files back (file_mover.pl)
perl file_mover.pl
