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
rundt                   'Set of Rundatetime'
caseName                'Set of CaseName'

case2dt2tp(ca<,dt<,tp<) 'Mapping caseID to datetime and to tp'
case2rundt(ca,rundt<)   'Mapping caseID to rundatetime'
case2Name(ca,caseName<) 'Mapping caseID to case name'


dt2tp(dt,tp)            'Mapping datetime to trading periods'

sca(ca)                 'caseID to be solved'
stp(tp)                 'Trading periods to be solved'
sdt(dt)                 'Date time to be solved'
srt(rundt)           'RunDateTime of cases to be solved'
scn(caseName)     'Name of cases to be solved'


sdt2tp(dt,tp)           'Mapping solved datetime to trading periods'
scase2dt(ca,dt)         ''
scase2Name(ca,caseName) ''
scase2rundt(ca,rundt)   ''

;
alias (tp,tp1);

Parameter
gdxDate(*,*)                        'day, month, year of trade date'
;

$gdxin "%inputPath%\%GDXname%.gdx"
$load gdxDate
$load case2dt2tp = i_dateTimeTradePeriodMap
$load case2rundt = i_runDateTime
$load case2Name = caseName
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
srt(rundt)    = no ;
scn(caseName) = no;

stp(tp) $ sum[ tmp, diag(tp,tmp)] = yes ;
sdt(dt) $ sum[ tmp, diag(dt,tmp)] = yes ;

stp(tp) $ sum[ tmp, diag(tmp,'All')] = yes ;
$if %opMode% == 'DWH' stp(tp) = yes;


sdt(dt) $ sum[ (ca,stp(tp)) $ case2dt2tp(ca,dt,tp), 1 ] = yes ;
stp(tp) $ sum[ (ca,sdt(dt)) $ case2dt2tp(ca,dt,tp), 1 ] = yes ;

sdt2tp(sdt(dt),stp(tp)) = yes $ sum[ca $ case2dt2tp(ca,dt,tp),1] ;

sca(ca)  = yes $ sum[ (sdt(dt),stp(tp)) $ case2dt2tp(ca,dt,tp),1] ;
scase2dt(ca,dt) = yes $ sum[(sca(ca),sdt(dt),stp(tp)) $ case2dt2tp(ca,dt,tp),1] ;

scn(caseName) $ sum[sca(ca) $ case2Name(ca,caseName), 1]  = yes ;
scase2Name(ca,caseName) = yes $ sum[ (sca(ca),scn(caseName)) $ case2Name(ca,caseName), 1 ] ;

srt(rundt) $ sum[sca(ca) $ case2rundt(ca,rundt), 1]  = yes ;
scase2rundt(ca,rundt) = yes $ sum[ (sca(ca),srt(rundt)) $ case2rundt(ca,rundt), 1] ; 



execute_unload '%programPath%\vSPDperiod.gdx'
  sca    = i_caseID
  stp    = i_tradePeriod
  sdt    = i_dateTime
  srt    = i_runDateTime
  scn    = i_caseName
  sdt2tp      = i_DateTimeTradePeriod
  scase2dt    = i_caseDateTime
  scase2Name  = i_caseIdName
  scase2rundt = i_case2rundt 
  ;

$endif
