*=====================================================================================
* Name:                 vSPDreport.gms
* Function:             Creates the detailed reports
* Developed by:         Ramu Naidoo (Electricity Authority, New Zealand)
* Last modified by:     Ramu Naidoo on 30 July 2013
*=====================================================================================


* Include some settings
$include vSPDpaths.inc
$include vSPDsettings.inc
$include vSPDcase.inc

* Perform integrity checks on operating mode and trade period reporting switches
* Notes: Operating mode: 1 --> DW mode; -1 --> Audit mode; all else implies usual vPSD mode.
*        tradePeriodReports must be 0 or 1 (default = 1) - a value of 1 implies reports by trade period are generated
*        A value of zero will supress them. tradePeriodReports must be 1 if opMode is 1 or -1, ie data warehouse or audit modes.
if(tradePeriodReports < 0 or tradePeriodReports > 1, tradePeriodReports = 1 ) ;
if( (opMode = -1) or (opMode = 1), tradePeriodReports = 1 ) ;
*Display opMode, tradePeriodReports ;

* If the input file does not exist then proceed to the next input file by skipping all of this program
$if not exist "%inputPath%\%vSPDinputData%.gdx" $goto nextInput


*===================================================================================
* Declare sets and parameters required for reporting
*===================================================================================
Sets
  o_fromDateTime(*)                   'From date time set for summary outputs'
  o_dateTime(*)                       'Date and time set for output'
  o_bus(*,*)                          'Set of buses for the different time period'
  o_offer(*,*)                        'Set of offers for the different time period'
  o_island(*,*)                       'Island definition for trade period outputs'
  i_offer(*)                          'Set of offers for the different summary outputs'
  i_trader(*)                         'Set of traders for the different summary outputs'
  o_offerTrader(*,*)                  'Set of offers mapped to traders for the different summary outputs'
  o_trader(*)                         'Set of traders for the trader summary outputs'
  o_node(*,*)                         'Set of nodes for the different time period'
  o_branch(*,*)                       'Set of branches for the different time period'
  o_branchFromBus_TP(*,*,*)           'Set of from buses for the different branches in each of the different time periods'
  o_branchToBus_TP(*,*,*)             'Set of to buses for the different branches in each of the different time periods'
  o_brConstraint_TP(*,*)              'Set of branch constraint for the different time periods'
  o_MnodeConstraint_TP(*,*)           'Set of market node constraint for the different time periods'
* Audit report sets
  o_reserveClass                      'This is for audit report' / FIR, SIR /
  o_riskClass                         'This is for audit report' / GENRISK, DCCE, DCECE, Manual, GENRISK_ECE, Manual_ECE, HVDCSECRISK_CE, HVDCSECRISK_ECE /
  o_lossSegment                       'This is for audit report' / ls1*ls6 /
  o_busIsland_TP(*,*,*)               'Bus Island Mapping for audit report'
  o_marketNodeIsland_TP(*,*,*)        'Generation Offer Island Mapping for audit reporting'
  ;

Alias (*,dim1), (*,dim2), (*,dim3), (*,dim4), (*,dim5) ;

Parameters
* Summary level
  o_numTradePeriods                  'Number of trade periods in the summary output for each input data set'
  o_systemOFV                        'System objective function value ($)'
  o_systemGen                        'System generation (MWh) for each input data set'
  o_systemLoad                       'System load (MWh) for each input data set'
  o_systemLoss                       'System loss (MWh) for each input data set'
  o_systemViolation                  'System violations (MWh) for each input data set'
  o_systemFIR                        'System FIR reserves (MWh) for each input data set'
  o_systemSIR                        'System SIR reserves (MWh) for each input data set'
  o_systemEnergyRevenue              'System energy revenue ($) for each input data set'
  o_systemReserveRevenue             'System reserve revenue ($) for each input data set'
  o_systemLoadCost                   'System load cost ($) for each input data set'
  o_systemLoadRevenue                'System load revenue (negative load cost) ($) for each input data set'
  o_systemSurplus                    'System surplus (difference between cost and revenue) ($) for each input data set'
  o_offerGen(*)                      'Offer generation (MWh) for each input data set'
  o_offerFIR(*)                      'Offer FIR (MWh) for each input data set'
  o_offerSIR(*)                      'Offer SIR (MWh) for each input data set'
  o_offerGenRevenue(*)               'Offer generation revenue for each input data set ($)'
  o_offerFIRRevenue(*)               'Offer FIR revenue for each input data set ($)'
  o_offerSIRRevenue(*)               'Offer SIR revenue for each input data set ($)'
  o_traderGen(*)                     'Trader generation (MWh) for each input data set'
  o_traderFIR(*)                     'Trader FIR (MWh) for each input data set'
  o_traderSIR(*)                     'Trader SIR (MWh) for each input data set'
  o_traderGenRevenue(*)              'Trader generation revenue for each input data set ($)'
  o_traderFIRRevenue(*)              'Trader FIR revenue for each input data set ($)'
  o_traderSIRRevenue(*)              'Trader SIR revenue for each input data set ($)'

