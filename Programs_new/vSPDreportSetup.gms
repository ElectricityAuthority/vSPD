*===============================================================================
* Name:                 vSPDreportSetup.gms
* Function:             Creates the report templates for normal SPD run
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       https://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: https://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Last modified on:     1 Oct 2019
* Last modified on:     08 August 2023
*                       add Period to report
*===============================================================================

$include vSPDsettings.inc

File rep "Write a progess report" /"ProgressReport.txt"/ ;
rep.lw = 0 ; rep.ap = 1 ;
putclose rep "vSPDreportSetup started at: " system.date " " system.time /;

* Trade Period Reports *********************************************************
File summaryResults_TP   / "%outputPath%\%runName%\%runName%_SummaryResults_TP.csv" /;
summaryResults_TP.pc = 5; summaryResults_TP.lw = 0; summaryResults_TP.pw = 9999;
put summaryResults_TP 'CaseID','DateTime','Period','SolveStatus (1=OK)', 'SystemOFV','SystemCost', 'SystemBenefit', 'ViolationCost','DeficitGenViol (MW)', 'SurplusGenViol (MW)', 'DeficitReserveViol (MW)','SurplusBranchFlowViol (MW)'
    'DeficitRampRateViol (MW)','SurplusRampRateViol (MW)', 'DeficitBranchGroupConstraintViol (MW)','SurplusBranchGroupConstraintViol (MW)', 'DeficitMNodeConstraintViol (MW)', 'SurplusMNodeConstraintViol (MW)';

File islandResults_TP    / "%outputPath%\%runName%\%runName%_IslandResults_TP.csv" /;
islandResults_TP.pc = 5; islandResults_TP.lw = 0; islandResults_TP.pw = 9999;
put islandResults_TP 'CaseID','DateTime','Period', 'Island', 'Gen (MW)', 'Load (MW)', 'Bid Load (MW)', 'IslandACLoss (MW)', 'HVDCFlow (MW)', 'HVDCLoss (MW)'
    'ReferencePrice ($/MWh)', 'FIR_req (MW)', 'SIR_req (MW)','FIR Price ($/MWh)', 'SIR Price ($/MWh)'
    'FIR_Clear', 'SIR_Clear', 'FIR_Share', 'SIR_Share','FIR_Receive', 'SIR_Receive', 'FIR_Effective_CE', 'SIR_Effective_CE', 'FIR_Effective_ECE', 'SIR_Effective_ECE' ;

File busResults_TP       / "%outputPath%\%runName%\%runName%_BusResults_TP.csv" /;
busResults_TP.pc = 5; busResults_TP.lw = 0; busResults_TP.pw = 9999;
put busResults_TP 'CaseID','DateTime','Period', 'Bus', 'Generation (MW)', 'Load (MW)','Price ($/MWh)', 'Deficit(MW)', 'Surplus(MW)';

File nodeResults_TP      / "%outputPath%\%runName%\%runName%_NodeResults_TP.csv" /;
nodeResults_TP.pc = 5; nodeResults_TP.lw = 0; nodeResults_TP.pw = 9999;
put nodeResults_TP 'CaseID','DateTime','Period', 'Node','Generation (MW)','Load (MW)','Price ($/MWh)','Deficit(MW)', 'Surplus(MW)';
    
File PublishedEnergyPrices_TP /"%outputPath%\%runName%\%runName%_PublishedEnergyPrices_TP.csv"/;
PublishedEnergyPrices_TP.pc = 5 ; PublishedEnergyPrices_TP.lw = 0 ; PublishedEnergyPrices_TP.pw = 9999 ;
put PublishedEnergyPrices_TP 'TradingPeriod','Pnodename','vSPDDollarsPerMegawattHour';

File PublishedReservePrices_TP /"%outputPath%\%runName%\%runName%_PublishedReservePrices_TP.csv"/;
PublishedReservePrices_TP.pc = 5 ; PublishedReservePrices_TP.lw = 0 ; PublishedReservePrices_TP.pw = 9999 ;
put PublishedReservePrices_TP 'TradingPeriod','Island','vSPDFIRDollarsPerMegawattHour','vSPDSIRDollarsPerMegawattHour';

File offerResults_TP     / "%outputPath%\%runName%\%runName%_OfferResults_TP.csv" /;
offerResults_TP.pc = 5; offerResults_TP.lw = 0; offerResults_TP.pw = 9999;
put offerResults_TP 'CaseID','DateTime','Period','Offer','Trader','Generation (MW)','FIR (MW)','SIR (MW)' ;

File bidResults_TP       / "%outputPath%\%runName%\%runName%_BidResults_TP.csv" /;
bidResults_TP.pc = 5; bidResults_TP.lw = 0; bidResults_TP.pw = 9999;
put bidResults_TP 'CaseID','DateTime','Period', 'Bid', 'Trader','Total Bid (MW)', 'Cleared Bid (MW)' ;

File reserveResults_TP   / "%outputPath%\%runName%\%runName%_ReserveResults_TP.csv" /;
reserveResults_TP.pc = 5; reserveResults_TP.lw = 0; reserveResults_TP.pw = 9999;
put reserveResults_TP 'CaseID','DateTime','Period', 'Island', 'FIR Reqd (MW)', 'SIR Reqd (MW)','FIR Price ($/MW)', 'SIR Price ($/MW)', 'FIR Violation (MW)', 'SIR Violation (MW)' ;

