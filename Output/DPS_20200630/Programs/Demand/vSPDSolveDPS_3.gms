*=====================================================================================
* Name:                 vSPDSolveDPS_3.gms
* Function:             Collect and store results for demand sensitivity analysis
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     23 Sept 2016
* Note:                 This code will be included to the end of period report
*                       section in vSPDSolve to produce output for pivot analysis
*=====================================================================================
$onend
    Loop i_dateTimeTradePeriodMap(dt,currTP) $ (not unsolvedPeriod(currTP)) do

        o_nodeGeneration_TP(dt,n) $ Node(currTP,n)
          = sum[ o $ offerNode(currTP,o,n), GENERATION.l(currTP,o) ] ;

        o_nodePrice_TP(dt,n) $ Node(currTP,n)
          = sum[ b $ NodeBus(currTP,n,b)
               , NodeBusAllocationFactor(currTP,n,b) * busPrice(currTP,b)
               ] ;

*       Get price at each reference pricng node for each demand scenario
        o_drsnodeprice(dt,drs,pricing_nodes(n)) = o_nodePrice_TP(dt,n);

*       Total island scheduled generation for each demand scenario
        o_drsGen(dt,drs,ild)
          = sum[ n $ nodeIsland(currTP,n,ild) , o_nodeGeneration_TP(dt,n)] ;

*       Total island non-negative demand for each demand scenario
        o_drsPosDemand(dt,drs,ild)
          = sum[ n $ { nodeIsland(currTP,n,ild) and (NodeDemand(currTP,n) > 0) }
                   , nodeDemand(currTP,n) ] ;

*       Total island negative demand for each demand scenario
        o_drsNegDemand(dt,drs,ild)
          = sum[ n $ { nodeIsland(currTP,n,ild) and (NodeDemand(currTP,n) < 0) }
                   , nodeDemand(currTP,n) ] ;

*       Total island cleared bid for each demand scenario'
        o_drsBid(dt,drs,ild)
          = sum[ bd $ bidIsland(currTP,bd,ild), PURCHASE.l(currTP,bd) ] ;

*       Total island reference price for each demand scenario'
        o_drsRefPrice(dt,drs,ild)
          = sum[ n $ { ReferenceNode(currTP,n) and nodeIsland(currTP,n,ild) }
                   , o_nodePrice_TP(dt,n) ] ;


*       Total island generation revenue for each demand scenario
        o_drsGenRevenue(dt,drs,ild)
          = sum[ n $ nodeIsland(currTP,n,ild), (i_tradingPeriodLength / 60)
                                             * o_nodeGeneration_TP(dt,n)
                                             * o_nodePrice_TP(dt,n) ] ;

*       Total island negative load revenue for each demand scenario
        o_drsNegLoadRevenue(dt,drs,ild)
          = (i_tradingPeriodLength/60)
          * sum[ n $ { nodeIsland(currTP,n,ild) and (nodeDemand(currTP,n) < 0) }
                     , - nodeDemand(currTP,n) * o_nodePrice_TP(dt,n) ] ;

*       Total island gwap (including negative load) for each demand scenario'
        o_drsGWAP(dt,drs,ild) $ i_tradingPeriodLength
          = (60 / i_tradingPeriodLength)
          * [ o_drsGenRevenue(dt,drs,ild) + o_drsNegLoadRevenue(dt,drs,ild) ]
          / [ o_drsGen(dt,drs,ild) + o_drsNegDemand(dt,drs,ild) ] ;

    EndLoop;

$offend
