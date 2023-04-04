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
  o_drsnodeprice(dt,drs,n)                 'Price at each reference pricng node for each demand scenario'
  o_drsGen(dt,drs,isl)                     'Total island scheduled generation for each demand scenario'
  o_drsPosDemand(dt,drs,isl)               'Total island non-negative demand for each demand scenario'
  o_drsNegDemand(dt,drs,isl)               'Total island negative demand for each demand scenario'
  o_drsBid(dt,drs,isl)                     'Total island cleared bid for each demand scenario'
  o_drsRefPrice(dt,drs,isl)                'Total island reference price for each demand scenario'
  o_drsGenRevenue(dt,drs,isl)              'Total island generation revenue for each demand scenario'
  o_drsNegLoadRevenue(dt,drs,isl)          'Total island negative load revenue for each demand scenario'
  o_drsGWAP(dt,drs,isl)                    'Total island gwap (including negative load) for each demand scenario'
;

* Reset island reference node for demand sensitivity analysis
*referenceNode(node(tp,n))
*  = yes $ { sameas(n,'OTA2201') or sameas(n,'BEN2201') } ;

* Begin a loop through each pivot scenario and produce pivot data
Loop[ drs,
* apply demand scale for current demand scenario
  RequiredLoad(node) = nodeDemand(node) ;
  RequiredLoad(node) $ ( nodeDemand(node) > 0 ) = demandscale(drs) * nodeDemand(node) ;

* Initialize energy scarcity limits and prices ---------------------------------
  ScarcityEnrgLimit(dt,n,blk) $ { energyScarcityEnabled(dt) and (RequiredLoad(dt,n) > 0) }                                      = scarcityEnrgNationalFactor(dt,blk) * RequiredLoad(dt,n);
  ScarcityEnrgPrice(dt,n,blk) $ { energyScarcityEnabled(dt) and (ScarcityEnrgLimit(dt,n,blk) > 0 ) }                            = scarcityEnrgNationalPrice(dt,blk) ;

  ScarcityEnrgLimit(dt,n,blk) $ { energyScarcityEnabled(dt) and scarcityEnrgNodeFactor(dt,n,blk) and (RequiredLoad(dt,n) > 0) } = scarcityEnrgNodeFactor(dt,n,blk) * RequiredLoad(dt,n);
  ScarcityEnrgPrice(dt,n,blk) $ { energyScarcityEnabled(dt) and scarcityEnrgNodeFactorPrice(dt,n,blk) }                         = scarcityEnrgNodeFactorPrice(dt,n,blk) ;

  ScarcityEnrgLimit(dt,n,blk) $ { energyScarcityEnabled(dt) and scarcityEnrgNodeLimit(dt,n,blk) }                               = scarcityEnrgNodeLimit(dt,n,blk);
  ScarcityEnrgPrice(dt,n,blk) $ { energyScarcityEnabled(dt) and scarcityEnrgNodeLimitPrice(dt,n,blk) }                          = scarcityEnrgNodeLimitPrice(dt,n,blk) ;
*-------------------------------------------------------------------------------

* Pre-processing: Shared Net Free Reserve (NFR) calculation - NMIR (4.5.2.1)
  sharedNFRLoad(dt,isl) = sum[ nodeIsland(dt,n,isl), RequiredLoad(dt,n)] + sum[ (bd,blk) $ bidIsland(dt,bd,isl), DemBidMW(dt,bd,blk) ] - sharedNFRLoadOffset(dt,isl) ;
  sharedNFRMax(dt,isl) = Min{ RMTReserveLimitTo(dt,isl,'FIR'), sharedNFRFactor(dt)*sharedNFRLoad(dt,isl) } ;

* Risk parameters
  FreeReserve(dt,isl,resC,riskC) = riskParameter(dt,isl,resC,riskC,'freeReserve') - sum[ isl1 $ (not sameas(isl,isl1)),sharedNFRMax(dt,isl1) ]${(ord(resC)=1) and ((GenRisk(riskC)) or (ManualRisk(riskC))) } ;



* ]; the end of loop will apprear in vSPDSolveDPS_4.gms
