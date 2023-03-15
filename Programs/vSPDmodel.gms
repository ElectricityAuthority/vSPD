*=====================================================================================
* Name:                 vSPDmodel.gms
* Function:             Mathematical formulation - based on the SPD formulation v9.0
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: http://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Modified on:          1 Oct 2019
*                       New feature added: New wind offer arrangements
* Modified on:          11 Dec 2020
*                       Branch Reverse Rating (this feature is suspended until further notice)
* Modified on:          24 Feb 2021
*                       Correcting the excess reserve sharing penalty
*                       by adding RESERVESHAREEFFECTIVE_CE and ECE variables
* Last modified on:     18 March 2022
*                       Rename/remove primary sets to tidy up the code and
*                       Assign value for constant sets such as ils, blk,resC, etc...
*
*=====================================================================================

$ontext
Directory of code sections in vSPDmodel.gms:
  1. Declare sets and parameters for all symbols to be loaded from daily GDX files
  2. Declare additional sets and parameters used throughout the model
  3. Declare model variables and constraints, and initialise constraints

Aliases to be aware of:
  dt = dt1                                  tp = tp1,tp2
  isl = isl1, isl2                          b = b1, frB, toB
  n = n1, n2                                o = o1, o2
  bd = bd1, bd2
  br = br1
$offtext

* Allow empty data set declaration
$onempty

*===================================================================================
* 1. Declare sets and parameters for all symbols to be loaded from daily GDX files
*===================================================================================
* Hard-coded sets.
Sets
  isl(*)              'Islands'                                                 / NI, SI /
  blk(*)              'Trade block definitions used for the offer and bids'     / t1*t20 /
  los(*)              'Loss segments available for loss modelling'              / ls1*ls13 /
  fd(*)               'Directional flow definition used in the SPD formulation' / forward, backward /
  resC(*)             'Definition of fast and sustained instantaneous reserve'  / FIR, SIR /
  riskC(*)            'Different risks that could set the reserve requirements' / genRisk, DCCE, DCECE, manual, genRiskECE, manualECE, HVDCsecRisk, HVDCsecRiskECE /
  resT(*)             'Definition of reserve types (PLSR, TWDR, ILR)'           / PLRO, TWRO, ILRO /

  bidofrCmpnt(*)      'Components of the bid and offer'                 / limitMW, price, plsrPct /
  offerPar(*)         'The various parameters required for each offer'  / initialMW, rampUpRate, rampDnRate, resrvGenMax, isIG, FKbandMW, isPriceResponse, potentialMW  /
  riskPar(*)          'Different risk parameters'                       / freeReserve, adjustFactor, HVDCRampUp /
  brPar(*)            'Branch parameter specified'                      / resistance, susceptance, fixedLosses, numLossTranches /
  CstrRHS(*)          'Constraint RHS definition'                       / cnstrSense, cnstrLimit /

  z(*)                'Defined reverse reserve sharing zone for HVDC sent flow: RP -> round power zone, NR -> no reverse zone, RZ -> reverse zone' /RP, NR, RZ/
  ;

* Dynamic sets that are defined by /loaded from gdx inputs
Sets
  caseName(*)         'Final pricing case name used to create the GDX file'
  dt(*)               'Date and time for the trade periods'
  tp(*)               'Trade periods for which input data is defined'
  b(*)                'Bus definitions for all trading periods'
  n(*)                'Node definitions for all trading periods'
  o(*)                'Offers for all trading periods'
  bd(*)               'Bids for all trading periods'
  trdr(*)             'Traders defined for all trading periods'
  br(*)               'Branch definition for all trading periods'
  brCstr(*)           'Branch constraint definitions for all trading periods'
  MnodeCstr(*)        'Market node constraint definitions for all trading periods'
  rg(*)               'Set representing a collection of generation and reserve offers treated as a group risk'
  rundt(*)            'Run datetime of the case for reporting'
  ;

* Aliases
Alias (dt,dt1,dt2),       (tp,tp1,tp2),     (isl,isl1,isl2),  (b,b1,frB,toB)
      (n,n1,n2),          (o,o1,o2),        (bd,bd2,bd1),     (br,br1)
      (fd,fd1,rd,rd1),    (z,z1,rrz,rrz1),  (rg,rg1),         (blk,blk1,blk2)
      (los,los1,bp,bp1,rsbp,rsbp1)
  ;

Sets
* 16 multi-dimensional sets, subsets, and mapping sets - membership is populated via loading from GDX file in vSPDsolve.gms
  dt2tp(dt,tp)                        'Mapping of dateTime set to the tradePeriod set'
  node(dt,n)                          'Node definition for the different trading periods'
  bus(dt,b)                           'Bus definition for the different trading periods'
  node2node(dt,n,n1)                  'Node to node mapping used for price and energy shortfall transfer'
  offerNode(dt,o,n)                   'Offers and the corresponding offer node for the different trading periods'
  offerTrader(dt,o,trdr)              'Offers and the corresponding trader for the different trading periods'
  bidNode(dt,bd,n)                    'Bids and the corresponding node for the different trading periods'
  bidTrader(dt,bd,trdr)               'Bids and the corresponding trader for the different trading periods'
  busIsland(dt,b,isl)                 'Bus island mapping for the different trade periods'
  nodeBus(dt,n,b)                     'Node bus mapping for the different trading periods'
  branchDefn(dt,br,frB,toB)           'Branch definition for the different trading periods'
  riskGenerator(dt,o)                 'Set of generators (offers) that can set the risk in the different trading periods'
  primarySecondaryOffer(dt,o,o1)      'Primary-secondary offer mapping for the different trading periods - in use from 01 May 2012'
  dispatchableBid(dt,bd)              'Set of dispatchable bids - effective date 20 May 2014'
  discreteModeBid(dt,bd)              'Set of dispatchable discrete bids - Start From RTP phase 4 to support Dispatch Lite'
  differenceBid(dt,bd)                'Set of difference bids - applied to PRSS mostly'
  dispatchableEnrgOffer(dt,o)         'Set of dispatchable energy offer - Start From RTP phase 4 to support Dispatch Lite'
  nodeoutagebranch(dt,n,br)           'Mappinging of branch and node where branch outage may affect the capacity to supply to the node'
  ;


Parameters
* 6 scalars - values are loaded from GDX file in vSPDsolve.gms
  gdxDate(*)                                            'day, month, year of trade date'
  intervalDuration                                      'Length of the trading period in minutes (e.g. 30)'

* 49 parameters - values are loaded from GDX file in vSPDsolve.gms
* Offer data
  offerParameter(dt,o,offerPar)                     'Initial MW for each offer for the different trading periods'
  energyOffer(dt,o,blk,bidofrCmpnt)                 'Energy offers for the different trading periods'
  fastPLSRoffer(dt,o,blk,bidofrCmpnt)               'Fast (6s) PLSR offers for the different trading periods'
  sustainedPLSRoffer(dt,o,blk,bidofrCmpnt)          'Sustained (60s) PLSR offers for the different trading periods'
  fastTWDRoffer(dt,o,blk,bidofrCmpnt)               'Fast (6s) TWDR offers for the different trading periods'
  sustainedTWDRoffer(dt,o,blk,bidofrCmpnt)          'Sustained (60s) TWDR offers for the different trading periods'
  fastILRoffer(dt,o,blk,bidofrCmpnt)                'Fast (6s) ILR offers for the different trading periods'
  sustainedILRoffer(dt,o,blk,bidofrCmpnt)           'Sustained (60s) ILR offers for the different trading periods'

* Bid data
  energyBid(dt,bd,blk,bidofrCmpnt)                  'Energy bids for the different trading periods'
* Demand data
  nodeDemand(dt,n)                                  'MW demand at each node for all trading periods'

* Network data
  refNode(dt,n)                                     'Reference nodes for the different trading periods'
  HVDCBranch(dt,br)                                 'HVDC branch indicator for the different trading periods'
  branchParameter(dt,br,brPar)                      'Branch resistance, reactance, fixed losses and number of loss tranches for the different time periods'
  branchCapacity(dt,br,fd)                          'Branch directed capacity for the different trading periods in MW (Branch Reverse Ratings)'
  branchOpenStatus(dt,br)                           'Branch open status for the different trading periods, 1 = Open'
  nodeBusAllocationFactor(dt,n,b)                   'Allocation factor of market node quantities to bus for the different trading periods'
  busElectricalIsland(dt,b)                         'Electrical island status of each bus for the different trading periods (0 = Dead)'

* Risk/Reserve data
  riskParameter(dt,isl,resC,riskC,riskPar)          'Risk parameters for the different trading periods (From RMT)'
  islandMinimumRisk(dt,isl,resC,riskC)              'Minimum MW risk level for each island for each reserve class applied to risk classes: manual, manualECE, HVDCsecRisk and HVDCsecRiskECE'
  HVDCSecRiskEnabled(dt,isl,riskC)                  'Flag indicating if the HVDC secondary risk is enabled (1 = Yes)'
  HVDCSecRiskSubtractor(dt,isl)                     'Ramp up capability on the HVDC pole that is not the secondary risk'
  reserveMaximumFactor(dt,o,resC)                   'Factor to adjust the maximum reserve of the different classes for the different offers'

* Branch constraint data
  branchCstrFactors(dt,brCstr,br)                   'Branch security constraint factors (sensitivities) for the current trading period'
  branchCstrRHS(dt,brCstr,CstrRHS)                  'Branch constraint sense and limit for the different trading periods'

* Market node constraint data
  mnCstrEnrgFactors(dt,MnodeCstr,o)                 'Market node energy offer constraint factors for the current trading period'
  mnCnstrResrvFactors(dt,MnodeCstr,o,resC,resT)     'Market node reserve offer constraint factors for the current trading period'
  mnCnstrEnrgBidFactors(dt,MnodeCstr,bd)            'Market node energy bid constraint factors for the different trading periods'
  mnCnstrResrvBidFactors(dt,MnodeCstr,bd,resC)      'Market node IL reserve bid constraint factors for the different trading periods - currently not used'
  mnCnstrRHS(dt,MnodeCstr,CstrRHS)                  'Market node constraint sense and limit for the different trading periods'


* Real Time Pricing - Inputs
  studyMode                                                         'RTD~101, RTDP~201, PRSS~130, NRSS~132, PRSL~131, NRSL~133, WDS~120' /101/
  useGenInitialMW(dt)                                               'Flag that if set to 1 indicates that for a schedule that is solving multiple intervals in sequential mode'
  runEnrgShortfallTransfer(dt)                                      'Flag that if set to 1 will enable shortfall transfer- post processing'
  runPriceTransfer(dt)                                              'Flag that if set to 1 will enable price transfer - post processing.'
  replaceSurplusPrice(dt)                                           'Flag that if set to 1 will enable sutplus price replacement - post processing'
  rtdIgIncreaseLimit(dt)                                            'For price responsive Intermittent Generation (IG) the 5-minute ramp-up is capped using this parameter'
  useActualLoad(dt)                                                 'Flag that if set to 0, initial estimated load [conformingfactor/noncomformingload] is used as initial load '
  dontScaleNegativeLoad(dt)                                         'Flag that if set to 1 --> negative load will be fixed in RTD load calculation'
  inputInitialLoad(dt,n)                                            'This value represents actual load MW for RTD schedule input'
  conformingFactor(dt,n)                                            'Initial estimated load for conforming load'
  nonConformingLoad(dt,n)                                           'Initial estimated load for non-conforming load'
  loadIsOverride(dt,n)                                              'Flag if set to 1 --> InputInitialLoad will be fixed as node demand'
  loadIsBad(dt,n)                                                   'Flag if set to 1 --> InitialLoad will be replaced by Estimated Initial Load'
  loadIsNCL(dt,n)                                                   'Flag if set to 1 --> non-conforming load --> will be fixed in RTD load calculation'
  maxLoad(dt,n)                                                     'Pnode maximum load'
  instructedLoadShed(dt,n)                                          'Instructed load shedding applied to RTDP and should be ignore by all other schedules'
  instructedShedActive(dt,n)                                        'Flag if Instructed load shedding is active; applied to RTDP and should be ignore by all other schedules'
  islandMWIPS(dt,isl)                                               'Island total generation at the start of RTD run'
  islandPDS(dt,isl)                                                 'Island pre-solve deviation - used to adjust RTD node demand'
  islandLosses(dt,isl)                                              'Island estimated losss - used to adjust RTD mode demand'
  enrgShortfallRemovalMargin(dt)                                    'This small margin is added to the shortfall removed amount in order to prevent any associated binding ACLine constraint'
  maxSolveLoops(dt)                                                 'The maximum number of times that the Energy Shortfall Check will re-solve the model'


  energyScarcityEnabled(dt)                                         'Flag to apply energy scarcity (this is different from FP scarcity situation)'
  reserveScarcityEnabled(dt)                                        'Flag to apply reserve scarcity (this is different from FP scarcity situation)'
  scarcityEnrgNationalFactor(dt,blk)                                'National energy scarcity factors'
  scarcityEnrgNationalPrice(dt,blk)                                 'National energy scarcity prices'
  scarcityEnrgNodeFactor(dt,n,blk)                                  'Nodal energy scarcity factors'
  scarcityEnrgNodeFactorPrice(dt,n,blk)                             'Nodal energy scarcity prices vs factors'
  scarcityEnrgNodeLimit(dt,n,blk)                                   'Nodal energy scarcity limits'
  scarcityEnrgNodeLimitPrice(dt,n,blk)                              'Nodal energy scarcity prices vs limits'
  scarcityResrvIslandLimit(dt,isl,resC,blk)                         'Reserve scarcity limits'
  scarcityResrvIslandPrice(dt,isl,resC,blk)                         'Reserve scarcity prices'

 ;

* End of GDX declarations



*===================================================================================
* 2. Declare additional sets and parameters used throughout the model
*===================================================================================

Scalars
  useAClossModel
  useHVDClossModel
  useACbranchLimits                        'Use the AC branch limits (1 = Yes)'
  useHVDCbranchLimits                      'Use the HVDC branch limits (1 = Yes)'
  resolveCircularBranchFlows               'Resolve circular branch flows (1 = Yes)'
  resolveHVDCnonPhysicalLosses             'Resolve nonphysical losses on HVDC branches (1 = Yes)'
  resolveACnonPhysicalLosses               'Resolve nonphysical losses on AC branches (1 = Yes)'
  circularBranchFlowTolerance
  nonPhysicalLossTolerance
  useBranchFlowMIPtolerance
  useReserveModel                          'Use the reserve model (1 = Yes)'
  mixedMIPtolerance
  LPtimeLimit                              'CPU seconds allowed for LP solves'
  LPiterationLimit                         'Iteration limit allowed for LP solves'
  MIPtimeLimit                             'CPU seconds allowed for MIP solves'
  MIPiterationLimit                        'Iteration limit allowed for MIP solves'
  MIPoptimality
  disconnectedNodePriceCorrection          'Flag to apply price correction methods to disconnected node'

  intervalDuration                         'Length of the interval in minutes (e.g. 30)'
  branchReceivingEndLossProportion         'Proportion of losses to be allocated to the receiving end of a branch' /1/

* External loss model from Transpower
  lossCoeff_A                       / 0.3101 /
  lossCoeff_C                       / 0.14495 /
  lossCoeff_D                       / 0.32247 /
  lossCoeff_E                       / 0.46742 /
  lossCoeff_F                       / 0.82247 /
  maxFlowSegment                    / 10000 /
  ;

Sets
* Global
  pole                                                   'HVDC poles' / pole1, pole2 /
  t(dt)                                                  'Current trading interval to solve'

