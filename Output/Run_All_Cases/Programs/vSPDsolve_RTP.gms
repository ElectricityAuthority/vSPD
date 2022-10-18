*=====================================================================================
* Name:                 vSPDsolve_RTP.gms
* Function:             First RTD solve to update island loss in order to
*                       adjust node demand
*                       A new development for Rea
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: http://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Created on:           14 Jan 2022

*=====================================================================================

*   7d. Solve Models First Time For Real Time Pricing
*=====================================================================================
* 7. The vSPD solve loop
*=====================================================================================
put_utility temp 'gdxin' / '%inputPath%\%GDXname%.gdx' ;
execute_load SPDLoadCalcLosses = i_dateTimeSPDLoadCalcLosses  ;
put_utility temp 'gdxin' ;

unsolvedDT(dt) = yes;
VSPDModel(dt) = 0 ;
option clear = useBranchFlowMIP ;

While ( Sum[ dt $ unsolvedDT(dt), 1 ],
  exitLoop = 0;
  loop[ dt $ {unsolvedDT(dt) and (exitLoop = 0)},

*   7a. Reset all sets, parameters and variables -------------------------------
    option clear = t ;
*   Generation variables
    option clear = GENERATION ;
    option clear = GENERATIONBLOCK ;
    option clear = GENERATIONUPDELTA ;
    option clear = GENERATIONDNDELTA ;
*   Purchase variables
    option clear = PURCHASE ;
    option clear = PURCHASEBLOCK ;
*   Network variables
    option clear = ACNODENETINJECTION ;
    option clear = ACNODEANGLE ;
    option clear = ACBRANCHFLOW ;
    option clear = ACBRANCHFLOWDIRECTED ;
    option clear = ACBRANCHLOSSESDIRECTED ;
    option clear = ACBRANCHFLOWBLOCKDIRECTED ;
    option clear = ACBRANCHLOSSESBLOCKDIRECTED ;
    option clear = ACBRANCHFLOWDIRECTED_INTEGER ;
    option clear = HVDCLINKFLOW ;
    option clear = HVDCLINKLOSSES ;
    option clear = LAMBDA ;
    option clear = LAMBDAINTEGER ;
    option clear = HVDCLINKFLOWDIRECTED_INTEGER ;
    option clear = HVDCPOLEFLOW_INTEGER ;
*   Risk/Reserve variables
    option clear = RISKOFFSET ;
    option clear = HVDCREC ;
    option clear = ISLANDRISK ;
    option clear = RESERVEBLOCK ;
    option clear = RESERVE ;
    option clear = ISLANDRESERVE;
*   NMIR variables
    option clear = SHAREDNFR ;
    option clear = SHAREDRESERVE ;
    option clear = HVDCSENT ;
    option clear = RESERVESHAREEFFECTIVE ;
    option clear = RESERVESHARERECEIVED ;
    option clear = RESERVESHARESENT ;
    option clear = HVDCSENDING ;
    option clear = INZONE ;
    option clear = HVDCSENTINSEGMENT ;
    option clear = HVDCRESERVESENT ;
    option clear = HVDCSENTLOSS ;
    option clear = HVDCRESERVELOSS ;
    option clear = LAMBDAHVDCENERGY ;
    option clear = LAMBDAHVDCRESERVE ;
    option clear = RESERVESHAREPENALTY ;
*   Objective
    option clear = NETBENEFIT ;
*   Violation variables
    option clear = TOTALPENALTYCOST ;
    option clear = DEFICITBUSGENERATION ;
    option clear = SURPLUSBUSGENERATION ;
    option clear = DEFICITRESERVE_CE ;
    option clear = DEFICITRESERVE_ECE ;
    option clear = DEFICITBRANCHSECURITYCONSTRAINT ;
    option clear = SURPLUSBRANCHSECURITYCONSTRAINT ;
    option clear = DEFICITRAMPRATE ;
    option clear = SURPLUSRAMPRATE ;
    option clear = DEFICITBRANCHFLOW ;
    option clear = SURPLUSBRANCHFLOW ;
    option clear = DEFICITMNODECONSTRAINT ;
    option clear = SURPLUSMNODECONSTRAINT ;

    option clear = SCARCITYCOST;
    option clear = ENERGYSCARCITYBLK ;
    option clear = ENERGYSCARCITYNODE;

*   Clear the pole circular branch flow flag
    option clear = circularBranchFlowExist ;
    option clear = poleCircularBranchFlowExist ;
    option clear = northHVDC ;
    option clear = southHVDC ;
    option clear = manualBranchSegmentMWFlow ;
    option clear = manualLossCalculation ;
    option clear = nonPhysicalLossExist ;
    option clear = modelSolved ;
    option clear = LPmodelSolved ;
*   Disconnected bus post-processing
    option clear = busGeneration ;
    option clear = busLoad ;
    option clear = busDisconnected ;
    option clear = busPrice ;


*   End reset


*   7b. Initialise current trade period and model data -------------------------
    t(dt)  $ sequentialSolve       = yes;
    t(dt1) $ (not sequentialSolve) = yes;

*   Update initial MW if run NRSS, PRSS, NRSL, PRSL
    generationStart(offer(t(dt),o))
        $ (sum[ o1, generationStart(dt,o1)] = 0)
        = sum[ dt1 $ (ord(dt1) = ord(dt)-1), o_offerEnergy_TP(dt1,o) ] ;

$ontext
these are not used anymore
*   Calculation of generation upper limits due to ramp rate limits
*   Calculation 5.3.1.2. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
    rampTimeUp(offer(t(tp),o))
        $ { (not hasPrimaryOffer(offer)) and rampRateUp(offer) }
        = Min[ intervalDuration , ( generationMaximum(offer)
                                       - generationStart(offer)
                                       ) / rampRateUp(offer)
             ] ;

*   Calculation 5.3.1.3. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
    generationEndUp(offer(t(tp),o)) $ (not hasPrimaryOffer(offer))
        = generationStart(offer) + rampRateUp(offer)*rampTimeUp(offer) ;


*   Calculation of generation lower limits due to ramp rate limits

*   Calculation 5.3.2.2. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
    rampTimeDown(offer(t(tp),o))
        $ { (not hasPrimaryOffer(offer)) and rampRateDown(offer) }
        = Min[ intervalDuration, ( generationStart(offer)
                                      - generationMinimum(offer)
                                      ) / rampRateDown(offer)
             ] ;

*   Calculation 5.3.2.3. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
    generationEndDown(offer(t(tp),o)) $ (not hasPrimaryOffer(offer))
        = Max[ 0, generationStart(offer)
                - rampRateDown(offer)*rampTimeDown(offer) ] ;
$offtext
*   Additional pre-processing on parameters end


*   7c. Updating the variable bounds before model solve ------------------------

* TN - Pivot or Demand Analysis - revise input data
$Ifi %opMode%=='PVT' $include "Pivot\vSPDSolvePivot_2.gms"
$Ifi %opMode%=='DPS' $include "Demand\vSPDSolveDPS_2.gms"
* TN - Pivot or Demand Analysis - revise input data end

*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS ========================

*   Offer blocks - Constraint 6.1.1.1
    GENERATIONBLOCK.up(genOfrBlk(t,o,blk))
        = EnrgOfrMW(genOfrBlk) ;

    GENERATIONBLOCK.fx(t,o,blk)
        $ (not genOfrBlk(t,o,blk)) = 0 ;

*   Constraint 6.1.1.2 - Fix the invalid generation to Zero
    GENERATION.fx(offer(t,o)) $ (not posEnrgOfr(offer)) = 0 ;

*   Constraint 6.1.1.3 - Set Upper Bound for intermittent generation
    GENERATION.up(offer(t,o))
        $ { windOffer(offer) and priceResponsive(offer) }
        = min[ potentialMW(offer), ReserveGenerationMaximum(offer) ] ;

*   Constraint 6.1.1.4 - Set Upper/Lower Bound for Positive Demand Bid
    PURCHASEBLOCK.up(demBidBlk(t,bd,blk))
        = DemBidMW(t,bd,blk) $ [DemBidMW(t,bd,blk)>0];

    PURCHASEBLOCK.lo(demBidBlk(t,bd,blk))
        = 0 $ [DemBidMW(t,bd,blk)>0];

*   Constraint 6.1.1.5 - Set Upper/Lower Bound for Negativetive Demand Bid
    PURCHASEBLOCK.up(demBidBlk(t,bd,blk))
        = 0 $ [DemBidMW(t,bd,blk)<0];

    PURCHASEBLOCK.lo(demBidBlk(t,bd,blk))
        = DemBidMW(t,bd,blk) $ [DemBidMW(t,bd,blk)<0];

    PURCHASEBLOCK.fx(t,bd,blk)
        $ (not demBidBlk(t,bd,blk))
        = 0 ;

    PURCHASE.fx(t,bd) $ (sum[blk $ demBidBlk(t,bd,blk), 1] = 0) = 0 ;

*   Constraint 6.1.1.7 - Set Upper Bound for Energy Scaricty Block
    ENERGYSCARCITYBLK.up(t,n,blk) = ScarcityEnrgLimit(t,n,blk) ;
    ENERGYSCARCITYBLK.fx(t,n,blk) $ (not EnergyScarcityEnabled(t)) = 0;
    ENERGYSCARCITYNODE.fx(t,n) $ (not EnergyScarcityEnabled(t)) = 0;

*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS END ====================


*======= HVDC TRANSMISSION EQUATIONS ===========================================

*   Ensure that variables used to specify flow and losses on HVDC link are
*   zero for AC branches and for open HVDC links.
    HVDCLINKFLOW.fx(t,br)   $ (not HVDClink(t,br)) = 0 ;
    HVDCLINKLOSSES.fx(t,br) $ (not HVDClink(t,br)) = 0 ;

*   Apply an upper bound on the weighting parameter based on its definition
    LAMBDA.up(branch,bp) = 1 ;

*   Ensure that the weighting factor value is zero for AC branches and for
*   invalid loss segments on HVDC links
    LAMBDA.fx(HVDClink,bp)
        $ ( sum[fd $ validLossSegment(HVDClink,bp,fd),1] = 0 ) = 0 ;
    LAMBDA.fx(t,br,bp) $ (not HVDClink(t,br)) = 0 ;

*======= HVDC TRANSMISSION EQUATIONS END =======================================


*======= AC TRANSMISSION EQUATIONS =============================================

*   Ensure that variables used to specify flow and losses on AC branches are
*   zero for HVDC links branches and for open AC branches
    ACBRANCHFLOW.fx(t,br)              $ (not ACbranch(t,br)) = 0 ;
    ACBRANCHFLOWDIRECTED.fx(t,br,fd)   $ (not ACbranch(t,br)) = 0 ;
    ACBRANCHLOSSESDIRECTED.fx(t,br,fd) $ (not ACbranch(t,br)) = 0 ;

*   Ensure directed block flow and loss block variables are zero for
*   non-AC branches and invalid loss segments on AC branches
   ACBRANCHFLOWBLOCKDIRECTED.fx(t,br,los,fd)
       $ { not(ACbranch(t,br) and validLossSegment(t,br,los,fd)) } = 0 ;

   ACBRANCHLOSSESBLOCKDIRECTED.fx(t,br,los,fd)
       $ { not(ACbranch(t,br) and validLossSegment(t,br,los,fd)) } = 0 ;


*   Constraint 3.3.1.10 - Ensure that the bus voltage angle for the buses
*   corresponding to the reference nodes and the HVDC nodes are set to zero
    ACNODEANGLE.fx(t,b)
       $ sum[ n $ { NodeBus(t,n,b) and refNode(t,n) }, 1 ] = 0 ;

*======= AC TRANSMISSION EQUATIONS END =========================================


*======= RISK & RESERVE EQUATIONS ==============================================

*   Ensure that all the invalid reserve blocks are set to zero for offers and purchasers
    RESERVEBLOCK.fx(offer(t,o),blk,resC,resT)
        $ (not resOfrBlk(offer,blk,resC,resT)) = 0 ;

*   Reserve block maximum for offers and purchasers - Constraint 6.5.3.2.
    RESERVEBLOCK.up(resOfrBlk(t,o,blk,resC,resT))
        = ResOfrMW(resOfrBlk) ;

*   Fix the reserve variable for invalid reserve offers. These are offers that
*   are either not connected to the grid or have no reserve quantity offered.
    RESERVE.fx(t,o,resC,resT)
        $ (not sum[ blk $ resOfrBlk(t,o,blk,resC,resT), 1 ] ) = 0 ;

*   NMIR project variables
    HVDCSENT.fx(t,isl) $ (HVDCCapacity(t,isl) = 0) = 0 ;
    HVDCSENTLOSS.fx(t,isl) $ (HVDCCapacity(t,isl) = 0) = 0 ;

*   (3.4.2.3) - SPD version 11.0
    SHAREDNFR.up(t,isl) = Max[0,sharedNFRMax(t,isl)] ;

*   No forward reserve sharing if HVDC capacity is zero
    RESERVESHARESENT.fx(t,isl,resC,rd)
        $ { (HVDCCapacity(t,isl) = 0) and (ord(rd) = 1) } = 0 ;

*   No forward reserve sharing if reserve sharing is disabled
    RESERVESHARESENT.fx(t,isl,resC,rd)
        $ (reserveShareEnabled(t,resC)=0) = 0;

*   No reserve sharing to cover HVDC risk
    RESERVESHAREEFFECTIVE.fx(t,isl,resC,HVDCrisk) = 0;
    RESERVESHAREEFFECTIVE.fx(t,isl,resC,HVDCsecRisk) = 0;

*   (3.4.2.16) - SPD version 11 - no RP zone if reserve round power disabled
    INZONE.fx(t,isl,resC,z)
        $ {(ord(z) = 1) and (not reserveRoundPower(t,resC))} = 0;

*   (3.4.2.17) - SPD version 11 - no no-reserve zone for SIR zone if reserve RP enabled
    INZONE.fx(t,isl,resC,z)
        $ {(ord(resC)=2) and (ord(z)=2) and reserveRoundPower(t,resC)} = 0;

*   Fixing Lambda integer variable for energy sent
    LAMBDAHVDCENERGY.fx(t,isl,bp) $ { (HVDCCapacity(t,isl) = 0)
                                        and (ord(bp) = 1) } = 1 ;

    LAMBDAHVDCENERGY.fx(t,isl,bp) $ (ord(bp) > 7) = 0 ;

* To be reviewed NMIR
    LAMBDAHVDCRESERVE.fx(t,isl,resC,rd,rsbp)
        $ { (HVDCCapacity(t,isl) = 0)
        and (ord(rsbp) = 7) and (ord(rd) = 1) } = 1 ;

    LAMBDAHVDCRESERVE.fx(t,isl1,resC,rd,rsbp)
        $ { (sum[ isl $ (not sameas(isl,isl1)), HVDCCapacity(t,isl) ] = 0)
        and (ord(rsbp) < 7) and (ord(rd) = 2) } = 0 ;

*   Contraint 6.5.4.2 - Set Upper Bound for reserve shortfall
    RESERVESHORTFALLBLK.up(t,isl,resC,riskC,blk)
        = scarcityResrvIslandLimit(t,isl,resC,blk) $ reserveScarcityEnabled(t);
    RESERVESHORTFALLBLK.fx(t,isl,resC,riskC,blk)
        $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALL.fx(t,isl,resC,riskC)
        $ (not reserveScarcityEnabled(t)) = 0;

    RESERVESHORTFALLUNITBLK.up(t,isl,o,resC,riskC,blk)
        = scarcityResrvIslandLimit(t,isl,resC,blk) $ reserveScarcityEnabled(t);
    RESERVESHORTFALLUNITBLK.fx(t,isl,o,resC,riskC,blk)
        $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALLUNIT.fx(t,isl,o,resC,riskC)
        $ (not reserveScarcityEnabled(t)) = 0;

    RESERVESHORTFALLGROUPBLK.up(t,isl,rg,resC,riskC,blk)
        = scarcityResrvIslandLimit(t,isl,resC,blk) $ reserveScarcityEnabled(t);
    RESERVESHORTFALLGROUPBLK.fx(t,isl,rg,resC,riskC,blk)
        $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALLGROUP.fx(t,isl,rg,resC,riskC)
        $ (not reserveScarcityEnabled(t)) = 0;
;


*======= RISK & RESERVE EQUATIONS END ==========================================


*   Updating the variable bounds before model solve end


*   7d. Solve Models
*   Solve the LP model ---------------------------------------------------------
    if( (Sum[t, VSPDModel(t)] = 0),

        if( UseShareReserve,
            option bratio = 1 ;
            vSPD_NMIR.Optfile = 1 ;
            vSPD_NMIR.optcr = MIPOptimality ;
            vSPD_NMIR.reslim = MIPTimeLimit ;
            vSPD_NMIR.iterlim = MIPIterationLimit ;
            solve vSPD_NMIR using mip maximizing NETBENEFIT ;
*           Set the model solve status
            ModelSolved = 1 $ { ( (vSPD_NMIR.modelstat = 1)
                               or (vSPD_NMIR.modelstat = 8) )
                            and ( vSPD_NMIR.solvestat = 1 ) } ;
        else
            option bratio = 1 ;
            vSPD.reslim = LPTimeLimit ;
            vSPD.iterlim = LPIterationLimit ;
            solve vSPD using lp maximizing NETBENEFIT ;
*           Set the model solve status
            ModelSolved = 1 $ { (vSPD.modelstat = 1) and (vSPD.solvestat = 1) };
        )

*       Post a progress message to the console and for use by EMI.
        if((ModelSolved = 1) and (sequentialSolve = 0),
            putclose rep 'The case: %GDXname% '
                         'is 1st solved successfully.'/
                         'Objective function value: '
                         NETBENEFIT.l:<15:4 /
                         'Violation Cost          : '
                         TOTALPENALTYCOST.l:<15:4 /
        elseif((ModelSolved = 0) and (sequentialSolve = 0)),
            putclose rep 'The case: %GDXname% '
                         'is 1st solved unsuccessfully.'/
        ) ;

        if((ModelSolved = 1) and (sequentialSolve = 1),
            loop(t,
                putclose rep 'The case: %GDXname% (' t.tl ') '
                             'is 1st solved successfully.'/
                             'Objective function value: '
                             NETBENEFIT.l:<15:4 /
                             'Violations cost         : '
                             TOTALPENALTYCOST.l:<15:4 /
            ) ;
        elseif((ModelSolved = 0) and (sequentialSolve = 1)),
            loop(t,
                unsolvedDT(t) = no;
                putclose rep 'The case: %GDXname% (' t.tl ') '
                             'is 1st solved unsuccessfully.'/
            ) ;

        ) ;
*   Solve the LP model end -----------------------------------------------------

*   Solve the vSPD_BranchFlowMIP -----------------------------------------------
    elseif (Sum[t, VSPDModel(t)] = 1),
*       Fix the values of these integer variables that are not needed
        ACBRANCHFLOWDIRECTED_INTEGER.fx(branch(t,br),fd)
            $ { (not ACbranch(t,br)) or (not LossBranch(branch)) } = 0 ;

*       Fix the integer AC branch flow variable to zero for invalid branches
        ACBRANCHFLOWDIRECTED_INTEGER.fx(t,br,fd)
            $ (not branch(t,br)) = 0 ;

*       Apply an upper bound on the integer weighting parameter
        LAMBDAINTEGER.up(branch(t,br),bp) = 1 ;

*       Ensure that the weighting factor value is zero for AC branches
*       and for invalid loss segments on HVDC links
        LAMBDAINTEGER.fx(branch(t,br),bp)
            $ { ACbranch(branch)
            or ( sum[fd $ validLossSegment(branch,bp,fd),1 ] = 0 )
              } = 0 ;

*       Fix the lambda integer variable to zero for invalid branches
        LAMBDAINTEGER.fx(t,br,bp) $ (not branch(t,br)) = 0 ;

        option bratio = 1 ;
        vSPD_BranchFlowMIP.Optfile = 1 ;
        vSPD_BranchFlowMIP.optcr = MIPOptimality ;
        vSPD_BranchFlowMIP.reslim = MIPTimeLimit ;
        vSPD_BranchFlowMIP.iterlim = MIPIterationLimit ;
        solve vSPD_BranchFlowMIP using mip maximizing NETBENEFIT ;
*       Set the model solve status
        ModelSolved = 1 $ { [ ( vSPD_BranchFlowMIP.modelstat = 1) or
                              (vSPD_BranchFlowMIP.modelstat = 8)
                            ]
                            and
                            [ vSPD_BranchFlowMIP.solvestat = 1 ]
                          } ;

*       Post a progress message for use by EMI.
        if(ModelSolved = 1,

*           TN - Replacing invalid prices after SOS1 - Flag to show the period that required SOS1 solve
            SOS1_solve(t)  = yes;

            loop(t,
                putclose rep 'The case: %GDXname% (' t.tl ') '
                             'is 1st solved successfully for branch integer.'/
                             'Objective function value: '
                             NETBENEFIT.l:<15:4 /
                             'Violations cost         : '
                             TOTALPENALTYCOST.l:<15:4 /
            ) ;
        else
            loop(t,
                unsolvedDT(t) = yes;
                VSPDModel(t) = 2;
                putclose rep 'The case: %GDXname% (' t.tl ') '
                             'is 1st solved unsuccessfully for branch integer.'/
            ) ;
        ) ;
*   Solve the vSPD_BranchFlowMIP model end -------------------------------------



*   Solve the LP model and stop ------------------------------------------------
    elseif (Sum[t, VSPDModel(t)] = 2),

        if( UseShareReserve,
            option bratio = 1 ;
            vSPD_NMIR.Optfile = 1 ;
            vSPD_NMIR.optcr = MIPOptimality ;
            vSPD_NMIR.reslim = MIPTimeLimit ;
            vSPD_NMIR.iterlim = MIPIterationLimit ;
            solve vSPD_NMIR using mip maximizing NETBENEFIT ;
*           Set the model solve status
            ModelSolved = 1 $ { ( (vSPD_NMIR.modelstat = 1)
                               or (vSPD_NMIR.modelstat = 8) )
                            and ( vSPD_NMIR.solvestat = 1 ) } ;
        else
            option bratio = 1 ;
            vSPD.reslim = LPTimeLimit ;
            vSPD.iterlim = LPIterationLimit ;
            solve vSPD using lp maximizing NETBENEFIT ;
*           Set the model solve status
            ModelSolved = 1 $ { (vSPD.modelstat = 1) and (vSPD.solvestat = 1) };
        )

*       Post a progress message for use by EMI.
        if( ModelSolved = 1,
            loop(t,
                putclose rep 'The case: %GDXname% (' t.tl ')'
                                ' integer resolve was unsuccessful.' /
                                'Reverting back to linear solve and '
                                'solve successfully. ' /
                                'Objective function value: '
                                NETBENEFIT.l:<15:4 /
                                'Violations cost         : '
                                TOTALPENALTYCOST.l:<15:4 /
                                'Solution may have circulating flows '
                                'and/or non-physical losses.' /
            ) ;
        else
            loop(t,
                putclose rep 'The case: %GDXname% (' t.tl
                                ') integer solve was unsuccessful. '
                                'Reverting back to linear solve. '
                                'Linear solve unsuccessful.' /
            ) ;
        ) ;

        unsolvedDT(t) = no;

*   Solve the LP model and stop end --------------------------------------------

    ) ;
*   Solve the models end



*   6e. Check if the LP results are valid --------------------------------------
    if((ModelSolved = 1),
        useBranchFlowMIP(t) = 0 ;
*       Check if there is no branch circular flow and non-physical losses
        Loop( t $ (VSPDModel(t)=0) ,

*           Check if there are circulating branch flows on loss AC branches
            circularBranchFlowExist(ACbranch(t,br))
                $ { LossBranch(ACbranch) and
                    [ ( sum[ fd, ACBRANCHFLOWDIRECTED.l(ACbranch,fd) ]
                      - abs(ACBRANCHFLOW.l(ACbranch))
                      ) > circularBranchFlowTolerance
                    ]
                  } = 1 ;

*           Determine the circular branch flow flag on each HVDC pole
            TotalHVDCpoleFlow(t,pole)
                = sum[ br $ HVDCpoleBranchMap(pole,br)
                     , HVDCLINKFLOW.l(t,br) ] ;

            MaxHVDCpoleFlow(t,pole)
                = smax[ br $ HVDCpoleBranchMap(pole,br)
                      , HVDCLINKFLOW.l(t,br) ] ;

            poleCircularBranchFlowExist(t,pole)
                $ { ( TotalHVDCpoleFlow(t,pole)
                    - MaxHVDCpoleFlow(t,pole)
                    ) > circularBranchFlowTolerance
                  } = 1 ;

*           Check if there are circulating branch flows on HVDC
            NorthHVDC(t)
                = sum[ (isl,b,br) $ { (ord(isl) = 2) and
                                      busIsland(t,b,isl) and
                                      HVDClinkSendingBus(t,br,b) and
                                      HVDClink(t,br)
                                    }, HVDCLINKFLOW.l(t,br)
                     ] ;

            SouthHVDC(t)
                = sum[ (isl,b,br) $ { (ord(isl) = 1) and
                                      busIsland(t,b,isl) and
                                      HVDClinkSendingBus(t,br,b) and
                                      HVDClink(t,br)
                                    }, HVDCLINKFLOW.l(t,br)
                     ] ;

            circularBranchFlowExist(t,br)
                $ { HVDClink(t,br) and LossBranch(t,br) and
                   (NorthHVDC(t) > circularBranchFlowTolerance) and
                   (SouthHVDC(t) > circularBranchFlowTolerance)
                  } = 1 ;

*           Check if there are non-physical losses on HVDC links
            ManualBranchSegmentMWFlow(LossBranch(HVDClink(t,br)),los,fd)
                $ { ( ord(los) <= branchLossBlocks(HVDClink) )
                and validLossSegment(t,br,los,fd) }
                = Min[ Max( 0,
                            [ abs(HVDCLINKFLOW.l(HVDClink))
                            - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                            ]
                          ),
                       ( LossSegmentMW(HVDClink,los,fd)
                       - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                       )
                     ] ;

            ManualLossCalculation(LossBranch(HVDClink(t,br)))
                = sum[ (los,fd) $ validLossSegment(t,br,los,fd)
                                , LossSegmentFactor(HVDClink,los,fd)
                                * ManualBranchSegmentMWFlow(HVDClink,los,fd)
                     ] ;

            NonPhysicalLossExist(LossBranch(HVDClink(t,br)))
                $ { abs( HVDCLINKLOSSES.l(HVDClink)
                       - ManualLossCalculation(HVDClink)
                       ) > NonPhysicalLossTolerance
                  } = 1 ;

*           Set UseBranchFlowMIP = 1 if the number of circular branch flow
*           and non-physical loss branches exceeds the specified tolerance
            useBranchFlowMIP(t)
                $ { ( sum[ br $ { ACbranch(t,br) and LossBranch(t,br) }
                              , resolveCircularBranchFlows
                              * circularBranchFlowExist(t,br)
                         ]
                    + sum[ br $ { HVDClink(t,br) and LossBranch(t,br) }
                              , resolveCircularBranchFlows
                              * circularBranchFlowExist(t,br)
                              + resolveHVDCnonPhysicalLosses
                              * NonPhysicalLossExist(t,br)
                         ]
                    + sum[ pole, resolveCircularBranchFlows
                               * poleCircularBranchFlowExist(t,pole)
                         ]
                     ) > UseBranchFlowMIPTolerance
                  } = 1 ;

*       Check if there is no branch circular flow and non-physical losses end
        );

*       A period is unsolved if MILP model is required
        unsolvedDT(t) = yes $ UseBranchFlowMIP(t) ;

*       Post a progress message for use by EMI. Reverting to the sequential mode for integer resolves.
        loop( unsolvedDT(t),
            if( UseBranchFlowMIP(t) >= 1,
                VSPDModel(t) = 1;
                putclose rep 'The case: %GDXname% requires a '
                             'vSPD_BranchFlowMIP resolve for period '
                             t.tl '. Switching Vectorisation OFF.'/
            ) ;

        ) ;

        sequentialSolve $ Sum[ unsolvedDT(t), 1 ] = 1 ;
        exitLoop = 1 $ Sum[ unsolvedDT(t), 1 ];

*   Check if the LP results are valid end
    ) ;

* End of the solve vSPD loop
  ] ;
* End of the While loop
);


