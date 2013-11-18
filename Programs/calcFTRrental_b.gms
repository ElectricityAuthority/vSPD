*=====================================================================================
* Name:                 calcFTRrental_b.gms
* Function:             Solve the FTR model
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://reports.ea.govt.nz/EMIIntro.htm
* Last modified on:     18 November 2013
*=====================================================================================

* Set the bratio to 1 i.e. do not use advanced basis for LP
  option bratio = 1;

* Set resource limits
  SPD_FTR.reslim = LPTimeLimit;
  vSPD_FTR.iterlim = LPIterationLimit;
  Solve vSPD_FTR using lp maximizing NETBENEFIT;

* Set the model solve status
  ModelSolved = 1 $ ((vSPD_FTR.modelstat = 1) and (vSPD_FTR.solvestat = 1)) ;

* Post a progress message to report for use by GUI and to the console.
  if((ModelSolved = 1) and (i_SequentialSolve = 0),
    putclose runlog / 'The case: %vSPDInputData% finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                      'Violation Cost: ' TOTALPENALTYCOST.l:<12:1 /
  elseif((ModelSolved = 0) and (i_SequentialSolve = 0)),
    putclose runlog / 'The case: %vSPDInputData% finished at ', system.time '. Solve unsuccessful.' /
  ) ;

  if((ModelSolved = 1) and (i_SequentialSolve = 1),
    loop(CurrentTradePeriod(i_TradePeriod),
      putclose runlog / 'The case: %vSPDInputData% (' CurrentTradePeriod.tl ') finished at ', system.time '. Solve successful.' / 'Objective function value: ' NETBENEFIT.l:<12:1 /
                        'Violations: ' TOTALPENALTYCOST.l:<12:1 /
    ) ;
  elseif((ModelSolved = 0) and (i_SequentialSolve = 1)),
    loop(CurrentTradePeriod(i_TradePeriod),
      putclose runlog / 'The case: %vSPDInputData% (' CurrentTradePeriod.tl ') finished at ', system.time '. Solve unsuccessful.' /
    ) ;
  ) ;

* Store reslts for FTR reporting at a trade period level
  loop(i_DateTimeTradePeriodMap(i_DateTime,CurrentTradePeriod),

* Branch data
    o_BranchFlow_TP(i_DateTime,i_Branch) $ ACBranch(CurrentTradePeriod,i_Branch) = ACBRANCHFLOW.l(CurrentTradePeriod,i_Branch) ;
    o_BranchFlow_TP(i_DateTime,i_Branch) $ HVDCLink(CurrentTradePeriod,i_Branch) = HVDCLINKFLOW.l(CurrentTradePeriod,i_Branch) ;

* Security constraint data
    o_BrConstraintLHS_TP(i_DateTime,i_BranchConstraint) $ BranchConstraint(CurrentTradePeriod,i_BranchConstraint) = BranchSecurityConstraintLE.l(CurrentTradePeriod,i_BranchConstraint) $ (BranchConstraintSense(CurrentTradePeriod,i_BranchConstraint) = -1) ;

* End of loop
  ) ;

* End of if statement to determine which periods to solve
  ) ;

* End of main for statement
  ) ;


* 10.b. --> FTR Output --> Store all AC branch flows and AC branch constraint LHS's
execute_unload '%outputPath%%runName%\runNum%vSPDrunNum%_branchOutput_TP.gdx' o_BranchFlow_TP o_BrConstraintLHS_TP
