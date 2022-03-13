# Databricks notebook source
# MAGIC %md
# MAGIC #### This Notebook contains R user defined functions that are commonly used by EA market anlytics
# MAGIC 
# MAGIC ##### 1. connecting_storage_container_to_dbfs(storageaccount,accesskey,container)
# MAGIC ##### 2. create_mapping_period_to_starttime() 
# MAGIC ##### 3. get_hours_in_a_day(yyyymmdd, timezone = 'Pacific/Auckland') 
# MAGIC ##### 4. get_caseID_from_casefilepath(casefilepath) 
# MAGIC ##### 5. get_case_type_from_CaseID(caseID) 

# COMMAND ----------

library(dplyr)
library(tidyr)
library(lubridate)
library(readr)
library(stringr)
library('data.table')

# COMMAND ----------

# DBTITLE 1,Function to mount a azure blob storage container and return the "path"
get_current_mount_points <- function(){
  fp <- function(x) return(x[['mountPoint']])
  fs <- function(x) return(x[['source']])
  l <- dbutils.fs.mounts()                          
  lp <- lapply(l,fp)
  ls <- lapply(l,fs)
  mountpoint <- unlist(lp,use.names=FALSE)
  source <- unlist(ls,use.names=FALSE)
  l <- data.frame(mountpoint,source, stringsAsFactors=F)
  return(l)
}

connecting_storage_container_to_dbfs <- function(storageaccount,accesskey,container){
  mp <- paste0('/mnt/',storageaccount,'/',container)
  src <- paste0("wasbs://",container,"@",storageaccount,".blob.core.windows.net")
  extfigs <- setNames(as.list(accesskey), paste0("fs.azure.account.key.",storageaccount,".blob.core.windows.net"))
  df <- get_current_mount_points()  # Get a list of current mount points
  if (mp %in% df$mountpoint) {  # Check if the mountpoint exists
    if (!(src==df$source[which(df$mountpoint==mp)])){  # Checking if the existing mount point has incorrect source
      dbutils.fs.unmount(mountPoint=mp)
      dbutils.fs.mount(source = src, mountPoint = mp, extraConfigs = extfigs)
    }
  } else {
      dbutils.fs.mount(source = src, mountPoint = mp, extraConfigs = extfigs)
  }
  return(mp)
}

# COMMAND ----------

# DBTITLE 1,Function to map 30 minutes trading period to period start time
create_mapping_period_to_starttime <- function(){
  df1 <- data.frame(period = seq(1,47,2), hourstr = paste0('0',seq(0,23),':00')) %>%
    rbind(data.frame(period = seq(2,48,2), hourstr = paste0('0',seq(0,23),':30'))) %>%
    dplyr::mutate(n = nchar(hourstr), numberofhours = 24) %>% 
    dplyr::mutate(hourstr = substr(x=hourstr,start=n-4,stop=n)) %>% 
    dplyr::select(-n) 
  
  df2 <- data.frame(period = seq(1,45,2), hourstr = paste0('0',c(0,1,seq(3,23)),':00')) %>%
    rbind(data.frame(period = seq(2,46,2), hourstr = paste0('0',c(0,1,seq(3,23)),':30'))) %>%
    dplyr::mutate(n = nchar(hourstr), numberofhours = 23) %>% 
    dplyr::mutate(hourstr = substr(x=hourstr,start=n-4,stop=n)) %>% 
    dplyr:: select(-n) 
  
  df3 <- data.frame(period = seq(1,49,2), hourstr = paste0('0',c(seq(0,2),seq(2,23)),':00')) %>%
    rbind(data.frame(period = seq(2,50,2), hourstr = paste0('0',c(seq(0,2),seq(2,23)),':30'))) %>%
    dplyr::mutate(n = nchar(hourstr), numberofhours = 25) %>% 
    dplyr::mutate(hourstr = substr(x=hourstr,start=n-4,stop=n)) %>% 
    dplyr::mutate(hourstr = ifelse(period %in% c(7,8),gsub(x=hourstr,pattern=':',replacement=';'),hourstr)) %>% 
    dplyr:: select(-n) 
  
  df <- rbind(df1,df2,df3) %>% 
    dplyr::transmute(NumberOfHoursPerDay = as.integer(numberofhours), TradingPeriodNumber = as.integer(period), TradingPeriodStartTime = hourstr)
  
  return(df)
}

