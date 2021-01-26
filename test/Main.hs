{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

import qualified Frames
import qualified Frames.CSV as Frames
import qualified BlueRipple.Data.DataFrames as BR
import qualified BlueRipple.Data.DataSourcePaths as BR
import qualified Knit.Report as Knit
import qualified Data.Text as Text
import qualified Control.Foldl as Foldl

main :: IO ()
main = do
  resE <- Knit.consumeKnitEffectStack (Knit.defaultKnitConfig Nothing) $ do
    f <- BR.loadToFrame @(Frames.RecordColumns BR.SenateElections) Frames.defaultParserOptions BR.senateElectionsCSV
    putTextLn $ Text.intercalate "\n" $ fmap show $ Foldl.fold Foldl.list f
  case resE of
    Left err -> putTextLn $ "Error: " <> err
    Right () -> putTextLn $ "Success!"
