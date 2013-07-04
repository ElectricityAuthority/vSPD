$ontext
===================================================================================
Name: runVSPDSolve.gms
Function: Invokes the solve function and produces some logs.
Developed by: Ramu Naidoo  (Electricity Authority, New Zealand)
Last modified: 01 December 2010
===================================================================================
$offtext

$include vSPDpaths.inc

* Invoke VSPDSolve
$call gams VSPDSolve.gms r=VSPDModel lo=3 ide=1
$if errorlevel 1 $abort +++ Check VSPDSolve.lst for errors +++

* Create a progress report file indicating that runVSPDSolve is now finished
File rep "Write a progess report" / "runVSPDSolveProgress.txt" / ; rep.lw = 0 ;
putclose rep "runVSPDSolve has now finished..." / "Time: " system.time / "Date: " system.date ;


