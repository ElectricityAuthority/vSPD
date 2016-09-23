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

    loop(i_dateTimeTradePeriodMap(dt,currTP) $ (not unsolvedPeriod(currTP)),

        o_dateTime(dt) = yes ;

        totalBusAllocation(dt,b) $ bus(currTP,b)
                = sum[ n $ Node(currTP,n), NodeBusAllocationFactor(currTP,n,b)];

        busNodeAllocationFactor(dt,b,n) $ (totalBusAllocation(dt,b) > 0)
                = NodeBusAllocationFactor(currTP,n,b)
                / totalBusAllocation(dt,b) ;

*       Node level output
        o_node(dt,n) $ {Node(currTP,n) and (not HVDCnode(currTP,n))} = yes ;

        o_nodePrice_TP(dt,n) $ Node(currTP,n)
            = sum[ b $ NodeBus(currTP,n,b)
                 , NodeBusAllocationFactor(currTP,n,b) * busPrice(currTP,b)
                  ] ;

*       Bus level output
        o_busDeficit_TP(dt,b) $ bus(currTP,b) = DEFICITBUSGENERATION.l(currTP,b);
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
$offtext
        unmappedDeficitBus(dt,b) $ o_busDeficit_TP(dt,b)
            = yes $ (Sum[ n, busNodeAllocationFactor(dt,b,n)] = 0);

        changedDeficitBus(dt,b) = no;

$onend
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
$offend
* TN - Post-process generation deficit bus end

*       Island output
        o_FIRprice_TP(dt,ild)
            = sum[ i_reserveClass $ (ord(i_reserveClass) = 1)
            , IslandReserveCalculation.m(currTP,ild,i_reserveClass) ];

        o_SIRprice_TP(dt,ild)
            = sum[ i_reserveClass $ (ord(i_reserveClass) = 2)
            , IslandReserveCalculation.m(currTP,ild,i_reserveClass) ];

*       Summary reporting by trading period
        o_solveOK_TP(dt) = ModelSolved ;

        o_systemCost_TP(dt) = SYSTEMCOST.l(currTP) - SYSTEMBENEFIT.l(currTP) ;

        o_totalViolation_TP(dt)
            = sum[ b $ bus(currTP,b)
                 , DEFICITBUSGENERATION.l(currTP,b)
                 + SURPLUSBUSGENERATION.l(currTP,b)                     ]
            + sum[ o $ offer(currTP,o)
                 , DEFICITRAMPRATE.l(currTP,o)
                 + SURPLUSRAMPRATE.l(currTP,o)                          ]
            + sum[ brCstr $ branchConstraint(currTP,brCstr)
                 , DEFICITBRANCHSECURITYCONSTRAINT.l(currTP,brCstr)
                 + SURPLUSBRANCHSECURITYCONSTRAINT.l(currTP,brCstr)     ]
            + sum[ MnodeCstr $ MnodeConstraint(currTP,MnodeCstr)
                 , DEFICITMnodeCONSTRAINT.l(currTP,MnodeCstr)
                 + SURPLUSMnodeCONSTRAINT.l(currTP,MnodeCstr)           ]
            + sum[ ACnodeCstr $ ACnodeConstraint(currTP,ACnodeCstr)
                 , DEFICITACnodeCONSTRAINT.l(currTP,ACnodeCstr)
                 + SURPLUSACnodeCONSTRAINT.l(currTP,ACnodeCstr)         ]
            + sum[ t1MixCstr $ Type1MixedConstraint(currTP,t1MixCstr)
                 , DEFICITTYPE1MIXEDCONSTRAINT.l(currTP,t1MixCstr)
                 + SURPLUSTYPE1MIXEDCONSTRAINT.l(currTP,t1MixCstr)      ]
            + sum[ gnrcCstr $ GenericConstraint(currTP,gnrcCstr)
                 , DEFICITGENERICCONSTRAINT.l(currTP,gnrcCstr)
                 + SURPLUSGENERICCONSTRAINT.l(currTP,gnrcCstr)          ]
            + sum[ br$branch(currTP,br), SURPLUSBRANCHFLOW.l(currTP,br) ]
            + sum[ (ild,i_reserveClass)
               , (DEFICITRESERVE.l(currTP,ild,i_reserveClass)$(not diffCeECeCVP))
               + (DEFICITRESERVE_CE.l(currTP,ild,i_reserveClass)$diffCeECeCVP)
               + (DEFICITRESERVE_ECE.l(currTP,ild,i_reserveClass)$diffCeECeCVP)
                 ] ;

*   Reporting at trading period end
    ) ;
