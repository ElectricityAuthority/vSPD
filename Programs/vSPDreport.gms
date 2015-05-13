*=====================================================================================
* Name:                 vSPDreport.gms
* Function:             Creates the detailed reports
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     8 May 2015
*=====================================================================================


* Include some settings
$include vSPDpaths.inc 
$include vSPDsettings.inc
$include vSPDcase.inc

* Skip this program if FTR rental mode is on
$if %opMode%==2 $goto End

* If the input file does not exist then skip all of this program
$if not exist "%inputPath%\%vSPDinputData%.gdx" $goto End

$if not %opMode%==0 tradePeriodReports = 1;
if(tradePeriodReports <> 0, tradePeriodReports = 1 ) ;


File rep "Write a progess report"  /"ProgressReport.txt"/;
rep.lw = 0 ; rep.ap = 1 ;
* Update progress report file indicating that runvSPDreportSetup is started
putclose rep "vSPDreport started at: " system.date " " system.time /;


*===================================================================================
* Declare sets and parameters required for reporting
*===================================================================================
Sets
  o_fromDateTime(*)                   'From date time set for summary outputs'
  o_dateTime(*)                       'Date and time set for output'
  o_bus(*,*)                          'Set of buses for the different time period'
  o_offer(*,*)                        'Set of offers for the different time period'
* MODD modification
  o_bid(*,*)                          'Set of bids for the different summary outputs'
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
  o_riskClass                         'This is for audit report' / GENRISK, DCCE, DCECE, Manual
                                                                   GENRISK_ECE, Manual_ECE, HVDCSECRISK_CE, HVDCSECRISK_ECE /
  o_lossSegment                       'This is for audit report' / ls1*ls6 /
  o_busIsland_TP(*,*,*)               'Bus Island Mapping for audit report'
  o_marketNodeIsland_TP(*,*,*)        'Generation Offer Island Mapping for audit reporting'
  ;

Alias (*,dim1), (*,dim2), (*,dim3), (*,dim4), (*,dim5)
      (o_lossSegment, ls), (o_reserveClass, resC), (o_riskClass, risC) ;

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
  o_systemBenefit_TP(*)              'System benefit of cleared bids for summary report'
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
* Additional reporting on system objective function and penalty cost
  o_ofv_TP(*)                        'Objective function value for each time period'
  o_penaltyCost_TP(*)                'Penalty cost for each time period'

* Trading period level
  o_islandGen_TP(*,*)                'Island generation (MW) for each time period'
  o_islandLoad_TP(*,*)               'Island fixed load (MW) for each time period'
* MODD modification
  o_islandClrBid_TP(*,*)             'Island cleared MW bid for each time period'
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
* MODD modification
  o_bidTotalMW_TP(*,*)               'Total MW bidded for each energy bid for each trade period'
  o_bidEnergy_TP(*,*)                'Output MW cleared for each energy bid for each trade period'
  o_bidFIR_TP(*,*)                   'Output MW cleared for FIR for each trade period'
  o_bidSIR_TP(*,*)                   'Output MW cleared for SIR for each trade period'
* MODD modification end
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
  o_generationRiskLevel(*,*,*,*,*)  'i_DateTime,i_Island,i_Offer,i_ReserveClass,i_RiskClass'
  o_genHVDCRiskLevel(*,*,*,*,*)     'i_DateTime,i_Island,i_Offer,i_ReserveClass,i_RiskClass'
  o_HVDCriskLevel(*,*,*,*)          'i_DateTime,i_Island,i_ReserveClass,i_RiskClass'
  o_manuriskLevel(*,*,*,*)          'i_DateTime,i_Island,i_ReserveClass,i_RiskClass'
  o_manuHVDCriskLevel(*,*,*,*)      'i_DateTime,i_Island,i_ReserveClass,i_RiskClass'

* Scarcity pricing updates
  o_FIRvrMW_TP(*,*)                  'MW scheduled from virtual FIR resource'
  o_SIRvrMW_TP(*,*)                  'MW scheduled from virtual SIR resource'

  o_scarcityExists_TP(*,*)
  o_cptPassed_TP(*,*)
  o_avgPriorGWAP_TP(*,*)
  o_islandGWAPbefore_TP(*,*)
  o_islandGWAPafter_TP(*,*)
  o_scarcityGWAPbefore_TP(*,*)
  o_scarcityGWAPafter_TP(*,*)
  o_scarcityScalingFactor_TP(*,*)
  o_GWAPfloor_TP(*,*)
  o_GWAPceiling_TP(*,*)
  o_GWAPthreshold_TP(*,*)

  ;


