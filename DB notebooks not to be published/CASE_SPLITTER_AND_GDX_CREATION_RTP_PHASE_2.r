# Databricks notebook source
# MAGIC %md ##Note:
# MAGIC ##### This notebook is applied for RTP Phase 2. This has been tested using test cases and passed.
# MAGIC ##### This notebook extract the MSS casefile data to CSV files if and only if the msscasepath is **"casefiles/landed"**
# MAGIC ##### This notebook create gdx file for MSS casefiles that are in casetype folder only such as  **"casefiles/processed/FP", "casefiles/processed/RTP", ect...**

# COMMAND ----------

# DBTITLE 1,Initialise widgets/parameters
dbutils.widgets.removeAll()
dbutils.widgets.text(name="msscasepath",defaultValue="None",label="msscasepath")
dbutils.widgets.text(name="msscasename",defaultValue="None",label="msscasename")
dbutils.widgets.text(name="FPExportPath",defaultValue="None",label="FPExportPath")

# COMMAND ----------

# MAGIC %md #Setting DBFS connectivity, temporary folders and loading R libraries

# COMMAND ----------

# DBTITLE 1,Get mounted storage containers and create temporary folders
Testing <- TRUE
if (Testing) {
  emi_publicdata_mp <- '/mnt/emidatasetsdev/publicdata'
  csv_mp            <- '/mnt/madatasourcesadev/casefiles/csv'
  raw_mp            <- '/mnt/madatasourcesadev/casefiles'  
  vspd_mp           <- '/mnt/madatasourcesadev/vspd'
} else {
  emi_publicdata_mp <- '/mnt/emidatasets/publicdata'          # Location to publish GDX and MSS case files
  csv_mp            <- '/mnt/madatasourcesaprd/casefiles/csv' # Location to store split CSV files
  raw_mp            <- '/mnt/madatasourcesaprd/casefiles'     # Location to read MSS case file
  vspd_mp           <- '/mnt/madatasourcesaprd/vspd'          # Location to store vSPD data
}


# Note: I have tried to read/write data directly from and to mounted container but it is faster to copy files into local dbfs to read/write and copy back to mounted container when it is done
if (!dir.exists('MSS')) dir.create('MSS')
if (!dir.exists('GDX')) dir.create('GDX')
if (!dir.exists('CSV')) dir.create('CSV')

# COMMAND ----------

# DBTITLE 1,Load required libraries
library(dplyr)
library(tidyr)
library(lubridate)
library(readr)
library(stringr)
library('data.table')

# COMMAND ----------

# MAGIC %run /Users/tuong.nguyen@ea.govt.nz/EA_Common_Functions/EA_Common_R_Functions

# COMMAND ----------

# MAGIC %sql
# MAGIC SET TIME ZONE 'Etc/UTC';

# COMMAND ----------

# MAGIC %md #Functions and procedures to list and check mss zip files to be processed.

# COMMAND ----------

# DBTITLE 1,Get list unprocessed/triggered blob case files
mssfoldername <- gsub(x = dbutils.widgets.get('msscasepath'), pattern = 'casefiles/',replacement = '')
msscasepath <- paste0('/dbfs',raw_mp,'/',mssfoldername,'/',dbutils.widgets.get('msscasename'))

if (file.exists(msscasepath) & !(file.info(msscasepath)$isdir)) { # if the MSS case file exists, read file info into a dataframe
  path <- gsub(x=msscasepath, pattern='/dbfs', replacement='dbfs:')
  name <- basename(msscasepath)
  size <- file.info(msscasepath)$size
  caseid <- toupper(name) %>% str_remove(pattern='MSS_') %>% str_remove(pattern='_0X.ZIP')
  casetype <- get_case_type(caseid)
  df <- data.frame(CaseID=caseid, CaseType = casetype, path=path, name=name, size = size, stringsAsFactors=F)
  
} else if (mssfoldername=='landed' | T)  { # if the MSS case file does not exist and mss case folder is "casefiles/landed" --> list all existing case files in "casefiles/landed"
  df <- dbutils.fs.ls(dir= paste0('dbfs:',raw_mp,'/',mssfoldername))  
  path <- lapply(X=df, FUN=function(x) { return(x$path) } )
  name <- lapply(X=df, FUN=function(x) { return(x$name) } )
  size <- lapply(X=df, FUN=function(x) { return(x$size) } )
  
  df <- data.frame(path = as.character(path), name = as.character(name), 
                   size = as.numeric(size), stringsAsFactors=F)
  df$CaseID <- sapply(df$name,get_caseID_from_casefilepath)
  df$CaseType <- sapply(df$CaseID, get_case_type)
  
} else { # otherwise, create an empty dataframe
  df <- data.frame(CaseID = character(), CaseType = character(), path = character(), name = character(), size = numeric(), stringsAsFactors=F)
}
df <- df %>% filter(startsWith(x=name,prefix='MSS_')) %>%
    filter((CaseType=='FP' & size >=2000000) | CaseType!='FP') %>% 
    select(CaseID, CaseType, path, name )

df_unprocessedcasefiles <- df
if (nrow(df_unprocessedcasefiles) > 0) display(df_unprocessedcasefiles) else dbutils.notebook.exit("No MSS casefile to process")

# COMMAND ----------

# DBTITLE 1,Load gdxrrw library and API if GDX creation is required
# Load gdxrrw package and GDX API processing files not in "landed" --> GDX creation process is required
if (!(mssfoldername=="landed") & (nrow(df_unprocessedcasefiles) > 0)) {
  # Install gdxrrw package if not exist using package from vspd storage container
  pkgs <- installed.packages() %>% data.frame()
  if (!('gdxrrw' %in% pkgs$Package)) {
    if (str_detect(R.version.string,'R version 3.6.3')) {
      install.packages(pkgs=paste0('/dbfs',vspd_mp,'/packages/R_version_3.6.3/gdxrrw_1.0.5_r_x86_64-redhat-linux-gnu.tar.gz'),repos=NULL,type='source')
      library(gdxrrw)
      igdx(gamsSysDir=paste0('/dbfs',vspd_mp,'/packages/R_version_3.6.3'))
    } else {
      install.packages(pkgs=paste0('/dbfs',vspd_mp,'/packages/R_version_4.0.3/gdxrrw_1.0.8_r_x86_64-redhat-linux-gnu.tar.gz'),repos=NULL,type='source')
      library(gdxrrw)
      igdx(gamsSysDir=paste0('/dbfs',vspd_mp,'/packages/R_version_4.0.3'))
    }
  }
}

# COMMAND ----------

# MAGIC %md #Functions and procedures to split MSS data to CSVs.

# COMMAND ----------

# DBTITLE 1,MSS casefile splitting procedure (only split data for "MSS" case files in MSS folder)
mssfoldername <- gsub(x = dbutils.widgets.get('msscasepath'), pattern = 'casefiles/',replacement = '')
SparkR::sparkR.session()

if ((mssfoldername=="landed") & (nrow(df_unprocessedcasefiles) > 0)) {
  
  for (i in (1:nrow(df_unprocessedcasefiles))) {
    
    path <- df_unprocessedcasefiles$path[i]
    mssFilePath <- gsub(x=path,pattern='dbfs:/',replacement="/dbfs/")
    filename <- df_unprocessedcasefiles$name[i]
    casetype <- df_unprocessedcasefiles$CaseType[i]
    absolutefilename <- gsub(x=raw_mp,pattern="/mnt/",replacement="")
    absolutefilename <- str_split(string=absolutefilename,pattern="/")
    absolutefilename <- paste0('abfss://',absolutefilename[[1]][2],
                               '@',absolutefilename[[1]][1],'.dfs.core.windows.net/',
                               casetype,'/',filename)
    try({
    if (casetype %in% c('WDS')){ # Casetype to be ignored, just read case file info for vspd.spdcase record
      if (file.exists(mssFilePath) & is.zip(mssFilePath)) {
        mssInfoList <- Read_MSS_Info_To_List(mssFilePath)
        spdcase_update_df <- spdcase_update(mssInfoList)
        print(paste0("Case files to move: ", filename ))
        if (file.exists(mssFilePath)) { # Before moving file, check again to make sure the file still exists
          dbutils.fs.mv(from = path, to = paste0('dbfs:',raw_mp,'/processed/',casetype,'/',filename))
          # Record the processed spd case into vspd.spdcase table
          spdcase_update_df$FileName <- absolutefilename
          sqlquery <- spdcase_info_insert_query(spdcase_update_df)
          SparkR::sql(sqlquery)
        } 
      }      
    } else { # Splitting data for all unignored case types
      if (file.exists(mssFilePath) & is.zip(mssFilePath)) {
        # It is faster to copy file to "local" folder to read than read directly from mounted folder
        file.copy(from = mssFilePath, to = 'MSS')
        mssDataList <- Read_MSS_Data_To_Dataframes_List(paste0('MSS/',filename))
        casetype <- as.character(mssDataList$CASETYPE)
        spdcase_update_df <- spdcase_update(mssDataList)
        print(paste0("Case files to split: ", filename ))
        # Splitting data for all case type
        csvDest <- paste0('/dbfs',csv_mp)
        casename <- Write_MSS_dataframe_to_CSV_folder(mssDataList) 
        file.copy(from=paste0('CSV/',casetype),to=csvDest,overwrite=T,recursive=T)
        unlink(x='CSV/*',recursive=T,force=T)        
        
        # Copy MSS casefile to "processed" folder 
        file.copy(from = paste0('MSS/',filename), to = paste0('/dbfs',raw_mp,'/processed/',casetype,'/',filename))
        unlink(paste0('MSS/',filename))
      
        # Record the processed spd case into vspd.spdcase table
        spdcase_update_df$FileName <- absolutefilename
        sqlquery <- spdcase_info_insert_query(spdcase_update_df)
        SparkR::sql(sqlquery)
        
        # Only delete processed file in landing location when every step is sucessful
        unlink(mssFilePath) 
      }
    }
    })
  }
}

# COMMAND ----------

# MAGIC %md #Functions and procedures to create GDX
# MAGIC 
# MAGIC ######Please note that this procedure only create GDX file for MSS casefiles reside in their allocated destination Ex: FP, RTP, RTD, NRSS, NRSL, PRSS and PRSL etc...  

# COMMAND ----------

