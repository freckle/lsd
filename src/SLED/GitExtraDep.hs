module SLED.GitExtraDep
  ( GitExtraDep (..)
  , decodeGitExtraDep
  , Repository (..)
  , repositoryBase
  , repositoryBaseName
  , CommitSHA (..)
  , TruncatedCommitSHA (..)
  , truncateCommitSHA
  ) where

import SLED.Prelude

import qualified Data.Text as T
import Data.Yaml.Marked.Parse
import Data.Yaml.Marked.Value
import SLED.Display

data GitExtraDep = GitExtraDep
  { gedRepository :: Repository
  , gedCommit :: Marked CommitSHA
  }
  deriving stock (Eq, Show)

instance Display GitExtraDep where
  display colors GitExtraDep {..} =
    display colors gedRepository
      <> "@"
      <> display colors (truncateCommitSHA <$> gedCommit)

decodeGitExtraDep :: Marked Value -> Either String (Marked GitExtraDep)
decodeGitExtraDep = withObject "GitExtraDep" $ \o -> do
  gh <- o .:? "github"
  repo <-
    maybe
      (json =<< o .: "git")
      ((Repository . (ghBase <>) <$$>) . text)
      gh
  GitExtraDep (markedItem repo) <$> (json =<< o .: "commit")

newtype Repository = Repository
  { unRepository :: Text
  }
  deriving newtype (Eq, Show, FromJSON, ToJSON)

instance Display Repository where
  display _ r = repositoryBase r

repositoryBase :: Repository -> Text
repositoryBase = dropPrefix ghBase . unRepository

repositoryBaseName :: Repository -> Text
repositoryBaseName = T.drop 1 . T.dropWhile (/= '/') . repositoryBase

newtype CommitSHA = CommitSHA
  { unCommitSHA :: Text
  }
  deriving newtype (Eq, Show, Display, FromJSON, ToJSON)

newtype TruncatedCommitSHA = TruncatedCommitSHA
  { unTruncatedCommitSHA :: Text
  }
  deriving newtype (Eq, Show, Display, FromJSON, ToJSON)

truncateCommitSHA :: CommitSHA -> TruncatedCommitSHA
truncateCommitSHA = TruncatedCommitSHA . T.take 7 . unCommitSHA

ghBase :: Text
ghBase = "https://github.com/"

dropPrefix :: Text -> Text -> Text
dropPrefix prefix t = fromMaybe t $ T.stripPrefix prefix t
