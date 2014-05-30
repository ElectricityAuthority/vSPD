*=====================================================================================
* Name:                 vSPDoverrides.gms
* Function:             Code to be included in vSPDsolve to take care of input data
*                       overrides.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     30 May 2014
*=====================================================================================

$ontext
This code is included into vSPDsolve.gms unless suppressOverrides in vSPDpaths.inc is set equal to 1.
The procedure for introducing data overrides depends on the user interface mode. The $setglobal called
interfaceMode is used to control the process of introducing data overrides.
interfaceMode: a value of zero implies the EMI interface, a 1 implies the Excel interface; and all other
values imply standalone interface mode (although ideally users should set it equal to 2 for standalone).
All override data symbols are the same as the names of the symbols being overridden, except that they have
the characters 'Ovrd' appended to the original symbol name. After declaring the override symbols, the override
data is installed and the original symbols are overwritten. Note that the Excel interface permits a very
limited number of input data symbols to be overridden. The EMI interface will create a GDX file of override
values for all data inputs to be overridden. If operating in standalone mode, overrides can be installed by
any means the user prefers - GDX file, $include file, hard-coding, etc. But it probably makes sense to mimic
the GDX file as used by EMI.

Directory of code sections in vSPDoverrides.gms:
  1. Excel interface - declare and initialise overrides
  2. EMI tools and Standalone interface - declare override symbols
     a) Install new set elements from vSPDnewElements.inc, if any exist
     b) Declare override symbols to be loaded from override GDX
        i)  Offers - incl. energy, PLSR, TWDR, and ILR
        ii) Demand
     c) Declare more override symbols - to be initialised within this program


  x. Initialise new data instances based on new set elements in override file
  x. Initialise override symbols
     a) Offer parameters
     b) Energy offers
     c) PLSR offers
     d) TWDR offers
     e) ILR offers
     f) Demand overrides

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


*=========================================================================================================================
* 1. Excel interface - declare and initialise overrides
*=========================================================================================================================

$if not %interfaceMode%==1 $goto endOverridesWithExcel

Parameters
  i_energyOfferOvrd(tp,i_offer,trdBlk,NRGofrCmpnt)  'Override for energy offers for specified trade period'
  i_offerParamOvrd(tp,i_offer,i_offerParam)         'Override for energy offer parameters for specified trade period'
  i_nodeDemandOvrd(tp,n)                            'Override MW nodal demand for specified trade period'
  i_islandDemandOvrd(tp,ild)                        'Scaling factor for island demand for specified trade period'
  tradePeriodNodeDemandTemp(tp,n)                   'Temporary trade period node demand for use in override calculations using i_islandDemandOvrd'
  ;
$onecho > overridesFromExcel.ins
  par = i_energyOfferOvrd       rng = i_energyOfferOvrd       rdim = 4
  par = i_offerParamOvrd        rng = i_offerParamOvrd        rdim = 3
  par = i_nodeDemandOvrd        rng = i_nodeDemandOvrd        rdim = 2
  par = i_islandDemandOvrd      rng = i_islandDemandOvrd      rdim = 2
$offecho

* Update the override path and file name for the xls overrides
$call 'gdxxrw "%programPath%\%vSPDinputFileName%.xls" o=%ovrdPath%\overridesFromExcel.gdx "@overridesFromExcel.ins"'
$gdxin "%ovrdPath%\overridesFromExcel"
$load i_energyOfferOvrd i_offerParamOvrd i_nodeDemandOvrd i_islandDemandOvrd
$gdxin

* Island demand overrides
tradePeriodNodeDemandTemp(tp,n) = 0 ;
tradePeriodNodeDemandTemp(tp,n) = i_tradePeriodNodeDemand(tp,n) ;

* Apply island scaling factor to a node if scaling factor > 0 and the node demand > 0
i_tradePeriodNodeDemand(tp,n) $ { ( tradePeriodNodeDemandTemp(tp,n) > 0 ) and
                                  ( sum[ (b,ild) $ { i_tradePeriodNodeBus(tp,n,b) and
                                                     i_tradePeriodBusIsland(tp,b,ild)
                                                   }, i_islandDemandOvrd(tp,ild)
                                       ] > 0
                                   )
                                }
    = sum[ (b,ild) $ { i_tradePeriodNodeBus(tp,n,b) and
                       i_tradePeriodBusIsland(tp,b,ild)
                     }, i_tradePeriodNodeBusAllocationFactor(tp,n,b)
                      * i_islandDemandOvrd(tp,ild)
                      * tradePeriodNodeDemandTemp(tp,n)
         ] ;

* Apply island scaling factor to a node if scaling factor = eps (0) and the node demand > 0
i_tradePeriodNodeDemand(tp,n) $ { ( tradePeriodNodeDemandTemp(tp,n) > 0 ) and
                                    ( sum[ (b,ild) $ { i_tradePeriodNodeBus(tp,n,b) and
                                                       i_tradePeriodBusIsland(tp,b,ild) and
                                                       i_islandDemandOvrd(tp,ild) and
                                                       ( i_islandDemandOvrd(tp,ild) = eps )
                                                     }, 1
                                         ] > 0 )
                                }
    = 0 ;

* Node demand overrides
i_tradePeriodNodeDemand(tp,n)$i_nodeDemandOvrd(tp,n) = i_nodeDemandOvrd(tp,n) ;
i_tradePeriodNodeDemand(tp,n)$( i_nodeDemandOvrd(tp,n) * ( i_nodeDemandOvrd(tp,n) = eps ) ) = 0 ;

* Energy offer overrides
i_tradePeriodEnergyOffer(tp,i_offer,trdBlk,NRGofrCmpnt)$( i_energyOfferOvrd(tp,i_offer,trdBlk,NRGofrCmpnt) > 0 )
  = i_energyOfferOvrd(tp,i_offer,trdBlk,NRGofrCmpnt) ;
i_tradePeriodEnergyOffer(tp,i_offer,trdBlk,NRGofrCmpnt)$
  ( i_energyOfferOvrd(tp,i_offer,trdBlk,NRGofrCmpnt) * ( i_energyOfferOvrd(tp,i_offer,trdBlk,NRGofrCmpnt) = eps ) )
   = 0 ;

* Offer parameter overrides
i_tradePeriodOfferParameter(tp,i_offer,i_offerParam)$( i_offerParamOvrd(tp,i_offer,i_offerParam) > 0 ) = i_offerParamOvrd(tp,i_offer,i_offerParam) ;
i_tradePeriodOfferParameter(tp,i_offer,i_offerParam)${ i_offerParamOvrd(tp,i_offer,i_offerParam) and
                                                       ( i_offerParamOvrd(tp,i_offer,i_offerParam) = eps ) } = 0 ;

$goto theEnd
$label endOverridesWithExcel



*=========================================================================================================================
* 2. EMI tools and Standalone interface - declare override symbols
*=========================================================================================================================
$if %interfaceMode%==1 $goto endEMIandStandaloneOverrides
* Declare override symbols to be used for both EMI tools and standalone interface types
* NB: The following declarations are not skipped if in Excel interface mode - no harm is done by declaring symbols and then never using them.


* a) Install new set elements from vSPDnewElements.inc, if any exist
$if exist vSPDnewElements.inc $include vSPDnewElements.inc


* b) Declare override symbols to be loaded from override GDX

* i) Offers - incl. energy, PLSR, TWDR, and ILR
Sets
  new_offer(o)                                                   'New offer elements'
  new_offerNode(o,n)                                             'Mapping of new offers to nodes'
  new_offerTrader(o,trdr)                                        'Mapping of new offers to traders'
  new_offerRiskSetter(o)                                         'Flag to indicate if new offers are the risk setter'
  new_offerInherit(o,o1)                                         'New offer to inherit data from existing offer'
  new_offerDate(o,fromTo,day,mth,yr)                             'Applicable dates for the new offer'
  ovrd_offerParamDate(ovrd,o,fromTo,day,mth,yr)                  'Offer parameter override dates'
  ovrd_offerParamTP(ovrd,o,tp)                                   'Offer parameter override trade periods'
  ovrd_energyOfferDate(ovrd,o,fromTo,day,mth,yr)                 'Energy offer override dates'
  ovrd_energyOfferTP(ovrd,o,tp)                                  'Energy offer override trade periods'
  ovrd_PLSRofferDate(ovrd,o,fromTo,day,mth,yr)                   'PLSR offer override dates'
  ovrd_PLSRofferTP(ovrd,o,tp)                                    'PLSR offer override trade periods'
  ovrd_TWDRofferDate(ovrd,o,fromTo,day,mth,yr)                   'TWDR offer override dates'
  ovrd_TWDRofferTP(ovrd,o,tp)                                    'TWDR offer override trade periods'
  ovrd_ILRofferDate(ovrd,o,fromTo,day,mth,yr)                    'ILR offer override dates'
  ovrd_ILRofferTP(ovrd,o,tp)                                     'ILR offer override trade periods'

Parameters
  ovrd_offerParam(ovrd,o,i_offerParam)                           'Offer parameter override values'
  ovrd_energyOffer(ovrd,o,trdBlk,NRGofrCmpnt)                    'Energy offer override values'
  ovrd_PLSRoffer(ovrd,i_reserveClass,o,trdBlk,PLSofrCmpnt)       'PLSR offer override values'
  ovrd_TWDRoffer(ovrd,i_reserveClass,o,trdBlk,TWDofrCmpnt)       'TWDR offer override values'
  ovrd_ILRoffer(ovrd,i_reserveClass,o,trdBlk,ILofrCmpnt)         'ILR offer override values'
  ;

*new_offer('offer_x') = yes ;
*new_offerNode('offer_x','HLY2201') = yes ;
*new_offerTrader('offer_x','38459') = yes ;
*new_offerRiskSetter('offer_x') = no ;
*new_offerInherit('offer_x','HLY2201 HLY5') = yes ;
*new_offerDate('offer_x','frm','20','10','2013') = yes ;
*new_offerDate('offer_x','to','20','10','2013') = yes ;
*execute_unload 'newOffer.gdx', new_offer new_offerNode new_offerTrader new_offerRiskSetter new_offerInherit new_offerDate new_offerDate



* ii) Demand


* c) Declare more override symbols - to be initialised within this program
Parameters
  newOfferDay(new_offer,fromTo)                                  'New offer override from/to day'
  newOfferMonth(new_offer,fromTo)                                'New offer override from/to month'
  newOfferYear(new_offer,fromTo)                                 'New offer override from/to year'
  newOfferGDate(new_offer,fromTo)                                'New offer override from/to Gregorian date'

  ovrdOfferDay(ovrd,o,fromTo)                                    'Offer override from/to day'
  ovrdOfferMonth(ovrd,o,fromTo)                                  'Offer override from/to month'
  ovrdOfferYear(ovrd,o,fromTo)                                   'Offer override from/to year'
  ovrdOfferGDate(ovrd,o,fromTo)                                  'Offer override from/to Gregorian date'
  ovrdOfferParamTP(tp,o,i_offerParam)                            'Offer parameter override values by applicable trade periods'
  ovrdEnergyOfferTP(tp,o,trdBlk,NRGofrCmpnt)                     'Energy offer override values by applicable trade periods'
  ovrdPLSRofferTP(tp,i_reserveClass,o,trdBlk,PLSofrCmpnt)        'PLSR offer override values by applicable trade periods'
  ovrdTWDRofferTP(tp,i_reserveClass,o,trdBlk,TWDofrCmpnt)        'TWDR offer override values by applicable trade periods'
  ovrdILRofferTP(tp,i_reserveClass,o,trdBlk,ILofrCmpnt)          'ILR offer override values by applicable trade periods'
  ;



$ontext
Sets
* Demand overrides
  i_islandDemandOvrdDate(ovrd,ild,i_dayNum,i_monthNum,i_yearNum) 'Island demand override date'
  i_islandDemandOvrdTP(ovrd,ild,tp)                              'Island demand override trade period'
  i_nodeDemandOvrdDate(ovrd,n,i_dayNum,i_monthNum,i_yearNum)     'Node demand override date'
  i_nodeDemandOvrdTP(ovrd,n,tp)                                  'Node demand override trade period'
* Branch overrides
  i_branchParamOvrdDate(ovrd,br,fromTo,day,mth,yr)               'Branch parameter override date'
  i_branchParamOvrdTP(ovrd,br,tp)                                'Branch parameter override trade period'
  i_branchCapacityOvrdDate(ovrd,br,fromTo,day,mth,yr)            'Branch capacity override date'
  i_branchCapacityOvrdTP(ovrd,br,tp)                               'Branch capacity override trade period'
  i_branchOpenStatusOvrdDate(ovrd,br,fromTo,day,mth,yr)                 'Branch open status override date'
  i_branchOpenStatusOvrdTP(ovrd,br,tp)                             'Branch open status override trade period'
* Branch security constraint overrides
  i_branchConstraintFactorOvrdDate(ovrd,brCstr,br,fromTo,day,mth,yr)    'Branch constraint factor override date'
  i_branchConstraintFactorOvrdTP(ovrd,brCstr,br,tp)                'Branch constraint factor override trade period'
  i_branchConstraintRHSOvrdDate(ovrd,brCstr,fromTo,day,mth,yr)                'Branch constraint RHS override date'
  i_branchConstraintRHSOvrdTP(ovrd,brCstr,tp)                            'Branch constraint RHS override trade period'
* Market node constraint overrides
  i_MnodeEnergyConstraintFactorOvrdDate(ovrd,MnodeCstr,o,fromTo,day,mth,yr) 'Market node energy constraint factor override date'
  i_MnodeEnergyConstraintFactorOvrdTP(ovrd,MnodeCstr,o,tp)             'Market node energy constraint factor override trade period'
  i_MnodeReserveConstraintFactorOvrdDate(ovrd,MnodeCstr,o,i_reserveClass,fromTo,day,mth,yr) 'Market node reserve constraint factor override date'
  i_MnodeReserveConstraintFactorOvrdTP(ovrd,MnodeCstr,o,i_reserveClass,tp)             'Market node reserve constraint factor override trade period'
  i_MnodeConstraintRHSOvrdDate(ovrd,MnodeCstr,fromTo,day,mth,yr)                                  'Market node constraint RHS override date'
  i_MnodeConstraintRHSOvrdTP(ovrd,MnodeCstr,tp)                                              'Market node constraint RHS override trade period'
* Risk/Reserves
  i_contingentEventRAFOvrdDate(ovrd,ild,i_reserveClass,fromTo,day,mth,yr)                            'Contingency event RAF override date'
  i_contingentEventRAFOvrdTP(ovrd,ild,i_reserveClass,tp)                                        'Contingency event RAF override trade period'
  i_extendedContingentEventRAFOvrdDate(ovrd,ild,i_reserveClass,fromTo,day,mth,yr)                    'Extended contingency event RAF override date'
  i_extendedContingentEventRAFOvrdTP(ovrd,ild,i_reserveClass,tp)                                'Extended contingency event RAF override trade period'
  i_contingentEventNFROvrdDate(ovrd,ild,i_reserveClass,i_riskClass,fromTo,day,mth,yr)                'Contingency event NFR override date - Generator and Manual'
  i_contingentEventNFROvrdTP(ovrd,ild,i_reserveClass,i_riskClass,tp)                            'Contingency event NFR override trade period - Generator and Manual'
  i_HVDCriskParamOvrdDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter,fromTo,day,mth,yr)     'HVDC risk parameter override date'
  i_HVDCriskParamOvrdTP(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter,tp)                 'HVDC risk parameter override trade period'
  ;

Parameters
* Demand overrides
  i_islandPosMWDemandOvrd(ovrd,ild)                                            'Island positive demand override MW values'
  i_islandPosPercDemandOvrd(ovrd,ild)                                          'Island positive demand override % values'
  i_islandNegMWDemandOvrd(ovrd,ild)                                            'Island negative demand override MW values'
  i_islandNegPercDemandOvrd(ovrd,ild)                                          'Island negative demand override % values'
  i_islandNetMWDemandOvrd(ovrd,ild)                                            'Island net demand override MW values'
  i_islandNetPercDemandOvrd(ovrd,ild)                                          'Island net demand override % values'
  i_nodeMWDemandOvrd(ovrd,n)                                                   'Node demand override MW values'
  i_nodePercDemandOvrd(ovrd,n)                                                 'Node demand override % values'
