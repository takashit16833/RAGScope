module Main (main) where

import Test.Hspec (hspec)

import RAGScope.Telemetry.BoundaryUsageSpec qualified as BoundaryUsageSpec

main :: IO ()
main =
  hspec BoundaryUsageSpec.spec
