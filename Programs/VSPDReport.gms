$ontext
===================================================================================
Name: VSPDReport.gms
Function: Creates the detailed reports
Developed by: Ramu Naidoo  (Electricity Authority, New Zealand)
Last modified: 13 May 2013
===================================================================================
$offtext

*===================================================================================
*Include some settings
*===================================================================================

$include vSPDpaths.inc
$include vSPDsettings.inc
$include vSPDcase.inc

*If the input file does not exist then proceed to the next input
$if not exist "%InputPath%%VSPDInputData%.gdx" $ goto NextInput

*===================================================================================
*Create combined output
*===================================================================================

SETS
o_FromDateTime(*)              'From date time set for summary outputs'
o_DateTime(*)                  'Date and time set for output'
o_Bus(*,*)                     'Set of buses for the different time period'
o_Offer(*,*)                   'Set of offers for the different time period'
o_Island(*,*)                  'Island definition for trade period outputs'
i_Offer(*)                     'Set of offers for the different summary outputs'
i_Trader(*)                    'Set of traders for the different summary outputs'
o_OfferTrader(*,*)             'Set of offers mapped to traders for the different summary outputs'
o_Trader(*)                    'Set of traders for the trader summary outputs'
o_Node(*,*)                    'Set of nodes for the different time period'
o_Branch(*,*)                  'Set of branches for the different time period'
o_BranchFromBus_TP(*,*,*)      'Set of from buses for the different branches in each of the different time periods'
o_BranchToBus_TP(*,*,*)        'Set of to buses for the different branches in each of the different time periods'
o_BrConstraint_TP(*,*)         'Set of branch constraint for the different time periods'
o_MNodeConstraint_TP(*,*)      'Set of market node constraint for the different time periods'
*TN - Audit report
   o_ReserveClass                   'This is for audit report' /FIR, SIR/
   o_RiskClass                      'This is for audit report' /GENRISK, DCCE, DCECE, Manual, GENRISK_ECE, Manual_ECE, HVDCSECRISK_CE, HVDCSECRISK_ECE/
   o_LossSegment                    'This is for audit report' /ls1*ls6/
   o_BusIsland_TP(*,*,*)            'Bus Island Mapping for audit report'
   o_MarketNodeIsland_TP(*,*,*)     'Generation Offer Island Mapping for audit reporting'
*TN - Audit report end
;

alias(*,dim1), (*,dim2), (*,dim3), (*,dim4), (*,dim5);

PARAMETERS
*Summary level
o_NumTradePeriods             'Number of trade periods in the summary output for each input data set'
o_SystemOFV                   'System objective function value ($)'
o_SystemGen                   'System generation (MWh) for each input data set'
o_SystemLoad                  'System load (MWh) for each input data set'
o_SystemLoss                  'System loss (MWh) for each input data set'
o_SystemViolation             'System violations (MWh) for each input data set'
o_SystemFIR                   'System FIR reserves (MWh) for each input data set'
o_SystemSIR                   'System SIR reserves (MWh) for each input data set'
o_SystemEnergyRevenue         'System energy revenue ($) for each input data set'
o_SystemReserveRevenue        'System reserve revenue ($) for each input data set'
o_SystemLoadCost              'System load cost ($) for each input data set'
o_SystemLoadRevenue           'System load revenue (negative load cost) ($) for each input data set'
o_SystemSurplus               'System surplus (difference between cost and revenue) ($) for each input data set'
o_OfferGen(*)                 'Offer generation (MWh) for each input data set'
o_OfferFIR(*)                 'Offer FIR (MWh) for each input data set'
o_OfferSIR(*)                 'Offer SIR (MWh) for each input data set'
o_OfferGenRevenue(*)          'Offer generation revenue for each input data set ($)'
o_OfferFIRRevenue(*)          'Offer FIR revenue for each input data set ($)'
o_OfferSIRRevenue(*)          'Offer SIR revenue for each input data set ($)'
o_TraderGen(*)                'Trader generation (MWh) for each input data set'
o_TraderFIR(*)                'Trader FIR (MWh) for each input data set'
o_TraderSIR(*)                'Trader SIR (MWh) for each input data set'
o_TraderGenRevenue(*)         'Trader generation revenue for each input data set ($)'
o_TraderFIRRevenue(*)         'Trader FIR revenue for each input data set ($)'
o_TraderSIRRevenue(*)         'Trader SIR revenue for each input data set ($)'

*Summary reporting by trading period
o_SolveOK_TP(*)               'Solve status (1=OK) for each time period'
o_SystemCost_TP(*)            'System cost for each time period'
o_DefGenViolation_TP(*)       'Deficit generaiton for each time period'
o_SurpGenViolation_TP(*)      'Surplus generation for each time period'
o_SurpBranchFlow_TP(*)        'Surplus branch flow for each time period'
o_DefRampRate_TP(*)           'Deficit ramp rate for each time period'
o_SurpRampRate_TP(*)          'Surplus ramp rate for each time period'
o_SurpBranchGroupConst_TP(*)  'Surplus branch group constraint for each time period'
o_DefBranchGroupConst_TP(*)   'Deficit branch group constraint for each time period'
o_DefMNodeConst_TP(*)         'Deficit market node constraint for each time period'
o_SurpMNodeConst_TP(*)        'Surplus market node constraint for each time period'
o_DefACNodeConst_TP(*)        'Deficit AC node constraint for each time period'
o_SurpACNodeConst_TP(*)       'Surplus AC node constraint for each time period'
o_DefT1MixedConst_TP(*)       'Deficit Type 1 mixed constraint for each time period'
o_SurpT1MixedConst_TP(*)      'Surplus Type 1 mixed constraint for each time period'
o_DefGenericConst_TP(*)       'Deficit generic constraint for each time period'
o_SurpGenericConst_TP(*)      'Surplus generic constraint for each time period'
o_DefResv_TP(*)               'Deficit reserve violation for each time period'
o_TotalViolation_TP(*)        'Total violation for each time period'
*RDN - 20130513 - Additional reporting on system objective function and penalty cost
o_OFV_TP(*)                   'Objective function value for each time period'
o_PenaltyCost_TP(*)           'Penalty cost for each time period'
*RDN - 20130513 - Additional reporting on system objective function and penalty cost

