module Main (main) where

import RAGScope.Logging.Backend.JsonSpec qualified as AesonSpec
import RAGScope.Logging.RuntimeSpec qualified as RuntimeSpec
import Test.Hspec (describe, hspec)

main :: IO ()
main =
  hspec $ do
    describe "RAGScope.Logging.Runtime" RuntimeSpec.spec
    describe "RAGScope.Logging.Backend.Json" AesonSpec.spec
