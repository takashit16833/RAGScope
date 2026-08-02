module RAGScope.Logging.RuntimeSpec (
  spec,
) where

import RAGScope.Logging (emit)
import RAGScope.Logging.Testing (
  Component (RAGScopeApp),
  EventContext (ExecutionContext),
  LogEvent (eventId),
  LogLevel (Debug),
  TestEvent (TestDebugEvent),
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

        result <- emit logger TestDebugEvent
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
