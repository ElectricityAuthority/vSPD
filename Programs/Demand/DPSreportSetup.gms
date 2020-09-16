*=====================================================================================
* Name:                 DPSReportSetup.gms
* Function:             Creates the report templates for demand price sensitivity.
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     23 Sept 2016
*=====================================================================================
$include vSPDsettings.inc

* Defines the set of scenarios for the demand sensitivity analysis
*$include "%system.fp%Scenarios.gms"


Files DPSNodeResults   /"%OutputPath%%runName%\NodePriceSensitivity.csv"/;
DPSNodeResults.pc = 5;  DPSNodeResults.lw = 0;  DPSNodeResults.pw = 9999;
put DPSNodeResults;
put 'DateTime', 'Scenario', 'Node', 'Price' ;


Files DPSIslandResults   /"%OutputPath%%runName%\IslandSensitivity.csv"/;
DPSIslandResults.pc = 5;  DPSIslandResults.lw = 0;  DPSIslandResults.pw = 9999;
put DPSIslandResults;
put 'DateTime', 'Scenario', 'Island', 'Load', 'Reference_price';