* Real Time Pricing - Second RTD load calculation

*   Calculate Island-level MW losses used to calculate the Island-level load
*   forecast from the InputIPS and the IslandPSD.
*   2nd solve loop --> SystemLosses as calculated in section 8.1'
    LoadCalcLosses(t,isl)
        = Sum[ (br,frB,toB)
             $ { ACbranch(t,br) and busIsland(t,toB,isl)
             and branchBusDefn(t,br,frB,toB)
               }, sum[ fd, ACBRANCHLOSSESDIRECTED.l(t,br,fd) ]
                + branchFixedLoss(t,br)
             ]

        + Sum[ (br,frB,toB) $ { HVDClink(t,br) and
                                branchBusDefn(t,br,frB,toB) and
                                ( busIsland(t,toB,isl) or
                                  busIsland(t,frB,isl)
                                )
                              }, 0.5 * branchFixedLoss(t,br)
             ]
        + Sum[ (br,frB,toB) $ { HVDClink(t,br) and
                                branchBusDefn(t,br,frB,toB) and
                                busIsland(t,toB,isl) and
                                (not (busIsland(t,frB,isl)))
                              }, HVDCLINKLOSSES.l(t,br)
             ]
          ;

*   Check if vSPD LoadCalcLosses = SPD LoadCalcLosses
*   if not, let's just use SPD LoadCalcLosses
    loop ( (t,isl),
        if ( ( SPDLoadCalcLosses(t,isl) > 0 )
         and ( abs( SPDLoadCalcLosses(t,isl)-LoadCalcLosses(t,isl) )>0.001 ) ,

            putclose rep 'Recalulated losses for ' isl.tl ' are different '
                         'between vSPD (' LoadCalcLosses(t,isl):<7:4
                         ') and SPD (' SPDLoadCalcLosses(t,isl):<7:4
                         '). We use SPD number instead' / ;
           LoadCalcLosses(t,isl) = SPDLoadCalcLosses(t,isl) ;

        );
    );