# DBTITLE 1,Function to create GDX from MSS case file
create_gdx_from_MSS_dataframe <- function(mssDataList, gdxDestination = 'GDX') {
    
    # Read data from MSS data list file to lists of tables
    MDBCTRL <- mssDataList[['MDBCTRL']]
    PERIOD <- mssDataList[['PERIOD']]
    MSSMKT <- mssDataList[['MSSMKT']]
    MSSMOD <- mssDataList[['MSSMOD']]
    DAILY <- mssDataList[['DAILY']]
    MSSNET <- mssDataList[['MSSNET']]
    TOPOLOGY <- mssDataList[['TOPOLOGY']]
    SPDSOLVED <- mssDataList[['SPDSOLVED']]
    
    # Get casename and casetype and caseid to use in later stage
    casename <- as.character(MDBCTRL$CASE$CASEFILE[1])
    casetype <- as.character(MDBCTRL$CASE$MODESHORTNAME[1])  
    studymode <- as.character(MDBCTRL$CASE$STUDYMODE[1])  
    caseid <- as.character(MDBCTRL$CASE$CASEID[1])
  
    # Extra Flag for RealTime Pricing Project
    if ('RUN_ENSHORTFALLTRANSFER' %in% colnames(MDBCTRL$CASE)) {
      enrgshortfalltransfer <- MDBCTRL$CASE$RUN_ENSHORTFALLTRANSFER[1]
    } else {
      enrgshortfalltransfer <- 0
    }

    if ('RUN_PRICETRANSFER' %in% colnames(MDBCTRL$CASE)) {
      pricetransfer <- MDBCTRL$CASE$RUN_PRICETRANSFER[1]
    } else {
      pricetransfer <- 0
    }
      
    if ('USESPDSOLVEDIMM' %in% colnames(MDBCTRL$CASE)) {
      usegeninitialMW <- MDBCTRL$CASE$USESPDSOLVEDIMM[1]
    } else {
      usegeninitialMW <- 0
    }  
  
    # Get rundatetime and dataDate
    dataDate <- dmy_hm(MDBCTRL$CONTROL$INTERVAL[1], tz = "Pacific/Auckland")
    runtime <- format(mssDataList$RUNDATETIME,'%Y%m%d%H%M%S',tz="Pacific/Auckland")
   
    # create GDX name using casetype and runtime
    if (casetype == 'FP') {
        gdxname <- paste0(casetype,'_',format(dataDate,format = '%Y%m%d_'),caseid,'_',runtime)
    } else {
        gdxname <- paste0(casetype,'_',format(dataDate,format = '%Y%m%d_%H%M_'),caseid)
    }
    
    # Create the folder for GDX destination
    yearstr <- format(dataDate,format = '%Y')   
    gdxDestination <- paste0(gdxDestination,'/',yearstr)
    if (!(dir.exists(gdxDestination))) { dir.create(path=gdxDestination,recursive=T) } 
    
    ###### The following section creates datetime and periods sets #######
    # Create caseName set
    caseName <- tibble(cn = MDBCTRL$CASE$CASEFILE) %>% gams_symbol('caseName')  
    
    # Create scalar i_day, i_month and i_year
    i_day <- day(dataDate) %>% setattr('symName','i_day')
    i_month <- month(dataDate) %>% setattr('symName','i_month')
    i_year <- year(dataDate) %>% setattr('symName','i_year')
    
    # Create i_dateTime set
    i_dateTime <- tibble(INTERVAL = MDBCTRL$CONTROL$INTERVAL) %>% gams_symbol('i_dateTime')
    
    # Create i_tradePeriod set    
    if (casetype == "FP") {
        i_tradePeriod <- tibble(PERIOD = paste0("TP", 1:nrow(MDBCTRL$CONTROL))) %>% gams_symbol("i_tradePeriod")
    } else {
        i_tradePeriod <- tibble(PERIOD = MDBCTRL$CONTROL$INTERVAL) %>% gams_symbol("i_tradePeriod")
    }
    
    # create i_dateTimeTradePeriod set
    i_dateTimeTradePeriod <- bind_cols(i_dateTime, i_tradePeriod) %>% gams_symbol('i_dateTimeTradePeriodMap')
    

####################################################################################################################
####################################################################################################################
####################################################################################################################
  
    #### Reading data into data frame for further process ##########################
    dt_tp <- i_dateTimeTradePeriod %>% mutate_all(as.character)               # Used to map datetime to period for other tables in later stage
  
    # Read data from MSSMKT_ISLAND table
    mssmkt_island <- mutate_if(MSSMKT$ISLAND, is.character, str_squish) %>%
        select(-c(I, MSSDATA, ISLAND),-starts_with('1')) %>% rename(ISLAND = ISLAND_1)
    
    # Read data from DAILY_UNITDATA table and map TP to dateTime
    daily_unitdata <- mutate_if(DAILY$UNITDATA, is.character, str_squish ) %>% 
        inner_join(dt_tp, by = "INTERVAL") %>% 
        select(-c(INTERVAL, I, MSSDATA, UNITDATA),-starts_with('1'))
    
    # Read data from DAILY_PNODE table
    daily_pnode <- mutate_if(DAILY$PNODE, is.character, str_squish) %>%
        mutate(ENODENAME = str_replace_all(ENODENAME, " ", "")) %>% 
        inner_join(dt_tp, by = "INTERVAL") %>%  
        select(-c(INTERVAL, I, MSSDATA, PNODE),-starts_with('1'))
    
    # Read data from PERIOD_BIDSANDOFFERS table
    period_bidsandoffers <- mutate_if(PERIOD$BIDSANDOFFERS, is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>% 
        select(-c(INTERVAL, I, MSSDATA, BIDSANDOFFERS),-starts_with('1'))
    
    # Read data from PERIOD_TRADERPERIODS table
    period_traderperiods <- mutate_if(PERIOD$TRADERPERIODS, is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>% 
        # filter(TRADETYPE != 'ENDE') %>%                                             # ENDE nolonger exists and should be ignored in Audit case
        select(-c(INTERVAL, I, MSSDATA, TRADERPERIODS),-starts_with('1'))
    
    # Read data from MSSNET_ENODEBUS table
    mssnet_enodebus <- mutate_if(TOPOLOGY$ENODEBUS, is.character, str_squish) %>%
        mutate(ID_ENODE = str_replace_all(ID_ENODE," ","")) %>%
        inner_join(dt_tp, by = "INTERVAL") %>% 
        select(-c(INTERVAL, I, NETDATA, ENODEBUS),-starts_with('1'))
    
    # Read data from MSSNET_NODE table
    mssnet_node <- mutate_if(MSSNET$NODE, is.character, str_squish) %>%
        mutate(ID_ENODE = str_replace_all(ID_ENODE," ","")) %>%
        select(-c(I, NETDATA, NODE),-starts_with('1'))
    
    # Read data from PERIOD_PNODEINT table or PERIOD_PNODELOAD table ( Real Time Pricing project )
    if ("PNODELOAD" %in% names(mssDataList$PERIOD)) {
      period_pnodeload <- mutate_if(PERIOD$PNODELOAD, is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>% 
        select(-c(INTERVAL, I, MSSDATA, PNODELOAD),-starts_with('1'))
    } else {
      period_pnodeint <- mutate_if(PERIOD$PNODEINT, is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>% 
        select(-c(INTERVAL, I, MSSDATA, PNODEINT),-starts_with('1'))
    }
  
    # Read data from MSSMOD_PNODEOVRD table
    mssmod_pnodeovrd <- mutate_if(MSSMOD$PNODEOVRD, is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL")  %>%
        select(-c(INTERVAL, I, MSSDATA, PNODEOVRD),-starts_with('1')) 
    
    # Read data from MSSMKT_BRANCHPARAM table
    mssmkt_branchpara <- mutate_if(MSSMKT$BRANCHPARAM, is.character, str_squish) %>%
        select(-c(I, MSSDATA, BRANCHPARAM),-starts_with('1'))
    
    # Read data from MSSMOD_BRANCHLIMIT table
    mssmod_branchlimit <- mutate_if(MSSMOD$BRANCHLIMIT, is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>%
        select(-c(INTERVAL,I, MSSDATA,BRANCHLIMIT),-starts_with('1'))
    
    # Read data from MSSNET_BRANCHNODE table
    mssnet_branchnode <- mutate_if(MSSNET$BRANCHNODE, is.character, str_squish) %>%
        select(-c(I, NETDATA, BRANCHNODE),-starts_with('1'))
    
    # Read data from MSSNET_BRANCHBUS table
    mssnet_branchbus <- mutate_if(TOPOLOGY$BRANCHBUS, is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>%
        select(-c(INTERVAL, I, NETDATA, BRANCHBUS),-starts_with('1')) %>%
        mutate_at(c("SUSCEPTANCE", "RESISTANCE"),as.numeric)
    
    # Read data from PERIOD_HVDCLINK table
    period_hvdclink <- mutate_if(PERIOD$HVDCLINK, is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>%
        select(-c(INTERVAL, I, MSSDATA, HVDCLINK),-starts_with('1'))
    
    # Read data from PERIOD_RISKPARAMSCHEDULE table
    period_riskparamschedule <- mutate_if(PERIOD$RISKPARAMSCHEDULE, is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>%
        select(-c(INTERVAL, I, MSSDATA, RISKPARAMSCHEDULE),-starts_with('1'))
    
    # Read data from PERIOD_RESERVESHARING table
    period_reservesharing <- mutate_if(PERIOD$RESERVESHARING, is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>%
        select(-c(INTERVAL, I, MSSDATA, RESERVESHARING),-starts_with('1'))
    
    # Read data from PERIOD_HVDCROUNDPOWER table
    hvdc_roundpower <- mutate_if(PERIOD$HVDCROUNDPOWER, is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>% select(PERIOD, HVDCALLOWROUNDPOWER)
    
    # Read data from PERIOD_SCARCITYAREA table
    if ("SCARCITYAREA" %in% names(PERIOD)) {
        period_scarcityarea <- mutate_if(PERIOD$SCARCITYAREA, is.character, str_squish) %>%
            inner_join(dt_tp, by = "INTERVAL") %>% mutate(SCARCITYAREA = SCARCITYAREA_1) %>%
            select(-c(INTERVAL, I, MSSDATA,SCARCITYAREA_1),-starts_with('1'))
    } else {
        period_scarcityarea <- 
            data.frame(SCARCITYAREA = character(), SCARCITYACTIVEFLAG = character(),
                       SCALINGFLOOR = numeric(), SCALINGCEILING = numeric(),
                       PERIOD = character(), stringsAsFactors = FALSE )
    }
    
    # Read data from PERIOD_SCARCITYISLAND table
    if ("SCARCITYISLAND" %in% names(PERIOD)) {
        period_scarcityisland <- mutate_if(PERIOD$SCARCITYISLAND, is.character, str_squish) %>%
            inner_join(dt_tp, by = "INTERVAL") %>%
            select(-c(INTERVAL, I, MSSDATA,SCARCITYISLAND),-starts_with('1'))
    } else {
        period_scarcityisland <- 
            data.frame(ISLAND = character(), GWAPPASTDAYSAVG = numeric(),
                       GWAPCOUNTFORAVG = numeric(), GWAPTHRESHOLD = numeric(),
                       PERIOD = character(), stringsAsFactors = FALSE )
        
    }
    
    # Read data from PERIOD_VIRTUALRESERVE table
    if ("VIRTUALRESERVE" %in% names(PERIOD)) {
        period_virtualreserve <- mutate_if(PERIOD$VIRTUALRESERVE, is.character, str_squish) %>%
            inner_join(dt_tp, by = "INTERVAL") %>%
            select(-c(INTERVAL, I, MSSDATA,VIRTUALRESERVE),-starts_with('1'))
    } else {
        period_virtualreserve <- 
            data.frame(ISLAND = character(), LIMIT = numeric(),
                       PRICE = numeric(), SIXSEC = numeric(),
                       PERIOD = character(), stringsAsFactors = FALSE )
    }
    
    # Read data from MSSMKT_HVDCBRANCH table
    mssmkt_hvdcbranch <- mutate_if(MSSMKT$HVDCBRANCH, is.character, str_squish) %>%
        select(-c(I, MSSDATA,HVDCBRANCH),-starts_with('1')) %>% rename(HVDCBRANCH = HVDCBRANCH_1)
    
    # Read data from MSSMKT_UNITACTUALMW table
    if ("UNITACTUALMW" %in% names(MSSMKT)) {
        mssmkt_unitactualMW <- mutate_if(MSSMKT$UNITACTUALMW, is.character, str_squish) %>%
            inner_join(dt_tp, by = "INTERVAL") %>%
            select(-c(INTERVAL, I, MSSDATA, UNITACTUALMW),-starts_with('1'))
    } else if ("UNITACTUALMW" %in% names(PERIOD)) { # Added for auditting purpose
        mssmkt_unitactualMW <- mutate_if(PERIOD$UNITACTUALMW, is.character, str_squish) %>%
            inner_join(dt_tp, by = "INTERVAL") %>%
            select(-c(INTERVAL, I, MSSDATA, UNITACTUALMW),-starts_with('1'))
    } else {
        mssmkt_unitactualMW <- data.frame(PNODENAME = character(), ACTUALMW = numeric(),
                                          PERIOD = character(), stringsAsFactors = FALSE )
    }

    # Read data from MSSMKT_UNITINITIALMW table - don't apply for FP/RTP
    if (casetype %in% c('RTD','PRSS','PRSL','NRSS','NRSL','WDS')) {
        mssmkt_unitinitialMW <- mutate_if(MSSMKT$UNITINITIALMW, is.character, str_squish) %>%
            mutate(PERIOD = as.character(i_tradePeriod$PERIOD[1]), INITIALMW = UNITMW) %>%
            select(PERIOD, PNODENAME, INITIALMW)
    }
   
    # Read data from PERIOD_SPDPARAMETER table - Real Time Pricing project
    if ("SPDPARAMETER" %in% names(PERIOD)) {
        period_spdparameter <- mutate_if(PERIOD$SPDPARAMETER, is.character, str_squish) %>%
            inner_join(dt_tp, by = "INTERVAL") %>%
            select(-c(INTERVAL, I, MSSDATA,SPDPARAMETER),-starts_with('1'))
    } else {
        period_spdparameter <- 
            data.frame(NAME = character(), VALUE = numeric(),
                       PERIOD = character(), stringsAsFactors = FALSE )
    }
  
    # Read data from PERIOD_SCARCITYENNATIONALFACTORS table - Real Time Pricing project
    if ('SCARCITYENNATIONALFACTORS' %in% names(PERIOD)) {
        period_scarcityennationalfactors <- PERIOD$SCARCITYENNATIONALFACTORS %>%
            mutate_if(is.character, str_squish) %>%
            inner_join(dt_tp, by = "INTERVAL") %>%
            select(-c(INTERVAL, I, MSSDATA,SCARCITYENNATIONALFACTORS),-starts_with('1'))
    } else {
        period_scarcityennationalfactors <- 
            data.frame(TRANCHENUMBER = character(), PRICE = numeric(), FACTOR = numeric(),
                       PERIOD = character(), stringsAsFactors = FALSE )
    }
  
    # Read data from PERIOD_SCARCITYENPNODEFACTORS table - Real Time Pricing project
    if ('SCARCITYENPNODEFACTORS' %in% names(PERIOD)) {
        period_scarcityenpnodefactors <- PERIOD$SCARCITYENPNODEFACTORS %>%
            mutate_if(is.character, str_squish) %>%
            inner_join(dt_tp, by = "INTERVAL") %>%
            select(-c(INTERVAL, I, MSSDATA,SCARCITYENPNODEFACTORS),-starts_with('1'))
    } else {
        period_scarcityenpnodefactors <- 
            data.frame(PNODENAME = character(), TRANCHENUMBER = character(), PRICE = numeric(),
                       FACTOR = numeric(), PERIOD = character(), stringsAsFactors = FALSE )
    }
    
    # Read data from PERIOD_SCARCITYENPNODELIMITS table - Real Time Pricing project
    if ('SCARCITYENPNODELIMITS' %in% names(PERIOD)) {
        period_scarcityenpnodelimits <- PERIOD$SCARCITYENPNODELIMITS %>%
            mutate_if(is.character, str_squish) %>%
            inner_join(dt_tp, by = "INTERVAL") %>%
            select(-c(INTERVAL, I, MSSDATA,SCARCITYENPNODELIMITS),-starts_with('1'))
    } else {
        period_scarcityenpnodelimits <- 
            data.frame(PNODENAME = character(), TRANCHENUMBER = character(), PRICE = numeric(),
                       LIMIT = numeric(), PERIOD = character(), stringsAsFactors = FALSE )
    }

    # Read data from PERIOD_SCARCITYRESISLANDLIMITS table - Real Time Pricing project
    if ('SCARCITYRESISLANDLIMITS' %in% names(PERIOD)) {
        period_scarcityresislandlimits <- PERIOD$SCARCITYRESISLANDLIMITS %>%
            mutate_if(is.character, str_squish) %>%
            inner_join(dt_tp, by = "INTERVAL") %>%
            select(-c(INTERVAL, I, MSSDATA,SCARCITYRESISLANDLIMITS),-starts_with('1'))
    } else {
        period_scarcityresislandlimits <- 
            data.frame(ISLAND = character(), RESERVECLASS = character(), TRANCHENUMBER = character(),
                       PRICE = numeric(), LIMIT = numeric(), PERIOD = character(), stringsAsFactors = FALSE )
    }
  


    
####################################################################################################################
####################################################################################################################
####################################################################################################################

    # The following section creates statics sets, parameters and scalars:
    # i_studyTradePeriod, i_AClineUnit, i_tradingPeriodLength, 
    # i_branchReceivingEndLossProportion, i_CVPvalues, i_cvp"
    
    # create i_StudyTradePeriod parameters (not used should be removed in the future)
    i_studyperiod <- mutate(i_tradePeriod, values = 1) %>% gams_symbol('i_studyTradePeriod',type = 'par')
    
    # create scalar i_ACLineUnit
    i_aclineunit <- 1
    i_aclineunit <- i_aclineunit %>% setattr('symName','i_AClineUnit')
    
    # create scalar i_TradingPeriodLength
    i_tradingperiodlength <- MDBCTRL$CASE$INTERVALDURATION %>% setattr('symName','i_tradingPeriodLength')
    
    # create scalar i_BranchReceivingEndLossProportion
    i_branchreceivingendlossproportion <- 1
    i_branchreceivingendlossproportion <- i_branchreceivingendlossproportion %>% 
                                             setattr('symName','i_branchReceivingEndLossProportion')
    
    # create i_CVP set and i_CVPValues parameter - fixed data read from CVPs.csv file
    i_cvpvalues <- 
        data.frame(i_CVP = c("i_Deficit60sReserve_CE","i_Deficit60sReserve_ECE",
                             "i_Deficit6sReserve_CE","i_Deficit6sReserve_ECE",
                             "i_DeficitACNodeConstraint","i_DeficitBranchFlow",
                             "i_DeficitBranchGroupConstraint","i_DeficitBusGeneration",
                             "i_DeficitGenericConstraint","i_DeficitMnodeConstraint",
                             "i_DeficitRampRate","i_SurplusACNodeConstraint",
                             "i_SurplusBranchFlow","i_SurplusBranchGroupConstraint",
                             "i_SurplusBusGeneration","i_SurplusGenericConstraint",
                             "i_SurplusMnodeConstraint","i_SurplusRampRate",
                             "i_Type1DeficitMixedConstraint","i_Type1SurplusMixedConstraint"),
                   Values = c(100000, 800000, 
                              100000, 800000, 
                              510000, 600000, 
                              650000, 500000, 
                              710000, 700000, 
                              850000, 510000, 
                              600000, 650000, 
                              500000, 710000, 
                              700000, 850000, 
                              750000, 750000)
        ) %>% gams_symbol('i_CVPvalues',type = 'par')
    
    i_cvp <- i_cvpvalues %>% select(i_CVP) %>% gams_symbol('i_CVP')
    
####################################################################################################################
####################################################################################################################
####################################################################################################################
    
    # The following section creates island, node and bus data (sets and parameters) 
    # using information from mssmkt_island, daily_pnode, mssnet_enodebus, mssnet_node,
    # period_pnodeint
    
    # create i_island set
    i_island <- select(mssmkt_island, ISLAND) %>% gams_symbol('i_island')
    
    # create i_node set
    i_node <- filter(daily_pnode, PNODETYPE != 'D') %>% 
        select(PNODENAME) %>% distinct() %>% gams_symbol('i_node')
    
    # create i_bus set
    i_bus <- select(mssnet_enodebus, ID_BUS)%>% distinct()%>% gams_symbol('i_bus')
    
    # create i_tradePeriodNode set
    i_tradeperiodnode <- merge(i_tradePeriod,i_node, all = TRUE) %>% gams_symbol('i_tradePeriodNode')
    
    # create i_tradePeriodBus set
    i_tradeperiodbus <- select(mssnet_enodebus, PERIOD, ID_BUS) %>% distinct() %>% gams_symbol('i_tradePeriodBus')
    
    # create i_tradePeriodBusIsland set
    i_tradeperiodbusisland <- mssnet_node %>% 
        transmute(ID_ST, ISLAND = ifelse(ID_COMPANY == 'NORTH','NI','SI')) %>%
        distinct() %>% inner_join(mssnet_enodebus, by = 'ID_ST') %>%
        select(PERIOD,ID_BUS,ISLAND) %>% distinct() %>% 
        gams_symbol('i_tradePeriodBusIsland')
    
    # create i_tradePeriodNodeBus set and i_tradePeriodNodeBusAllocationFactor
    nodebusfactor <- mssnet_node %>%                                                # Create a mapping from ID_ENODE to a distinct identifier 
        select(ID_ENODE, ID_KV,ID_EQUIPMENT, ID_ST) %>%                             # comprising of the ID_ST, ID_KV and ID_EQUIPMENT fields 
        distinct()                                                                  # from the NODE view of the static .MSSNET file     
    
    nodebusfactor <- daily_pnode %>% filter(PNODETYPE!= 'D') %>%                    # Create a time-stamped mapping of PNODENAME to a distinct identifier 
        transmute(PERIOD, PNODE = PNODENAME, ID_ST = KEY1, ID_KV = KEY2,            # comprising of KEY1, KEY2 and KEY3 from the PNODE view of the .DAILY file.
                  ID_EQUIPMENT = KEY3, FACTOR = FACTOR) %>% distinct() %>%          # This should only be done for PNODETYPES X, I and A
        inner_join(nodebusfactor, by = c('ID_ST','ID_KV','ID_EQUIPMENT'))           # Use these two mappings to create a time-stamped mapping of PNODENAME to ID_ENODE.
    
    nodebusfactor <- transmute(mssnet_enodebus, PERIOD, ID_ENODE, BUS = ID_BUS,     # Create a time-stamped mapping of ID_ENODE to ID_BUS 
                               E_ISLAND = ELECTRICAL_ISLAND) %>%                    # from the ENODEBUS view of the different dynamic .MSSNET files.
        distinct() %>% inner_join(nodebusfactor, by = c('PERIOD','ID_ENODE')) %>% 
        group_by(PERIOD, PNODE, BUS, E_ISLAND) %>%                                  # Calculate sum of factors from one PNODE to one bus by each period
        summarise(FACTOR = sum(FACTOR)) %>% data.frame() %>% filter(FACTOR > 0)
    
    # create i_tradePeriodNodeBus set
    i_tradeperiodnodebus <- select(nodebusfactor, PERIOD, PNODE, BUS) %>% 
        distinct() %>% gams_symbol('i_tradePeriodNodeBus')
    
    # create i_tradePeriodNodeBusAllocationFactor parameter
    df0 <- nodebusfactor %>% select(PERIOD, PNODE, E_ISLAND) %>% distinct() %>% 
        group_by(PERIOD,PNODE) %>% summarise(n = n()) %>% data.frame()
    
    df1 <- df0 %>% filter(n==1) %>%                                                 # Getting all Pnode_bus pairs that mapped to only one electrical island 
        inner_join(nodebusfactor, by = c('PERIOD','PNODE'))
    df1 <- group_by(df1,PERIOD, PNODE) %>% summarise(sumfactor = sum(FACTOR)) %>%   # Calculating the Node --> Bus Allocation factor for this group
        data.frame() %>% inner_join(df1, by = c('PERIOD','PNODE')) %>%
        transmute(PERIOD, PNODE, BUS, E_ISLAND, FACTOR = FACTOR/sumfactor) 
    
    dfn <- df0 %>% filter(n >= 2) %>%                                               # Getting all Pnode_bus pairs that mapped to more than one electrical island
        inner_join(nodebusfactor, by = c('PERIOD','PNODE')) %>%
        filter(E_ISLAND == 1 | E_ISLAND == 2)                                       # Ignore Pnode_bus pair of electrical island other than 1 or 2
    dfn <- group_by(dfn, PERIOD, PNODE) %>%                                         # Calculating the Node --> Bus Allocation FACTOR for this group
        summarise(sumfactor = sum(FACTOR)) %>% data.frame() %>%
        inner_join(dfn, by = c('PERIOD','PNODE')) %>%
        transmute(PERIOD, PNODE, BUS, E_ISLAND, FACTOR = FACTOR/sumfactor) 
  
    # create i_tradeperiodnodebusallocationfactor
    i_tradeperiodnodebusallocationfactor <- rbind(dfn,df1) %>% distinct %>% 
        filter(FACTOR > 0) %>% select(-E_ISLAND) %>%
        arrange(PERIOD, PNODE, BUS) %>%
        gams_symbol('i_tradePeriodNodeBusAllocationFactor','par')
    
    # create i_tradePeriodBusElectricalIsland parameter
    i_tradeperiodbuselectricalisland <- mssnet_enodebus %>%
        transmute(PERIOD, BUS = ID_BUS, E_ISLAND = ELECTRICAL_ISLAND) %>% 
        distinct() %>% gams_symbol('i_tradePeriodBusElectricalIsland','par')
    
    # create i_tradePeriodHVDCNode parameter
    i_tradeperiodHVDCnode <- 
        data.frame(NODE = c('HAY2701','HAY2702','BEN2701','BEN2702')) %>%
        merge(i_tradePeriod, all = TRUE) %>% select(PERIOD, NODE) %>%
        gams_symbol('i_tradePeriodHVDCNode')
    if (is.null(MSSMKT[['HVDCBUS']])) {
        i_tradeperiodHVDCnode$value <- 0
    } else {
        i_tradeperiodHVDCnode$value <- 1    
    }
    
    # create i_tradePeriodReferenceNode parameter
    i_tradeperiodrefnode <- merge(i_tradePeriod, mssmkt_island, all = TRUE) %>% 
        transmute(PERIOD, NODE = SLACKPNODENAME, value = 1) %>%
        gams_symbol('i_tradePeriodReferenceNode','par')
    
####################################################################################################################
####################################################################################################################
####################################################################################################################    
    
    # The following section creates static sets that applied 
    # for branch related parameter and variables 
    
    # create i_losssegment set
    i_losssegment <- data.frame(ls = paste0('ls',c(1:10))) %>% 
        gams_symbol('i_lossSegment')
    
    # create i_lossParameter set
    i_lossparameter <- data.frame(dim = c('i_MWbreakPoint','i_lossCoefficient')) %>%
        gams_symbol('i_lossParameter')
    
    # create i_noLossBranch set
    i_nolossbranch <- data.frame(d1 = 'ls1',d2 = 'i_MWbreakPoint',v = 10000) %>%
        gams_symbol('i_noLossBranch','par')
    
    # create i_AClossBranch (for completeness but not used in vSPD model)
    i_AClossbranch <- 
        data.frame(dim1 = c("ls1","ls1","ls2","ls2","ls3","ls3"),
                   dim2 = c("i_MWbreakPoint","i_lossCoefficient","i_MWbreakPoint",
                            "i_lossCoefficient","i_MWbreakPoint","i_lossCoefficient"),
                   value = c(0.3101, 0.002326, 0.6899, 0.01, 10000, 0.01767)
        ) %>%
        gams_symbol('i_ACLossBranch','par')
    
    
    # create i_DClossBranch (for completeness but not used in vSPD model)
    i_DClossbranch <- 
        data.frame(dim1 = c("ls1", "ls1", "ls2", "ls2", "ls3", "ls3", 
                            "ls4", "ls4", "ls5", "ls5", "ls6", "ls6"),
                   dim2 = c("i_MWbreakPoint", "i_lossCoefficient", 
                            "i_MWbreakPoint", "i_lossCoefficient", 
                            "i_MWbreakPoint", "i_lossCoefficient", 
                            "i_MWbreakPoint", "i_lossCoefficient", 
                            "i_MWbreakPoint", "i_lossCoefficient", 
                            "i_MWbreakPoint", "i_lossCoefficient"),
                   values = c(0.14495, 0.001087, 0.32247, 0.00467,
                              0.5, 0.00822, 0.67753, 0.011775, 
                              0.85505, 0.015326, 10000, 0.018913)
        ) %>% gams_symbol('i_HVDCLossBranch','par')
    
    # create i_FlowDirection set
    i_flowdirection <- data.frame(x = c('Forward', 'Backward')) %>%
        gams_symbol('i_FlowDirection')
    
####################################################################################################################
####################################################################################################################
####################################################################################################################    
    
    # The following section creates all hvdc and branch data (sets and parameters) 
    # using information from mssmkt_hvdcbranch, mssnet_enodebus, period_hvdclink, 
    # mssmkt_branchpara, mssnet_branchnode, mssmod_branchlimit and mssnet_branchbus
    
    hvdcpara <- mssmkt_hvdcbranch %>% 
        # Creating FrEnode and ToEnode mapped to HVDC branch
        transmute(HVDCBRANCH, 
                  FR_ENODE = paste0(FROM_ENODEKEY1,FROM_ENODEKEY2,FROM_ENODEKEY3),
                  TO_ENODE = paste0(TO_ENODEKEY1,TO_ENODEKEY2,TO_ENODEKEY3)) %>%
        # Merging with mssnet_enodebus to map HVDC branch to FrBus and ToBus
        merge(mssnet_enodebus, by.x = 'FR_ENODE', by.y = 'ID_ENODE') %>%
        rename(FROM_BUS = ID_BUS) %>% 
        merge(mssnet_enodebus, by.x = c('PERIOD','TO_ENODE'), 
              by.y = c('PERIOD','ID_ENODE')) %>% rename(TO_BUS = ID_BUS) %>%
        select(PERIOD,HVDCBRANCH,FROM_BUS,TO_BUS) %>%
        # Merging with period_hvdclink to get parameters of HVDC branches
        inner_join(period_hvdclink, by = c('PERIOD','HVDCBRANCH')) %>%
        rename(BRANCHNAME = HVDCBRANCH)
    
    
    branchpara <- mssmkt_branchpara %>% filter(KEY4 != 'DCCNV') %>%                 # Filter out the branch with KEY4 = 'DCCNV'
        mutate(NUMLOSSTRANCHES = as.numeric(NUMLOSSTRANCHES)) %>%
        transmute(BRANCHNAME, NUMLOSSTRANCHES = NUMLOSSTRANCHES * MARKETBRANCH,     # Make sure number of loss tranches = 0 for non-market branch
                  KEY = ifelse(KEY4!='XF', paste0(KEY2,'.',KEY3),                   # Create a distinct key to map with branch name
                               paste0(KEY1,'_',KEY2,'.',KEY3)), MARKETBRANCH)
    
    branchpara <- mssnet_branchnode %>% 
        # Creating the distinct KEY that mapped with ID_BRANCH in mssnet_branchnode
        transmute(ID_BRANCH, KEY = ifelse(KEY4!='XF', paste0(KEY2,'.',KEY3),
                                          paste0(KEY1,'_',KEY2,'.',KEY3))) %>%
        left_join(branchpara, by = 'KEY') %>%                                       # Merging branch data to mssnet_branchnode 
        mutate(BRANCHNAME = ifelse(is.na(BRANCHNAME),KEY,BRANCHNAME),               # and if there is no match in mssmkt_branchpara   
               NUMLOSSTRANCHES = ifelse(is.na(NUMLOSSTRANCHES),0,NUMLOSSTRANCHES),  # number of loss tranches will be set to zero
               MARKETBRANCH = ifelse(is.na(MARKETBRANCH),0,MARKETBRANCH)) %>%
        inner_join(mssnet_branchbus, by = 'ID_BRANCH')                              # Merging with mssnet_branchbus table to get connectivity definittion, resistance and susceptance
    
    branchpara <- mssmod_branchlimit %>%
        transmute(KEY = ifelse(KEY4!='XF', paste0(KEY2,'.',KEY3),                   # Create a distinct key to map with branch name
                               paste0(KEY1,'_',KEY2,'.',KEY3)),
                  PERIOD, MWMAX = BASECASEMWLIMITFOR, FIXEDLOSS,
                  MWMAXREV = BASECASEMWLIMITREV) %>%
        right_join(branchpara, by = c('PERIOD','KEY')) %>% select(-KEY) %>%         # Merging branchpara with mssmod_branchlimit table to get branch capacity and fixed loss using the distinct KEY
        transmute(PERIOD, ID_BRANCH, BRANCHNAME, 
                  FROM_BUS = ID_FROMBUS, TO_BUS = ID_TOBUS,
                  MWMAX = ifelse(is.na(MWMAX),9999,MWMAX), 
                  MWMAXREV = ifelse(is.na(MWMAXREV),9999,MWMAXREV),
                  FIXEDLOSS = ifelse(is.na(FIXEDLOSS), 0, FIXEDLOSS * MARKETBRANCH), 
                  NUMLOSSTRANCHES,SUSCEPTANCE,RESISTANCE, REMOVE) 
    
    branchpara <- hvdcpara %>% 
        transmute(PERIOD, ID_BRANCH = BRANCHNAME, BRANCHNAME,
                  FROM_BUS, TO_BUS, MWMAX, MWMAXREV = 0, FIXEDLOSS, 
                  NUMLOSSTRANCHES, SUSCEPTANCE = 0,RESISTANCE, REMOVE) %>% 
        rbind(branchpara) %>%
        merge(i_tradeperiodbuselectricalisland, by.x = c('PERIOD','FROM_BUS'),      
              by.y = c('PERIOD','BUS')) %>% rename(FR_ISLAND = E_ISLAND) %>%
        merge(i_tradeperiodbuselectricalisland, by.x = c('PERIOD','TO_BUS'), 
              by.y = c('PERIOD','BUS')) %>% rename(TO_ISLAND = E_ISLAND) %>%
        mutate(REMOVE = ifelse(FR_ISLAND * TO_ISLAND == 0, 1, REMOVE))              # If a branch connect to a dead node --> removed
    
    # create branchParameter set
    i_branchpara <- data.frame(x = c('i_branchResistance','i_branchSusceptance',
                                     'i_branchFixedLosses','i_numLossTranches')) %>%
        gams_symbol('i_branchParameter')
    
    # create i_branch
    i_branch <- select(branchpara,BRANCHNAME) %>% distinct %>% gams_symbol('i_branch')
    
    # create i_tradePeriodBranchDefn
    i_tradeperiodbranchdefn <- branchpara %>% 
        select(PERIOD,BRANCHNAME, FROM_BUS,TO_BUS) %>% 
        distinct %>% gams_symbol('i_tradePeriodBranchDefn')
    
    # create i_tradePeriodHVDCBranch
    i_tradeperiodHVDCbranch <- select(hvdcpara,PERIOD, BRANCHNAME, HVDCTYPE) %>% 
        gams_symbol('i_tradePeriodHVDCBranch','par')
    
    # create i_tradePeriodBranchParamater
    i_tradeperiodbranchpara <- branchpara %>% 
        transmute(dim1 = PERIOD, dim2 = BRANCHNAME,
                  i_branchResistance = RESISTANCE/100, 
                  i_branchSusceptance = SUSCEPTANCE/100,
                  i_branchFixedLosses = FIXEDLOSS,
                  i_numLossTranches = NUMLOSSTRANCHES) %>% 
        gather(key = 'dim3', value = 'value', -dim1, -dim2) %>%
        distinct %>% gams_symbol('i_tradePeriodBranchParameter','par')
    
    # create i_tradePeriodBranchCapacity
    i_tradeperiodbranchcapa <- select(branchpara, PERIOD,BRANCHNAME,MWMAX) %>% 
        distinct %>% gams_symbol('i_tradePeriodBranchCapacity','par')
    
    # create i_tradePeriodBranchCapacityDirected
    i_tradeperiodbranchcapadirected <- branchpara %>%
        select(PERIOD,BRANCHNAME,MWMAX,MWMAXREV) %>% 
        gather(key = DIRECTION, value = Value, c(MWMAX,MWMAXREV)) %>%
        mutate(DIRECTION = ifelse(DIRECTION == 'MWMAX',
                                  as.character(i_flowdirection$x[1]),
                                  as.character(i_flowdirection$x[2]))) %>%
        distinct %>% gams_symbol('i_tradePeriodBranchCapacityDirected','par')
    
    # create i_tradePeriodReverseRatingsApplied - The golivedatetime reflects the actual go-live time)
    i_tradePeriodReverseRatingsApplied <- dt_tp %>%
        mutate(golivedatetime = dmy_hm('24-JUNE-2021 00:00', tz = "Pacific/Auckland")) %>%
        mutate(i_dateTime = dmy_hm(INTERVAL, tz = "Pacific/Auckland")) %>%
        mutate(value = ifelse(i_dateTime >= golivedatetime,1,0)) %>%
        select(PERIOD,value) %>% distinct %>% gams_symbol('i_tradePeriodReverseRatingsApplied','par')
  
    # create i_tradePeriodBranchOpenStatus
    i_tradeperiodbranchstatus <- select(branchpara, PERIOD, BRANCHNAME, REMOVE) %>% 
        distinct %>% gams_symbol('i_tradePeriodBranchOpenStatus','par')
    
    # create i_tradePeriodBranchOpenStatus
    i_tradePeriodAllowHVDCRoundpower <- hvdc_roundpower %>% 
        transmute(PERIOD, HVDCALLOWROUNDPOWER) %>%
        distinct %>% gams_symbol('i_tradePeriodAllowHVDCRoundpower','par')
    
####################################################################################################################
####################################################################################################################
####################################################################################################################      
    
    # The following section creates all branch constraint data (sets and parameters)
    # using information from mssmod_branchconstraint, mssmod_branchconstraintfactor 
    # and mssmkt_branchpara"
    
    # create i_ConstraintRHS set
    i_cstrRHS <- data.frame(dim = c('i_ConstraintLimit','i_ConstraintSense')) %>%
        gams_symbol('i_ConstraintRHS')
    
    # Read data from MSSMOD_BRANCHCONSTRAINT.csv table
    mssmod_branchconstraint <- MSSMOD$BRANCHCONSTRAINT %>%
        mutate_if(is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>%
        select(-c(INTERVAL, I, MSSDATA, BRANCHCONSTRAINT),-starts_with('1')) %>%
        rename(BRANCHCONSTRAINT = BRANCHCONSTRAINT_1) %>%
        select(PERIOD, BRANCHCONSTRAINT, LOWERLIMITVALID, LOWERLIMIT, 
               UPPERLIMITVALID, UPPERLIMIT, HVDC_RAMP)
    
    # Read data from MSSMOD_BRANCHCONSTRFACTORS table
    mssmod_branchconstraintfactor <- MSSMOD$BRANCHCONSTRFACTORS %>%
        mutate_if(is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>%
        select(-c(INTERVAL, I, MSSDATA, BRANCHCONSTRFACTORS),-starts_with('1')) %>%
        select(PERIOD, BRANCHCONSTRAINT, KEY1, KEY2, KEY3, KEY4, FACTOR)
    
    # create i_branchConstraint
    i_branchconstraint <- select(mssmod_branchconstraint, BRANCHCONSTRAINT) %>% 
        distinct() %>% gams_symbol('i_branchConstraint')
    
    # create i_tradePeriodBranchConstraintFactors
    i_branchconstraintfactors <- mssmkt_branchpara %>% 
        mutate(ID = ifelse(KEY4=='XF', paste0(KEY1,KEY2,KEY3), paste0(KEY2,KEY3))
        ) %>% select(ID, BRANCHNAME)
    
    i_branchconstraintfactors <- mssmod_branchconstraintfactor %>% 
        mutate(ID = ifelse(KEY4=='XF', paste0(KEY1,KEY2,KEY3),paste0(KEY2,KEY3))
        ) %>% inner_join(i_branchconstraintfactors, by = 'ID') %>%
        select(PERIOD, BRANCHCONSTRAINT, BRANCHNAME, FACTOR) %>%
        arrange(PERIOD, BRANCHCONSTRAINT, BRANCHNAME) %>%
        gams_symbol('i_tradePeriodBranchConstraintFactors','par')
    
    # create i_tradePeriodBranchConstraintRHS
    i_branchconstraintRHS <- mssmod_branchconstraint %>%
        mutate(UPPERLIMIT = as.numeric(UPPERLIMIT),
               LOWERLIMIT = as.numeric(LOWERLIMIT),
               LOWERLIMITVALID = as.numeric(LOWERLIMITVALID),
               UPPERLIMITVALID = as.numeric(UPPERLIMITVALID)) %>%
        transmute(dim1 = PERIOD, dim2 = BRANCHCONSTRAINT, 
                  i_ConstraintLimit = ifelse(UPPERLIMITVALID==1, 
                                             UPPERLIMIT, LOWERLIMIT),
                  i_ConstraintSense = LOWERLIMITVALID - UPPERLIMITVALID ) %>%
        gather(dim3, value, -dim1, -dim2) %>%
        gams_symbol('i_tradePeriodBranchConstraintRHS','par')
    
####################################################################################################################
####################################################################################################################
####################################################################################################################      
    
    # The following section creates all AC node constraint data (sets and parameters)
    # (place holder only for now) 
    
    # create i_ACnodeConstraint
    i_acnodeconstraint <- data.frame(dim1 = factor()) %>% 
        gams_symbol('i_ACnodeConstraint')
    
    # create i_tradePeriodACnodeConstraintFactors
    i_acnodeconstraintfactors <- data.frame(dim1 = factor(), dim2 = factor(),
                                            dim3 = factor(), value = numeric()) %>%
        gams_symbol('i_tradePeriodACnodeConstraintFactors','par')
    
    # create i_tradePeriodACnodeConstraintRHS
    i_acnodeconstraintRHS <- data.frame(dim1 = factor(), dim2 = factor(),
                                        dim3 = factor(), value = numeric()) %>%
        gams_symbol('i_tradePeriodACnodeConstraintRHS','par')
    
####################################################################################################################
####################################################################################################################
####################################################################################################################    
    
    # The following section creates all marketnode constraint data (sets and parameters)
    # using information from mssmod_mndconstraint, mssmod_mndconstraintfactors"
    mssmod_mndconstraint <- MSSMOD$MNDCONSTRAINT %>%
        mutate_if(is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>%
        select(-c(INTERVAL, I, MSSDATA, MNDCONSTRAINT),-starts_with('1')) %>%
        transmute(PERIOD, CONSTRAINTNAME, 
                  UPPERLIMIT = as.numeric(UPPERLIMIT),
                  LOWERLIMIT = as.numeric(LOWERLIMIT),
                  LOWERLIMITVALID = as.numeric(LOWERLIMITVALID),
                  UPPERLIMITVALID = as.numeric(UPPERLIMITVALID))
    
    
    mssmod_mndconstraintfactors <- MSSMOD$MNDCONSTRAINTFACTORS %>%
        mutate_if(is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>%
        select(-c(INTERVAL, I, MSSDATA, MNDCONSTRAINTFACTORS),-starts_with('1')) %>%
        mutate(FACTOR = as.numeric(FACTOR), FACTORSIX = as.numeric(FACTORSIX))
    
    # create i_branchConstraint
    i_mnconstraint <- select(mssmod_mndconstraint, CONSTRAINTNAME) %>% 
        distinct %>% gams_symbol('i_MnodeConstraint')
    
    # create i_tradePeriodMNodeEnergyOfferConstraintFactors
    i_mnenrgofferconstraintfactors <- mssmod_mndconstraintfactors %>%
        filter(TRADERTYPE == 'ENOF') %>% 
        select(PERIOD, CONSTRAINTNAME, PNODENAME, FACTOR) %>%
        gams_symbol('i_tradePeriodMNodeEnergyOfferConstraintFactors','par')
    
    # create i_tradePeriodMNodeReserveOfferConstraintFactors
    i_mnresvofferconstraintfactors <- mssmod_mndconstraintfactors %>%
        filter(TRADERTYPE %in% c('ILRO','PLRO','TWRO')) %>%  
        transmute(PERIOD, CONSTRAINTNAME, PNODENAME, 
                  CLASS = ifelse(FACTOR == 1, 'SIR','FIR'),
                  TYPE = ifelse(TRADERTYPE == 'ILRO', 'ILR',
                                ifelse(TRADERTYPE == 'PLRO', 'PLSR','TWDR')), 
                  value = FACTOR + FACTORSIX) %>%
        gams_symbol('i_tradePeriodMNodeReserveOfferConstraintFactors','par')
    
    # create i_tradePeriodMNodeEnergyBidConstraintFactors
    i_mnenrgbidconstraintfactors <- mssmod_mndconstraintfactors %>%
        filter(TRADERTYPE == 'ENDL') %>% 
        select(PERIOD, CONSTRAINTNAME, PNODENAME,FACTOR) %>%
        gams_symbol('i_tradePeriodMNodeEnergyBidConstraintFactors','par')
    
    # create i_tradePeriodMNodeILReserveBidConstraintFactors - currently not used
    i_mnilresvbidconstraintfactors <- mssmod_mndconstraintfactors %>%
        filter(TRADERTYPE == 'EA') %>% 
        transmute(PERIOD, CONSTRAINTNAME, PNODENAME, 
                  CLASS = ifelse(FACTOR == 1, 'SIR','FIR'),
                  value = FACTOR + FACTORSIX) %>%
        gams_symbol('i_tradePeriodMNodeILReserveBidConstraintFactors','par')
    
    # create i_tradePeriodMNodeConstraintRHS
    i_mnconstraintRHS <- mssmod_mndconstraint %>%
        transmute(PERIOD, CONSTRAINTNAME, 
                  i_ConstraintLimit = (UPPERLIMIT + LOWERLIMIT)/
                      (LOWERLIMITVALID + UPPERLIMITVALID),
                  i_ConstraintSense = LOWERLIMITVALID - UPPERLIMITVALID ) %>%
        gather(RHS, value, -PERIOD, -CONSTRAINTNAME) %>%
        gams_symbol('i_tradePeriodMNodeConstraintRHS','par')
    
####################################################################################################################
####################################################################################################################
####################################################################################################################

    # The following section creates all generic constraint data (sets and parameters)
    # (place holder only for now)
    
    # create i_genericConstraint
    i_genericconstraint <- data.frame(dim1 = factor()) %>%
        setattr('symName','i_genericConstraint')
    
    # create i_tradePeriodGenericConstraint
    i_periodgenericconstraint <- 
        data.frame(dim1 = factor(), dim2 = factor()) %>%
        setattr('symName','i_tradePeriodGenericConstraint')
    
    # create i_tradePeriodGenericEnergyOfferConstraintFactors
    i_genericenrgofferconstraintfactors <- 
        data.frame(dim1 = factor(), dim2 = factor(),
                   dim3 = factor(), value = numeric()) %>%
        setattr('symName','i_tradePeriodGenericEnergyOfferConstraintFactors')
    
    # create i_tradePeriodGenericReserveOfferConstraintFactors
    i_genericresvofferconstraintfactors <- 
        data.frame(dim1 = factor(), dim2 = factor(), dim3 = factor(),
                   dim4 = factor(), dim5 = factor(), value = numeric()) %>%
        setattr('symName','i_tradePeriodGenericReserveOfferConstraintFactors')
    
    # create i_tradePeriodGenericEnergyBidConstraintFactors
    i_genericenrgbidconstraintfactors <- 
        data.frame(dim1 = factor(), dim2 = factor(),
                   dim3 = factor(), value = numeric()) %>%
        setattr('symName','i_tradePeriodGenericEnergyBidConstraintFactors')
    
    # create i_tradePeriodGenericILReserveBidConstraintFactors
    i_genericilresvbidconstraintfactors <- 
        data.frame(dim1 = factor(), dim2 = factor(), dim3 = factor(),
                   dim4 = factor(), value = numeric()) %>%
        setattr('symName','i_tradePeriodGenericILReserveBidConstraintFactors')
    
    # create i_tradePeriodGenericBranchConstraintFactors
    i_genericbranchconstraintfactors <- 
        data.frame(dim1 = factor(), dim2 = factor(),
                   dim3 = factor(), value = numeric()) %>%
        setattr('symName','i_tradePeriodGenericBranchConstraintFactors')
    
    # create i_tradePeriodGenericConstraintRHS
    i_genericconstraintRHS <- 
        data.frame(dim1 = factor(), dim2 = factor(),
                   dim3 = factor(), value = numeric()) %>%
        setattr('symName','i_tradePeriodGenericConstraintRHS')
    
####################################################################################################################
####################################################################################################################
####################################################################################################################    
    
    # The following section creates all mixed constraint data (sets and parameters)
    # (place holder only for now)
    
    mssmod_mixedconstraint <- MSSMOD$MIXEDCONSTRAINTS %>%
        mutate_if(is.character, str_squish) %>%
        inner_join(dt_tp, by = "INTERVAL") %>%
        select(-c(INTERVAL, I, MSSDATA, MIXEDCONSTRAINTS),-starts_with('1')) %>%
        transmute(PERIOD, CONSTRAINTNAME = MIXEDCONSTRAINT, 
                  LOWERLIMITVALID, LOWERLIMIT, UPPERLIMITVALID, UPPERLIMIT)
    
    # create i_type1MixedConstraintRHS
    i_type1MixedConstraintRHS <- 
        data.frame(dim = factor(c('i_MixedConstraintSense',
                                  'i_MixedConstraintLimit1',
                                  'i_MixedConstraintLimit2'))) %>%
        setattr('symName','i_type1MixedConstraintRHS')
    
    i_type1MixedConstraint <- data.frame(dim = factor()) %>%
        setattr('symName','i_type1MixedConstraint')
    
    i_type1MixedConstraintReserveMap <- 
        data.frame(dim1=factor(),dim2=factor(),dim3=factor(),dim4=factor()) %>%
        setattr('symName','i_type1MixedConstraintReserveMap')
    
    i_tradePeriodType1MixedConstraint <- 
        data.frame(dim1=factor(),dim2=factor()) %>%
        setattr('symName','i_tradePeriodType1MixedConstraint')
    
    i_type1MixedConstraintBranchCondition <- 
        data.frame(dim1=factor(),dim2=factor()) %>%
        setattr('symName','i_type1MixedConstraintBranchCondition')
    
    i_type1MixedConstraintVarWeight <- data.frame(dim=factor(),value=numeric()) %>%
        setattr('symName','i_type1MixedConstraintVarWeight')
    
    i_type1MixedConstraintPurWeight <- 
        data.frame(dim1=factor(),dim2=factor(),value=numeric()) %>%
        setattr('symName','i_type1MixedConstraintPurWeight')
    
    i_type1MixedConstraintGenWeight <- 
        data.frame(dim1=factor(),dim2=factor(),value=numeric()) %>%
        setattr('symName','i_type1MixedConstraintGenWeight')
    
    i_type1MixedConstraintResWeight <- 
        data.frame(dim1=factor(),dim2=factor(),dim3=factor(),
                   dim4=factor(),value=numeric()) %>%
        setattr('symName','i_type1MixedConstraintResWeight')
    
    i_type1MixedConstraintHVDClineWeight <- 
        data.frame(dim1=factor(),dim2=factor(),value=numeric()) %>%
        setattr('symName','i_type1MixedConstraintHVDClineWeight')
    
    i_tradePeriodType1MixedConstraintRHSParameters <-
        data.frame(dim1=factor(),dim2=factor(),dim3=factor(),value=numeric()) %>%
        setattr('symName','i_tradePeriodType1MixedConstraintRHSParameters')
    
    i_type1MixedConstraintHVDClineLossWeight <-
        data.frame(dim1=factor(),dim2=factor(),value=numeric()) %>%
        setattr('symName','i_type1MixedConstraintHVDClineLossWeight')
    
    i_type1MixedConstraintHVDClineFixedLossWeight <-
        data.frame(dim1=factor(),dim2=factor(),value=numeric()) %>%
        setattr('symName','i_type1MixedConstraintHVDClineFixedLossWeight')
    
    i_type1MixedConstraintAClineWeight <- 
        data.frame(dim1=factor(),dim2=factor(),value=numeric()) %>%
        setattr('symName','i_type1MixedConstraintAClineWeight')
    
    i_type1MixedConstraintAClineLossWeight <-
        data.frame(dim1=factor(),dim2=factor(),value=numeric()) %>%
        setattr('symName','i_type1MixedConstraintAClineLossWeight')
    
    i_type1MixedConstraintAClineFixedLossWeight <-
        data.frame(dim1=factor(),dim2=factor(),value=numeric()) %>%
        setattr('symName','i_type1MixedConstraintAClineFixedLossWeight')
    
    i_type2MixedConstraint <- data.frame(dim = factor()) %>%
        setattr('symName','i_type2MixedConstraint')
    
    i_tradePeriodType2MixedConstraint <-
        data.frame(dim1=factor(),dim2=factor()) %>%
        setattr('symName','i_tradePeriodType2MixedConstraint')
    
    i_type2MixedConstraintLHSParameters <-
        data.frame(dim1=factor(),dim2=factor(),value=numeric()) %>%
        setattr('symName','i_type2MixedConstraintLHSParameters')
    
    i_tradePeriodType2MixedConstraintRHSParameters <-
        data.frame(dim1=factor(),dim2=factor(),dim3=factor(),value=numeric()) %>%
        setattr('symName','i_tradePeriodType2MixedConstraintRHSParameters')
    
####################################################################################################################
####################################################################################################################
####################################################################################################################    
    
    # The following section creates energy and reserve data (sets and parameters)
    # using information from daily_unit, period_bidsandoffers, period_traderperiods
    
    offerparameters <- period_traderperiods %>% 
        filter(!TRADETYPE %in% c('ENDL','ENNC','ENDF')) %>%
        full_join(daily_unitdata, by = c('PERIOD','PNODENAME'))
    
    if (casetype %in% c('FP','RTP')) {# for FP/RTP case, initial MW data comes from mssmkt_unitactualMW
        offerparameters <- offerparameters %>%
            full_join(mssmkt_unitactualMW, by = c('PERIOD','PNODENAME')) %>%
            rename(INITIALMW = ACTUALMW) %>%
            filter(!(is.na(MWMAX)) | (INITIALMW != 0)) %>% distinct()
        
    } else {# for other cases, initial MW data comes from mssmkt_unitinitialMW
        offerparameters <- offerparameters %>%
            full_join(mssmkt_unitinitialMW, by = c('PERIOD','PNODENAME')) %>%
            filter(!(is.na(MWMAX)) | (INITIALMW != 0)) %>% distinct()
    }
    
    # create i_tradeBlock set
    i_tradeBlock <- data.frame(paste0('t',(1:20))) %>% gams_symbol('i_tradeBlock')
    
    # create i_Trader set
    i_Trader <- select(period_traderperiods, TRADERID) %>% distinct() %>% gams_symbol('i_Trader')
    
    # create i_Offer set
    i_Offer <- select(offerparameters, PNODENAME) %>% distinct() %>% gams_symbol('i_Offer')
    
    # create i_OfferParam set
    if ('ISPRICERESPONSIVEIG' %in% colnames(offerparameters)) {                     # adding two new offer parameters for wind offer
        i_offerParam <- 
            data.frame(dim = c('i_InitialMW','i_RampUpRate','i_RampDnRate',
                               'i_ReserveGenerationMaximum','i_WindOffer',
                               'i_FKBandMW','i_IsPriceResponse','i_PotentialMW')
            ) %>% gams_symbol('i_offerParam')
    } else {
        i_offerParam <- 
            data.frame(dim = c('i_InitialMW','i_RampUpRate','i_RampDnRate',
                               'i_ReserveGenerationMaximum','i_WindOffer',
                               'i_FKBandMW')) %>% gams_symbol('i_offerParam')
    }
    
    # create i_EnergyOfferComponent set
    i_energyOfferComponent <- 
        data.frame(dim = c('i_GenerationMWOffer','i_GenerationMWOfferPrice')) %>% 
        gams_symbol('i_EnergyOfferComponent')
    
    # create i_PLSROfferComponent set
    i_PLSRofferComponent <- 
        data.frame(dim = c('i_PLSROfferMax','i_PLSROfferPrice','i_PLSRofferPercentage')) %>% 
        gams_symbol('i_PLSROfferComponent')
    
    # create i_TWDROfferComponent set
    i_TWDRoffercomponent <- 
        data.frame(dim = c('i_TWDROfferMax','i_TWDROfferPrice')) %>% 
        gams_symbol('i_TWDRofferComponent')
    
    # create i_ILROfferComponent set
    i_ILRofferComponent <- 
        data.frame(dim = c('i_ILROfferMax','i_ILROfferPrice')) %>% 
        gams_symbol('i_ILRofferComponent')
    
    # create i_tradePeriodOfferTrader set
    i_tradePeriodOfferTrader <- offerparameters %>% filter(!is.na(TRADERID)) %>%
        transmute(PERIOD, PNODENAME, TRADERID) %>% distinct() %>%
        gams_symbol('i_tradePeriodOfferTrader')
    
    # create i_tradePeriodOfferNode set
    i_tradePeriodOfferNode <- merge(i_tradePeriod, i_Offer, all = TRUE) %>%
        distinct() %>% transmute(PERIOD, OFFER = PNODENAME, NODE = PNODENAME) %>% 
        gams_symbol('i_tradePeriodOfferNode')
    
    # create i_tradePeriodOfferParameter
    df <- offerparameters %>% 
        transmute(PERIOD, PNODENAME, i_FKBandMW = FKBANDMW, i_InitialMW = INITIALMW,
                  i_RampDnRate = RAMPDNRATEMX/60, i_RampUpRate = RAMPUPRATEMX/60,   # Currently we convert ramp rates to MW/minutes
                  i_ReserveGenerationMaximum = MWMAX,
                  i_WindOffer = ifelse(is.na(ISIG),0,as.numeric(ISIG)))
    
    if ('ISPRICERESPONSIVEIG' %in% colnames(offerparameters)) {                     # Adding data for two new offer parameters for wind offer
        df$i_IsPriceResponse <- as.numeric(offerparameters$ISPRICERESPONSIVEIG)
        df$i_PotentialMW <-  as.numeric(offerparameters$IGPOTENTIALMW)
        df$i_ISIG <- as.numeric(offerparameters$ISIG)
    }

    if (casetype == 'FP') {                                                         # Ignore non-price-responsive intermittent generation for FP case
        if (!('ISPRICERESPONSIVEIG' %in% colnames(offerparameters))) {
            df <- df %>% filter(i_WindOffer == 0)
        } else {
            df <- df %>% filter(i_ISIG==0 | i_IsPriceResponse==1) %>% select(-i_ISIG)
        }
    }
    
    if (casetype == 'RTD') {                                                         # For price responsive Intermittent Generation (IG) the 5-minute - Real Time Pricing project
        x <- filter(period_spdparameter, NAME == 'IGIncreaseLimitForRTD')            # ramp-up is capped using the IGIncreaseLimitForRTD parameter 
        x <- ifelse(is.na(x$VALUE[1]), 9999, x$VALUE[1]/5)                           # which represents the maximum MW increase over 5-minutes
        df <- df %>%
            mutate(IGIncreasedLimit = ifelse(i_IsPriceResponse==1, x, 9999)) %>%
            mutate(i_RampUpRate = ifelse(IGIncreasedLimit < i_RampUpRate,
                                         IGIncreasedLimit, i_RampUpRate )
                  ) %>% select(-IGIncreasedLimit)
    }
    
    df <- df %>%                                                                    # Only valid energy offers are included 
        filter(i_ReserveGenerationMaximum + i_RampUpRate + i_RampDnRate > 0 |
                   !is.na(i_InitialMW)) 
    
    i_tradePeriodOfferParameter <- gather(df, param, value,-PERIOD,-PNODENAME) %>%
        filter(value != 0) %>% distinct %>% gams_symbol('i_tradePeriodOfferParameter','par')
    
    # Zero offer price for energy is changed to $0.001 for all schedules except RTP and FP. This is since 1998.
    # Zero offer price for reserve is also changed to $0.001 for all schedules except RTP and FP. This is since reserve sharing in 2016.
    if (casetype %in% c('RTD','NRSS','NRSL','PRSS','PRSL','WDS')) {
        period_bidsandoffers <- period_bidsandoffers %>%
            mutate(TRADERBLOCKPRICE = ifelse(TRADERBLOCKPRICE==0 & TRADERBLOCKLIMIT > 0,
                                             0.001, TRADERBLOCKPRICE))
    }
    
    # create i_tradePeriodEnergyOffer
    i_tradePeriodEnergyOffer <- period_bidsandoffers %>% 
        filter(TRADETYPE == 'ENOF') %>% 
        transmute(PERIOD, PNODENAME, BLOCK = paste0('t',TRADERBLOCKTRANCHE), 
                  i_GenerationMWOffer = TRADERBLOCKLIMIT,
                  i_GenerationMWOfferPrice = TRADERBLOCKPRICE) %>%
        gather(param, value, -PERIOD, -PNODENAME, -BLOCK) %>%
        filter(value != 0) %>% distinct %>% 
        gams_symbol('i_tradePeriodEnergyOffer','par')
    
    # create i_tradePeriodSustainedPLSRoffer
    i_tradePeriodSustainedPLSRoffer <- period_bidsandoffers %>% 
        filter(TRADETYPE == 'PLRO', SIXSEC == 0) %>% 
        transmute(PERIOD, PNODENAME, BLOCK = paste0('t',TRADERBLOCKTRANCHE), 
                  i_PLSROfferMax = TRADERBLOCKLIMIT,
                  i_PLSROfferPrice = TRADERBLOCKPRICE,
                  i_PLSRofferPercentage = RESERVEPERCENT) %>%
        gather(param, value, -PERIOD, -PNODENAME, -BLOCK) %>%
        filter(value != 0) %>% distinct() %>%
        gams_symbol('i_tradePeriodSustainedPLSRoffer','par')
    
    # create i_tradePeriodFastPLSRoffer
    i_tradePeriodFastPLSRoffer <- period_bidsandoffers %>% 
        filter(TRADETYPE == 'PLRO', SIXSEC == 1) %>% 
        transmute(PERIOD, PNODENAME, BLOCK = paste0('t',TRADERBLOCKTRANCHE), 
                  i_PLSROfferMax = TRADERBLOCKLIMIT,
                  i_PLSROfferPrice = TRADERBLOCKPRICE,
                  i_PLSRofferPercentage = RESERVEPERCENT) %>%
        gather(param, value, -PERIOD, -PNODENAME, -BLOCK) %>%
        filter(value != 0) %>% distinct() %>%
        gams_symbol('i_tradePeriodFastPLSRoffer','par')
    
    # create i_tradePeriodSustainedTWDRoffer
    i_tradePeriodSustainedTWDRoffer <- period_bidsandoffers %>% 
        filter(TRADETYPE == 'TWRO', SIXSEC == 0) %>% 
        transmute(PERIOD, PNODENAME, BLOCK = paste0('t',TRADERBLOCKTRANCHE), 
                  i_TWDROfferMax = TRADERBLOCKLIMIT,
                  i_TWDROfferPrice = TRADERBLOCKPRICE) %>%
        gather(param, value, -PERIOD, -PNODENAME, -BLOCK) %>%
        filter(value != 0) %>% distinct() %>%
        gams_symbol('i_tradePeriodSustainedTWDRoffer','par')
    
    # create i_tradePeriodFastTWDRoffer
    i_tradePeriodFastTWDRoffer <- period_bidsandoffers %>% 
        filter(TRADETYPE == 'TWRO', SIXSEC == 1) %>% 
        transmute(PERIOD, PNODENAME, BLOCK  = paste0('t',TRADERBLOCKTRANCHE), 
                  i_TWDROfferMax = TRADERBLOCKLIMIT,
                  i_TWDROfferPrice = TRADERBLOCKPRICE) %>%
        gather(param, value, -PERIOD, -PNODENAME, -BLOCK) %>%
        filter(value != 0) %>% distinct() %>%
        gams_symbol('i_tradePeriodFastTWDRoffer','par')
    
    # create i_tradePeriodSustainedILRoffer
    i_tradePeriodSustainedILRoffer <- period_bidsandoffers %>% 
        filter(TRADETYPE == 'ILRO', SIXSEC == 0) %>% 
        transmute(PERIOD, PNODENAME, BLOCK = paste0('t',TRADERBLOCKTRANCHE), 
                  i_ILROfferMax = TRADERBLOCKLIMIT,
                  i_ILROfferPrice = TRADERBLOCKPRICE) %>%
        gather(param, value, -PERIOD, -PNODENAME, -BLOCK) %>%
        filter(value != 0) %>% distinct() %>%
        gams_symbol('i_tradePeriodSustainedILRoffer','par')
    
    # create i_tradePeriodFastILRoffer
    i_tradePeriodFastILRoffer <- period_bidsandoffers %>% 
        filter(TRADETYPE == 'ILRO', SIXSEC == 1) %>% 
        transmute(PERIOD, PNODENAME, BLOCK = paste0('t',TRADERBLOCKTRANCHE), 
                  i_ILROfferMax = TRADERBLOCKLIMIT,
                  i_ILROfferPrice = TRADERBLOCKPRICE) %>%
        gather(param, value, -PERIOD, -PNODENAME, -BLOCK) %>%
        filter(value != 0) %>% distinct() %>%
        gams_symbol('i_tradePeriodFastILRoffer','par')
    
    # create i_tradePeriodPrimarySecondaryOffer set
    df <- offerparameters %>% filter(ISPRIMARYNODE==0) %>% select(PERIOD,PNODENAME)
    
    df <- daily_pnode %>% filter(PNODETYPE =='I') %>% 
        select(PERIOD,PNODENAME,ENODENAME) %>% 
        inner_join(df, by = c('PERIOD','PNODENAME')) %>%
        rename(SECONDARYOFFER = PNODENAME)
    
    df <- daily_pnode %>% filter(PNODETYPE =='I') %>%
        transmute(PERIOD, PRIMARYOFFER = PNODENAME, ENODENAME) %>% 
        inner_join(df, by = c('PERIOD','ENODENAME')) %>% select(-ENODENAME) %>%
        filter(PRIMARYOFFER != SECONDARYOFFER) %>% distinct()
    
    i_tradePeriodPrimarySecondaryOffer <- df %>%
        gams_symbol('i_tradePeriodPrimarySecondaryOffer')
    
####################################################################################################################
####################################################################################################################
####################################################################################################################       
    
    # The following section creates bid and demand data (sets and parameters) 
    # using information from daily_unit, period_bidsandoffers, period_traderperiods 
 
    # In preparing for Real Time Pricing project, demand data is now in PNODELOAD table in MSS*.PERIOD
    if ("PNODELOAD" %in% names(mssDataList$PERIOD)) {                                
        nodedemand <- period_pnodeload %>%                                          # Getting node demand for the next step
          left_join(mssmod_pnodeovrd, by = c('PERIOD','PNODENAME'))  
      
        i_tradePeriodInputInitialLoad <- nodedemand %>% 
            select(PERIOD,PNODENAME,ACTUALLOAD) %>% 
            gams_symbol('i_tradePeriodInputInitialLoad','par')
      
        i_tradePeriodLoadIsOverride <- nodedemand %>% 
            select(PERIOD,PNODENAME,ISOVERRIDE) %>% 
            gams_symbol('i_tradePeriodLoadIsOverride','par')
      
        i_tradePeriodLoadIsBad <- nodedemand %>% 
            select(PERIOD,PNODENAME,ISBAD) %>% 
            gams_symbol('i_tradePeriodLoadIsBad','par')
      
        i_tradePeriodLoadIsNCL <- nodedemand %>% 
            select(PERIOD,PNODENAME,ISNCL) %>% 
            gams_symbol('i_tradePeriodLoadIsNCL','par')
      
        i_tradePeriodConformingFactor <- nodedemand %>% 
            select(PERIOD,PNODENAME,CONFORMINGFACTOR) %>% 
            gams_symbol('i_tradePeriodConformingFactor','par')
        
        i_tradePeriodNonConformingLoad <- nodedemand %>% 
            select(PERIOD,PNODENAME,NONCONFORMINGLOAD) %>% 
            gams_symbol('i_tradePeriodNonConformingLoad','par')
            
        i_tradePeriodMaxLoad <- nodedemand %>% 
            transmute(PERIOD,PNODENAME,LOADMAXMW = ifelse(is.na(LOADMAXMW),10000,LOADMAXMW)) %>% 
            gams_symbol('i_tradePeriodMaxLoad','par')
      
        if (casetype %in% c('FP', 'RTP')) {
            nodedemand$DEMANDMW = nodedemand$ACTUALLOAD
        } else if (grepl('PRS',casetype)) { 
            nodedemand$DEMANDMW = nodedemand$CONFORMINGFORECAST
        } else if (grepl('NRS',casetype)) {
            nodedemand <- nodedemand %>% 
                mutate(DEMANDMW = ifelse(ISNCL==1,NONCONFORMINGLOAD,CONFORMINGFORECAST))
        } else if (casetype == 'RTD') { # RTD demand will be calculated on the fly          
            nodedemand$DEMANDMW <- 0          
        } else { # place holder for WDS
            nodedemand$DEMANDMW = nodedemand$CONFORMINGFORECAST + nodedemand$NONCONFORMINGLOAD
        }
       
        nodedemand <- transmute(nodedemand, PERIOD, PNODE = PNODENAME, 
                                demand = ifelse(is.na(LOADMAXMW),DEMANDMW, 
                                                ifelse(LOADMAXMW < DEMANDMW,LOADMAXMW,DEMANDMW)))
                   
        
    } else { # Use data from PNODEINT (as of "old days")
        nodedemand <- period_pnodeint %>%                                           # Getting node demand for the next step
            left_join(mssmod_pnodeovrd, by = c('PERIOD','PNODENAME')) 
      
        if (casetype == 'FP') {
            nodedemand$DEMANDMW = nodedemand$MV90LOAD
        } else if (casetype == 'RTP') { 
            nodedemand$DEMANDMW = nodedemand$SDVLOAD
        } else if (grepl('PRS',casetype)) { 
            nodedemand$DEMANDMW = nodedemand$ESTIMATEDLOAD
        } else if (grepl('NRS',casetype)) {
            nodedemand$DEMANDMW = nodedemand$ESTIMATEDLOAD + nodedemand$NONCONFORMINGLOAD
        } else if (grepl('WDS',casetype)) { # place holder for WDS
            nodedemand$DEMANDMW = nodedemand$ESTIMATEDLOAD + nodedemand$NONCONFORMINGLOAD
        } else { # if (casetype == 'RTD')    
            nodedemand <- nodedemand %>%
                mutate(DEMANDMW = NONCONFORMINGLOAD + LOADPARTICIPATIONFACTOR)        
        }
      
        nodedemand <- transmute(nodedemand, PERIOD, PNODE = PNODENAME, 
                                demand = ifelse(is.na(LOADMAXMW),DEMANDMW, 
                                                ifelse(LOADMAXMW < DEMANDMW,LOADMAXMW,DEMANDMW)))  
    }   

    
    bidparameters <- period_traderperiods %>% 
        filter(TRADETYPE %in% c('ENDL','ENNC','ENDF')) %>%
        mutate(BID = TRADERPERIODALTKEY) %>%                                        # Code to create unique bid using pnode, traderid and traderblcokaltkey
        mutate(BID = substr(BID, nchar(BID) - 1, nchar(BID))) %>%
        mutate(BID = ifelse(TRADETYPE == 'ENDL', PNODENAME,
                            paste0(PNODENAME,'_',TRADERID,BID)))
    if (!(grepl('PRS',casetype))){                                                  # Tuong added code for flexibility
        bidparameters <- bidparameters %>% filter(TRADETYPE == 'ENDL')
    }
    
    # create i_bid
    i_bid <- bidparameters %>% select(BID) %>% distinct() %>% gams_symbol('i_bid')  
    
    # create i_energyBidComponent
    i_energyBidComponent <- data.frame(dim = c('i_BidMW','i_BidPrice')) %>% 
        gams_symbol('i_energyBidComponent')
    
    # create i_ILRbidComponent
    i_ILRbidComponent <- data.frame(dim=c('i_ILRBidMax','i_ILRBidPrice')) %>% 
        gams_symbol('i_ILRbidComponent')
    
    # create i_tradePeriodBidTrader
    i_tradePeriodBidTrader <- bidparameters %>% 
        transmute(PERIOD, BID, TRADERID) %>% distinct() %>%
        gams_symbol('i_tradePeriodBidTrader')
    
    # create i_tradePeriodBidNode
    i_tradePeriodBidNode <- bidparameters %>%
        transmute(PERIOD, BID, NODE = PNODENAME) %>% distinct() %>%
        gams_symbol('i_tradePeriodBidNode')
    
    # Get energy bid info
    energyBid <- period_bidsandoffers %>% 
        filter(TRADETYPE %in% c('ENDL','ENNC','ENDF')) %>%
        merge(nodedemand, by.x = c('PERIOD','PNODENAME'),
              by.y = c('PERIOD','PNODE'), all.x = TRUE) %>%
        mutate(TRADERBLOCKLIMIT = ifelse(TRADETYPE == 'ENDF' & demand == 0,         # Different bid only valid if demand <> 0
                                         0,TRADERBLOCKLIMIT)) %>%
        mutate(BID = TRADERBLOCKALTKEY) %>%                                         # Code to create unique bid using pnode, traderid and traderblcokaltkey
        mutate(BID = substr(BID, nchar(BID) - 1, nchar(BID))) %>%
        mutate(BID = ifelse(TRADETYPE == 'ENDL', PNODENAME,
                            paste0(PNODENAME,'_',TRADERID,BID))) %>%
        transmute(PERIOD , BID, TRADETYPE, BLOCK = paste0('t',TRADERBLOCKTRANCHE), 
                  i_BidMW = TRADERBLOCKLIMIT, i_BidPrice = TRADERBLOCKPRICE,
                  dispatchable = DISPATCHABLE)
    
    # create i_tradePeriodEnergyBid
    if (grepl('PRS',casetype)){                                                     # In PRS schedule, all bids are dispatchable.
        energyBid <- energyBid %>% mutate(dispatchable = 1) 
    } else {
        energyBid <- energyBid %>% filter(TRADETYPE == 'ENDL')
    }
    i_tradePeriodEnergyBid <- energyBid %>% select(-dispatchable,-TRADETYPE) %>%
        gather(param, value, -PERIOD, -BID, -BLOCK) %>%
        filter(value != 0) %>% distinct() %>% 
        gams_symbol('i_tradePeriodEnergyBid','par')
    
    # create i_tradePeriodDispatchableBid
    i_tradePeriodDispatchableBid <- energyBid %>% filter(dispatchable == 1) %>%
        select(PERIOD,BID) %>% distinct() %>%
        gams_symbol('i_tradePeriodDispatchableBid')
    
    # create i_tradePeriodSustainedILRbid (place holder)
    i_tradePeriodSustainedILRbid <- 
        data.frame(dim1 = factor(), dim2 = factor(), dim3 = factor(),
                   dim4 = factor(), value = numeric()) %>%
        gams_symbol('i_tradePeriodSustainedILRbid','par')
    
    # create i_tradePeriodSustainedILRbid (place holder)
    i_tradePeriodFastILRbid <- 
        data.frame(dim1 = factor(), dim2 = factor(), dim3 = factor(),
                   dim4 = factor(), value = numeric()) %>%
        gams_symbol('i_tradePeriodFastILRbid','par')
    
    # create i_tradePeriodNodedemand
    if (casetype %in% c('FP','NRSS','NRSL','RTP')){                                  # In FP and NRS schedule, remove demand if ENDL is dispatchable.
        df <- energyBid %>% 
            filter(TRADETYPE %in% c('ENDL'), dispatchable == 1) %>%                 
            transmute(PERIOD, PNODE = BID, dispatchable) %>% unique() %>%
            merge(nodedemand, by = c('PERIOD','PNODE'),  all.y = TRUE) %>%
            mutate(demand = ifelse(is.na(dispatchable),demand, 0)) %>%
            select(-dispatchable)
        nodedemand <- df
    } 
    i_tradeperiodnodedemand <- nodedemand %>% filter(demand != 0) %>%
        gams_symbol('i_tradePeriodNodeDemand','par')
    
####################################################################################################################
####################################################################################################################
####################################################################################################################       
    
    # The following section creates reserve/RISK data (sets and parameters)
    # using information from 
    
    # create i_reserveClass set
    i_reserveClass <- data.frame(dim = c('FIR','SIR')) %>% 
        gams_symbol('i_reserveClass')
    
    # create i_reserveType set
    i_reserveType <- data.frame(dim = c('PLSR','TWDR','ILR')) %>%
        gams_symbol('i_reserveType')
    
    # create i_riskClass set
    i_riskClass <- 
        data.frame(dim = c('genRisk','DCCE','DCECE','manual', 'genRisk_ECE',
                           'manual_ECE','HVDCsecRisk_CE','HVDCsecRisk_ECE')) %>% 
        gams_symbol('i_riskClass')
    
    # create i_riskParameter set
    i_riskParameter <- 
        data.frame(dim = c('i_FreeReserve','i_RiskAdjustmentFactor',
                           'i_HVDCPoleRampUp')) %>% gams_symbol('i_riskParameter')    
    
    # create i_tradePeriodRiskGenerator set
    i_tradePeriodRiskGenerator <- daily_unitdata %>% filter(SETRISK == 1) %>%
        transmute(PERIOD, OFFER = as.factor(PNODENAME)) %>% distinct() %>%
        gams_symbol('i_tradePeriodRiskGenerator')    
    
    # create i_tradePeriodRiskParameter
    # Getting i_FreeReserve for FIR
    df <- period_riskparamschedule %>%                      
        transmute(PERIOD, ISLAND, genRisk = NFRSIXACCE, manual = NFRSIXACCE,
                  DCCE = NFRSIXCE, DCECE = NFRSIXECE, genRisk_ECE = NFRSIXACECE,
                  manual_ECE = NFRSIXACECE, HVDCsecRisk_CE = NFRSIXACCE,
                  HVDCsecRisk_ECE = NFRSIXACECE) %>%
        gather(riskclass, value, -PERIOD, -ISLAND) %>% 
        mutate(reserveclass = 'FIR', riskparam = 'i_FreeReserve')
    # Adding i_FreeReserve for SIR
    df <- period_riskparamschedule %>%                      
        transmute(PERIOD, ISLAND, genRisk = NFRSIXTYACCE, manual = NFRSIXTYACCE,
                  DCCE = NFRSIXTYCE, DCECE = NFRSIXTYECE, 
                  genRisk_ECE = NFRSIXTYACECE, manual_ECE = NFRSIXTYACECE,
                  HVDCsecRisk_CE = NFRSIXTYACCE, HVDCsecRisk_ECE = NFRSIXTYACECE)%>%
        gather(riskclass, value, -PERIOD, -ISLAND) %>% 
        mutate(reserveclass = 'SIR', riskparam = 'i_FreeReserve') %>%
        rbind(df)
    # Adding i_RiskAdjustmentFactor for FIR
    df <- period_riskparamschedule %>%                      
        transmute(PERIOD, ISLAND, genRisk = RISKFACTORSIXSEC, 
                  manual = RISKFACTORSIXSEC, DCCE = RISKFACTORSIXSEC, 
                  DCECE = RISKFACTORSIXSECECE, genRisk_ECE = RISKFACTORSIXSECECE,
                  manual_ECE = RISKFACTORSIXSECECE,
                  HVDCsecRisk_CE = RISKFACTORSIXSEC,
                  HVDCsecRisk_ECE = RISKFACTORSIXSECECE) %>%
        gather(riskclass, value, -PERIOD, -ISLAND) %>% 
        mutate(reserveclass = 'FIR', riskparam = 'i_RiskAdjustmentFactor') %>%
        rbind(df)
    # Adding i_RiskAdjustmentFactor for SIR
    df <- period_riskparamschedule %>%                      
        transmute(PERIOD, ISLAND, genRisk = RISKFACTORSIXTYSEC, 
                  manual = RISKFACTORSIXTYSEC, DCCE = RISKFACTORSIXTYSEC, 
                  DCECE = RISKFACTORSIXTYSECECE, 
                  genRisk_ECE = RISKFACTORSIXTYSECECE,
                  manual_ECE = RISKFACTORSIXTYSECECE,
                  HVDCsecRisk_CE = RISKFACTORSIXTYSEC,
                  HVDCsecRisk_ECE = RISKFACTORSIXTYSECECE) %>%
        gather(riskclass, value, -PERIOD, -ISLAND) %>% 
        mutate(reserveclass = 'SIR', riskparam = 'i_RiskAdjustmentFactor') %>%
        rbind(df)
    # Adding i_HVDCPoleRampUp for FIR
    df <- period_riskparamschedule %>%                      
        transmute(PERIOD, ISLAND, DCCE = HVDCRISKSUBTRACTORMAX) %>%
        gather(riskclass, value, -PERIOD, -ISLAND) %>% 
        mutate(reserveclass = 'FIR', riskparam = 'i_HVDCPoleRampUp') %>%
        rbind(df)
    # Adding i_HVDCPoleRampUp for SIR
    df <- period_riskparamschedule %>%                      
        transmute(PERIOD, ISLAND, DCCE = HVDCRISKSUBTRACTORMAX) %>%
        gather(riskclass, value, -PERIOD, -ISLAND) %>% 
        mutate(reserveclass = 'SIR', riskparam = 'i_HVDCPoleRampUp') %>%
        rbind(df)
    # Finally rearrange the columns and set the symName
    i_tradePeriodRiskParameter <- df %>%                    
        select(PERIOD,ISLAND,reserveclass,riskclass,riskparam,value) %>%
        gams_symbol('i_tradePeriodRiskParameter','par')  
    
    # create i_tradePeriodManualRisk
    i_tradePeriodManualRisk <- period_riskparamschedule %>%
        transmute(PERIOD, ISLAND, 
                  FIR = MANUALLYENTEREDMIN, SIR = MANUALLYENTEREDMIN) %>%
        gather(reserveclass, value, -PERIOD, -ISLAND) %>% 
        gams_symbol('i_tradePeriodManualRisk','par')  
    
    # create i_tradePeriodManualRisk_ECE
    i_tradePeriodManualRisk_ECE <- period_riskparamschedule %>%
        transmute(PERIOD, ISLAND, FIR = MANUALMINACECE, SIR = MANUALMINACECE) %>%
        gather(reserveclass, value, -PERIOD, -ISLAND) %>%
        gams_symbol('i_tradePeriodManualRisk_ECE','par')
    
    # create i_tradePeriodHVDCSecRiskEnabled
    i_tradePeriodHVDCSecRiskEnabled <- period_riskparamschedule %>%
        transmute(PERIOD, ISLAND, HVDCsecRisk_CE = HVDCSECRISKENABLEDACCE,
                  HVDCsecRisk_ECE = HVDCSECRISKENABLEDACECE) %>%
        gather(riskclass, value, -PERIOD, -ISLAND) %>% 
        gams_symbol('i_tradePeriodHVDCSecRiskEnabled','par')
    
    # create i_tradePeriodHVDCSecRiskSubtractor
    i_tradePeriodHVDCSecRiskSubtractor <- period_riskparamschedule %>%
        transmute(PERIOD, ISLAND, HVDCSECRISKSUBTRACTOR) %>%
        gams_symbol('i_tradePeriodHVDCSecRiskSubtractor','par')
    
    # create i_tradePeriodReserveClassGenerationMaximum (need to double check with SO)
    i_tradePeriodReserveClassGenerationMaximum <- offerparameters %>%
        filter(TRADETYPE == 'ENOF') %>%
        transmute(PERIOD, PNODENAME,
                  FIR = ifelse(MAXSIXSEC == 1, 0, MAXSIXSEC), 
                  SIR = ifelse(MAXSIXTYSEC == 1, 0, MAXSIXTYSEC) ) %>%
        gather(reserveclass, value, -PERIOD, -PNODENAME) %>%
        gams_symbol('i_tradePeriodReserveClassGenerationMaximum','par')
    
####################################################################################################################
####################################################################################################################
####################################################################################################################       
    
    # The following section creates Scarcity and Virtual data (sets and parameters)
    # using information from period_scarcityarea 
    
    # create i_tradePeriodScarcitySituationExists(tp,sarea)  
    i_tradePeriodScarcitySituationExists <- period_scarcityarea %>%
        transmute(PERIOD, SCARCITYAREA, flag = as.numeric(SCARCITYACTIVEFLAG)) %>%
        gams_symbol('i_tradePeriodScarcitySituationExists','par')
    
    # create i_tradePeriodGWAPFloor(tp,sarea)  
    i_tradePeriodGWAPFloor <- period_scarcityarea %>%
        transmute(PERIOD, SCARCITYAREA, SCALINGFLOOR) %>%
        gams_symbol('i_tradePeriodGWAPFloor','par')
    
    # create i_tradePeriodGWAPCeiling(tp,sarea)  
    i_tradePeriodGWAPCeiling <- period_scarcityarea %>%
        transmute(PERIOD, SCARCITYAREA, SCALINGCEILING) %>%
        gams_symbol('i_tradePeriodGWAPCeiling','par')
    
    # create i_tradePeriodGWAPPastDaysAvg(tp,ild) 
    i_tradePeriodGWAPPastDaysAvg <- period_scarcityisland %>%
        transmute(PERIOD, ISLAND, GWAPPASTDAYSAVG) %>%
        gams_symbol('i_tradePeriodGWAPPastDaysAvg','par')
    
    # create i_tradePeriodGWAPCountForAvg(tp,ild)
    i_tradePeriodGWAPCountForAvg <- period_scarcityisland %>%
        transmute(PERIOD, ISLAND, GWAPCOUNTFORAVG) %>%
        gams_symbol('i_tradePeriodGWAPCountForAvg','par')
    
    # create i_tradePeriodGWAPThreshold(tp,ild)
    i_tradePeriodGWAPThreshold <- period_scarcityisland %>%
        transmute(PERIOD, ISLAND, GWAPTHRESHOLD) %>%
        gams_symbol('i_tradePeriodGWAPThreshold','par')
    
    # create i_tradePeriodVROfferMax(tp,ild,resC)
    i_tradePeriodVROfferMax <- period_virtualreserve %>%
        transmute(PERIOD, ISLAND, CLASS = ifelse(SIXSEC==1, 'FIR','SIR'), LIMIT) %>%
        gams_symbol('i_tradePeriodVROfferMax','par')
    
    # create i_tradePeriodVROfferPrice(tp,ild,resC)
    i_tradePeriodVROfferPrice <- period_virtualreserve %>%
        transmute(PERIOD, ISLAND, CLASS = ifelse(SIXSEC==1, 'FIR','SIR'), PRICE) %>%
        gams_symbol('i_tradePeriodVROfferPrice','par')
    
####################################################################################################################
####################################################################################################################
####################################################################################################################    
    
    # The following section creates reserve sharing data (sets and parameters)
    # using information from period_reservesharing, period_riskparamschedule 
    
    # create i_tradePeriodFKCEnabled(tp) -- not used at all in vSPD
    FKCenabled  <- period_reservesharing %>% transmute(PERIOD, FKCENABLED) %>%
        gams_symbol('i_tradePeriodFKCenabled','par')
    
    # create i_tradePeriodFKCEnabled(tp) -- not used at all in vSPD
    roundpwrstatus <- period_reservesharing %>% transmute(PERIOD, RPSTATUS) %>%
        gams_symbol('i_tradePeriodRPStatus','par')
    
    # create i_tradePeriodReserveRoundPower 
    reserveRoundPower <- period_reservesharing %>%
        transmute(PERIOD, FIR = 1- FIRROUNDPOWERDISABLED, 
                  SIR = 1- SIRROUNDPOWERDISABLED) %>% 
        gather(CLASS, value, -PERIOD) %>%
        gams_symbol('i_tradePeriodReserveRoundPower','par')
    
    # create i_tradePeriodReserveSharing
    reserveShareEnabled <- period_reservesharing %>%
        transmute(PERIOD, FIR = FIRRESERVESHARINGENABLED,
                  SIR = SIRRESERVESHARINGENABLED) %>% 
        gather(CLASS, value, -PERIOD) %>%
        gams_symbol('i_tradePeriodReserveSharing','par')
    
    # create i_tradePeriodModulationRisk
    modulationRiskClass <- period_reservesharing %>%
        transmute(PERIOD, DCCE = MRCE, DCECE = MRECE) %>% 
        gather(CLASS, value, -PERIOD) %>% 
        gams_symbol('i_tradePeriodModulationRisk','par')
    
    # create i_tradePeriodRoundPower2Mono
    rp2monolevel <- period_reservesharing %>%
        transmute(PERIOD, RPTOMONOPOLETRANSITION) %>% 
        gams_symbol('i_tradePeriodRoundPower2Mono','par')
    
    # create i_tradePeriodRoundPower2Mono
    bipole2monolevel <- period_reservesharing %>%
        transmute(PERIOD, BIPOLETOMONOPOLETRANSITION) %>% 
        gams_symbol('i_tradePeriodBipole2Mono','par')
    
    # create i_tradePeriodReserveSharingPoleMin
    monopoleMin <- period_reservesharing %>%
        transmute(PERIOD, RESERVESHARINGPOLEMIN) %>% 
        gams_symbol('i_tradePeriodReserveSharingPoleMin','par')
    
    # create i_tradePeriodHVDCcontrolBand(tp,rd)
    HVDCControlBand <- period_reservesharing %>%
        transmute(PERIOD, Forward = HVDCCONTROLBANDFORWARD,
                  Backward = HVDCCONTROLBANDREVERSE) %>% 
        gather(rd, value, -PERIOD) %>%
        gams_symbol('i_tradePeriodHVDCcontrolBand','par') 
    
    # create i_tradePeriodHVDCCableDischarge(tp) -- only used for RTD/RTP
    HVDCCableDischarge <- period_reservesharing %>%
        transmute(PERIOD, BPMPCABLEDISCHARGESTATUS) %>% 
        gams_symbol('i_tradePeriodHVDCCableDischarge','par')
    
    # create i_tradePeriodHVDClossScalingFactor(tp)
    HVDClossScalingFactor <- period_reservesharing %>%
        transmute(PERIOD, LOSSSCALINGFACTOR) %>% 
        gams_symbol('i_tradePeriodHVDClossScalingFactor','par')
    
    # create i_tradePeriodSharedNFRfactor(tp)
    sharedNFRfactor <- period_reservesharing %>%
        transmute(PERIOD, SHAREDNFRFACTOR) %>% 
        gams_symbol('i_tradePeriodSharedNFRfactor','par')
    
    # create i_tradePeriodReserveEffectiveFactor(tp,ild,resC,riskC)  - to be continued
    effectiveFactor <- period_riskparamschedule %>%
        transmute(PERIOD, ISLAND, 
                  FIR_CE = FIREFFECTIVENESSFACTORCE,
                  FIR_ECE = FIREFFECTIVENESSFACTORECE,
                  SIR_CE = SIREFFECTIVENESSFACTORCE,
                  SIR_ECE = SIREFFECTIVENESSFACTORECE) %>% 
        gather(CLASS, FACTOR, -PERIOD, -ISLAND) %>%
        separate(col = CLASS,into = c('CLASS','RISK'),sep = '_') %>%
        spread(RISK,FACTOR) %>% 
        mutate(GENRISK = CE, GENRISK_ECE = ECE,Manual = CE, Manual_ECE = ECE) %>%
        select(-CE, -ECE) %>% 
        gather(RISK, FACTOR, -PERIOD, -ISLAND, -CLASS) %>%
        gams_symbol('i_tradePeriodReserveEffectiveFactor','par')
    
    # create i_tradePeriodSharedNFRLoadOffset(tp)
    sharedNFRLoadOffset <- period_riskparamschedule %>%
        transmute(PERIOD, ISLAND, SHAREDNFRLOADOFFSET) %>% 
        gams_symbol('i_tradePeriodSharedNFRLoadOffset','par')
    
    # create i_tradePeriodRMTreserveLimit(tp)
    RMTreserveLimit <- period_riskparamschedule %>%
        transmute(PERIOD, ISLAND, FIR = RMTRESLIMITTOFIR,SIR = RMTRESLIMITTOSIR) %>% 
        gather(CLASS, FACTOR, -PERIOD, -ISLAND) %>%
        gams_symbol('i_tradePeriodRMTreserveLimit','par')
    
    # create i_tradePeriodRampingConstraint(tp,brCstr) set
    rampingConstraint <- mssmod_branchconstraint %>%
        filter(HVDC_RAMP == 1) %>% select(PERIOD, BRANCHCONSTRAINT) %>%
        gams_symbol('i_tradePeriodRampingConstraint')
 
####################################################################################################################
####################################################################################################################
####################################################################################################################        
    
    # The following section creates group risk data (sets and parameters)
    # using information from offerparameters 
    
    # create i_tradePeriodRiskGroup set
    riskgroupoffer <- offerparameters %>%
        filter(TRADETYPE == 'ENOF') %>% 
        transmute(PERIOD, OFFER = PNODENAME,
                  GENRISK = ACRISKIDCE, GENRISK_ECE = ACRISKIDECE) %>%
        gather(RISK, GROUP, -PERIOD, -OFFER) %>% filter( GROUP != 0) %>%
        select(PERIOD,GROUP,OFFER,RISK) %>% gams_symbol('i_tradePeriodRiskGroup')
    
    # create i_risk_Group set
    riskgroup <- riskgroupoffer %>% select(GROUP) %>% distinct %>%
        gams_symbol('i_riskGroup')
 
####################################################################################################################
####################################################################################################################
####################################################################################################################    

    # Extra input for Real Time Pricing project
    # Unless stated otherwise, the RTD run need to run twice:
    #   First run is to re-estimate the ISLANDLOSSES and update conforming node demand
    #   Second run is the final solve with the updated node demand.
    # We need the following parameters to do this in vSPD
    
    # create scalar i_studymode
    i_studymode <- as.numeric(studymode) %>% setattr('symName','i_studyMode')
    
    # create scalar i_runEnrgShortfallTransfer
    i_runEnrgShortfallTransfer <- as.numeric(enrgshortfalltransfer) %>% setattr('symName','i_runEnrgShortfallTransfer')
    
    # create scalar i_runPriceTransfer
    i_runPriceTransfer <- as.numeric(pricetransfer) %>% setattr('symName','i_runPriceTransfer')
    
    # create scalar i_runPriceTransfer
    i_useGenInitialMW <- as.numeric(usegeninitialMW) %>% setattr('symName','i_useGenInitialMW')
  
    # create i_island parameters
    if (casetype == 'RTD') {
        i_tradeperiodislandMWIPS <- 
            data.frame(dim1 = i_tradePeriod$PERIOD, 
                       dim2 = mssmkt_island$ISLAND,
                       value = mssmkt_island$MWIPS) %>%
            distinct %>% gams_symbol('i_tradePeriodIslandMWIPS','par')
      
        i_tradeperiodislandPDS <- 
            data.frame(dim1 = i_tradePeriod$PERIOD, 
                       dim2 = mssmkt_island$ISLAND, 
                       value = mssmkt_island$PSD) %>%
            distinct %>% gams_symbol('i_tradePeriodIslandPDS','par')
      
        i_tradeperiodislandlosses <- 
            data.frame(dim1 = i_tradePeriod$PERIOD, 
                       dim2 = mssmkt_island$ISLAND, 
                       value = mssmkt_island$ISLANDLOSSES) %>%
            distinct %>% gams_symbol('i_tradePeriodIslandLosses','par')
    } else {
        i_tradeperiodislandMWIPS <- 
            data.frame(dim1 = factor(), dim2 = factor(),value = numeric()) %>%
            gams_symbol('i_tradePeriodIslandMWIPS','par')
      
        i_tradeperiodislandPDS <- 
            data.frame(dim1 = factor(), dim2 = factor(),value = numeric()) %>%
            gams_symbol('i_tradePeriodIslandPDS','par')
      
        i_tradeperiodislandlosses <- 
            data.frame(dim1 = factor(), dim2 = factor(),value = numeric()) %>%
            gams_symbol('i_tradePeriodIslandLosses','par')
    }
    # create i_useactualLoad - flag to use actual load as initial load in RTD                
    i_useactualLoad <- filter(period_spdparameter, NAME == 'RtdLoadSourceUseCurrentLoad') %>% 
        select(PERIOD,VALUE) %>% gams_symbol('i_useActualLoad','par')    
    
    # create i_dontscalenegativeload - flag to not scale genagive load in RTD load calculation
    i_dontscalenegativeload <- filter(period_spdparameter, NAME=='DontScaleNegativeLoad') %>% 
        select(PERIOD,VALUE) %>% gams_symbol('i_dontScaleNegativeLoad','par')

    # create i_energyscarcityenabled - flag to enable energy scarcity Limits/Factors
    i_energyscarcityenabled <- filter(period_spdparameter, NAME=='EnergyScarcityEnabled') %>% 
        select(PERIOD,VALUE) %>% gams_symbol('i_energyScarcityEnabled','par')
  
    # create i_reservescarcityenabled - flag to enable reserve scarcity Limits
    i_reservescarcityenabled <- filter(period_spdparameter, NAME=='ReserveScarcityEnabled') %>% 
        select(PERIOD,VALUE) %>% gams_symbol('i_reserveScarcityEnabled','par')
  
    # create i_tradePeriodScarcityEnrgNationalFactor
    i_tradeperiodscarcityenrgnationalfactor <- period_scarcityennationalfactors %>%
        transmute(PERIOD, TRANCHENUMBER = paste0('t',TRANCHENUMBER), FACTOR) %>%
        gams_symbol('i_tradePeriodScarcityEnrgNationalFactor','par')
  
    # create i_tradePeriodScarcityEnrgNationalPrice
    i_tradeperiodscarcityenrgnationalprice <- period_scarcityennationalfactors %>%
        transmute(PERIOD, TRANCHENUMBER = paste0('t',TRANCHENUMBER), PRICE) %>% 
        gams_symbol('i_tradePeriodScarcityEnrgNationalPrice','par')
  
    # create i_tradePeriodScarcityEnrgNodeFactor
    i_tradeperiodscarcityenrgnodefactor <- period_scarcityenpnodefactors %>%
        transmute(PERIOD, PNODENAME, TRANCHENUMBER = paste0('t',TRANCHENUMBER), FACTOR) %>% 
        gams_symbol('i_tradePeriodScarcityEnrgNodeFactor','par')
  
    # create i_tradePeriodScarcityEnrgNodeFactorPrice
    i_tradeperiodscarcityenrgnodefactorprice <- period_scarcityenpnodefactors %>%
        transmute(PERIOD, PNODENAME, TRANCHENUMBER = paste0('t',TRANCHENUMBER), PRICE) %>% 
        gams_symbol('i_tradePeriodScarcityEnrgNodeFactorPrice','par')
    
    # create i_tradePeriodScarcityEnrgNodeLimit
    i_tradeperiodscarcityenrgnodelimit <- period_scarcityenpnodelimits %>%
        transmute(PERIOD, PNODENAME, TRANCHENUMBER = paste0('t',TRANCHENUMBER), LIMIT) %>% 
        gams_symbol('i_tradePeriodScarcityEnrgNodeLimit','par')
    
    # create i_tradePeriodScarcityEnrgNodeLimitPrice
    i_tradeperiodscarcityenrgnodelimitprice <- period_scarcityenpnodelimits %>%
        transmute(PERIOD, PNODENAME, TRANCHENUMBER = paste0('t',TRANCHENUMBER), PRICE) %>% 
        gams_symbol('i_tradePeriodScarcityEnrgNodeLimitPrice','par')
  
    # create i_tradePeriodScarcityResrvIslandLimits
    i_tradeperiodscarcityresrvislandlimit <- period_scarcityresislandlimits %>%
        transmute(PERIOD, ISLAND, RESERVECLASS, TRANCHENUMBER = paste0('t',TRANCHENUMBER), LIMIT) %>% 
        gams_symbol('i_tradePeriodScarcityResrvIslandLimit','par')
  
    # create i_tradePeriodScarcityResrvIslandPrice
    i_tradeperiodscarcityresrvislandprice <- period_scarcityresislandlimits %>%
        transmute(PERIOD, ISLAND, RESERVECLASS, TRANCHENUMBER = paste0('t',TRANCHENUMBER), PRICE) %>% 
        gams_symbol('i_tradePeriodScarcityResrvIslandPrice','par')  

####################################################################################################################
####################################################################################################################
####################################################################################################################    
    
    # The following section writing data into gdx file 
    wgdx.lst (paste0(gdxDestination,'/',gdxname,'.gdx'),
              caseName, i_day, i_month, i_year,                                     
              i_dateTime, i_tradePeriod, i_dateTimeTradePeriod,                     
              i_studyperiod, i_aclineunit, i_tradingperiodlength,                   
              i_branchreceivingendlossproportion,                                   
              i_cvp, i_cvpvalues, i_island, i_node, i_bus,                          
              
              i_tradeperiodnode, i_tradeperiodbus, i_tradeperiodbusisland,          
              i_tradeperiodnodebus,i_tradeperiodnodebusallocationfactor,            
              i_tradeperiodbuselectricalisland, i_tradeperiodHVDCnode,              
              i_tradeperiodrefnode,                                                 
              
              i_losssegment, i_lossparameter, i_nolossbranch,                       
              i_AClossbranch, i_DClossbranch, i_flowdirection,                      
              
              i_branchpara, i_branch, i_tradeperiodbranchdefn,                      
              i_tradeperiodHVDCbranch, i_tradeperiodbranchpara,                     
              i_tradeperiodbranchcapa, i_tradeperiodbranchcapadirected,
              i_tradeperiodbranchstatus, i_tradePeriodAllowHVDCRoundpower,
              i_tradePeriodReverseRatingsApplied,
              
              i_cstrRHS, 
              i_branchconstraint, i_branchconstraintfactors, i_branchconstraintRHS,
              i_acnodeconstraint, i_acnodeconstraintfactors, i_acnodeconstraintRHS,
              i_mnconstraint, i_mnenrgofferconstraintfactors, 
              i_mnresvofferconstraintfactors, i_mnenrgbidconstraintfactors,
              i_mnilresvbidconstraintfactors, i_mnconstraintRHS,
              i_genericconstraint, i_periodgenericconstraint,
              i_genericenrgofferconstraintfactors, 
              i_genericresvofferconstraintfactors, 
              i_genericenrgbidconstraintfactors,
              i_genericilresvbidconstraintfactors, 
              i_genericbranchconstraintfactors, 
              i_genericconstraintRHS,
              
              i_type1MixedConstraintRHS, 
              i_type1MixedConstraint, 
              i_type1MixedConstraintReserveMap,
              i_tradePeriodType1MixedConstraint, 
              i_type1MixedConstraintBranchCondition,
              i_type1MixedConstraintVarWeight,
              i_type1MixedConstraintPurWeight,
              i_type1MixedConstraintGenWeight,
              i_type1MixedConstraintResWeight,
              i_type1MixedConstraintHVDClineWeight,
              i_tradePeriodType1MixedConstraintRHSParameters,
              i_type1MixedConstraintHVDClineLossWeight,
              i_type1MixedConstraintHVDClineFixedLossWeight,
              i_type1MixedConstraintAClineWeight,
              i_type1MixedConstraintAClineLossWeight,
              i_type1MixedConstraintAClineFixedLossWeight,
              
              i_type2MixedConstraint,
              i_tradePeriodType2MixedConstraint,
              i_type2MixedConstraintLHSParameters,
              i_tradePeriodType2MixedConstraintRHSParameters,
              
              i_tradeBlock, i_Trader, i_Offer, i_offerParam, 
              i_energyOfferComponent, i_PLSRofferComponent, i_TWDRoffercomponent,
              i_ILRofferComponent, i_tradePeriodOfferTrader, i_tradePeriodOfferNode,
              i_tradePeriodOfferParameter, i_tradePeriodEnergyOffer,
              i_tradePeriodSustainedPLSRoffer, i_tradePeriodFastPLSRoffer,
              i_tradePeriodSustainedTWDRoffer, i_tradePeriodFastTWDRoffer,
              i_tradePeriodSustainedILRoffer, i_tradePeriodFastILRoffer,
              i_tradePeriodPrimarySecondaryOffer,
              
              i_bid, i_energyBidComponent, i_ILRbidComponent, 
              i_tradePeriodBidTrader, i_tradePeriodBidNode,
              i_tradePeriodEnergyBid, i_tradePeriodSustainedILRbid,
              i_tradePeriodFastILRbid, i_tradePeriodDispatchableBid,
              i_tradeperiodnodedemand,
              
              i_reserveClass, i_reserveType, i_riskClass, i_riskParameter,
              i_tradePeriodRiskGenerator, i_tradePeriodRiskParameter,
              i_tradePeriodManualRisk, i_tradePeriodManualRisk_ECE,
              i_tradePeriodHVDCSecRiskEnabled, i_tradePeriodHVDCSecRiskSubtractor,
              i_tradePeriodReserveClassGenerationMaximum,
              i_tradePeriodScarcitySituationExists, i_tradePeriodGWAPFloor, 
              i_tradePeriodGWAPCeiling, i_tradePeriodGWAPPastDaysAvg, 
              i_tradePeriodGWAPCountForAvg, i_tradePeriodGWAPThreshold,
              i_tradePeriodVROfferMax, i_tradePeriodVROfferPrice,
              
              FKCenabled, roundpwrstatus, reserveRoundPower,
              reserveShareEnabled,modulationRiskClass,
              rp2monolevel, bipole2monolevel, monopoleMin,
              HVDCControlBand, HVDCCableDischarge, HVDClossScalingFactor,
              sharedNFRfactor, effectiveFactor, sharedNFRLoadOffset,
              RMTreserveLimit, riskgroupoffer,rampingConstraint, riskgroup,
              
              # Real Time Pring Project - New Symbols
              i_studymode, i_useGenInitialMW, 
              i_runEnrgShortfallTransfer, i_runPriceTransfer,
              i_tradePeriodInputInitialLoad,
              i_tradePeriodLoadIsOverride, i_tradePeriodLoadIsBad,
              i_tradePeriodLoadIsNCL, i_tradePeriodConformingFactor,
              i_tradePeriodNonConformingLoad, i_tradePeriodMaxLoad,
              i_tradeperiodislandMWIPS, i_tradeperiodislandPDS, 
              i_tradeperiodislandlosses, 
              i_dontscalenegativeload, i_useactualLoad ,
              i_energyscarcityenabled, i_reservescarcityenabled,
              i_tradeperiodscarcityenrgnationalfactor,
              i_tradeperiodscarcityenrgnationalprice,
              i_tradeperiodscarcityenrgnodefactor,
              i_tradeperiodscarcityenrgnodefactorprice,
              i_tradeperiodscarcityenrgnodelimit,
              i_tradeperiodscarcityenrgnodelimitprice,
              i_tradeperiodscarcityresrvislandlimit,
              i_tradeperiodscarcityresrvislandprice 
              
    )
    
    return(paste0(gdxDestination,'/',gdxname,'.gdx'))
    
}


# COMMAND ----------

# DBTITLE 1,GDX creation procedure
SparkR::sparkR.session()

if (!(mssfoldername=="landed") & (nrow(df_unprocessedcasefiles) > 0)) {
  
  for (i in (1:nrow(df_unprocessedcasefiles))) {
    mssFilePath <- gsub(x=df_unprocessedcasefiles$path[i],pattern='dbfs:/',replacement="/dbfs/")
    filename <- df_unprocessedcasefiles$name[i]
    casetype <- df_unprocessedcasefiles$CaseType[i]
    absolutefilename <- gsub(x=raw_mp,pattern="/mnt/",replacement="")
    absolutefilename <- str_split(string=absolutefilename,pattern="/")
    absolutefilename <- paste0('abfss://',absolutefilename[[1]][2],
                               '@',absolutefilename[[1]][1],'.dfs.core.windows.net/',
                               casetype,'/',filename)
    
    # It is faster to copy file to "local" folder to read than read directly from mounted folder
    file.copy(from = mssFilePath, to = 'MSS')
    mssDataList <- Read_MSS_Data_To_Dataframes_List(paste0('MSS/',filename))
    casetype <- as.character(mssDataList$CASETYPE)
    
    # Splitting data for FP case type
    if (T) {
      print(paste0("Case files to split: ", filename ))
      csvDest <- paste0('/dbfs',csv_mp)
      casename <- Write_MSS_dataframe_to_CSV_folder(mssDataList) 
      file.copy(from=paste0('CSV/',casetype),to=csvDest,overwrite=T,recursive=T)
      unlink(x='CSV/*',recursive=T,force=T)  
    }
    
    # Create GDX and copy it to the EMI location
    if (T) {
      print(paste0("Case files to create gdx: ", filename ))
      gdxDest <- dbutils.widgets.get('FPExportPath')
      gdxname <- create_gdx_from_MSS_dataframe(mssDataList,gdxDestination=gdxDest)
      file.copy(from = 'Datasets',recursive=T,overwrite=T,to = paste0('/dbfs',emi_publicdata_mp))
      unlink(x=gdxname,recursive=T)
    }
    
    # Copy MSS casefile to EMI public data location and "processed" folder 
    if (T) {
      mssEmiDest <- gsub(x=dirname(gdxname),pattern='GDX',replacement='CaseFiles')
      mssEmiDest <- paste0('/dbfs',emi_publicdata_mp,'/',mssEmiDest)
      if (!(dir.exists(mssEmiDest))) { dir.create(path=mssEmiDest,recursive=T) } 
      file.copy(from = paste0('MSS/',filename), to = paste0(mssEmiDest,'/',filename))       
      file.copy(from = paste0('MSS/',filename), to = paste0('/dbfs',raw_mp,'/processed/',casetype,'/',filename))
    }
    
    if (T) {
      # Get casefile infor and append vspd.spdcase records
      spdcase_update_df <- spdcase_update(mssDataList)
      spdcase_update_df$GDXFileName <- basename(gdxname)
      spdcase_update_df$FileName <- absolutefilename
      sqlquery <- spdcase_info_insert_query(spdcase_update_df)
      #SparkR::sql(sqlquery)
    }
    
    # And remove MSS file from local MSS folder
    unlink(paste0('MSS/',filename))
    
    # Only delete processed file in landing location when every step is sucessful
    unlink(mssFilePath)
  }
}
