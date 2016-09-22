*=====================================================================================
* Name:                 FTRreportSetup.gms
* Function:             Creates the report templates for FTR rental mode
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: http://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Last modified on:     23 Sept 2016
*=====================================================================================
$include vSPDsettings.inc

Sets ftr
$include FTRPattern.inc
;

File HVDCrent         / "%outputPath%%runName%\%runName%_HVDCRent.csv" /;
HVDCRent.pc = 5; HVDCRent.lw = 0; HVDCRent.pw = 9999;
put HVDCRent 'DateTime', 'DC Branch', 'SPD Flow (MW)', 'Var Loss (MW)'
    'FromBusPrice ($)', 'ToBusPrice ($)', 'FTR Rent ($)';

File ACrent           / "%outputPath%%runName%\%runName%_ACRent.csv" /;
ACRent.pc = 2; ACRent.lw = 0; ACRent.pw = 9999;
put ACRent 'DateTime,', 'AC Branch,', 'SPD Flow (MW),' ;
loop( ftr,
  put 'Flow' ftr.tl:0 '(MW),' ;
);
put 'Assigned Cap (MW),', 'Shadow Price ($),', 'FTR Congestion Rent ($),', 'FTR Loss Rent ($)' ;

File brConstraintRent /"%outputPath%%runName%\%runName%_BrConstraintRent.csv"/;
brConstraintRent.pc = 2; brConstraintRent.lw = 0; brConstraintRent.pw = 9999;
put brConstraintRent 'DateTime,', 'Branch Constraint,', 'SPD LHS (MW),';
loop( ftr,
    put 'LHS ' ftr.tl:0 ' (MW),' ;
);
put 'Assigned Cap (MW),', 'Shadow Price ($),', 'FTR Rent ($),';

File totalRent        / "%outputPath%%runName%\%runName%_TotalRent.csv" /;
totalRent.pc = 5; totalRent.lw = 0; totalRent.pw = 9999;
put totalRent 'DateTime','HVDC FTR Rent ($)','AC Branch FTR Congestion Rent ($)'
    'AC Branch FTR Loss Rent ($)', 'AC Branch Group Constraint FTR Rent ($)'
    'Total FTR Rent ($)', 'AC Total Rent ($)' ;

