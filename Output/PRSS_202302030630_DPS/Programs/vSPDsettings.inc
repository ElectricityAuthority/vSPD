*+++ vSPD settings +++
$inlinecom ## ##
$eolcom !

*+++ Paths +++
$setglobal runName                       PRSS_202302030630_DPS
$setglobal programPath                   '%system.fp%' 
$setglobal inputPath                     '%system.fp%..\Input\'
$setglobal outputPath                    '%system.fp%..\Output\'
$setglobal ovrdPath                      '%system.fp%..\Override\'

$setglobal vSPDinputOvrdData             ''   !Name of override file 


*+++ Model +++
Scalar sequentialSolve                   / 0 / ;   ! Vectorisation: Yes <-> i_SequentialSolve: 0
Scalar dailymode                         / 1 / ;   ! Solving quickly by using RTD pre-calculated demand or PRSS solved initial MW  

*+++ Network +++
Scalar useACLossModel                    / 1 /    ;
Scalar useHVDCLossModel                  / 1 /    ;
Scalar useACBranchLimits                 / 1 /    ;
Scalar useHVDCBranchLimits               / 1 /    ;
Scalar resolveCircularBranchFlows        / 1 /    ;
Scalar resolveHVDCNonPhysicalLosses      / 1 /    ;
Scalar resolveACNonPhysicalLosses        / 0 /    ;   ! Placeholder for future code development
Scalar circularBranchFlowTolerance       / 1e-4 / ;
Scalar nonPhysicalLossTolerance          / 1e-6 / ;
Scalar useBranchFlowMIPTolerance         / 1e-6 / ;


*+++ Constraints +++
Scalar useReserveModel                   / 1 /    ;
Scalar suppressMixedConstraint           / 0 /    ;   ! No longer used since Mixed MIP Constraints no longer exists
Scalar mixedMIPtolerance                 / 1e-6 / ;   ! No longer used since Mixed MIP Constraints no longer exists


*+++ Solver +++
Scalar LPtimeLimit                       / 3600 / ;
Scalar LPiterationLimit                  / 2000000000 / ;
Scalar MIPtimeLimit                      / 3600 / ;
Scalar MIPiterationLimit                 / 2000000000 / ;
Scalar MIPoptimality                     / 0 / ;
$setglobal Solver                          Cplex
$setglobal licenseMode                     1


*+++ Various switches +++
$setglobal opMode                          DPS      ! DWH for data warehouse; AUD for audit; FTR for FTR Rental; SPD for normal SPD run; PVT for pivot analysis; DPS for demand~price sensitivity analysis