*Trade period level
o_IslandGen_TP(*,*)              'Island generation (MW) for each time period'
o_IslandLoad_TP(*,*)             'Island load (MW) for each time period'
o_IslandEnergyRevenue_TP(*,*)    'Island energy revenue ($) for each time period'
o_IslandLoadCost_TP(*,*)         'Island load cost ($) for each time period'
o_IslandLoadRevenue_TP(*,*)      'Island load revenue (negative load cost) ($) for each time period'
o_IslandSurplus_TP(*,*)          'Island surplus (difference between cost and revenue) ($) for each time period'
o_IslandBranchLoss_TP(*,*)       'Intra-island branch losses for the different time periods (MW)'
o_IslandRefPrice_TP(*,*)         'Reference prices in each island ($/MWh)'
o_HVDCFlow_TP(*,*)               'HVDC flow from each island (MW)'
o_HVDCLoss_TP(*,*)               'HVDC losses (MW)'

o_BusGeneration_TP(*,*)        'Generation per bus per time period for each input data set (MW)'
o_BusLoad_TP(*,*)              'Load per bus per time period for each input data set (MW)'
o_BusPrice_TP(*,*)             'Price per bus per time period for each input data set ($/MWh)'
o_BusRevenue_TP(*,*)           'Revenue per bus per time period for each input data set ($)'
o_BusCost_TP(*,*)              'Cost per bus per time period for each input data set ($)'
o_BusDeficit_TP(*,*)           'Bus deficit generation (MW)'
o_BusSurplus_TP(*,*)           'Bus surplus generation (MW)'
o_NodeGeneration_TP(*,*)       'Generation per node per time period for each input data set (MW)'
o_NodeLoad_TP(*,*)             'Load per node per time period for each input data set (MW)'
o_NodePrice_TP(*,*)            'Price per node per time period for each input data set ($/MWh)'
o_NodeRevenue_TP(*,*)          'Revenue per node per time period for each input data set ($)'
o_NodeCost_TP(*,*)             'Cost per node per time period for each input data set ($)'
o_NodeDeficit_TP(*,*)          'Node deficit generation (MW)'
o_NodeSurplus_TP(*,*)          'Node surplus generation (MW)'
o_OfferEnergy_TP(*,*)          'Energy per offer per time period for each input data set (MW)'
o_OfferFIR_TP(*,*)             'FI reserves per offer per time period for each input data set (MW)'
o_OfferSIR_TP(*,*)             'SI reserves per offer per time period for each input data set (MW)'
o_FIRReqd_TP(*,*)              'FIR required per island per time period for each input data set (MW)'
o_SIRReqd_TP(*,*)              'SIR required per island per time period for each input data set (MW)'
o_FIRPrice_TP(*,*)             'FIR price per island per time period for each input data set ($/MW)'
o_SIRPrice_TP(*,*)             'SIR price per island per time period for each input data set ($/MW)'
o_FIRViolation_TP(*,*)         'FIR violation per island per time period for each input data set (MW)'
o_SIRViolation_TP(*,*)         'SIR violation per island per time period for each input data set (MW)'
o_BranchFlow_TP(*,*)           'Flow on each branch per time period for each input data set (MW)'
o_BranchDynamicLoss_TP(*,*)    'Dynamic loss on each branch per time period for each input data set (MW)'
o_BranchFixedLoss_TP(*,*)      'Fixed loss on each branch per time period for each input data set (MW)'
o_BranchFromBusPrice_TP(*,*)   'Price on from bus for each branch per time period for each input data set ($/MW)'
o_BranchToBusPrice_TP(*,*)     'Price on to bus for each branch per time period for each input data set ($/MW)'
o_BranchMarginalPrice_TP(*,*)  'Marginal constraint price for each branch per time period for each input data set ($/MW)'
o_BranchTotalRentals_TP(*,*)   'Total loss and congestion rentals for each branch per time period for each input data set ($)'
o_BranchCapacity_TP(*,*)       'Branch capacity per time period for each input data set (MW)'
o_BrConstraintSense_TP(*,*)    'Branch constraint sense for each time period and each input data set'
o_BrConstraintLHS_TP(*,*)      'Branch constraint LHS for each time period and each input data set'
o_BrConstraintRHS_TP(*,*)      'Branch constraint RHS for each time period and each input data set'
o_BrConstraintPrice_TP(*,*)    'Branch constraint price for each time period and each input data set'
o_MNodeConstraintSense_TP(*,*) 'Market node constraint sense for each time period and each input data set'
o_MNodeConstraintLHS_TP(*,*)   'Market node constraint LHS for each time period and each input data set'
o_MNodeConstraintRHS_TP(*,*)   'Market node constraint RHS for each time period and each input data set'
o_MNodeConstraintPrice_TP(*,*) 'Market node constraint price for each time period and each input data set'

*TN - Additional output for audit reporting
o_LossSegmentBreakPoint(*,*,*)                       'MW capacity of each loss segment for audit'
o_LossSegmentFactor(*,*,*)                           'Loss factor of each loss segment for audit'

o_ACBusAngle(*,*)                                    'Bus voltage angle for audit reporting'
o_NonPhysicalLoss(*,*)                               'MW losses calculated manually from the solution for each loss branch'