* Offer
  offer(dt,o)                                            'Offers defined for the current trading period'
  genOfrBlk(dt,o,blk)                                    'Valid trade blocks for the respective generation offers'
  resOfrBlk(dt,o,blk,resC,resT)                          'Valid trade blocks for the respective reserve offers by class and type'
  posEnrgOfr(dt,o)                                       'Postive energy offers defined for the current trading period'

* Bid
  Bid(dt,bd)                                             'Bids defined for the current trading period'
  DemBidBlk(dt,bd,blk)                                   'Valid trade blocks for the respective purchase bids'

* Network
  branch(dt,br)                                                     'Branches defined for the current trading period'
  branchBusDefn(dt,br,frB,toB)                                      'Branch bus connectivity for the current trading period'
  branchFrBus(dt,br,frB)                                            'Define branch from bus connectivity for the current trading period'
  branchToBus(dt,br,frB)                                            'Define branch to bus connectivity for the current trading period'
  branchBusConnect(dt,br,b)                                         'Indication if a branch is connected to a bus for the current trading period'
  ACBranchSendingBus(dt,br,b,fd)                                    'Sending (From) bus of AC branch in forward and backward direction'
  ACBranchReceivingBus(dt,br,b,fd)                                  'Receiving (To) bus of AC branch in forward and backward direction'
  HVDClinkSendingBus(dt,br,b)                                       'Sending (From) bus of HVDC link'
  HVDClinkReceivingBus(dt,br,toB)                                   'Receiving (To) bus of HVDC link'
  HVDClinkBus(dt,br,b)                                              'Sending or Receiving bus of HVDC link'
  HVDClink(dt,br)                                                   'HVDC links (branches) defined for the current trading period'
*  HVDCpoles(dt,br)                                                  'DC transmission between Benmore and Hayward'

  HVDCpoleDirection(dt,br,fd)                                       'Direction defintion for HVDC poles S->N : forward and N->S : backward'
  ACBranch(dt,br)                                                   'AC branches defined for the current trading period'
  validLossSegment(dt,br,los,fd)                                    'Valid loss segments for a branch'
  lossBranch(dt,br)                                                 'Subset of branches that have non-zero loss factors'
* Mapping set of branches to HVDC pole
  HVDCpoleBranchMap(pole,br)                                        'Mapping of HVDC  branch to pole number'
* Risk/Reserve
  islandRiskGenerator(dt,isl,o)                          'Mapping of risk generator to island in the current trading period'

  GenRisk(riskC)                                                    'Subset containing generator risks'
  ManualRisk(riskC)                                                 'Subset containting manual risks'
  HVDCrisk(riskC)                                                   'Subset containing DCCE and DCECE risks'
  HVDCSecRisk(riskC)                                                'Subset containing secondary risk of the DCCE and DCECE events'

  PLRO(resT)                                             'PLSR reserve type'
  TWRO(resT)                                             'TWDR reserve type'
  ILRO(resT)                                             'ILR reserve type'

  nodeIsland(dt,n,isl)                                   'Mapping node to island'
  offerIsland(dt,o,isl)                                  'Mapping of reserve offer to island for the current trading period'
  bidIsland(dt,bd,isl)                                   'Mapping of purchase bid ILR to island for the current trading period'

* Definition of CE and ECE events to support different CE and ECE CVPs
  ContingentEvents(riskC)                                           'Subset of Risk Classes containing contigent event risks'
  ExtendedContingentEvent(riskC)                                    'Subset of Risk Classes containing extended contigent event risk'
* Branch constraint
  BranchConstraint(dt,brCstr)                                       'Set of valid branch constraints defined for the current trading period'
* Market node constraint
  MNodeConstraint(dt,MnodeCstr)                                     'Set of market node constraints defined for the current trading period'
* NMIR update
  rampingConstraint(dt,brCstr)                                      'Subset of branch constraints that limit total HVDC sent from an island due to ramping (5min schedule only)'
  bipoleConstraint(dt,isl,brCstr)                                   'Subset of branch constraints that limit total HVDC sent from an island'
  monopoleConstraint(dt,isl,brCstr,br)                              'Subset of branch constraints that limit the flow on HVDC pole sent from an island'

  riskGroupOffer(dt,rg,o,riskC)                                     'Mappimg of risk group to offers in current trading period for each risk class - SPD version 11.0 update'
  islandRiskGroup(dt,isl,rg,riskC)                                  'Mappimg of risk group to island in current trading period for each risk class - SPD version 11.0 update'
  ;

Parameters
* Offers
  GenerationStart(dt,o)                                  'The MW generation level associated with the offer at the start of a trading period'
  RampRateUp(dt,o)                                       'The ramping up rate in MW per minute associated with the generation offer (MW/min)'
  RampRateDn(dt,o)                                       'The ramping down rate in MW per minute associated with the generation offer (MW/min)'
  ReserveGenerationMaximum(dt,o)                         'Maximum generation and reserve capability for the current trading period (MW)'
  WindOffer(dt,o)                                        'Flag to indicate if offer is from wind generator (1 = Yes)'
  FKBand(dt,o)                                           'Frequency keeper band MW which is set when the risk setter is selected as the frequency keeper'
  PriceResponsive(dt,o)                                  'Flag to indicate if wind offer is price responsive (1 = Yes)'
  PotentialMW(dt,o)                                      'Potential max output of Wind offer'

* Energy offer
  EnrgOfrMW(dt,o,blk)                                    'Generation offer block (MW)'
  EnrgOfrPrice(dt,o,blk)                                 'Generation offer price ($/MW)'

* Primary-secondary offer parameters
  PrimaryOffer(dt,o)                                     'Flag to indicate if offer is a primary offer (1 = Yes)'
  SecondaryOffer(dt,o)                                   'Flag to indicate if offer is a secondary offer (1 = Yes)'


  GenerationMaximum(dt,o)                                           'Maximum generation level associated with the generation offer (MW)'
  GenerationMinimum(dt,o)                                           'Minimum generation level associated with the generation offer (MW)'
  GenerationEndUp(dt,o)                                             'MW generation level associated with the offer at the end of the trading period assuming ramp rate up'
  GenerationEndDown(dt,o)                                           'MW generation level associated with the offer at the end of the trading period assuming ramp rate down'
  RampTimeUp(dt,o)                                                  'Minimum of the trading period length and time to ramp up to maximum (Minutes)'
  RampTimeDown(dt,o)                                                'Minimum of the trading period length and time to ramp down to minimum (Minutes)'

* Reserve offer
  ResOfrPct(dt,o,blk,resC)                          'The percentage of the MW block available for PLSR of class FIR or SIR'
  ResOfrPrice(dt,o,blk,resC,resT)                   'The price of the reserve of the different reserve classes and types ($/MW)'
  ResOfrMW(dt,o,blk,resC,resT)                      'The maximum MW offered reserve for the different reserve classes and types (MW)'
* Demand
  RequiredLoad(dt,n)                                             'Nodal demand for the current trading period in MW'
* Bid
  DemBidMW(dt,bd,blk)                               'Demand bid block in MW'
  DemBidPrice(dt,bd,blk)                            'Purchase bid price in $/MW'
  DemBidILRMW(dt,bd,blk,resC)                               'Purchase bid ILR block in MW for the different reserve classes'
  DemBidILRPrice(dt,bd,blk,resC)                            'Purchase bid ILR price in $/MW for the different reserve classes'
* Network
  branchResistance(dt,br)                                           'Resistance of the a branch for the current trading period in per unit'
  branchSusceptance(dt,br)                                          'Susceptance (inverse of reactance) of a branch for the current trading period in per unit'
  branchFixedLoss(dt,br)                                            'Fixed loss of the a branch for the current trading period in MW'
  branchLossBlocks(dt,br)                                           'Number of blocks in the loss curve for the a branch in the current trading period'
  lossSegmentMW(dt,br,los,fd)                                       'MW capacity of each loss segment'
  lossSegmentFactor(dt,br,los,fd)                                   'Loss factor of each loss segment'
  ACBranchLossMW(dt,br,los,fd)                                      'MW element of the loss segment curve in MW'
  ACBranchLossFactor(dt,br,los,fd)                                  'Loss factor element of the loss segment curve'
  HVDCBreakPointMWFlow(dt,br,bp,fd)                                 'Value of power flow on the HVDC at the break point'
  HVDCBreakPointMWLoss(dt,br,bp,fd)                                 'Value of variable losses on the HVDC at the break point'

* Risk/Reserve
  IslandRiskAdjustmentFactor(dt,isl,resC,riskC)                     'Risk adjustment factor for each island, reserve class and risk class'
  FreeReserve(dt,isl,resC,riskC)                                    'MW free reserve for each island, reserve class and risk class'
  HVDCpoleRampUp(dt,isl,resC,riskC)                                 'HVDC pole MW ramp up capability for each island, reserve class and risk class'

* NMIR parameters
* The follwing are new input for NMIR
  reserveRoundPower(dt,resC)                                        'Database flag that disables round power under certain circumstances'
  reserveShareEnabled(dt,resC)                                      'Database flag if reserve class resC is sharable'
  modulationRiskClass(dt,riskC)                                     'HVDC energy modulation due to frequency keeping action'
  roundPower2MonoLevel(dt)                                          'HVDC sent value above which one pole is stopped and therefore FIR cannot use round power'
  bipole2MonoLevel(dt)                                              'HVDC sent value below which one pole is available to start in the opposite direction and therefore SIR can use round power'
  MonopoleMinimum(dt)                                               'The lowest level that the sent HVDC sent can ramp down to when round power is not available.'
  HVDCControlBand(dt,rd)                                            'Modulation limit of the HVDC control system apply to each HVDC direction'
  HVDClossScalingFactor(dt)                                         'Losses used for full voltage mode are adjusted by a factor of (700/500)^2 for reduced voltage operation'
  sharedNFRFactor(dt)                                               'Factor that is applied to [sharedNFRLoad - sharedNFRLoadOffset] as part of the calculation of sharedNFRMax'
  sharedNFRLoadOffset(dt,isl)                                       'Island load that does not provide load damping, e.g., Tiwai smelter load in the South Island. Subtracted from the sharedNFRLoad in the calculation of sharedNFRMax.'
  effectiveFactor(dt,isl,resC,riskC)                                'Estimate of the effectiveness of the shared reserve once it has been received in the risk island.'
  RMTReserveLimitTo(dt,isl,resC)                                    'The shared reserve limit used by RMT when it calculated the NFRs. Applied as a cap to the value that is calculated for SharedNFRMax.'
* The follwing are calculated parameters for NMIR
  reserveShareEnabledOverall(dt)                                    'An internal parameter based on the FIR and SIR enabled, and used as a switch in various places'
  modulationRisk(dt)                                                'Max of HVDC energy modulation due to frequency keeping action'
  roPwrZoneExit(dt,resC)                                            'Above this point there is no guarantee that HVDC sent can be reduced below MonopoleMinimum.'
  sharedNFRLoad(dt,isl)                                             'Island load, calculated in pre-processing from the required load and the bids. Used as an input to the calculation of SharedNFRMax.'
  sharedNFRMax(dt,isl)                                              'Amount of island free reserve that can be shared through HVDC'
  numberOfPoles(dt,isl)                                             'Number of HVDC poles avaialbe to send energy from an island'
  monoPoleCapacity(dt,isl,br)                                       'Maximum capacity of monopole defined by min of branch capacity and monopole constraint RHS'
  biPoleCapacity(dt,isl)                                            'Maximum capacity of bipole defined by bipole constraint RHS'
  HVDCMax(dt,isl)                                                   'Max HVDC flow based on available poles and branch group constraints RHS'
  HVDCCapacity(dt,isl)                                              'Total sent capacity of HVDC based on available poles'
  HVDCResistance(dt,isl)                                            'Estimated resistance of HVDC flow sent from an island'
  HVDClossSegmentMW(dt,isl,los)                                     'MW capacity of each loss segment applied to aggregated HVDC capacity'
  HVDClossSegmentFactor(dt,isl,los)                                 'Loss factor of each loss segment applied to to aggregated HVDC loss'
  HVDCSentBreakPointMWFlow(dt,isl,los)                              'Value of total HVDC sent power flow at the break point               --> lambda segment loss model'
  HVDCSentBreakPointMWLoss(dt,isl,los)                              'Value of ariable losses of the total HVDC sent at the break point    --> lambda segment loss model'
  HVDCReserveBreakPointMWFlow(dt,isl,los)                           'Value of total HVDC sent power flow + reserve at the break point     --> lambda segment loss model'
  HVDCReserveBreakPointMWLoss(dt,isl,los)                           'Value of post-contingent variable HVDC losses at the break point     --> lambda segment loss model'
* The follwing are flag and scalar for testing
  UseShareReserve                                                   'Flag to indicate if the reserve share is applied'
  BigM                                                              'Big M value to be applied for single active segment HVDC loss model' /10000/
* NMIR parameters end

* Branch constraint
  BranchConstraintSense(dt,brCstr)                                  'Branch security constraint sense for the current trading period (-1:<=, 0:= 1:>=)'
  BranchConstraintLimit(dt,brCstr)                                  'Branch security constraint limit for the current trading period'

* Market node constraint
  MNodeConstraintSense(dt,MnodeCstr)                                'Market node constraint sense for the current trading period'
  MNodeConstraintLimit(dt,MnodeCstr)                                'Market node constraint limit for the current trading period'


* Post-processing
  useBranchFlowMIP(dt)                             'Flag to indicate if integer constraints are needed in the branch flow model: 1 = Yes'

* Real Time Pricing
  ScarcityEnrgLimit(dt,n,blk)                                    'Bus energy scarcity limits'
  ScarcityEnrgPrice(dt,n,blk)                                    'Bus energy scarcity prices vs limits'


* Real Time Pricing - Calculated parameters
  InitialLoad(dt,n)                                'Value that represents the Pnode load MW at the start of the solution interval. Depending on the inputs this value will be either actual load, an operator applied override or an estimated initial load'
  LoadIsScalable(dt,n)                             'Binary value. If True then the Pnode InitialLoad will be scaled in order to calculate nodedemand, if False then Pnode InitialLoad will be directly assigned to nodedemand'
  LoadScalingFactor(dt,isl)                        'Island-level scaling factor applied to InitialLoad in order to calculate nodedemand'
  TargetTotalLoad(dt,isl)                          'Island-level MW load forecast'
  LoadCalcLosses(dt,isl)                           'Island-level MW losses used to calculate the Island-level load forecast from the InputIPS and the IslandPSD. 1st loop --> InitialLosses, 2nd solve loop --> SystemLosses as calculated in section 6.3'
  EstimatedInitialLoad(dt,n)                       'Calculated estimate of initial MW load, available to be used as an alternative to InputInitialLoad'
  EstScalingFactor(dt,isl)                         'Scaling applied to ConformingFactor load MW in order to calculate EstimatedInitialLoad'
  EstLoadIsScalable(dt,n)                          'Binary value. If True then ConformingFactor load MW will be scaled in order to calculate EstimatedInitialLoad. If False then EstNonScalableLoad will be assigned directly to EstimatedInitialLoad'
  EstNonScalableLoad(dt,n)                         'For a non-conforming Pnode this will be the NonConformingLoad MW input, for a conforming Pnode this will be the ConformingFactor MW input if that value is negative, otherwise it will be zero'
  EstScalableLoad(dt,n)                            'For a non-conforming Pnode this value will be zero. For a conforming Pnode this value will be the ConformingFactor if it is non-negative, otherwise this value will be zero'


  ;

