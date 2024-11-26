module SLED.Suggestion.Format.Target
  ( IsTarget (..)
  ) where

import SLED.Prelude

import qualified Data.Text as T
import SLED.ExtraDep
import SLED.GitExtraDep
import SLED.HackageExtraDep
import SLED.PackageName
import SLED.StackageResolver
import SLED.Suggestion
import SLED.Version

class IsTarget a where
  formatTarget :: a -> Text

  -- | Allows marking parts of a target for specific actions
  --
  -- We return void since we don't know what type that part could be, and
  -- at the point we use this we only care about the marks anyway.
  getTargetMark :: Marked (Suggestion a) -> Marked ()
  getTargetMark m = void m

instance IsTarget ExtraDep where
  formatTarget = \case
    Hackage hed -> formatTarget hed
    Git ged ->
      repositoryBase ged.repository
        <> "@"
        <> T.take 7 (formatTarget $ markedItem ged.commit)
    Other {} -> "<unknown>"

  getTargetMark m = case (s.target, s.action) of
    (Git ged, UpdateGitCommit {}) -> void ged.commit
    _ -> void m
   where
    s = markedItem m

instance IsTarget HackageExtraDep where
  formatTarget hed =
    hed.package.unwrap <> maybe "" (("-" <>) . pack . showVersion) hed.version

instance IsTarget CommitSHA where
  formatTarget = (.unwrap)

instance IsTarget StackageResolver where
  formatTarget = stackageResolverToText
