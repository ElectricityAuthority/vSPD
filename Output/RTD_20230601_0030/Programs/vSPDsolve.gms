$onText
*=====================================================================================
Name:                 vSPDsolve.gms
Function:             Establish base case and override data, prepare data, and solve the model
Developed by:         Electricity Authority, New Zealand
Source:               https://github.com/ElectricityAuthority/vSPD
                      http://www.emi.ea.govt.nz/Tools/vSPD
Contact:              Forum: http://www.emi.ea.govt.nz/forum/
                      Email: emi@ea.govt.nz
Created on:           1st November 2022 for Real Time Pricing

*=====================================================================================

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
$offText

*=====================================================================================
* 0. Initial setup
*=====================================================================================

* Include paths, settings and case name files
$include Intervals.inc 
$include vSPDsettings.inc
$include vSPDcase.inc

* Update the ProgressReport.txt file
File rep "Write to a report" /"ProgressReport.txt"/;  rep.lw = 0;  rep.ap = 1;
putclose rep / 'Case "%GDXname%" started at: ' system.date " " system.time /;

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

* Declare a temporary file
File temp ;

* Allow empty data set declaration
$onempty

*=====================================================================================
* 1. Declare symbols and initialise some of them
*=====================================================================================

Sets
  unsolvedDT(ca,dt)                                  'Set of datetime that are not solved yet'
  SOS1_solve(ca,dt)                                  'Flag period that is resolved using SOS1'

* Unmmaped bus defificit temporary sets
  unmappedDeficitBus(ca,dt,b)                        'List of buses that have deficit generation (price) and are not mapped to any pnode - revisit'
  changedDeficitBus(ca,dt,b)                         'List of buses that have deficit generation added from unmapped deficit bus - revisit'
  ;

Parameters
* Flag to apply corresponding vSPD model
  VSPDModel(ca,dt)                                       '0=VSPD, 1=vSPD_BranchFlowMIP, 2=VSPD (last solve)'

* MIP logic
  circularBranchFlowExist(ca,dt,br)                      'Flag to indicate if circulating branch flows exist on each branch: 1 = Yes'
  poleCircularBranchFlowExist(ca,dt,pole)                'Flag to indicate if circulating branch flows exist on each an HVDC pole: 1 = Yes'

* Calculated parameter used to check if non-physical loss occurs on HVDC
  northHVDC(ca,dt)                                       'HVDC MW sent from from SI to NI'
  southHVDC(ca,dt)                                       'HVDC MW sent from from NI to SI'
  nonPhysicalLossExist(ca,dt,br)                         'Flag to indicate if non-physical losses exist on branch (applied to HVDC only): 1 = Yes'
  manualBranchSegmentMWFlow(ca,dt,br,los,fd)             'Manual calculation of the branch loss segment MW flow --> used to manually calculate hvdc branch losses'
  manualLossCalculation(ca,dt,br)                        'MW losses calculated manually from the solution for each loss branch'

* Calculated parameter used to check if circular branch flow exists on each HVDC pole
  TotalHVDCpoleFlow(ca,dt,pole)                          'Total flow on an HVDC pole'
  MaxHVDCpoleFlow(ca,dt,pole)                            'Maximum flow on an HVDC pole'

* Disconnected bus post-processing
  busGeneration(ca,dt,b)                                 'MW generation at each bus for the study trade periods'
  busLoad(ca,dt,b)                                       'MW load at each bus for the study trade periods'
  busPrice(ca,dt,b)                                      '$/MW price at each bus for the study trade periods'
  busDisconnected(ca,dt,b)                               'Indication if bus is disconnected or not (1 = Yes) for the study trade periods'
* Unmmaped bus defificit temporary parameters
  temp_busDeficit_TP(ca,dt,b)                             'Bus deficit violation for each trade period'
* TN - Replacing invalid prices after SOS1
  busSOSinvalid(ca,dt,b)                                 'Buses with invalid bus prices after SOS1 solve'
  numberofbusSOSinvalid(ca,dt)                           'Number of buses with invalid bus prices after SOS1 solve --> used to check if invalid prices can be improved (numberofbusSOSinvalid reduces after each iteration)'
* System loss calculated by SPD for RTD run
  SPDLoadCalcLosses(ca,dt,isl)                           'Island losses calculated by SPD in the first solve to adjust demand'
 ;

* Extra sets and parameters used for energy shortfall check
Set nodeTonode(ca,dt,n,n1)                      'Temporary set to transfer deficit MW' ;

Parameters
  EnergyShortFallCheck(ca,dt,n)                 'Flag to indicate if energy shortfall at a node is checked (1 = Yes)'
  EligibleShortfallRemoval(ca,dt,n)             'Flag to indicate if energy shortfall at a node is eligible fro removal (1 = Yes)'
  PotentialModellingInconsistency(ca,dt,n)      'Flag to indicate if there is a potential for modelling inconsistency (1 = Yes)'
  IsNodeDead(ca,dt,n)                           'Flag to indicate if a node is dead (1 = Yes)'
  DidShortfallTransfer(ca,dt,n)                 'Flag to indicate if a node shortfall is transferred from to (1 = Yes)'
  CheckedNodeCandidate(ca,dt,n)                 'Flag to indicate if a target node has been checked for shortage transfer(1 = Yes)'
  ShortfallTransferFromTo(ca,dt,n,n1)           'Flag to indicate if shortfall from node n is transfered to node n1(1 = Yes)'
  ShortfallDisabledScaling(ca,dt,n)             'Flag to prevent the RTD Required Load calculation from scaling InitialLoad(1=Yes)'
  NodeElectricalIsland(ca,dt,n)                 'Calculated the ElectricalIsland of a node'

  EnergyShortfallMW(ca,dt,n)                    'Quantity of energy shortfall at a node'
  ShortfallAdjustmentMW(ca,dt,n)                'Quantity of energy transfered from a node where energy shortfall occurs'
  UntransferedShortfallMW(ca,dt,n)              'Quantity of energy shortage not yet transfered to an eligible target node'
  LoopCount(ca,dt)                              'Applied to RTD to limit number of times that the Energy Shortfall Check will re-solve the model'
  ;


Parameters
* Dispatch results for reporting - Trade period level - Island output
  o_islandGen_TP(ca,dt,isl)                              'Island MW generation for the different time periods'
  o_islandLoad_TP(ca,dt,isl)                             'Island MW fixed load for the different time periods'
  o_islandClrBid_TP(ca,dt,isl)                           'Island cleared MW bid for the different time periods'
  o_islandBranchLoss_TP(ca,dt,isl)                       'Intra-island branch losses for the different time periods (MW)'
  o_islandRefPrice_TP(ca,dt,isl)                         'Reference prices in each island ($/MWh)'

  o_HVDCflow_TP(ca,dt,isl)                               'HVDC flow from each island (MW)'
  o_HVDCloss_TP(ca,dt,isl)                               'HVDC losses (MW)'
  o_HVDCpoleFixedLoss_TP(ca,dt,isl)                      'Fixed loss on inter-island HVDC (MW)'
  o_HVDCreceived(ca,dt,isl)                              'Energy Recevied from HVDC into an island'
  o_HVDCRiskSubtractor(ca,dt,isl,resC,riskC)             'OutPut HVDC risk subtractor'

  o_busGeneration_TP(ca,dt,b)                            'Output MW generation at each bus for the different time periods'
  o_busLoad_TP(ca,dt,b)                                  'Output MW load at each bus for the different time periods'
  o_busPrice_TP(ca,dt,b)                                 'Output $/MW price at each bus for the different time periods'
  o_busDeficit_TP(ca,dt,b)                               'Bus deficit violation for each trade period'
  o_busSurplus_TP(ca,dt,b)                               'Bus surplus violation for each trade period'

  o_branchFromBusPrice_TP(ca,dt,br)                      'Output from bus price ($/MW) for branch reporting'
  o_branchToBusPrice_TP(ca,dt,br)                        'Output to bus price ($/MW) for branch reporting'
  o_branchMarginalPrice_TP(ca,dt,br)                     'Output marginal branch constraint price ($/MW) for branch reporting'
  o_branchFlow_TP(ca,dt,br)                              'Output MW flow on each branch for the different time periods'
  o_branchDynamicLoss_TP(ca,dt,br)                       'Output MW dynamic loss on each branch for the different time periods'
  o_branchTotalLoss_TP(ca,dt,br)                         'Output MW total loss on each branch for the different time periods'
  o_branchFixedLoss_TP(ca,dt,br)                         'Output MW fixed loss on each branch for the different time periods'
  o_branchTotalRentals_TP(ca,dt,br)                      'Output $ rentals on transmission branches using total (dynamic + fixed) for the different time periods'
  o_branchCapacity_TP(ca,dt,br)                          'Output MW branch capacity for branch reporting'

  o_ACbranchTotalRentals(ca,dt)                          'FTR rental - Total AC rental by trading period'
  o_ACbranchLossMW(ca,dt,br,los)                         'FTR rental - MW element of the loss segment curve in MW'
  o_ACbranchLossFactor(ca,dt,br,los)                     'FTR rental Loss factor element of the loss segment curve applied to'

  o_offerEnergy_TP(ca,dt,o)                              'Output MW cleared for each energy offer for each trade period'
  o_offerRes_TP(ca,dt,o,resC)                            'Output MW cleared for each reserve offer for each trade period'
  o_offerFIR_TP(ca,dt,o)                                 'Output MW cleared for FIR for each trade period'
  o_offerSIR_TP(ca,dt,o)                                 'Output MW cleared for SIR for each trade period'

  o_groupEnergy_TP(ca,dt,rg,riskC)                       'Output MW cleared for risk group for each trade period'
  o_groupFKband_TP(ca,dt,rg,riskC)                       'Output FK band MW applied for risk group for each trade period'
  o_groupRes_TP(ca,dt,rg,resC,riskC)                     'Output reserve MW cleared for risk group for each trade period'

  o_bidEnergy_TP(ca,dt,bd)                               'Output MW cleared for each energy bid for each trade period'
  o_bidTotalMW_TP(ca,dt,bd)                              'Output total MW bidded for each energy bid for each trade period'

  o_ReserveReqd_TP(ca,dt,isl,resC)                       'Output MW required for each reserve class in each trade period'
  o_FIRreqd_TP(ca,dt,isl)                                'Output MW required FIR for each trade period'
  o_SIRreqd_TP(ca,dt,isl)                                'Output MW required SIR for each trade period'
  o_ResCleared_TP(ca,dt,isl,resC)                        'Reserve cleared from an island for each trade period'
  o_FIRcleared_TP(ca,dt,isl)                             'Output - total FIR cleared by island'
  o_SIRcleared_TP(ca,dt,isl)                             'Output - total SIR cleared by island'
  o_ResPrice_TP(ca,dt,isl,resC)                          'Output $/MW price for each reserve classes for each trade period'
  o_FIRprice_TP(ca,dt,isl)                               'Output $/MW price for FIR reserve classes for each trade period'
  o_SIRprice_TP(ca,dt,isl)                               'Output $/MW price for SIR reserve classes for each trade period'

  o_GenRiskPrice_TP(ca,dt,isl,o,resC,riskC)              'Output Gen risk marginal prices'
  o_HVDCSecRiskPrice_TP(ca,dt,isl,o,resC,riskC)          'Output HVDC risk marginal prices'
  o_GenRiskGroupPrice_TP(ca,dt,isl,rg,resC,riskC)        'Output risk group marginal prices'
  o_HVDCRiskPrice_TP(ca,dt,isl,resC,riskC)               'Output HVDC risk marginal prices'
  o_ManualRiskPrice_TP(ca,dt,isl,resC,riskC)             'Output Manual risk marginal prices'
  o_HVDCSecManualRiskPrice_TP(ca,dt,isl,resC,riskC)      'Output HVDC risk marginal prices'

  o_GenRiskShortfall_TP(ca,dt,isl,o,resC,riskC)          'Output Gen risk shortfall'
  o_HVDCSecRiskShortfall_TP(ca,dt,isl,o,resC,riskC)      'Output HVDC risk shortfall'
  o_GenRiskGroupShortfall_TP(ca,dt,isl,rg,resC,riskC)    'Output risk group shortfall'
  o_HVDCRiskShortfall_TP(ca,dt,isl,resC,riskC)           'Output HVDC risk shortfall'
  o_ManualRiskShortfall_TP(ca,dt,isl,resC,riskC)         'Output Manual risk shortfall'
  o_HVDCSecManualRiskShortfall_TP(ca,dt,isl,resC,riskC)  'Output HVDC risk shortfall'

  o_ResViolation_TP(ca,dt,isl,resC)                      'Violation MW for each reserve classes for each trade period'
  o_FIRviolation_TP(ca,dt,isl)                           'Violation MW for FIR reserve classes for each trade period'
  o_SIRviolation_TP(ca,dt,isl)                           'Violation MW for SIR reserve classes for each trade period'

  o_nodeGeneration_TP(ca,dt,n)                           'Ouput MW generation at each node for the different time periods'
  o_nodeLoad_TP(ca,dt,n)                                 'Ouput MW load at each node for the different time periods'
  o_nodePrice_TP(ca,dt,n)                                'Output $/MW price at each node for the different time periods'
  o_nodeDeficit_TP(ca,dt,n)                              'Output node deficit violation for each trade period'
  o_nodeSurplus_TP(ca,dt,n)                              'Output node surplus violation for each trade period'
  o_nodeDead_TP(ca,dt,n)                                 'Define if a Node  (Pnode) is dead'
  o_nodeDeadPrice_TP(ca,dt,n)                            'Flag to check if a dead Node has valid price'
  o_nodeDeadPriceFrom_TP(ca,dt,n,n1)                     'Flag to show which price node the price of the dead node come from'
* Security constraint data
  o_brConstraintSense_TP(ca,dt,brCstr)                   'Branch constraint sense for each output report'
  o_brConstraintLHS_TP(ca,dt,brCstr)                     'Branch constraint LHS for each output report'
  o_brConstraintRHS_TP(ca,dt,brCstr)                     'Branch constraint RHS for each output report'
  o_brConstraintPrice_TP(ca,dt,brCstr)                   'Branch constraint price for each output report'
* Mnode constraint data
  o_MnodeConstraintSense_TP(ca,dt,MnodeCstr)             'Market node constraint sense for each output report'
  o_MnodeConstraintLHS_TP(ca,dt,MnodeCstr)               'Market node constraint LHS for each output report'
  o_MnodeConstraintRHS_TP(ca,dt,MnodeCstr)               'Market node constraint RHS for each output report'
  o_MnodeConstraintPrice_TP(ca,dt,MnodeCstr)             'Market node constraint price for each output report'
* TradePeriod summary report
  o_solveOK_TP(ca,dt)                                    'Solve status for summary report (1=OK)'
  o_systemCost_TP(ca,dt)                                 'System cost for summary report'
  o_systemBenefit_TP(ca,dt)                              'System benefit of cleared bids for summary report'
  o_ofv_TP(ca,dt)                                        'Objective function value for summary report'
  o_penaltyCost_TP(ca,dt)                                'Penalty cost for summary report'
  o_defGenViolation_TP(ca,dt)                            'Deficit generation violation for summary report'
  o_surpGenViolation_TP(ca,dt)                           'Surplus generaiton violation for summary report'
  o_surpBranchFlow_TP(ca,dt)                             'Surplus branch flow violation for summary report'
  o_defRampRate_TP(ca,dt)                                'Deficit ramp rate violation for summary report'
  o_surpRampRate_TP(ca,dt)                               'Surplus ramp rate violation for summary report'
  o_surpBranchGroupConst_TP(ca,dt)                       'Surplus branch group constraint violation for summary report'
  o_defBranchGroupConst_TP(ca,dt)                        'Deficit branch group constraint violation for summary report'
  o_defMnodeConst_TP(ca,dt)                              'Deficit market node constraint violation for summary report'
  o_surpMnodeConst_TP(ca,dt)                             'Surplus market node constraint violation for summary report'
  o_defResv_TP(ca,dt)                                    'Deficit reserve violation for summary report'

* Factor to prorate the deficit and surplus at the nodal level
  totalBusAllocation(ca,dt,b)                            'Total allocation of nodes to bus'
  busNodeAllocationFactor(ca,dt,b,n)                     'Bus to node allocation factor'

* Audit - extra output declaration
  o_lossSegmentBreakPoint(ca,dt,br,los)                            'Audit - loss segment MW'
  o_lossSegmentFactor(ca,dt,br,los)                                'Audit - loss factor of each loss segment'
  o_ACbusAngle(ca,dt,b)                                            'Audit - bus voltage angle'
  o_nonPhysicalLoss(ca,dt,br)                                      'Audit - non physical loss'

  o_ILRO_FIR_TP(ca,dt,o)                                           'Audit - ILRO FIR offer cleared (MWh)'
  o_ILRO_SIR_TP(ca,dt,o)                                           'Audit - ILRO SIR offer cleared (MWh)'
  o_ILbus_FIR_TP(ca,dt,b)                                          'Audit - ILRO FIR cleared at bus (MWh)'
  o_ILbus_SIR_TP(ca,dt,b)                                          'Audit - ILRO SIR cleared at bus (MWh)'
  o_PLRO_FIR_TP(ca,dt,o)                                           'Audit - PLRO FIR offer cleared (MWh)'
  o_PLRO_SIR_TP(ca,dt,o)                                           'Audit - PLRO SIR offer cleared (MWh)'
  o_TWRO_FIR_TP(ca,dt,o)                                           'Audit - TWRO FIR offer cleared (MWh)'
  o_TWRO_SIR_TP(ca,dt,o)                                           'Audit - TWRO SIR offer cleared (MWh)'

  o_generationRiskLevel(ca,dt,isl,o,resC,riskC)                    'Audit - generation risk'
  o_HVDCriskLevel(ca,dt,isl,resC,riskC)                            'Audit - DCCE and DCECE risk'
  o_manuRiskLevel(ca,dt,isl,resC,riskC)                            'Audit - manual risk'
  o_genHVDCriskLevel(ca,dt,isl,o,resC,riskC)                       'Audit - generation + HVDC secondary risk'
  o_manuHVDCriskLevel(ca,dt,isl,resC,riskC)                        'Audit - manual + HVDC secondary'
  o_generationRiskGroupLevel(ca,dt,isl,rg,resC,riskC)              'Audit - generation group risk'

