*=====================================================================================
* Name:                 vSPDsolve.gms
* Function:             Establish base case and override data, prepare data, and solve
*                       the model
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://reports.ea.govt.nz/EMIIntro.htm
* Contact:              emi@ea.govt.nz
* Last modified on:     28 November 2013
*=====================================================================================

$ontext
  Directory of code sections in vSPDsolve.gms:
  1. Declare symbols and initialise some of them
  2. Load data from GDX file
  3. Manage model and data compatability
  4. Establish which trading periods are to be solved
  5. Input data overrides - declare and apply (include vSPDsolveOverrides.gms)
  6. Initialise constraint violation penalties (CVPs)
  7. The vSPD solve loop
     a) Reset all sets, parameters and variables before proceeding with the next study trade period
     b) Initialise current trade period and model data for the current trade period
     c) Additional pre-processing on parameters and variables before model solve
     d) Solve the model
     e) Check if the LP results are valid
     f) Resolve the model if required
     g) Check for disconnected nodes and adjust prices accordingly
     h) Collect and store results from the current model solve in the output (o_xxx) parameters
     i) End of the solve vSPD loop
  8. Write results to GDX files

Aliases to be aware of:
  i_island = ild, ild1
  i_dateTime = dt
  i_tradePeriod = tp
  i_node = n
  i_offer = o, o1
  i_trader = trdr
  i_tradeBlock = trdBlk
  i_bus = b, b1, frB, toB
  i_branch = br, br1
  i_lossSegment = los, los1
$offtext


* Include paths, settings and case name files
$include vSPDpaths.inc
$include vSPDsettings.inc
$include vSPDcase.inc


* Perform integrity checks on operating mode (opMode) and trade period reporting (tradePeriodReports) switches.
* Notes: - Operating mode: 1 --> DW mode; -1 --> Audit mode; all else implies usual vSPD mode.
*        - tradePeriodReports must be 0 or 1 (default = 1) - a value of 1 implies reports by trade period are
*          generated. A value of zero will suppress them. tradePeriodReports must be 1 if opMode is 1 or -1,
*          i.e. data warehouse or audit modes.
if(tradePeriodReports < 0 or tradePeriodReports > 1, tradePeriodReports = 1 ) ;
if( (opMode = -1) or (opMode = 1), tradePeriodReports = 1 ) ;
*Display opMode, tradePeriodReports ;


* Update the runlog file
File runlog "Write to a report"      /  "%outputPath%\%runName%\%runName%_RunLog.txt" / ; runlog.lw = 0 ; runlog.ap = 1 ;
putclose runlog / 'Run: "%runName%"' / 'Case: "%vSPDinputData%" - started at ', system.time, ' on ' system.date;
if(sequentialsolve,
  putclose runlog / 'Vectorisation is switched OFF'
else
  putclose runlog / 'Vectorisation is switched ON'
) ;

* Set the solver for the LP and MIP
option lp = %Solver% ;
option mip = %Solver% ;

* Set profile status
option profile = 0 ;

* Set the solution print status in the lst file
option solprint = off ;

* Set the column (variable) and row (equation) listing in the lst file
option limcol = 0 ;
option limrow = 0 ;

* Allow empty data set declaration
$onempty


*=====================================================================================
* 1. Declare symbols and initialise some of them
*=====================================================================================

Sets
* Initialise 21 fundamental sets by hard-coding (these sets can also be found in the daily GDX files)
  i_island                    / NI, SI /
  i_reserveClass              / FIR, SIR /
  i_reserveType               / PLSR, TWDR, ILR /
  i_riskClass                 / genRisk, DCCE, DCECE, manual, genRisk_ECE, manual_ECE, HVDCsecRisk_CE, HVDCsecRisk_ECE /
  i_riskParameter             / i_freeReserve, i_riskAdjustmentFactor, i_HVDCpoleRampUp /

  i_offerType                 / energy, PLSR, TWDR, ILR /
  i_offerParam                / i_initialMW, i_rampUpRate, i_rampDnRate, i_reserveGenerationMaximum, i_windOffer, i_FKbandMW /
  i_energyOfferComponent      / i_generationMWoffer, i_generationMWofferPrice /
  i_PLSRofferComponent        / i_PLSRofferPercentage, i_PLSRofferMax, i_PLSRofferPrice /
  i_TWDRofferComponent        / i_TWDRofferMax, i_TWDRofferPrice /
  i_ILRofferComponent         / i_ILRofferMax, i_ILRofferPrice /

  i_energyBidComponent        / i_bidMW, i_bidPrice /
  i_ILRbidComponent           / i_ILRbidMax, i_ILRbidPrice /

  i_tradeBlock                / t1*t20 /
  i_branchParameter           / i_branchResistance, i_branchSusceptance, i_branchFixedLosses, i_numLossTranches /
  i_lossSegment               / ls1*ls10 /
  i_lossParameter             / i_MWbreakPoint, i_lossCoefficient /
  i_constraintRHS             / i_constraintSense, i_constraintLimit /
  i_type1MixedConstraintRHS   / i_mixedConstraintSense, i_mixedConstraintLimit1, i_mixedConstraintLimit2 /
  i_flowDirection             / forward, backward /
  i_CVP                       / i_deficitBusGeneration, i_surplusBusGeneration, i_deficit6sReserve_CE, i_deficit60sReserve_CE
                                i_deficitBranchGroupConstraint, i_surplusBranchGroupConstraint, i_deficitGenericConstraint
                                i_surplusGenericConstraint, i_deficitRampRate, i_surplusRampRate, i_deficitACnodeConstraint
                                i_surplusACnodeConstraint, i_deficitBranchFlow, i_surplusBranchFlow, i_deficitMnodeConstraint
                                i_surplusMnodeConstraint, i_type1DeficitMixedConstraint, i_type1SurplusMixedConstraint
                                i_deficit6sReserve_ECE, i_deficit60sReserve_ECE /
* Initialise the set called pole
  pole  'HVDC poles'          / pole1, pole2 /

* Initialise sets used when applying overrides. Declared and initialised now (ahead of input GDX load) so as to preserve orderedness of elements
  tradePeriodNodeIslandTemp(tp,n,ild) 'Temporary mapping set of nodes to islands for island demand override'
  ovrd             'Number of overrides per parameter'    / 1*100 /
  i_dayNum         'Day number'                           / 1*31 /
  i_monthNum       'Month number'                         / 1*12 /
  i_yearNum        'Year number'                          / 1900*2200 /
  fromTo           'From/To - for override dates'         / frm, to /
  ;

Alias (i_dayNum,day), (i_monthNum,mth), (i_yearNum,yr) ;

* 'startyear' must be modified if you ever decide it is clever to change the first element of i_yearnum.
Scalar startYear 'Start year - used in computing Gregorian date for override years'  / 1899 / ;

Sets
* Dispatch results reporting
  o_fromDateTime(dt)                                                       'Start period for summary reports'
  o_dateTime(dt)                                                           'Date and time for reporting'
  o_bus(dt,b)                                                          'Set of buses for output report'
  o_offer(dt,o)                                                      'Set of offers for output report'
  o_island(dt,ild)                                                    'Island definition for trade period reserve output report'
  o_offerTrader(o,trdr)                                                  'Mapping of offers to traders for offer summary reports'
  o_trader(trdr)                                                               'Set of traders for trader summary output report'
  o_node(dt,n)                                                        'Set of nodes for output report'
  o_branch(dt,br)                                                    'Set of branches for output report'
  o_branchFromBus_TP(dt,br,frB)                                'From bus for set of branches for output report'
  o_branchToBus_TP(dt,br,toB)                                    'To bus for set of branches for output report'
  o_brConstraint_TP(dt,i_branchConstraint)                                 'Set of branch constraints for output report'
  o_MnodeConstraint_TP(dt,i_MnodeConstraint)                               'Set of Mnode constraints for output report'
* TN - Audit report
  o_busIsland_TP(dt,b,ild)                                        'Bus Island Mapping for audit report'
  o_marketNodeIsland_TP(dt,o,ild)                               'Generation offer Island Mapping for audit reporting'
* TN - Audit report - End
* RDN - Additional output for audit report - Start------------------------------
  o_offerIsland_TP(dt,o,ild)                                    'Mapping of offers to island for audit reporting'
* RDN - Additional output for audit report - End--------------------------------
  ;

Parameters
* Main iteration counter
  iterationCount                                                                   'Iteration counter for the solve'
* MIP logic
  branchFlowMIPInvoked(tp)                                              'Flag to detect if branch flow MIP is needed'
  circularBranchFlowExist(tp,br)                                  'Flag to indicate if circulating branch flows exist on each branch: 1 = Yes'
* RDN - Introduce flag to detect circular branch flows on each HVDC pole
  poleCircularBranchFlowExist(tp,pole)                                'Flag to indicate if circulating branch flows exist on each an HVDC pole: 1 = Yes'

  northHVDC(tp)                                                         'HVDC MW sent from from SI to NI'
  southHVDC(tp)                                                         'HVDC MW sent from from NI to SI'
  nonPhysicalLossExist(tp,br)                                     'Flag to indicate if non-physical losses exist on branch: 1 = Yes'
  manualBranchSegmentMWFlow(tp,br,los)                  'Manual calculation of the branch loss segment MW flow'
  manualLossCalculation(tp,br)                                    'MW losses calculated manually from the solution for each loss branch'
  HVDChalfPoleSouthFlow(tp)                                             'Flag to indicate if south flow on HVDC halfpoles'
  type1MixedConstraintLimit2Violation(tp, i_type1MixedConstraint)       'Type 1 mixed constraint MW violaton of the alternate limit value'

* RDN - Parameters to calculate circular branch flow on each HVDC pole
  TotalHVDCpoleFlow(tp,pole)                                          'Total flow on an HVDC pole'
  MaxHVDCpoleFlow(tp,pole)                                            'Maximum flow on an HVDC pole'

* Disconnected bus post-processing
  busGeneration(tp,b)                                               'MW generation at each bus for the study trade periods'
  busLoad(tp,b)                                                     'MW load at each bus for the study trade periods'
  busPrice(tp,b)                                                    '$/MW price at each bus for the study trade periods'
  busDisconnected(tp,b)                                             'Indication if bus is disconnected or not (1 = Yes) for the study trade periods'
* Dispatch Results Outputs for reporting
* Trade period level
  o_islandGen_TP(dt,ild)                                              'Island MW generation for the different time periods'
  o_islandLoad_TP(dt,ild)                                             'Island MW load for the different time periods'
  o_systemViolation_TP(dt,ild)                                        'Island MW violation for the different time periods'
  o_islandEnergyRevenue_TP(dt,ild)                                    'Island energy revenue ($) for the different time periods'
  o_islandReserveRevenue_TP(dt,ild)                                   'Island reserve revenue ($) for the different time periods'
  o_islandLoadCost_TP(dt,ild)                                         'Island load cost ($) for the different time periods'
  o_islandLoadRevenue_TP(dt,ild)                                      'Island load revenue ($) for the different time periods'
  o_islandBranchLoss_TP(dt,ild)                                       'Intra-island branch losses for the different time periods (MW)'
  o_islandRefPrice_TP(dt,ild)                                         'Reference prices in each island ($/MWh)'
  o_HVDCflow_TP(dt,ild)                                               'HVDC flow from each island (MW)'
  o_HVDCloss_TP(dt,ild)                                               'HVDC losses (MW)'
  o_HVDChalfPoleLoss_TP(dt,ild)                                       'Losses on HVDC half poles (MW)'
  o_HVDCpoleFixedLoss_TP(dt,ild)                                      'Fixed loss on inter-island HVDC (MW)'
  o_busGeneration_TP(dt,b)                                             'Output MW generation at each bus for the different time periods'
  o_busLoad_TP(dt,b)                                                   'Output MW load at each bus for the different time periods'
  o_busPrice_TP(dt,b)                                                  'Output $/MW price at each bus for the different time periods'
  o_busDisconnected_TP(dt,b)                                           'Output disconnected bus flag (1 = Yes) for the different time periods'
  o_busRevenue_TP(dt,b)                                                'Generation revenue ($) at each bus for the different time periods'
  o_busCost_TP(dt,b)                                                   'Load cost ($) at each bus for the different time periods'
  o_busDeficit_TP(dt,b)                                                'Bus deficit violation for each trade period'
  o_busSurplus_TP(dt,b)                                                'Bus surplus violation for each trade period'
  o_branchFromBusPrice_TP(dt,br)                                     'Output from bus price ($/MW) for branch reporting'
  o_branchToBusPrice_TP(dt,br)                                       'Output to bus price ($/MW) for branch reporting'
  o_branchMarginalPrice_TP(dt,br)                                    'Output marginal branch constraint price ($/MW) for branch reporting'
  o_branchFlow_TP(dt,br)                                             'Output MW flow on each branch for the different time periods'
  o_branchDynamicLoss_TP(dt,br)                                      'Output MW dynamic loss on each branch for the different time periods'
  o_branchTotalLoss_TP(dt,br)                                        'Output MW total loss on each branch for the different time periods'
  o_branchFixedLoss_TP(dt,br)                                        'Output MW fixed loss on each branch for the different time periods'
  o_branchDynamicRentals_TP(dt,br)                                   'Output $ rentals on transmission branches using dynamic losses for the different time periods'
  o_branchTotalRentals_TP(dt,br)                                     'Output $ rentals on transmission branches using total (dynamic + fixed) for the different time periods'
  o_branchCapacity_TP(dt,br)                                         'Output MW branch capacity for branch reporting'
  o_offerEnergy_TP(dt,o)                                             'Output MW cleared for each energy offer for each trade period'
  o_offerFIR_TP(dt,o)                                                'Output MW cleared for FIR for each trade period'
  o_offerSIR_TP(dt,o)                                                'Output MW cleared for SIR for each trade period'
  o_bidEnergy_TP(dt,i_bid)                                                 'Output MW cleared for each energy bid for each trade period'
  o_bidReserve_TP(dt,i_bid,i_reserveClass)                                 'Output MW cleared for each reserve bid for each trade period'
  o_FIRreqd_TP(dt,ild)                                                'Output MW required FIR for each trade period'
  o_SIRreqd_TP(dt,ild)                                                'Output MW required SIR for each trade period'
  o_FIRprice_TP(dt,ild)                                               'Output $/MW price for FIR reserve classes for each trade period'
  o_SIRprice_TP(dt,ild)                                               'Output $/MW price for SIR reserve classes for each trade period'
  o_FIRviolation_TP(dt,ild)                                           'Violtaiton MW for FIR reserve classes for each trade period'
  o_SIRviolation_TP(dt,ild)                                           'Violtaiton MW for SIR reserve classes for each trade period'
  o_nodeGeneration_TP(dt,n)                                           'Ouput MW generation at each node for the different time periods'
  o_nodeLoad_TP(dt,n)                                                 'Ouput MW load at each node for the different time periods'
  o_nodePrice_TP(dt,n)                                                'Output $/MW price at each node for the different time periods'
  o_nodeRevenue_TP(dt,n)                                              'Output $ revenue at each node for the different time periods'
  o_nodeCost_TP(dt,n)                                                 'Output $ cost at each node for the different time periods'
  o_nodeDeficit_TP(dt,n)                                              'Output node deficit violation for each trade period'
  o_nodeSurplus_TP(dt,n)                                              'Output node surplus violation for each trade period'
* Security constraint data
  o_brConstraintSense_TP(dt,i_branchConstraint)                            'Branch constraint sense for each output report'
  o_brConstraintLHS_TP(dt,i_branchConstraint)                              'Branch constraint LHS for each output report'
  o_brConstraintRHS_TP(dt,i_branchConstraint)                              'Branch constraint RHS for each output report'
  o_brConstraintPrice_TP(dt,i_branchConstraint)                            'Branch constraint price for each output report'
* Mnode constraint data
  o_MnodeConstraintSense_TP(dt,i_MnodeConstraint)                          'Market node constraint sense for each output report'
  o_MnodeConstraintLHS_TP(dt,i_MnodeConstraint)                            'Market node constraint LHS for each output report'
  o_MnodeConstraintRHS_TP(dt,i_MnodeConstraint)                            'Market node constraint RHS for each output report'
  o_MnodeConstraintPrice_TP(dt,i_MnodeConstraint)                          'Market node constraint price for each output report'
* TradePeriod summary report
  o_solveOK_TP(dt)                                                         'Solve status for summary report (1=OK)'
  o_systemCost_TP(dt)                                                      'System cost for summary report'
*RDN - 20130730 - Additional reporting on system objective function and penalty cost
  o_ofv_TP(dt)                                                             'Objective function value for summary report'
  o_penaltyCost_TP(dt)                                                     'Penalty cost for summary report'
*RDN - 20130730 - Additional reporting on system objective function and penalty cost
  o_defGenViolation_TP(dt)                                                 'Deficit generation violation for summary report'
  o_surpGenViolation_TP(dt)                                                'Surplus generaiton violation for summary report'
  o_surpBranchFlow_TP(dt)                                                  'Surplus branch flow violation for summary report'
  o_defRampRate_TP(dt)                                                     'Deficit ramp rate violation for summary report'
  o_surpRampRate_TP(dt)                                                    'Surplus ramp rate violation for summary report'
  o_surpBranchGroupConst_TP(dt)                                            'Surplus branch group constraint violation for summary report'
  o_defBranchGroupConst_TP(dt)                                             'Deficit branch group constraint violation for summary report'
  o_defMnodeConst_TP(dt)                                                   'Deficit market node constraint violation for summary report'
  o_surpMnodeConst_TP(dt)                                                  'Surplus market node constraint violation for summary report'
  o_defACnodeConst_TP(dt)                                                  'Deficit AC node constraint violation for summary report'
  o_surpACnodeConst_TP(dt)                                                 'Surplus AC node constraint violation for summary report'
  o_defT1MixedConst_TP(dt)                                                 'Deficit Type1 mixed constraint violation for sumamry report'
  o_surpT1MixedConst_TP(dt)                                                'Surplus Type1 mixed constraint violation for summary report'
  o_defGenericConst_TP(dt)                                                 'Deficit generic constraint violation for summary report'
  o_surpGenericConst_TP(dt)                                                'Surplus generic constraint violation for summary report'
  o_defResv_TP(dt)                                                         'Deficit reserve violation for summary report'
  o_totalViolation_TP(dt)                                                  'Total violation for datawarehouse summary report'
* System level
  o_numTradePeriods                                                                'Output number of trade periods in summary'
  o_systemOFV                                                                      'System objective function value'
  o_systemGen                                                                      'Output system MWh generation'
  o_systemLoad                                                                     'Output system MWh load'
  o_systemLoss                                                                     'Output system MWh loss'
  o_systemViolation                                                                'Output system MWh violation'
  o_systemFIR                                                                      'Output system FIR MWh reserve'
  o_systemSIR                                                                      'Output system SIR MWh reserve'
  o_systemEnergyRevenue                                                            'Output offer energy revenue $'
  o_systemReserveRevenue                                                           'Output reserve revenue $'
  o_systemLoadCost                                                                 'Output system load cost $'
  o_systemLoadRevenue                                                              'Output system load revenue $'
  o_systemSurplus                                                                  'Output system surplus $'
  o_systemACrentals                                                                'Output system AC rentals $'
  o_systemDCrentals                                                                'Output system DC rentals $'
* Offer level
  o_offerGen(o)                                                              'Output offer generation (MWh)'
  o_offerFIR(o)                                                              'Output offer FIR (MWh)'
  o_offerSIR(o)                                                              'Output offer SIR (MWh)'
  o_offerGenRevenue(o)                                                       'Output offer energy revenue ($)'
  o_offerFIRrevenue(o)                                                       'Output offer FIR revenue ($)'
  o_offerSIRrevenue(o)                                                       'Output offer SIR revenue ($)'
* Trader level
  o_traderGen(trdr)                                                            'Output trader generation (MWh)'
  o_traderFIR(trdr)                                                            'Output trader FIR (MWh)'
  o_traderSIR(trdr)                                                            'Output trader SIR (MWh)'
  o_traderGenRevenue(trdr)                                                     'Output trader energy revenue ($)'
  o_traderFIRrevenue(trdr)                                                     'Output trader FIR revenue ($)'
  o_traderSIRrevenue(trdr)                                                     'Output trader SIR revenue ($)'
* TN - Additional output for audit reporting
  o_lossSegmentBreakPoint(dt,br,los)                       'MW capacity of each loss segment for audit'
  o_lossSegmentFactor(dt,br,los)                           'Loss factor of each loss segment for audit'
  o_ACbusAngle(dt,b)                                                   'Bus voltage angle for audit reporting'
  o_nonPhysicalLoss(dt,br)                                           'MW losses calculated manually from the solution for each loss branch'
  o_branchConstrained_TP(dt,br)                                      'Output flag if branch constrained'
  o_ILRO_FIR_TP(dt,o)                                                'Output IL offer FIR (MWh)'
  o_ILRO_SIR_TP(dt,o)                                                'Output IL offer SIR (MWh)'
  o_ILbus_FIR_TP(dt,b)                                                 'Output IL offer at bus FIR (MWh)'
  o_ILbus_SIR_TP(dt,b)                                                 'Output IL offer at bus SIR (MWh)'
  o_PLRO_FIR_TP(dt,o)                                                'Output PLSR offer FIR (MWh)'
  o_PLRO_SIR_TP(dt,o)                                                'Output PLSR SIR (MWh)'
  o_TWRO_FIR_TP(dt,o)                                                'Output TWR FIR (MWh)'
  o_TWRO_SIR_TP(dt,o)                                                'Output TWR SIR (MWh)'
  o_generationRiskSetter(dt,ild,o,i_reserveClass,i_riskClass)   'For Audit'
  o_generationRiskSetterMax(dt,ild,o,i_reserveClass)            'For Audit'
  o_genHVDCriskSetter(dt,ild,o,i_reserveClass,i_riskClass)      'For Audit'
  o_HVDCriskSetter(dt,ild,i_reserveClass,i_riskClass)                 'For Audit'
  o_manuRiskSetter(dt,ild,i_reserveClass,i_riskClass)                 'For Audit'
  o_manuHVDCriskSetter(dt,ild,i_reserveClass,i_riskClass)             'For Audit'
* TN - Additional output for audit reporting - End
* RDN - Additional output for Audit risk report - Start--------------------------
  o_HVDCriskSetterMax(dt,ild,i_reserveClass)                          'For Audit'
  o_genHVDCriskSetterMax(dt,ild,o,i_reserveClass)               'For Audit'
  o_manuHVDCriskSetterMax(dt,ild,i_reserveClass)                      'For Audit'
  o_manuRiskSetterMax(dt,ild,i_reserveClass)                          'For Audit'
  o_FIRcleared_TP(dt,ild)                                             'For Audit'
  o_SIRcleared_TP(dt,ild)                                             'For Audit'
* RDN - Update the deficit and surplus reporting at the nodal level - Start------
  totalBusAllocation(dt,b)                                             'Total allocation of nodes to bus'
  busNodeAllocationFactor(dt,b,n)                                 'Bus to node allocation factor'
* RDN - Update the deficit and surplus reporting at the nodal level - End--------
* RDN - 20130302 - i_tradePeriodNodeBusAllocationFactor update - Start-----------
* Introduce i_useBusNetworkModel to account for MSP change-over date when for half of the day the old
* market node model and the other half the bus network model was used.
  i_useBusNetworkModel(tp)                                              'Indicates if the post-MSP bus network model is used in vSPD (1 = Yes)'
* RDN - 20130302 - i_tradePeriodNodeBusAllocationFactor update - End-----------
  ;

Scalars
  modelSolved                      'Flag to indicate if the model solved successfully (1 = Yes)'                                           / 0 /
  LPmodelSolved                    'Flag to indicate if the final LP model (when MIP fails) is solved successfully (1 = Yes)'              / 0 /
  skipResolve                      'Flag to indicate if the integer resolve logic needs to be skipped and resolved in sequential mode'     / 0 /
  LPvalid                          'Flag to indicate if the LP solution is valid (1 = Yes)'                                                / 0 /
  numTradePeriods                  'Number of trade periods in the solve'                                                                  / 0 /
  thresholdSimultaneousInteger     'Threshold number of trade periods for which to skip the integer resolve in simultanous mode and repeat in sequential mode' / 1 /
* RDN - Flag to use the extended set of risk classes which include the GENRISK_ECE and Manual_ECE
  i_useExtendedRiskClass           'Use the extended set of risk classes (1 = Yes)'                                                                            / 0 /
  ;

* Declare a temporary file
File temp ;



*=====================================================================================
* 2. Load data from GDX file
*=====================================================================================
* Call the GDX routine and load the input data:
* - include .gdx extension to facilitate standalone mode (implies the .gdx extension is omitted from the vSPDcase.inc file)
* - if file does not exist then go to the next input file
$if not exist "%inputPath%\%vSPDinputData%.gdx" $goto nextInput
$gdxin "%inputPath%\%vSPDinputData%.gdx"
* 30 sets
$load i_tradePeriod i_dateTime i_offer i_trader i_bid i_node i_bus i_branch i_branchConstraint i_ACnodeConstraint i_MnodeConstraint i_GenericConstraint
$load i_type1MixedConstraint i_type2MixedConstraint
$load i_dateTimeTradePeriodMap i_tradePeriodOfferTrader i_tradePeriodOfferNode i_tradePeriodBidTrader i_tradePeriodBidNode  i_tradePeriodNode
$load i_tradePeriodBusIsland i_tradePeriodBus i_tradePeriodNodeBus i_tradePeriodBranchDefn i_tradePeriodRiskGenerator
$load i_type1MixedConstraintReserveMap i_tradePeriodType1MixedConstraint i_tradePeriodType2MixedConstraint i_type1MixedConstraintBranchCondition
$load i_tradePeriodGenericConstraint
* 55 Parameters
$load i_day i_month i_year i_tradingPeriodLength i_AClineUnit i_branchReceivingEndLossProportion
$load i_studyTradePeriod i_CVPvalues i_tradePeriodOfferParameter i_tradePeriodEnergyOffer i_tradePeriodSustainedPLSRoffer i_tradePeriodFastPLSRoffer
$load i_tradePeriodSustainedTWDRoffer i_tradePeriodFastTWDRoffer i_tradePeriodSustainedILRoffer i_tradePeriodFastILRoffer i_tradePeriodNodeDemand
$load i_tradePeriodEnergyBid i_tradePeriodSustainedILRbid i_tradePeriodFastILRbid i_tradePeriodHVDCnode i_tradePeriodReferenceNode i_tradePeriodHVDCBranch
$load i_tradePeriodBranchParameter i_tradePeriodBranchCapacity i_tradePeriodBranchOpenStatus i_noLossBranch i_AClossBranch i_HVDClossBranch i_tradePeriodNodeBusAllocationFactor
$load i_tradePeriodBusElectricalIsland i_tradePeriodRiskParameter i_tradePeriodManualRisk i_tradePeriodBranchConstraintFactors i_tradePeriodBranchConstraintRHS
$load i_tradePeriodACnodeConstraintFactors i_tradePeriodACnodeConstraintRHS i_tradePeriodMnodeEnergyOfferConstraintFactors i_tradePeriodMnodeReserveOfferConstraintFactors
$load i_tradePeriodMnodeEnergyBidConstraintFactors i_tradePeriodMnodeILReserveBidConstraintFactors i_tradePeriodMnodeConstraintRHS i_type1MixedConstraintVarWeight
$load i_type1MixedConstraintGenWeight i_type1MixedConstraintResWeight i_type1MixedConstraintHVDClineWeight i_tradePeriodType1MixedConstraintRHSParameters
$load i_type2MixedConstraintLHSParameters i_tradePeriodType2MixedConstraintRHSParameters i_tradePeriodGenericEnergyOfferConstraintFactors
$load i_tradePeriodGenericReserveOfferConstraintFactors i_tradePeriodGenericEnergyBidConstraintFactors i_tradePeriodGenericILReserveBidConstraintFactors
$load i_tradePeriodGenericBranchConstraintFactors i_tradePeriodGenericConstraintRHS
$gdxin



*=====================================================================================
* 3. Manage model and data compatability
*=====================================================================================
* This section manages the changes to model flags to ensure backward compatibility given
* changes in the SPD model formulation:
* - some data loading from GDX file is conditioned on date of inclusion of symbol in question
* - data symbols below are loaded at execution time whereas the main load above is at compile time.

* Gregorian date of when symbols have been included into the GDX files and therefore conditionally loaded
* 17 Oct 2011 = 40832
* 01 May 2012 = 41029
* 28 Jun 2012 = 41087
* 20 Sep 2012 = 41171
* 12 Jan 2013 = 41285
* 24 Feb 2013 = 41328

Scalars
  inputGDXGDate 'Gregorian date of input GDX file'
  mixedConstraintRiskOffsetGDXGDate        / 40832 /
  primarySecondaryGDXGDate                 / 41029 /
* RDN - Change to demand bid
  demandBidChangeGDXGDate                  / 41087 /
* RDN - Change to demand bid - End
  HVDCroundPowerGDXGDate                   / 41171 /
  minimumRiskECEGDXGDate                   / 41171 /
  HVDCsecRiskGDXGDate                      / 41171 /
  addnMixedConstraintVarGDXGDate           / 41328 /
  reserveClassGenMaxGDXGDate               / 41328 /
  primSecGenRiskModelGDXGDate              / 41328 /
* RDN - 20130302 - Introduce MSP change-over date to account for change in the node-bus allocation factor from the input gdx files
  MSPchangeOverGDXGDate                    / 40014 /
  ;

* Calculate the Gregorian date of the input data
inputGDXGDate = jdate(i_year,i_month,i_day) ;

put_utility temp 'gdxin' / '%inputPath%\%vSPDinputData%.gdx' ;

* Conditional load of i_tradePeriodPriamrySecondary set
if(inputGDXGDate >= primarySecondaryGDXGDate,
  execute_load i_tradePeriodPrimarySecondaryOffer ;
else
  i_tradePeriodPrimarySecondaryOffer(tp,o,o1) = no ;
) ;

