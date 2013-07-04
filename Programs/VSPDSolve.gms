$ontext
===================================================================================
Name: VSPDModel.gms
Function: Base and override data read, data prepare and model solve.
Developed by: Ramu Naidoo  (Electricity Authority, New Zealand)
Last modified: 11 Mar 2013
===================================================================================
$offtext

*===================================================================================
*Include the run settings
*===================================================================================

$include vSPDpaths.inc
$include vSPDsettings.inc
$include vSPDcase.inc

*Update the runlog file
File runlog "Write to a report"      /  "%OutputPath%%runName%\%runName%_RunLog.txt" / ; runlog.lw = 0 ; runlog.ap = 1 ;
putclose runlog / 'Run: "%runName%"' / 'Case: "%VSPDInputData%" - started at ', system.time, ' on ' system.date;
if(i_SequentialSolve,
  putclose runlog / 'Vectorisation is switched OFF'
else
  putclose runlog / 'Vectorisation is switched ON'
) ;

*Set the solver for the LP and MIP
option lp = %Solver%;
option mip = %Solver%;

*Set profile status
option profile = 0;

*Set the solution print status in the lst file
option solprint = off;

*Set the column (variable) and row (equation) listing in the lst file
option limcol = 0;
option limrow = 0;

*Allow empty data set declaration
$onempty

*===================================================================================
*Data load and initialisation
*===================================================================================
*Loop through all study trade periods
*Create the model level inputs
*Solve the model for each trading period
*Store the model results for each trading period

*Initialise some fundemantal sets
SETS
i_Island /NI, SI/
i_ReserveClass /FIR, SIR/
i_ReserveType /PLSR, TWDR, ILR/

*RDN - Include additional ECE risk classes
*i_RiskClass /GENRISK, DCCE, DCECE, Manual/
i_RiskClass /GENRISK, DCCE, DCECE, Manual, GENRISK_ECE, Manual_ECE, HVDCSECRISK_CE, HVDCSECRISK_ECE/

i_ConstraintRHS /i_ConstraintSense, i_ConstraintLimit/

i_OfferType /ENERGY, PLSR, TWDR, ILR/
i_TradeBlock /t1*t20/
i_EnergyOfferComponent /i_GenerationMWOffer, i_GenerationMWOfferPrice/
*RDN - Include FKBandMW as part of the offer parameter inputs
*i_OfferParam /i_InitialMW, i_RampUpRate, i_RampDnRate, i_ReserveGenerationMaximum, i_WindOffer/
i_OfferParam /i_InitialMW, i_RampUpRate, i_RampDnRate, i_ReserveGenerationMaximum, i_WindOffer, i_FKBandMW/


i_EnergyBidComponent /i_BidMW, i_BidPrice/

i_FlowDirection /Forward, Backward/
i_LossParameter /i_MWBreakPoint, i_LossCoefficient/
i_LossSegment /ls1*ls10/
i_BranchParameter /i_BranchResistance, i_BranchSusceptance, i_BranchFixedLosses, i_NumLossTranches/

*RDN - HVDC poles
i_Pole /Pole1, Pole2/

i_RiskParameter /i_FreeReserve, i_RiskAdjustmentFactor, i_HVDCPoleRampUp/

i_ILRBidComponent /i_ILRBidMax, i_ILRBidPrice/
i_ILROfferComponent /i_ILROfferMax, i_ILROfferPrice/

i_PLSROfferComponent /i_PLSROfferPercentage, i_PLSROfferMax, i_PLSROfferPrice/
i_TWDROfferComponent /i_TWDROfferMax, i_TWDROfferPrice/

*RDN - Load the mixed constraint sets from the gdx
*i_Type1MixedConstraint /m1*m24/
*i_Type2MixedConstraint /b1*b6/
i_Type1MixedConstraintRHS /i_MixedConstraintSense, i_MixedConstraintLimit1, i_MixedConstraintLimit2/

i_CVP /i_DeficitBusGeneration, i_SurplusBusGeneration, i_Deficit6sReserve_CE, i_Deficit60sReserve_CE, i_DeficitBranchGroupConstraint, i_SurplusBranchGroupConstraint, i_DeficitGenericConstraint, i_SurplusGenericConstraint, i_DeficitRampRate, i_SurplusRampRate, i_DeficitACNodeConstraint, i_SurplusACNodeConstraint, i_DeficitBranchFlow, i_SurplusBranchFlow, i_DeficitMnodeConstraint, i_SurplusMnodeConstraint, i_Type1DeficitMixedConstraint, i_Type1SurplusMixedConstraint, i_Deficit6sReserve_ECE, i_Deficit60sReserve_ECE/
;

SETS
*Dispatch Results Reporting
o_FromDateTime(i_DateTime)                                                       'Start period for summary reports'
o_DateTime(i_DateTime)                                                           'Date and time for reporting'
o_Bus(i_DateTime,i_Bus)                                                          'Set of buses for output report'
o_Offer(i_DateTime,i_Offer)                                                      'Set of offers for output report'
o_Island(i_DateTime,i_Island)                                                    'Island definition for trade period reserve output report'
o_OfferTrader(i_Offer,i_Trader)                                                  'Mapping of offers to traders for offer summary reports'
o_Trader(i_Trader)                                                               'Set of traders for trader summary output report'
o_Node(i_DateTime,i_Node)                                                        'Set of nodes for output report'
o_Branch(i_DateTime,i_Branch)                                                    'Set of branches for output report'
o_BranchFromBus_TP(i_DateTime,i_Branch,i_FromBus)                                'From bus for set of branches for output report'
o_BranchToBus_TP(i_DateTime,i_Branch,i_ToBus)                                    'To bus for set of branches for output report'
o_BrConstraint_TP(i_DateTime,i_BranchConstraint)                                 'Set of branch constraints for output report'
o_MNodeConstraint_TP(i_DateTime,i_MNodeConstraint)                               'Set of mnode constraints for output report'

*TN - Audit report
o_BusIsland_TP(i_DateTime,i_Bus,i_Island)                                        'Bus Island Mapping for audit report'
o_MarketNodeIsland_TP(i_DateTime,i_Offer,i_Island)                               'Generation Offer Island Mapping for audit reporting'
*TN - Audit report - End
*RDN - Additional output for audit report - Start-------------------------------
o_OfferIsland_TP(i_DateTime,i_Offer,i_Island)                                       'Mapping of offers to island for audit reporting'
*RDN - Additional output for audit report - End-------------------------------
;

PARAMETERS
*Main iteration counter
IterationCount                                                                   'Iteration counter for the solve'
*MIP logic
BranchFlowMIPInvoked(i_TradePeriod)                                              'Flag to detect if branch flow MIP is needed'
CircularBranchFlowExist(i_TradePeriod,i_Branch)                                  'Flag to indicate if circulating branch flows exist on each branch: 1 = Yes'
*RDN - Introduce flag to detect circular branch flows on each HVDC pole
PoleCircularBranchFlowExist(i_TradePeriod,i_Pole)                                'Flag to indicate if circulating branch flows exist on each an HVDC pole: 1 = Yes'

NorthHVDC(i_TradePeriod)                                                         'HVDC MW sent from from SI to NI'
SouthHVDC(i_TradePeriod)                                                         'HVDC MW sent from from NI to SI'
NonPhysicalLossExist(i_TradePeriod,i_Branch)                                     'Flag to indicate if non-physical losses exist on branch: 1 = Yes'
ManualBranchSegmentMWFlow(i_TradePeriod,i_Branch,i_LossSegment)                  'Manual calculation of the branch loss segment MW flow'
ManualLossCalculation(i_TradePeriod,i_Branch)                                    'MW losses calculated manually from the solution for each loss branch'
HVDCHalfPoleSouthFlow(i_TradePeriod)                                             'Flag to indicate if south flow on HVDC halfpoles'
Type1MixedConstraintLimit2Violation(i_TradePeriod, i_Type1MixedConstraint)       'Type 1 mixed constraint MW violaton of the alternate limit value'

*RDN - Parameters to calculate circular branch flow on each HVDC pole
TotalHVDCPoleFlow(i_TradePeriod,i_Pole)                                          'Total flow on an HVDC pole'
MaxHVDCPoleFlow(i_TradePeriod,i_Pole)                                            'Maximum flow on an HVDC pole'

*Disconnected bus post-processing
BusGeneration(i_TradePeriod,i_Bus)                                               'MW generation at each bus for the study trade periods'
BusLoad(i_TradePeriod,i_Bus)                                                     'MW load at each bus for the study trade periods'
BusPrice(i_TradePeriod,i_Bus)                                                    '$/MW price at each bus for the study trade periods'
BusDisconnected(i_TradePeriod,i_Bus)                                             'Indication if bus is disconnected or not (1 = Yes) for the study trade periods'

*Dispatch Results Outputs for reporting
*Trade period level
o_IslandGen_TP(i_DateTime,i_Island)                                              'Island MW generation for the different time periods'
o_IslandLoad_TP(i_DateTime,i_Island)                                             'Island MW load for the different time periods'
o_SystemViolation_TP(i_DateTime,i_Island)                                        'Island MW violation for the different time periods'
o_IslandEnergyRevenue_TP(i_DateTime,i_Island)                                    'Island energy revenue ($) for the different time periods'
o_IslandReserveRevenue_TP(i_DateTime,i_Island)                                   'Island reserve revenue ($) for the different time periods'
o_IslandLoadCost_TP(i_DateTime,i_Island)                                         'Island load cost ($) for the different time periods'
o_IslandLoadRevenue_TP(i_DateTime,i_Island)                                      'Island load revenue ($) for the different time periods'
o_IslandBranchLoss_TP(i_DateTime,i_Island)                                       'Intra-island branch losses for the different time periods (MW)'
o_IslandRefPrice_TP(i_DateTime,i_Island)                                         'Reference prices in each island ($/MWh)'
o_HVDCFlow_TP(i_DateTime,i_Island)                                               'HVDC flow from each island (MW)'
o_HVDCLoss_TP(i_DateTime,i_Island)                                               'HVDC losses (MW)'
o_HVDCHalfPoleLoss_TP(i_DateTime,i_Island)                                       'Losses on HVDC half poles (MW)'
o_HVDCPoleFixedLoss_TP(i_DateTime,i_Island)                                      'Fixed loss on inter-island HVDC (MW)'
o_BusGeneration_TP(i_DateTime,i_Bus)                                             'Output MW generation at each bus for the different time periods'
o_BusLoad_TP(i_DateTime,i_Bus)                                                   'Output MW load at each bus for the different time periods'
o_BusPrice_TP(i_DateTime,i_Bus)                                                  'Output $/MW price at each bus for the different time periods'
o_BusDisconnected_TP(i_DateTime,i_Bus)                                           'Output disconnected bus flag (1 = Yes) for the different time periods'
o_BusRevenue_TP(i_DateTime,i_Bus)                                                'Generation revenue ($) at each bus for the different time periods'
o_BusCost_TP(i_DateTime,i_Bus)                                                   'Load cost ($) at each bus for the different time periods'
o_BusDeficit_TP(i_DateTime,i_Bus)                                                'Bus deficit violation for each trade period'
o_BusSurplus_TP(i_DateTime,i_Bus)                                                'Bus surplus violation for each trade period'
o_BranchFromBusPrice_TP(i_DateTime,i_Branch)                                     'Output from bus price ($/MW) for branch reporting'
o_BranchToBusPrice_TP(i_DateTime,i_Branch)                                       'Output to bus price ($/MW) for branch reporting'
o_BranchMarginalPrice_TP(i_DateTime,i_Branch)                                    'Output marginal branch constraint price ($/MW) for branch reporting'
o_BranchFlow_TP(i_DateTime,i_Branch)                                             'Output MW flow on each branch for the different time periods'
o_BranchDynamicLoss_TP(i_DateTime,i_Branch)                                      'Output MW dynamic loss on each branch for the different time periods'
o_BranchTotalLoss_TP(i_DateTime,i_Branch)                                        'Output MW total loss on each branch for the different time periods'
o_BranchFixedLoss_TP(i_DateTime,i_Branch)                                        'Output MW fixed loss on each branch for the different time periods'
o_BranchDynamicRentals_TP(i_DateTime,i_Branch)                                   'Output $ rentals on transmission branches using dynamic losses for the different time periods'
o_BranchTotalRentals_TP(i_DateTime,i_Branch)                                     'Output $ rentals on transmission branches using total (dynamic + fixed) for the different time periods'
o_BranchCapacity_TP(i_DateTime,i_Branch)                                         'Output MW branch capacity for branch reporting'
o_OfferEnergy_TP(i_DateTime,i_Offer)                                             'Output MW cleared for each energy offer for each trade period'
o_OfferFIR_TP(i_DateTime,i_Offer)                                                'Output MW cleared for FIR for each trade period'
o_OfferSIR_TP(i_DateTime,i_Offer)                                                'Output MW cleared for SIR for each trade period'
o_BidEnergy_TP(i_DateTime,i_Bid)                                                 'Output MW cleared for each energy bid for each trade period'
o_BidReserve_TP(i_DateTime,i_Bid,i_ReserveClass)                                 'Output MW cleared for each reserve bid for each trade period'
o_FIRReqd_TP(i_DateTime,i_Island)                                                'Output MW required FIR for each trade period'
o_SIRReqd_TP(i_DateTime,i_Island)                                                'Output MW required SIR for each trade period'
o_FIRPrice_TP(i_DateTime,i_Island)                                               'Output $/MW price for FIR reserve classes for each trade period'
o_SIRPrice_TP(i_DateTime,i_Island)                                               'Output $/MW price for SIR reserve classes for each trade period'
o_FIRViolation_TP(i_DateTime,i_Island)                                           'Violtaiton MW for FIR reserve classes for each trade period'
o_SIRViolation_TP(i_DateTime,i_Island)                                           'Violtaiton MW for SIR reserve classes for each trade period'
o_NodeGeneration_TP(i_DateTime,i_Node)                                           'Ouput MW generation at each node for the different time periods'
o_NodeLoad_TP(i_DateTime,i_Node)                                                 'Ouput MW load at each node for the different time periods'
o_NodePrice_TP(i_DateTime,i_Node)                                                'Output $/MW price at each node for the different time periods'
o_NodeRevenue_TP(i_DateTime,i_Node)                                              'Output $ revenue at each node for the different time periods'
o_NodeCost_TP(i_DateTime,i_Node)                                                 'Output $ cost at each node for the different time periods'
o_NodeDeficit_TP(i_DateTime,i_Node)                                              'Output node deficit violation for each trade period'
o_NodeSurplus_TP(i_DateTime,i_Node)                                              'Output node surplus violation for each trade period'
*Security constraint data
o_BrConstraintSense_TP(i_DateTime,i_BranchConstraint)                            'Branch constraint sense for each output report'
o_BrConstraintLHS_TP(i_DateTime,i_BranchConstraint)                              'Branch constraint LHS for each output report'
o_BrConstraintRHS_TP(i_DateTime,i_BranchConstraint)                              'Branch constraint RHS for each output report'
o_BrConstraintPrice_TP(i_DateTime,i_BranchConstraint)                            'Branch constraint price for each output report'
*MNode constraint data
o_MNodeConstraintSense_TP(i_DateTime,i_MNodeConstraint)                          'Market node constraint sense for each output report'
o_MNodeConstraintLHS_TP(i_DateTime,i_MNodeConstraint)                            'Market node constraint LHS for each output report'
o_MNodeConstraintRHS_TP(i_DateTime,i_MNodeConstraint)                            'Market node constraint RHS for each output report'
o_MNodeConstraintPrice_TP(i_DateTime,i_MNodeConstraint)                          'Market node constraint price for each output report'

*TradePeriod summary report
o_SolveOK_TP(i_DateTime)                                                         'Solve status for summary report (1=OK)'
o_SystemCost_TP(i_DateTime)                                                      'System cost for summary report'
o_DefGenViolation_TP(i_DateTime)                                                 'Deficit generation violation for summary report'
o_SurpGenViolation_TP(i_DateTime)                                                'Surplus generaiton violation for summary report'
o_SurpBranchFlow_TP(i_DateTime)                                                  'Surplus branch flow violation for summary report'
o_DefRampRate_TP(i_DateTime)                                                     'Deficit ramp rate violation for summary report'
o_SurpRampRate_TP(i_DateTime)                                                    'Surplus ramp rate violation for summary report'
o_SurpBranchGroupConst_TP(i_DateTime)                                            'Surplus branch group constraint violation for summary report'
o_DefBranchGroupConst_TP(i_DateTime)                                             'Deficit branch group constraint violation for summary report'
o_DefMNodeConst_TP(i_DateTime)                                                   'Deficit market node constraint violation for summary report'
o_SurpMNodeConst_TP(i_DateTime)                                                  'Surplus market node constraint violation for summary report'
o_DefACNodeConst_TP(i_DateTime)                                                  'Deficit AC node constraint violation for summary report'
o_SurpACNodeConst_TP(i_DateTime)                                                 'Surplus AC node constraint violation for summary report'
o_DefT1MixedConst_TP(i_DateTime)                                                 'Deficit Type1 mixed constraint violation for sumamry report'
o_SurpT1MixedConst_TP(i_DateTime)                                                'Surplus Type1 mixed constraint violation for summary report'
o_DefGenericConst_TP(i_DateTime)                                                 'Deficit generic constraint violation for summary report'
o_SurpGenericConst_TP(i_DateTime)                                                'Surplus generic constraint violation for summary report'
o_DefResv_TP(i_DateTime)                                                         'Deficit reserve violation for summary report'
o_TotalViolation_TP(i_DateTime)                                                  'Total violation for datawarehouse summary report'

*System level
o_NumTradePeriods                                                                'Output number of trade periods in summary'
o_SystemOFV                                                                      'System objective function value'
o_SystemGen                                                                      'Output system MWh generation'
o_SystemLoad                                                                     'Output system MWh load'
o_SystemLoss                                                                     'Output system MWh loss'
o_SystemViolation                                                                'Output system MWh violation'
o_SystemFIR                                                                      'Output system FIR MWh reserve'
o_SystemSIR                                                                      'Output system SIR MWh reserve'
o_SystemEnergyRevenue                                                            'Output offer energy revenue $'
o_SystemReserveRevenue                                                           'Output reserve revenue $'
o_SystemLoadCost                                                                 'Output system load cost $'
o_SystemLoadRevenue                                                              'Output system load revenue $'
o_SystemSurplus                                                                  'Output system surplus $'
o_SystemACRentals                                                                'Output system AC rentals $'
o_SystemDCRentals                                                                'Output system DC rentals $'
*Offer level
o_OfferGen(i_Offer)                                                              'Output offer generation (MWh)'
o_OfferFIR(i_Offer)                                                              'Output offer FIR (MWh)'
o_OfferSIR(i_Offer)                                                              'Output offer SIR (MWh)'
o_OfferGenRevenue(i_Offer)                                                       'Output offer energy revenue ($)'
o_OfferFIRRevenue(i_Offer)                                                       'Output offer FIR revenue ($)'
o_OfferSIRRevenue(i_Offer)                                                       'Output offer SIR revenue ($)'
*Trader level
o_TraderGen(i_Trader)                                                            'Output trader generation (MWh)'
o_TraderFIR(i_Trader)                                                            'Output trader FIR (MWh)'
o_TraderSIR(i_Trader)                                                            'Output trader SIR (MWh)'
o_TraderGenRevenue(i_Trader)                                                     'Output trader energy revenue ($)'
o_TraderFIRRevenue(i_Trader)                                                     'Output trader FIR revenue ($)'
o_TraderSIRRevenue(i_Trader)                                                     'Output trader SIR revenue ($)'

*TN - Additional output for audit reporting
o_LossSegmentBreakPoint(i_DateTime,i_Branch,i_LossSegment)                       'MW capacity of each loss segment for audit'
o_LossSegmentFactor(i_DateTime,i_Branch,i_LossSegment)                           'Loss factor of each loss segment for audit'

o_ACBusAngle(i_DateTime,i_Bus)                                                   'Bus voltage angle for audit reporting'
o_NonPhysicalLoss(i_DateTime,i_Branch)                                           'MW losses calculated manually from the solution for each loss branch'
o_BranchConstrained_TP(i_DateTime,i_Branch)                                      'Output flag if branch constrained'

o_ILRO_FIR_TP(i_DateTime,i_Offer)                                                              'Output IL offer FIR (MWh)'
o_ILRO_SIR_TP(i_DateTime,i_Offer)                                                              'Output IL offer SIR (MWh)'
o_ILBus_FIR_TP(i_DateTime,i_Bus)                                                               'Output IL offer FIR (MWh)'
o_ILBus_SIR_TP(i_DateTime,i_Bus)                                                               'Output IL offer SIR (MWh)'
o_PLRO_FIR_TP(i_DateTime,i_Offer)                                                              'Output PLSR offer FIR (MWh)'
o_PLRO_SIR_TP(i_DateTime,i_Offer)                                                              'Output PLSR SIR (MWh)'
o_TWRO_FIR_TP(i_DateTime,i_Offer)                                                              'Output TWR FIR (MWh)'
o_TWRO_SIR_TP(i_DateTime,i_Offer)                                                              'Output TWR SIR (MWh)'

o_GenerationRiskSetter(i_DateTime,i_Island,i_Offer,i_ReserveClass,i_RiskClass)                    'For Audit'
o_GenerationRiskSetterMax(i_DateTime,i_Island,i_Offer,i_ReserveClass)                             'For Audit'
o_GenHVDCRiskSetter(i_DateTime,i_Island,i_Offer,i_ReserveClass,i_RiskClass)                       'For Audit'
o_HVDCRiskSetter(i_DateTime,i_Island,i_ReserveClass,i_RiskClass)                                  'For Audit'
o_MANURiskSetter(i_DateTime,i_Island,i_ReserveClass,i_RiskClass)                                  'For Audit'
o_MANUHVDCRiskSetter(i_DateTime,i_Island,i_ReserveClass,i_RiskClass)                              'For Audit'
*TN - Additional output for audit reporting - End

*RDN - Additional output for Audit risk report - Start--------------------------
o_HVDCRiskSetterMax(i_DateTime,i_Island,i_ReserveClass)                                           'For Audit'
o_GenHVDCRiskSetterMax(i_DateTime,i_Island,i_Offer,i_ReserveClass)                                'For Audit'
o_MANUHVDCRiskSetterMax(i_DateTime,i_Island,i_ReserveClass)                                       'For Audit'
o_MANURiskSetterMax(i_DateTime,i_Island,i_ReserveClass)                                           'For Audit'
o_FIRCleared_TP(i_DateTime,i_Island)                                                              'For Audit'
o_SIRCleared_TP(i_DateTime,i_Island)                                                              'For Audit'
*RDN - Additional output for Audit risk report - Start--------------------------


*RDN - Update the deficit and surplus reporting at the nodal level - Start------
TotalBusAllocation(i_DateTime,i_Bus)                                                             'Total allocation of nodes to bus'
BusNodeAllocationFactor(i_DateTime,i_Bus,i_Node)                                                 'Bus to node allocation factor'
*RDN - Update the deficit and surplus reporting at the nodal level - End--------

*RDN - 20130302 - i_TradePeriodNodeBusAllocationFactor update - Start-----------
*Introduce i_UseBusNetworkModel to account for MSP change-over date when for half of the day the old
*market node model and the other half the bus network model was used.
i_UseBusNetworkModel(i_TradePeriod)                                                              'Indicates if the post-MSP bus network model is used in vSPD (1 = Yes)'
*RDN - 20130302 - i_TradePeriodNodeBusAllocationFactor update - End-----------
;

SCALARS
ModelSolved                      'Flag to indicate if the model solved successfully (1 = Yes)'                                           /0/
LPModelSolved                    'Flag to indicate if the final LP model (when MIP fails) is solved successfully (1 = Yes)'              /0/
SkipResolve                      'Flag to indicate if the integer resolve logic needs to be skipped and resolved in sequential mode'     /0/
LPValid                          'Flag to indicate if the LP solution is valid (1 = Yes)'                                                /0/
NumTradePeriods                  'Number of trade periods in the solve'                                                                  /0/
ThresholdSimultaneousInteger     'Threshold number of trade periods for which to skip the integer resolve in simultanous mode and repeat in sequential mode' /1/
*RDN - Flag to use the extended set of risk classes which include the GENRISK_ECE and Manual_ECE
i_UseExtendedRiskClass           'Use the extended set of risk classes (1 = Yes)'                                                        /0/
;

*RDN - Temporary file name
Files
temp
;

* Start data load
* Call the GDX routine and load the input data:
* $GDXIN "%InputPath%%VSPDInputData%"
* Include gdx extension within the code to facilitate standalone mode - need to ensure that the extension is ommitted from the vSPDpaths.inc file
*If file does not exist then go to the next input file
$if not exist "%InputPath%%VSPDInputData%.gdx" $ goto NextInput
$GDXIN "%InputPath%%VSPDInputData%.gdx"
*$GDXIN "%VSPDInputData%"

$LOAD i_TradePeriod i_DateTime i_Offer i_Trader i_Bid i_Node i_Bus i_Branch i_BranchConstraint i_ACNodeConstraint i_MNodeConstraint i_GenericConstraint
$LOAD i_ACLineUnit i_TradingPeriodLength i_CVPValues i_BranchReceivingEndLossProportion
$LOAD i_DateTimeTradePeriodMap i_TradePeriodOfferNode i_TradePeriodOfferTrader i_TradePeriodBidNode i_TradePeriodBidTrader i_TradePeriodNode
$LOAD i_TradePeriodBusIsland i_TradePeriodBus i_TradePeriodNodeBus i_TradePeriodBranchDefn i_TradePeriodRiskGenerator
*RDN - Load mixed constraint sets from gdx
$LOAD i_Type1MixedConstraint i_Type2MixedConstraint
$LOAD i_Type1MixedConstraintReserveMap i_TradePeriodType1MixedConstraint i_TradePeriodType2MixedConstraint i_Type1MixedConstraintBranchCondition i_TradePeriodGenericConstraint
$LOAD i_StudyTradePeriod i_TradePeriodOfferParameter i_TradePeriodEnergyOffer i_TradePeriodSustainedPLSROffer i_TradePeriodFastPLSROffer i_TradePeriodSustainedTWDROffer i_TradePeriodFastTWDROffer
$LOAD i_TradePeriodSustainedILROffer i_TradePeriodFastILROffer i_TradePeriodNodeDemand i_TradePeriodHVDCNode i_TradePeriodReferenceNode i_TradePeriodHVDCBranch
$LOAD i_TradePeriodEnergyBid i_TradePeriodSustainedILRBid i_TradePeriodFastILRBid
$LOAD i_TradePeriodBranchParameter i_TradePeriodBranchCapacity i_TradePeriodBranchOpenStatus
$LOAD i_NoLossBranch i_ACLossBranch i_HVDCLossBranch i_TradePeriodNodeBusAllocationFactor i_TradePeriodBusElectricalIsland
$LOAD i_TradePeriodRiskParameter i_TradePeriodManualRisk
$LOAD i_TradePeriodBranchConstraintFactors i_TradePeriodBranchConstraintRHS i_TradePeriodACNodeConstraintFactors i_TradePeriodACNodeConstraintRHS
$LOAD i_TradePeriodMNodeEnergyOfferConstraintFactors i_TradePeriodMNodeReserveOfferConstraintFactors i_TradePeriodMNodeEnergyBidConstraintFactors i_TradePeriodMNodeILReserveBidConstraintFactors i_TradePeriodMNodeConstraintRHS
$LOAD i_Type1MixedConstraintVarWeight i_Type1MixedConstraintGenWeight i_Type1MixedConstraintResWeight i_Type1MixedConstraintHVDCLineWeight i_TradePeriodType1MixedConstraintRHSParameters i_Type2MixedConstraintLHSParameters i_TradePeriodType2MixedConstraintRHSParameters
$LOAD i_TradePeriodGenericEnergyOfferConstraintFactors i_TradePeriodGenericReserveOfferConstraintFactors i_TradePeriodGenericEnergyBidConstraintFactors
$LOAD i_TradePeriodGenericILReserveBidConstraintFactors i_TradePeriodGenericBranchConstraintFactors i_TradePeriodGenericConstraintRHS
*Load day, month and year
$LOAD i_Day i_Month i_Year
*Close the gdx
$GDXIN

*===================================================================================
*Model compatilibility
*===================================================================================
*This section manages to changes to model flags to ensure backward compatibility of vSPD
*given changes in the SPD model formulation
*RDN - Conditional load of some GDX data depending on when they were included into the GDX files
*Data loaded at execution time whereas the previous load is at compile time
Parameters
InputGDXGDate                    'Gregorian date of input GDX file'
;

*Gregorian date of when parameters have been included into the GDX files and therefore conditionally loaded
*17 Oct 2011 = 40832
*01 May 2012 = 41029
*28 Jun 2012 = 41087
*20 Sep 2012 = 41171
*12 Jan 2013 = 41285
*24 Feb 2013 = 41328

Scalars
MixedConstraintRiskOffsetGDXGDate        /40832/
PrimarySecondaryGDXGDate                 /41029/
*RDN - Change to demand bid
DemandBidChangeGDXGDate                  /41087/
*RDN - Change to demand bid - End
HVDCRoundPowerGDXGDate                   /41171/
MinimumRiskECEGDXGDate                   /41171/
HVDCSecRiskGDXGDate                      /41171/
AddnMixedConstraintVarGDXGDate           /41328/
ReserveClassGenMaxGDXGDate               /41328/
PrimSecGenRiskModelGDXGDate              /41328/
*RDN - 20130302 - Introduce MSP change-over date to account for change in the node-bus allocation
*factor from the input gdx files
MSPChangeOverGDXGDate                    /40014/
;

*Calculate the Gregorian date of the input data
InputGDXGDate = jdate(i_Year,i_Month,i_Day);

put_utility temp 'gdxin' / '%InputPath%%VSPDInputData%.gdx';

*Conditional load of i_TradePeriodPriamrySecondary set
if (InputGDXGDate >= PrimarySecondaryGDXGDate,
    execute_load i_TradePeriodPrimarySecondaryOffer;
else
    i_TradePeriodPrimarySecondaryOffer(i_TradePeriod,i_Offer,i_Offer1) = no;
);

*Conditional load of i_TradePeriodManualRisk_ECE parameter
if (InputGDXGDate >= MinimumRiskECEGDXGDate,
*RDN - Set the use extended risk class flag
    i_UseExtendedRiskClass = 1;
    execute_load i_TradePeriodManualRisk_ECE;
else
    i_TradePeriodManualRisk_ECE(i_TradePeriod,i_Island,i_ReserveClass) = 0;
);

*Conditional load of HVDC secondary risk parameters
if (InputGDXGDate >= HVDCSecRiskGDXGDate,
    execute_load i_TradePeriodHVDCSecRiskEnabled, i_TradePeriodHVDCSecRiskSubtractor;
else
    i_TradePeriodHVDCSecRiskEnabled(i_TradePeriod,i_Island,i_RiskClass) = 0;
    i_TradePeriodHVDCSecRiskSubtractor(i_TradePeriod,i_Island) = 0;
);

*Conditional load of i_TradePeriodAllowHVDCRoundpower parameter
if (InputGDXGDate >= HVDCRoundPowerGDXGDate,
    execute_load i_TradePeriodAllowHVDCRoundpower;
else
    i_TradePeriodAllowHVDCRoundpower(i_TradePeriod) = 0;
);

*Conditional load of additional mixed constraint parameters
if (InputGDXGDate >= AddnMixedConstraintVarGDXGDate,
    execute_load i_Type1MixedConstraintACLineWeight, i_Type1MixedConstraintACLineLossWeight, i_Type1MixedConstraintACLineFixedLossWeight
                 i_Type1MixedConstraintHVDCLineLossWeight, i_Type1MixedConstraintHVDCLineFixedLossWeight, i_Type1MixedConstraintPurWeight;
else
    i_Type1MixedConstraintACLineWeight(i_Type1MixedConstraint,i_Branch) = 0;
    i_Type1MixedConstraintACLineLossWeight(i_Type1MixedConstraint,i_Branch) = 0;
    i_Type1MixedConstraintACLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) = 0;
    i_Type1MixedConstraintHVDCLineLossWeight(i_Type1MixedConstraint,i_Branch) = 0;
    i_Type1MixedConstraintHVDCLineFixedLossWeight(i_Type1MixedConstraint,i_Branch) = 0;
    i_Type1MixedConstraintPurWeight(i_Type1MixedConstraint,i_Bid) = 0;
);

*Conditional load of reserve class generation parameter
if (InputGDXGDate >= ReserveClassGenMaxGDXGDate,
    execute_load i_TradePeriodReserveClassGenerationMaximum;
else
    i_TradePeriodReserveClassGenerationMaximum(i_TradePeriod,i_Offer,i_ReserveClass) = 0;
);

*RDN - Switch off the mixed constraint based risk offset calculation after 17 October 2011 (data stopped being populated in GDX file)
i_UseMixedConstraintRiskOffset = 1 $(InputGDXGDate < MixedConstraintRiskOffsetGDXGDate);

