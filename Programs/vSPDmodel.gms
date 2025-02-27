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
  riskC(*)            'Different risks that could set the reserve requirements' / genRisk, genRiskECE, DCCE, DCECE, manual, manualECE, HVDCsecRisk, HVDCsecRiskECE /
  resT(*)             'Definition of reserve types (PLSR, TWDR, ILR)'           / PLRO, TWRO, ILRO /

* Risk/Reserve subset
  GenRisk(riskC)      'Subset containing generator risks'                       / genRisk, genRiskECE /
  ManualRisk(riskC)   'Subset containting manual risks'                         / manual, manualECE /
  HVDCrisk(riskC)     'Subset containing DCCE and DCECE risks'                  / DCCE, DCECE /
  HVDCSecRisk(riskC)  'Subset containing DCCE and DCECE secondary risk'         / HVDCsecRisk, HVDCsecRiskECE /

  PLRO(resT)          'PLSR reserve type'                                       / PLRO /
  TWRO(resT)          'TWDR reserve type'                                       / TWRO /
  ILRO(resT)          'ILR reserve type'                                        / ILRO /

* Definition of CE and ECE events to support different CE and ECE CVPs
  ContingentEvents(riskC)          'Subset of Risk Classes containing contigent event risks'           / genRisk, DCCE, manual, HVDCsecRisk /
  ExtendedContingentEvent(riskC)   'Subset of Risk Classes containing extended contigent event risk'   / genRiskECE, DCECE, manualECE, HVDCsecRiskECE /

  casePar(*)          'Different information about a case and datetime' /studyMode, intervalLength/

  dtPar(*)            'The various parameters applied for datetime'     / usegeninitialMW, enrgShortfallTransfer, priceTransfer, replaceSurplusPrice, igIncreaseLimitRTD, useActualLoad, dontScaleNegLoad, maxSolveLoop, shortfallRemovalMargin, enrgScarcity, resrvScarcity, badPriceFactor, CommRiskDoCheckResOffers, CommRiskDoRiskAdjustment /

  islPar(*)           'The various parameters applied for each island'  / HVDCsecRisk, HVDCsecRiskECE, HVDCSecSubtractor, sharedNFRLoadOffset, RMTlimitFIR, RMTlimitSIR, MWIPS, PSD, Losses, SPDLoadCalcLosses/

  bidofrCmpnt(*)      'Components of the bid and offer'                 / limitMW, price, plsrPct, factor /

  offerPar(*)         'The various parameters required for each offer'  / solvedInitialMW, initialMW, rampUpRate, rampDnRate, resrvGenMax, isIG, FKbandMW, isPriceResponse, potentialMW, riskGenerator, dispatchable, maxFactorFIR, maxFactorSIR, ACSecondaryCERiskMW, ACSecondaryECERiskMW, isCommissioning, isPartStation /

  bidPar(*)           'The various parameters required for each offer'  / dispatchable, discrete, difference /

  nodePar(*)          'The various parameters applied for each  node'   / referenceNode, demand, initialLoad, conformingFactor, nonConformingFactor, loadIsOverride, loadIsBad, loadIsNCL, maxLoad, instructedLoadShed, instructedShedActive, dispatchedLoad, dispatchedGeneration /

  brPar(*)            'Branch parameter specified'                      / forwardCap, backwardCap, resistance, susceptance, fixedLosses, numLossTranches, HVDCbranch, isOpen /

  resPar(*)           'Parameters applied to reserve class'             / sharingFIR, sharingSIR, roundPwrFIR, roundPwrSIR, roundPwr2Mono, biPole2Mono, monoPoleMin, MRCE, MRECE, lossScalingFactorHVDC, sharedNFRfactor,forwardHVDCcontrolBand, backwardHVDCcontrolBand /

  riskPar(*)          'Different risk parameters'                       / freeReserve, adjustFactor, HVDCRampUp, minRisk, sharingEffectiveFactor /

  CstrRHS(*)          'Constraint RHS definition'                       / cnstrSense, cnstrLimit, rampingCnstr /

  z(*)                'RP: round power, NR: no reverse, RZ: reverse'    /RP, NR, RZ/

  pole(*)             'HVDC poles'                                      / pole1, pole2 /

  testcases(*)        'Test Cases for RTP 4'                            /'MSS_21012023030850151_0X','MSS_21302023030830146_0X','MSS_21322023030800133_0X','MSS_61012023030935374_0X'/
  ;

* Primary sets that are defined by /loaded from gdx inputs
Sets
  cn(*)               'Case name used to create the GDX file'
  ca(*)               'Case ID associated with data'
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
Alias (dt,dt1,dt2),       (tp,tp1,tp2),     (isl,isl1,isl2),  (b,b1,frB,toB),      (n,n1,n2),          (o,o1,o2),        (bd,bd2,bd1)
      (br,br1),           (fd,fd1,rd,rd1),  (z,z1,rrz,rrz1),  (rg,rg1),            (blk,blk1,blk2),    (los,los1,bp,bp1,rsbp,rsbp1)
  ;

* Dynamic sets that are loaded from GDX
Sets
* Case/period sets
  caseDefn(ca,cn<,rundt<)               'Mapping caseid - casename - rundatetime set'
  case2dt2tp(ca,dt,tp)                  'Mapping caseid - datetime - tradePeriod set'

* Node/bus sets
  node2node(ca,dt,n,n1)                 'Node to node mapping used for price and energy shortfall transfer'
  busIsland(ca,dt,b,isl)                'Bus island mapping for the different trade periods'
  nodeBus(ca,dt,n,b)                    'Node bus mapping for the different trading periods'

* Branch sets
  branchDefn(ca,dt,br<,frB,toB)         'Branch definition for the different trading periods'
  nodeoutagebranch(ca,dt,n,br)          'Mappinging of branch and node where branch outage may affect the capacity to supply to the node'

* Offer sets
  offerNode(ca,dt,o<,n)                 'Offers and the corresponding offer node for the different trading periods'
  offerTrader(ca,dt,o,trdr<)            'Offers and the corresponding trader for the different trading periods'
  primarySecondaryOffer(ca,dt,o,o1)     'Primary-secondary offer mapping for the different trading periods - in use from 01 May 2012'

* Bid sets
  bidNode(ca,dt,bd<,n)                  'Bids and the corresponding node for the different trading periods'
  bidTrader(ca,dt,bd,trdr<)             'Bids and the corresponding trader for the different trading periods'

* Risk sets
  riskGroupOffer(ca,dt,rg<,o,riskC)     'Mapping of risk group to offers in current trading period for each risk class - SPD version 11.0 update'
  ;


* Parameters loaded from GDX file in vSPDsolve.gms
Parameters
* Case-Period data
  gdxDate(*)                                        'day, month, year of trade date applied to daily GDX'
  runMode(ca,casePar)                               'Study mode and interval length applied to each caseID'
  dtParameter(ca,dt,dtPar)                          'Parameters applied to each caseID-datetime pair'

* Island data
  islandParameter(ca,dt,isl,islPar)                 'Island parameters for the different trading periods'

* Nodal data
  nodeParameter(ca,dt,n,nodePar)                    'Nodal input data for all trading periods'

* Bus data
  busElectricalIsland(ca,dt,b)                      'Electrical island status of each bus for the different trading periods (0 = Dead)'
  nodeBusAllocationFactor(ca,dt,n,b)                'Allocation factor of market node quantities to bus for the different trading periods'

* Branch and branch constraint data
  branchParameter(ca,dt,br,brPar)                   'Branch parameters for the different time periods'
  branchCstrFactors(ca,dt,brCstr<,br)               'Branch security constraint factors (sensitivities) for the current trading period'
  branchCstrRHS(ca,dt,brCstr,CstrRHS)               'Branch constraint sense and limit for the different trading periods'