* Conditional load of i_tradePeriodManualRisk_ECE parameter
if(inputGDXGDate >= minimumRiskECEGDXGDate,
* RDN - Set the use extended risk class flag
  i_useExtendedRiskClass = 1 ;
  execute_load i_tradePeriodManualRisk_ECE ;
else
  i_tradePeriodManualRisk_ECE(tp,ild,i_reserveClass) = 0 ;
) ;

* Conditional load of HVDC secondary risk parameters
if(inputGDXGDate >= HVDCsecRiskGDXGDate,
  execute_load i_tradePeriodHVDCsecRiskEnabled, i_tradePeriodHVDCsecRiskSubtractor ;
else
  i_tradePeriodHVDCsecRiskEnabled(tp,ild,i_riskClass) = 0 ;
  i_tradePeriodHVDCsecRiskSubtractor(tp,ild) = 0 ;
) ;

* Conditional load of i_tradePeriodAllowHVDCroundpower parameter
if(inputGDXGDate >= HVDCroundPowerGDXGDate,
  execute_load i_tradePeriodAllowHVDCroundpower ;
else
  i_tradePeriodAllowHVDCroundpower(tp) = 0 ;
) ;

* Conditional load of additional mixed constraint parameters
if(inputGDXGDate >= addnMixedConstraintVarGDXGDate,
  execute_load i_type1MixedConstraintAClineWeight, i_type1MixedConstraintAClineLossWeight, i_type1MixedConstraintAClineFixedLossWeight
               i_type1MixedConstraintHVDClineLossWeight, i_type1MixedConstraintHVDClineFixedLossWeight, i_type1MixedConstraintPurWeight ;
else
  i_type1MixedConstraintAClineWeight(i_type1MixedConstraint,br) = 0 ;
  i_type1MixedConstraintAClineLossWeight(i_type1MixedConstraint,br) = 0 ;
  i_type1MixedConstraintAClineFixedLossWeight(i_type1MixedConstraint,br) = 0 ;
  i_type1MixedConstraintHVDClineLossWeight(i_type1MixedConstraint,br) = 0 ;
  i_type1MixedConstraintHVDClineFixedLossWeight(i_type1MixedConstraint,br) = 0 ;
  i_type1MixedConstraintPurWeight(i_type1MixedConstraint,i_bid) = 0 ;
) ;

* Conditional load of reserve class generation parameter
if(inputGDXGDate >= reserveClassGenMaxGDXGDate,
  execute_load i_tradePeriodReserveClassGenerationMaximum ;
else
  i_tradePeriodReserveClassGenerationMaximum(tp,o,i_reserveClass) = 0 ;
) ;

* RDN - Switch off the mixed constraint based risk offset calculation after 17 October 2011 (data stopped being populated in GDX file)
useMixedConstraintRiskOffset = 1$(inputGDXGDate < mixedConstraintRiskOffsetGDXGDate) ;

* RDN - Switch off mixed constraint formulation if no data coming through or it's explicitly suppressed by the user
useMixedConstraint(tp)$sum(i_type1MixedConstraint$i_tradePeriodType1MixedConstraint(tp,i_type1MixedConstraint), 1) = 1 ;
useMixedConstraint(tp)$suppressMixedConstraint = 0 ;

* RDN - Do not use the extended risk class if no data coming through
i_useExtendedRiskClass$(sum((tp,ild,i_reserveClass,i_riskClass,i_riskParameter)$(ord(i_riskClass) > 4), i_tradePeriodRiskParameter(tp,ild,i_reserveClass,i_riskClass,i_riskParameter))=0) = 0 ;

* RDN - Change to demand bid
useDSBFDemandBidModel = 1$( inputGDXGDate >= demandBidChangeGDXGDate ) ;
* RDN - Change to demand bid - End

* RDN - Use the risk model that accounts for multiple offers per generating unit
usePrimSecGenRiskModel = 1$( inputGDXGDate >= primSecGenRiskModelGDXGDate ) ;

* RDN - 20130302 - i_tradePeriodNodeBusAllocationFactor update - Start--------
* Introduce i_useBusNetworkModel to account for MSP change-over date when for half of the day the old
* market node model and the other half the bus network model was used. The old market model does not
* have the i_tradePeriodBusElectrical island paramter specified since it uses the market node network
* model. This flag is introduced to allow the i_tradePeriodBusElectricalIsland parameter to be used
* in the post-MSP solves to indentify 'dead' electrical buses.
i_useBusNetworkModel(tp) = 1$( ( inputGDXGDate >= MSPchangeOverGDXGDate ) and sum(b, i_tradePeriodBusElectricalIsland(tp,b) ) ) ;
* RDN - 20130302 - i_tradePeriodNodeBusAllocationFactor update - End----------


*=====================================================================================
* 4. Establish which trading periods are to be solved
*=====================================================================================
$ontext
  The symbol called i_tradePeriodSolve is used to change the values of i_studyTradePeriod, which
  itself is loaded from the input GDX file and is by default set equal to 1 for all trading periods.
  The procedure for setting the value of i_tradePeriodSolve depends on the user interface mode. The
  $setglobal called interfaceMode is used to control the process of setting the values of i_tradePeriodSolve.
  interfaceMode: a value of zero implies the EMI interface, a 1 implies the Excel interface; and all other
  values imply standalone interface mode (although ideally users should set it equal to 2 for standalone).
$offtext

Parameter i_tradePeriodSolve(tp) 'Trading periods to be solved' ;

* EMI interface
$if not %interfaceMode%==0 $goto skipEMIReadTPsToSolve
$gdxin "%programPath%\TPsToSolve.gdx"
$load i_tradePeriodSolve
$gdxin
$label skipEMIReadTPsToSolve

* Excel interface
$if not %interfaceMode%==1 $goto skipExcelReadTPsToSolve
$onecho > TPsToSolve.ins
  par = i_tradePeriodSolve  rng = i_tradePeriodSolve  rdim = 1
$offecho
*RDN - Update the file name and path for the TPsTpSolve when in Excel mode
*$call 'gdxxrw "%ovrdPath%\%vSPDinputOvrdData%.xls" o=TPsToSolve.gdx "@TPsToSolve.ins"'
*$gdxin "%ovrdPath%\TPsToSolve.gdx"
$call 'gdxxrw "%programPath%\%vSPDinputFileName%.xls" o=TPsToSolve.gdx "@TPsToSolve.ins"'
$gdxin "%programPath%\TPsToSolve.gdx"
$load i_tradePeriodSolve
$gdxin
$label skipExcelReadTPsToSolve

* Standalone interface
$if %interfaceMode%==0 $goto skipStandaloneReadTPsToSolve
$if %interfaceMode%==1 $goto skipStandaloneReadTPsToSolve
* Users need to edit the next few lines to suit their own purposes. The default is to solve for all trading periods
  i_tradePeriodSolve(tp) = 1 ;
* i_tradePeriodSolve(tp)$[(ord(tp) > 28) or (ord(tp) < 41)] = 1 ;
* $include tradePeriodsToSolve.inc
*$gdxin "%programPath%\TPsToSolve.gdx"
*$load i_tradePeriodSolve
*$gdxin
$label skipStandaloneReadTPsToSolve

* Regardless of interface type, now use i_tradePeriodSolve to change the values of i_studyTradePeriod
i_studyTradePeriod(tp) = 0 ;
i_studyTradePeriod(tp)$i_tradePeriodSolve(tp) = 1 ;
*Display i_tradePeriodSolve ;


*=====================================================================================
* 5. Input data overrides - declare and apply (include vSPDsolveOverrides.gms)
*=====================================================================================

$ontext
  At this point, vSPDsolveOverrides.gms is included into vSPDsolve.gms unless suppressOverrides in
  vSPDpaths.inc is set equal to 1.
  The procedure for introducing data overrides depends on the user interface mode. The $setglobal called
  interfaceMode is used to control the process of introducing data overrides.
  interfaceMode: a value of zero implies the EMI interface, a 1 implies the Excel interface; and all other
  values imply standalone interface mode (although ideally users should set it equal to 2 for standalone).
  All override data symbols have the characters 'Ovrd' appended to the original symbol name. After declaring
  the override symbols, the override data is installed and the original symbols are overwritten.
  Note that the Excel interface permits a very limited number of input data symbols to be overridden. The EMI
  interface will create a GDX file of override values for all data inputs to be overridden. If operating in
  standalone mode, overrides can be installed by any means the user prefers - GDX file, $include file, hard-coding,
  etc. But it probably makes sense to mimic the GDX file as used by EMI.
$offtext

$if not %suppressOverrides%==1 $include vSPDoverrides.gms

*FTR include file 1 - override vSPD settings and parameters to calculate branch and constraint participation loading
*$if exist FTR_1.ins $Include FTR_1.ins


*=====================================================================================
* 6. Initialise constraint violation penalties (CVPs)
*=====================================================================================

Scalar CVPchangeGDate 'Gregorian date of CE and ECE CVP change' ;

* Set the flag for the application of the different CVPs for CE and ECE
* If the user selects No (0), this default value of the diffCeECeCVP flag will be used.
diffCeECeCVP = 0 ;

* Calculate the Gregorian date of the CE and ECE change - Based on CAN from www.systemoperator.co.nz this was on 24th June 2010
CVPchangeGDate = jdate(2010,06,24) ;

* If the user selects Auto (-1), set the diffCeECeCVP flag if the input date is greater than or equal to this date
diffCeECeCVP$((inputGDXGDate >= CVPchangeGDate) and (%VarResv% = -1)) = 1 ;
* If the user selects Yes (1), set the diffCeECeCVP flag
diffCeECeCVP$(%VarResv% = 1) = 1 ;

deficitBusGenerationPenalty                                         = sum(i_CVP$(ord(i_CVP) = 1), i_CVPvalues(i_CVP)) ;
surplusBusGenerationPenalty                                         = sum(i_CVP$(ord(i_CVP) = 2), i_CVPvalues(i_CVP)) ;
deficitReservePenalty(i_reserveClass)$(ord(i_reserveClass) = 1)     = sum(i_CVP$(ord(i_CVP) = 3), i_CVPvalues(i_CVP)) ;
deficitReservePenalty(i_reserveClass)$(ord(i_reserveClass) = 2)     = sum(i_CVP$(ord(i_CVP) = 4), i_CVPvalues(i_CVP)) ;
deficitBranchGroupConstraintPenalty                                 = sum(i_CVP$(ord(i_CVP) = 5), i_CVPvalues(i_CVP)) ;
surplusBranchGroupConstraintPenalty                                 = sum(i_CVP$(ord(i_CVP) = 6), i_CVPvalues(i_CVP)) ;
deficitGenericConstraintPenalty                                     = sum(i_CVP$(ord(i_CVP) = 7), i_CVPvalues(i_CVP)) ;
surplusGenericConstraintPenalty                                     = sum(i_CVP$(ord(i_CVP) = 8), i_CVPvalues(i_CVP)) ;
deficitRampRatePenalty                                              = sum(i_CVP$(ord(i_CVP) = 9), i_CVPvalues(i_CVP)) ;
surplusRampRatePenalty                                              = sum(i_CVP$(ord(i_CVP) = 10), i_CVPvalues(i_CVP)) ;
deficitACnodeConstraintPenalty                                      = sum(i_CVP$(ord(i_CVP) = 11), i_CVPvalues(i_CVP)) ;
surplusACnodeConstraintPenalty                                      = sum(i_CVP$(ord(i_CVP) = 12), i_CVPvalues(i_CVP)) ;
deficitBranchFlowPenalty                                            = sum(i_CVP$(ord(i_CVP) = 13), i_CVPvalues(i_CVP)) ;
surplusBranchFlowPenalty                                            = sum(i_CVP$(ord(i_CVP) = 14), i_CVPvalues(i_CVP)) ;
deficitMnodeConstraintPenalty                                       = sum(i_CVP$(ord(i_CVP) = 15), i_CVPvalues(i_CVP)) ;
surplusMnodeConstraintPenalty                                       = sum(i_CVP$(ord(i_CVP) = 16), i_CVPvalues(i_CVP)) ;
type1DeficitMixedConstraintPenalty                                  = sum(i_CVP$(ord(i_CVP) = 17), i_CVPvalues(i_CVP)) ;
type1SurplusMixedConstraintPenalty                                  = sum(i_CVP$(ord(i_CVP) = 18), i_CVPvalues(i_CVP)) ;
* RDN - Different CVPs defined for CE and ECE
deficitReservePenalty_CE(i_reserveClass)$(ord(i_reserveClass) = 1)  = sum(i_CVP$(ord(i_CVP) = 3), i_CVPvalues(i_CVP)) ;
deficitReservePenalty_CE(i_reserveClass)$(ord(i_reserveClass) = 2)  = sum(i_CVP$(ord(i_CVP) = 4), i_CVPvalues(i_CVP)) ;
deficitReservePenalty_ECE(i_reserveClass)$(ord(i_reserveClass) = 1) = sum(i_CVP$(ord(i_CVP) = 19), i_CVPvalues(i_CVP)) ;
deficitReservePenalty_ECE(i_reserveClass)$(ord(i_reserveClass) = 2) = sum(i_CVP$(ord(i_CVP) = 20), i_CVPvalues(i_CVP)) ;


* Initialise some reporting parameters
o_numTradePeriods = 0 ;
o_systemOFV = 0 ;
o_systemGen = 0 ;
o_systemLoad = 0 ;
o_systemLoss = 0 ;
o_systemViolation = 0 ;
o_systemFIR = 0 ;
o_systemSIR = 0 ;
o_systemEnergyRevenue = 0 ;
o_systemReserveRevenue = 0 ;
o_systemLoadCost = 0 ;
o_systemLoadRevenue = 0 ;
o_systemSurplus = 0 ;
o_systemACrentals = 0 ;
o_systemDCrentals = 0 ;
o_offerGen(o) = 0 ;
o_offerFIR(o) = 0 ;
o_offerSIR(o) = 0 ;
o_offerGenRevenue(o) = 0 ;
o_offerFIRrevenue(o) = 0 ;
o_offerSIRrevenue(o) = 0 ;

o_solveOK_TP(dt) = 0 ;


* RDN - Initialise some of the Audit reporting parameters to zero - Start--------
o_FIRreqd_TP(dt,ild) = 0 ;
o_SIRreqd_TP(dt,ild) = 0 ;
o_generationRiskSetter(dt,ild,o,i_reserveClass,i_riskClass) = 0 ;
o_generationRiskSetterMax(dt,ild,o,i_reserveClass) = 0 ;
o_genHVDCriskSetter(dt,ild,o,i_reserveClass,i_riskClass) = 0 ;
o_HVDCriskSetter(dt,ild,i_reserveClass,i_riskClass) = 0 ;
o_manuRiskSetter(dt,ild,i_reserveClass,i_riskClass) = 0 ;
o_manuHVDCriskSetter(dt,ild,i_reserveClass,i_riskClass) = 0 ;
o_HVDCriskSetterMax(dt,ild,i_reserveClass) = 0 ;
o_genHVDCriskSetterMax(dt,ild,o,i_reserveClass) = 0 ;
o_manuHVDCriskSetterMax(dt,ild,i_reserveClass) = 0 ;
o_manuRiskSetterMax(dt,ild,i_reserveClass) = 0 ;
o_FIRcleared_TP(dt,ild) = 0 ;
o_SIRcleared_TP(dt,ild) = 0 ;
* RDN - Initialise some of the Audit reporting parameters to zero - End----------

* RDN - Update the deficit and surplus reporting at the nodal level - Start------
totalBusAllocation(dt,b) = 0 ;
busNodeAllocationFactor(dt,b,n) = 0 ;
* RDN - Update the deficit and surplus reporting at the nodal level - End------
 ;


* Determine the number of trade periods
numTradePeriods = card(tp) ;



*=====================================================================================
* 7. The vSPD solve loop
*=====================================================================================

for(iterationCount = 1 to numTradePeriods,
  skipResolve = 0 ;

* Determine which trading periods to solve when in sequential solve mode
  if(((sequentialsolve and sum(tp$( ord(tp) = iterationCount), i_studyTradePeriod(tp))) or (not sequentialsolve)),

*=====================================================================================
*   a) Reset all sets, parameters and variables before proceeding with the next study trade period

*   Model Variables
*   Reset bounds
*   Offers
    option clear = GENERATION ;
    option clear = GENERATIONBLOCK ;
*   Purchase bids
    option clear = PURCHASE ;
    option clear = PURCHASEBLOCK ;
    option clear = PURCHASEILR ;
    option clear = PURCHASEILRBLOCK ;
*   Network
    option clear = HVDCLINKFLOW ;
    option clear = HVDCLINKLOSSES ;
    option clear = LAMBDA ;
    option clear = LAMBDAINTEGER ;
    option clear = ACBRANCHFLOW ;
    option clear = ACBRANCHFLOWDIRECTED ;
    option clear = ACBRANCHLOSSESDIRECTED ;
    option clear = ACBRANCHFLOWBLOCKDIRECTED ;
    option clear = ACBRANCHLOSSESBLOCKDIRECTED ;
    option clear = ACNODEANGLE ;
    option clear = ACBRANCHFLOWDIRECTED_INTEGER ;
    option clear = HVDCLINKFLOWDIRECTION_INTEGER ;
*   RDN - Clear the integer variable to prevent intra-pole circulating branch flows
    option clear = HVDCPOLEFLOW_INTEGER ;
*   Risk/Reserve
    option clear = RESERVEBLOCK ;
    option clear = RISKOFFSET ;
*   Mixed constraint
    option clear = MIXEDCONSTRAINTVARIABLE ;
    option clear = MIXEDCONSTRAINTLIMIT2SELECT ;
*   Reset levels
*   Objective
    option clear = NETBENEFIT ;
*   Network
    option clear = ACNODENETINJECTION ;
    option clear = ACBRANCHFLOW ;
    option clear = ACNODEANGLE ;
*   Generation
    option clear = GENERATION ;
    option clear = GENERATIONBLOCK ;
*   Purchase
    option clear = PURCHASE ;
    option clear = PURCHASEBLOCK ;
    option clear = PURCHASEILR ;
    option clear = PURCHASEILRBLOCK ;
*   Reserve
    option clear = ISLANDRISK ;
    option clear = HVDCREC ;
    option clear = RISKOFFSET ;
    option clear = RESERVE ;
    option clear = RESERVEBLOCK ;
    option clear = MAXISLANDRISK ;
*   Network
    option clear = HVDCLINKFLOW ;
    option clear = HVDCLINKLOSSES ;
    option clear = LAMBDA ;
    option clear = LAMBDAINTEGER ;
    option clear = ACBRANCHFLOWDIRECTED ;
    option clear = ACBRANCHLOSSESDIRECTED ;
    option clear = ACBRANCHFLOWBLOCKDIRECTED ;
    option clear = ACBRANCHLOSSESBLOCKDIRECTED ;
    option clear = ACBRANCHFLOWDIRECTED_INTEGER ;
    option clear = HVDCLINKFLOWDIRECTION_INTEGER ;
*   RDN - Clear the integer variable to prevent intra-pole circulating branch flows
    option clear = HVDCPOLEFLOW_INTEGER ;
*   Mixed constraint
    option clear = MIXEDCONSTRAINTVARIABLE ;
    option clear = MIXEDCONSTRAINTLIMIT2SELECT ;
*   Violations
    option clear = TOTALPENALTYCOST ;
    option clear = DEFICITBUSGENERATION ;
    option clear = SURPLUSBUSGENERATION ;
    option clear = DEFICITRESERVE ;
    option clear = DEFICITBRANCHSECURITYCONSTRAINT ;
    option clear = SURPLUSBRANCHSECURITYCONSTRAINT ;
    option clear = DEFICITRAMPRATE ;
    option clear = SURPLUSRAMPRATE ;
    option clear = DEFICITACnodeCONSTRAINT ;
    option clear = SURPLUSACnodeCONSTRAINT ;
    option clear = DEFICITBRANCHFLOW ;
    option clear = SURPLUSBRANCHFLOW ;
    option clear = DEFICITMNODECONSTRAINT ;
    option clear = SURPLUSMNODECONSTRAINT ;
    option clear = DEFICITTYPE1MIXEDCONSTRAINT ;
    option clear = SURPLUSTYPE1MIXEDCONSTRAINT ;
    option clear = DEFICITGENERICCONSTRAINT ;
    option clear = SURPLUSGENERICCONSTRAINT ;
*   RDN - Seperate CE and ECE deficit
    option clear = DEFICITRESERVE_CE ;
    option clear = DEFICITRESERVE_ECE ;
*   Study parameters and sets
    option clear = currTP ;
*   Offers
    option clear = offerNode ;
    option clear = generationStart ;
    option clear = rampRateUp ;
    option clear = rampRateDown ;
    option clear = reserveGenerationMaximum ;
    option clear = windOffer ;
*   RDN - Clear the FKband
    option clear = FKband ;
    option clear = generationOfferMW ;
    option clear = generationOfferPrice ;
*   Don't reset the previous MW value otherwise it serves no purpose
*   PreviousMW(o) = 0 ;
    option clear = validGenerationOfferBlock ;
*   RDN - 20130227 - Clear the positive energy offer set
    option clear = positiveEnergyOffer ;
    option clear = reserveOfferProportion ;
    option clear = reserveOfferMaximum ;
    option clear = reserveOfferPrice ;
    option clear = validReserveOfferBlock ;
    option clear = offer ;
*   RDN - Primary-secondary offer mapping
    option clear = primarySecondaryOffer ;
    option clear = hasSecondaryOffer ;
    option clear = hasPrimaryOffer ;
*   Bid
    option clear = purchaseBidMW ;
    option clear = purchaseBidPrice ;
    option clear = validPurchaseBidBlock ;
    option clear = purchaseBidILRMW ;
    option clear = purchaseBidILRPrice ;
    option clear = validPurchaseBidILRBlock ;
    option clear = bidNode ;
    option clear = bid ;
*   Demand
    option clear = nodeDemand ;
*   Network
    option clear = ACbranchSendingBus ;
    option clear = ACbranchReceivingBus ;
    option clear = ACbranchSendingBus ;
    option clear = ACbranchReceivingBus ;
    option clear = HVDClinkSendingBus ;
    option clear = HVDClinkReceivingBus ;
    option clear = HVDClinkBus ;
    option clear = ACbranchCapacity ;
    option clear = HVDClinkCapacity ;
    option clear = ACbranchResistance ;
    option clear = ACbranchSusceptance ;
    option clear = ACbranchFixedLoss ;
    option clear = ACbranchLossBlocks ;
    option clear = HVDClinkResistance ;
    option clear = HVDClinkFixedLoss ;
    option clear = HVDClinkLossBlocks ;
    option clear = ACbranchOpenStatus ;
    option clear = ACbranchClosedStatus ;
    option clear = HVDClinkOpenStatus ;
    option clear = HVDClinkClosedStatus ;
    option clear = lossSegmentMW ;
    option clear = lossSegmentFactor ;
    option clear = validLossSegment ;
    option clear = closedBranch ;
    option clear = openBranch ;
    option clear = ACbranch ;
    option clear = HVDChalfPoles ;
    option clear = HVDCpoles ;
    option clear = HVDClink ;
    option clear = HVDCpoleDirection ;
    option clear = lossBranch ;
    option clear = branchBusDefn ;
    option clear = branchBusConnect ;
    option clear = branch ;
    option clear = nodeBus ;
    option clear = nodeIsland ;
    option clear = busIsland ;
    option clear = HVDCnode ;
    option clear = ACnode ;
    option clear = referenceNode ;
    option clear = bus ;
    option clear = node ;
    option clear = DCbus ;
    option clear = ACbus ;
*   RDN - Clear the allow HVDC roundpower flag
    option clear = allowHVDCroundpower ;
*   Risk/Reserves
    option clear = freeReserve ;
    option clear = islandRiskAdjustmentFactor ;
    option clear = HVDCpoleRampUp ;
    option clear = islandMinimumRisk ;
    option clear = reserveClassGenerationMaximum ;
    option clear = reserveMaximumFactor ;
    option clear = ILreserveType ;
    option clear = PLSRreserveType ;
    option clear = manualRisk ;
    option clear = HVDCrisk ;
    option clear = genRisk ;
    option clear = islandOffer ;
    option clear = islandBid ;
    option clear = islandRiskGenerator ;
    option clear = riskGenerator ;
*   RDN - Define contingent and extended contingent events for CE and ECE risks
    option clear = contingentEvents ;
    option clear = extendedContingentEvent ;
*   RDN - Clear the HVDC secondary risk data
    option clear = HVDCsecRisk ;
    option clear = HVDCsecRiskEnabled ;
    option clear = HVDCsecRiskSubtractor ;
    option clear = HVDCsecIslandMinimumRisk ;
*   branch Constraints
    option clear = branchConstraint ;
    option clear = branchConstraintFactors ;
    option clear = branchConstraintSense ;
    option clear = branchConstraintLimit ;
*   AC Node Constraints
    option clear = ACnodeConstraint ;
    option clear = ACnodeConstraintFactors ;
    option clear = ACnodeConstraintSense ;
    option clear = ACnodeConstraintLimit ;
*   Market Node Constraints
    option clear = MnodeConstraint ;
    option clear = MnodeEnergyOfferConstraintFactors ;
    option clear = MnodeReserveOfferConstraintFactors ;
    option clear = MnodeEnergyBidConstraintFactors ;
    option clear = MnodeILReserveBidConstraintFactors ;
    option clear = MnodeConstraintSense ;
    option clear = MnodeConstraintLimit ;
*   Mixed Constraints
    option clear = type1MixedConstraint ;
    option clear = type2MixedConstraint ;
    option clear = type1MixedConstraintCondition ;
    option clear = type1MixedConstraintSense ;
    option clear = type1MixedConstraintLimit1 ;
    option clear = type1MixedConstraintLimit2 ;
    option clear = type2MixedConstraintSense ;
    option clear = type2MixedConstraintLimit ;
*   Generic Constraints
    option clear = genericConstraint ;
    option clear = genericEnergyOfferConstraintFactors ;
    option clear = genericReserveOfferConstraintFactors ;
    option clear = genericEnergyBidConstraintFactors ;
    option clear = genericILReserveBidConstraintFactors ;
    option clear = genericBranchConstraintFactors ;
    option clear = genericConstraintSense ;
    option clear = genericConstraintLimit ;
*   Additional parameters
    option clear = generationMaximum ;
    option clear = rampTimeUp ;
    option clear = rampTimeDown ;
    option clear = rampTimeUp ;
    option clear = generationEndUp ;
    option clear = generationMinimum ;
    option clear = rampTimeDown ;
    option clear = generationEndDown ;
    option clear = ACbranchLossMW ;
    option clear = ACbranchLossFactor ;
    option clear = HVDCbreakPointMWFlow ;
    option clear = HVDCbreakPointMWLoss ;
    option clear = useMixedConstraintMIP ;
    option clear = circularBranchFlowExist ;
*   RDN - Clear the pole circular branch flow flag
    option clear = poleCircularBranchFlowExist ;
    option clear = northHVDC ;
    option clear = southHVDC ;
    option clear = manualBranchSegmentMWFlow ;
    option clear = manualLossCalculation ;
    option clear = nonPhysicalLossExist ;
    option clear = useBranchFlowMIP ;
    option clear = modelSolved ;
    option clear = LPmodelSolved ;
    option clear = LPvalid ;
    option clear = branchFlowMIPInvoked ;
*   Disconnected bus post-processing
    option clear = busGeneration ;
    option clear = busLoad ;
    option clear = busDisconnected ;
    option clear = busPrice ;
*   Run logic
    option clear = skipResolve ;

*   ========================================================================================
*   b) Initialise current trade period and model data for the current trade period

*   Set the currTP
*   For sequential solve
    currTP(tp)$(sequentialsolve and (ord(tp) eq iterationCount)) = yes$i_studyTradePeriod(tp) ;
*   For simultaneous solve
    currTP(tp)$( not (sequentialsolve) ) = yes$i_studyTradePeriod(tp) ;
    iterationCount$( not (sequentialsolve) ) = numTradePeriods ;

*   RDN - 20130302 - i_tradePeriodNodeBusAllocationFactor update - Start-----------
*   Updated offer initialisation - offer must be mapped to a node that is mapped to a bus that is not in electrical island = 0 when the i_useBusNetworkModel flag is set to true
*   Pre MSP case
    offer(currTP,o)$( not ( i_useBusNetworkModel(currTP) ) and
                                        ( sum((n,b)$( i_tradePeriodOfferNode(currTP,o,n) and i_tradePeriodNodeBus(currTP,n,b) ), 1 ) )
                                      ) = yes ;
*   Post MSP case
    offer(currTP,o)$( i_useBusNetworkModel(currTP) and
                                        ( sum((n,b)$( i_tradePeriodOfferNode(currTP,o,n) and i_tradePeriodNodeBus(currTP,n,b) and
                                          i_tradePeriodBusElectricalIsland(currTP,b) ), 1 )
                                        )
                                      ) = yes ;
*   RDN - Updated offer initialisation - offer must be mapped to a node that is mapped to a bus with non-zero allocation factor
*   offer(currTP,o)$(sum((n,b)$(i_tradePeriodOfferNode(currTP,o,n) and
*   i_tradePeriodNodeBus(currTP,n,b) and i_tradePeriodNodeBusAllocationFactor(currTP,n,b)),1)) = yes ;
*   Initialise offer data for the current trade period
*   Offer(currTP,o)$(sum(n$i_tradePeriodOfferNode(currTP,o,n),1)) = yes ;
*   RDN - 20130302 - i_tradePeriodNodeBusAllocationFactor update - End-------------

    node(currTP,n)$i_tradePeriodNode(currTP,n) = yes ;
    offerNode(currTP,o,n)$i_tradePeriodOfferNode(currTP,o,n) = yes ;

    generationStart(offer) = sum(i_offerParam$( ord(i_offerParam) = 1 ), i_tradePeriodOfferParameter(offer,i_offerParam) ) ;
    rampRateUp(offer)      = sum(i_offerParam$( ord(i_offerParam) = 2 ), i_tradePeriodOfferParameter(offer,i_offerParam) ) ;
    rampRateDown(offer)    = sum(i_offerParam$( ord(i_offerParam) = 3 ), i_tradePeriodOfferParameter(offer,i_offerParam) ) ;

    reserveGenerationMaximum(offer) = sum(i_offerParam$( ord(i_offerParam) = 4 ), i_tradePeriodOfferParameter(offer,i_offerParam) ) ;
    windOffer(offer)                = sum(i_offerParam$( ord(i_offerParam) = 5 ), i_tradePeriodOfferParameter(offer,i_offerParam) ) ;