* Load trading period datetime set
$gdxin "%outputPath%\%runName%\%vSPDinputData%_SummaryOutput_TP.gdx"
$load o_dateTime
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_BusOutput_TP.gdx"
$load o_bus
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_NodeOutput_TP.gdx"
$load o_node
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_OfferOutput_TP.gdx"
$load o_offer
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_bidOutput_TP.gdx"
$load o_bid
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_ReserveOutput_TP.gdx"
$load o_island
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_BranchOutput_TP.gdx"
$load o_branch o_branchFromBus_TP o_branchToBus_TP
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_BrConstraintOutput_TP.gdx"
$load o_brConstraint_TP
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_MNodeConstraintOutput_TP.gdx"
$load o_MNodeConstraint_TP
$gdxin

*===============================================================================
* Data warehouse reporting process
*===============================================================================
$if not %opMode% == 1 $goto DWReportingEnd

$gdxin "%outputPath%\%runName%\%vSPDinputData%_SummaryOutput_TP.gdx"
$load o_solveOK_TP o_systemCost_TP o_systemBenefit_TP o_totalViolation_TP

$gdxin "%outputPath%\%runName%\%vSPDinputData%_NodeOutput_TP.gdx"
$load o_nodePrice_TP

$gdxin "%outputPath%\%runName%\%vSPDinputData%_ReserveOutput_TP.gdx"
$load o_FIRPrice_TP, o_SIRPrice_TP

* Data warehouse summary result
File DWsummaryResults /"%outputPath%\%runName%\%runName%_DWSummaryResults.csv"/;
DWsummaryResults.pc = 5 ;
DWsummaryResults.lw = 0 ;
DWsummaryResults.pw = 9999 ;
DWSummaryResults.ap = 1 ;
DWSummaryResults.nd = 3 ;
put DWSummaryResults ;
loop( dim1 $ o_DateTime(dim1),
    o_systemCost_TP(dim1) = o_systemCost_TP(dim1) - o_systemBenefit_TP(dim1);
    put dim1.tl, o_solveOK_TP(dim1)
        o_systemCost_TP(dim1), o_totalViolation_TP(dim1) / ;
) ;

* Data warehouse energy result
File DWenergyResults  /"%outputPath%\%runName%\%runName%_DWEnergyResults.csv"/;
DWenergyResults.pc = 5 ;
DWenergyResults.lw = 0 ;
DWenergyResults.pw = 9999 ;
DWEnergyResults.ap = 1 ;
DWEnergyResults.nd = 3 ;
put DWEnergyResults ;
loop( (dim1,dim2) $ { o_DateTime(dim1) and o_node(dim1,dim2) },
    put dim1.tl, dim2.tl, o_nodePrice_TP(dim1,dim2) / ;
) ;

* Data warehouse reserve result
File DWreserveResults /"%outputPath%\%runName%\%runName%_DWReserveResults.csv"/;
DWreserveResults.pc = 5 ;
DWreserveResults.lw = 0 ;
DWreserveResults.pw = 9999 ;
DWreserveResults.ap = 1 ;
DWreserveResults.nd = 3 ;
put DWReserveResults ;
loop( (dim1,dim2) $ { o_DateTime(dim1) and o_island(dim1,dim2) },
    put dim1.tl, dim2.tl, o_FIRPrice_TP(dim1,dim2), o_SIRPrice_TP(dim1,dim2) / ;
) ;

$goto End
$label DWReportingEnd
*===============================================================================




*===============================================================================
* Normal vSPD reporting process
*===============================================================================

* System level
$gdxin "%outputPath%\%runName%\%vSPDinputData%_SystemOutput.gdx"
$load o_FromDateTime o_NumTradePeriods o_systemOFV o_systemGen
$load o_systemLoad o_systemLoss o_systemViolation o_systemFIR
$load o_systemSIR o_systemEnergyRevenue o_systemLoadCost
$load o_systemLoadRevenue o_systemSurplus
$gdxin

* Offer level
$gdxin "%outputPath%\%runName%\%vSPDinputData%_OfferOutput.gdx"
$load i_Offer i_Trader o_offerTrader o_offerGen o_offerFIR o_offerSIR
$gdxin

* Trader level
$gdxin "%outputPath%\%runName%\%vSPDinputData%_TraderOutput.gdx"
$load o_trader o_traderGen o_traderFIR o_traderSIR
$gdxin

* System level summary
File SystemResults    / "%outputPath%\%runName%\%runName%_SystemResults.csv" / ;
SystemResults.pc = 5 ;
SystemResults.lw = 0 ;
SystemResults.pw = 9999 ;
SystemResults.ap = 1 ;
put SystemResults ;
loop( dim2 $ o_FromDateTime(dim2),
    put dim2.tl, o_NumTradePeriods, o_systemOFV, o_systemGen, o_systemLoad,
        o_systemLoss, o_systemViolation, o_systemFIR, o_systemSIR
        o_systemEnergyRevenue, o_systemLoadCost, o_systemLoadRevenue
        o_systemSurplus / ;
) ;

