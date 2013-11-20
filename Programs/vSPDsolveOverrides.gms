*=====================================================================================
* Name:                 vSPDsolveOverrides.gms
* Function:             Code to be included in vSPDsolve to take care of input data
*                       overrides.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://reports.ea.govt.nz/EMIIntro.htm
* Contact:              emi@ea.govt.nz
* Last modified on:     20 November 2013
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
$offtext


* 1. Declare override symbols
*    a) Offers - incl. energy, PLSR, TWDR, and ILR
*    b) Demand

* x. Initialise override symbols
*    a) Offer parameters
*    b) Energy offers
*    c) PLSR offers
*    d) TWDR offers
*    e) ILR offers
*    f) Demand overrides


* Excel interface - declare and initialise overrides
$if not %interfaceMode%==1 $goto skipOverridesWithExcel
$ontext
Parameters
  i_energyOfferOvrd(i_tradePeriod,i_offer,trdBlk,i_energyOfferComponent)  'Override for energy offers for specified trade period'
  i_offerParamOvrd(i_tradePeriod,i_offer,i_offerParam)  'Override for energy offer parameters for specified trade period'
  i_nodeDemandOvrd(i_tradePeriod,i_node)                'Override MW nodal demand for specified trade period'
  i_islandDemandOvrd(i_tradePeriod,i_island)            'Scaling factor for island demand for specified trade period'
  tradePeriodNodeDemandTemp(i_tradePeriod,i_node)       'Temporary trade period node demand for use in override calculations using i_islandDemandOvrd' ;
$onecho > OverridesFromExcel.ins
  par = i_energyOfferOvrd         rng = i_energyOfferOvrd         rdim = 4
  par = i_offerParamOvrd          rng = i_offerParamOvrd          rdim = 3
  par = i_nodeDemandOvrd          rng = i_nodeDemandOvrd          rdim = 2
  par = i_islandDemandOvrd        rng = i_islandDemandOvrd        rdim = 2
$offecho
*RDN - Update the override path and file name for the xls overrides
*$call 'gdxxrw "%ovrdPath%\%vSPDinputOvrdData%.xls" o=overridesFromExcel.gdx "@OverridesFromExcel.ins"'
*$gdxin "%ovrdPath%\overridesFromExcel"
$call 'gdxxrw "%programPath%\%vSPDinputFileName%.xls" o=overridesFromExcel.gdx "@OverridesFromExcel.ins"'
$gdxin "%programPath%\overridesFromExcel"
$load i_energyOfferOvrd i_offerParamOvrd i_nodeDemandOvrd i_islandDemandOvrd
$gdxin

* Island demand overrides
tradePeriodNodeDemandTemp(i_tradePeriod,i_node) = 0 ;
tradePeriodNodeDemandTemp(i_tradePeriod,i_node) = i_tradePeriodNodeDemand(i_tradePeriod,i_node) ;
* Apply island scaling factor to a node if scaling factor > 0 and the node demand > 0
  i_tradePeriodNodeDemand(i_tradePeriod,i_node)$(
                         ( tradePeriodNodeDemandTemp(i_tradePeriod,i_node) > 0 ) *
                         ( sum((i_bus,i_island)$( i_tradePeriodNodeBus(i_tradePeriod,i_node,i_bus) * i_tradePeriodBusIsland(i_tradePeriod,i_bus,i_island) ), i_islandDemandOvrd(i_tradePeriod,i_island) ) > 0 )  )
    = sum((i_bus,i_island)$( i_tradePeriodNodeBus(i_tradePeriod,i_node,i_bus) * i_tradePeriodBusIsland(i_tradePeriod,i_bus,i_island) ), i_tradePeriodNodeBusAllocationFactor(i_tradePeriod,i_node,i_bus) * i_islandDemandOvrd(i_tradePeriod,i_island) )
        * tradePeriodNodeDemandTemp(i_tradePeriod,i_node) ;
* Apply island scaling factor to a node if scaling factor = eps (0) and the node demand > 0
  i_tradePeriodNodeDemand(i_tradePeriod,i_node)$(
                         ( tradePeriodNodeDemandTemp(i_tradePeriod,i_node) > 0 ) *
                         ( sum((i_bus,i_island)$( i_tradePeriodNodeBus(i_tradePeriod,i_node,i_bus) * i_tradePeriodBusIsland(i_tradePeriod,i_bus,i_island) * i_islandDemandOvrd(i_tradePeriod,i_island) * ( i_islandDemandOvrd(i_tradePeriod,i_island) = eps ) ), 1 ) > 0 )  )
    = sum((i_bus,i_island)$( i_tradePeriodNodeBus(i_tradePeriod,i_node,i_bus) * i_tradePeriodBusIsland(i_tradePeriod,i_bus,i_island) ), i_tradePeriodNodeBusAllocationFactor(i_tradePeriod,i_node,i_bus) * 0 )
        * tradePeriodNodeDemandTemp(i_tradePeriod,i_node) ;

* Node demand overrides
i_tradePeriodNodeDemand(i_tradePeriod,i_node)$i_nodeDemandOvrd(i_tradePeriod,i_node) = i_nodeDemandOvrd(i_tradePeriod,i_node) ;
i_tradePeriodNodeDemand(i_tradePeriod,i_node)$( i_nodeDemandOvrd(i_tradePeriod,i_node) * ( i_nodeDemandOvrd(i_tradePeriod,i_node) = eps ) ) = 0 ;

* Energy offer overrides
i_tradePeriodEnergyOffer(i_tradePeriod,i_offer,trdBlk,i_energyOfferComponent)$( i_energyOfferOvrd(i_tradePeriod,i_offer,trdBlk,i_energyOfferComponent) > 0 )
  = i_energyOfferOvrd(i_tradePeriod,i_offer,trdBlk,i_energyOfferComponent) ;
i_tradePeriodEnergyOffer(i_tradePeriod,i_offer,trdBlk,i_energyOfferComponent)$( i_energyOfferOvrd(i_tradePeriod,i_offer,trdBlk,i_energyOfferComponent) * ( i_energyOfferOvrd(i_tradePeriod,i_offer,trdBlk,i_energyOfferComponent) = eps ) )
  = 0 ;

* Offer parameter overrides
i_tradePeriodOfferParameter(i_tradePeriod,i_offer,i_offerParam)$( i_offerParamOvrd(i_tradePeriod,i_offer,i_offerParam) > 0 ) = i_offerParamOvrd(i_tradePeriod,i_offer,i_offerParam) ;
i_tradePeriodOfferParameter(i_tradePeriod,i_offer,i_offerParam)$( i_offerParamOvrd(i_tradePeriod,i_offer,i_offerParam) * ( i_offerParamOvrd(i_tradePeriod,i_offer,i_offerParam) = eps ) ) = 0 ;
$offtext
$label skipOverridesWithExcel

* EMI tools and Standalone interface - declare override symbols
$if %interfaceMode%==1 $goto skipEMIandStandaloneOverrides
* Declare override symbols to be used for both EMI tools and standalone interface types
* NB: The following declarations are not skipped if in Excel interface mode - no harm is done by declaring symbols and then never using them.


*=====================================================================================
* 1. Declare override symbols
*=====================================================================================

* a) Offers - incl. energy, PLSR, TWDR, and ILR
Sets
  i_offerParamOvrdDate(ovrd,o,fromTo,day,mth,yr)                          'Offer parameter override dates'
  i_offerParamOvrdTP(ovrd,o,tp)                                           'Offer parameter override trade periods'
  i_energyOfferOvrdDate(ovrd,o,fromTo,day,mth,yr)                         'Energy offer override dates'
  i_energyOfferOvrdTP(ovrd,o,tp)                                          'Energy offer override trade periods'
  i_PLSRofferOvrdDate(ovrd,o,fromTo,day,mth,yr)                           'PLSR offer override dates'
  i_PLSRofferOvrdTP(ovrd,o,tp)                                            'PLSR offer override trade periods'
  i_TWDRofferOvrdDate(ovrd,o,fromTo,day,mth,yr)                           'TWDR offer override dates'
  i_TWDRofferOvrdTP(ovrd,o,tp)                                            'TWDR offer override trade periods'
  i_ILRofferOvrdDate(ovrd,o,fromTo,day,mth,yr)                            'ILR offer override dates'
  i_ILRofferOvrdTP(ovrd,o,tp)                                             'ILR offer override trade periods'
Parameters
  offerOvrdDay(ovrd,o,fromTo)                                             'Offer override from/to day'
  offerOvrdMonth(ovrd,o,fromTo)                                           'Offer override from/to month'
  offerOvrdYear(ovrd,o,fromTo)                                            'Offer override from/to year'
  offerOvrdGDate(ovrd,o,fromTo)                                           'Offer override from/to Gregorian date'
  i_offerParamOvrd(ovrd,o,i_offerParam)                                   'Offer parameter override values'
  i_energyOfferOvrd(ovrd,o,trdBlk,i_energyOfferComponent)                 'Energy offer override values'
  i_PLSRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_PLSRofferComponent)      'PLSR offer override values'
  i_TWDRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_TWDRofferComponent)      'TWDR offer override values'
  i_ILRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_ILRofferComponent)        'ILR offer override values'
  offerParamOvrdTP(tp,o,i_offerParam)                                     'Offer parameter override values by applicable trade periods'
  energyOfferOvrdTP(tp,o,trdBlk,i_energyOfferComponent)                   'Energy offer override values by applicable trade periods'
  PLSRofferOvrdTP(tp,i_reserveClass,o,trdBlk,i_PLSRofferComponent)        'PLSR offer override values by applicable trade periods'
  TWDRofferOvrdTP(tp,i_reserveClass,o,trdBlk,i_TWDRofferComponent)        'TWDR offer override values by applicable trade periods'
  ILRofferOvrdTP(tp,i_reserveClass,o,trdBlk,i_ILRofferComponent)          'ILR offer override values by applicable trade periods'
  ;
* b) Demand


$ontext
Sets
* Demand overrides
  i_islandDemandOvrdDate(ovrd,i_Island,i_dayNum,i_monthNum,i_yearNum)               'Island demand override date'
  i_islandDemandOvrdTP(ovrd,i_Island,tp)                                 'Island demand override trade period'
  i_nodeDemandOvrdDate(ovrd,i_node,i_dayNum,i_monthNum,i_yearNum)                   'Node demand override date'
  i_nodeDemandOvrdTP(ovrd,i_node,tp)                                     'Node demand override trade period'
* Branch overrides
  i_branchParamOvrdDate(ovrd,i_branch,fromTo,day,mth,yr)                      'Branch parameter override date'
  i_branchParamOvrdTP(ovrd,i_branch,tp)                                  'Branch parameter override trade period'
  i_branchCapacityOvrdDate(ovrd,i_branch,fromTo,day,mth,yr)                   'Branch capacity override date'
  i_branchCapacityOvrdTP(ovrd,i_branch,tp)                               'Branch capacity override trade period'
  i_branchOpenStatusOvrdDate(ovrd,i_branch,fromTo,day,mth,yr)                 'Branch open status override date'
  i_branchOpenStatusOvrdTP(ovrd,i_branch,tp)                             'Branch open status override trade period'
* Branch security constraint overrides
  i_branchConstraintFactorOvrdDate(ovrd,i_branchConstraint,i_branch,fromTo,day,mth,yr)    'Branch constraint factor override date'
  i_branchConstraintFactorOvrdTP(ovrd,i_branchConstraint,i_branch,tp)                'Branch constraint factor override trade period'
  i_branchConstraintRHSOvrdDate(ovrd,i_branchConstraint,fromTo,day,mth,yr)                'Branch constraint RHS override date'
  i_branchConstraintRHSOvrdTP(ovrd,i_branchConstraint,tp)                            'Branch constraint RHS override trade period'
* Market node constraint overrides
  i_MnodeEnergyConstraintFactorOvrdDate(ovrd,i_MnodeConstraint,o,fromTo,day,mth,yr) 'Market node energy constraint factor override date'
  i_MnodeEnergyConstraintFactorOvrdTP(ovrd,i_MnodeConstraint,o,tp)             'Market node energy constraint factor override trade period'
  i_MnodeReserveConstraintFactorOvrdDate(ovrd,i_MnodeConstraint,o,i_reserveClass,fromTo,day,mth,yr) 'Market node reserve constraint factor override date'
  i_MnodeReserveConstraintFactorOvrdTP(ovrd,i_MnodeConstraint,o,i_reserveClass,tp)             'Market node reserve constraint factor override trade period'
  i_MnodeConstraintRHSOvrdDate(ovrd,i_MnodeConstraint,fromTo,day,mth,yr)                                  'Market node constraint RHS override date'
  i_MnodeConstraintRHSOvrdTP(ovrd,i_MnodeConstraint,tp)                                              'Market node constraint RHS override trade period'
* Risk/Reserves
  i_contingentEventRAFOvrdDate(ovrd,i_island,i_reserveClass,fromTo,day,mth,yr)                            'Contingency event RAF override date'
  i_contingentEventRAFOvrdTP(ovrd,i_island,i_reserveClass,tp)                                        'Contingency event RAF override trade period'
  i_extendedContingentEventRAFOvrdDate(ovrd,i_island,i_reserveClass,fromTo,day,mth,yr)                    'Extended contingency event RAF override date'
  i_extendedContingentEventRAFOvrdTP(ovrd,i_island,i_reserveClass,tp)                                'Extended contingency event RAF override trade period'
  i_contingentEventNFROvrdDate(ovrd,i_island,i_reserveClass,i_riskClass,fromTo,day,mth,yr)                'Contingency event NFR override date - Generator and Manual'
  i_contingentEventNFROvrdTP(ovrd,i_island,i_reserveClass,i_riskClass,tp)                            'Contingency event NFR override trade period - Generator and Manual'
  i_HVDCriskParamOvrdDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,fromTo,day,mth,yr)     'HVDC risk parameter override date'
  i_HVDCriskParamOvrdTP(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,tp)                 'HVDC risk parameter override trade period'
  ;

Parameters
* Demand overrides
  i_islandPosMWDemandOvrd(ovrd,i_island)                                            'Island positive demand override MW values'
  i_islandPosPercDemandOvrd(ovrd,i_island)                                          'Island positive demand override % values'
  i_islandNegMWDemandOvrd(ovrd,i_island)                                            'Island negative demand override MW values'
  i_islandNegPercDemandOvrd(ovrd,i_island)                                          'Island negative demand override % values'
  i_islandNetMWDemandOvrd(ovrd,i_island)                                            'Island net demand override MW values'
  i_islandNetPercDemandOvrd(ovrd,i_island)                                          'Island net demand override % values'
  i_nodeMWDemandOvrd(ovrd,i_node)                                                   'Node demand override MW values'
  i_nodePercDemandOvrd(ovrd,i_node)                                                 'Node demand override % values'
* Branch parameter, capacity and status overrides
  i_branchParamOvrd(ovrd,i_branch,i_branchParameter)                                'Branch parameter override values'
  i_branchCapacityOvrd(ovrd,i_branch)                                               'Branch capacity override values'
  i_branchOpenStatusOvrd(ovrd,i_branch)                                             'Branch open status override values'
* Branch constraint factor overrides - factor and RHS
  i_branchConstraintFactorOvrd(ovrd,i_branchConstraint,i_branch)                    'Branch constraint factor override values'
  i_branchConstraintRHSOvrd(ovrd,i_branchConstraint,i_constraintRHS)                'Branch constraint RHS override values'
