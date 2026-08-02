-- | 構造化ログ基盤を検査するためのテスト支援API
-- 固定値、メモリ出力、検査用イベントを提供する
module RAGScope.Logging.Testing (
  -- * 実行処理の入力
  LogLevel (Debug),
  Component (RAGScopeApp),
  EventContext (ExecutionContext),

  -- * 記録済みイベントの確認
  LogEvent (eventId),

  -- * 固定値
  fixedEventId,
  fixedExecutionId,
  fixedEventIdSource,
  fixedClock,

  -- * テスト用ロガー
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

-- | 期待値に使う固定のイベントID
fixedEventId :: EventId
fixedEventId =
  EventId $
    UUID.fromWords 0x9abcdef0 0x12345678 0x9abcdef0 0x12345678

-- | 実行単位のテストに使う固定の実行ID
fixedExecutionId :: ExecutionId
fixedExecutionId =
  ExecutionId $
    UUID.fromWords 0x12345678 0x9abcdef0 0x12345678 0x9abcdef0

-- | 固定のイベントIDを供給する処理
fixedEventIdSource :: EventIdSource
fixedEventIdSource =
  pure fixedEventId

-- 固定時刻（2026-08-01 12:34:56 UTC）
fixedTime :: UTCTime
fixedTime =
  UTCTime
    (fromGregorian 2026 8 1)
    (secondsToDiffTime (12 * 60 * 60 + 34 * 60 + 56))

-- | 固定時刻を供給する処理
fixedClock :: Clock
fixedClock = pure $ Timestamp fixedTime

-- ログイベントを保存し、記録順で読み出せる出力処理を構築する
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

-- | メモリ出力へ接続したロガーと記録済みイベントの読み出し処理を構築する
-- イベントの記録と期待値の検査は行わない
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

-- | ログ出力処理のテストに使う閉じたイベント型
data TestEvent
  = -- | 付加情報を持たないデバッグ用イベント
    TestDebugEvent

instance ToEventSpec TestEvent where
  toEventSpec TestDebugEvent =
    debugEventSpec
      (OperationName "test.operation")
      (EventName "test")
      emptyPayload