* Offer level summary
File  OfferResults     / "%outputPath%\%runName%\%runName%_OfferResults.csv" / ;
OfferResults.pc = 5 ;
OfferResults.lw = 0 ;
OfferResults.pw = 9999 ;
OfferResults.ap = 1 ;
put OfferResults ;
loop( (dim2,dim4,dim5)
    $ { o_FromDateTime(dim2) and i_Offer(dim4) and
        i_Trader(dim5) and o_offerTrader(dim4,dim5) and
        [ o_offerGen(dim4) or o_offerFIR(dim4) or o_offerSIR(dim4) ]
      },
    put dim2.tl, o_NumTradePeriods, dim4.tl, dim5.tl
        o_offerGen(dim4), o_offerFIR(dim4), o_offerSIR(dim4) / ;
) ;

* Trader level summary
File  TraderResults   / "%outputPath%\%runName%\%runName%_TraderResults.csv" / ;
TraderResults.pc = 5 ;
TraderResults.lw = 0 ;
TraderResults.pw = 9999 ;
TraderResults.ap = 1 ;
put TraderResults ;
loop( (dim2,dim4)
    $ { o_FromDateTime(dim2) and o_trader(dim4) and
        [ o_traderGen(dim4) or o_traderFIR(dim4) or o_traderSIR(dim4) ]
      },
    put dim2.tl, o_NumTradePeriods, dim4.tl
        o_traderGen(dim4), o_traderFIR(dim4), o_traderSIR(dim4) / ;
) ;


* Trading period level report
$if not exist "%outputPath%\%runName%\%runName%_BusResults_TP.csv" $goto SkipTP

$gdxin "%outputPath%\%runName%\%vSPDinputData%_SummaryOutput_TP.gdx"
$load o_solveOK_TP o_systemCost_TP o_systemBenefit_TP
$load o_DefGenViolation_TP o_SurpGenViolation_TP
$load o_SurpBranchFlow_TP o_DefRampRate_TP o_SurpRampRate_TP o_ofv_TP
$load o_SurpBranchGroupConst_TP o_DefBranchGroupConst_TP o_DefMnodeConst_TP
$load o_SurpMnodeConst_TP o_DefACNodeConst_TP o_SurpACNodeConst_TP
$load o_DefT1MixedConst_TP o_SurpT1MixedConst_TP o_DefGenericConst_TP
$load o_SurpGenericConst_TP o_DefResv_TP o_totalViolation_TP o_penaltyCost_TP
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_IslandOutput_TP.gdx"
$load o_islandGen_TP o_islandLoad_TP o_islandClrBid_TP o_islandBranchLoss_TP
$load o_HVDCFlow_TP o_HVDCLoss_TP o_islandRefPrice_TP o_islandEnergyRevenue_TP
$load o_islandLoadCost_TP o_islandLoadRevenue_TP
$load o_scarcityExists_TP o_cptPassed_TP o_avgPriorGWAP_TP
$load o_islandGWAPbefore_TP o_islandGWAPafter_TP o_scarcityGWAPbefore_TP
$load o_scarcityGWAPafter_TP o_scarcityScalingFactor_TP
$load o_GWAPfloor_TP o_GWAPceiling_TP o_GWAPthreshold_TP
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_BusOutput_TP.gdx"
$load o_busGeneration_TP o_busLoad_TP o_busPrice_TP o_busRevenue_TP
$load o_busCost_TP o_busDeficit_TP o_busSurplus_TP

$gdxin "%outputPath%\%runName%\%vSPDinputData%_NodeOutput_TP.gdx"
$load o_nodeGeneration_TP o_nodeLoad_TP o_nodePrice_TP o_nodeRevenue_TP
$load o_nodeCost_TP o_nodeDeficit_TP o_nodeSurplus_TP
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_OfferOutput_TP.gdx"
$load  o_offerEnergy_TP o_offerFIR_TP o_offerSIR_TP
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_BidOutput_TP.gdx"
$load o_bidTotalMW_TP o_BidEnergy_TP o_bidFIR_TP o_bidSIR_TP
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_ReserveOutput_TP.gdx"
$load o_FIRReqd_TP o_SIRReqd_TP o_FIRPrice_TP o_SIRPrice_TP
$load o_FIRViolation_TP o_SIRViolation_TP o_FIRvrMW_TP o_SIRvrMW_TP
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_BranchOutput_TP.gdx"
$load o_branchFlow_TP o_branchDynamicLoss_TP o_branchFixedLoss_TP
$load o_branchFromBusPrice_TP o_branchToBusPrice_TP o_branchMarginalPrice_TP
$load o_branchTotalRentals_TP o_branchCapacity_TP
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_BrConstraintOutput_TP.gdx"
$load o_brConstraintSense_TP o_brConstraintLHS_TP
$load o_brConstraintRHS_TP o_brConstraintPrice_TP
$gdxin

$gdxin "%outputPath%\%runName%\%vSPDinputData%_MnodeConstraintOutput_TP.gdx"
$load o_MnodeConstraintSense_TP o_MnodeConstraintLHS_TP
$load o_MnodeConstraintRHS_TP o_MnodeConstraintPrice_TP
$gdxin


