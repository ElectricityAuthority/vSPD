$ontext
===================================================================================
Name: VSPDModel.gms
Function: Mathematical formulation.  Based on the SPD model formulation v7.0
Developed by: Ramu Naidoo  (Electricity Authority, New Zealand)
Last modified: 16 Jan 2013
===================================================================================
$offtext

*===================================================================================
*Section 1: Fundamental sets and parameters
*===================================================================================
*Define the fundamental sets and parameters
*These form the basis of the subsequent sets and parameters that read in and created

SETS
*Global
i_Island(*)                              'Island definition'
i_DateTime(*)                            'Date and time for the trade periods'
i_TradePeriod(*)                         'Trade periods for which input data is defined'
i_TradeBlock(*)                          'Trade block definitions.  These are used for the offer and bid tranches'
i_LossSegment(*)                         'Loss segments available for loss modelling'
i_CVP(*)                                 'Constraint violation penalties used in the model'
i_FlowDirection(*)                       'Directional flow definition used in the formulation'
i_ConstraintRHS(*)                       'Constraint RHS definition'

*Offer
i_OfferType(*)                           'Type of energy and reserve offers from market participants'
i_OfferParam(*)                          'Different parameters specified for each offer'
i_Offer(*)                               'Offers for all trading periods'
i_Trader(*)                              'Traders defined for all the trading periods'
i_EnergyOfferComponent(*)                'Components of the energy offer comprising of block MW capacity and price'
i_PLSROfferComponent(*)                  'Components of the PLSR offer comprising of MW proportion, block MW and price'
i_TWDROfferComponent(*)                  'Components of the TWDR offer comprising of block MW and price'
i_ILROfferComponent(*)                   'Components of the ILR offer comprising of block MW and price'

*Bid
i_Bid(*)                                 'Bids for all the trading periods'
i_EnergyBidComponent(*)                  'Components of the energy bid comprising of the block MW capacity and the price'
i_ILRBidComponent(*)                     'Components of the ILR provided by bids'

*Network
i_Node(*)                                'Node definitions for all the trading periods'
i_Bus(*)                                 'Bus definitions for all the trading periods'
i_Branch(*)                              'Branch definition for all the trading periods'
i_BranchParameter(*)                     'Branch parameter specified'
i_LossParameter(*)                       'Components of the piecewise loss function'

*RDN - HVDC poles
i_Pole(*)                                'HVDC poles'

*Risk/reserve
i_ReserveClass(*)                        'Definition of fast and sustained instantaneous reserve'
i_ReserveType(*)                         'Definition of the different reserve types (PLSR, TWDR, ILR)'
i_RiskClass(*)                           'Different risks that could set the reserve requirements'
i_RiskParameter(*)                       'Different risk parameters that are specified as inputs to the dispatch model'

*Branch security constraint
i_BranchConstraint(*)                    'Branch constraint definitions for all the trading periods'

*AC node security constraint
i_ACNodeConstraint(*)                    'AC node constraint definitions for all the trading periods'

*Market node security constraint
i_MNodeConstraint(*)                     'Market node constraint definitions for all the trading periods'

*Mixed constraint
i_Type1MixedConstraint(*)                'Type 1 mixed constraint definitions for all the tradeing periods'
i_Type2MixedConstraint(*)                'Type 2 mixed constraint definitions for all the trading periods'
i_Type1MixedConstraintRHS(*)             'Type 1 mixed constraint RHS definitions'

*Generic constraint
i_GenericConstraint(*)                   'Generic constraint names for all the trading periods'
;

PARAMETERS
i_ACLineUnit                             '0 = Actual values, 1 = per unit values on a 100MVA base'
i_TradingPeriodLength                    'Length of the trading period in minutes (e.g. 30)'
i_CVPValues(*)                           'Values for the constraint violation penalties'
i_BranchReceivingEndLossProportion       'Proportion of losses to be allocated to the receiving end of a branch'
*Day, month and year inputs per GDX
i_Day                                    'Day number (1..31)'
i_Month                                  'Month number (1..12)'
i_Year                                   'Year number (1900..2200)'
;

*Some settings
SCALARS
i_UseReserveModel                        'Use the reserve model (1 = Yes)'
i_UseACBranchLimits                      'Use the AC branch limits (1 = Yes)'
i_UseHVDCBranchLimits                    'Use the HVDC branch limits (1 = Yes)'
i_UseMixedConstraint                     'Use the mixed constraint formulation (1 = Yes)'
i_ResolveCircularBranchFlows             'Resolve circular branch flows (1 = Yes)'
i_ResolveACNonPhysicalLosses             'Resolve nonphysical losses on AC branches (1 = Yes)'
i_ResolveHVDCNonPhysicalLosses           'Resolve nonphysical losses on HVDC branches (1 = Yes)'
*RDN - Introduced this flag to invoke the code that accounts for the specific application of the original mixed constraint formulation
i_UseMixedConstraintRiskOffset           'Use the risk offset calculation based on mixed constraint formulation (1= Yes)'
UsePrimSecGenRiskModel                   'Flag to use the revised generator risk model for generators with primary and secondary offers'
*RDN - Change to demand bid
UseDSBFDemandBidModel                    'Flag to use the demand model defined under demand-side bidding and forecasting (DSBF)'
*RDN - Change to demand bid - End
;

alias (Island,i_Island), (i_FromBus,i_Bus), (i_ToBus,i_Bus), (i_Bus1,i_Bus), (i_LossSegment1,i_LossSegment), (i_Branch,i_Branch1);
*RDN - Additional set alias
alias (i_Offer,i_Offer1);

*===================================================================================
*Section 2: Additional sets and parameters
*===================================================================================
*Define additional sets and parameters
*These are data sets for the study.  Typically defined over several trading periods.

SETS
*Model sets
i_DateTimeTradePeriodMap(i_DateTime,i_TradePeriod)                       'Mapping of date time set to the trade period set'

*Offer data
i_TradePeriodOfferTrader(i_TradePeriod,i_Offer,i_Trader)                 'Offers and the corresponding trader for the different trading periods'
i_TradePeriodOfferNode(i_TradePeriod,i_Offer,i_Node)                     'Offers and the corresponding offer node for the different trading periods'
*RDN - Additional set for primary secondary offers
i_TradePeriodPrimarySecondaryOffer(i_TradePeriod,i_Offer,i_Offer1)       'Primary-secondary offer mapping for the different trading periods'

*Bid data
i_TradePeriodBidTrader(i_TradePeriod,i_Bid,i_Trader)                     'Bids and the corresponding trader for the different trading periods'
i_TradePeriodBidNode(i_TradePeriod,i_Bid,i_Node)                         'Bids and the corresponding node for the different trading periods'

*Network data
i_TradePeriodNode(i_TradePeriod,i_Node)                                  'Node definition for the different trading periods'
i_TradePeriodBusIsland(i_TradePeriod,i_Bus,i_Island)                     'Bus island mapping for the different trade periods'
i_TradePeriodBus(i_TradePeriod,i_Bus)                                    'Bus definition for the different trading periods'
i_TradePeriodNodeBus(i_TradePeriod,i_Node,i_Bus)                         'Node bus mapping for the different trading periods'
i_TradePeriodBranchDefn(i_TradePeriod,i_Branch,i_FromBus,i_ToBus)        'Branch definition for the different trading periods'

*Reserve data
i_TradePeriodRiskGenerator(i_TradePeriod,i_Offer)                       'Set of generators (offers) that can set the risk in the different trading periods'

*Mixed constraint
i_Type1MixedConstraintReserveMap(i_Type1MixedConstraint,i_Island,i_ReserveClass,i_RiskClass)     'Mapping of mixed constraint variables to reserve-related data'
i_TradePeriodType1MixedConstraint(i_TradePeriod,i_Type1MixedConstraint)                          'Set of mixed constraints defined for the different trading periods'
i_TradePeriodType2MixedConstraint(i_TradePeriod,i_Type2MixedConstraint)                          'Set of mixed constraints defined for the different trading periods'
i_Type1MixedConstraintBranchCondition(i_Type1MixedConstraint,i_Branch)                           'Set of mixed constraints that have limits conditional on branch flows'

*Generic constraint data
i_TradePeriodGenericConstraint(i_TradePeriod,i_GenericConstraint)                                'Generic constraints defined for the different trading periods'
;

PARAMETERS
*Model parameters
i_StudyTradePeriod(i_TradePeriod)                                                        'Trade periods that are to be studied'

*Offer data
i_TradePeriodOfferParameter(i_TradePeriod,i_Offer,i_OfferParam)                          'InitialMW for each offer for the different trading periods'
i_TradePeriodEnergyOffer(i_TradePeriod,i_Offer,i_TradeBlock,i_EnergyOfferComponent)      'Energy offers for the different trading periods'
i_TradePeriodSustainedPLSROffer(i_TradePeriod,i_Offer,i_TradeBlock,i_PLSROfferComponent) 'Sustained (60s) PLSR offers for the different trading periods'
i_TradePeriodFastPLSROffer(i_TradePeriod,i_Offer,i_TradeBlock,i_PLSROfferComponent)      'Fast (6s) PLSR offers for the different trading periods'
i_TradePeriodSustainedTWDROffer(i_TradePeriod,i_Offer,i_TradeBlock,i_TWDROfferComponent) 'Sustained (60s) TWDR offers for the different trading periods'
i_TradePeriodFastTWDROffer(i_TradePeriod,i_Offer,i_TradeBlock,i_TWDROfferComponent)      'Fast (6s) TWDR offers for the different trading periods'
i_TradePeriodSustainedILROffer(i_TradePeriod,i_Offer,i_TradeBlock,i_ILROfferComponent)   'Sustained (60s) ILR offers for the different trading periods'
i_TradePeriodFastILROffer(i_TradePeriod,i_Offer,i_TradeBlock,i_ILROfferComponent)        'Fast (6s) ILR offers for the different trading periods'

i_TradePeriodReserveClassGenerationMaximum(i_TradePeriod,i_Offer,i_ReserveClass)         'MW used to determine factor to adjust maximum reserve of a reserve class'

*Demand data
i_TradePeriodNodeDemand(i_TradePeriod,i_Node)                                             'MW demand at each node for all trading periods'

*Bid data
i_TradePeriodEnergyBid(i_TradePeriod,i_Bid,i_TradeBlock,i_EnergyBidComponent)    'Energy bids for the different trading periods'
i_TradePeriodSustainedILRBid(i_TradePeriod,i_Bid,i_TradeBlock,i_ILRBidComponent) 'Sustained ILR bids for the different trading periods'
i_TradePeriodFastILRBid(i_TradePeriod,i_Bid,i_TradeBlock,i_ILRBidComponent)      'Fast ILR bids for the different trading periods'

*Network data
i_TradePeriodHVDCNode(i_TradePeriod,i_Node)                                      'HVDC node for the different trading periods'
i_TradePeriodReferenceNode(i_TradePeriod,i_Node)                                 'Reference nodes for the different trading periods'
i_TradePeriodHVDCBranch(i_TradePeriod,i_Branch)                                  'HVDC branch indicator for the different trading periods'
i_TradePeriodBranchParameter(i_TradePeriod,i_Branch,i_BranchParameter)           'Branch resistance, reactance, fixed losses and number of loss tranches for the different time periods'
i_TradePeriodBranchCapacity(i_TradePeriod,i_Branch)                              'Branch capacity for the different trading periods in MW'
i_TradePeriodBranchOpenStatus(i_TradePeriod,i_Branch)                            'Branch open status for the different trading periods, 1 = Open'
i_NoLossBranch(i_LossSegment,i_LossParameter)                                    'Loss parameters for no loss branches'
i_ACLossBranch(i_LossSegment,i_LossParameter)                                    'Loss parameters for AC loss branches'
i_HVDCLossBranch(i_LossSegment,i_LossParameter)                                  'Loss parameters for HVDC loss branches'
i_TradePeriodNodeBusAllocationFactor(i_TradePeriod,i_Node,i_Bus)                 'Allocation factor of market node quantities to bus for the different trading periods'
i_TradePeriodBusElectricalIsland(i_TradePeriod,i_Bus)                            'Electrical island status of each bus for the different trading periods (0 = Dead)'
*RDN - Flag to allow roundpower on the HVDC link
i_TradePeriodAllowHVDCRoundpower(i_TradePeriod)                                  'Flag to allow roundpower on the HVDC (1 = Yes)'

*Risk/Reserve data
i_TradePeriodRiskParameter(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass,i_RiskParameter)    'Risk parameters for the different trading periods (From RMT)'
i_TradePeriodManualRisk(i_TradePeriod,i_Island,i_ReserveClass)                                   'Manual risk set for the different trading periods'
*RDN - Manual ECE risk
i_TradePeriodManualRisk_ECE(i_TradePeriod,i_Island,i_ReserveClass)                               'Manual ECE risk set for the different trading periods'
*RDN - Additional input parameters for the HVDC secondary risk
i_TradePeriodHVDCSecRiskEnabled(i_TradePeriod,i_Island,i_RiskClass)                              'Flag indicating if the HVDC secondary risk is enabled (1 = Yes)'
i_TradePeriodHVDCSecRiskSubtractor(i_TradePeriod,i_Island)                                       'Ramp up capability on the HVDC pole that is not the secondary risk'

*Branch constraint data
i_TradePeriodBranchConstraintFactors(i_TradePeriod,i_BranchConstraint,i_Branch)                  'Branch constraint factors (sensitivities) for the different trading periods'
i_TradePeriodBranchConstraintRHS(i_TradePeriod,i_BranchConstraint,i_ConstraintRHS)               'Branch constraint sense and limit for the different trading periods'

*AC node constraint data
i_TradePeriodACNodeConstraintFactors(i_TradePeriod,i_ACNodeConstraint,i_Node)                    'AC node constraint factors (sensitivities) for the different trading periods'
i_TradePeriodACNodeConstraintRHS(i_TradePeriod,i_ACNodeConstraint,i_ConstraintRHS)               'AC node constraint sense and limit for the different trading periods'

*Market node constraint data
i_TradePeriodMNodeEnergyOfferConstraintFactors(i_TradePeriod,i_MNodeConstraint,i_Offer)                                  'Market node energy offer constraint factors for the different trading periods'
i_TradePeriodMNodeReserveOfferConstraintFactors(i_TradePeriod,i_MNodeConstraint,i_Offer,i_ReserveClass,i_ReserveType)    'Market node reserve offer constraint factors for the different trading periods'
i_TradePeriodMNodeEnergyBidConstraintFactors(i_TradePeriod,i_MNodeConstraint,i_Bid)                                      'Market node energy bid constraint factors for the different trading periods'
i_TradePeriodMNodeILReserveBidConstraintFactors(i_TradePeriod,i_MNodeConstraint,i_Bid,i_ReserveClass)                    'Market node IL reserve bid constraint factors for the different trading periods'
i_TradePeriodMNodeConstraintRHS(i_TradePeriod,i_MNodeConstraint,i_ConstraintRHS)                                         'Market node constraint sense and limit for the different trading periods'

*Mixed constraint data
i_Type1MixedConstraintVarWeight(i_Type1MixedConstraint)                                                                  'Type 1 mixed constraint variable weights'
i_Type1MixedConstraintGenWeight(i_Type1MixedConstraint,i_Offer)                                                          'Type 1 mixed constraint generator weights'
i_Type1MixedConstraintResWeight(i_Type1MixedConstraint,i_Offer,i_ReserveClass,i_ReserveType)                             'Type 1 mixed constraint reserve weights'
i_Type1MixedConstraintHVDCLineWeight(i_Type1MixedConstraint,i_Branch)                                                    'Type 1 mixed constraint HVDC branch flow weights'
i_TradePeriodType1MixedConstraintRHSParameters(i_TradePeriod,i_Type1MixedConstraint,i_Type1MixedConstraintRHS)           'Type 1 mixed constraint RHS parameters'
i_Type2MixedConstraintLHSParameters(i_Type2MixedConstraint,i_Type1MixedConstraint)                                       'Type 2 mixed constraint LHS weights'
i_TradePeriodType2MixedConstraintRHSParameters(i_TradePeriod,i_Type2MixedConstraint,i_ConstraintRHS)                     'Type 2 mixed constraint RHS parameters'
*Some additional mixed constraint paramaters
i_Type1MixedConstraintACLineWeight(i_Type1MixedConstraint,i_Branch)                                                      'Type 1 mixed constraint AC branch flow weights'
i_Type1MixedConstraintACLineLossWeight(i_Type1MixedConstraint,i_Branch)                                                  'Type 1 mixed constraint AC branch loss weights'
i_Type1MixedConstraintACLineFixedLossWeight(i_Type1MixedConstraint,i_Branch)                                             'Type 1 mixed constraint AC branch fixed losses weight'
i_Type1MixedConstraintHVDCLineLossWeight(i_Type1MixedConstraint,i_Branch)                                                'Type 1 mixed constraint HVDC branch loss weights'
i_Type1MixedConstraintHVDCLineFixedLossWeight(i_Type1MixedConstraint,i_Branch)                                           'Type 1 mixed constraint HVDC branch fixed losses weight'
i_Type1MixedConstraintPurWeight(i_Type1MixedConstraint,i_Bid)                                                            'Type 1 mixed constraint demand bid weights'

*Generic constraint data
i_TradePeriodGenericEnergyOfferConstraintFactors(i_TradePeriod,i_GenericConstraint,i_Offer)                                      'Generic constraint offer constraint factors for the different trading periods'
i_TradePeriodGenericReserveOfferConstraintFactors(i_TradePeriod,i_GenericConstraint,i_Offer,i_ReserveClass,i_ReserveType)        'Generic constraint reserve offer constraint factors for the different trading periods'
i_TradePeriodGenericEnergyBidConstraintFactors(i_TradePeriod,i_GenericConstraint,i_Bid)                                          'Generic constraint energy bid constraint factors for the different trading periods'
i_TradePeriodGenericILReserveBidConstraintFactors(i_TradePeriod,i_GenericConstraint,i_Bid,i_ReserveClass)                        'Generic constraint IL reserve bid constraint factors for the different trading periods'
i_TradePeriodGenericBranchConstraintFactors(i_TradePeriod,i_GenericConstraint,i_Branch)                                          'Generic constraint energy offer constraint factors for the different trading periods'
i_TradePeriodGenericConstraintRHS(i_TradePeriod,i_GenericConstraint,i_ConstraintRHS)                                             'Generic constraint sense and limit for the different trading periods'
;

*===================================================================================
*Section 3: Model level sets and parameters
*===================================================================================
*Define additional sets and parameters that are to be used in the model
*These would be created from the sets and parameters read in Section 1 and Section 2.

