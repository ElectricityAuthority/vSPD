*=====================================================================================
* Name:                 vSPDmodel.gms
* Function:             Mathematical formulation - based on the SPD formulation v7.0
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://reports.ea.govt.nz/EMIIntro.htm
* Contact:              emi@ea.govt.nz
* Last modified on:     21 May 2014
*=====================================================================================

$ontext
Directory of code sections in vSPDmodel.gms:
  1. Declare sets and parameters for all symbols to be loaded from daily GDX files
  2. Declare additional sets and parameters used throughout the model
  3. Declare model variables and constraints, and initialise constraints

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
  i_genericConstraint = gnrcCstr
$offtext


*===================================================================================
* 1. Declare sets and parameters for all symbols to be loaded from daily GDX files
*===================================================================================

Sets
* 22 hard-coded sets. Although these 22 sets exist in the vSPD input GDX file, they are not loaded from
* the GDX file. Rather, all but caseName are initialsed via hard-coding in vSPDsolve.gms prior to data
* being loaded from the GDX file. They are declared now because they're used in the domain of other symbols.
  caseName(*)                              'Final pricing case name used to create the GDX file'
  i_island(*)                              'Islands'
  i_tradeBlock(*)                          'Trade block definitions (or tranches) - used for the offer and bids'
  i_CVP(*)                                 'Constraint violation penalties used in the model'
  i_offerType(*)                           'Type of energy and reserve offers from market participants'
  i_offerParam(*)                          'The various parameters required for each offer'
  i_energyOfferComponent(*)                'Components of the energy offer - comprised of MW capacity and price by tradeBlock'
  i_PLSRofferComponent(*)                  'Components of the PLSR offer - comprised of MW proportion and price by tradeBlock'
  i_TWDRofferComponent(*)                  'Components of the TWDR offer - comprised of MW capacity and price by tradeBlock'
  i_ILRofferComponent(*)                   'Components of the ILR offer - comprised of MW capacity and price by tradeBlock'
  i_energyBidComponent(*)                  'Components of the energy bid - comprised of MW capacity and price by tradeBlock'
  i_ILRbidComponent(*)                     'Components of the ILR provided by bids'
  i_riskClass(*)                           'Different risks that could set the reserve requirements'
  i_reserveType(*)                         'Definition of the different reserve types (PLSR, TWDR, ILR)'
  i_reserveClass(*)                        'Definition of fast and sustained instantaneous reserve'
  i_riskParameter(*)                       'Different risk parameters that are specified as inputs to the dispatch model'
  i_branchParameter(*)                     'Branch parameter specified'
  i_lossSegment(*)                         'Loss segments available for loss modelling'
  i_lossParameter(*)                       'Components of the piecewise loss function'
  i_constraintRHS(*)                       'Constraint RHS definition'
  i_flowDirection(*)                       'Directional flow definition used in the SPD formulation'
  i_type1MixedConstraintRHS(*)             'Type 1 mixed constraint RHS definitions'
* 14 fundamental sets - membership is assigned when symbols are loaded from the GDX file in vSPDsolve.gms
  i_dateTime(*)                            'Date and time for the trade periods'
  i_tradePeriod(*)                         'Trade periods for which input data is defined'
  i_node(*)                                'Node definitions for all trading periods'
  i_offer(*)                               'Offers for all trading periods'
  i_trader(*)                              'Traders defined for all trading periods'
  i_bid(*)                                 'Bids for all trading periods'
  i_bus(*)                                 'Bus definitions for all trading periods'
  i_branch(*)                              'Branch definition for all trading periods'
  i_branchConstraint(*)                    'Branch constraint definitions for all trading periods'
  i_ACnodeConstraint(*)                    'AC node constraint definitions for all trading periods'
  i_MnodeConstraint(*)                     'Market node constraint definitions for all trading periods'
  i_type1MixedConstraint(*)                'Type 1 mixed constraint definitions for all trading periods'
  i_type2MixedConstraint(*)                'Type 2 mixed constraint definitions for all trading periods'
  i_genericConstraint(*)                   'Generic constraint names for all trading periods'
* Scarcity pricing updates
  i_scarcityArea(*)                'Area to which scarcity pricing may apply'
  ;

* Aliases
Alias (i_dateTime,dt),                      (i_tradePeriod,tp),                 (i_island,ild,ild1)
      (i_bus,b,b1,toB,frB),                 (i_node,n,n1),                      (i_offer,o,o1)
      (i_trader,trdr),                      (i_tradeBlock,trdBlk),              (i_branch,br,br1)
      (i_branchConstraint,brCstr),          (i_ACnodeConstraint,ACnodeCstr),    (i_MnodeConstraint,MnodeCstr)
      (i_energyOfferComponent,NRGofrCmpnt), (i_PLSRofferComponent,PLSofrCmpnt), (i_TWDRofferComponent,TWDofrCmpnt)
      (i_ILRofferComponent,ILofrCmpnt),     (i_energyBidComponent,NRGbidCmpnt), (i_ILRbidComponent,ILbidCmpnt)
      (i_type1MixedConstraint,t1MixCstr),   (i_type2MixedConstraint,t2MixCstr), (i_type1MixedConstraintRHS,t1MixCstrRHS),
      (i_genericConstraint,gnrcCstr),       (i_lossSegment,los,los1),           (i_scarcityArea,sarea) ;

Sets
* 16 multi-dimensional sets, subsets, and mapping sets - membership is populated via loading from GDX file in vSPDsolve.gms
  i_dateTimeTradePeriodMap(dt,tp)                                   'Mapping of dateTime set to the tradePeriod set'
  i_tradePeriodNode(tp,n)                                           'Node definition for the different trading periods'
  i_tradePeriodOfferNode(tp,o,n)                                    'Offers and the corresponding offer node for the different trading periods'
  i_tradePeriodOfferTrader(tp,o,trdr)                               'Offers and the corresponding trader for the different trading periods'
  i_tradePeriodBidNode(tp,i_bid,n)                                  'Bids and the corresponding node for the different trading periods'
  i_tradePeriodBidTrader(tp,i_bid,trdr)                             'Bids and the corresponding trader for the different trading periods'
  i_tradePeriodBus(tp,b)                                            'Bus definition for the different trading periods'
  i_tradePeriodNodeBus(tp,n,b)                                      'Node bus mapping for the different trading periods'
  i_tradePeriodBusIsland(tp,b,ild)                                  'Bus island mapping for the different trade periods'
  i_tradePeriodBranchDefn(tp,br,frB,toB)                            'Branch definition for the different trading periods'
  i_tradePeriodRiskGenerator(tp,o)                                  'Set of generators (offers) that can set the risk in the different trading periods'
  i_tradePeriodType1MixedConstraint(tp,t1MixCstr)                   'Set of mixed constraints defined for the different trading periods'
  i_tradePeriodType2MixedConstraint(tp,t2MixCstr)                   'Set of mixed constraints defined for the different trading periods'
  i_type1MixedConstraintReserveMap(t1MixCstr,ild,i_reserveClass,i_riskClass) 'Mapping of mixed constraint variables to reserve-related data'
  i_type1MixedConstraintBranchCondition(t1MixCstr,br)               'Set of mixed constraints that have limits conditional on branch flows'
  i_tradePeriodGenericConstraint(tp,gnrcCstr)                       'Generic constraints defined for the different trading periods'
* 1 set loaded from GDX with conditional load statement in vSPDsolve.gms at execution time
  i_tradePeriodPrimarySecondaryOffer(tp,o,o1)                       'Primary-secondary offer mapping for the different trading periods'
* MODD Modification
  i_tradePeriodDispatchableBid(tp,i_bid)                            'Set of dispatchable bids'
  ;


Parameters
* 6 scalars - values are loaded from GDX file in vSPDsolve.gms
  i_day                                                             'Day number (1..31)'
  i_month                                                           'Month number (1..12)'
  i_year                                                            'Year number (1900..2200)'
  i_tradingPeriodLength                                             'Length of the trading period in minutes (e.g. 30)'
  i_AClineUnit                                                      '0 = Actual values, 1 = per unit values on a 100MVA base'
  i_branchReceivingEndLossProportion                                'Proportion of losses to be allocated to the receiving end of a branch'
* 49 parameters - values are loaded from GDX file in vSPDsolve.gms
  i_StudyTradePeriod(tp)                                            'Trade periods that are to be studied'
  i_CVPvalues(i_CVP)                                                'Values for the constraint violation penalties'
* Offer data
  i_tradePeriodOfferParameter(tp,o,i_offerParam)                    'Initial MW for each offer for the different trading periods'
  i_tradePeriodEnergyOffer(tp,o,trdBlk,NRGofrCmpnt)                 'Energy offers for the different trading periods'
  i_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)          'Sustained (60s) PLSR offers for the different trading periods'
  i_tradePeriodFastPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)               'Fast (6s) PLSR offers for the different trading periods'
  i_tradePeriodSustainedTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)          'Sustained (60s) TWDR offers for the different trading periods'
  i_tradePeriodFastTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)               'Fast (6s) TWDR offers for the different trading periods'
  i_tradePeriodSustainedILRoffer(tp,o,trdBlk,ILofrCmpnt)            'Sustained (60s) ILR offers for the different trading periods'
  i_tradePeriodFastILRoffer(tp,o,trdBlk,ILofrCmpnt)                 'Fast (6s) ILR offers for the different trading periods'
* Demand data
  i_tradePeriodNodeDemand(tp,n)                                     'MW demand at each node for all trading periods'
* Bid data
  i_tradePeriodEnergyBid(tp,i_bid,trdBlk,NRGbidCmpnt)               'Energy bids for the different trading periods'
  i_tradePeriodSustainedILRbid(tp,i_bid,trdBlk,ILbidCmpnt)          'Sustained ILR bids for the different trading periods'
  i_tradePeriodFastILRbid(tp,i_bid,trdBlk,ILbidCmpnt)               'Fast ILR bids for the different trading periods'
* Network data
  i_tradePeriodHVDCNode(tp,n)                                       'HVDC node for the different trading periods'
  i_tradePeriodReferenceNode(tp,n)                                  'Reference nodes for the different trading periods'
  i_tradePeriodHVDCBranch(tp,br)                                    'HVDC branch indicator for the different trading periods'
  i_tradePeriodBranchParameter(tp,br,i_branchParameter)             'Branch resistance, reactance, fixed losses and number of loss tranches for the different time periods'
  i_tradePeriodBranchCapacity(tp,br)                                'Branch capacity for the different trading periods in MW'
  i_tradePeriodBranchOpenStatus(tp,br)                              'Branch open status for the different trading periods, 1 = Open'
  i_noLossBranch(los,i_lossParameter)                               'Loss parameters for no loss branches'
  i_AClossBranch(los,i_lossParameter)                               'Loss parameters for AC loss branches'
  i_HVDClossBranch(los,i_lossParameter)                             'Loss parameters for HVDC loss branches'
  i_tradePeriodNodeBusAllocationFactor(tp,n,b)                      'Allocation factor of market node quantities to bus for the different trading periods'
  i_tradePeriodBusElectricalIsland(tp,b)                            'Electrical island status of each bus for the different trading periods (0 = Dead)'
* Risk/Reserve data
  i_tradePeriodRiskParameter(tp,ild,i_reserveClass,i_riskClass,i_riskParameter) 'Risk parameters for the different trading periods (From RMT)'
  i_tradePeriodManualRisk(tp,ild,i_reserveClass)                                'Manual risk set for the different trading periods'
* Branch constraint data
  i_tradePeriodBranchConstraintFactors(tp,brCstr,br)                'Branch constraint factors (sensitivities) for the different trading periods'
  i_tradePeriodBranchConstraintRHS(tp,brCstr,i_constraintRHS)       'Branch constraint sense and limit for the different trading periods'
* AC node constraint data
  i_tradePeriodACnodeConstraintFactors(tp,ACnodeCstr,n)             'AC node constraint factors (sensitivities) for the different trading periods'
  i_tradePeriodACnodeConstraintRHS(tp,ACnodeCstr,i_constraintRHS)   'AC node constraint sense and limit for the different trading periods'
* Market node constraint data
  i_tradePeriodMNodeEnergyOfferConstraintFactors(tp,MnodeCstr,o)                               'Market node energy offer constraint factors for the different trading periods'
  i_tradePeriodMNodeReserveOfferConstraintFactors(tp,MnodeCstr,o,i_reserveClass,i_reserveType) 'Market node reserve offer constraint factors for the different trading periods'
  i_tradePeriodMNodeEnergyBidConstraintFactors(tp,MnodeCstr,i_bid)                             'Market node energy bid constraint factors for the different trading periods'
  i_tradePeriodMNodeILReserveBidConstraintFactors(tp,MnodeCstr,i_bid,i_reserveClass)           'Market node IL reserve bid constraint factors for the different trading periods'
  i_tradePeriodMNodeConstraintRHS(tp,MnodeCstr,i_constraintRHS)                                'Market node constraint sense and limit for the different trading periods'
* Mixed constraint data
  i_type1MixedConstraintVarWeight(t1MixCstr)                                                   'Type 1 mixed constraint variable weights'
  i_type1MixedConstraintGenWeight(t1MixCstr,o)                                                 'Type 1 mixed constraint generator weights'
  i_type1MixedConstraintResWeight(t1MixCstr,o,i_reserveClass,i_reserveType)                    'Type 1 mixed constraint reserve weights'
  i_type1MixedConstraintHVDClineWeight(t1MixCstr,br)                                           'Type 1 mixed constraint HVDC branch flow weights'
  i_tradePeriodType1MixedConstraintRHSParameters(tp,t1MixCstr,t1MixCstrRHS)                    'Type 1 mixed constraint RHS parameters'
  i_type2MixedConstraintLHSParameters(t2MixCstr,t1MixCstr)                                     'Type 2 mixed constraint LHS weights'
  i_tradePeriodType2MixedConstraintRHSParameters(tp,t2MixCstr,i_constraintRHS)                 'Type 2 mixed constraint RHS parameters'
* Generic constraint data
  i_tradePeriodGenericEnergyOfferConstraintFactors(tp,gnrcCstr,o)                              'Generic constraint offer constraint factors for the different trading periods'
  i_tradePeriodGenericReserveOfferConstraintFactors(tp,gnrcCstr,o,i_reserveClass,i_reserveType)'Generic constraint reserve offer constraint factors for the different trading periods'
  i_tradePeriodGenericEnergyBidConstraintFactors(tp,gnrcCstr,i_bid)                            'Generic constraint energy bid constraint factors for the different trading periods'
  i_tradePeriodGenericILReserveBidConstraintFactors(tp,gnrcCstr,i_bid,i_reserveClass)          'Generic constraint IL reserve bid constraint factors for the different trading periods'
  i_tradePeriodGenericBranchConstraintFactors(tp,gnrcCstr,br)                                  'Generic constraint energy offer constraint factors for the different trading periods'
  i_tradePeriodGenericConstraintRHS(tp,gnrcCstr,i_constraintRHS)                               'Generic constraint sense and limit for the different trading periods'
* 11 parameters loaded from GDX with conditional load statement at execution time
  i_tradePeriodAllowHVDCRoundpower(tp)                              'Flag to allow roundpower on the HVDC (1 = Yes)'
  i_tradePeriodManualRisk_ECE(tp,ild,i_reserveClass)                'Manual ECE risk set for the different trading periods'
  i_tradePeriodHVDCSecRiskEnabled(tp,ild,i_riskClass)               'Flag indicating if the HVDC secondary risk is enabled (1 = Yes)'
  i_tradePeriodHVDCSecRiskSubtractor(tp,ild)                        'Ramp up capability on the HVDC pole that is not the secondary risk'
  i_type1MixedConstraintAClineWeight(t1MixCstr,br)                  'Type 1 mixed constraint AC branch flow weights'
  i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)              'Type 1 mixed constraint AC branch loss weights'
  i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)         'Type 1 mixed constraint AC branch fixed losses weight'
  i_type1MixedConstraintHVDClineLossWeight(t1MixCstr,br)            'Type 1 mixed constraint HVDC branch loss weights'
  i_type1MixedConstraintHVDClineFixedLossWeight(t1MixCstr,br)       'Type 1 mixed constraint HVDC branch fixed losses weight'
  i_type1MixedConstraintPurWeight(t1MixCstr,i_bid)                  'Type 1 mixed constraint demand bid weights'
  i_tradePeriodReserveClassGenerationMaximum(tp,o,i_reserveClass)   'MW used to determine factor to adjust maximum reserve of a reserve class'
