*=====================================================================================
* Name:			runvSPDreport.gms
* Function:		Invokes vSPDreport.gms to generate output reports
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     30 May 2014
*=====================================================================================

$include vSPDpaths.inc

* Invoke vSPDreport
$call gams vSPDreport.gms
$if errorlevel 1 $abort +++ Check vSPDreport.lst for errors +++


* End of file
