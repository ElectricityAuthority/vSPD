*=====================================================================================
* Name:                 DWHreportSetup.gms
* Function:             Creates the report templates for EA Data warehouse mode
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Contact:              Forum: http://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Last modified on:     23 Sept 2016
*=====================================================================================
$include vSPDsettings.inc

File DWsummaryResults /"%outputPath%\%runName%\%runName%_DWSummaryResults.csv"/;
DWsummaryResults.pc = 5 ; DWsummaryResults.lw = 0 ; DWsummaryResults.pw = 9999 ;
put DWsummaryResults 'DateTime','CaseID','TradingPeriod','GAMSsolveStatus','vSPDTotalViolationDollars','vSPDObjectiveFunctionValueDollars' ;

File DWenergyResults   /"%outputPath%\%runName%\%runName%_DWEnergyResults.csv"/;
DWenergyResults.pc = 5 ; DWenergyResults.lw = 0 ; DWenergyResults.pw = 9999 ;
put DWenergyResults  'DateTime','CaseID','TradingPeriod','Pnodename','vSPDDollarsPerMegawattHour','vSPDLoadMegawatts','vSPDGenerationMegawatts' ;

File DWreserveResults /"%outputPath%\%runName%\%runName%_DWReserveResults.csv"/;
DWreserveResults.pc = 5 ; DWreserveResults.lw = 0 ; DWreserveResults.pw = 9999 ;
put DWreserveResults 'DateTime','CaseID','TradingPeriod','Island','vSPDFIRMegawatts','vSPDFIRDollarsPerMegawattHour','vSPDSIRMegawatts','vSPDSIRDollarsPerMegawattHour';

File DWPublishedEnergyPrices /"%outputPath%\%runName%\%runName%_DWPublishedEnergyPrices.csv"/;
DWPublishedEnergyPrices.pc = 5 ; DWPublishedEnergyPrices.lw = 0 ; DWPublishedEnergyPrices.pw = 9999 ;
put DWPublishedEnergyPrices 'TradingPeriod','Pnodename','vSPDDollarsPerMegawattHour';

File DWPublishedReservePrices /"%outputPath%\%runName%\%runName%_DWPublishedEnergyPrices.csv"/;
DWPublishedReservePrices.pc = 5 ; DWPublishedReservePrices.lw = 0 ; DWPublishedReservePrices.pw = 9999 ;
put DWPublishedEnergyPrices 'TradingPeriod','Island','vSPDDollarsPerMegawattHour';
