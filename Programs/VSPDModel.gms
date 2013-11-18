*=====================================================================================
* Name:                 vSPDmodel.gms
* Function:             Mathematical formulation.  Based on the SPD model formulation v7.0
* Developed by:         Ramu Naidoo (Electricity Authority, New Zealand)
* Last modified by:     Ramu Naidoo on 6 May 2013
*=====================================================================================


*===================================================================================
* Section 1: Declare sets and parameters for all symbols to be loaded from daily GDX files
*===================================================================================

Sets
* 22 sets - although these 22 sets are in the daily input GDX file, they are not loaded from the GDX file.
* Rather, all but caseName are initialsed via hard-coding in vSPDsolve.gms prior to loading data from the
* GDX file. They are declared at this point because they appear in the domain of other symbols that are
* declared below.
  i_island(*)                              'Island definition'
  i_reserveClass(*)                        'Definition of fast and sustained instantaneous reserve'
  i_reserveType(*)                         'Definition of the different reserve types (PLSR, TWDR, ILR)'
  i_riskClass(*)                           'Different risks that could set the reserve requirements'
  i_riskParameter(*)                       'Different risk parameters that are specified as inputs to the dispatch model'
  i_offerType(*)                           'Type of energy and reserve offers from market participants'
  i_offerParam(*)                          'Different parameters specified for each offer'
  i_energyOfferComponent(*)                'Components of the energy offer comprising of block MW capacity and price'
  i_PLSRofferComponent(*)                  'Components of the PLSR offer comprising of MW proportion, block MW and price'
  i_TWDRofferComponent(*)                  'Components of the TWDR offer comprising of block MW and price'
  i_ILRofferComponent(*)                   'Components of the ILR offer comprising of block MW and price'
  i_energyBidComponent(*)                  'Components of the energy bid comprising of the block MW capacity and the price'
  i_ILRbidComponent(*)                     'Components of the ILR provided by bids'
  i_tradeBlock(*)                          'Trade block definitions.  These are used for the offer and bid tranches'
  i_branchParameter(*)                     'Branch parameter specified'
  i_lossSegment(*)                         'Loss segments available for loss modelling'
  i_lossParameter(*)                       'Components of the piecewise loss function'
  i_constraintRHS(*)                       'Constraint RHS definition'
  i_type1MixedConstraintRHS(*)             'Type 1 mixed constraint RHS definitions'
  i_flowDirection(*)                       'Directional flow definition used in the formulation'
  i_CVP(*)                                 'Constraint violation penalties used in the model'
  caseName(*)                              'Final pricing case name used to create the GDX file'

* 14 fundamental sets - membership is populated via loading from GDX file in vSPDsolve.gms
  i_dateTime(*)                            'Date and time for the trade periods'
  i_tradePeriod(*)                         'Trade periods for which input data is defined'
  i_offer(*)                               'Offers for all trading periods'
  i_trader(*)                              'Traders defined for all the trading periods'
  i_bid(*)                                 'Bids for all the trading periods'
  i_node(*)                                'Node definitions for all the trading periods'
  i_bus(*)                                 'Bus definitions for all the trading periods'
  i_branch(*)                              'Branch definition for all the trading periods'
  i_branchConstraint(*)                    'Branch constraint definitions for all the trading periods'
  i_ACnodeConstraint(*)                    'AC node constraint definitions for all the trading periods'
  i_MnodeConstraint(*)                     'Market node constraint definitions for all the trading periods'
  i_type1MixedConstraint(*)                'Type 1 mixed constraint definitions for all the tradeing periods'
  i_type2MixedConstraint(*)                'Type 2 mixed constraint definitions for all the trading periods'
  i_genericConstraint(*)                   'Generic constraint names for all the trading periods'
  ;

* 7 Aliases
Alias (i_island,island), (i_bus,i_toBus,i_FromBus,i_bus1), (i_lossSegment,i_lossSegment1), (i_branch,i_branch1), (i_offer,i_offer1) ;

Sets
* 16 multi-dimensional sets, subsets, and mapping sets - membership is populated via loading from GDX file in vSPDsolve.gms
  i_dateTimeTradePeriodMap(i_dateTime,i_tradePeriod)                       'Mapping of date time set to the trade period set'
  i_tradePeriodOfferTrader(i_tradePeriod,i_offer,i_trader)                 'Offers and the corresponding trader for the different trading periods'
  i_tradePeriodOfferNode(i_tradePeriod,i_offer,i_node)                     'Offers and the corresponding offer node for the different trading periods'
  i_tradePeriodBidTrader(i_tradePeriod,i_bid,i_trader)                     'Bids and the corresponding trader for the different trading periods'
  i_tradePeriodBidNode(i_tradePeriod,i_bid,i_node)                         'Bids and the corresponding node for the different trading periods'
  i_tradePeriodNode(i_tradePeriod,i_node)                                  'Node definition for the different trading periods'
  i_tradePeriodBusIsland(i_tradePeriod,i_bus,i_island)                     'Bus island mapping for the different trade periods'
  i_tradePeriodBus(i_tradePeriod,i_bus)                                    'Bus definition for the different trading periods'
  i_tradePeriodNodeBus(i_tradePeriod,i_node,i_bus)                         'Node bus mapping for the different trading periods'
  i_tradePeriodBranchDefn(i_tradePeriod,i_branch,i_fromBus,i_toBus)        'Branch definition for the different trading periods'
  i_tradePeriodRiskGenerator(i_tradePeriod,i_offer)                        'Set of generators (offers) that can set the risk in the different trading periods'
  i_type1MixedConstraintReserveMap(i_type1MixedConstraint,i_island,i_reserveClass,i_riskClass) 'Mapping of mixed constraint variables to reserve-related data'
  i_tradePeriodType1MixedConstraint(i_tradePeriod,i_type1MixedConstraint)  'Set of mixed constraints defined for the different trading periods'
  i_tradePeriodType2MixedConstraint(i_tradePeriod,i_type2MixedConstraint)  'Set of mixed constraints defined for the different trading periods'
  i_type1MixedConstraintBranchCondition(i_type1MixedConstraint,i_branch)   'Set of mixed constraints that have limits conditional on branch flows'
  i_tradePeriodGenericConstraint(i_tradePeriod,i_genericConstraint)        'Generic constraints defined for the different trading periods'

* 1 set loaded from GDX with conditional load statement in vSPDsolve.gms at execution time
  i_tradePeriodPrimarySecondaryOffer(i_tradePeriod,i_offer,i_offer1)       'Primary-secondary offer mapping for the different trading periods'
  ;

Parameters
* 6 scalars - values are loaded from GDX file in vSPDsolve.gms
  i_day                                    'Day number (1..31)'
  i_month                                  'Month number (1..12)'
  i_year                                   'Year number (1900..2200)'
  i_tradingPeriodLength                    'Length of the trading period in minutes (e.g. 30)'
  i_AClineUnit                             '0 = Actual values, 1 = per unit values on a 100MVA base'
  i_branchReceivingEndLossProportion       'Proportion of losses to be allocated to the receiving end of a branch'

* 49 parameters - values are loaded from GDX file in vSPDsolve.gms
  i_StudyTradePeriod(i_tradePeriod)        'Trade periods that are to be studied'
  i_CVPvalues(i_CVP)                       'Values for the constraint violation penalties'
* Offer data
  i_tradePeriodOfferParameter(i_tradePeriod,i_offer,i_offerParam)                          'InitialMW for each offer for the different trading periods'
  i_tradePeriodEnergyOffer(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent)      'Energy offers for the different trading periods'
  i_tradePeriodSustainedPLSRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_PLSRofferComponent) 'Sustained (60s) PLSR offers for the different trading periods'
  i_tradePeriodFastPLSRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_PLSRofferComponent)      'Fast (6s) PLSR offers for the different trading periods'
  i_tradePeriodSustainedTWDRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_TWDRofferComponent) 'Sustained (60s) TWDR offers for the different trading periods'
  i_tradePeriodFastTWDRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_TWDRofferComponent)      'Fast (6s) TWDR offers for the different trading periods'
  i_tradePeriodSustainedILRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_ILRofferComponent)   'Sustained (60s) ILR offers for the different trading periods'
  i_tradePeriodFastILRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_ILRofferComponent)        'Fast (6s) ILR offers for the different trading periods'
* Demand data
  i_tradePeriodNodeDemand(i_tradePeriod,i_node)                                            'MW demand at each node for all trading periods'
* Bid data
  i_tradePeriodEnergyBid(i_tradePeriod,i_bid,i_tradeBlock,i_energyBidComponent)            'Energy bids for the different trading periods'
  i_tradePeriodSustainedILRbid(i_tradePeriod,i_bid,i_tradeBlock,i_ILRbidComponent)         'Sustained ILR bids for the different trading periods'
  i_tradePeriodFastILRbid(i_tradePeriod,i_bid,i_tradeBlock,i_ILRbidComponent)              'Fast ILR bids for the different trading periods'
* Network data
  i_tradePeriodHVDCNode(i_tradePeriod,i_node)                                              'HVDC node for the different trading periods'
  i_tradePeriodReferenceNode(i_tradePeriod,i_node)                                         'Reference nodes for the different trading periods'
  i_tradePeriodHVDCBranch(i_tradePeriod,i_branch)                                          'HVDC branch indicator for the different trading periods'
  i_tradePeriodBranchParameter(i_tradePeriod,i_branch,i_branchParameter)                   'Branch resistance, reactance, fixed losses and number of loss tranches for the different time periods'
  i_tradePeriodBranchCapacity(i_tradePeriod,i_branch)                                      'Branch capacity for the different trading periods in MW'
  i_tradePeriodBranchOpenStatus(i_tradePeriod,i_branch)                                    'Branch open status for the different trading periods, 1 = Open'
  i_noLossBranch(i_lossSegment,i_lossParameter)                                            'Loss parameters for no loss branches'
  i_AClossBranch(i_lossSegment,i_lossParameter)                                            'Loss parameters for AC loss branches'
  i_HVDClossBranch(i_lossSegment,i_lossParameter)                                          'Loss parameters for HVDC loss branches'
  i_tradePeriodNodeBusAllocationFactor(i_tradePeriod,i_node,i_bus)                         'Allocation factor of market node quantities to bus for the different trading periods'
  i_tradePeriodBusElectricalIsland(i_tradePeriod,i_bus)                                    'Electrical island status of each bus for the different trading periods (0 = Dead)'
* Risk/Reserve data
  i_tradePeriodRiskParameter(i_tradePeriod,i_island,i_reserveClass,i_riskClass,i_riskParameter) 'Risk parameters for the different trading periods (From RMT)'
  i_tradePeriodManualRisk(i_tradePeriod,i_island,i_reserveClass)                           'Manual risk set for the different trading periods'
* Branch constraint data
  i_tradePeriodBranchConstraintFactors(i_tradePeriod,i_branchConstraint,i_branch)          'Branch constraint factors (sensitivities) for the different trading periods'
  i_tradePeriodBranchConstraintRHS(i_tradePeriod,i_branchConstraint,i_constraintRHS)       'Branch constraint sense and limit for the different trading periods'
* AC node constraint data
  i_tradePeriodACnodeConstraintFactors(i_tradePeriod,i_ACnodeConstraint,i_node)            'AC node constraint factors (sensitivities) for the different trading periods'
  i_tradePeriodACnodeConstraintRHS(i_tradePeriod,i_ACnodeConstraint,i_constraintRHS)       'AC node constraint sense and limit for the different trading periods'
* Market node constraint data
  i_tradePeriodMNodeEnergyOfferConstraintFactors(i_tradePeriod,i_MNodeConstraint,i_offer)                                  'Market node energy offer constraint factors for the different trading periods'
  i_tradePeriodMNodeReserveOfferConstraintFactors(i_tradePeriod,i_MNodeConstraint,i_offer,i_reserveClass,i_reserveType)    'Market node reserve offer constraint factors for the different trading periods'
  i_tradePeriodMNodeEnergyBidConstraintFactors(i_tradePeriod,i_MNodeConstraint,i_bid)                                      'Market node energy bid constraint factors for the different trading periods'
  i_tradePeriodMNodeILReserveBidConstraintFactors(i_tradePeriod,i_MNodeConstraint,i_bid,i_reserveClass)                    'Market node IL reserve bid constraint factors for the different trading periods'
  i_tradePeriodMNodeConstraintRHS(i_tradePeriod,i_MNodeConstraint,i_constraintRHS)                                         'Market node constraint sense and limit for the different trading periods'
* Mixed constraint data
  i_type1MixedConstraintVarWeight(i_type1MixedConstraint)                                                                  'Type 1 mixed constraint variable weights'
  i_type1MixedConstraintGenWeight(i_type1MixedConstraint,i_offer)                                                          'Type 1 mixed constraint generator weights'
  i_type1MixedConstraintResWeight(i_type1MixedConstraint,i_offer,i_reserveClass,i_reserveType)                             'Type 1 mixed constraint reserve weights'
  i_type1MixedConstraintHVDClineWeight(i_type1MixedConstraint,i_branch)                                                    'Type 1 mixed constraint HVDC branch flow weights'
  i_tradePeriodType1MixedConstraintRHSParameters(i_tradePeriod,i_type1MixedConstraint,i_type1MixedConstraintRHS)           'Type 1 mixed constraint RHS parameters'
  i_type2MixedConstraintLHSParameters(i_type2MixedConstraint,i_type1MixedConstraint)                                       'Type 2 mixed constraint LHS weights'
  i_tradePeriodType2MixedConstraintRHSParameters(i_tradePeriod,i_type2MixedConstraint,i_constraintRHS)                     'Type 2 mixed constraint RHS parameters'
* Generic constraint data
  i_tradePeriodGenericEnergyOfferConstraintFactors(i_tradePeriod,i_genericConstraint,i_offer)                              'Generic constraint offer constraint factors for the different trading periods'
  i_tradePeriodGenericReserveOfferConstraintFactors(i_tradePeriod,i_genericConstraint,i_offer,i_reserveClass,i_reserveType)'Generic constraint reserve offer constraint factors for the different trading periods'
  i_tradePeriodGenericEnergyBidConstraintFactors(i_tradePeriod,i_genericConstraint,i_bid)                                  'Generic constraint energy bid constraint factors for the different trading periods'
  i_tradePeriodGenericILReserveBidConstraintFactors(i_tradePeriod,i_genericConstraint,i_bid,i_reserveClass)                'Generic constraint IL reserve bid constraint factors for the different trading periods'
  i_tradePeriodGenericBranchConstraintFactors(i_tradePeriod,i_genericConstraint,i_branch)                                  'Generic constraint energy offer constraint factors for the different trading periods'
  i_tradePeriodGenericConstraintRHS(i_tradePeriod,i_genericConstraint,i_constraintRHS)                                     'Generic constraint sense and limit for the different trading periods'

* 11 parameters loaded from GDX with conditional load statement at execution time
  i_tradePeriodAllowHVDCRoundpower(i_tradePeriod)                                          'Flag to allow roundpower on the HVDC (1 = Yes)'
  i_tradePeriodManualRisk_ECE(i_tradePeriod,i_island,i_reserveClass)                       'Manual ECE risk set for the different trading periods'
  i_tradePeriodHVDCSecRiskEnabled(i_tradePeriod,i_island,i_riskClass)                      'Flag indicating if the HVDC secondary risk is enabled (1 = Yes)'
  i_tradePeriodHVDCSecRiskSubtractor(i_tradePeriod,i_island)                               'Ramp up capability on the HVDC pole that is not the secondary risk'
  i_type1MixedConstraintAClineWeight(i_type1MixedConstraint,i_branch)                      'Type 1 mixed constraint AC branch flow weights'
  i_type1MixedConstraintAClineLossWeight(i_type1MixedConstraint,i_branch)                  'Type 1 mixed constraint AC branch loss weights'
  i_type1MixedConstraintAClineFixedLossWeight(i_type1MixedConstraint,i_branch)             'Type 1 mixed constraint AC branch fixed losses weight'
  i_type1MixedConstraintHVDClineLossWeight(i_type1MixedConstraint,i_branch)                'Type 1 mixed constraint HVDC branch loss weights'
  i_type1MixedConstraintHVDClineFixedLossWeight(i_type1MixedConstraint,i_branch)           'Type 1 mixed constraint HVDC branch fixed losses weight'
  i_type1MixedConstraintPurWeight(i_type1MixedConstraint,i_bid)                            'Type 1 mixed constraint demand bid weights'
  i_tradePeriodReserveClassGenerationMaximum(i_tradePeriod,i_offer,i_reserveClass)         'MW used to determine factor to adjust maximum reserve of a reserve class'
  ;

* End of GDX declarations



*===================================================================================
* Section 2: Additional declarations of sets and parameters used throughout the model
*===================================================================================

Scalars
  i_sequentialSolve
  i_useACLossModel
  i_useHVDCLossModel
  i_useACBranchLimits                      'Use the AC branch limits (1 = Yes)'
  i_useHVDCBranchLimits                    'Use the HVDC branch limits (1 = Yes)'
  i_resolveCircularBranchFlows             'Resolve circular branch flows (1 = Yes)'
  i_resolveHVDCNonPhysicalLosses           'Resolve nonphysical losses on HVDC branches (1 = Yes)'
  i_resolveACNonPhysicalLosses             'Resolve nonphysical losses on AC branches (1 = Yes)'
  circularBranchFlowTolerance
  nonPhysicalLossTolerance
  useBranchFlowMIPTolerance
  i_useReserveModel                        'Use the reserve model (1 = Yes)'
  i_useMixedConstraint                     'Use the mixed constraint formulation (1 = Yes)'
  mixedMIPtolerance
  LPtimeLimit                              'CPU seconds allowed for LP solves'
  LPiterationLimit                         'Iteration limit allowed for LP solves'
  MIPtimeLimit                             'CPU seconds allowed for MIP solves'
  MIPiterationLimit                        'Iteration limit allowed for MIP solves'
  MIPoptimality
  i_disconnectedNodePriceCorrection
  i_useExternalLossModel
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
  pole                                                                                       'HVDC poles'
  currentTradePeriod(i_tradePeriod)                                                          'Current trading period'
* Offer
  offer(i_tradePeriod,i_offer)                                                               'Offers defined for the current trading period'
  offerNode(i_tradePeriod,i_offer,i_node)                                                    'Mapping of the offers to the nodes for the current trading period'
  validGenerationOfferBlock(i_tradePeriod,i_offer,i_tradeBlock)                              'Valid trade blocks for the respective generation offers'
  validReserveOfferBlock(i_tradePeriod,i_offer,i_tradeBlock,i_reserveClass,i_reserveType)    'Valid trade blocks for the respective reserve offers by class and type'
  PreviousMW(i_offer)                                                                        'MW output of offer to be used as initial MW of the next trading period if necessary'
  PositiveEnergyOffer(i_tradePeriod,i_offer)                                                 'Postive energy offers defined for the current trading period'
* RDN - Additional set for primary secondary offers
  PrimarySecondaryOffer(i_tradePeriod,i_offer,i_offer1)                                      'Primary-secondary offer mapping for the current trading period'
