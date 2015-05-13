*=====================================================================================
* Name:                 vSPDPeriod.gms
* Function:             Establish the set of periods selected to be solved in vSPD
*                       and unload to gdx file for later use in vSPDsolve.gms
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              emi@ea.govt.nz
* Last modified on:     11 May 2015
*=====================================================================================

$include vSPDpaths.inc
$include vSPDsettings.inc
$include vSPDcase.inc

* If input file does not exist then go to the next input file
$ifthen exist "%inputPath%\%vSPDinputData%.gdx"


*===============================================================================
* 1. Initialize set and data
*===============================================================================
Sets
sarea                  / NI, SI, National /
tp                       'Trading periods'
dt                       'Datetime'
dt2tp(dt,tp)             'Mapping datetime to trading periods'
stp(tp)                  'Trading periods to be solved'
sdt(dt)                  'Date time to be solved'
;

Scalars
i_day                    'Day number (1..31)'
i_month                  'Month number (1..12)'
i_year                   'Year number (1900..2200)'
inputGDXGDate            'Gregorian date of input GDX file'
scarcityPricingGDXGDate  'Scarcity pricing scheme available date'
;

Parameter
scarcitySituationExists(tp,sarea) 'Flag to indicate that a scarcity situation exists (1 = Yes)'
;

$gdxin "%inputPath%\%vSPDinputData%.gdx"
$load i_day i_month i_year
$load tp = i_tradePeriod
$load dt = i_dateTime
$load dt2tp = i_dateTimeTradePeriodMap
$gdxin


*===============================================================================
* 2. Establish which trading periods are to be solved
*===============================================================================
Sets
alp            'All trading periods to be solved'  / all /
tmp            'Temporary list of trading period to be solved'
$include vSPDtpsToSolve.inc
;

stp(tp) = no ;
stp(tp) $ sum[ tmp, diag(tp,tmp)] = yes ;
stp(tp) $ sum[ tmp, diag(tmp,'All')] = yes ;

sdt(dt) = no;
sdt(dt) $ sum[ stp(tp) $ dt2tp(dt,tp), 1 ] = yes ;

execute_unload '%programPath%\vSPDperiod.gdx'
   stp = i_TradePeriod
   sdt = i_DateTime ;


*===============================================================================
* 3. Check if scaricity pricing exist for selected trading period
*===============================================================================
File vSPDcase   "The current input case file"      / "vSPDcase.inc" /;
vSPDcase.lw = 0 ;   vSPDcase.sw = 0 ;   vSPDcase.ap = 1 ;

*Scarcity pricing scheme available date from  27 May 2014
scarcityPricingGDXGDate = 41785;

* Calculate the Gregorian date of the input data
inputGDXGDate = jdate(i_year,i_month,i_day) ;

* Scarcity pricing flag
if(inputGDXGDate >= scarcityPricingGDXGDate,
    execute_load "%inputPath%\%vSPDinputData%.gdx" ScarcitySituationExists = i_tradePeriodScarcitySituationExists;
    if( Sum[ (stp,sarea), ScarcitySituationExists(stp,sarea) ] > 0,
        putclose vSPDcase "$setglobal  scarcityExists 1 ";
    else
        putclose vSPDcase "$setglobal  scarcityExists 0 ";
    ) ;

else
    putclose vSPDcase "$setglobal  scarcityExists 0 ";
) ;
* Scarcity pricing flag end
$gdxin

$endif