*   RDN - Set the FKband
    FKband(offer) = sum(i_offerParam$( ord(i_offerParam) = 6 ), i_tradePeriodOfferParameter(offer,i_offerParam) ) ;

*   RDN - Set the primary-secondary offer combinations
    primarySecondaryOffer(currTP,o,o1) = i_tradePeriodPrimarySecondaryOffer(currTP,o,o1) ;

    generationOfferMW(offer,trdBlk)    = sum(i_energyOfferComponent$( ord(i_energyOfferComponent) = 1 ), i_tradePeriodEnergyOffer(offer,trdBlk,i_energyOfferComponent) ) ;
    generationOfferPrice(offer,trdBlk) = sum(i_energyOfferComponent$( ord(i_energyOfferComponent) = 2 ), i_tradePeriodEnergyOffer(offer,trdBlk,i_energyOfferComponent) ) ;

*   Valid generation offer blocks are defined as those with a non-zero block capacity or a non-zero price
*   Re-define valid generation offer block to be a block with a positive block limit
*   validGenerationOfferBlock(offer,trdBlk)$( generationOfferMW(offer,trdBlk) + generationOfferPrice(offer,trdBlk) ) = yes ;
    validGenerationOfferBlock(offer,trdBlk)$( generationOfferMW(offer,trdBlk) > 0 ) = yes ;

*   Define set of positive energy offers
    positiveEnergyOffer(offer)$( sum(trdBlk$validGenerationOfferBlock(offer,trdBlk), 1 ) ) = yes ;

    reserveOfferProportion(offer,trdBlk,i_reserveClass)$( ord(i_reserveClass) = 1 )
      = sum(i_PLSRofferComponent$( ord(i_PLSRofferComponent) = 1 ), i_tradePeriodFastPLSRoffer(offer,trdBlk,i_PLSRofferComponent) / 100 ) ;
    reserveOfferProportion(offer,trdBlk,i_reserveClass)$( ord(i_reserveClass) = 2 )
      = sum(i_PLSRofferComponent$( ord(i_PLSRofferComponent) = 1 ), i_tradePeriodSustainedPLSRoffer(offer,trdBlk,i_PLSRofferComponent) / 100 ) ;

    reserveOfferMaximum(offer,trdBlk,i_reserveClass,i_reserveType)$(( ord(i_reserveClass) = 1 ) and ( ord(i_reserveType) = 1 ) )
      = sum(i_PLSRofferComponent$( ord(i_PLSRofferComponent) = 2 ), i_tradePeriodFastPLSRoffer(offer,trdBlk,i_PLSRofferComponent)) ;
    reserveOfferMaximum(offer,trdBlk,i_reserveClass,i_reserveType)$(( ord(i_reserveClass) = 2) and (ord(i_reserveType) = 1))
      = sum(i_PLSRofferComponent$( ord(i_PLSRofferComponent) = 2 ), i_tradePeriodSustainedPLSRoffer(offer,trdBlk,i_PLSRofferComponent)) ;

    reserveOfferMaximum(offer,trdBlk,i_reserveClass,i_reserveType)$(( ord(i_reserveClass) = 1 ) and ( ord(i_reserveType) = 2 ) )
      = sum(i_TWDRofferComponent$( ord(i_TWDRofferComponent) = 1 ), i_tradePeriodFastTWDRoffer(offer,trdBlk,i_TWDRofferComponent) ) ;
    reserveOfferMaximum(offer,trdBlk,i_reserveClass,i_reserveType)$(( ord(i_reserveClass) = 2 ) and ( ord(i_reserveType) = 2 ) )
      = sum(i_TWDRofferComponent$( ord(i_TWDRofferComponent) = 1 ), i_tradePeriodSustainedTWDRoffer(offer,trdBlk,i_TWDRofferComponent)) ;

    reserveOfferMaximum(offer,trdBlk,i_reserveClass,i_reserveType)$(( ord(i_reserveClass) = 1 ) and ( ord(i_reserveType) = 3 ) )
      = sum(i_ILRofferComponent$( ord(i_ILRofferComponent) = 1 ), i_tradePeriodFastILRoffer(offer,trdBlk,i_ILRofferComponent) ) ;
    reserveOfferMaximum(offer,trdBlk,i_reserveClass,i_reserveType)$(( ord(i_reserveClass) = 2 ) and ( ord(i_reserveType) = 3 ) )
      = sum(i_ILRofferComponent$( ord(i_ILRofferComponent) = 1 ), i_tradePeriodSustainedILRoffer(offer,trdBlk,i_ILRofferComponent)) ;

    reserveOfferPrice(offer,trdBlk,i_reserveClass,i_reserveType)$(( ord(i_reserveClass) = 1 ) and ( ord(i_reserveType) = 1 ) )
      = sum(i_PLSRofferComponent$( ord(i_PLSRofferComponent) = 3 ), i_tradePeriodFastPLSRoffer(offer,trdBlk,i_PLSRofferComponent)) ;
    reserveOfferPrice(offer,trdBlk,i_reserveClass,i_reserveType)$(( ord(i_reserveClass) = 2 ) and ( ord(i_reserveType) = 1 ) )
      = sum(i_PLSRofferComponent$( ord(i_PLSRofferComponent) = 3 ), i_tradePeriodSustainedPLSRoffer(offer,trdBlk,i_PLSRofferComponent)) ;

    reserveOfferPrice(offer,trdBlk,i_reserveClass,i_reserveType)$(( ord(i_reserveClass) = 1 ) and ( ord(i_reserveType) = 2 ) )
      = sum(i_TWDRofferComponent$( ord(i_TWDRofferComponent) = 2 ), i_tradePeriodFastTWDRoffer(offer,trdBlk,i_TWDRofferComponent)) ;
    reserveOfferPrice(offer,trdBlk,i_reserveClass,i_reserveType)$(( ord(i_reserveClass) = 2 ) and ( ord(i_reserveType) = 2 ) )
      = sum(i_TWDRofferComponent$( ord(i_TWDRofferComponent) = 2 ), i_tradePeriodSustainedTWDRoffer(offer,trdBlk,i_TWDRofferComponent)) ;

    reserveOfferPrice(offer,trdBlk,i_reserveClass,i_reserveType)$(( ord(i_reserveClass) = 1 ) and ( ord(i_reserveType) = 3 ) )
      = sum(i_ILRofferComponent$( ord(i_ILRofferComponent) = 2 ), i_tradePeriodFastILRoffer(offer,trdBlk,i_ILRofferComponent)) ;
    reserveOfferPrice(offer,trdBlk,i_reserveClass,i_reserveType)$(( ord(i_reserveClass) = 2 ) and ( ord(i_reserveType) = 3 ) )
      = sum(i_ILRofferComponent$( ord(i_ILRofferComponent) = 2 ), i_tradePeriodSustainedILRoffer(offer,trdBlk,i_ILRofferComponent)) ;

*   Valid reserve offer block for each reserve class and reserve type are defined as those with a non-zero block capacity OR a non-zero block price
*   Re-define valid reserve offer block to be a block with a positive block limit
    validReserveOfferBlock(offer,trdBlk,i_reserveClass,i_reserveType)$( reserveOfferMaximum(offer,trdBlk,i_reserveClass,i_reserveType) > 0 )
      = yes ;

*   Initialise demand data for the current trade period
    nodeDemand(node) = i_tradePeriodNodeDemand(node) ;

*   RDN - 20130302 - i_tradePeriodNodeBusAllocationFactor update - Start-----------
*   Updated bid initialisation - Bid must be mapped to a node that is mapped to a bus that is not in electrical island = 0 when the i_useBusNetworkModel flag is set to true
*   Pre MSP case
    bid(currTP,i_bid)$( not (i_useBusNetworkModel(currTP) ) and
                                    ( sum((n,b)$( i_tradePeriodBidNode(currTP,i_bid,n) and i_tradePeriodNodeBus(currTP,n,b) ), 1 ) )
                                  ) = yes ;
*   Post MSP case
    bid(currTP,i_bid)$( i_useBusNetworkModel(currTP) and
                                    ( sum((n,b)$( i_tradePeriodBidNode(currTP,i_bid,n) and i_tradePeriodNodeBus(currTP,n,b) and i_tradePeriodBusElectricalIsland(currTP,b) ), 1 ) )
                                   ) = yes ;
*   RDN - Updated bid initialisation in accordance with change made to the offer definition above - Bid must be mapped to a node that is mapped to a bus with non-zero allocation factor
*     bid(currTP,i_bid)$(sum((n,b)$(i_tradePeriodBidNode(currTP,i_bid,n) and i_tradePeriodNodeBus(currTP,n,b) and i_tradePeriodNodeBusAllocationFactor(currTP,n,b)),1)) = yes ;
*   Initialise bid data for the current trade period
*     bid(tp,i_bid)$(sum(n$i_tradePeriodBidNode(tp,i_bid,n),1) and currTP(tp)) = yes ;
*   RDN - 20130302 - i_tradePeriodNodeBusAllocationFactor update - End-------------

    bidNode(bid,n)$i_tradePeriodBidNode(bid,n) = yes ;

    purchaseBidMW(bid,trdBlk)
      = sum(i_energyBidComponent$( ord(i_energyBidComponent) = 1 ), i_tradePeriodEnergyBid(bid,trdBlk,i_energyBidComponent)) ;
    purchaseBidPrice(bid,trdBlk)
      = sum(i_energyBidComponent$( ord(i_energyBidComponent) = 2 ), i_tradePeriodEnergyBid(bid,trdBlk,i_energyBidComponent)) ;

*   RDN - Change to demand bid
*   Valid purchaser bid blocks are defined as those with a non-zero block capacity OR a non-zero block price
*   Re-define valid purchase bid block to be a block with a positive block limit
*      ValidPurchaseBidBlock(bid,trdBlk)$(PurchaseBidMW(bid,trdBlk) > 0) = yes ;
*      ValidPurchaseBidBlock(bid,trdBlk)$(PurchaseBidMW(bid,trdBlk) + PurchaseBidPrice(bid,trdBlk)) = yes ;
*   Re-define valid purchase bid block to be a block with a non-zero block limit since both positive and negative limits are allowed
*   with changes to the demand bids following DSBF implementation
    validPurchaseBidBlock(bid,trdBlk)$( ( not useDSBFDemandBidModel ) and ( purchaseBidMW(bid,trdBlk) > 0 ) ) = yes ;
    validPurchaseBidBlock(bid,trdBlk)$( useDSBFDemandBidModel and ( purchaseBidMW(bid,trdBlk) <> 0) ) = yes ;

*   RDN - Change to demand bid - End
    purchaseBidILRMW(bid,trdBlk,i_reserveClass)$( ord(i_reserveClass) = 1 )
      = sum(i_ILRbidComponent$( ord(i_ILRbidComponent ) = 1), i_tradePeriodFastILRbid(bid,trdBlk,i_ILRbidComponent) ) ;
    purchaseBidILRPrice(bid,trdBlk,i_reserveClass)$( ord(i_reserveClass) = 1 )
      = sum(i_ILRbidComponent$( ord(i_ILRbidComponent) = 2 ), i_tradePeriodFastILRbid(bid,trdBlk,i_ILRbidComponent) ) ;

    purchaseBidILRMW(bid,trdBlk,i_reserveClass)$( ord(i_reserveClass) = 2 )
      = sum(i_ILRbidComponent$( ord(i_ILRbidComponent) = 1 ), i_tradePeriodSustainedILRbid(bid,trdBlk,i_ILRbidComponent) ) ;
    purchaseBidILRPrice(bid,trdBlk,i_reserveClass)$( ord(i_reserveClass) = 2 )
      = sum(i_ILRbidComponent$( ord(i_ILRbidComponent) = 2 ), i_tradePeriodSustainedILRbid(bid,trdBlk,i_ILRbidComponent) ) ;
*   Valid purchaser ILR blocks are defined as those with a non-zero block capacity OR a non-zero block price
*   Re-define valid purchase ILR offer block to be a block with a positive block limit
    validPurchaseBidILRBlock(bid,trdBlk,i_reserveClass)$( purchaseBidILRMW(bid,trdBlk,i_reserveClass) > 0 ) = yes ;

*   Initialise network data for the current trade period
    bus(currTP,b)$i_tradePeriodBus(currTP,b) = yes ;
    nodeBus(node,b)$i_tradePeriodNodeBus(node,b) = yes ;
    nodeIsland(currTP,n,ild)$( node(currTP,n ) and
      sum(b$( bus(currTP,b) and i_tradePeriodBusIsland(currTP,b,ild) and nodeBus(currTP,n,b) ), 1 ) ) = yes ;

*   Introduce bus island mapping
*   busIsland(currTP,b,ild)$bus(currTP,b) = i_tradePeriodBusIsland(currTP,b,ild) ;
    busIsland(Bus,ild) = i_tradePeriodBusIsland(bus,ild) ;

    HVDCnode(node)$i_tradePeriodHVDCnode(node) = yes ;
    ACnode(node)$( not HVDCnode(node)) = yes ;
    referenceNode(node)$i_tradePeriodReferenceNode(node) = yes ;

    DCbus(currTP,b)$( sum(nodeBus(HVDCnode(currTP,n),b), 1 ) ) = yes ;
    ACbus(currTP,b)$( not (sum(nodeBus(HVDCnode(currTP,n),b), 1) ) ) = yes ;

*   Node-bus allocation factor
    nodeBusAllocationFactor(currTP,n,b)$( node(currTP,n) and bus(currTP,b) )
      = i_tradePeriodNodeBusAllocationFactor(currTP,n,b) ;

*   Bus live island status
    busElectricalIsland(bus) = i_tradePeriodBusElectricalIsland(bus) ;

*   Branch is defined if there is a defined terminal bus, it is defined for the trade period, it has a non-zero capacity and is closed for that trade period
*   Branch(currTP,br)$(sum((frB,toB)$(bus(currTP,frB) and bus(currTP,toB) and i_tradePeriodBranchDefn(currTP,br,frB,toB)),1))
    branch(currTP,br)$(
      sum((frB,toB)$( bus(currTP,frB) and bus(currTP,toB) and i_tradePeriodBranchDefn(currTP,br,frB,toB) ), 1 )
      and i_tradePeriodBranchCapacity(currTP,br) and ( not (i_tradePeriodBranchOpenStatus(currTP,br) ) ) )
      = yes ;
    branchBusDefn(branch,frB,toB)$i_tradePeriodBranchDefn(branch,frB,toB) = yes ;
    branchBusConnect(branch,b)$sum(b1$( branchBusDefn(branch,b,b1) or branchBusDefn(branch,b1,b) ), 1 ) = yes ;

*   HVDC link definition
    HVDClink(branch)$i_tradePeriodHVDCBranch(branch) = yes ;
    HVDCpoles(branch)$( i_tradePeriodHVDCBranch(branch) = 1 ) = yes ;
    HVDChalfPoles(branch)$( i_tradePeriodHVDCBranch(branch) = 2 ) = yes ;
    ACbranch(branch)$( not HVDClink(branch) ) = yes ;

*   RDN - Flag to allow roundpower on the HVDC link
    allowHVDCroundpower(currTP) = i_tradePeriodAllowHVDCroundpower(currTP) ;

* RDN - 20130730 - Optimise pre-processing - Start------------------------------
*   Determine sending and receiving bus sets
*    ACbranchSendingBus(ACbranch,frB,i_flowDirection)$(sum(branchBusDefn(ACbranch,frB,toB),1) and (ord(i_flowDirection) = 1)) = yes ;
*    ACbranchReceivingBus(ACbranch,toB,i_flowDirection)$(sum(branchBusDefn(ACbranch,frB,toB),1) and (ord(i_flowDirection) = 1)) = yes ;
*    ACbranchSendingBus(ACbranch,toB,i_flowDirection)$(sum(branchBusDefn(ACbranch,frB,toB),1) and (ord(i_flowDirection) = 2)) = yes ;
*    ACbranchReceivingBus(ACbranch,frB,i_flowDirection)$(sum(branchBusDefn(ACbranch,frB,toB),1) and (ord(i_flowDirection) = 2)) = yes ;
    loop((frB,toB),
        ACbranchSendingBus(ACbranch,frB,i_flowDirection)$(branchBusDefn(ACbranch,frB,toB) and (ord(i_flowDirection) = 1)) = yes ;
        ACbranchReceivingBus(ACbranch,toB,i_flowDirection)$(branchBusDefn(ACbranch,frB,toB) and (ord(i_flowDirection) = 1)) = yes ;
        ACbranchSendingBus(ACbranch,toB,i_flowDirection)$(branchBusDefn(ACbranch,frB,toB) and (ord(i_flowDirection) = 2)) = yes ;
        ACbranchReceivingBus(ACbranch,frB,i_flowDirection)$(branchBusDefn(ACbranch,frB,toB) and (ord(i_flowDirection) = 2)) = yes ;
    );
* RDN - 20130730 - Optimise pre-processing - End--------------------------------

    HVDClinkSendingBus(HVDClink,frB)$sum(branchBusDefn(HVDClink,frB,toB),1) = yes ;
    HVDClinkReceivingBus(HVDClink,toB)$sum(branchBusDefn(HVDClink,frB,toB),1) = yes ;
    HVDClinkBus(HVDClink,b)$(HVDClinkSendingBus(HVDClink,b) or HVDClinkReceivingBus(HVDClink,b)) = yes ;

*   Determine the HVDC inter-island pole in the northward and southward direction
    HVDCpoleDirection(currTP,br,i_flowDirection)$((ord(i_flowDirection) = 1) and (HVDClink(currTP,br)) and sum((ild,NodeBus(currTP,n,b))$((ord(ild) = 2) and NodeIsland(currTP,n,ild) and HVDClinkSendingBus(currTP,br,b)),1))
       = yes ;
    HVDCpoleDirection(currTP,br,i_flowDirection)$((ord(i_flowDirection) = 1) and (HVDClink(currTP,br)) and sum((ild,NodeBus(currTP,n,b))$((ord(ild) = 2) and NodeIsland(currTP,n,ild) and HVDClinkReceivingBus(currTP,br,b)),1))
       = no ;
    HVDCpoleDirection(currTP,br,i_flowDirection)$((ord(i_flowDirection) = 2) and (HVDClink(currTP,br)) and sum((ild,NodeBus(currTP,n,b))$((ord(ild) = 1) and NodeIsland(currTP,n,ild) and HVDClinkSendingBus(currTP,br,b)),1))
       = yes ;
    HVDCpoleDirection(currTP,br,i_flowDirection)$((ord(i_flowDirection) = 2) and (HVDClink(currTP,br)) and sum((ild,NodeBus(currTP,n,b))$((ord(ild) = 1) and NodeIsland(currTP,n,ild) and HVDClinkReceivingBus(currTP,br,b)),1))
       = no ;

* RDN - Map of HVDC branch to pole
*    HVDCpoleBranchMap('Pole1','BEN_HAY1.1') = yes ;
*    HVDCpoleBranchMap('Pole1','HAY_BEN1.1') = yes ;
*    HVDCpoleBranchMap('Pole2','BEN_HAY2.1') = yes ;
*    HVDCpoleBranchMap('Pole2','HAY_BEN2.1') = yes ;

* TN - Updated map of HVDC branch to pole to account for name changes to Pole 3
    HVDCpoleBranchMap('Pole1',br)$sum(sameas(br,'BEN_HAY1.1'),1) = yes ;
    HVDCpoleBranchMap('Pole1',br)$sum(sameas(br,'HAY_BEN1.1'),1) = yes ;
    HVDCpoleBranchMap('Pole1',br)$sum(sameas(br,'BEN_HAY3.1'),1) = yes ;
    HVDCpoleBranchMap('Pole1',br)$sum(sameas(br,'HAY_BEN3.1'),1) = yes ;
    HVDCpoleBranchMap('Pole2',br)$sum(sameas(br,'BEN_HAY2.1'),1) = yes ;
    HVDCpoleBranchMap('Pole2',br)$sum(sameas(br,'HAY_BEN2.1'),1) = yes ;

* Allocate the input branch parameters to the defined model parameters
    ACbranchCapacity(ACbranch) = i_tradePeriodBranchCapacity(ACbranch) ;
    HVDClinkCapacity(HVDClink) = i_tradePeriodBranchCapacity(HVDClink) ;

    ACbranchResistance(ACbranch) = sum(i_branchParameter$(ord(i_branchParameter) = 1), i_tradePeriodBranchParameter(ACbranch,i_branchParameter)) ;
* RDN - Convert susceptance from -Bpu to B%
*   ACbranchSusceptance(ACbranch) = sum(i_branchParameter$(ord(i_branchParameter) = 2), i_tradePeriodBranchParameter(ACbranch,i_branchParameter)) ;
    ACbranchSusceptance(ACbranch) = -100*sum(i_branchParameter$(ord(i_branchParameter) = 2), i_tradePeriodBranchParameter(ACbranch,i_branchParameter)) ;
    ACbranchLossBlocks(ACbranch) = sum(i_branchParameter$(ord(i_branchParameter) = 4), i_tradePeriodBranchParameter(ACbranch,i_branchParameter)) ;
* Ensure fixed losses for no loss branches are not included
*   ACbranchFixedLoss(ACbranch) = sum(i_branchParameter$(ord(i_branchParameter) = 3), i_tradePeriodBranchParameter(ACbranch,i_branchParameter)) ;
    ACbranchFixedLoss(ACbranch) = sum(i_branchParameter$(ord(i_branchParameter) = 3), i_tradePeriodBranchParameter(ACbranch,i_branchParameter))$(ACbranchLossBlocks(ACbranch) > 1) ;

    HVDClinkResistance(HVDClink) = sum(i_branchParameter$(ord(i_branchParameter) = 1), i_tradePeriodBranchParameter(HVDClink,i_branchParameter)) ;
    HVDClinkFixedLoss(HVDClink) = sum(i_branchParameter$(ord(i_branchParameter) = 3), i_tradePeriodBranchParameter(HVDClink,i_branchParameter)) ;
    HVDClinkLossBlocks(HVDClink) = sum(i_branchParameter$(ord(i_branchParameter) = 4), i_tradePeriodBranchParameter(HVDClink,i_branchParameter)) ;

* Set resistance and fixed loss to zero if do not want to use the loss model
    ACbranchResistance(ACbranch)$(not useAClossModel) = 0 ;
    ACbranchFixedLoss(ACbranch)$(not useAClossModel) = 0 ;

    HVDClinkResistance(HVDClink)$(not useHVDClossModel) = 0 ;
    HVDClinkFixedLoss(HVDClink)$(not useHVDClossModel) = 0 ;

* Determine branch open and closed status
* Open status is provided but this is converted to a closed status since this is more compact to use in the formulation
* Used for Implementation 1 and 2.  Remove if using Implementation 3.
    ACbranchOpenStatus(ACbranch) = i_tradePeriodBranchOpenStatus(ACbranch) ;
    ACbranchClosedStatus(ACbranch) = 1 - ACbranchOpenStatus(ACbranch) ;
    HVDClinkOpenStatus(HVDClink) = i_tradePeriodBranchOpenStatus(HVDClink) ;
    HVDClinkClosedStatus(HVDClink) = 1 - HVDClinkOpenStatus(HVDClink) ;
* Used for Implementation 3
    ClosedBranch(branch)$(not i_tradePeriodBranchOpenStatus(branch)) = yes ;
    OpenBranch(branch)$(not ClosedBranch(branch)) = yes ;

* The loss factor coefficients assume that the branch capacity is in MW and the resistance is in p.u.
* Branches (AC and HVDC) with 1 loss segment
* RDN - Ensure only the 1st loss segment is used for branches with <= 1 loss blocks - Start--------------------------
*         lossSegmentMW(ClosedBranch(ACbranch),los)$((ACbranchLossBlocks(ACbranch) <= 1)  and (not useExternalLossModel)) = sum(i_lossParameter$(ord(i_lossParameter) = 1), i_noLossBranch(los,i_lossParameter)) ;
*         lossSegmentFactor(ClosedBranch(ACbranch),los)$((ACbranchLossBlocks(ACbranch) <= 1) and (not useExternalLossModel)) = sum(i_lossParameter$(ord(i_lossParameter) = 2), i_noLossBranch(los,i_lossParameter) * ACbranchResistance(ACbranch) * ACbranchCapacity(ACbranch)) ;
*         lossSegmentMW(ClosedBranch(HVDClink),los)$((HVDClinkLossBlocks(HVDClink) <= 1) and (not useExternalLossModel)) = sum(i_lossParameter$(ord(i_lossParameter) = 1), i_noLossBranch(los,i_lossParameter)) ;
*         lossSegmentFactor(ClosedBranch(HVDClink),los)$((HVDClinkLossBlocks(HVDClink) <= 1) and (not useExternalLossModel)) = sum(i_lossParameter$(ord(i_lossParameter) = 2), i_noLossBranch(los,i_lossParameter) * HVDClinkResistance(HVDClink) * HVDClinkCapacity(HVDClink)) ;

         lossSegmentMW(ClosedBranch(ACbranch),los)$((ACbranchLossBlocks(ACbranch) <= 1)  and (not useExternalLossModel) and (ord(los) = 1)) = sum(i_lossParameter$(ord(i_lossParameter) = 1), i_noLossBranch(los,i_lossParameter)) ;
         lossSegmentFactor(ClosedBranch(ACbranch),los)$((ACbranchLossBlocks(ACbranch) <= 1) and (not useExternalLossModel) and (ord(los) = 1)) = sum(i_lossParameter$(ord(i_lossParameter) = 2), i_noLossBranch(los,i_lossParameter) * ACbranchResistance(ACbranch) * ACbranchCapacity(ACbranch)) ;
         lossSegmentMW(ClosedBranch(HVDClink),los)$((HVDClinkLossBlocks(HVDClink) <= 1) and (not useExternalLossModel) and (ord(los) = 1)) = sum(i_lossParameter$(ord(i_lossParameter) = 1), i_noLossBranch(los,i_lossParameter)) ;
         lossSegmentFactor(ClosedBranch(HVDClink),los)$((HVDClinkLossBlocks(HVDClink) <= 1) and (not useExternalLossModel) and (ord(los) = 1)) = sum(i_lossParameter$(ord(i_lossParameter) = 2), i_noLossBranch(los,i_lossParameter) * HVDClinkResistance(HVDClink) * HVDClinkCapacity(HVDClink)) ;

* RDN - Ensure only the 1st loss segment is used for branches with <= 1 loss blocks - End--------------------------

* Use the external loss model as provided by Transpower
* RDN - Ensure only the 1st loss segment is used for branches with 0 loss blocks - Start--------------------------
*         lossSegmentMW(ClosedBranch(ACbranch),los)$((ACbranchLossBlocks(ACbranch) = 0) and useExternalLossModel) = maxFlowSegment ;
*         lossSegmentFactor(ClosedBranch(ACbranch),los)$((ACbranchLossBlocks(ACbranch) = 0) and useExternalLossModel) = 0 ;
*         lossSegmentMW(ClosedBranch(HVDClink),los)$((HVDClinkLossBlocks(HVDClink) = 0) and useExternalLossModel) = maxFlowSegment ;
*         lossSegmentFactor(ClosedBranch(HVDClink),los)$((HVDClinkLossBlocks(HVDClink) = 0) and useExternalLossModel) = 0 ;

         lossSegmentMW(ClosedBranch(ACbranch),los)$((ACbranchLossBlocks(ACbranch) = 0) and useExternalLossModel and (ord(los) = 1)) = maxFlowSegment ;
         lossSegmentFactor(ClosedBranch(ACbranch),los)$((ACbranchLossBlocks(ACbranch) = 0) and useExternalLossModel and (ord(los) = 1)) = 0 ;
         lossSegmentMW(ClosedBranch(HVDClink),los)$((HVDClinkLossBlocks(HVDClink) = 0) and useExternalLossModel and (ord(los) = 1)) = maxFlowSegment ;
         lossSegmentFactor(ClosedBranch(HVDClink),los)$((HVDClinkLossBlocks(HVDClink) = 0) and useExternalLossModel and (ord(los) = 1)) = 0 ;
* RDN - Ensure only the 1st loss segment is used for branches with 0 loss blocks - End----------------------------

* Use the external loss model as provided by Transpower
         lossSegmentMW(ClosedBranch(ACbranch),los)$((ACbranchLossBlocks(ACbranch) = 1) and useExternalLossModel and (ord(los) = 1)) = maxFlowSegment ;
         lossSegmentFactor(ClosedBranch(ACbranch),los)$((ACbranchLossBlocks(ACbranch) = 1) and useExternalLossModel and (ord(los) = 1)) = ACbranchResistance(ACbranch) * ACbranchCapacity(ACbranch) ;
         lossSegmentMW(ClosedBranch(HVDClink),los)$((HVDClinkLossBlocks(HVDClink) = 1) and useExternalLossModel and (ord(los) = 1)) = maxFlowSegment ;
         lossSegmentFactor(ClosedBranch(HVDClink),los)$((HVDClinkLossBlocks(HVDClink) = 1) and useExternalLossModel and (ord(los) = 1)) = HVDClinkResistance(HVDClink) * HVDClinkCapacity(HVDClink) ;

