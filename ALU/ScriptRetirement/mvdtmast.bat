@ECHO OFF

IF "%1" == "" GOTO END
IF NOT EXIST D:\svn\artifacts\trunk\integration-test\%1\NUL GOTO END

@ECHO **********************************************************
@ECHO ** MOVE A7-DATA EXTRACTS TO INPUT FOLDER TRANSITION APP **
@ECHO **********************************************************
@ECHO ** PARAMETER %1

copy D:\svn\artifacts\trunk\integration-test\master\*.* D:\svn\artifacts\trunk\integration-test\%1\master

call movecsv.bat D:\temp\alucmdb\master_DataCenter_component.csv D:\svn\artifacts\trunk\integration-test\%1\master
call movecsv.bat D:\temp\alucmdb\master_Person_component.csv D:\svn\artifacts\trunk\integration-test\%1\master
copy "D:\svn\artifacts\trunk\analysisdeliverables\sourceprep\Downloaded Origin Files\Portfolio\Portfolio_Data.xls" D:\svn\artifacts\trunk\integration-test\%1\master

:END