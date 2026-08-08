-- Logging Runtimeの振る舞いを検査する
module RAGScope.Logging.RuntimeSpec (
  spec,
) where

import Test.Hspec (
  Spec,
  context,
  describe,
  expectationFailure,
  it,
  shouldBe,
 )

import RAGScope.Logging (LoggingFailure (LoggingSinkFailure), emit)
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
  newFailureLogger,
  newMemoryLogger,
  testDebugEventSpec,
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

    context "最低ログレベル未満のイベントの場合" $ do
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

        -- LogEventが捕捉されないことを検査する
        capturedEvents <- readCapturedEvents
        capturedEvents `shouldBe` []

    context "ロガーがエラーを返す場合" $ do
      it "変換済みログの出力に失敗した" $ do
        -- 失敗するSinkへ接続したLoggerを準備する
        let logger =
              newFailureLogger
                Debug
                RAGScopeApp
                (ExecutionContext fixedExecutionId)
                fixedEventIdSource
                fixedClock

        -- テスト用イベントをemitする
        result <- emit logger TestDebugEvent
        result `shouldBe` Left LoggingSinkFailure