* Branch parameter, capacity and status overrides
  i_branchParamOvrd(ovrd,br,i_branchParameter)                                'Branch parameter override values'
  i_branchCapacityOvrd(ovrd,br)                                               'Branch capacity override values'
  i_branchOpenStatusOvrd(ovrd,br)                                             'Branch open status override values'
* Branch constraint factor overrides - factor and RHS
  i_branchConstraintFactorOvrd(ovrd,brCstr,br)                    'Branch constraint factor override values'
  i_branchConstraintRHSOvrd(ovrd,brCstr,i_constraintRHS)                'Branch constraint RHS override values'
* Market node constraint overrides - factor and RHS
  i_MnodeEnergyConstraintFactorOvrd(ovrd,MnodeCstr,o)                 'Market node energy constraint factor override values'
  i_MnodeReserveConstraintFactorOvrd(ovrd,MnodeCstr,o,i_reserveClass) 'Market node reserve constraint factor override values'
  i_MnodeConstraintRHSOvrd(ovrd,MnodeCstr,i_constraintRHS)                  'Market node constraint RHS override values'
* Risk/Reserve overrides
  i_contingentEventRAFOvrd(ovrd,ild,i_reserveClass)                            'Contingency event RAF override'
  i_extendedContingentEventRAFOvrd(ovrd,ild,i_reserveClass)                    'Extended contingency event RAF override'
  i_contingentEventNFROvrd(ovrd,ild,i_reserveClass,i_riskClass)                'Contingency event NFR override - GENRISK and Manual'
  i_HVDCriskParamOvrd(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter)     'HVDC risk parameter override'

* More demand overrides
  islandDemandOvrdFromDay(ovrd,ild)                                            'Island demand override from day'
  islandDemandOvrdFromMonth(ovrd,ild)                                          'Island demand override from month'
  islandDemandOvrdFromYear(ovrd,ild)                                           'Island demand override from year'
  islandDemandOvrdToDay(ovrd,ild)                                              'Island demand override to day'
  islandDemandOvrdToMonth(ovrd,ild)                                            'Island demand override to month'
  islandDemandOvrdToYear(ovrd,ild)                                             'Island demand override to year'
  islandDemandOvrdFromGDate(ovrd,ild)                                          'Island demand override date - Gregorian'
  islandDemandOvrdToGDate(ovrd,ild)                                            'Island demand override to date - Gregorian'
  tradePeriodNodeDemandOrig(tp,n)                                   'Original node demand - MW'
  tradePeriodPosislandDemand(tp,ild)                                'Original positive island demand'
  tradePeriodNegislandDemand(tp,ild)                                'Original negative island demand'
  tradePeriodNetislandDemand(tp,ild)                                'Original net island demand'
  nodeDemandOvrdFromDay(ovrd,n)                                                'Node demand override from day'
  nodeDemandOvrdFromMonth(ovrd,n)                                              'Node demand override from month'
  nodeDemandOvrdFromYear(ovrd,n)                                               'Node demand override from year'
  nodeDemandOvrdToDay(ovrd,n)                                                  'Node demand override to day'
  nodeDemandOvrdToMonth(ovrd,n)                                                'Node demand override to month'
  nodeDemandOvrdToYear(ovrd,n)                                                 'Node demand override to year'
  nodeDemandOvrdFromGDate(ovrd,n)                                              'Node demand override date - Gregorian'
  nodeDemandOvrdToGDate(ovrd,n)                                                'Node demand override to date - Gregorian'
  tradePeriodNodeDemandOvrd(tp,n)                                   'Node demand override'
* More branch overrides
  branchOvrdFromDay(ovrd,br)                                                  'Branch override from day'
  branchOvrdFromMonth(ovrd,br)                                                'Branch override from month'
  branchOvrdFromYear(ovrd,br)                                                 'Branch override from year'
  branchOvrdToDay(ovrd,br)                                                    'Branch override to day'
  branchOvrdToMonth(ovrd,br)                                                  'Branch override to month'
  branchOvrdToYear(ovrd,br)                                                   'Branch override to year'
  branchOvrdFromGDate(ovrd,br)                                                'Branch override date - Gregorian'
  branchOvrdToGDate(ovrd,br)                                                  'Branch override to date - Gregorian'
  tradePeriodBranchParamOvrd(tp,br,i_branchParameter)              'Branch parameter override for applicable trade periods'
  tradePeriodBranchCapacityOvrd(tp,br)                             'Branch capacity override for applicable trade periods'
  tradePeriodBranchOpenStatusOvrd(tp,br)                           'Branch status override for applicable trade periods'
* More branch security constraint overrides - factor
  branchConstraintFactorOvrdFromDay(ovrd,brCstr,br)               'Branch constraint factor override from day'
  branchConstraintFactorOvrdFromMonth(ovrd,brCstr,br)             'Branch constraint factor override from month'
  branchConstraintFactorOvrdFromYear(ovrd,brCstr,br)              'Branch constraint factor override from year'
  branchConstraintFactorOvrdToDay(ovrd,brCstr,br)                 'Branch constraint factor override to day'
  branchConstraintFactorOvrdToMonth(ovrd,brCstr,br)               'Branch constraint factor override to month'
  branchConstraintFactorOvrdToYear(ovrd,brCstr,br)                'Branch constraint factor override to year'
  branchConstraintFactorOvrdFromGDate(ovrd,brCstr,br)             'Branch constraint factor override date - Gregorian'
  branchConstraintFactorOvrdToGDate(ovrd,brCstr,br)               'Branch constraint factor override to date - Gregorian'
  tradePeriodBranchConstraintFactorOvrd(tp,brCstr,br)  'Branch constraint factor override for applicable trade periods'
* More branch security constraint overrides - RHS
  branchConstraintRHSOvrdFromDay(ovrd,brCstr)                           'Branch constraint RHS override from day'
  branchConstraintRHSOvrdFromMonth(ovrd,brCstr)                         'Branch constraint RHS override from month'
  branchConstraintRHSOvrdFromYear(ovrd,brCstr)                          'Branch constraint RHS override from year'
  branchConstraintRHSOvrdToDay(ovrd,brCstr)                             'Branch constraint RHS override to day'
  branchConstraintRHSOvrdToMonth(ovrd,brCstr)                           'Branch constraint RHS override to month'
  branchConstraintRHSOvrdToYear(ovrd,brCstr)                            'Branch constraint RHS override to year'
  branchConstraintRHSOvrdFromGDate(ovrd,brCstr)                         'Branch constraint RHS override date - Gregorian'
  branchConstraintRHSOvrdToGDate(ovrd,brCstr)                           'Branch constraint RHS override to date - Gregorian'
  tradePeriodBranchConstraintRHSOvrd(tp,brCstr,i_constraintRHS)'Branch constraint RHS override for applicable trade periods'
* More market node constraint overrides - energy factor
  MnodeEnergyConstraintFactorOvrdFromDay(ovrd,MnodeCstr,o)            'Market node energy constraint factor override from day'
  MnodeEnergyConstraintFactorOvrdFromMonth(ovrd,MnodeCstr,o)          'Market node energy constraint factor override from month'
  MnodeEnergyConstraintFactorOvrdFromYear(ovrd,MnodeCstr,o)           'Market node energy constraint factor override from year'
  MnodeEnergyConstraintFactorOvrdToDay(ovrd,MnodeCstr,o)              'Market node energy constraint factor override to day'
  MnodeEnergyConstraintFactorOvrdToMonth(ovrd,MnodeCstr,o)            'Market node energy constraint factor override to month'
  MnodeEnergyConstraintFactorOvrdToYear(ovrd,MnodeCstr,o)             'Market node energy constraint factor override to year'
  MnodeEnergyConstraintFactorOvrdFromGDate(ovrd,MnodeCstr,o)          'Market node energy constraint factor override date - Gregorian'
  MnodeEnergyConstraintFactorOvrdToGDate(ovrd,MnodeCstr,o)            'Market node energy constraint factor override to date - Gregorian'
  tradePeriodMnodeEnergyConstraintFactorOvrd(tp,MnodeCstr,o) 'Market node energy constraint factor override for applicable trade periods'
* More market node constraint overrides - reserve factor
  MnodeReserveConstraintFactorOvrdFromDay(ovrd,MnodeCstr,o,i_reserveClass)            'Market node reserve constraint factor override from day'
  MnodeReserveConstraintFactorOvrdFromMonth(ovrd,MnodeCstr,o,i_reserveClass)          'Market node reserve constraint factor override from month'
  MnodeReserveConstraintFactorOvrdFromYear(ovrd,MnodeCstr,o,i_reserveClass)           'Market node reserve constraint factor override from year'
  MnodeReserveConstraintFactorOvrdToDay(ovrd,MnodeCstr,o,i_reserveClass)              'Market node reserve constraint factor override to day'
  MnodeReserveConstraintFactorOvrdToMonth(ovrd,MnodeCstr,o,i_reserveClass)            'Market node reserve constraint factor override to month'
  MnodeReserveConstraintFactorOvrdToYear(ovrd,MnodeCstr,o,i_reserveClass)             'Market node reserve constraint factor override to year'
  MnodeReserveConstraintFactorOvrdFromGDate(ovrd,MnodeCstr,o,i_reserveClass)          'Market node reserve constraint factor override date - Gregorian'
  MnodeReserveConstraintFactorOvrdToGDate(ovrd,MnodeCstr,o,i_reserveClass)            'Market node reserve constraint factor override to date - Gregorian'
  tradePeriodMnodeReserveConstraintFactorOvrd(tp,MnodeCstr,o,i_reserveClass) 'Market node reserve constraint factor override for applicable trade periods'
* More market node constraint overrides - RHS
  MnodeConstraintRHSOvrdFromDay(ovrd,MnodeCstr)                             'Market node constraint RHS override from day'
  MnodeConstraintRHSOvrdFromMonth(ovrd,MnodeCstr)                           'Market node constraint RHS override from month'
  MnodeConstraintRHSOvrdFromYear(ovrd,MnodeCstr)                            'Market node constraint RHS override from year'
  MnodeConstraintRHSOvrdToDay(ovrd,MnodeCstr)                               'Market node constraint RHS override to day'
  MnodeConstraintRHSOvrdToMonth(ovrd,MnodeCstr)                             'Market node constraint RHS override to month'
  MnodeConstraintRHSOvrdToYear(ovrd,MnodeCstr)                              'Market node constraint RHS override to year'
  MnodeConstraintRHSOvrdFromGDate(ovrd,MnodeCstr)                           'Market node constraint RHS override date - Gregorian'
  MnodeConstraintRHSOvrdToGDate(ovrd,MnodeCstr)                             'Market node constraint RHS override to date - Gregorian'
  tradePeriodMnodeConstraintRHSOvrd(tp,MnodeCstr,i_constraintRHS)'Market node constraint RHS override for applicable trade periods'
* More risk/reserve overrides
  RAFovrdDay(ovrd,ild,i_reserveClass)                                          'RAF override from day'
  RAFovrdMonth(ovrd,ild,i_reserveClass)                                        'RAF override from month'
  RAFovrdYear(ovrd,ild,i_reserveClass)                                         'RAF override from year'
  CERAFovrdFromGDate(ovrd,ild,i_reserveClass)                                  'Contingency event RAF override date - Gregorian'
  CERAFovrdToGDate(ovrd,ild,i_reserveClass)                                    'Contingency event RAF override to date - Gregorian'
  tradePeriodCERAFovrd(tp,ild,i_reserveClass)                       'Contingency event RAF override for applicable trade periods'
  ECERAFovrdFromGDate(ovrd,ild,i_reserveClass)                                 'Extended contingency event RAF override date - Gregorian'
  ECERAFovrdToGDate(ovrd,ild,i_reserveClass)                                   'Extended contingency event RAF override to date - Gregorian'
  tradePeriodECERAFovrd(tp,ild,i_reserveClass)                      'Extended contingency event RAF override for applicable trade periods'
  CENFRovrdDay(ovrd,ild,i_reserveClass,i_riskClass)                            'Contingency event NFR override from day'
  CENFRovrdMonth(ovrd,ild,i_reserveClass,i_riskClass)                          'Contingency event NFR override from month'
  CENFRovrdYear(ovrd,ild,i_reserveClass,i_riskClass)                           'Contingency event NFR override from year'
  CENFRovrdFromGDate(ovrd,ild,i_reserveClass,i_riskClass)                      'Contingency event NFR override date - Gregorian'
  CENFRovrdToGDate(ovrd,ild,i_reserveClass,i_riskClass)                        'Contingency event NFR override to date - Gregorian'
  tradePeriodCENFRovrd(tp,ild,i_reserveClass,i_riskClass)           'Contingency event NFR override for applicable trade periods'
  HVDCriskOvrdDay(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter)         'HVDC risk parameter override from day'
  HVDCriskOvrdMonth(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter)       'HVDC risk parameter override from month'
  HVDCriskOvrdYear(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter)        'HVDC risk parameter override from year'
  HVDCriskOvrdFromGDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter)   'HVDC risk parameter override date - Gregorian'
  HVDCriskOvrdToGDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter)     'HVDC risk parameter override to date - Gregorian'
  tradePeriodHVDCriskOvrd(tp,ild,i_reserveClass,i_riskClass,i_riskParameter) 'HVDC risk parameter override for applicable trade periods'
  ;
$offtext

* EMI tools and Standalone interface - load/install override data
* Load override data from override GDX file. Note that all of these symbols must exist in the GDX file so as to intialise everything - even if they're empty.
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load new_offer new_offerNode new_offerTrader new_offerRiskSetter new_offerInherit new_offerDate
$load ovrd_offerParamDate ovrd_offerParamTP ovrd_energyOfferDate ovrd_energyOfferTP ovrd_PLSRofferDate ovrd_PLSRofferTP
$load ovrd_TWDRofferDate ovrd_TWDRofferTP ovrd_ILRofferDate ovrd_ILRofferTP
$load ovrd_offerParam ovrd_energyOffer ovrd_PLSRoffer ovrd_TWDRoffer ovrd_ILRoffer
*$load i_islandDemandOvrdFromDate i_islandDemandOvrdTP i_nodeDemandOvrdFromDate
*$load i_nodeDemandOvrdTP i_branchParamOvrdFromDate i_branchParamOvrdTP i_branchCapacityOvrdFromDate i_branchCapacityOvrdTP
*$load i_branchOpenStatusOvrdFromDate i_branchOpenStatusOvrdTP i_branchConstraintFactorOvrdFromDate
*$load i_branchConstraintFactorOvrdTP i_branchConstraintRHSOvrdFromDate i_branchConstraintRHSOvrdTP i_MnodeEnergyConstraintFactorOvrdFromDate
*$load i_MnodeEnergyConstraintFactorOvrdTP i_MnodeReserveConstraintFactorOvrdFromDate
*$load i_MnodeReserveConstraintFactorOvrdTP i_MnodeConstraintRHSOvrdFromDate i_MnodeConstraintRHSOvrdTP i_contingentEventRAFovrdFromDate
*$load i_contingentEventRAFovrdTP i_extendedContingentEventRAFovrdFromDate i_extendedContingentEventRAFovrdTP
*$load i_contingentEventNFRovrdFromDate i_contingentEventNFRovrdTP i_HVDCriskParamOvrdFromDate i_HVDCriskParamOvrdTP
*$load i_islandPosMWDemandOvrd i_islandPosPercDemandOvrd i_islandNegMWDemandOvrd
*$load i_islandNegPercDemandOvrd i_islandNetMWDemandOvrd i_islandNetPercDemandOvrd i_nodeMWDemandOvrd i_nodePercDemandOvrd i_branchParamOvrd i_branchCapacityOvrd
*$load i_branchOpenStatusOvrd i_branchConstraintFactorOvrd i_branchConstraintRHSOvrd i_MnodeEnergyConstraintFactorOvrd i_MnodeReserveConstraintFactorOvrd i_MnodeConstraintRHSOvrd
*$load i_contingentEventRAFovrd i_extendedContingentEventRAFovrd i_contingentEventNFRovrd i_HVDCriskParamOvrd
$gdxin


* Comment out the above $gdxin/$load statements and write some alternative statements to install override data from
* a source other than a GDX file when in standalone mode. But note that all declared override symbols must get initialised
* somehow, i.e. load empty from a GDX or explicitly assign them to be zero.