* Scarcity pricing updates
 i_tradePeriodVROfferMax(tp,ild,i_reserveClass)         'Maximum MW of the virtual reserve offer'
 i_tradePeriodVROfferPrice(tp,ild,i_reserveClass)       'Price of the virtual reserve offer'

 i_tradePeriodScarcitySituationExists(tp,sarea)         'Flag to indicate that a scarcity situation exists (1 = Yes)'
 i_tradePeriodGWAPFloor(tp,sarea)                       'Floor price for the scarcity situation in scarcity area'
 i_tradePeriodGWAPCeiling(tp,sarea)                     'Ceiling price for the scarcity situation in scarcity area'
 i_tradePeriodGWAPPastDaysAvg(tp,ild)                   'Average GWAP over past days - number of periods in GWAP count'
 i_tradePeriodGWAPCountForAvg(tp,ild)                   'Number of periods used for the i_gwapPastDaysAvg'
 i_tradePeriodGWAPThreshold(tp,ild)                     'Threshold on previous 336 trading period GWAP - cumulative price threshold'
  ;

* End of GDX declarations



*===================================================================================
* 2. Declare additional sets and parameters used throughout the model
*===================================================================================

Scalars
  sequentialSolve
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
  suppressMixedConstraint                  'Suppress use of the mixed constraint formulation (1 = suppress)'
  mixedMIPtolerance
  LPtimeLimit                              'CPU seconds allowed for LP solves'
  LPiterationLimit                         'Iteration limit allowed for LP solves'
  MIPtimeLimit                             'CPU seconds allowed for MIP solves'
  MIPiterationLimit                        'Iteration limit allowed for MIP solves'
  MIPoptimality
  disconnectedNodePriceCorrection
  useExternalLossModel
  lossCoeff_A
  lossCoeff_C
  lossCoeff_D
  lossCoeff_E
  lossCoeff_F
  maxFlowSegment
  opMode
  tradePeriodReports
  ;

Sets
* Global
  pole                                                              'HVDC poles'
  currTP(tp)                                                        'Current trading period'
* Offer
  offer(tp,o)                                                       'Offers defined for the current trading period'
  offerNode(tp,o,n)                                                 'Mapping of the offers to the nodes for the current trading period'
  validGenerationOfferBlock(tp,o,trdBlk)                            'Valid trade blocks for the respective generation offers'
  validReserveOfferBlock(tp,o,trdBlk,i_reserveClass,i_reserveType)  'Valid trade blocks for the respective reserve offers by class and type'
  PreviousMW(o)                                                     'MW output of offer to be used as initial MW of the next trading period if necessary'
  PositiveEnergyOffer(tp,o)                                         'Postive energy offers defined for the current trading period'
* Set for primary secondary offers
  PrimarySecondaryOffer(tp,o,o1)                                    'Primary-secondary offer mapping for the current trading period'
* Bid
  Bid(tp,i_bid)                                                     'Bids defined for the current trading period'
  BidNode(tp,i_bid,n)                                               'Mapping of the bids to the nodes for the current trading period'
  validPurchaseBidBlock(tp,i_bid,trdBlk)                            'Valid trade blocks for the respective purchase bids'
  validPurchaseBidILRBlock(tp,i_bid,trdBlk,i_reserveClass)          'Valid trade blocks for the respective purchase bids ILR'
* Network
  Node(tp,n)                                                        'Nodes defined for the current trading period'
  Bus(tp,b)                                                         'Buses defined for the current trading period'
  NodeBus(tp,n,b)                                                   'Mapping of the nodes to the buses for the current trading period'
  NodeIsland(tp,n,ild)                                              'Mapping of the node to the island for the current trading period'
  BusIsland(tp,b,ild)                                               'Mapping of the bus to the island for the current trading period'
  HVDCNode(tp,n)                                                    'HVDC node for the current trading period'
  ACnode(tp,n)                                                      'AC nodes for the current trading period'
  ReferenceNode(tp,n)                                               'Reference node for the current trading period'
  DCBus(tp,b)                                                       'Buses corresponding to HVDC nodes'
  ACBus(tp,b)                                                       'Buses corresponding to AC nodes'
  Branch(tp,br)                                                     'Branches defined for the current trading period'
  BranchBusDefn(tp,br,frB,toB)                                      'Branch bus connectivity for the current trading period'
  BranchBusConnect(tp,br,b)                                         'Indication if a branch is connected to a bus for the current trading period'
  ACBranchSendingBus(tp,br,b,i_flowDirection)                       'Sending (From) bus of AC branch in forward and backward direction'
  ACBranchReceivingBus(tp,br,b,i_flowDirection)                     'Receiving (To) bus of AC branch in forward and backward direction'
  HVDClinkSendingBus(tp,br,b)                                       'Sending (From) bus of HVDC link'
  HVDClinkReceivingBus(tp,br,toB)                                   'Receiving (To) bus of HVDC link'
  HVDClinkBus(tp,br,b)                                              'Sending or Receiving bus of HVDC link'
  HVDClink(tp,br)                                                   'HVDC links (branches) defined for the current trading period'
  HVDCpoles(tp,br)                                                  'DC transmission between Benmore and Hayward'
  HVDCHalfPoles(tp,br)                                              'Connection DC Pole 1 between AC and DC systems at Benmore and Haywards'
  HVDCpoleDirection(tp,br,i_flowDirection)                          'Direction defintion for HVDC poles S->N : Forward and N->S : Southward'
  ACBranch(tp,br)                                                   'AC branches defined for the current trading period'
  ClosedBranch(tp,br)                                               'Set of branches that are closed'
  OpenBranch(tp,br)                                                 'Set of branches that are open'
  validLossSegment(tp,br,los)                                       'Valid loss segments for a branch'
  lossBranch(tp,br)                                                 'Subset of branches that have non-zero loss factors'
* Mapping set of branches to HVDC pole
  HVDCpoleBranchMap(pole,br)                                        'Mapping of HVDC  branch to pole number'
* Risk/Reserve
  RiskGenerator(tp,o)                                               'Set of generators that can set the risk in the current trading period'
  islandRiskGenerator(tp,ild,o)                                     'Mapping of risk generator to island in the current trading period'
  HVDCrisk(i_riskClass)                                             'Subset containing DCCE and DCECE risks'
  GenRisk(i_riskClass)                                              'Subset containing generator risks'
  ManualRisk(i_riskClass)                                           'Subset containting manual risks'
* Allow for the HVDC secondary risks
  HVDCSecRisk(i_riskClass)                                          'Subset containing secondary risk of the HVDC for CE and ECE events'
  PLSRReserveType(i_reserveType)                                    'PLSR reserve type'
  TWDRReserveType(i_reserveType)                                    'TWDR reserve type'
  ILReserveType(i_reserveType)                                      'IL reserve type'
  IslandOffer(tp,ild,o)                                             'Mapping of reserve offer to island for the current trading period'
  IslandBid(tp,ild,i_bid)                                           'Mapping of purchase bid ILR to island for the current trading period'
* Definition of CE and ECE events to support different CE and ECE CVPs
  ContingentEvents(i_riskClass)                                     'Subset of Risk Classes containing contigent event risks'
  ExtendedContingentEvent(i_riskClass)                              'Subset of Risk Classes containing extended contigent event risk'
* Branch constraint
  BranchConstraint(tp,brCstr)                                       'Set of branch constraints defined for the current trading period'
* AC node constraint
  ACnodeConstraint(tp,ACnodeCstr)                                   'Set of AC node constraints defined for the current trading period'
* Market node constraint
  MNodeConstraint(tp,MnodeCstr)                                     'Set of market node constraints defined for the current trading period'
* Mixed constraint
  Type1MixedConstraint(tp,t1MixCstr)                                'Set of type 1 mixed constraints defined for the current trading period'
  Type2MixedConstraint(tp,t2MixCstr)                                'Set of type 2 mixed constraints defined for the current trading period'
  Type1MixedConstraintCondition(tp,t1MixCstr)                       'Subset of type 1 mixed constraints that have a condition to check for the use of the alternate limit'
* Generic constraint
  GenericConstraint(tp,gnrcCstr)                                    'Generic constraint defined for the current trading period'
  ;

Parameters
* Offers
  RampRateUp(tp,o)                                                  'The ramping up rate in MW per minute associated with the generation offer (MW/min)'
  RampRateDown(tp,o)                                                'The ramping down rate in MW per minute associated with the generation offer (MW/min)'
  GenerationStart(tp,o)                                             'The MW generation level associated with the offer at the start of a trading period'
  ReserveGenerationMaximum(tp,o)                                    'Maximum generation and reserve capability for the current trading period (MW)'
  WindOffer(tp,o)                                                   'Flag to indicate if offer is from wind generator (1 = Yes)'
* Primary-secondary offer parameters
  HasSecondaryOffer(tp,o)                                           'Flag to indicate if offer has a secondary offer (1 = Yes)'
  HasPrimaryOffer(tp,o)                                             'Flag to indicate if offer has a primary offer (1 = Yes)'
* Frequency keeper band MW
  FKBand(tp,o)                                                      'Frequency keeper band MW which is set when the risk setter is selected as the frequency keeper'
  GenerationMaximum(tp,o)                                           'Maximum generation level associated with the generation offer (MW)'
  GenerationMinimum(tp,o)                                           'Minimum generation level associated with the generation offer (MW)'
  GenerationEndUp(tp,o)                                             'MW generation level associated with the offer at the end of the trading period assuming ramp rate up'
  GenerationEndDown(tp,o)                                           'MW generation level associated with the offer at the end of the trading period assuming ramp rate down'
  RampTimeUp(tp,o)                                                  'Minimum of the trading period length and time to ramp up to maximum (Minutes)'
  RampTimeDown(tp,o)                                                'Minimum of the trading period length and time to ramp down to minimum (Minutes)'
* Energy offer
  GenerationOfferMW(tp,o,trdBlk)                                    'Generation offer block (MW)'
  GenerationOfferPrice(tp,o,trdBlk)                                 'Generation offer price ($/MW)'
* Reserve offer
  ReserveOfferProportion(tp,o,trdBlk,i_reserveClass)                'The percentage of the MW block available for PLSR of class FIR or SIR'
  ReserveOfferPrice(tp,o,trdBlk,i_reserveClass,i_reserveType)       'The price of the reserve of the different reserve classes and types ($/MW)'
  ReserveOfferMaximum(tp,o,trdBlk,i_reserveClass,i_reserveType)     'The maximum MW offered reserve for the different reserve classes and types (MW)'
* Demand
  NodeDemand(tp,n)                                                  'Nodal demand for the current trading period in MW'
* Bid
  PurchaseBidMW(tp,i_bid,trdBlk)                                    'Purchase bid block in MW'
  PurchaseBidPrice(tp,i_bid,trdBlk)                                 'Purchase bid price in $/MW'
  PurchaseBidILRMW(tp,i_bid,trdBlk,i_reserveClass)                  'Purchase bid ILR block in MW for the different reserve classes'
  PurchaseBidILRPrice(tp,i_bid,trdBlk,i_reserveClass)               'Purchase bid ILR price in $/MW for the different reserve classes'
* Network
  ACBranchCapacity(tp,br)                                           'MW capacity of AC branch for the current trading period'
  ACBranchResistance(tp,br)                                         'Resistance of the AC branch for the current trading period in per unit'
  ACBranchSusceptance(tp,br)                                        'Susceptance (inverse of reactance) of the AC branch for the current trading period in per unit'
  ACBranchFixedLoss(tp,br)                                          'Fixed loss of the AC branch for the current trading period in MW'
  ACBranchLossBlocks(tp,br)                                         'Number of blocks in the loss curve for the AC branch in the current trading period'
  ACBranchLossMW(tp,br,los)                                         'MW element of the loss segment curve in MW'
  ACBranchLossFactor(tp,br,los)                                     'Loss factor element of the loss segment curve'

  HVDClinkCapacity(tp,br)                                           'MW capacity of the HVDC link for the current trading period'
  HVDClinkResistance(tp,br)                                         'Resistance of the HVDC link for the current trading period in Ohms'
  HVDClinkFixedLoss(tp,br)                                          'Fixed loss of the HVDC link for the current trading period in MW'
  HVDClinkLossBlocks(tp,br)                                         'Number of blocks in the loss curve for the HVDC link in the current trading period'
  HVDCBreakPointMWFlow(tp,br,los)                                   'Value of power flow on the HVDC at the break point'
  HVDCBreakPointMWLoss(tp,br,los)                                   'Value of variable losses on the HVDC at the break point'

  lossSegmentMW(tp,br,los)                                          'MW capacity of each loss segment'
  lossSegmentFactor(tp,br,los)                                      'Loss factor of each loss segment'

  NodeBusAllocationFactor(tp,n,b)                                   'Allocation factor of market node to bus for the current trade period'
  BusElectricalIsland(tp,b)                                         'Bus electrical island status for the current trade period (0 = Dead)'
* Flag to allow roundpower on the HVDC link
  AllowHVDCRoundpower(tp)                                           'Flag to allow roundpower on the HVDC (1 = Yes)'
* Risk/Reserve
  ReserveClassGenerationMaximum(tp,o,i_reserveClass)                'MW used to determine factor to adjust maximum reserve of a reserve class'
  ReserveMaximumFactor(tp,o,i_reserveClass)                         'Factor to adjust the maximum reserve of the different classes for the different offers'
  IslandRiskAdjustmentFactor(tp,ild,i_reserveClass,i_riskClass)     'Risk adjustment factor for each island, reserve class and risk class'
  FreeReserve(tp,ild,i_reserveClass,i_riskClass)                    'MW free reserve for each island, reserve class and risk class'
  HVDCpoleRampUp(tp,ild,i_reserveClass,i_riskClass)                 'HVDC pole MW ramp up capability for each island, reserve class and risk class'
  IslandMinimumRisk(tp,ild,i_reserveClass,i_riskClass)              'Minimum MW risk level for each island for each reserve class and risk class'
* RDN - HVDC secondary risk parameters
  HVDCSecRiskEnabled(tp,ild,i_riskClass)                            'Flag indicating if the HVDC secondary risk is enabled (1 = Yes)'
  HVDCSecRiskSubtractor(tp,ild)                                     'Ramp up capability on the HVDC pole that is not the secondary risk'
  HVDCSecIslandMinimumRisk(tp,ild,i_reserveClass,i_riskClass)       'Minimum risk in each island for the HVDC secondary risk'
* Branch constraint
  BranchConstraintFactors(tp,brCstr,br)                             'Branch security constraint factors (sensitivities) for the current trading period'
  BranchConstraintSense(tp,brCstr)                                  'Branch security constraint sense for the current trading period (-1:<=, 0:= 1:>=)'
  BranchConstraintLimit(tp,brCstr)                                  'Branch security constraint limit for the current trading period'
* AC node constraint
  ACnodeConstraintFactors(tp,ACnodeCstr,n)                          'AC node security constraint factors (sensitivities) for the current trading period'
  ACnodeConstraintSense(tp,ACnodeCstr)                              'AC node security constraint sense for the current trading period (-1:<=, 0:= 1:>=)'
  ACnodeConstraintLimit(tp,ACnodeCstr)                              'AC node security constraint limit for the current trading period'
