-- Logging Runtimeの振る舞いを検査する
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
    context "出力対象のイベントの場合" $ do
      it "EventIdSourceが返したEventIdをLogEventへ設定する" $ do
        -- メモリSinkへ接続したLoggerと読み出し処理を準備する
        (logger, readCapturedEvents) <-
          newMemoryLogger
            Debug
            RAGScopeApp
            (ExecutionContext fixedExecutionId)
            fixedEventIdSource
            fixedClock

        -- テスト用イベントをemitする
        result <- emit logger TestDebugEvent
        result `shouldBe` Right ()

        -- 捕捉したLogEventのEventIdを検査する
        capturedEvents <- readCapturedEvents
        case capturedEvents of
          [logEvent] ->
            logEvent.eventId `shouldBe` fixedEventId
          _ ->
            expectationFailure $
              "ログイベントが1件であることを期待しましたが、"
                <> show (length capturedEvents)
                <> "件でした"