* Bid
  Bid(i_tradePeriod,i_bid)                                                                   'Bids defined for the current trading period'
  BidNode(i_tradePeriod,i_bid,i_node)                                                        'Mapping of the bids to the nodes for the current trading period'
  ValidPurchaseBidBlock(i_tradePeriod,i_bid,i_tradeBlock)                                    'Valid trade blocks for the respective purchase bids'
  ValidPurchaseBidILRBlock(i_tradePeriod,i_bid,i_tradeBlock,i_reserveClass)                  'Valid trade blocks for the respective purchase bids ILR'
* Network
  Node(i_tradePeriod,i_node)                                               'Nodes defined for the current trading period'
  Bus(i_tradePeriod,i_bus)                                                 'Buses defined for the current trading period'
  NodeBus(i_tradePeriod,i_node,i_bus)                                      'Mapping of the nodes to the buses for the current trading period'
  NodeIsland(i_tradePeriod,i_node,i_island)                                'Mapping of the node to the island for the current trading period'
  BusIsland(i_tradePeriod,i_bus,i_island)                                  'Mapping of the bus to the island for the current trading period'
  HVDCNode(i_tradePeriod,i_node)                                           'HVDC node for the current trading period'
  ACnode(i_tradePeriod,i_node)                                             'AC nodes for the current trading period'
  ReferenceNode(i_tradePeriod,i_node)                                      'Reference node for the current trading period'
  DCBus(i_tradePeriod,i_bus)                                               'Buses corresponding to HVDC nodes'
  ACBus(i_tradePeriod,i_bus)                                               'Buses corresponding to AC nodes'
  Branch(i_tradePeriod,i_branch)                                           'Branches defined for the current trading period'
  BranchBusDefn(i_tradePeriod,i_branch,i_fromBus,i_toBus)                  'Branch bus connectivity for the current trading period'
  BranchBusConnect(i_tradePeriod,i_branch,i_bus)                           'Indication if a branch is connected to a bus for the current trading period'
  ACBranchSendingBus(i_tradePeriod,i_branch,i_bus,i_flowDirection)         'Sending (From) bus of AC branch in forward and backward direction'
  ACBranchReceivingBus(i_tradePeriod,i_branch,i_bus,i_flowDirection)       'Receiving (To) bus of AC branch in forward and backward direction'
  HVDClinkSendingBus(i_tradePeriod,i_branch,i_bus)                         'Sending (From) bus of HVDC link'
  HVDClinkReceivingBus(i_tradePeriod,i_branch,i_toBus)                     'Receiving (To) bus of HVDC link'
  HVDClinkBus(i_tradePeriod,i_branch,i_bus)                                'Sending or Receiving bus of HVDC link'
  HVDClink(i_tradePeriod,i_branch)                                         'HVDC links (branches) defined for the current trading period'
  HVDCPoles(i_tradePeriod,i_branch)                                        'DC transmission between Benmore and Hayward'
  HVDCHalfPoles(i_tradePeriod,i_branch)                                    'Connection DC Pole 1 between AC and DC systems at Benmore and Haywards'
  HVDCPoleDirection(i_tradePeriod,i_branch,i_flowDirection)                'Direction defintion for HVDC poles S->N : Forward and N->S : Southward'
  ACBranch(i_tradePeriod,i_branch)                                         'AC branches defined for the current trading period'
  ClosedBranch(i_tradePeriod,i_branch)                                     'Set of branches that are closed'
  OpenBranch(i_tradePeriod,i_branch)                                       'Set of branches that are open'
  ValidLossSegment(i_tradePeriod,i_branch,i_lossSegment)                   'Valid loss segments for a branch'
  LossBranch(i_tradePeriod,i_branch)                                       'Subset of branches that have non-zero loss factors'
* RDN - Mapping set of branches to HVDC pole
  HVDCPoleBranchMap(pole,i_branch)                                         'Mapping of HVDC  branch to pole number'
* Risk/Reserve
  RiskGenerator(i_tradePeriod,i_offer)                                     'Set of generators that can set the risk in the current trading period'
  islandRiskGenerator(i_tradePeriod,i_island,i_offer)                      'Mapping of risk generator to island in the current trading period'
  HVDCrisk(i_riskClass)                                                    'Subset containing DCCE and DCECE risks'
  GenRisk(i_riskClass)                                                     'Subset containing generator risks'
  ManualRisk(i_riskClass)                                                  'Subset containting manual risks'
* RDN - Allow for the HVDC secondary risks
  HVDCSecRisk(i_riskClass)                                                 'Subset containing secondary risk of the HVDC for CE and ECE events'
  PLSRReserveType(i_reserveType)                                           'PLSR reserve type'
  ILReserveType(i_reserveType)                                             'IL reserve type'
  IslandOffer(i_tradePeriod,i_island,i_offer)                              'Mapping of reserve offer to island for the current trading period'
  IslandBid(i_tradePeriod,i_island,i_bid)                                  'Mapping of purchase bid ILR to island for the current trading period'
* RDN - Definition of CE and ECE events to support different CE and ECE CVPs
  ContingentEvents(i_riskClass)                                            'Subset of Risk Classes containing contigent event risks'
  ExtendedContingentEvent(i_riskClass)                                     'Subset of Risk Classes containing extended contigent event risk'
* Branch constraint
  BranchConstraint(i_tradePeriod,i_branchConstraint)                       'Set of branch constraints defined for the current trading period'
* AC node constraint
  ACnodeConstraint(i_tradePeriod,i_ACnodeConstraint)                       'Set of AC node constraints defined for the current trading period'
* Market node constraint
  MNodeConstraint(i_tradePeriod,i_MNodeConstraint)                         'Set of market node constraints defined for the current trading period'
* Mixed constraint
  Type1MixedConstraint(i_tradePeriod,i_type1MixedConstraint)               'Set of type 1 mixed constraints defined for the current trading period'
  Type2MixedConstraint(i_tradePeriod,i_type2MixedConstraint)               'Set of type 2 mixed constraints defined for the current trading period'
  Type1MixedConstraintCondition(i_tradePeriod,i_type1MixedConstraint)      'Subset of type 1 mixed constraints that have a condition to check for the use of the alternate limit'
* Generic constraint
  GenericConstraint(i_tradePeriod,i_genericConstraint)                     'Generic constraint defined for the current trading period'
  ;

Parameters
* Offers
  RampRateUp(i_tradePeriod,i_offer)                          'The ramping up rate in MW per minute associated with the generation offer (MW/min)'
  RampRateDown(i_tradePeriod,i_offer)                        'The ramping down rate in MW per minute associated with the generation offer (MW/min)'
  GenerationStart(i_tradePeriod,i_offer)                     'The MW generation level associated with the offer at the start of a trading period'
  ReserveGenerationMaximum(i_tradePeriod,i_offer)            'Maximum generation and reserve capability for the current trading period (MW)'
  WindOffer(i_tradePeriod,i_offer)                           'Flag to indicate if offer is from wind generator (1 = Yes)'
* RDN - Primary-secondary offer parameters
  HasSecondaryOffer(i_tradePeriod,i_offer)                   'Flag to indicate if offer has a secondary offer (1 = Yes)'
  HasPrimaryOffer(i_tradePeriod,i_offer)                     'Flag to indicate if offer has a primary offer (1 = Yes)'
* RDN - Frequency keeper band MW
  FKBand(i_tradePeriod,i_offer)                              'Frequency keeper band MW which is set when the risk setter is selected as the frequency keeper'
  GenerationMaximum(i_tradePeriod,i_offer)                   'Maximum generation level associated with the generation offer (MW)'
  GenerationMinimum(i_tradePeriod,i_offer)                   'Minimum generation level associated with the generation offer (MW)'
  GenerationEndUp(i_tradePeriod,i_offer)                     'MW generation level associated with the offer at the end of the trading period assuming ramp rate up'
  GenerationEndDown(i_tradePeriod,i_offer)                   'MW generation level associated with the offer at the end of the trading period assuming ramp rate down'
  RampTimeUp(i_tradePeriod,i_offer)                          'Minimum of the trading period length and time to ramp up to maximum (Minutes)'
  RampTimeDown(i_tradePeriod,i_offer)                        'Minimum of the trading period length and time to ramp down to minimum (Minutes)'
* Energy offer
  GenerationOfferMW(i_tradePeriod,i_offer,i_tradeBlock)      'Generation offer block (MW)'
  GenerationOfferPrice(i_tradePeriod,i_offer,i_tradeBlock)   'Generation offer price ($/MW)'
* Reserve offer
  ReserveOfferProportion(i_tradePeriod,i_offer,i_tradeBlock,i_reserveClass)             'The percentage of the MW block available for PLSR of class FIR or SIR'
  ReserveOfferPrice(i_tradePeriod,i_offer,i_tradeBlock,i_reserveClass,i_reserveType)    'The price of the reserve of the different reserve classes and types ($/MW)'
  ReserveOfferMaximum(i_tradePeriod,i_offer,i_tradeBlock,i_reserveClass,i_reserveType)  'The maximum MW offered reserve for the different reserve classes and types (MW)'
* Demand
  NodeDemand(i_tradePeriod,i_node)                                                      'Nodal demand for the current trading period in MW'
* Bid
  PurchaseBidMW(i_tradePeriod,i_bid,i_tradeBlock)                                       'Purchase bid block in MW'
  PurchaseBidPrice(i_tradePeriod,i_bid,i_tradeBlock)                                    'Purchase bid price in $/MW'
  PurchaseBidILRMW(i_tradePeriod,i_bid,i_tradeBlock,i_reserveClass)                     'Purchase bid ILR block in MW for the different reserve classes'
  PurchaseBidILRPrice(i_tradePeriod,i_bid,i_tradeBlock,i_reserveClass)                  'Purchase bid ILR price in $/MW for the different reserve classes'
* Network
  ACBranchCapacity(i_tradePeriod,i_branch)                   'MW capacity of AC branch for the current trading period'
  ACBranchResistance(i_tradePeriod,i_branch)                 'Resistance of the AC branch for the current trading period in per unit'
  ACBranchSusceptance(i_tradePeriod,i_branch)                'Susceptance (inverse of reactance) of the AC branch for the current trading period in per unit'
  ACBranchFixedLoss(i_tradePeriod,i_branch)                  'Fixed loss of the AC branch for the current trading period in MW'
  ACBranchLossBlocks(i_tradePeriod,i_branch)                 'Number of blocks in the loss curve for the AC branch in the current trading period'
  ACBranchLossMW(i_tradePeriod,i_branch,i_lossSegment)       'MW element of the loss segment curve in MW'
  ACBranchLossFactor(i_tradePeriod,i_branch,i_lossSegment)   'Loss factor element of the loss segment curve'
  ACBranchOpenStatus(i_tradePeriod,i_branch)                 'Flag indicating if the AC branch is open (1 = Open)'
  ACBranchClosedStatus(i_tradePeriod,i_branch)               'Flag indicating if the AC branch is closed (1 = Closed)'

  HVDClinkCapacity(i_tradePeriod,i_branch)                   'MW capacity of the HVDC link for the current trading period'
  HVDClinkResistance(i_tradePeriod,i_branch)                 'Resistance of the HVDC link for the current trading period in Ohms'
  HVDClinkFixedLoss(i_tradePeriod,i_branch)                  'Fixed loss of the HVDC link for the current trading period in MW'
  HVDClinkLossBlocks(i_tradePeriod,i_branch)                 'Number of blocks in the loss curve for the HVDC link in the current trading period'
  HVDCBreakPointMWFlow(i_tradePeriod,i_branch,i_lossSegment) 'Value of power flow on the HVDC at the break point'
  HVDCBreakPointMWLoss(i_tradePeriod,i_branch,i_lossSegment) 'Value of variable losses on the HVDC at the break point'
  HVDClinkOpenStatus(i_tradePeriod,i_branch)                 'Flag indicating if the HVDC link is open (1 = Open)'
  HVDClinkClosedStatus(i_tradePeriod,i_branch)               'Flag indicating if the HVDC link is closed (1 = Closed)'

  LossSegmentMW(i_tradePeriod,i_branch,i_lossSegment)        'MW capacity of each loss segment'
  LossSegmentFactor(i_tradePeriod,i_branch,i_lossSegment)    'Loss factor of each loss segment'

  NodeBusAllocationFactor(i_tradePeriod,i_node,i_bus)        'Allocation factor of market node to bus for the current trade period'
  BusElectricalIsland(i_tradePeriod,i_bus)                   'Bus electrical island status for the current trade period (0 = Dead)'
* RDN - Flag to allow roundpower on the HVDC link
  AllowHVDCRoundpower(i_tradePeriod)                         'Flag to allow roundpower on the HVDC (1 = Yes)'
* Risk/Reserve
  ReserveClassGenerationMaximum(i_tradePeriod,i_offer,i_reserveClass)            'MW used to determine factor to adjust maximum reserve of a reserve class'
  ReserveMaximumFactor(i_tradePeriod,i_offer,i_reserveClass)                     'Factor to adjust the maximum reserve of the different classes for the different offers'
  IslandRiskAdjustmentFactor(i_tradePeriod,i_island,i_reserveClass,i_riskClass)  'Risk adjustment factor for each island, reserve class and risk class'
  FreeReserve(i_tradePeriod,i_island,i_reserveClass,i_riskClass)                 'MW free reserve for each island, reserve class and risk class'
  HVDCPoleRampUp(i_tradePeriod,i_island,i_reserveClass,i_riskClass)              'HVDC pole MW ramp up capability for each island, reserve class and risk class'
* RDN - Index IslandMinimumRisk to cater for CE and ECE minimum risk
* IslandMinimumRisk(i_tradePeriod,i_island,i_reserveClass)                       'Minimum MW risk level for each island for each reserve class'
  IslandMinimumRisk(i_tradePeriod,i_island,i_reserveClass,i_riskClass)           'Minimum MW risk level for each island for each reserve class and risk class'
* RDN - HVDC secondary risk parameters
  HVDCSecRiskEnabled(i_tradePeriod,i_island,i_riskClass)                          'Flag indicating if the HVDC secondary risk is enabled (1 = Yes)'
  HVDCSecRiskSubtractor(i_tradePeriod,i_island)                                   'Ramp up capability on the HVDC pole that is not the secondary risk'
  HVDCSecIslandMinimumRisk(i_tradePeriod,i_island,i_reserveClass,i_riskClass)     'Minimum risk in each island for the HVDC secondary risk'
* Branch constraint
  BranchConstraintFactors(i_tradePeriod,i_branchConstraint,i_branch)              'Branch security constraint factors (sensitivities) for the current trading period'
  BranchConstraintSense(i_tradePeriod,i_branchConstraint)                         'Branch security constraint sense for the current trading period (-1:<=, 0:= 1:>=)'
  BranchConstraintLimit(i_tradePeriod,i_branchConstraint)                         'Branch security constraint limit for the current trading period'
* AC node constraint
  ACnodeConstraintFactors(i_tradePeriod,i_ACnodeConstraint,i_node)                'AC node security constraint factors (sensitivities) for the current trading period'
  ACnodeConstraintSense(i_tradePeriod,i_ACnodeConstraint)                         'AC node security constraint sense for the current trading period (-1:<=, 0:= 1:>=)'
  ACnodeConstraintLimit(i_tradePeriod,i_ACnodeConstraint)                         'AC node security constraint limit for the current trading period'
* Market node constraint
  MNodeEnergyOfferConstraintFactors(i_tradePeriod,i_MNodeConstraint,i_offer)                               'Market node energy offer constraint factors for the current trading period'
  MNodeReserveOfferConstraintFactors(i_tradePeriod,i_MNodeConstraint,i_offer,i_reserveClass,i_reserveType) 'Market node reserve offer constraint factors for the current trading period'
  MNodeEnergyBidConstraintFactors(i_tradePeriod,i_MNodeConstraint,i_bid)                                   'Market node energy bid constraint factors for the current trading period'
  MNodeILReserveBidConstraintFactors(i_tradePeriod,i_MNodeConstraint,i_bid,i_reserveClass)                 'Market node IL reserve bid constraint factors for the current trading period'
  MNodeConstraintSense(i_tradePeriod,i_MNodeConstraint)                                                    'Market node constraint sense for the current trading period'
  MNodeConstraintLimit(i_tradePeriod,i_MNodeConstraint)                                                    'Market node constraint limit for the current trading period'
* Mixed constraint
  useMixedConstraint(i_tradePeriod)                                                                        'Flag indicating use of the mixed constraint formulation (1 = Yes)'
  Type1MixedConstraintSense(i_tradePeriod,i_type1MixedConstraint)                                          'Type 1 mixed constraint sense'
  Type1MixedConstraintLimit1(i_tradePeriod,i_type1MixedConstraint)                                         'Type 1 mixed constraint limit 1'
  Type1MixedConstraintLimit2(i_tradePeriod,i_type1MixedConstraint)                                         'Type 1 mixed constraint alternate limit (limit 2)'
  Type2MixedConstraintSense(i_tradePeriod,i_type2MixedConstraint)                                          'Type 2 mixed constraint sense'
  Type2MixedConstraintLimit(i_tradePeriod,i_type2MixedConstraint)                                          'Type 2 mixed constraint limit'
* Generic constraint
  GenericEnergyOfferConstraintFactors(i_tradePeriod,i_genericConstraint,i_offer)                           'Generic constraint energy offer factors for the current trading period'
  GenericReserveOfferConstraintFactors(i_tradePeriod,i_genericConstraint,i_offer,i_reserveClass,i_reserveType) 'Generic constraint reserve offer factors for the current trading period'
  GenericEnergyBidConstraintFactors(i_tradePeriod,i_genericConstraint,i_bid)                               'Generic constraint energy bid factors for the current trading period'
  GenericILReserveBidConstraintFactors(i_tradePeriod,i_genericConstraint,i_bid,i_reserveClass)             'Generic constraint IL reserve bid factors for the current trading period'
  GenericBranchConstraintFactors(i_tradePeriod,i_genericConstraint,i_branch)                               'Generic constraint branch factors for the current trading period'
  GenericConstraintSense(i_tradePeriod,i_genericConstraint)                                                'Generic constraint sense for the current trading period'
  GenericConstraintLimit(i_tradePeriod,i_genericConstraint)                                                'Generic constraint limit for the current trading period'
* Violation penalties
  DeficitReservePenalty(i_reserveClass)                      '6s and 60s reserve deficit violation penalty'
* RDN - Different CVPs defined for CE and ECE
  DeficitReservePenalty_CE(i_reserveClass)                   '6s and 60s CE reserve deficit violation penalty'
  DeficitReservePenalty_ECE(i_reserveClass)                  '6s and 60s ECE reserve deficit violation penalty'
* Post-processing
  useBranchFlowMIP(i_tradePeriod)                            'Flag to indicate if integer constraints are needed in the branch flow model: 1 = Yes'
  useMixedConstraintMIP(i_tradePeriod)                       'Flag to indicate if integer constraints are needed in the mixed constraint formulation: 1 = Yes'
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
* RDN - Separate flag for the CE and ECE CVP
  DiffCeECeCVP                                     'Flag to indicate if the separate CE and ECE CVP is applied'
  usePrimSecGenRiskModel                           'Flag to use the revised generator risk model for generators with primary and secondary offers'
  useDSBFDemandBidModel                            'Flag to use the demand model defined under demand-side bidding and forecasting (DSBF)'
  ;


*===================================================================================
* Section 3: Define model variables and constraints
*===================================================================================

* Model formulation originally based on the SPD model formulation version 4.3 (15 Feb 2008) and amended as indicated

