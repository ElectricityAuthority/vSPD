*=====================================================================================
* Name:                 vSPDreportSetup.gms
* Function:             Creates the report templates
* Developed by:         Ramu Naidoo (Electricity Authority, New Zealand)
* Last modified by:     Ramu Naidoo on 30 July 2013
*=====================================================================================


$include vSPDpaths.inc
$include vSPDsettings.inc


* Perform integrity checks on operating mode and trade period reporting switches
* Notes: Operating mode: 1 --> DW mode; -1 --> Audit mode; all else implies usual vPSD mode.
*        tradePeriodReports must be 0 or 1 (default = 1) - a value of 1 implies reports by trade period are generated
*        A value of zero will supress them. tradePeriodReports must be 1 if opMode is 1 or -1, ie data warehouse or audit modes.
if(tradePeriodReports < 0 or tradePeriodReports > 1, tradePeriodReports = 1 ) ;
if( (opMode = -1) or (opMode = 1), tradePeriodReports = 1 ) ;
Display opMode, tradePeriodReports ;


Files
* Define output files
  systemResults            / "%outputPath%\%runName%\%runName%_SystemResults.csv" /
  offerResults             / "%outputPath%\%runName%\%runName%_OfferResults.csv" /
  traderResults            / "%outputPath%\%runName%\%runName%_TraderResults.csv" /
  summaryResults_TP        / "%outputPath%\%runName%\%runName%_SummaryResults_TP.csv" /
  islandResults_TP         / "%outputPath%\%runName%\%runName%_IslandResults_TP.csv" /
  busResults_TP            / "%outputPath%\%runName%\%runName%_BusResults_TP.csv" /
  nodeResults_TP           / "%outputPath%\%runName%\%runName%_NodeResults_TP.csv" /
  offerResults_TP          / "%outputPath%\%runName%\%runName%_OfferResults_TP.csv" /
  bidResults_TP            / "%outputPath%\%runName%\%runName%_BidResults_TP.csv" /
  reserveResults_TP        / "%outputPath%\%runName%\%runName%_ReserveResults_TP.csv" /
  branchResults_TP         / "%outputPath%\%runName%\%runName%_BranchResults_TP.csv" /
  brCnstrResults_TP        / "%outputPath%\%runName%\%runName%_BrConstraintResults_TP.csv" /
  MNodeCnstrResults_TP     / "%outputPath%\%runName%\%runName%_MNodeConstraintResults_TP.csv" /

* Define data warehouse output files
  DWsummaryResults         / "%outputPath%\%runName%\%runName%_DWSummaryResults.csv" /
  DWenergyResults          / "%outputPath%\%runName%\%runName%_DWEnergyResults.csv" /
  DWreserveResults         / "%outputPath%\%runName%\%runName%_DWReserveResults.csv" /

* Define audit output files
  branchLoss_Audit         / "%outputPath%\%runName%\%runName%_BranchLoss_Audit.csv" /
  busResults_Audit         / "%outputPath%\%runName%\%runName%_BusResults_Audit.csv" /
  marketNodeResults_Audit  / "%outputPath%\%runName%\%runName%_MarketNodeResults_Audit.csv" /
  branchResults_Audit      / "%outputPath%\%runName%\%runName%_BranchResults_Audit.csv" /
  riskResults_Audit        / "%outputPath%\%runName%\%runName%_RiskResults_Audit.csv" /
  objResults_Audit         / "%outputPath%\%runName%\%runName%_ObjResults_Audit.csv" /
  ;


* Set output file formats
systemResults.pc = 5 ;             systemResults.lw = 0 ;                systemResults.pw = 9999 ;
offerResults.pc = 5 ;              offerResults.lw = 0 ;                 offerResults.pw = 9999 ;
traderResults.pc = 5 ;             traderResults.lw = 0 ;                traderResults.pw = 9999 ;
summaryResults_TP.pc = 5 ;         summaryResults_TP.lw = 0 ;            summaryResults_TP.pw = 9999 ;
islandResults_TP.pc = 5 ;          islandResults_TP.lw = 0 ;             islandResults_TP.pw = 9999 ;
busResults_TP.pc = 5 ;             busResults_TP.lw = 0 ;                busResults_TP.pw = 9999 ;
nodeResults_TP.pc = 5 ;            nodeResults_TP.lw = 0 ;               nodeResults_TP.pw = 9999 ;
offerResults_TP.pc = 5 ;           offerResults_TP.lw = 0 ;              offerResults_TP.pw = 9999 ;
bidResults_TP.pc = 5 ;             bidResults_TP.lw = 0 ;                bidResults_TP.pw = 9999 ;
reserveResults_TP.pc = 5 ;         reserveResults_TP.lw = 0 ;            reserveResults_TP.pw = 9999 ;
branchResults_TP.pc = 5 ;          branchResults_TP.lw = 0 ;             branchResults_TP.pw = 9999 ;
brCnstrResults_TP.pc = 5 ;         brCnstrResults_TP.lw = 0 ;            brCnstrResults_TP.pw = 9999 ;
MNodeCnstrResults_TP.pc = 5 ;      MNodeCnstrResults_TP.lw = 0 ;         MNodeCnstrResults_TP.pw = 9999 ;

