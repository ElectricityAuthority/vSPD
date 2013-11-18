*=====================================================================================
* Name:                 vSPDsolveOverrides.gms
* Function:             Code to be included in vSPDsolve to take care of input data
*                       overrides.
* Developed by:         Ramu Naidoo (Electricity Authority, New Zealand)
* Last modified by:     Ramu Naidoo on 17 April 2013
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


* Excel interface - declare and initialise overrides
$if not %interfaceMode%==1 $goto skipOverridesWithExcel
Parameters
  i_energyOfferOvrd(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent)  'Override for energy offers for specified trade period'
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
i_tradePeriodEnergyOffer(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent)$( i_energyOfferOvrd(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent) > 0 )
  = i_energyOfferOvrd(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent) ;
i_tradePeriodEnergyOffer(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent)$( i_energyOfferOvrd(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent) * ( i_energyOfferOvrd(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent) = eps ) )
  = 0 ;

* Offer parameter overrides
i_tradePeriodOfferParameter(i_tradePeriod,i_offer,i_offerParam)$( i_offerParamOvrd(i_tradePeriod,i_offer,i_offerParam) > 0 ) = i_offerParamOvrd(i_tradePeriod,i_offer,i_offerParam) ;
i_tradePeriodOfferParameter(i_tradePeriod,i_offer,i_offerParam)$( i_offerParamOvrd(i_tradePeriod,i_offer,i_offerParam) * ( i_offerParamOvrd(i_tradePeriod,i_offer,i_offerParam) = eps ) ) = 0 ;

$label skipOverridesWithExcel


* EMI and Standalone interface - declare override symbols
$if %interfaceMode%==1 $goto skipEMIandStandaloneOverrides
* Declare override symbols to be used for both EMI and standalone interface types
* NB: The following declarations are not skipped if in Excel interface mode - no harm is done by declaring symbols and then never using them.
Sets
* Offer overrides
  i_offerParamOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear)           'Offer parameter override from date'
  i_offerParamOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear)                   'Offer parameter override to date'
  i_offerParamOvrdTP(i_ovrd,i_offer,i_tradePeriod)                                    'Offer parameter override trade period'
  i_energyOfferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear)          'Energy offer override from date'
  i_energyOfferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear)                  'Energy offer override to date'
  i_energyOfferOvrdTP(i_ovrd,i_offer,i_tradePeriod)                                   'Energy offer override trade period'
  i_PLSRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear)            'PLSR offer override from date'
  i_PLSRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear)                    'PLSR offer override to date'
  i_PLSRofferOvrdTP(i_ovrd,i_offer,i_tradePeriod)                                     'PLSR offer override trade period'
  i_TWDRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear)            'TWDR offer override from date'
  i_TWDRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear)                    'TWDR offer override to date'
  i_TWDRofferOvrdTP(i_ovrd,i_offer,i_tradePeriod)                                     'TWDR offer override trade period'
  i_ILRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear)             'ILR offer override from date'
  i_ILRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear)                     'ILR offer override to date'
  i_ILRofferOvrdTP(i_ovrd,i_offer,i_tradePeriod)                                      'ILR offer override trade period'
* Demand overrides
  i_islandDemandOvrdFromDate(i_ovrd,i_Island,i_dayNum,i_monthNum,i_yearNum)           'Island demand override from date'
  i_islandDemandOvrdToDate(i_ovrd,i_Island,i_dayNum,i_monthNum,i_yearNum)             'Island demand override to date'
  i_islandDemandOvrdTP(i_ovrd,i_Island,i_tradePeriod)                                 'Island demand override trade period'
  i_nodeDemandOvrdFromDate(i_ovrd,i_node,i_dayNum,i_monthNum,i_yearNum)               'Node demand override from date'
  i_nodeDemandOvrdToDate(i_ovrd,i_node,i_dayNum,i_monthNum,i_yearNum)                 'Node demand override to date'
  i_nodeDemandOvrdTP(i_ovrd,i_node,i_tradePeriod)                                     'Node demand override trade period'
* Branch overrides
  i_branchParamOvrdFromDate(i_ovrd,i_branch,i_fromDay,i_fromMonth,i_fromYear)         'Branch parameter override from date'
  i_branchParamOvrdToDate(i_ovrd,i_branch,i_toDay,i_toMonth,i_toYear)                 'Branch parameter override to date'
  i_branchParamOvrdTP(i_ovrd,i_branch,i_tradePeriod)                                  'Branch parameter override trade period'
  i_branchCapacityOvrdFromDate(i_ovrd,i_branch,i_fromDay,i_fromMonth,i_fromYear)      'Branch capacity override from date'
  i_branchCapacityOvrdToDate(i_ovrd,i_branch,i_toDay,i_toMonth,i_toYear)              'Branch capacity override to date'
  i_branchCapacityOvrdTP(i_ovrd,i_branch,i_tradePeriod)                               'Branch capacity override trade period'
  i_branchOpenStatusOvrdFromDate(i_ovrd,i_branch,i_fromDay,i_fromMonth,i_fromYear)    'Branch open status override from date'
  i_branchOpenStatusOvrdToDate(i_ovrd,i_branch,i_toDay,i_toMonth,i_toYear)            'Branch open status override to date'
  i_branchOpenStatusOvrdTP(i_ovrd,i_branch,i_tradePeriod)                             'Branch open status override trade period'
* Branch security constraint overrides
  i_branchConstraintFactorOvrdFromDate(i_ovrd,i_branchConstraint,i_branch,i_fromDay,i_fromMonth,i_fromYear)        'Branch constraint factor override from date'
  i_branchConstraintFactorOvrdToDate(i_ovrd,i_branchConstraint,i_branch,i_toDay,i_toMonth,i_toYear)                'Branch constraint factor override to date'
  i_branchConstraintFactorOvrdTP(i_ovrd,i_branchConstraint,i_branch,i_tradePeriod)                                 'Branch constraint factor override trade period'
  i_branchConstraintRHSOvrdFromDate(i_ovrd,i_branchConstraint,i_fromDay,i_fromMonth,i_fromYear)                    'Branch constraint RHS override from date'
  i_branchConstraintRHSOvrdToDate(i_ovrd,i_branchConstraint,i_toDay,i_toMonth,i_toYear)                            'Branch constraint RHS override to date'
  i_branchConstraintRHSOvrdTP(i_ovrd,i_branchConstraint,i_tradePeriod)                                             'Branch constraint RHS override trade period'
* Market node constraint overrides
  i_MnodeEnergyConstraintFactorOvrdFromDate(i_ovrd,i_MnodeConstraint,i_offer,i_fromDay,i_fromMonth,i_fromYear)     'Market node energy constraint factor override from date'
  i_MnodeEnergyConstraintFactorOvrdToDate(i_ovrd,i_MnodeConstraint,i_offer,i_toDay,i_toMonth,i_toYear)             'Market node energy constraint factor override to date'
  i_MnodeEnergyConstraintFactorOvrdTP(i_ovrd,i_MnodeConstraint,i_offer,i_tradePeriod)                              'Market node energy constraint factor override trade period'
  i_MnodeReserveConstraintFactorOvrdFromDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear) 'Market node reserve constraint factor override from date'
  i_MnodeReserveConstraintFactorOvrdToDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass,i_toDay,i_toMonth,i_toYear) 'Market node reserve constraint factor override to date'
  i_MnodeReserveConstraintFactorOvrdTP(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass,i_tradePeriod)              'Market node reserve constraint factor override trade period'
  i_MnodeConstraintRHSOvrdFromDate(i_ovrd,i_MnodeConstraint,i_fromDay,i_fromMonth,i_fromYear)                      'Market node constraint RHS override from date'
  i_MnodeConstraintRHSOvrdToDate(i_ovrd,i_MnodeConstraint,i_toDay,i_toMonth,i_toYear)                              'Market node constraint RHS override to date'
  i_MnodeConstraintRHSOvrdTP(i_ovrd,i_MnodeConstraint,i_tradePeriod)                                               'Market node constraint RHS override trade period'
* Risk/Reserves
  i_contingentEventRAFOvrdFromDate(i_ovrd,i_island,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear)                'Contingency event RAF override from date'
  i_contingentEventRAFOvrdToDate(i_ovrd,i_island,i_reserveClass,i_toDay,i_toMonth,i_toYear)                        'Contingency event RAF override to date'
  i_contingentEventRAFOvrdTP(i_ovrd,i_island,i_reserveClass,i_tradePeriod)                                         'Contingency event RAF override trade period'
  i_extendedContingentEventRAFOvrdFromDate(i_ovrd,i_island,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear)        'Extended contingency event RAF override from date'
  i_extendedContingentEventRAFOvrdToDate(i_ovrd,i_island,i_reserveClass,i_toDay,i_toMonth,i_toYear)                'Extended contingency event RAF override to date'
  i_extendedContingentEventRAFOvrdTP(i_ovrd,i_island,i_reserveClass,i_tradePeriod)                                 'Extended contingency event RAF override trade period'
  i_contingentEventNFROvrdFromDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_fromDay,i_fromMonth,i_fromYear)    'Contingency event NFR override from date - Generator and Manual'
  i_contingentEventNFROvrdToDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_toDay,i_toMonth,i_toYear)            'Contingency event NFR override to date - Generator and Manual'
  i_contingentEventNFROvrdTP(i_ovrd,i_island,i_reserveClass,i_riskClass,i_tradePeriod)                             'Contingency event NFR override trade period - Generator and Manual'
  i_HVDCriskParamOvrdFromDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,i_fromDay,i_fromMonth,i_fromYear) 'HVDC risk parameter override from date'
  i_HVDCriskParamOvrdToDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,i_toDay,i_toMonth,i_toYear) 'HVDC risk parameter override to date'
  i_HVDCriskParamOvrdTP(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,i_tradePeriod)                  'HVDC risk parameter override trade period'
  ;

Parameters
* Offer overrides
  i_offerParamOvrd(i_ovrd,i_offer,i_offerParam)                                       'Offer parameter override values'
  i_energyOfferOvrd(i_ovrd,i_offer,i_tradeBlock,i_energyOfferComponent)               'Energy offer override values'
  i_PLSRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_PLSRofferComponent)    'PLSR offer override values'
  i_TWDRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_TWDRofferComponent)    'TWDR offer override values'
  i_ILRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_ILRofferComponent)      'ILR offer override values'
* Demand overrides
  i_islandPosMWDemandOvrd(i_ovrd,i_island)                                            'Island positive demand override MW values'
  i_islandPosPercDemandOvrd(i_ovrd,i_island)                                          'Island positive demand override % values'
  i_islandNegMWDemandOvrd(i_ovrd,i_island)                                            'Island negative demand override MW values'
  i_islandNegPercDemandOvrd(i_ovrd,i_island)                                          'Island negative demand override % values'
  i_islandNetMWDemandOvrd(i_ovrd,i_island)                                            'Island net demand override MW values'
  i_islandNetPercDemandOvrd(i_ovrd,i_island)                                          'Island net demand override % values'
  i_nodeMWDemandOvrd(i_ovrd,i_node)                                                   'Node demand override MW values'
  i_nodePercDemandOvrd(i_ovrd,i_node)                                                 'Node demand override % values'
* Branch parameter, capacity and status overrides
  i_branchParamOvrd(i_ovrd,i_branch,i_branchParameter)                                'Branch parameter override values'
  i_branchCapacityOvrd(i_ovrd,i_branch)                                               'Branch capacity override values'
  i_branchOpenStatusOvrd(i_ovrd,i_branch)                                             'Branch open status override values'
* Branch constraint factor overrides - factor and RHS
  i_branchConstraintFactorOvrd(i_ovrd,i_branchConstraint,i_branch)                    'Branch constraint factor override values'
  i_branchConstraintRHSOvrd(i_ovrd,i_branchConstraint,i_constraintRHS)                'Branch constraint RHS override values'
* Market node constraint overrides - factor and RHS
  i_MnodeEnergyConstraintFactorOvrd(i_ovrd,i_MnodeConstraint,i_offer)                 'Market node energy constraint factor override values'
  i_MnodeReserveConstraintFactorOvrd(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass) 'Market node reserve constraint factor override values'
  i_MnodeConstraintRHSOvrd(i_ovrd,i_MnodeConstraint,i_constraintRHS)                  'Market node constraint RHS override values'
* Risk/Reserve overrides
  i_contingentEventRAFOvrd(i_ovrd,i_island,i_reserveClass)                            'Contingency event RAF override'
  i_extendedContingentEventRAFOvrd(i_ovrd,i_island,i_reserveClass)                    'Extended contingency event RAF override'
  i_contingentEventNFROvrd(i_ovrd,i_island,i_reserveClass,i_riskClass)                'Contingency event NFR override - GENRISK and Manual'
  i_HVDCriskParamOvrd(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)     'HVDC risk parameter override'

* More offer overrides
  offerOvrdFromDay(i_ovrd,i_offer)                                                    'Offer override from day'
  offerOvrdFromMonth(i_ovrd,i_offer)                                                  'Offer override from month'
  offerOvrdFromYear(i_ovrd,i_offer)                                                   'Offer override from year'
  offerOvrdToDay(i_ovrd,i_offer)                                                      'Offer override to day'
  offerOvrdToMonth(i_ovrd,i_offer)                                                    'Offer override to month'
  offerOvrdToYear(i_ovrd,i_offer)                                                     'Offer override to year'
  offerOvrdFromGDate(i_ovrd,i_offer)                                                  'Offer override from date - Gregorian '
  offerOvrdToGDate(i_ovrd,i_offer)                                                    'Offer override to date - Gregorian '
  tradePeriodOfferParamOvrd(i_tradePeriod,i_offer,i_offerParam)                       'Offer parameter override for applicable trade periods'
  tradePeriodEnergyOfferOvrd(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent)            'Energy offer override for applicable trade periods'
  tradePeriodPLSRofferOvrd(i_tradePeriod,i_reserveClass,i_offer,i_tradeBlock,i_PLSRofferComponent) 'PLSR offer override for applicable trade periods'
  tradePeriodTWDRofferOvrd(i_tradePeriod,i_reserveClass,i_offer,i_tradeBlock,i_TWDRofferComponent) 'TWDR offer override for applicable trade periods'
  tradePeriodILRofferOvrd(i_tradePeriod,i_reserveClass,i_offer,i_tradeBlock,i_ILRofferComponent)   'ILR offer override for applicable trade periods'
* More demand overrides
  islandDemandOvrdFromDay(i_ovrd,i_island)                                            'Island demand override from day'
  islandDemandOvrdFromMonth(i_ovrd,i_island)                                          'Island demand override from month'
  islandDemandOvrdFromYear(i_ovrd,i_island)                                           'Island demand override from year'
  islandDemandOvrdToDay(i_ovrd,i_island)                                              'Island demand override to day'
  islandDemandOvrdToMonth(i_ovrd,i_island)                                            'Island demand override to month'
  islandDemandOvrdToYear(i_ovrd,i_island)                                             'Island demand override to year'
  islandDemandOvrdFromGDate(i_ovrd,i_island)                                          'Island demand override from date - Gregorian'
  islandDemandOvrdToGDate(i_ovrd,i_island)                                            'Island demand override to date - Gregorian'
  tradePeriodNodeDemandOrig(i_tradePeriod,i_node)                                     'Original node demand - MW'
  tradePeriodPosislandDemand(i_tradePeriod,i_island)                                  'Original positive island demand'
  tradePeriodNegislandDemand(i_tradePeriod,i_island)                                  'Original negative island demand'
  tradePeriodNetislandDemand(i_tradePeriod,i_island)                                  'Original net island demand'
  nodeDemandOvrdFromDay(i_ovrd,i_node)                                                'Node demand override from day'
  nodeDemandOvrdFromMonth(i_ovrd,i_node)                                              'Node demand override from month'
  nodeDemandOvrdFromYear(i_ovrd,i_node)                                               'Node demand override from year'
  nodeDemandOvrdToDay(i_ovrd,i_node)                                                  'Node demand override to day'
  nodeDemandOvrdToMonth(i_ovrd,i_node)                                                'Node demand override to month'
  nodeDemandOvrdToYear(i_ovrd,i_node)                                                 'Node demand override to year'
  nodeDemandOvrdFromGDate(i_ovrd,i_node)                                              'Node demand override from date - Gregorian'
  nodeDemandOvrdToGDate(i_ovrd,i_node)                                                'Node demand override to date - Gregorian'
  tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)                                     'Node demand override'
