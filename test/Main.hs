{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
import qualified Frames
import qualified Frames.CSV as Frames
import qualified BlueRipple.Data.DataFrames as BR
import qualified BlueRipple.Data.DataSourcePaths as BR
import qualified Knit.Report as Knit
import qualified Data.Text as Text
import qualified Control.Foldl as Foldl

main :: IO ()
main = do
  let knitConfig = (Knit.defaultKnitConfig Nothing ) { Knit.logIf = const True}
  resE <- Knit.consumeKnitEffectStack knitConfig $ do
    f <- BR.loadToRecListChecked @(Frames.RecordColumns BR.States) Frames.defaultParser (BR.framesPath BR.statesCSV) (const True)
    putTextLn $ Text.intercalate "\n" $ fmap show $ Foldl.fold Foldl.list f
  case resE of
    Left err -> putTextLn $ "Error: " <> show err
    Right () -> putTextLn $ "Success!"
