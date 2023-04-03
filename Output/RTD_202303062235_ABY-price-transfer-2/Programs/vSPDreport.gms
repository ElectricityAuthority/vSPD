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
*=====================================================================================
* Writing data in to CSV result files
*=====================================================================================

* Trading period level report
$if not exist "%outputPath%\%runName%\%runName%_BusResults_TP.csv" $goto SkipTP

* Trading period summary result
File
SummaryResults_TP / "%outputPath%\%runName%\%runName%_SummaryResults_TP.csv" / ;
SummaryResults_TP.pc = 5 ;    SummaryResults_TP.lw = 0 ;
SummaryResults_TP.pw = 9999 ; SummaryResults_TP.ap = 1 ;
SummaryResults_TP.nd = 5 ;    SummaryResults_TP.nw = 20 ;
put SummaryResults_TP ;
loop( (dt,rundt),
    put dt.tl,rundt.tl, o_solveOK_TP(dt), o_ofv_TP(dt)
        o_systemCost_TP(dt), o_systemBenefit_TP(dt)
        o_penaltyCost_TP(dt), o_DefGenViolation_TP(dt)
        o_SurpGenViolation_TP(dt),o_DefResv_TP(dt),o_SurpBranchFlow_TP(dt)
        o_DefRampRate_TP(dt), o_SurpRampRate_TP(dt)
        o_DefBranchGroupConst_TP(dt), o_SurpBranchGroupConst_TP(dt)
        o_DefMnodeConst_TP(dt), o_SurpMnodeConst_TP(dt) / ;
) ;

* Trading period island result
File IslandResults_TP /"%outputPath%\%runName%\%runName%_IslandResults_TP.csv"/;
IslandResults_TP.pc = 5 ;     IslandResults_TP.lw = 0 ;
IslandResults_TP.pw = 9999 ;  IslandResults_TP.ap = 1 ;
IslandResults_TP.nd = 5 ;
put IslandResults_TP ;
loop( (dt,rundt,isl),
    put dt.tl,rundt.tl, isl.tl, o_islandGen_TP(dt,isl), o_islandLoad_TP(dt,isl)
        o_islandClrBid_TP(dt,isl), o_islandBranchLoss_TP(dt,isl)
        o_HVDCFlow_TP(dt,isl), o_HVDCLoss_TP(dt,isl)
        o_islandRefPrice_TP(dt,isl), o_FIRReqd_TP(dt,isl)
        o_SIRReqd_TP(dt,isl), o_FIRPrice_TP(dt,isl)o_SIRPrice_TP(dt,isl)
* NIRM output
    o_FirCleared_TP(dt,isl), o_SirCleared_TP(dt,isl)
    o_FirSent_TP(dt,isl), o_SirSent_TP(dt,isl)
    o_FirReceived_TP(dt,isl), o_SirReceived_TP(dt,isl)
    o_FirEffectiveCE_TP(dt,isl), o_SirEffectiveCE_TP(dt,isl)
    o_FirEffectiveECE_TP(dt,isl), o_SirEffectiveECE_TP(dt,isl)
*NIRM output end
    / ;
) ;


* Trading period bus result
File BusResults_TP   / "%outputPath%\%runName%\%runName%_BusResults_TP.csv" / ;
BusResults_TP.pc = 5 ;
BusResults_TP.lw = 0 ;
BusResults_TP.pw = 9999 ;
BusResults_TP.ap = 1 ;
BusResults_TP.nd = 3
put BusResults_TP ;
loop( (dt,rundt,b) $ bus(dt,b),
    put dt.tl,rundt.tl, b.tl, o_busGeneration_TP(dt,b), o_busLoad_TP(dt,b)
        o_busPrice_TP(dt,b), o_busDeficit_TP(dt,b), o_busSurplus_TP(dt,b) / ;
) ;

