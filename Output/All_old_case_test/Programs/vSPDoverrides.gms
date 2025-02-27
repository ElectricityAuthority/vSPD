*=====================================================================================
* Name:                 vSPDoverrides.gms
* Function:             Code to be included in vSPDsolve to take care of input data
*                       overrides.
* Developed by:         Electricity Authority, New Zealand
* Source:               https://github.com/ElectricityAuthority/vSPD
*                       https://www.emi.ea.govt.nz/Tools/vSPD
* Contact:              Forum: https://www.emi.ea.govt.nz/forum/
*                       Email: emi@ea.govt.nz
* Last modified on:     10 November 2023
*
*=====================================================================================

$ontext
This code is included into vSPDsolve.gms if an override file defined by
the $setglobal vSPDinputOvrdData in vSPDSetting.inc exists.

The prefix ovrd_ inidcates that the symbol contains data to override
the original input data, prefixed with i_.

After declaring the override symbols, the override data is installed and
the original symbols are overwritten.

Note that:
User use the Excel interface to create overrdies in GDX format.

Directory of code sections in vSPDoverrides.gms:
  1. Demand overrides
  2. Offer parameter overrides
  3. Offer energy overrides
  4. Offer reserve overrides 
  5. Bid parameter overrides
  6. Demand Bid overrides
  7. Branch parameter overrides
  8. Branch constraint RHS overrides
  9. Branch constraint factors overrides
  10. Market node constraint RHS overrides
  11. Market node constraint factor overrides

$offtext



* mapping data
case2dt(ca,dt)          = yes $ sum[ tp $ case2dt2tp(ca,dt,tp), 1] ;
node(ca,dt,n) = yes $ sum[ b $ nodeBus(ca,dt,n,b), 1 ] ;
bus(ca,dt,b)  = yes $ sum[ isl $ busIsland(ca,dt,b,isl), 1 ] ;
nodeIsland(ca,dt,n,isl) $ sum[ b $ { bus(ca,dt,b) and node(ca,dt,n) and nodeBus(ca,dt,n,b) and busIsland(ca,dt,b,isl) }, 1 ] = yes ;

*=========================================================================================================================
* 1. Demand overrides
*=========================================================================================================================
$onText
- When : By "all time" is applied first, by "period" are applied second and take precedence over "all time", by "caseID" are
         applied next and take precedence over  "period" and datetime are applied last and take precedence over "caseID".

- Where: By "all nodes" is applied first, by "island" are applied second and take precedence over "all nodes", and datetime
         are applied last and take precedence over "caseID".

- Type : By "all load types" is applied first, by "conforming/nonconform" are applied second and take precedence over "all load type".

- How  : scaling is applied first, increments are applied second and take precedence over scaling,
         and values are applied last and take precedence over increments.

- Increment and value overrides applied to island/NZ level will be distributed to positive load only.
$offText
Sets
  alll             'set that indicate the overrides appied to all element in a dimension'  / All /
  type             'Demand override applied to load type'                                  / All, Conforming, Nonconform /
  how              'Demand override method'                                                / scale, increment, value /
;

Parameters
* Demand
  ovrd_Demand_AllTime_All(alll,alll,type,how)     'Demand override applied to all nodes all the time'
  ovrd_Demand_Period_All(tp,alll,type,how)        'Demand override applied to all nodes for a trading period every day'
  ovrd_Demand_CaseID_All(ca,alll,type,how)        'Demand override applied to all nodes for a CaseID'
  ovrd_Demand_DateTime_All(dt,alll,type,how)      'Demand override applied  to all nodes for a DateTime'

  ovrd_Demand_AllTime_Island(alll,isl,type,how)   'Island demand override applied all the time'
  ovrd_Demand_Period_Island(tp,isl,type,how)      'Island demand override applied to a trading period every day'
  ovrd_Demand_CaseID_Island(ca,isl,type,how)      'Island demand override applied to a CaseID'
  ovrd_Demand_DateTime_Island(dt,isl,type,how)    'Island demand override applied to a DateTime'

  ovrd_Demand_AllTime_Node(alll,n,type,how)       'Node demand override applied all the time'
  ovrd_Demand_Period_Node(tp,n,type,how)          'Node demand override applied to a trading period every day'
  ovrd_Demand_CaseID_Node(ca,n,type,how)          'Node demand override applied to a CaseID'
  ovrd_Demand_DateTime_Node(dt,n,type,how)        'Node demand override applied to a DateTime'

* temporary calculated parameters
  positive_IslandDemand(ca,dt,isl,type) 'Temporary container for island positive demand value while implementing the island-based scaling factor'
  negative_IslandDemand(ca,dt,isl,type) 'Temporary container for island negative demand value while implementing the island-based scaling factor'
  positive_NZDemand(ca,dt,type)         'Temporary container for NZ positive demand value while implementing the island-based scaling factor'
  negative_NZDemand(ca,dt,type)         'Temporary container for NZ negative demand value while implementing the island-based scaling factor'
  temp_NodeDemandScale(ca,dt,n)         'Final scaling factor applied to node level'
;


*Loading data from gdx file
$onEps
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"

$load ovrd_Demand_AllTime_All  = demand_overrides
$load ovrd_Demand_Period_All   = demand_overrides
$load ovrd_Demand_DateTime_All = demand_overrides
$load ovrd_Demand_CaseID_All   = demand_overrides

$load ovrd_Demand_AllTime_Island  = demand_overrides
$load ovrd_Demand_Period_Island   = demand_overrides
$load ovrd_Demand_DateTime_Island = demand_overrides
$load ovrd_Demand_CaseID_Island   = demand_overrides

$load ovrd_Demand_AllTime_Node  = demand_overrides
$load ovrd_Demand_Period_Node   = demand_overrides
$load ovrd_Demand_DateTime_Node = demand_overrides
$load ovrd_Demand_CaseID_Node   = demand_overrides

$gdxin
$offEps

* Calculate temporary parameters for overrdie process
if (1=1,

positive_IslandDemand(case2dt(ca,dt),isl,'All')        = sum[ n $ {nodeIsland(ca,dt,n,isl) and (nodeParameter(ca,dt,n,'demand') > 0)                                             }, nodeParameter(ca,dt,n,'demand')];
positive_IslandDemand(case2dt(ca,dt),isl,'Nonconform') = sum[ n $ {nodeIsland(ca,dt,n,isl) and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')      }, nodeParameter(ca,dt,n,'demand')];
positive_IslandDemand(case2dt(ca,dt),isl,'Conforming') = sum[ n $ {nodeIsland(ca,dt,n,isl) and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))}, nodeParameter(ca,dt,n,'demand')];

negative_IslandDemand(case2dt(ca,dt),isl,'All')        = sum[ n $ {nodeIsland(ca,dt,n,isl) and (nodeParameter(ca,dt,n,'demand') < 0)                                             }, nodeParameter(ca,dt,n,'demand')];
negative_IslandDemand(case2dt(ca,dt),isl,'Nonconform') = sum[ n $ {nodeIsland(ca,dt,n,isl) and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL')      }, nodeParameter(ca,dt,n,'demand')];
negative_IslandDemand(case2dt(ca,dt),isl,'Conforming') = sum[ n $ {nodeIsland(ca,dt,n,isl) and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))}, nodeParameter(ca,dt,n,'demand')];

positive_NZDemand(case2dt(ca,dt),'All')        = sum[ n $ {(nodeParameter(ca,dt,n,'demand') > 0)                                             }, nodeParameter(ca,dt,n,'demand')];
positive_NZDemand(case2dt(ca,dt),'Nonconform') = sum[ n $ {(nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')      }, nodeParameter(ca,dt,n,'demand')];
positive_NZDemand(case2dt(ca,dt),'Conforming') = sum[ n $ {(nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))}, nodeParameter(ca,dt,n,'demand')];

negative_NZDemand(case2dt(ca,dt),'All')        = sum[ n $ {(nodeParameter(ca,dt,n,'demand') < 0)                                             }, nodeParameter(ca,dt,n,'demand')];
negative_NZDemand(case2dt(ca,dt),'Nonconform') = sum[ n $ {(nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL')      }, nodeParameter(ca,dt,n,'demand')];
negative_NZDemand(case2dt(ca,dt),'Conforming') = sum[ n $ {(nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))}, nodeParameter(ca,dt,n,'demand')];

temp_NodeDemandScale(case2dt(ca,dt),n) $ nodeParameter(ca,dt,n,'demand') = 1;
) ;

* Overrides applied all the time
if (1=1,

* Overrides applied all the time for entire NZ
if (1=1,

* Calculate scaling factor for demand scale overrides applied to all time, every where
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_AllTime_All('All','All','All','scale') and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = ovrd_Demand_AllTime_All('All','All','All','scale') ;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_AllTime_All('All','All','Nonconform','scale') and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                       } = ovrd_Demand_AllTime_All('All','All','Nonconform','scale') ;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_AllTime_All('All','All','Conforming','scale') and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = ovrd_Demand_AllTime_All('All','All','Conforming','scale') ;


* Calculate scaling factor for demand increment overrides applied to all time, every where
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_AllTime_All('All','All','All','increment')        and (nodeParameter(ca,dt,n,'demand') > 0) }
    = [ ovrd_Demand_AllTime_All('All','All','All','increment') + positive_NZDemand(ca,dt,'All') ] / positive_NZDemand(ca,dt,'All') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_AllTime_All('All','All','Nonconform','increment') and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL') }
    = [ ovrd_Demand_AllTime_All('All','All','Nonconform','increment') + positive_NZDemand(ca,dt,'Nonconform') ] / positive_NZDemand(ca,dt,'Nonconform') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_AllTime_All('All','All','Conforming','increment') and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = [ ovrd_Demand_AllTime_All('All','All','Conforming','increment') + positive_NZDemand(ca,dt,'Conforming') ] / positive_NZDemand(ca,dt,'Conforming') ;


* Calculate scaling factor for demand value overrides applied to all time, every where
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_AllTime_All('All','All','All','value')        and (nodeParameter(ca,dt,n,'demand') > 0) }
    = [ovrd_Demand_AllTime_All('All','All','All','value') - negative_NZDemand(ca,dt,'All')] / positive_NZDemand(ca,dt,'All') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_AllTime_All('All','All','Nonconform','value') and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL') }
    = [ovrd_Demand_AllTime_All('All','All','Nonconform','value') - negative_NZDemand(ca,dt,'Nonconform')] / positive_NZDemand(ca,dt,'Nonconform') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_AllTime_All('All','All','Conforming','value') and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = [ ovrd_Demand_AllTime_All('All','All','Conforming','value') - negative_NZDemand(ca,dt,'Conforming')] / positive_NZDemand(ca,dt,'Conforming') ;

) ;


* Overrides applied all the time for island
if (1=1,

* Calculate scaling factor for demand scale overrdies applied to all time and an island
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_AllTime_Island('All',isl,'All','scale') ] and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_AllTime_Island('All',isl,'All','scale') ] ;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_AllTime_Island('All',isl,'Nonconform','scale') ]
                                       and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_AllTime_Island('All',isl,'Nonconform','scale') ];
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_AllTime_Island('All',isl,'Conforming','scale') ]
                                       and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_AllTime_Island('All',isl,'Conforming','scale') ] ;


