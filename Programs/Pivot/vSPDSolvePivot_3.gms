*=====================================================================================
* Name:                 vSPDSolvePivot_3.gms
* Function:             Collect and store results for net pivotal analysis
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     23 Sept 2016
* Note:                 This code will be included to the end of period report
*                       section in vSPDSolve to produce output for net pivotal analysis.
*=====================================================================================

$onend
    Loop i_dateTimeTradePeriodMap(dt,currTP) $ (not unsolvedPeriod(currTP)) do

        o_node(dt,n) $ {Node(currTP,n) and (not HVDCnode(currTP,n))} = yes ;

        o_offer(dt,o) $ offer(currTP,o) = yes ;

*       Mapping pivot scenario to trader, island and offer for each period
        o_pivotMapping(dt,pvt,trdr,ild,o) = yes $ { pivotTrader(pvt,trdr)
                                                and pivotOffer(pvt,ild,o) } ;

*       Total scheduled GEN form pivotal provider
        o_pivotIslandGen(dt,pvt,ild)
          = sum[ offer(currTP,o) $ pivotOffer(pvt,ild,o), GENERATION.l(currTP,o) ] ;

*       Minimum generation required for FK from pivotal provider
        o_pivotIslandMin(dt,pvt,ild)
          = sum[ MnodeCstr $ { pivotMnCstr(pvt,ild,MnodeCstr)
                           and MnodeConstraint(currTP,MnodeCstr) }
                           , MnodeConstraintLimit(currTP,MnodeCstr) ] ;

*       Total pivot generation --> this is questionable item
        o_pivotIslandMW(dt,pvt,ild)
          = o_pivotIslandGen(dt,pvt,ild) - o_pivotIslandMin(dt,pvt,ild) ;

*       Total scheduled FIR form pivotal provider
        o_pivotFir(dt,pvt,ild)
          = sum[ (o,resC,resT)
               $ { pivotOffer(pvt,ild,o) and (ord(resC) = 1) }
               , RESERVE.l(currTP,o,resC,resT) ] ;

*       Total scheduled SIR form pivotal provider
        o_pivotSir(dt,pvt,ild)
          = sum[ (o,resC,resT)
               $ { pivotOffer(pvt,ild,o) and (ord(resC) = 2) }
               , RESERVE.l(currTP,o,resC,resT) ] ;

*       FIR price for pivot island
        o_pivotFirPr(dt,pvt,ild)
          = sum[ resC $ (ord(resC) = 1)
               , IslandReserveCalculation.m(currTP,ild,resC)
               ];

*       SIR price for pivot island
        o_pivotSirPr(dt,pvt,ild)
          = sum[ resC $ (ord(resC) = 2)
               , IslandReserveCalculation.m(currTP,ild,resC)
               ];

*       Energy nodal price for pivot island
        o_pivotNodePrice(dt,pvt,n)
          = sum[ b $ NodeBus(currTP,n,b)
               , NodeBusAllocationFactor(currTP,n,b) * busPrice(currTP,b)
               ];

*       Energy offer cleared for pivot offers
        o_pivotOfferGen(dt,pvt,o) $ offer(currTP,o)
          = GENERATION.l(currTP,o);

    EndLoop;

$offend