* Market node constraint overrides - factor and RHS
  i_MnodeEnergyConstraintFactorOvrd(ovrd,i_MnodeConstraint,o)                 'Market node energy constraint factor override values'
  i_MnodeReserveConstraintFactorOvrd(ovrd,i_MnodeConstraint,o,i_reserveClass) 'Market node reserve constraint factor override values'
  i_MnodeConstraintRHSOvrd(ovrd,i_MnodeConstraint,i_constraintRHS)                  'Market node constraint RHS override values'
* Risk/Reserve overrides
  i_contingentEventRAFOvrd(ovrd,i_island,i_reserveClass)                            'Contingency event RAF override'
  i_extendedContingentEventRAFOvrd(ovrd,i_island,i_reserveClass)                    'Extended contingency event RAF override'
  i_contingentEventNFROvrd(ovrd,i_island,i_reserveClass,i_riskClass)                'Contingency event NFR override - GENRISK and Manual'
  i_HVDCriskParamOvrd(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)     'HVDC risk parameter override'

* More demand overrides
  islandDemandOvrdFromDay(ovrd,i_island)                                            'Island demand override from day'
  islandDemandOvrdFromMonth(ovrd,i_island)                                          'Island demand override from month'
  islandDemandOvrdFromYear(ovrd,i_island)                                           'Island demand override from year'
  islandDemandOvrdToDay(ovrd,i_island)                                              'Island demand override to day'
  islandDemandOvrdToMonth(ovrd,i_island)                                            'Island demand override to month'
  islandDemandOvrdToYear(ovrd,i_island)                                             'Island demand override to year'
  islandDemandOvrdFromGDate(ovrd,i_island)                                          'Island demand override date - Gregorian'
  islandDemandOvrdToGDate(ovrd,i_island)                                            'Island demand override to date - Gregorian'
  tradePeriodNodeDemandOrig(tp,i_node)                                   'Original node demand - MW'
  tradePeriodPosislandDemand(tp,i_island)                                'Original positive island demand'
  tradePeriodNegislandDemand(tp,i_island)                                'Original negative island demand'
  tradePeriodNetislandDemand(tp,i_island)                                'Original net island demand'
  nodeDemandOvrdFromDay(ovrd,i_node)                                                'Node demand override from day'
  nodeDemandOvrdFromMonth(ovrd,i_node)                                              'Node demand override from month'
  nodeDemandOvrdFromYear(ovrd,i_node)                                               'Node demand override from year'
  nodeDemandOvrdToDay(ovrd,i_node)                                                  'Node demand override to day'
  nodeDemandOvrdToMonth(ovrd,i_node)                                                'Node demand override to month'
  nodeDemandOvrdToYear(ovrd,i_node)                                                 'Node demand override to year'
  nodeDemandOvrdFromGDate(ovrd,i_node)                                              'Node demand override date - Gregorian'
  nodeDemandOvrdToGDate(ovrd,i_node)                                                'Node demand override to date - Gregorian'
  tradePeriodNodeDemandOvrd(tp,i_node)                                   'Node demand override'
* More branch overrides
  branchOvrdFromDay(ovrd,i_branch)                                                  'Branch override from day'
  branchOvrdFromMonth(ovrd,i_branch)                                                'Branch override from month'
  branchOvrdFromYear(ovrd,i_branch)                                                 'Branch override from year'
  branchOvrdToDay(ovrd,i_branch)                                                    'Branch override to day'
  branchOvrdToMonth(ovrd,i_branch)                                                  'Branch override to month'
  branchOvrdToYear(ovrd,i_branch)                                                   'Branch override to year'
  branchOvrdFromGDate(ovrd,i_branch)                                                'Branch override date - Gregorian'
  branchOvrdToGDate(ovrd,i_branch)                                                  'Branch override to date - Gregorian'
  tradePeriodBranchParamOvrd(tp,i_branch,i_branchParameter)              'Branch parameter override for applicable trade periods'
  tradePeriodBranchCapacityOvrd(tp,i_branch)                             'Branch capacity override for applicable trade periods'
  tradePeriodBranchOpenStatusOvrd(tp,i_branch)                           'Branch status override for applicable trade periods'
* More branch security constraint overrides - factor
  branchConstraintFactorOvrdFromDay(ovrd,i_branchConstraint,i_branch)               'Branch constraint factor override from day'
  branchConstraintFactorOvrdFromMonth(ovrd,i_branchConstraint,i_branch)             'Branch constraint factor override from month'
  branchConstraintFactorOvrdFromYear(ovrd,i_branchConstraint,i_branch)              'Branch constraint factor override from year'
  branchConstraintFactorOvrdToDay(ovrd,i_branchConstraint,i_branch)                 'Branch constraint factor override to day'
  branchConstraintFactorOvrdToMonth(ovrd,i_branchConstraint,i_branch)               'Branch constraint factor override to month'
  branchConstraintFactorOvrdToYear(ovrd,i_branchConstraint,i_branch)                'Branch constraint factor override to year'
  branchConstraintFactorOvrdFromGDate(ovrd,i_branchConstraint,i_branch)             'Branch constraint factor override date - Gregorian'
  branchConstraintFactorOvrdToGDate(ovrd,i_branchConstraint,i_branch)               'Branch constraint factor override to date - Gregorian'
  tradePeriodBranchConstraintFactorOvrd(tp,i_branchConstraint,i_branch)  'Branch constraint factor override for applicable trade periods'
* More branch security constraint overrides - RHS
  branchConstraintRHSOvrdFromDay(ovrd,i_branchConstraint)                           'Branch constraint RHS override from day'
  branchConstraintRHSOvrdFromMonth(ovrd,i_branchConstraint)                         'Branch constraint RHS override from month'
  branchConstraintRHSOvrdFromYear(ovrd,i_branchConstraint)                          'Branch constraint RHS override from year'
  branchConstraintRHSOvrdToDay(ovrd,i_branchConstraint)                             'Branch constraint RHS override to day'
  branchConstraintRHSOvrdToMonth(ovrd,i_branchConstraint)                           'Branch constraint RHS override to month'
  branchConstraintRHSOvrdToYear(ovrd,i_branchConstraint)                            'Branch constraint RHS override to year'
  branchConstraintRHSOvrdFromGDate(ovrd,i_branchConstraint)                         'Branch constraint RHS override date - Gregorian'
  branchConstraintRHSOvrdToGDate(ovrd,i_branchConstraint)                           'Branch constraint RHS override to date - Gregorian'
  tradePeriodBranchConstraintRHSOvrd(tp,i_branchConstraint,i_constraintRHS)'Branch constraint RHS override for applicable trade periods'
* More market node constraint overrides - energy factor
  MnodeEnergyConstraintFactorOvrdFromDay(ovrd,i_MnodeConstraint,o)            'Market node energy constraint factor override from day'
  MnodeEnergyConstraintFactorOvrdFromMonth(ovrd,i_MnodeConstraint,o)          'Market node energy constraint factor override from month'
  MnodeEnergyConstraintFactorOvrdFromYear(ovrd,i_MnodeConstraint,o)           'Market node energy constraint factor override from year'
  MnodeEnergyConstraintFactorOvrdToDay(ovrd,i_MnodeConstraint,o)              'Market node energy constraint factor override to day'
  MnodeEnergyConstraintFactorOvrdToMonth(ovrd,i_MnodeConstraint,o)            'Market node energy constraint factor override to month'
  MnodeEnergyConstraintFactorOvrdToYear(ovrd,i_MnodeConstraint,o)             'Market node energy constraint factor override to year'
  MnodeEnergyConstraintFactorOvrdFromGDate(ovrd,i_MnodeConstraint,o)          'Market node energy constraint factor override date - Gregorian'
  MnodeEnergyConstraintFactorOvrdToGDate(ovrd,i_MnodeConstraint,o)            'Market node energy constraint factor override to date - Gregorian'
  tradePeriodMnodeEnergyConstraintFactorOvrd(tp,i_MnodeConstraint,o) 'Market node energy constraint factor override for applicable trade periods'
* More market node constraint overrides - reserve factor
  MnodeReserveConstraintFactorOvrdFromDay(ovrd,i_MnodeConstraint,o,i_reserveClass)            'Market node reserve constraint factor override from day'
  MnodeReserveConstraintFactorOvrdFromMonth(ovrd,i_MnodeConstraint,o,i_reserveClass)          'Market node reserve constraint factor override from month'
  MnodeReserveConstraintFactorOvrdFromYear(ovrd,i_MnodeConstraint,o,i_reserveClass)           'Market node reserve constraint factor override from year'
  MnodeReserveConstraintFactorOvrdToDay(ovrd,i_MnodeConstraint,o,i_reserveClass)              'Market node reserve constraint factor override to day'
  MnodeReserveConstraintFactorOvrdToMonth(ovrd,i_MnodeConstraint,o,i_reserveClass)            'Market node reserve constraint factor override to month'
  MnodeReserveConstraintFactorOvrdToYear(ovrd,i_MnodeConstraint,o,i_reserveClass)             'Market node reserve constraint factor override to year'
  MnodeReserveConstraintFactorOvrdFromGDate(ovrd,i_MnodeConstraint,o,i_reserveClass)          'Market node reserve constraint factor override date - Gregorian'
  MnodeReserveConstraintFactorOvrdToGDate(ovrd,i_MnodeConstraint,o,i_reserveClass)            'Market node reserve constraint factor override to date - Gregorian'
  tradePeriodMnodeReserveConstraintFactorOvrd(tp,i_MnodeConstraint,o,i_reserveClass) 'Market node reserve constraint factor override for applicable trade periods'
* More market node constraint overrides - RHS
  MnodeConstraintRHSOvrdFromDay(ovrd,i_MnodeConstraint)                             'Market node constraint RHS override from day'
  MnodeConstraintRHSOvrdFromMonth(ovrd,i_MnodeConstraint)                           'Market node constraint RHS override from month'
  MnodeConstraintRHSOvrdFromYear(ovrd,i_MnodeConstraint)                            'Market node constraint RHS override from year'
  MnodeConstraintRHSOvrdToDay(ovrd,i_MnodeConstraint)                               'Market node constraint RHS override to day'
  MnodeConstraintRHSOvrdToMonth(ovrd,i_MnodeConstraint)                             'Market node constraint RHS override to month'
  MnodeConstraintRHSOvrdToYear(ovrd,i_MnodeConstraint)                              'Market node constraint RHS override to year'
  MnodeConstraintRHSOvrdFromGDate(ovrd,i_MnodeConstraint)                           'Market node constraint RHS override date - Gregorian'
  MnodeConstraintRHSOvrdToGDate(ovrd,i_MnodeConstraint)                             'Market node constraint RHS override to date - Gregorian'
  tradePeriodMnodeConstraintRHSOvrd(tp,i_MnodeConstraint,i_constraintRHS)'Market node constraint RHS override for applicable trade periods'
* More risk/reserve overrides
  RAFovrdDay(ovrd,i_island,i_reserveClass)                                          'RAF override from day'
  RAFovrdMonth(ovrd,i_island,i_reserveClass)                                        'RAF override from month'
  RAFovrdYear(ovrd,i_island,i_reserveClass)                                         'RAF override from year'
  CERAFovrdFromGDate(ovrd,i_island,i_reserveClass)                                  'Contingency event RAF override date - Gregorian'
  CERAFovrdToGDate(ovrd,i_island,i_reserveClass)                                    'Contingency event RAF override to date - Gregorian'
  tradePeriodCERAFovrd(tp,i_island,i_reserveClass)                       'Contingency event RAF override for applicable trade periods'
  ECERAFovrdFromGDate(ovrd,i_island,i_reserveClass)                                 'Extended contingency event RAF override date - Gregorian'
  ECERAFovrdToGDate(ovrd,i_island,i_reserveClass)                                   'Extended contingency event RAF override to date - Gregorian'
  tradePeriodECERAFovrd(tp,i_island,i_reserveClass)                      'Extended contingency event RAF override for applicable trade periods'
  CENFRovrdDay(ovrd,i_island,i_reserveClass,i_riskClass)                            'Contingency event NFR override from day'
  CENFRovrdMonth(ovrd,i_island,i_reserveClass,i_riskClass)                          'Contingency event NFR override from month'
  CENFRovrdYear(ovrd,i_island,i_reserveClass,i_riskClass)                           'Contingency event NFR override from year'
  CENFRovrdFromGDate(ovrd,i_island,i_reserveClass,i_riskClass)                      'Contingency event NFR override date - Gregorian'
  CENFRovrdToGDate(ovrd,i_island,i_reserveClass,i_riskClass)                        'Contingency event NFR override to date - Gregorian'
  tradePeriodCENFRovrd(tp,i_island,i_reserveClass,i_riskClass)           'Contingency event NFR override for applicable trade periods'
  HVDCriskOvrdDay(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)         'HVDC risk parameter override from day'
  HVDCriskOvrdMonth(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)       'HVDC risk parameter override from month'
  HVDCriskOvrdYear(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)        'HVDC risk parameter override from year'
  HVDCriskOvrdFromGDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)   'HVDC risk parameter override date - Gregorian'
  HVDCriskOvrdToGDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)     'HVDC risk parameter override to date - Gregorian'
  tradePeriodHVDCriskOvrd(tp,i_island,i_reserveClass,i_riskClass,i_riskParameter) 'HVDC risk parameter override for applicable trade periods'
  ;
$offtext

* EMI tools and Standalone interface - load/install override data
* Load override data from override GDX file. Note that all of these symbols must exist in the GDX file so as to intialise everything - even if they're empty.
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load i_offerParamOvrdDate i_offerParamOvrdTP i_energyOfferOvrdDate i_energyOfferOvrdTP i_PLSRofferOvrdDate i_PLSRofferOvrdTP
$load i_TWDRofferOvrdDate i_TWDRofferOvrdTP i_ILRofferOvrdDate i_ILRofferOvrdTP
$load i_offerParamOvrd i_energyOfferOvrd i_PLSRofferOvrd i_TWDRofferOvrd i_ILRofferOvrd
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
* x. Initialise override symbols
*=====================================================================================

* a) Offer parameters
* Reset the override parameters
  option clear = offerOvrdDay ; option clear = offerOvrdMonth ; option clear = offerOvrdYear ; option clear = offerOvrdGDate ;

* Calculate the from and to dates for the offer parameter overrides
  offerOvrdDay(ovrd,o,fromTo)   = sum((day,mth,yr)$i_offerParamOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(day) ) ;
  offerOvrdMonth(ovrd,o,fromTo) = sum((day,mth,yr)$i_offerParamOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(mth) ) ;
  offerOvrdYear(ovrd,o,fromTo)  = sum((day,mth,yr)$i_offerParamOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(yr) + startYear ) ;

  offerOvrdGDate(ovrd,o,fromTo)$sum((day,mth,yr)$i_offerParamOvrdDate(ovrd,o,fromTo,day,mth,yr), 1 ) =
    jdate( offerOvrdYear(ovrd,o,fromTo), offerOvrdMonth(ovrd,o,fromTo), offerOvrdDay(ovrd,o,fromTo) ) ;

* Determine if all the conditions for applying the offer parameter overrides are satisfied
  loop((ovrd,tp,o,i_offerParam)$(   i_studyTradePeriod(tp) and
                                  ( offerOvrdGDate(ovrd,o,'frm') <= inputGDXgdate ) and
                                  ( offerOvrdGDate(ovrd,o,'to')  >= inputGDXgdate ) and
                                    i_offerParamOvrdTP(ovrd,o,tp) and
                                    i_offerParamOvrd(ovrd,o,i_offerParam)
                                ),
    if( (i_offerParamOvrd(ovrd,o,i_offerParam) > 0 ),   offerParamOvrdTP(tp,o,i_offerParam) = i_offerParamOvrd(ovrd,o,i_offerParam) ) ;
    if( (i_offerParamOvrd(ovrd,o,i_offerParam) = eps ), offerParamOvrdTP(tp,o,i_offerParam) = eps ) ;
  ) ;

