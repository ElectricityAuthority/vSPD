*=====================================================================================
* Name:                 vSPDSolvePivot_1.gms
* Function:             Included code for the net pivotal analysis
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     23 Sept 2016
* Note:                 This code will be included to the end of section 5 in
*                       vSPDSolve to begin the net pivotal analysis loop
*=====================================================================================

* Added on 5 May 2020 - estimate DCECE NFR for pivot simulation purpose
Parameters
est_FreeReserve(tp,ild,resC,riskC) 'Estimate DCECE NFR based on island load'
;

* NI FIR DCECE free reserve estimation
est_FreeReserve(tp,ild,resC,riskC)
    $ {(ord(riskC) = 3) and (ord(ild) = 1) and (ord(resC) = 1)}
    = sum[n $ nodeIsland(tp,n,ild), nodeDemand(tp,n)] * 0.296 - 179;

* NI SIR DCECE free reserve estimation
est_FreeReserve(tp,ild,resC,riskC)
    $ {(ord(riskC) = 3) and (ord(ild) = 1) and (ord(resC) = 2)}
    = sum[n $ nodeIsland(tp,n,ild), nodeDemand(tp,n)] * 0.287 - 221;

* SI FIR DCECE free reserve estimation
est_FreeReserve(tp,ild,resC,riskC)
    $ {(ord(riskC) = 3) and (ord(ild) = 2) and (ord(resC) = 1)}
    = sum[n $ nodeIsland(tp,n,ild), nodeDemand(tp,n)] * 0.381 - 290;

* SI SIR DCECE free reserve estimation
est_FreeReserve(tp,ild,resC,riskC)
    $ {(ord(riskC) = 3) and (ord(ild) = 2) and (ord(resC) = 2)}
    = sum[n $ nodeIsland(tp,n,ild), nodeDemand(tp,n)] * 0.228 - 36.9;

* Assign new DCECE NFR value if the estimated value greater than existing value
FreeReserve(tp,ild,resC,riskC)
    $ {(ord(riskC) = 3) and est_FreeReserve(tp,ild,resC,riskC) > FreeReserve(tp,ild,resC,riskC)}
    = est_FreeReserve(tp,ild,resC,riskC) ;

* Added on 5 May 2020 - estimate DCECE NFR for pivot simulation purpose - END


* Mapping offer -trader to be used in later stage (vSPDSolvePivot_3.gms)
o_offerTrader(o,trdr) $ sum[tp $ i_tradePeriodOfferTrader(tp,o,trdr), 1] = yes ;


* Scalars applied to net pivotal test
Scalars
  pivotGENTriggerPrice  'Offer prices above this will be changed to pivot price'    /   -1/
  pivotFIRTriggerPrice  'Offer prices above this will be changed to pivot price'    /   -1/
  pivotSIRTriggerPrice  'Offer prices above this will be changed to pivot price'    /   -1/
  pivotPrice            'Pivot price'                                               /30000/
  pivotPriceThreshold   'Threshold used for load at pivot price'                    /  0.8/
  pivotRemoveFKMin      'Remove the pivot generator as the FKeeper'                 /    0/
;


* Defines the set of scenarios for the pivotal analysis
Set pvt  /CTCT_NI, GENE_NI, MRPL_NI, MERI_SI, CTCT_SI, CTCT_NZ/ ;
Set trader  /CTCT, GENE, MRPL, MERI, 38430/ ;

Alias (pvt, pvt1, pvt2) ;

Sets
  pivotTrader(pvt,trdr)          'Mapping pivot scenarios to traders'
  pivotIsland(pvt,ild)           'Mapping pivot scenarios to island'
  pivotOffer(pvt,ild,o)          'Mapping pivot scenarios to offers'
  pivotMnCstr(pvt,ild,MnodeCstr) 'Mapping pivot scenarios to FK min constraint'
;