* AC loss branches with more than one loss segment
         lossSegmentMW(ClosedBranch(ACbranch),los)$((not useExternalLossModel) and (ACbranchLossBlocks(ACbranch) > 1) and (ord(los) < ACbranchLossBlocks(ACbranch))) = sum(i_lossParameter$(ord(i_lossParameter) = 1), i_AClossBranch(los,i_lossParameter) * ACbranchCapacity(ACbranch)) ;
         lossSegmentMW(ClosedBranch(ACbranch),los)$((not useExternalLossModel) and (ACbranchLossBlocks(ACbranch) > 1) and (ord(los) = ACbranchLossBlocks(ACbranch))) = sum(i_lossParameter$(ord(i_lossParameter) = 1), i_AClossBranch(los,i_lossParameter)) ;
         lossSegmentFactor(ClosedBranch(ACbranch),los)$((not useExternalLossModel) and (ACbranchLossBlocks(ACbranch) > 1)) = sum(i_lossParameter$(ord(i_lossParameter) = 2), i_AClossBranch(los,i_lossParameter) * ACbranchResistance(ACbranch) * ACbranchCapacity(ACbranch)) ;

* Use the external loss model as provided by Transpower
* Segment 1
         lossSegmentMW(ClosedBranch(ACbranch),los)$(useExternalLossModel and (ACbranchLossBlocks(ACbranch) > 1) and (ord(los) = 1)) = ACbranchCapacity(ACbranch) * lossCoeff_A ;
         lossSegmentFactor(ClosedBranch(ACbranch),los)$(useExternalLossModel and (ACbranchLossBlocks(ACbranch) > 1) and (ord(los) = 1)) = 0.01 * ACbranchResistance(ACbranch) * ACbranchCapacity(ACbranch) * 0.75 * lossCoeff_A ;
* Segment 2
         lossSegmentMW(ClosedBranch(ACbranch),los)$(useExternalLossModel and (ACbranchLossBlocks(ACbranch) > 1) and (ord(los) = 2)) = ACbranchCapacity(ACbranch) * (1-lossCoeff_A) ;
         lossSegmentFactor(ClosedBranch(ACbranch),los)$(useExternalLossModel and (ACbranchLossBlocks(ACbranch) > 1) and (ord(los) = 2)) = 0.01 * ACbranchResistance(ACbranch) * ACbranchCapacity(ACbranch) ;
* Segment 3
         lossSegmentMW(ClosedBranch(ACbranch),los)$(useExternalLossModel and (ACbranchLossBlocks(ACbranch) > 1) and (ord(los) = 3)) = maxFlowSegment ;
         lossSegmentFactor(ClosedBranch(ACbranch),los)$(useExternalLossModel and (ACbranchLossBlocks(ACbranch) > 1) and (ord(los) = 3)) = 0.01 * ACbranchResistance(ACbranch) * ACbranchCapacity(ACbranch) * (2 - (0.75*lossCoeff_A)) ;

* HVDC loss branches with more than one loss segment
         lossSegmentMW(ClosedBranch(HVDClink),los)$((not useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) < HVDClinkLossBlocks(HVDClink))) = sum(i_lossParameter$(ord(i_lossParameter) = 1), i_HVDClossBranch(los,i_lossParameter) * HVDClinkCapacity(HVDClink)) ;
         lossSegmentMW(ClosedBranch(HVDClink),los)$((not useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) = HVDClinkLossBlocks(HVDClink))) = sum(i_lossParameter$(ord(i_lossParameter) = 1), i_HVDClossBranch(los,i_lossParameter)) ;
         lossSegmentFactor(ClosedBranch(HVDClink),los)$((not useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1)) = sum(i_lossParameter$(ord(i_lossParameter) = 2), i_HVDClossBranch(los,i_lossParameter) * HVDClinkResistance(HVDClink) * HVDClinkCapacity(HVDClink)) ;

* Use the external loss model as provided by Transpower
* Segment 1
         lossSegmentMW(ClosedBranch(HVDClink),los)$((useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) = 1)) = HVDClinkCapacity(HVDClink) * lossCoeff_C ;
         lossSegmentFactor(ClosedBranch(HVDClink),los)$((useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) = 1)) = 0.01 * HVDClinkResistance(HVDClink) * HVDClinkCapacity(HVDClink) * 0.75 * lossCoeff_C ;
* Segment 2
         lossSegmentMW(ClosedBranch(HVDClink),los)$((useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) = 2)) = HVDClinkCapacity(HVDClink) * lossCoeff_D ;
         lossSegmentFactor(ClosedBranch(HVDClink),los)$((useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) = 2)) = 0.01 * HVDClinkResistance(HVDClink) * HVDClinkCapacity(HVDClink) * lossCoeff_E ;
* Segment 3
         lossSegmentMW(ClosedBranch(HVDClink),los)$((useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) = 3)) = HVDClinkCapacity(HVDClink) * 0.5 ;
         lossSegmentFactor(ClosedBranch(HVDClink),los)$((useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) = 3)) = 0.01 * HVDClinkResistance(HVDClink) * HVDClinkCapacity(HVDClink) * lossCoeff_F ;
* Segment 4
         lossSegmentMW(ClosedBranch(HVDClink),los)$((useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) = 4)) = HVDClinkCapacity(HVDClink) * (1 - lossCoeff_D) ;
         lossSegmentFactor(ClosedBranch(HVDClink),los)$((useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) = 4)) = 0.01 * HVDClinkResistance(HVDClink) * HVDClinkCapacity(HVDClink) * (2 - lossCoeff_F) ;
* Segment 5
         lossSegmentMW(ClosedBranch(HVDClink),los)$((useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) = 5)) = HVDClinkCapacity(HVDClink) * (1 - lossCoeff_C) ;
         lossSegmentFactor(ClosedBranch(HVDClink),los)$((useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) = 5)) = 0.01 * HVDClinkResistance(HVDClink) * HVDClinkCapacity(HVDClink) * (2 - lossCoeff_E) ;
* Segment 6
         lossSegmentMW(ClosedBranch(HVDClink),los)$((useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) = 6)) = maxFlowSegment ;
         lossSegmentFactor(ClosedBranch(HVDClink),los)$((useExternalLossModel) and (HVDClinkLossBlocks(HVDClink) > 1) and (ord(los) = 6)) = 0.01 * HVDClinkResistance(HVDClink) * HVDClinkCapacity(HVDClink) * (2 - (0.75*lossCoeff_C)) ;

* Valid loss segment for a branch is defined as a loss segment that has a non-zero lossSegmentMW OR a non-zero lossSegmentFactor
* Every branch has at least one loss segment block
    ValidLossSegment(branch,los)$(ord(los) = 1) = yes ;
    ValidLossSegment(branch,los)$((ord(los) > 1) and (lossSegmentMW(branch,los)+lossSegmentFactor(branch,los))) = yes ;
* HVDC loss model requires at least two loss segments and an additional loss block due to cumulative loss formulation
    ValidLossSegment(HVDClink,los)$((HVDClinkLossBlocks(HVDClink) <= 1) and (ord(los) = 2)) = yes ;
    ValidLossSegment(HVDClink,los)$((HVDClinkLossBlocks(HVDClink) > 1) and (sum(los1, lossSegmentMW(HVDClink,los1)+lossSegmentFactor(HVDClink,los1)) > 0) and (ord(los) = (HVDClinkLossBlocks(HVDClink) + 1))) = yes ;

* branches that have non-zero loss factors
    lossBranch(branch)$(sum(los, lossSegmentFactor(branch,los))) = yes ;

* Initialise Risk/Reserve data for the current trading period
    RiskGenerator(offer)$i_tradePeriodRiskGenerator(offer) = yes ;
    IslandRiskGenerator(currTP,ild,o)$(offer(currTP,o) and i_tradePeriodRiskGenerator(currTP,o) and sum(n$(offerNode(currTP,o,n) and NodeIsland(currTP,n,ild)),1))
       = yes ;
    IslandOffer(currTP,ild,o)$(offer(currTP,o) and sum(n$(offerNode(currTP,o,n) and NodeIsland(currTP,n,ild)),1))
       = yes ;

* RDN - If the i_useExtendedRiskClass flag is set, update GenRisk and ManualRisk mapping to the RiskClass set since it now includes additional ECE risk classes associated with GenRisk and ManualRisk
*     GenRisk(i_riskClass)$(ord(i_riskClass) = 1) = yes ;
*     HVDCrisk(i_riskClass)$((ord(i_riskClass) = 2) or (ord(i_riskClass) = 3)) = yes ;
*     ManualRisk(i_riskClass)$(ord(i_riskClass) = 4) = yes ;
    GenRisk(i_riskClass)$((ord(i_riskClass) = 1) and (not (i_useExtendedRiskClass))) = yes ;
    GenRisk(i_riskClass)$(i_useExtendedRiskClass and ((ord(i_riskClass) = 1) or (ord(i_riskClass) = 5))) = yes ;
    ManualRisk(i_riskClass)$((ord(i_riskClass) = 4) and (not (i_useExtendedRiskClass))) = yes ;
    ManualRisk(i_riskClass)$(i_useExtendedRiskClass and ((ord(i_riskClass) = 4) or (ord(i_riskClass) = 6))) = yes ;
    HVDCrisk(i_riskClass)$((ord(i_riskClass) = 2) or (ord(i_riskClass) = 3)) = yes ;
* RDN - Set the HVDCsecRisk class
    HVDCsecRisk(i_riskClass)$(not (i_useExtendedRiskClass)) = no ;
    HVDCsecRisk(i_riskClass)$(i_useExtendedRiskClass and ((ord(i_riskClass) = 7) or (ord(i_riskClass) = 8))) = yes ;

* RDN - Define the CE and ECE risk class set to support the different CE and ECE CVP
*    ExtendedContingentEvent(i_riskClass)$(ord(i_riskClass) = 3) = yes ;
*    ContingentEvents(i_riskClass)$((ord(i_riskClass) = 1) or (ord(i_riskClass) = 2) or (ord(i_riskClass) = 4)) = yes ;

* RDN - If the i_useExtendedRiskClass flag is set, update the extended contingency event defintion to include the additional ECE risks included into the i_riskClass set
    ExtendedContingentEvent(i_riskClass)$((ord(i_riskClass) = 3) and (not (i_useExtendedRiskClass))) = yes ;
    ExtendedContingentEvent(i_riskClass)$(i_useExtendedRiskClass and ((ord(i_riskClass) = 3) or (ord(i_riskClass) = 5) or (ord(i_riskClass) = 6) or (ord(i_riskClass) = 8))) = yes ;
    ContingentEvents(i_riskClass)$((not (i_useExtendedRiskClass)) and ((ord(i_riskClass) = 1) or (ord(i_riskClass) = 2) or (ord(i_riskClass) = 4))) = yes ;
    ContingentEvents(i_riskClass)$(i_useExtendedRiskClass and ((ord(i_riskClass) = 1) or (ord(i_riskClass) = 2) or (ord(i_riskClass) = 4) or (ord(i_riskClass) = 7)) ) = yes ;

    IslandBid(currTP,ild,i_bid)$(bid(currTP,i_bid) and sum(n$(bidNode(currTP,i_bid,n) and NodeIsland(currTP,n,ild)),1))
       = yes ;

    PLSRReserveType(i_reserveType)$(ord(i_reserveType) = 1) = yes ;
    ILReserveType(i_reserveType)$(ord(i_reserveType) = 3) = yes ;

    FreeReserve(currTP,ild,i_reserveClass,i_riskClass)
       = sum(i_riskParameter$(ord(i_riskParameter) = 1), i_tradePeriodRiskParameter(currTP,ild,i_reserveClass,i_riskClass,i_riskParameter)) ;

* RDN - Zero the island risk adjustment factor when useReserveModel flag is set to false - Start----------------
    IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,i_riskClass)
       = sum(i_riskParameter$(ord(i_riskParameter) = 2), i_tradePeriodRiskParameter(currTP,ild,i_reserveClass,i_riskClass,i_riskParameter)) ;

    IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,i_riskClass)$(not (useReserveModel)) = 0 ;
* RDN - Zero the island risk adjustment factor when useReserveModel flag is set to false - End------------------

    HVDCpoleRampUp(currTP,ild,i_reserveClass,i_riskClass)
       = sum(i_riskParameter$(ord(i_riskParameter) = 3), i_tradePeriodRiskParameter(currTP,ild,i_reserveClass,i_riskClass,i_riskParameter)) ;
* RDN - Index IslandMinimumRisk to cater for CE and ECE minimum risk
*    IslandMinimumRisk(currTP,ild,i_reserveClass) = i_tradePeriodManualRisk(currTP,ild,i_reserveClass) ;
    IslandMinimumRisk(currTP,ild,i_reserveClass,i_riskClass)$(ord(i_riskClass) = 4) = i_tradePeriodManualRisk(currTP,ild,i_reserveClass) ;
    IslandMinimumRisk(currTP,ild,i_reserveClass,i_riskClass)$(ord(i_riskClass) = 6) = i_tradePeriodManualRisk_ECE(currTP,ild,i_reserveClass) ;

* RDN - HVDC secondary risk parameters
    HVDCsecRiskEnabled(currTP,ild,i_riskClass) = i_tradePeriodHVDCsecRiskEnabled(currTP,ild,i_riskClass) ;
    HVDCsecRiskSubtractor(currTP,ild) = i_tradePeriodHVDCsecRiskSubtractor(currTP,ild) ;
* RDN - Minimum risks for the HVDC secondary risk are the same as the island minimum risk
    HVDCsecIslandMinimumRisk(currTP,ild,i_reserveClass,i_riskClass)$(ord(i_riskClass) = 7) = i_tradePeriodManualRisk(currTP,ild,i_reserveClass) ;
    HVDCsecIslandMinimumRisk(currTP,ild,i_reserveClass,i_riskClass)$(ord(i_riskClass) = 8) = i_tradePeriodManualRisk_ECE(currTP,ild,i_reserveClass) ;

* Calculation of reserve maximum factor - 5.2.1.1.
    reserveClassGenerationMaximum(offer,i_reserveClass) = ReserveGenerationMaximum(offer) ;
    reserveClassGenerationMaximum(offer,i_reserveClass)$i_tradePeriodReserveClassGenerationMaximum(offer,i_reserveClass) = i_tradePeriodReserveClassGenerationMaximum(offer,i_reserveClass) ;

    ReserveMaximumFactor(offer,i_reserveClass) = 1 ;
    ReserveMaximumFactor(offer,i_reserveClass)$(ReserveClassGenerationMaximum(offer,i_reserveClass)>0) = (ReserveGenerationMaximum(offer) / reserveClassGenerationMaximum(offer,i_reserveClass)) ;

* Initialise branch constraint data for the current trading period
    branchConstraint(currTP,i_branchConstraint)$(sum(br$(branch(currTP,br) and i_tradePeriodBranchConstraintFactors(currTP,i_branchConstraint,br)),1))
       = yes ;
    branchConstraintFactors(branchConstraint,br) = i_tradePeriodBranchConstraintFactors(branchConstraint,br) ;
    branchConstraintSense(branchConstraint) = sum(i_ConstraintRHS$(ord(i_ConstraintRHS) = 1), i_tradePeriodBranchConstraintRHS(branchConstraint,i_ConstraintRHS)) ;
    branchConstraintLimit(branchConstraint) = sum(i_ConstraintRHS$(ord(i_ConstraintRHS) = 2), i_tradePeriodBranchConstraintRHS(branchConstraint,i_ConstraintRHS)) ;

* Initialise AC node constraint data for the current trading period
    ACnodeConstraint(currTP,i_ACnodeConstraint)$(sum(n$(ACnode(currTP,n) and i_tradePeriodACnodeConstraintFactors(currTP,i_ACnodeConstraint,n)),1))
       = yes ;
    ACnodeConstraintFactors(ACnodeConstraint,n) = i_tradePeriodACnodeConstraintFactors(ACnodeConstraint,n) ;
    ACnodeConstraintSense(ACnodeConstraint) = sum(i_ConstraintRHS$(ord(i_ConstraintRHS) = 1), i_tradePeriodACnodeConstraintRHS(ACnodeConstraint,i_ConstraintRHS)) ;
    ACnodeConstraintLimit(ACnodeConstraint) = sum(i_ConstraintRHS$(ord(i_ConstraintRHS) = 2), i_tradePeriodACnodeConstraintRHS(ACnodeConstraint,i_ConstraintRHS)) ;

* Initialise market node constraint data for the current trading period
    MnodeConstraint(currTP,i_MnodeConstraint)$( (sum((o,i_reserveType,i_reserveClass)$(offer(currTP,o) and (i_tradePeriodMnodeEnergyOfferConstraintFactors(currTP,i_MnodeConstraint,o) or i_tradePeriodMnodeReserveOfferConstraintFactors(currTP,i_MnodeConstraint,o,i_reserveClass,i_reserveType))),1))
         or (sum((i_bid,i_reserveClass)$(bid(currTP,i_bid) and (i_tradePeriodMnodeEnergyBidConstraintFactors(currTP,i_MnodeConstraint,i_bid) or i_tradePeriodMnodeILReserveBidConstraintFactors(currTP,i_MnodeConstraint,i_bid,i_reserveClass))),1)) ) = yes ;
    MnodeEnergyOfferConstraintFactors(MnodeConstraint,o) = i_tradePeriodMnodeEnergyOfferConstraintFactors(MnodeConstraint,o) ;
    MnodeReserveOfferConstraintFactors(MnodeConstraint,o,i_reserveClass,i_reserveType) = i_tradePeriodMnodeReserveOfferConstraintFactors(MnodeConstraint,o,i_reserveClass,i_reserveType) ;
    MnodeEnergyBidConstraintFactors(MnodeConstraint,i_bid) = i_tradePeriodMnodeEnergyBidConstraintFactors(MnodeConstraint,i_bid) ;
    MnodeILReserveBidConstraintFactors(MnodeConstraint,i_bid,i_reserveClass) = i_tradePeriodMnodeILReserveBidConstraintFactors(MnodeConstraint,i_bid,i_reserveClass) ;
    MnodeConstraintSense(MnodeConstraint) = sum(i_ConstraintRHS$(ord(i_ConstraintRHS) = 1), i_tradePeriodMnodeConstraintRHS(MnodeConstraint,i_ConstraintRHS)) ;
    MnodeConstraintLimit(MnodeConstraint) = sum(i_ConstraintRHS$(ord(i_ConstraintRHS) = 2), i_tradePeriodMnodeConstraintRHS(MnodeConstraint,i_ConstraintRHS)) ;

* Initialise mixed constraint data for the current trading period
    Type1MixedConstraint(currTP,i_type1MixedConstraint) = i_tradePeriodType1MixedConstraint(currTP,i_type1MixedConstraint) ;
    Type2MixedConstraint(currTP,i_type2MixedConstraint) = i_tradePeriodType2MixedConstraint(currTP,i_type2MixedConstraint) ;
    Type1MixedConstraintSense(currTP,i_type1MixedConstraint) = sum(i_type1MixedConstraintRHS$(ord(i_type1MixedConstraintRHS) = 1), i_tradePeriodType1MixedConstraintRHSParameters(currTP,i_type1MixedConstraint,i_type1MixedConstraintRHS)) ;
    Type1MixedConstraintLimit1(currTP,i_type1MixedConstraint) = sum(i_type1MixedConstraintRHS$(ord(i_type1MixedConstraintRHS) = 2), i_tradePeriodType1MixedConstraintRHSParameters(currTP,i_type1MixedConstraint,i_type1MixedConstraintRHS)) ;
    Type1MixedConstraintLimit2(currTP,i_type1MixedConstraint) = sum(i_type1MixedConstraintRHS$(ord(i_type1MixedConstraintRHS) = 3), i_tradePeriodType1MixedConstraintRHSParameters(currTP,i_type1MixedConstraint,i_type1MixedConstraintRHS)) ;
    Type2MixedConstraintSense(currTP,i_type2MixedConstraint) = sum(i_ConstraintRHS$(ord(i_ConstraintRHS) = 1), i_tradePeriodType2MixedConstraintRHSParameters(currTP,i_type2MixedConstraint,i_ConstraintRHS)) ;
    Type2MixedConstraintLimit(currTP,i_type2MixedConstraint) = sum(i_ConstraintRHS$(ord(i_ConstraintRHS) = 2), i_tradePeriodType2MixedConstraintRHSParameters(currTP,i_type2MixedConstraint,i_ConstraintRHS)) ;
    Type1MixedConstraintCondition(currTP,i_type1MixedConstraint)$(sum(br$(HVDChalfPoles(currTP,br) and i_type1MixedConstraintBranchCondition(i_type1MixedConstraint,br)),1)) = yes ;

* Initialise generic constraint data for the current trading period
    GenericConstraint(currTP,i_GenericConstraint) = i_tradePeriodGenericConstraint(currTP,i_GenericConstraint) ;
    GenericEnergyOfferConstraintFactors(GenericConstraint,o) = i_tradePeriodGenericEnergyOfferConstraintFactors(GenericConstraint,o) ;
    GenericReserveOfferConstraintFactors(GenericConstraint,o,i_reserveClass,i_reserveType) = i_tradePeriodGenericReserveOfferConstraintFactors(GenericConstraint,o,i_reserveClass,i_reserveType) ;
    GenericEnergyBidConstraintFactors(GenericConstraint,i_bid) = i_tradePeriodGenericEnergyBidConstraintFactors(GenericConstraint,i_bid) ;
    GenericILReserveBidConstraintFactors(GenericConstraint,i_bid,i_reserveClass) = i_tradePeriodGenericILReserveBidConstraintFactors(GenericConstraint,i_bid,i_reserveClass) ;
    GenericBranchConstraintFactors(GenericConstraint,br) = i_tradePeriodGenericBranchConstraintFactors(GenericConstraint,br) ;
    GenericConstraintSense(GenericConstraint) = sum(i_ConstraintRHS$(ord(i_ConstraintRHS) = 1), i_tradePeriodGenericConstraintRHS(GenericConstraint,i_ConstraintRHS)) ;
    GenericConstraintLimit(GenericConstraint) = sum(i_ConstraintRHS$(ord(i_ConstraintRHS) = 2), i_tradePeriodGenericConstraintRHS(GenericConstraint,i_ConstraintRHS)) ;

*=====================================================================================
* c) Additional pre-processing on parameters and variables before model solve

* Calculation of generation limits due to ramp rate limits (See 5.3.1. and 5.3.2. of SPD formulation document)

* RDN - Identification of primary and secondary units
   HasSecondaryOffer(currTP,o)$sum(o1$PrimarySecondaryOffer(currTP,o,o1), 1) = 1 ;
   HasPrimaryOffer(currTP,o)$sum(o1$PrimarySecondaryOffer(currTP,o1,o), 1) = 1 ;

* Calculation 5.3.1.1.
*    GenerationMaximum(offer) = sum(ValidGenerationOfferBlock(offer,trdBlk), GenerationOfferMW(offer,trdBlk)) ;
    GenerationMaximum(offer)$(not (HasSecondaryOffer(offer) or HasPrimaryOffer(offer))) = sum(ValidGenerationOfferBlock(offer,trdBlk), GenerationOfferMW(offer,trdBlk)) ;
    GenerationMaximum(currTP,o)$HasSecondaryOffer(currTP,o) = sum(trdBlk$ValidGenerationOfferBlock(currTP,o,trdBlk), GenerationOfferMW(currTP,o,trdBlk))
                                                                                                  + sum((o1,trdBlk)$(ValidGenerationOfferBlock(currTP,o1,trdBlk) and PrimarySecondaryOffer(currTP,o,o1)), GenerationOfferMW(currTP,o1,trdBlk)) ;
* Set the ramp time
    RampTimeUp(offer) = i_tradingPeriodLength ;
    RampTimeDown(offer) = i_tradingPeriodLength ;

* RDN - Calculation 5.3.1.2. - Update to incorporate primary-secondary offers - For primary-secondary offers, only primary offer initial MW and ramp rate is used - Reference: Transpower Market Services
*   RampTimeUp(offer)$(RampRateUp(offer) and ((RampRateUp(offer)*i_tradingPeriodLength)>(GenerationMaximum(offer)-GenerationStart(offer))))
*         = (GenerationMaximum(offer)-GenerationStart(offer))/RampRateUp(offer) ;

   RampTimeUp(offer)$((not (HasSecondaryOffer(offer) or HasPrimaryOffer(offer))) and RampRateUp(offer) and ((RampRateUp(offer)*i_tradingPeriodLength)>(GenerationMaximum(offer)-GenerationStart(offer))))
         = (GenerationMaximum(offer)-GenerationStart(offer))/RampRateUp(offer) ;

   RampTimeUp(offer)$(HasSecondaryOffer(offer) and RampRateUp(offer) and ((RampRateUp(offer)*i_tradingPeriodLength)>(GenerationMaximum(offer)-GenerationStart(offer))))
         = (GenerationMaximum(offer)-GenerationStart(offer))/RampRateUp(offer) ;

* RDN - Calculation 5.3.1.3. - Update to incorporate primary-secondary offers - For primary-secondary offers, only primary offer initial MW and ramp rate is used - Reference: Transpower Market Services
*   GenerationEndUp(offer) = GenerationStart(offer)+(RampRateUp(offer)*RampTimeUp(offer)) ;
   GenerationEndUp(offer)$(not (HasSecondaryOffer(offer) or HasPrimaryOffer(offer))) = GenerationStart(offer)+(RampRateUp(offer)*RampTimeUp(offer)) ;
   GenerationEndUp(offer)$HasSecondaryOffer(offer) = GenerationStart(offer)+(RampRateUp(offer)*RampTimeUp(offer)) ;

* Calculation 5.3.2.1.
* Negative prices for generation offers are not allowed?
   GenerationMinimum(offer) = 0 ;

* Calculation 5.3.2.2. - Update to incorporate primary-secondary offers - For primary-secondary offers, only primary offer initial MW and ramp rate is used - Reference: Transpower Market Services
*   RampTimeDown(offer)$(RampRateDown(offer) and ((RampRateDown(offer)*i_tradingPeriodLength)>(GenerationStart(offer)-GenerationMinimum(offer))))
*         = (GenerationStart(offer)-GenerationMinimum(offer))/RampRateDown(offer) ;

   RampTimeDown(offer)$((not (HasSecondaryOffer(offer) or HasPrimaryOffer(offer))) and RampRateDown(offer) and ((RampRateDown(offer)*i_tradingPeriodLength)>(GenerationStart(offer)-GenerationMinimum(offer))))
         = (GenerationStart(offer)-GenerationMinimum(offer))/RampRateDown(offer) ;

   RampTimeDown(offer)$(HasSecondaryOffer(offer) and RampRateDown(offer) and ((RampRateDown(offer)*i_tradingPeriodLength)>(GenerationStart(offer)-GenerationMinimum(offer))))
         = (GenerationStart(offer)-GenerationMinimum(offer))/RampRateDown(offer) ;


* Calculation 5.3.2.3. - Update to incorporate primary-secondary offers - For primary-secondary offers, only primary offer initial MW and ramp rate is used - Reference: Transpower Market Services
*   GenerationEndDown(offer) = (GenerationStart(offer)-(RampRateDown(offer)*RampTimeDown(offer)))$((GenerationStart(offer)-(RampRateDown(offer)*RampTimeDown(offer))) >= 0) ;
   GenerationEndDown(offer)$(not (HasSecondaryOffer(offer) or HasPrimaryOffer(offer))) = (GenerationStart(offer)-(RampRateDown(offer)*RampTimeDown(offer)))$((GenerationStart(offer)-(RampRateDown(offer)*RampTimeDown(offer))) >= 0) ;
   GenerationEndDown(offer)$HasSecondaryOffer(offer) = (GenerationStart(offer)-(RampRateDown(offer)*RampTimeDown(offer)))$((GenerationStart(offer)-(RampRateDown(offer)*RampTimeDown(offer))) >= 0) ;

* Create branch loss segments
    ACbranchLossMW(branch,los)$(ValidLossSegment(branch,los) and ACbranch(branch) and (ord(los) = 1) ) = lossSegmentMW(branch,los) ;
    ACbranchLossMW(branch,los)$(ValidLossSegment(branch,los) and ACbranch(branch) and (ord(los) > 1) ) = lossSegmentMW(branch,los) - lossSegmentMW(branch,los-1) ;
    ACbranchLossFactor(branch,los)$(ValidLossSegment(branch,los) and ACbranch(branch)) = lossSegmentFactor(branch,los) ;

* Let the first point on the HVDCBreakPointMWFlow and HVDCBreakPointMWLoss be 0
* This allows zero losses and zero flow on the HVDC links otherwise model could be infeasible
    HVDCBreakPointMWFlow(HVDClink,los)$(ord(los) = 1) = 0 ;
    HVDCBreakPointMWLoss(HVDClink,los)$(ord(los) = 1) = 0 ;

    HVDCBreakPointMWFlow(branch,los)$(ValidLossSegment(branch,los) and HVDClink(branch) and (ord(los) > 1)) = lossSegmentMW(branch,los-1) ;
    HVDCBreakPointMWLoss(branch,los)$(ValidLossSegment(branch,los) and HVDClink(branch) and (ord(los) = 2)) = (lossSegmentMW(branch,los-1) * lossSegmentFactor(branch,los-1)) ;

    loop((HVDClink(branch),los)$(ord(los) > 2),
       HVDCBreakPointMWLoss(branch,los)$ValidLossSegment(branch,los) = ((lossSegmentMW(branch,los-1) - lossSegmentMW(branch,los-2)) * lossSegmentFactor(branch,los-1)) + HVDCBreakPointMWLoss(branch,los-1) ;
    ) ;

*Update the variable bounds and fixing variable values

* Offers and Bids
* Constraint 3.1.1.2
    GENERATIONBLOCK.up(ValidGenerationOfferBlock) = GenerationOfferMW(ValidGenerationOfferBlock) ;
    GENERATIONBLOCK.fx(offer,trdBlk)$(not ValidGenerationOfferBlock(offer,trdBlk)) = 0 ;

* RDN - 20130226 - Fix the generation variable for generators that are not connected or do not have a non-zero energy offer
    GENERATION.fx(currTP,o)$(not (PositiveEnergyOffer(currTP,o))) = 0 ;

