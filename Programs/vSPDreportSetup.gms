*=====================================================================================
* Name:                 vSPDreportSetup.gms
* Function:             Creates the report templates
*                       Note re: operating mode:
*                         -1 --> Audit mode
*                          0 --> usual vSPD mode
*                          1 --> EA Data warehouse mode
*                          2 --> FTR rental mode.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     12 January 2015
*=====================================================================================


$include vSPDpaths.inc
$include vSPDsettings.inc
$setglobal outputfolder "%outputPath%%runName%\%runName%"
$if not %opMode%==0 tradePeriodReports = 1;

File rep "Write a progess report" /"ProgressReport.txt"/ ;
rep.lw = 0 ; rep.ap = 1 ;
putclose rep "vSPDreportSetup started at: " system.date " " system.time /;


*===============================================================================
* Data warehouse reporting process
*===============================================================================
$if not %opMode% == 1 $goto DWReportingEnd
File DWsummaryResults /"%outputPath%\%runName%\%runName%_DWSummaryResults.csv"/;
DWsummaryResults.pc = 5 ;
DWsummaryResults.lw = 0 ;
DWsummaryResults.pw = 9999 ;
put DWsummaryResults 'DateTime', 'SolveStatus (1=OK)'
                     'SystemCost ($)', 'TotalViol (MW)' ;

File DWenergyResults   /"%outputPath%\%runName%\%runName%_DWEnergyResults.csv"/;
DWenergyResults.pc = 5 ;
DWenergyResults.lw = 0 ;
DWenergyResults.pw = 9999 ;
put DWenergyResults  'DateTime', 'Node', 'Price ($/MWh)' ;

File DWreserveResults /"%outputPath%\%runName%\%runName%_DWReserveResults.csv"/;
DWreserveResults.pc = 5 ;
DWreserveResults.lw = 0 ;
DWreserveResults.pw = 9999 ;
put DWreserveResults 'DateTime', 'Island'
                     'FIR Price ($/MW/h)', 'SIR Price ($/MW/h)' ;

$goto End
$label DWReportingEnd


*===============================================================================
* FTR rental reporting process
*===============================================================================
$if not %opMode% == 2 $goto SkipFTRRentalReport

SETS FTRPattern
$include FTRPattern.inc
;
Alias (FTRPattern,ftr) ;

File HVDCrent               / "%outputPath%%runName%\%runName%_HVDCRent.csv" /;
HVDCRent.pc = 5;
HVDCRent.lw = 0;
HVDCRent.pw = 9999;
put HVDCRent 'DateTime', 'DC Branch', 'SPD Flow (MW)', 'Var Loss (MW)'
    'FromBusPrice ($)', 'ToBusPrice ($)', 'FTR Rent ($)';

File ACrent                   / "%outputPath%%runName%\%runName%_ACRent.csv" /;
ACRent.pc = 2;
ACRent.lw = 0;
ACRent.pw = 9999;
put ACRent 'DateTime,', 'AC Branch,', 'SPD Flow (MW),' ;
loop( ftr,
  put 'Flow' ftr.tl:0 '(MW),' ;
);
put 'Assigned Cap (MW),', 'Shadow Price ($),'
    'FTR Congestion Rent ($),', 'FTR Loss Rent ($),' ;

File brConstraintRent /"%outputPath%%runName%\%runName%_BrConstraintRent.csv"/;
brConstraintRent.pc = 2;
brConstraintRent.lw = 0;
brConstraintRent.pw = 9999;
put brConstraintRent 'DateTime,', 'Branch Constraint,', 'SPD LHS (MW),';
loop( ftr,
    put 'LHS ' ftr.tl:0 ' (MW),' ;
);
put 'Assigned Cap (MW),', 'Shadow Price ($),', 'FTR Rent ($),';