*RDN - Switch off mixed constraint formulation if no data coming through
*i_UseMixedConstraint $ (sum(i_Type1MixedConstraint, i_Type1MixedConstraintVarWeight(i_Type1MixedConstraint))=0) = 0;
UseMixedConstraint(i_TradePeriod) $ (i_UseMixedConstraint and (sum(i_Type1MixedConstraint $ i_TradePeriodType1MixedConstraint(i_TradePeriod,i_Type1MixedConstraint),1))) = 1;

*RDN - Do not use the extended risk class if no data coming through
i_UseExtendedRiskClass $ (sum((i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass,i_RiskParameter) $ (ord(i_RiskClass) > 4), i_TradePeriodRiskParameter(i_TradePeriod,i_Island,i_ReserveClass,i_RiskClass,i_RiskParameter))=0) = 0;

*RDN - Change to demand bid
UseDSBFDemandBidModel = 1 $(InputGDXGDate >= DemandBidChangeGDXGDate);
*RDN - Change to demand bid - End

*RDN - Use the risk model that accounts for multiple offers per generating unit
UsePrimSecGenRiskModel = 1 $(InputGDXGDate >= PrimSecGenRiskModelGDXGDate);

*RDN - 20130302 - i_TradePeriodNodeBusAllocationFactor update - Start--------
*Introduce i_UseBusNetworkModel to account for MSP change-over date when for half of the day the old
*market node model and the other half the bus network model was used. The old market model does not
*have the i_TradePeriodBusElectrical island paramter specified since it uses the market node network
*model. This flag is introduced to allow the i_TradePeriodBusElectricalIsland parameter to be used
*in the post-MSP solves to indentify 'dead' electrical buses.
i_UseBusNetworkModel(i_TradePeriod) = 1 $ ((InputGDXGDate >= MSPChangeOverGDXGDate)
                                           and
                                           sum(i_Bus, i_TradePeriodBusElectricalIsland(i_TradePeriod,i_Bus))
                                          );
*RDN - 20130302 - i_TradePeriodNodeBusAllocationFactor update - End----------

*===================================================================================
*Overrides - Define and apply
*===================================================================================
*Define additional override parameters
*Read in the values from the override xls or GDX
*These are used to override the respective values from the input data.

Parameters
*Override
i_TradePeriodSolve(i_TradePeriod)                                                'Trade periods to solve'
i_EnergyOfferOvrd(i_TradePeriod,i_Offer,i_TradeBlock,i_EnergyOfferComponent)     'Override for energy offers for specified trade period'
i_OfferParamOvrd(i_TradePeriod,i_Offer,i_OfferParam)                             'Override for energy offer parameters for specified trade period'

i_NodeDemandOvrd(i_TradePeriod,i_Node)                                           'Override MW nodal demand for specified trade period'
i_IslandDemandOvrd(i_TradePeriod,i_Island)                                       'Scaling factor for island demand for specified trade period'
TradePeriodNodeDemandTemp(i_TradePeriod,i_Node)                                  'Temp trade period node demand for override calculations'
;

* Load the override parameters
* Import override input parameters from Excel data file via GDX.
* Write arguments for the GDX call to gdxVSPDInputOvrdData.ins:
$ONECHO > gdxVSPDInputOvrdData.ins
* Parameters and sets
         par = i_TradePeriodSolve                  rng = i_TradePeriodSolve                      rdim = 1
         par = i_EnergyOfferOvrd                   rng = i_EnergyOfferOvrd                       rdim = 4
         par = i_OfferParamOvrd                    rng = i_OfferParamOvrd                        rdim = 3
         par = i_NodeDemandOvrd                    rng = i_NodeDemandOvrd                        rdim = 2
         par = i_IslandDemandOvrd                  rng = i_IslandDemandOvrd                      rdim = 2
$OFFECHO

* Call the GDX routine and load the input data:
$if %VSPDInputOvrdFormat%==2 $CALL 'GDXXRW "%OvrdPath%%VSPDInputOvrdData%.xls" o=VSPDInputOvrdData.gdx "@gdxVSPDInputOvrdData.ins"'
$if %VSPDInputOvrdFormat%==2 $GDXIN VSPDInputOvrdData.gdx

$if %VSPDInputOvrdFormat%==1 $GDXIN "%OvrdPath%VSPDInputOvrdData.gdx"

* Call the GDX routine and load the override data:
*$GDXIN "%OvrdPath%%VSPDInputOvrdData%"

$LOAD i_TradePeriodSolve i_EnergyOfferOvrd i_OfferParamOvrd i_NodeDemandOvrd i_IslandDemandOvrd
*Close the gdx
$GDXIN

*Apply overrides

*Set the trade periods to solve
i_StudyTradePeriod(i_TradePeriod) = 0;
i_StudyTradePeriod(i_TradePeriod) $ i_TradePeriodSolve(i_TradePeriod) = 1;

*Island Demand
TradePeriodNodeDemandTemp(i_TradePeriod,i_Node) = 0;
TradePeriodNodeDemandTemp(i_TradePeriod,i_Node) = i_TradePeriodNodeDemand(i_TradePeriod,i_Node);
*Apply island scaling factor to a node if scaling factor > 0 and the node demand > 0
i_TradePeriodNodeDemand(i_TradePeriod,i_Node) $ ((TradePeriodNodeDemandTemp(i_TradePeriod,i_Node) > 0) and (sum((i_Bus,i_Island) $ (i_TradePeriodNodeBus(i_TradePeriod,i_Node,i_Bus) and i_TradePeriodBusIsland(i_TradePeriod,i_Bus,i_Island)), i_IslandDemandOvrd(i_TradePeriod,i_Island)) > 0))
   = sum((i_Bus,i_Island) $ (i_TradePeriodNodeBus(i_TradePeriod,i_Node,i_Bus) and i_TradePeriodBusIsland(i_TradePeriod,i_Bus,i_Island)), i_TradePeriodNodeBusAllocationFactor(i_TradePeriod,i_Node,i_Bus) * i_IslandDemandOvrd(i_TradePeriod,i_Island)) * TradePeriodNodeDemandTemp(i_TradePeriod,i_Node);
*Apply island scaling factor to a node if scaling factor = Eps (0) and the node demand > 0
i_TradePeriodNodeDemand(i_TradePeriod,i_Node) $ ((TradePeriodNodeDemandTemp(i_TradePeriod,i_Node) > 0) and (sum((i_Bus,i_Island) $ (i_TradePeriodNodeBus(i_TradePeriod,i_Node,i_Bus) and i_TradePeriodBusIsland(i_TradePeriod,i_Bus,i_Island) and i_IslandDemandOvrd(i_TradePeriod,i_Island) and (i_IslandDemandOvrd(i_TradePeriod,i_Island) = Eps)), 1) > 0))
   = sum((i_Bus,i_Island) $ (i_TradePeriodNodeBus(i_TradePeriod,i_Node,i_Bus) and i_TradePeriodBusIsland(i_TradePeriod,i_Bus,i_Island)), i_TradePeriodNodeBusAllocationFactor(i_TradePeriod,i_Node,i_Bus) * 0) * TradePeriodNodeDemandTemp(i_TradePeriod,i_Node);

*Node demand
i_TradePeriodNodeDemand(i_TradePeriod,i_Node) $ i_NodeDemandOvrd(i_TradePeriod,i_Node) = i_NodeDemandOvrd(i_TradePeriod,i_Node);
i_TradePeriodNodeDemand(i_TradePeriod,i_Node) $ (i_NodeDemandOvrd(i_TradePeriod,i_Node) and (i_NodeDemandOvrd(i_TradePeriod,i_Node) = Eps)) = 0;

*Energy offer
i_TradePeriodEnergyOffer(i_TradePeriod,i_Offer,i_TradeBlock,i_EnergyOfferComponent) $ (i_EnergyOfferOvrd(i_TradePeriod,i_Offer,i_TradeBlock,i_EnergyOfferComponent) > 0) = i_EnergyOfferOvrd(i_TradePeriod,i_Offer,i_TradeBlock,i_EnergyOfferComponent);
i_TradePeriodEnergyOffer(i_TradePeriod,i_Offer,i_TradeBlock,i_EnergyOfferComponent) $ (i_EnergyOfferOvrd(i_TradePeriod,i_Offer,i_TradeBlock,i_EnergyOfferComponent) and (i_EnergyOfferOvrd(i_TradePeriod,i_Offer,i_TradeBlock,i_EnergyOfferComponent) = Eps)) = 0;

i_TradePeriodOfferParameter(i_TradePeriod,i_Offer,i_OfferParam) $ (i_OfferParamOvrd(i_TradePeriod,i_Offer,i_OfferParam) > 0) = i_OfferParamOvrd(i_TradePeriod,i_Offer,i_OfferParam);
i_TradePeriodOfferParameter(i_TradePeriod,i_Offer,i_OfferParam) $ (i_OfferParamOvrd(i_TradePeriod,i_Offer,i_OfferParam) and (i_OfferParamOvrd(i_TradePeriod,i_Offer,i_OfferParam) = Eps)) = 0;


*===================================================================================
*Initialise CVPs
*===================================================================================
*Allocation of constraint violation penalties from input data

Parameters
CVPChangeGDate                   'Gregorian date of CE and ECE CVP change'
;

*Set the flag for the application of the different CVPs for CE and ECE
*If the user selects No (0), this default value of the DiffCeECeCVP flag will be used.
DiffCeECeCVP = 0;

*Calculate the Gregorian date of the CE and ECE change - Based on CAN from www.systemoperator.co.nz this was on 24th June 2010
CVPChangeGDate = jdate(2010,06,24);

*If the user selects Auto (-1), set the DiffCeECeCVP flag if the input date is greater than or equal to this date
DiffCeECeCVP $ ((InputGDXGDate >= CVPChangeGDate) and (%VarResv% = -1)) = 1;
*If the user selects Yes (1), set the DiffCeECeCVP flag
DiffCeECeCVP $ (%VarResv% = 1) = 1;

DeficitBusGenerationPenalty                                              = sum(i_CVP $ (ord(i_CVP) = 1), i_CVPValues(i_CVP));
SurplusBusGenerationPenalty                                              = sum(i_CVP $ (ord(i_CVP) = 2), i_CVPValues(i_CVP));
DeficitReservePenalty(i_ReserveClass) $ (ord(i_ReserveClass) = 1)        = sum(i_CVP $ (ord(i_CVP) = 3), i_CVPValues(i_CVP));
DeficitReservePenalty(i_ReserveClass) $ (ord(i_ReserveClass) = 2)        = sum(i_CVP $ (ord(i_CVP) = 4), i_CVPValues(i_CVP));
DeficitBranchGroupConstraintPenalty                                      = sum(i_CVP $ (ord(i_CVP) = 5), i_CVPValues(i_CVP));
SurplusBranchGroupConstraintPenalty                                      = sum(i_CVP $ (ord(i_CVP) = 6), i_CVPValues(i_CVP));
DeficitGenericConstraintPenalty                                          = sum(i_CVP $ (ord(i_CVP) = 7), i_CVPValues(i_CVP));
SurplusGenericConstraintPenalty                                          = sum(i_CVP $ (ord(i_CVP) = 8), i_CVPValues(i_CVP));
DeficitRampRatePenalty                                                   = sum(i_CVP $ (ord(i_CVP) = 9), i_CVPValues(i_CVP));
SurplusRampRatePenalty                                                   = sum(i_CVP $ (ord(i_CVP) = 10), i_CVPValues(i_CVP));
DeficitACNodeConstraintPenalty                                           = sum(i_CVP $ (ord(i_CVP) = 11), i_CVPValues(i_CVP));
SurplusACNodeConstraintPenalty                                           = sum(i_CVP $ (ord(i_CVP) = 12), i_CVPValues(i_CVP));
DeficitBranchFlowPenalty                                                 = sum(i_CVP $ (ord(i_CVP) = 13), i_CVPValues(i_CVP));
SurplusBranchFlowPenalty                                                 = sum(i_CVP $ (ord(i_CVP) = 14), i_CVPValues(i_CVP));
DeficitMnodeConstraintPenalty                                            = sum(i_CVP $ (ord(i_CVP) = 15), i_CVPValues(i_CVP));
SurplusMnodeConstraintPenalty                                            = sum(i_CVP $ (ord(i_CVP) = 16), i_CVPValues(i_CVP));
Type1DeficitMixedConstraintPenalty                                       = sum(i_CVP $ (ord(i_CVP) = 17), i_CVPValues(i_CVP));
Type1SurplusMixedConstraintPenalty                                       = sum(i_CVP $ (ord(i_CVP) = 18), i_CVPValues(i_CVP));
*RDN - Different CVPs defined for CE and ECE
DeficitReservePenalty_CE(i_ReserveClass) $ (ord(i_ReserveClass) = 1)     = sum(i_CVP $ (ord(i_CVP) = 3), i_CVPValues(i_CVP));
DeficitReservePenalty_CE(i_ReserveClass) $ (ord(i_ReserveClass) = 2)     = sum(i_CVP $ (ord(i_CVP) = 4), i_CVPValues(i_CVP));
DeficitReservePenalty_ECE(i_ReserveClass) $ (ord(i_ReserveClass) = 1)    = sum(i_CVP $ (ord(i_CVP) = 19), i_CVPValues(i_CVP));
DeficitReservePenalty_ECE(i_ReserveClass) $ (ord(i_ReserveClass) = 2)    = sum(i_CVP $ (ord(i_CVP) = 20), i_CVPValues(i_CVP));


*Initialise some reporting parameters
o_NumTradePeriods = 0;
o_SystemOFV = 0;
o_SystemGen = 0;
o_SystemLoad = 0;
o_SystemLoss = 0;
o_SystemViolation = 0;
o_SystemFIR = 0;
o_SystemSIR = 0;
o_SystemEnergyRevenue = 0;
o_SystemReserveRevenue = 0;
o_SystemLoadCost = 0;
o_SystemLoadRevenue = 0;
o_SystemSurplus = 0;
o_SystemACRentals = 0;
o_SystemDCRentals = 0;
o_OfferGen(i_Offer) = 0;
o_OfferFIR(i_Offer) = 0;
o_OfferSIR(i_Offer) = 0;
o_OfferGenRevenue(i_Offer) = 0;
o_OfferFIRRevenue(i_Offer) = 0;
o_OfferSIRRevenue(i_Offer) = 0;

o_SolveOK_TP(i_DateTime) = 0;


*RDN - Initialise some of the Audit reporting parameters to zero - Start--------
o_FIRReqd_TP(i_DateTime,i_Island) = 0;
o_SIRReqd_TP(i_DateTime,i_Island) = 0;
o_GenerationRiskSetter(i_DateTime,i_Island,i_Offer,i_ReserveClass,i_RiskClass) = 0;
o_GenerationRiskSetterMax(i_DateTime,i_Island,i_Offer,i_ReserveClass) = 0;
o_GenHVDCRiskSetter(i_DateTime,i_Island,i_Offer,i_ReserveClass,i_RiskClass) = 0;
o_HVDCRiskSetter(i_DateTime,i_Island,i_ReserveClass,i_RiskClass) = 0;
o_MANURiskSetter(i_DateTime,i_Island,i_ReserveClass,i_RiskClass) = 0;
o_MANUHVDCRiskSetter(i_DateTime,i_Island,i_ReserveClass,i_RiskClass) = 0;
o_HVDCRiskSetterMax(i_DateTime,i_Island,i_ReserveClass) = 0;
o_GenHVDCRiskSetterMax(i_DateTime,i_Island,i_Offer,i_ReserveClass) = 0;
o_MANUHVDCRiskSetterMax(i_DateTime,i_Island,i_ReserveClass) = 0;
o_MANURiskSetterMax(i_DateTime,i_Island,i_ReserveClass) = 0;
o_FIRCleared_TP(i_DateTime,i_Island) = 0;
o_SIRCleared_TP(i_DateTime,i_Island) = 0;
*RDN - Initialise some of the Audit reporting parameters to zero - End----------

*RDN - Update the deficit and surplus reporting at the nodal level - Start------
TotalBusAllocation(i_DateTime,i_Bus) = 0;
BusNodeAllocationFactor(i_DateTime,i_Bus,i_Node) = 0;
*RDN - Update the deficit and surplus reporting at the nodal level - End------
;


*Determine the number of trade periods
NumTradePeriods = card(i_TradePeriod);

***End data load and initialisation

*Main program loop

for (IterationCount = 1 to NumTradePeriods,

*If statement to determine which tradeperiods to solve when in sequential solve mode
 if (((i_SequentialSolve and sum(i_TradePeriod $ (ord(i_TradePeriod) = IterationCount), i_StudyTradePeriod(i_TradePeriod))) or (not i_SequentialSolve)),

*========================================================================================================
*Reset all sets, parameters and variables before proceeding with the next study trade period
*========================================================================================================
*Model Variables
*Reset bounds
*Offers
    option clear = GENERATION;
    option clear = GENERATIONBLOCK;
*Purchase bids
    option clear = PURCHASE;
    option clear = PURCHASEBLOCK;
    option clear = PURCHASEILR;
    option clear = PURCHASEILRBLOCK;
*Network
    option clear = HVDCLINKFLOW;
    option clear = HVDCLINKLOSSES;
    option clear = LAMBDA;
    option clear = LAMBDAINTEGER;
    option clear = ACBRANCHFLOW;
    option clear = ACBRANCHFLOWDIRECTED;
    option clear = ACBRANCHLOSSESDIRECTED;
    option clear = ACBRANCHFLOWBLOCKDIRECTED;
    option clear = ACBRANCHLOSSESBLOCKDIRECTED;
    option clear = ACNODEANGLE;
    option clear = ACBRANCHFLOWDIRECTED_INTEGER;
    option clear = HVDCLINKFLOWDIRECTION_INTEGER;
*RDN - Clear the integer variable to prevent intra-pole circulating branch flows
    option clear = HVDCPOLEFLOW_INTEGER;
*Risk/Reserve
    option clear = RESERVEBLOCK;
    option clear = RISKOFFSET;
*Mixed constraint
    option clear = MIXEDCONSTRAINTVARIABLE;
    option clear = MIXEDCONSTRAINTLIMIT2SELECT;

*Reset levels
*Objective
    option clear = NETBENEFIT;
*Network
    option clear = ACNODENETINJECTION;
    option clear = ACBRANCHFLOW;
    option clear = ACNODEANGLE;
*Generation
    option clear = GENERATION;
    option clear = GENERATIONBLOCK;
*Purchase
    option clear = PURCHASE;
    option clear = PURCHASEBLOCK;
    option clear = PURCHASEILR;
    option clear = PURCHASEILRBLOCK;
*Reserve
    option clear = ISLANDRISK;
    option clear = HVDCREC;
    option clear = RISKOFFSET;
    option clear = RESERVE;
    option clear = RESERVEBLOCK;
    option clear = MAXISLANDRISK;
*Network
    option clear = HVDCLINKFLOW;
    option clear = HVDCLINKLOSSES;
    option clear = LAMBDA;
    option clear = LAMBDAINTEGER;
    option clear = ACBRANCHFLOWDIRECTED;
    option clear = ACBRANCHLOSSESDIRECTED;
    option clear = ACBRANCHFLOWBLOCKDIRECTED;
    option clear = ACBRANCHLOSSESBLOCKDIRECTED;
    option clear = ACBRANCHFLOWDIRECTED_INTEGER;
    option clear = HVDCLINKFLOWDIRECTION_INTEGER;
*RDN - Clear the integer variable to prevent intra-pole circulating branch flows
    option clear = HVDCPOLEFLOW_INTEGER;

*Mixed constraint
    option clear = MIXEDCONSTRAINTVARIABLE;
    option clear = MIXEDCONSTRAINTLIMIT2SELECT;
*Violations
    option clear = TOTALPENALTYCOST;
    option clear = DEFICITBUSGENERATION;
    option clear = SURPLUSBUSGENERATION;
    option clear = DEFICITRESERVE;
    option clear = DEFICITBRANCHSECURITYCONSTRAINT;
    option clear = SURPLUSBRANCHSECURITYCONSTRAINT;
    option clear = DEFICITRAMPRATE;
    option clear = SURPLUSRAMPRATE;
    option clear = DEFICITACNODECONSTRAINT;
    option clear = SURPLUSACNODECONSTRAINT;
    option clear = DEFICITBRANCHFLOW;
    option clear = SURPLUSBRANCHFLOW;
    option clear = DEFICITMNODECONSTRAINT;
    option clear = SURPLUSMNODECONSTRAINT;
    option clear = DEFICITTYPE1MIXEDCONSTRAINT;
    option clear = SURPLUSTYPE1MIXEDCONSTRAINT;
    option clear = DEFICITGENERICCONSTRAINT;
    option clear = SURPLUSGENERICCONSTRAINT;
*RDN - Seperate CE and ECE deficit
    option clear = DEFICITRESERVE_CE;
    option clear = DEFICITRESERVE_ECE;

*Study parameters and sets
    option clear = CurrentTradePeriod;
*Offers
    option clear = OfferNode;
    option clear = GenerationStart;
    option clear = RampRateUp;
    option clear = RampRateDown;
    option clear = ReserveGenerationMaximum;
    option clear = WindOffer;
*RDN - Clear the FKBand
    option clear = FKBand;
    option clear = GenerationOfferMW;
    option clear = GenerationOfferPrice;
*Don't reset the previous MW value otherwise it serves no purpose
*   PreviousMW(i_Offer) = 0;
    option clear = ValidGenerationOfferBlock;
*RDN - 20130227 - Clear the positive energy offer set
    option clear = PositiveEnergyOffer;
    option clear = ReserveOfferProportion;
    option clear = ReserveOfferMaximum;
    option clear = ReserveOfferPrice;
    option clear = ValidReserveOfferBlock;
    option clear = Offer;
*RDN - Primary-secondary offer mapping
    option clear = PrimarySecondaryOffer;
    option clear = HasSecondaryOffer;
    option clear = HasPrimaryOffer;
*Bid
    option clear = PurchaseBidMW;
    option clear = PurchaseBidPrice;
    option clear = ValidPurchaseBidBlock;
    option clear = PurchaseBidILRMW;
    option clear = PurchaseBidILRPrice;
    option clear = ValidPurchaseBidILRBlock;
    option clear = BidNode;
    option clear = Bid;
*Demand
    option clear = NodeDemand;
*Network
    option clear = ACBranchSendingBus;
    option clear = ACBranchReceivingBus;
    option clear = ACBranchSendingBus;
    option clear = ACBranchReceivingBus;
    option clear = HVDCLinkSendingBus;
    option clear = HVDCLinkReceivingBus;
    option clear = HVDCLinkBus;
    option clear = ACBranchCapacity;
    option clear = HVDCLinkCapacity;
    option clear = ACBranchResistance;
    option clear = ACBranchSusceptance;
    option clear = ACBranchFixedLoss;
    option clear = ACBranchLossBlocks;
    option clear = HVDCLinkResistance;
    option clear = HVDCLinkFixedLoss;
    option clear = HVDCLinkLossBlocks;
    option clear = ACBranchOpenStatus;
    option clear = ACBranchClosedStatus;
    option clear = HVDCLinkOpenStatus;
    option clear = HVDCLinkClosedStatus;
    option clear = LossSegmentMW;
    option clear = LossSegmentFactor;
    option clear = ValidLossSegment;
    option clear = ClosedBranch;
    option clear = OpenBranch;
    option clear = ACBranch;
    option clear = HVDCHalfPoles;
    option clear = HVDCPoles;
    option clear = HVDCLink;
    option clear = HVDCPoleDirection;
    option clear = LossBranch;
    option clear = BranchBusDefn;
    option clear = BranchBusConnect;
    option clear = Branch;
    option clear = NodeBus;
    option clear = NodeIsland;
    option clear = BusIsland;
    option clear = HVDCNode;
    option clear = ACNode;
    option clear = ReferenceNode;
    option clear = Bus;
    option clear = Node;
    option clear = DCBus;
    option clear = ACBus;
*RDN - Clear the allow HVDC roundpower flag
    option clear = AllowHVDCRoundpower;
*Risk/Reserves
    option clear = FreeReserve;
    option clear = IslandRiskAdjustmentFactor;
    option clear = HVDCPoleRampUp;
    option clear = IslandMinimumRisk;
    option clear = ReserveClassGenerationMaximum;
    option clear = ReserveMaximumFactor;
    option clear = ILReserveType;
    option clear = PLSRReserveType;
    option clear = ManualRisk;
    option clear = HVDCRisk;
    option clear = GenRisk;
    option clear = IslandOffer;
    option clear = IslandBid;
    option clear = IslandRiskGenerator;
    option clear = RiskGenerator;
*RDN - Define contingent and extended contingent events for CE and ECE risks
    option clear = ContingentEvents;
    option clear = ExtendedContingentEvent;
*RDN - Clear the HVDC secondary risk data
    option clear = HVDCSecRisk;
    option clear = HVDCSecRiskEnabled;
    option clear = HVDCSecRiskSubtractor;
    option clear = HVDCSecIslandMinimumRisk;

*Branch Constraints
    option clear = BranchConstraint;
    option clear = BranchConstraintFactors;
    option clear = BranchConstraintSense;
    option clear = BranchConstraintLimit;
*AC Node Constraints
    option clear = ACNodeConstraint;
    option clear = ACNodeConstraintFactors;
    option clear = ACNodeConstraintSense;
    option clear = ACNodeConstraintLimit;
*Market Node Constraints
    option clear = MNodeConstraint;
    option clear = MNodeEnergyOfferConstraintFactors;
    option clear = MNodeReserveOfferConstraintFactors;
    option clear = MNodeEnergyBidConstraintFactors;
    option clear = MNodeILReserveBidConstraintFactors;
    option clear = MNodeConstraintSense;
    option clear = MNodeConstraintLimit;
*Mixed Constraints
    option clear = Type1MixedConstraint;
    option clear = Type2MixedConstraint;
    option clear = Type1MixedConstraintCondition;
    option clear = Type1MixedConstraintSense;
    option clear = Type1MixedConstraintLimit1;
    option clear = Type1MixedConstraintLimit2;
    option clear = Type2MixedConstraintSense;
    option clear = Type2MixedConstraintLimit;
*Generic Constraints
    option clear = GenericConstraint;
    option clear = GenericEnergyOfferConstraintFactors;
    option clear = GenericReserveOfferConstraintFactors;
    option clear = GenericEnergyBidConstraintFactors;
    option clear = GenericILReserveBidConstraintFactors;
    option clear = GenericBranchConstraintFactors;
    option clear = GenericConstraintSense;
    option clear = GenericConstraintLimit;
*Additional parameters
    option clear = GenerationMaximum;
    option clear = RampTimeUp;
    option clear = RampTimeDown;
    option clear = RampTimeUp;
    option clear = GenerationEndUp;
    option clear = GenerationMinimum;
    option clear = RampTimeDown;
    option clear = GenerationEndDown;
    option clear = ACBranchLossMW;
    option clear = ACBranchLossFactor;
    option clear = HVDCBreakPointMWFlow;
    option clear = HVDCBreakPointMWLoss;
    option clear = UseMixedConstraintMIP;
    option clear = CircularBranchFlowExist;
*RDN - Clear the pole circular branch flow flag
    option clear = PoleCircularBranchFlowExist;

    option clear = NorthHVDC;
    option clear = SouthHVDC;

    option clear = ManualBranchSegmentMWFlow;
    option clear = ManualLossCalculation;
    option clear = NonPhysicalLossExist;
    option clear = UseBranchFlowMIP;
    option clear = ModelSolved;
    option clear = LPModelSolved;
    option clear = LPValid;
    option clear = BranchFlowMIPInvoked;

*Disconnected bus post-processing
    option clear = BusGeneration;
    option clear = BusLoad;
    option clear = BusDisconnected;
    option clear = BusPrice;
*Run logic
    option clear = SkipResolve;

*End reset

*========================================================================================
*Initialise current trade period and model data for the current trade period
*========================================================================================

*Set the CurrentTradePeriod
*For sequential solve
    CurrentTradePeriod(i_TradePeriod) $ (i_SequentialSolve and (ord(i_TradePeriod) eq IterationCount)) = yes $ i_StudyTradePeriod(i_TradePeriod);
*For simultaneous solve
    CurrentTradePeriod(i_TradePeriod) $ (not (i_SequentialSolve)) = yes $ i_StudyTradePeriod(i_TradePeriod);
    IterationCount $ (not (i_SequentialSolve)) = NumTradePeriods;

*RDN - 20130302 - i_TradePeriodNodeBusAllocationFactor update - Start-----------
*Updated offer initialisation - Offer must be mapped to a node that is mapped to a bus that is not in electrical island = 0 when the i_UseBusNetworkModel flag is set to true
*Pre MSP case
    Offer(CurrentTradePeriod,i_Offer) $ (not (i_UseBusNetworkModel(CurrentTradePeriod))
                                         and
                                         (sum((i_Node,i_Bus) $ (i_TradePeriodOfferNode(CurrentTradePeriod,i_Offer,i_Node) and i_TradePeriodNodeBus(CurrentTradePeriod,i_Node,i_Bus)),1))
                                        ) = yes;
*Post MSP case
    Offer(CurrentTradePeriod,i_Offer) $ (i_UseBusNetworkModel(CurrentTradePeriod)
                                         and
                                         (sum((i_Node,i_Bus) $ (i_TradePeriodOfferNode(CurrentTradePeriod,i_Offer,i_Node) and i_TradePeriodNodeBus(CurrentTradePeriod,i_Node,i_Bus) and i_TradePeriodBusElectricalIsland(CurrentTradePeriod,i_Bus)),1))
                                        ) = yes;
*RDN - Updated offer initialisation - Offer must be mapped to a node that is mapped to a bus with non-zero allocation factor
*    Offer(CurrentTradePeriod,i_Offer) $ (sum((i_Node,i_Bus) $ (i_TradePeriodOfferNode(CurrentTradePeriod,i_Offer,i_Node) and i_TradePeriodNodeBus(CurrentTradePeriod,i_Node,i_Bus) and i_TradePeriodNodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus)),1)) = yes;
*Initialise offer data for the current trade period
*    Offer(CurrentTradePeriod,i_Offer) $ (sum(i_Node $ i_TradePeriodOfferNode(CurrentTradePeriod,i_Offer,i_Node),1)) = yes;
*RDN - 20130302 - i_TradePeriodNodeBusAllocationFactor update - End-------------

    Node(CurrentTradePeriod,i_Node) $ i_TradePeriodNode(CurrentTradePeriod,i_Node) = yes;
    OfferNode(CurrentTradePeriod,i_Offer,i_Node) $ i_TradePeriodOfferNode(CurrentTradePeriod,i_Offer,i_Node) = yes;

    GenerationStart(Offer) = sum(i_OfferParam $ (ord(i_OfferParam) = 1), i_TradePeriodOfferParameter(Offer,i_OfferParam));
    RampRateUp(Offer) = sum(i_OfferParam $ (ord(i_OfferParam) = 2), i_TradePeriodOfferParameter(Offer,i_OfferParam));
    RampRateDown(Offer) = sum(i_OfferParam $ (ord(i_OfferParam) = 3), i_TradePeriodOfferParameter(Offer,i_OfferParam));

    ReserveGenerationMaximum(Offer) = sum(i_OfferParam $ (ord(i_OfferParam) = 4), i_TradePeriodOfferParameter(Offer,i_OfferParam));
    WindOffer(Offer) = sum(i_OfferParam $ (ord(i_OfferParam) = 5), i_TradePeriodOfferParameter(Offer,i_OfferParam));

*RDN - Set the FKBand
    FKBand(Offer) = sum(i_OfferParam $ (ord(i_OfferParam) = 6), i_TradePeriodOfferParameter(Offer,i_OfferParam));

*RDN - Set the primary-secondary offer combinations
    PrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1) = i_TradePeriodPrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1);

    GenerationOfferMW(Offer,i_TradeBlock)
       = sum(i_EnergyOfferComponent $ (ord(i_EnergyOfferComponent) = 1), i_TradePeriodEnergyOffer(Offer,i_TradeBlock,i_EnergyOfferComponent));
    GenerationOfferPrice(Offer,i_TradeBlock)
       = sum(i_EnergyOfferComponent $ (ord(i_EnergyOfferComponent) = 2), i_TradePeriodEnergyOffer(Offer,i_TradeBlock,i_EnergyOfferComponent));

*Valid generation offer blocks are defined as those with a non-zero block capacity or a non-zero price
*Re-define valid generation offer block to be a block with a positive block limit
*    ValidGenerationOfferBlock(Offer,i_TradeBlock) $ (GenerationOfferMW(Offer,i_TradeBlock) + GenerationOfferPrice(Offer,i_TradeBlock)) = yes;
    ValidGenerationOfferBlock(Offer,i_TradeBlock) $ (GenerationOfferMW(Offer,i_TradeBlock) > 0) = yes;
