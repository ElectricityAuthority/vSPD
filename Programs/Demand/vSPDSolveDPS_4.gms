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
];

Files DRSIslandResults    /"%OutputPath%%runName%\DemandPriceSensitivity.csv"/;
  DRSIslandResults.pc = 5; DRSIslandResults.lw = 0; DRSIslandResults.pw = 9999;
  DRSIslandResults.ap = 1; DRSIslandResults.nd = 3;
  put DRSIslandResults;
  loop( (dt,ild),
    put dt.tl, ild.tl ;
    loop( drs, put o_drsRefPrice(dt,drs,ild) );
    put /;
  ) ;

$stop
execute_unload '%OutputPath%%runName%\DRSOutput_TP.gdx'
  i_dateTime
  i_island
  drs
  demandscale
  o_drsGen
  o_drsPosDemand
  o_drsNegDemand
  o_drsBid
  o_drsRefPrice
  o_drsGenRevenue
  o_drsNegLoadRevenue
  o_drsGWAP
  ;