* EMI and Standalone interface - assign or initialise all of the override symbols - this goes on for many pages...








*=====================================================================================
* x. Initialise new data instances based on new set elements in override file
*=====================================================================================

* Reset the override parameters
option clear = newOfferDay ; option clear = newOfferMonth ; option clear = newOfferYear ; option clear = newOfferGDate ;

newOfferDay(new_offer,fromTo)   = sum((day,mth,yr)$new_offerDate(new_offer,fromTo,day,mth,yr), ord(day) ) ;
newOfferMonth(new_offer,fromTo) = sum((day,mth,yr)$new_offerDate(new_offer,fromTo,day,mth,yr), ord(mth) ) ;
newOfferYear(new_offer,fromTo)  = sum((day,mth,yr)$new_offerDate(new_offer,fromTo,day,mth,yr), ord(yr) + startYear ) ;

newOfferGDate(new_offer,fromTo)$sum((day,mth,yr)$new_offerDate(new_offer,fromTo,day,mth,yr), 1 ) =
  jdate( newOfferYear(new_offer,fromTo), newOfferMonth(new_offer,fromTo), newOfferDay(new_offer,fromTo) ) ;

* If new offer is not mapped to a node then it is an invalid offer and excluded from the solve
i_tradePeriodOfferNode(tp,new_offerNode(new_offer,n))${ ( inputGDXgdate >= newOfferGDate(new_offer,'frm') ) and
                                                        ( inputGDXgdate <= newOfferGDate(new_offer,'to') )
                                                      } = yes ;

* If new offer is not mapped to a trader then it is an invalid offer and excluded from the solve
i_tradePeriodOfferTrader(tp,new_offerTrader(new_offer,trdr))${ ( inputGDXgdate >= newOfferGDate(new_offer,'frm') ) and
                                                               ( inputGDXgdate <= newOfferGDate(new_offer,'to') )
                                                             } = yes ;

* Initialise the set of risk setters if the new offer is a risk setter
i_tradePeriodRiskGenerator(tp,new_offerRiskSetter(new_offer)) = yes ;

* Initialise the data for new parameters based on inherited values
i_tradePeriodOfferParameter(tp,new_offer,i_OfferParam)           = sum(o1$new_offerInherit(new_offer,o1), i_tradePeriodOfferParameter(tp,o1,i_OfferParam)) ;
i_tradePeriodEnergyOffer(tp,new_offer,trdBlk,NRGofrCmpnt)        = sum(o1$new_offerInherit(new_offer,o1), i_tradePeriodEnergyOffer(tp,o1,trdBlk,NRGofrCmpnt)) ;
i_tradePeriodSustainedPLSROffer(tp,new_offer,trdBlk,PLSofrCmpnt) = sum(o1$new_offerInherit(new_offer,o1), i_tradePeriodSustainedPLSROffer(tp,o1,trdBlk,PLSofrCmpnt)) ;
i_tradePeriodFastPLSROffer(tp,new_offer,trdBlk,PLSofrCmpnt)      = sum(o1$new_offerInherit(new_offer,o1), i_tradePeriodFastPLSROffer(tp,o1,trdBlk,PLSofrCmpnt)) ;
i_tradePeriodSustainedTWDROffer(tp,new_offer,trdBlk,TWDofrCmpnt) = sum(o1$new_offerInherit(new_offer,o1), i_tradePeriodSustainedTWDROffer(tp,o1,trdBlk,TWDofrCmpnt)) ;
i_tradePeriodFastTWDROffer(tp,new_offer,trdBlk,TWDofrCmpnt)      = sum(o1$new_offerInherit(new_offer,o1), i_tradePeriodFastTWDROffer(tp,o1,trdBlk,TWDofrCmpnt)) ;
i_tradePeriodSustainedILROffer(tp,new_offer,trdBlk,ILofrCmpnt)   = sum(o1$new_offerInherit(new_offer,o1), i_tradePeriodSustainedILROffer(tp,o1,trdBlk,ILofrCmpnt)) ;
i_tradePeriodFastILROffer(tp,new_offer,trdBlk,ILofrCmpnt)        = sum(o1$new_offerInherit(new_offer,o1), i_tradePeriodFastILROffer(tp,o1,trdBlk,ILofrCmpnt)) ;

$ontext
Symbols defined on i_offer/o that are not intialised for new offer elements - check with Ramu that this is as he intended...
Sets
  i_tradePeriodPrimarySecondaryOffer(tp,o1,o)
Parameters
  i_tradePeriodMNodeEnergyOfferConstraintFactors(tp,MnodeCstr,o)
  i_type1MixedConstraintGenWeight(t1MixCstr,o)
  i_tradePeriodGenericEnergyOfferConstraintFactors(tp,gnrcCstr,o)
  i_tradePeriodReserveClassGenerationMaximum(tp,o,i_reserveClass)
  i_type1MixedConstraintResWeight(t1MixCstr,o,i_reserveClass,i_reserveType)
  i_tradePeriodMNodeReserveOfferConstraintFactors(tp,MnodeCstr,o,i_reserveClass,i_reserveType)
  i_tradePeriodGenericReserveOfferConstraintFactors(tp,gnrcCstr,o,i_reserveClass,i_reserveType)
$offtext



*=====================================================================================
* x. Initialise override symbols
*=====================================================================================

* a) Offer parameters
* Reset the override parameters
option clear = ovrdOfferDay ; option clear = ovrdOfferMonth ; option clear = ovrdOfferYear ; option clear = ovrdOfferGDate ;

* Calculate the from and to dates for the offer parameter overrides
ovrdOfferDay(ovrd,o,fromTo)   = sum((day,mth,yr)$ovrd_offerParamDate(ovrd,o,fromTo,day,mth,yr), ord(day) ) ;
ovrdOfferMonth(ovrd,o,fromTo) = sum((day,mth,yr)$ovrd_offerParamDate(ovrd,o,fromTo,day,mth,yr), ord(mth) ) ;
ovrdOfferYear(ovrd,o,fromTo)  = sum((day,mth,yr)$ovrd_offerParamDate(ovrd,o,fromTo,day,mth,yr), ord(yr) + startYear ) ;

ovrdOfferGDate(ovrd,o,fromTo)$sum((day,mth,yr)$ovrd_offerParamDate(ovrd,o,fromTo,day,mth,yr), 1 ) =
  jdate( ovrdOfferYear(ovrd,o,fromTo), ovrdOfferMonth(ovrd,o,fromTo), ovrdOfferDay(ovrd,o,fromTo) ) ;

* Determine if all the conditions for applying the offer parameter overrides are satisfied
loop((ovrd,tp,o,i_offerParam)${   i_studyTradePeriod(tp) and
                                ( ovrdOfferGDate(ovrd,o,'frm') <= inputGDXgdate ) and
                                ( ovrdOfferGDate(ovrd,o,'to')  >= inputGDXgdate ) and
                                  ovrd_offerParamTP(ovrd,o,tp) and
                                  ovrd_offerParam(ovrd,o,i_offerParam)
                              },
  if( (ovrd_offerParam(ovrd,o,i_offerParam) > 0 ),   ovrdOfferParamTP(tp,o,i_offerParam) = ovrd_offerParam(ovrd,o,i_offerParam) ) ;
  if( (ovrd_offerParam(ovrd,o,i_offerParam) = eps ), ovrdOfferParamTP(tp,o,i_offerParam) = eps ) ;
) ;

* Apply the offer parameter override values to the base case input data value. Clear the offer parameter override values when done.
i_tradePeriodOfferParameter(tp,o,i_offerParam)${ ovrdOfferParamTP(tp,o,i_offerParam) > 0 } = ovrdOfferParamTP(tp,o,i_offerParam) ;
i_tradePeriodOfferParameter(tp,o,i_offerParam)${   ovrdOfferParamTP(tp,o,i_offerParam) and
                                                 ( ovrdOfferParamTP(tp,o,i_offerParam) = eps ) } = 0 ;
option clear = ovrdOfferParamTP ;


* b) Energy offers
* Reset the override parameters
option clear = ovrdOfferDay ; option clear = ovrdOfferMonth ; option clear = ovrdOfferYear ; option clear = ovrdOfferGDate ;

* Calculate the from and to dates for the energy offer overrides
ovrdOfferDay(ovrd,o,fromTo)   = sum((day,mth,yr)$ovrd_energyOfferDate(ovrd,o,fromTo,day,mth,yr), ord(day) ) ;
ovrdOfferMonth(ovrd,o,fromTo) = sum((day,mth,yr)$ovrd_energyOfferDate(ovrd,o,fromTo,day,mth,yr), ord(mth) ) ;
ovrdOfferYear(ovrd,o,fromTo)  = sum((day,mth,yr)$ovrd_energyOfferDate(ovrd,o,fromTo,day,mth,yr), ord(yr) + startYear ) ;

ovrdOfferGDate(ovrd,o,fromTo)$sum((day,mth,yr)$ovrd_energyOfferDate(ovrd,o,fromTo,day,mth,yr), 1 ) =
  jdate( ovrdOfferYear(ovrd,o,fromTo), ovrdOfferMonth(ovrd,o,fromTo), ovrdOfferDay(ovrd,o,fromTo) ) ;

* Determine if all the conditions for applying the energy offer overrides are satisfied
loop((ovrd,tp,o,trdBlk,NRGofrCmpnt)${   i_studyTradePeriod(tp) and
                                      ( ovrdOfferGDate(ovrd,o,'frm') <= inputGDXgdate ) and
                                      ( ovrdOfferGDate(ovrd,o,'to')  >= inputGDXgdate ) and
                                        ovrd_energyOfferTP(ovrd,o,tp) and
                                        ovrd_energyOffer(ovrd,o,trdBlk,NRGofrCmpnt)
                                    },
  if(ovrd_energyOffer(ovrd,o,trdBlk,NRGofrCmpnt) > 0,
    ovrdEnergyOfferTP(tp,o,trdBlk,NRGofrCmpnt) = ovrd_energyOffer(ovrd,o,trdBlk,NRGofrCmpnt) ;
  ) ;
  if(ovrd_energyOffer(ovrd,o,trdBlk,NRGofrCmpnt) = eps,
    ovrdEnergyOfferTP(tp,o,trdBlk,NRGofrCmpnt) = eps ;
  ) ;
) ;

* Apply the energy offer override values to the base case input data values. Clear the energy offer override values when done.
i_tradePeriodEnergyOffer(tp,o,trdBlk,NRGofrCmpnt)$( ovrdEnergyOfferTP(tp,o,trdBlk,NRGofrCmpnt) > 0 ) =
  ovrdEnergyOfferTP(tp,o,trdBlk,NRGofrCmpnt) ;
i_tradePeriodEnergyOffer(tp,o,trdBlk,NRGofrCmpnt)$(   ovrdEnergyOfferTP(tp,o,trdBlk,NRGofrCmpnt) and
                                                    ( ovrdEnergyOfferTP(tp,o,trdBlk,NRGofrCmpnt) = eps ) ) = 0 ;
option clear = ovrdEnergyOfferTP ;


* c) PLSR offers
* Reset the override parameters
option clear = ovrdOfferDay ; option clear = ovrdOfferMonth ; option clear = ovrdOfferYear ; option clear = ovrdOfferGDate ;

* Calculate the from and to dates for the PLSR offer overrides
ovrdOfferDay(ovrd,o,fromTo)   = sum((day,mth,yr)$ovrd_PLSRofferDate(ovrd,o,fromTo,day,mth,yr), ord(day) ) ;
ovrdOfferMonth(ovrd,o,fromTo) = sum((day,mth,yr)$ovrd_PLSRofferDate(ovrd,o,fromTo,day,mth,yr), ord(mth) ) ;
ovrdOfferYear(ovrd,o,fromTo)  = sum((day,mth,yr)$ovrd_PLSRofferDate(ovrd,o,fromTo,day,mth,yr), ord(yr) + startYear ) ;

ovrdOfferGDate(ovrd,o,fromTo)$sum((day,mth,yr)$ovrd_PLSRofferDate(ovrd,o,fromTo,day,mth,yr), 1 ) =
  jdate( ovrdOfferYear(ovrd,o,fromTo), ovrdOfferMonth(ovrd,o,fromTo), ovrdOfferDay(ovrd,o,fromTo) ) ;

* Determine if all the conditions for applying the PLSR offer overrides are satisfied
loop((ovrd,tp,o,i_reserveClass,trdBlk,PLSofrCmpnt)$(   i_studyTradePeriod(tp) and
                                                     ( ovrdOfferGDate(ovrd,o,'frm') <= inputGDXgdate ) and
                                                     ( ovrdOfferGDate(ovrd,o,'to')  >= inputGDXgdate ) and
                                                       ovrd_PLSRofferTP(ovrd,o,tp) and
                                                       ovrd_PLSRoffer(ovrd,i_reserveClass,o,trdBlk,PLSofrCmpnt)
                                                   ),
  if(ovrd_PLSRoffer(ovrd,i_reserveClass,o,trdBlk,PLSofrCmpnt) > 0,
    ovrdPLSRofferTP(tp,i_reserveClass,o,trdBlk,PLSofrCmpnt) = ovrd_PLSRoffer(ovrd,i_reserveClass,o,trdBlk,PLSofrCmpnt) ;
  ) ;
  if(ovrd_PLSRoffer(ovrd,i_reserveClass,o,trdBlk,PLSofrCmpnt) = eps,
    ovrdPLSRofferTP(tp,i_reserveClass,o,trdBlk,PLSofrCmpnt) = eps ;
  ) ;
) ;

* Apply the PLSR offer override values to the base case input data values. Clear the PLSR offer override values when done.
i_tradePeriodFastPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)$( ovrdPLSRofferTP(tp,'fir',o,trdBlk,PLSofrCmpnt) > 0 ) =
  ovrdPLSRofferTP(tp,'fir',o,trdBlk,PLSofrCmpnt) ;
i_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)$( ovrdPLSRofferTP(tp,'sir',o,trdBlk,PLSofrCmpnt) > 0 ) =
  ovrdPLSRofferTP(tp,'sir',o,trdBlk,PLSofrCmpnt) ;
i_tradePeriodFastPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)$(   ovrdPLSRofferTP(tp,'fir',o,trdBlk,PLSofrCmpnt) and
                                                      ( ovrdPLSRofferTP(tp,'fir',o,trdBlk,PLSofrCmpnt) = eps ) ) = 0 ;
i_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)$(   ovrdPLSRofferTP(tp,'sir',o,trdBlk,PLSofrCmpnt) and
                                                           ( ovrdPLSRofferTP(tp,'sir',o,trdBlk,PLSofrCmpnt) = eps ) ) = 0 ;
option clear = ovrdPLSRofferTP ;


* d) TWDR offers
* Reset the override parameters
option clear = ovrdOfferDay ; option clear = ovrdOfferMonth ; option clear = ovrdOfferYear ; option clear = ovrdOfferGDate ;

* Calculate the from and to dates for the TWDR offer overrides
ovrdOfferDay(ovrd,o,fromTo)   = sum((day,mth,yr)$ovrd_TWDRofferDate(ovrd,o,fromTo,day,mth,yr), ord(day) ) ;
ovrdOfferMonth(ovrd,o,fromTo) = sum((day,mth,yr)$ovrd_TWDRofferDate(ovrd,o,fromTo,day,mth,yr), ord(mth) ) ;
ovrdOfferYear(ovrd,o,fromTo)  = sum((day,mth,yr)$ovrd_TWDRofferDate(ovrd,o,fromTo,day,mth,yr), ord(yr) + startYear ) ;

ovrdOfferGDate(ovrd,o,fromTo)$sum((day,mth,yr)$ovrd_TWDRofferDate(ovrd,o,fromTo,day,mth,yr), 1 ) =
  jdate( ovrdOfferYear(ovrd,o,fromTo), ovrdOfferMonth(ovrd,o,fromTo), ovrdOfferDay(ovrd,o,fromTo) ) ;