*Define set of positive energy offers
    PositiveEnergyOffer(Offer) $ (sum(i_TradeBlock $ ValidGenerationOfferBlock(Offer,i_TradeBlock),1)) = yes;

    ReserveOfferProportion(Offer,i_TradeBlock,i_ReserveClass) $ (ord(i_ReserveClass) = 1)
       = sum(i_PLSROfferComponent $ (ord(i_PLSROfferComponent) = 1), i_TradePeriodFastPLSROffer(Offer,i_TradeBlock,i_PLSROfferComponent)/100);
    ReserveOfferProportion(Offer,i_TradeBlock,i_ReserveClass) $ (ord(i_ReserveClass) = 2)
       = sum(i_PLSROfferComponent $ (ord(i_PLSROfferComponent) = 1), i_TradePeriodSustainedPLSROffer(Offer,i_TradeBlock,i_PLSROfferComponent)/100);

    ReserveOfferMaximum(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 1) and (ord(i_ReserveType) = 1))
       = sum(i_PLSROfferComponent $ (ord(i_PLSROfferComponent) = 2), i_TradePeriodFastPLSROffer(Offer,i_TradeBlock,i_PLSROfferComponent));
    ReserveOfferMaximum(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 2) and (ord(i_ReserveType) = 1))
       = sum(i_PLSROfferComponent $ (ord(i_PLSROfferComponent) = 2), i_TradePeriodSustainedPLSROffer(Offer,i_TradeBlock,i_PLSROfferComponent));

    ReserveOfferMaximum(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 1) and (ord(i_ReserveType) = 2))
       = sum(i_TWDROfferComponent $ (ord(i_TWDROfferComponent) = 1), i_TradePeriodFastTWDROffer(Offer,i_TradeBlock,i_TWDROfferComponent));
    ReserveOfferMaximum(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 2) and (ord(i_ReserveType) = 2))
       = sum(i_TWDROfferComponent $ (ord(i_TWDROfferComponent) = 1), i_TradePeriodSustainedTWDROffer(Offer,i_TradeBlock,i_TWDROfferComponent));

    ReserveOfferMaximum(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 1) and (ord(i_ReserveType) = 3))
       = sum(i_ILROfferComponent $ (ord(i_ILROfferComponent) = 1), i_TradePeriodFastILROffer(Offer,i_TradeBlock,i_ILROfferComponent));
    ReserveOfferMaximum(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 2) and (ord(i_ReserveType) = 3))
       = sum(i_ILROfferComponent $ (ord(i_ILROfferComponent) = 1), i_TradePeriodSustainedILROffer(Offer,i_TradeBlock,i_ILROfferComponent));

    ReserveOfferPrice(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 1) and (ord(i_ReserveType) = 1))
       = sum(i_PLSROfferComponent $ (ord(i_PLSROfferComponent) = 3), i_TradePeriodFastPLSROffer(Offer,i_TradeBlock,i_PLSROfferComponent));
    ReserveOfferPrice(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 2) and (ord(i_ReserveType) = 1))
       = sum(i_PLSROfferComponent $ (ord(i_PLSROfferComponent) = 3), i_TradePeriodSustainedPLSROffer(Offer,i_TradeBlock,i_PLSROfferComponent));

    ReserveOfferPrice(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 1) and (ord(i_ReserveType) = 2))
       = sum(i_TWDROfferComponent $ (ord(i_TWDROfferComponent) = 2), i_TradePeriodFastTWDROffer(Offer,i_TradeBlock,i_TWDROfferComponent));
    ReserveOfferPrice(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 2) and (ord(i_ReserveType) = 2))
       = sum(i_TWDROfferComponent $ (ord(i_TWDROfferComponent) = 2), i_TradePeriodSustainedTWDROffer(Offer,i_TradeBlock,i_TWDROfferComponent));

    ReserveOfferPrice(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 1) and (ord(i_ReserveType) = 3))
       = sum(i_ILROfferComponent $ (ord(i_ILROfferComponent) = 2), i_TradePeriodFastILROffer(Offer,i_TradeBlock,i_ILROfferComponent));
    ReserveOfferPrice(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 2) and (ord(i_ReserveType) = 3))
       = sum(i_ILROfferComponent $ (ord(i_ILROfferComponent) = 2), i_TradePeriodSustainedILROffer(Offer,i_TradeBlock,i_ILROfferComponent));

*Valid reserve offer block for each reserve class and reserve type are defined as those with a non-zero block capacity OR a non-zero block price
*Re-define valid reserve offer block to be a block with a positive block limit
    ValidReserveOfferBlock(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ (ReserveOfferMaximum(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) > 0)
       = yes;
*    ValidReserveOfferBlock(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ (ReserveOfferMaximum(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) + ReserveOfferPrice(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType))
*       = yes;

*Initialise demand data for the current trade period
    NodeDemand(Node) = i_TradePeriodNodeDemand(Node);

*RDN - 20130302 - i_TradePeriodNodeBusAllocationFactor update - Start-----------
*Updated bid initialisation - Bid must be mapped to a node that is mapped to a bus that is not in electrical island = 0 when the i_UseBusNetworkModel flag is set to true
*Pre MSP case
    Bid(CurrentTradePeriod,i_Bid) $ (not (i_UseBusNetworkModel(CurrentTradePeriod))
                                     and
                                     (sum((i_Node,i_Bus) $ (i_TradePeriodBidNode(CurrentTradePeriod,i_Bid,i_Node) and i_TradePeriodNodeBus(CurrentTradePeriod,i_Node,i_Bus)),1))
                                    ) = yes;
*Post MSP case
    Bid(CurrentTradePeriod,i_Bid) $ (i_UseBusNetworkModel(CurrentTradePeriod)
                                     and
                                     (sum((i_Node,i_Bus) $ (i_TradePeriodBidNode(CurrentTradePeriod,i_Bid,i_Node) and i_TradePeriodNodeBus(CurrentTradePeriod,i_Node,i_Bus) and i_TradePeriodBusElectricalIsland(CurrentTradePeriod,i_Bus)),1))
                                    ) = yes;
*RDN - Updated bid initialisation in accordance with change made to the offer definition above - Bid must be mapped to a node that is mapped to a bus with non-zero allocation factor
*    Bid(CurrentTradePeriod,i_Bid) $ (sum((i_Node,i_Bus) $ (i_TradePeriodBidNode(CurrentTradePeriod,i_Bid,i_Node) and i_TradePeriodNodeBus(CurrentTradePeriod,i_Node,i_Bus) and i_TradePeriodNodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus)),1)) = yes;
*Initialise bid data for the current trade period
*    Bid(i_TradePeriod,i_Bid) $ (sum(i_Node $ i_TradePeriodBidNode(i_TradePeriod,i_Bid,i_Node),1) and CurrentTradePeriod(i_TradePeriod)) = yes;
*RDN - 20130302 - i_TradePeriodNodeBusAllocationFactor update - End-------------

    BidNode(Bid,i_Node) $ i_TradePeriodBidNode(Bid,i_Node) = yes;

    PurchaseBidMW(Bid,i_TradeBlock)
       = sum(i_EnergyBidComponent $ (ord(i_EnergyBidComponent) = 1), i_TradePeriodEnergyBid(Bid,i_TradeBlock,i_EnergyBidComponent));
    PurchaseBidPrice(Bid,i_TradeBlock)
       = sum(i_EnergyBidComponent $ (ord(i_EnergyBidComponent) = 2), i_TradePeriodEnergyBid(Bid,i_TradeBlock,i_EnergyBidComponent));

*RDN - Change to demand bid
*Valid purchaser bid blocks are defined as those with a non-zero block capacity OR a non-zero block price
*Re-define valid purchase bid block to be a block with a positive block limit
*    ValidPurchaseBidBlock(Bid,i_TradeBlock) $ (PurchaseBidMW(Bid,i_TradeBlock) > 0) = yes;
*    ValidPurchaseBidBlock(Bid,i_TradeBlock) $ (PurchaseBidMW(Bid,i_TradeBlock) + PurchaseBidPrice(Bid,i_TradeBlock)) = yes;
*Re-define valid purchase bid block to be a block with a non-zero block limit since both positive and negative limits are allowed
*with changes to the demand bids following DSBF implementation
    ValidPurchaseBidBlock(Bid,i_TradeBlock) $ ((not (UseDSBFDemandBidModel)) and (PurchaseBidMW(Bid,i_TradeBlock) > 0)) = yes;
    ValidPurchaseBidBlock(Bid,i_TradeBlock) $ (UseDSBFDemandBidModel and (PurchaseBidMW(Bid,i_TradeBlock) <> 0)) = yes;

*RDN - Change to demand bid - End

    PurchaseBidILRMW(Bid,i_TradeBlock,i_ReserveClass) $ (ord(i_ReserveClass) = 1)
       = sum(i_ILRBidComponent $ (ord(i_ILRBidComponent) = 1), i_TradePeriodFastILRBid(Bid,i_TradeBlock,i_ILRBidComponent));
    PurchaseBidILRPrice(Bid,i_TradeBlock,i_ReserveClass) $ (ord(i_ReserveClass) = 1)
       = sum(i_ILRBidComponent $ (ord(i_ILRBidComponent) = 2), i_TradePeriodFastILRBid(Bid,i_TradeBlock,i_ILRBidComponent));

    PurchaseBidILRMW(Bid,i_TradeBlock,i_ReserveClass) $ (ord(i_ReserveClass) = 2)
       = sum(i_ILRBidComponent $ (ord(i_ILRBidComponent) = 1), i_TradePeriodSustainedILRBid(Bid,i_TradeBlock,i_ILRBidComponent));
    PurchaseBidILRPrice(Bid,i_TradeBlock,i_ReserveClass) $ (ord(i_ReserveClass) = 2)
       = sum(i_ILRBidComponent $ (ord(i_ILRBidComponent) = 2), i_TradePeriodSustainedILRBid(Bid,i_TradeBlock,i_ILRBidComponent));
*Valid purchaser ILR blocks are defined as those with a non-zero block capacity OR a non-zero block price
*Re-define valid purchase ILR offer block to be a block with a positive block limit
    ValidPurchaseBidILRBlock(Bid,i_TradeBlock,i_ReserveClass) $ (PurchaseBidILRMW(Bid,i_TradeBlock,i_ReserveClass) > 0)
       = yes;
*    ValidPurchaseBidILRBlock(Bid,i_TradeBlock,i_ReserveClass) $ (PurchaseBidILRMW(Bid,i_TradeBlock,i_ReserveClass) + PurchaseBidILRPrice(Bid,i_TradeBlock,i_ReserveClass))
*       = yes;

*Initialise network data for the current trade period
    Bus(CurrentTradePeriod,i_Bus) $ i_TradePeriodBus(CurrentTradePeriod,i_Bus) = yes;
    NodeBus(Node,i_Bus) $ i_TradePeriodNodeBus(Node,i_Bus) = yes;
    NodeIsland(CurrentTradePeriod,i_Node,i_Island) $ (Node(CurrentTradePeriod,i_Node) and sum(i_Bus $ (Bus(CurrentTradePeriod,i_Bus) and i_TradePeriodBusIsland(CurrentTradePeriod,i_Bus,i_Island) and NodeBus(CurrentTradePeriod,i_Node,i_Bus)),1))
       = yes;

*Introduce bus island mapping
*    BusIsland(CurrentTradePeriod,i_Bus,i_Island) $ Bus(CurrentTradePeriod,i_Bus) = i_TradePeriodBusIsland(CurrentTradePeriod,i_Bus,i_Island);
    BusIsland(Bus,i_Island) = i_TradePeriodBusIsland(Bus,i_Island);

    HVDCNode(Node) $ i_TradePeriodHVDCNode(Node) = yes;
    ACNode(Node) $ (not HVDCNode(Node)) = yes;
    ReferenceNode(Node) $ i_TradePeriodReferenceNode(Node) = yes;

    DCBus(CurrentTradePeriod,i_Bus) $ (sum(NodeBus(HVDCNode(CurrentTradePeriod,i_Node),i_Bus), 1)) = yes;
    ACBus(CurrentTradePeriod,i_Bus) $ (not (sum(NodeBus(HVDCNode(CurrentTradePeriod,i_Node),i_Bus), 1))) = yes;

*Node-bus allocation factor
    NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) $ (Node(CurrentTradePeriod,i_Node) and Bus(CurrentTradePeriod,i_Bus))
       = i_TradePeriodNodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus);

*Bus live island status
    BusElectricalIsland(Bus) = i_TradePeriodBusElectricalIsland(Bus);

*Branch is defined if there is a defined terminal bus, it is defined for the trade period, it has a non-zero capacity and is closed for that trade period
*    Branch(CurrentTradePeriod,i_Branch) $ (sum((i_FromBus,i_ToBus) $ (Bus(CurrentTradePeriod,i_FromBus) and Bus(CurrentTradePeriod,i_ToBus) and i_TradePeriodBranchDefn(CurrentTradePeriod,i_Branch,i_FromBus,i_ToBus)),1))
    Branch(CurrentTradePeriod,i_Branch) $ (sum((i_FromBus,i_ToBus) $ (Bus(CurrentTradePeriod,i_FromBus) and Bus(CurrentTradePeriod,i_ToBus) and i_TradePeriodBranchDefn(CurrentTradePeriod,i_Branch,i_FromBus,i_ToBus)),1) and i_TradePeriodBranchCapacity(CurrentTradePeriod,i_Branch) and (not (i_TradePeriodBranchOpenStatus(CurrentTradePeriod,i_Branch))))
       = yes;
    BranchBusDefn(Branch,i_FromBus,i_ToBus) $ i_TradePeriodBranchDefn(Branch,i_FromBus,i_ToBus) = yes;
    BranchBusConnect(Branch,i_Bus) $ sum(i_Bus1 $ (BranchBusDefn(Branch,i_Bus,i_Bus1) or BranchBusDefn(Branch,i_Bus1,i_Bus)),1) = yes;

*HVDC link definition
    HVDCLink(Branch) $ i_TradePeriodHVDCBranch(Branch) = yes;
    HVDCPoles(Branch) $ (i_TradePeriodHVDCBranch(Branch) = 1) = yes;
    HVDCHalfPoles(Branch) $ (i_TradePeriodHVDCBranch(Branch) = 2) = yes;
    ACBranch(Branch) $ (not HVDCLink(Branch)) = yes;

*RDN - Flag to allow roundpower on the HVDC link
    AllowHVDCRoundpower(CurrentTradePeriod) = i_TradePeriodAllowHVDCRoundpower(CurrentTradePeriod);

*Determine sending and receiving bus sets
    ACBranchSendingBus(ACBranch,i_FromBus,i_FlowDirection) $ (sum(BranchBusDefn(ACBranch,i_FromBus,i_ToBus),1) and (ord(i_FlowDirection) = 1)) = yes;
    ACBranchReceivingBus(ACBranch,i_ToBus,i_FlowDirection) $ (sum(BranchBusDefn(ACBranch,i_FromBus,i_ToBus),1) and (ord(i_FlowDirection) = 1)) = yes;
    ACBranchSendingBus(ACBranch,i_ToBus,i_FlowDirection) $ (sum(BranchBusDefn(ACBranch,i_FromBus,i_ToBus),1) and (ord(i_FlowDirection) = 2)) = yes;
    ACBranchReceivingBus(ACBranch,i_FromBus,i_FlowDirection) $ (sum(BranchBusDefn(ACBranch,i_FromBus,i_ToBus),1) and (ord(i_FlowDirection) = 2)) = yes;
    HVDCLinkSendingBus(HVDCLink,i_FromBus) $ sum(BranchBusDefn(HVDCLink,i_FromBus,i_ToBus),1) = yes;
    HVDCLinkReceivingBus(HVDCLink,i_ToBus) $ sum(BranchBusDefn(HVDCLink,i_FromBus,i_ToBus),1) = yes;
    HVDCLinkBus(HVDCLink,i_Bus) $ (HVDCLinkSendingBus(HVDCLink,i_Bus) or HVDCLinkReceivingBus(HVDCLink,i_Bus)) = yes;

*Determine the HVDC inter-island pole in the northward and southward direction
    HVDCPoleDirection(CurrentTradePeriod,i_Branch,i_FlowDirection) $ ((ord(i_FlowDirection) = 1) and (HVDCLink(CurrentTradePeriod,i_Branch)) and sum((i_Island,NodeBus(CurrentTradePeriod,i_Node,i_Bus)) $ ((ord(i_Island) = 2) and NodeIsland(CurrentTradePeriod,i_Node,i_Island) and HVDCLinkSendingBus(CurrentTradePeriod,i_Branch,i_Bus)),1))
       = yes;
    HVDCPoleDirection(CurrentTradePeriod,i_Branch,i_FlowDirection) $ ((ord(i_FlowDirection) = 1) and (HVDCLink(CurrentTradePeriod,i_Branch)) and sum((i_Island,NodeBus(CurrentTradePeriod,i_Node,i_Bus)) $ ((ord(i_Island) = 2) and NodeIsland(CurrentTradePeriod,i_Node,i_Island) and HVDCLinkReceivingBus(CurrentTradePeriod,i_Branch,i_Bus)),1))
       = no;
    HVDCPoleDirection(CurrentTradePeriod,i_Branch,i_FlowDirection) $ ((ord(i_FlowDirection) = 2) and (HVDCLink(CurrentTradePeriod,i_Branch)) and sum((i_Island,NodeBus(CurrentTradePeriod,i_Node,i_Bus)) $ ((ord(i_Island) = 1) and NodeIsland(CurrentTradePeriod,i_Node,i_Island) and HVDCLinkSendingBus(CurrentTradePeriod,i_Branch,i_Bus)),1))
       = yes;
    HVDCPoleDirection(CurrentTradePeriod,i_Branch,i_FlowDirection) $ ((ord(i_FlowDirection) = 2) and (HVDCLink(CurrentTradePeriod,i_Branch)) and sum((i_Island,NodeBus(CurrentTradePeriod,i_Node,i_Bus)) $ ((ord(i_Island) = 1) and NodeIsland(CurrentTradePeriod,i_Node,i_Island) and HVDCLinkReceivingBus(CurrentTradePeriod,i_Branch,i_Bus)),1))
       = no;

*RDN - Map of HVDC branch to pole
*    HVDCPoleBranchMap('Pole1','BEN_HAY1.1') = yes;
*    HVDCPoleBranchMap('Pole1','HAY_BEN1.1') = yes;
*    HVDCPoleBranchMap('Pole2','BEN_HAY2.1') = yes;
*    HVDCPoleBranchMap('Pole2','HAY_BEN2.1') = yes;

*TN - Updated map of HVDC branch to pole to account for name changes to Pole 3
    HVDCPoleBranchMap('Pole1',i_Branch) $ sum(sameas(i_Branch,'BEN_HAY1.1'),1) = yes;
    HVDCPoleBranchMap('Pole1',i_Branch) $ sum(sameas(i_Branch,'HAY_BEN1.1'),1) = yes;
    HVDCPoleBranchMap('Pole1',i_Branch) $ sum(sameas(i_Branch,'BEN_HAY3.1'),1) = yes;
    HVDCPoleBranchMap('Pole1',i_Branch) $ sum(sameas(i_Branch,'HAY_BEN3.1'),1) = yes;
    HVDCPoleBranchMap('Pole2',i_Branch) $ sum(sameas(i_Branch,'BEN_HAY2.1'),1) = yes;
    HVDCPoleBranchMap('Pole2',i_Branch) $ sum(sameas(i_Branch,'HAY_BEN2.1'),1) = yes;

*Allocate the input branch parameters to the defined model parameters
    ACBranchCapacity(ACBranch) = i_TradePeriodBranchCapacity(ACBranch);
    HVDCLinkCapacity(HVDCLink) = i_TradePeriodBranchCapacity(HVDCLink);

    ACBranchResistance(ACBranch) = sum(i_BranchParameter $ (ord(i_BranchParameter) = 1), i_TradePeriodBranchParameter(ACBranch,i_BranchParameter));
*RDN - Convert susceptance from -Bpu to B%
*    ACBranchSusceptance(ACBranch) = sum(i_BranchParameter $ (ord(i_BranchParameter) = 2), i_TradePeriodBranchParameter(ACBranch,i_BranchParameter));
    ACBranchSusceptance(ACBranch) = -100*sum(i_BranchParameter $ (ord(i_BranchParameter) = 2), i_TradePeriodBranchParameter(ACBranch,i_BranchParameter));
    ACBranchLossBlocks(ACBranch) = sum(i_BranchParameter $ (ord(i_BranchParameter) = 4), i_TradePeriodBranchParameter(ACBranch,i_BranchParameter));
*Ensure fixed losses for no loss branches are not included
*    ACBranchFixedLoss(ACBranch) = sum(i_BranchParameter $ (ord(i_BranchParameter) = 3), i_TradePeriodBranchParameter(ACBranch,i_BranchParameter));
    ACBranchFixedLoss(ACBranch) = sum(i_BranchParameter $ (ord(i_BranchParameter) = 3), i_TradePeriodBranchParameter(ACBranch,i_BranchParameter)) $ (ACBranchLossBlocks(ACBranch) > 1);

    HVDCLinkResistance(HVDCLink) = sum(i_BranchParameter $ (ord(i_BranchParameter) = 1), i_TradePeriodBranchParameter(HVDCLink,i_BranchParameter));
    HVDCLinkFixedLoss(HVDCLink) = sum(i_BranchParameter $ (ord(i_BranchParameter) = 3), i_TradePeriodBranchParameter(HVDCLink,i_BranchParameter));
    HVDCLinkLossBlocks(HVDCLink) = sum(i_BranchParameter $ (ord(i_BranchParameter) = 4), i_TradePeriodBranchParameter(HVDCLink,i_BranchParameter));

*Set resistance and fixed loss to zero if do not want to use the loss model
    ACBranchResistance(ACBranch) $ (not i_UseACLossModel) = 0;
    ACBranchFixedLoss(ACBranch) $ (not i_UseACLossModel) = 0;

    HVDCLinkResistance(HVDCLink) $ (not i_UseHVDCLossModel) = 0;
    HVDCLinkFixedLoss(HVDCLink) $ (not i_UseHVDCLossModel) = 0;

*Determine branch open and closed status
*Open status is provided but this is converted to a closed status since this is more compact to use in the formulation
*Used for Implementation 1 and 2.  Remove if using Implementation 3.
    ACBranchOpenStatus(ACBranch) = i_TradePeriodBranchOpenStatus(ACBranch);
    ACBranchClosedStatus(ACBranch) = 1 - ACBranchOpenStatus(ACBranch);
    HVDCLinkOpenStatus(HVDCLink) = i_TradePeriodBranchOpenStatus(HVDCLink);
    HVDCLinkClosedStatus(HVDCLink) = 1 - HVDCLinkOpenStatus(HVDCLink);
*Used for Implementation 3
    ClosedBranch(Branch) $ (not i_TradePeriodBranchOpenStatus(Branch)) = yes;
    OpenBranch(Branch) $ (not ClosedBranch(Branch)) = yes;

*The loss factor coefficients assume that the branch capacity is in MW and the resistance is in p.u.
*Branches (AC and HVDC) with 1 loss segment
*RDN - Ensure only the 1st loss segment is used for branches with <= 1 loss blocks - Start--------------------------
*         LossSegmentMW(ClosedBranch(ACBranch),i_LossSegment) $ ((ACBranchLossBlocks(ACBranch) <= 1)  and (not i_UseExternalLossModel)) = sum(i_LossParameter $ (ord(i_LossParameter) = 1), i_NoLossBranch(i_LossSegment,i_LossParameter));
*         LossSegmentFactor(ClosedBranch(ACBranch),i_LossSegment) $ ((ACBranchLossBlocks(ACBranch) <= 1) and (not i_UseExternalLossModel)) = sum(i_LossParameter $ (ord(i_LossParameter) = 2), i_NoLossBranch(i_LossSegment,i_LossParameter) * ACBranchResistance(ACBranch) * ACBranchCapacity(ACBranch));
*         LossSegmentMW(ClosedBranch(HVDCLink),i_LossSegment) $ ((HVDCLinkLossBlocks(HVDCLink) <= 1) and (not i_UseExternalLossModel)) = sum(i_LossParameter $ (ord(i_LossParameter) = 1), i_NoLossBranch(i_LossSegment,i_LossParameter));
*         LossSegmentFactor(ClosedBranch(HVDCLink),i_LossSegment) $ ((HVDCLinkLossBlocks(HVDCLink) <= 1) and (not i_UseExternalLossModel)) = sum(i_LossParameter $ (ord(i_LossParameter) = 2), i_NoLossBranch(i_LossSegment,i_LossParameter) * HVDCLinkResistance(HVDCLink) * HVDCLinkCapacity(HVDCLink));

         LossSegmentMW(ClosedBranch(ACBranch),i_LossSegment) $ ((ACBranchLossBlocks(ACBranch) <= 1)  and (not i_UseExternalLossModel) and (ord(i_LossSegment) = 1)) = sum(i_LossParameter $ (ord(i_LossParameter) = 1), i_NoLossBranch(i_LossSegment,i_LossParameter));
         LossSegmentFactor(ClosedBranch(ACBranch),i_LossSegment) $ ((ACBranchLossBlocks(ACBranch) <= 1) and (not i_UseExternalLossModel) and (ord(i_LossSegment) = 1)) = sum(i_LossParameter $ (ord(i_LossParameter) = 2), i_NoLossBranch(i_LossSegment,i_LossParameter) * ACBranchResistance(ACBranch) * ACBranchCapacity(ACBranch));
         LossSegmentMW(ClosedBranch(HVDCLink),i_LossSegment) $ ((HVDCLinkLossBlocks(HVDCLink) <= 1) and (not i_UseExternalLossModel) and (ord(i_LossSegment) = 1)) = sum(i_LossParameter $ (ord(i_LossParameter) = 1), i_NoLossBranch(i_LossSegment,i_LossParameter));
         LossSegmentFactor(ClosedBranch(HVDCLink),i_LossSegment) $ ((HVDCLinkLossBlocks(HVDCLink) <= 1) and (not i_UseExternalLossModel) and (ord(i_LossSegment) = 1)) = sum(i_LossParameter $ (ord(i_LossParameter) = 2), i_NoLossBranch(i_LossSegment,i_LossParameter) * HVDCLinkResistance(HVDCLink) * HVDCLinkCapacity(HVDCLink));

*RDN - Ensure only the 1st loss segment is used for branches with <= 1 loss blocks - End--------------------------

*Use the external loss model as provided by Transpower
*RDN - Ensure only the 1st loss segment is used for branches with 0 loss blocks - Start--------------------------
*         LossSegmentMW(ClosedBranch(ACBranch),i_LossSegment) $ ((ACBranchLossBlocks(ACBranch) = 0) and i_UseExternalLossModel) = MaxFlowSegment;
*         LossSegmentFactor(ClosedBranch(ACBranch),i_LossSegment) $ ((ACBranchLossBlocks(ACBranch) = 0) and i_UseExternalLossModel) = 0;
*         LossSegmentMW(ClosedBranch(HVDCLink),i_LossSegment) $ ((HVDCLinkLossBlocks(HVDCLink) = 0) and i_UseExternalLossModel) = MaxFlowSegment;
*         LossSegmentFactor(ClosedBranch(HVDCLink),i_LossSegment) $ ((HVDCLinkLossBlocks(HVDCLink) = 0) and i_UseExternalLossModel) = 0;

         LossSegmentMW(ClosedBranch(ACBranch),i_LossSegment) $ ((ACBranchLossBlocks(ACBranch) = 0) and i_UseExternalLossModel and (ord(i_LossSegment) = 1)) = MaxFlowSegment;
         LossSegmentFactor(ClosedBranch(ACBranch),i_LossSegment) $ ((ACBranchLossBlocks(ACBranch) = 0) and i_UseExternalLossModel and (ord(i_LossSegment) = 1)) = 0;
         LossSegmentMW(ClosedBranch(HVDCLink),i_LossSegment) $ ((HVDCLinkLossBlocks(HVDCLink) = 0) and i_UseExternalLossModel and (ord(i_LossSegment) = 1)) = MaxFlowSegment;
         LossSegmentFactor(ClosedBranch(HVDCLink),i_LossSegment) $ ((HVDCLinkLossBlocks(HVDCLink) = 0) and i_UseExternalLossModel and (ord(i_LossSegment) = 1)) = 0;
*RDN - Ensure only the 1st loss segment is used for branches with 0 loss blocks - End----------------------------

*Use the external loss model as provided by Transpower
         LossSegmentMW(ClosedBranch(ACBranch),i_LossSegment) $ ((ACBranchLossBlocks(ACBranch) = 1) and i_UseExternalLossModel and (ord(i_LossSegment) = 1)) = MaxFlowSegment;
         LossSegmentFactor(ClosedBranch(ACBranch),i_LossSegment) $ ((ACBranchLossBlocks(ACBranch) = 1) and i_UseExternalLossModel and (ord(i_LossSegment) = 1)) = ACBranchResistance(ACBranch) * ACBranchCapacity(ACBranch);
         LossSegmentMW(ClosedBranch(HVDCLink),i_LossSegment) $ ((HVDCLinkLossBlocks(HVDCLink) = 1) and i_UseExternalLossModel and (ord(i_LossSegment) = 1)) = MaxFlowSegment;
         LossSegmentFactor(ClosedBranch(HVDCLink),i_LossSegment) $ ((HVDCLinkLossBlocks(HVDCLink) = 1) and i_UseExternalLossModel and (ord(i_LossSegment) = 1)) = HVDCLinkResistance(HVDCLink) * HVDCLinkCapacity(HVDCLink);

*AC loss branches with more than one loss segment
         LossSegmentMW(ClosedBranch(ACBranch),i_LossSegment) $ ((not i_UseExternalLossModel) and (ACBranchLossBlocks(ACBranch) > 1) and (ord(i_LossSegment) < ACBranchLossBlocks(ACBranch))) = sum(i_LossParameter $ (ord(i_LossParameter) = 1), i_ACLossBranch(i_LossSegment,i_LossParameter) * ACBranchCapacity(ACBranch));
         LossSegmentMW(ClosedBranch(ACBranch),i_LossSegment) $ ((not i_UseExternalLossModel) and (ACBranchLossBlocks(ACBranch) > 1) and (ord(i_LossSegment) = ACBranchLossBlocks(ACBranch))) = sum(i_LossParameter $ (ord(i_LossParameter) = 1), i_ACLossBranch(i_LossSegment,i_LossParameter));
         LossSegmentFactor(ClosedBranch(ACBranch),i_LossSegment) $ ((not i_UseExternalLossModel) and (ACBranchLossBlocks(ACBranch) > 1)) = sum(i_LossParameter $ (ord(i_LossParameter) = 2), i_ACLossBranch(i_LossSegment,i_LossParameter) * ACBranchResistance(ACBranch) * ACBranchCapacity(ACBranch));

*Use the external loss model as provided by Transpower
*Segment 1
         LossSegmentMW(ClosedBranch(ACBranch),i_LossSegment) $ (i_UseExternalLossModel and (ACBranchLossBlocks(ACBranch) > 1) and (ord(i_LossSegment) = 1)) = ACBranchCapacity(ACBranch) * LossCoeff_A;
         LossSegmentFactor(ClosedBranch(ACBranch),i_LossSegment) $ (i_UseExternalLossModel and (ACBranchLossBlocks(ACBranch) > 1) and (ord(i_LossSegment) = 1)) = 0.01 * ACBranchResistance(ACBranch) * ACBranchCapacity(ACBranch) * 0.75 * LossCoeff_A;
*Segment 2
         LossSegmentMW(ClosedBranch(ACBranch),i_LossSegment) $ (i_UseExternalLossModel and (ACBranchLossBlocks(ACBranch) > 1) and (ord(i_LossSegment) = 2)) = ACBranchCapacity(ACBranch) * (1-LossCoeff_A);
         LossSegmentFactor(ClosedBranch(ACBranch),i_LossSegment) $ (i_UseExternalLossModel and (ACBranchLossBlocks(ACBranch) > 1) and (ord(i_LossSegment) = 2)) = 0.01 * ACBranchResistance(ACBranch) * ACBranchCapacity(ACBranch);
*Segment 3
         LossSegmentMW(ClosedBranch(ACBranch),i_LossSegment) $ (i_UseExternalLossModel and (ACBranchLossBlocks(ACBranch) > 1) and (ord(i_LossSegment) = 3)) = MaxFlowSegment;
         LossSegmentFactor(ClosedBranch(ACBranch),i_LossSegment) $ (i_UseExternalLossModel and (ACBranchLossBlocks(ACBranch) > 1) and (ord(i_LossSegment) = 3)) = 0.01 * ACBranchResistance(ACBranch) * ACBranchCapacity(ACBranch) * (2 - (0.75*LossCoeff_A));

*HVDC loss branches with more than one loss segment
         LossSegmentMW(ClosedBranch(HVDCLink),i_LossSegment) $ ((not i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) < HVDCLinkLossBlocks(HVDCLink))) = sum(i_LossParameter $ (ord(i_LossParameter) = 1), i_HVDCLossBranch(i_LossSegment,i_LossParameter) * HVDCLinkCapacity(HVDCLink));
         LossSegmentMW(ClosedBranch(HVDCLink),i_LossSegment) $ ((not i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) = HVDCLinkLossBlocks(HVDCLink))) = sum(i_LossParameter $ (ord(i_LossParameter) = 1), i_HVDCLossBranch(i_LossSegment,i_LossParameter));
         LossSegmentFactor(ClosedBranch(HVDCLink),i_LossSegment) $ ((not i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1)) = sum(i_LossParameter $ (ord(i_LossParameter) = 2), i_HVDCLossBranch(i_LossSegment,i_LossParameter) * HVDCLinkResistance(HVDCLink) * HVDCLinkCapacity(HVDCLink));

