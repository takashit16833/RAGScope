-- | 構造化ログ基盤を検査するためのテスト支援API
-- 固定値、メモリSink、Runtime検査用イベントを提供する
module RAGScope.Logging.Testing (
  -- * Runtimeの入力
  LogLevel (Debug, Info, Warn, Error),
  Component (RAGScopeApp, AIService),
  EventContext (ExecutionContext, ServiceContext),
  EventId,
  Timestamp,
  ExecutionId,
  EventIdSource,
  Clock,

  -- * 捕捉したLogEventの確認
  LogEvent (schemaVersion, eventId, timestamp, component, context, spec),

  -- * 固定値
  fixedEventId,
  fixedExecutionId,
  fixedTimestamp,
  fixedFractionalTimestamp,
  fixedOperationName,
  fixedEventName,
  fixedFieldName,
  fixedErrorCode,
  fixedSafeMessage,
  fixedEventIdSource,
  fixedClock,
  fixedErrorContext,
  fixedNormalEventSpec,
  fixedFailedEventSpec,
  fixedLogEvent,

  -- * テスト用Logger
  newMemoryLogger,
  newFailureLogger,

  -- * テスト用イベント
  TestEvent (TestDebugEvent),
  SchemaVersion (SchemaV1),
  testDebugEventSpec,

  -- * テスト用エラーカテゴリ
  LogErrorCategory (LogData, LogDependency, LogInput, LogInternal, LogResource, LogTimeout),
  LogValue (LogArray, LogBool, LogNumber, LogObject, LogText),
  logError,

  -- * テスト用JSON
  Payload (Payload),
  FieldName (FieldName),
) where

import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.Map qualified as Map
import Data.Time (UTCTime (..), fromGregorian, picosecondsToDiffTime, secondsToDiffTime)
import Data.UUID qualified as UUID
import RAGScope.Logging.Backend.Json ()
import RAGScope.Logging.Core (
  Component (AIService, RAGScopeApp),
  ErrorCode (ErrorCode),
  EventContext (ExecutionContext, ServiceContext),
  EventId (EventId),
  EventName (EventName),
  EventSpec,
  ExecutionId (ExecutionId),
  FieldName (FieldName),
  LogErrorCategory (LogData, LogDependency, LogInput, LogInternal, LogResource, LogTimeout),
  LogEvent (LogEvent, component, context, eventId, schemaVersion, spec, timestamp),
  LogLevel (Debug, Error, Info, Warn),
  LogValue (LogArray, LogBool, LogNumber, LogObject, LogText),
  OperationName (OperationName),
  Payload (Payload),
  SafeMessage (SafeMessage),
  SchemaVersion (SchemaV1),
  Timestamp (Timestamp),
  ToEventSpec (toEventSpec),
  debugEventSpec,
  emptyPayload,
  failedEventSpec,
  logError,
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
    UUID.fromWords 0x9abcdef0 0x12344678 0x9abcdef0 0x12345678

-- | 実行単位のテストに使う固定のExecutionId
fixedExecutionId :: ExecutionId
fixedExecutionId =
  ExecutionId $
    UUID.fromWords 0x12345678 0x9abc4ef0 0x82345678 0x9abcdef0

-- 固定時刻（2026-08-01 12:34:56 UTC）
fixedTime :: UTCTime
fixedTime =
  UTCTime
    (fromGregorian 2026 8 1)
    (secondsToDiffTime (12 * 60 * 60 + 34 * 60 + 56))

-- | JSON変換のテストに使う固定のTimestamp
fixedTimestamp :: Timestamp
fixedTimestamp = Timestamp fixedTime

-- | 小数秒を含むJSON変換のテストに使う固定のTimestamp
fixedFractionalTimestamp :: Timestamp
fixedFractionalTimestamp =
  Timestamp $
    UTCTime
      (fromGregorian 2026 8 1)
      (picosecondsToDiffTime ((12 * 60 * 60 + 34 * 60 + 56) * 1000000000000 + 123000000000))

-- | JSON変換のテストに使う固定のOperationName
fixedOperationName :: OperationName
fixedOperationName = OperationName "test.operation"

-- | JSON変換のテストに使う固定のEventName
fixedEventName :: EventName
fixedEventName = EventName "test"

-- | JSON変換のテストに使う固定のFieldName
fixedFieldName :: FieldName
fixedFieldName = FieldName "test_field"

-- | JSON変換のテストに使う固定のErrorCode
fixedErrorCode :: ErrorCode
fixedErrorCode = ErrorCode "test.error"

-- | JSON変換のテストに使う固定のSafeMessage
fixedSafeMessage :: SafeMessage
fixedSafeMessage = SafeMessage "safe message"

-- | 固定のEventIdを供給する処理
fixedEventIdSource :: EventIdSource
fixedEventIdSource =
  pure fixedEventId

-- | 固定時刻をTimestampとして供給する処理
fixedClock :: Clock
fixedClock = pure fixedTimestamp

-- | 固定ErrorContextをPayloadとして供給する処理
fixedErrorContext :: Payload
fixedErrorContext =
  Payload $
    Map.fromList [(FieldName "model_id", LogText "example-embedding-model")]

-- | 通常イベントを供給する処理
fixedNormalEventSpec :: EventSpec
fixedNormalEventSpec =
  debugEventSpec fixedOperationName fixedEventName $
    Payload $
      Map.fromList
        [ (FieldName "byte_count", LogNumber 2048)
        , (FieldName "duration_ms", LogNumber 12)
        ]

-- | 失敗イベントを供給する処理
fixedFailedEventSpec :: EventSpec
fixedFailedEventSpec =
  failedEventSpec
    fixedOperationName
    (Payload $ Map.fromList [(FieldName "duration_ms", LogNumber 12)])
    (logError LogInput fixedErrorCode fixedSafeMessage Nothing)

fixedLogEvent :: LogEvent
fixedLogEvent =
  LogEvent
    { schemaVersion = SchemaV1
    , eventId = fixedEventId
    , timestamp = fixedTimestamp
    , component = RAGScopeApp
    , context = ServiceContext
    , spec = fixedNormalEventSpec
    }

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
    fixedOperationName
    fixedEventName
    emptyPayload

instance ToEventSpec TestEvent where
  toEventSpec :: TestEvent -> EventSpec
  toEventSpec TestDebugEvent = testDebugEventSpec
