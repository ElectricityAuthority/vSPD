*=====================================================================================
* Name:                 runvSPDsolve.gms
* Function:             Invokes vSPDsolve.gms.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     30 May 2014
*=====================================================================================

$include vSPDpaths.inc

* Invoke vSPDsolve
$call gams vSPDsolve.gms r=vSPDmodel lo=3 ide=1
$if errorlevel 1 $abort +++ Check vSPDsolve.lst for errors +++


* End of file
