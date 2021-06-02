*=====================================================================================
* Name:                 vSPDsolve.gms
* Function:             Establish base case and override data, prepare data, and solve
*                       the model
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: http://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Modified on:          1 Oct 2019	
*                       New feature added: new wind offer arrangements	
* Modified on:          11 Nov 2020	
*                       Replacing invalid bus prices after SOS1 (6.1.3)	
* Last modified on:     11 Dec 2020
*                       From 11 Dec 2020, GDX input file have i_tradePeriodBranchCapacityDirected
*                       and i_tradePeriodReverseRatingsApplied symbols	   
*                       Applying branch reverse rating	s only when i_tradePeriodReverseRatingsApplied = 1
*
*=====================================================================================

$ontext
  Directory of code sections in vSPDsolve.gms:
  1. Declare symbols and initialise some of them
  2. Load data from GDX file f
  3. Manage model and data compatability
  4. Input data overrides - declare and apply (include vSPDoverrides.gms)
  5. Initialise constraint violation penalties (CVPs)
  6. The vSPD solve loop
     a) Reset all sets, parameters and variables before proceeding with the next study trade period
     b) Initialise current trade period and model data for the current trade period
     c) Additional pre-processing on parameters and variables before model solve
     d) Solve the model
     e) Check if the LP results are valid
     f) Resolve the model if required
     g) Check for disconnected nodes and adjust prices accordingly
     h) Collect and store results from the current model solve in the output (o_xxx) parameters
     i) End of the solve vSPD loop
  7. vSPD scarcity pricing post-processing
  8. Write results to CSV report files and GDX files

Aliases to be aware of:
  i_island = ild, ild1                      i_dateTime = dt
  i_tradePeriod = tp                        i_node = n
  i_offer = o, o1                           i_trader = trdr
  i_tradeBlock = trdBlk                     i_bus = b, b1, frB, toB
  i_branch = br, br1                        i_lossSegment = los, los1
  i_branchConstraint = brCstr               i_ACnodeConstraint = ACnodeCstr
  i_MnodeConstraint = MnodeCstr             i_energyOfferComponent = NRGofrCmpnt
  i_PLSRofferComponent = PLSofrCmpnt        i_TWDRofferComponent = TWDofrCmpnt
  i_ILRofferComponent = ILofrCmpnt          i_energyBidComponent = NRGbidCmpnt
  i_ILRbidComponent = ILbidCmpnt            i_type1MixedConstraint = t1MixCstr
  i_type2MixedConstraint = t2MixCstr        i_type1MixedConstraintRHS = t1MixCstrRHS
  i_genericConstraint = gnrcCstr            i_scarcityArea = sarea
  i_reserveType = resT                      i_reserveClass = resC
  i_riskClass = riskC                       i_constraintRHS = CstrRHS
  i_riskParameter = riskPar                 i_offerParam = offerPar
  i_dczone = z,z1,rrz,rrz1                  i_riskGroup = rg,rg1)
$offtext


* Include paths, settings and case name files
$include vSPDsettings.inc
$include vSPDcase.inc
$if not %opMode%=='SPD' tradePeriodReports = 1 ;


* Update the runlog file
File runlog "Write to a report"  / "ProgressReport.txt" /;
runlog.lw = 0 ; runlog.ap = 1 ;
putclose runlog / 'Case "%vSPDinputData%" started at: '
                  system.date " " system.time /;
if(sequentialSolve,
  putclose runlog 'Vectorisation is switched OFF' /;
else
  putclose runlog 'Vectorisation is switched ON' /;
) ;

* Set the solver for the LP and MIP
option lp = %Solver% ;
option mip = %Solver% ;

* Set profile status
option profile = 0 ;

* Set the solution print status in the lst file
option solprint = off;

* Set the column (variable) and row (equation) listing in the lst file
option limcol = 0 ;
option limrow = 0 ;

* Allow empty data set declaration
$onempty

* Declare a temporary file
File temp ;

*=====================================================================================
* 1. Declare symbols and initialise some of them
*=====================================================================================

Sets
* Initialise fundamental sets by hard-coding (these sets can also be found in the daily GDX files)
  i_island                    / NI, SI /
  i_reserveClass              / FIR, SIR /

$ontext
 Scarcity pricing updates --> i_reserveType
 Rather than include an additional reserve type element an additional virutal
 reserve paramter and associated variable is created. This is more efficient
 implementation in terms of the problem size as all other reserve providers
 are indexed on i_reserveType which would include an additional index on all
 these variables thus increasing the problem size. This increase would then
 need additional pre-processing to fix variables to zero. To avoid this and
 keep the problem size small the additional virtual reserve variable is included.
$offtext
  i_reserveType               / PLSR, TWDR, ILR /

  i_riskClass                 / genRisk, DCCE, DCECE, manual, genRisk_ECE
                                manual_ECE, HVDCsecRisk_CE, HVDCsecRisk_ECE /
  i_riskParameter             / i_freeReserve, i_riskAdjustmentFactor, i_HVDCpoleRampUp /
  i_offerType                 / energy, PLSR, TWDR, ILR /
  i_offerParam                / i_initialMW, i_rampUpRate, i_rampDnRate
                                i_reserveGenerationMaximum, i_windOffer, i_FKbandMW,
                                i_IsPriceResponse, i_PotentialMW  /
  i_energyOfferComponent      / i_generationMWoffer, i_generationMWofferPrice /
  i_PLSRofferComponent        / i_PLSRofferPercentage, i_PLSRofferMax, i_PLSRofferPrice /
  i_TWDRofferComponent        / i_TWDRofferMax, i_TWDRofferPrice /
  i_ILRofferComponent         / i_ILRofferMax, i_ILRofferPrice /
  i_energyBidComponent        / i_bidMW, i_bidPrice /
  i_ILRbidComponent           / i_ILRbidMax, i_ILRbidPrice /
  i_tradeBlock                / t1*t20 /
  i_lossSegment               / ls1*ls13 /
  i_lossParameter             / i_MWbreakPoint, i_lossCoefficient /
  i_branchParameter           / i_branchResistance, i_branchSusceptance, i_branchFixedLosses, i_numLossTranches /
  i_constraintRHS             / i_constraintSense, i_constraintLimit /
  i_type1MixedConstraintRHS   / i_mixedConstraintSense, i_mixedConstraintLimit1, i_mixedConstraintLimit2 /
  i_flowDirection             / forward, backward /
  i_CVP                       / i_deficitBusGeneration, i_surplusBusGeneration
                                i_deficit6sReserve_CE, i_deficit60sReserve_CE
                                i_deficitBranchGroupConstraint, i_surplusBranchGroupConstraint
                                i_deficitGenericConstraint, i_surplusGenericConstraint
                                i_deficitRampRate, i_surplusRampRate
                                i_deficitACnodeConstraint, i_surplusACnodeConstraint
                                i_deficitBranchFlow, i_surplusBranchFlow
                                i_deficitMnodeConstraint, i_surplusMnodeConstraint
                                i_type1DeficitMixedConstraint, i_type1SurplusMixedConstraint
                                i_deficit6sReserve_ECE, i_deficit60sReserve_ECE /

* Initialise the set called pole
  pole  'HVDC poles'          / pole1, pole2 /

* Scarcity pricing updates
  i_scarcityArea              /NI, SI, National/

* NMIR - HVDC flow zones for reverse reserve sharing
  i_dczone                    /RP, NR, RZ/

  ;



* 'startyear' must be modified if you ever decide it is clever to change the first element of i_yearnum.
Scalar startYear 'Start year - used in computing Gregorian date for override years'  / 1899 / ;

Sets
  scarcityAreaIslandMap(sarea,ild)                    'Mapping of scarcity area to island'
  unsolvedPeriod(tp)                                  'Set of periods that are not solved yet'
* Unmmaped bus defificit temporary sets
  unmappedDeficitBus(dt,b)                            'List of buses that have deficit generation (price) and are not mapped to any pnode'
  changedDeficitBus(dt,b)                             'List of buses that have deficit generation added from unmapped deficit bus'
* TN - Replacing invalid prices after SOS1	
  vSPD_SOS1_Solve(tp)                                 'Flag period that is resolved using SOS1'  
  ;

Parameters
* Flag to apply corresponding vSPD model
  VSPDModel(tp)                                       '0=VSPD, 1=VSPD_MIP, 2=vSPD_BranchFlowMIP, 3=vSPD_MixedConstraintMIP, 4=VSPD (last solve)'
* Main iteration counter
  iterationCount                                      'Iteration counter for the solve'
* MIP logic
  circularBranchFlowExist(tp,br)                      'Flag to indicate if circulating branch flows exist on each branch: 1 = Yes'
* Introduce flag to detect circular branch flows on each HVDC pole
  poleCircularBranchFlowExist(tp,pole)                'Flag to indicate if circulating branch flows exist on each an HVDC pole: 1 = Yes'
  northHVDC(tp)                                       'HVDC MW sent from from SI to NI'
  southHVDC(tp)                                       'HVDC MW sent from from NI to SI'
  nonPhysicalLossExist(tp,br)                         'Flag to indicate if non-physical losses exist on branch: 1 = Yes'
  manualBranchSegmentMWFlow(tp,br,los,fd)             'Manual calculation of the branch loss segment MW flow'
  manualLossCalculation(tp,br)                        'MW losses calculated manually from the solution for each loss branch'
  HVDChalfPoleSouthFlow(tp)                           'Flag to indicate if south flow on HVDC halfpoles'
  type1MixedConstraintLimit2Violation(tp, t1MixCstr)  'Type 1 mixed constraint MW violaton of the alternate limit value'
* Parameters to calculate circular branch flow on each HVDC pole
  TotalHVDCpoleFlow(tp,pole)                          'Total flow on an HVDC pole'
  MaxHVDCpoleFlow(tp,pole)                            'Maximum flow on an HVDC pole'
* Disconnected bus post-processing
  busGeneration(tp,b)                                 'MW generation at each bus for the study trade periods'
  busLoad(tp,b)                                       'MW load at each bus for the study trade periods'
  busPrice(tp,b)                                      '$/MW price at each bus for the study trade periods'
  busDisconnected(tp,b)                               'Indication if bus is disconnected or not (1 = Yes) for the study trade periods'
* Scarcity pricing processing parameters
  scarcitySituation(tp,sarea)                         'Flag to indicate that a scarcity situation exists (1 = Yes)'
  GWAPFloor(tp,sarea)                                 'Floor price for the scarcity situation in scarcity area'
  GWAPCeiling(tp,sarea)                               'Ceiling price for the scarcity situation in scarcity area'
  GWAPPastDaysAvg(tp,ild)                             'Average GWAP over past days - number of periods in GWAP count'
  GWAPCountForAvg(tp,ild)                             'Number of periods used for the i_gwapPastDaysAvg'
  GWAPThreshold(tp,ild)                               'Threshold on previous 336 trading period GWAP - cumulative price threshold'
  islandGWAP(tp,ild)                                  'Island GWAP calculation used to update GWAPPastDaysAvg'
  scarcityAreaGWAP(tp,sarea)                          'Scarcity area GWAP used to calculate the scaling factor'
  pastGWAPsumforCPT(tp,ild)
  pastTPcntforCPT(tp,ild)
  currentDayGWAPsumforCPT(ild)
  currentDayTPsumforCPT(ild)
  avgPriorGWAP(tp,ild)
  cptIslandPassed(tp,sarea)
  cptPassed(tp,sarea)
  cptIslandReq(sarea)
  scarcityScalingFactor(tp,sarea)
  scaledbusPrice(tp,b)
  scalednodePrice(tp,n)
  scaledFIRprice(tp,ild)
  scaledSIRprice(tp,ild)
  scaledislandGWAP(tp,ild)
  scaledscarcityAreaGWAP(tp,sarea)
* Unmmaped bus defificit temporary parameters
  temp_busDeficit_TP(dt,b) 'Bus deficit violation for each trade period'
* TN - Replacing invalid prices after SOS1	
  busSOSinvalid(tp,b)                                 'Buses with invalid bus prices after SOS1 solve'	
  numberofbusSOSinvalid(tp)                           'Number of buses with invalid bus prices after SOS1 solve --> used to check if invalid prices can be improved (numberofbusSOSinvalid reduces after each iteration) '
* TN - Flag to apply branch reverse ratings
  reverseRatingsApplied(tp)  
  ;

Sets
* Dispatch results reporting
  o_fromDateTime(dt)                                  'Start period for summary reports'
  o_dateTime(dt)                                      'Date and time for reporting'
  o_bus(dt,b)                                         'Set of buses for output report'
  o_offer(dt,o)                                       'Set of offers for output report'
  o_bid(dt,bd)                                        'Set of bids for output report'
  o_island(dt,ild)                                    'Island definition for trade period reserve output report'
  o_offerTrader(o,trdr)                               'Mapping of offers to traders for offer summary reports'
  o_trader(trdr)                                      'Set of traders for trader summary output report'
  o_node(dt,n)                                        'Set of nodes for output report'
  o_branch(dt,br)                                     'Set of branches for output report'
  o_HVDClink(dt,br)                                   'HVDC links (branches) defined for the current trading period'
  o_branchFromBus_TP(dt,br,frB)                       'From bus for set of branches for output report'
  o_branchToBus_TP(dt,br,toB)                         'To bus for set of branches for output report'
  o_brConstraint_TP(dt,brCstr)                        'Set of branch constraints for output report'
  o_MnodeConstraint_TP(dt,MnodeCstr)                  'Set of Mnode constraints for output report'
* Audit - extra output declaration
  o_busIsland_TP(dt,b,ild)                                      'Audit - Bus island mapping'
  o_marketNodeIsland_TP(dt,o,ild)                               'Audit - Generation offer island mapping'
  ;

Parameters
* Dispatch results for reporting - Trade period level - Island output
  o_islandGen_TP(dt,ild)                              'Island MW generation for the different time periods'
  o_islandLoad_TP(dt,ild)                             'Island MW fixed load for the different time periods'
  o_islandClrBid_TP(dt,ild)                           'Island cleared MW bid for the different time periods'
  o_systemViolation_TP(dt,ild)                        'Island MW violation for the different time periods'
  o_islandEnergyRevenue_TP(dt,ild)                    'Island energy revenue ($) for the different time periods'
  o_islandReserveRevenue_TP(dt,ild)                   'Island reserve revenue ($) for the different time periods'
  o_islandLoadCost_TP(dt,ild)                         'Island load cost ($) for the different time periods'
  o_islandLoadRevenue_TP(dt,ild)                      'Island load revenue ($) for the different time periods'
  o_islandBranchLoss_TP(dt,ild)                       'Intra-island branch losses for the different time periods (MW)'
  o_islandRefPrice_TP(dt,ild)                         'Reference prices in each island ($/MWh)'
  o_HVDCflow_TP(dt,ild)                               'HVDC flow from each island (MW)'
  o_HVDCloss_TP(dt,ild)                               'HVDC losses (MW)'
  o_HVDChalfPoleLoss_TP(dt,ild)                       'Losses on HVDC half poles (MW)'
  o_HVDCpoleFixedLoss_TP(dt,ild)                      'Fixed loss on inter-island HVDC (MW)'
  o_busGeneration_TP(dt,b)                            'Output MW generation at each bus for the different time periods'
  o_busLoad_TP(dt,b)                                  'Output MW load at each bus for the different time periods'
  o_busPrice_TP(dt,b)                                 'Output $/MW price at each bus for the different time periods'
  o_busDisconnected_TP(dt,b)                          'Output disconnected bus flag (1 = Yes) for the different time periods'
  o_busRevenue_TP(dt,b)                               'Generation revenue ($) at each bus for the different time periods'
  o_busCost_TP(dt,b)                                  'Load cost ($) at each bus for the different time periods'
  o_busDeficit_TP(dt,b)                               'Bus deficit violation for each trade period'
  o_busSurplus_TP(dt,b)                               'Bus surplus violation for each trade period'
  o_branchFromBusPrice_TP(dt,br)                      'Output from bus price ($/MW) for branch reporting'
  o_branchToBusPrice_TP(dt,br)                        'Output to bus price ($/MW) for branch reporting'
  o_branchMarginalPrice_TP(dt,br)                     'Output marginal branch constraint price ($/MW) for branch reporting'
  o_branchFlow_TP(dt,br)                              'Output MW flow on each branch for the different time periods'
  o_branchDynamicLoss_TP(dt,br)                       'Output MW dynamic loss on each branch for the different time periods'
  o_branchTotalLoss_TP(dt,br)                         'Output MW total loss on each branch for the different time periods'
  o_branchFixedLoss_TP(dt,br)                         'Output MW fixed loss on each branch for the different time periods'
  o_branchTotalRentals_TP(dt,br)                      'Output $ rentals on transmission branches using total (dynamic + fixed) for the different time periods'
  o_branchCapacity_TP(dt,br)                          'Output MW branch capacity for branch reporting'
  o_ACbranchTotalRentals(dt)                          'Total AC rental by trading period for reporting'
  o_ACbranchLossMW(dt,br,los)                         'MW element of the loss segment curve in MW'
  o_ACbranchLossFactor(dt,br,los)                     'Loss factor element of the loss segment curve'
  o_offerEnergy_TP(dt,o)                              'Output MW cleared for each energy offer for each trade period'
  o_offerFIR_TP(dt,o)                                 'Output MW cleared for FIR for each trade period'
  o_offerSIR_TP(dt,o)                                 'Output MW cleared for SIR for each trade period'
  o_bidEnergy_TP(dt,bd)                               'Output MW cleared for each energy bid for each trade period'
  o_offerEnergyBlock_TP(dt,o,trdBlk)                  'Output MW cleared for each energy offer for each trade period'
  o_offerFIRBlock_TP(dt,o,trdBlk,resT)                'Output MW cleared for FIR for each trade period'
  o_offerSIRBlock_TP(dt,o,trdBlk,resT)                'Output MW cleared for SIR for each trade period'
  o_bidTotalMW_TP(dt,bd)                              'Output total MW bidded for each energy bid for each trade period'
  o_bidFIR_TP(dt,bd)                                  'Output MW cleared for FIR for each trade period'
  o_bidSIR_TP(dt,bd)                                  'Output MW cleared for SIR for each trade period'
  o_ReserveReqd_TP(dt,ild,resC)                       'Output MW required for each reserve class in each trade period'
  o_FIRreqd_TP(dt,ild)                                'Output MW required FIR for each trade period'
  o_SIRreqd_TP(dt,ild)                                'Output MW required SIR for each trade period'
  o_ResCleared_TP(dt,ild,resC)                        'Reserve cleared from an island for each trade period'
  o_FIRcleared_TP(dt,ild)                             'Output - total FIR cleared by island'
  o_SIRcleared_TP(dt,ild)                             'Output - total SIR cleared by island'
  o_ResPrice_TP(dt,ild,resC)                          'Output $/MW price for each reserve classes for each trade period'
  o_FIRprice_TP(dt,ild)                               'Output $/MW price for FIR reserve classes for each trade period'
  o_SIRprice_TP(dt,ild)                               'Output $/MW price for SIR reserve classes for each trade period'
  o_ResViolation_TP(dt,ild,resC)                      'Violation MW for each reserve classes for each trade period'
  o_FIRviolation_TP(dt,ild)                           'Violation MW for FIR reserve classes for each trade period'
  o_SIRviolation_TP(dt,ild)                           'Violation MW for SIR reserve classes for each trade period'
  o_nodeGeneration_TP(dt,n)                           'Ouput MW generation at each node for the different time periods'
  o_nodeLoad_TP(dt,n)                                 'Ouput MW load at each node for the different time periods'
  o_nodePrice_TP(dt,n)                                'Output $/MW price at each node for the different time periods'
  o_nodeRevenue_TP(dt,n)                              'Output $ revenue at each node for the different time periods'
  o_nodeCost_TP(dt,n)                                 'Output $ cost at each node for the different time periods'
  o_nodeDeficit_TP(dt,n)                              'Output node deficit violation for each trade period'
  o_nodeSurplus_TP(dt,n)                              'Output node surplus violation for each trade period'
* Security constraint data
  o_brConstraintSense_TP(dt,brCstr)                   'Branch constraint sense for each output report'
  o_brConstraintLHS_TP(dt,brCstr)                     'Branch constraint LHS for each output report'
  o_brConstraintRHS_TP(dt,brCstr)                     'Branch constraint RHS for each output report'
  o_brConstraintPrice_TP(dt,brCstr)                   'Branch constraint price for each output report'
* Mnode constraint data
  o_MnodeConstraintSense_TP(dt,MnodeCstr)             'Market node constraint sense for each output report'
  o_MnodeConstraintLHS_TP(dt,MnodeCstr)               'Market node constraint LHS for each output report'
  o_MnodeConstraintRHS_TP(dt,MnodeCstr)               'Market node constraint RHS for each output report'
  o_MnodeConstraintPrice_TP(dt,MnodeCstr)             'Market node constraint price for each output report'
* TradePeriod summary report
  o_solveOK_TP(dt)                                    'Solve status for summary report (1=OK)'
  o_systemCost_TP(dt)                                 'System cost for summary report'
  o_systemBenefit_TP(dt)                              'System benefit of cleared bids for summary report'
  o_ofv_TP(dt)                                        'Objective function value for summary report'
  o_penaltyCost_TP(dt)                                'Penalty cost for summary report'
  o_defGenViolation_TP(dt)                            'Deficit generation violation for summary report'
  o_surpGenViolation_TP(dt)                           'Surplus generaiton violation for summary report'
  o_surpBranchFlow_TP(dt)                             'Surplus branch flow violation for summary report'
  o_defRampRate_TP(dt)                                'Deficit ramp rate violation for summary report'
  o_surpRampRate_TP(dt)                               'Surplus ramp rate violation for summary report'
  o_surpBranchGroupConst_TP(dt)                       'Surplus branch group constraint violation for summary report'
  o_defBranchGroupConst_TP(dt)                        'Deficit branch group constraint violation for summary report'
  o_defMnodeConst_TP(dt)                              'Deficit market node constraint violation for summary report'
  o_surpMnodeConst_TP(dt)                             'Surplus market node constraint violation for summary report'
  o_defACnodeConst_TP(dt)                             'Deficit AC node constraint violation for summary report'
  o_surpACnodeConst_TP(dt)                            'Surplus AC node constraint violation for summary report'
  o_defT1MixedConst_TP(dt)                            'Deficit Type1 mixed constraint violation for sumamry report'
  o_surpT1MixedConst_TP(dt)                           'Surplus Type1 mixed constraint violation for summary report'
  o_defGenericConst_TP(dt)                            'Deficit generic constraint violation for summary report'
  o_surpGenericConst_TP(dt)                           'Surplus generic constraint violation for summary report'
  o_defResv_TP(dt)                                    'Deficit reserve violation for summary report'
  o_totalViolation_TP(dt)                             'Total violation for datawarehouse summary report'
* System level
  o_numTradePeriods                                   'Output number of trade periods in summary'
  o_systemOFV                                         'System objective function value'
  o_systemGen                                         'Output system MWh generation'
  o_systemLoad                                        'Output system MWh load'
  o_systemLoss                                        'Output system MWh loss'
  o_systemViolation                                   'Output system MWh violation'
  o_systemFIR                                         'Output system FIR MWh reserve'
  o_systemSIR                                         'Output system SIR MWh reserve'
  o_systemEnergyRevenue                               'Output offer energy revenue $'
  o_systemReserveRevenue                              'Output reserve revenue $'
  o_systemLoadCost                                    'Output system load cost $'
  o_systemLoadRevenue                                 'Output system load revenue $'
  o_systemSurplus                                     'Output system surplus $'
* Offer level
  o_offerGen(o)                                       'Output offer generation (MWh)'
  o_offerFIR(o)                                       'Output offer FIR (MWh)'
  o_offerSIR(o)                                       'Output offer SIR (MWh)'
  o_offerGenRevenue(o)                                'Output offer energy revenue ($)'
  o_offerFIRrevenue(o)                                'Output offer FIR revenue ($)'
  o_offerSIRrevenue(o)                                'Output offer SIR revenue ($)'
* Trader level
  o_traderGen(trdr)                                   'Output trader generation (MWh)'
  o_traderFIR(trdr)                                   'Output trader FIR (MWh)'
  o_traderSIR(trdr)                                   'Output trader SIR (MWh)'
  o_traderGenRevenue(trdr)                            'Output trader energy revenue ($)'
  o_traderFIRrevenue(trdr)                            'Output trader FIR revenue ($)'
  o_traderSIRrevenue(trdr)                            'Output trader SIR revenue ($)'
* Factor to prorate the deficit and surplus at the nodal level
  totalBusAllocation(dt,b)                            'Total allocation of nodes to bus'
  busNodeAllocationFactor(dt,b,n)                     'Bus to node allocation factor'
* Introduce i_useBusNetworkModel to account for MSP change-over date.
  i_useBusNetworkModel(tp)                            'Indicates if the post-MSP bus network model is used in vSPD (1 = Yes)'
* Virtual reserve output
  o_vrResMW_TP(dt,ild,resC)                           'MW scheduled from virtual reserve resource'
  o_FIRvrMW_TP(dt,ild)                                'MW scheduled from virtual FIR resource'
  o_SIRvrMW_TP(dt,ild)                                'MW scheduled from virtual SIR resource'