o_ILRO_FIR_TP(*,*)                                   'Output IL offer FIR (MWh)'
o_ILRO_SIR_TP(*,*)                                   'Output IL offer SIR (MWh)'
o_ILBus_FIR_TP(*,*)                                  'Output IL offer FIR (MWh)'
o_ILBus_SIR_TP(*,*)                                  'Output IL offer SIR (MWh)'
o_PLRO_FIR_TP(*,*)                                   'Output PLSR offer FIR (MWh)'
o_PLRO_SIR_TP(*,*)                                   'Output PLSR SIR (MWh)'
o_TWRO_FIR_TP(*,*)                                   'Output TWR FIR (MWh)'
o_TWRO_SIR_TP(*,*)                                   'Output TWR SIR (MWh)'

o_GenerationRiskSetter(*,*,*,*,*)                    'i_DateTime,i_Island,i_Offer,i_ReserveClass,i_RiskClass'
o_GenHVDCRiskSetter(*,*,*,*,*)                       'i_DateTime,i_Island,i_Offer,i_ReserveClass,i_RiskClass'
o_HVDCRiskSetter(*,*,*,*)                            'i_DateTime,i_Island,i_ReserveClass,i_RiskClass'
o_MANURiskSetter(*,*,*,*)                            'i_DateTime,i_Island,i_ReserveClass,i_RiskClass'
o_MANUHVDCRiskSetter(*,*,*,*)                        'i_DateTime,i_Island,i_ReserveClass,i_RiskClass'
*TN - Additional output for audit reporting - End

*RDN - Additional output for audit report - Start-------------------------------
o_FIRCleared_TP(*,*)                                 'FIR cleared - for audit report'
o_SIRCleared_TP(*,*)                                 'SIR cleared - for audit report'
*RDN - Additional output for audit report - End-------------------------------
;

*RDN - Introduce zero tolerance due to numerical rounding issues - when detecting the risk setter - Start---------------------
Scalar ZeroTolerance          /0.000001/;
*RDN - Introduce zero tolerance due to numerical rounding issues - when detecting the risk setter - Start---------------------

*System level
$GDXIN "%OutputPath%%runName%\RunNum%VSPDRunNum%_SystemOutput.gdx"
$LOAD o_FromDateTime
$LOAD o_NumTradePeriods o_SystemOFV o_SystemGen o_SystemLoad o_SystemLoss o_SystemViolation o_SystemFIR o_SystemSIR o_SystemEnergyRevenue
$LOAD o_SystemLoadCost o_SystemLoadRevenue o_SystemSurplus
*Close the gdx
$GDXIN

*Offer level
$GDXIN "%OutputPath%%runName%\RunNum%VSPDRunNum%_OfferOutput.gdx"
$LOAD i_Offer i_Trader o_OfferTrader
$LOAD o_OfferGen o_OfferFIR o_OfferSIR
*Close the gdx
$GDXIN

*Trader level
$GDXIN "%OutputPath%%runName%\RunNum%VSPDRunNum%_TraderOutput.gdx"
$LOAD o_Trader
$LOAD o_TraderGen o_TraderFIR o_TraderSIR
*Close the gdx
$GDXIN

*Read in summary data if the TradePeriodReports flag is set to true

$if %TradePeriodReports%==1 $GDXIN "%OutputPath%%runName%\RunNum%VSPDRunNum%_SummaryOutput_TP.gdx"
$if %TradePeriodReports%==1 $LOAD o_DateTime
$if %TradePeriodReports%==1 $LOAD o_SolveOK_TP o_SystemCost_TP o_DefGenViolation_TP o_SurpGenViolation_TP o_SurpBranchFlow_TP
$if %TradePeriodReports%==1 $LOAD o_DefRampRate_TP o_SurpRampRate_TP o_SurpBranchGroupConst_TP o_DefBranchGroupConst_TP o_DefMNodeConst_TP
$if %TradePeriodReports%==1 $LOAD o_SurpMNodeConst_TP o_DefACNodeConst_TP o_SurpACNodeConst_TP o_DefT1MixedConst_TP o_SurpT1MixedConst_TP
$if %TradePeriodReports%==1 $LOAD o_DefGenericConst_TP o_SurpGenericConst_TP o_DefResv_TP o_TotalViolation_TP
*RDN - 20130513 - Additional reporting on system objective function and penalty cost
$if %TradePeriodReports%==1 $LOAD o_OFV_TP o_PenaltyCost_TP
*RDN - 20130513 - Additional reporting on system objective function and penalty cost

*Close the gdx
$if %TradePeriodReports%==1 $GDXIN

$if %TradePeriodReports%==1 $GDXIN "%OutputPath%%runName%\RunNum%VSPDRunNum%_IslandOutput_TP.gdx"
$if %TradePeriodReports%==1 $LOAD o_IslandGen_TP o_IslandLoad_TP o_IslandBranchLoss_TP o_HVDCFlow_TP o_HVDCLoss_TP o_IslandRefPrice_TP
$if %TradePeriodReports%==1 $LOAD o_IslandEnergyRevenue_TP o_IslandLoadCost_TP o_IslandLoadRevenue_TP
*Close the gdx
$if %TradePeriodReports%==1 $GDXIN

$if %TradePeriodReports%==1 $GDXIN "%OutputPath%%runName%\RunNum%VSPDRunNum%_BusOutput_TP.gdx"
$if %TradePeriodReports%==1 $LOAD o_Bus
$if %TradePeriodReports%==1 $LOAD o_BusGeneration_TP o_BusLoad_TP o_BusPrice_TP o_BusRevenue_TP o_BusCost_TP o_BusDeficit_TP o_BusSurplus_TP
$if %TradePeriodReports%==1 $GDXIN

$if %TradePeriodReports%==1 $GDXIN "%OutputPath%%runName%\RunNum%VSPDRunNum%_NodeOutput_TP.gdx"
$if %TradePeriodReports%==1 $LOAD o_Node
$if %TradePeriodReports%==1 $LOAD o_NodeGeneration_TP o_NodeLoad_TP o_NodePrice_TP o_NodeRevenue_TP o_NodeCost_TP o_NodeDeficit_TP o_NodeSurplus_TP
$if %TradePeriodReports%==1 $GDXIN

