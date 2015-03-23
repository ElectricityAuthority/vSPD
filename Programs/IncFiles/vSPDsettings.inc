*+++ vSPD settings +++
$inlinecom ## ##
$eolcom !


*+++ Model +++
Scalar sequentialSolve                   / 0 / ;   ! Vectorisation: Yes <-> i_SequentialSolve: 0


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
$setglobal Solver                          Cplex
Scalar LPtimeLimit                       / 3600 / ;
Scalar LPiterationLimit                  / 2000000000 / ;
Scalar MIPtimeLimit                      / 3600 / ;
Scalar MIPoptimality                     / 0 / ;
Scalar MIPiterationLimit                 / 2000000000 / ;


*+++ Misc +++
Scalar disconnectedNodePriceCorrection   / 1 / ;
$setglobal varResv                        -1


*+++ Various switches +++
$setglobal interfaceMode                   1       ! interfaceMode: Specify 0 for EMI tools; 1 for Excel; and 2 for Standalone
$setglobal suppressOverrides               0       ! Specify 1 to suppress reading and implementing the selected override file
$setglobal opMode                          0       ! Specify 1 for data warehouse; -1 for audit; 2 for FTR Rental, otherwise usual vSPD mode
Scalar     tradePeriodReports            / 1 / ;   ! Specify 1 for reports at trading period level, 0 otherwise
