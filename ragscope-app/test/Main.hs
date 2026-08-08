module Main (main) where

import Test.Hspec

import RAGScope.Logging.RuntimeSpec qualified as RuntimeSpec

main :: IO ()
main =
  hspec $ do
    describe "RAGScope.Logging.Runtime" RuntimeSpec.spec
