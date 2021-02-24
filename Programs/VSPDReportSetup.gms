*=====================================================================================
* Name:                 vSPDreportSetup.gms
* Function:             Creates the report templates for normal SPD run
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       https://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: https://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Last modified on:     1 Oct 2019
*
*=====================================================================================

$include vSPDsettings.inc

File rep "Write a progess report" /"ProgressReport.txt"/ ;
rep.lw = 0 ; rep.ap = 1 ;
putclose rep "vSPDreportSetup started at: " system.date " " system.time /;


* System level summary
File systemResults    / "%outputPath%\%runName%\%runName%_SystemResults.csv" /;
systemResults.pc = 5 ; systemResults.lw = 0 ; systemResults.pw = 9999 ;
put systemResults 'Date','NumTradePeriodsStudied', 'ObjectiveFunctionValue'
    'SystemGen (MW(half)h)','SystemLoad (MW(half)h)', 'SystemLoss (MW(half)h)'
    'SystemViolation (MW(half)h)','SystemFIR (MW(half)h)'
    'SystemSIR (MW(half)h)','SystemGenerationRevenue ($)','SystemLoadCost ($)'
    'SystemNegativeLoadRevenue ($)','SystemSurplus ($)' ;


* Offer level summary
File offerResults      / "%outputPath%\%runName%\%runName%_OfferResults.csv" /;
offerResults.pc = 5 ; offerResults.lw = 0 ; offerResults.pw = 9999 ;
put offerResults 'Date', 'NumTradePeriodsStudied', 'Offer', 'Trader'
    'Generation (MWh)', 'FIR (MWh)', 'SIR (MWh)' ;


* Trader level summary
File traderResults    / "%outputPath%\%runName%\%runName%_TraderResults.csv" /;
traderResults.pc = 5 ; traderResults.lw = 0 ; traderResults.pw = 9999 ;
put traderResults 'Date', 'NumTradePeriodsStudied', 'Trader'
    'Generation (MWh)', 'FIR (MWh)', 'SIR (MWh)' ;


* Trade Period Reports

File summaryResults_TP   / "%outputPath%\%runName%\%runName%_SummaryResults_TP.csv" /;
summaryResults_TP.pc = 5; summaryResults_TP.lw = 0; summaryResults_TP.pw = 9999;
put summaryResults_TP 'DateTime', 'SolveStatus (1=OK)', 'SystemOFV'
    'SystemCost', 'SystemBenefit', 'ViolationCost'
    'DeficitGenViol (MW)', 'SurplusGenViol (MW)', 'DeficitReserveViol (MW)'
    'SurplusBranchFlowViol (MW)', 'DeficitRampRateViol (MW)'
    'SurplusRampRateViol (MW)', 'DeficitBranchGroupConstraintViol (MW)'
    'SurplusBranchGroupConstraintViol (MW)',
    'DeficitMNodeConstraintViol (MW)', 'SurplusMNodeConstraintViol (MW)'
    'DeficitACNodeConstraintViol(MW)', 'SurplusACNodeConstraintViol (MW)'
    'DeficitMixedConstraintViol (MW)', 'SurplusMixedConstraintViol (MW)'
    'DeficitGenericConstraintViol (MW)', 'SurplusGenericConstraintViol (MW)';


File islandResults_TP    / "%outputPath%\%runName%\%runName%_IslandResults_TP.csv" /;
islandResults_TP.pc = 5; islandResults_TP.lw = 0; islandResults_TP.pw = 9999;
put islandResults_TP 'DateTime', 'Island', 'Gen (MW)', 'Load (MW)'
    'Bid Load (MW)', 'IslandACLoss (MW)', 'HVDCFlow (MW)', 'HVDCLoss (MW)'
    'ReferencePrice ($/MWh)', 'FIR_req (MW)', 'SIR_req (MW)', 'FIR Price ($/MWh)'
    'SIR Price ($/MWh)', 'GenerationRevenue ($)', 'LoadCost ($)'
    'NegativeLoadRevenue ($)'