SETS
*Global
CurrentTradePeriod(i_TradePeriod)                                                                'Current trading period'

*Offer
Offer(i_TradePeriod,i_Offer)                                                                     'Offers defined for the current trading period'
OfferNode(i_TradePeriod,i_Offer,i_Node)                                                          'Mapping of the offers to the nodes for the current trading period'
ValidGenerationOfferBlock(i_TradePeriod,i_Offer,i_TradeBlock)                                    'Valid trade blocks for the respective generation offers'
ValidReserveOfferBlock(i_TradePeriod,i_Offer,i_TradeBlock,i_ReserveClass,i_ReserveType)          'Valid trade blocks for the respective reserve offers by class and type'
PreviousMW(i_Offer)                                                                              'MW output of offer to be used as initial MW of the next trading period if necessary'
PositiveEnergyOffer(i_TradePeriod,i_Offer)                                                       'Postive energy offers defined for the current trading period'
*RDN - Additional set for primary secondary offers
PrimarySecondaryOffer(i_TradePeriod,i_Offer,i_Offer1)                                            'Primary-secondary offer mapping for the current trading period'

*Bid
Bid(i_TradePeriod,i_Bid)                                                         'Bids defined for the current trading period'
BidNode(i_TradePeriod,i_Bid,i_Node)                                              'Mapping of the bids to the nodes for the current trading period'
ValidPurchaseBidBlock(i_TradePeriod,i_Bid,i_TradeBlock)                          'Valid trade blocks for the respective purchase bids'
ValidPurchaseBidILRBlock(i_TradePeriod,i_Bid,i_TradeBlock,i_ReserveClass)        'Valid trade blocks for the respective purchase bids ILR'

*Network
Node(i_TradePeriod,i_Node)                       'Nodes defined for the current trading period'
Bus(i_TradePeriod,i_Bus)                         'Buses defined for the current trading period'
NodeBus(i_TradePeriod,i_Node,i_Bus)              'Mapping of the nodes to the buses for the current trading period'
NodeIsland(i_TradePeriod,i_Node,i_Island)        'Mapping of the node to the island for the current trading period'
BusIsland(i_TradePeriod,i_Bus,i_Island)          'Mapping of the bus to the island for the current trading period'
HVDCNode(i_TradePeriod,i_Node)                   'HVDC node for the current trading period'
ACNode(i_TradePeriod,i_Node)                     'AC nodes for the current trading period'
ReferenceNode(i_TradePeriod,i_Node)              'Reference node for the current trading period'
DCBus(i_TradePeriod,i_Bus)                       'Buses corresponding to HVDC nodes'
ACBus(i_TradePeriod,i_Bus)                       'Buses corresponding to AC nodes'
Branch(i_TradePeriod,i_Branch)                                           'Branches defined for the current trading period'
BranchBusDefn(i_TradePeriod,i_Branch,i_FromBus,i_ToBus)                  'Branch bus connectivity for the current trading period'
BranchBusConnect(i_TradePeriod,i_Branch,i_Bus)                           'Indication if a branch is connected to a bus for the current trading period'
ACBranchSendingBus(i_TradePeriod,i_Branch,i_Bus,i_FlowDirection)         'Sending (From) bus of AC branch in forward and backward direction'
ACBranchReceivingBus(i_TradePeriod,i_Branch,i_Bus,i_FlowDirection)       'Receiving (To) bus of AC branch in forward and backward direction'
HVDCLinkSendingBus(i_TradePeriod,i_Branch,i_Bus)                         'Sending (From) bus of HVDC link'
HVDCLinkReceivingBus(i_TradePeriod,i_Branch,i_ToBus)                     'Receiving (To) bus of HVDC link'
HVDCLinkBus(i_TradePeriod,i_Branch,i_Bus)                                'Sending or Receiving bus of HVDC link'
HVDCLink(i_TradePeriod,i_Branch)                                         'HVDC links (branches) defined for the current trading period'
HVDCPoles(i_TradePeriod,i_Branch)                                        'DC transmission between Benmore and Hayward'
HVDCHalfPoles(i_TradePeriod,i_Branch)                                    'Connection DC Pole 1 between AC and DC systems at Benmore and Haywards'
HVDCPoleDirection(i_TradePeriod,i_Branch,i_FlowDirection)                'Direction defintion for HVDC poles S->N : Forward and N->S : Southward'
ACBranch(i_TradePeriod,i_Branch)                                         'AC branches defined for the current trading period'
ClosedBranch(i_TradePeriod,i_Branch)                                     'Set of branches that are closed'
OpenBranch(i_TradePeriod,i_Branch)                                       'Set of branches that are open'
ValidLossSegment(i_TradePeriod,i_Branch,i_LossSegment)                   'Valid loss segments for a branch'
LossBranch(i_TradePeriod,i_Branch)                                       'Subset of branches that have non-zero loss factors'
*RDN - Mapping set of branches to HVDC pole
HVDCPoleBranchMap(i_Pole,i_Branch)                                       'Mapping of HVDC  branch to pole number'

*Risk/Reserve
RiskGenerator(i_TradePeriod,i_Offer)                                     'Set of generators that can set the risk in the current trading period'
IslandRiskGenerator(i_TradePeriod,i_Island,i_Offer)                      'Mapping of risk generator to island in the current trading period'
HVDCRisk(i_RiskClass)                                                    'Subset containing DCCE and DCECE risks'
GenRisk(i_RiskClass)                                                     'Subset containing generator risks'
ManualRisk(i_RiskClass)                                                  'Subset containting manual risks'
*RDN - Allow for the HVDC secondary risks
HVDCSecRisk(i_RiskClass)                                                 'Subset containing secondary risk of the HVDC for CE and ECE events'

PLSRReserveType(i_ReserveType)                                           'PLSR reserve type'
ILReserveType(i_ReserveType)                                             'IL reserve type'
IslandOffer(i_TradePeriod,i_Island,i_Offer)                              'Mapping of reserve offer to island for the current trading period'
IslandBid(i_TradePeriod,i_Island,i_Bid)                                  'Mapping of purchase bid ILR to island for the current trading period'
*RDN - Definition of CE and ECE events to support different CE and ECE CVPs
ContingentEvents(i_RiskClass)                                            'Subset of Risk Classes containing contigent event risks'
ExtendedContingentEvent(i_RiskClass)                                     'Subset of Risk Classes containing extended contigent event risk'

*Branch constraint
BranchConstraint(i_TradePeriod,i_BranchConstraint)                       'Set of branch constraints defined for the current trading period'

*AC node constraint
ACNodeConstraint(i_TradePeriod,i_ACNodeConstraint)                       'Set of AC node constraints defined for the current trading period'

*Market node constraint
MNodeConstraint(i_TradePeriod,i_MNodeConstraint)                         'Set of market node constraints defined for the current trading period'

*Mixed constraint
Type1MixedConstraint(i_TradePeriod,i_Type1MixedConstraint)               'Set of type 1 mixed constraints defined for the current trading period'
Type2MixedConstraint(i_TradePeriod,i_Type2MixedConstraint)               'Set of type 2 mixed constraints defined for the current trading period'
Type1MixedConstraintCondition(i_TradePeriod,i_Type1MixedConstraint)      'Subset of type 1 mixed constraints that have a condition to check for the use of the alternate limit'

*Generic constraint
GenericConstraint(i_TradePeriod,i_GenericConstraint)                     'Generic constraint defined for the current trading period'
;

PARAMETERS
*Offers
RampRateUp(i_TradePeriod,i_Offer)                'The ramping up rate in MW per minute associated with the generation offer (MW/min)'
RampRateDown(i_TradePeriod,i_Offer)              'The ramping down rate in MW per minute associated with the generation offer (MW/min)'
GenerationStart(i_TradePeriod,i_Offer)           'The MW generation level associated with the offer at the start of a trading period'
ReserveGenerationMaximum(i_TradePeriod,i_Offer)  'Maximum generation and reserve capability for the current trading period (MW)'
WindOffer(i_TradePeriod,i_Offer)                 'Flag to indicate if offer is from wind generator (1 = Yes)'
*RDN - Primary-secondary offer parameters
HasSecondaryOffer(i_TradePeriod,i_Offer)        'Flag to indicate if offer has a secondary offer (1 = Yes)'
HasPrimaryOffer(i_TradePeriod,i_Offer)          'Flag to indicate if offer has a primary offer (1 = Yes)'
*RDN - Frequency keeper band MW
FKBand(i_TradePeriod,i_Offer)                   'Frequency keeper band MW which is set when the risk setter is selected as the frequency keeper'

GenerationMaximum(i_TradePeriod,i_Offer)                       'Maximum generation level associated with the generation offer (MW)'
GenerationMinimum(i_TradePeriod,i_Offer)                       'Minimum generation level associated with the generation offer (MW)'
GenerationEndUp(i_TradePeriod,i_Offer)                         'MW generation level associated with the offer at the end of the trading period assuming ramp rate up'
GenerationEndDown(i_TradePeriod,i_Offer)                       'MW generation level associated with the offer at the end of the trading period assuming ramp rate down'
RampTimeUp(i_TradePeriod,i_Offer)                              'Minimum of the trading period length and time to ramp up to maximum (Minutes)'
RampTimeDown(i_TradePeriod,i_Offer)                            'Minimum of the trading period length and time to ramp down to minimum (Minutes)'

*Energy offer
GenerationOfferMW(i_TradePeriod,i_Offer,i_TradeBlock)          'Generation offer block (MW)'
GenerationOfferPrice(i_TradePeriod,i_Offer,i_TradeBlock)       'Generation offer price ($/MW)'

*Reserve offer
ReserveOfferProportion(i_TradePeriod,i_Offer,i_TradeBlock,i_ReserveClass)                'The percentage of the MW block available for PLSR of class FIR or SIR'
ReserveOfferPrice(i_TradePeriod,i_Offer,i_TradeBlock,i_ReserveClass,i_ReserveType)       'The price of the reserve of the different reserve classes and types ($/MW)'
ReserveOfferMaximum(i_TradePeriod,i_Offer,i_TradeBlock,i_ReserveClass,i_ReserveType)     'The maximum MW offered reserve for the different reserve classes and types (MW)'

*Demand
NodeDemand(i_TradePeriod,i_Node)                                                         'Nodal demand for the current trading period in MW'

*Bid
PurchaseBidMW(i_TradePeriod,i_Bid,i_TradeBlock)                                          'Purchase bid block in MW'
PurchaseBidPrice(i_TradePeriod,i_Bid,i_TradeBlock)                                       'Purchase bid price in $/MW'
PurchaseBidILRMW(i_TradePeriod,i_Bid,i_TradeBlock,i_ReserveClass)                        'Purchase bid ILR block in MW for the different reserve classes'
PurchaseBidILRPrice(i_TradePeriod,i_Bid,i_TradeBlock,i_ReserveClass)                     'Purchase bid ILR price in $/MW for the different reserve classes'

*Network
ACBranchCapacity(i_TradePeriod,i_Branch)                       'MW capacity of AC branch for the current trading period'
ACBranchResistance(i_TradePeriod,i_Branch)                     'Resistance of the AC branch for the current trading period in per unit'
ACBranchSusceptance(i_TradePeriod,i_Branch)                    'Susceptance (inverse of reactance) of the AC branch for the current trading period in per unit'
ACBranchFixedLoss(i_TradePeriod,i_Branch)                      'Fixed loss of the AC branch for the current trading period in MW'
ACBranchLossBlocks(i_TradePeriod,i_Branch)                     'Number of blocks in the loss curve for the AC branch in the current trading period'
ACBranchLossMW(i_TradePeriod,i_Branch,i_LossSegment)           'MW element of the loss segment curve in MW'
ACBranchLossFactor(i_TradePeriod,i_Branch,i_LossSegment)       'Loss factor element of the loss segment curve'
ACBranchOpenStatus(i_TradePeriod,i_Branch)                     'Flag indicating if the AC branch is open (1 = Open)'
ACBranchClosedStatus(i_TradePeriod,i_Branch)                   'Flag indicating if the AC branch is closed (1 = Closed)'

HVDCLinkCapacity(i_TradePeriod,i_Branch)                       'MW capacity of the HVDC link for the current trading period'
HVDCLinkResistance(i_TradePeriod,i_Branch)                     'Resistance of the HVDC link for the current trading period in Ohms'
HVDCLinkFixedLoss(i_TradePeriod,i_Branch)                      'Fixed loss of the HVDC link for the current trading period in MW'
HVDCLinkLossBlocks(i_TradePeriod,i_Branch)                     'Number of blocks in the loss curve for the HVDC link in the current trading period'
HVDCBreakPointMWFlow(i_TradePeriod,i_Branch,i_LossSegment)     'Value of power flow on the HVDC at the break point'
HVDCBreakPointMWLoss(i_TradePeriod,i_Branch,i_LossSegment)     'Value of variable losses on the HVDC at the break point'
HVDCLinkOpenStatus(i_TradePeriod,i_Branch)                     'Flag indicating if the HVDC link is open (1 = Open)'
HVDCLinkClosedStatus(i_TradePeriod,i_Branch)                   'Flag indicating if the HVDC link is closed (1 = Closed)'

LossSegmentMW(i_TradePeriod,i_Branch,i_LossSegment)            'MW capacity of each loss segment'
LossSegmentFactor(i_TradePeriod,i_Branch,i_LossSegment)        'Loss factor of each loss segment'

NodeBusAllocationFactor(i_TradePeriod,i_Node,i_Bus)            'Allocation factor of market node to bus for the current trade period'
BusElectricalIsland(i_TradePeriod,i_Bus)                       'Bus electrical island status for the current trade period (0 = Dead)'

*RDN - Flag to allow roundpower on the HVDC link
AllowHVDCRoundpower(i_TradePeriod)                             'Flag to allow roundpower on the HVDC (1 = Yes)'


*Risk/Reserve
ReserveClassGenerationMaximum(i_TradePeriod,i_Offer,i_ReserveClass)              'MW used to determine factor to adjust maximum reserve of a reserve class'
ReserveMaximumFactor(i_TradePeriod,i_Offer,i_ReserveClass)                       'Factor to adjust the maximum reserve of the different classes for the different offers'
IslandRiskAdjustmentFactor(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)    'Risk adjustment factor for each island, reserve class and risk class'
FreeReserve(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)                   'MW free reserve for each island, reserve class and risk class'
HVDCPoleRampUp(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)                'HVDC pole MW ramp up capability for each island, reserve class and risk class'
*RDN - Index IslandMinimumRisk to cater for CE and ECE minimum risk
*IslandMinimumRisk(i_TradePeriod,i_Island,i_ReserveClass)                         'Minimum MW risk level for each island for each reserve class'
IslandMinimumRisk(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)              'Minimum MW risk level for each island for each reserve class and risk class'

*RDN - HVDC secondary risk parameters
HVDCSecRiskEnabled(i_TradePeriod,i_Island,i_RiskClass)                            'Flag indicating if the HVDC secondary risk is enabled (1 = Yes)'
HVDCSecRiskSubtractor(i_TradePeriod,i_Island)                                     'Ramp up capability on the HVDC pole that is not the secondary risk'
HVDCSecIslandMinimumRisk(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)       'Minimum risk in each island for the HVDC secondary risk'

*Branch constraint
BranchConstraintFactors(i_TradePeriod,i_BranchConstraint,i_Branch)     'Branch security constraint factors (sensitivities) for the current trading period'
BranchConstraintSense(i_TradePeriod,i_BranchConstraint)                'Branch security constraint sense for the current trading period (-1:<=, 0:= 1:>=)'
BranchConstraintLimit(i_TradePeriod,i_BranchConstraint)                'Branch security constraint limit for the current trading period'

*AC node constraint
ACNodeConstraintFactors(i_TradePeriod,i_ACNodeConstraint,i_Node)       'AC node security constraint factors (sensitivities) for the current trading period'
ACNodeConstraintSense(i_TradePeriod,i_ACNodeConstraint)                'AC node security constraint sense for the current trading period (-1:<=, 0:= 1:>=)'
ACNodeConstraintLimit(i_TradePeriod,i_ACNodeConstraint)                'AC node security constraint limit for the current trading period'

*Market node constraint
MNodeEnergyOfferConstraintFactors(i_TradePeriod,i_MNodeConstraint,i_Offer)                                     'Market node energy offer constraint factors for the current trading period'
MNodeReserveOfferConstraintFactors(i_TradePeriod,i_MNodeConstraint,i_Offer,i_ReserveClass,i_ReserveType)       'Market node reserve offer constraint factors for the current trading period'
MNodeEnergyBidConstraintFactors(i_TradePeriod,i_MNodeConstraint,i_Bid)                                         'Market node energy bid constraint factors for the current trading period'
MNodeILReserveBidConstraintFactors(i_TradePeriod,i_MNodeConstraint,i_Bid,i_ReserveClass)                       'Market node IL reserve bid constraint factors for the current trading period'
MNodeConstraintSense(i_TradePeriod,i_MNodeConstraint)                                                          'Market node constraint sense for the current trading period'
MNodeConstraintLimit(i_TradePeriod,i_MNodeConstraint)                                                          'Market node constraint limit for the current trading period'

*Mixed constraint
UseMixedConstraint(i_TradePeriod)                                      'Flag indicating use of the mixed constraint formulation (1 = Yes)'
Type1MixedConstraintSense(i_TradePeriod,i_Type1MixedConstraint)        'Type 1 mixed constraint sense'
Type1MixedConstraintLimit1(i_TradePeriod,i_Type1MixedConstraint)       'Type 1 mixed constraint limit 1'
Type1MixedConstraintLimit2(i_TradePeriod,i_Type1MixedConstraint)       'Type 1 mixed constraint alternate limit (limit 2)'
Type2MixedConstraintSense(i_TradePeriod,i_Type2MixedConstraint)        'Type 2 mixed constraint sense'
Type2MixedConstraintLimit(i_TradePeriod,i_Type2MixedConstraint)        'Type 2 mixed constraint limit'

*Generic constraint
GenericEnergyOfferConstraintFactors(i_TradePeriod,i_GenericConstraint,i_Offer)                                     'Generic constraint energy offer factors for the current trading period'
GenericReserveOfferConstraintFactors(i_TradePeriod,i_GenericConstraint,i_Offer,i_ReserveClass,i_ReserveType)       'Generic constraint reserve offer factors for the current trading period'
GenericEnergyBidConstraintFactors(i_TradePeriod,i_GenericConstraint,i_Bid)                                         'Generic constraint energy bid factors for the current trading period'
GenericILReserveBidConstraintFactors(i_TradePeriod,i_GenericConstraint,i_Bid,i_ReserveClass)                       'Generic constraint IL reserve bid factors for the current trading period'
GenericBranchConstraintFactors(i_TradePeriod,i_GenericConstraint,i_Branch)                                         'Generic constraint branch factors for the current trading period'
GenericConstraintSense(i_TradePeriod,i_GenericConstraint)                                                          'Generic constraint sense for the current trading period'
GenericConstraintLimit(i_TradePeriod,i_GenericConstraint)                                                          'Generic constraint limit for the current trading period'

