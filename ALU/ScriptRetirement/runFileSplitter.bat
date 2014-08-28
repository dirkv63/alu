@echo off
rem set HOMEDIR=C:\Users\simpsonk\KSS\projects\ALU\DataAnalysis\testing\dataDeliveryFileSplitter
set HOMEDIR=D:\temp\FileRewriter
set INPUTDIR=%HOMEDIR%\inputDir
set OUTPUTDIR=%HOMEDIR%\outputDir

REM TEST IF OUTPUTDIR EXISTS (FAILSAFE)
IF EXIST %OUTPUTDIR%\NUL GOTO LABEL01
MD %OUTPUTDIR%

:LABEL01
REM Clean up output dir before starting
pushd %OUTPUTDIR%
rem del * -v
del /Q * 
popd

java SubBusinessFileRewriter %INPUTDIR% %OUTPUTDIR%

REM TEST IF INPUTDIR EXISTS (FAILSAFE)
IF EXIST %INPUTDIR%\NUL GOTO LABEL02
MD %INPUTDIR%

:LABEL02
echo *********
echo java popd
echo ********* 
rem What about clearing input dir now for the next run
pushd %INPUTDIR%
del /Q *
popd

rem pause
