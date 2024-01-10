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

The suffix _overrides inidcates that the symbol contains data to override
the original input data.

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


Parameters
  demand_overrides(*,*,*,*)                       'Demand overrides'
  offer_parameter_overrides(*,*,*)                'Offer parameter overrides'
  energy_offer_overrides(*,*,*,*)                 'Energy offer overrides'
  reserve_offer_overrides(*,*,*,*,*,*)            'Reserve offer overrides'
  bid_parameter_overrides(*,*,*)                  'Energy bid parameter overrides'
  energy_bid_overrides(*,*,*,*)                   'Energy bid overrides'
  branch_parameter_overrides(*,*,*)               'Branch parameter overrides'
  branch_constraint_overrides(*,*,*)              'Branch group constraint sense and-or limit overrdies'
  branch_cnstr_factor_overrides(*,*,*)            'Branch group constraint branch factor overrdies'
  marketnode_constraint_overrides(*,*,*)          'Market node constraint sense and-or limit overrdies'
  marketnode_cnstr_factor_overrides(*,*,*,*,*)    'Market node constraint factor overrdies''
;

$onEps
$gdxin "Override/vSPD_Overrides.gdx"
$load demand_overrides  bid_parameter_overrides  energy_bid_overrides
$load offer_parameter_overrides  energy_offer_overrides  reserve_offer_overrides
$load branch_parameter_overrides  branch_constraint_overrides  branch_cnstr_factor_overrides
$load marketnode_constraint_overrides  marketnode_cnstr_factor_overrides
$gdxin
$offEps

$onEmbeddedCode Python:
import pandas as pd
import numpy as np
import random

#_______________________________________________________________________________________________________________
# The loading and cleasing fucntions
#_______________________________________________________________________________________________________________

def load_cleans_overrides(gams, parameter):
    # Retrieve the GAMS dataset associated with the specified parameter
    my_dataset = gams.get(parameter)
    
    # Convert the GAMS dataset to a Pandas DataFrame
    my_dataset_pd = pd.DataFrame(my_dataset)
    
    # Check if the DataFrame is empty
    if my_dataset_pd.empty:
        return my_dataset_pd
    else:
        # Extract the values from the first column of the DataFrame
        my_dataset_l = list(my_dataset_pd.iloc[:, 0])
        
        # Create a new DataFrame from the list of values
        my_dataset_2 = pd.DataFrame(my_dataset_l)
        
        # Concatenate the new DataFrame with the second column of the original DataFrame
        my_dataset_3 = pd.concat([my_dataset_2, my_dataset_pd.iloc[:, 1]], axis=1)
        
        # Return the resulting DataFrame
        return my_dataset_3
        

def load_and_cleans(gams, raw_dataset):
    # Retrieve the GAMS dataset associated with the specified raw_dataset
    my_dataset = gams.get(raw_dataset)
    
    # Convert the GAMS dataset to a Pandas DataFrame
    my_dataset_pd = pd.DataFrame(my_dataset)
    
    # Extract the values from the first column of the DataFrame and convert them to a list
    my_dataset_l = list(my_dataset_pd.iloc[:, 0])
    
    # Create a new DataFrame from the list of values
    my_dataset_2 = pd.DataFrame(my_dataset_l)
    
    # Concatenate the new DataFrame with the second column of the original DataFrame
    my_dataset_3 = pd.concat([my_dataset_2, my_dataset_pd.iloc[:, 1]], axis=1)
    
    # Check if the resulting DataFrame has 5 columns
    if my_dataset_3.shape[1] == 5:
        # If it has 5 columns, assign new column names
        new_columns_pa = ['CaseID', 'Datetime', 'node', 'Parameters', 'Data']
        my_dataset_3.columns = new_columns_pa
    
    # Return the resulting DataFrame
    return my_dataset_3
    
#_______________________________________________________________________________________________________________
# Loading and cleasing the overrides as well as data
#_______________________________________________________________________________________________________________