# COMMAND ----------

# DBTITLE 1,Function to calculate number of hours in a day in NZ time
get_hours_in_a_day <- function(yyyymmdd, timezone = 'Pacific/Auckland') {
  if (is.Date(yyyymmdd)) {
    yyyymmdd <- format(x=yyyymmdd, format='%Y%m%d', tz='Pacific/Auckland')
  }
  NZT1 <- ymd(yyyymmdd,tz=timezone)
  NZT2 <- NZT1 + days(1)
  x <- difftime(NZT2,NZT1,units='hour')
  x <- as.integer(x)
  return(x)
}

# COMMAND ----------

# DBTITLE 1,Function to get period from an interval "dd-MMM-yyyy HH:MM"
get_period_from_inteval_nzt <- function(INTERVAL) {
    Date <- as.POSIXct(strptime(INTERVAL,format = '%d-%b-%Y',tz='Pacific/Auckland'))
    DateTime = as.POSIXct(strptime(INTERVAL,format = '%d-%b-%Y %H:%M',tz='Pacific/Auckland'))
    if (is.na(DateTime)) {
        DateTime = as.POSIXct(strptime(INTERVAL,format ='%d-%b-%Y %H;%M',tz='Pacific/Auckland'))
        period = 3 + (as.numeric(DateTime)-as.numeric(Date))/1800 
    } else {
        period = 1 + (as.numeric(DateTime)-as.numeric(Date))/1800 
    }
    return(period)
}

# COMMAND ----------

# DBTITLE 1,Function to get caseID from a MSS file path
get_caseID_from_casefilepath  <- function(casefilepath) {
  filename <- tools::file_path_sans_ext(basename(casefilepath))
  CaseID <- gsub(x=filename,pattern='MSS_','') %>% 
            gsub(pattern='_0X',replacement='')
  return(CaseID)
}

# COMMAND ----------

# DBTITLE 1,Function to get case type from case ID
get_case_type <- function(caseID) {
  nchr <- nchar(caseID)
  typecode <- substr(x=caseID, start=nchr-15,stop=nchr-13)
  casetype <- switch(typecode, '101' = "RTD", '110' = "RTP",'130' = "PRSS",'132' = "NRSS",
                    '131' = "PRSL",'133' = "NRSL",'111' = "FP",'120' = "WDS", typecode)
  return(casetype)
}

get_case_type_from_CaseID <- function(caseID) {
  return(get_case_type(caseID))
}

# COMMAND ----------

# DBTITLE 1,Function to get Start Period Date Time from case ID
get_start_date_time <- function(caseID, timezone = 'UTC') {
  nchr <- nchar(caseID)
  d <- substr(x=caseID, start=1,stop=nchr-16)
  Y <- substr(x=caseID, nchr-12,stop=nchr-9)
  m <- substr(x=caseID, nchr-8,stop=nchr-7)
  H <- substr(x=caseID, nchr-6,stop=nchr-5)
  M <- substr(x=caseID, nchr-4,stop=nchr-3)
  startdatetime <- dmy_hm(paste0(d,'-',m,'-',Y,' ',H,':',M), tz=timezone)
  return(startdatetime)
}

get_first_period_datetime <- function(caseID, timezone = 'UTC') {
  nchr <- nchar(caseID)
  d <- substr(x=caseID, start=1,stop=nchr-16)
  Y <- substr(x=caseID, nchr-12,stop=nchr-9)
  m <- substr(x=caseID, nchr-8,stop=nchr-7)
  H <- substr(x=caseID, nchr-6,stop=nchr-5)
  M <- substr(x=caseID, nchr-4,stop=nchr-3)
  startdatetime <- dmy_hm(paste0(d,'-',m,'-',Y,' ',H,':',M), tz=timezone)
  return(startdatetime)
}

# COMMAND ----------

# DBTITLE 1,Functions to map case type to study mode code and to price type code
get_study_mode <- function(casetype) {
  studymode <- switch(casetype, "RTD" = '101', "RTP" = '110',"PRSS" = '130',"NRSS" = '132',
                     "PRSL" = '131',"NRSL" = '133',"FP" = '111',"WDS" = '120', casetype)
  return(studymode)
}

