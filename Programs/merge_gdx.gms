$include mergeGDXsettings.inc
$call gdxmerge "%inputPath%\%yyyymmdd%\*.gdx" output = 'tempGDX'

*$ontext
Sets
  isl(*)              'Islands'                                                 / NI, SI /
  blk(*)              'Trade block definitions used for the offer and bids'     / t1*t20 /
  los(*)              'Loss segments available for loss modelling'              / ls1*ls13 /
  fd(*)               'Directional flow definition used in the SPD formulation' / forward, backward /
  resC(*)             'Definition of fast and sustained instantaneous reserve'  / FIR, SIR /
  riskC(*)            'Different risks that could set the reserve requirements' / genRisk, genRiskECE, DCCE, DCECE, manual, manualECE, HVDCsecRisk, HVDCsecRiskECE /
  resT(*)             'Definition of reserve types (PLSR, TWDR, ILR)'           / PLRO, TWRO, ILRO /

  casePar(*)          'Different information about a case and datetime' /studyMode, intervalLength/
  
  dtPar(*)            'The various parameters applied for datetime'     / usegeninitialMW, enrgShortfallTransfer, priceTransfer, replaceSurplusPrice, igIncreaseLimitRTD,
                                                                          useActualLoad, dontScaleNegLoad, maxSolveLoop, shortfallRemovalMargin, enrgScarcity, resrvScarcity,
                                                                          badPriceFactor /

  bidofrCmpnt(*)      'Components of the bid and offer'                 / limitMW, price, plsrPct, factor /
  
  offerPar(*)         'The various parameters required for each offer'  / solvedInitialMW, initialMW, rampUpRate, rampDnRate, resrvGenMax, isIG, FKbandMW, isPriceResponse, potentialMW,
                                                                          riskGenerator, dispatchable, maxFactorFIR, maxFactorSIR /                                                                         
  bidPar(*)           'The various parameters required for each offer'  / dispatchable, discrete, difference /
  
  nodePar(*)          'The various parameters applied for each  node'   / referenceNode, demand, initialLoad, conformingFactor, nonConformingFactor, loadIsOverride, loadIsBad,
                                                                          loadIsNCL, maxLoad, instructedLoadShed, instructedShedActive, dispatchedLoad, dispatchedGeneration /
  islPar(*)           'The various parameters applied for each island'  / HVDCsecRisk, HVDCsecRiskECE, HVDCSecSubtractor, sharedNFRLoadOffset, RMTlimitFIR, RMTlimitSIR,
                                                                          MWIPS, PSD, Losses, SPDLoadCalcLosses/
  resPar(*)           'Parameters applied to reserve class'             / sharingFIR, sharingSIR, roundPwrFIR, roundPwrSIR, roundPwr2Mono, biPole2Mono, monoPoleMin,
                                                                          MRCE, MRECE, lossScalingFactorHVDC, sharedNFRfactor,forwardHVDCcontrolBand, backwardHVDCcontrolBand /
  riskPar(*)          'Different risk parameters'                       / freeReserve, adjustFactor, HVDCRampUp, minRisk, sharingEffectiveFactor /
  
  brPar(*)            'Branch parameter specified'                      / forwardCap, backwardCap, resistance, susceptance, fixedLosses, numLossTranches, HVDCbranch, isOpen /
  
  CstrRHS(*)          'Constraint RHS definition'                       / cnstrSense, cnstrLimit, rampingCnstr /
  ;

* Dynamic sets that are defined by /loaded from gdx inputs
Sets
  gdxName(*)          'Name of Gdx that isued as additinal dimension in merged GDX'
  caseName(*)         'Case name used to create the GDX file'
  i_caseID(*)         'Case ID associated with data'
  i_dateTime(*)       'Date and time for the trade periods'
  i_tradePeriod(*)    'Trade periods for which input data is defined'
  i_bus(*)            'Bus definitions for all trading periods'
  i_node(*)           'Node definitions for all trading periods'
  i_offer(*)          'Offers for all trading periods'
  i_bid(*)            'Bids for all trading periods'
  i_trader(*)         'Traders defined for all trading periods'
  i_branch(*)         'Branch definition for all trading periods'
  i_branchConstraint(*)      'Branch constraint definitions for all trading periods'
  i_MnodeConstraint(*)       'Market node constraint definitions for all trading periods'
  i_riskGroup(*)             'Set representing a collection of generation and reserve offers treated as a group risk'
  i_runDateTime(*)           'Run datetime of the case for reporting'
  ;