Variables
  NETBENEFIT                                                                       'Defined as the difference between the consumer surplus and producer costs adjusted for penalty costs'
* Reserves
  ISLANDRISK(i_tradePeriod,i_island,i_reserveClass,i_riskClass)                    'Island MW risk for the different reserve and risk classes'
  HVDCREC(i_tradePeriod,i_island)                                                  'Total net pre-contingent HVDC MW flow received at each island'
  RISKOFFSET(i_tradePeriod,i_island,i_reserveClass,i_riskClass)                    'MW offset applied to the raw risk to account for HVDC pole rampup, AUFLS, free reserve and non-compliant generation'
* Network
  ACnodeNETINJECTION(i_tradePeriod,i_bus)                                          'MW injection at buses corresponding to AC nodes'
  ACBRANCHFLOW(i_tradePeriod,i_branch)                                             'MW flow on undirected AC branch'
  ACnodeANGLE(i_tradePeriod,i_bus)                                                 'Bus voltage angle'
* Mixed constraint variables
  MIXEDCONSTRAINTVARIABLE(i_tradePeriod,i_type1MixedConstraint)                    'Mixed constraint variable'
* RDN - Change to demand bids
* Demand bids were only positive but can be both positive and negative from v6.0 of SPD formulation (with DSBF)
* This change will be managed with the update of the lower bound of the free variable in vSPDSolve.gms to allow
* backward compatibility
* Note the formulation now refers to this as Demand. So Demand (in SPD formulation) = Purchase (in vSPD code)
  PURCHASE(i_tradePeriod,i_bid)                                                    'Total MW purchase scheduled'
  PURCHASEBLOCK(i_tradePeriod,i_bid,i_tradeBlock)                                  'MW purchase scheduled from the individual trade blocks of a bid'
* RDN - Change to demand bids - End
  ;

Positive variables
* Generation
  GENERATION(i_tradePeriod,i_offer)                                                'Total MW generation scheduled from an offer'
  GENERATIONBLOCK(i_tradePeriod,i_offer,i_tradeBlock)                              'MW generation scheduled from the individual trade blocks of an offer'
* Purchase
* PURCHASE(i_tradePeriod,i_bid)                                                    'Total MW purchase scheduled'
* PURCHASEBLOCK(i_tradePeriod,i_bid,i_tradeBlock)                                  'MW purchase scheduled from the individual trade blocks of a bid'
  PURCHASEILR(i_tradePeriod,i_bid,i_reserveClass)                                  'Total MW ILR provided by purchase bid for the different reserve classes'
  PURCHASEILRBLOCK(i_tradePeriod,i_bid,i_tradeBlock,i_reserveClass)                'MW ILR provided by purchase bid for individual trade blocks for the different reserve classes'
* Reserve
  RESERVE(i_tradePeriod,i_offer,i_reserveClass,i_reserveType)                      'MW Reserve scheduled from an offer'
  RESERVEBLOCK(i_tradePeriod,i_offer,i_tradeBlock,i_reserveClass,i_reserveType)    'MW Reserve scheduled from the individual trade blocks of an offer'
  MAXISLANDRISK(i_tradePeriod,i_island,i_reserveClass)                             'Maximum MW island risk for the different reserve classes'
* Network
  HVDCLINKFLOW(i_tradePeriod,i_branch)                                             'MW flow at the sending end scheduled for the HVDC link'
  HVDCLINKLOSSES(i_tradePeriod,i_branch)                                           'MW losses on the HVDC link'
  LAMBDA(i_tradePeriod,i_branch,i_lossSegment)                                     'Non-negative weight applied to the breakpoint of the HVDC link'
  ACBRANCHFLOWDIRECTED(i_tradePeriod,i_branch,i_flowDirection)                     'MW flow on the directed branch'
  ACBRANCHLOSSESDIRECTED(i_tradePeriod,i_branch,i_flowDirection)                   'MW losses on the directed branch'
  ACBRANCHFLOWBLOCKDIRECTED(i_tradePeriod,i_branch,i_lossSegment,i_flowDirection)  'MW flow on the different blocks of the loss curve'
  ACBRANCHLOSSESBLOCKDIRECTED(i_tradePeriod,i_branch,i_lossSegment,i_flowDirection)'MW losses on the different blocks of the loss curve'
* Violations
  TOTALPENALTYCOST                                                                 'Total violation costs'
  DEFICITBUSGENERATION(i_tradePeriod,i_bus)                                        'Deficit generation at a bus in MW'
  SURPLUSBUSGENERATION(i_tradePeriod,i_bus)                                        'Surplus generation at a bus in MW'
  DEFICITRESERVE(i_tradePeriod,i_island,i_reserveClass)                            'Deficit reserve generation in each island for each reserve class in MW'
  DEFICITBRANCHSECURITYCONSTRAINT(i_tradePeriod,i_branchConstraint)                'Deficit branch security constraint in MW'
  SURPLUSBRANCHSECURITYCONSTRAINT(i_tradePeriod,i_branchConstraint)                'Surplus branch security constraint in MW'
  DEFICITRAMPRATE(i_tradePeriod,i_offer)                                           'Deficit ramp rate in MW'
  SURPLUSRAMPRATE(i_tradePeriod,i_offer)                                           'Surplus ramp rate in MW'
  DEFICITACnodeCONSTRAINT(i_tradePeriod,i_ACnodeConstraint)                        'Deficit in AC node constraint in MW'
  SURPLUSACnodeCONSTRAINT(i_tradePeriod,i_ACnodeConstraint)                        'Surplus in AC node constraint in MW'
  DEFICITBRANCHFLOW(i_tradePeriod,i_branch)                                        'Deficit branch flow in MW'
  SURPLUSBRANCHFLOW(i_tradePeriod,i_branch)                                        'Surplus branch flow in MW'
  DEFICITMNODECONSTRAINT(i_tradePeriod,i_MNodeConstraint)                          'Deficit market node constraint in MW'
  SURPLUSMNODECONSTRAINT(i_tradePeriod,i_MNodeConstraint)                          'Surplus market node constraint in MW'
  DEFICITTYPE1MIXEDCONSTRAINT(i_tradePeriod,i_type1MixedConstraint)                'Type 1 deficit mixed constraint in MW'
  SURPLUSTYPE1MIXEDCONSTRAINT(i_tradePeriod,i_type1MixedConstraint)                'Type 1 surplus mixed constraint in MW'
  SURPLUSGENERICCONSTRAINT(i_tradePeriod,i_genericConstraint)                      'Surplus generic constraint in MW'
  DEFICITGENERICCONSTRAINT(i_tradePeriod,i_genericConstraint)                      'Deficit generic constraint in MW'
* RDN - Seperate CE and ECE violation variables to support different CVPs for CE and ECE
  DEFICITRESERVE_CE(i_tradePeriod,i_island,i_reserveClass)                         'Deficit CE reserve generation in each island for each reserve class in MW'
  DEFICITRESERVE_ECE(i_tradePeriod,i_island,i_reserveClass)                        'Deficit ECE reserve generation in each island for each reserve class in MW'
  ;

Binary variables
  MIXEDCONSTRAINTLIMIT2SELECT(i_tradePeriod,i_type1MixedConstraint)                'Binary decision variable used to detect if limit 2 should be selected for mixed constraints'
  ;

SOS1 Variables
  ACBRANCHFLOWDIRECTED_INTEGER(i_tradePeriod,i_branch,i_flowDirection)             'Integer variables used to select branch flow direction in the event of circular branch flows (3.8.1)'
  HVDCLINKFLOWDIRECTION_INTEGER(i_tradePeriod,i_flowDirection)                     'Integer variables used to select the HVDC branch flow direction on in the event of S->N (forward) and N->S (reverse) flows (3.8.2)'
* RDN - Integer varaible to prevent intra-pole circulating branch flows
  HVDCPOLEFLOW_INTEGER(i_tradePeriod,pole,i_flowDirection)                         'Integer variables used to select the HVDC pole flow direction on in the event of circulating branch flows within a pole'
  ;

SOS2 Variables
  LAMBDAINTEGER(i_tradePeriod,i_branch,i_lossSegment)                              'Integer variables used to enforce the piecewise linear loss approxiamtion on the HVDC links'
  ;

Equations
  ObjectiveFunction                                                                'Objective function of the dispatch model (4.1.1.1)'
* Offer and purchase definitions
  GenerationOfferDefintion(i_tradePeriod,i_offer)                                  'Definition of generation provided by an offer (3.1.1.2)'
  GenerationRampUp(i_tradePeriod,i_offer)                                          'Maximum movement of the generator upwards due to up ramp rate (3.7.1.1)'
  GenerationRampDown(i_tradePeriod,i_offer)                                        'Maximum movement of the generator downwards due to down ramp rate (3.7.1.2)'
* RDN - Primary-secondary ramp constraints
  GenerationRampUp_PS(i_tradePeriod,i_offer)                                       'Maximum movement of the primary-secondary offers upwards due to up ramp rate (3.7.1.1)'
  GenerationRampDown_PS(i_tradePeriod,i_offer)                                     'Maximum movement of the primary-secondary offers downwards due to down ramp rate (3.7.1.2)'
* RDN - Change to demand bids
* PurchaseBidDefintion(i_tradePeriod,i_bid)                                        'Definition of purchase provided by a bid (3.1.1.4)'
  PurchaseBidDefintion(i_tradePeriod,i_bid)                                        'Definition of purchase provided by a bid (3.1.1.5)'
* RDN - Change to demand bids - End
* Network
  HVDCLinkMaximumFlow(i_tradePeriod,i_branch)                                      'Maximum flow on each HVDC link (3.2.1.1)'
  HVDCLinkLossDefinition(i_tradePeriod,i_branch)                                   'Definition of losses on the HVDC link (3.2.1.2)'
  HVDCLinkFlowDefinition(i_tradePeriod,i_branch)                                   'Definition of MW flow on the HVDC link (3.2.1.3)'
  HVDCLinkFlowIntegerDefinition1(i_tradePeriod)                                    'Definition of the integer HVDC link flow variable (3.8.2a)'
  HVDCLinkFlowIntegerDefinition2(i_tradePeriod,i_flowDirection)                    'Definition of the integer HVDC link flow variable (3.8.2b)'
* RDN - Additional constraints for the intra-pole circulating branch flows
  HVDCLinkFlowIntegerDefinition3(i_tradePeriod,pole)                               'Definition of the HVDC pole integer varaible to prevent intra-pole circulating branch flows (3.8.2c)'
  HVDCLinkFlowIntegerDefinition4(i_tradePeriod,pole,i_flowDirection)               'Definition of the HVDC pole integer varaible to prevent intra-pole circulating branch flows (3.8.2d)'

  LambdaDefinition(i_tradePeriod,i_branch)                                         'Definition of weighting factor (3.2.1.4)'
  LambdaIntegerDefinition1(i_tradePeriod,i_branch)                                 'Definition of weighting factor when branch integer constraints are needed (3.8.3a)'
  LambdaIntegerDefinition2(i_tradePeriod,i_branch,i_lossSegment)                   'Definition of weighting factor when branch integer constraints are needed (3.8.3b)'

  DCNodeNetInjection(i_tradePeriod,i_bus)                                          'Definition of the net injection at buses corresponding to HVDC nodes (3.2.1.6)'
  ACnodeNetInjectionDefinition1(i_tradePeriod,i_bus)                               '1st definition of the net injection at buses corresponding to AC nodes (3.3.1.1)'
  ACnodeNetInjectionDefinition2(i_tradePeriod,i_bus)                               '2nd definition of the net injection at buses corresponding to AC nodes (3.3.1.2)'
  ACBranchMaximumFlow(i_tradePeriod,i_branch,i_flowDirection)                      'Maximum flow on the AC branch (3.3.1.3)'
  ACBranchFlowDefinition(i_tradePeriod,i_branch)                                   'Relationship between directed and undirected branch flow variables (3.3.1.4)'
  LinearLoadFlow(i_tradePeriod,i_branch)                                           'Equation that describes the linear load flow (3.3.1.5)'
  ACBranchBlockLimit(i_tradePeriod,i_branch,i_lossSegment,i_flowDirection)         'Limit on each AC branch flow block (3.3.1.6)'
  ACDirectedBranchFlowDefinition(i_tradePeriod,i_branch,i_flowDirection)           'Composition of the directed branch flow from the block branch flow (3.3.1.7)'
  ACBranchLossCalculation(i_tradePeriod,i_branch,i_lossSegment,i_flowDirection)    'Calculation of the losses in each loss segment (3.3.1.8)'
  ACDirectedBranchLossDefinition(i_tradePeriod,i_branch,i_flowDirection)           'Composition of the directed branch losses from the block branch losses (3.3.1.9)'
  ACDirectedBranchFlowIntegerDefinition1(i_tradePeriod,i_branch)                   'Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1a)'
  ACDirectedBranchFlowIntegerDefinition2(i_tradePeriod,i_branch,i_flowDirection)   'Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1b)'
* Risk and Reserve
  HVDCIslandRiskCalculation(i_tradePeriod,i_island,i_reserveClass,i_riskClass)                     'Calculation of the island risk for a DCCE and DCECE (3.4.1.1)'
  HVDCRecCalculation(i_tradePeriod,i_island)                                                       'Calculation of the net received HVDC MW flow into an island (3.4.1.5)'
  GenIslandRiskCalculation(i_tradePeriod,i_island,i_offer,i_reserveClass,i_riskClass)              'Calculation of the island risk for risk setting generators (3.4.1.6)'
  ManualIslandRiskCalculation(i_tradePeriod,i_island,i_reserveClass,i_riskClass)                   'Calculation of the island risk based on manual specifications (3.4.1.7)'
  PLSRReserveProportionMaximum(i_tradePeriod,i_offer,i_tradeBlock,i_reserveClass,i_reserveType)    'Maximum PLSR as a proportion of the block MW (3.4.2.1)'
  ReserveOfferDefinition(i_tradePeriod,i_offer,i_reserveClass,i_reserveType)                       'Definition of the reserve offers of different classes and types (3.4.2.3a)'
  ReserveDefinitionPurchaseBid(i_tradePeriod,i_bid,i_reserveClass)                                 'Definition of the ILR reserve provided by purchase bids (3.4.2.3b)'
  EnergyAndReserveMaximum(i_tradePeriod,i_offer,i_reserveClass)                                    'Definition of maximum energy and reserves from each generator (3.4.2.4)'
  PurchaseBidReserveMaximum(i_tradePeriod,i_bid,i_reserveClass)                                    'Maximum ILR provided by purchase bids (3.4.2.5)'
  MaximumIslandRiskDefinition(i_tradePeriod,i_island,i_reserveClass,i_riskClass)                   'Definition of the maximum risk in each island (3.4.3.1)'
  SupplyDemandReserveRequirement(i_tradePeriod,i_island,i_reserveClass)                            'Matching of reserve supply and demand (3.4.3.2)'
* RDN - Risk calculation for generators with more than one offer - Primary and secondary offers
  GenIslandRiskCalculation_NonPS(i_tradePeriod,i_island,i_offer,i_reserveClass,i_riskClass)        'Calculation of the island risk for risk setting generators with only one offer (3.4.1.6)'
  GenIslandRiskCalculation_PS(i_tradePeriod,i_island,i_offer,i_reserveClass,i_riskClass)           'Calculation of the island risk for risk setting generators with more than one offer (3.4.1.6)'
* RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
* RiskOffSetCalculationApproximation(i_tradePeriod,i_island,i_reserveClass,i_riskClass)            'Approximate calculation of the risk offset variable.  This will be used when the i_useMixedConstraint flag is false'
  RiskOffsetCalculation_DCCE(i_tradePeriod,i_island,i_reserveClass,i_riskClass)                    'Calculation of the risk offset variable for the DCCE risk class.  This will be used when the i_useMixedConstraint flag is false (3.4.1.2)'
  RiskOffsetCalculation_DCECE(i_tradePeriod,i_island,i_reserveClass,i_riskClass)                   'Calculation of the risk offset variable for the DCECE risk class.  This will be used when the i_useMixedConstraint flag is false (3.4.1.4)'
  RiskOffsetCalculation(i_tradePeriod,i_type1MixedConstraint,i_island,i_reserveClass,i_riskClass)  'Risk offset definition. This will be used when the i_useMixedConstraint flag is true (3.4.1.5 - v4.4)'
* RDN - Need to seperate the maximum island risk definition constraint to support the different CVPs defined for CE and ECE
  MaximumIslandRiskDefinition_CE(i_tradePeriod,i_island,i_reserveClass,i_riskClass)                'Definition of the maximum CE risk in each island (3.4.3.1a)'
  MaximumIslandRiskDefinition_ECE(i_tradePeriod,i_island,i_reserveClass,i_riskClass)               'Definition of the maximum ECE risk in each island (3.4.3.1b)'
* RDN - HVDC secondary risk calculation
  HVDCIslandSecRiskCalculation_GEN(i_tradePeriod,i_island,i_offer,i_reserveClass,i_riskClass)      'Calculation of the island risk for an HVDC secondary risk to an AC risk (3.4.1.8)'
  HVDCIslandSecRiskCalculation_Manual(i_tradePeriod,i_island,i_reserveClass,i_riskClass)           'Calculation of the island risk for an HVDC secondary risk to a manual risk (3.4.1.9)'
* RDN - HVDC secondary risk calculation for generators with more than one offer - Primary and secondary offers
  HVDCIslandSecRiskCalculation_GEN_NonPS(i_tradePeriod,i_island,i_offer,i_reserveClass,i_riskClass)
  HVDCIslandSecRiskCalculation_GEN_PS(i_tradePeriod,i_island,i_offer,i_reserveClass,i_riskClass)
* Branch security constraints
  BranchSecurityConstraintLE(i_tradePeriod,i_branchConstraint)                           'Branch security constraint with LE sense (3.5.1.5a)'
  BranchSecurityConstraintGE(i_tradePeriod,i_branchConstraint)                           'Branch security constraint with GE sense (3.5.1.5b)'
  BranchSecurityConstraintEQ(i_tradePeriod,i_branchConstraint)                           'Branch security constraint with EQ sense (3.5.1.5c)'
* AC node security constraints
  ACnodeSecurityConstraintLE(i_tradePeriod,i_ACnodeConstraint)                           'AC node security constraint with LE sense (3.5.1.6a)'
  ACnodeSecurityConstraintGE(i_tradePeriod,i_ACnodeConstraint)                           'AC node security constraint with GE sense (3.5.1.6b)'
  ACnodeSecurityConstraintEQ(i_tradePeriod,i_ACnodeConstraint)                           'AC node security constraint with EQ sense (3.5.1.6c)'
* Market node security constraints
  MNodeSecurityConstraintLE(i_tradePeriod,i_MNodeConstraint)                             'Market node security constraint with LE sense (3.5.1.7a)'
  MNodeSecurityConstraintGE(i_tradePeriod,i_MNodeConstraint)                             'Market node security constraint with GE sense (3.5.1.7b)'
  MNodeSecurityConstraintEQ(i_tradePeriod,i_MNodeConstraint)                             'Market node security constraint with EQ sense (3.5.1.7c)'