*   Calculate first target total load [4.10.6.5]
*   Island-level MW load forecast. For the second loop:
*   replace LoadCalcLosses(tp,isl) = islandLosses(tp,isl);
    TargetTotalLoad(t,isl) = islandMWIPS(t,isl)
                           + islandPDS(t,isl)
                           - LoadCalcLosses(t,isl) ;

*   Flag if estimate load is scalable [4.10.6.7]
*   Binary value. If True then ConformingFactor load MW will be scaled in order to
*   calculate EstimatedInitialLoad. If False then EstNonScalableLoad will be
*   assigned directly to EstimatedInitialLoad
    EstLoadIsScalable(t,n) =  1 $ { (LoadIsNCL(t,n) = 0)
                                     and (ConformingFactor(t,n) > 0) } ;

*   Calculate estimate non-scalable load 4.10.6.8]
*   For a non-conforming Pnode this will be the NonConformingLoad MW input, for a
*   conforming Pnode this will be the ConformingFactor MW input if that value is
*   negative, otherwise it will be zero
    EstNonScalableLoad(t,n) $ ( LoadIsNCL(t,n) = 1 ) = NonConformingLoad(t,n);
    EstNonScalableLoad(t,n) $ ( LoadIsNCL(t,n) = 0 ) = ConformingFactor(t,n);
    EstNonScalableLoad(t,n) $ ( EstLoadIsScalable(t,n) = 1 ) = 0;