* Scarcity pricing output
  o_scarcityExists_TP(dt,ild)
  o_cptPassed_TP(dt,ild)
  o_avgPriorGWAP_TP(dt,ild)
  o_islandGWAPbefore_TP(dt,ild)
  o_islandGWAPafter_TP(dt,ild)
  o_scarcityGWAPbefore_TP(dt,ild)
  o_scarcityGWAPafter_TP(dt,ild)
  o_scarcityScalingFactor_TP(dt,ild)
  o_GWAPthreshold_TP(dt,ild)
  o_GWAPfloor_TP(dt,ild)
  o_GWAPceiling_TP(dt,ild)
* Audit - extra output declaration
  o_lossSegmentBreakPoint(dt,br,los)                            'Audit - loss segment MW'
  o_lossSegmentFactor(dt,br,los)                                'Audit - loss factor of each loss segment'
  o_ACbusAngle(dt,b)                                            'Audit - bus voltage angle'
  o_nonPhysicalLoss(dt,br)                                      'Audit - non physical loss'
  o_ILRO_FIR_TP(dt,o)                                           'Audit - ILRO FIR offer cleared (MWh)'
  o_ILRO_SIR_TP(dt,o)                                           'Audit - ILRO SIR offer cleared (MWh)'
  o_ILbus_FIR_TP(dt,b)                                          'Audit - ILRO FIR cleared at bus (MWh)'
  o_ILbus_SIR_TP(dt,b)                                          'Audit - ILRO SIR cleared at bus (MWh)'
  o_PLRO_FIR_TP(dt,o)                                           'Audit - PLRO FIR offer cleared (MWh)'
  o_PLRO_SIR_TP(dt,o)                                           'Audit - PLRO SIR offer cleared (MWh)'
  o_TWRO_FIR_TP(dt,o)                                           'Audit - TWRO FIR offer cleared (MWh)'
  o_TWRO_SIR_TP(dt,o)                                           'Audit - TWRO SIR offer cleared (MWh)'
  o_generationRiskLevel(dt,ild,o,resC,riskC)                    'Audit - generation risk'
  o_generationRiskPrice(dt,ild,o,resC,riskC)                    'Audit - generation risk shadow price'
  o_HVDCriskLevel(dt,ild,resC,riskC)                            'Audit - DCCE and DCECE risk'
  o_HVDCriskPrice(dt,ild,resC,riskC)                            'Audit - DCCE and DCECE risk shadow price'
  o_manuRiskLevel(dt,ild,resC,riskC)                            'Audit - manual risk'
  o_manuRiskPrice(dt,ild,resC,riskC)                            'Audit - manual risk shadow price'
  o_genHVDCriskLevel(dt,ild,o,resC,riskC)                       'Audit - generation + HVDC secondary risk'
  o_genHVDCriskPrice(dt,ild,o,resC,riskC)                       'Audit - generation + HVDC secondary risk shadow price'
  o_manuHVDCriskLevel(dt,ild,resC,riskC)                        'Audit - manual + HVDC secondary'
  o_manuHVDCriskPrice(dt,ild,resC,riskC)                        'Audit - manual + HVDC secondary shadow price'
  o_generationRiskGroupLevel(dt,ild,rg,resC,riskC)                 'Audit - generation group risk'
  o_generationRiskGroupPrice(dt,ild,rg,resC,riskC)                 'Audit - generation group risk shadow price'
* TN - output parameters added for NMIR project --------------------------------
  o_FirSent_TP(dt,ild)                        'FIR export from an island for each trade period'
  o_SirSent_TP(dt,ild)                        'SIR export from an island for each trade period'
  o_FirReceived_TP(dt,ild)                    'FIR received at an island for each trade period'
  o_SirReceived_TP(dt,ild)                    'SIR received at an island for each trade period'
  o_FirEffReport_TP(dt,ild)                   'Effective FIR share for reporting to an island for each trade period'
  o_SirEffReport_TP(dt,ild)                   'Effective FIR share for reporting to an island for each trade period'
  o_EffectiveRes_TP(dt,ild,resC,riskC)        'Effective reserve share to an island for each trade period'
  o_FirEffective_TP(dt,ild,riskC)             'Effective FIR share to an island for each trade period'
  o_SirEffective_TP(dt,ild,riskC)             'Effective FIR share to an island for each trade period'
* TN - output parameters added for NMIR project end ----------------------------
  ;

Scalars
  modelSolved                   'Flag to indicate if the model solved successfully (1 = Yes)'                                           / 0 /
  LPmodelSolved                 'Flag to indicate if the final LP model (when MIP fails) is solved successfully (1 = Yes)'              / 0 /
* Flag to use the extended set of risk classes which include the GENRISK_ECE and Manual_ECE
  useExtendedRiskClass          'Use the extended set of risk classes (1 = Yes)'                                                        / 0 /
* Scarcity pricing
  scarcityExists                'Flag to indicate that a scarcity situation exists for at least 1 trading period in the solve'
  exitLoop                      'Flag to exit solve loop'                                                                               / 0 /
  ;



*=====================================================================================
* 2. Load data from GDX file
*=====================================================================================

* If input file does not exist then go to the next input file
$if not exist "%inputPath%\%vSPDinputData%.gdx" $goto nextInput

* Load trading period to be solved
* If scarcity pricing situation exists --> load and solve all trading periods
$onmulti
$if %scarcityExists%==1 $gdxin "%inputPath%\%vSPDinputData%.gdx"
$if %scarcityExists%==0 $gdxin "vSPDPeriod.gdx"
$load i_tradePeriod i_dateTime
$gdxin


* Call the GDX routine and load the input data:
$gdxin "%inputPath%\%vSPDinputData%.gdx"
* Sets
$load i_offer i_trader i_bid i_node i_bus i_branch i_branchConstraint i_ACnodeConstraint i_MnodeConstraint
$load i_GenericConstraint i_type1MixedConstraint i_type2MixedConstraint
$load i_dateTimeTradePeriodMap i_tradePeriodOfferTrader i_tradePeriodOfferNode i_tradePeriodBidTrader i_tradePeriodBidNode  i_tradePeriodNode
$load i_tradePeriodBusIsland i_tradePeriodBus i_tradePeriodNodeBus i_tradePeriodBranchDefn i_tradePeriodRiskGenerator
$load i_type1MixedConstraintReserveMap i_tradePeriodType1MixedConstraint i_tradePeriodType2MixedConstraint i_type1MixedConstraintBranchCondition
$load i_tradePeriodGenericConstraint
* Parameters
$load i_day i_month i_year i_tradingPeriodLength i_AClineUnit i_branchReceivingEndLossProportion
$load i_studyTradePeriod i_CVPvalues i_tradePeriodOfferParameter i_tradePeriodEnergyOffer i_tradePeriodSustainedPLSRoffer i_tradePeriodFastPLSRoffer
$load i_tradePeriodSustainedTWDRoffer i_tradePeriodFastTWDRoffer i_tradePeriodSustainedILRoffer i_tradePeriodFastILRoffer i_tradePeriodNodeDemand
$load i_tradePeriodEnergyBid i_tradePeriodSustainedILRbid i_tradePeriodFastILRbid i_tradePeriodHVDCnode i_tradePeriodReferenceNode i_tradePeriodHVDCBranch
$load i_tradePeriodBranchParameter i_tradePeriodBranchCapacity i_tradePeriodBranchOpenStatus i_noLossBranch i_AClossBranch i_HVDClossBranch
$load i_tradePeriodNodeBusAllocationFactor i_tradePeriodBusElectricalIsland i_tradePeriodRiskParameter i_tradePeriodManualRisk i_tradePeriodBranchConstraintFactors
$load i_tradePeriodBranchConstraintRHS i_tradePeriodACnodeConstraintFactors i_tradePeriodACnodeConstraintRHS i_tradePeriodMnodeEnergyOfferConstraintFactors
$load i_tradePeriodMnodeReserveOfferConstraintFactors i_tradePeriodMnodeEnergyBidConstraintFactors i_tradePeriodMnodeILReserveBidConstraintFactors
$load i_tradePeriodMnodeConstraintRHS i_type1MixedConstraintVarWeight i_type1MixedConstraintGenWeight i_type1MixedConstraintResWeight
$load i_type1MixedConstraintHVDClineWeight i_tradePeriodType1MixedConstraintRHSParameters i_type2MixedConstraintLHSParameters i_tradePeriodType2MixedConstraintRHSParameters
$load i_tradePeriodGenericEnergyOfferConstraintFactors i_tradePeriodGenericReserveOfferConstraintFactors i_tradePeriodGenericEnergyBidConstraintFactors
$load i_tradePeriodGenericILReserveBidConstraintFactors i_tradePeriodGenericBranchConstraintFactors i_tradePeriodGenericConstraintRHS
$gdxin

* New risk group sets
$if %riskGroup%==1 $gdxin "%inputPath%\%vSPDinputData%.gdx"
$if %riskGroup%==0 $gdxin "vSPDPeriod.gdx"
$load i_riskGroup
$load riskGroupOffer = i_tradePeriodRiskGroup
$gdxin


*=====================================================================================
* 3. Manage model and data compatability
*=====================================================================================

* This section manages the changes to model flags to ensure backward compatibility
* given changes in the SPD model formulation over time:
* - some data loading from GDX file is conditioned on inclusion date of symbol in question
* - data symbols below are loaded at execution time whereas the main load above is at compile time.

* Gregorian date of when symbols have been included into the GDX files and therefore conditionally loaded
Scalars inputGDXGDate                     'Gregorian date of input GDX file' ;

* Calculate the Gregorian date of the input data
inputGDXGDate = jdate(i_year,i_month,i_day) ;

* Introduce i_useBusNetworkModel to account for MSP change-over date when for
* half of the day the old market node model and the other half the bus network
* model was used. The old model does not have the i_tradePeriodBusElectrical
* island paramter specified since it uses the market node network model.
* This flag is introduced to allow the i_tradePeriodBusElectricalIsland parameter
* to be used in the post-MSP solves to indentify 'dead' electrical buses.
* MSP change over from mid-day on 21 Jul 2009
i_useBusNetworkModel(tp) = 1 $ { ( inputGDXGDate >= jdate(2009,7,21) ) and
                                 sum[ b, i_tradePeriodBusElectricalIsland(tp,b) ]
                               } ;

* Switch off the mixed constraint based risk offset calculation after 17 October 2011
useMixedConstraintRiskOffset = 1 $ { inputGDXGDate < jdate(2011,10,17) } ;

* Switch off mixed constraint formulation if no data coming through
* or mixed constraint is suppressed manually in vSPDsetting.inc
useMixedConstraint(tp)
    = 1 $ { sum[t1MixCstr$i_tradePeriodType1MixedConstraint(tp,t1MixCstr), 1]
        and (suppressMixedConstraint = 0) } ;

put_utility temp 'gdxin' / '%inputPath%\%vSPDinputData%.gdx' ;

* Primary secondary offer in use from 01 May 2012'
if(inputGDXGDate >= jdate(2012,05,01),
    execute_load i_tradePeriodPrimarySecondaryOffer ;
else
    i_tradePeriodPrimarySecondaryOffer(tp,o,o1) = no ;
) ;

* Change to demand bid on 28 Jun 2012
useDSBFDemandBidModel = 1 $ { inputGDXGDate >= jdate(2012,6,28) } ;

* Manual ECE risk parameters in use from 20 Sep 2012
if(inputGDXGDate >= jdate(2012,9,20),
    execute_load i_tradePeriodManualRisk_ECE ;
else
    i_tradePeriodManualRisk_ECE(tp,ild,resC) = 0 ;
) ;

* HVDC secondary risk parameters in use from 20 Sep 2012
if(inputGDXGDate >= jdate(2012,9,20),
    execute_load i_tradePeriodHVDCsecRiskEnabled
                 i_tradePeriodHVDCsecRiskSubtractor ;
else
    i_tradePeriodHVDCsecRiskEnabled(tp,ild,riskC) = 0 ;
    i_tradePeriodHVDCsecRiskSubtractor(tp,ild) = 0 ;
) ;

* Do not use the extended risk class if no data coming through
useExtendedRiskClass
    = 1 $ { sum[ (tp,ild,resC,riskC,riskPar) $ (ord(riskC) > 4)
               , i_tradePeriodRiskParameter(tp,ild,resC,riskC,riskPar) ] };

* HVDC round power mode in use from 20 Sep 2012
if(inputGDXGDate >= jdate(2012,9,20),
    execute_load i_tradePeriodAllowHVDCroundpower ;
else
    i_tradePeriodAllowHVDCroundpower(tp) = 0 ;
) ;

* Additional mixed constraint parameters exist from 24 Feb 2013

if(inputGDXGDate >= jdate(2013,2,24),
    execute_load i_type1MixedConstraintAClineWeight
                 i_type1MixedConstraintAClineLossWeight
                 i_type1MixedConstraintAClineFixedLossWeight
                 i_type1MixedConstraintHVDClineLossWeight
                 i_type1MixedConstraintHVDClineFixedLossWeight
                 i_type1MixedConstraintPurWeight ;
else
    i_type1MixedConstraintAClineWeight(t1MixCstr,br) = 0 ;
    i_type1MixedConstraintAClineLossWeight(t1MixCstr,br) = 0 ;
    i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br) = 0 ;
    i_type1MixedConstraintHVDClineLossWeight(t1MixCstr,br) = 0 ;
    i_type1MixedConstraintHVDClineFixedLossWeight(t1MixCstr,br) = 0 ;
    i_type1MixedConstraintPurWeight(t1MixCstr,bd) = 0 ;
) ;

*  Reserve class generation parameter in use from 24 Feb 2013
if(inputGDXGDate >= jdate(2013,2,24),
    execute_load i_tradePeriodReserveClassGenerationMaximum ;
else
    i_tradePeriodReserveClassGenerationMaximum(tp,o,resC) = 0 ;
) ;

* Primary secondary risk model in use from 24 Feb 2013
usePrimSecGenRiskModel = 1 $ { inputGDXGDate >= jdate(2013,2,24) } ;

* Dispatchable Demand effective date 20 May 2014
if(inputGDXGDate >= jdate(2014,5,20),
    execute_load i_tradePeriodDispatchableBid;
else
    i_tradePeriodDispatchableBid(tp,bd) =  Yes $ useDSBFDemandBidModel ;
) ;
* MODD modification end

* Scarcity pricing scheme for reserve available from 27 May 2014
if(inputGDXGDate >= jdate(2014,5,27),
    execute_load i_tradePeriodVROfferMax, i_tradePeriodVROfferPrice ;
else
    i_tradePeriodVROfferMax(tp,ild,resC) = 0 ;
    i_tradePeriodVROfferPrice(tp,ild,resC) = 0 ;
) ;


* National market for IR effective date 20 Oct 2016
if (inputGDXGDate >= jdate(2016,10,20),
    execute_load
    reserveRoundPower     = i_tradePeriodReserveRoundPower
    reserveShareEnabled   = i_tradePeriodReserveSharing
    modulationRiskClass   = i_tradePeriodModulationRisk
    roundPower2MonoLevel  = i_tradePeriodRoundPower2Mono
    bipole2MonoLevel      = i_tradePeriodBipole2Mono
    monopoleMinimum       = i_tradePeriodReserveSharingPoleMin
    HVDCControlBand       = i_tradePeriodHVDCcontrolBand
    HVDClossScalingFactor = i_tradePeriodHVDClossScalingFactor
    sharedNFRfactor       = i_tradePeriodSharedNFRfactor
    sharedNFRLoadOffset   = i_tradePeriodSharedNFRLoadOffset
    effectiveFactor       = i_tradePeriodReserveEffectiveFactor
    RMTreserveLimitTo     = i_tradePeriodRMTreserveLimit
    rampingConstraint     = i_tradePeriodRampingConstraint
  ;
else
    reserveRoundPower(tp,resC)         = 0    ;
    reserveShareEnabled(tp,resC)       = 0    ;
    modulationRiskClass(tp,riskC)      = 0    ;
    roundPower2MonoLevel(tp)           = 0    ;
    bipole2MonoLevel(tp)               = 0    ;
    MonopoleMinimum(tp)                = 0    ;
    HVDCControlBand(tp,fd)             = 0    ;
    HVDClossScalingFactor(tp)          = 0    ;
    sharedNFRfactor(tp)                = 0    ;
    sharedNFRloadOffset(tp,ild)        = 0    ;
    effectiveFactor(tp,ild,resC,riskC) = 0    ;
    RMTreserveLimitTo(tp,ild,resC)     = 0    ;
    rampingConstraint(tp,brCstr)       = no   ;
) ;

UseShareReserve = 1 $ sum[ (tp,resC), reserveShareEnabled(tp,resC)] ;

* Branch Reverse Ratings planned to go-live on 03/Feb/2021 (this will be flagged in GDX using i_tradePeriodReverseRatingsApplied)
* From 11 Dec 2020, GDX file will have i_tradePeriodBranchCapacityDirected and i_tradePeriodReverseRatingsApplied symbols
if (inputGDXGDate >= jdate(2020,12,11),
    execute_load i_tradePeriodBranchCapacityDirected;
    execute_load reverseRatingsApplied = i_tradePeriodReverseRatingsApplied;
    
    i_tradePeriodBranchCapacityDirected(tp,br,'backward') $ (reverseRatingsApplied(tp)=0)
        = i_tradePeriodBranchCapacityDirected(tp,br,'forward');
            
else
    i_tradePeriodBranchCapacityDirected(tp,br,fd)
        = i_tradePeriodBranchCapacity(tp,br) ;
) ;



*=====================================================================================
* 4. Input data overrides - declare and apply (include vSPDoverrides.gms)
*=====================================================================================

$ontext
 - At this point, vSPDoverrides.gms is included into vSPDsolve.gms if an override
   file defined by the $setglobal vSPDinputOvrdData in vSPDSetting.inc exists.
 - All override data symbols have the characters 'Ovrd' appended to the original
   symbol name. After declaring the override symbols, the override data is
   installed and the original symbols are overwritten.
 - Note that the Excel interface permits a limited number of input data symbols
   to be overridden. The EMI interface will create a GDX file of override values
   for all data inputs to be overridden. If operating in standalone mode,
   overrides can be installed by any means the user prefers - GDX file, $include
   file, hard-coding, etc. But it probably makes sense to mimic the GDX file as
   used by EMI.
$offtext

$if exist "%ovrdPath%%vSPDinputOvrdData%.gdx"  $include vSPDoverrides.gms


*=====================================================================================
* 5. Initialise constraint violation penalties (CVPs)
*=====================================================================================

Scalar CVPchangeGDate 'Gregorian date of CE and ECE CVP change' ;
* Calculate the Gregorian date of the CE and ECE change
* Based on CAN from www.systemoperator.co.nz this was on 24th June 2010
CVPchangeGDate = jdate(2010,06,24) ;

* Set the flag for the application of the different CVPs for CE and ECE
* If the user selects No (0), this default value of the diffCeECeCVP flag will be used.
diffCeECeCVP = 0 ;
* If the user selects Auto (-1), set the diffCeECeCVP flag if the input date is greater than or equal to this date
diffCeECeCVP $ { (inputGDXGDate >= CVPchangeGDate) and (%VarResv% = -1) } = 1 ;
* If the user selects Yes (1), set the diffCeECeCVP flag
diffCeECeCVP $ (%VarResv% = 1) = 1 ;

deficitBusGenerationPenalty                       = sum(i_CVP$(ord(i_CVP) = 1), i_CVPvalues(i_CVP)) ;
surplusBusGenerationPenalty                       = sum(i_CVP$(ord(i_CVP) = 2), i_CVPvalues(i_CVP)) ;
deficitReservePenalty(resC) $ (ord(resC) = 1)     = sum(i_CVP$(ord(i_CVP) = 3), i_CVPvalues(i_CVP)) ;
deficitReservePenalty(resC) $ (ord(resC) = 2)     = sum(i_CVP$(ord(i_CVP) = 4), i_CVPvalues(i_CVP)) ;
deficitBrCstrPenalty                              = sum(i_CVP$(ord(i_CVP) = 5), i_CVPvalues(i_CVP)) ;
surplusBrCstrPenalty                              = sum(i_CVP$(ord(i_CVP) = 6), i_CVPvalues(i_CVP)) ;
deficitGnrcCstrPenalty                            = sum(i_CVP$(ord(i_CVP) = 7), i_CVPvalues(i_CVP)) ;
surplusGnrcCstrPenalty                            = sum(i_CVP$(ord(i_CVP) = 8), i_CVPvalues(i_CVP)) ;
deficitRampRatePenalty                            = sum(i_CVP$(ord(i_CVP) = 9), i_CVPvalues(i_CVP)) ;
surplusRampRatePenalty                            = sum(i_CVP$(ord(i_CVP) = 10), i_CVPvalues(i_CVP)) ;
deficitACnodeCstrPenalty                          = sum(i_CVP$(ord(i_CVP) = 11), i_CVPvalues(i_CVP)) ;
surplusACnodeCstrPenalty                          = sum(i_CVP$(ord(i_CVP) = 12), i_CVPvalues(i_CVP)) ;
deficitBranchFlowPenalty                          = sum(i_CVP$(ord(i_CVP) = 13), i_CVPvalues(i_CVP)) ;
surplusBranchFlowPenalty                          = sum(i_CVP$(ord(i_CVP) = 14), i_CVPvalues(i_CVP)) ;
deficitMnodeCstrPenalty                           = sum(i_CVP$(ord(i_CVP) = 15), i_CVPvalues(i_CVP)) ;
surplusMnodeCstrPenalty                           = sum(i_CVP$(ord(i_CVP) = 16), i_CVPvalues(i_CVP)) ;
deficitT1MixCstrPenalty                           = sum(i_CVP$(ord(i_CVP) = 17), i_CVPvalues(i_CVP)) ;
surplusT1MixCstrPenalty                           = sum(i_CVP$(ord(i_CVP) = 18), i_CVPvalues(i_CVP)) ;
* Different CVPs defined for CE and ECE
deficitReservePenalty_CE(resC) $ (ord(resC) = 1)  = sum(i_CVP$(ord(i_CVP) = 3), i_CVPvalues(i_CVP)) ;
deficitReservePenalty_CE(resC) $ (ord(resC) = 2)  = sum(i_CVP$(ord(i_CVP) = 4), i_CVPvalues(i_CVP)) ;
deficitReservePenalty_ECE(resC)$ (ord(resC) = 1)  = sum(i_CVP$(ord(i_CVP) = 19), i_CVPvalues(i_CVP)) ;
deficitReservePenalty_ECE(resC)$ (ord(resC) = 2)  = sum(i_CVP$(ord(i_CVP) = 20), i_CVPvalues(i_CVP)) ;

*=====================================================================================
* 6. Initialise model mapping and inputs
*=====================================================================================

* Pre-dispatch schedule is solved sequentially
sequentialSolve
    $ ( sum[ (tp,o,offerPar) $ {(ord(tp) = 2) and (ord(offerPar) = 1)}
                             , i_tradePeriodOfferParameter(tp,o,offerPar) ] = 0
      ) = 1 ;

sequentialSolve $ UseShareReserve = 1;

* Initialise bus, node, offer, bid for the current trade period start
bus(tp,b)  $ i_tradePeriodBus(tp,b)  = yes  ;
node(tp,n) $ i_tradePeriodNode(tp,n) = yes  ;

* Initialise network sets for the current trade period start
nodeBus(node,b)     $ i_tradePeriodNodeBus(node,b)        = yes ;
HVDCnode(node)      $ i_tradePeriodHVDCnode(node)         = yes ;
ACnode(node)        $ ( not HVDCnode(node))               = yes ;
referenceNode(node) $ i_tradePeriodReferenceNode(node)    = yes ;
DCbus(tp,b)         $ sum[ nodeBus(HVDCnode(tp,n),b), 1 ] = yes ;
ACbus(tp,b)         $ ( not DCbus(tp,b) )                 = yes ;

* Bus live island status
busElectricalIsland(bus) = i_tradePeriodBusElectricalIsland(bus) ;

* Offer initialisation - offer must be mapped to a node that is mapped to a
* bus that is not in electrical island = 0 if i_useBusNetworkModel flag is 1
offer(tp,o) $ sum[ (n,b) $ { i_tradePeriodOfferNode(tp,o,n) and
                             nodeBus(tp,n,b) and
                             ( (not i_useBusNetworkModel(tp)) or
                               busElectricalIsland(tp,b))
                           }, 1 ] = yes ;

* IL offer mapped to a node that is mapped to a bus always valid
* (updated on 23 July 2015 based on an email from SO Bennet Tucker on 21 July 2015))
offer(tp,o)
    $ sum[ (n,b)
         $ { i_tradePeriodOfferNode(tp,o,n) and nodeBus(tp,n,b)
         and sum[ (trdBlk,ILofrCmpnt)
                , i_tradePeriodFastILRoffer(tp,o,trdBlk,ILofrCmpnt)
                + i_tradePeriodSustainedILRoffer(tp,o,trdBlk,ILofrCmpnt) ]
           }, 1 ] = yes ;

* Bid initialisation - bid must be mapped to a node that is mapped to a bus
* bus that is not in electrical island = 0 if i_useBusNetworkModel flag is 1
bid(tp,bd) $ sum[ (n,b) $ { i_tradePeriodBidNode(tp,bd,n) and
                            nodeBus(tp,n,b) and
                            ( (not i_useBusNetworkModel(tp)) or
                              busElectricalIsland(tp,b) )
                          }, 1 ] = yes ;