* Determine if all the conditions for applying the TWDR offer overrides are satisfied
loop((ovrd,tp,o,i_reserveClass,trdBlk,TWDofrCmpnt)$(   i_studyTradePeriod(tp) and
                                                     ( ovrdOfferGDate(ovrd,o,'frm') <= inputGDXgdate ) and
                                                     ( ovrdOfferGDate(ovrd,o,'to')  >= inputGDXgdate ) and
                                                       ovrd_TWDRofferTP(ovrd,o,tp) and
                                                       ovrd_TWDRoffer(ovrd,i_reserveClass,o,trdBlk,TWDofrCmpnt)
                                                   ),
  if(ovrd_TWDRoffer(ovrd,i_reserveClass,o,trdBlk,TWDofrCmpnt) > 0,
    ovrdTWDRofferTP(tp,i_reserveClass,o,trdBlk,TWDofrCmpnt) = ovrd_TWDRoffer(ovrd,i_reserveClass,o,trdBlk,TWDofrCmpnt) ;
  ) ;
  if(ovrd_TWDRoffer(ovrd,i_reserveClass,o,trdBlk,TWDofrCmpnt) = eps,
    ovrdTWDRofferTP(tp,i_reserveClass,o,trdBlk,TWDofrCmpnt) = eps ;
  ) ;
) ;

* Apply the TWDR offer override values to the base case input data values. Clear the TWDR offer override values when done.
i_tradePeriodFastTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)$( ovrdTWDRofferTP(tp,'fir',o,trdBlk,TWDofrCmpnt) > 0 ) =
  ovrdTWDRofferTP(tp,'fir',o,trdBlk,TWDofrCmpnt) ;
i_tradePeriodSustainedTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)$( ovrdTWDRofferTP(tp,'sir',o,trdBlk,TWDofrCmpnt) > 0 ) =
  ovrdTWDRofferTP(tp,'sir',o,trdBlk,TWDofrCmpnt) ;
i_tradePeriodFastTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)$(   ovrdTWDRofferTP(tp,'fir',o,trdBlk,TWDofrCmpnt) and
                                                      ( ovrdTWDRofferTP(tp,'fir',o,trdBlk,TWDofrCmpnt) = eps ) ) = 0 ;
i_tradePeriodSustainedTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)$(   ovrdTWDRofferTP(tp,'sir',o,trdBlk,TWDofrCmpnt) and
                                                           ( ovrdTWDRofferTP(tp,'sir',o,trdBlk,TWDofrCmpnt) = eps ) ) = 0 ;
option clear = ovrdTWDRofferTP ;


* e) ILR offers
* Reset the override parameters
option clear = ovrdOfferDay ; option clear = ovrdOfferMonth ; option clear = ovrdOfferYear ; option clear = ovrdOfferGDate ;

* Calculate the from and to dates for the ILR offer overrides
ovrdOfferDay(ovrd,o,fromTo)   = sum((day,mth,yr)$ovrd_ILRofferDate(ovrd,o,fromTo,day,mth,yr), ord(day) ) ;
ovrdOfferMonth(ovrd,o,fromTo) = sum((day,mth,yr)$ovrd_ILRofferDate(ovrd,o,fromTo,day,mth,yr), ord(mth) ) ;
ovrdOfferYear(ovrd,o,fromTo)  = sum((day,mth,yr)$ovrd_ILRofferDate(ovrd,o,fromTo,day,mth,yr), ord(yr) + startYear ) ;

ovrdOfferGDate(ovrd,o,fromTo)$sum((day,mth,yr)$ovrd_ILRofferDate(ovrd,o,fromTo,day,mth,yr), 1 ) =
  jdate( ovrdOfferYear(ovrd,o,fromTo), ovrdOfferMonth(ovrd,o,fromTo), ovrdOfferDay(ovrd,o,fromTo) ) ;

* Determine if all the conditions for applying the ILR offer overrides are satisfied
loop((ovrd,tp,o,i_reserveClass,trdBlk,ILofrCmpnt)$(   i_studyTradePeriod(tp) and
                                                    ( ovrdOfferGDate(ovrd,o,'frm') <= inputGDXgdate ) and
                                                    ( ovrdOfferGDate(ovrd,o,'to')  >= inputGDXgdate ) and
                                                      ovrd_ILRofferTP(ovrd,o,tp) and
                                                      ovrd_ILRoffer(ovrd,i_reserveClass,o,trdBlk,ILofrCmpnt)
                                                  ),
  if(ovrd_ILRoffer(ovrd,i_reserveClass,o,trdBlk,ILofrCmpnt) > 0,
    ovrdILRofferTP(tp,i_reserveClass,o,trdBlk,ILofrCmpnt) = ovrd_ILRoffer(ovrd,i_reserveClass,o,trdBlk,ILofrCmpnt) ;
  ) ;
  if(ovrd_ILRoffer(ovrd,i_reserveClass,o,trdBlk,ILofrCmpnt) = eps,
    ovrdILRofferTP(tp,i_reserveClass,o,trdBlk,ILofrCmpnt) = eps ;
  ) ;
) ;

* Apply the ILR offer override values to the base case input data values. Clear the ILR offer override values when done.
i_tradePeriodFastILRoffer(tp,o,trdBlk,ILofrCmpnt)$( ovrdILRofferTP(tp,'fir',o,trdBlk,ILofrCmpnt) > 0 ) =
  ovrdILRofferTP(tp,'fir',o,trdBlk,ILofrCmpnt) ;
i_tradePeriodSustainedILRoffer(tp,o,trdBlk,ILofrCmpnt)$( ovrdILRofferTP(tp,'sir',o,trdBlk,ILofrCmpnt) > 0 ) =
  ovrdILRofferTP(tp,'sir',o,trdBlk,ILofrCmpnt) ;
i_tradePeriodFastILRoffer(tp,o,trdBlk,ILofrCmpnt)$(   ovrdILRofferTP(tp,'fir',o,trdBlk,ILofrCmpnt) and
                                                    ( ovrdILRofferTP(tp,'fir',o,trdBlk,ILofrCmpnt) = eps ) ) = 0 ;
i_tradePeriodSustainedILRoffer(tp,o,trdBlk,ILofrCmpnt)$(   ovrdILRofferTP(tp,'sir',o,trdBlk,ILofrCmpnt) and
                                                         ( ovrdILRofferTP(tp,'sir',o,trdBlk,ILofrCmpnt) = eps ) ) = 0 ;
option clear = ovrdILRofferTP ;

* f) Demand overrides



***************** Done up to here...

$ontext
*+++ Start demand override +++

* Calculate the from and to date for the island demand override
  option clear = islandDemandOvrdFromDay ;          option clear = islandDemandOvrdFromMonth ;       option clear = islandDemandOvrdFromYear ;
  option clear = islandDemandOvrdToDay ;            option clear = islandDemandOvrdToMonth ;         option clear = islandDemandOvrdToYear ;
  option clear = islandDemandOvrdFromGDate ;        option clear = islandDemandOvrdToGDate ;

  islandDemandOvrdFromDay(ovrd,ild)   = sum((day,mth,yr)$i_islandDemandOvrdFromDate(ovrd,ild,day,mth,yr), ord(day) ) ;
  islandDemandOvrdFromMonth(ovrd,ild) = sum((day,mth,yr)$i_islandDemandOvrdFromDate(ovrd,ild,day,mth,yr), ord(mth) ) ;
  islandDemandOvrdFromYear(ovrd,ild)  = sum((day,mth,yr)$i_islandDemandOvrdFromDate(ovrd,ild,day,mth,yr), ord(yr) + startYear ) ;

  islandDemandOvrdToDay(ovrd,ild)   = sum((toDay,toMth,toYr)$i_islandDemandOvrdToDate(ovrd,ild,toDay,toMth,toYr), ord(toDay) ) ;
  islandDemandOvrdToMonth(ovrd,ild) = sum((toDay,toMth,toYr)$i_islandDemandOvrdToDate(ovrd,ild,toDay,toMth,toYr), ord(toMth) ) ;
  islandDemandOvrdToYear(ovrd,ild)  = sum((toDay,toMth,toYr)$i_islandDemandOvrdToDate(ovrd,ild,toDay,toMth,toYr), ord(toYr) + startYear ) ;

  islandDemandOvrdFromGDate(ovrd,ild)$sum((day,mth,yr)$i_islandDemandOvrdFromDate(ovrd,ild,day,mth,yr), 1 ) =
    jdate( islandDemandOvrdFromYear(ovrd,ild),islandDemandOvrdFromMonth(ovrd,ild),islandDemandOvrdFromDay(ovrd,ild) ) ;
  islandDemandOvrdToGDate(ovrd,ild)$sum((toDay,toMth,toYr)$i_islandDemandOvrdToDate(ovrd,ild,toDay,toMth,toYr), 1) =
    jdate(islandDemandOvrdToYear(ovrd,ild),islandDemandOvrdToMonth(ovrd,ild),islandDemandOvrdToDay(ovrd,ild) ) ;

* Island demand override pre-processing
  tradePeriodNodeDemandOrig(tp,n) = 0 ;
  tradePeriodNodeDemandOrig(tp,n) = i_tradePeriodNodeDemand(tp,n) ;
  tradePeriodNodeIslandTemp(tp,n,ild)$sum(b$(i_tradePeriodNodeBus(tp,n,b) and i_tradePeriodBusIsland(tp,b,ild)), 1 ) = yes ;

  tradePeriodPosIslandDemand(tp,ild) = sum(n$( tradePeriodNodeIslandTemp(tp,n,ild) and
                                                                  ( tradePeriodNodeDemandOrig(tp,n) > 0 ) ), tradePeriodNodeDemandOrig(tp,n) ) ;
  tradePeriodNegIslandDemand(tp,ild) = sum(n$( tradePeriodNodeIslandTemp(tp,n,ild) and
                                                                  ( tradePeriodNodeDemandOrig(tp,n) < 0 ) ), tradePeriodNodeDemandOrig(tp,n) ) ;
  tradePeriodNetIslandDemand(tp,ild) = sum(n$tradePeriodNodeIslandTemp(tp,n,ild), tradePeriodNodeDemandOrig(tp,n) ) ;

* Apply the demand overrides
  loop((ovrd,ild)$( ( islandDemandOvrdFromGDate(ovrd,ild) <= inputGDXgdate ) and ( islandDemandOvrdToGDate(ovrd,ild) >= inputGDXgdate ) ),
* Percentage override to positive loads
    if((i_islandPosPercDemandOvrd(ovrd,ild) and ( i_islandPosPercDemandOvrd(ovrd,ild) <> 0) ),
      tradePeriodNodeDemandOvrd(tp,n)$( ( tradePeriodNodeDemandOrig(tp,n) > 0 ) and
                                                          i_islandDemandOvrdTP(ovrd,ild,tp) and tradePeriodNodeIslandTemp(tp,n,ild) )
        =  ( 1+ ( i_islandPosPercDemandOvrd(ovrd,ild) / 100 ) ) * tradePeriodNodeDemandOrig(tp,n) ;
    elseif(i_islandPosPercDemandOvrd(ovrd,ild) and ( i_islandPosPercDemandOvrd(ovrd,ild) = eps ) ),
      tradePeriodNodeDemandOvrd(tp,n)$( ( tradePeriodNodeDemandOrig(tp,n) > 0 ) and
                                                          i_islandDemandOvrdTP(ovrd,ild,i_tradePeriod ) and tradePeriodNodeIslandTemp(tp,n,ild) )
        = tradePeriodNodeDemandOrig(tp,n) ;
    ) ;

* Percentage override to negative loads
    if ((i_islandNegPercDemandOvrd(ovrd,ild) and (i_islandNegPercDemandOvrd(ovrd,ild) <> 0)),
       tradePeriodNodeDemandOvrd(tp,n)$((tradePeriodNodeDemandOrig(tp,n) < 0) and i_islandDemandOvrdTP(ovrd,ild,tp) and tradePeriodNodeIslandTemp(tp,n,ild))
          =  (1+(i_islandNegPercDemandOvrd(ovrd,ild)/100)) * tradePeriodNodeDemandOrig(tp,n) ;
    elseif (i_islandNegPercDemandOvrd(ovrd,ild) and (i_islandNegPercDemandOvrd(ovrd,ild) = eps)),
       tradePeriodNodeDemandOvrd(tp,n)$((tradePeriodNodeDemandOrig(tp,n) < 0) and i_islandDemandOvrdTP(ovrd,ild,tp) and tradePeriodNodeIslandTemp(tp,n,ild))
          = tradePeriodNodeDemandOrig(tp,n) ;
    ) ;

* Percentage override to net loads
    if ((i_islandNetPercDemandOvrd(ovrd,ild) and (i_islandNetPercDemandOvrd(ovrd,ild) <> 0)),
       tradePeriodNodeDemandOvrd(tp,n)$(i_islandDemandOvrdTP(ovrd,ild,tp) and tradePeriodNodeIslandTemp(tp,n,ild))
          =  (1+(i_islandNetPercDemandOvrd(ovrd,ild)/100)) * tradePeriodNodeDemandOrig(tp,n) ;
    elseif (i_islandNetPercDemandOvrd(ovrd,ild) and (i_islandNetPercDemandOvrd(ovrd,ild) = eps)),
       tradePeriodNodeDemandOvrd(tp,n)$(i_islandDemandOvrdTP(ovrd,ild,tp) and tradePeriodNodeIslandTemp(tp,n,ild))
          = tradePeriodNodeDemandOrig(tp,n) ;
    ) ;

* MW override to positive island loads
    if ((i_islandPosMWDemandOvrd(ovrd,ild) and (i_islandPosMWDemandOvrd(ovrd,ild) <> 0)),
       tradePeriodNodeDemandOvrd(tp,n)$((tradePeriodPosislandDemand(tp,ild) > 0) and (tradePeriodNodeDemandOrig(tp,n) > 0) and i_islandDemandOvrdTP(ovrd,ild,tp) and tradePeriodNodeIslandTemp(tp,n,ild))
          =  i_islandPosMWDemandOvrd(ovrd,ild) * (tradePeriodNodeDemandOrig(tp,n)/TradePeriodPosislandDemand(tp,ild)) ;
    elseif (i_islandPosMWDemandOvrd(ovrd,ild) and (i_islandPosMWDemandOvrd(ovrd,ild) = eps)),
       tradePeriodNodeDemandOvrd(tp,n)$((tradePeriodNodeDemandOrig(tp,n) > 0) and i_islandDemandOvrdTP(ovrd,ild,tp) and tradePeriodNodeIslandTemp(tp,n,ild))
          = eps ;
    ) ;

* MW override to negative island loads
    if ((i_islandNegMWDemandOvrd(ovrd,ild) and (i_islandNegMWDemandOvrd(ovrd,ild) <> 0)),
       tradePeriodNodeDemandOvrd(tp,n)$((tradePeriodNegislandDemand(tp,ild) < 0) and (tradePeriodNodeDemandOrig(tp,n) < 0) and i_islandDemandOvrdTP(ovrd,ild,tp) and tradePeriodNodeIslandTemp(tp,n,ild))
          =  i_islandNegMWDemandOvrd(ovrd,ild) * (tradePeriodNodeDemandOrig(tp,n)/TradePeriodNegislandDemand(tp,ild)) ;
    elseif (i_islandNegMWDemandOvrd(ovrd,ild) and (i_islandNegMWDemandOvrd(ovrd,ild) = eps)),
       tradePeriodNodeDemandOvrd(tp,n)$((tradePeriodNodeDemandOrig(tp,n) < 0) and i_islandDemandOvrdTP(ovrd,ild,tp) and tradePeriodNodeIslandTemp(tp,n,ild))
          = eps ;
    ) ;

* MW override to net island loads
    if ((i_islandNetMWDemandOvrd(ovrd,ild) and (i_islandNetMWDemandOvrd(ovrd,ild) <> 0)),
       tradePeriodNodeDemandOvrd(tp,n)$((tradePeriodNetislandDemand(tp,ild) <> 0) and (tradePeriodNodeDemandOrig(tp,n) <> 0) and i_islandDemandOvrdTP(ovrd,ild,tp) and tradePeriodNodeIslandTemp(tp,n,ild))
          =  i_islandNetMWDemandOvrd(ovrd,ild) * (tradePeriodNodeDemandOrig(tp,n)/TradePeriodNetislandDemand(tp,ild)) ;
    elseif (i_islandNetMWDemandOvrd(ovrd,ild) and (i_islandNetMWDemandOvrd(ovrd,ild) = eps)),
       tradePeriodNodeDemandOvrd(tp,n)$(i_islandDemandOvrdTP(ovrd,ild,tp) and tradePeriodNodeIslandTemp(tp,n,ild))
          = eps ;
    ) ;

) ;

