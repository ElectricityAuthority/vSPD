*=====================================================================================
* Name:                 vSPDreport.gms
* Function:             Creates the detailed reports for normal SPD mode
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       https://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: https://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Last modified on:     1 Oct 2019
*
*=====================================================================================

* Normal vSPD run output
o_FromDateTime(dt)$( ord(dt) = 1 ) = yes ;

* System surplus needs to be calculated outside the main loop
o_systemSurplus = o_systemLoadCost-o_systemLoadRevenue-o_systemEnergyRevenue ;

* Trader level - Currently this does not include revenue from wind generators
* since wind generation in FP is represented as negative load
o_trader(trdr) = yes ;
o_traderGen(trdr) = sum(o_offerTrader(o,trdr), o_offerGen(o)) ;
o_traderFIR(trdr) = sum(o_offerTrader(o,trdr), o_offerFIR(o)) ;
o_traderSIR(trdr) = sum(o_offerTrader(o,trdr), o_offerSIR(o)) ;
o_traderGenRevenue(trdr) = sum(o_offerTrader(o,trdr), o_offerGenRevenue(o));
o_traderFIRrevenue(trdr) = sum(o_offerTrader(o,trdr), o_offerFIRrevenue(o));
o_traderSIRrevenue(trdr) = sum(o_offerTrader(o,trdr), o_offerSIRrevenue(o));


*=====================================================================================
* Writing data in to CSV result files
*=====================================================================================

* System level summary
File SystemResults    / "%outputPath%\%runName%\%runName%_SystemResults.csv" / ;
SystemResults.pc = 5 ;     SystemResults.lw = 0 ;
SystemResults.pw = 9999 ;  SystemResults.ap = 1 ;
put SystemResults ;
loop( dt $ o_FromDateTime(dt),
    put dt.tl, o_NumTradePeriods, o_systemOFV, o_systemGen, o_systemLoad
        o_systemLoss, o_systemViolation, o_systemFIR, o_systemSIR
        o_systemEnergyRevenue, o_systemLoadCost, o_systemLoadRevenue
        o_systemSurplus / ;
) ;

* Offer level summary
File  OfferResults     / "%outputPath%\%runName%\%runName%_OfferResults.csv" / ;
OfferResults.pc = 5 ;      OfferResults.lw = 0 ;
OfferResults.pw = 9999 ;   OfferResults.ap = 1 ;
put OfferResults ;
loop( (dt,o,trdr)
    $ { o_FromDateTime(dt) and o_offerTrader(o,trdr) and
        [ o_offerGen(o) or o_offerFIR(o) or o_offerSIR(o) ]
      },
    put dt.tl, o_NumTradePeriods, o.tl, trdr.tl
        o_offerGen(o), o_offerFIR(o), o_offerSIR(o) / ;
) ;

* Trader level summary
File  TraderResults   / "%outputPath%\%runName%\%runName%_TraderResults.csv" / ;
TraderResults.pc = 5 ;     TraderResults.lw = 0 ;
TraderResults.pw = 9999 ;  TraderResults.ap = 1 ;
put TraderResults ;
loop( (dt,trdr)
    $ { o_FromDateTime(dt) and o_trader(trdr) and
        [ o_traderGen(trdr) or o_traderFIR(trdr) or o_traderSIR(trdr) ]
      },
    put dt.tl, o_NumTradePeriods, trdr.tl
        o_traderGen(trdr), o_traderFIR(trdr), o_traderSIR(trdr) / ;
) ;


* Trading period level report
$if not exist "%outputPath%\%runName%\%runName%_BusResults_TP.csv" $goto SkipTP