* Offer data
  energyOffer(ca,dt,o,blk,bidofrCmpnt)              'Energy offers for the different trading periods'
  reserveOffer(ca,dt,o,resC,resT,blk,bidofrCmpnt)   'Reserve offers for the different trading periods'
  offerParameter(ca,dt,o,offerPar)                  'Initial MW for each offer for the different trading periods'

* Bid data
  energyBid(ca,dt,bd,blk,bidofrCmpnt)               'Energy bids for the different trading periods'
  bidParameter(ca,dt,bd,bidPar)                     'Parameters applied to each bid for the different trading periods'

* Market node constraint data
  mnCnstrRHS(ca,dt,MnodeCstr<,CstrRHS)              'Market node constraint sense and limit for the different trading periods'
  mnCstrEnrgFactors(ca,dt,MnodeCstr,o)              'Market node energy offer constraint factors for the current trading period'
  mnCnstrResrvFactors(ca,dt,MnodeCstr,o,resC,resT)  'Market node reserve offer constraint factors for the current trading period'
  mnCnstrEnrgBidFactors(ca,dt,MnodeCstr,bd)         'Market node energy bid constraint factors for the different trading periods'
  mnCnstrResrvBidFactors(ca,dt,MnodeCstr,bd,resC)   'Market node IL reserve bid constraint factors for the different trading periods - currently not used'

* Risk and reserve/sharing data
  riskParameter(ca,dt,isl,resC,riskC,riskPar)       'Risk parameters for the different trading periods'
  reserveSharingParameter(ca,dt,resPar)             'Reserve (sharing) parameters for the different trading periods'
  directionalRiskFactor(ca,dt,rg<,br,riskC)         'AC branch directional risk factor applied to a risk group for each risk class - SPD version 15.0 update'

* Scarcity data
  scarcityNationalFactor(ca,dt,blk,bidofrCmpnt)      'National energy scarcity factor parameters'
  scarcityNodeFactor(ca,dt,n,blk,bidofrCmpnt)        'Nodal energy scarcity factor parameters'
  scarcityNodeLimit(ca,dt,n,blk,bidofrCmpnt)         'Nodal energy scarcity limit parameters'
  scarcityResrvLimit(ca,dt,isl,resC,blk,bidofrCmpnt) 'Reserve scarcity limit parameters'

  ;

* Setting scalars that are hard-coded or defined in vSPDSetting.inc
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
  branchReceivingEndLossProportion         'Proportion of losses to be allocated to the receiving end of a branch' /1/
  BigM                                     'Big M value to be applied for single active segment HVDC loss model' /10000/

* External loss model from Transpower
  lossCoeff_A                       / 0.3101 /
  lossCoeff_C                       / 0.14495 /
  lossCoeff_D                       / 0.32247 /
  lossCoeff_E                       / 0.46742 /
  lossCoeff_F                       / 0.82247 /
  maxFlowSegment                    / 10000 /

  ;

* End of GDX declarations



*===================================================================================
* 2. Declare additional sets and parameters used throughout the model
*===================================================================================

* Dynamic sets that are calculated on the fly
Sets
* Global
  case2dt(ca,dt)                         'mapping caseID-DateTime pair'
  tp2dt(tp,dt)                           'mapping period to first datetime in a period '
  t(ca,dt)                               'Current trading interval to solve'

* Node/bus
  node(ca,dt,n)                          'Node definition for the different trading periods'
  bus(ca,dt,b)                           'Bus definition for the different trading periods'
  nodeIsland(ca,dt,n,isl)                'Mapping node to island'

* Network
  branch(ca,dt,br)                       'Branches defined for the current trading period'
  branchBusDefn(ca,dt,br,frB,toB)        'Branch bus connectivity for the current trading period'
  branchFrBus(ca,dt,br,frB)              'Define branch from bus connectivity for the current trading period'
  branchToBus(ca,dt,br,frB)              'Define branch to bus connectivity for the current trading period'
  branchBusConnect(ca,dt,br,b)           'Indication if a branch is connected to a bus for the current trading period'
  HVDClink(ca,dt,br)                     'HVDC links (branches) defined for the current trading period'
  ACBranch(ca,dt,br)                     'AC branches defined for the current trading period'
  ACBranchSendingBus(ca,dt,br,b,fd)      'Sending (From) bus of AC branch in forward and backward direction'
  ACBranchReceivingBus(ca,dt,br,b,fd)    'Receiving (To) bus of AC branch in forward and backward direction'
  HVDClinkSendingBus(ca,dt,br,b)         'Sending (From) bus of HVDC link'
  HVDClinkReceivingBus(ca,dt,br,toB)     'Receiving (To) bus of HVDC link'
  HVDClinkBus(ca,dt,br,b)                'Sending or Receiving bus of HVDC link'
  HVDCpoleDirection(ca,dt,br,fd)         'Direction defintion for HVDC poles S->N : forward and N->S : backward'
  HVDCpoleBranchMap(pole,br)             'Mapping of HVDC  branch to pole number'
  validLossSegment(ca,dt,br,los,fd)      'Valid loss segments for a branch'
  lossBranch(ca,dt,br)                   'Subset of branches that have non-zero loss factors'

* Branch constraint
  BranchConstraint(ca,dt,brCstr)         'Set of valid branch constraints defined for the current trading period'

* Offer
  offer(ca,dt,o)                         'Offers defined for the current trading period'
  offerIsland(ca,dt,o,isl)               'Mapping of reserve offer to island for the current trading period'
  islandRiskGenerator(ca,dt,isl,o)       'Mapping of risk generator to island in the current trading period'
  genOfrBlk(ca,dt,o,blk)                 'Valid trade blocks for the respective generation offers'
  posEnrgOfr(ca,dt,o)                    'Postive energy offers defined for the current trading period'
  resOfrBlk(ca,dt,o,blk,resC,resT)       'Valid trade blocks for the respective reserve offers by class and type'

* Bid
  Bid(ca,dt,bd)                          'Bids defined for the current trading period'
  bidIsland(ca,dt,bd,isl)                'Mapping of purchase bid ILR to island for the current trading period'
  DemBidBlk(ca,dt,bd,blk)                'Valid trade blocks for the respective purchase bids'

* Market node constraint
  MNodeConstraint(ca,dt,MnodeCstr)       'Set of market node constraints defined for the current trading period'

* Reserve/Risk
  islandRiskGroup(ca,dt,isl,rg,riskC)    'Mappimg of risk group to island in current trading period for each risk class - SPD version 11.0 update'
  islandLinkRiskGroup(ca,dt,isl,rg,riskC)'Mappimg of link risk group to island in current trading period for each risk class - SPD version 15.0 update'

* Reserve Sharing
  rampingConstraint(ca,dt,brCstr)         'Subset of branch constraints that limit total HVDC sent from an island due to ramping (5min schedule only)'
  bipoleConstraint(ca,dt,isl,brCstr)      'Subset of branch constraints that limit total HVDC sent from an island'
  monopoleConstraint(ca,dt,isl,brCstr,br) 'Subset of branch constraints that limit the flow on HVDC pole sent from an island'
  ;

Alias (t,t1,t2);

* Initialise risk/reserve data for the current trade period start



* Parameters initialised on the fly
Parameters
  studyMode(ca,dt)                        'RTD~101, RTDP~201, PRSS~130, NRSS~132, PRSL~131, NRSL~133, WDS~120'
  intervalDuration(ca,dt)                 'Length of the trading period in minutes (e.g. 30) applied to each caseID-Period pair'

