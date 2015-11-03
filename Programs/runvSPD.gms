*=====================================================================================
* Name:                 runvSPD.gms
* Function:             This file is invoked to control the entire operation of vSPD.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     10 September 2015
*=====================================================================================


$call cls
$onecho > con
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*+++++++++++++++++++++ EXECUTING vSPD v2.0.5 +++++++++++++++++++++
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
$offecho


*=====================================================================================
*Include paths and settings files
*=====================================================================================
$if not exist vSPDsettings.inc  $call "copy IncFiles\*.inc"
$include vSPDsettings.inc
$include vSPDpaths.inc
$setglobal outputfolder "%outputPath%%runName%\"


*=====================================================================================
* Create a progress report file
*=====================================================================================
File rep "Write a progess report" /"ProgressReport.txt"/ ;
rep.lw = 0 ;
putclose rep "Run: '%runName%'" //
             "runvSPD started at: " system.date " " system.time;


*=====================================================================================
* Define external files
*=====================================================================================
Files
temp       "A temporary, recyclable batch file"
vSPDcase   "The current input case file"      / "vSPDcase.inc" /
;
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
* Call vSPDsetup to establish the output folders etc for the current job
*=====================================================================================
put_utility temp 'exec' / 'gams vSPDsetup' ;


*=====================================================================================
* Initialize reports
*=====================================================================================
* Call vSPDreportSetup to establish the report files ready to write results into
put_utility temp 'exec' / 'gams vSPDreportSetup' ;


*=====================================================================================
* Solve vSPD and report - loop over the designated input GDX files and solve each one in turn.
*=====================================================================================
loop(i_fileName,

*  Create the file that has the name of the input file for the current case being solved
   putclose vSPDcase "$setglobal  vSPDinputData  " i_fileName.tl:0 ;

*  Create a gdx file contains periods to be solved
   put_utility temp 'exec' / 'gams vSPDperiod' ;

*  Solve the model for the current input file
   put_utility temp 'exec' / 'gams vSPDsolve.gms r=vSPDmodel lo=3 ide=1' ;

*  Updating the reports
   put_utility temp 'exec' / 'gams vSPDreport';

*  Remove the temporary output GDX files
   put_utility temp 'shell' / 'del "%outputPath%%runName%\*.gdx"' ;

*  Copy the vSPDsolve.lst file to i_fileName.lst in ..\Programs\lst\
   put_utility temp 'shell' / 'copy vSPDsolve.lst "%programPath%"\lst\', i_fileName.tl:0, '.lst' ;

) ;
rep.ap = 1 ;
putclose rep / "Total execute time: " timeExec "(secs)" /;


*=====================================================================================
* Clean up
*=====================================================================================
$label cleanUp
execute 'del "vSPDcase.inc"' ;
$ifthen %opMode%==1
execute 'move /y ProgressReport.txt "%outputPath%%runName%\%runName%_RunLog.txt"';
$else
execute 'move /y ProgressReport.txt "%outputPath%%runName%"';
$endif
execute 'del "*.lst"' ;
execute 'del "*.~gm"' ;
execute 'del "*.lxi"' ;
execute 'del "*.log"' ;
execute 'del "*.put"' ;
execute 'del "*.txt"' ;
execute 'del "*.gdx"' ;
execute 'del "temp.bat"' ;