$if %TradePeriodReports%==1 $GDXIN "%OutputPath%%runName%\RunNum%VSPDRunNum%_OfferOutput_TP.gdx"
$if %TradePeriodReports%==1 $LOAD o_Offer
$if %TradePeriodReports%==1 $LOAD o_OfferEnergy_TP o_OfferFIR_TP o_OfferSIR_TP
$if %TradePeriodReports%==1 $GDXIN

$if %TradePeriodReports%==1 $GDXIN "%OutputPath%%runName%\RunNum%VSPDRunNum%_ReserveOutput_TP.gdx"
$if %TradePeriodReports%==1 $LOAD o_Island
$if %TradePeriodReports%==1 $LOAD o_FIRReqd_TP o_SIRReqd_TP o_FIRPrice_TP o_SIRPrice_TP o_FIRViolation_TP o_SIRViolation_TP
$if %TradePeriodReports%==1 $GDXIN

$if %TradePeriodReports%==1 $GDXIN "%OutputPath%%runName%\RunNum%VSPDRunNum%_BranchOutput_TP.gdx"
$if %TradePeriodReports%==1 $LOAD o_Branch o_BranchFromBus_TP o_BranchToBus_TP
$if %TradePeriodReports%==1 $LOAD o_BranchFlow_TP o_BranchDynamicLoss_TP o_BranchFixedLoss_TP o_BranchFromBusPrice_TP o_BranchToBusPrice_TP
$if %TradePeriodReports%==1 $LOAD o_BranchMarginalPrice_TP o_BranchTotalRentals_TP o_BranchCapacity_TP
$if %TradePeriodReports%==1 $GDXIN

$if %TradePeriodReports%==1 $GDXIN "%OutputPath%%runName%\RunNum%VSPDRunNum%_BrConstraintOutput_TP.gdx"
$if %TradePeriodReports%==1 $LOAD o_BrConstraint_TP
$if %TradePeriodReports%==1 $LOAD o_BrConstraintSense_TP o_BrConstraintLHS_TP o_BrConstraintRHS_TP o_BrConstraintPrice_TP
$if %TradePeriodReports%==1 $GDXIN

$if %TradePeriodReports%==1 $GDXIN "%OutputPath%%runName%\RunNum%VSPDRunNum%_MNodeConstraintOutput_TP.gdx"
$if %TradePeriodReports%==1 $LOAD o_MNodeConstraint_TP
$if %TradePeriodReports%==1 $LOAD o_MNodeConstraintSense_TP o_MNodeConstraintLHS_TP o_MNodeConstraintRHS_TP o_MNodeConstraintPrice_TP
$if %TradePeriodReports%==1 $GDXIN

*TN - Additional output for audit reporting
$if %DWMode%==-1 $GDXIN "%OutputPath%%runName%\RunNum%VSPDRunNum%_AuditOutput_TP.gdx"
$if %DWMode%==-1 $LOAD o_ACBusAngle o_LossSegmentBreakPoint o_LossSegmentFactor
$if %DWMode%==-1 $LOAD o_NonPhysicalLoss o_BusIsland_TP o_MarketNodeIsland_TP
$if %DWMode%==-1 $LOAD o_PLRO_FIR_TP o_PLRO_SIR_TP o_TWRO_FIR_TP o_TWRO_SIR_TP
$if %DWMode%==-1 $LOAD o_ILRO_FIR_TP o_ILRO_SIR_TP o_ILBus_FIR_TP o_ILBus_SIR_TP
$if %DWMode%==-1 $LOAD o_GenerationRiskSetter o_GenHVDCRiskSetter o_HVDCRiskSetter
$if %DWMode%==-1 $LOAD o_MANURiskSetter o_MANUHVDCRiskSetter o_FIRCleared_TP o_SIRCleared_TP
$if %DWMode%==-1 $GDXIN
*TN - Additional output for audit reporting - End


*Define output files
FILES
SystemResults           / "%OutputPath%%runName%\%runName%_SystemResults.csv" /
OfferResults            / "%OutputPath%%runName%\%runName%_OfferResults.csv" /
TraderResults           / "%OutputPath%%runName%\%runName%_TraderResults.csv" /
SummaryResults_TP       / "%OutputPath%%runName%\%runName%_SummaryResults_TP.csv" /
IslandResults_TP        / "%OutputPath%%runName%\%runName%_IslandResults_TP.csv" /
BusResults_TP           / "%OutputPath%%runName%\%runName%_BusResults_TP.csv" /
NodeResults_TP          / "%OutputPath%%runName%\%runName%_NodeResults_TP.csv" /
OfferResults_TP         / "%OutputPath%%runName%\%runName%_OfferResults_TP.csv" /
ReserveResults_TP       / "%OutputPath%%runName%\%runName%_ReserveResults_TP.csv" /
BranchResults_TP        / "%OutputPath%%runName%\%runName%_BranchResults_TP.csv" /
BrCnstrResults_TP       / "%OutputPath%%runName%\%runName%_BrConstraintResults_TP.csv" /
MNodeCnstrResults_TP    / "%OutputPath%%runName%\%runName%_MNodeConstraintResults_TP.csv" /

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
SystemResults.pc = 5;           SystemResults.lw = 0;          SystemResults.pw = 9999;               SystemResults.ap = 1;
OfferResults.pc = 5;            OfferResults.lw = 0;           OfferResults.pw = 9999;                OfferResults.ap = 1;
TraderResults.pc = 5;           TraderResults.lw = 0;          TraderResults.pw = 9999;               TraderResults.ap = 1;
SummaryResults_TP.pc = 5;       SummaryResults_TP.lw = 0;      SummaryResults_TP.pw = 9999;           SummaryResults_TP.ap = 1;          SummaryResults_TP.nd = 5;
IslandResults_TP.pc = 5;        IslandResults_TP.lw = 0;       IslandResults_TP.pw = 9999;            IslandResults_TP.ap = 1;
BusResults_TP.pc = 5;           BusResults_TP.lw = 0;          BusResults_TP.pw = 9999;               BusResults_TP.ap = 1;
NodeResults_TP.pc = 5;          NodeResults_TP.lw = 0;         NodeResults_TP.pw = 9999;              NodeResults_TP.ap = 1;             NodeResults_TP.nd = 5;
OfferResults_TP.pc = 5;         OfferResults_TP.lw = 0;        OfferResults_TP.pw = 9999;             OfferResults_TP.ap = 1;
ReserveResults_TP.pc = 5;       ReserveResults_TP.lw = 0;      ReserveResults_TP.pw = 9999;           ReserveResults_TP.ap = 1;          ReserveResults_TP.nd = 5;
BranchResults_TP.pc = 5;        BranchResults_TP.lw = 0;       BranchResults_TP.pw = 9999;            BranchResults_TP.ap = 1;
BrCnstrResults_TP.pc = 5;       BrCnstrResults_TP.lw = 0;      BrCnstrResults_TP.pw = 9999;           BrCnstrResults_TP.ap = 1;
MNodeCnstrResults_TP.pc = 5;    MNodeCnstrResults_TP.lw = 0;   MNodeCnstrResults_TP.pw = 9999;        MNodeCnstrResults_TP.ap = 1;

