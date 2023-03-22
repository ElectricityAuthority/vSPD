library(AzureStor)
library(config)
library(tidyverse)
library(stringr)
library(lubridate)
library(readr)
library('data.table')

options(digits = 15)
rm(list = ls())
setwd(r"(C:/vSPD/ElectricityAuthority)")

config <- config::get(file = 'C:/ZZZ/config.yml',config = 'default')
config <- config::get(file = 'C:/ZZZ/config.yml',config = 'developement')
config <- config::get(file = 'C:/ZZZ/config.yml',config = 'testing')

casetype  <- 'RTD'
datetime <- '202303062235'
runname <- paste0(casetype,'_',datetime)
programfolder <- paste0(this.dir,"/Programs")
outputfolder <- paste0(this.dir,"/Output")
tradingdate <- substr(datetime,1,8)
print(paste0('Trading datetime : ',datetime))
runName <- paste0(casetype,'_',datetime)

listMSSfiles <- function(mssFilePath) {
    
    # First, get list of files in zip archive
    fileList <- unzip(zipfile = mssFilePath, list = TRUE)$Name
    
    # Subset list to those not needed for creating GDX
    fileListRemove <- str_detect(fileList, "aieperf|log|LOG|SPDSOLVEDIMM")
    
    return(fileList[!fileListRemove])
}
readMSSfirstComment <- function(zippedfile, mssfile){
    # Read the data into a character vector and remove strings starting with "C" (comments)
    con <- unz(zippedfile, mssfile)
    textData <- readLines(con,1) 
    df <- read.table(text = textData,header = F,sep = ",")
    close(con)
    return(df)    
}
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
        
        if (F) { # The code below cause an error when update cluster Runtime From 8.3 to 10.3. The issue is with readr(2.2.1) which can't read from a vetor of characters from memory as it used to
            suppressWarnings(
                
                dfList[[tbl]] <- read_delim(
                    file = tblData
                    , col_names = TRUE
                    , col_types = cols(KEY3 = col_character(),            # This is to make sure that Key3 of branch data have the type of character 
                                       CASEID = col_character())          # This is to make sure that CASEID have the type of character
                    , delim = ","
                )   
            )
        } else {
            cn <- str_split(tblData[1],",")[[1]]
            cn[duplicated(cn)] <- paste0(cn[duplicated(cn)],'_1')
            if (fromRow==toRow) {
                X = data.frame(matrix(ncol = length(cn), nrow = 0)) %>% mutate_all(as.character)
                colnames(X)  <- cn
                dfList[[tbl]] <- X
            } else {
                X = tblData[-1]
                dfList[[tbl]] <- as.data.frame(X,stringsAsFactors = F) %>%
                    separate(col = X, sep = ",",into = cn)
            }
            
        }
        
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


# Get list of gdx blob files for a trading date to be downloaded
if (T) {
    if (config$emi_key=="") {
        endpoint <- blob_endpoint(endpoint =config$emi_endpoint)
    } else{
        endpoint <- blob_endpoint(endpoint =config$emi_endpoint,
                                  key = config$emi_key)    
    }
    
    # Set Blob container using endpoint
    blobcontainer <- blob_container(endpoint = endpoint,name = "publicdata")
    
    # Get list of gdx files to download and solve
    prefix <- paste0('Datasets/Wholesale/DispatchAndPricing/GDXTest/',casetype,
                     '/',tradingdate,'/',casetype,'_',datetime)
    
    listblobs <- list_blobs(container = blobcontainer,prefix = prefix) %>%
        mutate(gdx = gsub(x=basename(name), pattern='.gdx',replacement='')) %>%
        mutate(mss = gdx) %>% separate(mss, c(NA,NA,'mss',NA), sep="_") %>%
        mutate(mss = paste0('MSS_',mss,'_0X.SPDSOLVED')) %>% arrange(gdx)
    
    # listblobs <-
    #     data.frame(gdx='NRSS_202210101230_91322022102330478_20221010123314') %>%
    #     mutate(name = paste0(gdx,'gdx')) %>%
    #     mutate(mss = gdx) %>% separate(mss, c(NA,NA,'mss',NA), sep="_") %>%
    #     mutate(mss = paste0('MSS_',mss,'_0X.SPDSOLVED')) %>% arrange(gdx)
}

