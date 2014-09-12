*=====================================================================================
* Name:                 runvSPDreportSetup.gms
* Function:             Invokes vSPDreportSetup.gms and creates a progress report
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     12 September 2014
*=====================================================================================

$include vSPDpaths.inc

* Invoke vSPDreportSetup
$call gams vSPDreportSetup.gms
$if errorlevel 1 $abort +++ Check vSPDreportSetup.lst for errors +++

* Create a progress report file indicating that runvSPDreportSetup is now finished
File rep "Write a progess report" / "runvSPDreportSetupProgress.txt" / ; rep.lw = 0 ;
putclose rep "runvSPDreportSetup has now finished..." / "Time: " system.time / "Date: " system.date ;
