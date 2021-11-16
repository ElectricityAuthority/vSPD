library(dplyr)
library(tidyr)
library(lubridate)
library(readr)
library(stringr)
library(data.table)

rm(list = ls())
this.dir <- dirname(parent.frame(2)$ofile)
setwd(this.dir)

library(gdxrrw,lib.loc = 'C:/R_libraries' )
igdx('C:/R_libraries')


create_empty_dataframe <- function(colname=NULL, type=NULL) {
  if (is.null(colname)) {
    return(NULL)
  } else if (length(colname) != length(type)) {
    print("Number of column name does not match number of colume type")
    return(NULL)
  } else {
    x <- data.frame()
    for (i in (1:length(colname))){
      cn <- colname[i]
      tp <- type[i]
      if (tp == 'num') {
        x[cn] <- numeric()    
      } else {
        x[cn] <- character()    
      }
    }
    return(x)
  }
  
}

# Function to convert a dataframe to GAMS set or parameter symbol
gams_symbol <- function(df,symName,type = 'set') {
  if (type %in% c('set','Set','SET')) {
    df <- df %>% mutate_all(as.factor)
  } else {
    n <- ncol(df)-1    
    df <- df %>% mutate_at((1:n),as.factor) %>% mutate_at(n+1, as.numeric) 
  }
  df <- df %>% setattr('symName',symName) 
}

