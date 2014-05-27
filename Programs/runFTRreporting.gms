*=====================================================================================
* Name:                 runFTRreporting.gms
* Function:             This file controls the whole FTR rental process.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://reports.ea.govt.nz/EMIIntro.htm
* Last modified on:     27 May 2014
*=====================================================================================


$call cls
$onecho > con
*****************************************************************
***************** EXECUTING vSPD with FTR rentals v1.0 **********
*****************************************************************
$offecho

*==================================
* Definitions and general settings
*==================================

* Include settings file
$include vSPDpaths.inc
$include vSPDsettings.inc

* File definition
Files
  temp
  vSPDcase "Current input case file being solved" / "vSPDcase.inc" / ; vSPDcase.lw = 0; vSPDcase.sw = 0
  ;

*Scalar to keep track of the run number
Scalar runNum  /1/;

* Input file name
Set i_fileName(*) 'Filenames' ;

* Import input data from Excel data file via GDX.
* Write arguments for the GDX call to gdxVSPDInputData.ins:
$onecho > gdxInputFileName.ins
* Parameters and sets
         set = i_FileName                rng = i_FileName                  rdim = 1
$offecho

* Call the GDX routine and load the input data:
$CALL 'GDXXRW "%ProgramPath%%VSPDInputFileName%.xls" o=InputFileName.gdx "@gdxInputFileName.ins"'
$GDXIN InputFileName.gdx

$LOAD i_FileName
*Close the gdx
$GDXIN


*Call setup file
put_utility temp 'exec' / 'gams FTRCalculateSetup';
*put_utility temp 'exec' / 'gams FTRReportSetup';

*Reset the run num
RunNum = 1;

*Loop over all the specified files and run the model
loop(i_FileName,

*Create file that has the current case input file being solved
    putclose vSPDcase "$setglobal       VSPDInputData         " i_Filename.tl:0 / "$setglobal       VSPDRunNum         " RunNum:0;

*Update run number
    RunNum = RunNum + 1;

*Run the model
    put_utility temp 'exec' / 'gams FTRCalculateRental';

);


*==================================
* Cleanup
*==================================
execute 'del *.ins';
execute 'del InputFileName.gdx';
