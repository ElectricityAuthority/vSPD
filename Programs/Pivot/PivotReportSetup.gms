*=====================================================================================
* Name:                 pivotReportSetup.gms
* Function:             Creates the report templates for net pivotal analysis
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     23 Sept 2016
*=====================================================================================
$include vSPDsettings.inc

File IslandResults  /"%OutputPath%%runName%\PivotIslandResults.csv"/ ;
  IslandResults.pc = 5;  IslandResults.lw = 0;  IslandResults.pw = 9999;
  put IslandResults;
  put 'DateTime', 'Scenario', 'Island', 'TraderGenMW', 'TraderMinMW'
      'TraderPivotMW', 'TraderFirMW', 'TraderSirMW', 'FirPrice', 'SirPrice';

File NodePrice      /"%OutputPath%%runName%\PivotNodePrice.csv"/ ;
 NodePrice.pc = 5;  NodePrice.lw = 0;  NodePrice.pw = 9999;
 put NodePrice;
 put 'DateTime', 'Scenario', 'Node', 'Price';

File OfferGen       /"%OutputPath%%runName%\PivotOfferGen.csv"/ ;
  OfferGen.pc = 5;  OfferGen.lw = 0;  OfferGen.pw = 9999;
  put OfferGen;
  put 'DateTime', 'Scenario', 'Offer', 'ClearedMW';
