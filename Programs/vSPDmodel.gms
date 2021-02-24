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
* Last modified on:     24 Feb 2021
*                       Correcting the excess reserve sharing penalty
*                       by adding RESERVESHAREEFFECTIVE_CE and ECE variables
*
*=====================================================================================

$ontext
Directory of code sections in vSPDmodel.gms:
  1. Declare sets and parameters for all symbols to be loaded from daily GDX files
  2. Declare additional sets and parameters used throughout the model
  3. Declare model variables and constraints, and initialise constraints

Aliases to be aware of:
  i_dateTime = dt                           i_tradePeriod = tp = tp1
  i_island = ild, ild1                      i_bus = b, b1, toB, frB
  i_node = n, n1                            i_offer = o, o1
  i_trader = trdr                           i_tradeBlock= trdBlk
  i_branch = br, br1                        i_branchConstraint = brCstr
  i_ACnodeConstraint = ACnodeCstr           i_MnodeConstraint = MnodeCstr
  i_energyOfferComponent = NRGofrCmpnt      i_PLSRofferComponent = PLSofrCmpnt
  i_TWDRofferComponent = TWDofrCmpnt        i_ILRofferComponent = ILofrCmpnt
  i_energyBidComponent = NRGbidCmpnt        i_ILRbidComponent = ILbidCmpnt
  i_type1MixedConstraint = t1MixCstr        i_type2MixedConstraint = t2MixCstr
  i_type1MixedConstraintRHS = t1MixCstrRHS  i_genericConstraint = gnrcCstr
  i_lossSegment = los, los1                 i_scarcityArea = sarea
  i_bid = bd, bd1                           i_flowDirection = fd, fd1
  i_reserveType = resT                      i_reserveClass = resC
  i_riskClass = riskC                       i_constraintRHS = CstrRHS
  i_riskParameter = riskPar                 i_dczone =  z, z1
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
  i_scarcityArea(*)                        'Area to which scarcity pricing may apply'
* NMIR update
  i_dczone(*)                              'Defined reverse reserve sharing zone for HVDC sent flow: RP -> round power zone, NR -> no reverse zone, RZ -> reverse zone'
  i_riskGroup(*)                           'Set representing a collection of generation and reserve offers treated as a group risk'

  ;

* Aliases
Alias (i_dateTime,dt),                      (i_tradePeriod,tp,tp1),             (i_island,ild,ild1)
      (i_bus,b,b1,toB,frB),                 (i_node,n,n1),                      (i_offer,o,o1)
      (i_trader,trdr),                      (i_tradeBlock,trdBlk),              (i_branch,br,br1)
      (i_branchConstraint,brCstr),          (i_ACnodeConstraint,ACnodeCstr),    (i_MnodeConstraint,MnodeCstr)
      (i_energyOfferComponent,NRGofrCmpnt), (i_PLSRofferComponent,PLSofrCmpnt), (i_TWDRofferComponent,TWDofrCmpnt)
      (i_ILRofferComponent,ILofrCmpnt),     (i_energyBidComponent,NRGbidCmpnt), (i_ILRbidComponent,ILbidCmpnt)
      (i_type1MixedConstraint,t1MixCstr),   (i_type2MixedConstraint,t2MixCstr), (i_type1MixedConstraintRHS,t1MixCstrRHS)
      (i_genericConstraint,gnrcCstr),       (i_scarcityArea,sarea),             (i_lossSegment,los,los1,bp,bp1,rsbp,rsbp1)
      (i_bid,bd,bd1),                       (i_flowDirection,fd,fd1,rd,rd1),    (i_reserveType,resT)
      (i_reserveClass,resC),                (i_riskClass,riskC),                (i_constraintRHS,CstrRHS)
      (i_riskParameter,riskPar),            (i_offerParam,offerPar),            (i_dczone,z,z1,rrz,rrz1)
      (i_riskGroup,rg,rg1)
  ;

Sets
* 16 multi-dimensional sets, subsets, and mapping sets - membership is populated via loading from GDX file in vSPDsolve.gms
  i_dateTimeTradePeriodMap(dt,tp)                                   'Mapping of dateTime set to the tradePeriod set'
  i_tradePeriodNode(tp,n)                                           'Node definition for the different trading periods'
  i_tradePeriodOfferNode(tp,o,n)                                    'Offers and the corresponding offer node for the different trading periods'
  i_tradePeriodOfferTrader(tp,o,trdr)                               'Offers and the corresponding trader for the different trading periods'
  i_tradePeriodBidNode(tp,bd,n)                                     'Bids and the corresponding node for the different trading periods'
  i_tradePeriodBidTrader(tp,bd,trdr)                                'Bids and the corresponding trader for the different trading periods'
  i_tradePeriodBus(tp,b)                                            'Bus definition for the different trading periods'
  i_tradePeriodNodeBus(tp,n,b)                                      'Node bus mapping for the different trading periods'
  i_tradePeriodBusIsland(tp,b,ild)                                  'Bus island mapping for the different trade periods'
  i_tradePeriodBranchDefn(tp,br,frB,toB)                            'Branch definition for the different trading periods'
  i_tradePeriodRiskGenerator(tp,o)                                  'Set of generators (offers) that can set the risk in the different trading periods'
  i_tradePeriodType1MixedConstraint(tp,t1MixCstr)                   'Set of mixed constraints defined for the different trading periods'
  i_tradePeriodType2MixedConstraint(tp,t2MixCstr)                   'Set of mixed constraints defined for the different trading periods'
  i_type1MixedConstraintReserveMap(t1MixCstr,ild,resC,riskC)        'Mapping of mixed constraint variables to reserve-related data'
  i_type1MixedConstraintBranchCondition(t1MixCstr,br)               'Set of mixed constraints that have limits conditional on branch flows'
  i_tradePeriodGenericConstraint(tp,gnrcCstr)                       'Generic constraints defined for the different trading periods'
* 1 set loaded from GDX with conditional load statement in vSPDsolve.gms at execution time
  i_tradePeriodPrimarySecondaryOffer(tp,o,o1)                       'Primary-secondary offer mapping for the different trading periods'
* MODD Modification
  i_tradePeriodDispatchableBid(tp,bd)                               'Set of dispatchable bids'
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
  i_tradePeriodEnergyBid(tp,bd,trdBlk,NRGbidCmpnt)                  'Energy bids for the different trading periods'
  i_tradePeriodSustainedILRbid(tp,bd,trdBlk,ILbidCmpnt)             'Sustained ILR bids for the different trading periods'
  i_tradePeriodFastILRbid(tp,bd,trdBlk,ILbidCmpnt)                  'Fast ILR bids for the different trading periods'
* Network data
  i_tradePeriodHVDCNode(tp,n)                                       'HVDC node for the different trading periods'
  i_tradePeriodReferenceNode(tp,n)                                  'Reference nodes for the different trading periods'
  i_tradePeriodHVDCBranch(tp,br)                                    'HVDC branch indicator for the different trading periods'
  i_tradePeriodBranchParameter(tp,br,i_branchParameter)             'Branch resistance, reactance, fixed losses and number of loss tranches for the different time periods'
  i_tradePeriodBranchCapacity(tp,br)                                'Branch capacity for the different trading periods in MW'
  i_tradePeriodBranchCapacityDirected(tp,br,fd)                     'Branch directed capacity for the different trading periods in MW (Branch Reverse Ratings)'
  i_tradePeriodBranchOpenStatus(tp,br)                              'Branch open status for the different trading periods, 1 = Open'
  i_noLossBranch(los,i_lossParameter)                               'Loss parameters for no loss branches'
  i_AClossBranch(los,i_lossParameter)                               'Loss parameters for AC loss branches'
  i_HVDClossBranch(los,i_lossParameter)                             'Loss parameters for HVDC loss branches'
  i_tradePeriodNodeBusAllocationFactor(tp,n,b)                      'Allocation factor of market node quantities to bus for the different trading periods'
  i_tradePeriodBusElectricalIsland(tp,b)                            'Electrical island status of each bus for the different trading periods (0 = Dead)'
* Risk/Reserve data
  i_tradePeriodRiskParameter(tp,ild,resC,riskC,riskPar)             'Risk parameters for the different trading periods (From RMT)'
  i_tradePeriodManualRisk(tp,ild,resC)                              'Manual risk set for the different trading periods'
* Branch constraint data
  i_tradePeriodBranchConstraintFactors(tp,brCstr,br)                'Branch constraint factors (sensitivities) for the different trading periods'
  i_tradePeriodBranchConstraintRHS(tp,brCstr,CstrRHS)               'Branch constraint sense and limit for the different trading periods'
* AC node constraint data
  i_tradePeriodACnodeConstraintFactors(tp,ACnodeCstr,n)             'AC node constraint factors (sensitivities) for the different trading periods'
  i_tradePeriodACnodeConstraintRHS(tp,ACnodeCstr,CstrRHS)           'AC node constraint sense and limit for the different trading periods'
* Market node constraint data
  i_tradePeriodMNodeEnergyOfferConstraintFactors(tp,MnodeCstr,o)                'Market node energy offer constraint factors for the different trading periods'
  i_tradePeriodMNodeReserveOfferConstraintFactors(tp,MnodeCstr,o,resC,resT)     'Market node reserve offer constraint factors for the different trading periods'
  i_tradePeriodMNodeEnergyBidConstraintFactors(tp,MnodeCstr,bd)                 'Market node energy bid constraint factors for the different trading periods'
  i_tradePeriodMNodeILReserveBidConstraintFactors(tp,MnodeCstr,bd,resC)         'Market node IL reserve bid constraint factors for the different trading periods'
  i_tradePeriodMNodeConstraintRHS(tp,MnodeCstr,CstrRHS)                         'Market node constraint sense and limit for the different trading periods'
* Mixed constraint data
  i_type1MixedConstraintVarWeight(t1MixCstr)                                    'Type 1 mixed constraint variable weights'
  i_type1MixedConstraintGenWeight(t1MixCstr,o)                                  'Type 1 mixed constraint generator weights'
  i_type1MixedConstraintResWeight(t1MixCstr,o,resC,resT)                        'Type 1 mixed constraint reserve weights'
  i_type1MixedConstraintHVDClineWeight(t1MixCstr,br)                            'Type 1 mixed constraint HVDC branch flow weights'
  i_tradePeriodType1MixedConstraintRHSParameters(tp,t1MixCstr,t1MixCstrRHS)     'Type 1 mixed constraint RHS parameters'
  i_type2MixedConstraintLHSParameters(t2MixCstr,t1MixCstr)                      'Type 2 mixed constraint LHS weights'
  i_tradePeriodType2MixedConstraintRHSParameters(tp,t2MixCstr,CstrRHS)          'Type 2 mixed constraint RHS parameters'
* Generic constraint data
  i_tradePeriodGenericEnergyOfferConstraintFactors(tp,gnrcCstr,o)               'Generic constraint offer constraint factors for the different trading periods'
  i_tradePeriodGenericReserveOfferConstraintFactors(tp,gnrcCstr,o,resC,resT)    'Generic constraint reserve offer constraint factors for the different trading periods'
  i_tradePeriodGenericEnergyBidConstraintFactors(tp,gnrcCstr,bd)                'Generic constraint energy bid constraint factors for the different trading periods'
  i_tradePeriodGenericILReserveBidConstraintFactors(tp,gnrcCstr,bd,resC)        'Generic constraint IL reserve bid constraint factors for the different trading periods'
  i_tradePeriodGenericBranchConstraintFactors(tp,gnrcCstr,br)                   'Generic constraint energy offer constraint factors for the different trading periods'
  i_tradePeriodGenericConstraintRHS(tp,gnrcCstr,CstrRHS)                        'Generic constraint sense and limit for the different trading periods'
* 11 parameters loaded from GDX with conditional load statement at execution time
  i_tradePeriodAllowHVDCRoundpower(tp)                              'Flag to allow roundpower on the HVDC (1 = Yes)'
  i_tradePeriodManualRisk_ECE(tp,ild,resC)                          'Manual ECE risk set for the different trading periods'
  i_tradePeriodHVDCSecRiskEnabled(tp,ild,riskC)                     'Flag indicating if the HVDC secondary risk is enabled (1 = Yes)'
  i_tradePeriodHVDCSecRiskSubtractor(tp,ild)                        'Ramp up capability on the HVDC pole that is not the secondary risk'
  i_type1MixedConstraintAClineWeight(t1MixCstr,br)                  'Type 1 mixed constraint AC branch flow weights'
  i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)              'Type 1 mixed constraint AC branch loss weights'
  i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)         'Type 1 mixed constraint AC branch fixed losses weight'
  i_type1MixedConstraintHVDClineLossWeight(t1MixCstr,br)            'Type 1 mixed constraint HVDC branch loss weights'
  i_type1MixedConstraintHVDClineFixedLossWeight(t1MixCstr,br)       'Type 1 mixed constraint HVDC branch fixed losses weight'
  i_type1MixedConstraintPurWeight(t1MixCstr,bd)                     'Type 1 mixed constraint demand bid weights'
  i_tradePeriodReserveClassGenerationMaximum(tp,o,resC)             'MW used to determine factor to adjust maximum reserve of a reserve class'
* Virtual reserve
 i_tradePeriodVROfferMax(tp,ild,resC)                               'Maximum MW of the virtual reserve offer'
 i_tradePeriodVROfferPrice(tp,ild,resC)                             'Price of the virtual reserve offer'
* Scarcity pricing
 i_tradePeriodScarcitySituationExists(tp,sarea)                     'Flag to indicate that a scarcity situation exists (1 = Yes)'
 i_tradePeriodGWAPFloor(tp,sarea)                                   'Floor price for the scarcity situation in scarcity area'
 i_tradePeriodGWAPCeiling(tp,sarea)                                 'Ceiling price for the scarcity situation in scarcity area'
 i_tradePeriodGWAPPastDaysAvg(tp,ild)                               'Average GWAP over past days - number of periods in GWAP count'
 i_tradePeriodGWAPCountForAvg(tp,ild)                               'Number of periods used for the i_gwapPastDaysAvg'
 i_tradePeriodGWAPThreshold(tp,ild)                                 'Threshold on previous 336 trading period GWAP - cumulative price threshold'

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
  disconnectedNodePriceCorrection          'Flag to apply price correction methods to disconnected node'
  tradePeriodReports                       'Specify 1 for reports at trading period level, 0 otherwise , no longer used?'

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
  pole                                                              'HVDC poles'
  currTP(tp)                                                        'Current trading period'
* Offer
  offer(tp,o)                                                       'Offers defined for the current trading period'
  offerNode(tp,o,n)                                                 'Mapping of the offers to the nodes for the current trading period'
  validGenerationOfferBlock(tp,o,trdBlk)                            'Valid trade blocks for the respective generation offers'
  validReserveOfferBlock(tp,o,trdBlk,resC,resT)                     'Valid trade blocks for the respective reserve offers by class and type'
  PreviousMW(o)                                                     'MW output of offer to be used as initial MW of the next trading period if necessary'
  PositiveEnergyOffer(tp,o)                                         'Postive energy offers defined for the current trading period'
* Set for primary secondary offers
  PrimarySecondaryOffer(tp,o,o1)                                    'Primary-secondary offer mapping for the current trading period'
* Bid
  Bid(tp,bd)                                                        'Bids defined for the current trading period'
  BidNode(tp,bd,n)                                                  'Mapping of the bids to the nodes for the current trading period'
  validPurchaseBidBlock(tp,bd,trdBlk)                               'Valid trade blocks for the respective purchase bids'
  validPurchaseBidILRBlock(tp,bd,trdBlk,resC)                       'Valid trade blocks for the respective purchase bids ILR'
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
  ACBranchSendingBus(tp,br,b,fd)                                    'Sending (From) bus of AC branch in forward and backward direction'
  ACBranchReceivingBus(tp,br,b,fd)                                  'Receiving (To) bus of AC branch in forward and backward direction'
  HVDClinkSendingBus(tp,br,b)                                       'Sending (From) bus of HVDC link'
  HVDClinkReceivingBus(tp,br,toB)                                   'Receiving (To) bus of HVDC link'
  HVDClinkBus(tp,br,b)                                              'Sending or Receiving bus of HVDC link'
  HVDClink(tp,br)                                                   'HVDC links (branches) defined for the current trading period'
  HVDCpoles(tp,br)                                                  'DC transmission between Benmore and Hayward'
  HVDCHalfPoles(tp,br)                                              'Connection DC Pole 1 between AC and DC systems at Benmore and Haywards'
  HVDCpoleDirection(tp,br,fd)                                       'Direction defintion for HVDC poles S->N : Forward and N->S : Southward'
  ACBranch(tp,br)                                                   'AC branches defined for the current trading period'
  validLossSegment(tp,br,los,fd)                                    'Valid loss segments for a branch'
  lossBranch(tp,br)                                                 'Subset of branches that have non-zero loss factors'
