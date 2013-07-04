$ontext
===================================================================================
Name: runVSPDReport.gms
Function: Invokes the reporting function and produces some logs.
Developed by: Ramu Naidoo  (Electricity Authority, New Zealand)
Last modified: 01 December 2010
===================================================================================
$offtext

$include vSPDpaths.inc

* Invoke VSPDReport
$call gams VSPDReport.gms
$if errorlevel 1 $abort +++ Check VSPDReport.lst for errors +++

* Create a progress report file indicating that runVSPDReport is now finished
File rep "Write a progess report" / "runVSPDReportProgress.txt" / ; rep.lw = 0 ;
putclose rep "runVSPDReport has now finished..." / "Time: " system.time / "Date: " system.date ;