* Trading period summary result
File
SummaryResults_TP / "%outputPath%\%runName%\%runName%_SummaryResults_TP.csv" / ;
SummaryResults_TP.pc = 5 ;    SummaryResults_TP.lw = 0 ;
SummaryResults_TP.pw = 9999 ; SummaryResults_TP.ap = 1 ;
SummaryResults_TP.nd = 5 ;
put SummaryResults_TP ;
loop( dt,
    put dt.tl, o_solveOK_TP(dt), o_ofv_TP(dt)
        o_systemCost_TP(dt), o_systemBenefit_TP(dt)
        o_penaltyCost_TP(dt), o_DefGenViolation_TP(dt)
        o_SurpGenViolation_TP(dt),o_DefResv_TP(dt),o_SurpBranchFlow_TP(dt)
        o_DefRampRate_TP(dt), o_SurpRampRate_TP(dt)
        o_DefBranchGroupConst_TP(dt), o_SurpBranchGroupConst_TP(dt)
        o_DefMnodeConst_TP(dt), o_SurpMnodeConst_TP(dt)
        o_DefACNodeConst_TP(dt), o_SurpACNodeConst_TP(dt)
        o_DefT1MixedConst_TP(dt), o_SurpT1MixedConst_TP(dt)
        o_DefGenericConst_TP(dt), o_SurpGenericConst_TP(dt) / ;
) ;

* Trading period island result
File IslandResults_TP /"%outputPath%\%runName%\%runName%_IslandResults_TP.csv"/;
IslandResults_TP.pc = 5 ;     IslandResults_TP.lw = 0 ;
IslandResults_TP.pw = 9999 ;  IslandResults_TP.ap = 1 ;
IslandResults_TP.nd = 5 ;
put IslandResults_TP ;
loop( (dt,ild) $ o_island(dt,ild),
    put dt.tl, ild.tl, o_islandGen_TP(dt,ild), o_islandLoad_TP(dt,ild)
        o_islandClrBid_TP(dt,ild), o_islandBranchLoss_TP(dt,ild)
        o_HVDCFlow_TP(dt,ild), o_HVDCLoss_TP(dt,ild)
        o_islandRefPrice_TP(dt,ild), o_FIRReqd_TP(dt,ild)
        o_SIRReqd_TP(dt,ild), o_FIRPrice_TP(dt,ild)
        o_SIRPrice_TP(dt,ild), o_islandEnergyRevenue_TP(dt,ild)
        o_islandLoadCost_TP(dt,ild), o_islandLoadRevenue_TP(dt,ild)
* NIRM output
    o_FirCleared_TP(dt,ild), o_SirCleared_TP(dt,ild)
    o_FirSent_TP(dt,ild), o_SirSent_TP(dt,ild)
    o_FirReceived_TP(dt,ild), o_SirReceived_TP(dt,ild)
    o_FirEffReport_TP(dt,ild), o_SirEffReport_TP(dt,ild)
*NIRM output end
    / ;
) ;

$ifthen.ScarcityReport %scarcityExists%==1
* Trading period scarcity results
File scarcityResults_TP    / "%outputPath%\%runName%\%runName%_ScarcityResults_TP.csv" /;
scarcityResults_TP.pc = 5 ;      scarcityResults_TP.lw = 0 ;
scarcityResults_TP.pw = 9999 ;   scarcityResults_TP.ap = 1 ;
scarcityResults_TP.nd = 3 ;
put scarcityResults_TP ;
loop( (dt,ild) $ o_island(dt,ild),
    put dt.tl, ild.tl, o_scarcityExists_TP(dt,ild), o_cptPassed_TP(dt,ild)
        o_avgPriorGWAP_TP(dt,ild), o_islandGWAPbefore_TP(dt,ild)
        o_islandGWAPafter_TP(dt,ild), o_scarcityGWAPbefore_TP(dt,ild)
        o_scarcityGWAPafter_TP(dt,ild), o_scarcityScalingFactor_TP(dt,ild)
        o_GWAPthreshold_TP(dt,ild), o_GWAPfloor_TP(dt,ild)
        o_GWAPceiling_TP(dt,ild) / ;
) ;
$endif.ScarcityReport