get_price_type_code <- function(casetype) { 
  pricetypecode <- switch(casetype, 'PRSS' = "A", 'PRSL' = "G", 'NRSS' = "N", 'NRSL' = "L",
                          'FP' = "Undecided", 'WDS' = "W", 'RTD' = "D", 'RTP' = "I", casetype)
  return(pricetypecode)
}

# COMMAND ----------

# DBTITLE 1,Function to check if a zip file is not corrupted
is.zip <- function(filepath){
  result <- try({
    unzip(filepath, list = TRUE)
    return(TRUE)
  })
  return(FALSE)
}

# COMMAND ----------

# MAGIC %md #Functions and procedures to read data from MSS zip file to a list of dataframes

# COMMAND ----------

# DBTITLE 1,Function to return a list of file names in a MSS zipped file
listMSSfiles <- function(mssFilePath) {
    
    # First, get list of files in zip archive
    fileList <- unzip(zipfile = mssFilePath, list = TRUE)$Name
    
    # Subset list to those not needed for creating GDX
    fileListRemove <- str_detect(fileList, "aieperf|log|LOG|SPDSOLVEDIMM")
    
    return(fileList[!fileListRemove])
}

# COMMAND ----------

# DBTITLE 1,Function to get tables from a single MSS file from MSS zipped file. 
readMSS <- function(zippedfile, mssfile, writeCSV = FALSE){
    
    # Read the data into a character vector and remove strings starting with "C" (comments)
    con <- unz(zippedfile, mssfile)
    textData <- readLines(con) %>%  str_subset("^C", negate = TRUE)
    
    # Get total number of rows in file
    totalRows <- length(textData)
    
    # Get index of "initial" rows
    initialRowVector <- textData %>% str_which("^I")
    
    # Get number of tables in file (based on "initial" rows)
    numTables <- length(initialRowVector)
    
    # Initialise list to hold header and data positions for each table
    positionList <- vector("list", numTables)
    
    # Get table names for all tables in file
    tableNames <- sapply(initialRowVector, function(x) unlist(str_split(textData[x], ","))[3])
    
    # Loop through to get header and data end positions for each table
    for(i in 1:numTables){
        if(i < numTables){
            positionList[[i]]$headerRow <- initialRowVector[i]
            positionList[[i]]$dataRowEnd <- (initialRowVector[i + 1] - 1)
        } else {
            positionList[[i]]$headerRow <- initialRowVector[i]
            positionList[[i]]$dataRowEnd <- totalRows
        }
    }
    
    # Assign names to positionList
    names(positionList) <- tableNames
    
    # Initialise list to hold all data frames
    dfList <- list()
    
    # Loop through to read each table in to a dataframe
    for (tbl in tableNames){
        fromRow <- positionList[[tbl]][["headerRow"]]
        toRow <- positionList[[tbl]][["dataRowEnd"]]
        
        # If no data row, attach an empty row to the header row
        if (fromRow == toRow){
            tblData <- c(textData[fromRow:toRow], "")
        } else {
            tblData <- textData[fromRow:toRow]
        }
        
        suppressWarnings(
            
            dfList[[tbl]] <- read_delim(
                file = tblData
                , col_names = TRUE
                , col_types = cols(KEY3 = col_character(),            # This is to make sure that Key3 of branch data have the type of character 
                                   CASEID = col_character())          # This is to make sure that CASEID have the type of character
                , delim = ","
            )   
        )
    }
    
    if(writeCSV){
        fileType <- gsub('OX.',replacement = '',mssfile)
        sapply(names(dfList), 
               function(x) write_csv(dfList[[x]], 
                                     paste0("CSV/", fileType, "_", x, ".csv")))
        
    }
    close(con)
    return(dfList)
    
}

# COMMAND ----------

# DBTITLE 1,Function to get tables from periodic MSSNET files.
readMSSTopology <- function(zippedfile, topControlFile, writeCSV = FALSE){
    # Get concordance between interval and filename
    intervalConcordance <- topControlFile %>% select(INTERVAL, TOPFILENAME)
    # Initialise list for storing dataframes
    dfList <- list()
    for (i in 1:length(intervalConcordance$TOPFILENAME)){
        interval <- intervalConcordance$INTERVAL[i]
        fileName <- intervalConcordance$TOPFILENAME[i]
        # Read file and append INTERVAL variable
        tmp <- readMSS(zippedfile, fileName, writeCSV = FALSE) %>% 
            lapply(. %>% mutate(INTERVAL = interval))
        # Loop through each individual table in tmp and append to "master" for each table
        for (tbl in names(tmp)){
            dfList[[tbl]] <- dfList[[tbl]] %>% 
                rbind(tmp[[tbl]])   
        }   
    }
    if(writeCSV){
        sapply(names(dfList), function(x) write_csv(dfList[[x]], paste0("CSV/MSSNET_", x, ".csv")))
    }
    return(dfList)
}

