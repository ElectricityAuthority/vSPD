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
DidShortfallTransfer(dt,n) = 0;
ShortfallDisabledScaling(dt,n) = 0;
CheckedNodeCandidate(dt,n) = 0;
$ontext
* Check Potential for Modelling Inconsistency (7.2.3.i&j)
The potential for a modelling inconsistency exists because while planned outages
are incorporated in the Network Model they are not necessarily reflected in the
forecast load. The Shortfall Check detects a modelling inconsistency if the
shortfall node has an associated ACLine in SHORTFALLACLINES and this ACLine is
removed from the model.
$offtext
PotentialModellingInconsistency(dt,n)= 1 $ { sum[ branch(dt,br) $ nodeoutagebranch(dt,n,br), 1] < sum[ br $ nodeoutagebranch(dt,n,br), 1] } ;

put_utility temp 'gdxin' / '%inputPath%\%GDXname%.gdx' ;
execute_load SPDLoadCalcLosses = i_dateTimeSPDLoadCalcLosses  ;
put_utility temp 'gdxin' ;

unsolvedDT(dt) = yes;
VSPDModel(dt) = 0 ;
LoopCount(dt) = 1;

*While ( Sum[ dt $ unsolvedDT(dt), 1],

While ( Sum[ dt $ { unsolvedDT(dt) and (LoopCount(dt) < maxSolveLoops(dt)) }, 1],
  loop[ dt $ { unsolvedDT(dt) and (LoopCount(dt) < maxSolveLoops(dt)) },
*  loop[ dt $ { unsolvedDT(dt) },

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
*   End reset


*   7b. Initialise current trade period and model data -------------------------
    t(dt)  = yes;

*   Update initial MW if run NRSS, PRSS, NRSL, PRSL
    generationStart(offer(t(dt),o)) $ { sum[ o1, generationStart(dt,o1)] = 0 } = sum[ dt1 $ (ord(dt1) = ord(dt)-1), o_offerEnergy_TP(dt1,o) ] ;


*   7c. Updating the variable bounds before model solve ------------------------

*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS ========================
*   Constraint 6.1.1.1 - Offer blocks
    GENERATIONBLOCK.up(genOfrBlk(t,o,blk)) = EnrgOfrMW(genOfrBlk) ;
    GENERATIONBLOCK.fx(t,o,blk) $ (not genOfrBlk(t,o,blk)) = 0 ;
*   Constraint 6.1.1.2 - Fix the invalid generation to Zero
    GENERATION.fx(offer(t,o)) $ (not posEnrgOfr(offer)) = 0 ;
*   Constraint 6.1.1.3 - Set Upper Bound for intermittent generation
    GENERATION.up(offer(t,o)) $ { windOffer(offer) and priceResponsive(offer) } = min[ potentialMW(offer), ReserveGenerationMaximum(offer) ] ;

*   Constraint 6.1.1.4 & Constraint 6.1.1.5 - Set Upper/Lower Bound for Positive/Negative Demand Bid
    PURCHASEBLOCK.up(demBidBlk(t,bd,blk)) = DemBidMW(t,bd,blk) $ [DemBidMW(t,bd,blk) > 0];
    PURCHASEBLOCK.lo(demBidBlk(t,bd,blk)) = DemBidMW(t,bd,blk) $ [DemBidMW(t,bd,blk) < 0];
    PURCHASEBLOCK.fx(t,bd,blk) $ (not demBidBlk(t,bd,blk))= 0 ;
    PURCHASE.fx(t,bd) $ (sum[blk $ demBidBlk(t,bd,blk), 1] = 0) = 0 ;

*   Constraint 6.1.1.7 - Set Upper Bound for Energy Scaricty Block
    ENERGYSCARCITYBLK.up(t,n,blk) = ScarcityEnrgLimit(t,n,blk) ;
    ENERGYSCARCITYBLK.fx(t,n,blk) $ (not EnergyScarcityEnabled(t)) = 0;
    ENERGYSCARCITYNODE.fx(t,n) $ (not EnergyScarcityEnabled(t)) = 0;
*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS END ====================

*======= HVDC TRANSMISSION EQUATIONS ===========================================
*   Ensure that variables used to specify flow and losses on HVDC link are zero for AC branches and for open HVDC links.
    HVDCLINKFLOW.fx(t,br)   $ (not HVDClink(t,br)) = 0 ;
    HVDCLINKLOSSES.fx(t,br) $ (not HVDClink(t,br)) = 0 ;
*   Apply an upper bound on the weighting parameter based on its definition
    LAMBDA.up(branch,bp) = 1 ;
*   Ensure that the weighting factor value is zero for AC branches and for invalid loss segments on HVDC links
    LAMBDA.fx(HVDClink,bp) $ ( sum[fd $ validLossSegment(HVDClink,bp,fd),1] = 0 ) = 0 ;
    LAMBDA.fx(t,br,bp) $ (not HVDClink(t,br)) = 0 ;
*======= HVDC TRANSMISSION EQUATIONS END =======================================

*======= AC TRANSMISSION EQUATIONS =============================================
*   Ensure that variables used to specify flow and losses on AC branches are zero for HVDC links branches and for open AC branches.
    ACBRANCHFLOW.fx(t,br)              $ (not ACbranch(t,br)) = 0 ;
    ACBRANCHFLOWDIRECTED.fx(t,br,fd)   $ (not ACbranch(t,br)) = 0 ;
    ACBRANCHLOSSESDIRECTED.fx(t,br,fd) $ (not ACbranch(t,br)) = 0 ;
*   Ensure directed block flow and loss block variables are zero for non-AC branches and invalid loss segments on AC branches.
    ACBRANCHFLOWBLOCKDIRECTED.fx(t,br,los,fd)   $ { not(ACbranch(t,br) and validLossSegment(t,br,los,fd)) } = 0 ;
    ACBRANCHLOSSESBLOCKDIRECTED.fx(t,br,los,fd) $ { not(ACbranch(t,br) and validLossSegment(t,br,los,fd)) } = 0 ;
*   Constraint 6.4.1.10 - Ensure that the bus voltage angle for the buses corresponding to the reference nodes and the HVDC nodes are set to zero.
    ACNODEANGLE.fx(t,b) $ sum[ n $ { NodeBus(t,n,b) and refNode(t,n) }, 1 ] = 0 ;
*======= AC TRANSMISSION EQUATIONS END =========================================

*======= RISK & RESERVE EQUATIONS ==============================================
*   Ensure that all the invalid reserve blocks are set to zero for offers and purchasers.
    RESERVEBLOCK.fx(offer(t,o),blk,resC,resT) $ (not resOfrBlk(offer,blk,resC,resT)) = 0 ;
*   Constraint 6.5.3.2 - Reserve block maximum for offers and purchasers.
    RESERVEBLOCK.up(resOfrBlk(t,o,blk,resC,resT)) = ResOfrMW(resOfrBlk) ;
*   Fix the reserve variable for invalid reserve offers. These are offers that are either not connected to the grid or have no reserve quantity offered.
    RESERVE.fx(t,o,resC,resT) $ (not sum[ blk $ resOfrBlk(t,o,blk,resC,resT), 1 ] ) = 0 ;
*   NMIR project variables
    HVDCSENT.fx(t,isl)     $ (HVDCCapacity(t,isl) = 0) = 0 ;
    HVDCSENTLOSS.fx(t,isl) $ (HVDCCapacity(t,isl) = 0) = 0 ;
*   Constraint 6.5.3.2.3 - SPD version 12.0
    SHAREDNFR.up(t,isl) = Max[0,sharedNFRMax(t,isl)] ;
*   No forward reserve sharing if HVDC capacity is zero
    RESERVESHARESENT.fx(t,isl,resC,rd) $ { (HVDCCapacity(t,isl) = 0) and (ord(rd) = 1) } = 0 ;
*   No forward reserve sharing if reserve sharing is disabled
    RESERVESHARESENT.fx(t,isl,resC,rd) $ (reserveShareEnabled(t,resC) = 0) = 0;
*   No reserve sharing to cover HVDC risk
    RESERVESHAREEFFECTIVE.fx(t,isl,resC,HVDCrisk) = 0;
    RESERVESHAREEFFECTIVE.fx(t,isl,resC,HVDCsecRisk) = 0;
*   Constraint 6.5.2.16 - no RP zone if reserve round power disabled
    INZONE.fx(t,isl,resC,z) $ {(ord(z) = 1) and (not reserveRoundPower(t,resC))} = 0;
*   Constraint 6.5.2.17 - no no-reserve zone for SIR zone if reserve RP enabled
    INZONE.fx(t,isl,resC,z) $ {(ord(resC)=2) and (ord(z)=2) and reserveRoundPower(t,resC)} = 0;
*   Fixing Lambda integer variable for energy sent
    LAMBDAHVDCENERGY.fx(t,isl,bp) $ { (HVDCCapacity(t,isl) = 0) and (ord(bp) = 1) } = 1 ;
    LAMBDAHVDCENERGY.fx(t,isl,bp) $ (ord(bp) > 7) = 0 ;
* To be reviewed NMIR ???
    LAMBDAHVDCRESERVE.fx(t,isl,resC,rd,rsbp) $ { (HVDCCapacity(t,isl) = 0) and (ord(rsbp) = 7) and (ord(rd) = 1) } = 1 ;
    LAMBDAHVDCRESERVE.fx(t,isl,resC,rd,rsbp) $ { (sum[isl1 $ (not sameas(isl1,isl)), HVDCCapacity(t,isl1)] = 0) and (ord(rsbp) < 7) and (ord(rd) = 2) } = 0 ;
*   Contraint 6.5.4.1 - Set Upper Bound for reserve shortfall
    RESERVESHORTFALLBLK.up(t,isl,resC,riskC,blk)         = scarcityResrvIslandLimit(t,isl,resC,blk) $ reserveScarcityEnabled(t);
    RESERVESHORTFALLBLK.fx(t,isl,resC,riskC,blk)         $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALL.fx(t,isl,resC,riskC)                $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALLUNITBLK.up(t,isl,o,resC,riskC,blk)   = scarcityResrvIslandLimit(t,isl,resC,blk) $ reserveScarcityEnabled(t);
    RESERVESHORTFALLUNITBLK.fx(t,isl,o,resC,riskC,blk)   $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALLUNIT.fx(t,isl,o,resC,riskC)          $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALLGROUPBLK.up(t,isl,rg,resC,riskC,blk) = scarcityResrvIslandLimit(t,isl,resC,blk) $ reserveScarcityEnabled(t);
    RESERVESHORTFALLGROUPBLK.fx(t,isl,rg,resC,riskC,blk) $ (not reserveScarcityEnabled(t)) = 0;
    RESERVESHORTFALLGROUP.fx(t,isl,rg,resC,riskC)        $ (not reserveScarcityEnabled(t)) = 0;
;
*======= RISK & RESERVE EQUATIONS END ==========================================

*   Updating the variable bounds before model solve end

*   7d. Solve Models

*   Solve the NMIR model ---------------------------------------------------------
    if( (Sum[t, VSPDModel(t)] = 0),

        option bratio = 1 ;
        vSPD_NMIR.Optfile = 1 ;
        vSPD_NMIR.optcr = MIPOptimality ;
        vSPD_NMIR.reslim = MIPTimeLimit ;
        vSPD_NMIR.iterlim = MIPIterationLimit ;
        solve vSPD_NMIR using mip maximizing NETBENEFIT ;
*       Set the model solve status
        ModelSolved = 1 $ { ( (vSPD_NMIR.modelstat = 1) or (vSPD_NMIR.modelstat = 8) ) and ( vSPD_NMIR.solvestat = 1 ) } ;

*       Post a progress message to the console and for use by EMI.
        if((ModelSolved = 1),
            loop(t,
                putclose rep 'The case: %GDXname% (' t.tl ') is 1st solved successfully.'/
                             'Objective function value: ' NETBENEFIT.l:<15:4 /
                             'Violations cost         : ' TOTALPENALTYCOST.l:<15:4 /
            ) ;
        elseif((ModelSolved = 0) and (sequentialSolve = 1)),
            loop(t,
                unsolvedDT(t) = no;
                putclose rep 'The case: %GDXname% (' t.tl ') is 1st solved unsuccessfully.'/
            ) ;

        ) ;
*   Solve the NMIR model end -----------------------------------------------------

*   Solve the vSPD_BranchFlowMIP -----------------------------------------------
    elseif (Sum[t, VSPDModel(t)] = 1),
        useBranchFlowMIP(t) = 1 ;
*       Fix the values of these integer variables that are not needed
        ACBRANCHFLOWDIRECTED_INTEGER.fx(branch(t,br),fd) $ { (not ACbranch(t,br)) or (not LossBranch(branch)) } = 0 ;
*       Fix the integer AC branch flow variable to zero for invalid branches
        ACBRANCHFLOWDIRECTED_INTEGER.fx(t,br,fd) $ (not branch(t,br)) = 0 ;
*       Apply an upper bound on the integer weighting parameter
        LAMBDAINTEGER.up(branch(t,br),bp) = 1 ;
*       Ensure that the weighting factor value is zero for AC branches and for invalid loss segments on HVDC links
        LAMBDAINTEGER.fx(branch(t,br),bp) $ { ACbranch(branch) or ( sum[fd $ validLossSegment(branch,bp,fd),1 ] = 0 ) } = 0 ;
*       Fix the lambda integer variable to zero for invalid branches
        LAMBDAINTEGER.fx(t,br,bp) $ (not branch(t,br)) = 0 ;

        option bratio = 1 ;
        vSPD_BranchFlowMIP.Optfile = 1 ;
        vSPD_BranchFlowMIP.optcr = MIPOptimality ;
        vSPD_BranchFlowMIP.reslim = MIPTimeLimit ;
        vSPD_BranchFlowMIP.iterlim = MIPIterationLimit ;
        solve vSPD_BranchFlowMIP using mip maximizing NETBENEFIT ;
*       Set the model solve status
        ModelSolved = 1 $ { [ ( vSPD_BranchFlowMIP.modelstat = 1) or (vSPD_BranchFlowMIP.modelstat = 8) ] and [ vSPD_BranchFlowMIP.solvestat = 1 ] } ;

*       Post a progress message for use by EMI.
        if(ModelSolved = 1,
*           Flag to show the period that required SOS1 solve
            SOS1_solve(t)  = yes;
            loop(t,
                putclose rep 'The case: %GDXname% (' t.tl ') is 1st solved successfully for branch integer.'/
                             'Objective function value: ' NETBENEFIT.l:<15:4 /
                             'Violations cost         : ' TOTALPENALTYCOST.l:<15:4 /
            ) ;
        else
            loop(t,
                unsolvedDT(t) = yes;
                VSPDModel(t) = 2;
                putclose rep 'The case: %GDXname% (' t.tl ') is 1st solved unsuccessfully for branch integer.'/
            ) ;
        ) ;
*   Solve the vSPD_BranchFlowMIP model end -------------------------------------

*   ReSolve the NMIR model and stop --------------------------------------------
    elseif (Sum[t, VSPDModel(t)] = 2),

        option bratio = 1 ;
        vSPD_NMIR.Optfile = 1 ;
        vSPD_NMIR.optcr = MIPOptimality ;
        vSPD_NMIR.reslim = MIPTimeLimit ;
        vSPD_NMIR.iterlim = MIPIterationLimit ;
        solve vSPD_NMIR using mip maximizing NETBENEFIT ;
*       Set the model solve status
        ModelSolved = 1 $ { ( (vSPD_NMIR.modelstat = 1) or (vSPD_NMIR.modelstat = 8) ) and ( vSPD_NMIR.solvestat = 1 ) } ;

*       Post a progress message for use by EMI.
        if( ModelSolved = 1,
            loop(t,
                putclose rep 'The case: %GDXname% (' t.tl ') branch flow integer resolve was unsuccessful.' /
                                'Reverting back to base model (NMIR) and solve successfully. ' /
                                'Objective function value: ' NETBENEFIT.l:<15:4 /
                                'Violations cost         : '  TOTALPENALTYCOST.l:<15:4 /
                                'Solution may have circulating flows and/or non-physical losses.' /
            ) ;
        else
            loop(t,
                putclose rep 'The case: %GDXname% (' t.tl') integer solve was unsuccessful. Reverting back to base model (NMIR) and solve unsuccessfully.' /
            ) ;
        ) ;

        unsolvedDT(t) = no;

*   ReSolve the NMIR model and stop end ----------------------------------------

    ) ;
*   Solve the models end


*   Post-Solve Checks
*   6e. Circulating Flow and Non-Physical Loss (HVDC only) Check ---------------
    if((ModelSolved = 1),
        useBranchFlowMIP(t) = 0 ;
*       Check if there is no branch circular flow and non-physical losses
        Loop( t $ (VSPDModel(t)=0) ,

*           Check if there are circulating branch flows on loss AC branches
            circularBranchFlowExist(LossBranch(ACbranch(t,br))) $ { sum[fd, ACBRANCHFLOWDIRECTED.l(ACbranch,fd)] - abs(ACBRANCHFLOW.l(ACbranch)) > circularBranchFlowTolerance } = 1 ;

*           Determine the circular branch flow flag on each HVDC pole
            TotalHVDCpoleFlow(t,pole) = sum[ br $ HVDCpoleBranchMap(pole,br), HVDCLINKFLOW.l(t,br) ] ;
            MaxHVDCpoleFlow(t,pole) = smax[ br $ HVDCpoleBranchMap(pole,br), HVDCLINKFLOW.l(t,br) ] ;
            poleCircularBranchFlowExist(t,pole) $ { TotalHVDCpoleFlow(t,pole) - MaxHVDCpoleFlow(t,pole) > circularBranchFlowTolerance } = 1 ;

*           Check if there are circulating branch flows on HVDC
            NorthHVDC(t) = sum[ (isl,b,br) $ { (ord(isl) = 2) and busIsland(t,b,isl) and HVDClinkSendingBus(t,br,b) and HVDClink(t,br) }, HVDCLINKFLOW.l(t,br) ] ;
            SouthHVDC(t) = sum[ (isl,b,br) $ { (ord(isl) = 1) and busIsland(t,b,isl) and HVDClinkSendingBus(t,br,b) and HVDClink(t,br) }, HVDCLINKFLOW.l(t,br) ] ;
            circularBranchFlowExist(t,br) $ { HVDClink(t,br) and LossBranch(t,br) and (NorthHVDC(t) > circularBranchFlowTolerance) and (SouthHVDC(t) > circularBranchFlowTolerance) } = 1 ;

*           Check if there are non-physical losses on HVDC links
            ManualBranchSegmentMWFlow(LossBranch(HVDClink(t,br)),los,fd) $ { ( ord(los) <= branchLossBlocks(HVDClink) ) and validLossSegment(t,br,los,fd) }
                = Min[ Max( 0, [ abs(HVDCLINKFLOW.l(HVDClink)) - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)] ] ), ( LossSegmentMW(HVDClink,los,fd) - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)] ) ] ;

            ManualLossCalculation(LossBranch(HVDClink(t,br))) = sum[ (los,fd) $ validLossSegment(t,br,los,fd), LossSegmentFactor(HVDClink,los,fd) * ManualBranchSegmentMWFlow(HVDClink,los,fd) ] ;
            NonPhysicalLossExist(LossBranch(HVDClink(t,br))) $ { abs( HVDCLINKLOSSES.l(HVDClink) - ManualLossCalculation(HVDClink) ) > NonPhysicalLossTolerance } = 1 ;

*           Set UseBranchFlowMIP = 1 if the number of circular branch flow or non-physical loss branches exceeds the specified tolerance
            useBranchFlowMIP(t) $ { ( sum[ br $ { ACbranch(t,br) and LossBranch(t,br) }, resolveCircularBranchFlows * circularBranchFlowExist(t,br)]
                                    + sum[ br $ { HVDClink(t,br) and LossBranch(t,br) }, resolveCircularBranchFlows * circularBranchFlowExist(t,br)]
                                    + sum[ br $ { HVDClink(t,br) and LossBranch(t,br) }, resolveHVDCnonPhysicalLosses * NonPhysicalLossExist(t,br) ]
                                    + sum[ pole, resolveCircularBranchFlows * poleCircularBranchFlowExist(t,pole)]
                                    ) > UseBranchFlowMIPTolerance
                                  } = 1 ;
        );
*       Check if there is no branch circular flow and non-physical losses end

*       A period is unsolved if MILP model is required
        unsolvedDT(t) = yes $ UseBranchFlowMIP(t) ;

*       Post a progress message for use by EMI. Reverting to the sequential mode for integer resolves.
        loop( unsolvedDT(t),
            if( UseBranchFlowMIP(t) >= 1,
                VSPDModel(t) = 1;
                putclose rep 'The case: %GDXname% requires a vSPD_BranchFlowMIP resolve for period ' t.tl '.'/
            ) ;

        );

    ) ;
