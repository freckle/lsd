module SLED.RunSpec
  ( spec
  ) where

import SLED.Prelude

import Blammo.Logging.Logger
import SLED.App
import SLED.Checks
import SLED.Options
import SLED.Report
import SLED.Run
import SLED.StackYaml
import Test.Hspec (Spec, describe, example, it)
import Test.Hspec.Expectations.Lifted

spec :: Spec
spec = do
  describe "runLsd" $ do
    it "finds 10 Hackage suggestions in the lts-18.18 example" $ example $ do
      let opts = testExampleOptions "lts-18.18" HackageChecks
      app <- App opts <$> newTestLogger defaultLogSettings
      stackYaml <- loadStackYaml $ oPath opts
      flip runAppT app $ do
        n <- runLsd opts stackYaml $ \_ -> pure ()
        n `shouldBe` 10

testExampleOptions :: String -> ChecksName -> Options
testExampleOptions name checks =
  Options
    { oResolver = Nothing
    , oExcludes = []
    , oChecks = checks
    , oFormat = Detailed
    , oNoExit = True
    , oPath = "test/examples/" <> name <> ".yaml"
    , oFilter = Nothing
    }