* Calculate scaling factor for demand increment overrdies applied to all time and an island
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_AllTime_Island('All',isl,'All','increment')]
                                       and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), { ovrd_Demand_AllTime_Island('All',isl,'All','increment') + positive_IslandDemand(ca,dt,isl,'All')
                                                                                 } / positive_IslandDemand(ca,dt,isl,'All') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_AllTime_Island('All',isl,'Nonconform','increment')]
                                       and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), { ovrd_Demand_AllTime_Island('All',isl,'Nonconform','increment') + positive_IslandDemand(ca,dt,isl,'Nonconform')
                                                                                 } / positive_IslandDemand(ca,dt,isl,'Nonconform') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_AllTime_Island('All',isl,'Conforming','increment')]
                                       and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), { ovrd_Demand_AllTime_Island('All',isl,'Conforming','increment') + positive_IslandDemand(ca,dt,isl,'Conforming')
                                                                                 } / positive_IslandDemand(ca,dt,isl,'Conforming') ] ;


* Calculate scaling factor for demand value overrdies applied to all time and an island
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_AllTime_Island('All',isl,'All','value')]
                                       and (nodeParameter(ca,dt,n,'demand') > 0) }
    = sum[ isl $ nodeIsland(ca,dt,n,isl), { ovrd_Demand_AllTime_Island('All',isl,'All','value') - negative_IslandDemand(ca,dt,isl,'All')
                                          } / positive_IslandDemand(ca,dt,isl,'All') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_AllTime_Island('All',isl,'Nonconform','value')]
                                       and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL') }
    = sum[ isl $ nodeIsland(ca,dt,n,isl), { ovrd_Demand_AllTime_Island('All',isl,'Nonconform','value') - negative_IslandDemand(ca,dt,isl,'Nonconform')
                                          } / positive_IslandDemand(ca,dt,isl,'Nonconform') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_AllTime_Island('All',isl,'Conforming','value')]
                                       and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = sum[ isl $ nodeIsland(ca,dt,n,isl), { ovrd_Demand_AllTime_Island('All',isl,'Conforming','value') - negative_IslandDemand(ca,dt,isl,'Conforming')
                                          } / positive_IslandDemand(ca,dt,isl,'Conforming') ] ;

);


* Overrides applied all the time for node
if (1=1,

* Calculate scaling factor for demand scale overrdies applied to all time and a node
temp_NodeDemandScale(case2dt(ca,dt),n) $ {ovrd_Demand_AllTime_Node('All',n,'All','scale') and nodeParameter(ca,dt,n,'demand')                                                    } = ovrd_Demand_AllTime_Node('All',n,'All','scale') ;                                         
temp_NodeDemandScale(case2dt(ca,dt),n) $ {ovrd_Demand_AllTime_Node('All',n,'Nonconform','scale') and nodeParameter(ca,dt,n,'demand') and      nodeParameter(ca,dt,n,'loadIsNCL') } = ovrd_Demand_AllTime_Node('All',n,'Nonconform','scale');
temp_NodeDemandScale(case2dt(ca,dt),n) $ {ovrd_Demand_AllTime_Node('All',n,'Conforming','scale') and nodeParameter(ca,dt,n,'demand') and (not nodeParameter(ca,dt,n,'loadIsNCL'))} = ovrd_Demand_AllTime_Node('All',n,'Conforming','scale');


* Calculate scaling factor for demand increment overrdies applied to all time and a node
temp_NodeDemandScale(case2dt(ca,dt),n) $ ovrd_Demand_AllTime_Node('All',n,'All','increment')
    = [ ovrd_Demand_AllTime_Node('All',n,'All','increment') $ (nodeParameter(ca,dt,n,'demand') = 0) ]
    + [(ovrd_Demand_AllTime_Node('All',n,'All','increment') + nodeParameter(ca,dt,n,'demand'))/nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ {ovrd_Demand_AllTime_Node('All',n,'Nonconform','increment') and nodeParameter(ca,dt,n,'loadIsNCL') }
    = [ ovrd_Demand_AllTime_Node('All',n,'Nonconform','increment') $ (nodeParameter(ca,dt,n,'demand') = 0) ]
    + [(ovrd_Demand_AllTime_Node('All',n,'Nonconform','increment') + nodeParameter(ca,dt,n,'demand'))/nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ {ovrd_Demand_AllTime_Node('All',n,'Conforming','increment') and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = [ ovrd_Demand_AllTime_Node('All',n,'Conforming','increment') $ (nodeParameter(ca,dt,n,'demand') = 0) ]
    + [(ovrd_Demand_AllTime_Node('All',n,'Conforming','increment') + nodeParameter(ca,dt,n,'demand'))/nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;


* Calculate scaling factor for demand value overrdies applied to all time and a node
temp_NodeDemandScale(case2dt(ca,dt),n) $ ovrd_Demand_AllTime_Node('All',n,'All','value')
    = [ ovrd_Demand_AllTime_Node('All',n,'All','value') $ (nodeParameter(ca,dt,n,'demand') = 0) ]
    + [ ovrd_Demand_AllTime_Node('All',n,'All','value') / nodeParameter(ca,dt,n,'demand') ] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ {ovrd_Demand_AllTime_Node('All',n,'Nonconform','value') and nodeParameter(ca,dt,n,'loadIsNCL') }
    = [ ovrd_Demand_AllTime_Node('All',n,'Nonconform','value') $ (nodeParameter(ca,dt,n,'demand') = 0) ]
    + [ ovrd_Demand_AllTime_Node('All',n,'Nonconform','value') / nodeParameter(ca,dt,n,'demand') ] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ {ovrd_Demand_AllTime_Node('All',n,'Conforming','value') and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = [ ovrd_Demand_AllTime_Node('All',n,'Conforming','value') $ (nodeParameter(ca,dt,n,'demand') = 0) ]
    + [ ovrd_Demand_AllTime_Node('All',n,'Conforming','value') / nodeParameter(ca,dt,n,'demand') ] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;

);

);
* Overrides applied all the time end


* Overrides applied to a trading period
if (1=1,

* Overrides applied to a trading period time for entire NZ
if (1=1,

* Calculate scaling factor for demand scale overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','All','scale')] and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','All','scale')] and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','All','scale')] and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','All','scale')] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Nonconform','scale')]
                                       and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Nonconform','scale')]
                                       and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Nonconform','scale')]
                                       and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Nonconform','scale')] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Conforming','scale')]
                                       and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Conforming','scale')]
                                       and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Conforming','scale')]
                                       and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Conforming','scale')] ;


