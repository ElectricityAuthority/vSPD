*=====================================================================================
* Name:                 vSPDSolveFTR_3a.gms
* Function:             Collect and store SPD price relating results for the FTR
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: http://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Last modified on:     23 Sept 2016
*=====================================================================================

loop(i_dateTimeTradePeriodMap(dt,tp),
*   branch output update
    o_branchFromBusPrice_TP(dt,br) $ branch(tp,br)
        = sum[ (b,toB) $ branchBusDefn(tp,br,b,toB), o_busPrice_TP(dt,b) ] ;

    o_branchToBusPrice_TP(dt,br) $ branch(tp,br)
        = sum[ (frB,b) $ branchBusDefn(tp,br,frB,b), o_busPrice_TP(dt,b) ] ;

    o_BranchTotalRentals_TP(dt,br) $ ACBranch(tp,br)
        = [ o_branchFlow_TP(dt,br)
          * ( o_branchToBusPrice_TP(dt,br) - o_branchFromBusPrice_TP(dt,br) )
          - o_BranchTotalLoss_TP(dt,br)
          * ( o_branchToBusPrice_TP(dt,br)$(o_branchFlow_TP(dt,br) >= 0)
            + o_branchFromBusPrice_TP(dt,br)$(o_branchFlow_TP(dt,br) < 0)
            )
          ] * ( i_TradingPeriodLength / 60 ) ;

    o_ACbranchTotalRentals(dt) = sum[ br, o_BranchTotalRentals_TP(dt,br) ];

) ;

