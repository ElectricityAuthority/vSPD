*=====================================================================================
* Name:                 vSPDoverrides.gms
* Function:             Code to be included in vSPDsolve to take care of input data
*                       overrides.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       http://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: http://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Last modified on:     23 Sept 2016
*=====================================================================================

$ontext
This code is included into vSPDsolve.gms if an override file defined by
the $setglobal vSPDinputOvrdData in vSPDSetting.inc exists.

The prefix ovrd_ inidcates that the symbol contains data to override
the original input data, prefixed with i_.

After declaring the override symbols, the override data is installed and
the original symbols are overwritten.

Note that:
The Excel interface permits a limited number of input data symbols to be overridden.
The EMI interface will create a GDX file of override values for all data inputs to be overridden.
If operating in standalone mode,overrides can be installed by any means the user prefers - GDX file, $include file, hard-coding, etc.
But it probably makes sense to mimic the GDX file as used by EMI.

Use GAMS to process a text file (e.g. somefile.gms) into a GDX file called filename.gdx,
e.g. c:\>gams somefile.gms gdx=filename

Directory of code sections in vSPDoverrides.gms:
  1. Declare all symbols required for vSPD on EMI and standalone overrides and load data from GDX
  2. Initialise the data
     a) Demand overrides
     b) Offers
     ...

Aliases to be aware of:
  i_island = ild, ild1                      i_dateTime = dt
  i_tradePeriod = tp                        i_node = n
  i_offer = o, o1                           i_trader = trdr
  i_tradeBlock = trdBlk                     i_bus = b, b1, frB, toB
  i_branch = br, br1                        i_lossSegment = los, los1
  i_branchConstraint = brCstr               i_ACnodeConstraint = ACnodeCstr
  i_MnodeConstraint = MnodeCstr             i_energyOfferComponent = NRGofrCmpnt
  i_PLSRofferComponent = PLSofrCmpnt        i_TWDRofferComponent = TWDofrCmpnt
  i_ILRofferComponent = ILofrCmpnt          i_energyBidComponent = NRGbidCmpnt
  i_ILRbidComponent = ILbidCmpnt            i_type1MixedConstraint = t1MixCstr
  i_type2MixedConstraint = t2MixCstr        i_type1MixedConstraintRHS = t1MixCstrRHS
  i_genericConstraint = gnrcCstr            i_reserveType = resT
  i_reserveClass =resC                      i_riskClass =riskC
$offtext

$OnEnd
*=========================================================================================================================
* 1. Declare all symbols required for vSPD on EMI and standalone overrides and load data from GDX
*=========================================================================================================================
Set demMethod        'Demand override method'               / scale, increment, value / ;

Parameters
* Demand
  ovrd_tradePeriodNodeDemand(tp,n,demMethod)       'Override the i_tradePeriodNodeDemand parameter'
  ovrd_dateTimeNodeDemand(dt,n,demMethod)          'Override the i_tradePeriodNodeDemand parameter with dateTime data'

  ovrd_tradePeriodIslandDemand(tp,ild,demMethod)   'Override the i_tradePeriodNodeDemand parameter with island-based data'
  ovrd_dateTimeIslandDemand(dt,ild,demMethod)      'Override the i_tradePeriodNodeDemand parameter with dateTime and island-based data'

  temp_TradePeriodNodeDemand(tp,n)                 'Temporary container for node demand value while implementing the node-based scaling factor'
  temp_TradePeriodIslandDemand(tp,ild)             'Temporary container for island positive demand value while implementing the island-based scaling factor'
  used_TradePeriodIslandScale(tp,ild)              'Final value used for island-based scaling'
;