* Summary reporting by trading period
  o_solveOK_TP(*)                    'Solve status (1=OK) for each time period'
  o_systemCost_TP(*)                 'System cost for each time period'
  o_defGenViolation_TP(*)            'Deficit generaiton for each time period'
  o_surpGenViolation_TP(*)           'Surplus generation for each time period'
  o_surpBranchFlow_TP(*)             'Surplus branch flow for each time period'
  o_defRampRate_TP(*)                'Deficit ramp rate for each time period'
  o_surpRampRate_TP(*)               'Surplus ramp rate for each time period'
  o_surpBranchGroupConst_TP(*)       'Surplus branch group constraint for each time period'
  o_defBranchGroupConst_TP(*)        'Deficit branch group constraint for each time period'
  o_defMnodeConst_TP(*)              'Deficit market node constraint for each time period'
  o_surpMnodeConst_TP(*)             'Surplus market node constraint for each time period'
  o_defACNodeConst_TP(*)             'Deficit AC node constraint for each time period'
  o_surpACNodeConst_TP(*)            'Surplus AC node constraint for each time period'
  o_defT1MixedConst_TP(*)            'Deficit Type 1 mixed constraint for each time period'
  o_surpT1MixedConst_TP(*)           'Surplus Type 1 mixed constraint for each time period'
  o_defGenericConst_TP(*)            'Deficit generic constraint for each time period'
  o_surpGenericConst_TP(*)           'Surplus generic constraint for each time period'
  o_defResv_TP(*)                    'Deficit reserve violation for each time period'
  o_totalViolation_TP(*)             'Total violation for each time period'
*RDN - 20130730 - Additional reporting on system objective function and penalty cost
  o_ofv_TP(*)                        'Objective function value for each time period'
  o_penaltyCost_TP(*)                'Penalty cost for each time period'

* Trading period level
  o_islandGen_TP(*,*)                'Island generation (MW) for each time period'
  o_islandLoad_TP(*,*)               'Island load (MW) for each time period'
  o_islandEnergyRevenue_TP(*,*)      'Island energy revenue ($) for each time period'
  o_islandLoadCost_TP(*,*)           'Island load cost ($) for each time period'
  o_islandLoadRevenue_TP(*,*)        'Island load revenue (negative load cost) ($) for each time period'
  o_islandSurplus_TP(*,*)            'Island surplus (difference between cost and revenue) ($) for each time period'
  o_islandBranchLoss_TP(*,*)         'Intra-island branch losses for the different time periods (MW)'
  o_islandRefPrice_TP(*,*)           'Reference prices in each island ($/MWh)'
  o_HVDCflow_TP(*,*)                 'HVDC flow from each island (MW)'
  o_HVDCloss_TP(*,*)                 'HVDC losses (MW)'
  o_busGeneration_TP(*,*)            'Generation per bus per time period for each input data set (MW)'
  o_busLoad_TP(*,*)                  'Load per bus per time period for each input data set (MW)'
  o_busPrice_TP(*,*)                 'Price per bus per time period for each input data set ($/MWh)'
  o_busRevenue_TP(*,*)               'Revenue per bus per time period for each input data set ($)'
  o_busCost_TP(*,*)                  'Cost per bus per time period for each input data set ($)'
  o_busDeficit_TP(*,*)               'Bus deficit generation (MW)'
  o_busSurplus_TP(*,*)               'Bus surplus generation (MW)'
  o_nodeGeneration_TP(*,*)           'Generation per node per time period for each input data set (MW)'
  o_nodeLoad_TP(*,*)                 'Load per node per time period for each input data set (MW)'
  o_nodePrice_TP(*,*)                'Price per node per time period for each input data set ($/MWh)'
  o_nodeRevenue_TP(*,*)              'Revenue per node per time period for each input data set ($)'
  o_nodeCost_TP(*,*)                 'Cost per node per time period for each input data set ($)'
  o_nodeDeficit_TP(*,*)              'Node deficit generation (MW)'
  o_nodeSurplus_TP(*,*)              'Node surplus generation (MW)'
  o_offerEnergy_TP(*,*)              'Energy per offer per time period for each input data set (MW)'
  o_offerFIR_TP(*,*)                 'FI reserves per offer per time period for each input data set (MW)'
  o_offerSIR_TP(*,*)                 'SI reserves per offer per time period for each input data set (MW)'
  o_FIRreqd_TP(*,*)                  'FIR required per island per time period for each input data set (MW)'
  o_SIRreqd_TP(*,*)                  'SIR required per island per time period for each input data set (MW)'
  o_FIRprice_TP(*,*)                 'FIR price per island per time period for each input data set ($/MW)'
  o_SIRprice_TP(*,*)                 'SIR price per island per time period for each input data set ($/MW)'
  o_FIRviolation_TP(*,*)             'FIR violation per island per time period for each input data set (MW)'
  o_SIRviolation_TP(*,*)             'SIR violation per island per time period for each input data set (MW)'
  o_branchFlow_TP(*,*)               'Flow on each branch per time period for each input data set (MW)'
  o_branchDynamicLoss_TP(*,*)        'Dynamic loss on each branch per time period for each input data set (MW)'
  o_branchFixedLoss_TP(*,*)          'Fixed loss on each branch per time period for each input data set (MW)'
  o_branchFromBusPrice_TP(*,*)       'Price on from bus for each branch per time period for each input data set ($/MW)'
  o_branchToBusPrice_TP(*,*)         'Price on to bus for each branch per time period for each input data set ($/MW)'
  o_branchMarginalPrice_TP(*,*)      'Marginal constraint price for each branch per time period for each input data set ($/MW)'
  o_branchTotalRentals_TP(*,*)       'Total loss and congestion rentals for each branch per time period for each input data set ($)'
  o_branchCapacity_TP(*,*)           'Branch capacity per time period for each input data set (MW)'
  o_brConstraintSense_TP(*,*)        'Branch constraint sense for each time period and each input data set'
  o_brConstraintLHS_TP(*,*)          'Branch constraint LHS for each time period and each input data set'
  o_brConstraintRHS_TP(*,*)          'Branch constraint RHS for each time period and each input data set'
  o_brConstraintPrice_TP(*,*)        'Branch constraint price for each time period and each input data set'
  o_MnodeConstraintSense_TP(*,*)     'Market node constraint sense for each time period and each input data set'
  o_MnodeConstraintLHS_TP(*,*)       'Market node constraint LHS for each time period and each input data set'
  o_MnodeConstraintRHS_TP(*,*)       'Market node constraint RHS for each time period and each input data set'
  o_MnodeConstraintPrice_TP(*,*)     'Market node constraint price for each time period and each input data set'