* More branch overrides
  branchOvrdFromDay(i_ovrd,i_branch)                                                  'Branch override from day'
  branchOvrdFromMonth(i_ovrd,i_branch)                                                'Branch override from month'
  branchOvrdFromYear(i_ovrd,i_branch)                                                 'Branch override from year'
  branchOvrdToDay(i_ovrd,i_branch)                                                    'Branch override to day'
  branchOvrdToMonth(i_ovrd,i_branch)                                                  'Branch override to month'
  branchOvrdToYear(i_ovrd,i_branch)                                                   'Branch override to year'
  branchOvrdFromGDate(i_ovrd,i_branch)                                                'Branch override from date - Gregorian'
  branchOvrdToGDate(i_ovrd,i_branch)                                                  'Branch override to date - Gregorian'
  tradePeriodBranchParamOvrd(i_tradePeriod,i_branch,i_branchParameter)                'Branch parameter override for applicable trade periods'
  tradePeriodBranchCapacityOvrd(i_tradePeriod,i_branch)                               'Branch capacity override for applicable trade periods'
  tradePeriodBranchOpenStatusOvrd(i_tradePeriod,i_branch)                             'Branch status override for applicable trade periods'
* More branch security constraint overrides - factor
  branchConstraintFactorOvrdFromDay(i_ovrd,i_branchConstraint,i_branch)               'Branch constraint factor override from day'
  branchConstraintFactorOvrdFromMonth(i_ovrd,i_branchConstraint,i_branch)             'Branch constraint factor override from month'
  branchConstraintFactorOvrdFromYear(i_ovrd,i_branchConstraint,i_branch)              'Branch constraint factor override from year'
  branchConstraintFactorOvrdToDay(i_ovrd,i_branchConstraint,i_branch)                 'Branch constraint factor override to day'
  branchConstraintFactorOvrdToMonth(i_ovrd,i_branchConstraint,i_branch)               'Branch constraint factor override to month'
  branchConstraintFactorOvrdToYear(i_ovrd,i_branchConstraint,i_branch)                'Branch constraint factor override to year'
  branchConstraintFactorOvrdFromGDate(i_ovrd,i_branchConstraint,i_branch)             'Branch constraint factor override from date - Gregorian'
  branchConstraintFactorOvrdToGDate(i_ovrd,i_branchConstraint,i_branch)               'Branch constraint factor override to date - Gregorian'
  tradePeriodBranchConstraintFactorOvrd(i_tradePeriod,i_branchConstraint,i_branch)    'Branch constraint factor override for applicable trade periods'
* More branch security constraint overrides - RHS
  branchConstraintRHSOvrdFromDay(i_ovrd,i_branchConstraint)                           'Branch constraint RHS override from day'
  branchConstraintRHSOvrdFromMonth(i_ovrd,i_branchConstraint)                         'Branch constraint RHS override from month'
  branchConstraintRHSOvrdFromYear(i_ovrd,i_branchConstraint)                          'Branch constraint RHS override from year'
  branchConstraintRHSOvrdToDay(i_ovrd,i_branchConstraint)                             'Branch constraint RHS override to day'
  branchConstraintRHSOvrdToMonth(i_ovrd,i_branchConstraint)                           'Branch constraint RHS override to month'
  branchConstraintRHSOvrdToYear(i_ovrd,i_branchConstraint)                            'Branch constraint RHS override to year'
  branchConstraintRHSOvrdFromGDate(i_ovrd,i_branchConstraint)                         'Branch constraint RHS override from date - Gregorian'
  branchConstraintRHSOvrdToGDate(i_ovrd,i_branchConstraint)                           'Branch constraint RHS override to date - Gregorian'
  tradePeriodBranchConstraintRHSOvrd(i_tradePeriod,i_branchConstraint,i_constraintRHS)'Branch constraint RHS override for applicable trade periods'
* More market node constraint overrides - energy factor
  MnodeEnergyConstraintFactorOvrdFromDay(i_ovrd,i_MnodeConstraint,i_offer)            'Market node energy constraint factor override from day'
  MnodeEnergyConstraintFactorOvrdFromMonth(i_ovrd,i_MnodeConstraint,i_offer)          'Market node energy constraint factor override from month'
  MnodeEnergyConstraintFactorOvrdFromYear(i_ovrd,i_MnodeConstraint,i_offer)           'Market node energy constraint factor override from year'
  MnodeEnergyConstraintFactorOvrdToDay(i_ovrd,i_MnodeConstraint,i_offer)              'Market node energy constraint factor override to day'
  MnodeEnergyConstraintFactorOvrdToMonth(i_ovrd,i_MnodeConstraint,i_offer)            'Market node energy constraint factor override to month'
  MnodeEnergyConstraintFactorOvrdToYear(i_ovrd,i_MnodeConstraint,i_offer)             'Market node energy constraint factor override to year'
  MnodeEnergyConstraintFactorOvrdFromGDate(i_ovrd,i_MnodeConstraint,i_offer)          'Market node energy constraint factor override from date - Gregorian'
  MnodeEnergyConstraintFactorOvrdToGDate(i_ovrd,i_MnodeConstraint,i_offer)            'Market node energy constraint factor override to date - Gregorian'
  tradePeriodMnodeEnergyConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer) 'Market node energy constraint factor override for applicable trade periods'
* More market node constraint overrides - reserve factor
  MnodeReserveConstraintFactorOvrdFromDay(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass)            'Market node reserve constraint factor override from day'
  MnodeReserveConstraintFactorOvrdFromMonth(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass)          'Market node reserve constraint factor override from month'
  MnodeReserveConstraintFactorOvrdFromYear(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass)           'Market node reserve constraint factor override from year'
  MnodeReserveConstraintFactorOvrdToDay(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass)              'Market node reserve constraint factor override to day'
  MnodeReserveConstraintFactorOvrdToMonth(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass)            'Market node reserve constraint factor override to month'
  MnodeReserveConstraintFactorOvrdToYear(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass)             'Market node reserve constraint factor override to year'
  MnodeReserveConstraintFactorOvrdFromGDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass)          'Market node reserve constraint factor override from date - Gregorian'
  MnodeReserveConstraintFactorOvrdToGDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass)            'Market node reserve constraint factor override to date - Gregorian'
  tradePeriodMnodeReserveConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer,i_reserveClass) 'Market node reserve constraint factor override for applicable trade periods'
* More market node constraint overrides - RHS
  MnodeConstraintRHSOvrdFromDay(i_ovrd,i_MnodeConstraint)                             'Market node constraint RHS override from day'
  MnodeConstraintRHSOvrdFromMonth(i_ovrd,i_MnodeConstraint)                           'Market node constraint RHS override from month'
  MnodeConstraintRHSOvrdFromYear(i_ovrd,i_MnodeConstraint)                            'Market node constraint RHS override from year'
  MnodeConstraintRHSOvrdToDay(i_ovrd,i_MnodeConstraint)                               'Market node constraint RHS override to day'
  MnodeConstraintRHSOvrdToMonth(i_ovrd,i_MnodeConstraint)                             'Market node constraint RHS override to month'
  MnodeConstraintRHSOvrdToYear(i_ovrd,i_MnodeConstraint)                              'Market node constraint RHS override to year'
  MnodeConstraintRHSOvrdFromGDate(i_ovrd,i_MnodeConstraint)                           'Market node constraint RHS override from date - Gregorian'
  MnodeConstraintRHSOvrdToGDate(i_ovrd,i_MnodeConstraint)                             'Market node constraint RHS override to date - Gregorian'
  tradePeriodMnodeConstraintRHSOvrd(i_tradePeriod,i_MnodeConstraint,i_constraintRHS)  'Market node constraint RHS override for applicable trade periods'
* More risk/reserve overrides
  RAFovrdDay(i_ovrd,i_island,i_reserveClass)                                          'RAF override from day'
  RAFovrdMonth(i_ovrd,i_island,i_reserveClass)                                        'RAF override from month'
  RAFovrdYear(i_ovrd,i_island,i_reserveClass)                                         'RAF override from year'
  CERAFovrdFromGDate(i_ovrd,i_island,i_reserveClass)                                  'Contingency event RAF override from date - Gregorian'
  CERAFovrdToGDate(i_ovrd,i_island,i_reserveClass)                                    'Contingency event RAF override to date - Gregorian'
  tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass)                         'Contingency event RAF override for applicable trade periods'
  ECERAFovrdFromGDate(i_ovrd,i_island,i_reserveClass)                                 'Extended contingency event RAF override from date - Gregorian'
  ECERAFovrdToGDate(i_ovrd,i_island,i_reserveClass)                                   'Extended contingency event RAF override to date - Gregorian'
  tradePeriodECERAFovrd(i_tradePeriod,i_island,i_reserveClass)                        'Extended contingency event RAF override for applicable trade periods'
  CENFRovrdDay(i_ovrd,i_island,i_reserveClass,i_riskClass)                            'Contingency event NFR override from day'
  CENFRovrdMonth(i_ovrd,i_island,i_reserveClass,i_riskClass)                          'Contingency event NFR override from month'
  CENFRovrdYear(i_ovrd,i_island,i_reserveClass,i_riskClass)                           'Contingency event NFR override from year'
  CENFRovrdFromGDate(i_ovrd,i_island,i_reserveClass,i_riskClass)                      'Contingency event NFR override from date - Gregorian'
  CENFRovrdToGDate(i_ovrd,i_island,i_reserveClass,i_riskClass)                        'Contingency event NFR override to date - Gregorian'
  tradePeriodCENFRovrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass)             'Contingency event NFR override for applicable trade periods'
  HVDCriskOvrdDay(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)         'HVDC risk parameter override from day'
  HVDCriskOvrdMonth(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)       'HVDC risk parameter override from month'
  HVDCriskOvrdYear(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)        'HVDC risk parameter override from year'
  HVDCriskOvrdFromGDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)   'HVDC risk parameter override from date - Gregorian'
  HVDCriskOvrdToGDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)     'HVDC risk parameter override to date - Gregorian'
  tradePeriodHVDCriskOvrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass,i_riskParameter) 'HVDC risk parameter override for applicable trade periods'
  ;

Scalar startYear 'Start year' / 1899 / ;

* EMI and Standalone interface - load/install override data
* Load override data from override GDX file. Note that all of these symbols must exist in the GDX file so as to intialise everything - even if they're empty.
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load i_offerParamOvrdFromDate i_offerParamOvrdToDate i_offerParamOvrdTP i_energyOfferOvrdFromDate i_energyOfferOvrdToDate
$load i_energyOfferOvrdTP i_PLSRofferOvrdFromDate i_PLSRofferOvrdToDate i_PLSRofferOvrdTP i_TWDRofferOvrdFromDate i_TWDRofferOvrdToDate i_TWDRofferOvrdTP i_ILRofferOvrdFromDate
$load i_ILRofferOvrdToDate i_ILRofferOvrdTP i_islandDemandOvrdFromDate i_islandDemandOvrdToDate i_islandDemandOvrdTP i_nodeDemandOvrdFromDate i_nodeDemandOvrdToDate
$load i_nodeDemandOvrdTP i_branchParamOvrdFromDate i_branchParamOvrdToDate i_branchParamOvrdTP i_branchCapacityOvrdFromDate i_branchCapacityOvrdToDate i_branchCapacityOvrdTP
$load i_branchOpenStatusOvrdFromDate i_branchOpenStatusOvrdToDate i_branchOpenStatusOvrdTP i_branchConstraintFactorOvrdFromDate i_branchConstraintFactorOvrdToDate
$load i_branchConstraintFactorOvrdTP i_branchConstraintRHSOvrdFromDate i_branchConstraintRHSOvrdToDate i_branchConstraintRHSOvrdTP i_MnodeEnergyConstraintFactorOvrdFromDate
$load i_MnodeEnergyConstraintFactorOvrdToDate i_MnodeEnergyConstraintFactorOvrdTP i_MnodeReserveConstraintFactorOvrdFromDate i_MnodeReserveConstraintFactorOvrdToDate
$load i_MnodeReserveConstraintFactorOvrdTP i_MnodeConstraintRHSOvrdFromDate i_MnodeConstraintRHSOvrdToDate i_MnodeConstraintRHSOvrdTP i_contingentEventRAFovrdFromDate
$load i_contingentEventRAFovrdToDate i_contingentEventRAFovrdTP i_extendedContingentEventRAFovrdFromDate i_extendedContingentEventRAFovrdToDate i_extendedContingentEventRAFovrdTP
$load i_contingentEventNFRovrdFromDate i_contingentEventNFRovrdToDate i_contingentEventNFRovrdTP i_HVDCriskParamOvrdFromDate i_HVDCriskParamOvrdToDate i_HVDCriskParamOvrdTP
$load i_offerParamOvrd i_energyOfferOvrd i_PLSRofferOvrd i_TWDRofferOvrd i_ILRofferOvrd i_islandPosMWDemandOvrd i_islandPosPercDemandOvrd i_islandNegMWDemandOvrd
$load i_islandNegPercDemandOvrd i_islandNetMWDemandOvrd i_islandNetPercDemandOvrd i_nodeMWDemandOvrd i_nodePercDemandOvrd i_branchParamOvrd i_branchCapacityOvrd
$load i_branchOpenStatusOvrd i_branchConstraintFactorOvrd i_branchConstraintRHSOvrd i_MnodeEnergyConstraintFactorOvrd i_MnodeReserveConstraintFactorOvrd i_MnodeConstraintRHSOvrd
$load i_contingentEventRAFovrd i_extendedContingentEventRAFovrd i_contingentEventNFRovrd i_HVDCriskParamOvrd
$gdxin

* Comment out the above $gdxin/$load statements and write some alternative statements to install override data from
* a source other than a GDX file when in standalone mode. But note that all declared override symbols must get initialised
* somehow, i.e. load empty from a GDX or explicitly assign them to be zero.

* EMI and Standalone interface - assign or initialise all of the override symbols - this goes on for many pages...

* +++ Start offer overrides +++
* Reset the offer override parameters
  option clear = offerOvrdFromDay ;         option clear = offerOvrdFromMonth ;      option clear = offerOvrdFromYear ;
  option clear = offerOvrdToDay ;           option clear = offerOvrdToMonth ;        option clear = offerOvrdToYear ;
  option clear = offerOvrdFromGDate ;       option clear = offerOvrdToGDate ;

* Calculate the from and to date for the offer parameter override
  offerOvrdFromDay(i_ovrd,i_offer)   = sum((i_fromDay,i_fromMonth,i_fromYear)$i_offerParamOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay) ) ;
  offerOvrdFromMonth(i_ovrd,i_offer) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_offerParamOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth) ) ;
  offerOvrdFromYear(i_ovrd,i_offer)  = sum((i_fromDay,i_fromMonth,i_fromYear)$i_offerParamOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear ) ;

  offerOvrdToDay(i_ovrd,i_offer)   = sum((i_toDay,i_toMonth,i_toYear)$i_offerParamOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toDay) ) ;
  offerOvrdToMonth(i_ovrd,i_offer) = sum((i_toDay,i_toMonth,i_toYear)$i_offerParamOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toMonth) ) ;
  offerOvrdToYear(i_ovrd,i_offer)  = sum((i_toDay,i_toMonth,i_toYear)$i_offerParamOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear ) ;

  offerOvrdFromGDate(i_ovrd,i_offer)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_offerParamOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), 1 ) =
    jdate( offerOvrdFromYear(i_ovrd,i_offer),offerOvrdFromMonth(i_ovrd,i_offer),offerOvrdFromDay(i_ovrd,i_offer) ) ;
  offerOvrdToGDate(i_ovrd,i_offer)$sum((i_toDay,i_toMonth,i_toYear)$i_offerParamOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), 1 ) =
    jdate( offerOvrdToYear(i_ovrd,i_offer),offerOvrdToMonth(i_ovrd,i_offer),offerOvrdToDay(i_ovrd,i_offer) ) ;