File totalRent             / "%outputPath%%runName%\%runName%_TotalRent.csv" /;
totalRent.pc = 5;
totalRent.lw = 0;
totalRent.pw = 9999;
put totalRent 'DateTime','HVDC FTR Rent ($)','AC Branch FTR Congestion Rent ($)'
    'AC Branch FTR Loss Rent ($)', 'AC Branch Group Constraint FTR Rent ($)'
    'Total FTR Rent ($)', 'AC Total Rent ($)' ;

$goto End
$label SkipFTRRentalReport


*===============================================================================
* Normal reporting process
*===============================================================================
* System level summary
File systemResults    / "%outputPath%\%runName%\%runName%_SystemResults.csv" /;
systemResults.pc = 5 ;
systemResults.lw = 0 ;
systemResults.pw = 9999 ;
put systemResults 'Date','NumTradePeriodsStudied', 'ObjectiveFunctionValue ($)'
    'SystemGen (MW(half)h)','SystemLoad (MW(half)h)', 'SystemLoss (MW(half)h)'
    'SystemViolation (MW(half)h)','SystemFIR (MW(half)h)'
    'SystemSIR (MW(half)h)','SystemGenerationRevenue ($)','SystemLoadCost ($)'
    'SystemNegativeLoadRevenue ($)','SystemSurplus ($)' ;


* Offer level summary
File offerResults      / "%outputPath%\%runName%\%runName%_OfferResults.csv" /;
offerResults.pc = 5 ;
offerResults.lw = 0 ;
offerResults.pw = 9999 ;
put offerResults 'Date', 'NumTradePeriodsStudied', 'Offer', 'Trader'
    'Generation (MWh)', 'FIR (MWh)', 'SIR (MWh)' ;


* Trader level summary
File traderResults    / "%outputPath%\%runName%\%runName%_TraderResults.csv" /;
traderResults.pc = 5 ;
traderResults.lw = 0 ;
traderResults.pw = 9999 ;
put traderResults 'Date', 'NumTradePeriodsStudied', 'Trader'
    'Generation (MWh)', 'FIR (MWh)', 'SIR (MWh)' ;


* In addition to the summary report templates above, write out the trade period
* report templates provided tradePeriodReports is set to 1 (or <> 0)
Files
summaryResults_TP / "%outputPath%\%runName%\%runName%_SummaryResults_TP.csv" /
islandResults_TP  / "%outputPath%\%runName%\%runName%_IslandResults_TP.csv" /
busResults_TP     / "%outputPath%\%runName%\%runName%_BusResults_TP.csv" /
nodeResults_TP    / "%outputPath%\%runName%\%runName%_NodeResults_TP.csv" /
offerResults_TP   / "%outputPath%\%runName%\%runName%_OfferResults_TP.csv" /
bidResults_TP     / "%outputPath%\%runName%\%runName%_BidResults_TP.csv" /
reserveResults_TP / "%outputPath%\%runName%\%runName%_ReserveResults_TP.csv" /
branchResults_TP  / "%outputPath%\%runName%\%runName%_BranchResults_TP.csv" /
brCstrResults_TP    / "%outputfolder%_BrConstraintResults_TP.csv" /
MNodeCstrResults_TP / "%outputfolder%_MNodeConstraintResults_TP.csv" /;

