-- Logging Runtimeの振る舞いを検査する
module RAGScope.Logging.RuntimeSpec (
  spec,
) where

import RAGScope.Logging (emit)
import RAGScope.Logging.Testing (
  Component (RAGScopeApp),
  EventContext (ExecutionContext),
  LogEvent (..),
  LogLevel (Debug, Info),
  SchemaVersion (SchemaV1),
  TestEvent (TestDebugEvent),
  fixedClock,
  fixedEventId,
  fixedEventIdSource,
  fixedExecutionId,
  newMemoryLogger,
  testDebugEventSpec,
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
      it "共通情報とEventSpecからLogEventを組み立てる" $ do
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

        -- 捕捉したLogEventの各項目を検査する
        capturedEvents <- readCapturedEvents
        case capturedEvents of
          [logEvent] -> do
            logEvent.schemaVersion `shouldBe` SchemaV1
            logEvent.eventId `shouldBe` fixedEventId
            (logEvent.timestamp `shouldBe`) =<< fixedClock
            logEvent.component `shouldBe` RAGScopeApp
            logEvent.context `shouldBe` ExecutionContext fixedExecutionId
            logEvent.spec `shouldBe` testDebugEventSpec
          _ ->
            expectationFailure $
              "ログイベントが1件であることを期待しましたが、"
                <> show (length capturedEvents)
                <> "件でした"

      it "最低ログレベル未満を出力しない" $ do
        -- メモリSinkへ接続したLoggerと読み出し処理を準備する
        (logger, readCapturedEvents) <-
          newMemoryLogger
            Info
            RAGScopeApp
            (ExecutionContext fixedExecutionId)
            fixedEventIdSource
            fixedClock

        -- テスト用イベントをemitする
        result <- emit logger TestDebugEvent
        result `shouldBe` Right ()

        -- 捕捉したLogEventの各項目を検査する
        capturedEvents <- readCapturedEvents
        length capturedEvents `shouldBe` 0
