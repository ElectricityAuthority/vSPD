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

unsolvedPeriod(tp) = yes;
VSPDModel(tp) = 0 ;
option clear = useBranchFlowMIP ;
option clear = useMixedConstraintMIP ;

While ( Sum[ tp $ unsolvedPeriod(tp), 1 ],
  exitLoop = 0;
  loop[ tp $ {unsolvedPeriod(tp) and (exitLoop = 0)},

*   7a. Reset all sets, parameters and variables -------------------------------
    option clear = currTP ;
*   Generation variables
    option clear = GENERATION ;
    option clear = GENERATIONBLOCK ;
*   Purchase variables
    option clear = PURCHASE ;
    option clear = PURCHASEBLOCK ;
    option clear = PURCHASEILR ;
    option clear = PURCHASEILRBLOCK ;
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
    option clear = HVDCLINKFLOWDIRECTION_INTEGER ;
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
*   Mixed constraint variables
    option clear = MIXEDCONSTRAINTVARIABLE ;
    option clear = MIXEDCONSTRAINTLIMIT2SELECT ;
*   Objective
    option clear = NETBENEFIT ;
*   Violation variables
    option clear = TOTALPENALTYCOST ;
    option clear = DEFICITBUSGENERATION ;
    option clear = SURPLUSBUSGENERATION ;
    option clear = DEFICITRESERVE ;
    option clear = DEFICITRESERVE_CE ;
    option clear = DEFICITRESERVE_ECE ;
    option clear = DEFICITBRANCHSECURITYCONSTRAINT ;
    option clear = SURPLUSBRANCHSECURITYCONSTRAINT ;
    option clear = DEFICITRAMPRATE ;
    option clear = SURPLUSRAMPRATE ;
    option clear = DEFICITACnodeCONSTRAINT ;
    option clear = SURPLUSACnodeCONSTRAINT ;
    option clear = DEFICITBRANCHFLOW ;
    option clear = SURPLUSBRANCHFLOW ;
    option clear = DEFICITMNODECONSTRAINT ;
    option clear = SURPLUSMNODECONSTRAINT ;
    option clear = DEFICITTYPE1MIXEDCONSTRAINT ;
    option clear = SURPLUSTYPE1MIXEDCONSTRAINT ;
    option clear = DEFICITGENERICCONSTRAINT ;
    option clear = SURPLUSGENERICCONSTRAINT ;

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
    currTP(tp)  $ sequentialSolve       = yes;
    currTP(tp1) $ (not sequentialSolve) = yes;

*   Update initial MW if run NRSS, PRSS, NRSL, PRSL
    generationStart(offer(currTP(tp),o))
        $ (sum[ o1, generationStart(currTP,o1)] = 0)
        = sum[ dt $ (ord(dt) = ord(tp)-1), o_offerEnergy_TP(dt,o) ] ;
*   Calculation of generation upper limits due to ramp rate limits
*   Calculation 5.3.1.2. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
    rampTimeUp(offer(currTP(tp),o))
        $ { (not hasPrimaryOffer(offer)) and rampRateUp(offer) }
        = Min[ i_tradingPeriodLength , ( generationMaximum(offer)
                                       - generationStart(offer)
                                       ) / rampRateUp(offer)
             ] ;

*   Calculation 5.3.1.3. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
    generationEndUp(offer(currTP(tp),o)) $ (not hasPrimaryOffer(offer))
        = generationStart(offer) + rampRateUp(offer)*rampTimeUp(offer) ;


*   Calculation of generation lower limits due to ramp rate limits

*   Calculation 5.3.2.2. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
    rampTimeDown(offer(currTP(tp),o))
        $ { (not hasPrimaryOffer(offer)) and rampRateDown(offer) }
        = Min[ i_tradingPeriodLength, ( generationStart(offer)
                                      - generationMinimum(offer)
                                      ) / rampRateDown(offer)
             ] ;

*   Calculation 5.3.2.3. - For primary-secondary offers, only primary offer
*   initial MW and ramp rate is used - Reference: Transpower Market Services
    generationEndDown(offer(currTP(tp),o)) $ (not hasPrimaryOffer(offer))
        = Max[ 0, generationStart(offer)
                - rampRateDown(offer)*rampTimeDown(offer) ] ;

*   Additional pre-processing on parameters end


*   7c. Updating the variable bounds before model solve ------------------------

* TN - Pivot or Demand Analysis - revise input data
$Ifi %opMode%=='PVT' $include "Pivot\vSPDSolvePivot_2.gms"
$Ifi %opMode%=='DPS' $include "Demand\vSPDSolveDPS_2.gms"
* TN - Pivot or Demand Analysis - revise input data end

*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS ========================

*   Offer blocks - Constraint 3.1.1.1
    GENERATIONBLOCK.up(validGenerationOfferBlock(currTP,o,trdBlk))
        = generationOfferMW(validGenerationOfferBlock) ;

    GENERATIONBLOCK.fx(currTP,o,trdBlk)
        $ (not validGenerationOfferBlock(currTP,o,trdBlk)) = 0 ;

*   Constraint 3.1.1.2 - Fix the generation variable for generators
*   that are not connected or do not have a non-zero energy offer
    GENERATION.fx(offer(currTP,o)) $ (not PositiveEnergyOffer(offer)) = 0 ;

*   Constraint 5.1.1.3 - Set Upper Bound for Wind Offer - Tuong
    GENERATION.up(offer(currTP,o))
        $ { windOffer(offer) and priceResponsive(offer) }
        = min[ potentialMW(offer), ReserveGenerationMaximum(offer) ] ;

*   Change to demand bid - Constraint 3.1.1.3 and 3.1.1.4
    PURCHASEBLOCK.up(validPurchaseBidBlock(currTP,bd,trdBlk))
        $ (not UseDSBFDemandBidModel)
        = purchaseBidMW(validPurchaseBidBlock) ;

    PURCHASEBLOCK.lo(validPurchaseBidBlock(currTP,bd,trdBlk))
        $ (not UseDSBFDemandBidModel)
        = 0 ;

    PURCHASEBLOCK.up(validPurchaseBidBlock(currTP,bd,trdBlk))
        $ UseDSBFDemandBidModel
        = purchaseBidMW(currTP,bd,trdBlk) $ [purchaseBidMW(currTP,bd,trdBlk)>0];

    PURCHASEBLOCK.lo(validPurchaseBidBlock(currTP,bd,trdBlk))
        $ UseDSBFDemandBidModel
        = purchaseBidMW(currTP,bd,trdBlk) $ [purchaseBidMW(currTP,bd,trdBlk)<0];

    PURCHASEBLOCK.fx(currTP,bd,trdBlk)
        $ (not validPurchaseBidBlock(currTP,bd,trdBlk))
        = 0 ;

*   Fix the purchase variable for purchasers that are not connected
*   or do not have a non-zero purchase bid
    PURCHASE.fx(currTP,bd)
        $ (sum[trdBlk $ validPurchaseBidBlock(currTP,bd,trdBlk), 1] = 0) = 0 ;

*======= GENERATION, DEMAND AND LOAD FORECAST EQUATIONS END ====================


*======= HVDC TRANSMISSION EQUATIONS ===========================================

*   Ensure that variables used to specify flow and losses on HVDC link are
*   zero for AC branches and for open HVDC links.
    HVDCLINKFLOW.fx(currTP,br)   $ (not HVDClink(currTP,br)) = 0 ;
    HVDCLINKLOSSES.fx(currTP,br) $ (not HVDClink(currTP,br)) = 0 ;

*   Apply an upper bound on the weighting parameter based on its definition
    LAMBDA.up(branch,bp) = 1 ;

*   Ensure that the weighting factor value is zero for AC branches and for
*   invalid loss segments on HVDC links
    LAMBDA.fx(HVDClink,bp)
        $ ( sum[fd $ validLossSegment(HVDClink,bp,fd),1] = 0 ) = 0 ;
    LAMBDA.fx(currTP,br,bp) $ (not HVDClink(currTP,br)) = 0 ;

*======= HVDC TRANSMISSION EQUATIONS END =======================================


*======= AC TRANSMISSION EQUATIONS =============================================

*   Ensure that variables used to specify flow and losses on AC branches are
*   zero for HVDC links branches and for open AC branches
    ACBRANCHFLOW.fx(currTP,br)              $ (not ACbranch(currTP,br)) = 0 ;
    ACBRANCHFLOWDIRECTED.fx(currTP,br,fd)   $ (not ACbranch(currTP,br)) = 0 ;
    ACBRANCHLOSSESDIRECTED.fx(currTP,br,fd) $ (not ACbranch(currTP,br)) = 0 ;

*   Ensure directed block flow and loss block variables are zero for
*   non-AC branches and invalid loss segments on AC branches
   ACBRANCHFLOWBLOCKDIRECTED.fx(currTP,br,los,fd)
       $ { not(ACbranch(currTP,br) and validLossSegment(currTP,br,los,fd)) } = 0 ;

   ACBRANCHLOSSESBLOCKDIRECTED.fx(currTP,br,los,fd)
       $ { not(ACbranch(currTP,br) and validLossSegment(currTP,br,los,fd)) } = 0 ;


*   Constraint 3.3.1.10 - Ensure that the bus voltage angle for the buses
*   corresponding to the reference nodes and the HVDC nodes are set to zero
    ACNODEANGLE.fx(currTP,b)
       $ sum[ n $ { NodeBus(currTP,n,b) and
                    (ReferenceNode(currTP,n) or HVDCnode(currTP,n)) }, 1 ] = 0 ;

*======= AC TRANSMISSION EQUATIONS END =========================================


*======= RISK & RESERVE EQUATIONS ==============================================

*   Ensure that all the invalid reserve blocks are set to zero for offers and purchasers
    RESERVEBLOCK.fx(offer(currTP,o),trdBlk,resC,resT)
        $ (not validReserveOfferBlock(offer,trdBlk,resC,resT)) = 0 ;

    PURCHASEILRBLOCK.fx(bid(currTP,bd),trdBlk,resC)
        $ (not validPurchaseBidILRBlock(bid,trdBlk,resC)) = 0 ;

*   Reserve block maximum for offers and purchasers - Constraint 3.4.3.2.
    RESERVEBLOCK.up(validReserveOfferBlock(currTP,o,trdBlk,resC,resT))
        = reserveOfferMaximum(validReserveOfferBlock) ;

    PURCHASEILRBLOCK.up(validPurchaseBidILRBlock(currTP,bd,trdBlk,resC))
        = purchaseBidILRMW(validPurchaseBidILRBlock) ;

*   Fix the reserve variable for invalid reserve offers. These are offers that
*   are either not connected to the grid or have no reserve quantity offered.
    RESERVE.fx(currTP,o,resC,resT)
        $ (not sum[ trdBlk $ validReserveOfferBlock(currTP,o,trdBlk,resC,resT), 1 ] ) = 0 ;

*   Fix the purchase ILR variable for invalid purchase reserve offers. These are
*   offers that are either not connected to the grid or have no reserve quantity offered.
    PURCHASEILR.fx(currTP,bd,resC)
        $ (not sum[ trdBlk $ validPurchaseBidILRBlock(currTP,bd,trdBlk,resC), 1 ] ) = 0 ;

*   Risk offset fixed to zero for those not mapped to corresponding mixed constraint variable
    RISKOFFSET.fx(currTP,ild,resC,riskC)
        $ { useMixedConstraintRiskOffset and useMixedConstraint(currTP) and
            (not sum[ t1MixCstr $ Type1MixCstrReserveMap(t1MixCstr,ild,resC,riskC),1])
          } = 0 ;

*   Fix the appropriate deficit variable to zero depending on
*   whether the different CE and ECE CVP flag is set
    DEFICITRESERVE.fx(currTP,ild,resC) $ diffCeECeCVP = 0 ;
    DEFICITRESERVE_CE.fx(currTP,ild,resC) $ (not diffCeECeCVP) = 0 ;
    DEFICITRESERVE_ECE.fx(currTP,ild,resC) $ (not diffCeECeCVP) = 0 ;

*   Virtual reserve
    VIRTUALRESERVE.up(currTP,ild,resC) = virtualReserveMax(currTP,ild,resC) ;

* TN - The code below is used to set bus deficit generation <= total bus load (positive)
$ontext
    DEFICITBUSGENERATION.up(currTP,b)
        $ ( sum[ NodeBus(currTP,n,b)
               , NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n)
               ] > 0 )
        = sum[ NodeBus(currTP,n,b)
             , NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n)
             ]  ;
    DEFICITBUSGENERATION.fx(currTP,b)
        $ ( sum[ NodeBus(currTP,n,b)
               , NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n)
               ] <= 0 )
        = 0 ;