* Nodal data
  refNode(ca,dt,n)                        'Reference nodes for the different trading periods'
  requiredLoad(ca,dt,n)                   'Nodal demand for the current trading period in MW'
  inputInitialLoad(ca,dt,n)               'This value represents actual load MW for RTD schedule input'
  conformingFactor(ca,dt,n)               'Initial estimated load for conforming load'
  nonConformingLoad(ca,dt,n)              'Initial estimated load for non-conforming load'
  loadIsOverride(ca,dt,n)                 'Flag if set to 1 --> InputInitialLoad will be fixed as node demand'
  loadIsBad(ca,dt,n)                      'Flag if set to 1 --> InitialLoad will be replaced by Estimated Initial Load'
  loadIsNCL(ca,dt,n)                      'Flag if set to 1 --> non-conforming load --> will be fixed in RTD load calculation'
  maxLoad(ca,dt,n)                        'Pnode maximum load'
  instructedLoadShed(ca,dt,n)             'Instructed load shedding applied to RTDP and should be ignore by all other schedules'
  instructedShedActive(ca,dt,n)           'Flag if Instructed load shedding is active; applied to RTDP and should be ignore by all other schedules'
  dispatchedLoad(ca,dt,n)                 'Initial dispatched lite demand'
  dispatchedGeneration(ca,dt,n)           'Initial dispatched lite generation'
* Factor to prorate the deficit and surplus at the nodal level
  totalBusAllocation(ca,dt,b)             'Total allocation of nodes to bus'
  busNodeAllocationFactor(ca,dt,b,n)      'Bus to node allocation factor'

* Network
  branchCapacity(ca,dt,br,fd)             'Branch directed capacity for the different trading periods in MW (Branch Reverse Ratings)'
  branchResistance(ca,dt,br)              'Resistance of the a branch for the current trading period in per unit'
  branchSusceptance(ca,dt,br)             'Susceptance (inverse of reactance) of a branch for the current trading period in per unit'
  branchFixedLoss(ca,dt,br)               'Fixed loss of the a branch for the current trading period in MW'
  branchLossBlocks(ca,dt,br)              'Number of blocks in the loss curve for the a branch in the current trading period'
  lossSegmentMW(ca,dt,br,los,fd)          'MW capacity of each loss segment'
  lossSegmentFactor(ca,dt,br,los,fd)      'Loss factor of each loss segment'
  ACBranchLossMW(ca,dt,br,los,fd)         'MW element of the loss segment curve in MW'
  ACBranchLossFactor(ca,dt,br,los,fd)     'Loss factor element of the loss segment curve'
  HVDCBreakPointMWFlow(ca,dt,br,bp,fd)    'Value of power flow on the HVDC at the break point'
  HVDCBreakPointMWLoss(ca,dt,br,bp,fd)    'Value of variable losses on the HVDC at the break point'

* Branch constraint
  BranchConstraintSense(ca,dt,brCstr)     'Branch security constraint sense for the current trading period (-1:<=, 0:= 1:>=)'
  BranchConstraintLimit(ca,dt,brCstr)     'Branch security constraint limit for the current trading period'

* Offers parameters
  generationStart(ca,dt,o)                'The MW generation level associated with the offer at the start of a trading period'
  rampRateUp(ca,dt,o)                     'The ramping up rate in MW per minute associated with the generation offer (MW/min)'
  rampRateDn(ca,dt,o)                     'The ramping down rate in MW per minute associated with the generation offer (MW/min)'
  reserveGenMax(ca,dt,o)                  'Maximum generation and reserve capability for the current trading period (MW)'
  intermittentOffer(ca,dt,o)              'Flag to indicate if offer is from intermittent generator (1 = Yes)'
  FKBand(ca,dt,o)                         'Frequency keeper band MW which is set when the risk setter is selected as the frequency keeper'
  priceResponsive(ca,dt,o)                'Flag to indicate if wind offer is price responsive (1 = Yes)'
  potentialMW(ca,dt,o)                    'Potential max output of Wind offer'
  reserveMaxFactor(ca,dt,o,resC)          'Factor to adjust the maximum reserve of the different classes for the different offers'

* Primary-secondary offer parameters
  primaryOffer(ca,dt,o)                   'Flag to indicate if offer is a primary offer (1 = Yes)'
  secondaryOffer(ca,dt,o)                 'Flag to indicate if offer is a secondary offer (1 = Yes)'

* Energy offer
  enrgOfrMW(ca,dt,o,blk)                  'Generation offer block (MW)'
  enrgOfrPrice(ca,dt,o,blk)               'Generation offer price ($/MW)'

* Reserve offer
  resrvOfrPct(ca,dt,o,blk,resC)           'The percentage of the MW block available for PLSR of class FIR or SIR'
  resrvOfrPrice(ca,dt,o,blk,resC,resT)    'The price of the reserve of the different reserve classes and types ($/MW)'
  resrvOfrMW(ca,dt,o,blk,resC,resT)       'The maximum MW offered reserve for the different reserve classes and types (MW)'

* Bid
  demBidMW(ca,dt,bd,blk)                  'Demand bid block in MW'
  demBidPrice(ca,dt,bd,blk)               'Purchase bid price in $/MW'
  demBidILRMW(ca,dt,bd,blk,resC)          'Purchase bid ILR block in MW for the different reserve classes - place holder'
  demBidILRPrice(ca,dt,bd,blk,resC)       'Purchase bid ILR price in $/MW for the different reserve classes - place holder'


* Market node constraint
  MNodeConstraintSense(ca,dt,MnodeCstr)   'Market node constraint sense for the current trading period'
  MNodeConstraintLimit(ca,dt,MnodeCstr)   'Market node constraint limit for the current trading period'


* Risk/Reserve
  HVDCSecRiskEnabled(ca,dt,isl,riskC)     'Flag indicating if the HVDC secondary risk is enabled (1 = Yes)'
  riskAdjFactor(ca,dt,isl,resC,riskC)     'Risk adjustment factor for each island, reserve class and risk class'
  HVDCpoleRampUp(ca,dt,isl,resC,riskC)    'HVDC pole MW ramp up capability for each island, reserve class and risk class'

* Secondary Risk (for comissioning)
  ACSecondaryRiskOffer(ca,dt,o,riskC)     'Secondary risk associated with a reserve/energy offer'
  ACSecondaryRiskGroup(ca,dt,rg,riskC)    'Secondary risk associated with a risk group'

* Reserve Sharing parameters
  reserveShareEnabled(ca,dt,resC)         'Database flag if reserve class resC is sharable'
  reserveShareEnabledOverall(ca,dt)       'An internal parameter based on the FIR and SIR enabled, and used as a switch in various places'
  reserveRoundPower(ca,dt,resC)           'Database flag that disables round power under certain circumstances'
  modulationRiskClass(ca,dt,riskC)        'HVDC energy modulation due to frequency keeping action'
  modulationRisk(ca,dt)                   'Max of HVDC energy modulation due to frequency keeping action'

  roundPower2MonoLevel(ca,dt)             'HVDC sent value above which one pole is stopped and therefore FIR cannot use round power'
  bipole2MonoLevel(ca,dt)                 'HVDC sent value below which one pole is available to start in the opposite direction and therefore SIR can use round power'
  roPwrZoneExit(ca,dt,resC)               'Above this point there is no guarantee that HVDC sent can be reduced below MonopoleMinimum.'

  monopoleMinimum(ca,dt)                  'The lowest level that the sent HVDC sent can ramp down to when round power is not available.'
  HVDCControlBand(ca,dt,rd)               'Modulation limit of the HVDC control system apply to each HVDC direction'
  HVDClossScalingFactor(ca,dt)            'Losses used for full voltage mode are adjusted by a factor of (700/500)^2 for reduced voltage operation'
  RMTReserveLimit(ca,dt,isl,resC)         'The shared reserve limit used by RMT when it calculated the NFRs. Applied as a cap to the value that is calculated for SharedNFRMax.'
  sharedNFRFactor(ca,dt)                  'Factor that is applied to [sharedNFRLoad - sharedNFRLoadOffset] as part of the calculation of sharedNFRMax'
  sharedNFRLoadOffset(ca,dt,isl)          'Island load that does not provide load damping, e.g., Tiwai smelter load in the South Island. Subtracted from the sharedNFRLoad in the calculation of sharedNFRMax.'
  effectiveFactor(ca,dt,isl,resC,riskC)   'Estimate of the effectiveness of the shared reserve once it has been received in the risk island.'