* Initialise Risk/Reserve data for the current trading period
RiskGenerator(offer) $ i_tradePeriodRiskGenerator(offer) = yes ;

* Mapping bus, node, offer, bid and island start for the current trade period
offerNode(offer,n)   $ i_tradePeriodOfferNode(offer,n)                 = yes ;
bidNode(bid,n)       $ i_tradePeriodBidNode(bid,n)                     = yes ;
busIsland(bus,ild)   $ i_tradePeriodBusIsland(bus,ild)                 = yes ;
nodeIsland(tp,n,ild) $ sum[ b $ { bus(tp,b) and node(tp,n)
                              and nodeBus(tp,n,b)
                              and busIsland(tp,b,ild) }, 1 ]           = yes ;
offerIsland(offer(tp,o),ild)
    $ sum[ n $ { offerNode(tp,o,n) and nodeIsland(tp,n,ild) }, 1 ] = yes ;
bidIsland(bid(tp,bd),ild)
    $ sum[ n $ { bidNode(tp,bd,n) and nodeIsland(tp,n,ild) }, 1 ] = yes ;

IslandRiskGenerator(tp,ild,o)
    $ { offerIsland(tp,o,ild) and RiskGenerator(tp,o) } = yes ;

* Set the primary-secondary offer combinations
primarySecondaryOffer(offer,o1) = i_tradePeriodPrimarySecondaryOffer(offer,o1) ;

* Identification of primary and secondary units
hasSecondaryOffer(tp,o) = 1 $ sum[ o1 $ primarySecondaryOffer(tp,o,o1), 1 ] ;
hasPrimaryOffer(tp,o)   = 1 $ sum[ o1 $ primarySecondaryOffer(tp,o1,o), 1 ];

* Initialise offer parameters for the current trade period start
generationStart(offer(tp,o))
    = sum[ offerPar $ ( ord(offerPar) = 1 )
                    , i_tradePeriodOfferParameter(tp,o,offerPar)
                    + sum[ o1 $ primarySecondaryOffer(tp,o,o1)
                              ,i_tradePeriodOfferParameter(tp,o1,offerPar) ]
         ];

rampRateUp(offer)
    = sum[ offerPar $ ( ord(offerPar) = 2 )
                    , i_tradePeriodOfferParameter(offer,offerPar) ] ;
rampRateDown(offer)
    = sum[ offerPar $ ( ord(offerPar) = 3 )
                    , i_tradePeriodOfferParameter(offer,offerPar) ] ;
reserveGenerationMaximum(offer)
    = sum[ offerPar $ ( ord(offerPar) = 4 )
                    , i_tradePeriodOfferParameter(offer,offerPar) ] ;
windOffer(offer)
    = sum[ offerPar $ ( ord(offerPar) = 5 )
                    , i_tradePeriodOfferParameter(offer,offerPar) ] ;
FKband(offer)
    = sum[ offerPar $ ( ord(offerPar) = 6 )
                    , i_tradePeriodOfferParameter(offer,offerPar) ] ;

priceResponsive(offer)
    = sum[ offerPar $ ( ord(offerPar) = 7 )
                    , i_tradePeriodOfferParameter(offer,offerPar) ] ;

potentialMW(offer)
    = sum[ offerPar $ ( ord(offerPar) = 8 )
                    , i_tradePeriodOfferParameter(offer,offerPar) ] ;


* Initialise energy offer data for the current trade period start
generationOfferMW(offer,trdBlk)
    = sum[ NRGofrCmpnt $ ( ord(NRGofrCmpnt) = 1 )
                       , i_tradePeriodEnergyOffer(offer,trdBlk,NRGofrCmpnt) ] ;
generationOfferPrice(offer,trdBlk)
    = sum[ NRGofrCmpnt $ ( ord(NRGofrCmpnt) = 2 )
                       , i_tradePeriodEnergyOffer(offer,trdBlk,NRGofrCmpnt) ] ;

* Valid generation offer blocks are defined as those with a positive block limit
validGenerationOfferBlock(offer,trdBlk)
    $ ( generationOfferMW(offer,trdBlk) > 0 ) = yes ;

* Define set of positive energy offers
positiveEnergyOffer(offer)
    $ sum[ trdBlk $ validGenerationOfferBlock(offer,trdBlk), 1 ] = yes ;

* Initialise reserve offer data for the current trade period start
PLSRReserveType(resT) $ (ord(resT) = 1) = yes ;
TWDRReserveType(resT) $ (ord(resT) = 2) = yes ;
ILReserveType(resT)   $ (ord(resT) = 3) = yes ;

reserveOfferProportion(offer,trdBlk,resC)
    $ ( ord(resC) = 1 )
    = sum[ PLSofrCmpnt $ ( ord(PLSofrCmpnt) = 1 )
         , i_tradePeriodFastPLSRoffer(offer,trdBlk,PLSofrCmpnt) / 100 ] ;

reserveOfferProportion(offer,trdBlk,resC)
    $ ( ord(resC) = 2 )
    = sum[ PLSofrCmpnt $ ( ord(PLSofrCmpnt) = 1 )
         , i_tradePeriodSustainedPLSRoffer(offer,trdBlk,PLSofrCmpnt) / 100 ] ;

reserveOfferMaximum(offer(tp,o),trdBlk,resC,PLSRReserveType)
    = sum[ PLSofrCmpnt $ ( ord(PLSofrCmpnt) = 2 )
    , i_tradePeriodFastPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)     $(ord(resC)=1)
    + i_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)$(ord(resC)=2) ];

reserveOfferMaximum(offer(tp,o),trdBlk,resC,TWDRReserveType)
    = sum[ TWDofrCmpnt $ ( ord(TWDofrCmpnt) = 1 )
    , i_tradePeriodFastTWDRoffer(offer,trdBlk,TWDofrCmpnt)     $(ord(resC)=1)
    + i_tradePeriodSustainedTWDRoffer(offer,trdBlk,TWDofrCmpnt)$(ord(resC)=2) ];

reserveOfferMaximum(offer,trdBlk,resC,ILReserveType)
    = sum[ ILofrCmpnt $ ( ord(ILofrCmpnt) = 1 )
    , i_tradePeriodFastILRoffer(offer,trdBlk,ILofrCmpnt)     $(ord(resC)=1)
    + i_tradePeriodSustainedILRoffer(offer,trdBlk,ILofrCmpnt)$(ord(resC)=2) ];

reserveOfferPrice(offer,trdBlk,resC,PLSRReserveType)
    = sum[ PLSofrCmpnt $ ( ord(PLSofrCmpnt) = 3 )
    , i_tradePeriodFastPLSRoffer(offer,trdBlk,PLSofrCmpnt)     $(ord(resC)=1)
    + i_tradePeriodSustainedPLSRoffer(offer,trdBlk,PLSofrCmpnt)$(ord(resC)=2) ];


reserveOfferPrice(offer,trdBlk,resC,TWDRReserveType)
    = sum[ TWDofrCmpnt $ ( ord(TWDofrCmpnt) = 2 )
    , i_tradePeriodFastTWDRoffer(offer,trdBlk,TWDofrCmpnt)     $(ord(resC)=1)
    + i_tradePeriodSustainedTWDRoffer(offer,trdBlk,TWDofrCmpnt)$(ord(resC)=2) ];

reserveOfferPrice(offer,trdBlk,resC,ILReserveType)
    = sum[ ILofrCmpnt $ ( ord(ILofrCmpnt) = 2 )
    , i_tradePeriodFastILRoffer(offer,trdBlk,ILofrCmpnt)     $(ord(resC)=1)
    + i_tradePeriodSustainedILRoffer(offer,trdBlk,ILofrCmpnt)$(ord(resC)=2) ] ;

* Only reserve offer block with a positive block limit is valid
validReserveOfferBlock(offer,trdBlk,resC,resT)
    $ (reserveOfferMaximum(offer,trdBlk,resC,resT) > 0) = yes ;

* Bid energy data
purchaseBidMW(bid,trdBlk) $ i_tradePeriodDispatchableBid(bid)
    = sum[ NRGbidCmpnt $ ( ord(NRGbidCmpnt) = 1 )
         , i_tradePeriodEnergyBid(bid,trdBlk,NRGbidCmpnt) ] ;

purchaseBidPrice(bid,trdBlk) $ i_tradePeriodDispatchableBid(bid)
    = sum[ NRGbidCmpnt $ ( ord(NRGbidCmpnt) = 2 )
         , i_tradePeriodEnergyBid(bid,trdBlk,NRGbidCmpnt) ] ;

validPurchaseBidBlock(bid,trdBlk)
    $ { ( purchaseBidMW(bid,trdBlk) > 0 ) or
        ( useDSBFDemandBidModel * purchaseBidMW(bid,trdBlk) <> 0) } = yes ;

* Bid IL data
purchaseBidILRMW(bid,trdBlk,resC) $ i_tradePeriodDispatchableBid(bid)
    = sum[ ILbidCmpnt $ ( ord(ILbidCmpnt ) = 1)
         , i_tradePeriodFastILRbid(bid,trdBlk,ILbidCmpnt)     $(ord(resC)=1)
         + i_tradePeriodSustainedILRbid(bid,trdBlk,ILbidCmpnt)$(ord(resC)=2) ] ;

purchaseBidILRPrice(bid,trdBlk,resC) $ i_tradePeriodDispatchableBid(bid)
    = sum[ ILbidCmpnt $ ( ord(ILbidCmpnt) = 2 )
         , i_tradePeriodFastILRbid(bid,trdBlk,ILbidCmpnt)     $(ord(resC)=1)
         + i_tradePeriodSustainedILRbid(bid,trdBlk,ILbidCmpnt)$(ord(resC)=2) ] ;

validPurchaseBidILRBlock(bid,trdBlk,resC)
    $ ( purchaseBidILRMW(bid,trdBlk,resC) > 0 ) = yes ;


* Initialise demand/bid data for the current trade period start
nodeDemand(node) = i_tradePeriodNodeDemand(node) ;

* If a bid is valid --> ignore the demand at the node connected to the bid
* (PA suggested during v1.4 Audit)
nodeDemand(node(tp,n))
    $ { useDSBFDemandBidModel and
        Sum[ bd $ { bidNode(tp,bd,n) and i_tradePeriodDispatchableBid(tp,bd) }
           , 1 ]
      } = 0;

* Branch is defined if there is a defined terminal bus, it has a non-zero
* capacity and is closed for that trade period
* Update the pre-processing code that removes branches which have a limit of zero
* so that it removes a branch if either direction has a limit of zero.
branch(tp,br) $ { (not i_tradePeriodBranchOpenStatus(tp,br)) and
                  sum[ fd $ (ord(fd)=1), i_tradePeriodBranchCapacityDirected(tp,br,fd)] and
                  sum[ fd $ (ord(fd)=2), i_tradePeriodBranchCapacityDirected(tp,br,fd)] and
                  sum[ (b,b1) $ { bus(tp,b) and bus(tp,b1) and
                                  i_tradePeriodBranchDefn(tp,br,b,b1) }, 1 ]
                } = yes ;



branchBusDefn(branch,b,b1) $ i_tradePeriodBranchDefn(branch,b,b1)    = yes ;
branchBusConnect(branch,b) $ sum[b1 $ branchBusDefn(branch,b,b1), 1] = yes ;
branchBusConnect(branch,b) $ sum[b1 $ branchBusDefn(branch,b1,b), 1] = yes ;

* HVDC link and AC branch definition
HVDClink(branch)      $ i_tradePeriodHVDCBranch(branch)         = yes ;
HVDCpoles(branch)     $ ( i_tradePeriodHVDCBranch(branch) = 1 ) = yes ;
HVDChalfPoles(branch) $ ( i_tradePeriodHVDCBranch(branch) = 2 ) = yes ;
ACbranch(branch)      $ ( not HVDClink(branch) )                = yes ;

* Determine sending and receiving bus sets
loop((frB,toB),
    ACbranchSendingBus(ACbranch,frB,fd)
        $ { branchBusDefn(ACbranch,frB,toB) and (ord(fd) = 1) } = yes ;

    ACbranchReceivingBus(ACbranch,toB,fd)
        $ { branchBusDefn(ACbranch,frB,toB) and (ord(fd) = 1) } = yes ;

    ACbranchSendingBus(ACbranch,toB,fd)
        $ { branchBusDefn(ACbranch,frB,toB) and (ord(fd) = 2) } = yes ;

    ACbranchReceivingBus(ACbranch,frB,fd)
        $ { branchBusDefn(ACbranch,frB,toB) and (ord(fd) = 2) } = yes ;
);

HVDClinkSendingBus(HVDClink,frB)
    $ sum[ branchBusDefn(HVDClink,frB,toB), 1 ] = yes ;

HVDClinkReceivingBus(HVDClink,toB)
    $ sum[ branchBusDefn(HVDClink,frB,toB), 1 ] = yes ;

HVDClinkBus(HVDClink,b) $ HVDClinkSendingBus(HVDClink,b)   = yes ;
HVDClinkBus(HVDClink,b) $ HVDClinkReceivingBus(HVDClink,b) = yes ;

* Determine the HVDC inter-island pole in the northward and southward direction

HVDCpoleDirection(tp,br,fd) $ { (ord(fd) = 1) and HVDClink(tp,br) }
    = yes $ sum[ (ild,NodeBus(tp,n,b)) $ { (ord(ild) = 2)
                                       and nodeIsland(tp,n,ild)
                                       and HVDClinkSendingBus(tp,br,b) }, 1 ] ;

HVDCpoleDirection(tp,br,fd) $ { (ord(fd) = 2) and HVDClink(tp,br) }
    = yes $ sum[ (ild,NodeBus(tp,n,b)) $ { (ord(ild) = 1)
                                       and nodeIsland(tp,n,ild)
                                       and HVDClinkSendingBus(tp,br,b) }, 1 ] ;

* Mapping HVDC branch to pole to account for name changes to Pole 3
HVDCpoleBranchMap('Pole1',br) $ sum[ sameas(br,'BEN_HAY1.1'), 1] = yes ;
HVDCpoleBranchMap('Pole1',br) $ sum[ sameas(br,'HAY_BEN1.1'), 1] = yes ;
HVDCpoleBranchMap('Pole1',br) $ sum[ sameas(br,'BEN_HAY3.1'), 1] = yes ;
HVDCpoleBranchMap('Pole1',br) $ sum[ sameas(br,'HAY_BEN3.1'), 1] = yes ;
HVDCpoleBranchMap('Pole2',br) $ sum[ sameas(br,'BEN_HAY2.1'), 1] = yes ;
HVDCpoleBranchMap('Pole2',br) $ sum[ sameas(br,'HAY_BEN2.1'), 1] = yes ;

* Initialise network data for the current trade period start
* Node-bus allocation factor
nodeBusAllocationFactor(tp,n,b) $ { node(tp,n) and bus(tp,b) }
    = i_tradePeriodNodeBusAllocationFactor(tp,n,b) ;

* Flag to allow roundpower on the HVDC link
allowHVDCroundpower(tp) = i_tradePeriodAllowHVDCroundpower(tp) ;

* Allocate the input branch parameters to the defined branchCapacity
branchCapacity(branch,fd)
    = i_tradePeriodBranchCapacityDirected(branch,fd) ;
* HVDC Links do not have reverse capacity
branchCapacity(HVDClink,fd) $ ( ord(fd) = 2 ) = 0 ;

* Allocate the input branch parameters to the defined branchResistance
branchResistance(branch)
    = sum[ i_branchParameter $ (ord(i_branchParameter) = 1)
         , i_tradePeriodBranchParameter(branch,i_branchParameter) ] ;

* Convert susceptance from -Bpu to B% for data post-MSP
branchSusceptance(ACbranch(tp,br))
    = sum[ i_branchParameter $ (ord(i_branchParameter) = 2)
         , i_tradePeriodBranchParameter(ACbranch,i_branchParameter) ]
    * [ 100$(not i_useBusNetworkModel(tp)) - 100$i_useBusNetworkModel(tp) ];

branchLossBlocks(branch)
    = sum[ i_branchParameter $ (ord(i_branchParameter) = 4)
         , i_tradePeriodBranchParameter(branch,i_branchParameter) ] ;

* Ensure fixed losses for no loss AC branches are not included
branchFixedLoss(ACbranch)
    = sum[ i_branchParameter $ (ord(i_branchParameter) = 3)
         , i_tradePeriodBranchParameter(ACbranch,i_branchParameter)
         ] $ (branchLossBlocks(ACbranch) > 1) ;

branchFixedLoss(HVDClink)
    = sum[ i_branchParameter $ (ord(i_branchParameter) = 3)
         , i_tradePeriodBranchParameter(HVDClink,i_branchParameter) ] ;

* Set resistance and fixed loss to zero if do not want to use the loss model
branchResistance(ACbranch) $ (not useAClossModel) = 0 ;
branchFixedLoss(ACbranch)  $ (not useAClossModel) = 0 ;

branchResistance(HVDClink) $ (not useHVDClossModel) = 0 ;
branchFixedLoss(HVDClink)  $ (not useHVDClossModel) = 0 ;

* Initialise loss tranches data for the current trade period start
* The loss factor coefficients assume that the branch capacity is in MW
* and the resistance is in p.u.

* Loss branches with 0 loss blocks
lossSegmentMW(branch,los,fd)
    $ { (branchLossBlocks(branch) = 0) and (ord(los) = 1) }
    = branchCapacity(branch,fd) ;

LossSegmentFactor(branch,los,fd)
    $ { (branchLossBlocks(branch) = 0) and (ord(los) = 1) }
    = 0 ;

* Loss branches with 1 loss blocks
LossSegmentMW(branch,los,fd)
    $ { (branchLossBlocks(branch) = 1) and (ord(los) = 1) }
    = maxFlowSegment ;

LossSegmentFactor(branch,los,fd)
    $ { (branchLossBlocks(branch) = 1) and (ord(los) = 1) }
    = 0.01 * branchResistance(branch) * branchCapacity(branch,fd) ;

* Loss branches with 3 loss blocks
loop( branch $ (branchLossBlocks(branch) = 3),
*   Segment 1
    LossSegmentMW(branch,los,fd) $ (ord(los) = 1)
        = lossCoeff_A * branchCapacity(branch,fd) ;

    LossSegmentFactor(branch,los,fd) $ (ord(los) = 1)
        = 0.01 * 0.75 * lossCoeff_A
        * branchResistance(branch) * branchCapacity(branch,fd) ;

*   Segment 2
    LossSegmentMW(branch,los,fd) $ (ord(los) = 2)
        = (1-lossCoeff_A) * branchCapacity(branch,fd) ;

    LossSegmentFactor(branch,los,fd) $ (ord(los) = 2)
        = 0.01 * branchResistance(branch) * branchCapacity(branch,fd) ;

*   Segment 3
    LossSegmentMW(branch,los,fd) $ (ord(los) = 3)
        = maxFlowSegment ;

    LossSegmentFactor(branch,los,fd) $ (ord(los) = 3)
        = 0.01 * (2 - (0.75*lossCoeff_A))
        * branchResistance(branch) * branchCapacity(branch,fd) ;
);

* Loss branches with 6 loss blocks
loop( branch $ (branchLossBlocks(branch) = 6),
*   Segment 1
    LossSegmentMW(branch,los,fd) $ (ord(los) = 1)
        = lossCoeff_C  * branchCapacity(branch,fd) ;

    LossSegmentFactor(branch,los,fd) $ (ord(los) = 1)
        = 0.01 * 0.75 * lossCoeff_C
        * branchResistance(branch) * branchCapacity(branch,fd) ;

*   Segment 2
    LossSegmentMW(branch,los,fd) $ (ord(los) = 2)
        = lossCoeff_D * branchCapacity(branch,fd) ;

    LossSegmentFactor(branch,los,fd) $ (ord(los) = 2)
        = 0.01 * lossCoeff_E
        * branchResistance(branch) * branchCapacity(branch,fd) ;

*   Segment 3
    LossSegmentMW(branch,los,fd) $ (ord(los) = 3)
        = 0.5 * branchCapacity(branch,fd) ;

    LossSegmentFactor(branch,los,fd) $ (ord(los) = 3)
        = 0.01 * lossCoeff_F
        * branchResistance(branch) * branchCapacity(branch,fd) ;

*   Segment 4
    LossSegmentMW(branch,los,fd) $ (ord(los) = 4)
        = (1 - lossCoeff_D) * branchCapacity(branch,fd) ;

    LossSegmentFactor(branch,los,fd) $ (ord(los) = 4)
        = 0.01 * (2 - lossCoeff_F)
        * branchResistance(branch) * branchCapacity(branch,fd) ;

*   Segment 5
    LossSegmentMW(branch,los,fd) $ (ord(los) = 5)
        = (1 - lossCoeff_C) * branchCapacity(branch,fd) ;

    LossSegmentFactor(branch,los,fd) $ (ord(los) = 5)
        = 0.01 * (2 - lossCoeff_E)
        * branchResistance(branch) * branchCapacity(branch,fd) ;

*   Segment 6
    LossSegmentMW(branch,los,fd) $ (ord(los) = 6)
        = maxFlowSegment ;

    LossSegmentFactor(branch,los,fd) $ (ord(los) = 6)
        = 0.01 * (2 - (0.75*lossCoeff_C))
        * branchResistance(branch) * branchCapacity(branch,fd) ;
) ;

* HVDC does not have backward flow --> No loss segment for backward flow
LossSegmentMW(HVDClink,los,fd) $ (ord(fd) = 2) = 0;
LossSegmentFactor(HVDClink,los,fd) $ (ord(fd) = 2) = 0;


* Valid loss segment for a branch is defined as a loss segment that
* has a non-zero LossSegmentMW or a non-zero LossSegmentFactor.
validLossSegment(branch,los,fd) = yes $ { (ord(los) = 1) or
                                          LossSegmentMW(branch,los,fd) or
                                          LossSegmentFactor(branch,los,fd) } ;

* HVDC loss model requires at least two loss segments and
* an additional loss block due to cumulative loss formulation
validLossSegment(HVDClink,los,fd)
    $ { (branchLossBlocks(HVDClink) <= 1) and (ord(los) = 2) } = yes ;

validLossSegment(HVDClink,los,fd)
    $ { (branchLossBlocks(HVDClink) > 1) and
        (ord(los) = (branchLossBlocks(HVDClink) + 1)) and
        (sum[ los1, LossSegmentMW(HVDClink,los1,fd)
                  + LossSegmentFactor(HVDClink,los1,fd) ] > 0)
      } = yes ;

* branches that have non-zero loss factors
LossBranch(branch) $ sum[ (los,fd), LossSegmentFactor(branch,los,fd) ] = yes ;

* Create AC branch loss segments
ACbranchLossMW(ACbranch,los,fd)
    $ { validLossSegment(ACbranch,los,fd) and (ord(los) = 1) }
    = LossSegmentMW(ACbranch,los,fd) ;

ACbranchLossMW(ACbranch,los,fd)
    $ { validLossSegment(ACbranch,los,fd) and (ord(los) > 1) }
    = LossSegmentMW(ACbranch,los,fd) - LossSegmentMW(ACbranch,los-1,fd) ;

ACbranchLossFactor(ACbranch,los,fd)
    $ validLossSegment(ACbranch,los,fd) = LossSegmentFactor(ACbranch,los,fd) ;

* Create HVDC loss break points
HVDCBreakPointMWFlow(HVDClink,bp,fd) $ (ord(bp) = 1) = 0 ;
HVDCBreakPointMWLoss(HVDClink,bp,fd) $ (ord(bp) = 1) = 0 ;

HVDCBreakPointMWFlow(HVDClink,bp,fd)
    $ { validLossSegment(HVDClink,bp,fd) and (ord(bp) > 1) }
    = LossSegmentMW(HVDClink,bp-1,fd) ;

HVDCBreakPointMWLoss(HVDClink,bp,fd)
    $ { validLossSegment(HVDClink,bp,fd) and (ord(bp) = 2) }
    =  LossSegmentMW(HVDClink,bp-1,fd) * LossSegmentFactor(HVDClink,bp-1,fd) ;

loop( (HVDClink(branch),bp) $ (ord(bp) > 2),
    HVDCBreakPointMWLoss(branch,bp,fd) $ validLossSegment(branch,bp,fd)
        = LossSegmentFactor(branch,bp-1,fd)
        * [ LossSegmentMW(branch,bp-1,fd) - LossSegmentMW(branch,bp-2,fd) ]
        + HVDCBreakPointMWLoss(branch,bp-1,fd) ;
) ;

* Initialise branch constraint data for the current trading period
branchConstraint(tp,brCstr)
    $ sum[ branch(tp,br)
         $ i_tradePeriodBranchConstraintFactors(tp,brCstr,br), 1 ] = yes ;

branchConstraintFactors(branchConstraint,br)
    = i_tradePeriodBranchConstraintFactors(branchConstraint,br) ;

branchConstraintSense(branchConstraint)
    = sum[ CstrRHS $ (ord(CstrRHS) = 1),
         i_tradePeriodBranchConstraintRHS(branchConstraint,CstrRHS) ] ;

branchConstraintLimit(branchConstraint)
    = sum[ CstrRHS $ (ord(CstrRHS) = 2),
         i_tradePeriodBranchConstraintRHS(branchConstraint,CstrRHS) ] ;

