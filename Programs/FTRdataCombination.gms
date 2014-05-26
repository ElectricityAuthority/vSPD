*=====================================================================================
* Name:                 FTRdataCombination.gms
* Function:             Combine output from FTR solves and prepare input for
*                       FTR rental calculation the model
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://reports.ea.govt.nz/EMIIntro.htm
* Contact:              emi@ea.govt.nz
* Last modified on:     22 November 2013
*=====================================================================================

* Include paths, settings and case name files
$include vSPDpaths.inc
$include vSPDsettings.inc
$include vSPDcase.inc
$include FTRrun.inc

Sets
  los /ls1*ls10/
  o_dateTime(*)                            'Date and time for the trade periods'
  i_branch(*)                              'Branch definition for all the trading periods'
  i_branchConstraint(*)                    'Branch constraint definitions for all the trading periods'
  FTRdirection                             'FTR flow direction'
;

Alias (o_dateTime,dt), (i_branch,br), (i_branchConstraint, brCstr), (FTRdirection, ftr) ;

Sets
  o_branch(dt,br)                          'Set of branches for output report'
  o_HVDClink(dt,br)                        'HVDC links (branches) defined for the current trading period'
  o_brConstraint_TP(dt,brCstr)             'Set of branch constraints for output report'
;

Parameters
  o_ACbranchLossMW(dt,br,los)              'MW element of the loss segment curve in MW'
  o_ACbranchLossFactor(dt,br,los)          'Loss factor element of the loss segment curve'
  o_branchFlow_TP(dt,br)                   'Output MW flow on each branch for the different time periods'
  o_branchFromBusPrice_TP(dt,br)           'Output from bus price ($/MW) for branch reporting'
  o_branchToBusPrice_TP(dt,br)             'Output to bus price ($/MW) for branch reporting'
  o_branchDynamicLoss_TP(dt,br)            'Output MW dynamic loss on each branch for the different time periods'
  o_branchMarginalPrice_TP(dt,br)          'Output marginal branch constraint price ($/MW) for branch reporting'
  o_branchCapacity_TP(dt,br)               'Output MW branch capacity for branch reporting'

  o_brConstraintLHS_TP(dt,brCstr)          'Branch constraint LHS for the different time periods'
  o_brConstraintPrice_TP(dt,brCstr)        'Branch constraint price for each output report'
  o_ACbranchTotalRentals(dt)               'Total AC rental by trading period for reporting'

  o_branchFlow_FTR(dt,br)                  'Output MW flow on each branch for the different time periods'
  o_brConstraintLHS_FTR(dt,brCstr)         'Branch constraint LHS for the different time periods'
  FTRbranchFlow(ftr,dt,br)                 'FRT directed MW flow on each branch for the different time periods'
  FTRbrCstrLHS(ftr,dt,brCstr)              'FRT directed branch constraint value'

  FTRbranchFlowtemp(ftr,dt,br)             'FRT directed MW flow on each branch for the different time periods'
  FTRbrCstrLHStemp(ftr,dt,brCstr)          'FRT directed branch constraint value'

;

$gdxin "%programPath%\FTRinput.gdx"
$load FTRdirection
$gdxin

$gdxin '%OutputPath%%runName%\runNum%VSPDRunNum%_FTRoutput.gdx'
$load o_dateTime i_branch i_branchConstraint o_branch o_HVDClink
$load o_brConstraint_TP o_ACbranchLossMW o_ACbranchLossFactor
$load o_branchFlow_TP o_branchFromBusPrice_TP o_branchToBusPrice_TP
$load o_branchDynamicLoss_TP o_branchMarginalPrice_TP o_branchCapacity_TP
$load o_brConstraintLHS_TP o_brConstraintPrice_TP o_ACbranchTotalRentals
* No data exists for FTRbranchFlow and FTRbrCstrLHS from current FTRoutput.gdx
* if this is the first FTR flow pattern run
$if %FTRorder%==1 $goto Next
$load FTRbranchFlow
$load FTRbrCstrLHS
$label Next
$gdxin


$gdxin '%OutputPath%%runName%\FTRflow.gdx'
$load FTRbranchFlowtemp = FTRbranchFlow
$load FTRbrCstrLHStemp = FTRbrCstrLHS
$gdxin

FTRbranchFlow(ftr,dt,br) $ FTRbranchFlowtemp(ftr,dt,br) = FTRbranchFlowtemp(ftr,dt,br) ;

FTRbrCstrLHS(ftr,dt,brCstr) $ FTRbrCstrLHStemp(ftr,dt,brCstr) = FTRbrCstrLHStemp(ftr,dt,brCstr);

display FTRbranchFlow, FTRbrCstrLHS

execute_unload '%OutputPath%%runName%\runNum%VSPDRunNum%_FTRoutput.gdx'
               o_dateTime, i_branch, i_branchConstraint, o_branch, o_HVDClink
               o_brConstraint_TP, o_ACbranchLossMW, o_ACbranchLossFactor
               o_branchFlow_TP, o_branchFromBusPrice_TP, o_branchToBusPrice_TP
               o_branchDynamicLoss_TP, o_branchMarginalPrice_TP, o_branchCapacity_TP
               o_brConstraintLHS_TP, o_brConstraintPrice_TP, o_ACbranchTotalRentals
               FTRdirection, FTRbranchFlow, FTRbrCstrLHS;

