module Main (main) where

import Test.Hspec
import RAGScope.Logging.TestingSpec qualified as TestingSpec

main :: IO ()
main =
  hspec $ do
    describe "RAGScope.Logging.Testing" TestingSpec.spec