* Trading period node result
File NodeResults_TP  /"%outputPath%\%runName%\%runName%_NodeResults_TP.csv" / ;
NodeResults_TP.pc = 5 ;
NodeResults_TP.lw = 0 ;
NodeResults_TP.pw = 9999 ;
NodeResults_TP.ap = 1 ;
NodeResults_TP.nd = 4 ;
put NodeResults_TP ;
loop( (dt,rundt,n) $ node(dt,n),
    put dt.tl,rundt.tl, n.tl, o_nodeGeneration_TP(dt,n), o_nodeLoad_TP(dt,n)
        o_nodePrice_TP(dt,n), o_nodeDeficit_TP(dt,n), o_nodeSurplus_TP(dt,n) / ;
) ;

* Trading period offer result
File OfferResults_TP  /"%outputPath%\%runName%\%runName%_OfferResults_TP.csv"/ ;
OfferResults_TP.pc = 5 ;      OfferResults_TP.lw = 0 ;
OfferResults_TP.pw = 9999 ;   OfferResults_TP.ap = 1 ;
OfferResults_TP.nd = 4 ;
put OfferResults_TP ;
loop( (dt,rundt,o,trdr) $ { offer(dt,o) and OfferTrader(dt,o,trdr) },
    put dt.tl, rundt.tl, o.tl, trdr.tl
        o_offerEnergy_TP(dt,o), o_offerFIR_TP(dt,o), o_offerSIR_TP(dt,o) / ;
) ;

* Trading period bid result
File BidResults_TP    / "%outputPath%\%runName%\%runName%_BidResults_TP.csv" / ;
BidResults_TP.pc = 5 ;     BidResults_TP.lw = 0 ;
BidResults_TP.pw = 9999 ;  BidResults_TP.ap = 1 ;
BidResults_TP.nd = 4 ;
put BidResults_TP ;
loop( (dt,rundt,bd,trdr) $ { bid(dt,bd) and BidTrader(dt,bd,trdr) },
    put dt.tl,rundt.tl, bd.tl, trdr.tl
        o_bidTotalMW_TP(dt,bd), o_bidEnergy_TP(dt,bd) / ;
) ;

* Trading period reserve result
File
ReserveResults_TP /"%outputPath%\%runName%\%runName%_ReserveResults_TP.csv" / ;
ReserveResults_TP.pc = 5 ;    ReserveResults_TP.lw = 0 ;
ReserveResults_TP.pw = 9999 ; ReserveResults_TP.ap = 1 ;
ReserveResults_TP.nd = 3 ;
put ReserveResults_TP ;
loop( (dt,rundt,isl),
    put dt.tl,rundt.tl, isl.tl, o_FIRReqd_TP(dt,isl), o_SIRReqd_TP(dt,isl)
        o_FIRPrice_TP(dt,isl), o_SIRPrice_TP(dt,isl)
        o_FIRViolation_TP(dt,isl), o_SIRViolation_TP(dt,isl) / ;
) ;


* Trading period risk result
File riskResults_TP / "%outputPath%\%runName%\%runName%_RiskResults_TP.csv" /;
riskResults_TP.pc = 5;        riskResults_TP.lw = 0;
riskResults_TP.pw = 9999;     riskResults_TP.ap = 1 ;
riskResults_TP.nd = 4 ;
put riskResults_TP ;
loop( (dt,rundt,isl,o,resC,GenRisk)
    $ (o_GenRiskPrice_TP(dt,isl,o,resC,GenRisk) <> 0),
    put dt.tl,rundt.tl, isl.tl, resC.tl ;
    if (ContingentEvents(GenRisk),
         put 'CE', 'GEN' ;
    else
         put 'ECE','GEN' ;
    );

    put o.tl, o_offerEnergy_TP(dt,o), o_offerRes_TP(dt,o,resC), FKband(dt,o)
        FreeReserve(dt,isl,resC,GenRisk)
        o_TotalIslandReserve(dt,isl,resC,GenRisk)
        o_GenRiskShortfall_TP(dt,isl,o,resC,GenRisk)
        o_ResViolation_TP(dt,isl,resC), o_ResPrice_TP(dt,isl,resC)
        o_GenRiskPrice_TP(dt,isl,o,resC,GenRisk)  / ;
);

