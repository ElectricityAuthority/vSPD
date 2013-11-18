*=====================================================================================
* Name:			runvSPDsolve.gms
* Function:		Invokes vSPDsolve.gms and creates a progress report file
* Developed by:		Ramu Naidoo (Electricity Authority, New Zealand)
* Last modified by:	Tuong Nguyen on 9 April 2013
*=====================================================================================

$include vSPDpaths.inc

* Invoke vSPDsolve
$call gams vSPDsolve.gms r=vSPDmodel lo=3 ide=1
$if errorlevel 1 $abort +++ Check vSPDsolve.lst for errors +++

* Create a progress report file indicating that runvSPDsolve is now finished
File rep "Write a progess report" / "runvSPDsolveProgress.txt" / ; rep.lw = 0 ;
putclose rep "runvSPDsolve has now finished..." / "Time: " system.time / "Date: " system.date ;