* Calculate scaling factor for demand increment overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','All','increment')] and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','All','increment')] and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','All','increment')] and (nodeParameter(ca,dt,n,'demand') > 0) }
    = [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','All','increment')] + positive_NZDemand(ca,dt,'All') ] / positive_NZDemand(ca,dt,'All') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Nonconform','increment')] and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Nonconform','increment')] and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Nonconform','increment')]
                                       and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL') }
    = [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Nonconform','increment')] + positive_NZDemand(ca,dt,'Nonconform') ] / positive_NZDemand(ca,dt,'Nonconform') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Conforming','increment')] and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Conforming','increment')] and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Conforming','increment')]
                                       and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Conforming','increment')] + positive_NZDemand(ca,dt,'Conforming') ] / positive_NZDemand(ca,dt,'Conforming') ;


* Calculate scaling factor for demand value overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','All','value')] and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','All','value')] and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','All','value')] and (nodeParameter(ca,dt,n,'demand') > 0) }
    = [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','All','value')] - negative_NZDemand(ca,dt,'All') ] / positive_NZDemand(ca,dt,'All') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Nonconform','value')] and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Nonconform','value')] and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Nonconform','value')] and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL') }
    = [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Nonconform','value')] - negative_NZDemand(ca,dt,'Nonconform') ] / positive_NZDemand(ca,dt,'Nonconform') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Conforming','value')] and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Conforming','value')] and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Conforming','value')] and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_All(tp,'All','Conforming','value')] - negative_NZDemand(ca,dt,'Conforming') ] / positive_NZDemand(ca,dt,'Conforming') ;

) ;


* Overrides applied to a trading period time for island
if (1=1,

* Calculate scaling factor for demand scale overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'All','scale')] and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'All','scale')] and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'All','scale')] and (nodeParameter(ca,dt,n,'demand') > 0) }
    = sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'All','scale')] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Nonconform','scale')] and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Nonconform','scale')] and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Nonconform','scale')] and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL') }
    = sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Nonconform','scale')] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Conforming','scale')] and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Conforming','scale')] and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Conforming','scale')] and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Conforming','scale')] ;


* Calculate scaling factor for demand increment overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'All','increment')] and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'All','increment')] and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'All','increment')] and (nodeParameter(ca,dt,n,'demand') > 0) }
    = sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ( ovrd_Demand_Period_Island(tp,isl,'All','increment') + positive_IslandDemand(ca,dt,isl,'All') ) / positive_IslandDemand(ca,dt,isl,'All') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Nonconform','increment')] and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Nonconform','increment')] and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Nonconform','increment')] and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL') }
    = sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ( ovrd_Demand_Period_Island(tp,isl,'Nonconform','increment') + positive_IslandDemand(ca,dt,isl,'Nonconform') ) / positive_IslandDemand(ca,dt,isl,'Nonconform') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Conforming','increment')] and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Conforming','increment')] and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Conforming','increment')] and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ( ovrd_Demand_Period_Island(tp,isl,'Conforming','increment') + positive_IslandDemand(ca,dt,isl,'Conforming') ) / positive_IslandDemand(ca,dt,isl,'Conforming') ] ;


* Calculate scaling factor for demand value overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'All','value')] and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'All','value')] and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'All','value')] and (nodeParameter(ca,dt,n,'demand') > 0) }
    = sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, [ ovrd_Demand_Period_Island(tp,isl,'All','value') - negative_IslandDemand(ca,dt,isl,'All') ] / positive_IslandDemand(ca,dt,isl,'All') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Nonconform','value')] and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Nonconform','value')] and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Nonconform','value')] and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL') }
    = sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, [ ovrd_Demand_Period_Island(tp,isl,'Nonconform','value') - negative_IslandDemand(ca,dt,isl,'Nonconform') ] / positive_IslandDemand(ca,dt,isl,'Nonconform') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Conforming','value')] and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Conforming','value')] and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, ovrd_Demand_Period_Island(tp,isl,'Conforming','value')] and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = sum[ {case2dt2tp(ca,dt,tp),nodeIsland(ca,dt,n,isl)}, [ ovrd_Demand_Period_Island(tp,isl,'Conforming','value') - negative_IslandDemand(ca,dt,isl,'Conforming') ] / positive_IslandDemand(ca,dt,isl,'Conforming') ] ;

) ;


* Overrides applied to a trading period time for node
if (1=1,
* Calculate scaling factor for demand scale overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'All','scale')] and nodeParameter(ca,dt,n,'demand') }
    = sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'All','scale')];                                        
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Nonconform','scale')]  and nodeParameter(ca,dt,n,'demand') and nodeParameter(ca,dt,n,'loadIsNCL') }
    = sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Nonconform','scale')] ;                                         
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Conforming','scale')]  and nodeParameter(ca,dt,n,'demand') and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Conforming','scale')] ;                                         
 
* Calculate scaling factor for demand increment overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'All','increment')] }
    = [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'All','increment') ]                                                                      $ (nodeParameter(ca,dt,n,'demand') = 0) ]
    + [ sum[ case2dt2tp(ca,dt,tp),(ovrd_Demand_Period_Node(tp,n,'All','increment') + nodeParameter(ca,dt,n,'demand')) / nodeParameter(ca,dt,n,'demand') ] $ (nodeParameter(ca,dt,n,'demand') <> 0)];

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Nonconform','increment')] and nodeParameter(ca,dt,n,'loadIsNCL') }
    = [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Nonconform','increment') ]                                                                       $ (nodeParameter(ca,dt,n,'demand') = 0) ]
    + [ sum[ case2dt2tp(ca,dt,tp),(ovrd_Demand_Period_Node(tp,n,'Nonconform','increment') + nodeParameter(ca,dt,n,'demand') ) / nodeParameter(ca,dt,n,'demand') ] $ (nodeParameter(ca,dt,n,'demand') <> 0)] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Conforming','increment')] and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Conforming','increment') ]                                                                       $ (nodeParameter(ca,dt,n,'demand') = 0) ]
    + [ sum[ case2dt2tp(ca,dt,tp),(ovrd_Demand_Period_Node(tp,n,'Conforming','increment') + nodeParameter(ca,dt,n,'demand') ) / nodeParameter(ca,dt,n,'demand') ] $ (nodeParameter(ca,dt,n,'demand') <> 0)] ;


* Calculate scaling factor for demand value overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'All','value')] }
    = [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'All','value') ]                                   $ (nodeParameter(ca,dt,n,'demand') = 0) ]
    + [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'All','value') / nodeParameter(ca,dt,n,'demand') ] $ (nodeParameter(ca,dt,n,'demand') <> 0)];

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Nonconform','value')] and nodeParameter(ca,dt,n,'loadIsNCL') }
    = [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Nonconform','value') ]                                   $ (nodeParameter(ca,dt,n,'demand') = 0) ]
    + [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Nonconform','value') / nodeParameter(ca,dt,n,'demand') ] $ (nodeParameter(ca,dt,n,'demand') <> 0)] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Conforming','value')] and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Conforming','value') ]                                   $ (nodeParameter(ca,dt,n,'demand') = 0) ]
    + [ sum[ case2dt2tp(ca,dt,tp), ovrd_Demand_Period_Node(tp,n,'Conforming','value') / nodeParameter(ca,dt,n,'demand') ] $ (nodeParameter(ca,dt,n,'demand') <> 0)] ;


);

);
* Overrides applied to a trading period end


* Overrides applied to a datetime
if (1=1,

* Overrides applied to a datetime for entire NZ
if (1=1,

* Calculate scaling factor for demand scale overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','All','scale') and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','All','scale') and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','All','scale') and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = ovrd_Demand_DateTime_All(dt,'All','All','scale') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Nonconform','scale') and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Nonconform','scale') and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Nonconform','scale') and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = ovrd_Demand_DateTime_All(dt,'All','Nonconform','scale') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Conforming','scale') and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Conforming','scale') and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Conforming','scale') and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = ovrd_Demand_DateTime_All(dt,'All','Conforming','scale') ;

