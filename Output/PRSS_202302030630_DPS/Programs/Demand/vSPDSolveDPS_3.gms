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
    Loop t $ (not unsolvedDT(t)) do
        busPrice(bus(t,b))      = ACnodeNetInjectionDefinition2.m(t,b) ;

        busDisconnected(bus(t,b)) $ { (busLoad(bus) = 0) and (busElectricalIsland(bus) = 0) } = 1 ;
        busDisconnected(bus(t,b)) $ { ( sum[ b1 $ { busElectricalIsland(t,b1) = busElectricalIsland(bus) }, busLoad(t,b1) ] = 0) and ( busElectricalIsland(bus) > 0 ) } = 1 ;
*       Set prices at dead buses with non-zero load
        busPrice(bus(t,b)) $ { (busLoad(bus) > 0) and (busElectricalIsland(bus)= 0) } = DeficitBusGenerationPenalty ;
        busPrice(bus(t,b)) $ { (busLoad(bus) < 0) and (busElectricalIsland(bus)= 0) } = -SurplusBusGenerationPenalty ;
*       Set price at identified disconnected buses to 0
        busPrice(bus)$busDisconnected(bus) = 0 ;

        o_nodeGeneration_TP(t,n) = sum[ o $ offerNode(t,o,n), GENERATION.l(t,o) ] ;

        o_nodePrice_TP(t,n) $ Node(t,n) = sum[ b $ NodeBus(t,n,b), NodeBusAllocationFactor(t,n,b) * busPrice(t,b) ] ;

*       Get price at each reference pricng node for each demand scenario
        o_drsnodeprice(t,drs,pricing_nodes(n)) = o_nodePrice_TP(t,n);

*       Total island scheduled generation for each demand scenario
        o_drsGen(t,drs,isl) = sum[ n $ nodeIsland(t,n,isl) , o_nodeGeneration_TP(t,n)] ;

*       Total island non-negative demand for each demand scenario
        o_drsPosDemand(t,drs,isl) = sum[ n $ { nodeIsland(t,n,isl) and (RequiredLoad(t,n) > 0) }, RequiredLoad(t,n) ] ;

*       Total island negative demand for each demand scenario
        o_drsNegDemand(t,drs,isl) = sum[ n $ { nodeIsland(t,n,isl) and (RequiredLoad(t,n) < 0) }, RequiredLoad(t,n) ] ;

*       Total island cleared bid for each demand scenario'
        o_drsBid(t,drs,isl) = sum[ bd $ bidIsland(t,bd,isl), PURCHASE.l(t,bd) ] ;

*       Total island reference price for each demand scenario'
        o_drsRefPrice(t,drs,isl) = sum[ n $ { refNode(t,n) and nodeIsland(t,n,isl) }, o_nodePrice_TP(t,n) ] ;

*       Total island generation revenue for each demand scenario
        o_drsGenRevenue(t,drs,isl) = sum[ n $ nodeIsland(t,n,isl), (intervalDuration(t) / 60) * o_nodeGeneration_TP(t,n) * o_nodePrice_TP(t,n) ] ;

*       Total island negative load revenue for each demand scenario
        o_drsNegLoadRevenue(t,drs,isl) = (intervalDuration(t)/60) * sum[ n $ { nodeIsland(t,n,isl) and (RequiredLoad(t,n) < 0) }, - RequiredLoad(t,n) * o_nodePrice_TP(t,n) ] ;

*       Total island gwap (including negative load) for each demand scenario'
        o_drsGWAP(t,drs,isl) $ intervalDuration(t)
          = (60 / intervalDuration(t))
          * [ o_drsGenRevenue(t,drs,isl) + o_drsNegLoadRevenue(t,drs,isl) ]
          / [ o_drsGen(t,drs,isl) + o_drsNegDemand(t,drs,isl) ] ;

    EndLoop;

$offend