*Violation penalties
DeficitReservePenalty(i_ReserveClass)                                  '6s and 60s reserve deficit violation penalty'
*RDN - Different CVPs defined for CE and ECE
DeficitReservePenalty_CE(i_ReserveClass)                               '6s and 60s CE reserve deficit violation penalty'
DeficitReservePenalty_ECE(i_ReserveClass)                              '6s and 60s ECE reserve deficit violation penalty'


*Post-processing
UseBranchFlowMIP(i_TradePeriod)                                        'Flag to indicate if integer constraints are needed in the branch flow model: 1 = Yes'
UseMixedConstraintMIP(i_TradePeriod)                                   'Flag to indicate if integer constraints are needed in the mixed constraint formulation: 1 = Yes'
;

SCALARS
*Volation penalties
*These violation penalties are not specified in the model formulation document (ver.4.3) but are specified in the
*document "Resolving Infeasibilities & High Spring Washer Price situations - an overview" available at www.systemoperator.co.nz/n2766,264.html

DeficitBusGenerationPenalty                      'Bus deficit violation penalty'
SurplusBusGenerationPenalty                      'Bus surplus violation penalty'
DeficitBranchGroupConstraintPenalty              'Deficit branch group constraint violation penalty'
SurplusBranchGroupConstraintPenalty              'Surplus branch group constraint violation penalty'
DeficitGenericConstraintPenalty                  'Deficit generic constraint violation penalty'
SurplusGenericConstraintPenalty                  'Surplus generic constraint violation penalty'
DeficitRampRatePenalty                           'Deficit ramp rate violation penalty'
SurplusRampRatePenalty                           'Surplus ramp rate violation penalty'
DeficitACNodeConstraintPenalty                   'AC node constraint deficit penalty'
SurplusACNodeConstraintPenalty                   'AC node constraint surplus penalty'
DeficitBranchFlowPenalty                         'Deficit branch flow violation penalty'
SurplusBranchFlowPenalty                         'Surplus branch flow violation penalty'
DeficitMnodeConstraintPenalty                    'Deficit market node constraint violation penalty'
SurplusMnodeConstraintPenalty                    'Surplus market node constraint violation penalty'
Type1DeficitMixedConstraintPenalty               'Type 1 deficit mixed constraint violation penalty'
Type1SurplusMixedConstraintPenalty               'Type 1 surplus mixed constraint violation penalty'

*Mixed constraint
MixedConstraintBigNumber                         'Big number used in the definition of the integer variables for mixed constraints'   /1000/

*RDN - Separate flag for the CE and ECE CVP
DiffCeECeCVP                                     'Flag to indicate if the separate CE and ECE CVP is applied'
;

*===================================================================================
*Section 4: Define model variables and constraints
*===================================================================================
*Model formulation based on the SPD model formulation version 4.3 (15 Feb 2008)

VARIABLES
NETBENEFIT                                                                       'Defined as the difference between the consumer surplus and producer costs adjusted for penalty costs'

*Reserves
ISLANDRISK(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)                    'Island MW risk for the different reserve and risk classes'
HVDCREC(i_TradePeriod,i_Island)                                                  'Total net pre-contingent HVDC MW flow received at each island'
RISKOFFSET(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)                    'MW offset applied to the raw risk to account for HVDC pole rampup, AUFLS, free reserve and non-compliant generation'

*Network
ACNODENETINJECTION(i_TradePeriod,i_Bus)                                          'MW injection at buses corresponding to AC nodes'
ACBRANCHFLOW(i_TradePeriod,i_Branch)                                             'MW flow on undirected AC branch'
ACNODEANGLE(i_TradePeriod,i_Bus)                                                 'Bus voltage angle'

*Mixed constraint variables
MIXEDCONSTRAINTVARIABLE(i_TradePeriod,i_Type1MixedConstraint)                    'Mixed constraint variable'

*RDN - Change to demand bids
*Demand bids were only positive but can be both positive and negative from v6.0 of SPD formulation (with DSBF)
*This change will be managed with the update of the lower bound of the free variable in vSPDSolve.gms to allow
*backward compatibility
*Note the formulation now refers to this as Demand. So Demand (in SPD formulation) = Purchase (in vSPD code)
PURCHASE(i_TradePeriod,i_Bid)                                                    'Total MW purchase scheduled'
PURCHASEBLOCK(i_TradePeriod,i_Bid,i_TradeBlock)                                  'MW purchase scheduled from the individual trade blocks of a bid'
*RDN - Change to demand bids - End
;

POSITIVE VARIABLES
*Generation
GENERATION(i_TradePeriod,i_Offer)                                                'Total MW generation scheduled from an offer'
GENERATIONBLOCK(i_TradePeriod,i_Offer,i_TradeBlock)                              'MW generation scheduled from the individual trade blocks of an offer'

*Purchase
*PURCHASE(i_TradePeriod,i_Bid)                                                    'Total MW purchase scheduled'
*PURCHASEBLOCK(i_TradePeriod,i_Bid,i_TradeBlock)                                  'MW purchase scheduled from the individual trade blocks of a bid'
PURCHASEILR(i_TradePeriod,i_Bid,i_ReserveClass)                                  'Total MW ILR provided by purchase bid for the different reserve classes'
PURCHASEILRBLOCK(i_TradePeriod,i_Bid,i_TradeBlock,i_ReserveClass)                'MW ILR provided by purchase bid for individual trade blocks for the different reserve classes'

*Reserve
RESERVE(i_TradePeriod,i_Offer,i_ReserveClass,i_ReserveType)                      'MW Reserve scheduled from an offer'
RESERVEBLOCK(i_TradePeriod,i_Offer,i_TradeBlock,i_ReserveClass,i_ReserveType)    'MW Reserve scheduled from the individual trade blocks of an offer'
MAXISLANDRISK(i_TradePeriod,i_Island,i_ReserveClass)                             'Maximum MW island risk for the different reserve classes'

*Network
HVDCLINKFLOW(i_TradePeriod,i_Branch)                                                     'MW flow at the sending end scheduled for the HVDC link'
HVDCLINKLOSSES(i_TradePeriod,i_Branch)                                                   'MW losses on the HVDC link'
LAMBDA(i_TradePeriod,i_Branch,i_LossSegment)                                             'Non-negative weight applied to the breakpoint of the HVDC link'
ACBRANCHFLOWDIRECTED(i_TradePeriod,i_Branch,i_FlowDirection)                             'MW flow on the directed branch'
ACBRANCHLOSSESDIRECTED(i_TradePeriod,i_Branch,i_FlowDirection)                           'MW losses on the directed branch'
ACBRANCHFLOWBLOCKDIRECTED(i_TradePeriod,i_Branch,i_LossSegment,i_FlowDirection)          'MW flow on the different blocks of the loss curve'
ACBRANCHLOSSESBLOCKDIRECTED(i_TradePeriod,i_Branch,i_LossSegment,i_FlowDirection)        'MW losses on the different blocks of the loss curve'

*Violations
TOTALPENALTYCOST                                                                 'Total violation costs'
DEFICITBUSGENERATION(i_TradePeriod,i_Bus)                                        'Deficit generation at a bus in MW'
SURPLUSBUSGENERATION(i_TradePeriod,i_Bus)                                        'Surplus generation at a bus in MW'
DEFICITRESERVE(i_TradePeriod,i_Island,i_ReserveClass)                            'Deficit reserve generation in each island for each reserve class in MW'
DEFICITBRANCHSECURITYCONSTRAINT(i_TradePeriod,i_BranchConstraint)                'Deficit branch security constraint in MW'
SURPLUSBRANCHSECURITYCONSTRAINT(i_TradePeriod,i_BranchConstraint)                'Surplus branch security constraint in MW'
DEFICITRAMPRATE(i_TradePeriod,i_Offer)                                           'Deficit ramp rate in MW'
SURPLUSRAMPRATE(i_TradePeriod,i_Offer)                                           'Surplus ramp rate in MW'
DEFICITACNODECONSTRAINT(i_TradePeriod,i_ACNodeConstraint)                        'Deficit in AC node constraint in MW'
SURPLUSACNODECONSTRAINT(i_TradePeriod,i_ACNodeConstraint)                        'Surplus in AC node constraint in MW'
DEFICITBRANCHFLOW(i_TradePeriod,i_Branch)                                        'Deficit branch flow in MW'
SURPLUSBRANCHFLOW(i_TradePeriod,i_Branch)                                        'Surplus branch flow in MW'
DEFICITMNODECONSTRAINT(i_TradePeriod,i_MNodeConstraint)                          'Deficit market node constraint in MW'
SURPLUSMNODECONSTRAINT(i_TradePeriod,i_MNodeConstraint)                          'Surplus market node constraint in MW'
DEFICITTYPE1MIXEDCONSTRAINT(i_TradePeriod,i_Type1MixedConstraint)                'Type 1 deficit mixed constraint in MW'
SURPLUSTYPE1MIXEDCONSTRAINT(i_TradePeriod,i_Type1MixedConstraint)                'Type 1 surplus mixed constraint in MW'
SURPLUSGENERICCONSTRAINT(i_TradePeriod,i_GenericConstraint)                      'Surplus generic constraint in MW'
DEFICITGENERICCONSTRAINT(i_TradePeriod,i_GenericConstraint)                      'Deficit generic constraint in MW'
*RDN - Seperate CE and ECE violation variables to support different CVPs for CE and ECE
DEFICITRESERVE_CE(i_TradePeriod,i_Island,i_ReserveClass)                         'Deficit CE reserve generation in each island for each reserve class in MW'
DEFICITRESERVE_ECE(i_TradePeriod,i_Island,i_ReserveClass)                        'Deficit ECE reserve generation in each island for each reserve class in MW'
;

BINARY VARIABLES
MIXEDCONSTRAINTLIMIT2SELECT(i_TradePeriod,i_Type1MixedConstraint)              'Binary decision variable used to detect if limit 2 should be selected for mixed constraints'
;

SOS1 VARIABLES
ACBRANCHFLOWDIRECTED_INTEGER(i_TradePeriod,i_Branch,i_FlowDirection)           'Integer variables used to select branch flow direction in the event of circular branch flows (3.8.1)'
HVDCLINKFLOWDIRECTION_INTEGER(i_TradePeriod,i_FlowDirection)                   'Integer variables used to select the HVDC branch flow direction on in the event of S->N (forward) and N->S (reverse) flows (3.8.2)'
*RDN - Integer varaible to prevent intra-pole circulating branch flows
HVDCPOLEFLOW_INTEGER(i_TradePeriod,i_Pole,i_FlowDirection)                     'Integer variables used to select the HVDC pole flow direction on in the event of circulating branch flows within a pole'
;

SOS2 VARIABLES
LAMBDAINTEGER(i_TradePeriod,i_Branch,i_LossSegment)                            'Integer variables used to enforce the piecewise linear loss approxiamtion on the HVDC links'
;

EQUATIONS
ObjectiveFunction                                                              'Objective function of the dispatch model (4.1.1.1)'
*Offer and purchase definitions
GenerationOfferDefintion(i_TradePeriod,i_Offer)                                'Definition of generation provided by an offer (3.1.1.2)'
GenerationRampUp(i_TradePeriod,i_Offer)                                        'Maximum movement of the generator upwards due to up ramp rate (3.7.1.1)'
GenerationRampDown(i_TradePeriod,i_Offer)                                      'Maximum movement of the generator downwards due to down ramp rate (3.7.1.2)'
*RDN - Primary-secondary ramp constraints
GenerationRampUp_PS(i_TradePeriod,i_Offer)                                     'Maximum movement of the primary-secondary offers upwards due to up ramp rate (3.7.1.1)'
GenerationRampDown_PS(i_TradePeriod,i_Offer)                                   'Maximum movement of the primary-secondary offers downwards due to down ramp rate (3.7.1.2)'

*RDN - Change to demand bids
*PurchaseBidDefintion(i_TradePeriod,i_Bid)                                      'Definition of purchase provided by a bid (3.1.1.4)'
PurchaseBidDefintion(i_TradePeriod,i_Bid)                                      'Definition of purchase provided by a bid (3.1.1.5)'
*RDN - Change to demand bids - End

*Network
HVDCLinkMaximumFlow(i_TradePeriod,i_Branch)                                    'Maximum flow on each HVDC link (3.2.1.1)'
HVDCLinkLossDefinition(i_TradePeriod,i_Branch)                                 'Definition of losses on the HVDC link (3.2.1.2)'
HVDCLinkFlowDefinition(i_TradePeriod,i_Branch)                                 'Definition of MW flow on the HVDC link (3.2.1.3)'
HVDCLinkFlowIntegerDefinition1(i_TradePeriod)                                  'Definition of the integer HVDC link flow variable (3.8.2a)'
HVDCLinkFlowIntegerDefinition2(i_TradePeriod,i_FlowDirection)                  'Definition of the integer HVDC link flow variable (3.8.2b)'
*RDN - Additional constraints for the intra-pole circulating branch flows
HVDCLinkFlowIntegerDefinition3(i_TradePeriod,i_Pole)                           'Definition of the HVDC pole integer varaible to prevent intra-pole circulating branch flows (3.8.2c)'
HVDCLinkFlowIntegerDefinition4(i_TradePeriod,i_Pole,i_FlowDirection)           'Definition of the HVDC pole integer varaible to prevent intra-pole circulating branch flows (3.8.2d)'

LambdaDefinition(i_TradePeriod,i_Branch)                                       'Definition of weighting factor (3.2.1.4)'

LambdaIntegerDefinition1(i_TradePeriod,i_Branch)                               'Definition of weighting factor when branch integer constraints are needed (3.8.3a)'
LambdaIntegerDefinition2(i_TradePeriod,i_Branch,i_LossSegment)                 'Definition of weighting factor when branch integer constraints are needed (3.8.3b)'

DCNodeNetInjection(i_TradePeriod,i_Bus)                                        'Definition of the net injection at buses corresponding to HVDC nodes (3.2.1.6)'
ACNodeNetInjectionDefinition1(i_TradePeriod,i_Bus)                             '1st definition of the net injection at buses corresponding to AC nodes (3.3.1.1)'
ACNodeNetInjectionDefinition2(i_TradePeriod,i_Bus)                             '2nd definition of the net injection at buses corresponding to AC nodes (3.3.1.2)'
ACBranchMaximumFlow(i_TradePeriod,i_Branch,i_FlowDirection)                    'Maximum flow on the AC branch (3.3.1.3)'
ACBranchFlowDefinition(i_TradePeriod,i_Branch)                                 'Relationship between directed and undirected branch flow variables (3.3.1.4)'
LinearLoadFlow(i_TradePeriod,i_Branch)                                         'Equation that describes the linear load flow (3.3.1.5)'
ACBranchBlockLimit(i_TradePeriod,i_Branch,i_LossSegment,i_FlowDirection)       'Limit on each AC branch flow block (3.3.1.6)'
ACDirectedBranchFlowDefinition(i_TradePeriod,i_Branch,i_FlowDirection)         'Composition of the directed branch flow from the block branch flow (3.3.1.7)'
ACBranchLossCalculation(i_TradePeriod,i_Branch,i_LossSegment,i_FlowDirection)  'Calculation of the losses in each loss segment (3.3.1.8)'
ACDirectedBranchLossDefinition(i_TradePeriod,i_Branch,i_FlowDirection)         'Composition of the directed branch losses from the block branch losses (3.3.1.9)'

ACDirectedBranchFlowIntegerDefinition1(i_TradePeriod,i_Branch)                 'Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1a)'
ACDirectedBranchFlowIntegerDefinition2(i_TradePeriod,i_Branch,i_FlowDirection) 'Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1b)'

*Risk and Reserve
HVDCIslandRiskCalculation(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)                     'Calculation of the island risk for a DCCE and DCECE (3.4.1.1)'
HVDCRecCalculation(i_TradePeriod,i_Island)                                                       'Calculation of the net received HVDC MW flow into an island (3.4.1.5)'
GenIslandRiskCalculation(i_TradePeriod,i_Island,i_Offer,i_ReserveClass,i_RiskClass)              'Calculation of the island risk for risk setting generators (3.4.1.6)'
ManualIslandRiskCalculation(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)                   'Calculation of the island risk based on manual specifications (3.4.1.7)'
PLSRReserveProportionMaximum(i_TradePeriod,i_Offer,i_TradeBlock,i_ReserveClass,i_ReserveType)    'Maximum PLSR as a proportion of the block MW (3.4.2.1)'
ReserveOfferDefinition(i_TradePeriod,i_Offer,i_ReserveClass,i_ReserveType)                       'Definition of the reserve offers of different classes and types (3.4.2.3a)'
ReserveDefinitionPurchaseBid(i_TradePeriod,i_Bid,i_ReserveClass)                                 'Definition of the ILR reserve provided by purchase bids (3.4.2.3b)'
EnergyAndReserveMaximum(i_TradePeriod,i_Offer,i_ReserveClass)                                    'Definition of maximum energy and reserves from each generator (3.4.2.4)'
PurchaseBidReserveMaximum(i_TradePeriod,i_Bid,i_ReserveClass)                                    'Maximum ILR provided by purchase bids (3.4.2.5)'
MaximumIslandRiskDefinition(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)                   'Definition of the maximum risk in each island (3.4.3.1)'
SupplyDemandReserveRequirement(i_TradePeriod,i_Island,i_ReserveClass)                            'Matching of reserve supply and demand (3.4.3.2)'

*RDN - Risk calculation for generators with more than one offer - Primary and secondary offers
GenIslandRiskCalculation_NonPS(i_TradePeriod,i_Island,i_Offer,i_ReserveClass,i_RiskClass)        'Calculation of the island risk for risk setting generators with only one offer (3.4.1.6)'
GenIslandRiskCalculation_PS(i_TradePeriod,i_Island,i_Offer,i_ReserveClass,i_RiskClass)           'Calculation of the island risk for risk setting generators with more than one offer (3.4.1.6)'

*RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
*RiskOffSetCalculationApproximation(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)            'Approximate calculation of the risk offset variable.  This will be used when the i_UseMixedConstraint flag is false'
RiskOffsetCalculation_DCCE(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)                    'Calculation of the risk offset variable for the DCCE risk class.  This will be used when the i_UseMixedConstraint flag is false (3.4.1.2)'
RiskOffsetCalculation_DCECE(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)                   'Calculation of the risk offset variable for the DCECE risk class.  This will be used when the i_UseMixedConstraint flag is false (3.4.1.4)'