# Download gdx files to solve with vSPD
if (T) {
    # Download GDX
    DownloadDestination <- paste0('Input/',tradingdate, '/')
    if (!dir.exists(DownloadDestination)) {
        dir.create(DownloadDestination,recursive = T)
    } 
    
    for (filename in listblobs$name) {
        if (file.exists(paste0(DownloadDestination,basename(filename)))) {
            print(paste0(filename, ' has already been downloaded'))
        } else {
            print(paste0('Downloading ', basename(filename)))
            storage_download(container = blobcontainer,src = filename,
                             dest = paste0(DownloadDestination,basename(filename)),
                             overwrite = T)
        }
    }

}


# Create vSPDfileList.inc file to list all the gdx to be solved by vSPD
if (T) {
    createListInc <- function(gdxlist, Incfolder = programfolder) {
        fileConn <- file(paste0(Incfolder,'/vSPDfileList.inc'))
        writeLines(c("/",paste0("'",gdxlist,"'"),"/"),con = fileConn)
        close(fileConn)
    }
    
    createListInc(gdxlist = listblobs$gdx)
}    
    
# Create vSPDsettings.inc for DWH mode
if (T) {
        
    createvSPDSettingInc <- function(runName, opMode, ovrdfile = "''",
                                     Inputfolder = "'%system.fp%..\\Input\\'" ,
                                     Outputfolder = "'%system.fp%..\\Output\\'" ,
                                     Ovrdfolder = "'%system.fp%..\\Override\\'" ,
                                     Incfolder = programfolder) {
        
        fileConn <- file(paste0(Incfolder,'/vSPDsettings.inc'))
        
        writeLines(c("*+++ vSPD settings +++",
                     "$inlinecom ## ##",
                     "$eolcom !",
                     "",
                     "*+++ Paths +++",
              paste0("$setglobal runName                       ",runName),
                     "",
                     "$setglobal programPath                   '%system.fp%' ",
              paste0("$setglobal inputPath                     ",Inputfolder),
              paste0("$setglobal outputPath                    ",Outputfolder),
              paste0("$setglobal ovrdPath                      ",Ovrdfolder),
                     "",
              paste0("$setglobal vSPDinputOvrdData             ",ovrdfile,"   !Name of override file "),
                     "",
                     "",
                     "*+++ Model +++",
                     "Scalar sequentialSolve                   / 0 / ;   ! Vectorisation: Yes <-> i_SequentialSolve: 0",
                     "Scalar disconnectedNodePriceCorrection   / 1 / ;",
                     "Scalar tradePeriodReports                / 1 / ;   ! Specify 1 for reports at trading period level, 0 otherwise",
                     "",
                     "",
                     "*+++ Network +++",
                     "Scalar useACLossModel                    / 1 /    ;",
                     "Scalar useHVDCLossModel                  / 1 /    ;",
                     "Scalar useACBranchLimits                 / 1 /    ;",
                     "Scalar useHVDCBranchLimits               / 1 /    ;",
                     "Scalar resolveCircularBranchFlows        / 1 /    ;",
                     "Scalar resolveHVDCNonPhysicalLosses      / 1 /    ;",
                     "Scalar resolveACNonPhysicalLosses        / 0 /    ;   ! Placeholder for future code development",
                     "Scalar circularBranchFlowTolerance       / 1e-4 / ;",
                     "Scalar nonPhysicalLossTolerance          / 1e-6 / ;",
                     "Scalar useBranchFlowMIPTolerance         / 1e-6 / ;",
                     "",
                     "",
                     "*+++ Constraints +++",
                     "Scalar useReserveModel                   / 1 /    ;",
                     "Scalar suppressMixedConstraint           / 0 /    ;   ! No longer used since Mixed MIP Constraints no longer exists",
                     "Scalar mixedMIPtolerance                 / 1e-6 / ;   ! No longer used since Mixed MIP Constraints no longer exists",
                     "",
                     "",
                     "*+++ Solver +++",
                     "Scalar LPtimeLimit                       / 3600 / ;",
                     "Scalar LPiterationLimit                  / 2000000000 / ;",
                     "Scalar MIPtimeLimit                      / 3600 / ;",
                     "Scalar MIPiterationLimit                 / 2000000000 / ;",
                     "Scalar MIPoptimality                     / 0 / ;",
                     "$setglobal Solver                          Cplex",
                     "$setglobal licenseMode                     1",
                     "","",
                     "*+++ Various switches +++",
                     paste0("$setglobal opMode                          ",opMode ,
                            "      ! DWH for data warehouse; AUD for audit; ",
                            "FTR for FTR Rental; SPD for normal SPD run; ",
                            "PVT for pivot analysis; ",
                            "DPS for demand~price sensitivity analysis")
        ),con = fileConn)
        
        close(fileConn)
    }
    
    createvSPDSettingInc(runName = runname, opMode = 'SPD', Inputfolder = paste0("'%system.fp%..\\Input\\" ,tradingdate,"\\'") )
    
}

