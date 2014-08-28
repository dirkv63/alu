rem @echo off
SET SCRIPTDIR=C:\Projects\ALU\Projects\FMO Data Load\SVN\sourceprep
SET EXTRACTDIR=C:\Temp\alu_reports
@echo Analyze Data in d:\temp\postbb
perl ci_create_ddl.pl -i "%SCRIPTDIR%\ALU\properties" "C:\Projects\ALU\Tools\CMDB\uCMDB\ALU Specific uCMDB Attribute Specification v1_30 Final.xls" %EXTRACTDIR%\CIs.csv %EXTRACTDIR%\Relations.csv > %EXTRACTDIR%\validation.ddl
@echo Load Datamodel into mysql
"C:\Program Files\MySQL\MySQL Server 5.5\bin\mysql.exe" -uroot -pMonitor1 < %EXTRACTDIR%\validation.ddl
@echo Load Data into validation database
perl ci_load_data.pl -i "%SCRIPTDIR%\ALU\properties" %EXTRACTDIR%\CIs.csv %EXTRACTDIR%\Relations.csv