*   Check if the NMIR results are valid end


*   Energy Shortfall Check (7.2)
   if( (runEnrgShortfallTransfer(dt) = 1),

*       Check for disconnected buses and dead nodes
        busLoad(bus(t,b)) = sum[ NodeBus(t,n,b), RequiredLoad(t,n) * NodeBusAllocationFactor(t,n,b) ] ;
        busDisconnected(bus(t,b)) $ { ( [busElectricalIsland(bus) = 0] and [busLoad(bus) = 0] )
                                    or ( sum[ b1 $ { busElectricalIsland(t,b1) = busElectricalIsland(bus) } , busLoad(t,b1) ] = 0 )
                                     } = 1 ;
        IsNodeDead(t,n) = 1 $ ( sum[b $ { NodeBus(t,n,b) and (busDisconnected(t,b)=0) }, NodeBusAllocationFactor(t,n,b) ] = 0 ) ;
        IsNodeDead(t,n) $ ( sum[b $ NodeBus(t,n,b), busElectricalIsland(t,b) ] = 0 ) = 1 ;
        NodeElectricalIsland(t,n) = smin[b $ NodeBus(t,n,b), busElectricalIsland(t,b)] ;

*       Check if a pnode has energy shortfall
        EnergyShortfallMW(t,n) $ Node(t,n) = ENERGYSCARCITYNODE.l(t,n) + sum[ b $ NodeBus(t,n,b), busNodeAllocationFactor(t,b,n) * DEFICITBUSGENERATION.l(t,b) ] ;
        OPTION EnergyShortfallMW:5:1:1;
        Display EnergyShortfallMW;
*       a.Checkable Energy Shortfall:
*       If a node has an EnergyShortfallMW greater than zero and the node has LoadIsOverride set to False and the Pnode has InstructedShedActivepn set to False, then EnergyShortfall is checked.
        EnergyShortFallCheck(t,n) $ { (EnergyShortfallMW(t,n) > 0) and (LoadIsOverride(t,n) = 0) and (instructedShedActive(t,n) = 0) } = 1 ;

*       c. Eligible for Removal:
*       An EnergyShortfall is eligible for removal if there is evidence that it is due to a modelling inconsistency (as described below),
*       or if the RTD Required Load calculation used an estimated initial load rather than an actual initial load, or if the node is dead node.
        EligibleShortfallRemoval(t,n) $ EnergyShortFallCheck(t,n) = 1 $ { PotentialModellingInconsistency(t,n) or (useActualLoad(t) = 0) or (LoadIsBad(t,n) = 1) or (IsNodeDead(t,n) = 1) } ;

*       d. Shortfall Removal:
*       If the shortfall at a node is eligible for removal then a Shortfall Adjustment quantity is subtracted from the RequiredLoad in order to remove the shortfall.
*       If the node is dead node then the Shortfall Adjustment is equal to EnergyShortfallMW otherwise it's equal to EnergyShortfall plus EnergyShortfallRemovalMargin.
*       If the adjustment would make RequiredLoad negative then RequiredLoad is assigned a value of zero. The adjusted node has DidShortfallTransferpn set to True so that
*       the RTD Required Load calculation does not recalculate its RequiredLoad at this node
        display IsNodeDead;
        ShortfallAdjustmentMW(t,n) $ EligibleShortfallRemoval(t,n) = [enrgShortfallRemovalMargin(t) $ (IsNodeDead(t,n) = 0) ] + EnergyShortfallMW(t,n) ;
        OPTION ShortfallAdjustmentMW:5:1:1;
        Display ShortfallAdjustmentMW;
        RequiredLoad(t,n) $ EligibleShortfallRemoval(t,n) = RequiredLoad(t,n) - ShortfallAdjustmentMW(t,n) ;
        RequiredLoad(t,n) $ { EligibleShortfallRemoval(t,n) and (RequiredLoad(t,n) < 0) } = 0 ;
        DidShortfallTransfer(t,n) $ EligibleShortfallRemoval(t,n) = 1 ;



$ontext
e. Shortfall Transfer:
If the previous step adjusts RequiredLoad then the processing will search for a transfer target Pnode to receive the Shortfall Adjustment quantity (the search process is described below).
If a transfer target node is found then the ShortfallAdjustmentMW is added to the RequiredLoad of the transfer target node and the DidShortfallTransfer of the transfer target Pnode flag is set to True.
k. Shortfall Transfer Target:
In the Shortfall Transfer step, the search for a transfer target node proceeds as follows.
The first choice candidate for price transfer source is the PnodeTransferPnode of the target Pnode. If the candidate is ineligible then the new candidate will be the PnodeTransferPnode of the candidate,
if any, but only if this new candidate has not already been visited in this search. The process of locating and checking candidates will continue until an eligible transfer Pnode is located or until no
more candidates are found. A candidate node isn't eligible as a target if it has a non-zero EnergyShortfall in the solution being checked or had one in the solution of a previous solve loop, or if the
candidate node has LoadIsOverridepn set to True, or if the candidate node has InstructedShedActivepn set to True, or if the node with the shortfall is not in Electrical Island 0 and the ElectricalIsland
of the candidate node is not the same as the ElectricalIslandpn of the node with the shortfall, or if the candidate node is in the set of DEADPNODESpn.
$offtext
        unsolvedDT(t) = yes $ sum[n $ EligibleShortfallRemoval(t,n), ShortfallAdjustmentMW(t,n)] ;

        nodeTonode(t,n,n1) = node2node(t,n,n1)
        While ( sum[n, ShortfallAdjustmentMW(dt,n)],

*           Check if shortfall from node n is eligibly transfered to node n1
            ShortfallTransferFromTo(nodeTonode(t,n,n1))
                $ { (ShortfallAdjustmentMW(t,n) > 0) and (ShortfallAdjustmentMW(t,n1) = 0) and (CheckedNodeCandidate(t,n1) = 0)
                and (LoadIsOverride(t,n1) = 0) and (InstructedShedActive(t,n1) = 0) and (IsNodeDead(t,n1) = 0)
                and [ (NodeElectricalIsland(t,n) = NodeElectricalIsland(t,n1)) or (NodeElectricalIsland(t,n) = 0) ]
                  } = 1;

*           If a transfer target node is found then the ShortfallAdjustmentMW is added to the RequiredLoad of the transfer target node
            RequiredLoad(t,n1) = RequiredLoad(t,n1) + sum[ n $ ShortfallTransferFromTo(t,n,n1), ShortfallAdjustmentMW(t,n)] ;
*           and the DidShortfallTransfer of the transfer target node is set to 1
            DidShortfallTransfer(t,n1) $ sum[n, ShortfallTransferFromTo(t,n,n1)] = 1 ;

*           If a candidate for target node is not eligible, remap the node n to the node after node n1
            nodeTonode(t,n,n2) $ sum[n1 $ { nodeTonode(t,n,n1) and nodeTonode(t,n1,n2) and (ShortfallTransferFromTo(t,n,n1) = 0) }, 1] = yes ;
            nodeTonode(t,n,n1) $ (ShortfallTransferFromTo(t,n,n1) = 0) = no ;

*           Set ShortfallAdjustmentMW at node n to zero if shortfall can be transfered to a target node
            ShortfallAdjustmentMW(t,n) $ sum[ n1, ShortfallTransferFromTo(t,n,n1)] = 0;

        ) ;

*       f. Scaling Disabled: For an RTD schedule type, when an EnergyShortfallpn is checked but the shortfall is not eligible for removal then ShortfallDisabledScalingpn is set to True
*       which will prevent the RTD Required Load calculation from scaling InitialLoad.
        ShortfallDisabledScaling(t,n) = 1 $ { (EnergyShortFallCheck(t,n)=1) and (EligibleShortfallRemoval(t,n)=0) };

    ) ;