* Calculate parameters for NMIR project ----------------------------------------
islandRiskGroup(tp,ild,rg,riskC)
    = yes $ sum[ o $ { offerIsland(tp,o,ild)
                   and riskGroupOffer(tp,rg,o,riskC) }, 1 ] ;

modulationRisk(tp) = smax[ riskC, modulationRiskClass(tp,RiskC) ];

reserveShareEnabledOverall(tp) = smax[ resC, reserveShareEnabled(tp,resC) ];

roPwrZoneExit(tp,resC)
    = [ roundPower2MonoLevel(tp) - modulationRisk(tp) ]$(ord(resC)=1)
    + bipole2MonoLevel(tp)$(ord(resC)=2) ;

* National market refinement - effective date 28 Mar 2019 12:00
$ontext
   SPD pre-processing is changed so that the roundpower settings for FIR are now the same as for SIR. Specifically:
   -  The RoundPowerZoneExit for FIR will be set at BipoleToMonopoleTransition by SPD pre-processing (same as for SIR),
      a change from the existing where the RoundPowerZoneExit for FIR is set at RoundPowerToMonopoleTransition by SPD pre-processing.
   -  Provided that roundpower is not disabled by the MDB, the InNoReverseZone for FIR will be removed by SPD pre-processing (same as for SIR),
      a change from the existing where the InNoReverseZone for FIR is never removed by SPD pre-processing.
$offtext

if (inputGDXGDate >= jdate(2019,03,28),
    roPwrZoneExit(tp,resC) = bipole2MonoLevel(tp) ;
) ;

* National market refinement end


* Pre-processing: Shared Net Free Reserve (NFR) calculation - NMIR (5.2.1.2)
sharedNFRLoad(tp,ild)
    = sum[ nodeIsland(tp,n,ild), nodeDemand(tp,n)]
    + sum[ (bd,trdBlk) $ bidIsland(tp,bd,ild), purchaseBidMW(tp,bd,trdBlk) ]
    - sharedNFRLoadOffset(tp,ild) ;

sharedNFRMax(tp,ild) = Min{ RMTReserveLimitTo(tp,ild,'FIR'),
                            sharedNFRFactor(tp)*sharedNFRLoad(tp,ild) } ;

* Calculate HVDC constraint sets and HVDC Max Flow - NMIR (4.1.8 - NMIR06)
* TN on 22 May 2017: Usually a branch group constraint that limits the HVDC flow only involves
* the HVDC branch(s) in the same direction. However, during TP6 to TP9 of 18 May 2017, the
* constraint HAY_BEN_High_Frequency_limit involved all four branches in the form:
*   HAY_BEN1.1 + HAY_BEN2.1 - BEN_HAY1.1 - BEN_HAY2.1 <= 530 MW
* This method of formulating the constraint prevented the previous formulation of monopoleConstraint
* and bipoleConstraintfrom working properly. Those constraints have been reformulated (see below)
* in order to cope with the formulation observed on 18 May 2017.
monopoleConstraint(tp,ild,brCstr,br)
    $ { HVDCpoles(tp,br)
    and ( not rampingConstraint(tp,brCstr) )
    and ( branchConstraintSense(tp,brCstr) = -1 )
    and (Sum[ (br1,b) $ {HVDClinkSendingBus(tp,br1,b) and busIsland(tp,b,ild)}
                      , branchConstraintFactors(tp,brCstr,br1)    ] = 1)
    and (Sum[ b $ {HVDClinkSendingBus(tp,br,b) and busIsland(tp,b,ild)}
                 , branchConstraintFactors(tp,brCstr,br)      ] = 1)
       } = yes ;

bipoleConstraint(tp,ild,brCstr)
    $ { ( not rampingConstraint(tp,brCstr) )
    and ( branchConstraintSense(tp,brCstr) = -1 )
    and (Sum[ (br,b) $ { HVDCpoles(tp,br)
                     and HVDClinkSendingBus(tp,br,b)
                     and busIsland(tp,b,ild) }
                    , branchConstraintFactors(tp,brCstr,br)  ] = 2)
                       } = yes ;

monoPoleCapacity(tp,ild,br)
    = Sum[ (b,fd) $ { BusIsland(tp,b,ild)
                  and HVDCPoles(tp,br)
                  and HVDClinkSendingBus(tp,br,b)
                  and ( ord(fd) = 1 )
                    }, branchCapacity(tp,br,fd) ] ;

monoPoleCapacity(tp,ild,br)
    $ Sum[ brCstr $ monopoleConstraint(tp,ild,brCstr,br), 1]
    = Smin[ brCstr $ monopoleConstraint(tp,ild,brCstr,br)
          , branchConstraintLimit(tp,brCstr) ];

monoPoleCapacity(tp,ild,br)
    = Min( monoPoleCapacity(tp,ild,br),
           sum[ fd $ ( ord(fd) = 1 ), branchCapacity(tp,br,fd) ] );

biPoleCapacity(tp,ild)
    $ Sum[ brCstr $ bipoleConstraint(tp,ild,brCstr), 1]
    = Smin[ brCstr $ bipoleConstraint(tp,ild,brCstr)
          , branchConstraintLimit(tp,brCstr) ];

biPoleCapacity(tp,ild)
    $ { Sum[ brCstr $ bipoleConstraint(tp,ild,brCstr), 1] = 0 }
    = Sum[ (b,br,fd) $ { BusIsland(tp,b,ild) and HVDCPoles(tp,br)
                     and HVDClinkSendingBus(tp,br,b)
                     and ( ord(fd) = 1 )
                       }, branchCapacity(tp,br,fd) ] ;

HVDCMax(tp,ild)
    = Min( biPoleCapacity(tp,ild), Sum[ br, monoPoleCapacity(tp,ild,br) ] ) ;

* Calculate HVDC HVDC Loss segment applied for NMIR

$ontext
* Note: When NMIR started on 20/10/2016, the SOdecided to incorrectly calculate the HVDC loss
* curve for reserve sharing based on the HVDC capacity only (i.e. not based on in-service HVDC poles)
* Tuong Nguyen @ EA discovered this bug and the SO has fixed it as of 22/11/2016.
$offtext
if (inputGDXGDate >= jdate(2016,11,22),
      HVDCCapacity(tp,ild)
          = Sum[ (b,br,fd) $ { BusIsland(tp,b,ild) and HVDCPoles(tp,br)
                           and HVDClinkSendingBus(tp,br,b)
                           and ( ord(fd) = 1 )
                             }, branchCapacity(tp,br,fd) ] ;

      numberOfPoles(tp,ild)
          = Sum[ (b,br) $ { BusIsland(tp,b,ild) and HVDCPoles(tp,br)
                        and HVDClinkSendingBus(tp,br,b) }, 1 ] ;

      HVDCResistance(tp,ild) $ (numberOfPoles(tp,ild) = 2)
          = Prod[ (b,br) $ { BusIsland(tp,b,ild) and HVDCPoles(tp,br)
                         and HVDClinkSendingBus(tp,br,b)
                           }, branchResistance(tp,br) ]
          / Sum[ (b,br) $ { BusIsland(tp,b,ild) and HVDCPoles(tp,br)
                        and HVDClinkSendingBus(tp,br,b)
                          }, branchResistance(tp,br) ] ;

      HVDCResistance(tp,ild) $ (numberOfPoles(tp,ild) = 1)
          = Sum[ br $ monoPoleCapacity(tp,ild,br), branchResistance(tp,br) ] ;
else
    HVDCCapacity(tp,ild)
        = Sum[ (br,b,b1,fd) $ { (i_tradePeriodHVDCBranch(tp,br) = 1)
                            and i_tradePeriodBusIsland(tp,b,ild)
                            and i_tradePeriodBranchDefn(tp,br,b,b1)
                            and ( ord(fd) = 1 )
                              }, i_tradePeriodBranchCapacityDirected(tp,br,fd) ] ;

    numberOfPoles(tp,ild)
        =Sum[ (br,b,b1) $ { (i_tradePeriodHVDCBranch(tp,br) = 1)
                      and i_tradePeriodBusIsland(tp,b,ild)
                      and i_tradePeriodBranchDefn(tp,br,b,b1)
                      and sum[ fd $ ( ord(fd) = 1 )
                             , i_tradePeriodBranchCapacityDirected(tp,br,fd) ]
                        }, 1 ] ;

    HVDCResistance(tp,ild)
        =  Sum[ (br,b,b1,i_branchParameter)
              $ { (i_tradePeriodHVDCBranch(tp,br) = 1)
              and i_tradePeriodBusIsland(tp,b,ild)
              and i_tradePeriodBranchDefn(tp,br,b,b1)
              and (ord(i_branchParameter) = 1)
                }, i_tradePeriodBranchParameter(tp,br,i_branchParameter) ] ;

    HVDCResistance(tp,ild) $ (numberOfPoles(tp,ild) = 2)
        = Prod[ (br,b,b1,i_branchParameter)
              $ { (i_tradePeriodHVDCBranch(tp,br) = 1)
              and i_tradePeriodBusIsland(tp,b,ild)
              and i_tradePeriodBranchDefn(tp,br,b,b1)
              and sum[ fd $ ( ord(fd) = 1 )
                             , i_tradePeriodBranchCapacityDirected(tp,br,fd) ]
              and (ord(i_branchParameter) = 1)
                }, i_tradePeriodBranchParameter(tp,br,i_branchParameter)
              ] / HVDCResistance(tp,ild) ;
) ;

* Segment 1
HVDCLossSegmentMW(tp,ild,los) $ (ord(los) = 1)
    = HVDCCapacity(tp,ild) * lossCoeff_C ;

HVDCLossSegmentFactor(tp,ild,los) $ (ord(los) = 1)
    = 0.01 * 0.75 * lossCoeff_C
    * HVDCResistance(tp,ild) * HVDCCapacity(tp,ild) ;

* Segment 2
HVDCLossSegmentMW(tp,ild,los) $ (ord(los) = 2)
    = HVDCCapacity(tp,ild) * lossCoeff_D ;

HVDCLossSegmentFactor(tp,ild,los) $ (ord(los) = 2)
    = 0.01 * lossCoeff_E
    * HVDCResistance(tp,ild) * HVDCCapacity(tp,ild) ;

* Segment 3
HVDCLossSegmentMW(tp,ild,los) $ (ord(los) = 3)
    = HVDCCapacity(tp,ild) * 0.5 ;

HVDCLossSegmentFactor(tp,ild,los) $ (ord(los) = 3)
    = 0.01 * lossCoeff_F
    * HVDCResistance(tp,ild) * HVDCCapacity(tp,ild) ;

* Segment 4
HVDCLossSegmentMW(tp,ild,los) $ (ord(los) = 4)
    = HVDCCapacity(tp,ild) * (1 - lossCoeff_D) ;

HVDCLossSegmentFactor(tp,ild,los) $ (ord(los) = 4)
    = 0.01 * (2 - lossCoeff_F)
    * HVDCResistance(tp,ild) * HVDCCapacity(tp,ild) ;

* Segment 5
HVDCLossSegmentMW(tp,ild,los) $ (ord(los) = 5)
    = HVDCCapacity(tp,ild) * (1 - lossCoeff_C) ;

HVDCLossSegmentFactor(tp,ild,los) $ (ord(los) = 5)
    = 0.01 * (2 - lossCoeff_E)
    * HVDCResistance(tp,ild) * HVDCCapacity(tp,ild) ;

* Segment 6
HVDCLossSegmentMW(tp,ild,los) $ (ord(los) = 6)
    = HVDCCapacity(tp,ild) ;

HVDCLossSegmentFactor(tp,ild,los) $ (ord(los) = 6)
    = 0.01 * (2 - (0.75*lossCoeff_C))
    * HVDCResistance(tp,ild) * HVDCCapacity(tp,ild) ;

* Parameter for energy lambda loss model
HVDCSentBreakPointMWFlow(tp,ild,bp) $ (ord(bp) = 1) = 0 ;
HVDCSentBreakPointMWLoss(tp,ild,bp) $ (ord(bp) = 1) = 0 ;

HVDCSentBreakPointMWFlow(tp,ild,bp) $ (ord(bp) > 1)
    = HVDCLossSegmentMW(tp,ild,bp-1) ;

loop( (tp,ild,bp) $ {(ord(bp) > 1) and (ord(bp) <= 7)},
    HVDCSentBreakPointMWLoss(tp,ild,bp)
        = HVDClossScalingFactor(tp)
        * HVDCLossSegmentFactor(tp,ild,bp-1)
        * [ HVDCLossSegmentMW(tp,ild,bp-1)
          - HVDCSentBreakPointMWFlow(tp,ild,bp-1) ]
        + HVDCSentBreakPointMWLoss(tp,ild,bp-1) ;
) ;

* Parameter for energy+reserve lambda loss model

* Ideally SO should use asymmetric loss curve
HVDCReserveBreakPointMWFlow(tp,ild,rsbp) $ (ord(rsbp) <= 7)
    = Sum[ (ild1,rsbp1) $ { ( not sameas(ild1,ild) )
                        and ( ord(rsbp) + ord(rsbp1) = 8)}
         , -HVDCSentBreakPointMWFlow(tp,ild1,rsbp1) ];

* SO decide to use symmetric loss curve instead
HVDCReserveBreakPointMWFlow(tp,ild,rsbp) $ (ord(rsbp) <= 7)
    = Sum[ rsbp1 $ { ord(rsbp) + ord(rsbp1) = 8}
         , -HVDCSentBreakPointMWFlow(tp,ild,rsbp1) ];

HVDCReserveBreakPointMWFlow(tp,ild,rsbp)
    $ { (ord(rsbp) > 7) and (ord(rsbp) <= 13) }
    = HVDCSentBreakPointMWFlow(tp,ild,rsbp-6) ;


* Ideally SO should use asymmetric loss curve
HVDCReserveBreakPointMWLoss(tp,ild,rsbp) $ (ord(rsbp) <= 7)
    = Sum[ (ild1,rsbp1) $ { ( not sameas(ild1,ild) )
                        and ( ord(rsbp) + ord(rsbp1) = 8)}
         , HVDCSentBreakPointMWLoss(tp,ild1,rsbp1) ];

* SO decide to use symmetric loss curve instead
HVDCReserveBreakPointMWLoss(tp,ild,rsbp) $ (ord(rsbp) <= 7)
    = Sum[ rsbp1 $ { ord(rsbp) + ord(rsbp1) = 8}
         , HVDCSentBreakPointMWLoss(tp,ild,rsbp1) ];

HVDCReserveBreakPointMWLoss(tp,ild,rsbp)
    $ { (ord(rsbp) > 7) and (ord(rsbp) <= 13) }
    = HVDCSentBreakPointMWLoss(tp,ild,rsbp-6);

* Parameter for lambda loss model  end

* Initialze parameters for NMIR project end ----------------------------------


* Initialise risk/reserve data for the current trade period start

GenRisk(riskC)     $ (ord(riskC) = 1) = yes ;
HVDCrisk(riskC)    $ (ord(riskC) = 2) = yes ;
HVDCrisk(riskC)    $ (ord(riskC) = 3) = yes ;
ManualRisk(riskC)  $ (ord(riskC) = 4) = yes ;
GenRisk(riskC)     $ (ord(riskC) = 5) = yes $ useExtendedRiskClass ;
ManualRisk(riskC)  $ (ord(riskC) = 6) = yes $ useExtendedRiskClass ;
HVDCsecRisk(riskC) $ (ord(riskC) = 7) = yes $ useExtendedRiskClass ;
HVDCsecRisk(riskC) $ (ord(riskC) = 8) = yes $ useExtendedRiskClass ;

* Define the CE and ECE risk class set to support the different CE and ECE CVP
ContingentEvents(riskC)        $ (ord(riskC) = 1) = yes ;
ContingentEvents(riskC)        $ (ord(riskC) = 2) = yes ;
ExtendedContingentEvent(riskC) $ (ord(riskC) = 3) = yes ;
ContingentEvents(riskC)        $ (ord(riskC) = 4) = yes ;
ExtendedContingentEvent(riskC) $ (ord(riskC) = 5) = yes $ useExtendedRiskClass ;
ExtendedContingentEvent(riskC) $ (ord(riskC) = 6) = yes $ useExtendedRiskClass ;
ContingentEvents(riskC)        $ (ord(riskC) = 7) = yes $ useExtendedRiskClass ;
ExtendedContingentEvent(riskC) $ (ord(riskC) = 8) = yes $ useExtendedRiskClass ;

* Risk parameters
FreeReserve(tp,ild,resC,riskC)
    = sum[ riskPar $ (ord(riskPar) = 1)
                   , i_tradePeriodRiskParameter(tp,ild,resC,riskC,riskPar) ]
* NMIR - Subtract shareNFRMax from current NFR -(5.2.1.4) - SPD version 11
    - sum[ ild1 $ (not sameas(ild,ild1)),sharedNFRMax(tp,ild1)
         ] $ { (ord(resC)=1) and ( (GenRisk(riskC)) or (ManualRisk(riskC)) )
           and (inputGDXGDate >= jdate(2016,10,20)) }
    ;

IslandRiskAdjustmentFactor(tp,ild,resC,riskC) $ useReserveModel
    = sum[ riskPar $ (ord(riskPar) = 2)
                   , i_tradePeriodRiskParameter(tp,ild,resC,riskC,riskPar) ] ;

* HVDC rampup max - (3.4.1.3) - SPD version 11
HVDCpoleRampUp(tp,ild,resC,riskC)
    = sum[ riskPar $ (ord(riskPar) = 3)
                   , i_tradePeriodRiskParameter(tp,ild,resC,riskC,riskPar) ] ;

* Index IslandMinimumRisk to cater for CE and ECE minimum risk
IslandMinimumRisk(tp,ild,resC,riskC) $ (ord(riskC) = 4)
    = i_tradePeriodManualRisk(tp,ild,resC) ;

IslandMinimumRisk(tp,ild,resC,riskC) $ (ord(riskC) = 6)
    = i_tradePeriodManualRisk_ECE(tp,ild,resC) ;

* HVDC secondary risk parameters
HVDCsecRiskEnabled(tp,ild,riskC)= i_tradePeriodHVDCsecRiskEnabled(tp,ild,riskC);
HVDCsecRiskSubtractor(tp,ild)   = i_tradePeriodHVDCsecRiskSubtractor(tp,ild) ;

* Min risks for the HVDC secondary risk are the same as the island min risk
HVDCsecIslandMinimumRisk(tp,ild,resC,riskC) $ (ord(riskC) = 7)
    = i_tradePeriodManualRisk(tp,ild,resC) ;

HVDCsecIslandMinimumRisk(tp,ild,resC,riskC) $ (ord(riskC) = 8)
    = i_tradePeriodManualRisk_ECE(tp,ild,resC) ;

* The MW combined maximum capability for generation and reserve of class.
reserveClassGenerationMaximum(offer,resC) = ReserveGenerationMaximum(offer) ;

reserveClassGenerationMaximum(offer,resC)
    $ i_tradePeriodReserveClassGenerationMaximum(offer,resC)
    = i_tradePeriodReserveClassGenerationMaximum(offer,resC) ;

* Calculation of reserve maximum factor - 5.2.1.1
ReserveMaximumFactor(offer,resC) = 1 ;
ReserveMaximumFactor(offer,resC)
    $ (ReserveClassGenerationMaximum(offer,resC)>0)
    = ReserveGenerationMaximum(offer)
    / reserveClassGenerationMaximum(offer,resC) ;

* Virtual reserve
virtualReserveMax(tp,ild,resC) = i_tradePeriodVROfferMax(tp,ild,resC) ;
virtualReservePrice(tp,ild,resC) = i_tradePeriodVROfferPrice(tp,ild,resC) ;

* Initialise AC node constraint data for the current trading period
ACnodeConstraint(tp,ACnodeCstr)
    $ sum[ ACnode(tp,n)
         $ i_tradePeriodACnodeConstraintFactors(tp,ACnodeCstr,n), 1 ] = yes ;

ACnodeConstraintFactors(ACnodeConstraint,n)
    = i_tradePeriodACnodeConstraintFactors(ACnodeConstraint,n) ;

ACnodeConstraintSense(ACnodeConstraint)
    = sum[ CstrRHS $ (ord(CstrRHS) = 1),
         i_tradePeriodACnodeConstraintRHS(ACnodeConstraint,CstrRHS) ] ;

ACnodeConstraintLimit(ACnodeConstraint)
    = sum[ CstrRHS $ (ord(CstrRHS) = 2),
         i_tradePeriodACnodeConstraintRHS(ACnodeConstraint,CstrRHS) ] ;

* Initialise market node constraint data for the current trading period
MnodeConstraint(tp,MnodeCstr)
    $ { sum[ (offer(tp,o),resT,resC)
           $ { i_tradePeriodMnodeEnergyOfferConstraintFactors(tp,MnodeCstr,o) or
               i_tradePeriodMnodeReserveOfferConstraintFactors(tp,MnodeCstr,o,resC,resT)
             }, 1
           ]
      or
        sum[ (bid(tp,bd),resC)
           $ { i_tradePeriodMnodeEnergyBidConstraintFactors(tp,MnodeCstr,bd) or
               i_tradePeriodMnodeILReserveBidConstraintFactors(tp,MnodeCstr,bd,resC)
             }, 1
           ]
      } = yes ;

MnodeEnergyOfferConstraintFactors(MnodeConstraint,o)
    = i_tradePeriodMnodeEnergyOfferConstraintFactors(MnodeConstraint,o) ;

MnodeReserveOfferConstraintFactors(MnodeConstraint,o,resC,resT)
    = i_tradePeriodMnodeReserveOfferConstraintFactors(MnodeConstraint,o,resC,resT) ;

MnodeEnergyBidConstraintFactors(MnodeConstraint,bd)
    = i_tradePeriodMnodeEnergyBidConstraintFactors(MnodeConstraint,bd) ;

MnodeILReserveBidConstraintFactors(MnodeConstraint,bd,resC)
    = i_tradePeriodMnodeILReserveBidConstraintFactors(MnodeConstraint,bd,resC) ;

MnodeConstraintSense(MnodeConstraint)
    = sum[ CstrRHS $ (ord(CstrRHS) = 1)
         , i_tradePeriodMnodeConstraintRHS(MnodeConstraint,CstrRHS) ] ;

MnodeConstraintLimit(MnodeConstraint)
    = sum[ CstrRHS $ (ord(CstrRHS) = 2)
         , i_tradePeriodMnodeConstraintRHS(MnodeConstraint,CstrRHS) ] ;

* Initialise mixed constraint data for the current trading period
Type1MixCstrReserveMap(t1MixCstr,ild,resC,riskC)
    = i_type1MixedConstraintReserveMap(t1MixCstr,ild,resC,riskC) ;

Type1MixedConstraint(tp,t1MixCstr)
    = i_tradePeriodType1MixedConstraint(tp,t1MixCstr) ;

Type2MixedConstraint(tp,t2MixCstr)
    = i_tradePeriodType2MixedConstraint(tp,t2MixCstr) ;

Type1MixedConstraintSense(tp,t1MixCstr)
    = sum[ t1MixCstrRHS $ (ord(t1MixCstrRHS) = 1)
         , i_tradePeriodType1MixedConstraintRHSParameters(tp,t1MixCstr,t1MixCstrRHS) ] ;

Type1MixedConstraintLimit1(tp,t1MixCstr)
    = sum[ t1MixCstrRHS $ (ord(t1MixCstrRHS) = 2)
         , i_tradePeriodType1MixedConstraintRHSParameters(tp,t1MixCstr,t1MixCstrRHS) ] ;

Type1MixedConstraintLimit2(tp,t1MixCstr)
    = sum[ t1MixCstrRHS $ (ord(t1MixCstrRHS) = 3)
         , i_tradePeriodType1MixedConstraintRHSParameters(tp,t1MixCstr,t1MixCstrRHS) ] ;

Type2MixedConstraintSense(tp,t2MixCstr)
    = sum[ CstrRHS $ (ord(CstrRHS) = 1)
         , i_tradePeriodType2MixedConstraintRHSParameters(tp,t2MixCstr,CstrRHS) ] ;

Type2MixedConstraintLimit(tp,t2MixCstr)
    = sum[ CstrRHS$(ord(CstrRHS) = 2)
         , i_tradePeriodType2MixedConstraintRHSParameters(tp,t2MixCstr,CstrRHS) ] ;

Type1MixedConstraintCondition(tp,t1MixCstr)
    $ sum[ br $ { HVDChalfPoles(tp,br) and
                  i_type1MixedConstraintBranchCondition(t1MixCstr,br)
                }, 1
         ] = yes ;

* Initialise generic constraint data for the current trading period
GenericConstraint(tp,gnrcCstr) = i_tradePeriodGenericConstraint(tp,gnrcCstr) ;

GenericEnergyOfferConstraintFactors(GenericConstraint,o)
    = i_tradePeriodGenericEnergyOfferConstraintFactors(GenericConstraint,o) ;

GenericReserveOfferConstraintFactors(GenericConstraint,o,resC,resT)
    = i_tradePeriodGenericReserveOfferConstraintFactors(GenericConstraint,o,resC,resT) ;

GenericEnergyBidConstraintFactors(GenericConstraint,bd)
    = i_tradePeriodGenericEnergyBidConstraintFactors(GenericConstraint,bd) ;

