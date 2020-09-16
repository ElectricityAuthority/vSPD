*=====================================================================================
* Name:                 vSPDSolveDPS_4.gms
* Function:             Writing data to output csv file for demand sensitivity analysis
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     23 Sept 2016
* Note:                 This code will be included to the end of period report
*                       section in vSPDSolve to load data to gdx.
*=====================================================================================


* End of the process that loop through each pivot scenario and produce pivot data

$ontext
* Testing
  Files DPSNodeResults   /"%OutputPath%%runName%\NodePriceSensitivity.csv"/;
    DPSNodeResults.pc = 5; DPSNodeResults.lw = 0; DPSNodeResults.pw = 9999;
    DPSNodeResults.ap = 1; DPSNodeResults.nd = 3;
    put DPSNodeResults;
    loop( (dt, pricing_nodes(n)),
      put dt.tl, drs.tl, n.tl, o_drsnodeprice(dt,drs,n);
      put /;
    ) ;

  Files DPSIslandResults   /"%OutputPath%%runName%\IslandSensitivity.csv"/;
    DPSIslandResults.pc = 5; DPSIslandResults.lw = 0; DPSIslandResults.pw = 9999;
    DPSIslandResults.ap = 1; DPSIslandResults.nd = 3;
    put DPSIslandResults;
    loop( (dt, ild),
      put dt.tl, drs.tl, ild.tl;
      put o_drsPosDemand(dt,drs,ild), o_drsRefPrice(dt,drs,ild) ;
      put /;
    ) ;
* Testing end
$offtext

];

*$ontext
Files DPSNodeResults   /"%OutputPath%%runName%\NodePriceSensitivity.csv"/;
  DPSNodeResults.pc = 5; DPSNodeResults.lw = 0; DPSNodeResults.pw = 9999;
  DPSNodeResults.ap = 1; DPSNodeResults.nd = 3;
  put DPSNodeResults;
  loop( (dt, drs, pricing_nodes(n)),
    put dt.tl, drs.tl, n.tl, o_drsnodeprice(dt,drs,n);
    put /;
  ) ;



Files DPSIslandResults   /"%OutputPath%%runName%\IslandSensitivity.csv"/;
  DPSIslandResults.pc = 5; DPSIslandResults.lw = 0; DPSIslandResults.pw = 9999;
  DPSIslandResults.ap = 1; DPSIslandResults.nd = 3;
  put DPSIslandResults;
  loop( (dt, drs, ild),
    put dt.tl, drs.tl, ild.tl;
    put o_drsPosDemand(dt,drs,ild), o_drsRefPrice(dt,drs,ild) ;
    put /;
  ) ;
*$offtext

$stop
execute_unload '%OutputPath%%runName%\DRSOutput_TP.gdx'
  i_dateTime
  i_island
  drs
  demandscale
  o_drsnodeprice
  o_drsGen
  o_drsPosDemand
  o_drsNegDemand
  o_drsBid
  o_drsRefPrice
  o_drsGenRevenue
  o_drsNegLoadRevenue
  o_drsGWAP
  ;