* NIRM output
    'FIR_Clear', 'SIR_Clear', 'FIR_Share', 'SIR_Share'
    'FIR_Receive', 'SIR_Receive', 'FIR_Effective', 'SIR_Effective'
*NIRM output end
;


File scarcityResults_TP    / "%outputPath%\%runName%\%runName%_ScarcityResults_TP.csv" /;
scarcityResults_TP.pc = 5; scarcityResults_TP.lw = 0; scarcityResults_TP.pw = 9999;
put scarcityResults_TP 'DateTime', 'Island'
    'Scarcity exists (0=none, 1=island, 2=national)'
    'CPT passed', 'AvgPriorGWAP ($/MWh)', 'IslandGWAP_before ($/MWh)'
    'IslandGWAP_after ($/MWh)', 'ScarcityAreaGWAP_before ($/MWh)'
    'ScarcityAreaGWAP_after ($/MWh)', 'ScarcityScalingFactor'
    'CPT_GWAPthreshold ($/MWh)', 'GWAPfloor ($/MWh)', 'GWAPceiling ($/MWh)';


File busResults_TP       / "%outputPath%\%runName%\%runName%_BusResults_TP.csv" /;
busResults_TP.pc = 5; busResults_TP.lw = 0; busResults_TP.pw = 9999;
put busResults_TP 'DateTime', 'Bus', 'Generation (MW)', 'Load (MW)'
    'Price ($/MWh)', 'Revenue ($)', 'Cost ($)', 'Deficit(MW)', 'Surplus(MW)';


File nodeResults_TP      / "%outputPath%\%runName%\%runName%_NodeResults_TP.csv" /;
nodeResults_TP.pc = 5; nodeResults_TP.lw = 0; nodeResults_TP.pw = 9999;
put nodeResults_TP 'DateTime', 'Node', 'Generation (MW)', 'Load (MW)'
    'Price ($/MWh)', 'Revenue ($)', 'Cost ($)', 'Deficit(MW)', 'Surplus(MW)';


File offerResults_TP     / "%outputPath%\%runName%\%runName%_OfferResults_TP.csv" /;
offerResults_TP.pc = 5; offerResults_TP.lw = 0; offerResults_TP.pw = 9999;
put offerResults_TP 'DateTime', 'Offer', 'Generation (MW)', 'FIR (MW)', 'SIR (MW)' ;


File bidResults_TP       / "%outputPath%\%runName%\%runName%_BidResults_TP.csv" /;
bidResults_TP.pc = 5; bidResults_TP.lw = 0; bidResults_TP.pw = 9999;
put bidResults_TP 'DateTime', 'Bid', 'Total Bid (MW)'
    'Cleared Bid (MW)', 'FIR (MW)', 'SIR (MW)' ;


File reserveResults_TP   / "%outputPath%\%runName%\%runName%_ReserveResults_TP.csv" /;
reserveResults_TP.pc = 5; reserveResults_TP.lw = 0; reserveResults_TP.pw = 9999;
put reserveResults_TP 'DateTime', 'Island', 'FIR Reqd (MW)', 'SIR Reqd (MW)'
    'FIR Price ($/MW)', 'SIR Price ($/MW)', 'FIR Violation (MW)'
    'SIR Violation (MW)', 'Virtual FIR (MW)', 'Virtual SIR (MW)' ;


File branchResults_TP    / "%outputPath%\%runName%\%runName%_BranchResults_TP.csv" /;
branchResults_TP.pc = 5; branchResults_TP.lw = 0; branchResults_TP.pw = 9999;
put branchResults_TP 'DateTime', 'Branch', 'FromBus', 'ToBus'
    'Flow (MW) (From->To)', 'Capacity (MW)', 'DynamicLoss (MW)'
    'FixedLoss (MW)', 'FromBusPrice ($/MWh)', 'ToBusPrice ($/MWh)'
    'BranchPrice ($/MWh)', 'BranchRentals ($)' ;