* Audit report parameters
  o_lossSegmentBreakPoint(*,*,*)     'MW capacity of each loss segment for audit'
  o_lossSegmentFactor(*,*,*)         'Loss factor of each loss segment for audit'
  o_ACbusAngle(*,*)                  'Bus voltage angle for audit reporting'
  o_nonPhysicalLoss(*,*)             'MW losses calculated manually from the solution for each loss branch'
  o_ILRO_FIR_TP(*,*)                 'Output IL offer FIR (MWh)'
  o_ILRO_SIR_TP(*,*)                 'Output IL offer SIR (MWh)'
  o_ILbus_FIR_TP(*,*)                'Output IL offer FIR (MWh)'
  o_ILbus_SIR_TP(*,*)                'Output IL offer SIR (MWh)'
  o_PLRO_FIR_TP(*,*)                 'Output PLSR offer FIR (MWh)'
  o_PLRO_SIR_TP(*,*)                 'Output PLSR SIR (MWh)'
  o_TWRO_FIR_TP(*,*)                 'Output TWR FIR (MWh)'
  o_TWRO_SIR_TP(*,*)                 'Output TWR SIR (MWh)'
  o_FIRcleared_TP(*,*)               'FIR cleared - for audit report'
  o_SIRcleared_TP(*,*)               'SIR cleared - for audit report'
  o_generationRiskSetter(*,*,*,*,*)  'i_DateTime,i_Island,i_Offer,i_ReserveClass,i_RiskClass'
  o_genHVDCRiskSetter(*,*,*,*,*)     'i_DateTime,i_Island,i_Offer,i_ReserveClass,i_RiskClass'
  o_HVDCriskSetter(*,*,*,*)          'i_DateTime,i_Island,i_ReserveClass,i_RiskClass'
  o_MANUriskSetter(*,*,*,*)          'i_DateTime,i_Island,i_ReserveClass,i_RiskClass'
  o_MANUHVDCriskSetter(*,*,*,*)      'i_DateTime,i_Island,i_ReserveClass,i_RiskClass'
  ;

* RDN - Introduce zero tolerance due to numerical rounding issues - when detecting the risk setter
Scalar zeroTolerance / 0.000001 / ;


*===================================================================================
* Load vSPD output from the GDX files where it was collected at vSPD solution time
*===================================================================================
* System level
$gdxin "%outputPath%\%runName%\runNum%vSPDrunNum%_SystemOutput.gdx"
$load o_FromDateTime o_NumTradePeriods o_systemOFV o_systemGen o_systemLoad o_systemLoss o_systemViolation o_systemFIR
$load o_systemSIR o_systemEnergyRevenue o_systemLoadCost o_systemLoadRevenue o_systemSurplus
$gdxin

* Offer level
$gdxin "%outputPath%\%runName%\runNum%vSPDrunNum%_OfferOutput.gdx"
$load i_Offer i_Trader o_offerTrader o_offerGen o_offerFIR o_offerSIR
$gdxin

* Trader level
$gdxin "%outputPath%\%runName%\runNum%vSPDrunNum%_TraderOutput.gdx"
$load o_trader o_traderGen o_traderFIR o_traderSIR
$gdxin

* Trading period level - need to do these at compile time rather than at execution time (as is case with parameters below)
$gdxin "%OutputPath%%runName%\RunNum%VSPDRunNum%_SummaryOutput_TP.gdx"
$load o_dateTime

$gdxin "%OutputPath%%runName%\RunNum%VSPDRunNum%_BusOutput_TP.gdx"
$load o_bus

$gdxin "%OutputPath%%runName%\RunNum%VSPDRunNum%_NodeOutput_TP.gdx"
$load o_node

$gdxin "%OutputPath%%runName%\RunNum%VSPDRunNum%_OfferOutput_TP.gdx"
$load o_offer

$gdxin "%OutputPath%%runName%\RunNum%VSPDRunNum%_ReserveOutput_TP.gdx"
$load o_island

$gdxin "%OutputPath%%runName%\RunNum%VSPDRunNum%_BranchOutput_TP.gdx"
$load o_branch o_branchFromBus_TP o_branchToBus_TP

$gdxin "%OutputPath%%runName%\RunNum%VSPDRunNum%_BrConstraintOutput_TP.gdx"
$load o_brConstraint_TP

$gdxin "%OutputPath%%runName%\RunNum%VSPDRunNum%_MNodeConstraintOutput_TP.gdx"
$load o_MNodeConstraint_TP
$gdxin

