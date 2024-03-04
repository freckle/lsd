module SLED.Suggestion.Format.GHA
  ( formatSuggestionGHA
  ) where

import SLED.Prelude

import Blammo.Logging.Colors
import qualified Data.Text as T
import SLED.Suggestion
import SLED.Suggestion.Format.Action

-- | Format a suggestion to create an annotation in GitHub Actions
--
-- @
-- ::error file={name},line={line},endLine={endLine},title={title}::{message}
-- @
formatSuggestionGHA :: Marked Suggestion -> Text
formatSuggestionGHA m =
  "::error "
    <> T.intercalate "," attrs
    <> "::"
    <> formatExtraDep s.target
    <> ": "
    <> suggestionActionDescription s.action
 where
  attrs =
    [ "file=" <> pack path
    , "line=" <> show startLine
    , "endLine=" <> show endLine
    , "title=" <> formatAction noColors s.target s.action
    ]
  path = markedPath m
  startLine = (+ 1) $ locationLine $ markedLocationStart m
  endLine = (+ 1) $ locationLine $ markedLocationStart m
  s = markedItem m