Parameters
* Offers - incl. energy, PLSR, TWDR, and ILR
  ovrd_tradePeriodEnergyOffer(tp,o,trdBlk,NRGofrCmpnt)         'Override for energy offers for specified trade period'
  ovrd_dateTimeEnergyOffer(dt,o,trdBlk,NRGofrCmpnt)            'Override for energy offers for specified datetime'

  ovrd_tradePeriodOfferParameter(tp,o,i_offerParam)            'Override for energy offer parameters for specified trade period'
  ovrd_dateTimeOfferParameter(dt,o,i_offerParam)               'Override for energy offer parameters for specified datetime'

  ovrd_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)  'Override for reserve offers for specified trading periods'
  ovrd_dateTimeSustainedPLSRoffer(dt,o,trdBlk,PLSofrCmpnt)     'Override for reserve offers for specified datetime'

  ovrd_tradePeriodFastPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)       'Override for reserve offers for specified trading periods'
  ovrd_dateTimeFastPLSRoffer(dt,o,trdBlk,PLSofrCmpnt)          'Override for reserve offers for specified datetime'

  ovrd_tradePeriodSustainedTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)  'Override for reserve offers for specified trading periods'
  ovrd_dateTimeSustainedTWDRoffer(dt,o,trdBlk,TWDofrCmpnt)     'Override for reserve offers for specified datetime'

  ovrd_tradePeriodFastTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)       'Override for reserve offers for specified trading periods'
  ovrd_dateTimeFastTWDRoffer(dt,o,trdBlk,TWDofrCmpnt)          'Override for reserve offers for specified datetime'

  ovrd_tradePeriodSustainedILRoffer(tp,o,trdBlk,ILofrCmpnt)    'Override for reserve offers for specified trading periods'
  ovrd_dateTimeSustainedILRoffer(dt,o,trdBlk,ILofrCmpnt)       'Override for reserve offers for specified datetime'

  ovrd_tradePeriodFastILRoffer(tp,o,trdBlk,ILofrCmpnt)         'Override for reserve offers for specified trading periods'
  ovrd_dateTimeFastILRoffer(dt,o,trdBlk,ILofrCmpnt)            'Override for reserve offers for specified datetime'

  ovrd_tradePeriodReserveClassGenerationMaximum(tp,o,resC)     'Override for MW used to determine factor to adjust maximum reserve of a reserve class'
  ovrd_dateTimeReserveClassGenerationMaximum(dt,o,resC)        'Override for MW used to determine factor to adjust maximum reserve of a reserve class'


* Bid data
  ovrd_tradePeriodEnergyBid(tp,i_bid,trdBlk,NRGbidCmpnt)       'Override for energy bids for specified trading periods'
  ovrd_dateTimeEnergyBid(dt,i_bid,trdBlk,NRGbidCmpnt)          'Override for energy bids for specified datetime'
  ovrd_tradePeriodDispatchableBid(tp,i_bid)                    'Override for energy bids for specified trading periods'
  ovrd_datetimeDispatchableBid(dt,i_bid)                       'Override for energy bids for specified datetime'
;



*=========================================================================================================================
* 2. Demand overrides
*=========================================================================================================================
*    Note that demMethod is declared in vSPDsolve.gms. Elements include scale, increment, and value where:
*      - scaling is applied first,
*      - increments are applied second and take precedence over scaling, and
*      - values are applied last and take precedence over increments.


*Loading data from gdx file
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load ovrd_tradePeriodNodeDemand = demandOverrides
$load ovrd_tradePeriodIslandDemand = demandOverrides
$load ovrd_dateTimeNodeDemand = demandOverrides
$load ovrd_dateTimeIslandDemand = demandOverrides
$gdxin


*overwrite period demand override by datetime demand override if datetime demand override exists (>0)
Loop i_dateTimeTradePeriodMap(dt,tp) do
    ovrd_tradePeriodNodeDemand(tp,n,demMethod)
        $ ovrd_dateTimeNodeDemand(dt,n,demMethod)
        = ovrd_dateTimeNodeDemand(dt,n,demMethod);

    ovrd_tradePeriodIslandDemand(tp,ild,demMethod)
        $ ovrd_dateTimeIslandDemand(dt,ild,demMethod)
        = ovrd_dateTimeIslandDemand(dt,ild,demMethod);
EndLoop;


* Store current node and island demand into temporary parameters
temp_TradePeriodNodeDemand(tp,n) = 0 ;
temp_TradePeriodIslandDemand(tp,ild) = 0;

