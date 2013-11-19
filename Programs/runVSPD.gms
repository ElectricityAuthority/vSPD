*=====================================================================================
* Name:                 runvSPD.gms
* Function:             This file is invoked to control the entire operation of vSPD.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://reports.ea.govt.nz/EMIIntro.htm
* Contact:              emi@ea.govt.nz
* Last modified on:     19 November 2013
*=====================================================================================


$call cls
$onecho > con
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*+++++++++++++++++++++ EXECUTING vSPD v1.4 +++++++++++++++++++++++
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
$offecho


* Include paths and settings files
$include vSPDpaths.inc
$include vSPDsettings.inc


* Define external files
Files
  temp     "A temporary, recyclable batch file"
  vSPDcase "The current input case file"    / "vSPDcase.inc" / ; vSPDcase.lw = 0 ; vSPDcase.sw = 0 ;


* Perform integrity checks on operating mode (opMode) and trade period reporting (tradePeriodReports) switches.
* Notes: - Operating mode: 1 --> DW mode; -1 --> Audit mode; all else implies usual vSPD mode.
*        - tradePeriodReports must be 0 or 1 (default = 1) - a value of 1 implies reports by trade period are
*          generated. A value of zero will suppress them. tradePeriodReports must be 1 if opMode is 1 or -1,
*          i.e. data warehouse or audit modes.
if(tradePeriodReports < 0 or tradePeriodReports > 1, tradePeriodReports = 1 ) ;
if( (opMode = -1) or (opMode = 1), tradePeriodReports = 1 ) ;
*Display opMode, tradePeriodReports ;


* Create the set of input GDX file names over which the solve and reporting loops will operate
* This process differs slightly for interface mode.
* a) If not using the Excel interface (interfaceMode <> 1), read input GDX files from fileNameList.inc
$if %interfaceMode%==1 $goto skipReadIncFile
Set i_fileName 'Input GDX file names' /
$include fileNameList.inc
  / ;
$label skipReadIncFile

* b) If using the Excel interface (interfaceMode <> 1), read input GDX files from the named array called i_fileName,
*    which is written to the GDX file names by reading the i_fileName 
$if not %interfaceMode%==1 $goto skipReadExcelFile
* First, write out the GDX call arguments
$onecho > gdxInputFileName.ins
  set = i_fileName rng = i_fileName rdim = 1
$offecho
* Then call the GDX routine and load the list of file names
Set i_fileName(*) 'Input GDX file names' ;
$call 'gdxxrw "%programPath%%vSPDinputFileName%.xls" o=inputFileName.gdx "@gdxInputFileName.ins"'
$gdxin inputFileName.gdx
$load i_fileName
$gdxin
$label skipReadExcelFile


* Call runvSPDsetup to establish the output folders etc for the current job
put_utility temp 'exec' / 'gams runvSPDsetup' ;


*=====================================================================================
* Solve vSPD - loop over the designated input GDX files and solve each one in turn.
*=====================================================================================

Scalar runNum 'Scalar to keep track of the run number' / 1 / ;
loop(i_fileName,

* Create the file that has the name of the input file for the current case being solved
  putclose vSPDcase "$setglobal  vSPDinputData  " i_fileName.tl:0 / "$setglobal  vSPDrunNum     " runNum:0:0 ;

* Solve the model for the current input file
  put_utility temp 'exec' / 'gams runvSPDsolve' ;

* Copy the vSPDsolve.lst file to i_fileName.lst in ..\Programs\lst\
  put_utility temp 'shell' / 'copy vSPDsolve.lst "%programPath%"\lst\', i_fileName.tl:0, '.lst' ;

* Increment the run number before going around loop again
  runNum = runNum + 1 ;

) ;


*=====================================================================================
* Generate reports (solving vSPD is now finished).
*=====================================================================================

* Skip the usual reporting if calculating FTR rentals
$if not %calcFTRrentals%==1 $goto cleanUp

* Call vSPDreportSetup to establish the report files ready to write results into
put_utility temp 'exec' / 'gams runvSPDreportSetup' ;

* Loop over the designated input files and generate vSPD reports
runNum = 1 ;
loop(i_fileName,

* Create file that has the name of the input file for the current case being reported on
  putclose vSPDcase "$setglobal  vSPDinputData  " i_fileName.tl:0 / "$setglobal  vSPDrunNum     " runNum:0:0 ;

* Generate the reports
  put_utility temp 'exec' / 'gams runvSPDreport';

* Remove the temporary output GDX files
  put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0'_systemOutput.gdx"' ;
  put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0'_offerOutput.gdx"' ;
  put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0'_traderOutput.gdx"' ;

* Remove the temporary output GDX files for trading period reports
  if(tradePeriodReports = 1,
    put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0'_summaryOutput_TP.gdx"' ;
    put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0'_islandOutput_TP.gdx"' ;
    put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0'_busOutput_TP.gdx"' ;
    put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0'_branchOutput_TP.gdx"' ;
    put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0'_nodeOutput_TP.gdx"' ;
    put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0'_offerOutput_TP.gdx"' ;
    put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0'_reserveOutput_TP.gdx"' ;
    put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0'_brConstraintOutput_TP.gdx"' ;
    put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0'_MnodeConstraintOutput_TP.gdx"' ;

*   If in audit operating mode, remove the temporary output GDX file associated with audit output
*  (Note that we're inside the tradePeriodReports loop at this point)
    if(opMode = -1,
      put_utility temp 'shell' / 'del "%outputPath%%runName%\runNum'runNum:0'_auditOutput_TP.gdx"' ;
    ) ;

  ) ;

* Increment the run number before going around loop again
  runNum = runNum + 1 ;

) ;


*=====================================================================================
* Clean up
*=====================================================================================
$label cleanUp
execute 'del *.ins' ;
execute 'del inputFileName.gdx' ;
$if not %interfaceMode%==2 execute 'del TPsToSolve.gdx' ;
$if     %interfaceMode%==1 execute 'del overridesFromExcel.gdx' ;