$offtext
*   NMIR project variables
    HVDCSENT.fx(currTP,ild) $ (HVDCCapacity(currTP,ild) = 0) = 0 ;
    HVDCSENTLOSS.fx(currTP,ild) $ (HVDCCapacity(currTP,ild) = 0) = 0 ;

*   (3.4.2.3) - SPD version 11.0
    SHAREDNFR.up(currTP,ild) = Max[0,sharedNFRMax(currTP,ild)] ;

*   No forward reserve sharing if HVDC capacity is zero
    RESERVESHARESENT.fx(currTP,ild,resC,rd)
        $ { (HVDCCapacity(currTP,ild) = 0) and (ord(rd) = 1) } = 0 ;

*   No forward reserve sharing if reserve sharing is disabled
    RESERVESHARESENT.fx(currTP,ild,resC,rd)
        $ (reserveShareEnabled(currTP,resC)=0) = 0;

*   No reserve sharing to cover HVDC risk
    RESERVESHAREEFFECTIVE.fx(currTP,ild,resC,HVDCrisk) = 0;
    RESERVESHAREEFFECTIVE.fx(currTP,ild,resC,HVDCsecRisk) = 0;

*   (3.4.2.16) - SPD version 11 - no RP zone if reserve round power disabled
    INZONE.fx(currTP,ild,resC,z)
        $ {(ord(z) = 1) and (not reserveRoundPower(currTP,resC))} = 0;

*   (3.4.2.17) - SPD version 11 - no no-reserve zone for SIR zone if reserve RP enabled
    INZONE.fx(currTP,ild,resC,z)
        $ {(ord(resC)=2) and (ord(z)=2) and reserveRoundPower(currTP,resC)} = 0;

*   Fixing Lambda integer variable for energy sent
    LAMBDAHVDCENERGY.fx(currTP,ild,bp) $ { (HVDCCapacity(currTP,ild) = 0)
                                        and (ord(bp) = 1) } = 1 ;

    LAMBDAHVDCENERGY.fx(currTP,ild,bp) $ (ord(bp) > 7) = 0 ;

* To be reviewed NMIR
    LAMBDAHVDCRESERVE.fx(currTP,ild,resC,rd,rsbp)
        $ { (HVDCCapacity(currTP,ild) = 0)
        and (ord(rsbp) = 7) and (ord(rd) = 1) } = 1 ;

    LAMBDAHVDCRESERVE.fx(currTP,ild1,resC,rd,rsbp)
        $ { (sum[ ild $ (not sameas(ild,ild1)), HVDCCapacity(currTP,ild) ] = 0)
        and (ord(rsbp) < 7) and (ord(rd) = 2) } = 0 ;
;


*======= RISK & RESERVE EQUATIONS END ==========================================


*======= MIXED CONSTRAINTS =====================================================

*   Mixed constraint
    MIXEDCONSTRAINTVARIABLE.fx(currTP,t1MixCstr)
        $ (not i_type1MixedConstraintVarWeight(t1MixCstr)) = 0 ;

*======= MIXED CONSTRAINTS END =================================================

*   Updating the variable bounds before model solve end


*   7d. Solve Models
*   Solve the LP model ---------------------------------------------------------
    if( (Sum[currTP, VSPDModel(currTP)] = 0),

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
            putclose runlog 'The case: %vSPDinputData% '
                            'is 1st solved successfully.'/
                            'Objective function value: '
                            NETBENEFIT.l:<12:1 /
                            'Violation Cost          : '
                            TOTALPENALTYCOST.l:<12:1 /
        elseif((ModelSolved = 0) and (sequentialSolve = 0)),
            putclose runlog 'The case: %vSPDinputData% '
                            'is 1st solved unsuccessfully.'/
        ) ;

        if((ModelSolved = 1) and (sequentialSolve = 1),
            loop(currTP,
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is 1st solved successfully.'/
                                'Objective function value: '
                                NETBENEFIT.l:<12:1 /
                                'Violations cost         : '
                                TOTALPENALTYCOST.l:<12:1 /
            ) ;
        elseif((ModelSolved = 0) and (sequentialSolve = 1)),
            loop(currTP,
                unsolvedPeriod(currTP) = no;
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is 1st solved unsuccessfully.'/
            ) ;

        ) ;
*   Solve the LP model end -----------------------------------------------------


*   Solve the VSPD_MIP model ---------------------------------------------------
    elseif (Sum[currTP, VSPDModel(currTP)] = 1),
*       Fix the values of the integer variables that are not needed
        ACBRANCHFLOWDIRECTED_INTEGER.fx(branch(currTP,br),fd)
            $ { (not ACbranch(currTP,br)) or (not LossBranch(branch)) } = 0 ;

*       Fix the integer AC branch flow variable to zero for invalid branches
        ACBRANCHFLOWDIRECTED_INTEGER.fx(currTP,br,fd)
            $ (not branch(currTP,br)) = 0 ;

*       Apply an upper bound on the integer weighting parameter
        LAMBDAINTEGER.up(branch(currTP,br),bp) = 1 ;

*       Ensure that the weighting factor value is zero for AC branches
*       and for invalid loss segments on HVDC links
        LAMBDAINTEGER.fx(branch(currTP,br),bp)
            $ { ACbranch(branch)
            or ( sum[fd $ validLossSegment(branch,bp,fd),1 ] = 0 )
              } = 0 ;

*       Fix the lambda integer variable to zero for invalid branches
        LAMBDAINTEGER.fx(currTP,br,bp) $ (not branch(currTP,br)) = 0 ;

*       Fix the value of some binary variables used in the mixed constraints
*       that have no alternate limit
        MIXEDCONSTRAINTLIMIT2SELECT.fx(Type1MixedConstraint(currTP,t1MixCstr))
            $ (not Type1MixedConstraintCondition(Type1MixedConstraint)) = 0 ;

        option bratio = 1 ;
        vSPD_MIP.Optfile = 1 ;
        vSPD_MIP.optcr = MIPOptimality ;
        vSPD_MIP.reslim = MIPTimeLimit ;
        vSPD_MIP.iterlim = MIPIterationLimit ;
        solve vSPD_MIP using mip maximizing NETBENEFIT ;
*       Set the model solve status
        ModelSolved = 1 $ { [ (vSPD_MIP.modelstat = 1) or
                              (vSPD_MIP.modelstat = 8)
                            ]
                            and
                            [ vSPD_MIP.solvestat = 1 ]
                          } ;

*       Post a progress message for use by EMI.
        if(ModelSolved = 1,
            loop(currTP,
                unsolvedPeriod(currTP) = no;
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is 1st solved successfully for FULL integer.'/
                                'Objective function value: '
                                NETBENEFIT.l:<12:1 /
                                'Violations              : '
                                TOTALPENALTYCOST.l:<12:1 /
            ) ;
        else
            loop(currTP,
                unsolvedPeriod(currTP) = yes;
                VSPDModel(currTP) = 4;
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is 1st solved unsuccessfully for FULL integer.'/
            ) ;
        ) ;
*   Solve the vSPD_MIP model end -----------------------------------------------


*   Solve the vSPD_BranchFlowMIP -----------------------------------------------
    elseif (Sum[currTP, VSPDModel(currTP)] = 2),
*       Fix the values of these integer variables that are not needed
        ACBRANCHFLOWDIRECTED_INTEGER.fx(branch(currTP,br),fd)
            $ { (not ACbranch(currTP,br)) or (not LossBranch(branch)) } = 0 ;

*       Fix the integer AC branch flow variable to zero for invalid branches
        ACBRANCHFLOWDIRECTED_INTEGER.fx(currTP,br,fd)
            $ (not branch(currTP,br)) = 0 ;

*       Apply an upper bound on the integer weighting parameter
        LAMBDAINTEGER.up(branch(currTP,br),bp) = 1 ;

*       Ensure that the weighting factor value is zero for AC branches
*       and for invalid loss segments on HVDC links
        LAMBDAINTEGER.fx(branch(currTP,br),bp)
            $ { ACbranch(branch)
            or ( sum[fd $ validLossSegment(branch,bp,fd),1 ] = 0 )
              } = 0 ;