# Function to create vSPD override gdx file
create_gdx_offer_overrides <- function(overrides, gdxname) {
  
  # create demand overrides (empty)
  if ('demandOverrides' %in% names(overrides)) {
    df <- overrides$demandOverrides
  } else {
    df <- create_empty_dataframe(colname = c('Period','Pnone','Method','Value'),
                                 type = c('chr','chr','chr','num'))
  }
  demandOverrides <- gams_symbol(df,'demandOverrides','par')
  
  
  # create offer parameter overrides (empty)
  if ('offerParameterOverrides' %in% names(overrides)) {
    df <- overrides$offerParameterOverrides
  } else {
    df <- create_empty_dataframe(colname = c('Period','Offer','Param','Value'),
                                 type = c('chr','chr','chr','num'))
  }
  offerParameterOverrides <- gams_symbol(df,'offerParameterOverrides','par')
  
  
  # create sustained PLSR offer overrides (empty)
  if ('sustainedPLSROfferOverrides' %in% names(overrides)) {
    df <- overrides$sustainedPLSROfferOverrides
  } else {
    df <- create_empty_dataframe(colname = c('Period','Offer','Band','PlsrCompnt','Value'),
                                 type = c('chr','chr','chr','chr','num'))
  }
  sustainedPLSROfferOverrides <- gams_symbol(df,'sustainedPLSROfferOverrides','par')
  
  
  # create fast PLSR offer overrides (empty)
  if ('fastPLSROfferOverrides' %in% names(overrides)) {
    df <- overrides$fastPLSROfferOverrides
  } else {
    df <- create_empty_dataframe(colname = c('Period','Offer','Band','PlsrCompnt','Value'),
                                 type = c('chr','chr','chr','chr','num'))
  }
  fastPLSROfferOverrides <- gams_symbol(df,'fastPLSROfferOverrides','par')
  
  
  # create sustained TWDR offer overrides (empty)
  if ('sustainedTWDROfferOverrides' %in% names(overrides)) {
    df <- overrides$sustainedTWDROfferOverrides
  } else {
    df <- create_empty_dataframe(colname = c('Period','Offer','Band','TwdrCompnt','Value'),
                                 type = c('chr','chr','chr','chr','num'))
  }
  sustainedTWDROfferOverrides <- gams_symbol(df,'sustainedTWDROfferOverrides','par')
  
  
  # create fast TWDR offer overrides (empty)
  if ('fastTWDROfferOverrides' %in% names(overrides)) {
    df <- overrides$fastTWDROfferOverrides
  } else {
    df <- create_empty_dataframe(colname = c('Period','Offer','Band','TwdrCompnt','Value'),
                                 type = c('chr','chr','chr','chr','num'))
  }
  fastTWDROfferOverrides <- gams_symbol(df,'fastTWDROfferOverrides','par')
  
  
  # create sustained ILR offer overrides (empty)
  if ('sustainedILROfferOverrides' %in% names(overrides)) {
    df <- overrides$sustainedILROfferOverrides
  } else {
    df <- create_empty_dataframe(colname = c('Period','Offer','Band','PlsrCompnt','Value'),
                                 type = c('chr','chr','chr','chr','num'))
  }
  sustainedILROfferOverrides <- gams_symbol(df,'sustainedILROfferOverrides','par')
  
  
  # create fast ILR offer overrides (empty)
  if ('fastILROfferOverrides' %in% names(overrides)) {
    df <- overrides$fastILROfferOverrides
  } else {
    df <- create_empty_dataframe(colname = c('Period','Offer','Band','PlsrCompnt','Value'),
                                 type = c('chr','chr','chr','chr','num'))
  }
  fastILROfferOverrides <- gams_symbol(df,'fastILROfferOverrides','par')
  
  
  # create energy bid overrides (empty)
  if ('energyBidOverrides' %in% names(overrides)) {
    df <- overrides$energyBidOverrides
  } else {
    df <- create_empty_dataframe(colname = c('Period','Bid','Band','bidCompnt','Value'),
                                 type = c('chr','chr','chr','chr','num'))
  }
  energyBidOverrides <- gams_symbol(df,'energyBidOverrides','par')
  
  
  # create dispatch-able energy bid overrides (empty)
  if ('dispatchableEnergyBidOverrides' %in% names(overrides)) {
    df <- overrides$dispatchableEnergyBidOverrides
  } else {
    df <- create_empty_dataframe(colname = c('Period','Bid','Value'),
                                 type = c('chr','chr','num'))
  }
  dispatchableEnergyBidOverrides <- gams_symbol(df,'dispatchableEnergyBidOverrides','par')
  
  
  if ('energyOfferOverrides' %in% names(overrides)) {
    df <- overrides$energyOfferOverrides
  } else {
    df <- create_empty_dataframe(colname = c('Period','Offer','Band','ofrCompnt','Value'),
                                 type = c('chr','chr','chr','chr','num'))
  }
  energyOfferOverrides <- gams_symbol(df,'energyOfferOverrides','par')
  
  
  
  wgdx.lst (gdxName = gdxname, squeeze = 'e',
            demandOverrides,    
            energyOfferOverrides,
            offerParameterOverrides,
            fastILROfferOverrides,
            sustainedILROfferOverrides,
            fastPLSROfferOverrides,
            sustainedPLSROfferOverrides,
            fastTWDROfferOverrides,
            sustainedTWDROfferOverrides,
            energyBidOverrides,
            dispatchableEnergyBidOverrides
  )
  
  
  return(gdxname)
  
}


# Demand overrides
if (F) { 
  df <- read.csv('export rec.csv') %>%
    gather(key = 'ValueType', value = 'Value',-Period,-Node) %>%
    filter(!is.na(Value)) %>%
    mutate(Period = as.POSIXct(strptime(Period,'%d/%m/%Y %H:%M'))) %>%
    mutate(Period = format(Period,'%d-%b-%Y %H:%M')) %>%
    mutate(Period = toupper(Period))


overrides <- list(demandOverrides = df) 

create_gdx_offer_overrides(overrides,gdxname = 'export rec.gdx')
}


# Energy offer overrides
if (F) {
  energyOfferOverrides <- data.frame(datetime = paste0('TP',1:50),
                                     offer = 'JRD1101 JRD0'
  ) %>%
    merge(data.frame(band = paste0('t',1:5)), all=T) %>%
    merge(data.frame(offerCompnt = c('i_GenerationMWOffer',
                                     'i_GenerationMWOfferPrice')), all=T) %>%
    mutate(Value = 'EPS')
  
  overrides <- list(energyOfferOverrides = energyOfferOverrides) 
  
  create_gdx_offer_overrides(overrides,gdxname = 'test.gdx')
}