* Aliases
Alias (i_caseID,ca,ca1),  (i_dateTime,dt,dt1,dt2),       (i_tradePeriod,tp,tp1,tp2),
      (i_bus,b,b1,b2),    (i_node,n,n1,n2),              (i_offer,o,o1,o2),        
      (i_trader,trdr),    (i_branch,br,br1),             (i_branchConstraint,brCstr),
      (i_riskGroup,rg),   (i_runDateTime,rundt),         (i_MnodeConstraint,MnodeCstr),
      (gdxName,gn,gn1),   (caseName,cn,cn1),  (i_bid,bd,bd2,bd1),            (i_trader,trdr)
      
  ;
  
$onMulti

Parameter priceCaseFilesPublishedSecs(ca<,tp<)          'Time Weight Seconds apply to case file for final pricing calculation ' 
/
$include 'pricing_case_files.inc'
/;

* Declare sets and parameters that are loaded/exported from/to merged/output file
Parameter gdxDate(gn<,*)                                'day, month, year of trade date of gdx file' ;
Parameter i_gdxDate(*)                                  'day, month, year of trade date of gdx file';

Set caseDefn(gn,ca,cn<,rundt<)                          'caseID-caseName-runDateTime mapping' ;
Set i_caseDefn(ca,cn,rundt)                             'caseID-caseName-runDateTime mapping' ;

Parameter runMode(gn,ca,casePar)                        'Study mode and interval length applied to each caseID' ;
Parameter i_runMode(ca,casePar)                         'Study mode and interval length applied to each caseID' ;

Set dateTimeTradePeriodMap(gn,ca,dt<,tp)                'Interval - Trading period mapping' ;
Set i_dateTimeTradePeriodMap(ca,dt,tp)                  'Interval - Trading period mapping' ;

Parameter dateTimeParameter(gn,ca,dt,dtPar)             'Parameters applied to each caseID-dateTime pair' ;
Parameter i_dateTimeParameter(ca,dt,dtPar)              'Parameters applied to each caseID-datetime pair' ;

Parameter dateTimeIslandParameter(gn,ca,dt,isl,islPar)  'Island parameters applied to each caseID-dateTime pair' ;
Parameter i_dateTimeIslandParameter(ca,dt,isl,islPar)   'Island parameters applied to each caseID-dateTime pair' ;

Set node(gn,n<)                                         'Pnode name' ;

Set dateTimeNodeToNode(gn,ca,dt,n,n1)                   'Node to node mapping for shortage and price transfer' ;
Set i_dateTimeNodetoNode(ca,dt,n,n1)                    'Node to node mapping for shortage and price transfer' ;

Parameter dateTimeNodeParameter(gn,ca,dt,n,nodePar)     'Nodal parameters' ;
Parameter i_dateTimeNodeParameter(ca,dt,n,nodePar)      'Nodal parameters' ;

Set bus(gn,b<)                                          'Bus ID' ;

Set dateTimeBusIsland(gn,ca,dt,b,isl)                   'Valid bus-island mapping for each Interval' ;
Set i_dateTimeBusIsland(ca,dt,b,isl)                    'Valid bus-island mapping for each Interval' ;

Parameter dateTimeBusElectricalIsland(gn,ca,dt,b)       'Electrical island of a bus' ;
Parameter i_dateTimeBusElectricalIsland(ca,dt,b)        'Electrical island of a bus' ;

Set dateTimeNodeBus(gn,ca,dt,n,b)                       'Node-Bus mapping by interval' ;
Set i_dateTimeNodeBus(ca,dt,n,b)                        'Node-Bus mapping by interval' ;