* Apply the offer parameter override values to the base case input data value. Clear the offer parameter override values when done.
  i_tradePeriodOfferParameter(tp,o,i_offerParam)$( offerParamOvrdTP(tp,o,i_offerParam) > 0 )   = offerParamOvrdTP(tp,o,i_offerParam) ;
  i_tradePeriodOfferParameter(tp,o,i_offerParam)$(   offerParamOvrdTP(tp,o,i_offerParam) and
                                                   ( offerParamOvrdTP(tp,o,i_offerParam) = eps ) ) = 0 ;
  option clear = offerParamOvrdTP ;


* b) Energy offers
* Reset the override parameters
  option clear = offerOvrdDay ; option clear = offerOvrdMonth ; option clear = offerOvrdYear ; option clear = offerOvrdGDate ;

* Calculate the from and to dates for the energy offer overrides
  offerOvrdDay(ovrd,o,fromTo)   = sum((day,mth,yr)$i_energyOfferOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(day) ) ;
  offerOvrdMonth(ovrd,o,fromTo) = sum((day,mth,yr)$i_energyOfferOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(mth) ) ;
  offerOvrdYear(ovrd,o,fromTo)  = sum((day,mth,yr)$i_energyOfferOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(yr) + startYear ) ;

  offerOvrdGDate(ovrd,o,fromTo)$sum((day,mth,yr)$i_energyOfferOvrdDate(ovrd,o,fromTo,day,mth,yr), 1 ) =
    jdate( offerOvrdYear(ovrd,o,fromTo), offerOvrdMonth(ovrd,o,fromTo), offerOvrdDay(ovrd,o,fromTo) ) ;

* Determine if all the conditions for applying the energy offer overrides are satisfied
  loop((ovrd,tp,o,trdBlk,i_energyOfferComponent)$(   i_studyTradePeriod(tp) and
                                                   ( offerOvrdGDate(ovrd,o,'frm') <= inputGDXgdate ) and
                                                   ( offerOvrdGDate(ovrd,o,'to')  >= inputGDXgdate ) and
                                                     i_energyOfferOvrdTP(ovrd,o,tp) and
                                                     i_energyOfferOvrd(ovrd,o,trdBlk,i_energyOfferComponent)
                                                   ),
    if(i_energyOfferOvrd(ovrd,o,trdBlk,i_energyOfferComponent) > 0,
      energyOfferOvrdTP(tp,o,trdBlk,i_energyOfferComponent) = i_energyOfferOvrd(ovrd,o,trdBlk,i_energyOfferComponent) ;
    ) ;
    if(i_energyOfferOvrd(ovrd,o,trdBlk,i_energyOfferComponent) = eps,
      energyOfferOvrdTP(tp,o,trdBlk,i_energyOfferComponent) = eps ;
    ) ;
  ) ;

* Apply the energy offer override values to the base case input data values. Clear the energy offer override values when done.
  i_tradePeriodEnergyOffer(tp,o,trdBlk,i_energyOfferComponent)$( energyOfferOvrdTP(tp,o,trdBlk,i_energyOfferComponent) > 0 ) =
    energyOfferOvrdTP(tp,o,trdBlk,i_energyOfferComponent) ;
  i_tradePeriodEnergyOffer(tp,o,trdBlk,i_energyOfferComponent)$(   energyOfferOvrdTP(tp,o,trdBlk,i_energyOfferComponent) and
                                                                 ( energyOfferOvrdTP(tp,o,trdBlk,i_energyOfferComponent) = eps ) ) = 0 ;
  option clear = energyOfferOvrdTP ;


* c) PLSR offers
* Reset the override parameters
  option clear = offerOvrdDay ; option clear = offerOvrdMonth ; option clear = offerOvrdYear ; option clear = offerOvrdGDate ;

* Calculate the from and to dates for the PLSR offer overrides
  offerOvrdDay(ovrd,o,fromTo)   = sum((day,mth,yr)$i_PLSRofferOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(day) ) ;
  offerOvrdMonth(ovrd,o,fromTo) = sum((day,mth,yr)$i_PLSRofferOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(mth) ) ;
  offerOvrdYear(ovrd,o,fromTo)  = sum((day,mth,yr)$i_PLSRofferOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(yr) + startYear ) ;

  offerOvrdGDate(ovrd,o,fromTo)$sum((day,mth,yr)$i_PLSRofferOvrdDate(ovrd,o,fromTo,day,mth,yr), 1 ) =
    jdate( offerOvrdYear(ovrd,o,fromTo), offerOvrdMonth(ovrd,o,fromTo), offerOvrdDay(ovrd,o,fromTo) ) ;

* Determine if all the conditions for applying the PLSR offer overrides are satisfied
  loop((ovrd,tp,o,i_reserveClass,trdBlk,i_PLSRofferComponent)$(   i_studyTradePeriod(tp) and
                                                                ( offerOvrdGDate(ovrd,o,'frm') <= inputGDXgdate ) and
                                                                ( offerOvrdGDate(ovrd,o,'to')  >= inputGDXgdate ) and
                                                                  i_PLSRofferOvrdTP(ovrd,o,tp) and
                                                                  i_PLSRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_PLSRofferComponent)
                                                                ),
    if(i_PLSRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_PLSRofferComponent) > 0,
      PLSRofferOvrdTP(tp,i_reserveClass,o,trdBlk,i_PLSRofferComponent) = i_PLSRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_PLSRofferComponent) ;
    ) ;
    if(i_PLSRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_PLSRofferComponent) = eps,
      PLSRofferOvrdTP(tp,i_reserveClass,o,trdBlk,i_PLSRofferComponent) = eps ;
    ) ;
  ) ;

* Apply the PLSR offer override values to the base case input data values. Clear the PLSR offer override values when done.
  i_tradePeriodFastPLSRoffer(tp,o,trdBlk,i_PLSRofferComponent)$( PLSRofferOvrdTP(tp,'fir',o,trdBlk,i_PLSRofferComponent) > 0 ) =
    PLSRofferOvrdTP(tp,'fir',o,trdBlk,i_PLSRofferComponent) ;
  i_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,i_PLSRofferComponent)$( PLSRofferOvrdTP(tp,'sir',o,trdBlk,i_PLSRofferComponent) > 0 ) =
    PLSRofferOvrdTP(tp,'sir',o,trdBlk,i_PLSRofferComponent) ;
  i_tradePeriodFastPLSRoffer(tp,o,trdBlk,i_PLSRofferComponent)$(   PLSRofferOvrdTP(tp,'fir',o,trdBlk,i_PLSRofferComponent) and
                                                                 ( PLSRofferOvrdTP(tp,'fir',o,trdBlk,i_PLSRofferComponent) = eps ) ) = 0 ;
  i_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,i_PLSRofferComponent)$(   PLSRofferOvrdTP(tp,'sir',o,trdBlk,i_PLSRofferComponent) and
                                                                      ( PLSRofferOvrdTP(tp,'sir',o,trdBlk,i_PLSRofferComponent) = eps ) ) = 0 ;
  option clear = PLSRofferOvrdTP ;


* d) TWDR offers
* Reset the override parameters
  option clear = offerOvrdDay ; option clear = offerOvrdMonth ; option clear = offerOvrdYear ; option clear = offerOvrdGDate ;

* Calculate the from and to dates for the TWDR offer overrides
  offerOvrdDay(ovrd,o,fromTo)   = sum((day,mth,yr)$i_TWDRofferOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(day) ) ;
  offerOvrdMonth(ovrd,o,fromTo) = sum((day,mth,yr)$i_TWDRofferOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(mth) ) ;
  offerOvrdYear(ovrd,o,fromTo)  = sum((day,mth,yr)$i_TWDRofferOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(yr) + startYear ) ;

  offerOvrdGDate(ovrd,o,fromTo)$sum((day,mth,yr)$i_TWDRofferOvrdDate(ovrd,o,fromTo,day,mth,yr), 1 ) =
    jdate( offerOvrdYear(ovrd,o,fromTo), offerOvrdMonth(ovrd,o,fromTo), offerOvrdDay(ovrd,o,fromTo) ) ;

* Determine if all the conditions for applying the TWDR offer overrides are satisfied
  loop((ovrd,tp,o,i_reserveClass,trdBlk,i_TWDRofferComponent)$(   i_studyTradePeriod(tp) and
                                                                ( offerOvrdGDate(ovrd,o,'frm') <= inputGDXgdate ) and
                                                                ( offerOvrdGDate(ovrd,o,'to')  >= inputGDXgdate ) and
                                                                  i_TWDRofferOvrdTP(ovrd,o,tp) and
                                                                  i_TWDRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_TWDRofferComponent)
                                                              ),
    if(i_TWDRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_TWDRofferComponent) > 0,
      TWDRofferOvrdTP(tp,i_reserveClass,o,trdBlk,i_TWDRofferComponent) = i_TWDRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_TWDRofferComponent) ;
    ) ;
    if(i_TWDRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_TWDRofferComponent) = eps,
      TWDRofferOvrdTP(tp,i_reserveClass,o,trdBlk,i_TWDRofferComponent) = eps ;
    ) ;
  ) ;

* Apply the TWDR offer override values to the base case input data values. Clear the TWDR offer override values when done.
  i_tradePeriodFastTWDRoffer(tp,o,trdBlk,i_TWDRofferComponent)$( TWDRofferOvrdTP(tp,'fir',o,trdBlk,i_TWDRofferComponent) > 0 ) =
    TWDRofferOvrdTP(tp,'fir',o,trdBlk,i_TWDRofferComponent) ;
  i_tradePeriodSustainedTWDRoffer(tp,o,trdBlk,i_TWDRofferComponent)$( TWDRofferOvrdTP(tp,'sir',o,trdBlk,i_TWDRofferComponent) > 0 ) =
    TWDRofferOvrdTP(tp,'sir',o,trdBlk,i_TWDRofferComponent) ;
  i_tradePeriodFastTWDRoffer(tp,o,trdBlk,i_TWDRofferComponent)$(   TWDRofferOvrdTP(tp,'fir',o,trdBlk,i_TWDRofferComponent) and
                                                                 ( TWDRofferOvrdTP(tp,'fir',o,trdBlk,i_TWDRofferComponent) = eps ) ) = 0 ;
  i_tradePeriodSustainedTWDRoffer(tp,o,trdBlk,i_TWDRofferComponent)$(   TWDRofferOvrdTP(tp,'sir',o,trdBlk,i_TWDRofferComponent) and
                                                                      ( TWDRofferOvrdTP(tp,'sir',o,trdBlk,i_TWDRofferComponent) = eps ) ) = 0 ;
  option clear = TWDRofferOvrdTP ;


* e) ILR offers
* Reset the override parameters
  option clear = offerOvrdDay ; option clear = offerOvrdMonth ; option clear = offerOvrdYear ; option clear = offerOvrdGDate ;

* Calculate the from and to dates for the ILR offer overrides
  offerOvrdDay(ovrd,o,fromTo)   = sum((day,mth,yr)$i_ILRofferOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(day) ) ;
  offerOvrdMonth(ovrd,o,fromTo) = sum((day,mth,yr)$i_ILRofferOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(mth) ) ;
  offerOvrdYear(ovrd,o,fromTo)  = sum((day,mth,yr)$i_ILRofferOvrdDate(ovrd,o,fromTo,day,mth,yr), ord(yr) + startYear ) ;

  offerOvrdGDate(ovrd,o,fromTo)$sum((day,mth,yr)$i_ILRofferOvrdDate(ovrd,o,fromTo,day,mth,yr), 1 ) =
    jdate( offerOvrdYear(ovrd,o,fromTo), offerOvrdMonth(ovrd,o,fromTo), offerOvrdDay(ovrd,o,fromTo) ) ;

* Determine if all the conditions for applying the ILR offer overrides are satisfied
  loop((ovrd,tp,o,i_reserveClass,trdBlk,i_ILRofferComponent)$(   i_studyTradePeriod(tp) and
                                                               ( offerOvrdGDate(ovrd,o,'frm') <= inputGDXgdate ) and
                                                               ( offerOvrdGDate(ovrd,o,'to')  >= inputGDXgdate ) and
                                                                 i_ILRofferOvrdTP(ovrd,o,tp) and
                                                                 i_ILRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_ILRofferComponent)
                                                             ),
    if(i_ILRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_ILRofferComponent) > 0,
      ILRofferOvrdTP(tp,i_reserveClass,o,trdBlk,i_ILRofferComponent) = i_ILRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_ILRofferComponent) ;
    ) ;
    if(i_ILRofferOvrd(ovrd,i_reserveClass,o,trdBlk,i_ILRofferComponent) = eps,
      ILRofferOvrdTP(tp,i_reserveClass,o,trdBlk,i_ILRofferComponent) = eps ;
    ) ;
  ) ;

* Apply the ILR offer override values to the base case input data values. Clear the ILR offer override values when done.
  i_tradePeriodFastILRoffer(tp,o,trdBlk,i_ILRofferComponent)$( ILRofferOvrdTP(tp,'fir',o,trdBlk,i_ILRofferComponent) > 0 ) =
    ILRofferOvrdTP(tp,'fir',o,trdBlk,i_ILRofferComponent) ;
  i_tradePeriodSustainedILRoffer(tp,o,trdBlk,i_ILRofferComponent)$( ILRofferOvrdTP(tp,'sir',o,trdBlk,i_ILRofferComponent) > 0 ) =
    ILRofferOvrdTP(tp,'sir',o,trdBlk,i_ILRofferComponent) ;
  i_tradePeriodFastILRoffer(tp,o,trdBlk,i_ILRofferComponent)$(   ILRofferOvrdTP(tp,'fir',o,trdBlk,i_ILRofferComponent) and
                                                               ( ILRofferOvrdTP(tp,'fir',o,trdBlk,i_ILRofferComponent) = eps ) ) = 0 ;
  i_tradePeriodSustainedILRoffer(tp,o,trdBlk,i_ILRofferComponent)$(   ILRofferOvrdTP(tp,'sir',o,trdBlk,i_ILRofferComponent) and
                                                                    ( ILRofferOvrdTP(tp,'sir',o,trdBlk,i_ILRofferComponent) = eps ) ) = 0 ;
  option clear = ILRofferOvrdTP ;

* f) Demand overrides



***************** Done up to here...

$ontext
*+++ Start demand override +++

