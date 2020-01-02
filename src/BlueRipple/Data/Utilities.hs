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

module BlueRipple.Data.Utilities
  ()
where

import           BlueRipple.Data.DataFrames
import qualified Knit.Report                   as K

import qualified Control.Foldl                 as FL
import qualified Data.List                     as L
import           Data.Maybe                     ( catMaybes )
import qualified Data.Text                     as T
import           Data.Text                      ( Text )
import qualified Data.Vinyl                    as V
import qualified Frames                        as F
import qualified Frames.CSV                    as F
import qualified Frames.InCore                 as FI
import qualified Frames.TH                     as F

import qualified Frames.ParseableTypes         as FP
import qualified Frames.MaybeUtils             as FM

import qualified Frames.MapReduce              as FMR
import qualified Frames.Folds                  as FF



type VoteTotalsByCD = [Year, StateName, StateAbbreviation, StateFips, CongressionalDistrict, TotalVotes]
type VoteTotalsByState = [Year, StateName, StateAbbreviation, StateFips, TotalVotes]

cdVoteTotalsFromHouseElectionResultsF
  :: FL.Fold (F.Record ElectionResults) (F.FrameRec VoteTotalsByCD)
cdVoteTotalsFromHouseElectionResultsF =
  let preprocess = fmap
        ( FT.retypeColumn @State @StateName
        . FT.retypeColumn @District @CongressionalDistrict
        . FT.retypeColumn @StatePo @StateAbbreviation
        )
      unpack = MR.Unpack (pure @[] . preprocess)
      assign =
        FMR.assignKeysAndData
          @'[Year, StateName, StateAbbreviation, CongressionalDistrict]
          @'[TotalVotes]
      reduce =
        FMR.foldAndAddKey
          $ fmap (FT.recordSingleton @TotalVotes . fromMaybe 0)
          $ FL.premap (F.rgetField @TotalVotes) Fl.last
  in  FMR.mapReduceFold unpack assign reduce
--stateVoteTotalsFromCDVoteTotalsF :: FL.Fold (F.Record VoteTotalsByCD) (F.FrameRec VoteTotalsByState)


-- is there a better way to merge these folds??
--stateVoteTotalsFromHouseElectionResults :: FL.Fold (F.Record ElectionResults) (F.FrameRec VoteTotalsByState)
--stateVoteTotalsFromHouseElectionResults = fmap (FL.fold stateVoteTotalsFromCDVoteTotals) cdVoteTotalsFromHouseElectionResultsF
--voteTotalsByStateFromHouseResults :: F.FrameRec ElectionResults -> F.FrameRec VoteTotalsByState
