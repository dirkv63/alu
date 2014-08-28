@ECHO OFF

IF "%1" == "" GOTO ABORT01
IF NOT EXIST D:\svn\artifacts\trunk\integration-test\%1\NUL GOTO END

IF NOT EXIST D:\TEMP\NUL GOTO ABORT03

@ECHO **********************************************************
@ECHO ** call movecsv.bat A7-DATA EXTRACTS TO INPUT FOLDER TRANSITION APP **
@ECHO **********************************************************
@ECHO ** PARAMETER %1


call movecsv.bat D:\temp\alucmdb\A7_cd_appComposition.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_appInstComposition.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_appInstDependsUponCS.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_bladeInEnclosure.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_clusterComposition.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_clusterPackageComposition.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_CSBackupForDB.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_dodgyRelationships.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_farmComposition.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_farmManager.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_physicalSrvrOnHardware.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_PrdInstalledOnCS.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_PrdInstalledOnCS_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_PrdInstalledPrd.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_PrdInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_prdInstOfInstalledPrd.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_prdInstOfInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_prdInstRelationships.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_cd_virtualSrvrOnCS.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ComputerSystem_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ComputerSystem_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ComputerSystem_ESL.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ComputerSystem_NoteList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ComputerSystem_RemoteAccessList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ComputerSystem_ServiceFunctionList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ComputerSystem_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ComputerSystem_SystemUsageList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_Hardware_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_Hardware_LocationList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_Hardware_ProcessorList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_InstalledProduct_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_InstalledProduct_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_Product_Component_Application.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_Product_Component_Application_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_Product_Component_TechnicalProduct.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_Product_Component_TechnicalProduct_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ProductInstance_AppInstance.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ProductInstance_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ProductInstance_AssignedContactList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ProductInstance_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ProductInstance_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ProductInstance_DBInstance.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ProductInstance_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ProductInstance_ServiceLevelList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\A7_ProductInstance_WebInstance.csv D:\svn\artifacts\trunk\integration-test\%1
GOTO END

:ABORT01
ECHO ** PLEASE PROVIDE A DESTINATION FOLDER **
GOTO END

:ABORT02
ECHO ** DESTINATION FOLDER %1 DOES NOT EXISTS **
GOTO END

:ABORT03
ECHO ** D:\TEMP SOURCE FOLDER DOES NOT EXISTS
GOTO END

:END