Parameter dateTimeNodeBusAllocationFactor(gn,ca,dt,n,b) 'Node-Bus allocation factors' ;
Parameter i_dateTimeNodeBusAllocationFactor(ca,dt,n,b)  'Node-Bus allocation factors' ;

Set dateTimeBranchDefn(gn,ca,dt,br<,b1,b2)              'AC/DC Branches connectivity definition' ;
Set i_dateTimeBranchDefn(ca,dt,br,b1,b2)                'AC/DC Branches connectivity definition' ;

Set dateTimeNodeOutageBranch(gn,ca,dt,n,br)             'Set to check if a Node is Linked to a Branch' ;
Set i_dateTimeNodeOutageBranch(ca,dt,n,br)              'Set to check if a Node is Linked to a Branch' ;

Parameter dateTimeBranchParameter(gn,ca,dt,br,brPar)             'Branch parameters' ;
Parameter i_dateTimeBranchParameter(ca,dt,br,brPar)              'Branch parameters' ;

Parameter dateTimeBranchConstraintRHS(gn,ca,dt,brCstr<,CstrRHS)  'Branch group contraint RHS parameters' ;
Parameter i_dateTimeBranchConstraintRHS(ca,dt,brCstr,CstrRHS)    'Branch group contraint RHS parameters' ;

Parameter dateTimeBranchConstraintFactors(gn,ca,dt,brCstr,br)    'Branch factor of branch group contraint' ;
Parameter i_dateTimeBranchConstraintFactors(ca,dt,brCstr,br)     'Branch factor of branch group contraint' ;

Set dateTimeOfferNode(gn,ca,dt,o<,n)                                 'Mapping offer to node' ;
Set i_dateTimeOfferNode(ca,dt,o,n)                                   'Mapping offer to node' ;

Set dateTimeOfferTrader(gn,ca,dt,o,trdr<)                            'Mapping offer to trader' ;
Set i_dateTimeOfferTrader(ca,dt,o,trdr)                              'Mapping offer to trader' ;

Set dateTimePrimarySecondaryOffer(gn,ca,dt,o,o1)                     'Mapping secondary off to primary offer' ;
Set i_dateTimePrimarySecondaryOffer(ca,dt,o,o1)                      'Mapping secondary off to primary offer' ;

Parameter dateTimeOfferParameter(gn,ca,dt,o,offerPar)                'Generation offer parameters' ;
Parameter i_dateTimeOfferParameter(ca,dt,o,offerPar)                 'Generation offer parameters' ;

Set dateTimeRiskGroup(gn,ca,dt,rg<,o,riskC)                          'Mapping risk group - generation offer' ;
Set i_dateTimeRiskGroup(ca,dt,rg,o,riskC)                            'Mapping risk group - generation offer' ;

Parameter dateTimeRiskGroupBranch(gn,ca,dt,rg,br,riskC)              'Mapping risk group - directional branch' ;
Parameter i_dateTimeRiskGroupBranch(ca,dt,rg,br,riskC)               'Mapping risk group - directional branch' ;

Parameter dateTimeEnergyOffer(gn,ca,dt,o,blk,bidofrCmpnt)            'Generation offer quantity and price' ;
Parameter i_dateTimeEnergyOffer(ca,dt,o,blk,bidofrCmpnt)             'Generation offer quantity and price' ;

Parameter dateTimeReserveOffer(gn,ca,dt,o,resC,resT,blk,bidofrCmpnt) 'Reserve offer quantity and price' ;
Parameter i_dateTimeReserveOffer(ca,dt,o,resC,resT,blk,bidofrCmpnt)  'Reserve offer quantity and price' ;

Set dateTimeBidNode(gn,ca,dt,bd<,n)                        'Mapping energy bids to nodes' ;
Set i_dateTimeBidNode(ca,dt,bd,n)                          'Mapping energy bids to nodes' ;

Set dateTimeBidTrader(gn,ca,dt,bd,trdr<)                   'Mapping energy bids to traders' ;
Set i_dateTimeBidTrader(ca,dt,bd,trdr)                     'Mapping energy bids to traders' ;

