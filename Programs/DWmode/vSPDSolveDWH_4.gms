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
DWSummaryResults.ap = 1; DWSummaryResults.nd = 3;
put DWSummaryResults ;
loop( i_dateTimeTradePeriodMap(dt,tp),
    put dt.tl, tp.tl, o_solveOK_TP(dt),
        o_totalViolation_TP(dt),o_systemCost_TP(dt) /;
) ;

* Data warehouse energy result
File DWenergyResults  /"%outputPath%\%runName%\%runName%_DWEnergyResults.csv"/;
DWenergyResults.pc = 5; DWenergyResults.lw = 0; DWenergyResults.pw = 9999;
DWEnergyResults.ap = 1; DWEnergyResults.nd = 3;
put DWEnergyResults ;
loop( (dt,tp,n) $ {i_dateTimeTradePeriodMap(dt,tp) and o_node(dt,n)},
    put dt.tl, tp.tl, n.tl, o_nodePrice_TP(dt,n),
        o_nodeLoad_TP(dt,n), o_nodeGeneration_TP(dt,n) / ;
) ;

* Data warehouse reserve result
File DWreserveResults /"%outputPath%\%runName%\%runName%_DWReserveResults.csv"/;
DWreserveResults.pc = 5; DWreserveResults.lw = 0; DWreserveResults.pw = 9999;
DWreserveResults.ap = 1; DWreserveResults.nd = 3;
put DWReserveResults ;
loop( (dt,tp,ild) $ i_dateTimeTradePeriodMap(dt,tp) ,
    put dt.tl, tp.tl, ild.tl, o_FirCleared_TP(dt,ild), o_FIRPrice_TP(dt,ild),
        o_SirCleared_TP(dt,ild), o_SIRPrice_TP(dt,ild) / ;
) ;