GenericILReserveBidConstraintFactors(GenericConstraint,bd,resC)
    = i_tradePeriodGenericILReserveBidConstraintFactors(GenericConstraint,bd,resC) ;

GenericBranchConstraintFactors(GenericConstraint,br)
    = i_tradePeriodGenericBranchConstraintFactors(GenericConstraint,br) ;

GenericConstraintSense(GenericConstraint)
    = sum[ CstrRHS $ (ord(CstrRHS) = 1)
         , i_tradePeriodGenericConstraintRHS(GenericConstraint,CstrRHS) ] ;

GenericConstraintLimit(GenericConstraint)
    = sum[ CstrRHS $ (ord(CstrRHS) = 2)
         , i_tradePeriodGenericConstraintRHS(GenericConstraint,CstrRHS) ] ;


* Additional pre-processing on parameters --------------------------------------

* Calculation of generation upper limits due to ramp rate limits

* Only primary offers are considered (5.3.1.1)
generationMaximum(tp,o) $ (not hasPrimaryOffer(tp,o))
    = sum[ validGenerationOfferBlock(tp,o,trdBlk)
         , generationOfferMW(tp,o,trdBlk) ]
    + sum[ (o1,trdBlk) $ { primarySecondaryOffer(tp,o,o1) and
                           validGenerationOfferBlock(tp,o1,trdBlk) }
         , generationOfferMW(tp,o1,trdBlk)
         ] ;

* Calculation 5.3.1.2. - For primary-secondary offers, only primary offer
* initial MW and ramp rate is used - Reference: Transpower Market Services
rampTimeUp(offer) $ { (not hasPrimaryOffer(offer)) and rampRateUp(offer) }
    = Min[ i_tradingPeriodLength , ( generationMaximum(offer)
                                   - generationStart(offer)
                                   ) / rampRateUp(offer)
         ] ;

* Calculation 5.3.1.3. - For primary-secondary offers, only primary offer
* initial MW and ramp rate is used - Reference: Transpower Market Services
generationEndUp(offer) $ (not hasPrimaryOffer(offer))
    = generationStart(offer) + rampRateUp(offer)*rampTimeUp(offer) ;


* Calculation of generation lower limits due to ramp rate limits

* Only primary offers are considered (5.3.2.1)
* Negative prices for generation offers are not allowed? (5.3.2.1)
generationMinimum(offer) = 0;

*   Calculation 5.3.2.2. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
rampTimeDown(offer) $ { (not hasPrimaryOffer(offer)) and rampRateDown(offer) }
    = Min[ i_tradingPeriodLength, ( generationStart(offer)
                                  - generationMinimum(offer)
                                  ) / rampRateDown(offer)
         ] ;

*   Calculation 5.3.2.3. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
generationEndDown(offer) $ (not hasPrimaryOffer(offer))
    = Max[ 0, generationStart(offer) - rampRateDown(offer)*rampTimeDown(offer) ] ;

o_offerEnergy_TP(dt,o) = 0;
*   Additional pre-processing on parameters end



* TN - Pivot or demand analysis begin
$Ifi %opMode%=='PVT' $include "Pivot\vSPDSolvePivot_1.gms"
$Ifi %opMode%=='DPS' $include "Demand\vSPDSolveDPS_1.gms"
* TN - Pivot or demand analysis begin end

*=====================================================================================
* 7. The vSPD solve loop
*=====================================================================================

unsolvedPeriod(tp) = yes;
VSPDModel(tp) = 0 ;
option clear = useBranchFlowMIP ;
option clear = useMixedConstraintMIP ;

While ( Sum[ tp $ unsolvedPeriod(tp), 1 ],
  exitLoop = 0;
  loop[ tp $ {unsolvedPeriod(tp) and (exitLoop = 0)},

*   7a. Reset all sets, parameters and variables -------------------------------
    option clear = currTP ;
*   Generation variables
    option clear = GENERATION ;
    option clear = GENERATIONBLOCK ;
*   Purchase variables
    option clear = PURCHASE ;
    option clear = PURCHASEBLOCK ;
    option clear = PURCHASEILR ;
    option clear = PURCHASEILRBLOCK ;
*   Network variables
    option clear = ACNODENETINJECTION ;
    option clear = ACNODEANGLE ;
    option clear = ACBRANCHFLOW ;
    option clear = ACBRANCHFLOWDIRECTED ;
    option clear = ACBRANCHLOSSESDIRECTED ;
    option clear = ACBRANCHFLOWBLOCKDIRECTED ;
    option clear = ACBRANCHLOSSESBLOCKDIRECTED ;
    option clear = ACBRANCHFLOWDIRECTED_INTEGER ;
    option clear = HVDCLINKFLOW ;
    option clear = HVDCLINKLOSSES ;
    option clear = LAMBDA ;
    option clear = LAMBDAINTEGER ;
    option clear = HVDCLINKFLOWDIRECTION_INTEGER ;
    option clear = HVDCPOLEFLOW_INTEGER ;
*   Risk/Reserve variables
    option clear = RISKOFFSET ;
    option clear = HVDCREC ;
    option clear = ISLANDRISK ;
    option clear = RESERVEBLOCK ;
    option clear = RESERVE ;
    option clear = ISLANDRESERVE;
*   NMIR variables
    option clear = SHAREDNFR ;
    option clear = SHAREDRESERVE ;
    option clear = HVDCSENT ;
    option clear = RESERVESHAREEFFECTIVE ;
    option clear = RESERVESHARERECEIVED ;
    option clear = RESERVESHARESENT ;
    option clear = HVDCSENDING ;
    option clear = INZONE ;
    option clear = HVDCSENTINSEGMENT ;
    option clear = HVDCRESERVESENT ;
    option clear = HVDCSENTLOSS ;
    option clear = HVDCRESERVELOSS ;
    option clear = LAMBDAHVDCENERGY ;
    option clear = LAMBDAHVDCRESERVE ;
    option clear = RESERVESHAREPENALTY ;
*   Mixed constraint variables
    option clear = MIXEDCONSTRAINTVARIABLE ;
    option clear = MIXEDCONSTRAINTLIMIT2SELECT ;
*   Objective
    option clear = NETBENEFIT ;
*   Violation variables
    option clear = TOTALPENALTYCOST ;
    option clear = DEFICITBUSGENERATION ;
    option clear = SURPLUSBUSGENERATION ;
    option clear = DEFICITRESERVE ;
    option clear = DEFICITRESERVE_CE ;
    option clear = DEFICITRESERVE_ECE ;
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

*   Clear the pole circular branch flow flag
    option clear = circularBranchFlowExist ;
    option clear = poleCircularBranchFlowExist ;
    option clear = northHVDC ;
    option clear = southHVDC ;
    option clear = manualBranchSegmentMWFlow ;
    option clear = manualLossCalculation ;
    option clear = nonPhysicalLossExist ;
    option clear = modelSolved ;
    option clear = LPmodelSolved ;
*   Disconnected bus post-processing
    option clear = busGeneration ;
    option clear = busLoad ;
    option clear = busDisconnected ;
    option clear = busPrice ;


*   End reset


*   7b. Initialise current trade period and model data -------------------------
    currTP(tp)  $ sequentialSolve       = yes;
    currTP(tp1) $ (not sequentialSolve) = yes;

*   Update initial MW if run NRSS, PRSS, NRSL, PRSL
    generationStart(offer(currTP(tp),o))
        $ (sum[ o1, generationStart(currTP,o1)] = 0)
        = sum[ dt $ (ord(dt) = ord(tp)-1), o_offerEnergy_TP(dt,o) ] ;
*   Calculation of generation upper limits due to ramp rate limits
*   Calculation 5.3.1.2. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
    rampTimeUp(offer(currTP(tp),o))
        $ { (not hasPrimaryOffer(offer)) and rampRateUp(offer) }
        = Min[ i_tradingPeriodLength , ( generationMaximum(offer)
                                       - generationStart(offer)
                                       ) / rampRateUp(offer)
             ] ;

*   Calculation 5.3.1.3. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
    generationEndUp(offer(currTP(tp),o)) $ (not hasPrimaryOffer(offer))
        = generationStart(offer) + rampRateUp(offer)*rampTimeUp(offer) ;


*   Calculation of generation lower limits due to ramp rate limits

*   Calculation 5.3.2.2. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
    rampTimeDown(offer(currTP(tp),o))
        $ { (not hasPrimaryOffer(offer)) and rampRateDown(offer) }
        = Min[ i_tradingPeriodLength, ( generationStart(offer)
                                      - generationMinimum(offer)
                                      ) / rampRateDown(offer)
             ] ;

*   Calculation 5.3.2.3. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
    generationEndDown(offer(currTP(tp),o)) $ (not hasPrimaryOffer(offer))
        = Max[ 0, generationStart(offer)
                - rampRateDown(offer)*rampTimeDown(offer) ] ;

*   Additional pre-processing on parameters end


*   7c. Updating the variable bounds before model solve ------------------------

* TN - Pivot or Demand Analysis - revise input data
$Ifi %opMode%=='PVT' $include "Pivot\vSPDSolvePivot_2.gms"
$Ifi %opMode%=='DPS' $include "Demand\vSPDSolveDPS_2.gms"
* TN - Pivot or Demand Analysis - revise input data end

*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS ========================

*   Offer blocks - Constraint 3.1.1.1
    GENERATIONBLOCK.up(validGenerationOfferBlock(currTP,o,trdBlk))
        = generationOfferMW(validGenerationOfferBlock) ;

    GENERATIONBLOCK.fx(currTP,o,trdBlk)
        $ (not validGenerationOfferBlock(currTP,o,trdBlk)) = 0 ;

*   Constraint 3.1.1.2 - Fix the generation variable for generators
*   that are not connected or do not have a non-zero energy offer
    GENERATION.fx(offer(currTP,o)) $ (not PositiveEnergyOffer(offer)) = 0 ;

*   Constraint 5.1.1.3 - Set Upper Bound for Wind Offer - Tuong
    GENERATION.up(offer(currTP,o))
        $ { windOffer(offer) and priceResponsive(offer) }
        = min[ potentialMW(offer), ReserveGenerationMaximum(offer) ] ;

*   Change to demand bid - Constraint 3.1.1.3 and 3.1.1.4
    PURCHASEBLOCK.up(validPurchaseBidBlock(currTP,bd,trdBlk))
        $ (not UseDSBFDemandBidModel)
        = purchaseBidMW(validPurchaseBidBlock) ;

    PURCHASEBLOCK.lo(validPurchaseBidBlock(currTP,bd,trdBlk))
        $ (not UseDSBFDemandBidModel)
        = 0 ;

    PURCHASEBLOCK.up(validPurchaseBidBlock(currTP,bd,trdBlk))
        $ UseDSBFDemandBidModel
        = purchaseBidMW(currTP,bd,trdBlk) $ [purchaseBidMW(currTP,bd,trdBlk)>0];

    PURCHASEBLOCK.lo(validPurchaseBidBlock(currTP,bd,trdBlk))
        $ UseDSBFDemandBidModel
        = purchaseBidMW(currTP,bd,trdBlk) $ [purchaseBidMW(currTP,bd,trdBlk)<0];

    PURCHASEBLOCK.fx(currTP,bd,trdBlk)
        $ (not validPurchaseBidBlock(currTP,bd,trdBlk))
        = 0 ;

*   Fix the purchase variable for purchasers that are not connected
*   or do not have a non-zero purchase bid
    PURCHASE.fx(currTP,bd)
        $ (sum[trdBlk $ validPurchaseBidBlock(currTP,bd,trdBlk), 1] = 0) = 0 ;

*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS END ====================


*======= HVDC TRANSMISSION EQUATIONS ===========================================

*   Ensure that variables used to specify flow and losses on HVDC link are
*   zero for AC branches and for open HVDC links.
    HVDCLINKFLOW.fx(currTP,br)   $ (not HVDClink(currTP,br)) = 0 ;
    HVDCLINKLOSSES.fx(currTP,br) $ (not HVDClink(currTP,br)) = 0 ;

*   Apply an upper bound on the weighting parameter based on its definition
    LAMBDA.up(branch,bp) = 1 ;

*   Ensure that the weighting factor value is zero for AC branches and for
*   invalid loss segments on HVDC links
    LAMBDA.fx(HVDClink,bp)
        $ ( sum[fd $ validLossSegment(HVDClink,bp,fd),1] = 0 ) = 0 ;
    LAMBDA.fx(currTP,br,bp) $ (not HVDClink(currTP,br)) = 0 ;

*======= HVDC TRANSMISSION EQUATIONS END =======================================


*======= AC TRANSMISSION EQUATIONS =============================================

*   Ensure that variables used to specify flow and losses on AC branches are
*   zero for HVDC links branches and for open AC branches
    ACBRANCHFLOW.fx(currTP,br)              $ (not ACbranch(currTP,br)) = 0 ;
    ACBRANCHFLOWDIRECTED.fx(currTP,br,fd)   $ (not ACbranch(currTP,br)) = 0 ;
    ACBRANCHLOSSESDIRECTED.fx(currTP,br,fd) $ (not ACbranch(currTP,br)) = 0 ;

*   Ensure directed block flow and loss block variables are zero for
*   non-AC branches and invalid loss segments on AC branches
   ACBRANCHFLOWBLOCKDIRECTED.fx(currTP,br,los,fd)
       $ { not(ACbranch(currTP,br) and validLossSegment(currTP,br,los,fd)) } = 0 ;

   ACBRANCHLOSSESBLOCKDIRECTED.fx(currTP,br,los,fd)
       $ { not(ACbranch(currTP,br) and validLossSegment(currTP,br,los,fd)) } = 0 ;


*   Constraint 3.3.1.10 - Ensure that the bus voltage angle for the buses
*   corresponding to the reference nodes and the HVDC nodes are set to zero
    ACNODEANGLE.fx(currTP,b)
       $ sum[ n $ { NodeBus(currTP,n,b) and
                    (ReferenceNode(currTP,n) or HVDCnode(currTP,n)) }, 1 ] = 0 ;

*======= AC TRANSMISSION EQUATIONS END =========================================


*======= RISK & RESERVE EQUATIONS ==============================================

*   Ensure that all the invalid reserve blocks are set to zero for offers and purchasers
    RESERVEBLOCK.fx(offer(currTP,o),trdBlk,resC,resT)
        $ (not validReserveOfferBlock(offer,trdBlk,resC,resT)) = 0 ;

    PURCHASEILRBLOCK.fx(bid(currTP,bd),trdBlk,resC)
        $ (not validPurchaseBidILRBlock(bid,trdBlk,resC)) = 0 ;

*   Reserve block maximum for offers and purchasers - Constraint 3.4.3.2.
    RESERVEBLOCK.up(validReserveOfferBlock(currTP,o,trdBlk,resC,resT))
        = reserveOfferMaximum(validReserveOfferBlock) ;

    PURCHASEILRBLOCK.up(validPurchaseBidILRBlock(currTP,bd,trdBlk,resC))
        = purchaseBidILRMW(validPurchaseBidILRBlock) ;

*   Fix the reserve variable for invalid reserve offers. These are offers that
*   are either not connected to the grid or have no reserve quantity offered.
    RESERVE.fx(currTP,o,resC,resT)
        $ (not sum[ trdBlk $ validReserveOfferBlock(currTP,o,trdBlk,resC,resT), 1 ] ) = 0 ;

*   Fix the purchase ILR variable for invalid purchase reserve offers. These are
*   offers that are either not connected to the grid or have no reserve quantity offered.
    PURCHASEILR.fx(currTP,bd,resC)
        $ (not sum[ trdBlk $ validPurchaseBidILRBlock(currTP,bd,trdBlk,resC), 1 ] ) = 0 ;

*   Risk offset fixed to zero for those not mapped to corresponding mixed constraint variable
    RISKOFFSET.fx(currTP,ild,resC,riskC)
        $ { useMixedConstraintRiskOffset and useMixedConstraint(currTP) and
            (not sum[ t1MixCstr $ Type1MixCstrReserveMap(t1MixCstr,ild,resC,riskC),1])
          } = 0 ;

*   Fix the appropriate deficit variable to zero depending on
*   whether the different CE and ECE CVP flag is set
    DEFICITRESERVE.fx(currTP,ild,resC) $ diffCeECeCVP = 0 ;
    DEFICITRESERVE_CE.fx(currTP,ild,resC) $ (not diffCeECeCVP) = 0 ;
    DEFICITRESERVE_ECE.fx(currTP,ild,resC) $ (not diffCeECeCVP) = 0 ;

*   Virtual reserve
    VIRTUALRESERVE.up(currTP,ild,resC) = virtualReserveMax(currTP,ild,resC) ;

* TN - The code below is used to set bus deficit generation <= total bus load (positive)
$ontext
    DEFICITBUSGENERATION.up(currTP,b)
        $ ( sum[ NodeBus(currTP,n,b)
               , NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n)
               ] > 0 )
        = sum[ NodeBus(currTP,n,b)
             , NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n)
             ]  ;
    DEFICITBUSGENERATION.fx(currTP,b)
        $ ( sum[ NodeBus(currTP,n,b)
               , NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n)
               ] <= 0 )
        = 0 ;
$offtext
*   NMIR project variables
    HVDCSENT.fx(currTP,ild) $ (HVDCCapacity(currTP,ild) = 0) = 0 ;
    HVDCSENTLOSS.fx(currTP,ild) $ (HVDCCapacity(currTP,ild) = 0) = 0 ;

*   (3.4.2.3) - SPD version 11.0
    SHAREDNFR.up(currTP,ild) = Max[0,sharedNFRMax(currTP,ild)] ;

*   No forward reserve sharing if HVDC capacity is zero
    RESERVESHARESENT.fx(currTP,ild,resC,rd)
        $ { (HVDCCapacity(currTP,ild) = 0) and (ord(rd) = 1) } = 0 ;

*   No forward reserve sharing if reserve sharing is disabled
    RESERVESHARESENT.fx(currTP,ild,resC,rd)
        $ (reserveShareEnabled(currTP,resC)=0) = 0;

*   No reserve sharing to cover HVDC risk
    RESERVESHAREEFFECTIVE.fx(currTP,ild,resC,HVDCrisk) = 0;
    RESERVESHAREEFFECTIVE.fx(currTP,ild,resC,HVDCsecRisk) = 0;

*   (3.4.2.16) - SPD version 11 - no RP zone if reserve round power disabled
    INZONE.fx(currTP,ild,resC,z)
        $ {(ord(z) = 1) and (not reserveRoundPower(currTP,resC))} = 0;

*   (3.4.2.17) - SPD version 11 - no no-reserve zone for SIR zone if reserve RP enabled
    INZONE.fx(currTP,ild,resC,z)
        $ {(ord(resC)=2) and (ord(z)=2) and reserveRoundPower(currTP,resC)} = 0;

*   Fixing Lambda integer variable for energy sent
    LAMBDAHVDCENERGY.fx(currTP,ild,bp) $ { (HVDCCapacity(currTP,ild) = 0)
                                        and (ord(bp) = 1) } = 1 ;

    LAMBDAHVDCENERGY.fx(currTP,ild,bp) $ (ord(bp) > 7) = 0 ;

* To be reviewed NMIR
    LAMBDAHVDCRESERVE.fx(currTP,ild,resC,rd,rsbp)
        $ { (HVDCCapacity(currTP,ild) = 0)
        and (ord(rsbp) = 7) and (ord(rd) = 1) } = 1 ;

    LAMBDAHVDCRESERVE.fx(currTP,ild1,resC,rd,rsbp)
        $ { (sum[ ild $ (not sameas(ild,ild1)), HVDCCapacity(currTP,ild) ] = 0)
        and (ord(rsbp) < 7) and (ord(rd) = 2) } = 0 ;
;


*======= RISK & RESERVE EQUATIONS END ==========================================


*======= MIXED CONSTRAINTS =====================================================

*   Mixed constraint
    MIXEDCONSTRAINTVARIABLE.fx(currTP,t1MixCstr)
        $ (not i_type1MixedConstraintVarWeight(t1MixCstr)) = 0 ;

*======= MIXED CONSTRAINTS END =================================================

*   Updating the variable bounds before model solve end


*   7d. Solve Models