* Calculate the from and to date for the island demand override
  option clear = islandDemandOvrdFromDay ;          option clear = islandDemandOvrdFromMonth ;       option clear = islandDemandOvrdFromYear ;
  option clear = islandDemandOvrdToDay ;            option clear = islandDemandOvrdToMonth ;         option clear = islandDemandOvrdToYear ;
  option clear = islandDemandOvrdFromGDate ;        option clear = islandDemandOvrdToGDate ;

* Calculate the from and to date for the node demand override
  option clear = nodeDemandOvrdFromDay ;            option clear = nodeDemandOvrdFromMonth ;         option clear = nodeDemandOvrdFromYear ;
  option clear = nodeDemandOvrdToDay ;              option clear = nodeDemandOvrdToMonth ;           option clear = nodeDemandOvrdToYear ;
  option clear = nodeDemandOvrdFromGDate ;          option clear = nodeDemandOvrdToGDate ;

NodeDemandOvrdFromDay(ovrd,n) = sum((day,mth,yr)$i_nodeDemandOvrdFromDate(ovrd,n,day,mth,yr), ord(day)) ;
NodeDemandOvrdFromMonth(ovrd,n) = sum((day,mth,yr)$i_nodeDemandOvrdFromDate(ovrd,n,day,mth,yr), ord(mth)) ;
NodeDemandOvrdFromYear(ovrd,n) = sum((day,mth,yr)$i_nodeDemandOvrdFromDate(ovrd,n,day,mth,yr), ord(yr) + startYear) ;

NodeDemandOvrdToDay(ovrd,n) = sum((toDay,toMth,toYr)$i_nodeDemandOvrdToDate(ovrd,n,toDay,toMth,toYr), ord(toDay)) ;
NodeDemandOvrdToMonth(ovrd,n) = sum((toDay,toMth,toYr)$i_nodeDemandOvrdToDate(ovrd,n,toDay,toMth,toYr), ord(toMth)) ;
NodeDemandOvrdToYear(ovrd,n) = sum((toDay,toMth,toYr)$i_nodeDemandOvrdToDate(ovrd,n,toDay,toMth,toYr), ord(toYr) + startYear) ;

NodeDemandOvrdFromGDate(ovrd,n)$sum((day,mth,yr)$i_nodeDemandOvrdFromDate(ovrd,n,day,mth,yr), 1) = jdate(NodeDemandOvrdFromYear(ovrd,n), nodeDemandOvrdFromMonth(ovrd,n), nodeDemandOvrdFromDay(ovrd,n)) ;
NodeDemandOvrdToGDate(ovrd,n)$sum((toDay,toMth,toYr)$i_nodeDemandOvrdToDate(ovrd,n,toDay,toMth,toYr), 1) = jdate(NodeDemandOvrdToYear(ovrd,n), nodeDemandOvrdToMonth(ovrd,n), nodeDemandOvrdToDay(ovrd,n)) ;

* Apply the node demand overrides
loop((ovrd,n)$((NodeDemandOvrdFromGDate(ovrd,n) <= inputGDXgdate) and (NodeDemandOvrdToGDate(ovrd,n) >= inputGDXgdate) and (i_nodeMWDemandOvrd(ovrd,n) or i_nodePercDemandOvrd(ovrd,n))),

* MW override to node loads
    if (((i_nodeMWDemandOvrd(ovrd,n) > 0) or (i_nodeMWDemandOvrd(ovrd,n) < 0)),
       tradePeriodNodeDemandOvrd(tp,n)$i_nodeDemandOvrdTP(ovrd,n,tp) =  i_nodeMWDemandOvrd(ovrd,n) ;
    elseif (i_nodeMWDemandOvrd(ovrd,n) = eps),
       tradePeriodNodeDemandOvrd(tp,n)$i_nodeDemandOvrdTP(ovrd,n,tp) = eps ;
    ) ;

* Percentage override to node loads
    if (((i_nodePercDemandOvrd(ovrd,n) > 0) or (i_nodePercDemandOvrd(ovrd,n) < 0)),
       tradePeriodNodeDemandOvrd(tp,n)$i_nodeDemandOvrdTP(ovrd,n,tp) =  (1+(i_nodePercDemandOvrd(ovrd,n)/100)) * tradePeriodNodeDemandOrig(tp,n) ;
    elseif (i_nodeMWDemandOvrd(ovrd,n) = eps),
       tradePeriodNodeDemandOvrd(tp,n)$i_nodeDemandOvrdTP(ovrd,n,tp) = eps ;
    ) ;
) ;

* Calculate the from and to date for the node demand override
  option clear = nodeDemandOvrdFromDay ;            option clear = nodeDemandOvrdFromMonth ;         option clear = nodeDemandOvrdFromYear ;
  option clear = nodeDemandOvrdToDay ;              option clear = nodeDemandOvrdToMonth ;           option clear = nodeDemandOvrdToYear ;
  option clear = nodeDemandOvrdFromGDate ;          option clear = nodeDemandOvrdToGDate ;

* Apply the demand override
i_tradePeriodNodeDemand(tp,n)$TradePeriodNodeDemandOvrd(tp,n) = tradePeriodNodeDemandOvrd(tp,n) ;
i_tradePeriodNodeDemand(tp,n)$(tradePeriodNodeDemandOvrd(tp,n) and (tradePeriodNodeDemandOvrd(tp,n) = eps)) = 0 ;
  option clear = tradePeriodNodeDemandOvrd ;        option clear = tradePeriodNodeDemandOrig ;       option clear = tradePeriodNodeIslandTemp ;
  option clear = tradePeriodPosislandDemand ;       option clear = tradePeriodNegislandDemand ;      option clear = tradePeriodNetislandDemand ;

*+++ End demand override +++

*+++ Start branch override +++

* Reset the branch override parameters
  option clear = BranchOvrdFromDay ;                option clear = BranchOvrdFromMonth ;             option clear = BranchOvrdFromYear ;
  option clear = BranchOvrdToDay ;                  option clear = BranchOvrdToMonth ;               option clear = BranchOvrdToYear ;
  option clear = BranchOvrdFromGDate ;              option clear = BranchOvrdToGDate ;

* Calculate the from and to date for the branch parameter override
BranchOvrdFromDay(ovrd,br) = sum((day,mth,yr)$i_BranchParamOvrdFromDate(ovrd,br,day,mth,yr), ord(day)) ;
BranchOvrdFromMonth(ovrd,br) = sum((day,mth,yr)$i_BranchParamOvrdFromDate(ovrd,br,day,mth,yr), ord(mth)) ;
BranchOvrdFromYear(ovrd,br) = sum((day,mth,yr)$i_BranchParamOvrdFromDate(ovrd,br,day,mth,yr), ord(yr) + startYear) ;

BranchOvrdToDay(ovrd,br) = sum((toDay,toMth,toYr)$i_BranchParamOvrdToDate(ovrd,br,toDay,toMth,toYr), ord(toDay)) ;
BranchOvrdToMonth(ovrd,br) = sum((toDay,toMth,toYr)$i_BranchParamOvrdToDate(ovrd,br,toDay,toMth,toYr), ord(toMth)) ;
BranchOvrdToYear(ovrd,br) = sum((toDay,toMth,toYr)$i_BranchParamOvrdToDate(ovrd,br,toDay,toMth,toYr), ord(toYr) + startYear) ;

BranchOvrdFromGDate(ovrd,br)$sum((day,mth,yr)$i_BranchParamOvrdFromDate(ovrd,br,day,mth,yr), 1) = jdate(BranchOvrdFromYear(ovrd,br), BranchOvrdFromMonth(ovrd,br), BranchOvrdFromDay(ovrd,br)) ;
BranchOvrdToGDate(ovrd,br)$sum((toDay,toMth,toYr)$i_BranchParamOvrdToDate(ovrd,br,toDay,toMth,toYr), 1) = jdate(BranchOvrdToYear(ovrd,br), BranchOvrdToMonth(ovrd,br), BranchOvrdToDay(ovrd,br)) ;

* Determine if all the conditions for the branch parameter override are satisfied
loop((ovrd,tp,br,i_BranchParameter)$(i_studyTradePeriod(tp) and (BranchOvrdFromGDate(ovrd,br) <= inputGDXgdate) and (BranchOvrdToGDate(ovrd,br) >= inputGDXgdate) and i_BranchParamOvrdTP(ovrd,br,tp) and i_BranchParamOvrd(ovrd,br,i_BranchParameter)),
    if ((i_BranchParamOvrd(ovrd,br,i_BranchParameter) <> 0),
      tradePeriodBranchParamOvrd(tp,br,i_BranchParameter) = i_BranchParamOvrd(ovrd,br,i_BranchParameter) ;
    elseif (i_BranchParamOvrd(ovrd,br,i_BranchParameter) = eps),
      tradePeriodBranchParamOvrd(tp,br,i_BranchParameter) = eps ;
    ) ;
) ;

* Reset the branch override parameters
  option clear = BranchOvrdFromDay ;                option clear = BranchOvrdFromMonth ;             option clear = BranchOvrdFromYear ;
  option clear = BranchOvrdToDay ;                  option clear = BranchOvrdToMonth ;               option clear = BranchOvrdToYear ;
  option clear = BranchOvrdFromGDate ;              option clear = BranchOvrdToGDate ;

* Apply the branch parameter override
i_tradePeriodBranchParameter(tp,br,i_BranchParameter)$ (tradePeriodBranchParamOvrd(tp,br,i_BranchParameter) <> 0) = tradePeriodBranchParamOvrd(tp,br,i_BranchParameter) ;
i_tradePeriodBranchParameter(tp,br,i_BranchParameter)$(tradePeriodBranchParamOvrd(tp,br,i_BranchParameter) and (tradePeriodBranchParamOvrd(tp,br,i_BranchParameter) = eps)) = 0 ;
  option clear = tradePeriodBranchParamOvrd ;

* Calculate the from and to date for the branch capacity override
BranchOvrdFromDay(ovrd,br) = sum((day,mth,yr)$i_BranchCapacityOvrdFromDate(ovrd,br,day,mth,yr), ord(day)) ;
BranchOvrdFromMonth(ovrd,br) = sum((day,mth,yr)$i_BranchCapacityOvrdFromDate(ovrd,br,day,mth,yr), ord(mth)) ;
BranchOvrdFromYear(ovrd,br) = sum((day,mth,yr)$i_BranchCapacityOvrdFromDate(ovrd,br,day,mth,yr), ord(yr) + startYear) ;

BranchOvrdToDay(ovrd,br) = sum((toDay,toMth,toYr)$i_BranchCapacityOvrdToDate(ovrd,br,toDay,toMth,toYr), ord(toDay)) ;
BranchOvrdToMonth(ovrd,br) = sum((toDay,toMth,toYr)$i_BranchCapacityOvrdToDate(ovrd,br,toDay,toMth,toYr), ord(toMth)) ;
BranchOvrdToYear(ovrd,br) = sum((toDay,toMth,toYr)$i_BranchCapacityOvrdToDate(ovrd,br,toDay,toMth,toYr), ord(toYr) + startYear) ;

BranchOvrdFromGDate(ovrd,br)$sum((day,mth,yr)$i_BranchCapacityOvrdFromDate(ovrd,br,day,mth,yr), 1) = jdate(BranchOvrdFromYear(ovrd,br), BranchOvrdFromMonth(ovrd,br), BranchOvrdFromDay(ovrd,br)) ;
BranchOvrdToGDate(ovrd,br)$sum((toDay,toMth,toYr)$i_BranchCapacityOvrdToDate(ovrd,br,toDay,toMth,toYr), 1) = jdate(BranchOvrdToYear(ovrd,br), BranchOvrdToMonth(ovrd,br), BranchOvrdToDay(ovrd,br)) ;

* Determine if all the conditions for the branch capacity are satisfied
loop((ovrd,tp,br)$(i_studyTradePeriod(tp) and (BranchOvrdFromGDate(ovrd,br) <= inputGDXgdate) and (BranchOvrdToGDate(ovrd,br) >= inputGDXgdate) and i_BranchCapacityOvrdTP(ovrd,br,tp) and i_BranchCapacityOvrd(ovrd,br)),
    if ((i_BranchCapacityOvrd(ovrd,br) > 0),
      tradePeriodBranchCapacityOvrd(tp,br) = i_BranchCapacityOvrd(ovrd,br) ;
    elseif (i_BranchCapacityOvrd(ovrd,br) = eps),
      tradePeriodBranchCapacityOvrd(tp,br) = eps ;
    ) ;
) ;

* Reset the branch override parameters
  option clear = BranchOvrdFromDay ;                option clear = BranchOvrdFromMonth ;             option clear = BranchOvrdFromYear ;
  option clear = BranchOvrdToDay ;                  option clear = BranchOvrdToMonth ;               option clear = BranchOvrdToYear ;
  option clear = BranchOvrdFromGDate ;              option clear = BranchOvrdToGDate ;

* Apply the branch capacity override
i_tradePeriodBranchCapacity(tp,br)$ (tradePeriodBranchCapacityOvrd(tp,br) > 0) = tradePeriodBranchCapacityOvrd(tp,br) ;
i_tradePeriodBranchCapacity(tp,br)$(tradePeriodBranchCapacityOvrd(tp,br) and (tradePeriodBranchCapacityOvrd(tp,br) = eps)) = 0 ;
  option clear = tradePeriodBranchCapacityOvrd ;

* Calculate the from and to date for the branch open status override
BranchOvrdFromDay(ovrd,br) = sum((day,mth,yr)$i_BranchOpenStatusOvrdFromDate(ovrd,br,day,mth,yr), ord(day)) ;
BranchOvrdFromMonth(ovrd,br) = sum((day,mth,yr)$i_BranchOpenStatusOvrdFromDate(ovrd,br,day,mth,yr), ord(mth)) ;
BranchOvrdFromYear(ovrd,br) = sum((day,mth,yr)$i_BranchOpenStatusOvrdFromDate(ovrd,br,day,mth,yr), ord(yr) + startYear) ;

BranchOvrdToDay(ovrd,br) = sum((toDay,toMth,toYr)$i_BranchOpenStatusOvrdToDate(ovrd,br,toDay,toMth,toYr), ord(toDay)) ;
BranchOvrdToMonth(ovrd,br) = sum((toDay,toMth,toYr)$i_BranchOpenStatusOvrdToDate(ovrd,br,toDay,toMth,toYr), ord(toMth)) ;
BranchOvrdToYear(ovrd,br) = sum((toDay,toMth,toYr)$i_BranchOpenStatusOvrdToDate(ovrd,br,toDay,toMth,toYr), ord(toYr) + startYear) ;

BranchOvrdFromGDate(ovrd,br)$sum((day,mth,yr)$i_BranchOpenStatusOvrdFromDate(ovrd,br,day,mth,yr), 1) = jdate(BranchOvrdFromYear(ovrd,br), BranchOvrdFromMonth(ovrd,br), BranchOvrdFromDay(ovrd,br)) ;
BranchOvrdToGDate(ovrd,br)$sum((toDay,toMth,toYr)$i_BranchOpenStatusOvrdToDate(ovrd,br,toDay,toMth,toYr), 1) = jdate(BranchOvrdToYear(ovrd,br), BranchOvrdToMonth(ovrd,br), BranchOvrdToDay(ovrd,br)) ;

* Determine if all the conditions for the branch open status are satisfied
loop((ovrd,tp,br)$(i_studyTradePeriod(tp) and (BranchOvrdFromGDate(ovrd,br) <= inputGDXgdate) and (BranchOvrdToGDate(ovrd,br) >= inputGDXgdate) and i_BranchOpenStatusOvrdTP(ovrd,br,tp) and i_BranchOpenStatusOvrd(ovrd,br)),
    if ((i_BranchOpenStatusOvrd(ovrd,br) > 0),
      tradePeriodBranchOpenStatusOvrd(tp,br) = i_BranchOpenStatusOvrd(ovrd,br) ;
    elseif (i_BranchOpenStatusOvrd(ovrd,br) = eps),
      tradePeriodBranchOpenStatusOvrd(tp,br) = eps ;
    ) ;
) ;

