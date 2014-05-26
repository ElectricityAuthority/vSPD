*=====================================================================================
* Name:                 runvSPD.gms
* Function:             This file is invoked to control the entire operation of vSPD.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://reports.ea.govt.nz/EMIIntro.htm
* Contact:              emi@ea.govt.nz
* Last modified on:     6 December 2013
*=====================================================================================


$call cls
$onecho > con
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*+++++++++++++++++++++ EXECUTING vSPD v1.4 +++++++++++++++++++++++
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
$offecho

$if not exist vSPDpaths.inc  $call "copy IncFiles\*.inc"
* Include paths and settings files
$include vSPDpaths.inc
$include vSPDsettings.inc


* Define external files
Files
  temp       "A temporary, recyclable batch file"
  vSPDcase   "The current input case file"      / "vSPDcase.inc" /
  FTRrun     "Current FTR run type"             / "FTRrun.inc" /
  FTRdirect  "Current FTR direction"            / "FTRdirect.inc" / ;

  vSPDcase.lw = 0 ;   vSPDcase.sw = 0 ;
  FTRrun.lw = 0 ;     FTRrun.sw = 0 ;
  FTRdirect.lw = 0 ;  FTRdirect.sw = 0 ;


*=====================================================================================
* Perform integrity checks on operating modeand trade period reporting switches.
*=====================================================================================
* Notes: - Operating mode: 1 --> DW mode; -1 --> Audit mode; all else implies usual vSPD mode.
*        - tradePeriodReports must be 0 or 1 (default = 1) - a value of 1 implies reports by trade
*          period are generated. A value of zero will suppress them. tradePeriodReports must be 1
*          if opMode is 1 or -1, i.e. data warehouse or audit modes.
if(tradePeriodReports < 0 or tradePeriodReports > 1, tradePeriodReports = 1 ) ;
$if %calcFTRrentals%==1 opMode = 0
if( (opMode = -1) or (opMode = 1), tradePeriodReports = 1 ) ;
*Display opMode, tradePeriodReports ;



*=====================================================================================
* Install the set of input GDX file names over which the solve and reporting loops will operate
*=====================================================================================
Set i_fileName 'Input GDX file names'
$include vSPDfileList.inc
  ;



*=====================================================================================
* FTR rental data preparation
*=====================================================================================

* Set FTR flag to zero for normal vSPD run
Scalar FTRflag  / 0 / ;
putclose FTRrun "Scalar FTRflag  / 0 / ;"

$if not %calcFTRrentals%==1 $goto SkipFTRinput

* Declare and install FTR rental sets and data
Sets
  FTRdirection  'FTR flow pattern'
$ include FTRPattern.inc
  ;

Alias (FTRdirection,ftr) ;

Table
  FTRinjection(FTRdirection,*) 'Maximum injections'
$ include FTRinjection.inc
  ;

execute_unload '%programPath%FTRinput', FTRdirection, FTRinjection ;

* Set FTR flag to 1 for FTR normal run
FTRflag = 1;
putclose FTRrun "Scalar FTRflag  /1/;";

$label SkipFTRinput



*=====================================================================================
* Solve vSPD - loop over the designated input GDX files and solve each one in turn.
*=====================================================================================

* Call runvSPDsetup to establish the output folders etc for the current job
put_utility temp 'exec' / 'gams runvSPDsetup' ;

Scalar runNum 'Scalar to keep track of the run number' / 1 / ;
loop(i_fileName,

* Create the file that has the name of the input file for the current case being solved
  putclose vSPDcase "$setglobal  vSPDinputData  " i_fileName.tl:0 / "$setglobal  vSPDrunNum     " runNum:0:0 ;

* Solve the model for the current input file
  put_utility temp 'exec' / 'gams runvSPDsolve' ;

* Copy the vSPDsolve.lst file to i_fileName.lst in ..\Programs\lst\
  put_utility temp 'shell' / 'copy vSPDsolve.lst "%programPath%"\lst\', i_fileName.tl:0, '.lst' ;

$if not %calcFTRrentals%==1 $goto SkipFTRruns

  loop(ftr,

*   Set FTRflag to 2 for FTR flow run and set current i_FRdirection
    putclose FTRrun  'scalar FTRflag  /2/;' /
                     '$setglobal  FTRorder     ' ord(ftr):0:0 ;
    putclose FTRdirect '/' ftr.tl:0 '/' ;

*   Solve the model for the current FTR direction
    put_utility temp 'exec' / 'gams runvSPDsolve' ;

*   Copy the vSPDsolve.lst file to i_fileName.lst in ..\Programs\lst\
    put_utility temp 'shell' / 'copy vSPDsolve.lst "%programPath%"lst\', i_fileName.tl:0, '_', ftr.tl:0, '.lst' ;

*   Combine all FTR output into one file
    put_utility temp 'exec' / 'gams FTRdataCombination errmsg=1' ;

  ) ;

*   Setting FTR flag back to 1 for FTR normal run
    putclose FTRrun "Scalar FTRflag  /1/;";

$label SkipFTRruns

* Increment the run number before going around loop again
  runNum = runNum + 1 ;

) ;


*=====================================================================================
* Generate reports (solving vSPD is now finished).
*=====================================================================================

if( (FTRflag = 0),
* Do the usual vSPD reporting

* Call vSPDreportSetup to establish the report files ready to write results into
  put_utility temp 'exec' / 'gams runvSPDreportSetup' ;

* Loop over the designated input files and generate vSPD reports
  runNum = 1 ;
  loop(i_fileName,

*     Create file that has the name of the input file for the current case being reported on
      putclose vSPDcase "$setglobal  vSPDinputData  " i_fileName.tl:0 / "$setglobal  vSPDrunNum     " runNum:0:0 ;

*     Generate the reports
      put_utility temp 'exec' / 'gams runvSPDreport';

*     Remove the temporary output GDX files
      put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0:0'_*.gdx"' ;

*     Increment the run number before going around loop again
      runNum = runNum + 1 ;

  ) ;

elseif (FTRflag = 1),
* Do the FTR calculations and reporting in the case where FTR rents are being calculated

* Call setup file
  put_utility temp 'exec' / 'gams FTRreportSetup errmsg=1';

* Reset the run num
  runNum = 1;

* Loop over all the specified files and run the model
  loop(i_FileName,

*   Create file that has the current case input file being solved
    putclose vSPDcase "$setglobal  VSPDInputData  " i_Filename.tl:0 / "$setglobal  VSPDRunNum  " runNum:0:0;

*   Run the model
    put_utility temp 'exec' / 'gams FTRrentalCalculation errmsg=1';

*   Remove the temporary output GDX files
    put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0:0'_*.gdx"' ;

*   Increment the run number before going around loop again
    runNum = runNum + 1 ;

  ) ;

* Remove the temporary output GDX files
  put_utility temp 'shell' / 'del "%OutputPath%%runName%\FTRflow.gdx"' ;

) ;



*=====================================================================================
* Clean up
*=====================================================================================
$label cleanUp
*execute 'copy *.inc "%system.fp%"\IncFiles\ /y ';
*execute 'del "*.inc"' ;
execute 'move /y *.inc "%system.fp%"\IncFiles';
execute 'del "*.lst"' ;
execute 'del "*.~gm"' ;
execute 'del "*.lxi"' ;
execute 'del "*.log"' ;
execute 'del "*.put"' ;
execute 'del "*.txt"' ;
execute 'del "*.gdx"' ; 