Scalars
* Violation penalties
* These violation penalties are not specified in the model formulation document (ver.4.3) but are specified in the
* document "Resolving Infeasibilities & High Spring Washer Price situations - an overview" available at www.systemoperator.co.nz/n2766,264.html
  deficitBusGenerationPenalty                      'Bus deficit violation penalty'                      /500000/
  surplusBusGenerationPenalty                      'Bus surplus violation penalty'                      /500000/
  deficitBrCstrPenalty                             'Deficit branch group constraint violation penalty'  /650000/
  surplusBrCstrPenalty                             'Surplus branch group constraint violation penalty'  /650000/
  deficitGnrcCstrPenalty                           'Deficit generic constraint violation penalty'       /710000/
  surplusGnrcCstrPenalty                           'Surplus generic constraint violation penalty'       /710000/
  deficitRampRatePenalty                           'Deficit ramp rate violation penalty'                /850000/
  surplusRampRatePenalty                           'Surplus ramp rate violation penalty'                /850000/
  deficitBranchFlowPenalty                         'Deficit branch flow violation penalty'              /600000/
  surplusBranchFlowPenalty                         'Surplus branch flow violation penalty'              /600000/
  deficitMnodeCstrPenalty                          'Deficit market node constraint violation penalty'   /700000/
  surplusMnodeCstrPenalty                          'Surplus market node constraint violation penalty'   /700000/
  DeficitReservePenalty_CE                         '6s and 60s CE reserve deficit violation penalty'    /100000/
  DeficitReservePenalty_ECE                        '6s and 60s ECE reserve deficit violation penalty'   /800000/
  ;


*===================================================================================
* 3. Declare model variables and constraints, and initialise constraints
*=================================================================== ================

* VARIABLES - UPPER CASE
* Equations, parameters and everything else - lower or mixed case

* Model formulation originally based on the SPD model formulation version 4.3 (15 Feb 2008) and amended as indicated

Variables
  NETBENEFIT                                       'Defined as the difference between the consumer surplus and producer costs adjusted for penalty costs'
* Risk
  ISLANDRISK(dt,isl,resC,riskC)                    'Island MW risk for the different reserve and risk classes'
  GENISLANDRISK(dt,isl,o,resC,riskC)               'Island MW risk for different risk setting generators'
  GENISLANDRISKGROUP(dt,isl,rg,resC,riskC)         'Island MW risk for different risk group - SPD version 11.0'
  HVDCGENISLANDRISK(dt,isl,o,resC,riskC)           'Island MW risk for different risk setting generators + HVDC'
  HVDCMANISLANDRISK(dt,isl,resC,riskC)             'Island MW risk for manual risk + HVDC'
  HVDCREC(dt,isl)                                  'Total net pre-contingent HVDC MW flow received at each island'
  RISKOFFSET(dt,isl,resC,riskC)                    'MW offset applied to the raw risk to account for HVDC pole rampup, AUFLS, free reserve and non-compliant generation'

* NMIR free variables
  HVDCRESERVESENT(dt,isl,resC,rd)                  'Total net post-contingent HVDC MW flow sent from an island applied to each reserve class'
  HVDCRESERVELOSS(dt,isl,resC,rd)                  'Post-contingent HVDC loss of energy + reserve sent from an island applied to each reserve class'
* NMIR free variables end

* Network
  ACNODENETINJECTION(dt,b)                         'MW injection at buses corresponding to AC nodes'
  ACBRANCHFLOW(dt,br)                              'MW flow on undirected AC branch'
  ACNODEANGLE(dt,b)                                'Bus voltage angle'

* Demand bids can be either positive or negative from v6.0 of SPD formulation (with DSBF)
* The lower bound of the free variable is updated in vSPDSolve.gms to allow backward compatibility
* Note the formulation now refers to this as Demand. So Demand (in SPD formulation) = Purchase (in vSPD code)
  PURCHASE(dt,bd)                                  'Total MW purchase scheduled'
  PURCHASEBLOCK(dt,bd,blk)                         'MW purchase scheduled from the individual trade blocks of a bid'

  ;

Positive variables
* system cost and benefit
  SYSTEMBENEFIT(dt)                                'Total purchase bid benefit by period'
  SYSTEMCOST(dt)                                   'Total generation and reserve costs by period'
  SYSTEMPENALTYCOST(dt)                            'Total violation costs by period'
  TOTALPENALTYCOST                                 'Total violation costs'
  SCARCITYCOST(dt)                                 'Total scarcity Cost'
* scarcity variables
  ENERGYSCARCITYBLK(dt,n,blk)                      'Block energy scarcity cleared at bus b'
  ENERGYSCARCITYNODE(dt,n)                         'Energy scarcity cleared at bus b'

  RESERVESHORTFALLBLK(dt,isl,resC,riskC,blk)       'Block reserve shortfall by risk class (excluding genrisk and HVDC secondary risk)'
  RESERVESHORTFALL(dt,isl,resC,riskC)              'Reserve shortfall by risk class (excluding genris kand HVDC secondary risk)'

  RESERVESHORTFALLUNITBLK(dt,isl,o,resC,riskC,blk) 'Block reserve shortfall by risk generation unit (applied to genrisk and HVDC secondary risk)'
  RESERVESHORTFALLUNIT(dt,isl,o,resC,riskC)        'Reserve shortfall by risk generation unit (applied to genrisk and HVDC secondary risk)'

  RESERVESHORTFALLGROUPBLK(dt,isl,rg,resC,riskC,blk) 'Block Reserve shortfall by risk group (applied to genrisk and HVDC secondary risk)'
  RESERVESHORTFALLGROUP(dt,isl,rg,resC,riskC)        'Reserve shortfall by risk risk group (applied to genrisk and HVDC secondary risk)'

* Generation
  GENERATION(dt,o)                                 'Total MW generation scheduled from an offer'
  GENERATIONBLOCK(dt,o,blk)                        'MW generation scheduled from the individual trade blocks of an offer'
  GENERATIONUPDELTA(dt,o)                          'Total increase in MW generation scheduled from an offer'
  GENERATIONDNDELTA(dt,o)                          'Total decrease in MW generation scheduled from an offer'
* Reserve
  RESERVE(dt,o,resC,resT)                          'MW Reserve scheduled from an offer'
  RESERVEBLOCK(dt,o,blk,resC,resT)                 'MW Reserve scheduled from the individual trade blocks of an offer'
  ISLANDRESERVE(dt,isl,resC)                       'Total island cleared reserve'

* NMIR positive variables
  SHAREDNFR(dt,isl)                                'Amount of free load reserve being shared from an island'
  SHAREDRESERVE(dt,isl,resC)                       'Amount of cleared reserve from an island being shared to the other island'
  HVDCSENT(dt,isl)                                 'Directed pre-contingent HVDC MW flow sent from each island'
  HVDCSENTLOSS(dt,isl)                             'Energy loss for  HVDC flow sent from an island'
  RESERVESHAREEFFECTIVE(dt,isl,resC,riskC)         'Effective shared reserve received at island after adjusted for losses and effectiveness factor'
  RESERVESHARERECEIVED(dt,isl,resC,rd)             'Directed shared reserve received at island after adjusted for losses'
  RESERVESHARESENT(dt,isl,resC,rd)                 'Directed shared reserve sent from and island'
  RESERVESHAREPENALTY(dt)                          'Penalty cost for excessive reserve sharing'
* Tuong Nguyen added on 24 Feb 2021 to correct the calculation of RESERVESHAREPENALTY
  RESERVESHAREEFFECTIVE_CE(dt,isl,resC)            'Max effective shared reserve for CE risk received at island after adjusted for losses and effectiveness factor'
  RESERVESHAREEFFECTIVE_ECE(dt,isl,resC)           'Max effective shared reserve for ECE risk received at island after adjusted for losses and effectiveness factor'
* NMIR positive variables end

* Network
  HVDCLINKFLOW(dt,br)                              'MW flow at the sending end scheduled for the HVDC link'
  HVDCLINKLOSSES(dt,br)                            'MW losses on the HVDC link'
  LAMBDA(dt,br,bp)                                 'Non-negative weight applied to the breakpoint of the HVDC link'
  ACBRANCHFLOWDIRECTED(dt,br,fd)                   'MW flow on the directed branch'
  ACBRANCHLOSSESDIRECTED(dt,br,fd)                 'MW losses on the directed branch'
  ACBRANCHFLOWBLOCKDIRECTED(dt,br,los,fd)          'MW flow on the different blocks of the loss curve'
  ACBRANCHLOSSESBLOCKDIRECTED(dt,br,los,fd)        'MW losses on the different blocks of the loss curve'
* Violations
  DEFICITBUSGENERATION(dt,b)                       'Deficit generation at a bus in MW'
  SURPLUSBUSGENERATION(dt,b)                       'Surplus generation at a bus in MW'
  DEFICITBRANCHSECURITYCONSTRAINT(dt,brCstr)       'Deficit branch security constraint in MW'
  SURPLUSBRANCHSECURITYCONSTRAINT(dt,brCstr)       'Surplus branch security constraint in MW'
  DEFICITRAMPRATE(dt,o)                            'Deficit ramp rate in MW'
  SURPLUSRAMPRATE(dt,o)                            'Surplus ramp rate in MW'
  DEFICITBRANCHFLOW(dt,br)                         'Deficit branch flow in MW'
  SURPLUSBRANCHFLOW(dt,br)                         'Surplus branch flow in MW'
  DEFICITMNODECONSTRAINT(dt,MnodeCstr)             'Deficit market node constraint in MW'
  SURPLUSMNODECONSTRAINT(dt,MnodeCstr)             'Surplus market node constraint in MW'
* Seperate CE and ECE violation variables to support different CVPs for CE and ECE
  DEFICITRESERVE_CE(dt,isl,resC)                   'Deficit CE reserve generation in each island for each reserve class in MW'
  DEFICITRESERVE_ECE(dt,isl,resC)                  'Deficit ECE reserve generation in each island for each reserve class in MW'

  ;

Binary variables
* NMIR binary variables
  HVDCSENDING(dt,isl)                              'Binary variable indicating if island isl is the sending end of the HVDC flow. 1 = Yes.'
  INZONE(dt,isl,resC,z)                            'Binary variable (1 = Yes ) indicating if the HVDC flow is in a zone (z) that facilitates the appropriate quantity of shared reserves in the reverse direction to the HVDC sending island isl for reserve class resC.'
  HVDCSENTINSEGMENT(dt,isl,los)                    'Binary variable to decide which loss segment HVDC flow sent from an island falling into --> active segment loss model'
* Discete dispachable demand block binary variables
  PURCHASEBLOCKBINARY(dt,bd,blk)                   'Binary variable to decide if a purchase block is cleared either fully or nothing at all'
* HVDC Secondary risk should not be covered if HVDC sending is zero. The following binary variable is to enforced that (Update from RTP phase 4)
  HVDCSENDZERO(dt,isl)                              'Binary variable indicating if island is NOT the sending energy through HVDC flow. 1 = Yes.'
  ;

SOS1 Variables
  ACBRANCHFLOWDIRECTED_INTEGER(dt,br,fd)           'Integer variables used to select branch flow direction in the event of circular branch flows (3.8.1)'
  HVDCLINKFLOWDIRECTED_INTEGER(dt,fd)              'Integer variables used to select the HVDC branch flow direction on in the event of S->N (forward) and N->S (reverse) flows (3.8.2)'
* Integer varaible to prevent intra-pole circulating branch flows
  HVDCPOLEFLOW_INTEGER(dt,pole,fd)                 'Integer variables used to select the HVDC pole flow direction on in the event of circulating branch flows within a pole'
  ;

SOS2 Variables
  LAMBDAINTEGER(dt,br,bp)                          'Integer variables used to enforce the piecewise linear loss approxiamtion on the HVDC links'
  LAMBDAHVDCENERGY(dt,isl,bp)                      'Integer variables used to enforce the piecewise linear loss approxiamtion (NMIR) on the HVDC links'
  LAMBDAHVDCRESERVE(dt,isl,resC,rd,rsbp)           'Integer variables used to enforce the piecewise linear loss approxiamtion (NMIR) on the HVDC links'
  ;


Equations
  ObjectiveFunction                                'Objective function of the dispatch model (5.1.1.1)'
* Cost and benefit breaking down
  SystemBenefitDefinition(dt)                      'Defined as the sum of the purcahse bid benefit'
  SystemCostDefinition(dt)                         'Defined as the sum of the generation and reserve costs'
  SystemPenaltyCostDefinition(dt)                  'Defined as the sum of the individual violation costs'
  TotalViolationCostDefinition                     'Deined as the sume of period violation cost - (for reporting)'
  TotalScarcityCostDefinition(dt)                  'Deined as the sume of scarcity cost'


* Offer and purchase constraints
  GenerationChangeUpDown(dt,o)                     'Calculate the MW of generation increase/decrease for RTD and RTDP (6.1.1.2)'
  GenerationOfferDefintion(dt,o)                   'Definition of generation provided by an offer (6.1.1.3)'
  DemBidDiscrete(dt,bd,blk)                        'Definition of discrete purchase mode (6.1.1.7)'
  DemBidDefintion(dt,bd)                           'Definition of purchase provided by a bid (6.1.1.8)'
  EnergyScarcityDefinition(dt,n)                   'Definition of bus energy scarcity (6.1.1.10)'

* Ramping constraints
  GenerationRampUp(dt,o)                           'Maximum movement of the generator upwards due to up ramp rate (6.2.1.1)'
  GenerationRampDown(dt,o)                         'Maximum movement of the generator downwards due to down ramp rate (6.2.1.2)'



* HVDC transmission constraints
  HVDClinkMaximumFlow(dt,br)                       'Maximum flow on each HVDC link (6.3.1.1)'
  HVDClinkLossDefinition(dt,br)                    'Definition of losses on the HVDC link (6.3.1.2)'
  HVDClinkFlowDefinition(dt,br)                    'Definition of MW flow on the HVDC link (6.3.1.3)'
  LambdaDefinition(dt,br)                          'Definition of weighting factor (6.3.1.4)'

* HVDC transmission constraints to resolve non-physical loss and circular flow
* These constraints are not explicitly formulated in SPD formulation
* But you can find the description in "Post-Solve Checks"
  HVDClinkFlowIntegerDefinition1(dt)               'Definition 1 of the integer HVDC link flow variable )'
  HVDClinkFlowIntegerDefinition2(dt,fd)            'Definition 2 of the integer HVDC link flow variable'
  HVDClinkFlowIntegerDefinition3(dt,pole)          'Definition 4 of the HVDC pole integer varaible to prevent intra-pole circulating branch flows'
  HVDClinkFlowIntegerDefinition4(dt,pole,fd)       'Definition 4 of the HVDC pole integer varaible to prevent intra-pole circulating branch flows'
  LambdaIntegerDefinition1(dt,br)                  'Definition of weighting factor when branch integer constraints are needed'
  LambdaIntegerDefinition2(dt,br,los)              'Definition of weighting factor when branch integer constraints are needed'

* AC transmission constraints
  ACnodeNetInjectionDefinition1(dt,b)              '1st definition of the net injection at buses corresponding to AC nodes (6.4.1.1)'
  ACnodeNetInjectionDefinition2(dt,b)              '2nd definition of the net injection at buses corresponding to AC nodes (6.4.1.2)'
  ACBranchMaximumFlow(dt,br,fd)                    'Maximum flow on the AC branch (6.4.1.3)'
  ACBranchFlowDefinition(dt,br)                    'Relationship between directed and undirected branch flow variables (6.4.1.4)'
  LinearLoadFlow(dt,br)                            'Equation that describes the linear load flow (6.4.1.5)'
  ACBranchBlockLimit(dt,br,los,fd)                 'Limit on each AC branch flow block (6.4.1.6)'
  ACDirectedBranchFlowDefinition(dt,br,fd)         'Composition of the directed branch flow from the block branch flow (6.4.1.7)'
  ACBranchLossCalculation(dt,br,los,fd)            'Calculation of the losses in each loss segment (6.4.1.8)'
  ACDirectedBranchLossDefinition(dt,br,fd)         'Composition of the directed branch losses from the block branch losses (6.4.1.9)'