*Use the external loss model as provided by Transpower
*Segment 1
         LossSegmentMW(ClosedBranch(HVDCLink),i_LossSegment) $ ((i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) = 1)) = HVDCLinkCapacity(HVDCLink) * LossCoeff_C;
         LossSegmentFactor(ClosedBranch(HVDCLink),i_LossSegment) $ ((i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) = 1)) = 0.01 * HVDCLinkResistance(HVDCLink) * HVDCLinkCapacity(HVDCLink) * 0.75 * LossCoeff_C;
*Segment 2
         LossSegmentMW(ClosedBranch(HVDCLink),i_LossSegment) $ ((i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) = 2)) = HVDCLinkCapacity(HVDCLink) * LossCoeff_D;
         LossSegmentFactor(ClosedBranch(HVDCLink),i_LossSegment) $ ((i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) = 2)) = 0.01 * HVDCLinkResistance(HVDCLink) * HVDCLinkCapacity(HVDCLink) * LossCoeff_E;
*Segment 3
         LossSegmentMW(ClosedBranch(HVDCLink),i_LossSegment) $ ((i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) = 3)) = HVDCLinkCapacity(HVDCLink) * 0.5;
         LossSegmentFactor(ClosedBranch(HVDCLink),i_LossSegment) $ ((i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) = 3)) = 0.01 * HVDCLinkResistance(HVDCLink) * HVDCLinkCapacity(HVDCLink) * LossCoeff_F;
*Segment 4
         LossSegmentMW(ClosedBranch(HVDCLink),i_LossSegment) $ ((i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) = 4)) = HVDCLinkCapacity(HVDCLink) * (1 - LossCoeff_D);
         LossSegmentFactor(ClosedBranch(HVDCLink),i_LossSegment) $ ((i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) = 4)) = 0.01 * HVDCLinkResistance(HVDCLink) * HVDCLinkCapacity(HVDCLink) * (2 - LossCoeff_F);
*Segment 5
         LossSegmentMW(ClosedBranch(HVDCLink),i_LossSegment) $ ((i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) = 5)) = HVDCLinkCapacity(HVDCLink) * (1 - LossCoeff_C);
         LossSegmentFactor(ClosedBranch(HVDCLink),i_LossSegment) $ ((i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) = 5)) = 0.01 * HVDCLinkResistance(HVDCLink) * HVDCLinkCapacity(HVDCLink) * (2 - LossCoeff_E);
*Segment 6
         LossSegmentMW(ClosedBranch(HVDCLink),i_LossSegment) $ ((i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) = 6)) = MaxFlowSegment;
         LossSegmentFactor(ClosedBranch(HVDCLink),i_LossSegment) $ ((i_UseExternalLossModel) and (HVDCLinkLossBlocks(HVDCLink) > 1) and (ord(i_LossSegment) = 6)) = 0.01 * HVDCLinkResistance(HVDCLink) * HVDCLinkCapacity(HVDCLink) * (2 - (0.75*LossCoeff_C));

*Valid loss segment for a branch is defined as a loss segment that has a non-zero LossSegmentMW OR a non-zero LossSegmentFactor
*Every branch has at least one loss segment block
    ValidLossSegment(Branch,i_LossSegment) $ (ord(i_LossSegment) = 1) = yes;
    ValidLossSegment(Branch,i_LossSegment) $ ((ord(i_LossSegment) > 1) and (LossSegmentMW(Branch,i_LossSegment)+LossSegmentFactor(Branch,i_LossSegment))) = yes;
*HVDC loss model requires at least two loss segments and an additional loss block due to cumulative loss formulation
    ValidLossSegment(HVDCLink,i_LossSegment) $ ((HVDCLinkLossBlocks(HVDCLink) <= 1) and (ord(i_LossSegment) = 2)) = yes;
    ValidLossSegment(HVDCLink,i_LossSegment) $ ((HVDCLinkLossBlocks(HVDCLink) > 1) and (sum(i_LossSegment1, LossSegmentMW(HVDCLink,i_LossSegment1)+LossSegmentFactor(HVDCLink,i_LossSegment1)) > 0) and (ord(i_LossSegment) = (HVDCLinkLossBlocks(HVDCLink) + 1))) = yes;

*Branches that have non-zero loss factors
    LossBranch(Branch) $ (sum(i_LossSegment, LossSegmentFactor(Branch,i_LossSegment))) = yes;

*Initialise Risk/Reserve data for the current trading period
    RiskGenerator(Offer) $ i_TradePeriodRiskGenerator(Offer) = yes;
    IslandRiskGenerator(CurrentTradePeriod,i_Island,i_Offer) $ (Offer(CurrentTradePeriod,i_Offer) and i_TradePeriodRiskGenerator(CurrentTradePeriod,i_Offer) and sum(i_Node $ (OfferNode(CurrentTradePeriod,i_Offer,i_Node) and NodeIsland(CurrentTradePeriod,i_Node,i_Island)),1))
       = yes;
    IslandOffer(CurrentTradePeriod,i_Island,i_Offer) $ (Offer(CurrentTradePeriod,i_Offer) and sum(i_Node $ (OfferNode(CurrentTradePeriod,i_Offer,i_Node) and NodeIsland(CurrentTradePeriod,i_Node,i_Island)),1))
       = yes;

*RDN - If the i_UseExtendedRiskClass flag is set, update GenRisk and ManualRisk mapping to the RiskClass set since it now includes additional ECE risk classes associated with GenRisk and ManualRisk
*    GenRisk(i_RiskClass) $ (ord(i_RiskClass) = 1) = yes;
*    HVDCRisk(i_RiskClass) $ ((ord(i_RiskClass) = 2) or (ord(i_RiskClass) = 3)) = yes;
*    ManualRisk(i_RiskClass) $ (ord(i_RiskClass) = 4) = yes;
    GenRisk(i_RiskClass) $ ((ord(i_RiskClass) = 1) and (not (i_UseExtendedRiskClass))) = yes;
    GenRisk(i_RiskClass) $ (i_UseExtendedRiskClass and ((ord(i_RiskClass) = 1) or (ord(i_RiskClass) = 5))) = yes;
    ManualRisk(i_RiskClass) $ ((ord(i_RiskClass) = 4) and (not (i_UseExtendedRiskClass))) = yes;
    ManualRisk(i_RiskClass) $ (i_UseExtendedRiskClass and ((ord(i_RiskClass) = 4) or (ord(i_RiskClass) = 6))) = yes;
    HVDCRisk(i_RiskClass) $ ((ord(i_RiskClass) = 2) or (ord(i_RiskClass) = 3)) = yes;
*RDN - Set the HVDCSecRisk class
    HVDCSecRisk(i_RiskClass) $ (not (i_UseExtendedRiskClass)) = no;
    HVDCSecRisk(i_RiskClass) $ (i_UseExtendedRiskClass and ((ord(i_RiskClass) = 7) or (ord(i_RiskClass) = 8))) = yes;

*RDN - Define the CE and ECE risk class set to support the different CE and ECE CVP
*    ExtendedContingentEvent(i_RiskClass) $ (ord(i_RiskClass) = 3) = yes;
*    ContingentEvents(i_RiskClass) $ ((ord(i_RiskClass) = 1) or (ord(i_RiskClass) = 2) or (ord(i_RiskClass) = 4)) = yes;

*RDN - If the i_UseExtendedRiskClass flag is set, update the extended contingency event defintion to include the additional ECE risks included into the i_RiskClass set
    ExtendedContingentEvent(i_RiskClass) $ ((ord(i_RiskClass) = 3) and (not (i_UseExtendedRiskClass))) = yes;
    ExtendedContingentEvent(i_RiskClass) $ (i_UseExtendedRiskClass and ((ord(i_RiskClass) = 3) or (ord(i_RiskClass) = 5) or (ord(i_RiskClass) = 6) or (ord(i_RiskClass) = 8))) = yes;
    ContingentEvents(i_RiskClass) $ ((not (i_UseExtendedRiskClass)) and ((ord(i_RiskClass) = 1) or (ord(i_RiskClass) = 2) or (ord(i_RiskClass) = 4))) = yes;
    ContingentEvents(i_RiskClass) $ (i_UseExtendedRiskClass and ((ord(i_RiskClass) = 1) or (ord(i_RiskClass) = 2) or (ord(i_RiskClass) = 4) or (ord(i_RiskClass) = 7)) ) = yes;

    IslandBid(CurrentTradePeriod,i_Island,i_Bid) $ (Bid(CurrentTradePeriod,i_Bid) and sum(i_Node $ (BidNode(CurrentTradePeriod,i_Bid,i_Node) and NodeIsland(CurrentTradePeriod,i_Node,i_Island)),1))
       = yes;

    PLSRReserveType(i_ReserveType) $ (ord(i_ReserveType) = 1) = yes;
    ILReserveType(i_ReserveType) $ (ord(i_ReserveType) = 3) = yes;

    FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass)
       = sum(i_RiskParameter $ (ord(i_RiskParameter) = 1), i_TradePeriodRiskParameter(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass,i_RiskParameter));

*RDN - Zero the island risk adjustment factor when i_UseReserveModel flag is set to false - Start----------------
    IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass)
       = sum(i_RiskParameter $ (ord(i_RiskParameter) = 2), i_TradePeriodRiskParameter(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass,i_RiskParameter));

    IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) $ (not (i_UseReserveModel)) = 0;
*RDN - Zero the island risk adjustment factor when i_UseReserveModel flag is set to false - End------------------

    HVDCPoleRampUp(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass)
       = sum(i_RiskParameter $ (ord(i_RiskParameter) = 3), i_TradePeriodRiskParameter(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass,i_RiskParameter));
*RDN - Index IslandMinimumRisk to cater for CE and ECE minimum risk
*    IslandMinimumRisk(CurrentTradePeriod,i_Island,i_ReserveClass) = i_TradePeriodManualRisk(CurrentTradePeriod,i_Island,i_ReserveClass);
    IslandMinimumRisk(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) $ (ord(i_RiskClass) = 4) = i_TradePeriodManualRisk(CurrentTradePeriod,i_Island,i_ReserveClass);
    IslandMinimumRisk(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) $ (ord(i_RiskClass) = 6) = i_TradePeriodManualRisk_ECE(CurrentTradePeriod,i_Island,i_ReserveClass);

*RDN - HVDC secondary risk parameters
    HVDCSecRiskEnabled(CurrentTradePeriod,i_Island,i_RiskClass) = i_TradePeriodHVDCSecRiskEnabled(CurrentTradePeriod,i_Island,i_RiskClass);
    HVDCSecRiskSubtractor(CurrentTradePeriod,i_Island) = i_TradePeriodHVDCSecRiskSubtractor(CurrentTradePeriod,i_Island);
*RDN - Minimum risks for the HVDC secondary risk are the same as the island minimum risk
    HVDCSecIslandMinimumRisk(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) $ (ord(i_RiskClass) = 7) = i_TradePeriodManualRisk(CurrentTradePeriod,i_Island,i_ReserveClass);
    HVDCSecIslandMinimumRisk(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) $ (ord(i_RiskClass) = 8) = i_TradePeriodManualRisk_ECE(CurrentTradePeriod,i_Island,i_ReserveClass);

*Calculation of reserve maximum factor - 5.2.1.1.
    ReserveClassGenerationMaximum(Offer,i_ReserveClass) = ReserveGenerationMaximum(Offer);
    ReserveClassGenerationMaximum(Offer,i_ReserveClass) $ i_TradePeriodReserveClassGenerationMaximum(Offer,i_ReserveClass) = i_TradePeriodReserveClassGenerationMaximum(Offer,i_ReserveClass);

    ReserveMaximumFactor(Offer,i_ReserveClass) = 1;
    ReserveMaximumFactor(Offer,i_ReserveClass) $ (ReserveClassGenerationMaximum(Offer,i_ReserveClass)>0) = (ReserveGenerationMaximum(Offer) / ReserveClassGenerationMaximum(Offer,i_ReserveClass));

*Initialise branch constraint data for the current trading period
    BranchConstraint(CurrentTradePeriod,i_BranchConstraint) $ (sum(i_Branch $ (Branch(CurrentTradePeriod,i_Branch) and i_TradePeriodBranchConstraintFactors(CurrentTradePeriod,i_BranchConstraint,i_Branch)),1))
       = yes;
    BranchConstraintFactors(BranchConstraint,i_Branch) = i_TradePeriodBranchConstraintFactors(BranchConstraint,i_Branch);
    BranchConstraintSense(BranchConstraint) = sum(i_ConstraintRHS $ (ord(i_ConstraintRHS) = 1), i_TradePeriodBranchConstraintRHS(BranchConstraint,i_ConstraintRHS));
    BranchConstraintLimit(BranchConstraint) = sum(i_ConstraintRHS $ (ord(i_ConstraintRHS) = 2), i_TradePeriodBranchConstraintRHS(BranchConstraint,i_ConstraintRHS));

*Initialise AC node constraint data for the current trading period
    ACNodeConstraint(CurrentTradePeriod,i_ACNodeConstraint) $ (sum(i_Node $ (ACNode(CurrentTradePeriod,i_Node) and i_TradePeriodACNodeConstraintFactors(CurrentTradePeriod,i_ACNodeConstraint,i_Node)),1))
       = yes;
    ACNodeConstraintFactors(ACNodeConstraint,i_Node) = i_TradePeriodACNodeConstraintFactors(ACNodeConstraint,i_Node);
    ACNodeConstraintSense(ACNodeConstraint) = sum(i_ConstraintRHS $ (ord(i_ConstraintRHS) = 1), i_TradePeriodACNodeConstraintRHS(ACNodeConstraint,i_ConstraintRHS));
    ACNodeConstraintLimit(ACNodeConstraint) = sum(i_ConstraintRHS $ (ord(i_ConstraintRHS) = 2), i_TradePeriodACNodeConstraintRHS(ACNodeConstraint,i_ConstraintRHS));

*Initialise market node constraint data for the current trading period
    MNodeConstraint(CurrentTradePeriod,i_MNodeConstraint) $ ( (sum((i_Offer,i_ReserveType,i_ReserveClass) $ (Offer(CurrentTradePeriod,i_Offer) and (i_TradePeriodMNodeEnergyOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer) or i_TradePeriodMNodeReserveOfferConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Offer,i_ReserveClass,i_ReserveType))),1))
         or (sum((i_Bid,i_ReserveClass) $ (Bid(CurrentTradePeriod,i_Bid) and (i_TradePeriodMNodeEnergyBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid) or i_TradePeriodMNodeILReserveBidConstraintFactors(CurrentTradePeriod,i_MNodeConstraint,i_Bid,i_ReserveClass))),1)) ) = yes;
    MNodeEnergyOfferConstraintFactors(MNodeConstraint,i_Offer) = i_TradePeriodMNodeEnergyOfferConstraintFactors(MNodeConstraint,i_Offer);
    MNodeReserveOfferConstraintFactors(MNodeConstraint,i_Offer,i_ReserveClass,i_ReserveType) = i_TradePeriodMNodeReserveOfferConstraintFactors(MNodeConstraint,i_Offer,i_ReserveClass,i_ReserveType);
    MNodeEnergyBidConstraintFactors(MNodeConstraint,i_Bid) = i_TradePeriodMNodeEnergyBidConstraintFactors(MNodeConstraint,i_Bid);
    MNodeILReserveBidConstraintFactors(MNodeConstraint,i_Bid,i_ReserveClass) = i_TradePeriodMNodeILReserveBidConstraintFactors(MNodeConstraint,i_Bid,i_ReserveClass);
    MNodeConstraintSense(MNodeConstraint) = sum(i_ConstraintRHS $ (ord(i_ConstraintRHS) = 1), i_TradePeriodMNodeConstraintRHS(MNodeConstraint,i_ConstraintRHS));
    MNodeConstraintLimit(MNodeConstraint) = sum(i_ConstraintRHS $ (ord(i_ConstraintRHS) = 2), i_TradePeriodMNodeConstraintRHS(MNodeConstraint,i_ConstraintRHS));

*Initialise mixed constraint data for the current trading period
    Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint) = i_TradePeriodType1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint);
    Type2MixedConstraint(CurrentTradePeriod,i_Type2MixedConstraint) = i_TradePeriodType2MixedConstraint(CurrentTradePeriod,i_Type2MixedConstraint);
    Type1MixedConstraintSense(CurrentTradePeriod,i_Type1MixedConstraint) = sum(i_Type1MixedConstraintRHS $ (ord(i_Type1MixedConstraintRHS) = 1), i_TradePeriodType1MixedConstraintRHSParameters(CurrentTradePeriod,i_Type1MixedConstraint,i_Type1MixedConstraintRHS));
    Type1MixedConstraintLimit1(CurrentTradePeriod,i_Type1MixedConstraint) = sum(i_Type1MixedConstraintRHS $ (ord(i_Type1MixedConstraintRHS) = 2), i_TradePeriodType1MixedConstraintRHSParameters(CurrentTradePeriod,i_Type1MixedConstraint,i_Type1MixedConstraintRHS));
    Type1MixedConstraintLimit2(CurrentTradePeriod,i_Type1MixedConstraint) = sum(i_Type1MixedConstraintRHS $ (ord(i_Type1MixedConstraintRHS) = 3), i_TradePeriodType1MixedConstraintRHSParameters(CurrentTradePeriod,i_Type1MixedConstraint,i_Type1MixedConstraintRHS));
    Type2MixedConstraintSense(CurrentTradePeriod,i_Type2MixedConstraint) = sum(i_ConstraintRHS $ (ord(i_ConstraintRHS) = 1), i_TradePeriodType2MixedConstraintRHSParameters(CurrentTradePeriod,i_Type2MixedConstraint,i_ConstraintRHS));
    Type2MixedConstraintLimit(CurrentTradePeriod,i_Type2MixedConstraint) = sum(i_ConstraintRHS $ (ord(i_ConstraintRHS) = 2), i_TradePeriodType2MixedConstraintRHSParameters(CurrentTradePeriod,i_Type2MixedConstraint,i_ConstraintRHS));
    Type1MixedConstraintCondition(CurrentTradePeriod,i_Type1MixedConstraint) $ (sum(i_Branch $ (HVDCHalfPoles(CurrentTradePeriod,i_Branch) and i_Type1MixedConstraintBranchCondition(i_Type1MixedConstraint,i_Branch)),1)) = yes;

*Initialise generic constraint data for the current trading period
    GenericConstraint(CurrentTradePeriod,i_GenericConstraint) = i_TradePeriodGenericConstraint(CurrentTradePeriod,i_GenericConstraint);
    GenericEnergyOfferConstraintFactors(GenericConstraint,i_Offer) = i_TradePeriodGenericEnergyOfferConstraintFactors(GenericConstraint,i_Offer);
    GenericReserveOfferConstraintFactors(GenericConstraint,i_Offer,i_ReserveClass,i_ReserveType) = i_TradePeriodGenericReserveOfferConstraintFactors(GenericConstraint,i_Offer,i_ReserveClass,i_ReserveType);
    GenericEnergyBidConstraintFactors(GenericConstraint,i_Bid) = i_TradePeriodGenericEnergyBidConstraintFactors(GenericConstraint,i_Bid);
    GenericILReserveBidConstraintFactors(GenericConstraint,i_Bid,i_ReserveClass) = i_TradePeriodGenericILReserveBidConstraintFactors(GenericConstraint,i_Bid,i_ReserveClass);
    GenericBranchConstraintFactors(GenericConstraint,i_Branch) = i_TradePeriodGenericBranchConstraintFactors(GenericConstraint,i_Branch);
    GenericConstraintSense(GenericConstraint) = sum(i_ConstraintRHS $ (ord(i_ConstraintRHS) = 1), i_TradePeriodGenericConstraintRHS(GenericConstraint,i_ConstraintRHS));
    GenericConstraintLimit(GenericConstraint) = sum(i_ConstraintRHS $ (ord(i_ConstraintRHS) = 2), i_TradePeriodGenericConstraintRHS(GenericConstraint,i_ConstraintRHS));

*=====================================================================================
*Additional pre-processing on parameters and variables before model solve
*=====================================================================================

*Calculation of generation limits due to ramp rate limits (See 5.3.1. and 5.3.2. of SPD formulation document)

*RDN - Identification of primary and secondary units
   HasSecondaryOffer(CurrentTradePeriod,i_Offer) $ sum(i_Offer1 $ PrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1), 1) = 1;
   HasPrimaryOffer(CurrentTradePeriod,i_Offer) $ sum(i_Offer1 $ PrimarySecondaryOffer(CurrentTradePeriod,i_Offer1,i_Offer), 1) = 1;

*Calculation 5.3.1.1.
*    GenerationMaximum(Offer) = sum(ValidGenerationOfferBlock(Offer,i_TradeBlock), GenerationOfferMW(Offer,i_TradeBlock));
    GenerationMaximum(Offer) $ (not (HasSecondaryOffer(Offer) or HasPrimaryOffer(Offer))) = sum(ValidGenerationOfferBlock(Offer,i_TradeBlock), GenerationOfferMW(Offer,i_TradeBlock));
    GenerationMaximum(CurrentTradePeriod,i_Offer) $ HasSecondaryOffer(CurrentTradePeriod,i_Offer) = sum(i_TradeBlock $ ValidGenerationOfferBlock(CurrentTradePeriod,i_Offer,i_TradeBlock), GenerationOfferMW(CurrentTradePeriod,i_Offer,i_TradeBlock))
                                                                                                  + sum((i_Offer1,i_TradeBlock) $ (ValidGenerationOfferBlock(CurrentTradePeriod,i_Offer1,i_TradeBlock) and PrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1)), GenerationOfferMW(CurrentTradePeriod,i_Offer1,i_TradeBlock));
*Set the ramp time
    RampTimeUp(Offer) = i_TradingPeriodLength;
    RampTimeDown(Offer) = i_TradingPeriodLength;

*RDN - Calculation 5.3.1.2. - Update to incorporate primary-secondary offers - For primary-secondary offers, only primary offer initial MW and ramp rate is used - Reference: Transpower Market Services
*   RampTimeUp(Offer) $ (RampRateUp(Offer) and ((RampRateUp(Offer)*i_TradingPeriodLength)>(GenerationMaximum(Offer)-GenerationStart(Offer))))
*         = (GenerationMaximum(Offer)-GenerationStart(Offer))/RampRateUp(Offer);

   RampTimeUp(Offer) $ ((not (HasSecondaryOffer(Offer) or HasPrimaryOffer(Offer))) and RampRateUp(Offer) and ((RampRateUp(Offer)*i_TradingPeriodLength)>(GenerationMaximum(Offer)-GenerationStart(Offer))))
         = (GenerationMaximum(Offer)-GenerationStart(Offer))/RampRateUp(Offer);

   RampTimeUp(Offer) $ (HasSecondaryOffer(Offer) and RampRateUp(Offer) and ((RampRateUp(Offer)*i_TradingPeriodLength)>(GenerationMaximum(Offer)-GenerationStart(Offer))))
         = (GenerationMaximum(Offer)-GenerationStart(Offer))/RampRateUp(Offer);

*RDN - Calculation 5.3.1.3. - Update to incorporate primary-secondary offers - For primary-secondary offers, only primary offer initial MW and ramp rate is used - Reference: Transpower Market Services
*   GenerationEndUp(Offer) = GenerationStart(Offer)+(RampRateUp(Offer)*RampTimeUp(Offer));
   GenerationEndUp(Offer) $ (not (HasSecondaryOffer(Offer) or HasPrimaryOffer(Offer))) = GenerationStart(Offer)+(RampRateUp(Offer)*RampTimeUp(Offer));
   GenerationEndUp(Offer) $ HasSecondaryOffer(Offer) = GenerationStart(Offer)+(RampRateUp(Offer)*RampTimeUp(Offer));

*Calculation 5.3.2.1.
*Negative prices for generation offers are not allowed?
   GenerationMinimum(Offer) = 0;

*Calculation 5.3.2.2. - Update to incorporate primary-secondary offers - For primary-secondary offers, only primary offer initial MW and ramp rate is used - Reference: Transpower Market Services
*   RampTimeDown(Offer) $ (RampRateDown(Offer) and ((RampRateDown(Offer)*i_TradingPeriodLength)>(GenerationStart(Offer)-GenerationMinimum(Offer))))
*         = (GenerationStart(Offer)-GenerationMinimum(Offer))/RampRateDown(Offer);

   RampTimeDown(Offer) $ ((not (HasSecondaryOffer(Offer) or HasPrimaryOffer(Offer))) and RampRateDown(Offer) and ((RampRateDown(Offer)*i_TradingPeriodLength)>(GenerationStart(Offer)-GenerationMinimum(Offer))))
         = (GenerationStart(Offer)-GenerationMinimum(Offer))/RampRateDown(Offer);

   RampTimeDown(Offer) $ (HasSecondaryOffer(Offer) and RampRateDown(Offer) and ((RampRateDown(Offer)*i_TradingPeriodLength)>(GenerationStart(Offer)-GenerationMinimum(Offer))))
         = (GenerationStart(Offer)-GenerationMinimum(Offer))/RampRateDown(Offer);


*Calculation 5.3.2.3. - Update to incorporate primary-secondary offers - For primary-secondary offers, only primary offer initial MW and ramp rate is used - Reference: Transpower Market Services
*   GenerationEndDown(Offer) = (GenerationStart(Offer)-(RampRateDown(Offer)*RampTimeDown(Offer))) $ ((GenerationStart(Offer)-(RampRateDown(Offer)*RampTimeDown(Offer))) >= 0);
   GenerationEndDown(Offer) $ (not (HasSecondaryOffer(Offer) or HasPrimaryOffer(Offer))) = (GenerationStart(Offer)-(RampRateDown(Offer)*RampTimeDown(Offer))) $ ((GenerationStart(Offer)-(RampRateDown(Offer)*RampTimeDown(Offer))) >= 0);
   GenerationEndDown(Offer) $ HasSecondaryOffer(Offer) = (GenerationStart(Offer)-(RampRateDown(Offer)*RampTimeDown(Offer))) $ ((GenerationStart(Offer)-(RampRateDown(Offer)*RampTimeDown(Offer))) >= 0);

*Create branch loss segments
    ACBranchLossMW(Branch,i_LossSegment) $ (ValidLossSegment(Branch,i_LossSegment) and ACBranch(Branch) and (ord(i_LossSegment) = 1) ) = LossSegmentMW(Branch,i_LossSegment);
    ACBranchLossMW(Branch,i_LossSegment) $ (ValidLossSegment(Branch,i_LossSegment) and ACBranch(Branch) and (ord(i_LossSegment) > 1) ) = LossSegmentMW(Branch,i_LossSegment) - LossSegmentMW(Branch,i_LossSegment-1);
    ACBranchLossFactor(Branch,i_LossSegment) $ (ValidLossSegment(Branch,i_LossSegment) and ACBranch(Branch)) = LossSegmentFactor(Branch,i_LossSegment);

*Let the first point on the HVDCBreakPointMWFlow and HVDCBreakPointMWLoss be 0
*This allows zero losses and zero flow on the HVDC links otherwise model could be infeasible
    HVDCBreakPointMWFlow(HVDCLink,i_LossSegment) $ (ord(i_LossSegment) = 1) = 0;
    HVDCBreakPointMWLoss(HVDCLink,i_LossSegment) $ (ord(i_LossSegment) = 1) = 0;

    HVDCBreakPointMWFlow(Branch,i_LossSegment) $ (ValidLossSegment(Branch,i_LossSegment) and HVDCLink(Branch) and (ord(i_LossSegment) > 1)) = LossSegmentMW(Branch,i_LossSegment-1);
    HVDCBreakPointMWLoss(Branch,i_LossSegment) $ (ValidLossSegment(Branch,i_LossSegment) and HVDCLink(Branch) and (ord(i_LossSegment) = 2)) = (LossSegmentMW(Branch,i_LossSegment-1) * LossSegmentFactor(Branch,i_LossSegment-1));

    loop((HVDCLink(Branch),i_LossSegment) $ (ord(i_LossSegment) > 2),
       HVDCBreakPointMWLoss(Branch,i_LossSegment) $ ValidLossSegment(Branch,i_LossSegment) = ((LossSegmentMW(Branch,i_LossSegment-1) - LossSegmentMW(Branch,i_LossSegment-2)) * LossSegmentFactor(Branch,i_LossSegment-1)) + HVDCBreakPointMWLoss(Branch,i_LossSegment-1);
    );

*Update the variable bounds and fixing variable values

*Offers and Bids
*Constraint 3.1.1.2
    GENERATIONBLOCK.up(ValidGenerationOfferBlock) = GenerationOfferMW(ValidGenerationOfferBlock);
    GENERATIONBLOCK.fx(Offer,i_TradeBlock) $ (not ValidGenerationOfferBlock(Offer,i_TradeBlock)) = 0;

*RDN - 20130226 - Fix the generation variable for generators that are not connected or do not have a non-zero energy offer
    GENERATION.fx(CurrentTradePeriod,i_Offer) $ (not (PositiveEnergyOffer(CurrentTradePeriod,i_Offer))) = 0;

*RDN - Change to demand bid
*Constraint 3.1.1.3 and 3.1.1.4
*    PURCHASEBLOCK.up(ValidPurchaseBidBlock) = PurchaseBidMW(ValidPurchaseBidBlock);
    PURCHASEBLOCK.up(ValidPurchaseBidBlock) $ (not (UseDSBFDemandBidModel)) = PurchaseBidMW(ValidPurchaseBidBlock);
    PURCHASEBLOCK.lo(ValidPurchaseBidBlock) $ (not (UseDSBFDemandBidModel)) = 0;

    PURCHASEBLOCK.up(ValidPurchaseBidBlock) $ UseDSBFDemandBidModel = PurchaseBidMW(ValidPurchaseBidBlock) $ (PurchaseBidMW(ValidPurchaseBidBlock) > 0);
    PURCHASEBLOCK.lo(ValidPurchaseBidBlock) $ UseDSBFDemandBidModel = PurchaseBidMW(ValidPurchaseBidBlock) $ (PurchaseBidMW(ValidPurchaseBidBlock) < 0);

    PURCHASEBLOCK.fx(Bid,i_TradeBlock) $ (not ValidPurchaseBidBlock(Bid,i_TradeBlock)) = 0;
*RDN - Change to demand bid - End

*RDN - 20130226 - Fix the purchase variable for purchasers that are not connected or do not have a non-zero purchase bid
    PURCHASE.fx(CurrentTradePeriod,i_Bid) $ (not (sum(i_TradeBlock $ ValidPurchaseBidBlock(CurrentTradePeriod,i_Bid,i_TradeBlock),1))) = 0;

*Network
*Ensure that variables used to specify flow and losses on HVDC link are zero for AC branches and for open HVDC links.
    HVDCLINKFLOW.fx(ACBranch) = 0;
    HVDCLINKFLOW.fx(OpenBranch(HVDCLink)) = 0;
    HVDCLINKLOSSES.fx(ACBranch) = 0;
    HVDCLINKLOSSES.fx(OpenBranch(HVDCLink)) = 0;
*RDN - 20130227 - Set HVDC link flow and losses to zero for all branches that are not HVDC link
    HVDCLINKFLOW.fx(CurrentTradePeriod,i_Branch) $ (not Branch(CurrentTradePeriod,i_Branch)) = 0;
    HVDCLINKLOSSES.fx(CurrentTradePeriod,i_Branch) $ (not Branch(CurrentTradePeriod,i_Branch)) = 0;

*Apply an upper bound on the weighting parameter based on its definition
    LAMBDA.up(Branch,i_LossSegment) = 1;
*Ensure that the weighting factor value is zero for AC branches and for invalid loss segments on HVDC links
    LAMBDA.fx(ACBranch,i_LossSegment) = 0;
    LAMBDA.fx(HVDCLink,i_LossSegment) $ (not (ValidLossSegment(HVDCLink,i_LossSegment))) = 0;
*RDN - 20130227 - Set HVDC link flow and losses to zero for all branches that are not HVDC link
    LAMBDA.fx(CurrentTradePeriod,i_Branch,i_LossSegment) $ (not Branch(CurrentTradePeriod,i_Branch)) = 0;

*Ensure that variables used to specify flow and losses on AC branches are zero for HVDC links branches and for open AC branches
    ACBRANCHFLOW.fx(HVDCLink) = 0;
    ACBRANCHFLOW.fx(OpenBranch) = 0;
*RDN - 20130227 - Set HVDC link flow and losses to zero for all branches that are not HVDC link
    ACBRANCHFLOW.fx(CurrentTradePeriod,i_Branch) $ (not Branch(CurrentTradePeriod,i_Branch)) = 0;

    ACBRANCHFLOWDIRECTED.fx(OpenBranch,i_FlowDirection) = 0;
    ACBRANCHFLOWDIRECTED.fx(HVDCLink,i_FlowDirection) = 0;