* Mapping set of branches to HVDC pole
  HVDCpoleBranchMap(pole,br)                                        'Mapping of HVDC  branch to pole number'
* Risk/Reserve
  RiskGenerator(tp,o)                                               'Set of generators that can set the risk in the current trading period'
  islandRiskGenerator(tp,ild,o)                                     'Mapping of risk generator to island in the current trading period'
  GenRisk(riskC)                                                    'Subset containing generator risks'
  ManualRisk(riskC)                                                 'Subset containting manual risks'
  HVDCrisk(riskC)                                                   'Subset containing DCCE and DCECE risks'
  HVDCSecRisk(riskC)                                                'Subset containing secondary risk of the DCCE and DCECE events'
  PLSRReserveType(resT)                                             'PLSR reserve type'
  TWDRReserveType(resT)                                             'TWDR reserve type'
  ILReserveType(resT)                                               'IL reserve type'
  offerIsland(tp,o,ild)                                             'Mapping of reserve offer to island for the current trading period'
  bidIsland(tp,bd,ild)                                              'Mapping of purchase bid ILR to island for the current trading period'
* Definition of CE and ECE events to support different CE and ECE CVPs
  ContingentEvents(riskC)                                           'Subset of Risk Classes containing contigent event risks'
  ExtendedContingentEvent(riskC)                                    'Subset of Risk Classes containing extended contigent event risk'
* Branch constraint
  BranchConstraint(tp,brCstr)                                       'Set of branch constraints defined for the current trading period'
* AC node constraint
  ACnodeConstraint(tp,ACnodeCstr)                                   'Set of AC node constraints defined for the current trading period'
* Market node constraint
  MNodeConstraint(tp,MnodeCstr)                                     'Set of market node constraints defined for the current trading period'
* Mixed constraint
  Type1MixCstrReserveMap(t1MixCstr,ild,resC,riskC)                  'Mapping of mixed constraint variables to reserve-related data'
  Type1MixedConstraint(tp,t1MixCstr)                                'Set of type 1 mixed constraints defined for the current trading period'
  Type2MixedConstraint(tp,t2MixCstr)                                'Set of type 2 mixed constraints defined for the current trading period'
  Type1MixedConstraintCondition(tp,t1MixCstr)                       'Subset of type 1 mixed constraints that have a condition to check for the use of the alternate limit'
* Generic constraint
  GenericConstraint(tp,gnrcCstr)                                    'Generic constraint defined for the current trading period'
* NMIR update
  rampingConstraint(tp,brCstr)                                      'Subset of branch constraints that limit total HVDC sent from an island due to ramping (5min schedule only)'
  bipoleConstraint(tp,ild,brCstr)                                   'Subset of branch constraints that limit total HVDC sent from an island'
  monopoleConstraint(tp,ild,brCstr,br)                              'Subset of branch constraints that limit the flow on HVDC pole sent from an island'

  riskGroupOffer(tp,rg,o,riskC)                                     'Mappimg of risk group to offers in current trading period for each risk class - SPD version 11.0 update'
  islandRiskGroup(tp,ild,rg,riskC)                                  'Mappimg of risk group to island in current trading period for each risk class - SPD version 11.0 update'
  ;

Parameters
* Offers
  RampRateUp(tp,o)                                                  'The ramping up rate in MW per minute associated with the generation offer (MW/min)'
  RampRateDown(tp,o)                                                'The ramping down rate in MW per minute associated with the generation offer (MW/min)'
  GenerationStart(tp,o)                                             'The MW generation level associated with the offer at the start of a trading period'
  ReserveGenerationMaximum(tp,o)                                    'Maximum generation and reserve capability for the current trading period (MW)'
  WindOffer(tp,o)                                                   'Flag to indicate if offer is from wind generator (1 = Yes)'
  PriceResponsive(tp,o)                                             'Flag to indicate if wind offer is price responsive (1 = Yes)'
  PotentialMW(tp,o)                                                 'Potential max output of Wind offer'
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
  ReserveOfferProportion(tp,o,trdBlk,resC)                          'The percentage of the MW block available for PLSR of class FIR or SIR'
  ReserveOfferPrice(tp,o,trdBlk,resC,resT)                          'The price of the reserve of the different reserve classes and types ($/MW)'
  ReserveOfferMaximum(tp,o,trdBlk,resC,resT)                        'The maximum MW offered reserve for the different reserve classes and types (MW)'
* Demand
  NodeDemand(tp,n)                                                  'Nodal demand for the current trading period in MW'
* Bid
  PurchaseBidMW(tp,bd,trdBlk)                                       'Purchase bid block in MW'
  PurchaseBidPrice(tp,bd,trdBlk)                                    'Purchase bid price in $/MW'
  PurchaseBidILRMW(tp,bd,trdBlk,resC)                               'Purchase bid ILR block in MW for the different reserve classes'
  PurchaseBidILRPrice(tp,bd,trdBlk,resC)                            'Purchase bid ILR price in $/MW for the different reserve classes'
* Network
  branchCapacity(tp,br,fd)                                          'MW capacity of a branch for the current trading period'
  branchResistance(tp,br)                                           'Resistance of the a branch for the current trading period in per unit'
  branchSusceptance(tp,br)                                          'Susceptance (inverse of reactance) of a branch for the current trading period in per unit'
  branchFixedLoss(tp,br)                                            'Fixed loss of the a branch for the current trading period in MW'
  branchLossBlocks(tp,br)                                           'Number of blocks in the loss curve for the a branch in the current trading period'
  lossSegmentMW(tp,br,los,fd)                                       'MW capacity of each loss segment'
  lossSegmentFactor(tp,br,los,fd)                                   'Loss factor of each loss segment'
  ACBranchLossMW(tp,br,los,fd)                                      'MW element of the loss segment curve in MW'
  ACBranchLossFactor(tp,br,los,fd)                                  'Loss factor element of the loss segment curve'
  HVDCBreakPointMWFlow(tp,br,bp,fd)                                 'Value of power flow on the HVDC at the break point'
  HVDCBreakPointMWLoss(tp,br,bp,fd)                                 'Value of variable losses on the HVDC at the break point'
  NodeBusAllocationFactor(tp,n,b)                                   'Allocation factor of market node to bus for the current trade period'
  BusElectricalIsland(tp,b)                                         'Bus electrical island status for the current trade period (0 = Dead)'
* Flag to allow roundpower on the HVDC link
  AllowHVDCRoundpower(tp)                                           'Flag to allow roundpower on the HVDC (1 = Yes)'
* Risk/Reserve
  ReserveClassGenerationMaximum(tp,o,resC)                          'MW used to determine factor to adjust maximum reserve of a reserve class'
  ReserveMaximumFactor(tp,o,resC)                                   'Factor to adjust the maximum reserve of the different classes for the different offers'
  IslandRiskAdjustmentFactor(tp,ild,resC,riskC)                     'Risk adjustment factor for each island, reserve class and risk class'
  FreeReserve(tp,ild,resC,riskC)                                    'MW free reserve for each island, reserve class and risk class'
  HVDCpoleRampUp(tp,ild,resC,riskC)                                 'HVDC pole MW ramp up capability for each island, reserve class and risk class'
  IslandMinimumRisk(tp,ild,resC,riskC)                              'Minimum MW risk level for each island for each reserve class and risk class'
* HVDC secondary risk parameters
  HVDCSecRiskEnabled(tp,ild,riskC)                                  'Flag indicating if the HVDC secondary risk is enabled (1 = Yes)'
  HVDCSecRiskSubtractor(tp,ild)                                     'Ramp up capability on the HVDC pole that is not the secondary risk'
  HVDCSecIslandMinimumRisk(tp,ild,resC,riskC)                       'Minimum risk in each island for the HVDC secondary risk'

* NMIR parameters
* The follwing are new input for NMIR
  reserveRoundPower(tp,resC)                                        'Database flag that disables round power under certain circumstances'
  reserveShareEnabled(tp,resC)                                      'Database flag if reserve class resC is sharable'
  modulationRiskClass(tp,riskC)                                     'HVDC energy modulation due to frequency keeping action'
  roundPower2MonoLevel(tp)                                          'HVDC sent value above which one pole is stopped and therefore FIR cannot use round power'
  bipole2MonoLevel(tp)                                              'HVDC sent value below which one pole is available to start in the opposite direction and therefore SIR can use round power'
  MonopoleMinimum(tp)                                               'The lowest level that the sent HVDC sent can ramp down to when round power is not available.'
  HVDCControlBand(tp,rd)                                            'Modulation limit of the HVDC control system apply to each HVDC direction'
  HVDClossScalingFactor(tp)                                         'Losses used for full voltage mode are adjusted by a factor of (700/500)^2 for reduced voltage operation'
  sharedNFRFactor(tp)                                               'Factor that is applied to [sharedNFRLoad - sharedNFRLoadOffset] as part of the calculation of sharedNFRMax'
  sharedNFRLoadOffset(tp,ild)                                       'Island load that does not provide load damping, e.g., Tiwai smelter load in the South Island. Subtracted from the sharedNFRLoad in the calculation of sharedNFRMax.'
  effectiveFactor(tp,ild,resC,riskC)                                'Estimate of the effectiveness of the shared reserve once it has been received in the risk island.'
  RMTReserveLimitTo(tp,ild,resC)                                    'The shared reserve limit used by RMT when it calculated the NFRs. Applied as a cap to the value that is calculated for SharedNFRMax.'
* The follwing are calculated parameters for NMIR
  reserveShareEnabledOverall(tp)                                    'An internal parameter based on the FIR and SIR enabled, and used as a switch in various places'
  modulationRisk(tp)                                                'Max of HVDC energy modulation due to frequency keeping action'
  roPwrZoneExit(tp,resC)                                            'Above this point there is no guarantee that HVDC sent can be reduced below MonopoleMinimum.'
  sharedNFRLoad(tp,ild)                                             'Island load, calculated in pre-processing from the required load and the bids. Used as an input to the calculation of SharedNFRMax.'
  sharedNFRMax(tp,ild)                                              'Amount of island free reserve that can be shared through HVDC'
  numberOfPoles(tp,ild)                                             'Number of HVDC poles avaialbe to send energy from an island'
  monoPoleCapacity(tp,ild,br)                                       'Maximum capacity of monopole defined by min of branch capacity and monopole constraint RHS'
  biPoleCapacity(tp,ild)                                            'Maximum capacity of bipole defined by bipole constraint RHS'
  HVDCMax(tp,ild)                                                   'Max HVDC flow based on available poles and branch group constraints RHS'
  HVDCCapacity(tp,ild)                                              'Total sent capacity of HVDC based on available poles'
  HVDCResistance(tp,ild)                                            'Estimated resistance of HVDC flow sent from an island'
  HVDClossSegmentMW(tp,ild,los)                                     'MW capacity of each loss segment applied to aggregated HVDC capacity'
  HVDClossSegmentFactor(tp,ild,los)                                 'Loss factor of each loss segment applied to to aggregated HVDC loss'
  HVDCSentBreakPointMWFlow(tp,ild,los)                              'Value of total HVDC sent power flow at the break point               --> lambda segment loss model'
  HVDCSentBreakPointMWLoss(tp,ild,los)                              'Value of ariable losses of the total HVDC sent at the break point    --> lambda segment loss model'
  HVDCReserveBreakPointMWFlow(tp,ild,los)                           'Value of total HVDC sent power flow + reserve at the break point     --> lambda segment loss model'
  HVDCReserveBreakPointMWLoss(tp,ild,los)                           'Value of post-contingent variable HVDC losses at the break point     --> lambda segment loss model'
* The follwing are flag and scalar for testing
  UseShareReserve                                                   'Flag to indicate if the reserve share is applied'
  BigM                                                              'Big M value to be applied for single active segment HVDC loss model' /10000/
* NMIR parameters end

* Branch constraint
  BranchConstraintFactors(tp,brCstr,br)                             'Branch security constraint factors (sensitivities) for the current trading period'
  BranchConstraintSense(tp,brCstr)                                  'Branch security constraint sense for the current trading period (-1:<=, 0:= 1:>=)'
  BranchConstraintLimit(tp,brCstr)                                  'Branch security constraint limit for the current trading period'
* AC node constraint
  ACnodeConstraintFactors(tp,ACnodeCstr,n)                          'AC node security constraint factors (sensitivities) for the current trading period'
  ACnodeConstraintSense(tp,ACnodeCstr)                              'AC node security constraint sense for the current trading period (-1:<=, 0:= 1:>=)'
  ACnodeConstraintLimit(tp,ACnodeCstr)                              'AC node security constraint limit for the current trading period'
* Market node constraint
  MNodeEnergyOfferConstraintFactors(tp,MnodeCstr,o)                 'Market node energy offer constraint factors for the current trading period'
  MNodeReserveOfferConstraintFactors(tp,MnodeCstr,o,resC,resT)      'Market node reserve offer constraint factors for the current trading period'
  MNodeEnergyBidConstraintFactors(tp,MnodeCstr,bd)                  'Market node energy bid constraint factors for the current trading period'
  MNodeILReserveBidConstraintFactors(tp,MnodeCstr,bd,resC)          'Market node IL reserve bid constraint factors for the current trading period'
  MNodeConstraintSense(tp,MnodeCstr)                                'Market node constraint sense for the current trading period'
  MNodeConstraintLimit(tp,MnodeCstr)                                'Market node constraint limit for the current trading period'
* Mixed constraint
  useMixedConstraint(tp)                                            'Flag indicating use of the mixed constraint formulation (1 = Yes)'
  Type1MixedConstraintSense(tp,t1MixCstr)                           'Type 1 mixed constraint sense'
  Type1MixedConstraintLimit1(tp,t1MixCstr)                          'Type 1 mixed constraint limit 1'
  Type1MixedConstraintLimit2(tp,t1MixCstr)                          'Type 1 mixed constraint alternate limit (limit 2)'
  Type2MixedConstraintSense(tp,t2MixCstr)                           'Type 2 mixed constraint sense'
  Type2MixedConstraintLimit(tp,t2MixCstr)                           'Type 2 mixed constraint limit'
* Generic constraint
  GenericEnergyOfferConstraintFactors(tp,gnrcCstr,o)                'Generic constraint energy offer factors for the current trading period'
  GenericReserveOfferConstraintFactors(tp,gnrcCstr,o,resC,resT)     'Generic constraint reserve offer factors for the current trading period'
  GenericEnergyBidConstraintFactors(tp,gnrcCstr,bd)                 'Generic constraint energy bid factors for the current trading period'
  GenericILReserveBidConstraintFactors(tp,gnrcCstr,bd,resC)         'Generic constraint IL reserve bid factors for the current trading period'
  GenericBranchConstraintFactors(tp,gnrcCstr,br)                    'Generic constraint branch factors for the current trading period'
  GenericConstraintSense(tp,gnrcCstr)                               'Generic constraint sense for the current trading period'
  GenericConstraintLimit(tp,gnrcCstr)                               'Generic constraint limit for the current trading period'
* Violation penalties
  DeficitReservePenalty(resC)                      '6s and 60s reserve deficit violation penalty'
* Different CVPs defined for CE and ECE
  DeficitReservePenalty_CE(resC)                   '6s and 60s CE reserve deficit violation penalty'
  DeficitReservePenalty_ECE(resC)                  '6s and 60s ECE reserve deficit violation penalty'
* Post-processing
  useBranchFlowMIP(tp)                             'Flag to indicate if integer constraints are needed in the branch flow model: 1 = Yes'
  useMixedConstraintMIP(tp)                        'Flag to indicate if integer constraints are needed in the mixed constraint formulation: 1 = Yes'
* Virtual reserve
  virtualReserveMax(tp,ild,resC)                   'Maximum MW of virtual reserve offer in each island for each reserve class'
  virtualReservePrice(tp,ild,resC)                 'Price of virtual reserve offer in each island for each reserve class'
  ;