File riskResults_TP   / "%outputPath%\%runName%\%runName%_RiskResults_TP.csv" /;
riskResults_TP.pc = 5; riskResults_TP.lw = 0; riskResults_TP.pw = 9999;
put riskResults_TP 'CaseID','DateTime','Period', 'Island', 'ReserveClass', 'RiskClass','RiskType','RiskSetter','CoveredEnergy','CoveredReserve','CoveredFKBand','RiskSubtractor','Reserve','Shortfall','Deficit','ReservePrice','RiskPrice';

File branchResults_TP    / "%outputPath%\%runName%\%runName%_BranchResults_TP.csv" /;
branchResults_TP.pc = 5; branchResults_TP.lw = 0; branchResults_TP.pw = 9999;
put branchResults_TP 'CaseID','DateTime','Period', 'Branch', 'FromBus', 'ToBus','Flow (MW) (From->To)', 'Capacity (MW)', 'DynamicLoss (MW)','FixedLoss (MW)', 'FromBusPrice ($/MWh)', 'ToBusPrice ($/MWh)', 'BranchPrice ($/MWh)', 'BranchRentals ($)' ;

File brCstrResults_TP    / "%outputPath%\%runName%\%runName%_BrConstraintResults_TP.csv" /;
brCstrResults_TP.pc = 5; brCstrResults_TP.lw = 0; brCstrResults_TP.pw = 9999;
put brCstrResults_TP 'CaseID','DateTime','Period', 'BranchConstraint', 'LHS (MW)','Sense (-1:<=, 0:=, 1:>=)', 'RHS (MW)', 'Price ($/MWh)' ;

File MNodeCstrResults_TP / "%outputPath%\%runName%\%runName%_MNodeConstraintResults_TP.csv" /;
MNodeCstrResults_TP.pc = 5; MNodeCstrResults_TP.lw = 0; MNodeCstrResults_TP.pw = 9999 ;
put MNodeCstrResults_TP 'CaseID','DateTime','Period', 'MNodeConstraint', 'LHS (MW)','Sense (-1:<=, 0:=, 1:>=)', 'RHS (MW)', 'Price ($/MWh)' ;

*===============================================================================
* Audit mode reporting process
*===============================================================================
$Iftheni.Audit %opMode%=='AUD'

File branchLoss_Audit /"%outputPath%\%runName%\%runName%_Audit_BranchLoss.csv"/;
branchLoss_Audit.pc = 5;  branchLoss_Audit.lw = 0;  branchLoss_Audit.pw = 9999;
put branchLoss_Audit 'CaseID','DateTime','Period', 'Branch Name','LS1_MW', 'LS1_Factor', 'LS2_MW', 'LS2_Factor', 'LS3_MW', 'LS3_Factor','LS4_MW', 'LS4_Factor', 'LS5_MW', 'LS5_Factor', 'LS6_MW', 'LS6_Factor' ;

File busResults_Audit /"%outputPath%\%runName%\%runName%_Audit_BusResults.csv"/;
busResults_Audit.pc = 5;  busResults_Audit.lw = 0;  busResults_Audit.pw = 9999;
put busResults_Audit 'CaseID','DateTime','Period', 'Island', 'Bus', 'Angle','Price', 'Load', 'Cleared ILRO 6s', 'Cleared ILRO 60s' ;

File MNodeResults_Audit  /"%outputPath%\%runName%\%runName%_Audit_MNodeResults.csv"/;
MNodeResults_Audit.pc = 5; MNodeResults_Audit.lw = 0; MNodeResults_Audit.pw = 9999;
put MNodeResults_Audit 'CaseID','DateTime','Period', 'Island', 'Generator', 'Cleared GenMW','Cleared PLRO 6s',  'Cleared PLRO 60s','Cleared TWRO 6s', 'Cleared TWRO 60s' ;

File brchResults_Audit  /"%outputPath%\%runName%\%runName%_Audit_BranchResults.csv"/;
brchResults_Audit.pc = 5; brchResults_Audit.lw = 0; brchResults_Audit.pw = 9999;
put brchResults_Audit 'CaseID','DateTime','Period', 'Branch Name', 'Flow', 'Variable Loss','Fixed Loss', 'Total Losses', 'Constrained', 'Shadow Price', 'NonPhysicalLoss';

File riskResults_Audit /"%outputPath%\%runName%\%runName%_Audit_RiskResults.csv"/;
riskResults_Audit.pc = 5; riskResults_Audit.lw = 0; riskResults_Audit.pw = 9999;
put riskResults_Audit 'CaseID','DateTime','Period', 'Island', 'ReserveClass', 'Risk Setter','RiskClass', 'Max Risk', 'Reserve Cleared', 'Reserve Shared','Violation', 'Reserve Price' ;

File objResults_Audit /"%outputPath%\%runName%\%runName%_Audit_ObjResults.csv"/;
objResults_Audit.pc = 5; objResults_Audit.lw = 0; objResults_Audit.pw = 9999;
put objResults_Audit 'CaseID','DateTime','Period', 'Objective Function' ;

$endif.Audit

