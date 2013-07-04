$ontext
===================================================================================
Name: VSPDReport.gms
Function: Creates the report templates
Developed by: Ramu Naidoo  (Electricity Authority, New Zealand)
Last modified: 29 November 2011
===================================================================================
$offtext

*===================================================================================
*Include some settings
*===================================================================================

$include vSPDpaths.inc
$include vSPDsettings.inc

*===================================================================================
*Create the reports
*===================================================================================

*Define output files
FILES
SystemResults            / "%OutputPath%%runName%\%runName%_SystemResults.csv" /
OfferResults             / "%OutputPath%%runName%\%runName%_OfferResults.csv" /
TraderResults            / "%OutputPath%%runName%\%runName%_TraderResults.csv" /
SummaryResults_TP        / "%OutputPath%%runName%\%runName%_SummaryResults_TP.csv" /
IslandResults_TP         / "%OutputPath%%runName%\%runName%_IslandResults_TP.csv" /
BusResults_TP            / "%OutputPath%%runName%\%runName%_BusResults_TP.csv" /
NodeResults_TP           / "%OutputPath%%runName%\%runName%_NodeResults_TP.csv" /
OfferResults_TP          / "%OutputPath%%runName%\%runName%_OfferResults_TP.csv" /
ReserveResults_TP        / "%OutputPath%%runName%\%runName%_ReserveResults_TP.csv" /
BranchResults_TP         / "%OutputPath%%runName%\%runName%_BranchResults_TP.csv" /
BrCnstrResults_TP        / "%OutputPath%%runName%\%runName%_BrConstraintResults_TP.csv" /
MNodeCnstrResults_TP     / "%OutputPath%%runName%\%runName%_MNodeConstraintResults_TP.csv" /

*Datawarehouse reports
DWSummaryResults         / "%OutputPath%%runName%\%runName%_DWSummaryResults.csv" /
DWEnergyResults          / "%OutputPath%%runName%\%runName%_DWEnergyResults.csv" /
DWReserveResults         / "%OutputPath%%runName%\%runName%_DWReserveResults.csv" /

*TN - Audit reports
BranchLoss_Audit            / "%OutputPath%%runName%\%runName%_BranchLoss_Audit.csv" /
BusResults_Audit            / "%OutputPath%%runName%\%runName%_BusResults_Audit.csv" /
MarketNodeResults_Audit     / "%OutputPath%%runName%\%runName%_MarketNodeResults_Audit.csv" /
BranchResults_Audit         / "%OutputPath%%runName%\%runName%_BranchResults_Audit.csv" /
RiskResults_Audit           / "%OutputPath%%runName%\%runName%_RiskResults_Audit.csv" /
ObjResults_Audit            / "%OutputPath%%runName%\%runName%_ObjResults_Audit.csv" /
*TN - Audit reports - End
;

*Set output file format
SystemResults.pc = 5;                    SystemResults.lw = 0;                   SystemResults.pw = 9999;
OfferResults.pc = 5;                     OfferResults.lw = 0;                    OfferResults.pw = 9999;
TraderResults.pc = 5;                    TraderResults.lw = 0;                   TraderResults.pw = 9999;
SummaryResults_TP.pc = 5;                SummaryResults_TP.lw = 0;               SummaryResults_TP.pw = 9999;
IslandResults_TP.pc = 5;                 IslandResults_TP.lw = 0;                IslandResults_TP.pw = 9999;
BusResults_TP.pc = 5;                    BusResults_TP.lw = 0;                   BusResults_TP.pw = 9999;
NodeResults_TP.pc = 5;                   NodeResults_TP.lw = 0;                  NodeResults_TP.pw = 9999;
OfferResults_TP.pc = 5;                  OfferResults_TP.lw = 0;                 OfferResults_TP.pw = 9999;
ReserveResults_TP.pc = 5;                ReserveResults_TP.lw = 0;               ReserveResults_TP.pw = 9999;
BranchResults_TP.pc = 5;                 BranchResults_TP.lw = 0;                BranchResults_TP.pw = 9999;
BrCnstrResults_TP.pc = 5;                BrCnstrResults_TP.lw = 0;               BrCnstrResults_TP.pw = 9999;
MNodeCnstrResults_TP.pc = 5;             MNodeCnstrResults_TP.lw = 0;            MNodeCnstrResults_TP.pw = 9999;