Scalars
* Violation penalties
* These violation penalties are not specified in the model formulation document (ver.4.3) but are specified in the
* document "Resolving Infeasibilities & High Spring Washer Price situations - an overview" available at www.systemoperator.co.nz/n2766,264.html
  deficitBusGenerationPenalty                      'Bus deficit violation penalty'
  surplusBusGenerationPenalty                      'Bus surplus violation penalty'
  deficitBrCstrPenalty                             'Deficit branch group constraint violation penalty'
  surplusBrCstrPenalty                             'Surplus branch group constraint violation penalty'
  deficitGnrcCstrPenalty                           'Deficit generic constraint violation penalty'
  surplusGnrcCstrPenalty                           'Surplus generic constraint violation penalty'
  DeficitRampRatePenalty                           'Deficit ramp rate violation penalty'
  SurplusRampRatePenalty                           'Surplus ramp rate violation penalty'
  deficitACnodeCstrPenalty                         'AC node constraint deficit penalty'
  surplusACnodeCstrPenalty                         'AC node constraint surplus penalty'
  deficitBranchFlowPenalty                         'Deficit branch flow violation penalty'
  surplusBranchFlowPenalty                         'Surplus branch flow violation penalty'
  deficitMnodeCstrPenalty                          'Deficit market node constraint violation penalty'
  surplusMnodeCstrPenalty                          'Surplus market node constraint violation penalty'
  deficitT1MixCstrPenalty                          'Type 1 deficit mixed constraint violation penalty'
  surplusT1MixCstrPenalty                          'Type 1 surplus mixed constraint violation penalty'
* Mixed constraint
  MixedConstraintBigNumber                         'Big number used in the definition of the integer variables for mixed constraints'   /1000 /
  useMixedConstraintRiskOffset                     'Use the risk offset calculation based on mixed constraint formulation (1= Yes)'
* Separate flag for the CE and ECE CVP
  DiffCeECeCVP                                     'Flag to indicate if the separate CE and ECE CVP is applied'
  usePrimSecGenRiskModel                           'Flag to use the revised generator risk model for generators with primary and secondary offers'
  useDSBFDemandBidModel                            'Flag to use the demand model defined under demand-side bidding and forecasting (DSBF) - only applied for PRSS and PRSL run'
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
  ISLANDRISK(tp,ild,resC,riskC)                    'Island MW risk for the different reserve and risk classes'
  GENISLANDRISK(tp,ild,o,resC,riskC)               'Island MW risk for different risk setting generators'
  GENISLANDRISKGROUP(tp,ild,rg,resC,riskC)         'Island MW risk for different risk group - SPD version 11.0'
  HVDCGENISLANDRISK(tp,ild,o,resC,riskC)           'Island MW risk for different risk setting generators + HVDC'
  HVDCMANISLANDRISK(tp,ild,resC,riskC)             'Island MW risk for manual risk + HVDC'
  HVDCREC(tp,ild)                                  'Total net pre-contingent HVDC MW flow received at each island'
  RISKOFFSET(tp,ild,resC,riskC)                    'MW offset applied to the raw risk to account for HVDC pole rampup, AUFLS, free reserve and non-compliant generation'

* NMIR free variables
  HVDCRESERVESENT(tp,ild,resC,rd)                  'Total net post-contingent HVDC MW flow sent from an island applied to each reserve class'
  HVDCRESERVELOSS(tp,ild,resC,rd)                  'Post-contingent HVDC loss of energy + reserve sent from an island applied to each reserve class'
* NMIR free variables end

* Network
  ACNODENETINJECTION(tp,b)                         'MW injection at buses corresponding to AC nodes'
  ACBRANCHFLOW(tp,br)                              'MW flow on undirected AC branch'
  ACNODEANGLE(tp,b)                                'Bus voltage angle'
* Mixed constraint variables
  MIXEDCONSTRAINTVARIABLE(tp,t1MixCstr)            'Mixed constraint variable'

* Demand bids can be either positive or negative from v6.0 of SPD formulation (with DSBF)
* The lower bound of the free variable is updated in vSPDSolve.gms to allow backward compatibility
* Note the formulation now refers to this as Demand. So Demand (in SPD formulation) = Purchase (in vSPD code)
  PURCHASE(tp,bd)                                  'Total MW purchase scheduled'
  PURCHASEBLOCK(tp,bd,trdBlk)                      'MW purchase scheduled from the individual trade blocks of a bid'

  ;

Positive variables
* system cost and benefit
  SYSTEMBENEFIT(tp)                                'Total purchase bid benefit by period'
  SYSTEMCOST(tp)                                   'Total generation and reserve costs by period'
  SYSTEMPENALTYCOST(tp)                            'Total violation costs by period'
  TOTALPENALTYCOST                                 'Total violation costs'
* Generation
  GENERATION(tp,o)                                 'Total MW generation scheduled from an offer'
  GENERATIONBLOCK(tp,o,trdBlk)                     'MW generation scheduled from the individual trade blocks of an offer'
* Purchase
  PURCHASEILR(tp,bd,resC)                          'Total MW ILR provided by purchase bid for the different reserve classes'
  PURCHASEILRBLOCK(tp,bd,trdBlk,resC)              'MW ILR provided by purchase bid for individual trade blocks for the different reserve classes'
* Reserve
  RESERVE(tp,o,resC,resT)                          'MW Reserve scheduled from an offer'
  RESERVEBLOCK(tp,o,trdBlk,resC,resT)              'MW Reserve scheduled from the individual trade blocks of an offer'
  ISLANDRESERVE(tp,ild,resC)                       'Total island cleared reserve'
* NMIR positive variables
  SHAREDNFR(tp,ild)                                'Amount of free load reserve being shared from an island'
  SHAREDRESERVE(tp,ild,resC)                       'Amount of cleared reserve from an island being shared to the other island'
  HVDCSENT(tp,ild)                                 'Directed pre-contingent HVDC MW flow sent from each island'
  HVDCSENTLOSS(tp,ild)                             'Energy loss for  HVDC flow sent from an island'
  RESERVESHAREEFFECTIVE(tp,ild,resC,riskC)         'Effective shared reserve received at island after adjusted for losses and effectiveness factor'
  RESERVESHARERECEIVED(tp,ild,resC,rd)             'Directed shared reserve received at island after adjusted for losses'
  RESERVESHARESENT(tp,ild,resC,rd)                 'Directed shared reserve sent from and island'
  RESERVESHAREPENALTY(tp)                          'Penalty cost for excessive reserve sharing'
* Tuong Nguyen added on 24 Feb 2021 to correct the calculation of RESERVESHAREPENALTY
  RESERVESHAREEFFECTIVE_CE(tp,ild,resC)            'Max effective shared reserve for CE risk received at island after adjusted for losses and effectiveness factor'
  RESERVESHAREEFFECTIVE_ECE(tp,ild,resC)           'Max effective shared reserve for ECE risk received at island after adjusted for losses and effectiveness factor'
* NMIR positive variables end
* Network
  HVDCLINKFLOW(tp,br)                              'MW flow at the sending end scheduled for the HVDC link'
  HVDCLINKLOSSES(tp,br)                            'MW losses on the HVDC link'
  LAMBDA(tp,br,bp)                                 'Non-negative weight applied to the breakpoint of the HVDC link'
  ACBRANCHFLOWDIRECTED(tp,br,fd)                   'MW flow on the directed branch'
  ACBRANCHLOSSESDIRECTED(tp,br,fd)                 'MW losses on the directed branch'
  ACBRANCHFLOWBLOCKDIRECTED(tp,br,los,fd)          'MW flow on the different blocks of the loss curve'
  ACBRANCHLOSSESBLOCKDIRECTED(tp,br,los,fd)        'MW losses on the different blocks of the loss curve'
* Violations
  DEFICITBUSGENERATION(tp,b)                       'Deficit generation at a bus in MW'
  SURPLUSBUSGENERATION(tp,b)                       'Surplus generation at a bus in MW'
  DEFICITRESERVE(tp,ild,resC)                      'Deficit reserve generation in each island for each reserve class in MW'
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
  DEFICITRESERVE_CE(tp,ild,resC)                   'Deficit CE reserve generation in each island for each reserve class in MW'
  DEFICITRESERVE_ECE(tp,ild,resC)                  'Deficit ECE reserve generation in each island for each reserve class in MW'
* Scarcity pricing updates
  VIRTUALRESERVE(tp,ild,resC)                      'MW scheduled from virtual reserve'
  ;

Binary variables
  MIXEDCONSTRAINTLIMIT2SELECT(tp,t1MixCstr)        'Binary decision variable used to detect if limit 2 should be selected for mixed constraints'
* NMIR binary variables
  HVDCSENDING(tp,ild)                              'Binary variable indicating if island ild is the sending end of the HVDC flow. 1 = Yes.'
  INZONE(tp,ild,resC,z)                            'Binary variable (1 = Yes ) indicating if the HVDC flow is in a zone (z) that facilitates the appropriate quantity of shared reserves in the reverse direction to the HVDC sending island ild for reserve class resC.'
  HVDCSENTINSEGMENT(tp,ild,los)                    'Binary variable to decide which loss segment HVDC flow sent from an island falling into --> active segment loss model'
* NMIR binary variables end
  ;

SOS1 Variables
  ACBRANCHFLOWDIRECTED_INTEGER(tp,br,fd)           'Integer variables used to select branch flow direction in the event of circular branch flows (3.8.1)'
  HVDCLINKFLOWDIRECTION_INTEGER(tp,fd)             'Integer variables used to select the HVDC branch flow direction on in the event of S->N (forward) and N->S (reverse) flows (3.8.2)'
* Integer varaible to prevent intra-pole circulating branch flows
  HVDCPOLEFLOW_INTEGER(tp,pole,fd)                 'Integer variables used to select the HVDC pole flow direction on in the event of circulating branch flows within a pole'
  ;

SOS2 Variables
  LAMBDAINTEGER(tp,br,bp)                         'Integer variables used to enforce the piecewise linear loss approxiamtion on the HVDC links'
* NMIR SOS2 variables
  LAMBDAHVDCENERGY(tp,ild,bp)                      'Integer variables used to enforce the piecewise linear loss approxiamtion on the HVDC links'
  LAMBDAHVDCRESERVE(tp,ild,resC,rd,rsbp)           'Integer variables used to enforce the piecewise linear loss approxiamtion on the HVDC links'
* NMIR SOS2 variables end
  ;


Equations
  ObjectiveFunction                                'Objective function of the dispatch model (4.1.1.1)'
* Offer and purchase definitions
  GenerationOfferDefintion(tp,o)                   'Definition of generation provided by an offer (3.1.1.2)'
  GenerationRampUp(tp,o)                           'Maximum movement of the generator upwards due to up ramp rate (3.7.1.1)'
  GenerationRampDown(tp,o)                         'Maximum movement of the generator downwards due to down ramp rate (3.7.1.2)'
  PurchaseBidDefintion(tp,bd)                      'Definition of purchase provided by a bid (3.1.1.5)'
* Change to demand bids - End
* Network
  HVDClinkMaximumFlow(tp,br)                       'Maximum flow on each HVDC link (3.2.1.1)'
  HVDClinkLossDefinition(tp,br)                    'Definition of losses on the HVDC link (3.2.1.2)'
  HVDClinkFlowDefinition(tp,br)                    'Definition of MW flow on the HVDC link (3.2.1.3)'
  HVDClinkFlowIntegerDefinition1(tp)               'Definition of the integer HVDC link flow variable (3.8.2a)'
  HVDClinkFlowIntegerDefinition2(tp,fd)            'Definition of the integer HVDC link flow variable (3.8.2b)'
* Additional constraints for the intra-pole circulating branch flows
  HVDClinkFlowIntegerDefinition3(tp,pole)          'Definition of the HVDC pole integer varaible to prevent intra-pole circulating branch flows (3.8.2c)'
  HVDClinkFlowIntegerDefinition4(tp,pole,fd)       'Definition of the HVDC pole integer varaible to prevent intra-pole circulating branch flows (3.8.2d)'

  LambdaDefinition(tp,br)                          'Definition of weighting factor (3.2.1.4)'
  LambdaIntegerDefinition1(tp,br)                  'Definition of weighting factor when branch integer constraints are needed (3.8.3a)'
  LambdaIntegerDefinition2(tp,br,los)              'Definition of weighting factor when branch integer constraints are needed (3.8.3b)'

  DCNodeNetInjection(tp,b)                         'Definition of the net injection at buses corresponding to HVDC nodes (3.2.1.6)'
  ACnodeNetInjectionDefinition1(tp,b)              '1st definition of the net injection at buses corresponding to AC nodes (3.3.1.1)'
  ACnodeNetInjectionDefinition2(tp,b)              '2nd definition of the net injection at buses corresponding to AC nodes (3.3.1.2)'
  ACBranchMaximumFlow(tp,br,fd)                    'Maximum flow on the AC branch (3.3.1.3)'
  ACBranchFlowDefinition(tp,br)                    'Relationship between directed and undirected branch flow variables (3.3.1.4)'
  LinearLoadFlow(tp,br)                            'Equation that describes the linear load flow (3.3.1.5)'
  ACBranchBlockLimit(tp,br,los,fd)                 'Limit on each AC branch flow block (3.3.1.6)'
  ACDirectedBranchFlowDefinition(tp,br,fd)         'Composition of the directed branch flow from the block branch flow (3.3.1.7)'
  ACBranchLossCalculation(tp,br,los,fd)            'Calculation of the losses in each loss segment (3.3.1.8)'
  ACDirectedBranchLossDefinition(tp,br,fd)         'Composition of the directed branch losses from the block branch losses (3.3.1.9)'
  ACDirectedBranchFlowIntegerDefinition1(tp,br)    'Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1a)'
  ACDirectedBranchFlowIntegerDefinition2(tp,br,fd) 'Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1b)'
* Risk
  RiskOffsetCalculation_DCCE(tp,ild,resC,riskC)          'Calculation of the risk offset variable for the DCCE risk class.  Suppress this when suppressMixedConstraint flag is true (3.4.1.2)'
  RiskOffsetCalculation_DCECE(tp,ild,resC,riskC)         'Calculation of the risk offset variable for the DCECE risk class.  Suppress this when suppressMixedConstraint flag is true (3.4.1.4)'
  RiskOffsetCalculation(tp,t1MixCstr,ild,resC,riskC)     'Risk offset definition. Suppress this when suppressMixedConstraint flag is true (3.4.1.5 - v4.4)'
  HVDCIslandRiskCalculation(tp,ild,resC,riskC)           'Calculation of the island risk for a DCCE and DCECE (3.4.1.1)'
  HVDCRecCalculation(tp,ild)                             'Calculation of the net received HVDC MW flow into an island (3.4.1.5)'
  GenIslandRiskCalculation(tp,ild,o,resC,riskC)          'Calculation of the island risk for risk setting generators (3.4.1.6)'
  GenIslandRiskCalculation_1(tp,ild,o,resC,riskC)        'Calculation of the island risk for risk setting generators (3.4.1.6)'
  ManualIslandRiskCalculation(tp,ild,resC,riskC)         'Calculation of the island risk based on manual specifications (3.4.1.7)'
  HVDCIslandSecRiskCalculation_GEN(tp,ild,o,resC,riskC)  'Calculation of the island risk for an HVDC secondary risk to an AC risk (3.4.1.8)'
  HVDCIslandSecRiskCalculation_GEN_1(tp,ild,o,resC,riskC)'Calculation of the island risk for an HVDC secondary risk to an AC risk (3.4.1.8)'
  HVDCIslandSecRiskCalculation_Manual(tp,ild,resC,riskC) 'Calculation of the island risk for an HVDC secondary risk to a manual risk (3.4.1.9)'
  HVDCIslandSecRiskCalculation_Manu_1(tp,ild,resC,riskC) 'Calculation of the island risk for an HVDC secondary risk to a manual risk (3.4.1.9)'
  GenIslandRiskGroupCalculation(tp,ild,rg,resC,riskC)    'Calculation of the island risk of risk group (3.4.1.10) - SPD version 11.0'
  GenIslandRiskGroupCalculation_1(tp,ild,rg,resC,riskC)  'Calculation of the risk of risk group (3.4.1.10) - SPD version 11.0'
* Reserve
  PLSRReserveProportionMaximum(tp,o,trdBlk,resC,resT)    'Maximum PLSR as a proportion of the block MW (3.4.2.1)'
  ReserveOfferDefinition(tp,o,resC,resT)                 'Definition of the reserve offers of different classes and types (3.4.2.3a)'
  ReserveDefinitionPurchaseBid(tp,bd,resC)               'Definition of the ILR reserve provided by purchase bids (3.4.2.3b)'
  EnergyAndReserveMaximum(tp,o,resC)                     'Definition of maximum energy and reserves from each generator (3.4.2.4)'
  PurchaseBidReserveMaximum(tp,bd,resC)                  'Maximum ILR provided by purchase bids (3.4.2.5)'