*RDN - 20130227 - Set AC flow and losses to zero for all branches that are not in the AC branches set
    ACBRANCHFLOWDIRECTED.fx(CurrentTradePeriod,i_Branch,i_FlowDirection) $ (not Branch(CurrentTradePeriod,i_Branch)) = 0;

    ACBRANCHLOSSESDIRECTED.fx(OpenBranch,i_FlowDirection) = 0;
    ACBRANCHLOSSESDIRECTED.fx(HVDCLink,i_FlowDirection) = 0;
*RDN - 20130227 - Set AC flow and losses to zero for all branches that are not in the AC branches set
    ACBRANCHLOSSESDIRECTED.fx(CurrentTradePeriod,i_Branch,i_FlowDirection) $ (not Branch(CurrentTradePeriod,i_Branch)) = 0;

*Ensure that variables used to specify block flow and block losses on AC branches are zero for HVDC links, open AC branches
*and invalid loss segments on closed AC branches
    ACBRANCHFLOWBLOCKDIRECTED.fx(Branch,i_LossSegment,i_FlowDirection) $ (not (ValidLossSegment(Branch,i_LossSegment))) = 0;
    ACBRANCHFLOWBLOCKDIRECTED.fx(OpenBranch,i_LossSegment,i_FlowDirection) = 0;
    ACBRANCHFLOWBLOCKDIRECTED.fx(HVDCLink,i_LossSegment,i_FlowDirection) = 0;
*RDN - 20130227 - Set AC block flow and block losses to zero for all branches that are not in the AC branches set
    ACBRANCHFLOWBLOCKDIRECTED.fx(CurrentTradePeriod,i_Branch,i_LossSegment,i_FlowDirection) $ (not Branch(CurrentTradePeriod,i_Branch)) = 0;

    ACBRANCHLOSSESBLOCKDIRECTED.fx(Branch,i_LossSegment,i_FlowDirection) $ (not (ValidLossSegment(Branch,i_LossSegment))) = 0;
    ACBRANCHLOSSESBLOCKDIRECTED.fx(OpenBranch,i_LossSegment,i_FlowDirection) = 0;
    ACBRANCHLOSSESBLOCKDIRECTED.fx(HVDCLink,i_LossSegment,i_FlowDirection) = 0;
*RDN - 20130227 - Set AC block flow and block losses to zero for all branches that are not in the AC branches set
    ACBRANCHLOSSESBLOCKDIRECTED.fx(CurrentTradePeriod,i_Branch,i_LossSegment,i_FlowDirection) $ (not Branch(CurrentTradePeriod,i_Branch)) = 0;

*Ensure that the bus voltage angle for the buses corresponding to the reference nodes and the HVDC nodes are set to zero
*Constraint 3.3.1.10
    ACNODEANGLE.fx(CurrentTradePeriod,i_Bus) $ sum(i_Node $ (NodeBus(CurrentTradePeriod,i_Node,i_Bus) and ReferenceNode(CurrentTradePeriod,i_Node)),1) = 0;
    ACNODEANGLE.fx(CurrentTradePeriod,i_Bus) $ sum(i_Node $ (NodeBus(CurrentTradePeriod,i_Node,i_Bus) and HVDCNode(CurrentTradePeriod,i_Node)),1) = 0;

*Risk/Reserve
*Ensure that all the invalid reserve blocks are set to zero for offers and purchasers
    RESERVEBLOCK.fx(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ (not (ValidReserveOfferBlock(Offer,i_TradeBlock,i_ReserveClass,i_ReserveType))) = 0;
    PURCHASEILRBLOCK.fx(Bid,i_TradeBlock,i_ReserveClass) $ (not (ValidPurchaseBidILRBlock(Bid,i_TradeBlock,i_ReserveClass))) = 0;
*Reserve block maximum for offers and purchasers - Constraint 3.4.2.2.
    RESERVEBLOCK.up(ValidReserveOfferBlock) = ReserveOfferMaximum(ValidReserveOfferBlock);
    PURCHASEILRBLOCK.up(ValidPurchaseBidILRBlock) = PurchaseBidILRMW(ValidPurchaseBidILRBlock);

*RDN - 20130226 - Fix the reserve variable for invalid reserve offers. These are offers that are either not connected to the grid or have no reserve quantity offered.
    RESERVE.fx(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType) $ (not (sum(i_TradeBlock $ ValidReserveOfferBlock(CurrentTradePeriod,i_Offer,i_TradeBlock,i_ReserveClass,i_ReserveType),1))) = 0;
*RDN - 20130226 - Fix the purchase ILR variable for invalid purchase reserve offers. These are offers that are either not connected to the grid or have no reserve quantity offered.
    PURCHASEILR.fx(CurrentTradePeriod,i_Bid,i_ReserveClass) $ (not (sum(i_TradeBlock $ ValidPurchaseBidILRBlock(CurrentTradePeriod,i_Bid,i_TradeBlock,i_ReserveClass),1))) = 0;

*Risk offset fixed to zero for those not mapped to corresponding mixed constraint variable
*    RISKOFFSET.fx(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) $ (i_UseMixedConstraintRiskOffset and i_UseMixedConstraint and (not sum(i_Type1MixedConstraint $ i_Type1MixedConstraintReserveMap(i_Type1MixedConstraint,i_Island,i_ReserveClass,i_RiskClass),1))) = 0;
    RISKOFFSET.fx(CurrentTradePeriod,i_Island,i_ReserveClass,i_RiskClass) $ (i_UseMixedConstraintRiskOffset and UseMixedConstraint(CurrentTradePeriod) and (not sum(i_Type1MixedConstraint $ i_Type1MixedConstraintReserveMap(i_Type1MixedConstraint,i_Island,i_ReserveClass,i_RiskClass),1))) = 0;

*RDN - Fix the appropriate deficit variable to zero depending on whether the different CE and ECE CVP flag is set
    DEFICITRESERVE.fx(CurrentTradePeriod,i_Island,i_ReserveClass) $ DiffCeECeCVP = 0;
    DEFICITRESERVE_CE.fx(CurrentTradePeriod,i_Island,i_ReserveClass) $ (not DiffCeECeCVP) = 0;
    DEFICITRESERVE_ECE.fx(CurrentTradePeriod,i_Island,i_ReserveClass) $ (not DiffCeECeCVP) = 0;

*Mixed constraint
    MIXEDCONSTRAINTVARIABLE.fx(CurrentTradePeriod,i_Type1MixedConstraint) $ (not (i_Type1MixedConstraintVarWeight(i_Type1MixedConstraint))) = 0;

*============================
*Solve the model
*============================

*Set the bratio to 1 i.e. do not use advanced basis for LP
    option bratio = 1;
*Set resource limits
    VSPD.reslim = LPTimeLimit;
    VSPD.iterlim = LPIterationLimit;
    solve VSPD using lp maximizing NETBENEFIT;
*Set the model solve status
    ModelSolved = 1 $ ((VSPD.modelstat = 1) and (VSPD.solvestat = 1));

*Post a progress message to report for use by GUI and to the console.
    if((ModelSolved = 1) and (i_SequentialSolve = 0),
      putclose runlog / 'The case: %VSPDInputData% finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                         'Violation Cost: ' TOTALPENALTYCOST.l:<12:1 /
    elseif((ModelSolved = 0) and (i_SequentialSolve = 0)),
      putclose runlog / 'The case: %VSPDInputData% finished at ', system.time '. Solve unsuccessful.' /
    ) ;


    if((ModelSolved = 1) and (i_SequentialSolve = 1),
      loop(CurrentTradePeriod(i_TradePeriod),
         putclose runlog / 'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                            'Violations: ' TOTALPENALTYCOST.l:<12:1 /
      );
    elseif((ModelSolved = 0) and (i_SequentialSolve = 1)),
      loop(CurrentTradePeriod(i_TradePeriod),
         putclose runlog / 'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') finished at ', system.time '. Solve unsuccessful.' /
      );
    ) ;

*==============================================
*Check if the LP results are valid
*==============================================
    if ((ModelSolved = 1),
*Check if there are circulating branch flows on loss AC branches and HVDC links
       CircularBranchFlowExist(ACBranch) $ (LossBranch(ACBranch) and (abs(sum(i_FlowDirection, ACBRANCHFLOWDIRECTED.l(ACBranch,i_FlowDirection)) - abs(ACBRANCHFLOW.l(ACBranch))) > CircularBranchFlowTolerance)) = 1;

*RDN - Determine the circular branch flow flag on each HVDC pole
       TotalHVDCPoleFlow(CurrentTradePeriod,i_Pole) =
       sum(i_Branch $ HVDCPoleBranchMap(i_Pole,i_Branch), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch));

       MaxHVDCPoleFlow(CurrentTradePeriod,i_Pole) =
       smax(i_Branch $ HVDCPoleBranchMap(i_Pole,i_Branch), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch));

       PoleCircularBranchFlowExist(CurrentTradePeriod,i_Pole) $ ((abs(TotalHVDCPoleFlow(CurrentTradePeriod,i_Pole)-MaxHVDCPoleFlow(CurrentTradePeriod,i_Pole)) > CircularBranchFlowTolerance)) = 1;

       NorthHVDC(CurrentTradePeriod) = sum((i_Island,i_Bus,i_Branch) $ ((ord(i_Island) = 2) and i_TradePeriodBusIsland(CurrentTradePeriod,i_Bus,i_Island) and HVDCLinkSendingBus(CurrentTradePeriod,i_Branch,i_Bus) and HVDCPoles(CurrentTradePeriod,i_Branch)), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch));
       SouthHVDC(CurrentTradePeriod) = sum((i_Island,i_Bus,i_Branch) $ ((ord(i_Island) = 1) and i_TradePeriodBusIsland(CurrentTradePeriod,i_Bus,i_Island) and HVDCLinkSendingBus(CurrentTradePeriod,i_Branch,i_Bus) and HVDCPoles(CurrentTradePeriod,i_Branch)), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch));

       CircularBranchFlowExist(CurrentTradePeriod,i_Branch) $ (HVDCPoles(CurrentTradePeriod,i_Branch) and LossBranch(CurrentTradePeriod,i_Branch) and (min(NorthHVDC(CurrentTradePeriod), SouthHVDC(CurrentTradePeriod)) > CircularBranchFlowTolerance)) = 1;

*Check if there are non-physical losses on loss AC branches and HVDC links
       ManualBranchSegmentMWFlow(ValidLossSegment(ACBranch,i_LossSegment)) $ LossBranch(ACBranch) = min(max((abs(ACBRANCHFLOW.l(ACBranch))-(LossSegmentMW(ACBranch,i_LossSegment-1))$(ord(i_LossSegment) > 1)),0),ACBranchLossMW(ACBranch,i_LossSegment));
       ManualBranchSegmentMWFlow(ValidLossSegment(HVDCLink,i_LossSegment)) $ (LossBranch(HVDCLink) and (ord(i_LossSegment) <= HVDCLinkLossBlocks(HVDCLink))) = min(max((abs(HVDCLINKFLOW.l(HVDCLink))-(LossSegmentMW(HVDCLink,i_LossSegment-1))$(ord(i_LossSegment) > 1)),0),(LossSegmentMW(HVDCLink,i_LossSegment) - (LossSegmentMW(HVDCLink,i_LossSegment-1))$(ord(i_LossSegment) > 1)));
       ManualLossCalculation(Branch) $ LossBranch(Branch) = sum(i_LossSegment, LossSegmentFactor(Branch,i_LossSegment) * ManualBranchSegmentMWFlow(Branch,i_LossSegment));
       NonPhysicalLossExist(ACBranch) $ (LossBranch(ACBranch) and (abs(ManualLossCalculation(ACBranch) - sum(i_FlowDirection, ACBRANCHLOSSESDIRECTED.l(ACBranch,i_FlowDirection))) > NonPhysicalLossTolerance)) = 1;
       NonPhysicalLossExist(HVDCLink) $ (LossBranch(HVDCLink) and (abs(ManualLossCalculation(HVDCLink) - HVDCLINKLOSSES.l(HVDCLink)) > NonPhysicalLossTolerance)) = 1;

*Invoke the UseBranchFlowMIP flag if the number of circular branch flow and non-physical loss branches exceeds the specified tolerance
*RDN - Test - update logic to include roundpower logic
*       UseBranchFlowMIP(CurrentTradePeriod) $ ((sum(i_Branch $ (ACBranch(CurrentTradePeriod,i_Branch) and LossBranch(CurrentTradePeriod,i_Branch)), i_ResolveCircularBranchFlows*CircularBranchFlowExist(CurrentTradePeriod,i_Branch) + i_ResolveACNonPhysicalLosses*NonPhysicalLossExist(CurrentTradePeriod,i_Branch)) +
*         sum(i_Branch $ (LossBranch(CurrentTradePeriod,i_Branch) and HVDCLink(CurrentTradePeriod,i_Branch)), i_ResolveCircularBranchFlows*CircularBranchFlowExist(CurrentTradePeriod,i_Branch) + i_ResolveHVDCNonPhysicalLosses*NonPhysicalLossExist(CurrentTradePeriod,i_Branch)))
*         > UseBranchFlowMIPTolerance) = 1;
       UseBranchFlowMIP(CurrentTradePeriod) $ ((sum(i_Branch $ (ACBranch(CurrentTradePeriod,i_Branch) and LossBranch(CurrentTradePeriod,i_Branch)), i_ResolveCircularBranchFlows*CircularBranchFlowExist(CurrentTradePeriod,i_Branch) + i_ResolveACNonPhysicalLosses*NonPhysicalLossExist(CurrentTradePeriod,i_Branch)) +
         sum(i_Branch $ (LossBranch(CurrentTradePeriod,i_Branch) and HVDCLink(CurrentTradePeriod,i_Branch)), (1-AllowHVDCRoundpower(CurrentTradePeriod))*i_ResolveCircularBranchFlows*CircularBranchFlowExist(CurrentTradePeriod,i_Branch) + i_ResolveHVDCNonPhysicalLosses*NonPhysicalLossExist(CurrentTradePeriod,i_Branch))) +
         sum(i_Pole, i_ResolveCircularBranchFlows*PoleCircularBranchFlowExist(CurrentTradePeriod,i_Pole))
         > UseBranchFlowMIPTolerance) = 1;

*Detect if branch flow MIP is needed
       BranchFlowMIPInvoked(CurrentTradePeriod) = UseBranchFlowMIP(CurrentTradePeriod);

*Check branch flows for relevant mixed constraint to check if integer variables are needed
*RDN - Updated the condition to i_UseMixedConstraintRiskOffset which is specific to the original mixed constraint application
*       if (i_UseMixedConstraint,
       if (i_UseMixedConstraintRiskOffset,
          HVDCHalfPoleSouthFlow(CurrentTradePeriod) $ (sum(i_Type1MixedConstraintBranchCondition(i_Type1MixedConstraint,i_Branch) $ HVDCHalfPoles(CurrentTradePeriod,i_Branch), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch)) > MixedMIPTolerance) = 1;
*RDN - Change definition to only calculate violation if the constraint limit is non-zero
*          Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition)
          Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition) $ (Type1MixedConstraintLimit2(Type1MixedConstraintCondition) > 0)
              = (Type1MixedConstraintLE.l(Type1MixedConstraintCondition) - Type1MixedConstraintLimit2(Type1MixedConstraintCondition)) $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = -1)
              + (Type1MixedConstraintLimit2(Type1MixedConstraintCondition) - Type1MixedConstraintGE.l(Type1MixedConstraintCondition)) $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = 1)
              + abs(Type1MixedConstraintEQ.l(Type1MixedConstraintCondition) - Type1MixedConstraintLimit2(Type1MixedConstraintCondition)) $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = 0);
*Integer constraints are needed if southward flow on half-poles AND constraint level exceeds the mixed constraint limit2 value
          UseMixedConstraintMIP(CurrentTradePeriod) $ (HVDCHalfPoleSouthFlow(CurrentTradePeriod) and sum(i_Type1MixedConstraint $ (Type1MixedConstraintLimit2Violation(CurrentTradePeriod,i_Type1MixedConstraint) > MixedMIPTolerance),1)) = 1;
       );

*Skip the resolve logic if the simultaneous mode requires integer variables since the problem becomes large MILP
*Resolve in sequential mode
       SkipResolve $ ((not i_SequentialSolve) and ((sum(CurrentTradePeriod, UseBranchFlowMIP(CurrentTradePeriod) + UseMixedConstraintMIP(CurrentTradePeriod)) and (card(CurrentTradePeriod) > ThresholdSimultaneousInteger))) ) = 1;


*Post a progress message to report for use by GUI. Reverting to the sequential mode for integer resolves.
       if(((not i_SequentialSolve) and sum(CurrentTradePeriod, UseBranchFlowMIP(CurrentTradePeriod) + UseMixedConstraintMIP(CurrentTradePeriod))),
          putclose runlog / 'The case: %VSPDInputData% requires an integer resolve.  Switching Vectorisation OFF.' /
       ) ;

*Post a progress message to report for use by GUI. Reverting to the sequential mode for integer resolves.
       if((i_SequentialSolve and sum(CurrentTradePeriod, UseBranchFlowMIP(CurrentTradePeriod) + UseMixedConstraintMIP(CurrentTradePeriod))),
         loop(CurrentTradePeriod(i_TradePeriod),
             putclose runlog / 'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') requires an integer resolve.' /
         ) ;
       ) ;

*==========================================
*Resolve the model if required
*==========================================
       if( not SkipResolve,

         if ((sum(CurrentTradePeriod, UseBranchFlowMIP(CurrentTradePeriod)) * sum(CurrentTradePeriod,UseMixedConstraintMIP(CurrentTradePeriod))) >= 1,
*Don't use integer variables for periods that do not need them
          MIXEDCONSTRAINTLIMIT2SELECT.fx(CurrentTradePeriod,i_Type1MixedConstraint) $ (not UseMixedConstraintMIP(CurrentTradePeriod)) = 0;
          ACBRANCHFLOWDIRECTED_INTEGER.fx(CurrentTradePeriod,i_Branch,i_FlowDirection) $ (not UseBranchFlowMIP(CurrentTradePeriod)) = 0;
          HVDCLINKFLOWDIRECTION_INTEGER.fx(CurrentTradePeriod,i_FlowDirection) $ (not UseBranchFlowMIP(CurrentTradePeriod)) = 0;
*RDN - Don't use the integer variables if not needed
         HVDCPOLEFLOW_INTEGER.fx(CurrentTradePeriod,i_Pole,i_FlowDirection) $ (not UseBranchFlowMIP(CurrentTradePeriod)) = 0;

          LAMBDAINTEGER.fx(CurrentTradePeriod,i_Branch,i_LossSegment) $ (not UseBranchFlowMIP(CurrentTradePeriod)) = 0;
*Fix the values of these integer variables that are not needed
          ACBRANCHFLOWDIRECTED_INTEGER.fx(Branch(CurrentTradePeriod,i_Branch),i_FlowDirection) $ (UseBranchFlowMIP(CurrentTradePeriod) and (HVDCLink(Branch) or (not LossBranch(Branch)) or OpenBranch(Branch))) = 0;
*RDN - 20130227 - Fix the integer AC branch flow variable to zero for invalid branches
          ACBRANCHFLOWDIRECTED_INTEGER.fx(CurrentTradePeriod,i_Branch,i_FlowDirection) $ (UseBranchFlowMIP(CurrentTradePeriod) and (not Branch(CurrentTradePeriod,i_Branch))) = 0;

*Apply an upper bound on the integer weighting parameter based on its definition
          LAMBDAINTEGER.up(Branch(CurrentTradePeriod,i_Branch),i_LossSegment) $ UseBranchFlowMIP(CurrentTradePeriod) = 1;
*Ensure that the weighting factor value is zero for AC branches and for invalid loss segments on HVDC links
          LAMBDAINTEGER.fx(Branch(CurrentTradePeriod,i_Branch),i_LossSegment) $ (UseBranchFlowMIP(CurrentTradePeriod) and (ACBranch(Branch) or (not (ValidLossSegment(Branch,i_LossSegment) and HVDCLink(Branch))))) = 0;
*RDN - 20130227 - Fix the lambda integer variable to zero for invalid branches
          LAMBDAINTEGER.fx(CurrentTradePeriod,i_Branch,i_LossSegment) $ (UseBranchFlowMIP(CurrentTradePeriod) and (not Branch(CurrentTradePeriod,i_Branch))) = 0;

*Fix the value of some binary variables used in the mixed constraints that have no alternate limit
          MIXEDCONSTRAINTLIMIT2SELECT.fx(Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint)) $ (UseMixedConstraintMIP(CurrentTradePeriod) and (not Type1MixedConstraintCondition(Type1MixedConstraint))) = 0;
*Use the advanced basis here
          option bratio = 0.25;
*Set the optimality criteria for the MIP
          VSPD_MIP.optcr = MIPOptimality;
          VSPD_MIP.reslim = MIPTimeLimit;
          VSPD_MIP.iterlim = MIPIterationLimit;
*Solve the model
          solve VSPD_MIP using mip maximizing NETBENEFIT;
*Set the model solve status
*          ModelSolved = 1 $ (((VSPD_MIP.modelstat = 1) or (VSPD_MIP.modelstat = 7)) and (VSPD_MIP.solvestat = 1));
          ModelSolved = 1 $ (((VSPD_MIP.modelstat = 1) or (VSPD_MIP.modelstat = 8)) and (VSPD_MIP.solvestat = 1));

*Post a progress message to report for use by GUI.
          if(ModelSolved = 1,
             loop(CurrentTradePeriod(i_TradePeriod),
                  putclose runlog / 'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') FULL integer solve finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                                     'Violations: ' TOTALPENALTYCOST.l:<12:1 /
             );
          else
             loop(CurrentTradePeriod(i_TradePeriod),
                  putclose runlog / 'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') FULL integer solve finished at ', system.time '. Solve unsuccessful.' /
             );
          ) ;

         else

          if ((sum(CurrentTradePeriod, UseBranchFlowMIP(CurrentTradePeriod)) >= 1),
*Don't use integer variables for periods that do not need them
             ACBRANCHFLOWDIRECTED_INTEGER.fx(CurrentTradePeriod,i_Branch,i_FlowDirection) $ (not UseBranchFlowMIP(CurrentTradePeriod)) = 0;
             HVDCLINKFLOWDIRECTION_INTEGER.fx(CurrentTradePeriod,i_FlowDirection) $ (not UseBranchFlowMIP(CurrentTradePeriod)) = 0;
*RDN - Don't use the integer varaibles if not needed
             HVDCPOLEFLOW_INTEGER.fx(CurrentTradePeriod,i_Pole,i_FlowDirection) $ (not UseBranchFlowMIP(CurrentTradePeriod)) = 0;

             LAMBDAINTEGER.fx(CurrentTradePeriod,i_Branch,i_LossSegment) $ (not UseBranchFlowMIP(CurrentTradePeriod)) = 0;
*Fix the values of these integer variables that are not needed
             ACBRANCHFLOWDIRECTED_INTEGER.fx(Branch(CurrentTradePeriod,i_Branch),i_FlowDirection) $ (UseBranchFlowMIP(CurrentTradePeriod) and (HVDCLink(Branch) or (not LossBranch(Branch)) or OpenBranch(Branch))) = 0;
*RDN - 20130227 - Fix the integer AC branch flow variable to zero for invalid branches
             ACBRANCHFLOWDIRECTED_INTEGER.fx(CurrentTradePeriod,i_Branch,i_FlowDirection) $ (UseBranchFlowMIP(CurrentTradePeriod) and (not Branch(CurrentTradePeriod,i_Branch))) = 0;
*Apply an upper bound on the integer weighting parameter based on its definition
             LAMBDAINTEGER.up(Branch(CurrentTradePeriod,i_Branch),i_LossSegment) $ UseBranchFlowMIP(CurrentTradePeriod) = 1;
*Ensure that the weighting factor value is zero for AC branches and for invalid loss segments on HVDC links
             LAMBDAINTEGER.fx(Branch(CurrentTradePeriod,i_Branch),i_LossSegment) $ (UseBranchFlowMIP(CurrentTradePeriod) and (ACBranch(Branch) or (not (ValidLossSegment(Branch,i_LossSegment) and HVDCLink(Branch))))) = 0;
*RDN - 20130227 - Fix the lambda integer variable to zero for invalid branches
             LAMBDAINTEGER.fx(CurrentTradePeriod,i_Branch,i_LossSegment) $ (UseBranchFlowMIP(CurrentTradePeriod) and (not Branch(CurrentTradePeriod,i_Branch))) = 0;
*Use the advanced basis here
             option bratio = 0.25;
*Set the optimality criteria for the MIP
             VSPD_BranchFlowMIP.optcr = MIPOptimality;
             VSPD_BranchFlowMIP.reslim = MIPTimeLimit;
             VSPD_BranchFlowMIP.iterlim = MIPIterationLimit;
*Solve the model
             solve VSPD_BranchFlowMIP using mip maximizing NETBENEFIT;
*Set the model solve status
             ModelSolved = 1 $ (((VSPD_BranchFlowMIP.modelstat = 1) or (VSPD_BranchFlowMIP.modelstat = 8)) and (VSPD_BranchFlowMIP.solvestat = 1));

*Post a progress message to report for use by GUI.
          if(ModelSolved = 1,
             loop(CurrentTradePeriod(i_TradePeriod),
                  putclose runlog / 'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') BRANCH integer solve finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                                     'Violations: ' TOTALPENALTYCOST.l:<12:1 /
             );
          else
             loop(CurrentTradePeriod(i_TradePeriod),
                  putclose runlog / 'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') BRANCH integer solve finished at ', system.time '. Solve unsuccessful.' /
             );
          ) ;

          elseif (sum(CurrentTradePeriod, UseMixedConstraintMIP(CurrentTradePeriod)) >= 1),
*Don't use integer variables for periods that do not need them
             MIXEDCONSTRAINTLIMIT2SELECT.fx(CurrentTradePeriod,i_Type1MixedConstraint) $ (not UseMixedConstraintMIP(CurrentTradePeriod)) = 0;
*Fix the value of some binary variables used in the mixed constraints that have no alternate limit
             MIXEDCONSTRAINTLIMIT2SELECT.fx(Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint)) $ (UseMixedConstraintMIP(CurrentTradePeriod) and (not Type1MixedConstraintCondition(Type1MixedConstraint))) = 0;
*Use the advanced basis here
             option bratio = 0.25;
*Set the optimality criteria for the MIP
             VSPD_MixedConstraintMIP.optcr = MIPOptimality;
             VSPD_MixedConstraintMIP.reslim = MIPTimeLimit;
             VSPD_MixedConstraintMIP.iterlim = MIPIterationLimit;
*Solve the model
             solve VSPD_MixedConstraintMIP using mip maximizing NETBENEFIT;
*Set the model solve status
             ModelSolved = 1 $ (((VSPD_MixedConstraintMIP.modelstat = 1) or (VSPD_MixedConstraintMIP.modelstat = 8)) and (VSPD_MixedConstraintMIP.solvestat = 1));

*Post a progress message to report for use by GUI.
          if(ModelSolved = 1,
             loop(CurrentTradePeriod(i_TradePeriod),
                  putclose runlog / 'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') MIXED integer solve finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                                     'Violations: ' TOTALPENALTYCOST.l:<12:1 /
             );
          else
             loop(CurrentTradePeriod(i_TradePeriod),
                  putclose runlog / 'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') MIXED integer solve finished at ', system.time '. Solve unsuccessful.' /
             );
          ) ;

          else
*Set the LP valid flag
             LPValid = 1;
          );
         );

*If either the VSPD_BranchFlowMIP or the VSPD_MixedConstraintMIP returned a valid solution
         if (((ModelSolved * (sum(CurrentTradePeriod, UseMixedConstraintMIP(CurrentTradePeriod) + UseBranchFlowMIP(CurrentTradePeriod)))) >= 1),

**Re-check the MIP solved solution
*Check if there are circulating branch flows on loss AC branches and HVDC links and if mixed constraints are violated
*Reset the relevant parameters
          CircularBranchFlowExist(Branch) = 0;
          NorthHVDC(CurrentTradePeriod) = 0;
          SouthHVDC(CurrentTradePeriod) = 0;
*RDN - Reset the pole circular branch flow flag
          PoleCircularBranchFlowExist(CurrentTradePeriod,i_Pole) = 0;

          ManualBranchSegmentMWFlow(i_TradePeriod,i_Branch,i_LossSegment) = 0;
          ManualLossCalculation(Branch) = 0;
          NonPhysicalLossExist(Branch)= 0;
          UseBranchFlowMIP(CurrentTradePeriod) = 0;

*Check if there are circulating branch flows on loss AC branches and HVDC links
          CircularBranchFlowExist(ACBranch) $ (LossBranch(ACBranch) and (abs(sum(i_FlowDirection, ACBRANCHFLOWDIRECTED.l(ACBranch,i_FlowDirection)) - abs(ACBRANCHFLOW.l(ACBranch))) > CircularBranchFlowTolerance)) = 1;
          NorthHVDC(CurrentTradePeriod) = sum((i_Island,i_Bus,i_Branch) $ ((ord(i_Island) = 2) and i_TradePeriodBusIsland(CurrentTradePeriod,i_Bus,i_Island) and HVDCLinkSendingBus(CurrentTradePeriod,i_Branch,i_Bus) and HVDCPoles(CurrentTradePeriod,i_Branch)), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch));
          SouthHVDC(CurrentTradePeriod) = sum((i_Island,i_Bus,i_Branch) $ ((ord(i_Island) = 1) and i_TradePeriodBusIsland(CurrentTradePeriod,i_Bus,i_Island) and HVDCLinkSendingBus(CurrentTradePeriod,i_Branch,i_Bus) and HVDCPoles(CurrentTradePeriod,i_Branch)), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch));
          CircularBranchFlowExist(CurrentTradePeriod,i_Branch) $ (HVDCPoles(CurrentTradePeriod,i_Branch) and LossBranch(CurrentTradePeriod,i_Branch) and (min(NorthHVDC(CurrentTradePeriod), SouthHVDC(CurrentTradePeriod)) > CircularBranchFlowTolerance)) = 1;

*RDN - Determine the circular branch flow flag on each HVDC pole
          TotalHVDCPoleFlow(CurrentTradePeriod,i_Pole) =
          sum(i_Branch $ HVDCPoleBranchMap(i_Pole,i_Branch), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch));

          MaxHVDCPoleFlow(CurrentTradePeriod,i_Pole) =
          smax(i_Branch $ HVDCPoleBranchMap(i_Pole,i_Branch), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch));

          PoleCircularBranchFlowExist(CurrentTradePeriod,i_Pole) $ ((abs(TotalHVDCPoleFlow(CurrentTradePeriod,i_Pole)-MaxHVDCPoleFlow(CurrentTradePeriod,i_Pole)) > CircularBranchFlowTolerance)) = 1;

*Check if there are non-physical losses on loss AC branches and HVDC links
          ManualBranchSegmentMWFlow(ValidLossSegment(ACBranch,i_LossSegment)) $ LossBranch(ACBranch) = min(max((abs(ACBRANCHFLOW.l(ACBranch))-(LossSegmentMW(ACBranch,i_LossSegment-1))$(ord(i_LossSegment) > 1)),0),ACBranchLossMW(ACBranch,i_LossSegment));
          ManualBranchSegmentMWFlow(ValidLossSegment(HVDCLink,i_LossSegment)) $ (LossBranch(HVDCLink) and (ord(i_LossSegment) <= HVDCLinkLossBlocks(HVDCLink))) = min(max((abs(HVDCLINKFLOW.l(HVDCLink))-(LossSegmentMW(HVDCLink,i_LossSegment-1))$(ord(i_LossSegment) > 1)),0),(LossSegmentMW(HVDCLink,i_LossSegment) - (LossSegmentMW(HVDCLink,i_LossSegment-1))$(ord(i_LossSegment) > 1)));
          ManualLossCalculation(Branch) $ LossBranch(Branch) = sum(i_LossSegment, LossSegmentFactor(Branch,i_LossSegment) * ManualBranchSegmentMWFlow(Branch,i_LossSegment));
          NonPhysicalLossExist(ACBranch) $ (LossBranch(ACBranch) and (abs(ManualLossCalculation(ACBranch) - sum(i_FlowDirection, ACBRANCHLOSSESDIRECTED.l(ACBranch,i_FlowDirection))) > NonPhysicalLossTolerance)) = 1;
          NonPhysicalLossExist(HVDCLink) $ (LossBranch(HVDCLink) and (abs(ManualLossCalculation(HVDCLink) - HVDCLINKLOSSES.l(HVDCLink)) > NonPhysicalLossTolerance)) = 1;