* Reset the branch override parameters
  option clear = BranchOvrdFromDay ;                option clear = BranchOvrdFromMonth ;             option clear = BranchOvrdFromYear ;
  option clear = BranchOvrdToDay ;                  option clear = BranchOvrdToMonth ;               option clear = BranchOvrdToYear ;
  option clear = BranchOvrdFromGDate ;              option clear = BranchOvrdToGDate ;

* Apply the branch open status override
i_tradePeriodBranchOpenStatus(tp,br)$(tradePeriodBranchOpenStatusOvrd(tp,br) > 0) = tradePeriodBranchOpenStatusOvrd(tp,br) ;
i_tradePeriodBranchOpenStatus(tp,br)$(tradePeriodBranchOpenStatusOvrd(tp,br) and (tradePeriodBranchOpenStatusOvrd(tp,br) = eps)) = 0 ;
  option clear = tradePeriodBranchOpenStatusOvrd ;

*+++ End branch override +++

*+++ Start branch constraint override +++

* Reset the branch constraint factor override parameters
  option clear = BranchConstraintFactorOvrdFromDay ;        option clear = BranchConstraintFactorOvrdFromMonth ;     option clear = BranchConstraintFactorOvrdFromYear ;
  option clear = BranchConstraintFactorOvrdToDay ;          option clear = BranchConstraintFactorOvrdToMonth ;       option clear = BranchConstraintFactorOvrdToYear ;
  option clear = BranchConstraintFactorOvrdFromGDate ;      option clear = BranchConstraintFactorOvrdToGDate ;

* Calculate the from and to date for the branch constraint factor override
BranchConstraintFactorOvrdFromDay(ovrd,brCstr,br) = sum((day,mth,yr)$i_BranchConstraintFactorOvrdFromDate(ovrd,brCstr,br,day,mth,yr), ord(day)) ;
BranchConstraintFactorOvrdFromMonth(ovrd,brCstr,br) = sum((day,mth,yr)$i_BranchConstraintFactorOvrdFromDate(ovrd,brCstr,br,day,mth,yr), ord(mth)) ;
BranchConstraintFactorOvrdFromYear(ovrd,brCstr,br) = sum((day,mth,yr)$i_BranchConstraintFactorOvrdFromDate(ovrd,brCstr,br,day,mth,yr), ord(yr) + startYear) ;

BranchConstraintFactorOvrdToDay(ovrd,brCstr,br) = sum((toDay,toMth,toYr)$i_BranchConstraintFactorOvrdToDate(ovrd,brCstr,br,toDay,toMth,toYr), ord(toDay)) ;
BranchConstraintFactorOvrdToMonth(ovrd,brCstr,br) = sum((toDay,toMth,toYr)$i_BranchConstraintFactorOvrdToDate(ovrd,brCstr,br,toDay,toMth,toYr), ord(toMth)) ;
BranchConstraintFactorOvrdToYear(ovrd,brCstr,br) = sum((toDay,toMth,toYr)$i_BranchConstraintFactorOvrdToDate(ovrd,brCstr,br,toDay,toMth,toYr), ord(toYr) + startYear) ;

BranchConstraintFactorOvrdFromGDate(ovrd,brCstr,br)$sum((day,mth,yr)$i_BranchConstraintFactorOvrdFromDate(ovrd,brCstr,br,day,mth,yr), 1) = jdate(BranchConstraintFactorOvrdFromYear(ovrd,brCstr,br), BranchConstraintFactorOvrdFromMonth(ovrd,brCstr,br), BranchConstraintFactorOvrdFromDay(ovrd,brCstr,br)) ;
BranchConstraintFactorOvrdToGDate(ovrd,brCstr,br)$sum((toDay,toMth,toYr)$i_BranchConstraintFactorOvrdToDate(ovrd,brCstr,br,toDay,toMth,toYr), 1) = jdate(BranchConstraintFactorOvrdToYear(ovrd,brCstr,br), BranchConstraintFactorOvrdToMonth(ovrd,brCstr,br), BranchConstraintFactorOvrdToDay(ovrd,brCstr,br)) ;

* Determine if all the conditions for the branch constraint factor are satisfied
loop((ovrd,tp,brCstr,br)$(i_studyTradePeriod(tp) and (BranchConstraintFactorOvrdFromGDate(ovrd,brCstr,br) <= inputGDXgdate) and (BranchConstraintFactorOvrdToGDate(ovrd,brCstr,br) >= inputGDXgdate) and i_BranchConstraintFactorOvrdTP(ovrd,brCstr,br,tp) and brCstrFactorOvrd(ovrd,brCstr,br)),
    if ((i_BranchConstraintFactorOvrd(ovrd,brCstr,br) <> 0),
      tradePeriodBranchConstraintFactorOvrd(tp,brCstr,br) = i_BranchConstraintFactorOvrd(ovrd,brCstr,br) ;
    elseif (i_BranchConstraintFactorOvrd(ovrd,brCstr,br) = eps),
      tradePeriodBranchConstraintFactorOvrd(tp,brCstr,br) = eps ;
    ) ;
) ;

* Reset the branch constraint factor override parameters
  option clear = BranchConstraintFactorOvrdFromDay ;        option clear = BranchConstraintFactorOvrdFromMonth ;     option clear = BranchConstraintFactorOvrdFromYear ;
  option clear = BranchConstraintFactorOvrdToDay ;          option clear = BranchConstraintFactorOvrdToMonth ;       option clear = BranchConstraintFactorOvrdToYear ;
  option clear = BranchConstraintFactorOvrdFromGDate ;      option clear = BranchConstraintFactorOvrdToGDate ;

* Apply the branch constraint factor override
i_tradePeriodBranchConstraintFactors(tp,brCstr,br)$(tradePeriodBranchConstraintFactorOvrd(tp,brCstr,br) <> 0) = tradePeriodBranchConstraintFactorOvrd(tp,brCstr,br) ;
i_tradePeriodBranchConstraintFactors(tp,brCstr,br)$(tradePeriodBranchConstraintFactorOvrd(tp,brCstr,br) and (tradePeriodBranchConstraintFactorOvrd(tp,brCstr,br) = eps)) = 0 ;
  option clear = tradePeriodBranchConstraintFactorOvrd ;

* Reset the branch constraint RHS override parameters
  option clear = BranchConstraintRHSOvrdFromDay ;           option clear = BranchConstraintRHSOvrdFromMonth ;        option clear = BranchConstraintRHSOvrdFromYear ;
  option clear = BranchConstraintRHSOvrdToDay ;             option clear = BranchConstraintRHSOvrdToMonth ;          option clear = BranchConstraintRHSOvrdToYear ;
  option clear = BranchConstraintRHSOvrdFromGDate ;         option clear = BranchConstraintRHSOvrdToGDate ;

* Calculate the from and to date for the branch constraint RHS override
BranchConstraintRHSOvrdFromDay(ovrd,brCstr) = sum((day,mth,yr)$i_BranchConstraintRHSOvrdFromDate(ovrd,brCstr,day,mth,yr), ord(day)) ;
BranchConstraintRHSOvrdFromMonth(ovrd,brCstr) = sum((day,mth,yr)$i_BranchConstraintRHSOvrdFromDate(ovrd,brCstr,day,mth,yr), ord(mth)) ;
BranchConstraintRHSOvrdFromYear(ovrd,brCstr) = sum((day,mth,yr)$i_BranchConstraintRHSOvrdFromDate(ovrd,brCstr,day,mth,yr), ord(yr) + startYear) ;

BranchConstraintRHSOvrdToDay(ovrd,brCstr) = sum((toDay,toMth,toYr)$i_BranchConstraintRHSOvrdToDate(ovrd,brCstr,toDay,toMth,toYr), ord(toDay)) ;
BranchConstraintRHSOvrdToMonth(ovrd,brCstr) = sum((toDay,toMth,toYr)$i_BranchConstraintRHSOvrdToDate(ovrd,brCstr,toDay,toMth,toYr), ord(toMth)) ;
BranchConstraintRHSOvrdToYear(ovrd,brCstr) = sum((toDay,toMth,toYr)$i_BranchConstraintRHSOvrdToDate(ovrd,brCstr,toDay,toMth,toYr), ord(toYr) + startYear) ;

BranchConstraintRHSOvrdFromGDate(ovrd,brCstr)$sum((day,mth,yr)$i_BranchConstraintRHSOvrdFromDate(ovrd,brCstr,day,mth,yr), 1) = jdate(BranchConstraintRHSOvrdFromYear(ovrd,brCstr), BranchConstraintRHSOvrdFromMonth(ovrd,brCstr), BranchConstraintRHSOvrdFromDay(ovrd,brCstr)) ;
BranchConstraintRHSOvrdToGDate(ovrd,brCstr)$sum((toDay,toMth,toYr)$i_BranchConstraintRHSOvrdToDate(ovrd,brCstr,toDay,toMth,toYr), 1) = jdate(BranchConstraintRHSOvrdToYear(ovrd,brCstr), BranchConstraintRHSOvrdToMonth(ovrd,brCstr), BranchConstraintRHSOvrdToDay(ovrd,brCstr)) ;

* Determine if all the conditions for the branch constraint RHS are satisfied
loop((ovrd,tp,brCstr,i_constraintRHS)$(i_studyTradePeriod(tp) and (BranchConstraintRHSOvrdFromGDate(ovrd,brCstr) <= inputGDXgdate) and (BranchConstraintRHSOvrdToGDate(ovrd,brCstr) >= inputGDXgdate) and i_BranchConstraintRHSOvrdTP(ovrd,brCstr,tp) and i_BranchConstraintRHSOvrd(ovrd,brCstr,i_constraintRHS)),
    if ((i_BranchConstraintRHSOvrd(ovrd,brCstr,i_constraintRHS) <> 0),
      tradePeriodBranchConstraintRHSOvrd(tp,brCstr,i_constraintRHS) = i_BranchConstraintRHSOvrd(ovrd,brCstr,i_constraintRHS) ;
    elseif (i_BranchConstraintRHSOvrd(ovrd,brCstr,i_constraintRHS) = eps),
      tradePeriodBranchConstraintRHSOvrd(tp,brCstr,i_constraintRHS) = eps ;
    ) ;
) ;

* Reset the branch constraint RHS override parameters
  option clear = BranchConstraintRHSOvrdFromDay ;           option clear = BranchConstraintRHSOvrdFromMonth ;        option clear = BranchConstraintRHSOvrdFromYear ;
  option clear = BranchConstraintRHSOvrdToDay ;             option clear = BranchConstraintRHSOvrdToMonth ;          option clear = BranchConstraintRHSOvrdToYear ;
  option clear = BranchConstraintRHSOvrdFromGDate ;         option clear = BranchConstraintRHSOvrdToGDate ;

* Apply the branch constraint RHS override
i_tradePeriodBranchConstraintRHS(tp,brCstr,i_constraintRHS)$(tradePeriodBranchConstraintRHSOvrd(tp,brCstr,i_constraintRHS) <> 0) = tradePeriodBranchConstraintRHSOvrd(tp,brCstr,i_constraintRHS) ;
i_tradePeriodBranchConstraintRHS(tp,brCstr,i_constraintRHS)$(tradePeriodBranchConstraintRHSOvrd(tp,brCstr,i_constraintRHS) and (tradePeriodBranchConstraintRHSOvrd(tp,brCstr,i_constraintRHS) = eps)) = 0 ;
  option clear = tradePeriodBranchConstraintRHSOvrd ;

*+++ End branch constraint override +++

*+++ Start market node constraint override +++

* Reset the market node energy constraint factor override parameters
  option clear = MnodeEnergyConstraintFactorOvrdFromDay ;   option clear = MnodeEnergyConstraintFactorOvrdFromMonth ;        option clear = MnodeEnergyConstraintFactorOvrdFromYear ;
  option clear = MnodeEnergyConstraintFactorOvrdToDay ;     option clear = MnodeEnergyConstraintFactorOvrdToMonth ;          option clear = MnodeEnergyConstraintFactorOvrdToYear ;
  option clear = MnodeEnergyConstraintFactorOvrdFromGDate ; option clear = MnodeEnergyConstraintFactorOvrdToGDate ;

* Calculate the from and to date for the market node energy constraint factor override
MnodeEnergyConstraintFactorOvrdFromDay(ovrd,MnodeCstr,o) = sum((day,mth,yr)$i_MnodeEnergyConstraintFactorOvrdFromDate(ovrd,MnodeCstr,o,day,mth,yr), ord(day)) ;
MnodeEnergyConstraintFactorOvrdFromMonth(ovrd,MnodeCstr,o) = sum((day,mth,yr)$i_MnodeEnergyConstraintFactorOvrdFromDate(ovrd,MnodeCstr,o,day,mth,yr), ord(mth)) ;
MnodeEnergyConstraintFactorOvrdFromYear(ovrd,MnodeCstr,o) = sum((day,mth,yr)$i_MnodeEnergyConstraintFactorOvrdFromDate(ovrd,MnodeCstr,o,day,mth,yr), ord(yr) + startYear) ;

MnodeEnergyConstraintFactorOvrdToDay(ovrd,MnodeCstr,o) = sum((toDay,toMth,toYr)$i_MnodeEnergyConstraintFactorOvrdToDate(ovrd,MnodeCstr,o,toDay,toMth,toYr), ord(toDay)) ;
MnodeEnergyConstraintFactorOvrdToMonth(ovrd,MnodeCstr,o) = sum((toDay,toMth,toYr)$i_MnodeEnergyConstraintFactorOvrdToDate(ovrd,MnodeCstr,o,toDay,toMth,toYr), ord(toMth)) ;
MnodeEnergyConstraintFactorOvrdToYear(ovrd,MnodeCstr,o) = sum((toDay,toMth,toYr)$i_MnodeEnergyConstraintFactorOvrdToDate(ovrd,MnodeCstr,o,toDay,toMth,toYr), ord(toYr) + startYear) ;

MnodeEnergyConstraintFactorOvrdFromGDate(ovrd,MnodeCstr,o)$sum((day,mth,yr)$i_MnodeEnergyConstraintFactorOvrdFromDate(ovrd,MnodeCstr,o,day,mth,yr), 1) = jdate(MnodeEnergyConstraintFactorOvrdFromYear(ovrd,MnodeCstr,o), MnodeEnergyConstraintFactorOvrdFromMonth(ovrd,MnodeCstr,o), MnodeEnergyConstraintFactorOvrdFromDay(ovrd,MnodeCstr,o)) ;
MnodeEnergyConstraintFactorOvrdToGDate(ovrd,MnodeCstr,o)$sum((toDay,toMth,toYr)$i_MnodeEnergyConstraintFactorOvrdToDate(ovrd,MnodeCstr,o,toDay,toMth,toYr), 1) = jdate(MnodeEnergyConstraintFactorOvrdToYear(ovrd,MnodeCstr,o), MnodeEnergyConstraintFactorOvrdToMonth(ovrd,MnodeCstr,o), MnodeEnergyConstraintFactorOvrdToDay(ovrd,MnodeCstr,o)) ;

* Determine if all the conditions for the market node energy constraint factor are satisfied
loop((ovrd,tp,MnodeCstr,o)$(i_studyTradePeriod(tp) and (MnodeEnergyConstraintFactorOvrdFromGDate(ovrd,MnodeCstr,o) <= inputGDXgdate) and (MnodeEnergyConstraintFactorOvrdToGDate(ovrd,MnodeCstr,o) >= inputGDXgdate) and i_MnodeEnergyConstraintFactorOvrdTP(ovrd,MnodeCstr,o,tp) and i_MnodeEnergyConstraintFactorOvrd(ovrd,MnodeCstr,o)),
    if ((i_MnodeEnergyConstraintFactorOvrd(ovrd,MnodeCstr,o) <> 0),
      tradePeriodMnodeEnergyConstraintFactorOvrd(tp,MnodeCstr,o) = i_MnodeEnergyConstraintFactorOvrd(ovrd,MnodeCstr,o) ;
    elseif (i_MnodeEnergyConstraintFactorOvrd(ovrd,MnodeCstr,o) = eps),
      tradePeriodMnodeEnergyConstraintFactorOvrd(tp,MnodeCstr,o) = eps ;
    ) ;
) ;