*Datawarehouse reports
DWSummaryResults.pc = 5;                 DWSummaryResults.lw = 0;                DWSummaryResults.pw = 9999;
DWEnergyResults.pc = 5;                  DWEnergyResults.lw = 0;                 DWEnergyResults.pw = 9999;
DWReserveResults.pc = 5;                 DWReserveResults.lw = 0;                DWReserveResults.pw = 9999;

*TN - Audit reports
BranchLoss_Audit.pc = 5;                 BranchLoss_Audit.lw = 0;                BranchLoss_Audit.pw = 9999;
BusResults_Audit.pc = 5;                 BusResults_Audit.lw = 0;                BusResults_Audit.pw = 9999;
MarketNodeResults_Audit.pc = 5;          MarketNodeResults_Audit.lw = 0;         MarketNodeResults_Audit.pw = 9999;
BranchResults_Audit.pc = 5;              BranchResults_Audit.lw = 0;             BranchResults_Audit.pw = 9999;
RiskResults_Audit.pc = 5;                RiskResults_Audit.lw = 0;               RiskResults_Audit.pw = 9999;
ObjResults_Audit.pc = 5;                 ObjResults_Audit.lw = 0;                ObjResults_Audit.pw = 9999;

*TN - If NOT in normal vSPD report setup
$if not %DWMode%==0 $goto SkipvSPDReportSetup

*Write out summary reports
*System level
   put SystemResults;
   put 'Date', 'NumTradePeriodsStudied', 'ObjectiveFunctionValue ($)', 'SystemGen (MW(half)h)', 'SystemLoad (MW(half)h)', 'SystemLoss (MW(half)h)', 'SystemViolation (MW(half)h)', 'SystemFIR (MW(half)h)'
       'SystemSIR (MW(half)h)', 'SystemGenerationRevenue ($)', 'SystemLoadCost ($)', 'SystemNegativeLoadRevenue ($)', 'SystemSurplus ($)';

*Offer level
   put OfferResults;
   put 'Date', 'NumTradePeriodsStudied', 'Offer', 'Trader', 'Generation (MWh)', 'FIR (MWh)', 'SIR (MWh)';

*Trader level
   put TraderResults;
   put 'Date', 'NumTradePeriodsStudied', 'Trader', 'Generation (MWh)', 'FIR (MWh)', 'SIR (MWh)';