* General NMIR equations
  EffectiveReserveShareCalculation(tp,ild,resC,riskC)                           'Calculation of effective shared reserve (3.4.2.1)'
  SharedReserveLimitByClearedReserve(tp,ild,resC)                               'Shared offered reserve is limited by cleared reserved (3.4.2.2)'
  BothClearedAndFreeReserveCanBeShared(tp,ild,resC,rd)                          'Shared reserve is covered by cleared reserved and shareable free reserve (3.4.2.4)'
  ReserveShareSentLimitByHVDCControlBand(tp,ild,resC,rd)                        'Reserve share sent from an island is limited by HVDC control band (3.4.2.5)'
  FwdReserveShareSentLimitByHVDCCapacity(tp,ild,resC,rd)                        'Forward reserve share sent from an island is limited by HVDC capacity (3.4.2.6)'
  ReverseReserveOnlyToEnergySendingIsland(tp,ild,resC,rd)                       'Shared reserve sent in reverse direction is possible only if the island is not sending energy through HVDC - (3.4.2.7)'
  ReverseReserveShareLimitByHVDCControlBand(tp,ild,resC,rd)                     'Reverse reserve share recieved at an island is limited by HVDC control band (3.4.2.8)'
  ForwardReserveOnlyToEnergyReceivingIsland(tp,ild,resC,rd)                     'Forward received reserve is possible if in the same direction of HVDC (3.4.2.9)'
  ReverseReserveLimitInReserveZone(tp,ild,resC,rd,z)                            'Reverse reserve constraint if HVDC sent flow in reverse zone (3.4.2.10)'
  ZeroReserveInNoReserveZone(tp,ild,resC,z)                                     'No reverse reserve if HVDC sent flow in no reverse zone and no forward reserve if round power disabled (3.4.2.11) & (3.4.2.18)'
  OnlyOneActiveHVDCZoneForEachReserveClass(tp,resC)                             'Across both island, one and only one zone is active for each reserve class (3.4.2.12)'
  ZeroSentHVDCFlowForNonSendingIsland(tp,ild)                                   'Directed HVDC sent from an island, if non-zero, must fall in a zone for each reserve class (3.4.2.13)'
  RoundPowerZoneSentHVDCUpperLimit(tp,ild,resC,z)                               'Directed HVDC sent from an island <= RoundPowerZoneExit level if in round power zone of that island (3.4.2.14)'
  HVDCSendingIslandDefinition(tp,ild,resC)                                      'An island is HVDC sending island if HVDC flow sent is in one of the three zones for each reserve class (3.4.2.15)'
  OnlyOneSendingIslandExists(tp)                                                'One and only one island is HVDC sending island (3.4.2.16)'
  HVDCSentCalculation(tp,ild)                                                   'Total HVDC sent from each island - (3.4.2.17) - SPD version 11.0'
* Lamda loss model
  HVDCFlowAccountedForForwardReserve(tp,ild,resC,rd)                            'HVDC flow sent from an island taking into account forward sent reserve (3.4.2.18) - SPD version 11.0'
  ForwardReserveReceivedAtHVDCReceivingIsland(tp,ild,resC,rd)                   'Forward reserve RECEIVED at an HVDC receiving island - (3.4.2.19) - SPD version 11.0'
  HVDCFlowAccountedForReverseReserve(tp,ild,resC,rd)                            'HVDC flow sent from an island taking into account reverse received reserve (3.4.2.20) - SPD version 11.0'
  ReverseReserveReceivedAtHVDCSendingIsland(tp,ild,resC,rd)                     'Reverse reserve RECEIVED at an HVDC sending island (3.4.2.21) - SPD version 11.0'
  HVDCSentEnergyLambdaDefinition(tp,ild)                                        'Definition of weight factor for total HVDC energy sent from an island (3.4.2.22) - SPD version 11.0'
  HVDCSentEnergyFlowDefinition(tp,ild)                                          'Lambda definition of total HVDC energy flow sent from an island (3.4.2.23) - SPD version 11.0'
  HVDCSentEnergyLossesDefinition(tp,ild)                                        'Lambda definition of total loss of HVDC energy sent from an island (3.4.2.24) - SPD version 11.0'
  HVDCSentReserveLambdaDefinition(tp,ild,resC,rd)                               'Definition of weight factor for total HVDC+reserve sent from an island (3.4.2.25) - SPD version 11.0'
  HVDCSentReserveFlowDefinition(tp,ild,resC,rd)                                 'Lambda definition of Reserse + Energy flow on HVDC sent from an island (3.4.2.26) - SPD version 11.0'
  HVDCSentReserveLossesDefinition(tp,ild,resC,rd)                               'Lambda definition of Reserse + Energy loss on HVDC sent from an island (3.4.2.27) - SPD version 11.0'
* Reserve share penalty
  ExcessReserveSharePenalty(tp)                                                 'Constraint to avoid excessive reserve share (3.4.2.28) - SPD version 11.0'
* Tuong Nguyen added on 24 Feb 2021 to correct the calculation of RESERVESHAREPENALTY
  ReserveShareEffective_CE_Calculation(tp,ild,resC,riskC)                       'Calculate max effective shared reserve for CE risk received at island (3.4.2.28)'
  ReserveShareEffective_ECE_Calculation(tp,ild,resC,riskC)                      'Calculate max effective shared reserve for ECE risk received at island (3.4.2.28)'

* Matching of reserve requirement and availability
  SupplyDemandReserveRequirement(tp,ild,resC,riskC)      'Matching of reserve supply and demand (3.4.3.1)'
  IslandReserveCalculation(tp,ild,resC)                  'Calculate total island cleared reserve (3.4.3.2)'
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
  SystemCostDefinition(tp)                         'Defined as the sum of the generation and reserve costs'
  SystemBenefitDefinition(tp)                      'Defined as the sum of the purcahse bid benefit'
  SystemPenaltyCostDefinition(tp)                  'Defined as the sum of the individual violation costs'
  TotalViolationCostDefinition                     'Deined as the sume of period violation cost'
  ;

* Objective function of the dispatch model (4.1.1.1)
ObjectiveFunction..
NETBENEFIT
=e=
  sum[ currTP, SYSTEMBENEFIT(currTP)
             - SYSTEMCOST(currTP)
             - SYSTEMPENALTYCOST(currTP)
             - RESERVESHAREPENALTY(currTP) ]

* the following prevents clearing more zero price reserve than required amount
- sum[ validReserveOfferBlock(currTP,o,trdBlk,resC,resT)
     $ (ReserveOfferPrice(validReserveOfferBlock) = 0)
     , 1e-6 * RESERVEBLOCK(validReserveOfferBlock) ]
  ;

* Defined as the sum of the individual violation costs
TotalViolationCostDefinition..
TOTALPENALTYCOST
=e=
  sum[ currTP, SYSTEMPENALTYCOST(currTP) ]
  ;

* Defined as the net sum of generation cost + reserve cost
SystemCostDefinition(currTP)..
SYSTEMCOST(currTP)
=e=
  sum[ validGenerationOfferBlock(currTP,o,trdBlk)
     , GENERATIONBLOCK(validGenerationOfferBlock)
     * GenerationOfferPrice(validGenerationOfferBlock) ]
+ sum[ validReserveOfferBlock(currTP,o,trdBlk,resC,resT)
     , RESERVEBLOCK(validReserveOfferBlock)
     * ReserveOfferPrice(validReserveOfferBlock) ]
+ sum[ validPurchaseBidILRBlock(currTP,bd,trdBlk,resC)
     , PURCHASEILRBLOCK(validPurchaseBidILRBlock) ]
+ sum[ (ild,resC)
     , VIRTUALRESERVE(currTP,ild,resC)
     * virtualReservePrice(currTP,ild,resC) ]
  ;

* Defined as the net sum of generation cost + reserve cost
SystemBenefitDefinition(currTP)..
SYSTEMBENEFIT(currTP)
=e=
  sum[ validPurchaseBidBlock(currTP,bd,trdBlk)
     , PURCHASEBLOCK(validPurchaseBidBlock)
     * PurchaseBidPrice(validPurchaseBidBlock) ]
  ;

* Defined as the sum of the individual violation costs
SystemPenaltyCostDefinition(currTP)..
SYSTEMPENALTYCOST(currTP)
=e=
  sum[ bus(currTP,b), deficitBusGenerationPenalty * DEFICITBUSGENERATION(bus)
                    + surplusBusGenerationPenalty * SURPLUSBUSGENERATION(bus) ]

+ sum[ branch(currTP,br), surplusBranchFlowPenalty * SURPLUSBRANCHFLOW(branch) ]

+ sum[ offer(currTP,o), deficitRampRatePenalty * DEFICITRAMPRATE(offer)
                      + surplusRampRatePenalty * SURPLUSRAMPRATE(Offer) ]

+ sum[ ACnodeConstraint(currTP,ACnodeCstr)
     , deficitACnodeCstrPenalty * DEFICITACnodeCONSTRAINT(ACnodeConstraint)
     + surplusACnodeCstrPenalty * SURPLUSACnodeCONSTRAINT(ACnodeConstraint) ]

+ sum[ BranchConstraint(currTP,brCstr)
     , deficitBrCstrPenalty * DEFICITBRANCHSECURITYCONSTRAINT(currTP,brCstr)
     + surplusBrCstrPenalty * SURPLUSBRANCHSECURITYCONSTRAINT(currTP,brCstr) ]

+ sum[ MNodeConstraint(currTP,MnodeCstr)
     , deficitMnodeCstrPenalty * DEFICITMNODECONSTRAINT(MNodeConstraint)
     + surplusMnodeCstrPenalty * SURPLUSMNODECONSTRAINT(MNodeConstraint) ]

+ sum[ Type1MixedConstraint(currTP,t1MixCstr)
     , deficitT1MixCstrPenalty * DEFICITTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
     + surplusT1MixCstrPenalty * SURPLUSTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr) ]

+ sum[ GenericConstraint(currTP,gnrcCstr)
     , deficitGnrcCstrPenalty * DEFICITGENERICCONSTRAINT(GenericConstraint)
     + surplusGnrcCstrPenalty * SURPLUSGENERICCONSTRAINT(GenericConstraint) ]
* Separate CE and ECE reserve deficity
+ sum[ (ild,resC)
       , [DeficitReservePenalty(resC)     * DEFICITRESERVE(currTP,ild,resC)    ]
       + [DeficitReservePenalty_CE(resC)  * DEFICITRESERVE_CE(currTP,ild,resC) ]
       + [DeficitReservePenalty_ECE(resC) * DEFICITRESERVE_ECE(currTP,ild,resC)]
     ]
  ;


*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS ========================

* Definition of generation provided by an offer (3.1.1.2)
GenerationOfferDefintion(offer(currTP,o))..
  GENERATION(offer)
=e=
  sum[ validGenerationOfferBlock(offer,trdBlk), GENERATIONBLOCK(offer,trdBlk) ]
  ;

* Change constraint numbering. 3.1.1.5 in the SPD formulation v6.0
* Definition of purchase provided by a bid (3.1.1.5)
PurchaseBidDefintion(bid(currTP,bd))..
  PURCHASE(bid)
=e=
  sum[ validPurchaseBidBlock(bid,trdBlk), PURCHASEBLOCK(bid,trdBlk) ]
  ;

*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS END ====================




*======= HVDC TRANSMISSION EQUATIONS ===========================================

* Maximum flow on each HVDC link (3.2.1.1)
HVDClinkMaximumFlow(HVDClink(currTP,br)) $ useHVDCbranchLimits ..
  HVDCLINKFLOW(HVDClink)
=l=
  sum[ fd $ ( ord(fd)=1 ), branchCapacity(HVDClink,fd) ]
  ;

* Definition of losses on the HVDC link (3.2.1.2)
HVDClinkLossDefinition(HVDClink(currTP,br))..
  HVDCLINKLOSSES(HVDClink)
=e=
  sum[ validLossSegment(HVDClink,bp,fd)
     , HVDCBreakPointMWLoss(HVDClink,bp,fd) * LAMBDA(HVDClink,bp) ]
  ;

* Definition of MW flow on the HVDC link (3.2.1.3)
HVDClinkFlowDefinition(HVDClink(currTP,br))..
  HVDCLINKFLOW(HVDClink)
=e=
  sum[ validLossSegment(HVDClink,bp,fd)
  , HVDCBreakPointMWFlow(HVDClink,bp,fd) * LAMBDA(HVDClink,bp) ]
  ;

* Definition of the integer HVDC link flow variable (3.8.2a)
* Not used if roundpower is allowed
HVDClinkFlowIntegerDefinition1(currTP) $ { UseBranchFlowMIP(currTP) and
                                           resolveCircularBranchFlows and
                                           (1-AllowHVDCRoundpower(currTP))
                                         }..
  sum[ fd, HVDCLINKFLOWDIRECTION_INTEGER(currTP,fd) ]
=e=
  sum[ HVDCpoleDirection(HVDClink(currTP,br),fd), HVDCLINKFLOW(HVDClink) ]
  ;

* Definition of the integer HVDC link flow variable (3.8.2b)
* Not used if roundpower is allowed
HVDClinkFlowIntegerDefinition2(currTP,fd) $ { UseBranchFlowMIP(currTP) and
                                              resolveCircularBranchFlows and
                                              (1-AllowHVDCRoundpower(currTP))
                                            }..
  HVDCLINKFLOWDIRECTION_INTEGER(currTP,fd)
=e=
  sum[ HVDCpoleDirection(HVDClink(currTP,br),fd), HVDCLINKFLOW(HVDClink) ]
  ;

* Definition of the integer HVDC pole flow variable for intra-pole circulating branch flows e (3.8.2c)
HVDClinkFlowIntegerDefinition3(currTP,pole) $ { UseBranchFlowMIP(currTP) and
                                                resolveCircularBranchFlows }..
  sum[ br $ { HVDCpoles(currTP,br)
          and HVDCpoleBranchMap(pole,br) } , HVDCLINKFLOW(currTP,br) ]
=e=
  sum[ fd, HVDCPOLEFLOW_INTEGER(currTP,pole,fd) ]
  ;

* Definition of the integer HVDC pole flow variable for intra-pole circulating branch flows e (3.8.2d)
HVDClinkFlowIntegerDefinition4(currTP,pole,fd) $ { UseBranchFlowMIP(currTP) and
                                                   resolveCircularBranchFlows }..
  sum[ HVDCpoleDirection(HVDCpoles(currTP,br),fd) $ HVDCpoleBranchMap(pole,br)
     , HVDCLINKFLOW(HVDCpoles) ]
=e=
  HVDCPOLEFLOW_INTEGER(currTP,pole,fd)
  ;

* Definition of weighting factor (3.2.1.4)
LambdaDefinition(HVDClink(currTP,br))..
  sum(validLossSegment(HVDClink,bp,fd), LAMBDA(HVDClink,bp))
=e=
  1
  ;

* Definition of weighting factor when branch integer constraints are needed (3.8.3a)
LambdaIntegerDefinition1(HVDClink(currTP,br)) $ { UseBranchFlowMIP(currTP) and
                                                  resolveHVDCnonPhysicalLosses }..
  sum[ validLossSegment(HVDClink,bp,fd), LAMBDAINTEGER(HVDClink,bp) ]
=e=
  1
  ;

* Definition of weighting factor when branch integer constraints are needed (3.8.3b)
LambdaIntegerDefinition2(HVDClink(currTP,br),bp)
  $ { UseBranchFlowMIP(currTP) and resolveHVDCnonPhysicalLosses
  and sum[ fd $ validLossSegment(HVDClink,bp,fd), 1] }..
  LAMBDAINTEGER(HVDClink,bp)
=e=
  LAMBDA(HVDClink,bp)
  ;

* Definition of the net injection at the HVDC nodes (3.2.1.6)
DCNodeNetInjection(DCBus(currTP,b))..
  0
=e=
  DEFICITBUSGENERATION(currTP,b) - SURPLUSBUSGENERATION(currTP,b)
+ sum[ HVDClinkReceivingBus(HVDClink(currTP,br),b), HVDCLINKFLOW(HVDClink)
                                                  - HVDCLINKLOSSES(HVDClink)
     ]
- sum[ HVDClinkSendingBus(HVDClink(currTP,br),b),  HVDCLINKFLOW(HVDClink) ]
- sum[ HVDClinkBus(HVDClink(currTP,br),b), 0.5* branchFixedLoss(HVDClink) ]
  ;

*======= HVDC TRANSMISSION EQUATIONS END =======================================




*======= AC TRANSMISSION EQUATIONS =============================================

