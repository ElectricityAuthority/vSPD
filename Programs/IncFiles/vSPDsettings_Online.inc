*+++ vSPD settings +++
$inlinecom ## ##
$eolcom !

*+++ Paths +++
$setglobal runName               {RUN NAME}
 
$setglobal programPath           '%system.fp%'
$setglobal inputPath             '%system.fp%..\Input\'
$setglobal ovrdPath              '%system.fp%..\Override\'
$setglobal outputPath            '%system.fp%..\Output\'
 
$setglobal vSPDinputOvrdData     {OVERRIDE FILE}       ! Name of override file when using EMI

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
$setglobal opMode                          0       ! Specify 1 for data warehouse; -1 for audit; 2 for FTR Rental, otherwise usual vSPD mode