if(tradePeriodReports <> 0,

  summaryResults_TP.pc = 5 ;
  summaryResults_TP.lw = 0 ;
  summaryResults_TP.pw = 9999 ;
  put summaryResults_TP 'DateTime', 'SolveStatus (1=OK)', 'SystemOFV ($)'
      'SystemCost ($)', 'SystemBenefit ($)', 'ViolationCost ($)'
      'DeficitGenViol (MW)', 'SurplusGenViol (MW)', 'DeficitReserveViol (MW)'
      'SurplusBranchFlowViol (MW)', 'DeficitRampRateViol (MW)'
      'SurplusRampRateViol (MW)', 'DeficitBranchGroupConstraintViol (MW)'
      'SurplusBranchGroupConstraintViol (MW)',
      'DeficitMNodeConstraintViol (MW)', 'SurplusMNodeConstraintViol (MW)'
      'DeficitACNodeConstraintViol(MW)', 'SurplusACNodeConstraintViol (MW)'
      'DeficitMixedConstraintViol (MW)', 'SurplusMixedConstraintViol (MW)'
      'DeficitGenericConstraintViol (MW)', 'SurplusGenericConstraintViol (MW)';

  islandResults_TP.pc = 5 ;
  islandResults_TP.lw = 0 ;
  islandResults_TP.pw = 9999 ;
  put islandResults_TP 'DateTime', 'Island', 'Gen (MW)', 'Load (MW)'
      'Bid Load (MW)', 'IslandACLoss (MW)', 'HVDCFlow (MW)', 'HVDCLoss (MW)'
      'ReferencePrice ($/MWh)', 'FIR (MW)', 'SIR (MW)', 'FIR Price ($/MWh)'
      'SIR Price ($/MWh)', 'GenerationRevenue ($)', 'LoadCost ($)'
      'NegativeLoadRevenue ($)','Scarcity exists (0=none, 1=island, 2=national)'
      'CPT passed', 'AvgPriorGWAP ($/MWh)', 'IslandGWAP_before ($/MWh)'
      'IslandGWAP_after ($/MWh)', 'ScarcityAreaGWAP_before ($/MWh)'
      'ScarcityAreaGWAP_after ($/MWh)', 'ScarcityScalingFactor'
      'CPT_GWAPthreshold ($/MWh)', 'GWAPfloor ($/MWh)', 'GWAPceiling ($/MWh)' ;

  busResults_TP.pc = 5 ;
  busResults_TP.lw = 0 ;
  busResults_TP.pw = 9999 ;
  put busResults_TP 'DateTime', 'Bus', 'Generation (MW)', 'Load (MW)'
      'Price ($/MWh)', 'Revenue ($)', 'Cost ($)', 'Deficit(MW)', 'Surplus(MW)';

  nodeResults_TP.pc = 5 ;
  nodeResults_TP.lw = 0 ;
  nodeResults_TP.pw = 9999 ;
  put nodeResults_TP 'DateTime', 'Node', 'Generation (MW)', 'Load (MW)'
      'Price ($/MWh)', 'Revenue ($)', 'Cost ($)', 'Deficit(MW)', 'Surplus(MW)';

  offerResults_TP.pc = 5 ;
  offerResults_TP.lw = 0 ;
  offerResults_TP.pw = 9999 ;
  put offerResults_TP 'DateTime', 'Offer'
      'Generation (MW)', 'FIR (MW)', 'SIR (MW)' ;

  bidResults_TP.pc = 5 ;
  bidResults_TP.lw = 0 ;
  bidResults_TP.pw = 9999 ;
  put bidResults_TP 'DateTime', 'Bid', 'Total Bid (MW)'
      'Cleared Bid (MW)', 'FIR (MW)', 'SIR (MW)' ;

  reserveResults_TP.pc = 5 ;
  reserveResults_TP.lw = 0 ;
  reserveResults_TP.pw = 9999 ;
  put reserveResults_TP 'DateTime', 'Island',
      'FIR Reqd (MW)', 'SIR Reqd (MW)'
      'FIR Price ($/MW)', 'SIR Price ($/MW)'
      'FIR Violation (MW)', 'SIR Violation (MW)'
      'Virtual FIR (MW)', 'Virtual SIR (MW)' ;

  branchResults_TP.pc = 5 ;
  branchResults_TP.lw = 0 ;
  branchResults_TP.pw = 9999 ;
  put branchResults_TP 'DateTime', 'Branch', 'FromBus', 'ToBus'
      'Flow (MW) (From->To)', 'Capacity (MW)', 'DynamicLoss (MW)'
      'FixedLoss (MW)', 'FromBusPrice ($/MWh)', 'ToBusPrice ($/MWh)'
      'BranchPrice ($/MWh)', 'BranchRentals ($)' ;

  brCstrResults_TP.pc = 5 ;
  brCstrResults_TP.lw = 0 ;
  brCstrResults_TP.pw = 9999 ;
  put brCstrResults_TP 'DateTime', 'BranchConstraint', 'LHS (MW)'
      'Sense (-1:<=, 0:=, 1:>=)', 'RHS (MW)', 'Price ($/MWh)' ;

  MNodeCstrResults_TP.pc = 5 ;
  MNodeCstrResults_TP.lw = 0 ;
  MNodeCstrResults_TP.pw = 9999 ;
  put MNodeCstrResults_TP 'DateTime', 'MNodeConstraint', 'LHS (MW)'
      'Sense (-1:<=, 0:=, 1:>=)', 'RHS (MW)', 'Price ($/MWh)' ;

) ;


