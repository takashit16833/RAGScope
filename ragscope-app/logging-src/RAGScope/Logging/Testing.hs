-- | 構造化ログ基盤を検査するためのテスト支援API
-- 固定値、メモリ出力、Runtime検査用イベントを提供する
module RAGScope.Logging.Testing (
  -- * Runtimeの入力
  LogLevel (Debug),
  Component (RAGScopeApp),
  EventContext (ExecutionContext),

  -- * 捕捉したイベントの観測
  LogEvent (eventId),

  -- * 固定値
  fixedEventId,
  fixedExecutionId,
  fixedEventIdSource,
  fixedClock,

  -- * テスト用Logger
  newMemoryLogger,

  -- * テスト用イベント
  TestEvent (TestDebugEvent),
) where

import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Data.UUID qualified as UUID
import RAGScope.Logging.Core (
  Component (RAGScopeApp),
  EventContext (ExecutionContext),
  EventId (EventId),
  EventName (EventName),
  ExecutionId (ExecutionId),
  LogEvent (eventId),
  LogLevel (Debug),
  OperationName (OperationName),
  Timestamp (Timestamp),
  ToEventSpec (toEventSpec),
  debugEventSpec,
  emptyPayload,
 )
import RAGScope.Logging.Runtime (
  Clock,
  EventIdSource,
  Logger,
  Sink,
  mkLogger,
 )

-- | Runtimeテストで期待値に使う固定のEventId
fixedEventId :: EventId
fixedEventId =
  EventId $
    UUID.fromWords 0x9abcdef0 0x12345678 0x9abcdef0 0x12345678

-- | execution scopeのテストで使う固定のExecutionId
fixedExecutionId :: ExecutionId
fixedExecutionId =
  ExecutionId $
    UUID.fromWords 0x12345678 0x9abcdef0 0x12345678 0x9abcdef0

-- | 常に 'fixedEventId' を返すEventIdSource
fixedEventIdSource :: EventIdSource
fixedEventIdSource =
  pure fixedEventId

-- 'fixedClock'が返す固定UTC時刻（2026-08-01 12:34:56 UTC）
fixedTime :: UTCTime
fixedTime =
  UTCTime
    (fromGregorian 2026 8 1)
    (secondsToDiffTime (12 * 60 * 60 + 34 * 60 + 56))

-- | 常に固定時刻を返すClock
fixedClock :: Clock
fixedClock = pure $ Timestamp fixedTime

-- LogEventを保存し、emit順で読み出せるSinkを構築する
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

-- | メモリSinkへ接続したLoggerと捕捉イベントの読出処理を構築する
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

-- | Logging Runtimeのテストで使用する閉じたイベント型
data TestEvent
  = -- | Payloadを持たないdebug levelの通常イベント
    TestDebugEvent

instance ToEventSpec TestEvent where
  toEventSpec TestDebugEvent =
    debugEventSpec
      (OperationName "test.operation")
      (EventName "test")
      emptyPayload