bidparameteroverrides_dst          = load_cleans_overrides(gams,'bid_parameter_overrides')
offerparameteroverrides_dst        = load_cleans_overrides(gams,'offer_parameter_overrides')
energyofferoverrides_dst           = load_cleans_overrides(gams,'energy_offer_overrides')
reserveofferoverrides_dst          = load_cleans_overrides(gams,'reserve_offer_overrides')
energybidoverrides_dst             = load_cleans_overrides(gams,'energy_bid_overrides')
branchparameteroverrides_dst       = load_cleans_overrides(gams,'branch_parameter_overrides')
branchconstraintoverrides_dst      = load_cleans_overrides(gams,'branch_constraint_overrides')
branchcnstrfactoroverrides_dst     = load_cleans_overrides(gams,'branch_cnstr_factor_overrides')
marketnodeconstraintoverrides_dst  = load_cleans_overrides(gams,'marketnode_constraint_overrides')
marketnodecnstrfactoroverrides_dst = load_cleans_overrides(gams,'marketnode_cnstr_factor_overrides')

MncnstrEnrgFactor     = load_and_cleans(gams, 'MNCnstrEnrgFactor')
MncnstrResrvFactor    = load_and_cleans(gams, 'MncnstrResrvFactor')
mncnstrRHS            = load_and_cleans(gams, 'MNCnstrRHS')
branchCstrFactors     = load_and_cleans(gams, 'branchCstrFactors')
branchCstrRHS         = load_and_cleans(gams, 'branchCstrRHS')
offerParameter        = load_and_cleans(gams, 'offerParameter')
branchParameter       = load_and_cleans(gams, 'branchParameter')
bidParameter          = load_and_cleans(gams, 'bidParameter')
energyBid             = load_and_cleans(gams, 'energyBid')
energyOffer           = load_and_cleans(gams, 'energyOffer')
reserveOffer          = load_and_cleans(gams, 'reserveOffer')


#_______________________________________________________________________________________________________________
# Loading and cleasing other parameters
#(There are other parameters which are needed for the process of overriding like list of all nodes or all caseIDs
#they are loaded, prepared and manipulated in this section)
#_______________________________________________________________________________________________________________

case2dt2tp  = pd.DataFrame(gams.get('case2dt2tp'))
case2dt     = case2dt2tp.iloc[:, :2]
dt2tp       = case2dt2tp.iloc[:, 1:]    
dt2tp.drop_duplicates(subset=dt2tp.columns[0], inplace = True)

node_bus    = pd.DataFrame(gams.get('nodeBus'))
node_bus.drop_duplicates(subset=node_bus.columns[2], inplace = True)
node_bus    = node_bus.iloc[:,2:]
node_bus.columns = ['node', 'bus']

bus_island  = pd.DataFrame(gams.get('busIsland'))
bus_island.drop_duplicates(subset=bus_island.columns[2], inplace = True)
bus_island  = bus_island.iloc[:,2:]
bus_island.columns = ['bus', 'island']

node_island = node_bus.merge(bus_island, on ='bus', how='left')
node_island.drop('bus', axis = 1, inplace = True)

node_list   = list(gams.get('n'))

#_______________________________________________________________________________________________________________
# Sorting overrides except for demand
#_______________________________________________________________________________________________________________

def sort_parameter_ovr(override_dst):
    # Check if the DataFrame override_dst is empty
    if override_dst.empty:
        # If it is empty, return the original empty DataFrame
        return override_dst
    else:
        # Create a new column 'Time' based on conditions applied to the first column of override_dst
        override_dst['Time'] = override_dst.iloc[:,0].apply(
        lambda column: (
            4 if column == "All" else
            3 if str(column).startswith('TP') else
            1 if "-" not in column else
            2))
            
        # Sort the DataFrame by the 'Time' column in descending order
        override_dst.sort_values(by=['Time'], ascending=[False], inplace=True)
        
        # Drop the 'Time' column from the DataFrame
        override_dst.drop(columns=['Time'], inplace=True)
        
        # Return the modified DataFrame
        return override_dst

#_______________________________________________________________________________________________________________
# Preparing information for each node, datetime and timeperiod
#_______________________________________________________________________________________________________________

def get_island_nodes(island):
    loc_nod = {
        'NI' : node_island.iloc[:, 0][node_island.iloc[:,1] == 'NI'].tolist(),
        'SI' : node_island.iloc[:, 0][node_island.iloc[:,1] == 'SI'].tolist()
    }
    return loc_nod.get(island)

def get_period_datetime(tp_code):
    output_tp = dt2tp.iloc[:, 0][dt2tp.iloc[:, 1] == tp_code].tolist()
    return output_tp

