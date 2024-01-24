module SLED.Checks.RedundantGit
  ( checkRedundantGit
  ) where

import SLED.Prelude

import Data.List (intersect)
import SLED.Check
import SLED.PackageName

checkRedundantGit :: Check
checkRedundantGit = Check $ \ed extraDep -> do
  Git ged <- pure $ markedItem extraDep
  gd <- ed.gitDetails

  let
    versions = sortOn (Down . fst) gd.commitCountToVersionTags
    equalVersions = map snd $ takeWhile ((>= 0) . fst) versions
    newerVersions = map snd $ takeWhile ((> 0) . fst) versions

    -- Attempt to suggest a version tag that exists on Hackage
    suggestHackage = do
      hv <- ed.hackageVersions
      version <- headMaybe $ hv.normal `intersect` equalVersions
      pure
        $ Suggestion
          { action =
              ReplaceGitWithHackage (ged <$ extraDep)
                $ HackageExtraDep
                  { package = PackageName $ repositoryBaseName ged.repository
                  , version = Just version
                  , checksum = Nothing
                  }
          , reason = "Same-or-newer version exists on Hackage"
          }

    -- Fall-back for when we can't find Hackage info, so just suggest if there
    -- are newer version-like tags
    suggestGit = do
      version <- headMaybe newerVersions
      pure
        $ Suggestion
          { action =
              ReplaceGitWithHackage (ged <$ extraDep)
                $ HackageExtraDep
                  { package = PackageName $ repositoryBaseName ged.repository
                  , version = Just version
                  , checksum = Nothing
                  }
          , reason = "Newer, version-like tag exists"
          }

  suggestHackage <|> suggestGit