*       Fix the lambda integer variable to zero for invalid branches
        LAMBDAINTEGER.fx(currTP,br,bp) $ (not branch(currTP,br)) = 0 ;

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
            vSPD_SOS1_Solve(currTP)  = yes;

            loop(currTP,
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is 1st solved successfully for branch integer.'/
                                'Objective function value: '
                                NETBENEFIT.l:<12:1 /
                                'Violations cost         : '
                                TOTALPENALTYCOST.l:<12:1 /
            ) ;
        else
            loop(currTP,
                unsolvedPeriod(currTP) = yes;
                VSPDModel(currTP) = 4;
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is 1st solved unsuccessfully for branch integer.'/
            ) ;
        ) ;
*   Solve the vSPD_BranchFlowMIP model end -------------------------------------


*   Solve the vSPD_MixedConstraintMIP model ------------------------------------
    elseif (Sum[currTP, VSPDModel(currTP)] = 3),
*       Fix the value of some binary variables used in the mixed constraints
*       that have no alternate limit
        MIXEDCONSTRAINTLIMIT2SELECT.fx(Type1MixedConstraint(currTP,t1MixCstr))
            $ (not Type1MixedConstraintCondition(Type1MixedConstraint)) = 0 ;

*       Use the advanced basis here
        option bratio = 0.25 ;
        vSPD_MixedConstraintMIP.Optfile = 1 ;
*       Set the optimality criteria for the MIP
        vSPD_MixedConstraintMIP.optcr = MIPOptimality ;
        vSPD_MixedConstraintMIP.reslim = MIPTimeLimit ;
        vSPD_MixedConstraintMIP.iterlim = MIPIterationLimit ;
*       Solve the model
        solve vSPD_MixedConstraintMIP using mip maximizing NETBENEFIT ;
*       Set the model solve status
        ModelSolved = 1 $ { [ (vSPD_MixedConstraintMIP.modelstat = 1) or
                              (vSPD_MixedConstraintMIP.modelstat = 8)
                            ]
                            and
                            [ vSPD_MixedConstraintMIP.solvestat = 1 ]
                          } ;

*       Post a progress message for use by EMI.
        if(ModelSolved = 1,
            loop(currTP,
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is 1st solved successfully for '
                                'mixed constraint integer.'/
                                'Objective function value: '
                                NETBENEFIT.l:<12:1 /
                                'Violations cost         : '
                                TOTALPENALTYCOST.l:<12:1 /
            ) ;
        else
            loop(currTP,
                unsolvedPeriod(currTP) = yes;
                VSPDModel(currTP) = 1;
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is 1st solved unsuccessfully for '
                                'mixed constraint integer.'/
            ) ;
        ) ;
*   Solve the vSPD_MixedConstraintMIP model end --------------------------------


*   Solve the LP model and stop ------------------------------------------------
    elseif (Sum[currTP, VSPDModel(currTP)] = 4),

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
            loop(currTP,
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ')'
                                ' integer resolve was unsuccessful.' /
                                'Reverting back to linear solve and '
                                'solve successfully. ' /
                                'Objective function value: '
                                NETBENEFIT.l:<12:1 /
                                'Violations cost         : '
                                TOTALPENALTYCOST.l:<12:1 /
                                'Solution may have circulating flows '
                                'and/or non-physical losses.' /
            ) ;
        else
            loop(currTP,
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl
                                ') integer solve was unsuccessful. '
                                'Reverting back to linear solve. '
                                'Linear solve unsuccessful.' /
            ) ;
        ) ;

        unsolvedPeriod(currTP) = no;

*   Solve the LP model and stop end --------------------------------------------

    ) ;
*   Solve the models end



*   6e. Check if the LP results are valid --------------------------------------
    if((ModelSolved = 1),
        useBranchFlowMIP(currTP) = 0 ;
        useMixedConstraintMIP(currTP) = 0 ;
*       Check if there is no branch circular flow and non-physical losses
        Loop( currTP $ { (VSPDModel(currTP)=0) or (VSPDModel(currTP)=3) } ,

*           Check if there are circulating branch flows on loss AC branches
            circularBranchFlowExist(ACbranch(currTP,br))
                $ { LossBranch(ACbranch) and
                    [ ( sum[ fd, ACBRANCHFLOWDIRECTED.l(ACbranch,fd) ]
                      - abs(ACBRANCHFLOW.l(ACbranch))
                      ) > circularBranchFlowTolerance
                    ]
                  } = 1 ;

*           Determine the circular branch flow flag on each HVDC pole
            TotalHVDCpoleFlow(currTP,pole)
                = sum[ br $ HVDCpoleBranchMap(pole,br)
                     , HVDCLINKFLOW.l(currTP,br) ] ;

            MaxHVDCpoleFlow(currTP,pole)
                = smax[ br $ HVDCpoleBranchMap(pole,br)
                      , HVDCLINKFLOW.l(currTP,br) ] ;

            poleCircularBranchFlowExist(currTP,pole)
                $ { ( TotalHVDCpoleFlow(currTP,pole)
                    - MaxHVDCpoleFlow(currTP,pole)
                    ) > circularBranchFlowTolerance
                  } = 1 ;

*           Check if there are circulating branch flows on HVDC
            NorthHVDC(currTP)
                = sum[ (ild,b,br) $ { (ord(ild) = 2) and
                                      i_tradePeriodBusIsland(currTP,b,ild) and
                                      HVDClinkSendingBus(currTP,br,b) and
                                      HVDCpoles(currTP,br)
                                    }, HVDCLINKFLOW.l(currTP,br)
                     ] ;

            SouthHVDC(currTP)
                = sum[ (ild,b,br) $ { (ord(ild) = 1) and
                                      i_tradePeriodBusIsland(currTP,b,ild) and
                                      HVDClinkSendingBus(currTP,br,b) and
                                      HVDCpoles(currTP,br)
                                    }, HVDCLINKFLOW.l(currTP,br)
                     ] ;

            circularBranchFlowExist(currTP,br)
                $ { HVDCpoles(currTP,br) and LossBranch(currTP,br) and
                   (NorthHVDC(currTP) > circularBranchFlowTolerance) and
                   (SouthHVDC(currTP) > circularBranchFlowTolerance)
                  } = 1 ;

*           Check if there are non-physical losses on HVDC links
            ManualBranchSegmentMWFlow(LossBranch(HVDClink(currTP,br)),los,fd)
                $ { ( ord(los) <= branchLossBlocks(HVDClink) )
                and validLossSegment(currTP,br,los,fd) }
                = Min[ Max( 0,
                            [ abs(HVDCLINKFLOW.l(HVDClink))
                            - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                            ]
                          ),
                       ( LossSegmentMW(HVDClink,los,fd)
                       - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                       )
                     ] ;

            ManualLossCalculation(LossBranch(HVDClink(currTP,br)))
                = sum[ (los,fd) $ validLossSegment(currTP,br,los,fd)
                                , LossSegmentFactor(HVDClink,los,fd)
                                * ManualBranchSegmentMWFlow(HVDClink,los,fd)
                     ] ;

            NonPhysicalLossExist(LossBranch(HVDClink(currTP,br)))
                $ { abs( HVDCLINKLOSSES.l(HVDClink)
                       - ManualLossCalculation(HVDClink)
                       ) > NonPhysicalLossTolerance
                  } = 1 ;

*           Set UseBranchFlowMIP = 1 if the number of circular branch flow
*           and non-physical loss branches exceeds the specified tolerance
            useBranchFlowMIP(currTP)
                $ { ( sum[ br $ { ACbranch(currTP,br) and LossBranch(currTP,br) }
                              , resolveCircularBranchFlows
                              * circularBranchFlowExist(currTP,br)
                         ]
                    + sum[ br $ { HVDClink(currTP,br) and LossBranch(currTP,br) }
                              , (1 - AllowHVDCroundpower(currTP))
                              * resolveCircularBranchFlows
                              * circularBranchFlowExist(currTP,br)
                              + resolveHVDCnonPhysicalLosses
                              * NonPhysicalLossExist(currTP,br)
                         ]
                    + sum[ pole, resolveCircularBranchFlows
                               * poleCircularBranchFlowExist(currTP,pole)
                         ]
                     ) > UseBranchFlowMIPTolerance
                                       } = 1 ;

*       Check if there is no branch circular flow and non-physical losses end
        );


*       Check if there is mixed constraint integer is required
        Loop( currTP $ { (VSPDModel(currTP)=0) or (VSPDModel(currTP)=2) } ,

*           Check if integer variables are needed for mixed constraint
            if( useMixedConstraintRiskOffset,
                HVDChalfPoleSouthFlow(currTP)
                    $ { sum[ i_type1MixedConstraintBranchCondition(t1MixCstr,br)
                             $ HVDChalfPoles(currTP,br), HVDCLINKFLOW.l(currTP,br)
                           ] > MixedMIPTolerance
                      } = 1 ;

*               Only calculate violation if the constraint limit is non-zero
                Type1MixedConstraintLimit2Violation(Type1MixedConstraintCondition)
                    $ (Type1MixedConstraintLimit2(Type1MixedConstraintCondition) > 0)
                    = [ Type1MixedConstraintLE.l(Type1MixedConstraintCondition)
                      - Type1MixedConstraintLimit2(Type1MixedConstraintCondition)
                      ] $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = -1)
                    + [ Type1MixedConstraintLimit2(Type1MixedConstraintCondition)
                      - Type1MixedConstraintGE.l(Type1MixedConstraintCondition)
                      ] $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = 1)
                    + abs[ Type1MixedConstraintEQ.l(Type1MixedConstraintCondition)
                         - Type1MixedConstraintLimit2(Type1MixedConstraintCondition)
                         ] $ (Type1MixedConstraintSense(Type1MixedConstraintCondition) = 0) ;

*               Integer constraints are needed if southward flow on half-poles AND
*               constraint level exceeds the mixed constraint limit2 value
                useMixedConstraintMIP(currTP)
                    $ { HVDChalfPoleSouthFlow(currTP) and
                        sum[ t1MixCstr
                             $ { Type1MixedConstraintLimit2Violation(currTP,t1MixCstr)
                               > MixedMIPTolerance }, 1
                           ]
                      } = 1 ;
            ) ;

*       Check if there is mixed constraint integer is required end
        );

*       A period is unsolved if MILP model is required
        unsolvedPeriod(currTP) = yes $ [ UseBranchFlowMIP(currTP)
                                       + UseMixedConstraintMIP(currTP)
                                       ] ;