*   Calculate estimate scalable load [4.10.6.10]
*   For a non-conforming Pnode this value will be zero. For a conforming Pnode
*   this value will be the ConformingFactor if it is non-negative, otherwise this
*   value will be zero'
    EstScalableLoad(t,n) $ ( EstLoadIsScalable(t,n) = 1 ) = ConformingFactor(t,n);


*   Calculate Scaling applied to ConformingFactor load MW [4.10.6.9]
*   in order to calculate EstimatedInitialLoad
    EstScalingFactor(t,isl)
        = (islandMWIPS(t,isl) - LoadCalcLosses(t,isl)
          - Sum[ n $ nodeIsland(t,n,isl), EstNonScalableLoad(t,n) ]
          ) / Sum[ n $ nodeIsland(t,n,isl), EstScalableLoad(t,n) ]

        ;

*   Calculate estimate initial load [4.10.6.6]
*   Calculated estimate of initial MW load, available to be used as an
*   alternative to InputInitialLoad
    EstimatedInitialLoad(t,n) $ ( EstLoadIsScalable(t,n) = 1 )
        = ConformingFactor(t,n) * Sum[ isl $ nodeisland(t,n,isl)
                                          , EstScalingFactor(t,isl)] ;
* TN- There is a bug in this equarion
    EstimatedInitialLoad(t,n) $ ( EstLoadIsScalable(t,n) = 0 )