*Invoke the UseBranchFlowMIP flag if the number of circular branch flow and non-physical loss branches exceeds the specified tolerance
*RDN - Test - update logic to include roundpower logic
*          UseBranchFlowMIP(CurrentTradePeriod) $ ((sum(i_Branch $ (ACBranch(CurrentTradePeriod,i_Branch) and LossBranch(CurrentTradePeriod,i_Branch)), i_ResolveCircularBranchFlows*CircularBranchFlowExist(CurrentTradePeriod,i_Branch) + i_ResolveACNonPhysicalLosses*NonPhysicalLossExist(CurrentTradePeriod,i_Branch)) +
*            sum(i_Branch $ (LossBranch(CurrentTradePeriod,i_Branch) and HVDCLink(CurrentTradePeriod,i_Branch)), i_ResolveCircularBranchFlows*CircularBranchFlowExist(CurrentTradePeriod,i_Branch) + i_ResolveHVDCNonPhysicalLosses*NonPhysicalLossExist(CurrentTradePeriod,i_Branch)))
*            > UseBranchFlowMIPTolerance) = 1;
          UseBranchFlowMIP(CurrentTradePeriod) $ ((sum(i_Branch $ (ACBranch(CurrentTradePeriod,i_Branch) and LossBranch(CurrentTradePeriod,i_Branch)), i_ResolveCircularBranchFlows*CircularBranchFlowExist(CurrentTradePeriod,i_Branch) + i_ResolveACNonPhysicalLosses*NonPhysicalLossExist(CurrentTradePeriod,i_Branch)) +
            sum(i_Branch $ (LossBranch(CurrentTradePeriod,i_Branch) and HVDCLink(CurrentTradePeriod,i_Branch)), (1-AllowHVDCRoundpower(CurrentTradePeriod))*i_ResolveCircularBranchFlows*CircularBranchFlowExist(CurrentTradePeriod,i_Branch) + i_ResolveHVDCNonPhysicalLosses*NonPhysicalLossExist(CurrentTradePeriod,i_Branch))) +
            sum(i_Pole, i_ResolveCircularBranchFlows*PoleCircularBranchFlowExist(CurrentTradePeriod,i_Pole))
            > UseBranchFlowMIPTolerance) = 1;

*Check branch flows for relevant mixed constraint to check if integer variables are needed
*RDN - Updated the condition to i_UseMixedConstraintRiskOffset which is specific to the original mixed constraint application
*         if (i_UseMixedConstraint,
          if (i_UseMixedConstraintRiskOffset,
*Reset the relevant parameters
             HVDCHalfPoleSouthFlow(CurrentTradePeriod) = 0;
             Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition) = 0;
             UseMixedConstraintMIP(CurrentTradePeriod) = 0;

*Check branch flows for relevant mixed constraint to check if integer variables are needed
             HVDCHalfPoleSouthFlow(CurrentTradePeriod) $ (sum(i_Type1MixedConstraintBranchCondition(i_Type1MixedConstraint,i_Branch) $ HVDCHalfPoles(CurrentTradePeriod,i_Branch), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch)) > MixedMIPTolerance) = 1;
*RDN - Change definition to only calculate violation if the constraint limit is non-zero
*          Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition)
             Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition) $ (Type1MixedConstraintLimit2(Type1MixedConstraintCondition) > 0)
                    = (Type1MixedConstraintLE.l(Type1MixedConstraintCondition) - Type1MixedConstraintLimit2(Type1MixedConstraintCondition)) $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = -1)
                    + (Type1MixedConstraintLimit2(Type1MixedConstraintCondition) - Type1MixedConstraintGE.l(Type1MixedConstraintCondition)) $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = 1)
                    + abs(Type1MixedConstraintEQ.l(Type1MixedConstraintCondition) - Type1MixedConstraintLimit2(Type1MixedConstraintCondition)) $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = 0);
*Integer constraints are needed if southward flow on half-poles AND constraint level exceeds the mixed constraint limit2 value
             UseMixedConstraintMIP(CurrentTradePeriod) $ (HVDCHalfPoleSouthFlow(CurrentTradePeriod) and sum(i_Type1MixedConstraint $ (Type1MixedConstraintLimit2Violation(CurrentTradePeriod,i_Type1MixedConstraint) > MixedMIPTolerance),1)) = 1;
          );

*If either circular branch flows or non-physical losses or discontinuous mixed constraint limits then
          if ((sum(CurrentTradePeriod, UseBranchFlowMIP(CurrentTradePeriod) + UseMixedConstraintMIP(CurrentTradePeriod)) >= 1),

*Reset some bounds
             MIXEDCONSTRAINTLIMIT2SELECT.up(CurrentTradePeriod,i_Type1MixedConstraint) = 1;
             ACBRANCHFLOWDIRECTED_INTEGER.up(CurrentTradePeriod,i_Branch,i_FlowDirection) = +inf;
             HVDCLINKFLOWDIRECTION_INTEGER.up(CurrentTradePeriod,i_FlowDirection) = +inf;
*RDN - Reset the bound of the integer variable
             HVDCPOLEFLOW_INTEGER.up(CurrentTradePeriod,i_Pole,i_FlowDirection) $ (not UseBranchFlowMIP(CurrentTradePeriod)) = +inf;

             LAMBDAINTEGER.up(CurrentTradePeriod,i_Branch,i_LossSegment) = +inf;

*Don't use integer variables for periods that do not need them
             MIXEDCONSTRAINTLIMIT2SELECT.fx(CurrentTradePeriod,i_Type1MixedConstraint) $ (not UseMixedConstraintMIP(CurrentTradePeriod)) = 0;
             ACBRANCHFLOWDIRECTED_INTEGER.fx(CurrentTradePeriod,i_Branch,i_FlowDirection) $ (not UseBranchFlowMIP(CurrentTradePeriod)) = 0;
             HVDCLINKFLOWDIRECTION_INTEGER.fx(CurrentTradePeriod,i_FlowDirection) $ (not UseBranchFlowMIP(CurrentTradePeriod)) = 0;
*RDN - Don't use the integer variable if not needed
             HVDCPOLEFLOW_INTEGER.fx(CurrentTradePeriod,i_Pole,i_FlowDirection) $ (not UseBranchFlowMIP(CurrentTradePeriod)) = 0;

             LAMBDAINTEGER.fx(CurrentTradePeriod,i_Branch,i_LossSegment) $ (not UseBranchFlowMIP(CurrentTradePeriod)) = 0;
*Fix the values of these integer variables that are not needed
             ACBRANCHFLOWDIRECTED_INTEGER.fx(Branch(CurrentTradePeriod,i_Branch),i_FlowDirection) $ (UseBranchFlowMIP(CurrentTradePeriod) and (HVDCLink(Branch) or (not LossBranch(Branch)) or OpenBranch(Branch))) = 0;
*RDN - 20130227 - Fix the AC branch flow integer variable for invalid branches
             ACBRANCHFLOWDIRECTED_INTEGER.fx(CurrentTradePeriod,i_Branch,i_FlowDirection) $ (UseBranchFlowMIP(CurrentTradePeriod) and (not Branch(CurrentTradePeriod,i_Branch))) = 0;
*Apply an upper bound on the integer weighting parameter based on its definition
             LAMBDAINTEGER.up(Branch(CurrentTradePeriod,i_Branch),i_LossSegment) $ UseBranchFlowMIP(CurrentTradePeriod) = 1;
*Ensure that the weighting factor value is zero for AC branches and for invalid loss segments on HVDC links
             LAMBDAINTEGER.fx(Branch(CurrentTradePeriod,i_Branch),i_LossSegment) $ (UseBranchFlowMIP(CurrentTradePeriod) and (ACBranch(Branch) or (not (ValidLossSegment(Branch,i_LossSegment) and HVDCLink(Branch))))) = 0;
*RDN - 20130227 - Fix the lambda integer variable to zero for invalid branches
             LAMBDAINTEGER.fx(CurrentTradePeriod,i_Branch,i_LossSegment) $ (UseBranchFlowMIP(CurrentTradePeriod) and (not Branch(CurrentTradePeriod,i_Branch))) = 0;
*Fix the value of some binary variables used in the mixed constraints that have no alternate limit
             MIXEDCONSTRAINTLIMIT2SELECT.fx(Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint)) $ (UseMixedConstraintMIP(CurrentTradePeriod) and (not Type1MixedConstraintCondition(Type1MixedConstraint))) = 0;

*Use the advanced basis here
             option bratio = 1;
*Set the optimality criteria for the MIP
             VSPD_MIP.optcr = MIPOptimality;
             VSPD_MIP.reslim = MIPTimeLimit;
             VSPD_MIP.iterlim = MIPIterationLimit;

*Solve the model
             solve VSPD_MIP using mip maximizing NETBENEFIT;

*Post a progress message to report for use by GUI.
          if(ModelSolved = 1,
             loop(CurrentTradePeriod(i_TradePeriod),
                  putclose runlog / 'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') FULL integer solve finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                                     'Violations: ' TOTALPENALTYCOST.l:<12:1 /
             );
          else
             loop(CurrentTradePeriod(i_TradePeriod),
                  putclose runlog / 'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') FULL integer solve finished at ', system.time '. Solve unsuccessful.' /
             );
          ) ;

*Set the model solve status
             ModelSolved = 1 $ (((VSPD_MIP.modelstat = 1) or (VSPD_MIP.modelstat = 8)) and (VSPD_MIP.solvestat = 1));

          );

*End of if-statement for the rechecking of the solution when ModelSolved = 1
         );

**At this point either :-
*1. LP is valid (LPValid = 1) - OK
*2. LP is invalid and MIP is valid ((1-LPValid)*ModelSolved = 1) - OK
*3. LP is invlalid and MIP is invalid (ModelSolved = 0) - Resolve LP

       if (ModelSolved = 0,
*Confirmation that Branch flow MIP was unsuccessful we are here
          BranchFlowMIPInvoked(CurrentTradePeriod) = 0;
*Set the bratio to 1 i.e. do not use advanced basis for LP
          option bratio = 1;
*Set resource limits
          VSPD.reslim = LPTimeLimit;
          VSPD.iterlim = LPIterationLimit;
          solve VSPD using lp maximizing NETBENEFIT;
*Set the model solve status
          LPModelSolved = 1 $ ((VSPD.modelstat = 1) and (VSPD.solvestat = 1));

*Post a progress message to report for use by GUI.
          if(LPModelSolved = 1,
             loop(CurrentTradePeriod(i_TradePeriod),
                  putclose runlog / 'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') integer resolve was unsuccessful. Reverting back to linear solve.' /
                                     'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') linear solve finished at ', system.time '. Solve successful. ' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                                     'Violations: ' TOTALPENALTYCOST.l:<12:1 /
                                     'Solution may have circulating flows and/or non-physical losses.' /
             );
          else
             loop(CurrentTradePeriod(i_TradePeriod),
                  putclose runlog / 'The case: %VSPDInputData% (' CurrentTradePeriod.tl ') integer solve was unsuccessful.  Reverting back to linear solve. Linear solve unsuccessful.' /
             );
          ) ;

*Reset the relevant parameters
          CircularBranchFlowExist(Branch) = 0;
          NorthHVDC(CurrentTradePeriod) = 0;
          SouthHVDC(CurrentTradePeriod) = 0;
*RDN - Reset the pole circular branch flow parameter
          PoleCircularBranchFlowExist(CurrentTradePeriod,i_Pole) = 0;

          ManualBranchSegmentMWFlow(i_TradePeriod,i_Branch,i_LossSegment) = 0;
          ManualLossCalculation(Branch) = 0;
          NonPhysicalLossExist(Branch)= 0;
          UseBranchFlowMIP(CurrentTradePeriod) = 0;

*Check if there are circulating branch flows on loss AC branches and HVDC links
          CircularBranchFlowExist(ACBranch) $ (LossBranch(ACBranch) and (abs(sum(i_FlowDirection, ACBRANCHFLOWDIRECTED.l(ACBranch,i_FlowDirection)) - abs(ACBRANCHFLOW.l(ACBranch))) > CircularBranchFlowTolerance)) = 1;
          NorthHVDC(CurrentTradePeriod) = sum((i_Island,i_Bus,i_Branch) $ ((ord(i_Island) = 2) and i_TradePeriodBusIsland(CurrentTradePeriod,i_Bus,i_Island) and HVDCLinkSendingBus(CurrentTradePeriod,i_Branch,i_Bus) and HVDCPoles(CurrentTradePeriod,i_Branch)), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch));
          SouthHVDC(CurrentTradePeriod) = sum((i_Island,i_Bus,i_Branch) $ ((ord(i_Island) = 1) and i_TradePeriodBusIsland(CurrentTradePeriod,i_Bus,i_Island) and HVDCLinkSendingBus(CurrentTradePeriod,i_Branch,i_Bus) and HVDCPoles(CurrentTradePeriod,i_Branch)), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch));
          CircularBranchFlowExist(CurrentTradePeriod,i_Branch) $ (HVDCPoles(CurrentTradePeriod,i_Branch) and LossBranch(CurrentTradePeriod,i_Branch) and (min(NorthHVDC(CurrentTradePeriod), SouthHVDC(CurrentTradePeriod)) > CircularBranchFlowTolerance)) = 1;

*RDN - Determine the circular branch flow flag on each HVDC pole
          TotalHVDCPoleFlow(CurrentTradePeriod,i_Pole) =
          sum(i_Branch $ HVDCPoleBranchMap(i_Pole,i_Branch), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch));

          MaxHVDCPoleFlow(CurrentTradePeriod,i_Pole) =
          smax(i_Branch $ HVDCPoleBranchMap(i_Pole,i_Branch), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch));

          PoleCircularBranchFlowExist(CurrentTradePeriod,i_Pole) $ ((abs(TotalHVDCPoleFlow(CurrentTradePeriod,i_Pole)-MaxHVDCPoleFlow(CurrentTradePeriod,i_Pole)) > CircularBranchFlowTolerance)) = 1;


*Check if there are non-physical losses on loss AC branches and HVDC links
          ManualBranchSegmentMWFlow(ValidLossSegment(ACBranch,i_LossSegment)) $ LossBranch(ACBranch) = min(max((abs(ACBRANCHFLOW.l(ACBranch))-(LossSegmentMW(ACBranch,i_LossSegment-1))$(ord(i_LossSegment) > 1)),0),ACBranchLossMW(ACBranch,i_LossSegment));
          ManualBranchSegmentMWFlow(ValidLossSegment(HVDCLink,i_LossSegment)) $ (LossBranch(HVDCLink) and (ord(i_LossSegment) <= HVDCLinkLossBlocks(HVDCLink))) = min(max((abs(HVDCLINKFLOW.l(HVDCLink))-(LossSegmentMW(HVDCLink,i_LossSegment-1))$(ord(i_LossSegment) > 1)),0),(LossSegmentMW(HVDCLink,i_LossSegment) - (LossSegmentMW(HVDCLink,i_LossSegment-1))$(ord(i_LossSegment) > 1)));
          ManualLossCalculation(Branch) $ LossBranch(Branch) = sum(i_LossSegment, LossSegmentFactor(Branch,i_LossSegment) * ManualBranchSegmentMWFlow(Branch,i_LossSegment));
          NonPhysicalLossExist(ACBranch) $ (LossBranch(ACBranch) and (abs(ManualLossCalculation(ACBranch) - sum(i_FlowDirection, ACBRANCHLOSSESDIRECTED.l(ACBranch,i_FlowDirection))) > NonPhysicalLossTolerance)) = 1;
          NonPhysicalLossExist(HVDCLink) $ (LossBranch(HVDCLink) and (abs(ManualLossCalculation(HVDCLink) - HVDCLINKLOSSES.l(HVDCLink)) > NonPhysicalLossTolerance)) = 1;

*Invoke the UseBranchFlowMIP flag if the number of circular branch flow and non-physical loss branches exceeds the specified tolerance
*RDN - Test - update logic to include roundpower logic
*          UseBranchFlowMIP(CurrentTradePeriod) $ ((sum(i_Branch $ (ACBranch(CurrentTradePeriod,i_Branch) and LossBranch(CurrentTradePeriod,i_Branch)), i_ResolveCircularBranchFlows*CircularBranchFlowExist(CurrentTradePeriod,i_Branch) + i_ResolveACNonPhysicalLosses*NonPhysicalLossExist(CurrentTradePeriod,i_Branch)) +
*            sum(i_Branch $ (LossBranch(CurrentTradePeriod,i_Branch) and HVDCLink(CurrentTradePeriod,i_Branch)), i_ResolveCircularBranchFlows*CircularBranchFlowExist(CurrentTradePeriod,i_Branch) + i_ResolveHVDCNonPhysicalLosses*NonPhysicalLossExist(CurrentTradePeriod,i_Branch)))
*            > UseBranchFlowMIPTolerance) = 1;
          UseBranchFlowMIP(CurrentTradePeriod) $ ((sum(i_Branch $ (ACBranch(CurrentTradePeriod,i_Branch) and LossBranch(CurrentTradePeriod,i_Branch)), i_ResolveCircularBranchFlows*CircularBranchFlowExist(CurrentTradePeriod,i_Branch) + i_ResolveACNonPhysicalLosses*NonPhysicalLossExist(CurrentTradePeriod,i_Branch)) +
            sum(i_Branch $ (LossBranch(CurrentTradePeriod,i_Branch) and HVDCLink(CurrentTradePeriod,i_Branch)), (1-AllowHVDCRoundpower(CurrentTradePeriod))*i_ResolveCircularBranchFlows*CircularBranchFlowExist(CurrentTradePeriod,i_Branch) + i_ResolveHVDCNonPhysicalLosses*NonPhysicalLossExist(CurrentTradePeriod,i_Branch))) +
            sum(i_Pole, i_ResolveCircularBranchFlows*PoleCircularBranchFlowExist(CurrentTradePeriod,i_Pole))
            > UseBranchFlowMIPTolerance) = 1;

*Check branch flows for relevant mixed constraint to check if integer variables are needed
*RDN - Updated the condition to i_UseMixedConstraintRiskOffset which is specific to the original mixed constraint application
*         if (i_UseMixedConstraint,
          if (i_UseMixedConstraintRiskOffset,
*Reset the relevant parameters
             HVDCHalfPoleSouthFlow(CurrentTradePeriod) = 0;
             Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition) = 0;
             UseMixedConstraintMIP(CurrentTradePeriod) = 0;

*Check branch flows for relevant mixed constraint to check if integer variables are needed
             HVDCHalfPoleSouthFlow(CurrentTradePeriod) $ (sum(i_Type1MixedConstraintBranchCondition(i_Type1MixedConstraint,i_Branch) $ HVDCHalfPoles(CurrentTradePeriod,i_Branch), HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch)) > MixedMIPTolerance) = 1;
*RDN - Change definition to only calculate violation if the constraint limit is non-zero
*            Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition)
             Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition) $ (Type1MixedConstraintLimit2(Type1MixedConstraintCondition) > 0)
                 = (Type1MixedConstraintLE.l(Type1MixedConstraintCondition) - Type1MixedConstraintLimit2(Type1MixedConstraintCondition)) $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = -1)
                 + (Type1MixedConstraintLimit2(Type1MixedConstraintCondition) - Type1MixedConstraintGE.l(Type1MixedConstraintCondition)) $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = 1)
                 + abs(Type1MixedConstraintEQ.l(Type1MixedConstraintCondition) - Type1MixedConstraintLimit2(Type1MixedConstraintCondition)) $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = 0);
*Integer constraints are needed if southward flow on half-poles AND constraint level exceeds the mixed constraint limit2 value
             UseMixedConstraintMIP(CurrentTradePeriod) $ (HVDCHalfPoleSouthFlow(CurrentTradePeriod) and sum(i_Type1MixedConstraint $ (Type1MixedConstraintLimit2Violation(CurrentTradePeriod,i_Type1MixedConstraint) > MixedMIPTolerance),1)) = 1;
          );

*End of if-statement when the MIP is invalid and the LP is resolved
       );

*End of if-statement when the LP is optimal
    );

*=======================================================================
*Check for disconnected nodes and adjust prices accordingly
*=======================================================================

*See Rule Change Proposal August 2008 - Disconnected nodes available at www.systemoperator.co.nz/reports-papers

    BusGeneration(Bus(CurrentTradePeriod,i_Bus)) = sum((i_Offer,i_Node) $ (OfferNode(CurrentTradePeriod,i_Offer,i_Node) and NodeBus(CurrentTradePeriod,i_Node,i_Bus)), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * GENERATION.l(CurrentTradePeriod,i_Offer));
    BusLoad(Bus(CurrentTradePeriod,i_Bus)) = sum(NodeBus(CurrentTradePeriod,i_Node,i_Bus), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * NodeDemand(CurrentTradePeriod,i_Node));
    BusPrice(Bus(CurrentTradePeriod,i_Bus)) $ (not (sum(NodeBus(HVDCNode(CurrentTradePeriod,i_Node),i_Bus), 1))) = ACNodeNetInjectionDefinition2.m(CurrentTradePeriod,i_Bus);
    BusPrice(Bus(CurrentTradePeriod,i_Bus)) $ (sum(NodeBus(HVDCNode(CurrentTradePeriod,i_Node),i_Bus), 1)) = DCNodeNetInjection.m(CurrentTradePeriod,i_Bus);

*Disconnected nodes are defined as follows:
*Pre-MSP: Have no generation or load, are disconnected from the network and has a price = CVP.
*Post-MSP: Indication to SPD whether a bus is dead or not.  Dead buses are not processed by the SPD solved and have their prices set by the
*post-process with the following rules:

*Scenario A/B/D: Price for buses in live electrical island determined by the solved
*Scenario C/F/G/H/I: Buses in the dead electrical island with:
*a) Null/zero load: Marked as disconnected with $0 price.
*b) Positive load: Price = CVP for deficit generation
*c) Negative load: Price = -CVP for surplus generation
*Scenario E: Price for bus in live electrical island with zero load and zero cleared generation needs to be adjusted since actually is disconnected.

*The Post-MSP implementation imply a mapping of a bus to an electrical island and an indication of whether this electrical island is live of dead.
*The correction of the prices is performed by SPD.

*RDN - 20130302 - i_TradePeriodNodeBusAllocationFactor update - Start-----------
*Update the disconnected nodes logic to use the time-stamped i_UseBusNetworkModel flag
*This allows disconnected nodes logic to work with both pre and post MSP data structure in the same gdx file

$ONTEXT
***CANNOT HAVE SOLVE THAT HAS PRE-MSP AND POST-MSP DATA STRUCTURE IN THE SAME RUN SINCE THE DISCONNECTED NODES LOGIC WILL NOT WORK
    if (((i_DisconnctedNodePriceCorrection = 1) and (sum(Bus, BusElectricalIsland(Bus)) = 0)),
       BusDisconnected(Bus(CurrentTradePeriod,i_Bus)) = 1 $ ((BusGeneration(Bus) = 0) and (BusLoad(Bus) = 0) and (not sum(i_Branch $ (BranchBusConnect(CurrentTradePeriod,i_Branch,i_Bus) and ClosedBranch(CurrentTradePeriod,i_Branch)),1)));
*Set price at identified disconnected buses to 0
       BusPrice(Bus) $ BusDisconnected(Bus) = 0;
    );

*Post-MSP: Indication to SPD whether a bus is dead or not.  Dead buses are not processed by the SPD solved and have their prices set by the
*post-process with the following rules:

*Scenario A/B/D: Price for buses in live electrical island determined by the solved
*Scenario C/F/G/H/I: Buses in the dead electrical island with:
*a) Null/zero load: Marked as disconnected with $0 price.
*b) Positive load: Price = CVP for deficit generation
*c) Negative load: Price = -CVP for surplus generation
*Scenario E: Price for bus in live electrical island with zero load and zero cleared generation needs to be adjusted since actually is disconnected.

*The Post-MSP implementation imply a mapping of a bus to an electrical island and an indication of whether this electrical island is live of dead.
*The correction of the prices is performed by SPD.

    if (((i_DisconnctedNodePriceCorrection = 1) and (sum(Bus, BusElectricalIsland(Bus)) > 0)),
*Scenario C/F/G/H/I:
       BusDisconnected(Bus) $ ((BusLoad(Bus) = 0) and (BusElectricalIsland(Bus) = 0)) = 1 ;
*Scenario E:
       BusDisconnected(Bus(CurrentTradePeriod,i_Bus)) $ ( (sum(i_Bus1 $ (BusElectricalIsland(CurrentTradePeriod,i_Bus1) = BusElectricalIsland(Bus)), BusLoad(CurrentTradePeriod,i_Bus1)) = 0)
                                 and (sum(i_Bus1 $ (BusElectricalIsland(CurrentTradePeriod,i_Bus1) = BusElectricalIsland(Bus)), BusGeneration(CurrentTradePeriod,i_Bus1)) = 0)
                                 and (BusElectricalIsland(Bus) > 0) ) = 1;
*Set price at buses at disconnected buses
       BusPrice(Bus) $ BusDisconnected(Bus) = 0;
*Set prices at dead buses with non-zero load
       BusPrice(Bus) $ ((BusLoad(Bus) > 0) and (BusElectricalIsland(Bus)= 0)) = DeficitBusGenerationPenalty;
       BusPrice(Bus) $ ((BusLoad(Bus) < 0) and (BusElectricalIsland(Bus)= 0)) = -SurplusBusGenerationPenalty;
    );
$OFFTEXT

    if ((i_DisconnctedNodePriceCorrection = 1),
*Pre-MSP case
       BusDisconnected(Bus(CurrentTradePeriod,i_Bus)) $ (i_UseBusNetworkModel(CurrentTradePeriod) = 0)
              = 1 $ ((BusGeneration(Bus) = 0) and (BusLoad(Bus) = 0) and (not sum(i_Branch $ (BranchBusConnect(CurrentTradePeriod,i_Branch,i_Bus) and ClosedBranch(CurrentTradePeriod,i_Branch)),1)));

*Post-MSP cases
*Scenario C/F/G/H/I:
       BusDisconnected(Bus(CurrentTradePeriod,i_Bus)) $ (
                                                         (i_UseBusNetworkModel(CurrentTradePeriod) = 1)
                                                         and (BusLoad(Bus) = 0)
                                                         and (BusElectricalIsland(Bus) = 0)
                                                        ) = 1;
*Scenario E:
       BusDisconnected(Bus(CurrentTradePeriod,i_Bus)) $ ((sum(i_Bus1 $ (BusElectricalIsland(CurrentTradePeriod,i_Bus1) = BusElectricalIsland(Bus)), BusLoad(CurrentTradePeriod,i_Bus1)) = 0)
                                                         and (sum(i_Bus1 $ (BusElectricalIsland(CurrentTradePeriod,i_Bus1) = BusElectricalIsland(Bus)), BusGeneration(CurrentTradePeriod,i_Bus1)) = 0)
                                                         and (BusElectricalIsland(Bus) > 0)
                                                         and (i_UseBusNetworkModel(CurrentTradePeriod) = 1)
                                                        ) = 1;
*Set prices at dead buses with non-zero load
       BusPrice(Bus(CurrentTradePeriod,i_Bus)) $ ((i_UseBusNetworkModel(CurrentTradePeriod) = 1)
                                                  and (BusLoad(Bus) > 0)
                                                  and (BusElectricalIsland(Bus)= 0)
                                                 ) = DeficitBusGenerationPenalty;

       BusPrice(Bus(CurrentTradePeriod,i_Bus)) $ ((i_UseBusNetworkModel(CurrentTradePeriod) = 1)
                                                  and (BusLoad(Bus) < 0)
                                                  and (BusElectricalIsland(Bus)= 0)
                                                 ) = -SurplusBusGenerationPenalty;

*Set price at identified disconnected buses to 0
       BusPrice(Bus) $ BusDisconnected(Bus) = 0;
    );
*RDN - 20130302 - i_TradePeriodNodeBusAllocationFactor update - End-------------

*=================================================
*Store results from the model solve
*=================================================

