module SLED.Options.PragmaSpec
  ( spec
  ) where

import SLED.Test

import SLED.Options (Options (..))
import SLED.Options.Pragma

spec :: Spec
spec = do
  describe "parsePragmaOptions" $ do
    it "parses simple comments" $ do
      let
        yaml :: ByteString
        yaml =
          mconcat
            [ "# @sled --exclude foo --exclude bar\n"
            , "resolver: x\n"
            , "extra-deps:\n"
            , "# This is another comment that might mention\n"
            , "# sled at the beginning of a sentence.\n"
            , "- foo\n"
            , "- bar\n"
            , "- baz\n"
            ]

      let (_errs, options) = parsePragmaOptions yaml

      options.excludes `shouldBe` ["foo", "bar"]

    it "parses multiple comments anywhere in the file" $ do
      let
        yaml :: ByteString
        yaml =
          mconcat
            [ "# @sled --exclude foo --exclude baz\n"
            , "resolver: x\n"
            , "extra-deps:\n"
            , "  - foo\n"
            , "  - bar\n"
            , "  # @sled --exclude=\"bat\"\n"
            , "  - bat\n"
            ]

      let (_errs, options) = parsePragmaOptions yaml

      options.excludes `shouldBe` ["foo", "baz", "bat"]

    it "parses trailing comments" $ do
      let
        yaml :: ByteString
        yaml =
          mconcat
            [ "resolver: x\n"
            , "extra-deps:\n"
            , "  - foo\n"
            , "  - bar\n"
            , "  - bat # @sled --exclude=\"bat\"\n"
            ]

      let (_errs, options) = parsePragmaOptions yaml

      options.excludes `shouldBe` ["bat"]

    it "returns errors in the case of invalid options" $ do
      let
        yaml :: ByteString
        yaml =
          mconcat
            [ "# @sled --what --no-way\n"
            , "resolver: x\n"
            ]

      let
        (errs, _) = parsePragmaOptions yaml

        expectedErr =
          concat
            [ "Invalid option `--what'"
            , "\n"
            , "\nUsage: stack-lint-extra-deps [-p|--path PATH] [-r|--resolver RESOLVER] "
            , "\n                             [-f|--format tty|gha|json] [--exclude PATTERN] "
            , "\n                             [-R|--no-check-resolver] [--checks CHECKS] "
            , "\n                             [-n|--no-exit] [-F|--fix] [PATTERN] [--version]"
            , "\n\n  stack lint-extra-deps (sled)"
            ]

      errs `shouldBe` [expectedErr]

    it "returns errors in the case of invalid pragmas" $ do
      let
        yaml :: ByteString
        yaml =
          mconcat
            [ "# @sled foo '\n"
            , "resolver: x\n"
            ]

      let
        (errs, _) = parsePragmaOptions yaml

        expectedErr =
          concat
            [ "<input>:1:6:"
            , "\n  |"
            , "\n1 | foo '"
            , "\n  |      ^"
            , "\nunexpected end of input"
            , "\nexpecting ''' or escaped'\\''"
            , "\n"
            ]

      errs `shouldBe` [expectedErr]

    it "collects all errors" $ do
      let
        yaml :: ByteString
        yaml =
          mconcat
            [ "# @sled foo '\n"
            , "resolver: x\n"
            , "# @sled bar '\n"
            ]

      let (errs, _) = parsePragmaOptions yaml

      errs `shouldSatisfy` (== 2) . length