RiskOffsetCalculation(i_TradePeriod,i_Type1MixedConstraint,i_Island,i_ReserveClass,i_RiskClass)  'Risk offset definition. This will be used when the i_UseMixedConstraint flag is true (3.4.1.5 - v4.4)'

*RDN - Need to seperate the maximum island risk definition constraint to support the different CVPs defined for CE and ECE
MaximumIslandRiskDefinition_CE(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)                'Definition of the maximum CE risk in each island (3.4.3.1a)'
MaximumIslandRiskDefinition_ECE(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)               'Definition of the maximum ECE risk in each island (3.4.3.1b)'

*RDN - HVDC secondary risk calculation
HVDCIslandSecRiskCalculation_GEN(i_TradePeriod,i_Island,i_Offer,i_ReserveClass,i_RiskClass)  'Calculation of the island risk for an HVDC secondary risk to an AC risk (3.4.1.8)'
HVDCIslandSecRiskCalculation_Manual(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass)            'Calculation of the island risk for an HVDC secondary risk to a manual risk (3.4.1.9)'

*RDN - HVDC secondary risk calculation for generators with more than one offer - Primary and secondary offers
HVDCIslandSecRiskCalculation_GEN_NonPS(i_TradePeriod,i_Island,i_Offer,i_ReserveClass,i_RiskClass)
HVDCIslandSecRiskCalculation_GEN_PS(i_TradePeriod,i_Island,i_Offer,i_ReserveClass,i_RiskClass)

*Branch security constraints
BranchSecurityConstraintLE(i_TradePeriod,i_BranchConstraint)                           'Branch security constraint with LE sense (3.5.1.5a)'
BranchSecurityConstraintGE(i_TradePeriod,i_BranchConstraint)                           'Branch security constraint with GE sense (3.5.1.5b)'
BranchSecurityConstraintEQ(i_TradePeriod,i_BranchConstraint)                           'Branch security constraint with EQ sense (3.5.1.5c)'

*AC node security constraints
ACNodeSecurityConstraintLE(i_TradePeriod,i_ACNodeConstraint)                           'AC node security constraint with LE sense (3.5.1.6a)'
ACNodeSecurityConstraintGE(i_TradePeriod,i_ACNodeConstraint)                           'AC node security constraint with GE sense (3.5.1.6b)'
ACNodeSecurityConstraintEQ(i_TradePeriod,i_ACNodeConstraint)                           'AC node security constraint with EQ sense (3.5.1.6c)'

*Market node security constraints
MNodeSecurityConstraintLE(i_TradePeriod,i_MNodeConstraint)                             'Market node security constraint with LE sense (3.5.1.7a)'
MNodeSecurityConstraintGE(i_TradePeriod,i_MNodeConstraint)                             'Market node security constraint with GE sense (3.5.1.7b)'
MNodeSecurityConstraintEQ(i_TradePeriod,i_MNodeConstraint)                             'Market node security constraint with EQ sense (3.5.1.7c)'

*Mixed constraints
Type1MixedConstraintLE(i_TradePeriod,i_Type1MixedConstraint)                           'Type 1 mixed constraint definition with LE sense (3.6.1.1a)'
Type1MixedConstraintGE(i_TradePeriod,i_Type1MixedConstraint)                           'Type 1 mixed constraint definition with GE sense (3.6.1.1b)'
Type1MixedConstraintEQ(i_TradePeriod,i_Type1MixedConstraint)                           'Type 1 mixed constraint definition with EQ sense (3.6.1.1c)'
Type2MixedConstraintLE(i_TradePeriod,i_Type2MixedConstraint)                           'Type 2 mixed constraint definition with LE sense (3.6.1.2a)'
Type2MixedConstraintGE(i_TradePeriod,i_Type2MixedConstraint)                           'Type 2 mixed constraint definition with GE sense (3.6.1.2b)'
Type2MixedConstraintEQ(i_TradePeriod,i_Type2MixedConstraint)                           'Type 2 mixed constraint definition with EQ sense (3.6.1.2c)'

Type1MixedConstraintLE_MIP(i_TradePeriod,i_Type1MixedConstraint)                       'Integer equivalent of type 1 mixed constraint definition with LE sense (3.6.1.1a_MIP)'
Type1MixedConstraintGE_MIP(i_TradePeriod,i_Type1MixedConstraint)                       'Integer equivalent of type 1 mixed constraint definition with GE sense (3.6.1.1b_MIP)'
Type1MixedConstraintEQ_MIP(i_TradePeriod,i_Type1MixedConstraint)                       'Integer equivalent of type 1 mixed constraint definition with EQ sense (3.6.1.1c_MIP)'
Type1MixedConstraintMIP(i_TradePeriod,i_Type1MixedConstraint,i_Branch)                 'Type 1 mixed constraint definition of alternate limit selection (integer)'

*Generic constraints
GenericSecurityConstraintLE(i_TradePeriod,i_GenericConstraint)                         'Generic security constraint with LE sense'
GenericSecurityConstraintGE(i_TradePeriod,i_GenericConstraint)                         'Generic security constraint with GE sense'
GenericSecurityConstraintEQ(i_TradePeriod,i_GenericConstraint)                         'Generic security constraint with EQ sense'

*ViolationCost
TotalViolationCostDefinition                                                           'Defined as the sum of the individual violation costs'
;


*Objective function of the dispatch model (4.1.1.1)
ObjectiveFunction..
NETBENEFIT =e=
sum(ValidPurchaseBidBlock, PURCHASEBLOCK(ValidPurchaseBidBlock) * PurchaseBidPrice(ValidPurchaseBidBlock))
- sum(ValidGenerationOfferBlock, GENERATIONBLOCK(ValidGenerationOfferBlock) * GenerationOfferPrice(ValidGenerationOfferBlock))
- sum(ValidReserveOfferBlock, RESERVEBLOCK(ValidReserveOfferBlock) * ReserveOfferPrice(ValidReserveOfferBlock))
- sum(ValidPurchaseBidILRBlock, PURCHASEILRBLOCK(ValidPurchaseBidILRBlock))
- TOTALPENALTYCOST
;

*Defined as the sum of the individual violation costs
*RDN - Bug fix - Used SurplusBranchGroupConstraintPenalty rather than SurplusBranchFlowPenalty
TotalViolationCostDefinition..
TOTALPENALTYCOST =e=
sum(Bus, DeficitBusGenerationPenalty * DEFICITBUSGENERATION(Bus))
+ sum(Bus, SurplusBusGenerationPenalty * SURPLUSBUSGENERATION(Bus))
+ sum(Branch, SurplusBranchFlowPenalty * SURPLUSBRANCHFLOW(Branch))
+ sum(Offer, (DeficitRampRatePenalty * DEFICITRAMPRATE(Offer)) + (SurplusRampRatePenalty * SURPLUSRAMPRATE(Offer)))
+ sum(ACNodeConstraint, DeficitACNodeConstraintPenalty * DEFICITACNODECONSTRAINT(ACNodeConstraint))
+ sum(ACNodeConstraint, SurplusACNodeConstraintPenalty * SURPLUSACNODECONSTRAINT(ACNodeConstraint))
+ sum(BranchConstraint, SurplusBranchGroupConstraintPenalty * SURPLUSBRANCHSECURITYCONSTRAINT(BranchConstraint))
+ sum(BranchConstraint, DeficitBranchGroupConstraintPenalty * DEFICITBRANCHSECURITYCONSTRAINT(BranchConstraint))
+ sum(MNodeConstraint, DeficitMnodeConstraintPenalty * DEFICITMNODECONSTRAINT(MNodeConstraint))
+ sum(MNodeConstraint, SurplusMnodeConstraintPenalty * SURPLUSMNODECONSTRAINT(MNodeConstraint))
+ sum(Type1MixedConstraint, Type1DeficitMixedConstraintPenalty * DEFICITTYPE1MIXEDCONSTRAINT(Type1MixedConstraint))
+ sum(Type1MixedConstraint, Type1SurplusMixedConstraintPenalty * SURPLUSTYPE1MIXEDCONSTRAINT(Type1MixedConstraint))
+ sum(GenericConstraint, DeficitGenericConstraintPenalty * DEFICITGENERICCONSTRAINT(GenericConstraint))
+ sum(GenericConstraint, SurplusGenericConstraintPenalty * SURPLUSGENERICCONSTRAINT(GenericConstraint))
*RDN - Separate CE and ECE reserve deficity
+ sum((CurrentTradePeriod,i_Island,i_ReserveClass) $ (not DiffCeECeCVP), DeficitReservePenalty(i_ReserveClass) * DEFICITRESERVE(CurrentTradePeriod,i_Island,i_ReserveClass))
+ sum((CurrentTradePeriod,i_Island,i_ReserveClass) $ DiffCeECeCVP, DeficitReservePenalty_CE(i_ReserveClass) * DEFICITRESERVE_CE(CurrentTradePeriod,i_Island,i_ReserveClass))
+ sum((CurrentTradePeriod,i_Island,i_ReserveClass) $ DiffCeECeCVP, DeficitReservePenalty_ECE(i_ReserveClass) * DEFICITRESERVE_ECE(CurrentTradePeriod,i_Island,i_ReserveClass))
;

*Definition of generation provided by an offer (3.1.1.2)
GenerationOfferDefintion(Offer)..
GENERATION(Offer) =e=
sum(ValidGenerationOfferBlock(Offer,i_TradeBlock), GENERATIONBLOCK(Offer,i_TradeBlock))
;

*RDN - Change to demand bid
*Change constraint numbering. 3.1.1.5 in the SPD formulation v6.0
*Definition of purchase provided by a bid (3.1.1.5)
*RDN - Change to demand bid - End
PurchaseBidDefintion(Bid)..
PURCHASE(Bid) =e=
sum(ValidPurchaseBidBlock(Bid,i_TradeBlock), PURCHASEBLOCK(Bid,i_TradeBlock))
;

*Maximum flow on each HVDC link (3.2.1.1)
HVDCLinkMaximumFlow(HVDCLink) $ (HVDCLinkClosedStatus(HVDCLink) and i_UseHVDCBranchLimits)..
HVDCLINKFLOW(HVDCLink) =l=
HVDCLinkCapacity(HVDCLink)
;

*Definition of losses on the HVDC link (3.2.1.2)
HVDCLinkLossDefinition(HVDCLink)..
HVDCLINKLOSSES(HVDCLink) =e=
sum(ValidLossSegment(HVDCLink,i_LossSegment), HVDCBreakPointMWLoss(HVDCLink,i_LossSegment)*LAMBDA(HVDCLink,i_LossSegment))
;

*Definition of MW flow on the HVDC link (3.2.1.3)
HVDCLinkFlowDefinition(HVDCLink)..
HVDCLINKFLOW(HVDCLink) =e=
sum(ValidLossSegment(HVDCLink,i_LossSegment), HVDCBreakPointMWFlow(HVDCLink,i_LossSegment)*LAMBDA(HVDCLink,i_LossSegment))
;

*Definition of the integer HVDC link flow variable (3.8.2a)
*RDN - Update constraint to exlcude if roundpower is allowed
*HVDCLinkFlowIntegerDefinition1(CurrentTradePeriod) $ (UseBranchFlowMIP(CurrentTradePeriod) and i_ResolveCircularBranchFlows)..
HVDCLinkFlowIntegerDefinition1(CurrentTradePeriod) $ (UseBranchFlowMIP(CurrentTradePeriod) and i_ResolveCircularBranchFlows and (1-AllowHVDCRoundpower(CurrentTradePeriod)))..
sum(i_FlowDirection, HVDCLINKFLOWDIRECTION_INTEGER(CurrentTradePeriod,i_FlowDirection)) =e=
sum(HVDCPoleDirection(HVDCLink(CurrentTradePeriod,i_Branch),i_FlowDirection), HVDCLINKFLOW(HVDCLink))
;

*Definition of the integer HVDC link flow variable (3.8.2b)
*RDN - Update constraint to exlcude if roundpower is allowed
*HVDCLinkFlowIntegerDefinition2(CurrentTradePeriod,i_FlowDirection) $ (UseBranchFlowMIP(CurrentTradePeriod) and i_ResolveCircularBranchFlows)..
HVDCLinkFlowIntegerDefinition2(CurrentTradePeriod,i_FlowDirection) $ (UseBranchFlowMIP(CurrentTradePeriod) and i_ResolveCircularBranchFlows and (1-AllowHVDCRoundpower(CurrentTradePeriod)))..
HVDCLINKFLOWDIRECTION_INTEGER(CurrentTradePeriod,i_FlowDirection) =e=
sum(HVDCPoleDirection(HVDCLink(CurrentTradePeriod,i_Branch),i_FlowDirection), HVDCLINKFLOW(HVDCLink))
;

*RDN - Definition of the integer HVDC pole flow variable for intra-pole circulating branch flows e (3.8.2c)
HVDCLinkFlowIntegerDefinition3(CurrentTradePeriod,i_Pole) $ (UseBranchFlowMIP(CurrentTradePeriod) and i_ResolveCircularBranchFlows)..
sum(i_Branch $ (HVDCPoles(CurrentTradePeriod,i_Branch) and HVDCPoleBranchMap(i_Pole,i_Branch)), HVDCLINKFLOW(CurrentTradePeriod,i_Branch)) =e=
sum(i_FlowDirection, HVDCPOLEFLOW_INTEGER(CurrentTradePeriod,i_Pole,i_FlowDirection))
;

*RDN - Definition of the integer HVDC pole flow variable for intra-pole circulating branch flows e (3.8.2d)
HVDCLinkFlowIntegerDefinition4(CurrentTradePeriod,i_Pole,i_FlowDirection) $ (UseBranchFlowMIP(CurrentTradePeriod) and i_ResolveCircularBranchFlows)..
sum(HVDCPoleDirection(HVDCPoles(CurrentTradePeriod,i_Branch),i_FlowDirection) $ HVDCPoleBranchMap(i_Pole,i_Branch), HVDCLINKFLOW(HVDCPoles)) =e=
HVDCPOLEFLOW_INTEGER(CurrentTradePeriod,i_Pole,i_FlowDirection)
;

*Definition of weighting factor (3.2.1.4)
LambdaDefinition(HVDCLink)..
sum(ValidLossSegment(HVDCLink,i_LossSegment), LAMBDA(HVDCLink,i_LossSegment)) =e=
1
;

*Definition of weighting factor when branch integer constraints are needed (3.8.3a)
LambdaIntegerDefinition1(HVDCLink(CurrentTradePeriod,i_Branch)) $ (UseBranchFlowMIP(CurrentTradePeriod) and i_ResolveHVDCNonPhysicalLosses)..
sum(ValidLossSegment(HVDCLink,i_LossSegment), LAMBDAINTEGER(HVDCLink,i_LossSegment)) =e=
1
;

*Definition of weighting factor when branch integer constraints are needed (3.8.3b)
LambdaIntegerDefinition2(ValidLossSegment(HVDCLink(CurrentTradePeriod,i_Branch),i_LossSegment)) $ (UseBranchFlowMIP(CurrentTradePeriod) and i_ResolveHVDCNonPhysicalLosses)..
LAMBDAINTEGER(HVDCLink,i_LossSegment) =e=
LAMBDA(HVDCLink,i_LossSegment)
;

*Definition of the net injection at the HVDC nodes (3.2.1.6)
DCNodeNetInjection(DCBus(CurrentTradePeriod,i_Bus))..
0 =e=
DEFICITBUSGENERATION(CurrentTradePeriod,i_Bus) - SURPLUSBUSGENERATION(CurrentTradePeriod,i_Bus)
- sum(HVDCLinkSendingBus(HVDCLink(CurrentTradePeriod,i_Branch),i_Bus) $ ClosedBranch(HVDCLink), HVDCLINKFLOW(HVDCLink))
+ sum(HVDCLinkReceivingBus(HVDCLink(CurrentTradePeriod,i_Branch),i_Bus) $ ClosedBranch(HVDCLink), HVDCLINKFLOW(HVDCLink) - HVDCLINKLOSSES(HVDCLink))
- sum(HVDCLinkBus(HVDCLink(CurrentTradePeriod,i_Branch),i_Bus) $ ClosedBranch(HVDCLink), 0.5 * HVDCLinkFixedLoss(HVDCLink))
;

*1st definition of the net injection at buses corresponding to AC nodes (3.3.1.1)
ACNodeNetInjectionDefinition1(ACBus(CurrentTradePeriod,i_Bus))..
ACNODENETINJECTION(CurrentTradePeriod,i_Bus) =e=
sum(ACBranchSendingBus(ACBranch(CurrentTradePeriod,i_Branch),i_Bus,i_FlowDirection) $ ClosedBranch(ACBranch), ACBRANCHFLOWDIRECTED(ACBranch,i_FlowDirection))
-sum(ACBranchReceivingBus(ACBranch(CurrentTradePeriod,i_Branch),i_Bus,i_FlowDirection) $ ClosedBranch(ACBranch), ACBRANCHFLOWDIRECTED(ACBranch,i_FlowDirection))
;

*2nd definition of the net injection at buses corresponding to AC nodes (3.3.1.2)
ACNodeNetInjectionDefinition2(ACBus(CurrentTradePeriod,i_Bus))..
ACNODENETINJECTION(CurrentTradePeriod,i_Bus) =e=
sum(OfferNode(CurrentTradePeriod,i_Offer,i_Node) $ NodeBus(CurrentTradePeriod,i_Node,i_Bus), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * GENERATION(CurrentTradePeriod,i_Offer))
- sum(BidNode(CurrentTradePeriod,i_Bid,i_Node) $ NodeBus(CurrentTradePeriod,i_Node,i_Bus), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * PURCHASE(CurrentTradePeriod,i_Bid))
- sum(NodeBus(CurrentTradePeriod,i_Node,i_Bus), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * NodeDemand(CurrentTradePeriod,i_Node))
+ DEFICITBUSGENERATION(CurrentTradePeriod,i_Bus) - SURPLUSBUSGENERATION(CurrentTradePeriod,i_Bus)
- sum(HVDCLinkSendingBus(HVDCLink(CurrentTradePeriod,i_Branch),i_Bus) $ ClosedBranch(HVDCLink), HVDCLINKFLOW(HVDCLink))
+ sum(HVDCLinkReceivingBus(HVDCLink(CurrentTradePeriod,i_Branch),i_Bus) $ ClosedBranch(HVDCLink), HVDCLINKFLOW(HVDCLink) - HVDCLINKLOSSES(HVDCLink))
- sum(HVDCLinkBus(HVDCLink(CurrentTradePeriod,i_Branch),i_Bus) $ ClosedBranch(HVDCLink), 0.5 * HVDCLinkFixedLoss(HVDCLink))
- sum(ACBranchReceivingBus(ACBranch(CurrentTradePeriod,i_Branch),i_Bus,i_FlowDirection) $ ClosedBranch(ACBranch), i_BranchReceivingEndLossProportion * ACBRANCHLOSSESDIRECTED(ACBranch,i_FlowDirection))
- sum(ACBranchSendingBus(ACBranch(CurrentTradePeriod,i_Branch),i_Bus,i_FlowDirection) $ ClosedBranch(ACBranch), (1 - i_BranchReceivingEndLossProportion) * ACBRANCHLOSSESDIRECTED(ACBranch,i_FlowDirection))
- sum(BranchBusConnect(ACBranch(CurrentTradePeriod,i_Branch),i_Bus) $ ClosedBranch(ACBranch), 0.5 * ACBranchFixedLoss(ACBranch))
;