*TradePeriod reports
$if %TradePeriodReports%==0 $goto SkipTradePeriodReports

   put SummaryResults_TP;
   put 'DateTime', 'SolveStatus (1=OK)', 'SystemCost ($)', 'DeficitGenViol (MW)', 'SurplusGenViol (MW)', 'DeficitReserveViol (MW)', 'SurplusBranchFlowViol (MW)', 'DeficitRampRateViol (MW)', 'SurplusRampRateViol (MW)', 'SurplusBranchGroupConstraintViol (MW)'
       'DeficitBranchGroupConstraintViol (MW)', 'DeficitMNodeConstraintViol (MW)', 'SurplusMNodeConstraintViol (MW)', 'DeficitACNodeConstraintViol(MW)', 'SurplusACNodeConstraintViol (MW)', 'DeficitMixedConstraintViol (MW)', 'SurplusMixedConstraintViol (MW)'
      'DeficitGenericConstraintViol (MW)', 'SurplusGenericConstraintViol (MW)';

   put IslandResults_TP;
   put 'DateTime', 'Island', 'Gen (MW)', 'Load (MW)', 'IslandACLoss (MW)', 'HVDCFlow (MW)', 'HVDCLoss (MW)', 'ReferencePrice ($/MWh)'
       'FIR (MW)', 'SIR (MW)', 'FIR Price ($/MWh)', 'SIR Price ($/MWh)', 'GenerationRevenue ($)', 'LoadCost ($)', 'NegativeLoadRevenue ($)';

   put BusResults_TP;
   put 'DateTime', 'Bus', 'Generation (MW)', 'Load (MW)', 'Price ($/MWh)', 'Revenue ($)', 'Cost ($)', 'Deficit(MW)', 'Surplus(MW)';

   put NodeResults_TP;
   put 'DateTime', 'Node', 'Generation (MW)', 'Load (MW)', 'Price ($/MWh)', 'Revenue ($)', 'Cost ($)', 'Deficit(MW)', 'Surplus(MW)';

   put OfferResults_TP;
   put 'DateTime', 'Offer', 'Generation (MW)', 'FIR (MW)', 'SIR (MW)';

   put ReserveResults_TP;
   put 'DateTime', 'Island', 'FIR Reqd (MW)', 'SIR Reqd (MW)', 'FIR Price ($/MW)', 'SIR Price ($/MW)', 'FIR Violation (MW)', 'SIR Violation (MW)';

   put BranchResults_TP;
   put 'DateTime', 'Branch', 'FromBus', 'ToBus', 'Flow (MW) (From->To)', 'Capacity (MW)', 'DynamicLoss (MW)', 'FixedLoss (MW)', 'FromBusPrice ($/MWh)', 'ToBusPrice ($/MWh)', 'BranchPrice ($/MWh)', 'BranchRentals ($)';

   put BrCnstrResults_TP;
   put 'DateTime', 'BranchConstraint', 'LHS (MW)', 'Sense (-1:<=, 0:=, 1:>=)', 'RHS (MW)', 'Price ($/MWh)';

   put MNodeCnstrResults_TP;
   put 'DateTime', 'MNodeConstraint', 'LHS (MW)', 'Sense (-1:<=, 0:=, 1:>=)', 'RHS (MW)', 'Price ($/MWh)';

$label SkipTradePeriodReports
$label SkipvSPDReportSetup

*TN - If NOT in datawarehouse mode skip the DW report setup
$if not %DWMode%==1 $goto SkipDWReportSetup

   put DWSummaryResults;
   put 'DateTime', 'SolveStatus (1=OK)', 'SystemCost ($)', 'TotalViol (MW)';

   put DWEnergyResults;
   put 'DateTime', 'Node', 'Price ($/MWh)';

   put DWReserveResults;
   put 'DateTime', 'Island', 'FIR Price ($/MW/h)', 'SIR Price ($/MW/h)';

$label SkipDWReportSetup

*TN - Check if in Audit mode
$if not %DWMode%==-1 $goto SkipAuditReportSetup

   put BranchLoss_Audit;
   put 'DateTime', 'Branch Name', 'LS1_MW', 'LS1_Factor', 'LS2_MW', 'LS2_Factor', 'LS3_MW', 'LS3_Factor', 'LS4_MW', 'LS4_Factor', 'LS5_MW', 'LS5_Factor', 'LS6_MW', 'LS6_Factor';

   put BusResults_Audit;
   put 'DateTime', 'Island', 'Bus', 'Angle', 'Price', 'Load', 'Cleared ILRO 6s', 'Cleared ILRO 60s' ;

   put MarketNodeResults_Audit;
   put 'DateTime', 'Island', 'Generator', 'Cleared GenMW', 'Cleared PLRO 6s',  'Cleared PLRO 60s', 'Cleared TWRO 6s', 'Cleared TWRO 60s';

   put BranchResults_Audit;
   put 'DateTime', 'Branch Name', 'Flow', 'Variable Loss', 'Fixed Loss', 'Total Losses', 'Constrained', 'Shadow Price', 'NonPhysicalLoss';

   put RiskResults_Audit;
   put 'DateTime', 'Island', 'ReserveClass', 'Risk Setter', 'RiskClass', 'Max Risk', 'Reserve Cleared', 'Violation', 'Reserve Price';

   put ObjResults_Audit;
   put 'DateTime', 'Objective Function';

$label SkipAuditReportSetup