* RDN - Change to demand bid
* Constraint 3.1.1.3 and 3.1.1.4
*    PURCHASEBLOCK.up(validPurchaseBidBlock) = purchaseBidMW(validPurchaseBidBlock) ;
    PURCHASEBLOCK.up(validPurchaseBidBlock)$(not (UseDSBFDemandBidModel)) = purchaseBidMW(validPurchaseBidBlock) ;
    PURCHASEBLOCK.lo(validPurchaseBidBlock)$(not (UseDSBFDemandBidModel)) = 0 ;

    PURCHASEBLOCK.up(validPurchaseBidBlock)$UseDSBFDemandBidModel = purchaseBidMW(validPurchaseBidBlock)$(purchaseBidMW(validPurchaseBidBlock) > 0) ;
    PURCHASEBLOCK.lo(validPurchaseBidBlock)$UseDSBFDemandBidModel = purchaseBidMW(validPurchaseBidBlock)$(purchaseBidMW(validPurchaseBidBlock) < 0) ;

    PURCHASEBLOCK.fx(bid,trdBlk)$(not validPurchaseBidBlock(bid,trdBlk)) = 0 ;
* RDN - Change to demand bid - End

* RDN - 20130226 - Fix the purchase variable for purchasers that are not connected or do not have a non-zero purchase bid
    PURCHASE.fx(currTP,i_bid)$(not (sum(trdBlk$validPurchaseBidBlock(currTP,i_bid,trdBlk),1))) = 0 ;

* Network
* Ensure that variables used to specify flow and losses on HVDC link are zero for AC branches and for open HVDC links.
    HVDClINKFLOW.fx(ACbranch) = 0 ;
    HVDClINKFLOW.fx(OpenBranch(HVDClink)) = 0 ;
    HVDClINKLOSSES.fx(ACbranch) = 0 ;
    HVDClINKLOSSES.fx(OpenBranch(HVDClink)) = 0 ;
* RDN - 20130227 - Set HVDC link flow and losses to zero for all branches that are not HVDC link
    HVDClINKFLOW.fx(currTP,br)$(not branch(currTP,br)) = 0 ;
    HVDClINKLOSSES.fx(currTP,br)$(not branch(currTP,br)) = 0 ;

* Apply an upper bound on the weighting parameter based on its definition
    LAMBDA.up(branch,los) = 1 ;
* Ensure that the weighting factor value is zero for AC branches and for invalid loss segments on HVDC links
    LAMBDA.fx(ACbranch,los) = 0 ;
    LAMBDA.fx(HVDClink,los)$(not (ValidLossSegment(HVDClink,los))) = 0 ;
* RDN - 20130227 - Set HVDC link flow and losses to zero for all branches that are not HVDC link
    LAMBDA.fx(currTP,br,los)$(not branch(currTP,br)) = 0 ;

* Ensure that variables used to specify flow and losses on AC branches are zero for HVDC links branches and for open AC branches
    ACBRANCHFLOW.fx(HVDClink) = 0 ;
    ACBRANCHFLOW.fx(OpenBranch) = 0 ;
* RDN - 20130227 - Set HVDC link flow and losses to zero for all branches that are not HVDC link
    ACBRANCHFLOW.fx(currTP,br)$(not branch(currTP,br)) = 0 ;

    ACBRANCHFLOWDIRECTED.fx(OpenBranch,i_flowDirection) = 0 ;
    ACBRANCHFLOWDIRECTED.fx(HVDClink,i_flowDirection) = 0 ;
* RDN - 20130227 - Set AC flow and losses to zero for all branches that are not in the AC branches set
    ACBRANCHFLOWDIRECTED.fx(currTP,br,i_flowDirection)$(not branch(currTP,br)) = 0 ;

    ACBRANCHLOSSESDIRECTED.fx(OpenBranch,i_flowDirection) = 0 ;
    ACBRANCHLOSSESDIRECTED.fx(HVDClink,i_flowDirection) = 0 ;
* RDN - 20130227 - Set AC flow and losses to zero for all branches that are not in the AC branches set
    ACBRANCHLOSSESDIRECTED.fx(currTP,br,i_flowDirection)$(not branch(currTP,br)) = 0 ;

* Ensure that variables used to specify block flow and block losses on AC branches are zero for HVDC links, open AC branches
* and invalid loss segments on closed AC branches
    ACBRANCHFLOWBLOCKDIRECTED.fx(branch,los,i_flowDirection)$(not (ValidLossSegment(branch,los))) = 0 ;
    ACBRANCHFLOWBLOCKDIRECTED.fx(OpenBranch,los,i_flowDirection) = 0 ;
    ACBRANCHFLOWBLOCKDIRECTED.fx(HVDClink,los,i_flowDirection) = 0 ;
* RDN - 20130227 - Set AC block flow and block losses to zero for all branches that are not in the AC branches set
    ACBRANCHFLOWBLOCKDIRECTED.fx(currTP,br,los,i_flowDirection)$(not branch(currTP,br)) = 0 ;

    ACBRANCHLOSSESBLOCKDIRECTED.fx(branch,los,i_flowDirection)$(not (ValidLossSegment(branch,los))) = 0 ;
    ACBRANCHLOSSESBLOCKDIRECTED.fx(OpenBranch,los,i_flowDirection) = 0 ;
    ACBRANCHLOSSESBLOCKDIRECTED.fx(HVDClink,los,i_flowDirection) = 0 ;
* RDN - 20130227 - Set AC block flow and block losses to zero for all branches that are not in the AC branches set
    ACBRANCHLOSSESBLOCKDIRECTED.fx(currTP,br,los,i_flowDirection)$(not branch(currTP,br)) = 0 ;

* Ensure that the bus voltage angle for the buses corresponding to the reference nodes and the HVDC nodes are set to zero
* Constraint 3.3.1.10
    ACnodeANGLE.fx(currTP,b)$sum(n$(NodeBus(currTP,n,b) and ReferenceNode(currTP,n)),1) = 0 ;
    ACnodeANGLE.fx(currTP,b)$sum(n$(NodeBus(currTP,n,b) and HVDCnode(currTP,n)),1) = 0 ;

* Risk/Reserve
* Ensure that all the invalid reserve blocks are set to zero for offers and purchasers
    RESERVEBLOCK.fx(offer,trdBlk,i_reserveClass,i_reserveType)$(not (ValidReserveOfferBlock(offer,trdBlk,i_reserveClass,i_reserveType))) = 0 ;
    PURCHASEILRBLOCK.fx(bid,trdBlk,i_reserveClass)$(not (validPurchaseBidILRBlock(bid,trdBlk,i_reserveClass))) = 0 ;
* Reserve block maximum for offers and purchasers - Constraint 3.4.2.2.
    RESERVEBLOCK.up(ValidReserveOfferBlock) = reserveOfferMaximum(ValidReserveOfferBlock) ;
    PURCHASEILRBLOCK.up(validPurchaseBidILRBlock) = purchaseBidILRMW(validPurchaseBidILRBlock) ;

* RDN - 20130226 - Fix the reserve variable for invalid reserve offers. These are offers that are either not connected to the grid or have no reserve quantity offered.
    RESERVE.fx(currTP,o,i_reserveClass,i_reserveType)$(not (sum(trdBlk$ValidReserveOfferBlock(currTP,o,trdBlk,i_reserveClass,i_reserveType),1))) = 0 ;
* RDN - 20130226 - Fix the purchase ILR variable for invalid purchase reserve offers. These are offers that are either not connected to the grid or have no reserve quantity offered.
    PURCHASEILR.fx(currTP,i_bid,i_reserveClass)$(not (sum(trdBlk$validPurchaseBidILRBlock(currTP,i_bid,trdBlk,i_reserveClass),1))) = 0 ;

* Risk offset fixed to zero for those not mapped to corresponding mixed constraint variable
    RISKOFFSET.fx(currTP,ild,i_reserveClass,i_riskClass)$(useMixedConstraintRiskOffset and UseMixedConstraint(currTP) and (not sum(i_type1MixedConstraint$i_type1MixedConstraintReserveMap(i_type1MixedConstraint,ild,i_reserveClass,i_riskClass),1))) = 0 ;

* RDN - Fix the appropriate deficit variable to zero depending on whether the different CE and ECE CVP flag is set
    DEFICITRESERVE.fx(currTP,ild,i_reserveClass)$diffCeECeCVP = 0 ;
    DEFICITRESERVE_CE.fx(currTP,ild,i_reserveClass)$(not diffCeECeCVP) = 0 ;
    DEFICITRESERVE_ECE.fx(currTP,ild,i_reserveClass)$(not diffCeECeCVP) = 0 ;

* Mixed constraint
    MIXEDCONSTRAINTVARIABLE.fx(currTP,i_type1MixedConstraint)$(not (i_type1MixedConstraintVarWeight(i_type1MixedConstraint))) = 0 ;


*=====================================================================================
* d) Solve the model

** Do this skip if solving either pattern - i.e. 2 and 3
*FTR --> Skip normal vSPD model solve when an extreme flow pattern is applied
*$if exist FTR_1.ins $goto FTR_process

* Set the bratio to 1 i.e. do not use advanced basis for LP
    option bratio = 1 ;
* Set resource limits
    vSPD.reslim = LPTimeLimit ;
    vSPD.iterlim = LPIterationLimit ;
    solve vSPD using lp maximizing NETBENEFIT ;
* Set the model solve status
    ModelSolved = 1$((vSPD.modelstat = 1) and (vSPD.solvestat = 1)) ;

* Post a progress message to the console and for use by EMI tools.
    if((ModelSolved = 1) and (sequentialsolve = 0),
      putclose runlog / 'The case: %vSPDinputData% finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                         'Violation Cost: ' TOTALPENALTYCOST.l:<12:1 /
    elseif((ModelSolved = 0) and (sequentialsolve = 0)),
      putclose runlog / 'The case: %vSPDinputData% finished at ', system.time '. Solve unsuccessful.' /
    )  ;


    if((ModelSolved = 1) and (sequentialsolve = 1),
      loop(currTP(tp),
         putclose runlog / 'The case: %vSPDinputData% (' currTP.tl ') finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                            'Violations: ' TOTALPENALTYCOST.l:<12:1 /
      ) ;
    elseif((ModelSolved = 0) and (sequentialsolve = 1)),
      loop(currTP(tp),
         putclose runlog / 'The case: %vSPDinputData% (' currTP.tl ') finished at ', system.time '. Solve unsuccessful.' /
      ) ;
    ) ;


*=====================================================================================
* e) Check if the LP results are valid
    if((ModelSolved = 1),
* Check if there are circulating branch flows on loss AC branches and HVDC links
       circularBranchFlowExist(ACbranch)$(lossBranch(ACbranch) and (abs(sum(i_flowDirection, ACBRANCHFLOWDIRECTED.l(ACbranch,i_flowDirection)) - abs(ACBRANCHFLOW.l(ACbranch))) > circularBranchFlowTolerance)) = 1 ;

* RDN - Determine the circular branch flow flag on each HVDC pole
       TotalHVDCpoleFlow(currTP,pole) =
       sum(br$HVDCpoleBranchMap(pole,br), HVDClINKFLOW.l(currTP,br)) ;

       MaxHVDCpoleFlow(currTP,pole) =
       smax(br$HVDCpoleBranchMap(pole,br), HVDClINKFLOW.l(currTP,br)) ;

       poleCircularBranchFlowExist(currTP,pole)$((abs(TotalHVDCpoleFlow(currTP,pole)-MaxHVDCpoleFlow(currTP,pole)) > circularBranchFlowTolerance)) = 1 ;

       NorthHVDC(currTP) = sum((ild,b,br)$((ord(ild) = 2) and i_tradePeriodBusIsland(currTP,b,ild) and HVDClinkSendingBus(currTP,br,b) and HVDCpoles(currTP,br)), HVDClINKFLOW.l(currTP,br)) ;
       SouthHVDC(currTP) = sum((ild,b,br)$((ord(ild) = 1) and i_tradePeriodBusIsland(currTP,b,ild) and HVDClinkSendingBus(currTP,br,b) and HVDCpoles(currTP,br)), HVDClINKFLOW.l(currTP,br)) ;

       circularBranchFlowExist(currTP,br)$(HVDCpoles(currTP,br) and lossBranch(currTP,br) and (min(NorthHVDC(currTP), SouthHVDC(currTP)) > circularBranchFlowTolerance)) = 1 ;

* Check if there are non-physical losses on loss AC branches and HVDC links
       ManualBranchSegmentMWFlow(ValidLossSegment(ACbranch,los))$lossBranch(ACbranch) = min(max((abs(ACBRANCHFLOW.l(ACbranch))-(lossSegmentMW(ACbranch,los-1))$(ord(los) > 1)),0),ACbranchLossMW(ACbranch,los)) ;
       ManualBranchSegmentMWFlow(ValidLossSegment(HVDClink,los))$(lossBranch(HVDClink) and (ord(los) <= HVDClinkLossBlocks(HVDClink))) = min(max((abs(HVDClINKFLOW.l(HVDClink))-(lossSegmentMW(HVDClink,los-1))$(ord(los) > 1)),0),(lossSegmentMW(HVDClink,los) - (lossSegmentMW(HVDClink,los-1))$(ord(los) > 1))) ;
       ManualLossCalculation(branch)$lossBranch(branch) = sum(los, LossSegmentFactor(branch,los) * ManualBranchSegmentMWFlow(branch,los)) ;
       NonPhysicalLossExist(ACbranch)$(lossBranch(ACbranch) and (abs(ManualLossCalculation(ACbranch) - sum(i_flowDirection, ACBRANCHLOSSESDIRECTED.l(ACbranch,i_flowDirection))) > NonPhysicalLossTolerance)) = 1 ;
       NonPhysicalLossExist(HVDClink)$(lossBranch(HVDClink) and (abs(ManualLossCalculation(HVDClink) - HVDClINKLOSSES.l(HVDClink)) > NonPhysicalLossTolerance)) = 1 ;

* Invoke the UseBranchFlowMIP flag if the number of circular branch flow and non-physical loss branches exceeds the specified tolerance
* RDN - Test - update logic to include roundpower logic
*       UseBranchFlowMIP(currTP)$((sum(br$(ACbranch(currTP,br) and lossBranch(currTP,br)), resolveCircularBranchFlows*circularBranchFlowExist(currTP,br) + resolveACnonPhysicalLosses*NonPhysicalLossExist(currTP,br)) +
*         sum(br$(lossBranch(currTP,br) and HVDClink(currTP,br)), resolveCircularBranchFlows*circularBranchFlowExist(currTP,br) + resolveHVDCnonPhysicalLosses*NonPhysicalLossExist(currTP,br)))
*         > UseBranchFlowMIPTolerance) = 1 ;
       UseBranchFlowMIP(currTP)$((sum(br$(ACbranch(currTP,br) and lossBranch(currTP,br)), resolveCircularBranchFlows*circularBranchFlowExist(currTP,br) + resolveACnonPhysicalLosses*NonPhysicalLossExist(currTP,br)) +
         sum(br$(lossBranch(currTP,br) and HVDClink(currTP,br)), (1-AllowHVDCroundpower(currTP))*resolveCircularBranchFlows*circularBranchFlowExist(currTP,br) + resolveHVDCnonPhysicalLosses*NonPhysicalLossExist(currTP,br))) +
         sum(pole, resolveCircularBranchFlows*poleCircularBranchFlowExist(currTP,pole))
         > UseBranchFlowMIPTolerance) = 1 ;

* Detect if branch flow MIP is needed
       branchFlowMIPInvoked(currTP) = UseBranchFlowMIP(currTP) ;

* Check branch flows for relevant mixed constraint to check if integer variables are needed
* RDN - Updated the condition to useMixedConstraintRiskOffset which is specific to the original mixed constraint application
       if(useMixedConstraintRiskOffset,
          HVDChalfPoleSouthFlow(currTP)$(sum(i_type1MixedConstraintBranchCondition(i_type1MixedConstraint,br)$HVDChalfPoles(currTP,br), HVDClINKFLOW.l(currTP,br)) > MixedMIPTolerance) = 1 ;
* RDN - Change definition to only calculate violation if the constraint limit is non-zero
*          Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition)
          Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition)$(Type1MixedConstraintLimit2(Type1MixedConstraintCondition) > 0)
              = (Type1MixedConstraintLE.l(Type1MixedConstraintCondition) - Type1MixedConstraintLimit2(Type1MixedConstraintCondition))$(Type1MixedConstraintSense(Type1MixedConstraintCondition) = -1)
              + (Type1MixedConstraintLimit2(Type1MixedConstraintCondition) - Type1MixedConstraintGE.l(Type1MixedConstraintCondition))$(Type1MixedConstraintSense(Type1MixedConstraintCondition) = 1)
              + abs(Type1MixedConstraintEQ.l(Type1MixedConstraintCondition) - Type1MixedConstraintLimit2(Type1MixedConstraintCondition))$(Type1MixedConstraintSense(Type1MixedConstraintCondition) = 0) ;
* Integer constraints are needed if southward flow on half-poles AND constraint level exceeds the mixed constraint limit2 value
          UseMixedConstraintMIP(currTP)$(HVDChalfPoleSouthFlow(currTP) and sum(i_type1MixedConstraint$(Type1MixedConstraintLimit2Violation(currTP,i_type1MixedConstraint) > MixedMIPTolerance),1)) = 1 ;
       ) ;

* Skip the resolve logic if the simultaneous mode requires integer variables since the problem becomes large MILP
* Resolve in sequential mode
       skipResolve$((not sequentialsolve) and ((sum(currTP, UseBranchFlowMIP(currTP) + UseMixedConstraintMIP(currTP)) and (card(currTP) > ThresholdSimultaneousInteger))) ) = 1 ;


* Post a progress message for use by EMI. Reverting to the sequential mode for integer resolves.
       if(((not sequentialsolve) and sum(currTP, UseBranchFlowMIP(currTP) + UseMixedConstraintMIP(currTP))),
          putclose runlog / 'The case: %vSPDinputData% requires an integer resolve.  Switching Vectorisation OFF.' /
       ) ;

* Post a progress message for use by EMI. Reverting to the sequential mode for integer resolves.
       if((sequentialsolve and sum(currTP, UseBranchFlowMIP(currTP) + UseMixedConstraintMIP(currTP))),
         loop(currTP(tp),
             putclose runlog / 'The case: %vSPDinputData% (' currTP.tl ') requires an integer resolve.' /
         ) ;
       ) ;


*=====================================================================================
* f) Resolve the model if required
       if( not skipResolve,

         if((sum(currTP, UseBranchFlowMIP(currTP)) * sum(currTP,UseMixedConstraintMIP(currTP))) >= 1,
* Don't use integer variables for periods that do not need them
          MIXEDCONSTRAINTLIMIT2SELECT.fx(currTP,i_type1MixedConstraint)$(not UseMixedConstraintMIP(currTP)) = 0 ;
          ACBRANCHFLOWDIRECTED_INTEGER.fx(currTP,br,i_flowDirection)$(not UseBranchFlowMIP(currTP)) = 0 ;
          HVDClINKFLOWDIRECTION_INTEGER.fx(currTP,i_flowDirection)$(not UseBranchFlowMIP(currTP)) = 0 ;
* RDN - Don't use the integer variables if not needed
         HVDCpoleFLOW_INTEGER.fx(currTP,pole,i_flowDirection)$(not UseBranchFlowMIP(currTP)) = 0 ;

          LAMBDAINTEGER.fx(currTP,br,los)$(not UseBranchFlowMIP(currTP)) = 0 ;
* Fix the values of these integer variables that are not needed
          ACBRANCHFLOWDIRECTED_INTEGER.fx(branch(currTP,br),i_flowDirection)$(UseBranchFlowMIP(currTP) and (HVDClink(branch) or (not lossBranch(branch)) or OpenBranch(branch))) = 0 ;
* RDN - 20130227 - Fix the integer AC branch flow variable to zero for invalid branches
          ACBRANCHFLOWDIRECTED_INTEGER.fx(currTP,br,i_flowDirection)$(UseBranchFlowMIP(currTP) and (not branch(currTP,br))) = 0 ;

* Apply an upper bound on the integer weighting parameter based on its definition
          LAMBDAINTEGER.up(branch(currTP,br),los)$UseBranchFlowMIP(currTP) = 1 ;
* Ensure that the weighting factor value is zero for AC branches and for invalid loss segments on HVDC links
          LAMBDAINTEGER.fx(branch(currTP,br),los)$(UseBranchFlowMIP(currTP) and (ACbranch(branch) or (not (ValidLossSegment(branch,los) and HVDClink(branch))))) = 0 ;
* RDN - 20130227 - Fix the lambda integer variable to zero for invalid branches
          LAMBDAINTEGER.fx(currTP,br,los)$(UseBranchFlowMIP(currTP) and (not branch(currTP,br))) = 0 ;

* Fix the value of some binary variables used in the mixed constraints that have no alternate limit
          MIXEDCONSTRAINTLIMIT2SELECT.fx(Type1MixedConstraint(currTP,i_type1MixedConstraint))$(UseMixedConstraintMIP(currTP) and (not Type1MixedConstraintCondition(Type1MixedConstraint))) = 0 ;
* Use the advanced basis here
          option bratio = 0.25 ;
* Set the optimality criteria for the MIP
          vSPD_MIP.optcr = MIPOptimality ;
          vSPD_MIP.reslim = MIPTimeLimit ;
          vSPD_MIP.iterlim = MIPIterationLimit ;
* Solve the model
          solve vSPD_MIP using mip maximizing NETBENEFIT ;
* Set the model solve status
*          ModelSolved = 1$(((vSPD_MIP.modelstat = 1) or (vSPD_MIP.modelstat = 7)) and (vSPD_MIP.solvestat = 1)) ;
          ModelSolved = 1$(((vSPD_MIP.modelstat = 1) or (vSPD_MIP.modelstat = 8)) and (vSPD_MIP.solvestat = 1)) ;

* Post a progress message for use by EMI.
          if(ModelSolved = 1,
             loop(currTP(tp),
                  putclose runlog / 'The case: %vSPDinputData% (' currTP.tl ') FULL integer solve finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                                     'Violations: ' TOTALPENALTYCOST.l:<12:1 /
             ) ;
          else
             loop(currTP(tp),
                  putclose runlog / 'The case: %vSPDinputData% (' currTP.tl ') FULL integer solve finished at ', system.time '. Solve unsuccessful.' /
             ) ;
          )  ;

         else

          if((sum(currTP, UseBranchFlowMIP(currTP)) >= 1),
* Don't use integer variables for periods that do not need them
             ACBRANCHFLOWDIRECTED_INTEGER.fx(currTP,br,i_flowDirection)$(not UseBranchFlowMIP(currTP)) = 0 ;
             HVDClINKFLOWDIRECTION_INTEGER.fx(currTP,i_flowDirection)$(not UseBranchFlowMIP(currTP)) = 0 ;
* RDN - Don't use the integer varaibles if not needed
             HVDCpoleFLOW_INTEGER.fx(currTP,pole,i_flowDirection)$(not UseBranchFlowMIP(currTP)) = 0 ;

             LAMBDAINTEGER.fx(currTP,br,los)$(not UseBranchFlowMIP(currTP)) = 0 ;
* Fix the values of these integer variables that are not needed
             ACBRANCHFLOWDIRECTED_INTEGER.fx(branch(currTP,br),i_flowDirection)$(UseBranchFlowMIP(currTP) and (HVDClink(branch) or (not lossBranch(branch)) or OpenBranch(branch))) = 0 ;
* RDN - 20130227 - Fix the integer AC branch flow variable to zero for invalid branches
             ACBRANCHFLOWDIRECTED_INTEGER.fx(currTP,br,i_flowDirection)$(UseBranchFlowMIP(currTP) and (not branch(currTP,br))) = 0 ;
* Apply an upper bound on the integer weighting parameter based on its definition
             LAMBDAINTEGER.up(branch(currTP,br),los)$UseBranchFlowMIP(currTP) = 1 ;
* Ensure that the weighting factor value is zero for AC branches and for invalid loss segments on HVDC links
             LAMBDAINTEGER.fx(branch(currTP,br),los)$(UseBranchFlowMIP(currTP) and (ACbranch(branch) or (not (ValidLossSegment(branch,los) and HVDClink(branch))))) = 0 ;
* RDN - 20130227 - Fix the lambda integer variable to zero for invalid branches
             LAMBDAINTEGER.fx(currTP,br,los)$(UseBranchFlowMIP(currTP) and (not branch(currTP,br))) = 0 ;
* Use the advanced basis here
             option bratio = 0.25 ;
* Set the optimality criteria for the MIP
             vSPD_BranchFlowMIP.optcr = MIPOptimality ;
             vSPD_BranchFlowMIP.reslim = MIPTimeLimit ;
             vSPD_BranchFlowMIP.iterlim = MIPIterationLimit ;
* Solve the model
             solve vSPD_BranchFlowMIP using mip maximizing NETBENEFIT ;
* Set the model solve status
             ModelSolved = 1$(((vSPD_BranchFlowMIP.modelstat = 1) or (vSPD_BranchFlowMIP.modelstat = 8)) and (vSPD_BranchFlowMIP.solvestat = 1)) ;

* Post a progress message for use by EMI.
          if(ModelSolved = 1,
             loop(currTP(tp),
                  putclose runlog / 'The case: %vSPDinputData% (' currTP.tl ') branch integer solve finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                                     'Violations: ' TOTALPENALTYCOST.l:<12:1 /
             ) ;
          else
             loop(currTP(tp),
                  putclose runlog / 'The case: %vSPDinputData% (' currTP.tl ') branch integer solve finished at ', system.time '. Solve unsuccessful.' /
             ) ;
          ) ;

          elseif(sum(currTP, UseMixedConstraintMIP(currTP)) >= 1),
* Don't use integer variables for periods that do not need them
             MIXEDCONSTRAINTLIMIT2SELECT.fx(currTP,i_type1MixedConstraint)$(not UseMixedConstraintMIP(currTP)) = 0 ;
* Fix the value of some binary variables used in the mixed constraints that have no alternate limit
             MIXEDCONSTRAINTLIMIT2SELECT.fx(Type1MixedConstraint(currTP,i_type1MixedConstraint))$(UseMixedConstraintMIP(currTP) and (not Type1MixedConstraintCondition(Type1MixedConstraint))) = 0 ;
* Use the advanced basis here
             option bratio = 0.25 ;
* Set the optimality criteria for the MIP
             vSPD_MixedConstraintMIP.optcr = MIPOptimality ;
             vSPD_MixedConstraintMIP.reslim = MIPTimeLimit ;
             vSPD_MixedConstraintMIP.iterlim = MIPIterationLimit ;
* Solve the model
             solve vSPD_MixedConstraintMIP using mip maximizing NETBENEFIT ;
* Set the model solve status
             ModelSolved = 1$(((vSPD_MixedConstraintMIP.modelstat = 1) or (vSPD_MixedConstraintMIP.modelstat = 8)) and (vSPD_MixedConstraintMIP.solvestat = 1)) ;

* Post a progress message for use by EMI.
          if(ModelSolved = 1,
             loop(currTP(tp),
                  putclose runlog / 'The case: %vSPDinputData% (' currTP.tl ') MIXED integer solve finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                                     'Violations: ' TOTALPENALTYCOST.l:<12:1 /
             ) ;
          else
             loop(currTP(tp),
                  putclose runlog / 'The case: %vSPDinputData% (' currTP.tl ') MIXED integer solve finished at ', system.time '. Solve unsuccessful.' /
             ) ;
          ) ;

          else
* Set the LP valid flag
             LPValid = 1 ;
          ) ;
         ) ;

* If either the vSPD_BranchFlowMIP or the vSPD_MixedConstraintMIP returned a valid solution
         if(((ModelSolved * (sum(currTP, UseMixedConstraintMIP(currTP) + UseBranchFlowMIP(currTP)))) >= 1),

* Re-check the MIP solved solution
* Check if there are circulating branch flows on loss AC branches and HVDC links and if mixed constraints are violated
* Reset the relevant parameters
          circularBranchFlowExist(branch) = 0 ;
          NorthHVDC(currTP) = 0 ;
          SouthHVDC(currTP) = 0 ;
* RDN - Reset the pole circular branch flow flag
          poleCircularBranchFlowExist(currTP,pole) = 0 ;

          ManualBranchSegmentMWFlow(tp,br,los) = 0 ;
          ManualLossCalculation(branch) = 0 ;
          NonPhysicalLossExist(branch)= 0 ;
          UseBranchFlowMIP(currTP) = 0 ;

* Check if there are circulating branch flows on loss AC branches and HVDC links
          circularBranchFlowExist(ACbranch)$(lossBranch(ACbranch) and (abs(sum(i_flowDirection, ACBRANCHFLOWDIRECTED.l(ACbranch,i_flowDirection)) - abs(ACBRANCHFLOW.l(ACbranch))) > circularBranchFlowTolerance)) = 1 ;
          NorthHVDC(currTP) = sum((ild,b,br)$((ord(ild) = 2) and i_tradePeriodBusIsland(currTP,b,ild) and HVDClinkSendingBus(currTP,br,b) and HVDCpoles(currTP,br)), HVDClINKFLOW.l(currTP,br)) ;
          SouthHVDC(currTP) = sum((ild,b,br)$((ord(ild) = 1) and i_tradePeriodBusIsland(currTP,b,ild) and HVDClinkSendingBus(currTP,br,b) and HVDCpoles(currTP,br)), HVDClINKFLOW.l(currTP,br)) ;
          circularBranchFlowExist(currTP,br)$(HVDCpoles(currTP,br) and lossBranch(currTP,br) and (min(NorthHVDC(currTP), SouthHVDC(currTP)) > circularBranchFlowTolerance)) = 1 ;

* RDN - Determine the circular branch flow flag on each HVDC pole
          TotalHVDCpoleFlow(currTP,pole) =
          sum(br$HVDCpoleBranchMap(pole,br), HVDClINKFLOW.l(currTP,br)) ;

          MaxHVDCpoleFlow(currTP,pole) =
          smax(br$HVDCpoleBranchMap(pole,br), HVDClINKFLOW.l(currTP,br)) ;

          poleCircularBranchFlowExist(currTP,pole)$((abs(TotalHVDCpoleFlow(currTP,pole)-MaxHVDCpoleFlow(currTP,pole)) > circularBranchFlowTolerance)) = 1 ;

* Check if there are non-physical losses on loss AC branches and HVDC links
          ManualBranchSegmentMWFlow(ValidLossSegment(ACbranch,los))$lossBranch(ACbranch) = min(max((abs(ACBRANCHFLOW.l(ACbranch))-(lossSegmentMW(ACbranch,los-1))$(ord(los) > 1)),0),ACbranchLossMW(ACbranch,los)) ;
          ManualBranchSegmentMWFlow(ValidLossSegment(HVDClink,los))$(lossBranch(HVDClink) and (ord(los) <= HVDClinkLossBlocks(HVDClink))) = min(max((abs(HVDClINKFLOW.l(HVDClink))-(lossSegmentMW(HVDClink,los-1))$(ord(los) > 1)),0),(lossSegmentMW(HVDClink,los) - (lossSegmentMW(HVDClink,los-1))$(ord(los) > 1))) ;
          ManualLossCalculation(branch)$lossBranch(branch) = sum(los, lossSegmentFactor(branch,los) * ManualBranchSegmentMWFlow(branch,los)) ;
          NonPhysicalLossExist(ACbranch)$(lossBranch(ACbranch) and (abs(ManualLossCalculation(ACbranch) - sum(i_flowDirection, ACBRANCHLOSSESDIRECTED.l(ACbranch,i_flowDirection))) > NonPhysicalLossTolerance)) = 1 ;
          NonPhysicalLossExist(HVDClink)$(lossBranch(HVDClink) and (abs(ManualLossCalculation(HVDClink) - HVDClINKLOSSES.l(HVDClink)) > NonPhysicalLossTolerance)) = 1 ;

* Invoke the UseBranchFlowMIP flag if the number of circular branch flow and non-physical loss branches exceeds the specified tolerance
* RDN - Test - update logic to include roundpower logic
*          UseBranchFlowMIP(currTP)$((sum(br$(ACbranch(currTP,br) and lossBranch(currTP,br)), resolveCircularBranchFlows*circularBranchFlowExist(currTP,br) + resolveACnonPhysicalLosses*NonPhysicalLossExist(currTP,br)) +
*            sum(br$(lossBranch(currTP,br) and HVDClink(currTP,br)), resolveCircularBranchFlows*circularBranchFlowExist(currTP,br) + resolveHVDCnonPhysicalLosses*NonPhysicalLossExist(currTP,br)))
*            > UseBranchFlowMIPTolerance) = 1 ;
          UseBranchFlowMIP(currTP)$((sum(br$(ACbranch(currTP,br) and lossBranch(currTP,br)), resolveCircularBranchFlows*circularBranchFlowExist(currTP,br) + resolveACnonPhysicalLosses*NonPhysicalLossExist(currTP,br)) +
            sum(br$(lossBranch(currTP,br) and HVDClink(currTP,br)), (1-AllowHVDCroundpower(currTP))*resolveCircularBranchFlows*circularBranchFlowExist(currTP,br) + resolveHVDCnonPhysicalLosses*NonPhysicalLossExist(currTP,br))) +
            sum(pole, resolveCircularBranchFlows*poleCircularBranchFlowExist(currTP,pole))
            > UseBranchFlowMIPTolerance) = 1 ;

* Check branch flows for relevant mixed constraint to check if integer variables are needed
* RDN - Updated the condition to useMixedConstraintRiskOffset which is specific to the original mixed constraint application
          if(useMixedConstraintRiskOffset,
* Reset the relevant parameters
             HVDChalfPoleSouthFlow(currTP) = 0 ;
             Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition) = 0 ;
             UseMixedConstraintMIP(currTP) = 0 ;

* Check branch flows for relevant mixed constraint to check if integer variables are needed
             HVDChalfPoleSouthFlow(currTP)$(sum(i_type1MixedConstraintBranchCondition(i_type1MixedConstraint,br)$HVDChalfPoles(currTP,br), HVDClINKFLOW.l(currTP,br)) > MixedMIPTolerance) = 1 ;
* RDN - Change definition to only calculate violation if the constraint limit is non-zero
*          Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition)
             Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition)$(Type1MixedConstraintLimit2(Type1MixedConstraintCondition) > 0)
                    = (Type1MixedConstraintLE.l(Type1MixedConstraintCondition) - Type1MixedConstraintLimit2(Type1MixedConstraintCondition))$(Type1MixedConstraintSense(Type1MixedConstraintCondition) = -1)
                    + (Type1MixedConstraintLimit2(Type1MixedConstraintCondition) - Type1MixedConstraintGE.l(Type1MixedConstraintCondition))$(Type1MixedConstraintSense(Type1MixedConstraintCondition) = 1)
                    + abs(Type1MixedConstraintEQ.l(Type1MixedConstraintCondition) - Type1MixedConstraintLimit2(Type1MixedConstraintCondition))$(Type1MixedConstraintSense(Type1MixedConstraintCondition) = 0) ;