* Calculate the from and to date for the island demand override
  option clear = islandDemandOvrdFromDay ;          option clear = islandDemandOvrdFromMonth ;       option clear = islandDemandOvrdFromYear ;
  option clear = islandDemandOvrdToDay ;            option clear = islandDemandOvrdToMonth ;         option clear = islandDemandOvrdToYear ;
  option clear = islandDemandOvrdFromGDate ;        option clear = islandDemandOvrdToGDate ;

  islandDemandOvrdFromDay(ovrd,i_island)   = sum((day,mth,yr)$i_islandDemandOvrdFromDate(ovrd,i_island,day,mth,yr), ord(day) ) ;
  islandDemandOvrdFromMonth(ovrd,i_island) = sum((day,mth,yr)$i_islandDemandOvrdFromDate(ovrd,i_island,day,mth,yr), ord(mth) ) ;
  islandDemandOvrdFromYear(ovrd,i_island)  = sum((day,mth,yr)$i_islandDemandOvrdFromDate(ovrd,i_island,day,mth,yr), ord(yr) + startYear ) ;

  islandDemandOvrdToDay(ovrd,i_island)   = sum((toDay,toMth,toYr)$i_islandDemandOvrdToDate(ovrd,i_island,toDay,toMth,toYr), ord(toDay) ) ;
  islandDemandOvrdToMonth(ovrd,i_island) = sum((toDay,toMth,toYr)$i_islandDemandOvrdToDate(ovrd,i_island,toDay,toMth,toYr), ord(toMth) ) ;
  islandDemandOvrdToYear(ovrd,i_island)  = sum((toDay,toMth,toYr)$i_islandDemandOvrdToDate(ovrd,i_island,toDay,toMth,toYr), ord(toYr) + startYear ) ;

  islandDemandOvrdFromGDate(ovrd,i_island)$sum((day,mth,yr)$i_islandDemandOvrdFromDate(ovrd,i_island,day,mth,yr), 1 ) =
    jdate( islandDemandOvrdFromYear(ovrd,i_island),islandDemandOvrdFromMonth(ovrd,i_island),islandDemandOvrdFromDay(ovrd,i_island) ) ;
  islandDemandOvrdToGDate(ovrd,i_island)$sum((toDay,toMth,toYr)$i_islandDemandOvrdToDate(ovrd,i_island,toDay,toMth,toYr), 1) =
    jdate(islandDemandOvrdToYear(ovrd,i_island),islandDemandOvrdToMonth(ovrd,i_island),islandDemandOvrdToDay(ovrd,i_island) ) ;

* Island demand override pre-processing
  tradePeriodNodeDemandOrig(tp,i_node) = 0 ;
  tradePeriodNodeDemandOrig(tp,i_node) = i_tradePeriodNodeDemand(tp,i_node) ;
  tradePeriodNodeIslandTemp(tp,i_node,i_island)$sum(i_Bus$(i_tradePeriodNodeBus(tp,i_node,i_Bus) and i_tradePeriodBusIsland(tp,i_Bus,i_island)), 1 ) = yes ;

  tradePeriodPosIslandDemand(tp,i_island) = sum(i_node$( tradePeriodNodeIslandTemp(tp,i_node,i_island) and
                                                                  ( tradePeriodNodeDemandOrig(tp,i_node) > 0 ) ), tradePeriodNodeDemandOrig(tp,i_node) ) ;
  tradePeriodNegIslandDemand(tp,i_island) = sum(i_node$( tradePeriodNodeIslandTemp(tp,i_node,i_island) and
                                                                  ( tradePeriodNodeDemandOrig(tp,i_node) < 0 ) ), tradePeriodNodeDemandOrig(tp,i_node) ) ;
  tradePeriodNetIslandDemand(tp,i_island) = sum(i_node$tradePeriodNodeIslandTemp(tp,i_node,i_island), tradePeriodNodeDemandOrig(tp,i_node) ) ;