* Determine if all the conditions for the offer parameter override are satisfied
  loop((i_ovrd,i_tradePeriod,i_offer,i_offerParam)$( i_studyTradePeriod(i_tradePeriod) and ( offerOvrdFromGDate(i_ovrd,i_offer) <= inputGDXGDate ) and
                                                   ( offerOvrdToGDate(i_ovrd,i_offer) >= inputGDXGDate ) and i_offerParamOvrdTP(i_ovrd,i_offer,i_tradePeriod) and
                                                     i_offerParamOvrd(i_ovrd,i_offer,i_offerParam) ),
    if((i_offerParamOvrd(i_ovrd,i_offer,i_offerParam) > 0 ),
      tradePeriodOfferParamOvrd(i_tradePeriod,i_offer,i_offerParam) = i_offerParamOvrd(i_ovrd,i_offer,i_offerParam) ;
    elseif(i_offerParamOvrd(i_ovrd,i_offer,i_offerParam) = eps ),
      tradePeriodOfferParamOvrd(i_tradePeriod,i_offer,i_offerParam) = eps ;
    ) ;
  ) ;

* Apply offer parameter override
  i_tradePeriodOfferParameter(i_tradePeriod,i_offer,i_offerParam)$( tradePeriodOfferParamOvrd(i_tradePeriod,i_offer,i_offerParam) > 0 ) =
    tradePeriodOfferParamOvrd(i_tradePeriod,i_offer,i_offerParam) ;
  i_tradePeriodOfferParameter(i_tradePeriod,i_offer,i_offerParam)$( tradePeriodOfferParamOvrd(i_tradePeriod,i_offer,i_offerParam) and
                                                                  ( tradePeriodOfferParamOvrd(i_tradePeriod,i_offer,i_offerParam) = eps ) ) = 0 ;
  option clear = tradePeriodOfferParamOvrd ;

* Calculate the from and to date for the energy offer override
  option clear = offerOvrdFromDay ;         option clear = offerOvrdFromMonth ;      option clear = offerOvrdFromYear ;
  option clear = offerOvrdToDay ;           option clear = offerOvrdToMonth ;        option clear = offerOvrdToYear ;
  option clear = offerOvrdFromGDate ;       option clear = offerOvrdToGDate ;

  offerOvrdFromDay(i_ovrd,i_offer)   = sum((i_fromDay,i_fromMonth,i_fromYear)$i_energyOfferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay) ) ;
  offerOvrdFromMonth(i_ovrd,i_offer) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_energyOfferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth) ) ;
  offerOvrdFromYear(i_ovrd,i_offer)  = sum((i_fromDay,i_fromMonth,i_fromYear)$i_energyOfferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear ) ;

  offerOvrdToDay(i_ovrd,i_offer)   = sum((i_toDay,i_toMonth,i_toYear)$i_energyOfferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toDay) ) ;
  offerOvrdToMonth(i_ovrd,i_offer) = sum((i_toDay,i_toMonth,i_toYear)$i_energyOfferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toMonth) ) ;
  offerOvrdToYear(i_ovrd,i_offer)  = sum((i_toDay,i_toMonth,i_toYear)$i_energyOfferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear ) ;

  offerOvrdFromGDate(i_ovrd,i_offer)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_energyOfferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), 1 ) =
    jdate( offerOvrdFromYear(i_ovrd,i_offer),offerOvrdFromMonth(i_ovrd,i_offer),offerOvrdFromDay(i_ovrd,i_offer) ) ;
  offerOvrdToGDate(i_ovrd,i_offer)$sum((i_toDay,i_toMonth,i_toYear)$i_energyOfferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), 1 ) =
    jdate( offerOvrdToYear(i_ovrd,i_offer),offerOvrdToMonth(i_ovrd,i_offer),offerOvrdToDay(i_ovrd,i_offer) ) ;

* Determine if all the conditions for the energy offer override are satisfied
  loop((i_ovrd,i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent)$( i_studyTradePeriod(i_tradePeriod) and ( offerOvrdFromGDate(i_ovrd,i_offer) <= inputGDXGDate ) and
                                                                          ( offerOvrdToGDate(i_ovrd,i_offer) >= inputGDXGDate ) and i_energyOfferOvrdTP(i_ovrd,i_offer,i_tradePeriod) and
                                                                            i_energyOfferOvrd(i_ovrd,i_offer,i_tradeBlock,i_energyOfferComponent) ),
    if((i_energyOfferOvrd(i_ovrd,i_offer,i_tradeBlock,i_energyOfferComponent) > 0 ),
      tradePeriodEnergyOfferOvrd(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent) = i_energyOfferOvrd(i_ovrd,i_offer,i_tradeBlock,i_energyOfferComponent) ;
    elseif(i_energyOfferOvrd(i_ovrd,i_offer,i_tradeBlock,i_energyOfferComponent) = eps ),
      tradePeriodEnergyOfferOvrd(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent) = eps ;
    ) ;
  ) ;

* Apply energy offer override
  i_tradePeriodEnergyOffer(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent)$( tradePeriodEnergyOfferOvrd(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent) > 0 ) =
    tradePeriodEnergyOfferOvrd(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent) ;
  i_tradePeriodEnergyOffer(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent)$( tradePeriodEnergyOfferOvrd(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent) and
                                                                                        ( tradePeriodEnergyOfferOvrd(i_tradePeriod,i_offer,i_tradeBlock,i_energyOfferComponent) = eps ) ) = 0 ;
  option clear = tradePeriodEnergyOfferOvrd ;

* Calculate the from and to date for the PLSR offer override
  option clear = offerOvrdFromDay ;         option clear = offerOvrdFromMonth ;      option clear = offerOvrdFromYear ;
  option clear = offerOvrdToDay ;           option clear = offerOvrdToMonth ;        option clear = offerOvrdToYear ;
  option clear = offerOvrdFromGDate ;       option clear = offerOvrdToGDate ;

  offerOvrdFromDay(i_ovrd,i_offer)   = sum((i_fromDay,i_fromMonth,i_fromYear)$i_PLSRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay) ) ;
  offerOvrdFromMonth(i_ovrd,i_offer) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_PLSRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth) ) ;
  offerOvrdFromYear(i_ovrd,i_offer)  = sum((i_fromDay,i_fromMonth,i_fromYear)$i_PLSRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear ) ;

  offerOvrdToDay(i_ovrd,i_offer)   = sum((i_toDay,i_toMonth,i_toYear)$i_PLSRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toDay) ) ;
  offerOvrdToMonth(i_ovrd,i_offer) = sum((i_toDay,i_toMonth,i_toYear)$i_PLSRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toMonth) ) ;
  offerOvrdToYear(i_ovrd,i_offer)  = sum((i_toDay,i_toMonth,i_toYear)$i_PLSRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear ) ;

  offerOvrdFromGDate(i_ovrd,i_offer)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_PLSRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), 1 ) =
    jdate( offerOvrdFromYear(i_ovrd,i_offer),offerOvrdFromMonth(i_ovrd,i_offer),offerOvrdFromDay(i_ovrd,i_offer) ) ;
  offerOvrdToGDate(i_ovrd,i_offer)$sum((i_toDay,i_toMonth,i_toYear)$i_PLSRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), 1 ) =
    jdate( offerOvrdToYear(i_ovrd,i_offer),offerOvrdToMonth(i_ovrd,i_offer),offerOvrdToDay(i_ovrd,i_offer) ) ;

* Determine if all the conditions for the PLSR offer override are satisfied
  loop((i_ovrd,i_tradePeriod,i_reserveClass,i_offer,i_tradeBlock,i_PLSRofferComponent)$( i_studyTradePeriod(i_tradePeriod) and ( offerOvrdFromGDate(i_ovrd,i_offer) <= inputGDXGDate ) and
                                                                                       ( offerOvrdToGDate(i_ovrd,i_offer) >= inputGDXGDate ) and i_PLSRofferOvrdTP(i_ovrd,i_offer,i_tradePeriod) and
                                                                                         i_PLSRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_PLSRofferComponent) ),
    if((i_PLSRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_PLSRofferComponent) > 0 ),
      tradePeriodPLSRofferOvrd(i_tradePeriod,i_reserveClass,i_offer,i_tradeBlock,i_PLSRofferComponent) = i_PLSRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_PLSRofferComponent) ;
    elseif(i_PLSRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_PLSRofferComponent) = eps ),
      tradePeriodPLSRofferOvrd(i_tradePeriod,i_reserveClass,i_offer,i_tradeBlock,i_PLSRofferComponent) = eps ;
    ) ;
) ;

* Apply the PLSR offer override
  i_tradePeriodFastPLSRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_PLSRofferComponent)$( tradePeriodPLSRofferOvrd(i_tradePeriod,'FIR',i_offer,i_tradeBlock,i_PLSRofferComponent) > 0 ) =
    tradePeriodPLSRofferOvrd(i_tradePeriod,'FIR',i_offer,i_tradeBlock,i_PLSRofferComponent) ;
  i_tradePeriodFastPLSRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_PLSRofferComponent)$( tradePeriodPLSRofferOvrd(i_tradePeriod,'FIR',i_offer,i_tradeBlock,i_PLSRofferComponent) and
                                                                                      ( tradePeriodPLSRofferOvrd(i_tradePeriod,'FIR',i_offer,i_tradeBlock,i_PLSRofferComponent) = eps ) ) = 0 ;
  i_tradePeriodSustainedPLSRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_PLSRofferComponent)$( tradePeriodPLSRofferOvrd(i_tradePeriod,'SIR',i_offer,i_tradeBlock,i_PLSRofferComponent) > 0 ) =
    tradePeriodPLSRofferOvrd(i_tradePeriod,'SIR',i_offer,i_tradeBlock,i_PLSRofferComponent) ;
  i_tradePeriodSustainedPLSRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_PLSRofferComponent)$( tradePeriodPLSRofferOvrd(i_tradePeriod,'SIR',i_offer,i_tradeBlock,i_PLSRofferComponent) and
                                                                                           ( tradePeriodPLSRofferOvrd(i_tradePeriod,'SIR',i_offer,i_tradeBlock,i_PLSRofferComponent) = eps) ) = 0 ;
  option clear = TradePeriodPLSRofferOvrd ;

* Calculate the from and to date for the TWDR offer override
  option clear = offerOvrdFromDay ;         option clear = offerOvrdFromMonth ;      option clear = offerOvrdFromYear ;
  option clear = offerOvrdToDay ;           option clear = offerOvrdToMonth ;        option clear = offerOvrdToYear ;
  option clear = offerOvrdFromGDate ;       option clear = offerOvrdToGDate ;

  offerOvrdFromDay(i_ovrd,i_offer)   =  sum((i_fromDay,i_fromMonth,i_fromYear)$i_TWDRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay) ) ;
  offerOvrdFromMonth(i_ovrd,i_offer) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_TWDRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth) ) ;
  offerOvrdFromYear(i_ovrd,i_offer)  = sum((i_fromDay,i_fromMonth,i_fromYear)$i_TWDRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear ) ;

  offerOvrdToDay(i_ovrd,i_offer)   = sum((i_toDay,i_toMonth,i_toYear)$i_TWDRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toDay) ) ;
  offerOvrdToMonth(i_ovrd,i_offer) = sum((i_toDay,i_toMonth,i_toYear)$i_TWDRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toMonth) ) ;
  offerOvrdToYear(i_ovrd,i_offer)  = sum((i_toDay,i_toMonth,i_toYear)$i_TWDRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear ) ;

  offerOvrdFromGDate(i_ovrd,i_offer)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_TWDRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), 1 ) =
    jdate( offerOvrdFromYear(i_ovrd,i_offer),offerOvrdFromMonth(i_ovrd,i_offer),offerOvrdFromDay(i_ovrd,i_offer) ) ;
  offerOvrdToGDate(i_ovrd,i_offer)$sum((i_toDay,i_toMonth,i_toYear)$i_TWDRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), 1 ) =
    jdate( offerOvrdToYear(i_ovrd,i_offer),offerOvrdToMonth(i_ovrd,i_offer),offerOvrdToDay(i_ovrd,i_offer) ) ;

* Determine if all the conditions for the TWDR offer override are satisfied
  loop((i_ovrd,i_tradePeriod,i_reserveClass,i_offer,i_tradeBlock,i_TWDRofferComponent)$( i_studyTradePeriod(i_tradePeriod) and ( offerOvrdFromGDate(i_ovrd,i_offer) <= inputGDXGDate ) and
                                                                                       ( offerOvrdToGDate(i_ovrd,i_offer) >= inputGDXGDate ) and i_TWDRofferOvrdTP(i_ovrd,i_offer,i_tradePeriod) and
                                                                                         i_TWDRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_TWDRofferComponent) ),
    if((i_TWDRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_TWDRofferComponent) > 0 ),
      tradePeriodTWDRofferOvrd(i_tradePeriod,i_reserveClass,i_offer,i_tradeBlock,i_TWDRofferComponent) = i_TWDRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_TWDRofferComponent) ;
    elseif(i_TWDRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_TWDRofferComponent) = eps ),
      tradePeriodTWDRofferOvrd(i_tradePeriod,i_reserveClass,i_offer,i_tradeBlock,i_TWDRofferComponent) = eps ;
    ) ;
  ) ;

* Apply the TWDR offer override
  i_tradePeriodFastTWDRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_TWDRofferComponent)$( tradePeriodTWDRofferOvrd(i_tradePeriod,'FIR',i_offer,i_tradeBlock,i_TWDRofferComponent) > 0 ) =
    tradePeriodTWDRofferOvrd(i_tradePeriod,'FIR',i_offer,i_tradeBlock,i_TWDRofferComponent) ;
  i_tradePeriodFastTWDRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_TWDRofferComponent)$( tradePeriodTWDRofferOvrd(i_tradePeriod,'FIR',i_offer,i_tradeBlock,i_TWDRofferComponent) and
                                                                                      ( tradePeriodTWDRofferOvrd(i_tradePeriod,'FIR',i_offer,i_tradeBlock,i_TWDRofferComponent) = eps ) ) = 0 ;
  i_tradePeriodSustainedTWDRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_TWDRofferComponent)$( tradePeriodTWDRofferOvrd(i_tradePeriod,'SIR',i_offer,i_tradeBlock,i_TWDRofferComponent) > 0 ) =
    tradePeriodTWDRofferOvrd(i_tradePeriod,'SIR',i_offer,i_tradeBlock,i_TWDRofferComponent) ;
  i_tradePeriodSustainedTWDRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_TWDRofferComponent)$( tradePeriodTWDRofferOvrd(i_tradePeriod,'SIR',i_offer,i_tradeBlock,i_TWDRofferComponent) and
                                                                                           ( tradePeriodTWDRofferOvrd(i_tradePeriod,'SIR',i_offer,i_tradeBlock,i_TWDRofferComponent) = eps ) ) = 0 ;
  option clear = tradePeriodTWDRofferOvrd ;