* 1st definition of the net injection at buses corresponding to AC nodes (3.3.1.1)
ACnodeNetInjectionDefinition1(ACBus(currTP,b))..
  ACNODENETINJECTION(currTP,b)
=e=
  sum[ ACBranchSendingBus(ACBranch(currTP,br),b,fd)
       , ACBRANCHFLOWDIRECTED(ACBranch,fd)
     ]
- sum[ ACBranchReceivingBus(ACBranch(currTP,br),b,fd)
       , ACBRANCHFLOWDIRECTED(ACBranch,fd)
     ]
  ;

* 2nd definition of the net injection at buses corresponding to AC nodes (3.3.1.2)
ACnodeNetInjectionDefinition2(ACBus(currTP,b))..
  ACNODENETINJECTION(currTP,b)
=e=
  sum[ offerNode(currTP,o,n) $ NodeBus(currTP,n,b)
     , NodeBusAllocationFactor(currTP,n,b) * GENERATION(currTP,o) ]
- sum[ BidNode(currTP,bd,n) $ NodeBus(currTP,n,b)
     , NodeBusAllocationFactor(currTP,n,b) * PURCHASE(currTP,bd) ]
- sum[ NodeBus(currTP,n,b)
     , NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n) ]
+ sum[ HVDClinkReceivingBus(HVDClink(currTP,br),b), HVDCLINKFLOW(HVDClink)   ]
- sum[ HVDClinkReceivingBus(HVDClink(currTP,br),b), HVDCLINKLOSSES(HVDClink) ]
- sum[ HVDClinkSendingBus(HVDClink(currTP,br),b)  , HVDCLINKFLOW(HVDClink)   ]
- sum[ HVDClinkBus(HVDClink(currTP,br),b),   0.5 * branchFixedLoss(HVDClink) ]
- sum[ ACBranchReceivingBus(ACBranch(currTP,br),b,fd)
     , i_branchReceivingEndLossProportion
     * ACBRANCHLOSSESDIRECTED(ACBranch,fd) ]
- sum[ ACBranchSendingBus(ACBranch(currTP,br),b,fd)
     , (1 - i_branchReceivingEndLossProportion)
     * ACBRANCHLOSSESDIRECTED(ACBranch,fd) ]
- sum[ BranchBusConnect(ACBranch(currTP,br),b), 0.5*branchFixedLoss(ACBranch) ]
+ DEFICITBUSGENERATION(currTP,b) - SURPLUSBUSGENERATION(currTP,b)
  ;

* Maximum flow on the AC branch (3.3.1.3) - Modified for BranchcReverseRatings
ACBranchMaximumFlow(ACbranch(currTP,br),fd) $ useACbranchLimits..
  ACBRANCHFLOWDIRECTED(ACBranch,fd) - SURPLUSBRANCHFLOW(ACBranch)
=l=
  branchCapacity(ACBranch,fd)
  ;

* Relationship between directed and undirected branch flow variables (3.3.1.4)
ACBranchFlowDefinition(ACBranch(currTP,br))..
  ACBRANCHFLOW(ACBranch)
=e=
  sum[ fd $ (ord(fd) = 1), ACBRANCHFLOWDIRECTED(ACBranch,fd) ]
- sum[ fd $ (ord(fd) = 2), ACBRANCHFLOWDIRECTED(ACBranch,fd) ]
  ;

* Equation that describes the linear load flow (3.3.1.5)
LinearLoadFlow(ACBranch(currTP,br))..
  ACBRANCHFLOW(ACBranch)
=e=
  branchSusceptance(ACBranch)
  * sum[ BranchBusDefn(ACBranch,frB,toB)
       , ACNODEANGLE(currTP,frB) - ACNODEANGLE(currTP,toB) ]
  ;

* Limit on each AC branch flow block (3.3.1.6) - Modified for BranchcReverseRatings
ACBranchBlockLimit(validLossSegment(ACBranch(currTP,br),los,fd))..
  ACBRANCHFLOWBLOCKDIRECTED(ACBranch,los,fd)
=l=
  ACBranchLossMW(ACBranch,los,fd)
  ;

* Composition of the directed branch flow from the block branch flow (3.3.1.7)
ACDirectedBranchFlowDefinition(ACBranch(currTP,br),fd)..
  ACBRANCHFLOWDIRECTED(ACBranch,fd)
=e=
  sum[ validLossSegment(ACBranch,los,fd)
     , ACBRANCHFLOWBLOCKDIRECTED(ACBranch,los,fd) ]
  ;

* Calculation of the losses in each loss segment (3.3.1.8) - Modified for BranchcReverseRatings
ACBranchLossCalculation(validLossSegment(ACBranch(currTP,br),los,fd))..
  ACBRANCHLOSSESBLOCKDIRECTED(ACBranch,los,fd)
=e=
  ACBRANCHFLOWBLOCKDIRECTED(ACBranch,los,fd)
  * ACBranchLossFactor(ACBranch,los,fd)
  ;

* Composition of the directed branch losses from the block branch losses (3.3.1.9)
ACDirectedBranchLossDefinition(ACBranch(currTP,br),fd)..
  ACBRANCHLOSSESDIRECTED(ACBranch,fd)
=e=
  sum[ validLossSegment(ACBranch,los,fd)
     , ACBRANCHLOSSESBLOCKDIRECTED(ACBranch,los,fd) ]
  ;

* Integer constraint to enforce a flow direction on loss AC branches in the
* presence of circular branch flows or non-physical losses (3.8.1a)
ACDirectedBranchFlowIntegerDefinition1(ACBranch(lossBranch(currTP,br)))
  $ { UseBranchFlowMIP(currTP) and resolveCircularBranchFlows }..
  sum[ fd, ACBRANCHFLOWDIRECTED_INTEGER(ACBranch,fd) ]
=e=
  sum[ fd, ACBRANCHFLOWDIRECTED(ACBranch,fd) ]
  ;

* Integer constraint to enforce a flow direction on loss AC branches in the
* presence of circular branch flows or non-physical losses (3.8.1b)
ACDirectedBranchFlowIntegerDefinition2(ACBranch(lossBranch(currTP,br)),fd)
  $ { UseBranchFlowMIP(currTP) and resolveCircularBranchFlows }..
  ACBRANCHFLOWDIRECTED_INTEGER(ACBranch,fd)
=e=
  ACBRANCHFLOWDIRECTED(ACBranch,fd)
  ;

*======= AC TRANSMISSION EQUATIONS END =========================================




*======= RAMPING EQUATIONS =====================================================

* Maximum movement of the generator downwards due to up ramp rate (3.7.1.1)
GenerationRampUp(currTP,o) $ { PositiveEnergyOffer(currTP,o)
                           and ( not HasPrimaryOffer(currTP,o) ) }..
  sum[ o1 $ PrimarySecondaryOffer(currTP,o,o1), GENERATION(currTP,o1) ]
+ GENERATION(currTP,o) - DEFICITRAMPRATE(currTP,o)
=l=
  GenerationEndUp(currTP,o)
  ;

* Maximum movement of the generator downwards due to down ramp rate (3.7.1.2)
GenerationRampDown(currTP,o) $ { PositiveEnergyOffer(currTP,o)
                           and ( not HasPrimaryOffer(currTP,o) ) }..
  sum[ o1 $ PrimarySecondaryOffer(currTP,o,o1), GENERATION(currTP,o1) ]
+ GENERATION(currTP,o) + SURPLUSRAMPRATE(currTP,o)
=g=
  GenerationEndDown(currTP,o)
  ;

*======= RAMPING EQUATIONS END =================================================




*======= RISK EQUATIONS ========================================================

* Calculation of the island risk for a DCCE and DCECE (3.4.1.1)
HVDCIslandRiskCalculation(currTP,ild,resC,HVDCrisk)..
  ISLANDRISK(currTP,ild,resC,HVDCrisk)
=e=
  IslandRiskAdjustmentFactor(currTP,ild,resC,HVDCrisk)
  * [ HVDCREC(currTP,ild)
    - RISKOFFSET(currTP,ild,resC,HVDCrisk)
*   SPD version 11.0 update
    + modulationRiskClass(currTP,HVDCrisk)
    ]
  ;

* Calculation of the risk offset variable for the DCCE risk class.
* This will be used when the useMixedConstraintRiskOffset flag is false (3.4.1.2)
RiskOffsetCalculation_DCCE(currTP,ild,resC,riskC)
  $ { (not useMixedConstraintRiskOffset) and
      HVDCrisk(riskC) and ContingentEvents(riskC)  }..
  RISKOFFSET(currTP,ild,resC,riskC)
=e=
  FreeReserve(currTP,ild,resC,riskC) + HVDCPoleRampUp(currTP,ild,resC,riskC)
  ;

* Calculation of the risk offset variable for the DCECE risk class.
* This will be used when the useMixedConstraintRiskOffset flag is false (3.4.1.4)
RiskOffsetCalculation_DCECE(currTP,ild,resC,riskC)
  $ { (not useMixedConstraintRiskOffset) and HVDCrisk(riskC) and
      ExtendedContingentEvent(riskC) }..
  RISKOFFSET(currTP,ild,resC,riskC)
=e=
  FreeReserve(currTP,ild,resC,riskC)
  ;

* Risk offset definition (3.4.1.5) in old formulation (v4.4).
* Use this when the useMixedConstraintRiskOffset flag is set.
RiskOffsetCalculation(currTP,Type1MixCstrReserveMap(t1MixCstr,ild,resC,riskC))
  $ useMixedConstraintRiskOffset..
  RISKOFFSET(currTP,ild,resC,riskC)
=e=
  MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
  ;

* Calculation of the net received HVDC MW flow into an island (3.4.1.5)
HVDCRecCalculation(currTP,ild)..
  HVDCREC(currTP,ild)
=e=
  sum[ (b,br) $ { BusIsland(currTP,b,ild)
              and HVDClinkSendingBus(currTP,br,b)
              and HVDCPoles(currTP,br)
                }, -HVDCLINKFLOW(currTP,br)
     ]
+ sum[ (b,br) $ { BusIsland(currTP,b,ild)
              and HVDClinkReceivingBus(currTP,br,b)
              and HVDCPoles(currTP,br)
                }, HVDCLINKFLOW(currTP,br) - HVDCLINKLOSSES(currTP,br)
     ]
  ;

* Calculation of the risk of risk setting generators (3.4.1.6)
GenIslandRiskCalculation_1(currTP,ild,o,resC,GenRisk)
  $ IslandRiskGenerator(currTP,ild,o)..
  GENISLANDRISK(currTP,ild,o,resC,GenRisk)
=e=
  IslandRiskAdjustmentFactor(currTP,ild,resC,GenRisk)
  * [ GENERATION(currTP,o)
    - FreeReserve(currTP,ild,resC,GenRisk)
    + FKBand(currTP,o)
    + sum[ resT, RESERVE(currTP,o,resC,resT) ]
    + sum[ o1 $ {PrimarySecondaryOffer(currTP,o,o1) and UsePrimSecGenRiskModel}
         , sum[ resT, RESERVE(currTP,o1,resC,resT) ] + GENERATION(currTP,o1) ]
    ]
* NMIR update
- RESERVESHAREEFFECTIVE(currTP,ild,resC,GenRisk)$reserveShareEnabled(currTP,resC)
  ;

* Calculation of the island risk for risk setting generators (3.4.1.6)
GenIslandRiskCalculation(currTP,ild,o,resC,GenRisk)
  $ IslandRiskGenerator(currTP,ild,o)..
  ISLANDRISK(currTP,ild,resC,GenRisk)
=g=
  GENISLANDRISK(currTP,ild,o,resC,GenRisk)
  ;

* Calculation of the island risk based on manual specifications (3.4.1.7)
ManualIslandRiskCalculation(currTP,ild,resC,ManualRisk)..
  ISLANDRISK(currTP,ild,resC,ManualRisk)
=e=
  IslandRiskAdjustmentFactor(currTP,ild,resC,ManualRisk)
  * [ IslandMinimumRisk(currTP,ild,resC,ManualRisk)
    - FreeReserve(currTP,ild,resC,ManualRisk)
    ]
* NMIR update
- RESERVESHAREEFFECTIVE(currTP,ild,resC,ManualRisk)$reserveShareEnabled(currTP,resC)
  ;

* HVDC secondary risk calculation including the FKBand for generator primary risk
* Calculation of the island risk for an HVDC secondary risk to a generator risk (3.4.1.8)
HVDCIslandSecRiskCalculation_GEN_1(currTP,ild,o,resC,HVDCSecRisk)
  $ { IslandRiskGenerator(currTP,ild,o) and
      HVDCSecRiskEnabled(currTP,ild,HVDCSecRisk) }..
  HVDCGENISLANDRISK(currTP,ild,o,resC,HVDCSecRisk)
=e=
  IslandRiskAdjustmentFactor(currTP,ild,resC,HVDCSecRisk)
  * [ GENERATION(currTP,o)
    - FreeReserve(currTP,ild,resC,HVDCSecRisk)
    + HVDCREC(currTP,ild)
    - HVDCSecRiskSubtractor(currTP,ild)
    + FKBand(currTP,o)
    + sum[ resT, RESERVE(currTP,o,resC,resT) ]
    + sum[ o1 $ {PrimarySecondaryOffer(currTP,o,o1) and UsePrimSecGenRiskModel}
         , sum[ resT, RESERVE(currTP,o1,resC,resT) ] + GENERATION(currTP,o1) ]
*   SPD version 11.0 update
    + modulationRiskClass(currTP,HVDCSecRisk)
    ]
  ;

* HVDC secondary risk calculation including the FKBand for generator primary risk
* Calculation of the island risk for an HVDC secondary risk to a generator risk (3.4.1.8)
HVDCIslandSecRiskCalculation_GEN(currTP,ild,o,resC,HVDCSecRisk)
  $ { IslandRiskGenerator(currTP,ild,o) and
      HVDCSecRiskEnabled(currTP,ild,HVDCSecRisk) }..
  ISLANDRISK(currTP,ild,resC,HVDCSecRisk)
=g=
  HVDCGENISLANDRISK(currTP,ild,o,resC,HVDCSecRisk)
  ;

* HVDC secondary risk calculation for manual primary risk
* Calculation of the island risk for an HVDC secondary risk to a manual risk (3.4.1.9)
HVDCIslandSecRiskCalculation_Manu_1(currTP,ild,resC,HVDCSecRisk)
  $ HVDCSecRiskEnabled(currTP,ild,HVDCSecRisk)..
  HVDCMANISLANDRISK(currTP,ild,resC,HVDCSecRisk)
=e=
  IslandRiskAdjustmentFactor(currTP,ild,resC,HVDCSecRisk)
  * [ HVDCSecIslandMinimumRisk(currTP,ild,resC,HVDCSecRisk)
    - FreeReserve(currTP,ild,resC,HVDCSecRisk)
    + HVDCREC(currTP,ild)
    - HVDCSecRiskSubtractor(currTP,ild)
*   SPD version 11.0 update
    + modulationRiskClass(currTP,HVDCSecRisk)
    ]
  ;

* HVDC secondary risk calculation for manual primary risk
* Calculation of the island risk for an HVDC secondary risk to a manual risk (3.4.1.9)
HVDCIslandSecRiskCalculation_Manual(currTP,ild,resC,HVDCSecRisk)
  $ HVDCSecRiskEnabled(currTP,ild,HVDCSecRisk)..
  ISLANDRISK(currTP,ild,resC,HVDCSecRisk)
=g=
  HVDCMANISLANDRISK(currTP,ild,resC,HVDCSecRisk)
  ;

* Calculation of the risk of risk group (3.4.1.10) - SPD version 11.0
GenIslandRiskGroupCalculation_1(currTP,ild,rg,resC,GenRisk)
  $ islandRiskGroup(currTP,ild,rg,GenRisk)..
  GENISLANDRISKGROUP(currTP,ild,rg,resC,GenRisk)
=e=
  IslandRiskAdjustmentFactor(currTP,ild,resC,GenRisk)
  * [ sum[ o $ { offerIsland(currTP,o,ild)
             and riskGroupOffer(currTP,rg,o,GenRisk)
               } , GENERATION(currTP,o) + FKBand(currTP,o)
                 + sum[ resT, RESERVE(currTP,o,resC,resT) ]
         ]
    - FreeReserve(currTP,ild,resC,GenRisk)
    ]
* NMIR update
- RESERVESHAREEFFECTIVE(currTP,ild,resC,GenRisk)$reserveShareEnabled(currTP,resC)
  ;

