*=====================================================================================
* Name:                 vSPDSolveDWH_3.gms
* Function:             Collect and store results for the data warehouse mode
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: http://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Last modified on:     23 Sept 2016
*=====================================================================================
$onend
    Loop t $ (not unsolvedDT(t)) do

        busGeneration(bus(t,b)) = sum[ (o,n) $ { offerNode(t,o,n) and NodeBus(t,n,b) } , NodeBusAllocationFactor(t,n,b) * GENERATION.l(t,o) ] ;
        busLoad(bus(t,b))       = sum[ NodeBus(t,n,b), NodeBusAllocationFactor(t,n,b) * RequiredLoad(t,n) ] ;
        busPrice(bus(t,b))      = ACnodeNetInjectionDefinition2.m(t,b) ;

        busDisconnected(bus(t,b)) $ { (busLoad(bus) = 0) and (busElectricalIsland(bus) = 0) } = 1 ;
        busDisconnected(bus(t,b)) $ { ( sum[ b1 $ { busElectricalIsland(t,b1) = busElectricalIsland(bus) }, busLoad(t,b1) ] = 0) and ( busElectricalIsland(bus) > 0 ) } = 1 ;
*       Set prices at dead buses with non-zero load
        busPrice(bus(t,b)) $ { (busLoad(bus) > 0) and (busElectricalIsland(bus)= 0) } = DeficitBusGenerationPenalty ;
        busPrice(bus(t,b)) $ { (busLoad(bus) < 0) and (busElectricalIsland(bus)= 0) } = -SurplusBusGenerationPenalty ;
*       Set price at identified disconnected buses to 0
        busPrice(bus)$busDisconnected(bus) = 0 ;
*       End Check for disconnected nodes and adjust prices accordingly

*       6f0. Replacing invalid prices after SOS1 (7.1.3)----------------------------
        if SOS1_solve(ca,dt) then
            putclose rep 'Replacing invalid prices after SOS1. /' ;
*           Calculate highest bus cleared offere price        
            busClearedPrice(ca,dt,b) = smax[ (o,n,blk) $ { offernode(ca,dt,o,n) and nodebus(ca,dt,n,b) and (GENERATIONBLOCK.l(ca,dt,o,blk) > 0) }, enrgOfrPrice(ca,dt,o,blk) ];
            busSOSinvalid(ca,dt,b)
                = 1 $ { [ ( busPrice(ca,dt,b) = 0 ) or ( busPrice(ca,dt,b) > 0.9*deficitBusGenerationPenalty ) or ( busPrice(ca,dt,b) < -0.9*surplusBusGenerationPenalty )
                        or (busPrice(ca,dt,b) = busClearedPrice(ca,dt,b) ) or (busPrice(ca,dt,b) = busClearedPrice(ca,dt,b) + 0.0005 ) or (busPrice(ca,dt,b) = busClearedPrice(ca,dt,b) - 0.0005 )   ]
                    and bus(ca,dt,b)  and [ not busDisconnected(ca,dt,b) ]  and [ busLoad(ca,dt,b) = busGeneration(ca,dt,b) ]
                    and [ sum[(br,fd) $ { BranchBusConnect(ca,dt,br,b) and branch(ca,dt,br) }, ACBRANCHFLOWDIRECTED.l(ca,dt,br,fd) ] = 0 ]
                    and [ sum[ br     $ { BranchBusConnect(ca,dt,br,b) and branch(ca,dt,br) } , 1 ] > 0 ]
                      };
                      
            numberofbusSOSinvalid(ca,dt) = 2*sum[b, busSOSinvalid(ca,dt,b)];

            While sum[b, busSOSinvalid(ca,dt,b)] < numberofbusSOSinvalid(ca,dt) do
                numberofbusSOSinvalid(ca,dt) = sum[b, busSOSinvalid(ca,dt,b)];

                busPrice(ca,dt,b) $ { busSOSinvalid(ca,dt,b) and ( sum[ b1 $ { [ not busSOSinvalid(ca,dt,b1) ] and sum[ br $ { branch(ca,dt,br) and BranchBusConnect(ca,dt,br,b) and BranchBusConnect(ca,dt,br,b1) }, 1 ] }, 1 ] > 0 ) }
                    = sum[ b1 $ { [ not busSOSinvalid(ca,dt,b1) ] and sum[ br $ { branch(ca,dt,br) and BranchBusConnect(ca,dt,br,b) and BranchBusConnect(ca,dt,br,b1) }, 1 ] }, busPrice(ca,dt,b1) ]
                    / sum[ b1 $ { [ not busSOSinvalid(ca,dt,b1) ] and sum[ br $ { branch(ca,dt,br) and BranchBusConnect(ca,dt,br,b) and BranchBusConnect(ca,dt,br,b1) }, 1 ] }, 1 ];

                busSOSinvalid(ca,dt,b)
                  = 1 $ { [ ( busPrice(ca,dt,b) = 0 ) or ( busPrice(ca,dt,b) > 0.9 * deficitBusGenerationPenalty ) or ( busPrice(ca,dt,b) < -0.9 * surplusBusGenerationPenalty ) ]
                      and bus(ca,dt,b) and [ not busDisconnected(ca,dt,b) ] and [ busLoad(ca,dt,b) = busGeneration(ca,dt,b) ]
                      and [ sum[(br,fd) $ { BranchBusConnect(ca,dt,br,b) and branch(ca,dt,br) }, ACBRANCHFLOWDIRECTED.l(ca,dt,br,fd) ] = 0 ]
                      and [ sum[ br $ { BranchBusConnect(ca,dt,br,b) and branch(ca,dt,br) }, 1 ] > 0 ]
                        };
            endwhile;
        endif ;

        totalBusAllocation(t,b) $ bus(t,b)
            = sum[ n $ Node(t,n), NodeBusAllocationFactor(t,n,b)];

        busNodeAllocationFactor(t,b,n) $ (totalBusAllocation(t,b) > 0)
            = NodeBusAllocationFactor(t,n,b) / totalBusAllocation(t,b) ;