* Calculate the from and to date for the ILR offer override
  option clear = offerOvrdFromDay ;         option clear = offerOvrdFromMonth ;      option clear = offerOvrdFromYear ;
  option clear = offerOvrdToDay ;           option clear = offerOvrdToMonth ;        option clear = offerOvrdToYear ;
  option clear = offerOvrdFromGDate ;       option clear = offerOvrdToGDate ;

  offerOvrdFromDay(i_ovrd,i_offer)   = sum((i_fromDay,i_fromMonth,i_fromYear)$i_ILRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay) ) ;
  offerOvrdFromMonth(i_ovrd,i_offer) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_ILRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth) ) ;
  offerOvrdFromYear(i_ovrd,i_offer)  = sum((i_fromDay,i_fromMonth,i_fromYear)$i_ILRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear ) ;

  offerOvrdToDay(i_ovrd,i_offer)   = sum((i_toDay,i_toMonth,i_toYear)$i_ILRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toDay) ) ;
  offerOvrdToMonth(i_ovrd,i_offer) = sum((i_toDay,i_toMonth,i_toYear)$i_ILRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toMonth) ) ;
  offerOvrdToYear(i_ovrd,i_offer)  = sum((i_toDay,i_toMonth,i_toYear)$i_ILRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear ) ;

  offerOvrdFromGDate(i_ovrd,i_offer)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_ILRofferOvrdFromDate(i_ovrd,i_offer,i_fromDay,i_fromMonth,i_fromYear), 1) =
    jdate( offerOvrdFromYear(i_ovrd,i_offer),offerOvrdFromMonth(i_ovrd,i_offer),offerOvrdFromDay(i_ovrd,i_offer) ) ;
  offerOvrdToGDate(i_ovrd,i_offer)$sum((i_toDay,i_toMonth,i_toYear)$i_ILRofferOvrdToDate(i_ovrd,i_offer,i_toDay,i_toMonth,i_toYear), 1) =
    jdate( offerOvrdToYear(i_ovrd,i_offer),offerOvrdToMonth(i_ovrd,i_offer),offerOvrdToDay(i_ovrd,i_offer) ) ;

* Determine if all the conditions for the ILR offer override are satisfied
  loop((i_ovrd,i_tradePeriod,i_reserveClass,i_offer,i_tradeBlock,i_ILRofferComponent)$( i_studyTradePeriod(i_tradePeriod) and ( offerOvrdFromGDate(i_ovrd,i_offer) <= inputGDXGDate ) and
                                                                                      ( offerOvrdToGDate(i_ovrd,i_offer) >= inputGDXGDate ) and i_ILRofferOvrdTP(i_ovrd,i_offer,i_tradePeriod) and
                                                                                        i_ILRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_ILRofferComponent) ),
    if((i_ILRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_ILRofferComponent) > 0 ),
      tradePeriodILRofferOvrd(i_tradePeriod,i_reserveClass,i_offer,i_tradeBlock,i_ILRofferComponent) = i_ILRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_ILRofferComponent) ;
    elseif(i_ILRofferOvrd(i_ovrd,i_reserveClass,i_offer,i_tradeBlock,i_ILRofferComponent) = eps ),
      tradePeriodILRofferOvrd(i_tradePeriod,i_reserveClass,i_offer,i_tradeBlock,i_ILRofferComponent) = eps ;
    ) ;
) ;

* Apply the ILR offer override
  i_tradePeriodFastILRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_ILRofferComponent)$( tradePeriodILRofferOvrd(i_tradePeriod,'FIR',i_offer,i_tradeBlock,i_ILRofferComponent) > 0 ) =
    tradePeriodILRofferOvrd(i_tradePeriod,'FIR',i_offer,i_tradeBlock,i_ILRofferComponent) ;
  i_tradePeriodFastILRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_ILRofferComponent)$( tradePeriodILRofferOvrd(i_tradePeriod,'FIR',i_offer,i_tradeBlock,i_ILRofferComponent ) and
                                                                                    ( tradePeriodILRofferOvrd(i_tradePeriod,'FIR',i_offer,i_tradeBlock,i_ILRofferComponent) = eps ) ) = 0 ;
  i_tradePeriodSustainedILRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_ILRofferComponent)$( tradePeriodILRofferOvrd(i_tradePeriod,'SIR',i_offer,i_tradeBlock,i_ILRofferComponent) > 0 ) =
    tradePeriodILRofferOvrd(i_tradePeriod,'SIR',i_offer,i_tradeBlock,i_ILRofferComponent) ;
  i_tradePeriodSustainedILRoffer(i_tradePeriod,i_offer,i_tradeBlock,i_ILRofferComponent)$( tradePeriodILRofferOvrd(i_tradePeriod,'SIR',i_offer,i_tradeBlock,i_ILRofferComponent) and
                                                                                         ( tradePeriodILRofferOvrd(i_tradePeriod,'SIR',i_offer,i_tradeBlock,i_ILRofferComponent) = eps ) ) = 0 ;
  option clear = tradePeriodILRofferOvrd ;

* Reset the offer override parameters
  option clear = offerOvrdFromDay ;         option clear = offerOvrdFromMonth ;      option clear = offerOvrdFromYear ;
  option clear = offerOvrdToDay ;           option clear = offerOvrdToMonth ;        option clear = offerOvrdToYear ;
  option clear = offerOvrdFromGDate ;       option clear = offerOvrdToGDate ;

*+++ End offer override +++

*+++ Start demand override +++

* Calculate the from and to date for the island demand override
  option clear = islandDemandOvrdFromDay ;          option clear = islandDemandOvrdFromMonth ;       option clear = islandDemandOvrdFromYear ;
  option clear = islandDemandOvrdToDay ;            option clear = islandDemandOvrdToMonth ;         option clear = islandDemandOvrdToYear ;
  option clear = islandDemandOvrdFromGDate ;        option clear = islandDemandOvrdToGDate ;

  islandDemandOvrdFromDay(i_ovrd,i_island)   = sum((i_fromDay,i_fromMonth,i_fromYear)$i_islandDemandOvrdFromDate(i_ovrd,i_island,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay) ) ;
  islandDemandOvrdFromMonth(i_ovrd,i_island) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_islandDemandOvrdFromDate(i_ovrd,i_island,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth) ) ;
  islandDemandOvrdFromYear(i_ovrd,i_island)  = sum((i_fromDay,i_fromMonth,i_fromYear)$i_islandDemandOvrdFromDate(i_ovrd,i_island,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear ) ;

  islandDemandOvrdToDay(i_ovrd,i_island)   = sum((i_toDay,i_toMonth,i_toYear)$i_islandDemandOvrdToDate(i_ovrd,i_island,i_toDay,i_toMonth,i_toYear), ord(i_toDay) ) ;
  islandDemandOvrdToMonth(i_ovrd,i_island) = sum((i_toDay,i_toMonth,i_toYear)$i_islandDemandOvrdToDate(i_ovrd,i_island,i_toDay,i_toMonth,i_toYear), ord(i_toMonth) ) ;
  islandDemandOvrdToYear(i_ovrd,i_island)  = sum((i_toDay,i_toMonth,i_toYear)$i_islandDemandOvrdToDate(i_ovrd,i_island,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear ) ;

  islandDemandOvrdFromGDate(i_ovrd,i_island)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_islandDemandOvrdFromDate(i_ovrd,i_island,i_fromDay,i_fromMonth,i_fromYear), 1 ) =
    jdate( islandDemandOvrdFromYear(i_ovrd,i_island),islandDemandOvrdFromMonth(i_ovrd,i_island),islandDemandOvrdFromDay(i_ovrd,i_island) ) ;
  islandDemandOvrdToGDate(i_ovrd,i_island)$sum((i_toDay,i_toMonth,i_toYear)$i_islandDemandOvrdToDate(i_ovrd,i_island,i_toDay,i_toMonth,i_toYear), 1) =
    jdate(islandDemandOvrdToYear(i_ovrd,i_island),islandDemandOvrdToMonth(i_ovrd,i_island),islandDemandOvrdToDay(i_ovrd,i_island) ) ;

* Island demand override pre-processing
  tradePeriodNodeDemandOrig(i_tradePeriod,i_node) = 0 ;
  tradePeriodNodeDemandOrig(i_tradePeriod,i_node) = i_tradePeriodNodeDemand(i_tradePeriod,i_node) ;
  tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island)$sum(i_Bus$(i_tradePeriodNodeBus(i_tradePeriod,i_node,i_Bus) and i_tradePeriodBusIsland(i_tradePeriod,i_Bus,i_island)), 1 ) = yes ;

  tradePeriodPosIslandDemand(i_tradePeriod,i_island) = sum(i_node$( tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island) and
                                                                  ( tradePeriodNodeDemandOrig(i_tradePeriod,i_node) > 0 ) ), tradePeriodNodeDemandOrig(i_tradePeriod,i_node) ) ;
  tradePeriodNegIslandDemand(i_tradePeriod,i_island) = sum(i_node$( tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island) and
                                                                  ( tradePeriodNodeDemandOrig(i_tradePeriod,i_node) < 0 ) ), tradePeriodNodeDemandOrig(i_tradePeriod,i_node) ) ;
  tradePeriodNetIslandDemand(i_tradePeriod,i_island) = sum(i_node$tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island), tradePeriodNodeDemandOrig(i_tradePeriod,i_node) ) ;

* Apply the demand overrides
  loop((i_ovrd,i_island)$( ( islandDemandOvrdFromGDate(i_ovrd,i_island) <= inputGDXGDate ) and ( islandDemandOvrdToGDate(i_ovrd,i_island) >= inputGDXGDate ) ),
* Percentage override to positive loads
    if((i_islandPosPercDemandOvrd(i_ovrd,i_island) and ( i_islandPosPercDemandOvrd(i_ovrd,i_island) <> 0) ),
      tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$( ( tradePeriodNodeDemandOrig(i_tradePeriod,i_node) > 0 ) and
                                                          i_islandDemandOvrdTP(i_ovrd,i_island,i_tradePeriod) and tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island) )
        =  ( 1+ ( i_islandPosPercDemandOvrd(i_ovrd,i_island) / 100 ) ) * tradePeriodNodeDemandOrig(i_tradePeriod,i_node) ;
    elseif(i_islandPosPercDemandOvrd(i_ovrd,i_island) and ( i_islandPosPercDemandOvrd(i_ovrd,i_island) = eps ) ),
      tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$( ( tradePeriodNodeDemandOrig(i_tradePeriod,i_node) > 0 ) and
                                                          i_islandDemandOvrdTP(i_ovrd,i_island,i_tradePeriod ) and tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island) )
        = tradePeriodNodeDemandOrig(i_tradePeriod,i_node) ;
    ) ;

* Percentage override to negative loads
    if ((i_islandNegPercDemandOvrd(i_ovrd,i_island) and (i_islandNegPercDemandOvrd(i_ovrd,i_island) <> 0)),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$((tradePeriodNodeDemandOrig(i_tradePeriod,i_node) < 0) and i_islandDemandOvrdTP(i_ovrd,i_island,i_tradePeriod) and tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island))
          =  (1+(i_islandNegPercDemandOvrd(i_ovrd,i_island)/100)) * tradePeriodNodeDemandOrig(i_tradePeriod,i_node) ;
    elseif (i_islandNegPercDemandOvrd(i_ovrd,i_island) and (i_islandNegPercDemandOvrd(i_ovrd,i_island) = eps)),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$((tradePeriodNodeDemandOrig(i_tradePeriod,i_node) < 0) and i_islandDemandOvrdTP(i_ovrd,i_island,i_tradePeriod) and tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island))
          = tradePeriodNodeDemandOrig(i_tradePeriod,i_node) ;
    ) ;

* Percentage override to net loads
    if ((i_islandNetPercDemandOvrd(i_ovrd,i_island) and (i_islandNetPercDemandOvrd(i_ovrd,i_island) <> 0)),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$(i_islandDemandOvrdTP(i_ovrd,i_island,i_tradePeriod) and tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island))
          =  (1+(i_islandNetPercDemandOvrd(i_ovrd,i_island)/100)) * tradePeriodNodeDemandOrig(i_tradePeriod,i_node) ;
    elseif (i_islandNetPercDemandOvrd(i_ovrd,i_island) and (i_islandNetPercDemandOvrd(i_ovrd,i_island) = eps)),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$(i_islandDemandOvrdTP(i_ovrd,i_island,i_tradePeriod) and tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island))
          = tradePeriodNodeDemandOrig(i_tradePeriod,i_node) ;
    ) ;

* MW override to positive island loads
    if ((i_islandPosMWDemandOvrd(i_ovrd,i_island) and (i_islandPosMWDemandOvrd(i_ovrd,i_island) <> 0)),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$((tradePeriodPosislandDemand(i_tradePeriod,i_island) > 0) and (tradePeriodNodeDemandOrig(i_tradePeriod,i_node) > 0) and i_islandDemandOvrdTP(i_ovrd,i_island,i_tradePeriod) and tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island))
          =  i_islandPosMWDemandOvrd(i_ovrd,i_island) * (tradePeriodNodeDemandOrig(i_tradePeriod,i_node)/TradePeriodPosislandDemand(i_tradePeriod,i_island)) ;
    elseif (i_islandPosMWDemandOvrd(i_ovrd,i_island) and (i_islandPosMWDemandOvrd(i_ovrd,i_island) = eps)),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$((tradePeriodNodeDemandOrig(i_tradePeriod,i_node) > 0) and i_islandDemandOvrdTP(i_ovrd,i_island,i_tradePeriod) and tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island))
          = eps ;
    ) ;

* MW override to negative island loads
    if ((i_islandNegMWDemandOvrd(i_ovrd,i_island) and (i_islandNegMWDemandOvrd(i_ovrd,i_island) <> 0)),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$((tradePeriodNegislandDemand(i_tradePeriod,i_island) < 0) and (tradePeriodNodeDemandOrig(i_tradePeriod,i_node) < 0) and i_islandDemandOvrdTP(i_ovrd,i_island,i_tradePeriod) and tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island))
          =  i_islandNegMWDemandOvrd(i_ovrd,i_island) * (tradePeriodNodeDemandOrig(i_tradePeriod,i_node)/TradePeriodNegislandDemand(i_tradePeriod,i_island)) ;
    elseif (i_islandNegMWDemandOvrd(i_ovrd,i_island) and (i_islandNegMWDemandOvrd(i_ovrd,i_island) = eps)),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$((tradePeriodNodeDemandOrig(i_tradePeriod,i_node) < 0) and i_islandDemandOvrdTP(i_ovrd,i_island,i_tradePeriod) and tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island))
          = eps ;
    ) ;

* MW override to net island loads
    if ((i_islandNetMWDemandOvrd(i_ovrd,i_island) and (i_islandNetMWDemandOvrd(i_ovrd,i_island) <> 0)),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$((tradePeriodNetislandDemand(i_tradePeriod,i_island) <> 0) and (tradePeriodNodeDemandOrig(i_tradePeriod,i_node) <> 0) and i_islandDemandOvrdTP(i_ovrd,i_island,i_tradePeriod) and tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island))
          =  i_islandNetMWDemandOvrd(i_ovrd,i_island) * (tradePeriodNodeDemandOrig(i_tradePeriod,i_node)/TradePeriodNetislandDemand(i_tradePeriod,i_island)) ;
    elseif (i_islandNetMWDemandOvrd(i_ovrd,i_island) and (i_islandNetMWDemandOvrd(i_ovrd,i_island) = eps)),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$(i_islandDemandOvrdTP(i_ovrd,i_island,i_tradePeriod) and tradePeriodNodeIslandTemp(i_tradePeriod,i_node,i_island))
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

NodeDemandOvrdFromDay(i_ovrd,i_node) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_nodeDemandOvrdFromDate(i_ovrd,i_node,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay)) ;
NodeDemandOvrdFromMonth(i_ovrd,i_node) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_nodeDemandOvrdFromDate(i_ovrd,i_node,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth)) ;
NodeDemandOvrdFromYear(i_ovrd,i_node) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_nodeDemandOvrdFromDate(i_ovrd,i_node,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear) ;