temp_TradePeriodNodeDemand(tp,n) = i_tradePeriodNodeDemand(tp,n) ;
temp_TradePeriodIslandDemand(tp,ild)
    = Sum[ (n,b) $ { i_tradePeriodNodeBus(tp,n,b) and
                     i_tradePeriodBusIsland(tp,b,ild) and
                     (temp_TradePeriodNodeDemand(tp,n) > 0) and
                     (Sum[ bd $ { sameas(n,bd) and
                                  i_tradePeriodDispatchableBid(tp,bd)
                                }, 1 ] = 0)
                     }
                 , temp_TradePeriodNodeDemand(tp,n)
                 * i_tradePeriodNodeBusAllocationFactor(tp,n,b)
         ] ;

used_TradePeriodIslandScale(tp,ild) = 1;

* Apply island scaling factor to an island if scaling factor exist
used_TradePeriodIslandScale(tp,ild)
    $ ovrd_tradePeriodIslandDemand(tp,ild,'scale')
    = ovrd_tradePeriodIslandDemand(tp,ild,'scale') ;

* Apply island scaling factor to an island if scaling factor = eps (i.e. zero)
used_TradePeriodIslandScale(tp,ild)
    $ { ovrd_tradePeriodIslandDemand(tp,ild,'scale')
    and (ovrd_tradePeriodIslandDemand(tp,ild,'scale') = eps) }
    = 0 ;

* Apply island increments to an island if increments exist
used_TradePeriodIslandScale(tp,ild)
    $ ovrd_tradePeriodIslandDemand(tp,ild,'increment')
    = 1 + [ ovrd_tradePeriodIslandDemand(tp,ild,'increment')
          / temp_TradePeriodIslandDemand(tp,ild)  ] ;

* Apply island values to an island if values exist
used_TradePeriodIslandScale(tp,ild)
    $ ovrd_tradePeriodIslandDemand(tp,ild,'value')
    = ovrd_tradePeriodIslandDemand(tp,ild,'value')
    / temp_TradePeriodIslandDemand(tp,ild) ;

* Apply island values to an island if value = eps (i.e. zero)
used_TradePeriodIslandScale(tp,ild)
    $ { ovrd_tradePeriodIslandDemand(tp,ild,'value')
    and (ovrd_tradePeriodIslandDemand(tp,ild,'value') = eps) }
    = 0 ;

* Allocate island demand override value to node demand
i_tradePeriodNodeDemand(tp,n) $ (temp_TradePeriodNodeDemand(tp,n) > 0)
    = Sum[ (b,ild) $ { i_tradePeriodNodeBus(tp,n,b) and
                       i_tradePeriodBusIsland(tp,b,ild)
                     } , used_TradePeriodIslandScale(tp,ild)
                       * i_tradePeriodNodeBusAllocationFactor(tp,n,b)
                       * temp_TradePeriodNodeDemand(tp,n)
         ]  ;

* Node demand overrides --> overwriten island override as node level
i_tradePeriodNodeDemand(tp,n) $ ovrd_tradePeriodNodeDemand(tp,n,'scale')
    = temp_TradePeriodNodeDemand(tp,n)
    * ovrd_tradePeriodNodeDemand(tp,n,'scale') ;

i_tradePeriodNodeDemand(tp,n)
    $ { ovrd_tradePeriodNodeDemand(tp,n,'scale')
    and (ovrd_tradePeriodNodeDemand(tp,n,'scale') = eps) }
    = 0;

i_tradePeriodNodeDemand(tp,n) $ ovrd_tradePeriodNodeDemand(tp,n,'increment')
    = temp_TradePeriodNodeDemand(tp,n)
    + ovrd_tradePeriodNodeDemand(tp,n,'increment');

i_tradePeriodNodeDemand(tp,n) $ ovrd_tradePeriodNodeDemand(tp,n,'value')
    = ovrd_tradePeriodNodeDemand(tp,n,'value') ;

i_tradePeriodNodeDemand(tp,n)
    $ { ovrd_tradePeriodNodeDemand(tp,n,'value')
    and (ovrd_tradePeriodNodeDemand(tp,n,'value') = eps) }
    = 0;



