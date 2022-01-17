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

if (studyMode = 101,
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
                            'is solved successfully.'/
                            'Objective function value: '
                            NETBENEFIT.l:<12:1 /
                            'Violation Cost          : '
                            TOTALPENALTYCOST.l:<12:1 /
        elseif((ModelSolved = 0) and (sequentialSolve = 0)),
            putclose runlog 'The case: %vSPDinputData% '
                            'is solved unsuccessfully.'/
        ) ;

        if((ModelSolved = 1) and (sequentialSolve = 1),
            loop(currTP,
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is solved successfully.'/
                                'Objective function value: '
                                NETBENEFIT.l:<12:1 /
                                'Violations cost         : '
                                TOTALPENALTYCOST.l:<12:1 /
            ) ;
        elseif((ModelSolved = 0) and (sequentialSolve = 1)),
            loop(currTP,
                unsolvedPeriod(currTP) = no;
                putclose runlog 'The case: %vSPDinputData% (' currTP.tl ') '
                                'is solved unsuccessfully.'/
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
                                'is solved successfully for FULL integer.'/
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
                                'is solved unsuccessfully for FULL integer.'/
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
                                'is solved successfully for branch integer.'/
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
                                'is solved unsuccessfully for branch integer.'/
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
                                'is solved successfully for '
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
                                'is solved unsuccessfully for '
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
*   Island-level MW load forecast. For the fist loop:
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
    EstimatedInitialLoad(currTP,n) $ ( EstLoadIsScalable(currTP,n) = 0 )
        = NonConformingLoad(currTP,n);

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

);