*   Solve the LP model ---------------------------------------------------------
    if( (Sum[currTP, VSPDModel(currTP)] = 0),

        if( UseShareReserve,
            option bratio = 1 ;
            vSPD_NMIR.Optfile = 1 ;
            vSPD_NMIR.optcr = MIPOptimality ;
            vSPD_NMIR.reslim = MIPTimeLimit ;
            vSPD_NMIR.iterlim = MIPIterationLimit ;
            solve vSPD_NMIR using mip maximizing NETBENEFIT ;
*           Set the model solve status
            ModelSolved = 1 $ { ( (vSPD_NMIR.modelstat = 1)
                               or (vSPD_NMIR.modelstat = 8) )
                            and ( vSPD_NMIR.solvestat = 1 ) } ;
        else
            option bratio = 1 ;
            vSPD.reslim = LPTimeLimit ;
            vSPD.iterlim = LPIterationLimit ;
            solve vSPD using lp maximizing NETBENEFIT ;
*           Set the model solve status
            ModelSolved = 1 $ { (vSPD.modelstat = 1) and (vSPD.solvestat = 1) };
        )

*       Post a progress message to the console and for use by EMI.
        if((ModelSolved = 1) and (sequentialSolve = 0),
            putclose runlog 'The case: %vSPDinputData% '
                            'is solved successfully.'/
                            'Objective function value: '
                            NETBENEFIT.l:<12:1 /
                            'Violation Cost          : '
                            TOTALPENALTYCOST.l:<12:1 /
        elseif((ModelSolved = 0) and (sequentialSolve = 0)),
            putclose runlog 'The case: %vSPDinputData% '
                            'is solved unsuccessfully.'/
        ) ;

        if((ModelSolved = 1) and (sequentialSolve = 1),
            loop(currTP,
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is solved successfully.'/
                                'Objective function value: '
                                NETBENEFIT.l:<12:1 /
                                'Violations cost         : '
                                TOTALPENALTYCOST.l:<12:1 /
            ) ;
        elseif((ModelSolved = 0) and (sequentialSolve = 1)),
            loop(currTP,
                unsolvedPeriod(currTP) = no;
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is solved unsuccessfully.'/
            ) ;

        ) ;
*   Solve the LP model end -----------------------------------------------------


*   Solve the VSPD_MIP model ---------------------------------------------------
    elseif (Sum[currTP, VSPDModel(currTP)] = 1),
*       Fix the values of the integer variables that are not needed
        ACBRANCHFLOWDIRECTED_INTEGER.fx(branch(currTP,br),fd)
            $ { (not ACbranch(currTP,br)) or (not LossBranch(branch)) } = 0 ;

*       Fix the integer AC branch flow variable to zero for invalid branches
        ACBRANCHFLOWDIRECTED_INTEGER.fx(currTP,br,fd)
            $ (not branch(currTP,br)) = 0 ;

*       Apply an upper bound on the integer weighting parameter
        LAMBDAINTEGER.up(branch(currTP,br),bp) = 1 ;

*       Ensure that the weighting factor value is zero for AC branches
*       and for invalid loss segments on HVDC links
        LAMBDAINTEGER.fx(branch(currTP,br),bp)
            $ { ACbranch(branch)
            or ( sum[fd $ validLossSegment(branch,bp,fd),1 ] = 0 )
              } = 0 ;

*       Fix the lambda integer variable to zero for invalid branches
        LAMBDAINTEGER.fx(currTP,br,bp) $ (not branch(currTP,br)) = 0 ;

*       Fix the value of some binary variables used in the mixed constraints
*       that have no alternate limit
        MIXEDCONSTRAINTLIMIT2SELECT.fx(Type1MixedConstraint(currTP,t1MixCstr))
            $ (not Type1MixedConstraintCondition(Type1MixedConstraint)) = 0 ;

        option bratio = 1 ;
        vSPD_MIP.Optfile = 1 ;
        vSPD_MIP.optcr = MIPOptimality ;
        vSPD_MIP.reslim = MIPTimeLimit ;
        vSPD_MIP.iterlim = MIPIterationLimit ;
        solve vSPD_MIP using mip maximizing NETBENEFIT ;
*       Set the model solve status
        ModelSolved = 1 $ { [ (vSPD_MIP.modelstat = 1) or
                              (vSPD_MIP.modelstat = 8)
                            ]
                            and
                            [ vSPD_MIP.solvestat = 1 ]
                          } ;

*       Post a progress message for use by EMI.
        if(ModelSolved = 1,
            loop(currTP,
                unsolvedPeriod(currTP) = no;
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is solved successfully for FULL integer.'/
                                'Objective function value: '
                                NETBENEFIT.l:<12:1 /
                                'Violations              : '
                                TOTALPENALTYCOST.l:<12:1 /
            ) ;
        else
            loop(currTP,
                unsolvedPeriod(currTP) = yes;
                VSPDModel(currTP) = 4;
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is solved unsuccessfully for FULL integer.'/
            ) ;
        ) ;
*   Solve the vSPD_MIP model end -----------------------------------------------


*   Solve the vSPD_BranchFlowMIP -----------------------------------------------
    elseif (Sum[currTP, VSPDModel(currTP)] = 2),
*       Fix the values of these integer variables that are not needed
        ACBRANCHFLOWDIRECTED_INTEGER.fx(branch(currTP,br),fd)
            $ { (not ACbranch(currTP,br)) or (not LossBranch(branch)) } = 0 ;

*       Fix the integer AC branch flow variable to zero for invalid branches
        ACBRANCHFLOWDIRECTED_INTEGER.fx(currTP,br,fd)
            $ (not branch(currTP,br)) = 0 ;

*       Apply an upper bound on the integer weighting parameter
        LAMBDAINTEGER.up(branch(currTP,br),bp) = 1 ;

*       Ensure that the weighting factor value is zero for AC branches
*       and for invalid loss segments on HVDC links
        LAMBDAINTEGER.fx(branch(currTP,br),bp)
            $ { ACbranch(branch)
            or ( sum[fd $ validLossSegment(branch,bp,fd),1 ] = 0 )
              } = 0 ;

*       Fix the lambda integer variable to zero for invalid branches
        LAMBDAINTEGER.fx(currTP,br,bp) $ (not branch(currTP,br)) = 0 ;

        option bratio = 1 ;
        vSPD_BranchFlowMIP.Optfile = 1 ;
        vSPD_BranchFlowMIP.optcr = MIPOptimality ;
        vSPD_BranchFlowMIP.reslim = MIPTimeLimit ;
        vSPD_BranchFlowMIP.iterlim = MIPIterationLimit ;
        solve vSPD_BranchFlowMIP using mip maximizing NETBENEFIT ;
*       Set the model solve status
        ModelSolved = 1 $ { [ ( vSPD_BranchFlowMIP.modelstat = 1) or
                              (vSPD_BranchFlowMIP.modelstat = 8)
                            ]
                            and
                            [ vSPD_BranchFlowMIP.solvestat = 1 ]
                          } ;

*       Post a progress message for use by EMI.
        if(ModelSolved = 1,
		
*           TN - Replacing invalid prices after SOS1 - Flag to show the period that required SOS1 solve	
            vSPD_SOS1_Solve(currTP)  = yes;	

            loop(currTP,
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is solved successfully for branch integer.'/
                                'Objective function value: '
                                NETBENEFIT.l:<12:1 /
                                'Violations cost         : '
                                TOTALPENALTYCOST.l:<12:1 /
            ) ;
        else
            loop(currTP,
                unsolvedPeriod(currTP) = yes;
                VSPDModel(currTP) = 4;
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is solved unsuccessfully for branch integer.'/
            ) ;
        ) ;
*   Solve the vSPD_BranchFlowMIP model end -------------------------------------


*   Solve the vSPD_MixedConstraintMIP model ------------------------------------
    elseif (Sum[currTP, VSPDModel(currTP)] = 3),
*       Fix the value of some binary variables used in the mixed constraints
*       that have no alternate limit
        MIXEDCONSTRAINTLIMIT2SELECT.fx(Type1MixedConstraint(currTP,t1MixCstr))
            $ (not Type1MixedConstraintCondition(Type1MixedConstraint)) = 0 ;

*       Use the advanced basis here
        option bratio = 0.25 ;
        vSPD_MixedConstraintMIP.Optfile = 1 ;
*       Set the optimality criteria for the MIP
        vSPD_MixedConstraintMIP.optcr = MIPOptimality ;
        vSPD_MixedConstraintMIP.reslim = MIPTimeLimit ;
        vSPD_MixedConstraintMIP.iterlim = MIPIterationLimit ;
*       Solve the model
        solve vSPD_MixedConstraintMIP using mip maximizing NETBENEFIT ;
*       Set the model solve status
        ModelSolved = 1 $ { [ (vSPD_MixedConstraintMIP.modelstat = 1) or
                              (vSPD_MixedConstraintMIP.modelstat = 8)
                            ]
                            and
                            [ vSPD_MixedConstraintMIP.solvestat = 1 ]
                          } ;

*       Post a progress message for use by EMI.
        if(ModelSolved = 1,
            loop(currTP,
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is solved successfully for '
                                'mixed constraint integer.'/
                                'Objective function value: '
                                NETBENEFIT.l:<12:1 /
                                'Violations cost         : '
                                TOTALPENALTYCOST.l:<12:1 /
            ) ;
        else
            loop(currTP,
                unsolvedPeriod(currTP) = yes;
                VSPDModel(currTP) = 1;
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is solved unsuccessfully for '
                                'mixed constraint integer.'/
            ) ;
        ) ;
*   Solve the vSPD_MixedConstraintMIP model end --------------------------------


*   Solve the LP model and stop ------------------------------------------------
    elseif (Sum[currTP, VSPDModel(currTP)] = 4),

        if( UseShareReserve,
            option bratio = 1 ;
            vSPD_NMIR.Optfile = 1 ;
            vSPD_NMIR.optcr = MIPOptimality ;
            vSPD_NMIR.reslim = MIPTimeLimit ;
            vSPD_NMIR.iterlim = MIPIterationLimit ;
            solve vSPD_NMIR using mip maximizing NETBENEFIT ;
*           Set the model solve status
            ModelSolved = 1 $ { ( (vSPD_NMIR.modelstat = 1)
                               or (vSPD_NMIR.modelstat = 8) )
                            and ( vSPD_NMIR.solvestat = 1 ) } ;
        else
            option bratio = 1 ;
            vSPD.reslim = LPTimeLimit ;
            vSPD.iterlim = LPIterationLimit ;
            solve vSPD using lp maximizing NETBENEFIT ;
*           Set the model solve status
            ModelSolved = 1 $ { (vSPD.modelstat = 1) and (vSPD.solvestat = 1) };
        )

*       Post a progress message for use by EMI.
        if( ModelSolved = 1,
            loop(currTP,
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ')'
                                ' integer resolve was unsuccessful.' /
                                'Reverting back to linear solve and '
                                'solve successfully. ' /
                                'Objective function value: '
                                NETBENEFIT.l:<12:1 /
                                'Violations cost         : '
                                TOTALPENALTYCOST.l:<12:1 /
                                'Solution may have circulating flows '
                                'and/or non-physical losses.' /
            ) ;
        else
            loop(currTP,
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl
                                ') integer solve was unsuccessful. '
                                'Reverting back to linear solve. '
                                'Linear solve unsuccessful.' /
            ) ;
        ) ;

        unsolvedPeriod(currTP) = no;

*   Solve the LP model and stop end --------------------------------------------

    ) ;
*   Solve the models end



*   6e. Check if the LP results are valid --------------------------------------
    if((ModelSolved = 1),
        useBranchFlowMIP(currTP) = 0 ;
        useMixedConstraintMIP(currTP) = 0 ;
*       Check if there is no branch circular flow and non-physical losses
        Loop( currTP $ { (VSPDModel(currTP)=0) or (VSPDModel(currTP)=3) } ,

*           Check if there are circulating branch flows on loss AC branches
            circularBranchFlowExist(ACbranch(currTP,br))
                $ { LossBranch(ACbranch) and
                    [ ( sum[ fd, ACBRANCHFLOWDIRECTED.l(ACbranch,fd) ]
                      - abs(ACBRANCHFLOW.l(ACbranch))
                      ) > circularBranchFlowTolerance
                    ]
                  } = 1 ;

*           Determine the circular branch flow flag on each HVDC pole
            TotalHVDCpoleFlow(currTP,pole)
                = sum[ br $ HVDCpoleBranchMap(pole,br)
                     , HVDCLINKFLOW.l(currTP,br) ] ;

            MaxHVDCpoleFlow(currTP,pole)
                = smax[ br $ HVDCpoleBranchMap(pole,br)
                      , HVDCLINKFLOW.l(currTP,br) ] ;

            poleCircularBranchFlowExist(currTP,pole)
                $ { ( TotalHVDCpoleFlow(currTP,pole)
                    - MaxHVDCpoleFlow(currTP,pole)
                    ) > circularBranchFlowTolerance
                  } = 1 ;

*           Check if there are circulating branch flows on HVDC
            NorthHVDC(currTP)
                = sum[ (ild,b,br) $ { (ord(ild) = 2) and
                                      i_tradePeriodBusIsland(currTP,b,ild) and
                                      HVDClinkSendingBus(currTP,br,b) and
                                      HVDCpoles(currTP,br)
                                    }, HVDCLINKFLOW.l(currTP,br)
                     ] ;

            SouthHVDC(currTP)
                = sum[ (ild,b,br) $ { (ord(ild) = 1) and
                                      i_tradePeriodBusIsland(currTP,b,ild) and
                                      HVDClinkSendingBus(currTP,br,b) and
                                      HVDCpoles(currTP,br)
                                    }, HVDCLINKFLOW.l(currTP,br)
                     ] ;

            circularBranchFlowExist(currTP,br)
                $ { HVDCpoles(currTP,br) and LossBranch(currTP,br) and
                   (NorthHVDC(currTP) > circularBranchFlowTolerance) and
                   (SouthHVDC(currTP) > circularBranchFlowTolerance)
                  } = 1 ;

*           Check if there are non-physical losses on HVDC links
            ManualBranchSegmentMWFlow(LossBranch(HVDClink(currTP,br)),los,fd)
                $ { ( ord(los) <= branchLossBlocks(HVDClink) )
                and validLossSegment(currTP,br,los,fd) }
                = Min[ Max( 0,
                            [ abs(HVDCLINKFLOW.l(HVDClink))
                            - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                            ]
                          ),
                       ( LossSegmentMW(HVDClink,los,fd)
                       - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                       )
                     ] ;

            ManualLossCalculation(LossBranch(HVDClink(currTP,br)))
                = sum[ (los,fd) $ validLossSegment(currTP,br,los,fd)
                                , LossSegmentFactor(HVDClink,los,fd)
                                * ManualBranchSegmentMWFlow(HVDClink,los,fd)
                     ] ;

            NonPhysicalLossExist(LossBranch(HVDClink(currTP,br)))
                $ { abs( HVDCLINKLOSSES.l(HVDClink)
                       - ManualLossCalculation(HVDClink)
                       ) > NonPhysicalLossTolerance
                  } = 1 ;

*           Set UseBranchFlowMIP = 1 if the number of circular branch flow
*           and non-physical loss branches exceeds the specified tolerance
            useBranchFlowMIP(currTP)
                $ { ( sum[ br $ { ACbranch(currTP,br) and LossBranch(currTP,br) }
                              , resolveCircularBranchFlows
                              * circularBranchFlowExist(currTP,br)
                         ]
                    + sum[ br $ { HVDClink(currTP,br) and LossBranch(currTP,br) }
                              , (1 - AllowHVDCroundpower(currTP))
                              * resolveCircularBranchFlows
                              * circularBranchFlowExist(currTP,br)
                              + resolveHVDCnonPhysicalLosses
                              * NonPhysicalLossExist(currTP,br)
                         ]
                    + sum[ pole, resolveCircularBranchFlows
                               * poleCircularBranchFlowExist(currTP,pole)
                         ]
                     ) > UseBranchFlowMIPTolerance
                                       } = 1 ;

*       Check if there is no branch circular flow and non-physical losses end
        );


*       Check if there is mixed constraint integer is required
        Loop( currTP $ { (VSPDModel(currTP)=0) or (VSPDModel(currTP)=2) } ,

*           Check if integer variables are needed for mixed constraint
            if( useMixedConstraintRiskOffset,
                HVDChalfPoleSouthFlow(currTP)
                    $ { sum[ i_type1MixedConstraintBranchCondition(t1MixCstr,br)
                             $ HVDChalfPoles(currTP,br), HVDCLINKFLOW.l(currTP,br)
                           ] > MixedMIPTolerance
                      } = 1 ;

*               Only calculate violation if the constraint limit is non-zero
                Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition)
                    $ (Type1MixedConstraintLimit2(Type1MixedConstraintCondition) > 0)
                    = [ Type1MixedConstraintLE.l(Type1MixedConstraintCondition)
                      - Type1MixedConstraintLimit2(Type1MixedConstraintCondition)
                      ] $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = -1)
                    + [ Type1MixedConstraintLimit2(Type1MixedConstraintCondition)
                      - Type1MixedConstraintGE.l(Type1MixedConstraintCondition)
                      ] $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = 1)
                    + abs[ Type1MixedConstraintEQ.l(Type1MixedConstraintCondition)
                         - Type1MixedConstraintLimit2(Type1MixedConstraintCondition)
                         ] $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = 0) ;

*               Integer constraints are needed if southward flow on half-poles AND
*               constraint level exceeds the mixed constraint limit2 value
                useMixedConstraintMIP(currTP)
                    $ { HVDChalfPoleSouthFlow(currTP) and
                        sum[ t1MixCstr
                             $ { Type1MixedConstraintLimit2Violation(currTP,t1MixCstr)
                               > MixedMIPTolerance }, 1
                           ]
                      } = 1 ;
            ) ;

*       Check if there is mixed constraint integer is required end
        );

*       A period is unsolved if MILP model is required
        unsolvedPeriod(currTP) = yes $ [ UseBranchFlowMIP(currTP)
                                       + UseMixedConstraintMIP(currTP)
                                       ] ;

*       Post a progress message for use by EMI. Reverting to the sequential mode for integer resolves.
        loop( unsolvedPeriod(currTP),
            if( UseBranchFlowMIP(currTP)*UseMixedConstraintMIP(currTP) >= 1,
                VSPDModel(currTP) = 1;
                putclose runlog 'The case: %vSPDinputData% requires a'
                                'VSPD_MIP resolve for period ' currTP.tl
                                '. Switching Vectorisation OFF.' /

            elseif UseBranchFlowMIP(currTP) >= 1,
                if( VSPDModel(currTP) = 0,
                    VSPDModel(currTP) = 2;
                    putclose runlog 'The case: %vSPDinputData% requires a '
                                    'vSPD_BranchFlowMIP resolve for period '
                                    currTP.tl '. Switching Vectorisation OFF.'/
                elseif VSPDModel(currTP) = 3,
                    VSPDModel(currTP) = 1;
                    putclose runlog 'The case: %vSPDinputData% requires a '
                                    'VSPD_MIP resolve for period ' currTP.tl
                                    '. Switching Vectorisation OFF.' /
                );

            elseif UseMixedConstraintMIP(currTP) >= 1,
                if( VSPDModel(currTP) = 0,
                    VSPDModel(currTP) = 3;
                    putclose runlog 'The case: %vSPDinputData% requires a '
                                    'vSPD_MixedConstraintMIP resolve for period '
                                    currTP.tl '. Switching Vectorisation OFF.' /
                elseif VSPDModel(currTP) = 2,
                    VSPDModel(currTP) = 1;
                    putclose runlog 'The case: %vSPDinputData% requires a '
                                    'VSPD_MIP resolve for period ' currTP.tl
                                    '. Switching Vectorisation OFF.' /
                );

            ) ;

        ) ;

        sequentialSolve $ Sum[ unsolvedPeriod(currTP), 1 ] = 1 ;
        exitLoop = 1 $ Sum[ unsolvedPeriod(currTP), 1 ];

*   Check if the LP results are valid end
    ) ;



*   6f. Check for disconnected nodes and adjust prices accordingly -------------

*   See Rule Change Proposal August 2008 - Disconnected nodes available at
*   www.systemoperator.co.nz/reports-papers
$ontext
    Disconnected nodes are defined as follows:
    Pre-MSP: Have no generation or load, are disconnected from the network
             and has a price = CVP.
    Post-MSP: Indication to SPD whether a bus is dead or not.
              Dead buses are not processed by the SPD solved
    Disconnected nodes' prices set by the post-process with the following rules:
    Scenario A/B/D: Price for buses in live electrical island determined
                    by the solved
    Scenario C/F/G/H/I: Buses in the dead electrical island with:
        a. Null/zero load: Marked as disconnected with $0 price.
        b. Positive load: Price = CVP for deficit generation
        c. Negative load: Price = -CVP for surplus generation
    Scenario E: Price for bus in live electrical island with zero load and
                zero cleared generation needs to be adjusted since actually
                is disconnected.

    The Post-MSP implementation imply a mapping of a bus to an electrical island
    and an indication of whether this electrical island is live of dead.
    The correction of the prices is performed by SPD.

    Update the disconnected nodes logic to use the time-stamped
    i_useBusNetworkModel flag. This allows disconnected nodes logic to work
    with both pre and post-MSP data structure in the same gdx file
$offtext

    busGeneration(bus(currTP,b))
        = sum[ (o,n) $ { offerNode(currTP,o,n) and NodeBus(currTP,n,b) }
             , NodeBusAllocationFactor(currTP,n,b) * GENERATION.l(currTP,o)
             ] ;

    busLoad(bus(currTP,b))
        = sum[ NodeBus(currTP,n,b)
             , NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n)
             ] ;

    busPrice(bus(currTP,b)) $ { not sum[ NodeBus(HVDCnode(currTP,n),b), 1 ] }
        = ACnodeNetInjectionDefinition2.m(currTP,b) ;

    busPrice(bus(currTP,b)) $ sum[ NodeBus(HVDCnode(currTP,n),b), 1 ]
        = DCNodeNetInjection.m(currTP,b) ;

    if((disconnectedNodePriceCorrection = 1),
*       Pre-MSP case
        busDisconnected(bus(currTP,b)) $ (i_useBusNetworkModel(currTP) = 0)
            = 1 $ { (busGeneration(bus) = 0) and  (busLoad(bus) = 0) and
                    ( not sum[ br $ { branchBusConnect(currTP,br,b) and
                                      branch(currTP,br)
                                    }, 1 ]
                    )
                  } ;

*       Post-MSP cases
*       Scenario C/F/G/H/I:
        busDisconnected(bus(currTP,b)) $ { (i_useBusNetworkModel(currTP) = 1)
                                       and (busLoad(bus) = 0)
                                       and (busElectricalIsland(bus) = 0)
                                         } = 1 ;
*       Scenario E:
        busDisconnected(bus(currTP,b))
            $ { ( sum[ b1 $ { busElectricalIsland(currTP,b1)
                            = busElectricalIsland(bus) }
                     , busLoad(currTP,b1) ] = 0
                ) and
                ( sum[ b1 $ { busElectricalIsland(currTP,b1)
                            = busElectricalIsland(bus) }
                     , busGeneration(currTP,b1) ] = 0
                ) and
                ( busElectricalIsland(bus) > 0 ) and
                ( i_useBusNetworkModel(currTP) = 1 )
              } = 1 ;
*       Set prices at dead buses with non-zero load
        busPrice(bus(currTP,b)) $ { (i_useBusNetworkModel(currTP) = 1) and
                                    (busLoad(bus) > 0) and
                                    (busElectricalIsland(bus)= 0)
                                  } = DeficitBusGenerationPenalty ;

        busPrice(bus(currTP,b)) $ { (i_useBusNetworkModel(currTP) = 1) and
                                    (busLoad(bus) < 0) and
                                    (busElectricalIsland(bus)= 0)
                                  } = -SurplusBusGenerationPenalty ;

*       Set price at identified disconnected buses to 0
        busPrice(bus)$busDisconnected(bus) = 0 ;
    ) ;

* End Check for disconnected nodes and adjust prices accordingly

* TN - Replacing invalid prices after SOS1	
*   6f0. Replacing invalid prices after SOS1 (6.1.3)----------------------------	
    if ( vSPD_SOS1_Solve(tp),	
         busSOSinvalid(tp,b)	
           = 1 $ { [ ( busPrice(tp,b) = 0 )	
                    or ( busPrice(tp,b) > 0.9 * deficitBusGenerationPenalty )	
                    or ( busPrice(tp,b) < -0.9 * surplusBusGenerationPenalty )	
                     ]	
                 and bus(tp,b)	
                 and [ not busDisconnected(tp,b) ]	
*                 and [ busLoad(tp,b) = 0 ]	
*                 and [ busGeneration(tp,b) = 0 ]
                 and [ busLoad(tp,b) = busGeneration(tp,b) ]	
                 and [ sum[(br,fd)	
                          $ { BranchBusConnect(tp,br,b) and branch(tp,br) }	
                          , ACBRANCHFLOWDIRECTED.l(tp,br,fd)	
                          ] = 0	
                     ]	
                 and [ sum[ br	
                          $ { BranchBusConnect(tp,br,b) and branch(tp,br) }	
                          , 1	
                          ] > 0	
                     ]	
                   };	
        numberofbusSOSinvalid(tp) = 2*sum[b, busSOSinvalid(tp,b)];	
        While ( sum[b, busSOSinvalid(tp,b)] < numberofbusSOSinvalid(tp) ,
            numberofbusSOSinvalid(tp) = sum[b, busSOSinvalid(tp,b)];	
            busPrice(tp,b)	
              $ { busSOSinvalid(tp,b)	
              and ( sum[ b1 $ { [ not busSOSinvalid(tp,b1) ]	
                            and sum[ br $ { branch(tp,br)	
                                        and BranchBusConnect(tp,br,b)	
                                        and BranchBusConnect(tp,br,b1)	
                                          }, 1	
                                   ]	
                             }, 1	
                       ] > 0	
                  )	
                }	
              = sum[ b1 $ { [ not busSOSinvalid(tp,b1) ]	
                        and sum[ br $ { branch(tp,br)	
                                    and BranchBusConnect(tp,br,b)	
                                    and BranchBusConnect(tp,br,b1)	
                                      }, 1 ]	
                          }, busPrice(tp,b1)	
                   ]	
              / sum[ b1 $ { [ not busSOSinvalid(tp,b1) ]	
                        and sum[ br $ { branch(tp,br)	
                                    and BranchBusConnect(tp,br,b)	
                                    and BranchBusConnect(tp,br,b1)	
                                      }, 1 ]	
                          }, 1	
                   ];
                    
            busSOSinvalid(tp,b)	
              = 1 $ { [ ( busPrice(tp,b) = 0 )	
                     or ( busPrice(tp,b) > 0.9 * deficitBusGenerationPenalty )	
                     or ( busPrice(tp,b) < -0.9 * surplusBusGenerationPenalty )	
                      ]	
                  and bus(tp,b)	
                  and [ not busDisconnected(tp,b) ]	
*                  and [ busLoad(tp,b) = 0 ]	
*                  and [ busGeneration(tp,b) = 0 ]
                  and [ busLoad(tp,b) = busGeneration(tp,b) ]	
                  and [ sum[(br,fd)	
                          $ { BranchBusConnect(tp,br,b) and branch(tp,br) }	
                          , ACBRANCHFLOWDIRECTED.l(tp,br,fd)	
                           ] = 0	
                      ]	
                  and [ sum[ br	
                           $ { BranchBusConnect(tp,br,b) and branch(tp,br) }	
                           , 1	
                           ] > 0	
                      ]	
                    };	
         );	
    );	
*   End Replacing invalid prices after SOS1 (6.1.3) ----------------------------


*   6g. Collect and store results of solved periods into output parameters -----
* Note: all the price relating outputs such as costs and revenues are calculated in section 7.b

$iftheni.PeriodReport %opMode%=='FTR' $include "FTRental\vSPDSolveFTR_3.gms"
$elseifi.PeriodReport %opMode%=='DWH' $include "DWmode\vSPDSolveDWH_3.gms"
$elseifi.PeriodReport %opMode%=='PVT' $include "Pivot\vSPDSolvePivot_3.gms"
$elseifi.PeriodReport %opMode%=='DPS' $include "Demand\vSPDSolveDPS_3.gms"

$else.PeriodReport
*   Normal vSPD run post processing for reporting
$onend
    Loop i_dateTimeTradePeriodMap(dt,currTP) $ (not unsolvedPeriod(currTP)) do
*   Reporting at trading period start
*       Node level output
        o_node(dt,n) $ {Node(currTP,n) and (not HVDCnode(currTP,n))} = yes ;

        o_nodeGeneration_TP(dt,n) $ Node(currTP,n)
            = sum[ o $ offerNode(currTP,o,n), GENERATION.l(currTP,o) ] ;

        o_nodeLoad_TP(dt,n) $ Node(currTP,n)
           = NodeDemand(currTP,n)
           + Sum[ bd $ bidNode(currTP,bd,n), PURCHASE.l(currTP,bd) ];

        o_nodePrice_TP(dt,n) $ Node(currTP,n)
            = sum[ b $ NodeBus(currTP,n,b)
                 , NodeBusAllocationFactor(currTP,n,b) * busPrice(currTP,b)
                  ] ;

*       Offer output
        o_offer(dt,o) $ offer(currTP,o) = yes ;

        o_offerEnergy_TP(dt,o) $ offer(currTP,o) = GENERATION.l(currTP,o) ;

        o_offerFIR_TP(dt,o) $ offer(currTP,o)
            = sum[ (resC,resT)$(ord(resC) = 1)
                 , RESERVE.l(currTP,o,resC,resT) ] ;

        o_offerSIR_TP(dt,o) $ offer(currTP,o)
            = sum[ (resC,resT)$(ord(resC) = 2)
                 , RESERVE.l(currTP,o,resC,resT) ] ;

*       Bus level output
        o_bus(dt,b) $ { bus(currTP,b) and (not DCBus(currTP,b)) } = yes ;

        o_busGeneration_TP(dt,b) $ bus(currTP,b) = busGeneration(currTP,b) ;

        o_busLoad_TP(dt,b) $ bus(currTP,b)
            = busLoad(currTP,b)
            + Sum[ (bd,n) $ { bidNode(currTP,bd,n) and NodeBus(currTP,n,b) }
                 , PURCHASE.l(currTP,bd) ];

        o_busPrice_TP(dt,b) $ bus(currTP,b) = busPrice(currTP,b) ;

        o_busDeficit_TP(dt,b)$bus(currTP,b) = DEFICITBUSGENERATION.l(currTP,b) ;

        o_busSurplus_TP(dt,b)$bus(currTP,b) = SURPLUSBUSGENERATION.l(currTP,b) ;