* Trading period summary result
File
SummaryResults_TP / "%outputPath%\%runName%\%runName%_SummaryResults_TP.csv" / ;
SummaryResults_TP.pc = 5 ;
SummaryResults_TP.lw = 0 ;
SummaryResults_TP.pw = 9999 ;
SummaryResults_TP.ap = 1 ;
put SummaryResults_TP ;
loop( dim1 $ o_DateTime(dim1),
    put dim1.tl, o_solveOK_TP(dim1), o_ofv_TP(dim1)
        o_systemCost_TP(dim1), o_systemBenefit_TP(dim1)
        o_penaltyCost_TP(dim1), o_DefGenViolation_TP(dim1)
        o_SurpGenViolation_TP(dim1),o_DefResv_TP(dim1),o_SurpBranchFlow_TP(dim1)
        o_DefRampRate_TP(dim1), o_SurpRampRate_TP(dim1)
        o_DefBranchGroupConst_TP(dim1), o_SurpBranchGroupConst_TP(dim1)
        o_DefMnodeConst_TP(dim1), o_SurpMnodeConst_TP(dim1)
        o_DefACNodeConst_TP(dim1), o_SurpACNodeConst_TP(dim1)
        o_DefT1MixedConst_TP(dim1), o_SurpT1MixedConst_TP(dim1)
        o_DefGenericConst_TP(dim1), o_SurpGenericConst_TP(dim1) / ;
) ;

* Trading period island result
File IslandResults_TP /"%outputPath%\%runName%\%runName%_IslandResults_TP.csv"/;
IslandResults_TP.pc = 5 ;
IslandResults_TP.lw = 0 ;
IslandResults_TP.pw = 9999 ;
IslandResults_TP.ap = 1 ;
IslandResults_TP.nd = 3 ;
put IslandResults_TP ;
loop( (dim1,dim2) $ { o_DateTime(dim1) and o_island(dim1,dim2) },
    put dim1.tl, dim2.tl, o_islandGen_TP(dim1,dim2), o_islandLoad_TP(dim1,dim2)
        o_islandClrBid_TP(dim1,dim2), o_islandBranchLoss_TP(dim1,dim2)
        o_HVDCFlow_TP(dim1,dim2), o_HVDCLoss_TP(dim1,dim2)
        o_islandRefPrice_TP(dim1,dim2), o_FIRReqd_TP(dim1,dim2)
        o_SIRReqd_TP(dim1,dim2), o_FIRPrice_TP(dim1,dim2)
        o_SIRPrice_TP(dim1,dim2), o_islandEnergyRevenue_TP(dim1,dim2)
        o_islandLoadCost_TP(dim1,dim2), o_islandLoadRevenue_TP(dim1,dim2)
        o_scarcityExists_TP(dim1,dim2), o_cptPassed_TP(dim1,dim2)
        o_avgPriorGWAP_TP(dim1,dim2), o_islandGWAPbefore_TP(dim1,dim2)
        o_islandGWAPafter_TP(dim1,dim2), o_scarcityGWAPbefore_TP(dim1,dim2)
        o_scarcityGWAPafter_TP(dim1,dim2), o_scarcityScalingFactor_TP(dim1,dim2)
        o_GWAPthreshold_TP(dim1,dim2), o_GWAPfloor_TP(dim1,dim2)
        o_GWAPceiling_TP(dim1,dim2) / ;
) ;

* Trading period bus result
File BusResults_TP   / "%outputPath%\%runName%\%runName%_BusResults_TP.csv" / ;
BusResults_TP.pc = 5 ;
BusResults_TP.lw = 0 ;
BusResults_TP.pw = 9999 ;
BusResults_TP.ap = 1 ;
BusResults_TP.nd = 5
put BusResults_TP ;
loop( (dim2,dim3) $ { o_DateTime(dim2) and o_bus(dim2,dim3) },
    put dim2.tl, dim3.tl, o_busGeneration_TP(dim2,dim3), o_busLoad_TP(dim2,dim3)
        o_busPrice_TP(dim2,dim3), o_busRevenue_TP(dim2,dim3)
        o_busCost_TP(dim2,dim3), o_busDeficit_TP(dim2,dim3)
        o_busSurplus_TP(dim2,dim3) / ;
) ;

* Trading period node result
File NodeResults_TP  /"%outputPath%\%runName%\%runName%_NodeResults_TP.csv" / ;
NodeResults_TP.pc = 5 ;
NodeResults_TP.lw = 0 ;
NodeResults_TP.pw = 9999 ;
NodeResults_TP.ap = 1 ;
NodeResults_TP.nd = 5 ;
put NodeResults_TP ;
loop( (dim2,dim3) $ { o_DateTime(dim2) and o_node(dim2,dim3) },
    put dim2.tl, dim3.tl, o_nodeGeneration_TP(dim2,dim3)
        o_nodeLoad_TP(dim2,dim3), o_nodePrice_TP(dim2,dim3)
        o_nodeRevenue_TP(dim2,dim3), o_nodeCost_TP(dim2,dim3)
        o_nodeDeficit_TP(dim2,dim3), o_nodeSurplus_TP(dim2,dim3) / ;
) ;

