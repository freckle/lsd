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
import Data.Yaml.Marked.Decode
import SLED.Check
import SLED.Checks
import SLED.Options
import SLED.StackYaml
import SLED.StackageResolver
import SLED.Suggestion.Format
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
  logDebug $ "Loading stack.yaml" :# ["path" .= options.path]

  cwd <- getCurrentDirectory
  bs <- readFileBS options.path
  colors <- getColorsLogger
  stackYaml <-
    liftIO $ markedItem <$> decodeThrow decodeStackYaml options.path bs

  -- Mark an option resolver with the in-file resolver's position so that if
  -- we do anything based on it, that's what we'll use
  let resolver = maybe stackYaml.resolver (<$ stackYaml.resolver) options.resolver

  suggestions <-
    runConduit
      $ yieldMany stackYaml.extraDeps
      .| filterC (shouldIncludeExtraDep options.filter options.excludes . markedItem)
      .| awaitForever
        ( \extraDep -> do
            suggestions <- lift $ runChecks resolver options.checks extraDep
            yieldMany suggestions
        )
      .| iterM (pushLoggerLn . formatSuggestion cwd bs colors options.format)
      .| sinkList

  let n = length suggestions
  logDebug $ "Suggestions found" :# ["count" .= n]

  when (n /= 0 && not options.noExit) $ do
    logDebug "Exiting non-zero (--no-exit to disable)"
    exitFailure

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
  -> m [Marked Suggestion]
runChecks resolver checksName extraDep = do
  logDebug
    $ "Fetching external details"
    :# ["dependency" .= markedItem extraDep]
  details <-
    getExternalDetails (markedItem resolver) $ markedItem extraDep

  pure
    $ mapMaybe (runCheck details extraDep)
    $ checksByName checksName