NodeDemandOvrdToDay(i_ovrd,i_node) = sum((i_toDay,i_toMonth,i_toYear)$i_nodeDemandOvrdToDate(i_ovrd,i_node,i_toDay,i_toMonth,i_toYear), ord(i_toDay)) ;
NodeDemandOvrdToMonth(i_ovrd,i_node) = sum((i_toDay,i_toMonth,i_toYear)$i_nodeDemandOvrdToDate(i_ovrd,i_node,i_toDay,i_toMonth,i_toYear), ord(i_toMonth)) ;
NodeDemandOvrdToYear(i_ovrd,i_node) = sum((i_toDay,i_toMonth,i_toYear)$i_nodeDemandOvrdToDate(i_ovrd,i_node,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear) ;

NodeDemandOvrdFromGDate(i_ovrd,i_node)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_nodeDemandOvrdFromDate(i_ovrd,i_node,i_fromDay,i_fromMonth,i_fromYear), 1) = jdate(NodeDemandOvrdFromYear(i_ovrd,i_node), nodeDemandOvrdFromMonth(i_ovrd,i_node), nodeDemandOvrdFromDay(i_ovrd,i_node)) ;
NodeDemandOvrdToGDate(i_ovrd,i_node)$sum((i_toDay,i_toMonth,i_toYear)$i_nodeDemandOvrdToDate(i_ovrd,i_node,i_toDay,i_toMonth,i_toYear), 1) = jdate(NodeDemandOvrdToYear(i_ovrd,i_node), nodeDemandOvrdToMonth(i_ovrd,i_node), nodeDemandOvrdToDay(i_ovrd,i_node)) ;

* Apply the node demand overrides
loop((i_ovrd,i_node)$((NodeDemandOvrdFromGDate(i_ovrd,i_node) <= inputGDXGDate) and (NodeDemandOvrdToGDate(i_ovrd,i_node) >= inputGDXGDate) and (i_nodeMWDemandOvrd(i_ovrd,i_node) or i_nodePercDemandOvrd(i_ovrd,i_node))),

* MW override to node loads
    if (((i_nodeMWDemandOvrd(i_ovrd,i_node) > 0) or (i_nodeMWDemandOvrd(i_ovrd,i_node) < 0)),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$i_nodeDemandOvrdTP(i_ovrd,i_node,i_tradePeriod) =  i_nodeMWDemandOvrd(i_ovrd,i_node) ;
    elseif (i_nodeMWDemandOvrd(i_ovrd,i_node) = eps),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$i_nodeDemandOvrdTP(i_ovrd,i_node,i_tradePeriod) = eps ;
    ) ;

* Percentage override to node loads
    if (((i_nodePercDemandOvrd(i_ovrd,i_node) > 0) or (i_nodePercDemandOvrd(i_ovrd,i_node) < 0)),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$i_nodeDemandOvrdTP(i_ovrd,i_node,i_tradePeriod) =  (1+(i_nodePercDemandOvrd(i_ovrd,i_node)/100)) * tradePeriodNodeDemandOrig(i_tradePeriod,i_node) ;
    elseif (i_nodeMWDemandOvrd(i_ovrd,i_node) = eps),
       tradePeriodNodeDemandOvrd(i_tradePeriod,i_node)$i_nodeDemandOvrdTP(i_ovrd,i_node,i_tradePeriod) = eps ;
    ) ;
) ;

* Calculate the from and to date for the node demand override
  option clear = nodeDemandOvrdFromDay ;            option clear = nodeDemandOvrdFromMonth ;         option clear = nodeDemandOvrdFromYear ;
  option clear = nodeDemandOvrdToDay ;              option clear = nodeDemandOvrdToMonth ;           option clear = nodeDemandOvrdToYear ;
  option clear = nodeDemandOvrdFromGDate ;          option clear = nodeDemandOvrdToGDate ;

* Apply the demand override
i_tradePeriodNodeDemand(i_tradePeriod,i_node)$TradePeriodNodeDemandOvrd(i_tradePeriod,i_node) = tradePeriodNodeDemandOvrd(i_tradePeriod,i_node) ;
i_tradePeriodNodeDemand(i_tradePeriod,i_node)$(tradePeriodNodeDemandOvrd(i_tradePeriod,i_node) and (tradePeriodNodeDemandOvrd(i_tradePeriod,i_node) = eps)) = 0 ;
  option clear = tradePeriodNodeDemandOvrd ;        option clear = tradePeriodNodeDemandOrig ;       option clear = tradePeriodNodeIslandTemp ;
  option clear = tradePeriodPosislandDemand ;       option clear = tradePeriodNegislandDemand ;      option clear = tradePeriodNetislandDemand ;

*+++ End demand override +++

*+++ Start branch override +++

* Reset the branch override parameters
  option clear = BranchOvrdFromDay ;                option clear = BranchOvrdFromMonth ;             option clear = BranchOvrdFromYear ;
  option clear = BranchOvrdToDay ;                  option clear = BranchOvrdToMonth ;               option clear = BranchOvrdToYear ;
  option clear = BranchOvrdFromGDate ;              option clear = BranchOvrdToGDate ;

* Calculate the from and to date for the branch parameter override
BranchOvrdFromDay(i_ovrd,i_Branch) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchParamOvrdFromDate(i_ovrd,i_Branch,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay)) ;
BranchOvrdFromMonth(i_ovrd,i_Branch) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchParamOvrdFromDate(i_ovrd,i_Branch,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth)) ;
BranchOvrdFromYear(i_ovrd,i_Branch) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchParamOvrdFromDate(i_ovrd,i_Branch,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear) ;

BranchOvrdToDay(i_ovrd,i_Branch) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchParamOvrdToDate(i_ovrd,i_Branch,i_toDay,i_toMonth,i_toYear), ord(i_toDay)) ;
BranchOvrdToMonth(i_ovrd,i_Branch) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchParamOvrdToDate(i_ovrd,i_Branch,i_toDay,i_toMonth,i_toYear), ord(i_toMonth)) ;
BranchOvrdToYear(i_ovrd,i_Branch) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchParamOvrdToDate(i_ovrd,i_Branch,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear) ;

BranchOvrdFromGDate(i_ovrd,i_Branch)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchParamOvrdFromDate(i_ovrd,i_Branch,i_fromDay,i_fromMonth,i_fromYear), 1) = jdate(BranchOvrdFromYear(i_ovrd,i_Branch), BranchOvrdFromMonth(i_ovrd,i_Branch), BranchOvrdFromDay(i_ovrd,i_Branch)) ;
BranchOvrdToGDate(i_ovrd,i_Branch)$sum((i_toDay,i_toMonth,i_toYear)$i_BranchParamOvrdToDate(i_ovrd,i_Branch,i_toDay,i_toMonth,i_toYear), 1) = jdate(BranchOvrdToYear(i_ovrd,i_Branch), BranchOvrdToMonth(i_ovrd,i_Branch), BranchOvrdToDay(i_ovrd,i_Branch)) ;

* Determine if all the conditions for the branch parameter override are satisfied
loop((i_ovrd,i_tradePeriod,i_Branch,i_BranchParameter)$(i_studyTradePeriod(i_tradePeriod) and (BranchOvrdFromGDate(i_ovrd,i_Branch) <= inputGDXGDate) and (BranchOvrdToGDate(i_ovrd,i_Branch) >= inputGDXGDate) and i_BranchParamOvrdTP(i_ovrd,i_Branch,i_tradePeriod) and i_BranchParamOvrd(i_ovrd,i_Branch,i_BranchParameter)),
    if ((i_BranchParamOvrd(i_ovrd,i_Branch,i_BranchParameter) <> 0),
      tradePeriodBranchParamOvrd(i_tradePeriod,i_Branch,i_BranchParameter) = i_BranchParamOvrd(i_ovrd,i_Branch,i_BranchParameter) ;
    elseif (i_BranchParamOvrd(i_ovrd,i_Branch,i_BranchParameter) = eps),
      tradePeriodBranchParamOvrd(i_tradePeriod,i_Branch,i_BranchParameter) = eps ;
    ) ;
) ;

* Reset the branch override parameters
  option clear = BranchOvrdFromDay ;                option clear = BranchOvrdFromMonth ;             option clear = BranchOvrdFromYear ;
  option clear = BranchOvrdToDay ;                  option clear = BranchOvrdToMonth ;               option clear = BranchOvrdToYear ;
  option clear = BranchOvrdFromGDate ;              option clear = BranchOvrdToGDate ;

* Apply the branch parameter override
i_tradePeriodBranchParameter(i_tradePeriod,i_Branch,i_BranchParameter)$ (tradePeriodBranchParamOvrd(i_tradePeriod,i_Branch,i_BranchParameter) <> 0) = tradePeriodBranchParamOvrd(i_tradePeriod,i_Branch,i_BranchParameter) ;
i_tradePeriodBranchParameter(i_tradePeriod,i_Branch,i_BranchParameter)$(tradePeriodBranchParamOvrd(i_tradePeriod,i_Branch,i_BranchParameter) and (tradePeriodBranchParamOvrd(i_tradePeriod,i_Branch,i_BranchParameter) = eps)) = 0 ;
  option clear = tradePeriodBranchParamOvrd ;

* Calculate the from and to date for the branch capacity override
BranchOvrdFromDay(i_ovrd,i_Branch) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchCapacityOvrdFromDate(i_ovrd,i_Branch,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay)) ;
BranchOvrdFromMonth(i_ovrd,i_Branch) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchCapacityOvrdFromDate(i_ovrd,i_Branch,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth)) ;
BranchOvrdFromYear(i_ovrd,i_Branch) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchCapacityOvrdFromDate(i_ovrd,i_Branch,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear) ;

BranchOvrdToDay(i_ovrd,i_Branch) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchCapacityOvrdToDate(i_ovrd,i_Branch,i_toDay,i_toMonth,i_toYear), ord(i_toDay)) ;
BranchOvrdToMonth(i_ovrd,i_Branch) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchCapacityOvrdToDate(i_ovrd,i_Branch,i_toDay,i_toMonth,i_toYear), ord(i_toMonth)) ;
BranchOvrdToYear(i_ovrd,i_Branch) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchCapacityOvrdToDate(i_ovrd,i_Branch,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear) ;

BranchOvrdFromGDate(i_ovrd,i_Branch)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchCapacityOvrdFromDate(i_ovrd,i_Branch,i_fromDay,i_fromMonth,i_fromYear), 1) = jdate(BranchOvrdFromYear(i_ovrd,i_Branch), BranchOvrdFromMonth(i_ovrd,i_Branch), BranchOvrdFromDay(i_ovrd,i_Branch)) ;
BranchOvrdToGDate(i_ovrd,i_Branch)$sum((i_toDay,i_toMonth,i_toYear)$i_BranchCapacityOvrdToDate(i_ovrd,i_Branch,i_toDay,i_toMonth,i_toYear), 1) = jdate(BranchOvrdToYear(i_ovrd,i_Branch), BranchOvrdToMonth(i_ovrd,i_Branch), BranchOvrdToDay(i_ovrd,i_Branch)) ;

* Determine if all the conditions for the branch capacity are satisfied
loop((i_ovrd,i_tradePeriod,i_Branch)$(i_studyTradePeriod(i_tradePeriod) and (BranchOvrdFromGDate(i_ovrd,i_Branch) <= inputGDXGDate) and (BranchOvrdToGDate(i_ovrd,i_Branch) >= inputGDXGDate) and i_BranchCapacityOvrdTP(i_ovrd,i_Branch,i_tradePeriod) and i_BranchCapacityOvrd(i_ovrd,i_Branch)),
    if ((i_BranchCapacityOvrd(i_ovrd,i_Branch) > 0),
      tradePeriodBranchCapacityOvrd(i_tradePeriod,i_Branch) = i_BranchCapacityOvrd(i_ovrd,i_Branch) ;
    elseif (i_BranchCapacityOvrd(i_ovrd,i_Branch) = eps),
      tradePeriodBranchCapacityOvrd(i_tradePeriod,i_Branch) = eps ;
    ) ;
) ;

* Reset the branch override parameters
  option clear = BranchOvrdFromDay ;                option clear = BranchOvrdFromMonth ;             option clear = BranchOvrdFromYear ;
  option clear = BranchOvrdToDay ;                  option clear = BranchOvrdToMonth ;               option clear = BranchOvrdToYear ;
  option clear = BranchOvrdFromGDate ;              option clear = BranchOvrdToGDate ;

* Apply the branch capacity override
i_tradePeriodBranchCapacity(i_tradePeriod,i_Branch)$ (tradePeriodBranchCapacityOvrd(i_tradePeriod,i_Branch) > 0) = tradePeriodBranchCapacityOvrd(i_tradePeriod,i_Branch) ;
i_tradePeriodBranchCapacity(i_tradePeriod,i_Branch)$(tradePeriodBranchCapacityOvrd(i_tradePeriod,i_Branch) and (tradePeriodBranchCapacityOvrd(i_tradePeriod,i_Branch) = eps)) = 0 ;
  option clear = tradePeriodBranchCapacityOvrd ;

* Calculate the from and to date for the branch open status override
BranchOvrdFromDay(i_ovrd,i_Branch) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchOpenStatusOvrdFromDate(i_ovrd,i_Branch,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay)) ;
BranchOvrdFromMonth(i_ovrd,i_Branch) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchOpenStatusOvrdFromDate(i_ovrd,i_Branch,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth)) ;
BranchOvrdFromYear(i_ovrd,i_Branch) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchOpenStatusOvrdFromDate(i_ovrd,i_Branch,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear) ;

BranchOvrdToDay(i_ovrd,i_Branch) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchOpenStatusOvrdToDate(i_ovrd,i_Branch,i_toDay,i_toMonth,i_toYear), ord(i_toDay)) ;
BranchOvrdToMonth(i_ovrd,i_Branch) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchOpenStatusOvrdToDate(i_ovrd,i_Branch,i_toDay,i_toMonth,i_toYear), ord(i_toMonth)) ;
BranchOvrdToYear(i_ovrd,i_Branch) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchOpenStatusOvrdToDate(i_ovrd,i_Branch,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear) ;

BranchOvrdFromGDate(i_ovrd,i_Branch)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchOpenStatusOvrdFromDate(i_ovrd,i_Branch,i_fromDay,i_fromMonth,i_fromYear), 1) = jdate(BranchOvrdFromYear(i_ovrd,i_Branch), BranchOvrdFromMonth(i_ovrd,i_Branch), BranchOvrdFromDay(i_ovrd,i_Branch)) ;
BranchOvrdToGDate(i_ovrd,i_Branch)$sum((i_toDay,i_toMonth,i_toYear)$i_BranchOpenStatusOvrdToDate(i_ovrd,i_Branch,i_toDay,i_toMonth,i_toYear), 1) = jdate(BranchOvrdToYear(i_ovrd,i_Branch), BranchOvrdToMonth(i_ovrd,i_Branch), BranchOvrdToDay(i_ovrd,i_Branch)) ;

* Determine if all the conditions for the branch open status are satisfied
loop((i_ovrd,i_tradePeriod,i_Branch)$(i_studyTradePeriod(i_tradePeriod) and (BranchOvrdFromGDate(i_ovrd,i_Branch) <= inputGDXGDate) and (BranchOvrdToGDate(i_ovrd,i_Branch) >= inputGDXGDate) and i_BranchOpenStatusOvrdTP(i_ovrd,i_Branch,i_tradePeriod) and i_BranchOpenStatusOvrd(i_ovrd,i_Branch)),
    if ((i_BranchOpenStatusOvrd(i_ovrd,i_Branch) > 0),
      tradePeriodBranchOpenStatusOvrd(i_tradePeriod,i_Branch) = i_BranchOpenStatusOvrd(i_ovrd,i_Branch) ;
    elseif (i_BranchOpenStatusOvrd(i_ovrd,i_Branch) = eps),
      tradePeriodBranchOpenStatusOvrd(i_tradePeriod,i_Branch) = eps ;
    ) ;
) ;

* Reset the branch override parameters
  option clear = BranchOvrdFromDay ;                option clear = BranchOvrdFromMonth ;             option clear = BranchOvrdFromYear ;
  option clear = BranchOvrdToDay ;                  option clear = BranchOvrdToMonth ;               option clear = BranchOvrdToYear ;
  option clear = BranchOvrdFromGDate ;              option clear = BranchOvrdToGDate ;