*       Post a progress message for use by EMI. Reverting to the sequential mode for integer resolves.
        loop( unsolvedPeriod(currTP),
            if( UseBranchFlowMIP(currTP)*UseMixedConstraintMIP(currTP) >= 1,
                VSPDModel(currTP) = 1;
                putclose runlog 'The case: %vSPDinputData% requires a'
                                'VSPD_MIP resolve for period ' currTP.tl
                                '. Switching Vectorisation OFF.' /

            elseif UseBranchFlowMIP(currTP) >= 1,
                if( VSPDModel(currTP) = 0,
                    VSPDModel(currTP) = 2;
                    putclose runlog 'The case: %vSPDinputData% requires a '
                                    'vSPD_BranchFlowMIP resolve for period '
                                    currTP.tl '. Switching Vectorisation OFF.'/
                elseif VSPDModel(currTP) = 3,
                    VSPDModel(currTP) = 1;
                    putclose runlog 'The case: %vSPDinputData% requires a '
                                    'VSPD_MIP resolve for period ' currTP.tl
                                    '. Switching Vectorisation OFF.' /
                );

            elseif UseMixedConstraintMIP(currTP) >= 1,
                if( VSPDModel(currTP) = 0,
                    VSPDModel(currTP) = 3;
                    putclose runlog 'The case: %vSPDinputData% requires a '
                                    'vSPD_MixedConstraintMIP resolve for period '
                                    currTP.tl '. Switching Vectorisation OFF.' /
                elseif VSPDModel(currTP) = 2,
                    VSPDModel(currTP) = 1;
                    putclose runlog 'The case: %vSPDinputData% requires a '
                                    'VSPD_MIP resolve for period ' currTP.tl
                                    '. Switching Vectorisation OFF.' /
                );

            ) ;

        ) ;

        sequentialSolve $ Sum[ unsolvedPeriod(currTP), 1 ] = 1 ;
        exitLoop = 1 $ Sum[ unsolvedPeriod(currTP), 1 ];

*   Check if the LP results are valid end
    ) ;



*   6f. Check for disconnected nodes and adjust prices accordingly -------------

*   See Rule Change Proposal August 2008 - Disconnected nodes available at
*   www.systemoperator.co.nz/reports-papers
$ontext
    Disconnected nodes are defined as follows:
    Pre-MSP: Have no generation or load, are disconnected from the network
             and has a price = CVP.
    Post-MSP: Indication to SPD whether a bus is dead or not.
              Dead buses are not processed by the SPD solved
    Disconnected nodes' prices set by the post-process with the following rules:
    Scenario A/B/D: Price for buses in live electrical island determined
                    by the solved
    Scenario C/F/G/H/I: Buses in the dead electrical island with:
        a. Null/zero load: Marked as disconnected with $0 price.
        b. Positive load: Price = CVP for deficit generation
        c. Negative load: Price = -CVP for surplus generation
    Scenario E: Price for bus in live electrical island with zero load needs to
                be adjusted since actually is disconnected.

    The Post-MSP implementation imply a mapping of a bus to an electrical island
    and an indication of whether this electrical island is live of dead.
    The correction of the prices is performed by SPD.

    Update the disconnected nodes logic to use the time-stamped
    i_useBusNetworkModel flag. This allows disconnected nodes logic to work
    with both pre and post-MSP data structure in the same gdx file
$offtext

    busGeneration(bus(currTP,b))
        = sum[ (o,n) $ { offerNode(currTP,o,n) and NodeBus(currTP,n,b) }
             , NodeBusAllocationFactor(currTP,n,b) * GENERATION.l(currTP,o)
             ] ;

    busLoad(bus(currTP,b))
        = sum[ NodeBus(currTP,n,b)
             , NodeBusAllocationFactor(currTP,n,b) * NodeDemand(currTP,n)
             ] ;

    busPrice(bus(currTP,b)) $ { not sum[ NodeBus(HVDCnode(currTP,n),b), 1 ] }
        = ACnodeNetInjectionDefinition2.m(currTP,b) ;

    busPrice(bus(currTP,b)) $ sum[ NodeBus(HVDCnode(currTP,n),b), 1 ]
        = DCNodeNetInjection.m(currTP,b) ;

    if((disconnectedNodePriceCorrection = 1),
*       Pre-MSP case
        busDisconnected(bus(currTP,b)) $ (i_useBusNetworkModel(currTP) = 0)
            = 1 $ { (busGeneration(bus) = 0) and  (busLoad(bus) = 0) and
                    ( not sum[ br $ { branchBusConnect(currTP,br,b) and
                                      branch(currTP,br)
                                    }, 1 ]
                    )
                  } ;

*       Post-MSP cases
*       Scenario C/F/G/H/I:
        busDisconnected(bus(currTP,b)) $ { (i_useBusNetworkModel(currTP) = 1)
                                       and (busLoad(bus) = 0)
                                       and (busElectricalIsland(bus) = 0)
                                         } = 1 ;
*       Scenario E:
        busDisconnected(bus(currTP,b))
            $ { ( sum[ b1 $ { busElectricalIsland(currTP,b1)
                            = busElectricalIsland(bus) }
                     , busLoad(currTP,b1) ] = 0
                ) and
                ( busElectricalIsland(bus) > 0 ) and
                ( i_useBusNetworkModel(currTP) = 1 )
              } = 1 ;
*       Set prices at dead buses with non-zero load
        busPrice(bus(currTP,b)) $ { (i_useBusNetworkModel(currTP) = 1) and
                                    (busLoad(bus) > 0) and
                                    (busElectricalIsland(bus)= 0)
                                  } = DeficitBusGenerationPenalty ;

        busPrice(bus(currTP,b)) $ { (i_useBusNetworkModel(currTP) = 1) and
                                    (busLoad(bus) < 0) and
                                    (busElectricalIsland(bus)= 0)
                                  } = -SurplusBusGenerationPenalty ;

*       Set price at identified disconnected buses to 0
        busPrice(bus)$busDisconnected(bus) = 0 ;
    ) ;

* End Check for disconnected nodes and adjust prices accordingly

* TN - Replacing invalid prices after SOS1
*   6f0. Replacing invalid prices after SOS1 (6.1.3)----------------------------
    if ( vSPD_SOS1_Solve(tp),
         busSOSinvalid(tp,b)
           = 1 $ { [ ( busPrice(tp,b) = 0 )
                    or ( busPrice(tp,b) > 0.9 * deficitBusGenerationPenalty )
                    or ( busPrice(tp,b) < -0.9 * surplusBusGenerationPenalty )
                     ]
                 and bus(tp,b)
                 and [ not busDisconnected(tp,b) ]
*                 and [ busLoad(tp,b) = 0 ]
*                 and [ busGeneration(tp,b) = 0 ]
                 and [ busLoad(tp,b) = busGeneration(tp,b) ]
                 and [ sum[(br,fd)
                          $ { BranchBusConnect(tp,br,b) and branch(tp,br) }
                          , ACBRANCHFLOWDIRECTED.l(tp,br,fd)
                          ] = 0
                     ]
                 and [ sum[ br
                          $ { BranchBusConnect(tp,br,b) and branch(tp,br) }
                          , 1
                          ] > 0
                     ]
                   };
        numberofbusSOSinvalid(tp) = 2*sum[b, busSOSinvalid(tp,b)];
        While ( sum[b, busSOSinvalid(tp,b)] < numberofbusSOSinvalid(tp) ,
            numberofbusSOSinvalid(tp) = sum[b, busSOSinvalid(tp,b)];
            busPrice(tp,b)
              $ { busSOSinvalid(tp,b)
              and ( sum[ b1 $ { [ not busSOSinvalid(tp,b1) ]
                            and sum[ br $ { branch(tp,br)
                                        and BranchBusConnect(tp,br,b)
                                        and BranchBusConnect(tp,br,b1)
                                          }, 1
                                   ]
                             }, 1
                       ] > 0
                  )
                }
              = sum[ b1 $ { [ not busSOSinvalid(tp,b1) ]
                        and sum[ br $ { branch(tp,br)
                                    and BranchBusConnect(tp,br,b)
                                    and BranchBusConnect(tp,br,b1)
                                      }, 1 ]
                          }, busPrice(tp,b1)
                   ]
              / sum[ b1 $ { [ not busSOSinvalid(tp,b1) ]
                        and sum[ br $ { branch(tp,br)
                                    and BranchBusConnect(tp,br,b)
                                    and BranchBusConnect(tp,br,b1)
                                      }, 1 ]
                          }, 1
                   ];

            busSOSinvalid(tp,b)
              = 1 $ { [ ( busPrice(tp,b) = 0 )
                     or ( busPrice(tp,b) > 0.9 * deficitBusGenerationPenalty )
                     or ( busPrice(tp,b) < -0.9 * surplusBusGenerationPenalty )
                      ]
                  and bus(tp,b)
                  and [ not busDisconnected(tp,b) ]
*                  and [ busLoad(tp,b) = 0 ]
*                  and [ busGeneration(tp,b) = 0 ]
                  and [ busLoad(tp,b) = busGeneration(tp,b) ]
                  and [ sum[(br,fd)
                          $ { BranchBusConnect(tp,br,b) and branch(tp,br) }
                          , ACBRANCHFLOWDIRECTED.l(tp,br,fd)
                           ] = 0
                      ]
                  and [ sum[ br
                           $ { BranchBusConnect(tp,br,b) and branch(tp,br) }
                           , 1
                           ] > 0
                      ]
                    };
         );
    );
*   End Replacing invalid prices after SOS1 (6.1.3) ----------------------------


*   6g. Collect and store results of solved periods into output parameters -----
* Note: all the price relating outputs such as costs and revenues are calculated in section 7.b

$iftheni.PeriodReport %opMode%=='FTR' $include "FTRental\vSPDSolveFTR_3.gms"
$elseifi.PeriodReport %opMode%=='DWH' $include "DWmode\vSPDSolveDWH_3.gms"
$elseifi.PeriodReport %opMode%=='PVT' $include "Pivot\vSPDSolvePivot_3.gms"
$elseifi.PeriodReport %opMode%=='DPS' $include "Demand\vSPDSolveDPS_3.gms"

$else.PeriodReport
*   Normal vSPD run post processing for reporting
$onend
    Loop i_dateTimeTradePeriodMap(dt,currTP) $ (not unsolvedPeriod(currTP)) do
