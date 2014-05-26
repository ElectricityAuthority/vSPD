if exist report.txt                    erase report.txt /q
if exist vSPDcase.inc                  erase vSPDcase.inc /q
if exist runvSPDsetupProgress.txt      erase runvSPDsetupProgress.txt /q
if exist runvSPDsolveProgress.txt      erase runvSPDsolveProgress.txt /q
if exist runvSPDmergeProgress.txt      erase runvSPDmergeProgress.txt /q
if exist runvSPDreportProgress.txt     erase runvSPDreportProgress.txt /q
if exist "C:\TUONG_NGUYEN\vSPD\vSPD_Versions\Programs_v1.4.1_Master\..\Output\\TestMaster"      rmdir "C:\TUONG_NGUYEN\vSPD\vSPD_Versions\Programs_v1.4.1_Master\..\Output\\TestMaster" /s /q
if exist "C:\TUONG_NGUYEN\vSPD\vSPD_Versions\Programs_v1.4.1_Master\\lst"           rmdir "C:\TUONG_NGUYEN\vSPD\vSPD_Versions\Programs_v1.4.1_Master\\lst" /s /q
mkdir "C:\TUONG_NGUYEN\vSPD\vSPD_Versions\Programs_v1.4.1_Master\..\Output\\TestMaster"
mkdir "C:\TUONG_NGUYEN\vSPD\vSPD_Versions\Programs_v1.4.1_Master\\lst"
