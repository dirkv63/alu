@ECHO OFF

ECHO ** PARAMETER : %1 **

IF "%1" == "" ( GOTO ABORT02 )	
IF EXIST D:\svn\artifacts\trunk\integration-test\%1\NUL GOTO ABORT01
IF NOT EXIST D:\temp\NUL GOTO ABORT03

md D:\svn\artifacts\trunk\integration-test\
md D:\svn\artifacts\trunk\integration-test\%1\master

call mvdta7.bat %1
call mvdtesl.bat %1
call mvdtovsd.bat %1
call mvdtmast.bat %1

GOTO END

:ABORT01
ECHO ** D:\svn\artifacts\trunk\integration-test\%1 ALREADY EXISTS !! **
GOTO END

:ABORT02
ECHO ** Please provide a snapshot folder (snapshotyyyymmdd)
GOTO END

:ABORT03
ECHO ** No D:\temp folder found to copy the source data from.
GOTO END

:END