* AC transmission constraints to resolve circular flow
  ACDirectedBranchFlowIntegerDefinition1(dt,br)    'Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses'
  ACDirectedBranchFlowIntegerDefinition2(dt,br,fd) 'Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses'

* Risk
  RiskOffsetCalculation_DCCE(dt,isl,resC,riskC)          '6.5.1.1 : Calculation of the risk offset variable for the DCCE risk class.'
  RiskOffsetCalculation_DCECE(dt,isl,resC,riskC)         '6.5.1.3 : Calculation of the risk offset variable for the DCECE risk class.'
  HVDCRecCalculation(dt,isl)                             '6.5.1.4 : Calculation of the net received HVDC MW flow into an island.'
  HVDCIslandRiskCalculation(dt,isl,resC,riskC)           '6.5.1.5 : Calculation of the island risk for a DCCE and DCECE.'

  GenIslandRiskCalculation(dt,isl,o,resC,riskC)          '6.5.1.6 : Calculation of the island risk for risk setting generators.'
  GenIslandRiskCalculation_1(dt,isl,o,resC,riskC)        '6.5.1.6 : Calculation of the island risk for risk setting generators.'
  ManualIslandRiskCalculation(dt,isl,resC,riskC)         '6.5.1.7 : Calculation of the island risk based on manual specifications.'
  HVDCSendMustZeroBinaryDefinition(dt,isl)               '6.5.1.8: Define a flag to show if HVDC sending zero MW flow from an island '

  HVDCIslandSecRiskCalculation_GEN(dt,isl,o,resC,riskC)     '6.5.1.9 : Calculation of the island risk for an HVDC secondary risk to an AC risk.'
  HVDCIslandSecRiskCalculation_GEN_1(dt,isl,o,resC,riskC)   '6.5.1.9 : Calculation of the island risk for an HVDC secondary risk to an AC risk.'
  HVDCIslandSecRiskCalculation_Manual(dt,isl,resC,riskC)    '6.5.1.10: Calculation of the island risk for an HVDC secondary risk to a manual risk.'
  HVDCIslandSecRiskCalculation_Manu_1(dt,isl,resC,riskC)    '6.5.1.10: Calculation of the island risk for an HVDC secondary risk to a manual risk.'
  GenIslandRiskGroupCalculation(dt,isl,rg,resC,riskC)       '6.5.1.11: Calculation of the island risk of risk group.'
  GenIslandRiskGroupCalculation_1(dt,isl,rg,resC,riskC)     '6.5.1.11: Calculation of the risk of risk group.'

* General NMIR equations
  EffectiveReserveShareCalculation(dt,isl,resC,riskC)                           '6.5.2.1 : Calculation of effective shared reserve'
  SharedReserveLimitByClearedReserve(dt,isl,resC)                               '6.5.2.2 : Shared offered reserve is limited by cleared reserved'
  BothClearedAndFreeReserveCanBeShared(dt,isl,resC,rd)                          '6.5.2.4 : Shared reserve is covered by cleared reserved and shareable free reserve'
  ReserveShareSentLimitByHVDCControlBand(dt,isl,resC,rd)                        '6.5.2.5 : Reserve share sent from an island is limited by HVDC control band'
  FwdReserveShareSentLimitByHVDCCapacity(dt,isl,resC,rd)                        '6.5.2.6 : Forward reserve share sent from an island is limited by HVDC capacity'
  ReverseReserveOnlyToEnergySendingIsland(dt,isl,resC,rd)                       '6.5.2.7 : Shared reserve sent in reverse direction is possible only if the island is not sending energy through HVDC'
  ReverseReserveShareLimitByHVDCControlBand(dt,isl,resC,rd)                     '6.5.2.8 : Reverse reserve share recieved at an island is limited by HVDC control band'
  ForwardReserveOnlyToEnergyReceivingIsland(dt,isl,resC,rd)                     '6.5.2.9 : Forward received reserve is possible if in the same direction of HVDC '
  ReverseReserveLimitInReserveZone(dt,isl,resC,rd,z)                            '6.5.2.10: Reverse reserve constraint if HVDC sent flow in reverse zone'
  ZeroReserveInNoReserveZone(dt,isl,resC,z)                                     '6.5.2.11 & 6.5.2.18: No reverse reserve if HVDC sent flow in no reverse zone and no forward reserve if round power disabled'
  OnlyOneActiveHVDCZoneForEachReserveClass(dt,resC)                             '6.5.2.12: Across both island, one and only one zone is active for each reserve class'
  ZeroSentHVDCFlowForNonSendingIsland(dt,isl)                                   '6.5.2.13: Directed HVDC sent from an island, if non-zero, must fall in a zone for each reserve class'
  RoundPowerZoneSentHVDCUpperLimit(dt,isl,resC,z)                               '6.5.2.14: Directed HVDC sent from an island <= RoundPowerZoneExit level if in round power zone of that island'
  HVDCSendingIslandDefinition(dt,isl,resC)                                      '6.5.2.15: An island is HVDC sending island if HVDC flow sent is in one of the three zones for each reserve class '
  OnlyOneSendingIslandExists(dt)                                                '6.5.2.19: One and only one island is HVDC sending island'
  HVDCSentCalculation(dt,isl)                                                   '6.5.2.20: Total HVDC sent from each island'

* Lamda loss model
  HVDCFlowAccountedForForwardReserve(dt,isl,resC,rd)                            '6.5.2.21: HVDC flow sent from an island taking into account forward sent reserve'
  ForwardReserveReceivedAtHVDCReceivingIsland(dt,isl,resC,rd)                   '6.5.2.22: Forward reserve RECEIVED at an HVDC receiving island'
  HVDCFlowAccountedForReverseReserve(dt,isl,resC,rd)                            '6.5.2.23: HVDC flow sent from an island taking into account reverse received reserve'
  ReverseReserveReceivedAtHVDCSendingIsland(dt,isl,resC,rd)                     '6.5.2.24: Reverse reserve RECEIVED at an HVDC sending island'
  HVDCSentEnergyLambdaDefinition(dt,isl)                                        '6.5.2.25: Definition of weight factor for total HVDC energy sent from an island'
  HVDCSentEnergyFlowDefinition(dt,isl)                                          '6.5.2.26: Lambda definition of total HVDC energy flow sent from an island'
  HVDCSentEnergyLossesDefinition(dt,isl)                                        '6.5.2.27: Lambda definition of total loss of HVDC energy sent from an island'
  HVDCSentReserveLambdaDefinition(dt,isl,resC,rd)                               '6.5.2.28: Definition of weight factor for total HVDC+reserve sent from an island'
  HVDCSentReserveFlowDefinition(dt,isl,resC,rd)                                 '6.5.2.29: Lambda definition of Reserse + Energy flow on HVDC sent from an island'
  HVDCSentReserveLossesDefinition(dt,isl,resC,rd)                               '6.5.2.30: Lambda definition of Reserse + Energy loss on HVDC sent from an island'

* Reserve share penalty
* Tuong Nguyen added on 24 Feb 2021 to correct the calculation
  ReserveShareEffective_CE_Calculation(dt,isl,resC,riskC)                       '6.5.2.31: Calculate max effective shared reserve for CE risk received at island'
  ReserveShareEffective_ECE_Calculation(dt,isl,resC,riskC)                      '6.5.2.31: Calculate max effective shared reserve for ECE risk received at island'
  ExcessReserveSharePenalty(dt)                                                 '6.5.2.31: Constraint to avoid excessive reserve share'

* Reserve
  PLSRReserveProportionMaximum(dt,o,blk,resC,resT)                              '6.5.3.1: Maximum PLSR as a proportion of the block MW'
  ReserveInterruptibleOfferLimit(dt,o,bd,resC,resT)                             '6.5.3.3: Cleared IL reserve is constrained by cleared dispatchable demand'
  ReserveOfferDefinition(dt,o,resC,resT)                                        '6.5.3.4: Definition of the reserve offers of different classes and types'
  EnergyAndReserveMaximum(dt,o,resC)                                            '6.5.3.5: Definition of maximum energy and reserves from each generator'

* Reserve scarcity/shortfall
  HVDCRiskReserveShortFallCalculation(dt,isl,resC,RiskC)                        '6.5.4.2: Total Reserve Shortfall for DCCE risk'
  ManualRiskReserveShortFallCalculation(dt,isl,resC,RiskC)                      '6.5.4.2: Total Reserve Shortfall for Manual risk'
  GenRiskReserveShortFallCalculation(dt,isl,o,resC,RiskC)                       '6.5.4.2: Total Reserve Shortfall for generation risk unit'
  HVDCsecRiskReserveShortFallCalculation(dt,isl,o,resC,RiskC)                   '6.5.4.2: Total Reserve Shortfall for generation unit + HVDC risk'
  HVDCsecManualRiskReserveShortFallCalculation(dt,isl,resC,RiskC)                '6.5.4.2: Total Reserve Shortfall for Manual risk + HVDC risk'
  RiskGroupReserveShortFallCalculation(dt,isl,rg,resC,RiskC)                     '6.5.4.2: Total Reserve Shortfall for Risk Group'

* Matching of reserve requirement and availability
  IslandReserveCalculation(dt,isl,resC)                                         '6.5.5.1: Calculate total island cleared reserve'
  SupplyDemandReserveRequirement(dt,isl,resC,riskC)                             '6.5.5.2&3: Matching of reserve supply and demand'

* Branch security constraints
  BranchSecurityConstraintLE(dt,brCstr)                                         '6.6.1.5: Branch security constraint with LE sense'
  BranchSecurityConstraintGE(dt,brCstr)                                         '6.6.1.5: Branch security constraint with GE sense'
  BranchSecurityConstraintEQ(dt,brCstr)                                         '6.6.1.5: Branch security constraint with EQ sense'

* Market node security constraints
  MNodeSecurityConstraintLE(dt,MnodeCstr)                                       '6.6.1.7: Market node security constraint with LE sense'
  MNodeSecurityConstraintGE(dt,MnodeCstr)                                       '6.6.1.7: Market node security constraint with GE sense'
  MNodeSecurityConstraintEQ(dt,MnodeCstr)                                       '6.6.1.7: Market node security constraint with EQ sense'

  ;

* OBJECTIVE FUNCTION (5.1.1.1)
ObjectiveFunction..
  NETBENEFIT
=e=
  sum[ t, SYSTEMBENEFIT(t) - SYSTEMCOST(t) - SCARCITYCOST(t)
        - SYSTEMPENALTYCOST(t) - RESERVESHAREPENALTY(t) ]
  + sum[(t,n,blk), ScarcityEnrgLimit(t,n,blk) * ScarcityEnrgPrice(t,n,blk)]
  ;

* Defined as the net sum of generation cost + reserve cost
SystemCostDefinition(t)..
  SYSTEMCOST(t)
=e=
  sum[ genOfrBlk(t,o,blk)
     , GENERATIONBLOCK(genOfrBlk)
     * EnrgOfrPrice(genOfrBlk) ]
+ sum[ resOfrBlk(t,o,blk,resC,resT)
     , RESERVEBLOCK(resOfrBlk)
     * ResOfrPrice(resOfrBlk) ]
  ;

* Defined as the net sum of dispatchable load benefit
SystemBenefitDefinition(t)..
  SYSTEMBENEFIT(t)
=e=
  sum[ demBidBlk(t,bd,blk)
     , PURCHASEBLOCK(demBidBlk)
     * DemBidPrice(demBidBlk) ]
  ;

* Defined as the sum of the individual violation costs
SystemPenaltyCostDefinition(t)..
  SYSTEMPENALTYCOST(t)
=e=
  sum[ bus(t,b), deficitBusGenerationPenalty * DEFICITBUSGENERATION(bus)
                    + surplusBusGenerationPenalty * SURPLUSBUSGENERATION(bus) ]

+ sum[ branch(t,br), surplusBranchFlowPenalty * SURPLUSBRANCHFLOW(branch) ]

+ sum[ offer(t,o), deficitRampRatePenalty * DEFICITRAMPRATE(offer)
                      + surplusRampRatePenalty * SURPLUSRAMPRATE(Offer) ]

+ sum[ BranchConstraint(t,brCstr)
     , deficitBrCstrPenalty * DEFICITBRANCHSECURITYCONSTRAINT(t,brCstr)
     + surplusBrCstrPenalty * SURPLUSBRANCHSECURITYCONSTRAINT(t,brCstr) ]

+ sum[ MNodeConstraint(t,MnodeCstr)
     , deficitMnodeCstrPenalty * DEFICITMNODECONSTRAINT(MNodeConstraint)
     + surplusMnodeCstrPenalty * SURPLUSMNODECONSTRAINT(MNodeConstraint) ]

+ sum[ (isl,resC)
       , [DeficitReservePenalty_CE  * DEFICITRESERVE_CE(t,isl,resC) ]
       + [DeficitReservePenalty_ECE * DEFICITRESERVE_ECE(t,isl,resC)]
     ]

+ sum[ o $ { (StudyMode = 101) or (StudyMode = 201) }
         , 0.0005 * ( GENERATIONUPDELTA(t,o) + GENERATIONDNDELTA(t,o) )
     ]
  ;

* Defined as the sum of the individual violation costs (for reporting)
TotalViolationCostDefinition..
  TOTALPENALTYCOST =e= sum[ t, SYSTEMPENALTYCOST(t) ] ;

* Deined as the sume of scarcity cost
TotalScarcityCostDefinition(t)..
  SCARCITYCOST(t)
=e=
  sum[ (n,blk), ScarcityEnrgPrice(t,n,blk) * ENERGYSCARCITYBLK(t,n,blk) ]

+ sum[ (isl,resC,riskC,blk) $ HVDCrisk(riskC)
     , ScarcityResrvIslandPrice(t,isl,resC,blk)
      * RESERVESHORTFALLBLK(t,isl,resC,riskC,blk) ]

+ sum[ (isl,resC,riskC,blk) $ ManualRisk(riskC)
     , ScarcityResrvIslandPrice(t,isl,resC,blk)
     * RESERVESHORTFALLBLK(t,isl,resC,riskC,blk) ]

+  sum[ (isl,o,resC,riskC,blk) $ { GenRisk(riskC)
                               and islandRiskGenerator(t,isl,o) }
     , ScarcityResrvIslandPrice(t,isl,resC,blk)
     * RESERVESHORTFALLUNITBLK(t,isl,o,resC,riskC,blk) ]

+  sum[ (isl,o,resC,riskC,blk) $ { HVDCsecRisk(riskC)
                               and islandRiskGenerator(t,isl,o) }
     , ScarcityResrvIslandPrice(t,isl,resC,blk)
     * RESERVESHORTFALLUNITBLK(t,isl,o,resC,riskC,blk) ]

+  sum[ (isl, resC,riskC,blk) $ HVDCsecRisk(riskC)
     , ScarcityResrvIslandPrice(t,isl,resC,blk)
     * RESERVESHORTFALLBLK(t,isl,resC,riskC,blk) ]

+  sum[ (isl,rg,resC,riskC,blk) $ GenRisk(riskC)
     , ScarcityResrvIslandPrice(t,isl,resC,blk)
     * RESERVESHORTFALLGROUPBLK(t,isl,rg,resC,riskC,blk) ]
;


*======= GENERATION AND LOAD CONSTRAINTS =======================================

* Calculate the MW of generation increase/decrease for RTD and RTDP (6.1.1.2)'
GenerationChangeUpDown(t,o) $ { (StudyMode = 101) or (StudyMode = 201) }..
  GENERATIONUPDELTA(t,o) - GENERATIONDNDELTA(t,o)
