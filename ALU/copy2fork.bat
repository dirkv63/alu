@echo off
set SVNDIR=D:\temp\artifacts\trunk\integration-test
set SOURCE=%SVNDIR%\201201
set TARGET=%SVNDIR%\201201_fork

@echo Copy Component Files only
copy /Y %SOURCE%\*Component* %TARGET%

@echo Copy Component Dependency Files
copy /Y %SOURCE%\*_cd_* %TARGET%

@echo Delete Files from unexpected Sources
del /Q %TARGET%\ESL-AGEO*
del /Q %TARGET%\ESL-Alcanet*
del /Q %TARGET%\ESL-ALU-CMO-*
del /Q %TARGET%\ESL-ALU-Transformation*