* Calculation of the island risk for risk group (3.4.1.10) - SPD version 11.0
GenIslandRiskGroupCalculation(currTP,ild,rg,resC,GenRisk)
  $ islandRiskGroup(currTP,ild,rg,GenRisk)..
  ISLANDRISK(currTP,ild,resC,GenRisk)
=g=
  GENISLANDRISKGROUP(currTP,ild,rg,resC,GenRisk)
  ;

*======= RISK EQUATIONS END ====================================================


*======= NMIR - RESERVE SHARING EQUATIONS ======================================

* General NMIR equations start -------------------------------------------------

* Calculation of effective shared reserve - (3.4.2.1) - SPD version 11.0
EffectiveReserveShareCalculation(currTP,ild,resC,riskC)
  $ { reserveShareEnabled(currTP,resC)
  and ( GenRisk(riskC) or ManualRisk(riskC) ) }..
  RESERVESHAREEFFECTIVE(currTP,ild,resC,riskC)
=l=
  Sum[ rd , RESERVESHARERECEIVED(currTP,ild,resC,rd)
          * effectiveFactor(currTP,ild,resC,riskC) ]
  ;
* Tuong Nguyen added on 24 Feb 2021 to correct the calculation of RESERVESHAREPENALTY
ReserveShareEffective_CE_Calculation(currTP,ild,resC,riskC)
  $ { reserveShareEnabled(currTP,resC) and ContingentEvents(riskC)
  and ( GenRisk(riskC) or ManualRisk(riskC) ) }..
  RESERVESHAREEFFECTIVE_CE(currTP,ild,resC)
=g=
  RESERVESHAREEFFECTIVE(currTP,ild,resC,riskC)
  ;
ReserveShareEffective_ECE_Calculation(currTP,ild,resC,riskC)
  $ { reserveShareEnabled(currTP,resC) and ExtendedContingentEvent(riskC)
  and ( GenRisk(riskC) or ManualRisk(riskC) ) }..
  RESERVESHAREEFFECTIVE_ECE(currTP,ild,resC)
=g=
  RESERVESHAREEFFECTIVE(currTP,ild,resC,riskC)
  ;

* Shared offered reserve is limited by cleared reserved - (3.4.2.2) - SPD version 11.0
SharedReserveLimitByClearedReserve(currTP,ild,resC)
  $ reserveShareEnabled(currTP,resC)..
  SHAREDRESERVE(currTP,ild,resC)
=l=
  ISLANDRESERVE(currTP,ild,resC)
  ;

* Both cleared reserved and shareable free reserve can be shared - (3.4.2.4) - SPD version 11.0
BothClearedAndFreeReserveCanBeShared(currTP,ild,resC,rd)
  $ reserveShareEnabled(currTP,resC)..
  RESERVESHARESENT(currTP,ild,resC,rd)
=l=
  SHAREDRESERVE(currTP,ild,resC) + SHAREDNFR(currTP,ild)$(ord(resC)=1)
  ;

* Reserve share sent is limited by HVDC control band - (3.4.2.5) - SPD version 11.0
ReserveShareSentLimitByHVDCControlBand(currTP,ild,resC,rd)
  $ reserveShareEnabled(currTP,resC)..
  RESERVESHARESENT(currTP,ild,resC,rd)
=l=
  [ HVDCControlBand(currTP,rd) - modulationRisk(currTP)
  ] $ (HVDCControlBand(currTP,rd) > modulationRisk(currTP))
  ;

* Forward reserve share sent is limited by HVDC capacity - (3.4.2.6) - SPD version 11.0
FwdReserveShareSentLimitByHVDCCapacity(currTP,ild,resC,rd)
  $ { reserveShareEnabled(currTP,resC) and (ord(rd) = 1) }..
  RESERVESHARESENT(currTP,ild,resC,rd)
+ HVDCSENT(currTP,ild)
=l=
  [ HVDCMax(currTP,ild) - modulationRisk(currTP)
  ] $ (HVDCMax(currTP,ild) > modulationRisk(currTP))
;

* Shared reserve sent in reverse direction is possible only if the island is
* NOT sending energy through HVDC - (3.4.2.7) - SPD version 11.0
ReverseReserveOnlyToEnergySendingIsland(currTP,ild,resC,rd)
  $ { reserveShareEnabled(currTP,resC) and (ord(rd) = 2) }..
  RESERVESHARESENT(currTP,ild,resC,rd)
=l=
  BigM * [ 1 - HVDCSENDING(currTP,ild) ]
  ;

* Reverse reserve share recieved at an island is limited by HVDC control band
* (3.4.2.8) - SPD version 11.0
ReverseReserveShareLimitByHVDCControlBand(currTP,ild,resC,rd)
  $ { reserveShareEnabled(currTP,resC) and (ord(rd) = 2) }..
  RESERVESHARERECEIVED(currTP,ild,resC,rd)
=l=
  HVDCSENDING(currTP,ild) * [ HVDCControlBand(currTP,rd)
                            - modulationRisk(currTP)
                            ] $ ( HVDCControlBand(currTP,rd)
                                > modulationRisk(currTP) )
  ;

* Forward received reserve is possible if in the same direction of HVDC
* (3.4.2.9) - SPD version 11.0
ForwardReserveOnlyToEnergyReceivingIsland(currTP,ild,resC,rd)
  $ { reserveShareEnabled(currTP,resC) and (ord(rd) = 1) }..
  RESERVESHARERECEIVED(currTP,ild,resC,rd)
=l=
  BigM * [ 1 - HVDCSENDING(currTP,ild) ]
  ;

* Reverse reserve constraint if HVDC sent flow in reverse zone
* (3.4.2.10) - SPD version 11.0
ReverseReserveLimitInReserveZone(currTP,ild,resC,rd,z)
  $ { reserveShareEnabled(currTP,resC) and (ord(rd) = 2) and (ord(z) = 3) }..
  RESERVESHARERECEIVED(currTP,ild,resC,rd)
=l=
  HVDCSENT(currTP,ild) - (MonopoleMinimum(currTP) + modulationRisk(currTP))
+ BigM * [ 1 - INZONE(currTP,ild,resC,z) ]
  ;

* No reverse reserve if HVDC sent flow in no reverse zone &
* No forward reserve if HVDC sent flow in no reverse zone and RP disabled
* (3.4.2.11) & (3.4.2.18) - SPD version 11.0
ZeroReserveInNoReserveZone(currTP,ild,resC,z)
  $ { reserveShareEnabled(currTP,resC) and (ord(z) = 2) }..
  Sum[ rd $ (ord(rd) = 2), RESERVESHARERECEIVED(currTP,ild,resC,rd) ]
+ Sum[ rd $ (ord(rd) = 1), RESERVESHARESENT(currTP,ild,resC,rd) ] $ {reserveRoundPower(currTP,resC) = 0}
=l=
  BigM * [ 1 - INZONE(currTP,ild,resC,z) ]
  ;

* Across both island, only one zone is active for each reserve class
* (3.4.2.12) - SPD version 11.0
OnlyOneActiveHVDCZoneForEachReserveClass(currTP,resC)
  $ reserveShareEnabled(currTP,resC)..
  Sum[ (ild,z), INZONE(currTP,ild,resC,z) ]
=e=
  1
  ;

* Directed HVDC sent from an island can be non-zero if an only if the island is
* sending island - (3.4.2.13) - SPD version 11.0
ZeroSentHVDCFlowForNonSendingIsland(currTP,ild)
  $ reserveShareEnabledOverall(currTP)..
  HVDCSENT(currTP,ild)
=l=
  BigM * HVDCSENDING(currTP,ild)
  ;

* Directed HVDC sent from an island <= RoundPowerZoneExit level if in round
* power zone of that island - (3.4.2.14) - SPD version 11.0
RoundPowerZoneSentHVDCUpperLimit(currTP,ild,resC,z)
  $ { reserveShareEnabled(currTP,resC) and (ord(z) = 1) }..
  HVDCSENT(currTP,ild)
=l=
  roPwrZoneExit(currTP,resC)
+ BigM * [ 1 - INZONE(currTP,ild,resC,z) ]
;

* An island is HVDC sending island if HVDC flow sent is in one of the three
* zones for each reserve class - (3.4.2.15) - SPD version 11.0
HVDCSendingIslandDefinition(currTP,ild,resC) $ reserveShareEnabled(currTP,resC)..
  HVDCSENDING(currTP,ild)
=e=
  Sum[ z, INZONE(currTP,ild,resC,z) ]
  ;

* One and only one island is HVDC sending island - (3.4.2.19) - SPD version 11.0
OnlyOneSendingIslandExists(currTP) $ reserveShareEnabledOverall(currTP)..
 Sum[ ild, HVDCSENDING(currTP,ild) ]
=e=
  1
  ;

* Total HVDC sent from each island - (3.4.2.20) - SPD version 11.0
HVDCSentCalculation(currTP,ild) $ reserveShareEnabledOverall(currTP)..
  HVDCSENT(currTP,ild)
=e=
  Sum[ (b,br) $ { BusIsland(currTP,b,ild)
              and HVDClinkSendingBus(currTP,br,b)
              and HVDCPoles(currTP,br)
                }, HVDCLINKFLOW(currTP,br)
     ]
;

* General NMIR equations end ---------------------------------------------------


* Lamda loss model -------------------------------------------------------------

* HVDC flow sent from an island taking into account forward SENT reserve
* (3.4.2.21) - SPD version 11.0
HVDCFlowAccountedForForwardReserve(currTP,ild,resC,rd)
  $ { reserveShareEnabled(currTP,resC) and (ord(rd) = 1) }..
  HVDCRESERVESENT(currTP,ild,resC,rd)
=e=
  RESERVESHARESENT(currTP,ild,resC,rd) + HVDCSENT(currTP,ild)
  ;

* Forward reserve RECEIVED at an HVDC receiving island - (3.4.2.22) - SPD version 11.0
ForwardReserveReceivedAtHVDCReceivingIsland(currTP,ild,resC,rd)
  $ { reserveShareEnabled(currTP,resC) and (ord(rd) = 1) }..
  RESERVESHARERECEIVED(currTP,ild,resC,rd)
=e=
  Sum[ ild1 $ (not sameas(ild1,ild))
      , RESERVESHARESENT(currTP,ild1,resC,rd)
      - HVDCRESERVELOSS(currTP,ild1,resC,rd)
      + HVDCSENTLOSS(currTP,ild1) ]
  ;

* HVDC flow sent from an island taking into account reverse RECEIVED reserve
* (3.4.2.23) - SPD version 11.0
HVDCFlowAccountedForReverseReserve(currTP,ild,resC,rd)
  $ { reserveShareEnabled(currTP,resC) and (ord(rd) = 2) }..
  HVDCRESERVESENT(currTP,ild,resC,rd)
=e=
  HVDCSENT(currTP,ild) - RESERVESHARERECEIVED(currTP,ild,resC,rd)
  ;

* Reverse reserve RECEIVED at an HVDC sending island - (3.4.2.24) - SPD version 11.0
ReverseReserveReceivedAtHVDCSendingIsland(currTP,ild,resC,rd)
  $ { reserveShareEnabled(currTP,resC) and (ord(rd) = 2) }..
  RESERVESHARERECEIVED(currTP,ild,resC,rd)
=e=
  Sum[ ild1 $ (not sameas(ild1,ild)), RESERVESHARESENT(currTP,ild1,resC,rd) ]
- HVDCRESERVELOSS(currTP,ild,resC,rd)
+ HVDCSENTLOSS(currTP,ild)
  ;

* Definition of weight factor for total HVDC energy sent from an island
* (3.4.2.25) - SPD version 11.0
HVDCSentEnergyLambdaDefinition(currTP,ild) $ reserveShareEnabledOverall(currTP)..
  Sum[ bp $ (ord(bp) <= 7),LAMBDAHVDCENERGY(currTP,ild,bp) ]
=e=
  1
  ;

* Lambda definition of total HVDC energy flow sent from an island
* (3.4.2.26) - SPD version 11.0
HVDCSentEnergyFlowDefinition(currTP,ild) $ reserveShareEnabledOverall(currTP)..
  HVDCSENT(currTP,ild)
=e=
  Sum[ bp $ (ord(bp) <= 7), HVDCSentBreakPointMWFlow(currTP,ild,bp)
                          * LAMBDAHVDCENERGY(currTP,ild,bp) ]
  ;

* Lambda definition of total loss of HVDC energy sent from an island
* (3.4.2.27) - SPD version 11.0
HVDCSentEnergyLossesDefinition(currTP,ild) $ reserveShareEnabledOverall(currTP)..
  HVDCSENTLOSS(currTP,ild)
=e=
  Sum[ bp $ (ord(bp) <= 7), HVDCSentBreakPointMWLoss(currTP,ild,bp)
                          * LAMBDAHVDCENERGY(currTP,ild,bp) ]
  ;

* Definition of weight factor for total HVDC+reserve sent from an island
* (3.4.2.28) - SPD version 11.0
HVDCSentReserveLambdaDefinition(currTP,ild,resC,rd)
  $ reserveShareEnabled(currTP,resC)..
  Sum[ rsbp, LAMBDAHVDCRESERVE(currTP,ild,resC,rd,rsbp) ]
=e=
  1
  ;

* Lambda definition of Reserse + Energy flow on HVDC sent from an island
* (3.4.2.29) - SPD version 11.0
HVDCSentReserveFlowDefinition(currTP,ild,resC,rd)
  $ reserveShareEnabled(currTP,resC)..
  HVDCRESERVESENT(currTP,ild,resC,rd)
=e=
  Sum[ rsbp, HVDCReserveBreakPointMWFlow(currTP,ild,rsbp)
           * LAMBDAHVDCRESERVE(currTP,ild,resC,rd,rsbp) ]
  ;

* Lambda definition of Reserse + Energy Loss on HVDC sent from an island
* (3.4.2.30) - SPD version 11.0
HVDCSentReserveLossesDefinition(currTP,ild,resC,rd)
  $ reserveShareEnabled(currTP,resC)..
  HVDCRESERVELOSS(currTP,ild,resC,rd)
=e=
  Sum[ rsbp, HVDCReserveBreakPointMWLoss(currTP,ild,rsbp)
           * LAMBDAHVDCRESERVE(currTP,ild,resC,rd,rsbp) ]
  ;

* Lamda loss model end ---------------------------------------------------------

* Constraint to avoid excessive reserve share (3.4.2.31) - SPD version 11.0
ExcessReserveSharePenalty(currTP) $ reserveShareEnabledOverall(currTP)..
  RESERVESHAREPENALTY(currTP)
=e=
  sum[ ild, 1e-5 * SHAREDNFR(currTP,ild) ]
+ sum[ (ild,resC), 2e-5 * SHAREDRESERVE(currTP,ild,resC) ]
* Tuong Nguyen added on 24 Feb 2021 to correct the calculation of RESERVESHAREPENALTY
*+ sum[ (ild,resC,riskC), 3e-5 * RESERVESHAREEFFECTIVE(currTP,ild,resC,riskC)]
+ sum[ (ild,resC), 3e-5 * RESERVESHAREEFFECTIVE_CE(currTP,ild,resC)]
+ sum[ (ild,resC), 3e-5 * RESERVESHAREEFFECTIVE_ECE(currTP,ild,resC)]
;

*======= NMIR - RESERVE SHARING EQUATIONS END ==================================


*======= RESERVE EQUATIONS =====================================================

* Maximum PLSR as a proportion of the block MW (3.4.3.1)
PLSRReserveProportionMaximum(offer(currTP,o),trdBlk,resC,PLSRReserveType)
  $ validReserveOfferBlock(offer,trdBlk,resC,PLSRReserveType)..
  RESERVEBLOCK(Offer,trdBlk,resC,PLSRReserveType)
=l=
  ReserveOfferProportion(Offer,trdBlk,resC) * GENERATION(Offer)
  ;

* Definition of the reserve offers of different classes and types (3.4.3.3a)
ReserveOfferDefinition(offer(currTP,o),resC,resT)..
  RESERVE(offer,resC,resT)
=e=
  sum[ trdBlk, RESERVEBLOCK(offer,trdBlk,resC,resT) ]
  ;

* Definition of the ILR reserve provided by purchase bids (3.4.3.3b)
ReserveDefinitionPurchaseBid(bid(currTP,bd),resC)..
  PURCHASEILR(bid,resC)
=e=
  sum(trdBlk, PURCHASEILRBLOCK(bid,trdBlk,resC))
  ;

* Definition of maximum energy and reserves from each generator (3.4.3.4)
EnergyAndReserveMaximum(offer(currTP,o),resC)..
  GENERATION(offer)
+ ReserveMaximumFactor(offer,resC)
  * sum[ resT $ (not ILReserveType(resT)), RESERVE(offer,resC,resT) ]
