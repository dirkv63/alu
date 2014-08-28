@echo off

REM Check that we are running on drive D
IF NOT EXIST d:\NUL GOTO ABORT01

REM Check if the log directory we use exists, if not create it
IF NOT EXIST d:\temp\NUL GOTO PREPTMP 
IF NOT EXIST d:\temp\alucmdb\NUL md d:\temp\alucmdb
IF NOT EXIST d:\temp\log\NUL md d:\temp\log 

REM Start from a clean set of output data
del /Q d:\temp\alucmdb

GOTO EXECUTE

:PREPTMP
md d:\temp
md d:\temp\log
md d:\temp\alucmdb

:EXECUTE
REM Use a team library where all project perl modules are located
set PERL5LIB=D:\svn\artifacts\trunk\analysisdeliverables\sourceprep\Modules;%PERL5LIB%;
set PERL5LIB=C:\svn\artifacts\trunk\analysisdeliverables\sourceprep\Modules;%PERL5LIB%;

@echo ****************************************************
@echo Hardware (hw_all.bat)
@echo ****************************************************
call hw_all.bat
@echo ****************************************************
@echo ComputerSystem (computersystem_all.bat)
@echo ****************************************************
call computersystem_all.bat
@echo ****************************************************
@echo Solution (solutions_all.bat)
@echo ****************************************************
call solutions_all.bat
@echo ****************************************************
@echo Master Data 
@echo ****************************************************
@echo Person Data (create_person.pl)
perl create_person.pl
@echo Create Master Renaming File (create_acronym_renaming.pl)
perl create_acronym_renaming.pl
@echo ****************************************************
@echo Verify Number of Lines (verify_line_count.pl)
@echo ****************************************************
perl verify_line_count.pl
@echo ****************************************************
@echo Get rid of timestamp in filename (rename_files.pl)
@echo ****************************************************
perl rename_files.pl
@echo ****************************************************
@echo Now Copy ESL Product Component Files to each ESL Sub business (copy_esl_product.bat)
@echo ****************************************************
call copy_esl_product.bat
GOTO END

:ABORT01
@echo ****************************************************
@echo WE ARE ONLY RUNNING ON A D-DRIVE (SORRY)
@echo ****************************************************


:END
