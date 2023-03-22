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
tp                      'Set of trading periods'
dt                      'Set of datetime'
dt2tp(dt,tp)            'Mapping datetime to trading periods'

stp(tp)                 'Trading periods to be solved'
sdt(dt)                 'Date time to be solved'
sdt2tp(dt,tp)           'Mapping solved datetime to trading periods'
;
alias (tp,tp1);

Parameter
gdxDate(*)                        'day, month, year of trade date'
;

$gdxin "%inputPath%\%GDXname%.gdx"
$load gdxDate
$load tp = i_tradePeriod
$load dt = i_dateTime
$load dt2tp = i_dateTimeTradePeriodMap
$gdxin

*===============================================================================
* 2. Establish which trading periods are to be solved
*===============================================================================
Sets
alp            'All trading periods to be solved'  / All /
tmp            'Temporary list of trading period to be solved'
$include vSPDtpsToSolve.inc
;

stp(tp) = no ;
sdt(dt) = no;

stp(tp) $ sum[ tmp, diag(tp,tmp)] = yes ;
sdt(dt) $ sum[ tmp, diag(dt,tmp)] = yes ;

stp(tp) $ sum[ tmp, diag(tmp,'All')] = yes ;
$if %opMode% == 'DWH' stp(tp) = yes;

sdt(dt) $ sum[ stp(tp) $ dt2tp(dt,tp), 1 ] = yes ;
stp(tp) $ sum[ sdt(dt) $ dt2tp(dt,tp), 1 ] = yes ;

sdt2tp(dt,tp) $ sum[ (sdt(dt), stp(tp)) $ dt2tp(dt,tp), 1 ] = yes ;

execute_unload '%programPath%\vSPDperiod.gdx'
  stp    = i_TradePeriod
  sdt    = i_DateTime
  sdt2tp = i_DateTimeTradePeriod
  ;

$endif