loop( (dt,rundt,isl,resC,HVDCRisk)
    $ (o_HVDCRiskPrice_TP(dt,isl,resC,HVDCrisk)  <> 0),
    put dt.tl,rundt.tl, isl.tl, resC.tl ;
    if (ContingentEvents(HVDCRisk),
         put 'CE', 'HVDC', 'HVDC';
    else
         put 'ECE','HVDC', 'HVDC';
    );
    put o_HVDCreceived(dt,isl), 0, modulationRiskClass(dt,HVDCrisk)
        o_HVDCRiskSubtractor(dt,isl,resC,HVDCrisk)
        o_TotalIslandReserve(dt,isl,resC,HVDCrisk)
        o_HVDCRiskShortfall_TP(dt,isl,resC,HVDCrisk)
        o_ResViolation_TP(dt,isl,resC), o_ResPrice_TP(dt,isl,resC)
        o_HVDCRiskPrice_TP(dt,isl,resC,HVDCrisk)  / ;
);

loop( (dt,rundt,isl,resC,ManualRisk)
    $ (o_ManualRiskPrice_TP(dt,isl,resC,ManualRisk)  <> 0),
    put dt.tl,rundt.tl, isl.tl, resC.tl ;
    if (ContingentEvents(ManualRisk),
         put 'CE', 'MANUAL', 'MANUAL';
    else
         put 'ECE','MANUAL', 'MANUAL';
    );
    put IslandMinimumRisk(dt,isl,resC,ManualRisk) , 0, 0
        FreeReserve(dt,isl,resC,ManualRisk)
        o_TotalIslandReserve(dt,isl,resC,ManualRisk)
        o_ManualRiskShortfall_TP(dt,isl,resC,ManualRisk)
        o_ResViolation_TP(dt,isl,resC), o_ResPrice_TP(dt,isl,resC)
        o_ManualRiskPrice_TP(dt,isl,resC,ManualRisk)    / ;
);

loop( (dt,rundt,isl,rg,resC,GenRisk)
    $ (o_GenRiskGroupPrice_TP(dt,isl,rg,resC,GenRisk) <> 0),
    put dt.tl,rundt.tl, isl.tl, resC.tl ;
    if (ContingentEvents(GenRisk),
         put 'CE', 'RISKGROUP';
    else
         put 'ECE','RISKGROUP';
    );
    put rg.tl, o_groupEnergy_TP(dt,rg,GenRisk),o_groupRes_TP(dt,rg,resC,GenRisk)
        o_groupFKband_TP(dt,rg,GenRisk), FreeReserve(dt,isl,resC,GenRisk)
        o_TotalIslandReserve(dt,isl,resC,GenRisk)
        o_GenRiskGroupShortfall_TP(dt,isl,rg,resC,GenRisk)
        o_ResViolation_TP(dt,isl,resC), o_ResPrice_TP(dt,isl,resC)
        o_GenRiskGroupPrice_TP(dt,isl,rg,resC,GenRisk)  / ;
);

* Trading period branch result
File
BranchResults_TP  / "%outputPath%\%runName%\%runName%_BranchResults_TP.csv" / ;
BranchResults_TP.pc = 5 ;     BranchResults_TP.lw = 0 ;
BranchResults_TP.pw = 9999 ;  BranchResults_TP.ap = 1 ;
BranchResults_TP.nd = 5 ;
put BranchResults_TP ;
loop( (dt,rundt,br,frB,toB) $ branchDefn(dt,br,frB,toB),
    put dt.tl, rundt.tl, br.tl, frB.tl, toB.tl, o_branchFlow_TP(dt,br)
        o_branchCapacity_TP(dt,br), o_branchDynamicLoss_TP(dt,br)
        o_branchFixedLoss_TP(dt,br), o_branchFromBusPrice_TP(dt,br)
        o_branchToBusPrice_TP(dt,br), o_branchMarginalPrice_TP(dt,br)
        o_branchTotalRentals_TP(dt,br) / ;
) ;