time_period_dict = dict(zip(dt2tp.iloc[:, 0], dt2tp.iloc[:, 1]))
def tp_of_datetime(datetime):
    return time_period_dict.get(datetime, None)


#_______________________________________________________________________________________________________________
# Sorting demand overrides
#_______________________________________________________________________________________________________________

class DataFrameSorter:

    def __init__(self, dataframe):
        self.dataframe = dataframe
        self.sorted_dataframe = dataframe.copy()

    def sort_when(self):
        self.sorted_dataframe['Priority_when'] = self.dataframe['When'].apply(
            lambda column: (
                4 if column == "All" else
                3 if str(column).startswith('TP') else
                1 if "-" not in column else
                2
            )
        )

    def sort_where(self):
        self.sorted_dataframe['Priority_where'] = self.dataframe['Where'].apply(
            lambda column: (
                4 if column == "All" else
                3 if len(str(column)) == 2 else
                2 if len(str(column)) == 7 else
                1
            )
        )

    def sort_how(self):
        self.sorted_dataframe['Priority_how'] = self.dataframe['How'].apply(
            lambda column: (
                4 if column == "scale" else
                3 if column == "increment" else
                2 if column == "value" else
                1
            )
        )

    def sort_Load_Type(self):
        self.sorted_dataframe['Priority_Load_Type'] = self.dataframe['Load_Type'].apply(
            lambda column: (
                3 if column == "All" else
                2 if column == "Nonconform" else
                1

            )
        )

    def sort_dataframe(self):
        self.sort_when()
        self.sort_where()
        self.sort_how()
        self.sort_Load_Type()
        self.sorted_dataframe.sort_values(
            by=['Priority_when', 'Priority_where', 'Priority_how', 'Priority_Load_Type' ],
            ascending=[False, False, False, False],
            inplace=True
        )
        self.sorted_dataframe.drop(
            columns=['Priority_when', 'Priority_where', 'Priority_how', 'Priority_Load_Type'],
            inplace=True
        )

    def display_sorted_dataframe(self):
        self.sort_dataframe()
        display(self.sorted_dataframe)


#_______________________________________________________________________________________________________________
# Demand override preparations
#_______________________________________________________________________________________________________________

no_demand_override = {
    'When' : ['All'],
    'Where': ['All'],
    'Load_Type' : ['All'],
    'How': ['scale'],
    'value' : ['1']
}

demand_overrides = pd.DataFrame(gams.get('demand_overrides'))
if demand_overrides.empty:
    dataset_rules3 = pd.DataFrame(no_demand_override)
else:
    dataset_rules1 = list(demand_overrides.iloc[:,0])
    dataset_rules2 = pd.DataFrame(dataset_rules1)
    dataset_rules3 = pd.concat([dataset_rules2,demand_overrides.iloc[:,1]], axis=1)
    
gdx2 = dataset_rules3.copy()
gdx2.columns = ['When', 'Where', 'Load_Type', 'How', 'value']
gdx1 = DataFrameSorter(gdx2)
gdx1.sort_dataframe()
gdx = gdx1.sorted_dataframe

#_______________________________________________________________________________________________________________
# Demand data preparations
#_______________________________________________________________________________________________________________

nodeparameter = gams.get("nodeParameter")

dataset_p   = pd.DataFrame(nodeparameter)
dataset_p_l = list(dataset_p.iloc[:,0])
dataset_p_2 =  pd.DataFrame(dataset_p_l)
dataset_p_3 =  pd.concat([dataset_p_2,dataset_p.iloc[:,1]], axis=1)
dataset_p_3.columns = ['CaseID', 'Datetime', 'node', 'Parameters', 'Data']
dataset = dataset_p_3.copy()

# Get non-conforming load flag for each demand nods
ncl_nodes = dataset.iloc[:, 0:3][dataset['Parameters'] == 'loadIsNCL']
demand_ncl = dataset[(dataset['CaseID'].isin(ncl_nodes['CaseID'])) & (dataset['Datetime'].isin(ncl_nodes['Datetime'])) & (dataset['node'].isin(ncl_nodes['node']))]
demand_ncl = demand_ncl[demand_ncl['Parameters'] == 'demand']
ncl_index  = demand_ncl.index.values
second_last_col = len(dataset.columns) - 1
dataset.insert(loc=second_last_col, column='loadNCL', value='non')
dataset.loc[ncl_index, 'loadNCL'] = 1
dataset.loc[~dataset.index.isin(ncl_index), 'loadNCL'] = 0