*   Energy Shortfall Check End

    LoopCount(t) = LoopCount(t) + 1 ;
    LoopCount(t) $ { sum[n $ EligibleShortfallRemoval(t,n), ShortfallAdjustmentMW(t,n)] = 0 } = maxSolveLoops(t);

* End of the solve vSPD loop
  ] ;
* End of the While loop
);

* Real Time Pricing - Second RTD load calculation
    putclose rep 'Recalculate RTD load calculation for second solve'/;

*   Calculate Island-level MW losses used to calculate the Island-level load
*   forecast from the InputIPS and the IslandPSD.
*   2nd solve loop --> SystemLosses as calculated in section 8.1'
    LoadCalcLosses(t,isl)= Sum[ (br,frB,toB) $ { ACbranch(t,br) and branchBusDefn(t,br,frB,toB) and busIsland(t,toB,isl) }, sum[ fd, ACBRANCHLOSSESDIRECTED.l(t,br,fd) ] + branchFixedLoss(t,br) ]
                         + Sum[ (br,frB,toB) $ { HVDClink(t,br) and branchBusDefn(t,br,frB,toB) and ( busIsland(t,toB,isl) or busIsland(t,frB,isl) ) }, 0.5 * branchFixedLoss(t,br) ]
                         + Sum[ (br,frB,toB) $ { HVDClink(t,br) and branchBusDefn(t,br,frB,toB) and busIsland(t,toB,isl) and (not (busIsland(t,frB,isl))) }, HVDCLINKLOSSES.l(t,br) ] ;

