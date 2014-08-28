rem @echo off
@echo Analyze Data in d:\temp\postbb
perl ci_create_ddl.pl -i C:\Temp\ALUCMDB\analysisdeliverables\sourceprep\ALU\properties "C:\Projects\ALU\Tools\CMDB\uCMDB\ALU Specific uCMDB Attribute Specification v1_30 Final.xls" D:\temp\PostBB\CIs.csv D:\temp\PostBB\Relations.csv > d:\temp\postbb\validation.ddl
@echo Load Datamodel into mysql
"C:\Program Files\MySQL\MySQL Server 5.5\bin\mysql.exe" -uroot -pMonitor1 < d:\temp\PostBB\validation.ddl
@echo Load Data into validation database
perl ci_load_data.pl -i C:\Temp\ALUCMDB\analysisdeliverables\sourceprep\ALU\properties D:\temp\PostBB\CIs.csv D:\temp\PostBB\Relations.csv