demand_df1 = dataset.copy()
demand = demand_df1

set_of_nodes = dataset['node'].unique()
for g in range(gdx.shape[0]):
    if (len(gdx.iat[g,1]) == 7) and (gdx.iat[g,1] in node_list) and (gdx.iat[g,1] not in set_of_nodes):
        demand_node_refrence = demand_df1.iat[0,2]
        demand_added_node = demand_df1[(demand_df1['node'] == demand_node_refrence) ]
        demand_added_node['Data'][demand_added_node['Parameters'] == 'demand'] = 0
        demand_added_node['node'] = gdx.iat[g,1]
        demand = pd.concat([demand_df1, demand_added_node], axis = 0,  ignore_index=True)
    else:
        demand_added_node = pd.DataFrame()
        
demand_df = demand.copy()

#_to be continued______________________________________________________________________________________________________________
# filtering demand data and preparaton for applying override
#_______________________________________________________________________________________________________________


def filter_function_com_f(when_p, where_p, how_p, demand, get_period_datetime, get_island_nodes):
    if len(where_p) == 7:
      demand = demand[demand['Parameters'] == 'demand']
    else:
       demand = demand[demand['Parameters'] == 'demand']
       #demand = demand[demand['Data'] > 0]
    if when_p == 'All':
        pass
    elif when_p.startswith('TP'):
        tp_value =  get_period_datetime(when_p)
        if tp_value is None:
            raise ValueError(f'TP code "{when_p}" not found in get_period_datetime')
        demand = demand[demand['Datetime'].isin(tp_value)]
    elif "-" in when_p:
        demand = demand[demand['Datetime'] == when_p]
    else:
        demand = demand[demand['CaseID'] == when_p]



    # Filter demand based on the specified where_p condition
    if where_p == 'All':
        pass
    elif len(where_p) == 2:
        location = get_island_nodes(where_p)
        if location is None:
            raise ValueError(f'Location code "{where_p}" not found in get_island_nodes')
        demand = demand[demand['node'].isin(location)]
    else:
        demand = demand[demand['node'] == where_p]


    # Filter demand based on the specified how_p condition
    if how_p == 'All':
        pass
    elif how_p.lower() == 'nonconform':
        demand = demand[demand['loadNCL'] == 1]
    elif how_p.lower() == 'conforming':
        demand = demand[demand['loadNCL'] == 0]
    else:
         raise ValueError(f'Invalid how_p value "{how_p}"')

    #Return the indices of the remaining rows
    return demand.index.tolist()

#_______________________________________________________________________________________________________________
# Applying 'value' to demand data
#_______________________________________________________________________________________________________________

def apply_value2(demand,where,constant_value):
    if len(where) == 7:
        demand['Data'] = float(constant_value)
    else:
        demand_pos = demand[demand['Data'] > 0]
        demand_neg = demand[demand['Data'] < 0]
        dt_demand_pos = demand_pos.groupby(['CaseID', 'Datetime'])['Data'].sum()
        dt_demand_neg = demand_neg.groupby(['CaseID', 'Datetime'])['Data'].sum()
        demand = demand.merge(dt_demand_pos, on=['CaseID'])
        demand = demand.merge(dt_demand_neg, on=['CaseID'], how='outer')
        demand.rename(columns={'Data': 'Data_z' }, inplace=True)
        demand.rename(columns={'Data_x': 'Data' }, inplace=True)
        demand.fillna(value=0, inplace=True)
        demand['Data_w'] = constant_value
        demand.loc[:,'Data_w'] +=  demand.loc[:,'Data_z'].abs()
        demand['Data'] = demand.apply(lambda row: (row['Data']/row['Data_y'])*row['Data_w'] if row['Data'] > 0 else row['Data'], axis=1)
        demand.drop(['Data_y','Data_z', 'Data_w' ], axis=1, inplace=True)
    return demand

#_______________________________________________________________________________________________________________
# Applying 'Increment' to demand data
#_______________________________________________________________________________________________________________