* Calculate scaling factor for demand increment overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','All','increment') and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','All','increment') and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','All','increment') and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = [ ovrd_Demand_DateTime_All(dt,'All','All','increment') + positive_NZDemand(ca,dt,'All') ] / positive_NZDemand(ca,dt,'All')  ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Nonconform','increment') and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Nonconform','increment') and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Nonconform','increment') and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = [ ovrd_Demand_DateTime_All(dt,'All','Nonconform','increment') + positive_NZDemand(ca,dt,'Nonconform') ] / positive_NZDemand(ca,dt,'Nonconform')  ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Conforming','increment') and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Conforming','increment') and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Conforming','increment') and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = [ ovrd_Demand_DateTime_All(dt,'All','Conforming','increment') + positive_NZDemand(ca,dt,'Conforming') ] / positive_NZDemand(ca,dt,'Conforming')  ;


* Calculate scaling factor for demand value overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','All','value') and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','All','value') and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','All','value') and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = [ ovrd_Demand_DateTime_All(dt,'All','All','value') - negative_NZDemand(ca,dt,'All') ] / positive_NZDemand(ca,dt,'All') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Nonconform','value') and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Nonconform','value') and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Nonconform','value') and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = [ ovrd_Demand_DateTime_All(dt,'All','Nonconform','value') - negative_NZDemand(ca,dt,'Nonconform') ] / positive_NZDemand(ca,dt,'Nonconform') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Conforming','value') and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Conforming','value') and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_All(dt,'All','Conforming','value') and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = [ ovrd_Demand_DateTime_All(dt,'All','Conforming','value') - negative_NZDemand(ca,dt,'Conforming') ] / positive_NZDemand(ca,dt,'Conforming') ;

) ;


* Overrides applied to a datatime for island
if (1=1,

* Calculate scaling factor for demand scale overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'All','scale') ] and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'All','scale') ] and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'All','scale') ] and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'All','scale') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Nonconform','scale') ] and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Nonconform','scale') ] and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Nonconform','scale') ] and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Nonconform','scale') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Conforming','scale') ] and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Conforming','scale') ] and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Conforming','scale') ] and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Conforming','scale') ] ;


* Calculate scaling factor for demand increment overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'All','increment') ] and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'All','increment') ] and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'All','increment') ] and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), (ovrd_Demand_DateTime_Island(dt,isl,'All','increment') + positive_IslandDemand(ca,dt,isl,'All')) / positive_IslandDemand(ca,dt,isl,'All')] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Nonconform','increment') ] and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Nonconform','increment') ] and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Nonconform','increment') ] and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), (ovrd_Demand_DateTime_Island(dt,isl,'Nonconform','increment') + positive_IslandDemand(ca,dt,isl,'Nonconform')) / positive_IslandDemand(ca,dt,isl,'Nonconform') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Conforming','increment') ] and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Conforming','increment') ] and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Conforming','increment') ] and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), (ovrd_Demand_DateTime_Island(dt,isl,'Conforming','increment') + positive_IslandDemand(ca,dt,isl,'Conforming')) / positive_IslandDemand(ca,dt,isl,'Conforming') ] ;


* Calculate scaling factor for demand value overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'All','value') ] and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'All','value') ] and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'All','value') ] and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), (ovrd_Demand_DateTime_Island(dt,isl,'All','value') - negative_IslandDemand(ca,dt,isl,'All')) / positive_IslandDemand(ca,dt,isl,'All')] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Nonconform','value') ] and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Nonconform','value') ] and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Nonconform','value') ] and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), (ovrd_Demand_DateTime_Island(dt,isl,'Nonconform','value') - negative_IslandDemand(ca,dt,isl,'Nonconform')) / positive_IslandDemand(ca,dt,isl,'Nonconform') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Conforming','value') ] and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Conforming','value') ] and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_DateTime_Island(dt,isl,'Conforming','value') ] and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), (ovrd_Demand_DateTime_Island(dt,isl,'Conforming','value') - negative_IslandDemand(ca,dt,isl,'Conforming')) / positive_IslandDemand(ca,dt,isl,'Conforming') ] ;
) ;


* Overrides applied to a datetime for node
if (1=1,

* Calculate scaling factor for demand scale overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_Node(dt,n,'All','scale')  and nodeParameter(ca,dt,n,'demand') }                                                     = ovrd_Demand_DateTime_Node(dt,n,'All','scale') ;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_Node(dt,n,'Nonconform','scale')  and nodeParameter(ca,dt,n,'demand') and nodeParameter(ca,dt,n,'loadIsNCL') }       = ovrd_Demand_DateTime_Node(dt,n,'Nonconform','scale') ;                                         
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_Node(dt,n,'Conforming','scale')  and nodeParameter(ca,dt,n,'demand') and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = ovrd_Demand_DateTime_Node(dt,n,'Conforming','scale') ;

* Calculate scaling factor for demand increment overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_Node(dt,n,'All','increment') }
    = [ ovrd_Demand_DateTime_Node(dt,n,'All','increment')                                                                      $ (nodeParameter(ca,dt,n,'demand') = 0)]
    + [(ovrd_Demand_DateTime_Node(dt,n,'All','increment') + nodeParameter(ca,dt,n,'demand'))/ nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_Node(dt,n,'Nonconform','increment') and nodeParameter(ca,dt,n,'loadIsNCL') }
    = [ ovrd_Demand_DateTime_Node(dt,n,'Nonconform','increment')                                                                       $ (nodeParameter(ca,dt,n,'demand') = 0)]
    + [(ovrd_Demand_DateTime_Node(dt,n,'Nonconform','increment') + nodeParameter(ca,dt,n,'demand')) / nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_Node(dt,n,'Conforming','increment') and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = [ ovrd_Demand_DateTime_Node(dt,n,'Conforming','increment')                                                                       $ (nodeParameter(ca,dt,n,'demand') = 0)]
    + [(ovrd_Demand_DateTime_Node(dt,n,'Conforming','increment') + nodeParameter(ca,dt,n,'demand')) / nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;


* Calculate scaling factor for demand value overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_Node(dt,n,'All','value') }
    = [ovrd_Demand_DateTime_Node(dt,n,'All','value')                                    $ (nodeParameter(ca,dt,n,'demand') = 0)]
    + [ovrd_Demand_DateTime_Node(dt,n,'All','value') / nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_Node(dt,n,'Nonconform','value')  and nodeParameter(ca,dt,n,'loadIsNCL') }
    = [ovrd_Demand_DateTime_Node(dt,n,'Nonconform','value')                                    $ (nodeParameter(ca,dt,n,'demand') = 0)]
    + [ovrd_Demand_DateTime_Node(dt,n,'Nonconform','value') / nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_DateTime_Node(dt,n,'Conforming','value') and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = [ovrd_Demand_DateTime_Node(dt,n,'Conforming','value')                                    $ (nodeParameter(ca,dt,n,'demand') = 0)]
    + [ovrd_Demand_DateTime_Node(dt,n,'Conforming','value') / nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;
) ;

);
* Overrides applied to a datetime end


* Overrides applied to a CaseID
if (1=1,

* Overrides applied to a CaseID for entire NZ
if (1=1,

* Calculate scaling factor for demand scale overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','All','scale') and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','All','scale') and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','All','scale') and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = ovrd_Demand_CaseID_All(ca,'All','All','scale') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Nonconform','scale') and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Nonconform','scale') and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Nonconform','scale') and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = ovrd_Demand_CaseID_All(ca,'All','Nonconform','scale') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Conforming','scale') and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Conforming','scale') and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Conforming','scale') and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = ovrd_Demand_CaseID_All(ca,'All','Conforming','scale') ;

* Calculate scaling factor for demand increment overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','All','increment') and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','All','increment') and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','All','increment') and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = [ ovrd_Demand_CaseID_All(ca,'All','All','increment') + positive_NZDemand(ca,dt,'All') ] / positive_NZDemand(ca,dt,'All')  ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Nonconform','increment') and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Nonconform','increment') and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Nonconform','increment') and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = [ ovrd_Demand_CaseID_All(ca,'All','Nonconform','increment') + positive_NZDemand(ca,dt,'Nonconform') ] / positive_NZDemand(ca,dt,'Nonconform')  ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Conforming','increment') and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Conforming','increment') and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Conforming','increment') and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = [ ovrd_Demand_CaseID_All(ca,'All','Conforming','increment') + positive_NZDemand(ca,dt,'Conforming') ] / positive_NZDemand(ca,dt,'Conforming')  ;


* Calculate scaling factor for demand value overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','All','value') and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','All','value') and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','All','value') and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = [ ovrd_Demand_CaseID_All(ca,'All','All','value') - negative_NZDemand(ca,dt,'All') ] / positive_NZDemand(ca,dt,'All') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Nonconform','value') and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Nonconform','value') and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Nonconform','value') and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = [ ovrd_Demand_CaseID_All(ca,'All','Nonconform','value') - negative_NZDemand(ca,dt,'Nonconform') ] / positive_NZDemand(ca,dt,'Nonconform') ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Conforming','value') and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Conforming','value') and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_All(ca,'All','Conforming','value') and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = [ ovrd_Demand_CaseID_All(ca,'All','Conforming','value') - negative_NZDemand(ca,dt,'Conforming') ] / positive_NZDemand(ca,dt,'Conforming') ;


) ;