* Mixed constraints
  Type1MixedConstraintLE(i_tradePeriod,i_type1MixedConstraint)                           'Type 1 mixed constraint definition with LE sense (3.6.1.1a)'
  Type1MixedConstraintGE(i_tradePeriod,i_type1MixedConstraint)                           'Type 1 mixed constraint definition with GE sense (3.6.1.1b)'
  Type1MixedConstraintEQ(i_tradePeriod,i_type1MixedConstraint)                           'Type 1 mixed constraint definition with EQ sense (3.6.1.1c)'
  Type2MixedConstraintLE(i_tradePeriod,i_type2MixedConstraint)                           'Type 2 mixed constraint definition with LE sense (3.6.1.2a)'
  Type2MixedConstraintGE(i_tradePeriod,i_type2MixedConstraint)                           'Type 2 mixed constraint definition with GE sense (3.6.1.2b)'
  Type2MixedConstraintEQ(i_tradePeriod,i_type2MixedConstraint)                           'Type 2 mixed constraint definition with EQ sense (3.6.1.2c)'
  Type1MixedConstraintLE_MIP(i_tradePeriod,i_type1MixedConstraint)                       'Integer equivalent of type 1 mixed constraint definition with LE sense (3.6.1.1a_MIP)'
  Type1MixedConstraintGE_MIP(i_tradePeriod,i_type1MixedConstraint)                       'Integer equivalent of type 1 mixed constraint definition with GE sense (3.6.1.1b_MIP)'
  Type1MixedConstraintEQ_MIP(i_tradePeriod,i_type1MixedConstraint)                       'Integer equivalent of type 1 mixed constraint definition with EQ sense (3.6.1.1c_MIP)'
  Type1MixedConstraintMIP(i_tradePeriod,i_type1MixedConstraint,i_branch)                 'Type 1 mixed constraint definition of alternate limit selection (integer)'
* Generic constraints
  GenericSecurityConstraintLE(i_tradePeriod,i_genericConstraint)                         'Generic security constraint with LE sense'
  GenericSecurityConstraintGE(i_tradePeriod,i_genericConstraint)                         'Generic security constraint with GE sense'
  GenericSecurityConstraintEQ(i_tradePeriod,i_genericConstraint)                         'Generic security constraint with EQ sense'
* Violation cost
  TotalViolationCostDefinition                                                           'Defined as the sum of the individual violation costs'
  ;


* Objective function of the dispatch model (4.1.1.1)
ObjectiveFunction..
NETBENEFIT =e=
  sum(ValidPurchaseBidBlock, PURCHASEBLOCK(ValidPurchaseBidBlock) * PurchaseBidPrice(ValidPurchaseBidBlock))
- sum(validGenerationOfferBlock, GENERATIONBLOCK(validGenerationOfferBlock) * GenerationOfferPrice(validGenerationOfferBlock))
- sum(validReserveOfferBlock, RESERVEBLOCK(validReserveOfferBlock) * ReserveOfferPrice(validReserveOfferBlock))
- sum(ValidPurchaseBidILRBlock, PURCHASEILRBLOCK(ValidPurchaseBidILRBlock))
- TOTALPENALTYCOST
  ;

* Defined as the sum of the individual violation costs
* RDN - Bug fix - used surplusBranchGroupConstraintPenalty rather than surplusBranchFlowPenalty
TotalViolationCostDefinition..
TOTALPENALTYCOST =e=
  sum(Bus, deficitBusGenerationPenalty * DEFICITBUSGENERATION(Bus))
+ sum(Bus, surplusBusGenerationPenalty * SURPLUSBUSGENERATION(Bus))
+ sum(Branch, surplusBranchFlowPenalty * SURPLUSBRANCHFLOW(Branch))
+ sum(Offer, (DeficitRampRatePenalty * DEFICITRAMPRATE(Offer)) + (SurplusRampRatePenalty * SURPLUSRAMPRATE(Offer)))
+ sum(ACnodeConstraint, DeficitACnodeConstraintPenalty * DEFICITACnodeCONSTRAINT(ACnodeConstraint))
+ sum(ACnodeConstraint, SurplusACnodeConstraintPenalty * SURPLUSACnodeCONSTRAINT(ACnodeConstraint))
+ sum(BranchConstraint, surplusBranchGroupConstraintPenalty * SURPLUSBRANCHSECURITYCONSTRAINT(BranchConstraint))
+ sum(BranchConstraint, deficitBranchGroupConstraintPenalty * DEFICITBRANCHSECURITYCONSTRAINT(BranchConstraint))
+ sum(MNodeConstraint, DeficitMnodeConstraintPenalty * DEFICITMNODECONSTRAINT(MNodeConstraint))
+ sum(MNodeConstraint, SurplusMnodeConstraintPenalty * SURPLUSMNODECONSTRAINT(MNodeConstraint))
+ sum(Type1MixedConstraint, Type1DeficitMixedConstraintPenalty * DEFICITTYPE1MIXEDCONSTRAINT(Type1MixedConstraint))
+ sum(Type1MixedConstraint, Type1SurplusMixedConstraintPenalty * SURPLUSTYPE1MIXEDCONSTRAINT(Type1MixedConstraint))
+ sum(GenericConstraint, DeficitGenericConstraintPenalty * DEFICITGENERICCONSTRAINT(GenericConstraint))
+ sum(GenericConstraint, SurplusGenericConstraintPenalty * SURPLUSGENERICCONSTRAINT(GenericConstraint))
* RDN - Separate CE and ECE reserve deficity
+ sum((currentTradePeriod,i_island,i_reserveClass) $ (not DiffCeECeCVP), DeficitReservePenalty(i_reserveClass) * DEFICITRESERVE(currentTradePeriod,i_island,i_reserveClass))
+ sum((currentTradePeriod,i_island,i_reserveClass) $ DiffCeECeCVP, DeficitReservePenalty_CE(i_reserveClass) * DEFICITRESERVE_CE(currentTradePeriod,i_island,i_reserveClass))
+ sum((currentTradePeriod,i_island,i_reserveClass) $ DiffCeECeCVP, DeficitReservePenalty_ECE(i_reserveClass) * DEFICITRESERVE_ECE(currentTradePeriod,i_island,i_reserveClass))
  ;

* Definition of generation provided by an offer (3.1.1.2)
GenerationOfferDefintion(Offer)..
GENERATION(Offer) =e=
sum(validGenerationOfferBlock(Offer,i_tradeBlock), GENERATIONBLOCK(Offer,i_tradeBlock))
  ;

* RDN - Change to demand bid
* Change constraint numbering. 3.1.1.5 in the SPD formulation v6.0
* Definition of purchase provided by a bid (3.1.1.5)
* RDN - Change to demand bid - End
PurchaseBidDefintion(Bid)..
PURCHASE(Bid) =e=
sum(ValidPurchaseBidBlock(Bid,i_tradeBlock), PURCHASEBLOCK(Bid,i_tradeBlock))
  ;

* Maximum flow on each HVDC link (3.2.1.1)
HVDCLinkMaximumFlow(HVDCLink) $ (HVDCLinkClosedStatus(HVDCLink) and i_useHVDCBranchLimits)..
HVDCLINKFLOW(HVDCLink) =l=
HVDCLinkCapacity(HVDCLink)
  ;

* Definition of losses on the HVDC link (3.2.1.2)
HVDCLinkLossDefinition(HVDCLink)..
HVDCLINKLOSSES(HVDCLink) =e=
sum(ValidLossSegment(HVDCLink,i_lossSegment), HVDCBreakPointMWLoss(HVDCLink,i_lossSegment)*LAMBDA(HVDCLink,i_lossSegment))
  ;

* Definition of MW flow on the HVDC link (3.2.1.3)
HVDCLinkFlowDefinition(HVDCLink)..
HVDCLINKFLOW(HVDCLink) =e=
sum(ValidLossSegment(HVDCLink,i_lossSegment), HVDCBreakPointMWFlow(HVDCLink,i_lossSegment)*LAMBDA(HVDCLink,i_lossSegment))
  ;

* Definition of the integer HVDC link flow variable (3.8.2a)
* RDN - Update constraint to exlcude if roundpower is allowed
* HVDCLinkFlowIntegerDefinition1(currentTradePeriod) $ (UseBranchFlowMIP(currentTradePeriod) and i_resolveCircularBranchFlows)..
HVDCLinkFlowIntegerDefinition1(currentTradePeriod) $ (UseBranchFlowMIP(currentTradePeriod) and i_resolveCircularBranchFlows and (1-AllowHVDCRoundpower(currentTradePeriod)))..
sum(i_flowDirection, HVDCLINKFLOWDIRECTION_INTEGER(currentTradePeriod,i_flowDirection)) =e=
sum(HVDCPoleDirection(HVDCLink(currentTradePeriod,i_branch),i_flowDirection), HVDCLINKFLOW(HVDCLink))
  ;

* Definition of the integer HVDC link flow variable (3.8.2b)
* RDN - Update constraint to exlcude if roundpower is allowed
* HVDCLinkFlowIntegerDefinition2(currentTradePeriod,i_flowDirection) $ (UseBranchFlowMIP(currentTradePeriod) and i_resolveCircularBranchFlows)..
HVDCLinkFlowIntegerDefinition2(currentTradePeriod,i_flowDirection) $ (UseBranchFlowMIP(currentTradePeriod) and i_resolveCircularBranchFlows and (1-AllowHVDCRoundpower(currentTradePeriod)))..
HVDCLINKFLOWDIRECTION_INTEGER(currentTradePeriod,i_flowDirection) =e=
sum(HVDCPoleDirection(HVDCLink(currentTradePeriod,i_branch),i_flowDirection), HVDCLINKFLOW(HVDCLink))
  ;

* RDN - Definition of the integer HVDC pole flow variable for intra-pole circulating branch flows e (3.8.2c)
HVDCLinkFlowIntegerDefinition3(currentTradePeriod,pole) $ (UseBranchFlowMIP(currentTradePeriod) and i_resolveCircularBranchFlows)..
sum(i_branch $ (HVDCPoles(currentTradePeriod,i_branch) and HVDCPoleBranchMap(pole,i_branch)), HVDCLINKFLOW(currentTradePeriod,i_branch)) =e=
sum(i_flowDirection, HVDCPOLEFLOW_INTEGER(currentTradePeriod,pole,i_flowDirection))
  ;

* RDN - Definition of the integer HVDC pole flow variable for intra-pole circulating branch flows e (3.8.2d)
HVDCLinkFlowIntegerDefinition4(currentTradePeriod,pole,i_flowDirection) $ (UseBranchFlowMIP(currentTradePeriod) and i_resolveCircularBranchFlows)..
sum(HVDCPoleDirection(HVDCPoles(currentTradePeriod,i_branch),i_flowDirection) $ HVDCPoleBranchMap(pole,i_branch), HVDCLINKFLOW(HVDCPoles)) =e=
HVDCPOLEFLOW_INTEGER(currentTradePeriod,pole,i_flowDirection)
  ;

* Definition of weighting factor (3.2.1.4)
LambdaDefinition(HVDCLink)..
sum(ValidLossSegment(HVDCLink,i_lossSegment), LAMBDA(HVDCLink,i_lossSegment)) =e=
1  ;

* Definition of weighting factor when branch integer constraints are needed (3.8.3a)
LambdaIntegerDefinition1(HVDCLink(currentTradePeriod,i_branch)) $ (UseBranchFlowMIP(currentTradePeriod) and i_resolveHVDCNonPhysicalLosses)..
sum(ValidLossSegment(HVDCLink,i_lossSegment), LAMBDAINTEGER(HVDCLink,i_lossSegment)) =e=
1  ;

* Definition of weighting factor when branch integer constraints are needed (3.8.3b)
LambdaIntegerDefinition2(ValidLossSegment(HVDCLink(currentTradePeriod,i_branch),i_lossSegment)) $ (UseBranchFlowMIP(currentTradePeriod) and i_resolveHVDCNonPhysicalLosses)..
LAMBDAINTEGER(HVDCLink,i_lossSegment) =e=
LAMBDA(HVDCLink,i_lossSegment)
  ;

* Definition of the net injection at the HVDC nodes (3.2.1.6)
DCNodeNetInjection(DCBus(currentTradePeriod,i_bus))..
0 =e=
DEFICITBUSGENERATION(currentTradePeriod,i_bus) - SURPLUSBUSGENERATION(currentTradePeriod,i_bus)
- sum(HVDCLinkSendingBus(HVDCLink(currentTradePeriod,i_branch),i_bus) $ ClosedBranch(HVDCLink), HVDCLINKFLOW(HVDCLink))
+ sum(HVDCLinkReceivingBus(HVDCLink(currentTradePeriod,i_branch),i_bus) $ ClosedBranch(HVDCLink), HVDCLINKFLOW(HVDCLink) - HVDCLINKLOSSES(HVDCLink))
- sum(HVDCLinkBus(HVDCLink(currentTradePeriod,i_branch),i_bus) $ ClosedBranch(HVDCLink), 0.5 * HVDCLinkFixedLoss(HVDCLink))
  ;

* 1st definition of the net injection at buses corresponding to AC nodes (3.3.1.1)
ACnodeNetInjectionDefinition1(ACBus(currentTradePeriod,i_bus))..
ACnodeNETINJECTION(currentTradePeriod,i_bus) =e=
  sum(ACBranchSendingBus(ACBranch(currentTradePeriod,i_branch),i_bus,i_flowDirection) $ ClosedBranch(ACBranch), ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection))
- sum(ACBranchReceivingBus(ACBranch(currentTradePeriod,i_branch),i_bus,i_flowDirection) $ ClosedBranch(ACBranch), ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection))
  ;

* 2nd definition of the net injection at buses corresponding to AC nodes (3.3.1.2)
ACnodeNetInjectionDefinition2(ACBus(currentTradePeriod,i_bus))..
ACnodeNETINJECTION(currentTradePeriod,i_bus) =e=
  sum(offerNode(currentTradePeriod,i_offer,i_node) $ NodeBus(currentTradePeriod,i_node,i_bus), NodeBusAllocationFactor(currentTradePeriod,i_node,i_bus) * GENERATION(currentTradePeriod,i_offer))
- sum(BidNode(currentTradePeriod,i_bid,i_node) $ NodeBus(currentTradePeriod,i_node,i_bus), NodeBusAllocationFactor(currentTradePeriod,i_node,i_bus) * PURCHASE(currentTradePeriod,i_bid))
- sum(NodeBus(currentTradePeriod,i_node,i_bus), NodeBusAllocationFactor(currentTradePeriod,i_node,i_bus) * NodeDemand(currentTradePeriod,i_node))
+ DEFICITBUSGENERATION(currentTradePeriod,i_bus) - SURPLUSBUSGENERATION(currentTradePeriod,i_bus)
- sum(HVDCLinkSendingBus(HVDCLink(currentTradePeriod,i_branch),i_bus) $ ClosedBranch(HVDCLink), HVDCLINKFLOW(HVDCLink))
+ sum(HVDCLinkReceivingBus(HVDCLink(currentTradePeriod,i_branch),i_bus) $ ClosedBranch(HVDCLink), HVDCLINKFLOW(HVDCLink) - HVDCLINKLOSSES(HVDCLink))
- sum(HVDCLinkBus(HVDCLink(currentTradePeriod,i_branch),i_bus) $ ClosedBranch(HVDCLink), 0.5 * HVDCLinkFixedLoss(HVDCLink))
- sum(ACBranchReceivingBus(ACBranch(currentTradePeriod,i_branch),i_bus,i_flowDirection) $ ClosedBranch(ACBranch), i_branchReceivingEndLossProportion * ACBRANCHLOSSESDIRECTED(ACBranch,i_flowDirection))
- sum(ACBranchSendingBus(ACBranch(currentTradePeriod,i_branch),i_bus,i_flowDirection) $ ClosedBranch(ACBranch), (1 - i_branchReceivingEndLossProportion) * ACBRANCHLOSSESDIRECTED(ACBranch,i_flowDirection))
- sum(BranchBusConnect(ACBranch(currentTradePeriod,i_branch),i_bus) $ ClosedBranch(ACBranch), 0.5 * ACBranchFixedLoss(ACBranch))
  ;

* Maximum flow on the AC branch (3.3.1.3)
ACBranchMaximumFlow(ClosedBranch(ACBranch),i_flowDirection) $ i_useACBranchLimits..
ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection) =l=
ACBranchCapacity(ACBranch)
+ SURPLUSBRANCHFLOW(ACBranch)
  ;

* Relationship between directed and undirected branch flow variables (3.3.1.4)
ACBranchFlowDefinition(ClosedBranch(ACBranch))..
ACBRANCHFLOW(ACBranch) =e=
  sum(i_flowDirection $ (ord(i_flowDirection) = 1), ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection))
- sum(i_flowDirection $ (ord(i_flowDirection) = 2), ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection))
  ;

* Equation that describes the linear load flow (3.3.1.5)
LinearLoadFlow(ClosedBranch(ACBranch(currentTradePeriod,i_branch)))..
ACBRANCHFLOW(ACBranch) =e=
ACBranchSusceptance(ACBranch) * sum(BranchBusDefn(ACBranch,i_fromBus,i_toBus), ACnodeANGLE(currentTradePeriod,i_fromBus) - ACnodeANGLE(currentTradePeriod,i_toBus))
  ;

* Limit on each AC branch flow block (3.3.1.6)
ACBranchBlockLimit(ValidLossSegment(ClosedBranch(ACBranch),i_lossSegment),i_flowDirection)..
ACBRANCHFLOWBLOCKDIRECTED(ACBranch,i_lossSegment,i_flowDirection) =l=
ACBranchLossMW(ACBranch,i_lossSegment)
  ;

* Composition of the directed branch flow from the block branch flow (3.3.1.7)
ACDirectedBranchFlowDefinition(ClosedBranch(ACBranch),i_flowDirection)..
ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection) =e=
sum(ValidLossSegment(ACBranch,i_lossSegment), ACBRANCHFLOWBLOCKDIRECTED(ACBranch,i_lossSegment,i_flowDirection))
  ;

* Calculation of the losses in each loss segment (3.3.1.8)
ACBranchLossCalculation(ValidLossSegment(ClosedBranch(ACBranch),i_lossSegment),i_flowDirection)..
ACBRANCHLOSSESBLOCKDIRECTED(ACBranch,i_lossSegment,i_flowDirection) =e=
ACBRANCHFLOWBLOCKDIRECTED(ACBranch,i_lossSegment,i_flowDirection) * ACBranchLossFactor(ACBranch,i_lossSegment)
  ;

* Composition of the directed branch losses from the block branch losses (3.3.1.9)
ACDirectedBranchLossDefinition(ClosedBranch(ACBranch),i_flowDirection)..
ACBRANCHLOSSESDIRECTED(ACBranch,i_flowDirection) =e=
sum(ValidLossSegment(ACBranch,i_lossSegment), ACBRANCHLOSSESBLOCKDIRECTED(ACBranch,i_lossSegment,i_flowDirection))
  ;

* Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1a)
ACDirectedBranchFlowIntegerDefinition1(ClosedBranch(ACBranch(LossBranch(currentTradePeriod,i_branch)))) $ (UseBranchFlowMIP(currentTradePeriod) and i_resolveCircularBranchFlows)..
sum(i_flowDirection, ACBRANCHFLOWDIRECTED_INTEGER(ACBranch,i_flowDirection)) =e=
sum(i_flowDirection, ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection))
  ;

* Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1b)
ACDirectedBranchFlowIntegerDefinition2(ClosedBranch(ACBranch(LossBranch(currentTradePeriod,i_branch))),i_flowDirection) $ (UseBranchFlowMIP(currentTradePeriod) and i_resolveCircularBranchFlows)..
ACBRANCHFLOWDIRECTED_INTEGER(ACBranch,i_flowDirection) =e=
ACBRANCHFLOWDIRECTED(ACBranch,i_flowDirection)
  ;

* Maximum movement of the generator upwards due to up ramp rate (3.7.1.1)
* Define this constraint over positive energy offers
* RDN - The standard ramp rate constraint does not apply to primary-secondary offers. See GenerationRampUp_PS
* GenerationRampUp(PositiveEnergyOffer)..
* GENERATION(PositiveEnergyOffer) - DEFICITRAMPRATE(PositiveEnergyOffer) =l=
* GenerationEndUp(PositiveEnergyOffer)
* ;
GenerationRampUp(PositiveEnergyOffer) $ (not (HasSecondaryOffer(PositiveEnergyOffer) or HasPrimaryOffer(PositiveEnergyOffer)))..
GENERATION(PositiveEnergyOffer) - DEFICITRAMPRATE(PositiveEnergyOffer) =l=
GenerationEndUp(PositiveEnergyOffer)
  ;

* Maximum movement of the generator downwards due to down ramp rate (3.7.1.2)
* Define this constraint over positive energy offers
* RDN - The standard ramp rate constraint does not apply to primary-secondary offers. See GenerationRampDown_PS
* GenerationRampDown(PositiveEnergyOffer)..
* GENERATION(PositiveEnergyOffer) + SURPLUSRAMPRATE(PositiveEnergyOffer) =g=
* GenerationEndDown(PositiveEnergyOffer)
* ;
GenerationRampDown(PositiveEnergyOffer) $ (not (HasSecondaryOffer(PositiveEnergyOffer) or HasPrimaryOffer(PositiveEnergyOffer)))..
GENERATION(PositiveEnergyOffer) + SURPLUSRAMPRATE(PositiveEnergyOffer) =g=
GenerationEndDown(PositiveEnergyOffer)
  ;

* RDN - Maximum movement of the primary offer that has a secondary offer upwards due to up ramp rate (3.7.1.1)
* Define this constraint over positive energy offers
GenerationRampUp_PS(currentTradePeriod,i_offer) $ (PositiveEnergyOffer(currentTradePeriod,i_offer) and HasSecondaryOffer(currentTradePeriod,i_offer))..
GENERATION(currentTradePeriod,i_offer) + sum(i_offer1 $ PrimarySecondaryOffer(currentTradePeriod,i_offer,i_offer1), GENERATION(currentTradePeriod,i_offer1)) - DEFICITRAMPRATE(currentTradePeriod,i_offer) =l=
GenerationEndUp(currentTradePeriod,i_offer)
  ;

* RDN - Maximum movement of the primary offer that has a secondary offer downwards due to down ramp rate (3.7.1.2)
* Define this constraint over positive energy offers
GenerationRampDown_PS(currentTradePeriod,i_offer) $ (PositiveEnergyOffer(currentTradePeriod,i_offer) and HasSecondaryOffer(currentTradePeriod,i_offer))..
GENERATION(currentTradePeriod,i_offer) + sum(i_offer1 $ PrimarySecondaryOffer(currentTradePeriod,i_offer,i_offer1), GENERATION(currentTradePeriod,i_offer1)) + SURPLUSRAMPRATE(currentTradePeriod,i_offer) =g=
GenerationEndDown(currentTradePeriod,i_offer)
  ;

* RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
* Approximation of the risk offset variable.  This approximation will be used if the i_useMixedConstraint flag is set to false
* RiskOffSetCalculationApproximation(currentTradePeriod,i_island,i_reserveClass,i_riskClass) $ (not i_useMixedConstraint)..
* RISKOFFSET(currentTradePeriod,i_island,i_reserveClass,i_riskClass) =e=
* FreeReserve(currentTradePeriod,i_island,i_reserveClass,i_riskClass) + HVDCPoleRampUp(currentTradePeriod,i_island,i_reserveClass,i_riskClass)
* ;

* RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
* Calculation of the risk offset variable for the DCCE risk class.  This will be used when the useMixedConstraintRiskOffset flag is false (3.4.1.2)
* RDN - Disable this constraint only when the original mixed constraint formulation specifit to the risk offset calculation is not used
* RiskOffsetCalculation_DCCE(currentTradePeriod,i_island,i_reserveClass,i_riskClass) $ ((not i_useMixedConstraint) and HVDCrisk(i_riskClass) and ContingentEvents(i_riskClass))..
RiskOffsetCalculation_DCCE(currentTradePeriod,i_island,i_reserveClass,i_riskClass) $ ((not useMixedConstraintRiskOffset) and HVDCrisk(i_riskClass) and ContingentEvents(i_riskClass))..
RISKOFFSET(currentTradePeriod,i_island,i_reserveClass,i_riskClass) =e=
FreeReserve(currentTradePeriod,i_island,i_reserveClass,i_riskClass) + HVDCPoleRampUp(currentTradePeriod,i_island,i_reserveClass,i_riskClass)
  ;

* RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
* Calculation of the risk offset variable for the DCECE risk class.  This will be used when the useMixedConstraintRiskOffset flag is false (3.4.1.4)
* RDN - Disable this constraint only when the original mixed constraint formulation specifit to the risk offset calculation is not used
* RiskOffsetCalculation_DCECE(currentTradePeriod,i_island,i_reserveClass,i_riskClass) $ ((not i_useMixedConstraint) and HVDCrisk(i_riskClass) and ExtendedContingentEvent(i_riskClass))..
RiskOffsetCalculation_DCECE(currentTradePeriod,i_island,i_reserveClass,i_riskClass) $ ((not useMixedConstraintRiskOffset) and HVDCrisk(i_riskClass) and ExtendedContingentEvent(i_riskClass))..
RISKOFFSET(currentTradePeriod,i_island,i_reserveClass,i_riskClass) =e=
FreeReserve(currentTradePeriod,i_island,i_reserveClass,i_riskClass)
  ;

* Risk offset definition (3.4.1.5) in old formulation (v4.4). use this when the useMixedConstraintRiskOffset flag is set.
* RDN - Enable this constraint only when the original mixed constraint formulation specifit to the risk offset calculation is used
* RiskOffsetCalculation(currentTradePeriod,i_type1MixedConstraintReserveMap(i_type1MixedConstraint,i_island,i_reserveClass,i_riskClass)) $ i_useMixedConstraint..
RiskOffsetCalculation(currentTradePeriod,i_type1MixedConstraintReserveMap(i_type1MixedConstraint,i_island,i_reserveClass,i_riskClass)) $ useMixedConstraintRiskOffset..
RISKOFFSET(currentTradePeriod,i_island,i_reserveClass,i_riskClass) =e=
MIXEDCONSTRAINTVARIABLE(currentTradePeriod,i_type1MixedConstraint)
  ;

* Calculation of the island risk for a DCCE and DCECE (3.4.1.1)
HVDCIslandRiskCalculation(currentTradePeriod,i_island,i_reserveClass,HVDCrisk)..
ISLANDRISK(currentTradePeriod,i_island,i_reserveClass,HVDCrisk) =e=
IslandRiskAdjustmentFactor(currentTradePeriod,i_island,i_reserveClass,HVDCrisk) * (HVDCREC(currentTradePeriod,i_island) - RISKOFFSET(currentTradePeriod,i_island,i_reserveClass,HVDCrisk))
  ;

* Calculation of the net received HVDC MW flow into an island (3.4.1.2)
* RDN - Change definition of constraint to cater for the fact that bus to HVDC could be mapped to more than one node
HVDCRecCalculation(currentTradePeriod,i_island)..
HVDCREC(currentTradePeriod,i_island) =e=
* sum((i_node,i_bus,i_branch) $ (NodeIsland(currentTradePeriod,i_node,i_island) and ACnode(currentTradePeriod,i_node) and NodeBus(currentTradePeriod,i_node,i_bus) and HVDCLink(currentTradePeriod,i_branch) and HVDCLinkSendingBus(currentTradePeriod,i_branch,i_bus) and HVDCLink(currentTradePeriod,i_branch)), -HVDCLINKFLOW(currentTradePeriod,i_branch))
* + sum((i_node,i_bus,i_branch) $ (NodeIsland(currentTradePeriod,i_node,i_island) and ACnode(currentTradePeriod,i_node) and NodeBus(currentTradePeriod,i_node,i_bus) and HVDCLink(currentTradePeriod,i_branch) and HVDCLinkReceivingBus(currentTradePeriod,i_branch,i_bus) and HVDCLink(currentTradePeriod,i_branch)), HVDCLINKFLOW(currentTradePeriod,i_branch) - HVDCLINKLOSSES(currentTradePeriod,i_branch))
* RDN - Change definition based on implementation (This was confirmed by Transpower).  To cater for roundpower - consider only HVDC poles as the sending links to avoid the reduction in the HVDCRec due to half-pole fixed losses
* sum((i_bus,i_branch) $ (BusIsland(currentTradePeriod,i_bus,i_island) and ACBus(currentTradePeriod,i_bus) and HVDCLink(currentTradePeriod,i_branch) and HVDCLinkSendingBus(currentTradePeriod,i_branch,i_bus) and HVDCLink(currentTradePeriod,i_branch)), -HVDCLINKFLOW(currentTradePeriod,i_branch))
* + sum((i_bus,i_branch) $ (BusIsland(currentTradePeriod,i_bus,i_island) and ACBus(currentTradePeriod,i_bus) and HVDCLink(currentTradePeriod,i_branch) and HVDCLinkReceivingBus(currentTradePeriod,i_branch,i_bus) and HVDCLink(currentTradePeriod,i_branch)), HVDCLINKFLOW(currentTradePeriod,i_branch) - HVDCLINKLOSSES(currentTradePeriod,i_branch))
  sum((i_bus,i_branch) $ (BusIsland(currentTradePeriod,i_bus,i_island) and ACBus(currentTradePeriod,i_bus) and HVDCLink(currentTradePeriod,i_branch) and HVDCLinkSendingBus(currentTradePeriod,i_branch,i_bus) and HVDCPoles(currentTradePeriod,i_branch)), -HVDCLINKFLOW(currentTradePeriod,i_branch))
+ sum((i_bus,i_branch) $ (BusIsland(currentTradePeriod,i_bus,i_island) and ACBus(currentTradePeriod,i_bus) and HVDCLink(currentTradePeriod,i_branch) and HVDCLinkReceivingBus(currentTradePeriod,i_branch,i_bus) and HVDCLink(currentTradePeriod,i_branch)), HVDCLINKFLOW(currentTradePeriod,i_branch) - HVDCLINKLOSSES(currentTradePeriod,i_branch))
  ;

* Calculation of the island risk for risk setting generators (3.4.1.6)
GenIslandRiskCalculation(currentTradePeriod,i_island,i_offer,i_reserveClass,GenRisk) $ ((not (UsePrimSecGenRiskModel)) and IslandRiskGenerator(currentTradePeriod,i_island,i_offer))..
ISLANDRISK(currentTradePeriod,i_island,i_reserveClass,GenRisk) =g=
* RDN - Include FKBand into the calculation of the generator risk and replace RISKOFFSET variable by FreeReserve parameter. The FreeReserve parameter is the same as the RiskOffsetParameter.
* IslandRiskAdjustmentFactor(currentTradePeriod,i_island,i_reserveClass,GenRisk) * (GENERATION(currentTradePeriod,i_offer) - RISKOFFSET(currentTradePeriod,i_island,i_reserveClass,GenRisk) + sum(i_reserveType, RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType)) )
IslandRiskAdjustmentFactor(currentTradePeriod,i_island,i_reserveClass,GenRisk) * (GENERATION(currentTradePeriod,i_offer) - FreeReserve(currentTradePeriod,i_island,i_reserveClass,GenRisk) + FKBand(currentTradePeriod,i_offer) + sum(i_reserveType, RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType)) )
  ;

*-----------------------------------------------
* Calculation of the island risk for risk setting generators (3.4.1.6)
* RDN - Generator island risk calculation with single offer
GenIslandRiskCalculation_NonPS(currentTradePeriod,i_island,i_offer,i_reserveClass,GenRisk) $ (UsePrimSecGenRiskModel and IslandRiskGenerator(currentTradePeriod,i_island,i_offer) and (not (HasSecondaryOffer(currentTradePeriod,i_offer) or HasPrimaryOffer(currentTradePeriod,i_offer))))..
ISLANDRISK(currentTradePeriod,i_island,i_reserveClass,GenRisk) =g=
IslandRiskAdjustmentFactor(currentTradePeriod,i_island,i_reserveClass,GenRisk) * (GENERATION(currentTradePeriod,i_offer) - FreeReserve(currentTradePeriod,i_island,i_reserveClass,GenRisk) + FKBand(currentTradePeriod,i_offer) + sum(i_reserveType, RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType)) )
  ;

* Calculation of the island risk for risk setting generators (3.4.1.6)
* RDN - Risk calculation for generators with more than one offer - Primary and secondary offers
GenIslandRiskCalculation_PS(currentTradePeriod,i_island,i_offer,i_reserveClass,GenRisk) $ (UsePrimSecGenRiskModel and IslandRiskGenerator(currentTradePeriod,i_island,i_offer) and HasSecondaryOffer(currentTradePeriod,i_offer))..
ISLANDRISK(currentTradePeriod,i_island,i_reserveClass,GenRisk) =g=
IslandRiskAdjustmentFactor(currentTradePeriod,i_island,i_reserveClass,GenRisk) * ((GENERATION(currentTradePeriod,i_offer) + sum(i_offer1 $ PrimarySecondaryOffer(currentTradePeriod,i_offer,i_offer1), GENERATION(currentTradePeriod,i_offer1))) - FreeReserve(currentTradePeriod,i_island,i_reserveClass,GenRisk) + FKBand(currentTradePeriod,i_offer)
+ (sum(i_reserveType, RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType)) + sum((i_offer1,i_reserveType) $ PrimarySecondaryOffer(currentTradePeriod,i_offer,i_offer1), RESERVE(currentTradePeriod,i_offer1,i_reserveClass,i_reserveType))) )
  ;
*-----------------------------------------------

* Calculation of the island risk based on manual specifications (3.4.1.7)
ManualIslandRiskCalculation(currentTradePeriod,i_island,i_reserveClass,ManualRisk)..
ISLANDRISK(currentTradePeriod,i_island,i_reserveClass,ManualRisk) =e=
* RDN - Include IslandMinimumRisk parameter that is indexed over i_riskClass and replace RISKOFFSET variable by FreeReserve parameter. The FreeReserve parameter is the same as the RiskOffsetParameter.
* IslandRiskAdjustmentFactor(currentTradePeriod,i_island,i_reserveClass,ManualRisk) * (IslandMinimumRisk(currentTradePeriod,i_island,i_reserveClass) - RISKOFFSET(currentTradePeriod,i_island,i_reserveClass,ManualRisk))
IslandRiskAdjustmentFactor(currentTradePeriod,i_island,i_reserveClass,ManualRisk) * (IslandMinimumRisk(currentTradePeriod,i_island,i_reserveClass,ManualRisk) - FreeReserve(currentTradePeriod,i_island,i_reserveClass,ManualRisk))
  ;

* RDN - HVDC secondary risk calculation including the FKBand for generator primary risk
* Calculation of the island risk for an HVDC secondary risk to a generator risk (3.4.1.8)
HVDCIslandSecRiskCalculation_GEN(currentTradePeriod,i_island,i_offer,i_reserveClass,HVDCSecRisk) $ ((not (UsePrimSecGenRiskModel)) and HVDCSecRiskEnabled(currentTradePeriod,i_island,HVDCSecRisk) and IslandRiskGenerator(currentTradePeriod,i_island,i_offer))..
ISLANDRISK(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) =g=
IslandRiskAdjustmentFactor(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) * (GENERATION(currentTradePeriod,i_offer) - FreeReserve(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) + HVDCREC(currentTradePeriod,i_island) - HVDCSecRiskSubtractor(currentTradePeriod,i_island) + FKBand(currentTradePeriod,i_offer) + sum(i_reserveType, RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType)))
  ;

*-----------------------------------------------
* Calculation of the island risk for an HVDC secondary risk to a generator risk (3.4.1.8)
HVDCIslandSecRiskCalculation_GEN_NonPS(currentTradePeriod,i_island,i_offer,i_reserveClass,HVDCSecRisk) $ (UsePrimSecGenRiskModel and HVDCSecRiskEnabled(currentTradePeriod,i_island,HVDCSecRisk) and IslandRiskGenerator(currentTradePeriod,i_island,i_offer) and (not (HasSecondaryOffer(currentTradePeriod,i_offer) or HasPrimaryOffer(currentTradePeriod,i_offer))))..
ISLANDRISK(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) =g=
IslandRiskAdjustmentFactor(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) * (GENERATION(currentTradePeriod,i_offer) - FreeReserve(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) + HVDCREC(currentTradePeriod,i_island) - HVDCSecRiskSubtractor(currentTradePeriod,i_island) + FKBand(currentTradePeriod,i_offer) + sum(i_reserveType, RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType)))
  ;

* Calculation of the island risk for an HVDC secondary risk to a generator risk (3.4.1.8)
HVDCIslandSecRiskCalculation_GEN_PS(currentTradePeriod,i_island,i_offer,i_reserveClass,HVDCSecRisk) $ (UsePrimSecGenRiskModel and HVDCSecRiskEnabled(currentTradePeriod,i_island,HVDCSecRisk) and IslandRiskGenerator(currentTradePeriod,i_island,i_offer) and HasSecondaryOffer(currentTradePeriod,i_offer))..
ISLANDRISK(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) =g=
IslandRiskAdjustmentFactor(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) * ((GENERATION(currentTradePeriod,i_offer) + sum(i_offer1 $ PrimarySecondaryOffer(currentTradePeriod,i_offer,i_offer1), GENERATION(currentTradePeriod,i_offer1)))
- FreeReserve(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) + HVDCREC(currentTradePeriod,i_island) - HVDCSecRiskSubtractor(currentTradePeriod,i_island) + FKBand(currentTradePeriod,i_offer)
+ (sum(i_reserveType, RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType)) + sum((i_offer1,i_reserveType) $ PrimarySecondaryOffer(currentTradePeriod,i_offer,i_offer1), RESERVE(currentTradePeriod,i_offer1,i_reserveClass,i_reserveType))) )
  ;
*-----------------------------------------------

* RDN - HVDC secondary risk calculation for manual primary risk
* Calculation of the island risk for an HVDC secondary risk to a manual risk (3.4.1.9)
HVDCIslandSecRiskCalculation_Manual(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) $ HVDCSecRiskEnabled(currentTradePeriod,i_island,HVDCSecRisk)..
ISLANDRISK(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) =g=
IslandRiskAdjustmentFactor(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) * (HVDCSecIslandMinimumRisk(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) - FreeReserve(currentTradePeriod,i_island,i_reserveClass,HVDCSecRisk) + HVDCREC(currentTradePeriod,i_island) - HVDCSecRiskSubtractor(currentTradePeriod,i_island))
  ;

* Maximum PLSR as a proportion of the block MW (3.4.2.1)
PLSRReserveProportionMaximum(validReserveOfferBlock(Offer,i_tradeBlock,i_reserveClass,PLSRReserveType))..
RESERVEBLOCK(Offer,i_tradeBlock,i_reserveClass,PLSRReserveType) =l=
ReserveOfferProportion(Offer,i_tradeBlock,i_reserveClass) * GENERATION(Offer)
  ;

