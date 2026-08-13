-- | LogEventを契約どおりのJSONへ変換し、標準エラーへ1行で出力する。
module RAGScope.Logging.Backend.AesonStderr (
  aesonStderrSink,
  encodeLogEvent,
) where

import Control.Exception (IOException, try)
import Data.Aeson (
  Value (..),
  encode,
  object,
  toJSON,
  (.=),
 )
import Data.Aeson.Key qualified as Key
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (
  UTCTime,
  defaultTimeLocale,
  formatTime,
  utctDayTime,
 )
import Data.UUID qualified as UUID
import RAGScope.Logging.Core
import RAGScope.Logging.Runtime (
  LoggingFailure (..),
  Sink,
 )
import System.IO (
  hFlush,
  stderr,
 )

-- | AesonでJSON化したLogEventを、標準エラーへ1行で出力するSink。
aesonStderrSink :: Sink
aesonStderrSink logEvent = do
  -- JSONのValueをByteStringへ変換して出力する。
  result <- tryWrite (encode (encodeLogEvent logEvent))

  -- IO例外をLoggingFailureへ変換する。
  pure $
    case result of
      Left _ ->
        Left LoggingSinkFailure
      Right () ->
        Right ()

-- | JSONを標準エラーへ書き込み、発生したIO例外を値として返す。
tryWrite :: LazyByteString.ByteString -> IO (Either IOException ())
tryWrite encoded =
  try $ do
    -- 1イベントを1行のJSONとして出力する。
    LazyByteString.hPutStrLn stderr encoded

    -- バッファに残さず、すぐに出力する。
    hFlush stderr

-- | 完成済みLogEventをJSON契約のroot objectへ変換する。
--
-- Haskell内部ではEventSpecを入れ子で保持するが、JSONではrootへ平坦化する。
encodeLogEvent :: LogEvent -> Value
encodeLogEvent logEvent =
  let
    -- イベント定義に属する情報を取り出す。
    eventSpec = logEvent.spec

    -- すべてのログイベントに必須となる項目。
    requiredFields =
      [ "schema_version" .= encodeSchemaVersion logEvent.schemaVersion
      , "event_id" .= encodeEventId logEvent.eventId
      , "timestamp" .= encodeTimestamp logEvent.timestamp
      , "level" .= encodeLogLevel eventSpec.level
      , "event" .= encodeEventName eventSpec.event
      , "component" .= encodeComponent logEvent.component
      , "operation" .= encodeOperationName eventSpec.operation
      , "context" .= encodeEventContext logEvent.context
      , "payload" .= encodePayload eventSpec.payload
      ]

    -- エラー情報がある場合だけerrorフィールドを追加する。
    optionalError =
      case eventSpec.errorInfo of
        Nothing ->
          []
        Just logErrorValue ->
          ["error" .= encodeLogError logErrorValue]
   in
    -- 必須項目と任意項目をまとめてroot objectを作る。
    object (requiredFields <> optionalError)

-- | SchemaVersionをJSON上の数値へ変換する。
encodeSchemaVersion :: SchemaVersion -> Int
encodeSchemaVersion = \case
  SchemaV1 ->
    1

-- | EventIdのUUIDを文字列へ変換する。
encodeEventId :: EventId -> Text
encodeEventId (EventId uuid) =
  UUID.toText uuid

-- | TimestampをUTCのISO 8601形式へ変換する。
encodeTimestamp :: Timestamp -> Text
encodeTimestamp (Timestamp utcTime) =
  timestampBase utcTime
    <> "."
    <> Text.justifyRight 3 '0' (Text.pack (show (milliseconds utcTime)))
    <> "Z"

-- | 秒未満は切り捨て、常に3桁のミリ秒として出力する。
milliseconds :: UTCTime -> Integer
milliseconds utcTime =
  floor (toRational (utctDayTime utcTime) * 1000) `mod` 1000

-- | Timestampのミリ秒より前の部分を作る。
timestampBase :: UTCTime -> Text
timestampBase =
  Text.pack
    . formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S"

-- | LogLevelをJSON契約上の文字列へ変換する。
encodeLogLevel :: LogLevel -> Text
encodeLogLevel = \case
  Debug ->
    "debug"
  Info ->
    "info"
  Warn ->
    "warn"
  Error ->
    "error"

-- | EventNameから内部の文字列を取り出す。
encodeEventName :: EventName -> Text
encodeEventName (EventName eventName) =
  eventName

-- | ComponentをJSON契約上の文字列へ変換する。
encodeComponent :: Component -> Text
encodeComponent = \case
  RAGScopeApp ->
    "ragscope_app"
  AIService ->
    "ai_service"

-- | OperationNameから内部の文字列を取り出す。
encodeOperationName :: OperationName -> Text
encodeOperationName (OperationName operationName) =
  operationName

-- | EventContextをscopeに応じたJSON objectへ変換する。
encodeEventContext :: EventContext -> Value
encodeEventContext = \case
  -- 実行単位のログにはexecution_idを含める。
  ExecutionContext (ExecutionId executionId) ->
    object
      [ "scope" .= ("execution" :: Text)
      , "execution_id" .= UUID.toText executionId
      ]
  -- サービス単位のログには識別子を含めない。
  ServiceContext ->
    object
      ["scope" .= ("service" :: Text)]

-- | Payloadの各フィールドをJSON objectへ変換する。
encodePayload :: Payload -> Value
encodePayload (Payload fields) =
  object
    [ Key.fromText fieldName .= encodeLogValue logValue
    | (FieldName fieldName, logValue) <- Map.toList fields
    ]

-- | LogValueを対応するJSONの値へ変換する。
encodeLogValue :: LogValue -> Value
encodeLogValue = \case
  -- 文字列をJSON文字列へ変換する。
  LogText text ->
    String text
  -- 数値をJSON数値へ変換する。
  LogNumber number ->
    Number number
  -- 真偽値をJSON真偽値へ変換する。
  LogBool boolean ->
    Bool boolean
  -- 配列内の値も再帰的に変換する。
  LogArray values ->
    toJSON (map encodeLogValue values)
  -- 入れ子のobjectもPayloadとして再帰的に変換する。
  LogObject payload ->
    encodePayload payload

-- | LogErrorをJSON契約上のerror objectへ変換する。
encodeLogError :: LogError -> Value
encodeLogError logErrorValue =
  let
    -- すべてのエラーに必須となる項目。
    requiredFields =
      [ "category" .= encodeLogErrorCategory logErrorValue.category
      , "code" .= encodeErrorCode logErrorValue.code
      , "message" .= encodeSafeMessage logErrorValue.message
      ]

    -- 補足情報がある場合だけcontextフィールドを追加する。
    optionalContext =
      case logErrorValue.context of
        Nothing ->
          []
        Just payload ->
          ["context" .= encodePayload payload]
   in
    object (requiredFields <> optionalContext)

-- | LogErrorCategoryをJSON契約上の文字列へ変換する。
encodeLogErrorCategory :: LogErrorCategory -> Text
encodeLogErrorCategory = \case
  LogInput ->
    "input"
  LogResource ->
    "resource"
  LogData ->
    "data"
  LogDependency ->
    "dependency"
  LogTimeout ->
    "timeout"
  LogInternal ->
    "internal"

-- | ErrorCodeから内部の文字列を取り出す。
encodeErrorCode :: ErrorCode -> Text
encodeErrorCode (ErrorCode errorCode) =
  errorCode

-- | SafeMessageから外部出力可能な文字列を取り出す。
encodeSafeMessage :: SafeMessage -> Text
encodeSafeMessage (SafeMessage safeMessage) =
  safeMessage