* Trading period offer result
File OfferResults_TP  /"%outputPath%\%runName%\%runName%_OfferResults_TP.csv"/ ;
OfferResults_TP.pc = 5 ;
OfferResults_TP.lw = 0 ;
OfferResults_TP.pw = 9999 ;
OfferResults_TP.ap = 1 ;
OfferResults_TP.nd = 3 ;
put OfferResults_TP ;
loop( (dim2,dim3) $ { o_DateTime(dim2) and o_offer(dim2,dim3) },
    put dim2.tl, dim3.tl, o_offerEnergy_TP(dim2,dim3)
        o_offerFIR_TP(dim2,dim3), o_offerSIR_TP(dim2,dim3) / ;
) ;

* Trading period bid result
File BidResults_TP    / "%outputPath%\%runName%\%runName%_BidResults_TP.csv" / ;
BidResults_TP.pc = 5 ;
BidResults_TP.lw = 0 ;
BidResults_TP.pw = 9999 ;
BidResults_TP.ap = 1 ;
BidResults_TP.nd = 3 ;
put BidResults_TP ;
loop( (dim2,dim3) $ { o_DateTime(dim2) and o_bid(dim2,dim3) },
    put dim2.tl, dim3.tl, o_bidTotalMW_TP(dim2,dim3), o_bidEnergy_TP(dim2,dim3)
    o_bidFIR_TP(dim2,dim3), o_bidSIR_TP(dim2,dim3) / ;
) ;

* Trading period reserve result
File
ReserveResults_TP /"%outputPath%\%runName%\%runName%_ReserveResults_TP.csv" / ;
ReserveResults_TP.pc = 5 ;
ReserveResults_TP.lw = 0 ;
ReserveResults_TP.pw = 9999 ;
ReserveResults_TP.ap = 1 ;
ReserveResults_TP.nd = 3 ;
put ReserveResults_TP ;
loop( (dim2,dim3) $ { o_DateTime(dim2) and o_island(dim2,dim3) },
    put dim2.tl, dim3.tl, o_FIRReqd_TP(dim2,dim3), o_SIRReqd_TP(dim2,dim3)
        o_FIRPrice_TP(dim2,dim3), o_SIRPrice_TP(dim2,dim3)
        o_FIRViolation_TP(dim2,dim3), o_SIRViolation_TP(dim2,dim3)
        o_FIRvrMW_TP(dim2,dim3), o_SIRvrMW_TP(dim2,dim3) / ;
) ;

* Trading period branch result
File
BranchResults_TP  / "%outputPath%\%runName%\%runName%_BranchResults_TP.csv" / ;
BranchResults_TP.pc = 5 ;
BranchResults_TP.lw = 0 ;
BranchResults_TP.pw = 9999 ;
BranchResults_TP.ap = 1 ;
BranchResults_TP.nd = 5 ;
put BranchResults_TP ;
loop( (dim2,dim3,dim4,dim5)
    $ { o_DateTime(dim2) and o_branchToBus_TP(dim2,dim3,dim5) and
        o_branchFromBus_TP(dim2,dim3,dim4) and o_branch(dim2,dim3)
      },
    put dim2.tl, dim3.tl, dim4.tl, dim5.tl, o_branchFlow_TP(dim2,dim3)
        o_branchCapacity_TP(dim2,dim3), o_branchDynamicLoss_TP(dim2,dim3)
        o_branchFixedLoss_TP(dim2,dim3), o_branchFromBusPrice_TP(dim2,dim3)
        o_branchToBusPrice_TP(dim2,dim3), o_branchMarginalPrice_TP(dim2,dim3)
        o_branchTotalRentals_TP(dim2,dim3) / ;
) ;

* Trading period branch constraint result
File BrCstrResults_TP
/ "%outputPath%\%runName%\%runName%_BrConstraintResults_TP.csv" / ;
BrCstrResults_TP.pc = 5 ;
BrCstrResults_TP.lw = 0 ;
BrCstrResults_TP.pw = 9999 ;
BrCstrResults_TP.ap = 1 ;
BrCstrResults_TP.nd = 5 ;
put BrCstrResults_TP ;
loop( (dim2,dim3) $ { o_DateTime(dim2) and o_brConstraint_TP(dim2,dim3) },
    put dim2.tl, dim3.tl, o_brConstraintLHS_TP(dim2,dim3)
        o_brConstraintSense_TP(dim2,dim3), o_brConstraintRHS_TP(dim2,dim3)
        o_brConstraintPrice_TP(dim2,dim3) / ;
) ;