* Set data warehouse output file formats
DWsummaryResults.pc = 5 ;          DWsummaryResults.lw = 0 ;             DWsummaryResults.pw = 9999 ;
DWenergyResults.pc = 5 ;           DWenergyResults.lw = 0 ;              DWenergyResults.pw = 9999 ;
DWreserveResults.pc = 5 ;          DWreserveResults.lw = 0 ;             DWreserveResults.pw = 9999 ;

* Set audit output file formats
branchLoss_Audit.pc = 5 ;          branchLoss_Audit.lw = 0 ;             branchLoss_Audit.pw = 9999 ;
busResults_Audit.pc = 5 ;          busResults_Audit.lw = 0 ;             busResults_Audit.pw = 9999 ;
marketNodeResults_Audit.pc = 5 ;   marketNodeResults_Audit.lw = 0 ;      marketNodeResults_Audit.pw = 9999 ;
branchResults_Audit.pc = 5 ;       branchResults_Audit.lw = 0 ;          branchResults_Audit.pw = 9999 ;
riskResults_Audit.pc = 5 ;         riskResults_Audit.lw = 0 ;            riskResults_Audit.pw = 9999 ;
objResults_Audit.pc = 5 ;          objResults_Audit.lw = 0 ;             objResults_Audit.pw = 9999 ;