Parameter dateTimeBidParameter(gn,ca,dt,bd,bidPar)         'Mapping energy bids to traders' ;
Parameter i_dateTimeBidParameter(ca,dt,bd,bidPar)          'Mapping energy bids to traders' ;

Parameter dateTimeEnergyBid(gn,ca,dt,bd,blk,bidofrCmpnt)   'Demand bid quantity and price' ;
Parameter i_dateTimeEnergyBid(ca,dt,bd,blk,bidofrCmpnt)    'Demand bid quantity and price' ;

Parameter dateTimeMNCnstrRHS(gn,ca,dt,MnodeCstr<,CstrRHS)             'Limit and Sense of market node constraint' ;
Parameter i_dateTimeMNCnstrRHS(ca,dt,MnodeCstr,CstrRHS)               'Limit and Sense of market node constraint' ;

Parameter dateTimeMNCnstrEnrgFactors(gn,ca,dt,MnodeCstr,o)            'Energy factor of market node constraint' ;
Parameter i_dateTimeMNCnstrEnrgFactors(ca,dt,MnodeCstr,o)             'Energy factor of market node constraint' ;

Parameter dateTimeMNCnstrResrvFactors(gn,ca,dt,MnodeCstr,o,resC,resT) 'Reserve factor of market node constraint' ;
Parameter i_dateTimeMNCnstrResrvFactors(ca,dt,MnodeCstr,o,resC,resT)  'Reserve factor of market node constraint' ;

Parameter dateTimeMNCnstrEnrgBidFactors(gn,ca,dt,MnodeCstr,bd)        'Energy bid factor of market node constraint' ;
Parameter i_dateTimeMNCnstrEnrgBidFactors(ca,dt,MnodeCstr,bd)         'Energy bid factor of market node constraint' ;

Parameter dateTimeMNCnstrResrvBidFactors(gn,ca,dt,MnodeCstr,bd,resC)  'Reserve factor of a bid for market node constraint' ;
Parameter i_dateTimeMNCnstrResrvBidFactors(ca,dt,MnodeCstr,bd,resC)   'Reserve factor of a bid for market node constraint' ;

Parameter dateTimeRiskParameter(gn,ca,dt,isl,resC,riskC,riskPar) 'Risk parameters' ;
Parameter i_dateTimeRiskParameter(ca,dt,isl,resC,riskC,riskPar)  'Risk parameters' ;

Parameter dateTimeReserveSharing(gn,ca,dt,resPar)                'Reserve (sharing) parameters' ;
Parameter i_dateTimeReserveSharing(ca,dt,resPar)                 'Reserve (sharing) parameters' ;

Parameter dateTimeScarcityNationalFactor(gn,ca,dt,blk,bidofrCmpnt)      'National energy scarcity parameters' ;
Parameter i_dateTimeScarcityNationalFactor(ca,dt,blk,bidofrCmpnt)       'National energy scarcity parameters' ;

Parameter dateTimeScarcityResrvLimit(gn,ca,dt,isl,resC,blk,bidofrCmpnt) 'Island limit MW for reserve scarcity' ;
Parameter i_dateTimeScarcityResrvLimit(ca,dt,isl,resC,blk,bidofrCmpnt)  'Island limit MW for reserve scarcity' ;

Parameter dateTimeScarcityNodeFactor(gn,ca,dt,n,blk,bidofrCmpnt)        'Nodal energy scarcity factor parameters' ;
Parameter i_dateTimeScarcityNodeFactor(ca,dt,n,blk,bidofrCmpnt)         'Nodal energy scarcity factor parameters'
  
Parameter dateTimeScarcityNodeLimit(gn,ca,dt,n,blk,bidofrCmpnt)         'Nodal energy scarcity limit parameters' ;
Parameter i_dateTimeScarcityNodeLimit(ca,dt,n,blk,bidofrCmpnt)          'Nodal energy scarcity limit parameters' ;


*Load the input data form merged GDX file