* Trading period market node constraint result
File MnodeCstrResults_TP
/ "%outputPath%\%runName%\%runName%_MnodeConstraintResults_TP.csv" / ;
MnodeCstrResults_TP.pc = 5 ;
MnodeCstrResults_TP.lw = 0 ;
MnodeCstrResults_TP.pw = 9999 ;
MnodeCstrResults_TP.ap = 1 ;
MnodeCstrResults_TP.nd = 5 ;
put MnodeCstrResults_TP ;
loop( (dim2,dim3) $ { o_DateTime(dim2) and o_MnodeConstraint_TP(dim2,dim3) },
    put dim2.tl, dim3.tl, o_MnodeConstraintLHS_TP(dim2,dim3)
        o_MnodeConstraintSense_TP(dim2,dim3), o_MnodeConstraintRHS_TP(dim2,dim3)
        o_MnodeConstraintPrice_TP(dim2,dim3) / ;
) ;

$label SkipTP
*===============================================================================



*===============================================================================
* Audit mode reporting process
*===============================================================================
$if not %opMode% == -1 $goto AuditReportingEnd

* Introduce zero tolerance to detect risk setter due to rounding issues
Scalar zeroTolerance / 0.000001 / ;

$gdxin "%outputPath%\%runName%\%vSPDinputData%_AuditOutput_TP.gdx"
$load o_busIsland_TP o_marketNodeIsland_TP o_ACBusAngle
$load o_LossSegmentBreakPoint o_LossSegmentFactor o_NonPhysicalLoss
$load o_PLRO_FIR_TP o_PLRO_SIR_TP o_TWRO_FIR_TP o_TWRO_SIR_TP
$load o_ILRO_FIR_TP o_ILRO_SIR_TP o_ILBus_FIR_TP o_ILBus_SIR_TP
$load o_generationRiskLevel o_GenHVDCRiskLevel o_HVDCRiskLevel
$load o_manuRiskLevel o_manuHVDCRiskLevel o_FIRCleared_TP o_SIRCleared_TP
$gdxin


* Audit - branch loss result
File branchLoss_Audit /"%outputPath%\%runName%\%runName%_BranchLoss_Audit.csv"/;
branchLoss_Audit.pc = 5 ;
branchLoss_Audit.lw = 0 ;
branchLoss_Audit.pw = 9999 ;
BranchLoss_Audit.ap = 1 ;
BranchLoss_Audit.nd = 9 ;
put BranchLoss_Audit ;
loop( (dim1,dim2) $ { o_DateTime(dim1) and o_branch(dim1,dim2) },
    put dim1.tl, dim2.tl ;
    loop(ls $ o_LossSegmentBreakPoint(dim1,dim2,ls),
        put o_LossSegmentBreakPoint(dim1,dim2,ls)
            o_LossSegmentFactor(dim1,dim2,ls) ;
    )
    put / ;
) ;

* Audit - bus result
File busResults_Audit /"%outputPath%\%runName%\%runName%_BusResults_Audit.csv"/;
busResults_Audit.pc = 5 ;
busResults_Audit.lw = 0 ;
busResults_Audit.pw = 9999 ;
BusResults_Audit.ap = 1 ;
BusResults_Audit.nd = 5 ;
put busResults_Audit 'DateTime', 'Island', 'Bus', 'Angle'
    'Price', 'Load', 'Cleared ILRO 6s', 'Cleared ILRO 60s' ;

put BusResults_Audit ;
loop( (dim1,dim2,dim3) $ { o_DateTime(dim1) and o_bus(dim1,dim2) and
                           o_busIsland_TP(dim1,dim2,dim3) },
    put dim1.tl, dim3.tl, dim2.tl, o_ACBusAngle(dim1,dim2)
        o_busPrice_TP(dim1,dim2), o_busLoad_TP(dim1,dim2)
        o_ILBus_FIR_TP(dim1,dim2), o_ILBus_SIR_TP(dim1,dim2) / ;
) ;

* Audit - market node result
File
MNodeResults_Audit  /"%outputPath%\%runName%\%runName%_MNodeResults_Audit.csv"/;
MNodeResults_Audit.pc = 5 ;
MNodeResults_Audit.lw = 0 ;
MNodeResults_Audit.pw = 9999 ;
MNodeResults_Audit.ap = 1 ;
MNodeResults_Audit.nd = 5 ;
put MNodeResults_Audit ;
loop( (dim1,dim2,dim3) $ { o_DateTime(dim1) and o_offer(dim1,dim2) and
                           o_MarketNodeIsland_TP(dim1,dim2,dim3) },
    put dim1.tl, dim3.tl, dim2.tl, o_offerEnergy_TP(dim1,dim2)
        o_PLRO_FIR_TP(dim1,dim2), o_PLRO_SIR_TP(dim1,dim2)
        o_TWRO_FIR_TP(dim1,dim2), o_TWRO_SIR_TP(dim1,dim2) / ;
) ;