*   Reporting at trading period start
*       Node level output
        o_node(dt,n) $ {Node(currTP,n) and (not HVDCnode(currTP,n))} = yes ;

        o_nodeGeneration_TP(dt,n) $ Node(currTP,n)
            = sum[ o $ offerNode(currTP,o,n), GENERATION.l(currTP,o) ] ;

        o_nodeLoad_TP(dt,n) $ Node(currTP,n)
           = NodeDemand(currTP,n)
           + Sum[ bd $ bidNode(currTP,bd,n), PURCHASE.l(currTP,bd) ];

        o_nodePrice_TP(dt,n) $ Node(currTP,n)
            = sum[ b $ NodeBus(currTP,n,b)
                 , NodeBusAllocationFactor(currTP,n,b) * busPrice(currTP,b)
                  ] ;

*       Offer output
        o_offer(dt,o) $ offer(currTP,o) = yes ;

        o_offerEnergy_TP(dt,o) $ offer(currTP,o) = GENERATION.l(currTP,o) ;

        o_offerFIR_TP(dt,o) $ offer(currTP,o)
            = sum[ (resC,resT)$(ord(resC) = 1)
                 , RESERVE.l(currTP,o,resC,resT) ] ;

        o_offerSIR_TP(dt,o) $ offer(currTP,o)
            = sum[ (resC,resT)$(ord(resC) = 2)
                 , RESERVE.l(currTP,o,resC,resT) ] ;

*       Bus level output
        o_bus(dt,b) $ { bus(currTP,b) and (not DCBus(currTP,b)) } = yes ;

        o_busGeneration_TP(dt,b) $ bus(currTP,b) = busGeneration(currTP,b) ;

        o_busLoad_TP(dt,b) $ bus(currTP,b)
            = busLoad(currTP,b)
            + Sum[ (bd,n) $ { bidNode(currTP,bd,n) and NodeBus(currTP,n,b) }
                 , PURCHASE.l(currTP,bd) ];

        o_busPrice_TP(dt,b) $ bus(currTP,b) = busPrice(currTP,b) ;

        o_busDeficit_TP(dt,b)$bus(currTP,b) = DEFICITBUSGENERATION.l(currTP,b) ;

        o_busSurplus_TP(dt,b)$bus(currTP,b) = SURPLUSBUSGENERATION.l(currTP,b) ;

*       Node level output

        totalBusAllocation(dt,b) $ bus(currTP,b)
            = sum[ n $ Node(currTP,n), NodeBusAllocationFactor(currTP,n,b)];

        busNodeAllocationFactor(dt,b,n) $ (totalBusAllocation(dt,b) > 0)
            = NodeBusAllocationFactor(currTP,n,b) / totalBusAllocation(dt,b) ;

* TN - post processing unmapped generation deficit buses start
$ontext
The following code is added post-process generation deficit bus that is not
mapped to a pnode (BusNodeAllocationFactor  = 0). In post-processing, when a
deficit is detected at a bus that does not map directly to a pnode, SPD creates
a ZBR mapping by following zero impendence branches (ZBRs) until it reaches a
pnode. The price at the deficit bus is assigned directly to the pnode,
overwriting any weighted price that post-processing originally calculated for
the pnode. This is based on email from Nic Deller <Nic.Deller@transpower.co.nz>
on 25 Feb 2015.
The code is modified again on 16 Feb 2016 to avoid infinite loop when there are
many generation deficit buses.
This code is used to post-process generation deficit bus that is not mapped to
$offtext
        unmappedDeficitBus(dt,b) $ o_busDeficit_TP(dt,b)
            = yes $ (Sum[ n, busNodeAllocationFactor(dt,b,n)] = 0);

        changedDeficitBus(dt,b) = no;

        If Sum[b $ unmappedDeficitBus(dt,b), 1] then

            temp_busDeficit_TP(dt,b) = o_busDeficit_TP(dt,b);

            Loop b $ unmappedDeficitBus(dt,b) do
                o_busDeficit_TP(dt,b1)
                  $ { Sum[ br $ { ( branchLossBlocks(tp,br)=0 )
                              and ( branchBusDefn(tp,br,b1,b)
                                 or branchBusDefn(tp,br,b,b1) )
                                }, 1 ]
                    } = o_busDeficit_TP(dt,b1) + o_busDeficit_TP(dt,b) ;

                changedDeficitBus(dt,b1)
                  $ Sum[ br $ { ( branchLossBlocks(tp,br)=0 )
                            and ( branchBusDefn(tp,br,b1,b)
                               or branchBusDefn(tp,br,b,b1) )
                              }, 1 ] = yes;

                unmappedDeficitBus(dt,b) = no;
                changedDeficitBus(dt,b) = no;
                o_busDeficit_TP(dt,b) = 0;
            EndLoop;

            Loop n $ sum[ b $ changedDeficitBus(dt,b)
                        , busNodeAllocationFactor(dt,b,n)] do
                o_nodePrice_TP(dt,n) = deficitBusGenerationPenalty ;
                o_nodeDeficit_TP(dt,n) = sum[ b $ busNodeAllocationFactor(dt,b,n),
                                                  busNodeAllocationFactor(dt,b,n)
                                                * o_busDeficit_TP(dt,b) ] ;
            EndLoop;

            o_busDeficit_TP(dt,b) = temp_busDeficit_TP(dt,b);
        Endif;
* TN - post processing unmapped generation deficit buses end

        o_nodeDeficit_TP(dt,n) $ Node(currTP,n)
            = sum[ b $ NodeBus(currTP,n,b), busNodeAllocationFactor(dt,b,n)
                                          * DEFICITBUSGENERATION.l(currTP,b) ] ;

        o_nodeSurplus_TP(dt,n) $ Node(currTP,n)
            = sum[ b $ NodeBus(currTP,n,b), busNodeAllocationFactor(dt,b,n)
                                          * SURPLUSBUSGENERATION.l(currTP,b) ] ;

*       branch output
        o_branch(dt,br) $ branch(currTP,br) = yes ;

        o_branchFlow_TP(dt,br) $ ACbranch(currTP,br) = ACBRANCHFLOW.l(currTP,br);

        o_branchFlow_TP(dt,br) $ HVDClink(currTP,br) = HVDCLINKFLOW.l(currTP,br);

        o_branchDynamicLoss_TP(dt,br) $  ACbranch(currTP,br)
            = sum[ fd, ACBRANCHLOSSESDIRECTED.l(currTP,br,fd) ] ;

        o_branchDynamicLoss_TP(dt,br) $ HVDClink(currTP,br)
            = HVDCLINKLOSSES.l(currTP,br) ;

        o_branchFixedLoss_TP(dt,br) $ branch(currTP,br)
            = branchFixedLoss(currTP,br) ;

        o_branchTotalLoss_TP(dt,br) $ branch(currTP,br)
            = o_branchDynamicLoss_TP(dt,br) + o_branchFixedLoss_TP(dt,br) ;

        o_branchFromBus_TP(dt,br,frB)
            $ { branch(currTP,br) and
                sum[ toB $ branchBusDefn(currTP,br,frB,toB), 1 ]
              } = yes ;

        o_branchToBus_TP(dt,br,toB)
            $ { branch(currTP,br) and
                sum[ frB $ branchBusDefn(currTP,br,frB,toB), 1 ]
              } = yes ;

        o_branchMarginalPrice_TP(dt,br) $ ACbranch(currTP,br)
            = sum[ fd, ACbranchMaximumFlow.m(currTP,br,fd) ] ;

        o_branchMarginalPrice_TP(dt,br) $ HVDClink(currTP,br)
            = HVDClinkMaximumFlow.m(currTP,br) ;

        o_branchCapacity_TP(dt,br) $ branch(currTP,br)
            = sum[ fd $ ( ord(fd) = 1 )
                      , i_tradePeriodBranchCapacityDirected(currTP,br,fd)
                 ] $  { o_branchFlow_TP(dt,br) >= 0 }
            + sum[ fd $ ( ord(fd) = 2 )
                      , i_tradePeriodBranchCapacityDirected(currTP,br,fd)
                 ] $  { o_branchFlow_TP(dt,br) < 0 } ;


*       Offer output
        o_offerEnergyBlock_TP(dt,o,trdBlk)
            = GENERATIONBLOCK.l(currTP,o,trdBlk);

        o_offerFIRBlock_TP(dt,o,trdBlk,resT)
            = sum[ resC $ (ord(resC) = 1)
            , RESERVEBLOCK.l(currTP,o,trdBlk,resC,resT)];

        o_offerSIRBlock_TP(dt,o,trdBlk,resT)
            = sum[ resC $ (ord(resC) = 2)
            , RESERVEBLOCK.l(currTP,o,trdBlk,resC,resT)];

*       bid output
        o_bid(dt,bd) $ bid(currTP,bd) = yes ;

        o_bidEnergy_TP(dt,bd) $ bid(currTP,bd) = PURCHASE.l(currTP,bd) ;

        o_bidFIR_TP(dt,bd) $ bid(currTP,bd)
            = sum[ resC $ (ord(resC) = 1)
                 , PURCHASEILR.l(currTP,bd,resC) ] ;

        o_bidSIR_TP(dt,bd) $ bid(currTP,bd)
            = sum[ resC $ (ord(resC) = 2)
                 , PURCHASEILR.l(currTP,bd,resC) ] ;

        o_bidTotalMW_TP(dt,bd) $ bid(currTP,bd)
            = sum[ trdBlk, purchaseBidMW(currTP,bd,trdBlk) ] ;

*       Violation reporting based on the CE and ECE
        o_ResViolation_TP(dt,ild,resC)
            = DEFICITRESERVE.l(currTP,ild,resC)     $ (not diffCeECeCVP)
            + DEFICITRESERVE_CE.l(currTP,ild,resC)  $ (diffCeECeCVP)
            + DEFICITRESERVE_ECE.l(currTP,ild,resC) $ (diffCeECeCVP) ;

        o_FIRviolation_TP(dt,ild)
            = sum[ resC $ (ord(resC) = 1), o_ResViolation_TP(dt,ild,resC) ] ;

        o_SIRviolation_TP(dt,ild)
            = sum[ resC $ (ord(resC) = 2), o_ResViolation_TP(dt,ild,resC) ] ;

