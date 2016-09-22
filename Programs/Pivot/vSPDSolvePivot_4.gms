*=====================================================================================
* Name:                 vSPDSolvePivot_4.gms
* Function:             Writing data to output CSV file for net pivotal analysis
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     23 Sept 2016
* Note:                 This code will be included to the end of period report
*                       section in vSPDSolve to load data to GDX.
*=====================================================================================

* This code started inside a loop created in vSPDSolvePivot_1.gms 
* End of the process that loop through each pivot scenario and produce pivot data
];


File IslandResults  /"%OutputPath%%runName%\PivotIslandResults.csv"/ ;
  IslandResults.pc = 5;  IslandResults.lw = 0;  IslandResults.pw = 9999;
  IslandResults.ap = 1;  IslandResults.nd = 3;
  put IslandResults;
  loop( (dt,pvt,ild),
    put dt.tl, pvt.tl, ild.tl, o_pivotIslandGen(dt,pvt,ild)
        o_pivotIslandMin(dt,pvt,ild), o_pivotIslandMW(dt,pvt,ild)
        o_pivotFir(dt,pvt,ild), o_pivotSir(dt,pvt,ild)
        o_pivotFirPr(dt,pvt,ild), o_pivotSirPr(dt,pvt,ild) /;
  ) ;

File NodePrice      /"%OutputPath%%runName%\PivotNodePrice.csv"/ ;
  NodePrice.pc = 5;  NodePrice.lw = 0;  NodePrice.pw = 9999;
  NodePrice.ap = 1;  NodePrice.nd = 2;
  put NodePrice;
  loop( (dt,pvt,n), put dt.tl, pvt.tl, n.tl, o_pivotNodePrice(dt,pvt,n)/ ) ;

File OfferGen       /"%OutputPath%%runName%\PivotOfferGen.csv"/;
  OfferGen.pc = 5;  OfferGen.lw = 0;  OfferGen.pw = 9999;
  OfferGen.ap = 1;  OfferGen.nd = 3;
  put OfferGen;
  loop( (dt,pvt,o) $ { o_offer(dt,o) and o_pivotOfferGen(dt,pvt,o) },
    put dt.tl, pvt.tl, o.tl, o_pivotOfferGen(dt,pvt,o)/;
  ) ;

$stop
execute_unload '%OutputPath%%runName%\PivotOutput_TP.gdx'
  i_dateTime
  i_island
  o_node
  o_offer
  pvt
  o_pivotMapping
  o_pivotIslandGen
  o_pivotIslandMin
  o_pivotIslandMW
  o_pivotFir
  o_pivotSir
  o_pivotFirPr
  o_pivotSirPr
  o_pivotNodePrice
  o_pivotOfferGen
  ;
