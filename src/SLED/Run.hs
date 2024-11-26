{-# LANGUAGE ViewPatterns #-}

module SLED.Run
  ( runSLED

    -- * Exported for testing
  , shouldIncludeExtraDep
  , runChecks
  ) where

import SLED.Prelude

import Blammo.Logging.Colors
import Blammo.Logging.Logger
import Conduit
import Data.Conduit.Combinators (iterM)
import qualified Data.List.NonEmpty as NE
import SLED.Check
import SLED.Checks
import SLED.Checks.StackageResolver
import SLED.Options.Parse
import SLED.StackYaml
import SLED.StackageResolver
import SLED.Suggestion.Format
import SLED.Suggestion.Format.Target
import System.FilePath.Glob
import UnliftIO.Directory (getCurrentDirectory)

runSLED
  :: ( MonadThrow m
     , MonadUnliftIO m
     , MonadLogger m
     , MonadHackage m
     , MonadStackage m
     , MonadGit m
     , MonadReader env m
     , HasLogger env
     )
  => Options
  -> m ()
runSLED options = do
  logDebug $ "Loaded stack.yaml" :# ["path" .= options.path]

  n <-
    fmap getSum
      $ runConduit
      $ (<>)
      <$> do
        msuggestion <- lift $ checkStackageResolver options.stackYaml.resolver
        traverse_ yield msuggestion
          .| outputSuggestions options.stackYamlContents options.format
          .| foldMapC (const @(Sum Int) 1)
      <*> do
        yieldMany options.stackYaml.extraDeps
          .| filterC (shouldIncludeExtraDep options.filter options.excludes . markedItem)
          .| concatMapMC (runChecks options.resolver options.checks)
          .| outputSuggestions options.stackYamlContents options.format
          .| foldMapC (const @(Sum Int) 1)

  logDebug $ "Suggestions found" :# ["count" .= n]

  when (n /= 0 && not options.noExit) $ do
    logDebug "Exiting non-zero (--no-exit to disable)"
    exitFailure

-- | Print 'Suggestion's according to 'Format'
outputSuggestions
  :: ( MonadUnliftIO m
     , MonadLogger m
     , MonadReader env m
     , HasLogger env
     , IsTarget t
     , ToJSON t
     )
  => ByteString
  -> Format
  -> ConduitT (Marked (Suggestion t)) (Marked (Suggestion t)) m ()
outputSuggestions contents format = do
  cwd <- getCurrentDirectory
  colors <- getColorsLogger
  iterM $ pushLoggerLn . formatSuggestion cwd contents colors format

shouldIncludeExtraDep :: Maybe Pattern -> [Pattern] -> ExtraDep -> Bool
shouldIncludeExtraDep mInclude excludes dep
  | Just include <- mInclude, not (include `matchPattern` dep) = False
  | any (`matchPattern` dep) excludes = False
  | otherwise = True

runChecks
  :: ( MonadUnliftIO m
     , MonadLogger m
     , MonadHackage m
     , MonadStackage m
     , MonadGit m
     )
  => Marked StackageResolver
  -> ChecksName
  -> Marked ExtraDep
  -> m (Maybe (Marked (Suggestion ExtraDep)))
runChecks (markedItem -> resolver) checksName m@(markedItem -> extraDep) = do
  logDebug $ "Fetching external details" :# ["dependency" .= extraDep]

  details <-
    getExternalDetails resolver extraDep

  let mactions =
        NE.nonEmpty
          $ mapMaybe (\check -> check.run details extraDep)
          $ checksByName checksName

  for mactions $ \actions -> do
    -- Making multiple suggestions on one extra-dep is conflicting.
    -- We'll use the semigroup instance to give precendence and fold
    -- them down to one per extra-dep.
    let suggestion = Suggestion {target = extraDep, action = sconcat actions}

    -- And mark the Suggestion at the point of the ExtraDep
    pure $ suggestion <$ m
