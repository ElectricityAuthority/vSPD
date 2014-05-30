*=====================================================================================
* Name:			runvSPDreportSetup.gms
* Function:		Invokes vSPDreportSetup.gms
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     30 May 2014
*=====================================================================================

$include vSPDpaths.inc

* Invoke vSPDreportSetup
$call gams vSPDreportSetup.gms
$if errorlevel 1 $abort +++ Check vSPDreportSetup.lst for errors +++


* End of file
