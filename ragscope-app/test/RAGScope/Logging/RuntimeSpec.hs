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

test :: IO [LogEvent]
test = do
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

  case result of
    Right () -> readEvents
    Left _ -> pure []

spec :: Spec
spec = do
  describe "emit" $ do
    context "とりあえずなんかテスト" $ do
      it "EventIdのテスト" $ do
        [logEvent] <- test :: IO [LogEvent]
        let (EventId actualEventUuid) = logEvent.eventId
        actualEventUuid `shouldBe` fixedEvenUuid
