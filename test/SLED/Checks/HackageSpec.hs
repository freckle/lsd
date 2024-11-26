module SLED.Checks.HackageSpec
  ( spec
  ) where

import SLED.Prelude

import qualified Data.Map.Strict as Map
import SLED.Hackage
import SLED.PackageName
import SLED.Stackage
import SLED.Suggestion
import SLED.Test
import SLED.Version

spec :: Spec
spec = do
  describe "checkHackageVersion" $ do
    it "suggests newer normal versions" $ do
      let
        package = PackageName "freckle-app"
        version = unsafeVersion "1.0.1.2"
        mockHackage = Map.singleton package $ hackageVersions ["1.0.1.2"] [] []

      runHackageChecks
        mockHackage
        mempty
        HackageExtraDep
          { package = package
          , version = parseVersion "1.0.1.1"
          }
        `shouldReturn` Just (UpdateHackageVersion version)

    it "doesn't suggest deprecated versions" $ do
      let
        package = PackageName "freckle-app"
        mockHackage = Map.singleton package $ hackageVersions [] [] ["1.0.1.2"]

      runHackageChecks
        mockHackage
        mempty
        HackageExtraDep
          { package = package
          , version = parseVersion "1.0.1.1"
          }
        `shouldReturn` Nothing

  describe "checkRedundantHackage" $ do
    it "suggests when stackage has your dep" $ do
      let
        package = PackageName "freckle-app"
        mockStackage =
          Map.singleton
            (markedItem lts1818)
            (Map.singleton package $ stackageVersions "1.0.1.1" "1.0.1.2")
        hed =
          HackageExtraDep
            { package = package
            , version = parseVersion "1.0.1.1"
            }

      runHackageChecks mempty mockStackage hed
        `shouldReturn` Just Remove

    it "suggests when stackage has a newer dep" $ do
      let
        package = PackageName "freckle-app"
        mockStackage =
          Map.singleton
            (markedItem lts1818)
            (Map.singleton package $ stackageVersions "1.0.1.2" "1.0.1.2")

      runHackageChecks
        mempty
        mockStackage
        HackageExtraDep
          { package = package
          , version = Just $ unsafeVersion "1.0.1.1"
          }
        `shouldReturn` Just Remove

    it "does not suggest when stackage has an older dep" $ do
      let
        package = PackageName "freckle-app"
        mockStackage =
          Map.singleton
            (markedItem lts1818)
            (Map.singleton package $ stackageVersions "1.0.1.0" "1.0.1.2")

      runHackageChecks
        mempty
        mockStackage
        HackageExtraDep
          { package = package
          , version = Just $ unsafeVersion "1.0.1.1"
          }
        `shouldReturn` Nothing

    it "does not suggest when the extra-dep is a newer revision (implicit)" $ do
      let
        package = PackageName "servant-swagger-ui-core"
        mockHackage = Map.singleton package $ hackageVersions ["0.3.5@rev:11"] [] []
        mockStackage =
          Map.singleton
            (markedItem lts1818)
            (Map.singleton package $ stackageVersions "0.3.5@rev:6" "0.3.5@rev:11")

      runHackageChecks
        mockHackage
        mockStackage
        HackageExtraDep
          { package = package
          , version = Just $ unsafeVersion "0.3.5"
          }
        `shouldReturn` Nothing

    it "does not suggest when the extra-dep is a newer revision (checksum)" $ do
      let
        package = PackageName "servant-swagger-ui-core"
        version = unsafeVersion "0.3.5@sha256:ffffffffffffffffff,100"
        mockHackage = Map.singleton package $ hackageVersions ["0.3.5@rev:11"] [] []
        mockStackage =
          Map.singleton
            (markedItem lts1818)
            (Map.singleton package $ stackageVersions "0.3.5@rev:6" "0.3.5@rev:11")

      runHackageChecks
        mockHackage
        mockStackage
        HackageExtraDep
          { package = package
          , version = Just version
          }
        `shouldReturn` Nothing

    it "does not suggest when the extra-dep is a newer revision (explicit)" $ do
      let
        package = PackageName "servant-swagger-ui-core"
        mockHackage = Map.singleton package $ hackageVersions ["0.3.5@rev:11"] [] []
        mockStackage =
          Map.singleton
            (markedItem lts1818)
            (Map.singleton package $ stackageVersions "0.3.5@rev:6" "0.3.5@rev:11")

      runHackageChecks
        mockHackage
        mockStackage
        HackageExtraDep
          { package = package
          , version = Just $ unsafeVersion "0.3.5@rev:11"
          }
        `shouldReturn` Nothing

hackageVersions
  :: [Text]
  -- ^ Normal
  -> [Text]
  -- ^ Unpreferred
  -> [Text]
  -- ^ Deprecated
  -> HackageVersions
hackageVersions n u d =
  HackageVersions
    { normal = mapMaybe parseVersion n
    , unpreferred = mapMaybe parseVersion u
    , deprecated = mapMaybe parseVersion d
    }

stackageVersions
  :: Text
  -- ^ On-page
  -> Text
  -- ^ On-Hackage
  -> StackageVersions
stackageVersions p h =
  StackageVersions
    { onPage = unsafeVersion p
    , onHackage = unsafeVersion h
    }