$gdxin "tempGDX.gdx"
$load gdxDate = i_gdxDate  caseDefn = i_caseDefn runMode = i_runMode
$load dateTimeTradePeriodMap = i_dateTimeTradePeriodMap dateTimeParameter = i_dateTimeParameter  dateTimeIslandParameter = i_dateTimeIslandParameter
$load node = i_node  dateTimeNodeToNode = i_dateTimeNodetoNode   dateTimeNodeParameter = i_dateTimeNodeParameter
$load bus = i_bus  dateTimeBusIsland = i_dateTimeBusIsland  dateTimeBusElectricalIsland = i_dateTimeBusElectricalIsland
$load dateTimeNodeBus = i_dateTimeNodeBus  dateTimeNodeBusAllocationFactor = i_dateTimeNodeBusAllocationFactor
$load dateTimeBranchDefn = i_dateTimeBranchDefn  dateTimeNodeOutageBranch = i_dateTimeNodeOutageBranch  dateTimeBranchParameter = i_dateTimeBranchParameter
$load dateTimeBranchConstraintRHS = i_dateTimeBranchConstraintRHS  dateTimeBranchConstraintFactors = i_dateTimeBranchConstraintFactors
$load dateTimeOfferNode = i_dateTimeOfferNode  dateTimeOfferTrader = i_dateTimeOfferTrader
$load dateTimePrimarySecondaryOffer = i_dateTimePrimarySecondaryOffer   dateTimeOfferParameter = i_dateTimeOfferParameter
$load dateTimeRiskGroup = i_dateTimeRiskGroup  dateTimeRiskGroupBranch = i_dateTimeRiskGroupBranch  dateTimeEnergyOffer = i_dateTimeEnergyOffer  dateTimeReserveOffer =  i_dateTimeReserveOffer
$load dateTimeBidNode = i_dateTimeBidNode  dateTimeBidTrader = i_dateTimeBidTrader  dateTimeBidParameter = i_dateTimeBidParameter  dateTimeEnergyBid = i_dateTimeEnergyBid
$load dateTimeMNCnstrRHS = i_dateTimeMNCnstrRHS  dateTimeMNCnstrEnrgFactors = i_dateTimeMNCnstrEnrgFactors  dateTimeMNCnstrResrvFactors = i_dateTimeMNCnstrResrvFactors
$load dateTimeMNCnstrEnrgBidFactors = i_dateTimeMNCnstrEnrgBidFactors  dateTimeMNCnstrResrvBidFactors = i_dateTimeMNCnstrResrvBidFactors
$load dateTimeRiskParameter = i_dateTimeRiskParameter  dateTimeReserveSharing = i_dateTimeReserveSharing
$load dateTimeScarcityNationalFactor = i_dateTimeScarcityNationalFactor
$load dateTimeScarcityResrvLimit = i_dateTimeScarcityResrvLimit
$load dateTimeScarcityNodeFactor = i_dateTimeScarcityNodeFactor
$load dateTimeScarcityNodeLimit = i_dateTimeScarcityNodeLimit
$gdxin
$offMulti

*$ontext
* Process data to export
i_gdxdate('day')   = smin[ (gn,ca) $ {runMode(gn,ca,'studyMode') = 101} , gdxDate(gn,'day') ] ;
i_gdxdate('month') = smin[ (gn,ca) $ {runMode(gn,ca,'studyMode') = 101} , gdxDate(gn,'month') ] ;
i_gdxdate('year')  = smin[ (gn,ca) $ {runMode(gn,ca,'studyMode') = 101} , gdxDate(gn,'year') ] ;

i_caseDefn(ca,cn,rundt) = yes $ sum[gn $ caseDefn(gn,ca,cn,rundt), 1] ;

i_runMode(ca,casePar) = sum[ gn, runMode(gn,ca,casePar)] ;