* Market node constraint
  MNodeEnergyOfferConstraintFactors(tp,MnodeCstr,o)                               'Market node energy offer constraint factors for the current trading period'
  MNodeReserveOfferConstraintFactors(tp,MnodeCstr,o,i_reserveClass,i_reserveType) 'Market node reserve offer constraint factors for the current trading period'
  MNodeEnergyBidConstraintFactors(tp,MnodeCstr,i_bid)                             'Market node energy bid constraint factors for the current trading period'
  MNodeILReserveBidConstraintFactors(tp,MnodeCstr,i_bid,i_reserveClass)           'Market node IL reserve bid constraint factors for the current trading period'
  MNodeConstraintSense(tp,MnodeCstr)                                              'Market node constraint sense for the current trading period'
  MNodeConstraintLimit(tp,MnodeCstr)                                              'Market node constraint limit for the current trading period'
* Mixed constraint
  useMixedConstraint(tp)                                                          'Flag indicating use of the mixed constraint formulation (1 = Yes)'
  Type1MixedConstraintSense(tp,t1MixCstr)                                         'Type 1 mixed constraint sense'
  Type1MixedConstraintLimit1(tp,t1MixCstr)                                        'Type 1 mixed constraint limit 1'
  Type1MixedConstraintLimit2(tp,t1MixCstr)                                        'Type 1 mixed constraint alternate limit (limit 2)'
  Type2MixedConstraintSense(tp,t2MixCstr)                                         'Type 2 mixed constraint sense'
  Type2MixedConstraintLimit(tp,t2MixCstr)                                         'Type 2 mixed constraint limit'
* Generic constraint
  GenericEnergyOfferConstraintFactors(tp,gnrcCstr,o)                              'Generic constraint energy offer factors for the current trading period'
  GenericReserveOfferConstraintFactors(tp,gnrcCstr,o,i_reserveClass,i_reserveType)'Generic constraint reserve offer factors for the current trading period'
  GenericEnergyBidConstraintFactors(tp,gnrcCstr,i_bid)                            'Generic constraint energy bid factors for the current trading period'
  GenericILReserveBidConstraintFactors(tp,gnrcCstr,i_bid,i_reserveClass)          'Generic constraint IL reserve bid factors for the current trading period'
  GenericBranchConstraintFactors(tp,gnrcCstr,br)                                  'Generic constraint branch factors for the current trading period'
  GenericConstraintSense(tp,gnrcCstr)                                             'Generic constraint sense for the current trading period'
  GenericConstraintLimit(tp,gnrcCstr)                                             'Generic constraint limit for the current trading period'
* Violation penalties
  DeficitReservePenalty(i_reserveClass)            '6s and 60s reserve deficit violation penalty'
* Different CVPs defined for CE and ECE
  DeficitReservePenalty_CE(i_reserveClass)         '6s and 60s CE reserve deficit violation penalty'
  DeficitReservePenalty_ECE(i_reserveClass)        '6s and 60s ECE reserve deficit violation penalty'
* Post-processing
  useBranchFlowMIP(tp)                             'Flag to indicate if integer constraints are needed in the branch flow model: 1 = Yes'
  useMixedConstraintMIP(tp)                        'Flag to indicate if integer constraints are needed in the mixed constraint formulation: 1 = Yes'
* Scarcity pricing updates
  virtualReserveMax(tp,ild,i_reserveClass)         'Maximum MW of virtual reserve offer in each island for each reserve class'
  virtualReservePrice(tp,ild,i_reserveClass)       'Price of virtual reserve offer in each island for each reserve class'

  scarcitySituationExists(tp,sarea)                'Flag to indicate that a scarcity situation exists (1 = Yes)'
  GWAPFloor(tp,sarea)                              'Floor price for the scarcity situation in scarcity area'
  GWAPCeiling(tp,sarea)                            'Ceiling price for the scarcity situation in scarcity area'
  GWAPPastDaysAvg(tp,ild)                          'Average GWAP over past days - number of periods in GWAP count'
  GWAPCountForAvg(tp,ild)                          'Number of periods used for the i_gwapPastDaysAvg'
  GWAPThreshold(tp,ild)                            'Threshold on previous 336 trading period GWAP - cumulative price threshold'

  nodeGeneration(tp,n)                             'Nodal generation used for scarcity GWAP calculations'
  nodePrice(tp,n)                                  'Nodal price used for scarcity GWAP calculations'

  islandGWAP(tp,ild)                               'Island GWAP calculation used to update GWAPPastDaysAvg'
  scarcityAreaGWAP(tp,sarea)                       'Scarcity area GWAP used to calculate the scaling factor'
  ;

Scalars
* Violation penalties
* These violation penalties are not specified in the model formulation document (ver.4.3) but are specified in the
* document "Resolving Infeasibilities & High Spring Washer Price situations - an overview" available at www.systemoperator.co.nz/n2766,264.html
  deficitBusGenerationPenalty                      'Bus deficit violation penalty'
  surplusBusGenerationPenalty                      'Bus surplus violation penalty'
  deficitBranchGroupConstraintPenalty              'Deficit branch group constraint violation penalty'
  surplusBranchGroupConstraintPenalty              'Surplus branch group constraint violation penalty'
  DeficitGenericConstraintPenalty                  'Deficit generic constraint violation penalty'
  SurplusGenericConstraintPenalty                  'Surplus generic constraint violation penalty'
  DeficitRampRatePenalty                           'Deficit ramp rate violation penalty'
  SurplusRampRatePenalty                           'Surplus ramp rate violation penalty'
  DeficitACnodeConstraintPenalty                   'AC node constraint deficit penalty'
  SurplusACnodeConstraintPenalty                   'AC node constraint surplus penalty'
  deficitBranchFlowPenalty                         'Deficit branch flow violation penalty'
  surplusBranchFlowPenalty                         'Surplus branch flow violation penalty'
  DeficitMnodeConstraintPenalty                    'Deficit market node constraint violation penalty'
  SurplusMnodeConstraintPenalty                    'Surplus market node constraint violation penalty'
  Type1DeficitMixedConstraintPenalty               'Type 1 deficit mixed constraint violation penalty'
  Type1SurplusMixedConstraintPenalty               'Type 1 surplus mixed constraint violation penalty'
* Mixed constraint
  MixedConstraintBigNumber                         'Big number used in the definition of the integer variables for mixed constraints'   /1000 /
  useMixedConstraintRiskOffset                     'Use the risk offset calculation based on mixed constraint formulation (1= Yes)'
* Separate flag for the CE and ECE CVP
  DiffCeECeCVP                                     'Flag to indicate if the separate CE and ECE CVP is applied'
  usePrimSecGenRiskModel                           'Flag to use the revised generator risk model for generators with primary and secondary offers'
  useDSBFDemandBidModel                            'Flag to use the demand model defined under demand-side bidding and forecasting (DSBF)'

* Scarcity pricing updates
  scarcityExists                                  'Flag to indicate that a scarcity situation exists for at least 1 trading period in the solve'
  ;


*===================================================================================
* 3. Declare model variables and constraints, and initialise constraints
*=================================================================== ================

* VARIABLES - UPPER CASE
* Equations, parameters and everything else - lower or mixed case

* Model formulation originally based on the SPD model formulation version 4.3 (15 Feb 2008) and amended as indicated

Variables
  NETBENEFIT                                       'Defined as the difference between the consumer surplus and producer costs adjusted for penalty costs'
* Reserves
  ISLANDRISK(tp,ild,i_reserveClass,i_riskClass)    'Island MW risk for the different reserve and risk classes'
  HVDCREC(tp,ild)                                  'Total net pre-contingent HVDC MW flow received at each island'
  RISKOFFSET(tp,ild,i_reserveClass,i_riskClass)    'MW offset applied to the raw risk to account for HVDC pole rampup, AUFLS, free reserve and non-compliant generation'
* Network
  ACNODENETINJECTION(tp,b)                         'MW injection at buses corresponding to AC nodes'
  ACBRANCHFLOW(tp,br)                              'MW flow on undirected AC branch'
  ACNODEANGLE(tp,b)                                'Bus voltage angle'
* Mixed constraint variables
  MIXEDCONSTRAINTVARIABLE(tp,t1MixCstr)            'Mixed constraint variable'

* Demand bids can be either positive or negative from v6.0 of SPD formulation (with DSBF)
* The lower bound of the free variable is updated in vSPDSolve.gms to allow backward compatibility
* Note the formulation now refers to this as Demand. So Demand (in SPD formulation) = Purchase (in vSPD code)
  PURCHASE(tp,i_bid)                               'Total MW purchase scheduled'
  PURCHASEBLOCK(tp,i_bid,trdBlk)                   'MW purchase scheduled from the individual trade blocks of a bid'

  ;

Positive variables
* Generation
  GENERATION(tp,o)                                       'Total MW generation scheduled from an offer'
  GENERATIONBLOCK(tp,o,trdBlk)                           'MW generation scheduled from the individual trade blocks of an offer'
* Purchase
  PURCHASEILR(tp,i_bid,i_reserveClass)                   'Total MW ILR provided by purchase bid for the different reserve classes'
  PURCHASEILRBLOCK(tp,i_bid,trdBlk,i_reserveClass)       'MW ILR provided by purchase bid for individual trade blocks for the different reserve classes'
* Reserve
  RESERVE(tp,o,i_reserveClass,i_reserveType)             'MW Reserve scheduled from an offer'
  RESERVEBLOCK(tp,o,trdBlk,i_reserveClass,i_reserveType) 'MW Reserve scheduled from the individual trade blocks of an offer'
  MAXISLANDRISK(tp,ild,i_reserveClass)                   'Maximum MW island risk for the different reserve classes'
* Network
  HVDCLINKFLOW(tp,br)                                    'MW flow at the sending end scheduled for the HVDC link'
  HVDCLINKLOSSES(tp,br)                                  'MW losses on the HVDC link'
  LAMBDA(tp,br,los)                                      'Non-negative weight applied to the breakpoint of the HVDC link'
  ACBRANCHFLOWDIRECTED(tp,br,i_flowDirection)            'MW flow on the directed branch'
  ACBRANCHLOSSESDIRECTED(tp,br,i_flowDirection)          'MW losses on the directed branch'
  ACBRANCHFLOWBLOCKDIRECTED(tp,br,los,i_flowDirection)   'MW flow on the different blocks of the loss curve'
  ACBRANCHLOSSESBLOCKDIRECTED(tp,br,los,i_flowDirection) 'MW losses on the different blocks of the loss curve'
* Violations
  TOTALPENALTYCOST                                 'Total violation costs'
  DEFICITBUSGENERATION(tp,b)                       'Deficit generation at a bus in MW'
  SURPLUSBUSGENERATION(tp,b)                       'Surplus generation at a bus in MW'
  DEFICITRESERVE(tp,ild,i_reserveClass)            'Deficit reserve generation in each island for each reserve class in MW'
  DEFICITBRANCHSECURITYCONSTRAINT(tp,brCstr)       'Deficit branch security constraint in MW'
  SURPLUSBRANCHSECURITYCONSTRAINT(tp,brCstr)       'Surplus branch security constraint in MW'
  DEFICITRAMPRATE(tp,o)                            'Deficit ramp rate in MW'
  SURPLUSRAMPRATE(tp,o)                            'Surplus ramp rate in MW'
  DEFICITACnodeCONSTRAINT(tp,ACnodeCstr)           'Deficit in AC node constraint in MW'
  SURPLUSACnodeCONSTRAINT(tp,ACnodeCstr)           'Surplus in AC node constraint in MW'
  DEFICITBRANCHFLOW(tp,br)                         'Deficit branch flow in MW'
  SURPLUSBRANCHFLOW(tp,br)                         'Surplus branch flow in MW'
  DEFICITMNODECONSTRAINT(tp,MnodeCstr)             'Deficit market node constraint in MW'
  SURPLUSMNODECONSTRAINT(tp,MnodeCstr)             'Surplus market node constraint in MW'
  DEFICITTYPE1MIXEDCONSTRAINT(tp,t1MixCstr)        'Type 1 deficit mixed constraint in MW'
  SURPLUSTYPE1MIXEDCONSTRAINT(tp,t1MixCstr)        'Type 1 surplus mixed constraint in MW'
  SURPLUSGENERICCONSTRAINT(tp,gnrcCstr)            'Surplus generic constraint in MW'
  DEFICITGENERICCONSTRAINT(tp,gnrcCstr)            'Deficit generic constraint in MW'
* Seperate CE and ECE violation variables to support different CVPs for CE and ECE
  DEFICITRESERVE_CE(tp,ild,i_reserveClass)         'Deficit CE reserve generation in each island for each reserve class in MW'
  DEFICITRESERVE_ECE(tp,ild,i_reserveClass)        'Deficit ECE reserve generation in each island for each reserve class in MW'
* Scarcity pricing updates
  VIRTUALRESERVE(tp,ild,i_reserveClass)            'MW scheduled from virtual reserve'
  ;

Binary variables
  MIXEDCONSTRAINTLIMIT2SELECT(tp,t1MixCstr)        'Binary decision variable used to detect if limit 2 should be selected for mixed constraints'
  ;

SOS1 Variables
  ACBRANCHFLOWDIRECTED_INTEGER(tp,br,i_flowDirection)'Integer variables used to select branch flow direction in the event of circular branch flows (3.8.1)'
  HVDCLINKFLOWDIRECTION_INTEGER(tp,i_flowDirection)'Integer variables used to select the HVDC branch flow direction on in the event of S->N (forward) and N->S (reverse) flows (3.8.2)'
* Integer varaible to prevent intra-pole circulating branch flows
  HVDCPOLEFLOW_INTEGER(tp,pole,i_flowDirection)    'Integer variables used to select the HVDC pole flow direction on in the event of circulating branch flows within a pole'
  ;

SOS2 Variables
  LAMBDAINTEGER(tp,br,los)                         'Integer variables used to enforce the piecewise linear loss approxiamtion on the HVDC links'
  ;

Equations
  ObjectiveFunction                                'Objective function of the dispatch model (4.1.1.1)'
* Offer and purchase definitions
  GenerationOfferDefintion(tp,o)                   'Definition of generation provided by an offer (3.1.1.2)'
  GenerationRampUp(tp,o)                           'Maximum movement of the generator upwards due to up ramp rate (3.7.1.1)'
  GenerationRampDown(tp,o)                         'Maximum movement of the generator downwards due to down ramp rate (3.7.1.2)'
* Primary-secondary ramp constraints
  GenerationRampUp_PS(tp,o)                        'Maximum movement of the primary-secondary offers upwards due to up ramp rate (3.7.1.1)'
  GenerationRampDown_PS(tp,o)                      'Maximum movement of the primary-secondary offers downwards due to down ramp rate (3.7.1.2)'
  PurchaseBidDefintion(tp,i_bid)                   'Definition of purchase provided by a bid (3.1.1.5)'
* Change to demand bids - End
* Network
  HVDClinkMaximumFlow(tp,br)                       'Maximum flow on each HVDC link (3.2.1.1)'
  HVDClinkLossDefinition(tp,br)                    'Definition of losses on the HVDC link (3.2.1.2)'
  HVDClinkFlowDefinition(tp,br)                    'Definition of MW flow on the HVDC link (3.2.1.3)'
  HVDClinkFlowIntegerDefinition1(tp)               'Definition of the integer HVDC link flow variable (3.8.2a)'
  HVDClinkFlowIntegerDefinition2(tp,i_flowDirection)               'Definition of the integer HVDC link flow variable (3.8.2b)'