* Apply the branch open status override
i_tradePeriodBranchOpenStatus(i_tradePeriod,i_Branch)$(tradePeriodBranchOpenStatusOvrd(i_tradePeriod,i_Branch) > 0) = tradePeriodBranchOpenStatusOvrd(i_tradePeriod,i_Branch) ;
i_tradePeriodBranchOpenStatus(i_tradePeriod,i_Branch)$(tradePeriodBranchOpenStatusOvrd(i_tradePeriod,i_Branch) and (tradePeriodBranchOpenStatusOvrd(i_tradePeriod,i_Branch) = eps)) = 0 ;
  option clear = tradePeriodBranchOpenStatusOvrd ;

*+++ End branch override +++

*+++ Start branch constraint override +++

* Reset the branch constraint factor override parameters
  option clear = BranchConstraintFactorOvrdFromDay ;        option clear = BranchConstraintFactorOvrdFromMonth ;     option clear = BranchConstraintFactorOvrdFromYear ;
  option clear = BranchConstraintFactorOvrdToDay ;          option clear = BranchConstraintFactorOvrdToMonth ;       option clear = BranchConstraintFactorOvrdToYear ;
  option clear = BranchConstraintFactorOvrdFromGDate ;      option clear = BranchConstraintFactorOvrdToGDate ;

* Calculate the from and to date for the branch constraint factor override
BranchConstraintFactorOvrdFromDay(i_ovrd,i_BranchConstraint,i_Branch) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchConstraintFactorOvrdFromDate(i_ovrd,i_BranchConstraint,i_Branch,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay)) ;
BranchConstraintFactorOvrdFromMonth(i_ovrd,i_BranchConstraint,i_Branch) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchConstraintFactorOvrdFromDate(i_ovrd,i_BranchConstraint,i_Branch,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth)) ;
BranchConstraintFactorOvrdFromYear(i_ovrd,i_BranchConstraint,i_Branch) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchConstraintFactorOvrdFromDate(i_ovrd,i_BranchConstraint,i_Branch,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear) ;

BranchConstraintFactorOvrdToDay(i_ovrd,i_BranchConstraint,i_Branch) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchConstraintFactorOvrdToDate(i_ovrd,i_BranchConstraint,i_Branch,i_toDay,i_toMonth,i_toYear), ord(i_toDay)) ;
BranchConstraintFactorOvrdToMonth(i_ovrd,i_BranchConstraint,i_Branch) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchConstraintFactorOvrdToDate(i_ovrd,i_BranchConstraint,i_Branch,i_toDay,i_toMonth,i_toYear), ord(i_toMonth)) ;
BranchConstraintFactorOvrdToYear(i_ovrd,i_BranchConstraint,i_Branch) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchConstraintFactorOvrdToDate(i_ovrd,i_BranchConstraint,i_Branch,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear) ;

BranchConstraintFactorOvrdFromGDate(i_ovrd,i_BranchConstraint,i_Branch)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchConstraintFactorOvrdFromDate(i_ovrd,i_BranchConstraint,i_Branch,i_fromDay,i_fromMonth,i_fromYear), 1) = jdate(BranchConstraintFactorOvrdFromYear(i_ovrd,i_BranchConstraint,i_Branch), BranchConstraintFactorOvrdFromMonth(i_ovrd,i_BranchConstraint,i_Branch), BranchConstraintFactorOvrdFromDay(i_ovrd,i_BranchConstraint,i_Branch)) ;
BranchConstraintFactorOvrdToGDate(i_ovrd,i_BranchConstraint,i_Branch)$sum((i_toDay,i_toMonth,i_toYear)$i_BranchConstraintFactorOvrdToDate(i_ovrd,i_BranchConstraint,i_Branch,i_toDay,i_toMonth,i_toYear), 1) = jdate(BranchConstraintFactorOvrdToYear(i_ovrd,i_BranchConstraint,i_Branch), BranchConstraintFactorOvrdToMonth(i_ovrd,i_BranchConstraint,i_Branch), BranchConstraintFactorOvrdToDay(i_ovrd,i_BranchConstraint,i_Branch)) ;

* Determine if all the conditions for the branch constraint factor are satisfied
loop((i_ovrd,i_tradePeriod,i_BranchConstraint,i_Branch)$(i_studyTradePeriod(i_tradePeriod) and (BranchConstraintFactorOvrdFromGDate(i_ovrd,i_BranchConstraint,i_Branch) <= inputGDXGDate) and (BranchConstraintFactorOvrdToGDate(i_ovrd,i_BranchConstraint,i_Branch) >= inputGDXGDate) and i_BranchConstraintFactorOvrdTP(i_ovrd,i_BranchConstraint,i_Branch,i_tradePeriod) and i_BranchConstraintFactorOvrd(i_ovrd,i_BranchConstraint,i_Branch)),
    if ((i_BranchConstraintFactorOvrd(i_ovrd,i_BranchConstraint,i_Branch) <> 0),
      tradePeriodBranchConstraintFactorOvrd(i_tradePeriod,i_BranchConstraint,i_Branch) = i_BranchConstraintFactorOvrd(i_ovrd,i_BranchConstraint,i_Branch) ;
    elseif (i_BranchConstraintFactorOvrd(i_ovrd,i_BranchConstraint,i_Branch) = eps),
      tradePeriodBranchConstraintFactorOvrd(i_tradePeriod,i_BranchConstraint,i_Branch) = eps ;
    ) ;
) ;

* Reset the branch constraint factor override parameters
  option clear = BranchConstraintFactorOvrdFromDay ;        option clear = BranchConstraintFactorOvrdFromMonth ;     option clear = BranchConstraintFactorOvrdFromYear ;
  option clear = BranchConstraintFactorOvrdToDay ;          option clear = BranchConstraintFactorOvrdToMonth ;       option clear = BranchConstraintFactorOvrdToYear ;
  option clear = BranchConstraintFactorOvrdFromGDate ;      option clear = BranchConstraintFactorOvrdToGDate ;

* Apply the branch constraint factor override
i_tradePeriodBranchConstraintFactors(i_tradePeriod,i_BranchConstraint,i_Branch)$(tradePeriodBranchConstraintFactorOvrd(i_tradePeriod,i_BranchConstraint,i_Branch) <> 0) = tradePeriodBranchConstraintFactorOvrd(i_tradePeriod,i_BranchConstraint,i_Branch) ;
i_tradePeriodBranchConstraintFactors(i_tradePeriod,i_BranchConstraint,i_Branch)$(tradePeriodBranchConstraintFactorOvrd(i_tradePeriod,i_BranchConstraint,i_Branch) and (tradePeriodBranchConstraintFactorOvrd(i_tradePeriod,i_BranchConstraint,i_Branch) = eps)) = 0 ;
  option clear = tradePeriodBranchConstraintFactorOvrd ;

* Reset the branch constraint RHS override parameters
  option clear = BranchConstraintRHSOvrdFromDay ;           option clear = BranchConstraintRHSOvrdFromMonth ;        option clear = BranchConstraintRHSOvrdFromYear ;
  option clear = BranchConstraintRHSOvrdToDay ;             option clear = BranchConstraintRHSOvrdToMonth ;          option clear = BranchConstraintRHSOvrdToYear ;
  option clear = BranchConstraintRHSOvrdFromGDate ;         option clear = BranchConstraintRHSOvrdToGDate ;

* Calculate the from and to date for the branch constraint RHS override
BranchConstraintRHSOvrdFromDay(i_ovrd,i_BranchConstraint) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchConstraintRHSOvrdFromDate(i_ovrd,i_BranchConstraint,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay)) ;
BranchConstraintRHSOvrdFromMonth(i_ovrd,i_BranchConstraint) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchConstraintRHSOvrdFromDate(i_ovrd,i_BranchConstraint,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth)) ;
BranchConstraintRHSOvrdFromYear(i_ovrd,i_BranchConstraint) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchConstraintRHSOvrdFromDate(i_ovrd,i_BranchConstraint,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear) ;

BranchConstraintRHSOvrdToDay(i_ovrd,i_BranchConstraint) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchConstraintRHSOvrdToDate(i_ovrd,i_BranchConstraint,i_toDay,i_toMonth,i_toYear), ord(i_toDay)) ;
BranchConstraintRHSOvrdToMonth(i_ovrd,i_BranchConstraint) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchConstraintRHSOvrdToDate(i_ovrd,i_BranchConstraint,i_toDay,i_toMonth,i_toYear), ord(i_toMonth)) ;
BranchConstraintRHSOvrdToYear(i_ovrd,i_BranchConstraint) = sum((i_toDay,i_toMonth,i_toYear)$i_BranchConstraintRHSOvrdToDate(i_ovrd,i_BranchConstraint,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear) ;

BranchConstraintRHSOvrdFromGDate(i_ovrd,i_BranchConstraint)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_BranchConstraintRHSOvrdFromDate(i_ovrd,i_BranchConstraint,i_fromDay,i_fromMonth,i_fromYear), 1) = jdate(BranchConstraintRHSOvrdFromYear(i_ovrd,i_BranchConstraint), BranchConstraintRHSOvrdFromMonth(i_ovrd,i_BranchConstraint), BranchConstraintRHSOvrdFromDay(i_ovrd,i_BranchConstraint)) ;
BranchConstraintRHSOvrdToGDate(i_ovrd,i_BranchConstraint)$sum((i_toDay,i_toMonth,i_toYear)$i_BranchConstraintRHSOvrdToDate(i_ovrd,i_BranchConstraint,i_toDay,i_toMonth,i_toYear), 1) = jdate(BranchConstraintRHSOvrdToYear(i_ovrd,i_BranchConstraint), BranchConstraintRHSOvrdToMonth(i_ovrd,i_BranchConstraint), BranchConstraintRHSOvrdToDay(i_ovrd,i_BranchConstraint)) ;

* Determine if all the conditions for the branch constraint RHS are satisfied
loop((i_ovrd,i_tradePeriod,i_BranchConstraint,i_constraintRHS)$(i_studyTradePeriod(i_tradePeriod) and (BranchConstraintRHSOvrdFromGDate(i_ovrd,i_BranchConstraint) <= inputGDXGDate) and (BranchConstraintRHSOvrdToGDate(i_ovrd,i_BranchConstraint) >= inputGDXGDate) and i_BranchConstraintRHSOvrdTP(i_ovrd,i_BranchConstraint,i_tradePeriod) and i_BranchConstraintRHSOvrd(i_ovrd,i_BranchConstraint,i_constraintRHS)),
    if ((i_BranchConstraintRHSOvrd(i_ovrd,i_BranchConstraint,i_constraintRHS) <> 0),
      tradePeriodBranchConstraintRHSOvrd(i_tradePeriod,i_BranchConstraint,i_constraintRHS) = i_BranchConstraintRHSOvrd(i_ovrd,i_BranchConstraint,i_constraintRHS) ;
    elseif (i_BranchConstraintRHSOvrd(i_ovrd,i_BranchConstraint,i_constraintRHS) = eps),
      tradePeriodBranchConstraintRHSOvrd(i_tradePeriod,i_BranchConstraint,i_constraintRHS) = eps ;
    ) ;
) ;

* Reset the branch constraint RHS override parameters
  option clear = BranchConstraintRHSOvrdFromDay ;           option clear = BranchConstraintRHSOvrdFromMonth ;        option clear = BranchConstraintRHSOvrdFromYear ;
  option clear = BranchConstraintRHSOvrdToDay ;             option clear = BranchConstraintRHSOvrdToMonth ;          option clear = BranchConstraintRHSOvrdToYear ;
  option clear = BranchConstraintRHSOvrdFromGDate ;         option clear = BranchConstraintRHSOvrdToGDate ;

* Apply the branch constraint RHS override
i_tradePeriodBranchConstraintRHS(i_tradePeriod,i_BranchConstraint,i_constraintRHS)$(tradePeriodBranchConstraintRHSOvrd(i_tradePeriod,i_BranchConstraint,i_constraintRHS) <> 0) = tradePeriodBranchConstraintRHSOvrd(i_tradePeriod,i_BranchConstraint,i_constraintRHS) ;
i_tradePeriodBranchConstraintRHS(i_tradePeriod,i_BranchConstraint,i_constraintRHS)$(tradePeriodBranchConstraintRHSOvrd(i_tradePeriod,i_BranchConstraint,i_constraintRHS) and (tradePeriodBranchConstraintRHSOvrd(i_tradePeriod,i_BranchConstraint,i_constraintRHS) = eps)) = 0 ;
  option clear = tradePeriodBranchConstraintRHSOvrd ;

*+++ End branch constraint override +++

*+++ Start market node constraint override +++

* Reset the market node energy constraint factor override parameters
  option clear = MnodeEnergyConstraintFactorOvrdFromDay ;   option clear = MnodeEnergyConstraintFactorOvrdFromMonth ;        option clear = MnodeEnergyConstraintFactorOvrdFromYear ;
  option clear = MnodeEnergyConstraintFactorOvrdToDay ;     option clear = MnodeEnergyConstraintFactorOvrdToMonth ;          option clear = MnodeEnergyConstraintFactorOvrdToYear ;
  option clear = MnodeEnergyConstraintFactorOvrdFromGDate ; option clear = MnodeEnergyConstraintFactorOvrdToGDate ;

* Calculate the from and to date for the market node energy constraint factor override
MnodeEnergyConstraintFactorOvrdFromDay(i_ovrd,i_MnodeConstraint,i_offer) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_MnodeEnergyConstraintFactorOvrdFromDate(i_ovrd,i_MnodeConstraint,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay)) ;
MnodeEnergyConstraintFactorOvrdFromMonth(i_ovrd,i_MnodeConstraint,i_offer) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_MnodeEnergyConstraintFactorOvrdFromDate(i_ovrd,i_MnodeConstraint,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth)) ;
MnodeEnergyConstraintFactorOvrdFromYear(i_ovrd,i_MnodeConstraint,i_offer) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_MnodeEnergyConstraintFactorOvrdFromDate(i_ovrd,i_MnodeConstraint,i_offer,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear) ;

MnodeEnergyConstraintFactorOvrdToDay(i_ovrd,i_MnodeConstraint,i_offer) = sum((i_toDay,i_toMonth,i_toYear)$i_MnodeEnergyConstraintFactorOvrdToDate(i_ovrd,i_MnodeConstraint,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toDay)) ;
MnodeEnergyConstraintFactorOvrdToMonth(i_ovrd,i_MnodeConstraint,i_offer) = sum((i_toDay,i_toMonth,i_toYear)$i_MnodeEnergyConstraintFactorOvrdToDate(i_ovrd,i_MnodeConstraint,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toMonth)) ;
MnodeEnergyConstraintFactorOvrdToYear(i_ovrd,i_MnodeConstraint,i_offer) = sum((i_toDay,i_toMonth,i_toYear)$i_MnodeEnergyConstraintFactorOvrdToDate(i_ovrd,i_MnodeConstraint,i_offer,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear) ;

MnodeEnergyConstraintFactorOvrdFromGDate(i_ovrd,i_MnodeConstraint,i_offer)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_MnodeEnergyConstraintFactorOvrdFromDate(i_ovrd,i_MnodeConstraint,i_offer,i_fromDay,i_fromMonth,i_fromYear), 1) = jdate(MnodeEnergyConstraintFactorOvrdFromYear(i_ovrd,i_MnodeConstraint,i_offer), MnodeEnergyConstraintFactorOvrdFromMonth(i_ovrd,i_MnodeConstraint,i_offer), MnodeEnergyConstraintFactorOvrdFromDay(i_ovrd,i_MnodeConstraint,i_offer)) ;
MnodeEnergyConstraintFactorOvrdToGDate(i_ovrd,i_MnodeConstraint,i_offer)$sum((i_toDay,i_toMonth,i_toYear)$i_MnodeEnergyConstraintFactorOvrdToDate(i_ovrd,i_MnodeConstraint,i_offer,i_toDay,i_toMonth,i_toYear), 1) = jdate(MnodeEnergyConstraintFactorOvrdToYear(i_ovrd,i_MnodeConstraint,i_offer), MnodeEnergyConstraintFactorOvrdToMonth(i_ovrd,i_MnodeConstraint,i_offer), MnodeEnergyConstraintFactorOvrdToDay(i_ovrd,i_MnodeConstraint,i_offer)) ;