* HVDC data for Reserve Sharing
  numberOfPoles(ca,dt,isl)                    'Number of HVDC poles avaialbe to send energy from an island'
  monoPoleCapacity(ca,dt,isl,br)              'Maximum capacity of monopole defined by min of branch capacity and monopole constraint RHS'
  biPoleCapacity(ca,dt,isl)                   'Maximum capacity of bipole defined by bipole constraint RHS'
  HVDCMax(ca,dt,isl)                          'Max HVDC flow based on available poles and branch group constraints RHS'
  HVDCCapacity(ca,dt,isl)                     'Total sent capacity of HVDC based on available poles'
  HVDCResistance(ca,dt,isl)                   'Estimated resistance of HVDC flow sent from an island'
  HVDClossSegmentMW(ca,dt,isl,los)            'MW capacity of each loss segment applied to aggregated HVDC capacity'
  HVDClossSegmentFactor(ca,dt,isl,los)        'Loss factor of each loss segment applied to to aggregated HVDC loss'
  HVDCSentBreakPointMWFlow(ca,dt,isl,los)     'Value of total HVDC sent power flow at the break point               --> lambda segment loss model'
  HVDCSentBreakPointMWLoss(ca,dt,isl,los)     'Value of ariable losses of the total HVDC sent at the break point    --> lambda segment loss model'
  HVDCReserveBreakPointMWFlow(ca,dt,isl,los)  'Value of total HVDC sent power flow + reserve at the break point     --> lambda segment loss model'
  HVDCReserveBreakPointMWLoss(ca,dt,isl,los)  'Value of post-contingent variable HVDC losses at the break point     --> lambda segment loss model'

  sharedNFRLoad(ca,dt,isl)                'Island load, calculated in pre-processing from the required load and the bids. Used as an input to the calculation of SharedNFRMax.'
  sharedNFRMax(ca,dt,isl)                 'Amount of island free reserve that can be shared through HVDC'
  FreeReserve(ca,dt,isl,resC,riskC)       'MW free reserve for each island, reserve class and risk class'
* NMIR parameters end

* Real Time Pricing - Inputs
  useGenInitialMW(ca,dt)                  'Flag that if set to 1 indicates that for a schedule that is solving multiple intervals in sequential mode'
  useActualLoad(ca,dt)                    'Flag that if set to 0, initial estimated load [conformingfactor/noncomformingload] is used as initial load '
  maxSolveLoops(ca,dt)                    'The maximum number of times that the Energy Shortfall Check will re-solve the model'

  islandMWIPS(ca,dt,isl)                  'Island total generation at the start of RTD run'
  islandPDS(ca,dt,isl)                    'Island pre-solve deviation - used to adjust RTD node demand'
  islandLosses(ca,dt,isl)                 'Island estimated losss - used to adjust RTD mode demand'
  SPDLoadCalcLosses(ca,dt,isl)            'Island losses calculated by SPD in the first solve to adjust demand'

  energyScarcityEnabled(ca,dt)                 'Flag to apply energy scarcity (this is different from FP scarcity situation)'
  reserveScarcityEnabled(ca,dt)                'Flag to apply reserve scarcity (this is different from FP scarcity situation)'
  scarcityEnrgLimit(ca,dt,n,blk)               'Node energy scarcity limits'
  scarcityEnrgPrice(ca,dt,n,blk)               'Node energy scarcity prices vs limits'
  scarcityResrvIslandLimit(ca,dt,isl,resC,blk) 'Reserve scarcity limits'
  scarcityResrvIslandPrice(ca,dt,isl,resC,blk) 'Reserve scarcity prices'

  commRiskDoRiskAdjustment(ca,dt)              'The CommRiskDoRiskAdjustment would only be set to 0 for testing. If it was set to 0 then the ACSecondaryRiskMW adjustment would not be applied:'
  commRiskDoCheckResOffers(ca,dt)              'Similarly, the CommRiskDoCheckResOffers would only be set to 0 for testing. If it was set to 0 then the resevre offered on secondary risk is not set to zero'


* Real Time Pricing - Calculated parameters
  InitialLoad(ca,dt,n)                                'Value that represents the Pnode load MW at the start of the solution interval. Depending on the inputs this value will be either actual load, an operator applied override or an estimated initial load'
  LoadIsScalable(ca,dt,n)                             'Binary value. If True then the Pnode InitialLoad will be scaled in order to calculate nodedemand, if False then Pnode InitialLoad will be directly assigned to nodedemand'
  LoadScalingFactor(ca,dt,isl)                        'Island-level scaling factor applied to InitialLoad in order to calculate nodedemand'
  TargetTotalLoad(ca,dt,isl)                          'Island-level MW load forecast'
  LoadCalcLosses(ca,dt,isl)                           'Island-level MW losses used to calculate the Island-level load forecast from the InputIPS and the IslandPSD. 1st loop --> InitialLosses, 2nd solve loop --> SystemLosses as calculated in section 6.3'
  EstimatedInitialLoad(ca,dt,n)                       'Calculated estimate of initial MW load, available to be used as an alternative to InputInitialLoad'
  EstScalingFactor(ca,dt,isl)                         'Scaling applied to ConformingFactor load MW in order to calculate EstimatedInitialLoad'
  EstLoadIsScalable(ca,dt,n)                          'Binary value. If True then ConformingFactor load MW will be scaled in order to calculate EstimatedInitialLoad. If False then EstNonScalableLoad will be assigned directly to EstimatedInitialLoad'
  EstNonScalableLoad(ca,dt,n)                         'For a non-conforming Pnode this will be the NonConformingLoad MW input, for a conforming Pnode this will be the ConformingFactor MW input if that value is negative, otherwise it will be zero'
  EstScalableLoad(ca,dt,n)                            'For a non-conforming Pnode this value will be zero. For a conforming Pnode this value will be the ConformingFactor if it is non-negative, otherwise this value will be zero'

* Post-processing
  useBranchFlowMIP(ca,dt)                             'Flag to indicate if integer constraints are needed in the branch flow model: 1 = Yes'


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
  ISLANDRISK(ca,dt,isl,resC,riskC)                    'Island MW risk for the different reserve and risk classes'
  GENISLANDRISK(ca,dt,isl,o,resC,riskC)               'Island MW risk for different risk setting generators'
  GENISLANDRISKGROUP(ca,dt,isl,rg,resC,riskC)         'Island MW risk for different risk group - SPD version 11.0'
  HVDCGENISLANDRISK(ca,dt,isl,o,resC,riskC)           'Island MW risk for different risk setting generators + HVDC'
  HVDCMANISLANDRISK(ca,dt,isl,resC,riskC)             'Island MW risk for manual risk + HVDC'
  HVDCREC(ca,dt,isl)                                  'Total net pre-contingent HVDC MW flow received at each island'
  RISKOFFSET(ca,dt,isl,resC,riskC)                    'MW offset applied to the raw risk to account for HVDC pole rampup, AUFLS, free reserve and non-compliant generation'

* NMIR free variables
  HVDCRESERVESENT(ca,dt,isl,resC,rd)                  'Total net post-contingent HVDC MW flow sent from an island applied to each reserve class'
  HVDCRESERVELOSS(ca,dt,isl,resC,rd)                  'Post-contingent HVDC loss of energy + reserve sent from an island applied to each reserve class'
* NMIR free variables end

* Network
  ACNODENETINJECTION(ca,dt,b)                         'MW injection at buses corresponding to AC nodes'
  ACBRANCHFLOW(ca,dt,br)                              'MW flow on undirected AC branch'
  ACNODEANGLE(ca,dt,b)                                'Bus voltage angle'

* Demand bids can be either positive or negative from v6.0 of SPD formulation (with DSBF)
* The lower bound of the free variable is updated in vSPDSolve.gms to allow backward compatibility
* Note the formulation now refers to this as Demand. So Demand (in SPD formulation) = Purchase (in vSPD code)
  PURCHASE(ca,dt,bd)                                  'Total MW purchase scheduled'
  PURCHASEBLOCK(ca,dt,bd,blk)                         'MW purchase scheduled from the individual trade blocks of a bid'

  ;