*        = NonConformingLoad(t,n);
        = EstNonScalableLoad(t,n);

*   Calculate initial load [4.10.6.2]
*   Value that represents the Pnode load MW at the start of the solution
*   interval. Depending on the inputs this value will be either actual load,
*   an operator applied override or an estimated initial load
    InitialLoad(t,n) = InputInitialLoad(t,n);
    InitialLoad(t,n) $ { (LoadIsOverride(t,n) = 0)
                          and ( (useActualLoad(t) = 0)
                             or (LoadIsBad(t,n) = 1) )
                            } = EstimatedInitialLoad(t,n) ;

*   Flag if load is scalable [4.10.6.4]
*   Binary value. If True then the Pnode InitialLoad will be scaled in order to
*   calculate RequiredLoad, if False then Pnode InitialLoad will be directly
*   assigned to RequiredLoad
    LoadIsScalable(t,n) = 1 $ { (LoadIsNCL(t,n) = 0)
                                 and (LoadIsOverride(t,n) = 0)
                                 and (InitialLoad(t,n) >= 0) } ;

*   Calculate Island-level scaling factor [4.10.6.3]
*   --> applied to InitialLoad in order to calculate RequiredLoad
    LoadScalingFactor(t,isl)
        = ( TargetTotalLoad(t,isl)
          - Sum[ n $ { nodeIsland(t,n,isl)
                   and (LoadIsScalable(t,n) = 0) }, InitialLoad(t,n) ]
          ) / Sum[ n $ { nodeIsland(t,n,isl)
                     and (LoadIsScalable(t,n) = 1) }, InitialLoad(t,n) ]
        ;

