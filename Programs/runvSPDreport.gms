*=====================================================================================
* Name:			runvSPDreport.gms
* Function:		Invokes vSPDreport.gms to generate output reports and creates
*			a reporting progress report
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     12 September 2014
*=====================================================================================

$include vSPDpaths.inc

* Invoke vSPDreport
$call gams vSPDreport.gms
$if errorlevel 1 $abort +++ Check vSPDreport.lst for errors +++

* Create a progress report file indicating that runvSPDreport is now finished
File rep "Write a progess report" / "runvSPDreportProgress.txt" / ; rep.lw = 0 ;
putclose rep "runvSPDreport has now finished..." / "Time: " system.time / "Date: " system.date ;