* Overrides applied to a CaseID for island
if (1=1,

* Calculate scaling factor for demand scale overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'All','scale') ] and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'All','scale') ] and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'All','scale') ] and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'All','scale') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Nonconform','scale') ] and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Nonconform','scale') ] and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Nonconform','scale') ] and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Nonconform','scale') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Conforming','scale') ] and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Conforming','scale') ] and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Conforming','scale') ] and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Conforming','scale') ] ;


* Calculate scaling factor for demand increment overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'All','increment') ] and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'All','increment') ] and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'All','increment') ] and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), (ovrd_Demand_CaseID_Island(ca,isl,'All','increment') + positive_IslandDemand(ca,dt,isl,'All')) / positive_IslandDemand(ca,dt,isl,'All')] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Nonconform','increment') ] and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Nonconform','increment') ] and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Nonconform','increment') ] and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), (ovrd_Demand_CaseID_Island(ca,isl,'Nonconform','increment') + positive_IslandDemand(ca,dt,isl,'Nonconform')) / positive_IslandDemand(ca,dt,isl,'Nonconform') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Conforming','increment') ] and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Conforming','increment') ] and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Conforming','increment') ] and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), (ovrd_Demand_CaseID_Island(ca,isl,'Conforming','increment') + positive_IslandDemand(ca,dt,isl,'Conforming')) / positive_IslandDemand(ca,dt,isl,'Conforming') ] ;


* Calculate scaling factor for demand value overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'All','value') ] and (nodeParameter(ca,dt,n,'demand') = 0) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'All','value') ] and (nodeParameter(ca,dt,n,'demand') < 0) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'All','value') ] and (nodeParameter(ca,dt,n,'demand') > 0)
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), (ovrd_Demand_CaseID_Island(ca,isl,'All','value') - negative_IslandDemand(ca,dt,isl,'All')) / positive_IslandDemand(ca,dt,isl,'All')] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Nonconform','value') ] and (nodeParameter(ca,dt,n,'demand') = 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Nonconform','value') ] and (nodeParameter(ca,dt,n,'demand') < 0) and nodeParameter(ca,dt,n,'loadIsNCL') } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Nonconform','value') ] and (nodeParameter(ca,dt,n,'demand') > 0) and nodeParameter(ca,dt,n,'loadIsNCL')
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), (ovrd_Demand_CaseID_Island(ca,isl,'Nonconform','value') - negative_IslandDemand(ca,dt,isl,'Nonconform')) / positive_IslandDemand(ca,dt,isl,'Nonconform') ] ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Conforming','value') ] and (nodeParameter(ca,dt,n,'demand') = 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 0;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Conforming','value') ] and (nodeParameter(ca,dt,n,'demand') < 0) and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = 1;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { sum[ isl $ nodeIsland(ca,dt,n,isl), ovrd_Demand_CaseID_Island(ca,isl,'Conforming','value') ] and (nodeParameter(ca,dt,n,'demand') > 0) and (not nodeParameter(ca,dt,n,'loadIsNCL'))
                                         } = sum[ isl $ nodeIsland(ca,dt,n,isl), (ovrd_Demand_CaseID_Island(ca,isl,'Conforming','value') - negative_IslandDemand(ca,dt,isl,'Conforming')) / positive_IslandDemand(ca,dt,isl,'Conforming') ] ;

) ;


* Overrides applied to a CaseID for node
if (1=1,

* Calculate scaling factor for demand scale overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_Node(ca,n,'All','scale') and nodeParameter(ca,dt,n,'demand') }                                                     = ovrd_Demand_CaseID_Node(ca,n,'All','scale') ;
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_Node(ca,n,'Nonconform','scale') and nodeParameter(ca,dt,n,'demand') and nodeParameter(ca,dt,n,'loadIsNCL') }       = ovrd_Demand_CaseID_Node(ca,n,'Nonconform','scale') ;                                         
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_Node(ca,n,'Conforming','scale') and nodeParameter(ca,dt,n,'demand') and (not nodeParameter(ca,dt,n,'loadIsNCL')) } = ovrd_Demand_CaseID_Node(ca,n,'Conforming','scale') ;

* Calculate scaling factor for demand increment overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_Node(ca,n,'All','increment') }
    = [ ovrd_Demand_CaseID_Node(ca,n,'All','increment')                                                                      $ (nodeParameter(ca,dt,n,'demand') = 0)]
    + [(ovrd_Demand_CaseID_Node(ca,n,'All','increment') + nodeParameter(ca,dt,n,'demand'))/ nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_Node(ca,n,'Nonconform','increment') and nodeParameter(ca,dt,n,'loadIsNCL') }
    = [ ovrd_Demand_CaseID_Node(ca,n,'Nonconform','increment')                                                                       $ (nodeParameter(ca,dt,n,'demand') = 0)]
    + [(ovrd_Demand_CaseID_Node(ca,n,'Nonconform','increment') + nodeParameter(ca,dt,n,'demand')) / nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_Node(ca,n,'Conforming','increment') and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = [ ovrd_Demand_CaseID_Node(ca,n,'Conforming','increment')                                                                       $ (nodeParameter(ca,dt,n,'demand') = 0)]
    + [(ovrd_Demand_CaseID_Node(ca,n,'Conforming','increment') + nodeParameter(ca,dt,n,'demand')) / nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;


* Calculate scaling factor for demand value overrides
temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_Node(ca,n,'All','value') }
    = [ovrd_Demand_CaseID_Node(ca,n,'All','value')                                    $ (nodeParameter(ca,dt,n,'demand') = 0)]
    + [ovrd_Demand_CaseID_Node(ca,n,'All','value') / nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_Node(ca,n,'Nonconform','value')  and nodeParameter(ca,dt,n,'loadIsNCL') }
    = [ovrd_Demand_CaseID_Node(ca,n,'Nonconform','value')                                    $ (nodeParameter(ca,dt,n,'demand') = 0)]
    + [ovrd_Demand_CaseID_Node(ca,n,'Nonconform','value') / nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;

temp_NodeDemandScale(case2dt(ca,dt),n) $ { ovrd_Demand_CaseID_Node(ca,n,'Conforming','value') and (not nodeParameter(ca,dt,n,'loadIsNCL')) }
    = [ovrd_Demand_CaseID_Node(ca,n,'Conforming','value')                                    $ (nodeParameter(ca,dt,n,'demand') = 0)]
    + [ovrd_Demand_CaseID_Node(ca,n,'Conforming','value') / nodeParameter(ca,dt,n,'demand')] $ (nodeParameter(ca,dt,n,'demand') <> 0) ;
) ;

);
* Overrides applied to a CaseID end


nodeParameter(case2dt(ca,dt),n,'demand') $ { (temp_NodeDemandScale(ca,dt,n) <> 0) and (temp_NodeDemandScale(ca,dt,n) <> 1) }
    = temp_NodeDemandScale(ca,dt,n) * nodeParameter(ca,dt,n,'demand') $ nodeParameter(ca,dt,n,'demand')
    + temp_NodeDemandScale(ca,dt,n) $ {nodeParameter(ca,dt,n,'demand') = 0} ;

nodeParameter(case2dt(ca,dt),n,'demand') $ { nodeParameter(ca,dt,n,'demand') = EPS } = 0 ;

*=========================================================================================================================
* Demand overrides end
*=========================================================================================================================



*=========================================================================================================================
* 2. Offer parameter overrides
*=========================================================================================================================

Parameters
  ovrd_OfferParameter_Alltime(alll,o,offerPar)      'Override for energy offer parameters applied all the time'
  ovrd_OfferParameter_Period(tp,o,offerPar)         'Override for energy offer parameters applied to a trading period'
  ovrd_OfferParameter_DateTime(dt,o,offerPar)       'Override for energy offer parameters applied to an interval'
  ovrd_OfferParameter_CaseID(ca,o,offerPar)         'Override for energy offer parameters applied to a caseID'
;

*Loading data from gdx file
$onEps
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load ovrd_OfferParameter_Alltime  = offer_parameter_overrides
$load ovrd_OfferParameter_Period   = offer_parameter_overrides
$load ovrd_OfferParameter_DateTime = offer_parameter_overrides
$load ovrd_OfferParameter_CaseID   = offer_parameter_overrides
$gdxin
$offEps


offerParameter(case2dt(ca,dt),o,offerPar) $ ovrd_OfferParameter_Alltime('All',o,offerPar) = ovrd_OfferParameter_Alltime('All',o,offerPar) ;

