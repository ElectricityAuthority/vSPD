*=====================================================================================
* Name:                 vSPDSolveDWH_4.gms
* Function:             Creates the detailed reports for EA Data warehouse mode
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: http://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Last modified on:     23 Sept 2016
*=====================================================================================

* Data warehouse summary result
File DWsummaryResults /"%outputPath%\%runName%\%runName%_DWSummaryResults.csv"/;
DWsummaryResults.pc = 5; DWsummaryResults.lw = 0; DWsummaryResults.pw = 9999 ;
DWSummaryResults.ap = 1; DWSummaryResults.nd = 5; DWsummaryResults.nw = 20;
put DWSummaryResults ;
loop( (ca,dt,tp) $ case2dt2tp(ca,dt,tp),
    put dt.tl,ca.tl, tp.tl, o_solveOK_TP(ca,dt),
        o_penaltyCost_TP(ca,dt), o_systemCost_TP(ca,dt) /;
) ;

* Data warehouse energy result
File DWenergyResults  /"%outputPath%\%runName%\%runName%_DWEnergyResults.csv"/;
DWenergyResults.pc = 5; DWenergyResults.lw = 0; DWenergyResults.pw = 9999;
DWEnergyResults.ap = 1; DWEnergyResults.nd = 5; DWEnergyResults.nw = 20;
put DWEnergyResults ;
loop( (ca,dt,tp,n) $ { case2dt2tp(ca,dt,tp) and node(ca,dt,n) },
    put dt.tl,ca.tl,tp.tl, n.tl, o_nodePrice_TP(ca,dt,n),
        o_nodeLoad_TP(ca,dt,n), o_nodeGeneration_TP(ca,dt,n) / ;
) ;

* Data warehouse reserve result
File DWreserveResults /"%outputPath%\%runName%\%runName%_DWReserveResults.csv"/;
DWreserveResults.pc = 5; DWreserveResults.lw = 0; DWreserveResults.pw = 9999;
DWreserveResults.ap = 1; DWreserveResults.nd = 5; DWreserveResults.nw = 20;
put DWReserveResults ;
loop( (ca,dt,tp,isl) $ case2dt2tp(ca,dt,tp),
    put dt.tl,ca.tl, tp.tl, isl.tl, o_FirCleared_TP(ca,dt,isl), o_FIRPrice_TP(ca,dt,isl),
        o_SirCleared_TP(ca,dt,isl), o_SIRPrice_TP(ca,dt,isl) / ;
) ;

* Data warehouse published energy result
File DWPublishedEnergyPrices  /"%outputPath%\%runName%\%runName%_DWPublishedEnergyPrices.csv"/;
DWPublishedEnergyPrices.pc = 5; DWPublishedEnergyPrices.lw = 0; DWPublishedEnergyPrices.pw = 9999;
DWPublishedEnergyPrices.ap = 1; DWPublishedEnergyPrices.nd = 5; DWPublishedEnergyPrices.nw = 20;
put DWPublishedEnergyPrices ;
loop( (tp,n),
    put tp.tl, n.tl, o_PublisedPrice_TP(tp,n) / ;
) ;

* Data warehouse published reserve prices
File  DWPublishedReservePrices  /"%outputPath%\%runName%\%runName%_DWPublishedReservePrices.csv"/;
 DWPublishedReservePrices.pc = 5;  DWPublishedReservePrices.lw = 0;  DWPublishedReservePrices.pw = 9999;
 DWPublishedReservePrices.ap = 1;  DWPublishedReservePrices.nd = 5;  DWPublishedReservePrices.nw = 20;
put  DWPublishedReservePrices ;
loop( (tp,isl),
    put tp.tl, isl.tl, o_PublisedFIRPrice_TP(tp,isl), o_PublisedSIRPrice_TP(tp,isl) / ;
) ;