*   Check if vSPD LoadCalcLosses = SPD LoadCalcLosses. If not, let's just use SPD LoadCalcLosses. This is extra feature of vSPD in case the RTD load calculation does not match SPD for some reason.
    loop ( (t,isl),
        if ( ( SPDLoadCalcLosses(t,isl) > 0 ) and ( abs( SPDLoadCalcLosses(t,isl) - LoadCalcLosses(t,isl) ) > 0.001 ),
            putclose rep 'Recalulated losses for ' isl.tl ' are different between vSPD (' LoadCalcLosses(t,isl):<7:4 ') and SPD (' SPDLoadCalcLosses(t,isl):<7:4 '). We use SPD number instead' / ;
            LoadCalcLosses(t,isl) = SPDLoadCalcLosses(t,isl) ;
        );
    );


*   Calculate first target total load [4.10.6.5]
*   Island-level MW load forecast. For the second loop, uses LoadCalcLosses(t,isl)
    TargetTotalLoad(t,isl) = islandMWIPS(t,isl) + islandPDS(t,isl) - LoadCalcLosses(t,isl) ;

*   Flag if estimate load is scalable [4.10.6.7]
*   If True [1] then ConformingFactor load MW will be scaled in order to calculate EstimatedInitialLoad. If False then EstNonScalableLoad will be assigned directly to EstimatedInitialLoad
    EstLoadIsScalable(t,n) =  1 $ { (LoadIsNCL(t,n) = 0) and (ConformingFactor(t,n) > 0) } ;