* Additional constraints for the intra-pole circulating branch flows
  HVDClinkFlowIntegerDefinition3(tp,pole)                          'Definition of the HVDC pole integer varaible to prevent intra-pole circulating branch flows (3.8.2c)'
  HVDClinkFlowIntegerDefinition4(tp,pole,i_flowDirection)          'Definition of the HVDC pole integer varaible to prevent intra-pole circulating branch flows (3.8.2d)'

  LambdaDefinition(tp,br)                                          'Definition of weighting factor (3.2.1.4)'
  LambdaIntegerDefinition1(tp,br)                                  'Definition of weighting factor when branch integer constraints are needed (3.8.3a)'
  LambdaIntegerDefinition2(tp,br,los)                              'Definition of weighting factor when branch integer constraints are needed (3.8.3b)'

  DCNodeNetInjection(tp,b)                                         'Definition of the net injection at buses corresponding to HVDC nodes (3.2.1.6)'
  ACnodeNetInjectionDefinition1(tp,b)                              '1st definition of the net injection at buses corresponding to AC nodes (3.3.1.1)'
  ACnodeNetInjectionDefinition2(tp,b)                              '2nd definition of the net injection at buses corresponding to AC nodes (3.3.1.2)'
  ACBranchMaximumFlow(tp,br,i_flowDirection)                       'Maximum flow on the AC branch (3.3.1.3)'
  ACBranchFlowDefinition(tp,br)                                    'Relationship between directed and undirected branch flow variables (3.3.1.4)'
  LinearLoadFlow(tp,br)                                            'Equation that describes the linear load flow (3.3.1.5)'
  ACBranchBlockLimit(tp,br,los,i_flowDirection)                    'Limit on each AC branch flow block (3.3.1.6)'
  ACDirectedBranchFlowDefinition(tp,br,i_flowDirection)            'Composition of the directed branch flow from the block branch flow (3.3.1.7)'
  ACBranchLossCalculation(tp,br,los,i_flowDirection)               'Calculation of the losses in each loss segment (3.3.1.8)'
  ACDirectedBranchLossDefinition(tp,br,i_flowDirection)            'Composition of the directed branch losses from the block branch losses (3.3.1.9)'
  ACDirectedBranchFlowIntegerDefinition1(tp,br)                    'Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1a)'
  ACDirectedBranchFlowIntegerDefinition2(tp,br,i_flowDirection)    'Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1b)'
* Risk and Reserve
  HVDCIslandRiskCalculation(tp,ild,i_reserveClass,i_riskClass)     'Calculation of the island risk for a DCCE and DCECE (3.4.1.1)'
  HVDCRecCalculation(tp,ild)                                       'Calculation of the net received HVDC MW flow into an island (3.4.1.5)'
  GenIslandRiskCalculation(tp,ild,o,i_reserveClass,i_riskClass)    'Calculation of the island risk for risk setting generators (3.4.1.6)'
  ManualIslandRiskCalculation(tp,ild,i_reserveClass,i_riskClass)   'Calculation of the island risk based on manual specifications (3.4.1.7)'
  PLSRReserveProportionMaximum(tp,o,trdBlk,i_reserveClass,i_reserveType) 'Maximum PLSR as a proportion of the block MW (3.4.2.1)'
  ReserveOfferDefinition(tp,o,i_reserveClass,i_reserveType)        'Definition of the reserve offers of different classes and types (3.4.2.3a)'
  ReserveDefinitionPurchaseBid(tp,i_bid,i_reserveClass)            'Definition of the ILR reserve provided by purchase bids (3.4.2.3b)'
  EnergyAndReserveMaximum(tp,o,i_reserveClass)                     'Definition of maximum energy and reserves from each generator (3.4.2.4)'
  PurchaseBidReserveMaximum(tp,i_bid,i_reserveClass)               'Maximum ILR provided by purchase bids (3.4.2.5)'
  MaximumIslandRiskDefinition(tp,ild,i_reserveClass,i_riskClass)   'Definition of the maximum risk in each island (3.4.3.1)'
  SupplyDemandReserveRequirement(tp,ild,i_reserveClass)            'Matching of reserve supply and demand (3.4.3.2)'
* Risk calculation for generators with more than one offer - Primary and secondary offers
  GenIslandRiskCalculation_NonPS(tp,ild,o,i_reserveClass,i_riskClass)    'Calculation of the island risk for risk setting generators with only one offer (3.4.1.6)'
  GenIslandRiskCalculation_PS(tp,ild,o,i_reserveClass,i_riskClass)       'Calculation of the island risk for risk setting generators with more than one offer (3.4.1.6)'
  RiskOffsetCalculation_DCCE(tp,ild,i_reserveClass,i_riskClass)          'Calculation of the risk offset variable for the DCCE risk class.  Suppress this when suppressMixedConstraint flag is true (3.4.1.2)'
  RiskOffsetCalculation_DCECE(tp,ild,i_reserveClass,i_riskClass)         'Calculation of the risk offset variable for the DCECE risk class.  Suppress this when suppressMixedConstraint flag is true (3.4.1.4)'
  RiskOffsetCalculation(tp,t1MixCstr,ild,i_reserveClass,i_riskClass)  'Risk offset definition. Suppress this when suppressMixedConstraint flag is true (3.4.1.5 - v4.4)'
* Need to seperate the maximum island risk definition constraint to support the different CVPs defined for CE and ECE
  MaximumIslandRiskDefinition_CE(tp,ild,i_reserveClass,i_riskClass)      'Definition of the maximum CE risk in each island (3.4.3.1a)'
  MaximumIslandRiskDefinition_ECE(tp,ild,i_reserveClass,i_riskClass)     'Definition of the maximum ECE risk in each island (3.4.3.1b)'
* HVDC secondary risk calculation
  HVDCIslandSecRiskCalculation_GEN(tp,ild,o,i_reserveClass,i_riskClass)  'Calculation of the island risk for an HVDC secondary risk to an AC risk (3.4.1.8)'
  HVDCIslandSecRiskCalculation_Manual(tp,ild,i_reserveClass,i_riskClass) 'Calculation of the island risk for an HVDC secondary risk to a manual risk (3.4.1.9)'
* HVDC secondary risk calculation for generators with more than one offer - Primary and secondary offers
  HVDCIslandSecRiskCalculation_GEN_NonPS(tp,ild,o,i_reserveClass,i_riskClass)
  HVDCIslandSecRiskCalculation_GEN_PS(tp,ild,o,i_reserveClass,i_riskClass)
* Branch security constraints
  BranchSecurityConstraintLE(tp,brCstr)            'Branch security constraint with LE sense (3.5.1.5a)'
  BranchSecurityConstraintGE(tp,brCstr)            'Branch security constraint with GE sense (3.5.1.5b)'
  BranchSecurityConstraintEQ(tp,brCstr)            'Branch security constraint with EQ sense (3.5.1.5c)'
* AC node security constraints
  ACnodeSecurityConstraintLE(tp,ACnodeCstr)        'AC node security constraint with LE sense (3.5.1.6a)'
  ACnodeSecurityConstraintGE(tp,ACnodeCstr)        'AC node security constraint with GE sense (3.5.1.6b)'
  ACnodeSecurityConstraintEQ(tp,ACnodeCstr)        'AC node security constraint with EQ sense (3.5.1.6c)'
* Market node security constraints
  MNodeSecurityConstraintLE(tp,MnodeCstr)          'Market node security constraint with LE sense (3.5.1.7a)'
  MNodeSecurityConstraintGE(tp,MnodeCstr)          'Market node security constraint with GE sense (3.5.1.7b)'
  MNodeSecurityConstraintEQ(tp,MnodeCstr)          'Market node security constraint with EQ sense (3.5.1.7c)'
* Mixed constraints
  Type1MixedConstraintLE(tp,t1MixCstr)             'Type 1 mixed constraint definition with LE sense (3.6.1.1a)'
  Type1MixedConstraintGE(tp,t1MixCstr)             'Type 1 mixed constraint definition with GE sense (3.6.1.1b)'
  Type1MixedConstraintEQ(tp,t1MixCstr)             'Type 1 mixed constraint definition with EQ sense (3.6.1.1c)'
  Type2MixedConstraintLE(tp,t2MixCstr)             'Type 2 mixed constraint definition with LE sense (3.6.1.2a)'
  Type2MixedConstraintGE(tp,t2MixCstr)             'Type 2 mixed constraint definition with GE sense (3.6.1.2b)'
  Type2MixedConstraintEQ(tp,t2MixCstr)             'Type 2 mixed constraint definition with EQ sense (3.6.1.2c)'
  Type1MixedConstraintLE_MIP(tp,t1MixCstr)         'Integer equivalent of type 1 mixed constraint definition with LE sense (3.6.1.1a_MIP)'
  Type1MixedConstraintGE_MIP(tp,t1MixCstr)         'Integer equivalent of type 1 mixed constraint definition with GE sense (3.6.1.1b_MIP)'
  Type1MixedConstraintEQ_MIP(tp,t1MixCstr)         'Integer equivalent of type 1 mixed constraint definition with EQ sense (3.6.1.1c_MIP)'
  Type1MixedConstraintMIP(tp,t1MixCstr,br)         'Type 1 mixed constraint definition of alternate limit selection (integer)'
* Generic constraints
  GenericSecurityConstraintLE(tp,gnrcCstr)         'Generic security constraint with LE sense'
  GenericSecurityConstraintGE(tp,gnrcCstr)         'Generic security constraint with GE sense'
  GenericSecurityConstraintEQ(tp,gnrcCstr)         'Generic security constraint with EQ sense'
* Violation cost
  TotalViolationCostDefinition                     'Defined as the sum of the individual violation costs'
  ;


* Objective function of the dispatch model (4.1.1.1)
ObjectiveFunction..
NETBENEFIT =e=
  sum[ validPurchaseBidBlock,     PURCHASEBLOCK(validPurchaseBidBlock)       * PurchaseBidPrice(validPurchaseBidBlock) ]
- sum[ validGenerationOfferBlock, GENERATIONBLOCK(validGenerationOfferBlock) * GenerationOfferPrice(validGenerationOfferBlock) ]
- sum[ validReserveOfferBlock,    RESERVEBLOCK(validReserveOfferBlock)       * ReserveOfferPrice(validReserveOfferBlock) ]
- sum[ validPurchaseBidILRBlock,  PURCHASEILRBLOCK(validPurchaseBidILRBlock) ]
- TOTALPENALTYCOST
* Scarcity pricing updates
- sum((currTP,ild,i_reserveClass), virtualReservePrice(currTP,ild,i_reserveClass) * VIRTUALRESERVE(currTP,ild,i_reserveClass))
  ;

* Defined as the sum of the individual violation costs
* RDN - Bug fix - used surplusBranchGroupConstraintPenalty rather than surplusBranchFlowPenalty
TotalViolationCostDefinition..
TOTALPENALTYCOST =e=
  sum[ Bus,    deficitBusGenerationPenalty * DEFICITBUSGENERATION(Bus) ]
+ sum[ Bus,    surplusBusGenerationPenalty * SURPLUSBUSGENERATION(Bus) ]
+ sum[ Branch, surplusBranchFlowPenalty    * SURPLUSBRANCHFLOW(Branch) ]
+ sum[ Offer,  deficitRampRatePenalty      * DEFICITRAMPRATE(Offer) ]
+ sum[ Offer,  surplusRampRatePenalty      * SURPLUSRAMPRATE(Offer) ]
+ sum[ ACnodeConstraint, DeficitACnodeConstraintPenalty * DEFICITACnodeCONSTRAINT(ACnodeConstraint) ]
+ sum[ ACnodeConstraint, SurplusACnodeConstraintPenalty * SURPLUSACnodeCONSTRAINT(ACnodeConstraint) ]
+ sum[ BranchConstraint, surplusBranchGroupConstraintPenalty * SURPLUSBRANCHSECURITYCONSTRAINT(BranchConstraint) ]
+ sum[ BranchConstraint, deficitBranchGroupConstraintPenalty * DEFICITBRANCHSECURITYCONSTRAINT(BranchConstraint) ]
+ sum[ MNodeConstraint, DeficitMnodeConstraintPenalty * DEFICITMNODECONSTRAINT(MNodeConstraint) ]
+ sum[ MNodeConstraint, SurplusMnodeConstraintPenalty * SURPLUSMNODECONSTRAINT(MNodeConstraint) ]
+ sum[ Type1MixedConstraint, Type1DeficitMixedConstraintPenalty * DEFICITTYPE1MIXEDCONSTRAINT(Type1MixedConstraint) ]
+ sum[ Type1MixedConstraint, Type1SurplusMixedConstraintPenalty * SURPLUSTYPE1MIXEDCONSTRAINT(Type1MixedConstraint) ]
+ sum[ GenericConstraint, DeficitGenericConstraintPenalty * DEFICITGENERICCONSTRAINT(GenericConstraint) ]
+ sum[ GenericConstraint, SurplusGenericConstraintPenalty * SURPLUSGENERICCONSTRAINT(GenericConstraint) ]
* Separate CE and ECE reserve deficity
+ sum[ (currTP,ild,i_reserveClass)
       , [DeficitReservePenalty(i_reserveClass)     * DEFICITRESERVE(currTP,ild,i_reserveClass)     $ (not DiffCeECeCVP)]
       + [DeficitReservePenalty_CE(i_reserveClass)  * DEFICITRESERVE_CE(currTP,ild,i_reserveClass)  $ DiffCeECeCVP]
       + [DeficitReservePenalty_ECE(i_reserveClass) * DEFICITRESERVE_ECE(currTP,ild,i_reserveClass) $ DiffCeECeCVP]
     ]
  ;

* Definition of generation provided by an offer (3.1.1.2)
GenerationOfferDefintion(Offer)..
  GENERATION(Offer)
=e=
  sum[ validGenerationOfferBlock(Offer,trdBlk), GENERATIONBLOCK(Offer,trdBlk) ]
  ;

* Change constraint numbering. 3.1.1.5 in the SPD formulation v6.0
* Definition of purchase provided by a bid (3.1.1.5)
PurchaseBidDefintion(Bid)..
  PURCHASE(Bid)
=e=
  sum[ validPurchaseBidBlock(Bid,trdBlk), PURCHASEBLOCK(Bid,trdBlk) ]
  ;

* Maximum flow on each HVDC link (3.2.1.1)
HVDClinkMaximumFlow(HVDClink) $ { ClosedBranch(HVDClink) and useHVDCbranchLimits }..
  HVDCLINKFLOW(HVDClink)
=l=
  HVDClinkCapacity(HVDClink)
  ;

* Definition of losses on the HVDC link (3.2.1.2)
HVDClinkLossDefinition(HVDClink)..
  HVDCLINKLOSSES(HVDClink)
=e=
  sum[ validLossSegment(HVDClink,los), HVDCBreakPointMWLoss(HVDClink,los) * LAMBDA(HVDClink,los) ]
  ;

* Definition of MW flow on the HVDC link (3.2.1.3)
HVDClinkFlowDefinition(HVDClink)..
  HVDCLINKFLOW(HVDClink)
=e=
  sum[ validLossSegment(HVDClink,los), HVDCBreakPointMWFlow(HVDClink,los) * LAMBDA(HVDClink,los) ]
  ;

* Definition of the integer HVDC link flow variable (3.8.2a)
* Not used if roundpower is allowed
HVDClinkFlowIntegerDefinition1(currTP) $ { UseBranchFlowMIP(currTP) and
                                           resolveCircularBranchFlows and
                                           (1-AllowHVDCRoundpower(currTP))
                                         }..
  sum[ i_flowDirection, HVDCLINKFLOWDIRECTION_INTEGER(currTP,i_flowDirection) ]
=e=
  sum[ HVDCpoleDirection(HVDClink(currTP,br),i_flowDirection), HVDCLINKFLOW(HVDClink) ]
  ;

* Definition of the integer HVDC link flow variable (3.8.2b)
* Not used if roundpower is allowed
HVDClinkFlowIntegerDefinition2(currTP,i_flowDirection) $ { UseBranchFlowMIP(currTP) and
                                                           resolveCircularBranchFlows and
                                                           (1-AllowHVDCRoundpower(currTP))
                                                         }..
  HVDCLINKFLOWDIRECTION_INTEGER(currTP,i_flowDirection)
=e=
  sum[ HVDCpoleDirection(HVDClink(currTP,br),i_flowDirection), HVDCLINKFLOW(HVDClink) ]
  ;

* Definition of the integer HVDC pole flow variable for intra-pole circulating branch flows e (3.8.2c)
HVDClinkFlowIntegerDefinition3(currTP,pole) $ { UseBranchFlowMIP(currTP) and
                                                resolveCircularBranchFlows }..
  sum[ br $ { HVDCpoles(currTP,br) and HVDCpoleBranchMap(pole,br) }, HVDCLINKFLOW(currTP,br) ]
