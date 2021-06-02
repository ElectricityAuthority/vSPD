*=====================================================================================
* Name:                 vSPDSolveFTR_3.gms
* Function:             Collect and store vSPD results for the FTR rental mode
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: http://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Last modified on:     03 June 2021
*=====================================================================================

*   Store results for FTR reporting at a trade period level
    loop(i_DateTimeTradePeriodMap(dt,currTP) $ (not unsolvedPeriod(currTP)),

        o_busPrice_TP(dt,b) $ bus(currTP,b) = round(busPrice(currTP,b),4) ;

*       branch data
        o_branch(dt,br) $ Branch(currTP,br) = yes;

        o_HVDClink(dt,br) $ HVDCLink(currTP,br) = yes;

        o_branchFlow_TP(dt,br) $ ACBranch(currTP,br) = ACBRANCHFLOW.l(currTP,br);
        o_branchFlow_TP(dt,br) $ HVDCLink(currTP,br) = HVDCLINKFLOW.l(currTP,br);
        o_branchFlow_TP(dt,br) = Round(o_BranchFlow_TP(dt,br),3) ;

        o_branchDynamicLoss_TP(dt,br)
            $ HVDCLink(currTP,br)
            = HVDCLINKLOSSES.l(currTP,br);

        o_branchMarginalPrice_TP(dt,br) $ ACBranch(currTP,br)
            = sum[ fd, Round(ACBranchMaximumFlow.m(currTP,br,fd), 4) ];

        o_branchCapacity_TP(dt,br) $ Branch(currTP,br)
            = i_TradePeriodBranchCapacity(currTP,br);

        o_BranchTotalLoss_TP(dt,br)
            $ ACBranch(currTP,br)
            = branchFixedLoss(currTP,br)
            + sum[ fd, ACBRANCHLOSSESDIRECTED.l(currTP,br,fd) ];

*       Security constraint data
        o_brConstraint_TP(dt,brCstr) $ BranchConstraint(currTP,brCstr) = yes;

        o_brConstraintRHS_TP(dt,brCstr)
            $ { BranchConstraint(currTP,brCstr) and
               (BranchConstraintSense(currTP,brCstr) = -1) }
            = branchConstraintLimit(currTP,brCstr) ;

        o_brConstraintPrice_TP(dt,brCstr)
            $ { BranchConstraint(currTP,brCstr) and
               (BranchConstraintSense(currTP,brCstr) = -1) }
            = Round(BranchSecurityConstraintLE.m(currTP,brCstr), 4);

        o_brConstraintLHS_TP(dt,brCstr)
            $ { BranchConstraint(currTP,brCstr) and
               (BranchConstraintSense(currTP,brCstr) = -1) }
            = sum[ br $ ACbranch(currTP,br)
                 , BranchConstraintFactors(currTP,brCstr,br)
                 * o_branchFlow_TP(dt,br)
                 ] $ o_brConstraintPrice_TP(dt,brCstr) ;

*       AC branch loss segment
        o_ACbranchLossMW(dt,br,los) $ ACbranch(currTP,br)
            = ACBranchLossMW(currTP,br,los,'forward') $ (o_branchFlow_TP(dt,br) >= 0)
            + ACBranchLossMW(currTP,br,los,'backward') $ (o_branchFlow_TP(dt,br) < 0);

        o_ACbranchLossFactor(dt,br,los) $ ACbranch(currTP,br)
            = ACBranchLossFactor(currTP,br,los,'forward') $ (o_branchFlow_TP(dt,br) >= 0)
            + ACBranchLossFactor(currTP,br,los,'backward') $ (o_branchFlow_TP(dt,br) < 0);
    ) ;