* Parameters in trading period and audit reporting GDX files are read at execution rather than compile time to avoid compile errors later on
* where conditional statements operate on on unassigned symbols
* Trade period reporting
if(tradePeriodReports = 1,
  execute_load "%outputPath%\%runName%\runNum%vSPDrunNum%_SummaryOutput_TP.gdx", o_solveOK_TP, o_systemCost_TP, o_DefGenViolation_TP
                 o_SurpGenViolation_TP, o_SurpBranchFlow_TP, o_DefRampRate_TP, o_SurpRampRate_TP, o_SurpBranchGroupConst_TP, o_DefBranchGroupConst_TP
                 o_DefMnodeConst_TP, o_SurpMnodeConst_TP, o_DefACNodeConst_TP, o_SurpACNodeConst_TP, o_DefT1MixedConst_TP, o_SurpT1MixedConst_TP
                 o_DefGenericConst_TP, o_SurpGenericConst_TP, o_DefResv_TP, o_totalViolation_TP
*RDN - 20130730 - Additional reporting on system objective function and penalty cost
                 o_ofv_TP, o_penaltyCost_TP

  execute_load "%outputPath%\%runName%\runNum%vSPDrunNum%_IslandOutput_TP.gdx", o_islandGen_TP, o_islandLoad_TP, o_islandBranchLoss_TP, o_HVDCFlow_TP
                 o_HVDCLoss_TP, o_islandRefPrice_TP, o_islandEnergyRevenue_TP, o_islandLoadCost_TP, o_islandLoadRevenue_TP

  execute_load "%outputPath%\%runName%\runNum%vSPDrunNum%_BusOutput_TP.gdx", o_busGeneration_TP, o_busLoad_TP, o_busPrice_TP, o_busRevenue_TP
                 o_busCost_TP, o_busDeficit_TP, o_busSurplus_TP

  execute_load "%outputPath%\%runName%\runNum%vSPDrunNum%_NodeOutput_TP.gdx", o_nodeGeneration_TP, o_nodeLoad_TP, o_nodePrice_TP, o_nodeRevenue_TP
                 o_nodeCost_TP, o_nodeDeficit_TP, o_nodeSurplus_TP

  execute_load "%outputPath%\%runName%\runNum%vSPDrunNum%_OfferOutput_TP.gdx", o_offerEnergy_TP, o_offerFIR_TP, o_offerSIR_TP

  execute_load "%outputPath%\%runName%\runNum%vSPDrunNum%_ReserveOutput_TP.gdx", o_FIRReqd_TP, o_SIRReqd_TP, o_FIRPrice_TP, o_SIRPrice_TP, o_FIRViolation_TP
                 o_SIRViolation_TP

  execute_load "%outputPath%\%runName%\runNum%vSPDrunNum%_BranchOutput_TP.gdx", o_branchFlow_TP, o_branchDynamicLoss_TP, o_branchFixedLoss_TP
                 o_branchFromBusPrice_TP, o_branchToBusPrice_TP, o_branchMarginalPrice_TP, o_branchTotalRentals_TP, o_branchCapacity_TP

  execute_load "%outputPath%\%runName%\runNum%vSPDrunNum%_BrConstraintOutput_TP.gdx", o_brConstraintSense_TP, o_brConstraintLHS_TP
                 o_brConstraintRHS_TP, o_brConstraintPrice_TP

  execute_load "%outputPath%\%runName%\runNum%vSPDrunNum%_MnodeConstraintOutput_TP.gdx", o_MnodeConstraintSense_TP, o_MnodeConstraintLHS_TP, o_MnodeConstraintRHS_TP
                 o_MnodeConstraintPrice_TP
) ;

* Audit reporting
* Read the audit results at compile time if audit GDX file exists
$if not exist "%outputPath%\%runName%\runNum%vSPDrunNum%_AuditOutput_TP.gdx" $goto noAudit1
$gdxin "%outputPath%\%runName%\runNum%vSPDrunNum%_AuditOutput_TP.gdx"
$load o_busIsland_TP, o_marketNodeIsland_TP o_ACBusAngle o_LossSegmentBreakPoint o_LossSegmentFactor o_NonPhysicalLoss
$load o_PLRO_FIR_TP o_PLRO_SIR_TP o_TWRO_FIR_TP o_TWRO_SIR_TP o_ILRO_FIR_TP o_ILRO_SIR_TP o_ILBus_FIR_TP o_ILBus_SIR_TP o_generationRiskSetter o_GenHVDCRiskSetter
$load o_HVDCRiskSetter o_MANURiskSetter o_MANUHVDCRiskSetter o_FIRCleared_TP o_SIRCleared_TP
$gdxin
$label noAudit1

*===================================================================================
* Declare output files (all CSVs) and set output file attributes
*===================================================================================
Files
  SystemResults             / "%outputPath%\%runName%\%runName%_SystemResults.csv" /
  OfferResults              / "%outputPath%\%runName%\%runName%_OfferResults.csv" /
  TraderResults             / "%outputPath%\%runName%\%runName%_TraderResults.csv" /
  SummaryResults_TP         / "%outputPath%\%runName%\%runName%_SummaryResults_TP.csv" /
  IslandResults_TP          / "%outputPath%\%runName%\%runName%_IslandResults_TP.csv" /
  BusResults_TP             / "%outputPath%\%runName%\%runName%_BusResults_TP.csv" /
  NodeResults_TP            / "%outputPath%\%runName%\%runName%_NodeResults_TP.csv" /
  OfferResults_TP           / "%outputPath%\%runName%\%runName%_OfferResults_TP.csv" /
  ReserveResults_TP         / "%outputPath%\%runName%\%runName%_ReserveResults_TP.csv" /
  BranchResults_TP          / "%outputPath%\%runName%\%runName%_BranchResults_TP.csv" /
  BrCnstrResults_TP         / "%outputPath%\%runName%\%runName%_BrConstraintResults_TP.csv" /
  MnodeCnstrResults_TP      / "%outputPath%\%runName%\%runName%_MnodeConstraintResults_TP.csv" /
* Data warehouse reports
  DWSummaryResults          / "%outputPath%\%runName%\%runName%_DWSummaryResults.csv" /
  DWEnergyResults           / "%outputPath%\%runName%\%runName%_DWEnergyResults.csv" /
  DWReserveResults          / "%outputPath%\%runName%\%runName%_DWReserveResults.csv" /
* Audit reports
  BranchLoss_Audit          / "%outputPath%\%runName%\%runName%_BranchLoss_Audit.csv" /
  BusResults_Audit          / "%outputPath%\%runName%\%runName%_BusResults_Audit.csv" /
  MarketNodeResults_Audit   / "%outputPath%\%runName%\%runName%_MarketNodeResults_Audit.csv" /
  BranchResults_Audit       / "%outputPath%\%runName%\%runName%_BranchResults_Audit.csv" /
  RiskResults_Audit         / "%outputPath%\%runName%\%runName%_RiskResults_Audit.csv" /
  objResults_Audit          / "%outputPath%\%runName%\%runName%_objResults_Audit.csv" /
  ;

