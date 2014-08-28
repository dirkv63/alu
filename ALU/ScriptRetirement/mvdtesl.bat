@ECHO OFF

IF "%1" == "" GOTO END
IF NOT EXIST D:\svn\artifacts\trunk\integration-test\%1\NUL GOTO END

@ECHO ***********************************************************
@ECHO ** MOVE ESL-DATA EXTRACTS TO INPUT FOLDER TRANSITION APP **
@ECHO ***********************************************************
@ECHO ** PARAMETER %1

@ECHO ** ESL_CD **
call movecsv.bat D:\temp\alucmdb\ESL_cd_appComposition.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_cd_appInstComposition.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_cd_bladeInEnclosure.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_cd_clusterComposition.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_cd_clusterPackageComposition.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_cd_CSBackupForDB.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_cd_dodgyRelationships.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_cd_farmComposition.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_cd_farmManager.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_cd_PrdInstalledOnCS.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_cd_PrdInstalledPrd.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_cd_prdInstOfInstalledPrd.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_cd_prdInstRelationships.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_cd_virtualSrvrOnCS.csv D:\svn\artifacts\trunk\integration-test\%1

@ECHO ** ESL **
call movecsv.bat D:\temp\alucmdb\ESL_Product_Component_Application.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL_Product_Component_Application_os.csv D:\svn\artifacts\trunk\integration-test\%1

@ECHO ** ESL ALU-AMS**
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_cd_appInstDependsUponCS.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_cd_physicalSrvrOnHardware.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_cd_PrdInstalledOnCS_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_cd_PrdInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_cd_prdInstOfInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ComputerSystem_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ComputerSystem_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ComputerSystem_ESL.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ComputerSystem_NoteList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ComputerSystem_RemoteAccessList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ComputerSystem_ServiceFunctionList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ComputerSystem_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ComputerSystem_SystemUsageList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_Hardware_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_Hardware_LocationList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_Hardware_ProcessorList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_InstalledProduct_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_InstalledProduct_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_Product_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_Product_Component_TechnicalProduct.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ProductInstance_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ProductInstance_AssignedContactList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ProductInstance_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ProductInstance_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ProductInstance_DBInstance.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ProductInstance_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ProductInstance_ServiceLevelList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-AMS_ProductInstance_WebInstance.csv D:\svn\artifacts\trunk\integration-test\%1

@ECHO ** ESL ALU-APJ**
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_cd_appInstDependsUponCS.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_cd_physicalSrvrOnHardware.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_cd_PrdInstalledOnCS_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_cd_PrdInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_cd_prdInstOfInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ComputerSystem_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ComputerSystem_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ComputerSystem_ESL.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ComputerSystem_NoteList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ComputerSystem_RemoteAccessList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ComputerSystem_ServiceFunctionList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ComputerSystem_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ComputerSystem_SystemUsageList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_Hardware_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_Hardware_LocationList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_Hardware_ProcessorList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_InstalledProduct_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_InstalledProduct_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_Product_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_Product_Component_TechnicalProduct.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ProductInstance_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ProductInstance_AssignedContactList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ProductInstance_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ProductInstance_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ProductInstance_DBInstance.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ProductInstance_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ProductInstance_ServiceLevelList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-APJ_ProductInstance_WebInstance.csv D:\svn\artifacts\trunk\integration-test\%1

@ECHO ** ESL ALU-EMEA **
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_cd_appInstDependsUponCS.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_cd_physicalSrvrOnHardware.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_cd_PrdInstalledOnCS_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_cd_PrdInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_cd_prdInstOfInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ComputerSystem_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ComputerSystem_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ComputerSystem_ESL.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ComputerSystem_NoteList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ComputerSystem_RemoteAccessList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ComputerSystem_ServiceFunctionList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ComputerSystem_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ComputerSystem_SystemUsageList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_Hardware_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_Hardware_LocationList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_Hardware_ProcessorList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_InstalledProduct_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_InstalledProduct_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_Product_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_Product_Component_TechnicalProduct.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ProductInstance_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ProductInstance_AssignedContactList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ProductInstance_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ProductInstance_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ProductInstance_DBInstance.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ProductInstance_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ProductInstance_ServiceLevelList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-EMEA_ProductInstance_WebInstance.csv D:\svn\artifacts\trunk\integration-test\%1

@ECHO ** ESL CMO-MARTINIQUE **
move "D:\temp\alucmdb\ESL-CMO Martinique_cd_appInstDependsUponCS.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_cd_physicalSrvrOnHardware.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_cd_PrdInstalledOnCS_os.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_cd_PrdInstalledPrd_os.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_cd_prdInstOfInstalledPrd_os.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ComputerSystem_AssignedContactList.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ComputerSystem_Component.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ComputerSystem_ESL.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ComputerSystem_NoteList.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ComputerSystem_RemoteAccessList.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ComputerSystem_ServiceFunctionList.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ComputerSystem_ServiceLevelList.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ComputerSystem_SystemUsageList.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_Hardware_Component.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_Hardware_LocationList.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_Hardware_ProcessorList.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_InstalledProduct_Component.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_InstalledProduct_Component_os.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_Product_Component_os.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_Product_Component_TechnicalProduct.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ProductInstance_AssignedContactList.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ProductInstance_AssignedContactList_os.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ProductInstance_Component.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ProductInstance_Component_os.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ProductInstance_DBInstance.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ProductInstance_ServiceLevelList.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ProductInstance_ServiceLevelList_os.csv" D:\svn\artifacts\trunk\integration-test\%1
move "D:\temp\alucmdb\ESL-CMO Martinique_ProductInstance_WebInstance.csv" D:\svn\artifacts\trunk\integration-test\%1