*       Security constraint data
        o_brConstraint_TP(dt,brCstr) $ branchConstraint(currTP,brCstr) = yes ;

        o_brConstraintSense_TP(dt,brCstr) $ branchConstraint(currTP,brCstr)
            = branchConstraintSense(currTP,brCstr) ;

        o_brConstraintLHS_TP(dt,brCstr) $ branchConstraint(currTP,brCstr)
            = [ branchSecurityConstraintLE.l(currTP,brCstr)
              $ (branchConstraintSense(currTP,brCstr) = -1) ]
            + [ branchSecurityConstraintGE.l(currTP,brCstr)
              $ (branchConstraintSense(currTP,brCstr) = 1)  ]
            + [ branchSecurityConstraintEQ.l(currTP,brCstr)
              $ (branchConstraintSense(currTP,brCstr) = 0)  ] ;

        o_brConstraintRHS_TP(dt,brCstr) $ branchConstraint(currTP,brCstr)
            = branchConstraintLimit(currTP,brCstr) ;

        o_brConstraintPrice_TP(dt,brCstr) $ branchConstraint(currTP,brCstr)
            = [ branchSecurityConstraintLE.m(currTP,brCstr)
              $ (branchConstraintSense(currTP,brCstr) = -1) ]
            + [ branchSecurityConstraintGE.m(currTP,brCstr)
              $ (branchConstraintSense(currTP,brCstr) = 1)  ]
            + [ branchSecurityConstraintEQ.m(currTP,brCstr)
              $ (branchConstraintSense(currTP,brCstr) = 0)  ] ;

*       Mnode constraint data
        o_MnodeConstraint_TP(dt,MnodeCstr)
            $ MnodeConstraint(currTP,MnodeCstr) = yes ;

        o_MnodeConstraintSense_TP(dt,MnodeCstr)
            $ MnodeConstraint(currTP,MnodeCstr)
            = MnodeConstraintSense(currTP,MnodeCstr) ;

        o_MnodeConstraintLHS_TP(dt,MnodeCstr)
            $ MnodeConstraint(currTP,MnodeCstr)
            = [ MnodeSecurityConstraintLE.l(currTP,MnodeCstr)
              $ (MnodeConstraintSense(currTP,MnodeCstr) = -1) ]
            + [ MnodeSecurityConstraintGE.l(currTP,MnodeCstr)
              $ (MnodeConstraintSense(currTP,MnodeCstr) = 1)  ]
            + [ MnodeSecurityConstraintEQ.l(currTP,MnodeCstr)
              $ (MnodeConstraintSense(currTP,MnodeCstr) = 0)  ] ;

        o_MnodeConstraintRHS_TP(dt,MnodeCstr)
            $ MnodeConstraint(currTP,MnodeCstr)
            = MnodeConstraintLimit(currTP,MnodeCstr) ;

        o_MnodeConstraintPrice_TP(dt,MnodeCstr)
            $ MnodeConstraint(currTP,MnodeCstr)
            = [ MnodeSecurityConstraintLE.m(currTP,MnodeCstr)
              $ (MnodeConstraintSense(currTP,MnodeCstr) = -1) ]
            + [ MnodeSecurityConstraintGE.m(currTP,MnodeCstr)
              $ (MnodeConstraintSense(currTP,MnodeCstr) = 1)  ]
            + [ MnodeSecurityConstraintEQ.m(currTP,MnodeCstr)
              $ (MnodeConstraintSense(currTP,MnodeCstr) = 0)  ] ;

*       Island output
        o_island(dt,ild) = yes ;

        o_ResPrice_TP(dt,ild,resC)= IslandReserveCalculation.m(currTP,ild,resC);

        o_FIRprice_TP(dt,ild) = sum[ resC $ (ord(resC) = 1)
                                          , o_ResPrice_TP(dt,ild,resC) ];

        o_SIRprice_TP(dt,ild) = sum[ resC $ (ord(resC) = 2)
                                          , o_ResPrice_TP(dt,ild,resC) ];

        o_islandGen_TP(dt,ild)
            = sum[ b $ busIsland(currTP,b,ild), busGeneration(currTP,b) ] ;

        o_islandClrBid_TP(dt,ild)
            = sum[ bd $ bidIsland(currTP,bd,ild), PURCHASE.l(currTP,bd) ] ;

        o_islandLoad_TP(dt,ild)
            = sum[ b $ busIsland(currTP,b,ild), busLoad(currTP,b) ]
            + o_islandClrBid_TP(dt,ild) ;

        o_ResCleared_TP(dt,ild,resC) = ISLANDRESERVE.l(currTP,ild,resC);

        o_FirCleared_TP(dt,ild) = Sum[ resC $ (ord(resC) = 1)
                                            , o_ResCleared_TP(dt,ild,resC) ];

        o_SirCleared_TP(dt,ild) = Sum[ resC $ (ord(resC) = 2)
                                            , o_ResCleared_TP(dt,ild,resC) ];

        o_islandBranchLoss_TP(dt,ild)
            = sum[ (br,frB,toB)
                 $ { ACbranch(currTP,br) and busIsland(currTP,toB,ild)
                 and branchBusDefn(currTP,br,frB,toB)
                   }, o_branchTotalLoss_TP(dt,br) ] ;

        o_HVDCflow_TP(dt,ild)
            = sum[ (br,frB,toB)
                 $ { HVDCpoles(currTP,br) and busIsland(currTP,frB,ild)
                 and branchBusDefn(currTP,br,frB,toB)
                   }, o_branchFlow_TP(dt,br) ] ;

        o_HVDChalfPoleLoss_TP(dt,ild)
            = sum[ (br,frB,toB) $ { HVDChalfPoles(currTP,br) and
                                    branchBusDefn(currTP,br,frB,toB) and
                                    busIsland(currTP,toB,ild) and
                                    busIsland(currTP,frB,ild)
                                      }, o_branchTotalLoss_TP(dt,br)
                 ] ;

        o_HVDCpoleFixedLoss_TP(dt,ild)
            = sum[ (br,frB,toB) $ { HVDCpoles(currTP,br) and
                                    branchBusDefn(currTP,br,frB,toB) and
                                    ( busIsland(currTP,toB,ild) or
                                      busIsland(currTP,frB,ild)
                                    )
                                  }, 0.5 * o_branchFixedLoss_TP(dt,br)
                 ] ;

        o_HVDCloss_TP(dt,ild)
            = o_HVDChalfPoleLoss_TP(dt,ild)
            + o_HVDCpoleFixedLoss_TP(dt,ild)
            + sum[ (br,frB,toB) $ { HVDClink(currTP,br) and
                                    branchBusDefn(currTP,br,frB,toB) and
                                    busIsland(currTP,toB,ild) and
                                    (not (busIsland(currTP,frB,ild)))
                                  }, o_branchDynamicLoss_TP(dt,br)
                 ] ;

* TN - The code below is added for NMIR project ================================
        o_EffectiveRes_TP(dt,ild,resC,riskC) $ reserveShareEnabled(currTP,resC)
            = RESERVESHAREEFFECTIVE.l(currTP,ild,resC,riskC) ;

        If Sum[ resC $ (ord(resC) = 1), reserveShareEnabled(currTP,resC)] then

            o_FirSent_TP(dt,ild)
                = Sum[ (rd,resC) $ (ord(resC) = 1)
                     , RESERVESHARESENT.l(currTP,ild,resC,rd)];

            o_FirReceived_TP(dt,ild)
                = Sum[ (rd,resC) $ (ord(resC) = 1)
                     , RESERVESHARERECEIVED.l(currTP,ild,resC,rd) ];

            o_FirEffective_TP(dt,ild,riskC)
                = Sum[ resC $ (ord(resC) = 1),
                       RESERVESHAREEFFECTIVE.l(currTP,ild,resC,riskC) ];

            o_FirEffReport_TP(dt,ild)
                = Smax[ (resC,riskC) $ (ord(resC)=1)
                     , RESERVESHAREEFFECTIVE.l(currTP,ild,resC,riskC) ];

        Endif;

        If Sum[ resC $ (ord(resC) = 2), reserveShareEnabled(currTP,resC)] then

            o_SirSent_TP(dt,ild)
                = Sum[ (rd,resC) $ (ord(resC) = 2),
                       RESERVESHARESENT.l(currTP,ild,resC,rd) ];

            o_SirReceived_TP(dt,ild)
                = Sum[ (fd,resC) $ (ord(resC) = 2),
                       RESERVESHARERECEIVED.l(currTP,ild,resC,fd) ];

            o_SirEffective_TP(dt,ild,riskC)
                = Sum[ resC $ (ord(resC) = 2),
                       RESERVESHAREEFFECTIVE.l(currTP,ild,resC,riskC) ];

            o_SirEffReport_TP(dt,ild)
                = Smax[ (resC,riskC) $ (ord(resC)=2)
                     , RESERVESHAREEFFECTIVE.l(currTP,ild,resC,riskC) ];
        Endif;


* TN - The code for NMIR project end ===========================================

*       Additional output for audit reporting
        o_ACbusAngle(dt,b) = ACNODEANGLE.l(currTP,b) ;