* Trading period bus result
File BusResults_TP   / "%outputPath%\%runName%\%runName%_BusResults_TP.csv" / ;
BusResults_TP.pc = 5 ;
BusResults_TP.lw = 0 ;
BusResults_TP.pw = 9999 ;
BusResults_TP.ap = 1 ;
BusResults_TP.nd = 3
put BusResults_TP ;
loop( o_bus(dt,b),
    put dt.tl, b.tl, o_busGeneration_TP(dt,b), o_busLoad_TP(dt,b)
        o_busPrice_TP(dt,b), o_busRevenue_TP(dt,b), o_busCost_TP(dt,b)
        o_busDeficit_TP(dt,b), o_busSurplus_TP(dt,b) / ;
) ;

* Trading period node result
File NodeResults_TP  /"%outputPath%\%runName%\%runName%_NodeResults_TP.csv" / ;
NodeResults_TP.pc = 5 ;
NodeResults_TP.lw = 0 ;
NodeResults_TP.pw = 9999 ;
NodeResults_TP.ap = 1 ;
NodeResults_TP.nd = 3 ;
put NodeResults_TP ;
loop( (dt,n) $ o_node(dt,n),
    put dt.tl, n.tl, o_nodeGeneration_TP(dt,n), o_nodeLoad_TP(dt,n)
        o_nodePrice_TP(dt,n), o_nodeRevenue_TP(dt,n), o_nodeCost_TP(dt,n)
        o_nodeDeficit_TP(dt,n), o_nodeSurplus_TP(dt,n) / ;
) ;

* Trading period offer result
File OfferResults_TP  /"%outputPath%\%runName%\%runName%_OfferResults_TP.csv"/ ;
OfferResults_TP.pc = 5 ;      OfferResults_TP.lw = 0 ;
OfferResults_TP.pw = 9999 ;   OfferResults_TP.ap = 1 ;
OfferResults_TP.nd = 3 ;
put OfferResults_TP ;
loop( (dt,o) $ o_offer(dt,o),
    put dt.tl, o.tl, o_offerEnergy_TP(dt,o)
        o_offerFIR_TP(dt,o), o_offerSIR_TP(dt,o) / ;
) ;

* Trading period bid result
File BidResults_TP    / "%outputPath%\%runName%\%runName%_BidResults_TP.csv" / ;
BidResults_TP.pc = 5 ;     BidResults_TP.lw = 0 ;
BidResults_TP.pw = 9999 ;  BidResults_TP.ap = 1 ;
BidResults_TP.nd = 3 ;
put BidResults_TP ;
loop( (dt,bd) $ o_bid(dt,bd),
    put dt.tl, bd.tl, o_bidTotalMW_TP(dt,bd), o_bidEnergy_TP(dt,bd)
    o_bidFIR_TP(dt,bd), o_bidSIR_TP(dt,bd) / ;
) ;

* Trading period reserve result
File
ReserveResults_TP /"%outputPath%\%runName%\%runName%_ReserveResults_TP.csv" / ;
ReserveResults_TP.pc = 5 ;    ReserveResults_TP.lw = 0 ;
ReserveResults_TP.pw = 9999 ; ReserveResults_TP.ap = 1 ;
ReserveResults_TP.nd = 3 ;
put ReserveResults_TP ;
loop( (dt,ild) $ o_island(dt,ild),
    put dt.tl, ild.tl, o_FIRReqd_TP(dt,ild), o_SIRReqd_TP(dt,ild)
        o_FIRPrice_TP(dt,ild), o_SIRPrice_TP(dt,ild)
        o_FIRViolation_TP(dt,ild), o_SIRViolation_TP(dt,ild)
        o_FIRvrMW_TP(dt,ild), o_SIRvrMW_TP(dt,ild) / ;
) ;

