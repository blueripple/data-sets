{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module BlueRipple.Data.DataSourcePaths where

import qualified Paths_blueripple_data_sets    as Paths
--import qualified Frames.TH                     as F

thFramesDataDir :: FilePath
thFramesDataDir = "./data/"

electionDir :: FilePath
electionDir = "election/"

demographicDir :: FilePath
demographicDir = "demographic/"

campaignFinanceDir :: FilePath
campaignFinanceDir = "campaign-finance/"

dictionariesDir :: FilePath
dictionariesDir = "dictionaries/"

otherDir :: FilePath
otherDir = "other/"

totalSpendingCSV :: FilePath
totalSpendingCSV =
  campaignFinanceDir ++ "allSpendingThrough20181106.csv"

totalSpendingBeforeCSV :: FilePath 
totalSpendingBeforeCSV =
  campaignFinanceDir ++ "allSpendingThrough20180731.csv"

totalSpendingDuringCSV :: FilePath
totalSpendingDuringCSV =
  campaignFinanceDir ++ "allSpendingFrom20180801Through20181106.csv"

forecastAndSpendingCSV :: FilePath   
forecastAndSpendingCSV =
  campaignFinanceDir ++ "forecastAndSpending.csv"
  
houseElectionsCSV :: FilePath
houseElectionsCSV = electionDir ++ "1976-2018-house_v5_u1.csv"

allMoney2020CSV :: FilePath
allMoney2020CSV = campaignFinanceDir ++ "allMoney_20200902.csv"

detailedASRTurnoutCSV :: FilePath 
detailedASRTurnoutCSV =
  electionDir ++ "DetailedTurnoutByAgeSexRace2010-2018.csv"

detailedASETurnoutCSV :: FilePath 
detailedASETurnoutCSV =
  electionDir ++ "DetailedTurnoutByAgeSexEducation2010-2018.csv"

stateTurnoutCSV :: FilePath 
stateTurnoutCSV = electionDir ++ "StateTurnout.csv"

electionResultsCSV :: FilePath
electionResultsCSV = electionDir ++ "electionResult2018.csv"

exitPoll2018CSV :: FilePath 
exitPoll2018CSV = electionDir ++ "EdisonExitPoll2018.csv"

presidentialByStateCSV :: FilePath 
presidentialByStateCSV = electionDir ++ "1976-2016-president.csv"

electorsCSV :: FilePath 
electorsCSV = electionDir ++ "electoral_college.csv"

housePolls2020CSV :: FilePath
housePolls2020CSV = electionDir ++ "HousePolls538_20200904.csv"

contextDemographicsCSV :: FilePath
contextDemographicsCSV =
  demographicDir ++ "contextDemographicsByDistrict.csv"

ageSexRaceDemographicsLongCSV :: FilePath
ageSexRaceDemographicsLongCSV =
  demographicDir ++ "ageSexRaceDemographics2010-2018.csv"

ageSexEducationDemographicsLongCSV :: FilePath 
ageSexEducationDemographicsLongCSV =
  demographicDir ++ "ageSexEducationDemographics2010-2018.csv"

cvapByCDAndRace2014_2018CSV :: FilePath 
cvapByCDAndRace2014_2018CSV =
  demographicDir ++ "CVAPByCD2014-2018.csv"

popsByCountyCSV :: FilePath 
popsByCountyCSV = demographicDir ++ "populationsByCounty.csv"

puma2012ToCD116CSV :: FilePath 
puma2012ToCD116CSV = demographicDir ++ "puma2012ToCD116.csv"

puma2000ToCD116CSV :: FilePath 
puma2000ToCD116CSV = demographicDir ++ "puma2000ToCD116.csv"

statesCSV :: FilePath 
statesCSV = dictionariesDir ++ "states.csv"

stateCounty116CDCSV :: FilePath 
stateCounty116CDCSV = dictionariesDir ++ "StateCounty116CD.csv"

stateCountyTractPUMACSV :: FilePath 
stateCountyTractPUMACSV = dictionariesDir ++ "2010StateCountyTractPUMA.csv"

countyToCD116CSV :: FilePath
countyToCD116CSV = dictionariesDir ++ "2010CountyToCD116.csv"

cd116ToStateLeg2016CSV :: FilePath
cd116ToStateLeg2016CSV = dictionariesDir ++ "cd116ToStateLeg2016.csv"

puma2012ToStateLeg2016CSV :: FilePath
puma2012ToStateLeg2016CSV = dictionariesDir ++ "puma2012ToStateLeg2016.csv"


angryDemsCSV :: FilePath 
angryDemsCSV = otherDir ++ "angryDemsContributions20181203.csv"

framesPath :: FilePath -> FilePath
framesPath x = thFramesDataDir ++ x

usePath :: FilePath -> IO FilePath
usePath x = fmap (\dd -> dd ++ "/" ++ x) Paths.getDataDir

{-
ccesTSV :: FilePath = dataDir ++ "CCES_cumulative_2006_2018.txt"

-- the things I would make Categorical are already ints. :(
ccesRowGen = (F.rowGen ccesTSV) { F.tablePrefix = "CCES"
                                , F.separator   = "\t"
                                , F.rowTypeName = "CCES"
                                }
-}

{-
turnoutCSV :: FilePath = dataDir ++ "Turnout2012-2018.csv"
identityDemographics2012CSV :: FilePath =
  dataDir ++ "identityDemographicsByDistrict2012.csv"
identityDemographics2014CSV :: FilePath =
  dataDir ++ "identityDemographicsByDistrict2014.csv"
identityDemographics2016CSV :: FilePath =
  dataDir ++ "identityDemographicsByDistrict2016.csv"
identityDemographics2017CSV :: FilePath =
  dataDir ++ "identityDemographicsByDistrict2017.csv"
-}
