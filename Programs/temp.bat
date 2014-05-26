if exist report.txt                    erase report.txt /q
if exist vSPDcase.inc                  erase vSPDcase.inc /q
if exist runvSPDsetupProgress.txt      erase runvSPDsetupProgress.txt /q
if exist runvSPDsolveProgress.txt      erase runvSPDsolveProgress.txt /q
if exist runvSPDmergeProgress.txt      erase runvSPDmergeProgress.txt /q
if exist runvSPDreportProgress.txt     erase runvSPDreportProgress.txt /q
if exist "C:\TUONG_NGUYEN\vSPD\vSPD_Versions\Programs_v1.4.2_Scarcity_unpublished\..\Output\\TestScarc_alone"      rmdir "C:\TUONG_NGUYEN\vSPD\vSPD_Versions\Programs_v1.4.2_Scarcity_unpublished\..\Output\\TestScarc_alone" /s /q
if exist "C:\TUONG_NGUYEN\vSPD\vSPD_Versions\Programs_v1.4.2_Scarcity_unpublished\\lst"           rmdir "C:\TUONG_NGUYEN\vSPD\vSPD_Versions\Programs_v1.4.2_Scarcity_unpublished\\lst" /s /q
mkdir "C:\TUONG_NGUYEN\vSPD\vSPD_Versions\Programs_v1.4.2_Scarcity_unpublished\..\Output\\TestScarc_alone"
mkdir "C:\TUONG_NGUYEN\vSPD\vSPD_Versions\Programs_v1.4.2_Scarcity_unpublished\\lst"
