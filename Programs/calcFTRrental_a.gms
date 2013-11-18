*=====================================================================================
* Name:                 calcFTRrental_a.gms
* Function:             Implement clause 7 - vSPD settings to calculate branch and
*                       constraint participation loading
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://reports.ea.govt.nz/EMIIntro.htm
* Last modified on:     18 November 2013
*=====================================================================================


* 7.a.ii --> HVDC must always be modeled as in service
Parameters
  i_TradePeriodHVDCDirection(i_TradePeriod, i_Branch) '1 --> to NI, -1 --> to SI';
  i_TradePeriodHVDCDirection(i_TradePeriod,i_Branch) $
                                                   [i_TradePeriodHVDCBranch(i_TradePeriod,i_Branch) and
                                                    Sum((i_FromBus,i_ToBus) $
                                                                           [i_TradePeriodBranchDefn(i_TradePeriod,i_Branch,i_FromBus,i_ToBus) and
                                                                            i_TradePeriodBusIsland(i_TradePeriod,i_FromBus,'SI') and
                                                                            i_TradePeriodBusIsland(i_TradePeriod,i_ToBus,'NI')],1)
                                                    ] = 1 ;

i_TradePeriodHVDCDirection(i_TradePeriod,i_Branch) $
                                                   [i_TradePeriodHVDCBranch(i_TradePeriod,i_Branch) and
                                                    Sum((i_FromBus,i_ToBus) $
                                                                           [i_TradePeriodBranchDefn(i_TradePeriod,i_Branch,i_FromBus,i_ToBus) and
                                                                            i_TradePeriodBusIsland(i_TradePeriod,i_FromBus,'NI') and
                                                                            i_TradePeriodBusIsland(i_TradePeriod,i_ToBus,'SI')],1)
                                                    ] = -1;

i_TradePeriodBranchDefn(i_TradePeriod,i_Branch,i_FromBus,i_ToBus) $ i_TradePeriodHVDCBranch(i_TradePeriod,i_Branch) = no;
i_TradePeriodBranchOpenStatus(i_TradePeriod,i_Branch) $ i_TradePeriodHVDCBranch(i_TradePeriod,i_Branch) = 0;
i_TradePeriodBranchDefn(i_TradePeriod,i_Branch,i_FromBus,i_ToBus) $ [(i_TradePeriodHVDCDirection(i_TradePeriod,i_Branch) = 1) and i_TradePeriodNodeBus(i_TradePeriod,'BEN2201',i_FromBus) and i_TradePeriodNodeBus(i_TradePeriod,'HAY2201',i_ToBus)] = yes;
i_TradePeriodBranchDefn(i_TradePeriod,i_Branch,i_FromBus,i_ToBus) $ [(i_TradePeriodHVDCDirection(i_TradePeriod,i_Branch) = -1) and i_TradePeriodNodeBus(i_TradePeriod,'HAY2201',i_FromBus) and i_TradePeriodNodeBus(i_TradePeriod,'BEN2201',i_ToBus)] = yes;

*7.a.iii --> All generation offer removed
i_TradePeriodEnergyOffer(i_TradePeriod,i_Offer,i_TradeBlock,i_EnergyOfferComponent) = 0;
i_TradePeriodOfferParameter(i_TradePeriod,i_Offer,i_OfferParam) = 0;

*7.a.iv --> All demand removed
i_TradePeriodNodeDemand(i_TradePeriod,i_Node) = 0;

*7.a.v --> Positive hub injections represented by fixing generation at relevant node
$onmulti
SET i_Offer    'dummy Offer'  /'BEN2201 FTR0'/;
SET i_Node     'dummy Node'   /'BEN2201 FTR0'/;
$offmulti
i_TradePeriodNode(i_TradePeriod,'BEN2201 FTR0') = yes;
i_TradePeriodOfferNode(i_TradePeriod,'BEN2201 FTR0','BEN2201 FTR0') = yes;
i_TradePeriodNodeBus(i_TradePeriod,'BEN2201 FTR0',i_Bus) $ i_TradePeriodNodeBus(i_TradePeriod,'BEN2201',i_Bus) = yes;
i_TradePeriodNodeBusAllocationFactor(i_TradePeriod,'BEN2201 FTR0',i_Bus) $ i_TradePeriodNodeBus(i_TradePeriod,'BEN2201',i_Bus) = 1;

i_TradePeriodEnergyOffer(i_TradePeriod,'BEN2201 FTR0','t1','i_GenerationMWOffer') = 5000;
i_TradePeriodEnergyOffer(i_TradePeriod,'BEN2201 FTR0','t1','i_GenerationMWOfferPrice') = 0.01;
i_TradePeriodOfferParameter(i_TradePeriod,'BEN2201 FTR0','i_InitialMW') = 700;
i_TradePeriodOfferParameter(i_TradePeriod,'BEN2201 FTR0','i_ReserveGenerationMaximum') = 9999;

*7.a.vi --> Negative hub injections repesented by fixing demand at relevant node
i_TradePeriodNodeDemand(i_TradePeriod,'OTA2201') = 700;

*7.a.vii --> All fixed and variable losses disabled
i_UseACLossModel = 0;
i_UseHVDCLossModel = 0;

*7.a.viii --> All branch limits set to 9999
i_TradePeriodBranchCapacity(i_TradePeriod,i_Branch) = 9999;

*7.a.ix --> All constraint RHS's set to 9999
i_TradePeriodBranchConstraintRHS(i_TradePeriod,i_BranchConstraint,'i_ConstraintLimit') $ [i_TradePeriodBranchConstraintRHS(i_TradePeriod,i_BranchConstraint,'i_ConstraintSense') = -1] = 9999;

*7.a.ix --> All other constraints disabled
i_UseReserveModel = 0;
i_TradePeriodACNodeConstraintFactors(i_TradePeriod,i_ACNodeConstraint,i_Node) = 0;
i_TradePeriodMNodeEnergyOfferConstraintFactors(i_TradePeriod,i_MNodeConstraint,i_Offer) = 0;
i_UseMixedConstraint = 0;

*Vectorised solve
i_SequentialSolve = 0;

*-----------Clause 7 - vSPD setting to calculate branch and constraint participation loading end---------