* Trading period branch result
File
BranchResults_TP  / "%outputPath%\%runName%\%runName%_BranchResults_TP.csv" / ;
BranchResults_TP.pc = 5 ;     BranchResults_TP.lw = 0 ;
BranchResults_TP.pw = 9999 ;  BranchResults_TP.ap = 1 ;
BranchResults_TP.nd = 5 ;
put BranchResults_TP ;
loop( (dt,br,frB,toB)
    $ { o_branchToBus_TP(dt,br,toB) and
        o_branchFromBus_TP(dt,br,frB) and o_branch(dt,br)
      },
    put dt.tl, br.tl, frB.tl, toB.tl, o_branchFlow_TP(dt,br)
        o_branchCapacity_TP(dt,br), o_branchDynamicLoss_TP(dt,br)
        o_branchFixedLoss_TP(dt,br), o_branchFromBusPrice_TP(dt,br)
        o_branchToBusPrice_TP(dt,br), o_branchMarginalPrice_TP(dt,br)
        o_branchTotalRentals_TP(dt,br) / ;
) ;

* Trading period branch constraint result
File BrCstrResults_TP
/ "%outputPath%\%runName%\%runName%_BrConstraintResults_TP.csv" / ;
BrCstrResults_TP.pc = 5 ;
BrCstrResults_TP.lw = 0 ;
BrCstrResults_TP.pw = 9999 ;
BrCstrResults_TP.ap = 1 ;
BrCstrResults_TP.nd = 5 ;
put BrCstrResults_TP ;
loop( (dt,brCstr) $ o_brConstraint_TP(dt,brCstr),
    put dt.tl, brCstr.tl, o_brConstraintLHS_TP(dt,brCstr)
        o_brConstraintSense_TP(dt,brCstr), o_brConstraintRHS_TP(dt,brCstr)
        o_brConstraintPrice_TP(dt,brCstr) / ;
) ;

* Trading period market node constraint result
File MnodeCstrResults_TP
/ "%outputPath%\%runName%\%runName%_MnodeConstraintResults_TP.csv" / ;
MnodeCstrResults_TP.pc = 5 ;
MnodeCstrResults_TP.lw = 0 ;
MnodeCstrResults_TP.pw = 9999 ;
MnodeCstrResults_TP.ap = 1 ;
MnodeCstrResults_TP.nd = 5 ;
put MnodeCstrResults_TP ;
loop( (dt,MnodeCstr) $ o_MnodeConstraint_TP(dt,MnodeCstr),
    put dt.tl, MnodeCstr.tl, o_MnodeConstraintLHS_TP(dt,MnodeCstr)
        o_MnodeConstraintSense_TP(dt,MnodeCstr)
        o_MnodeConstraintRHS_TP(dt,MnodeCstr)
        o_MnodeConstraintPrice_TP(dt,MnodeCstr) / ;
) ;

$label SkipTP
*===============================================================================



*===============================================================================
* Audit mode reporting process
*===============================================================================
$ifthen.AuditReport %opMode%=='AUD'

* Introduce zero tolerance to detect risk setter due to rounding issues
Scalar zeroTolerance / 0.000001 / ;


* Audit - branch loss result
File branchLoss_Audit /"%outputPath%\%runName%\%runName%_Audit_BranchLoss.csv"/;
branchLoss_Audit.pc = 5 ;
branchLoss_Audit.lw = 0 ;
branchLoss_Audit.pw = 9999 ;
BranchLoss_Audit.ap = 1 ;
BranchLoss_Audit.nd = 9 ;
put BranchLoss_Audit ;
loop( (dt,br) $ o_branch(dt,br),
    put dt.tl, br.tl ;
    loop(los $ o_LossSegmentBreakPoint(dt,br,los),
        put o_LossSegmentBreakPoint(dt,br,los)
            o_LossSegmentFactor(dt,br,los) ;
    )
    put / ;
) ;

* Audit - bus result
File busResults_Audit /"%outputPath%\%runName%\%runName%_Audit_BusResults.csv"/;
busResults_Audit.pc = 5 ;
busResults_Audit.lw = 0 ;
busResults_Audit.pw = 9999 ;
BusResults_Audit.ap = 1 ;
BusResults_Audit.nd = 5 ;
put BusResults_Audit ;
loop( (dt,b,ild) $ { o_bus(dt,b) and o_busIsland_TP(dt,b,ild) },
    put dt.tl, ild.tl, b.tl, o_ACBusAngle(dt,b)
        o_busPrice_TP(dt,b), o_busLoad_TP(dt,b)
        o_ILBus_FIR_TP(dt,b), o_ILBus_SIR_TP(dt,b) / ;
) ;

