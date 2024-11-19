module SLED.Checks.HackageVersion
  ( checkHackageVersion
  ) where

import SLED.Prelude

import SLED.Check
import SLED.Version

checkHackageVersion :: Check
checkHackageVersion = Check $ \ed extraDep -> do
  Hackage hed <- pure extraDep
  hv <- ed.hackageVersions
  released <- headMaybe hv.normal
  current <- defaultRevision hv.normal <$> hed.version
  UpdateHackageVersion released <$ guard (released > current)