* TN - output parameters added for NMIR project --------------------------------
  o_FirSent_TP(ca,dt,isl)                        'FIR export from an island for each trade period'
  o_SirSent_TP(ca,dt,isl)                        'SIR export from an island for each trade period'
  o_FirReceived_TP(ca,dt,isl)                    'FIR received at an island for each trade period'
  o_SirReceived_TP(ca,dt,isl)                    'SIR received at an island for each trade period'
  o_FirEffReport_TP(ca,dt,isl)                   'Effective FIR share for reporting to an island for each trade period'
  o_SirEffReport_TP(ca,dt,isl)                   'Effective FIR share for reporting to an island for each trade period'
  o_EffectiveRes_TP(ca,dt,isl,resC,riskC)        'Effective reserve share to an island for each trade period'
  o_FirEffectiveCE_TP(ca,dt,isl)                 'Effective FIR share to an island for each trade period'
  o_SirEffectiveCE_TP(ca,dt,isl)                 'Effective FIR share to an island for each trade period'
  o_FirEffectiveECE_TP(ca,dt,isl)                'Effective FIR share to an island for each trade period'
  o_SirEffectiveECE_TP(ca,dt,isl)                'Effective FIR share to an island for each trade period'

  o_TotalIslandReserve(ca,dt,isl,resC,riskC)     'Total Reserve cleared in a island including shared Reserve'
* TN - output parameters added for NMIR project end ----------------------------
  ;

Scalars
  modelSolved                   'Flag to indicate if the model solved successfully (1 = Yes)'                                           / 0 /
  LPmodelSolved                 'Flag to indicate if the final LP model (when MIP fails) is solved successfully (1 = Yes)'              / 0 /
  exitLoop                      'Flag to exit solve loop'                                                                               / 0 /
  ;



*=====================================================================================
* 2. Load data from GDX file
*=====================================================================================

* If input file does not exist then go to the next input file
$if not exist "%inputPath%\%GDXname%.gdx" $goto nextInput

* Load trading period to be solved
$onmulti
$gdxin "vSPDPeriod.gdx"
$load tp=i_tradePeriod  dt=i_dateTime  ca=i_caseID  rundt=i_runDateTime  caseName=i_caseName
$load dt2tp = i_dateTimeTradePeriod  case2dt=i_caseDateTime  case2Name=i_caseIdName  case2rundt= i_case2rundt
$gdxin

* Call the GDX routine and load the input data:
$gdxin "%inputPath%\%GDXname%.gdx"
* Sets
$load 
*$load b = i_bus  n = i_node  o = i_offer  bd = i_bid  trdr = i_trader
*$load br = i_branch  brCstr = i_branchConstraint  MnodeCstr = i_MnodeConstraint
$load node = i_dateTimeNode  bus = i_dateTimeBus
$load node2node = i_dateTimeNodetoNode
$load offerTrader = i_dateTimeOfferTrader
$load offerNode = i_dateTimeOfferNode
$load bidTrader = i_dateTimeBidTrader
$load bidNode = i_dateTimeBidNode
$load nodeBus = i_dateTimeNodeBus
$load busIsland = i_dateTimeBusIsland
$load branchDefn = i_dateTimeBranchDefn
$load riskGenerator = i_dateTimeRiskGenerator
$load PrimarySecondaryOffer = i_dateTimePrimarySecondaryOffer
$load dispatchableBid =  i_dateTimeDispatchableBid
*$load rg = i_riskGroup
$load riskGroupOffer = i_dateTimeRiskGroup
$load nodeoutagebranch = i_dateTimeNodeOutageBranch

* Parameters
$load caseGdxDate = gdxDate caseIntervalDuration = i_intervalLength
$load offerParameter = i_dateTimeOfferParameter
$load energyOffer = i_dateTimeEnergyOffer
$load fastPLSRoffer = i_dateTimeFastPLSRoffer
$load sustainedPLSRoffer =  i_dateTimeSustainedPLSRoffer
$load fastTWDRoffer = i_dateTimeFastTWDRoffer
$load sustainedTWDRoffer = i_dateTimeSustainedTWDRoffer
$load fastILRoffer = i_dateTimeFastILRoffer
$load sustainedILRoffer = i_dateTimeSustainedILRoffer

$load energyBid = i_dateTimeEnergyBid
$load nodeDemand = i_dateTimeNodeDemand

$load refNode = i_dateTimeReferenceNode
$load HVDCBranch = i_dateTimeHVDCBranch
$load branchParameter = i_dateTimeBranchParameter
$load branchCapacity = i_dateTimeBranchCapacity
$load branchOpenStatus = i_dateTimeBranchOpenStatus
$load nodeBusAllocationFactor = i_dateTimeNodeBusAllocationFactor
$load busElectricalIsland = i_dateTimeBusElectricalIsland

$load riskParameter = i_dateTimeRiskParameter
$load islandMinimumRisk = i_dateTimeManualRisk
$load HVDCsecRiskEnabled = i_dateTimeHVDCsecRiskEnabled
$load HVDCsecRiskSubtractor = i_dateTimeHVDCsecRiskSubtractor
$load ReserveMaximumFactor = i_dateTimeReserveMaximumFactor

$load branchCstrFactors = i_dateTimeBranchConstraintFactors
$load branchCstrRHS = i_dateTimeBranchConstraintRHS
$load mnCstrEnrgFactors = i_dateTimeMNCnstrEnrgFactors
$load mnCnstrResrvFactors = i_dateTimeMNCnstrResrvFactors
$load mnCnstrEnrgBidFactors = i_dateTimeMNCnstrEnrgBidFactors
$load mnCnstrResrvBidFactors = i_dateTimeMNCnstrResrvBidFactors
$load mnCnstrRHS = i_dateTimeMNCnstrRHS

* National market for IR effective date 20 Oct 2016
$load reserveRoundPower     = i_dateTimeReserveRoundPower
$load reserveShareEnabled   = i_dateTimeReserveSharing
$load modulationRiskClass   = i_dateTimeModulationRisk
$load roundPower2MonoLevel  = i_dateTimeRoundPower2Mono
$load bipole2MonoLevel      = i_dateTimeBipole2Mono
$load monopoleMinimum       = i_dateTimeReserveSharingPoleMin
$load HVDCControlBand       = i_dateTimeHVDCcontrolBand
$load HVDClossScalingFactor = i_dateTimeHVDClossScalingFactor
$load sharedNFRfactor       = i_dateTimeSharedNFRfactor
$load sharedNFRLoadOffset   = i_dateTimeSharedNFRLoadOffset
$load effectiveFactor       = i_dateTimeReserveEffectiveFactor
$load RMTreserveLimitTo     = i_dateTimeRMTreserveLimit
$load rampingConstraint     = i_dateTimeRampingConstraint

*Real Time Pricing Project
$load caseStudyMode                   = i_studyMode
$load useGenInitialMW             = i_dateTimeUseGenInitialMW
$load runEnrgShortfallTransfer    = i_dateTimeRunEnrgShortfallTransfer
$load runPriceTransfer            = i_dateTimeRunPriceTransfer
$load replaceSurplusPrice         = i_dateTimeReplaceSurplusPrice
$load rtdIgIncreaseLimit          = i_dateTimeRtdIgIncreaseLimit
$load useActualLoad               = i_dateTimeUseActualLoad
$load dontScaleNegativeLoad       = i_dateTimeDontScaleNegativeLoad
$load inputInitialLoad            = i_dateTimeInputInitialLoad
$load conformingFactor            = i_dateTimeConformingFactor
$load nonConformingLoad           = i_dateTimeNonConformingLoad
$load loadIsOverride              = i_dateTimeLoadIsOverride
$load loadIsBad                   = i_dateTimeLoadIsBad
$load loadIsNCL                   = i_dateTimeLoadIsNCL
$load maxLoad                     = i_dateTimeMaxLoad
$load instructedLoadShed          = i_dateTimeInstructedLoadShed
$load InstructedShedActive        = i_dateTimeInstructedShedActive
$load islandMWIPS                 = i_dateTimeIslandMWIPS
$load islandPDS                   = i_dateTimeIslandPDS
$load islandLosses                = i_dateTimeIslandLosses
$load enrgShortfallRemovalMargin  = i_dateTimeEnrgShortfallRemovalMargin
$load maxSolveLoops               = i_dateTimeMaxSolveLoops
$load SPDLoadCalcLosses           = i_dateTimeSPDLoadCalcLosses

$load energyScarcityEnabled       = i_dateTimeEnergyScarcityEnabled
$load reserveScarcityEnabled      = i_dateTimeReserveScarcityEnabled
$load scarcityEnrgNationalFactor  = i_dateTimeScarcityEnrgNationalFactor
$load scarcityEnrgNationalPrice   = i_dateTimeScarcityEnrgNationalPrice
$load scarcityEnrgNodeFactor      = i_dateTimeScarcityEnrgNodeFactor
$load scarcityEnrgNodeFactorPrice = i_dateTimeScarcityEnrgNodeFactorPrice
$load scarcityEnrgNodeLimit       = i_dateTimeScarcityEnrgNodeLimit
$load scarcityEnrgNodeLimitPrice  = i_dateTimeScarcityEnrgNodeLimitPrice
$load scarcityResrvIslandLimit    = i_dateTimeScarcityResrvIslandLimit
$load scarcityResrvIslandPrice    = i_dateTimeScarcityResrvIslandPrice
$gdxin

*===============================================================================
* 3. Manage model and data compatability
*===============================================================================
* This section manages the changes to model flags to ensure backward
* compatibility given changes in the SPD model formulation over time:
* Ex: some data (sets) only starting to exist at certain time and we need to use
* GDX time to check if we can load that data (set) from gdx.

* Gregorian date of when symbols have been included into the GDX files
Scalars inputGDXGDate                     'Gregorian date of input GDX file' ;

gdxDate('year')  = sum[ca $ (ord(ca)=1), caseGdxDate(ca,'year')]  ;
gdxDate('month') = sum[ca $ (ord(ca)=1), caseGdxDate(ca,'month')] ;
gdxDate('day')   = sum[ca $ (ord(ca)=1), caseGdxDate(ca,'day')]   ;

inputGDXGDate = jdate(gdxDate('year'),gdxDate('month'),gdxDate('day'));

put_utility temp 'gdxin' / '%inputPath%\%GDXname%.gdx' ;