=e=
  GENERATION(t,o) - generationStart(t,o);

* Definition of generation provided by an offer (6.1.1.3)
GenerationOfferDefintion(offer(t,o))..
  GENERATION(offer)
=e=
  sum[ genOfrBlk(offer,blk), GENERATIONBLOCK(offer,blk) ]
  ;

* Definition of discrete purchase mode (6.1.1.7)
DemBidDiscrete(bid(t,bd),blk) $ discreteModeBid(bid) ..
  PURCHASEBLOCK(bid,blk)
=e=
  PURCHASEBLOCKBINARY(bid,blk) * DemBidMW(bid,blk) 
  ;

* Definition of purchase provided by a bid (6.1.1.8)
DemBidDefintion(bid(t,bd))..
  PURCHASE(bid)
=e=
  sum[ demBidBlk(bid,blk), PURCHASEBLOCK(bid,blk) ]
  ;

* Definition of bus energy scarcity (6.1.1.10)
EnergyScarcityDefinition(t,n)..
  ENERGYSCARCITYNODE(t,n)
=e=
  sum[ blk, ENERGYSCARCITYBLK(t,n,blk) ]
  ;

*======= GENERATION AND LOAD CONSTRAINTS END ===================================



*======= RAMPING CONSTRAINTS ===================================================
* Note: The CoefficientForRampRate in SPD formulation  = intervalDuration / 60

* Maximum movement of the generator downwards due to up ramp rate (6.2.1.1)
GenerationRampUp(t,o) $ { posEnrgOfr(t,o) and PrimaryOffer(t,o) }..
  sum[ o1 $ PrimarySecondaryOffer(t,o,o1), GENERATION(t,o1) ]
+ GENERATION(t,o) - DEFICITRAMPRATE(t,o)
=l=
  generationStart(t,o) + (RampRateUp(t,o) * intervalDuration / 60)
  ;

* Maximum movement of the generator downwards due to down ramp rate (6.2.1.2)
GenerationRampDown(t,o) $ { posEnrgOfr(t,o) and PrimaryOffer(t,o) }..
  sum[ o1 $ PrimarySecondaryOffer(t,o,o1), GENERATION(t,o1) ]
+ GENERATION(t,o) + SURPLUSRAMPRATE(t,o)
=g=
  generationStart(t,o) - (RampRateDn(t,o) * intervalDuration / 60)
  ;

*======= RAMPING CONSTRAINTS END================================================


*======= HVDC TRANSMISSION EQUATIONS ===========================================

* Maximum flow on each HVDC link (6.3.1.1)
HVDClinkMaximumFlow(HVDClink(t,br)) $ useHVDCbranchLimits ..
  HVDCLINKFLOW(HVDClink)
=l=
  sum[ fd $ ( ord(fd)=1 ), branchCapacity(HVDClink,fd) ]
  ;

* Definition of losses on the HVDC link (6.3.1.2)
HVDClinkLossDefinition(HVDClink(t,br))..
  HVDCLINKLOSSES(HVDClink)
=e=
  sum[ validLossSegment(HVDClink,bp,fd)
     , HVDCBreakPointMWLoss(HVDClink,bp,fd) * LAMBDA(HVDClink,bp) ]
  ;

* Definition of MW flow on the HVDC link (6.3.1.3)
HVDClinkFlowDefinition(HVDClink(t,br))..
  HVDCLINKFLOW(HVDClink)
=e=
  sum[ validLossSegment(HVDClink,bp,fd)
  , HVDCBreakPointMWFlow(HVDClink,bp,fd) * LAMBDA(HVDClink,bp) ]
  ;

* Definition of weighting factor (6.3.1.4)
LambdaDefinition(HVDClink(t,br))..
  sum(validLossSegment(HVDClink,bp,fd), LAMBDA(HVDClink,bp))
=e=
  1
  ;


*======= HVDC TRANSMISSION EQUATIONS END =======================================



*======= HVDC TRANSMISSION EQUATIONS FOR SOS1 VARIABLES ========================
* HVDC transmission constraints to resolve non-physical loss and circular flow
* These constraints are not explicitly formulated in SPD formulation
* But you can find the description in "Post-Solve Checks

* Definition 1 of the integer HVDC link flow variable
* HVDC_North_Flow + HVDC_South_Flow
* = BEN_HAY_1_Flow + BEN_HAY_2_Flow + HAY_BEN_1_Flow + HAY_BEN_2_Flow
HVDClinkFlowIntegerDefinition1(t) $ { UseBranchFlowMIP(t) and
                                      resolveCircularBranchFlows }..
  sum[ fd, HVDCLINKFLOWDIRECTED_INTEGER(t,fd) ]
=e=
  sum[ HVDCpoleDirection(HVDClink(t,br),fd), HVDCLINKFLOW(HVDClink) ]
  ;

* Definition 2 of the integer HVDC link flow variable
* HVDC_North_Flow = BEN_HAY_1_Flow + BEN_HAY_2_Flow
* HVDC_South_Flow = HAY_BEN_1_Flow + HAY_BEN_2_Flow
HVDClinkFlowIntegerDefinition2(t,fd) $ { UseBranchFlowMIP(t) and
                                         resolveCircularBranchFlows }..
  HVDCLINKFLOWDIRECTED_INTEGER(t,fd)
=e=
  sum[ HVDCpoleDirection(HVDClink(t,br),fd), HVDCLINKFLOW(HVDClink) ]
  ;

* Definition of the integer HVDC pole flow variable for intra-pole circulating branch flows
* Pole1_North_Flow + Pole1_South_Flow = BEN_HAY_1_Flow + HAY_BEN_1_Flow
* Pole2_North_Flow + Pole2_South_Flow = BEN_HAY_2_Flow + HAY_BEN_2_Flow
HVDClinkFlowIntegerDefinition3(t,pole) $ { UseBranchFlowMIP(t) and
                                           resolveCircularBranchFlows }..
  sum[ br $ { HVDClink(t,br)
          and HVDCpoleBranchMap(pole,br) } , HVDCLINKFLOW(t,br) ]
=e=
  sum[ fd, HVDCPOLEFLOW_INTEGER(t,pole,fd) ]
  ;

* Definition of the integer HVDC pole flow variable for intra-pole circulating branch flows
* Pole1_North_Flow = BEN_HAY_1_Flow + HAY_BEN_1_Flow
* Pole1_South_Flow = BEN_HAY_1_Flow + HAY_BEN_1_Flow
* Pole2_North_Flow = BEN_HAY_2_Flow + HAY_BEN_2_Flow
* Pole2_South_Flow = BEN_HAY_2_Flow + HAY_BEN_2_Flow

HVDClinkFlowIntegerDefinition4(t,pole,fd) $ { UseBranchFlowMIP(t) and
                                              resolveCircularBranchFlows }..
  sum[ HVDCpoleDirection(HVDClink(t,br),fd) $ HVDCpoleBranchMap(pole,br)
     , HVDCLINKFLOW(HVDClink) ]
=e=
  HVDCPOLEFLOW_INTEGER(t,pole,fd)
  ;

*======= HVDC TRANSMISSION EQUATIONS FOR SOS1 VARIABLES END ====================


*======= HVDC TRANSMISSION EQUATIONS FOR SOS2 VARIABLES ========================
* Definition 1 of weighting factor when branch integer constraints are needed
LambdaIntegerDefinition1(HVDClink(t,br)) $ { UseBranchFlowMIP(t) and
                                             resolveHVDCnonPhysicalLosses }..
  sum[ validLossSegment(HVDClink,bp,fd), LAMBDAINTEGER(HVDClink,bp) ]
=e=
  1
  ;

* Definition 2 of weighting factor when branch integer constraints are needed
LambdaIntegerDefinition2(HVDClink(t,br),bp)
  $ { UseBranchFlowMIP(t) and resolveHVDCnonPhysicalLosses
  and sum[ fd $ validLossSegment(HVDClink,bp,fd), 1] }..
  LAMBDAINTEGER(HVDClink,bp)
=e=
  LAMBDA(HVDClink,bp)
  ;

*======= HVDC TRANSMISSION EQUATIONS END =======================================




*======= AC TRANSMISSION EQUATIONS =============================================

* 1st definition of the net injection at buses corresponding to AC nodes (6.4.1.1)
ACnodeNetInjectionDefinition1(bus(t,b))..
  ACNODENETINJECTION(t,b)
=e=
  sum[ ACBranchSendingBus(ACBranch(t,br),b,fd)
     , ACBRANCHFLOWDIRECTED(ACBranch,fd)
     ]
- sum[ ACBranchReceivingBus(ACBranch(t,br),b,fd)
     , ACBRANCHFLOWDIRECTED(ACBranch,fd)
     ]
  ;

* 2nd definition of the net injection at buses corresponding to AC nodes (6.4.1.2)
ACnodeNetInjectionDefinition2(bus(t,b))..
  ACNODENETINJECTION(t,b)
=e=
  sum[ offerNode(t,o,n) $ NodeBus(t,n,b)
     , nodeBusAllocationFactor(t,n,b) * GENERATION(t,o) ]
- sum[ BidNode(t,bd,n) $ NodeBus(t,n,b)
     , NodeBusAllocationFactor(t,n,b) * PURCHASE(t,bd) ]
- sum[ NodeBus(t,n,b)
     , NodeBusAllocationFactor(t,n,b) * RequiredLoad(t,n) ]
+ sum[ HVDClinkReceivingBus(HVDClink(t,br),b), HVDCLINKFLOW(HVDClink)   ]
- sum[ HVDClinkReceivingBus(HVDClink(t,br),b), HVDCLINKLOSSES(HVDClink) ]
- sum[ HVDClinkSendingBus(HVDClink(t,br),b)  , HVDCLINKFLOW(HVDClink)   ]
- sum[ HVDClinkBus(HVDClink(t,br),b),   0.5 * branchFixedLoss(HVDClink) ]
- sum[ ACBranchReceivingBus(ACBranch(t,br),b,fd)
     , branchReceivingEndLossProportion
     * ACBRANCHLOSSESDIRECTED(ACBranch,fd) ]
- sum[ ACBranchSendingBus(ACBranch(t,br),b,fd)
     , (1 - branchReceivingEndLossProportion)
     * ACBRANCHLOSSESDIRECTED(ACBranch,fd) ]
- sum[ BranchBusConnect(ACBranch(t,br),b), 0.5*branchFixedLoss(ACBranch) ]
+ DEFICITBUSGENERATION(t,b) - SURPLUSBUSGENERATION(t,b)
* Note that we model energy scarcity as penalty instead of benefit like SPD
* The reason for this is to avoid numerical issues.
+ sum[ NodeBus(t,n,b)
     , NodeBusAllocationFactor(t,n,b) * ENERGYSCARCITYNODE(t,n)]
  ;

* Maximum flow on the AC branch (6.4.1.3)
ACBranchMaximumFlow(ACbranch(t,br),fd) $ useACbranchLimits..
  ACBRANCHFLOWDIRECTED(ACBranch,fd) - SURPLUSBRANCHFLOW(ACBranch)
=l=
  branchCapacity(ACBranch,fd)
  ;

* Relationship between directed and undirected branch flow variables (6.4.1.4)
ACBranchFlowDefinition(ACBranch(t,br))..
  ACBRANCHFLOW(ACBranch)
=e=
  sum[ fd $ (ord(fd) = 1), ACBRANCHFLOWDIRECTED(ACBranch,fd) ]
- sum[ fd $ (ord(fd) = 2), ACBRANCHFLOWDIRECTED(ACBranch,fd) ]
  ;

* Equation that describes the linear load flow (6.4.1.5)
LinearLoadFlow(ACBranch(t,br))..
  ACBRANCHFLOW(ACBranch)
=e=
  branchSusceptance(ACBranch)
  * sum[ BranchBusDefn(ACBranch,frB,toB)
       , ACNODEANGLE(t,frB) - ACNODEANGLE(t,toB) ]
  ;

* Limit on each AC branch flow block (6.4.1.6)
ACBranchBlockLimit(validLossSegment(ACBranch(t,br),los,fd))..
  ACBRANCHFLOWBLOCKDIRECTED(ACBranch,los,fd)
=l=
  ACBranchLossMW(ACBranch,los,fd)
  ;

* Composition of the directed branch flow from the block branch flow (6.4.1.7)
ACDirectedBranchFlowDefinition(ACBranch(t,br),fd)..
  ACBRANCHFLOWDIRECTED(ACBranch,fd)
=e=
  sum[ validLossSegment(ACBranch,los,fd)
     , ACBRANCHFLOWBLOCKDIRECTED(ACBranch,los,fd) ]
  ;

* Calculation of the losses in each loss segment (6.4.1.8) - Modified for BranchcReverseRatings
ACBranchLossCalculation(validLossSegment(ACBranch(t,br),los,fd))..
  ACBRANCHLOSSESBLOCKDIRECTED(ACBranch,los,fd)
=e=
  ACBRANCHFLOWBLOCKDIRECTED(ACBranch,los,fd)
  * ACBranchLossFactor(ACBranch,los,fd)
  ;

* Composition of the directed branch losses from the block branch losses (6.4.1.9)
ACDirectedBranchLossDefinition(ACBranch(t,br),fd)..
  ACBRANCHLOSSESDIRECTED(ACBranch,fd)
=e=
  sum[ validLossSegment(ACBranch,los,fd)
     , ACBRANCHLOSSESBLOCKDIRECTED(ACBranch,los,fd) ]
  ;

*======= AC TRANSMISSION EQUATIONS END =========================================



*======= AC TRANSMISSION EQUATIONS FOR SOS1 VARIABLES ==========================
* AC transmission constraints to resolve circular flow
* These constraints are not explicitly formulated in SPD formulation
* But you can find the description in "Post-Solve Checks"

* Integer constraint to enforce a flow direction on loss AC branches in the
* presence of circular branch flows or non-physical losses
ACDirectedBranchFlowIntegerDefinition1(ACBranch(lossBranch(t,br)))
  $ { UseBranchFlowMIP(t) and resolveCircularBranchFlows }..
  sum[ fd, ACBRANCHFLOWDIRECTED_INTEGER(ACBranch,fd) ]
=e=
  sum[ fd, ACBRANCHFLOWDIRECTED(ACBranch,fd) ]
  ;

* Integer constraint to enforce a flow direction on loss AC branches in the
* presence of circular branch flows or non-physical losses
ACDirectedBranchFlowIntegerDefinition2(ACBranch(lossBranch(t,br)),fd)
  $ { UseBranchFlowMIP(t) and resolveCircularBranchFlows }..
  ACBRANCHFLOWDIRECTED_INTEGER(ACBranch,fd)
=e=
  ACBRANCHFLOWDIRECTED(ACBranch,fd)
  ;

*======= AC TRANSMISSION EQUATIONS FOR SOS1 VARIABLES END ======================



*======= RISK EQUATIONS ========================================================

* 6.5.1.1 : Calculation of the risk offset variable for the DCCE risk class.
RiskOffsetCalculation_DCCE(t,isl,resC,riskC)
  $ { HVDCrisk(riskC) and ContingentEvents(riskC)  }..
  RISKOFFSET(t,isl,resC,riskC)
=e=
  FreeReserve(t,isl,resC,riskC) + HVDCPoleRampUp(t,isl,resC,riskC)
  ;

* 6.5.1.3 : Calculation of the risk offset variable for the DCECE risk class.
RiskOffsetCalculation_DCECE(t,isl,resC,riskC)
  $ { HVDCrisk(riskC) and ExtendedContingentEvent(riskC) }..
  RISKOFFSET(t,isl,resC,riskC)