* Definition of the reserve offers of different classes and types (3.4.2.3a)
ReserveOfferDefinition(Offer,i_reserveClass,i_reserveType)..
RESERVE(Offer,i_reserveClass,i_reserveType) =e=
sum(i_tradeBlock, RESERVEBLOCK(Offer,i_tradeBlock,i_reserveClass,i_reserveType))
  ;

* Definition of the ILR reserve provided by purchase bids (3.4.2.3b)
ReserveDefinitionPurchaseBid(Bid,i_reserveClass)..
PURCHASEILR(Bid,i_reserveClass) =e=
sum(i_tradeBlock, PURCHASEILRBLOCK(Bid,i_tradeBlock,i_reserveClass))
  ;

* Definition of maximum energy and reserves from each generator (3.4.2.4)
EnergyAndReserveMaximum(Offer,i_reserveClass)..
GENERATION(Offer) + ReserveMaximumFactor(Offer,i_reserveClass) * sum(i_reserveType $ (not ILReserveType(i_reserveType)), RESERVE(Offer,i_reserveClass,i_reserveType)) =l=
ReserveGenerationMaximum(Offer)
  ;

* RDN - Change to demand bid
* This constraint is no longer in the formulation from v6.0 (following changes with DSBF)
* Maximum ILR provided by purchase bids (3.4.2.5)
* PurchaseBidReserveMaximum(Bid,i_reserveClass)..
PurchaseBidReserveMaximum(Bid,i_reserveClass) $ (not (UseDSBFDemandBidModel))..
PURCHASEILR(Bid,i_reserveClass) =l=
PURCHASE(Bid)
  ;
* RDN - Change to demand bid - End

* Definition of the maximum risk in each island (3.4.3.1)
* MaximumIslandRiskDefinition(currentTradePeriod,i_island,i_reserveClass,i_riskClass)..
* ISLANDRISK(currentTradePeriod,i_island,i_reserveClass,i_riskClass) =l=
* MAXISLANDRISK(currentTradePeriod,i_island,i_reserveClass)
* ;

* Definition of the maximum risk in each island (3.4.3.1)
* RDN - Update maximum island risk definition to only apply when the CE and ECE CVPs are not separated
MaximumIslandRiskDefinition(currentTradePeriod,i_island,i_reserveClass,i_riskClass) $ (not DiffCeECeCVP)..
ISLANDRISK(currentTradePeriod,i_island,i_reserveClass,i_riskClass) =l=
MAXISLANDRISK(currentTradePeriod,i_island,i_reserveClass)
  ;

* RDN - Update maximum island risk definition with the CE and ECE deficit reserve
* Definition of the maximum CE risk in each island (3.4.3.1a) - use this definition if flag for different CVPs for CE and ECE
MaximumIslandRiskDefinition_CE(currentTradePeriod,i_island,i_reserveClass,ContingentEvents) $ (DiffCeECeCVP)..
ISLANDRISK(currentTradePeriod,i_island,i_reserveClass,ContingentEvents) =l=
MAXISLANDRISK(currentTradePeriod,i_island,i_reserveClass) + DEFICITRESERVE_CE(currentTradePeriod,i_island,i_reserveClass)
  ;

* RDN - Update maximum island risk definition with the CE and ECE deficit reserve
* Definition of the maximum ECE risk in each island (3.4.3.1b) - use this definition if flag for different CVPs for CE and ECE
MaximumIslandRiskDefinition_ECE(currentTradePeriod,i_island,i_reserveClass,ExtendedContingentEvent) $ (DiffCeECeCVP)..
ISLANDRISK(currentTradePeriod,i_island,i_reserveClass,ExtendedContingentEvent) =l=
MAXISLANDRISK(currentTradePeriod,i_island,i_reserveClass) + DEFICITRESERVE_ECE(currentTradePeriod,i_island,i_reserveClass)
  ;

* Matching of reserve supply and demand (3.4.3.2)
SupplyDemandReserveRequirement(currentTradePeriod,i_island,i_reserveClass) $ i_useReserveModel..
MAXISLANDRISK(currentTradePeriod,i_island,i_reserveClass) - (DEFICITRESERVE(currentTradePeriod,i_island,i_reserveClass) $ (not DiffCeECeCVP)) =l=
  sum((i_offer,i_reserveType) $ (Offer(currentTradePeriod,i_offer) and IslandOffer(currentTradePeriod,i_island,i_offer)), RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_bid $ (Bid(currentTradePeriod,i_bid) and IslandBid(currentTradePeriod,i_island,i_bid)), PURCHASEILR(currentTradePeriod,i_bid,i_reserveClass))
  ;

* Branch security constraint with LE sense (3.5.1.5a)
BranchSecurityConstraintLE(currentTradePeriod,i_branchConstraint) $ (BranchConstraintSense(currentTradePeriod,i_branchConstraint) = -1)..
  sum(i_branch $ ACBranch(currentTradePeriod,i_branch), BranchConstraintFactors(currentTradePeriod,i_branchConstraint,i_branch) * ACBRANCHFLOW(currentTradePeriod,i_branch))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), BranchConstraintFactors(currentTradePeriod,i_branchConstraint,i_branch) * HVDCLINKFLOW(currentTradePeriod,i_branch))
- SURPLUSBRANCHSECURITYCONSTRAINT(currentTradePeriod,i_branchConstraint) =l=
BranchConstraintLimit(currentTradePeriod,i_branchConstraint)
  ;

* Branch security constraint with GE sense (3.5.1.5b)
BranchSecurityConstraintGE(currentTradePeriod,i_branchConstraint) $ (BranchConstraintSense(currentTradePeriod,i_branchConstraint) = 1)..
  sum(i_branch $ ACBranch(currentTradePeriod,i_branch), BranchConstraintFactors(currentTradePeriod,i_branchConstraint,i_branch) * ACBRANCHFLOW(currentTradePeriod,i_branch))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), BranchConstraintFactors(currentTradePeriod,i_branchConstraint,i_branch) * HVDCLINKFLOW(currentTradePeriod,i_branch))
+ DEFICITBRANCHSECURITYCONSTRAINT(currentTradePeriod,i_branchConstraint) =g=
BranchConstraintLimit(currentTradePeriod,i_branchConstraint)
  ;

* Branch security constraint with EQ sense (3.5.1.5c)
BranchSecurityConstraintEQ(currentTradePeriod,i_branchConstraint) $ (BranchConstraintSense(currentTradePeriod,i_branchConstraint) = 0)..
  sum(i_branch $ ACBranch(currentTradePeriod,i_branch), BranchConstraintFactors(currentTradePeriod,i_branchConstraint,i_branch) * ACBRANCHFLOW(currentTradePeriod,i_branch))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), BranchConstraintFactors(currentTradePeriod,i_branchConstraint,i_branch) * HVDCLINKFLOW(currentTradePeriod,i_branch))
+ DEFICITBRANCHSECURITYCONSTRAINT(currentTradePeriod,i_branchConstraint) - SURPLUSBRANCHSECURITYCONSTRAINT(currentTradePeriod,i_branchConstraint) =e=
BranchConstraintLimit(currentTradePeriod,i_branchConstraint)
  ;

* AC node security constraint with LE sense (3.5.1.6a)
ACnodeSecurityConstraintLE(currentTradePeriod,i_ACnodeConstraint) $ (ACnodeConstraintSense(currentTradePeriod,i_ACnodeConstraint) = -1)..
sum((i_node,i_bus) $ (ACnode(currentTradePeriod,i_node) and NodeBus(currentTradePeriod,i_node,i_bus)), ACnodeConstraintFactors(currentTradePeriod,i_ACnodeConstraint,i_node) * NodeBusAllocationFactor(currentTradePeriod,i_node,i_bus) * ACnodeNETINJECTION(currentTradePeriod,i_bus))
- SURPLUSACnodeCONSTRAINT(currentTradePeriod,i_ACnodeConstraint) =l=
ACnodeConstraintLimit(currentTradePeriod,i_ACnodeConstraint)
  ;

* AC node security constraint with GE sense (3.5.1.6b)
ACnodeSecurityConstraintGE(currentTradePeriod,i_ACnodeConstraint) $ (ACnodeConstraintSense(currentTradePeriod,i_ACnodeConstraint) = 1)..
sum((i_node,i_bus) $ (ACnode(currentTradePeriod,i_node) and NodeBus(currentTradePeriod,i_node,i_bus)), ACnodeConstraintFactors(currentTradePeriod,i_ACnodeConstraint,i_node) * NodeBusAllocationFactor(currentTradePeriod,i_node,i_bus) * ACnodeNETINJECTION(currentTradePeriod,i_bus))
+ DEFICITACnodeCONSTRAINT(currentTradePeriod,i_ACnodeConstraint) =g=
ACnodeConstraintLimit(currentTradePeriod,i_ACnodeConstraint)
  ;

* AC node security constraint with EQ sense (3.5.1.6c)
ACnodeSecurityConstraintEQ(currentTradePeriod,i_ACnodeConstraint) $ (ACnodeConstraintSense(currentTradePeriod,i_ACnodeConstraint) = 0)..
sum((i_node,i_bus) $ (ACnode(currentTradePeriod,i_node) and NodeBus(currentTradePeriod,i_node,i_bus)), ACnodeConstraintFactors(currentTradePeriod,i_ACnodeConstraint,i_node) * NodeBusAllocationFactor(currentTradePeriod,i_node,i_bus) * ACnodeNETINJECTION(currentTradePeriod,i_bus))
+ DEFICITACnodeCONSTRAINT(currentTradePeriod,i_ACnodeConstraint) - SURPLUSACnodeCONSTRAINT(currentTradePeriod,i_ACnodeConstraint) =e=
ACnodeConstraintLimit(currentTradePeriod,i_ACnodeConstraint)
  ;



