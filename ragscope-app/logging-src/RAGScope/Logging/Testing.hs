-- | 構造化ログ基盤を検査するためのテスト支援API。
--
-- 固定ID・固定時刻、メモリへ完成済みイベントを保存する 'Logger'、
-- Runtime検査用の閉じたイベント型を提供する。
--
-- このモジュールはテスト環境の準備と観測手段だけを担当する。
-- @emit@の呼び出しと期待値の検査はtest-suite側へ置く。
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

-- | Runtimeテストで期待値として使用する固定のEventId。
--
-- 'fixedEventIdSource'も同じ値を返す。
fixedEventId :: EventId
fixedEventId =
  EventId $
    UUID.fromWords 0x9abcdef0 0x12345678 0x9abcdef0 0x12345678

-- | execution scopeのテストで使用する固定のExecutionId。
fixedExecutionId :: ExecutionId
fixedExecutionId =
  ExecutionId $
    UUID.fromWords 0x12345678 0x9abcdef0 0x12345678 0x9abcdef0

-- | 呼び出すたびに 'fixedEventId' を返すEventIdSource。
--
-- ID生成の非決定性を排除し、完成したLogEventを安定して検査できるようにする。
fixedEventIdSource :: EventIdSource
fixedEventIdSource =
  pure fixedEventId

-- 'fixedClock'が返す固定UTC時刻（2026-08-01 12:34:56 UTC）。
fixedTime :: UTCTime
fixedTime =
  UTCTime
    (fromGregorian 2026 8 1)
    (secondsToDiffTime (12 * 60 * 60 + 34 * 60 + 56))

-- | 呼び出すたびに固定時刻を返すClock。
--
-- 時刻取得の非決定性を排除し、完成したLogEventを安定して検査できるようにする。
fixedClock :: Clock
fixedClock = pure $ Timestamp fixedTime

-- メモリへLogEventを保存し、emitされた順序で読み出すSinkを構築する。
--
-- 書き込み時はリストの先頭へ追加し、読み出し時に反転してemit順へ戻す。
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

-- | 指定したRuntime設定と依存を使い、メモリSinkへ接続したLoggerを構築する。
--
-- 戻り値の第2要素は、捕捉済みのLogEventをemit順で読み出すIOアクションである。
-- この関数自身はイベントをemitせず、期待値も検査しない。
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

-- | Logging Runtimeのテストで使用する閉じたイベント型。
data TestEvent
  = -- | Payloadを持たないdebug levelの通常イベント。
    TestDebugEvent

instance ToEventSpec TestEvent where
  toEventSpec TestDebugEvent =
    debugEventSpec
      (OperationName "test.operation")
      (EventName "test")
      emptyPayload