# COMMAND ----------

# DBTITLE 1,Function to get data from periodic SPDSOLVED files
readSPDSOLVED <- function(zippedfile, solvedFiles, writeCSV = FALSE){
    # Initialise list for storing dataframes
    dfList <- list()
    for (i in 1:length(solvedFiles)){
        fileName <- solvedFiles[i]
        # Read current file in to tmp object
        tmp <- readMSS(zippedfile, fileName, writeCSV = FALSE) 
        # Loop through each individual table in tmp and append to "master" for each table
        for (tbl in names(tmp)){
            dfList[[tbl]] <- dfList[[tbl]] %>% 
                rbind(tmp[[tbl]])
        }
    }
    if(writeCSV){        
        sapply(names(dfList), function(x) write_csv(dfList[[x]], paste0("CSV/SOLVED_", x, ".csv")))
    }
    return(dfList)
}

# COMMAND ----------

# DBTITLE 1,Function to read first comment line from a single MSS file from MSS zipped file
readMSSfirstComment <- function(zippedfile, mssfile){
    # Read the data into a character vector and remove strings starting with "C" (comments)
    con <- unz(zippedfile, mssfile)
    textData <- readLines(con,1) 
    df <- read.table(text = textData,header = F,sep = ",")
    close(con)
    return(df)    
}

# COMMAND ----------

# DBTITLE 1,Read data from MSS zip to lists of data frames
Read_MSS_Data_To_Dataframes_List <- function(mssFilePath) {
    
  MSSfileList <- listMSSfiles(mssFilePath)
  
  f <- MSSfileList[str_detect(MSSfileList,'MDBCTRL')]
  MDBCTRL <- readMSS(mssFilePath, f)
  if (T) { # rename caseID to new caseID based on the new assigned casedID from file name)
    oldcaseID = MDBCTRL$CASE$CASEID
    newcaseID = strsplit(basename(mssFilePath),split='_')[[1]][2]

    MDBCTRL$CASE$CASEID <- newcaseID
    MDBCTRL$CASE$CASEFILE <- paste0('MSS_',newcaseID,'_0X')
    MDBCTRL$MDBFILE <- MDBCTRL$MDBFILE %>% 
      mutate(CASEID = newcaseID,
             FILENAME = gsub(x=FILENAME,pattern=oldcaseID,replacement=newcaseID))

    MDBCTRL$TOPFILE <- MDBCTRL$TOPFILE %>%
      mutate(TOPFILENAME = gsub(x=TOPFILENAME, pattern=oldcaseID,replacement=newcaseID) )
  }
  EXPORTER <- readMSSfirstComment(mssFilePath,f)
    
  f <- MSSfileList[str_detect(MSSfileList,'PERIOD')]
  PERIOD <- readMSS(mssFilePath, f)
  
  f <- MSSfileList[str_detect(MSSfileList,'MSSMKT')]
  MSSMKT <- readMSS(mssFilePath, f)
  
  f <- MSSfileList[str_detect(MSSfileList,'MSSMOD')]
  MSSMOD <- readMSS(mssFilePath, f)
    
  f <- MSSfileList[str_detect(MSSfileList,'DAILY')]
  DAILY <- readMSS(mssFilePath, f)
    
  f <- MSSfileList[str_detect(MSSfileList,'0X.MSSNET')]
  MSSNET <- readMSS(mssFilePath, f)
    
  # Load periodic MSS tables
  TOPOLOGY <- readMSSTopology(mssFilePath, MDBCTRL$TOPFILE)
    
  f <- MSSfileList[str_detect(MSSfileList,'SOLVED')]
  SPDSOLVED <- readSPDSOLVED(mssFilePath,f,writeCSV = F)
  
  # Get case name and case type to use in later stage
  casename <- MDBCTRL$CASE$CASENAME[1]
  casefile <- MDBCTRL$CASE$CASEFILE[1]
  caseType <- MDBCTRL$CASE$MODESHORTNAME[1]     
  studyMode <- MDBCTRL$CASE$STUDYMODE[1]
  caseid  <-  as.character(MDBCTRL$CASE$CASEID[1])
  rundatetime <- paste(EXPORTER$V6[1],EXPORTER$V7[1])
    
  # From 21-JUL-2020, SO report runtime in MSS as UTC instead of NZT
  dataDate <- dmy_hm(MDBCTRL$CONTROL$INTERVAL[1], tz = "Pacific/Auckland")
  if (dataDate >= dmy_hm('21-JUL-2020 00:00', tz = "Pacific/Auckland")) {
    rundatetime <- as.POSIXct(strptime(x=rundatetime,format='%Y/%m/%d %H:%M:%S',tz='UTC'))
  } else{
    rundatetime <- as.POSIXct(strptime(x=rundatetime,format='%Y/%m/%d %H:%M:%S',tz='Pacific/Auckland'))
  }
  
  datalist <- list("MDBCTRL"=MDBCTRL,"EXPORTER"=EXPORTER,"PERIOD"=PERIOD,
                   "MSSMKT"=MSSMKT,"MSSMOD"=MSSMOD,"DAILY"=DAILY,"MSSNET"=MSSNET,
                   "TOPOLOGY"=TOPOLOGY,"SPDSOLVED"=SPDSOLVED,
                   "CASENAME"= casename, CASEFILE = casefile, "CASETYPE"=caseType, 
                   "STUDYMODE" = studyMode, "CASEID"=caseid,"RUNDATETIME"=rundatetime
                  )
  return(datalist)
  
}