* Reset the market node energy constraint factor override parameters
  option clear = MnodeEnergyConstraintFactorOvrdFromDay ;   option clear = MnodeEnergyConstraintFactorOvrdFromMonth ;        option clear = MnodeEnergyConstraintFactorOvrdFromYear ;
  option clear = MnodeEnergyConstraintFactorOvrdToDay ;     option clear = MnodeEnergyConstraintFactorOvrdToMonth ;          option clear = MnodeEnergyConstraintFactorOvrdToYear ;
  option clear = MnodeEnergyConstraintFactorOvrdFromGDate ; option clear = MnodeEnergyConstraintFactorOvrdToGDate ;

* Apply the market node energy constraint factor override
i_tradePeriodMnodeEnergyOfferConstraintFactors(tp,MnodeCstr,o)$(tradePeriodMnodeEnergyConstraintFactorOvrd(tp,MnodeCstr,o) <> 0) = tradePeriodMnodeEnergyConstraintFactorOvrd(tp,MnodeCstr,o) ;
i_tradePeriodMnodeEnergyOfferConstraintFactors(tp,MnodeCstr,o)$(tradePeriodMnodeEnergyConstraintFactorOvrd(tp,MnodeCstr,o) and (tradePeriodMnodeEnergyConstraintFactorOvrd(tp,MnodeCstr,o) = eps)) = 0 ;
  option clear = tradePeriodMnodeEnergyConstraintFactorOvrd ;

* Reset the market node reserve constraint factor override parameters
  option clear = MnodeReserveConstraintFactorOvrdFromDay ;          option clear = MnodeReserveConstraintFactorOvrdFromMonth ;       option clear = MnodeReserveConstraintFactorOvrdFromYear ;
  option clear = MnodeReserveConstraintFactorOvrdToDay ;            option clear = MnodeReserveConstraintFactorOvrdToMonth ;         option clear = MnodeReserveConstraintFactorOvrdToYear ;
  option clear = MnodeReserveConstraintFactorOvrdFromGDate ;        option clear = MnodeReserveConstraintFactorOvrdToGDate ;

* Calculate the from and to date for the market node reserve constraint factor override
MnodeReserveConstraintFactorOvrdFromDay(ovrd,MnodeCstr,o,i_reserveClass) = sum((day,mth,yr)$i_MnodeReserveConstraintFactorOvrdFromDate(ovrd,MnodeCstr,o,i_reserveClass,day,mth,yr), ord(day)) ;
MnodeReserveConstraintFactorOvrdFromMonth(ovrd,MnodeCstr,o,i_reserveClass) = sum((day,mth,yr)$i_MnodeReserveConstraintFactorOvrdFromDate(ovrd,MnodeCstr,o,i_reserveClass,day,mth,yr), ord(mth)) ;
MnodeReserveConstraintFactorOvrdFromYear(ovrd,MnodeCstr,o,i_reserveClass) = sum((day,mth,yr)$i_MnodeReserveConstraintFactorOvrdFromDate(ovrd,MnodeCstr,o,i_reserveClass,day,mth,yr), ord(yr) + startYear) ;

MnodeReserveConstraintFactorOvrdToDay(ovrd,MnodeCstr,o,i_reserveClass) = sum((toDay,toMth,toYr)$i_MnodeReserveConstraintFactorOvrdToDate(ovrd,MnodeCstr,o,i_reserveClass,toDay,toMth,toYr), ord(toDay)) ;
MnodeReserveConstraintFactorOvrdToMonth(ovrd,MnodeCstr,o,i_reserveClass) = sum((toDay,toMth,toYr)$i_MnodeReserveConstraintFactorOvrdToDate(ovrd,MnodeCstr,o,i_reserveClass,toDay,toMth,toYr), ord(toMth)) ;
MnodeReserveConstraintFactorOvrdToYear(ovrd,MnodeCstr,o,i_reserveClass) = sum((toDay,toMth,toYr)$i_MnodeReserveConstraintFactorOvrdToDate(ovrd,MnodeCstr,o,i_reserveClass,toDay,toMth,toYr), ord(toYr) + startYear) ;

MnodeReserveConstraintFactorOvrdFromGDate(ovrd,MnodeCstr,o,i_reserveClass)$sum((day,mth,yr)$i_MnodeReserveConstraintFactorOvrdFromDate(ovrd,MnodeCstr,o,i_reserveClass,day,mth,yr), 1) = jdate(MnodeReserveConstraintFactorOvrdFromYear(ovrd,MnodeCstr,o,i_reserveClass), MnodeReserveConstraintFactorOvrdFromMonth(ovrd,MnodeCstr,o,i_reserveClass), MnodeReserveConstraintFactorOvrdFromDay(ovrd,MnodeCstr,o,i_reserveClass)) ;
MnodeReserveConstraintFactorOvrdToGDate(ovrd,MnodeCstr,o,i_reserveClass)$sum((toDay,toMth,toYr)$i_MnodeReserveConstraintFactorOvrdToDate(ovrd,MnodeCstr,o,i_reserveClass,toDay,toMth,toYr), 1) = jdate(MnodeReserveConstraintFactorOvrdToYear(ovrd,MnodeCstr,o,i_reserveClass), MnodeReserveConstraintFactorOvrdToMonth(ovrd,MnodeCstr,o,i_reserveClass), MnodeReserveConstraintFactorOvrdToDay(ovrd,MnodeCstr,o,i_reserveClass)) ;

* Determine if all the conditions for the market node reserve constraint factor are satisfied
loop((ovrd,tp,MnodeCstr,o,i_reserveClass)$(i_studyTradePeriod(tp) and (MnodeReserveConstraintFactorOvrdFromGDate(ovrd,MnodeCstr,o,i_reserveClass) <= inputGDXgdate) and (MnodeReserveConstraintFactorOvrdToGDate(ovrd,MnodeCstr,o,i_reserveClass) >= inputGDXgdate) and i_MnodeReserveConstraintFactorOvrdTP(ovrd,MnodeCstr,o,i_reserveClass,tp) and i_MnodeReserveConstraintFactorOvrd(ovrd,MnodeCstr,o,i_reserveClass)),
    if ((i_MnodeReserveConstraintFactorOvrd(ovrd,MnodeCstr,o,i_reserveClass) <> 0),
      tradePeriodMnodeReserveConstraintFactorOvrd(tp,MnodeCstr,o,i_reserveClass) = i_MnodeReserveConstraintFactorOvrd(ovrd,MnodeCstr,o,i_reserveClass) ;
    elseif (i_MnodeReserveConstraintFactorOvrd(ovrd,MnodeCstr,o,i_reserveClass) = eps),
      tradePeriodMnodeReserveConstraintFactorOvrd(tp,MnodeCstr,o,i_reserveClass) = eps ;
    ) ;
) ;

* Reset the market node reserve constraint factor override parameters
  option clear = MnodeReserveConstraintFactorOvrdFromDay ;          option clear = MnodeReserveConstraintFactorOvrdFromMonth ;       option clear = MnodeReserveConstraintFactorOvrdFromYear ;
  option clear = MnodeReserveConstraintFactorOvrdToDay ;            option clear = MnodeReserveConstraintFactorOvrdToMonth ;         option clear = MnodeReserveConstraintFactorOvrdToYear ;
  option clear = MnodeReserveConstraintFactorOvrdFromGDate ;        option clear = MnodeReserveConstraintFactorOvrdToGDate ;

* Apply the market node reserve constraint factor override
i_tradePeriodMnodeReserveOfferConstraintFactors(tp,MnodeCstr,o,i_reserveClass,i_reserveType)$(tradePeriodMnodeReserveConstraintFactorOvrd(tp,MnodeCstr,o,i_reserveClass) <> 0) = tradePeriodMnodeReserveConstraintFactorOvrd(tp,MnodeCstr,o,i_reserveClass) ;
i_tradePeriodMnodeReserveOfferConstraintFactors(tp,MnodeCstr,o,i_reserveClass,i_reserveType)$(tradePeriodMnodeReserveConstraintFactorOvrd(tp,MnodeCstr,o,i_reserveClass) and (tradePeriodMnodeReserveConstraintFactorOvrd(tp,MnodeCstr,o,i_reserveClass) = eps)) = 0 ;
  option clear = tradePeriodMnodeReserveConstraintFactorOvrd ;

* Reset the market node reserve constraint RHS override parameters
  option clear = MnodeConstraintRHSOvrdFromDay ;            option clear = MnodeConstraintRHSOvrdFromMonth ;         option clear = MnodeConstraintRHSOvrdFromYear ;
  option clear = MnodeConstraintRHSOvrdToDay ;              option clear = MnodeConstraintRHSOvrdToMonth ;           option clear = MnodeConstraintRHSOvrdToYear ;
  option clear = MnodeConstraintRHSOvrdFromGDate ;          option clear = MnodeConstraintRHSOvrdToGDate ;

* Calculate the from and to date for the market node RHS override
MnodeConstraintRHSOvrdFromDay(ovrd,MnodeCstr) = sum((day,mth,yr)$i_MnodeConstraintRHSOvrdFromDate(ovrd,MnodeCstr,day,mth,yr), ord(day)) ;
MnodeConstraintRHSOvrdFromMonth(ovrd,MnodeCstr) = sum((day,mth,yr)$i_MnodeConstraintRHSOvrdFromDate(ovrd,MnodeCstr,day,mth,yr), ord(mth)) ;
MnodeConstraintRHSOvrdFromYear(ovrd,MnodeCstr) = sum((day,mth,yr)$i_MnodeConstraintRHSOvrdFromDate(ovrd,MnodeCstr,day,mth,yr), ord(yr) + startYear) ;

MnodeConstraintRHSOvrdToDay(ovrd,MnodeCstr) = sum((toDay,toMth,toYr)$i_MnodeConstraintRHSOvrdToDate(ovrd,MnodeCstr,toDay,toMth,toYr), ord(toDay)) ;
MnodeConstraintRHSOvrdToMonth(ovrd,MnodeCstr) = sum((toDay,toMth,toYr)$i_MnodeConstraintRHSOvrdToDate(ovrd,MnodeCstr,toDay,toMth,toYr), ord(toMth)) ;
MnodeConstraintRHSOvrdToYear(ovrd,MnodeCstr) = sum((toDay,toMth,toYr)$i_MnodeConstraintRHSOvrdToDate(ovrd,MnodeCstr,toDay,toMth,toYr), ord(toYr) + startYear) ;

MnodeConstraintRHSOvrdFromGDate(ovrd,MnodeCstr)$sum((day,mth,yr)$i_MnodeConstraintRHSOvrdFromDate(ovrd,MnodeCstr,day,mth,yr), 1) = jdate(MnodeConstraintRHSOvrdFromYear(ovrd,MnodeCstr), MnodeConstraintRHSOvrdFromMonth(ovrd,MnodeCstr), MnodeConstraintRHSOvrdFromDay(ovrd,MnodeCstr)) ;
MnodeConstraintRHSOvrdToGDate(ovrd,MnodeCstr)$sum((toDay,toMth,toYr)$i_MnodeConstraintRHSOvrdToDate(ovrd,MnodeCstr,toDay,toMth,toYr), 1) = jdate(MnodeConstraintRHSOvrdToYear(ovrd,MnodeCstr), MnodeConstraintRHSOvrdToMonth(ovrd,MnodeCstr), MnodeConstraintRHSOvrdToDay(ovrd,MnodeCstr)) ;

* Determine if all the conditions for the market node constraint RHS are satisfied
loop((ovrd,tp,MnodeCstr,i_constraintRHS)$(i_studyTradePeriod(tp) and (MnodeConstraintRHSOvrdFromGDate(ovrd,MnodeCstr) <= inputGDXgdate) and (MnodeConstraintRHSOvrdToGDate(ovrd,MnodeCstr) >= inputGDXgdate) and i_MnodeConstraintRHSOvrdTP(ovrd,MnodeCstr,tp) and i_MnodeConstraintRHSOvrd(ovrd,MnodeCstr,i_constraintRHS)),
    if ((i_MnodeConstraintRHSOvrd(ovrd,MnodeCstr,i_constraintRHS) <> 0),
      tradePeriodMnodeConstraintRHSOvrd(tp,MnodeCstr,i_constraintRHS) = i_MnodeConstraintRHSOvrd(ovrd,MnodeCstr,i_constraintRHS) ;
    elseif (i_MnodeConstraintRHSOvrd(ovrd,MnodeCstr,i_constraintRHS) = eps),
      tradePeriodMnodeConstraintRHSOvrd(tp,MnodeCstr,i_constraintRHS) = eps ;
    ) ;
) ;

* Reset the market node reserve constraint RHS override parameters
  option clear = MnodeConstraintRHSOvrdFromDay ;    option clear = MnodeConstraintRHSOvrdFromMonth ;         option clear = MnodeConstraintRHSOvrdFromYear ;
  option clear = MnodeConstraintRHSOvrdToDay ;      option clear = MnodeConstraintRHSOvrdToMonth ;           option clear = MnodeConstraintRHSOvrdToYear ;
  option clear = MnodeConstraintRHSOvrdFromGDate ;  option clear = MnodeConstraintRHSOvrdToGDate ;

* Market node constraint RHS override
i_tradePeriodMnodeConstraintRHS(tp,MnodeCstr,i_constraintRHS)$(tradePeriodMnodeConstraintRHSOvrd(tp,MnodeCstr,i_constraintRHS) <> 0) = tradePeriodMnodeConstraintRHSOvrd(tp,MnodeCstr,i_constraintRHS) ;
i_tradePeriodMnodeConstraintRHS(tp,MnodeCstr,i_constraintRHS)$(tradePeriodMnodeConstraintRHSOvrd(tp,MnodeCstr,i_constraintRHS) and (tradePeriodMnodeConstraintRHSOvrd(tp,MnodeCstr,i_constraintRHS) = eps)) = 0 ;
  option clear = tradePeriodMnodeConstraintRHSOvrd ;

*+++ End market node constraint override +++

*+++ Start risk/reserve override +++

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

* Calculate the from and to date for the CE RAF override
RAFovrdDay(ovrd,ild,i_reserveClass) = sum((day,mth,yr)$i_contingentEventRAFovrdFromDate(ovrd,ild,i_reserveClass,day,mth,yr), ord(day)) ;
RAFovrdMonth(ovrd,ild,i_reserveClass) = sum((day,mth,yr)$i_contingentEventRAFovrdFromDate(ovrd,ild,i_reserveClass,day,mth,yr), ord(mth)) ;
RAFovrdYear(ovrd,ild,i_reserveClass) = sum((day,mth,yr)$i_contingentEventRAFovrdFromDate(ovrd,ild,i_reserveClass,day,mth,yr), ord(yr) + startYear) ;
CERAFovrdFromGDate(ovrd,ild,i_reserveClass)$sum((day,mth,yr)$i_contingentEventRAFovrdFromDate(ovrd,ild,i_reserveClass,day,mth,yr), 1) = jdate(RAFovrdYear(ovrd,ild,i_reserveClass), RAFovrdMonth(ovrd,ild,i_reserveClass), RAFovrdDay(ovrd,ild,i_reserveClass)) ;

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

RAFovrdDay(ovrd,ild,i_reserveClass) = sum((toDay,toMth,toYr)$i_contingentEventRAFovrdToDate(ovrd,ild,i_reserveClass,toDay,toMth,toYr), ord(toDay)) ;
RAFovrdMonth(ovrd,ild,i_reserveClass) = sum((toDay,toMth,toYr)$i_contingentEventRAFovrdToDate(ovrd,ild,i_reserveClass,toDay,toMth,toYr), ord(toMth)) ;
RAFovrdYear(ovrd,ild,i_reserveClass) = sum((toDay,toMth,toYr)$i_contingentEventRAFovrdToDate(ovrd,ild,i_reserveClass,toDay,toMth,toYr), ord(toYr) + startYear) ;
CERAFovrdToGDate(ovrd,ild,i_reserveClass)$sum((toDay,toMth,toYr)$i_contingentEventRAFovrdToDate(ovrd,ild,i_reserveClass,toDay,toMth,toYr), 1) = jdate(RAFovrdYear(ovrd,ild,i_reserveClass), RAFovrdMonth(ovrd,ild,i_reserveClass), RAFovrdDay(ovrd,ild,i_reserveClass)) ;

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