*Maximum flow on the AC branch (3.3.1.3)
ACBranchMaximumFlow(ClosedBranch(ACBranch),i_FlowDirection) $ i_UseACBranchLimits..
ACBRANCHFLOWDIRECTED(ACBranch,i_FlowDirection) =l=
ACBranchCapacity(ACBranch)
+ SURPLUSBRANCHFLOW(ACBranch)
;

*Relationship between directed and undirected branch flow variables (3.3.1.4)
ACBranchFlowDefinition(ClosedBranch(ACBranch))..
ACBRANCHFLOW(ACBranch) =e=
sum(i_FlowDirection $ (ord(i_FlowDirection) = 1), ACBRANCHFLOWDIRECTED(ACBranch,i_FlowDirection))
- sum(i_FlowDirection $ (ord(i_FlowDirection) = 2), ACBRANCHFLOWDIRECTED(ACBranch,i_FlowDirection))
;

*Equation that describes the linear load flow (3.3.1.5)
LinearLoadFlow(ClosedBranch(ACBranch(CurrentTradePeriod,i_Branch)))..
ACBRANCHFLOW(ACBranch) =e=
ACBranchSusceptance(ACBranch) * sum(BranchBusDefn(ACBranch,i_FromBus,i_ToBus), ACNODEANGLE(CurrentTradePeriod,i_FromBus) - ACNODEANGLE(CurrentTradePeriod,i_ToBus))
;

*Limit on each AC branch flow block (3.3.1.6)
ACBranchBlockLimit(ValidLossSegment(ClosedBranch(ACBranch),i_LossSegment),i_FlowDirection)..
ACBRANCHFLOWBLOCKDIRECTED(ACBranch,i_LossSegment,i_FlowDirection) =l=
ACBranchLossMW(ACBranch,i_LossSegment)
;

*Composition of the directed branch flow from the block branch flow (3.3.1.7)
ACDirectedBranchFlowDefinition(ClosedBranch(ACBranch),i_FlowDirection)..
ACBRANCHFLOWDIRECTED(ACBranch,i_FlowDirection) =e=
sum(ValidLossSegment(ACBranch,i_LossSegment), ACBRANCHFLOWBLOCKDIRECTED(ACBranch,i_LossSegment,i_FlowDirection))
;

*Calculation of the losses in each loss segment (3.3.1.8)
ACBranchLossCalculation(ValidLossSegment(ClosedBranch(ACBranch),i_LossSegment),i_FlowDirection)..
ACBRANCHLOSSESBLOCKDIRECTED(ACBranch,i_LossSegment,i_FlowDirection) =e=
ACBRANCHFLOWBLOCKDIRECTED(ACBranch,i_LossSegment,i_FlowDirection) * ACBranchLossFactor(ACBranch,i_LossSegment)
;

*Composition of the directed branch losses from the block branch losses (3.3.1.9)
ACDirectedBranchLossDefinition(ClosedBranch(ACBranch),i_FlowDirection)..
ACBRANCHLOSSESDIRECTED(ACBranch,i_FlowDirection) =e=
sum(ValidLossSegment(ACBranch,i_LossSegment), ACBRANCHLOSSESBLOCKDIRECTED(ACBranch,i_LossSegment,i_FlowDirection))
;

*Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1a)
ACDirectedBranchFlowIntegerDefinition1(ClosedBranch(ACBranch(LossBranch(CurrentTradePeriod,i_Branch)))) $ (UseBranchFlowMIP(CurrentTradePeriod) and i_ResolveCircularBranchFlows)..
sum(i_FlowDirection, ACBRANCHFLOWDIRECTED_INTEGER(ACBranch,i_FlowDirection)) =e=
sum(i_FlowDirection, ACBRANCHFLOWDIRECTED(ACBranch,i_FlowDirection))
;

*Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses (3.8.1b)
ACDirectedBranchFlowIntegerDefinition2(ClosedBranch(ACBranch(LossBranch(CurrentTradePeriod,i_Branch))),i_FlowDirection) $ (UseBranchFlowMIP(CurrentTradePeriod) and i_ResolveCircularBranchFlows)..
ACBRANCHFLOWDIRECTED_INTEGER(ACBranch,i_FlowDirection) =e=
ACBRANCHFLOWDIRECTED(ACBranch,i_FlowDirection)
;

*Maximum movement of the generator upwards due to up ramp rate (3.7.1.1)
*Define this constraint over positive energy offers
*RDN - The standard ramp rate constraint does not apply to primary-secondary offers. See GenerationRampUp_PS
*GenerationRampUp(PositiveEnergyOffer)..
*GENERATION(PositiveEnergyOffer) - DEFICITRAMPRATE(PositiveEnergyOffer) =l=
*GenerationEndUp(PositiveEnergyOffer)
*;
GenerationRampUp(PositiveEnergyOffer) $ (not (HasSecondaryOffer(PositiveEnergyOffer) or HasPrimaryOffer(PositiveEnergyOffer)))..
GENERATION(PositiveEnergyOffer) - DEFICITRAMPRATE(PositiveEnergyOffer) =l=
GenerationEndUp(PositiveEnergyOffer)
;

*Maximum movement of the generator downwards due to down ramp rate (3.7.1.2)
*Define this constraint over positive energy offers
*RDN - The standard ramp rate constraint does not apply to primary-secondary offers. See GenerationRampDown_PS
*GenerationRampDown(PositiveEnergyOffer)..
*GENERATION(PositiveEnergyOffer) + SURPLUSRAMPRATE(PositiveEnergyOffer) =g=
*GenerationEndDown(PositiveEnergyOffer)
*;
GenerationRampDown(PositiveEnergyOffer) $ (not (HasSecondaryOffer(PositiveEnergyOffer) or HasPrimaryOffer(PositiveEnergyOffer)))..
GENERATION(PositiveEnergyOffer) + SURPLUSRAMPRATE(PositiveEnergyOffer) =g=
GenerationEndDown(PositiveEnergyOffer)
;

*RDN - Maximum movement of the primary offer that has a secondary offer upwards due to up ramp rate (3.7.1.1)
*Define this constraint over positive energy offers
GenerationRampUp_PS(CurrentTradePeriod,i_Offer) $ (PositiveEnergyOffer(CurrentTradePeriod,i_Offer) and HasSecondaryOffer(CurrentTradePeriod,i_Offer))..
GENERATION(CurrentTradePeriod,i_Offer) + sum(i_Offer1 $ PrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1), GENERATION(CurrentTradePeriod,i_Offer1)) - DEFICITRAMPRATE(CurrentTradePeriod,i_Offer) =l=
GenerationEndUp(CurrentTradePeriod,i_Offer)
;

*RDN - Maximum movement of the primary offer that has a secondary offer downwards due to down ramp rate (3.7.1.2)
*Define this constraint over positive energy offers
GenerationRampDown_PS(CurrentTradePeriod,i_Offer) $ (PositiveEnergyOffer(CurrentTradePeriod,i_Offer) and HasSecondaryOffer(CurrentTradePeriod,i_Offer))..
GENERATION(CurrentTradePeriod,i_Offer) + sum(i_Offer1 $ PrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1), GENERATION(CurrentTradePeriod,i_Offer1)) + SURPLUSRAMPRATE(CurrentTradePeriod,i_Offer) =g=
GenerationEndDown(CurrentTradePeriod,i_Offer)
;

*RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
*Approximation of the risk offset variable.  This approximation will be used if the i_UseMixedConstraint flag is set to false
*RiskOffSetCalculationApproximation(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) $ (not i_UseMixedConstraint)..
*RISKOFFSET(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) =e=
*FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) + HVDCPoleRampUp(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass)
*;

*RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
*Calculation of the risk offset variable for the DCCE risk class.  This will be used when the i_UseMixedConstraintRiskOffset flag is false (3.4.1.2)
*RDN - Disable this constraint only when the original mixed constraint formulation specifit to the risk offset calculation is not used
*RiskOffsetCalculation_DCCE(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) $ ((not i_UseMixedConstraint) and HVDCRisk(i_RiskClass) and ContingentEvents(i_RiskClass))..
RiskOffsetCalculation_DCCE(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) $ ((not i_UseMixedConstraintRiskOffset) and HVDCRisk(i_RiskClass) and ContingentEvents(i_RiskClass))..
RISKOFFSET(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) =e=
FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) + HVDCPoleRampUp(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass)
;

*RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
*Calculation of the risk offset variable for the DCECE risk class.  This will be used when the i_UseMixedConstraintRiskOffset flag is false (3.4.1.4)
*RDN - Disable this constraint only when the original mixed constraint formulation specifit to the risk offset calculation is not used
*RiskOffsetCalculation_DCECE(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) $ ((not i_UseMixedConstraint) and HVDCRisk(i_RiskClass) and ExtendedContingentEvent(i_RiskClass))..
RiskOffsetCalculation_DCECE(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) $ ((not i_UseMixedConstraintRiskOffset) and HVDCRisk(i_RiskClass) and ExtendedContingentEvent(i_RiskClass))..
RISKOFFSET(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) =e=
FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass)
;

*Risk offset definition (3.4.1.5) in old formulation (v4.4). Use this when the i_UseMixedConstraintRiskOffset flag is set.
*RDN - Enable this constraint only when the original mixed constraint formulation specifit to the risk offset calculation is used
*RiskOffsetCalculation(CurrentTradePeriod,i_Type1MixedConstraintReserveMap(i_Type1MixedConstraint,i_Island,i_ReserveClass,i_RiskClass)) $ i_UseMixedConstraint..
RiskOffsetCalculation(CurrentTradePeriod,i_Type1MixedConstraintReserveMap(i_Type1MixedConstraint,i_Island,i_ReserveClass,i_RiskClass)) $ i_UseMixedConstraintRiskOffset..
RISKOFFSET(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) =e=
MIXEDCONSTRAINTVARIABLE(CurrentTradePeriod,i_Type1MixedConstraint)
;

*Calculation of the island risk for a DCCE and DCECE (3.4.1.1)
HVDCIslandRiskCalculation(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCRisk)..
ISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCRisk) =e=
IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCRisk) * (HVDCREC(CurrentTradePeriod,i_Island) - RISKOFFSET(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCRisk))
;

*Calculation of the net received HVDC MW flow into an island (3.4.1.2)
*RDN - Change definition of constraint to cater for the fact that bus to HVDC could be mapped to more than one node
HVDCRecCalculation(CurrentTradePeriod,i_Island)..
HVDCREC(CurrentTradePeriod,i_Island) =e=
*sum((i_Node,i_Bus,i_Branch) $ (NodeIsland(CurrentTradePeriod,i_Node,i_Island) and ACNode(CurrentTradePeriod,i_Node) and NodeBus(CurrentTradePeriod,i_Node,i_Bus) and HVDCLink(CurrentTradePeriod,i_Branch) and HVDCLinkSendingBus(CurrentTradePeriod,i_Branch,i_Bus) and HVDCLink(CurrentTradePeriod,i_Branch)), -HVDCLINKFLOW(CurrentTradePeriod,i_Branch))
*+ sum((i_Node,i_Bus,i_Branch) $ (NodeIsland(CurrentTradePeriod,i_Node,i_Island) and ACNode(CurrentTradePeriod,i_Node) and NodeBus(CurrentTradePeriod,i_Node,i_Bus) and HVDCLink(CurrentTradePeriod,i_Branch) and HVDCLinkReceivingBus(CurrentTradePeriod,i_Branch,i_Bus) and HVDCLink(CurrentTradePeriod,i_Branch)), HVDCLINKFLOW(CurrentTradePeriod,i_Branch) - HVDCLINKLOSSES(CurrentTradePeriod,i_Branch))
*RDN - Change definition based on implementation (This was confirmed by Transpower).  To cater for roundpower - consider only HVDC poles as the sending links to avoid the reduction in the HVDCRec due to half-pole fixed losses
*sum((i_Bus,i_Branch) $ (BusIsland(CurrentTradePeriod,i_Bus,i_Island) and ACBus(CurrentTradePeriod,i_Bus) and HVDCLink(CurrentTradePeriod,i_Branch) and HVDCLinkSendingBus(CurrentTradePeriod,i_Branch,i_Bus) and HVDCLink(CurrentTradePeriod,i_Branch)), -HVDCLINKFLOW(CurrentTradePeriod,i_Branch))
*+ sum((i_Bus,i_Branch) $ (BusIsland(CurrentTradePeriod,i_Bus,i_Island) and ACBus(CurrentTradePeriod,i_Bus) and HVDCLink(CurrentTradePeriod,i_Branch) and HVDCLinkReceivingBus(CurrentTradePeriod,i_Branch,i_Bus) and HVDCLink(CurrentTradePeriod,i_Branch)), HVDCLINKFLOW(CurrentTradePeriod,i_Branch) - HVDCLINKLOSSES(CurrentTradePeriod,i_Branch))
sum((i_Bus,i_Branch) $ (BusIsland(CurrentTradePeriod,i_Bus,i_Island) and ACBus(CurrentTradePeriod,i_Bus) and HVDCLink(CurrentTradePeriod,i_Branch) and HVDCLinkSendingBus(CurrentTradePeriod,i_Branch,i_Bus) and HVDCPoles(CurrentTradePeriod,i_Branch)), -HVDCLINKFLOW(CurrentTradePeriod,i_Branch))
+ sum((i_Bus,i_Branch) $ (BusIsland(CurrentTradePeriod,i_Bus,i_Island) and ACBus(CurrentTradePeriod,i_Bus) and HVDCLink(CurrentTradePeriod,i_Branch) and HVDCLinkReceivingBus(CurrentTradePeriod,i_Branch,i_Bus) and HVDCLink(CurrentTradePeriod,i_Branch)), HVDCLINKFLOW(CurrentTradePeriod,i_Branch) - HVDCLINKLOSSES(CurrentTradePeriod,i_Branch))
;

*Calculation of the island risk for risk setting generators (3.4.1.6)
GenIslandRiskCalculation(CurrentTradePeriod,i_Island,i_Offer,i_ReserveClass,GenRisk) $ ((not (UsePrimSecGenRiskModel)) and IslandRiskGenerator(CurrentTradePeriod,i_Island,i_Offer))..
ISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) =g=
*RDN - Include FKBand into the calculation of the generator risk and replace RISKOFFSET variable by FreeReserve parameter. The FreeReserve parameter is the same as the RiskOffsetParameter.
*IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) * (GENERATION(CurrentTradePeriod,i_Offer) - RISKOFFSET(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) + sum(i_ReserveType, RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)) )
IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) * (GENERATION(CurrentTradePeriod,i_Offer) - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) + FKBand(CurrentTradePeriod,i_Offer) + sum(i_ReserveType, RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)) )
;

*-----------------------------------------------
*Calculation of the island risk for risk setting generators (3.4.1.6)
*RDN - Generator island risk calculation with single offer
GenIslandRiskCalculation_NonPS(CurrentTradePeriod,i_Island,i_Offer,i_ReserveClass,GenRisk) $ (UsePrimSecGenRiskModel and IslandRiskGenerator(CurrentTradePeriod,i_Island,i_Offer) and (not (HasSecondaryOffer(CurrentTradePeriod,i_Offer) or HasPrimaryOffer(CurrentTradePeriod,i_Offer))))..
ISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) =g=
IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) * (GENERATION(CurrentTradePeriod,i_Offer) - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) + FKBand(CurrentTradePeriod,i_Offer) + sum(i_ReserveType, RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)) )
;

*Calculation of the island risk for risk setting generators (3.4.1.6)
*RDN - Risk calculation for generators with more than one offer - Primary and secondary offers
GenIslandRiskCalculation_PS(CurrentTradePeriod,i_Island,i_Offer,i_ReserveClass,GenRisk) $ (UsePrimSecGenRiskModel and IslandRiskGenerator(CurrentTradePeriod,i_Island,i_Offer) and HasSecondaryOffer(CurrentTradePeriod,i_Offer))..
ISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) =g=
IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) * ((GENERATION(CurrentTradePeriod,i_Offer) + sum(i_Offer1 $ PrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1), GENERATION(CurrentTradePeriod,i_Offer1))) - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) + FKBand(CurrentTradePeriod,i_Offer)
+ (sum(i_ReserveType, RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)) + sum((i_Offer1,i_ReserveType) $ PrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1), RESERVE(CurrentTradePeriod,i_Offer1,i_ReserveClass,i_ReserveType))) )
;
*-----------------------------------------------

*Calculation of the island risk based on manual specifications (3.4.1.7)
ManualIslandRiskCalculation(CurrentTradePeriod,i_Island,i_ReserveClass,ManualRisk)..
ISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass,ManualRisk) =e=
*RDN - Include IslandMinimumRisk parameter that is indexed over i_RiskClass and replace RISKOFFSET variable by FreeReserve parameter. The FreeReserve parameter is the same as the RiskOffsetParameter.
*IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,ManualRisk) * (IslandMinimumRisk(CurrentTradePeriod,i_Island,i_ReserveClass) - RISKOFFSET(CurrentTradePeriod,i_Island,i_ReserveClass,ManualRisk))
IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,ManualRisk) * (IslandMinimumRisk(CurrentTradePeriod,i_Island,i_ReserveClass,ManualRisk) - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,ManualRisk))
;