* Audit - branch result
File
brchResults_Audit  /"%outputPath%\%runName%\%runName%_BranchResults_Audit.csv"/;
brchResults_Audit.pc = 5 ;
brchResults_Audit.lw = 0 ;
brchResults_Audit.pw = 9999 ;
brchResults_Audit.ap = 1 ;
brchResults_Audit.nd = 9 ;
put brchResults_Audit ;
loop( (dim1,dim2) $ { o_DateTime(dim1) and o_branch(dim1,dim2) },
    put dim1.tl, dim2.tl, o_branchFlow_TP(dim1,dim2)
        o_branchDynamicLoss_TP(dim1,dim2), o_branchFixedLoss_TP(dim1,dim2)
        [o_branchDynamicLoss_TP(dim1,dim2) + o_branchFixedLoss_TP(dim1,dim2)] ;

    if( abs[ o_branchCapacity_TP(dim1,dim2)
           - abs(o_branchFlow_TP(dim1,dim2)) ] <= ZeroTolerance,
        put 'Y' ;
    else
        put 'N' ;
    ) ;

    put o_branchMarginalPrice_TP(dim1,dim2) ;

    if( o_NonPhysicalLoss(dim1,dim2) > NonPhysicalLossTolerance,
        put 'Y' / ;
    else
        put 'N' / ;
    ) ;
) ;

* Audit - risk result
File
riskResults_Audit    /"%outputPath%\%runName%\%runName%_RiskResults_Audit.csv"/;
riskResults_Audit.pc = 5 ;
riskResults_Audit.lw = 0 ;
riskResults_Audit.pw = 9999 ;
RiskResults_Audit.ap = 1 ;
RiskResults_Audit.nd = 5 ;
put RiskResults_Audit ;
loop( (dim1,dim2,resC) $ { o_DateTime(dim1) and o_island(dim1,dim2) },
    loop( risC,
        loop( dim3 $ o_offer(dim1,dim3),
            if( ( ord(resC)=1 ) and
                ( o_FIRReqd_TP(dim1,dim2) > 0 ) and
                ( abs[ o_GenerationRiskLevel(dim1,dim2,dim3,resC,risC)
                     - o_FIRReqd_TP(dim1,dim2)
                     ] <= ZeroTolerance
                ),
                put dim1.tl, dim2.tl, resC.tl, dim3.tl, risC.tl
                    o_GenerationRiskLevel(dim1,dim2,dim3,resC,risC)
                    o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2)
                    o_FIRPrice_TP(dim1,dim2), o_FIRvrMW_TP(dim1,dim2) / ;
            elseif ( ord(resC)=2 ) and
                   ( o_SIRReqd_TP(dim1,dim2) > 0 ) and
                   ( abs[ o_GenerationRiskLevel(dim1,dim2,dim3,resC,risC)
                        - o_SIRReqd_TP(dim1,dim2)
                        ] <= ZeroTolerance
                   ) ,
                put dim1.tl, dim2.tl, resC.tl, dim3.tl, risC.tl
                    o_GenerationRiskLevel(dim1,dim2,dim3,resC,risC)
                    o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2)
                    o_SIRPrice_TP(dim1,dim2), o_SIRvrMW_TP(dim1,dim2) / ;
            ) ;
        ) ;

        loop( dim3 $ o_offer(dim1,dim3),
            if( ( ord(resC)=1 ) and
                ( o_FIRReqd_TP(dim1,dim2) > 0 ) and
                ( abs[ o_GenHVDCRiskLevel(dim1,dim2,dim3,resC,risC)
                     - o_FIRReqd_TP(dim1,dim2)
                     ] <= ZeroTolerance
                ),
                put dim1.tl, dim2.tl, resC.tl, dim3.tl, risC.tl
                    o_GenHVDCRiskLevel(dim1,dim2,dim3, resC,risC)
                    o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2)
                    o_FIRPrice_TP(dim1,dim2), o_FIRvrMW_TP(dim1,dim2) / ;
            elseif ( ord(resC)=2 ) and
                   ( o_SIRReqd_TP(dim1,dim2) > 0 ) and
                   ( abs[ o_GenHVDCRiskLevel(dim1,dim2,dim3,resC,risC)
                        - o_SIRReqd_TP(dim1,dim2)
                        ] <= ZeroTolerance
                   ),
                put dim1.tl, dim2.tl, resC.tl, dim3.tl, risC.tl
                    o_GenHVDCRiskLevel(dim1,dim2,dim3,resC,risC)
                    o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2)
                    o_SIRPrice_TP(dim1,dim2), o_SIRvrMW_TP(dim1,dim2) / ;
            ) ;
        ) ;

        if( ( ord(resC)=1 ) and
            ( o_FIRReqd_TP(dim1,dim2) > 0 ) and
            ( abs[ o_HVDCRiskLevel(dim1,dim2,resC,risC)
                 - o_FIRReqd_TP(dim1,dim2)
                 ] <= ZeroTolerance
            ),
            put dim1.tl, dim2.tl, resC.tl, 'HVDC', risC.tl
                o_HVDCRiskLevel(dim1,dim2,resC,risC)
                o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2)
                o_FIRPrice_TP(dim1,dim2), o_FIRvrMW_TP(dim1,dim2) / ;
        elseif ( ord(resC)=2 ) and
               ( o_SIRReqd_TP(dim1,dim2) > 0 ) and
               ( abs[ o_HVDCRiskLevel(dim1,dim2,resC,risC)
                    - o_SIRReqd_TP(dim1,dim2)
                    ] <= ZeroTolerance
               ),
            put dim1.tl, dim2.tl, resC.tl, 'HVDC', risC.tl
                o_HVDCRiskLevel(dim1,dim2,resC,risC)
                o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2)
                o_SIRPrice_TP(dim1,dim2), o_SIRvrMW_TP(dim1,dim2) / ;
        ) ;

        if( ( ord(resC)=1 ) and
            ( o_FIRReqd_TP(dim1,dim2) > 0 ) and
            ( abs[ o_manuRiskLevel(dim1,dim2,resC,risC)
                 - o_FIRReqd_TP(dim1,dim2)
                 ] <= ZeroTolerance
            ),
            put dim1.tl, dim2.tl, resC.tl, 'Manual', risC.tl
                o_manuRiskLevel(dim1,dim2,resC,risC)
                o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2)
                o_FIRPrice_TP(dim1,dim2), o_FIRvrMW_TP(dim1,dim2) / ;
        elseif ( ord(resC)=2 ) and
               ( o_SIRReqd_TP(dim1,dim2) > 0 ) and
               ( abs[ o_manuRiskLevel(dim1,dim2,resC,risC)
                    - o_SIRReqd_TP(dim1,dim2)
                    ] <= ZeroTolerance
               ),
            put dim1.tl, dim2.tl, resC.tl, 'Manual', risC.tl
                o_manuRiskLevel(dim1,dim2,resC,risC)
                o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2)
                o_SIRPrice_TP(dim1,dim2), o_SIRvrMW_TP(dim1,dim2) / ;
        ) ;

        if( ( ord(resC)=1 ) and
            ( o_FIRReqd_TP(dim1,dim2) > 0 ) and
            ( abs[ o_manuHVDCRiskLevel(dim1,dim2,resC,risC)
                 - o_FIRReqd_TP(dim1,dim2)
                 ] <= ZeroTolerance
            ),
            put dim1.tl, dim2.tl, resC.tl, 'Manual', risC.tl
                o_manuHVDCRiskLevel(dim1,dim2,resC,risC)
                o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2)
                o_FIRPrice_TP(dim1,dim2), o_FIRvrMW_TP(dim1,dim2) / ;
        elseif ( ord(resC)=2 ) and
               ( o_SIRReqd_TP(dim1,dim2) > 0 ) and
               ( abs[ o_manuHVDCRiskLevel(dim1,dim2,resC,risC)
                    - o_SIRReqd_TP(dim1,dim2)
                    ] <= ZeroTolerance
               ),
            put dim1.tl, dim2.tl, resC.tl, 'Manual', risC.tl
                o_manuHVDCRiskLevel(dim1,dim2,resC,risC)
                o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2)
                o_SIRPrice_TP(dim1,dim2), o_SIRvrMW_TP(dim1,dim2) / ;
        ) ;
    ) ;