Positive variables
* system cost and benefit
  SYSTEMBENEFIT(ca,dt)                                'Total purchase bid benefit by period'
  SYSTEMCOST(ca,dt)                                   'Total generation and reserve costs by period'
  SYSTEMPENALTYCOST(ca,dt)                            'Total violation costs by period'
  TOTALPENALTYCOST                                 'Total violation costs'
  SCARCITYCOST(ca,dt)                                 'Total scarcity Cost'
* scarcity variables
  ENERGYSCARCITYBLK(ca,dt,n,blk)                      'Block energy scarcity cleared at bus b'
  ENERGYSCARCITYNODE(ca,dt,n)                         'Energy scarcity cleared at bus b'

  RESERVESHORTFALLBLK(ca,dt,isl,resC,riskC,blk)       'Block reserve shortfall by risk class (excluding genrisk and HVDC secondary risk)'
  RESERVESHORTFALL(ca,dt,isl,resC,riskC)              'Reserve shortfall by risk class (excluding genris kand HVDC secondary risk)'

  RESERVESHORTFALLUNITBLK(ca,dt,isl,o,resC,riskC,blk) 'Block reserve shortfall by risk generation unit (applied to genrisk and HVDC secondary risk)'
  RESERVESHORTFALLUNIT(ca,dt,isl,o,resC,riskC)        'Reserve shortfall by risk generation unit (applied to genrisk and HVDC secondary risk)'

  RESERVESHORTFALLGROUPBLK(ca,dt,isl,rg,resC,riskC,blk) 'Block Reserve shortfall by risk group (applied to genrisk and HVDC secondary risk)'
  RESERVESHORTFALLGROUP(ca,dt,isl,rg,resC,riskC)        'Reserve shortfall by risk risk group (applied to genrisk and HVDC secondary risk)'

* Generation
  GENERATION(ca,dt,o)                                 'Total MW generation scheduled from an offer'
  GENERATIONBLOCK(ca,dt,o,blk)                        'MW generation scheduled from the individual trade blocks of an offer'
  GENERATIONUPDELTA(ca,dt,o)                          'Total increase in MW generation scheduled from an offer'
  GENERATIONDNDELTA(ca,dt,o)                          'Total decrease in MW generation scheduled from an offer'
* Reserve
  RESERVE(ca,dt,o,resC,resT)                          'MW Reserve scheduled from an offer'
  RESERVEBLOCK(ca,dt,o,blk,resC,resT)                 'MW Reserve scheduled from the individual trade blocks of an offer'
  ISLANDRESERVE(ca,dt,isl,resC)                       'Total island cleared reserve'

* NMIR positive variables
  SHAREDNFR(ca,dt,isl)                                'Amount of free load reserve being shared from an island'
  SHAREDRESERVE(ca,dt,isl,resC)                       'Amount of cleared reserve from an island being shared to the other island'
  HVDCSENT(ca,dt,isl)                                 'Directed pre-contingent HVDC MW flow sent from each island'
  HVDCSENTLOSS(ca,dt,isl)                             'Energy loss for  HVDC flow sent from an island'
  RESERVESHAREEFFECTIVE(ca,dt,isl,resC,riskC)         'Effective shared reserve received at island after adjusted for losses and effectiveness factor'
  RESERVESHARERECEIVED(ca,dt,isl,resC,rd)             'Directed shared reserve received at island after adjusted for losses'
  RESERVESHARESENT(ca,dt,isl,resC,rd)                 'Directed shared reserve sent from and island'
  RESERVESHAREPENALTY(ca,dt)                          'Penalty cost for excessive reserve sharing'
* Tuong Nguyen added on 24 Feb 2021 to correct the calculation of RESERVESHAREPENALTY
  RESERVESHAREEFFECTIVE_CE(ca,dt,isl,resC)            'Max effective shared reserve for CE risk received at island after adjusted for losses and effectiveness factor'
  RESERVESHAREEFFECTIVE_ECE(ca,dt,isl,resC)           'Max effective shared reserve for ECE risk received at island after adjusted for losses and effectiveness factor'
* NMIR positive variables end

* Network
  HVDCLINKFLOW(ca,dt,br)                              'MW flow at the sending end scheduled for the HVDC link'
  HVDCLINKLOSSES(ca,dt,br)                            'MW losses on the HVDC link'
  LAMBDA(ca,dt,br,bp)                                 'Non-negative weight applied to the breakpoint of the HVDC link'
  ACBRANCHFLOWDIRECTED(ca,dt,br,fd)                   'MW flow on the directed branch'
  ACBRANCHLOSSESDIRECTED(ca,dt,br,fd)                 'MW losses on the directed branch'
  ACBRANCHFLOWBLOCKDIRECTED(ca,dt,br,los,fd)          'MW flow on the different blocks of the loss curve'
  ACBRANCHLOSSESBLOCKDIRECTED(ca,dt,br,los,fd)        'MW losses on the different blocks of the loss curve'
* Violations
  DEFICITBUSGENERATION(ca,dt,b)                       'Deficit generation at a bus in MW'
  SURPLUSBUSGENERATION(ca,dt,b)                       'Surplus generation at a bus in MW'
  DEFICITBRANCHSECURITYCONSTRAINT(ca,dt,brCstr)       'Deficit branch security constraint in MW'
  SURPLUSBRANCHSECURITYCONSTRAINT(ca,dt,brCstr)       'Surplus branch security constraint in MW'
  DEFICITRAMPRATE(ca,dt,o)                            'Deficit ramp rate in MW'
  SURPLUSRAMPRATE(ca,dt,o)                            'Surplus ramp rate in MW'
  DEFICITBRANCHFLOW(ca,dt,br)                         'Deficit branch flow in MW'
  SURPLUSBRANCHFLOW(ca,dt,br)                         'Surplus branch flow in MW'
  DEFICITMNODECONSTRAINT(ca,dt,MnodeCstr)             'Deficit market node constraint in MW'
  SURPLUSMNODECONSTRAINT(ca,dt,MnodeCstr)             'Surplus market node constraint in MW'
* Seperate CE and ECE violation variables to support different CVPs for CE and ECE
  DEFICITRESERVE_CE(ca,dt,isl,resC)                   'Deficit CE reserve generation in each island for each reserve class in MW'
  DEFICITRESERVE_ECE(ca,dt,isl,resC)                  'Deficit ECE reserve generation in each island for each reserve class in MW'

  ;

Binary variables
* NMIR binary variables
  HVDCSENDING(ca,dt,isl)                              'Binary variable indicating if island isl is the sending end of the HVDC flow. 1 = Yes.'
  INZONE(ca,dt,isl,resC,z)                            'Binary variable (1 = Yes ) indicating if the HVDC flow is in a zone (z) that facilitates the appropriate quantity of shared reserves in the reverse direction to the HVDC sending island isl for reserve class resC.'
  HVDCSENTINSEGMENT(ca,dt,isl,los)                    'Binary variable to decide which loss segment HVDC flow sent from an island falling into --> active segment loss model'
* Discete dispachable demand block binary variables
  PURCHASEBLOCKBINARY(ca,dt,bd,blk)                   'Binary variable to decide if a purchase block is cleared either fully or nothing at all'
* HVDC Secondary risk should not be covered if HVDC sending is zero. The following binary variable is to enforced that (Update from RTP phase 4)
  HVDCSENDZERO(ca,dt,isl)                              'Binary variable indicating if island is NOT the sending energy through HVDC flow. 1 = Yes.'
  ;

SOS1 Variables
  ACBRANCHFLOWDIRECTED_INTEGER(ca,dt,br,fd)           'Integer variables used to select branch flow direction in the event of circular branch flows (3.8.1)'
  HVDCLINKFLOWDIRECTED_INTEGER(ca,dt,fd)              'Integer variables used to select the HVDC branch flow direction on in the event of S->N (forward) and N->S (reverse) flows (3.8.2)'
