module Main (main) where

import Test.Hspec (describe, hspec)

import RAGScope.Logging.Backend.JsonSpec qualified as AesonSpec
import RAGScope.Logging.RuntimeSpec qualified as RuntimeSpec

main :: IO ()
main =
  hspec $ do
    describe "RAGScope.Logging.Runtime" RuntimeSpec.spec
    describe "RAGScope.Logging.Backend.Json" AesonSpec.spec