*       Node level output

        totalBusAllocation(dt,b) $ bus(currTP,b)
            = sum[ n $ Node(currTP,n), NodeBusAllocationFactor(currTP,n,b)];

        busNodeAllocationFactor(dt,b,n) $ (totalBusAllocation(dt,b) > 0)
            = NodeBusAllocationFactor(currTP,n,b) / totalBusAllocation(dt,b) ;

* TN - post processing unmapped generation deficit buses start
$ontext
The following code is added post-process generation deficit bus that is not
mapped to a pnode (BusNodeAllocationFactor  = 0). In post-processing, when a
deficit is detected at a bus that does not map directly to a pnode, SPD creates
a ZBR mapping by following zero impendence branches (ZBRs) until it reaches a
pnode. The price at the deficit bus is assigned directly to the pnode,
overwriting any weighted price that post-processing originally calculated for
the pnode. This is based on email from Nic Deller <Nic.Deller@transpower.co.nz>
on 25 Feb 2015.
The code is modified again on 16 Feb 2016 to avoid infinite loop when there are
many generation deficit buses.
This code is used to post-process generation deficit bus that is not mapped to
$offtext
        unmappedDeficitBus(dt,b) $ o_busDeficit_TP(dt,b)
            = yes $ (Sum[ n, busNodeAllocationFactor(dt,b,n)] = 0);

        changedDeficitBus(dt,b) = no;

        If Sum[b $ unmappedDeficitBus(dt,b), 1] then

            temp_busDeficit_TP(dt,b) = o_busDeficit_TP(dt,b);

            Loop b $ unmappedDeficitBus(dt,b) do
                o_busDeficit_TP(dt,b1)
                  $ { Sum[ br $ { ( branchLossBlocks(tp,br)=0 )
                              and ( branchBusDefn(tp,br,b1,b)
                                 or branchBusDefn(tp,br,b,b1) )
                                }, 1 ]
                    } = o_busDeficit_TP(dt,b1) + o_busDeficit_TP(dt,b) ;

                changedDeficitBus(dt,b1)
                  $ Sum[ br $ { ( branchLossBlocks(tp,br)=0 )
                            and ( branchBusDefn(tp,br,b1,b)
                               or branchBusDefn(tp,br,b,b1) )
                              }, 1 ] = yes;

                unmappedDeficitBus(dt,b) = no;
                changedDeficitBus(dt,b) = no;
                o_busDeficit_TP(dt,b) = 0;
            EndLoop;

            Loop n $ sum[ b $ changedDeficitBus(dt,b)
                        , busNodeAllocationFactor(dt,b,n)] do
                o_nodePrice_TP(dt,n) = deficitBusGenerationPenalty ;
                o_nodeDeficit_TP(dt,n) = sum[ b $ busNodeAllocationFactor(dt,b,n),
                                                  busNodeAllocationFactor(dt,b,n)
                                                * o_busDeficit_TP(dt,b) ] ;
            EndLoop;

            o_busDeficit_TP(dt,b) = temp_busDeficit_TP(dt,b);
        Endif;
* TN - post processing unmapped generation deficit buses end

        o_nodeDeficit_TP(dt,n) $ Node(currTP,n)
            = sum[ b $ NodeBus(currTP,n,b), busNodeAllocationFactor(dt,b,n)
                                          * DEFICITBUSGENERATION.l(currTP,b) ] ;

        o_nodeSurplus_TP(dt,n) $ Node(currTP,n)
            = sum[ b $ NodeBus(currTP,n,b), busNodeAllocationFactor(dt,b,n)
                                          * SURPLUSBUSGENERATION.l(currTP,b) ] ;

*       branch output
        o_branch(dt,br) $ branch(currTP,br) = yes ;

        o_branchFlow_TP(dt,br) $ ACbranch(currTP,br) = ACBRANCHFLOW.l(currTP,br);

        o_branchFlow_TP(dt,br) $ HVDClink(currTP,br) = HVDCLINKFLOW.l(currTP,br);

        o_branchDynamicLoss_TP(dt,br) $  ACbranch(currTP,br)
            = sum[ fd, ACBRANCHLOSSESDIRECTED.l(currTP,br,fd) ] ;

        o_branchDynamicLoss_TP(dt,br) $ HVDClink(currTP,br)
            = HVDCLINKLOSSES.l(currTP,br) ;

        o_branchFixedLoss_TP(dt,br) $ branch(currTP,br)
            = branchFixedLoss(currTP,br) ;

        o_branchTotalLoss_TP(dt,br) $ branch(currTP,br)
            = o_branchDynamicLoss_TP(dt,br) + o_branchFixedLoss_TP(dt,br) ;

        o_branchFromBus_TP(dt,br,frB)
            $ { branch(currTP,br) and
                sum[ toB $ branchBusDefn(currTP,br,frB,toB), 1 ]
              } = yes ;

        o_branchToBus_TP(dt,br,toB)
            $ { branch(currTP,br) and
                sum[ frB $ branchBusDefn(currTP,br,frB,toB), 1 ]
              } = yes ;

        o_branchMarginalPrice_TP(dt,br) $ ACbranch(currTP,br)
            = sum[ fd, ACbranchMaximumFlow.m(currTP,br,fd) ] ;

        o_branchMarginalPrice_TP(dt,br) $ HVDClink(currTP,br)
            = HVDClinkMaximumFlow.m(currTP,br) ;

        o_branchCapacity_TP(dt,br) $ branch(currTP,br)
            = sum[ fd $ ( ord(fd) = 1 )
                      , i_tradePeriodBranchCapacityDirected(currTP,br,fd)
                 ] $  { o_branchFlow_TP(dt,br) >= 0 }
            + sum[ fd $ ( ord(fd) = 2 )
                      , i_tradePeriodBranchCapacityDirected(currTP,br,fd)
                 ] $  { o_branchFlow_TP(dt,br) < 0 } ;


*       Offer output
        o_offerEnergyBlock_TP(dt,o,trdBlk)
            = GENERATIONBLOCK.l(currTP,o,trdBlk);

        o_offerFIRBlock_TP(dt,o,trdBlk,resT)
            = sum[ resC $ (ord(resC) = 1)
            , RESERVEBLOCK.l(currTP,o,trdBlk,resC,resT)];

        o_offerSIRBlock_TP(dt,o,trdBlk,resT)
            = sum[ resC $ (ord(resC) = 2)
            , RESERVEBLOCK.l(currTP,o,trdBlk,resC,resT)];

*       bid output
        o_bid(dt,bd) $ bid(currTP,bd) = yes ;

        o_bidEnergy_TP(dt,bd) $ bid(currTP,bd) = PURCHASE.l(currTP,bd) ;

        o_bidFIR_TP(dt,bd) $ bid(currTP,bd)
            = sum[ resC $ (ord(resC) = 1)
                 , PURCHASEILR.l(currTP,bd,resC) ] ;

        o_bidSIR_TP(dt,bd) $ bid(currTP,bd)
            = sum[ resC $ (ord(resC) = 2)
                 , PURCHASEILR.l(currTP,bd,resC) ] ;

        o_bidTotalMW_TP(dt,bd) $ bid(currTP,bd)
            = sum[ trdBlk, purchaseBidMW(currTP,bd,trdBlk) ] ;

*       Violation reporting based on the CE and ECE
        o_ResViolation_TP(dt,ild,resC)
            = DEFICITRESERVE.l(currTP,ild,resC)     $ (not diffCeECeCVP)
            + DEFICITRESERVE_CE.l(currTP,ild,resC)  $ (diffCeECeCVP)
            + DEFICITRESERVE_ECE.l(currTP,ild,resC) $ (diffCeECeCVP) ;

        o_FIRviolation_TP(dt,ild)
            = sum[ resC $ (ord(resC) = 1), o_ResViolation_TP(dt,ild,resC) ] ;

        o_SIRviolation_TP(dt,ild)
            = sum[ resC $ (ord(resC) = 2), o_ResViolation_TP(dt,ild,resC) ] ;

*       Security constraint data
        o_brConstraint_TP(dt,brCstr) $ branchConstraint(currTP,brCstr) = yes ;

        o_brConstraintSense_TP(dt,brCstr) $ branchConstraint(currTP,brCstr)
            = branchConstraintSense(currTP,brCstr) ;

        o_brConstraintLHS_TP(dt,brCstr) $ branchConstraint(currTP,brCstr)
            = [ branchSecurityConstraintLE.l(currTP,brCstr)
              $ (branchConstraintSense(currTP,brCstr) = -1) ]
            + [ branchSecurityConstraintGE.l(currTP,brCstr)
              $ (branchConstraintSense(currTP,brCstr) = 1)  ]
            + [ branchSecurityConstraintEQ.l(currTP,brCstr)
              $ (branchConstraintSense(currTP,brCstr) = 0)  ] ;

        o_brConstraintRHS_TP(dt,brCstr) $ branchConstraint(currTP,brCstr)
            = branchConstraintLimit(currTP,brCstr) ;

        o_brConstraintPrice_TP(dt,brCstr) $ branchConstraint(currTP,brCstr)
            = [ branchSecurityConstraintLE.m(currTP,brCstr)
              $ (branchConstraintSense(currTP,brCstr) = -1) ]
            + [ branchSecurityConstraintGE.m(currTP,brCstr)
              $ (branchConstraintSense(currTP,brCstr) = 1)  ]
            + [ branchSecurityConstraintEQ.m(currTP,brCstr)
              $ (branchConstraintSense(currTP,brCstr) = 0)  ] ;

*       Mnode constraint data
        o_MnodeConstraint_TP(dt,MnodeCstr)
            $ MnodeConstraint(currTP,MnodeCstr) = yes ;

        o_MnodeConstraintSense_TP(dt,MnodeCstr)
            $ MnodeConstraint(currTP,MnodeCstr)
            = MnodeConstraintSense(currTP,MnodeCstr) ;

        o_MnodeConstraintLHS_TP(dt,MnodeCstr)
            $ MnodeConstraint(currTP,MnodeCstr)
            = [ MnodeSecurityConstraintLE.l(currTP,MnodeCstr)
              $ (MnodeConstraintSense(currTP,MnodeCstr) = -1) ]
            + [ MnodeSecurityConstraintGE.l(currTP,MnodeCstr)
              $ (MnodeConstraintSense(currTP,MnodeCstr) = 1)  ]
            + [ MnodeSecurityConstraintEQ.l(currTP,MnodeCstr)
              $ (MnodeConstraintSense(currTP,MnodeCstr) = 0)  ] ;

        o_MnodeConstraintRHS_TP(dt,MnodeCstr)
            $ MnodeConstraint(currTP,MnodeCstr)
            = MnodeConstraintLimit(currTP,MnodeCstr) ;

        o_MnodeConstraintPrice_TP(dt,MnodeCstr)
            $ MnodeConstraint(currTP,MnodeCstr)
            = [ MnodeSecurityConstraintLE.m(currTP,MnodeCstr)
              $ (MnodeConstraintSense(currTP,MnodeCstr) = -1) ]
            + [ MnodeSecurityConstraintGE.m(currTP,MnodeCstr)
              $ (MnodeConstraintSense(currTP,MnodeCstr) = 1)  ]
            + [ MnodeSecurityConstraintEQ.m(currTP,MnodeCstr)
              $ (MnodeConstraintSense(currTP,MnodeCstr) = 0)  ] ;

*       Island output
        o_island(dt,ild) = yes ;

        o_ResPrice_TP(dt,ild,resC)= IslandReserveCalculation.m(currTP,ild,resC);

        o_FIRprice_TP(dt,ild) = sum[ resC $ (ord(resC) = 1)
                                          , o_ResPrice_TP(dt,ild,resC) ];

        o_SIRprice_TP(dt,ild) = sum[ resC $ (ord(resC) = 2)
                                          , o_ResPrice_TP(dt,ild,resC) ];

        o_islandGen_TP(dt,ild)
            = sum[ b $ busIsland(currTP,b,ild), busGeneration(currTP,b) ] ;

        o_islandClrBid_TP(dt,ild)
            = sum[ bd $ bidIsland(currTP,bd,ild), PURCHASE.l(currTP,bd) ] ;

        o_islandLoad_TP(dt,ild)
            = sum[ b $ busIsland(currTP,b,ild), busLoad(currTP,b) ]
            + o_islandClrBid_TP(dt,ild) ;

        o_ResCleared_TP(dt,ild,resC) = ISLANDRESERVE.l(currTP,ild,resC);

        o_FirCleared_TP(dt,ild) = Sum[ resC $ (ord(resC) = 1)
                                            , o_ResCleared_TP(dt,ild,resC) ];

        o_SirCleared_TP(dt,ild) = Sum[ resC $ (ord(resC) = 2)
                                            , o_ResCleared_TP(dt,ild,resC) ];

        o_islandBranchLoss_TP(dt,ild)
            = sum[ (br,frB,toB)
                 $ { ACbranch(currTP,br) and busIsland(currTP,toB,ild)
                 and branchBusDefn(currTP,br,frB,toB)
                   }, o_branchTotalLoss_TP(dt,br) ] ;

        o_HVDCflow_TP(dt,ild)
            = sum[ (br,frB,toB)
                 $ { HVDCpoles(currTP,br) and busIsland(currTP,frB,ild)
                 and branchBusDefn(currTP,br,frB,toB)
                   }, o_branchFlow_TP(dt,br) ] ;

        o_HVDChalfPoleLoss_TP(dt,ild)
            = sum[ (br,frB,toB) $ { HVDChalfPoles(currTP,br) and
                                    branchBusDefn(currTP,br,frB,toB) and
                                    busIsland(currTP,toB,ild) and
                                    busIsland(currTP,frB,ild)
                                      }, o_branchTotalLoss_TP(dt,br)
                 ] ;

        o_HVDCpoleFixedLoss_TP(dt,ild)
            = sum[ (br,frB,toB) $ { HVDCpoles(currTP,br) and
                                    branchBusDefn(currTP,br,frB,toB) and
                                    ( busIsland(currTP,toB,ild) or
                                      busIsland(currTP,frB,ild)
                                    )
                                  }, 0.5 * o_branchFixedLoss_TP(dt,br)
                 ] ;

        o_HVDCloss_TP(dt,ild)
            = o_HVDChalfPoleLoss_TP(dt,ild)
            + o_HVDCpoleFixedLoss_TP(dt,ild)
            + sum[ (br,frB,toB) $ { HVDClink(currTP,br) and
                                    branchBusDefn(currTP,br,frB,toB) and
                                    busIsland(currTP,toB,ild) and
                                    (not (busIsland(currTP,frB,ild)))
                                  }, o_branchDynamicLoss_TP(dt,br)
                 ] ;

* TN - The code below is added for NMIR project ================================
        o_EffectiveRes_TP(dt,ild,resC,riskC) $ reserveShareEnabled(currTP,resC)
            = RESERVESHAREEFFECTIVE.l(currTP,ild,resC,riskC) ;

        If Sum[ resC $ (ord(resC) = 1), reserveShareEnabled(currTP,resC)] then

            o_FirSent_TP(dt,ild)
                = Sum[ (rd,resC) $ (ord(resC) = 1)
                     , RESERVESHARESENT.l(currTP,ild,resC,rd)];

            o_FirReceived_TP(dt,ild)
                = Sum[ (rd,resC) $ (ord(resC) = 1)
                     , RESERVESHARERECEIVED.l(currTP,ild,resC,rd) ];

            o_FirEffective_TP(dt,ild,riskC)
                = Sum[ resC $ (ord(resC) = 1),
                       RESERVESHAREEFFECTIVE.l(currTP,ild,resC,riskC) ];

            o_FirEffReport_TP(dt,ild)
                = Smax[ (resC,riskC) $ (ord(resC)=1)
                     , RESERVESHAREEFFECTIVE.l(currTP,ild,resC,riskC) ];

        Endif;

        If Sum[ resC $ (ord(resC) = 2), reserveShareEnabled(currTP,resC)] then

            o_SirSent_TP(dt,ild)
                = Sum[ (rd,resC) $ (ord(resC) = 2),
                       RESERVESHARESENT.l(currTP,ild,resC,rd) ];

            o_SirReceived_TP(dt,ild)
                = Sum[ (fd,resC) $ (ord(resC) = 2),
                       RESERVESHARERECEIVED.l(currTP,ild,resC,fd) ];

            o_SirEffective_TP(dt,ild,riskC)
                = Sum[ resC $ (ord(resC) = 2),
                       RESERVESHAREEFFECTIVE.l(currTP,ild,resC,riskC) ];

            o_SirEffReport_TP(dt,ild)
                = Smax[ (resC,riskC) $ (ord(resC)=2)
                     , RESERVESHAREEFFECTIVE.l(currTP,ild,resC,riskC) ];
        Endif;


* TN - The code for NMIR project end ===========================================

*       Additional output for audit reporting
        o_ACbusAngle(dt,b) = ACNODEANGLE.l(currTP,b) ;

*       Check if there are non-physical losses on AC branches
        ManualBranchSegmentMWFlow(LossBranch(ACbranch(currTP,br)),los,fd)
                $ { ( ord(los) <= branchLossBlocks(ACbranch) )
                and validLossSegment(ACbranch,los,fd)
                and ( ACBRANCHFLOWDIRECTED.l(ACbranch,fd) > 0 )
                  }
                = Min[ Max( 0,
                            [ abs(o_branchFlow_TP(dt,br))
                            - [LossSegmentMW(ACbranch,los-1,fd) $ (ord(los) > 1)]
                            ]
                          ),
                       ( LossSegmentMW(ACbranch,los,fd)
                       - [LossSegmentMW(ACbranch,los-1,fd) $ (ord(los) > 1)]
                       )
                     ] ;

        ManualBranchSegmentMWFlow(LossBranch(HVDClink(currTP,br)),los,fd)
                $ { ( ord(los) <= branchLossBlocks(HVDClink) )
                and validLossSegment(HVDClink,los,fd) and ( ord(fd) = 1 )
                  }
                = Min[ Max( 0,
                            [ abs(o_branchFlow_TP(dt,br))
                            - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                            ]
                          ),
                       ( LossSegmentMW(HVDClink,los,fd)
                       - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                       )
                     ] ;

        ManualLossCalculation(LossBranch(branch(currTP,br)))
            = sum[ (los,fd), LossSegmentFactor(branch,los,fd)
                           * ManualBranchSegmentMWFlow(branch,los,fd) ] ;

        o_nonPhysicalLoss(dt,br) = o_branchDynamicLoss_TP(dt,br)
                                 - ManualLossCalculation(currTP,br) ;

        o_lossSegmentBreakPoint(dt,br,los)
            = sum [ fd $ { validLossSegment(currTP,br,los,fd)
                       and (ord(fd) = 1)
                         }, LossSegmentMW(currTP,br,los,fd) ] $ { o_branchFlow_TP(dt,br) >= 0 }
            + sum [ fd $ { validLossSegment(currTP,br,los,fd)
                       and (ord(fd) = 2)
                         }, LossSegmentMW(currTP,br,los,fd) ] $ { o_branchFlow_TP(dt,br) < 0 }
        ;

        o_lossSegmentFactor(dt,br,los)
            = sum [ fd $ { validLossSegment(currTP,br,los,fd)
                       and (ord(fd) = 1)
                         }, LossSegmentFactor(currTP,br,los,fd) ] $ { o_branchFlow_TP(dt,br) >= 0 }
            + sum [ fd $ { validLossSegment(currTP,br,los,fd)
                       and (ord(fd) = 2)
                         }, LossSegmentFactor(currTP,br,los,fd) ] $ { o_branchFlow_TP(dt,br) < 0 }
        ;

        o_busIsland_TP(dt,b,ild) $ busIsland(currTP,b,ild) = yes ;

        o_PLRO_FIR_TP(dt,o) $ offer(currTP,o)
            = sum[(resC,PLSRReserveType) $ (ord(resC)=1)
                 , RESERVE.l(currTP,o,resC,PLSRReserveType) ] ;

        o_PLRO_SIR_TP(dt,o) $ offer(currTP,o)
            = sum[(resC,PLSRReserveType) $ (ord(resC)=2)
                 , RESERVE.l(currTP,o,resC,PLSRReserveType)] ;

        o_TWRO_FIR_TP(dt,o) $ offer(currTP,o)
            = sum[(resC,TWDRReserveType) $ (ord(resC)=1)
                 , RESERVE.l(currTP,o,resC,TWDRReserveType)] ;

        o_TWRO_SIR_TP(dt,o) $ offer(currTP,o)
            = sum[(resC,TWDRReserveType) $ (ord(resC)=2)
                 , RESERVE.l(currTP,o,resC,TWDRReserveType)] ;

        o_ILRO_FIR_TP(dt,o) $ offer(currTP,o)
            = sum[ (resC,ILReserveType) $ (ord(resC)=1)
                 , RESERVE.l(currTP,o,resC,ILReserveType)] ;

        o_ILRO_SIR_TP(dt,o) $ offer(currTP,o)
            = sum[ (resC,ILReserveType) $ (ord(resC)=2)
                 , RESERVE.l(currTP,o,resC,ILReserveType)] ;

        o_ILbus_FIR_TP(dt,b) = sum[ (o,n) $ { NodeBus(currTP,n,b) and
                                              offerNode(currTP,o,n)
                                            }, o_ILRO_FIR_TP(dt,o) ] ;

        o_ILbus_SIR_TP(dt,b) = sum[ (o,n) $ { NodeBus(currTP,n,b) and
                                              offerNode(currTP,o,n)
                                            }, o_ILRO_SIR_TP(dt,o) ] ;

        o_marketNodeIsland_TP(dt,o,ild)
            $ sum[ n $ { offerIsland(currTP,o,ild) and
                         offerNode(currTP,o,n) and
                         (o_nodeLoad_TP(dt,n)  = 0)
                       },1
                 ] = yes ;

        o_generationRiskLevel(dt,ild,o,resC,GenRisk)
            = GENISLANDRISK.l(currTP,ild,o,resC,GenRisk)
            + RESERVESHAREEFFECTIVE.l(currTP,ild,resC,GenRisk)
            ;

        o_generationRiskPrice(dt,ild,o,resC,GenRisk)
            = GenIslandRiskCalculation_1.m(currTP,ild,o,resC,GenRisk) ;

        o_HVDCriskLevel(dt,ild,resC,HVDCrisk)
            = ISLANDRISK.l(currTP,ild,resC,HVDCrisk) ;

        o_HVDCriskPrice(dt,ild,resC,HVDCrisk)
            = HVDCIslandRiskCalculation.m(currTP,ild,resC,HVDCrisk) ;

        o_manuRiskLevel(dt,ild,resC,ManualRisk)
            = ISLANDRISK.l(currTP,ild,resC,ManualRisk)
            + RESERVESHAREEFFECTIVE.l(currTP,ild,resC,ManualRisk)
            ;

        o_manuRiskPrice(dt,ild,resC,ManualRisk)
            = ManualIslandRiskCalculation.m(currTP,ild,resC,ManualRisk) ;

        o_genHVDCriskLevel(dt,ild,o,resC,HVDCsecRisk)
            = HVDCGENISLANDRISK.l(currTP,ild,o,resC,HVDCsecRisk) ;

        o_genHVDCriskPrice(dt,ild,o,resC,HVDCsecRisk(riskC))
            = HVDCIslandSecRiskCalculation_GEN_1.m(currTP,ild,o,resC,riskC) ;

        o_manuHVDCriskLevel(dt,ild,resC,HVDCsecRisk)
            = HVDCMANISLANDRISK.l(currTP,ild,resC,HVDCsecRisk);

        o_manuHVDCriskPrice(dt,ild,resC,HVDCsecRisk(riskC))
            = HVDCIslandSecRiskCalculation_Manu_1.m(currTP,ild,resC,riskC) ;

        o_generationRiskGroupLevel(dt,ild,rg,resC,GenRisk)
            $ islandRiskGroup(currTP,ild,rg,GenRisk)
            = GENISLANDRISKGROUP.l(currTP,ild,rg,resC,GenRisk)
            + RESERVESHAREEFFECTIVE.l(currTP,ild,resC,GenRisk)
            ;

        o_generationRiskGroupPrice(dt,ild,rg,resC,GenRisk)
            $ islandRiskGroup(currTP,ild,rg,GenRisk)
            = GenIslandRiskGroupCalculation_1.m(currTP,ild,rg,resC,GenRisk) ;

*       FIR and SIR required based on calculations of the island risk to
*       overcome reporting issues of the risk setter under degenerate
*       conditions when reserve price = 0 - See below

        o_ReserveReqd_TP(dt,ild,resC)
            = Max[ 0,
                   smax[(o,GenRisk)     , o_generationRiskLevel(dt,ild,o,resC,GenRisk)],
                   smax[ HVDCrisk       , o_HVDCriskLevel(dt,ild,resC,HVDCrisk) ] ,
                   smax[ ManualRisk     , o_manuRiskLevel(dt,ild,resC,ManualRisk) ] ,
                   smax[ (o,HVDCsecRisk), o_genHVDCriskLevel(dt,ild,o,resC,HVDCsecRisk) ] ,
                   smax[ HVDCsecRisk    , o_manuHVDCriskLevel(dt,ild,resC,HVDCsecRisk)  ] ,
                   smax[ (rg,GenRisk)   , o_generationRiskGroupLevel(dt,ild,rg,resC,GenRisk)  ]
                 ] ;

        o_FIRreqd_TP(dt,ild) = sum[ resC $ (ord(resC)=1), o_ReserveReqd_TP(dt,ild,resC) ] ;
        o_SIRreqd_TP(dt,ild) = sum[ resC $ (ord(resC)=2), o_ReserveReqd_TP(dt,ild,resC) ] ;

