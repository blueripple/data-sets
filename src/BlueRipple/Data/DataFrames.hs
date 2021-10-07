{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE CPP                 #-}
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
{-# OPTIONS_GHC -fplugin=Polysemy.Plugin #-}

module BlueRipple.Data.DataFrames
  ( module BlueRipple.Data.DataSourcePaths
  , module BlueRipple.Data.DataFrames
  )
where

import Prelude hiding (State)
import           BlueRipple.Data.DataSourcePaths
import qualified Knit.Report                   as K
import qualified Knit.Utilities.Streamly as K

import qualified Polysemy as Polysemy
import qualified Polysemy.Error as Polysemy

import qualified Control.Foldl                 as FL
import qualified Control.Monad.Catch.Pure      as Exceptions
import qualified Data.List                     as L
import qualified Data.Map as Map
import qualified Data.Text                     as T
import qualified Data.Vinyl                    as V
import qualified Frames                        as F
import qualified Frames.CSV                    as F
import qualified Frames.InCore                 as FI

import qualified Pipes                         as P
import qualified Pipes.Prelude                 as P

import qualified Text.Pandoc                   as Pandoc

import qualified Streamly.Prelude as Streamly
import qualified Streamly.Internal.Data.Fold as Streamly.Fold

#if MIN_VERSION_streamly(0,8,0)
#else
import qualified Streamly as Streamly
--import qualified Streamly.Internal.Prelude as Streamly
#endif

import qualified Frames.ParseableTypes         as FP
import qualified Frames.MaybeUtils             as FM
import qualified Frames.Streamly.CSV           as Frames.Streamly
import qualified Frames.Streamly.InCore        as Frames.Streamly
import qualified Frames.Streamly.TH as FS

-- pre-declare cols with non-standard types
F.declareColumn "Date" ''FP.FrameDay
F.declareColumn "StartDate" ''FP.FrameDay
F.declareColumn "EndDate" ''FP.FrameDay
F.declareColumn "ElectionDate" ''FP.FrameDay


FS.tableTypes "TotalSpending" (framesPath totalSpendingCSV)

FS.tableTypes' (FS.rowGen (framesPath forecastAndSpendingCSV)) { FS.rowTypeName = "ForecastAndSpending"
                                                               , FS.columnUniverse = Proxy :: Proxy FP.ColumnsWithDayAndLocalTime
                                                               }

FS.tableTypes "ElectionResults" (framesPath electionResultsCSV)
FS.tableTypes "AngryDems" (framesPath angryDemsCSV)
FS.tableTypes "AllMoney2020" (framesPath allMoney2020CSV)
FS.tableTypes "HouseElections" (framesPath houseElectionsCSV)
FS.tableTypes' (FS.rowGen (framesPath senateElectionsCSV)) { FS.rowTypeName = "SenateElections"
                                                           , FS.tablePrefix = "Senate"
                                                           }
FS.tableTypes' (FS.rowGen  (framesPath electionIntegrityByState2016CSV)) { FS.rowTypeName = "ElectionIntegrityByState2016"
                                                                         , FS.tablePrefix = "PEI"
                                                                         }

FS.tableTypes' (FS.rowGen  (framesPath electionIntegrityByState2018CSV)) { FS.rowTypeName = "ElectionIntegrityByState2018"
                                                                         , FS.tablePrefix = "PEI"
                                                                         }


--F.tableTypes' (F.rowGen  (framesPath electionIntegrityByState2016CSV)) { F.rowTypeName = "ElectionIntegrityByState"
--                                                                       , F.tablePrefix = "PEI"


FS.tableTypes "PresidentialByState" (framesPath presidentialByStateCSV)
FS.tableTypes' (FS.rowGen (framesPath housePolls2020CSV)) { FS.rowTypeName = "HousePolls2020"
                                                          , FS.columnUniverse = Proxy :: Proxy FP.ColumnsWithDayAndLocalTime
                                                          }
FS.tableTypes "ContextDemographics" (framesPath contextDemographicsCSV)
FS.tableTypes "CVAPByCDAndRace_Raw" (framesPath cvapByCDAndRace2014_2018CSV)
FS.tableTypes "PopulationsByCounty_Raw" (framesPath popsByCountyCSV)
-- NB: cd115, cd114, cd113 are all also present and have the same table-types
FS.tableTypes "CDFromPUMA2012"       (framesPath cd116FromPUMA2012CSV)


FS.tableTypes "TurnoutASR"          (framesPath detailedASRTurnoutCSV)
FS.tableTypes "TurnoutASE"          (framesPath detailedASETurnoutCSV)
FS.tableTypes "StateTurnout"        (framesPath stateTurnoutCSV)
FS.tableTypes "ASRDemographics" (framesPath ageSexRaceDemographicsLongCSV)
FS.tableTypes "ASEDemographics" (framesPath ageSexEducationDemographicsLongCSV)
FS.tableTypes "EdisonExit2018" (framesPath exitPoll2018CSV)