* *RTP4 - new symbols to support Dispatch Lite - applied from 1 April 2023
if (inputGDXGDate >= jdate(2023,4,1) or sum[sameas(caseName,testCases),1] ,
    execute_load
    discreteModeBid             = i_dateTimeDiscreteModeBid
    dispatchableEnrgOffer       = i_dateTimeDispatchableEnrgOffer
    differenceBid               = i_dateTimeDifferenceBid
    dispatchedLoad              = i_dateTimeDispatchedLoad
    dispatchedGeneration        = i_dateTimeDispatchedGeneration
    ;
else
    discreteModeBid(ca,dt,bd)      = no   ;
    dispatchableEnrgOffer(ca,dt,o) = yes   ;
    differenceBid(ca,dt,bd)        = no   ;
    dispatchedLoad(ca,dt,n)        = 0    ;
    dispatchedGeneration(ca,dt,n)  = 0    ;
    
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


*===============================================================================
* 5. Initialise model mapping and inputs
*===============================================================================

* Calculate studyMode(t)
studyMode(ca,dt) = caseStudyMode(ca);

* Calculate IntervalDuration(t)
IntervalDuration(ca,dt) = caseIntervalDuration(ca);

* Check if NMIR is enabled
UseShareReserve(ca) = 1 $ sum[ (dt,resC), reserveShareEnabled(ca,dt,resC)] ;

* Initialise genrating offer parameters ----------------------------------------
GenerationStart(ca,dt,o) = offerParameter(ca,dt,o,'initialMW') + sum[ o1 $ primarySecondaryOffer(ca,dt,o,o1), offerParameter(ca,dt,o1,'initialMW') ] ;
* if useGenIntitialMW = 1 --> sequential solve like PRSS, NRSS
* GenerationStart(ca,dt,o) $ { (useGenInitialMW(ca,dt) = 1) and (ord(dt) > 1) } = 0;  ! Not neccessary because data is zero anyway

RampRateUp(ca,dt,o)               = offerParameter(ca,dt,o,'rampUpRate')      ;
RampRateDn(ca,dt,o)               = offerParameter(ca,dt,o,'rampDnRate')      ;
ReserveGenerationMaximum(ca,dt,o) = offerParameter(ca,dt,o,'resrvGenMax')      ;
WindOffer(ca,dt,o)                = offerParameter(ca,dt,o,'isIG')            ;
FKband(ca,dt,o)                   = offerParameter(ca,dt,o,'FKbandMW')        ;
PriceResponsive(ca,dt,o)          = offerParameter(ca,dt,o,'isPriceResponse') ;
PotentialMW(ca,dt,o)              = offerParameter(ca,dt,o,'potentialMW')     ;

* This is based on the 4.6.2.1 calculation
$onText
For generators in the PRICERESPONSIVEIG subset, if the PotentialMW(g) value is less than ReserveGenerationMaximum(g,c) then pre-processing sets the ReserveGenerationMaximum(g,c) parameter to the PotentialMWg value,
otherwise if the PotentialMW(g) value is greater than or equal to the ReserveGenerationMaximum(g,c) then the ReserveGenerationMaximum(g,c) value is unchanged
Tuong note: this does not seems to make sense and be used.
$offText
reserveMaximumFactor(ca,dt,o,resC) $ { windOffer(ca,dt,o) and priceResponsive(ca,dt,o) and( potentialMW(ca,dt,o) > 0) and (potentialMW(ca,dt,o) < ReserveGenerationMaximum(ca,dt,o)) } = ReserveGenerationMaximum(ca,dt,o) / potentialMW(ca,dt,o) ;
*-------------------------------------------------------------------------------

* Initialise offer limits and prices -------------------------------------------
* Initialise energy offer data for the current trade period start
EnrgOfrMW(ca,dt,o,blk) = energyOffer(ca,dt,o,blk,'limitMW')  $ dispatchableEnrgOffer(ca,dt,o) ;
EnrgOfrPrice(ca,dt,o,blk) = energyOffer(ca,dt,o,blk,'price') $ dispatchableEnrgOffer(ca,dt,o) ;
* Initialise reserve offer data for the current trade period start
PLRO(resT) $ (ord(resT) = 1) = yes ;
TWRO(resT) $ (ord(resT) = 2) = yes ;
ILRO(resT) $ (ord(resT) = 3) = yes ;

ResOfrPct(ca,dt,o,blk,resC) = (fastPLSRoffer(ca,dt,o,blk,'plsrPct') / 100)$(ord(resC)=1 ) + (sustainedPLSRoffer(ca,dt,o,blk,'plsrPct') / 100)$(ord(resC)=2);
ResOfrMW(ca,dt,o,blk,resC,PLRO) = fastPLSRoffer(ca,dt,o,blk,'limitMW')$(ord(resC)=1)  + sustainedPLSRoffer(ca,dt,o,blk,'limitMW')$(ord(resC)=2) ;
ResOfrMW(ca,dt,o,blk,resC,TWRO) = fastTWDRoffer(ca,dt,o,blk,'limitMW')$(ord(resC)=1)  + sustainedTWDRoffer(ca,dt,o,blk,'limitMW')$(ord(resC)=2) ;
ResOfrMW(ca,dt,o,blk,resC,ILRO) = fastILRoffer(ca,dt,o,blk,'limitMW')$(ord(resC)=1)   + sustainedILRoffer(ca,dt,o,blk,'limitMW')$(ord(resC)=2) ;
ResOfrPrice(ca,dt,o,blk,resC,PLRO) = fastPLSRoffer(ca,dt,o,blk,'price')$(ord(resC)=1) + sustainedPLSRoffer(ca,dt,o,blk,'price')$(ord(resC)=2) ;
ResOfrPrice(ca,dt,o,blk,resC,TWRO) = fastTWDRoffer(ca,dt,o,blk,'price')$(ord(resC)=1) + sustainedTWDRoffer(ca,dt,o,blk,'price')$(ord(resC)=2) ;
ResOfrPrice(ca,dt,o,blk,resC,ILRO) = fastILRoffer(ca,dt,o,blk,'price')$(ord(resC)=1)  + sustainedILRoffer(ca,dt,o,blk,'price')$(ord(resC)=2)  ;
*-------------------------------------------------------------------------------

* Define valid offers and valid offer block ------------------------------------
* Valid offer must be mapped to a bus with electrical island <> 0
offer(ca,dt,o) $ sum[ (n,b) $ { offerNode(ca,dt,o,n) and nodeBus(ca,dt,n,b) }, busElectricalIsland(ca,dt,b) ] = yes ;
* IL offer with non zero total limit is always valid
offer(ca,dt,o) $ sum[ (blk,resC,ILRO), ResOfrMW(ca,dt,o,blk,resC,ILRO)] = yes ;
* Valid energy offer blocks are defined as those with a positive block limit
genOfrBlk(ca,dt,o,blk) $ ( EnrgOfrMW(ca,dt,o,blk) > 0 ) = yes ;
* Define set of positive (valid) energy offers
posEnrgOfr(ca,dt,o) $ sum[ blk $ genOfrBlk(ca,dt,o,blk), 1 ] = yes ;
* Only reserve offer block with a positive block limit is valid
resOfrBlk(ca,dt,o,blk,resC,resT) $ (ResOfrMW(ca,dt,o,blk,resC,resT) > 0) = yes ;
*-------------------------------------------------------------------------------

* Initialise bid limits and prices ---------------------------------------------
* Valid bid must be mapped to a bus with electrical island <> 0
bid(ca,dt,bd) $ sum[ (n,b) $ { bidNode(ca,dt,bd,n) and nodeBus(ca,dt,n,b) }, busElectricalIsland(ca,dt,b) ] = yes ;
* Bid energy data and valid bid block
DemBidMW(bid,blk)    $ dispatchableBid(bid) = energyBid(bid,blk,'limitMW') ;
DemBidPrice(bid,blk) $ dispatchableBid(bid) = energyBid(bid,blk,'price')   ;
DemBidBlk(bid,blk)   $ ( DemBidMW(bid,blk) <> 0 ) = yes ;
*-------------------------------------------------------------------------------

* Initialise mappings to use in later stage ------------------------------------
nodeIsland(ca,dt,n,isl) $ sum[ b $ { bus(ca,dt,b) and node(ca,dt,n) and nodeBus(ca,dt,n,b) and busIsland(ca,dt,b,isl) }, 1 ] = yes ;
offerIsland(offer(ca,dt,o),isl) $ sum[ n $ { offerNode(ca,dt,o,n) and nodeIsland(ca,dt,n,isl) }, 1 ] = yes ;
bidIsland(bid(ca,dt,bd),isl) $ sum[ n $ { bidNode(ca,dt,bd,n) and nodeIsland(ca,dt,n,isl) }, 1 ] = yes ;
islandRiskGenerator(ca,dt,isl,o) $ { offerIsland(ca,dt,o,isl) and riskGenerator(ca,dt,o) } = yes ;

* Identification of primary and secondary units
PrimaryOffer(ca,dt,o) = 1 ;
SecondaryOffer(ca,dt,o) = 1 $ sum[ o1 $ primarySecondaryOffer(ca,dt,o1,o), 1 ] ;
PrimaryOffer(ca,dt,o) $ SecondaryOffer(ca,dt,o) = 0 ;
*-------------------------------------------------------------------------------

* Initialize AC and DC branches ------------------------------------------------
*Branch is defined if there is a defined terminal bus, it is in servcie for that trade period and has positive capacity limit for both direction (only forward direction for HVDC).
branch(ca,dt,br) = yes $ { (not branchOpenStatus(ca,dt,br)) and branchCapacity(ca,dt,br,'forward') and branchCapacity(ca,dt,br,'backward') and sum[ (b,b1) $ { bus(ca,dt,b) and bus(ca,dt,b1) and branchDefn(ca,dt,br,b,b1) }, 1 ] }  ;
branch(ca,dt,br) $ { (not branchOpenStatus(ca,dt,br)) and (HVDCBranch(ca,dt,br)) and branchCapacity(ca,dt,br,'forward') and sum[ (b,b1) $ { bus(ca,dt,b) and bus(ca,dt,b1) and branchDefn(ca,dt,br,b,b1) }, 1 ] } = yes ;

branchBusDefn(branch,b,b1) $ branchDefn(branch,b,b1)    = yes ;
branchFrBus(branch,frB) $ sum[ toB $ branchBusDefn(branch,frB,toB), 1 ] = yes ;
branchToBus(branch,toB) $ sum[ frB $ branchBusDefn(branch,frB,toB), 1 ] = yes ;
branchBusConnect(branch,b) $ { branchFrBus(branch,b) or branchToBus(branch,b) } = yes ;

* HVDC link and AC branch definition
HVDClink(branch) = yes $ HVDCBranch(branch) ;
ACbranch(branch) = yes $ [not HVDCBranch(branch)];

* Determine sending and receiving bus for each branch flow direction
loop ((frB,toB),
    ACbranchSendingBus(ACbranch,frB,fd)   $ { branchBusDefn(ACbranch,frB,toB) and (ord(fd) = 1) } = yes ;
    ACbranchReceivingBus(ACbranch,toB,fd) $ { branchBusDefn(ACbranch,frB,toB) and (ord(fd) = 1) } = yes ;
    ACbranchSendingBus(ACbranch,toB,fd)   $ { branchBusDefn(ACbranch,frB,toB) and (ord(fd) = 2) } = yes ;
    ACbranchReceivingBus(ACbranch,frB,fd) $ { branchBusDefn(ACbranch,frB,toB) and (ord(fd) = 2) } = yes ;
) ;

HVDClinkSendingBus(HVDClink,frB)   $ sum[ branchBusDefn(HVDClink,frB,toB), 1 ] = yes ;
HVDClinkReceivingBus(HVDClink,toB) $ sum[ branchBusDefn(HVDClink,frB,toB), 1 ] = yes ;
HVDClinkBus(HVDClink,b) $ { HVDClinkSendingBus(HVDClink,b) or HVDClinkReceivingBus(HVDClink,b) }  = yes ;

* Determine the HVDC inter-island pole in the northward and southward direction
HVDCpoleDirection(ca,dt,br,fd) $ { (ord(fd) = 1) and HVDClink(ca,dt,br) } = yes $ sum[ (isl,NodeBus(ca,dt,n,b)) $ { (ord(isl) = 2) and nodeIsland(ca,dt,n,isl) and HVDClinkSendingBus(ca,dt,br,b) }, 1 ] ;
HVDCpoleDirection(ca,dt,br,fd) $ { (ord(fd) = 2) and HVDClink(ca,dt,br) } = yes $ sum[ (isl,NodeBus(ca,dt,n,b)) $ { (ord(isl) = 1) and nodeIsland(ca,dt,n,isl) and HVDClinkSendingBus(ca,dt,br,b) }, 1 ] ;

* Mapping HVDC branch to pole to account for name changes to Pole 3
HVDCpoleBranchMap('Pole1',br) $ sum[ sameas(br,'BEN_HAY1.1'), 1] = yes ;
HVDCpoleBranchMap('Pole1',br) $ sum[ sameas(br,'HAY_BEN1.1'), 1] = yes ;
HVDCpoleBranchMap('Pole1',br) $ sum[ sameas(br,'BEN_HAY3.1'), 1] = yes ;
HVDCpoleBranchMap('Pole1',br) $ sum[ sameas(br,'HAY_BEN3.1'), 1] = yes ;
HVDCpoleBranchMap('Pole2',br) $ sum[ sameas(br,'BEN_HAY2.1'), 1] = yes ;
HVDCpoleBranchMap('Pole2',br) $ sum[ sameas(br,'HAY_BEN2.1'), 1] = yes ;

* Initialise network data for the current trade period start
branchResistance(branch)    = branchParameter(branch,'resistance') ;
branchSusceptance(ACbranch) = -100 * branchParameter(ACbranch,'susceptance');
branchLossBlocks(branch)    = branchParameter(branch,'numLossTranches') ;

* Ensure fixed losses for no loss AC branches are not included
branchFixedLoss(ACbranch) = branchParameter(ACbranch,'fixedLosses') $ (branchLossBlocks(ACbranch) > 1) ;
branchFixedLoss(HVDClink) = branchParameter(HVDClink,'fixedLosses') ;

* Set resistance and fixed loss to zero if do not want to use the loss model
branchResistance(ACbranch) $ (not useAClossModel) = 0 ;
branchFixedLoss(ACbranch)  $ (not useAClossModel) = 0 ;
branchResistance(HVDClink) $ (not useHVDClossModel) = 0 ;
branchFixedLoss(HVDClink)  $ (not useHVDClossModel) = 0 ;

$ontext
Initialise loss tranches data for the current trade period start. The loss factor coefficients assume that the branch capacity is in MW and the resistance is in p.u.
$offtext

lossSegmentMW(branch,los,fd)     $ { (branchLossBlocks(branch) = 0) and (ord(los) = 1) } = branchCapacity(branch,fd) ;
LossSegmentFactor(branch,los,fd) $ { (branchLossBlocks(branch) = 0) and (ord(los) = 1) } = 0 ;

LossSegmentMW(branch,los,fd)     $ { (branchLossBlocks(branch) = 1) and (ord(los) = 1) } = maxFlowSegment ;
LossSegmentFactor(branch,los,fd) $ { (branchLossBlocks(branch) = 1) and (ord(los) = 1) } = 0.01 * branchResistance(branch) * branchCapacity(branch,fd) ;

LossSegmentMW(branch,los,fd)     $ { (branchLossBlocks(branch) = 3) and (ord(los) = 1) } = lossCoeff_A * branchCapacity(branch,fd) ;
LossSegmentMW(branch,los,fd)     $ { (branchLossBlocks(branch) = 3) and (ord(los) = 2) } = (1-lossCoeff_A) * branchCapacity(branch,fd) ;
LossSegmentMW(branch,los,fd)     $ { (branchLossBlocks(branch) = 3) and (ord(los) = 3) } = maxFlowSegment ;
LossSegmentFactor(branch,los,fd) $ { (branchLossBlocks(branch) = 3) and (ord(los) = 2) } = 0.01 * branchResistance(branch) * branchCapacity(branch,fd) ;
LossSegmentFactor(branch,los,fd) $ { (branchLossBlocks(branch) = 3) and (ord(los) = 1) } = 0.01 * 0.75 * lossCoeff_A * branchResistance(branch) * branchCapacity(branch,fd) ;
LossSegmentFactor(branch,los,fd) $ { (branchLossBlocks(branch) = 3) and (ord(los) = 3) } = 0.01 * (2 - (0.75*lossCoeff_A)) * branchResistance(branch) * branchCapacity(branch,fd) ;

LossSegmentMW(branch,los,fd)     $ { (branchLossBlocks(branch) = 6) and (ord(los) = 1) } = lossCoeff_C  * branchCapacity(branch,fd) ;
LossSegmentMW(branch,los,fd)     $ { (branchLossBlocks(branch) = 6) and (ord(los) = 2) } = lossCoeff_D * branchCapacity(branch,fd) ;
LossSegmentMW(branch,los,fd)     $ { (branchLossBlocks(branch) = 6) and (ord(los) = 3) } = 0.5 * branchCapacity(branch,fd) ;
LossSegmentMW(branch,los,fd)     $ { (branchLossBlocks(branch) = 6) and (ord(los) = 4) } = (1 - lossCoeff_D) * branchCapacity(branch,fd) ;
LossSegmentMW(branch,los,fd)     $ { (branchLossBlocks(branch) = 6) and (ord(los) = 5) } = (1 - lossCoeff_C) * branchCapacity(branch,fd) ;
LossSegmentMW(branch,los,fd)     $ { (branchLossBlocks(branch) = 6) and (ord(los) = 6) } = maxFlowSegment ;
LossSegmentFactor(branch,los,fd) $ { (branchLossBlocks(branch) = 6) and (ord(los) = 1) } = 0.01 * 0.75 * lossCoeff_C * branchResistance(branch) * branchCapacity(branch,fd) ;
LossSegmentFactor(branch,los,fd) $ { (branchLossBlocks(branch) = 6) and (ord(los) = 2) } = 0.01 * lossCoeff_E * branchResistance(branch) * branchCapacity(branch,fd) ;
LossSegmentFactor(branch,los,fd) $ { (branchLossBlocks(branch) = 6) and (ord(los) = 3) } = 0.01 * lossCoeff_F * branchResistance(branch) * branchCapacity(branch,fd) ;
LossSegmentFactor(branch,los,fd) $ { (branchLossBlocks(branch) = 6) and (ord(los) = 4) } = 0.01 * (2 - lossCoeff_F) * branchResistance(branch) * branchCapacity(branch,fd) ;
LossSegmentFactor(branch,los,fd) $ { (branchLossBlocks(branch) = 6) and (ord(los) = 5) } = 0.01 * (2 - lossCoeff_E) * branchResistance(branch) * branchCapacity(branch,fd) ;
LossSegmentFactor(branch,los,fd) $ { (branchLossBlocks(branch) = 6) and (ord(los) = 6) } = 0.01 * (2 - (0.75*lossCoeff_C)) * branchResistance(branch) * branchCapacity(branch,fd) ;

* HVDC does not have backward flow --> No loss segment for backward flow
LossSegmentMW(HVDClink,los,fd)     $ (ord(fd) = 2) = 0;
LossSegmentFactor(HVDClink,los,fd) $ (ord(fd) = 2) = 0;

* Valid loss segment for a branch is defined as a loss segment that has a non-zero LossSegmentMW or a non-zero LossSegmentFactor.
validLossSegment(branch,los,fd) = yes $ { (ord(los) = 1) or LossSegmentMW(branch,los,fd) or LossSegmentFactor(branch,los,fd) } ;
* HVDC loss model requires at least two loss segments and an additional loss block due to cumulative loss formulation
validLossSegment(HVDClink,los,fd) $ { (branchLossBlocks(HVDClink) <= 1) and (ord(los) = 2) } = yes ;
validLossSegment(HVDClink,los,fd) $ { (branchLossBlocks(HVDClink) > 1) and (ord(los) = (branchLossBlocks(HVDClink) + 1)) and (sum[ los1, LossSegmentMW(HVDClink,los1,fd) + LossSegmentFactor(HVDClink,los1,fd) ] > 0) } = yes ;

* branches that have non-zero loss factors
LossBranch(branch) $ sum[ (los,fd), LossSegmentFactor(branch,los,fd) ] = yes ;

* Create AC branch loss segments
ACbranchLossMW(ACbranch,los,fd) $ { validLossSegment(ACbranch,los,fd) and (ord(los) = 1) } = LossSegmentMW(ACbranch,los,fd) ;
ACbranchLossMW(ACbranch,los,fd) $ { validLossSegment(ACbranch,los,fd) and (ord(los) > 1) } = LossSegmentMW(ACbranch,los,fd) - LossSegmentMW(ACbranch,los-1,fd) ;
ACbranchLossFactor(ACbranch,los,fd) $ validLossSegment(ACbranch,los,fd) = LossSegmentFactor(ACbranch,los,fd) ;

* Create HVDC loss break points
HVDCBreakPointMWFlow(HVDClink,bp,fd) $ (ord(bp) = 1) = 0 ;
HVDCBreakPointMWLoss(HVDClink,bp,fd) $ (ord(bp) = 1) = 0 ;
HVDCBreakPointMWFlow(HVDClink,bp,fd) $ { validLossSegment(HVDClink,bp,fd) and (ord(bp) > 1) } = LossSegmentMW(HVDClink,bp-1,fd) ;
HVDCBreakPointMWLoss(HVDClink,bp,fd) $ { validLossSegment(HVDClink,bp,fd) and (ord(bp) = 2) } =  LossSegmentMW(HVDClink,bp-1,fd) * LossSegmentFactor(HVDClink,bp-1,fd) ;
loop ((HVDClink(branch),bp) $ (ord(bp) > 2),
    HVDCBreakPointMWLoss(branch,bp,fd) $ validLossSegment(branch,bp,fd) = LossSegmentFactor(branch,bp-1,fd) * [ LossSegmentMW(branch,bp-1,fd) - LossSegmentMW(branch,bp-2,fd) ] + HVDCBreakPointMWLoss(branch,bp-1,fd) ;
) ;
*-------------------------------------------------------------------------------

* Initialise branch constraint data --------------------------------------------
branchConstraint(ca,dt,brCstr) $ sum[ branch(ca,dt,br) $ branchCstrFactors(ca,dt,brCstr,br), 1 ] = yes ;
branchConstraintSense(branchConstraint) = branchCstrRHS(branchConstraint,'cnstrSense') ;
branchConstraintLimit(branchConstraint) = branchCstrRHS(branchConstraint,'cnstrLimit') ;
*-------------------------------------------------------------------------------

* Calculate parameters for NMIR project ----------------------------------------
islandRiskGroup(ca,dt,isl,rg,riskC) = yes $ sum[ o $ { offerIsland(ca,dt,o,isl) and riskGroupOffer(ca,dt,rg,o,riskC) }, 1 ] ;
modulationRisk(ca,dt)               = smax[ riskC, modulationRiskClass(ca,dt,RiskC) ];
reserveShareEnabledOverall(ca,dt)   = smax[ resC, reserveShareEnabled(ca,dt,resC) ];
roPwrZoneExit(ca,dt,resC)           = [ roundPower2MonoLevel(ca,dt) - modulationRisk(ca,dt) ]$(ord(resC)=1) + bipole2MonoLevel(ca,dt)$(ord(resC)=2) ;

$onText
SPD pre-processing is changed so that the roundpower settings for FIR are now the same as for SIR. Specifically: (National market refinement - effective date 28 Mar 2019 12:00 )
-  The RoundPowerZoneExit for FIR will be set at BipoleToMonopoleTransition by SPD pre-processing. A change from the existing where the RoundPowerZoneExit for FIR is set at RoundPowerToMonopoleTransition by SPD pre-processing.
-  Provided that roundpower is not disabled by the MDB, the InNoReverseZone for FIR will be removed by SPD pre-processing. A change from the existing where the InNoReverseZone for FIR is never removed by SPD pre-processing.
$offText
if(inputGDXGDate >= jdate(2019,03,28),
    roPwrZoneExit(ca,dt,resC) = bipole2MonoLevel(ca,dt) ;
) ;

* Calculate HVDC constraint sets and HVDC Max Flow - NMIR (4.1.8 - NMIR06)
$onText
TN on 22 May 2017:
Usually a branch group constraint that limits the HVDC flow only involves the HVDC branch(s) in the same direction. However, during TP6 to TP9 of 18 May 2017, the constraint HAY_BEN_High_Frequency_limit involved all four
branches in the form: HAY_BEN1.1 + HAY_BEN2.1 - BEN_HAY1.1 - BEN_HAY2.1 <= 530 MW. This method of formulating the constraint prevented the previous formulation of monopoleConstraint and bipoleConstraintfrom working properly.
Those constraints have been reformulated (see below) in order to cope with the formulation observed on 18 May 2017.
$offText
monopoleConstraint(ca,dt,isl,brCstr,br) $ { HVDClink(ca,dt,br) and ( not rampingConstraint(ca,dt,brCstr) ) and ( branchConstraintSense(ca,dt,brCstr) = -1 )
                                     and (sum[ (br1,b) $ { HVDClinkSendingBus(ca,dt,br1,b) and busIsland(ca,dt,b,isl) }, branchCstrFactors(ca,dt,brCstr,br1)] = 1)
                                     and (sum[ b $ { HVDClinkSendingBus(ca,dt,br,b) and busIsland(ca,dt,b,isl) }, branchCstrFactors(ca,dt,brCstr,br)] = 1)  } = yes ;

bipoleConstraint(ca,dt,isl,brCstr) $ { ( not rampingConstraint(ca,dt,brCstr) ) and ( branchConstraintSense(ca,dt,brCstr) = -1 )
                                and (sum[ (br,b) $ { HVDClink(ca,dt,br) and HVDClinkSendingBus(ca,dt,br,b) and busIsland(ca,dt,b,isl) }, branchCstrFactors(ca,dt,brCstr,br)  ] = 2) } = yes ;

monoPoleCapacity(ca,dt,isl,br) = sum[ b $ { BusIsland(ca,dt,b,isl) and HVDClink(ca,dt,br) and HVDClinkSendingBus(ca,dt,br,b)}, branchCapacity(ca,dt,br,'forward') ] ;
monoPoleCapacity(ca,dt,isl,br) $ sum[ brCstr $ monopoleConstraint(ca,dt,isl,brCstr,br), 1] = Smin[ brCstr $ monopoleConstraint(ca,dt,isl,brCstr,br), branchConstraintLimit(ca,dt,brCstr) ];
monoPoleCapacity(ca,dt,isl,br) = Min[ monoPoleCapacity(ca,dt,isl,br), branchCapacity(ca,dt,br,'forward') ];

biPoleCapacity(ca,dt,isl) $ sum[ brCstr $ bipoleConstraint(ca,dt,isl,brCstr), 1]  = Smin[ brCstr $ bipoleConstraint(ca,dt,isl,brCstr) , branchConstraintLimit(ca,dt,brCstr) ];
biPoleCapacity(ca,dt,isl) $ { sum[ brCstr $ bipoleConstraint(ca,dt,isl,brCstr), 1] = 0 } = sum[ (b,br,fd) $ { BusIsland(ca,dt,b,isl) and HVDClink(ca,dt,br) and HVDClinkSendingBus(ca,dt,br,b) }, branchCapacity(ca,dt,br,'forward') ] ;
HVDCMax(ca,dt,isl) = Min( biPoleCapacity(ca,dt,isl), sum[ br, monoPoleCapacity(ca,dt,isl,br) ] ) ;

* Initialse parameters for NMIR -------------------------------------------
$onText
* When NMIR started on 20/10/2016, the SO decided to incorrectly calculate the HVDC loss curve for reserve sharing based on the HVDC capacity only (i.e. not based on in-service HVDC poles)
* Tuong Nguyen @ EA discovered this bug and the SO has fixed it as of 22/11/2016.
$offText
HVDCCapacity(ca,dt,isl) = sum[ (b,br) $ { BusIsland(ca,dt,b,isl) and HVDClink(ca,dt,br) and HVDClinkSendingBus(ca,dt,br,b) }, branchCapacity(ca,dt,br,'forward') ] ;
numberOfPoles(ca,dt,isl) = sum[ (b,br) $ { BusIsland(ca,dt,b,isl) and HVDClink(ca,dt,br) and HVDClinkSendingBus(ca,dt,br,b) }, 1 ] ;
HVDCResistance(ca,dt,isl) $ (numberOfPoles(ca,dt,isl) = 2) = prod[ (b,br) $ { BusIsland(ca,dt,b,isl) and HVDClink(ca,dt,br) and HVDClinkSendingBus(ca,dt,br,b) }, branchResistance(ca,dt,br) ]
                                                     / sum[ (b,br) $ { BusIsland(ca,dt,b,isl) and HVDClink(ca,dt,br) and HVDClinkSendingBus(ca,dt,br,b) }, branchResistance(ca,dt,br) ] ;
HVDCResistance(ca,dt,isl) $ (numberOfPoles(ca,dt,isl) = 1) = sum[ br $ monoPoleCapacity(ca,dt,isl,br), branchResistance(ca,dt,br) ] ;

HVDCLossSegmentMW(ca,dt,isl,los)     $ (ord(los) = 1) = HVDCCapacity(ca,dt,isl) * lossCoeff_C ;
HVDCLossSegmentMW(ca,dt,isl,los)     $ (ord(los) = 2) = HVDCCapacity(ca,dt,isl) * lossCoeff_D ;
HVDCLossSegmentMW(ca,dt,isl,los)     $ (ord(los) = 3) = HVDCCapacity(ca,dt,isl) * 0.5 ;
HVDCLossSegmentMW(ca,dt,isl,los)     $ (ord(los) = 4) = HVDCCapacity(ca,dt,isl) * (1 - lossCoeff_D) ;
HVDCLossSegmentMW(ca,dt,isl,los)     $ (ord(los) = 5) = HVDCCapacity(ca,dt,isl) * (1 - lossCoeff_C) ;
HVDCLossSegmentMW(ca,dt,isl,los)     $ (ord(los) = 6) = HVDCCapacity(ca,dt,isl) ;
HVDCLossSegmentFactor(ca,dt,isl,los) $ (ord(los) = 1) = 0.01 * 0.75 * lossCoeff_C * HVDCResistance(ca,dt,isl) * HVDCCapacity(ca,dt,isl) ;
HVDCLossSegmentFactor(ca,dt,isl,los) $ (ord(los) = 2) = 0.01 * lossCoeff_E * HVDCResistance(ca,dt,isl) * HVDCCapacity(ca,dt,isl) ;
HVDCLossSegmentFactor(ca,dt,isl,los) $ (ord(los) = 3) = 0.01 * lossCoeff_F * HVDCResistance(ca,dt,isl) * HVDCCapacity(ca,dt,isl) ;
HVDCLossSegmentFactor(ca,dt,isl,los) $ (ord(los) = 4) = 0.01 * (2 - lossCoeff_F) * HVDCResistance(ca,dt,isl) * HVDCCapacity(ca,dt,isl) ;
HVDCLossSegmentFactor(ca,dt,isl,los) $ (ord(los) = 5) = 0.01 * (2 - lossCoeff_E) * HVDCResistance(ca,dt,isl) * HVDCCapacity(ca,dt,isl) ;
HVDCLossSegmentFactor(ca,dt,isl,los) $ (ord(los) = 6) = 0.01 * (2 - (0.75*lossCoeff_C)) * HVDCResistance(ca,dt,isl) * HVDCCapacity(ca,dt,isl) ;

* Parameter for energy lambda loss model
HVDCSentBreakPointMWFlow(ca,dt,isl,bp) $ (ord(bp) = 1) = 0 ;
HVDCSentBreakPointMWLoss(ca,dt,isl,bp) $ (ord(bp) = 1) = 0 ;
HVDCSentBreakPointMWFlow(ca,dt,isl,bp) $ (ord(bp) > 1) = HVDCLossSegmentMW(ca,dt,isl,bp-1) ;
loop( (ca,dt,isl,bp) $ {(ord(bp) > 1) and (ord(bp) <= 7)},
    HVDCSentBreakPointMWLoss(ca,dt,isl,bp) = HVDClossScalingFactor(ca,dt) * HVDCLossSegmentFactor(ca,dt,isl,bp-1) * [ HVDCLossSegmentMW(ca,dt,isl,bp-1) - HVDCSentBreakPointMWFlow(ca,dt,isl,bp-1) ] + HVDCSentBreakPointMWLoss(ca,dt,isl,bp-1) ;
) ;

* Parameter for energy+reserve lambda loss model
* Ideally SO should use asymmetric loss curve
HVDCReserveBreakPointMWFlow(ca,dt,isl,rsbp) $ (ord(rsbp) <= 7) = sum[ (isl1,rsbp1) $ { ( not sameas(isl1,isl) ) and ( ord(rsbp) + ord(rsbp1) = 8) }, -HVDCSentBreakPointMWFlow(ca,dt,isl1,rsbp1) ];
HVDCReserveBreakPointMWLoss(ca,dt,isl,rsbp) $ (ord(rsbp) <= 7) = sum[ (isl1,rsbp1) $ { ( not sameas(isl1,isl) ) and ( ord(rsbp) + ord(rsbp1) = 8) }, HVDCSentBreakPointMWLoss(ca,dt,isl1,rsbp1) ];
* SO decide to use symmetric loss curve instead
HVDCReserveBreakPointMWFlow(ca,dt,isl,rsbp) $ (ord(rsbp) <= 7) = sum[ rsbp1 $ { ord(rsbp) + ord(rsbp1) = 8 }, -HVDCSentBreakPointMWFlow(ca,dt,isl,rsbp1) ];
HVDCReserveBreakPointMWFlow(ca,dt,isl,rsbp) $ { (ord(rsbp) > 7) and (ord(rsbp) <= 13) } = HVDCSentBreakPointMWFlow(ca,dt,isl,rsbp-6) ;
HVDCReserveBreakPointMWLoss(ca,dt,isl,rsbp) $ (ord(rsbp) <= 7) = sum[ rsbp1 $ { ord(rsbp) + ord(rsbp1) = 8 }, HVDCSentBreakPointMWLoss(ca,dt,isl,rsbp1) ];
HVDCReserveBreakPointMWLoss(ca,dt,isl,rsbp) $ { (ord(rsbp) > 7) and (ord(rsbp) <= 13) } = HVDCSentBreakPointMWLoss(ca,dt,isl,rsbp-6);
* Initialze parameters for NMIR project end ----------------------------------

* Initialise risk/reserve data for the current trade period start
GenRisk(riskC)     $ { (ord(riskC) = 1) or (ord(riskC) = 5) } = yes ;
HVDCrisk(riskC)    $ { (ord(riskC) = 2) or (ord(riskC) = 3) } = yes ;
ManualRisk(riskC)  $ { (ord(riskC) = 4) or (ord(riskC) = 6) } = yes ;
HVDCsecRisk(riskC) $ { (ord(riskC) = 7) or (ord(riskC) = 8) } = yes ;
* Define the CE and ECE risk class set to support the different CE and ECE CVP
ContingentEvents(riskC)        $ { (ord(riskC) = 1) or (ord(riskC) = 2) or (ord(riskC) = 4) or (ord(riskC) = 7) } = yes ;
ExtendedContingentEvent(riskC) $ { (ord(riskC) = 3) or (ord(riskC) = 5) or (ord(riskC) = 6) or (ord(riskC) = 8) }= yes ;

* Risk parameters
IslandRiskAdjustmentFactor(ca,dt,isl,resC,riskC) $ useReserveModel = riskParameter(ca,dt,isl,resC,riskC,'adjustFactor') ;
HVDCpoleRampUp(ca,dt,isl,resC,riskC) = riskParameter(ca,dt,isl,resC,riskC,'HVDCRampUp') ;

* Initialise market node constraint data for the current trading period
MnodeConstraint(ca,dt,MnodeCstr) $ { sum[ (offer(ca,dt,o),resT,resC) $ { mnCstrEnrgFactors(ca,dt,MnodeCstr,o) or mnCnstrResrvFactors(ca,dt,MnodeCstr,o,resC,resT) }, 1 ]
                               or sum[ (bid(ca,dt,bd),resC) $ { mnCnstrEnrgBidFactors(ca,dt,MnodeCstr,bd) or mnCnstrResrvBidFactors(ca,dt,MnodeCstr,bd,resC) }, 1 ] } = yes ;
MnodeConstraintSense(MnodeConstraint) = mnCnstrRHS(MnodeConstraint,'cnstrSense') ;
MnodeConstraintLimit(MnodeConstraint) = mnCnstrRHS(MnodeConstraint,'cnstrLimit') ;

* Generation Ramp Pre_processing -----------------------------------------------
* For PRICERESPONSIVEIG generators, The RTD RampRateUp is capped: (4.7.2.2)
loop( (ca,dt),
  if (studyMode(ca,dt) = 101 or studyMode(ca,dt) = 201,
      RampRateUp(offer(ca,dt,o)) $ { windOffer(offer) and priceResponsive(offer) } = Min[ RampRateUp(offer), rtdIgIncreaseLimit(ca,dt)*60/intervalDuration(ca,dt) ];
  ) ;
) ;

totalBusAllocation(ca,dt,b) $ bus(ca,dt,b) = sum[ n $ Node(ca,dt,n), NodeBusAllocationFactor(ca,dt,n,b)];
busNodeAllocationFactor(ca,dt,b,n) $ (totalBusAllocation(ca,dt,b) > 0) = NodeBusAllocationFactor(ca,dt,n,b) / totalBusAllocation(ca,dt,b) ;

* Need to initiate value for this parameters before it is used
o_offerEnergy_TP(ca,dt,o) = 0;


* Initialise demand/bid data ---------------------------------------------------
RequiredLoad(node) = nodeDemand(node) ;

* 4.9.2 Dispatchable Pnodes
$ontext
If the Pnode associated with a Dispatchable Demand Bid is not a dead Pnode then
PnodeRequiredLoadpn is set to zero. The Pnode load will be determined by
clearing the Pnode's Dispatchable Demand Bid when the LP Model is solved.
$offtext
RequiredLoad(node(ca,dt,n)) $ { sum[ (bd,blk) $ ( bidNode(ca,dt,bd,n) and (not differenceBid(ca,dt,bd) ) ), DemBidMW(ca,dt,bd,blk) ] > 0 } = 0;
*-------------------------------------------------------------------------------

* Initialize energy scarcity limits and prices ---------------------------------
ScarcityEnrgLimit(ca,dt,n,blk) $ { energyScarcityEnabled(ca,dt) and (RequiredLoad(ca,dt,n) > 0) }                                      = scarcityEnrgNationalFactor(ca,dt,blk) * RequiredLoad(ca,dt,n);
ScarcityEnrgPrice(ca,dt,n,blk) $ { energyScarcityEnabled(ca,dt) and (ScarcityEnrgLimit(ca,dt,n,blk) > 0 ) }                            = scarcityEnrgNationalPrice(ca,dt,blk) ;

ScarcityEnrgLimit(ca,dt,n,blk) $ { energyScarcityEnabled(ca,dt) and scarcityEnrgNodeFactor(ca,dt,n,blk) and (RequiredLoad(ca,dt,n) > 0) } = scarcityEnrgNodeFactor(ca,dt,n,blk) * RequiredLoad(ca,dt,n);
ScarcityEnrgPrice(ca,dt,n,blk) $ { energyScarcityEnabled(ca,dt) and scarcityEnrgNodeFactorPrice(ca,dt,n,blk) }                         = scarcityEnrgNodeFactorPrice(ca,dt,n,blk) ;

ScarcityEnrgLimit(ca,dt,n,blk) $ { energyScarcityEnabled(ca,dt) and scarcityEnrgNodeLimit(ca,dt,n,blk) }                               = scarcityEnrgNodeLimit(ca,dt,n,blk);
ScarcityEnrgPrice(ca,dt,n,blk) $ { energyScarcityEnabled(ca,dt) and scarcityEnrgNodeLimitPrice(ca,dt,n,blk) }                          = scarcityEnrgNodeLimitPrice(ca,dt,n,blk) ;
*-------------------------------------------------------------------------------

* Pre-processing: Shared Net Free Reserve (NFR) calculation - NMIR (4.5.2.1)
sharedNFRLoad(ca,dt,isl) = sum[ nodeIsland(ca,dt,n,isl), RequiredLoad(ca,dt,n)] + sum[ (bd,blk) $ bidIsland(ca,dt,bd,isl), DemBidMW(ca,dt,bd,blk) ] - sharedNFRLoadOffset(ca,dt,isl) ;
sharedNFRMax(ca,dt,isl) = Min{ RMTReserveLimitTo(ca,dt,isl,'FIR'), sharedNFRFactor(ca,dt)*sharedNFRLoad(ca,dt,isl) } ;

* Risk parameters
FreeReserve(ca,dt,isl,resC,riskC) = riskParameter(ca,dt,isl,resC,riskC,'freeReserve') - sum[ isl1 $ (not sameas(isl,isl1)),sharedNFRMax(ca,dt,isl1) ]${(ord(resC)=1) and ((GenRisk(riskC)) or (ManualRisk(riskC))) } ;

* TN - Pivot or demand analysis begin
$Ifi %opMode%=='PVT' $include "Pivot\vSPDSolvePivot_1.gms"
$Ifi %opMode%=='DPS' $include "Demand\vSPDSolveDPS_1.gms"
* TN - Pivot or demand analysis begin end

*=====================================================================================
* 7. The vSPD solve loop
*=====================================================================================

LoadCalcLosses(ca,dt,isl) = islandLosses(ca,dt,isl);
DidShortfallTransfer(ca,dt,n) = 0;
ShortfallDisabledScaling(ca,dt,n) = 0;
CheckedNodeCandidate(ca,dt,n) = 0;
PotentialModellingInconsistency(ca,dt,n)= 1 $ { sum[ branch(ca,dt,br) $ nodeoutagebranch(ca,dt,n,br), 1] < sum[ br $ nodeoutagebranch(ca,dt,n,br), 1] } ;

unsolvedDT(ca,dt) = yes $ case2dt(ca,dt);
VSPDModel(ca,dt) = 0 ;
LoopCount(ca,dt) = 1 $ case2dt(ca,dt);
IsNodeDead(ca,dt,n) = 0;
While ( sum[ (ca,dt) $ {unsolvedDT(ca,dt) and case2dt(ca,dt)} , 1 ],

  loop[ (ca,dt) $ {unsolvedDT(ca,dt) and case2dt(ca,dt) and (LoopCount(ca,dt) < maxSolveLoops(ca,dt)) },

*   7a. Reset all sets, parameters and variables -------------------------------
    option clear = t ;
*   Generation variables
    option clear = GENERATION ;
    option clear = GENERATIONBLOCK ;
    option clear = GENERATIONUPDELTA ;
    option clear = GENERATIONDNDELTA ;
*   Purchase variables
    option clear = PURCHASE ;
    option clear = PURCHASEBLOCK ;
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
    option clear = HVDCLINKFLOWDIRECTED_INTEGER ;
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
*   Objective
    option clear = NETBENEFIT ;
*   Violation variables
    option clear = TOTALPENALTYCOST ;
    option clear = DEFICITBUSGENERATION ;
    option clear = SURPLUSBUSGENERATION ;
    option clear = DEFICITRESERVE_CE ;
    option clear = DEFICITRESERVE_ECE ;
    option clear = DEFICITBRANCHSECURITYCONSTRAINT ;
    option clear = SURPLUSBRANCHSECURITYCONSTRAINT ;
    option clear = DEFICITRAMPRATE ;
    option clear = SURPLUSRAMPRATE ;
    option clear = DEFICITBRANCHFLOW ;
    option clear = SURPLUSBRANCHFLOW ;
    option clear = DEFICITMNODECONSTRAINT ;
    option clear = SURPLUSMNODECONSTRAINT ;
*   Scarcity variables
    option clear = SCARCITYCOST;
    option clear = ENERGYSCARCITYBLK ;
    option clear = ENERGYSCARCITYNODE;
*   Risk violation variables
    option clear = RESERVESHORTFALLBLK;
    option clear = RESERVESHORTFALL;
    option clear = RESERVESHORTFALLUNITBLK;
    option clear = RESERVESHORTFALLUNIT;
    option clear = RESERVESHORTFALLGROUPBLK;
    option clear = RESERVESHORTFALLGROUP;
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
*   End reset


*   7b. Initialise current trade period and model data -------------------------
    t(ca,dt)= yes  $ case2dt(ca,dt);

*   Update initial MW if run NRSS, PRSS, NRSL, PRSL
    generationStart(offer(t(ca,dt),o)) $ { sum[ o1, generationStart(ca,dt,o1)] = 0 } = sum[ dt1 $ (ord(dt1) = ord(dt)-1), o_offerEnergy_TP(ca,dt1,o) ] ;

*   4.10 Real Time Pricing - First RTD load calculation --------------------------
    if (studyMode(ca,dt) = 101 or studyMode(ca,dt) = 201,
*       Calculate first target total load [4.10.6.5]
*       Island-level MW load forecast. For the fist loop, uses islandLosses(t,isl)
        TargetTotalLoad(t,isl) = islandMWIPS(t,isl) + islandPDS(t,isl) - LoadCalcLosses(t,isl) + sum[n $ nodeIsland(t,n,isl),dispatchedGeneration(t,n) - dispatchedLoad(t,n) ];

*       Flag if estimate load is scalable [4.10.6.7]
*       If True [1] then ConformingFactor load MW will be scaled in order to calculate EstimatedInitialLoad. If False then EstNonScalableLoad will be assigned directly to EstimatedInitialLoad
        EstLoadIsScalable(t,n) =  1 $ { (LoadIsNCL(t,n) = 0) and (ConformingFactor(t,n) > 0) } ;

*       Calculate estimate non-scalable load [4.10.6.8]
*       For a non-conforming Pnode this will be the NonConformingLoad MW input, for a conforming Pnode this will be the ConformingFactor MW input if that value is negative, otherwise it will be zero
        EstNonScalableLoad(t,n) $ ( LoadIsNCL(t,n) = 1 ) = NonConformingLoad(t,n);
        EstNonScalableLoad(t,n) $ ( LoadIsNCL(t,n) = 0 ) = ConformingFactor(t,n);
        EstNonScalableLoad(t,n) $ ( EstLoadIsScalable(t,n) = 1 ) = 0;

*       Calculate estimate scalable load [4.10.6.10]
*       For a non-conforming Pnode this value will be zero. For a conforming Pnode this value will be the ConformingFactor if it is non-negative, otherwise this value will be zero
        EstScalableLoad(t,n) $ ( EstLoadIsScalable(t,n) = 1 ) = ConformingFactor(t,n);

*       Calculate Scaling applied to ConformingFactor load MW [4.10.6.9] in order to calculate EstimatedInitialLoad
        EstScalingFactor(t,isl) = (islandMWIPS(t,isl) - LoadCalcLosses(t,isl) - sum[ n $ nodeIsland(t,n,isl), EstNonScalableLoad(t,n) ]) / sum[ n $ nodeIsland(t,n,isl), EstScalableLoad(t,n) ] ;

*       Calculate estimate initial load [4.10.6.6]
*       Calculated estimate of initial MW load, available to be used as an alternative to InputInitialLoad
        EstimatedInitialLoad(t,n) $ ( EstLoadIsScalable(t,n) = 1 ) = ConformingFactor(t,n) * sum[ isl $ nodeisland(t,n,isl), EstScalingFactor(t,isl)] ;
        EstimatedInitialLoad(t,n) $ ( EstLoadIsScalable(t,n) = 0 ) = EstNonScalableLoad(t,n);

*       Calculate initial load [4.10.6.2]
*       Value that represents the Pnode load MW at the start of the solution interval. Depending on the inputs this value will be either actual load, an operator applied override or an estimated initial load
        InitialLoad(t,n) = InputInitialLoad(t,n);
        InitialLoad(t,n) $ { (LoadIsOverride(t,n) = 0) and ( (useActualLoad(t) = 0) or (LoadIsBad(t,n) = 1) ) } = EstimatedInitialLoad(t,n) ;
        InitialLoad(t,n) $ { (LoadIsOverride(t,n) = 1) and (useActualLoad(t) = 1) and (InitialLoad(t,n) > MaxLoad(t,n)) } = MaxLoad(t,n) ;
        InitialLoad(t,n) $ DidShortfallTransfer(t,n) = RequiredLoad(t,n);

*       Flag if load is scalable [4.10.6.4]
*       If True [1] then the Pnode InitialLoad will be scaled in order to calculate RequiredLoad, if False then Pnode InitialLoad will be directly assigned to RequiredLoad
        LoadIsScalable(t,n) = 1 $ { (LoadIsNCL(t,n) = 0) and (LoadIsOverride(t,n) = 0) and (InitialLoad(t,n) >= 0) and (ShortfallDisabledScaling(t,n) = 0) and (DidShortfallTransfer(t,n) = 0) } ;

*       Calculate Island-level scaling factor [4.10.6.3] --> applied to InitialLoad in order to calculate RequiredLoad
        LoadScalingFactor(t,isl) = ( TargetTotalLoad(t,isl) - sum[n $ {nodeIsland(t,n,isl) and (LoadIsScalable(t,n) = 0)}, InitialLoad(t,n)] ) / sum[n $ {nodeIsland(t,n,isl) and (LoadIsScalable(t,n) = 1)}, InitialLoad(t,n)] ;

*       Calculate RequiredLoad [4.10.6.1]
        RequiredLoad(t,n) $ { (DidShortfallTransfer(t,n)=0) and (LoadIsScalable(t,n) = 1) } = InitialLoad(t,n) * sum[ isl $ nodeisland(t,n,isl), LoadScalingFactor(t,isl) ];
        RequiredLoad(t,n) $ { (DidShortfallTransfer(t,n)=0) and (LoadIsScalable(t,n) = 0) } = InitialLoad(t,n);
        RequiredLoad(t,n) $ { (DidShortfallTransfer(t,n)=0)                                } = RequiredLoad(t,n) + [InstructedLoadShed(t,n) $ InstructedShedActive(t,n)];

*       Recalculate energy scarcity limits -------------------------------------
        ScarcityEnrgLimit(t,n,blk) = 0 ;
        ScarcityEnrgLimit(t,n,blk) $ { energyScarcityEnabled(t) and (RequiredLoad(t,n) > 0) }                                     = scarcityEnrgNationalFactor(t,blk) * RequiredLoad(t,n);
        ScarcityEnrgPrice(t,n,blk) $ { energyScarcityEnabled(t) and (ScarcityEnrgLimit(t,n,blk) > 0 ) }                           = scarcityEnrgNationalPrice(t,blk) ;

        ScarcityEnrgLimit(t,n,blk) $ { energyScarcityEnabled(t) and (RequiredLoad(t,n) > 0) and scarcityEnrgNodeFactor(t,n,blk) } = scarcityEnrgNodeFactor(t,n,blk) * RequiredLoad(t,n);
        ScarcityEnrgPrice(t,n,blk) $ { energyScarcityEnabled(t) and scarcityEnrgNodeFactorPrice(t,n,blk) }                        = scarcityEnrgNodeFactorPrice(t,n,blk) ;

        ScarcityEnrgLimit(t,n,blk) $ { energyScarcityEnabled(t) and                             scarcityEnrgNodeLimit(t,n,blk)  } = scarcityEnrgNodeLimit(t,n,blk);
        ScarcityEnrgPrice(t,n,blk) $ { energyScarcityEnabled(t) and scarcityEnrgNodeLimitPrice(t,n,blk) }                         = scarcityEnrgNodeLimitPrice(t,n,blk) ;
*       ------------------------------------------------------------------------

*       Update Free Reserve and SharedNFRmax - Pre-processing: Shared Net Free Reserve (NFR) calculation - NMIR (4.5.1.2)
        sharedNFRLoad(t,isl) = sum[ nodeIsland(t,n,isl), RequiredLoad(t,n)] + sum[ (bd,blk) $ bidIsland(t,bd,isl), DemBidMW(t,bd,blk) ] - sharedNFRLoadOffset(t,isl) ;
        sharedNFRMax(t,isl) = Min{ RMTReserveLimitTo(t,isl,'FIR'), sharedNFRFactor(t)*sharedNFRLoad(t,isl) } ;
        FreeReserve(t,isl,resC,riskC) = riskParameter(t,isl,resC,riskC,'freeReserve')
                                     - sum[ isl1 $ (not sameas(isl,isl1)),sharedNFRMax(t,isl1) ] $ { (ord(resC)=1) and ( (GenRisk(riskC)) or (ManualRisk(riskC)) ) and (inputGDXGDate >= jdate(2016,10,20)) } ;
    ) ;


*   7c. Updating the variable bounds before model solve ------------------------

* TN - Pivot or Demand Analysis - revise input data
$Ifi %opMode%=='PVT' $include "Pivot\vSPDSolvePivot_2.gms"
$Ifi %opMode%=='DPS' $include "Demand\vSPDSolveDPS_2.gms"
* TN - Pivot or Demand Analysis - revise input data end

*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS ========================
*   Constraint 6.1.1.1 - Offer blocks
    GENERATIONBLOCK.up(genOfrBlk(t,o,blk)) = EnrgOfrMW(genOfrBlk) ;
    GENERATIONBLOCK.fx(t,o,blk) $ (not genOfrBlk(t,o,blk)) = 0 ;
*   Constraint 6.1.1.3 - Fix the invalid generation to Zero
    GENERATION.fx(offer(t,o)) $ (not posEnrgOfr(offer)) = 0 ;
*   Constraint 6.1.1.4 - Set Upper Bound for intermittent generation
    GENERATION.up(offer(t,o)) $ { windOffer(offer) and priceResponsive(offer) } = min[ potentialMW(offer), ReserveGenerationMaximum(offer) ] ;

*   Dead node pre-processing - zero cleared qunatities 4.3.1
    GENERATION.fx(offer(t,o)) $ sum[n $ offernode(t,o,n),IsNodeDead(t,n)] = 0 ;
    PURCHASE.fx(bid(t,bd)) $ sum[n $ bidnode(t,bd,n),IsNodeDead(t,n)] = 0 ;

*   Constraint 6.1.1.4 & Constraint 6.1.1.5 - Set Upper/Lower Bound for Positive/Negative Demand Bid
    PURCHASEBLOCK.up(demBidBlk(t,bd,blk)) = DemBidMW(t,bd,blk) $ [DemBidMW(t,bd,blk) > 0];
    PURCHASEBLOCK.lo(demBidBlk(t,bd,blk)) = DemBidMW(t,bd,blk) $ [DemBidMW(t,bd,blk) < 0];
    PURCHASEBLOCK.fx(t,bd,blk) $ (not demBidBlk(t,bd,blk))= 0 ;
    PURCHASE.fx(t,bd) $ (sum[blk $ demBidBlk(t,bd,blk), 1] = 0) = 0 ;

*   Constraint 6.1.1.7 - Set Upper Bound for Energy Scaricty Block
    ENERGYSCARCITYBLK.up(t,n,blk) = ScarcityEnrgLimit(t,n,blk) ;
    ENERGYSCARCITYBLK.fx(t,n,blk) $ (not EnergyScarcityEnabled(t)) = 0;
    ENERGYSCARCITYNODE.fx(t,n) $ (not EnergyScarcityEnabled(t)) = 0;
*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS END ====================

*======= HVDC TRANSMISSION EQUATIONS ===========================================
*   Ensure that variables used to specify flow and losses on HVDC link are zero for AC branches and for open HVDC links.
    HVDCLINKFLOW.fx(t,br)   $ (not HVDClink(t,br)) = 0 ;
    HVDCLINKLOSSES.fx(t,br) $ (not HVDClink(t,br)) = 0 ;
*   Apply an upper bound on the weighting parameter based on its definition
    LAMBDA.up(branch,bp) = 1 ;
*   Ensure that the weighting factor value is zero for AC branches and for invalid loss segments on HVDC links
    LAMBDA.fx(HVDClink,bp) $ ( sum[fd $ validLossSegment(HVDClink,bp,fd),1] = 0 ) = 0 ;
    LAMBDA.fx(t,br,bp) $ (not HVDClink(t,br)) = 0 ;
*======= HVDC TRANSMISSION EQUATIONS END =======================================

*======= AC TRANSMISSION EQUATIONS =============================================
*   Ensure that variables used to specify flow and losses on AC branches are zero for HVDC links branches and for open AC branches.
    ACBRANCHFLOW.fx(t,br)              $ (not ACbranch(t,br)) = 0 ;
    ACBRANCHFLOWDIRECTED.fx(t,br,fd)   $ (not ACbranch(t,br)) = 0 ;
    ACBRANCHLOSSESDIRECTED.fx(t,br,fd) $ (not ACbranch(t,br)) = 0 ;
*   Ensure directed block flow and loss block variables are zero for non-AC branches and invalid loss segments on AC branches.
    ACBRANCHFLOWBLOCKDIRECTED.fx(t,br,los,fd)   $ { not(ACbranch(t,br) and validLossSegment(t,br,los,fd)) } = 0 ;
    ACBRANCHLOSSESBLOCKDIRECTED.fx(t,br,los,fd) $ { not(ACbranch(t,br) and validLossSegment(t,br,los,fd)) } = 0 ;
*   Constraint 6.4.1.10 - Ensure that the bus voltage angle for the buses corresponding to the reference nodes and the HVDC nodes are set to zero.
    ACNODEANGLE.fx(t,b) $ sum[ n $ { NodeBus(t,n,b) and refNode(t,n) }, 1 ] = 0 ;
*======= AC TRANSMISSION EQUATIONS END =========================================

*======= RISK & RESERVE EQUATIONS ==============================================
*   Ensure that all the invalid reserve blocks are set to zero for offers and purchasers.
    RESERVEBLOCK.fx(offer(t,o),blk,resC,resT) $ (not resOfrBlk(offer,blk,resC,resT)) = 0 ;
*   Constraint 6.5.3.2 - Reserve block maximum for offers and purchasers.
    RESERVEBLOCK.up(resOfrBlk(t,o,blk,resC,resT)) = ResOfrMW(resOfrBlk) ;
*   Fix the reserve variable for invalid reserve offers. These are offers that are either not connected to the grid or have no reserve quantity offered.
    RESERVE.fx(t,o,resC,resT) $ (not sum[ blk $ resOfrBlk(t,o,blk,resC,resT), 1 ] ) = 0 ;
*   NMIR project variables
    HVDCSENT.fx(t,isl)     $ (HVDCCapacity(t,isl) = 0) = 0 ;
    HVDCSENTLOSS.fx(t,isl) $ (HVDCCapacity(t,isl) = 0) = 0 ;
*   Constraint 6.5.3.2.3 - SPD version 12.0
    SHAREDNFR.up(t,isl) = Max[0,sharedNFRMax(t,isl)] ;
*   No forward reserve sharing if HVDC capacity is zero
    RESERVESHARESENT.fx(t,isl,resC,rd) $ { (HVDCCapacity(t,isl) = 0) and (ord(rd) = 1) } = 0 ;
*   No forward reserve sharing if reserve sharing is disabled
    RESERVESHARESENT.fx(t,isl,resC,rd) $ (reserveShareEnabled(t,resC) = 0) = 0;
*   No reserve sharing to cover HVDC risk
    RESERVESHAREEFFECTIVE.fx(t,isl,resC,HVDCrisk) = 0;
    RESERVESHAREEFFECTIVE.fx(t,isl,resC,HVDCsecRisk) = 0;
*   Constraint 6.5.2.16 - no RP zone if reserve round power disabled
    INZONE.fx(t,isl,resC,z) $ {(ord(z) = 1) and (not reserveRoundPower(t,resC))} = 0;
*   Constraint 6.5.2.17 - no no-reserve zone for SIR zone if reserve RP enabled
    INZONE.fx(t,isl,resC,z) $ {(ord(resC)=2) and (ord(z)=2) and reserveRoundPower(t,resC)} = 0;
*   Fixing Lambda integer variable for energy sent
    LAMBDAHVDCENERGY.fx(t,isl,bp) $ { (HVDCCapacity(t,isl) = 0) and (ord(bp) = 1) } = 1 ;
    LAMBDAHVDCENERGY.fx(t,isl,bp) $ (ord(bp) > 7) = 0 ;
    LAMBDAHVDCRESERVE.fx(t,isl,resC,rd,rsbp) $ { (HVDCCapacity(t,isl) = 0) and (ord(rsbp) = 7) and (ord(rd) = 1) } = 1 ;
    LAMBDAHVDCRESERVE.fx(t,isl,resC,rd,rsbp) $ { (sum[isl1 $ (not sameas(isl1,isl)), HVDCCapacity(t,isl1)] = 0) and (ord(rsbp) < 7) and (ord(rd) = 2) } = 0 ;
*   Contraint 6.5.4.1 - Set Upper Bound for reserve shortfall
    RESERVESHORTFALLBLK.up(t,isl,resC,riskC,blk)         = scarcityResrvIslandLimit(t,isl,resC,blk) $ reserveScarcityEnabled(t);
    RESERVESHORTFALLBLK.fx(t,isl,resC,riskC,blk)         $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALL.fx(t,isl,resC,riskC)                $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALLUNITBLK.up(t,isl,o,resC,riskC,blk)   = scarcityResrvIslandLimit(t,isl,resC,blk) $ reserveScarcityEnabled(t);
    RESERVESHORTFALLUNITBLK.fx(t,isl,o,resC,riskC,blk)   $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALLUNIT.fx(t,isl,o,resC,riskC)          $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALLGROUPBLK.up(t,isl,rg,resC,riskC,blk) = scarcityResrvIslandLimit(t,isl,resC,blk) $ reserveScarcityEnabled(t);
    RESERVESHORTFALLGROUPBLK.fx(t,isl,rg,resC,riskC,blk) $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALLGROUP.fx(t,isl,rg,resC,riskC)        $ (not reserveScarcityEnabled(t)) = 0;
;
*======= RISK & RESERVE EQUATIONS END ==========================================

*   Updating the variable bounds before model solve end


*   7d. Solve Models

*   Solve the NMIR model -------------------------------------------------------
    if ( sum[t(ca,dt), VSPDModel(t)] = 0,

        option bratio = 1 ;
        vSPD_NMIR.Optfile = 1 ;
        vSPD_NMIR.optcr = MIPOptimality ;
        vSPD_NMIR.reslim = MIPTimeLimit ;
        vSPD_NMIR.iterlim = MIPIterationLimit ;
        solve vSPD_NMIR using mip maximizing NETBENEFIT ;
*       Set the model solve status
        ModelSolved = 1 $ { ( (vSPD_NMIR.modelstat = 1) or (vSPD_NMIR.modelstat = 8) ) and ( vSPD_NMIR.solvestat = 1 ) } ;

*       Post a progress message to the console and for use by EMI.
        if (ModelSolved = 1,
            loop (t,
                putclose rep 'The caseID: ' ca.tl ' (' dt.tl ') is 1st solved successfully.'/
                             'Objective function value: ' NETBENEFIT.l:<15:4 /
                             'Violations cost         : ' TOTALPENALTYCOST.l:<15:4 /
            ) ;
        elseif (ModelSolved = 0) and (sequentialSolve = 1),
            loop (t,
                unsolvedDT(t) = no;
                putclose rep 'The caseID: ' ca.tl ' (' dt.tl ') is 1st solved unsuccessfully.'/
            ) ;

        ) ;
display t, LoopCount, VSPDModel, unsolvedDT;
*       Post-Solve - Circulating flow check ------------------------------------
        if((ModelSolved = 1),
            Loop( t $ (VSPDModel(t)=0) ,
*               Check if there are circulating branch flows on loss AC branches
                circularBranchFlowExist(LossBranch(ACbranch(t,br))) $ { sum[fd, ACBRANCHFLOWDIRECTED.l(ACbranch,fd)] - abs(ACBRANCHFLOW.l(ACbranch)) > circularBranchFlowTolerance } = 1 ;
*               Determine the circular branch flow flag on each HVDC pole
                TotalHVDCpoleFlow(t,pole) = sum[ br $ HVDCpoleBranchMap(pole,br), HVDCLINKFLOW.l(t,br) ] ;
                MaxHVDCpoleFlow(t,pole) = smax[ br $ HVDCpoleBranchMap(pole,br), HVDCLINKFLOW.l(t,br) ] ;
                poleCircularBranchFlowExist(t,pole) $ { TotalHVDCpoleFlow(t,pole) - MaxHVDCpoleFlow(t,pole) > circularBranchFlowTolerance } = 1 ;
*               Check if there are circulating branch flows on HVDC
                NorthHVDC(t) = sum[ (isl,b,br) $ { (ord(isl) = 2) and busIsland(t,b,isl) and HVDClinkSendingBus(t,br,b) and HVDClink(t,br) }, HVDCLINKFLOW.l(t,br) ] ;
                SouthHVDC(t) = sum[ (isl,b,br) $ { (ord(isl) = 1) and busIsland(t,b,isl) and HVDClinkSendingBus(t,br,b) and HVDClink(t,br) }, HVDCLINKFLOW.l(t,br) ] ;
                circularBranchFlowExist(t,br) $ { HVDClink(t,br) and LossBranch(t,br) and (NorthHVDC(t) > circularBranchFlowTolerance) and (SouthHVDC(t) > circularBranchFlowTolerance) } = 1 ;
*               Check if there are non-physical losses on HVDC links
                ManualBranchSegmentMWFlow(LossBranch(HVDClink(t,br)),los,fd) $ { ( ord(los) <= branchLossBlocks(HVDClink) ) and validLossSegment(t,br,los,fd) }
                    = Min[ Max( 0, [ abs(HVDCLINKFLOW.l(HVDClink)) - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)] ] ), ( LossSegmentMW(HVDClink,los,fd) - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)] ) ] ;
                ManualLossCalculation(LossBranch(HVDClink(t,br))) = sum[ (los,fd) $ validLossSegment(t,br,los,fd), LossSegmentFactor(HVDClink,los,fd) * ManualBranchSegmentMWFlow(HVDClink,los,fd) ] ;
                NonPhysicalLossExist(LossBranch(HVDClink(t,br))) $ { abs( HVDCLINKLOSSES.l(HVDClink) - ManualLossCalculation(HVDClink) ) > NonPhysicalLossTolerance } = 1 ;
*               Set UseBranchFlowMIP = 1 if the number of circular branch flow or non-physical loss branches exceeds the specified tolerance
                useBranchFlowMIP(t) $ { ( sum[ br $ { ACbranch(t,br) and LossBranch(t,br) }, resolveCircularBranchFlows * circularBranchFlowExist(t,br)]
                                        + sum[ br $ { HVDClink(t,br) and LossBranch(t,br) }, resolveCircularBranchFlows * circularBranchFlowExist(t,br)]
                                        + sum[ br $ { HVDClink(t,br) and LossBranch(t,br) }, resolveHVDCnonPhysicalLosses * NonPhysicalLossExist(t,br) ]
                                        + sum[ pole, resolveCircularBranchFlows * poleCircularBranchFlowExist(t,pole)]
                                        ) > UseBranchFlowMIPTolerance
                                      } = 1 ;
display circularBranchFlowExist,NonPhysicalLossExist,poleCircularBranchFlowExist, ACBRANCHFLOWDIRECTED.l, ACBRANCHFLOW.l ;


            );
*           Post-Solve - Circulating flow check  end

*           A period is unsolved if MILP model is required
            unsolvedDT(t) = yes $ UseBranchFlowMIP(t) ;

*           Post a progress message for use by EMI. Reverting to the sequential mode for integer resolves.
            loop( unsolvedDT(t),
                if( UseBranchFlowMIP(t) >= 1,
                    VSPDModel(t) = 1;
                    putclose rep 'The caseID: ' ca.tl ' requires a vSPD_BranchFlowMIP resolve for period ' dt.tl '.'/
                ) ;
            ) ;
        ) ;
