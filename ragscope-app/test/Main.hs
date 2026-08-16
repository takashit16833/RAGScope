module Main (main) where

import Test.Hspec (describe, hspec)

import RAGScope.Logging.Backend.JsonSpec qualified as AesonSpec
import RAGScope.Logging.RuntimeSpec qualified as RuntimeSpec
import RAGScope.Logging.SchemaSpec qualified as SchemaSpec

main :: IO ()
main =
  hspec $ do
    describe "RAGScope.Logging.Runtime" RuntimeSpec.spec
    describe "RAGScope.Logging.Schema" SchemaSpec.spec
    describe "RAGScope.Logging.Backend.Json" AesonSpec.spec
