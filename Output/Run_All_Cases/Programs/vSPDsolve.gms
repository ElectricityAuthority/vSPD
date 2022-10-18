$ontext
*=====================================================================================
Name:                 vSPDsolve.gms
Function:             Establish base case and override data, prepare data, and
                      solve the model
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
$offtext

*=====================================================================================
* 0. Initial setup
*=====================================================================================

* Include paths, settings and case name files
$include vSPDsettings.inc
$include vSPDcase.inc

* Update the ProgressReport.txt file
File rep "Write to a report" /"ProgressReport.txt"/;  rep.lw = 0;  rep.ap = 1;
putclose rep / 'Case "%GDXname%" started at: ' system.date " " system.time /;

if(sequentialSolve,
  putclose rep 'Vectorisation is switched OFF' /;
else
  putclose rep 'Vectorisation is switched ON' /;
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

* Declare a temporary file
File temp ;

* Allow empty data set declaration
$onempty

*=====================================================================================
* 1. Declare symbols and initialise some of them
*=====================================================================================

Sets
  unsolvedDT(dt)                                  'Set of datetime that are not solved yet'
  SOS1_solve(dt)                                  'Flag period that is resolved using SOS1'

* Unmmaped bus defificit temporary sets
  unmappedDeficitBus(dt,b)                        'List of buses that have deficit generation (price) and are not mapped to any pnode - revisit'
  changedDeficitBus(dt,b)                         'List of buses that have deficit generation added from unmapped deficit bus - revisit'
  ;

Parameters
* Flag to apply corresponding vSPD model
  VSPDModel(dt)                                       '0=VSPD, 1=vSPD_BranchFlowMIP, 2=VSPD (last solve)'

* MIP logic
  circularBranchFlowExist(dt,br)                      'Flag to indicate if circulating branch flows exist on each branch: 1 = Yes'
  poleCircularBranchFlowExist(dt,pole)                'Flag to indicate if circulating branch flows exist on each an HVDC pole: 1 = Yes'

* Calculated parameter used to check if non-physical loss occurs on HVDC
  northHVDC(dt)                                       'HVDC MW sent from from SI to NI'
  southHVDC(dt)                                       'HVDC MW sent from from NI to SI'
  nonPhysicalLossExist(dt,br)                         'Flag to indicate if non-physical losses exist on branch (applied to HVDC only): 1 = Yes'
  manualBranchSegmentMWFlow(dt,br,los,fd)             'Manual calculation of the branch loss segment MW flow --> used to manually calculate hvdc branch losses'
  manualLossCalculation(dt,br)                        'MW losses calculated manually from the solution for each loss branch'

* Calculated parameter used to check if circular branch flow exists on each HVDC pole
  TotalHVDCpoleFlow(dt,pole)                          'Total flow on an HVDC pole'
  MaxHVDCpoleFlow(dt,pole)                            'Maximum flow on an HVDC pole'

* Disconnected bus post-processing
  busGeneration(dt,b)                                 'MW generation at each bus for the study trade periods'
  busLoad(dt,b)                                       'MW load at each bus for the study trade periods'
  busPrice(dt,b)                                      '$/MW price at each bus for the study trade periods'
  busDisconnected(dt,b)                               'Indication if bus is disconnected or not (1 = Yes) for the study trade periods'
* Unmmaped bus defificit temporary parameters
  temp_busDeficit_TP(dt,b)                             'Bus deficit violation for each trade period'
* TN - Replacing invalid prices after SOS1
  busSOSinvalid(dt,b)                                 'Buses with invalid bus prices after SOS1 solve'
  numberofbusSOSinvalid(dt)                           'Number of buses with invalid bus prices after SOS1 solve --> used to check if invalid prices can be improved (numberofbusSOSinvalid reduces after each iteration)'
* System loss calculated by SPD for RTD run
  SPDLoadCalcLosses(dt,isl)                           'Island losses calculated by SPD in the first solve to adjust demand'
 ;

Parameters
* Dispatch results for reporting - Trade period level - Island output
  o_islandGen_TP(dt,isl)                              'Island MW generation for the different time periods'
  o_islandLoad_TP(dt,isl)                             'Island MW fixed load for the different time periods'
  o_islandClrBid_TP(dt,isl)                           'Island cleared MW bid for the different time periods'
  o_islandBranchLoss_TP(dt,isl)                       'Intra-island branch losses for the different time periods (MW)'
  o_islandRefPrice_TP(dt,isl)                         'Reference prices in each island ($/MWh)'

  o_HVDCflow_TP(dt,isl)                               'HVDC flow from each island (MW)'
  o_HVDCloss_TP(dt,isl)                               'HVDC losses (MW)'
  o_HVDCpoleFixedLoss_TP(dt,isl)                      'Fixed loss on inter-island HVDC (MW)'
  o_HVDCreceived(dt,isl)                              'Energy Recevied from HVDC into an island'
  o_HVDCRiskSubtractor(dt,isl,resC,riskC)             'OutPut HVDC risk subtractor'

  o_busGeneration_TP(dt,b)                            'Output MW generation at each bus for the different time periods'
  o_busLoad_TP(dt,b)                                  'Output MW load at each bus for the different time periods'
  o_busPrice_TP(dt,b)                                 'Output $/MW price at each bus for the different time periods'
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

  o_ACbranchTotalRentals(dt)                          'FTR rental - Total AC rental by trading period'
  o_ACbranchLossMW(dt,br,los)                         'FTR rental - MW element of the loss segment curve in MW'
  o_ACbranchLossFactor(dt,br,los)                     'FTR rental Loss factor element of the loss segment curve applied to'

  o_offerEnergy_TP(dt,o)                              'Output MW cleared for each energy offer for each trade period'
  o_offerRes_TP(dt,o,resC)                            'Output MW cleared for each reserve offer for each trade period'
  o_offerFIR_TP(dt,o)                                 'Output MW cleared for FIR for each trade period'
  o_offerSIR_TP(dt,o)                                 'Output MW cleared for SIR for each trade period'

  o_groupEnergy_TP(dt,rg,riskC)                       'Output MW cleared for risk group for each trade period'
  o_groupFKband_TP(dt,rg,riskC)                       'Output FK band MW applied for risk group for each trade period'
  o_groupRes_TP(dt,rg,resC,riskC)                     'Output reserve MW cleared for risk group for each trade period'

  o_bidEnergy_TP(dt,bd)                               'Output MW cleared for each energy bid for each trade period'
  o_bidTotalMW_TP(dt,bd)                              'Output total MW bidded for each energy bid for each trade period'

  o_ReserveReqd_TP(dt,isl,resC)                       'Output MW required for each reserve class in each trade period'
  o_FIRreqd_TP(dt,isl)                                'Output MW required FIR for each trade period'
  o_SIRreqd_TP(dt,isl)                                'Output MW required SIR for each trade period'
  o_ResCleared_TP(dt,isl,resC)                        'Reserve cleared from an island for each trade period'
  o_FIRcleared_TP(dt,isl)                             'Output - total FIR cleared by island'
  o_SIRcleared_TP(dt,isl)                             'Output - total SIR cleared by island'
  o_ResPrice_TP(dt,isl,resC)                          'Output $/MW price for each reserve classes for each trade period'
  o_FIRprice_TP(dt,isl)                               'Output $/MW price for FIR reserve classes for each trade period'
  o_SIRprice_TP(dt,isl)                               'Output $/MW price for SIR reserve classes for each trade period'

  o_GenRiskPrice_TP(dt,isl,o,resC,riskC)              'Output Gen risk marginal prices'
  o_HVDCSecRiskPrice_TP(dt,isl,o,resC,riskC)          'Output HVDC risk marginal prices'
  o_GenRiskGroupPrice_TP(dt,isl,rg,resC,riskC)        'Output risk group marginal prices'
  o_HVDCRiskPrice_TP(dt,isl,resC,riskC)               'Output HVDC risk marginal prices'
  o_ManualRiskPrice_TP(dt,isl,resC,riskC)             'Output Manual risk marginal prices'
  o_HVDCSecManualRiskPrice_TP(dt,isl,resC,riskC)      'Output HVDC risk marginal prices'

  o_GenRiskShortfall_TP(dt,isl,o,resC,riskC)          'Output Gen risk shortfall'
  o_HVDCSecRiskShortfall_TP(dt,isl,o,resC,riskC)      'Output HVDC risk shortfall'
  o_GenRiskGroupShortfall_TP(dt,isl,rg,resC,riskC)    'Output risk group shortfall'
  o_HVDCRiskShortfall_TP(dt,isl,resC,riskC)           'Output HVDC risk shortfall'
  o_ManualRiskShortfall_TP(dt,isl,resC,riskC)         'Output Manual risk shortfall'
  o_HVDCSecManualRiskShortfall_TP(dt,isl,resC,riskC)  'Output HVDC risk shortfall'

  o_ResViolation_TP(dt,isl,resC)                      'Violation MW for each reserve classes for each trade period'
  o_FIRviolation_TP(dt,isl)                           'Violation MW for FIR reserve classes for each trade period'
  o_SIRviolation_TP(dt,isl)                           'Violation MW for SIR reserve classes for each trade period'

  o_nodeGeneration_TP(dt,n)                           'Ouput MW generation at each node for the different time periods'
  o_nodeLoad_TP(dt,n)                                 'Ouput MW load at each node for the different time periods'
  o_nodePrice_TP(dt,n)                                'Output $/MW price at each node for the different time periods'
  o_nodeDeficit_TP(dt,n)                              'Output node deficit violation for each trade period'
  o_nodeSurplus_TP(dt,n)                              'Output node surplus violation for each trade period'
  o_nodeDead_TP(dt,n)                                 'Define if a Node  (Pnode) is dead'
  o_nodeDeadPrice_TP(dt,n)                            'Flag to check if a dead Node has valid price'
  o_nodeDeadPriceFrom_TP(dt,n,n1)                     'Flag to show which price node the price of the dead node come from'
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
  o_defResv_TP(dt)                                    'Deficit reserve violation for summary report'

* Factor to prorate the deficit and surplus at the nodal level
  totalBusAllocation(dt,b)                            'Total allocation of nodes to bus'
  busNodeAllocationFactor(dt,b,n)                     'Bus to node allocation factor'

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

  o_generationRiskLevel(dt,isl,o,resC,riskC)                    'Audit - generation risk'

  o_HVDCriskLevel(dt,isl,resC,riskC)                            'Audit - DCCE and DCECE risk'

  o_manuRiskLevel(dt,isl,resC,riskC)                            'Audit - manual risk'

  o_genHVDCriskLevel(dt,isl,o,resC,riskC)                       'Audit - generation + HVDC secondary risk'

  o_manuHVDCriskLevel(dt,isl,resC,riskC)                        'Audit - manual + HVDC secondary'

  o_generationRiskGroupLevel(dt,isl,rg,resC,riskC)              'Audit - generation group risk'


* TN - output parameters added for NMIR project --------------------------------
  o_FirSent_TP(dt,isl)                        'FIR export from an island for each trade period'
  o_SirSent_TP(dt,isl)                        'SIR export from an island for each trade period'
  o_FirReceived_TP(dt,isl)                    'FIR received at an island for each trade period'
  o_SirReceived_TP(dt,isl)                    'SIR received at an island for each trade period'
  o_FirEffReport_TP(dt,isl)                   'Effective FIR share for reporting to an island for each trade period'
  o_SirEffReport_TP(dt,isl)                   'Effective FIR share for reporting to an island for each trade period'
  o_EffectiveRes_TP(dt,isl,resC,riskC)        'Effective reserve share to an island for each trade period'
  o_FirEffectiveCE_TP(dt,isl)                 'Effective FIR share to an island for each trade period'
  o_SirEffectiveCE_TP(dt,isl)                 'Effective FIR share to an island for each trade period'
  o_FirEffectiveECE_TP(dt,isl)                'Effective FIR share to an island for each trade period'
  o_SirEffectiveECE_TP(dt,isl)                'Effective FIR share to an island for each trade period'

  o_TotalIslandReserve(dt,isl,resC,riskC)     'Total Reserve cleared in a island including shared Reserve'
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
$load tp=i_tradePeriod  dt=i_dateTime  dt2tp = i_dateTimeTradePeriod
$gdxin

* Call the GDX routine and load the input data:
$gdxin "%inputPath%\%GDXname%.gdx"
* Sets
$load caseName  rundt=i_runDateTime
$load b = i_bus  n = i_node  o = i_offer  bd = i_bid  trdr = i_trader
$load br = i_branch  brCstr = i_branchConstraint  MnodeCstr = i_MnodeConstraint
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
$load rg = i_riskGroup
$load riskGroupOffer = i_dateTimeRiskGroup

* Parameters
$load gdxDate intervalDuration = i_intervalLength
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
$load studyMode                   = i_studyMode
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
$load instructedloadshed          = i_dateTimeInstructedLoadShed
$load instructedshedactive        = i_dateTimeInstructedShedActive
$load islandMWIPS                 = i_dateTimeIslandMWIPS
$load islandPDS                   = i_dateTimeIslandPDS
$load islandLosses                = i_dateTimeIslandLosses

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
inputGDXGDate = jdate(gdxDate('year'),gdxDate('month'),gdxDate('day'));

* The code below is for example and not currently used
$ontext
put_utility temp 'gdxin' / '%inputPath%\%GDXname%.gdx' ;
if (inputGDXGDate >= jdate(2022,11,1) or sum[sameas(caseName,testCases),1] ,
    execute_load
    energyScarcityEnabled       = i_energyScarcityEnabled
    ;
) ;
$oftext


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
$onend

* Check if NMIR is enabled
UseShareReserve = 1 $ sum[ (dt,resC), reserveShareEnabled(dt,resC)] ;

* Pre-dispatch schedule is solved sequentially
sequentialSolve $ { (studyMode >= 130) and (studyMode <= 133) } = 1 ;
sequentialSolve $ sum[dt, useGenInitialMW(dt)] = 1;
sequentialSolve $ UseShareReserve = 1;



* Initialise genrating offer parameters ----------------------------------------
GenerationStart(dt,o) = offerParameter(dt,o,'initialMW')
                      + sum[ o1 $ primarySecondaryOffer(dt,o,o1)
                                , offerParameter(dt,o1,'initialMW') ] ;
* if useGenIntitialMW = 1 --> sequential solve like PRSS, NRSS
GenerationStart(dt,o) $ { (useGenInitialMW(dt) = 1) and (ord(dt) > 1) } = 0;

RampRateUp(dt,o)               = offerParameter(dt,o,'rampUpRate')      ;
RampRateDn(dt,o)               = offerParameter(dt,o,'rampDnRate')      ;
ReserveGenerationMaximum(dt,o) = offerParameter(dt,o,'resrvGenMax')      ;
WindOffer(dt,o)                = offerParameter(dt,o,'isIG')            ;
FKband(dt,o)                   = offerParameter(dt,o,'FKbandMW')        ;
PriceResponsive(dt,o)          = offerParameter(dt,o,'isPriceResponse') ;
PotentialMW(dt,o)              = offerParameter(dt,o,'potentialMW')     ;

* This is based on the 4.6.2.1 calculation
$ontext
For generators in the PRICERESPONSIVEIG subset, if the PotentialMWg value is
less than ReserveGenerationMaximumg,c  then pre-processing sets the
ReserveGenerationMaximumg,c parameter to the PotentialMWg value, otherwise if
the PotentialMWg value is greater than or equal to the
ReserveGenerationMaximumg,c  then the ReserveGenerationMaximumg,c
value is unchanged
Tuong note: this does not seems to make saense and be used.
$offtext
reserveMaximumFactor(dt,o,resC)
    $ { windOffer(dt,o) and priceResponsive(dt,o) and( potentialMW(dt,o) > 0)
    and (potentialMW(dt,o) < ReserveGenerationMaximum(dt,o)) }
    = ReserveGenerationMaximum(dt,o) / potentialMW(dt,o) ;
*-------------------------------------------------------------------------------


* Initialise offer limits and prices -------------------------------------------

* Initialise energy offer data for the current trade period start
EnrgOfrMW(dt,o,blk) = energyOffer(dt,o,blk,'limitMW') ;
EnrgOfrPrice(dt,o,blk) = energyOffer(dt,o,blk,'price') ;

* Initialise reserve offer data for the current trade period start
PLRO(resT) $ (ord(resT) = 1) = yes ;
TWRO(resT) $ (ord(resT) = 2) = yes ;
ILRO(resT) $ (ord(resT) = 3) = yes ;

ResOfrPct(dt,o,blk,resC)
    = (fastPLSRoffer(dt,o,blk,'plsrPct')      / 100) $ ( ord(resC) = 1 )
    + (sustainedPLSRoffer(dt,o,blk,'plsrPct') / 100) $ ( ord(resC) = 2 );

ResOfrMW(dt,o,blk,resC,PLRO)
    = fastPLSRoffer(dt,o,blk,'limitMW')     $(ord(resC)=1)
    + sustainedPLSRoffer(dt,o,blk,'limitMW')$(ord(resC)=2) ;

ResOfrMW(dt,o,blk,resC,TWRO)
    = fastTWDRoffer(dt,o,blk,'limitMW')     $(ord(resC)=1)
    + sustainedTWDRoffer(dt,o,blk,'limitMW')$(ord(resC)=2) ;

ResOfrMW(dt,o,blk,resC,ILRO)
    = fastILRoffer(dt,o,blk,'limitMW')     $(ord(resC)=1)
    + sustainedILRoffer(dt,o,blk,'limitMW')$(ord(resC)=2) ;

ResOfrPrice(dt,o,blk,resC,PLRO)
    = fastPLSRoffer(dt,o,blk,'price')     $(ord(resC)=1)
    + sustainedPLSRoffer(dt,o,blk,'price')$(ord(resC)=2) ;

ResOfrPrice(dt,o,blk,resC,TWRO)
    = fastTWDRoffer(dt,o,blk,'price')     $(ord(resC)=1)
    + sustainedTWDRoffer(dt,o,blk,'price')$(ord(resC)=2) ;

ResOfrPrice(dt,o,blk,resC,ILRO)
    = fastILRoffer(dt,o,blk,'price')     $(ord(resC)=1)
    + sustainedILRoffer(dt,o,blk,'price')$(ord(resC)=2)  ;
*-------------------------------------------------------------------------------


* Define valid offers and valid offer block ------------------------------------

* Valid offer must be mapped to a bus with electrical island <> 0
offer(dt,o) $ sum[ (n,b) $ { offerNode(dt,o,n) and nodeBus(dt,n,b)
                           }, busElectricalIsland(dt,b) ] = yes ;

* IL offer with non zero total limit is always valid
offer(dt,o) $ sum[ (blk,resC,ILRO), ResOfrMW(dt,o,blk,resC,ILRO)] = yes ;

* Valid energy offer blocks are defined as those with a positive block limit
genOfrBlk(dt,o,blk) $ ( EnrgOfrMW(dt,o,blk) > 0 ) = yes ;

* Define set of positive (valid) energy offers
posEnrgOfr(dt,o) $ sum[ blk $ genOfrBlk(dt,o,blk), 1 ] = yes ;

* Only reserve offer block with a positive block limit is valid
resOfrBlk(dt,o,blk,resC,resT) $ (ResOfrMW(dt,o,blk,resC,resT) > 0) = yes ;
*-------------------------------------------------------------------------------


* Initialise bid limits and prices ---------------------------------------------

* Valid bid must be mapped to a bus with electrical island <> 0
bid(dt,bd) $ sum[ (n,b) $ { bidNode(dt,bd,n) and nodeBus(dt,n,b)
                          }, busElectricalIsland(dt,b) ] = yes ;
* Bid energy data
DemBidMW(bid,blk)    $ dispatchableBid(bid) = energyBid(bid,blk,'limitMW') ;
DemBidPrice(bid,blk) $ dispatchableBid(bid) = energyBid(bid,blk,'price')   ;
* Valid Demand Bid Block
DemBidBlk(bid,blk)   $ ( DemBidMW(bid,blk) <> 0 ) = yes ;
*-------------------------------------------------------------------------------


* Initialise mappings to use in later stage ------------------------------------

nodeIsland(dt,n,isl) $ sum[ b $ { bus(dt,b) and node(dt,n)
                              and nodeBus(dt,n,b) and busIsland(dt,b,isl) }, 1
                          ] = yes ;
offerIsland(offer(dt,o),isl)
    $ sum[ n $ { offerNode(dt,o,n) and nodeIsland(dt,n,isl) }, 1 ] = yes ;

bidIsland(bid(dt,bd),isl)
    $ sum[ n $ { bidNode(dt,bd,n) and nodeIsland(dt,n,isl) }, 1 ] = yes ;

islandRiskGenerator(dt,isl,o)
    $ { offerIsland(dt,o,isl) and riskGenerator(dt,o) } = yes ;


* Identification of primary and secondary units
PrimaryOffer(dt,o) = 1 ;
SecondaryOffer(dt,o) = 1 $ sum[ o1 $ primarySecondaryOffer(dt,o1,o), 1 ] ;
PrimaryOffer(dt,o) $ SecondaryOffer(dt,o) = 0 ;
*-------------------------------------------------------------------------------


* Initialise demand/bid data ---------------------------------------------------
RequiredLoad(node) = nodeDemand(node) ;

* 4.9.2 Dispatchable Pnodes
$ontext
If the Pnode associated with a Dispatchable Demand Bid is not a dead Pnode then
PnodeRequiredLoadpn is set to zero. The Pnode load will be determined by
clearing the Pnode's Dispatchable Demand Bid when the LP Model is solved.
$offtext
RequiredLoad(node(dt,n))
    $ { Sum[ (bd,blk) $ bidNode(dt,bd,n), DemBidMW(dt,bd,blk) ] > 0 } = 0;



* 4.10 Real Time Pricing - First RTD load calculation
if studyMode = 101 or studyMode = 201 then

*   Calculate first target total load [4.10.6.5]
*   Island-level MW load forecast. For the fist loop:
*   replace LoadCalcLosses(dt,isl) = islandLosses(dt,isl);
    TargetTotalLoad(dt,isl) = islandMWIPS(dt,isl)
                            + islandPDS(dt,isl)
                            - islandLosses(dt,isl);

*   Flag if estimate load is scalable [4.10.6.7]
*   Binary value. If True then ConformingFactor load MW will be scaled in order
*   to calculate EstimatedInitialLoad. If False then EstNonScalableLoad will be
*   assigned directly to EstimatedInitialLoad
    EstLoadIsScalable(dt,n) =  1 $ { (LoadIsNCL(dt,n) = 0)
                                 and (ConformingFactor(dt,n) > 0) } ;

*   Calculate estimate non-scalable load [4.10.6.8]
*   For a non-conforming Pnode this will be the NonConformingLoad MW input, for
*   a conforming Pnode this will be the ConformingFactor MW input if that value
*   is negative, otherwise it will be zero
    EstNonScalableLoad(dt,n) $ ( LoadIsNCL(dt,n) = 1 ) = NonConformingLoad(dt,n);
    EstNonScalableLoad(dt,n) $ ( LoadIsNCL(dt,n) = 0 ) = ConformingFactor(dt,n);
    EstNonScalableLoad(dt,n) $ ( EstLoadIsScalable(dt,n) = 1 ) = 0;

*   Calculate estimate scalable load [4.10.6.10]
*   For a non-conforming Pnode this value will be zero. For a conforming Pnode
*   this value will be the ConformingFactor if it is non-negative, otherwise
*   this value will be zero'
    EstScalableLoad(dt,n) $ ( EstLoadIsScalable(dt,n) = 1 ) = ConformingFactor(dt,n);


*   Calculate Scaling applied to ConformingFactor load MW [4.10.6.9]
*   in order to calculate EstimatedInitialLoad
    EstScalingFactor(dt,isl)
        = (islandMWIPS(dt,isl) - islandLosses(dt,isl)
          - Sum[ n $ nodeIsland(dt,n,isl), EstNonScalableLoad(dt,n) ]
          ) / Sum[ n $ nodeIsland(dt,n,isl), EstScalableLoad(dt,n) ]

        ;

*   Calculate estimate initial load [4.10.6.6]
*   Calculated estimate of initial MW load, available to be used as an
*   alternative to InputInitialLoad
    EstimatedInitialLoad(dt,n) $ ( EstLoadIsScalable(dt,n) = 1 )
        = ConformingFactor(dt,n) * Sum[ isl $ nodeisland(dt,n,isl)
                                      , EstScalingFactor(dt,isl)] ;
    EstimatedInitialLoad(dt,n) $ ( EstLoadIsScalable(dt,n) = 0 )
        = EstNonScalableLoad(dt,n);

*   Calculate initial load [4.10.6.2]
*   Value that represents the Pnode load MW at the start of the solution
*   interval. Depending on the inputs this value will be either actual load,
*   an operator applied override or an estimated initial load
    InitialLoad(dt,n) = InputInitialLoad(dt,n);
    InitialLoad(dt,n) $ { (LoadIsOverride(dt,n) = 0)
                      and ( (useActualLoad(dt) = 0) or (LoadIsBad(dt,n) = 1) )
                        } = EstimatedInitialLoad(dt,n) ;
    InitialLoad(dt,n) $ { (LoadIsOverride(dt,n) = 1)
                      and (useActualLoad(dt) = 1)
                      and (InitialLoad(dt,n) > MaxLoad(dt,n))
                        } = MaxLoad(dt,n) ;

*   Flag if load is scalable [4.10.6.4]
*   Binary value. If True then the Pnode InitialLoad will be scaled in order to
*   calculate RequiredLoad, if False then Pnode InitialLoad will be directly
*   assigned to RequiredLoad
    LoadIsScalable(dt,n) = 1 $ { (LoadIsNCL(dt,n) = 0)
                             and (LoadIsOverride(dt,n) = 0)
                             and (InitialLoad(dt,n) >= 0) } ;

*   Calculate Island-level scaling factor [4.10.6.3]
*   --> applied to InitialLoad in order to calculate RequiredLoad
    LoadScalingFactor(dt,isl)
        = ( TargetTotalLoad(dt,isl)
          - Sum[ n $ { nodeIsland(dt,n,isl)
                   and (LoadIsScalable(dt,n) = 0) }, InitialLoad(dt,n) ]
          ) / Sum[ n $ { nodeIsland(dt,n,isl)
                     and (LoadIsScalable(dt,n) = 1) }, InitialLoad(dt,n) ]
        ;

*   Calculate RequiredLoad [4.10.6.1]
    RequiredLoad(dt,n) $ LoadIsScalable(dt,n)
        = InitialLoad(dt,n) * sum[ isl $ nodeisland(dt,n,isl)
                                 , LoadScalingFactor(dt,isl) ];

    RequiredLoad(dt,n) $ (LoadIsScalable(dt,n) = 0) = InitialLoad(dt,n);

    RequiredLoad(dt,n) = RequiredLoad(dt,n)
                       + [instructedloadshed(dt,n) $ instructedshedactive(dt,n)];

Endif;
*-------------------------------------------------------------------------------


* Initialize energy scarcity limits and prices ---------------------------------

ScarcityEnrgLimit(dt,n,blk)
    $ { energyScarcityEnabled(dt) and scarcityEnrgNodeLimit(dt,n,blk) }
    = scarcityEnrgNodeLimit(dt,n,blk);
ScarcityEnrgPrice(dt,n,blk)
    $ { energyScarcityEnabled(dt) and scarcityEnrgNodeLimit(dt,n,blk) }
    = scarcityEnrgNodeLimitPrice(dt,n,blk) ;


ScarcityEnrgLimit(dt,n,blk)
    $ { energyScarcityEnabled(dt)
    and (sum[blk1, ScarcityEnrgLimit(dt,n,blk1)] = 0 )
    and scarcityEnrgNodeFactor(dt,n,blk)
    and (RequiredLoad(dt,n) > 0)
      }
    = scarcityEnrgNodeFactor(dt,n,blk) * RequiredLoad(dt,n);
ScarcityEnrgPrice(dt,n,blk)
    $ { energyScarcityEnabled(dt)
    and (sum[blk1, ScarcityEnrgLimit(dt,n,blk1)] > 0 )
    and scarcityEnrgNodeFactor(dt,n,blk)
      }
    = scarcityEnrgNodeFactorPrice(dt,n,blk) ;


ScarcityEnrgLimit(dt,n,blk)
    $ { energyScarcityEnabled(dt)
    and (sum[blk1, ScarcityEnrgLimit(dt,n,blk1)] = 0 )
    and (RequiredLoad(dt,n) > 0)
      }
    = scarcityEnrgNationalFactor(dt,blk) * RequiredLoad(dt,n);
ScarcityEnrgPrice(dt,n,blk)
    $ { energyScarcityEnabled(dt)
    and (sum[blk1, ScarcityEnrgLimit(dt,n,blk1)] > 0 )
      }
    = scarcityEnrgNationalPrice(dt,blk) ;


*-------------------------------------------------------------------------------


* Initialize AC and DC branches ------------------------------------------------

* Branch is defined if there is a defined terminal bus, it has a non-zero
* capacity and is closed for that trade period
* Update the pre-processing code that removes branches which have a limit of zero
* so that it removes a branch if either direction has a limit of zero.
branch(dt,br) $ { (not branchOpenStatus(dt,br)) and
                  (not HVDCBranch(dt,br)) and
                  sum[ fd $ (ord(fd)=1), branchCapacity(dt,br,fd)] and
                  sum[ fd $ (ord(fd)=2), branchCapacity(dt,br,fd)] and
                  sum[ (b,b1) $ { bus(dt,b) and bus(dt,b1) and
                                  branchDefn(dt,br,b,b1) }, 1 ]
                } = yes ;

branch(dt,br) $ { (not branchOpenStatus(dt,br)) and
                  (HVDCBranch(dt,br)) and
                  sum[ fd, branchCapacity(dt,br,fd)] and
                  sum[ (b,b1) $ { bus(dt,b) and bus(dt,b1) and
                                  branchDefn(dt,br,b,b1) }, 1 ]
                } = yes ;


branchBusDefn(branch,b,b1) $ branchDefn(branch,b,b1)    = yes ;
branchFrBus(branch,frB) $ sum[ toB $ branchBusDefn(branch,frB,toB), 1 ] = yes ;
branchToBus(branch,toB) $ sum[ frB $ branchBusDefn(branch,frB,toB), 1 ] = yes ;
branchBusConnect(branch,b) $ branchFrBus(branch,b) = yes ;
branchBusConnect(branch,b) $ branchToBus(branch,b) = yes ;


* HVDC link and AC branch definition
HVDClink(branch) = yes $ HVDCBranch(branch) ;
ACbranch(branch) = yes $ [not HVDCBranch(branch)];


* Determine sending and receiving bus for each branch flow direction
loop (frB,toB) do
    ACbranchSendingBus(ACbranch,frB,fd)
        $ { branchBusDefn(ACbranch,frB,toB) and (ord(fd) = 1) } = yes ;

    ACbranchReceivingBus(ACbranch,toB,fd)
        $ { branchBusDefn(ACbranch,frB,toB) and (ord(fd) = 1) } = yes ;

    ACbranchSendingBus(ACbranch,toB,fd)
        $ { branchBusDefn(ACbranch,frB,toB) and (ord(fd) = 2) } = yes ;

    ACbranchReceivingBus(ACbranch,frB,fd)
        $ { branchBusDefn(ACbranch,frB,toB) and (ord(fd) = 2) } = yes ;
endloop;

HVDClinkSendingBus(HVDClink,frB)
    $ sum[ branchBusDefn(HVDClink,frB,toB), 1 ] = yes ;

HVDClinkReceivingBus(HVDClink,toB)
    $ sum[ branchBusDefn(HVDClink,frB,toB), 1 ] = yes ;

HVDClinkBus(HVDClink,b) $ HVDClinkSendingBus(HVDClink,b)   = yes ;
HVDClinkBus(HVDClink,b) $ HVDClinkReceivingBus(HVDClink,b) = yes ;

* Determine the HVDC inter-island pole in the northward and southward direction

HVDCpoleDirection(dt,br,fd) $ { (ord(fd) = 1) and HVDClink(dt,br) }
    = yes $ sum[ (isl,NodeBus(dt,n,b)) $ { (ord(isl) = 2)
                                       and nodeIsland(dt,n,isl)
                                       and HVDClinkSendingBus(dt,br,b) }, 1 ] ;

HVDCpoleDirection(dt,br,fd) $ { (ord(fd) = 2) and HVDClink(dt,br) }
    = yes $ sum[ (isl,NodeBus(dt,n,b)) $ { (ord(isl) = 1)
                                       and nodeIsland(dt,n,isl)
                                       and HVDClinkSendingBus(dt,br,b) }, 1 ] ;

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
branchFixedLoss(ACbranch) = branchParameter(ACbranch,'fixedLosses')
                          $ (branchLossBlocks(ACbranch) > 1) ;

branchFixedLoss(HVDClink) = branchParameter(HVDClink,'fixedLosses') ;

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
loop branch $ (branchLossBlocks(branch) = 3) do
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
endloop;

* Loss branches with 6 loss blocks
loop branch $ (branchLossBlocks(branch) = 6) do
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
endloop ;

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

loop (HVDClink(branch),bp) $ (ord(bp) > 2) do
    HVDCBreakPointMWLoss(branch,bp,fd) $ validLossSegment(branch,bp,fd)
        = LossSegmentFactor(branch,bp-1,fd)
        * [ LossSegmentMW(branch,bp-1,fd) - LossSegmentMW(branch,bp-2,fd) ]
        + HVDCBreakPointMWLoss(branch,bp-1,fd) ;
endloop ;
*-------------------------------------------------------------------------------


* Initialise branch constraint data --------------------------------------------
branchConstraint(dt,brCstr)
    $ sum[ branch(dt,br) $ branchCstrFactors(dt,brCstr,br), 1 ] = yes ;

branchConstraintSense(branchConstraint)
    = branchCstrRHS(branchConstraint,'cnstrSense') ;

branchConstraintLimit(branchConstraint)
    = branchCstrRHS(branchConstraint,'cnstrLimit') ;
*-------------------------------------------------------------------------------


* Calculate parameters for NMIR project ----------------------------------------
islandRiskGroup(dt,isl,rg,riskC)
    = yes $ sum[ o $ { offerIsland(dt,o,isl)
                   and riskGroupOffer(dt,rg,o,riskC) }, 1 ] ;

modulationRisk(dt) = smax[ riskC, modulationRiskClass(dt,RiskC) ];

reserveShareEnabledOverall(dt) = smax[ resC, reserveShareEnabled(dt,resC) ];

roPwrZoneExit(dt,resC)
    = [ roundPower2MonoLevel(dt) - modulationRisk(dt) ]$(ord(resC)=1)
    + bipole2MonoLevel(dt)$(ord(resC)=2) ;

* National market refinement - effective date 28 Mar 2019 12:00
$ontext
   SPD pre-processing is changed so that the roundpower settings for FIR are
   now the same as for SIR. Specifically:
   -  The RoundPowerZoneExit for FIR will be set at BipoleToMonopoleTransition
      by SPD pre-processing (same as for SIR). A change from the existing where
      the RoundPowerZoneExit for FIR is set at RoundPowerToMonopoleTransition
      by SPD pre-processing.
   -  Provided that roundpower is not disabled by the MDB, the InNoReverseZone
      for FIR will be removed by SPD pre-processing (same as for SIR). A change
      from the existing where the InNoReverseZone for FIR is never removed by
      SPD pre-processing.
$offtext

if inputGDXGDate >= jdate(2019,03,28) then
    roPwrZoneExit(dt,resC) = bipole2MonoLevel(dt) ;
endif ;

* National market refinement end


* Pre-processing: Shared Net Free Reserve (NFR) calculation - NMIR (4.5.2.1)
sharedNFRLoad(dt,isl)
    = sum[ nodeIsland(dt,n,isl), RequiredLoad(dt,n)]
    + sum[ (bd,blk) $ bidIsland(dt,bd,isl), DemBidMW(dt,bd,blk) ]
    - sharedNFRLoadOffset(dt,isl) ;

sharedNFRMax(dt,isl) = Min{ RMTReserveLimitTo(dt,isl,'FIR'),
                            sharedNFRFactor(dt)*sharedNFRLoad(dt,isl) } ;

* Calculate HVDC constraint sets and HVDC Max Flow - NMIR (4.1.8 - NMIR06)
$ontext
 TN on 22 May 2017:
Usually a branch group constraint that limits the HVDC flow only involves the
HVDC branch(s) in the same direction. However, during TP6 to TP9 of 18 May 2017,
the constraint HAY_BEN_High_Frequency_limit involved all four branches in the
form: HAY_BEN1.1 + HAY_BEN2.1 - BEN_HAY1.1 - BEN_HAY2.1 <= 530 MW
This method of formulating the constraint prevented the previous formulation of
monopoleConstraint and bipoleConstraintfrom working properly. Those constraints
have been reformulated (see below) in order to cope with the formulation
observed on 18 May 2017.
$offtext
monopoleConstraint(dt,isl,brCstr,br)
    $ { HVDClink(dt,br)
    and ( not rampingConstraint(dt,brCstr) )
    and ( branchConstraintSense(dt,brCstr) = -1 )
    and (Sum[ (br1,b) $ {HVDClinkSendingBus(dt,br1,b) and busIsland(dt,b,isl)}
                      , branchCstrFactors(dt,brCstr,br1)    ] = 1)
    and (Sum[ b $ {HVDClinkSendingBus(dt,br,b) and busIsland(dt,b,isl)}
                 , branchCstrFactors(dt,brCstr,br)      ] = 1)
       } = yes ;

bipoleConstraint(dt,isl,brCstr)
    $ { ( not rampingConstraint(dt,brCstr) )
    and ( branchConstraintSense(dt,brCstr) = -1 )
    and (Sum[ (br,b) $ { HVDClink(dt,br)
                     and HVDClinkSendingBus(dt,br,b)
                     and busIsland(dt,b,isl) }
                    , branchCstrFactors(dt,brCstr,br)  ] = 2)
                       } = yes ;

monoPoleCapacity(dt,isl,br)
    = Sum[ (b,fd) $ { BusIsland(dt,b,isl)
                  and HVDClink(dt,br)
                  and HVDClinkSendingBus(dt,br,b)
                  and ( ord(fd) = 1 )
                    }, branchCapacity(dt,br,fd) ] ;

monoPoleCapacity(dt,isl,br)
    $ Sum[ brCstr $ monopoleConstraint(dt,isl,brCstr,br), 1]
    = Smin[ brCstr $ monopoleConstraint(dt,isl,brCstr,br)
          , branchConstraintLimit(dt,brCstr) ];

monoPoleCapacity(dt,isl,br)
    = Min( monoPoleCapacity(dt,isl,br),
           sum[ fd $ ( ord(fd) = 1 ), branchCapacity(dt,br,fd) ] );

biPoleCapacity(dt,isl)
    $ Sum[ brCstr $ bipoleConstraint(dt,isl,brCstr), 1]
    = Smin[ brCstr $ bipoleConstraint(dt,isl,brCstr)
          , branchConstraintLimit(dt,brCstr) ];

biPoleCapacity(dt,isl)
    $ { Sum[ brCstr $ bipoleConstraint(dt,isl,brCstr), 1] = 0 }
    = Sum[ (b,br,fd) $ { BusIsland(dt,b,isl) and HVDClink(dt,br)
                     and HVDClinkSendingBus(dt,br,b)
                     and ( ord(fd) = 1 )
                       }, branchCapacity(dt,br,fd) ] ;

HVDCMax(dt,isl)
    = Min( biPoleCapacity(dt,isl), Sum[ br, monoPoleCapacity(dt,isl,br) ] ) ;


* Calculate HVDC HVDC Loss segment applied for NMIR ----------------------------
$ontext
* Note: When NMIR started on 20/10/2016, the SOdecided to incorrectly calculate the HVDC loss
* curve for reserve sharing based on the HVDC capacity only (i.e. not based on in-service HVDC poles)
* Tuong Nguyen @ EA discovered this bug and the SO has fixed it as of 22/11/2016.
$offtext
if inputGDXGDate >= jdate(2016,11,22) then
      HVDCCapacity(dt,isl)
          = Sum[ (b,br,fd) $ { BusIsland(dt,b,isl) and HVDClink(dt,br)
                           and HVDClinkSendingBus(dt,br,b)
                           and ( ord(fd) = 1 )
                             }, branchCapacity(dt,br,fd) ] ;

      numberOfPoles(dt,isl)
          = Sum[ (b,br) $ { BusIsland(dt,b,isl) and HVDClink(dt,br)
                        and HVDClinkSendingBus(dt,br,b) }, 1 ] ;

      HVDCResistance(dt,isl) $ (numberOfPoles(dt,isl) = 2)
          = Prod[ (b,br) $ { BusIsland(dt,b,isl) and HVDClink(dt,br)
                         and HVDClinkSendingBus(dt,br,b)
                           }, branchResistance(dt,br) ]
          / Sum[ (b,br) $ { BusIsland(dt,b,isl) and HVDClink(dt,br)
                        and HVDClinkSendingBus(dt,br,b)
                          }, branchResistance(dt,br) ] ;

      HVDCResistance(dt,isl) $ (numberOfPoles(dt,isl) = 1)
          = Sum[ br $ monoPoleCapacity(dt,isl,br), branchResistance(dt,br) ] ;
else
    HVDCCapacity(dt,isl)
        = Sum[ (br,b,b1,fd) $ { (HVDCBranch(dt,br) = 1)
                            and busIsland(dt,b,isl)
                            and branchDefn(dt,br,b,b1)
                            and ( ord(fd) = 1 )
                              }, branchCapacity(dt,br,fd) ] ;

    numberOfPoles(dt,isl)
        =Sum[ (br,b,b1) $ { (HVDCBranch(dt,br) = 1)
                      and busIsland(dt,b,isl)
                      and branchDefn(dt,br,b,b1)
                      and sum[ fd $ ( ord(fd) = 1 )
                             , branchCapacity(dt,br,fd) ]
                        }, 1 ] ;

    HVDCResistance(dt,isl)
        =  Sum[ (br,b,b1,brPar)
              $ { (HVDCBranch(dt,br) = 1)
              and busIsland(dt,b,isl)
              and branchDefn(dt,br,b,b1)
              and (ord(brPar) = 1)
                }, branchParameter(dt,br,brPar) ] ;

    HVDCResistance(dt,isl) $ (numberOfPoles(dt,isl) = 2)
        = Prod[ (br,b,b1,brPar)
              $ { (HVDCBranch(dt,br) = 1)
              and busIsland(dt,b,isl)
              and branchDefn(dt,br,b,b1)
              and sum[ fd $ ( ord(fd) = 1 )
                             , branchCapacity(dt,br,fd) ]
              and (ord(brPar) = 1)
                }, branchParameter(dt,br,brPar)
              ] / HVDCResistance(dt,isl) ;
endif ;

* Segment 1
HVDCLossSegmentMW(dt,isl,los) $ (ord(los) = 1)
    = HVDCCapacity(dt,isl) * lossCoeff_C ;

HVDCLossSegmentFactor(dt,isl,los) $ (ord(los) = 1)
    = 0.01 * 0.75 * lossCoeff_C
    * HVDCResistance(dt,isl) * HVDCCapacity(dt,isl) ;

* Segment 2
HVDCLossSegmentMW(dt,isl,los) $ (ord(los) = 2)
    = HVDCCapacity(dt,isl) * lossCoeff_D ;

HVDCLossSegmentFactor(dt,isl,los) $ (ord(los) = 2)
    = 0.01 * lossCoeff_E
    * HVDCResistance(dt,isl) * HVDCCapacity(dt,isl) ;

* Segment 3
HVDCLossSegmentMW(dt,isl,los) $ (ord(los) = 3)
    = HVDCCapacity(dt,isl) * 0.5 ;

HVDCLossSegmentFactor(dt,isl,los) $ (ord(los) = 3)
    = 0.01 * lossCoeff_F
    * HVDCResistance(dt,isl) * HVDCCapacity(dt,isl) ;

* Segment 4
HVDCLossSegmentMW(dt,isl,los) $ (ord(los) = 4)
    = HVDCCapacity(dt,isl) * (1 - lossCoeff_D) ;

HVDCLossSegmentFactor(dt,isl,los) $ (ord(los) = 4)
    = 0.01 * (2 - lossCoeff_F)
    * HVDCResistance(dt,isl) * HVDCCapacity(dt,isl) ;

* Segment 5
HVDCLossSegmentMW(dt,isl,los) $ (ord(los) = 5)
    = HVDCCapacity(dt,isl) * (1 - lossCoeff_C) ;

HVDCLossSegmentFactor(dt,isl,los) $ (ord(los) = 5)
    = 0.01 * (2 - lossCoeff_E)
    * HVDCResistance(dt,isl) * HVDCCapacity(dt,isl) ;

* Segment 6
HVDCLossSegmentMW(dt,isl,los) $ (ord(los) = 6)
    = HVDCCapacity(dt,isl) ;

HVDCLossSegmentFactor(dt,isl,los) $ (ord(los) = 6)
    = 0.01 * (2 - (0.75*lossCoeff_C))
    * HVDCResistance(dt,isl) * HVDCCapacity(dt,isl) ;

* Parameter for energy lambda loss model
HVDCSentBreakPointMWFlow(dt,isl,bp) $ (ord(bp) = 1) = 0 ;
HVDCSentBreakPointMWLoss(dt,isl,bp) $ (ord(bp) = 1) = 0 ;

HVDCSentBreakPointMWFlow(dt,isl,bp) $ (ord(bp) > 1)
    = HVDCLossSegmentMW(dt,isl,bp-1) ;

loop (dt,isl,bp) $ {(ord(bp) > 1) and (ord(bp) <= 7)} do
    HVDCSentBreakPointMWLoss(dt,isl,bp)
        = HVDClossScalingFactor(dt)
        * HVDCLossSegmentFactor(dt,isl,bp-1)
        * [ HVDCLossSegmentMW(dt,isl,bp-1)
          - HVDCSentBreakPointMWFlow(dt,isl,bp-1) ]
        + HVDCSentBreakPointMWLoss(dt,isl,bp-1) ;
endloop ;

* Parameter for energy+reserve lambda loss model

* Ideally SO should use asymmetric loss curve
HVDCReserveBreakPointMWFlow(dt,isl,rsbp) $ (ord(rsbp) <= 7)
    = Sum[ (isl1,rsbp1) $ { ( not sameas(isl1,isl) )
                        and ( ord(rsbp) + ord(rsbp1) = 8)}
         , -HVDCSentBreakPointMWFlow(dt,isl1,rsbp1) ];

* SO decide to use symmetric loss curve instead
HVDCReserveBreakPointMWFlow(dt,isl,rsbp) $ (ord(rsbp) <= 7)
    = Sum[ rsbp1 $ { ord(rsbp) + ord(rsbp1) = 8}
         , -HVDCSentBreakPointMWFlow(dt,isl,rsbp1) ];

HVDCReserveBreakPointMWFlow(dt,isl,rsbp)
    $ { (ord(rsbp) > 7) and (ord(rsbp) <= 13) }
    = HVDCSentBreakPointMWFlow(dt,isl,rsbp-6) ;


* Ideally SO should use asymmetric loss curve
HVDCReserveBreakPointMWLoss(dt,isl,rsbp) $ (ord(rsbp) <= 7)
    = Sum[ (isl1,rsbp1) $ { ( not sameas(isl1,isl) )
                        and ( ord(rsbp) + ord(rsbp1) = 8)}
         , HVDCSentBreakPointMWLoss(dt,isl1,rsbp1) ];

* SO decide to use symmetric loss curve instead
HVDCReserveBreakPointMWLoss(dt,isl,rsbp) $ (ord(rsbp) <= 7)
    = Sum[ rsbp1 $ { ord(rsbp) + ord(rsbp1) = 8}
         , HVDCSentBreakPointMWLoss(dt,isl,rsbp1) ];

HVDCReserveBreakPointMWLoss(dt,isl,rsbp)
    $ { (ord(rsbp) > 7) and (ord(rsbp) <= 13) }
    = HVDCSentBreakPointMWLoss(dt,isl,rsbp-6);

* Parameter for lambda loss model  end

* Initialze parameters for NMIR project end ----------------------------------


* Initialise risk/reserve data for the current trade period start

GenRisk(riskC)     $ (ord(riskC) = 1) = yes ;
HVDCrisk(riskC)    $ (ord(riskC) = 2) = yes ;
HVDCrisk(riskC)    $ (ord(riskC) = 3) = yes ;
ManualRisk(riskC)  $ (ord(riskC) = 4) = yes ;
GenRisk(riskC)     $ (ord(riskC) = 5) = yes ;
ManualRisk(riskC)  $ (ord(riskC) = 6) = yes ;
HVDCsecRisk(riskC) $ (ord(riskC) = 7) = yes ;
HVDCsecRisk(riskC) $ (ord(riskC) = 8) = yes ;

* Define the CE and ECE risk class set to support the different CE and ECE CVP
ContingentEvents(riskC)        $ (ord(riskC) = 1) = yes ;
ContingentEvents(riskC)        $ (ord(riskC) = 2) = yes ;
ExtendedContingentEvent(riskC) $ (ord(riskC) = 3) = yes ;
ContingentEvents(riskC)        $ (ord(riskC) = 4) = yes ;
ExtendedContingentEvent(riskC) $ (ord(riskC) = 5) = yes ;
ExtendedContingentEvent(riskC) $ (ord(riskC) = 6) = yes ;
ContingentEvents(riskC)        $ (ord(riskC) = 7) = yes ;
ExtendedContingentEvent(riskC) $ (ord(riskC) = 8) = yes ;

* Risk parameters
FreeReserve(dt,isl,resC,riskC)
    = riskParameter(dt,isl,resC,riskC,'freeReserve')
* NMIR - Subtract shareNFRMax from current NFR -(5.2.1.4) - SPD version 11
    - sum[ isl1 $ (not sameas(isl,isl1)),sharedNFRMax(dt,isl1)
         ] $ { (ord(resC)=1) and ( (GenRisk(riskC)) or (ManualRisk(riskC)) )
           and (inputGDXGDate >= jdate(2016,10,20)) }
    ;

IslandRiskAdjustmentFactor(dt,isl,resC,riskC) $ useReserveModel
    = riskParameter(dt,isl,resC,riskC,'adjustFactor') ;

* HVDC rampup max - (6.5.1.2) - SPD version 12
HVDCpoleRampUp(dt,isl,resC,riskC)
    = riskParameter(dt,isl,resC,riskC,'HVDCRampUp') ;



* Initialise market node constraint data for the current trading period
MnodeConstraint(dt,MnodeCstr)
    $ { sum[ (offer(dt,o),resT,resC)
           $ { mnCstrEnrgFactors(dt,MnodeCstr,o) or
               mnCnstrResrvFactors(dt,MnodeCstr,o,resC,resT)
             }, 1
           ]
      or
        sum[ (bid(dt,bd),resC)
           $ { mnCnstrEnrgBidFactors(dt,MnodeCstr,bd) or
               mnCnstrResrvBidFactors(dt,MnodeCstr,bd,resC)
             }, 1
           ]
      } = yes ;

MnodeConstraintSense(MnodeConstraint)
    = mnCnstrRHS(MnodeConstraint,'cnstrSense') ;

MnodeConstraintLimit(MnodeConstraint)
    = mnCnstrRHS(MnodeConstraint,'cnstrLimit') ;


* Generation Ramp Pre_processing -----------------------------------------------

* For PRICERESPONSIVEIG generators, The RTD RampRateUp is capped: (4.7.2.2)
if studyMode = 101 or studyMode = 201 then
    RampRateUp(offer(dt,o)) $ { windOffer(offer) and priceResponsive(offer) }
        = Min[ RampRateUp(offer), rtdIgIncreaseLimit(dt)*60/intervalDuration ];
endif;

* Need to initiate value for this parameters before it is used
o_offerEnergy_TP(dt,o) = 0;


* TN - Pivot or demand analysis begin
$Ifi %opMode%=='PVT' $include "Pivot\vSPDSolvePivot_1.gms"
$Ifi %opMode%=='DPS' $include "Demand\vSPDSolveDPS_1.gms"
* TN - Pivot or demand analysis begin end

$offend
*=====================================================================================
* 7. The vSPD solve loop
*=====================================================================================
if (studyMode = 101 or studyMode = 201,
$include "vSPDsolve_RTP.gms"
) ;


unsolvedDT(dt) = yes;
VSPDModel(dt) = 0 ;
option clear = useBranchFlowMIP ;

While ( Sum[ dt $ unsolvedDT(dt), 1 ],
  exitLoop = 0;
  loop[ dt $ {unsolvedDT(dt) and (exitLoop = 0)},

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

    option clear = SCARCITYCOST;
    option clear = ENERGYSCARCITYBLK ;
    option clear = ENERGYSCARCITYNODE;

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
*   Disconnected bus post-processing
    option clear = busGeneration ;
    option clear = busLoad ;
    option clear = busDisconnected ;
    option clear = busPrice ;


*   End reset


*   7b. Initialise current trade period and model data -------------------------
    t(dt)  $ sequentialSolve       = yes;
    t(dt1) $ (not sequentialSolve) = yes;

*   Update initial MW if run NRSS, PRSS, NRSL, PRSL
    generationStart(offer(t(dt),o))
        $ (sum[ o1, generationStart(dt,o1)] = 0)
        = sum[ dt1 $ (ord(dt1) = ord(dt)-1), o_offerEnergy_TP(dt1,o) ] ;

*   Additional pre-processing on parameters end


*   7c. Updating the variable bounds before model solve ------------------------

* TN - Pivot or Demand Analysis - revise input data
$Ifi %opMode%=='PVT' $include "Pivot\vSPDSolvePivot_2.gms"
$Ifi %opMode%=='DPS' $include "Demand\vSPDSolveDPS_2.gms"
* TN - Pivot or Demand Analysis - revise input data end

*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS ========================

*   Offer blocks - Constraint 6.1.1.1
    GENERATIONBLOCK.up(genOfrBlk(t,o,blk))
        = EnrgOfrMW(genOfrBlk) ;

    GENERATIONBLOCK.fx(t,o,blk)
        $ (not genOfrBlk(t,o,blk)) = 0 ;

*   Constraint 6.1.1.2 - Fix the invalid generation to Zero
    GENERATION.fx(offer(t,o)) $ (not posEnrgOfr(offer)) = 0 ;

*   Constraint 6.1.1.3 - Set Upper Bound for intermittent generation
    GENERATION.up(offer(t,o))
        $ { windOffer(offer) and priceResponsive(offer) }
        = min[ potentialMW(offer), ReserveGenerationMaximum(offer) ] ;

*   Constraint 6.1.1.4 - Set Upper/Lower Bound for Positive Demand Bid
    PURCHASEBLOCK.up(demBidBlk(t,bd,blk))
        = DemBidMW(t,bd,blk) $ [DemBidMW(t,bd,blk)>0];

    PURCHASEBLOCK.lo(demBidBlk(t,bd,blk))
        = 0 $ [DemBidMW(t,bd,blk)>0];

*   Constraint 6.1.1.5 - Set Upper/Lower Bound for Negativetive Demand Bid
    PURCHASEBLOCK.up(demBidBlk(t,bd,blk)) $ [DemBidMW(t,bd,blk)<0] = 0;

    PURCHASEBLOCK.lo(demBidBlk(t,bd,blk))
        = DemBidMW(t,bd,blk) $ [DemBidMW(t,bd,blk)<0];

    PURCHASEBLOCK.fx(t,bd,blk)
        $ (not demBidBlk(t,bd,blk))
        = 0 ;

    PURCHASE.fx(t,bd) $ (sum[blk $ demBidBlk(t,bd,blk), 1] = 0) = 0 ;

*   Constraint 6.1.1.7 - Set Upper Bound for Energy Scaricty Block
    ENERGYSCARCITYBLK.up(t,n,blk) = ScarcityEnrgLimit(t,n,blk) ;
    ENERGYSCARCITYBLK.fx(t,n,blk) $ (not EnergyScarcityEnabled(t)) = 0;
    ENERGYSCARCITYNODE.fx(t,n) $ (not EnergyScarcityEnabled(t)) = 0;

*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS END ====================


*======= HVDC TRANSMISSION EQUATIONS ===========================================

*   Ensure that variables used to specify flow and losses on HVDC link are
*   zero for AC branches and for open HVDC links.
    HVDCLINKFLOW.fx(t,br)   $ (not HVDClink(t,br)) = 0 ;
    HVDCLINKLOSSES.fx(t,br) $ (not HVDClink(t,br)) = 0 ;

*   Apply an upper bound on the weighting parameter based on its definition
    LAMBDA.up(branch,bp) = 1 ;

*   Ensure that the weighting factor value is zero for AC branches and for
*   invalid loss segments on HVDC links
    LAMBDA.fx(HVDClink,bp)
        $ ( sum[fd $ validLossSegment(HVDClink,bp,fd),1] = 0 ) = 0 ;
    LAMBDA.fx(t,br,bp) $ (not HVDClink(t,br)) = 0 ;

*======= HVDC TRANSMISSION EQUATIONS END =======================================


*======= AC TRANSMISSION EQUATIONS =============================================

*   Ensure that variables used to specify flow and losses on AC branches are
*   zero for HVDC links branches and for open AC branches
    ACBRANCHFLOW.fx(t,br)              $ (not ACbranch(t,br)) = 0 ;
    ACBRANCHFLOWDIRECTED.fx(t,br,fd)   $ (not ACbranch(t,br)) = 0 ;
    ACBRANCHLOSSESDIRECTED.fx(t,br,fd) $ (not ACbranch(t,br)) = 0 ;

*   Ensure directed block flow and loss block variables are zero for
*   non-AC branches and invalid loss segments on AC branches
   ACBRANCHFLOWBLOCKDIRECTED.fx(t,br,los,fd)
       $ { not(ACbranch(t,br) and validLossSegment(t,br,los,fd)) } = 0 ;

   ACBRANCHLOSSESBLOCKDIRECTED.fx(t,br,los,fd)
       $ { not(ACbranch(t,br) and validLossSegment(t,br,los,fd)) } = 0 ;


*   Constraint 6.4.1.10 - Ensure that the bus voltage angle for the buses
*   corresponding to the reference nodes are set to zero
    ACNODEANGLE.fx(t,b)
       $ sum[ n $ { NodeBus(t,n,b) and  refNode(t,n) }, 1 ] = 0 ;

*======= AC TRANSMISSION EQUATIONS END =========================================


*======= RISK & RESERVE EQUATIONS ==============================================

*   Ensure that all the invalid reserve blocks are set to zero for offers and purchasers
    RESERVEBLOCK.fx(offer(t,o),blk,resC,resT)
        $ (not resOfrBlk(offer,blk,resC,resT)) = 0 ;

*   Reserve block maximum for offers and purchasers - Constraint 6.5.3.2.
    RESERVEBLOCK.up(resOfrBlk(t,o,blk,resC,resT))
        = ResOfrMW(resOfrBlk) ;

*   Fix the reserve variable for invalid reserve offers. These are offers that
*   are either not connected to the grid or have no reserve quantity offered.
    RESERVE.fx(t,o,resC,resT)
        $ (not sum[ blk $ resOfrBlk(t,o,blk,resC,resT), 1 ] ) = 0 ;

*   NMIR project variables
    HVDCSENT.fx(t,isl) $ (HVDCCapacity(t,isl) = 0) = 0 ;
    HVDCSENTLOSS.fx(t,isl) $ (HVDCCapacity(t,isl) = 0) = 0 ;

*   Total shared NFR is capped by shared NFR max(6.5.2.3)
    SHAREDNFR.up(t,isl) = Max[0,sharedNFRMax(t,isl)] ;

*   No forward reserve sharing if HVDC capacity is zero
    RESERVESHARESENT.fx(t,isl,resC,rd)
        $ { (HVDCCapacity(t,isl) = 0) and (ord(rd) = 1) } = 0 ;

*   No forward reserve sharing if reserve sharing is disabled
    RESERVESHARESENT.fx(t,isl,resC,rd)
        $ (reserveShareEnabled(t,resC)=0) = 0;

*   No reserve sharing to cover HVDC risk
    RESERVESHAREEFFECTIVE.fx(t,isl,resC,HVDCrisk) = 0;
    RESERVESHAREEFFECTIVE.fx(t,isl,resC,HVDCsecRisk) = 0;

*   (6.5.2.16) - SPD version 11 - no RP zone if reserve round power disabled
    INZONE.fx(t,isl,resC,z)
        $ {(ord(z) = 1) and (not reserveRoundPower(t,resC))} = 0;

*   (6.5.2.17) - SPD version 11 - no no-reserve zone for SIR zone if reserve RP enabled
    INZONE.fx(t,isl,resC,z)
        $ {(ord(resC)=2) and (ord(z)=2) and reserveRoundPower(t,resC)} = 0;

*   Fixing Lambda integer variable for energy sent
    LAMBDAHVDCENERGY.fx(t,isl,bp) $ { (HVDCCapacity(t,isl) = 0)
                                        and (ord(bp) = 1) } = 1 ;

    LAMBDAHVDCENERGY.fx(t,isl,bp) $ (ord(bp) > 7) = 0 ;

* To be reviewed NMIR
    LAMBDAHVDCRESERVE.fx(t,isl,resC,rd,rsbp)
        $ { (HVDCCapacity(t,isl) = 0)
        and (ord(rsbp) = 7) and (ord(rd) = 1) } = 1 ;

    LAMBDAHVDCRESERVE.fx(t,isl1,resC,rd,rsbp)
        $ { (sum[ isl $ (not sameas(isl,isl1)), HVDCCapacity(t,isl) ] = 0)
        and (ord(rsbp) < 7) and (ord(rd) = 2) } = 0 ;

*   Contraint 6.5.4.2 - Set Upper Bound for reserve shortfall
    RESERVESHORTFALLBLK.up(t,isl,resC,riskC,blk)
        = scarcityResrvIslandLimit(t,isl,resC,blk) $ reserveScarcityEnabled(t);
    RESERVESHORTFALLBLK.fx(t,isl,resC,riskC,blk)
        $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALL.fx(t,isl,resC,riskC)
        $ (not reserveScarcityEnabled(t)) = 0;

    RESERVESHORTFALLUNITBLK.up(t,isl,o,resC,riskC,blk)
        = scarcityResrvIslandLimit(t,isl,resC,blk) $ reserveScarcityEnabled(t);
    RESERVESHORTFALLUNITBLK.fx(t,isl,o,resC,riskC,blk)
        $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALLUNIT.fx(t,isl,o,resC,riskC)
        $ (not reserveScarcityEnabled(t)) = 0;

    RESERVESHORTFALLGROUPBLK.up(t,isl,rg,resC,riskC,blk)
        = scarcityResrvIslandLimit(t,isl,resC,blk) $ reserveScarcityEnabled(t);
    RESERVESHORTFALLGROUPBLK.fx(t,isl,rg,resC,riskC,blk)
        $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALLGROUP.fx(t,isl,rg,resC,riskC)
        $ (not reserveScarcityEnabled(t)) = 0;
;


*======= RISK & RESERVE EQUATIONS END ==========================================


*   Updating the variable bounds before model solve end


*   7d. Solve Models

*   Solve the LP model ---------------------------------------------------------
    if( (Sum[t, VSPDModel(t)] = 0),

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
            putclose rep 'The case: %GDXname% '
                         'is solved successfully.'/
                         'Objective function value: '
                         NETBENEFIT.l:<15:4 /
                         'Violation Cost          : '
                         TOTALPENALTYCOST.l:<15:4 /
        elseif((ModelSolved = 0) and (sequentialSolve = 0)),
            putclose rep 'The case: %GDXname% '
                         'is solved unsuccessfully.'/
        ) ;

        if((ModelSolved = 1) and (sequentialSolve = 1),
            loop(t,
                putclose rep 'The case: %GDXname% (' t.tl ') '
                             'is solved successfully.'/
                             'Objective function value: '
                             NETBENEFIT.l:<15:4 /
                             'Violations cost         : '
                             TOTALPENALTYCOST.l:<15:4 /
            ) ;
        elseif((ModelSolved = 0) and (sequentialSolve = 1)),
            loop(t,
                unsolvedDT(t) = no;
                putclose rep 'The case: %GDXname% (' t.tl ') '
                             'is solved unsuccessfully.'/
            ) ;

        ) ;
*   Solve the LP model end -----------------------------------------------------


*   Solve the vSPD_BranchFlowMIP -----------------------------------------------
    elseif (Sum[t, VSPDModel(t)] = 1),
*       Fix the values of these integer variables that are not needed
        ACBRANCHFLOWDIRECTED_INTEGER.fx(branch(t,br),fd)
            $ { (not ACbranch(t,br)) or (not LossBranch(branch)) } = 0 ;

*       Fix the integer AC branch flow variable to zero for invalid branches
        ACBRANCHFLOWDIRECTED_INTEGER.fx(t,br,fd)
            $ (not branch(t,br)) = 0 ;

*       Apply an upper bound on the integer weighting parameter
        LAMBDAINTEGER.up(branch(t,br),bp) = 1 ;

*       Ensure that the weighting factor value is zero for AC branches
*       and for invalid loss segments on HVDC links
        LAMBDAINTEGER.fx(branch(t,br),bp)
            $ { ACbranch(branch)
            or ( sum[fd $ validLossSegment(branch,bp,fd),1 ] = 0 )
              } = 0 ;

*       Fix the lambda integer variable to zero for invalid branches
        LAMBDAINTEGER.fx(t,br,bp) $ (not branch(t,br)) = 0 ;

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
            SOS1_solve(t)  = yes;

            loop(t,
                putclose rep 'The case: %GDXname% (' t.tl ') '
                             'is solved successfully for branch integer.'/
                             'Objective function value: '
                             NETBENEFIT.l:<15:4 /
                             'Violations cost         : '
                             TOTALPENALTYCOST.l:<15:4 /
            ) ;
        else
            loop(t,
                unsolvedDT(t) = yes;
                VSPDModel(t) = 2;
                putclose rep 'The case: %GDXname% (' t.tl ') '
                             'is solved unsuccessfully for branch integer.'/
            ) ;
        ) ;
*   Solve the vSPD_BranchFlowMIP model end -------------------------------------


*   Solve the LP model and stop ------------------------------------------------
    elseif (Sum[t, VSPDModel(t)] = 2),

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
            loop(t,
                putclose rep 'The case: %GDXname% (' t.tl ')'
                                ' integer resolve was unsuccessful.' /
                                'Reverting back to linear solve and '
                                'solve successfully. ' /
                                'Objective function value: '
                                NETBENEFIT.l:<15:4 /
                                'Violations cost         : '
                                TOTALPENALTYCOST.l:<15:4 /
                                'Solution may have circulating flows '
                                'and/or non-physical losses.' /
            ) ;
        else
            loop(t,
                putclose rep 'The case: %GDXname% (' t.tl
                                ') integer solve was unsuccessful. '
                                'Reverting back to linear solve. '
                                'Linear solve unsuccessful.' /
            ) ;
        ) ;

        unsolvedDT(t) = no;

*   Solve the LP model and stop end --------------------------------------------

    ) ;