*RDN - HVDC secondary risk calculation including the FKBand for generator primary risk
*Calculation of the island risk for an HVDC secondary risk to a generator risk (3.4.1.8)
HVDCIslandSecRiskCalculation_GEN(CurrentTradePeriod,i_Island,i_Offer,i_ReserveClass,HVDCSecRisk) $ ((not (UsePrimSecGenRiskModel)) and HVDCSecRiskEnabled(CurrentTradePeriod,i_Island,HVDCSecRisk) and IslandRiskGenerator(CurrentTradePeriod,i_Island,i_Offer))..
ISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) =g=
IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) * (GENERATION(CurrentTradePeriod,i_Offer) - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) + HVDCREC(CurrentTradePeriod,i_Island) - HVDCSecRiskSubtractor(CurrentTradePeriod,i_Island) + FKBand(CurrentTradePeriod,i_Offer) + sum(i_ReserveType, RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)))
;

*-----------------------------------------------
*Calculation of the island risk for an HVDC secondary risk to a generator risk (3.4.1.8)
HVDCIslandSecRiskCalculation_GEN_NonPS(CurrentTradePeriod,i_Island,i_Offer,i_ReserveClass,HVDCSecRisk) $ (UsePrimSecGenRiskModel and HVDCSecRiskEnabled(CurrentTradePeriod,i_Island,HVDCSecRisk) and IslandRiskGenerator(CurrentTradePeriod,i_Island,i_Offer) and (not (HasSecondaryOffer(CurrentTradePeriod,i_Offer) or HasPrimaryOffer(CurrentTradePeriod,i_Offer))))..
ISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) =g=
IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) * (GENERATION(CurrentTradePeriod,i_Offer) - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) + HVDCREC(CurrentTradePeriod,i_Island) - HVDCSecRiskSubtractor(CurrentTradePeriod,i_Island) + FKBand(CurrentTradePeriod,i_Offer) + sum(i_ReserveType, RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)))
;

*Calculation of the island risk for an HVDC secondary risk to a generator risk (3.4.1.8)
HVDCIslandSecRiskCalculation_GEN_PS(CurrentTradePeriod,i_Island,i_Offer,i_ReserveClass,HVDCSecRisk) $ (UsePrimSecGenRiskModel and HVDCSecRiskEnabled(CurrentTradePeriod,i_Island,HVDCSecRisk) and IslandRiskGenerator(CurrentTradePeriod,i_Island,i_Offer) and HasSecondaryOffer(CurrentTradePeriod,i_Offer))..
ISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) =g=
IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) * ((GENERATION(CurrentTradePeriod,i_Offer) + sum(i_Offer1 $ PrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1), GENERATION(CurrentTradePeriod,i_Offer1)))
- FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) + HVDCREC(CurrentTradePeriod,i_Island) - HVDCSecRiskSubtractor(CurrentTradePeriod,i_Island) + FKBand(CurrentTradePeriod,i_Offer)
+ (sum(i_ReserveType, RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)) + sum((i_Offer1,i_ReserveType) $ PrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1), RESERVE(CurrentTradePeriod,i_Offer1,i_ReserveClass,i_ReserveType))) )
;
*-----------------------------------------------

*RDN - HVDC secondary risk calculation for manual primary risk
*Calculation of the island risk for an HVDC secondary risk to a manual risk (3.4.1.9)
HVDCIslandSecRiskCalculation_Manual(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) $ HVDCSecRiskEnabled(CurrentTradePeriod,i_Island,HVDCSecRisk)..
ISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) =g=
IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) * (HVDCSecIslandMinimumRisk(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) + HVDCREC(CurrentTradePeriod,i_Island) - HVDCSecRiskSubtractor(CurrentTradePeriod,i_Island))
;

*Maximum PLSR as a proportion of the block MW (3.4.2.1)
PLSRReserveProportionMaximum(ValidReserveOfferBlock(Offer,i_TradeBlock,i_ReserveClass,PLSRReserveType))..
RESERVEBLOCK(Offer,i_TradeBlock,i_ReserveClass,PLSRReserveType) =l=
ReserveOfferProportion(Offer,i_TradeBlock,i_ReserveClass) * GENERATION(Offer)
;

*Definition of the reserve offers of different classes and types (3.4.2.3a)
ReserveOfferDefinition(Offer,i_ReserveClass,i_ReserveType)..
RESERVE(Offer,i_ReserveClass,i_ReserveType) =e=
sum(i_TradeBlock, RESERVEBLOCK(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType))
;

*Definition of the ILR reserve provided by purchase bids (3.4.2.3b)
ReserveDefinitionPurchaseBid(Bid,i_ReserveClass)..
PURCHASEILR(Bid,i_ReserveClass) =e=
sum(i_TradeBlock, PURCHASEILRBLOCK(Bid,i_TradeBlock,i_ReserveClass))
;

*Definition of maximum energy and reserves from each generator (3.4.2.4)
EnergyAndReserveMaximum(Offer,i_ReserveClass)..
GENERATION(Offer) + ReserveMaximumFactor(Offer,i_ReserveClass) * sum(i_ReserveType $ (not ILReserveType(i_ReserveType)), RESERVE(Offer,i_ReserveClass,i_ReserveType)) =l=
ReserveGenerationMaximum(Offer)
;

*RDN - Change to demand bid
*This constraint is no longer in the formulation from v6.0 (following changes with DSBF)
*Maximum ILR provided by purchase bids (3.4.2.5)
*PurchaseBidReserveMaximum(Bid,i_ReserveClass)..
PurchaseBidReserveMaximum(Bid,i_ReserveClass) $ (not (UseDSBFDemandBidModel))..
PURCHASEILR(Bid,i_ReserveClass) =l=
PURCHASE(Bid)
;
*RDN - Change to demand bid - End

*Definition of the maximum risk in each island (3.4.3.1)
*MaximumIslandRiskDefinition(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass)..
*ISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) =l=
*MAXISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass)
*;

*Definition of the maximum risk in each island (3.4.3.1)
*RDN - Update maximum island risk definition to only apply when the CE and ECE CVPs are not separated
MaximumIslandRiskDefinition(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) $ (not DiffCeECeCVP)..
ISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) =l=
MAXISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass)
;

*RDN - Update maximum island risk definition with the CE and ECE deficit reserve
*Definition of the maximum CE risk in each island (3.4.3.1a) - Use this definition if flag for different CVPs for CE and ECE
MaximumIslandRiskDefinition_CE(CurrentTradePeriod,i_Island,i_ReserveClass,ContingentEvents) $ (DiffCeECeCVP)..
ISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass,ContingentEvents) =l=
MAXISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass) + DEFICITRESERVE_CE(CurrentTradePeriod,i_Island,i_ReserveClass)
;

*RDN - Update maximum island risk definition with the CE and ECE deficit reserve
*Definition of the maximum ECE risk in each island (3.4.3.1b) - Use this definition if flag for different CVPs for CE and ECE
MaximumIslandRiskDefinition_ECE(CurrentTradePeriod,i_Island,i_ReserveClass,ExtendedContingentEvent) $ (DiffCeECeCVP)..
ISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass,ExtendedContingentEvent) =l=
MAXISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass) + DEFICITRESERVE_ECE(CurrentTradePeriod,i_Island,i_ReserveClass)
;

*Matching of reserve supply and demand (3.4.3.2)
SupplyDemandReserveRequirement(CurrentTradePeriod,i_Island,i_ReserveClass) $ i_UseReserveModel..
MAXISLANDRISK(CurrentTradePeriod,i_Island,i_ReserveClass) - (DEFICITRESERVE(CurrentTradePeriod,i_Island,i_ReserveClass) $ (not DiffCeECeCVP)) =l=
sum((i_Offer,i_ReserveType) $ (Offer(CurrentTradePeriod,i_Offer) and IslandOffer(CurrentTradePeriod,i_Island,i_Offer)), RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Bid $ (Bid(CurrentTradePeriod,i_Bid) and IslandBid(CurrentTradePeriod,i_Island,i_Bid)), PURCHASEILR(CurrentTradePeriod,i_Bid,i_ReserveClass))
;

*Branch security constraint with LE sense (3.5.1.5a)
BranchSecurityConstraintLE(CurrentTradePeriod,i_BranchConstraint) $ (BranchConstraintSense(CurrentTradePeriod,i_BranchConstraint) = -1)..
sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), BranchConstraintFactors(CurrentTradePeriod,i_BranchConstraint,i_Branch) * ACBRANCHFLOW(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), BranchConstraintFactors(CurrentTradePeriod,i_BranchConstraint,i_Branch) * HVDCLINKFLOW(CurrentTradePeriod,i_Branch))
- SURPLUSBRANCHSECURITYCONSTRAINT(CurrentTradePeriod,i_BranchConstraint) =l=
BranchConstraintLimit(CurrentTradePeriod,i_BranchConstraint)
;

*Branch security constraint with GE sense (3.5.1.5b)
BranchSecurityConstraintGE(CurrentTradePeriod,i_BranchConstraint) $ (BranchConstraintSense(CurrentTradePeriod,i_BranchConstraint) = 1)..
sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), BranchConstraintFactors(CurrentTradePeriod,i_BranchConstraint,i_Branch) * ACBRANCHFLOW(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), BranchConstraintFactors(CurrentTradePeriod,i_BranchConstraint,i_Branch) * HVDCLINKFLOW(CurrentTradePeriod,i_Branch))
+ DEFICITBRANCHSECURITYCONSTRAINT(CurrentTradePeriod,i_BranchConstraint) =g=
BranchConstraintLimit(CurrentTradePeriod,i_BranchConstraint)
;

*Branch security constraint with EQ sense (3.5.1.5c)
BranchSecurityConstraintEQ(CurrentTradePeriod,i_BranchConstraint) $ (BranchConstraintSense(CurrentTradePeriod,i_BranchConstraint) = 0)..
sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), BranchConstraintFactors(CurrentTradePeriod,i_BranchConstraint,i_Branch) * ACBRANCHFLOW(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), BranchConstraintFactors(CurrentTradePeriod,i_BranchConstraint,i_Branch) * HVDCLINKFLOW(CurrentTradePeriod,i_Branch))
+ DEFICITBRANCHSECURITYCONSTRAINT(CurrentTradePeriod,i_BranchConstraint) - SURPLUSBRANCHSECURITYCONSTRAINT(CurrentTradePeriod,i_BranchConstraint) =e=
BranchConstraintLimit(CurrentTradePeriod,i_BranchConstraint)
;

*AC node security constraint with LE sense (3.5.1.6a)
ACNodeSecurityConstraintLE(CurrentTradePeriod,i_ACNodeConstraint) $ (ACNodeConstraintSense(CurrentTradePeriod,i_ACNodeConstraint) = -1)..
sum((i_Node,i_Bus) $ (ACNode(CurrentTradePeriod,i_Node) and NodeBus(CurrentTradePeriod,i_Node,i_Bus)), ACNodeConstraintFactors(CurrentTradePeriod,i_ACNodeConstraint,i_Node) * NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * ACNODENETINJECTION(CurrentTradePeriod,i_Bus))
- SURPLUSACNODECONSTRAINT(CurrentTradePeriod,i_ACNodeConstraint) =l=
ACNodeConstraintLimit(CurrentTradePeriod,i_ACNodeConstraint)
;

*AC node security constraint with GE sense (3.5.1.6b)
ACNodeSecurityConstraintGE(CurrentTradePeriod,i_ACNodeConstraint) $ (ACNodeConstraintSense(CurrentTradePeriod,i_ACNodeConstraint) = 1)..
sum((i_Node,i_Bus) $ (ACNode(CurrentTradePeriod,i_Node) and NodeBus(CurrentTradePeriod,i_Node,i_Bus)), ACNodeConstraintFactors(CurrentTradePeriod,i_ACNodeConstraint,i_Node) * NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * ACNODENETINJECTION(CurrentTradePeriod,i_Bus))
+ DEFICITACNODECONSTRAINT(CurrentTradePeriod,i_ACNodeConstraint) =g=
ACNodeConstraintLimit(CurrentTradePeriod,i_ACNodeConstraint)
;

*AC node security constraint with EQ sense (3.5.1.6c)
ACNodeSecurityConstraintEQ(CurrentTradePeriod,i_ACNodeConstraint) $ (ACNodeConstraintSense(CurrentTradePeriod,i_ACNodeConstraint) = 0)..
sum((i_Node,i_Bus) $ (ACNode(CurrentTradePeriod,i_Node) and NodeBus(CurrentTradePeriod,i_Node,i_Bus)), ACNodeConstraintFactors(CurrentTradePeriod,i_ACNodeConstraint,i_Node) * NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * ACNODENETINJECTION(CurrentTradePeriod,i_Bus))
+ DEFICITACNODECONSTRAINT(CurrentTradePeriod,i_ACNodeConstraint) - SURPLUSACNODECONSTRAINT(CurrentTradePeriod,i_ACNodeConstraint) =e=
ACNodeConstraintLimit(CurrentTradePeriod,i_ACNodeConstraint)
;



