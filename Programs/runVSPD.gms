$ontext
===================================================================================
Name: runVSPD.gms
Function: This controls the whole process in standalone mode
Developed by: Ramu Naidoo (Electricity Authority, New Zealand)
Last modified: 09 October 2012
===================================================================================
$offtext

$call cls
$onecho > con
*****************************************************************
***********************EXECUTING vSPD v1.3***********************
*****************************************************************
$offecho

*==================================
*Definitions and general settings
*==================================

*Include settings file
$include vSPDpaths.inc
$include vSPDsettings.inc

*File definition
Files
temp
vSPDcase "Current input case file being solved" / "vSPDcase.inc" / ; vSPDcase.lw = 0; vSPDcase.sw = 0
;

*Call setup file
put_utility temp 'exec' / 'gams runVSPDSetup';

*Now execute in standalone mode

*Scalar to keep track of the run number
Scalar RunNum  /1/;

SETS
*Input file name
i_FileName(*)       'Filenames'
;

*If in datawarehouse mode skip the xls file read process
$if %DWMode%==1 $goto SkipxlsFileRead

* Import input data from Excel data file via GDX.
* Write arguments for the GDX call to gdxVSPDInputData.ins:
$ONECHO > gdxInputFileName.ins
* Parameters and sets
         set = i_FileName                rng = i_FileName                  rdim = 1
$OFFECHO

* Call the GDX routine and load the input data:
$CALL 'GDXXRW "%ProgramPath%%VSPDInputFileName%.xls" o=InputFileName.gdx "@gdxInputFileName.ins"'
$GDXIN InputFileName.gdx

$LOAD i_FileName
*Close the gdx
$GDXIN

*Loop over all the specified files and run the model
loop(i_FileName,

*Create file that has the current case input file being solved
    putclose vSPDcase "$setglobal       VSPDInputData         " i_Filename.tl:0 / "$setglobal       VSPDRunNum         " RunNum:0;

*Update run number
    RunNum = RunNum + 1;

*Run the model
    put_utility temp 'exec' / 'gams runVSPDSolve';

);
$label SkipxlsFileRead


*TN - If NOT in datawarehouse mode skip the DW solve process
$if not %DWMode%==1 $goto SkipDWSolve

   put_utility temp 'exec' / 'gams runVSPDSolve';

$label SkipDWSolve


*==================================
*Report Results
*==================================

*Setup the report templates
put_utility temp 'exec' / 'gams VSPDReportSetup';

*If in datawarehouse mode skip the normal vSPD report process
$if %DWMode%==1 $goto SkipvSPDReportProcess

*Reset the run num
RunNum = 1;

*Loop over all the specified files and update the reports
loop(i_FileName,

*Create file that has the current input case file being solved
    putclose vSPDcase "$setglobal       VSPDInputData         " i_Filename.tl:0 / "$setglobal       VSPDRunNum         " RunNum:0;
*Report the results
    put_utility temp 'exec' / 'gams runVSPDReport';
*$call gams runVSPDReport.gms

*Remove the temp output files
    put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_SystemOutput.gdx';
    put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_OfferOutput.gdx';
    put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_TraderOutput.gdx';

    if (%TradePeriodReports% = 1,
       put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_SummaryOutput_TP.gdx';
       put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_IslandOutput_TP.gdx';
       put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_BusOutput_TP.gdx';
       put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_BranchOutput_TP.gdx';
       put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_NodeOutput_TP.gdx';
       put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_OfferOutput_TP.gdx';
       put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_ReserveOutput_TP.gdx';
       put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_BrConstraintOutput_TP.gdx';
       put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_MNodeConstraintOutput_TP.gdx';
*TN - Additional output for audit reporting
      if (%DWMode%=-1,
         put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_AuditOutput_TP.gdx';
      );
    );
*TN - Additional output for audit reporting - End


*Update run number
    RunNum = RunNum + 1;
);
$label SkipvSPDReportProcess


*TN - If NOT in datawarehouse mode skip the DW report process
$if not %DWMode%==1 $goto SkipDWReportProcess

put_utility temp 'exec' / 'gams runVSPDReport';

*Remove the temp output files
put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_SystemOutput.gdx';
put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_OfferOutput.gdx';
put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_TraderOutput.gdx';

if (%TradePeriodReports% = 1,
    put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_SummaryOutput_TP.gdx';
    put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_IslandOutput_TP.gdx';
    put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_BusOutput_TP.gdx';
    put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_BranchOutput_TP.gdx';
    put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_NodeOutput_TP.gdx';
    put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_OfferOutput_TP.gdx';
    put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_ReserveOutput_TP.gdx';
    put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_BrConstraintOutput_TP.gdx';
    put_utility temp 'shell' / 'del %OutputPath%%runName%\RunNum'RunNum:0'_MNodeConstraintOutput_TP.gdx';
);

$label SkipDWReportProcess

*==================================
*Cleanup
*==================================
execute 'del *.ins';
execute 'del InputFileName.gdx';

