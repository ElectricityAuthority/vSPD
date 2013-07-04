$ontext
===================================================================================
Name: runVSPDSetup.gms
Function: Creates the output directories and cleans up the working directory.
Developed by: Ramu Naidoo  (Electricity Authority, New Zealand)
Last modified: 29 November 2011
===================================================================================
$offtext

$include vSPDsettings.inc
$include vSPDpaths.inc

* Invoke VSPDmodel - only if license type is developer (i.e. mode=1).
$if %Mode%==1    $call gams VSPDModel.gms s=VSPDModel
$if errorlevel 1 $abort +++ Check VSPDModel.lst for errors +++

* Create a couple of files.
File bat "A recyclable batch file"  / "%ProgramPath%temp.bat" / ;        bat.lw = 0 ;
File rep "Write a progess report"   / "runVSPDSetupProgress.txt" / ;     rep.lw = 0 ;

* Create and execute a batch file to:
* - remove any output directory with the extant runName;
* - create a new output directory with the extant runName;

*If DWMode flag is set skip the standard batch file creation otherwise
*If DWMode flag is NOT set skip use the standard batch file creation
$if %DWMode%==0 $goto SkipDWBat
putclose bat
  'if exist report.txt                     erase report.txt /q' /
*  'if exist vSPDcase.inc                   erase vSPDcase.inc /q' /
  'if exist runVSPDSetupProgress.txt       erase runVSPDSetupProgress.txt /q' /
  'if exist runVSPDSolveProgress.txt       erase runVSPDSolveProgress.txt /q' /
  'if exist runVSPDMergeProgress.txt       erase runVSPDMergeProgress.txt /q' /
  'if exist runVSPDReportProgress.txt      erase runVSPDReportProgress.txt /q' /
  'if exist "%OutputPath%%runName%"        rmdir "%OutputPath%%runName%" /s /q' /
  'mkdir "%OutputPath%%runName%"' /
  ;
$label SkipDWBat

$if %DWMode%==1 $goto SkipStdBat
putclose bat
  'if exist report.txt                     erase report.txt /q' /
  'if exist vSPDcase.inc                   erase vSPDcase.inc /q' /
  'if exist runVSPDSetupProgress.txt       erase runVSPDSetupProgress.txt /q' /
  'if exist runVSPDSolveProgress.txt       erase runVSPDSolveProgress.txt /q' /
  'if exist runVSPDMergeProgress.txt       erase runVSPDMergeProgress.txt /q' /
  'if exist runVSPDReportProgress.txt      erase runVSPDReportProgress.txt /q' /
  'if exist "%OutputPath%%runName%"        rmdir "%OutputPath%%runName%" /s /q' /
  'mkdir "%OutputPath%%runName%"' /
  ;
$label SkipStdBat

execute 'temp.bat' ;

* Indicate that runVSPDSetup is finished.
putclose rep "runVSPDSetup has now finished..." / "Time: " system.time / "Date: " system.date ;