* Integer varaible to prevent intra-pole circulating branch flows
  HVDCPOLEFLOW_INTEGER(ca,dt,pole,fd)                 'Integer variables used to select the HVDC pole flow direction on in the event of circulating branch flows within a pole'
  ;

SOS2 Variables
  LAMBDAINTEGER(ca,dt,br,bp)                          'Integer variables used to enforce the piecewise linear loss approxiamtion on the HVDC links'
  LAMBDAHVDCENERGY(ca,dt,isl,bp)                      'Integer variables used to enforce the piecewise linear loss approxiamtion (NMIR) on the HVDC links'
  LAMBDAHVDCRESERVE(ca,dt,isl,resC,rd,rsbp)           'Integer variables used to enforce the piecewise linear loss approxiamtion (NMIR) on the HVDC links'
  ;


Equations
  ObjectiveFunction                                'Objective function of the dispatch model (5.1.1.1)'
* Cost and benefit breaking down
  SystemBenefitDefinition(ca,dt)                      'Defined as the sum of the purcahse bid benefit'
  SystemCostDefinition(ca,dt)                         'Defined as the sum of the generation and reserve costs'
  SystemPenaltyCostDefinition(ca,dt)                  'Defined as the sum of the individual violation costs'
  TotalViolationCostDefinition                     'Deined as the sume of period violation cost - (for reporting)'
  TotalScarcityCostDefinition(ca,dt)                  'Deined as the sume of scarcity cost'


* Offer and purchase constraints
  GenerationChangeUpDown(ca,dt,o)                     'Calculate the MW of generation increase/decrease for RTD and RTDP (6.1.1.2)'
  GenerationOfferDefintion(ca,dt,o)                   'Definition of generation provided by an offer (6.1.1.3)'
  DemBidDiscrete(ca,dt,bd,blk)                        'Definition of discrete purchase mode (6.1.1.7)'
  DemBidDefintion(ca,dt,bd)                           'Definition of purchase provided by a bid (6.1.1.8)'
  EnergyScarcityDefinition(ca,dt,n)                   'Definition of bus energy scarcity (6.1.1.10)'

* Ramping constraints
  GenerationRampUp(ca,dt,o)                           'Maximum movement of the generator upwards due to up ramp rate (6.2.1.1)'
  GenerationRampDown(ca,dt,o)                         'Maximum movement of the generator downwards due to down ramp rate (6.2.1.2)'



* HVDC transmission constraints
  HVDClinkMaximumFlow(ca,dt,br)                       'Maximum flow on each HVDC link (6.3.1.1)'
  HVDClinkLossDefinition(ca,dt,br)                    'Definition of losses on the HVDC link (6.3.1.2)'
  HVDClinkFlowDefinition(ca,dt,br)                    'Definition of MW flow on the HVDC link (6.3.1.3)'
  LambdaDefinition(ca,dt,br)                          'Definition of weighting factor (6.3.1.4)'

* HVDC transmission constraints to resolve non-physical loss and circular flow
* These constraints are not explicitly formulated in SPD formulation
* But you can find the description in "Post-Solve Checks"
  HVDClinkFlowIntegerDefinition1(ca,dt)               'Definition 1 of the integer HVDC link flow variable )'
  HVDClinkFlowIntegerDefinition2(ca,dt,fd)            'Definition 2 of the integer HVDC link flow variable'
  HVDClinkFlowIntegerDefinition3(ca,dt,pole)          'Definition 4 of the HVDC pole integer varaible to prevent intra-pole circulating branch flows'
  HVDClinkFlowIntegerDefinition4(ca,dt,pole,fd)       'Definition 4 of the HVDC pole integer varaible to prevent intra-pole circulating branch flows'
  LambdaIntegerDefinition1(ca,dt,br)                  'Definition of weighting factor when branch integer constraints are needed'
  LambdaIntegerDefinition2(ca,dt,br,los)              'Definition of weighting factor when branch integer constraints are needed'

* AC transmission constraints
  ACnodeNetInjectionDefinition1(ca,dt,b)              '1st definition of the net injection at buses corresponding to AC nodes (6.4.1.1)'
  ACnodeNetInjectionDefinition2(ca,dt,b)              '2nd definition of the net injection at buses corresponding to AC nodes (6.4.1.2)'
  ACBranchMaximumFlow(ca,dt,br,fd)                    'Maximum flow on the AC branch (6.4.1.3)'
  ACBranchFlowDefinition(ca,dt,br)                    'Relationship between directed and undirected branch flow variables (6.4.1.4)'
  LinearLoadFlow(ca,dt,br)                            'Equation that describes the linear load flow (6.4.1.5)'
  ACBranchBlockLimit(ca,dt,br,los,fd)                 'Limit on each AC branch flow block (6.4.1.6)'
  ACDirectedBranchFlowDefinition(ca,dt,br,fd)         'Composition of the directed branch flow from the block branch flow (6.4.1.7)'
  ACBranchLossCalculation(ca,dt,br,los,fd)            'Calculation of the losses in each loss segment (6.4.1.8)'
  ACDirectedBranchLossDefinition(ca,dt,br,fd)         'Composition of the directed branch losses from the block branch losses (6.4.1.9)'

* AC transmission constraints to resolve circular flow
  ACDirectedBranchFlowIntegerDefinition1(ca,dt,br)    'Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses'
  ACDirectedBranchFlowIntegerDefinition2(ca,dt,br,fd) 'Integer constraint to enforce a flow direction on loss AC branches in the presence of circular branch flows or non-physical losses'

* Risk
  RiskOffsetCalculation_DCCE(ca,dt,isl,resC,riskC)          '6.5.1.1 : Calculation of the risk offset variable for the DCCE risk class.'
  RiskOffsetCalculation_DCECE(ca,dt,isl,resC,riskC)         '6.5.1.3 : Calculation of the risk offset variable for the DCECE risk class.'
  HVDCRecCalculation(ca,dt,isl)                             '6.5.1.4 : Calculation of the net received HVDC MW flow into an island.'
  HVDCIslandRiskCalculation(ca,dt,isl,resC,riskC)           '6.5.1.5 : Calculation of the island risk for a DCCE and DCECE.'

  GenIslandRiskCalculation(ca,dt,isl,o,resC,riskC)          '6.5.1.6 : Calculation of the island risk for risk setting generators.'
  GenIslandRiskCalculation_1(ca,dt,isl,o,resC,riskC)        '6.5.1.6 : Calculation of the island risk for risk setting generators.'
  ManualIslandRiskCalculation(ca,dt,isl,resC,riskC)         '6.5.1.7 : Calculation of the island risk based on manual specifications.'
  HVDCSendMustZeroBinaryDefinition(ca,dt,isl)               '6.5.1.8: Define a flag to show if HVDC sending zero MW flow from an island '

  HVDCIslandSecRiskCalculation_GEN(ca,dt,isl,o,resC,riskC)     '6.5.1.9 : Calculation of the island risk for an HVDC secondary risk to an AC risk.'
  HVDCIslandSecRiskCalculation_GEN_1(ca,dt,isl,o,resC,riskC)   '6.5.1.9 : Calculation of the island risk for an HVDC secondary risk to an AC risk.'
  HVDCIslandSecRiskCalculation_Manual(ca,dt,isl,resC,riskC)    '6.5.1.10: Calculation of the island risk for an HVDC secondary risk to a manual risk.'
  HVDCIslandSecRiskCalculation_Manu_1(ca,dt,isl,resC,riskC)    '6.5.1.10: Calculation of the island risk for an HVDC secondary risk to a manual risk.'
  GenIslandRiskGroupCalculation(ca,dt,isl,rg,resC,riskC)       '6.5.1.11: Calculation of the island risk of risk group.'
  GenIslandRiskGroupCalculation_1(ca,dt,isl,rg,resC,riskC)     '6.5.1.11: Calculation of the island risk of risk group.'
  AClineRiskGroupCalculation(ca,dt,isl,rg,resC,riskC)          '6.5.1.12: Calculation of the island risk of link risk group.'
  AClineRiskGroupCalculation_1(ca,dt,isl,rg,resC,riskC)        '6.5.1.12: Calculation of the island risk of link risk group.'