* Apply the demand overrides
  loop((ovrd,i_island)$( ( islandDemandOvrdFromGDate(ovrd,i_island) <= inputGDXgdate ) and ( islandDemandOvrdToGDate(ovrd,i_island) >= inputGDXgdate ) ),
* Percentage override to positive loads
    if((i_islandPosPercDemandOvrd(ovrd,i_island) and ( i_islandPosPercDemandOvrd(ovrd,i_island) <> 0) ),
      tradePeriodNodeDemandOvrd(tp,i_node)$( ( tradePeriodNodeDemandOrig(tp,i_node) > 0 ) and
                                                          i_islandDemandOvrdTP(ovrd,i_island,tp) and tradePeriodNodeIslandTemp(tp,i_node,i_island) )
        =  ( 1+ ( i_islandPosPercDemandOvrd(ovrd,i_island) / 100 ) ) * tradePeriodNodeDemandOrig(tp,i_node) ;
    elseif(i_islandPosPercDemandOvrd(ovrd,i_island) and ( i_islandPosPercDemandOvrd(ovrd,i_island) = eps ) ),
      tradePeriodNodeDemandOvrd(tp,i_node)$( ( tradePeriodNodeDemandOrig(tp,i_node) > 0 ) and
                                                          i_islandDemandOvrdTP(ovrd,i_island,i_tradePeriod ) and tradePeriodNodeIslandTemp(tp,i_node,i_island) )
        = tradePeriodNodeDemandOrig(tp,i_node) ;
    ) ;

* Percentage override to negative loads
    if ((i_islandNegPercDemandOvrd(ovrd,i_island) and (i_islandNegPercDemandOvrd(ovrd,i_island) <> 0)),
       tradePeriodNodeDemandOvrd(tp,i_node)$((tradePeriodNodeDemandOrig(tp,i_node) < 0) and i_islandDemandOvrdTP(ovrd,i_island,tp) and tradePeriodNodeIslandTemp(tp,i_node,i_island))
          =  (1+(i_islandNegPercDemandOvrd(ovrd,i_island)/100)) * tradePeriodNodeDemandOrig(tp,i_node) ;
    elseif (i_islandNegPercDemandOvrd(ovrd,i_island) and (i_islandNegPercDemandOvrd(ovrd,i_island) = eps)),
       tradePeriodNodeDemandOvrd(tp,i_node)$((tradePeriodNodeDemandOrig(tp,i_node) < 0) and i_islandDemandOvrdTP(ovrd,i_island,tp) and tradePeriodNodeIslandTemp(tp,i_node,i_island))
          = tradePeriodNodeDemandOrig(tp,i_node) ;
    ) ;

* Percentage override to net loads
    if ((i_islandNetPercDemandOvrd(ovrd,i_island) and (i_islandNetPercDemandOvrd(ovrd,i_island) <> 0)),
       tradePeriodNodeDemandOvrd(tp,i_node)$(i_islandDemandOvrdTP(ovrd,i_island,tp) and tradePeriodNodeIslandTemp(tp,i_node,i_island))
          =  (1+(i_islandNetPercDemandOvrd(ovrd,i_island)/100)) * tradePeriodNodeDemandOrig(tp,i_node) ;
    elseif (i_islandNetPercDemandOvrd(ovrd,i_island) and (i_islandNetPercDemandOvrd(ovrd,i_island) = eps)),
       tradePeriodNodeDemandOvrd(tp,i_node)$(i_islandDemandOvrdTP(ovrd,i_island,tp) and tradePeriodNodeIslandTemp(tp,i_node,i_island))
          = tradePeriodNodeDemandOrig(tp,i_node) ;
    ) ;

* MW override to positive island loads
    if ((i_islandPosMWDemandOvrd(ovrd,i_island) and (i_islandPosMWDemandOvrd(ovrd,i_island) <> 0)),
       tradePeriodNodeDemandOvrd(tp,i_node)$((tradePeriodPosislandDemand(tp,i_island) > 0) and (tradePeriodNodeDemandOrig(tp,i_node) > 0) and i_islandDemandOvrdTP(ovrd,i_island,tp) and tradePeriodNodeIslandTemp(tp,i_node,i_island))
          =  i_islandPosMWDemandOvrd(ovrd,i_island) * (tradePeriodNodeDemandOrig(tp,i_node)/TradePeriodPosislandDemand(tp,i_island)) ;
    elseif (i_islandPosMWDemandOvrd(ovrd,i_island) and (i_islandPosMWDemandOvrd(ovrd,i_island) = eps)),
       tradePeriodNodeDemandOvrd(tp,i_node)$((tradePeriodNodeDemandOrig(tp,i_node) > 0) and i_islandDemandOvrdTP(ovrd,i_island,tp) and tradePeriodNodeIslandTemp(tp,i_node,i_island))
          = eps ;
    ) ;

* MW override to negative island loads
    if ((i_islandNegMWDemandOvrd(ovrd,i_island) and (i_islandNegMWDemandOvrd(ovrd,i_island) <> 0)),
       tradePeriodNodeDemandOvrd(tp,i_node)$((tradePeriodNegislandDemand(tp,i_island) < 0) and (tradePeriodNodeDemandOrig(tp,i_node) < 0) and i_islandDemandOvrdTP(ovrd,i_island,tp) and tradePeriodNodeIslandTemp(tp,i_node,i_island))
          =  i_islandNegMWDemandOvrd(ovrd,i_island) * (tradePeriodNodeDemandOrig(tp,i_node)/TradePeriodNegislandDemand(tp,i_island)) ;
    elseif (i_islandNegMWDemandOvrd(ovrd,i_island) and (i_islandNegMWDemandOvrd(ovrd,i_island) = eps)),
       tradePeriodNodeDemandOvrd(tp,i_node)$((tradePeriodNodeDemandOrig(tp,i_node) < 0) and i_islandDemandOvrdTP(ovrd,i_island,tp) and tradePeriodNodeIslandTemp(tp,i_node,i_island))
          = eps ;
    ) ;

* MW override to net island loads
    if ((i_islandNetMWDemandOvrd(ovrd,i_island) and (i_islandNetMWDemandOvrd(ovrd,i_island) <> 0)),
       tradePeriodNodeDemandOvrd(tp,i_node)$((tradePeriodNetislandDemand(tp,i_island) <> 0) and (tradePeriodNodeDemandOrig(tp,i_node) <> 0) and i_islandDemandOvrdTP(ovrd,i_island,tp) and tradePeriodNodeIslandTemp(tp,i_node,i_island))
          =  i_islandNetMWDemandOvrd(ovrd,i_island) * (tradePeriodNodeDemandOrig(tp,i_node)/TradePeriodNetislandDemand(tp,i_island)) ;
    elseif (i_islandNetMWDemandOvrd(ovrd,i_island) and (i_islandNetMWDemandOvrd(ovrd,i_island) = eps)),
       tradePeriodNodeDemandOvrd(tp,i_node)$(i_islandDemandOvrdTP(ovrd,i_island,tp) and tradePeriodNodeIslandTemp(tp,i_node,i_island))
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

NodeDemandOvrdFromDay(ovrd,i_node) = sum((day,mth,yr)$i_nodeDemandOvrdFromDate(ovrd,i_node,day,mth,yr), ord(day)) ;
NodeDemandOvrdFromMonth(ovrd,i_node) = sum((day,mth,yr)$i_nodeDemandOvrdFromDate(ovrd,i_node,day,mth,yr), ord(mth)) ;
NodeDemandOvrdFromYear(ovrd,i_node) = sum((day,mth,yr)$i_nodeDemandOvrdFromDate(ovrd,i_node,day,mth,yr), ord(yr) + startYear) ;

NodeDemandOvrdToDay(ovrd,i_node) = sum((toDay,toMth,toYr)$i_nodeDemandOvrdToDate(ovrd,i_node,toDay,toMth,toYr), ord(toDay)) ;
NodeDemandOvrdToMonth(ovrd,i_node) = sum((toDay,toMth,toYr)$i_nodeDemandOvrdToDate(ovrd,i_node,toDay,toMth,toYr), ord(toMth)) ;
NodeDemandOvrdToYear(ovrd,i_node) = sum((toDay,toMth,toYr)$i_nodeDemandOvrdToDate(ovrd,i_node,toDay,toMth,toYr), ord(toYr) + startYear) ;

NodeDemandOvrdFromGDate(ovrd,i_node)$sum((day,mth,yr)$i_nodeDemandOvrdFromDate(ovrd,i_node,day,mth,yr), 1) = jdate(NodeDemandOvrdFromYear(ovrd,i_node), nodeDemandOvrdFromMonth(ovrd,i_node), nodeDemandOvrdFromDay(ovrd,i_node)) ;
NodeDemandOvrdToGDate(ovrd,i_node)$sum((toDay,toMth,toYr)$i_nodeDemandOvrdToDate(ovrd,i_node,toDay,toMth,toYr), 1) = jdate(NodeDemandOvrdToYear(ovrd,i_node), nodeDemandOvrdToMonth(ovrd,i_node), nodeDemandOvrdToDay(ovrd,i_node)) ;

* Apply the node demand overrides
loop((ovrd,i_node)$((NodeDemandOvrdFromGDate(ovrd,i_node) <= inputGDXgdate) and (NodeDemandOvrdToGDate(ovrd,i_node) >= inputGDXgdate) and (i_nodeMWDemandOvrd(ovrd,i_node) or i_nodePercDemandOvrd(ovrd,i_node))),

* MW override to node loads
    if (((i_nodeMWDemandOvrd(ovrd,i_node) > 0) or (i_nodeMWDemandOvrd(ovrd,i_node) < 0)),
       tradePeriodNodeDemandOvrd(tp,i_node)$i_nodeDemandOvrdTP(ovrd,i_node,tp) =  i_nodeMWDemandOvrd(ovrd,i_node) ;
    elseif (i_nodeMWDemandOvrd(ovrd,i_node) = eps),
       tradePeriodNodeDemandOvrd(tp,i_node)$i_nodeDemandOvrdTP(ovrd,i_node,tp) = eps ;
    ) ;

* Percentage override to node loads
    if (((i_nodePercDemandOvrd(ovrd,i_node) > 0) or (i_nodePercDemandOvrd(ovrd,i_node) < 0)),
       tradePeriodNodeDemandOvrd(tp,i_node)$i_nodeDemandOvrdTP(ovrd,i_node,tp) =  (1+(i_nodePercDemandOvrd(ovrd,i_node)/100)) * tradePeriodNodeDemandOrig(tp,i_node) ;
    elseif (i_nodeMWDemandOvrd(ovrd,i_node) = eps),
       tradePeriodNodeDemandOvrd(tp,i_node)$i_nodeDemandOvrdTP(ovrd,i_node,tp) = eps ;
    ) ;
) ;

* Calculate the from and to date for the node demand override
  option clear = nodeDemandOvrdFromDay ;            option clear = nodeDemandOvrdFromMonth ;         option clear = nodeDemandOvrdFromYear ;
  option clear = nodeDemandOvrdToDay ;              option clear = nodeDemandOvrdToMonth ;           option clear = nodeDemandOvrdToYear ;
  option clear = nodeDemandOvrdFromGDate ;          option clear = nodeDemandOvrdToGDate ;

* Apply the demand override
i_tradePeriodNodeDemand(tp,i_node)$TradePeriodNodeDemandOvrd(tp,i_node) = tradePeriodNodeDemandOvrd(tp,i_node) ;
i_tradePeriodNodeDemand(tp,i_node)$(tradePeriodNodeDemandOvrd(tp,i_node) and (tradePeriodNodeDemandOvrd(tp,i_node) = eps)) = 0 ;
  option clear = tradePeriodNodeDemandOvrd ;        option clear = tradePeriodNodeDemandOrig ;       option clear = tradePeriodNodeIslandTemp ;
  option clear = tradePeriodPosislandDemand ;       option clear = tradePeriodNegislandDemand ;      option clear = tradePeriodNetislandDemand ;

*+++ End demand override +++

*+++ Start branch override +++

* Reset the branch override parameters
  option clear = BranchOvrdFromDay ;                option clear = BranchOvrdFromMonth ;             option clear = BranchOvrdFromYear ;
  option clear = BranchOvrdToDay ;                  option clear = BranchOvrdToMonth ;               option clear = BranchOvrdToYear ;
  option clear = BranchOvrdFromGDate ;              option clear = BranchOvrdToGDate ;

* Calculate the from and to date for the branch parameter override
BranchOvrdFromDay(ovrd,i_Branch) = sum((day,mth,yr)$i_BranchParamOvrdFromDate(ovrd,i_Branch,day,mth,yr), ord(day)) ;
BranchOvrdFromMonth(ovrd,i_Branch) = sum((day,mth,yr)$i_BranchParamOvrdFromDate(ovrd,i_Branch,day,mth,yr), ord(mth)) ;
BranchOvrdFromYear(ovrd,i_Branch) = sum((day,mth,yr)$i_BranchParamOvrdFromDate(ovrd,i_Branch,day,mth,yr), ord(yr) + startYear) ;

BranchOvrdToDay(ovrd,i_Branch) = sum((toDay,toMth,toYr)$i_BranchParamOvrdToDate(ovrd,i_Branch,toDay,toMth,toYr), ord(toDay)) ;
BranchOvrdToMonth(ovrd,i_Branch) = sum((toDay,toMth,toYr)$i_BranchParamOvrdToDate(ovrd,i_Branch,toDay,toMth,toYr), ord(toMth)) ;
BranchOvrdToYear(ovrd,i_Branch) = sum((toDay,toMth,toYr)$i_BranchParamOvrdToDate(ovrd,i_Branch,toDay,toMth,toYr), ord(toYr) + startYear) ;

BranchOvrdFromGDate(ovrd,i_Branch)$sum((day,mth,yr)$i_BranchParamOvrdFromDate(ovrd,i_Branch,day,mth,yr), 1) = jdate(BranchOvrdFromYear(ovrd,i_Branch), BranchOvrdFromMonth(ovrd,i_Branch), BranchOvrdFromDay(ovrd,i_Branch)) ;
BranchOvrdToGDate(ovrd,i_Branch)$sum((toDay,toMth,toYr)$i_BranchParamOvrdToDate(ovrd,i_Branch,toDay,toMth,toYr), 1) = jdate(BranchOvrdToYear(ovrd,i_Branch), BranchOvrdToMonth(ovrd,i_Branch), BranchOvrdToDay(ovrd,i_Branch)) ;

* Determine if all the conditions for the branch parameter override are satisfied
loop((ovrd,tp,i_Branch,i_BranchParameter)$(i_studyTradePeriod(tp) and (BranchOvrdFromGDate(ovrd,i_Branch) <= inputGDXgdate) and (BranchOvrdToGDate(ovrd,i_Branch) >= inputGDXgdate) and i_BranchParamOvrdTP(ovrd,i_Branch,tp) and i_BranchParamOvrd(ovrd,i_Branch,i_BranchParameter)),
    if ((i_BranchParamOvrd(ovrd,i_Branch,i_BranchParameter) <> 0),
      tradePeriodBranchParamOvrd(tp,i_Branch,i_BranchParameter) = i_BranchParamOvrd(ovrd,i_Branch,i_BranchParameter) ;
    elseif (i_BranchParamOvrd(ovrd,i_Branch,i_BranchParameter) = eps),
      tradePeriodBranchParamOvrd(tp,i_Branch,i_BranchParameter) = eps ;
    ) ;
) ;

* Reset the branch override parameters
  option clear = BranchOvrdFromDay ;                option clear = BranchOvrdFromMonth ;             option clear = BranchOvrdFromYear ;
  option clear = BranchOvrdToDay ;                  option clear = BranchOvrdToMonth ;               option clear = BranchOvrdToYear ;
  option clear = BranchOvrdFromGDate ;              option clear = BranchOvrdToGDate ;

* Apply the branch parameter override
i_tradePeriodBranchParameter(tp,i_Branch,i_BranchParameter)$ (tradePeriodBranchParamOvrd(tp,i_Branch,i_BranchParameter) <> 0) = tradePeriodBranchParamOvrd(tp,i_Branch,i_BranchParameter) ;
i_tradePeriodBranchParameter(tp,i_Branch,i_BranchParameter)$(tradePeriodBranchParamOvrd(tp,i_Branch,i_BranchParameter) and (tradePeriodBranchParamOvrd(tp,i_Branch,i_BranchParameter) = eps)) = 0 ;
  option clear = tradePeriodBranchParamOvrd ;

* Calculate the from and to date for the branch capacity override
BranchOvrdFromDay(ovrd,i_Branch) = sum((day,mth,yr)$i_BranchCapacityOvrdFromDate(ovrd,i_Branch,day,mth,yr), ord(day)) ;
BranchOvrdFromMonth(ovrd,i_Branch) = sum((day,mth,yr)$i_BranchCapacityOvrdFromDate(ovrd,i_Branch,day,mth,yr), ord(mth)) ;
BranchOvrdFromYear(ovrd,i_Branch) = sum((day,mth,yr)$i_BranchCapacityOvrdFromDate(ovrd,i_Branch,day,mth,yr), ord(yr) + startYear) ;

BranchOvrdToDay(ovrd,i_Branch) = sum((toDay,toMth,toYr)$i_BranchCapacityOvrdToDate(ovrd,i_Branch,toDay,toMth,toYr), ord(toDay)) ;
BranchOvrdToMonth(ovrd,i_Branch) = sum((toDay,toMth,toYr)$i_BranchCapacityOvrdToDate(ovrd,i_Branch,toDay,toMth,toYr), ord(toMth)) ;
BranchOvrdToYear(ovrd,i_Branch) = sum((toDay,toMth,toYr)$i_BranchCapacityOvrdToDate(ovrd,i_Branch,toDay,toMth,toYr), ord(toYr) + startYear) ;

BranchOvrdFromGDate(ovrd,i_Branch)$sum((day,mth,yr)$i_BranchCapacityOvrdFromDate(ovrd,i_Branch,day,mth,yr), 1) = jdate(BranchOvrdFromYear(ovrd,i_Branch), BranchOvrdFromMonth(ovrd,i_Branch), BranchOvrdFromDay(ovrd,i_Branch)) ;
BranchOvrdToGDate(ovrd,i_Branch)$sum((toDay,toMth,toYr)$i_BranchCapacityOvrdToDate(ovrd,i_Branch,toDay,toMth,toYr), 1) = jdate(BranchOvrdToYear(ovrd,i_Branch), BranchOvrdToMonth(ovrd,i_Branch), BranchOvrdToDay(ovrd,i_Branch)) ;

* Determine if all the conditions for the branch capacity are satisfied
loop((ovrd,tp,i_Branch)$(i_studyTradePeriod(tp) and (BranchOvrdFromGDate(ovrd,i_Branch) <= inputGDXgdate) and (BranchOvrdToGDate(ovrd,i_Branch) >= inputGDXgdate) and i_BranchCapacityOvrdTP(ovrd,i_Branch,tp) and i_BranchCapacityOvrd(ovrd,i_Branch)),
    if ((i_BranchCapacityOvrd(ovrd,i_Branch) > 0),
      tradePeriodBranchCapacityOvrd(tp,i_Branch) = i_BranchCapacityOvrd(ovrd,i_Branch) ;
    elseif (i_BranchCapacityOvrd(ovrd,i_Branch) = eps),
      tradePeriodBranchCapacityOvrd(tp,i_Branch) = eps ;
    ) ;
) ;

* Reset the branch override parameters
  option clear = BranchOvrdFromDay ;                option clear = BranchOvrdFromMonth ;             option clear = BranchOvrdFromYear ;
  option clear = BranchOvrdToDay ;                  option clear = BranchOvrdToMonth ;               option clear = BranchOvrdToYear ;
  option clear = BranchOvrdFromGDate ;              option clear = BranchOvrdToGDate ;

* Apply the branch capacity override
i_tradePeriodBranchCapacity(tp,i_Branch)$ (tradePeriodBranchCapacityOvrd(tp,i_Branch) > 0) = tradePeriodBranchCapacityOvrd(tp,i_Branch) ;
i_tradePeriodBranchCapacity(tp,i_Branch)$(tradePeriodBranchCapacityOvrd(tp,i_Branch) and (tradePeriodBranchCapacityOvrd(tp,i_Branch) = eps)) = 0 ;
  option clear = tradePeriodBranchCapacityOvrd ;

* Calculate the from and to date for the branch open status override
BranchOvrdFromDay(ovrd,i_Branch) = sum((day,mth,yr)$i_BranchOpenStatusOvrdFromDate(ovrd,i_Branch,day,mth,yr), ord(day)) ;
BranchOvrdFromMonth(ovrd,i_Branch) = sum((day,mth,yr)$i_BranchOpenStatusOvrdFromDate(ovrd,i_Branch,day,mth,yr), ord(mth)) ;
BranchOvrdFromYear(ovrd,i_Branch) = sum((day,mth,yr)$i_BranchOpenStatusOvrdFromDate(ovrd,i_Branch,day,mth,yr), ord(yr) + startYear) ;

BranchOvrdToDay(ovrd,i_Branch) = sum((toDay,toMth,toYr)$i_BranchOpenStatusOvrdToDate(ovrd,i_Branch,toDay,toMth,toYr), ord(toDay)) ;
BranchOvrdToMonth(ovrd,i_Branch) = sum((toDay,toMth,toYr)$i_BranchOpenStatusOvrdToDate(ovrd,i_Branch,toDay,toMth,toYr), ord(toMth)) ;
BranchOvrdToYear(ovrd,i_Branch) = sum((toDay,toMth,toYr)$i_BranchOpenStatusOvrdToDate(ovrd,i_Branch,toDay,toMth,toYr), ord(toYr) + startYear) ;

BranchOvrdFromGDate(ovrd,i_Branch)$sum((day,mth,yr)$i_BranchOpenStatusOvrdFromDate(ovrd,i_Branch,day,mth,yr), 1) = jdate(BranchOvrdFromYear(ovrd,i_Branch), BranchOvrdFromMonth(ovrd,i_Branch), BranchOvrdFromDay(ovrd,i_Branch)) ;
BranchOvrdToGDate(ovrd,i_Branch)$sum((toDay,toMth,toYr)$i_BranchOpenStatusOvrdToDate(ovrd,i_Branch,toDay,toMth,toYr), 1) = jdate(BranchOvrdToYear(ovrd,i_Branch), BranchOvrdToMonth(ovrd,i_Branch), BranchOvrdToDay(ovrd,i_Branch)) ;

* Determine if all the conditions for the branch open status are satisfied
loop((ovrd,tp,i_Branch)$(i_studyTradePeriod(tp) and (BranchOvrdFromGDate(ovrd,i_Branch) <= inputGDXgdate) and (BranchOvrdToGDate(ovrd,i_Branch) >= inputGDXgdate) and i_BranchOpenStatusOvrdTP(ovrd,i_Branch,tp) and i_BranchOpenStatusOvrd(ovrd,i_Branch)),
    if ((i_BranchOpenStatusOvrd(ovrd,i_Branch) > 0),
      tradePeriodBranchOpenStatusOvrd(tp,i_Branch) = i_BranchOpenStatusOvrd(ovrd,i_Branch) ;
    elseif (i_BranchOpenStatusOvrd(ovrd,i_Branch) = eps),
      tradePeriodBranchOpenStatusOvrd(tp,i_Branch) = eps ;
    ) ;
) ;

* Reset the branch override parameters
  option clear = BranchOvrdFromDay ;                option clear = BranchOvrdFromMonth ;             option clear = BranchOvrdFromYear ;
  option clear = BranchOvrdToDay ;                  option clear = BranchOvrdToMonth ;               option clear = BranchOvrdToYear ;
  option clear = BranchOvrdFromGDate ;              option clear = BranchOvrdToGDate ;

* Apply the branch open status override
i_tradePeriodBranchOpenStatus(tp,i_Branch)$(tradePeriodBranchOpenStatusOvrd(tp,i_Branch) > 0) = tradePeriodBranchOpenStatusOvrd(tp,i_Branch) ;
i_tradePeriodBranchOpenStatus(tp,i_Branch)$(tradePeriodBranchOpenStatusOvrd(tp,i_Branch) and (tradePeriodBranchOpenStatusOvrd(tp,i_Branch) = eps)) = 0 ;
  option clear = tradePeriodBranchOpenStatusOvrd ;

*+++ End branch override +++

*+++ Start branch constraint override +++

* Reset the branch constraint factor override parameters
  option clear = BranchConstraintFactorOvrdFromDay ;        option clear = BranchConstraintFactorOvrdFromMonth ;     option clear = BranchConstraintFactorOvrdFromYear ;
  option clear = BranchConstraintFactorOvrdToDay ;          option clear = BranchConstraintFactorOvrdToMonth ;       option clear = BranchConstraintFactorOvrdToYear ;
  option clear = BranchConstraintFactorOvrdFromGDate ;      option clear = BranchConstraintFactorOvrdToGDate ;

* Calculate the from and to date for the branch constraint factor override
BranchConstraintFactorOvrdFromDay(ovrd,i_BranchConstraint,i_Branch) = sum((day,mth,yr)$i_BranchConstraintFactorOvrdFromDate(ovrd,i_BranchConstraint,i_Branch,day,mth,yr), ord(day)) ;
BranchConstraintFactorOvrdFromMonth(ovrd,i_BranchConstraint,i_Branch) = sum((day,mth,yr)$i_BranchConstraintFactorOvrdFromDate(ovrd,i_BranchConstraint,i_Branch,day,mth,yr), ord(mth)) ;
BranchConstraintFactorOvrdFromYear(ovrd,i_BranchConstraint,i_Branch) = sum((day,mth,yr)$i_BranchConstraintFactorOvrdFromDate(ovrd,i_BranchConstraint,i_Branch,day,mth,yr), ord(yr) + startYear) ;

BranchConstraintFactorOvrdToDay(ovrd,i_BranchConstraint,i_Branch) = sum((toDay,toMth,toYr)$i_BranchConstraintFactorOvrdToDate(ovrd,i_BranchConstraint,i_Branch,toDay,toMth,toYr), ord(toDay)) ;
BranchConstraintFactorOvrdToMonth(ovrd,i_BranchConstraint,i_Branch) = sum((toDay,toMth,toYr)$i_BranchConstraintFactorOvrdToDate(ovrd,i_BranchConstraint,i_Branch,toDay,toMth,toYr), ord(toMth)) ;
BranchConstraintFactorOvrdToYear(ovrd,i_BranchConstraint,i_Branch) = sum((toDay,toMth,toYr)$i_BranchConstraintFactorOvrdToDate(ovrd,i_BranchConstraint,i_Branch,toDay,toMth,toYr), ord(toYr) + startYear) ;

BranchConstraintFactorOvrdFromGDate(ovrd,i_BranchConstraint,i_Branch)$sum((day,mth,yr)$i_BranchConstraintFactorOvrdFromDate(ovrd,i_BranchConstraint,i_Branch,day,mth,yr), 1) = jdate(BranchConstraintFactorOvrdFromYear(ovrd,i_BranchConstraint,i_Branch), BranchConstraintFactorOvrdFromMonth(ovrd,i_BranchConstraint,i_Branch), BranchConstraintFactorOvrdFromDay(ovrd,i_BranchConstraint,i_Branch)) ;
BranchConstraintFactorOvrdToGDate(ovrd,i_BranchConstraint,i_Branch)$sum((toDay,toMth,toYr)$i_BranchConstraintFactorOvrdToDate(ovrd,i_BranchConstraint,i_Branch,toDay,toMth,toYr), 1) = jdate(BranchConstraintFactorOvrdToYear(ovrd,i_BranchConstraint,i_Branch), BranchConstraintFactorOvrdToMonth(ovrd,i_BranchConstraint,i_Branch), BranchConstraintFactorOvrdToDay(ovrd,i_BranchConstraint,i_Branch)) ;

* Determine if all the conditions for the branch constraint factor are satisfied
loop((ovrd,tp,i_BranchConstraint,i_Branch)$(i_studyTradePeriod(tp) and (BranchConstraintFactorOvrdFromGDate(ovrd,i_BranchConstraint,i_Branch) <= inputGDXgdate) and (BranchConstraintFactorOvrdToGDate(ovrd,i_BranchConstraint,i_Branch) >= inputGDXgdate) and i_BranchConstraintFactorOvrdTP(ovrd,i_BranchConstraint,i_Branch,tp) and i_BranchConstraintFactorOvrd(ovrd,i_BranchConstraint,i_Branch)),
    if ((i_BranchConstraintFactorOvrd(ovrd,i_BranchConstraint,i_Branch) <> 0),
      tradePeriodBranchConstraintFactorOvrd(tp,i_BranchConstraint,i_Branch) = i_BranchConstraintFactorOvrd(ovrd,i_BranchConstraint,i_Branch) ;
    elseif (i_BranchConstraintFactorOvrd(ovrd,i_BranchConstraint,i_Branch) = eps),
      tradePeriodBranchConstraintFactorOvrd(tp,i_BranchConstraint,i_Branch) = eps ;
    ) ;
) ;

* Reset the branch constraint factor override parameters
  option clear = BranchConstraintFactorOvrdFromDay ;        option clear = BranchConstraintFactorOvrdFromMonth ;     option clear = BranchConstraintFactorOvrdFromYear ;
  option clear = BranchConstraintFactorOvrdToDay ;          option clear = BranchConstraintFactorOvrdToMonth ;       option clear = BranchConstraintFactorOvrdToYear ;
  option clear = BranchConstraintFactorOvrdFromGDate ;      option clear = BranchConstraintFactorOvrdToGDate ;

* Apply the branch constraint factor override
i_tradePeriodBranchConstraintFactors(tp,i_BranchConstraint,i_Branch)$(tradePeriodBranchConstraintFactorOvrd(tp,i_BranchConstraint,i_Branch) <> 0) = tradePeriodBranchConstraintFactorOvrd(tp,i_BranchConstraint,i_Branch) ;
i_tradePeriodBranchConstraintFactors(tp,i_BranchConstraint,i_Branch)$(tradePeriodBranchConstraintFactorOvrd(tp,i_BranchConstraint,i_Branch) and (tradePeriodBranchConstraintFactorOvrd(tp,i_BranchConstraint,i_Branch) = eps)) = 0 ;
  option clear = tradePeriodBranchConstraintFactorOvrd ;

* Reset the branch constraint RHS override parameters
  option clear = BranchConstraintRHSOvrdFromDay ;           option clear = BranchConstraintRHSOvrdFromMonth ;        option clear = BranchConstraintRHSOvrdFromYear ;
  option clear = BranchConstraintRHSOvrdToDay ;             option clear = BranchConstraintRHSOvrdToMonth ;          option clear = BranchConstraintRHSOvrdToYear ;
  option clear = BranchConstraintRHSOvrdFromGDate ;         option clear = BranchConstraintRHSOvrdToGDate ;

* Calculate the from and to date for the branch constraint RHS override
BranchConstraintRHSOvrdFromDay(ovrd,i_BranchConstraint) = sum((day,mth,yr)$i_BranchConstraintRHSOvrdFromDate(ovrd,i_BranchConstraint,day,mth,yr), ord(day)) ;
BranchConstraintRHSOvrdFromMonth(ovrd,i_BranchConstraint) = sum((day,mth,yr)$i_BranchConstraintRHSOvrdFromDate(ovrd,i_BranchConstraint,day,mth,yr), ord(mth)) ;
BranchConstraintRHSOvrdFromYear(ovrd,i_BranchConstraint) = sum((day,mth,yr)$i_BranchConstraintRHSOvrdFromDate(ovrd,i_BranchConstraint,day,mth,yr), ord(yr) + startYear) ;

BranchConstraintRHSOvrdToDay(ovrd,i_BranchConstraint) = sum((toDay,toMth,toYr)$i_BranchConstraintRHSOvrdToDate(ovrd,i_BranchConstraint,toDay,toMth,toYr), ord(toDay)) ;
BranchConstraintRHSOvrdToMonth(ovrd,i_BranchConstraint) = sum((toDay,toMth,toYr)$i_BranchConstraintRHSOvrdToDate(ovrd,i_BranchConstraint,toDay,toMth,toYr), ord(toMth)) ;
BranchConstraintRHSOvrdToYear(ovrd,i_BranchConstraint) = sum((toDay,toMth,toYr)$i_BranchConstraintRHSOvrdToDate(ovrd,i_BranchConstraint,toDay,toMth,toYr), ord(toYr) + startYear) ;

BranchConstraintRHSOvrdFromGDate(ovrd,i_BranchConstraint)$sum((day,mth,yr)$i_BranchConstraintRHSOvrdFromDate(ovrd,i_BranchConstraint,day,mth,yr), 1) = jdate(BranchConstraintRHSOvrdFromYear(ovrd,i_BranchConstraint), BranchConstraintRHSOvrdFromMonth(ovrd,i_BranchConstraint), BranchConstraintRHSOvrdFromDay(ovrd,i_BranchConstraint)) ;
BranchConstraintRHSOvrdToGDate(ovrd,i_BranchConstraint)$sum((toDay,toMth,toYr)$i_BranchConstraintRHSOvrdToDate(ovrd,i_BranchConstraint,toDay,toMth,toYr), 1) = jdate(BranchConstraintRHSOvrdToYear(ovrd,i_BranchConstraint), BranchConstraintRHSOvrdToMonth(ovrd,i_BranchConstraint), BranchConstraintRHSOvrdToDay(ovrd,i_BranchConstraint)) ;

* Determine if all the conditions for the branch constraint RHS are satisfied
loop((ovrd,tp,i_BranchConstraint,i_constraintRHS)$(i_studyTradePeriod(tp) and (BranchConstraintRHSOvrdFromGDate(ovrd,i_BranchConstraint) <= inputGDXgdate) and (BranchConstraintRHSOvrdToGDate(ovrd,i_BranchConstraint) >= inputGDXgdate) and i_BranchConstraintRHSOvrdTP(ovrd,i_BranchConstraint,tp) and i_BranchConstraintRHSOvrd(ovrd,i_BranchConstraint,i_constraintRHS)),
    if ((i_BranchConstraintRHSOvrd(ovrd,i_BranchConstraint,i_constraintRHS) <> 0),
      tradePeriodBranchConstraintRHSOvrd(tp,i_BranchConstraint,i_constraintRHS) = i_BranchConstraintRHSOvrd(ovrd,i_BranchConstraint,i_constraintRHS) ;
    elseif (i_BranchConstraintRHSOvrd(ovrd,i_BranchConstraint,i_constraintRHS) = eps),
      tradePeriodBranchConstraintRHSOvrd(tp,i_BranchConstraint,i_constraintRHS) = eps ;
    ) ;
) ;

* Reset the branch constraint RHS override parameters
  option clear = BranchConstraintRHSOvrdFromDay ;           option clear = BranchConstraintRHSOvrdFromMonth ;        option clear = BranchConstraintRHSOvrdFromYear ;
  option clear = BranchConstraintRHSOvrdToDay ;             option clear = BranchConstraintRHSOvrdToMonth ;          option clear = BranchConstraintRHSOvrdToYear ;
  option clear = BranchConstraintRHSOvrdFromGDate ;         option clear = BranchConstraintRHSOvrdToGDate ;

* Apply the branch constraint RHS override
i_tradePeriodBranchConstraintRHS(tp,i_BranchConstraint,i_constraintRHS)$(tradePeriodBranchConstraintRHSOvrd(tp,i_BranchConstraint,i_constraintRHS) <> 0) = tradePeriodBranchConstraintRHSOvrd(tp,i_BranchConstraint,i_constraintRHS) ;
i_tradePeriodBranchConstraintRHS(tp,i_BranchConstraint,i_constraintRHS)$(tradePeriodBranchConstraintRHSOvrd(tp,i_BranchConstraint,i_constraintRHS) and (tradePeriodBranchConstraintRHSOvrd(tp,i_BranchConstraint,i_constraintRHS) = eps)) = 0 ;
  option clear = tradePeriodBranchConstraintRHSOvrd ;

*+++ End branch constraint override +++

*+++ Start market node constraint override +++

* Reset the market node energy constraint factor override parameters
  option clear = MnodeEnergyConstraintFactorOvrdFromDay ;   option clear = MnodeEnergyConstraintFactorOvrdFromMonth ;        option clear = MnodeEnergyConstraintFactorOvrdFromYear ;
  option clear = MnodeEnergyConstraintFactorOvrdToDay ;     option clear = MnodeEnergyConstraintFactorOvrdToMonth ;          option clear = MnodeEnergyConstraintFactorOvrdToYear ;
  option clear = MnodeEnergyConstraintFactorOvrdFromGDate ; option clear = MnodeEnergyConstraintFactorOvrdToGDate ;

* Calculate the from and to date for the market node energy constraint factor override
MnodeEnergyConstraintFactorOvrdFromDay(ovrd,i_MnodeConstraint,o) = sum((day,mth,yr)$i_MnodeEnergyConstraintFactorOvrdFromDate(ovrd,i_MnodeConstraint,o,day,mth,yr), ord(day)) ;
MnodeEnergyConstraintFactorOvrdFromMonth(ovrd,i_MnodeConstraint,o) = sum((day,mth,yr)$i_MnodeEnergyConstraintFactorOvrdFromDate(ovrd,i_MnodeConstraint,o,day,mth,yr), ord(mth)) ;
MnodeEnergyConstraintFactorOvrdFromYear(ovrd,i_MnodeConstraint,o) = sum((day,mth,yr)$i_MnodeEnergyConstraintFactorOvrdFromDate(ovrd,i_MnodeConstraint,o,day,mth,yr), ord(yr) + startYear) ;

MnodeEnergyConstraintFactorOvrdToDay(ovrd,i_MnodeConstraint,o) = sum((toDay,toMth,toYr)$i_MnodeEnergyConstraintFactorOvrdToDate(ovrd,i_MnodeConstraint,o,toDay,toMth,toYr), ord(toDay)) ;
MnodeEnergyConstraintFactorOvrdToMonth(ovrd,i_MnodeConstraint,o) = sum((toDay,toMth,toYr)$i_MnodeEnergyConstraintFactorOvrdToDate(ovrd,i_MnodeConstraint,o,toDay,toMth,toYr), ord(toMth)) ;
MnodeEnergyConstraintFactorOvrdToYear(ovrd,i_MnodeConstraint,o) = sum((toDay,toMth,toYr)$i_MnodeEnergyConstraintFactorOvrdToDate(ovrd,i_MnodeConstraint,o,toDay,toMth,toYr), ord(toYr) + startYear) ;

MnodeEnergyConstraintFactorOvrdFromGDate(ovrd,i_MnodeConstraint,o)$sum((day,mth,yr)$i_MnodeEnergyConstraintFactorOvrdFromDate(ovrd,i_MnodeConstraint,o,day,mth,yr), 1) = jdate(MnodeEnergyConstraintFactorOvrdFromYear(ovrd,i_MnodeConstraint,o), MnodeEnergyConstraintFactorOvrdFromMonth(ovrd,i_MnodeConstraint,o), MnodeEnergyConstraintFactorOvrdFromDay(ovrd,i_MnodeConstraint,o)) ;
MnodeEnergyConstraintFactorOvrdToGDate(ovrd,i_MnodeConstraint,o)$sum((toDay,toMth,toYr)$i_MnodeEnergyConstraintFactorOvrdToDate(ovrd,i_MnodeConstraint,o,toDay,toMth,toYr), 1) = jdate(MnodeEnergyConstraintFactorOvrdToYear(ovrd,i_MnodeConstraint,o), MnodeEnergyConstraintFactorOvrdToMonth(ovrd,i_MnodeConstraint,o), MnodeEnergyConstraintFactorOvrdToDay(ovrd,i_MnodeConstraint,o)) ;

* Determine if all the conditions for the market node energy constraint factor are satisfied
loop((ovrd,tp,i_MnodeConstraint,o)$(i_studyTradePeriod(tp) and (MnodeEnergyConstraintFactorOvrdFromGDate(ovrd,i_MnodeConstraint,o) <= inputGDXgdate) and (MnodeEnergyConstraintFactorOvrdToGDate(ovrd,i_MnodeConstraint,o) >= inputGDXgdate) and i_MnodeEnergyConstraintFactorOvrdTP(ovrd,i_MnodeConstraint,o,tp) and i_MnodeEnergyConstraintFactorOvrd(ovrd,i_MnodeConstraint,o)),
    if ((i_MnodeEnergyConstraintFactorOvrd(ovrd,i_MnodeConstraint,o) <> 0),
      tradePeriodMnodeEnergyConstraintFactorOvrd(tp,i_MnodeConstraint,o) = i_MnodeEnergyConstraintFactorOvrd(ovrd,i_MnodeConstraint,o) ;
    elseif (i_MnodeEnergyConstraintFactorOvrd(ovrd,i_MnodeConstraint,o) = eps),
      tradePeriodMnodeEnergyConstraintFactorOvrd(tp,i_MnodeConstraint,o) = eps ;
    ) ;
) ;

* Reset the market node energy constraint factor override parameters
  option clear = MnodeEnergyConstraintFactorOvrdFromDay ;   option clear = MnodeEnergyConstraintFactorOvrdFromMonth ;        option clear = MnodeEnergyConstraintFactorOvrdFromYear ;
  option clear = MnodeEnergyConstraintFactorOvrdToDay ;     option clear = MnodeEnergyConstraintFactorOvrdToMonth ;          option clear = MnodeEnergyConstraintFactorOvrdToYear ;
  option clear = MnodeEnergyConstraintFactorOvrdFromGDate ; option clear = MnodeEnergyConstraintFactorOvrdToGDate ;

* Apply the market node energy constraint factor override
i_tradePeriodMnodeEnergyOfferConstraintFactors(tp,i_MnodeConstraint,o)$(tradePeriodMnodeEnergyConstraintFactorOvrd(tp,i_MnodeConstraint,o) <> 0) = tradePeriodMnodeEnergyConstraintFactorOvrd(tp,i_MnodeConstraint,o) ;
i_tradePeriodMnodeEnergyOfferConstraintFactors(tp,i_MnodeConstraint,o)$(tradePeriodMnodeEnergyConstraintFactorOvrd(tp,i_MnodeConstraint,o) and (tradePeriodMnodeEnergyConstraintFactorOvrd(tp,i_MnodeConstraint,o) = eps)) = 0 ;
  option clear = tradePeriodMnodeEnergyConstraintFactorOvrd ;

* Reset the market node reserve constraint factor override parameters
  option clear = MnodeReserveConstraintFactorOvrdFromDay ;          option clear = MnodeReserveConstraintFactorOvrdFromMonth ;       option clear = MnodeReserveConstraintFactorOvrdFromYear ;
  option clear = MnodeReserveConstraintFactorOvrdToDay ;            option clear = MnodeReserveConstraintFactorOvrdToMonth ;         option clear = MnodeReserveConstraintFactorOvrdToYear ;
  option clear = MnodeReserveConstraintFactorOvrdFromGDate ;        option clear = MnodeReserveConstraintFactorOvrdToGDate ;

* Calculate the from and to date for the market node reserve constraint factor override
MnodeReserveConstraintFactorOvrdFromDay(ovrd,i_MnodeConstraint,o,i_reserveClass) = sum((day,mth,yr)$i_MnodeReserveConstraintFactorOvrdFromDate(ovrd,i_MnodeConstraint,o,i_reserveClass,day,mth,yr), ord(day)) ;
MnodeReserveConstraintFactorOvrdFromMonth(ovrd,i_MnodeConstraint,o,i_reserveClass) = sum((day,mth,yr)$i_MnodeReserveConstraintFactorOvrdFromDate(ovrd,i_MnodeConstraint,o,i_reserveClass,day,mth,yr), ord(mth)) ;
MnodeReserveConstraintFactorOvrdFromYear(ovrd,i_MnodeConstraint,o,i_reserveClass) = sum((day,mth,yr)$i_MnodeReserveConstraintFactorOvrdFromDate(ovrd,i_MnodeConstraint,o,i_reserveClass,day,mth,yr), ord(yr) + startYear) ;

MnodeReserveConstraintFactorOvrdToDay(ovrd,i_MnodeConstraint,o,i_reserveClass) = sum((toDay,toMth,toYr)$i_MnodeReserveConstraintFactorOvrdToDate(ovrd,i_MnodeConstraint,o,i_reserveClass,toDay,toMth,toYr), ord(toDay)) ;
MnodeReserveConstraintFactorOvrdToMonth(ovrd,i_MnodeConstraint,o,i_reserveClass) = sum((toDay,toMth,toYr)$i_MnodeReserveConstraintFactorOvrdToDate(ovrd,i_MnodeConstraint,o,i_reserveClass,toDay,toMth,toYr), ord(toMth)) ;
MnodeReserveConstraintFactorOvrdToYear(ovrd,i_MnodeConstraint,o,i_reserveClass) = sum((toDay,toMth,toYr)$i_MnodeReserveConstraintFactorOvrdToDate(ovrd,i_MnodeConstraint,o,i_reserveClass,toDay,toMth,toYr), ord(toYr) + startYear) ;

MnodeReserveConstraintFactorOvrdFromGDate(ovrd,i_MnodeConstraint,o,i_reserveClass)$sum((day,mth,yr)$i_MnodeReserveConstraintFactorOvrdFromDate(ovrd,i_MnodeConstraint,o,i_reserveClass,day,mth,yr), 1) = jdate(MnodeReserveConstraintFactorOvrdFromYear(ovrd,i_MnodeConstraint,o,i_reserveClass), MnodeReserveConstraintFactorOvrdFromMonth(ovrd,i_MnodeConstraint,o,i_reserveClass), MnodeReserveConstraintFactorOvrdFromDay(ovrd,i_MnodeConstraint,o,i_reserveClass)) ;
MnodeReserveConstraintFactorOvrdToGDate(ovrd,i_MnodeConstraint,o,i_reserveClass)$sum((toDay,toMth,toYr)$i_MnodeReserveConstraintFactorOvrdToDate(ovrd,i_MnodeConstraint,o,i_reserveClass,toDay,toMth,toYr), 1) = jdate(MnodeReserveConstraintFactorOvrdToYear(ovrd,i_MnodeConstraint,o,i_reserveClass), MnodeReserveConstraintFactorOvrdToMonth(ovrd,i_MnodeConstraint,o,i_reserveClass), MnodeReserveConstraintFactorOvrdToDay(ovrd,i_MnodeConstraint,o,i_reserveClass)) ;

* Determine if all the conditions for the market node reserve constraint factor are satisfied
loop((ovrd,tp,i_MnodeConstraint,o,i_reserveClass)$(i_studyTradePeriod(tp) and (MnodeReserveConstraintFactorOvrdFromGDate(ovrd,i_MnodeConstraint,o,i_reserveClass) <= inputGDXgdate) and (MnodeReserveConstraintFactorOvrdToGDate(ovrd,i_MnodeConstraint,o,i_reserveClass) >= inputGDXgdate) and i_MnodeReserveConstraintFactorOvrdTP(ovrd,i_MnodeConstraint,o,i_reserveClass,tp) and i_MnodeReserveConstraintFactorOvrd(ovrd,i_MnodeConstraint,o,i_reserveClass)),
    if ((i_MnodeReserveConstraintFactorOvrd(ovrd,i_MnodeConstraint,o,i_reserveClass) <> 0),
      tradePeriodMnodeReserveConstraintFactorOvrd(tp,i_MnodeConstraint,o,i_reserveClass) = i_MnodeReserveConstraintFactorOvrd(ovrd,i_MnodeConstraint,o,i_reserveClass) ;
    elseif (i_MnodeReserveConstraintFactorOvrd(ovrd,i_MnodeConstraint,o,i_reserveClass) = eps),
      tradePeriodMnodeReserveConstraintFactorOvrd(tp,i_MnodeConstraint,o,i_reserveClass) = eps ;
    ) ;
) ;

* Reset the market node reserve constraint factor override parameters
  option clear = MnodeReserveConstraintFactorOvrdFromDay ;          option clear = MnodeReserveConstraintFactorOvrdFromMonth ;       option clear = MnodeReserveConstraintFactorOvrdFromYear ;
  option clear = MnodeReserveConstraintFactorOvrdToDay ;            option clear = MnodeReserveConstraintFactorOvrdToMonth ;         option clear = MnodeReserveConstraintFactorOvrdToYear ;
  option clear = MnodeReserveConstraintFactorOvrdFromGDate ;        option clear = MnodeReserveConstraintFactorOvrdToGDate ;

* Apply the market node reserve constraint factor override
i_tradePeriodMnodeReserveOfferConstraintFactors(tp,i_MnodeConstraint,o,i_reserveClass,i_reserveType)$(tradePeriodMnodeReserveConstraintFactorOvrd(tp,i_MnodeConstraint,o,i_reserveClass) <> 0) = tradePeriodMnodeReserveConstraintFactorOvrd(tp,i_MnodeConstraint,o,i_reserveClass) ;
i_tradePeriodMnodeReserveOfferConstraintFactors(tp,i_MnodeConstraint,o,i_reserveClass,i_reserveType)$(tradePeriodMnodeReserveConstraintFactorOvrd(tp,i_MnodeConstraint,o,i_reserveClass) and (tradePeriodMnodeReserveConstraintFactorOvrd(tp,i_MnodeConstraint,o,i_reserveClass) = eps)) = 0 ;
  option clear = tradePeriodMnodeReserveConstraintFactorOvrd ;

* Reset the market node reserve constraint RHS override parameters
  option clear = MnodeConstraintRHSOvrdFromDay ;            option clear = MnodeConstraintRHSOvrdFromMonth ;         option clear = MnodeConstraintRHSOvrdFromYear ;
  option clear = MnodeConstraintRHSOvrdToDay ;              option clear = MnodeConstraintRHSOvrdToMonth ;           option clear = MnodeConstraintRHSOvrdToYear ;
  option clear = MnodeConstraintRHSOvrdFromGDate ;          option clear = MnodeConstraintRHSOvrdToGDate ;

* Calculate the from and to date for the market node RHS override
MnodeConstraintRHSOvrdFromDay(ovrd,i_MnodeConstraint) = sum((day,mth,yr)$i_MnodeConstraintRHSOvrdFromDate(ovrd,i_MnodeConstraint,day,mth,yr), ord(day)) ;
MnodeConstraintRHSOvrdFromMonth(ovrd,i_MnodeConstraint) = sum((day,mth,yr)$i_MnodeConstraintRHSOvrdFromDate(ovrd,i_MnodeConstraint,day,mth,yr), ord(mth)) ;
MnodeConstraintRHSOvrdFromYear(ovrd,i_MnodeConstraint) = sum((day,mth,yr)$i_MnodeConstraintRHSOvrdFromDate(ovrd,i_MnodeConstraint,day,mth,yr), ord(yr) + startYear) ;

MnodeConstraintRHSOvrdToDay(ovrd,i_MnodeConstraint) = sum((toDay,toMth,toYr)$i_MnodeConstraintRHSOvrdToDate(ovrd,i_MnodeConstraint,toDay,toMth,toYr), ord(toDay)) ;
MnodeConstraintRHSOvrdToMonth(ovrd,i_MnodeConstraint) = sum((toDay,toMth,toYr)$i_MnodeConstraintRHSOvrdToDate(ovrd,i_MnodeConstraint,toDay,toMth,toYr), ord(toMth)) ;
MnodeConstraintRHSOvrdToYear(ovrd,i_MnodeConstraint) = sum((toDay,toMth,toYr)$i_MnodeConstraintRHSOvrdToDate(ovrd,i_MnodeConstraint,toDay,toMth,toYr), ord(toYr) + startYear) ;

MnodeConstraintRHSOvrdFromGDate(ovrd,i_MnodeConstraint)$sum((day,mth,yr)$i_MnodeConstraintRHSOvrdFromDate(ovrd,i_MnodeConstraint,day,mth,yr), 1) = jdate(MnodeConstraintRHSOvrdFromYear(ovrd,i_MnodeConstraint), MnodeConstraintRHSOvrdFromMonth(ovrd,i_MnodeConstraint), MnodeConstraintRHSOvrdFromDay(ovrd,i_MnodeConstraint)) ;
MnodeConstraintRHSOvrdToGDate(ovrd,i_MnodeConstraint)$sum((toDay,toMth,toYr)$i_MnodeConstraintRHSOvrdToDate(ovrd,i_MnodeConstraint,toDay,toMth,toYr), 1) = jdate(MnodeConstraintRHSOvrdToYear(ovrd,i_MnodeConstraint), MnodeConstraintRHSOvrdToMonth(ovrd,i_MnodeConstraint), MnodeConstraintRHSOvrdToDay(ovrd,i_MnodeConstraint)) ;

* Determine if all the conditions for the market node constraint RHS are satisfied
loop((ovrd,tp,i_MnodeConstraint,i_constraintRHS)$(i_studyTradePeriod(tp) and (MnodeConstraintRHSOvrdFromGDate(ovrd,i_MnodeConstraint) <= inputGDXgdate) and (MnodeConstraintRHSOvrdToGDate(ovrd,i_MnodeConstraint) >= inputGDXgdate) and i_MnodeConstraintRHSOvrdTP(ovrd,i_MnodeConstraint,tp) and i_MnodeConstraintRHSOvrd(ovrd,i_MnodeConstraint,i_constraintRHS)),
    if ((i_MnodeConstraintRHSOvrd(ovrd,i_MnodeConstraint,i_constraintRHS) <> 0),
      tradePeriodMnodeConstraintRHSOvrd(tp,i_MnodeConstraint,i_constraintRHS) = i_MnodeConstraintRHSOvrd(ovrd,i_MnodeConstraint,i_constraintRHS) ;
    elseif (i_MnodeConstraintRHSOvrd(ovrd,i_MnodeConstraint,i_constraintRHS) = eps),
      tradePeriodMnodeConstraintRHSOvrd(tp,i_MnodeConstraint,i_constraintRHS) = eps ;
    ) ;
) ;

* Reset the market node reserve constraint RHS override parameters
  option clear = MnodeConstraintRHSOvrdFromDay ;    option clear = MnodeConstraintRHSOvrdFromMonth ;         option clear = MnodeConstraintRHSOvrdFromYear ;
  option clear = MnodeConstraintRHSOvrdToDay ;      option clear = MnodeConstraintRHSOvrdToMonth ;           option clear = MnodeConstraintRHSOvrdToYear ;
  option clear = MnodeConstraintRHSOvrdFromGDate ;  option clear = MnodeConstraintRHSOvrdToGDate ;

* Market node constraint RHS override
i_tradePeriodMnodeConstraintRHS(tp,i_MnodeConstraint,i_constraintRHS)$(tradePeriodMnodeConstraintRHSOvrd(tp,i_MnodeConstraint,i_constraintRHS) <> 0) = tradePeriodMnodeConstraintRHSOvrd(tp,i_MnodeConstraint,i_constraintRHS) ;
i_tradePeriodMnodeConstraintRHS(tp,i_MnodeConstraint,i_constraintRHS)$(tradePeriodMnodeConstraintRHSOvrd(tp,i_MnodeConstraint,i_constraintRHS) and (tradePeriodMnodeConstraintRHSOvrd(tp,i_MnodeConstraint,i_constraintRHS) = eps)) = 0 ;
  option clear = tradePeriodMnodeConstraintRHSOvrd ;

*+++ End market node constraint override +++

*+++ Start risk/reserve override +++

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

* Calculate the from and to date for the CE RAF override
RAFovrdDay(ovrd,i_island,i_reserveClass) = sum((day,mth,yr)$i_contingentEventRAFovrdFromDate(ovrd,i_island,i_reserveClass,day,mth,yr), ord(day)) ;
RAFovrdMonth(ovrd,i_island,i_reserveClass) = sum((day,mth,yr)$i_contingentEventRAFovrdFromDate(ovrd,i_island,i_reserveClass,day,mth,yr), ord(mth)) ;
RAFovrdYear(ovrd,i_island,i_reserveClass) = sum((day,mth,yr)$i_contingentEventRAFovrdFromDate(ovrd,i_island,i_reserveClass,day,mth,yr), ord(yr) + startYear) ;
CERAFovrdFromGDate(ovrd,i_island,i_reserveClass)$sum((day,mth,yr)$i_contingentEventRAFovrdFromDate(ovrd,i_island,i_reserveClass,day,mth,yr), 1) = jdate(RAFovrdYear(ovrd,i_island,i_reserveClass), RAFovrdMonth(ovrd,i_island,i_reserveClass), RAFovrdDay(ovrd,i_island,i_reserveClass)) ;

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

RAFovrdDay(ovrd,i_island,i_reserveClass) = sum((toDay,toMth,toYr)$i_contingentEventRAFovrdToDate(ovrd,i_island,i_reserveClass,toDay,toMth,toYr), ord(toDay)) ;
RAFovrdMonth(ovrd,i_island,i_reserveClass) = sum((toDay,toMth,toYr)$i_contingentEventRAFovrdToDate(ovrd,i_island,i_reserveClass,toDay,toMth,toYr), ord(toMth)) ;
RAFovrdYear(ovrd,i_island,i_reserveClass) = sum((toDay,toMth,toYr)$i_contingentEventRAFovrdToDate(ovrd,i_island,i_reserveClass,toDay,toMth,toYr), ord(toYr) + startYear) ;
CERAFovrdToGDate(ovrd,i_island,i_reserveClass)$sum((toDay,toMth,toYr)$i_contingentEventRAFovrdToDate(ovrd,i_island,i_reserveClass,toDay,toMth,toYr), 1) = jdate(RAFovrdYear(ovrd,i_island,i_reserveClass), RAFovrdMonth(ovrd,i_island,i_reserveClass), RAFovrdDay(ovrd,i_island,i_reserveClass)) ;

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

* Determine if all the conditions for the CE RAF override are satisfied
loop((ovrd,tp,i_island,i_reserveClass)$(i_studyTradePeriod(tp) and (CERAFovrdFromGDate(ovrd,i_island,i_reserveClass) <= inputGDXgdate) and (CERAFovrdToGDate(ovrd,i_island,i_reserveClass) >= inputGDXgdate) and i_contingentEventRAFovrdTP(ovrd,i_island,i_reserveClass,tp) and i_contingentEventRAFovrd(ovrd,i_island,i_reserveClass)),
    if ((i_contingentEventRAFovrd(ovrd,i_island,i_reserveClass) > 0),
      tradePeriodCERAFovrd(tp,i_island,i_reserveClass) = i_contingentEventRAFovrd(ovrd,i_island,i_reserveClass) ;
    elseif (i_contingentEventRAFovrd(ovrd,i_island,i_reserveClass) = eps),
      tradePeriodCERAFovrd(tp,i_island,i_reserveClass) = eps ;
    ) ;
) ;

* Apply the CE RAF override
i_tradePeriodRiskParameter(tp,i_island,i_reserveClass,'GENRISK','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(tp,i_island,i_reserveClass) > 0) = tradePeriodCERAFovrd(tp,i_island,i_reserveClass) ;
i_tradePeriodRiskParameter(tp,i_island,i_reserveClass,'DCCE','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(tp,i_island,i_reserveClass) > 0) = tradePeriodCERAFovrd(tp,i_island,i_reserveClass) ;
i_tradePeriodRiskParameter(tp,i_island,i_reserveClass,'Manual','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(tp,i_island,i_reserveClass) > 0) = tradePeriodCERAFovrd(tp,i_island,i_reserveClass) ;
i_tradePeriodRiskParameter(tp,i_island,i_reserveClass,'GENRISK','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(tp,i_island,i_reserveClass) and (tradePeriodCERAFovrd(tp,i_island,i_reserveClass) = eps)) = 0 ;
i_tradePeriodRiskParameter(tp,i_island,i_reserveClass,'DCCE','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(tp,i_island,i_reserveClass) and (tradePeriodCERAFovrd(tp,i_island,i_reserveClass) = eps)) = 0 ;
i_tradePeriodRiskParameter(tp,i_island,i_reserveClass,'Manual','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(tp,i_island,i_reserveClass) and (tradePeriodCERAFovrd(tp,i_island,i_reserveClass) = eps)) = 0 ;
  option clear = tradePeriodCERAFovrd ;

* Calculate the from and to date for the ECE RAF override
RAFovrdDay(ovrd,i_island,i_reserveClass) = sum((day,mth,yr)$i_extendedContingentEventRAFovrdFromDate(ovrd,i_island,i_reserveClass,day,mth,yr), ord(day)) ;
RAFovrdMonth(ovrd,i_island,i_reserveClass) = sum((day,mth,yr)$i_extendedContingentEventRAFovrdFromDate(ovrd,i_island,i_reserveClass,day,mth,yr), ord(mth)) ;
RAFovrdYear(ovrd,i_island,i_reserveClass) = sum((day,mth,yr)$i_extendedContingentEventRAFovrdFromDate(ovrd,i_island,i_reserveClass,day,mth,yr), ord(yr) + startYear) ;
ECERAFovrdFromGDate(ovrd,i_island,i_reserveClass)$sum((day,mth,yr)$i_extendedContingentEventRAFovrdFromDate(ovrd,i_island,i_reserveClass,day,mth,yr), 1) = jdate(RAFovrdYear(ovrd,i_island,i_reserveClass), RAFovrdMonth(ovrd,i_island,i_reserveClass), RAFovrdDay(ovrd,i_island,i_reserveClass)) ;

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

RAFovrdDay(ovrd,i_island,i_reserveClass) = sum((toDay,toMth,toYr)$i_extendedContingentEventRAFovrdToDate(ovrd,i_island,i_reserveClass,toDay,toMth,toYr), ord(toDay)) ;
RAFovrdMonth(ovrd,i_island,i_reserveClass) = sum((toDay,toMth,toYr)$i_extendedContingentEventRAFovrdToDate(ovrd,i_island,i_reserveClass,toDay,toMth,toYr), ord(toMth)) ;
RAFovrdYear(ovrd,i_island,i_reserveClass) = sum((toDay,toMth,toYr)$i_extendedContingentEventRAFovrdToDate(ovrd,i_island,i_reserveClass,toDay,toMth,toYr), ord(toYr) + startYear) ;
ECERAFovrdToGDate(ovrd,i_island,i_reserveClass)$sum((toDay,toMth,toYr)$i_extendedContingentEventRAFovrdToDate(ovrd,i_island,i_reserveClass,toDay,toMth,toYr), 1) = jdate(RAFovrdYear(ovrd,i_island,i_reserveClass), RAFovrdMonth(ovrd,i_island,i_reserveClass), RAFovrdDay(ovrd,i_island,i_reserveClass)) ;

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

* Determine if all the conditions for the ECE RAF override are satisfied
loop((ovrd,tp,i_island,i_reserveClass)$(i_studyTradePeriod(tp) and (ECERAFovrdFromGDate(ovrd,i_island,i_reserveClass) <= inputGDXgdate) and (ECERAFovrdToGDate(ovrd,i_island,i_reserveClass) >= inputGDXgdate) and i_extendedContingentEventRAFovrdTP(ovrd,i_island,i_reserveClass,tp) and i_extendedContingentEventRAFovrd(ovrd,i_island,i_reserveClass)),
    if ((i_extendedContingentEventRAFovrd(ovrd,i_island,i_reserveClass) > 0),
      tradePeriodECERAFovrd(tp,i_island,i_reserveClass) = i_extendedContingentEventRAFovrd(ovrd,i_island,i_reserveClass) ;
    elseif (i_extendedContingentEventRAFovrd(ovrd,i_island,i_reserveClass) = eps),
      tradePeriodECERAFovrd(tp,i_island,i_reserveClass) = eps ;
    ) ;
) ;

* Reset the RAF override parameters
  option clear = CERAFovrdFromGDate ;       option clear = CERAFovrdToGDate ;        option clear = ECERAFovrdFromGDate ;             option clear = ECERAFovrdToGDate ;

* Apply the ECE RAF override
i_tradePeriodRiskParameter(tp,i_island,i_reserveClass,'DCECE','i_riskAdjustmentFactor')$(tradePeriodECERAFovrd(tp,i_island,i_reserveClass) > 0) = tradePeriodECERAFovrd(tp,i_island,i_reserveClass) ;
i_tradePeriodRiskParameter(tp,i_island,i_reserveClass,'DCECE','i_riskAdjustmentFactor')$(tradePeriodECERAFovrd(tp,i_island,i_reserveClass) and (tradePeriodECERAFovrd(tp,i_island,i_reserveClass) = eps)) = 0 ;
  option clear = tradePeriodECERAFovrd ;

* Reset the CE NFR override parameters
  option clear = CENFRovrdDay ;             option clear = CENFRovrdMonth ;          option clear = CENFRovrdYear ;

* Calculate the from and to date for the CE NFR override
CENFRovrdDay(ovrd,i_island,i_reserveClass,i_riskClass) = sum((day,mth,yr)$i_contingentEventNFRovrdFromDate(ovrd,i_island,i_reserveClass,i_riskClass,day,mth,yr), ord(day)) ;
CENFRovrdMonth(ovrd,i_island,i_reserveClass,i_riskClass) = sum((day,mth,yr)$i_contingentEventNFRovrdFromDate(ovrd,i_island,i_reserveClass,i_riskClass,day,mth,yr), ord(mth)) ;
CENFRovrdYear(ovrd,i_island,i_reserveClass,i_riskClass) = sum((day,mth,yr)$i_contingentEventNFRovrdFromDate(ovrd,i_island,i_reserveClass,i_riskClass,day,mth,yr), ord(yr) + startYear) ;
CENFRovrdFromGDate(ovrd,i_island,i_reserveClass,i_riskClass)$sum((day,mth,yr)$i_contingentEventNFRovrdFromDate(ovrd,i_island,i_reserveClass,i_riskClass,day,mth,yr), 1) = jdate(CENFRovrdYear(ovrd,i_island,i_reserveClass,i_riskClass), CENFRovrdMonth(ovrd,i_island,i_reserveClass,i_riskClass), CENFRovrdDay(ovrd,i_island,i_reserveClass,i_riskClass)) ;

* Reset the CE NFR override parameters
  option clear = CENFRovrdDay ;             option clear = CENFRovrdMonth ;          option clear = CENFRovrdYear ;

* Calculate the from and to date for the CE NFR override
CENFRovrdDay(ovrd,i_island,i_reserveClass,i_riskClass) = sum((toDay,toMth,toYr)$i_contingentEventNFRovrdToDate(ovrd,i_island,i_reserveClass,i_riskClass,toDay,toMth,toYr), ord(toDay)) ;
CENFRovrdMonth(ovrd,i_island,i_reserveClass,i_riskClass) = sum((toDay,toMth,toYr)$i_contingentEventNFRovrdToDate(ovrd,i_island,i_reserveClass,i_riskClass,toDay,toMth,toYr), ord(toMth)) ;
CENFRovrdYear(ovrd,i_island,i_reserveClass,i_riskClass) = sum((toDay,toMth,toYr)$i_contingentEventNFRovrdToDate(ovrd,i_island,i_reserveClass,i_riskClass,toDay,toMth,toYr), ord(toYr) + startYear) ;
CENFRovrdToGDate(ovrd,i_island,i_reserveClass,i_riskClass)$sum((toDay,toMth,toYr)$i_contingentEventNFRovrdToDate(ovrd,i_island,i_reserveClass,i_riskClass,toDay,toMth,toYr), 1) = jdate(CENFRovrdYear(ovrd,i_island,i_reserveClass,i_riskClass), CENFRovrdMonth(ovrd,i_island,i_reserveClass,i_riskClass), CENFRovrdDay(ovrd,i_island,i_reserveClass,i_riskClass)) ;

* Reset the CE NFR override parameters
  option clear = CENFRovrdDay ;             option clear = CENFRovrdMonth ;          option clear = CENFRovrdYear ;

* Determine if all the conditions for the CE NFR override are satisfied
loop((ovrd,tp,i_island,i_reserveClass,i_riskClass)$(i_studyTradePeriod(tp) and (CENFRovrdFromGDate(ovrd,i_island,i_reserveClass,i_riskClass) <= inputGDXgdate) and (CENFRovrdToGDate(ovrd,i_island,i_reserveClass,i_riskClass) >= inputGDXgdate) and i_contingentEventNFRovrdTP(ovrd,i_island,i_reserveClass,i_riskClass,tp) and i_contingentEventNFRovrd(ovrd,i_island,i_reserveClass,i_riskClass)),
    if ((i_contingentEventNFRovrd(ovrd,i_island,i_reserveClass,i_riskClass) <> 0),
      tradePeriodCENFRovrd(tp,i_island,i_reserveClass,i_riskClass) = i_contingentEventNFRovrd(ovrd,i_island,i_reserveClass,i_riskClass) ;
    elseif (i_contingentEventNFRovrd(ovrd,i_island,i_reserveClass,i_riskClass) = eps),
      tradePeriodCENFRovrd(tp,i_island,i_reserveClass,i_riskClass) = eps ;
    ) ;
) ;

* Reset the CE NFR override parameters
  option clear = CENFRovrdFromGDate ;       option clear = CENFRovrdToGDate ;

* Apply the CE NFR override
i_tradePeriodRiskParameter(tp,i_island,i_reserveClass,i_riskClass,'i_FreeReserve')$(tradePeriodCENFRovrd(tp,i_island,i_reserveClass,i_riskClass) <> 0) = tradePeriodCENFRovrd(tp,i_island,i_reserveClass,i_riskClass) ;
i_tradePeriodRiskParameter(tp,i_island,i_reserveClass,i_riskClass,'i_FreeReserve')$(tradePeriodCENFRovrd(tp,i_island,i_reserveClass,i_riskClass) and (tradePeriodCENFRovrd(tp,i_island,i_reserveClass,i_riskClass) = eps)) = 0 ;
  option clear = tradePeriodCENFRovrd ;

* Reset the HVDC risk override parameters
  option clear = HVDCriskOvrdDay ;          option clear = HVDCriskOvrdMonth ;       option clear = HVDCriskOvrdYear ;

* Calculate the from date for the HVDC risk override
HVDCriskOvrdDay(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = sum((day,mth,yr)$i_HVDCriskParamOvrdFromDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,day,mth,yr), ord(day)) ;
HVDCriskOvrdMonth(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = sum((day,mth,yr)$i_HVDCriskParamOvrdFromDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,day,mth,yr), ord(mth)) ;
HVDCriskOvrdYear(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = sum((day,mth,yr)$i_HVDCriskParamOvrdFromDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,day,mth,yr), ord(yr) + startYear) ;
HVDCriskOvrdFromGDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)$sum((day,mth,yr)$i_HVDCriskParamOvrdFromDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,day,mth,yr), 1) = jdate(HVDCriskOvrdYear(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter), HVDCriskOvrdMonth(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter), HVDCriskOvrdDay(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)) ;

* Reset the HVDC risk override parameters
  option clear = HVDCriskOvrdDay ;          option clear = HVDCriskOvrdMonth ;       option clear = HVDCriskOvrdYear ;

* Calculate the to date for the HVDC risk override
HVDCriskOvrdDay(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = sum((toDay,toMth,toYr)$i_HVDCriskParamOvrdToDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,toDay,toMth,toYr), ord(toDay)) ;
HVDCriskOvrdMonth(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = sum((toDay,toMth,toYr)$i_HVDCriskParamOvrdToDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,toDay,toMth,toYr), ord(toMth)) ;
HVDCriskOvrdYear(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = sum((toDay,toMth,toYr)$i_HVDCriskParamOvrdToDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,toDay,toMth,toYr), ord(toYr) + startYear) ;
HVDCriskOvrdToGDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)$sum((toDay,toMth,toYr)$i_HVDCriskParamOvrdToDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,toDay,toMth,toYr), 1) = jdate(HVDCriskOvrdYear(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter), HVDCriskOvrdMonth(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter), HVDCriskOvrdDay(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)) ;

* Reset the HVDC risk override parameters
  option clear = HVDCriskOvrdDay ;          option clear = HVDCriskOvrdMonth ;       option clear = HVDCriskOvrdYear ;

* Determine if all the conditions for the HVDC risk overrides are satisfied
loop((ovrd,tp,i_island,i_reserveClass,i_riskClass,i_riskParameter)$(i_studyTradePeriod(tp) and (HVDCriskOvrdFromGDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) <= inputGDXgdate) and (HVDCriskOvrdToGDate(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) >= inputGDXgdate) and i_HVDCriskParamOvrdTP(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,tp) and i_HVDCriskParamOvrd(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)),
    if ((i_HVDCriskParamOvrd(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) <> 0),
      tradePeriodHVDCriskOvrd(tp,i_island,i_reserveClass,i_riskClass,i_riskParameter) = i_HVDCriskParamOvrd(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) ;
    elseif (i_HVDCriskParamOvrd(ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = eps),
      tradePeriodHVDCriskOvrd(tp,i_island,i_reserveClass,i_riskClass,i_riskParameter) = eps ;
    ) ;
) ;

* Reset the HVDC risk override parameters
  option clear = HVDCriskOvrdFromGDate ;       option clear = HVDCriskOvrdToGDate ;

* Apply HVDC risk override
i_tradePeriodRiskParameter(tp,i_island,i_reserveClass,i_riskClass,i_riskParameter)$(tradePeriodHVDCriskOvrd(tp,i_island,i_reserveClass,i_riskClass,i_riskParameter) <> 0) = tradePeriodHVDCriskOvrd(tp,i_island,i_reserveClass,i_riskClass,i_riskParameter) ;
i_tradePeriodRiskParameter(tp,i_island,i_reserveClass,i_riskClass,i_riskParameter)$(tradePeriodHVDCriskOvrd(tp,i_island,i_reserveClass,i_riskClass,i_riskParameter) and (tradePeriodHVDCriskOvrd(tp,i_island,i_reserveClass,i_riskClass,i_riskParameter) = eps)) = 0 ;
  option clear = tradePeriodHVDCriskOvrd ;

*+++ End risk/reserve overrides +++
$offtext


* End EMI and Standalone interface override assignments
$label skipEMIandStandaloneOverrides