*       Summary reporting by trading period
        o_solveOK_TP(dt) = ModelSolved ;

        o_systemCost_TP(dt) = SYSTEMCOST.l(currTP) ;

        o_systemBenefit_TP(dt) = SYSTEMBENEFIT.l(currTP) ;

        o_penaltyCost_TP(dt) = SYSTEMPENALTYCOST.l(currTP) ;

        o_ofv_TP(dt) = o_systemBenefit_TP(dt)
                     - o_systemCost_TP(dt)
                     - o_penaltyCost_TP(dt);


*       Separete violation reporting at trade period level
        o_defGenViolation_TP(dt) = sum[ b, o_busDeficit_TP(dt,b) ] ;

        o_surpGenViolation_TP(dt) = sum[ b, o_busSurplus_TP(dt,b) ] ;

        o_surpBranchFlow_TP(dt)
            = sum[ br$branch(currTP,br), SURPLUSBRANCHFLOW.l(currTP,br) ] ;

        o_defRampRate_TP(dt)
            = sum[ o $ offer(currTP,o), DEFICITRAMPRATE.l(currTP,o) ] ;

        o_surpRampRate_TP(dt)
            = sum[ o $ offer(currTP,o), SURPLUSRAMPRATE.l(currTP,o) ] ;

        o_surpBranchGroupConst_TP(dt)
            = sum[ brCstr $ branchConstraint(currTP,brCstr)
                 , SURPLUSBRANCHSECURITYCONSTRAINT.l(currTP,brCstr) ] ;

        o_defBranchGroupConst_TP(dt)
            = sum[ brCstr $ branchConstraint(currTP,brCstr)
                 , DEFICITBRANCHSECURITYCONSTRAINT.l(currTP,brCstr) ] ;

        o_defMnodeConst_TP(dt)
            = sum[ MnodeCstr $ MnodeConstraint(currTP,MnodeCstr)
                 , DEFICITMnodeCONSTRAINT.l(currTP,MnodeCstr) ] ;

        o_surpMnodeConst_TP(dt)
            = sum[ MnodeCstr $ MnodeConstraint(currTP,MnodeCstr)
                 , SURPLUSMnodeCONSTRAINT.l(currTP,MnodeCstr) ] ;

        o_defACnodeConst_TP(dt)
            = sum[ ACnodeCstr $ ACnodeConstraint(currTP,ACnodeCstr)
                 , DEFICITACnodeCONSTRAINT.l(currTP,ACnodeCstr) ] ;

        o_surpACnodeConst_TP(dt)
            = sum[ ACnodeCstr $ ACnodeConstraint(currTP,ACnodeCstr)
                 , SURPLUSACnodeCONSTRAINT.l(currTP,ACnodeCstr) ] ;

        o_defT1MixedConst_TP(dt)
            = sum[ t1MixCstr $ Type1MixedConstraint(currTP,t1MixCstr)
                 , DEFICITTYPE1MIXEDCONSTRAINT.l(currTP,t1MixCstr) ] ;

        o_surpT1MixedConst_TP(dt)
            = sum[ t1MixCstr $ Type1MixedConstraint(currTP,t1MixCstr)
                 , SURPLUSTYPE1MIXEDCONSTRAINT.l(currTP,t1MixCstr) ] ;

        o_defGenericConst_TP(dt)
            = sum[ gnrcCstr $ GenericConstraint(currTP,gnrcCstr)
                 , DEFICITGENERICCONSTRAINT.l(currTP,gnrcCstr) ] ;

        o_surpGenericConst_TP(dt)
            = sum[ gnrcCstr $ GenericConstraint(currTP,gnrcCstr)
                 , SURPLUSGENERICCONSTRAINT.l(currTP,gnrcCstr) ] ;

        o_defResv_TP(dt)
            = sum[ (ild,resC) , o_ResViolation_TP(dt,ild,resC) ] ;

        o_totalViolation_TP(dt)
            = o_defGenViolation_TP(dt) + o_surpGenViolation_TP(dt)
            + o_defRampRate_TP(dt) + o_surpRampRate_TP(dt)
            + o_defBranchGroupConst_TP(dt) + o_surpBranchGroupConst_TP(dt)
            + o_defMnodeConst_TP(dt) + o_surpMnodeConst_TP(dt)
            + o_defACnodeConst_TP(dt) + o_surpACnodeConst_TP(dt)
            + o_defT1MixedConst_TP(dt) + o_surpT1MixedConst_TP(dt)
            + o_defGenericConst_TP(dt) + o_surpGenericConst_TP(dt)
            + o_defResv_TP(dt) + o_surpBranchFlow_TP(dt) ;

*       Virtual reserve
        o_vrResMW_TP(dt,ild,resC) = VIRTUALRESERVE.l(currTP,ild,resC) ;

        o_FIRvrMW_TP(dt,ild) = sum[ resC $ (ord(resC) = 1)
                                  , o_vrResMW_TP(dt,ild,resC) ] ;

        o_SIRvrMW_TP(dt,ild) = sum[ resC $ (ord(resC) = 2)
                                  , o_vrResMW_TP(dt,ild,resC) ] ;

*   Reporting at trading period end
    EndLoop;
$offend

$endif.PeriodReport

* End of the solve vSPD loop
  ] ;
* End of the While loop
);


*   Summary reports - only applied for normal and audit vSPD run.
$iftheni.SummaryReport %opMode%=='DWH' display 'No summary report for data warehouse mode';
$elseifi.SummaryReport %opMode%=='FTR' display 'No summary report for FTR rental mode';
$elseifi.SummaryReport %opMode%=='PVT' display 'No summary report for pivot analysis mode';
$elseifi.SummaryReport %opMode%=='DPS' display 'No summary report for demand analysis mode';
$else.SummaryReport

*   System level
    o_numTradePeriods = card(tp) ;

    o_systemOFV = sum[ dt, o_ofv_TP(dt) ] ;

    o_systemGen = sum[ (dt,ild), o_islandGen_TP(dt,ild) ] ;

    o_systemLoad = sum[ (dt,ild), o_islandLoad_TP(dt,ild)
                                - o_islandClrBid_TP(dt,ild) ] ;

    o_systemLoss = sum[ (dt,ild), o_islandBranchLoss_TP(dt,ild)
                                + o_HVDCloss_TP(dt,ild) ] ;

    o_systemViolation = sum[ dt, o_totalViolation_TP(dt) ] ;

    o_systemFIR = sum[ (dt,ild), o_FIRcleared_TP(dt,ild) ] ;

    o_systemSIR = sum[ (dt,ild), o_SIRcleared_TP(dt,ild) ] ;


*   Offer level - This does not include revenue from wind generators for
*   final pricing because the wind generation is netted off against load
*   at the particular bus for the final pricing solves

    o_offerTrader(o,trdr)
        $ sum[ tp $ i_tradePeriodOfferTrader(tp,o,trdr), 1 ] = yes ;

    o_offerGen(o) = (i_tradingPeriodLength/60)*sum[dt, o_offerEnergy_TP(dt,o)] ;

    o_offerFIR(o) = (i_tradingPeriodLength/60)*sum[dt, o_offerFIR_TP(dt,o)] ;

    o_offerSIR(o) = (i_tradingPeriodLength/60)*sum[dt, o_offerSIR_TP(dt,o)] ;

$endif.SummaryReport


*=====================================================================================
* 8. vSPD scarcity pricing post-processing
*=====================================================================================
$iftheni.vSPDscarcity %opMode%=='PVT' display 'Scacity pricing not applied for pivot analysis';
$elseifi.vSPDscarcity %opMode%=='DPS' display 'Scacity pricing not applied for demand analysis';
$else.vSPDscarcity

* Mapping scarcity area to islands
scarcityAreaIslandMap(sarea,ild)      = no ;
scarcityAreaIslandMap('NI','NI')      = yes ;
scarcityAreaIslandMap('SI','SI')      = yes ;
scarcityAreaIslandMap('National',ild) = yes ;

$ifthen.ScarcityExists %scarcityExists%==1

* 8a. Check if scarcity pricing situation is applied --------------------------
putclose runlog 'Scarcity situation exists. ';

$gdxin "%inputPath%\%vSPDinputData%.gdx"
$load i_tradePeriodScarcitySituationExists i_tradePeriodGWAPFloor
$load i_tradePeriodGWAPCeiling i_tradePeriodGWAPThreshold
$load i_tradePeriodGWAPCountForAvg i_tradePeriodGWAPPastDaysAvg
$gdxin

* No of island cumulative price thresholds required for each scarcity area
cptIslandReq(sarea) = sum(ild $ scarcityAreaIslandMap(sarea,ild),1) ;

* Loading data that are imported from gdx input file
GWAPFloor(tp,sarea)         = i_tradePeriodGWAPFloor(tp,sarea) ;
GWAPCeiling(tp,sarea)       = i_tradePeriodGWAPCeiling(tp,sarea) ;
GWAPPastDaysAvg(tp,ild)     = i_tradePeriodGWAPPastDaysAvg(tp,ild) ;
GWAPCountForAvg(tp,ild)     = i_tradePeriodGWAPCountForAvg(tp,ild) ;
GWAPThreshold(tp,ild)       = i_tradePeriodGWAPThreshold(tp,ild) ;
scarcitySituation(tp,sarea) = i_tradePeriodScarcitySituationExists(tp,sarea) ;

* Load the past days price x quantity (PQ)
pastGWAPsumforCPT(tp,ild) = GWAPPastDaysAvg(tp,ild) * GWAPCountForAvg(tp,ild) ;

* Load trading period count for the calculation of the past days GWAP
pastTPcntforCPT(tp,ild) = GWAPCountForAvg(tp,ild) ;

* Initialise the parameters to be used to update the average prior GWAP
currentDayGWAPsumforCPT(ild) = 0 ;
currentDayTPsumforCPT(ild) = 0 ;

* The following loop going through each trading period to
* check if a scarcity pricing situation applied and
* calculate the last 7 days GWAP for the CPT check - The Code Clause 13.135C
loop[ i_dateTimeTradePeriodMap(dt,tp),

*   Recalculate the past GWAP and count with the current day to update
*   the average prior GWAP calculation
    pastGWAPsumforCPT(tp,ild) = pastGWAPsumforCPT(tp,ild)
                              + currentDayGWAPsumforCPT(ild) ;

    pastTPcntforCPT(tp,ild) = pastTPcntforCPT(tp,ild)
                            + currentDayTPsumforCPT(ild) ;

*   Calculate the average prior GWAP for each island
    avgPriorGWAP(tp,ild) $ (pastTPcntforCPT(tp,ild) = 336)
        = pastGWAPsumforCPT(tp,ild) / pastTPcntforCPT(tp,ild) ;

*   Calculate the island and any scarcity area GWAP - (6.3.3)
    islandGWAP(tp,ild)
        = sum[ n $ nodeIsland(tp,n,ild)
             , o_nodeGeneration_TP(dt,n) * o_nodePrice_TP(dt,n) ]
        / sum[ n $ nodeIsland(tp,n,ild), o_nodeGeneration_TP(dt,n)] ;

    scarcityAreaGWAP(tp,sarea) $ scarcitySituation(tp,sarea)
       = sum[ nodeIsland(tp,n,ild) $ scarcityAreaIslandMap(sarea,ild)
             , o_nodeGeneration_TP(dt,n) * o_nodePrice_TP(dt,n)
            ]
       / sum[ nodeIsland(tp,n,ild) $ scarcityAreaIslandMap(sarea,ild)
            , o_nodeGeneration_TP(dt,n)
            ] ;


    loop[ sarea $ scarcitySituation(tp,sarea),

*       Cumulative price threshold (CPT) check
        cptIslandPassed(tp,sarea)
            = sum[ scarcityAreaIslandMap(sarea,ild)
                $ (avgPriorGWAP(tp,ild) <= GWAPThreshold(tp,ild)), 1
                 ] ;

*       Check of the required CPT thresholds are met
        cptPassed(tp,sarea)
            $ (cptIslandPassed(tp,sarea) = cptIslandReq(sarea)) = 1;

*       Scaling factor calculation (6.3.4) - If CPT is passed then if:
*         a. scarcity area GWAP < floor then scale prices up
*         b. scarcity area GWAP > ceiling then scale prices down
*         c. scarcity area GWAP >= floor and GWAP <= ceiling scaling factor = 1
        if( cptPassed(tp,sarea) = 1,

            scarcityScalingFactor(tp,sarea)
                $ { scarcityAreaGWAP(tp,sarea) < GWAPFloor(tp,sarea) }
                = GWAPFloor(tp,sarea) / scarcityAreaGWAP(tp,sarea) ;

            scarcityScalingFactor(tp,sarea)
                $ { scarcityAreaGWAP(tp,sarea) > GWAPCeiling(tp,sarea) }
                = GWAPCeiling(tp,sarea) / scarcityAreaGWAP(tp,sarea) ;

            scarcityScalingFactor(tp,sarea)
                $ { (scarcityAreaGWAP(tp,sarea) >= GWAPFloor(tp,sarea)) and
                    (scarcityAreaGWAP(tp,sarea) <= GWAPCeiling(tp,sarea))
                  } = 1 ;

*           Scale the bus prices and reserve prices in the scarcity area
            scaledbusPrice(tp,b)
                $ sum[ busIsland(bus(tp,b),ild)
                      $ scarcityAreaIslandMap(sarea,ild), 1
                     ] = scarcityScalingFactor(tp,sarea) * o_busPrice_TP(dt,b) ;

            scaledFIRprice(tp,ild) $ scarcityAreaIslandMap(sarea,ild)
                = scarcityScalingFactor(tp,sarea) * o_FIRprice_TP(dt,ild) ;

            scaledSIRprice(tp,ild) $ scarcityAreaIslandMap(sarea,ild)
                = scarcityScalingFactor(tp,sarea) * o_SIRprice_TP(dt,ild) ;

*           Allocate the scaled bus energy, FIR and SIR prices
            o_busPrice_TP(dt,b) $ sum[ busIsland(bus(tp,b),ild)
                                     $ scarcityAreaIslandMap(sarea,ild), 1
                                     ] = scaledbusPrice(tp,b) ;

            o_FIRprice_TP(dt,ild) $ scarcityAreaIslandMap(sarea,ild)
                                  = scaledFIRprice(tp,ild) ;

            o_SIRprice_TP(dt,ild) $ scarcityAreaIslandMap(sarea,ild)
                                  = scaledSIRprice(tp,ild) ;

            o_ResPrice_TP(dt,ild,resC) $ (ord(resC)=1) = o_FIRprice_TP(dt,ild);
            o_ResPrice_TP(dt,ild,resC) $ (ord(resC)=2) = o_SIRprice_TP(dt,ild);

*           Update node price with scaling factor
            scalednodePrice(tp,n)
                = sum[ nodeBus(node(tp,n),b)
                     , NodeBusAllocationFactor(tp,n,b) * o_busPrice_TP(dt,b) ] ;

           scaledislandGWAP(tp,ild) $ scarcityAreaIslandMap(sarea,ild)
                = sum[ nodeIsland(tp,n,ild), o_nodeGeneration_TP(dt,n)
                                           * scalednodePrice(tp,n) ]
                / sum[ nodeIsland(tp,n,ild), o_nodeGeneration_TP(dt,n) ] ;

            scaledscarcityAreaGWAP(tp,sarea) $ scarcitySituation(tp,sarea)
                = sum[ nodeIsland(tp,n,ild)
                     $ scarcityAreaIslandMap(sarea,ild)
                     , o_nodeGeneration_TP(dt,n) * scalednodePrice(tp,n)
                     ]
                / sum[ nodeIsland(tp,n,ild)
                     $ scarcityAreaIslandMap(sarea,ild)
                     , o_nodeGeneration_TP(dt,n)
                     ] ;

*           Update the node price used for the GWAP calculation for the CPT
            o_nodePrice_TP(dt,n) = scalednodePrice(tp,n) ;

*       End Scaling factor calculation (6.3.4) if CPT is passed
        ) ;

*   End of scarcity check loop
    ] ;


*   Calculate the GWAP for the current trade period in each island
    currentDayGWAPsumforCPT(ild) = currentDayGWAPsumforCPT(ild)
                                 + scaledislandGWAP(tp,ild) ;

    currentDayTPsumforCPT(ild) = currentDayTPsumforCPT(ild) + 1 ;

* End of trade period loop
] ;

*   Scarcity pricing situation application check end
$endif.ScarcityExists


* 8b. Calculating price-relating outputs --------------------------------------

$iftheni.PriceRelatedOutputs %opMode%=='DWH'
$elseifi.PriceRelatedOutputs %opMode%=='FTR' $include "FTRental\vSPDSolveFTR_3a.gms"
$else.PriceRelatedOutputs
loop(i_dateTimeTradePeriodMap(dt,tp),

*   bus output update
    o_busRevenue_TP(dt,b) $ bus(tp,b) = (i_tradingPeriodLength / 60)
                                      * o_busGeneration_TP(dt,b)
                                      * o_busPrice_TP(dt,b) ;

    o_busCost_TP(dt,b) $ bus(tp,b) = (i_tradingPeriodLength / 60)
                                   * o_busLoad_TP(dt,b)
                                   * o_busPrice_TP(dt,b);

*   node output update
    o_nodeRevenue_TP(dt,n) $ node(tp,n) = (i_tradingPeriodLength / 60)
                                        * o_nodeGeneration_TP(dt,n)
                                        * o_nodePrice_TP(dt,n) ;

    o_nodeCost_TP(dt,n) $ node(tp,n) = (i_tradingPeriodLength / 60)
                                     * o_nodeLoad_TP(dt,n)
                                     * o_nodePrice_TP(dt,n) ;

*   branch output update
    o_branchFromBusPrice_TP(dt,br) $ branch(tp,br)
        = sum[ b $ o_branchFromBus_TP(dt,br,b), o_busPrice_TP(dt,b) ] ;

    o_branchToBusPrice_TP(dt,br) $ branch(tp,br)
        = sum[ b $ o_branchToBus_TP(dt,br,b), o_busPrice_TP(dt,b) ] ;

    o_branchTotalRentals_TP(dt,br)
        $ { branch(tp,br) and (o_branchFlow_TP(dt,br) >= 0) }
        = (i_tradingPeriodLength/60)
        * [ o_branchToBusPrice_TP(dt,br)   * o_branchFlow_TP(dt,br)
          - o_branchToBusPrice_TP(dt,br)   * o_branchTotalLoss_TP(dt,br)
          - o_branchFromBusPrice_TP(dt,br) * o_branchFlow_TP(dt,br)
          ] ;

    o_branchTotalRentals_TP(dt,br)
        $ { branch(tp,br) and (o_branchFlow_TP(dt,br) < 0) }
        = (i_tradingPeriodLength/60)
        * [ o_branchToBusPrice_TP(dt,br)   * o_branchFlow_TP(dt,br)
          - o_branchFromBusPrice_TP(dt,br) * o_branchFlow_TP(dt,br)
          - o_branchFromBusPrice_TP(dt,br) * o_branchTotalLoss_TP(dt,br)
          ] ;

*   Island output
    o_islandRefPrice_TP(dt,ild)
        = sum[ n $ { referenceNode(tp,n)
                 and nodeIsland(tp,n,ild) } , o_nodePrice_TP(dt,n) ] ;

    o_islandEnergyRevenue_TP(dt,ild)
        = sum[ n $ nodeIsland(tp,n,ild), o_nodeRevenue_TP(dt,n)] ;

    o_islandReserveRevenue_TP(dt,ild) = sum[ resC, o_ResCleared_TP(dt,ild,resC)
                                                 * o_ResPrice_TP(dt,ild,resC)
                                                 * i_tradingPeriodLength/60 ];

    o_islandLoadCost_TP(dt,ild)
        = sum[ n $ { nodeIsland(tp,n,ild) and (o_nodeLoad_TP(dt,n) >= 0) }
             , o_nodeCost_TP(dt,n) ] ;

    o_islandLoadRevenue_TP(dt,ild)
        = sum[ n $ { nodeIsland(tp,n,ild) and (o_nodeLoad_TP(dt,n) < 0) }
             , - o_nodeCost_TP(dt,n) ] ;

$ifthen.ScarcityOutput %scarcityExists%==1

    o_scarcityExists_TP(dt,ild)
        = sum[ scarcityAreaIslandMap(sarea,ild), scarcitySituation(tp,sarea) ];

    o_cptPassed_TP(dt,ild) $ sum[ scarcityAreaIslandMap(sarea,ild)
                                , cptPassed(tp,sarea) ] = 1 ;

    o_avgPriorGWAP_TP(dt,ild) = avgPriorGWAP(tp,ild) ;

    o_islandGWAPbefore_TP(dt,ild) = islandGWAP(tp,ild) ;

    o_islandGWAPafter_TP(dt,ild) = scaledislandGWAP(tp,ild) ;

    o_scarcityGWAPbefore_TP(dt,ild)
        = sum[ scarcityAreaIslandMap(sarea,ild), scarcityAreaGWAP(tp,sarea) ] ;

    o_scarcityGWAPafter_TP(dt,ild) = sum[ scarcityAreaIslandMap(sarea,ild)
                                        , scaledscarcityAreaGWAP(tp,sarea)];

    o_scarcityScalingFactor_TP(dt,ild) = sum[ scarcityAreaIslandMap(sarea,ild)
                                            , scarcityScalingFactor(tp,sarea) ] ;

    o_GWAPfloor_TP(dt,ild) = sum[ scarcityAreaIslandMap(sarea,ild)
                                $ (scarcitySituation(tp,sarea) = 1)
                                , GWAPFloor(tp,sarea) ] ;

    o_GWAPceiling_TP(dt,ild) = sum[ scarcityAreaIslandMap(sarea,ild)
                                  $ (scarcitySituation(tp,sarea) = 1)
                                  , GWAPCeiling(tp,sarea) ] ;

    o_GWAPthreshold_TP(dt,ild) $ o_scarcityExists_TP(dt,ild)
                                   = GWAPThreshold(tp,ild) ;

$endif.ScarcityOutput
) ;

* System level
o_systemEnergyRevenue  = sum[ (dt,ild), o_islandEnergyRevenue_TP(dt,ild) ] ;

o_systemReserveRevenue = sum[ (dt,ild), o_islandReserveRevenue_TP(dt,ild) ];

o_systemLoadCost       = sum[ (dt,ild), o_islandLoadCost_TP(dt,ild) ];

o_systemLoadRevenue    = sum[ (dt,ild), o_islandLoadRevenue_TP(dt,ild) ];

* Offer level
o_offerGenRevenue(o)
    = sum[ (dt,tp,n) $ { i_dateTimeTradePeriodMap(dt,tp) and offerNode(tp,o,n) }
         , (i_tradingPeriodLength/60)
         * o_offerEnergy_TP(dt,o) * o_nodePrice_TP(dt,n) ] ;

o_offerFIRrevenue(o)
    = sum[ (dt,tp,n,ild) $ { i_dateTimeTradePeriodMap(dt,tp) and
                             offerNode(tp,o,n) and nodeIsland(tp,n,ild)}
         , (i_tradingPeriodLength/60)
         * o_offerFIR_TP(dt,o) * o_FIRprice_TP(dt,ild) ] ;

o_offerSIRrevenue(o)
   = sum[ (dt,tp,n,ild) $ { i_dateTimeTradePeriodMap(dt,tp) and
                             offerNode(tp,o,n) and nodeIsland(tp,n,ild)}
         , (i_tradingPeriodLength/60)
         * o_offerSIR_TP(dt,o) * o_SIRprice_TP(dt,ild) ] ;

$endif.PriceRelatedOutputs
*   Calculating price-relating outputs end -------------------------------------


$endif.vSPDscarcity

*=====================================================================================
* 9. Write results to CSV report files and GDX files
*=====================================================================================
* TN - Pivot analysis end
$iftheni.Output %opMode%=='PVT' $include "Pivot\vSPDSolvePivot_4.gms"
$elseifi.Output %opMode%=='DPS' $include "Demand\vSPDSolveDPS_4.gms"
$elseifi.Output %opMode%=='FTR' $include "FTRental\vSPDSolveFTR_4.gms"
$elseifi.Output %opMode%=='DWH' $include "DWmode\vSPDSolveDWH_4.gms"
$else.Output                   $include "vSPDreport.gms"
$endif.Output


* Post a progress message for use by EMI.
putclose runlog 'Case: %vSPDinputData% is complete in ',timeExec,'(secs)'/ ;
putclose runlog 'Case: %vSPDinputData% is finished in ',timeElapsed,'(secs)'/ ;

* Go to the next input file
$label nextInput

* Post a progress message for use by EMI.
$if not exist "%inputPath%\%vSPDinputData%.gdx" putclose runlog 'The file %inputPath%\%vSPDinputData%.gdx could not be found (', system.time, ').' // ;