* Set output file attributes
SystemResults.pc = 5 ;          SystemResults.lw = 0 ;          SystemResults.pw = 9999 ;              SystemResults.ap = 1 ;
OfferResults.pc = 5 ;           OfferResults.lw = 0 ;           OfferResults.pw = 9999 ;               OfferResults.ap = 1 ;
TraderResults.pc = 5 ;          TraderResults.lw = 0 ;          TraderResults.pw = 9999 ;              TraderResults.ap = 1 ;
SummaryResults_TP.pc = 5 ;      SummaryResults_TP.lw = 0 ;      SummaryResults_TP.pw = 9999 ;          SummaryResults_TP.ap = 1 ;
IslandResults_TP.pc = 5 ;       IslandResults_TP.lw = 0 ;       IslandResults_TP.pw = 9999 ;           IslandResults_TP.ap = 1 ;
BusResults_TP.pc = 5 ;          BusResults_TP.lw = 0 ;          BusResults_TP.pw = 9999 ;              BusResults_TP.ap = 1 ;
NodeResults_TP.pc = 5 ;         NodeResults_TP.lw = 0 ;         NodeResults_TP.pw = 9999 ;             NodeResults_TP.ap = 1 ;            NodeResults_TP.nd = 5 ;
OfferResults_TP.pc = 5 ;        OfferResults_TP.lw = 0 ;        OfferResults_TP.pw = 9999 ;            OfferResults_TP.ap = 1 ;
ReserveResults_TP.pc = 5 ;      ReserveResults_TP.lw = 0 ;      ReserveResults_TP.pw = 9999 ;          ReserveResults_TP.ap = 1 ;         ReserveResults_TP.nd = 5 ;
BranchResults_TP.pc = 5 ;       BranchResults_TP.lw = 0 ;       BranchResults_TP.pw = 9999 ;           BranchResults_TP.ap = 1 ;
BrCnstrResults_TP.pc = 5 ;      BrCnstrResults_TP.lw = 0 ;      BrCnstrResults_TP.pw = 9999 ;          BrCnstrResults_TP.ap = 1 ;
MnodeCnstrResults_TP.pc = 5 ;   MnodeCnstrResults_TP.lw = 0 ;   MnodeCnstrResults_TP.pw = 9999 ;       MnodeCnstrResults_TP.ap = 1 ;

* Data warehouse file attributes
DWSummaryResults.pc = 5 ;       DWSummaryResults.lw = 0 ;       DWSummaryResults.pw = 9999 ;           DWSummaryResults.ap = 1 ;          DWSummaryResults.nd = 5 ;
DWEnergyResults.pc = 5 ;        DWEnergyResults.lw = 0 ;        DWEnergyResults.pw = 9999 ;            DWEnergyResults.ap = 1 ;           DWEnergyResults.nd = 5 ;
DWReserveResults.pc = 5 ;       DWReserveResults.lw = 0 ;       DWReserveResults.pw = 9999 ;           DWReserveResults.ap = 1 ;          DWReserveResults.nd = 5 ;

* Audit file attributes
BranchLoss_Audit.pc = 5 ;       BranchLoss_Audit.lw = 0 ;       BranchLoss_Audit.pw = 9999 ;           BranchLoss_Audit.ap = 1 ;          BranchLoss_Audit.nd = 5 ;
BusResults_Audit.pc = 5 ;       BusResults_Audit.lw = 0 ;       BusResults_Audit.pw = 9999 ;           BusResults_Audit.ap = 1 ;          BusResults_Audit.nd = 5 ;
BranchResults_Audit.pc = 5 ;    BranchResults_Audit.lw = 0 ;    BranchResults_Audit.pw = 9999 ;        BranchResults_Audit.ap = 1 ;       BranchResults_Audit.nd = 5 ;
RiskResults_Audit.pc = 5 ;      RiskResults_Audit.lw = 0 ;      RiskResults_Audit.pw = 9999 ;          RiskResults_Audit.ap = 1 ;         RiskResults_Audit.nd = 5 ;
MarketNodeResults_Audit.pc = 5 ;MarketNodeResults_Audit.lw = 0 ;MarketNodeResults_Audit.pw = 9999 ;    MarketNodeResults_Audit.ap = 1 ;   MarketNodeResults_Audit.nd = 5 ;
objResults_Audit.pc = 5 ;       objResults_Audit.lw = 0 ;       objResults_Audit.pw = 9999 ;           objResults_Audit.ap = 1 ;          objResults_Audit.nd = 5 ;
objResults_Audit.nw = 20 ;



*===================================================================================
* Write vSPD results to the CSV report files
*===================================================================================

