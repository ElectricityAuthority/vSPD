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
Scalar LPtimeLimit                       / 600 / ;
Scalar LPiterationLimit                  / 1000000 / ;
Scalar MIPtimeLimit                      / 600 / ;
Scalar MIPoptimality                     / 0 / ;
Scalar MIPiterationLimit                 / 1000000 / ;

*+++ Misc +++
Scalar disconnectedNodePriceCorrection   / 1 / ;
$setglobal varResv                        -1

*+++ External loss model from Transpower +++
Scalar useExternalLossModel              / 1 / ;
Scalar lossCoeff_A                       / 0.3101 / ;
Scalar lossCoeff_C                       / 0.14495 / ;
Scalar lossCoeff_D                       / 0.32247 / ;
Scalar lossCoeff_E                       / 0.46742 / ;
Scalar lossCoeff_F                       / 0.82247 / ;
Scalar maxFlowSegment                    / 10000 / ;

*+++ Various switches +++
$setglobal interfaceMode                   2       ! interfaceMode: Specify 0 for EMI tools; 1 for Excel; and 2 for Standalone
$setglobal skipCleanUp                     0       ! Specify 1 to skip clean up of working directory
$setglobal suppressOverrides               1       ! Specify 1 to suppress reading and implementing the selected override file
$setglobal calcFTRrentals                  0       ! Specify 1 to calculate FTR rentals
Scalar     opMode                        / 0 / ;   ! Specify 1 for data warehouse; -1 for audit; otherwise usual vSPD mode
Scalar     tradePeriodReports            / 1 / ;   ! Specify 1 for reports at trading period level, 0 otherwise
