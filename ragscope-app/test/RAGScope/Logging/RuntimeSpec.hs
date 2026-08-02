module RAGScope.Logging.RuntimeSpec (
  spec,
) where

import RAGScope.Logging (emit)
import RAGScope.Logging.EventSpec (
  EventName (EventName),
  OperationName (OperationName),
  ToEventSpec (..),
  debugEventSpec,
  emptyPayload,
 )
import RAGScope.Logging.Testing (
  Component (RAGScopeApp),
  EventContext (ExecutionContext),
  LogEvent (eventId),
  LogLevel (Debug),
  fixedClock,
  fixedEventId,
  fixedEventIdSource,
  fixedExecutionId,
  newMemoryLogger,
 )
import Test.Hspec (
  Spec,
  context,
  describe,
  expectationFailure,
  it,
  shouldBe,
 )

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
        (logger, readEvents) <-
          newMemoryLogger
            Debug
            RAGScopeApp
            (ExecutionContext fixedExecutionId)
            fixedEventIdSource
            fixedClock

        result <- emit logger (TestEventType "debug")
        result `shouldBe` Right ()

        logEvents <- readEvents
        case logEvents of
          [logEvent] ->
            logEvent.eventId `shouldBe` fixedEventId
          _ ->
            expectationFailure $
              "ログイベントが1件であることを期待しましたが、"
                <> show (length logEvents)
                <> "件でした"