*   Calculate estimate non-scalable load 4.10.6.8]
*   For a non-conforming Pnode this will be the NonConformingLoad MW input, for a conforming Pnode this will be the ConformingFactor MW input if that value is negative, otherwise it will be zero
    EstNonScalableLoad(t,n) $ ( LoadIsNCL(t,n) = 1 ) = NonConformingLoad(t,n);
    EstNonScalableLoad(t,n) $ ( LoadIsNCL(t,n) = 0 ) = ConformingFactor(t,n);
    EstNonScalableLoad(t,n) $ ( EstLoadIsScalable(t,n) = 1 ) = 0;

*   Calculate estimate scalable load [4.10.6.10]
*   For a non-conforming Pnode this value will be zero. For a conforming Pnode this value will be the ConformingFactor if it is non-negative, otherwise this value will be zero
    EstScalableLoad(t,n) $ ( EstLoadIsScalable(t,n) = 1 ) = ConformingFactor(t,n);

*   Calculate Scaling applied to ConformingFactor load MW [4.10.6.9] in order to calculate EstimatedInitialLoad
    EstScalingFactor(t,isl) = (islandMWIPS(t,isl) - LoadCalcLosses(t,isl) - Sum[ n $ nodeIsland(t,n,isl), EstNonScalableLoad(t,n) ]) / Sum[ n $ nodeIsland(t,n,isl), EstScalableLoad(t,n) ] ;