*=========================================================================================================================
* 3. Bid and Offer overrides - incl. bid, energy, PLSR, TWDR, and ILR
*=========================================================================================================================
*Loading data from gdx file
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"

$load ovrd_tradePeriodEnergyOffer = energyOfferOverrides
$load ovrd_dateTimeEnergyOffer = energyOfferOverrides

$load ovrd_tradePeriodOfferParameter = offerParameterOverrides
$load ovrd_dateTimeOfferParameter = offerParameterOverrides
$load ovrd_tradePeriodReserveClassGenerationMaximum = offerParameterOverrides
$load ovrd_dateTimeReserveClassGenerationMaximum = offerParameterOverrides

$load ovrd_tradePeriodFastILRoffer = fastILROfferOverrides
$load ovrd_dateTimeFastILRoffer = fastILROfferOverrides
$load ovrd_tradePeriodSustainedILRoffer = sustainedILROfferOverrides
$load ovrd_dateTimeSustainedILRoffer = sustainedILROfferOverrides

$load ovrd_tradePeriodFastPLSRoffer = fastPLSROfferOverrides
$load ovrd_dateTimeFastPLSRoffer = fastPLSROfferOverrides
$load ovrd_tradePeriodSustainedPLSRoffer = sustainedPLSROfferOverrides
$load ovrd_dateTimeSustainedPLSRoffer = sustainedPLSROfferOverrides

$load ovrd_tradePeriodFastTWDRoffer = fastTWDROfferOverrides
$load ovrd_dateTimeFastTWDRoffer = fastTWDROfferOverrides
$load ovrd_tradePeriodSustainedTWDRoffer = sustainedTWDROfferOverrides
$load ovrd_dateTimeSustainedTWDRoffer = sustainedTWDROfferOverrides

$load ovrd_tradePeriodEnergyBid = energyBidOverrides
$load ovrd_dateTimeEnergyBid = energyBidOverrides
$load ovrd_tradePeriodDispatchableBid = dispatchableEnergyBidOverrides
$load ovrd_datetimeDispatchableBid = dispatchableEnergyBidOverrides

$gdxin

*overwrite period offer override by datetime offer override if datetime offer override exists (>0)
Loop i_dateTimeTradePeriodMap(dt,tp) do
    ovrd_tradePeriodEnergyOffer(tp,o,trdBlk,NRGofrCmpnt)
        $ ovrd_dateTimeEnergyOffer(dt,o,trdBlk,NRGofrCmpnt)
        = ovrd_dateTimeEnergyOffer(dt,o,trdBlk,NRGofrCmpnt) ;

    ovrd_tradePeriodOfferParameter(tp,i_offer,i_offerParam)
        $ ovrd_dateTimeOfferParameter(dt,i_offer,i_offerParam)
        = ovrd_dateTimeOfferParameter(dt,i_offer,i_offerParam) ;

    ovrd_tradePeriodFastPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)
        $ ovrd_dateTimeFastPLSRoffer(dt,o,trdBlk,PLSofrCmpnt)
        = ovrd_dateTimeFastPLSRoffer(dt,o,trdBlk,PLSofrCmpnt) ;

    ovrd_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)
        $ ovrd_dateTimeSustainedPLSRoffer(dt,o,trdBlk,PLSofrCmpnt)
        = ovrd_dateTimeSustainedPLSRoffer(dt,o,trdBlk,PLSofrCmpnt) ;

    ovrd_tradePeriodFastTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)
        $ ovrd_dateTimeFastTWDRoffer(dt,o,trdBlk,TWDofrCmpnt)
        = ovrd_dateTimeFastTWDRoffer(dt,o,trdBlk,TWDofrCmpnt) ;

    ovrd_tradePeriodSustainedTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)
        $ ovrd_dateTimeSustainedTWDRoffer(dt,o,trdBlk,TWDofrCmpnt)
        = ovrd_dateTimeSustainedTWDRoffer(dt,o,trdBlk,TWDofrCmpnt) ;

    ovrd_tradePeriodFastILRoffer(tp,o,trdBlk,ILofrCmpnt)
        $ ovrd_dateTimeFastILRoffer(dt,o,trdBlk,ILofrCmpnt)
        = ovrd_dateTimeFastILRoffer(dt,o,trdBlk,ILofrCmpnt) ;

    ovrd_tradePeriodSustainedILRoffer(tp,o,trdBlk,ILofrCmpnt)
        $ ovrd_dateTimeSustainedILRoffer(dt,o,trdBlk,ILofrCmpnt)
        = ovrd_dateTimeSustainedILRoffer(dt,o,trdBlk,ILofrCmpnt) ;

    ovrd_tradePeriodReserveClassGenerationMaximum(tp,o,resC)
        $ ovrd_dateTimeReserveClassGenerationMaximum(dt,o,resC)
        = ovrd_dateTimeReserveClassGenerationMaximum(dt,o,resC) ;

    ovrd_tradePeriodEnergyBid(tp,i_bid,trdBlk,NRGbidCmpnt)
        $ ovrd_dateTimeEnergyBid(dt,i_bid,trdBlk,NRGbidCmpnt)
        = ovrd_dateTimeEnergyBid(dt,i_bid,trdBlk,NRGbidCmpnt) ;

    ovrd_tradePeriodDispatchableBid(tp,i_bid)
        $ ovrd_datetimeDispatchableBid(dt,i_bid)
        = ovrd_datetimeDispatchableBid(dt,i_bid) ;