*Check if want reporting at a trade period level
*    if (%TradePeriodReports% = 1,
    if ((%TradePeriodReports% = 1) or (%DWMode% = -1),
     loop(i_DateTimeTradePeriodMap(i_DateTime,CurrentTradePeriod),
       o_DateTime(i_DateTime) = yes;
       o_Bus(i_DateTime,i_Bus) $ (Bus(CurrentTradePeriod,i_Bus) and (not DCBus(CurrentTradePeriod,i_Bus))) = yes;
       o_BusGeneration_TP(i_DateTime,i_Bus) $ Bus(CurrentTradePeriod,i_Bus) = BusGeneration(CurrentTradePeriod,i_Bus);
       o_BusLoad_TP(i_DateTime,i_Bus) $ Bus(CurrentTradePeriod,i_Bus) = BusLoad(CurrentTradePeriod,i_Bus);
       o_BusPrice_TP(i_DateTime,i_Bus) $ Bus(CurrentTradePeriod,i_Bus) = BusPrice(CurrentTradePeriod,i_Bus);
       o_BusRevenue_TP(i_DateTime,i_Bus) $ Bus(CurrentTradePeriod,i_Bus) = (i_TradingPeriodLength/60)*(BusGeneration(CurrentTradePeriod,i_Bus) * BusPrice(CurrentTradePeriod,i_Bus));
       o_BusCost_TP(i_DateTime,i_Bus) $ Bus(CurrentTradePeriod,i_Bus) = (i_TradingPeriodLength/60)*(BusLoad(CurrentTradePeriod,i_Bus) * BusPrice(CurrentTradePeriod,i_Bus));
       o_BusDeficit_TP(i_DateTime,i_Bus) $ Bus(CurrentTradePeriod,i_Bus) = DEFICITBUSGENERATION.l(CurrentTradePeriod,i_Bus);
       o_BusSurplus_TP(i_DateTime,i_Bus) $ Bus(CurrentTradePeriod,i_Bus) = SURPLUSBUSGENERATION.l(CurrentTradePeriod,i_Bus);
       o_Node(i_DateTime,i_Node) $ (Node(CurrentTradePeriod,i_Node) and (not HVDCNode(CurrentTradePeriod,i_Node))) = yes;
       o_NodeGeneration_TP(i_DateTime,i_Node) $ Node(CurrentTradePeriod,i_Node) = sum(i_Offer $ (OfferNode(CurrentTradePeriod,i_Offer,i_Node)), GENERATION.l(CurrentTradePeriod,i_Offer));
       o_NodeLoad_TP(i_DateTime,i_Node) $ Node(CurrentTradePeriod,i_Node) = NodeDemand(CurrentTradePeriod,i_Node);
       o_NodePrice_TP(i_DateTime,i_Node) $ Node(CurrentTradePeriod,i_Node) = sum(i_Bus $ (NodeBus(CurrentTradePeriod,i_Node,i_Bus)), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * BusPrice(CurrentTradePeriod,i_Bus));
       o_NodeRevenue_TP(i_DateTime,i_Node) $ Node(CurrentTradePeriod,i_Node) = (i_TradingPeriodLength/60)*(o_NodeGeneration_TP(i_DateTime,i_Node) * o_NodePrice_TP(i_DateTime,i_Node));
       o_NodeCost_TP(i_DateTime,i_Node) $ Node(CurrentTradePeriod,i_Node) = (i_TradingPeriodLength/60)*(o_NodeLoad_TP(i_DateTime,i_Node) * o_NodePrice_TP(i_DateTime,i_Node));

*RDN - Update the deficit and surplus reporting at the nodal level - Start------
       TotalBusAllocation(i_DateTime,i_Bus) $ Bus(CurrentTradePeriod,i_Bus) = sum(i_Node $ Node(CurrentTradePeriod,i_Node), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus));
       BusNodeAllocationFactor(i_DateTime,i_Bus,i_Node) $ (TotalBusAllocation(i_DateTime,i_Bus) > 0) = NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus)/TotalBusAllocation(i_DateTime,i_Bus);
*       o_NodeDeficit_TP(i_DateTime,i_Node) $ Node(CurrentTradePeriod,i_Node) = sum(i_Bus $ (NodeBus(CurrentTradePeriod,i_Node,i_Bus)), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * DEFICITBUSGENERATION.l(CurrentTradePeriod,i_Bus));
*       o_NodeSurplus_TP(i_DateTime,i_Node) $ Node(CurrentTradePeriod,i_Node) = sum(i_Bus $ (NodeBus(CurrentTradePeriod,i_Node,i_Bus)), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * SURPLUSBUSGENERATION.l(CurrentTradePeriod,i_Bus));
       o_NodeDeficit_TP(i_DateTime,i_Node) $ Node(CurrentTradePeriod,i_Node) = sum(i_Bus $ (NodeBus(CurrentTradePeriod,i_Node,i_Bus)), BusNodeAllocationFactor(i_DateTime,i_Bus,i_Node) * DEFICITBUSGENERATION.l(CurrentTradePeriod,i_Bus));
       o_NodeSurplus_TP(i_DateTime,i_Node) $ Node(CurrentTradePeriod,i_Node) = sum(i_Bus $ (NodeBus(CurrentTradePeriod,i_Node,i_Bus)), BusNodeAllocationFactor(i_DateTime,i_Bus,i_Node) * SURPLUSBUSGENERATION.l(CurrentTradePeriod,i_Bus));
*RDN - Update the deficit and surplus reporting at the nodal level - End------

       o_Branch(i_DateTime,i_Branch) $ Branch(CurrentTradePeriod,i_Branch) = yes;
       o_BranchFlow_TP(i_DateTime,i_Branch) $ ACBranch(CurrentTradePeriod,i_Branch) = ACBRANCHFLOW.l(CurrentTradePeriod,i_Branch);
       o_BranchFlow_TP(i_DateTime,i_Branch) $ HVDCLink(CurrentTradePeriod,i_Branch) = HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch);
       o_BranchDynamicLoss_TP(i_DateTime,i_Branch) $ (ACBranch(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)) = sum(i_FlowDirection,ACBRANCHLOSSESDIRECTED.l(CurrentTradePeriod,i_Branch,i_FlowDirection));
       o_BranchDynamicLoss_TP(i_DateTime,i_Branch) $ (HVDCLink(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)) = HVDCLINKLOSSES.l(CurrentTradePeriod,i_Branch);

       o_BranchTotalLoss_TP(i_DateTime,i_Branch) $ (ACBranch(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)) = sum(i_FlowDirection,ACBRANCHLOSSESDIRECTED.l(CurrentTradePeriod,i_Branch,i_FlowDirection)) + ACBranchFixedLoss(CurrentTradePeriod,i_Branch);
       o_BranchTotalLoss_TP(i_DateTime,i_Branch) $ (HVDCLink(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch) and (i_TradePeriodHVDCBranch(CurrentTradePeriod,i_Branch) = 1) and (o_BranchFlow_TP(i_DateTime,i_Branch) > 0)) = HVDCLINKLOSSES.l(CurrentTradePeriod,i_Branch) + sum(i_Branch1 $ (HVDCLink(CurrentTradePeriod,i_Branch1) and ClosedBranch(CurrentTradePeriod,i_Branch1) and (i_TradePeriodHVDCBranch(CurrentTradePeriod,i_Branch1) = 1)), HVDCLinkFixedLoss(CurrentTradePeriod,i_Branch1));
       o_BranchTotalLoss_TP(i_DateTime,i_Branch) $ (HVDCLink(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch) and (i_TradePeriodHVDCBranch(CurrentTradePeriod,i_Branch) = 2) and (o_BranchFlow_TP(i_DateTime,i_Branch) > 0)) = HVDCLINKLOSSES.l(CurrentTradePeriod,i_Branch) + sum(i_Branch1 $ (HVDCLink(CurrentTradePeriod,i_Branch1) and ClosedBranch(CurrentTradePeriod,i_Branch1) and (i_TradePeriodHVDCBranch(CurrentTradePeriod,i_Branch1) = 2)), HVDCLinkFixedLoss(CurrentTradePeriod,i_Branch1));

       o_BranchFixedLoss_TP(i_DateTime,i_Branch) $ (ACBranch(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)) = ACBranchFixedLoss(CurrentTradePeriod,i_Branch);
       o_BranchFixedLoss_TP(i_DateTime,i_Branch) $ (HVDCLink(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch)) = HVDCLinkFixedLoss(CurrentTradePeriod,i_Branch);

       o_BranchFromBus_TP(i_DateTime,i_Branch,i_FromBus) $ (Branch(CurrentTradePeriod,i_Branch) and sum(i_ToBus $ BranchBusDefn(CurrentTradePeriod,i_Branch,i_FromBus,i_ToBus),1)) = yes;
       o_BranchToBus_TP(i_DateTime,i_Branch,i_ToBus) $ (Branch(CurrentTradePeriod,i_Branch) and sum(i_FromBus $ BranchBusDefn(CurrentTradePeriod,i_Branch,i_FromBus,i_ToBus),1)) = yes;
       o_BranchFromBusPrice_TP(i_DateTime,i_Branch) $ Branch(CurrentTradePeriod,i_Branch) = sum((i_FromBus,i_ToBus) $ BranchBusDefn(CurrentTradePeriod,i_Branch,i_FromBus,i_ToBus), BusPrice(CurrentTradePeriod,i_FromBus));
       o_BranchToBusPrice_TP(i_DateTime,i_Branch) $ Branch(CurrentTradePeriod,i_Branch) = sum((i_FromBus,i_ToBus) $ BranchBusDefn(CurrentTradePeriod,i_Branch,i_FromBus,i_ToBus), BusPrice(CurrentTradePeriod,i_ToBus));
       o_BranchMarginalPrice_TP(i_DateTime,i_Branch) $ ACBranch(CurrentTradePeriod,i_Branch) = sum(i_FlowDirection, ACBranchMaximumFlow.m(CurrentTradePeriod,i_Branch,i_FlowDirection));
       o_BranchMarginalPrice_TP(i_DateTime,i_Branch) $ HVDCLink(CurrentTradePeriod,i_Branch) = HVDCLinkMaximumFlow.m(CurrentTradePeriod,i_Branch);
       o_BranchDynamicRentals_TP(i_DateTime,i_Branch) $ (Branch(CurrentTradePeriod,i_Branch) and (o_BranchFlow_TP(i_DateTime,i_Branch) >= 0)) = (i_TradingPeriodLength/60)*((o_BranchToBusPrice_TP(i_DateTime,i_Branch)*(o_BranchFlow_TP(i_DateTime,i_Branch)-o_BranchDynamicLoss_TP(i_DateTime,i_Branch))) - (o_BranchFromBusPrice_TP(i_DateTime,i_Branch)*o_BranchFlow_TP(i_DateTime,i_Branch)));
       o_BranchDynamicRentals_TP(i_DateTime,i_Branch) $ (Branch(CurrentTradePeriod,i_Branch) and (o_BranchFlow_TP(i_DateTime,i_Branch) < 0)) = (i_TradingPeriodLength/60)*((o_BranchFromBusPrice_TP(i_DateTime,i_Branch)*(abs(o_BranchFlow_TP(i_DateTime,i_Branch))-o_BranchDynamicLoss_TP(i_DateTime,i_Branch))) -(o_BranchToBusPrice_TP(i_DateTime,i_Branch)*abs(o_BranchFlow_TP(i_DateTime,i_Branch))));
       o_BranchTotalRentals_TP(i_DateTime,i_Branch) $ (Branch(CurrentTradePeriod,i_Branch) and (o_BranchFlow_TP(i_DateTime,i_Branch) >= 0)) = (i_TradingPeriodLength/60)*((o_BranchToBusPrice_TP(i_DateTime,i_Branch)*(o_BranchFlow_TP(i_DateTime,i_Branch)-o_BranchTotalLoss_TP(i_DateTime,i_Branch))) - (o_BranchFromBusPrice_TP(i_DateTime,i_Branch)*o_BranchFlow_TP(i_DateTime,i_Branch)));
       o_BranchTotalRentals_TP(i_DateTime,i_Branch) $ (Branch(CurrentTradePeriod,i_Branch) and (o_BranchFlow_TP(i_DateTime,i_Branch) < 0)) = (i_TradingPeriodLength/60)*((o_BranchFromBusPrice_TP(i_DateTime,i_Branch)*(abs(o_BranchFlow_TP(i_DateTime,i_Branch))-o_BranchTotalLoss_TP(i_DateTime,i_Branch))) -(o_BranchToBusPrice_TP(i_DateTime,i_Branch)*abs(o_BranchFlow_TP(i_DateTime,i_Branch))));
       o_BranchCapacity_TP(i_DateTime,i_Branch) $ Branch(CurrentTradePeriod,i_Branch) = i_TradePeriodBranchCapacity(CurrentTradePEriod,i_Branch);
       o_Offer(i_DateTime,i_Offer) $ Offer(CurrentTradePeriod,i_Offer) = yes;
       o_OfferEnergy_TP(i_DateTime,i_Offer) $ Offer(CurrentTradePeriod,i_Offer) = GENERATION.l(CurrentTradePeriod,i_Offer);
       o_OfferFIR_TP(i_DateTime,i_Offer) $ Offer(CurrentTradePeriod,i_Offer) = sum((i_ReserveClass,i_ReserveType) $ (ord(i_ReserveClass) = 1), RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType));
       o_OfferSIR_TP(i_DateTime,i_Offer) $ Offer(CurrentTradePeriod,i_Offer) = sum((i_ReserveClass,i_ReserveType) $ (ord(i_ReserveClass) = 2), RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType));
       o_BidEnergy_TP(i_DateTime,i_Bid) $ Bid(CurrentTradePeriod,i_Bid) = PURCHASE.l(CurrentTradePeriod,i_Bid);
       o_BidReserve_TP(i_DateTime,i_Bid,i_ReserveClass) $ Bid(CurrentTradePeriod,i_Bid) = PURCHASEILR.l(CurrentTradePeriod,i_Bid,i_ReserveClass);
       o_Island(i_DateTime,i_Island) = yes;
*RDN - Update FIR and SIR required based on the CE and ECE
*RDN - FIR and SIR required based on calculations of the island risk to overcome reporting issues of the risk setter under degenerate conditions when reserve price = 0 - See below
*       o_FIRReqd_TP(i_DateTime,i_Island) $ (not DiffCeECeCVP) = sum(i_ReserveClass $ (ord(i_ReserveClass) = 1), MAXISLANDRISK.l(CurrentTradePeriod,i_Island,i_ReserveClass));
*       o_SIRReqd_TP(i_DateTime,i_Island) $ (not DiffCeECeCVP) = sum(i_ReserveClass $ (ord(i_ReserveClass) = 2), MAXISLANDRISK.l(CurrentTradePeriod,i_Island,i_ReserveClass));
*       o_FIRReqd_TP(i_DateTime,i_Island) $ (DiffCeECeCVP) = sum(i_ReserveClass $ (ord(i_ReserveClass) = 1), MAXISLANDRISK.l(CurrentTradePeriod,i_Island,i_ReserveClass) + max(DEFICITRESERVE_CE.l(CurrentTradePeriod,i_Island,i_ReserveClass),DEFICITRESERVE_ECE.l(CurrentTradePeriod,i_Island,i_ReserveClass)));
*       o_SIRReqd_TP(i_DateTime,i_Island) $ (DiffCeECeCVP) = sum(i_ReserveClass $ (ord(i_ReserveClass) = 2), MAXISLANDRISK.l(CurrentTradePeriod,i_Island,i_ReserveClass) + max(DEFICITRESERVE_CE.l(CurrentTradePeriod,i_Island,i_ReserveClass),DEFICITRESERVE_ECE.l(CurrentTradePeriod,i_Island,i_ReserveClass)));

       o_FIRPrice_TP(i_DateTime,i_Island) = sum(i_ReserveClass $ (ord(i_ReserveClass) = 1), SupplyDemandReserveRequirement.m(CurrentTradePeriod,i_Island,i_ReserveClass));
       o_SIRPrice_TP(i_DateTime,i_Island) = sum(i_ReserveClass $ (ord(i_ReserveClass) = 2), SupplyDemandReserveRequirement.m(CurrentTradePeriod,i_Island,i_ReserveClass));
*RDN - Update violation reporting based on the CE and ECE
*       o_FIRViolation_TP(i_DateTime,i_Island) = sum(i_ReserveClass $ (ord(i_ReserveClass) = 1), DEFICITRESERVE.l(CurrentTradePeriod,i_Island,i_ReserveClass));
*       o_SIRViolation_TP(i_DateTime,i_Island) = sum(i_ReserveClass $ (ord(i_ReserveClass) = 2), DEFICITRESERVE.l(CurrentTradePeriod,i_Island,i_ReserveClass));
       o_FIRViolation_TP(i_DateTime,i_Island) $ (not DiffCeECeCVP) = sum(i_ReserveClass $ (ord(i_ReserveClass) = 1), DEFICITRESERVE.l(CurrentTradePeriod,i_Island,i_ReserveClass));
       o_SIRViolation_TP(i_DateTime,i_Island) $ (not DiffCeECeCVP) = sum(i_ReserveClass $ (ord(i_ReserveClass) = 2), DEFICITRESERVE.l(CurrentTradePeriod,i_Island,i_ReserveClass));
       o_FIRViolation_TP(i_DateTime,i_Island) $ (DiffCeECeCVP) = sum(i_ReserveClass $ (ord(i_ReserveClass) = 1), DEFICITRESERVE_CE.l(CurrentTradePeriod,i_Island,i_ReserveClass) + DEFICITRESERVE_ECE.l(CurrentTradePeriod,i_Island,i_ReserveClass));
       o_SIRViolation_TP(i_DateTime,i_Island) $ (DiffCeECeCVP) = sum(i_ReserveClass $ (ord(i_ReserveClass) = 2), DEFICITRESERVE_CE.l(CurrentTradePeriod,i_Island,i_ReserveClass) + DEFICITRESERVE_ECE.l(CurrentTradePeriod,i_Island,i_ReserveClass));

*Security constraint data
       o_BrConstraint_TP(i_DateTime,i_BranchConstraint) $ BranchConstraint(CurrentTradePeriod,i_BranchConstraint) = yes;
       o_BrConstraintSense_TP(i_DateTime,i_BranchConstraint) $ BranchConstraint(CurrentTradePeriod,i_BranchConstraint) = BranchConstraintSense(CurrentTradePeriod,i_BranchConstraint);
       o_BrConstraintLHS_TP(i_DateTime,i_BranchConstraint) $ BranchConstraint(CurrentTradePeriod,i_BranchConstraint) = BranchSecurityConstraintLE.l(CurrentTradePeriod,i_BranchConstraint) $ (BranchConstraintSense(CurrentTradePeriod,i_BranchConstraint) = -1)
                                                                                                                          + BranchSecurityConstraintGE.l(CurrentTradePeriod,i_BranchConstraint) $ (BranchConstraintSense(CurrentTradePeriod,i_BranchConstraint) = 1)
                                                                                                                          + BranchSecurityConstraintEQ.l(CurrentTradePeriod,i_BranchConstraint) $ (BranchConstraintSense(CurrentTradePeriod,i_BranchConstraint) = 0);
       o_BrConstraintRHS_TP(i_DateTime,i_BranchConstraint) $ BranchConstraint(CurrentTradePeriod,i_BranchConstraint) = BranchConstraintLimit(CurrentTradePeriod,i_BranchConstraint);
       o_BrConstraintPrice_TP(i_DateTime,i_BranchConstraint) $ BranchConstraint(CurrentTradePeriod,i_BranchConstraint) = BranchSecurityConstraintLE.m(CurrentTradePeriod,i_BranchConstraint) $ (BranchConstraintSense(CurrentTradePeriod,i_BranchConstraint) = -1)
                                                                                                                          + BranchSecurityConstraintGE.m(CurrentTradePeriod,i_BranchConstraint) $ (BranchConstraintSense(CurrentTradePeriod,i_BranchConstraint) = 1)
                                                                                                                          + BranchSecurityConstraintEQ.m(CurrentTradePeriod,i_BranchConstraint) $ (BranchConstraintSense(CurrentTradePeriod,i_BranchConstraint) = 0);
*MNode constraint data
       o_MNodeConstraint_TP(i_DateTime,i_MNodeConstraint) $ MNodeConstraint(CurrentTradePeriod,i_MNodeConstraint) = yes;
       o_MNodeConstraintSense_TP(i_DateTime,i_MNodeConstraint) $ MNodeConstraint(CurrentTradePeriod,i_MNodeConstraint) = MNodeConstraintSense(CurrentTradePeriod,i_MNodeConstraint);
       o_MNodeConstraintLHS_TP(i_DateTime,i_MNodeConstraint) $ MNodeConstraint(CurrentTradePeriod,i_MNodeConstraint) = MNodeSecurityConstraintLE.l(CurrentTradePeriod,i_MNodeConstraint) $ (MNodeConstraintSense(CurrentTradePeriod,i_MNodeConstraint) = -1)
                                                                                                                          + MNodeSecurityConstraintGE.l(CurrentTradePeriod,i_MNodeConstraint) $ (MNodeConstraintSense(CurrentTradePeriod,i_MNodeConstraint) = 1)
                                                                                                                          + MNodeSecurityConstraintEQ.l(CurrentTradePeriod,i_MNodeConstraint) $ (MNodeConstraintSense(CurrentTradePeriod,i_MNodeConstraint) = 0);
       o_MNodeConstraintRHS_TP(i_DateTime,i_MNodeConstraint) $ MNodeConstraint(CurrentTradePeriod,i_MNodeConstraint) = MNodeConstraintLimit(CurrentTradePeriod,i_MNodeConstraint);
       o_MNodeConstraintPrice_TP(i_DateTime,i_MNodeConstraint) $ MNodeConstraint(CurrentTradePeriod,i_MNodeConstraint) = MNodeSecurityConstraintLE.m(CurrentTradePeriod,i_MNodeConstraint) $ (MNodeConstraintSense(CurrentTradePeriod,i_MNodeConstraint) = -1)
                                                                                                                          + MNodeSecurityConstraintGE.m(CurrentTradePeriod,i_MNodeConstraint) $ (MNodeConstraintSense(CurrentTradePeriod,i_MNodeConstraint) = 1)
                                                                                                                          + MNodeSecurityConstraintEQ.m(CurrentTradePeriod,i_MNodeConstraint) $ (MNodeConstraintSense(CurrentTradePeriod,i_MNodeConstraint) = 0);

*Island results at a trade period level
      o_IslandGen_TP(i_DateTime,i_Island) = sum(i_Bus $ BusIsland(CurrentTradePeriod,i_Bus,i_Island), BusGeneration(CurrentTradePeriod,i_Bus));
      o_IslandLoad_TP(i_DateTime,i_Island) = sum(i_Bus $ BusIsland(CurrentTradePeriod,i_Bus,i_Island), BusLoad(CurrentTradePeriod,i_Bus));
      o_IslandEnergyRevenue_TP(i_DateTime,i_Island) = (i_TradingPeriodLength/60)*sum((i_Offer,i_Bus,i_Node) $ (OfferNode(CurrentTradePeriod,i_Offer,i_Node) and NodeBus(CurrentTradePeriod,i_Node,i_Bus) and BusIsland(CurrentTradePeriod,i_Bus,i_Island)), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * GENERATION.l(CurrentTradePeriod,i_Offer) * BusPrice(CurrentTradePeriod,i_Bus));
      o_IslandReserveRevenue_TP(i_DateTime,i_Island) = (i_TradingPeriodLength/60)*sum((i_Offer,i_Node,i_Bus,i_ReserveClass,i_ReserveType) $ (OfferNode(CurrentTradePeriod,i_Offer,i_Node) and NodeBus(CurrentTradePeriod,i_Node,i_Bus) and BusIsland(CurrentTradePeriod,i_Bus,i_Island)), SupplyDemandReserveRequirement.m(CurrentTradePeriod,i_Island,i_ReserveClass) * RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType));
      o_IslandLoadCost_TP(i_DateTime,i_Island) = (i_TradingPeriodLength/60)*sum((i_Bus,i_Node) $ (NodeBus(CurrentTradePeriod,i_Node,i_Bus) and (NodeDemand(CurrentTradePeriod,i_Node) >= 0) and BusIsland(CurrentTradePeriod,i_Bus,i_Island)), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * NodeDemand(CurrentTradePeriod,i_Node) * BusPrice(CurrentTradePeriod,i_Bus));
      o_IslandLoadRevenue_TP(i_DateTime,i_Island) = (i_TradingPeriodLength/60)*sum((i_Bus,i_Node) $ (NodeBus(CurrentTradePeriod,i_Node,i_Bus) and (NodeDemand(CurrentTradePeriod,i_Node) < 0) and BusIsland(CurrentTradePeriod,i_Bus,i_Island)), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * (-NodeDemand(CurrentTradePeriod,i_Node)) * BusPrice(CurrentTradePeriod,i_Bus));

      o_IslandBranchLoss_TP(i_DateTime,i_Island) = sum((i_Branch,i_FromBus,i_ToBus) $ (ACBranch(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch) and BranchBusDefn(CurrentTradePeriod,i_Branch,i_FromBus,i_ToBus) and BusIsland(CurrentTradePeriod,i_ToBus,i_Island)), o_BranchTotalLoss_TP(i_DateTime,i_Branch));
      o_HVDCFlow_TP(i_DateTime,i_Island) = sum((i_Branch,i_FromBus,i_ToBus) $ (HVDCPoles(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch) and BranchBusDefn(CurrentTradePeriod,i_Branch,i_FromBus,i_ToBus) and BusIsland(CurrentTradePeriod,i_FromBus,i_Island)), o_BranchFlow_TP(i_DateTime,i_Branch));

      o_HVDCHalfPoleLoss_TP(i_DateTime,i_Island) = sum((i_Branch,i_FromBus,i_ToBus) $ (HVDCHalfPoles(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch) and BranchBusDefn(CurrentTradePeriod,i_Branch,i_FromBus,i_ToBus) and BusIsland(CurrentTradePeriod,i_ToBus,i_Island) and BusIsland(CurrentTradePeriod,i_FromBus,i_Island)), o_BranchTotalLoss_TP(i_DateTime,i_Branch));
      o_HVDCPoleFixedLoss_TP(i_DateTime,i_Island) = sum((i_Branch,i_FromBus,i_ToBus) $ (HVDCPoles(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch) and BranchBusDefn(CurrentTradePeriod,i_Branch,i_FromBus,i_ToBus) and (BusIsland(CurrentTradePeriod,i_ToBus,i_Island) or BusIsland(CurrentTradePeriod,i_FromBus,i_Island))), 0.5 * o_BranchFixedLoss_TP(i_DateTime,i_Branch));
      o_HVDCLoss_TP(i_DateTime,i_Island) = o_HVDCHalfPoleLoss_TP(i_DateTime,i_Island) + o_HVDCPoleFixedLoss_TP(i_DateTime,i_Island) +
                                         sum((i_Branch,i_FromBus,i_ToBus) $ (HVDCLink(CurrentTradePeriod,i_Branch) and ClosedBranch(CurrentTradePeriod,i_Branch) and BranchBusDefn(CurrentTradePeriod,i_Branch,i_FromBus,i_ToBus) and BusIsland(CurrentTradePeriod,i_ToBus,i_Island) and (not (BusIsland(CurrentTradePeriod,i_FromBus,i_Island)))), o_BranchDynamicLoss_TP(i_DateTime,i_Branch));
      o_IslandRefPrice_TP(i_DateTime,i_Island) = sum(i_Node $ (ReferenceNode(CurrentTradePeriod,i_Node) and NodeIsland(CurrentTradePeriod,i_Node,i_Island)), o_NodePrice_TP(i_DateTime,i_Node));

*TN - Additional output for audit reporting
      o_ACBusAngle(i_DateTime,i_Bus) = ACNODEANGLE.l(CurrentTradePeriod,i_Bus);

      o_NonPhysicalLoss(i_DateTime,i_Branch) $ ACBranch(CurrentTradePeriod,i_Branch) = abs(ManualLossCalculation(CurrentTradePeriod,i_Branch) - sum(i_FlowDirection, ACBRANCHLOSSESDIRECTED.l(CurrentTradePeriod,i_Branch,i_FlowDirection)));
      o_NonPhysicalLoss(i_DateTime,i_Branch) $ HVDCLink(CurrentTradePeriod,i_Branch) = abs(ManualLossCalculation(CurrentTradePeriod,i_Branch) - HVDCLINKLOSSES.l(CurrentTradePeriod,i_Branch));

      o_LossSegmentBreakPoint(i_DateTime,i_Branch,i_LossSegment) $ ValidLossSegment(CurrentTradePeriod,i_Branch,i_LossSegment) = LossSegmentMW(CurrentTradePeriod,i_Branch,i_LossSegment);
      o_LossSegmentFactor(i_DateTime,i_Branch,i_LossSegment) $ ValidLossSegment(CurrentTradePeriod,i_Branch,i_LossSegment) = LossSegmentFactor(CurrentTradePeriod,i_Branch,i_LossSegment);

      o_BusIsland_TP(i_DateTime,i_Bus,i_Island) $ BusIsland(CurrentTradePeriod,i_Bus,i_Island) = yes;

      o_PLRO_FIR_TP(i_DateTime,i_Offer) $ Offer(CurrentTradePeriod,i_Offer) = sum[(i_ReserveClass,i_ReserveType) $ [(ord(i_ReserveClass) = 1) and (ord(i_ReserveType) = 1)], RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)];
      o_PLRO_SIR_TP(i_DateTime,i_Offer) $ Offer(CurrentTradePeriod,i_Offer) = sum[(i_ReserveClass,i_ReserveType) $ [(ord(i_ReserveClass) = 2) and (ord(i_ReserveType) = 1)], RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)];
      o_TWRO_FIR_TP(i_DateTime,i_Offer) $ Offer(CurrentTradePeriod,i_Offer) = sum[(i_ReserveClass,i_ReserveType) $ [(ord(i_ReserveClass) = 1) and (ord(i_ReserveType) = 2)], RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)];
      o_TWRO_SIR_TP(i_DateTime,i_Offer) $ Offer(CurrentTradePeriod,i_Offer) = sum[(i_ReserveClass,i_ReserveType) $ [(ord(i_ReserveClass) = 2) and (ord(i_ReserveType) = 2)], RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)];
      o_ILRO_FIR_TP(i_DateTime,i_Offer) $ Offer(CurrentTradePeriod,i_Offer) = sum[(i_ReserveClass,i_ReserveType) $ [(ord(i_ReserveClass) = 1) and (ord(i_ReserveType) = 3)], RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)];
      o_ILRO_SIR_TP(i_DateTime,i_Offer) $ Offer(CurrentTradePeriod,i_Offer) = sum[(i_ReserveClass,i_ReserveType) $ [(ord(i_ReserveClass) = 2) and (ord(i_ReserveType) = 3)], RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)];

      o_ILBus_FIR_TP(i_DateTime,i_Bus) = sum[i_Offer $ sameas(i_Offer,i_Bus), o_ILRO_FIR_TP(i_DateTime,i_Offer)];
      o_ILBus_SIR_TP(i_DateTime,i_Bus) = sum[i_Offer $ sameas(i_Offer,i_Bus), o_ILRO_SIR_TP(i_DateTime,i_Offer)];

      o_MarketNodeIsland_TP(i_DateTime,i_Offer,i_Island) $ sum[(i_Node,i_Bus) $ [BusIsland(CurrentTradePeriod,i_Bus,i_Island)
                                                                             and NodeBus(CurrentTradePeriod,i_Node,i_Bus)
                                                                             and OfferNode(CurrentTradePeriod,i_Offer,i_Node)
                                                                             and (o_NodeLoad_TP(i_DateTime,i_Node)  = 0)
                                                                                ],1] = yes;

      o_GenerationRiskSetter(i_DateTime,i_Island,i_Offer,i_ReserveClass,GenRisk) $  [not UsePrimSecGenRiskModel
                                                                                 and IslandRiskGenerator(CurrentTradePeriod,i_Island,i_Offer)
                                                                                    ] =
            IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) * [GENERATION.l(CurrentTradePeriod,i_Offer)
                                                                                            - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk)
                                                                                            + FKBand(CurrentTradePeriod,i_Offer)
                                                                                            + sum(i_ReserveType, RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
                                                                                             ];

      o_GenerationRiskSetter(i_DateTime,i_Island,i_Offer,i_ReserveClass,GenRisk) $ [UsePrimSecGenRiskModel
                                                                                and IslandRiskGenerator(CurrentTradePeriod,i_Island,i_Offer)
                                                                                and ( not (HasSecondaryOffer(CurrentTradePeriod,i_Offer) or HasPrimaryOffer(CurrentTradePeriod,i_Offer))                                                                                          )
                                                                                   ] =
            IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) * [GENERATION.l(CurrentTradePeriod,i_Offer)
                                                                                            - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk)
                                                                                            + FKBand(CurrentTradePeriod,i_Offer)
                                                                                            + sum(i_ReserveType, RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
                                                                                             ];

      o_GenerationRiskSetter(i_DateTime,i_Island,i_Offer,i_ReserveClass,GenRisk) $  [UsePrimSecGenRiskModel
                                                                                 and IslandRiskGenerator(CurrentTradePeriod,i_Island,i_Offer)
                                                                                 and HasSecondaryOffer(CurrentTradePeriod,i_Offer)
                                                                                    ] =
            IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk) * [ GENERATION.l(CurrentTradePeriod,i_Offer)
                                                                                              + sum[i_Offer1 $ PrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1), GENERATION.l(CurrentTradePeriod,i_Offer1)]
                                                                                              - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,GenRisk)
                                                                                              + FKBand(CurrentTradePeriod,i_Offer)
                                                                                              + sum[i_ReserveType, RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType)]
                                                                                              + sum[(i_Offer1,i_ReserveType) $ PrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1), RESERVE.l(CurrentTradePeriod,i_Offer1,i_ReserveClass,i_ReserveType)]
                                                                                              ];
      o_GenerationRiskSetterMax(i_DateTime,i_Island,i_Offer,i_ReserveClass) = SMax[GenRisk, o_GenerationRiskSetter(i_DateTime,i_Island,i_Offer,i_ReserveClass,GenRisk)];


      o_HVDCRiskSetter(i_DateTime,i_Island,i_ReserveClass,HVDCRisk) =
            IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCRisk) * [HVDCREC.l(CurrentTradePeriod,i_Island)
                                                                                             - RISKOFFSET.l(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCRisk)
                                                                                              ];

      o_MANURiskSetter(i_DateTime,i_Island,i_ReserveClass,ManualRisk) =
            IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,ManualRisk) * [IslandMinimumRisk(CurrentTradePeriod,i_Island,i_ReserveClass,ManualRisk)
                                                                                               - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,ManualRisk)
                                                                                                ];

      o_GenHVDCRiskSetter(i_DateTime,i_Island,i_Offer,i_ReserveClass,HVDCSecRisk) $ [ (not (UsePrimSecGenRiskModel)) and HVDCSecRiskEnabled(CurrentTradePeriod,i_Island,HVDCSecRisk)
                                                                                  and IslandRiskGenerator(CurrentTradePeriod,i_Island,i_Offer)
                                                                                    ] =
            IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) * [ GENERATION.l(CurrentTradePeriod,i_Offer)
                                                                                                 - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk)
                                                                                                 + HVDCREC.l(CurrentTradePeriod,i_Island)
                                                                                                 - HVDCSecRiskSubtractor(CurrentTradePeriod,i_Island)
                                                                                                 + FKBand(CurrentTradePeriod,i_Offer)
                                                                                                 + sum(i_ReserveType, RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
                                                                                                 ];


      o_MANUHVDCRiskSetter(i_DateTime,i_Island,i_ReserveClass,HVDCSecRisk)  $ HVDCSecRiskEnabled(CurrentTradePeriod,i_Island,HVDCSecRisk) =
            IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) * [ HVDCSecIslandMinimumRisk(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk)
                                                                                                 - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk)
                                                                                                 + HVDCREC.l(CurrentTradePeriod,i_Island)
                                                                                                 - HVDCSecRiskSubtractor(CurrentTradePeriod,i_Island)
                                                                                                 ];

*TN - Additional output for audit reporting - End

*RDN - Included reporting of risk - Start-----------------
      o_GenHVDCRiskSetter(i_DateTime,i_Island,i_Offer,i_ReserveClass,HVDCSecRisk) $ [ UsePrimSecGenRiskModel and HVDCSecRiskEnabled(CurrentTradePeriod,i_Island,HVDCSecRisk)
                                                                                  and IslandRiskGenerator(CurrentTradePeriod,i_Island,i_Offer)
                                                                                  and (not (HasSecondaryOffer(CurrentTradePeriod,i_Offer) or HasPrimaryOffer(CurrentTradePeriod,i_Offer)))
                                                                                    ] =
            IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) * [ GENERATION.l(CurrentTradePeriod,i_Offer)
                                                                                                 - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk)
                                                                                                 + HVDCREC.l(CurrentTradePeriod,i_Island)
                                                                                                 - HVDCSecRiskSubtractor(CurrentTradePeriod,i_Island)
                                                                                                 + FKBand(CurrentTradePeriod,i_Offer)
                                                                                                 + sum(i_ReserveType, RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
                                                                                                 ];


      o_GenHVDCRiskSetter(i_DateTime,i_Island,i_Offer,i_ReserveClass,HVDCSecRisk) $ [ UsePrimSecGenRiskModel and HVDCSecRiskEnabled(CurrentTradePeriod,i_Island,HVDCSecRisk)
                                                                                  and IslandRiskGenerator(CurrentTradePeriod,i_Island,i_Offer)
                                                                                  and HasSecondaryOffer(CurrentTradePeriod,i_Offer)
                                                                                    ] =
            IslandRiskAdjustmentFactor(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk) * [ GENERATION.l(CurrentTradePeriod,i_Offer)
                                                                                                 + sum[i_Offer1 $ PrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1), GENERATION.l(CurrentTradePeriod,i_Offer1)]
                                                                                                 - FreeReserve(CurrentTradePeriod,i_Island,i_ReserveClass,HVDCSecRisk)
                                                                                                 + HVDCREC.l(CurrentTradePeriod,i_Island)
                                                                                                 - HVDCSecRiskSubtractor(CurrentTradePeriod,i_Island)
                                                                                                 + FKBand(CurrentTradePeriod,i_Offer)
                                                                                                 + sum(i_ReserveType, RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType))
                                                                                                 + sum[(i_Offer1,i_ReserveType) $ PrimarySecondaryOffer(CurrentTradePeriod,i_Offer,i_Offer1), RESERVE.l(CurrentTradePeriod,i_Offer1,i_ReserveClass,i_ReserveType)]
                                                                                                 ];


      o_GenHVDCRiskSetterMax(i_DateTime,i_Island,i_Offer,i_ReserveClass) = SMax[HVDCSecRisk, o_GenHVDCRiskSetter(i_DateTime,i_Island,i_Offer,i_ReserveClass,HVDCSecRisk)];


      o_HVDCRiskSetterMax(i_DateTime,i_Island,i_ReserveClass) = Smax[HVDCRisk, o_HVDCRiskSetter(i_DateTime,i_Island,i_ReserveClass,HVDCRisk)];
      o_MANURiskSetterMax(i_DateTime,i_Island,i_ReserveClass) = Smax[ManualRisk, o_MANURiskSetter(i_DateTime,i_Island,i_ReserveClass,ManualRisk)];
      o_MANUHVDCRiskSetterMax(i_DateTime,i_Island,i_ReserveClass) = Smax[HVDCSecRisk, o_MANUHVDCRiskSetter(i_DateTime,i_Island,i_ReserveClass,HVDCSecRisk)];

