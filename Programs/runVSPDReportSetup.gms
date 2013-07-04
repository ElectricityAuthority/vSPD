$ontext
===================================================================================
Name: runVSPDReportSetup.gms
Function: Invokes the reporting setup function and produces some logs.
Developed by: Ramu Naidoo  (Electricity Authority, New Zealand)
Last modified: 01 December 2010
===================================================================================
$offtext

$include vSPDpaths.inc

* Invoke VSPDReportSetup
$call gams VSPDReportSetup.gms
$if errorlevel 1 $abort +++ Check VSPDReportSetup.lst for errors +++

* Create a progress report file indicating that runVSPDReportSetup is now finished
File rep "Write a progess report" / "runVSPDReportSetupProgress.txt" / ; rep.lw = 0 ;
putclose rep "runVSPDReportSetup has now finished..." / "Time: " system.time / "Date: " system.date ;