*   Check if the NMIR results are valid end
    ) ;
*   Solve the NMIR model end ---------------------------------------------------
display t, LoopCount, VSPDModel, unsolvedDT;

*   Solve the vSPD_BranchFlowMIP -----------------------------------------------
    if ( smax[t, VSPDModel(t)] = 1,
*       Fix the values of these integer variables that are not needed
        ACBRANCHFLOWDIRECTED_INTEGER.fx(branch(t,br),fd) $ { (not ACbranch(t,br)) or (not LossBranch(branch)) } = 0 ;
*       Fix the integer AC branch flow variable to zero for invalid branches
        ACBRANCHFLOWDIRECTED_INTEGER.fx(t,br,fd) $ (not branch(t,br)) = 0 ;
*       Apply an upper bound on the integer weighting parameter
        LAMBDAINTEGER.up(branch(t,br),bp) = 1 ;
*       Ensure that the weighting factor value is zero for AC branches and for invalid loss segments on HVDC links
        LAMBDAINTEGER.fx(branch(t,br),bp) $ { ACbranch(branch) or ( sum[fd $ validLossSegment(branch,bp,fd),1 ] = 0 ) } = 0 ;
*       Fix the lambda integer variable to zero for invalid branches
        LAMBDAINTEGER.fx(t,br,bp) $ (not branch(t,br)) = 0 ;

        option bratio = 1 ;
        vSPD_BranchFlowMIP.Optfile = 1 ;
        vSPD_BranchFlowMIP.optcr = MIPOptimality ;
        vSPD_BranchFlowMIP.reslim = MIPTimeLimit ;
        vSPD_BranchFlowMIP.iterlim = MIPIterationLimit ;
        solve vSPD_BranchFlowMIP using mip maximizing NETBENEFIT ;
*       Set the model solve status
        ModelSolved = 1 $ { [ ( vSPD_BranchFlowMIP.modelstat = 1) or (vSPD_BranchFlowMIP.modelstat = 8) ] and [ vSPD_BranchFlowMIP.solvestat = 1 ] } ;

*       Post a progress message for use by EMI.
        if(ModelSolved = 1,
*           Flag to show the period that required SOS1 solve
            SOS1_solve(t)  = yes;
            loop(t,
                unsolvedDT(t) = no;
                putclose rep 'The caseID: ' ca.tl ' (' dt.tl ') is 1st solved successfully for branch integer.'/
                             'Objective function value: ' NETBENEFIT.l:<15:4 /
                             'Violations cost         : ' TOTALPENALTYCOST.l:<15:4 /
            ) ;
        else
            loop (t,
                unsolvedDT(t) = yes;
                VSPDModel(t) = 2;
                putclose rep 'The caseID: ' ca.tl ' (' dt.tl ') is 1st solved unsuccessfully for branch integer.'/
            ) ;
        ) ;
    ) ;