=e=
  FreeReserve(t,isl,resC,riskC)
  ;

* 6.5.1.4 : Calculation of the net received HVDC MW flow into an island.
HVDCRecCalculation(t,isl)..
  HVDCREC(t,isl)
=e=
  sum[ (b,br) $ { BusIsland(t,b,isl)
              and HVDClinkSendingBus(t,br,b)
              and HVDCLink(t,br)
                }, -HVDCLINKFLOW(t,br)
     ]
+ sum[ (b,br) $ { BusIsland(t,b,isl)
              and HVDClinkReceivingBus(t,br,b)
              and HVDCLink(t,br)
                }, HVDCLINKFLOW(t,br) - HVDCLINKLOSSES(t,br)
     ]
  ;

* 6.5.1.5 : Calculation of the island risk for a DCCE and DCECE.
HVDCIslandRiskCalculation(t,isl,resC,HVDCrisk)..
  ISLANDRISK(t,isl,resC,HVDCrisk)
=e=
  IslandRiskAdjustmentFactor(t,isl,resC,HVDCrisk)
  * [ HVDCREC(t,isl)
    - RISKOFFSET(t,isl,resC,HVDCrisk)
    + modulationRiskClass(t,HVDCrisk)
    ]
* Scarcity reserve (only applied for CE risk)
  - RESERVESHORTFALL(t,isl,resC,HVDCrisk) $ ContingentEvents(HVDCrisk)
  ;

* 6.5.1.6 : Calculation of the risk of risk setting generators
GenIslandRiskCalculation_1(t,isl,o,resC,GenRisk)
  $ islandRiskGenerator(t,isl,o) ..
  GENISLANDRISK(t,isl,o,resC,GenRisk)
=e=
  IslandRiskAdjustmentFactor(t,isl,resC,GenRisk)
  * [ GENERATION(t,o)
    - FreeReserve(t,isl,resC,GenRisk)
    + FKBand(t,o)
    + sum[ resT, RESERVE(t,o,resC,resT) ]
    + sum[ o1 $ PrimarySecondaryOffer(t,o,o1)
         , sum[ resT, RESERVE(t,o1,resC,resT) ] + GENERATION(t,o1) ]
    ]
* NMIR update
- RESERVESHAREEFFECTIVE(t,isl,resC,GenRisk)$reserveShareEnabled(t,resC)
* Scarcity reserve (only applied for CE risk)
- RESERVESHORTFALLUNIT(t,isl,o,resC,GenRisk) $ ContingentEvents(GenRisk)
  ;

* 6.5.1.6 : Calculation of the island risk for risk setting generators
GenIslandRiskCalculation(t,isl,o,resC,GenRisk)
  $ islandRiskGenerator(t,isl,o) ..
  ISLANDRISK(t,isl,resC,GenRisk)
=g=
  GENISLANDRISK(t,isl,o,resC,GenRisk) ;

* 6.5.1.7 : Calculation of the island risk based on manual specifications
ManualIslandRiskCalculation(t,isl,resC,ManualRisk)..
  ISLANDRISK(t,isl,resC,ManualRisk)
=e=
  IslandRiskAdjustmentFactor(t,isl,resC,ManualRisk)
  * [ IslandMinimumRisk(t,isl,resC,ManualRisk)
    - FreeReserve(t,isl,resC,ManualRisk)
    ]
* NMIR update
- RESERVESHAREEFFECTIVE(t,isl,resC,ManualRisk)$reserveShareEnabled(t,resC)
* Scarcity reserve (only applied for CE risk)
- RESERVESHORTFALL(t,isl,resC,ManualRisk) $ ContingentEvents(ManualRisk)
  ;

* 6.5.1.8: Define a flag to show if HVDC sending zero MW flow from an island
HVDCSendMustZeroBinaryDefinition(t,isl).. HVDCSENT(t,isl) =l= BigM * [ 1 - HVDCSENDZERO(t,isl) ] ;


* 6.5.1.9 : Calculation of the island risk for an HVDC secondary generation risk
* HVDC secondary risk includes HVDC risk and Generation of both primary and secondary generation unit + cleared reserve + the FKBand for generator primary risk
HVDCIslandSecRiskCalculation_GEN_1(t,isl,o,resC,HVDCSecRisk)
  $ { islandRiskGenerator(t,isl,o)  and
      HVDCSecRiskEnabled(t,isl,HVDCSecRisk) }..
  HVDCGENISLANDRISK(t,isl,o,resC,HVDCSecRisk)
=e=
  IslandRiskAdjustmentFactor(t,isl,resC,HVDCSecRisk)
  * [ GENERATION(t,o)
    - FreeReserve(t,isl,resC,HVDCSecRisk)
    + HVDCREC(t,isl)
    - HVDCSecRiskSubtractor(t,isl)
    + FKBand(t,o)
    + sum[ resT, RESERVE(t,o,resC,resT) ]
    + sum[ o1 $ PrimarySecondaryOffer(t,o,o1)
         , sum[ resT, RESERVE(t,o1,resC,resT) ] + GENERATION(t,o1) ]
    + modulationRiskClass(t,HVDCSecRisk)
    ]
* Scarcity reserve (only applied for CE risk)
  - RESERVESHORTFALLUNIT(t,isl,o,resC,HVDCSecRisk) $ ContingentEvents(HVDCSecRisk)
* HVDC secondary risk not applied if HVDC sent is zero
  - BigM * sum[ isl1 $ (not sameas(isl1,isl)), HVDCSENDZERO(t,isl) ]
  ;

* 6.5.1.9 : Calculation of the island risk for an HVDC secondary generation risk
HVDCIslandSecRiskCalculation_GEN(t,isl,o,resC,HVDCSecRisk)
  $ { islandRiskGenerator(t,isl,o)  and
      HVDCSecRiskEnabled(t,isl,HVDCSecRisk) }..
  ISLANDRISK(t,isl,resC,HVDCSecRisk)
=g=
  HVDCGENISLANDRISK(t,isl,o,resC,HVDCSecRisk)
  ;

* 6.5.1.10: Calculation of the island risk for an HVDC secondary manual risk
HVDCIslandSecRiskCalculation_Manu_1(t,isl,resC,HVDCSecRisk)
  $ HVDCSecRiskEnabled(t,isl,HVDCSecRisk)..
  HVDCMANISLANDRISK(t,isl,resC,HVDCSecRisk)
=e=
  IslandRiskAdjustmentFactor(t,isl,resC,HVDCSecRisk)
  * [ IslandMinimumRisk(t,isl,resC,HVDCSecRisk)
    - FreeReserve(t,isl,resC,HVDCSecRisk)
    + HVDCREC(t,isl)
    - HVDCSecRiskSubtractor(t,isl)
    + modulationRiskClass(t,HVDCSecRisk)
    ]
* Scarcity reserve (only applied for CE risk)
  - RESERVESHORTFALL(t,isl,resC,HVDCSecRisk) $ ContingentEvents(HVDCSecRisk)
* HVDC secondary risk not applied if HVDC sent is zero
  - BigM * sum[ isl1 $ (not sameas(isl1,isl)), HVDCSENDZERO(t,isl) ]
  ;

* 6.5.1.10: Calculation of the island risk for an HVDC secondary manual risk
HVDCIslandSecRiskCalculation_Manual(t,isl,resC,HVDCSecRisk)
  $ HVDCSecRiskEnabled(t,isl,HVDCSecRisk)..
  ISLANDRISK(t,isl,resC,HVDCSecRisk)
=g=
  HVDCMANISLANDRISK(t,isl,resC,HVDCSecRisk)
  ;

* 6.5.1.11: Calculation of the risk of risk group
GenIslandRiskGroupCalculation_1(t,isl,rg,resC,GenRisk)
  $ islandRiskGroup(t,isl,rg,GenRisk)..
  GENISLANDRISKGROUP(t,isl,rg,resC,GenRisk)
=e=
  IslandRiskAdjustmentFactor(t,isl,resC,GenRisk)
  * [ sum[ o $ { offerIsland(t,o,isl)
             and riskGroupOffer(t,rg,o,GenRisk)
               } , GENERATION(t,o) + FKBand(t,o)
                 + sum[ resT, RESERVE(t,o,resC,resT) ]
         ]
    - FreeReserve(t,isl,resC,GenRisk)
    ]
* NMIR update
- RESERVESHAREEFFECTIVE(t,isl,resC,GenRisk)$reserveShareEnabled(t,resC)
* Scarcity reserve (only applied for CE risk)
- RESERVESHORTFALLGROUP(t,isl,rg,resC,GenRisk) $ ContingentEvents(GenRisk)
  ;

* 6.5.1.11: Calculation of the island risk for risk group
GenIslandRiskGroupCalculation(t,isl,rg,resC,GenRisk)
  $ islandRiskGroup(t,isl,rg,GenRisk)..
  ISLANDRISK(t,isl,resC,GenRisk)
=g=
  GENISLANDRISKGROUP(t,isl,rg,resC,GenRisk)
  ;

*======= RISK EQUATIONS END ====================================================


*======= NMIR - RESERVE SHARING EQUATIONS ======================================

* General NMIR equations start -------------------------------------------------

* Calculation of effective shared reserve - (6.5.2.1)
EffectiveReserveShareCalculation(t,isl,resC,riskC)
  $ { reserveShareEnabled(t,resC)
  and ( GenRisk(riskC) or ManualRisk(riskC) ) }..
  RESERVESHAREEFFECTIVE(t,isl,resC,riskC)
=l=
  Sum[ rd , RESERVESHARERECEIVED(t,isl,resC,rd)
          * effectiveFactor(t,isl,resC,riskC) ]
  ;

* Shared offered reserve is limited by cleared reserved - (6.5.2.2)
SharedReserveLimitByClearedReserve(t,isl,resC)
  $ reserveShareEnabled(t,resC)..
  SHAREDRESERVE(t,isl,resC)
=l=
  ISLANDRESERVE(t,isl,resC)
  ;

* Both cleared reserved and shareable free reserve can be shared - (6.5.2.4)
BothClearedAndFreeReserveCanBeShared(t,isl,resC,rd)
  $ reserveShareEnabled(t,resC)..
  RESERVESHARESENT(t,isl,resC,rd)
=l=
  SHAREDRESERVE(t,isl,resC) + SHAREDNFR(t,isl)$(ord(resC)=1)
  ;

* Reserve share sent is limited by HVDC control band - (6.5.2.5)
ReserveShareSentLimitByHVDCControlBand(t,isl,resC,rd)
  $ reserveShareEnabled(t,resC)..
  RESERVESHARESENT(t,isl,resC,rd)
=l=
  [ HVDCControlBand(t,rd) - modulationRisk(t)
  ] $ (HVDCControlBand(t,rd) > modulationRisk(t))
  ;

* Forward reserve share sent is limited by HVDC capacity - (6.5.2.6)
FwdReserveShareSentLimitByHVDCCapacity(t,isl,resC,rd)
  $ { reserveShareEnabled(t,resC) and (ord(rd) = 1) }..
  RESERVESHARESENT(t,isl,resC,rd)
+ HVDCSENT(t,isl)
=l=
  [ HVDCMax(t,isl) - modulationRisk(t) ] $ (HVDCMax(t,isl) > modulationRisk(t))
;

* Reverse shared reserve is only possible for receiving island - (6.5.2.7)
ReverseReserveOnlyToEnergySendingIsland(t,isl,resC,rd)
  $ { reserveShareEnabled(t,resC) and (ord(rd) = 2) }..
  RESERVESHARESENT(t,isl,resC,rd)
=l=
  BigM * [ 1 - HVDCSENDING(t,isl) ]
  ;

* Reverse shared reserve recieved at an island is limited by HVDC control band - (6.5.2.8)
ReverseReserveShareLimitByHVDCControlBand(t,isl,resC,rd)
  $ { reserveShareEnabled(t,resC) and (ord(rd) = 2) }..
  RESERVESHARERECEIVED(t,isl,resC,rd)
=l=
  HVDCSENDING(t,isl) * [ HVDCControlBand(t,rd) - modulationRisk(t)
                       ] $ ( HVDCControlBand(t,rd) > modulationRisk(t) )
  ;

* Forward received shared reserve only possible for receiving island - (3.4.2.9)
ForwardReserveOnlyToEnergyReceivingIsland(t,isl,resC,rd)
  $ { reserveShareEnabled(t,resC) and (ord(rd) = 1) }..
  RESERVESHARERECEIVED(t,isl,resC,rd)
=l=
  BigM * [ 1 - HVDCSENDING(t,isl) ]
  ;

* Reverse shared reserve limit if HVDC sent flow in reverse zone - (6.5.2.10)
ReverseReserveLimitInReserveZone(t,isl,resC,rd,z)
  $ { reserveShareEnabled(t,resC) and (ord(rd) = 2) and (ord(z) = 3) }..
  RESERVESHARERECEIVED(t,isl,resC,rd)
=l=
  HVDCSENT(t,isl)
- (MonopoleMinimum(t) + modulationRisk(t))
+ BigM * [ 1 - INZONE(t,isl,resC,z) ]
  ;

* No reverse shared reserve if HVDC sent flow in no reverse zone &
* No forward reserve if HVDC sent flow in no reverse zone and RP disabled
* (6.5.2.11) & (6.5.2.18)
ZeroReserveInNoReserveZone(t,isl,resC,z)
  $ { reserveShareEnabled(t,resC) and (ord(z) = 2) }..
  Sum[ rd $ (ord(rd) = 2), RESERVESHARERECEIVED(t,isl,resC,rd) ]
+ Sum[ rd $ (ord(rd) = 1), RESERVESHARESENT(t,isl,resC,rd)
     ] $ {reserveRoundPower(t,resC) = 0}
=l=
  BigM * [ 1 - INZONE(t,isl,resC,z) ]
  ;

* Across both island, only one zone is active for each reserve class -(6.5.2.12)
OnlyOneActiveHVDCZoneForEachReserveClass(t,resC) $ reserveShareEnabled(t,resC)..
  Sum[ (isl,z), INZONE(t,isl,resC,z) ] =e= 1 ;

* HVDC sent from sending island only - (6.5.2.13)
ZeroSentHVDCFlowForNonSendingIsland(t,isl) $ reserveShareEnabledOverall(t)..
  HVDCSENT(t,isl) =l= BigM * HVDCSENDING(t,isl) ;

* HVDC sent from an island <= RoundPowerZoneExit level if in round power zone
* of that island - (6.5.2.14)
RoundPowerZoneSentHVDCUpperLimit(t,isl,resC,z)
  $ { reserveShareEnabled(t,resC) and (ord(z) = 1) }..
  HVDCSENT(t,isl)
=l=
  roPwrZoneExit(t,resC) + BigM * [ 1 - INZONE(t,isl,resC,z) ]
;

* An island is HVDC sending island if HVDC flow sent is in one of the three
* zones for each reserve class - (6.5.2.15)
HVDCSendingIslandDefinition(t,isl,resC) $ reserveShareEnabled(t,resC)..
  HVDCSENDING(t,isl) =e= Sum[ z, INZONE(t,isl,resC,z) ] ;

* One and only one island is HVDC sending island - (6.5.2.19)
OnlyOneSendingIslandExists(t) $ reserveShareEnabledOverall(t)..
 Sum[ isl, HVDCSENDING(t,isl) ] =e= 1 ;

* Total HVDC sent from each island - (6.5.2.20)
HVDCSentCalculation(t,isl) $ reserveShareEnabledOverall(t)..
  HVDCSENT(t,isl)
=e=
  Sum[ (b,br) $ { BusIsland(t,b,isl)
              and HVDClinkSendingBus(t,br,b)
              and HVDClink(t,br)
                }, HVDCLINKFLOW(t,br)
     ]