=e=
  sum[ i_flowDirection, HVDCPOLEFLOW_INTEGER(currTP,pole,i_flowDirection) ]
  ;

* Definition of the integer HVDC pole flow variable for intra-pole circulating branch flows e (3.8.2d)
HVDClinkFlowIntegerDefinition4(currTP,pole,i_flowDirection) $ { UseBranchFlowMIP(currTP) and
                                                                resolveCircularBranchFlows }..
  sum[ HVDCpoleDirection(HVDCpoles(currTP,br),i_flowDirection) $ HVDCpoleBranchMap(pole,br), HVDCLINKFLOW(HVDCpoles) ]
=e=
  HVDCPOLEFLOW_INTEGER(currTP,pole,i_flowDirection)
  ;

* Definition of weighting factor (3.2.1.4)
LambdaDefinition(HVDClink)..
  sum(validLossSegment(HVDClink,los), LAMBDA(HVDClink,los))
=e=
  1
  ;

* Definition of weighting factor when branch integer constraints are needed (3.8.3a)
LambdaIntegerDefinition1(HVDClink(currTP,br)) $ { UseBranchFlowMIP(currTP) and
                                                  resolveHVDCnonPhysicalLosses }..
  sum[ validLossSegment(HVDClink,los), LAMBDAINTEGER(HVDClink,los) ]
=e=
  1
  ;

* Definition of weighting factor when branch integer constraints are needed (3.8.3b)
LambdaIntegerDefinition2(validLossSegment(HVDClink(currTP,br),los)) $ { UseBranchFlowMIP(currTP) and
                                                                        resolveHVDCnonPhysicalLosses }..
  LAMBDAINTEGER(HVDClink,los)
=e=
  LAMBDA(HVDClink,los)
  ;

* Definition of the net injection at the HVDC nodes (3.2.1.6)
DCNodeNetInjection(DCBus(currTP,b))..
  0
=e=
  DEFICITBUSGENERATION(currTP,b) - SURPLUSBUSGENERATION(currTP,b)
+ sum[ HVDClinkReceivingBus(HVDClink(currTP,br),b) $ ClosedBranch(HVDClink), HVDCLINKFLOW(HVDClink)
                                                                             - HVDCLINKLOSSES(HVDClink)
     ]
- sum[ HVDClinkSendingBus(HVDClink(currTP,br),b) $ ClosedBranch(HVDClink),   HVDCLINKFLOW(HVDClink) ]
- sum[ HVDClinkBus(HVDClink(currTP,br),b) $ ClosedBranch(HVDClink), 0.5 * HVDClinkFixedLoss(HVDClink) ]
  ;

* 1st definition of the net injection at buses corresponding to AC nodes (3.3.1.1)
ACnodeNetInjectionDefinition1(ACBus(currTP,b))..
  ACNODENETINJECTION(currTP,b)
=e=
  sum[ ACBranchSendingBus(ACBranch(currTP,br),b,i_flowDirection) $ ClosedBranch(ACBranch)
       , ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection)
     ]
- sum[ ACBranchReceivingBus(ACBranch(currTP,br),b,i_flowDirection) $ ClosedBranch(ACBranch)
       , ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection)
     ]
  ;

* 2nd definition of the net injection at buses corresponding to AC nodes (3.3.1.2)
ACnodeNetInjectionDefinition2(ACBus(currTP,b))..
  ACNODENETINJECTION(currTP,b)
=e=
  sum[ offerNode(currTP,o,n) $ NodeBus(currTP,n,b), NodeBusAllocationFactor(currTP,n,b) * GENERATION(currTP,o) ]
- sum[ BidNode(currTP,i_bid,n) $ NodeBus(currTP,n,b), NodeBusAllocationFactor(currTP,n,b) * PURCHASE(currTP,i_bid) ]
- sum[ NodeBus(currTP,n,b), NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n) ]
+ sum[ HVDClinkReceivingBus(HVDClink(currTP,br),b) $ ClosedBranch(HVDClink), HVDCLINKFLOW(HVDClink) ]
- sum[ HVDClinkReceivingBus(HVDClink(currTP,br),b) $ ClosedBranch(HVDClink), HVDCLINKLOSSES(HVDClink) ]
- sum[ HVDClinkSendingBus(HVDClink(currTP,br),b) $ ClosedBranch(HVDClink), HVDCLINKFLOW(HVDClink) ]
- sum[ HVDClinkBus(HVDClink(currTP,br),b) $ ClosedBranch(HVDClink), 0.5 * HVDClinkFixedLoss(HVDClink) ]
- sum[ ACBranchReceivingBus(ACBranch(currTP,br),b,i_flowDirection) $ ClosedBranch(ACBranch)
       , i_branchReceivingEndLossProportion * ACBRANCHLOSSESDIRECTED(ACBranch,i_flowDirection) ]
- sum[ ACBranchSendingBus(ACBranch(currTP,br),b,i_flowDirection) $ ClosedBranch(ACBranch)
       , (1 - i_branchReceivingEndLossProportion) * ACBRANCHLOSSESDIRECTED(ACBranch,i_flowDirection) ]
- sum[ BranchBusConnect(ACBranch(currTP,br),b) $ ClosedBranch(ACBranch), 0.5 * ACBranchFixedLoss(ACBranch) ]
+ DEFICITBUSGENERATION(currTP,b)
- SURPLUSBUSGENERATION(currTP,b)
  ;

* Maximum flow on the AC branch (3.3.1.3)
ACBranchMaximumFlow(ClosedBranch(ACbranch),i_flowDirection) $ useACbranchLimits..
  ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection)
=l=
  ACBranchCapacity(ACBranch)
+ SURPLUSBRANCHFLOW(ACBranch)
  ;

* Relationship between directed and undirected branch flow variables (3.3.1.4)
ACBranchFlowDefinition(ClosedBranch(ACBranch))..
  ACBRANCHFLOW(ACBranch)
=e=
  sum[ i_flowDirection $ (ord(i_flowDirection) = 1), ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection) ]
- sum[ i_flowDirection $ (ord(i_flowDirection) = 2), ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection) ]
  ;

* Equation that describes the linear load flow (3.3.1.5)
LinearLoadFlow(ClosedBranch(ACBranch(currTP,br)))..
  ACBRANCHFLOW(ACBranch)
=e=
  ACBranchSusceptance(ACBranch)
  * sum[ BranchBusDefn(ACBranch,frB,toB), ACNODEANGLE(currTP,frB) - ACNODEANGLE(currTP,toB) ]
  ;

* Limit on each AC branch flow block (3.3.1.6)
ACBranchBlockLimit(validLossSegment(ClosedBranch(ACBranch),los),i_flowDirection)..
  ACBRANCHFLOWBLOCKDIRECTED(ACBranch,los,i_flowDirection)
=l=
  ACBranchLossMW(ACBranch,los)
  ;

* Composition of the directed branch flow from the block branch flow (3.3.1.7)
ACDirectedBranchFlowDefinition(ClosedBranch(ACBranch),i_flowDirection)..
  ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection)
=e=
  sum[ validLossSegment(ACBranch,los), ACBRANCHFLOWBLOCKDIRECTED(ACBranch,los,i_flowDirection) ]
  ;

* Calculation of the losses in each loss segment (3.3.1.8)
ACBranchLossCalculation(validLossSegment(ClosedBranch(ACBranch),los),i_flowDirection)..
  ACBRANCHLOSSESBLOCKDIRECTED(ACBranch,los,i_flowDirection)
=e=
  ACBRANCHFLOWBLOCKDIRECTED(ACBranch,los,i_flowDirection) * ACBranchLossFactor(ACBranch,los)
  ;

* Composition of the directed branch losses from the block branch losses (3.3.1.9)
ACDirectedBranchLossDefinition(ClosedBranch(ACBranch),i_flowDirection)..
  ACBRANCHLOSSESDIRECTED(ACBranch,i_flowDirection)
=e=
  sum[ validLossSegment(ACBranch,los), ACBRANCHLOSSESBLOCKDIRECTED(ACBranch,los,i_flowDirection) ]
  ;

* Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1a)
ACDirectedBranchFlowIntegerDefinition1(ClosedBranch(ACBranch(lossBranch(currTP,br)))) $ { UseBranchFlowMIP(currTP) and
                                                                                          resolveCircularBranchFlows }..
  sum[ i_flowDirection, ACBRANCHFLOWDIRECTED_INTEGER(ACBranch,i_flowDirection) ]
=e=
  sum[ i_flowDirection, ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection) ]
  ;

* Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1b)
ACDirectedBranchFlowIntegerDefinition2(ClosedBranch(ACBranch(lossBranch(currTP,br))),i_flowDirection) $ { UseBranchFlowMIP(currTP) and
                                                                                                          resolveCircularBranchFlows }..
  ACBRANCHFLOWDIRECTED_INTEGER(ACBranch,i_flowDirection)
=e=
  ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection)
  ;

* Maximum movement of the generator downwards due to up ramp rate (3.7.1.1)
GenerationRampUp(PositiveEnergyOffer) $ { not ( HasSecondaryOffer(PositiveEnergyOffer) or
                                                HasPrimaryOffer(PositiveEnergyOffer)
                                              ) }..
  GENERATION(PositiveEnergyOffer) - DEFICITRAMPRATE(PositiveEnergyOffer)
=l=
  GenerationEndUp(PositiveEnergyOffer)
  ;

* Maximum movement of the generator downwards due to down ramp rate (3.7.1.2)
GenerationRampDown(PositiveEnergyOffer) $ { not ( HasSecondaryOffer(PositiveEnergyOffer) or
                                                  HasPrimaryOffer(PositiveEnergyOffer)
                                                ) }..
  GENERATION(PositiveEnergyOffer) + SURPLUSRAMPRATE(PositiveEnergyOffer)
=g=
  GenerationEndDown(PositiveEnergyOffer)
  ;

* Maximum movement of the primary offer that has a secondary offer upwards due to up ramp rate (3.7.1.1)
GenerationRampUp_PS(currTP,o) $ { PositiveEnergyOffer(currTP,o) and HasSecondaryOffer(currTP,o) }..
  GENERATION(currTP,o)
+ sum[ o1 $ PrimarySecondaryOffer(currTP,o,o1), GENERATION(currTP,o1) ]
- DEFICITRAMPRATE(currTP,o)
=l=
  GenerationEndUp(currTP,o)
  ;

* Maximum movement of the primary offer that has a secondary offer downwards due to down ramp rate (3.7.1.2)
GenerationRampDown_PS(currTP,o) $ { PositiveEnergyOffer(currTP,o) and HasSecondaryOffer(currTP,o) }..
  GENERATION(currTP,o)
+ sum[ o1 $ PrimarySecondaryOffer(currTP,o,o1), GENERATION(currTP,o1) ]
+ SURPLUSRAMPRATE(currTP,o)
=g=
  GenerationEndDown(currTP,o)
  ;

* Calculation of the risk offset variable for the DCCE risk class.
* This will be used when the useMixedConstraintRiskOffset flag is false (3.4.1.2)
RiskOffsetCalculation_DCCE(currTP,ild,i_reserveClass,i_riskClass) $ { (not useMixedConstraintRiskOffset) and
                                                                      HVDCrisk(i_riskClass) and
                                                                      ContingentEvents(i_riskClass)
                                                                    }..
  RISKOFFSET(currTP,ild,i_reserveClass,i_riskClass)
=e=
  FreeReserve(currTP,ild,i_reserveClass,i_riskClass)
+ HVDCPoleRampUp(currTP,ild,i_reserveClass,i_riskClass)
  ;

* Calculation of the risk offset variable for the DCECE risk class.
* This will be used when the useMixedConstraintRiskOffset flag is false (3.4.1.4)
RiskOffsetCalculation_DCECE(currTP,ild,i_reserveClass,i_riskClass) $ { (not useMixedConstraintRiskOffset) and
                                                                       HVDCrisk(i_riskClass) and
                                                                       ExtendedContingentEvent(i_riskClass)
                                                                     }..
  RISKOFFSET(currTP,ild,i_reserveClass,i_riskClass)
=e=
  FreeReserve(currTP,ild,i_reserveClass,i_riskClass)
  ;

* Risk offset definition (3.4.1.5) in old formulation (v4.4).
* Use this when the useMixedConstraintRiskOffset flag is set.
RiskOffsetCalculation(currTP,i_type1MixedConstraintReserveMap(t1MixCstr,ild,i_reserveClass,i_riskClass)) $ useMixedConstraintRiskOffset..
  RISKOFFSET(currTP,ild,i_reserveClass,i_riskClass)
=e=
  MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
  ;

* Calculation of the island risk for a DCCE and DCECE (3.4.1.1)
HVDCIslandRiskCalculation(currTP,ild,i_reserveClass,HVDCrisk)..
  ISLANDRISK(currTP,ild,i_reserveClass,HVDCrisk)
=e=
  IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,HVDCrisk)
  * [ HVDCREC(currTP,ild) - RISKOFFSET(currTP,ild,i_reserveClass,HVDCrisk) ]
  ;

* Calculation of the net received HVDC MW flow into an island (3.4.1.5)
HVDCRecCalculation(currTP,ild)..
  HVDCREC(currTP,ild)
=e=
  sum[ (b,br) $ { BusIsland(currTP,b,ild)
*TN              and ACBus(currTP,b)
*TN              and HVDClink(currTP,br)
              and HVDClinkSendingBus(currTP,br,b)
              and HVDCPoles(currTP,br)
                }, -HVDCLINKFLOW(currTP,br)
     ]
+ sum[ (b,br) $ { BusIsland(currTP,b,ild)
*TN              and ACBus(currTP,b) and
*TN              and HVDClink(currTP,br) and
              and HVDClinkReceivingBus(currTP,br,b)
              and HVDCPoles(currTP,br)
                }, HVDCLINKFLOW(currTP,br) - HVDCLINKLOSSES(currTP,br)
     ]
  ;

* Calculation of the island risk for risk setting generators (3.4.1.6)
GenIslandRiskCalculation(currTP,ild,o,i_reserveClass,GenRisk) $ { (not (UsePrimSecGenRiskModel)) and
                                                                  IslandRiskGenerator(currTP,ild,o)
                                                                }..
  ISLANDRISK(currTP,ild,i_reserveClass,GenRisk)
=g=
  IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,GenRisk)
  * [ GENERATION(currTP,o)
    - FreeReserve(currTP,ild,i_reserveClass,GenRisk)
    + FKBand(currTP,o)
    + sum[ i_reserveType, RESERVE(currTP,o,i_reserveClass,i_reserveType) ]
    ]
  ;

* Calculation of the island risk for risk setting generators (3.4.1.6)
* Generator island risk calculation with single offer
GenIslandRiskCalculation_NonPS(currTP,ild,o,i_reserveClass,GenRisk) $ { UsePrimSecGenRiskModel and
                                                                        IslandRiskGenerator(currTP,ild,o) and
                                                                        ( not ( HasSecondaryOffer(currTP,o) or
                                                                                HasPrimaryOffer(currTP,o)
                                                                              )
                                                                        )
                                                                      }..
  ISLANDRISK(currTP,ild,i_reserveClass,GenRisk)
=g=
  IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,GenRisk)
  * [ GENERATION(currTP,o)
    - FreeReserve(currTP,ild,i_reserveClass,GenRisk)
    + FKBand(currTP,o)
    + sum[ i_reserveType, RESERVE(currTP,o,i_reserveClass,i_reserveType) ]
    ]
  ;

* Calculation of the island risk for risk setting generators (3.4.1.6)
* Risk calculation for generators with more than one offer - Primary and secondary offers
GenIslandRiskCalculation_PS(currTP,ild,o,i_reserveClass,GenRisk) $ { UsePrimSecGenRiskModel and
                                                                     IslandRiskGenerator(currTP,ild,o) and
                                                                     HasSecondaryOffer(currTP,o)
                                                                   }..
  ISLANDRISK(currTP,ild,i_reserveClass,GenRisk)
