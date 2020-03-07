{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module BlueRipple.Data.DataSourcePaths where

import qualified Paths_blueripple_data_sets    as Paths
--import qualified Frames.TH                     as F

thFramesDataDir = "./data/"
electionDir = "election/"
demographicDir = "demographic/"
campaignFinanceDir = "campaign-finance/"
dictionariesDir = "dictionaries/"
otherDir = "other/"

totalSpendingCSV :: FilePath =
  campaignFinanceDir ++ "allSpendingThrough20181106.csv"
totalSpendingBeforeCSV :: FilePath =
  campaignFinanceDir ++ "allSpendingThrough20180731.csv"
totalSpendingDuringCSV :: FilePath =
  campaignFinanceDir ++ "allSpendingFrom20180801Through20181106.csv"
forecastAndSpendingCSV :: FilePath =
  campaignFinanceDir ++ "forecastAndSpending.csv"

houseElectionsCSV :: FilePath = electionDir ++ "1976-2018-house_v5.csv"
detailedASRTurnoutCSV :: FilePath =
  electionDir ++ "DetailedTurnoutByAgeSexRace2010-2018.csv"
detailedASETurnoutCSV :: FilePath =
  electionDir ++ "DetailedTurnoutByAgeSexEducation2010-2018.csv"
stateTurnoutCSV :: FilePath = electionDir ++ "StateTurnout.csv"
electionResultsCSV :: FilePath = electionDir ++ "electionResult2018.csv"
exitPoll2018CSV :: FilePath = electionDir ++ "EdisonExitPoll2018.csv"
presidentialByStateCSV :: FilePath = electionDir ++ "1976-2016-president.csv"
electorsCSV :: FilePath = electionDir ++ "electoral_college.csv"

contextDemographicsCSV :: FilePath =
  demographicDir ++ "contextDemographicsByDistrict.csv"
ageSexRaceDemographicsLongCSV :: FilePath =
  demographicDir ++ "ageSexRaceDemographics2010-2018.csv"
ageSexEducationDemographicsLongCSV :: FilePath =
  demographicDir ++ "ageSexEducationDemographics2010-2018.csv"
cvapByCDAndRace2014_2018 :: FilePath =
  demographicDir ++ "CVAPByCD2014-2018.csv"


angryDemsCSV :: FilePath = otherDir ++ "angryDemsContributions20181203.csv"

statesCSV :: FilePath = dictionariesDir ++ "states.csv"

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