offerParameter(case2dt(ca,dt),o,offerPar) $ sum[ case2dt2tp(ca,dt,tp), ovrd_OfferParameter_Period(tp,o,offerPar)] = sum[ case2dt2tp(ca,dt,tp), ovrd_OfferParameter_Period(tp,o,offerPar)] ;

offerParameter(case2dt(ca,dt),o,offerPar) $ ovrd_OfferParameter_DateTime(dt,o,offerPar)   = ovrd_OfferParameter_DateTime(dt,o,offerPar) ;

offerParameter(case2dt(ca,dt),o,offerPar) $ ovrd_OfferParameter_CaseID(ca,o,offerPar)     =  ovrd_OfferParameter_CaseID(ca,o,offerPar) ;

offerParameter(case2dt(ca,dt),o,offerPar) $ { offerParameter(ca,dt,o,offerPar) = EPS } = 0 ;

*=========================================================================================================================
* Offer parameter overrides end
*=========================================================================================================================



*=========================================================================================================================
* 3. Offer energy overrides
*=========================================================================================================================
Parameters
  ovrd_EnergyOffer_Alltime(alll,o,bidofrCmpnt,blk)      'Override for energy offer prices and limits applied all the time'
  ovrd_EnergyOffer_Period(tp,o,bidofrCmpnt,blk)         'Override for energy offer prices and limits applied to a trading period'
  ovrd_EnergyOffer_DateTime(dt,o,bidofrCmpnt,blk)       'Override for energy offer prices and limits applied to an interval'
  ovrd_EnergyOffer_CaseID(ca,o,bidofrCmpnt,blk)         'Override for energy offer prices and limits applied to a caseID'
;

*Loading data from gdx file
$onEps
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load ovrd_EnergyOffer_Alltime  = energy_offer_overrides
$load ovrd_EnergyOffer_Period   = energy_offer_overrides
$load ovrd_EnergyOffer_DateTime = energy_offer_overrides
$load ovrd_EnergyOffer_CaseID   = energy_offer_overrides
$gdxin
$offEps

energyOffer(case2dt(ca,dt),o,blk,bidofrCmpnt) $ ovrd_EnergyOffer_Alltime('All',o,bidofrCmpnt,blk) = ovrd_EnergyOffer_Alltime('All',o,bidofrCmpnt,blk) ;

energyOffer(case2dt(ca,dt),o,blk,bidofrCmpnt) $ sum[case2dt2tp(ca,dt,tp), ovrd_EnergyOffer_Period(tp,o,bidofrCmpnt,blk)] = sum[case2dt2tp(ca,dt,tp), ovrd_EnergyOffer_Period(tp,o,bidofrCmpnt,blk)] ;

energyOffer(case2dt(ca,dt),o,blk,bidofrCmpnt) $ ovrd_EnergyOffer_DateTime(dt,o,bidofrCmpnt,blk)   = ovrd_EnergyOffer_DateTime(dt,o,bidofrCmpnt,blk) ;

energyOffer(case2dt(ca,dt),o,blk,bidofrCmpnt) $ ovrd_EnergyOffer_CaseID(ca,o,bidofrCmpnt,blk)     = ovrd_EnergyOffer_CaseID(ca,o,bidofrCmpnt,blk) ;

energyOffer(case2dt(ca,dt),o,blk,bidofrCmpnt) $ { energyOffer(ca,dt,o,blk,bidofrCmpnt) = EPS } = 0 ;

*=========================================================================================================================
* Offer energy overrides end
*=========================================================================================================================




*=========================================================================================================================
* 4. Offer reserve overrides
*=========================================================================================================================
Parameters
  ovrd_ReserveOffer_Alltime(alll,o,resC,resT,bidofrCmpnt,blk)      'Override for reserve offer prices and limits applied all the time'
  ovrd_ReserveOffer_Period(tp,o,resC,resT,bidofrCmpnt,blk)         'Override for reserve offer prices and limits applied to a trading period'
  ovrd_ReserveOffer_DateTime(dt,o,resC,resT,bidofrCmpnt,blk)       'Override for reserve offer prices and limits applied to an interval'
  ovrd_ReserveOffer_CaseID(ca,o,resC,resT,bidofrCmpnt,blk)         'Override for reserve offer prices and limits applied to a caseID'
;

*Loading data from gdx file
$onEps
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load ovrd_ReserveOffer_Alltime  = reserve_offer_overrides
$load ovrd_ReserveOffer_Period   = reserve_offer_overrides
$load ovrd_ReserveOffer_DateTime = reserve_offer_overrides
$load ovrd_ReserveOffer_CaseID   = reserve_offer_overrides
$gdxin
$offEps


reserveOffer(case2dt(ca,dt),o,resC,resT,blk,bidofrCmpnt) $ ovrd_ReserveOffer_Alltime('All',o,resC,resT,bidofrCmpnt,blk) = ovrd_ReserveOffer_Alltime('All',o,resC,resT,bidofrCmpnt,blk);

reserveOffer(case2dt(ca,dt),o,resC,resT,blk,bidofrCmpnt) $ sum[case2dt2tp(ca,dt,tp), ovrd_ReserveOffer_Period(tp,o,resC,resT,bidofrCmpnt,blk)] = sum[case2dt2tp(ca,dt,tp), ovrd_ReserveOffer_Period(tp,o,resC,resT,bidofrCmpnt,blk)];

reserveOffer(case2dt(ca,dt),o,resC,resT,blk,bidofrCmpnt) $ ovrd_ReserveOffer_DateTime(dt,o,resC,resT,bidofrCmpnt,blk)   = ovrd_ReserveOffer_DateTime(dt,o,resC,resT,bidofrCmpnt,blk);

reserveOffer(case2dt(ca,dt),o,resC,resT,blk,bidofrCmpnt) $ ovrd_ReserveOffer_CaseID(ca,o,resC,resT,bidofrCmpnt,blk)     = ovrd_ReserveOffer_CaseID(ca,o,resC,resT,bidofrCmpnt,blk);

reserveOffer(case2dt(ca,dt),o,resC,resT,blk,bidofrCmpnt) $ { reserveOffer(ca,dt,o,resC,resT,blk,bidofrCmpnt) = EPS } = 0 ;
*=========================================================================================================================
* Offer reserve overrides end
*=========================================================================================================================



*=========================================================================================================================
* 5. Bid parameter overrides
*=========================================================================================================================

Parameters
  ovrd_BidParameter_Alltime(alll,bd,bidPar)      'Override for demand bid parameters applied all the time'
  ovrd_BidParameter_Period(tp,bd,bidPar)         'Override for demand bid parameters applied to a trading period'
  ovrd_BidParameter_DateTime(dt,bd,bidPar)       'Override for demand bid parameters applied to an interval'
  ovrd_BidParameter_CaseID(ca,bd,bidPar)         'Override for demand bid parameters applied to a caseID'
;

*Loading data from gdx file
$onEps
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load ovrd_BidParameter_Alltime  = bid_parameter_overrides
$load ovrd_BidParameter_Period   = bid_parameter_overrides
$load ovrd_BidParameter_DateTime = bid_parameter_overrides
$load ovrd_BidParameter_CaseID   = bid_parameter_overrides
$gdxin
$offEps


bidParameter(case2dt(ca,dt),bd,bidPar) $ ovrd_BidParameter_Alltime('All',bd,bidPar) = ovrd_BidParameter_Alltime('All',bd,bidPar) ;

bidParameter(case2dt(ca,dt),bd,bidPar) $ sum[ case2dt2tp(ca,dt,tp), ovrd_BidParameter_Period(tp,bd,bidPar)] = sum[ case2dt2tp(ca,dt,tp), ovrd_BidParameter_Period(tp,bd,bidPar)] ;

bidParameter(case2dt(ca,dt),bd,bidPar) $ ovrd_BidParameter_DateTime(dt,bd,bidPar)   = ovrd_BidParameter_DateTime(dt,bd,bidPar) ;

bidParameter(case2dt(ca,dt),bd,bidPar) $ ovrd_BidParameter_CaseID(ca,bd,bidPar)     =  ovrd_BidParameter_CaseID(ca,bd,bidPar) ;

bidParameter(case2dt(ca,dt),bd,bidPar) $ { bidParameter(ca,dt,bd,bidPar) = EPS } = 0 ;

*=========================================================================================================================
* Bid parameter overrides end
*=========================================================================================================================