* Mannually mapping pivot scenarios to island ----------------------------------
  pivotIsland('CTCT_NI',ild) = yes $ [ord(ild) = 1] ;
  pivotIsland('GENE_NI',ild) = yes $ [ord(ild) = 1] ;
  pivotIsland('MRPL_NI',ild) = yes $ [ord(ild) = 1] ;
  pivotIsland('MERI_SI',ild) = yes $ [ord(ild) = 2] ;
  pivotIsland('CTCT_SI',ild) = yes $ [ord(ild) = 2] ;
  pivotIsland('CTCT_NZ',ild) = yes                  ;
* Mannually mapping pivot scenarios to island end ------------------------------


* Mannually mapping pivot scenarios to trader ----------------------------------
  pivotTrader('CTCT_NI',trdr) = yes $ [ sameas(trdr,'38433') or sameas(trdr,'CTCT') ] ;
  pivotTrader('GENE_NI',trdr) = yes $ [ sameas(trdr,'38459') or sameas(trdr,'GENE') ] ;
  pivotTrader('MRPL_NI',trdr) = yes $ [ sameas(trdr,'38486') or sameas(trdr,'MRPL') ] ;
  pivotTrader('MERI_SI',trdr) = yes $ [ sameas(trdr,'38481') or sameas(trdr,'MERI') ] ;
  pivotTrader('CTCT_SI',trdr) = yes $ [ sameas(trdr,'38433') or sameas(trdr,'CTCT') ] ;
  pivotTrader('CTCT_NZ',trdr) = yes $ [ sameas(trdr,'38433') or sameas(trdr,'CTCT') ] ;

* From 09-Mar-13 to 11-June-13 TWI IL is under MERI control
  if (((InputGDXGDate >= 40976) and (InputGDXGDate <= 41070)),
*    pivotTrader('MERI_SI',trdr) $ sameas(trdr,'38430') = yes ;
    pivotTrader('MERI_SI',i_trader) $ sameas(i_trader,'38430') = yes ;
  );
* Mannually mapping pivot scenarios to trader end ------------------------------


* Mannually mapping pivot scenarios to offers ----------------------------------

  pivotOffer(pvt,ild,o)
    = yes $ { Sum[ (tp,trdr,n,b) $ { pivotIsland(pvt,ild)
                                 and pivotTrader(pvt,trdr)
                                 and i_tradePeriodOfferTrader(tp,o,trdr)
                                 and i_tradePeriodOfferNode(tp,o,n)
                                 and i_tradePeriodNodeBus(tp,n,b)
                                 and i_tradePeriodBusIsland(tp,b,ild)
                                   }, 1 ]
            } ;

* Mannually mapping pivot scenarios to offers end ------------------------------


* Mannually mapping pivot scenarios to FK Min market node constraint -----------
  pivotMnCstr(pvt,ild,MnodeCstr)
    = yes $ { Sum[ (tp,o, CstrRHS)
                 $ { (ord(CstrRHS) = 1)
                 and (i_TradePeriodMNodeConstraintRHS(tp,MnodeCstr,CstrRHS) = 1)
                 and pivotOffer(pvt,ild,o)
                   }
                 , i_TradePeriodMNodeEnergyOfferConstraintFactors(tp,MnodeCstr,o)
                 ]
            } ;

* Mannually mapping pivot scenarios to FK Min market node constraint end -------


* Define output required for pivotal test
Sets
  o_pivotMapping(dt,pvt,trdr,ild,o)   'Mapping pivot scenario to trader, island and offer for each period'
;

Parameters
  o_pivotIslandGen(dt,pvt,ild)   'Total scheduled GEN form pivotal provider'
  o_pivotIslandMin(dt,pvt,ild)   'Minimum generation required for FK from pivotal provider'
  o_pivotIslandMW(dt,pvt,ild)    'Total pivot generation = Total scheduled generation  - Minimum generation required for FK'