*Datawarehouse reports
DWSummaryResults.pc = 5;       DWSummaryResults.lw = 0;        DWSummaryResults.pw = 9999;            DWSummaryResults.ap = 1;           DWSummaryResults.nd = 5;
DWEnergyResults.pc = 5;        DWEnergyResults.lw = 0;         DWEnergyResults.pw = 9999;             DWEnergyResults.ap = 1;            DWEnergyResults.nd = 5;
DWReserveResults.pc = 5;       DWReserveResults.lw = 0;        DWReserveResults.pw = 9999;            DWReserveResults.ap = 1;           DWReserveResults.nd = 5;

*TN - Audit reports
BranchLoss_Audit.pc = 5;       BranchLoss_Audit.lw = 0;        BranchLoss_Audit.pw = 9999;            BranchLoss_Audit.ap = 1;           BranchLoss_Audit.nd = 5;
BusResults_Audit.pc = 5;       BusResults_Audit.lw = 0;        BusResults_Audit.pw = 9999;            BusResults_Audit.ap = 1;           BusResults_Audit.nd = 5;

BranchResults_Audit.pc = 5;    BranchResults_Audit.lw = 0;     BranchResults_Audit.pw = 9999;         BranchResults_Audit.ap = 1;        BranchResults_Audit.nd = 5;
RiskResults_Audit.pc = 5;      RiskResults_Audit.lw = 0;       RiskResults_Audit.pw = 9999;           RiskResults_Audit.ap = 1;          RiskResults_Audit.nd = 5;
ObjResults_Audit.pc = 5;       ObjResults_Audit.lw = 0;        ObjResults_Audit.pw = 9999;            ObjResults_Audit.ap = 1;           ObjResults_Audit.nd = 5;        ObjResults_Audit.nw=20;

MarketNodeResults_Audit.pc = 5;
MarketNodeResults_Audit.lw = 0;
MarketNodeResults_Audit.pw = 9999;
MarketNodeResults_Audit.ap = 1;
MarketNodeResults_Audit.nd = 5;
*TN - Audit reports - End

*TN - If NOT in normal mode skip the normal vSPD reporting
$if not %DWMode%==0 $goto SkipvSPDReport

*Write out summary reports
*System level
put SystemResults;
loop(dim2 $ o_FromDateTime(dim2),
  put dim2.tl, o_NumTradePeriods, o_SystemOFV, o_SystemGen, o_SystemLoad, o_SystemLoss, o_SystemViolation
      o_SystemFIR, o_SystemSIR, o_SystemEnergyRevenue, o_SystemLoadCost, o_SystemLoadRevenue, o_SystemSurplus /;
);

*Offer level
put OfferResults;
loop((dim2,dim4,dim5) $ (o_FromDateTime(dim2) and i_Offer(dim4) and i_Trader(dim5) and o_OfferTrader(dim4,dim5) and (o_OfferGen(dim4) or o_OfferFIR(dim4) or o_OfferSIR(dim4))),
  put dim2.tl, o_NumTradePeriods, dim4.tl, dim5.tl, o_OfferGen(dim4), o_OfferFIR(dim4), o_OfferSIR(dim4) /;
);

*Trader level
put TraderResults;
loop((dim2,dim4) $ (o_FromDateTime(dim2) and o_Trader(dim4) and (o_TraderGen(dim4) or o_TraderFIR(dim4) or o_TraderSIR(dim4))),
  put dim2.tl, o_NumTradePeriods, dim4.tl, o_TraderGen(dim4), o_TraderFIR(dim4), o_TraderSIR(dim4) /;

);

*TradePeriod reports
$if %TradePeriodReports%==0 $goto SkipTradePeriodReports

