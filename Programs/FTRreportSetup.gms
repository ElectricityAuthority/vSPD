*=====================================================================================
* Name:                 calcFTRrentalSetup.gms
* Function:             Creates the output directories and cleans up the working directory.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://reports.ea.govt.nz/EMIIntro.htm
* Last modified on:     27 May 2014
*=====================================================================================


$include vSPDpaths.inc
$include vSPDsettings.inc

* Create a couple of files.
File bat "A recyclable batch file"  / "%programPath%temp.bat" / ;   bat.lw = 0 ;

* Create and execute a batch file to:
* - remove any output directory with the extant runName;
* - create a new output directory with the extant runName;

*putclose bat
*  'if exist "%OutputPath%%runName%_Result"   rmdir "%OutputPath%%runName%_Result" /s /q' /
*  'mkdir "%OutputPath%%runName%_Result"' /
*  ;

*execute 'temp.bat' ;

* Define output files
Files
  HVDCrent                 / "%outputPath%%runName%\%runName%_HVDCRent.csv" /
  ACrent                   / "%outputPath%%runName%\%runName%_ACRent.csv" /
  brConstraintRent         / "%outputPath%%runName%\%runName%_BrConstraintRent.csv" /
  totalRent                / "%outputPath%%runName%\%runName%_TotalRent.csv" /
  ;

* Set output file format
HVDCRent.pc = 5;                  HVDCRent.lw = 0;                  HVDCRent.pw = 9999;
ACRent.pc = 2;                    ACRent.lw = 0;                    ACRent.pw = 9999;
BrConstraintRent.pc = 2;          BrConstraintRent.lw = 0;          BrConstraintRent.pw = 9999;
TotalRent.pc = 5;                 TotalRent.lw = 0;                 TotalRent.pw = 9999;


SETS
FTRdirection
;
Alias (FTRdirection,ftr) ;

$gdxin FTRinput
$load  FTRdirection
$gdxin

* Write out summary reports
* HVDC rent
put HVDCRent;
put 'DateTime', 'DC Branch', 'SPD Flow (MW)', 'Var Loss (MW)' ;
put 'FromBusPrice ($)', 'ToBusPrice ($)', 'FTR Rent ($)';

* AC branch rent
put ACRent;
put 'DateTime,', 'AC Branch,', 'SPD Flow (MW),' ;
loop( ftr,
    put 'Flow' ftr.tl:0 '(MW),' ;
);
put 'Assigned Cap (MW),', 'Shadow Price ($),', 'FTR Congestion Rent ($),', 'FTR Loss Rent ($)' ;

* AC branch constraint rent
put BrConstraintRent;
put 'DateTime,', 'Branch Constraint,', 'SPD LHS (MW),'
loop( ftr,
    put 'LHS ' ftr.tl:0 ' (MW),' ;
);
put 'Assigned Cap (MW),', 'Shadow Price ($),', 'FTR Rent ($)';

* AC branch constraint rent
put TotalRent;
put 'DateTime', 'HVDC FTR Rent ($)', 'AC Branch FTR Congestion Rent ($)' ;
put 'AC Branch FTR Loss Rent ($)', 'AC Branch Group Constraint FTR Rent ($)' ;
put 'Total FTR Rent ($)', 'AC Total Rent ($)'