* General NMIR equations
  EffectiveReserveShareCalculation(ca,dt,isl,resC,riskC)                           '6.5.2.1 : Calculation of effective shared reserve'
  SharedReserveLimitByClearedReserve(ca,dt,isl,resC)                               '6.5.2.2 : Shared offered reserve is limited by cleared reserved'
  BothClearedAndFreeReserveCanBeShared(ca,dt,isl,resC,rd)                          '6.5.2.4 : Shared reserve is covered by cleared reserved and shareable free reserve'
  ReserveShareSentLimitByHVDCControlBand(ca,dt,isl,resC,rd)                        '6.5.2.5 : Reserve share sent from an island is limited by HVDC control band'
  FwdReserveShareSentLimitByHVDCCapacity(ca,dt,isl,resC,rd)                        '6.5.2.6 : Forward reserve share sent from an island is limited by HVDC capacity'
  ReverseReserveOnlyToEnergySendingIsland(ca,dt,isl,resC,rd)                       '6.5.2.7 : Shared reserve sent in reverse direction is possible only if the island is not sending energy through HVDC'
  ReverseReserveShareLimitByHVDCControlBand(ca,dt,isl,resC,rd)                     '6.5.2.8 : Reverse reserve share recieved at an island is limited by HVDC control band'
  ForwardReserveOnlyToEnergyReceivingIsland(ca,dt,isl,resC,rd)                     '6.5.2.9 : Forward received reserve is possible if in the same direction of HVDC '
  ReverseReserveLimitInReserveZone(ca,dt,isl,resC,rd,z)                            '6.5.2.10: Reverse reserve constraint if HVDC sent flow in reverse zone'
  ZeroReserveInNoReserveZone(ca,dt,isl,resC,z)                                     '6.5.2.11 & 6.5.2.18: No reverse reserve if HVDC sent flow in no reverse zone and no forward reserve if round power disabled'
  OnlyOneActiveHVDCZoneForEachReserveClass(ca,dt,resC)                             '6.5.2.12: Across both island, one and only one zone is active for each reserve class'
  ZeroSentHVDCFlowForNonSendingIsland(ca,dt,isl)                                   '6.5.2.13: Directed HVDC sent from an island, if non-zero, must fall in a zone for each reserve class'
  RoundPowerZoneSentHVDCUpperLimit(ca,dt,isl,resC,z)                               '6.5.2.14: Directed HVDC sent from an island <= RoundPowerZoneExit level if in round power zone of that island'
  HVDCSendingIslandDefinition(ca,dt,isl,resC)                                      '6.5.2.15: An island is HVDC sending island if HVDC flow sent is in one of the three zones for each reserve class '
  OnlyOneSendingIslandExists(ca,dt)                                                '6.5.2.19: One and only one island is HVDC sending island'
  HVDCSentCalculation(ca,dt,isl)                                                   '6.5.2.20: Total HVDC sent from each island'

* Lamda loss model
  HVDCFlowAccountedForForwardReserve(ca,dt,isl,resC,rd)                            '6.5.2.21: HVDC flow sent from an island taking into account forward sent reserve'
  ForwardReserveReceivedAtHVDCReceivingIsland(ca,dt,isl,resC,rd)                   '6.5.2.22: Forward reserve RECEIVED at an HVDC receiving island'
  HVDCFlowAccountedForReverseReserve(ca,dt,isl,resC,rd)                            '6.5.2.23: HVDC flow sent from an island taking into account reverse received reserve'
  ReverseReserveReceivedAtHVDCSendingIsland(ca,dt,isl,resC,rd)                     '6.5.2.24: Reverse reserve RECEIVED at an HVDC sending island'
  HVDCSentEnergyLambdaDefinition(ca,dt,isl)                                        '6.5.2.25: Definition of weight factor for total HVDC energy sent from an island'
  HVDCSentEnergyFlowDefinition(ca,dt,isl)                                          '6.5.2.26: Lambda definition of total HVDC energy flow sent from an island'
  HVDCSentEnergyLossesDefinition(ca,dt,isl)                                        '6.5.2.27: Lambda definition of total loss of HVDC energy sent from an island'
  HVDCSentReserveLambdaDefinition(ca,dt,isl,resC,rd)                               '6.5.2.28: Definition of weight factor for total HVDC+reserve sent from an island'
  HVDCSentReserveFlowDefinition(ca,dt,isl,resC,rd)                                 '6.5.2.29: Lambda definition of Reserse + Energy flow on HVDC sent from an island'
  HVDCSentReserveLossesDefinition(ca,dt,isl,resC,rd)                               '6.5.2.30: Lambda definition of Reserse + Energy loss on HVDC sent from an island'

* Reserve share penalty
* Tuong Nguyen added on 24 Feb 2021 to correct the calculation
  ReserveShareEffective_CE_Calculation(ca,dt,isl,resC,riskC)                       '6.5.2.31: Calculate max effective shared reserve for CE risk received at island'
  ReserveShareEffective_ECE_Calculation(ca,dt,isl,resC,riskC)                      '6.5.2.31: Calculate max effective shared reserve for ECE risk received at island'
  ExcessReserveSharePenalty(ca,dt)                                                 '6.5.2.31: Constraint to avoid excessive reserve share'

* Reserve
  PLSRReserveProportionMaximum(ca,dt,o,blk,resC,resT)                              '6.5.3.1: Maximum PLSR as a proportion of the block MW'
  ReserveInterruptibleOfferLimit(ca,dt,o,bd,resC,resT)                             '6.5.3.3: Cleared IL reserve is constrained by cleared dispatchable demand'
  ReserveOfferDefinition(ca,dt,o,resC,resT)                                        '6.5.3.4: Definition of the reserve offers of different classes and types'
  EnergyAndReserveMaximum(ca,dt,o,resC)                                            '6.5.3.5: Definition of maximum energy and reserves from each generator'

* Reserve scarcity/shortfall
  HVDCRiskReserveShortFallCalculation(ca,dt,isl,resC,RiskC)                        '6.5.4.2: Total Reserve Shortfall for DCCE risk'
  ManualRiskReserveShortFallCalculation(ca,dt,isl,resC,RiskC)                      '6.5.4.2: Total Reserve Shortfall for Manual risk'
  GenRiskReserveShortFallCalculation(ca,dt,isl,o,resC,RiskC)                       '6.5.4.2: Total Reserve Shortfall for generation risk unit'
  HVDCsecRiskReserveShortFallCalculation(ca,dt,isl,o,resC,RiskC)                   '6.5.4.2: Total Reserve Shortfall for generation unit + HVDC risk'
  HVDCsecManualRiskReserveShortFallCalculation(ca,dt,isl,resC,RiskC)                '6.5.4.2: Total Reserve Shortfall for Manual risk + HVDC risk'
  RiskGroupReserveShortFallCalculation(ca,dt,isl,rg,resC,RiskC)                     '6.5.4.2: Total Reserve Shortfall for Risk Group'

* Matching of reserve requirement and availability
  IslandReserveCalculation(ca,dt,isl,resC)                                         '6.5.5.1: Calculate total island cleared reserve'
  SupplyDemandReserveRequirement(ca,dt,isl,resC,riskC)                             '6.5.5.2&3: Matching of reserve supply and demand'

* Branch security constraints
  BranchSecurityConstraintLE(ca,dt,brCstr)                                         '6.6.1.5: Branch security constraint with LE sense'
  BranchSecurityConstraintGE(ca,dt,brCstr)                                         '6.6.1.5: Branch security constraint with GE sense'
  BranchSecurityConstraintEQ(ca,dt,brCstr)                                         '6.6.1.5: Branch security constraint with EQ sense'