* Integer constraints are needed if southward flow on half-poles AND constraint level exceeds the mixed constraint limit2 value
             UseMixedConstraintMIP(currTP)$(HVDChalfPoleSouthFlow(currTP) and sum(i_type1MixedConstraint$(Type1MixedConstraintLimit2Violation(currTP,i_type1MixedConstraint) > MixedMIPTolerance),1)) = 1 ;
          ) ;

* If either circular branch flows or non-physical losses or discontinuous mixed constraint limits then
          if((sum(currTP, UseBranchFlowMIP(currTP) + UseMixedConstraintMIP(currTP)) >= 1),

* Reset some bounds
             MIXEDCONSTRAINTLIMIT2SELECT.up(currTP,i_type1MixedConstraint) = 1 ;
             ACBRANCHFLOWDIRECTED_INTEGER.up(currTP,br,i_flowDirection) = +inf ;
             HVDClINKFLOWDIRECTION_INTEGER.up(currTP,i_flowDirection) = +inf ;
* RDN - Reset the bound of the integer variable
             HVDCpoleFLOW_INTEGER.up(currTP,pole,i_flowDirection)$(not UseBranchFlowMIP(currTP)) = +inf ;

             LAMBDAINTEGER.up(currTP,br,los) = +inf ;

* Don't use integer variables for periods that do not need them
             MIXEDCONSTRAINTLIMIT2SELECT.fx(currTP,i_type1MixedConstraint)$(not UseMixedConstraintMIP(currTP)) = 0 ;
             ACBRANCHFLOWDIRECTED_INTEGER.fx(currTP,br,i_flowDirection)$(not UseBranchFlowMIP(currTP)) = 0 ;
             HVDClINKFLOWDIRECTION_INTEGER.fx(currTP,i_flowDirection)$(not UseBranchFlowMIP(currTP)) = 0 ;
* RDN - Don't use the integer variable if not needed
             HVDCpoleFLOW_INTEGER.fx(currTP,pole,i_flowDirection)$(not UseBranchFlowMIP(currTP)) = 0 ;

             LAMBDAINTEGER.fx(currTP,br,los)$(not UseBranchFlowMIP(currTP)) = 0 ;
* Fix the values of these integer variables that are not needed
             ACBRANCHFLOWDIRECTED_INTEGER.fx(branch(currTP,br),i_flowDirection)$(UseBranchFlowMIP(currTP) and (HVDClink(branch) or (not lossBranch(branch)) or OpenBranch(branch))) = 0 ;
* RDN - 20130227 - Fix the AC branch flow integer variable for invalid branches
             ACBRANCHFLOWDIRECTED_INTEGER.fx(currTP,br,i_flowDirection)$(UseBranchFlowMIP(currTP) and (not branch(currTP,br))) = 0 ;
* Apply an upper bound on the integer weighting parameter based on its definition
             LAMBDAINTEGER.up(branch(currTP,br),los)$UseBranchFlowMIP(currTP) = 1 ;
* Ensure that the weighting factor value is zero for AC branches and for invalid loss segments on HVDC links
             LAMBDAINTEGER.fx(branch(currTP,br),los)$(UseBranchFlowMIP(currTP) and (ACbranch(branch) or (not (ValidLossSegment(branch,los) and HVDClink(branch))))) = 0 ;
* RDN - 20130227 - Fix the lambda integer variable to zero for invalid branches
             LAMBDAINTEGER.fx(currTP,br,los)$(UseBranchFlowMIP(currTP) and (not branch(currTP,br))) = 0 ;
* Fix the value of some binary variables used in the mixed constraints that have no alternate limit
             MIXEDCONSTRAINTLIMIT2SELECT.fx(Type1MixedConstraint(currTP,i_type1MixedConstraint))$(UseMixedConstraintMIP(currTP) and (not Type1MixedConstraintCondition(Type1MixedConstraint))) = 0 ;

* Use the advanced basis here
             option bratio = 1 ;
* Set the optimality criteria for the MIP
             vSPD_MIP.optcr = MIPOptimality ;
             vSPD_MIP.reslim = MIPTimeLimit ;
             vSPD_MIP.iterlim = MIPIterationLimit ;

* Solve the model
             solve vSPD_MIP using mip maximizing NETBENEFIT ;

* Post a progress message for use by EMI.
          if(ModelSolved = 1,
             loop(currTP(tp),
                  putclose runlog / 'The case: %vSPDinputData% (' currTP.tl ') FULL integer solve finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                                     'Violations: ' TOTALPENALTYCOST.l:<12:1 /
             ) ;
          else
             loop(currTP(tp),
                  putclose runlog / 'The case: %vSPDinputData% (' currTP.tl ') FULL integer solve finished at ', system.time '. Solve unsuccessful.' /
             ) ;
          ) ;

* Set the model solve status
             ModelSolved = 1$(((vSPD_MIP.modelstat = 1) or (vSPD_MIP.modelstat = 8)) and (vSPD_MIP.solvestat = 1)) ;

          ) ;

* End of if-statement for the rechecking of the solution when ModelSolved = 1
         ) ;

* *At this point either :-
* 1. LP is valid (LPValid = 1) - OK
* 2. LP is invalid and MIP is valid ((1-LPValid)*ModelSolved = 1) - OK
* 3. LP is invlalid and MIP is invalid (ModelSolved = 0) - Resolve LP

       if(ModelSolved = 0,
* Confirmation that branch flow MIP was unsuccessful we are here
          branchFlowMIPInvoked(currTP) = 0 ;
* Set the bratio to 1 i.e. do not use advanced basis for LP
          option bratio = 1 ;
* Set resource limits
          vSPD.reslim = LPTimeLimit ;
          vSPD.iterlim = LPIterationLimit ;
          solve vSPD using lp maximizing NETBENEFIT ;
* Set the model solve status
          LPModelSolved = 1$((vSPD.modelstat = 1) and (vSPD.solvestat = 1)) ;

* Post a progress message for use by EMI.
          if(LPModelSolved = 1,
             loop(currTP(tp),
                  putclose runlog / 'The case: %vSPDinputData% (' currTP.tl ') integer resolve was unsuccessful. Reverting back to linear solve.' /
                                     'The case: %vSPDinputData% (' currTP.tl ') linear solve finished at ', system.time '. Solve successful. ' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                                     'Violations: ' TOTALPENALTYCOST.l:<12:1 /
                                     'Solution may have circulating flows and/or non-physical losses.' /
             ) ;
          else
             loop(currTP(tp),
                  putclose runlog / 'The case: %vSPDinputData% (' currTP.tl ') integer solve was unsuccessful.  Reverting back to linear solve. Linear solve unsuccessful.' /
             ) ;
          ) ;

* Reset the relevant parameters
          circularBranchFlowExist(branch) = 0 ;
          NorthHVDC(currTP) = 0 ;
          SouthHVDC(currTP) = 0 ;
* RDN - Reset the pole circular branch flow parameter
          poleCircularBranchFlowExist(currTP,pole) = 0 ;

          ManualBranchSegmentMWFlow(tp,br,los) = 0 ;
          ManualLossCalculation(branch) = 0 ;
          NonPhysicalLossExist(branch)= 0 ;
          UseBranchFlowMIP(currTP) = 0 ;

* Check if there are circulating branch flows on loss AC branches and HVDC links
          circularBranchFlowExist(ACbranch)$(lossBranch(ACbranch) and (abs(sum(i_flowDirection, ACBRANCHFLOWDIRECTED.l(ACbranch,i_flowDirection)) - abs(ACBRANCHFLOW.l(ACbranch))) > circularBranchFlowTolerance)) = 1 ;
          NorthHVDC(currTP) = sum((ild,b,br)$((ord(ild) = 2) and i_tradePeriodBusIsland(currTP,b,ild) and HVDClinkSendingBus(currTP,br,b) and HVDCpoles(currTP,br)), HVDClINKFLOW.l(currTP,br)) ;
          SouthHVDC(currTP) = sum((ild,b,br)$((ord(ild) = 1) and i_tradePeriodBusIsland(currTP,b,ild) and HVDClinkSendingBus(currTP,br,b) and HVDCpoles(currTP,br)), HVDClINKFLOW.l(currTP,br)) ;
          circularBranchFlowExist(currTP,br)$(HVDCpoles(currTP,br) and lossBranch(currTP,br) and (min(NorthHVDC(currTP), SouthHVDC(currTP)) > circularBranchFlowTolerance)) = 1 ;

* RDN - Determine the circular branch flow flag on each HVDC pole
          TotalHVDCpoleFlow(currTP,pole) =
          sum(br$HVDCpoleBranchMap(pole,br), HVDClINKFLOW.l(currTP,br)) ;

          MaxHVDCpoleFlow(currTP,pole) =
          smax(br$HVDCpoleBranchMap(pole,br), HVDClINKFLOW.l(currTP,br)) ;

          poleCircularBranchFlowExist(currTP,pole)$((abs(TotalHVDCpoleFlow(currTP,pole)-MaxHVDCpoleFlow(currTP,pole)) > circularBranchFlowTolerance)) = 1 ;


* Check if there are non-physical losses on loss AC branches and HVDC links
          ManualBranchSegmentMWFlow(ValidLossSegment(ACbranch,los))$lossBranch(ACbranch) = min(max((abs(ACBRANCHFLOW.l(ACbranch))-(lossSegmentMW(ACbranch,los-1))$(ord(los) > 1)),0),ACbranchLossMW(ACbranch,los)) ;
          ManualBranchSegmentMWFlow(ValidLossSegment(HVDClink,los))$(lossBranch(HVDClink) and (ord(los) <= HVDClinkLossBlocks(HVDClink))) = min(max((abs(HVDClINKFLOW.l(HVDClink))-(lossSegmentMW(HVDClink,los-1))$(ord(los) > 1)),0),(lossSegmentMW(HVDClink,los) - (lossSegmentMW(HVDClink,los-1))$(ord(los) > 1))) ;
          ManualLossCalculation(branch)$lossBranch(branch) = sum(los, lossSegmentFactor(branch,los) * ManualBranchSegmentMWFlow(branch,los)) ;
          NonPhysicalLossExist(ACbranch)$(lossBranch(ACbranch) and (abs(ManualLossCalculation(ACbranch) - sum(i_flowDirection, ACBRANCHLOSSESDIRECTED.l(ACbranch,i_flowDirection))) > NonPhysicalLossTolerance)) = 1 ;
          NonPhysicalLossExist(HVDClink)$(lossBranch(HVDClink) and (abs(ManualLossCalculation(HVDClink) - HVDClINKLOSSES.l(HVDClink)) > NonPhysicalLossTolerance)) = 1 ;

* Invoke the UseBranchFlowMIP flag if the number of circular branch flow and non-physical loss branches exceeds the specified tolerance
* RDN - Test - update logic to include roundpower logic
*          UseBranchFlowMIP(currTP)$((sum(br$(ACbranch(currTP,br) and lossBranch(currTP,br)), resolveCircularBranchFlows*circularBranchFlowExist(currTP,br) + resolveACnonPhysicalLosses*NonPhysicalLossExist(currTP,br)) +
*            sum(br$(lossBranch(currTP,br) and HVDClink(currTP,br)), resolveCircularBranchFlows*circularBranchFlowExist(currTP,br) + resolveHVDCnonPhysicalLosses*NonPhysicalLossExist(currTP,br)))
*            > UseBranchFlowMIPTolerance) = 1 ;
          UseBranchFlowMIP(currTP)$((sum(br$(ACbranch(currTP,br) and lossBranch(currTP,br)), resolveCircularBranchFlows*circularBranchFlowExist(currTP,br) + resolveACnonPhysicalLosses*NonPhysicalLossExist(currTP,br)) +
            sum(br$(lossBranch(currTP,br) and HVDClink(currTP,br)), (1-AllowHVDCroundpower(currTP))*resolveCircularBranchFlows*circularBranchFlowExist(currTP,br) + resolveHVDCnonPhysicalLosses*NonPhysicalLossExist(currTP,br))) +
            sum(pole, resolveCircularBranchFlows*poleCircularBranchFlowExist(currTP,pole))
            > UseBranchFlowMIPTolerance) = 1 ;

* Check branch flows for relevant mixed constraint to check if integer variables are needed
* RDN - Updated the condition to useMixedConstraintRiskOffset which is specific to the original mixed constraint application
          if(useMixedConstraintRiskOffset,
* Reset the relevant parameters
             HVDChalfPoleSouthFlow(currTP) = 0 ;
             Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition) = 0 ;
             UseMixedConstraintMIP(currTP) = 0 ;

* Check branch flows for relevant mixed constraint to check if integer variables are needed
             HVDChalfPoleSouthFlow(currTP)$(sum(i_type1MixedConstraintBranchCondition(i_type1MixedConstraint,br)$HVDChalfPoles(currTP,br), HVDClINKFLOW.l(currTP,br)) > MixedMIPTolerance) = 1 ;
* RDN - Change definition to only calculate violation if the constraint limit is non-zero
*             Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition)
             Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition)$(Type1MixedConstraintLimit2(Type1MixedConstraintCondition) > 0)
                 = (Type1MixedConstraintLE.l(Type1MixedConstraintCondition) - Type1MixedConstraintLimit2(Type1MixedConstraintCondition))$(Type1MixedConstraintSense(Type1MixedConstraintCondition) = -1)
                 + (Type1MixedConstraintLimit2(Type1MixedConstraintCondition) - Type1MixedConstraintGE.l(Type1MixedConstraintCondition))$(Type1MixedConstraintSense(Type1MixedConstraintCondition) = 1)
                 + abs(Type1MixedConstraintEQ.l(Type1MixedConstraintCondition) - Type1MixedConstraintLimit2(Type1MixedConstraintCondition))$(Type1MixedConstraintSense(Type1MixedConstraintCondition) = 0) ;
* Integer constraints are needed if southward flow on half-poles AND constraint level exceeds the mixed constraint limit2 value
             UseMixedConstraintMIP(currTP)$(HVDChalfPoleSouthFlow(currTP) and sum(i_type1MixedConstraint$(Type1MixedConstraintLimit2Violation(currTP,i_type1MixedConstraint) > MixedMIPTolerance),1)) = 1 ;
          ) ;

* End of if-statement when the MIP is invalid and the LP is resolved
       ) ;

* End of if-statement when the LP is optimal
    ) ;


*=====================================================================================
* g) Check for disconnected nodes and adjust prices accordingly

* See Rule Change Proposal August 2008 - Disconnected nodes available at www.systemoperator.co.nz/reports-papers

    busGeneration(bus(currTP,b)) = sum((o,n)$(offerNode(currTP,o,n) and NodeBus(currTP,n,b)), NodeBusAllocationFactor(currTP,n,b) * GENERATION.l(currTP,o)) ;
    busLoad(bus(currTP,b)) = sum(NodeBus(currTP,n,b), NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n)) ;
    busPrice(bus(currTP,b))$(not (sum(NodeBus(HVDCnode(currTP,n),b), 1))) = ACnodeNetInjectionDefinition2.m(currTP,b) ;
    busPrice(bus(currTP,b))$(sum(NodeBus(HVDCnode(currTP,n),b), 1)) = DCNodeNetInjection.m(currTP,b) ;

* Disconnected nodes are defined as follows:
* Pre-MSP: Have no generation or load, are disconnected from the network and has a price = CVP.
* Post-MSP: Indication to SPD whether a bus is dead or not.  Dead buses are not processed by the SPD solved and have their prices set by the
* post-process with the following rules:

* Scenario A/B/D: Price for buses in live electrical island determined by the solved
* Scenario C/F/G/H/I: Buses in the dead electrical island with:
* a) Null/zero load: Marked as disconnected with $0 price.
* b) Positive load: Price = CVP for deficit generation
* c) Negative load: Price = -CVP for surplus generation
* Scenario E: Price for bus in live electrical island with zero load and zero cleared generation needs to be adjusted since actually is disconnected.

* The Post-MSP implementation imply a mapping of a bus to an electrical island and an indication of whether this electrical island is live of dead.
* The correction of the prices is performed by SPD.

* RDN - 20130302 - i_tradePeriodNodeBusAllocationFactor update - Start-----------
* Update the disconnected nodes logic to use the time-stamped i_useBusNetworkModel flag
* This allows disconnected nodes logic to work with both pre and post MSP data structure in the same gdx file

$ONTEXT
*+++ CANNOT HAVE SOLVE THAT HAS PRE-MSP AND POST-MSP DATA STRUCTURE IN THE SAME RUN SINCE THE DISCONNECTED NODES LOGIC WILL NOT WORK +++
    if(((disconnectedNodePriceCorrection = 1) and (sum(bus, busElectricalIsland(bus)) = 0)),
       busDisconnected(bus(currTP,b)) = 1$((busGeneration(bus) = 0) and (busLoad(bus) = 0) and (not sum(br$(branchBusConnect(currTP,br,b) and ClosedBranch(currTP,br)),1))) ;
* Set price at identified disconnected buses to 0
       busPrice(bus)$busDisconnected(bus) = 0 ;
    ) ;

* Post-MSP: Indication to SPD whether a bus is dead or not.  Dead buses are not processed by the SPD solved and have their prices set by the
* post-process with the following rules:

* Scenario A/B/D: Price for buses in live electrical island determined by the solved
* Scenario C/F/G/H/I: Buses in the dead electrical island with:
* a) Null/zero load: Marked as disconnected with $0 price.
* b) Positive load: Price = CVP for deficit generation
* c) Negative load: Price = -CVP for surplus generation
* Scenario E: Price for bus in live electrical island with zero load and zero cleared generation needs to be adjusted since actually is disconnected.

* The Post-MSP implementation imply a mapping of a bus to an electrical island and an indication of whether this electrical island is live of dead.
* The correction of the prices is performed by SPD.

    if(((disconnectedNodePriceCorrection = 1) and (sum(bus, busElectricalIsland(bus)) > 0)),
* Scenario C/F/G/H/I:
       busDisconnected(bus)$((busLoad(bus) = 0) and (busElectricalIsland(bus) = 0)) = 1  ;
* Scenario E:
       busDisconnected(bus(currTP,b))$( (sum(b1$(busElectricalIsland(currTP,b1) = busElectricalIsland(bus)), busLoad(currTP,b1)) = 0)
                                 and (sum(b1$(busElectricalIsland(currTP,b1) = busElectricalIsland(bus)), busGeneration(currTP,b1)) = 0)
                                 and (busElectricalIsland(bus) > 0) ) = 1 ;
* Set price at buses at disconnected buses
       busPrice(bus)$busDisconnected(bus) = 0 ;
* Set prices at dead buses with non-zero load
       busPrice(bus)$((busLoad(bus) > 0) and (busElectricalIsland(bus)= 0)) = DeficitBusGenerationPenalty ;
       busPrice(bus)$((busLoad(bus) < 0) and (busElectricalIsland(bus)= 0)) = -SurplusBusGenerationPenalty ;
    ) ;
$OFFTEXT

    if((disconnectedNodePriceCorrection = 1),
* Pre-MSP case
       busDisconnected(bus(currTP,b))$(i_useBusNetworkModel(currTP) = 0)
              = 1$((busGeneration(bus) = 0) and (busLoad(bus) = 0) and (not sum(br$(branchBusConnect(currTP,br,b) and ClosedBranch(currTP,br)),1))) ;

* Post-MSP cases
* Scenario C/F/G/H/I:
       busDisconnected(bus(currTP,b))$(
                                                         (i_useBusNetworkModel(currTP) = 1)
                                                         and (busLoad(bus) = 0)
                                                         and (busElectricalIsland(bus) = 0)
                                                        ) = 1 ;
* Scenario E:
       busDisconnected(bus(currTP,b))$((sum(b1$(busElectricalIsland(currTP,b1) = busElectricalIsland(bus)), busLoad(currTP,b1)) = 0)
                                                         and (sum(b1$(busElectricalIsland(currTP,b1) = busElectricalIsland(bus)), busGeneration(currTP,b1)) = 0)
                                                         and (busElectricalIsland(bus) > 0)
                                                         and (i_useBusNetworkModel(currTP) = 1)
                                                        ) = 1 ;
* Set prices at dead buses with non-zero load
       busPrice(bus(currTP,b))$((i_useBusNetworkModel(currTP) = 1)
                                                  and (busLoad(bus) > 0)
                                                  and (busElectricalIsland(bus)= 0)
                                                 ) = DeficitBusGenerationPenalty ;

       busPrice(bus(currTP,b))$((i_useBusNetworkModel(currTP) = 1)
                                                  and (busLoad(bus) < 0)
                                                  and (busElectricalIsland(bus)= 0)
                                                 ) = -SurplusBusGenerationPenalty ;

*  Set price at identified disconnected buses to 0
       busPrice(bus)$busDisconnected(bus) = 0 ;
    ) ;


*=====================================================================================
* h) Collect and store results from the current model solve in the output (o_xxx) parameters

* Skip the usual vSPD reporting if calculating FTR rentals
*$if not %calcFTRrentals%==1 $goto FTR_process