* Audit - market node result
File
MNodeResults_Audit  /"%outputPath%\%runName%\%runName%_Audit_MNodeResults.csv"/;
MNodeResults_Audit.pc = 5 ;
MNodeResults_Audit.lw = 0 ;
MNodeResults_Audit.pw = 9999 ;
MNodeResults_Audit.ap = 1 ;
MNodeResults_Audit.nd = 5 ;
put MNodeResults_Audit ;
loop( (dt,o,ild) $ {o_offer(dt,o) and o_MarketNodeIsland_TP(dt,o,ild) },
    put dt.tl, ild.tl, o.tl, o_offerEnergy_TP(dt,o)
        o_PLRO_FIR_TP(dt,o), o_PLRO_SIR_TP(dt,o)
        o_TWRO_FIR_TP(dt,o), o_TWRO_SIR_TP(dt,o) / ;
) ;

* Audit - branch result
File
brchResults_Audit  /"%outputPath%\%runName%\%runName%_Audit_BranchResults.csv"/;
brchResults_Audit.pc = 5 ;
brchResults_Audit.lw = 0 ;
brchResults_Audit.pw = 9999 ;
brchResults_Audit.ap = 1 ;
brchResults_Audit.nd = 9 ;
put brchResults_Audit ;
loop( (dt,br) $ o_branch(dt,br),
    put dt.tl, br.tl, o_branchFlow_TP(dt,br)
        o_branchDynamicLoss_TP(dt,br), o_branchFixedLoss_TP(dt,br)
        [o_branchDynamicLoss_TP(dt,br) + o_branchFixedLoss_TP(dt,br)] ;
    if ( o_branchMarginalPrice_TP(dt,br) <> 0,  put 'Y' ;
    else                                        put 'N' ;
    ) ;

    put o_branchMarginalPrice_TP(dt,br) ;

    if( o_NonPhysicalLoss(dt,br) > NonPhysicalLossTolerance, put 'Y' / ;
    else                                                     put 'N' / ;
    ) ;
) ;