put SummaryResults_TP;
loop(dim1 $ o_DateTime(dim1),
*RDN - 20130513 - Additional reporting on system objective function and penalty cost
*  put dim1.tl, o_SolveOK_TP(dim1), o_SystemCost_TP(dim1), o_DefGenViolation_TP(dim1), o_SurpGenViolation_TP(dim1), o_DefResv_TP(dim1), o_SurpBranchFlow_TP(dim1)
  put dim1.tl, o_SolveOK_TP(dim1), o_OFV_TP(dim1), o_SystemCost_TP(dim1), o_PenaltyCost_TP(dim1), o_DefGenViolation_TP(dim1), o_SurpGenViolation_TP(dim1)
*RDN - 20130513 - Additional reporting on system objective function and penalty cost
      o_DefResv_TP(dim1), o_SurpBranchFlow_TP(dim1), o_DefRampRate_TP(dim1), o_SurpRampRate_TP(dim1)
      o_SurpBranchGroupConst_TP(dim1), o_DefBranchGroupConst_TP(dim1), o_DefMNodeConst_TP(dim1)
      o_SurpMNodeConst_TP(dim1), o_DefACNodeConst_TP(dim1), o_SurpACNodeConst_TP(dim1)
      o_DefT1MixedConst_TP(dim1), o_SurpT1MixedConst_TP(dim1), o_DefGenericConst_TP(dim1), o_SurpGenericConst_TP(dim1) /;
);

put IslandResults_TP;
loop((dim1,dim2) $ (o_DateTime(dim1) and o_Island(dim1,dim2)),
  put dim1.tl, dim2.tl, o_IslandGen_TP(dim1,dim2), o_IslandLoad_TP(dim1,dim2), o_IslandBranchLoss_TP(dim1,dim2), o_HVDCFlow_TP(dim1,dim2), o_HVDCLoss_TP(dim1,dim2), o_IslandRefPrice_TP(dim1,dim2)
      o_FIRReqd_TP(dim1,dim2), o_SIRReqd_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2)
      o_IslandEnergyRevenue_TP(dim1,dim2), o_IslandLoadCost_TP(dim1,dim2), o_IslandLoadRevenue_TP(dim1,dim2) /;
);

put BusResults_TP;
loop((dim2,dim3) $ (o_DateTime(dim2) and o_Bus(dim2,dim3)),
  put dim2.tl, dim3.tl, o_BusGeneration_TP(dim2,dim3), o_BusLoad_TP(dim2,dim3), o_BusPrice_TP(dim2,dim3), o_BusRevenue_TP(dim2,dim3), o_BusCost_TP(dim2,dim3), o_BusDeficit_TP(dim2,dim3), o_BusSurplus_TP(dim2,dim3) /;
);

put NodeResults_TP;
loop((dim2,dim3) $ (o_DateTime(dim2) and o_Node(dim2,dim3)),
  put dim2.tl, dim3.tl, o_NodeGeneration_TP(dim2,dim3), o_NodeLoad_TP(dim2,dim3), o_NodePrice_TP(dim2,dim3), o_NodeRevenue_TP(dim2,dim3), o_NodeCost_TP(dim2,dim3), o_NodeDeficit_TP(dim2,dim3), o_NodeSurplus_TP(dim2,dim3) /;
);

put OfferResults_TP;
loop((dim2,dim3) $ (o_DateTime(dim2) and o_Offer(dim2,dim3)),
  put dim2.tl, dim3.tl, o_OfferEnergy_TP(dim2,dim3), o_OfferFIR_TP(dim2,dim3), o_OfferSIR_TP(dim2,dim3) /;
);

put ReserveResults_TP;
loop((dim2,dim3) $ (o_DateTime(dim2) and o_Island(dim2,dim3)),
  put dim2.tl, dim3.tl, o_FIRReqd_TP(dim2,dim3), o_SIRReqd_TP(dim2,dim3), o_FIRPrice_TP(dim2,dim3), o_SIRPrice_TP(dim2,dim3), o_FIRViolation_TP(dim2,dim3), o_SIRViolation_TP(dim2,dim3) /;
);

put BranchResults_TP;
loop((dim2,dim3,dim4,dim5) $ (o_DateTime(dim2) and o_Branch(dim2,dim3) and o_BranchFromBus_TP(dim2,dim3,dim4) and o_BranchToBus_TP(dim2,dim3,dim5)),
  put dim2.tl, dim3.tl, dim4.tl, dim5.tl, o_BranchFlow_TP(dim2,dim3), o_BranchCapacity_TP(dim2,dim3), o_BranchDynamicLoss_TP(dim2,dim3), o_BranchFixedLoss_TP(dim2,dim3)
      o_BranchFromBusPrice_TP(dim2,dim3), o_BranchToBusPrice_TP(dim2,dim3), o_BranchMarginalPrice_TP(dim2,dim3), o_BranchTotalRentals_TP(dim2,dim3) /;
);

put BrCnstrResults_TP;
loop((dim2,dim3) $ (o_DateTime(dim2) and o_BrConstraint_TP(dim2,dim3)),
  put dim2.tl, dim3.tl, o_BrConstraintLHS_TP(dim2,dim3), o_BrConstraintSense_TP(dim2,dim3), o_BrConstraintRHS_TP(dim2,dim3), o_BrConstraintPrice_TP(dim2,dim3) /;
);

put MNodeCnstrResults_TP;
loop((dim2,dim3) $ (o_DateTime(dim2) and o_MNodeConstraint_TP(dim2,dim3)),
  put dim2.tl, dim3.tl, o_MNodeConstraintLHS_TP(dim2,dim3), o_MNodeConstraintSense_TP(dim2,dim3), o_MNodeConstraintRHS_TP(dim2,dim3), o_MNodeConstraintPrice_TP(dim2,dim3) /;
);

$label SkipTradePeriodReports

$label SkipvSPDReport

*TN - If NOT in datawarehouse mode skip the DW report setup
$if not %DWMode%==1 $goto SkipDWReport

put DWSummaryResults;
loop(dim1 $ o_DateTime(dim1),
  put dim1.tl, o_SolveOK_TP(dim1), o_SystemCost_TP(dim1), o_TotalViolation_TP(dim1) /;
);

put DWEnergyResults;
loop((dim2,dim3) $ (o_DateTime(dim2) and o_Node(dim2,dim3)),
  put dim2.tl, dim3.tl, o_NodePrice_TP(dim2,dim3) /;
);