*   Ensure still reporting for conditions with zero FIR and/or SIR required
    if( ( ord(resC)=1 ) and ( o_FIRReqd_TP(dim1,dim2) = 0 ),
        put dim1.tl, dim2.tl, resC.tl, ' ', ' ', ' '
            o_FIRCleared_TP(dim1,dim2), o_FIRViolation_TP(dim1,dim2)
            o_FIRPrice_TP(dim1,dim2), o_FIRvrMW_TP(dim1,dim2) / ;
    elseif ( ord(resC)=2 ) and ( o_SIRReqd_TP(dim1,dim2) = 0 ),
        put dim1.tl, dim2.tl, resC.tl, ' ', ' ', ' '
            o_SIRCleared_TP(dim1,dim2), o_SIRViolation_TP(dim1,dim2)
            o_SIRPrice_TP(dim1,dim2), o_SIRvrMW_TP(dim1,dim2) / ;
    ) ;
) ;

* Audit - objective result
File objResults_Audit /"%outputPath%\%runName%\%runName%_ObjResults_Audit.csv"/;
objResults_Audit.pc = 5 ;
objResults_Audit.lw = 0 ;
objResults_Audit.pw = 9999 ;
objResults_Audit.ap = 1 ;
objResults_Audit.nd = 5 ;
objResults_Audit.nw = 20 ;
put objResults_Audit
loop( dim1 $ o_DateTime(dim1),
*    put dim1.tl, o_systemCost_TP(dim1) /
    put dim1.tl, o_ofv_TP(dim1) /
) ;

$label AuditReportingEnd
*===============================================================================

* Go to the next input file
$ label End
