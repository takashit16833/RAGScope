module RAGScope.Logging.RuntimeSpec (
  spec,
) where

import RAGScope.Logging.Testing
import Test.Hspec

spec :: Spec
spec = do
  describe "emit" $ do
    context "とりあえずなんかテスト" $ do
      it "EventIdのテスト" $ do
        [logEvent] <- test :: IO [LogEvent]
        let (EventId actualId) = logEvent . eventId
        actualId `shouldBe` fixedUuid2
