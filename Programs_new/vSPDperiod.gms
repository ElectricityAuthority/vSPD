*=====================================================================================
* Name:               vSPDPeriod.gms
* Function:           Establish the set of periods selected to be solved in vSPD
*                     and unload to gdx file for later use in vSPDsolve.gms
* Developed by:       Electricity Authority, New Zealand
* Source:             https://github.com/ElectricityAuthority/vSPD
*                     https://www.emi.ea.govt.nz/Tools/vSPD
* Contact:            Forum: https://www.emi.ea.govt.nz/forum/
*                     Email: emi@ea.govt.nz
* Last modified on:   1 Nov 2022
*
*=====================================================================================

$include vSPDsettings.inc
$include vSPDcase.inc

* If input file does not exist then go to the next input file
$ifthen exist "%inputPath%\%GDXname%.gdx"


*===============================================================================
* 1. Initialize set and data
*===============================================================================
Sets
ca                      'Set of caseID'
tp                      'Set of trading periods'
dt                      'Set of datetime'
case2dt2tp(ca<,dt<,tp<) 'Mapping caseID to datetime and to trading periods'


sca(ca)                 'caseID to be solved'
stp(tp)                 'Trading periods to be solved'
sdt(dt)                 'Date time to be solved'
scase2dt2tp(ca,dt,tp)   'Mapping solved caseID to datetime and to trading periods'
;
alias (tp,tp1), (dt,dt1), (ca,ca1);

Parameter casePublishedSecs(ca,tp) 'Time Weight Seconds apply to case file for final pricing calculation' ;


$gdxin "%inputPath%\%GDXname%.gdx"
$load case2dt2tp = i_dateTimeTradePeriodMap
$load casePublishedSecs = i_priceCaseFilesPublishedSecs
$gdxin

*===============================================================================
* 2. Establish which trading periods are to be solved
*===============================================================================
Sets
alp            'All trading periods to be solved'  / All /
tmp            'Temporary list of trading period to be solved'
$include vSPDtpsToSolve.inc
;
sca(ca)       = no ;
stp(tp)       = no ;
sdt(dt)       = no ;

stp(tp) $ sum[ tmp, diag(tp,tmp)] = yes ;
sdt(dt) $ sum[ tmp, diag(dt,tmp)] = yes ;
sca(ca) $ sum[ tmp, diag(ca,tmp)] = yes ;

stp(tp) $ sum[ tmp, diag(tmp,'All')] = yes ;
sdt(dt) $ sum[ tmp, diag(tmp,'All')] = yes ;
sca(ca) $ sum[ tmp, diag(tmp,'All')] = yes ;


sdt(dt) $ { ( sum[dt1 $ sdt(dt1), 1] = 0 ) and (sum[ca $ sca(ca), 1] = 0 ) and sum[ (ca,stp(tp)) $ { case2dt2tp(ca,dt,tp)}, 1 ] } = yes ;
sdt(dt) $ { ( sum[dt1 $ sdt(dt1), 1] = 0 ) and (sum[tp $ stp(tp), 1] = 0 ) and sum[ (sca(ca),tp) $ { case2dt2tp(ca,dt,tp)}, 1 ] } = yes ; 
sdt(dt) $ { ( sum[dt1 $ sdt(dt1), 1] = 0 ) and sum[ (sca(ca),stp(tp)) $ case2dt2tp(ca,dt,tp), 1 ] } = yes ;

stp(tp) $ { ( sum[tp1 $ stp(tp1), 1] = 0 ) and ( sum[ca $ sca(ca), 1] = 0 ) and sum[ (ca,sdt(dt)) $ case2dt2tp(ca,dt,tp), 1 ] } = yes ;
stp(tp) $ { ( sum[tp1 $ stp(tp1), 1] = 0 ) and ( sum[dt $ sdt(dt), 1] = 0 ) and sum[ (sca(ca),dt) $ case2dt2tp(ca,dt,tp), 1 ] } = yes ; 
stp(tp) $ { ( sum[tp1 $ stp(tp1), 1] = 0 ) and sum[ (sca(ca),sdt(dt)) $ case2dt2tp(ca,dt,tp), 1 ] } = yes ;

sca(ca) $ { ( sum[dt $ sdt(dt), 1] = 0 ) and sum[ (dt,stp(tp)) $ case2dt2tp(ca,dt,tp), 1 ] } = yes ; 
sca(ca) $ { ( sum[tp $ stp(tp), 1] = 0 ) and sum[ (sdt(dt),tp) $ case2dt2tp(ca,dt,tp), 1 ] } = yes ;
sca(ca) $ { ( sum[ca1 $ sca(ca1), 1] = 0 ) and sum[ (sdt(dt),stp(tp)) $ case2dt2tp(ca,dt,tp), 1 ] } = yes ;

scase2dt2tp(sca(ca),sdt(dt),stp(tp)) = yes $ {case2dt2tp(ca,dt,tp) and casePublishedSecs(ca,tp)} ;

sca(ca) = yes $ sum[ (sdt(dt),stp(tp)) $ scase2dt2tp(ca,dt,tp), 1 ] ;
sdt(dt) = yes $ sum[ (sca(ca),stp(tp)) $ scase2dt2tp(ca,dt,tp), 1 ] ;
stp(tp) = yes $ sum[ (sca(ca),sdt(dt)) $ scase2dt2tp(ca,dt,tp), 1 ] ;


execute_unload '%programPath%\vSPDperiod.gdx'
  sca    = i_caseID
  stp    = i_tradePeriod
  sdt    = i_dateTime
  scase2dt2tp  = i_DateTimeTradePeriod
  ;

$endif