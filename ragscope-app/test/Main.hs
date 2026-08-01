module Main (main) where

import RAGScope.Logging.RuntimeSpec qualified as RuntimeSpec
import Test.Hspec

main :: IO ()
main =
  hspec $ do
    describe "RAGScope.Logging.Runtime" RuntimeSpec.spec