*=========================================================================================================================
* 6. Demand Bid overrides
*=========================================================================================================================
Parameters
  ovrd_DemandBid_Alltime(alll,bd,bidofrCmpnt,blk)      'Override for demand bid prices and limits applied all the time'
  ovrd_DemandBid_Period(tp,bd,bidofrCmpnt,blk)         'Override for demand bid prices and limits applied to a trading period'
  ovrd_DemandBid_DateTime(dt,bd,bidofrCmpnt,blk)       'Override for demand bid prices and limits applied to an interval'
  ovrd_DemandBid_CaseID(ca,bd,bidofrCmpnt,blk)         'Override for demand bid prices and limits applied to a caseID'
;

*Loading data from gdx file
$onEps
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load ovrd_DemandBid_Alltime  = energy_bid_overrides
$load ovrd_DemandBid_Period   = energy_bid_overrides
$load ovrd_DemandBid_DateTime = energy_bid_overrides
$load ovrd_DemandBid_CaseID   = energy_bid_overrides
$gdxin
$offEps

energyBid(case2dt(ca,dt),bd,blk,bidofrCmpnt) $ ovrd_DemandBid_Alltime('All',bd,bidofrCmpnt,blk) = ovrd_DemandBid_Alltime('All',bd,bidofrCmpnt,blk) ;

energyBid(case2dt(ca,dt),bd,blk,bidofrCmpnt) $ sum[case2dt2tp(ca,dt,tp), ovrd_DemandBid_Period(tp,bd,bidofrCmpnt,blk)] = sum[case2dt2tp(ca,dt,tp), ovrd_DemandBid_Period(tp,bd,bidofrCmpnt,blk)] ;

energyBid(case2dt(ca,dt),bd,blk,bidofrCmpnt) $ ovrd_DemandBid_DateTime(dt,bd,bidofrCmpnt,blk)   = ovrd_DemandBid_DateTime(dt,bd,bidofrCmpnt,blk) ;

energyBid(case2dt(ca,dt),bd,blk,bidofrCmpnt) $ ovrd_DemandBid_CaseID(ca,bd,bidofrCmpnt,blk)     = ovrd_DemandBid_CaseID(ca,bd,bidofrCmpnt,blk) ;

energyBid(case2dt(ca,dt),bd,blk,bidofrCmpnt) $ { energyBid(ca,dt,bd,blk,bidofrCmpnt) = EPS } = 0 ;

*=========================================================================================================================
* Demand Bid overrides end
*=========================================================================================================================



*=========================================================================================================================
* 7. Branch parameter overrides
*=========================================================================================================================

Parameters
  ovrd_BranchParameter_Alltime(alll,br,brPar)      'Override for branch parameters applied all the time'
  ovrd_BranchParameter_Period(tp,br,brPar)         'Override for branch parameters applied to a trading period'
  ovrd_BranchParameter_DateTime(dt,br,brPar)       'Override for branch parameters applied to an interval'
  ovrd_BranchParameter_CaseID(ca,br,brPar)         'Override for branch parameters applied to a caseID'
;

*Loading data from gdx file
$onEps
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load ovrd_BranchParameter_Alltime  = branch_parameter_overrides
$load ovrd_BranchParameter_Period   = branch_parameter_overrides
$load ovrd_BranchParameter_DateTime = branch_parameter_overrides
$load ovrd_BranchParameter_CaseID   = branch_parameter_overrides
$gdxin
$offEps


branchParameter(case2dt(ca,dt),br,brPar) $ ovrd_BranchParameter_Alltime('All',br,brPar) = ovrd_BranchParameter_Alltime('All',br,brPar) ;

branchParameter(case2dt(ca,dt),br,brPar) $ sum[ case2dt2tp(ca,dt,tp), ovrd_BranchParameter_Period(tp,br,brPar)] = sum[ case2dt2tp(ca,dt,tp), ovrd_BranchParameter_Period(tp,br,brPar)] ;

branchParameter(case2dt(ca,dt),br,brPar) $ ovrd_BranchParameter_DateTime(dt,br,brPar)   = ovrd_BranchParameter_DateTime(dt,br,brPar) ;

branchParameter(case2dt(ca,dt),br,brPar) $ ovrd_BranchParameter_CaseID(ca,br,brPar)     =  ovrd_BranchParameter_CaseID(ca,br,brPar) ;

branchParameter(case2dt(ca,dt),br,brPar) $ { branchParameter(ca,dt,br,brPar) = EPS } = 0 ;

*=========================================================================================================================
* Branch parameter overrides end
*=========================================================================================================================



*=========================================================================================================================
* 8. Branch constraint RHS overrides
*=========================================================================================================================

Parameters
  ovrd_BranchCnstrRHS_Alltime(alll,brCstr,CstrRHS)      'Override for branch constraint RHS applied all the time'
  ovrd_BranchCnstrRHS_Period(tp,brCstr,CstrRHS)         'Override for branch constraint RHS applied to a trading period'
  ovrd_BranchCnstrRHS_DateTime(dt,brCstr,CstrRHS)       'Override for branch constraint RHS applied to an interval'
  ovrd_BranchCnstrRHS_CaseID(ca,brCstr,CstrRHS)         'Override for branch constraint RHS applied to a caseID'
;

*Loading data from gdx file
$onEps
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load ovrd_BranchCnstrRHS_Alltime  = branch_constraint_overrides
$load ovrd_BranchCnstrRHS_Period   = branch_constraint_overrides
$load ovrd_BranchCnstrRHS_DateTime = branch_constraint_overrides
$load ovrd_BranchCnstrRHS_CaseID   = branch_constraint_overrides
$gdxin
$offEps


branchCstrRHS(case2dt(ca,dt),brCstr,CstrRHS) $ ovrd_BranchCnstrRHS_Alltime('All',brCstr,CstrRHS) = ovrd_BranchCnstrRHS_Alltime('All',brCstr,CstrRHS) ;

branchCstrRHS(case2dt(ca,dt),brCstr,CstrRHS) $ sum[ case2dt2tp(ca,dt,tp), ovrd_BranchCnstrRHS_Period(tp,brCstr,CstrRHS)] = sum[ case2dt2tp(ca,dt,tp), ovrd_BranchCnstrRHS_Period(tp,brCstr,CstrRHS)] ;

branchCstrRHS(case2dt(ca,dt),brCstr,CstrRHS) $ ovrd_BranchCnstrRHS_DateTime(dt,brCstr,CstrRHS)   = ovrd_BranchCnstrRHS_DateTime(dt,brCstr,CstrRHS) ;

branchCstrRHS(case2dt(ca,dt),brCstr,CstrRHS) $ ovrd_BranchCnstrRHS_CaseID(ca,brCstr,CstrRHS)     =  ovrd_BranchCnstrRHS_CaseID(ca,brCstr,CstrRHS) ;

branchCstrRHS(case2dt(ca,dt),brCstr,CstrRHS) $ { branchCstrRHS(ca,dt,brCstr,CstrRHS) = EPS } = 0 ;

*=========================================================================================================================
* Branch constraint RHS overrides end
*=========================================================================================================================



*=========================================================================================================================
* 9. Branch constraint factors overrides
*=========================================================================================================================

Parameters
  ovrd_BranchCnstrFactor_Alltime(alll,brCstr,br)      'Override for branch constraint factor applied all the time'
  ovrd_BranchCnstrFactor_Period(tp,brCstr,br)         'Override for branch constraint factor applied to a trading period'
  ovrd_BranchCnstrFactor_DateTime(dt,brCstr,br)       'Override for branch constraint factor applied to an interval'
  ovrd_BranchCnstrFactor_CaseID(ca,brCstr,br)         'Override for branch constraint factor applied to a caseID'
;

*Loading data from gdx file
$onEps
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load ovrd_BranchCnstrFactor_Alltime  = branch_cnstr_factor_overrides
$load ovrd_BranchCnstrFactor_Period   = branch_cnstr_factor_overrides
$load ovrd_BranchCnstrFactor_DateTime = branch_cnstr_factor_overrides
$load ovrd_BranchCnstrFactor_CaseID   = branch_cnstr_factor_overrides
$gdxin
$offEps


branchCstrFactors(case2dt(ca,dt),brCstr,br) $ ovrd_BranchCnstrFactor_Alltime('All',brCstr,br) = ovrd_BranchCnstrFactor_Alltime('All',brCstr,br) ;

branchCstrFactors(case2dt(ca,dt),brCstr,br) $ sum[ case2dt2tp(ca,dt,tp), ovrd_BranchCnstrFactor_Period(tp,brCstr,br)] = sum[ case2dt2tp(ca,dt,tp), ovrd_BranchCnstrFactor_Period(tp,brCstr,br)] ;

branchCstrFactors(case2dt(ca,dt),brCstr,br) $ ovrd_BranchCnstrFactor_DateTime(dt,brCstr,br)   = ovrd_BranchCnstrFactor_DateTime(dt,brCstr,br) ;