def apply_increment6(demand, where ,increment_value):
    if len(where) == 7:
        demand['Data'] += float(increment_value)
    else:
        demand_pos = demand[demand['Data'] > 0]
        demand_neg = demand[demand['Data'] < 0]
        dt_demand = demand.groupby(['CaseID', 'Datetime'])['Data'].sum()
        dt_demand_pos = demand_pos.groupby(['CaseID', 'Datetime'])['Data'].sum()
        dt_demand_neg = demand_neg.groupby(['CaseID', 'Datetime'])['Data'].sum()
        demand = demand.merge(dt_demand_pos, on=['CaseID'])
        demand = demand.merge(dt_demand_neg, on=['CaseID'], how='outer')
        demand.rename(columns={'Data': 'Data_z' }, inplace=True)
        demand.rename(columns={'Data_x': 'Data' }, inplace=True)
        demand.fillna(value=0, inplace=True)
        demand['Data_w'] = increment_value
        demand['Data'] = demand.apply(lambda row: row['Data'] + (row['Data']/row['Data_y'])*row['Data_w'] if row['Data'] > 0 else row['Data'], axis=1)
        demand.drop(['Data_y','Data_z', 'Data_w' ], axis=1, inplace=True)

    return demand

#_______________________________________________________________________________________________________________
# Applying 'Scale' to demand data
#_______________________________________________________________________________________________________________

def apply_scale(demand, where, scale_value):
    if len(where) == 7:
        demand['Data'] *= float(scale_value)
    else:
        demand_pos_index = demand[demand['Data'] > 0].index
        demand.loc[demand_pos_index, 'Data'] *=  float(scale_value)
    return demand

#_______________________________________________________________________________________________________________
# Applying overrides to demand data
#_______________________________________________________________________________________________________________

def apply_overide(gdx, demand):
    if gdx.empty:
        return demand
    for i in range (gdx.shape[0]):
        filter_info = tuple((gdx.iat[i, 0], gdx.iat[i, 1], gdx.iat[i, 2], demand, get_period_datetime,  get_island_nodes ))
        result = filter_function_com_f(*filter_info)
        if gdx.iat[i, 3].lower()  == 'scale':
            demand.iloc[result, :] = apply_scale(demand_df.iloc[result, :], gdx.iat[i, 1], gdx.iat[i, -1])
            result = []
        elif gdx.iat[i, 3].lower()  == 'value':
            demand.iloc[result, :] =  apply_value2(demand_df.iloc[result, :],gdx.iat[i, 1] ,gdx.iat[i, -1])
            result = []
        elif gdx.iat[i, 3].lower()  == 'increment':
            demand.iloc[result, :] =  apply_increment6(demand_df.iloc[result, :], gdx.iat[i, 1] ,gdx.iat[i, -1])

    return demand
#_______________________________________________________________________________________________________________
# Applying overrides to other parameters
#_______________________________________________________________________________________________________________

