*=====================================================================================
* Name:                 runvSPDsetup.gms
* Function:             Invokes vSPDmodel if required, creates the output directory for
*                       the current run, and cleans up the working directory.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     30 May 2014
*=====================================================================================

* Include paths and settings files
$include vSPDpaths.inc
$include vSPDsettings.inc

* Invoke vSPDmodel if license type is developer (licenseMode=1)
$if %licenseMode%==1 $call gams vSPDmodel.gms s=vSPDmodel
$if errorlevel 1     $abort +++ Check vSPDmodel.lst for errors +++

* Create a recyclable batch file.
File bat "A recyclable batch file" / "%programPath%temp.bat" / ;    bat.lw = 0 ;

* Create and execute a batch file to:
* - remove any output directory with the extant runName;
* - create a new output directory with the extant runName;
putclose bat
  'if exist report.txt                    erase report.txt /q' /
  'if exist vSPDcase.inc                  erase vSPDcase.inc /q' /
  'if exist "%outputPath%\%runName%"      rmdir "%outputPath%\%runName%" /s /q' /
  'if exist "%programPath%\lst"           rmdir "%programPath%\lst" /s /q' /
  'mkdir "%outputPath%\%runName%"' /
  'mkdir "%programPath%\lst"' / ;

execute 'temp.bat' ;


* End of file
