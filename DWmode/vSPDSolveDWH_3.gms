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

        if { runPriceTransfer(t)
        and ( (studyMode = 101) or (studyMode = 201) or (studyMode = 130))
           } then
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
*        o_offerEnergy_TP(t,o) $ offer(t,o) = GENERATION.l(t,o) ;

*       Bus level output
*        o_busDeficit_TP(dt,b) $ bus(currTP,b) = DEFICITBUSGENERATION.l(currTP,b);
* TN - post processing unmapped generation deficit buses
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

        unmappedDeficitBus(dt,b) $ o_busDeficit_TP(dt,b)
            = yes $ (Sum[ n, busNodeAllocationFactor(dt,b,n)] = 0);

        changedDeficitBus(dt,b) = no;

*$onend
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
*$offend
* TN - Post-process generation deficit bus end
$offtext

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