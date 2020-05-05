{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE GADTs               #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE PolyKinds           #-}
{-# LANGUAGE QuasiQuotes         #-}
{-# LANGUAGE TemplateHaskell     #-}
{-# LANGUAGE TypeFamilies        #-}
{-# LANGUAGE TypeOperators       #-}
{-# LANGUAGE TypeApplications    #-}
{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE Rank2Types          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections       #-}

module BlueRipple.Data.DataFrames
  ( module BlueRipple.Data.DataSourcePaths
  , module BlueRipple.Data.DataFrames
  )
where

import           BlueRipple.Data.DataSourcePaths
import qualified Knit.Report                   as K

import qualified Control.Foldl                 as FL
import           Control.Monad.IO.Class         ( MonadIO(liftIO) )
import qualified Data.List                     as L
import           Data.Maybe                     ( catMaybes )
import           Data.Proxy                     ( Proxy(..) )
import qualified Data.Text                     as T
import           Data.Text                      ( Text )
import qualified Data.Vinyl                    as V
import qualified Frames                        as F
import qualified Frames.CSV                    as F
import qualified Frames.InCore                 as FI
import qualified Frames.TH                     as F

import qualified Pipes                         as P
import qualified Pipes.Prelude                 as P

import qualified Streamly as Streamly
import qualified Streamly.Prelude as Streamly

import qualified Frames.ParseableTypes         as FP
import qualified Frames.MaybeUtils             as FM
import qualified Frames.Streamly as Frames.Streamly

-- pre-declare cols with non-standard types
F.declareColumn "Date" ''FP.FrameDay

F.tableTypes "TotalSpending" (framesPath totalSpendingCSV)

F.tableTypes' (F.rowGen (framesPath forecastAndSpendingCSV)) { F.rowTypeName = "ForecastAndSpending"
                                                , F.columnUniverse = Proxy :: Proxy FP.ColumnsWithDayAndLocalTime
                                                }

F.tableTypes "ElectionResults" (framesPath electionResultsCSV)
F.tableTypes "AngryDems" (framesPath angryDemsCSV)
F.tableTypes "HouseElections" (framesPath houseElectionsCSV)
F.tableTypes "PresidentialByState" (framesPath presidentialByStateCSV)
F.tableTypes "ContextDemographics" (framesPath contextDemographicsCSV)
F.tableTypes "CVAPByCDAndRace_Raw" (framesPath cvapByCDAndRace2014_2018CSV)
F.tableTypes "PopulationsByCounty_Raw" (framesPath popsByCountyCSV) 
F.tableTypes "PUMA2012ToCD116"       (framesPath puma2012ToCD116CSV)
F.tableTypes "PUMA2000ToCD116"       (framesPath puma2000ToCD116CSV)

F.tableTypes "TurnoutASR"          (framesPath detailedASRTurnoutCSV)
F.tableTypes "TurnoutASE"          (framesPath detailedASETurnoutCSV)
F.tableTypes "StateTurnout"        (framesPath stateTurnoutCSV)
F.tableTypes "ASRDemographics" (framesPath ageSexRaceDemographicsLongCSV)
F.tableTypes "ASEDemographics" (framesPath ageSexEducationDemographicsLongCSV)
F.tableTypes "EdisonExit2018" (framesPath exitPoll2018CSV)

F.tableTypes "ElectoralCollege" (framesPath electorsCSV)

F.tableTypes "States" (framesPath statesCSV)
F.tableTypes "StateCountyCD" (framesPath stateCounty116CDCSV)
F.tableTypes "StateCountyTractPUMA" (framesPath stateCountyTractPUMACSV)
F.tableTypes "CountyToCD116" (framesPath countyToCD116CSV)

loadToRecStream
  :: forall rs m
  . ( Monad m
    , F.ReadRec rs
    , FI.RecVec rs
    , V.RMap rs
    )
  => F.ParserOptions
  -> FilePath
  -> (F.Record rs -> Bool)
  -> Streamly.SerialT m (F.Record rs)
loadToRecStream po fp filterF =
  Streamly.filter filterF $ Frames.Streamly.streamTable po fp
{-# INLINEABLE loadToRecStream #-}

loadToMaybeRecStream
  :: forall rs rs' r
  . (K.KnitEffects r
    , F.ReadRec rs
    , FI.RecVec rs
    , V.RMap rs
    )
  => F.ParserOptions
  -> FilePath
  -> (F.Rec (Maybe F.:. F.ElField) rs -> Bool)
  -> Streamly.SerialT (K.Sem r) (F.Rec (Maybe F.:. F.ElField) rs')
loadToMaybeRecStream po fp filterF = do
  let s = Streamly.map (F.rcast @rs')
          $ Streamly.filter filterF
          $ Frames.Streamly.streamTableMaybe po fp
  let reportRows :: Foldable f => Streamly.SerialT (K.Sem r) x -> FilePath -> K.Sem r ()
      reportRows s fn = do
        sLen <- Streamly.length s
        K.logLE K.Diagnostic
          $  T.pack (show s)
          <> " rows in "
          <> T.pack fn
  Streamly.yieldM $ reportRows s fp
  s
{-# INLINEABLE loadToMaybeRecStream #-}

loadToFrame
  :: forall rs effs
   . ( MonadIO (K.Sem effs)
     , K.LogWithPrefixesLE effs
     , F.ReadRec rs
     , FI.RecVec rs
     , V.RMap rs
     )
  => F.ParserOptions
  -> FilePath
  -> (F.Record rs -> Bool)
  -> K.Sem effs (F.FrameRec rs)
loadToFrame po fp filterF = do
  frame <- F.inCoreAoS $ toPipes $ loadToRecStream po fp filterF
  let reportRows :: Foldable f => f x -> FilePath -> K.Sem effs ()
      reportRows f fn =
        K.logLE K.Diagnostic
          $  T.pack (show $ FL.fold FL.length f)
          <> " rows in "
          <> T.pack fn
  reportRows frame fp
  return frame
{-# INLINEABLE loadToFrame #-}

toPipes :: Monad m => Streamly.SerialT m a -> P.Producer a m ()
toPipes = P.unfoldr unconsS
    where
    -- Adapt S.uncons to return an Either instead of Maybe
    unconsS s = Streamly.uncons s >>= maybe (return $ Left ()) (return . Right)
{-# INLINEABLE toPipes #-}

processMaybeRecStream
  :: ( K.LogWithPrefixesLE r
     , FI.RecVec rs
     , V.RFoldMap rs
     , V.RPureConstrained V.KnownField rs
     , V.RecApplicative rs
     , V.RApply rs
--     , Show (F.Rec (Maybe F.:. F.ElField) rs)
     )
  => (F.Rec (Maybe F.:. F.ElField) rs -> (F.Rec (Maybe F.:. F.ElField) rs)) -- fix any Nothings you need to/can
  -> (F.Record rs -> Bool) -- filter after removing Nothings
  -> Streamly.SerialT (K.Sem r) (F.Rec (Maybe F.:. F.ElField) rs)
  -> Streamly.SerialT (K.Sem r) (F.Record rs)
processMaybeRecStream fixMissing filterRows maybeRecStream =

  K.wrapPrefix "maybeRecsToFrame" $ do
    let missingPre = FM.whatsMissing maybeRecs
        fixed       = fmap fixMissing maybeRecs
        missingPost = FM.whatsMissing fixed
        droppedMissing = catMaybes $ fmap F.recMaybe fixed
        filtered = L.filter filterRows droppedMissing
    K.logLE K.Diagnostic "Input rows:"
    K.logLE K.Diagnostic (T.pack $ show $ length maybeRecs)
    K.logLE K.Diagnostic "Missing Data before fixing:"
    K.logLE K.Diagnostic (T.pack $ show missingPre)
    K.logLE K.Diagnostic "Missing Data after fixing:"
    K.logLE K.Diagnostic (T.pack $ show missingPost)
    K.logLE K.Diagnostic "Rows after fixing and dropping missing:"
    K.logLE K.Diagnostic (T.pack $ show $ length droppedMissing)
    K.logLE K.Diagnostic "Rows after filtering: "
    K.logLE K.Diagnostic (T.pack $ show $ length filtered)    
    return filtered
{-# INLINEABLE processMaybeRecStream #-}

{-
loadToFrame
  :: forall rs effs
   . ( MonadIO (K.Sem effs)
     , K.LogWithPrefixesLE effs
     , F.ReadRec rs
     , FI.RecVec rs
     , V.RMap rs
     )
  => F.ParserOptions
  -> FilePath
  -> (F.Record rs -> Bool)
  -> K.Sem effs (F.FrameRec rs)
loadToFrame po fp filterF = do
  let producer = F.readTableOpt po fp P.>-> P.filter filterF
  frame <- liftIO $ F.inCoreAoS producer
  let reportRows :: Foldable f => f x -> FilePath -> K.Sem effs ()
      reportRows f fn =
        K.logLE K.Diagnostic
          $  T.pack (show $ FL.fold FL.length f)
          <> " rows in "
          <> T.pack fn
  reportRows frame fp
  return frame

fromPipes :: (Streamly.IsStream t, Streamly.MonadAsync m) => P.Producer a m r -> t m a
fromPipes = Streamly.unfoldrM unconsP
    where
    -- Adapt P.next to return a Maybe instead of Either
    unconsP p = P.next p >>= either (\_ -> return Nothing) (return . Just)
-}
  
loadToRecList
  :: forall rs effs
   . ( MonadIO (K.Sem effs)
     , K.LogWithPrefixesLE effs
     , F.ReadRec rs
     , FI.RecVec rs
     , V.RMap rs
     )
  => F.ParserOptions
  -> FilePath
  -> (F.Record rs -> Bool)
  -> K.Sem effs [F.Record rs]
loadToRecList po fp filterF = do
  let rawRecStream = fromPipes $ F.readTableOpt po fp -- MonadSafe m => SerialT m (F.Record rs)
      filtered = Streamly.filter filterF rawRecStream  
  asRecList <- liftIO $ F.runSafeT $ Streamly.toList filtered
  -- NB: if we didn't already need to be strict, this would require at least spine strictness
  -- to compute the length!
  let reportRows :: Foldable f => f x -> FilePath -> K.Sem effs ()
      reportRows f fn =
        K.logLE K.Diagnostic
          $  T.pack (show $ FL.fold FL.length f)
          <> " rows in "
          <> T.pack fn
  reportRows asRecList fp
  return asRecList


-- This goes through maybeRecs so we can see if we're dropping rows.  Slightly slower and more
-- memory intensive (I assume)
-- but since we will cache anything big post-processed, that seems like a good trade often.
loadToRecListChecked
  :: forall rs effs
   . ( MonadIO (K.Sem effs)
     , K.LogWithPrefixesLE effs
     , F.ReadRec rs
     , FI.RecVec rs
     , V.RFoldMap rs
     , V.RMap rs
     , V.RPureConstrained V.KnownField rs
     , V.RecApplicative rs
     , V.RApply rs
     , rs F.⊆ rs
     )
  => F.ParserOptions
  -> FilePath
  -> (F.Record rs -> Bool)
  -> K.Sem effs [F.Record rs]
loadToRecListChecked po fp filterF = loadToMaybeRecs @rs @rs po (const True) fp >>= processMaybeRecs id filterF
--  traverse (maybeRecsToFrame id filterF) $ loadToMaybeRecs po (const True) fp

loadToMaybeRecs
  :: forall rs rs' effs
   . ( MonadIO (K.Sem effs)
     , K.LogWithPrefixesLE effs
     , F.ReadRec rs'
     , FI.RecVec rs'
     , V.RMap rs'
     , rs F.⊆ rs'
     )
  => F.ParserOptions
  -> (F.Rec (Maybe F.:. F.ElField) rs -> Bool)
  -> FilePath
  -> K.Sem effs [F.Rec (Maybe F.:. F.ElField) rs]
loadToMaybeRecs po filterF fp = do
  let producerM = F.readTableMaybeOpt @_ @rs' po fp --P.>-> P.filter filterF
  listM :: [F.Rec (Maybe F.:. F.ElField) rs] <-
    liftIO
    $     F.runSafeEffect
    $     P.toListM
    $     producerM
    P.>-> P.map F.rcast
    P.>-> P.filter filterF
  let reportRows :: Foldable f => f x -> FilePath -> K.Sem effs ()
      reportRows f fn =
        K.logLE K.Diagnostic
          $  T.pack (show $ FL.fold FL.length f)
          <> " rows in "
          <> T.pack fn
  reportRows listM fp
  return listM

processMaybeRecs
  :: ( K.LogWithPrefixesLE effs
     , FI.RecVec rs
     , V.RFoldMap rs
     , V.RPureConstrained V.KnownField rs
     , V.RecApplicative rs
     , V.RApply rs
--     , Show (F.Rec (Maybe F.:. F.ElField) rs)
     )
  => (F.Rec (Maybe F.:. F.ElField) rs -> (F.Rec (Maybe F.:. F.ElField) rs)) -- fix any Nothings you need to/can
  -> (F.Record rs -> Bool) -- filter after removing Nothings
  -> [F.Rec (Maybe F.:. F.ElField) rs]
  -> K.Sem effs [F.Record rs]
processMaybeRecs fixMissing filterRows maybeRecs =
  K.wrapPrefix "maybeRecsToFrame" $ do
    let missingPre = FM.whatsMissing maybeRecs
        fixed       = fmap fixMissing maybeRecs
        missingPost = FM.whatsMissing fixed
        droppedMissing = catMaybes $ fmap F.recMaybe fixed
        filtered = L.filter filterRows droppedMissing
    K.logLE K.Diagnostic "Input rows:"
    K.logLE K.Diagnostic (T.pack $ show $ length maybeRecs)
    K.logLE K.Diagnostic "Missing Data before fixing:"
    K.logLE K.Diagnostic (T.pack $ show missingPre)
    K.logLE K.Diagnostic "Missing Data after fixing:"
    K.logLE K.Diagnostic (T.pack $ show missingPost)
    K.logLE K.Diagnostic "Rows after fixing and dropping missing:"
    K.logLE K.Diagnostic (T.pack $ show $ length droppedMissing)
    K.logLE K.Diagnostic "Rows after filtering: "
    K.logLE K.Diagnostic (T.pack $ show $ length filtered)    
    return filtered