*RDN - FIR and SIR required based on calculations of the island risk to overcome reporting issues of the risk setter under degenerate conditions when reserve price = 0 - See below
      o_FIRReqd_TP(i_DateTime,i_Island) = Max [ 0,
                                                Smax((i_ReserveClass,i_Offer) $ (ord(i_ReserveClass) = 1), o_GenerationRiskSetterMax(i_DateTime,i_Island,i_Offer,i_ReserveClass)),
                                                sum(i_ReserveClass $ (ord(i_ReserveClass) = 1), o_HVDCRiskSetterMax(i_DateTime,i_Island,i_ReserveClass)),
                                                sum(i_ReserveClass $ (ord(i_ReserveClass) = 1), o_MANURiskSetterMax(i_DateTime,i_Island,i_ReserveClass)),
                                                Smax((i_ReserveClass,i_Offer) $ (ord(i_ReserveClass) = 1), o_GenHVDCRiskSetterMax(i_DateTime,i_Island,i_Offer,i_ReserveClass)),
                                                sum(i_ReserveClass $ (ord(i_ReserveClass) = 1), o_MANUHVDCRiskSetterMax(i_DateTime,i_Island,i_ReserveClass))
                                              ];


      o_SIRReqd_TP(i_DateTime,i_Island) = Max [ 0,
                                                Smax((i_ReserveClass,i_Offer) $ (ord(i_ReserveClass) = 2), o_GenerationRiskSetterMax(i_DateTime,i_Island,i_Offer,i_ReserveClass)),
                                                sum(i_ReserveClass $ (ord(i_ReserveClass) = 2), o_HVDCRiskSetterMax(i_DateTime,i_Island,i_ReserveClass)),
                                                sum(i_ReserveClass $ (ord(i_ReserveClass) = 2), o_MANURiskSetterMax(i_DateTime,i_Island,i_ReserveClass)),
                                                Smax((i_ReserveClass,i_Offer) $ (ord(i_ReserveClass) = 2), o_GenHVDCRiskSetterMax(i_DateTime,i_Island,i_Offer,i_ReserveClass)),
                                                sum(i_ReserveClass $ (ord(i_ReserveClass) = 2), o_MANUHVDCRiskSetterMax(i_DateTime,i_Island,i_ReserveClass))
                                              ];


      o_OfferIsland_TP(i_DateTime,i_Offer,i_Island) $ sum[(i_Node,i_Bus) $ [BusIsland(CurrentTradePeriod,i_Bus,i_Island)
                                                                             and NodeBus(CurrentTradePeriod,i_Node,i_Bus)
                                                                             and OfferNode(CurrentTradePeriod,i_Offer,i_Node)
                                                                           ],1] = yes;

       o_FIRCleared_TP(i_DateTime,i_Island) = sum((i_Offer, i_ReserveClass,i_ReserveType) $ [(ord(i_ReserveClass) = 1) and Offer(CurrentTradePeriod,i_Offer) and o_OfferIsland_TP(i_DateTime,i_Offer,i_Island)], RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType));
       o_SIRCleared_TP(i_DateTime,i_Island) = sum((i_Offer, i_ReserveClass,i_ReserveType) $ [(ord(i_ReserveClass) = 2) and Offer(CurrentTradePeriod,i_Offer) and o_OfferIsland_TP(i_DateTime,i_Offer,i_Island)], RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType));

*RDN - Included reporting of risk - End-----------------


*Summary reporting
      o_SolveOK_TP(i_DateTime) = ModelSolved;

      o_SystemCost_TP(i_DateTime) = sum((i_Offer,i_TradeBlock) $ ValidGenerationOfferBlock(CurrentTradePeriod,i_Offer,i_TradeBlock), GENERATIONBLOCK.l(CurrentTradePeriod,i_Offer,i_TradeBlock) * GenerationOfferPrice(CurrentTradePeriod,i_Offer,i_TradeBlock))
                                  + sum((i_Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) $ ValidReserveOfferBlock(CurrentTradePeriod,i_Offer,i_TradeBlock,i_ReserveClass,i_ReserveType), RESERVEBLOCK.l(CurrentTradePeriod,i_Offer,i_TradeBlock,i_ReserveClass,i_ReserveType) * ReserveOfferPrice(CurrentTradePeriod,i_Offer,i_TradeBlock,i_ReserveClass,i_ReserveType))
                                  + sum((i_Bid,i_TradeBlock,i_ReserveClass) $ ValidPurchaseBidILRBlock(CurrentTradePeriod,i_Bid,i_TradeBlock,i_ReserveClass), PURCHASEILRBLOCK.l(CurrentTradePeriod,i_Bid,i_TradeBlock,i_ReserveClass))
*Penalty costs
                                  + sum(i_Bus $ Bus(CurrentTradePeriod,i_Bus), DeficitBusGenerationPenalty * DEFICITBUSGENERATION.l(CurrentTradePeriod,i_Bus))
                                  + sum(i_Bus $ Bus(CurrentTradePeriod,i_Bus), SurplusBusGenerationPenalty * SURPLUSBUSGENERATION.l(CurrentTradePeriod,i_Bus))
                                  + sum(i_Branch $ Branch(CurrentTradePeriod,i_Branch), SurplusBranchFlowPenalty * SURPLUSBRANCHFLOW.l(CurrentTradePeriod,i_Branch))
                                  + sum(i_Offer $ Offer(CurrentTradePeriod,i_Offer), (DeficitRampRatePenalty * DEFICITRAMPRATE.l(CurrentTradePeriod,i_Offer)) + (SurplusRampRatePenalty * SURPLUSRAMPRATE.l(CurrentTradePeriod,i_Offer)))
                                  + sum(i_ACNodeConstraint $ ACNodeConstraint(CurrentTradePeriod,i_ACNodeConstraint), DeficitACNodeConstraintPenalty * DEFICITACNODECONSTRAINT.l(CurrentTradePeriod,i_ACNodeConstraint))
                                  + sum(i_ACNodeConstraint $ ACNodeConstraint(CurrentTradePeriod,i_ACNodeConstraint), SurplusACNodeConstraintPenalty * SURPLUSACNODECONSTRAINT.l(CurrentTradePeriod,i_ACNodeConstraint))
                                  + sum(i_BranchConstraint $ BranchConstraint(CurrentTradePeriod,i_BranchConstraint), SurplusBranchGroupConstraintPenalty * SURPLUSBRANCHSECURITYCONSTRAINT.l(CurrentTradePeriod,i_BranchConstraint))
                                  + sum(i_BranchConstraint $ BranchConstraint(CurrentTradePeriod,i_BranchConstraint), DeficitBranchGroupConstraintPenalty * DEFICITBRANCHSECURITYCONSTRAINT.l(CurrentTradePeriod,i_BranchConstraint))
                                  + sum(i_MNodeConstraint $ MNodeConstraint(CurrentTradePeriod,i_MNodeConstraint), DeficitMnodeConstraintPenalty * DEFICITMNODECONSTRAINT.l(CurrentTradePeriod,i_MNodeConstraint))
                                  + sum(i_MNodeConstraint $ MNodeConstraint(CurrentTradePeriod,i_MNodeConstraint), SurplusMnodeConstraintPenalty * SURPLUSMNODECONSTRAINT.l(CurrentTradePeriod,i_MNodeConstraint))
                                  + sum(i_Type1MixedConstraint $ Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint), Type1DeficitMixedConstraintPenalty * DEFICITTYPE1MIXEDCONSTRAINT.l(CurrentTradePeriod,i_Type1MixedConstraint))
                                  + sum(i_Type1MixedConstraint $ Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint), Type1SurplusMixedConstraintPenalty * SURPLUSTYPE1MIXEDCONSTRAINT.l(CurrentTradePeriod,i_Type1MixedConstraint))
                                  + sum(i_GenericConstraint $ GenericConstraint(CurrentTradePeriod,i_GenericConstraint), DeficitGenericConstraintPenalty * DEFICITGENERICCONSTRAINT.l(CurrentTradePeriod,i_GenericConstraint))
                                  + sum(i_GenericConstraint $ GenericConstraint(CurrentTradePeriod,i_GenericConstraint), SurplusGenericConstraintPenalty * SURPLUSGENERICCONSTRAINT.l(CurrentTradePeriod,i_GenericConstraint))
                                  + sum((i_Island,i_ReserveClass) $ (not DiffCeECeCVP), DeficitReservePenalty(i_ReserveClass) * DEFICITRESERVE.l(CurrentTradePeriod,i_Island,i_ReserveClass))
                                  + sum((i_Island,i_ReserveClass) $ DiffCeECeCVP, DeficitReservePenalty_CE(i_ReserveClass) * DEFICITRESERVE_CE.l(CurrentTradePeriod,i_Island,i_ReserveClass))
                                  + sum((i_Island,i_ReserveClass) $ DiffCeECeCVP, DeficitReservePenalty_ECE(i_ReserveClass) * DEFICITRESERVE_ECE.l(CurrentTradePeriod,i_Island,i_ReserveClass))
                                  - sum((i_Bid,i_TradeBlock) $ ValidPurchaseBidBlock(CurrentTradePeriod,i_Bid,i_TradeBlock), PURCHASEBLOCK.l(CurrentTradePeriod,i_Bid,i_TradeBlock) * PurchaseBidPrice(CurrentTradePeriod,i_Bid,i_TradeBlock));

*Separete violation reporting at trade period level
      o_DefGenViolation_TP(i_DateTime) = sum(i_Bus $ Bus(CurrentTradePeriod,i_Bus),  DEFICITBUSGENERATION.l(CurrentTradePeriod,i_Bus));
      o_SurpGenViolation_TP(i_DateTime) = sum(i_Bus $ Bus(CurrentTradePeriod,i_Bus), SURPLUSBUSGENERATION.l(CurrentTradePeriod,i_Bus));
      o_SurpBranchFlow_TP(i_DateTime) = sum(i_Branch $ Branch(CurrentTradePeriod,i_Branch), SURPLUSBRANCHFLOW.l(CurrentTradePeriod,i_Branch));
      o_DefRampRate_TP(i_DateTime) = sum(i_Offer $ Offer(CurrentTradePeriod,i_Offer), DEFICITRAMPRATE.l(CurrentTradePeriod,i_Offer));
      o_SurpRampRate_TP(i_DateTime) = sum(i_Offer $ Offer(CurrentTradePeriod,i_Offer), SURPLUSRAMPRATE.l(CurrentTradePeriod,i_Offer));
      o_SurpBranchGroupConst_TP(i_DateTime) = sum(i_BranchConstraint $ BranchConstraint(CurrentTradePeriod,i_BranchConstraint), SURPLUSBRANCHSECURITYCONSTRAINT.l(CurrentTradePeriod,i_BranchConstraint));
      o_DefBranchGroupConst_TP(i_DateTime) = sum(i_BranchConstraint $ BranchConstraint(CurrentTradePeriod,i_BranchConstraint), DEFICITBRANCHSECURITYCONSTRAINT.l(CurrentTradePeriod,i_BranchConstraint));
      o_DefMNodeConst_TP(i_DateTime) = sum(i_MNodeConstraint $ MNodeConstraint(CurrentTradePeriod,i_MNodeConstraint), DEFICITMNODECONSTRAINT.l(CurrentTradePeriod,i_MNodeConstraint));
      o_SurpMNodeConst_TP(i_DateTime) = sum(i_MNodeConstraint $ MNodeConstraint(CurrentTradePeriod,i_MNodeConstraint), SURPLUSMNODECONSTRAINT.l(CurrentTradePeriod,i_MNodeConstraint));
      o_DefACNodeConst_TP(i_DateTime) = sum(i_ACNodeConstraint $ ACNodeConstraint(CurrentTradePeriod,i_ACNodeConstraint), DEFICITACNODECONSTRAINT.l(CurrentTradePeriod,i_ACNodeConstraint));
      o_SurpACNodeConst_TP(i_DateTime) = sum(i_ACNodeConstraint $ ACNodeConstraint(CurrentTradePeriod,i_ACNodeConstraint), SURPLUSACNODECONSTRAINT.l(CurrentTradePeriod,i_ACNodeConstraint));

      o_DefT1MixedConst_TP(i_DateTime) = sum(i_Type1MixedConstraint $ Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint), DEFICITTYPE1MIXEDCONSTRAINT.l(CurrentTradePeriod,i_Type1MixedConstraint));
      o_SurpT1MixedConst_TP(i_DateTime) = sum(i_Type1MixedConstraint $ Type1MixedConstraint(CurrentTradePeriod,i_Type1MixedConstraint), SURPLUSTYPE1MIXEDCONSTRAINT.l(CurrentTradePeriod,i_Type1MixedConstraint));

      o_DefGenericConst_TP(i_DateTime) = sum(i_GenericConstraint $ GenericConstraint(CurrentTradePeriod,i_GenericConstraint), DEFICITGENERICCONSTRAINT.l(CurrentTradePeriod,i_GenericConstraint));
      o_SurpGenericConst_TP(i_DateTime) =  sum(i_GenericConstraint $ GenericConstraint(CurrentTradePeriod,i_GenericConstraint), SURPLUSGENERICCONSTRAINT.l(CurrentTradePeriod,i_GenericConstraint));
      o_DefResv_TP(i_DateTime) =  sum((i_Island,i_ReserveClass) $ (not DiffCeECeCVP), DEFICITRESERVE.l(CurrentTradePeriod,i_Island,i_ReserveClass))
                          + sum((i_Island,i_ReserveClass) $ DiffCeECeCVP, DEFICITRESERVE_CE.l(CurrentTradePeriod,i_Island,i_ReserveClass) + DEFICITRESERVE_ECE.l(CurrentTradePeriod,i_Island,i_ReserveClass));

      o_TotalViolation_TP(i_DateTime) = o_DefGenViolation_TP(i_DateTime) + o_SurpGenViolation_TP(i_DateTime) + o_SurpBranchFlow_TP(i_DateTime) + o_DefRampRate_TP(i_DateTime) + o_SurpRampRate_TP(i_DateTime) + o_SurpBranchGroupConst_TP(i_DateTime)
                                      + o_DefBranchGroupConst_TP(i_DateTime) + o_DefMNodeConst_TP(i_DateTime) + o_SurpMNodeConst_TP(i_DateTime) + o_DefACNodeConst_TP(i_DateTime) + o_SurpACNodeConst_TP(i_DateTime) + o_DefT1MixedConst_TP(i_DateTime)
                                      + o_SurpT1MixedConst_TP(i_DateTime) + o_DefGenericConst_TP(i_DateTime) + o_SurpGenericConst_TP(i_DateTime) + o_DefResv_TP(i_DateTime);
     );
    );


*Summary reports
*System level
      o_NumTradePeriods = o_NumTradePeriods + sum(CurrentTradePeriod,1);
      o_SystemOFV = o_SystemOFV + NETBENEFIT.l;
      o_SystemGen = o_SystemGen + sum(Bus,BusGeneration(Bus));
      o_SystemLoad = o_SystemLoad + sum(Bus,BusLoad(Bus));
      o_SystemLoss = o_SystemLoss + sum((ClosedBranch,i_FlowDirection),ACBRANCHLOSSESDIRECTED.l(ClosedBranch,i_FlowDirection)) + sum(ClosedBranch, ACBranchFixedLoss(ClosedBranch))
        + sum(ClosedBranch, HVDCLINKLOSSES.l(ClosedBranch) + HVDCLinkFixedLoss(ClosedBranch));
      o_SystemViolation = o_SystemViolation + sum(Bus, DEFICITBUSGENERATION.l(Bus) + SURPLUSBUSGENERATION.l(Bus)) +
*RDN - Update reserve violation calculations based on different CE and ECE violations
*                          sum((CurrentTradePeriod,i_Island,i_ReserveClass), DEFICITRESERVE.l(CurrentTradePeriod,i_Island,i_ReserveClass)) +
                          (sum((CurrentTradePeriod,i_Island,i_ReserveClass), DEFICITRESERVE.l(CurrentTradePeriod,i_Island,i_ReserveClass)) $ (not DiffCeECeCVP)) +
                          (sum((CurrentTradePeriod,i_Island,i_ReserveClass), DEFICITRESERVE_CE.l(CurrentTradePeriod,i_Island,i_ReserveClass) + DEFICITRESERVE_ECE.l(CurrentTradePeriod,i_Island,i_ReserveClass)) $ (DiffCeECeCVP)) +
                          sum(BranchConstraint, DEFICITBRANCHSECURITYCONSTRAINT.l(BranchConstraint) + SURPLUSBRANCHSECURITYCONSTRAINT.l(BranchConstraint)) +
                          sum(Offer, DEFICITRAMPRATE.l(Offer) + SURPLUSRAMPRATE.l(Offer)) +
                          sum(ACNodeConstraint, DEFICITACNODECONSTRAINT.l(ACNodeConstraint) + SURPLUSACNODECONSTRAINT.l(ACNodeConstraint)) +
                          sum(Branch, DEFICITBRANCHFLOW.l(Branch) + SURPLUSBRANCHFLOW.l(Branch)) +
                          sum(MNodeConstraint, DEFICITMNODECONSTRAINT.l(MNodeConstraint) + SURPLUSMNODECONSTRAINT.l(MNodeConstraint)) +
                          sum((CurrentTradePeriod,i_Type1MixedConstraint), DEFICITTYPE1MIXEDCONSTRAINT.l(CurrentTradePeriod,i_Type1MixedConstraint) + SURPLUSTYPE1MIXEDCONSTRAINT.l(CurrentTradePeriod,i_Type1MixedConstraint)) +
                          sum(GenericConstraint, SURPLUSGENERICCONSTRAINT.l(GenericConstraint) + DEFICITGENERICCONSTRAINT.l(GenericConstraint));
      o_SystemFIR = o_SystemFIR + sum((Offer,i_ReserveClass,i_ReserveType) $ (ord(i_ReserveClass) = 1), RESERVE.l(Offer,i_ReserveClass,i_ReserveType)) + sum((Bid,i_ReserveClass) $ (ord(i_ReserveClass) = 1), PURCHASEILR.l(Bid,i_ReserveClass));
      o_SystemSIR = o_SystemSIR + sum((Offer,i_ReserveClass,i_ReserveType) $ (ord(i_ReserveClass) = 2), RESERVE.l(Offer,i_ReserveClass,i_ReserveType)) + sum((Bid,i_ReserveClass) $ (ord(i_ReserveClass) = 2), PURCHASEILR.l(Bid,i_ReserveClass));
      o_SystemEnergyRevenue = o_SystemEnergyRevenue + (i_TradingPeriodLength/60)*sum((CurrentTradePeriod,i_Offer,i_Bus,i_Node) $ (OfferNode(CurrentTradePeriod,i_Offer,i_Node) and NodeBus(CurrentTradePeriod,i_Node,i_Bus)), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * GENERATION.l(CurrentTradePeriod,i_Offer) * BusPrice(CurrentTradePeriod,i_Bus));
      o_SystemReserveRevenue = o_SystemReserveRevenue + (i_TradingPeriodLength/60)*sum((CurrentTradePeriod,i_Island,i_Offer,i_Node,i_Bus,i_ReserveClass,i_ReserveType) $ (OfferNode(CurrentTradePeriod,i_Offer,i_Node) and NodeBus(CurrentTradePeriod,i_Node,i_Bus) and i_TradePeriodBusIsland(CurrentTradePeriod,i_Bus,i_Island)), SupplyDemandReserveRequirement.m(CurrentTradePeriod,i_Island,i_ReserveClass) * RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType));
      o_SystemLoadCost = o_SystemLoadCost + (i_TradingPeriodLength/60)*sum((CurrentTradePeriod,i_Bus,i_Node) $ (NodeBus(CurrentTradePeriod,i_Node,i_Bus) and (NodeDemand(CurrentTradePeriod,i_Node) >= 0)), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * NodeDemand(CurrentTradePeriod,i_Node) * BusPrice(CurrentTradePeriod,i_Bus));
      o_SystemLoadRevenue = o_SystemLoadRevenue + (i_TradingPeriodLength/60)*sum((CurrentTradePeriod,i_Bus,i_Node) $ (NodeBus(CurrentTradePeriod,i_Node,i_Bus) and (NodeDemand(CurrentTradePeriod,i_Node) < 0)), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * (-NodeDemand(CurrentTradePeriod,i_Node)) * BusPrice(CurrentTradePeriod,i_Bus));
      o_SystemACRentals = o_SystemACRentals + sum((CurrentTradePeriod,i_DateTime,i_Branch) $ (i_DateTimeTradePeriodMap(i_DateTime,CurrentTradePeriod) and ACBranch(CurrentTradePeriod,i_Branch)), o_BranchTotalRentals_TP(i_DateTime,i_Branch));
      o_SystemDCRentals = o_SystemDCRentals + sum((CurrentTradePeriod,i_DateTime,i_Branch) $ (i_DateTimeTradePeriodMap(i_DateTime,CurrentTradePeriod) and HVDCLink(CurrentTradePeriod,i_Branch)), o_BranchTotalRentals_TP(i_DateTime,i_Branch));

*Offer level
*This does not include revenue from wind generators for final pricing because the wind generation is netted off against load
*at the particular bus for the final pricing solves
      o_OfferTrader(i_Offer,i_Trader) $ sum(CurrentTradePeriod $ i_TradePeriodOfferTrader(CurrentTradePeriod,i_Offer,i_Trader),1) = yes;
      o_OfferGen(i_Offer) = o_OfferGen(i_Offer) + (i_TradingPeriodLength/60)*sum(CurrentTradePeriod, GENERATION.l(CurrentTradePeriod,i_Offer));
      o_OfferFIR(i_Offer) = o_OfferFIR(i_Offer) + (i_TradingPeriodLength/60)*sum((CurrentTradePeriod,i_ReserveClass,i_ReserveType) $ (ord(i_ReserveClass) = 1), RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType));
      o_OfferSIR(i_Offer) = o_OfferSIR(i_Offer) + (i_TradingPeriodLength/60)*sum((CurrentTradePeriod,i_ReserveClass,i_ReserveType) $ (ord(i_ReserveClass) = 2), RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType));
      o_OfferGenRevenue(i_Offer) = o_OfferGenRevenue(i_Offer)
        + (i_TradingPeriodLength/60)*sum((CurrentTradePeriod,i_Bus,i_Node) $ (OfferNode(CurrentTradePeriod,i_Offer,i_Node) and NodeBus(CurrentTradePeriod,i_Node,i_Bus)), NodeBusAllocationFactor(CurrentTradePeriod,i_Node,i_Bus) * GENERATION.l(CurrentTradePeriod,i_Offer) * BusPrice(CurrentTradePeriod,i_Bus));
      o_OfferFIRRevenue(i_Offer) = o_OfferFIRRevenue(i_Offer)
        + (i_TradingPeriodLength/60)*sum((CurrentTradePeriod,i_Island,i_Node,i_Bus,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 1) and OfferNode(CurrentTradePeriod,i_Offer,i_Node) and NodeBus(CurrentTradePeriod,i_Node,i_Bus) and i_TradePeriodBusIsland(CurrentTradePeriod,i_Bus,i_Island)), SupplyDemandReserveRequirement.m(CurrentTradePeriod,i_Island,i_ReserveClass) * RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType));
      o_OfferSIRRevenue(i_Offer) = o_OfferSIRRevenue(i_Offer)
        + (i_TradingPeriodLength/60)*sum((CurrentTradePeriod,i_Island,i_Node,i_Bus,i_ReserveClass,i_ReserveType) $ ((ord(i_ReserveClass) = 2) and OfferNode(CurrentTradePeriod,i_Offer,i_Node) and NodeBus(CurrentTradePeriod,i_Node,i_Bus) and i_TradePeriodBusIsland(CurrentTradePeriod,i_Bus,i_Island)), SupplyDemandReserveRequirement.m(CurrentTradePeriod,i_Island,i_ReserveClass) * RESERVE.l(CurrentTradePeriod,i_Offer,i_ReserveClass,i_ReserveType));

*End of if statement for the resolve skipped
  );

*End of if statement to determine which periods to solve
 );

 if (SkipResolve,
*Set to sequential solve if the simultaneous solve failed and reset iteration counter
   i_SequentialSolve = 1;
   IterationCount = 0;
*Reset some of the reporting parameters if reverting to a sequential solve after simultaneous solve fails
   o_NumTradePeriods = 0;
   o_SystemOFV = 0;
   o_SystemGen = 0;
   o_SystemLoad = 0;
   o_SystemLoss = 0;
   o_SystemViolation = 0;
   o_SystemFIR = 0;
   o_SystemSIR = 0;
   o_SystemEnergyRevenue = 0;
   o_SystemReserveRevenue = 0;
   o_SystemLoadCost = 0;
   o_SystemLoadRevenue = 0;
   o_SystemACRentals = 0;
   o_SystemDCRentals = 0;
   o_OfferGen(i_Offer) = 0;
   o_OfferFIR(i_Offer) = 0;
   o_OfferSIR(i_Offer) = 0;
   o_OfferGenRevenue(i_Offer) = 0;
   o_OfferFIRRevenue(i_Offer) = 0;
   o_OfferSIRRevenue(i_Offer) = 0;
 );

*End of main for statement
);

*=============================
*Results reporting
*=============================
*Report the results from the solves

*Write out summary report
*System level
o_FromDateTime(i_DateTime) $ (ord(i_DateTime) = 1) = yes;
*System surplus needs to be calculated outside the main loop
o_SystemSurplus = o_SystemLoadCost - o_SystemLoadRevenue - o_SystemEnergyRevenue;

execute_unload '%OutputPath%%runName%\RunNum%VSPDRunNum%_SystemOutput.gdx', o_FromDateTime, o_NumTradePeriods, o_SystemOFV, o_SystemGen, o_SystemLoad
                                                               o_SystemLoss, o_SystemViolation, o_SystemFIR, o_SystemSIR, o_SystemEnergyRevenue
                                                               o_SystemLoadCost, o_SystemLoadRevenue, o_SystemSurplus;
*Offer level
execute_unload '%OutputPath%%runName%\RunNum%VSPDRunNum%_OfferOutput.gdx', i_Offer, i_Trader, o_OfferTrader, o_OfferGen, o_OfferFIR, o_OfferSIR;

*Trader level
*Currently this does not include revenue from wind generators since wind generation in FP is represented as negative load
o_Trader(i_Trader) = yes;
o_TraderGen(i_Trader) = sum(i_Offer $ o_OfferTrader(i_Offer,i_Trader), o_OfferGen(i_Offer));
o_TraderFIR(i_Trader) = sum(i_Offer $ o_OfferTrader(i_Offer,i_Trader), o_OfferFIR(i_Offer));
o_TraderSIR(i_Trader) = sum(i_Offer $ o_OfferTrader(i_Offer,i_Trader), o_OfferSIR(i_Offer));
o_TraderGenRevenue(i_Trader) = sum(i_Offer $ o_OfferTrader(i_Offer,i_Trader), o_OfferGenRevenue(i_Offer));
o_TraderFIRRevenue(i_Trader) = sum(i_Offer $ o_OfferTrader(i_Offer,i_Trader), o_OfferFIRRevenue(i_Offer));
o_TraderSIRRevenue(i_Trader) = sum(i_Offer $ o_OfferTrader(i_Offer,i_Trader), o_OfferSIRRevenue(i_Offer));

execute_unload '%OutputPath%%runName%\RunNum%VSPDRunNum%_TraderOutput.gdx', o_Trader, o_TraderGen, o_TraderFIR, o_TraderSIR;

*Write out detailed reports if requested
if (%TradePeriodReports% = 1,

   execute_unload '%OutputPath%%runName%\RunNum%VSPDRunNum%_SummaryOutput_TP.gdx', o_DateTime, o_SolveOK_TP, o_SystemCost_TP, o_DefGenViolation_TP, o_SurpGenViolation_TP, o_SurpBranchFlow_TP
                                                                                   o_DefRampRate_TP, o_SurpRampRate_TP, o_SurpBranchGroupConst_TP, o_DefBranchGroupConst_TP, o_DefMNodeConst_TP
                                                                                   o_SurpMNodeConst_TP, o_DefACNodeConst_TP, o_SurpACNodeConst_TP, o_DefT1MixedConst_TP, o_SurpT1MixedConst_TP
                                                                                   o_DefGenericConst_TP, o_SurpGenericConst_TP, o_DefResv_TP, o_TotalViolation_TP;

   execute_unload '%OutputPath%%runName%\RunNum%VSPDRunNum%_IslandOutput_TP.gdx', o_IslandGen_TP, o_IslandLoad_TP, o_IslandEnergyRevenue_TP
                                                                               o_IslandLoadCost_TP, o_IslandLoadRevenue_TP
                                                                               o_IslandBranchLoss_TP, o_HVDCFlow_TP, o_HVDCLoss_TP, o_IslandRefPrice_TP;

   execute_unload '%OutputPath%%runName%\RunNum%VSPDRunNum%_BusOutput_TP.gdx', o_Bus, o_BusGeneration_TP, o_BusLoad_TP, o_BusPrice_TP, o_BusRevenue_TP, o_BusCost_TP, o_BusDeficit_TP, o_BusSurplus_TP;

   execute_unload '%OutputPath%%runName%\RunNum%VSPDRunNum%_BranchOutput_TP.gdx', o_Branch, o_BranchFromBus_TP, o_BranchToBus_TP, o_BranchFlow_TP, o_BranchDynamicLoss_TP
                                                                      o_BranchFixedLoss_TP, o_BranchFromBusPrice_TP, o_BranchToBusPrice_TP
                                                                      o_BranchMarginalPrice_TP, o_BranchTotalRentals_TP, o_BranchCapacity_TP;

   execute_unload '%OutputPath%%runName%\RunNum%VSPDRunNum%_NodeOutput_TP.gdx', o_Node, o_NodeGeneration_TP, o_NodeLoad_TP, o_NodePrice_TP, o_NodeRevenue_TP, o_NodeCost_TP, o_NodeDeficit_TP, o_NodeSurplus_TP;

   execute_unload '%OutputPath%%runName%\RunNum%VSPDRunNum%_OfferOutput_TP.gdx', o_Offer, o_OfferEnergy_TP, o_OfferFIR_TP, o_OfferSIR_TP;

   execute_unload '%OutputPath%%runName%\RunNum%VSPDRunNum%_ReserveOutput_TP.gdx', o_Island, o_FIRReqd_TP, o_SIRReqd_TP, o_FIRPrice_TP, o_SIRPrice_TP, o_FIRViolation_TP, o_SIRViolation_TP;

   execute_unload '%OutputPath%%runName%\RunNum%VSPDRunNum%_BrConstraintOutput_TP.gdx', o_BrConstraint_TP, o_BrConstraintSense_TP, o_BrConstraintLHS_TP, o_BrConstraintRHS_TP, o_BrConstraintPrice_TP;

   execute_unload '%OutputPath%%runName%\RunNum%VSPDRunNum%_MNodeConstraintOutput_TP.gdx', o_MNodeConstraint_TP, o_MNodeConstraintSense_TP, o_MNodeConstraintLHS_TP, o_MNodeConstraintRHS_TP, o_MNodeConstraintPrice_TP;

*TN - Additional output for audit reporting
   if (%DWMode%=-1,
      execute_unload '%OutputPath%%runName%\RunNum%VSPDRunNum%_AuditOutput_TP.gdx', o_ACBusAngle, o_LossSegmentBreakPoint, o_LossSegmentFactor
                                                                                    o_NonPhysicalLoss, o_BusIsland_TP, o_MarketNodeIsland_TP
                                                                                    o_ILRO_FIR_TP, o_ILRO_SIR_TP, o_ILBus_FIR_TP, o_ILBus_SIR_TP
                                                                                    o_PLRO_FIR_TP, o_PLRO_SIR_TP, o_TWRO_FIR_TP, o_TWRO_SIR_TP
                                                                                    o_GenerationRiskSetter, o_GenHVDCRiskSetter, o_HVDCRiskSetter
                                                                                    o_MANURiskSetter, o_MANUHVDCRiskSetter, o_FIRCleared_TP, o_SIRCleared_TP;
   );
*TN - Additional output for audit reporting - End

);

*Post a progress message to report for use by GUI.
putclose runlog / 'The case: %VSPDInputData% is complete. (', system.time, ').' //// ;

*Go to the next input file
$label NextInput
*Post a progress message to report for use by GUI.
$if not exist "%InputPath%%VSPDInputData%.gdx" putclose runlog / 'The file %ProgramPath%Input\%VSPDInputData%.gdx could not be found (', system.time, ').' // ;


