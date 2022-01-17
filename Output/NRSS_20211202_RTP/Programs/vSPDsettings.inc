*+++ vSPD settings +++
$inlinecom ## ##
$eolcom !

*+++ Paths +++
$setglobal runName                       NRSS_20211202_RTP
$setglobal programPath                   '%system.fp%'
$setglobal inputPath                     '%system.fp%..\Input\'
*$setglobal inputPath                     'A:\Tuong Nguyen\vSPD_Inputs\FP\'
$setglobal ovrdPath                      '%system.fp%..\Override\'
$setglobal outputPath                    '%system.fp%..\Output\'

$setglobal vSPDinputOvrdData             ''  ! Name of override file


*+++ Model +++
Scalar sequentialSolve                   / 0 / ;   ! Vectorisation: Yes <-> i_SequentialSolve: 0
Scalar disconnectedNodePriceCorrection   / 1 / ;
Scalar tradePeriodReports                / 1 / ;   ! Specify 1 for reports at trading period level, 0 otherwise


*+++ Network +++
Scalar useACLossModel                    / 1 / ;
Scalar useHVDCLossModel                  / 1 / ;
Scalar useACBranchLimits                 / 1 / ;
Scalar useHVDCBranchLimits               / 1 / ;
Scalar resolveCircularBranchFlows        / 1 / ;
Scalar resolveHVDCNonPhysicalLosses      / 1 / ;
Scalar resolveACNonPhysicalLosses        / 0 / ;   ! Placeholder for future code development
Scalar circularBranchFlowTolerance       / 0.000001 / ;
Scalar nonPhysicalLossTolerance          / 0.000001 / ;
Scalar useBranchFlowMIPTolerance         / 0.000001 / ;


*+++ Constraints +++
Scalar useReserveModel                   / 1 / ;
Scalar suppressMixedConstraint           / 0 / ;
Scalar mixedMIPtolerance                 / 0.000001 / ;


*+++ Solver +++
Scalar LPtimeLimit                       / 3600 / ;
Scalar LPiterationLimit                  / 2000000000 / ;
Scalar MIPtimeLimit                      / 3600 / ;
Scalar MIPiterationLimit                 / 2000000000 / ;
Scalar MIPoptimality                     / 0 / ;
$setglobal Solver                          Cplex
$setglobal licenseMode                     1


*+++ Various switches +++
$setglobal varResv                         -1
$setglobal opMode                          AUD    ! DWH for data warehouse; AUD for audit; FTR for FTR Rental; SPD for normal SPD run; PVT for pivot analysis; DPS for demand~price sensitivity analysis

