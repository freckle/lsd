module SLED.Suggestion
  ( Suggestion (..)
  , SuggestionAction (..)
  ) where

import RIO

import SLED.ExtraDep

data SuggestionAction
  = Remove
  | ReplaceWith ExtraDep

data Suggestion = Suggestion
  { sTarget :: ExtraDep
  , sAction :: SuggestionAction
  , sDescription :: Utf8Builder
  }