;

* General NMIR equations end ---------------------------------------------------


* Lamda loss model -------------------------------------------------------------

* HVDC flow + forward reserve sent from an island - (6.5.2.21)
HVDCFlowAccountedForForwardReserve(t,isl,resC,rd)
  $ { reserveShareEnabled(t,resC) and (ord(rd) = 1) }..
  HVDCRESERVESENT(t,isl,resC,rd)
=e=
  RESERVESHARESENT(t,isl,resC,rd) + HVDCSENT(t,isl)
  ;

* Received forward shared reserve at an HVDC receiving island - (6.5.2.22)
ForwardReserveReceivedAtHVDCReceivingIsland(t,isl,resC,rd)
  $ { reserveShareEnabled(t,resC) and (ord(rd) = 1) }..
  RESERVESHARERECEIVED(t,isl,resC,rd)
=e=
  Sum[ isl1 $ (not sameas(isl1,isl))
      , RESERVESHARESENT(t,isl1,resC,rd)
      - HVDCRESERVELOSS(t,isl1,resC,rd)
      + HVDCSENTLOSS(t,isl1) ]
  ;

* HVDC flow - received reverse reserve sent from an island - (6.5.2.23)
HVDCFlowAccountedForReverseReserve(t,isl,resC,rd)
  $ { reserveShareEnabled(t,resC) and (ord(rd) = 2) }..
  HVDCRESERVESENT(t,isl,resC,rd)
=e=
  HVDCSENT(t,isl) - RESERVESHARERECEIVED(t,isl,resC,rd)
  ;

* Reverse reserve RECEIVED at an HVDC sending island - (6.5.2.24)
ReverseReserveReceivedAtHVDCSendingIsland(t,isl,resC,rd)
  $ { reserveShareEnabled(t,resC) and (ord(rd) = 2) }..
  RESERVESHARERECEIVED(t,isl,resC,rd)
=e=
  Sum[ isl1 $ (not sameas(isl1,isl)), RESERVESHARESENT(t,isl1,resC,rd) ]
- HVDCRESERVELOSS(t,isl,resC,rd)
+ HVDCSENTLOSS(t,isl)
  ;

* Total weight factor = 1 for HVDC energy sent from an island - (6.5.2.25)
HVDCSentEnergyLambdaDefinition(t,isl) $ reserveShareEnabledOverall(t)..
  Sum[ bp $ (ord(bp) <= 7),LAMBDAHVDCENERGY(t,isl,bp) ] =e= 1 ;

* Lambda definition of total HVDC energy flow sent from an island
* (6.5.2.26) - SPD version 11.0
HVDCSentEnergyFlowDefinition(t,isl) $ reserveShareEnabledOverall(t)..
  HVDCSENT(t,isl)
=e=
  Sum[ bp $ (ord(bp) <= 7), HVDCSentBreakPointMWFlow(t,isl,bp)
                          * LAMBDAHVDCENERGY(t,isl,bp) ]
  ;

* Lambda definition of total loss of HVDC energy sent from an island
* (6.5.2.27) - SPD version 11.0
HVDCSentEnergyLossesDefinition(t,isl) $ reserveShareEnabledOverall(t)..
  HVDCSENTLOSS(t,isl)
=e=
  Sum[ bp $ (ord(bp) <= 7), HVDCSentBreakPointMWLoss(t,isl,bp)
                          * LAMBDAHVDCENERGY(t,isl,bp) ]
  ;

* Total weight factor = 1 for HVDC+reserve sent from an island -(6.5.2.28)
HVDCSentReserveLambdaDefinition(t,isl,resC,rd) $ reserveShareEnabled(t,resC)..
  Sum[ rsbp, LAMBDAHVDCRESERVE(t,isl,resC,rd,rsbp) ] =e= 1 ;

* Lambda definition of Reserse + Energy flow on HVDC sent from an island
* (3.4.2.29) - SPD version 11.0
HVDCSentReserveFlowDefinition(t,isl,resC,rd)
  $ reserveShareEnabled(t,resC)..
  HVDCRESERVESENT(t,isl,resC,rd)
=e=
  Sum[ rsbp, HVDCReserveBreakPointMWFlow(t,isl,rsbp)
           * LAMBDAHVDCRESERVE(t,isl,resC,rd,rsbp) ]
  ;

* Lambda definition of Reserse + Energy Loss on HVDC sent from an island
* (3.4.2.30) - SPD version 11.0
HVDCSentReserveLossesDefinition(t,isl,resC,rd)
  $ reserveShareEnabled(t,resC)..
  HVDCRESERVELOSS(t,isl,resC,rd)
=e=
  Sum[ rsbp, HVDCReserveBreakPointMWLoss(t,isl,rsbp)
           * LAMBDAHVDCRESERVE(t,isl,resC,rd,rsbp) ]
  ;

* Lamda loss model end ---------------------------------------------------------


* Calculate Reserve sharing excess penalty -------------------------------------

* Tuong Nguyen added on 24 Feb 2021 to correct the calculation
* Calculate max effective shared reserve for CE risk received at island (6.5.2.31)
ReserveShareEffective_CE_Calculation(t,isl,resC,riskC)
  $ { reserveShareEnabled(t,resC) and ContingentEvents(riskC)
  and ( GenRisk(riskC) or ManualRisk(riskC) ) }..
  RESERVESHAREEFFECTIVE_CE(t,isl,resC)
=g=
  RESERVESHAREEFFECTIVE(t,isl,resC,riskC)
  ;

* Tuong Nguyen added on 24 Feb 2021 to correct the calculation
* Calculate max effective shared reserve for CE risk received at island (6.5.2.31)
ReserveShareEffective_ECE_Calculation(t,isl,resC,riskC)
  $ { reserveShareEnabled(t,resC) and ExtendedContingentEvent(riskC)
  and ( GenRisk(riskC) or ManualRisk(riskC) ) }..
  RESERVESHAREEFFECTIVE_ECE(t,isl,resC)
=g=
  RESERVESHAREEFFECTIVE(t,isl,resC,riskC)
  ;

* Constraint to avoid excessive reserve share (6.5.2.31)
ExcessReserveSharePenalty(t) $ reserveShareEnabledOverall(t)..
  RESERVESHAREPENALTY(t)
=e=
  sum[ isl, 1e-5 * SHAREDNFR(t,isl) ]
+ sum[ (isl,resC), 2e-5 * SHAREDRESERVE(t,isl,resC) ]
* Tuong Nguyen modified on 24 Feb 2021 to correct the calculation
*+ sum[ (isl,resC,riskC), 3e-5 * RESERVESHAREEFFECTIVE(t,isl,resC,riskC)]
+ sum[ (isl,resC), 3e-5 * RESERVESHAREEFFECTIVE_CE(t,isl,resC)]
+ sum[ (isl,resC), 3e-5 * RESERVESHAREEFFECTIVE_ECE(t,isl,resC)]
;
* Calculate Reserve sharing excess penalty end ---------------------------------

*======= NMIR - RESERVE SHARING EQUATIONS END ==================================



*======= RESERVE EQUATIONS =====================================================
* 6.5.3.1: Maximum PLSR as a proportion of the block MW
PLSRReserveProportionMaximum(offer(t,o),blk,resC,PLRO)
  $ resOfrBlk(offer,blk,resC,PLRO)..
  RESERVEBLOCK(Offer,blk,resC,PLRO)
=l=
  ResOfrPct(Offer,blk,resC) * GENERATION(Offer)
  ;

* 6.5.3.3: Cleared IL reserve is constrained by cleared dispatchable demand'
ReserveInterruptibleOfferLimit(t,o,bd,resC,ILRO(resT))
  $ { sameas(o,bd) and offer(t,o) and bid(t,bd) and (sum[blk,DemBidMW(t,bd,blk)] >= 0) } ..
  RESERVE(t,o,resC,resT)
=l=
  PURCHASE(t,bd);


* 6.5.3.4 Definition of the reserve offers of different classes and types
ReserveOfferDefinition(offer(t,o),resC,resT)..
  RESERVE(offer,resC,resT)
=e=
  sum[ blk, RESERVEBLOCK(offer,blk,resC,resT) ]
  ;

* 6.5.3.5 Definition of maximum energy and reserves from each generator
EnergyAndReserveMaximum(offer(t,o),resC)..
  GENERATION(offer)
+ reserveMaximumFactor(offer,resC)
  * sum[ resT $ (not ILRO(resT)), RESERVE(offer,resC,resT) ]
=l=
  ReserveGenerationMaximum(offer)
  ;

*======= RESERVE EQUATIONS END =================================================



*======= RESERVE SCARCITY ======================================================
* 6.5.4.2: Total Reserve Shortfall for DCCE risk
HVDCRiskReserveShortFallCalculation(t,isl,resC,HVDCrisk(RiskC))
  $ ContingentEvents(riskC)..
  RESERVESHORTFALL(t,isl,resC,riskC)
=e=
  sum[ blk, RESERVESHORTFALLBLK(t,isl,resC,riskC,blk) ]
  ;

* 6.5.4.2: Total Reserve Shortfall for Manual risk
ManualRiskReserveShortFallCalculation(t,isl,resC,ManualRisk(RiskC))
  $ ContingentEvents(riskC)..
  RESERVESHORTFALL(t,isl,resC,riskC)
=e=
  sum[ blk, RESERVESHORTFALLBLK(t,isl,resC,riskC,blk) ]
  ;

* 6.5.4.2: Total Reserve Shortfall for generation risk unit
GenRiskReserveShortFallCalculation(t,isl,o,resC,GenRisk(RiskC))
  $ { ContingentEvents(riskC) and  islandRiskGenerator(t,isl,o)  }..
  RESERVESHORTFALLUNIT(t,isl,o,resC,riskC)
=e=
  sum[ blk, RESERVESHORTFALLUNITBLK(t,isl,o,resC,riskC,blk) ]
  ;

* 6.5.4.2: Total Reserve Shortfall for generation unit + HVDC risk
HVDCsecRiskReserveShortFallCalculation(t,isl,o,resC,HVDCsecRisk(RiskC))
  $ { ContingentEvents(riskC) and  islandRiskGenerator(t,isl,o)  }..
  RESERVESHORTFALLUNIT(t,isl,o,resC,riskC)
=e=
  sum[ blk, RESERVESHORTFALLUNITBLK(t,isl,o,resC,riskC,blk) ]
  ;

* 6.5.4.2: Total Reserve Shortfall for Manual risk + HVDC risk
HVDCsecManualRiskReserveShortFallCalculation(t,isl,resC,HVDCsecRisk(RiskC))
  $ ContingentEvents(riskC)..
  RESERVESHORTFALL(t,isl,resC,riskC)
=e=
  sum[ blk, RESERVESHORTFALLBLK(t,isl,resC,riskC,blk) ]
  ;

* 6.5.4.2: Total Reserve Shortfall for risk group
RiskGroupReserveShortFallCalculation(t,isl,rg,resC,GenRisk(RiskC))
  $ { ContingentEvents(riskC) and islandRiskGroup(t,isl,rg,RiskC)}..
  RESERVESHORTFALLGROUP(t,isl,rg,resC,riskC)
=e=
  sum[ blk, RESERVESHORTFALLGROUPBLK(t,isl,rg,resC,riskC,blk) ]
  ;

*======= RESERVE SCARCITY END ==================================================



*======= RISK AND RESERVE BALANCE EQUATIONS ====================================

* 6.5.5.1: Calculate total island cleared reserve
IslandReserveCalculation(t,isl,resC)..
  ISLANDRESERVE(t,isl,resC)
=l=
  Sum[ (o,resT) $ { offer(t,o) and offerIsland(t,o,isl) }
                , RESERVE(t,o,resC,resT)
     ]
  ;

* 6.5.5.2 & 6.5.5.3: Matching of reserve supply and demand
SupplyDemandReserveRequirement(t,isl,resC,riskC) $ useReserveModel..
  ISLANDRISK(t,isl,resC,riskC)
- DEFICITRESERVE_CE(t,isl,resC)   $ ContingentEvents(riskC)
- DEFICITRESERVE_ECE(t,isl,resC)  $ ExtendedContingentEvent(riskC)
=l=
  ISLANDRESERVE(t,isl,resC)
  ;

*======= RISK AND RESERVE BALANCE EQUATIONS END ================================



*======= SECURITY EQUATIONS ====================================================

* 6.6.1.5 Branch security constraint with LE sense
BranchSecurityConstraintLE(t,brCstr)
  $ (BranchConstraintSense(t,brCstr) = -1)..
  sum[ br $ ACbranch(t,br)
     , branchCstrFactors(t,brCstr,br) * ACBRANCHFLOW(t,br) ]
+ sum[ br $ HVDClink(t,br)
     , branchCstrFactors(t,brCstr,br) * HVDCLINKFLOW(t,br) ]
- SURPLUSBRANCHSECURITYCONSTRAINT(t,brCstr)
=l=
  BranchConstraintLimit(t,brCstr)
  ;

* 6.6.1.5 Branch security constraint with GE sense
BranchSecurityConstraintGE(t,brCstr)
  $ (BranchConstraintSense(t,brCstr) = 1)..
  sum[ br $ ACbranch(t,br)
     , branchCstrFactors(t,brCstr,br) * ACBRANCHFLOW(t,br) ]
+ sum[ br $ HVDClink(t,br)
     , branchCstrFactors(t,brCstr,br) * HVDCLINKFLOW(t,br) ]
+ DEFICITBRANCHSECURITYCONSTRAINT(t,brCstr)
=g=
  BranchConstraintLimit(t,brCstr)
  ;

* 6.6.1.5 Branch security constraint with EQ sense
BranchSecurityConstraintEQ(t,brCstr)
  $ (BranchConstraintSense(t,brCstr) = 0)..
  sum[ br $ ACbranch(t,br)
     , branchCstrFactors(t,brCstr,br) * ACBRANCHFLOW(t,br) ]
+ sum[ br $ HVDClink(t,br)
     , branchCstrFactors(t,brCstr,br) * HVDCLINKFLOW(t,br) ]
+ DEFICITBRANCHSECURITYCONSTRAINT(t,brCstr)
- SURPLUSBRANCHSECURITYCONSTRAINT(t,brCstr)
=e=
  BranchConstraintLimit(t,brCstr)
  ;



* Market node security constraint with LE sense (3.5.1.7a)
MNodeSecurityConstraintLE(t,MnodeCstr)
  $ (MNodeConstraintSense(t,MnodeCstr) = -1)..
  sum[ o $ posEnrgOfr(t,o)
       , MNCstrEnrgFactors(t,MnodeCstr,o)
       * GENERATION(t,o)
     ]
+ sum[ (o,resC,resT) $ offer(t,o)
       , MNCnstrResrvFactors(t,MnodeCstr,o,resC,resT)
       * RESERVE(t,o,resC,resT)
     ]
+ sum[ bd $ Bid(t,bd)
       , mnCnstrEnrgBidFactors(t,MnodeCstr,bd)
       * PURCHASE(t,bd)
     ]
- SURPLUSMNODECONSTRAINT(t,MnodeCstr)
=l=
  MNodeConstraintLimit(t,MnodeCstr)
  ;

* Market node security constraint with GE sense (3.5.1.7b)
MNodeSecurityConstraintGE(t,MnodeCstr)
  $ (MNodeConstraintSense(t,MnodeCstr) = 1)..
  sum[ o $ posEnrgOfr(t,o)
       , MNCstrEnrgFactors(t,MnodeCstr,o)
       * GENERATION(t,o)
     ]
+ sum[ (o,resC,resT) $ offer(t,o)
       , MNCnstrResrvFactors(t,MnodeCstr,o,resC,resT)
       * RESERVE(t,o,resC,resT)
     ]