# runvSPD
if (T) {
    setwd(programfolder)
    system('runvSPD.bat', wait = T)
    setwd(this.dir)
}


# Download MSS case files
if (T) {
    
    config <- config::get(file = 'C:/ZZZ/config.yml',config = 'testing')
    # Set Blob container using endpoint
    if (config$emi_key=="") {
        endpoint <- blob_endpoint(endpoint =config$emi_endpoint)
    } else{
        endpoint <- blob_endpoint(endpoint =config$emi_endpoint,key = config$emi_key)    
    }
    blobcontainer <- blob_container(endpoint = endpoint,name = "publicdata")
    
    # if (casetype!='RTD') {
    #     endpoint <- blob_endpoint(endpoint =config$madatasource_endpoint,key = config$madatasource_key)    
    #     blobcontainer <- blob_container(endpoint = endpoint,name = "casefiles")
    # }
    
    
    SolutionIsland <- NULL
    SolutionTrdrPrd <- NULL
    SolutionPnode <- NULL
    SolutionBus <- NULL
    SolutionBranch <- NULL
    SolutionCnstr <- NULL
    CluMessage <- NULL
    BranchNode <- NULL
    HVDCLink <- NULL
    ObjectiveValue <- NULL
    
    # Download MSS
    DownloadDestination <- paste0('Output/',runname, '/')
    if (!dir.exists(DownloadDestination)) {
        dir.create(DownloadDestination,recursive = T)
    } 
    
    for (mss in listblobs$mss) {
        
        msspath <- listblobs$name[which(listblobs$mss==mss)]
        msspath <- gsub(x=msspath,pattern = 'GDX',replacement = 'CaseFiles') %>% dirname()
        filename = gsub(x = mss, pattern = 'SPDSOLVED',replacement = 'ZIP')
        
        # if (casetype!='RTD') msspath <- paste0('processed/',casetype)
        
        filename = paste0(msspath,'/',filename)
        
        if (file.exists(paste0(DownloadDestination,basename(filename)))) {
            print(paste0(filename, ' has already been downloaded'))
        } else {
            print(paste0('Downloading ', basename(filename)))
            storage_download(container = blobcontainer,src = filename,
                             dest = paste0(DownloadDestination,basename(filename)),
                             overwrite = T)
        }
        
        zip_file <- paste0(DownloadDestination,basename(filename))
        mssdata <- Read_MSS_Data_To_Dataframes_List(mssFilePath = zip_file)
        
        rundt <- mssdata$RUNDATETIME %>%
            format(format = '%d-%b-%Y %H:%M:%S',tz = 'Pacific/Auckland') %>% toupper()
        
        mssdata$SPDSOLVED$ISLAND$RunTime <- rundt
        mssdata$SPDSOLVED$TRADERPERIOD$RunTime <- rundt
        mssdata$SPDSOLVED$PNODE$RunTime <- rundt
        mssdata$SPDSOLVED$BUS$RunTime <- rundt
        mssdata$SPDSOLVED$BRANCH$RunTime <- rundt
        mssdata$SPDSOLVED$CONSTRAINT$RunTime <- rundt
        mssdata$SPDSOLVED$CLUMESSAGE$RunTime <- rundt
        
        # Read Solution Island
        if (is.null(SolutionIsland)) {
            SolutionIsland  <- mssdata$SPDSOLVED$ISLAND 
            SolutionTrdrPrd <- mssdata$SPDSOLVED$TRADERPERIOD
            SolutionPnode   <- mssdata$SPDSOLVED$PNODE
            SolutionBus     <- mssdata$SPDSOLVED$BUS
            SolutionBranch  <- mssdata$SPDSOLVED$BRANCH
            SolutionCnstr   <- mssdata$SPDSOLVED$CONSTRAINT
            CluMessage      <- mssdata$SPDSOLVED$CLUMESSAGE
            BranchNode      <- mssdata$MSSNET$BRANCHNODE
            HVDCLink        <- mssdata$PERIOD$HVDCLINK

            
        } else {
            SolutionIsland  <- rbind(SolutionIsland,mssdata$SPDSOLVED$ISLAND)
            SolutionTrdrPrd <- rbind(SolutionTrdrPrd,mssdata$SPDSOLVED$TRADERPERIOD)
            SolutionPnode   <- rbind(SolutionPnode,mssdata$SPDSOLVED$PNODE)
            SolutionBus     <- rbind(SolutionBus,mssdata$SPDSOLVED$BUS)
            SolutionBranch  <- rbind(SolutionBranch,mssdata$SPDSOLVED$BRANCH)
            SolutionCnstr   <- rbind(SolutionCnstr,mssdata$SPDSOLVED$CONSTRAINT)
            CluMessage      <- rbind(CluMessage,mssdata$SPDSOLVED$CLUMESSAGE)
            BranchNode      <- rbind(BranchNode,mssdata$MSSNET$BRANCHNODE)
            HVDCLink        <- rbind(HVDCLink,mssdata$PERIOD$HVDCLINK)
        }
        
    }
    
    branch_branch <- BranchNode %>% mutate_if(is.character, str_squish) %>%
        transmute(BRANCHNAME = ID_BRANCH, 
                  Branch = ifelse(KEY4 == 'LN', paste0(KEY2,".",KEY3),
                                  paste0(KEY1,"_",KEY2,".",KEY3)))
    branch_branch <- HVDCLink %>% 
        transmute(BRANCHNAME = HVDCBRANCH, Branch = HVDCBRANCH ) %>%
        rbind(branch_branch) %>% distinct() %>%
        mutate(BRANCHNAME = gsub(x = BRANCHNAME,pattern = " ",replacement = ""))
    
    df <- CluMessage %>% 
        select(RunTime,CLUMETHOD,CLUMESSAGE_1) %>%
        filter(endsWith(CLUMETHOD,'SPDSolvePeriod')) 
    df$TimeStamp = sapply(strsplit(df$CLUMESSAGE_1, "\\|"), "[", 1)
    df$CLUMESSAGE = sapply(strsplit(df$CLUMESSAGE_1, "\\|"), "[", 2)
    CluMessage <- df %>% select(RunTime, TimeStamp, CLUMESSAGE)
    df <- df %>% filter(startsWith(CLUMESSAGE,'Objective function value')) %>%
        mutate(CLUMESSAGE = gsub(x=CLUMESSAGE,pattern = 'Objective function value =  ','')) %>%
        transmute(RunTime,CLUMESSAGE = trimws(CLUMESSAGE),TimeStamp)
    df$ObjectiveValue = sapply(strsplit(df$CLUMESSAGE, " for "), "[", 1)
    df$CLUMESSAGE = sapply(strsplit(df$CLUMESSAGE, " for "), "[", 2)
    df$DateTime = sapply(strsplit(df$CLUMESSAGE, " \\("), "[", 1)
    df <- df %>% transmute(DateTime,RunTime, TimeStamp = as.POSIXct(strptime(TimeStamp,'%d-%m-%Y %H:%M:%S')),
                           ObjectiveValue = -as.numeric(ObjectiveValue))
    ObjectiveValue <- df
    
    
}