put DWReserveResults;
loop((dim2,dim3) $ (o_DateTime(dim2) and o_Island(dim2,dim3)),
  put dim2.tl, dim3.tl, o_FIRPrice_TP(dim2,dim3), o_SIRPrice_TP(dim2,dim3) /;
);

$label SkipDWReport

*TN - if NOT in Audit mode skip audit report
$if not %DWMode%==-1 $goto SkipAuditReportSetup

put BranchLoss_Audit;
*put 'DateTime', 'Branch Name', 'LS1_MW', 'LS1_Factor', 'LS2_MW', 'LS2_Factor', 'LS3_MW', 'LS3_Factor', 'LS4_MW', 'LS4_Factor', 'LS5_MW', 'LS5_Factor', 'LS6_MW', 'LS6_Factor';
loop((dim1,dim2) $ [o_DateTime(dim1) and o_Branch(dim1,dim2)],
   put dim1.tl, dim2.tl;
   loop(o_LossSegment $ o_LossSegmentBreakPoint(dim1,dim2,o_LossSegment),
      put o_LossSegmentBreakPoint(dim1,dim2,o_LossSegment), o_LossSegmentFactor(dim1,dim2,o_LossSegment);
   );
   put /;
);

put BusResults_Audit;
*put 'DateTime', 'Island', 'Bus', 'Angle', 'Price', 'Load', 'Cleared ILRO 6s', 'Cleared ILRO 60s' ;
loop((dim1,dim2,dim3) $ (o_DateTime(dim1) and o_Bus(dim1,dim2) and o_BusIsland_TP(dim1,dim2,dim3)),
   put dim1.tl, dim3.tl, dim2.tl, o_ACBusAngle(dim1,dim2), o_BusPrice_TP(dim1,dim2), o_BusLoad_TP(dim1,dim2), o_ILBus_FIR_TP(dim1,dim2), o_ILBus_SIR_TP(dim1,dim2) /;
);

put MarketNodeResults_Audit;
*put 'DateTime', 'Island', 'Generator', 'Cleared GenMW', 'Cleared PLRO 6s', 'Cleared PLRO 60s', 'Cleared TWRO 6s', 'Cleared TWRO 60s';
loop((dim1,dim2,dim3) $ (o_DateTime(dim1) and o_Offer(dim1,dim2) and o_MarketNodeIsland_TP(dim1,dim2,dim3)),
   put dim1.tl, dim3.tl, dim2.tl, o_OfferEnergy_TP(dim1,dim2), o_PLRO_FIR_TP(dim1,dim2), o_PLRO_SIR_TP(dim1,dim2), o_TWRO_FIR_TP(dim1,dim2), o_TWRO_SIR_TP(dim1,dim2) /;
);

put BranchResults_Audit;
*put 'DateTime', 'Branch Name', 'Flow', 'Variable Loss', 'Fixed Loss', 'Total Losses', 'Constrained', 'Shadow Price', 'NonPhysicalLoss';
loop((dim1,dim2) $ (o_DateTime(dim1) and o_Branch(dim1,dim2)),
*RDN - Update branch loss reporting for Audit report - Start--------------------
   put dim1.tl, dim2.tl, o_BranchFlow_TP(dim1,dim2), o_BranchDynamicLoss_TP(dim1,dim2), o_BranchFixedLoss_TP(dim1,dim2), (o_BranchDynamicLoss_TP(dim1,dim2) + o_BranchFixedLoss_TP(dim1,dim2));
*RDN - Update branch loss reporting for Audit report - End--------------------
   if([abs(o_BranchCapacity_TP(dim1,dim2)-abs(o_BranchFlow_TP(dim1,dim2))) <= ZeroTolerance],
      put 'Y';
   else
      put 'N';
   );
   put o_BranchMarginalPrice_TP(dim1,dim2);
   if(o_NonPhysicalLoss(dim1,dim2) > NonPhysicalLossTolerance,
      put 'Y' /;
   else
      put 'N' /;
   );
);


*RDN - Revised risk results - Start --------------------------------------------
put RiskResults_Audit;
*put 'DateTime', 'Island', 'ReserveClass', 'Risk Setter', 'RiskClass', 'Max Risk', 'Reserve Cleared', 'Violation';
loop((dim1,dim2,o_ReserveClass) $ (o_DateTime(dim1) and o_Island(dim1,dim2)),

   loop(o_RiskClass,

      loop(dim3 $ o_Offer(dim1,dim3),
*         if([ord(o_ReserveClass)=1] and [o_GenerationRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass) = o_FIRReqd_TP(dim1,dim2)] and [o_FIRReqd_TP(dim1,dim2) > 0],
         if([ord(o_ReserveClass)=1] and (abs[o_GenerationRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass)-o_FIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_FIRReqd_TP(dim1,dim2) > 0],
*   put 'DateTime', 'Island', 'ReserveClass', 'Risk Setter', 'RiskClass', 'Max Risk', 'Reserve Cleared', 'Violation', 'Reserve Price';
            put dim1.tl, dim2.tl, o_ReserveClass.tl, dim3.tl, o_RiskClass.tl, o_GenerationRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass), o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2) /;
*         elseif [ord(o_ReserveClass)=2] and [o_GenerationRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass) = o_SIRReqd_TP(dim1,dim2)] and [o_SIRReqd_TP(dim1,dim2) > 0],
         elseif [ord(o_ReserveClass)=2] and (abs[o_GenerationRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass)-o_SIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_SIRReqd_TP(dim1,dim2) > 0],
            put dim1.tl, dim2.tl, o_ReserveClass.tl, dim3.tl, o_RiskClass.tl, o_GenerationRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass), o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2) /;
         );
      );

      loop(dim3 $ o_Offer(dim1,dim3),
*         if([ord(o_ReserveClass)=1] and [o_GenHVDCRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass) = o_FIRReqd_TP(dim1,dim2)] and [o_FIRReqd_TP(dim1,dim2) > 0],
         if([ord(o_ReserveClass)=1] and (abs[o_GenHVDCRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass)-o_FIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_FIRReqd_TP(dim1,dim2) > 0],
*   put 'DateTime', 'Island', 'ReserveClass', 'Risk Setter', 'RiskClass', 'Max Risk', 'Reserve Cleared', 'Violation', 'Reserve Price';
            put dim1.tl, dim2.tl, o_ReserveClass.tl, dim3.tl, o_RiskClass.tl, o_GenHVDCRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass), o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2) /;
