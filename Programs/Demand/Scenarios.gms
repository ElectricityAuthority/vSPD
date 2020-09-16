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
Set non_conforming_nodes
$include "Demand\non_conforming_load.inc"
;

Set pricing_nodes(n)
$include "Demand\pricing_nodes.inc"
;

* Defines the set of scenarios for the demand analysis
Set drs
/ 'base'

  'increase all load 0.5%'
  'increase all load 1.0%'
  'increase all load 1.5%'
  'increase all load 2.0%'
  'increase all load 3.0%'
  'increase all load 4.0%'
  'increase all load 5.0%'

  'decrease all load 0.5%'
  'decrease all load 1.0%'
  'decrease all load 1.5%'
  'decrease all load 2.0%'
  'decrease all load 3.0%'
  'decrease all load 4.0%'
  'decrease all load 5.0%'

  'increase conforming load 0.5%'
  'increase conforming load 1.0%'
  'increase conforming load 1.5%'
  'increase conforming load 2.0%'
  'increase conforming load 3.0%'
  'increase conforming load 4.0%'
  'increase conforming load 5.0%'

  'decrease conforming load 0.5%'
  'decrease conforming load 1.0%'
  'decrease conforming load 1.5%'
  'decrease conforming load 2.0%'
  'decrease conforming load 3.0%'
  'decrease conforming load 4.0%'
  'decrease conforming load 5.0%'
/ ;

Set drs_conforming(drs)
/
  'increase conforming load 0.5%'
  'increase conforming load 1.0%'
  'increase conforming load 1.5%'
  'increase conforming load 2.0%'
  'increase conforming load 3.0%'
  'increase conforming load 4.0%'
  'increase conforming load 5.0%'

  'decrease conforming load 0.5%'
  'decrease conforming load 1.0%'
  'decrease conforming load 1.5%'
  'decrease conforming load 2.0%'
  'decrease conforming load 3.0%'
  'decrease conforming load 4.0%'
  'decrease conforming load 5.0%'
/

Alias (drs, drs1, drs2) ;
;

Parameters
  demandscale(drs)                         'Demand scale for each demand scenario'
  /
  'base'          1.000

  'increase all load 0.5%'    1.005
  'increase all load 1.0%'    1.010
  'increase all load 1.5%'    1.015
  'increase all load 2.0%'    1.020
  'increase all load 3.0%'    1.030
  'increase all load 4.0%'    1.040
  'increase all load 5.0%'    1.050

  'decrease all load 0.5%'    0.995
  'decrease all load 1.0%'    0.990
  'decrease all load 1.5%'    0.985
  'decrease all load 2.0%'    0.980
  'decrease all load 3.0%'    0.970
  'decrease all load 4.0%'    0.960
  'decrease all load 5.0%'    0.950

  'increase conforming load 0.5%'   1.005
  'increase conforming load 1.0%'   1.010
  'increase conforming load 1.5%'   1.015
  'increase conforming load 2.0%'   1.020
  'increase conforming load 3.0%'   1.030
  'increase conforming load 4.0%'   1.040
  'increase conforming load 5.0%'   1.050

  'decrease conforming load 0.5%'   0.995
  'decrease conforming load 1.0%'   0.990
  'decrease conforming load 1.5%'   0.985
  'decrease conforming load 2.0%'   0.980
  'decrease conforming load 3.0%'   0.970
  'decrease conforming load 4.0%'   0.960
  'decrease conforming load 5.0%'    0.950


  /
;