*The following parameters may not be used
  o_pivotFir(dt,pvt,ild)         'Total scheduled FIR form pivotal provider'
  o_pivotSir(dt,pvt,ild)         'Total scheduled SIR form pivotal provider'

  o_pivotFirPr(dt,pvt,ild)       'FIR price for pivot island'
  o_pivotSirPr(dt,pvt,ild)       'SIR price for pivot island'

  o_pivotNodePrice(dt,pvt,n)     'Energy nodal price for all nodes in pivot island'
  o_pivotOfferGen(dt,pvt,o)      'Energy offer cleared for pivot offers'
;

* Begin a loop through each pivot scenario and produce pivot data
Loop[ pvt,
    sequentialSolve  = 0 ;
    sequentialSolve $ UseShareReserve = 1 ;
* Set FKmin for pivot offers to zero if i_RemoveFKPivot = 1
    MnodeConstraintLimit(MnodeConstraint(tp,MnodeCstr))
    = sum[ CstrRHS $ (ord(CstrRHS) = 2)
         , i_tradePeriodMnodeConstraintRHS(MnodeConstraint,CstrRHS)
         ] $ { (not pivotRemoveFKMin) or
               sum[ ild $ pivotMnCstr(pvt,ild,MnodeCstr), 1] = 0 } ;

* Apply the pivot price to pivot offers
    generationOfferPrice(offer(tp,o),trdBlk)
        = sum[ NRGofrCmpnt $ ( ord(NRGofrCmpnt) = 2 )
             , i_tradePeriodEnergyOffer(offer,trdBlk,NRGofrCmpnt) ] ;

    generationOfferPrice(offer(tp,o),trdBlk)
        $ { sum[ ild $ pivotOffer(pvt,ild,o), 1 ]
        and (generationOfferPrice(offer,trdBlk) >= pivotGENTriggerPrice)
          } = pivotPrice ;

    reserveOfferPrice(offer,trdBlk,resC,PLSRReserveType)
    = sum[ PLSofrCmpnt $ ( ord(PLSofrCmpnt) = 3 )
    , i_tradePeriodFastPLSRoffer(offer,trdBlk,PLSofrCmpnt)     $(ord(resC)=1)
    + i_tradePeriodSustainedPLSRoffer(offer,trdBlk,PLSofrCmpnt)$(ord(resC)=2) ];

    reserveOfferPrice(offer,trdBlk,resC,TWDRReserveType)
    = sum[ TWDofrCmpnt $ ( ord(TWDofrCmpnt) = 2 )
    , i_tradePeriodFastTWDRoffer(offer,trdBlk,TWDofrCmpnt)     $(ord(resC)=1)
    + i_tradePeriodSustainedTWDRoffer(offer,trdBlk,TWDofrCmpnt)$(ord(resC)=2) ];

    reserveOfferPrice(offer,trdBlk,resC,ILReserveType)
    = sum[ ILofrCmpnt $ ( ord(ILofrCmpnt) = 2 )
    , i_tradePeriodFastILRoffer(offer,trdBlk,ILofrCmpnt)     $(ord(resC)=1)
    + i_tradePeriodSustainedILRoffer(offer,trdBlk,ILofrCmpnt)$(ord(resC)=2) ] ;

    reserveOfferPrice(offer(tp,o),trdBlk,resC,resT)
      $ { sum[ ild $ pivotOffer(pvt,ild,o), 1 ] and [ord(resC) = 1]
      and (reserveOfferPrice(offer,trdBlk,resC,resT) >= pivotFIRTriggerPrice)
        } = pivotPrice ;

    reserveOfferPrice(offer(tp,o),trdBlk,resC,resT)
      $ { sum[ ild $ pivotOffer(pvt,ild,o), 1 ] and [ord(resC) = 2]
      and (reserveOfferPrice(offer,trdBlk,resC,resT) >= pivotSIRTriggerPrice)
        } = pivotPrice ;