*Market node security constraint with LE sense (3.5.1.7a)
MNodeSecurityConstraintLE(CurrentTradePeriod,i_MNodeConstraint) $ (MNodeConstraintSense(CurrentTradePeriod,i_MNodeConstraint) = -1)..
*RDN - 20130226 - Only valid energy offers and bids are included in the constraint
*sum(i_Offer, MNodeEnergyOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
*+ sum((i_Offer,i_ReserveClass,i_ReserveType), MNodeReserveOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
*+ sum(i_Bid, MNodeEnergyBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
*+ sum((i_Bid,i_ReserveClass), MNodeILReserveBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid,i_ReserveClass) * PURCHASEILR(CurrentTradePeriod,i_Bid,i_ReserveClass))
sum(i_Offer $ PositiveEnergyOffer(CurrentTradePeriod,i_Offer), MNodeEnergyOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum((i_Offer,i_ReserveClass,i_ReserveType) $ Offer(CurrentTradePeriod,i_Offer), MNodeReserveOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Bid $ Bid(CurrentTradePeriod,i_Bid), MNodeEnergyBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
+ sum((i_Bid,i_ReserveClass) $ Bid(CurrentTradePeriod,i_Bid), MNodeILReserveBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid,i_ReserveClass) * PURCHASEILR(CurrentTradePeriod,i_Bid,i_ReserveClass))
- SURPLUSMNODECONSTRAINT(CurrentTradePeriod,i_MNodeConstraint) =l=
MNodeConstraintLimit(CurrentTradePeriod,i_MNodeConstraint)
;

*Market node security constraint with GE sense (3.5.1.7b)
MNodeSecurityConstraintGE(CurrentTradePeriod,i_MNodeConstraint) $ (MNodeConstraintSense(CurrentTradePeriod,i_MNodeConstraint) = 1)..
*RDN - 20130226 - Only valid energy offers and bids are included in the constraint
*sum(i_Offer, MNodeEnergyOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
*+ sum((i_Offer,i_ReserveClass,i_ReserveType), MNodeReserveOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
*+ sum(i_Bid, MNodeEnergyBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
*+ sum((i_Bid,i_ReserveClass), MNodeILReserveBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid,i_ReserveClass) * PURCHASEILR(CurrentTradePeriod,i_Bid,i_ReserveClass))
sum(i_Offer $ PositiveEnergyOffer(CurrentTradePeriod,i_Offer), MNodeEnergyOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum((i_Offer,i_ReserveClass,i_ReserveType) $ Offer(CurrentTradePeriod,i_Offer), MNodeReserveOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Bid $ Bid(CurrentTradePeriod,i_Bid), MNodeEnergyBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
+ sum((i_Bid,i_ReserveClass) $ Bid(CurrentTradePeriod,i_Bid), MNodeILReserveBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid,i_ReserveClass) * PURCHASEILR(CurrentTradePeriod,i_Bid,i_ReserveClass))
+ DEFICITMNODECONSTRAINT(CurrentTradePeriod,i_MNodeConstraint) =g=
MNodeConstraintLimit(CurrentTradePeriod,i_MNodeConstraint)
;

*Market node security constraint with EQ sense (3.5.1.7c)
MNodeSecurityConstraintEQ(CurrentTradePeriod,i_MNodeConstraint) $ (MNodeConstraintSense(CurrentTradePeriod,i_MNodeConstraint) = 0)..
*RDN - 20130226 - Only valid energy offers and bids are included in the constraint
*sum(i_Offer, MNodeEnergyOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
*+ sum((i_Offer,i_ReserveClass,i_ReserveType), MNodeReserveOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
*+ sum(i_Bid, MNodeEnergyBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
*+ sum((i_Bid,i_ReserveClass), MNodeILReserveBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid,i_ReserveClass) * PURCHASEILR(CurrentTradePeriod,i_Bid,i_ReserveClass))
sum(i_Offer $ PositiveEnergyOffer(CurrentTradePeriod,i_Offer), MNodeEnergyOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum((i_Offer,i_ReserveClass,i_ReserveType) $ Offer(CurrentTradePeriod,i_Offer), MNodeReserveOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Bid $ Bid(CurrentTradePeriod,i_Bid), MNodeEnergyBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
+ sum((i_Bid,i_ReserveClass) $ Bid(CurrentTradePeriod,i_Bid), MNodeILReserveBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid,i_ReserveClass) * PURCHASEILR(CurrentTradePeriod,i_Bid,i_ReserveClass))
+ DEFICITMNODECONSTRAINT(CurrentTradePeriod,i_MNodeConstraint) - SURPLUSMNODECONSTRAINT(CurrentTradePeriod,i_MNodeConstraint) =e=
MNodeConstraintLimit(CurrentTradePeriod,i_MNodeConstraint)
;

*Type 1 mixed constraint definition with LE sense (3.6.1.1a)
*Type1MixedConstraintLE(CurrentTradePeriod,i_Type1MixedConstraint) $ (i_UseMixedConstraint and (Type1MixedConstraintSense(CurrentTradePeriod,i_Type1MixedConstraint) = -1) and (not UseMixedConstraintMIP(CurrentTradePeriod)))..
Type1MixedConstraintLE(CurrentTradePeriod,i_Type1MixedConstraint) $ (UseMixedConstraint(CurrentTradePeriod) and (Type1MixedConstraintSense(CurrentTradePeriod,i_Type1MixedConstraint) = -1) and (not UseMixedConstraintMIP(CurrentTradePeriod)))..
i_Type1MixedConstraintVarWeight(i_Type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(CurrentTradePeriod,i_Type1MixedConstraint)
*RDN - 20130226 - Only valid energy offers and bids are included in the constraint
*+ sum(i_Offer, i_Type1MixedConstraintGenWeight(i_Type1MixedConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
*+ sum((i_Offer,i_ReserveClass,i_ReserveType), i_Type1MixedConstraintResWeight(i_Type1MixedConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Offer $ PositiveEnergyOffer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintGenWeight(i_Type1MixedConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum((i_Offer,i_ReserveClass,i_ReserveType) $ Offer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintResWeight(i_Type1MixedConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintHVDCLineWeight(i_Type1MixedConstraint,i_Branch) * HVDCLINKFLOW(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintACLineWeight(i_Type1MixedConstraint,i_Branch) * sum(i_FlowDirection, ACBRANCHFLOWDIRECTED(CurrentTradePeriod,i_Branch,i_FlowDirection)))
+ sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintACLineLossWeight(i_Type1MixedConstraint,i_Branch) * sum(i_FlowDirection, ACBRANCHLOSSESDIRECTED(CurrentTradePeriod,i_Branch,i_FlowDirection)))
+ sum(i_Branch $ (ACBranch(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)), i_Type1MixedConstraintACLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) * ACBranchFixedLoss(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintHVDCLineLossWeight(i_Type1MixedConstraint,i_Branch) * HVDCLINKLOSSES(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ (HVDCLink(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)), i_Type1MixedConstraintHVDCLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) * HVDCLinkFixedLoss(CurrentTradePeriod,i_Branch))
+ sum(i_Bid $ Bid(CurrentTradePeriod,i_Bid), i_Type1MixedConstraintPurWeight(i_Type1MixedConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
- SURPLUSTYPE1MIXEDCONSTRAINT(CurrentTradePeriod,i_Type1MixedConstraint) =l=
Type1MixedConstraintLimit1(CurrentTradePeriod,i_Type1MixedConstraint)
;


*Type 1 mixed constraint definition with GE sense (3.6.1.1b)
*Type1MixedConstraintGE(CurrentTradePeriod,i_Type1MixedConstraint) $ (i_UseMixedConstraint and (Type1MixedConstraintSense(CurrentTradePeriod,i_Type1MixedConstraint) = 1) and (not UseMixedConstraintMIP(CurrentTradePeriod)))..
Type1MixedConstraintGE(CurrentTradePeriod,i_Type1MixedConstraint) $ (UseMixedConstraint(CurrentTradePeriod) and (Type1MixedConstraintSense(CurrentTradePeriod,i_Type1MixedConstraint) = 1) and (not UseMixedConstraintMIP(CurrentTradePeriod)))..
i_Type1MixedConstraintVarWeight(i_Type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(CurrentTradePeriod,i_Type1MixedConstraint)
*RDN - 20130226 - Only valid energy offers and bids are included in the constraint
*+ sum(i_Offer, i_Type1MixedConstraintGenWeight(i_Type1MixedConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
*+ sum((i_Offer,i_ReserveClass,i_ReserveType), i_Type1MixedConstraintResWeight(i_Type1MixedConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Offer $ PositiveEnergyOffer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintGenWeight(i_Type1MixedConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum((i_Offer,i_ReserveClass,i_ReserveType) $ Offer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintResWeight(i_Type1MixedConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintHVDCLineWeight(i_Type1MixedConstraint,i_Branch) * HVDCLINKFLOW(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintACLineWeight(i_Type1MixedConstraint,i_Branch) * sum(i_FlowDirection, ACBRANCHFLOWDIRECTED(CurrentTradePeriod,i_Branch,i_FlowDirection)))
+ sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintACLineLossWeight(i_Type1MixedConstraint,i_Branch) * sum(i_FlowDirection, ACBRANCHLOSSESDIRECTED(CurrentTradePeriod,i_Branch,i_FlowDirection)))
+ sum(i_Branch $ (ACBranch(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)), i_Type1MixedConstraintACLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) * ACBranchFixedLoss(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintHVDCLineLossWeight(i_Type1MixedConstraint,i_Branch) * HVDCLINKLOSSES(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ (HVDCLink(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)), i_Type1MixedConstraintHVDCLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) * HVDCLinkFixedLoss(CurrentTradePeriod,i_Branch))
+ sum(i_Bid $ Bid(CurrentTradePeriod,i_Bid), i_Type1MixedConstraintPurWeight(i_Type1MixedConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
+ DEFICITTYPE1MIXEDCONSTRAINT(CurrentTradePeriod,i_Type1MixedConstraint) =g=
Type1MixedConstraintLimit1(CurrentTradePeriod,i_Type1MixedConstraint)
;

*Type 1 mixed constraint definition with EQ sense (3.6.1.1c)
*Type1MixedConstraintEQ(CurrentTradePeriod,i_Type1MixedConstraint) $ (i_UseMixedConstraint and (Type1MixedConstraintSense(CurrentTradePeriod,i_Type1MixedConstraint) = 0) and (not UseMixedConstraintMIP(CurrentTradePeriod)))..
Type1MixedConstraintEQ(CurrentTradePeriod,i_Type1MixedConstraint) $ (UseMixedConstraint(CurrentTradePeriod) and (Type1MixedConstraintSense(CurrentTradePeriod,i_Type1MixedConstraint) = 0) and (not UseMixedConstraintMIP(CurrentTradePeriod)))..
i_Type1MixedConstraintVarWeight(i_Type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(CurrentTradePeriod,i_Type1MixedConstraint)
*RDN - 20130226 - Only valid energy offers and bids are included in the constraint
*+ sum(i_Offer, i_Type1MixedConstraintGenWeight(i_Type1MixedConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
*+ sum((i_Offer,i_ReserveClass,i_ReserveType), i_Type1MixedConstraintResWeight(i_Type1MixedConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Offer $ PositiveEnergyOffer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintGenWeight(i_Type1MixedConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum((i_Offer,i_ReserveClass,i_ReserveType) $ Offer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintResWeight(i_Type1MixedConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintHVDCLineWeight(i_Type1MixedConstraint,i_Branch) * HVDCLINKFLOW(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintACLineWeight(i_Type1MixedConstraint,i_Branch) * sum(i_FlowDirection, ACBRANCHFLOWDIRECTED(CurrentTradePeriod,i_Branch,i_FlowDirection)))
+ sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintACLineLossWeight(i_Type1MixedConstraint,i_Branch) * sum(i_FlowDirection, ACBRANCHLOSSESDIRECTED(CurrentTradePeriod,i_Branch,i_FlowDirection)))
+ sum(i_Branch $ (ACBranch(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)), i_Type1MixedConstraintACLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) * ACBranchFixedLoss(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintHVDCLineLossWeight(i_Type1MixedConstraint,i_Branch) * HVDCLINKLOSSES(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ (HVDCLink(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)), i_Type1MixedConstraintHVDCLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) * HVDCLinkFixedLoss(CurrentTradePeriod,i_Branch))
+ sum(i_Bid $ Bid(CurrentTradePeriod,i_Bid), i_Type1MixedConstraintPurWeight(i_Type1MixedConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
+ DEFICITTYPE1MIXEDCONSTRAINT(CurrentTradePeriod,i_Type1MixedConstraint) - SURPLUSTYPE1MIXEDCONSTRAINT(CurrentTradePeriod,i_Type1MixedConstraint) =e=
Type1MixedConstraintLimit1(CurrentTradePeriod,i_Type1MixedConstraint)
;

*Type 2 mixed constraint definition with LE sense (3.6.1.2a)
*Type2MixedConstraintLE(CurrentTradePeriod,i_Type2MixedConstraint) $ (i_UseMixedConstraint and (Type2MixedConstraintSense(CurrentTradePeriod,i_Type2MixedConstraint) = -1))..
Type2MixedConstraintLE(CurrentTradePeriod,i_Type2MixedConstraint) $ (UseMixedConstraint(CurrentTradePeriod) and (Type2MixedConstraintSense(CurrentTradePeriod,i_Type2MixedConstraint) = -1))..
sum(i_Type1MixedConstraint, i_Type2MixedConstraintLHSParameters(i_Type2MixedConstraint,i_Type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(CurrentTradePeriod,i_Type1MixedConstraint))
=l=
Type2MixedConstraintLimit(CurrentTradePeriod,i_Type2MixedConstraint)
;

*Type 2 mixed constraint definition with GE sense (3.6.1.2b)
*Type2MixedConstraintGE(CurrentTradePeriod,i_Type2MixedConstraint) $ (i_UseMixedConstraint and (Type2MixedConstraintSense(CurrentTradePeriod,i_Type2MixedConstraint) = 1))..
Type2MixedConstraintGE(CurrentTradePeriod,i_Type2MixedConstraint) $ (UseMixedConstraint(CurrentTradePeriod) and (Type2MixedConstraintSense(CurrentTradePeriod,i_Type2MixedConstraint) = 1))..
sum(i_Type1MixedConstraint, i_Type2MixedConstraintLHSParameters(i_Type2MixedConstraint,i_Type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(CurrentTradePeriod,i_Type1MixedConstraint))
=g=
Type2MixedConstraintLimit(CurrentTradePeriod,i_Type2MixedConstraint)
;

*Type 2 mixed constraint definition with EQ sense (3.6.1.2c)
*Type2MixedConstraintEQ(CurrentTradePeriod,i_Type2MixedConstraint) $ (i_UseMixedConstraint and (Type2MixedConstraintSense(CurrentTradePeriod,i_Type2MixedConstraint) = 0))..
Type2MixedConstraintEQ(CurrentTradePeriod,i_Type2MixedConstraint) $ (UseMixedConstraint(CurrentTradePeriod) and (Type2MixedConstraintSense(CurrentTradePeriod,i_Type2MixedConstraint) = 0))..
sum(i_Type1MixedConstraint, i_Type2MixedConstraintLHSParameters(i_Type2MixedConstraint,i_Type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(CurrentTradePeriod,i_Type1MixedConstraint))
=e=
Type2MixedConstraintLimit(CurrentTradePeriod,i_Type2MixedConstraint)
;

*Type 1 mixed constraint definition of alternate limit selection (integer)
*RDN - Enable this constraint only when the original mixed constraint formulation is used. This logic is specific to the HVDC pole 1 south flow condition.
*Type1MixedConstraintMIP(CurrentTradePeriod,i_Type1MixedConstraintBranchCondition(i_Type1MixedConstraint,i_Branch)) $ (i_UseMixedConstraint and HVDCHalfPoles(CurrentTradePeriod,i_Branch) and UseMixedConstraintMIP(CurrentTradePeriod))..
Type1MixedConstraintMIP(CurrentTradePeriod,i_Type1MixedConstraintBranchCondition(i_Type1MixedConstraint,i_Branch)) $ (i_UseMixedConstraintRiskOffset and HVDCHalfPoles(CurrentTradePeriod,i_Branch) and UseMixedConstraintMIP(CurrentTradePeriod))..
HVDCLINKFLOW(CurrentTradePeriod,i_Branch) =l=
MIXEDCONSTRAINTLIMIT2SELECT(CurrentTradePeriod,i_Type1MixedConstraint) * MixedConstraintBigNumber
;

*Integer equivalent of Type 1 mixed constraint definition with LE sense (3.6.1.1a_MIP)
*Type1MixedConstraintLE_MIP(Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint)) $ (i_UseMixedConstraint and (Type1MixedConstraintSense(CurrentTradePeriod,i_Type1MixedConstraint) = -1) and UseMixedConstraintMIP(CurrentTradePeriod))..
Type1MixedConstraintLE_MIP(Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint)) $ (UseMixedConstraint(CurrentTradePeriod) and (Type1MixedConstraintSense(CurrentTradePeriod,i_Type1MixedConstraint) = -1) and UseMixedConstraintMIP(CurrentTradePeriod))..
i_Type1MixedConstraintVarWeight(i_Type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(CurrentTradePeriod,i_Type1MixedConstraint)
*RDN - 20130226 - Only positive energy offers are included in the constraint
*+ sum(i_Offer $ Offer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintGenWeight(i_Type1MixedConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum(i_Offer $ PositiveEnergyOffer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintGenWeight(i_Type1MixedConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum((i_Offer,i_ReserveClass,i_ReserveType) $ Offer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintResWeight(i_Type1MixedConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintHVDCLineWeight(i_Type1MixedConstraint,i_Branch) * HVDCLINKFLOW(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintACLineWeight(i_Type1MixedConstraint,i_Branch) * sum(i_FlowDirection, ACBRANCHFLOWDIRECTED(CurrentTradePeriod,i_Branch,i_FlowDirection)))
+ sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintACLineLossWeight(i_Type1MixedConstraint,i_Branch) * sum(i_FlowDirection, ACBRANCHLOSSESDIRECTED(CurrentTradePeriod,i_Branch,i_FlowDirection)))
+ sum(i_Branch $ (ACBranch(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)), i_Type1MixedConstraintACLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) * ACBranchFixedLoss(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintHVDCLineLossWeight(i_Type1MixedConstraint,i_Branch) * HVDCLINKLOSSES(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ (HVDCLink(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)), i_Type1MixedConstraintHVDCLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) * HVDCLinkFixedLoss(CurrentTradePeriod,i_Branch))
+ sum(i_Bid $ Bid(CurrentTradePeriod,i_Bid), i_Type1MixedConstraintPurWeight(i_Type1MixedConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
- SURPLUSTYPE1MIXEDCONSTRAINT(CurrentTradePeriod,i_Type1MixedConstraint) =l=
Type1MixedConstraintLimit1(CurrentTradePeriod,i_Type1MixedConstraint) * (1 - MIXEDCONSTRAINTLIMIT2SELECT(CurrentTradePeriod,i_Type1MixedConstraint))
+ Type1MixedConstraintLimit2(CurrentTradePeriod,i_Type1MixedConstraint) * MIXEDCONSTRAINTLIMIT2SELECT(CurrentTradePeriod,i_Type1MixedConstraint)
;

*Integer equivalent of Type 1 mixed constraint definition with GE sense (3.6.1.1b_MIP)
*Type1MixedConstraintGE_MIP(Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint)) $ (i_UseMixedConstraint and (Type1MixedConstraintSense(CurrentTradePeriod,i_Type1MixedConstraint) = 1) and UseMixedConstraintMIP(CurrentTradePeriod))..
Type1MixedConstraintGE_MIP(Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint)) $ (UseMixedConstraint(CurrentTradePeriod) and (Type1MixedConstraintSense(CurrentTradePeriod,i_Type1MixedConstraint) = 1) and UseMixedConstraintMIP(CurrentTradePeriod))..
i_Type1MixedConstraintVarWeight(i_Type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(CurrentTradePeriod,i_Type1MixedConstraint)
*RDN - 20130226 - Only positive energy offers are included in the constraint
*+ sum(i_Offer $ Offer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintGenWeight(i_Type1MixedConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum(i_Offer $ PositiveEnergyOffer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintGenWeight(i_Type1MixedConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum((i_Offer,i_ReserveClass,i_ReserveType) $ Offer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintResWeight(i_Type1MixedConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintHVDCLineWeight(i_Type1MixedConstraint,i_Branch) * HVDCLINKFLOW(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintACLineWeight(i_Type1MixedConstraint,i_Branch) * sum(i_FlowDirection, ACBRANCHFLOWDIRECTED(CurrentTradePeriod,i_Branch,i_FlowDirection)))
+ sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintACLineLossWeight(i_Type1MixedConstraint,i_Branch) * sum(i_FlowDirection, ACBRANCHLOSSESDIRECTED(CurrentTradePeriod,i_Branch,i_FlowDirection)))
+ sum(i_Branch $ (ACBranch(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)), i_Type1MixedConstraintACLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) * ACBranchFixedLoss(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintHVDCLineLossWeight(i_Type1MixedConstraint,i_Branch) * HVDCLINKLOSSES(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ (HVDCLink(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)), i_Type1MixedConstraintHVDCLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) * HVDCLinkFixedLoss(CurrentTradePeriod,i_Branch))
+ sum(i_Bid $ Bid(CurrentTradePeriod,i_Bid), i_Type1MixedConstraintPurWeight(i_Type1MixedConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
+ DEFICITTYPE1MIXEDCONSTRAINT(CurrentTradePeriod,i_Type1MixedConstraint) =g=
Type1MixedConstraintLimit1(CurrentTradePeriod,i_Type1MixedConstraint) * (1 - MIXEDCONSTRAINTLIMIT2SELECT(CurrentTradePeriod,i_Type1MixedConstraint))
+ Type1MixedConstraintLimit2(CurrentTradePeriod,i_Type1MixedConstraint) * MIXEDCONSTRAINTLIMIT2SELECT(CurrentTradePeriod,i_Type1MixedConstraint)
;

*Integer equivalent of Type 1 mixed constraint definition with EQ sense (3.6.1.1b_MIP)
*Type1MixedConstraintEQ_MIP(Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint)) $ (i_UseMixedConstraint and (Type1MixedConstraintSense(CurrentTradePeriod,i_Type1MixedConstraint) = 0) and UseMixedConstraintMIP(CurrentTradePeriod))..
Type1MixedConstraintEQ_MIP(Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint)) $ (UseMixedConstraint(CurrentTradePeriod) and (Type1MixedConstraintSense(CurrentTradePeriod,i_Type1MixedConstraint) = 0) and UseMixedConstraintMIP(CurrentTradePeriod))..
i_Type1MixedConstraintVarWeight(i_Type1MixedConstraint) * MIXEDCONSTRAINTVARIABLE(CurrentTradePeriod,i_Type1MixedConstraint)
*RDN - 20130226 - Only positive energy offers are included in the constraint
*+ sum(i_Offer $ Offer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintGenWeight(i_Type1MixedConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum(i_Offer $ PositiveEnergyOffer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintGenWeight(i_Type1MixedConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum((i_Offer,i_ReserveClass,i_ReserveType) $ Offer(CurrentTradePeriod,i_Offer), i_Type1MixedConstraintResWeight(i_Type1MixedConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintHVDCLineWeight(i_Type1MixedConstraint,i_Branch) * HVDCLINKFLOW(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintACLineWeight(i_Type1MixedConstraint,i_Branch) * sum(i_FlowDirection, ACBRANCHFLOWDIRECTED(CurrentTradePeriod,i_Branch,i_FlowDirection)))
+ sum(i_Branch $ ACBranch(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintACLineLossWeight(i_Type1MixedConstraint,i_Branch) * sum(i_FlowDirection, ACBRANCHLOSSESDIRECTED(CurrentTradePeriod,i_Branch,i_FlowDirection)))
+ sum(i_Branch $ (ACBranch(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)), i_Type1MixedConstraintACLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) * ACBranchFixedLoss(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ HVDCLink(CurrentTradePeriod,i_Branch), i_Type1MixedConstraintHVDCLineLossWeight(i_Type1MixedConstraint,i_Branch) * HVDCLINKLOSSES(CurrentTradePeriod,i_Branch))
+ sum(i_Branch $ (HVDCLink(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)), i_Type1MixedConstraintHVDCLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) * HVDCLinkFixedLoss(CurrentTradePeriod,i_Branch))
+ sum(i_Bid $ Bid(CurrentTradePeriod,i_Bid), i_Type1MixedConstraintPurWeight(i_Type1MixedConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
+ DEFICITTYPE1MIXEDCONSTRAINT(CurrentTradePeriod,i_Type1MixedConstraint) - SURPLUSTYPE1MIXEDCONSTRAINT(CurrentTradePeriod,i_Type1MixedConstraint) =e=
Type1MixedConstraintLimit1(CurrentTradePeriod,i_Type1MixedConstraint) * (1 - MIXEDCONSTRAINTLIMIT2SELECT(CurrentTradePeriod,i_Type1MixedConstraint))
+ Type1MixedConstraintLimit2(CurrentTradePeriod,i_Type1MixedConstraint) * MIXEDCONSTRAINTLIMIT2SELECT(CurrentTradePeriod,i_Type1MixedConstraint)
;

*Generic security constraint with LE sense
GenericSecurityConstraintLE(CurrentTradePeriod,i_GenericConstraint) $ (GenericConstraintSense(CurrentTradePeriod,i_GenericConstraint) = -1)..
*RDN - 20130226 - Include only valid energy offers, bids and branch flows
*sum(i_Offer, GenericEnergyOfferConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
*+ sum((i_Offer,i_ReserveClass,i_ReserveType), GenericReserveOfferConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
*+ sum(i_Bid, GenericEnergyBidConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
*+ sum((i_Bid,i_ReserveClass), GenericILReserveBidConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Bid,i_ReserveClass) * PURCHASEILR(CurrentTradePeriod,i_Bid,i_ReserveClass))
*+ sum(i_Branch, GenericBranchConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Branch) * (ACBRANCHFLOW(CurrentTradePeriod,i_Branch) + HVDCLINKFLOW(CurrentTradePeriod,i_Branch)))
sum(i_Offer $ PositiveEnergyOffer(CurrentTradePeriod,i_Offer), GenericEnergyOfferConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum((i_Offer,i_ReserveClass,i_ReserveType) $ Offer(CurrentTradePeriod,i_Offer), GenericReserveOfferConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Bid $ Bid(CurrentTradePeriod,i_Bid), GenericEnergyBidConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
+ sum((i_Bid,i_ReserveClass) $ Bid(CurrentTradePeriod,i_Bid), GenericILReserveBidConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Bid,i_ReserveClass) * PURCHASEILR(CurrentTradePeriod,i_Bid,i_ReserveClass))
+ sum(i_Branch $ ((ACBranch(CurrentTradePeriod,i_Branch) or HVDCLink(CurrentTradePeriod,i_Branch)) and ClosedBranch(CurrentTradePeriod,i_Branch)), GenericBranchConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Branch) * (ACBRANCHFLOW(CurrentTradePeriod,i_Branch) + HVDCLINKFLOW(CurrentTradePeriod,i_Branch)))
- SURPLUSGENERICCONSTRAINT(CurrentTradePeriod,i_GenericConstraint) =l=
GenericConstraintLimit(CurrentTradePeriod,i_GenericConstraint)
;

*Generic security constraint with GE sense
GenericSecurityConstraintGE(CurrentTradePeriod,i_GenericConstraint) $ (GenericConstraintSense(CurrentTradePeriod,i_GenericConstraint) = 1)..
*RDN - 20130226 - Include only valid energy offers, bids and branch flows
*sum(i_Offer, GenericEnergyOfferConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
*+ sum((i_Offer,i_ReserveClass,i_ReserveType), GenericReserveOfferConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
*+ sum(i_Bid, GenericEnergyBidConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
*+ sum((i_Bid,i_ReserveClass), GenericILReserveBidConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Bid,i_ReserveClass) * PURCHASEILR(CurrentTradePeriod,i_Bid,i_ReserveClass))
*+ sum(i_Branch, GenericBranchConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Branch) * (ACBRANCHFLOW(CurrentTradePeriod,i_Branch) + HVDCLINKFLOW(CurrentTradePeriod,i_Branch)))
sum(i_Offer $ PositiveEnergyOffer(CurrentTradePeriod,i_Offer), GenericEnergyOfferConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum((i_Offer,i_ReserveClass,i_ReserveType) $ Offer(CurrentTradePeriod,i_Offer), GenericReserveOfferConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Bid $ Bid(CurrentTradePeriod,i_Bid), GenericEnergyBidConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
+ sum((i_Bid,i_ReserveClass) $ Bid(CurrentTradePeriod,i_Bid), GenericILReserveBidConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Bid,i_ReserveClass) * PURCHASEILR(CurrentTradePeriod,i_Bid,i_ReserveClass))
+ sum(i_Branch $ ((ACBranch(CurrentTradePeriod,i_Branch) or HVDCLink(CurrentTradePeriod,i_Branch)) and ClosedBranch(CurrentTradePeriod,i_Branch)), GenericBranchConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Branch) * (ACBRANCHFLOW(CurrentTradePeriod,i_Branch) + HVDCLINKFLOW(CurrentTradePeriod,i_Branch)))
+ DEFICITGENERICCONSTRAINT(CurrentTradePeriod,i_GenericConstraint) =g=
GenericConstraintLimit(CurrentTradePeriod,i_GenericConstraint)
;

*Generic security constraint with EQ sense
GenericSecurityConstraintEQ(CurrentTradePeriod,i_GenericConstraint) $ (GenericConstraintSense(CurrentTradePeriod,i_GenericConstraint) = 0)..
*RDN - 20130226 - Include only valid energy offers, bids and branch flows
*sum(i_Offer, GenericEnergyOfferConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
*+ sum((i_Offer,i_ReserveClass,i_ReserveType), GenericReserveOfferConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
*+ sum(i_Bid, GenericEnergyBidConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
*+ sum((i_Bid,i_ReserveClass), GenericILReserveBidConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Bid,i_ReserveClass) * PURCHASEILR(CurrentTradePeriod,i_Bid,i_ReserveClass))
*+ sum(i_Branch, GenericBranchConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Branch) * (ACBRANCHFLOW(CurrentTradePeriod,i_Branch) + HVDCLINKFLOW(CurrentTradePeriod,i_Branch)))
sum(i_Offer $ PositiveEnergyOffer(CurrentTradePeriod,i_Offer), GenericEnergyOfferConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Offer) * GENERATION(CurrentTradePeriod,i_Offer))
+ sum((i_Offer,i_ReserveClass,i_ReserveType) $ Offer(CurrentTradePeriod,i_Offer), GenericReserveOfferConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Offer,i_ReserveClass,i_ReserveType) * RESERVE(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
+ sum(i_Bid $ Bid(CurrentTradePeriod,i_Bid), GenericEnergyBidConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Bid) * PURCHASE(CurrentTradePeriod,i_Bid))
+ sum((i_Bid,i_ReserveClass) $ Bid(CurrentTradePeriod,i_Bid), GenericILReserveBidConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Bid,i_ReserveClass) * PURCHASEILR(CurrentTradePeriod,i_Bid,i_ReserveClass))
+ sum(i_Branch $ ((ACBranch(CurrentTradePeriod,i_Branch) or HVDCLink(CurrentTradePeriod,i_Branch)) and ClosedBranch(CurrentTradePeriod,i_Branch)), GenericBranchConstraintFactors(CurrentTradePeriod,i_GenericConstraint,i_Branch) * (ACBRANCHFLOW(CurrentTradePeriod,i_Branch) + HVDCLINKFLOW(CurrentTradePeriod,i_Branch)))
+ DEFICITGENERICCONSTRAINT(CurrentTradePeriod,i_GenericConstraint) - SURPLUSGENERICCONSTRAINT(CurrentTradePeriod,i_GenericConstraint) =e=
GenericConstraintLimit(CurrentTradePeriod,i_GenericConstraint)

*Model declarations

Model VSPD /
*Objective function
ObjectiveFunction
*Offer and purchase definitions
GenerationOfferDefintion, GenerationRampUp, GenerationRampDown, PurchaseBidDefintion
*RDN - Primary-secondary ramping constraints
GenerationRampUp_PS, GenerationRampDown_PS
*Network
HVDCLinkMaximumFlow, HVDCLinkLossDefinition, HVDCLinkFlowDefinition, LambdaDefinition, DCNodeNetInjection, ACNodeNetInjectionDefinition1, ACNodeNetInjectionDefinition2
ACBranchMaximumFlow, ACBranchFlowDefinition, LinearLoadFlow, ACBranchBlockLimit, ACDirectedBranchFlowDefinition, ACBranchLossCalculation, ACDirectedBranchLossDefinition
*Risk and Reserve
HVDCIslandRiskCalculation, HVDCRecCalculation, GenIslandRiskCalculation, ManualIslandRiskCalculation, PLSRReserveProportionMaximum, ReserveOfferDefinition
ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum, PurchaseBidReserveMaximum, MaximumIslandRiskDefinition, SupplyDemandReserveRequirement, RiskOffsetCalculation
*RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
*RiskOffSetCalculationApproximation
RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
*RDN - Island risk definition for different CE and ECE CVPs
MaximumIslandRiskDefinition_CE, MaximumIslandRiskDefinition_ECE
*RDN - Include HVDC secondary risk constraints
HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_Manual
*Branch security constraints
BranchSecurityConstraintLE, BranchSecurityConstraintGE, BranchSecurityConstraintEQ
*AC node security constraints
ACNodeSecurityConstraintLE, ACNodeSecurityConstraintGE, ACNodeSecurityConstraintEQ
*Market node security constraints
MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
*Mixed constraints
Type1MixedConstraintLE, Type1MixedConstraintGE, Type1MixedConstraintEQ, Type2MixedConstraintLE, Type2MixedConstraintGE, Type2MixedConstraintEQ
*Generic constraints
GenericSecurityConstraintLE, GenericSecurityConstraintGE, GenericSecurityConstraintEQ
*ViolationCost
TotalViolationCostDefinition
*RDN - Generator island risk calculation considering more than one offer per generator
GenIslandRiskCalculation_NonPS, GenIslandRiskCalculation_PS
HVDCIslandSecRiskCalculation_GEN_NonPS, HVDCIslandSecRiskCalculation_GEN_PS
/;


Model VSPD_MIP /
*Objective function
ObjectiveFunction
*Offer and purchase definitions
GenerationOfferDefintion, GenerationRampUp, GenerationRampDown, PurchaseBidDefintion
*RDN - Primary-secondary ramping constraints
GenerationRampUp_PS, GenerationRampDown_PS
*Network
HVDCLinkMaximumFlow, HVDCLinkLossDefinition, HVDCLinkFlowDefinition, LambdaDefinition, DCNodeNetInjection, ACNodeNetInjectionDefinition1, ACNodeNetInjectionDefinition2
ACBranchMaximumFlow, ACBranchFlowDefinition, LinearLoadFlow, ACBranchBlockLimit, ACDirectedBranchFlowDefinition, ACBranchLossCalculation, ACDirectedBranchLossDefinition
ACDirectedBranchFlowIntegerDefinition1, ACDirectedBranchFlowIntegerDefinition2
LambdaIntegerDefinition1, LambdaIntegerDefinition2
*Risk and Reserve
HVDCIslandRiskCalculation, HVDCRecCalculation, GenIslandRiskCalculation, ManualIslandRiskCalculation, PLSRReserveProportionMaximum, ReserveOfferDefinition
ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum, PurchaseBidReserveMaximum, MaximumIslandRiskDefinition, SupplyDemandReserveRequirement, RiskOffsetCalculation
*RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
*RiskOffSetCalculationApproximation
RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
*RDN - Island risk definition for different CE and ECE CVPs
MaximumIslandRiskDefinition_CE, MaximumIslandRiskDefinition_ECE
*RDN - Include HVDC secondary risk constraints
HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_Manual
*Branch security constraints
BranchSecurityConstraintLE, BranchSecurityConstraintGE, BranchSecurityConstraintEQ
*AC node security constraints
ACNodeSecurityConstraintLE, ACNodeSecurityConstraintGE, ACNodeSecurityConstraintEQ
*Market node security constraints
MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
*Mixed constraints
Type1MixedConstraintMIP, Type1MixedConstraintLE_MIP, Type1MixedConstraintGE_MIP, Type1MixedConstraintEQ_MIP, Type2MixedConstraintLE, Type2MixedConstraintGE, Type2MixedConstraintEQ
*Generic constraints
GenericSecurityConstraintLE, GenericSecurityConstraintGE, GenericSecurityConstraintEQ
*ViolationCost
TotalViolationCostDefinition
*RDN - Updated set of integer constraints on the HVDC link to incorporate the allowance of HVDC roundpower
HVDCLinkFlowIntegerDefinition1, HVDCLinkFlowIntegerDefinition2
HVDCLinkFlowIntegerDefinition3, HVDCLinkFlowIntegerDefinition4
*RDN - Generator island risk calculation considering more than one offer per generator
GenIslandRiskCalculation_NonPS, GenIslandRiskCalculation_PS
HVDCIslandSecRiskCalculation_GEN_NonPS, HVDCIslandSecRiskCalculation_GEN_PS
/;


Model VSPD_BranchFlowMIP /
*Objective function
ObjectiveFunction
*Offer and purchase definitions
GenerationOfferDefintion, GenerationRampUp, GenerationRampDown, PurchaseBidDefintion
*RDN - Primary-secondary ramping constraints
GenerationRampUp_PS, GenerationRampDown_PS
*Network
HVDCLinkMaximumFlow, HVDCLinkLossDefinition, HVDCLinkFlowDefinition, LambdaDefinition, DCNodeNetInjection, ACNodeNetInjectionDefinition1, ACNodeNetInjectionDefinition2
ACBranchMaximumFlow, ACBranchFlowDefinition, LinearLoadFlow, ACBranchBlockLimit, ACDirectedBranchFlowDefinition, ACBranchLossCalculation, ACDirectedBranchLossDefinition
ACDirectedBranchFlowIntegerDefinition1, ACDirectedBranchFlowIntegerDefinition2
LambdaIntegerDefinition1, LambdaIntegerDefinition2
*Risk and Reserve
HVDCIslandRiskCalculation, HVDCRecCalculation, GenIslandRiskCalculation, ManualIslandRiskCalculation, PLSRReserveProportionMaximum, ReserveOfferDefinition
ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum, PurchaseBidReserveMaximum, MaximumIslandRiskDefinition, SupplyDemandReserveRequirement, RiskOffsetCalculation
*RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
*RiskOffSetCalculationApproximation
RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
*RDN - Island risk definition for different CE and ECE CVPs
MaximumIslandRiskDefinition_CE, MaximumIslandRiskDefinition_ECE
*RDN - Include HVDC secondary risk constraints
HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_Manual
*Branch security constraints
BranchSecurityConstraintLE, BranchSecurityConstraintGE, BranchSecurityConstraintEQ
*AC node security constraints
ACNodeSecurityConstraintLE, ACNodeSecurityConstraintGE, ACNodeSecurityConstraintEQ
*Market node security constraints
MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
*Mixed constraints
Type1MixedConstraintLE, Type1MixedConstraintGE, Type1MixedConstraintEQ, Type2MixedConstraintLE, Type2MixedConstraintGE, Type2MixedConstraintEQ
*Generic constraints
GenericSecurityConstraintLE, GenericSecurityConstraintGE, GenericSecurityConstraintEQ
*ViolationCost
TotalViolationCostDefinition
*RDN - Updated set of intrger constraints on the HVDC link to incorporate the allowance of HVDC roundpower
HVDCLinkFlowIntegerDefinition1, HVDCLinkFlowIntegerDefinition2
HVDCLinkFlowIntegerDefinition3, HVDCLinkFlowIntegerDefinition4
*RDN - Generator island risk calculation considering more than one offer per generator
GenIslandRiskCalculation_NonPS, GenIslandRiskCalculation_PS
HVDCIslandSecRiskCalculation_GEN_NonPS, HVDCIslandSecRiskCalculation_GEN_PS
/;

Model VSPD_MixedConstraintMIP /
*Objective function
ObjectiveFunction
*Offer and purchase definitions
GenerationOfferDefintion, GenerationRampUp, GenerationRampDown, PurchaseBidDefintion
*RDN - Primary-secondary ramping constraints
GenerationRampUp_PS, GenerationRampDown_PS
*Network
HVDCLinkMaximumFlow, HVDCLinkLossDefinition, HVDCLinkFlowDefinition, LambdaDefinition, DCNodeNetInjection, ACNodeNetInjectionDefinition1, ACNodeNetInjectionDefinition2
ACBranchMaximumFlow, ACBranchFlowDefinition, LinearLoadFlow, ACBranchBlockLimit, ACDirectedBranchFlowDefinition, ACBranchLossCalculation, ACDirectedBranchLossDefinition
*Risk and Reserve
HVDCIslandRiskCalculation, HVDCRecCalculation, GenIslandRiskCalculation, ManualIslandRiskCalculation, PLSRReserveProportionMaximum, ReserveOfferDefinition
ReserveDefinitionPurchaseBid, EnergyAndReserveMaximum, PurchaseBidReserveMaximum, MaximumIslandRiskDefinition, SupplyDemandReserveRequirement, RiskOffsetCalculation
*RDN - Replace the risk offset approximation by the several different constraints as in formulation - these are eqiuvalent
*RiskOffSetCalculationApproximation
RiskOffsetCalculation_DCCE, RiskOffsetCalculation_DCECE
*RDN - Island risk definition for different CE and ECE CVPs
MaximumIslandRiskDefinition_CE, MaximumIslandRiskDefinition_ECE
*RDN - Include HVDC secondary risk constraints
HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_Manual
*Branch security constraints
BranchSecurityConstraintLE, BranchSecurityConstraintGE, BranchSecurityConstraintEQ
*AC node security constraints
ACNodeSecurityConstraintLE, ACNodeSecurityConstraintGE, ACNodeSecurityConstraintEQ
*Market node security constraints
MNodeSecurityConstraintLE, MNodeSecurityConstraintGE, MNodeSecurityConstraintEQ
*Mixed constraints
Type1MixedConstraintMIP, Type1MixedConstraintLE_MIP, Type1MixedConstraintGE_MIP, Type1MixedConstraintEQ_MIP, Type2MixedConstraintLE, Type2MixedConstraintGE, Type2MixedConstraintEQ
*Generic constraints
GenericSecurityConstraintLE, GenericSecurityConstraintGE, GenericSecurityConstraintEQ
*ViolationCost
TotalViolationCostDefinition
*RDN - Generator island risk calculation considering more than one offer per generator
GenIslandRiskCalculation_NonPS, GenIslandRiskCalculation_PS
HVDCIslandSecRiskCalculation_GEN_NonPS, HVDCIslandSecRiskCalculation_GEN_PS
/;