*       Check if there are non-physical losses on AC branches
        ManualBranchSegmentMWFlow(LossBranch(ACbranch(currTP,br)),los,fd)
                $ { ( ord(los) <= branchLossBlocks(ACbranch) )
                and validLossSegment(ACbranch,los,fd)
                and ( ACBRANCHFLOWDIRECTED.l(ACbranch,fd) > 0 )
                  }
                = Min[ Max( 0,
                            [ abs(o_branchFlow_TP(dt,br))
                            - [LossSegmentMW(ACbranch,los-1,fd) $ (ord(los) > 1)]
                            ]
                          ),
                       ( LossSegmentMW(ACbranch,los,fd)
                       - [LossSegmentMW(ACbranch,los-1,fd) $ (ord(los) > 1)]
                       )
                     ] ;

        ManualBranchSegmentMWFlow(LossBranch(HVDClink(currTP,br)),los,fd)
                $ { ( ord(los) <= branchLossBlocks(HVDClink) )
                and validLossSegment(HVDClink,los,fd) and ( ord(fd) = 1 )
                  }
                = Min[ Max( 0,
                            [ abs(o_branchFlow_TP(dt,br))
                            - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                            ]
                          ),
                       ( LossSegmentMW(HVDClink,los,fd)
                       - [LossSegmentMW(HVDClink,los-1,fd) $ (ord(los) > 1)]
                       )
                     ] ;

        ManualLossCalculation(LossBranch(branch(currTP,br)))
            = sum[ (los,fd), LossSegmentFactor(branch,los,fd)
                           * ManualBranchSegmentMWFlow(branch,los,fd) ] ;

        o_nonPhysicalLoss(dt,br) = o_branchDynamicLoss_TP(dt,br)
                                 - ManualLossCalculation(currTP,br) ;

        o_lossSegmentBreakPoint(dt,br,los)
            = sum [ fd $ { validLossSegment(currTP,br,los,fd)
                       and (ord(fd) = 1)
                         }, LossSegmentMW(currTP,br,los,fd) ] $ { o_branchFlow_TP(dt,br) >= 0 }
            + sum [ fd $ { validLossSegment(currTP,br,los,fd)
                       and (ord(fd) = 2)
                         }, LossSegmentMW(currTP,br,los,fd) ] $ { o_branchFlow_TP(dt,br) < 0 }
        ;

        o_lossSegmentFactor(dt,br,los)
            = sum [ fd $ { validLossSegment(currTP,br,los,fd)
                       and (ord(fd) = 1)
                         }, LossSegmentFactor(currTP,br,los,fd) ] $ { o_branchFlow_TP(dt,br) >= 0 }
            + sum [ fd $ { validLossSegment(currTP,br,los,fd)
                       and (ord(fd) = 2)
                         }, LossSegmentFactor(currTP,br,los,fd) ] $ { o_branchFlow_TP(dt,br) < 0 }
        ;

        o_busIsland_TP(dt,b,ild) $ busIsland(currTP,b,ild) = yes ;

        o_PLRO_FIR_TP(dt,o) $ offer(currTP,o)
            = sum[(resC,PLSRReserveType) $ (ord(resC)=1)
                 , RESERVE.l(currTP,o,resC,PLSRReserveType) ] ;

        o_PLRO_SIR_TP(dt,o) $ offer(currTP,o)
            = sum[(resC,PLSRReserveType) $ (ord(resC)=2)
                 , RESERVE.l(currTP,o,resC,PLSRReserveType)] ;

        o_TWRO_FIR_TP(dt,o) $ offer(currTP,o)
            = sum[(resC,TWDRReserveType) $ (ord(resC)=1)
                 , RESERVE.l(currTP,o,resC,TWDRReserveType)] ;

        o_TWRO_SIR_TP(dt,o) $ offer(currTP,o)
            = sum[(resC,TWDRReserveType) $ (ord(resC)=2)
                 , RESERVE.l(currTP,o,resC,TWDRReserveType)] ;

        o_ILRO_FIR_TP(dt,o) $ offer(currTP,o)
            = sum[ (resC,ILReserveType) $ (ord(resC)=1)
                 , RESERVE.l(currTP,o,resC,ILReserveType)] ;

        o_ILRO_SIR_TP(dt,o) $ offer(currTP,o)
            = sum[ (resC,ILReserveType) $ (ord(resC)=2)
                 , RESERVE.l(currTP,o,resC,ILReserveType)] ;

        o_ILbus_FIR_TP(dt,b) = sum[ (o,n) $ { NodeBus(currTP,n,b) and
                                              offerNode(currTP,o,n)
                                            }, o_ILRO_FIR_TP(dt,o) ] ;

        o_ILbus_SIR_TP(dt,b) = sum[ (o,n) $ { NodeBus(currTP,n,b) and
                                              offerNode(currTP,o,n)
                                            }, o_ILRO_SIR_TP(dt,o) ] ;

        o_marketNodeIsland_TP(dt,o,ild)
            $ sum[ n $ { offerIsland(currTP,o,ild) and
                         offerNode(currTP,o,n) and
                         (o_nodeLoad_TP(dt,n)  = 0)
                       },1
                 ] = yes ;

        o_generationRiskLevel(dt,ild,o,resC,GenRisk)
            = GENISLANDRISK.l(currTP,ild,o,resC,GenRisk)
            + RESERVESHAREEFFECTIVE.l(currTP,ild,resC,GenRisk)
            ;

        o_generationRiskPrice(dt,ild,o,resC,GenRisk)
            = GenIslandRiskCalculation_1.m(currTP,ild,o,resC,GenRisk) ;

        o_HVDCriskLevel(dt,ild,resC,HVDCrisk)
            = ISLANDRISK.l(currTP,ild,resC,HVDCrisk) ;

        o_HVDCriskPrice(dt,ild,resC,HVDCrisk)
            = HVDCIslandRiskCalculation.m(currTP,ild,resC,HVDCrisk) ;

        o_manuRiskLevel(dt,ild,resC,ManualRisk)
            = ISLANDRISK.l(currTP,ild,resC,ManualRisk)
            + RESERVESHAREEFFECTIVE.l(currTP,ild,resC,ManualRisk)
            ;

        o_manuRiskPrice(dt,ild,resC,ManualRisk)
            = ManualIslandRiskCalculation.m(currTP,ild,resC,ManualRisk) ;

        o_genHVDCriskLevel(dt,ild,o,resC,HVDCsecRisk)
            = HVDCGENISLANDRISK.l(currTP,ild,o,resC,HVDCsecRisk) ;

        o_genHVDCriskPrice(dt,ild,o,resC,HVDCsecRisk(riskC))
            = HVDCIslandSecRiskCalculation_GEN_1.m(currTP,ild,o,resC,riskC) ;

        o_manuHVDCriskLevel(dt,ild,resC,HVDCsecRisk)
            = HVDCMANISLANDRISK.l(currTP,ild,resC,HVDCsecRisk);

        o_manuHVDCriskPrice(dt,ild,resC,HVDCsecRisk(riskC))
            = HVDCIslandSecRiskCalculation_Manu_1.m(currTP,ild,resC,riskC) ;

        o_generationRiskGroupLevel(dt,ild,rg,resC,GenRisk)
            $ islandRiskGroup(currTP,ild,rg,GenRisk)
            = GENISLANDRISKGROUP.l(currTP,ild,rg,resC,GenRisk)
            + RESERVESHAREEFFECTIVE.l(currTP,ild,resC,GenRisk)
            ;

        o_generationRiskGroupPrice(dt,ild,rg,resC,GenRisk)
            $ islandRiskGroup(currTP,ild,rg,GenRisk)
            = GenIslandRiskGroupCalculation_1.m(currTP,ild,rg,resC,GenRisk) ;

*       FIR and SIR required based on calculations of the island risk to
*       overcome reporting issues of the risk setter under degenerate
*       conditions when reserve price = 0 - See below

        o_ReserveReqd_TP(dt,ild,resC)
            = Max[ 0,
                   smax[(o,GenRisk)     , o_generationRiskLevel(dt,ild,o,resC,GenRisk)],
                   smax[ HVDCrisk       , o_HVDCriskLevel(dt,ild,resC,HVDCrisk) ] ,
                   smax[ ManualRisk     , o_manuRiskLevel(dt,ild,resC,ManualRisk) ] ,
                   smax[ (o,HVDCsecRisk), o_genHVDCriskLevel(dt,ild,o,resC,HVDCsecRisk) ] ,
                   smax[ HVDCsecRisk    , o_manuHVDCriskLevel(dt,ild,resC,HVDCsecRisk)  ] ,
                   smax[ (rg,GenRisk)   , o_generationRiskGroupLevel(dt,ild,rg,resC,GenRisk)  ]
                 ] ;

        o_FIRreqd_TP(dt,ild) = sum[ resC $ (ord(resC)=1), o_ReserveReqd_TP(dt,ild,resC) ] ;
        o_SIRreqd_TP(dt,ild) = sum[ resC $ (ord(resC)=2), o_ReserveReqd_TP(dt,ild,resC) ] ;

*       Summary reporting by trading period
        o_solveOK_TP(dt) = ModelSolved ;

        o_systemCost_TP(dt) = SYSTEMCOST.l(currTP) ;

        o_systemBenefit_TP(dt) = SYSTEMBENEFIT.l(currTP) ;

        o_penaltyCost_TP(dt) = SYSTEMPENALTYCOST.l(currTP) ;

        o_ofv_TP(dt) = o_systemBenefit_TP(dt)
                     - o_systemCost_TP(dt)
                     - o_penaltyCost_TP(dt);


*       Separete violation reporting at trade period level
        o_defGenViolation_TP(dt) = sum[ b, o_busDeficit_TP(dt,b) ] ;

        o_surpGenViolation_TP(dt) = sum[ b, o_busSurplus_TP(dt,b) ] ;

        o_surpBranchFlow_TP(dt)
            = sum[ br$branch(currTP,br), SURPLUSBRANCHFLOW.l(currTP,br) ] ;

        o_defRampRate_TP(dt)
            = sum[ o $ offer(currTP,o), DEFICITRAMPRATE.l(currTP,o) ] ;

        o_surpRampRate_TP(dt)
            = sum[ o $ offer(currTP,o), SURPLUSRAMPRATE.l(currTP,o) ] ;

        o_surpBranchGroupConst_TP(dt)
            = sum[ brCstr $ branchConstraint(currTP,brCstr)
                 , SURPLUSBRANCHSECURITYCONSTRAINT.l(currTP,brCstr) ] ;

        o_defBranchGroupConst_TP(dt)
            = sum[ brCstr $ branchConstraint(currTP,brCstr)
                 , DEFICITBRANCHSECURITYCONSTRAINT.l(currTP,brCstr) ] ;

        o_defMnodeConst_TP(dt)
            = sum[ MnodeCstr $ MnodeConstraint(currTP,MnodeCstr)
                 , DEFICITMnodeCONSTRAINT.l(currTP,MnodeCstr) ] ;

        o_surpMnodeConst_TP(dt)
            = sum[ MnodeCstr $ MnodeConstraint(currTP,MnodeCstr)
                 , SURPLUSMnodeCONSTRAINT.l(currTP,MnodeCstr) ] ;

        o_defACnodeConst_TP(dt)
            = sum[ ACnodeCstr $ ACnodeConstraint(currTP,ACnodeCstr)
                 , DEFICITACnodeCONSTRAINT.l(currTP,ACnodeCstr) ] ;

        o_surpACnodeConst_TP(dt)
            = sum[ ACnodeCstr $ ACnodeConstraint(currTP,ACnodeCstr)
                 , SURPLUSACnodeCONSTRAINT.l(currTP,ACnodeCstr) ] ;

        o_defT1MixedConst_TP(dt)
            = sum[ t1MixCstr $ Type1MixedConstraint(currTP,t1MixCstr)
                 , DEFICITTYPE1MIXEDCONSTRAINT.l(currTP,t1MixCstr) ] ;

        o_surpT1MixedConst_TP(dt)
            = sum[ t1MixCstr $ Type1MixedConstraint(currTP,t1MixCstr)
                 , SURPLUSTYPE1MIXEDCONSTRAINT.l(currTP,t1MixCstr) ] ;

        o_defGenericConst_TP(dt)
            = sum[ gnrcCstr $ GenericConstraint(currTP,gnrcCstr)
                 , DEFICITGENERICCONSTRAINT.l(currTP,gnrcCstr) ] ;

        o_surpGenericConst_TP(dt)
            = sum[ gnrcCstr $ GenericConstraint(currTP,gnrcCstr)
                 , SURPLUSGENERICCONSTRAINT.l(currTP,gnrcCstr) ] ;

        o_defResv_TP(dt)
            = sum[ (ild,resC) , o_ResViolation_TP(dt,ild,resC) ] ;

        o_totalViolation_TP(dt)
            = o_defGenViolation_TP(dt) + o_surpGenViolation_TP(dt)
            + o_defRampRate_TP(dt) + o_surpRampRate_TP(dt)
            + o_defBranchGroupConst_TP(dt) + o_surpBranchGroupConst_TP(dt)
            + o_defMnodeConst_TP(dt) + o_surpMnodeConst_TP(dt)
            + o_defACnodeConst_TP(dt) + o_surpACnodeConst_TP(dt)
            + o_defT1MixedConst_TP(dt) + o_surpT1MixedConst_TP(dt)
            + o_defGenericConst_TP(dt) + o_surpGenericConst_TP(dt)
            + o_defResv_TP(dt) + o_surpBranchFlow_TP(dt) ;

