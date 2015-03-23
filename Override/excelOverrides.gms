$onempty
Parameter ovrd_tradePeriodNodeDemand(*,*,*) 'Override i_tradePeriodNodeDemand by time, location and method'
/
'TP1'.'ABY0111'.'value'            50
'TP1'.'SI'.'scale'                 1.1
/ ;


Parameter ovrd_tradePeriodEnergyOffer(*,*,*,*) 'Override i_tradePeriodEnergyOffer by time, offer, block and component'
/
'TP1'.'ARA2201 ARA0'.'t1'.'i_GenerationMWOffer'             30
'TP1'.'ARA2201 ARA0'.'t3'.'i_GenerationMWOffer'             8
'TP1'.'ARA2201 ARA0'.'t5'.'i_GenerationMWOffer'             40
/ ;


Parameter ovrd_tradePeriodOfferParameter(*,*,*) 'Override i_tradePeriodOfferParameter by time, offer and parameter'
/
/ ;


Parameter ovrd_tradePeriodReserveOffer(*,*,*,*,*) 'Override for reserve offers for by time, offer, block, reserve class, reserve type and component'
/
/ ;


Parameter ovrd_tradePeriodEnergyBid(*,*,*,*) 'Override for energy bid for by trading period, bid, block and component'
/
/ ;
$offempty