# COMMAND ----------

# MAGIC %md #Functions and procedures to create new record for vspd.spdcase

# COMMAND ----------

# DBTITLE 1,Read info data from MSS zip to list
Read_MSS_Info_To_List <- function(mssFilePath) {
    
  MSSfileList <- listMSSfiles(mssFilePath)
  
  f <- MSSfileList[str_detect(MSSfileList,'MDBCTRL')]
  MDBCTRL <- readMSS(mssFilePath, f)
  EXPORTER <- readMSSfirstComment(mssFilePath,f)
    
  # Get case name and case type to use in later stage
  casename <- MDBCTRL$CASE$CASENAME[1]
  casefile <- MDBCTRL$CASE$CASEFILE[1]
  caseType <- MDBCTRL$CASE$MODESHORTNAME[1]      
  studyMode  <-  MDBCTRL$CASE$STUDYMODE[1]   
  caseid  <-  as.character(MDBCTRL$CASE$CASEID[1])
  rundatetime <- paste(EXPORTER$V6[1],EXPORTER$V7[1])
  
  # From 21-JUL-2020, SO report runtime in MSS as UTC instead of NZT
  dataDate <- dmy_hm(MDBCTRL$CONTROL$INTERVAL[1], tz = "Pacific/Auckland")
  if (dataDate >= dmy_hm('21-JUL-2020 00:00', tz = "Pacific/Auckland")) {
    rundatetime <- as.POSIXct(strptime(x=rundatetime,format='%Y/%m/%d %H:%M:%S',tz='UTC'))
  } else{
    rundatetime <- as.POSIXct(strptime(x=rundatetime,format='%Y/%m/%d %H:%M:%S',tz='Pacific/Auckland'))
  }
  
  datalist <- list("CASENAME"=casename, "CASETYPE"=caseType, CASEFILE = casefile,
                   "STUDYMODE" = studyMode, "CASEID"=caseid,"RUNDATETIME"=rundatetime)
  return(datalist)
}

# COMMAND ----------