*       Virtual reserve
        o_vrResMW_TP(dt,ild,resC) = VIRTUALRESERVE.l(currTP,ild,resC) ;

        o_FIRvrMW_TP(dt,ild) = sum[ resC $ (ord(resC) = 1)
                                  , o_vrResMW_TP(dt,ild,resC) ] ;

        o_SIRvrMW_TP(dt,ild) = sum[ resC $ (ord(resC) = 2)
                                  , o_vrResMW_TP(dt,ild,resC) ] ;

*   Reporting at trading period end
    EndLoop;
$offend

$endif.PeriodReport

* End of the solve vSPD loop
  ] ;
* End of the While loop
);


* Real Time Pricing - Second RTD load calculation

*   Calculate Island-level MW losses used to calculate the Island-level load
*   forecast from the InputIPS and the IslandPSD.
*   2nd solve loop --> SystemLosses as calculated in section 6.3'
    LoadCalcLosses(currTP,ild)
        = Sum[ (br,frB,toB)
             $ { ACbranch(currTP,br) and busIsland(currTP,toB,ild)
             and branchBusDefn(currTP,br,frB,toB)
               }, sum[ fd, ACBRANCHLOSSESDIRECTED.l(currTP,br,fd) ]
                + branchFixedLoss(currTP,br)
             ]
        + Sum[ (br,frB,toB) $ { HVDChalfPoles(currTP,br) and
                                branchBusDefn(currTP,br,frB,toB) and
                                busIsland(currTP,toB,ild) and
                                busIsland(currTP,frB,ild)
                              }, sum[ fd, ACBRANCHLOSSESDIRECTED.l(currTP,br,fd) ]
                               + HVDCLINKLOSSES.l(currTP,br)
                               + branchFixedLoss(currTP,br)
             ]
        + Sum[ (br,frB,toB) $ { HVDCpoles(currTP,br) and
                                branchBusDefn(currTP,br,frB,toB) and
                                ( busIsland(currTP,toB,ild) or
                                  busIsland(currTP,frB,ild)
                                )
                              }, 0.5 * branchFixedLoss(currTP,br)
             ]
        + Sum[ (br,frB,toB) $ { HVDClink(currTP,br) and
                                branchBusDefn(currTP,br,frB,toB) and
                                busIsland(currTP,toB,ild) and
                                (not (busIsland(currTP,frB,ild)))
                              }, HVDCLINKLOSSES.l(currTP,br)
             ]
          ;


*   Calculate first target total load [3.8.5.5]
*   Island-level MW load forecast. For the second loop:
*   replace LoadCalcLosses(tp,ild) = islandLosses(tp,ild);
    TargetTotalLoad(currTP,ild) = islandMWIPS(currTP,ild) + islandPDS(currTP,ild) - LoadCalcLosses(currTP,ild) ;

*   Flag if estimate load is scalable [3.8.5.7]
*   Binary value. If True then ConformingFactor load MW will be scaled in order to
*   calculate EstimatedInitialLoad. If False then EstNonScalableLoad will be
*   assigned directly to EstimatedInitialLoad
    EstLoadIsScalable(currTP,n) =  1 $ { (LoadIsNCL(currTP,n) = 0)
                                     and (ConformingFactor(currTP,n) > 0) } ;

*   Calculate estimate non-scalable load [3.8.5.8]
*   For a non-conforming Pnode this will be the NonConformingLoad MW input, for a
*   conforming Pnode this will be the ConformingFactor MW input if that value is
*   negative, otherwise it will be zero
    EstNonScalableLoad(currTP,n) $ ( LoadIsNCL(currTP,n) = 1 ) = NonConformingLoad(currTP,n);
    EstNonScalableLoad(currTP,n) $ ( LoadIsNCL(currTP,n) = 0 ) = ConformingFactor(currTP,n);
    EstNonScalableLoad(currTP,n) $ ( EstLoadIsScalable(currTP,n) = 1 ) = 0;

*   Calculate estimate scalable load [3.8.5.10]
*   For a non-conforming Pnode this value will be zero. For a conforming Pnode
*   this value will be the ConformingFactor if it is non-negative, otherwise this
*   value will be zero'
    EstScalableLoad(currTP,n) $ ( EstLoadIsScalable(currTP,n) = 1 ) = ConformingFactor(currTP,n);


*   Calculate Scaling applied to ConformingFactor load MW [3.8.5.9]
*   in order to calculate EstimatedInitialLoad
    EstScalingFactor(currTP,ild)
        = (islandMWIPS(currTP,ild) - LoadCalcLosses(currTP,ild)
          - Sum[ n $ nodeIsland(currTP,n,ild), EstNonScalableLoad(currTP,n) ]
          ) / Sum[ n $ nodeIsland(currTP,n,ild), EstScalableLoad(currTP,n) ]

        ;

*   Calculate estimate initial load [3.8.5.6]
*   Calculated estimate of initial MW load, available to be used as an
*   alternative to InputInitialLoad
    EstimatedInitialLoad(currTP,n) $ ( EstLoadIsScalable(currTP,n) = 1 )
        = ConformingFactor(currTP,n) * Sum[ ild $ nodeisland(currTP,n,ild)
                                          , EstScalingFactor(currTP,ild)] ;
* TN- There is a bug in this equarion
    EstimatedInitialLoad(currTP,n) $ ( EstLoadIsScalable(currTP,n) = 0 )
*        = NonConformingLoad(currTP,n);
        = EstNonScalableLoad(currTP,n);

*   Calculate initial load [3.8.5.2]
*   Value that represents the Pnode load MW at the start of the solution
*   interval. Depending on the inputs this value will be either actual load,
*   an operator applied override or an estimated initial load
    InitialLoad(currTP,n) = InputInitialLoad(currTP,n);
    InitialLoad(currTP,n) $ { (LoadIsOverride(currTP,n) = 0)
                          and ( (useActualLoad(currTP) = 0)
                             or (LoadIsBad(currTP,n) = 1) )
                            } = EstimatedInitialLoad(currTP,n) ;

*   Flag if load is scalable [3.8.5.4]
*   Binary value. If True then the Pnode InitialLoad will be scaled in order to
*   calculate nodedemand, if False then Pnode InitialLoad will be directly
*   assigned to nodedemand
    LoadIsScalable(currTP,n) = 1 $ { (LoadIsNCL(currTP,n) = 0)
                                 and (LoadIsOverride(currTP,n) = 0)
                                 and (InitialLoad(currTP,n) >= 0) } ;

*   Calculate Island-level scaling factor [3.8.5.3]
*   --> applied to InitialLoad in order to calculate nodedemand
    LoadScalingFactor(currTP,ild)
        = ( TargetTotalLoad(currTP,ild)
          - Sum[ n $ { nodeIsland(currTP,n,ild)
                   and (LoadIsScalable(currTP,n) = 0) }, InitialLoad(currTP,n) ]
          ) / Sum[ n $ { nodeIsland(currTP,n,ild)
                     and (LoadIsScalable(currTP,n) = 1) }, InitialLoad(currTP,n) ]
        ;

*   Calculate nodedemand [3.8.5.1]
    nodedemand(currTP,n) $ LoadIsScalable(currTP,n)
        = InitialLoad(currTP,n) * sum[ ild $ nodeisland(currTP,n,ild)
                                 , LoadScalingFactor(currTP,ild) ];

    nodedemand(currTP,n) $ (LoadIsScalable(currTP,n) = 0) = InitialLoad(currTP,n);


*   Update Free Reserve and SharedNFRmax
*   Pre-processing: Shared Net Free Reserve (NFR) calculation - NMIR (5.2.1.2)
    sharedNFRLoad(currTP,ild)
        = sum[ nodeIsland(currTP,n,ild), nodeDemand(currTP,n)]
        + sum[ (bd,trdBlk) $ bidIsland(currTP,bd,ild), purchaseBidMW(currTP,bd,trdBlk) ]
        - sharedNFRLoadOffset(currTP,ild) ;

    sharedNFRMax(currTP,ild) = Min{ RMTReserveLimitTo(currTP,ild,'FIR'),
                                    sharedNFRFactor(currTP)*sharedNFRLoad(currTP,ild) } ;

*   Risk parameters
    FreeReserve(currTP,ild,resC,riskC)
        = sum[ riskPar $ (ord(riskPar) = 1)
                       , i_tradePeriodRiskParameter(currTP,ild,resC,riskC,riskPar) ]
*   NMIR - Subtract shareNFRMax from current NFR -(5.2.1.4) - SPD version 11
        - sum[ ild1 $ (not sameas(ild,ild1)),sharedNFRMax(currTP,ild1)
             ] $ { (ord(resC)=1) and ( (GenRisk(riskC)) or (ManualRisk(riskC)) )
               and (inputGDXGDate >= jdate(2016,10,20)) }
    ;

*   (3.4.2.3) - SPD version 11.0
    SHAREDNFR.up(currTP,ild) = Max[0,sharedNFRMax(currTP,ild)] ;

*);