=l=
  ReserveGenerationMaximum(offer)
  ;

* This constraint is no longer in the formulation from v6.0 (following changes with DSBF)
* Maximum ILR provided by purchase bids (3.4.2.5 - SPD version 5.0)
PurchaseBidReserveMaximum(bid(currTP,bd),resC) $ (not (UseDSBFDemandBidModel))..
  PURCHASEILR(bid,resC)
=l=
  PURCHASE(bid)
  ;

*======= RESERVE EQUATIONS END =================================================



*======= RISK AND RESERVE BALANCE EQUATIONS ====================================

* Matching of reserve supply and demand (3.4.4.1)
SupplyDemandReserveRequirement(currTP,ild,resC,riskC) $ useReserveModel..
  ISLANDRISK(currTP,ild,resC,riskC)
- DEFICITRESERVE(currTP,ild,resC)      $ {not DiffCeECeCVP}
- DEFICITRESERVE_CE(currTP,ild,resC)   $ {DiffCeECeCVP and ContingentEvents(riskC)}
- DEFICITRESERVE_ECE(currTP,ild,resC)  $ {DiffCeECeCVP and ExtendedContingentEvent(riskC)}
=l=
  ISLANDRESERVE(currTP,ild,resC)
* Scarcity pricing updates
+ VIRTUALRESERVE(currTP,ild,resC)
  ;

* Calculate total island cleared reserve (3.4.4.2)
IslandReserveCalculation(currTP,ild,resC)..
  ISLANDRESERVE(currTP,ild,resC)
=l=
  Sum[ (o,resT) $ { offer(currTP,o) and offerIsland(currTP,o,ild) }
                , RESERVE(currTP,o,resC,resT)
     ]
+ Sum[ bd $ { Bid(currTP,bd) and bidIsland(currTP,bd,ild) }
             , PURCHASEILR(currTP,bd,resC)
     ]
  ;

*======= RISK AND RESERVE BALANCE EQUATIONS END ================================




*======= SECURITY EQUATIONS ====================================================

* Branch security constraint with LE sense (3.5.1.5a)
BranchSecurityConstraintLE(currTP,brCstr)
  $ (BranchConstraintSense(currTP,brCstr) = -1)..
  sum[ br $ ACbranch(currTP,br)
     , BranchConstraintFactors(currTP,brCstr,br) * ACBRANCHFLOW(currTP,br) ]
+ sum[ br $ HVDClink(currTP,br)
     , BranchConstraintFactors(currTP,brCstr,br) * HVDCLINKFLOW(currTP,br) ]
- SURPLUSBRANCHSECURITYCONSTRAINT(currTP,brCstr)
=l=
  BranchConstraintLimit(currTP,brCstr)
  ;

* Branch security constraint with GE sense (3.5.1.5b)
BranchSecurityConstraintGE(currTP,brCstr)
  $ (BranchConstraintSense(currTP,brCstr) = 1)..
  sum[ br $ ACbranch(currTP,br)
     , BranchConstraintFactors(currTP,brCstr,br) * ACBRANCHFLOW(currTP,br) ]
+ sum[ br $ HVDClink(currTP,br)
     , BranchConstraintFactors(currTP,brCstr,br) * HVDCLINKFLOW(currTP,br) ]
+ DEFICITBRANCHSECURITYCONSTRAINT(currTP,brCstr)
=g=
  BranchConstraintLimit(currTP,brCstr)
  ;

* Branch security constraint with EQ sense (3.5.1.5c)
BranchSecurityConstraintEQ(currTP,brCstr)
  $ (BranchConstraintSense(currTP,brCstr) = 0)..
  sum[ br $ ACbranch(currTP,br)
     , BranchConstraintFactors(currTP,brCstr,br) * ACBRANCHFLOW(currTP,br) ]
+ sum[ br $ HVDClink(currTP,br)
     , BranchConstraintFactors(currTP,brCstr,br) * HVDCLINKFLOW(currTP,br) ]
+ DEFICITBRANCHSECURITYCONSTRAINT(currTP,brCstr)
- SURPLUSBRANCHSECURITYCONSTRAINT(currTP,brCstr)
=e=
  BranchConstraintLimit(currTP,brCstr)
  ;

* AC node security constraint with LE sense (3.5.1.6a)
ACnodeSecurityConstraintLE(currTP,ACnodeCstr)
  $ (ACnodeConstraintSense(currTP,ACnodeCstr) = -1)..
  sum[ (n,b) $ { ACnode(currTP,n) and NodeBus(currTP,n,b) }
             , ACnodeConstraintFactors(currTP,ACnodeCstr,n)
             * NodeBusAllocationFactor(currTP,n,b)
             * ACNODENETINJECTION(currTP,b)
     ]
- SURPLUSACnodeCONSTRAINT(currTP,ACnodeCstr)
=l=
  ACnodeConstraintLimit(currTP,ACnodeCstr)
  ;

* AC node security constraint with GE sense (3.5.1.6b)
ACnodeSecurityConstraintGE(currTP,ACnodeCstr)
  $ (ACnodeConstraintSense(currTP,ACnodeCstr) = 1)..
  sum[ (n,b) $ { ACnode(currTP,n) and NodeBus(currTP,n,b) }
             , ACnodeConstraintFactors(currTP,ACnodeCstr,n)
             * NodeBusAllocationFactor(currTP,n,b)
             * ACNODENETINJECTION(currTP,b)
     ]
+ DEFICITACnodeCONSTRAINT(currTP,ACnodeCstr)
=g=
  ACnodeConstraintLimit(currTP,ACnodeCstr)
  ;

* AC node security constraint with EQ sense (3.5.1.6c)
ACnodeSecurityConstraintEQ(currTP,ACnodeCstr)
  $ (ACnodeConstraintSense(currTP,ACnodeCstr) = 0)..
  sum[ (n,b) $ { ACnode(currTP,n) and NodeBus(currTP,n,b) }
             , ACnodeConstraintFactors(currTP,ACnodeCstr,n)
             * NodeBusAllocationFactor(currTP,n,b)
             * ACNODENETINJECTION(currTP,b)
     ]
+ DEFICITACnodeCONSTRAINT(currTP,ACnodeCstr)
- SURPLUSACnodeCONSTRAINT(currTP,ACnodeCstr)
=e=
  ACnodeConstraintLimit(currTP,ACnodeCstr)
  ;

* Market node security constraint with LE sense (3.5.1.7a)
MNodeSecurityConstraintLE(currTP,MnodeCstr)
  $ (MNodeConstraintSense(currTP,MnodeCstr) = -1)..
  sum[ o $ PositiveEnergyOffer(currTP,o)
       , MNodeEnergyOfferConstraintFactors(currTP,MnodeCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,resC,resT) $ offer(currTP,o)
       , MNodeReserveOfferConstraintFactors(currTP,MnodeCstr,o,resC,resT)
       * RESERVE(currTP,o,resC,resT)
     ]
+ sum[ bd $ Bid(currTP,bd)
       , MNodeEnergyBidConstraintFactors(currTP,MnodeCstr,bd)
       * PURCHASE(currTP,bd)
     ]
+ sum[ (bd,resC) $ Bid(currTP,bd)
       , MNodeILReserveBidConstraintFactors(currTP,MnodeCstr,bd,resC)
       * PURCHASEILR(currTP,bd,resC)
     ]
- SURPLUSMNODECONSTRAINT(currTP,MnodeCstr)
=l=
  MNodeConstraintLimit(currTP,MnodeCstr)
  ;

* Market node security constraint with GE sense (3.5.1.7b)
MNodeSecurityConstraintGE(currTP,MnodeCstr)
  $ (MNodeConstraintSense(currTP,MnodeCstr) = 1)..
  sum[ o $ PositiveEnergyOffer(currTP,o)
       , MNodeEnergyOfferConstraintFactors(currTP,MnodeCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,resC,resT) $ offer(currTP,o)
       , MNodeReserveOfferConstraintFactors(currTP,MnodeCstr,o,resC,resT)
       * RESERVE(currTP,o,resC,resT)
     ]
+ sum[ bd $ Bid(currTP,bd)
       , MNodeEnergyBidConstraintFactors(currTP,MnodeCstr,bd)
       * PURCHASE(currTP,bd)
     ]
+ sum[ (bd,resC) $ Bid(currTP,bd)
       , MNodeILReserveBidConstraintFactors(currTP,MnodeCstr,bd,resC)
       * PURCHASEILR(currTP,bd,resC)
     ]
+ DEFICITMNODECONSTRAINT(currTP,MnodeCstr)
=g=
  MNodeConstraintLimit(currTP,MnodeCstr)
  ;

* Market node security constraint with EQ sense (3.5.1.7c)
MNodeSecurityConstraintEQ(currTP,MnodeCstr)
  $ (MNodeConstraintSense(currTP,MnodeCstr) = 0)..
  sum[ o $ PositiveEnergyOffer(currTP,o)
       , MNodeEnergyOfferConstraintFactors(currTP,MnodeCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,resC,resT) $ offer(currTP,o)
       , MNodeReserveOfferConstraintFactors(currTP,MnodeCstr,o,resC,resT)
       * RESERVE(currTP,o,resC,resT)
     ]
+ sum[ bd $ Bid(currTP,bd)
       , MNodeEnergyBidConstraintFactors(currTP,MnodeCstr,bd)
       * PURCHASE(currTP,bd)
     ]
+ sum[ (bd,resC) $ Bid(currTP,bd)
       , MNodeILReserveBidConstraintFactors(currTP,MnodeCstr,bd,resC)
       * PURCHASEILR(currTP,bd,resC)
     ]
+ DEFICITMNODECONSTRAINT(currTP,MnodeCstr)
- SURPLUSMNODECONSTRAINT(currTP,MnodeCstr)
=e=
  MNodeConstraintLimit(currTP,MnodeCstr)
  ;

*======= SECURITY EQUATIONS END ================================================




*======= MIXED CONSTRAINTS =====================================================

* Type 1 mixed constraint definition with LE sense (3.6.1.1a)
Type1MixedConstraintLE(currTP,t1MixCstr)
  $ { useMixedConstraint(currTP) and (not useMixedConstraintMIP(currTP)) and
      (Type1MixedConstraintSense(currTP,t1MixCstr) = -1) }..
  i_type1MixedConstraintVarWeight(t1MixCstr)
  * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
+ sum[ o $ PositiveEnergyOffer(currTP,o)
       , i_type1MixedConstraintGenWeight(t1MixCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,resC,resT) $ offer(currTP,o)
       , i_type1MixedConstraintResWeight(t1MixCstr,o,resC,resT)
       * RESERVE(currTP,o,resC,resT)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineWeight(t1MixCstr,br)
       * HVDCLINKFLOW(currTP,br)
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineWeight(t1MixCstr,br)
       * sum[ fd, ACBRANCHFLOWDIRECTED(currTP,br,fd) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)
       * sum[ fd, ACBRANCHLOSSESDIRECTED(currTP,br,fd) ]
     ]