* If opMode is anything but 1 or -1, ie data warehouse or audit mode, write the following reports
if( (opMode <> 1) and (opMode <> -1 ),
* System level summary
  put SystemResults ;
  loop(dim2 $ o_FromDateTime(dim2),
    put dim2.tl, o_NumTradePeriods, o_systemOFV, o_systemGen, o_systemLoad, o_systemLoss, o_systemViolation
        o_systemFIR, o_systemSIR, o_systemEnergyRevenue, o_systemLoadCost, o_systemLoadRevenue, o_systemSurplus / ;
  ) ;

* Offer level summary
  put OfferResults ;
  loop((dim2,dim4,dim5) $ (o_FromDateTime(dim2) and i_Offer(dim4) and i_Trader(dim5) and o_offerTrader(dim4,dim5) and (o_offerGen(dim4) or o_offerFIR(dim4) or o_offerSIR(dim4))),
    put dim2.tl, o_NumTradePeriods, dim4.tl, dim5.tl, o_offerGen(dim4), o_offerFIR(dim4), o_offerSIR(dim4) / ;
  ) ;

* Trader level summary
  put TraderResults ;
  loop((dim2,dim4) $ (o_FromDateTime(dim2) and o_trader(dim4) and (o_traderGen(dim4) or o_traderFIR(dim4) or o_traderSIR(dim4))),
    put dim2.tl, o_NumTradePeriods, dim4.tl, o_traderGen(dim4), o_traderFIR(dim4), o_traderSIR(dim4) / ;
  ) ;

* In addition to the summary reports above, write out the trade period reports provided tradePeriodReports is set to 1
  if(tradePeriodReports = 1,

    put SummaryResults_TP ;
    loop(dim1 $ o_DateTime(dim1),
*RDN - 20130730 - Additional reporting on system objective function and penalty cost
*      put dim1.tl, o_solveOK_TP(dim1), o_systemCost_TP(dim1), o_DefGenViolation_TP(dim1), o_SurpGenViolation_TP(dim1), o_DefResv_TP(dim1), o_SurpBranchFlow_TP(dim1)
      put dim1.tl, o_solveOK_TP(dim1), o_ofv_TP(dim1), o_systemCost_TP(dim1), o_penaltyCost_TP(dim1), o_DefGenViolation_TP(dim1), o_SurpGenViolation_TP(dim1)
        o_DefResv_TP(dim1), o_SurpBranchFlow_TP(dim1), o_DefRampRate_TP(dim1), o_SurpRampRate_TP(dim1), o_SurpBranchGroupConst_TP(dim1), o_DefBranchGroupConst_TP(dim1)
        o_DefMnodeConst_TP(dim1), o_SurpMnodeConst_TP(dim1), o_DefACNodeConst_TP(dim1), o_SurpACNodeConst_TP(dim1), o_DefT1MixedConst_TP(dim1), o_SurpT1MixedConst_TP(dim1)
        o_DefGenericConst_TP(dim1), o_SurpGenericConst_TP(dim1) / ;
    ) ;

    put IslandResults_TP ;
    loop((dim1,dim2) $ (o_DateTime(dim1) and o_island(dim1,dim2)),
      put dim1.tl, dim2.tl, o_islandGen_TP(dim1,dim2), o_islandLoad_TP(dim1,dim2), o_islandBranchLoss_TP(dim1,dim2), o_HVDCFlow_TP(dim1,dim2), o_HVDCLoss_TP(dim1,dim2)
        o_islandRefPrice_TP(dim1,dim2), o_FIRReqd_TP(dim1,dim2), o_SIRReqd_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2)
        o_islandEnergyRevenue_TP(dim1,dim2), o_islandLoadCost_TP(dim1,dim2), o_islandLoadRevenue_TP(dim1,dim2) / ;
    ) ;

    put BusResults_TP ;
    loop((dim2,dim3) $ (o_DateTime(dim2) and o_bus(dim2,dim3)),
      put dim2.tl, dim3.tl, o_busGeneration_TP(dim2,dim3), o_busLoad_TP(dim2,dim3), o_busPrice_TP(dim2,dim3), o_busRevenue_TP(dim2,dim3), o_busCost_TP(dim2,dim3)
        o_busDeficit_TP(dim2,dim3), o_busSurplus_TP(dim2,dim3) / ;
    ) ;

    put NodeResults_TP ;
    loop((dim2,dim3) $ (o_DateTime(dim2) and o_node(dim2,dim3)),
      put dim2.tl, dim3.tl, o_nodeGeneration_TP(dim2,dim3), o_nodeLoad_TP(dim2,dim3), o_nodePrice_TP(dim2,dim3), o_nodeRevenue_TP(dim2,dim3), o_nodeCost_TP(dim2,dim3)
        o_nodeDeficit_TP(dim2,dim3), o_nodeSurplus_TP(dim2,dim3) / ;
    ) ;

    put OfferResults_TP ;
    loop((dim2,dim3) $ (o_DateTime(dim2) and o_offer(dim2,dim3)),
      put dim2.tl, dim3.tl, o_offerEnergy_TP(dim2,dim3), o_offerFIR_TP(dim2,dim3), o_offerSIR_TP(dim2,dim3) / ;
    ) ;

    put ReserveResults_TP ;
    loop((dim2,dim3) $ (o_DateTime(dim2) and o_island(dim2,dim3)),
      put dim2.tl, dim3.tl, o_FIRReqd_TP(dim2,dim3), o_SIRReqd_TP(dim2,dim3), o_FIRPrice_TP(dim2,dim3), o_SIRPrice_TP(dim2,dim3), o_FIRViolation_TP(dim2,dim3)
        o_SIRViolation_TP(dim2,dim3) / ;
    ) ;

    put BranchResults_TP ;
    loop((dim2,dim3,dim4,dim5) $ (o_DateTime(dim2) and o_branch(dim2,dim3) and o_branchFromBus_TP(dim2,dim3,dim4) and o_branchToBus_TP(dim2,dim3,dim5)),
      put dim2.tl, dim3.tl, dim4.tl, dim5.tl, o_branchFlow_TP(dim2,dim3), o_branchCapacity_TP(dim2,dim3), o_branchDynamicLoss_TP(dim2,dim3), o_branchFixedLoss_TP(dim2,dim3)
        o_branchFromBusPrice_TP(dim2,dim3), o_branchToBusPrice_TP(dim2,dim3), o_branchMarginalPrice_TP(dim2,dim3), o_branchTotalRentals_TP(dim2,dim3) / ;
    ) ;

    put BrCnstrResults_TP ;
    loop((dim2,dim3) $ (o_DateTime(dim2) and o_brConstraint_TP(dim2,dim3)),
      put dim2.tl, dim3.tl, o_brConstraintLHS_TP(dim2,dim3), o_brConstraintSense_TP(dim2,dim3), o_brConstraintRHS_TP(dim2,dim3), o_brConstraintPrice_TP(dim2,dim3) / ;
    ) ;

    put MnodeCnstrResults_TP ;
    loop((dim2,dim3) $ (o_DateTime(dim2) and o_MnodeConstraint_TP(dim2,dim3)),
      put dim2.tl, dim3.tl, o_MnodeConstraintLHS_TP(dim2,dim3), o_MnodeConstraintSense_TP(dim2,dim3), o_MnodeConstraintRHS_TP(dim2,dim3), o_MnodeConstraintPrice_TP(dim2,dim3) / ;
    ) ;

  ) ;

) ;