*   Solve the models end



*   6e. Check if the LP results are valid --------------------------------------
    if((ModelSolved = 1),
        useBranchFlowMIP(t) = 0 ;
*       Check if there is no branch circular flow and non-physical losses
        Loop( t $ (VSPDModel(t)=0) ,

*           Check if there are circulating branch flows on loss AC branches
            circularBranchFlowExist(ACbranch(t,br))
                $ { LossBranch(ACbranch) and
                    [ ( sum[ fd, ACBRANCHFLOWDIRECTED.l(ACbranch,fd) ]
                      - abs(ACBRANCHFLOW.l(ACbranch))
                      ) > circularBranchFlowTolerance
                    ]
                  } = 1 ;

*           Determine the circular branch flow flag on each HVDC pole
            TotalHVDCpoleFlow(t,pole)
                = sum[ br $ HVDCpoleBranchMap(pole,br)
                     , HVDCLINKFLOW.l(t,br) ] ;

            MaxHVDCpoleFlow(t,pole)
                = smax[ br $ HVDCpoleBranchMap(pole,br)
                      , HVDCLINKFLOW.l(t,br) ] ;

            poleCircularBranchFlowExist(t,pole)
                $ { ( TotalHVDCpoleFlow(t,pole)
                    - MaxHVDCpoleFlow(t,pole)
                    ) > circularBranchFlowTolerance
                  } = 1 ;

*           Check if there are circulating branch flows on HVDC
            NorthHVDC(t)
                = sum[ (isl,b,br) $ { (ord(isl) = 2) and
                                      busIsland(t,b,isl) and
                                      HVDClinkSendingBus(t,br,b) and
                                      HVDClink(t,br)
                                    }, HVDCLINKFLOW.l(t,br)
                     ] ;

            SouthHVDC(t)
                = sum[ (isl,b,br) $ { (ord(isl) = 1) and
                                      busIsland(t,b,isl) and
                                      HVDClinkSendingBus(t,br,b) and
                                      HVDClink(t,br)
                                    }, HVDCLINKFLOW.l(t,br)
                     ] ;

            circularBranchFlowExist(t,br)
                $ { HVDClink(t,br) and LossBranch(t,br) and
                   (NorthHVDC(t) > circularBranchFlowTolerance) and
                   (SouthHVDC(t) > circularBranchFlowTolerance)
                  } = 1 ;

*           Check if there are non-physical losses on HVDC links
            ManualBranchSegmentMWFlow(LossBranch(HVDClink(t,br)),los,fd)
                $ { ( ord(los) <= branchLossBlocks(HVDClink) )
                and validLossSegment(t,br,los,fd) }
                = Min[ Max( 0,
                            [ abs(HVDCLINKFLOW.l(HVDClink))
                            - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                            ]
                          ),
                       ( LossSegmentMW(HVDClink,los,fd)
                       - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                       )
                     ] ;

            ManualLossCalculation(LossBranch(HVDClink(t,br)))
                = sum[ (los,fd) $ validLossSegment(t,br,los,fd)
                                , LossSegmentFactor(HVDClink,los,fd)
                                * ManualBranchSegmentMWFlow(HVDClink,los,fd)
                     ] ;

            NonPhysicalLossExist(LossBranch(HVDClink(t,br)))
                $ { abs( HVDCLINKLOSSES.l(HVDClink)
                       - ManualLossCalculation(HVDClink)
                       ) > NonPhysicalLossTolerance
                  } = 1 ;

*           Set UseBranchFlowMIP = 1 if the number of circular branch flow
*           and non-physical loss branches exceeds the specified tolerance
            useBranchFlowMIP(t)
                $ { ( sum[ br $ { ACbranch(t,br) and LossBranch(t,br) }
                              , resolveCircularBranchFlows
                              * circularBranchFlowExist(t,br)
                         ]
                    + sum[ br $ { HVDClink(t,br) and LossBranch(t,br) }
                              , resolveCircularBranchFlows
                              * circularBranchFlowExist(t,br)
                              + resolveHVDCnonPhysicalLosses
                              * NonPhysicalLossExist(t,br)
                         ]
                    + sum[ pole, resolveCircularBranchFlows
                               * poleCircularBranchFlowExist(t,pole)
                         ]
                     ) > UseBranchFlowMIPTolerance
                  } = 1 ;

*       Check if there is no branch circular flow and non-physical losses end
        );

*       A period is unsolved if MILP model is required
        unsolvedDT(t) = yes $ UseBranchFlowMIP(t) ;

*       Post a progress message for use by EMI. Reverting to the sequential mode for integer resolves.
        loop( unsolvedDT(t),
            if( UseBranchFlowMIP(t) >= 1,
                VSPDModel(t) = 1;
                putclose rep 'The case: %GDXname% requires a '
                                    'vSPD_BranchFlowMIP resolve for period '
                                    t.tl '. Switching Vectorisation OFF.'/
            ) ;

        ) ;

        sequentialSolve $ Sum[ unsolvedDT(t), 1 ] = 1 ;
        exitLoop = 1 $ Sum[ unsolvedDT(t), 1 ];

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
    Scenario E: Price for bus in live electrical island with zero load needs to
                be adjusted since actually is disconnected.

    The Post-MSP implementation imply a mapping of a bus to an electrical island
    and an indication of whether this electrical island is live of dead.
    The correction of the prices is performed by SPD.
$offtext

    busGeneration(bus(t,b))
        = sum[ (o,n) $ { offerNode(t,o,n) and NodeBus(t,n,b) }
             , NodeBusAllocationFactor(t,n,b) * GENERATION.l(t,o)
             ] ;

    busLoad(bus(t,b))
        = sum[ NodeBus(t,n,b)
             , NodeBusAllocationFactor(t,n,b) * RequiredLoad(t,n)
             ] ;

    busPrice(bus(t,b)) = ACnodeNetInjectionDefinition2.m(t,b) ;

    if((disconnectedNodePriceCorrection = 1),
*       Post-MSP cases
*       Scenario C/F/G/H/I:
        busDisconnected(bus(t,b)) $ { (busLoad(bus) = 0)
                                      and (busElectricalIsland(bus) = 0)
                                    } = 1 ;
*       Scenario E:
        busDisconnected(bus(t,b))
            $ { ( sum[ b1 $ { busElectricalIsland(t,b1)
                            = busElectricalIsland(bus) }
                     , busLoad(t,b1) ] = 0
                ) and
                ( busElectricalIsland(bus) > 0 )
              } = 1 ;
*       Set prices at dead buses with non-zero load
        busPrice(bus(t,b)) $ { (busLoad(bus) > 0) and
                               (busElectricalIsland(bus)= 0)
                             } = DeficitBusGenerationPenalty ;

        busPrice(bus(t,b)) $ { (busLoad(bus) < 0) and
                               (busElectricalIsland(bus)= 0)
                             } = -SurplusBusGenerationPenalty ;

*       Set price at identified disconnected buses to 0
        busPrice(bus)$busDisconnected(bus) = 0 ;
    ) ;

* End Check for disconnected nodes and adjust prices accordingly

* TN - Replacing invalid prices after SOS1
*   6f0. Replacing invalid prices after SOS1 (7.1.3)----------------------------
    if ( SOS1_solve(dt),
         busSOSinvalid(dt,b)
           = 1 $ { [ ( busPrice(dt,b) = 0 )
                    or ( busPrice(dt,b) > 0.9 * deficitBusGenerationPenalty )
                    or ( busPrice(dt,b) < -0.9 * surplusBusGenerationPenalty )
                     ]
                 and bus(dt,b)
                 and [ not busDisconnected(dt,b) ]
                 and [ busLoad(dt,b) = busGeneration(dt,b) ]
                 and [ sum[(br,fd)
                          $ { BranchBusConnect(dt,br,b) and branch(dt,br) }
                          , ACBRANCHFLOWDIRECTED.l(dt,br,fd)
                          ] = 0
                     ]
                 and [ sum[ br
                          $ { BranchBusConnect(dt,br,b) and branch(dt,br) }
                          , 1
                          ] > 0
                     ]
                   };
        numberofbusSOSinvalid(dt) = 2*sum[b, busSOSinvalid(dt,b)];
        While ( sum[b, busSOSinvalid(dt,b)] < numberofbusSOSinvalid(dt) ,
            numberofbusSOSinvalid(dt) = sum[b, busSOSinvalid(dt,b)];
            busPrice(dt,b)
              $ { busSOSinvalid(dt,b)
              and ( sum[ b1 $ { [ not busSOSinvalid(dt,b1) ]
                            and sum[ br $ { branch(dt,br)
                                        and BranchBusConnect(dt,br,b)
                                        and BranchBusConnect(dt,br,b1)
                                          }, 1
                                   ]
                             }, 1
                       ] > 0
                  )
                }
              = sum[ b1 $ { [ not busSOSinvalid(dt,b1) ]
                        and sum[ br $ { branch(dt,br)
                                    and BranchBusConnect(dt,br,b)
                                    and BranchBusConnect(dt,br,b1)
                                      }, 1 ]
                          }, busPrice(dt,b1)
                   ]
              / sum[ b1 $ { [ not busSOSinvalid(dt,b1) ]
                        and sum[ br $ { branch(dt,br)
                                    and BranchBusConnect(dt,br,b)
                                    and BranchBusConnect(dt,br,b1)
                                      }, 1 ]
                          }, 1
                   ];

            busSOSinvalid(dt,b)
              = 1 $ { [ ( busPrice(dt,b) = 0 )
                     or ( busPrice(dt,b) > 0.9 * deficitBusGenerationPenalty )
                     or ( busPrice(dt,b) < -0.9 * surplusBusGenerationPenalty )
                      ]
                  and bus(dt,b)
                  and [ not busDisconnected(dt,b) ]
                  and [ busLoad(dt,b) = busGeneration(dt,b) ]
                  and [ sum[(br,fd)
                          $ { BranchBusConnect(dt,br,b) and branch(dt,br) }
                          , ACBRANCHFLOWDIRECTED.l(dt,br,fd)
                           ] = 0
                      ]
                  and [ sum[ br
                           $ { BranchBusConnect(dt,br,b) and branch(dt,br) }
                           , 1
                           ] > 0
                      ]
                    };
         );
    );
*   End Replacing invalid prices after SOS1 (7.1.3) ----------------------------


*   6g. Collect and store results of solved periods into output parameters -----
* Note: all the price relating outputs such as costs and revenues are calculated in section 7.b

$iftheni.PeriodReport %opMode%=='FTR' $include "FTRental\vSPDSolveFTR_3.gms"
$elseifi.PeriodReport %opMode%=='DWH' $include "DWmode\vSPDSolveDWH_3.gms"
$elseifi.PeriodReport %opMode%=='PVT' $include "Pivot\vSPDSolvePivot_3.gms"
$elseifi.PeriodReport %opMode%=='DPS' $include "Demand\vSPDSolveDPS_3.gms"

$else.PeriodReport
$onend
*   Normal vSPD run - write results out for for reporting
    Loop t $ (not unsolvedDT(t)) do
*   Reporting at trading period start
*       Node level output
        o_nodeGeneration_TP(t,n) $ Node(t,n)
            = sum[ o $ offerNode(t,o,n), GENERATION.l(t,o) ] ;

        o_nodeLoad_TP(t,n) $ Node(t,n)
           = RequiredLoad(t,n)
           + Sum[ bd $ bidNode(t,bd,n), PURCHASE.l(t,bd) ];

        o_nodePrice_TP(t,n) $ Node(t,n)
            = sum[ b $ NodeBus(t,n,b)
                 , NodeBusAllocationFactor(t,n,b) * busPrice(t,b)
                  ] ;

        if { runPriceTransfer(t)
        and ( (studyMode = 101) or (studyMode = 201) or (studyMode = 130))
           }   then
            o_nodeDead_TP(t,n)
                = 1 $ ( sum[b $ {NodeBus(t,n,b) and (not busDisconnected(t,b))
                                }, NodeBusAllocationFactor(t,n,b) ] = 0 ) ;

            o_nodeDeadPriceFrom_TP(t,n,n1)
                = 1 $ {o_nodeDead_TP(t,n) and node2node(t,n,n1)};

            o_nodeDeadPrice_TP(t,n) $ o_nodeDead_TP(t,n) = 1;

            While sum[ n $ o_nodeDead_TP(t,n), o_nodeDeadPrice_TP(t,n) ] do
                o_nodePrice_TP(t,n)
                    $ { o_nodeDead_TP(t,n) and o_nodeDeadPrice_TP(t,n) }
                    = sum[n1 $ o_nodeDeadPriceFrom_TP(t,n,n1)
                             , o_nodePrice_TP(t,n1) ] ;

                o_nodeDeadPrice_TP(t,n)
                    = 1 $ sum[n1 $ o_nodeDead_TP(t,n1)
                                 , o_nodeDeadPriceFrom_TP(t,n,n1) ];

                o_nodeDeadPriceFrom_TP(t,n,n2) $ o_nodeDeadPrice_TP(t,n)
                    = 1 $ { sum[ n1 $ { node2node(t,n1,n2)
                                    and o_nodeDeadPriceFrom_TP(t,n,n1) }, 1 ]
                          } ;

                o_nodeDeadPriceFrom_TP(t,n,n1) $ o_nodeDead_TP(t,n1) = 0 ;

            endwhile
        endif;

*       Offer output
        o_offerEnergy_TP(t,o) $ offer(t,o) = GENERATION.l(t,o) ;

        o_offerRes_TP(t,o,resC) $ offer(t,o)
            = sum[ resT, RESERVE.l(t,o,resC,resT) ] ;

        o_offerFIR_TP(t,o) $ offer(t,o)
            = sum[ resC $ (ord(resC) = 1),o_offerRes_TP(t,o,resC) ] ;

        o_offerSIR_TP(t,o) $ offer(t,o)
            = sum[ resC $ (ord(resC) = 2),o_offerRes_TP(t,o,resC) ] ;

*       Risk group output
        o_groupEnergy_TP(t,rg,GenRisk)
            = sum[ o $ riskGroupOffer(t,rg,o,GenRisk), o_offerEnergy_TP(t,o) ];

        o_groupFKband_TP(t,rg,GenRisk)
            = sum[ o $ riskGroupOffer(t,rg,o,GenRisk), FKBand(t,o) ];

        o_groupRes_TP(t,rg,resC,GenRisk)
            = sum[ o $ riskGroupOffer(t,rg,o,GenRisk), o_offerRes_TP(t,o,resC)];

*       Bus level output
        o_busGeneration_TP(t,b) $ bus(t,b) = busGeneration(t,b) ;

        o_busLoad_TP(t,b) $ bus(t,b)
            = busLoad(t,b)
            + Sum[ (bd,n) $ { bidNode(t,bd,n) and NodeBus(t,n,b) }
                 , PURCHASE.l(t,bd) ];

        o_busPrice_TP(t,b) $ bus(t,b) = busPrice(t,b) ;

        o_busDeficit_TP(t,b) $ bus(t,b)
            = DEFICITBUSGENERATION.l(t,b)
            + sum[n, NodeBusAllocationFactor(t,n,b)*ENERGYSCARCITYNODE.l(t,n)];

        o_busSurplus_TP(t,b)$bus(t,b) = SURPLUSBUSGENERATION.l(t,b) ;

*       Node level output

        totalBusAllocation(t,b) $ bus(t,b)
            = sum[ n $ Node(t,n), NodeBusAllocationFactor(t,n,b)];

        busNodeAllocationFactor(t,b,n) $ (totalBusAllocation(t,b) > 0)
            = NodeBusAllocationFactor(t,n,b) / totalBusAllocation(t,b) ;

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
        unmappedDeficitBus(t,b) $ o_busDeficit_TP(t,b)
            = yes $ (Sum[ n, busNodeAllocationFactor(t,b,n)] = 0);

        changedDeficitBus(t,b) = no;

        If Sum[b $ unmappedDeficitBus(t,b), 1] then

            temp_busDeficit_TP(t,b) = o_busDeficit_TP(t,b);

            Loop b $ unmappedDeficitBus(t,b) do
                o_busDeficit_TP(t,b1)
                  $ { Sum[ br $ { ( branchLossBlocks(t,br)=0 )
                              and ( branchBusDefn(t,br,b1,b)
                                 or branchBusDefn(t,br,b,b1) )
                                }, 1 ]
                    } = o_busDeficit_TP(t,b1) + o_busDeficit_TP(t,b) ;

                changedDeficitBus(t,b1)
                  $ Sum[ br $ { ( branchLossBlocks(t,br)=0 )
                            and ( branchBusDefn(t,br,b1,b)
                               or branchBusDefn(t,br,b,b1) )
                              }, 1 ] = yes;

                unmappedDeficitBus(t,b) = no;
                changedDeficitBus(t,b) = no;
                o_busDeficit_TP(t,b) = 0;
            EndLoop;

            Loop n $ sum[ b $ changedDeficitBus(t,b)
                        , busNodeAllocationFactor(t,b,n)] do
                o_nodePrice_TP(t,n) = deficitBusGenerationPenalty ;
                o_nodeDeficit_TP(t,n) = sum[ b $ busNodeAllocationFactor(t,b,n),
                                                  busNodeAllocationFactor(t,b,n)
                                                * o_busDeficit_TP(t,b) ] ;
            EndLoop;

            o_busDeficit_TP(t,b) = temp_busDeficit_TP(t,b);
        Endif;
* TN - post processing unmapped generation deficit buses end

        o_nodeDeficit_TP(t,n) $ Node(t,n)
            = sum[ b $ NodeBus(t,n,b), busNodeAllocationFactor(t,b,n)
                                          * DEFICITBUSGENERATION.l(t,b) ] ;

        o_nodeSurplus_TP(t,n) $ Node(t,n)
            = sum[ b $ NodeBus(t,n,b), busNodeAllocationFactor(t,b,n)
                                          * SURPLUSBUSGENERATION.l(t,b) ] ;

*       branch output
        o_branchFlow_TP(t,br) $ ACbranch(t,br) = ACBRANCHFLOW.l(t,br);

        o_branchFlow_TP(t,br) $ HVDClink(t,br) = HVDCLINKFLOW.l(t,br);

        o_branchDynamicLoss_TP(t,br) $  ACbranch(t,br)
            = sum[ fd, ACBRANCHLOSSESDIRECTED.l(t,br,fd) ] ;

        o_branchDynamicLoss_TP(t,br) $ HVDClink(t,br)
            = HVDCLINKLOSSES.l(t,br) ;

        o_branchFixedLoss_TP(t,br) $ branch(t,br)
            = branchFixedLoss(t,br) ;

        o_branchTotalLoss_TP(t,br) $ branch(t,br)
            = o_branchDynamicLoss_TP(t,br) + o_branchFixedLoss_TP(t,br) ;

        o_branchMarginalPrice_TP(t,br) $ ACbranch(t,br)
            = sum[ fd, ACbranchMaximumFlow.m(t,br,fd) ] ;

        o_branchMarginalPrice_TP(t,br) $ HVDClink(t,br)
            = HVDClinkMaximumFlow.m(t,br) ;

        o_branchCapacity_TP(t,br) $ branch(t,br)
            = sum[ fd $ ( ord(fd) = 1 )
                      , branchCapacity(t,br,fd)
                 ] $  { o_branchFlow_TP(t,br) >= 0 }
            + sum[ fd $ ( ord(fd) = 2 )
                      , branchCapacity(t,br,fd)
                 ] $  { o_branchFlow_TP(t,br) < 0 } ;

*       bid output
        o_bidEnergy_TP(t,bd) $ bid(t,bd) = PURCHASE.l(t,bd) ;

        o_bidTotalMW_TP(t,bd) $ bid(t,bd)
            = sum[ blk, DemBidMW(t,bd,blk) ] ;

*       Violation reporting based on the CE and ECE
        o_ResViolation_TP(t,isl,resC)
            = DEFICITRESERVE_CE.l(t,isl,resC)
            + DEFICITRESERVE_ECE.l(t,isl,resC)  ;

        o_FIRviolation_TP(t,isl)
            = sum[ resC $ (ord(resC) = 1), o_ResViolation_TP(t,isl,resC) ] ;

        o_SIRviolation_TP(t,isl)
            = sum[ resC $ (ord(resC) = 2), o_ResViolation_TP(t,isl,resC) ] ;

*       Risk marginal prices and shortfall outputs
        o_GenRiskPrice_TP(t,isl,o,resC,GenRisk)
            = -GenIslandRiskCalculation_1.m(t,isl,o,resC,GenRisk) ;

        o_GenRiskShortfall_TP(t,isl,o,resC,GenRisk)
            = RESERVESHORTFALLUNIT.l(t,isl,o,resC,GenRisk) ;

        o_HVDCSecRiskPrice_TP(t,isl,o,resC,HVDCSecRisk)
            = -HVDCIslandSecRiskCalculation_GEN_1.m(t,isl,o,resC,HVDCSecRisk) ;

        o_HVDCSecRiskShortfall_TP(t,isl,o,resC,HVDCSecRisk)
            = RESERVESHORTFALLUNIT.l(t,isl,o,resC,HVDCSecRisk) ;

        o_GenRiskGroupPrice_TP(t,isl,rg,resC,GenRisk)
            = -GenIslandRiskGroupCalculation_1.m(t,isl,rg,resC,GenRisk) ;

        o_GenRiskGroupShortfall_TP(t,isl,rg,resC,GenRisk)
            = RESERVESHORTFALLGROUP.l(t,isl,rg,resC,GenRisk) ;

        o_HVDCRiskPrice_TP(t,isl,resC,HVDCrisk)
            = -HVDCIslandRiskCalculation.m(t,isl,resC,HVDCrisk);

        o_HVDCRiskShortfall_TP(t,isl,resC,HVDCrisk)
            = RESERVESHORTFALL.l(t,isl,resC,HVDCrisk);


        o_ManualRiskPrice_TP(t,isl,resC,ManualRisk)
            = -ManualIslandRiskCalculation.m(t,isl,resC,ManualRisk) ;

        o_ManualRiskShortfall_TP(t,isl,resC,ManualRisk)
            = RESERVESHORTFALL.l(t,isl,resC,ManualRisk) ;

        o_HVDCSecManualRiskPrice_TP(t,isl,resC,HVDCSecRisk)
            = -HVDCIslandSecRiskCalculation_Manu_1.m(t,isl,resC,HVDCSecRisk);

        o_HVDCSecManualRiskShortfall_TP(t,isl,resC,HVDCSecRisk)
            = RESERVESHORTFALL.l(t,isl,resC,HVDCSecRisk) ;

*       Security constraint data

        o_brConstraintSense_TP(t,brCstr) $ branchConstraint(t,brCstr)
            = branchConstraintSense(t,brCstr) ;

        o_brConstraintLHS_TP(t,brCstr) $ branchConstraint(t,brCstr)
            = [ branchSecurityConstraintLE.l(t,brCstr)
              $ (branchConstraintSense(t,brCstr) = -1) ] ;

        o_brConstraintRHS_TP(t,brCstr) $ branchConstraint(t,brCstr)
            = branchConstraintLimit(t,brCstr) ;

        o_brConstraintPrice_TP(t,brCstr) $ branchConstraint(t,brCstr)
            = [ branchSecurityConstraintLE.m(t,brCstr)
              $ (branchConstraintSense(t,brCstr) = -1) ] ;

*       Mnode constraint data
        o_MnodeConstraintSense_TP(t,MnodeCstr)
            $ MnodeConstraint(t,MnodeCstr)
            = MnodeConstraintSense(t,MnodeCstr) ;

        o_MnodeConstraintLHS_TP(t,MnodeCstr)
            $ MnodeConstraint(t,MnodeCstr)
            = [ MnodeSecurityConstraintLE.l(t,MnodeCstr)
              $ (MnodeConstraintSense(t,MnodeCstr) = -1) ]
            + [ MnodeSecurityConstraintGE.l(t,MnodeCstr)
              $ (MnodeConstraintSense(t,MnodeCstr) = 1)  ]
            + [ MnodeSecurityConstraintEQ.l(t,MnodeCstr)
              $ (MnodeConstraintSense(t,MnodeCstr) = 0)  ] ;

        o_MnodeConstraintRHS_TP(t,MnodeCstr)
            $ MnodeConstraint(t,MnodeCstr)
            = MnodeConstraintLimit(t,MnodeCstr) ;

        o_MnodeConstraintPrice_TP(t,MnodeCstr)
            $ MnodeConstraint(t,MnodeCstr)
            = [ MnodeSecurityConstraintLE.m(t,MnodeCstr)
              $ (MnodeConstraintSense(t,MnodeCstr) = -1) ]
            + [ MnodeSecurityConstraintGE.m(t,MnodeCstr)
              $ (MnodeConstraintSense(t,MnodeCstr) = 1)  ]
            + [ MnodeSecurityConstraintEQ.m(t,MnodeCstr)
              $ (MnodeConstraintSense(t,MnodeCstr) = 0)  ] ;

*       Island output
        o_ResPrice_TP(t,isl,resC)= IslandReserveCalculation.m(t,isl,resC);

        o_FIRprice_TP(t,isl) = sum[ resC $ (ord(resC) = 1)
                                          , o_ResPrice_TP(t,isl,resC) ];

        o_SIRprice_TP(t,isl) = sum[ resC $ (ord(resC) = 2)
                                          , o_ResPrice_TP(t,isl,resC) ];

        o_islandGen_TP(t,isl)
            = sum[ b $ busIsland(t,b,isl), busGeneration(t,b) ] ;

        o_islandClrBid_TP(t,isl)
            = sum[ bd $ bidIsland(t,bd,isl), PURCHASE.l(t,bd) ] ;

        o_islandLoad_TP(t,isl)
            = sum[ b $ busIsland(t,b,isl), busLoad(t,b) ]
            + o_islandClrBid_TP(t,isl) ;

        o_ResCleared_TP(t,isl,resC) = ISLANDRESERVE.l(t,isl,resC);

        o_FirCleared_TP(t,isl) = Sum[ resC $ (ord(resC) = 1)
                                            , o_ResCleared_TP(t,isl,resC) ];

        o_SirCleared_TP(t,isl) = Sum[ resC $ (ord(resC) = 2)
                                            , o_ResCleared_TP(t,isl,resC) ];

        o_islandBranchLoss_TP(t,isl)
            = sum[ (br,frB,toB)
                 $ { ACbranch(t,br) and busIsland(t,toB,isl)
                 and branchBusDefn(t,br,frB,toB)
                   }, o_branchTotalLoss_TP(t,br) ] ;

        o_HVDCflow_TP(t,isl)
            = sum[ (br,frB,toB)
                 $ { HVDClink(t,br) and busIsland(t,frB,isl)
                 and branchBusDefn(t,br,frB,toB)
                   }, o_branchFlow_TP(t,br) ] ;


        o_HVDCpoleFixedLoss_TP(t,isl)
            = sum[ (br,frB,toB) $ { HVDClink(t,br) and
                                    branchBusDefn(t,br,frB,toB) and
                                    ( busIsland(t,toB,isl) or
                                      busIsland(t,frB,isl)
                                    )
                                  }, 0.5 * o_branchFixedLoss_TP(t,br)
                 ] ;

        o_HVDCloss_TP(t,isl)
            = o_HVDCpoleFixedLoss_TP(t,isl)
            + sum[ (br,frB,toB) $ { HVDClink(t,br) and
                                    branchBusDefn(t,br,frB,toB) and
                                    busIsland(t,toB,isl) and
                                    (not (busIsland(t,frB,isl)))
                                  }, o_branchDynamicLoss_TP(t,br)
                 ] ;

        o_HVDCreceived(t,isl) = HVDCREC.l(t,isl);

        o_HVDCRiskSubtractor(t,isl,resC,HVDCrisk)
            = RISKOFFSET.l(t,isl,resC,HVDCrisk) ;

* TN - The code below is added for NMIR project ================================
        o_EffectiveRes_TP(t,isl,resC,riskC) $ reserveShareEnabled(t,resC)
            = RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ;

        If Sum[ resC $ (ord(resC) = 1), reserveShareEnabled(t,resC)] then

            o_FirSent_TP(t,isl)
                = Sum[ (rd,resC) $ (ord(resC) = 1)
                     , RESERVESHARESENT.l(t,isl,resC,rd)];

            o_FirReceived_TP(t,isl)
                = Sum[ (rd,resC) $ (ord(resC) = 1)
                     , RESERVESHARERECEIVED.l(t,isl,resC,rd) ];

            o_FirEffectiveCE_TP(t,isl)
                = Smax[ (resC,riskC)
                      $ { (ord(resC) = 1) and ContingentEvents(riskC) }
                      , RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ];

            o_FirEffectiveECE_TP(t,isl)
                = Smax[ (resC,riskC)
                      $ { (ord(resC) = 1) and ExtendedContingentEvent(riskC) }
                      , RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ];

            o_FirEffReport_TP(t,isl)
                = Smax[ (resC,riskC) $ (ord(resC)=1)
                     , RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ];

        Endif;

        If Sum[ resC $ (ord(resC) = 2), reserveShareEnabled(t,resC)] then

            o_SirSent_TP(t,isl)
                = Sum[ (rd,resC) $ (ord(resC) = 2),
                       RESERVESHARESENT.l(t,isl,resC,rd) ];

            o_SirReceived_TP(t,isl)
                = Sum[ (fd,resC) $ (ord(resC) = 2),
                       RESERVESHARERECEIVED.l(t,isl,resC,fd) ];

            o_SirEffectiveCE_TP(t,isl)
                = Smax[ (resC,riskC)
                      $ { (ord(resC) = 2) and ContingentEvents(riskC) }
                      , RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ];

            o_SirEffectiveECE_TP(t,isl)
                = Smax[ (resC,riskC)
                      $ { (ord(resC) = 2) and ExtendedContingentEvent(riskC) }
                      , RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ];

            o_SirEffReport_TP(t,isl)
                = Smax[ (resC,riskC) $ (ord(resC)=2)
                     , RESERVESHAREEFFECTIVE.l(t,isl,resC,riskC) ];
        Endif;

        o_TotalIslandReserve(t,isl,resC,riskC)
            = o_ResCleared_TP(t,isl,resC) + o_EffectiveRes_TP(t,isl,resC,riskC);


* TN - The code for NMIR project end ===========================================

*       Additional output for audit reporting
        o_ACbusAngle(t,b) = ACNODEANGLE.l(t,b) ;

*       Check if there are non-physical losses on AC branches
        ManualBranchSegmentMWFlow(LossBranch(ACbranch(t,br)),los,fd)
                $ { ( ord(los) <= branchLossBlocks(ACbranch) )
                and validLossSegment(ACbranch,los,fd)
                and ( ACBRANCHFLOWDIRECTED.l(ACbranch,fd) > 0 )
                  }
                = Min[ Max( 0,
                            [ abs(o_branchFlow_TP(t,br))
                            - [LossSegmentMW(ACbranch,los-1,fd) $ (ord(los) > 1)]
                            ]
                          ),
                       ( LossSegmentMW(ACbranch,los,fd)
                       - [LossSegmentMW(ACbranch,los-1,fd) $ (ord(los) > 1)]
                       )
                     ] ;

        ManualBranchSegmentMWFlow(LossBranch(HVDClink(t,br)),los,fd)
                $ { ( ord(los) <= branchLossBlocks(HVDClink) )
                and validLossSegment(HVDClink,los,fd) and ( ord(fd) = 1 )
                  }
                = Min[ Max( 0,
                            [ abs(o_branchFlow_TP(t,br))
                            - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                            ]
                          ),
                       ( LossSegmentMW(HVDClink,los,fd)
                       - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                       )
                     ] ;

        ManualLossCalculation(LossBranch(branch(t,br)))
            = sum[ (los,fd), LossSegmentFactor(branch,los,fd)
                           * ManualBranchSegmentMWFlow(branch,los,fd) ] ;

        o_nonPhysicalLoss(t,br) = o_branchDynamicLoss_TP(t,br)
                                 - ManualLossCalculation(t,br) ;

        o_lossSegmentBreakPoint(t,br,los)
            = sum [ fd $ { validLossSegment(t,br,los,fd)
                       and (ord(fd) = 1)
                         }, LossSegmentMW(t,br,los,fd) ] $ { o_branchFlow_TP(t,br) >= 0 }
            + sum [ fd $ { validLossSegment(t,br,los,fd)
                       and (ord(fd) = 2)
                         }, LossSegmentMW(t,br,los,fd) ] $ { o_branchFlow_TP(t,br) < 0 }
        ;

        o_lossSegmentFactor(t,br,los)
            = sum [ fd $ { validLossSegment(t,br,los,fd)
                       and (ord(fd) = 1)
                         }, LossSegmentFactor(t,br,los,fd) ] $ { o_branchFlow_TP(t,br) >= 0 }
            + sum [ fd $ { validLossSegment(t,br,los,fd)
                       and (ord(fd) = 2)
                         }, LossSegmentFactor(t,br,los,fd) ] $ { o_branchFlow_TP(t,br) < 0 }
        ;

        o_PLRO_FIR_TP(t,o) $ offer(t,o)
            = sum[(resC,PLRO) $ (ord(resC)=1)
                 , RESERVE.l(t,o,resC,PLRO) ] ;

        o_PLRO_SIR_TP(t,o) $ offer(t,o)
            = sum[(resC,PLRO) $ (ord(resC)=2)
                 , RESERVE.l(t,o,resC,PLRO)] ;

        o_TWRO_FIR_TP(t,o) $ offer(t,o)
            = sum[(resC,TWRO) $ (ord(resC)=1)
                 , RESERVE.l(t,o,resC,TWRO)] ;

        o_TWRO_SIR_TP(t,o) $ offer(t,o)
            = sum[(resC,TWRO) $ (ord(resC)=2)
                 , RESERVE.l(t,o,resC,TWRO)] ;

        o_ILRO_FIR_TP(t,o) $ offer(t,o)
            = sum[ (resC,ILRO) $ (ord(resC)=1)
                 , RESERVE.l(t,o,resC,ILRO)] ;

        o_ILRO_SIR_TP(t,o) $ offer(t,o)
            = sum[ (resC,ILRO) $ (ord(resC)=2)
                 , RESERVE.l(t,o,resC,ILRO)] ;

        o_ILbus_FIR_TP(t,b) = sum[ (o,n) $ { NodeBus(t,n,b) and
                                              offerNode(t,o,n)
                                            }, o_ILRO_FIR_TP(t,o) ] ;

        o_ILbus_SIR_TP(t,b) = sum[ (o,n) $ { NodeBus(t,n,b) and
                                              offerNode(t,o,n)
                                            }, o_ILRO_SIR_TP(t,o) ] ;

        o_generationRiskLevel(t,isl,o,resC,GenRisk)
            = GENISLANDRISK.l(t,isl,o,resC,GenRisk)
            + RESERVESHAREEFFECTIVE.l(t,isl,resC,GenRisk)
            ;

        o_HVDCriskLevel(t,isl,resC,HVDCrisk)
            = ISLANDRISK.l(t,isl,resC,HVDCrisk) ;

        o_manuRiskLevel(t,isl,resC,ManualRisk)
            = ISLANDRISK.l(t,isl,resC,ManualRisk)
            + RESERVESHAREEFFECTIVE.l(t,isl,resC,ManualRisk)
            ;

        o_genHVDCriskLevel(t,isl,o,resC,HVDCsecRisk)
            = HVDCGENISLANDRISK.l(t,isl,o,resC,HVDCsecRisk) ;

        o_manuHVDCriskLevel(t,isl,resC,HVDCsecRisk)
            = HVDCMANISLANDRISK.l(t,isl,resC,HVDCsecRisk);

        o_generationRiskGroupLevel(t,isl,rg,resC,GenRisk)
            $ islandRiskGroup(t,isl,rg,GenRisk)
            = GENISLANDRISKGROUP.l(t,isl,rg,resC,GenRisk)
            + RESERVESHAREEFFECTIVE.l(t,isl,resC,GenRisk)
            ;

*       FIR and SIR required based on calculations of the island risk to
*       overcome reporting issues of the risk setter under degenerate
*       conditions when reserve price = 0 - See below

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
        o_solveOK_TP(t) = ModelSolved ;

        o_systemCost_TP(t) = SYSTEMCOST.l(t) ;

        o_systemBenefit_TP(t) = SYSTEMBENEFIT.l(t) ;

        o_penaltyCost_TP(t) = SYSTEMPENALTYCOST.l(t) ;

        o_ofv_TP(t) = o_systemBenefit_TP(t)
                     - o_systemCost_TP(t)
                     - o_penaltyCost_TP(t);


*       Separete violation reporting at trade period level
        o_defGenViolation_TP(t) = sum[ b, o_busDeficit_TP(t,b) ] ;

        o_surpGenViolation_TP(t) = sum[ b, o_busSurplus_TP(t,b) ] ;

        o_surpBranchFlow_TP(t)
            = sum[ br$branch(t,br), SURPLUSBRANCHFLOW.l(t,br) ] ;

        o_defRampRate_TP(t)
            = sum[ o $ offer(t,o), DEFICITRAMPRATE.l(t,o) ] ;

        o_surpRampRate_TP(t)
            = sum[ o $ offer(t,o), SURPLUSRAMPRATE.l(t,o) ] ;

        o_surpBranchGroupConst_TP(t)
            = sum[ brCstr $ branchConstraint(t,brCstr)
                 , SURPLUSBRANCHSECURITYCONSTRAINT.l(t,brCstr) ] ;

        o_defBranchGroupConst_TP(t)
            = sum[ brCstr $ branchConstraint(t,brCstr)
                 , DEFICITBRANCHSECURITYCONSTRAINT.l(t,brCstr) ] ;

        o_defMnodeConst_TP(t)
            = sum[ MnodeCstr $ MnodeConstraint(t,MnodeCstr)
                 , DEFICITMnodeCONSTRAINT.l(t,MnodeCstr) ] ;

        o_surpMnodeConst_TP(t)
            = sum[ MnodeCstr $ MnodeConstraint(t,MnodeCstr)
                 , SURPLUSMnodeCONSTRAINT.l(t,MnodeCstr) ] ;

        o_defResv_TP(t)
            = sum[ (isl,resC) , o_ResViolation_TP(t,isl,resC) ] ;

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


*   Offer level - This does not include revenue from wind generators for
*   final pricing because the wind generation is netted off against load
*   at the particular bus for the final pricing solves

$endif.SummaryReport


* 8b. Calculating price-relating outputs --------------------------------------

$iftheni.PriceRelatedOutputs %opMode%=='DWH'
$elseifi.PriceRelatedOutputs %opMode%=='FTR' $include "FTRental\vSPDSolveFTR_3a.gms"
$else.PriceRelatedOutputs
loop (dt,

*   branch output update
    o_branchFromBusPrice_TP(dt,br) $ branch(dt,br)
        = sum[ b $ branchFrBus(dt,br,b), o_busPrice_TP(dt,b) ] ;

    o_branchToBusPrice_TP(dt,br) $ branch(dt,br)
        = sum[ b $ branchToBus(dt,br,b), o_busPrice_TP(dt,b) ] ;

    o_branchTotalRentals_TP(dt,br)
        $ { branch(dt,br) and (o_branchFlow_TP(dt,br) >= 0) }
        = (intervalDuration/60)
        * [ o_branchToBusPrice_TP(dt,br)   * o_branchFlow_TP(dt,br)
          - o_branchToBusPrice_TP(dt,br)   * o_branchTotalLoss_TP(dt,br)
          - o_branchFromBusPrice_TP(dt,br) * o_branchFlow_TP(dt,br)
          ] ;

    o_branchTotalRentals_TP(dt,br)
        $ { branch(dt,br) and (o_branchFlow_TP(dt,br) < 0) }
        = (intervalDuration/60)
        * [ o_branchToBusPrice_TP(dt,br)   * o_branchFlow_TP(dt,br)
          - o_branchFromBusPrice_TP(dt,br) * o_branchFlow_TP(dt,br)
          - o_branchFromBusPrice_TP(dt,br) * o_branchTotalLoss_TP(dt,br)
          ] ;

*   Island output
    o_islandRefPrice_TP(dt,isl)
        = sum[ n $ { refNode(dt,n)
                 and nodeIsland(dt,n,isl) } , o_nodePrice_TP(dt,n) ] ;
) ;

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