*   Solve the vSPD_BranchFlowMIP model end -------------------------------------
display t, LoopCount, VSPDModel, unsolvedDT;

*   ReSolve the NMIR model and stop --------------------------------------------
    if (smax[t, VSPDModel(t)] = 2,

        option bratio = 1 ;
        vSPD_NMIR.Optfile = 1 ;
        vSPD_NMIR.optcr = MIPOptimality ;
        vSPD_NMIR.reslim = MIPTimeLimit ;
        vSPD_NMIR.iterlim = MIPIterationLimit ;
        solve vSPD_NMIR using mip maximizing NETBENEFIT ;
*       Set the model solve status
        ModelSolved = 1 $ { ( (vSPD_NMIR.modelstat = 1) or (vSPD_NMIR.modelstat = 8) ) and ( vSPD_NMIR.solvestat = 1 ) } ;

*       Post a progress message for use by EMI.
        if (ModelSolved = 1,
            loop (t,
                putclose rep 'The caseID: ' ca.tl ' (' dt.tl ') branch flow integer resolve was unsuccessful.' /
                                'Reverting back to base model (NMIR) and solve successfully. ' /
                                'Objective function value: ' NETBENEFIT.l:<15:4 /
                                'Violations cost         : '  TOTALPENALTYCOST.l:<15:4 /
                                'Solution may have circulating flows and/or non-physical losses.' /
            ) ;
        else
            loop (t,
                putclose rep 'The caseID: ' ca.tl ' (' dt.tl ') integer solve was unsuccessful. Reverting back to base model (NMIR) and solve unsuccessfully.' /
            ) ;
        ) ;

        unsolvedDT(t) = no;

*   ReSolve the NMIR model and stop end ----------------------------------------

    ) ;