*   Calculate estimate initial load [4.10.6.6]
*   Calculated estimate of initial MW load, available to be used as an alternative to InputInitialLoad
    EstimatedInitialLoad(t,n) $ ( EstLoadIsScalable(t,n) = 1 ) = ConformingFactor(t,n) * Sum[ isl $ nodeisland(t,n,isl), EstScalingFactor(t,isl)] ;
    EstimatedInitialLoad(t,n) $ ( EstLoadIsScalable(t,n) = 0 ) = EstNonScalableLoad(t,n);

*   Calculate initial load [4.10.6.2]
*   Value that represents the Pnode load MW at the start of the solution interval. Depending on the inputs this value will be either actual load, an operator applied override or an estimated initial load
    InitialLoad(t,n) = InputInitialLoad(t,n);
    InitialLoad(t,n) $ { (LoadIsOverride(t,n) = 0) and ( (useActualLoad(t) = 0) or (LoadIsBad(t,n) = 1) ) } = EstimatedInitialLoad(t,n) ;
    InitialLoad(t,n) $ DidShortfallTransfer(t,n) = RequiredLoad(t,n);

*   Flag if load is scalable [4.10.6.4]
*   If True [1] then the Pnode InitialLoad will be scaled in order to alculate RequiredLoad, if False then Pnode InitialLoad will be directly assigned to RequiredLoad
    LoadIsScalable(t,n) = 1 $ { (LoadIsNCL(t,n) = 0) and (LoadIsOverride(t,n) = 0) and (InitialLoad(t,n) >= 0) and (ShortfallDisabledScaling(t,n) = 0) and (DidShortfallTransfer(t,n) = 0) } ;