# DBTITLE 1,Get information of spd case
spdcase_update <- function(infolist) {
  firstperioddatetime <- get_first_period_datetime(infolist$CASEID)
  firstperioddatetimeNZT <- format(firstperioddatetime ,format = '%Y-%m-%d %H:%M:%S', tz='Pacific/Auckland') 
  firstperioddatetimeUTC <- format(firstperioddatetime ,format = '%Y-%m-%d %H:%M:%S', tz='UTC')
  
  df <- data.frame(CaseID = infolist$CASEID,
                   CaseName = infolist$CASENAME,
                   RunDateTime = infolist$RUNDATETIME,
                   CaseTypeCode = infolist$CASETYPE,
                   StudyModeCode = as.character(infolist$STUDYMODE), 
                   FirstPeriodDateTime = firstperioddatetime, 
                   FirstPeriodDateTimeNZT = firstperioddatetimeNZT, 
                   FirstPeriodDateTimeUTC = firstperioddatetimeUTC,
                   stringsAsFactors=FALSE) %>% 
    mutate(PriceTypeCode = get_price_type_code(CaseTypeCode),
           RunDateTimeNZT = format(RunDateTime,format = '%Y-%m-%d %H:%M:%S',tz = "Pacific/Auckland"),
           RunDateTimeUTC = format(RunDateTime,format = '%Y-%m-%d %H:%M:%S',tz = "UTC")
          )
  
  return(df)
}

# COMMAND ----------

# DBTITLE 1,Return a query to insert new record into vspd.spdcase
spdcase_info_insert_query <- function(df) {
   
  df$InsertDateTime <- Sys.time()
  df$InsertDateTimeNZT <- format(df$InsertDateTime,format='%Y-%m-%d %H:%M:%OS3',tz = "Pacific/Auckland")
  df$InsertDateTimeUTC <- format(df$InsertDateTime,format='%Y-%m-%d %H:%M:%OS3',tz = "UTC")
  
  if (!('GDXFileName' %in% colnames(df))) df$GDXFileName <- NA
  df <- df %>% 
      transmute(CaseID,CaseName,CaseTypeCode,StudyModeCode,PriceTypeCode,
                FirstPeriodDateTime,FirstPeriodDateTimeNZT,FirstPeriodDateTimeUTC,
                RunDateTime,RunDateTimeNZT,RunDateTimeUTC,
                GDXFileName,
                EnergyPriceComparisonFlag = NA,
                ReservePriceComparisonFlag = NA,
                IntervalCostComparisonFlag = NA,
                DifferenceReason = NA,
                FileName,InsertDateTime,InsertDateTimeNZT,InsertDateTimeUTC)
  
  values <- NULL
  for (i in (1:ncol(df))) {
    x <- df[1,i]
    if (is.na(x)) {
      x <- "NULL"
     } else {
      x <- paste0("'",x,"'")
    }
    if (is.null(values)) {
      values <- x
    } else {
      values <- paste(values,x,sep =",")
    }  
  }
  sqlquery <- paste0("INSERT INTO vspd.spdcase VALUES (", values, ")")
  
  return(sqlquery)
}

# COMMAND ----------

# MAGIC %md #Functions to write split MSS data to CSVs.

# COMMAND ----------