*  Check if reporting at trading period level or for audit purposes is required...
    if((tradePeriodReports = 1) or (opMode = -1),
     loop(i_dateTimeTradePeriodMap(dt,currTP),
       o_dateTime(dt) = yes ;
       o_bus(dt,b)$(bus(currTP,b) and (not DCBus(currTP,b))) = yes ;
       o_busGeneration_TP(dt,b)$bus(currTP,b) = busGeneration(currTP,b) ;
       o_busLoad_TP(dt,b)$bus(currTP,b) = busLoad(currTP,b) ;
       o_busPrice_TP(dt,b)$bus(currTP,b) = busPrice(currTP,b) ;
       o_busRevenue_TP(dt,b)$bus(currTP,b) = (i_tradingPeriodLength/60)*(busGeneration(currTP,b) * busPrice(currTP,b)) ;
       o_busCost_TP(dt,b)$bus(currTP,b) = (i_tradingPeriodLength/60)*(busLoad(currTP,b) * busPrice(currTP,b)) ;
       o_busDeficit_TP(dt,b)$bus(currTP,b) = DEFICITBUSGENERATION.l(currTP,b) ;
       o_busSurplus_TP(dt,b)$bus(currTP,b) = SURPLUSBUSGENERATION.l(currTP,b) ;
       o_node(dt,n)$(Node(currTP,n) and (not HVDCnode(currTP,n))) = yes ;
       o_nodeGeneration_TP(dt,n)$Node(currTP,n) = sum(o$(offerNode(currTP,o,n)), GENERATION.l(currTP,o)) ;
       o_nodeLoad_TP(dt,n)$Node(currTP,n) = NodeDemand(currTP,n) ;
       o_nodePrice_TP(dt,n)$Node(currTP,n) = sum(b$(NodeBus(currTP,n,b)), NodeBusAllocationFactor(currTP,n,b) * busPrice(currTP,b)) ;
       o_nodeRevenue_TP(dt,n)$Node(currTP,n) = (i_tradingPeriodLength/60)*(o_nodeGeneration_TP(dt,n) * o_nodePrice_TP(dt,n)) ;
       o_nodeCost_TP(dt,n)$Node(currTP,n) = (i_tradingPeriodLength/60)*(o_nodeLoad_TP(dt,n) * o_nodePrice_TP(dt,n)) ;

*  RDN - Update the deficit and surplus reporting at the nodal level - Start------
       totalBusAllocation(dt,b)$bus(currTP,b) = sum(n$Node(currTP,n), NodeBusAllocationFactor(currTP,n,b)) ;
       busNodeAllocationFactor(dt,b,n)$(totalBusAllocation(dt,b) > 0) = NodeBusAllocationFactor(currTP,n,b)/totalBusAllocation(dt,b) ;
*      o_nodeDeficit_TP(dt,n)$Node(currTP,n) = sum(b$(NodeBus(currTP,n,b)), NodeBusAllocationFactor(currTP,n,b) * DEFICITBUSGENERATION.l(currTP,b)) ;
*      o_nodeSurplus_TP(dt,n)$Node(currTP,n) = sum(b$(NodeBus(currTP,n,b)), NodeBusAllocationFactor(currTP,n,b) * SURPLUSBUSGENERATION.l(currTP,b)) ;
       o_nodeDeficit_TP(dt,n)$Node(currTP,n) = sum(b$(NodeBus(currTP,n,b)), busNodeAllocationFactor(dt,b,n) * DEFICITBUSGENERATION.l(currTP,b)) ;
       o_nodeSurplus_TP(dt,n)$Node(currTP,n) = sum(b$(NodeBus(currTP,n,b)), busNodeAllocationFactor(dt,b,n) * SURPLUSBUSGENERATION.l(currTP,b)) ;
* RDN - Update the deficit and surplus reporting at the nodal level - End------

       o_branch(dt,br)$branch(currTP,br) = yes ;
       o_branchFlow_TP(dt,br)$ACbranch(currTP,br) = ACBRANCHFLOW.l(currTP,br) ;
       o_branchFlow_TP(dt,br)$HVDClink(currTP,br) = HVDClINKFLOW.l(currTP,br) ;
       o_branchDynamicLoss_TP(dt,br)$(ACbranch(currTP,br) and ClosedBranch(currTP,br)) = sum(i_flowDirection,ACBRANCHLOSSESDIRECTED.l(currTP,br,i_flowDirection)) ;
       o_branchDynamicLoss_TP(dt,br)$(HVDClink(currTP,br) and ClosedBranch(currTP,br)) = HVDClINKLOSSES.l(currTP,br) ;

       o_branchTotalLoss_TP(dt,br)$(ACbranch(currTP,br) and ClosedBranch(currTP,br)) = sum(i_flowDirection,ACBRANCHLOSSESDIRECTED.l(currTP,br,i_flowDirection)) + ACbranchFixedLoss(currTP,br) ;
       o_branchTotalLoss_TP(dt,br)$(HVDClink(currTP,br) and ClosedBranch(currTP,br) and (i_tradePeriodHVDCBranch(currTP,br) = 1) and (o_branchFlow_TP(dt,br) > 0)) = HVDClINKLOSSES.l(currTP,br) + sum(br1$(HVDClink(currTP,br1) and ClosedBranch(currTP,br1) and (i_tradePeriodHVDCBranch(currTP,br1) = 1)), HVDClinkFixedLoss(currTP,br1)) ;
       o_branchTotalLoss_TP(dt,br)$(HVDClink(currTP,br) and ClosedBranch(currTP,br) and (i_tradePeriodHVDCBranch(currTP,br) = 2) and (o_branchFlow_TP(dt,br) > 0)) = HVDClINKLOSSES.l(currTP,br) + sum(br1$(HVDClink(currTP,br1) and ClosedBranch(currTP,br1) and (i_tradePeriodHVDCBranch(currTP,br1) = 2)), HVDClinkFixedLoss(currTP,br1)) ;

       o_branchFixedLoss_TP(dt,br)$(ACbranch(currTP,br) and ClosedBranch(currTP,br)) = ACbranchFixedLoss(currTP,br) ;
       o_branchFixedLoss_TP(dt,br)$(HVDClink(currTP,br) and ClosedBranch(currTP,br)) = HVDClinkFixedLoss(currTP,br) ;

       o_branchFromBus_TP(dt,br,frB)$(branch(currTP,br) and sum(toB$branchBusDefn(currTP,br,frB,toB),1)) = yes ;
       o_branchToBus_TP(dt,br,toB)$(branch(currTP,br) and sum(frB$branchBusDefn(currTP,br,frB,toB),1)) = yes ;
       o_branchFromBusPrice_TP(dt,br)$branch(currTP,br) = sum((frB,toB)$branchBusDefn(currTP,br,frB,toB), busPrice(currTP,frB)) ;
       o_branchToBusPrice_TP(dt,br)$branch(currTP,br) = sum((frB,toB)$branchBusDefn(currTP,br,frB,toB), busPrice(currTP,toB)) ;
       o_branchMarginalPrice_TP(dt,br)$ACbranch(currTP,br) = sum(i_flowDirection, ACbranchMaximumFlow.m(currTP,br,i_flowDirection)) ;
       o_branchMarginalPrice_TP(dt,br)$HVDClink(currTP,br) = HVDClinkMaximumFlow.m(currTP,br) ;
       o_branchDynamicRentals_TP(dt,br)$(branch(currTP,br) and (o_branchFlow_TP(dt,br) >= 0)) = (i_tradingPeriodLength/60)*((o_branchToBusPrice_TP(dt,br)*(o_branchFlow_TP(dt,br)-o_branchDynamicLoss_TP(dt,br))) - (o_branchFromBusPrice_TP(dt,br)*o_branchFlow_TP(dt,br))) ;
       o_branchDynamicRentals_TP(dt,br)$(branch(currTP,br) and (o_branchFlow_TP(dt,br) < 0)) = (i_tradingPeriodLength/60)*((o_branchFromBusPrice_TP(dt,br)*(abs(o_branchFlow_TP(dt,br))-o_branchDynamicLoss_TP(dt,br))) -(o_branchToBusPrice_TP(dt,br)*abs(o_branchFlow_TP(dt,br)))) ;
       o_branchTotalRentals_TP(dt,br)$(branch(currTP,br) and (o_branchFlow_TP(dt,br) >= 0)) = (i_tradingPeriodLength/60)*((o_branchToBusPrice_TP(dt,br)*(o_branchFlow_TP(dt,br)-o_branchTotalLoss_TP(dt,br))) - (o_branchFromBusPrice_TP(dt,br)*o_branchFlow_TP(dt,br))) ;
       o_branchTotalRentals_TP(dt,br)$(branch(currTP,br) and (o_branchFlow_TP(dt,br) < 0)) = (i_tradingPeriodLength/60)*((o_branchFromBusPrice_TP(dt,br)*(abs(o_branchFlow_TP(dt,br))-o_branchTotalLoss_TP(dt,br))) -(o_branchToBusPrice_TP(dt,br)*abs(o_branchFlow_TP(dt,br)))) ;
       o_branchCapacity_TP(dt,br)$branch(currTP,br) = i_tradePeriodBranchCapacity(currTP,br) ;
       o_offer(dt,o)$offer(currTP,o) = yes ;
       o_offerEnergy_TP(dt,o)$offer(currTP,o) = GENERATION.l(currTP,o) ;
       o_offerFIR_TP(dt,o)$offer(currTP,o) = sum((i_reserveClass,i_reserveType)$(ord(i_reserveClass) = 1), RESERVE.l(currTP,o,i_reserveClass,i_reserveType)) ;
       o_offerSIR_TP(dt,o)$offer(currTP,o) = sum((i_reserveClass,i_reserveType)$(ord(i_reserveClass) = 2), RESERVE.l(currTP,o,i_reserveClass,i_reserveType)) ;
       o_bidEnergy_TP(dt,i_bid)$bid(currTP,i_bid) = PURCHASE.l(currTP,i_bid) ;
       o_bidReserve_TP(dt,i_bid,i_reserveClass)$bid(currTP,i_bid) = PURCHASEILR.l(currTP,i_bid,i_reserveClass) ;
       o_island(dt,ild) = yes ;
* RDN - Update FIR and SIR required based on the CE and ECE
* RDN - FIR and SIR required based on calculations of the island risk to overcome reporting issues of the risk setter under degenerate conditions when reserve price = 0 - See below
*      o_FIRreqd_TP(dt,ild)$(not diffCeECeCVP) = sum(i_reserveClass$(ord(i_reserveClass) = 1), MAXISLANDRISK.l(currTP,ild,i_reserveClass)) ;
*      o_SIRreqd_TP(dt,ild)$(not diffCeECeCVP) = sum(i_reserveClass$(ord(i_reserveClass) = 2), MAXISLANDRISK.l(currTP,ild,i_reserveClass)) ;
*      o_FIRreqd_TP(dt,ild)$(diffCeECeCVP) = sum(i_reserveClass$(ord(i_reserveClass) = 1), MAXISLANDRISK.l(currTP,ild,i_reserveClass) + max(DEFICITRESERVE_CE.l(currTP,ild,i_reserveClass),DEFICITRESERVE_ECE.l(currTP,ild,i_reserveClass))) ;
*      o_SIRreqd_TP(dt,ild)$(diffCeECeCVP) = sum(i_reserveClass$(ord(i_reserveClass) = 2), MAXISLANDRISK.l(currTP,ild,i_reserveClass) + max(DEFICITRESERVE_CE.l(currTP,ild,i_reserveClass),DEFICITRESERVE_ECE.l(currTP,ild,i_reserveClass))) ;

       o_FIRprice_TP(dt,ild) = sum(i_reserveClass$(ord(i_reserveClass) = 1), SupplyDemandReserveRequirement.m(currTP,ild,i_reserveClass)) ;
       o_SIRprice_TP(dt,ild) = sum(i_reserveClass$(ord(i_reserveClass) = 2), SupplyDemandReserveRequirement.m(currTP,ild,i_reserveClass)) ;
* RDN - Update violation reporting based on the CE and ECE
*      o_FIRviolation_TP(dt,ild) = sum(i_reserveClass$(ord(i_reserveClass) = 1), DEFICITRESERVE.l(currTP,ild,i_reserveClass)) ;
*      o_SIRviolation_TP(dt,ild) = sum(i_reserveClass$(ord(i_reserveClass) = 2), DEFICITRESERVE.l(currTP,ild,i_reserveClass)) ;
       o_FIRviolation_TP(dt,ild)$(not diffCeECeCVP) = sum(i_reserveClass$(ord(i_reserveClass) = 1), DEFICITRESERVE.l(currTP,ild,i_reserveClass)) ;
       o_SIRviolation_TP(dt,ild)$(not diffCeECeCVP) = sum(i_reserveClass$(ord(i_reserveClass) = 2), DEFICITRESERVE.l(currTP,ild,i_reserveClass)) ;
       o_FIRviolation_TP(dt,ild)$(diffCeECeCVP) = sum(i_reserveClass$(ord(i_reserveClass) = 1), DEFICITRESERVE_CE.l(currTP,ild,i_reserveClass) + DEFICITRESERVE_ECE.l(currTP,ild,i_reserveClass)) ;
       o_SIRviolation_TP(dt,ild)$(diffCeECeCVP) = sum(i_reserveClass$(ord(i_reserveClass) = 2), DEFICITRESERVE_CE.l(currTP,ild,i_reserveClass) + DEFICITRESERVE_ECE.l(currTP,ild,i_reserveClass)) ;

* Security constraint data
       o_brConstraint_TP(dt,i_branchConstraint)$branchConstraint(currTP,i_branchConstraint) = yes ;
       o_brConstraintSense_TP(dt,i_branchConstraint)$branchConstraint(currTP,i_branchConstraint) = branchConstraintSense(currTP,i_branchConstraint) ;
       o_brConstraintLHS_TP(dt,i_branchConstraint)$branchConstraint(currTP,i_branchConstraint) = branchSecurityConstraintLE.l(currTP,i_branchConstraint)$(branchConstraintSense(currTP,i_branchConstraint) = -1)
                                                                                                                          + branchSecurityConstraintGE.l(currTP,i_branchConstraint)$(branchConstraintSense(currTP,i_branchConstraint) = 1)
                                                                                                                          + branchSecurityConstraintEQ.l(currTP,i_branchConstraint)$(branchConstraintSense(currTP,i_branchConstraint) = 0) ;
       o_brConstraintRHS_TP(dt,i_branchConstraint)$branchConstraint(currTP,i_branchConstraint) = branchConstraintLimit(currTP,i_branchConstraint) ;
       o_brConstraintPrice_TP(dt,i_branchConstraint)$branchConstraint(currTP,i_branchConstraint) = branchSecurityConstraintLE.m(currTP,i_branchConstraint)$(branchConstraintSense(currTP,i_branchConstraint) = -1)
                                                                                                                          + branchSecurityConstraintGE.m(currTP,i_branchConstraint)$(branchConstraintSense(currTP,i_branchConstraint) = 1)
                                                                                                                          + branchSecurityConstraintEQ.m(currTP,i_branchConstraint)$(branchConstraintSense(currTP,i_branchConstraint) = 0) ;
* Mnode constraint data
       o_MnodeConstraint_TP(dt,i_MnodeConstraint)$MnodeConstraint(currTP,i_MnodeConstraint) = yes ;
       o_MnodeConstraintSense_TP(dt,i_MnodeConstraint)$MnodeConstraint(currTP,i_MnodeConstraint) = MnodeConstraintSense(currTP,i_MnodeConstraint) ;
       o_MnodeConstraintLHS_TP(dt,i_MnodeConstraint)$MnodeConstraint(currTP,i_MnodeConstraint) = MnodeSecurityConstraintLE.l(currTP,i_MnodeConstraint)$(MnodeConstraintSense(currTP,i_MnodeConstraint) = -1)
                                                                                                                          + MnodeSecurityConstraintGE.l(currTP,i_MnodeConstraint)$(MnodeConstraintSense(currTP,i_MnodeConstraint) = 1)
                                                                                                                          + MnodeSecurityConstraintEQ.l(currTP,i_MnodeConstraint)$(MnodeConstraintSense(currTP,i_MnodeConstraint) = 0) ;
       o_MnodeConstraintRHS_TP(dt,i_MnodeConstraint)$MnodeConstraint(currTP,i_MnodeConstraint) = MnodeConstraintLimit(currTP,i_MnodeConstraint) ;
       o_MnodeConstraintPrice_TP(dt,i_MnodeConstraint)$MnodeConstraint(currTP,i_MnodeConstraint) = MnodeSecurityConstraintLE.m(currTP,i_MnodeConstraint)$(MnodeConstraintSense(currTP,i_MnodeConstraint) = -1)
                                                                                                                          + MnodeSecurityConstraintGE.m(currTP,i_MnodeConstraint)$(MnodeConstraintSense(currTP,i_MnodeConstraint) = 1)
                                                                                                                          + MnodeSecurityConstraintEQ.m(currTP,i_MnodeConstraint)$(MnodeConstraintSense(currTP,i_MnodeConstraint) = 0) ;

* Island results at a trade period level
      o_islandGen_TP(dt,ild) = sum(b$busIsland(currTP,b,ild), busGeneration(currTP,b)) ;
      o_islandLoad_TP(dt,ild) = sum(b$busIsland(currTP,b,ild), busLoad(currTP,b)) ;
      o_islandEnergyRevenue_TP(dt,ild) = (i_tradingPeriodLength/60)*sum((o,b,n)$(offerNode(currTP,o,n) and NodeBus(currTP,n,b) and busIsland(currTP,b,ild)), NodeBusAllocationFactor(currTP,n,b) * GENERATION.l(currTP,o) * busPrice(currTP,b)) ;
      o_islandReserveRevenue_TP(dt,ild) = (i_tradingPeriodLength/60)*sum((o,n,b,i_reserveClass,i_reserveType)$(offerNode(currTP,o,n) and NodeBus(currTP,n,b) and busIsland(currTP,b,ild)), SupplyDemandReserveRequirement.m(currTP,ild,i_reserveClass) * RESERVE.l(currTP,o,i_reserveClass,i_reserveType)) ;
      o_islandLoadCost_TP(dt,ild) = (i_tradingPeriodLength/60)*sum((b,n)$(NodeBus(currTP,n,b) and (NodeDemand(currTP,n) >= 0) and busIsland(currTP,b,ild)), NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n) * busPrice(currTP,b)) ;
      o_islandLoadRevenue_TP(dt,ild) = (i_tradingPeriodLength/60)*sum((b,n)$(NodeBus(currTP,n,b) and (NodeDemand(currTP,n) < 0) and busIsland(currTP,b,ild)), NodeBusAllocationFactor(currTP,n,b) * (-NodeDemand(currTP,n)) * busPrice(currTP,b)) ;

      o_islandBranchLoss_TP(dt,ild) = sum((br,frB,toB)$(ACbranch(currTP,br) and ClosedBranch(currTP,br) and branchBusDefn(currTP,br,frB,toB) and busIsland(currTP,toB,ild)), o_branchTotalLoss_TP(dt,br)) ;
      o_HVDCflow_TP(dt,ild) = sum((br,frB,toB)$(HVDCpoles(currTP,br) and ClosedBranch(currTP,br) and branchBusDefn(currTP,br,frB,toB) and busIsland(currTP,frB,ild)), o_branchFlow_TP(dt,br)) ;

      o_HVDChalfPoleLoss_TP(dt,ild) = sum((br,frB,toB)$(HVDChalfPoles(currTP,br) and ClosedBranch(currTP,br) and branchBusDefn(currTP,br,frB,toB) and busIsland(currTP,toB,ild) and busIsland(currTP,frB,ild)), o_branchTotalLoss_TP(dt,br)) ;
      o_HVDCpoleFixedLoss_TP(dt,ild) = sum((br,frB,toB)$(HVDCpoles(currTP,br) and ClosedBranch(currTP,br) and branchBusDefn(currTP,br,frB,toB) and (busIsland(currTP,toB,ild) or busIsland(currTP,frB,ild))), 0.5 * o_branchFixedLoss_TP(dt,br)) ;
      o_HVDCloss_TP(dt,ild) = o_HVDChalfPoleLoss_TP(dt,ild) + o_HVDCpoleFixedLoss_TP(dt,ild) +
                                         sum((br,frB,toB)$(HVDClink(currTP,br) and ClosedBranch(currTP,br) and branchBusDefn(currTP,br,frB,toB) and busIsland(currTP,toB,ild) and (not (busIsland(currTP,frB,ild)))), o_branchDynamicLoss_TP(dt,br)) ;
      o_islandRefPrice_TP(dt,ild) = sum(n$(ReferenceNode(currTP,n) and NodeIsland(currTP,n,ild)), o_nodePrice_TP(dt,n)) ;

* TN - Additional output for audit reporting
      o_ACbusAngle(dt,b) = ACnodeANGLE.l(currTP,b) ;

      o_nonPhysicalLoss(dt,br)$ACbranch(currTP,br) = abs(ManualLossCalculation(currTP,br) - sum(i_flowDirection, ACBRANCHLOSSESDIRECTED.l(currTP,br,i_flowDirection))) ;
      o_nonPhysicalLoss(dt,br)$HVDClink(currTP,br) = abs(ManualLossCalculation(currTP,br) - HVDClINKLOSSES.l(currTP,br)) ;

      o_lossSegmentBreakPoint(dt,br,los)$ValidLossSegment(currTP,br,los) = lossSegmentMW(currTP,br,los) ;
      o_lossSegmentFactor(dt,br,los)$ValidLossSegment(currTP,br,los) = lossSegmentFactor(currTP,br,los) ;

      o_busIsland_TP(dt,b,ild)$busIsland(currTP,b,ild) = yes ;

      o_PLRO_FIR_TP(dt,o)$offer(currTP,o) = sum[(i_reserveClass,i_reserveType)$[(ord(i_reserveClass) = 1) and (ord(i_reserveType) = 1)], RESERVE.l(currTP,o,i_reserveClass,i_reserveType)] ;
      o_PLRO_SIR_TP(dt,o)$offer(currTP,o) = sum[(i_reserveClass,i_reserveType)$[(ord(i_reserveClass) = 2) and (ord(i_reserveType) = 1)], RESERVE.l(currTP,o,i_reserveClass,i_reserveType)] ;
      o_TWRO_FIR_TP(dt,o)$offer(currTP,o) = sum[(i_reserveClass,i_reserveType)$[(ord(i_reserveClass) = 1) and (ord(i_reserveType) = 2)], RESERVE.l(currTP,o,i_reserveClass,i_reserveType)] ;
      o_TWRO_SIR_TP(dt,o)$offer(currTP,o) = sum[(i_reserveClass,i_reserveType)$[(ord(i_reserveClass) = 2) and (ord(i_reserveType) = 2)], RESERVE.l(currTP,o,i_reserveClass,i_reserveType)] ;
      o_ILRO_FIR_TP(dt,o)$offer(currTP,o) = sum[(i_reserveClass,i_reserveType)$[(ord(i_reserveClass) = 1) and (ord(i_reserveType) = 3)], RESERVE.l(currTP,o,i_reserveClass,i_reserveType)] ;
      o_ILRO_SIR_TP(dt,o)$offer(currTP,o) = sum[(i_reserveClass,i_reserveType)$[(ord(i_reserveClass) = 2) and (ord(i_reserveType) = 3)], RESERVE.l(currTP,o,i_reserveClass,i_reserveType)] ;

      o_ILbus_FIR_TP(dt,b) = sum[o$sameas(o,b), o_ILRO_FIR_TP(dt,o)] ;
      o_ILbus_SIR_TP(dt,b) = sum[o$sameas(o,b), o_ILRO_SIR_TP(dt,o)] ;

      o_marketNodeIsland_TP(dt,o,ild)$sum[(n,b)$[BusIsland(currTP,b,ild)
                                                                             and NodeBus(currTP,n,b)
                                                                             and offerNode(currTP,o,n)
                                                                             and (o_nodeLoad_TP(dt,n)  = 0)
                                                                                ],1] = yes ;

      o_generationRiskSetter(dt,ild,o,i_reserveClass,GenRisk)$[not UsePrimSecGenRiskModel
                                                                                 and IslandRiskGenerator(currTP,ild,o)
                                                                                    ] =
            IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,GenRisk) * [GENERATION.l(currTP,o)
                                                                                            - FreeReserve(currTP,ild,i_reserveClass,GenRisk)
                                                                                            + FKband(currTP,o)
                                                                                            + sum(i_reserveType, RESERVE.l(currTP,o,i_reserveClass,i_reserveType))
                                                                                             ] ;

      o_generationRiskSetter(dt,ild,o,i_reserveClass,GenRisk)$[UsePrimSecGenRiskModel
                                                                                and IslandRiskGenerator(currTP,ild,o)
                                                                                and ( not (HasSecondaryOffer(currTP,o) or HasPrimaryOffer(currTP,o))                                                                                          )
                                                                                   ] =
            IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,GenRisk) * [GENERATION.l(currTP,o)
                                                                                            - FreeReserve(currTP,ild,i_reserveClass,GenRisk)
                                                                                            + FKband(currTP,o)
                                                                                            + sum(i_reserveType, RESERVE.l(currTP,o,i_reserveClass,i_reserveType))
                                                                                             ] ;

      o_generationRiskSetter(dt,ild,o,i_reserveClass,GenRisk)$[UsePrimSecGenRiskModel
                                                                                 and IslandRiskGenerator(currTP,ild,o)
                                                                                 and HasSecondaryOffer(currTP,o)
                                                                                    ] =
            IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,GenRisk) * [ GENERATION.l(currTP,o)
                                                                                              + sum[o1$PrimarySecondaryOffer(currTP,o,o1), GENERATION.l(currTP,o1)]
                                                                                              - FreeReserve(currTP,ild,i_reserveClass,GenRisk)
                                                                                              + FKband(currTP,o)
                                                                                              + sum[i_reserveType, RESERVE.l(currTP,o,i_reserveClass,i_reserveType)]
                                                                                              + sum[(o1,i_reserveType)$PrimarySecondaryOffer(currTP,o,o1), RESERVE.l(currTP,o1,i_reserveClass,i_reserveType)]
                                                                                              ] ;
      o_generationRiskSetterMax(dt,ild,o,i_reserveClass) = SMax[GenRisk, o_generationRiskSetter(dt,ild,o,i_reserveClass,GenRisk)] ;


      o_HVDCriskSetter(dt,ild,i_reserveClass,HVDCrisk) =
            IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,HVDCrisk) * [HVDCREC.l(currTP,ild)
                                                                                             - RISKOFFSET.l(currTP,ild,i_reserveClass,HVDCrisk)
                                                                                              ] ;

      o_manuRiskSetter(dt,ild,i_reserveClass,ManualRisk) =
            IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,ManualRisk) * [IslandMinimumRisk(currTP,ild,i_reserveClass,ManualRisk)
                                                                                               - FreeReserve(currTP,ild,i_reserveClass,ManualRisk)
                                                                                                ] ;

      o_genHVDCriskSetter(dt,ild,o,i_reserveClass,HVDCsecRisk)$[ (not (UsePrimSecGenRiskModel)) and HVDCsecRiskEnabled(currTP,ild,HVDCsecRisk)
                                                                                  and IslandRiskGenerator(currTP,ild,o)
                                                                                    ] =
            IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,HVDCsecRisk) * [ GENERATION.l(currTP,o)
                                                                                                 - FreeReserve(currTP,ild,i_reserveClass,HVDCsecRisk)
                                                                                                 + HVDCREC.l(currTP,ild)
                                                                                                 - HVDCsecRiskSubtractor(currTP,ild)
                                                                                                 + FKband(currTP,o)
                                                                                                 + sum(i_reserveType, RESERVE.l(currTP,o,i_reserveClass,i_reserveType))
                                                                                                 ] ;


      o_manuHVDCriskSetter(dt,ild,i_reserveClass,HVDCsecRisk) $HVDCsecRiskEnabled(currTP,ild,HVDCsecRisk) =
            IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,HVDCsecRisk) * [ HVDCsecIslandMinimumRisk(currTP,ild,i_reserveClass,HVDCsecRisk)
                                                                                                 - FreeReserve(currTP,ild,i_reserveClass,HVDCsecRisk)
                                                                                                 + HVDCREC.l(currTP,ild)
                                                                                                 - HVDCsecRiskSubtractor(currTP,ild)
                                                                                                 ] ;

* TN - Additional output for audit reporting - End

* RDN - Included reporting of risk - Start-----------------
      o_genHVDCriskSetter(dt,ild,o,i_reserveClass,HVDCsecRisk)$[ UsePrimSecGenRiskModel and HVDCsecRiskEnabled(currTP,ild,HVDCsecRisk)
                                                                                  and IslandRiskGenerator(currTP,ild,o)
                                                                                  and (not (HasSecondaryOffer(currTP,o) or HasPrimaryOffer(currTP,o)))
                                                                                    ] =
            IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,HVDCsecRisk) * [ GENERATION.l(currTP,o)
                                                                                                 - FreeReserve(currTP,ild,i_reserveClass,HVDCsecRisk)
                                                                                                 + HVDCREC.l(currTP,ild)
                                                                                                 - HVDCsecRiskSubtractor(currTP,ild)
                                                                                                 + FKband(currTP,o)
                                                                                                 + sum(i_reserveType, RESERVE.l(currTP,o,i_reserveClass,i_reserveType))
                                                                                                 ] ;


      o_genHVDCriskSetter(dt,ild,o,i_reserveClass,HVDCsecRisk)$[ UsePrimSecGenRiskModel and HVDCsecRiskEnabled(currTP,ild,HVDCsecRisk)
                                                                                  and IslandRiskGenerator(currTP,ild,o)
                                                                                  and HasSecondaryOffer(currTP,o)
                                                                                    ] =
            IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,HVDCsecRisk) * [ GENERATION.l(currTP,o)
                                                                                                 + sum[o1$PrimarySecondaryOffer(currTP,o,o1), GENERATION.l(currTP,o1)]
                                                                                                 - FreeReserve(currTP,ild,i_reserveClass,HVDCsecRisk)
                                                                                                 + HVDCREC.l(currTP,ild)
                                                                                                 - HVDCsecRiskSubtractor(currTP,ild)
                                                                                                 + FKband(currTP,o)
                                                                                                 + sum(i_reserveType, RESERVE.l(currTP,o,i_reserveClass,i_reserveType))
                                                                                                 + sum[(o1,i_reserveType)$PrimarySecondaryOffer(currTP,o,o1), RESERVE.l(currTP,o1,i_reserveClass,i_reserveType)]
                                                                                                 ] ;


      o_genHVDCriskSetterMax(dt,ild,o,i_reserveClass) = SMax[HVDCsecRisk, o_genHVDCriskSetter(dt,ild,o,i_reserveClass,HVDCsecRisk)] ;


      o_HVDCriskSetterMax(dt,ild,i_reserveClass) = Smax[HVDCrisk, o_HVDCriskSetter(dt,ild,i_reserveClass,HVDCrisk)] ;
      o_manuRiskSetterMax(dt,ild,i_reserveClass) = Smax[ManualRisk, o_manuRiskSetter(dt,ild,i_reserveClass,ManualRisk)] ;
      o_manuHVDCriskSetterMax(dt,ild,i_reserveClass) = Smax[HVDCsecRisk, o_manuHVDCriskSetter(dt,ild,i_reserveClass,HVDCsecRisk)] ;

* RDN - FIR and SIR required based on calculations of the island risk to overcome reporting issues of the risk setter under degenerate conditions when reserve price = 0 - See below
      o_FIRreqd_TP(dt,ild) = Max [ 0,
                                                Smax((i_reserveClass,o)$(ord(i_reserveClass) = 1), o_generationRiskSetterMax(dt,ild,o,i_reserveClass)),
                                                sum(i_reserveClass$(ord(i_reserveClass) = 1), o_HVDCriskSetterMax(dt,ild,i_reserveClass)),
                                                sum(i_reserveClass$(ord(i_reserveClass) = 1), o_manuRiskSetterMax(dt,ild,i_reserveClass)),
                                                Smax((i_reserveClass,o)$(ord(i_reserveClass) = 1), o_genHVDCriskSetterMax(dt,ild,o,i_reserveClass)),
                                                sum(i_reserveClass$(ord(i_reserveClass) = 1), o_manuHVDCriskSetterMax(dt,ild,i_reserveClass))
                                              ] ;


      o_SIRreqd_TP(dt,ild) = Max [ 0,
                                                Smax((i_reserveClass,o)$(ord(i_reserveClass) = 2), o_generationRiskSetterMax(dt,ild,o,i_reserveClass)),
                                                sum(i_reserveClass$(ord(i_reserveClass) = 2), o_HVDCriskSetterMax(dt,ild,i_reserveClass)),
                                                sum(i_reserveClass$(ord(i_reserveClass) = 2), o_manuRiskSetterMax(dt,ild,i_reserveClass)),
                                                Smax((i_reserveClass,o)$(ord(i_reserveClass) = 2), o_genHVDCriskSetterMax(dt,ild,o,i_reserveClass)),
                                                sum(i_reserveClass$(ord(i_reserveClass) = 2), o_manuHVDCriskSetterMax(dt,ild,i_reserveClass))
                                              ] ;


      o_offerIsland_TP(dt,o,ild)$sum[(n,b)$[BusIsland(currTP,b,ild)
                                                                             and NodeBus(currTP,n,b)
                                                                             and offerNode(currTP,o,n)
                                                                           ],1] = yes ;

       o_FIRcleared_TP(dt,ild) = sum((o, i_reserveClass,i_reserveType)$[(ord(i_reserveClass) = 1) and offer(currTP,o) and o_offerIsland_TP(dt,o,ild)], RESERVE.l(currTP,o,i_reserveClass,i_reserveType)) ;
       o_SIRcleared_TP(dt,ild) = sum((o, i_reserveClass,i_reserveType)$[(ord(i_reserveClass) = 2) and offer(currTP,o) and o_offerIsland_TP(dt,o,ild)], RESERVE.l(currTP,o,i_reserveClass,i_reserveType)) ;