=g=
  IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,GenRisk)
  * [ GENERATION(currTP,o)
    - FreeReserve(currTP,ild,i_reserveClass,GenRisk)
    + FKBand(currTP,o)
    + sum[ i_reserveType, RESERVE(currTP,o,i_reserveClass,i_reserveType) ]
    + sum[ o1 $ PrimarySecondaryOffer(currTP,o,o1), GENERATION(currTP,o1) ]
    + sum[ (o1,i_reserveType) $ PrimarySecondaryOffer(currTP,o,o1), RESERVE(currTP,o1,i_reserveClass,i_reserveType) ]

    ]
  ;

* Calculation of the island risk based on manual specifications (3.4.1.7)
ManualIslandRiskCalculation(currTP,ild,i_reserveClass,ManualRisk)..
  ISLANDRISK(currTP,ild,i_reserveClass,ManualRisk)
=e=
  IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,ManualRisk)
  * [ IslandMinimumRisk(currTP,ild,i_reserveClass,ManualRisk)
    - FreeReserve(currTP,ild,i_reserveClass,ManualRisk)
    ]
  ;

* HVDC secondary risk calculation including the FKBand for generator primary risk
* Calculation of the island risk for an HVDC secondary risk to a generator risk (3.4.1.8)
HVDCIslandSecRiskCalculation_GEN(currTP,ild,o,i_reserveClass,HVDCSecRisk) $ { (not (UsePrimSecGenRiskModel)) and
                                                                              HVDCSecRiskEnabled(currTP,ild,HVDCSecRisk) and
                                                                              IslandRiskGenerator(currTP,ild,o)
                                                                            }..
  ISLANDRISK(currTP,ild,i_reserveClass,HVDCSecRisk)
=g=
  IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,HVDCSecRisk)
  * [ GENERATION(currTP,o)
    - FreeReserve(currTP,ild,i_reserveClass,HVDCSecRisk)
    + HVDCREC(currTP,ild)
    - HVDCSecRiskSubtractor(currTP,ild)
    + FKBand(currTP,o)
    + sum[ i_reserveType, RESERVE(currTP,o,i_reserveClass,i_reserveType) ]
    ]
  ;

* Calculation of the island risk for an HVDC secondary risk to a generator risk (3.4.1.8)
HVDCIslandSecRiskCalculation_GEN_NonPS(currTP,ild,o,i_reserveClass,HVDCSecRisk) $ { UsePrimSecGenRiskModel and
                                                                                    HVDCSecRiskEnabled(currTP,ild,HVDCSecRisk) and
                                                                                    IslandRiskGenerator(currTP,ild,o) and
                                                                                    ( not ( HasSecondaryOffer(currTP,o) or
                                                                                            HasPrimaryOffer(currTP,o)
                                                                                          )
                                                                                    )
                                                                                  }..
  ISLANDRISK(currTP,ild,i_reserveClass,HVDCSecRisk)
=g=
  IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,HVDCSecRisk)
  * [ GENERATION(currTP,o)
    - FreeReserve(currTP,ild,i_reserveClass,HVDCSecRisk)
    + HVDCREC(currTP,ild)
    - HVDCSecRiskSubtractor(currTP,ild)
    + FKBand(currTP,o)
    + sum(i_reserveType, RESERVE(currTP,o,i_reserveClass,i_reserveType))
    ]
  ;

* Calculation of the island risk for an HVDC secondary risk to a generator risk (3.4.1.8)
HVDCIslandSecRiskCalculation_GEN_PS(currTP,ild,o,i_reserveClass,HVDCSecRisk) $ { UsePrimSecGenRiskModel and
                                                                                 HVDCSecRiskEnabled(currTP,ild,HVDCSecRisk) and
                                                                                 IslandRiskGenerator(currTP,ild,o) and
                                                                                 HasSecondaryOffer(currTP,o)
                                                                               }..
  ISLANDRISK(currTP,ild,i_reserveClass,HVDCSecRisk)
=g=
  IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,HVDCSecRisk)
  * [ GENERATION(currTP,o)
    - FreeReserve(currTP,ild,i_reserveClass,HVDCSecRisk)
    + HVDCREC(currTP,ild)
    - HVDCSecRiskSubtractor(currTP,ild)
    + FKBand(currTP,o)
    + sum[ i_reserveType, RESERVE(currTP,o,i_reserveClass,i_reserveType) ]
    + sum[ o1 $ PrimarySecondaryOffer(currTP,o,o1), GENERATION(currTP,o1) ]
    + sum[ (o1,i_reserveType) $ PrimarySecondaryOffer(currTP,o,o1), RESERVE(currTP,o1,i_reserveClass,i_reserveType) ]
    ]
  ;

* HVDC secondary risk calculation for manual primary risk
* Calculation of the island risk for an HVDC secondary risk to a manual risk (3.4.1.9)
HVDCIslandSecRiskCalculation_Manual(currTP,ild,i_reserveClass,HVDCSecRisk) $ HVDCSecRiskEnabled(currTP,ild,HVDCSecRisk)..
  ISLANDRISK(currTP,ild,i_reserveClass,HVDCSecRisk)
=g=
  IslandRiskAdjustmentFactor(currTP,ild,i_reserveClass,HVDCSecRisk)
  * [ HVDCSecIslandMinimumRisk(currTP,ild,i_reserveClass,HVDCSecRisk)
    - FreeReserve(currTP,ild,i_reserveClass,HVDCSecRisk)
    + HVDCREC(currTP,ild)
    - HVDCSecRiskSubtractor(currTP,ild)
    ]
  ;

* Maximum PLSR as a proportion of the block MW (3.4.2.1)
PLSRReserveProportionMaximum(validReserveOfferBlock(Offer,trdBlk,i_reserveClass,PLSRReserveType))..
  RESERVEBLOCK(Offer,trdBlk,i_reserveClass,PLSRReserveType)
=l=
  ReserveOfferProportion(Offer,trdBlk,i_reserveClass) * GENERATION(Offer)
  ;

* Definition of the reserve offers of different classes and types (3.4.2.3a)
ReserveOfferDefinition(Offer,i_reserveClass,i_reserveType)..
  RESERVE(Offer,i_reserveClass,i_reserveType)
=e=
  sum[ trdBlk, RESERVEBLOCK(Offer,trdBlk,i_reserveClass,i_reserveType) ]
  ;

* Definition of the ILR reserve provided by purchase bids (3.4.2.3b)
ReserveDefinitionPurchaseBid(Bid,i_reserveClass)..
  PURCHASEILR(Bid,i_reserveClass)
=e=
  sum(trdBlk, PURCHASEILRBLOCK(Bid,trdBlk,i_reserveClass))
  ;

* Definition of maximum energy and reserves from each generator (3.4.2.4)
EnergyAndReserveMaximum(Offer,i_reserveClass)..
  GENERATION(Offer)
+ ReserveMaximumFactor(Offer,i_reserveClass)
  * sum[ i_reserveType $ (not ILReserveType(i_reserveType)), RESERVE(Offer,i_reserveClass,i_reserveType) ]
=l=
  ReserveGenerationMaximum(Offer)
  ;

* This constraint is no longer in the formulation from v6.0 (following changes with DSBF)
* Maximum ILR provided by purchase bids (3.4.2.5)
PurchaseBidReserveMaximum(Bid,i_reserveClass) $ (not (UseDSBFDemandBidModel))..
  PURCHASEILR(Bid,i_reserveClass)
=l=
  PURCHASE(Bid)
  ;

* Definition of the maximum risk in each island
* applied when the CE and ECE CVPs are not separated (3.4.3.1)

MaximumIslandRiskDefinition(currTP,ild,i_reserveClass,i_riskClass) $ (not DiffCeECeCVP)..
  ISLANDRISK(currTP,ild,i_reserveClass,i_riskClass)
=l=
  MAXISLANDRISK(currTP,ild,i_reserveClass)
  ;

* Definition of the maximum CE risk in each island (3.4.3.1a)
* applied when the CE and ECE CVPs are separated
MaximumIslandRiskDefinition_CE(currTP,ild,i_reserveClass,ContingentEvents) $ (DiffCeECeCVP)..
  ISLANDRISK(currTP,ild,i_reserveClass,ContingentEvents)
=l=
  MAXISLANDRISK(currTP,ild,i_reserveClass)
  + DEFICITRESERVE_CE(currTP,ild,i_reserveClass)
  ;

* Definition of the maximum CE risk in each island (3.4.3.1b)
* applied when the CE and ECE CVPs are separated
MaximumIslandRiskDefinition_ECE(currTP,ild,i_reserveClass,ExtendedContingentEvent) $ (DiffCeECeCVP)..
  ISLANDRISK(currTP,ild,i_reserveClass,ExtendedContingentEvent)
=l=
  MAXISLANDRISK(currTP,ild,i_reserveClass)
  + DEFICITRESERVE_ECE(currTP,ild,i_reserveClass)
  ;

* Matching of reserve supply and demand (3.4.3.2)
SupplyDemandReserveRequirement(currTP,ild,i_reserveClass) $ useReserveModel..
  MAXISLANDRISK(currTP,ild,i_reserveClass)
- [DEFICITRESERVE(currTP,ild,i_reserveClass) $ (not DiffCeECeCVP)]
=l=
  sum[ (o,i_reserveType) $ { Offer(currTP,o) and
                             IslandOffer(currTP,ild,o)
                           }, RESERVE(currTP,o,i_reserveClass,i_reserveType)
     ]
+ sum[ i_bid $ { Bid(currTP,i_bid) and
                 IslandBid(currTP,ild,i_bid)
               }, PURCHASEILR(currTP,i_bid,i_reserveClass)
     ]
* Scarcity pricing updates
+ VIRTUALRESERVE(currTP,ild,i_reserveClass)
  ;

* Branch security constraint with LE sense (3.5.1.5a)
BranchSecurityConstraintLE(currTP,brCstr) $ (BranchConstraintSense(currTP,brCstr) = -1)..
  sum[ br $ ACbranch(currTP,br), BranchConstraintFactors(currTP,brCstr,br) * ACBRANCHFLOW(currTP,br) ]
+ sum[ br $ HVDClink(currTP,br), BranchConstraintFactors(currTP,brCstr,br) * HVDCLINKFLOW(currTP,br) ]
- SURPLUSBRANCHSECURITYCONSTRAINT(currTP,brCstr)
=l=
  BranchConstraintLimit(currTP,brCstr)
  ;

* Branch security constraint with GE sense (3.5.1.5b)
BranchSecurityConstraintGE(currTP,brCstr) $ (BranchConstraintSense(currTP,brCstr) = 1)..
  sum[ br $ ACbranch(currTP,br), BranchConstraintFactors(currTP,brCstr,br) * ACBRANCHFLOW(currTP,br) ]
+ sum[ br $ HVDClink(currTP,br), BranchConstraintFactors(currTP,brCstr,br) * HVDCLINKFLOW(currTP,br) ]
+ DEFICITBRANCHSECURITYCONSTRAINT(currTP,brCstr)
=g=
  BranchConstraintLimit(currTP,brCstr)
  ;

* Branch security constraint with EQ sense (3.5.1.5c)
BranchSecurityConstraintEQ(currTP,brCstr) $ (BranchConstraintSense(currTP,brCstr) = 0)..
  sum[ br $ ACbranch(currTP,br), BranchConstraintFactors(currTP,brCstr,br) * ACBRANCHFLOW(currTP,br) ]
+ sum[ br $ HVDClink(currTP,br), BranchConstraintFactors(currTP,brCstr,br) * HVDCLINKFLOW(currTP,br) ]
+ DEFICITBRANCHSECURITYCONSTRAINT(currTP,brCstr)
- SURPLUSBRANCHSECURITYCONSTRAINT(currTP,brCstr)
=e=
  BranchConstraintLimit(currTP,brCstr)
  ;

* AC node security constraint with LE sense (3.5.1.6a)
ACnodeSecurityConstraintLE(currTP,ACnodeCstr) $ (ACnodeConstraintSense(currTP,ACnodeCstr) = -1)..
  sum[ (n,b) $ { ACnode(currTP,n) and
                 NodeBus(currTP,n,b)
               }, ACnodeConstraintFactors(currTP,ACnodeCstr,n)
                * NodeBusAllocationFactor(currTP,n,b)
                * ACNODENETINJECTION(currTP,b)
     ]
- SURPLUSACnodeCONSTRAINT(currTP,ACnodeCstr)
=l=
  ACnodeConstraintLimit(currTP,ACnodeCstr)
  ;

* AC node security constraint with GE sense (3.5.1.6b)
ACnodeSecurityConstraintGE(currTP,ACnodeCstr) $ (ACnodeConstraintSense(currTP,ACnodeCstr) = 1)..
  sum[ (n,b) $ { ACnode(currTP,n) and
                 NodeBus(currTP,n,b)
               }, ACnodeConstraintFactors(currTP,ACnodeCstr,n)
                * NodeBusAllocationFactor(currTP,n,b)
                * ACNODENETINJECTION(currTP,b)
     ]
+ DEFICITACnodeCONSTRAINT(currTP,ACnodeCstr)
=g=
  ACnodeConstraintLimit(currTP,ACnodeCstr)
  ;

* AC node security constraint with EQ sense (3.5.1.6c)
ACnodeSecurityConstraintEQ(currTP,ACnodeCstr) $ (ACnodeConstraintSense(currTP,ACnodeCstr) = 0)..
  sum[ (n,b) $ { ACnode(currTP,n) and
                 NodeBus(currTP,n,b)
               }, ACnodeConstraintFactors(currTP,ACnodeCstr,n)
                * NodeBusAllocationFactor(currTP,n,b)
                * ACNODENETINJECTION(currTP,b)
     ]
+ DEFICITACnodeCONSTRAINT(currTP,ACnodeCstr)
- SURPLUSACnodeCONSTRAINT(currTP,ACnodeCstr)
=e=
  ACnodeConstraintLimit(currTP,ACnodeCstr)
  ;



* Market node security constraint with LE sense (3.5.1.7a)
MNodeSecurityConstraintLE(currTP,MnodeCstr) $ (MNodeConstraintSense(currTP,MnodeCstr) = -1)..
  sum[ o $ PositiveEnergyOffer(currTP,o)
       , MNodeEnergyOfferConstraintFactors(currTP,MnodeCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,i_reserveClass,i_reserveType) $ offer(currTP,o)
       , MNodeReserveOfferConstraintFactors(currTP,MnodeCstr,o,i_reserveClass,i_reserveType)
       * RESERVE(currTP,o,i_reserveClass,i_reserveType)
     ]
+ sum[ i_bid $ Bid(currTP,i_bid)
       , MNodeEnergyBidConstraintFactors(currTP,MnodeCstr,i_bid)
       * PURCHASE(currTP,i_bid)
     ]
+ sum[ (i_bid,i_reserveClass) $ Bid(currTP,i_bid)
       , MNodeILReserveBidConstraintFactors(currTP,MnodeCstr,i_bid,i_reserveClass)
       * PURCHASEILR(currTP,i_bid,i_reserveClass)
     ]
- SURPLUSMNODECONSTRAINT(currTP,MnodeCstr)
=l=
  MNodeConstraintLimit(currTP,MnodeCstr)
  ;

* Market node security constraint with GE sense (3.5.1.7b)
MNodeSecurityConstraintGE(currTP,MnodeCstr) $ (MNodeConstraintSense(currTP,MnodeCstr) = 1)..
  sum[ o $ PositiveEnergyOffer(currTP,o)
       , MNodeEnergyOfferConstraintFactors(currTP,MnodeCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,i_reserveClass,i_reserveType) $ offer(currTP,o)
       , MNodeReserveOfferConstraintFactors(currTP,MnodeCstr,o,i_reserveClass,i_reserveType)
       * RESERVE(currTP,o,i_reserveClass,i_reserveType)
     ]
+ sum[ i_bid $ Bid(currTP,i_bid)
       , MNodeEnergyBidConstraintFactors(currTP,MnodeCstr,i_bid)
       * PURCHASE(currTP,i_bid)
     ]
+ sum[ (i_bid,i_reserveClass) $ Bid(currTP,i_bid)
       , MNodeILReserveBidConstraintFactors(currTP,MnodeCstr,i_bid,i_reserveClass)
       * PURCHASEILR(currTP,i_bid,i_reserveClass)
     ]