* Market node security constraints
  MNodeSecurityConstraintLE(ca,dt,MnodeCstr)                                       '6.6.1.7: Market node security constraint with LE sense'
  MNodeSecurityConstraintGE(ca,dt,MnodeCstr)                                       '6.6.1.7: Market node security constraint with GE sense'
  MNodeSecurityConstraintEQ(ca,dt,MnodeCstr)                                       '6.6.1.7: Market node security constraint with EQ sense'

  ;

* OBJECTIVE FUNCTION (5.1.1.1)
ObjectiveFunction..
  NETBENEFIT
=e=
  sum[ t, SYSTEMBENEFIT(t) - SYSTEMCOST(t) - SCARCITYCOST(t)
        - SYSTEMPENALTYCOST(t) - RESERVESHAREPENALTY(t) ]
  + sum[(t,n,blk), scarcityEnrgLimit(t,n,blk) * scarcityEnrgPrice(t,n,blk)]
  ;

* Defined as the net sum of generation cost + reserve cost
SystemCostDefinition(t)..
  SYSTEMCOST(t)
=e=
  sum[ genOfrBlk(t,o,blk)
     , GENERATIONBLOCK(genOfrBlk)
     * enrgOfrPrice(genOfrBlk) ]
+ sum[ resOfrBlk(t,o,blk,resC,resT)
     , RESERVEBLOCK(resOfrBlk)
     * resrvOfrPrice(resOfrBlk) ]
  ;

* Defined as the net sum of dispatchable load benefit
SystemBenefitDefinition(t)..
  SYSTEMBENEFIT(t)
=e=
  sum[ demBidBlk(t,bd,blk)
     , PURCHASEBLOCK(demBidBlk)
     * demBidPrice(demBidBlk) ]
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

+ sum[ o $ { (StudyMode(t) = 101) or (StudyMode(t) = 201) }
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
  sum[ (n,blk), scarcityEnrgPrice(t,n,blk) * ENERGYSCARCITYBLK(t,n,blk) ]

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
GenerationChangeUpDown(t,o) $ { (StudyMode(t) = 101) or (StudyMode(t) = 201) }..
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
DemBidDiscrete(bid(t,bd),blk) $ { bidParameter(bid,'discrete') = 1 }..
  PURCHASEBLOCK(bid,blk)
=e=
  PURCHASEBLOCKBINARY(bid,blk) * demBidMW(bid,blk)
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
GenerationRampUp(t,o) $ { posEnrgOfr(t,o) and primaryOffer(t,o) }..
  sum[ o1 $ PrimarySecondaryOffer(t,o,o1), GENERATION(t,o1) ]
+ GENERATION(t,o) - DEFICITRAMPRATE(t,o)
=l=
  generationStart(t,o) + (rampRateUp(t,o) * intervalDuration(t) / 60)
  ;

* Maximum movement of the generator downwards due to down ramp rate (6.2.1.2)
GenerationRampDown(t,o) $ { posEnrgOfr(t,o) and primaryOffer(t,o) }..
  sum[ o1 $ PrimarySecondaryOffer(t,o,o1), GENERATION(t,o1) ]
+ GENERATION(t,o) + SURPLUSRAMPRATE(t,o)
=g=
  generationStart(t,o) - (rampRateDn(t,o) * intervalDuration(t) / 60)
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
     , NodeBusAllocationFactor(t,n,b) * requiredLoad(t,n) ]
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
  riskAdjFactor(t,isl,resC,HVDCrisk)
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
  riskAdjFactor(t,isl,resC,GenRisk)
  * [ GENERATION(t,o)
    - ACSecondaryRiskOffer(t,o,GenRisk)
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
  riskAdjFactor(t,isl,resC,ManualRisk)
  * [ riskParameter(t,isl,resC,ManualRisk,'minRisk')
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
  riskAdjFactor(t,isl,resC,HVDCSecRisk)
  * [ GENERATION(t,o)
    - FreeReserve(t,isl,resC,HVDCSecRisk)
    + HVDCREC(t,isl)
    - islandParameter(t,isl,'HVDCSecSubtractor')
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
  riskAdjFactor(t,isl,resC,HVDCSecRisk)
  * [ riskParameter(t,isl,resC,HVDCSecRisk,'minRisk')
    - FreeReserve(t,isl,resC,HVDCSecRisk)
    + HVDCREC(t,isl)
    - islandParameter(t,isl,'HVDCSecSubtractor')
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
  $ {islandRiskGroup(t,isl,rg,GenRisk) and (not islandLinkRiskGroup(t,isl,rg,GenRisk))}..
  GENISLANDRISKGROUP(t,isl,rg,resC,GenRisk)
=e=
  riskAdjFactor(t,isl,resC,GenRisk)
  * [ sum[ o $ { offerIsland(t,o,isl)
             and riskGroupOffer(t,rg,o,GenRisk)
               } , GENERATION(t,o) + FKBand(t,o)
                 + sum[ resT, RESERVE(t,o,resC,resT) ]
         ]
    - ACSecondaryRiskGroup(t,rg,GenRisk)
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

* 6.5.1.12: Calculation of the island risk of link risk group.
AClineRiskGroupCalculation_1(t,isl,rg,resC,GenRisk)
  $ islandLinkRiskGroup(t,isl,rg,GenRisk)..
  GENISLANDRISKGROUP(t,isl,rg,resC,GenRisk)
=e=
  riskAdjFactor(t,isl,resC,GenRisk)
  * [ sum[ br $ directionalRiskFactor(t,rg,br,GenRisk)
              , ACBRANCHFLOW(t,br) * directionalRiskFactor(t,rg,br,GenRisk)]

    + sum[ (o,resT) $ { offerIsland(t,o,isl)
                    and riskGroupOffer(t,rg,o,GenRisk)
                      } , RESERVE(t,o,resC,resT)
         ]
    - ACSecondaryRiskGroup(t,rg,GenRisk)
    - FreeReserve(t,isl,resC,GenRisk)
    ]
* NMIR update
- RESERVESHAREEFFECTIVE(t,isl,resC,GenRisk)$reserveShareEnabled(t,resC)
* Scarcity reserve (only applied for CE risk)
- RESERVESHORTFALLGROUP(t,isl,rg,resC,GenRisk) $ ContingentEvents(GenRisk)
  ;

* 6.5.1.12: Calculation of the island risk of link risk group.
AClineRiskGroupCalculation(t,isl,rg,resC,GenRisk)
  $ islandLinkRiskGroup(t,isl,rg,GenRisk)..
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
- (monopoleMinimum(t) + modulationRisk(t))
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
  resrvOfrPct(Offer,blk,resC) * GENERATION(Offer)
  ;

* 6.5.3.3: Cleared IL reserve is constrained by cleared dispatchable demand'
ReserveInterruptibleOfferLimit(t,o,bd,resC,ILRO(resT))
  $ { sameas(o,bd) and offer(t,o) and bid(t,bd) and (sum[blk,demBidMW(t,bd,blk)] >= 0) } ..
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
+ reserveMaxFactor(offer,resC)
  * sum[ resT $ (not ILRO(resT)), RESERVE(offer,resC,resT) ]
=l=
  reserveGenMax(offer)
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
  AClineRiskGroupCalculation, AClineRiskGroupCalculation_1
  ManualIslandRiskCalculation
* Reserve
  PLSRReserveProportionMaximum, ReserveInterruptibleOfferLimit,
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
  AClineRiskGroupCalculation, AClineRiskGroupCalculation_1
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
  AClineRiskGroupCalculation, AClineRiskGroupCalculation_1
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
  AClineRiskGroupCalculation, AClineRiskGroupCalculation_1
  HVDCIslandSecRiskCalculation_GEN, HVDCIslandSecRiskCalculation_GEN_1
  HVDCIslandSecRiskCalculation_Manual, HVDCIslandSecRiskCalculation_Manu_1
* Reserve
  PLSRReserveProportionMaximum, ReserveInterruptibleOfferLimit,
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