* Determine if all the conditions for the CE RAF override are satisfied
loop((ovrd,tp,ild,i_reserveClass)$(i_studyTradePeriod(tp) and (CERAFovrdFromGDate(ovrd,ild,i_reserveClass) <= inputGDXgdate) and (CERAFovrdToGDate(ovrd,ild,i_reserveClass) >= inputGDXgdate) and i_contingentEventRAFovrdTP(ovrd,ild,i_reserveClass,tp) and i_contingentEventRAFovrd(ovrd,ild,i_reserveClass)),
    if ((i_contingentEventRAFovrd(ovrd,ild,i_reserveClass) > 0),
      tradePeriodCERAFovrd(tp,ild,i_reserveClass) = i_contingentEventRAFovrd(ovrd,ild,i_reserveClass) ;
    elseif (i_contingentEventRAFovrd(ovrd,ild,i_reserveClass) = eps),
      tradePeriodCERAFovrd(tp,ild,i_reserveClass) = eps ;
    ) ;
) ;

* Apply the CE RAF override
i_tradePeriodRiskParameter(tp,ild,i_reserveClass,'GENRISK','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(tp,ild,i_reserveClass) > 0) = tradePeriodCERAFovrd(tp,ild,i_reserveClass) ;
i_tradePeriodRiskParameter(tp,ild,i_reserveClass,'DCCE','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(tp,ild,i_reserveClass) > 0) = tradePeriodCERAFovrd(tp,ild,i_reserveClass) ;
i_tradePeriodRiskParameter(tp,ild,i_reserveClass,'Manual','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(tp,ild,i_reserveClass) > 0) = tradePeriodCERAFovrd(tp,ild,i_reserveClass) ;
i_tradePeriodRiskParameter(tp,ild,i_reserveClass,'GENRISK','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(tp,ild,i_reserveClass) and (tradePeriodCERAFovrd(tp,ild,i_reserveClass) = eps)) = 0 ;
i_tradePeriodRiskParameter(tp,ild,i_reserveClass,'DCCE','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(tp,ild,i_reserveClass) and (tradePeriodCERAFovrd(tp,ild,i_reserveClass) = eps)) = 0 ;
i_tradePeriodRiskParameter(tp,ild,i_reserveClass,'Manual','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(tp,ild,i_reserveClass) and (tradePeriodCERAFovrd(tp,ild,i_reserveClass) = eps)) = 0 ;
  option clear = tradePeriodCERAFovrd ;

* Calculate the from and to date for the ECE RAF override
RAFovrdDay(ovrd,ild,i_reserveClass) = sum((day,mth,yr)$i_extendedContingentEventRAFovrdFromDate(ovrd,ild,i_reserveClass,day,mth,yr), ord(day)) ;
RAFovrdMonth(ovrd,ild,i_reserveClass) = sum((day,mth,yr)$i_extendedContingentEventRAFovrdFromDate(ovrd,ild,i_reserveClass,day,mth,yr), ord(mth)) ;
RAFovrdYear(ovrd,ild,i_reserveClass) = sum((day,mth,yr)$i_extendedContingentEventRAFovrdFromDate(ovrd,ild,i_reserveClass,day,mth,yr), ord(yr) + startYear) ;
ECERAFovrdFromGDate(ovrd,ild,i_reserveClass)$sum((day,mth,yr)$i_extendedContingentEventRAFovrdFromDate(ovrd,ild,i_reserveClass,day,mth,yr), 1) = jdate(RAFovrdYear(ovrd,ild,i_reserveClass), RAFovrdMonth(ovrd,ild,i_reserveClass), RAFovrdDay(ovrd,ild,i_reserveClass)) ;

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

RAFovrdDay(ovrd,ild,i_reserveClass) = sum((toDay,toMth,toYr)$i_extendedContingentEventRAFovrdToDate(ovrd,ild,i_reserveClass,toDay,toMth,toYr), ord(toDay)) ;
RAFovrdMonth(ovrd,ild,i_reserveClass) = sum((toDay,toMth,toYr)$i_extendedContingentEventRAFovrdToDate(ovrd,ild,i_reserveClass,toDay,toMth,toYr), ord(toMth)) ;
RAFovrdYear(ovrd,ild,i_reserveClass) = sum((toDay,toMth,toYr)$i_extendedContingentEventRAFovrdToDate(ovrd,ild,i_reserveClass,toDay,toMth,toYr), ord(toYr) + startYear) ;
ECERAFovrdToGDate(ovrd,ild,i_reserveClass)$sum((toDay,toMth,toYr)$i_extendedContingentEventRAFovrdToDate(ovrd,ild,i_reserveClass,toDay,toMth,toYr), 1) = jdate(RAFovrdYear(ovrd,ild,i_reserveClass), RAFovrdMonth(ovrd,ild,i_reserveClass), RAFovrdDay(ovrd,ild,i_reserveClass)) ;

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

* Determine if all the conditions for the ECE RAF override are satisfied
loop((ovrd,tp,ild,i_reserveClass)$(i_studyTradePeriod(tp) and (ECERAFovrdFromGDate(ovrd,ild,i_reserveClass) <= inputGDXgdate) and (ECERAFovrdToGDate(ovrd,ild,i_reserveClass) >= inputGDXgdate) and i_extendedContingentEventRAFovrdTP(ovrd,ild,i_reserveClass,tp) and i_extendedContingentEventRAFovrd(ovrd,ild,i_reserveClass)),
    if ((i_extendedContingentEventRAFovrd(ovrd,ild,i_reserveClass) > 0),
      tradePeriodECERAFovrd(tp,ild,i_reserveClass) = i_extendedContingentEventRAFovrd(ovrd,ild,i_reserveClass) ;
    elseif (i_extendedContingentEventRAFovrd(ovrd,ild,i_reserveClass) = eps),
      tradePeriodECERAFovrd(tp,ild,i_reserveClass) = eps ;
    ) ;
) ;

* Reset the RAF override parameters
  option clear = CERAFovrdFromGDate ;       option clear = CERAFovrdToGDate ;        option clear = ECERAFovrdFromGDate ;             option clear = ECERAFovrdToGDate ;

* Apply the ECE RAF override
i_tradePeriodRiskParameter(tp,ild,i_reserveClass,'DCECE','i_riskAdjustmentFactor')$(tradePeriodECERAFovrd(tp,ild,i_reserveClass) > 0) = tradePeriodECERAFovrd(tp,ild,i_reserveClass) ;
i_tradePeriodRiskParameter(tp,ild,i_reserveClass,'DCECE','i_riskAdjustmentFactor')$(tradePeriodECERAFovrd(tp,ild,i_reserveClass) and (tradePeriodECERAFovrd(tp,ild,i_reserveClass) = eps)) = 0 ;
  option clear = tradePeriodECERAFovrd ;

* Reset the CE NFR override parameters
  option clear = CENFRovrdDay ;             option clear = CENFRovrdMonth ;          option clear = CENFRovrdYear ;

* Calculate the from and to date for the CE NFR override
CENFRovrdDay(ovrd,ild,i_reserveClass,i_riskClass) = sum((day,mth,yr)$i_contingentEventNFRovrdFromDate(ovrd,ild,i_reserveClass,i_riskClass,day,mth,yr), ord(day)) ;
CENFRovrdMonth(ovrd,ild,i_reserveClass,i_riskClass) = sum((day,mth,yr)$i_contingentEventNFRovrdFromDate(ovrd,ild,i_reserveClass,i_riskClass,day,mth,yr), ord(mth)) ;
CENFRovrdYear(ovrd,ild,i_reserveClass,i_riskClass) = sum((day,mth,yr)$i_contingentEventNFRovrdFromDate(ovrd,ild,i_reserveClass,i_riskClass,day,mth,yr), ord(yr) + startYear) ;
CENFRovrdFromGDate(ovrd,ild,i_reserveClass,i_riskClass)$sum((day,mth,yr)$i_contingentEventNFRovrdFromDate(ovrd,ild,i_reserveClass,i_riskClass,day,mth,yr), 1) = jdate(CENFRovrdYear(ovrd,ild,i_reserveClass,i_riskClass), CENFRovrdMonth(ovrd,ild,i_reserveClass,i_riskClass), CENFRovrdDay(ovrd,ild,i_reserveClass,i_riskClass)) ;

* Reset the CE NFR override parameters
  option clear = CENFRovrdDay ;             option clear = CENFRovrdMonth ;          option clear = CENFRovrdYear ;

* Calculate the from and to date for the CE NFR override
CENFRovrdDay(ovrd,ild,i_reserveClass,i_riskClass) = sum((toDay,toMth,toYr)$i_contingentEventNFRovrdToDate(ovrd,ild,i_reserveClass,i_riskClass,toDay,toMth,toYr), ord(toDay)) ;
CENFRovrdMonth(ovrd,ild,i_reserveClass,i_riskClass) = sum((toDay,toMth,toYr)$i_contingentEventNFRovrdToDate(ovrd,ild,i_reserveClass,i_riskClass,toDay,toMth,toYr), ord(toMth)) ;
CENFRovrdYear(ovrd,ild,i_reserveClass,i_riskClass) = sum((toDay,toMth,toYr)$i_contingentEventNFRovrdToDate(ovrd,ild,i_reserveClass,i_riskClass,toDay,toMth,toYr), ord(toYr) + startYear) ;
CENFRovrdToGDate(ovrd,ild,i_reserveClass,i_riskClass)$sum((toDay,toMth,toYr)$i_contingentEventNFRovrdToDate(ovrd,ild,i_reserveClass,i_riskClass,toDay,toMth,toYr), 1) = jdate(CENFRovrdYear(ovrd,ild,i_reserveClass,i_riskClass), CENFRovrdMonth(ovrd,ild,i_reserveClass,i_riskClass), CENFRovrdDay(ovrd,ild,i_reserveClass,i_riskClass)) ;

* Reset the CE NFR override parameters
  option clear = CENFRovrdDay ;             option clear = CENFRovrdMonth ;          option clear = CENFRovrdYear ;

* Determine if all the conditions for the CE NFR override are satisfied
loop((ovrd,tp,ild,i_reserveClass,i_riskClass)$(i_studyTradePeriod(tp) and (CENFRovrdFromGDate(ovrd,ild,i_reserveClass,i_riskClass) <= inputGDXgdate) and (CENFRovrdToGDate(ovrd,ild,i_reserveClass,i_riskClass) >= inputGDXgdate) and i_contingentEventNFRovrdTP(ovrd,ild,i_reserveClass,i_riskClass,tp) and i_contingentEventNFRovrd(ovrd,ild,i_reserveClass,i_riskClass)),
    if ((i_contingentEventNFRovrd(ovrd,ild,i_reserveClass,i_riskClass) <> 0),
      tradePeriodCENFRovrd(tp,ild,i_reserveClass,i_riskClass) = i_contingentEventNFRovrd(ovrd,ild,i_reserveClass,i_riskClass) ;
    elseif (i_contingentEventNFRovrd(ovrd,ild,i_reserveClass,i_riskClass) = eps),
      tradePeriodCENFRovrd(tp,ild,i_reserveClass,i_riskClass) = eps ;
    ) ;
) ;

* Reset the CE NFR override parameters
  option clear = CENFRovrdFromGDate ;       option clear = CENFRovrdToGDate ;

* Apply the CE NFR override
i_tradePeriodRiskParameter(tp,ild,i_reserveClass,i_riskClass,'i_FreeReserve')$(tradePeriodCENFRovrd(tp,ild,i_reserveClass,i_riskClass) <> 0) = tradePeriodCENFRovrd(tp,ild,i_reserveClass,i_riskClass) ;
i_tradePeriodRiskParameter(tp,ild,i_reserveClass,i_riskClass,'i_FreeReserve')$(tradePeriodCENFRovrd(tp,ild,i_reserveClass,i_riskClass) and (tradePeriodCENFRovrd(tp,ild,i_reserveClass,i_riskClass) = eps)) = 0 ;
  option clear = tradePeriodCENFRovrd ;

* Reset the HVDC risk override parameters
  option clear = HVDCriskOvrdDay ;          option clear = HVDCriskOvrdMonth ;       option clear = HVDCriskOvrdYear ;

* Calculate the from date for the HVDC risk override
HVDCriskOvrdDay(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter) = sum((day,mth,yr)$i_HVDCriskParamOvrdFromDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter,day,mth,yr), ord(day)) ;
HVDCriskOvrdMonth(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter) = sum((day,mth,yr)$i_HVDCriskParamOvrdFromDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter,day,mth,yr), ord(mth)) ;
HVDCriskOvrdYear(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter) = sum((day,mth,yr)$i_HVDCriskParamOvrdFromDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter,day,mth,yr), ord(yr) + startYear) ;
HVDCriskOvrdFromGDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter)$sum((day,mth,yr)$i_HVDCriskParamOvrdFromDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter,day,mth,yr), 1) = jdate(HVDCriskOvrdYear(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter), HVDCriskOvrdMonth(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter), HVDCriskOvrdDay(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter)) ;

* Reset the HVDC risk override parameters
  option clear = HVDCriskOvrdDay ;          option clear = HVDCriskOvrdMonth ;       option clear = HVDCriskOvrdYear ;

* Calculate the to date for the HVDC risk override
HVDCriskOvrdDay(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter) = sum((toDay,toMth,toYr)$i_HVDCriskParamOvrdToDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter,toDay,toMth,toYr), ord(toDay)) ;
HVDCriskOvrdMonth(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter) = sum((toDay,toMth,toYr)$i_HVDCriskParamOvrdToDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter,toDay,toMth,toYr), ord(toMth)) ;
HVDCriskOvrdYear(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter) = sum((toDay,toMth,toYr)$i_HVDCriskParamOvrdToDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter,toDay,toMth,toYr), ord(toYr) + startYear) ;
HVDCriskOvrdToGDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter)$sum((toDay,toMth,toYr)$i_HVDCriskParamOvrdToDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter,toDay,toMth,toYr), 1) = jdate(HVDCriskOvrdYear(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter), HVDCriskOvrdMonth(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter), HVDCriskOvrdDay(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter)) ;

* Reset the HVDC risk override parameters
  option clear = HVDCriskOvrdDay ;          option clear = HVDCriskOvrdMonth ;       option clear = HVDCriskOvrdYear ;

* Determine if all the conditions for the HVDC risk overrides are satisfied
loop((ovrd,tp,ild,i_reserveClass,i_riskClass,i_riskParameter)$(i_studyTradePeriod(tp) and (HVDCriskOvrdFromGDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter) <= inputGDXgdate) and (HVDCriskOvrdToGDate(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter) >= inputGDXgdate) and i_HVDCriskParamOvrdTP(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter,tp) and i_HVDCriskParamOvrd(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter)),
    if ((i_HVDCriskParamOvrd(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter) <> 0),
      tradePeriodHVDCriskOvrd(tp,ild,i_reserveClass,i_riskClass,i_riskParameter) = i_HVDCriskParamOvrd(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter) ;
    elseif (i_HVDCriskParamOvrd(ovrd,ild,i_reserveClass,i_riskClass,i_riskParameter) = eps),
      tradePeriodHVDCriskOvrd(tp,ild,i_reserveClass,i_riskClass,i_riskParameter) = eps ;
    ) ;
) ;

* Reset the HVDC risk override parameters
  option clear = HVDCriskOvrdFromGDate ;       option clear = HVDCriskOvrdToGDate ;

* Apply HVDC risk override
i_tradePeriodRiskParameter(tp,ild,i_reserveClass,i_riskClass,i_riskParameter)$(tradePeriodHVDCriskOvrd(tp,ild,i_reserveClass,i_riskClass,i_riskParameter) <> 0) = tradePeriodHVDCriskOvrd(tp,ild,i_reserveClass,i_riskClass,i_riskParameter) ;
i_tradePeriodRiskParameter(tp,ild,i_reserveClass,i_riskClass,i_riskParameter)$(tradePeriodHVDCriskOvrd(tp,ild,i_reserveClass,i_riskClass,i_riskParameter) and (tradePeriodHVDCriskOvrd(tp,ild,i_reserveClass,i_riskClass,i_riskParameter) = eps)) = 0 ;
  option clear = tradePeriodHVDCriskOvrd ;

*+++ End risk/reserve overrides +++
$offtext


* End EMI and Standalone interface override assignments
$label endEMIandStandaloneOverrides


$label theEnd


* End of file.