GOTO :END

@ECHO ** ESL AGEO**
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_cd_appInstDependsUponCS.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_cd_physicalSrvrOnHardware.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_cd_PrdInstalledOnCS_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_cd_PrdInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_cd_prdInstOfInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ComputerSystem_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ComputerSystem_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ComputerSystem_ESL.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ComputerSystem_NoteList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ComputerSystem_RemoteAccessList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ComputerSystem_ServiceFunctionList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ComputerSystem_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ComputerSystem_SystemUsageList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_Hardware_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_Hardware_LocationList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_Hardware_ProcessorList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_InstalledProduct_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_InstalledProduct_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ProductInstance_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ProductInstance_AssignedContactList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ProductInstance_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ProductInstance_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ProductInstance_DBInstance.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ProductInstance_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ProductInstance_ServiceLevelList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-AGEO_ProductInstance_WebInstance.csv D:\svn\artifacts\trunk\integration-test\%1

@ECHO ** ESL Alcanet-DE-VMS**
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_cd_physicalSrvrOnHardware.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_cd_PrdInstalledOnCS_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_cd_PrdInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_cd_prdInstOfInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_ComputerSystem_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_ComputerSystem_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_ComputerSystem_ESL.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_ComputerSystem_NoteList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_ComputerSystem_RemoteAccessList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_ComputerSystem_ServiceFunctionList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_ComputerSystem_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_ComputerSystem_SystemUsageList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_Hardware_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_Hardware_LocationList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_Hardware_ProcessorList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_InstalledProduct_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_ProductInstance_AssignedContactList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_ProductInstance_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-Alcanet-DE-VMS_ProductInstance_ServiceLevelList_os.csv D:\svn\artifacts\trunk\integration-test\%1

@ECHO ** ESL ALU-CMO-AMS**
call movecsv.bat D:\temp\alucmdb\ESL-ALU-CMO-AMS_Hardware_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-CMO-AMS_Hardware_LocationList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-CMO-AMS_Hardware_ProcessorList.csv D:\svn\artifacts\trunk\integration-test\%1

@ECHO ** ESL ALU-CMO-APJ**
call movecsv.bat D:\temp\alucmdb\ESL-ALU-CMO-APJ_Hardware_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-CMO-APJ_Hardware_LocationList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-CMO-APJ_Hardware_ProcessorList.csv D:\svn\artifacts\trunk\integration-test\%1

@ECHO ** ESL ALU-IPAM **
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_cd_physicalSrvrOnHardware.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_cd_PrdInstalledOnCS_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_cd_PrdInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_cd_prdInstOfInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_ComputerSystem_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_ComputerSystem_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_ComputerSystem_ESL.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_ComputerSystem_NoteList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_ComputerSystem_RemoteAccessList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_ComputerSystem_ServiceFunctionList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_ComputerSystem_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_ComputerSystem_SystemUsageList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_Hardware_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_Hardware_LocationList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_Hardware_ProcessorList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_InstalledProduct_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_ProductInstance_AssignedContactList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_ProductInstance_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-IPAM_ProductInstance_ServiceLevelList_os.csv D:\svn\artifacts\trunk\integration-test\%1

@ECHO ** ESL ALU-SOFTWARE DISTRIBUTION **
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_cd_physicalSrvrOnHardware.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_cd_PrdInstalledOnCS_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_cd_PrdInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_cd_prdInstOfInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_ComputerSystem_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_ComputerSystem_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_ComputerSystem_ESL.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_ComputerSystem_NoteList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_ComputerSystem_RemoteAccessList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_ComputerSystem_ServiceFunctionList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_ComputerSystem_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_ComputerSystem_SystemUsageList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_Hardware_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_Hardware_LocationList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_Hardware_ProcessorList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_InstalledProduct_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_InstalledProduct_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_ProductInstance_AssignedContactList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_ProductInstance_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_ProductInstance_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_ProductInstance_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Software Distribution_ProductInstance_ServiceLevelList_os.csv D:\svn\artifacts\trunk\integration-test\%1

@ECHO ** ESL ALU-TRANSFORMATION **
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_cd_physicalSrvrOnHardware.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_cd_PrdInstalledOnCS_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_cd_PrdInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_cd_prdInstOfInstalledPrd_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_ComputerSystem_AssignedContactList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_ComputerSystem_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_ComputerSystem_ESL.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_ComputerSystem_NoteList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_ComputerSystem_RemoteAccessList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_ComputerSystem_ServiceFunctionList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_ComputerSystem_ServiceLevelList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_ComputerSystem_SystemUsageList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_Hardware_Component.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_Hardware_LocationList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_Hardware_ProcessorList.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_InstalledProduct_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_ProductInstance_AssignedContactList_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_ProductInstance_Component_os.csv D:\svn\artifacts\trunk\integration-test\%1
call movecsv.bat D:\temp\alucmdb\ESL-ALU-Transformation_ProductInstance_ServiceLevelList_os.csv D:\svn\artifacts\trunk\integration-test\%1

:END