i_dateTimeTradePeriodMap(ca,dt,tp)  =  yes $ sum[gn $ { dateTimeTradePeriodMap(gn,ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, 1] ;

i_dateTimeParameter(ca,dt,dtPar) = sum [ (gn,tp) $ { i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeParameter(gn,ca,dt,dtPar)] ; 

i_dateTimeIslandParameter(ca,dt,isl,islPar) = sum[ (gn,tp) $ { i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeIslandParameter(gn,ca,dt,isl,islPar)] ;

i_dateTimeNodetoNode(ca,dt,n,n1) = yes $ sum[(gn,tp) $ { i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) and dateTimeNodeToNode(gn,ca,dt,n,n1) }, 1] ;

i_dateTimeNodeParameter(ca,dt,n,nodePar) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeNodeParameter(gn,ca,dt,n,nodePar)] ;

i_dateTimeBusIsland(ca,dt,b,isl) = yes $ sum[ (gn,tp) $ { i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) and dateTimeBusIsland(gn,ca,dt,b,isl) }, 1] ;

i_dateTimeBusElectricalIsland(ca,dt,b) = sum[ (gn,tp) $ { i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeBusElectricalIsland(gn,ca,dt,b)] ;
 
i_dateTimeNodeBus(ca,dt,n,b) = yes $ sum[ (gn,tp) $ { i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) and dateTimeNodeBus(gn,ca,dt,n,b) }, 1] ;

i_dateTimeNodeBusAllocationFactor(ca,dt,n,b) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeNodeBusAllocationFactor(gn,ca,dt,n,b)] ;

i_dateTimeBranchDefn(ca,dt,br,b1,b2) = yes $ sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) and dateTimeBranchDefn(gn,ca,dt,br,b1,b2) }, 1] ;

i_dateTimeNodeOutageBranch(ca,dt,n,br) = yes $ sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) and dateTimeNodeOutageBranch(gn,ca,dt,n,br) }, 1] ;

i_dateTimeBranchParameter(ca,dt,br,brPar) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeBranchParameter(gn,ca,dt,br,brPar)] ;

i_dateTimeBranchConstraintRHS(ca,dt,brCstr,CstrRHS) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeBranchConstraintRHS(gn,ca,dt,brCstr,CstrRHS)] ;

i_dateTimeBranchConstraintFactors(ca,dt,brCstr,br) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeBranchConstraintFactors(gn,ca,dt,brCstr,br)] ;

i_dateTimeOfferNode(ca,dt,o,n) = yes $ sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) and dateTimeOfferNode(gn,ca,dt,o,n) }, 1 ] ;

i_dateTimeOfferTrader(ca,dt,o,trdr) = yes $ sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) and dateTimeOfferTrader(gn,ca,dt,o,trdr) }, 1] ;

i_dateTimePrimarySecondaryOffer(ca,dt,o,o1) = yes $ sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) and dateTimePrimarySecondaryOffer(gn,ca,dt,o,o1) }, 1] ;

i_dateTimeOfferParameter(ca,dt,o,offerPar) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeOfferParameter(gn,ca,dt,o,offerPar)] ;

i_dateTimeRiskGroup(ca,dt,rg,o,riskC) = yes $ sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) and dateTimeRiskGroup(gn,ca,dt,rg,o,riskC) }, 1] ;

i_dateTimeRiskGroupBranch(ca,dt,rg,br,riskC) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeRiskGroupBranch(gn,ca,dt,rg,br,riskC)] ;

i_dateTimeEnergyOffer(ca,dt,o,blk,bidofrCmpnt) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeEnergyOffer(gn,ca,dt,o,blk,bidofrCmpnt)] ;

i_dateTimeReserveOffer(ca,dt,o,resC,resT,blk,bidofrCmpnt) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeReserveOffer(gn,ca,dt,o,resC,resT,blk,bidofrCmpnt)] ;

i_dateTimeBidNode(ca,dt,bd,n) = yes $ sum [gn $ dateTimeBidNode(gn,ca,dt,bd,n), 1] ;

i_dateTimeBidTrader(ca,dt,bd,trdr) = yes $ sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) and dateTimeBidTrader(gn,ca,dt,bd,trdr) }, 1] ;

i_dateTimeBidParameter(ca,dt,bd,bidPar) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeBidParameter(gn,ca,dt,bd,bidPar)] ;

i_dateTimeEnergyBid(ca,dt,bd,blk,bidofrCmpnt) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeEnergyBid(gn,ca,dt,bd,blk,bidofrCmpnt)] ;

