-- | 構造化ログ基盤を検査するためのテスト支援API
-- 固定値、メモリSink、Runtime検査用イベントを提供する
module RAGScope.Logging.Testing (
  -- * Runtimeの入力
  LogLevel (Debug, Info),
  Component (RAGScopeApp),
  EventContext (ExecutionContext),

  -- * 捕捉したLogEventの確認
  LogEvent (schemaVersion, eventId, timestamp, component, context, spec),

  -- * 固定値
  fixedEventId,
  fixedExecutionId,
  fixedEventIdSource,
  fixedClock,

  -- * テスト用Logger
  newMemoryLogger,
  newFailureLogger,

  -- * テスト用イベント
  TestEvent (TestDebugEvent),
  SchemaVersion (SchemaV1),
  testDebugEventSpec,
) where

import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Data.UUID qualified as UUID
import RAGScope.Logging.Core (
  Component (RAGScopeApp),
  EventContext (ExecutionContext),
  EventId (EventId),
  EventName (EventName),
  EventSpec,
  ExecutionId (ExecutionId),
  LogEvent (component, context, eventId, schemaVersion, spec, timestamp),
  LogLevel (Debug, Info),
  OperationName (OperationName),
  SchemaVersion (SchemaV1),
  Timestamp (Timestamp),
  ToEventSpec (toEventSpec),
  debugEventSpec,
  emptyPayload,
 )
import RAGScope.Logging.Runtime (
  Clock,
  EventIdSource,
  Logger,
  LoggingFailure (LoggingSinkFailure),
  Sink,
  mkLogger,
 )

-- | 期待値に使う固定のEventId
fixedEventId :: EventId
fixedEventId =
  EventId $
    UUID.fromWords 0x9abcdef0 0x12345678 0x9abcdef0 0x12345678

-- | 実行単位のテストに使う固定のExecutionId
fixedExecutionId :: ExecutionId
fixedExecutionId =
  ExecutionId $
    UUID.fromWords 0x12345678 0x9abcdef0 0x12345678 0x9abcdef0

-- | 固定のEventIdを供給する処理
fixedEventIdSource :: EventIdSource
fixedEventIdSource =
  pure fixedEventId

-- 固定時刻（2026-08-01 12:34:56 UTC）
fixedTime :: UTCTime
fixedTime =
  UTCTime
    (fromGregorian 2026 8 1)
    (secondsToDiffTime (12 * 60 * 60 + 34 * 60 + 56))

-- | 固定時刻をTimestampとして供給する処理
fixedClock :: Clock
fixedClock = pure $ Timestamp fixedTime

-- LogEventを保存し、記録順で読み出せるSinkを構築する
-- 保存時は先頭へ追加し、読み出し時に反転する
newMemorySink :: IO (Sink, IO [LogEvent])
newMemorySink = do
  eventsRef <- newIORef []

  let
    sink :: Sink
    sink logEvent = do
      modifyIORef' eventsRef (logEvent :)
      pure (Right ())

    readCapturedEvents =
      reverse <$> readIORef eventsRef

  pure (sink, readCapturedEvents)

-- 変換済みログの出力に失敗するSinkを構築する
failureSink :: Sink
failureSink _ = pure $ Left LoggingSinkFailure

-- | メモリSinkへ接続したLoggerと捕捉したLogEventの読み出し処理を構築する
-- イベントのemitと期待値の検査は行わない
newMemoryLogger ::
  LogLevel ->
  Component ->
  EventContext ->
  EventIdSource ->
  Clock ->
  IO (Logger, IO [LogEvent])
newMemoryLogger minimumLevel component context eventIdSource clock = do
  (memorySink, readCapturedEvents) <- newMemorySink

  let logger =
        mkLogger
          minimumLevel
          component
          context
          eventIdSource
          clock
          memorySink

  pure (logger, readCapturedEvents)

-- | 失敗するSinkへ接続したLoggerを構築する
-- イベントのemitと期待値の検査は行わない
newFailureLogger ::
  LogLevel ->
  Component ->
  EventContext ->
  EventIdSource ->
  Clock ->
  Logger
newFailureLogger minimumLevel component context eventIdSource clock =
  mkLogger
    minimumLevel
    component
    context
    eventIdSource
    clock
    failureSink

-- | Logging Runtimeのテストに使う閉じたイベント型
data TestEvent
  = -- | Payloadを持たないdebug levelの通常イベント
    TestDebugEvent

-- | 'TestDebugEvent'を変換したEventSpec
testDebugEventSpec :: EventSpec
testDebugEventSpec =
  debugEventSpec
    (OperationName "test.operation")
    (EventName "test")
    emptyPayload

instance ToEventSpec TestEvent where
  toEventSpec :: TestEvent -> EventSpec
  toEventSpec TestDebugEvent = testDebugEventSpec