*   Calculate RequiredLoad [4.10.6.1]
    RequiredLoad(t,n) $ LoadIsScalable(t,n)
        = InitialLoad(t,n) * sum[ isl $ nodeisland(t,n,isl)
                                 , LoadScalingFactor(t,isl) ];

    RequiredLoad(t,n) $ (LoadIsScalable(t,n) = 0) = InitialLoad(t,n);

    RequiredLoad(t,n) = RequiredLoad(t,n)
                     + [instructedloadshed(t,n) $ instructedshedactive(t,n)] ;


* Recalculate energy scarcity limits -------------------------------------------
ScarcityEnrgLimit(t,n,blk) = 0 ;

ScarcityEnrgLimit(t,n,blk) $ energyScarcityEnabled(t)
    = scarcityEnrgNodeLimit(t,n,blk);

ScarcityEnrgLimit(t,n,blk)
    $ { energyScarcityEnabled(t)
    and (sum[blk1, ScarcityEnrgLimit(t,n,blk1)] = 0 )
    and (RequiredLoad(t,n) > 0)
      }
    = scarcityEnrgNodeFactor(t,n,blk) * RequiredLoad(t,n);

ScarcityEnrgLimit(t,n,blk)
    $ { energyScarcityEnabled(t)
    and (sum[blk1, ScarcityEnrgLimit(t,n,blk1)] = 0 )
    and (RequiredLoad(t,n) > 0)
      }
    = scarcityEnrgNationalFactor(t,blk) * RequiredLoad(t,n);