* Write out the data warehouse mode reports
if(opMode = 1,
  put DWSummaryResults ;
  loop(dim1 $ o_DateTime(dim1),
    put dim1.tl, o_solveOK_TP(dim1), o_systemCost_TP(dim1), o_totalViolation_TP(dim1) / ;
  ) ;

  put DWEnergyResults ;
  loop((dim2,dim3) $ (o_DateTime(dim2) and o_node(dim2,dim3)),
    put dim2.tl, dim3.tl, o_nodePrice_TP(dim2,dim3) / ;
  ) ;

  put DWReserveResults ;
  loop((dim2,dim3) $ (o_DateTime(dim2) and o_island(dim2,dim3)),
    put dim2.tl, dim3.tl, o_FIRPrice_TP(dim2,dim3), o_SIRPrice_TP(dim2,dim3) / ;
  ) ;

* End of data warehouse mode reporting loop
) ;

* Write out the audit mode reports
$if not exist "%outputPath%\%runName%\runNum%vSPDrunNum%_AuditOutput_TP.gdx" $goto noAudit2
if(opMode = -1,
  put BranchLoss_Audit ;
  loop((dim1,dim2) $ [o_DateTime(dim1) and o_branch(dim1,dim2)],
     put dim1.tl, dim2.tl ;
     loop(o_LossSegment $ o_LossSegmentBreakPoint(dim1,dim2,o_LossSegment),
        put o_LossSegmentBreakPoint(dim1,dim2,o_LossSegment), o_LossSegmentFactor(dim1,dim2,o_LossSegment) ;
     )  put / ;
  ) ;

  put BusResults_Audit ;
  loop((dim1,dim2,dim3) $ (o_DateTime(dim1) and o_bus(dim1,dim2) and o_busIsland_TP(dim1,dim2,dim3)),
     put dim1.tl, dim3.tl, dim2.tl, o_ACBusAngle(dim1,dim2), o_busPrice_TP(dim1,dim2), o_busLoad_TP(dim1,dim2), o_ILBus_FIR_TP(dim1,dim2)
         o_ILBus_SIR_TP(dim1,dim2) / ;
  ) ;

  put MarketNodeResults_Audit ;
  loop((dim1,dim2,dim3) $ (o_DateTime(dim1) and o_offer(dim1,dim2) and o_MarketNodeIsland_TP(dim1,dim2,dim3)),
     put dim1.tl, dim3.tl, dim2.tl, o_offerEnergy_TP(dim1,dim2), o_PLRO_FIR_TP(dim1,dim2), o_PLRO_SIR_TP(dim1,dim2), o_TWRO_FIR_TP(dim1,dim2)
         o_TWRO_SIR_TP(dim1,dim2) / ;
  ) ;

  put BranchResults_Audit ;
  loop((dim1,dim2) $ (o_DateTime(dim1) and o_branch(dim1,dim2)),
* RDN - Update branch loss reporting for Audit report - Start--------------------
    put dim1.tl, dim2.tl, o_branchFlow_TP(dim1,dim2), o_branchDynamicLoss_TP(dim1,dim2), o_branchFixedLoss_TP(dim1,dim2)
       (o_branchDynamicLoss_TP(dim1,dim2) + o_branchFixedLoss_TP(dim1,dim2)) ;
*   RDN - Update branch loss reporting for Audit report - End--------------------
    if([abs(o_branchCapacity_TP(dim1,dim2)-abs(o_branchFlow_TP(dim1,dim2))) <= ZeroTolerance],
      put 'Y' ;
      else
      put 'N' ;
    ) ;
    put o_branchMarginalPrice_TP(dim1,dim2) ;
    if(o_NonPhysicalLoss(dim1,dim2) > NonPhysicalLossTolerance,
      put 'Y' / ;
      else
      put 'N' / ;
    ) ;
  ) ;

* RDN - Revised risk results - Start --------------------------------------------
  put RiskResults_Audit ;
  loop((dim1,dim2,o_ReserveClass) $ (o_DateTime(dim1) and o_island(dim1,dim2)),
    loop(o_RiskClass,
      loop(dim3 $ o_offer(dim1,dim3),
*       if([ord(o_ReserveClass)=1] and [o_GenerationRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass) = o_FIRReqd_TP(dim1,dim2)] and [o_FIRReqd_TP(dim1,dim2) > 0],
        if([ord(o_ReserveClass)=1] and (abs[o_GenerationRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass)-o_FIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_FIRReqd_TP(dim1,dim2) > 0],
          put dim1.tl, dim2.tl, o_ReserveClass.tl, dim3.tl, o_RiskClass.tl, o_GenerationRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass), o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2) / ;
*         elseif [ord(o_ReserveClass)=2] and [o_GenerationRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass) = o_SIRReqd_TP(dim1,dim2)] and [o_SIRReqd_TP(dim1,dim2) > 0],
          elseif [ord(o_ReserveClass)=2] and (abs[o_GenerationRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass)-o_SIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_SIRReqd_TP(dim1,dim2) > 0],
            put dim1.tl, dim2.tl, o_ReserveClass.tl, dim3.tl, o_RiskClass.tl, o_GenerationRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass), o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2) / ;
        ) ;
      ) ;

      loop(dim3 $ o_offer(dim1,dim3),
*       if([ord(o_ReserveClass)=1] and [o_GenHVDCRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass) = o_FIRReqd_TP(dim1,dim2)] and [o_FIRReqd_TP(dim1,dim2) > 0],
        if([ord(o_ReserveClass)=1] and (abs[o_GenHVDCRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass)-o_FIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_FIRReqd_TP(dim1,dim2) > 0],
          put dim1.tl, dim2.tl, o_ReserveClass.tl, dim3.tl, o_RiskClass.tl, o_GenHVDCRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass), o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2) / ;