*   Calculate Island-level scaling factor [4.10.6.3] --> applied to InitialLoad in order to calculate RequiredLoad
    LoadScalingFactor(t,isl) = ( TargetTotalLoad(t,isl) - Sum[n $ {nodeIsland(t,n,isl) and (LoadIsScalable(t,n) = 0)}, InitialLoad(t,n)] ) / Sum[n $ {nodeIsland(t,n,isl) and (LoadIsScalable(t,n) = 1)}, InitialLoad(t,n)] ;

*   Calculate RequiredLoad [4.10.6.1]
    RequiredLoad(t,n) $ { (DidShortfallTransfer(t,n)=0) and (LoadIsScalable(t,n)=1) } = InitialLoad(t,n) * sum[ isl $ nodeisland(t,n,isl), LoadScalingFactor(t,isl) ];
    RequiredLoad(t,n) $ { (DidShortfallTransfer(t,n)=0) and (LoadIsScalable(t,n)=0) }= InitialLoad(t,n);
    RequiredLoad(t,n) $ {  DidShortfallTransfer(t,n)=0 } = RequiredLoad(t,n) + [InstructedLoadShed(t,n) $ InstructedShedActive(t,n)] ;


*   Recalculate energy scarcity limits -------------------------------------------
    ScarcityEnrgLimit(t,n,blk) = 0 ;
    ScarcityEnrgLimit(t,n,blk) $ { energyScarcityEnabled(t) and (RequiredLoad(t,n) > 0) }                                     = scarcityEnrgNationalFactor(t,blk) * RequiredLoad(t,n);
    ScarcityEnrgPrice(t,n,blk) $ { energyScarcityEnabled(t) and (ScarcityEnrgLimit(t,n,blk) > 0 ) }                           = scarcityEnrgNationalPrice(t,blk) ;

    ScarcityEnrgLimit(t,n,blk) $ { energyScarcityEnabled(t) and (RequiredLoad(t,n) > 0) and scarcityEnrgNodeFactor(t,n,blk) } = scarcityEnrgNodeFactor(t,n,blk) * RequiredLoad(t,n);
    ScarcityEnrgPrice(t,n,blk) $ { energyScarcityEnabled(t) and scarcityEnrgNodeFactorPrice(t,n,blk) }                        = scarcityEnrgNodeFactorPrice(t,n,blk) ;

    ScarcityEnrgLimit(t,n,blk) $ { energyScarcityEnabled(t) and                             scarcityEnrgNodeLimit(t,n,blk)  } = scarcityEnrgNodeLimit(t,n,blk);
    ScarcityEnrgPrice(t,n,blk) $ { energyScarcityEnabled(t) and scarcityEnrgNodeLimitPrice(t,n,blk) }                         = scarcityEnrgNodeLimitPrice(t,n,blk) ;