branchCstrFactors(case2dt(ca,dt),brCstr,br) $ ovrd_BranchCnstrFactor_CaseID(ca,brCstr,br)     =  ovrd_BranchCnstrFactor_CaseID(ca,brCstr,br) ;

branchCstrFactors(case2dt(ca,dt),brCstr,br) $ { branchCstrFactors(ca,dt,brCstr,br) = EPS } = 0 ;

*=========================================================================================================================
* Branch constraint factors overrides end
*=========================================================================================================================



*=========================================================================================================================
* 10. Market node constraint RHS overrides
*=========================================================================================================================

Parameters
  ovrd_MnodeCnstrRHS_Alltime(alll,MnodeCstr,CstrRHS)      'Override for market node constraint RHS applied all the time'
  ovrd_MnodeCnstrRHS_Period(tp,MnodeCstr,CstrRHS)         'Override for market node constraint RHS applied to a trading period'
  ovrd_MnodeCnstrRHS_DateTime(dt,MnodeCstr,CstrRHS)       'Override for market node constraint RHS applied to an interval'
  ovrd_MnodeCnstrRHS_CaseID(ca,MnodeCstr,CstrRHS)         'Override for market node constraint RHS applied to a caseID'
;

*Loading data from gdx file
$onEps
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load ovrd_MnodeCnstrRHS_Alltime  = marketnode_constraint_overrides
$load ovrd_MnodeCnstrRHS_Period   = marketnode_constraint_overrides
$load ovrd_MnodeCnstrRHS_DateTime = marketnode_constraint_overrides
$load ovrd_MnodeCnstrRHS_CaseID   = marketnode_constraint_overrides
$gdxin
$offEps


mnCnstrRHS(case2dt(ca,dt),MnodeCstr,CstrRHS) $ ovrd_MnodeCnstrRHS_Alltime('All',MnodeCstr,CstrRHS) = ovrd_MnodeCnstrRHS_Alltime('All',MnodeCstr,CstrRHS) ;

mnCnstrRHS(case2dt(ca,dt),MnodeCstr,CstrRHS) $ sum[ case2dt2tp(ca,dt,tp), ovrd_MnodeCnstrRHS_Period(tp,MnodeCstr,CstrRHS)] = sum[ case2dt2tp(ca,dt,tp), ovrd_MnodeCnstrRHS_Period(tp,MnodeCstr,CstrRHS)] ;

mnCnstrRHS(case2dt(ca,dt),MnodeCstr,CstrRHS) $ ovrd_MnodeCnstrRHS_DateTime(dt,MnodeCstr,CstrRHS)   = ovrd_MnodeCnstrRHS_DateTime(dt,MnodeCstr,CstrRHS) ;

mnCnstrRHS(case2dt(ca,dt),MnodeCstr,CstrRHS) $ ovrd_MnodeCnstrRHS_CaseID(ca,MnodeCstr,CstrRHS)     =  ovrd_MnodeCnstrRHS_CaseID(ca,MnodeCstr,CstrRHS) ;

mnCnstrRHS(case2dt(ca,dt),MnodeCstr,CstrRHS) $ { mnCnstrRHS(ca,dt,MnodeCstr,CstrRHS) = EPS } = 0 ;

*=========================================================================================================================
* Market node constraint RHS overrides end
*=========================================================================================================================



*=========================================================================================================================
* 11. Market node constraint factor overrides
*=========================================================================================================================
Sets
  resCx / set.resC, "NA" /
  resTx / set.resT, "NA" /
;

Parameters
  ovrd_MnodeCnstrfactor_Alltime(alll,MnodeCstr,o,resCx,resTx)      'Override for market node constraint factor applied all the time'
  ovrd_MnodeCnstrfactor_Period(tp,MnodeCstr,o,resCx,resTx)         'Override for market node constraint factor applied to a trading period'
  ovrd_MnodeCnstrfactor_DateTime(dt,MnodeCstr,o,resCx,resTx)       'Override for market node constraint factor applied to an interval'
  ovrd_MnodeCnstrfactor_CaseID(ca,MnodeCstr,o,resCx,resTx)         'Override for market node constraint factor applied to a caseID'
;

*Loading data from gdx file
$onEps
$gdxin "%ovrdPath%%vSPDinputOvrdData%.gdx"
$load ovrd_MnodeCnstrfactor_Alltime  = marketnode_cnstr_factor_overrides
$load ovrd_MnodeCnstrfactor_Period   = marketnode_cnstr_factor_overrides
$load ovrd_MnodeCnstrfactor_DateTime = marketnode_cnstr_factor_overrides
$load ovrd_MnodeCnstrfactor_CaseID   = marketnode_cnstr_factor_overrides
$gdxin
$offEps


mnCstrEnrgFactors(case2dt(ca,dt),MnodeCstr,o) $ ovrd_MnodeCnstrfactor_Alltime('All',MnodeCstr,o,"NA","NA") = ovrd_MnodeCnstrfactor_Alltime('All',MnodeCstr,o,"NA","NA") ;

mnCstrEnrgFactors(case2dt(ca,dt),MnodeCstr,o) $ sum[ case2dt2tp(ca,dt,tp), ovrd_MnodeCnstrfactor_Period(tp,MnodeCstr,o,"NA","NA")] = sum[ case2dt2tp(ca,dt,tp), ovrd_MnodeCnstrfactor_Period(tp,MnodeCstr,o,"NA","NA")] ;

mnCstrEnrgFactors(case2dt(ca,dt),MnodeCstr,o) $ ovrd_MnodeCnstrfactor_DateTime(dt,MnodeCstr,o,"NA","NA")   = ovrd_MnodeCnstrfactor_DateTime(dt,MnodeCstr,o,"NA","NA") ;

mnCstrEnrgFactors(case2dt(ca,dt),MnodeCstr,o) $ ovrd_MnodeCnstrfactor_CaseID(ca,MnodeCstr,o,"NA","NA")     =  ovrd_MnodeCnstrfactor_CaseID(ca,MnodeCstr,o,"NA","NA") ;

mnCstrEnrgFactors(case2dt(ca,dt),MnodeCstr,o) $ { mnCstrEnrgFactors(ca,dt,MnodeCstr,o) = EPS } = 0 ;


mnCnstrResrvFactors(case2dt(ca,dt),MnodeCstr,o,resC,resT)
    $ sum[ (resCx,resTx) $ { sameas(resCx,resC) and sameas(resTx,resT) }, ovrd_MnodeCnstrfactor_Alltime('All',MnodeCstr,o,resCx,resTx) ]
    = sum[ (resCx,resTx) $ { sameas(resCx,resC) and sameas(resTx,resT) }, ovrd_MnodeCnstrfactor_Alltime('All',MnodeCstr,o,resCx,resTx) ] ;

mnCnstrResrvFactors(case2dt(ca,dt),MnodeCstr,o,resC,resT)
    $ sum[ (case2dt2tp(ca,dt,tp),resCx,resTx) $ { sameas(resCx,resC) and sameas(resTx,resT) }, ovrd_MnodeCnstrfactor_Period(tp,MnodeCstr,o,resCx,resTx) ]
    = sum[ (case2dt2tp(ca,dt,tp),resCx,resTx) $ { sameas(resCx,resC) and sameas(resTx,resT) }, ovrd_MnodeCnstrfactor_Period(tp,MnodeCstr,o,resCx,resTx) ] ;

mnCnstrResrvFactors(case2dt(ca,dt),MnodeCstr,o,resC,resT)
    $ sum[ (resCx,resTx) $ { sameas(resCx,resC) and sameas(resTx,resT) }, ovrd_MnodeCnstrfactor_DateTime(dt,MnodeCstr,o,resCx,resTx) ]
    = sum[ (resCx,resTx) $ { sameas(resCx,resC) and sameas(resTx,resT) }, ovrd_MnodeCnstrfactor_DateTime(dt,MnodeCstr,o,resCx,resTx) ] ;

mnCnstrResrvFactors(case2dt(ca,dt),MnodeCstr,o,resC,resT)
    $ sum[ (resCx,resTx) $ { sameas(resCx,resC) and sameas(resTx,resT) }, ovrd_MnodeCnstrfactor_CaseID(ca,MnodeCstr,o,resCx,resTx) ]
    = sum[ (resCx,resTx) $ { sameas(resCx,resC) and sameas(resTx,resT) }, ovrd_MnodeCnstrfactor_CaseID(ca,MnodeCstr,o,resCx,resTx) ] ;

mnCnstrResrvFactors(case2dt(ca,dt),MnodeCstr,o,resC,resT) $ { mnCnstrResrvFactors(ca,dt,MnodeCstr,o,resC,resT) = EPS } = 0 ;

*=========================================================================================================================
* Market node constraint factor overrides end
*=========================================================================================================================

* End of file
