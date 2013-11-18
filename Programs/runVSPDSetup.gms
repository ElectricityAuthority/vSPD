*=====================================================================================
* Name:                 runvSPDsetup.gms
* Function:             Creates the output directories and cleans up the working directory.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://reports.ea.govt.nz/EMIIntro.htm
* Last modified on:     18 November 2013
*=====================================================================================

* Include paths and settings files
$include vSPDpaths.inc
$include vSPDsettings.inc


* Invoke vSPDmodel if license type is developer (i.e. licenseMode=1)
$if %licenseMode%==1 $call gams vSPDmodel.gms s=vSPDmodel
$if errorlevel 1     $abort +++ Check vSPDmodel.lst for errors +++


* Create a couple of files.
File bat "A recyclable batch file" / "%programPath%temp.bat" / ;    bat.lw = 0 ;
File rep "Write a progess report"  / "runvSPDsetupProgress.txt" / ; rep.lw = 0 ;


* Create and execute a batch file to:
* - remove any output directory with the extant runName;
* - create a new output directory with the extant runName;
putclose bat
  'if exist report.txt                    erase report.txt /q' /
  'if exist vSPDcase.inc                  erase vSPDcase.inc /q' /
  'if exist runvSPDsetupProgress.txt      erase runvSPDsetupProgress.txt /q' /
  'if exist runvSPDsolveProgress.txt      erase runvSPDsolveProgress.txt /q' /
  'if exist runvSPDmergeProgress.txt      erase runvSPDmergeProgress.txt /q' /
  'if exist runvSPDreportProgress.txt     erase runvSPDreportProgress.txt /q' /
  'if exist "%outputPath%\%runName%"      rmdir "%outputPath%\%runName%" /s /q' /
  'if exist "%programPath%\lst"           rmdir "%programPath%\lst" /s /q' /
  'mkdir "%outputPath%\%runName%"' /
  'mkdir "%programPath%\lst"' / ;

execute 'temp.bat' ;


* Indicate that runvSPDsetup is finished.
putclose rep "runvSPDsetup has now finished..." / "Time: " system.time / "Date: " system.date ;