i_dateTimeMNCnstrRHS(ca,dt,MnodeCstr,CstrRHS) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeMNCnstrRHS(gn,ca,dt,MnodeCstr,CstrRHS)] ;

i_dateTimeMNCnstrEnrgFactors(ca,dt,MnodeCstr,o) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeMNCnstrEnrgFactors(gn,ca,dt,MnodeCstr,o)] ;

i_dateTimeMNCnstrResrvFactors(ca,dt,MnodeCstr,o,resC,resT) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeMNCnstrResrvFactors(gn,ca,dt,MnodeCstr,o,resC,resT)] ;

i_dateTimeMNCnstrEnrgBidFactors(ca,dt,MnodeCstr,bd) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeMNCnstrEnrgBidFactors(gn,ca,dt,MnodeCstr,bd)] ;

i_dateTimeMNCnstrResrvBidFactors(ca,dt,MnodeCstr,bd,resC) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeMNCnstrResrvBidFactors(gn,ca,dt,MnodeCstr,bd,resC)] ;

i_dateTimeRiskParameter(ca,dt,isl,resC,riskC,riskPar) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeRiskParameter(gn,ca,dt,isl,resC,riskC,riskPar)] ;

i_dateTimeReserveSharing(ca,dt,resPar) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeReserveSharing(gn,ca,dt,resPar)] ;

i_dateTimeScarcityNationalFactor(ca,dt,blk,bidofrCmpnt) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeScarcityNationalFactor(gn,ca,dt,blk,bidofrCmpnt)] ;

i_dateTimeScarcityResrvLimit(ca,dt,isl,resC,blk,bidofrCmpnt) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeScarcityResrvLimit(gn,ca,dt,isl,resC,blk,bidofrCmpnt)] ;

i_dateTimeScarcityNodeFactor(ca,dt,n,blk,bidofrCmpnt) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeScarcityNodeFactor(gn,ca,dt,n,blk,bidofrCmpnt)] ;
  
i_dateTimeScarcityNodeLimit(ca,dt,n,blk,bidofrCmpnt) = sum[ (gn,tp) $ {i_dateTimeTradePeriodMap(ca,dt,tp) and priceCaseFilesPublishedSecs(ca,tp) }, dateTimeScarcityNodeLimit(gn,ca,dt,n,blk,bidofrCmpnt)] ;
  
    
execute_unload "%inputPath%\Pricing_%yyyymmdd%.gdx"
    i_gdxDate, i_caseDefn, i_runMode
    i_dateTimeTradePeriodMap, i_dateTimeParameter, i_dateTimeIslandParameter
    i_node,i_dateTimeNodetoNode, i_dateTimeNodeParameter
    i_bus, i_dateTimeBusIsland, i_dateTimeBusElectricalIsland
    i_dateTimeNodeBus, i_dateTimeNodeBusAllocationFactor
    i_dateTimeBranchDefn, i_dateTimeNodeOutageBranch, i_dateTimeBranchParameter
    i_dateTimeBranchConstraintRHS, i_dateTimeBranchConstraintFactors
    i_dateTimeOfferNode, i_dateTimeOfferTrader, i_dateTimePrimarySecondaryOffer, i_dateTimeOfferParameter
    i_dateTimeRiskGroup, i_dateTimeRiskGroupBranch, i_dateTimeEnergyOffer, i_dateTimeReserveOffer
    i_dateTimeBidNode, i_dateTimeBidTrader, i_dateTimeBidParameter, i_dateTimeEnergyBid
    i_dateTimeMNCnstrRHS, i_dateTimeMNCnstrEnrgFactors, i_dateTimeMNCnstrResrvFactors
    i_dateTimeMNCnstrEnrgBidFactors, i_dateTimeMNCnstrResrvBidFactors
    i_dateTimeRiskParameter, i_dateTimeReserveSharing
    i_dateTimeScarcityNationalFactor, i_dateTimeScarcityResrvLimit
    i_dateTimeScarcityNodeFactor, i_dateTimeScarcityNodeLimit
    priceCaseFilesPublishedSecs = i_priceCaseFilesPublishedSecs
;

*$offtext
*execute_unload 'tempAll.gdx';