def apply_overide_parameters(parameter, rules):
    if rules.empty:
       return parameter
    else:
        for index, row in rules.iterrows():
              parameter1 = parameter.copy()
              time_origin = case2dt.copy()
              constant = row.iloc[-1]
              if row.iloc[0] == 'All':
                pass
              elif row.iloc[0].startswith('TP'):
                tp_value_fourcolumns =  get_period_datetime(row.iloc[0])
                parameter1 = parameter1[parameter1.iloc[:, 1].isin(tp_value_fourcolumns)]
                time_origin = time_origin[time_origin.iloc[:, 1].isin(tp_value_fourcolumns)]
              elif "-" in row.iloc[0]:
                parameter1 = parameter1[parameter1.iloc[:, 1] == row.iloc[0]]
                time_origin = time_origin[time_origin.iloc[:, 1] == row.iloc[0]]
              else:
                parameter1 = parameter1[parameter1.iloc[:, 0] == row.iloc[0]]
                time_origin = time_origin[time_origin.iloc[:, 0] == row.iloc[0]]
              for i in range(2,(parameter1.shape[1])):
                  col_name_origin = '{}'.format(i)
                  time_origin.insert(loc=i, column=col_name_origin, value='0')
              if rules.shape[1] == 4:
                parameter1 = parameter1[parameter1.iloc[:, 2] == row.iloc[1]]
                parameter1 = parameter1[parameter1.iloc[:, 3] == row.iloc[2]]
                time_origin.iloc[:, 2] = row.iloc[1]
                time_origin.iloc[:, 3] = row.iloc[2]
              if rules.shape[1] == 5:
                parameter1 = parameter1[parameter1.iloc[:, 2] == row.iloc[1]]
                parameter1 = parameter1[parameter1.iloc[:, 3] == row.iloc[3]]
                parameter1 = parameter1[parameter1.iloc[:, 4] == row.iloc[2]]
                time_origin.iloc[:, 2] = row.iloc[1]
                time_origin.iloc[:, 3] = row.iloc[3]
                time_origin.iloc[:, 4] = row.iloc[2]
              if rules.shape[1] == 6:
                parameter1 = parameter1[parameter1.iloc[:, 2] == row.iloc[1]]
                parameter1 = parameter1[parameter1.iloc[:, 3] == row.iloc[2]]
                parameter1 = parameter1[parameter1.iloc[:, 4] == row.iloc[3]]
                parameter1 = parameter1[parameter1.iloc[:, 5] == row.iloc[4]]
                time_origin.iloc[:, 2] = row.iloc[1]
                time_origin.iloc[:, 3] = row.iloc[2]
                time_origin.iloc[:, 4] = row.iloc[3]
                time_origin.iloc[:, 5] = row.iloc[4]
              if rules.shape[1] == 7:
                parameter1 = parameter1[parameter1.iloc[:, 2] == row.iloc[1]]
                parameter1 = parameter1[parameter1.iloc[:, 3] == row.iloc[2]]
                parameter1 = parameter1[parameter1.iloc[:, 4] == row.iloc[3]]
                parameter1 = parameter1[parameter1.iloc[:, 5] == row.iloc[5]]
                parameter1 = parameter1[parameter1.iloc[:, 6] == row.iloc[4]]
                time_origin.iloc[:, 2] = row.iloc[1]
                time_origin.iloc[:, 3] = row.iloc[2]
                time_origin.iloc[:, 4] = row.iloc[3]
                time_origin.iloc[:, 5] = row.iloc[5]
                time_origin.iloc[:, 6] = row.iloc[4]
              index_parameter = parameter1.index.tolist()
              if (parameter1.shape[0] <= time_origin.shape[0]):
                 parameter_appand = time_origin.copy()
                 parameter_appand.iloc[:, -1] = constant
                 parameter.drop(index = index_parameter, inplace = True)
                 parameter_appand.columns = parameter.columns
                 parameter = pd.concat([parameter, parameter_appand ], ignore_index=True )
              else:
                 parameter.iloc[index_parameter, -1] = constant
        return parameter
#_______________________________________________________________________________________________________________
# Triggers to apply overrides
#_______________________________________________________________________________________________________________

CstrEnrgFct_ovrd = marketnodecnstrfactoroverrides_dst[(marketnodecnstrfactoroverrides_dst.iloc[:,3] == 'NA') & (marketnodecnstrfactoroverrides_dst.iloc[:,4] == 'NA')]
CstrReserveFct_ovrd = marketnodecnstrfactoroverrides_dst[(marketnodecnstrfactoroverrides_dst.iloc[:,3] != 'NA') & (marketnodecnstrfactoroverrides_dst.iloc[:,4] != 'NA')]
columns_to_remove = CstrEnrgFct_ovrd.iloc[:,3:5].columns.ravel()
CstrEnrgFct_ovrd_F = CstrEnrgFct_ovrd.drop(columns_to_remove,axis=1)