*   Solve the models end

display t, LoopCount, VSPDModel, unsolvedDT;

*   Post-Solve Checks ----------------------------------------------------------

*   Check for disconnected nodes
$ontext
    8.2 Dead Electrical Island
        If an Electrical Island > 2 has no positive load or if the total energy offered within the Electrical Island is zero then the Electrical Island is determined to be a dead
        Electrical Island and each ACNode in the Electrical Island is added to the set of DeadACNodes and each Pnode in the Electrical Island is added to the set of DeadPnodes.
    8.4 Disconnected Pnodes
        Each Pnode that has a scheduled load of zero and is in the set of DeadPnodes is added to the set of DisconnectedPnodes.
$offtext
    busGeneration(bus(t,b)) = sum[ (o,n) $ { offerNode(t,o,n) and NodeBus(t,n,b) } , NodeBusAllocationFactor(t,n,b) * GENERATION.l(t,o) ] ;
    busLoad(bus(t,b))       = sum[ NodeBus(t,n,b), NodeBusAllocationFactor(t,n,b) * RequiredLoad(t,n) ] ;
    busDisconnected(bus(t,b)) $ { ( [busElectricalIsland(bus) = 0] and [busLoad(bus) = 0] )
                               or ( sum[ b1 $ { busElectricalIsland(t,b1) = busElectricalIsland(bus) } , busLoad(t,b1) ] = 0 )
                               or ( sum[ b1 $ { busElectricalIsland(t,b1) = busElectricalIsland(bus) } , busGeneration(t,b1) ] = 0 ) } = 1 ;

*   Energy Shortfall Check (7.2)
    if( smax[t,runEnrgShortfallTransfer(t)] = 1,

*       Check for dead nodes
        IsNodeDead(t,n) = 1 $ ( sum[b $ { NodeBus(t,n,b) and (busDisconnected(t,b)=0) }, NodeBusAllocationFactor(t,n,b) ] = 0 ) ;
        IsNodeDead(t,n) $ ( sum[b $ NodeBus(t,n,b), busElectricalIsland(t,b) ] = 0 ) = 1 ;
        NodeElectricalIsland(t,n) = smin[b $ NodeBus(t,n,b), busElectricalIsland(t,b)] ;
        InputInitialLoad(t,n) $ { IsNodeDead(t,n) and (NodeElectricalIsland(t,n) > 0) } = 0;

*       Check if a pnode has energy shortfall
        EnergyShortfallMW(t,n) $ Node(t,n) = ENERGYSCARCITYNODE.l(t,n) + sum[ b $ NodeBus(t,n,b), busNodeAllocationFactor(t,b,n) * DEFICITBUSGENERATION.l(t,b) ] ;
        EnergyShortfallMW(t,n) $ { IsNodeDead(t,n) and (NodeElectricalIsland(t,n) > 0) } = 0;

*       a.Checkable Energy Shortfall:
*       If a node has an EnergyShortfallMW greater than zero and the node has LoadIsOverride set to False and the Pnode has InstructedShedActivepn set to False, then EnergyShortfall is checked.
        EnergyShortFallCheck(t,n) = 1 $ { (EnergyShortfallMW(t,n) > 0) and (LoadIsOverride(t,n) = 0) and (instructedShedActive(t,n) = 0) } ;

*       c. Eligible for Removal:
*       An EnergyShortfall is eligible for removal if there is evidence that it is due to a modelling inconsistency (as described below),
*       or if the RTD Required Load calculation used an estimated initial load rather than an actual initial load, or if the node is dead node.
        EligibleShortfallRemoval(t,n) = 1 $ [EnergyShortFallCheck(t,n)  and { PotentialModellingInconsistency(t,n) or (useActualLoad(t) = 0) or (LoadIsBad(t,n) = 1) or (IsNodeDead(t,n) = 1) }] ;

*       d. Shortfall Removal:
*       If the shortfall at a node is eligible for removal then a Shortfall Adjustment quantity is subtracted from the RequiredLoad in order to remove the shortfall.
*       If the node is dead node then the Shortfall Adjustment is equal to EnergyShortfallMW otherwise it's equal to EnergyShortfall plus EnergyShortfallRemovalMargin.
*       If the adjustment would make RequiredLoad negative then RequiredLoad is assigned a value of zero. The adjusted node has DidShortfallTransferpn set to True so that
*       the RTD Required Load calculation does not recalculate its RequiredLoad at this node
        ShortfallAdjustmentMW(t,n) $ EligibleShortfallRemoval(t,n) = [enrgShortfallRemovalMargin(t) $ (IsNodeDead(t,n) = 0) ] + EnergyShortfallMW(t,n) ;

        RequiredLoad(t,n) $ EligibleShortfallRemoval(t,n) = RequiredLoad(t,n) - ShortfallAdjustmentMW(t,n) ;
        RequiredLoad(t,n) $ { EligibleShortfallRemoval(t,n) and (RequiredLoad(t,n) < 0) } = 0 ;
        DidShortfallTransfer(t,n) $ EligibleShortfallRemoval(t,n) = 1 ;

$ontext
e. Shortfall Transfer:
If the previous step adjusts RequiredLoad then the processing will search for a transfer target Pnode to receive the Shortfall Adjustment quantity (the search process is described below).
If a transfer target node is found then the ShortfallAdjustmentMW is added to the RequiredLoad of the transfer target node and the DidShortfallTransfer of the transfer target Pnode flag is set to True.
k. Shortfall Transfer Target:
In the Shortfall Transfer step, the search for a transfer target node proceeds as follows.
The first choice candidate for price transfer source is the PnodeTransferPnode of the target Pnode. If the candidate is ineligible then the new candidate will be the PnodeTransferPnode of the candidate,
if any, but only if this new candidate has not already been visited in this search. The process of locating and checking candidates will continue until an eligible transfer Pnode is located or until no
more candidates are found. A candidate node isn't eligible as a target if it has a non-zero EnergyShortfall in the solution being checked or had one in the solution of a previous solve loop, or if the
candidate node has LoadIsOverridepn set to True, or if the candidate node has InstructedShedActivepn set to True, or if the node with the shortfall is not in Electrical Island 0 and the ElectricalIsland
of the candidate node is not the same as the ElectricalIslandpn of the node with the shortfall, or if the candidate node is in the set of DEADPNODESpn.
$offtext
        unsolvedDT(t) = yes $ sum[n $ EligibleShortfallRemoval(t,n), ShortfallAdjustmentMW(t,n)] ;

        nodeTonode(t,n,n1) = node2node(t,n,n1)
        while( sum[n, ShortfallAdjustmentMW(ca,dt,n)],

*           Check if shortfall from node n is eligibly transfered to node n1
            ShortfallTransferFromTo(nodeTonode(t,n,n1))
                $ { (ShortfallAdjustmentMW(t,n) > 0) and (ShortfallAdjustmentMW(t,n1) = 0) and (CheckedNodeCandidate(t,n1) = 0)
                and (LoadIsOverride(t,n1) = 0) and (InstructedShedActive(t,n1) = 0)
                and [ (NodeElectricalIsland(t,n) = NodeElectricalIsland(t,n1)) or (NodeElectricalIsland(t,n) = 0) ]
                  } = 1;

*           If a transfer target node is found then the ShortfallAdjustmentMW is added to the RequiredLoad of the transfer target node
            RequiredLoad(t,n1) $ (IsNodeDead(t,n1) = 0)= RequiredLoad(t,n1) + sum[ n $ ShortfallTransferFromTo(t,n,n1), ShortfallAdjustmentMW(t,n)] ;

*           If a transfer target node is dead then the ShortfallAdjustmentMW is added to the ShortfallAdjustmentMW of the transfer target node
            ShortfallAdjustmentMW(t,n1) $ (IsNodeDead(t,n1) = 1) = ShortfallAdjustmentMW(t,n1) + sum[ n $ ShortfallTransferFromTo(t,n,n1), ShortfallAdjustmentMW(t,n)] ;

*           and the DidShortfallTransfer of the transfer target node is set to 1
            DidShortfallTransfer(t,n1) $ sum[n, ShortfallTransferFromTo(t,n,n1)] = 1 ;

*           Set ShortfallAdjustmentMW at node n to zero if shortfall can be transfered to a target node
            ShortfallAdjustmentMW(t,n) $ sum[ n1, ShortfallTransferFromTo(t,n,n1)] = 0;

        ) ;

*       f. Scaling Disabled: For an RTD schedule type, when an EnergyShortfallpn is checked but the shortfall is not eligible for removal then ShortfallDisabledScalingpn is set to True
*       which will prevent the RTD Required Load calculation from scaling InitialLoad.
        ShortfallDisabledScaling(t,n) = 1 $ { (EnergyShortFallCheck(t,n)=1) and (EligibleShortfallRemoval(t,n)=0) };
    ) ;
*   Energy Shortfall Check End

    unsolvedDT(t) $ {(studyMode(t) = 101 or studyMode(t) = 201) and (LoopCount(t)=1)} = yes ;
    if ((studyMode(ca,dt) = 101 or studyMode(ca,dt) = 201) and sum[unsolvedDT(t),1],
        putclose rep 'Recalculate RTD Island Loss for next solve'/;
        LoadCalcLosses(t,isl)= Sum[ (br,frB,toB) $ { ACbranch(t,br) and branchBusDefn(t,br,frB,toB) and busIsland(t,toB,isl) }, sum[ fd, ACBRANCHLOSSESDIRECTED.l(t,br,fd) ] + branchFixedLoss(t,br) ]
                             + Sum[ (br,frB,toB) $ { HVDClink(t,br) and branchBusDefn(t,br,frB,toB) and ( busIsland(t,toB,isl) or busIsland(t,frB,isl) ) }, 0.5 * branchFixedLoss(t,br) ]
                             + Sum[ (br,frB,toB) $ { HVDClink(t,br) and branchBusDefn(t,br,frB,toB) and busIsland(t,toB,isl) and (not (busIsland(t,frB,isl))) }, HVDCLINKLOSSES.l(t,br) ] ;
        LoopCount(t) = LoopCount(t) + 1 ;
        loop( (t,isl) $ {unsolvedDT(t) and ( SPDLoadCalcLosses(t,isl) > 0 ) and ( abs( SPDLoadCalcLosses(t,isl) - LoadCalcLosses(t,isl) ) > 0.0005 )},
            putclose rep 'Recalulated losses for ' isl.tl ' are different between vSPD (' LoadCalcLosses(t,isl):<10:5 ') and SPD (' SPDLoadCalcLosses(t,isl):<10:5 ') --> Using SPD calculated losses instead.' ;
*            putclose rep 'Using SPDLoadCalcLosses instead. /' ;
            LoadCalcLosses(t,isl) = SPDLoadCalcLosses(t,isl);

        );
    ) ;
    unsolvedDT(t) $ (LoopCount(t)=maxSolveLoops(t)) = no ;
*   6g. Collect and store results of solved periods into output parameters -----
*   Note: all the price relating outputs such as costs and revenues are calculated in section 7.b

$iftheni.PeriodReport %opMode%=='FTR' $include "FTRental\vSPDSolveFTR_3.gms"
$elseifi.PeriodReport %opMode%=='DWH' $include "DWmode\vSPDSolveDWH_3.gms"
$elseifi.PeriodReport %opMode%=='PVT' $include "Pivot\vSPDSolvePivot_3.gms"
$elseifi.PeriodReport %opMode%=='DPS' $include "Demand\vSPDSolveDPS_3.gms"
$else.PeriodReport