* If opMode is anything but 1 or -1, ie data warehouse or audit mode, write the following report templates
if( (opMode <> 1) and (opMode <> -1 ),
* System level summary
  put systemResults 'Date', 'NumTradePeriodsStudied', 'ObjectiveFunctionValue ($)', 'SystemGen (MW(half)h)', 'SystemLoad (MW(half)h)'
     'SystemLoss (MW(half)h)', 'SystemViolation (MW(half)h)', 'SystemFIR (MW(half)h)', 'SystemSIR (MW(half)h)', 'SystemGenerationRevenue ($)'
     'SystemLoadCost ($)', 'SystemNegativeLoadRevenue ($)', 'SystemSurplus ($)' ;

* Offer level summary
  put offerResults 'Date', 'NumTradePeriodsStudied', 'Offer', 'Trader', 'Generation (MWh)', 'FIR (MWh)', 'SIR (MWh)' ;

* Trader level summary
  put traderResults 'Date', 'NumTradePeriodsStudied', 'Trader', 'Generation (MWh)', 'FIR (MWh)', 'SIR (MWh)' ;

* In addition to the summary report templates above, write out the trade period report templates provided tradePeriodReports is set to 1
  if(tradePeriodReports = 1,

*RDN - 20130730 - Additional reporting on system objective function and penalty cost
*  put summaryResults_TP 'DateTime', 'SolveStatus (1=OK)', 'SystemCost ($)', 'DeficitGenViol (MW)', 'SurplusGenViol (MW)', 'DeficitReserveViol (MW)'
    put summaryResults_TP 'DateTime', 'SolveStatus (1=OK)', 'SystemOFV ($)', 'SystemCost ($)', 'ViolationCost ($)', 'DeficitGenViol (MW)', 'SurplusGenViol (MW)', 'DeficitReserveViol (MW)'
*RDN - 20130730 - Additional reporting on system objective function and penalty cost
     'SurplusBranchFlowViol (MW)', 'DeficitRampRateViol (MW)', 'SurplusRampRateViol (MW)', 'SurplusBranchGroupConstraintViol (MW)', 'DeficitBranchGroupConstraintViol (MW)'
     'DeficitMNodeConstraintViol (MW)', 'SurplusMNodeConstraintViol (MW)', 'DeficitACNodeConstraintViol(MW)', 'SurplusACNodeConstraintViol (MW)'
     'DeficitMixedConstraintViol (MW)', 'SurplusMixedConstraintViol (MW)', 'DeficitGenericConstraintViol (MW)', 'SurplusGenericConstraintViol (MW)' ;

    put islandResults_TP 'DateTime', 'Island', 'Gen (MW)', 'Fixed Load (MW)', 'Bid Load (MW)', 'IslandACLoss (MW)', 'HVDCFlow (MW)', 'HVDCLoss (MW)', 'ReferencePrice ($/MWh)'
     'FIR (MW)', 'SIR (MW)', 'FIR Price ($/MWh)', 'SIR Price ($/MWh)', 'GenerationRevenue ($)', 'LoadCost ($)', 'NegativeLoadRevenue ($)' ;

    put busResults_TP 'DateTime', 'Bus', 'Generation (MW)', 'Load (MW)', 'Price ($/MWh)', 'Revenue ($)', 'Cost ($)', 'Deficit(MW)', 'Surplus(MW)' ;

    put nodeResults_TP 'DateTime', 'Node', 'Generation (MW)', 'Load (MW)', 'Price ($/MWh)', 'Revenue ($)', 'Cost ($)', 'Deficit(MW)', 'Surplus(MW)' ;

    put offerResults_TP 'DateTime', 'Offer', 'Generation (MW)', 'FIR (MW)', 'SIR (MW)' ;

    put bidResults_TP 'DateTime', 'Bid', 'Total Bid (MW)', 'Cleared Bid (MW)', 'FIR (MW)', 'SIR (MW)' ;

    put reserveResults_TP 'DateTime', 'Island', 'FIR Reqd (MW)', 'SIR Reqd (MW)', 'FIR Price ($/MW)', 'SIR Price ($/MW)', 'FIR Violation (MW)', 'SIR Violation (MW)' ;

    put branchResults_TP 'DateTime', 'Branch', 'FromBus', 'ToBus', 'Flow (MW) (From->To)', 'Capacity (MW)', 'DynamicLoss (MW)', 'FixedLoss (MW)'
     'FromBusPrice ($/MWh)', 'ToBusPrice ($/MWh)', 'BranchPrice ($/MWh)', 'BranchRentals ($)' ;

    put brCnstrResults_TP 'DateTime', 'BranchConstraint', 'LHS (MW)', 'Sense (-1:<=, 0:=, 1:>=)', 'RHS (MW)', 'Price ($/MWh)' ;

    put MNodeCnstrResults_TP 'DateTime', 'MNodeConstraint', 'LHS (MW)', 'Sense (-1:<=, 0:=, 1:>=)', 'RHS (MW)', 'Price ($/MWh)' ;

  ) ;

) ;

* Write out the data warehouse mode report templates
if(opMode = 1,
  put DWsummaryResults 'DateTime', 'SolveStatus (1=OK)', 'SystemCost ($)', 'TotalViol (MW)' ;

  put DWenergyResults  'DateTime', 'Node', 'Price ($/MWh)' ;

  put DWreserveResults 'DateTime', 'Island', 'FIR Price ($/MW/h)', 'SIR Price ($/MW/h)' ;

) ;

* Write out the audit mode report templates
if(opMode = -1,
  put branchLoss_Audit 'DateTime', 'Branch Name', 'LS1_MW', 'LS1_Factor', 'LS2_MW', 'LS2_Factor', 'LS3_MW', 'LS3_Factor', 'LS4_MW', 'LS4_Factor', 'LS5_MW'
     'LS5_Factor', 'LS6_MW', 'LS6_Factor' ;

  put busResults_Audit 'DateTime', 'Island', 'Bus', 'Angle', 'Price', 'Load', 'Cleared ILRO 6s', 'Cleared ILRO 60s'  ;

  put marketNodeResults_Audit 'DateTime', 'Island', 'Generator', 'Cleared GenMW', 'Cleared PLRO 6s',  'Cleared PLRO 60s', 'Cleared TWRO 6s', 'Cleared TWRO 60s' ;

  put branchResults_Audit 'DateTime', 'Branch Name', 'Flow', 'Variable Loss', 'Fixed Loss', 'Total Losses', 'Constrained', 'Shadow Price', 'NonPhysicalLoss' ;

  put riskResults_Audit 'DateTime', 'Island', 'ReserveClass', 'Risk Setter', 'RiskClass', 'Max Risk', 'Reserve Cleared', 'Violation', 'Reserve Price' ;

  put objResults_Audit 'DateTime', 'Objective Function' ;

) ;
