module Main (main) where

import Test.Hspec (describe, hspec)

import RAGScope.Execution.ObservationSpec qualified as ObservationSpec
import RAGScope.Execution.ResultSpec qualified as ResultSpec
import RAGScope.Logging.Backend.JsonSpec qualified as AesonSpec
import RAGScope.Logging.OutputBoundarySpec qualified as OutputBoundarySpec
import RAGScope.Logging.RuntimeSpec qualified as RuntimeSpec
import RAGScope.Logging.SchemaSpec qualified as SchemaSpec

main :: IO ()
main =
  hspec $ do
    describe "RAGScope.Logging.Runtime" RuntimeSpec.spec
    describe "RAGScope.Logging.Schema" SchemaSpec.spec
    describe "RAGScope.Execution.Result" ResultSpec.spec
    describe "RAGScope.Execution.Observation" ObservationSpec.spec
    describe "RAGScope.Logging.OutputBoundary" OutputBoundarySpec.spec
    describe "RAGScope.Logging.Backend.Json" AesonSpec.spec
