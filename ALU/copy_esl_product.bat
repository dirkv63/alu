@echo off
set SOURCE=D:\temp\alucmdb
rem set SOURCE=D:\temp\artifacts\trunk\integration-test\201201
rem set SOURCE=D:\temp\artifacts\trunk\integration-test\201201_308

@echo Copy ESL Technical Product Component Files only
set Component_TP=Product_Component_TechnicalProduct.csv
copy /Y %SOURCE%\ESL_Product_Component_TechnicalProduct.csv "%SOURCE%\ESL-CMO Martinique_Product_Component_TechnicalProduct.csv"
copy /Y %SOURCE%\ESL_Product_Component_TechnicalProduct.csv "%SOURCE%\ESL-ALU-EMEA_Product_Component_TechnicalProduct.csv"
copy /Y %SOURCE%\ESL_Product_Component_TechnicalProduct.csv "%SOURCE%\ESL-ALU-APJ_Product_Component_TechnicalProduct.csv"
copy /Y %SOURCE%\ESL_Product_Component_TechnicalProduct.csv "%SOURCE%\ESL-ALU-AMS_Product_Component_TechnicalProduct.csv"
copy /Y %SOURCE%\ESL_Product_Component_TechnicalProduct_os.csv "%SOURCE%\ESL-CMO Martinique_Product_Component_os.csv"
copy /Y %SOURCE%\ESL_Product_Component_TechnicalProduct_os.csv "%SOURCE%\ESL-ALU-EMEA_Product_Component_os.csv"
copy /Y %SOURCE%\ESL_Product_Component_TechnicalProduct_os.csv "%SOURCE%\ESL-ALU-APJ_Product_Component_os.csv"
copy /Y %SOURCE%\ESL_Product_Component_TechnicalProduct_os.csv "%SOURCE%\ESL-ALU-AMS_Product_Component_os.csv"

@echo Delete Files from unexpected Sources
rem Delete not required, Products must also be in ESL Source
rem but added again, since Technical Products need to be moved but not Applications
del /Q %SOURCE%\ESL_Product_Component_TechnicalProduct.csv
del /Q %SOURCE%\ESL_Product_Component_TechnicalProduct_os.csv