# DBTITLE 1,Write MSS data to CSV format file
Write_MSS_dataframe_to_CSV_folder <- function(mssDataList, csvDestination = 'CSV') {
  
  casetype <- as.character(mssDataList$CASETYPE)
  casefile <- as.character(mssDataList$CASEFILE)
  
  # Get rundatetime
  df <- mssDataList$EXPORTER
  tabletype <- as.character(df[1,2])
  tablename <- as.character(df[1,3])
  pathdir <- paste(csvDestination,casetype,tabletype,tablename,sep='/')
  if (!(dir.exists(pathdir))) { dir.create(pathdir,recursive=T) }
  write.table(df,row.names=F,col.name=F,file=paste0(pathdir,'/',casefile,'.MDBCTRL'),quote=F,sep=",")
  
  
  split_mss_to_csv <- function(msstables, tablelist, extention) {
    tablenames <- names(msstables) 
    tablenames <- tablenames[tablenames %in% tablelist]
    for (tablename in tablenames) {
      df <- msstables[[tablename]]
      if (nrow(df) > 0) {
        header <- colnames(df)
        tabletype <- header[2]
        pathdir <- paste(csvDestination,casetype,tabletype,tablename,sep='/')
        if (!(dir.exists(pathdir))) { dir.create(pathdir,recursive=T) }
        write.csv(df,row.names=F,quote=F,file=paste0(pathdir,'/',casefile,extention))     
      }  
    }
  }
  
  solutionlist <- c("ISLAND","BUS","PNODE","BRANCH","CONSTRAINT","TRADERPERIOD",
                    "SCARCITYPRICING","RESERVESHARING","RISKTYPESHORTFALL") 
  solutiontables <- mssDataList$SPDSOLVED
  split_mss_to_csv(solutiontables, solutionlist, '.SPDSOLVED') 
  
  mdbctrllist <- c("CASE","CONTROL","MASTHRESHOLD","MDBFILE","SFTCASE","TOPFILE") 
#   if (casetype %in% c('RTD','RTP')) {mdbctrllist <- c("CASE")}
  mdbctrtables <- mssDataList$MDBCTRL
  split_mss_to_csv(mdbctrtables, mdbctrllist, '.MDBCTRL') 
  
  periodlist <- c("TRADERPERIODS","BIDSANDOFFERS","RISKPARAMSCHEDULE",
                  "PNODEINT","PNODELOAD","HVDCLINK","HVDCROUNDPOWER",
                  "SCARCITYAREA","SCARCITYISLAND",
                  "VIRTUALRESERVE","RESERVESHARING",
                  "SCARCITYENNATIONALFACTORS","SCARCITYENPNODEFACTORS", 
                  "SCARCITYENPNODELIMITS","SCARCITYRESISLANDLIMITS",
                  "SPDPARAMETER"
                 ) 
#   if (casetype %in% c('RTD','RTP')) {periodlist <- c("NOTHING")}
  periodtables <- mssDataList$PERIOD
  split_mss_to_csv(periodtables, periodlist, '.PERIOD')
      
  mssmktlist <- c("TRADER","ISLAND","BRANCHSEGMENT","BRANCHPARAM",
                  "UNITINITIALMW","UNITACTUALMW","HVDCBRANCH","HVDCLINKPOLEDATA" ) 
#   if (casetype %in% c('RTD','RTP')) {mssmktlist <- c("NOTHING")}
  mssmkttables <- mssDataList$MSSMKT
  split_mss_to_csv(mssmkttables, mssmktlist, '.MSSMKT')
    
  mssmodlist <- c("BRANCHCONSTRAINT","BRANCHCONSTRFACTORS","BRANCHOUTAGE",
                  "MNDCONSTRAINT","MNDCONSTRAINTFACTORS","PNODEOVRD") 
  if (casetype %in% c('RTD','RTP')) {mssmodlist <- c("NOTHING")}
  mssmodtables <- mssDataList$MSSMOD
  split_mss_to_csv(mssmodtables, mssmodlist, '.MSSMKT')  
  
  dailylist <- c("PNODE","UNITDATA") 
#   if (casetype %in% c('RTD','RTP')) {dailylist <- c("NOTHING")}
  dailytables <- mssDataList$DAILY
  split_mss_to_csv(dailytables, mssmodlist, '.DAILY')
  
  mssnetlist <- c("BRANCHNODE") 
#   if (casetype %in% c('RTD','RTP')) {mssnetlist <- c("NOTHING")}
  mssnettables <- mssDataList$MSSNET
  split_mss_to_csv(mssnettables, mssmodlist, '.MSSNET')
  
  topolist <- c("ENODEBUS","BRANCHBUS") 
#   if (casetype %in% c('RTD','RTP')) {topolist <- c("NOTHING")}
  topotables <- mssDataList$TOPOLOGY
  split_mss_to_csv(topotables, topolist, '.MSSNET')

  return(mssDataList$CASEID)
}

# COMMAND ----------

# MAGIC %md #Functions and procedures to create GDX

# COMMAND ----------

# DBTITLE 1,Function to convert a dataframe to GAMS set or parameter symbol
gams_symbol <- function(df,symName,type = 'set') {
    if (type %in% c('set','Set','SET')) {
        df <- df %>% mutate_all(as.factor)
    } else {
        n <- ncol(df)-1    
        df <- df %>% mutate_at((1:n),as.factor) %>% mutate_at(n+1, as.numeric) 
    }
    df <- df %>% setattr('symName',symName) 
}

# COMMAND ----------

# DBTITLE 1,Function to create an empty GAMS set or parameter symbol
gams_empty_symbol <- function(dim = 1,symName,type = 'set') {    
    df <- tibble()
    for (i in 1:dim) {
      df[paste0('dim',i)] <- factor()
    } 
    if (!(type %in% c('set','Set','SET'))) {
        df['value'] <- numeric()
    }
    df <- df %>% setattr('symName',symName) 
    return(df)
}
