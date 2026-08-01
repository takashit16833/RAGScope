module RAGScope.Logging.RuntimeSpec (
  spec,
) where

import RAGScope.Logging.Testing
import Test.Hspec

newtype TestEventType = TestEventType String

instance ToEventSpec TestEventType where
  toEventSpec (TestEventType level) =
    case level of
      _ ->
        debugEventSpec
          (OperationName "operation")
          (EventName "event")
          emptyPayload

spec :: Spec
spec = do
  describe "emit" $ do
    context "とりあえずなんかテスト" $ do
      it "EventIdのテスト" $ do
        (memorySink, readEvents) <- newMemorySink

        let logger =
              mkLogger
                Debug
                RAGScopeApp
                (ExecutionContext fixedExecutionId)
                fixedEventIdSource
                fixedClock
                memorySink

        result <- emit logger (TestEventType "debug")
        logEvents <- readEvents

        result `shouldBe` Right ()

        length logEvents `shouldBe` 1

        let (EventId actualId) = (head logEvents).eventId

        actualId `shouldBe` fixedEvenUuid