*-------------------------------------------------------------------------------


*   Update Free Reserve and SharedNFRmax
*   Pre-processing: Shared Net Free Reserve (NFR) calculation - NMIR (4.5.1.2)
    sharedNFRLoad(t,isl) = sum[ nodeIsland(t,n,isl), RequiredLoad(t,n)] + sum[ (bd,blk) $ bidIsland(t,bd,isl), DemBidMW(t,bd,blk) ] - sharedNFRLoadOffset(t,isl) ;
    sharedNFRMax(t,isl) = Min{ RMTReserveLimitTo(t,isl,'FIR'), sharedNFRFactor(t)*sharedNFRLoad(t,isl) } ;

*   Risk parameters
    FreeReserve(t,isl,resC,riskC)
        = riskParameter(t,isl,resC,riskC,'freeReserve')
*   NMIR - Subtract shareNFRMax from current NFR -(5.2.1.4) - SPD version 11
        - sum[ isl1 $ (not sameas(isl,isl1)),sharedNFRMax(t,isl1) ] $ { (ord(resC)=1) and ( (GenRisk(riskC)) or (ManualRisk(riskC)) ) and (inputGDXGDate >= jdate(2016,10,20)) }
    ;

*   6.5.2.3 Total shared NFR is capped by shared NFR max
    SHAREDNFR.up(t,isl) = Max[0,sharedNFRMax(t,isl)] ;

*);