*-------------------------------------------------------------------------------



*   Update Free Reserve and SharedNFRmax
*   Pre-processing: Shared Net Free Reserve (NFR) calculation - NMIR (4.5.1.2)
    sharedNFRLoad(t,isl)
        = sum[ nodeIsland(t,n,isl), RequiredLoad(t,n)]
        + sum[ (bd,blk) $ bidIsland(t,bd,isl), DemBidMW(t,bd,blk) ]
        - sharedNFRLoadOffset(t,isl) ;

    sharedNFRMax(t,isl) = Min{ RMTReserveLimitTo(t,isl,'FIR'),
                               sharedNFRFactor(t)*sharedNFRLoad(t,isl) } ;

*   Risk parameters
    FreeReserve(t,isl,resC,riskC)
        = riskParameter(t,isl,resC,riskC,'freeReserve')
*   NMIR - Subtract shareNFRMax from current NFR -(5.2.1.4) - SPD version 11
        - sum[ isl1 $ (not sameas(isl,isl1)),sharedNFRMax(t,isl1)
             ] $ { (ord(resC)=1) and ( (GenRisk(riskC)) or (ManualRisk(riskC)) )
               and (inputGDXGDate >= jdate(2016,10,20)) }
    ;

*   6.5.2.3 Total shared NFR is capped by shared NFR max
    SHAREDNFR.up(t,isl) = Max[0,sharedNFRMax(t,isl)] ;

*);



