if exist report.txt                     erase report.txt /q
if exist runVSPDSetupProgress.txt       erase runVSPDSetupProgress.txt /q
if exist runVSPDSolveProgress.txt       erase runVSPDSolveProgress.txt /q
if exist runVSPDMergeProgress.txt       erase runVSPDMergeProgress.txt /q
if exist runVSPDReportProgress.txt      erase runVSPDReportProgress.txt /q
if exist "C:\vSPD\Test\Programs\..\Output\Test"        rmdir "C:\vSPD\Test\Programs\..\Output\Test" /s /q
mkdir "C:\vSPD\Test\Programs\..\Output\Test"