*           elseif [ord(o_ReserveClass)=2] and [o_GenHVDCRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass) = o_SIRReqd_TP(dim1,dim2)] and [o_SIRReqd_TP(dim1,dim2) > 0],
            elseif [ord(o_ReserveClass)=2] and (abs[o_GenHVDCRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass)-o_SIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_SIRReqd_TP(dim1,dim2) > 0],
              put dim1.tl, dim2.tl, o_ReserveClass.tl, dim3.tl, o_RiskClass.tl, o_GenHVDCRiskSetter(dim1,dim2,dim3,o_ReserveClass,o_RiskClass), o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2) / ;
        ) ;
      ) ;

*     if([ord(o_ReserveClass)=1] and [o_HVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass) = o_FIRReqd_TP(dim1,dim2)] and [o_FIRReqd_TP(dim1,dim2) > 0],
      if([ord(o_ReserveClass)=1] and (abs[o_HVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass)-o_FIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_FIRReqd_TP(dim1,dim2) > 0],
        put dim1.tl, dim2.tl, o_ReserveClass.tl, 'HVDC', o_RiskClass.tl, o_HVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass), o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2) / ;
*         elseif [ord(o_ReserveClass)=2] and [o_HVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass) = o_SIRReqd_TP(dim1,dim2)] and [o_SIRReqd_TP(dim1,dim2) > 0],
          elseif [ord(o_ReserveClass)=2] and (abs[o_HVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass)-o_SIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_SIRReqd_TP(dim1,dim2) > 0],
          put dim1.tl, dim2.tl, o_ReserveClass.tl, 'HVDC', o_RiskClass.tl, o_HVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass), o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2) / ;
      ) ;

*     if([ord(o_ReserveClass)=1] and [o_MANURiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass) = o_FIRReqd_TP(dim1,dim2)] and [o_FIRReqd_TP(dim1,dim2) > 0],
      if([ord(o_ReserveClass)=1] and (abs[o_MANURiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass)-o_FIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_FIRReqd_TP(dim1,dim2) > 0],
        put dim1.tl, dim2.tl, o_ReserveClass.tl, 'Manual', o_RiskClass.tl, o_MANURiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass), o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2) / ;
*         elseif [ord(o_ReserveClass)=2] and [o_MANURiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass) = o_SIRReqd_TP(dim1,dim2)] and [o_SIRReqd_TP(dim1,dim2) > 0],
          elseif [ord(o_ReserveClass)=2] and (abs[o_MANURiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass)-o_SIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_SIRReqd_TP(dim1,dim2) > 0],
          put dim1.tl, dim2.tl, o_ReserveClass.tl, 'Manual', o_RiskClass.tl, o_MANURiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass), o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2) / ;
      ) ;

*     if([ord(o_ReserveClass)=1] and [o_MANUHVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass) = o_FIRReqd_TP(dim1,dim2)] and [o_FIRReqd_TP(dim1,dim2) > 0],
      if([ord(o_ReserveClass)=1] and (abs[o_MANUHVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass)-o_FIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_FIRReqd_TP(dim1,dim2) > 0],
        put dim1.tl, dim2.tl, o_ReserveClass.tl, 'Manual', o_RiskClass.tl, o_MANUHVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass), o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2) / ;
*         elseif [ord(o_ReserveClass)=2] and [o_MANUHVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass) = o_SIRReqd_TP(dim1,dim2)] and [o_SIRReqd_TP(dim1,dim2) > 0],
          elseif [ord(o_ReserveClass)=2] and (abs[o_MANUHVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass)-o_SIRReqd_TP(dim1,dim2)] <= ZeroTolerance) and [o_SIRReqd_TP(dim1,dim2) > 0],
            put dim1.tl, dim2.tl, o_ReserveClass.tl, 'Manual', o_RiskClass.tl, o_MANUHVDCRiskSetter(dim1,dim2,o_ReserveClass,o_RiskClass), o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2) / ;
      ) ;
    ) ;

*   Ensure still reporting for conditions with zero FIR and/or SIR required
    if([ord(o_ReserveClass)=1] and [o_FIRReqd_TP(dim1,dim2) = 0],
      put dim1.tl, dim2.tl, o_ReserveClass.tl, ' ', ' ', ' ', o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2) / ;
        elseif [ord(o_ReserveClass)=2] and [o_SIRReqd_TP(dim1,dim2) = 0],
          put dim1.tl, dim2.tl, o_ReserveClass.tl, ' ', ' ', ' ', o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2) / ;
    ) ;
  ) ;
* RDN - Revised risk results - End ----------------------------------------------

  put objResults_Audit loop(dim1 $ o_DateTime(dim1), put dim1.tl, o_systemCost_TP(dim1) / ) ;

* End of audit mode reporting loop
) ;
$label noAudit2


* Go to the next input file
$ label nextInput