*       Node level output

        o_nodeGeneration_TP(t,n) $ Node(t,n)
            = sum[ o $ offerNode(t,o,n), GENERATION.l(t,o) ] ;

        o_nodeLoad_TP(t,n) $ Node(t,n)
           = RequiredLoad(t,n)
           + Sum[ bd $ bidNode(t,bd,n), PURCHASE.l(t,bd) ];

        o_nodePrice_TP(t,n) $ Node(t,n)
            = sum[ b $ NodeBus(t,n,b)
                 , NodeBusAllocationFactor(t,n,b) * busPrice(t,b)
                  ] ;

        if { dtParameter(t,'priceTransfer') and [(studyMode(t) = 101) or (studyMode(t) = 201) or (studyMode(t) = 130) or (studyMode(t) = 131)] } then
            o_nodeDead_TP(t,n)
                = 1 $ ( sum[b $ {NodeBus(t,n,b) and (not busDisconnected(t,b))
                                }, NodeBusAllocationFactor(t,n,b) ] = 0 ) ;

            o_nodeDeadPriceFrom_TP(t,n,n1)
                = 1 $ {o_nodeDead_TP(t,n) and node2node(t,n,n1)};

            o_nodeDeadPrice_TP(t,n) $ o_nodeDead_TP(t,n) = 1;

            While sum[ n $ o_nodeDead_TP(t,n), o_nodeDeadPrice_TP(t,n) ] do
                o_nodePrice_TP(t,n)
                    $ { o_nodeDead_TP(t,n) and o_nodeDeadPrice_TP(t,n) }
                    = sum[n1 $ o_nodeDeadPriceFrom_TP(t,n,n1)
                             , o_nodePrice_TP(t,n1) ] ;

                o_nodeDeadPrice_TP(t,n)
                    = 1 $ sum[n1 $ o_nodeDead_TP(t,n1)
                                 , o_nodeDeadPriceFrom_TP(t,n,n1) ];

                o_nodeDeadPriceFrom_TP(t,n,n2) $ o_nodeDeadPrice_TP(t,n)
                    = 1 $ { sum[ n1 $ { node2node(t,n1,n2)
                                    and o_nodeDeadPriceFrom_TP(t,n,n1) }, 1 ]
                          } ;

                o_nodeDeadPriceFrom_TP(t,n,n1) $ o_nodeDead_TP(t,n1) = 0 ;

            endwhile
        endif;

*       Offer output
        o_offerEnergy_TP(t,o) $ offer(t,o) = GENERATION.l(t,o) ;

*       Island reserve output
        o_FIRprice_TP(t,isl) = Sum[ resC $ (ord(resC) = 1)
                                  , IslandReserveCalculation.m(t,isl,resC) ];

        o_SIRprice_TP(t,isl) = Sum[ resC $ (ord(resC) = 2)
                                  , IslandReserveCalculation.m(t,isl,resC) ];

        o_FirCleared_TP(t,isl) = Sum[ resC $ (ord(resC) = 1)
                                    , ISLANDRESERVE.l(t,isl,resC) ];

        o_SirCleared_TP(t,isl) = Sum[ resC $ (ord(resC) = 2)
                                    , ISLANDRESERVE.l(t,isl,resC) ];

*       Summary reporting by trading period
        o_solveOK_TP(t) = ModelSolved ;

        o_systemCost_TP(t) = SYSTEMCOST.l(t) - SYSTEMBENEFIT.l(t) ;

        o_penaltyCost_TP(t) = SYSTEMPENALTYCOST.l(t);

*   Reporting at trading period end
    endloop ;
$offend