mncnstrEnrgFactor_overided = apply_overide_parameters(MncnstrEnrgFactor,sort_parameter_ovr(CstrEnrgFct_ovrd_F))
mncnstrResrvFactor_overided =  apply_overide_parameters(MncnstrResrvFactor,sort_parameter_ovr(CstrReserveFct_ovrd))
mncnstrRHS_overided = apply_overide_parameters(mncnstrRHS,sort_parameter_ovr(marketnodeconstraintoverrides_dst))
datetimeBranchConstraintFactors_overided = apply_overide_parameters(datetimeBranchConstraintFactors,sort_parameter_ovr(branchcnstrfactoroverrides_dst))
datetimeBranchConstraintRHS_overided = apply_overide_parameters(datetimeBranchConstraintRHS,sort_parameter_ovr(branchconstraintoverrides_dst))
datetimeOfferParameter_overided = apply_overide_parameters(datetimeOfferParameter,sort_parameter_ovr(offerparameteroverrides_dst))
datetimeBranchParameter_overided = apply_overide_parameters(datetimeBranchParameter,sort_parameter_ovr(branchparameteroverrides_dst))
datetimeBidParameter_overided = apply_overide_parameters(datetimeBidParameter,sort_parameter_ovr(bidparameteroverrides_dst))
datetimeEnergyBid_overided = apply_overide_parameters(datetimeEnergyBid,sort_parameter_ovr(energybidoverrides_dst))
datetimeEnergyOffer_overided = apply_overide_parameters(datetimeEnergyOffer,sort_parameter_ovr(energyofferoverrides_dst))
datetimeReserveOffer_overided = apply_overide_parameters(datetimeReserveOffer,sort_parameter_ovr(reserveofferoverrides_dst))
demand_overided = apply_overide(gdx, demand)

#_______________________________________________________________________________________________________________
# Preparation of all parameter to upload to GAMS
#_______________________________________________________________________________________________________________

mncnstrResrvFactor_overided.name = 'mncnstrResrvFactor_overided'
mncnstrEnrgFactor_overided.name = 'mncnstrEnrgFactor_overided'
mncnstrRHS_overided.name = 'mncnstrRHS_overided'
datetimeBranchConstraintFactors_overided.name = 'datetimeBranchConstraintFactors_overided'
datetimeBranchConstraintRHS_overided.name = 'datetimeBranchConstraintRHS_overided'
datetimeOfferParameter_overided.name = 'datetimeOfferParameter_overided'
datetimeBranchParameter_overided.name = 'datetimeBranchParameter_overided'
datetimeBidParameter_overided.name = 'datetimeBidParameter_overided'
datetimeEnergyBid_overided.name = 'datetimeEnergyBid_overided'
datetimeEnergyOffer_overided.name = 'datetimeEnergyOffer_overided'
datetimeReserveOffer_overided.name = 'datetimeReserveOffer_overided'
demand_overided.name = 'demand_overided'
demand_overided.drop(['loadNCL'], axis=1, inplace = True)

gams_parameters_list = [ mncnstrRHS_overided, datetimeBranchConstraintFactors_overided,datetimeBranchConstraintRHS_overided,datetimeOfferParameter_overided,
  datetimeBranchParameter_overided,datetimeBidParameter_overided, datetimeEnergyBid_overided, datetimeEnergyOffer_overided, demand_overided, datetimeReserveOffer_overided, mncnstrEnrgFactor_overided, mncnstrResrvFactor_overided]
#506
for item in gams_parameters_list:
    gams_param = {}
    for index, row in item.iterrows():
        if item.shape[1] == 5:
            key_tuple = (row['CaseID'], row['Datetime'], row['node'], row['Parameters'])
            value_tuple = (row['Data'],)
        elif item.shape[1] == 6:
            key_tuple = (row.iloc[0], row.iloc[1], row.iloc[2], row.iloc[3], row.iloc[4])
            value_tuple = (row.iloc[5],)
        elif item.shape[1] == 7:
            key_tuple = (row.iloc[0], row.iloc[1], row.iloc[2], row.iloc[3], row.iloc[4], row.iloc[5] )
            value_tuple = (row.iloc[6],)
        elif item.shape[1] == 8:
            key_tuple = (row.iloc[0], row.iloc[1], row.iloc[2], row.iloc[3], row.iloc[4], row.iloc[5], row.iloc[6])
            value_tuple = (row.iloc[-1],)
        gams_param.setdefault(str(item.name), []).append((key_tuple, value_tuple))
    gams.set(str(item.name), gams_param[str(item.name)])
    
$offEmbeddedCode demand_overided datetimeReserveOffer_overided datetimeEnergyOffer_overided energyBid_overided  mncnstrRHS_overided datetimeBranchConstraintFactors_overided branchCstrRHS_overided offerParameter_overided branchParameter_overided bidParameter_overided mncnstrEnrgFactor_overided mncnstrResrvFactor_overided


* End of file
