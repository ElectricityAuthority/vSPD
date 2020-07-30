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
  o_drsGen(dt,drs,ild)                     'Total island scheduled generation for each demand scenario'
  o_drsPosDemand(dt,drs,ild)               'Total island non-negative demand for each demand scenario'
  o_drsNegDemand(dt,drs,ild)               'Total island negative demand for each demand scenario'
  o_drsBid(dt,drs,ild)                     'Total island cleared bid for each demand scenario'
  o_drsRefPrice(dt,drs,ild)                'Total island reference price for each demand scenario'
  o_drsGenRevenue(dt,drs,ild)              'Total island generation revenue for each demand scenario'
  o_drsNegLoadRevenue(dt,drs,ild)          'Total island negative load revenue for each demand scenario'
  o_drsGWAP(dt,drs,ild)                    'Total island gwap (including negative load) for each demand scenario'
;

* Reset island reference node for demand sensitivity analysis
*referenceNode(node(tp,n))
*  = yes $ { sameas(n,'OTA2201') or sameas(n,'BEN2201') } ;

* Begin a loop through each pivot scenario and produce pivot data
Loop[ drs,
*   apply demand scale for current demand scenario
    nodeDemand(node) = i_tradePeriodNodeDemand(node) ;

    nodeDemand(node) $ { ( nodeDemand(node) > 0 )
                     and ( not drs_conforming(drs) ) }
    = demandscale(drs) * nodeDemand(node) ;

    nodeDemand(node(tp,n)) $ { ( nodeDemand(node) > 0 )
                           and ( drs_conforming(drs) )
                           and ( not non_conforming_nodes(n) )}
    = demandscale(drs) * nodeDemand(node) ;


* ]; the end of loop will apprear in vSPDSolveDPS_4.gms