+ sum[ br $ { ACBranch(currTP,br) }
       , i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)
       * branchFixedLoss(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineLossWeight(t1MixCstr,br)
       * HVDCLINKLOSSES(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineFixedLossWeight(t1MixCstr,br)
       * branchFixedLoss(currTP,br)
     ]
+ sum[ bd $ Bid(currTP,bd)
       , i_type1MixedConstraintPurWeight(t1MixCstr,bd)
       * PURCHASE(currTP,bd)
     ]
- SURPLUSTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
=l=
  Type1MixedConstraintLimit1(currTP,t1MixCstr)
  ;


* Type 1 mixed constraint definition with GE sense (3.6.1.1b)
Type1MixedConstraintGE(currTP,t1MixCstr)
  $ { useMixedConstraint(currTP) and (not useMixedConstraintMIP(currTP)) and
      (Type1MixedConstraintSense(currTP,t1MixCstr) = 1) }..
  i_type1MixedConstraintVarWeight(t1MixCstr)
  * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
+ sum[ o $ PositiveEnergyOffer(currTP,o)
       , i_type1MixedConstraintGenWeight(t1MixCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,resC,resT) $ offer(currTP,o)
       , i_type1MixedConstraintResWeight(t1MixCstr,o,resC,resT)
       * RESERVE(currTP,o,resC,resT)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineWeight(t1MixCstr,br)
       * HVDCLINKFLOW(currTP,br)
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineWeight(t1MixCstr,br)
       * sum[ fd, ACBRANCHFLOWDIRECTED(currTP,br,fd) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)
       * sum[ fd, ACBRANCHLOSSESDIRECTED(currTP,br,fd) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)
       * branchFixedLoss(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
     , i_type1MixedConstraintHVDCLineLossWeight(t1MixCstr,br)
     * HVDCLINKLOSSES(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineFixedLossWeight(t1MixCstr,br)
       * branchFixedLoss(currTP,br)
     ]
+ sum[ bd $ Bid(currTP,bd)
     , i_type1MixedConstraintPurWeight(t1MixCstr,bd)
     * PURCHASE(currTP,bd)
     ]
+ DEFICITTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
=g=
  Type1MixedConstraintLimit1(currTP,t1MixCstr)
  ;

* Type 1 mixed constraint definition with EQ sense (3.6.1.1c)
Type1MixedConstraintEQ(currTP,t1MixCstr)
  $ { useMixedConstraint(currTP) and (not useMixedConstraintMIP(currTP)) and
     (Type1MixedConstraintSense(currTP,t1MixCstr) = 0) }..
  i_type1MixedConstraintVarWeight(t1MixCstr)
  * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
+ sum[ o $ PositiveEnergyOffer(currTP,o)
       , i_type1MixedConstraintGenWeight(t1MixCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,resC,resT) $ offer(currTP,o)
       , i_type1MixedConstraintResWeight(t1MixCstr,o,resC,resT)
       * RESERVE(currTP,o,resC,resT)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineWeight(t1MixCstr,br)
       * HVDCLINKFLOW(currTP,br)
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineWeight(t1MixCstr,br)
       * sum[ fd, ACBRANCHFLOWDIRECTED(currTP,br,fd) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)
       * sum[ fd, ACBRANCHLOSSESDIRECTED(currTP,br,fd) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)
       * branchFixedLoss(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineLossWeight(t1MixCstr,br)
       * HVDCLINKLOSSES(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineFixedLossWeight(t1MixCstr,br)
       * branchFixedLoss(currTP,br)
     ]
+ sum[ bd $ Bid(currTP,bd)
       , i_type1MixedConstraintPurWeight(t1MixCstr,bd)
       * PURCHASE(currTP,bd)
     ]
+ DEFICITTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
- SURPLUSTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
=e=
  Type1MixedConstraintLimit1(currTP,t1MixCstr)
  ;

* Type 2 mixed constraint definition with LE sense (3.6.1.2a)
Type2MixedConstraintLE(currTP,t2MixCstr)
  $ { useMixedConstraint(currTP) and
      (Type2MixedConstraintSense(currTP,t2MixCstr) = -1) }..
  sum[ t1MixCstr, i_type2MixedConstraintLHSParameters(t2MixCstr,t1MixCstr)
                * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr) ]
=l=
  Type2MixedConstraintLimit(currTP,t2MixCstr)
  ;

* Type 2 mixed constraint definition with GE sense (3.6.1.2b)
Type2MixedConstraintGE(currTP,t2MixCstr)
  $ { useMixedConstraint(currTP) and
      (Type2MixedConstraintSense(currTP,t2MixCstr) = 1) }..
  sum[ t1MixCstr, i_type2MixedConstraintLHSParameters(t2MixCstr,t1MixCstr)
                * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr) ]
=g=
  Type2MixedConstraintLimit(currTP,t2MixCstr)
  ;

* Type 2 mixed constraint definition with EQ sense (3.6.1.2c)
Type2MixedConstraintEQ(currTP,t2MixCstr)
  $ { useMixedConstraint(currTP) and
      (Type2MixedConstraintSense(currTP,t2MixCstr) = 0) }..
  sum[ t1MixCstr, i_type2MixedConstraintLHSParameters(t2MixCstr,t1MixCstr)
                * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr) ]
=e=
  Type2MixedConstraintLimit(currTP,t2MixCstr)
  ;

* Type 1 mixed constraint definition of alternate limit selection (integer)
Type1MixedConstraintMIP(currTP,t1MixCstr,br)
  $ { i_type1MixedConstraintBranchCondition(t1MixCstr,br) and
      useMixedConstraintRiskOffset and HVDCHalfPoles(currTP,br) and
      useMixedConstraintMIP(currTP) }..
  HVDCLINKFLOW(currTP,br)
=l=
  MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr) * MixedConstraintBigNumber
  ;

* Integer equivalent of Type 1 mixed constraint definition with LE sense (3.6.1.1a_MIP)
Type1MixedConstraintLE_MIP(Type1MixedConstraint(currTP,t1MixCstr))
  $ { useMixedConstraint(currTP) and useMixedConstraintMIP(currTP) and
      (Type1MixedConstraintSense(currTP,t1MixCstr) = -1) }..
  i_type1MixedConstraintVarWeight(t1MixCstr)
  * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
+ sum[ o $ PositiveEnergyOffer(currTP,o)
       , i_type1MixedConstraintGenWeight(t1MixCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,resC,resT) $ offer(currTP,o)
       , i_type1MixedConstraintResWeight(t1MixCstr,o,resC,resT)
       * RESERVE(currTP,o,resC,resT)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineWeight(t1MixCstr,br)
       * HVDCLINKFLOW(currTP,br)
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineWeight(t1MixCstr,br)
       * sum[ fd, ACBRANCHFLOWDIRECTED(currTP,br,fd) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)
       * sum[ fd, ACBRANCHLOSSESDIRECTED(currTP,br,fd) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)
       * branchFixedLoss(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineLossWeight(t1MixCstr,br)
       * HVDCLINKLOSSES(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineFixedLossWeight(t1MixCstr,br)
       * branchFixedLoss(currTP,br)
     ]
+ sum[ bd $ Bid(currTP,bd)
       , i_type1MixedConstraintPurWeight(t1MixCstr,bd)
       * PURCHASE(currTP,bd)
     ]
- SURPLUSTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
=l=
  Type1MixedConstraintLimit1(currTP,t1MixCstr)
  * (1 - MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr))
+ Type1MixedConstraintLimit2(currTP,t1MixCstr)
  * MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr)
  ;

* Integer equivalent of Type 1 mixed constraint definition with GE sense (3.6.1.1b_MIP)
Type1MixedConstraintGE_MIP(Type1MixedConstraint(currTP,t1MixCstr))
  $ { useMixedConstraint(currTP) and useMixedConstraintMIP(currTP) and
      (Type1MixedConstraintSense(currTP,t1MixCstr) = 1) }..
  i_type1MixedConstraintVarWeight(t1MixCstr)
  * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
+ sum[ o $ PositiveEnergyOffer(currTP,o)
       , i_type1MixedConstraintGenWeight(t1MixCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,resC,resT) $ offer(currTP,o)
       , i_type1MixedConstraintResWeight(t1MixCstr,o,resC,resT)
       * RESERVE(currTP,o,resC,resT)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineWeight(t1MixCstr,br)
       * HVDCLINKFLOW(currTP,br)
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineWeight(t1MixCstr,br)
       * sum[ fd, ACBRANCHFLOWDIRECTED(currTP,br,fd) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)
       * sum[ fd, ACBRANCHLOSSESDIRECTED(currTP,br,fd) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)
       * branchFixedLoss(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineLossWeight(t1MixCstr,br)
       * HVDCLINKLOSSES(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineFixedLossWeight(t1MixCstr,br)
       * branchFixedLoss(currTP,br)
     ]
+ sum[ bd $ Bid(currTP,bd)
       , i_type1MixedConstraintPurWeight(t1MixCstr,bd)
       * PURCHASE(currTP,bd)
     ]
+ DEFICITTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
=g=
  Type1MixedConstraintLimit1(currTP,t1MixCstr)
  * (1 - MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr))
+ Type1MixedConstraintLimit2(currTP,t1MixCstr)
  * MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr)
  ;

* Integer equivalent of Type 1 mixed constraint definition with EQ sense (3.6.1.1b_MIP)
Type1MixedConstraintEQ_MIP(Type1MixedConstraint(currTP,t1MixCstr))
  $ { useMixedConstraint(currTP) and useMixedConstraintMIP(currTP) and
     (Type1MixedConstraintSense(currTP,t1MixCstr) = 0) }..
  i_type1MixedConstraintVarWeight(t1MixCstr)
  * MIXEDCONSTRAINTVARIABLE(currTP,t1MixCstr)
+ sum[ o $ PositiveEnergyOffer(currTP,o)
       , i_type1MixedConstraintGenWeight(t1MixCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,resC,resT) $ offer(currTP,o)
       , i_type1MixedConstraintResWeight(t1MixCstr,o,resC,resT)
       * RESERVE(currTP,o,resC,resT)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineWeight(t1MixCstr,br)
       * HVDCLINKFLOW(currTP,br)
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineWeight(t1MixCstr,br)
       * sum[ fd, ACBRANCHFLOWDIRECTED(currTP,br,fd) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineLossWeight(t1MixCstr,br)
       * sum[ fd, ACBRANCHLOSSESDIRECTED(currTP,br,fd) ]
     ]
+ sum[ br $ ACBranch(currTP,br)
       , i_type1MixedConstraintAClineFixedLossWeight(t1MixCstr,br)
       * branchFixedLoss(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineLossWeight(t1MixCstr,br)
       * HVDCLINKLOSSES(currTP,br)
     ]
+ sum[ br $ HVDClink(currTP,br)
       , i_type1MixedConstraintHVDCLineFixedLossWeight(t1MixCstr,br)
       * branchFixedLoss(currTP,br)
     ]
+ sum[ bd $ Bid(currTP,bd)
       , i_type1MixedConstraintPurWeight(t1MixCstr,bd)
       * PURCHASE(currTP,bd)
     ]
+ DEFICITTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
- SURPLUSTYPE1MIXEDCONSTRAINT(currTP,t1MixCstr)
=e=
  Type1MixedConstraintLimit1(currTP,t1MixCstr)
  * (1 - MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr))
+ Type1MixedConstraintLimit2(currTP,t1MixCstr)
  * MIXEDCONSTRAINTLIMIT2SELECT(currTP,t1MixCstr)
  ;

*======= MIXED CONSTRAINTS END =================================================




*======= GENERIC SECURITY CONSTRAINTS ==========================================

* Generic security constraint with LE sense
GenericSecurityConstraintLE(currTP,gnrcCstr)
  $ (GenericConstraintSense(currTP,gnrcCstr) = -1)..
  sum[ o $ PositiveEnergyOffer(currTP,o)
       , GenericEnergyOfferConstraintFactors(currTP,gnrcCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,resC,resT) $ offer(currTP,o)
       , GenericReserveOfferConstraintFactors(currTP,gnrcCstr,o,resC,resT)
       * RESERVE(currTP,o,resC,resT)
     ]
+ sum[ bd $ Bid(currTP,bd)
     , GenericEnergyBidConstraintFactors(currTP,gnrcCstr,bd)
     * PURCHASE(currTP,bd)
     ]
+ sum[ (bd,resC) $ Bid(currTP,bd)
       , GenericILReserveBidConstraintFactors(currTP,gnrcCstr,bd,resC)
       * PURCHASEILR(currTP,bd,resC)
     ]
+ sum[ br $ { ACBranch(currTP,br) or HVDClink(currTP,br) }
       , GenericBranchConstraintFactors(currTP,gnrcCstr,br)
       * (ACBRANCHFLOW(currTP,br) + HVDCLINKFLOW(currTP,br))
     ]
- SURPLUSGENERICCONSTRAINT(currTP,gnrcCstr)
=l=
  GenericConstraintLimit(currTP,gnrcCstr)
  ;

* Generic security constraint with GE sense
GenericSecurityConstraintGE(currTP,gnrcCstr)
  $ (GenericConstraintSense(currTP,gnrcCstr) = 1)..
  sum[ o $ PositiveEnergyOffer(currTP,o)
       , GenericEnergyOfferConstraintFactors(currTP,gnrcCstr,o)
       * GENERATION(currTP,o)
     ]
+ sum[ (o,resC,resT) $ offer(currTP,o)
       , GenericReserveOfferConstraintFactors(currTP,gnrcCstr,o,resC,resT)
       * RESERVE(currTP,o,resC,resT)
     ]
+ sum[ bd $ Bid(currTP,bd)
       , GenericEnergyBidConstraintFactors(currTP,gnrcCstr,bd)
       * PURCHASE(currTP,bd)
     ]
+ sum[ (bd,resC) $ Bid(currTP,bd)
       , GenericILReserveBidConstraintFactors(currTP,gnrcCstr,bd,resC)
       * PURCHASEILR(currTP,bd,resC)
     ]
+ sum[ br $ { ACBranch(currTP,br) or HVDClink(currTP,br) }
       , GenericBranchConstraintFactors(currTP,gnrcCstr,br)
       * (ACBRANCHFLOW(currTP,br) + HVDCLINKFLOW(currTP,br))
     ]
+ DEFICITGENERICCONSTRAINT(currTP,gnrcCstr)
=g=
  GenericConstraintLimit(currTP,gnrcCstr)
  ;

* Generic security constraint with EQ sense
GenericSecurityConstraintEQ(currTP,gnrcCstr)
  $ (GenericConstraintSense(currTP,gnrcCstr) = 0)..
  sum[ o $ PositiveEnergyOffer(currTP,o)
         , GenericEnergyOfferConstraintFactors(currTP,gnrcCstr,o)
         * GENERATION(currTP,o)
     ]
+ sum[ (o,resC,resT) $ offer(currTP,o)
       , GenericReserveOfferConstraintFactors(currTP,gnrcCstr,o,resC,resT)
       * RESERVE(currTP,o,resC,resT)
     ]
+ sum[ bd $ Bid(currTP,bd)
       , GenericEnergyBidConstraintFactors(currTP,gnrcCstr,bd)
       * PURCHASE(currTP,bd)
     ]
+ sum[ (bd,resC) $ Bid(currTP,bd)
       , GenericILReserveBidConstraintFactors(currTP,gnrcCstr,bd,resC)
       * PURCHASEILR(currTP,bd,resC)
     ]
+ sum[ br $ { ACBranch(currTP,br) or HVDClink(currTP,br) }
       , GenericBranchConstraintFactors(currTP,gnrcCstr,br)
      * (ACBRANCHFLOW(currTP,br) + HVDCLINKFLOW(currTP,br))
     ]
+ DEFICITGENERICCONSTRAINT(currTP,gnrcCstr)
- SURPLUSGENERICCONSTRAINT(currTP,gnrcCstr)
=e=
  GenericConstraintLimit(currTP,gnrcCstr)
  ;

*======= GENERIC SECURITY CONSTRAINTS END ======================================


* Model declarations
Model vSPD /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, PurchaseBidDefintion
  GenerationRampUp, GenerationRampDown
* Network
  HVDClinkMaximumFlow, HVDClinkLossDefinition
  HVDClinkFlowDefinition, LambdaDefinition
  DCNodeNetInjection, ACnodeNetInjectionDefinition1
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
  ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum
  PurchaseBidReserveMaximum
* Matching of reserve requirement and availability
  SupplyDemandReserveRequirement, IslandReserveCalculation
* Risk Offset calculation
  RiskOffsetCalculation
  RiskOffsetCalculation_DCCE
  RiskOffsetCalculation_DCECE
* Island risk definitions
* Include HVDC secondary risk constraints
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_GEN_1
  HVDCIslandSecRiskCalculation_Manual, HVDCIslandSecRiskCalculation_Manu_1
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
  SystemCostDefinition, SystemBenefitDefinition
  SystemPenaltyCostDefinition, TotalViolationCostDefinition
  / ;

Model vSPD_NMIR /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, PurchaseBidDefintion
  GenerationRampUp, GenerationRampDown
* Network
  HVDClinkMaximumFlow, HVDClinkLossDefinition
  HVDClinkFlowDefinition, LambdaDefinition
  DCNodeNetInjection, ACnodeNetInjectionDefinition1
  ACnodeNetInjectionDefinition2, ACBranchMaximumFlow
  ACBranchFlowDefinition, LinearLoadFlow
  ACBranchBlockLimit, ACDirectedBranchFlowDefinition
  ACBranchLossCalculation, ACDirectedBranchLossDefinition
* Risk
  RiskOffsetCalculation,RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
  HVDCIslandRiskCalculation, HVDCRecCalculation, ManualIslandRiskCalculation
  GenIslandRiskCalculation, GenIslandRiskCalculation_1
  GenIslandRiskGroupCalculation, GenIslandRiskGroupCalculation_1
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_GEN_1
  HVDCIslandSecRiskCalculation_Manual, HVDCIslandSecRiskCalculation_Manu_1
* Reserve
  PLSRReserveProportionMaximum, ReserveOfferDefinition
  ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum
  PurchaseBidReserveMaximum
* Matching of reserve requirement and availability
  SupplyDemandReserveRequirement, IslandReserveCalculation
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
  SystemCostDefinition, SystemBenefitDefinition
  SystemPenaltyCostDefinition, TotalViolationCostDefinition
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
  GenerationOfferDefintion, PurchaseBidDefintion
  GenerationRampUp, GenerationRampDown
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
* Risk
  RiskOffsetCalculation,RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
  HVDCIslandRiskCalculation, HVDCRecCalculation, ManualIslandRiskCalculation
  GenIslandRiskCalculation, GenIslandRiskCalculation_1
  GenIslandRiskGroupCalculation, GenIslandRiskGroupCalculation_1
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_GEN_1
  HVDCIslandSecRiskCalculation_Manual, HVDCIslandSecRiskCalculation_Manu_1
* Reserve
  PLSRReserveProportionMaximum, ReserveOfferDefinition
  ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum
  PurchaseBidReserveMaximum
* Matching of reserve requirement and availability
  SupplyDemandReserveRequirement, IslandReserveCalculation
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
  SystemCostDefinition, SystemBenefitDefinition
  SystemPenaltyCostDefinition, TotalViolationCostDefinition
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
  GenerationOfferDefintion, PurchaseBidDefintion
  GenerationRampUp, GenerationRampDown
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
* Risk
  RiskOffsetCalculation,RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
  HVDCIslandRiskCalculation, HVDCRecCalculation, ManualIslandRiskCalculation
  GenIslandRiskCalculation, GenIslandRiskCalculation_1
  GenIslandRiskGroupCalculation, GenIslandRiskGroupCalculation_1
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_GEN_1
  HVDCIslandSecRiskCalculation_Manual, HVDCIslandSecRiskCalculation_Manu_1
* Reserve
  PLSRReserveProportionMaximum, ReserveOfferDefinition
  ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum
  PurchaseBidReserveMaximum
* Matching of reserve requirement and availability
  SupplyDemandReserveRequirement, IslandReserveCalculation
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
  SystemCostDefinition, SystemBenefitDefinition
  SystemPenaltyCostDefinition, TotalViolationCostDefinition
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

Model vSPD_MixedConstraintMIP /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, PurchaseBidDefintion
  GenerationRampUp, GenerationRampDown
* Network
  HVDClinkMaximumFlow, HVDClinkLossDefinition
  HVDClinkFlowDefinition, LambdaDefinition
  DCNodeNetInjection, ACnodeNetInjectionDefinition1
  ACnodeNetInjectionDefinition2, ACBranchMaximumFlow
  ACBranchFlowDefinition, LinearLoadFlow
  ACBranchBlockLimit, ACDirectedBranchFlowDefinition
  ACBranchLossCalculation, ACDirectedBranchLossDefinition
* Risk
  RiskOffsetCalculation,RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
  HVDCIslandRiskCalculation, HVDCRecCalculation, ManualIslandRiskCalculation
  GenIslandRiskCalculation, GenIslandRiskCalculation_1
  GenIslandRiskGroupCalculation, GenIslandRiskGroupCalculation_1
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_GEN_1
  HVDCIslandSecRiskCalculation_Manual, HVDCIslandSecRiskCalculation_Manu_1
* Reserve
  PLSRReserveProportionMaximum, ReserveOfferDefinition
  ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum
  PurchaseBidReserveMaximum
* Matching of reserve requirement and availability
  SupplyDemandReserveRequirement, IslandReserveCalculation
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
  SystemCostDefinition, SystemBenefitDefinition
  SystemPenaltyCostDefinition, TotalViolationCostDefinition
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
  HVDClinkMaximumFlow, DCNodeNetInjection
  ACNodeNetInjectionDefinition1, ACNodeNetInjectionDefinition2
  ACBranchMaximumFlow, ACBranchFlowDefinition, LinearLoadFlow
* Branch security constraints
  BranchSecurityConstraintLE
* ViolationCost
  SystemCostDefinition, SystemBenefitDefinition
  SystemPenaltyCostDefinition, TotalViolationCostDefinition
  / ;