* RDN - Included reporting of risk - End-----------------


* Summary reporting
      o_solveOK_TP(dt) = ModelSolved ;


*RDN - 20130730 - Additional reporting on system objective function and penalty cost
*o_systemcost now represents the system costs only (excluding the penalty costs). See o_penalty and o_ofv for penalty and total cost
      o_systemCost_TP(dt) = sum((o,trdBlk)$ValidGenerationOfferBlock(currTP,o,trdBlk), GENERATIONBLOCK.l(currTP,o,trdBlk) * GenerationOfferPrice(currTP,o,trdBlk))
                                  + sum((o,trdBlk,i_reserveClass,i_reserveType)$ValidReserveOfferBlock(currTP,o,trdBlk,i_reserveClass,i_reserveType), RESERVEBLOCK.l(currTP,o,trdBlk,i_reserveClass,i_reserveType) * reserveOfferPrice(currTP,o,trdBlk,i_reserveClass,i_reserveType))
                                  + sum((i_bid,trdBlk,i_reserveClass)$validPurchaseBidILRBlock(currTP,i_bid,trdBlk,i_reserveClass), PURCHASEILRBLOCK.l(currTP,i_bid,trdBlk,i_reserveClass)) ;
$ONTEXT
* Penalty costs
                                  + sum(b$bus(currTP,b), DeficitBusGenerationPenalty * DEFICITBUSGENERATION.l(currTP,b))
                                  + sum(b$bus(currTP,b), SurplusBusGenerationPenalty * SURPLUSBUSGENERATION.l(currTP,b))
                                  + sum(br$branch(currTP,br), SurplusBranchFlowPenalty * SURPLUSBRANCHFLOW.l(currTP,br))
                                  + sum(o$offer(currTP,o), (DeficitRampRatePenalty * DEFICITRAMPRATE.l(currTP,o)) + (SurplusRampRatePenalty * SURPLUSRAMPRATE.l(currTP,o)))
                                  + sum(i_ACnodeConstraint$ACnodeConstraint(currTP,i_ACnodeConstraint), DeficitACnodeConstraintPenalty * DEFICITACnodeCONSTRAINT.l(currTP,i_ACnodeConstraint))
                                  + sum(i_ACnodeConstraint$ACnodeConstraint(currTP,i_ACnodeConstraint), SurplusACnodeConstraintPenalty * SURPLUSACnodeCONSTRAINT.l(currTP,i_ACnodeConstraint))
                                  + sum(i_branchConstraint$branchConstraint(currTP,i_branchConstraint), SurplusBranchGroupConstraintPenalty * SURPLUSBRANCHSECURITYCONSTRAINT.l(currTP,i_branchConstraint))
                                  + sum(i_branchConstraint$branchConstraint(currTP,i_branchConstraint), DeficitBranchGroupConstraintPenalty * DEFICITBRANCHSECURITYCONSTRAINT.l(currTP,i_branchConstraint))
                                  + sum(i_MnodeConstraint$MnodeConstraint(currTP,i_MnodeConstraint), DeficitMnodeConstraintPenalty * DEFICITMnodeCONSTRAINT.l(currTP,i_MnodeConstraint))
                                  + sum(i_MnodeConstraint$MnodeConstraint(currTP,i_MnodeConstraint), SurplusMnodeConstraintPenalty * SURPLUSMnodeCONSTRAINT.l(currTP,i_MnodeConstraint))
                                  + sum(i_type1MixedConstraint$Type1MixedConstraint(currTP,i_type1MixedConstraint), Type1DeficitMixedConstraintPenalty * DEFICITTYPE1MIXEDCONSTRAINT.l(currTP,i_type1MixedConstraint))
                                  + sum(i_type1MixedConstraint$Type1MixedConstraint(currTP,i_type1MixedConstraint), Type1SurplusMixedConstraintPenalty * SURPLUSTYPE1MIXEDCONSTRAINT.l(currTP,i_type1MixedConstraint))
                                  + sum(i_GenericConstraint$GenericConstraint(currTP,i_GenericConstraint), DeficitGenericConstraintPenalty * DEFICITGENERICCONSTRAINT.l(currTP,i_GenericConstraint))
                                  + sum(i_GenericConstraint$GenericConstraint(currTP,i_GenericConstraint), SurplusGenericConstraintPenalty * SURPLUSGENERICCONSTRAINT.l(currTP,i_GenericConstraint))
                                  + sum((ild,i_reserveClass)$(not diffCeECeCVP), DeficitReservePenalty(i_reserveClass) * DEFICITRESERVE.l(currTP,ild,i_reserveClass))
                                  + sum((ild,i_reserveClass)$diffCeECeCVP, DeficitReservePenalty_CE(i_reserveClass) * DEFICITRESERVE_CE.l(currTP,ild,i_reserveClass))
                                  + sum((ild,i_reserveClass)$diffCeECeCVP, DeficitReservePenalty_ECE(i_reserveClass) * DEFICITRESERVE_ECE.l(currTP,ild,i_reserveClass))
                                  - sum((i_bid,trdBlk)$validPurchaseBidBlock(currTP,i_bid,trdBlk), PURCHASEBLOCK.l(currTP,i_bid,trdBlk) * purchaseBidPrice(currTP,i_bid,trdBlk)) ;
$OFFTEXT
      o_penaltyCost_TP(dt) = sum(b$bus(currTP,b), DeficitBusGenerationPenalty * DEFICITBUSGENERATION.l(currTP,b))
                                   + sum(b$bus(currTP,b), SurplusBusGenerationPenalty * SURPLUSBUSGENERATION.l(currTP,b))
                                   + sum(br$branch(currTP,br), SurplusBranchFlowPenalty * SURPLUSBRANCHFLOW.l(currTP,br))
                                   + sum(o$offer(currTP,o), (DeficitRampRatePenalty * DEFICITRAMPRATE.l(currTP,o)) + (SurplusRampRatePenalty * SURPLUSRAMPRATE.l(currTP,o)))
                                   + sum(i_ACnodeConstraint$ACnodeConstraint(currTP,i_ACnodeConstraint), DeficitACnodeConstraintPenalty * DEFICITACnodeCONSTRAINT.l(currTP,i_ACnodeConstraint))
                                   + sum(i_ACnodeConstraint$ACnodeConstraint(currTP,i_ACnodeConstraint), SurplusACnodeConstraintPenalty * SURPLUSACnodeCONSTRAINT.l(currTP,i_ACnodeConstraint))
                                   + sum(i_branchConstraint$branchConstraint(currTP,i_branchConstraint), SurplusBranchGroupConstraintPenalty * SURPLUSBRANCHSECURITYCONSTRAINT.l(currTP,i_branchConstraint))
                                   + sum(i_branchConstraint$branchConstraint(currTP,i_branchConstraint), DeficitBranchGroupConstraintPenalty * DEFICITBRANCHSECURITYCONSTRAINT.l(currTP,i_branchConstraint))
                                   + sum(i_MnodeConstraint$MnodeConstraint(currTP,i_MnodeConstraint), DeficitMnodeConstraintPenalty * DEFICITMnodeCONSTRAINT.l(currTP,i_MnodeConstraint))
                                   + sum(i_MnodeConstraint$MnodeConstraint(currTP,i_MnodeConstraint), SurplusMnodeConstraintPenalty * SURPLUSMnodeCONSTRAINT.l(currTP,i_MnodeConstraint))
                                   + sum(i_type1MixedConstraint$Type1MixedConstraint(currTP,i_type1MixedConstraint), Type1DeficitMixedConstraintPenalty * DEFICITTYPE1MIXEDCONSTRAINT.l(currTP,i_type1MixedConstraint))
                                   + sum(i_type1MixedConstraint$Type1MixedConstraint(currTP,i_type1MixedConstraint), Type1SurplusMixedConstraintPenalty * SURPLUSTYPE1MIXEDCONSTRAINT.l(currTP,i_type1MixedConstraint))
                                   + sum(i_GenericConstraint$GenericConstraint(currTP,i_GenericConstraint), DeficitGenericConstraintPenalty * DEFICITGENERICCONSTRAINT.l(currTP,i_GenericConstraint))
                                   + sum(i_GenericConstraint$GenericConstraint(currTP,i_GenericConstraint), SurplusGenericConstraintPenalty * SURPLUSGENERICCONSTRAINT.l(currTP,i_GenericConstraint))
                                   + sum((ild,i_reserveClass)$(not diffCeECeCVP), DeficitReservePenalty(i_reserveClass) * DEFICITRESERVE.l(currTP,ild,i_reserveClass))
                                   + sum((ild,i_reserveClass)$diffCeECeCVP, DeficitReservePenalty_CE(i_reserveClass) * DEFICITRESERVE_CE.l(currTP,ild,i_reserveClass))
                                   + sum((ild,i_reserveClass)$diffCeECeCVP, DeficitReservePenalty_ECE(i_reserveClass) * DEFICITRESERVE_ECE.l(currTP,ild,i_reserveClass))
                                   - sum((i_bid,trdBlk)$validPurchaseBidBlock(currTP,i_bid,trdBlk), PURCHASEBLOCK.l(currTP,i_bid,trdBlk) * purchaseBidPrice(currTP,i_bid,trdBlk)) ;

      o_ofv_TP(dt) = o_systemCost_TP(dt) + o_penaltyCost_TP(dt);
*RDN - 20130730 - Additional reporting on system objective function and penalty cost

* Separete violation reporting at trade period level
      o_defGenViolation_TP(dt) = sum(b$bus(currTP,b),  DEFICITBUSGENERATION.l(currTP,b)) ;
      o_surpGenViolation_TP(dt) = sum(b$bus(currTP,b), SURPLUSBUSGENERATION.l(currTP,b)) ;
      o_surpBranchFlow_TP(dt) = sum(br$branch(currTP,br), SURPLUSBRANCHFLOW.l(currTP,br)) ;
      o_defRampRate_TP(dt) = sum(o$offer(currTP,o), DEFICITRAMPRATE.l(currTP,o)) ;
      o_surpRampRate_TP(dt) = sum(o$offer(currTP,o), SURPLUSRAMPRATE.l(currTP,o)) ;
      o_surpBranchGroupConst_TP(dt) = sum(i_branchConstraint$branchConstraint(currTP,i_branchConstraint), SURPLUSBRANCHSECURITYCONSTRAINT.l(currTP,i_branchConstraint)) ;
      o_defBranchGroupConst_TP(dt) = sum(i_branchConstraint$branchConstraint(currTP,i_branchConstraint), DEFICITBRANCHSECURITYCONSTRAINT.l(currTP,i_branchConstraint)) ;
      o_defMnodeConst_TP(dt) = sum(i_MnodeConstraint$MnodeConstraint(currTP,i_MnodeConstraint), DEFICITMnodeCONSTRAINT.l(currTP,i_MnodeConstraint)) ;
      o_surpMnodeConst_TP(dt) = sum(i_MnodeConstraint$MnodeConstraint(currTP,i_MnodeConstraint), SURPLUSMnodeCONSTRAINT.l(currTP,i_MnodeConstraint)) ;
      o_defACnodeConst_TP(dt) = sum(i_ACnodeConstraint$ACnodeConstraint(currTP,i_ACnodeConstraint), DEFICITACnodeCONSTRAINT.l(currTP,i_ACnodeConstraint)) ;
      o_surpACnodeConst_TP(dt) = sum(i_ACnodeConstraint$ACnodeConstraint(currTP,i_ACnodeConstraint), SURPLUSACnodeCONSTRAINT.l(currTP,i_ACnodeConstraint)) ;

      o_defT1MixedConst_TP(dt) = sum(i_type1MixedConstraint$Type1MixedConstraint(currTP,i_type1MixedConstraint), DEFICITTYPE1MIXEDCONSTRAINT.l(currTP,i_type1MixedConstraint)) ;
      o_surpT1MixedConst_TP(dt) = sum(i_type1MixedConstraint$Type1MixedConstraint(currTP,i_type1MixedConstraint), SURPLUSTYPE1MIXEDCONSTRAINT.l(currTP,i_type1MixedConstraint)) ;

      o_defGenericConst_TP(dt) = sum(i_GenericConstraint$GenericConstraint(currTP,i_GenericConstraint), DEFICITGENERICCONSTRAINT.l(currTP,i_GenericConstraint)) ;
      o_surpGenericConst_TP(dt) =  sum(i_GenericConstraint$GenericConstraint(currTP,i_GenericConstraint), SURPLUSGENERICCONSTRAINT.l(currTP,i_GenericConstraint)) ;
      o_defResv_TP(dt) =  sum((ild,i_reserveClass)$(not diffCeECeCVP), DEFICITRESERVE.l(currTP,ild,i_reserveClass))
                          + sum((ild,i_reserveClass)$diffCeECeCVP, DEFICITRESERVE_CE.l(currTP,ild,i_reserveClass) + DEFICITRESERVE_ECE.l(currTP,ild,i_reserveClass)) ;

      o_totalViolation_TP(dt) = o_defGenViolation_TP(dt) + o_surpGenViolation_TP(dt) + o_surpBranchFlow_TP(dt) + o_defRampRate_TP(dt) + o_surpRampRate_TP(dt) + o_surpBranchGroupConst_TP(dt)
                                      + o_defBranchGroupConst_TP(dt) + o_defMnodeConst_TP(dt) + o_surpMnodeConst_TP(dt) + o_defACnodeConst_TP(dt) + o_surpACnodeConst_TP(dt) + o_defT1MixedConst_TP(dt)
                                      + o_surpT1MixedConst_TP(dt) + o_defGenericConst_TP(dt) + o_surpGenericConst_TP(dt) + o_defResv_TP(dt) ;
     ) ;
    ) ;


* Summary reports
* System level
      o_numTradePeriods = o_numTradePeriods + sum(currTP,1) ;
      o_systemOFV = o_systemOFV + NETBENEFIT.l ;
      o_systemGen = o_systemGen + sum(bus,BusGeneration(bus)) ;
      o_systemLoad = o_systemLoad + sum(bus,BusLoad(bus)) ;
      o_systemLoss = o_systemLoss + sum((ClosedBranch,i_flowDirection),ACBRANCHLOSSESDIRECTED.l(ClosedBranch,i_flowDirection)) + sum(ClosedBranch, ACbranchFixedLoss(ClosedBranch))
        + sum(ClosedBranch, HVDClINKLOSSES.l(ClosedBranch) + HVDClinkFixedLoss(ClosedBranch)) ;
      o_systemViolation = o_systemViolation + sum(bus, DEFICITBUSGENERATION.l(bus) + SURPLUSBUSGENERATION.l(bus)) +
* RDN - Update reserve violation calculations based on different CE and ECE violations
*                          sum((currTP,ild,i_reserveClass), DEFICITRESERVE.l(currTP,ild,i_reserveClass)) +
                          (sum((currTP,ild,i_reserveClass), DEFICITRESERVE.l(currTP,ild,i_reserveClass))$(not diffCeECeCVP)) +
                          (sum((currTP,ild,i_reserveClass), DEFICITRESERVE_CE.l(currTP,ild,i_reserveClass) + DEFICITRESERVE_ECE.l(currTP,ild,i_reserveClass))$(diffCeECeCVP)) +
                          sum(branchConstraint, DEFICITBRANCHSECURITYCONSTRAINT.l(branchConstraint) + SURPLUSBRANCHSECURITYCONSTRAINT.l(branchConstraint)) +
                          sum(offer, DEFICITRAMPRATE.l(offer) + SURPLUSRAMPRATE.l(offer)) +
                          sum(ACnodeConstraint, DEFICITACnodeCONSTRAINT.l(ACnodeConstraint) + SURPLUSACnodeCONSTRAINT.l(ACnodeConstraint)) +
                          sum(branch, DEFICITBRANCHFLOW.l(branch) + SURPLUSBRANCHFLOW.l(branch)) +
                          sum(MnodeConstraint, DEFICITMnodeCONSTRAINT.l(MnodeConstraint) + SURPLUSMnodeCONSTRAINT.l(MnodeConstraint)) +
                          sum((currTP,i_type1MixedConstraint), DEFICITTYPE1MIXEDCONSTRAINT.l(currTP,i_type1MixedConstraint) + SURPLUSTYPE1MIXEDCONSTRAINT.l(currTP,i_type1MixedConstraint)) +
                          sum(GenericConstraint, SURPLUSGENERICCONSTRAINT.l(GenericConstraint) + DEFICITGENERICCONSTRAINT.l(GenericConstraint)) ;
      o_systemFIR = o_systemFIR + sum((offer,i_reserveClass,i_reserveType)$(ord(i_reserveClass) = 1), RESERVE.l(offer,i_reserveClass,i_reserveType)) + sum((bid,i_reserveClass)$(ord(i_reserveClass) = 1), PURCHASEILR.l(bid,i_reserveClass)) ;
      o_systemSIR = o_systemSIR + sum((offer,i_reserveClass,i_reserveType)$(ord(i_reserveClass) = 2), RESERVE.l(offer,i_reserveClass,i_reserveType)) + sum((bid,i_reserveClass)$(ord(i_reserveClass) = 2), PURCHASEILR.l(bid,i_reserveClass)) ;
      o_systemEnergyRevenue = o_systemEnergyRevenue + (i_tradingPeriodLength/60)*sum((currTP,o,b,n)$(offerNode(currTP,o,n) and NodeBus(currTP,n,b)), NodeBusAllocationFactor(currTP,n,b) * GENERATION.l(currTP,o) * busPrice(currTP,b)) ;
      o_systemReserveRevenue = o_systemReserveRevenue + (i_tradingPeriodLength/60)*sum((currTP,ild,o,n,b,i_reserveClass,i_reserveType)$(offerNode(currTP,o,n) and NodeBus(currTP,n,b) and i_tradePeriodBusIsland(currTP,b,ild)), SupplyDemandReserveRequirement.m(currTP,ild,i_reserveClass) * RESERVE.l(currTP,o,i_reserveClass,i_reserveType)) ;
      o_systemLoadCost = o_systemLoadCost + (i_tradingPeriodLength/60)*sum((currTP,b,n)$(NodeBus(currTP,n,b) and (NodeDemand(currTP,n) >= 0)), NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n) * busPrice(currTP,b)) ;
      o_systemLoadRevenue = o_systemLoadRevenue + (i_tradingPeriodLength/60)*sum((currTP,b,n)$(NodeBus(currTP,n,b) and (NodeDemand(currTP,n) < 0)), NodeBusAllocationFactor(currTP,n,b) * (-NodeDemand(currTP,n)) * busPrice(currTP,b)) ;
      o_systemACrentals = o_systemACrentals + sum((currTP,dt,br)$(i_dateTimeTradePeriodMap(dt,currTP) and ACbranch(currTP,br)), o_branchTotalRentals_TP(dt,br)) ;
      o_systemDCrentals = o_systemDCrentals + sum((currTP,dt,br)$(i_dateTimeTradePeriodMap(dt,currTP) and HVDClink(currTP,br)), o_branchTotalRentals_TP(dt,br)) ;

* Offer level
* This does not include revenue from wind generators for final pricing because the wind generation is netted off against load
* at the particular bus for the final pricing solves
      o_offerTrader(o,trdr)$sum(currTP$i_tradePeriodOfferTrader(currTP,o,trdr),1) = yes ;
      o_offerGen(o) = o_offerGen(o) + (i_tradingPeriodLength/60)*sum(currTP, GENERATION.l(currTP,o)) ;
      o_offerFIR(o) = o_offerFIR(o) + (i_tradingPeriodLength/60)*sum((currTP,i_reserveClass,i_reserveType)$(ord(i_reserveClass) = 1), RESERVE.l(currTP,o,i_reserveClass,i_reserveType)) ;
      o_offerSIR(o) = o_offerSIR(o) + (i_tradingPeriodLength/60)*sum((currTP,i_reserveClass,i_reserveType)$(ord(i_reserveClass) = 2), RESERVE.l(currTP,o,i_reserveClass,i_reserveType)) ;
      o_offerGenRevenue(o) = o_offerGenRevenue(o)
        + (i_tradingPeriodLength/60)*sum((currTP,b,n)$(offerNode(currTP,o,n) and NodeBus(currTP,n,b)), NodeBusAllocationFactor(currTP,n,b) * GENERATION.l(currTP,o) * busPrice(currTP,b)) ;
      o_offerFIRrevenue(o) = o_offerFIRrevenue(o)
        + (i_tradingPeriodLength/60)*sum((currTP,ild,n,b,i_reserveClass,i_reserveType)$((ord(i_reserveClass) = 1) and offerNode(currTP,o,n) and NodeBus(currTP,n,b) and i_tradePeriodBusIsland(currTP,b,ild)), SupplyDemandReserveRequirement.m(currTP,ild,i_reserveClass) * RESERVE.l(currTP,o,i_reserveClass,i_reserveType)) ;
      o_offerSIRrevenue(o) = o_offerSIRrevenue(o)
        + (i_tradingPeriodLength/60)*sum((currTP,ild,n,b,i_reserveClass,i_reserveType)$((ord(i_reserveClass) = 2) and offerNode(currTP,o,n) and NodeBus(currTP,n,b) and i_tradePeriodBusIsland(currTP,b,ild)), SupplyDemandReserveRequirement.m(currTP,ild,i_reserveClass) * RESERVE.l(currTP,o,i_reserveClass,i_reserveType)) ;

* End of if statement for the resolve skipped
  ) ;

* End of if statement to determine which periods to solve
 ) ;

 if(skipResolve,
* Set to sequential solve if the simultaneous solve failed and reset iteration counter
   sequentialsolve = 1 ;
   iterationCount = 0 ;
* Reset some of the reporting parameters if reverting to a sequential solve after simultaneous solve fails
   o_numTradePeriods = 0 ;
   o_systemOFV = 0 ;
   o_systemGen = 0 ;
   o_systemLoad = 0 ;
   o_systemLoss = 0 ;
   o_systemViolation = 0 ;
   o_systemFIR = 0 ;
   o_systemSIR = 0 ;
   o_systemEnergyRevenue = 0 ;
   o_systemReserveRevenue = 0 ;
   o_systemLoadCost = 0 ;
   o_systemLoadRevenue = 0 ;
   o_systemACrentals = 0 ;
   o_systemDCrentals = 0 ;
   o_offerGen(o) = 0 ;
   o_offerFIR(o) = 0 ;
   o_offerSIR(o) = 0 ;
   o_offerGenRevenue(o) = 0 ;
   o_offerFIRrevenue(o) = 0 ;
   o_offerSIRrevenue(o) = 0 ;
 ) ;


*=====================================================================================
* i) End of the solve vSPD loop
) ;



*=====================================================================================
* 8. Write results to GDX files
*=====================================================================================
* Report the results from the solves

* Write out summary report
* System level
o_fromDateTime(dt)$( ord(dt) = 1 ) = yes ;

* System surplus needs to be calculated outside the main loop
o_systemSurplus = o_systemLoadCost - o_systemLoadRevenue - o_systemEnergyRevenue ;

execute_unload '%outputPath%\%runName%\RunNum%vSPDRunNum%_SystemOutput.gdx', o_fromDateTime, o_numTradePeriods, o_systemOFV, o_systemGen
                 o_systemLoad, o_systemLoss, o_systemViolation, o_systemFIR, o_systemSIR, o_systemEnergyRevenue, o_systemLoadCost
                 o_systemLoadRevenue, o_systemSurplus ;
* Offer level
execute_unload '%outputPath%\%runName%\RunNum%vSPDRunNum%_OfferOutput.gdx', i_offer, i_trader, o_offerTrader, o_offerGen, o_offerFIR, o_offerSIR ;

* Trader level
* Currently this does not include revenue from wind generators since wind generation in FP is represented as negative load
o_trader(trdr) = yes ;
o_traderGen(trdr) = sum(o$o_offerTrader(o,trdr), o_offerGen(o)) ;
o_traderFIR(trdr) = sum(o$o_offerTrader(o,trdr), o_offerFIR(o)) ;
o_traderSIR(trdr) = sum(o$o_offerTrader(o,trdr), o_offerSIR(o)) ;
o_traderGenRevenue(trdr) = sum(o$o_offerTrader(o,trdr), o_offerGenRevenue(o)) ;
o_traderFIRrevenue(trdr) = sum(o$o_offerTrader(o,trdr), o_offerFIRrevenue(o)) ;
o_traderSIRrevenue(trdr) = sum(o$o_offerTrader(o,trdr), o_offerSIRrevenue(o)) ;

execute_unload '%outputPath%\%runName%\RunNum%vSPDRunNum%_TraderOutput.gdx', o_trader, o_traderGen, o_traderFIR, o_traderSIR ;

* Write out detailed reports if requested
if(tradePeriodReports = 1,

  execute_unload '%outputPath%\%runName%\RunNum%vSPDRunNum%_SummaryOutput_TP.gdx', o_dateTime, o_solveOK_TP, o_systemCost_TP, o_defGenViolation_TP
                   o_surpGenViolation_TP, o_surpBranchFlow_TP, o_defRampRate_TP, o_surpRampRate_TP, o_surpBranchGroupConst_TP, o_defBranchGroupConst_TP
                   o_defMnodeConst_TP, o_surpMnodeConst_TP, o_defACnodeConst_TP, o_surpACnodeConst_TP, o_defT1MixedConst_TP, o_surpT1MixedConst_TP
                   o_defGenericConst_TP, o_surpGenericConst_TP, o_defResv_TP, o_totalViolation_TP
*RDN - 20130730 - Additional reporting on system objective function and penalty cost
                   o_ofv_TP, o_penaltyCost_TP ;
*RDN - 20130730 - Additional reporting on system objective function and penalty cost


  execute_unload '%outputPath%\%runName%\RunNum%vSPDRunNum%_IslandOutput_TP.gdx', o_islandGen_TP, o_islandLoad_TP, o_islandEnergyRevenue_TP
                   o_islandLoadCost_TP, o_islandLoadRevenue_TP, o_islandBranchLoss_TP, o_HVDCflow_TP, o_HVDCloss_TP, o_islandRefPrice_TP ;

  execute_unload '%outputPath%\%runName%\RunNum%vSPDRunNum%_BusOutput_TP.gdx', o_bus, o_busGeneration_TP, o_busLoad_TP, o_busPrice_TP, o_busRevenue_TP
                   o_busCost_TP, o_busDeficit_TP, o_busSurplus_TP ;

  execute_unload '%outputPath%\%runName%\RunNum%vSPDRunNum%_BranchOutput_TP.gdx', o_branch, o_branchFromBus_TP, o_branchToBus_TP, o_branchFlow_TP
                   o_branchDynamicLoss_TP, o_branchFixedLoss_TP, o_branchFromBusPrice_TP, o_branchToBusPrice_TP, o_branchMarginalPrice_TP, o_branchTotalRentals_TP
                   o_branchCapacity_TP ;

  execute_unload '%outputPath%\%runName%\RunNum%vSPDRunNum%_NodeOutput_TP.gdx', o_node, o_nodeGeneration_TP, o_nodeLoad_TP, o_nodePrice_TP, o_nodeRevenue_TP
                   o_nodeCost_TP, o_nodeDeficit_TP, o_nodeSurplus_TP ;

  execute_unload '%outputPath%\%runName%\RunNum%vSPDRunNum%_OfferOutput_TP.gdx', o_offer, o_offerEnergy_TP, o_offerFIR_TP, o_offerSIR_TP ;

  execute_unload '%outputPath%\%runName%\RunNum%vSPDRunNum%_ReserveOutput_TP.gdx', o_island, o_FIRreqd_TP, o_SIRreqd_TP, o_FIRprice_TP, o_SIRprice_TP
                   o_FIRviolation_TP, o_SIRviolation_TP ;

  execute_unload '%outputPath%\%runName%\RunNum%vSPDRunNum%_BrConstraintOutput_TP.gdx', o_brConstraint_TP, o_brConstraintSense_TP, o_brConstraintLHS_TP
                   o_brConstraintRHS_TP, o_brConstraintPrice_TP ;

  execute_unload '%outputPath%\%runName%\RunNum%vSPDRunNum%_MnodeConstraintOutput_TP.gdx', o_MnodeConstraint_TP, o_MnodeConstraintSense_TP
                   o_MnodeConstraintLHS_TP, o_MnodeConstraintRHS_TP, o_MnodeConstraintPrice_TP ;

* TN - Additional output for audit reporting
  if(opMode = -1,
    execute_unload '%outputPath%\%runName%\RunNum%vSPDRunNum%_AuditOutput_TP.gdx', o_ACbusAngle, o_lossSegmentBreakPoint, o_lossSegmentFactor
                     o_nonPhysicalLoss, o_busIsland_TP, o_marketNodeIsland_TP, o_ILRO_FIR_TP, o_ILRO_SIR_TP, o_ILbus_FIR_TP, o_ILbus_SIR_TP, o_PLRO_FIR_TP
                     o_PLRO_SIR_TP, o_TWRO_FIR_TP, o_TWRO_SIR_TP, o_generationRiskSetter, o_genHVDCriskSetter, o_HVDCriskSetter, o_manuRiskSetter
                     o_manuHVDCriskSetter, o_FIRcleared_TP, o_SIRcleared_TP ;
   ) ;
* TN - Additional output for audit reporting - End

) ;


$label FTR_process
* If calculating FTR rentals, do the FTR rental reporting
*$if %calcFTRrentals%==1 $include FTR_2.ins


* Post a progress message for use by EMI.
putclose runlog / 'The case: %vSPDinputData% is complete. (', system.time, ').' //// ;


* Go to the next input file
$label nextInput


* Post a progress message for use by EMI.
$ if not exist "%inputPath%\%vSPDinputData%.gdx" putclose runlog / 'The file %programPath%Input\%vSPDinputData%.gdx could not be found (', system.time, ').' // ;