* Market node security constraint with LE sense (3.5.1.7a)
MNodeSecurityConstraintLE(currentTradePeriod,i_MNodeConstraint) $ (MNodeConstraintSense(currentTradePeriod,i_MNodeConstraint) = -1)..
* RDN - 20130226 - Only valid energy offers and bids are included in the constraint
* sum(i_offer, MNodeEnergyOfferConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
* + sum((i_offer,i_reserveClass,i_reserveType), MNodeReserveOfferConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
* + sum(i_bid, MNodeEnergyBidConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
* + sum((i_bid,i_reserveClass), MNodeILReserveBidConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_bid,i_reserveClass) * PURCHASEILR(currentTradePeriod,i_bid,i_reserveClass))
  sum(i_offer $ PositiveEnergyOffer(currentTradePeriod,i_offer), MNodeEnergyOfferConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum((i_offer,i_reserveClass,i_reserveType) $ offer(currentTradePeriod,i_offer), MNodeReserveOfferConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_bid $ Bid(currentTradePeriod,i_bid), MNodeEnergyBidConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
+ sum((i_bid,i_reserveClass) $ Bid(currentTradePeriod,i_bid), MNodeILReserveBidConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_bid,i_reserveClass) * PURCHASEILR(currentTradePeriod,i_bid,i_reserveClass))
- SURPLUSMNODECONSTRAINT(currentTradePeriod,i_MNodeConstraint) =l=
MNodeConstraintLimit(currentTradePeriod,i_MNodeConstraint)
  ;

* Market node security constraint with GE sense (3.5.1.7b)
MNodeSecurityConstraintGE(currentTradePeriod,i_MNodeConstraint) $ (MNodeConstraintSense(currentTradePeriod,i_MNodeConstraint) = 1)..
* RDN - 20130226 - Only valid energy offers and bids are included in the constraint
* sum(i_offer, MNodeEnergyOfferConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
* + sum((i_offer,i_reserveClass,i_reserveType), MNodeReserveOfferConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
* + sum(i_bid, MNodeEnergyBidConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
* + sum((i_bid,i_reserveClass), MNodeILReserveBidConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_bid,i_reserveClass) * PURCHASEILR(currentTradePeriod,i_bid,i_reserveClass))
  sum(i_offer $ PositiveEnergyOffer(currentTradePeriod,i_offer), MNodeEnergyOfferConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum((i_offer,i_reserveClass,i_reserveType) $ offer(currentTradePeriod,i_offer), MNodeReserveOfferConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_bid $ Bid(currentTradePeriod,i_bid), MNodeEnergyBidConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
+ sum((i_bid,i_reserveClass) $ Bid(currentTradePeriod,i_bid), MNodeILReserveBidConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_bid,i_reserveClass) * PURCHASEILR(currentTradePeriod,i_bid,i_reserveClass))
+ DEFICITMNODECONSTRAINT(currentTradePeriod,i_MNodeConstraint) =g=
MNodeConstraintLimit(currentTradePeriod,i_MNodeConstraint)
  ;

* Market node security constraint with EQ sense (3.5.1.7c)
MNodeSecurityConstraintEQ(currentTradePeriod,i_MNodeConstraint) $ (MNodeConstraintSense(currentTradePeriod,i_MNodeConstraint) = 0)..
* RDN - 20130226 - Only valid energy offers and bids are included in the constraint
* sum(i_offer, MNodeEnergyOfferConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
* + sum((i_offer,i_reserveClass,i_reserveType), MNodeReserveOfferConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
* + sum(i_bid, MNodeEnergyBidConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
* + sum((i_bid,i_reserveClass), MNodeILReserveBidConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_bid,i_reserveClass) * PURCHASEILR(currentTradePeriod,i_bid,i_reserveClass))
  sum(i_offer $ PositiveEnergyOffer(currentTradePeriod,i_offer), MNodeEnergyOfferConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum((i_offer,i_reserveClass,i_reserveType) $ offer(currentTradePeriod,i_offer), MNodeReserveOfferConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_bid $ Bid(currentTradePeriod,i_bid), MNodeEnergyBidConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
+ sum((i_bid,i_reserveClass) $ Bid(currentTradePeriod,i_bid), MNodeILReserveBidConstraintFactors(currentTradePeriod,i_MNodeConstraint,i_bid,i_reserveClass) * PURCHASEILR(currentTradePeriod,i_bid,i_reserveClass))
+ DEFICITMNODECONSTRAINT(currentTradePeriod,i_MNodeConstraint) - SURPLUSMNODECONSTRAINT(currentTradePeriod,i_MNodeConstraint) =e=
MNodeConstraintLimit(currentTradePeriod,i_MNodeConstraint)
  ;

* Type 1 mixed constraint definition with LE sense (3.6.1.1a)
* Type1MixedConstraintLE(currentTradePeriod,i_type1MixedConstraint) $ (i_useMixedConstraint and (Type1MixedConstraintSense(currentTradePeriod,i_type1MixedConstraint) = -1) and (not useMixedConstraintMIP(currentTradePeriod)))..
Type1MixedConstraintLE(currentTradePeriod,i_type1MixedConstraint) $ (UseMixedConstraint(currentTradePeriod) and (Type1MixedConstraintSense(currentTradePeriod,i_type1MixedConstraint) = -1) and (not useMixedConstraintMIP(currentTradePeriod)))..
i_type1MixedConstraintVarWeight(i_type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(currentTradePeriod,i_type1MixedConstraint)
* RDN - 20130226 - Only valid energy offers and bids are included in the constraint
* + sum(i_offer, i_type1MixedConstraintGenWeight(i_type1MixedConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
* + sum((i_offer,i_reserveClass,i_reserveType), i_type1MixedConstraintResWeight(i_type1MixedConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_offer $ PositiveEnergyOffer(currentTradePeriod,i_offer), i_type1MixedConstraintGenWeight(i_type1MixedConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum((i_offer,i_reserveClass,i_reserveType) $ offer(currentTradePeriod,i_offer), i_type1MixedConstraintResWeight(i_type1MixedConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), i_type1MixedConstraintHVDCLineWeight(i_type1MixedConstraint,i_branch) * HVDCLINKFLOW(currentTradePeriod,i_branch))
+ sum(i_branch $ ACBranch(currentTradePeriod,i_branch), i_type1MixedConstraintAClineWeight(i_type1MixedConstraint,i_branch) * sum(i_flowDirection, ACBRANCHFLOWDIRECTED(currentTradePeriod,i_branch,i_flowDirection)))
+ sum(i_branch $ ACBranch(currentTradePeriod,i_branch), i_type1MixedConstraintAClineLossWeight(i_type1MixedConstraint,i_branch) * sum(i_flowDirection, ACBRANCHLOSSESDIRECTED(currentTradePeriod,i_branch,i_flowDirection)))
+ sum(i_branch $ (ACBranch(currentTradePeriod,i_branch) and ClosedBranch(currentTradePeriod,i_branch)), i_type1MixedConstraintAClineFixedLossWeight(i_type1MixedConstraint,i_branch) * ACBranchFixedLoss(currentTradePeriod,i_branch))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), i_type1MixedConstraintHVDCLineLossWeight(i_type1MixedConstraint,i_branch) * HVDCLINKLOSSES(currentTradePeriod,i_branch))
+ sum(i_branch $ (HVDCLink(currentTradePeriod,i_branch) and ClosedBranch(currentTradePeriod,i_branch)), i_type1MixedConstraintHVDCLineFixedLossWeight(i_type1MixedConstraint,i_branch) * HVDCLinkFixedLoss(currentTradePeriod,i_branch))
+ sum(i_bid $ Bid(currentTradePeriod,i_bid), i_type1MixedConstraintPurWeight(i_type1MixedConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
- SURPLUSTYPE1MIXEDCONSTRAINT(currentTradePeriod,i_type1MixedConstraint) =l=
Type1MixedConstraintLimit1(currentTradePeriod,i_type1MixedConstraint)
  ;


* Type 1 mixed constraint definition with GE sense (3.6.1.1b)
* Type1MixedConstraintGE(currentTradePeriod,i_type1MixedConstraint) $ (i_useMixedConstraint and (Type1MixedConstraintSense(currentTradePeriod,i_type1MixedConstraint) = 1) and (not useMixedConstraintMIP(currentTradePeriod)))..
Type1MixedConstraintGE(currentTradePeriod,i_type1MixedConstraint) $ (UseMixedConstraint(currentTradePeriod) and (Type1MixedConstraintSense(currentTradePeriod,i_type1MixedConstraint) = 1) and (not useMixedConstraintMIP(currentTradePeriod)))..
i_type1MixedConstraintVarWeight(i_type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(currentTradePeriod,i_type1MixedConstraint)
* RDN - 20130226 - Only valid energy offers and bids are included in the constraint
* + sum(i_offer, i_type1MixedConstraintGenWeight(i_type1MixedConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
* + sum((i_offer,i_reserveClass,i_reserveType), i_type1MixedConstraintResWeight(i_type1MixedConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_offer $ PositiveEnergyOffer(currentTradePeriod,i_offer), i_type1MixedConstraintGenWeight(i_type1MixedConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum((i_offer,i_reserveClass,i_reserveType) $ offer(currentTradePeriod,i_offer), i_type1MixedConstraintResWeight(i_type1MixedConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), i_type1MixedConstraintHVDCLineWeight(i_type1MixedConstraint,i_branch) * HVDCLINKFLOW(currentTradePeriod,i_branch))
+ sum(i_branch $ ACBranch(currentTradePeriod,i_branch), i_type1MixedConstraintAClineWeight(i_type1MixedConstraint,i_branch) * sum(i_flowDirection, ACBRANCHFLOWDIRECTED(currentTradePeriod,i_branch,i_flowDirection)))
+ sum(i_branch $ ACBranch(currentTradePeriod,i_branch), i_type1MixedConstraintAClineLossWeight(i_type1MixedConstraint,i_branch) * sum(i_flowDirection, ACBRANCHLOSSESDIRECTED(currentTradePeriod,i_branch,i_flowDirection)))
+ sum(i_branch $ (ACBranch(currentTradePeriod,i_branch) and ClosedBranch(currentTradePeriod,i_branch)), i_type1MixedConstraintAClineFixedLossWeight(i_type1MixedConstraint,i_branch) * ACBranchFixedLoss(currentTradePeriod,i_branch))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), i_type1MixedConstraintHVDCLineLossWeight(i_type1MixedConstraint,i_branch) * HVDCLINKLOSSES(currentTradePeriod,i_branch))
+ sum(i_branch $ (HVDCLink(currentTradePeriod,i_branch) and ClosedBranch(currentTradePeriod,i_branch)), i_type1MixedConstraintHVDCLineFixedLossWeight(i_type1MixedConstraint,i_branch) * HVDCLinkFixedLoss(currentTradePeriod,i_branch))
+ sum(i_bid $ Bid(currentTradePeriod,i_bid), i_type1MixedConstraintPurWeight(i_type1MixedConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
+ DEFICITTYPE1MIXEDCONSTRAINT(currentTradePeriod,i_type1MixedConstraint) =g=
Type1MixedConstraintLimit1(currentTradePeriod,i_type1MixedConstraint)
  ;

* Type 1 mixed constraint definition with EQ sense (3.6.1.1c)
* Type1MixedConstraintEQ(currentTradePeriod,i_type1MixedConstraint) $ (i_useMixedConstraint and (Type1MixedConstraintSense(currentTradePeriod,i_type1MixedConstraint) = 0) and (not useMixedConstraintMIP(currentTradePeriod)))..
Type1MixedConstraintEQ(currentTradePeriod,i_type1MixedConstraint) $ (UseMixedConstraint(currentTradePeriod) and (Type1MixedConstraintSense(currentTradePeriod,i_type1MixedConstraint) = 0) and (not useMixedConstraintMIP(currentTradePeriod)))..
i_type1MixedConstraintVarWeight(i_type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(currentTradePeriod,i_type1MixedConstraint)
* RDN - 20130226 - Only valid energy offers and bids are included in the constraint
* + sum(i_offer, i_type1MixedConstraintGenWeight(i_type1MixedConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
* + sum((i_offer,i_reserveClass,i_reserveType), i_type1MixedConstraintResWeight(i_type1MixedConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_offer $ PositiveEnergyOffer(currentTradePeriod,i_offer), i_type1MixedConstraintGenWeight(i_type1MixedConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum((i_offer,i_reserveClass,i_reserveType) $ offer(currentTradePeriod,i_offer), i_type1MixedConstraintResWeight(i_type1MixedConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), i_type1MixedConstraintHVDCLineWeight(i_type1MixedConstraint,i_branch) * HVDCLINKFLOW(currentTradePeriod,i_branch))
+ sum(i_branch $ ACBranch(currentTradePeriod,i_branch), i_type1MixedConstraintAClineWeight(i_type1MixedConstraint,i_branch) * sum(i_flowDirection, ACBRANCHFLOWDIRECTED(currentTradePeriod,i_branch,i_flowDirection)))
+ sum(i_branch $ ACBranch(currentTradePeriod,i_branch), i_type1MixedConstraintAClineLossWeight(i_type1MixedConstraint,i_branch) * sum(i_flowDirection, ACBRANCHLOSSESDIRECTED(currentTradePeriod,i_branch,i_flowDirection)))
+ sum(i_branch $ (ACBranch(currentTradePeriod,i_branch) and ClosedBranch(currentTradePeriod,i_branch)), i_type1MixedConstraintAClineFixedLossWeight(i_type1MixedConstraint,i_branch) * ACBranchFixedLoss(currentTradePeriod,i_branch))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), i_type1MixedConstraintHVDCLineLossWeight(i_type1MixedConstraint,i_branch) * HVDCLINKLOSSES(currentTradePeriod,i_branch))
+ sum(i_branch $ (HVDCLink(currentTradePeriod,i_branch) and ClosedBranch(currentTradePeriod,i_branch)), i_type1MixedConstraintHVDCLineFixedLossWeight(i_type1MixedConstraint,i_branch) * HVDCLinkFixedLoss(currentTradePeriod,i_branch))
+ sum(i_bid $ Bid(currentTradePeriod,i_bid), i_type1MixedConstraintPurWeight(i_type1MixedConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
+ DEFICITTYPE1MIXEDCONSTRAINT(currentTradePeriod,i_type1MixedConstraint) - SURPLUSTYPE1MIXEDCONSTRAINT(currentTradePeriod,i_type1MixedConstraint) =e=
Type1MixedConstraintLimit1(currentTradePeriod,i_type1MixedConstraint)
  ;

* Type 2 mixed constraint definition with LE sense (3.6.1.2a)
* Type2MixedConstraintLE(currentTradePeriod,i_type2MixedConstraint) $ (i_useMixedConstraint and (Type2MixedConstraintSense(currentTradePeriod,i_type2MixedConstraint) = -1))..
Type2MixedConstraintLE(currentTradePeriod,i_type2MixedConstraint) $ (UseMixedConstraint(currentTradePeriod) and (Type2MixedConstraintSense(currentTradePeriod,i_type2MixedConstraint) = -1))..
sum(i_type1MixedConstraint, i_type2MixedConstraintLHSParameters(i_type2MixedConstraint,i_type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(currentTradePeriod,i_type1MixedConstraint))
=l=
Type2MixedConstraintLimit(currentTradePeriod,i_type2MixedConstraint)
  ;

* Type 2 mixed constraint definition with GE sense (3.6.1.2b)
* Type2MixedConstraintGE(currentTradePeriod,i_type2MixedConstraint) $ (i_useMixedConstraint and (Type2MixedConstraintSense(currentTradePeriod,i_type2MixedConstraint) = 1))..
Type2MixedConstraintGE(currentTradePeriod,i_type2MixedConstraint) $ (UseMixedConstraint(currentTradePeriod) and (Type2MixedConstraintSense(currentTradePeriod,i_type2MixedConstraint) = 1))..
sum(i_type1MixedConstraint, i_type2MixedConstraintLHSParameters(i_type2MixedConstraint,i_type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(currentTradePeriod,i_type1MixedConstraint))
=g=
Type2MixedConstraintLimit(currentTradePeriod,i_type2MixedConstraint)
  ;

* Type 2 mixed constraint definition with EQ sense (3.6.1.2c)
* Type2MixedConstraintEQ(currentTradePeriod,i_type2MixedConstraint) $ (i_useMixedConstraint and (Type2MixedConstraintSense(currentTradePeriod,i_type2MixedConstraint) = 0))..
Type2MixedConstraintEQ(currentTradePeriod,i_type2MixedConstraint) $ (UseMixedConstraint(currentTradePeriod) and (Type2MixedConstraintSense(currentTradePeriod,i_type2MixedConstraint) = 0))..
sum(i_type1MixedConstraint, i_type2MixedConstraintLHSParameters(i_type2MixedConstraint,i_type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(currentTradePeriod,i_type1MixedConstraint))
=e=
Type2MixedConstraintLimit(currentTradePeriod,i_type2MixedConstraint)
  ;

* Type 1 mixed constraint definition of alternate limit selection (integer)
* RDN - Enable this constraint only when the original mixed constraint formulation is used. This logic is specific to the HVDC pole 1 south flow condition.
* Type1MixedConstraintMIP(currentTradePeriod,i_type1MixedConstraintBranchCondition(i_type1MixedConstraint,i_branch)) $ (i_useMixedConstraint and HVDCHalfPoles(currentTradePeriod,i_branch) and useMixedConstraintMIP(currentTradePeriod))..
Type1MixedConstraintMIP(currentTradePeriod,i_type1MixedConstraintBranchCondition(i_type1MixedConstraint,i_branch)) $ (useMixedConstraintRiskOffset and HVDCHalfPoles(currentTradePeriod,i_branch) and useMixedConstraintMIP(currentTradePeriod))..
HVDCLINKFLOW(currentTradePeriod,i_branch) =l=
MIXEDCONSTRAINTLIMIT2SELECT(currentTradePeriod,i_type1MixedConstraint) * MixedConstraintBigNumber
  ;

* Integer equivalent of Type 1 mixed constraint definition with LE sense (3.6.1.1a_MIP)
* Type1MixedConstraintLE_MIP(Type1MixedConstraint(currentTradePeriod,i_type1MixedConstraint)) $ (i_useMixedConstraint and (Type1MixedConstraintSense(currentTradePeriod,i_type1MixedConstraint) = -1) and useMixedConstraintMIP(currentTradePeriod))..
Type1MixedConstraintLE_MIP(Type1MixedConstraint(currentTradePeriod,i_type1MixedConstraint)) $ (UseMixedConstraint(currentTradePeriod) and (Type1MixedConstraintSense(currentTradePeriod,i_type1MixedConstraint) = -1) and useMixedConstraintMIP(currentTradePeriod))..
i_type1MixedConstraintVarWeight(i_type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(currentTradePeriod,i_type1MixedConstraint)
* RDN - 20130226 - Only positive energy offers are included in the constraint
* + sum(i_offer $ offer(currentTradePeriod,i_offer), i_type1MixedConstraintGenWeight(i_type1MixedConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum(i_offer $ PositiveEnergyOffer(currentTradePeriod,i_offer), i_type1MixedConstraintGenWeight(i_type1MixedConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum((i_offer,i_reserveClass,i_reserveType) $ offer(currentTradePeriod,i_offer), i_type1MixedConstraintResWeight(i_type1MixedConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), i_type1MixedConstraintHVDCLineWeight(i_type1MixedConstraint,i_branch) * HVDCLINKFLOW(currentTradePeriod,i_branch))
+ sum(i_branch $ ACBranch(currentTradePeriod,i_branch), i_type1MixedConstraintAClineWeight(i_type1MixedConstraint,i_branch) * sum(i_flowDirection, ACBRANCHFLOWDIRECTED(currentTradePeriod,i_branch,i_flowDirection)))
+ sum(i_branch $ ACBranch(currentTradePeriod,i_branch), i_type1MixedConstraintAClineLossWeight(i_type1MixedConstraint,i_branch) * sum(i_flowDirection, ACBRANCHLOSSESDIRECTED(currentTradePeriod,i_branch,i_flowDirection)))
+ sum(i_branch $ (ACBranch(currentTradePeriod,i_branch) and ClosedBranch(currentTradePeriod,i_branch)), i_type1MixedConstraintAClineFixedLossWeight(i_type1MixedConstraint,i_branch) * ACBranchFixedLoss(currentTradePeriod,i_branch))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), i_type1MixedConstraintHVDCLineLossWeight(i_type1MixedConstraint,i_branch) * HVDCLINKLOSSES(currentTradePeriod,i_branch))
+ sum(i_branch $ (HVDCLink(currentTradePeriod,i_branch) and ClosedBranch(currentTradePeriod,i_branch)), i_type1MixedConstraintHVDCLineFixedLossWeight(i_type1MixedConstraint,i_branch) * HVDCLinkFixedLoss(currentTradePeriod,i_branch))
+ sum(i_bid $ Bid(currentTradePeriod,i_bid), i_type1MixedConstraintPurWeight(i_type1MixedConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
- SURPLUSTYPE1MIXEDCONSTRAINT(currentTradePeriod,i_type1MixedConstraint) =l=
Type1MixedConstraintLimit1(currentTradePeriod,i_type1MixedConstraint) * (1 - MIXEDCONSTRAINTLIMIT2SELECT(currentTradePeriod,i_type1MixedConstraint))
+ Type1MixedConstraintLimit2(currentTradePeriod,i_type1MixedConstraint) * MIXEDCONSTRAINTLIMIT2SELECT(currentTradePeriod,i_type1MixedConstraint)
  ;

* Integer equivalent of Type 1 mixed constraint definition with GE sense (3.6.1.1b_MIP)
* Type1MixedConstraintGE_MIP(Type1MixedConstraint(currentTradePeriod,i_type1MixedConstraint)) $ (i_useMixedConstraint and (Type1MixedConstraintSense(currentTradePeriod,i_type1MixedConstraint) = 1) and useMixedConstraintMIP(currentTradePeriod))..
Type1MixedConstraintGE_MIP(Type1MixedConstraint(currentTradePeriod,i_type1MixedConstraint)) $ (UseMixedConstraint(currentTradePeriod) and (Type1MixedConstraintSense(currentTradePeriod,i_type1MixedConstraint) = 1) and useMixedConstraintMIP(currentTradePeriod))..
i_type1MixedConstraintVarWeight(i_type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(currentTradePeriod,i_type1MixedConstraint)
* RDN - 20130226 - Only positive energy offers are included in the constraint
* + sum(i_offer $ offer(currentTradePeriod,i_offer), i_type1MixedConstraintGenWeight(i_type1MixedConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum(i_offer $ PositiveEnergyOffer(currentTradePeriod,i_offer), i_type1MixedConstraintGenWeight(i_type1MixedConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum((i_offer,i_reserveClass,i_reserveType) $ offer(currentTradePeriod,i_offer), i_type1MixedConstraintResWeight(i_type1MixedConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), i_type1MixedConstraintHVDCLineWeight(i_type1MixedConstraint,i_branch) * HVDCLINKFLOW(currentTradePeriod,i_branch))
+ sum(i_branch $ ACBranch(currentTradePeriod,i_branch), i_type1MixedConstraintAClineWeight(i_type1MixedConstraint,i_branch) * sum(i_flowDirection, ACBRANCHFLOWDIRECTED(currentTradePeriod,i_branch,i_flowDirection)))
+ sum(i_branch $ ACBranch(currentTradePeriod,i_branch), i_type1MixedConstraintAClineLossWeight(i_type1MixedConstraint,i_branch) * sum(i_flowDirection, ACBRANCHLOSSESDIRECTED(currentTradePeriod,i_branch,i_flowDirection)))
+ sum(i_branch $ (ACBranch(currentTradePeriod,i_branch) and ClosedBranch(currentTradePeriod,i_branch)), i_type1MixedConstraintAClineFixedLossWeight(i_type1MixedConstraint,i_branch) * ACBranchFixedLoss(currentTradePeriod,i_branch))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), i_type1MixedConstraintHVDCLineLossWeight(i_type1MixedConstraint,i_branch) * HVDCLINKLOSSES(currentTradePeriod,i_branch))
+ sum(i_branch $ (HVDCLink(currentTradePeriod,i_branch) and ClosedBranch(currentTradePeriod,i_branch)), i_type1MixedConstraintHVDCLineFixedLossWeight(i_type1MixedConstraint,i_branch) * HVDCLinkFixedLoss(currentTradePeriod,i_branch))
+ sum(i_bid $ Bid(currentTradePeriod,i_bid), i_type1MixedConstraintPurWeight(i_type1MixedConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
+ DEFICITTYPE1MIXEDCONSTRAINT(currentTradePeriod,i_type1MixedConstraint) =g=
Type1MixedConstraintLimit1(currentTradePeriod,i_type1MixedConstraint) * (1 - MIXEDCONSTRAINTLIMIT2SELECT(currentTradePeriod,i_type1MixedConstraint))
+ Type1MixedConstraintLimit2(currentTradePeriod,i_type1MixedConstraint) * MIXEDCONSTRAINTLIMIT2SELECT(currentTradePeriod,i_type1MixedConstraint)
  ;

* Integer equivalent of Type 1 mixed constraint definition with EQ sense (3.6.1.1b_MIP)
* Type1MixedConstraintEQ_MIP(Type1MixedConstraint(currentTradePeriod,i_type1MixedConstraint)) $ (i_useMixedConstraint and (Type1MixedConstraintSense(currentTradePeriod,i_type1MixedConstraint) = 0) and useMixedConstraintMIP(currentTradePeriod))..
Type1MixedConstraintEQ_MIP(Type1MixedConstraint(currentTradePeriod,i_type1MixedConstraint)) $ (UseMixedConstraint(currentTradePeriod) and (Type1MixedConstraintSense(currentTradePeriod,i_type1MixedConstraint) = 0) and useMixedConstraintMIP(currentTradePeriod))..
i_type1MixedConstraintVarWeight(i_type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(currentTradePeriod,i_type1MixedConstraint)
* RDN - 20130226 - Only positive energy offers are included in the constraint
* + sum(i_offer $ offer(currentTradePeriod,i_offer), i_type1MixedConstraintGenWeight(i_type1MixedConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum(i_offer $ PositiveEnergyOffer(currentTradePeriod,i_offer), i_type1MixedConstraintGenWeight(i_type1MixedConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum((i_offer,i_reserveClass,i_reserveType) $ offer(currentTradePeriod,i_offer), i_type1MixedConstraintResWeight(i_type1MixedConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), i_type1MixedConstraintHVDCLineWeight(i_type1MixedConstraint,i_branch) * HVDCLINKFLOW(currentTradePeriod,i_branch))
+ sum(i_branch $ ACBranch(currentTradePeriod,i_branch), i_type1MixedConstraintAClineWeight(i_type1MixedConstraint,i_branch) * sum(i_flowDirection, ACBRANCHFLOWDIRECTED(currentTradePeriod,i_branch,i_flowDirection)))
+ sum(i_branch $ ACBranch(currentTradePeriod,i_branch), i_type1MixedConstraintAClineLossWeight(i_type1MixedConstraint,i_branch) * sum(i_flowDirection, ACBRANCHLOSSESDIRECTED(currentTradePeriod,i_branch,i_flowDirection)))
+ sum(i_branch $ (ACBranch(currentTradePeriod,i_branch) and ClosedBranch(currentTradePeriod,i_branch)), i_type1MixedConstraintAClineFixedLossWeight(i_type1MixedConstraint,i_branch) * ACBranchFixedLoss(currentTradePeriod,i_branch))
+ sum(i_branch $ HVDCLink(currentTradePeriod,i_branch), i_type1MixedConstraintHVDCLineLossWeight(i_type1MixedConstraint,i_branch) * HVDCLINKLOSSES(currentTradePeriod,i_branch))
+ sum(i_branch $ (HVDCLink(currentTradePeriod,i_branch) and ClosedBranch(currentTradePeriod,i_branch)), i_type1MixedConstraintHVDCLineFixedLossWeight(i_type1MixedConstraint,i_branch) * HVDCLinkFixedLoss(currentTradePeriod,i_branch))
+ sum(i_bid $ Bid(currentTradePeriod,i_bid), i_type1MixedConstraintPurWeight(i_type1MixedConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
+ DEFICITTYPE1MIXEDCONSTRAINT(currentTradePeriod,i_type1MixedConstraint) - SURPLUSTYPE1MIXEDCONSTRAINT(currentTradePeriod,i_type1MixedConstraint) =e=
Type1MixedConstraintLimit1(currentTradePeriod,i_type1MixedConstraint) * (1 - MIXEDCONSTRAINTLIMIT2SELECT(currentTradePeriod,i_type1MixedConstraint))
+ Type1MixedConstraintLimit2(currentTradePeriod,i_type1MixedConstraint) * MIXEDCONSTRAINTLIMIT2SELECT(currentTradePeriod,i_type1MixedConstraint)
  ;

* Generic security constraint with LE sense
GenericSecurityConstraintLE(currentTradePeriod,i_genericConstraint) $ (GenericConstraintSense(currentTradePeriod,i_genericConstraint) = -1)..
* RDN - 20130226 - Include only valid energy offers, bids and branch flows
* sum(i_offer, GenericEnergyOfferConstraintFactors(currentTradePeriod,i_genericConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
* + sum((i_offer,i_reserveClass,i_reserveType), GenericReserveOfferConstraintFactors(currentTradePeriod,i_genericConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
* + sum(i_bid, GenericEnergyBidConstraintFactors(currentTradePeriod,i_genericConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
* + sum((i_bid,i_reserveClass), GenericILReserveBidConstraintFactors(currentTradePeriod,i_genericConstraint,i_bid,i_reserveClass) * PURCHASEILR(currentTradePeriod,i_bid,i_reserveClass))
* + sum(i_branch, GenericBranchConstraintFactors(currentTradePeriod,i_genericConstraint,i_branch) * (ACBRANCHFLOW(currentTradePeriod,i_branch) + HVDCLINKFLOW(currentTradePeriod,i_branch)))
  sum(i_offer $ PositiveEnergyOffer(currentTradePeriod,i_offer), GenericEnergyOfferConstraintFactors(currentTradePeriod,i_genericConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum((i_offer,i_reserveClass,i_reserveType) $ offer(currentTradePeriod,i_offer), GenericReserveOfferConstraintFactors(currentTradePeriod,i_genericConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_bid $ Bid(currentTradePeriod,i_bid), GenericEnergyBidConstraintFactors(currentTradePeriod,i_genericConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
+ sum((i_bid,i_reserveClass) $ Bid(currentTradePeriod,i_bid), GenericILReserveBidConstraintFactors(currentTradePeriod,i_genericConstraint,i_bid,i_reserveClass) * PURCHASEILR(currentTradePeriod,i_bid,i_reserveClass))
+ sum(i_branch $ ((ACBranch(currentTradePeriod,i_branch) or HVDCLink(currentTradePeriod,i_branch)) and ClosedBranch(currentTradePeriod,i_branch)), GenericBranchConstraintFactors(currentTradePeriod,i_genericConstraint,i_branch) * (ACBRANCHFLOW(currentTradePeriod,i_branch) + HVDCLINKFLOW(currentTradePeriod,i_branch)))
- SURPLUSGENERICCONSTRAINT(currentTradePeriod,i_genericConstraint) =l=
GenericConstraintLimit(currentTradePeriod,i_genericConstraint)
  ;

* Generic security constraint with GE sense
GenericSecurityConstraintGE(currentTradePeriod,i_genericConstraint) $ (GenericConstraintSense(currentTradePeriod,i_genericConstraint) = 1)..
* RDN - 20130226 - Include only valid energy offers, bids and branch flows
* sum(i_offer, GenericEnergyOfferConstraintFactors(currentTradePeriod,i_genericConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
* + sum((i_offer,i_reserveClass,i_reserveType), GenericReserveOfferConstraintFactors(currentTradePeriod,i_genericConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
* + sum(i_bid, GenericEnergyBidConstraintFactors(currentTradePeriod,i_genericConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
* + sum((i_bid,i_reserveClass), GenericILReserveBidConstraintFactors(currentTradePeriod,i_genericConstraint,i_bid,i_reserveClass) * PURCHASEILR(currentTradePeriod,i_bid,i_reserveClass))
* + sum(i_branch, GenericBranchConstraintFactors(currentTradePeriod,i_genericConstraint,i_branch) * (ACBRANCHFLOW(currentTradePeriod,i_branch) + HVDCLINKFLOW(currentTradePeriod,i_branch)))
  sum(i_offer $ PositiveEnergyOffer(currentTradePeriod,i_offer), GenericEnergyOfferConstraintFactors(currentTradePeriod,i_genericConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum((i_offer,i_reserveClass,i_reserveType) $ offer(currentTradePeriod,i_offer), GenericReserveOfferConstraintFactors(currentTradePeriod,i_genericConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_bid $ Bid(currentTradePeriod,i_bid), GenericEnergyBidConstraintFactors(currentTradePeriod,i_genericConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
+ sum((i_bid,i_reserveClass) $ Bid(currentTradePeriod,i_bid), GenericILReserveBidConstraintFactors(currentTradePeriod,i_genericConstraint,i_bid,i_reserveClass) * PURCHASEILR(currentTradePeriod,i_bid,i_reserveClass))
+ sum(i_branch $ ((ACBranch(currentTradePeriod,i_branch) or HVDCLink(currentTradePeriod,i_branch)) and ClosedBranch(currentTradePeriod,i_branch)), GenericBranchConstraintFactors(currentTradePeriod,i_genericConstraint,i_branch) * (ACBRANCHFLOW(currentTradePeriod,i_branch) + HVDCLINKFLOW(currentTradePeriod,i_branch)))
+ DEFICITGENERICCONSTRAINT(currentTradePeriod,i_genericConstraint) =g=
GenericConstraintLimit(currentTradePeriod,i_genericConstraint)
  ;

* Generic security constraint with EQ sense
GenericSecurityConstraintEQ(currentTradePeriod,i_genericConstraint) $ (GenericConstraintSense(currentTradePeriod,i_genericConstraint) = 0)..
* RDN - 20130226 - Include only valid energy offers, bids and branch flows
* sum(i_offer, GenericEnergyOfferConstraintFactors(currentTradePeriod,i_genericConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
* + sum((i_offer,i_reserveClass,i_reserveType), GenericReserveOfferConstraintFactors(currentTradePeriod,i_genericConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
* + sum(i_bid, GenericEnergyBidConstraintFactors(currentTradePeriod,i_genericConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
* + sum((i_bid,i_reserveClass), GenericILReserveBidConstraintFactors(currentTradePeriod,i_genericConstraint,i_bid,i_reserveClass) * PURCHASEILR(currentTradePeriod,i_bid,i_reserveClass))
* + sum(i_branch, GenericBranchConstraintFactors(currentTradePeriod,i_genericConstraint,i_branch) * (ACBRANCHFLOW(currentTradePeriod,i_branch) + HVDCLINKFLOW(currentTradePeriod,i_branch)))
  sum(i_offer $ PositiveEnergyOffer(currentTradePeriod,i_offer), GenericEnergyOfferConstraintFactors(currentTradePeriod,i_genericConstraint,i_offer) * GENERATION(currentTradePeriod,i_offer))
+ sum((i_offer,i_reserveClass,i_reserveType) $ offer(currentTradePeriod,i_offer), GenericReserveOfferConstraintFactors(currentTradePeriod,i_genericConstraint,i_offer,i_reserveClass,i_reserveType) * RESERVE(currentTradePeriod,i_offer,i_reserveClass,i_reserveType))
+ sum(i_bid $ Bid(currentTradePeriod,i_bid), GenericEnergyBidConstraintFactors(currentTradePeriod,i_genericConstraint,i_bid) * PURCHASE(currentTradePeriod,i_bid))
+ sum((i_bid,i_reserveClass) $ Bid(currentTradePeriod,i_bid), GenericILReserveBidConstraintFactors(currentTradePeriod,i_genericConstraint,i_bid,i_reserveClass) * PURCHASEILR(currentTradePeriod,i_bid,i_reserveClass))
+ sum(i_branch $ ((ACBranch(currentTradePeriod,i_branch) or HVDCLink(currentTradePeriod,i_branch)) and ClosedBranch(currentTradePeriod,i_branch)), GenericBranchConstraintFactors(currentTradePeriod,i_genericConstraint,i_branch) * (ACBRANCHFLOW(currentTradePeriod,i_branch) + HVDCLINKFLOW(currentTradePeriod,i_branch)))
+ DEFICITGENERICCONSTRAINT(currentTradePeriod,i_genericConstraint) - SURPLUSGENERICCONSTRAINT(currentTradePeriod,i_genericConstraint) =e=
GenericConstraintLimit(currentTradePeriod,i_genericConstraint)
  ;

* Model declarations
Model vSPD /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, GenerationRampUp, GenerationRampDown, PurchaseBidDefintion
* RDN - Primary-secondary ramping constraints
  GenerationRampUp_PS, GenerationRampDown_PS
* Network
  HVDCLinkMaximumFlow, HVDCLinkLossDefinition, HVDCLinkFlowDefinition, LambdaDefinition, DCNodeNetInjection, ACnodeNetInjectionDefinition1, ACnodeNetInjectionDefinition2
  ACBranchMaximumFlow, ACBranchFlowDefinition, LinearLoadFlow, ACBranchBlockLimit, ACDirectedBranchFlowDefinition, ACBranchLossCalculation, ACDirectedBranchLossDefinition
* Risk and Reserve
  HVDCIslandRiskCalculation, HVDCRecCalculation, GenIslandRiskCalculation, ManualIslandRiskCalculation, PLSRReserveProportionMaximum, ReserveOfferDefinition
  ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum, PurchaseBidReserveMaximum, MaximumIslandRiskDefinition, SupplyDemandReserveRequirement, RiskOffsetCalculation
* RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
* RiskOffSetCalculationApproximation
  RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
* RDN - Island risk definition for different CE and ECE CVPs
  MaximumIslandRiskDefinition_CE, MaximumIslandRiskDefinition_ECE
* RDN - Include HVDC secondary risk constraints
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_Manual
* Branch security constraints
  BranchSecurityConstraintLE, BranchSecurityConstraintGE, BranchSecurityConstraintEQ
* AC node security constraints
  ACnodeSecurityConstraintLE, ACnodeSecurityConstraintGE, ACnodeSecurityConstraintEQ
* Market node security constraints
  MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
* Mixed constraints
  Type1MixedConstraintLE, Type1MixedConstraintGE, Type1MixedConstraintEQ, Type2MixedConstraintLE, Type2MixedConstraintGE, Type2MixedConstraintEQ
* Generic constraints
  GenericSecurityConstraintLE, GenericSecurityConstraintGE, GenericSecurityConstraintEQ
* ViolationCost
  TotalViolationCostDefinition
* RDN - Generator island risk calculation considering more than one offer per generator
  GenIslandRiskCalculation_NonPS, GenIslandRiskCalculation_PS
  HVDCIslandSecRiskCalculation_GEN_NonPS, HVDCIslandSecRiskCalculation_GEN_PS
  / ;


Model vSPD_MIP /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, GenerationRampUp, GenerationRampDown, PurchaseBidDefintion
* RDN - Primary-secondary ramping constraints
  GenerationRampUp_PS, GenerationRampDown_PS
* Network
  HVDCLinkMaximumFlow, HVDCLinkLossDefinition, HVDCLinkFlowDefinition, LambdaDefinition, DCNodeNetInjection, ACnodeNetInjectionDefinition1, ACnodeNetInjectionDefinition2
  ACBranchMaximumFlow, ACBranchFlowDefinition, LinearLoadFlow, ACBranchBlockLimit, ACDirectedBranchFlowDefinition, ACBranchLossCalculation, ACDirectedBranchLossDefinition
  ACDirectedBranchFlowIntegerDefinition1, ACDirectedBranchFlowIntegerDefinition2
  LambdaIntegerDefinition1, LambdaIntegerDefinition2
* Risk and Reserve
  HVDCIslandRiskCalculation, HVDCRecCalculation, GenIslandRiskCalculation, ManualIslandRiskCalculation, PLSRReserveProportionMaximum, ReserveOfferDefinition
  ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum, PurchaseBidReserveMaximum, MaximumIslandRiskDefinition, SupplyDemandReserveRequirement, RiskOffsetCalculation
* RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
* RiskOffSetCalculationApproximation
  RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
* RDN - Island risk definition for different CE and ECE CVPs
  MaximumIslandRiskDefinition_CE, MaximumIslandRiskDefinition_ECE
* RDN - Include HVDC secondary risk constraints
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_Manual
* Branch security constraints
  BranchSecurityConstraintLE, BranchSecurityConstraintGE, BranchSecurityConstraintEQ
* AC node security constraints
  ACnodeSecurityConstraintLE, ACnodeSecurityConstraintGE, ACnodeSecurityConstraintEQ
* Market node security constraints
  MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
* Mixed constraints
  Type1MixedConstraintMIP, Type1MixedConstraintLE_MIP, Type1MixedConstraintGE_MIP, Type1MixedConstraintEQ_MIP, Type2MixedConstraintLE, Type2MixedConstraintGE, Type2MixedConstraintEQ
* Generic constraints
  GenericSecurityConstraintLE, GenericSecurityConstraintGE, GenericSecurityConstraintEQ
* ViolationCost
  TotalViolationCostDefinition
* RDN - Updated set of integer constraints on the HVDC link to incorporate the allowance of HVDC roundpower
  HVDCLinkFlowIntegerDefinition1, HVDCLinkFlowIntegerDefinition2
  HVDCLinkFlowIntegerDefinition3, HVDCLinkFlowIntegerDefinition4
* RDN - Generator island risk calculation considering more than one offer per generator
  GenIslandRiskCalculation_NonPS, GenIslandRiskCalculation_PS
  HVDCIslandSecRiskCalculation_GEN_NonPS, HVDCIslandSecRiskCalculation_GEN_PS
  / ;


Model vSPD_BranchFlowMIP /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, GenerationRampUp, GenerationRampDown, PurchaseBidDefintion
* RDN - Primary-secondary ramping constraints
  GenerationRampUp_PS, GenerationRampDown_PS
* Network
  HVDCLinkMaximumFlow, HVDCLinkLossDefinition, HVDCLinkFlowDefinition, LambdaDefinition, DCNodeNetInjection, ACnodeNetInjectionDefinition1, ACnodeNetInjectionDefinition2
  ACBranchMaximumFlow, ACBranchFlowDefinition, LinearLoadFlow, ACBranchBlockLimit, ACDirectedBranchFlowDefinition, ACBranchLossCalculation, ACDirectedBranchLossDefinition
  ACDirectedBranchFlowIntegerDefinition1, ACDirectedBranchFlowIntegerDefinition2
  LambdaIntegerDefinition1, LambdaIntegerDefinition2
* Risk and Reserve
  HVDCIslandRiskCalculation, HVDCRecCalculation, GenIslandRiskCalculation, ManualIslandRiskCalculation, PLSRReserveProportionMaximum, ReserveOfferDefinition
  ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum, PurchaseBidReserveMaximum, MaximumIslandRiskDefinition, SupplyDemandReserveRequirement, RiskOffsetCalculation
* RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
* RiskOffSetCalculationApproximation
  RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
* RDN - Island risk definition for different CE and ECE CVPs
  MaximumIslandRiskDefinition_CE, MaximumIslandRiskDefinition_ECE
* RDN - Include HVDC secondary risk constraints
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_Manual
* Branch security constraints
  BranchSecurityConstraintLE, BranchSecurityConstraintGE, BranchSecurityConstraintEQ
* AC node security constraints
  ACnodeSecurityConstraintLE, ACnodeSecurityConstraintGE, ACnodeSecurityConstraintEQ
* Market node security constraints
  MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
* Mixed constraints
  Type1MixedConstraintLE, Type1MixedConstraintGE, Type1MixedConstraintEQ, Type2MixedConstraintLE, Type2MixedConstraintGE, Type2MixedConstraintEQ
* Generic constraints
  GenericSecurityConstraintLE, GenericSecurityConstraintGE, GenericSecurityConstraintEQ
* ViolationCost
  TotalViolationCostDefinition
* RDN - Updated set of intrger constraints on the HVDC link to incorporate the allowance of HVDC roundpower
  HVDCLinkFlowIntegerDefinition1, HVDCLinkFlowIntegerDefinition2
  HVDCLinkFlowIntegerDefinition3, HVDCLinkFlowIntegerDefinition4
* RDN - Generator island risk calculation considering more than one offer per generator
  GenIslandRiskCalculation_NonPS, GenIslandRiskCalculation_PS
  HVDCIslandSecRiskCalculation_GEN_NonPS, HVDCIslandSecRiskCalculation_GEN_PS
  / ;

Model vSPD_MixedConstraintMIP /
* Objective function
  ObjectiveFunction
* Offer and purchase definitions
  GenerationOfferDefintion, GenerationRampUp, GenerationRampDown, PurchaseBidDefintion
* RDN - Primary-secondary ramping constraints
  GenerationRampUp_PS, GenerationRampDown_PS
* Network
  HVDCLinkMaximumFlow, HVDCLinkLossDefinition, HVDCLinkFlowDefinition, LambdaDefinition, DCNodeNetInjection, ACnodeNetInjectionDefinition1, ACnodeNetInjectionDefinition2
  ACBranchMaximumFlow, ACBranchFlowDefinition, LinearLoadFlow, ACBranchBlockLimit, ACDirectedBranchFlowDefinition, ACBranchLossCalculation, ACDirectedBranchLossDefinition
* Risk and Reserve
  HVDCIslandRiskCalculation, HVDCRecCalculation, GenIslandRiskCalculation, ManualIslandRiskCalculation, PLSRReserveProportionMaximum, ReserveOfferDefinition
  ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum, PurchaseBidReserveMaximum, MaximumIslandRiskDefinition, SupplyDemandReserveRequirement, RiskOffsetCalculation
* RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
* RiskOffSetCalculationApproximation
  RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
* RDN - Island risk definition for different CE and ECE CVPs
  MaximumIslandRiskDefinition_CE, MaximumIslandRiskDefinition_ECE
* RDN - Include HVDC secondary risk constraints
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_Manual
* Branch security constraints
  BranchSecurityConstraintLE, BranchSecurityConstraintGE, BranchSecurityConstraintEQ
* AC node security constraints
  ACnodeSecurityConstraintLE, ACnodeSecurityConstraintGE, ACnodeSecurityConstraintEQ
* Market node security constraints
  MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
* Mixed constraints
  Type1MixedConstraintMIP, Type1MixedConstraintLE_MIP, Type1MixedConstraintGE_MIP, Type1MixedConstraintEQ_MIP, Type2MixedConstraintLE, Type2MixedConstraintGE, Type2MixedConstraintEQ
* Generic constraints
  GenericSecurityConstraintLE, GenericSecurityConstraintGE, GenericSecurityConstraintEQ
* ViolationCost
  TotalViolationCostDefinition
* RDN - Generator island risk calculation considering more than one offer per generator
  GenIslandRiskCalculation_NonPS, GenIslandRiskCalculation_PS
  HVDCIslandSecRiskCalculation_GEN_NonPS, HVDCIslandSecRiskCalculation_GEN_PS
  / ;

Model VSPD_FTR /
*Objective function
ObjectiveFunction
*Offer and purchase definitions
GenerationOfferDefintion
*Network
HVDCLinkMaximumFlow, DCNodeNetInjection
ACNodeNetInjectionDefinition1, ACNodeNetInjectionDefinition2
ACBranchMaximumFlow, ACBranchFlowDefinition, LinearLoadFlow
*Branch security constraints
BranchSecurityConstraintLE
*ViolationCost
TotalViolationCostDefinition
/;