+ DEFICITMNODECONSTRAINT(currTP,MnodeCstr)
=g=
  MNodeConstraintLimit(currTP,MnodeCstr)
  ;

* Market node security constraint with EQ sense (3.5.1.7c)
MNodeSecurityConstraintEQ(currTP,MnodeCstr) $ (MNodeConstraintSense(currTP,MnodeCstr) = 0)..
  sum[ o $ PositiveEnergyOffer(currTP,o)
       , MNodeEnergyOfferConstraintFactors(currTP,MnodeCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,i_reserveClass,i_reserveType) $ offer(currTP,o)
       , MNodeReserveOfferConstraintFactors(currTP,MnodeCstr,o,i_reserveClass,i_reserveType)
       * RESERVE(currTP,o,i_reserveClass,i_reserveType)
     ]
+ sum[ i_bid $ Bid(currTP,i_bid)
       , MNodeEnergyBidConstraintFactors(currTP,MnodeCstr,i_bid)
       * PURCHASE(currTP,i_bid)
     ]
+ sum[ (i_bid,i_reserveClass) $ Bid(currTP,i_bid)
       , MNodeILReserveBidConstraintFactors(currTP,MnodeCstr,i_bid,i_reserveClass)
       * PURCHASEILR(currTP,i_bid,i_reserveClass)
     ]
+ DEFICITMNODECONSTRAINT(currTP,MnodeCstr)
- SURPLUSMNODECONSTRAINT(currTP,MnodeCstr)
=e=
  MNodeConstraintLimit(currTP,MnodeCstr)
  ;

* Type 1 mixed constraint definition with LE sense (3.6.1.1a)
Type1MixedConstraintLE(currTP,t1MixCstr) $ { useMixedConstraint(currTP) and
                                             (Type1MixedConstraintSense(currTP,t1MixCstr) = -1) and
                                             (not useMixedConstraintMIP(currTP))
                                           }..
  i_type1MixedConstraintVarWeight(t1MixCstr) * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
+ sum[ o $ PositiveEnergyOffer(currTP,o)
       , i_type1MixedConstraintGenWeight(t1MixCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,i_reserveClass,i_reserveType) $ offer(currTP,o)
       , i_type1MixedConstraintResWeight(t1MixCstr,o,i_reserveClass,i_reserveType)
       * RESERVE(currTP,o,i_reserveClass,i_reserveType)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineWeight(t1MixCstr,br)
       * HVDCLINKFLOW(currTP,br)
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineWeight(t1MixCstr,br)
       * sum[ i_flowDirection, ACBRANCHFLOWDIRECTED(currTP,br,i_flowDirection) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)
       * sum[ i_flowDirection, ACBRANCHLOSSESDIRECTED(currTP,br,i_flowDirection) ]
     ]
+ sum[ br $ { ACBranch(currTP,br) and ClosedBranch(currTP,br) }
       , i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)
       * ACBranchFixedLoss(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineLossWeight(t1MixCstr,br)
       * HVDCLINKLOSSES(currTP,br)
     ]
+ sum[ br $ { HVDClink(currTP,br) and ClosedBranch(currTP,br) }
       , i_type1MixedConstraintHVDCLineFixedLossWeight(t1MixCstr,br)
       * HVDClinkFixedLoss(currTP,br)
     ]
+ sum[ i_bid $ Bid(currTP,i_bid)
       , i_type1MixedConstraintPurWeight(t1MixCstr,i_bid)
       * PURCHASE(currTP,i_bid)
     ]
- SURPLUSTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
=l=
  Type1MixedConstraintLimit1(currTP,t1MixCstr)
  ;


* Type 1 mixed constraint definition with GE sense (3.6.1.1b)
Type1MixedConstraintGE(currTP,t1MixCstr) $ { useMixedConstraint(currTP) and
                                             (Type1MixedConstraintSense(currTP,t1MixCstr) = 1) and
                                             (not useMixedConstraintMIP(currTP))
                                           }..
  i_type1MixedConstraintVarWeight(t1MixCstr) * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
+ sum[ o $ PositiveEnergyOffer(currTP,o)
       , i_type1MixedConstraintGenWeight(t1MixCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,i_reserveClass,i_reserveType) $ offer(currTP,o)
       , i_type1MixedConstraintResWeight(t1MixCstr,o,i_reserveClass,i_reserveType)
       * RESERVE(currTP,o,i_reserveClass,i_reserveType)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineWeight(t1MixCstr,br)
       * HVDCLINKFLOW(currTP,br)
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineWeight(t1MixCstr,br)
       * sum[ i_flowDirection, ACBRANCHFLOWDIRECTED(currTP,br,i_flowDirection) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)
       * sum[ i_flowDirection, ACBRANCHLOSSESDIRECTED(currTP,br,i_flowDirection) ]
     ]
+ sum[ br $ { ACBranch(currTP,br) and ClosedBranch(currTP,br) }
       , i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)
       * ACBranchFixedLoss(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
     , i_type1MixedConstraintHVDCLineLossWeight(t1MixCstr,br)
     * HVDCLINKLOSSES(currTP,br)
     ]
+ sum[ br $ { HVDClink(currTP,br) and ClosedBranch(currTP,br) }
       , i_type1MixedConstraintHVDCLineFixedLossWeight(t1MixCstr,br)
       * HVDClinkFixedLoss(currTP,br)
     ]
+ sum[ i_bid $ Bid(currTP,i_bid)
     , i_type1MixedConstraintPurWeight(t1MixCstr,i_bid)
     * PURCHASE(currTP,i_bid)
     ]
+ DEFICITTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
=g=
  Type1MixedConstraintLimit1(currTP,t1MixCstr)
  ;

* Type 1 mixed constraint definition with EQ sense (3.6.1.1c)
Type1MixedConstraintEQ(currTP,t1MixCstr) $ { useMixedConstraint(currTP) and
                                             (Type1MixedConstraintSense(currTP,t1MixCstr) = 0) and
                                             (not useMixedConstraintMIP(currTP))
                                           }..
  i_type1MixedConstraintVarWeight(t1MixCstr) * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
+ sum[ o $ PositiveEnergyOffer(currTP,o)
       , i_type1MixedConstraintGenWeight(t1MixCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,i_reserveClass,i_reserveType) $ offer(currTP,o)
       , i_type1MixedConstraintResWeight(t1MixCstr,o,i_reserveClass,i_reserveType)
       * RESERVE(currTP,o,i_reserveClass,i_reserveType)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineWeight(t1MixCstr,br)
       * HVDCLINKFLOW(currTP,br)
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineWeight(t1MixCstr,br)
       * sum[ i_flowDirection, ACBRANCHFLOWDIRECTED(currTP,br,i_flowDirection) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)
       * sum[ i_flowDirection, ACBRANCHLOSSESDIRECTED(currTP,br,i_flowDirection) ]
     ]
+ sum[ br $ { ACBranch(currTP,br) and ClosedBranch(currTP,br) }
       , i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)
       * ACBranchFixedLoss(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineLossWeight(t1MixCstr,br)
       * HVDCLINKLOSSES(currTP,br)
     ]
+ sum[ br $ { HVDClink(currTP,br) and ClosedBranch(currTP,br) }
       , i_type1MixedConstraintHVDCLineFixedLossWeight(t1MixCstr,br)
       * HVDClinkFixedLoss(currTP,br)
     ]
+ sum[ i_bid $ Bid(currTP,i_bid)
       , i_type1MixedConstraintPurWeight(t1MixCstr,i_bid)
       * PURCHASE(currTP,i_bid)
     ]
+ DEFICITTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
- SURPLUSTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
=e=
  Type1MixedConstraintLimit1(currTP,t1MixCstr)
  ;

* Type 2 mixed constraint definition with LE sense (3.6.1.2a)
Type2MixedConstraintLE(currTP,t2MixCstr) $ { useMixedConstraint(currTP) and
                                             (Type2MixedConstraintSense(currTP,t2MixCstr) = -1)
                                           }..
  sum[ t1MixCstr, i_type2MixedConstraintLHSParameters(t2MixCstr,t1MixCstr)
                * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr) ]
=l=
  Type2MixedConstraintLimit(currTP,t2MixCstr)
  ;

* Type 2 mixed constraint definition with GE sense (3.6.1.2b)
Type2MixedConstraintGE(currTP,t2MixCstr) $ { useMixedConstraint(currTP) and
                                             (Type2MixedConstraintSense(currTP,t2MixCstr) = 1)
                                           }..
  sum[ t1MixCstr, i_type2MixedConstraintLHSParameters(t2MixCstr,t1MixCstr)
                * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr) ]
=g=
  Type2MixedConstraintLimit(currTP,t2MixCstr)
  ;

* Type 2 mixed constraint definition with EQ sense (3.6.1.2c)
Type2MixedConstraintEQ(currTP,t2MixCstr) $ { useMixedConstraint(currTP) and
                                             (Type2MixedConstraintSense(currTP,t2MixCstr) = 0)
                                           }..
  sum[ t1MixCstr, i_type2MixedConstraintLHSParameters(t2MixCstr,t1MixCstr)
                * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr) ]
=e=
  Type2MixedConstraintLimit(currTP,t2MixCstr)
  ;

* Type 1 mixed constraint definition of alternate limit selection (integer)
Type1MixedConstraintMIP(currTP,i_type1MixedConstraintBranchCondition(t1MixCstr,br)) $ { useMixedConstraintRiskOffset and
                                                                                        HVDCHalfPoles(currTP,br) and
                                                                                        useMixedConstraintMIP(currTP)
                                                                                      }..
  HVDCLINKFLOW(currTP,br)
=l=
  MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr) * MixedConstraintBigNumber
  ;

* Integer equivalent of Type 1 mixed constraint definition with LE sense (3.6.1.1a_MIP)
Type1MixedConstraintLE_MIP(Type1MixedConstraint(currTP,t1MixCstr)) $ { useMixedConstraint(currTP) and
                                                                       (Type1MixedConstraintSense(currTP,t1MixCstr) = -1) and
                                                                       useMixedConstraintMIP(currTP)
                                                                     }..
  i_type1MixedConstraintVarWeight(t1MixCstr) * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
+ sum[ o $ PositiveEnergyOffer(currTP,o)
       , i_type1MixedConstraintGenWeight(t1MixCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,i_reserveClass,i_reserveType) $ offer(currTP,o)
       , i_type1MixedConstraintResWeight(t1MixCstr,o,i_reserveClass,i_reserveType)
       * RESERVE(currTP,o,i_reserveClass,i_reserveType)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineWeight(t1MixCstr,br)
       * HVDCLINKFLOW(currTP,br)
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineWeight(t1MixCstr,br)
       * sum[ i_flowDirection, ACBRANCHFLOWDIRECTED(currTP,br,i_flowDirection) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)
       * sum[ i_flowDirection, ACBRANCHLOSSESDIRECTED(currTP,br,i_flowDirection) ]
     ]
+ sum[ br $ { ACBranch(currTP,br) and ClosedBranch(currTP,br) }
       , i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)
       * ACBranchFixedLoss(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineLossWeight(t1MixCstr,br)
       * HVDCLINKLOSSES(currTP,br)
     ]
+ sum[ br $ { HVDClink(currTP,br) and ClosedBranch(currTP,br) }
       , i_type1MixedConstraintHVDCLineFixedLossWeight(t1MixCstr,br)
       * HVDClinkFixedLoss(currTP,br)
     ]
+ sum[ i_bid $ Bid(currTP,i_bid)
       , i_type1MixedConstraintPurWeight(t1MixCstr,i_bid)
       * PURCHASE(currTP,i_bid)
     ]
- SURPLUSTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
=l=
  Type1MixedConstraintLimit1(currTP,t1MixCstr) * (1 - MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr))
+ Type1MixedConstraintLimit2(currTP,t1MixCstr) * MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr)
  ;

* Integer equivalent of Type 1 mixed constraint definition with GE sense (3.6.1.1b_MIP)
Type1MixedConstraintGE_MIP(Type1MixedConstraint(currTP,t1MixCstr)) $ { useMixedConstraint(currTP) and
                                                                       (Type1MixedConstraintSense(currTP,t1MixCstr) = 1) and
                                                                       useMixedConstraintMIP(currTP)
                                                                     }..
  i_type1MixedConstraintVarWeight(t1MixCstr) * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
+ sum[ o $ PositiveEnergyOffer(currTP,o)
       , i_type1MixedConstraintGenWeight(t1MixCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,i_reserveClass,i_reserveType) $ offer(currTP,o)
       , i_type1MixedConstraintResWeight(t1MixCstr,o,i_reserveClass,i_reserveType)
       * RESERVE(currTP,o,i_reserveClass,i_reserveType)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineWeight(t1MixCstr,br)
       * HVDCLINKFLOW(currTP,br)
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineWeight(t1MixCstr,br)
       * sum[ i_flowDirection, ACBRANCHFLOWDIRECTED(currTP,br,i_flowDirection) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)
       * sum[ i_flowDirection, ACBRANCHLOSSESDIRECTED(currTP,br,i_flowDirection) ]
     ]
+ sum[ br $ { ACBranch(currTP,br) and ClosedBranch(currTP,br) }
       , i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)
       * ACBranchFixedLoss(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineLossWeight(t1MixCstr,br)
       * HVDCLINKLOSSES(currTP,br)
     ]
+ sum[ br $ { HVDClink(currTP,br) and ClosedBranch(currTP,br) }
       , i_type1MixedConstraintHVDCLineFixedLossWeight(t1MixCstr,br)
       * HVDClinkFixedLoss(currTP,br)
     ]
+ sum[ i_bid $ Bid(currTP,i_bid)
       , i_type1MixedConstraintPurWeight(t1MixCstr,i_bid)
       * PURCHASE(currTP,i_bid)
     ]
+ DEFICITTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
=g=
  Type1MixedConstraintLimit1(currTP,t1MixCstr) * (1 - MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr))
+ Type1MixedConstraintLimit2(currTP,t1MixCstr) * MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr)
  ;

* Integer equivalent of Type 1 mixed constraint definition with EQ sense (3.6.1.1b_MIP)
Type1MixedConstraintEQ_MIP(Type1MixedConstraint(currTP,t1MixCstr)) $ { useMixedConstraint(currTP) and
                                                                       (Type1MixedConstraintSense(currTP,t1MixCstr) = 0) and
                                                                       useMixedConstraintMIP(currTP)
                                                                     }..
  i_type1MixedConstraintVarWeight(t1MixCstr) * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
+ sum[ o $ PositiveEnergyOffer(currTP,o)
       , i_type1MixedConstraintGenWeight(t1MixCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,i_reserveClass,i_reserveType) $ offer(currTP,o)
       , i_type1MixedConstraintResWeight(t1MixCstr,o,i_reserveClass,i_reserveType)
       * RESERVE(currTP,o,i_reserveClass,i_reserveType)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineWeight(t1MixCstr,br)
       * HVDCLINKFLOW(currTP,br)
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineWeight(t1MixCstr,br)
       * sum[ i_flowDirection, ACBRANCHFLOWDIRECTED(currTP,br,i_flowDirection) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)
       * sum[ i_flowDirection, ACBRANCHLOSSESDIRECTED(currTP,br,i_flowDirection) ]
     ]
+ sum[ br $ { ACBranch(currTP,br) and ClosedBranch(currTP,br) }
       , i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)
       * ACBranchFixedLoss(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineLossWeight(t1MixCstr,br)
       * HVDCLINKLOSSES(currTP,br)
     ]
+ sum[ br $ { HVDClink(currTP,br) and ClosedBranch(currTP,br) }
       , i_type1MixedConstraintHVDCLineFixedLossWeight(t1MixCstr,br)
       * HVDClinkFixedLoss(currTP,br)
     ]
+ sum[ i_bid $ Bid(currTP,i_bid)
       , i_type1MixedConstraintPurWeight(t1MixCstr,i_bid)
       * PURCHASE(currTP,i_bid)
     ]
+ DEFICITTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
- SURPLUSTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
=e=
  Type1MixedConstraintLimit1(currTP,t1MixCstr) * (1 - MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr))
+ Type1MixedConstraintLimit2(currTP,t1MixCstr) * MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr)
  ;

* Generic security constraint with LE sense
GenericSecurityConstraintLE(currTP,gnrcCstr) $ (GenericConstraintSense(currTP,gnrcCstr) = -1)..
  sum[ o $ PositiveEnergyOffer(currTP,o)
       , GenericEnergyOfferConstraintFactors(currTP,gnrcCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,i_reserveClass,i_reserveType) $ offer(currTP,o)
       , GenericReserveOfferConstraintFactors(currTP,gnrcCstr,o,i_reserveClass,i_reserveType)
       * RESERVE(currTP,o,i_reserveClass,i_reserveType)
     ]
+ sum[ i_bid $ Bid(currTP,i_bid)
     , GenericEnergyBidConstraintFactors(currTP,gnrcCstr,i_bid)
     * PURCHASE(currTP,i_bid)
     ]
+ sum[ (i_bid,i_reserveClass) $ Bid(currTP,i_bid)
       , GenericILReserveBidConstraintFactors(currTP,gnrcCstr,i_bid,i_reserveClass)
       * PURCHASEILR(currTP,i_bid,i_reserveClass)
     ]
+ sum[ br $ { [ACBranch(currTP,br) or HVDClink(currTP,br)] and ClosedBranch(currTP,br) }
       , GenericBranchConstraintFactors(currTP,gnrcCstr,br)
       * (ACBRANCHFLOW(currTP,br) + HVDCLINKFLOW(currTP,br))
     ]
- SURPLUSGENERICCONSTRAINT(currTP,gnrcCstr)
=l=
  GenericConstraintLimit(currTP,gnrcCstr)
  ;

* Generic security constraint with GE sense
GenericSecurityConstraintGE(currTP,gnrcCstr) $ (GenericConstraintSense(currTP,gnrcCstr) = 1)..
  sum[ o $ PositiveEnergyOffer(currTP,o)
       , GenericEnergyOfferConstraintFactors(currTP,gnrcCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,i_reserveClass,i_reserveType) $ offer(currTP,o)
       , GenericReserveOfferConstraintFactors(currTP,gnrcCstr,o,i_reserveClass,i_reserveType)
       * RESERVE(currTP,o,i_reserveClass,i_reserveType)
     ]
+ sum[ i_bid $ Bid(currTP,i_bid)
       , GenericEnergyBidConstraintFactors(currTP,gnrcCstr,i_bid)
       * PURCHASE(currTP,i_bid)
     ]
+ sum[ (i_bid,i_reserveClass) $ Bid(currTP,i_bid)
       , GenericILReserveBidConstraintFactors(currTP,gnrcCstr,i_bid,i_reserveClass)
       * PURCHASEILR(currTP,i_bid,i_reserveClass)
     ]
+ sum[ br $ { [ACBranch(currTP,br) or HVDClink(currTP,br)] and ClosedBranch(currTP,br) }
       , GenericBranchConstraintFactors(currTP,gnrcCstr,br)
       * (ACBRANCHFLOW(currTP,br) + HVDCLINKFLOW(currTP,br))
     ]
+ DEFICITGENERICCONSTRAINT(currTP,gnrcCstr)
=g=
  GenericConstraintLimit(currTP,gnrcCstr)
  ;

* Generic security constraint with EQ sense
GenericSecurityConstraintEQ(currTP,gnrcCstr) $ (GenericConstraintSense(currTP,gnrcCstr) = 0)..
  sum[ o $ PositiveEnergyOffer(currTP,o), GenericEnergyOfferConstraintFactors(currTP,gnrcCstr,o) * GENERATION(currTP,o)
     ]
+ sum[ (o,i_reserveClass,i_reserveType) $ offer(currTP,o)
       , GenericReserveOfferConstraintFactors(currTP,gnrcCstr,o,i_reserveClass,i_reserveType)
       * RESERVE(currTP,o,i_reserveClass,i_reserveType)
     ]
+ sum[ i_bid $ Bid(currTP,i_bid)
       , GenericEnergyBidConstraintFactors(currTP,gnrcCstr,i_bid)
       * PURCHASE(currTP,i_bid)
     ]
+ sum[ (i_bid,i_reserveClass) $ Bid(currTP,i_bid)
       , GenericILReserveBidConstraintFactors(currTP,gnrcCstr,i_bid,i_reserveClass)
       * PURCHASEILR(currTP,i_bid,i_reserveClass)
     ]
+ sum[ br $ { [ACBranch(currTP,br) or HVDClink(currTP,br)] and ClosedBranch(currTP,br) }
       , GenericBranchConstraintFactors(currTP,gnrcCstr,br)
      * (ACBRANCHFLOW(currTP,br) + HVDCLINKFLOW(currTP,br))
     ]
+ DEFICITGENERICCONSTRAINT(currTP,gnrcCstr)
- SURPLUSGENERICCONSTRAINT(currTP,gnrcCstr)
=e=
  GenericConstraintLimit(currTP,gnrcCstr)
  ;

* Model declarations
Model vSPD /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, PurchaseBidDefintion
  GenerationRampUp, GenerationRampDown
* Primary-secondary ramping constraints
  GenerationRampUp_PS, GenerationRampDown_PS
* Network
  HVDClinkMaximumFlow, HVDClinkLossDefinition
  HVDClinkFlowDefinition, LambdaDefinition
  DCNodeNetInjection, ACnodeNetInjectionDefinition1
  ACnodeNetInjectionDefinition2, ACBranchMaximumFlow
  ACBranchFlowDefinition, LinearLoadFlow
  ACBranchBlockLimit, ACDirectedBranchFlowDefinition
  ACBranchLossCalculation, ACDirectedBranchLossDefinition
* Risk and Reserve
  HVDCIslandRiskCalculation, HVDCRecCalculation
  GenIslandRiskCalculation, ManualIslandRiskCalculation
  PLSRReserveProportionMaximum, ReserveOfferDefinition
  ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum
  PurchaseBidReserveMaximum, SupplyDemandReserveRequirement
* Risk Offset calculation
  RiskOffsetCalculation
  RiskOffsetCalculation_DCCE
  RiskOffsetCalculation_DCECE
* Island risk definitions
  MaximumIslandRiskDefinition
  MaximumIslandRiskDefinition_CE
  MaximumIslandRiskDefinition_ECE
* Include HVDC secondary risk constraints
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_Manual
* Branch security constraints
  BranchSecurityConstraintLE, BranchSecurityConstraintGE, BranchSecurityConstraintEQ
* AC node security constraints
  ACnodeSecurityConstraintLE, ACnodeSecurityConstraintGE, ACnodeSecurityConstraintEQ
* Market node security constraints
  MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
* Mixed constraints
  Type1MixedConstraintLE, Type1MixedConstraintGE, Type1MixedConstraintEQ
  Type2MixedConstraintLE, Type2MixedConstraintGE, Type2MixedConstraintEQ
* Generic constraints
  GenericSecurityConstraintLE, GenericSecurityConstraintGE, GenericSecurityConstraintEQ
* ViolationCost
  TotalViolationCostDefinition
* Generator island risk calculation considering more than one offer per generator
  GenIslandRiskCalculation_NonPS, GenIslandRiskCalculation_PS
  HVDCIslandSecRiskCalculation_GEN_NonPS, HVDCIslandSecRiskCalculation_GEN_PS
  / ;

Model vSPD_MIP /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, PurchaseBidDefintion
  GenerationRampUp, GenerationRampDown
* Primary-secondary ramping constraints
  GenerationRampUp_PS, GenerationRampDown_PS
* Network
  HVDClinkMaximumFlow, HVDClinkLossDefinition
  HVDClinkFlowDefinition, LambdaDefinition
  DCNodeNetInjection, ACnodeNetInjectionDefinition1
  ACnodeNetInjectionDefinition2, ACBranchMaximumFlow
  ACBranchFlowDefinition, LinearLoadFlow
  ACBranchBlockLimit, ACDirectedBranchFlowDefinition
  ACBranchLossCalculation, ACDirectedBranchLossDefinition
  ACDirectedBranchFlowIntegerDefinition1, ACDirectedBranchFlowIntegerDefinition2
  LambdaIntegerDefinition1, LambdaIntegerDefinition2
* Risk and Reserve
  HVDCIslandRiskCalculation, HVDCRecCalculation
  GenIslandRiskCalculation, ManualIslandRiskCalculation
  PLSRReserveProportionMaximum, ReserveOfferDefinition
  ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum
  PurchaseBidReserveMaximum, SupplyDemandReserveRequirement
* Risk Offset calculation
  RiskOffsetCalculation
  RiskOffsetCalculation_DCCE
  RiskOffsetCalculation_DCECE
* Island risk definitions
  MaximumIslandRiskDefinition
  MaximumIslandRiskDefinition_CE
  MaximumIslandRiskDefinition_ECE
* Include HVDC secondary risk constraints
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_Manual
* Branch security constraints
  BranchSecurityConstraintLE, BranchSecurityConstraintGE, BranchSecurityConstraintEQ
* AC node security constraints
  ACnodeSecurityConstraintLE, ACnodeSecurityConstraintGE, ACnodeSecurityConstraintEQ
* Market node security constraints
  MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
* Mixed constraints
  Type1MixedConstraintMIP, Type1MixedConstraintLE_MIP, Type1MixedConstraintGE_MIP
  Type1MixedConstraintEQ_MIP, Type2MixedConstraintLE, Type2MixedConstraintGE, Type2MixedConstraintEQ
* Generic constraints
  GenericSecurityConstraintLE, GenericSecurityConstraintGE, GenericSecurityConstraintEQ
* ViolationCost
  TotalViolationCostDefinition
* Set of integer constraints on the HVDC link to incorporate the allowance of HVDC roundpower
  HVDClinkFlowIntegerDefinition1, HVDClinkFlowIntegerDefinition2
  HVDClinkFlowIntegerDefinition3, HVDClinkFlowIntegerDefinition4
* Generator island risk calculation considering more than one offer per generator
  GenIslandRiskCalculation_NonPS, GenIslandRiskCalculation_PS
  HVDCIslandSecRiskCalculation_GEN_NonPS, HVDCIslandSecRiskCalculation_GEN_PS
  / ;

Model vSPD_BranchFlowMIP /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, PurchaseBidDefintion
  GenerationRampUp, GenerationRampDown
* Primary-secondary ramping constraints
  GenerationRampUp_PS, GenerationRampDown_PS
* Network
  HVDClinkMaximumFlow, HVDClinkLossDefinition
  HVDClinkFlowDefinition, LambdaDefinition
  DCNodeNetInjection, ACnodeNetInjectionDefinition1
  ACnodeNetInjectionDefinition2, ACBranchMaximumFlow
  ACBranchFlowDefinition, LinearLoadFlow
  ACBranchBlockLimit, ACDirectedBranchFlowDefinition
  ACBranchLossCalculation, ACDirectedBranchLossDefinition
  ACDirectedBranchFlowIntegerDefinition1, ACDirectedBranchFlowIntegerDefinition2
  LambdaIntegerDefinition1, LambdaIntegerDefinition2
* Risk and Reserve
  HVDCIslandRiskCalculation, HVDCRecCalculation
  GenIslandRiskCalculation, ManualIslandRiskCalculation
  PLSRReserveProportionMaximum, ReserveOfferDefinition
  ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum
  PurchaseBidReserveMaximum, SupplyDemandReserveRequirement
* Risk offset calculation
  RiskOffsetCalculation
  RiskOffsetCalculation_DCCE
  RiskOffsetCalculation_DCECE
* Island risk definitions
  MaximumIslandRiskDefinition
  MaximumIslandRiskDefinition_CE
  MaximumIslandRiskDefinition_ECE
* Include HVDC secondary risk constraints
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_Manual
* Branch security constraints
  BranchSecurityConstraintLE, BranchSecurityConstraintGE, BranchSecurityConstraintEQ
* AC node security constraints
  ACnodeSecurityConstraintLE, ACnodeSecurityConstraintGE, ACnodeSecurityConstraintEQ
* Market node security constraints
  MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
* Mixed constraints
  Type1MixedConstraintLE, Type1MixedConstraintGE, Type1MixedConstraintEQ
  Type2MixedConstraintLE, Type2MixedConstraintGE, Type2MixedConstraintEQ
* Generic constraints
  GenericSecurityConstraintLE, GenericSecurityConstraintGE, GenericSecurityConstraintEQ
* ViolationCost
  TotalViolationCostDefinition
* Set of intrger constraints on the HVDC link to incorporate the allowance of HVDC roundpower
  HVDClinkFlowIntegerDefinition1, HVDClinkFlowIntegerDefinition2
  HVDClinkFlowIntegerDefinition3, HVDClinkFlowIntegerDefinition4
* Generator island risk calculation considering more than one offer per generator
  GenIslandRiskCalculation_NonPS, GenIslandRiskCalculation_PS
  HVDCIslandSecRiskCalculation_GEN_NonPS, HVDCIslandSecRiskCalculation_GEN_PS
  / ;

Model vSPD_MixedConstraintMIP /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, PurchaseBidDefintion
  GenerationRampUp, GenerationRampDown
* Primary-secondary ramping constraints
  GenerationRampUp_PS, GenerationRampDown_PS
* Network
  HVDClinkMaximumFlow, HVDClinkLossDefinition
  HVDClinkFlowDefinition, LambdaDefinition
  DCNodeNetInjection, ACnodeNetInjectionDefinition1
  ACnodeNetInjectionDefinition2, ACBranchMaximumFlow
  ACBranchFlowDefinition, LinearLoadFlow
  ACBranchBlockLimit, ACDirectedBranchFlowDefinition
  ACBranchLossCalculation, ACDirectedBranchLossDefinition
* Risk and Reserve
  HVDCIslandRiskCalculation, HVDCRecCalculation
  GenIslandRiskCalculation, ManualIslandRiskCalculation
  PLSRReserveProportionMaximum, ReserveOfferDefinition
  ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum
  PurchaseBidReserveMaximum, SupplyDemandReserveRequirement
* Risk offset calculation
  RiskOffsetCalculation
  RiskOffsetCalculation_DCCE
  RiskOffsetCalculation_DCECE
* Island risk definition for different CE and ECE CVPs
  MaximumIslandRiskDefinition
  MaximumIslandRiskDefinition_CE
  MaximumIslandRiskDefinition_ECE
* Include HVDC secondary risk constraints
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_Manual
* Branch security constraints
  BranchSecurityConstraintLE, BranchSecurityConstraintGE, BranchSecurityConstraintEQ
* AC node security constraints
  ACnodeSecurityConstraintLE, ACnodeSecurityConstraintGE, ACnodeSecurityConstraintEQ
* Market node security constraints
  MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
* Mixed constraints
  Type1MixedConstraintMIP, Type1MixedConstraintLE_MIP, Type1MixedConstraintGE_MIP
  Type1MixedConstraintEQ_MIP, Type2MixedConstraintLE, Type2MixedConstraintGE, Type2MixedConstraintEQ
* Generic constraints
  GenericSecurityConstraintLE, GenericSecurityConstraintGE, GenericSecurityConstraintEQ
* ViolationCost
  TotalViolationCostDefinition
* Generator island risk calculation considering more than one offer per generator
  GenIslandRiskCalculation_NonPS, GenIslandRiskCalculation_PS
  HVDCIslandSecRiskCalculation_GEN_NonPS, HVDCIslandSecRiskCalculation_GEN_PS
  / ;

Model vSPD_FTR /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion
* Network
  HVDClinkMaximumFlow, DCNodeNetInjection
  ACNodeNetInjectionDefinition1, ACNodeNetInjectionDefinition2
  ACBranchMaximumFlow, ACBranchFlowDefinition, LinearLoadFlow
* Branch security constraints
  BranchSecurityConstraintLE
* ViolationCost
  TotalViolationCostDefinition
  / ;