File brCstrResults_TP    / "%outputPath%\%runName%\%runName%_BrConstraintResults_TP.csv" /;
brCstrResults_TP.pc = 5; brCstrResults_TP.lw = 0; brCstrResults_TP.pw = 9999;
put brCstrResults_TP 'DateTime', 'BranchConstraint', 'LHS (MW)'
    'Sense (-1:<=, 0:=, 1:>=)', 'RHS (MW)', 'Price ($/MWh)' ;


File MNodeCstrResults_TP / "%outputPath%\%runName%\%runName%_MNodeConstraintResults_TP.csv" /;
MNodeCstrResults_TP.pc = 5; MNodeCstrResults_TP.lw = 0; MNodeCstrResults_TP.pw = 9999 ;
put MNodeCstrResults_TP 'DateTime', 'MNodeConstraint', 'LHS (MW)'
    'Sense (-1:<=, 0:=, 1:>=)', 'RHS (MW)', 'Price ($/MWh)' ;


*===============================================================================
* Audit mode reporting process
*===============================================================================
$Iftheni.Audit %opMode%=='AUD'

File branchLoss_Audit /"%outputPath%\%runName%\%runName%_Audit_BranchLoss.csv"/;
branchLoss_Audit.pc = 5;  branchLoss_Audit.lw = 0;  branchLoss_Audit.pw = 9999;
put branchLoss_Audit 'DateTime', 'Branch Name'
    'LS1_MW', 'LS1_Factor', 'LS2_MW', 'LS2_Factor', 'LS3_MW', 'LS3_Factor'
    'LS4_MW', 'LS4_Factor', 'LS5_MW', 'LS5_Factor', 'LS6_MW', 'LS6_Factor' ;


File busResults_Audit /"%outputPath%\%runName%\%runName%_Audit_BusResults.csv"/;
busResults_Audit.pc = 5;  busResults_Audit.lw = 0;  busResults_Audit.pw = 9999;
put busResults_Audit 'DateTime', 'Island', 'Bus', 'Angle'
    'Price', 'Load', 'Cleared ILRO 6s', 'Cleared ILRO 60s' ;


File MNodeResults_Audit  /"%outputPath%\%runName%\%runName%_Audit_MNodeResults.csv"/;
MNodeResults_Audit.pc = 5; MNodeResults_Audit.lw = 0; MNodeResults_Audit.pw = 9999;
put MNodeResults_Audit 'DateTime', 'Island', 'Generator', 'Cleared GenMW'
                       'Cleared PLRO 6s',  'Cleared PLRO 60s'
                       'Cleared TWRO 6s', 'Cleared TWRO 60s' ;


File brchResults_Audit  /"%outputPath%\%runName%\%runName%_Audit_BranchResults.csv"/;
brchResults_Audit.pc = 5; brchResults_Audit.lw = 0; brchResults_Audit.pw = 9999;
put brchResults_Audit 'DateTime', 'Branch Name', 'Flow', 'Variable Loss'
'Fixed Loss', 'Total Losses', 'Constrained', 'Shadow Price', 'NonPhysicalLoss';


File riskResults_Audit /"%outputPath%\%runName%\%runName%_Audit_RiskResults.csv"/;
riskResults_Audit.pc = 5; riskResults_Audit.lw = 0; riskResults_Audit.pw = 9999;
put riskResults_Audit 'DateTime', 'Island', 'ReserveClass', 'Risk Setter'
    'RiskClass', 'Max Risk', 'Reserve Cleared', 'Reserve Shared'
    'Violation', 'Reserve Price', 'Virtual Reserve MW' ;


File objResults_Audit /"%outputPath%\%runName%\%runName%_Audit_ObjResults.csv"/;
objResults_Audit.pc = 5; objResults_Audit.lw = 0; objResults_Audit.pw = 9999;
put objResults_Audit 'DateTime', 'Objective Function' ;

$endif.Audit