+ sum[ bd $ Bid(t,bd)
       , mnCnstrEnrgBidFactors(t,MnodeCstr,bd)
       * PURCHASE(t,bd)
     ]
+ DEFICITMNODECONSTRAINT(t,MnodeCstr)
=g=
  MNodeConstraintLimit(t,MnodeCstr)
  ;

* Market node security constraint with EQ sense (3.5.1.7c)
MNodeSecurityConstraintEQ(t,MnodeCstr)
  $ (MNodeConstraintSense(t,MnodeCstr) = 0)..
  sum[ o $ posEnrgOfr(t,o)
       , MNCstrEnrgFactors(t,MnodeCstr,o)
       * GENERATION(t,o)
     ]
+ sum[ (o,resC,resT) $ offer(t,o)
       , MNCnstrResrvFactors(t,MnodeCstr,o,resC,resT)
       * RESERVE(t,o,resC,resT)
     ]
+ sum[ bd $ Bid(t,bd)
       , mnCnstrEnrgBidFactors(t,MnodeCstr,bd)
       * PURCHASE(t,bd)
     ]
+ DEFICITMNODECONSTRAINT(t,MnodeCstr)
- SURPLUSMNODECONSTRAINT(t,MnodeCstr)
=e=
  MNodeConstraintLimit(t,MnodeCstr)
  ;

*======= SECURITY EQUATIONS END ================================================


* Model declarations
Model vSPD /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, DemBidDefintion
  EnergyScarcityDefinition,
  GenerationRampUp, GenerationRampDown
* Network
  HVDClinkMaximumFlow, HVDClinkLossDefinition
  HVDClinkFlowDefinition, LambdaDefinition
  ACnodeNetInjectionDefinition1
  ACnodeNetInjectionDefinition2, ACBranchMaximumFlow
  ACBranchFlowDefinition, LinearLoadFlow
  ACBranchBlockLimit, ACDirectedBranchFlowDefinition
  ACBranchLossCalculation, ACDirectedBranchLossDefinition
* Risk
  HVDCIslandRiskCalculation, HVDCRecCalculation
  GenIslandRiskCalculation, GenIslandRiskCalculation_1
  GenIslandRiskGroupCalculation, GenIslandRiskGroupCalculation_1
  ManualIslandRiskCalculation
* Reserve
  PLSRReserveProportionMaximum, ReserveOfferDefinition
  EnergyAndReserveMaximum
* Reserve scarcity/shortfall
  HVDCRiskReserveShortFallCalculation
  ManualRiskReserveShortFallCalculation
  GenRiskReserveShortFallCalculation
  HVDCsecRiskReserveShortFallCalculation
  HVDCsecManualRiskReserveShortFallCalculation
  RiskGroupReserveShortFallCalculation
* Matching of reserve requirement and availability
  SupplyDemandReserveRequirement, IslandReserveCalculation
* Risk Offset calculation
  RiskOffsetCalculation_DCCE
  RiskOffsetCalculation_DCECE
* Island risk definitions
* Include HVDC secondary risk constraints
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_GEN_1
  HVDCIslandSecRiskCalculation_Manual, HVDCIslandSecRiskCalculation_Manu_1
* Branch security constraints
  BranchSecurityConstraintLE
  BranchSecurityConstraintGE
  BranchSecurityConstraintEQ
* Market node security constraints
  MNodeSecurityConstraintLE, MNodeSecurityConstraintGE
  MNodeSecurityConstraintEQ
* ViolationCost
  SystemCostDefinition, SystemBenefitDefinition
  SystemPenaltyCostDefinition, TotalViolationCostDefinition
  TotalScarcityCostDefinition
  / ;

Model vSPD_NMIR /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, DemBidDiscrete,
  DemBidDefintion, EnergyScarcityDefinition,
  GenerationRampUp, GenerationRampDown, GenerationChangeUpDown
* Network
  HVDClinkMaximumFlow, HVDClinkLossDefinition
  HVDClinkFlowDefinition, LambdaDefinition
  ACnodeNetInjectionDefinition1
  ACnodeNetInjectionDefinition2, ACBranchMaximumFlow
  ACBranchFlowDefinition, LinearLoadFlow
  ACBranchBlockLimit, ACDirectedBranchFlowDefinition
  ACBranchLossCalculation, ACDirectedBranchLossDefinition
* Risk
  RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
  HVDCIslandRiskCalculation, HVDCRecCalculation, ManualIslandRiskCalculation
  GenIslandRiskCalculation, GenIslandRiskCalculation_1
  GenIslandRiskGroupCalculation, GenIslandRiskGroupCalculation_1
  HVDCSendMustZeroBinaryDefinition
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_GEN_1
  HVDCIslandSecRiskCalculation_Manual, HVDCIslandSecRiskCalculation_Manu_1
* Reserve
  PLSRReserveProportionMaximum, ReserveInterruptibleOfferLimit
  ReserveOfferDefinition, EnergyAndReserveMaximum
* Reserve scarcity/shortfall
  HVDCRiskReserveShortFallCalculation
  ManualRiskReserveShortFallCalculation
  GenRiskReserveShortFallCalculation
  HVDCsecRiskReserveShortFallCalculation
  HVDCsecManualRiskReserveShortFallCalculation
  RiskGroupReserveShortFallCalculation
* Matching of reserve requirement and availability
  SupplyDemandReserveRequirement, IslandReserveCalculation
* Branch security constraints
  BranchSecurityConstraintLE
  BranchSecurityConstraintGE
  BranchSecurityConstraintEQ
* Market node security constraints
  MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
* ViolationCost
  SystemCostDefinition, SystemBenefitDefinition
  SystemPenaltyCostDefinition, TotalViolationCostDefinition
  TotalScarcityCostDefinition
* General NMIR equations
  EffectiveReserveShareCalculation
  SharedReserveLimitByClearedReserve
  BothClearedAndFreeReserveCanBeShared
  ReverseReserveShareLimitByHVDCControlBand
  ReserveShareSentLimitByHVDCControlBand
  FwdReserveShareSentLimitByHVDCCapacity
  ReverseReserveOnlyToEnergySendingIsland
  ForwardReserveOnlyToEnergyReceivingIsland
  ReverseReserveLimitInReserveZone
  ZeroReserveInNoReserveZone
  OnlyOneActiveHVDCZoneForEachReserveClass
  ZeroSentHVDCFlowForNonSendingIsland
  RoundPowerZoneSentHVDCUpperLimit
  HVDCSendingIslandDefinition
  OnlyOneSendingIslandExists
  HVDCSentCalculation
  ExcessReserveSharePenalty
  ReserveShareEffective_CE_Calculation
  ReserveShareEffective_ECE_Calculation
* Lamda loss model NMIR
  HVDCFlowAccountedForForwardReserve
  ForwardReserveReceivedAtHVDCReceivingIsland
  HVDCFlowAccountedForReverseReserve
  ReverseReserveReceivedAtHVDCSendingIsland
  HVDCSentEnergyLambdaDefinition
  HVDCSentEnergyFlowDefinition
  HVDCSentEnergyLossesDefinition
  HVDCSentReserveLambdaDefinition
  HVDCSentReserveFlowDefinition
  HVDCSentReserveLossesDefinition
  / ;

Model vSPD_MIP /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, DemBidDiscrete, DemBidDefintion
  EnergyScarcityDefinition,
  GenerationRampUp, GenerationRampDown, GenerationChangeUpDown
* Network
  HVDClinkMaximumFlow, HVDClinkLossDefinition
  HVDClinkFlowDefinition, LambdaDefinition
  ACnodeNetInjectionDefinition1
  ACnodeNetInjectionDefinition2, ACBranchMaximumFlow
  ACBranchFlowDefinition, LinearLoadFlow
  ACBranchBlockLimit, ACDirectedBranchFlowDefinition
  ACBranchLossCalculation, ACDirectedBranchLossDefinition
  ACDirectedBranchFlowIntegerDefinition1, ACDirectedBranchFlowIntegerDefinition2
  LambdaIntegerDefinition1, LambdaIntegerDefinition2
* Risk
  RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
  HVDCIslandRiskCalculation, HVDCRecCalculation, ManualIslandRiskCalculation
  GenIslandRiskCalculation, GenIslandRiskCalculation_1
  GenIslandRiskGroupCalculation, GenIslandRiskGroupCalculation_1
  HVDCSendMustZeroBinaryDefinition
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_GEN_1
  HVDCIslandSecRiskCalculation_Manual, HVDCIslandSecRiskCalculation_Manu_1
* Reserve
  PLSRReserveProportionMaximum, ReserveInterruptibleOfferLimit
  ReserveOfferDefinition, EnergyAndReserveMaximum
* Reserve scarcity/shortfall
  HVDCRiskReserveShortFallCalculation
  ManualRiskReserveShortFallCalculation
  GenRiskReserveShortFallCalculation
  HVDCsecRiskReserveShortFallCalculation
  HVDCsecManualRiskReserveShortFallCalculation
  RiskGroupReserveShortFallCalculation
* Matching of reserve requirement and availability
  SupplyDemandReserveRequirement, IslandReserveCalculation
* Branch security constraints
  BranchSecurityConstraintLE
  BranchSecurityConstraintGE
  BranchSecurityConstraintEQ
* Market node security constraints
  MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
* ViolationCost
  SystemCostDefinition, SystemBenefitDefinition
  SystemPenaltyCostDefinition, TotalViolationCostDefinition
  TotalScarcityCostDefinition
* Set of integer constraints on the HVDC link to incorporate the allowance of HVDC roundpower
  HVDClinkFlowIntegerDefinition1, HVDClinkFlowIntegerDefinition2
  HVDClinkFlowIntegerDefinition3, HVDClinkFlowIntegerDefinition4
* General NMIR equations
  EffectiveReserveShareCalculation
  SharedReserveLimitByClearedReserve
  BothClearedAndFreeReserveCanBeShared
  ReverseReserveShareLimitByHVDCControlBand
  ReserveShareSentLimitByHVDCControlBand
  FwdReserveShareSentLimitByHVDCCapacity
  ReverseReserveOnlyToEnergySendingIsland
  ForwardReserveOnlyToEnergyReceivingIsland
  ReverseReserveLimitInReserveZone
  ZeroReserveInNoReserveZone
  OnlyOneActiveHVDCZoneForEachReserveClass
  ZeroSentHVDCFlowForNonSendingIsland
  RoundPowerZoneSentHVDCUpperLimit
  HVDCSendingIslandDefinition
  OnlyOneSendingIslandExists
  HVDCSentCalculation
  ExcessReserveSharePenalty
  ReserveShareEffective_CE_Calculation
  ReserveShareEffective_ECE_Calculation
* Lamda loss model NMIR
  HVDCFlowAccountedForForwardReserve
  ForwardReserveReceivedAtHVDCReceivingIsland
  HVDCFlowAccountedForReverseReserve
  ReverseReserveReceivedAtHVDCSendingIsland
  HVDCSentEnergyLambdaDefinition
  HVDCSentEnergyFlowDefinition
  HVDCSentEnergyLossesDefinition
  HVDCSentReserveLambdaDefinition
  HVDCSentReserveFlowDefinition
  HVDCSentReserveLossesDefinition
  / ;

Model vSPD_BranchFlowMIP /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, DemBidDefintion
  EnergyScarcityDefinition,
  GenerationRampUp, GenerationRampDown, GenerationChangeUpDown
* Network
  HVDClinkMaximumFlow, HVDClinkLossDefinition
  HVDClinkFlowDefinition, LambdaDefinition
  ACnodeNetInjectionDefinition1
  ACnodeNetInjectionDefinition2, ACBranchMaximumFlow
  ACBranchFlowDefinition, LinearLoadFlow
  ACBranchBlockLimit, ACDirectedBranchFlowDefinition
  ACBranchLossCalculation, ACDirectedBranchLossDefinition
  ACDirectedBranchFlowIntegerDefinition1, ACDirectedBranchFlowIntegerDefinition2
  LambdaIntegerDefinition1, LambdaIntegerDefinition2
* Risk
  RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
  HVDCIslandRiskCalculation, HVDCRecCalculation, ManualIslandRiskCalculation
  GenIslandRiskCalculation, GenIslandRiskCalculation_1
  GenIslandRiskGroupCalculation, GenIslandRiskGroupCalculation_1
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_GEN_1
  HVDCIslandSecRiskCalculation_Manual, HVDCIslandSecRiskCalculation_Manu_1
* Reserve
  PLSRReserveProportionMaximum, ReserveOfferDefinition
  EnergyAndReserveMaximum
* Reserve scarcity/shortfall
  HVDCRiskReserveShortFallCalculation
  ManualRiskReserveShortFallCalculation
  GenRiskReserveShortFallCalculation
  HVDCsecRiskReserveShortFallCalculation
  HVDCsecManualRiskReserveShortFallCalculation
  RiskGroupReserveShortFallCalculation
* Matching of reserve requirement and availability
  SupplyDemandReserveRequirement, IslandReserveCalculation
* Branch security constraints
  BranchSecurityConstraintLE
  BranchSecurityConstraintGE
  BranchSecurityConstraintEQ
* Market node security constraints
  MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
* ViolationCost
  SystemCostDefinition, SystemBenefitDefinition
  SystemPenaltyCostDefinition, TotalViolationCostDefinition
  TotalScarcityCostDefinition
* Set of intrger constraints on the HVDC link to incorporate the allowance of HVDC roundpower
  HVDClinkFlowIntegerDefinition1, HVDClinkFlowIntegerDefinition2
  HVDClinkFlowIntegerDefinition3, HVDClinkFlowIntegerDefinition4
* General NMIR equations
  EffectiveReserveShareCalculation
  SharedReserveLimitByClearedReserve
  BothClearedAndFreeReserveCanBeShared
  ReverseReserveShareLimitByHVDCControlBand
  ReserveShareSentLimitByHVDCControlBand
  FwdReserveShareSentLimitByHVDCCapacity
  ReverseReserveOnlyToEnergySendingIsland
  ForwardReserveOnlyToEnergyReceivingIsland
  ReverseReserveLimitInReserveZone
  ZeroReserveInNoReserveZone
  OnlyOneActiveHVDCZoneForEachReserveClass
  ZeroSentHVDCFlowForNonSendingIsland
  RoundPowerZoneSentHVDCUpperLimit
  HVDCSendingIslandDefinition
  OnlyOneSendingIslandExists
  HVDCSentCalculation
  ExcessReserveSharePenalty
  ReserveShareEffective_CE_Calculation
  ReserveShareEffective_ECE_Calculation
* Lamda loss model NMIR
  HVDCFlowAccountedForForwardReserve
  ForwardReserveReceivedAtHVDCReceivingIsland
  HVDCFlowAccountedForReverseReserve
  ReverseReserveReceivedAtHVDCSendingIsland
  HVDCSentEnergyLambdaDefinition
  HVDCSentEnergyFlowDefinition
  HVDCSentEnergyLossesDefinition
  HVDCSentReserveLambdaDefinition
  HVDCSentReserveFlowDefinition
  HVDCSentReserveLossesDefinition
  / ;

Model vSPD_FTR /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion
* Network
  HVDClinkMaximumFlow
  ACNodeNetInjectionDefinition1, ACNodeNetInjectionDefinition2
  ACBranchMaximumFlow, ACBranchFlowDefinition, LinearLoadFlow
* Branch security constraints
  BranchSecurityConstraintLE
  BranchSecurityConstraintGE
  BranchSecurityConstraintEQ
* ViolationCost
  SystemCostDefinition, SystemBenefitDefinition
  SystemPenaltyCostDefinition, TotalViolationCostDefinition
  TotalScarcityCostDefinition
  / ;
