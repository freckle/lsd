module Main
  ( main
  ) where

import RIO

import App
import Options
import Report
import Run
import StackYaml

main :: IO ()
main = do
  opts@Options {..} <- parseOptions

  withApp opts $ \app -> runRIO app $ do
    logDebug $ "Loading " <> fromString oPath
    stackYaml <- loadStackYaml oPath
    report <- getReportSuggestion oFormat

    n <- runLsd opts stackYaml report
    logDebug $ displayShow n <> " suggestion(s) found"

    when (n /= 0 && not oNoExit) $ do
      logDebug "Exiting non-zero (--no-exit to disable)"
      exitFailure