* Trading period branch constraint result
File BrCstrResults_TP
/ "%outputPath%\%runName%\%runName%_BrConstraintResults_TP.csv" / ;
BrCstrResults_TP.pc = 5 ;      BrCstrResults_TP.lw = 0 ;
BrCstrResults_TP.pw = 9999 ;   BrCstrResults_TP.ap = 1 ;
BrCstrResults_TP.nd = 5 ;
put BrCstrResults_TP ;
loop( (dt,rundt,brCstr) $ branchConstraint(dt,brCstr),
    put dt.tl,rundt.tl, brCstr.tl, o_brConstraintLHS_TP(dt,brCstr)
        o_brConstraintSense_TP(dt,brCstr), o_brConstraintRHS_TP(dt,brCstr)
        o_brConstraintPrice_TP(dt,brCstr) / ;
) ;


* Trading period market node constraint result
File MnodeCstrResults_TP
/ "%outputPath%\%runName%\%runName%_MnodeConstraintResults_TP.csv" / ;
MnodeCstrResults_TP.pc = 5 ;    MnodeCstrResults_TP.lw = 0 ;
MnodeCstrResults_TP.pw = 9999 ; MnodeCstrResults_TP.ap = 1 ;
MnodeCstrResults_TP.nd = 5 ;
put MnodeCstrResults_TP ;
loop( (dt,rundt,MnodeCstr) $ MnodeConstraint(dt,MnodeCstr),
    put dt.tl,rundt.tl, MnodeCstr.tl, o_MnodeConstraintLHS_TP(dt,MnodeCstr)
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
loop( (dt,rundt,br) $ branch(dt,br),
    put dt.tl,rundt.tl, br.tl ;
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
loop( (dt,rundt,b,isl) $ { o_bus(dt,b) and busIsland(dt,b,isl) },
    put dt.tl,rundt.tl, isl.tl, b.tl, o_ACBusAngle(dt,b)
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
loop( (dt,rundt,o,isl) $ {offer(dt,o) and offerIsland(dt,o,isl) },
    put dt.tl,rundt.tl, isl.tl, o.tl, o_offerEnergy_TP(dt,o)
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
loop( (dt,rundt,br) $ branch(dt,br),
    put dt.tl,rundt.tl, br.tl, o_branchFlow_TP(dt,br)
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
loop( (dt,rundt,isl,resC),
    loop( (o,GenRisk) $ { ( o_generationRiskLevel(dt,isl,o,resC,GenRisk) > 0 )
                      and ( abs[ o_GenerationRiskLevel(dt,isl,o,resC,GenRisk)
                               - o_ReserveReqd_TP(dt,isl,resC)
                               ] <= ZeroTolerance )
                         },
        put dt.tl,rundt.tl, isl.tl, resC.tl, o.tl, GenRisk.tl
            o_GenerationRiskLevel(dt,isl,o,resC,GenRisk)
            o_ResCleared_TP(dt,isl,resC), o_EffectiveRes_TP(dt,isl,resC,GenRisk)
            o_ResViolation_TP(dt,isl,resC)
            o_ResPrice_TP(dt,isl,resC) / ;

    ) ;

    loop( HVDCrisk $ { (o_HVDCriskLevel(dt,isl,resC,HVDCrisk) > 0)
                   and ( abs[  o_HVDCriskLevel(dt,isl,resC,HVDCrisk)
                             - o_ReserveReqd_TP(dt,isl,resC)
                            ] <= ZeroTolerance )
                     },
        put dt.tl,rundt.tl, isl.tl, resC.tl, 'HVDC', HVDCrisk.tl
            o_HVDCriskLevel(dt,isl,resC,HVDCrisk), o_ResCleared_TP(dt,isl,resC)
            o_EffectiveRes_TP(dt,isl,resC,HVDCRisk)
            o_ResViolation_TP(dt,isl,resC)
            o_ResPrice_TP(dt,isl,resC) / ;
    ) ;

    loop( manualRisk $ { ( o_manuRiskLevel(dt,isl,resC,ManualRisk) > 0 )
                     and ( abs[ o_manuRiskLevel(dt,isl,resC,manualRisk)
                              - o_ReserveReqd_TP(dt,isl,resC)
                              ] <= ZeroTolerance )
                       },
        put dt.tl,rundt.tl, isl.tl, resC.tl, 'Manual', manualRisk.tl
            o_manuRiskLevel(dt,isl,resC,manualRisk),o_ResCleared_TP(dt,isl,resC)
            o_EffectiveRes_TP(dt,isl,resC,manualRisk)
            o_ResViolation_TP(dt,isl,resC)
            o_ResPrice_TP(dt,isl,resC) / ;
    ) ;

    loop( (o,riskC) $ { HVDCsecRisk(riskC)
                    and ( o_genHVDCriskLevel(dt,isl,o,resC,riskC) > 0 )
                    and ( abs[ o_genHVDCriskLevel(dt,isl,o,resC,riskC)
                             - o_ReserveReqd_TP(dt,isl,resC)
                             ] <= ZeroTolerance )
                      },
        put dt.tl,rundt.tl, isl.tl, resC.tl, o.tl, riskC.tl
            o_GenHVDCRiskLevel(dt,isl,o, resC,riskC)
            o_ResCleared_TP(dt,isl,resC), o_EffectiveRes_TP(dt,isl,resC,riskC)
            o_ResViolation_TP(dt,isl,resC)
            o_ResPrice_TP(dt,isl,resC) / ;
    ) ;

    loop( (o,riskC) $ { HVDCsecRisk(riskC)
                    and ( o_manuHVDCriskLevel(dt,isl,resC,riskC) > 0 )
                    and ( abs[ o_manuHVDCriskLevel(dt,isl,resC,riskC)
                             - o_ReserveReqd_TP(dt,isl,resC)
                             ] <= ZeroTolerance )
                      },
        put dt.tl,rundt.tl, isl.tl, resC.tl, 'Manual', riskC.tl
            o_manuHVDCriskLevel(dt,isl,resC,riskC)
            o_ResCleared_TP(dt,isl,resC), o_EffectiveRes_TP(dt,isl,resC,riskC)
            o_ResViolation_TP(dt,isl,resC)
            o_ResPrice_TP(dt,isl,resC) / ;
        ) ;

    loop( (rg,riskC) $ { GenRisk(riskC)
                    and ( o_generationRiskGroupLevel(dt,isl,rg,resC,RiskC) > 0 )
                    and ( abs[ o_generationRiskGroupLevel(dt,isl,rg,resC,RiskC)
                             - o_ReserveReqd_TP(dt,isl,resC)
                             ] <= ZeroTolerance )
                      },
        put dt.tl,rundt.tl, isl.tl, resC.tl, rg.tl, riskC.tl
            o_generationRiskGroupLevel(dt,isl,rg,resC,RiskC)
            o_ResCleared_TP(dt,isl,resC), o_EffectiveRes_TP(dt,isl,resC,riskC)
            o_ResViolation_TP(dt,isl,resC)
            o_ResPrice_TP(dt,isl,resC) / ;
        ) ;

*   Ensure still reporting for conditions with zero FIR and/or SIR required
    if( (o_ReserveReqd_TP(dt,isl,resC) = 0) ,
        put dt.tl,rundt.tl, isl.tl, resC.tl, ' ', ' ', ' '
            o_ResCleared_TP(dt,isl,resC), o_ResViolation_TP(dt,isl,resC)
            o_ResPrice_TP(dt,isl,resC) / ;
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
loop( (dt,rundt),
    put dt.tl,rundt.tl, o_ofv_TP(dt) /
) ;


execute_unload '%outputPath%\%runName%\%GDXname%_AllData.gdx' ;
$endif.AuditReport
*===============================================================================
execute_unload '%outputPath%\%runName%\%GDXname%_AllData.gdx' ;