# Compare vsPD vs SPD 
if (T) {
    
    # Branch Solution Comparison
    if (T) { 
        df <- read.csv(paste0('Output/',runname,'/',runname,'_BranchResults_TP.csv'),header = T, as.is = T)
        cn <- colnames(df)
        cn <- sapply(X = cn, gsub, pattern = "\\.", replacement = "")
        colnames(df) <- cn
        
        df1 <- SolutionBranch %>% 
            mutate(BRANCHNAME = gsub(x = BRANCHNAME,pattern = " ",replacement = ""),
                   DISCONNECTED = as.integer(DISCONNECTED)
                   ) %>%
            inner_join(branch_branch, by = 'BRANCHNAME') %>% 
            transmute(DateTime = INTERVAL, RunTime, Branch,
                      FromBus = as.integer(FROM_ID_BUS), ToBus = as.integer(TO_ID_BUS),
                      SPDFLOWMWFROMTO = ifelse(as.numeric(FROM_MW) < 0,as.numeric(TO_MW), as.numeric(FROM_MW)),
                      SPDMWMAX	= as.numeric(MWMAX),
                      SPDFIXEDLOSS = ifelse(DISCONNECTED == 1,0, as.numeric(FIXEDLOSS)),
                      SPDBRANCHDYNAMICLOSSES = as.numeric(BRANCHLOSSES) - SPDFIXEDLOSS,
                      SPDMARGINALPRICE = as.numeric(MARGINALPRICE)
                      )
        
        hvdcloss <- df1 %>% 
            select(DateTime, RunTime, Branch, 
                   SPDFIXEDLOSS,SPDBRANCHDYNAMICLOSSES) %>%
            filter(Branch %in% c('BEN_HAY1.1','BEN_HAY2.1','HAY_BEN1.1','HAY_BEN2.1')) %>%
            mutate(Island = ifelse(Branch %in% c('BEN_HAY1.1','BEN_HAY2.1'),'NI','SI')) %>%
            group_by(DateTime, RunTime,Island) %>%  
            summarise(SPDFIXEDLOSS = sum(SPDFIXEDLOSS),
                      SPDBRANCHDYNAMICLOSSES = sum(SPDBRANCHDYNAMICLOSSES)) %>%
            ungroup()
        
        hvdcloss <- hvdcloss %>% group_by(DateTime,RunTime) %>%  
            summarise(SPDFIXEDLOSS1 = sum(SPDFIXEDLOSS)/2) %>%
            ungroup() %>% inner_join(hvdcloss,by = c('DateTime','RunTime')) %>%
            transmute(DateTime, RunTime,Island,HVDCLOSS = SPDFIXEDLOSS1 +SPDBRANCHDYNAMICLOSSES)
        
        CompareBranch <- 
            df %>% full_join(df1,by=c('DateTime','RunTime','Branch','FromBus','ToBus')) %>%
            mutate(FLOWCOMPARE = round(SPDFLOWMWFROMTO - FlowMWFromTo,4),
                   VARIABLELOSSCOMPARE = round(SPDBRANCHDYNAMICLOSSES - DynamicLossMW,6),
                   FIXEDLOSSCOMPARE = round(SPDFIXEDLOSS - FixedLossMW,3)
                   )
        
        write.csv(CompareBranch,file = paste0('Output/',runname,'/',runname,'_CompareBranch.csv'),row.names = F)
    }    
    
    # Island Solution Comparison
    if (T) {    
        df <- read.csv(paste0('Output/',runname,'/',runname,'_IslandResults_TP.csv'),header = T, as.is = T)
        cn <- colnames(df)
        cn <- sapply(X = cn, gsub, pattern = "\\.", replacement = "")
        colnames(df) <- cn
        
        df <- read.csv(paste0('Output/',runname,'/',runname,'_SummaryResults_TP.csv'),header = T, as.is = T) %>%
            transmute(DateTime,RunTime,SystemOFV,SystemCost = SystemCost - SystemBenefit) %>%
            inner_join(df,by = c('DateTime','RunTime')) %>% 
            select(-c('FIR_reqMW','SIR_reqMW')) %>%
            mutate(Source = 'vSPD')
        
        
        df2 <- ObjectiveValue %>% group_by(DateTime,RunTime) %>% 
            summarise(TimeStamp = max(TimeStamp)) %>% ungroup() %>% 
            inner_join(ObjectiveValue, by = c('DateTime','RunTime','TimeStamp')) %>%
            select(-TimeStamp)
        
        df1 <- SolutionIsland  %>%
            rename(DateTime = INTERVAL, Island=ISLANDNAME ) %>%
            inner_join(hvdcloss,by = c('DateTime','RunTime','Island')) %>%
            inner_join(df2, by = c('DateTime','RunTime')) %>%
            transmute(DateTime,RunTime, SystemOFV = ObjectiveValue,
                      SystemCost = as.numeric(INTERVALCOST),
                      Island,GenMW = as.numeric(ENCLEARED),LoadMW = as.numeric(LOADMW),
                      BidLoadMW = as.numeric(DISPATCHBIDSCLEARED), 
                      IslandACLossMW = as.numeric(NETWORKLOSS) - HVDCLOSS,
                      HVDCFlowMW = ifelse(as.numeric(NETDCXFER) < 0 , 0, as.numeric(NETDCXFER)),
                      HVDCLossMW = HVDCLOSS, ReferencePriceMWh = as.numeric(REFERENCEPRICE),
                      FIRPriceMWh = as.numeric(RESERVEPRICESIXSEC), SIRPriceMWh = as.numeric(RESERVEPRICESIXTYSEC),
                      FIR_Clear = as.numeric(RESERVEACTUALSIXSEC), SIR_Clear = as.numeric(RESERVEACTUALSIXTYSEC),
                      FIR_Share = as.numeric(RESSENTFROM6S), SIR_Share = as.numeric(RESSENTFROM60S),
                      FIR_Receive = as.numeric(RESRECEIVEDAT6S), SIR_Receive = as.numeric(RESRECEIVEDAT60S),
                      FIR_Effective_CE = as.numeric(RESEFFECTIVETO6SCE), SIR_Effective_CE = as.numeric(RESEFFECTIVETO60SCE),
                      FIR_Effective_ECE = as.numeric(RESEFFECTIVETO6SECE), SIR_Effective_ECE = as.numeric(RESEFFECTIVETO60SECE),
                      Source = 'SPD'
                      )
        CompareIsland = rbind(df,df1) %>%
            gather(key = 'Item', value = 'Value',-c('DateTime','RunTime','Island','Source')) %>%
            spread(key = Source, value = Value) %>% mutate(vSPDvsSPD = round(vSPD - SPD,5)) %>%
            gather(key = 'Source', value = 'Value',-c('DateTime','RunTime','Island','Item')) %>%
            spread(key = Item, value = Value) %>%
            transmute(DateTime,RunTime,Island,Source,SystemOFV, SystemCost,GenMW,LoadMW,BidLoadMW,FIR_Clear,SIR_Clear,
                      ReferencePrice = ReferencePriceMWh, FIRPrice = FIRPriceMWh, SIRPrice = SIRPriceMWh,
                      IslandACLossMW,HVDCLossMW,HVDCFlowMW,FIR_Share,SIR_Share,FIR_Receive,SIR_Receive,
                      FIR_Effective_CE,SIR_Effective_CE,FIR_Effective_ECE,SIR_Effective_ECE) %>%
            arrange(Source,DateTime,RunTime,Island)
        
        write.csv(CompareIsland,file = paste0('Output/',runname,'/',runname,'_CompareIsland.csv'), row.names = F)
    }  
    
    # Node Solution Comparison
    if (T) {    
        df <- read.csv(paste0('Output/',runname,'/',runname,'_NodeResults_TP.csv'),header = T, as.is = T) 
        cn <- colnames(df)
        cn <- sapply(X = cn, gsub, pattern = "\\.", replacement = "")
        colnames(df) <- cn
        
        df1 <- SolutionPnode  %>%
            transmute(DateTime = INTERVAL,RunTime,Node=PNODENAME,
                      LOAD = as.numeric(LOAD),GENERATION = as.numeric(GENERATION),
                      PRICE = as.numeric(PRICE)
                      
            )
        CompareNode <- full_join(df,df1, by = c('DateTime','RunTime','Node')) %>%
            mutate(LOADCHECK = LoadMW - DeficitMW-LOAD, GENERATIONCHECK  = GenerationMW - GENERATION, 
                   PRICECHECK = PriceMWh - PRICE )
        
        write.csv(CompareNode,file = paste0('Output/',runname,'/',runname,'_CompareNode.csv'),row.names = F)
    }    
    
    # Bus Solution Comparison
    if (T) {    
        df <- read.csv(paste0('Output/',runname,'/',runname,'_BusResults_TP.csv'),header = T, as.is = T) 
        cn <- colnames(df)
        cn <- sapply(X = cn, gsub, pattern = "\\.", replacement = "")
        colnames(df) <- cn
        
        df1 <- SolutionBus %>%
            transmute(DateTime = INTERVAL, RunTime, Bus = as.integer(ID_BUS),
                      LOAD = as.numeric(LOAD),GENERATION = as.numeric(GENERATION),
                      PRICE = as.numeric(PRICE)
                      
            )
        CompareBus <- full_join(df,df1, by = c('DateTime','RunTime','Bus')) %>%
            mutate(PRICECHECK = PriceMWh - PRICE, LOADCHECK = round(LoadMW - LOAD,4), 
                   GENERATIONCHECK = round(GenerationMW - GENERATION,4)
                   )
        write.csv(CompareBus,file = paste0('Output/',runname,'/',runname,'_CompareBus.csv'),row.names = F)
    }    
    
    # TraderPeriod Solution Comparison
    if (T) {    
        df <- read.csv(paste0('Output/',runname,'/',runname,'_OfferResults_TP.csv'),header = T, as.is = T) 
        cn <- colnames(df)
        cn <- sapply(X = cn, gsub, pattern = "\\.", replacement = "")
        colnames(df) <- cn
        
        df_bid <- read.csv(paste0('Output/',runname,'/',runname,'_BidResults_TP.csv'),header = T, as.is = T) 
        if (nrow(df_bid) > 0) {
          cn <- colnames(df_bid)
          cn <- sapply(X = cn, gsub, pattern = "\\.", replacement = "")
          colnames(df_bid) <- cn
          df_bid <- df_bid %>% rename(Offer = Bid)
          df <- full_join(df,df_bid, by = c('DateTime','RunTime','Offer','Trader')) 
          df[is.na(df)] <- 0
          
          df <- df %>% mutate(GenerationMW = GenerationMW - ClearedBidMW) %>%
            select(-TotalBidMW, -ClearedBidMW)
          
        }
        
        
        df1 <- SolutionTrdrPrd %>%
            transmute(DateTime = INTERVAL, RunTime, Offer = PNODENAME,
                      GENERATION = as.numeric(MWCLEARED), 
                      RESERVECLEAREDSIXSEC = as.numeric(RESERVECLEAREDSIXSEC),
                      RESERVECLEAREDSIXTYSEC = as.numeric(RESERVECLEAREDSIXTYSEC),
                      UPRAMPRATE = as.numeric(UPRAMPRATE), 
                      DNRAMPRATE = as.numeric(DNRAMPRATE) ) %>% 
            group_by(DateTime, RunTime, Offer) %>%
            summarise(GENERATION = sum(GENERATION), 
                      RESERVECLEAREDSIXSEC = sum(RESERVECLEAREDSIXSEC),
                      RESERVECLEAREDSIXTYSEC = sum(RESERVECLEAREDSIXTYSEC),
                      UPRAMPRATE = max(UPRAMPRATE), 
                      DNRAMPRATE = max(DNRAMPRATE)) %>% ungroup()
            
        
        CompareTraderPeriod <- full_join(df,df1, by = c('DateTime','RunTime','Offer')) %>%
            mutate(GENERATIONCHECK = round(GenerationMW - GENERATION,4),
                   FIRCHECK  = round(FIRMW - RESERVECLEAREDSIXSEC,4),
                   SIRCHECK  = round(SIRMW - RESERVECLEAREDSIXTYSEC,4)
            )
        
        write.csv(CompareTraderPeriod,file = paste0('Output/',runname,'/',runname,'_CompareTraderPeriod.csv'),row.names = F)
    }  
    
    # Constraint Solution Comparison
    if (T) {    
        df <- read.csv(paste0('Output/',runname,'/',runname,'_MNodeConstraintResults_TP.csv'),
                       header = T, as.is = T) %>% 
            transmute(DateTime,RunTime,ConstraintName = MNodeConstraint, ConstraintType = 'MnCnst',
                      LHSValue = `LHS..MW.`, Sense = `Sense...1.....0....1....`,
                      RHSValue = `RHS..MW.`, MarginalPrice = `Price....MWh.`)
        
        df <- read.csv(paste0('Output/',runname,'/',runname,'_BrConstraintResults_TP.csv'),
                       header = T, as.is = T) %>% 
            transmute(DateTime,RunTime,ConstraintName = BranchConstraint, ConstraintType = 'BrCnst',
                      LHSValue = `LHS..MW.`, Sense = `Sense...1.....0....1....`,
                      RHSValue = `RHS..MW.`, MarginalPrice = `Price....MWh.`) %>% rbind(df)
        
        df1 <- SolutionCnstr %>%
            transmute(DateTime = INTERVAL, RunTime, ConstraintName = trimws(CONSTRAINTNAME),
                      ConstraintType = CONSTRAINTTYPE, CONSTRAINTVALUE = as.numeric(CONSTRAINTVALUE),
                      CONSTRAINTLIMIT = as.numeric(LOWERLIMITVALID) * as.numeric(LOWERLIMIT) + 
                          as.numeric(UPPERLIMITVALID) * as.numeric(UPPERLIMIT),
                      MARGINALPRICE = as.numeric(LOWERLIMITVALID) * as.numeric(LOWERMARGINALPRICE) + 
                          as.numeric(UPPERLIMITVALID) * as.numeric(UPPERMARGINALPRICE))
        
        CompareConstraint <- full_join(df,df1, by = c('DateTime','RunTime','ConstraintName','ConstraintType')) %>%
            mutate(LHSCHECK = round(LHSValue - CONSTRAINTVALUE,4),
                   RHSCHECK  = round(RHSValue - CONSTRAINTLIMIT,4),
                   MARGINALPRICECHECK  = round(MarginalPrice - MARGINALPRICE,4)
            )
        
        write.csv(CompareConstraint,file = paste0('Output/',runname,'/',runname,'_CompareConstraint.csv'),row.names = F)
    } 
}





        

