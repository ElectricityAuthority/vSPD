*=====================================================================================
* Name:                 runvSPD.gms
* Function:             This file is invoked to control the entire operation of vSPD.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       https://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: https://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Last modified on:     1 Oct 2019
*=====================================================================================


$call cls
$onecho > con
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*+++++++++++++++++++++ EXECUTING vSPD ++++++++++++++++++++++++++++
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
$offecho


*=====================================================================================
*Include paths and settings files
*=====================================================================================
$include vSPDsettings.inc


*=====================================================================================
* Create a progress report file
*=====================================================================================
File rep "Write a progess report" /"ProgressReport.txt"/ ;  rep.lw = 0 ;
putclose rep "Run: '%runName%'" //
             "runvSPD started at: " system.date " " system.time;


*=====================================================================================
* Define external files
*=====================================================================================
Files
temp       "A temporary, recyclable batch file"
vSPDcase   "The current input case file"      / "vSPDcase.inc" /;
vSPDcase.lw = 0 ;   vSPDcase.sw = 0 ;


*=====================================================================================
* Install the set of input GDX file names over which the solve and reporting loops will operate
*=====================================================================================
$Onempty
Set i_fileName(*) 'Input GDX file names'
$include vSPDfileList.inc
;
$Offempty

*=====================================================================================
* Compiling vSPDModel if required
* Establish the output folders for the current job
* Copy program codes for repeatability and reproducibility
*=====================================================================================
rep.ap = 1 ;
putclose rep "vSPDsetup started at: " system.date " " system.time ;

* Invoke vSPDmodel if license type is developer (licenseMode=1)
$if %licenseMode%==1 $call gams vSPDmodel.gms s=vSPDmodel
$if errorlevel 1     $abort +++ Check vSPDmodel.lst for errors +++

execute 'if exist "%outputPath%%runName%" rmdir "%outputPath%%runName%" /s /q';
execute 'if exist "%programPath%lst"  rmdir "%programPath%lst" /s /q';
execute 'mkdir "%programPath%lst"';
execute 'mkdir "%outputPath%%runName%\Programs"';
execute 'copy /y vSPD*.inc "%outputPath%%runName%\Programs"'
execute 'copy /y *.gms "%outputPath%%runName%\Programs"'
execute 'copy /y cplex.opt "%outputPath%%runName%\Programs"'

$ifthen exist "%ovrdPath%%vSPDinputOvrdData%.gdx"
  execute 'mkdir  "%outputPath%%runName%\Override"'
  execute 'copy /y "%ovrdPath%%vSPDinputOvrdData%.gdx" "%outputPath%%runName%\Override"'
$endif

$iftheni %opMode%=='PVT'
  execute 'mkdir  "%outputPath%%runName%\Programs\Pivot"'
  execute 'copy /y "Pivot\*.*" "%outputPath%%runName%\Programs\Pivot"'
$elseifi %opMode%=='DPS' execute 'gams Demand\DPSreportSetup.gms'
  execute 'mkdir  "%outputPath%%runName%\Programs\Demand"'
  execute 'copy /y "Demand\*.*" "%outputPath%%runName%\Programs\Demand"'
$elseifi %opMode%=='FTR' execute 'gams FTRental\FTRreportSetup.gms'
  execute 'copy /y FTR*.inc "%outputPath%%runName%\Programs"'
  execute 'mkdir  "%outputPath%%runName%\Programs\FTRental"'
  execute 'copy /y "FTRental\*.*" "%outputPath%%runName%\Programs\FTRental"'
$elseifi %opMode%=='DWH' execute 'gams DWmode\DWHreportSetup.gms'
  execute 'mkdir  "%outputPath%%runName%\Programs\DWMode"'
  execute 'copy /y "DWmode\*.*" "%outputPath%%runName%\Programs\DWMode"'
$else
$endif


*=====================================================================================
* Initialize reports
*=====================================================================================
* Call vSPDreportSetup to establish the report files ready to write results into
$iftheni %opMode%=='PVT' execute 'gams Pivot\PivotReportSetup.gms'
$elseifi %opMode%=='DPS' execute 'gams Demand\DPSreportSetup.gms'
$elseifi %opMode%=='FTR' execute 'gams FTRental\FTRreportSetup.gms'
$elseifi %opMode%=='DWH' execute 'gams DWmode\DWHreportSetup.gms'
$else                    execute 'gams vSPDreportSetup.gms'
$endif


*=====================================================================================
* Solve vSPD and report - loop over the designated input GDX files and solve each one in turn.
*=====================================================================================
loop(i_fileName,

*  Create the file that has the name of the input file for the current case being solved
   putclose vSPDcase "$setglobal  GDXname  " i_fileName.tl:0 ;

*  Create a gdx file contains periods to be solved
   put_utility temp 'exec' / 'gams vSPDperiod' ;

*  Solve the model for the current input file
   put_utility temp 'exec' / 'gams vSPDsolve.gms r=vSPDmodel lo=3 ide=1 Errmsg = 1 holdFixed = 0' ;

*  Copy the vSPDsolve.lst file to i_fileName.lst in ..\Programs\lst\
   put_utility temp 'shell' / 'copy vSPDsolve.lst "%programPath%"\lst\', i_fileName.tl:0, '.lst' ;

) ;
rep.ap = 1 ;
putclose rep / "Total execute time: " timeExec "(secs)" /;


*=====================================================================================
* Clean up
*=====================================================================================
$label cleanUp
execute 'erase "vSPDcase.inc"' ;
$ifthen %opMode%=='DWH'
execute 'move /y ProgressReport.txt "%outputPath%%runName%\%runName%_RunLog.txt"';
$else
execute 'move /y ProgressReport.txt "%outputPath%%runName%"';
$endif
*execute 'if exist *.lst   erase /q *.lst '
execute 'if exist *.~gm   erase /q *.~gm '
execute 'if exist *.lxi   erase /q *.lxi '
execute 'if exist *.log   erase /q *.log '
execute 'if exist *.put   erase /q *.put '
execute 'if exist *.txt   erase /q *.txt '
execute 'if exist *.gdx   erase /q *.gdx '
execute 'if exist temp.*  erase /q temp.*'