EndLoop;

* Energy offer overrides
i_tradePeriodEnergyOffer(tp,i_offer,trdBlk,NRGofrCmpnt)
    $ (ovrd_tradePeriodEnergyOffer(tp,i_offer,trdBlk,NRGofrCmpnt) > 0)
    = ovrd_tradePeriodEnergyOffer(tp,i_offer,trdBlk,NRGofrCmpnt) ;

i_tradePeriodEnergyOffer(tp,i_offer,trdBlk,NRGofrCmpnt)
    $ { ovrd_tradePeriodEnergyOffer(tp,i_offer,trdBlk,NRGofrCmpnt)
    and (ovrd_tradePeriodEnergyOffer(tp,i_offer,trdBlk,NRGofrCmpnt) = eps)
      } = 0 ;

* Offer parameter overrides
i_tradePeriodOfferParameter(tp,i_offer,i_offerParam)
    $ (ovrd_tradePeriodOfferParameter(tp,i_offer,i_offerParam) > 0)
    = ovrd_tradePeriodOfferParameter(tp,i_offer,i_offerParam) ;

i_tradePeriodOfferParameter(tp,i_offer,i_offerParam)
    $ { ovrd_tradePeriodOfferParameter(tp,i_offer,i_offerParam)
    and (ovrd_tradePeriodOfferParameter(tp,i_offer,i_offerParam) = eps )
      } = 0 ;

* PLSR offer overrides
i_tradePeriodFastPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)
    $ (ovrd_tradePeriodFastPLSRoffer(tp,o,trdBlk,PLSofrCmpnt) > 0)
    = ovrd_tradePeriodFastPLSRoffer(tp,o,trdBlk,PLSofrCmpnt) ;

i_tradePeriodFastPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)
    $ { ovrd_tradePeriodFastPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)
    and (ovrd_tradePeriodFastPLSRoffer(tp,o,trdBlk,PLSofrCmpnt) = eps)
      } = 0 ;

i_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)
    $ (ovrd_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,PLSofrCmpnt) > 0)
    = ovrd_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,PLSofrCmpnt) ;

i_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)
    $ { ovrd_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,PLSofrCmpnt)
    and (ovrd_tradePeriodSustainedPLSRoffer(tp,o,trdBlk,PLSofrCmpnt) = eps)
      } = 0 ;

* TWDR offer overrides
i_tradePeriodFastTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)
    $ (ovrd_tradePeriodFastTWDRoffer(tp,o,trdBlk,TWDofrCmpnt) > 0)
    = ovrd_tradePeriodFastTWDRoffer(tp,o,trdBlk,TWDofrCmpnt) ;

