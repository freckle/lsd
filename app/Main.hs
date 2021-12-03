module Main
  ( main
  ) where

import RIO

import Lsd.App
import Lsd.Options
import Lsd.Run
import Lsd.StackYaml

main :: IO ()
main = do
  opts@Options {..} <- parseOptions

  withApp opts $ \app -> runRIO app $ do
    logDebug $ "Loading " <> fromString oPath
    stackYaml <- loadStackYaml oPath

    n <- runLsd opts stackYaml
    logDebug $ displayShow n <> " suggestion(s) found"

    when (n /= 0 && not oNoExit) $ do
      logDebug "Exiting non-zero (--no-exit to disable)"
      exitFailure
