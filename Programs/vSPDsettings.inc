$inlinecom { }
$eolcom !
***vSPD solve settings***
**Model**
Scalar i_SequentialSolve                  /0/;        !Vectorisation: Yes <-> i_SequentialSolve: 0
**Network**
Scalar i_UseACLossModel                   /1/;
Scalar i_UseHVDCLossModel                 /1/;
Scalar i_UseACBranchLimits                /1/;
Scalar i_UseHVDCBranchLimits              /1/;
Scalar i_ResolveCircularBranchFlows       /1/;
Scalar i_ResolveHVDCNonPhysicalLosses     /1/;
Scalar i_ResolveACNonPhysicalLosses       /0/;   !Placeholder for future code development.
Scalar CircularBranchFlowTolerance        /0.000001/;
Scalar NonPhysicalLossTolerance           /0.000001/;
Scalar UseBranchFlowMIPTolerance          /0.000001/;
**Constraints**
Scalar i_UseReserveModel                  /1/;
Scalar i_UseMixedConstraint               /1/;
Scalar MixedMIPTolerance                  /0.000001/;
**Solver**
$setglobal    Solver                       CPLEX
Scalar LPTimeLimit                        /600/;
Scalar MIPTimeLimit                       /600/;
Scalar MIPOptimality                      /0/;
Scalar LPIterationLimit                   /1000000/;
Scalar MIPIterationLimit                  /1000000/;
**Reports**
*Specify if want reporting at trade period level (1 = Yes, 0 = No)
$setglobal    TradePeriodReports           1
**Misc**
Scalar i_DisconnctedNodePriceCorrection    /1/;
$setglobal    VarResv                       -1
**External loss model from Transpower**
Scalar i_UseExternalLossModel    /1/;
Scalar LossCoeff_A    /0.3101/;
Scalar LossCoeff_C    /0.14495/;
Scalar LossCoeff_D    /0.32247/;
Scalar LossCoeff_E    /0.46742/;
Scalar LossCoeff_F    /0.82247/;
Scalar MaxFlowSegment    /10000/;
*Set this flag to invoke the datawarehouse mode*
$setglobal    DWMode           1