* Determine if all the conditions for the market node energy constraint factor are satisfied
loop((i_ovrd,i_tradePeriod,i_MnodeConstraint,i_offer)$(i_studyTradePeriod(i_tradePeriod) and (MnodeEnergyConstraintFactorOvrdFromGDate(i_ovrd,i_MnodeConstraint,i_offer) <= inputGDXGDate) and (MnodeEnergyConstraintFactorOvrdToGDate(i_ovrd,i_MnodeConstraint,i_offer) >= inputGDXGDate) and i_MnodeEnergyConstraintFactorOvrdTP(i_ovrd,i_MnodeConstraint,i_offer,i_tradePeriod) and i_MnodeEnergyConstraintFactorOvrd(i_ovrd,i_MnodeConstraint,i_offer)),
    if ((i_MnodeEnergyConstraintFactorOvrd(i_ovrd,i_MnodeConstraint,i_offer) <> 0),
      tradePeriodMnodeEnergyConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer) = i_MnodeEnergyConstraintFactorOvrd(i_ovrd,i_MnodeConstraint,i_offer) ;
    elseif (i_MnodeEnergyConstraintFactorOvrd(i_ovrd,i_MnodeConstraint,i_offer) = eps),
      tradePeriodMnodeEnergyConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer) = eps ;
    ) ;
) ;

* Reset the market node energy constraint factor override parameters
  option clear = MnodeEnergyConstraintFactorOvrdFromDay ;   option clear = MnodeEnergyConstraintFactorOvrdFromMonth ;        option clear = MnodeEnergyConstraintFactorOvrdFromYear ;
  option clear = MnodeEnergyConstraintFactorOvrdToDay ;     option clear = MnodeEnergyConstraintFactorOvrdToMonth ;          option clear = MnodeEnergyConstraintFactorOvrdToYear ;
  option clear = MnodeEnergyConstraintFactorOvrdFromGDate ; option clear = MnodeEnergyConstraintFactorOvrdToGDate ;

* Apply the market node energy constraint factor override
i_tradePeriodMnodeEnergyOfferConstraintFactors(i_tradePeriod,i_MnodeConstraint,i_offer)$(tradePeriodMnodeEnergyConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer) <> 0) = tradePeriodMnodeEnergyConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer) ;
i_tradePeriodMnodeEnergyOfferConstraintFactors(i_tradePeriod,i_MnodeConstraint,i_offer)$(tradePeriodMnodeEnergyConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer) and (tradePeriodMnodeEnergyConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer) = eps)) = 0 ;
  option clear = tradePeriodMnodeEnergyConstraintFactorOvrd ;

* Reset the market node reserve constraint factor override parameters
  option clear = MnodeReserveConstraintFactorOvrdFromDay ;          option clear = MnodeReserveConstraintFactorOvrdFromMonth ;       option clear = MnodeReserveConstraintFactorOvrdFromYear ;
  option clear = MnodeReserveConstraintFactorOvrdToDay ;            option clear = MnodeReserveConstraintFactorOvrdToMonth ;         option clear = MnodeReserveConstraintFactorOvrdToYear ;
  option clear = MnodeReserveConstraintFactorOvrdFromGDate ;        option clear = MnodeReserveConstraintFactorOvrdToGDate ;

* Calculate the from and to date for the market node reserve constraint factor override
MnodeReserveConstraintFactorOvrdFromDay(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_MnodeReserveConstraintFactorOvrdFromDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay)) ;
MnodeReserveConstraintFactorOvrdFromMonth(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_MnodeReserveConstraintFactorOvrdFromDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth)) ;
MnodeReserveConstraintFactorOvrdFromYear(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_MnodeReserveConstraintFactorOvrdFromDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear) ;

MnodeReserveConstraintFactorOvrdToDay(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass) = sum((i_toDay,i_toMonth,i_toYear)$i_MnodeReserveConstraintFactorOvrdToDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass,i_toDay,i_toMonth,i_toYear), ord(i_toDay)) ;
MnodeReserveConstraintFactorOvrdToMonth(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass) = sum((i_toDay,i_toMonth,i_toYear)$i_MnodeReserveConstraintFactorOvrdToDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass,i_toDay,i_toMonth,i_toYear), ord(i_toMonth)) ;
MnodeReserveConstraintFactorOvrdToYear(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass) = sum((i_toDay,i_toMonth,i_toYear)$i_MnodeReserveConstraintFactorOvrdToDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear) ;

MnodeReserveConstraintFactorOvrdFromGDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_MnodeReserveConstraintFactorOvrdFromDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear), 1) = jdate(MnodeReserveConstraintFactorOvrdFromYear(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass), MnodeReserveConstraintFactorOvrdFromMonth(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass), MnodeReserveConstraintFactorOvrdFromDay(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass)) ;
MnodeReserveConstraintFactorOvrdToGDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass)$sum((i_toDay,i_toMonth,i_toYear)$i_MnodeReserveConstraintFactorOvrdToDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass,i_toDay,i_toMonth,i_toYear), 1) = jdate(MnodeReserveConstraintFactorOvrdToYear(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass), MnodeReserveConstraintFactorOvrdToMonth(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass), MnodeReserveConstraintFactorOvrdToDay(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass)) ;

* Determine if all the conditions for the market node reserve constraint factor are satisfied
loop((i_ovrd,i_tradePeriod,i_MnodeConstraint,i_offer,i_reserveClass)$(i_studyTradePeriod(i_tradePeriod) and (MnodeReserveConstraintFactorOvrdFromGDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass) <= inputGDXGDate) and (MnodeReserveConstraintFactorOvrdToGDate(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass) >= inputGDXGDate) and i_MnodeReserveConstraintFactorOvrdTP(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass,i_tradePeriod) and i_MnodeReserveConstraintFactorOvrd(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass)),
    if ((i_MnodeReserveConstraintFactorOvrd(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass) <> 0),
      tradePeriodMnodeReserveConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer,i_reserveClass) = i_MnodeReserveConstraintFactorOvrd(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass) ;
    elseif (i_MnodeReserveConstraintFactorOvrd(i_ovrd,i_MnodeConstraint,i_offer,i_reserveClass) = eps),
      tradePeriodMnodeReserveConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer,i_reserveClass) = eps ;
    ) ;
) ;

* Reset the market node reserve constraint factor override parameters
  option clear = MnodeReserveConstraintFactorOvrdFromDay ;          option clear = MnodeReserveConstraintFactorOvrdFromMonth ;       option clear = MnodeReserveConstraintFactorOvrdFromYear ;
  option clear = MnodeReserveConstraintFactorOvrdToDay ;            option clear = MnodeReserveConstraintFactorOvrdToMonth ;         option clear = MnodeReserveConstraintFactorOvrdToYear ;
  option clear = MnodeReserveConstraintFactorOvrdFromGDate ;        option clear = MnodeReserveConstraintFactorOvrdToGDate ;

* Apply the market node reserve constraint factor override
i_tradePeriodMnodeReserveOfferConstraintFactors(i_tradePeriod,i_MnodeConstraint,i_offer,i_reserveClass,i_reserveType)$(tradePeriodMnodeReserveConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer,i_reserveClass) <> 0) = tradePeriodMnodeReserveConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer,i_reserveClass) ;
i_tradePeriodMnodeReserveOfferConstraintFactors(i_tradePeriod,i_MnodeConstraint,i_offer,i_reserveClass,i_reserveType)$(tradePeriodMnodeReserveConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer,i_reserveClass) and (tradePeriodMnodeReserveConstraintFactorOvrd(i_tradePeriod,i_MnodeConstraint,i_offer,i_reserveClass) = eps)) = 0 ;
  option clear = tradePeriodMnodeReserveConstraintFactorOvrd ;

* Reset the market node reserve constraint RHS override parameters
  option clear = MnodeConstraintRHSOvrdFromDay ;            option clear = MnodeConstraintRHSOvrdFromMonth ;         option clear = MnodeConstraintRHSOvrdFromYear ;
  option clear = MnodeConstraintRHSOvrdToDay ;              option clear = MnodeConstraintRHSOvrdToMonth ;           option clear = MnodeConstraintRHSOvrdToYear ;
  option clear = MnodeConstraintRHSOvrdFromGDate ;          option clear = MnodeConstraintRHSOvrdToGDate ;

* Calculate the from and to date for the market node RHS override
MnodeConstraintRHSOvrdFromDay(i_ovrd,i_MnodeConstraint) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_MnodeConstraintRHSOvrdFromDate(i_ovrd,i_MnodeConstraint,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay)) ;
MnodeConstraintRHSOvrdFromMonth(i_ovrd,i_MnodeConstraint) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_MnodeConstraintRHSOvrdFromDate(i_ovrd,i_MnodeConstraint,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth)) ;
MnodeConstraintRHSOvrdFromYear(i_ovrd,i_MnodeConstraint) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_MnodeConstraintRHSOvrdFromDate(i_ovrd,i_MnodeConstraint,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear) ;

MnodeConstraintRHSOvrdToDay(i_ovrd,i_MnodeConstraint) = sum((i_toDay,i_toMonth,i_toYear)$i_MnodeConstraintRHSOvrdToDate(i_ovrd,i_MnodeConstraint,i_toDay,i_toMonth,i_toYear), ord(i_toDay)) ;
MnodeConstraintRHSOvrdToMonth(i_ovrd,i_MnodeConstraint) = sum((i_toDay,i_toMonth,i_toYear)$i_MnodeConstraintRHSOvrdToDate(i_ovrd,i_MnodeConstraint,i_toDay,i_toMonth,i_toYear), ord(i_toMonth)) ;
MnodeConstraintRHSOvrdToYear(i_ovrd,i_MnodeConstraint) = sum((i_toDay,i_toMonth,i_toYear)$i_MnodeConstraintRHSOvrdToDate(i_ovrd,i_MnodeConstraint,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear) ;

MnodeConstraintRHSOvrdFromGDate(i_ovrd,i_MnodeConstraint)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_MnodeConstraintRHSOvrdFromDate(i_ovrd,i_MnodeConstraint,i_fromDay,i_fromMonth,i_fromYear), 1) = jdate(MnodeConstraintRHSOvrdFromYear(i_ovrd,i_MnodeConstraint), MnodeConstraintRHSOvrdFromMonth(i_ovrd,i_MnodeConstraint), MnodeConstraintRHSOvrdFromDay(i_ovrd,i_MnodeConstraint)) ;
MnodeConstraintRHSOvrdToGDate(i_ovrd,i_MnodeConstraint)$sum((i_toDay,i_toMonth,i_toYear)$i_MnodeConstraintRHSOvrdToDate(i_ovrd,i_MnodeConstraint,i_toDay,i_toMonth,i_toYear), 1) = jdate(MnodeConstraintRHSOvrdToYear(i_ovrd,i_MnodeConstraint), MnodeConstraintRHSOvrdToMonth(i_ovrd,i_MnodeConstraint), MnodeConstraintRHSOvrdToDay(i_ovrd,i_MnodeConstraint)) ;

* Determine if all the conditions for the market node constraint RHS are satisfied
loop((i_ovrd,i_tradePeriod,i_MnodeConstraint,i_constraintRHS)$(i_studyTradePeriod(i_tradePeriod) and (MnodeConstraintRHSOvrdFromGDate(i_ovrd,i_MnodeConstraint) <= inputGDXGDate) and (MnodeConstraintRHSOvrdToGDate(i_ovrd,i_MnodeConstraint) >= inputGDXGDate) and i_MnodeConstraintRHSOvrdTP(i_ovrd,i_MnodeConstraint,i_tradePeriod) and i_MnodeConstraintRHSOvrd(i_ovrd,i_MnodeConstraint,i_constraintRHS)),
    if ((i_MnodeConstraintRHSOvrd(i_ovrd,i_MnodeConstraint,i_constraintRHS) <> 0),
      tradePeriodMnodeConstraintRHSOvrd(i_tradePeriod,i_MnodeConstraint,i_constraintRHS) = i_MnodeConstraintRHSOvrd(i_ovrd,i_MnodeConstraint,i_constraintRHS) ;
    elseif (i_MnodeConstraintRHSOvrd(i_ovrd,i_MnodeConstraint,i_constraintRHS) = eps),
      tradePeriodMnodeConstraintRHSOvrd(i_tradePeriod,i_MnodeConstraint,i_constraintRHS) = eps ;
    ) ;
) ;

* Reset the market node reserve constraint RHS override parameters
  option clear = MnodeConstraintRHSOvrdFromDay ;    option clear = MnodeConstraintRHSOvrdFromMonth ;         option clear = MnodeConstraintRHSOvrdFromYear ;
  option clear = MnodeConstraintRHSOvrdToDay ;      option clear = MnodeConstraintRHSOvrdToMonth ;           option clear = MnodeConstraintRHSOvrdToYear ;
  option clear = MnodeConstraintRHSOvrdFromGDate ;  option clear = MnodeConstraintRHSOvrdToGDate ;

* Market node constraint RHS override
i_tradePeriodMnodeConstraintRHS(i_tradePeriod,i_MnodeConstraint,i_constraintRHS)$(tradePeriodMnodeConstraintRHSOvrd(i_tradePeriod,i_MnodeConstraint,i_constraintRHS) <> 0) = tradePeriodMnodeConstraintRHSOvrd(i_tradePeriod,i_MnodeConstraint,i_constraintRHS) ;
i_tradePeriodMnodeConstraintRHS(i_tradePeriod,i_MnodeConstraint,i_constraintRHS)$(tradePeriodMnodeConstraintRHSOvrd(i_tradePeriod,i_MnodeConstraint,i_constraintRHS) and (tradePeriodMnodeConstraintRHSOvrd(i_tradePeriod,i_MnodeConstraint,i_constraintRHS) = eps)) = 0 ;
  option clear = tradePeriodMnodeConstraintRHSOvrd ;

*+++ End market node constraint override +++

*+++ Start risk/reserve override +++

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

* Calculate the from and to date for the CE RAF override
RAFovrdDay(i_ovrd,i_island,i_reserveClass) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_contingentEventRAFovrdFromDate(i_ovrd,i_island,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay)) ;
RAFovrdMonth(i_ovrd,i_island,i_reserveClass) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_contingentEventRAFovrdFromDate(i_ovrd,i_island,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth)) ;
RAFovrdYear(i_ovrd,i_island,i_reserveClass) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_contingentEventRAFovrdFromDate(i_ovrd,i_island,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear) ;
CERAFovrdFromGDate(i_ovrd,i_island,i_reserveClass)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_contingentEventRAFovrdFromDate(i_ovrd,i_island,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear), 1) = jdate(RAFovrdYear(i_ovrd,i_island,i_reserveClass), RAFovrdMonth(i_ovrd,i_island,i_reserveClass), RAFovrdDay(i_ovrd,i_island,i_reserveClass)) ;

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