*   Normal vSPD run - write results out for for reporting
    Loop (t $ (not unsolvedDT(t)),


*       6f. Check for disconnected nodes and adjust prices accordingly -------------
$ontext
    8.2 Dead Electrical Island
        If an Electrical Island > 2 has no positive load or if the total energy offered within the Electrical Island is zero then the Electrical Island is determined to be a dead
        Electrical Island and each ACNode in the Electrical Island is added to the set of DeadACNodes and each Pnode in the Electrical Island is added to the set of DeadPnodes.
    8.4 Disconnected Pnodes
        Each Pnode that has a scheduled load of zero and is in the set of DeadPnodes is added to the set of DisconnectedPnodes.
$offtext

        busGeneration(bus(t,b)) = sum[ (o,n) $ { offerNode(t,o,n) and NodeBus(t,n,b) } , NodeBusAllocationFactor(t,n,b) * GENERATION.l(t,o) ] ;
        busLoad(bus(t,b))       = sum[ NodeBus(t,n,b), NodeBusAllocationFactor(t,n,b) * RequiredLoad(t,n) ] ;
        busPrice(bus(t,b))      = ACnodeNetInjectionDefinition2.m(t,b) ;

        busDisconnected(bus(t,b)) $ { (busLoad(bus) = 0) and (busElectricalIsland(bus) = 0) } = 1 ;
        busDisconnected(bus(t,b)) $ { ( sum[ b1 $ { busElectricalIsland(t,b1) = busElectricalIsland(bus) }, busLoad(t,b1) ] = 0) and ( busElectricalIsland(bus) > 0 ) } = 1 ;
*       Set prices at dead buses with non-zero load
        busPrice(bus(t,b)) $ { (busLoad(bus) > 0) and (busElectricalIsland(bus)= 0) } = DeficitBusGenerationPenalty ;
        busPrice(bus(t,b)) $ { (busLoad(bus) < 0) and (busElectricalIsland(bus)= 0) } = -SurplusBusGenerationPenalty ;
*       Set price at identified disconnected buses to 0
        busPrice(bus)$busDisconnected(bus) = 0 ;
*       End Check for disconnected nodes and adjust prices accordingly

*       6f0. Replacing invalid prices after SOS1 (7.1.3)----------------------------
        if ( SOS1_solve(ca,dt),
            busSOSinvalid(ca,dt,b)
                = 1 $ { [ ( busPrice(ca,dt,b) = 0 ) or ( busPrice(ca,dt,b) > 0.9*deficitBusGenerationPenalty ) or ( busPrice(ca,dt,b) < -0.9*surplusBusGenerationPenalty ) ]
                    and bus(ca,dt,b)  and [ not busDisconnected(ca,dt,b) ]  and [ busLoad(ca,dt,b) = busGeneration(ca,dt,b) ]
                    and [ sum[(br,fd) $ { BranchBusConnect(ca,dt,br,b) and branch(ca,dt,br) }, ACBRANCHFLOWDIRECTED.l(ca,dt,br,fd) ] = 0 ]
                    and [ sum[ br     $ { BranchBusConnect(ca,dt,br,b) and branch(ca,dt,br) } , 1 ] > 0 ]
                      };

            numberofbusSOSinvalid(ca,dt) = 2*sum[b, busSOSinvalid(ca,dt,b)];

            While ( sum[b, busSOSinvalid(ca,dt,b)] < numberofbusSOSinvalid(ca,dt) ,
                numberofbusSOSinvalid(ca,dt) = sum[b, busSOSinvalid(ca,dt,b)];

                busPrice(ca,dt,b) $ { busSOSinvalid(ca,dt,b) and ( sum[ b1 $ { [ not busSOSinvalid(ca,dt,b1) ] and sum[ br $ { branch(ca,dt,br) and BranchBusConnect(ca,dt,br,b) and BranchBusConnect(ca,dt,br,b1) }, 1 ] }, 1 ] > 0 ) }
                    = sum[ b1 $ { [ not busSOSinvalid(ca,dt,b1) ] and sum[ br $ { branch(ca,dt,br) and BranchBusConnect(ca,dt,br,b) and BranchBusConnect(ca,dt,br,b1) }, 1 ] }, busPrice(ca,dt,b1) ]
                    / sum[ b1 $ { [ not busSOSinvalid(ca,dt,b1) ] and sum[ br $ { branch(ca,dt,br) and BranchBusConnect(ca,dt,br,b) and BranchBusConnect(ca,dt,br,b1) }, 1 ] }, 1 ];

                busSOSinvalid(ca,dt,b)
                  = 1 $ { [ ( busPrice(ca,dt,b) = 0 ) or ( busPrice(ca,dt,b) > 0.9 * deficitBusGenerationPenalty ) or ( busPrice(ca,dt,b) < -0.9 * surplusBusGenerationPenalty ) ]
                      and bus(ca,dt,b) and [ not busDisconnected(ca,dt,b) ] and [ busLoad(ca,dt,b) = busGeneration(ca,dt,b) ]
                      and [ sum[(br,fd) $ { BranchBusConnect(ca,dt,br,b) and branch(ca,dt,br) }, ACBRANCHFLOWDIRECTED.l(ca,dt,br,fd) ] = 0 ]
                      and [ sum[ br $ { BranchBusConnect(ca,dt,br,b) and branch(ca,dt,br) }, 1 ] > 0 ]
                        };
            );
        );
*   End Replacing invalid prices after SOS1 (7.1.3) ----------------------------


*   Reporting at trading period start
*       Node level output
        o_nodeGeneration_TP(t,n) $ Node(t,n) = sum[ o $ offerNode(t,o,n), GENERATION.l(t,o) ] ;
        o_nodeLoad_TP(t,n)       $ Node(t,n) = RequiredLoad(t,n) + sum[ bd $ bidNode(t,bd,n), PURCHASE.l(t,bd) ];
        o_nodePrice_TP(t,n)      $ Node(t,n) = sum[ b $ NodeBus(t,n,b), NodeBusAllocationFactor(t,n,b) * busPrice(t,b) ] ;

$ontext
        8.3.5 Dead Price Replacement
        Dead Price Replacement is applied to the Schedule Types that produce settlement prices, i.e., RTD, RTDP, PRS. For each Pnode in the set of DeadPnodes the Dead Price Replacement processing will search for a suitable
        price transfer source Pnode to provide a replacement price

        The first choice candidate for price transfer source is the PnodeTransferPnode of the target Pnode. If the candidate is ineligible then the new candidate will be the PnodeTransferPnodepn of the candidate, if any, but
        only if this new candidate has not already been visited in this search. The process of locating and checking candidates will continue until an eligible transfer Pnode is located or until no more candidates are found.

        A candidate Pnode is not eligible as a price source if it is in the set of DEADPNODESpn, or if the source candidate Pnode is not in the same Electrical Island as the target Pnode unless the target Pnode is in Island 0,
        i.e., if the target of the price transfer is in Electrical Island 0 then it does not matter which Electrical Island the price source is in, provided the price source is not a dead Pnode.

        Note that a candidate Pnode with a shortfall is eligible.

        If an eligible price transfer source is found then the energy price of the dead Pnode and its associated ACNode are assigned the energy price of the transfer Pnode. If no eligible price is found then the dead Pnode
        and its associated ACNode are assigned a price of zero.
$offtext
        if (runPriceTransfer(t) and [(studyMode(t) = 101) or (studyMode(t) = 201) or (studyMode(t) = 130) or (studyMode(t) = 131)],
            o_nodeDead_TP(t,n) = 1 $ { ( sum[b $ {NodeBus(t,n,b) and (not busDisconnected(t,b)) }, NodeBusAllocationFactor(t,n,b) ] = 0 )} ;
            o_nodeDeadPrice_TP(t,n) $ o_nodeDead_TP(t,n) = 1;
            o_nodeDeadPriceFrom_TP(t,n,n1) = 1 $ { [ ( Smin[b $ NodeBus(t,n,b), busElectricalIsland(t,b)] = Smin[b1 $ NodeBus(t,n1,b1), busElectricalIsland(t,b1)] )
                                                  or ( Smin[b $ NodeBus(t,n,b), busElectricalIsland(t,b)] = 0 ) ] and o_nodeDead_TP(t,n) and node2node(t,n,n1) and ( o_nodeDead_TP(t,n1) = 0)  };
            while (sum[ n $ o_nodeDead_TP(t,n), o_nodeDeadPrice_TP(t,n) ],
                o_nodePrice_TP(t,n) $ { o_nodeDead_TP(t,n) and o_nodeDeadPrice_TP(t,n) } = sum[n1 $ o_nodeDeadPriceFrom_TP(t,n,n1), o_nodePrice_TP(t,n1) ] ;
                o_nodeDeadPrice_TP(t,n) = 1 $ sum[n1 $ o_nodeDead_TP(t,n1), o_nodeDeadPriceFrom_TP(t,n,n1) ];
                o_nodeDeadPriceFrom_TP(t,n,n2) $ o_nodeDeadPrice_TP(t,n) = 1 $ { sum[ n1 $ { node2node(t,n1,n2) and o_nodeDeadPriceFrom_TP(t,n,n1) }, 1 ] } ;
                o_nodeDeadPriceFrom_TP(t,n,n1) $ o_nodeDead_TP(t,n1) = 0 ;
            ) ;
        ) ;

*       Offer output
        o_offerEnergy_TP(t,o)   $ offer(t,o) = GENERATION.l(t,o) ;
        o_offerRes_TP(t,o,resC) $ offer(t,o) = sum[ resT, RESERVE.l(t,o,resC,resT) ] ;
        o_offerFIR_TP(t,o)      $ offer(t,o) = sum[ resC $ (ord(resC) = 1),o_offerRes_TP(t,o,resC) ] ;
        o_offerSIR_TP(t,o)      $ offer(t,o) = sum[ resC $ (ord(resC) = 2),o_offerRes_TP(t,o,resC) ] ;

*       Risk group output
        o_groupEnergy_TP(t,rg,GenRisk)   = sum[ o $ riskGroupOffer(t,rg,o,GenRisk), o_offerEnergy_TP(t,o) ];
        o_groupFKband_TP(t,rg,GenRisk)   = sum[ o $ riskGroupOffer(t,rg,o,GenRisk), FKBand(t,o) ];
        o_groupRes_TP(t,rg,resC,GenRisk) = sum[ o $ riskGroupOffer(t,rg,o,GenRisk), o_offerRes_TP(t,o,resC)];

*       Bus level output
        o_busGeneration_TP(t,b) $ bus(t,b) = busGeneration(t,b) ;
        o_busLoad_TP(t,b)       $ bus(t,b) = busLoad(t,b) + sum[ (bd,n) $ { bidNode(t,bd,n) and NodeBus(t,n,b) }, PURCHASE.l(t,bd) ];
        o_busDeficit_TP(t,b)    $ bus(t,b) = DEFICITBUSGENERATION.l(t,b) + sum[n, NodeBusAllocationFactor(t,n,b)*ENERGYSCARCITYNODE.l(t,n)];
        o_busSurplus_TP(t,b)    $ bus(t,b) = SURPLUSBUSGENERATION.l(t,b) ;
        o_busPrice_TP(t,b)      $ bus(t,b) = busPrice(t,b) ;
        o_busPrice_TP(t,b)      $ sum[n $ NodeBus(t,n,b), o_nodeDead_TP(t,n)] = sum[n $ NodeBus(t,n,b), o_nodePrice_TP(t,n) * NodeBusAllocationFactor(t,n,b)]  ;

*       Node level output
        totalBusAllocation(t,b) $ bus(t,b) = sum[ n $ Node(t,n), NodeBusAllocationFactor(t,n,b)];
        busNodeAllocationFactor(t,b,n) $ (totalBusAllocation(t,b) > 0) = NodeBusAllocationFactor(t,n,b) / totalBusAllocation(t,b) ;

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
        unmappedDeficitBus(t,b) $ o_busDeficit_TP(t,b) = yes $ (sum[ n, busNodeAllocationFactor(t,b,n)] = 0);
        changedDeficitBus(t,b) = no;

        If (sum[b $ unmappedDeficitBus(t,b), 1],

            temp_busDeficit_TP(t,b) = o_busDeficit_TP(t,b);

            loop (b $ unmappedDeficitBus(t,b),
                o_busDeficit_TP(t,b1)   $ sum[ br $ { ( branchLossBlocks(t,br)=0 ) and ( branchBusDefn(t,br,b1,b) or branchBusDefn(t,br,b,b1) ) }, 1 ] = o_busDeficit_TP(t,b1) + o_busDeficit_TP(t,b) ;
                changedDeficitBus(t,b1) $ sum[ br $ { ( branchLossBlocks(t,br)=0 ) and ( branchBusDefn(t,br,b1,b) or branchBusDefn(t,br,b,b1) ) }, 1 ] = yes;

                unmappedDeficitBus(t,b) = no;  changedDeficitBus(t,b) = no;  o_busDeficit_TP(t,b) = 0;
            ) ;

            Loop (n $ sum[ b $ changedDeficitBus(t,b), busNodeAllocationFactor(t,b,n)],
                o_nodePrice_TP(t,n) = deficitBusGenerationPenalty ;
                o_nodeDeficit_TP(t,n) = sum[ b $ busNodeAllocationFactor(t,b,n), busNodeAllocationFactor(t,b,n) * o_busDeficit_TP(t,b) ] ;
            ) ;

            o_busDeficit_TP(t,b) = temp_busDeficit_TP(t,b);
        ) ;
* TN - post processing unmapped generation deficit buses end

        o_nodeDeficit_TP(t,n) $ Node(t,n)
            = ENERGYSCARCITYNODE.l(t,n) + sum[ b $ NodeBus(t,n,b), busNodeAllocationFactor(t,b,n) * DEFICITBUSGENERATION.l(t,b) ] ;

        o_nodeSurplus_TP(t,n) $ Node(t,n) = sum[ b $ NodeBus(t,n,b), busNodeAllocationFactor(t,b,n) * SURPLUSBUSGENERATION.l(t,b) ] ;

*       branch output
        o_branchFlow_TP(t,br) $ ACbranch(t,br) = ACBRANCHFLOW.l(t,br);
        o_branchFlow_TP(t,br) $ HVDClink(t,br) = HVDCLINKFLOW.l(t,br);

        o_branchDynamicLoss_TP(t,br) $  ACbranch(t,br) = sum[ fd, ACBRANCHLOSSESDIRECTED.l(t,br,fd) ] ;
        o_branchDynamicLoss_TP(t,br) $ HVDClink(t,br)  = HVDCLINKLOSSES.l(t,br) ;
        o_branchFixedLoss_TP(t,br) $ branch(t,br) = branchFixedLoss(t,br) ;
        o_branchTotalLoss_TP(t,br) $ branch(t,br) = o_branchDynamicLoss_TP(t,br) + o_branchFixedLoss_TP(t,br) ;

        o_branchMarginalPrice_TP(t,br) $ ACbranch(t,br) = sum[ fd, ACbranchMaximumFlow.m(t,br,fd) ] ;
        o_branchMarginalPrice_TP(t,br) $ HVDClink(t,br) = HVDClinkMaximumFlow.m(t,br) ;

        o_branchCapacity_TP(t,br) $ branch(t,br) = sum[ fd $ ( ord(fd) = 1 ), branchCapacity(t,br,fd)] $  { o_branchFlow_TP(t,br) >= 0 }
                                                 + sum[ fd $ ( ord(fd) = 2 ), branchCapacity(t,br,fd)] $  { o_branchFlow_TP(t,br) < 0 } ;

*       bid output
        o_bidEnergy_TP(t,bd)  $ bid(t,bd) = PURCHASE.l(t,bd) ;
        o_bidTotalMW_TP(t,bd) $ bid(t,bd) = sum[ blk, DemBidMW(t,bd,blk) ] ;

*       Violation reporting based on the CE and ECE
        o_ResViolation_TP(t,isl,resC) = DEFICITRESERVE_CE.l(t,isl,resC) + DEFICITRESERVE_ECE.l(t,isl,resC)  ;
        o_FIRviolation_TP(t,isl) = sum[ resC $ (ord(resC) = 1), o_ResViolation_TP(t,isl,resC) ] ;
        o_SIRviolation_TP(t,isl) = sum[ resC $ (ord(resC) = 2), o_ResViolation_TP(t,isl,resC) ] ;

*       Risk marginal prices and shortfall outputs
        o_GenRiskPrice_TP(t,isl,o,resC,GenRisk)     = -GenIslandRiskCalculation_1.m(t,isl,o,resC,GenRisk) ;
        o_GenRiskShortfall_TP(t,isl,o,resC,GenRisk) = RESERVESHORTFALLUNIT.l(t,isl,o,resC,GenRisk) ;

        o_HVDCSecRiskPrice_TP(t,isl,o,resC,HVDCSecRisk)     = -HVDCIslandSecRiskCalculation_GEN_1.m(t,isl,o,resC,HVDCSecRisk) ;
        o_HVDCSecRiskShortfall_TP(t,isl,o,resC,HVDCSecRisk) = RESERVESHORTFALLUNIT.l(t,isl,o,resC,HVDCSecRisk) ;

        o_GenRiskGroupPrice_TP(t,isl,rg,resC,GenRisk)     = -GenIslandRiskGroupCalculation_1.m(t,isl,rg,resC,GenRisk) ;
        o_GenRiskGroupShortfall_TP(t,isl,rg,resC,GenRisk) = RESERVESHORTFALLGROUP.l(t,isl,rg,resC,GenRisk) ;

        o_HVDCRiskPrice_TP(t,isl,resC,HVDCrisk)     = -HVDCIslandRiskCalculation.m(t,isl,resC,HVDCrisk);
        o_HVDCRiskShortfall_TP(t,isl,resC,HVDCrisk) = RESERVESHORTFALL.l(t,isl,resC,HVDCrisk);

        o_ManualRiskPrice_TP(t,isl,resC,ManualRisk)     = -ManualIslandRiskCalculation.m(t,isl,resC,ManualRisk) ;
        o_ManualRiskShortfall_TP(t,isl,resC,ManualRisk) = RESERVESHORTFALL.l(t,isl,resC,ManualRisk) ;

        o_HVDCSecManualRiskPrice_TP(t,isl,resC,HVDCSecRisk)     = -HVDCIslandSecRiskCalculation_Manu_1.m(t,isl,resC,HVDCSecRisk);
        o_HVDCSecManualRiskShortfall_TP(t,isl,resC,HVDCSecRisk) = RESERVESHORTFALL.l(t,isl,resC,HVDCSecRisk) ;

*       Security constraint data
        o_brConstraintSense_TP(t,brCstr) $ branchConstraint(t,brCstr) = branchConstraintSense(t,brCstr) ;
        o_brConstraintRHS_TP(t,brCstr) $ branchConstraint(t,brCstr)   = branchConstraintLimit(t,brCstr) ;
        o_brConstraintLHS_TP(t,brCstr) $ branchConstraint(t,brCstr)   = [ branchSecurityConstraintLE.l(t,brCstr) $ (branchConstraintSense(t,brCstr) = -1) ]
                                                                      + [ branchSecurityConstraintGE.l(t,brCstr) $ (branchConstraintSense(t,brCstr) =  1) ]
                                                                      + [ branchSecurityConstraintEQ.l(t,brCstr) $ (branchConstraintSense(t,brCstr) =  0) ];
        o_brConstraintPrice_TP(t,brCstr) $ branchConstraint(t,brCstr) = [ branchSecurityConstraintLE.m(t,brCstr) $ (branchConstraintSense(t,brCstr) = -1) ]
                                                                      + [ branchSecurityConstraintGE.m(t,brCstr) $ (branchConstraintSense(t,brCstr) =  1) ]
                                                                      + [ branchSecurityConstraintEQ.m(t,brCstr) $ (branchConstraintSense(t,brCstr) =  0) ];
*       Mnode constraint data
        o_MnodeConstraintSense_TP(t,MnodeCstr) $ MnodeConstraint(t,MnodeCstr) = MnodeConstraintSense(t,MnodeCstr) ;
        o_MnodeConstraintRHS_TP(t,MnodeCstr)   $ MnodeConstraint(t,MnodeCstr) = MnodeConstraintLimit(t,MnodeCstr) ;
        o_MnodeConstraintLHS_TP(t,MnodeCstr)   $ MnodeConstraint(t,MnodeCstr) = [ MnodeSecurityConstraintLE.l(t,MnodeCstr) $ (MnodeConstraintSense(t,MnodeCstr) = -1) ]
                                                                              + [ MnodeSecurityConstraintGE.l(t,MnodeCstr) $ (MnodeConstraintSense(t,MnodeCstr) = 1)  ]
                                                                              + [ MnodeSecurityConstraintEQ.l(t,MnodeCstr) $ (MnodeConstraintSense(t,MnodeCstr) = 0)  ] ;
        o_MnodeConstraintPrice_TP(t,MnodeCstr) $ MnodeConstraint(t,MnodeCstr) = [ MnodeSecurityConstraintLE.m(t,MnodeCstr) $ (MnodeConstraintSense(t,MnodeCstr) = -1) ]
                                                                              + [ MnodeSecurityConstraintGE.m(t,MnodeCstr) $ (MnodeConstraintSense(t,MnodeCstr) = 1)  ]
                                                                              + [ MnodeSecurityConstraintEQ.m(t,MnodeCstr) $ (MnodeConstraintSense(t,MnodeCstr) = 0)  ] ;
*       Island output
        o_ResPrice_TP(t,isl,resC)   = IslandReserveCalculation.m(t,isl,resC);
        o_FIRprice_TP(t,isl)        = sum[ resC $ (ord(resC) = 1), o_ResPrice_TP(t,isl,resC) ];
        o_SIRprice_TP(t,isl)        = sum[ resC $ (ord(resC) = 2), o_ResPrice_TP(t,isl,resC) ];
        o_islandGen_TP(t,isl)       = sum[ b $ busIsland(t,b,isl), busGeneration(t,b) ] ;
        o_islandClrBid_TP(t,isl)    = sum[ bd $ bidIsland(t,bd,isl), PURCHASE.l(t,bd) ] ;
        o_islandLoad_TP(t,isl)      = sum[ b $ busIsland(t,b,isl), busLoad(t,b) ] + o_islandClrBid_TP(t,isl) ;
        o_ResCleared_TP(t,isl,resC) = ISLANDRESERVE.l(t,isl,resC);
        o_FirCleared_TP(t,isl)      = sum[ resC $ (ord(resC) = 1), o_ResCleared_TP(t,isl,resC) ];
        o_SirCleared_TP(t,isl)      = sum[ resC $ (ord(resC) = 2), o_ResCleared_TP(t,isl,resC) ];
        o_islandBranchLoss_TP(t,isl)= sum[ (br,frB,toB) $ { ACbranch(t,br) and busIsland(t,toB,isl) and branchBusDefn(t,br,frB,toB) }, o_branchTotalLoss_TP(t,br) ] ;
        o_HVDCflow_TP(t,isl)        = sum[ (br,frB,toB) $ { HVDClink(t,br) and busIsland(t,frB,isl) and branchBusDefn(t,br,frB,toB) }, o_branchFlow_TP(t,br) ] ;
        o_HVDCpoleFixedLoss_TP(t,isl) = sum[ (br,frB,toB) $ { HVDClink(t,br) and branchBusDefn(t,br,frB,toB) and ( busIsland(t,toB,isl) or busIsland(t,frB,isl) ) }, 0.5 * o_branchFixedLoss_TP(t,br) ] ;
        o_HVDCloss_TP(t,isl)  = o_HVDCpoleFixedLoss_TP(t,isl)  + sum[ (br,frB,toB) $ { HVDClink(t,br) and branchBusDefn(t,br,frB,toB) and busIsland(t,toB,isl) and (not (busIsland(t,frB,isl))) }, o_branchDynamicLoss_TP(t,br) ] ;
        o_HVDCreceived(t,isl) = HVDCREC.l(t,isl);
        o_HVDCRiskSubtractor(t,isl,resC,HVDCrisk) = RISKOFFSET.l(t,isl,resC,HVDCrisk) ;

*       Island shared reserve output
        o_EffectiveRes_TP(t,isl,resC,riskC) $ reserveShareEnabled(t,resC) = RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ;
        If (sum[ resC $ (ord(resC) = 1), reserveShareEnabled(t,resC)],
            o_FirSent_TP(t,isl)     = sum[ (rd,resC) $ (ord(resC) = 1), RESERVESHARESENT.l(t,isl,resC,rd)];
            o_FirReceived_TP(t,isl) = sum[ (rd,resC) $ (ord(resC) = 1), RESERVESHARERECEIVED.l(t,isl,resC,rd) ];
            o_FirEffectiveCE_TP(t,isl)  = smax[ (resC,riskC) $ { (ord(resC) = 1) and ContingentEvents(riskC) }, RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ];
            o_FirEffectiveECE_TP(t,isl) = smax[ (resC,riskC) $ { (ord(resC) = 1) and ExtendedContingentEvent(riskC) } , RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ];
            o_FirEffReport_TP(t,isl)    = smax[ (resC,riskC) $ (ord(resC)=1), RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ];
        ) ;
        If (sum[ resC $ (ord(resC) = 2), reserveShareEnabled(t,resC)],
            o_SirSent_TP(t,isl)     = sum[ (rd,resC) $ (ord(resC) = 2),  RESERVESHARESENT.l(t,isl,resC,rd) ];
            o_SirReceived_TP(t,isl) = sum[ (fd,resC) $ (ord(resC) = 2),  RESERVESHARERECEIVED.l(t,isl,resC,fd) ];
            o_SirEffectiveCE_TP(t,isl)  = smax[ (resC,riskC) $ { (ord(resC) = 2) and ContingentEvents(riskC) }, RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ];
            o_SirEffectiveECE_TP(t,isl) = smax[ (resC,riskC) $ { (ord(resC) = 2) and ExtendedContingentEvent(riskC) }, RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ];
            o_SirEffReport_TP(t,isl)    = smax[ (resC,riskC) $ (ord(resC)=2), RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ];
        ) ;
        o_TotalIslandReserve(t,isl,resC,riskC) = o_ResCleared_TP(t,isl,resC) + o_EffectiveRes_TP(t,isl,resC,riskC);


*       Additional output for audit reporting
        o_ACbusAngle(t,b) = ACNODEANGLE.l(t,b) ;

*       Check if there are non-physical losses on AC branches
        ManualBranchSegmentMWFlow(LossBranch(ACbranch(t,br)),los,fd) $ { ( ord(los) <= branchLossBlocks(ACbranch) ) and validLossSegment(ACbranch,los,fd) and ( ACBRANCHFLOWDIRECTED.l(ACbranch,fd) > 0 ) }
            = Min[ Max( 0, [ abs(o_branchFlow_TP(t,br)) - [LossSegmentMW(ACbranch,los-1,fd) $ (ord(los) > 1)] ] ),
                   ( LossSegmentMW(ACbranch,los,fd) - [LossSegmentMW(ACbranch,los-1,fd) $ (ord(los) > 1)] ) ] ;

        ManualBranchSegmentMWFlow(LossBranch(HVDClink(t,br)),los,fd) $ { ( ord(los) <= branchLossBlocks(HVDClink) ) and validLossSegment(HVDClink,los,fd) and ( ord(fd) = 1 ) }
            = Min[ Max( 0, [ abs(o_branchFlow_TP(t,br)) - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)] ] ),
                   ( LossSegmentMW(HVDClink,los,fd) - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)] ) ] ;

        ManualLossCalculation(LossBranch(branch(t,br))) = sum[ (los,fd), LossSegmentFactor(branch,los,fd)  * ManualBranchSegmentMWFlow(branch,los,fd) ] ;
        o_nonPhysicalLoss(t,br) = o_branchDynamicLoss_TP(t,br) - ManualLossCalculation(t,br) ;

        o_lossSegmentBreakPoint(t,br,los) = sum [ fd $ { validLossSegment(t,br,los,fd) and (ord(fd) = 1) }, LossSegmentMW(t,br,los,fd) ] $ { o_branchFlow_TP(t,br) >= 0 }
                                          + sum [ fd $ { validLossSegment(t,br,los,fd) and (ord(fd) = 2) }, LossSegmentMW(t,br,los,fd) ] $ { o_branchFlow_TP(t,br) < 0 } ;

        o_lossSegmentFactor(t,br,los) = sum [ fd $ { validLossSegment(t,br,los,fd) and (ord(fd) = 1) }, LossSegmentFactor(t,br,los,fd) ] $ { o_branchFlow_TP(t,br) >= 0 }
                                      + sum [ fd $ { validLossSegment(t,br,los,fd) and (ord(fd) = 2) }, LossSegmentFactor(t,br,los,fd) ] $ { o_branchFlow_TP(t,br) < 0 }  ;

        o_PLRO_FIR_TP(t,o) $ offer(t,o) = sum[(resC,PLRO) $ (ord(resC)=1), RESERVE.l(t,o,resC,PLRO)] ;
        o_PLRO_SIR_TP(t,o) $ offer(t,o) = sum[(resC,PLRO) $ (ord(resC)=2), RESERVE.l(t,o,resC,PLRO)] ;
        o_TWRO_FIR_TP(t,o) $ offer(t,o) = sum[(resC,TWRO) $ (ord(resC)=1), RESERVE.l(t,o,resC,TWRO)] ;
        o_TWRO_SIR_TP(t,o) $ offer(t,o) = sum[(resC,TWRO) $ (ord(resC)=2), RESERVE.l(t,o,resC,TWRO)] ;
        o_ILRO_FIR_TP(t,o) $ offer(t,o) = sum[(resC,ILRO) $ (ord(resC)=1), RESERVE.l(t,o,resC,ILRO)] ;
        o_ILRO_SIR_TP(t,o) $ offer(t,o) = sum[ (resC,ILRO)$ (ord(resC)=2), RESERVE.l(t,o,resC,ILRO)] ;
        o_ILbus_FIR_TP(t,b) = sum[ (o,n) $ { NodeBus(t,n,b) and offerNode(t,o,n) }, o_ILRO_FIR_TP(t,o) ] ;
        o_ILbus_SIR_TP(t,b) = sum[ (o,n) $ { NodeBus(t,n,b) and offerNode(t,o,n) }, o_ILRO_SIR_TP(t,o) ] ;

        o_generationRiskLevel(t,isl,o,resC,GenRisk) = GENISLANDRISK.l(t,isl,o,resC,GenRisk) + RESERVESHAREEFFECTIVE.l(t,isl,resC,GenRisk) ;
        o_HVDCriskLevel(t,isl,resC,HVDCrisk)        = ISLANDRISK.l(t,isl,resC,HVDCrisk) ;
        o_manuRiskLevel(t,isl,resC,ManualRisk)      = ISLANDRISK.l(t,isl,resC,ManualRisk)   + RESERVESHAREEFFECTIVE.l(t,isl,resC,ManualRisk) ;
        o_genHVDCriskLevel(t,isl,o,resC,HVDCsecRisk)= HVDCGENISLANDRISK.l(t,isl,o,resC,HVDCsecRisk) ;
        o_manuHVDCriskLevel(t,isl,resC,HVDCsecRisk) = HVDCMANISLANDRISK.l(t,isl,resC,HVDCsecRisk);
        o_generationRiskGroupLevel(t,isl,rg,resC,GenRisk) $ islandRiskGroup(t,isl,rg,GenRisk) = GENISLANDRISKGROUP.l(t,isl,rg,resC,GenRisk) + RESERVESHAREEFFECTIVE.l(t,isl,resC,GenRisk) ;

