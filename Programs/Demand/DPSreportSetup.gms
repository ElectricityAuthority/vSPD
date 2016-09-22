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
$include "%system.fp%Scenarios.gms"

Files DRSIslandResults   /"%OutputPath%%runName%\DemandPriceSensitivity.csv"/;
DRSIslandResults.pc = 5;  DRSIslandResults.lw = 0;  DRSIslandResults.pw = 9999;
put DRSIslandResults;
put 'DateTime', 'Island';
loop( drs, put drs.tl) ;