*         elseif [ord(o_ReserveClass)=2] and [o_GenHVDCRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass) = o_SIRReqd_TP(dim1,dim2)] and [o_SIRReqd_TP(dim1,dim2) > 0],
         elseif [ord(o_ReserveClass)=2] and (abs[o_GenHVDCRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass)-o_SIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_SIRReqd_TP(dim1,dim2) > 0],
            put dim1.tl, dim2.tl, o_ReserveClass.tl, dim3.tl, o_RiskClass.tl, o_GenHVDCRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass), o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2) /;

         );
      );

*      if([ord(o_ReserveClass)=1] and [o_HVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass) = o_FIRReqd_TP(dim1,dim2)] and [o_FIRReqd_TP(dim1,dim2) > 0],
      if([ord(o_ReserveClass)=1] and (abs[o_HVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass)-o_FIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_FIRReqd_TP(dim1,dim2) > 0],
*   put 'DateTime', 'Island', 'ReserveClass', 'Risk Setter', 'RiskClass', 'Max Risk', 'Reserve Cleared', 'Violation', 'Reserve Price';
         put dim1.tl, dim2.tl, o_ReserveClass.tl, 'HVDC', o_RiskClass.tl, o_HVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass), o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2) /;
*      elseif [ord(o_ReserveClass)=2] and [o_HVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass) = o_SIRReqd_TP(dim1,dim2)] and [o_SIRReqd_TP(dim1,dim2) > 0],
      elseif [ord(o_ReserveClass)=2] and (abs[o_HVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass)-o_SIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_SIRReqd_TP(dim1,dim2) > 0],
         put dim1.tl, dim2.tl, o_ReserveClass.tl, 'HVDC', o_RiskClass.tl, o_HVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass), o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2) /;
      );

*      if([ord(o_ReserveClass)=1] and [o_MANURiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass) = o_FIRReqd_TP(dim1,dim2)] and [o_FIRReqd_TP(dim1,dim2) > 0],
      if([ord(o_ReserveClass)=1] and (abs[o_MANURiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass)-o_FIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_FIRReqd_TP(dim1,dim2) > 0],
*   put 'DateTime', 'Island', 'ReserveClass', 'Risk Setter', 'RiskClass', 'Max Risk', 'Reserve Cleared', 'Violation', 'Reserve Price';
         put dim1.tl, dim2.tl, o_ReserveClass.tl, 'Manual', o_RiskClass.tl, o_MANURiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass), o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2) /;
*      elseif [ord(o_ReserveClass)=2] and [o_MANURiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass) = o_SIRReqd_TP(dim1,dim2)] and [o_SIRReqd_TP(dim1,dim2) > 0],
      elseif [ord(o_ReserveClass)=2] and (abs[o_MANURiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass)-o_SIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_SIRReqd_TP(dim1,dim2) > 0],
         put dim1.tl, dim2.tl, o_ReserveClass.tl, 'Manual', o_RiskClass.tl, o_MANURiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass), o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2) /;
      );

*      if([ord(o_ReserveClass)=1] and [o_MANUHVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass) = o_FIRReqd_TP(dim1,dim2)] and [o_FIRReqd_TP(dim1,dim2) > 0],
      if([ord(o_ReserveClass)=1] and (abs[o_MANUHVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass)-o_FIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_FIRReqd_TP(dim1,dim2) > 0],
*   put 'DateTime', 'Island', 'ReserveClass', 'Risk Setter', 'RiskClass', 'Max Risk', 'Reserve Cleared', 'Violation', 'Reserve Price';
         put dim1.tl, dim2.tl, o_ReserveClass.tl, 'Manual', o_RiskClass.tl, o_MANUHVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass), o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2) /;
*      elseif [ord(o_ReserveClass)=2] and [o_MANUHVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass) = o_SIRReqd_TP(dim1,dim2)] and [o_SIRReqd_TP(dim1,dim2) > 0],
      elseif [ord(o_ReserveClass)=2] and (abs[o_MANUHVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass)-o_SIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_SIRReqd_TP(dim1,dim2) > 0],
         put dim1.tl, dim2.tl, o_ReserveClass.tl, 'Manual', o_RiskClass.tl, o_MANUHVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass), o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2) /;
      );
   );

*Ensure still reporting for conditions with zero FIR and/or SIR required
*   put 'DateTime', 'Island', 'ReserveClass', 'Risk Setter', 'RiskClass', 'Max Risk', 'Reserve Cleared', 'Violation', 'Reserve Price';
   if([ord(o_ReserveClass)=1] and [o_FIRReqd_TP(dim1,dim2) = 0],
      put dim1.tl, dim2.tl, o_ReserveClass.tl, ' ', ' ', ' ', o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2) /;
   elseif [ord(o_ReserveClass)=2] and [o_SIRReqd_TP(dim1,dim2) = 0],
      put dim1.tl, dim2.tl, o_ReserveClass.tl, ' ', ' ', ' ', o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2) /;
   );



);
*RDN - Revised risk results - End ----------------------------------------------

put ObjResults_Audit;
loop(dim1 $ o_DateTime(dim1),
   put dim1.tl, o_SystemCost_TP(dim1) /;
);

$label SkipAuditReportSetup

*Go to the next input file
$label NextInput