i_tradePeriodFastTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)
    $ { ovrd_tradePeriodFastTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)
    and (ovrd_tradePeriodFastTWDRoffer(tp,o,trdBlk,TWDofrCmpnt) = eps)
      } = 0 ;

i_tradePeriodSustainedTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)
    $ (ovrd_tradePeriodSustainedTWDRoffer(tp,o,trdBlk,TWDofrCmpnt) > 0)
    = ovrd_tradePeriodSustainedTWDRoffer(tp,o,trdBlk,TWDofrCmpnt) ;

i_tradePeriodSustainedTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)
    $ { ovrd_tradePeriodSustainedTWDRoffer(tp,o,trdBlk,TWDofrCmpnt)
    and (ovrd_tradePeriodSustainedTWDRoffer(tp,o,trdBlk,TWDofrCmpnt) = eps)
      } = 0 ;

* ILR offer overrides
i_tradePeriodFastILRoffer(tp,o,trdBlk,ILofrCmpnt)
    $ (ovrd_tradePeriodFastILRoffer(tp,o,trdBlk,ILofrCmpnt) > 0)
    =  ovrd_tradePeriodFastILRoffer(tp,o,trdBlk,ILofrCmpnt) ;

i_tradePeriodFastILRoffer(tp,o,trdBlk,ILofrCmpnt)
    $ { ovrd_tradePeriodFastILRoffer(tp,o,trdBlk,ILofrCmpnt)
    and (ovrd_tradePeriodFastILRoffer(tp,o,trdBlk,ILofrCmpnt) = eps)
      } = 0 ;

i_tradePeriodSustainedILRoffer(tp,o,trdBlk,ILofrCmpnt)
    $ (ovrd_tradePeriodSustainedILRoffer(tp,o,trdBlk,ILofrCmpnt) > 0)
    =  ovrd_tradePeriodSustainedILRoffer(tp,o,trdBlk,ILofrCmpnt) ;

i_tradePeriodSustainedILRoffer(tp,o,trdBlk,ILofrCmpnt)
    $ { ovrd_tradePeriodSustainedILRoffer(tp,o,trdBlk,ILofrCmpnt)
    and (ovrd_tradePeriodSustainedILRoffer(tp,o,trdBlk,ILofrCmpnt) = eps)
      } = 0 ;

* Genertion Reserve Class Capacity
i_tradePeriodReserveClassGenerationMaximum(tp,o,resC)
    $ (ovrd_tradePeriodReserveClassGenerationMaximum(tp,o,resC) > 0)
    = ovrd_tradePeriodReserveClassGenerationMaximum(tp,o,resC) ;

i_tradePeriodReserveClassGenerationMaximum(tp,o,resC)
    $ { ovrd_tradePeriodReserveClassGenerationMaximum(tp,o,resC)
    and (ovrd_tradePeriodReserveClassGenerationMaximum(tp,o,resC) = eps)
      } = 0 ;

* Enegry bid overrides
i_tradePeriodEnergyBid(tp,i_bid,trdBlk,NRGbidCmpnt)
    $ (ovrd_tradePeriodEnergyBid(tp,i_bid,trdBlk,NRGbidCmpnt) > 0)
    = ovrd_tradePeriodEnergyBid(tp,i_bid,trdBlk,NRGbidCmpnt) ;

i_tradePeriodEnergyBid(tp,i_bid,trdBlk,NRGbidCmpnt)
    $ { ovrd_tradePeriodEnergyBid(tp,i_bid,trdBlk,NRGbidCmpnt)
    and (ovrd_tradePeriodEnergyBid(tp,i_bid,trdBlk,NRGbidCmpnt) = eps)
      } = 0 ;

i_tradePeriodDispatchableBid(tp,i_bid)
    $ (ovrd_tradePeriodDispatchableBid(tp,i_bid) > 0) = yes ;

i_tradePeriodDispatchableBid(tp,i_bid)
    $ { ovrd_tradePeriodDispatchableBid(tp,i_bid)
    and (ovrd_tradePeriodDispatchableBid(tp,i_bid) = eps)
      } = no ;

$offEnd


* End of file
