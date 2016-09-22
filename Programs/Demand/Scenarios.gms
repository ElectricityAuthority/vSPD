*=====================================================================================
* Name:                 Scenarios.gms
* Function:             Creates the demand scenarios for sensitivity analysis
* Developed by:         Tuong Nguyen - Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     23 Sept 2016
* Note:                 This code will be included to the end of section 5 in
*                       vSPDSolve to begin the demand sensitivity analysis loop
*=====================================================================================

* Defines the set of scenarios for the demand analysis
Set drs
/ 'base', 'incre 1.0%', 'incre 2.0%', 'incre 2.5%', 'incre 3.0%', 'incre 4.0%', 'incre 5.0%' / ;

Alias (drs, drs1, drs2) ;
;

Parameters
  demandscale(drs)                         'Demand scale for each demand scenario'
  /
  'base'          1
  'incre 1.0%'    1.01
  'incre 2.0%'    1.02
  'incre 2.5%'    1.025
  'incre 3.0%'    1.03
  'incre 4.0%'    1.04
  'incre 5.0%'    1.05
  /
;










