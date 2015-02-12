*=====================================================================================
* Name:                 vSPDsetup.gms
* Function:             Invokes vSPDmodel if required, creates the output directory for
*                       the current run, and cleans up the working directory.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     12 January 2015
*=====================================================================================

* Include paths and settings files
$include vSPDpaths.inc
$include vSPDsettings.inc

File rep "Write a progess report" /"ProgressReport.txt"/ ;
rep.lw = 0 ; rep.ap = 1 ;
putclose rep "vSPDsetup started at: " system.date " " system.time ;


* Invoke vSPDmodel if license type is developer (licenseMode=1)
$if %licenseMode%==1 $call gams vSPDmodel.gms s=vSPDmodel
$if errorlevel 1     $abort +++ Check vSPDmodel.lst for errors +++


* Create and execute a batch file to:
* - remove any output directory with the extant runName;
* - create a new output directory with the extant runName;
File bat "A recyclable batch file" / "%programPath%temp.bat" / ;
bat.lw = 0 ;
putclose bat
  'if exist vSPDcase.inc                  erase vSPDcase.inc /q' /
  'if exist "%outputPath%\%runName%"      rmdir "%outputPath%\%runName%" /s /q' /
  'if exist "%programPath%\lst"           rmdir "%programPath%\lst" /s /q' /
  'mkdir "%outputPath%\%runName%"' /
  'mkdir "%programPath%\lst"' / ;
execute 'temp.bat' ;
