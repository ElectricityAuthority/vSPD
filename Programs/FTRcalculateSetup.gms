$ontext
===================================================================================
Name: FTR_Calculate_Setup.gms
Function: Creates the output directories and cleans up the working directory.
Developed by: Tuong Nguyen  (Electricity Authority, New Zealand)
Last modified: 16 November 2012
===================================================================================
$offtext

$include vSPDsettings.inc
$include vSPDpaths.inc

* Create a couple of files.
File bat "A recyclable batch file"  / "%ProgramPath%temp.bat" / ;        bat.lw = 0 ;

* Create and execute a batch file to:
* - remove any output directory with the extant runName;
* - create a new output directory with the extant runName;

putclose bat
  'if exist "%OutputPath%%runName%_Result"        rmdir "%OutputPath%%runName%_Result" /s /q' /
  'mkdir "%OutputPath%%runName%_Result"' /
  ;

execute 'temp.bat' ;



*Define output files
FILES
HVDCRent                 / "%OutputPath%%runName%_Result\%runName%_HVDCRent.csv" /
ACRent                   / "%OutputPath%%runName%_Result\%runName%_ACRent.csv" /
BrConstraintRent         / "%OutputPath%%runName%_Result\%runName%_BrConstraintRent.csv" /
TotalRent                / "%OutputPath%%runName%_Result\%runName%_TotalRent.csv" /
;

*Set output file format
HVDCRent.pc = 5;                         HVDCRent.lw = 0;                        HVDCRent.pw = 9999;
ACRent.pc = 5;                           ACRent.lw = 0;                          ACRent.pw = 9999;
BrConstraintRent.pc = 5;                 BrConstraintRent.lw = 0;                BrConstraintRent.pw = 9999;
TotalRent.pc = 5;                        TotalRent.lw = 0;                       TotalRent.pw = 9999;

*Write out summary reports
*HVDC rent
put HVDCRent;
put 'DateTime', 'DC Branch', 'SPD Flow (MW)', 'Var Loss (MW)', 'FromBusPrice ($)', 'ToBusPrice ($)', 'FTR Rent ($)';

*AC branch rent
put ACRent;
put 'DateTime', 'AC Branch', 'SPD Flow (MW)', 'Flow 1 (MW)', 'Flow 2 (MW)', 'Assigned Cap (MW)', 'Shadow Price ($)', 'FTR Congestion Rent ($)', 'FTR Loss Rent ($)' ;

*AC branch constraint rent
put BrConstraintRent;
put 'DateTime', 'Branch Constraint', 'SPD LHS (MW)', 'LHS 1 (MW)', 'LHS 2 (MW)', 'Assigned Cap (MW)', 'Shadow Price ($)', 'FTR Rent ($)';

*AC branch constraint rent
put TotalRent;
put 'DateTime', 'HVDC FTR Rent ($)', 'AC Branch FTR Congestion Rent ($)', 'AC Branch FTR Loss Rent ($)', 'AC Branch Group Constraint FTR Rent ($)', 'Total FTR Rent ($)', 'AC Total Rent ($)';