* Audit - risk result
File
riskResults_Audit    /"%outputPath%\%runName%\%runName%_Audit_RiskResults.csv"/;
riskResults_Audit.pc = 5 ;
riskResults_Audit.lw = 0 ;
riskResults_Audit.pw = 9999 ;
RiskResults_Audit.ap = 1 ;
RiskResults_Audit.nd = 5 ;
put RiskResults_Audit ;
loop( (dt,ild,resC) $ o_island(dt,ild),
    loop( (o,GenRisk) $ { ( o_generationRiskLevel(dt,ild,o,resC,GenRisk) > 0 )
                      and ( abs[ o_GenerationRiskLevel(dt,ild,o,resC,GenRisk)
                               - o_ReserveReqd_TP(dt,ild,resC)
                               ] <= ZeroTolerance )
                         },
        put dt.tl, ild.tl, resC.tl, o.tl, GenRisk.tl
            o_GenerationRiskLevel(dt,ild,o,resC,GenRisk)
            o_ResCleared_TP(dt,ild,resC), o_EffectiveRes_TP(dt,ild,resC,GenRisk)
            o_ResViolation_TP(dt,ild,resC)
            o_ResPrice_TP(dt,ild,resC), o_vrResMW_TP(dt,ild,resC) / ;

    ) ;

    loop( HVDCrisk $ { (o_HVDCriskLevel(dt,ild,resC,HVDCrisk) > 0)
                   and ( abs[  o_HVDCriskLevel(dt,ild,resC,HVDCrisk)
                             - o_ReserveReqd_TP(dt,ild,resC)
                            ] <= ZeroTolerance )
                     },
        put dt.tl, ild.tl, resC.tl, 'HVDC', HVDCrisk.tl
            o_HVDCriskLevel(dt,ild,resC,HVDCrisk), o_ResCleared_TP(dt,ild,resC)
            o_EffectiveRes_TP(dt,ild,resC,HVDCRisk)
            o_ResViolation_TP(dt,ild,resC)
            o_ResPrice_TP(dt,ild,resC), o_vrResMW_TP(dt,ild,resC) / ;
    ) ;

    loop( manualRisk $ { ( o_manuRiskLevel(dt,ild,resC,ManualRisk) > 0 )
                     and ( abs[ o_manuRiskLevel(dt,ild,resC,manualRisk)
                              - o_ReserveReqd_TP(dt,ild,resC)
                              ] <= ZeroTolerance )
                       },
        put dt.tl, ild.tl, resC.tl, 'Manual', manualRisk.tl
            o_manuRiskLevel(dt,ild,resC,manualRisk),o_ResCleared_TP(dt,ild,resC)
            o_EffectiveRes_TP(dt,ild,resC,manualRisk)
            o_ResViolation_TP(dt,ild,resC)
            o_ResPrice_TP(dt,ild,resC), o_vrResMW_TP(dt,ild,resC) / ;
    ) ;

    loop( (o,riskC) $ { HVDCsecRisk(riskC)
                    and ( o_genHVDCriskLevel(dt,ild,o,resC,riskC) > 0 )
                    and ( abs[ o_genHVDCriskLevel(dt,ild,o,resC,riskC)
                             - o_ReserveReqd_TP(dt,ild,resC)
                             ] <= ZeroTolerance )
                      },
        put dt.tl, ild.tl, resC.tl, o.tl, riskC.tl
            o_GenHVDCRiskLevel(dt,ild,o, resC,riskC)
            o_ResCleared_TP(dt,ild,resC), o_EffectiveRes_TP(dt,ild,resC,riskC)
            o_ResViolation_TP(dt,ild,resC)
            o_ResPrice_TP(dt,ild,resC), o_vrResMW_TP(dt,ild,resC) / ;
    ) ;

    loop( (o,riskC) $ { HVDCsecRisk(riskC)
                    and ( o_manuHVDCriskLevel(dt,ild,resC,riskC) > 0 )
                    and ( abs[ o_manuHVDCriskLevel(dt,ild,resC,riskC)
                             - o_ReserveReqd_TP(dt,ild,resC)
                             ] <= ZeroTolerance )
                      },
        put dt.tl, ild.tl, resC.tl, 'Manual', riskC.tl
            o_manuHVDCriskLevel(dt,ild,resC,riskC)
            o_ResCleared_TP(dt,ild,resC), o_EffectiveRes_TP(dt,ild,resC,riskC)
            o_ResViolation_TP(dt,ild,resC)
            o_ResPrice_TP(dt,ild,resC), o_vrResMW_TP(dt,ild,resC) / ;
        ) ;

*   Ensure still reporting for conditions with zero FIR and/or SIR required
    if( (o_ReserveReqd_TP(dt,ild,resC) = 0) ,
        put dt.tl, ild.tl, resC.tl, ' ', ' ', ' '
            o_ResCleared_TP(dt,ild,resC), o_ResViolation_TP(dt,ild,resC)
            o_ResPrice_TP(dt,ild,resC), o_vrResMW_TP(dt,ild,resC) / ;
    ) ;
) ;

* Audit - objective result
File objResults_Audit /"%outputPath%\%runName%\%runName%_Audit_ObjResults.csv"/;
objResults_Audit.pc = 5 ;
objResults_Audit.lw = 0 ;
objResults_Audit.pw = 9999 ;
objResults_Audit.ap = 1 ;
objResults_Audit.nd = 5 ;
objResults_Audit.nw = 20 ;
put objResults_Audit
loop( dt,
    put dt.tl, o_ofv_TP(dt) /
) ;


execute_unload '%outputPath%\%runName%\%vSPDinputData%_AllData.gdx' ;
$endif.AuditReport
*===============================================================================
*execute_unload '%outputPath%\%runName%\%vSPDinputData%_AllData.gdx' ;