RAFovrdDay(i_ovrd,i_island,i_reserveClass) = sum((i_toDay,i_toMonth,i_toYear)$i_contingentEventRAFovrdToDate(i_ovrd,i_island,i_reserveClass,i_toDay,i_toMonth,i_toYear), ord(i_toDay)) ;
RAFovrdMonth(i_ovrd,i_island,i_reserveClass) = sum((i_toDay,i_toMonth,i_toYear)$i_contingentEventRAFovrdToDate(i_ovrd,i_island,i_reserveClass,i_toDay,i_toMonth,i_toYear), ord(i_toMonth)) ;
RAFovrdYear(i_ovrd,i_island,i_reserveClass) = sum((i_toDay,i_toMonth,i_toYear)$i_contingentEventRAFovrdToDate(i_ovrd,i_island,i_reserveClass,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear) ;
CERAFovrdToGDate(i_ovrd,i_island,i_reserveClass)$sum((i_toDay,i_toMonth,i_toYear)$i_contingentEventRAFovrdToDate(i_ovrd,i_island,i_reserveClass,i_toDay,i_toMonth,i_toYear), 1) = jdate(RAFovrdYear(i_ovrd,i_island,i_reserveClass), RAFovrdMonth(i_ovrd,i_island,i_reserveClass), RAFovrdDay(i_ovrd,i_island,i_reserveClass)) ;

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

* Determine if all the conditions for the CE RAF override are satisfied
loop((i_ovrd,i_tradePeriod,i_island,i_reserveClass)$(i_studyTradePeriod(i_tradePeriod) and (CERAFovrdFromGDate(i_ovrd,i_island,i_reserveClass) <= inputGDXGDate) and (CERAFovrdToGDate(i_ovrd,i_island,i_reserveClass) >= inputGDXGDate) and i_contingentEventRAFovrdTP(i_ovrd,i_island,i_reserveClass,i_tradePeriod) and i_contingentEventRAFovrd(i_ovrd,i_island,i_reserveClass)),
    if ((i_contingentEventRAFovrd(i_ovrd,i_island,i_reserveClass) > 0),
      tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) = i_contingentEventRAFovrd(i_ovrd,i_island,i_reserveClass) ;
    elseif (i_contingentEventRAFovrd(i_ovrd,i_island,i_reserveClass) = eps),
      tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) = eps ;
    ) ;
) ;

* Apply the CE RAF override
i_tradePeriodRiskParameter(i_tradePeriod,i_island,i_reserveClass,'GENRISK','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) > 0) = tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) ;
i_tradePeriodRiskParameter(i_tradePeriod,i_island,i_reserveClass,'DCCE','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) > 0) = tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) ;
i_tradePeriodRiskParameter(i_tradePeriod,i_island,i_reserveClass,'Manual','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) > 0) = tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) ;
i_tradePeriodRiskParameter(i_tradePeriod,i_island,i_reserveClass,'GENRISK','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) and (tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) = eps)) = 0 ;
i_tradePeriodRiskParameter(i_tradePeriod,i_island,i_reserveClass,'DCCE','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) and (tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) = eps)) = 0 ;
i_tradePeriodRiskParameter(i_tradePeriod,i_island,i_reserveClass,'Manual','i_riskAdjustmentFactor')$(tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) and (tradePeriodCERAFovrd(i_tradePeriod,i_island,i_reserveClass) = eps)) = 0 ;
  option clear = tradePeriodCERAFovrd ;

* Calculate the from and to date for the ECE RAF override
RAFovrdDay(i_ovrd,i_island,i_reserveClass) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_extendedContingentEventRAFovrdFromDate(i_ovrd,i_island,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay)) ;
RAFovrdMonth(i_ovrd,i_island,i_reserveClass) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_extendedContingentEventRAFovrdFromDate(i_ovrd,i_island,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth)) ;
RAFovrdYear(i_ovrd,i_island,i_reserveClass) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_extendedContingentEventRAFovrdFromDate(i_ovrd,i_island,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear) ;
ECERAFovrdFromGDate(i_ovrd,i_island,i_reserveClass)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_extendedContingentEventRAFovrdFromDate(i_ovrd,i_island,i_reserveClass,i_fromDay,i_fromMonth,i_fromYear), 1) = jdate(RAFovrdYear(i_ovrd,i_island,i_reserveClass), RAFovrdMonth(i_ovrd,i_island,i_reserveClass), RAFovrdDay(i_ovrd,i_island,i_reserveClass)) ;

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

RAFovrdDay(i_ovrd,i_island,i_reserveClass) = sum((i_toDay,i_toMonth,i_toYear)$i_extendedContingentEventRAFovrdToDate(i_ovrd,i_island,i_reserveClass,i_toDay,i_toMonth,i_toYear), ord(i_toDay)) ;
RAFovrdMonth(i_ovrd,i_island,i_reserveClass) = sum((i_toDay,i_toMonth,i_toYear)$i_extendedContingentEventRAFovrdToDate(i_ovrd,i_island,i_reserveClass,i_toDay,i_toMonth,i_toYear), ord(i_toMonth)) ;
RAFovrdYear(i_ovrd,i_island,i_reserveClass) = sum((i_toDay,i_toMonth,i_toYear)$i_extendedContingentEventRAFovrdToDate(i_ovrd,i_island,i_reserveClass,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear) ;
ECERAFovrdToGDate(i_ovrd,i_island,i_reserveClass)$sum((i_toDay,i_toMonth,i_toYear)$i_extendedContingentEventRAFovrdToDate(i_ovrd,i_island,i_reserveClass,i_toDay,i_toMonth,i_toYear), 1) = jdate(RAFovrdYear(i_ovrd,i_island,i_reserveClass), RAFovrdMonth(i_ovrd,i_island,i_reserveClass), RAFovrdDay(i_ovrd,i_island,i_reserveClass)) ;

* Reset the RAF override parameters
  option clear = RAFovrdDay ;             option clear = RAFovrdMonth ;            option clear = RAFovrdYear ;

* Determine if all the conditions for the ECE RAF override are satisfied
loop((i_ovrd,i_tradePeriod,i_island,i_reserveClass)$(i_studyTradePeriod(i_tradePeriod) and (ECERAFovrdFromGDate(i_ovrd,i_island,i_reserveClass) <= inputGDXGDate) and (ECERAFovrdToGDate(i_ovrd,i_island,i_reserveClass) >= inputGDXGDate) and i_extendedContingentEventRAFovrdTP(i_ovrd,i_island,i_reserveClass,i_tradePeriod) and i_extendedContingentEventRAFovrd(i_ovrd,i_island,i_reserveClass)),
    if ((i_extendedContingentEventRAFovrd(i_ovrd,i_island,i_reserveClass) > 0),
      tradePeriodECERAFovrd(i_tradePeriod,i_island,i_reserveClass) = i_extendedContingentEventRAFovrd(i_ovrd,i_island,i_reserveClass) ;
    elseif (i_extendedContingentEventRAFovrd(i_ovrd,i_island,i_reserveClass) = eps),
      tradePeriodECERAFovrd(i_tradePeriod,i_island,i_reserveClass) = eps ;
    ) ;
) ;

* Reset the RAF override parameters
  option clear = CERAFovrdFromGDate ;       option clear = CERAFovrdToGDate ;        option clear = ECERAFovrdFromGDate ;             option clear = ECERAFovrdToGDate ;

* Apply the ECE RAF override
i_tradePeriodRiskParameter(i_tradePeriod,i_island,i_reserveClass,'DCECE','i_riskAdjustmentFactor')$(tradePeriodECERAFovrd(i_tradePeriod,i_island,i_reserveClass) > 0) = tradePeriodECERAFovrd(i_tradePeriod,i_island,i_reserveClass) ;
i_tradePeriodRiskParameter(i_tradePeriod,i_island,i_reserveClass,'DCECE','i_riskAdjustmentFactor')$(tradePeriodECERAFovrd(i_tradePeriod,i_island,i_reserveClass) and (tradePeriodECERAFovrd(i_tradePeriod,i_island,i_reserveClass) = eps)) = 0 ;
  option clear = tradePeriodECERAFovrd ;

* Reset the CE NFR override parameters
  option clear = CENFRovrdDay ;             option clear = CENFRovrdMonth ;          option clear = CENFRovrdYear ;

* Calculate the from and to date for the CE NFR override
CENFRovrdDay(i_ovrd,i_island,i_reserveClass,i_riskClass) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_contingentEventNFRovrdFromDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay)) ;
CENFRovrdMonth(i_ovrd,i_island,i_reserveClass,i_riskClass) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_contingentEventNFRovrdFromDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth)) ;
CENFRovrdYear(i_ovrd,i_island,i_reserveClass,i_riskClass) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_contingentEventNFRovrdFromDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear) ;
CENFRovrdFromGDate(i_ovrd,i_island,i_reserveClass,i_riskClass)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_contingentEventNFRovrdFromDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_fromDay,i_fromMonth,i_fromYear), 1) = jdate(CENFRovrdYear(i_ovrd,i_island,i_reserveClass,i_riskClass), CENFRovrdMonth(i_ovrd,i_island,i_reserveClass,i_riskClass), CENFRovrdDay(i_ovrd,i_island,i_reserveClass,i_riskClass)) ;

* Reset the CE NFR override parameters
  option clear = CENFRovrdDay ;             option clear = CENFRovrdMonth ;          option clear = CENFRovrdYear ;

* Calculate the from and to date for the CE NFR override
CENFRovrdDay(i_ovrd,i_island,i_reserveClass,i_riskClass) = sum((i_toDay,i_toMonth,i_toYear)$i_contingentEventNFRovrdToDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_toDay,i_toMonth,i_toYear), ord(i_toDay)) ;
CENFRovrdMonth(i_ovrd,i_island,i_reserveClass,i_riskClass) = sum((i_toDay,i_toMonth,i_toYear)$i_contingentEventNFRovrdToDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_toDay,i_toMonth,i_toYear), ord(i_toMonth)) ;
CENFRovrdYear(i_ovrd,i_island,i_reserveClass,i_riskClass) = sum((i_toDay,i_toMonth,i_toYear)$i_contingentEventNFRovrdToDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear) ;
CENFRovrdToGDate(i_ovrd,i_island,i_reserveClass,i_riskClass)$sum((i_toDay,i_toMonth,i_toYear)$i_contingentEventNFRovrdToDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_toDay,i_toMonth,i_toYear), 1) = jdate(CENFRovrdYear(i_ovrd,i_island,i_reserveClass,i_riskClass), CENFRovrdMonth(i_ovrd,i_island,i_reserveClass,i_riskClass), CENFRovrdDay(i_ovrd,i_island,i_reserveClass,i_riskClass)) ;

* Reset the CE NFR override parameters
  option clear = CENFRovrdDay ;             option clear = CENFRovrdMonth ;          option clear = CENFRovrdYear ;

* Determine if all the conditions for the CE NFR override are satisfied
loop((i_ovrd,i_tradePeriod,i_island,i_reserveClass,i_riskClass)$(i_studyTradePeriod(i_tradePeriod) and (CENFRovrdFromGDate(i_ovrd,i_island,i_reserveClass,i_riskClass) <= inputGDXGDate) and (CENFRovrdToGDate(i_ovrd,i_island,i_reserveClass,i_riskClass) >= inputGDXGDate) and i_contingentEventNFRovrdTP(i_ovrd,i_island,i_reserveClass,i_riskClass,i_tradePeriod) and i_contingentEventNFRovrd(i_ovrd,i_island,i_reserveClass,i_riskClass)),
    if ((i_contingentEventNFRovrd(i_ovrd,i_island,i_reserveClass,i_riskClass) <> 0),
      tradePeriodCENFRovrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass) = i_contingentEventNFRovrd(i_ovrd,i_island,i_reserveClass,i_riskClass) ;
    elseif (i_contingentEventNFRovrd(i_ovrd,i_island,i_reserveClass,i_riskClass) = eps),
      tradePeriodCENFRovrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass) = eps ;
    ) ;
) ;

* Reset the CE NFR override parameters
  option clear = CENFRovrdFromGDate ;       option clear = CENFRovrdToGDate ;

* Apply the CE NFR override
i_tradePeriodRiskParameter(i_tradePeriod,i_island,i_reserveClass,i_riskClass,'i_FreeReserve')$(tradePeriodCENFRovrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass) <> 0) = tradePeriodCENFRovrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass) ;
i_tradePeriodRiskParameter(i_tradePeriod,i_island,i_reserveClass,i_riskClass,'i_FreeReserve')$(tradePeriodCENFRovrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass) and (tradePeriodCENFRovrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass) = eps)) = 0 ;
  option clear = tradePeriodCENFRovrd ;

* Reset the HVDC risk override parameters
  option clear = HVDCriskOvrdDay ;          option clear = HVDCriskOvrdMonth ;       option clear = HVDCriskOvrdYear ;

* Calculate the from date for the HVDC risk override
HVDCriskOvrdDay(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_HVDCriskParamOvrdFromDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromDay)) ;
HVDCriskOvrdMonth(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_HVDCriskParamOvrdFromDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromMonth)) ;
HVDCriskOvrdYear(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = sum((i_fromDay,i_fromMonth,i_fromYear)$i_HVDCriskParamOvrdFromDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,i_fromDay,i_fromMonth,i_fromYear), ord(i_fromYear) + startYear) ;
HVDCriskOvrdFromGDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)$sum((i_fromDay,i_fromMonth,i_fromYear)$i_HVDCriskParamOvrdFromDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,i_fromDay,i_fromMonth,i_fromYear), 1) = jdate(HVDCriskOvrdYear(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter), HVDCriskOvrdMonth(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter), HVDCriskOvrdDay(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)) ;

* Reset the HVDC risk override parameters
  option clear = HVDCriskOvrdDay ;          option clear = HVDCriskOvrdMonth ;       option clear = HVDCriskOvrdYear ;

* Calculate the to date for the HVDC risk override
HVDCriskOvrdDay(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = sum((i_toDay,i_toMonth,i_toYear)$i_HVDCriskParamOvrdToDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,i_toDay,i_toMonth,i_toYear), ord(i_toDay)) ;
HVDCriskOvrdMonth(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = sum((i_toDay,i_toMonth,i_toYear)$i_HVDCriskParamOvrdToDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,i_toDay,i_toMonth,i_toYear), ord(i_toMonth)) ;
HVDCriskOvrdYear(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = sum((i_toDay,i_toMonth,i_toYear)$i_HVDCriskParamOvrdToDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,i_toDay,i_toMonth,i_toYear), ord(i_toYear) + startYear) ;
HVDCriskOvrdToGDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)$sum((i_toDay,i_toMonth,i_toYear)$i_HVDCriskParamOvrdToDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,i_toDay,i_toMonth,i_toYear), 1) = jdate(HVDCriskOvrdYear(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter), HVDCriskOvrdMonth(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter), HVDCriskOvrdDay(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)) ;

* Reset the HVDC risk override parameters
  option clear = HVDCriskOvrdDay ;          option clear = HVDCriskOvrdMonth ;       option clear = HVDCriskOvrdYear ;

* Determine if all the conditions for the HVDC risk overrides are satisfied
loop((i_ovrd,i_tradePeriod,i_island,i_reserveClass,i_riskClass,i_riskParameter)$(i_studyTradePeriod(i_tradePeriod) and (HVDCriskOvrdFromGDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) <= inputGDXGDate) and (HVDCriskOvrdToGDate(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) >= inputGDXGDate) and i_HVDCriskParamOvrdTP(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter,i_tradePeriod) and i_HVDCriskParamOvrd(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter)),
    if ((i_HVDCriskParamOvrd(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) <> 0),
      tradePeriodHVDCriskOvrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass,i_riskParameter) = i_HVDCriskParamOvrd(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) ;
    elseif (i_HVDCriskParamOvrd(i_ovrd,i_island,i_reserveClass,i_riskClass,i_riskParameter) = eps),
      tradePeriodHVDCriskOvrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass,i_riskParameter) = eps ;
    ) ;
) ;

* Reset the HVDC risk override parameters
  option clear = HVDCriskOvrdFromGDate ;       option clear = HVDCriskOvrdToGDate ;

* Apply HVDC risk override
i_tradePeriodRiskParameter(i_tradePeriod,i_island,i_reserveClass,i_riskClass,i_riskParameter)$(tradePeriodHVDCriskOvrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass,i_riskParameter) <> 0) = tradePeriodHVDCriskOvrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass,i_riskParameter) ;
i_tradePeriodRiskParameter(i_tradePeriod,i_island,i_reserveClass,i_riskClass,i_riskParameter)$(tradePeriodHVDCriskOvrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass,i_riskParameter) and (tradePeriodHVDCriskOvrd(i_tradePeriod,i_island,i_reserveClass,i_riskClass,i_riskParameter) = eps)) = 0 ;
  option clear = tradePeriodHVDCriskOvrd ;

*+++ End risk/reserve overrides +++


* End EMI and Standalone interface override assignments
$label skipEMIandStandaloneOverrides