*       FIR and SIR required based on calculations of the island risk to overcome reporting issues of the risk setter under degenerate conditions when reserve price = 0 - See below
        o_ReserveReqd_TP(t,isl,resC)
            = Max[ 0,
                   smax[(o,GenRisk)     , o_generationRiskLevel(t,isl,o,resC,GenRisk)],
                   smax[ HVDCrisk       , o_HVDCriskLevel(t,isl,resC,HVDCrisk) ] ,
                   smax[ ManualRisk     , o_manuRiskLevel(t,isl,resC,ManualRisk) ] ,
                   smax[ (o,HVDCsecRisk), o_genHVDCriskLevel(t,isl,o,resC,HVDCsecRisk) ] ,
                   smax[ HVDCsecRisk    , o_manuHVDCriskLevel(t,isl,resC,HVDCsecRisk)  ] ,
                   smax[ (rg,GenRisk)   , o_generationRiskGroupLevel(t,isl,rg,resC,GenRisk)  ]
                 ] ;

        o_FIRreqd_TP(t,isl) = sum[ resC $ (ord(resC)=1), o_ReserveReqd_TP(t,isl,resC) ] ;
        o_SIRreqd_TP(t,isl) = sum[ resC $ (ord(resC)=2), o_ReserveReqd_TP(t,isl,resC) ] ;

*       Summary reporting by trading period
        o_solveOK_TP(t)       = ModelSolved ;
        o_systemCost_TP(t)    = SYSTEMCOST.l(t) ;
        o_systemBenefit_TP(t) = SYSTEMBENEFIT.l(t) ;
        o_penaltyCost_TP(t)   = SYSTEMPENALTYCOST.l(t) ;
        o_ofv_TP(t)           = o_systemBenefit_TP(t) - o_systemCost_TP(t) - o_penaltyCost_TP(t)
                              - SCARCITYCOST.l(t) - RESERVESHAREPENALTY.l(t)
                              + sum[(n,blk), ScarcityEnrgLimit(t,n,blk) * ScarcityEnrgPrice(t,n,blk)];


*       Separete violation reporting at trade period level
        o_defGenViolation_TP(t)      = sum[ b, o_busDeficit_TP(t,b) ] ;
        o_surpGenViolation_TP(t)     = sum[ b, o_busSurplus_TP(t,b) ] ;
        o_surpBranchFlow_TP(t)       = sum[ br$branch(t,br), SURPLUSBRANCHFLOW.l(t,br) ] ;
        o_defRampRate_TP(t)          = sum[ o $ offer(t,o), DEFICITRAMPRATE.l(t,o) ] ;
        o_surpRampRate_TP(t)         = sum[ o $ offer(t,o), SURPLUSRAMPRATE.l(t,o) ] ;
        o_surpBranchGroupConst_TP(t) = sum[ brCstr $ branchConstraint(t,brCstr), SURPLUSBRANCHSECURITYCONSTRAINT.l(t,brCstr) ] ;
        o_defBranchGroupConst_TP(t)  = sum[ brCstr $ branchConstraint(t,brCstr), DEFICITBRANCHSECURITYCONSTRAINT.l(t,brCstr) ] ;
        o_defMnodeConst_TP(t)        = sum[ MnodeCstr $ MnodeConstraint(t,MnodeCstr), DEFICITMnodeCONSTRAINT.l(t,MnodeCstr) ] ;
        o_surpMnodeConst_TP(t)       = sum[ MnodeCstr $ MnodeConstraint(t,MnodeCstr), SURPLUSMnodeCONSTRAINT.l(t,MnodeCstr) ] ;
        o_defResv_TP(t)              = sum[ (isl,resC) , o_ResViolation_TP(t,isl,resC) ] ;

*   Reporting at trading period end
    ) ;


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


*   Offer level - This does not include revenue from wind generators for
*   final pricing because the wind generation is netted off against load
*   at the particular bus for the final pricing solves

$endif.SummaryReport


* 8b. Calculating price-relating outputs --------------------------------------

$iftheni.PriceRelatedOutputs %opMode%=='DWH'
$elseifi.PriceRelatedOutputs %opMode%=='DPS'
$elseifi.PriceRelatedOutputs %opMode%=='PVT'
$elseifi.PriceRelatedOutputs %opMode%=='FTR' $include "FTRental\vSPDSolveFTR_3a.gms"
$else.PriceRelatedOutputs

* branch output update
o_branchFromBusPrice_TP(ca,dt,br) $ branch(ca,dt,br) = sum[ b $ branchFrBus(ca,dt,br,b), o_busPrice_TP(ca,dt,b) ] ;
o_branchToBusPrice_TP(ca,dt,br) $ branch(ca,dt,br)   = sum[ b $ branchToBus(ca,dt,br,b), o_busPrice_TP(ca,dt,b) ] ;
o_branchTotalRentals_TP(ca,dt,br) $ { branch(ca,dt,br) and (o_branchFlow_TP(ca,dt,br) >= 0) } = (intervalDuration(ca,dt)/60) * [ o_branchToBusPrice_TP(ca,dt,br)*[o_branchFlow_TP(ca,dt,br) - o_branchTotalLoss_TP(ca,dt,br)] - o_branchFromBusPrice_TP(ca,dt,br)*o_branchFlow_TP(ca,dt,br) ] ;
o_branchTotalRentals_TP(ca,dt,br) $ { branch(ca,dt,br) and (o_branchFlow_TP(ca,dt,br) < 0) }  = (intervalDuration(ca,dt)/60) * [ o_branchToBusPrice_TP(ca,dt,br)*o_branchFlow_TP(ca,dt,br) - o_branchFromBusPrice_TP(ca,dt,br)*[o_branchTotalLoss_TP(ca,dt,br) + o_branchFlow_TP(ca,dt,br)] ] ;
*   Island output
o_islandRefPrice_TP(ca,dt,isl) = sum[ n $ { refNode(ca,dt,n) and nodeIsland(ca,dt,n,isl) } , o_nodePrice_TP(ca,dt,n) ] ;


$endif.PriceRelatedOutputs
*   Calculating price-relating outputs end -------------------------------------

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
putclose rep 'Case: %GDXname% is complete in ',timeExec,'(secs)'/ ;
putclose rep 'Case: %GDXname% is finished in ',timeElapsed,'(secs)'/ ;

* Go to the next input file
$label nextInput

* Post a progress message for use by EMI.
$if not exist "%inputPath%\%GDXname%.gdx" putclose rep 'The file %inputPath%\%GDXname%.gdx could not be found (', system.time, ').' // ;