FS.tableTypes "ElectoralCollege" (framesPath electorsCSV)

FS.tableTypes "States" (framesPath statesCSV)
FS.tableTypes "StateCountyCD" (framesPath stateCounty116CDCSV)
FS.tableTypes "StateCountyTractPUMA" (framesPath stateCountyTractPUMACSV)
FS.tableTypes "CountyToCD116" (framesPath countyToCD116CSV)
FS.tableTypes "CD116FromStateLower2016" (framesPath cd116FromStateLower2016CSV)
FS.tableTypes "CD116FromStateUpper2016" (framesPath cd116FromStateUpper2016CSV)
FS.tableTypes "StateLower2016FromPUMA" (framesPath stateLower2016FromPUMACSV)
FS.tableTypes "StateUpper2016FromPUMA" (framesPath stateUpper2016FromPUMACSV)
FS.tableTypes "CountyFromPUMA" (framesPath county2014FromPUMA2012CSV)


rmapM :: Monad m => (a -> m b) -> Streamly.Fold.Fold m x a -> Streamly.Fold.Fold m x b
#if MIN_VERSION_streamly(0,8,0)
rmapM = Streamly.Fold.rmapM
#else
rmapM = Streamly.Fold.mapM
#endif
{-# INLINE rmapM #-}

logLengthF :: T.Text -> Streamly.Fold.Fold K.StreamlyM a ()
logLengthF t = rmapM (\n -> K.logStreamly K.Diagnostic $ t <> " " <> (T.pack $ show n)) Streamly.Fold.length

loadToRecStream
  :: forall rs t m
  . ( Monad m
    , Monad (t m)
    , Streamly.MonadAsync m
    , Exceptions.MonadCatch m
    , V.RMap rs
    , Frames.Streamly.StrictReadRec rs
    , Streamly.IsStream t
    )
  => Frames.Streamly.ParserOptions
  -> FilePath
  -> (F.Record rs -> Bool)
  -> t m (F.Record rs)
loadToRecStream po fp filterF = Streamly.filter filterF
                                $ Frames.Streamly.readTableOpt po fp
{-# INLINEABLE loadToRecStream #-}

-- load with cols qs
-- filter with rs
-- return rs
loadToMaybeRecStream
  :: forall qs rs t m
  . ( Monad m
    , Monad (t m)
    , Streamly.MonadAsync m
    , Exceptions.MonadCatch m
    , Streamly.IsStream t
    , Frames.Streamly.StrictReadRec qs
    , V.RMap rs
    , Show (F.Record rs)
    , V.RMap qs
    , V.RecordToList rs
    , (V.ReifyConstraint Show (Maybe F.:. F.ElField) rs)
    , rs F.⊆ qs
    )
  => Frames.Streamly.ParserOptions
  -> FilePath
  -> (F.Rec (Maybe F.:. F.ElField) rs -> Bool)
  -> t m (F.Rec (Maybe F.:. F.ElField) rs)
loadToMaybeRecStream po fp filterF =
  Streamly.filter filterF
  $ Streamly.map F.rcast
  $ Frames.Streamly.readTableMaybeOpt @qs po fp
{-
    let reportRows :: Streamly.SerialT (K.Sem r) x -> FilePath -> K.Sem r ()
      reportRows str fn = do
        sLen <- Streamly.length str
        K.logLE K.Diagnostic
          $  T.pack (show sLen)
          <> " rows in "
          <> T.pack fn
  Streamly.yieldM $ reportRows s fp
  s
-}
{-# INLINEABLE loadToMaybeRecStream #-}

loadToRecList
  :: forall rs r
  . ( K.KnitEffects r
    , Frames.Streamly.StrictReadRec rs
    , V.RMap rs
    )
  => Frames.Streamly.ParserOptions
  -> FilePath
  -> (F.Record rs -> Bool)
  -> K.Sem r [F.Record rs]
loadToRecList po fp filterF = K.streamlyToKnit $ Streamly.toList $ loadToRecStream po fp filterF
{-# INLINEABLE loadToRecList #-}

loadToFrame
  :: forall rs r
   . ( K.KnitEffects r
     , Frames.Streamly.StrictReadRec rs
     , FI.RecVec rs
     , V.RMap rs
     )
  => Frames.Streamly.ParserOptions
  -> FilePath
  -> (F.Record rs -> Bool)
  -> K.Sem r (F.FrameRec rs)
loadToFrame po fp filterF = do
  frame <- K.streamlyToKnit $ Frames.Streamly.inCoreAoS $ Streamly.filter filterF $ Frames.Streamly.readTableOpt po fp
  let reportRows :: Foldable f => f x -> FilePath -> K.Sem r ()
      reportRows f fn =
        K.logLE K.Diagnostic
          $  T.pack (show $ FL.fold FL.length f)
          <> " rows in "
          <> T.pack fn
  reportRows frame fp
  return frame
{-# INLINEABLE loadToFrame #-}

processMaybeRecStream
  :: forall rs rs'
     .(V.RFoldMap rs
     , V.RPureConstrained V.KnownField rs
     , V.RecApplicative rs
     , V.RApply rs
     , V.RFoldMap rs'
     , V.RPureConstrained V.KnownField rs'
     , V.RecApplicative rs'
     , V.RApply rs'
     , Show (F.Rec (Maybe F.:. F.ElField) rs)
     )
  => (F.Rec (Maybe F.:. F.ElField) rs -> (F.Rec (Maybe F.:. F.ElField) rs')) -- fix any Nothings you need to/can
  -> (F.Record rs' -> Bool) -- filter after removing Nothings
  -> Streamly.SerialT K.StreamlyM (F.Rec (Maybe F.:. F.ElField) rs)
  -> Streamly.SerialT K.StreamlyM (F.Record rs')
processMaybeRecStream fixMissing filterRows maybeRecS = do
  let addMissing m l = Map.insertWith (+) l 1 m
      addMissings m = FL.fold (FL.Fold addMissing m id)
#if MIN_VERSION_streamly(0,8,0)
      whatsMissingF ::  (V.RFoldMap qs, V.RPureConstrained V.KnownField qs, V.RecApplicative qs, V.RApply qs)
                    => Streamly.Fold.Fold K.StreamlyM (F.Rec  (Maybe F.:. F.ElField) qs) (Map Text Int)
      whatsMissingF = Streamly.Fold.mkFold (\m a -> Streamly.Fold.Partial $ addMissings m (FM.whatsMissingRow a)) (Streamly.Fold.Partial Map.empty) id
--      showRecsF = Streamly.drainBy $ liftIO. putStrLn . show --Streamly.Fold.mkFoldM_ (\_ a -> (liftIO $ putStrLn $ show a) >> (return $ Streamly.Fold.Partial ())) (return $ Streamly.Fold.Partial ())
#else
      whatsMissingF :: (V.RFoldMap qs, V.RPureConstrained V.KnownField qs, V.RecApplicative qs, V.RApply qs)
                    =>  Streamly.Fold.Fold K.StreamlyM (F.Rec  (Maybe F.:. F.ElField) qs) (Map Text Int)
      whatsMissingF = Streamly.Fold.mkPure (\m a -> addMissings m (FM.whatsMissingRow a)) Map.empty id
--      showRecsF = Streamly.Fold.mkFold (\m a -> putStrLn $ show a) (return ()) return
#endif
      logMissingF ::  (V.RFoldMap qs, V.RPureConstrained V.KnownField qs, V.RecApplicative qs, V.RApply qs)
                  =>T.Text -> Streamly.Fold.Fold K.StreamlyM (F.Rec (Maybe F.:. F.ElField) qs) ()
      logMissingF t = rmapM (\x  -> K.logStreamly K.Diagnostic $ t <> (T.pack $ show x)) whatsMissingF
  Streamly.filter filterRows
    $ Streamly.tap (logLengthF "Length after fixing and dropping: ")
    $ Streamly.mapMaybe F.recMaybe
    $ Streamly.tap (logMissingF "missing after fixing: ")
    $ Streamly.map fixMissing
    $ Streamly.tap (logMissingF "missing before fixing: ")
--    $ Streamly.tap (Streamly.Fold.drainBy $ liftIO. putStrLn . show)
    $ maybeRecS
{-# INLINEABLE processMaybeRecStream #-}

toPipes :: Monad m => Streamly.SerialT m a -> P.Producer a m ()
toPipes = P.unfoldr unconsS
    where
    -- Adapt S.uncons to return an Either instead of Maybe
    unconsS s = Streamly.uncons s >>= maybe (return $ Left ()) (return . Right)
{-# INLINEABLE toPipes #-}


someExceptionAsPandocError :: forall r a. (Polysemy.MemberWithError (Polysemy.Error K.PandocError) r)
                           => Polysemy.Sem (Polysemy.Error SomeException ': r) a -> Polysemy.Sem r a
someExceptionAsPandocError = Polysemy.mapError (\(e :: SomeException) -> Pandoc.PandocSomeError $ T.pack $ displayException e)
{-# INLINEABLE someExceptionAsPandocError #-}

{-
fixMonadCatch :: (Polysemy.MemberWithError (Polysemy.Error SomeException) r)
              => Streamly.SerialT (Exceptions.CatchT (K.Sem r)) a -> Streamly.SerialT (K.Sem r) a
fixMonadCatch = Streamly.hoist f where
  f :: forall r a. (Polysemy.MemberWithError (Polysemy.Error SomeException) r) =>  Exceptions.CatchT (K.Sem r) a -> K.Sem r a
  f = join . fmap Polysemy.fromEither . Exceptions.runCatchT
{-# INLINEABLE fixMonadCatch #-}


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
-}

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