*===============================================================================
* Audit mode reporting process
*===============================================================================
$if not %opMode% == -1 $goto AuditReportingEnd

File branchLoss_Audit /"%outputPath%\%runName%\%runName%_BranchLoss_Audit.csv"/;
branchLoss_Audit.pc = 5 ;
branchLoss_Audit.lw = 0 ;
branchLoss_Audit.pw = 9999 ;
put branchLoss_Audit 'DateTime', 'Branch Name'
    'LS1_MW', 'LS1_Factor', 'LS2_MW', 'LS2_Factor', 'LS3_MW', 'LS3_Factor'
    'LS4_MW', 'LS4_Factor', 'LS5_MW', 'LS5_Factor', 'LS6_MW', 'LS6_Factor' ;

File busResults_Audit /"%outputPath%\%runName%\%runName%_BusResults_Audit.csv"/;
busResults_Audit.pc = 5 ;
busResults_Audit.lw = 0 ;
busResults_Audit.pw = 9999 ;
put busResults_Audit 'DateTime', 'Island', 'Bus', 'Angle'
    'Price', 'Load', 'Cleared ILRO 6s', 'Cleared ILRO 60s' ;

File
MNodeResults_Audit  /"%outputPath%\%runName%\%runName%_MNodeResults_Audit.csv"/;
MNodeResults_Audit.pc = 5 ;
MNodeResults_Audit.lw = 0 ;
MNodeResults_Audit.pw = 9999 ;
put MNodeResults_Audit 'DateTime', 'Island', 'Generator', 'Cleared GenMW'
                       'Cleared PLRO 6s',  'Cleared PLRO 60s'
                       'Cleared TWRO 6s', 'Cleared TWRO 60s' ;

File
brchResults_Audit  /"%outputPath%\%runName%\%runName%_BranchResults_Audit.csv"/;
brchResults_Audit.pc = 5 ;
brchResults_Audit.lw = 0 ;
brchResults_Audit.pw = 9999 ;
put brchResults_Audit 'DateTime', 'Branch Name', 'Flow', 'Variable Loss'
'Fixed Loss', 'Total Losses', 'Constrained', 'Shadow Price', 'NonPhysicalLoss';

File riskResults_Audit /"%outputPath%\%runName%\%runName%_RiskResults_Audit.csv"/;
riskResults_Audit.pc = 5 ;
riskResults_Audit.lw = 0 ;
riskResults_Audit.pw = 9999 ;
put riskResults_Audit 'DateTime', 'Island', 'ReserveClass', 'Risk Setter'
    'RiskClass', 'Max Risk', 'Reserve Cleared', 'Violation', 'Reserve Price'
    'Virtual Reserve MW' ;

File objResults_Audit /"%outputPath%\%runName%\%runName%_ObjResults_Audit.csv"/;
objResults_Audit.pc = 5 ;
objResults_Audit.lw = 0 ;
objResults_Audit.pw = 9999 ;
put objResults_Audit 'DateTime', 'Objective Function' ;

$label AuditReportingEnd


$label End
