*=====================================================================================
* Name:                 calcFTRrentalSetup.gms
* Function:             Creates the output directories and cleans up the working directory.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://reports.ea.govt.nz/EMIIntro.htm
* Last modified on:     18 November 2013
*=====================================================================================


$include vSPDpaths.inc
$include vSPDsettings.inc

* Create a couple of files.
File bat "A recyclable batch file"  / "%programPath%temp.bat" / ;   bat.lw = 0 ;

* Create and execute a batch file to:
* - remove any output directory with the extant runName;
* - create a new output directory with the extant runName;

putclose bat
  'if exist "%OutputPath%%runName%_Result"        rmdir "%OutputPath%%runName%_Result" /s /q' /
  'mkdir "%OutputPath%%runName%_Result"' /
  ;

execute 'temp.bat' ;

* Define output files
Files
  HVDCrent                 / "%outputPath%%runName%_result\%runName%_HVDCRent.csv" /
  ACrent                   / "%outputPath%%runName%_result\%runName%_ACRent.csv" /
  brConstraintRent         / "%outputPath%%runName%_result\%runName%_BrConstraintRent.csv" /
  totalRent                / "%outputPath%%runName%_result\%runName%_TotalRent.csv" /
  ;

* Set output file format
HVDCRent.pc = 5;                  HVDCRent.lw = 0;                  HVDCRent.pw = 9999;
ACRent.pc = 5;                    ACRent.lw = 0;                    ACRent.pw = 9999;
BrConstraintRent.pc = 5;          BrConstraintRent.lw = 0;          BrConstraintRent.pw = 9999;
TotalRent.pc = 5;                 TotalRent.lw = 0;                 TotalRent.pw = 9999;

* Write out summary reports
* HVDC rent
put HVDCRent;
put 'DateTime', 'DC Branch', 'SPD Flow (MW)', 'Var Loss (MW)', 'FromBusPrice ($)', 'ToBusPrice ($)', 'FTR Rent ($)';

* AC branch rent
put ACRent;
put 'DateTime', 'AC Branch', 'SPD Flow (MW)', 'Flow 1 (MW)', 'Flow 2 (MW)', 'Assigned Cap (MW)', 'Shadow Price ($)', 'FTR Congestion Rent ($)', 'FTR Loss Rent ($)' ;

* AC branch constraint rent
put BrConstraintRent;
put 'DateTime', 'Branch Constraint', 'SPD LHS (MW)', 'LHS 1 (MW)', 'LHS 2 (MW)', 'Assigned Cap (MW)', 'Shadow Price ($)', 'FTR Rent ($)';

* AC branch constraint rent
put TotalRent;
put 'DateTime', 'HVDC FTR Rent ($)', 'AC Branch FTR Congestion Rent ($)', 'AC Branch FTR Loss Rent ($)', 'AC Branch Group Constraint FTR Rent ($)', 'Total FTR Rent ($)', 'AC Total Rent ($)';
