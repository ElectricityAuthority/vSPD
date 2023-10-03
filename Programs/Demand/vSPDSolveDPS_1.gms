*=====================================================================================
* Name:                 vSPDSolveDPS_1.gms
* Function:             Included code for the demand sensitivity analysis
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     23 Sept 2016
* Note:                 This code will be included to the end of section 5 in
*                       vSPDSolve to begin the demand sensitivity analysis loop
*=====================================================================================

$include "%system.fp%Scenarios.gms"

* Define output required for pivotal test

Parameters
  o_drsnodeprice(ca,dt,drs,n)                 'Price at each reference pricng node for each demand scenario'
  o_drsGen(ca,dt,drs,isl)                     'Total island scheduled generation for each demand scenario'
  o_drsPosDemand(ca,dt,drs,isl)               'Total island non-negative demand for each demand scenario'
  o_drsNegDemand(ca,dt,drs,isl)               'Total island negative demand for each demand scenario'
  o_drsBid(ca,dt,drs,isl)                     'Total island cleared bid for each demand scenario'
  o_drsRefPrice(ca,dt,drs,isl)                'Total island reference price for each demand scenario'
  o_drsGenRevenue(ca,dt,drs,isl)              'Total island generation revenue for each demand scenario'
  o_drsNegLoadRevenue(ca,dt,drs,isl)          'Total island negative load revenue for each demand scenario'
  o_drsGWAP(ca,dt,drs,isl)                    'Total island gwap (including negative load) for each demand scenario'
;

* Reset island reference node for demand sensitivity analysis
*referenceNode(node(tp,n))
*  = yes $ { sameas(n,'OTA2201') or sameas(n,'BEN2201') } ;

* Begin a loop through each pivot scenario and produce pivot data
Loop[ drs,
  putclose rep '==============================================================================='/;
  putclose rep 'Demand price sensitivity scenario: ' drs.tl /;
  putclose rep '==============================================================================='/;
* apply demand scale for current demand scenario
  RequiredLoad(node) = nodeParameter(node,'demand') ;
  RequiredLoad(node) $ ( nodeParameter(node,'demand') > 0 ) = demandscale(drs) * nodeParameter(node,'demand') ;

* Initialize energy scarcity limits and prices ---------------------------------
  scarcityEnrgLimit(ca,dt,n,blk) $ { energyScarcityEnabled(ca,dt) and (requiredLoad(ca,dt,n) > 0) }                                      = scarcityNationalFactor(ca,dt,blk,'factor') * requiredLoad(ca,dt,n);
  scarcityEnrgPrice(ca,dt,n,blk) $ { energyScarcityEnabled(ca,dt) and (scarcityEnrgLimit(ca,dt,n,blk) > 0 ) }                            = scarcityNationalFactor(ca,dt,blk,'price') ;

  scarcityEnrgLimit(ca,dt,n,blk) $ { energyScarcityEnabled(ca,dt) and scarcityNodeFactor(ca,dt,n,blk,'factor') and (requiredLoad(ca,dt,n) > 0) } = scarcityNodeFactor(ca,dt,n,blk,'factor') * requiredLoad(ca,dt,n);
  scarcityEnrgPrice(ca,dt,n,blk) $ { energyScarcityEnabled(ca,dt) and scarcityNodeFactor(ca,dt,n,blk,'price') }                         = scarcityNodeFactor(ca,dt,n,blk,'price') ;

  scarcityEnrgLimit(ca,dt,n,blk) $ { energyScarcityEnabled(ca,dt) and scarcityNodeLimit(ca,dt,n,blk,'limitMW') }                               = scarcityNodeLimit(ca,dt,n,blk,'limitMW');
  scarcityEnrgPrice(ca,dt,n,blk) $ { energyScarcityEnabled(ca,dt) and scarcityNodeLimit(ca,dt,n,blk,'price') }                          = scarcityNodeLimit(ca,dt,n,blk,'price') ;

*-------------------------------------------------------------------------------

* Pre-processing: Shared Net Free Reserve (NFR) calculation - NMIR (4.5.2.1)
  sharedNFRLoad(ca,dt,isl) = sum[ nodeIsland(ca,dt,n,isl), requiredLoad(ca,dt,n)] + sum[ (bd,blk) $ bidIsland(ca,dt,bd,isl), DemBidMW(ca,dt,bd,blk) ] - sharedNFRLoadOffset(ca,dt,isl) ;
  sharedNFRMax(ca,dt,isl) = Min{ RMTReserveLimit(ca,dt,isl,'FIR'), sharedNFRFactor(ca,dt)*sharedNFRLoad(ca,dt,isl) } ;

* Risk parameters
  FreeReserve(ca,dt,isl,resC,riskC) = riskParameter(ca,dt,isl,resC,riskC,'freeReserve') - sum[ isl1 $ (not sameas(isl,isl1)),sharedNFRMax(ca,dt,isl1) ]${(ord(resC)=1) and ((GenRisk(riskC)) or (ManualRisk(riskC))) } ;



* ]; the end of loop will apprear in vSPDSolveDPS_4.gms
