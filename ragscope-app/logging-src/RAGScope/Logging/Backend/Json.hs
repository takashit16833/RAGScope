{-# OPTIONS_GHC -Wno-orphans #-}

-- | LogEventを契約どおりのJSONへ変換する。
--
-- CoreをAeson非依存に保ち、JSON instanceをこのモジュールへ集中させるため
-- 意図的にorphan instanceとする
module RAGScope.Logging.Backend.Json (encodeLogEvent) where

import Data.Aeson (
  Encoding,
  Options (fieldLabelModifier, sumEncoding),
  SumEncoding (UntaggedValue),
  ToJSON (toEncoding),
  ToJSONKey (toJSONKey),
  ToJSONKeyFunction,
  Value (..),
  defaultOptions,
  encode,
  genericToEncoding,
  genericToJSON,
  object,
  toJSON,
  (.=),
 )
import Data.Aeson.Types (toJSONKeyText)
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)

import RAGScope.Logging.Core (
  Component (AIService, RAGScopeApp),
  ErrorCode (..),
  EventContext (ExecutionContext, ServiceContext),
  EventId (..),
  EventKind (FailedEvent, NormalEvent),
  EventName (..),
  EventSpec (eventKind, operation, payload),
  ExecutionId (..),
  FieldName (..),
  LogError (category, code, context, message),
  LogErrorCategory (
    LogData,
    LogDependency,
    LogInput,
    LogInternal,
    LogResource,
    LogTimeout
  ),
  LogEvent,
  LogLevel (ErrorLevel, NormalLevel),
  LogValue,
  NormalLogLevel (Debug, Info, Warn),
  OperationName (..),
  Payload,
  SafeMessage (..),
  SchemaVersion (SchemaV1),
  Timestamp (..),
  effectiveLogLevel,
 )

-- Schema v1は外部契約上のnumber 1として表現する。
instance ToJSON SchemaVersion where
  toJSON :: SchemaVersion -> Value
  toJSON SchemaV1 = toJSON (1 :: Int)

  toEncoding :: SchemaVersion -> Encoding
  toEncoding SchemaV1 = toEncoding (1 :: Int)

-- 外部契約上のログレベル名を固定する。
logLevelValue :: LogLevel -> Value
logLevelValue (NormalLevel Debug) = String "debug"
logLevelValue (NormalLevel Info) = String "info"
logLevelValue (NormalLevel Warn) = String "warn"
logLevelValue ErrorLevel = String "error"

instance ToJSON LogLevel where
  toJSON :: LogLevel -> Value
  toJSON = logLevelValue

  toEncoding :: LogLevel -> Encoding
  toEncoding = toEncoding . logLevelValue

instance ToJSON EventId where
  toJSON :: EventId -> Value
  toJSON (EventId uuid) = toJSON uuid

  toEncoding :: EventId -> Encoding
  toEncoding (EventId uuid) = toEncoding uuid

instance ToJSON ExecutionId where
  toJSON :: ExecutionId -> Value
  toJSON (ExecutionId uuid) = toJSON uuid

  toEncoding :: ExecutionId -> Encoding
  toEncoding (ExecutionId uuid) = toEncoding uuid

instance ToJSON OperationName where
  toJSON :: OperationName -> Value
  toJSON (OperationName operationName) = toJSON operationName

  toEncoding :: OperationName -> Encoding
  toEncoding (OperationName operationName) = toEncoding operationName

instance ToJSON EventName where
  toJSON :: EventName -> Value
  toJSON (EventName eventName) = toJSON eventName

  toEncoding :: EventName -> Encoding
  toEncoding (EventName eventName) = toEncoding eventName

instance ToJSON ErrorCode where
  toJSON :: ErrorCode -> Value
  toJSON (ErrorCode errorCode) = toJSON errorCode

  toEncoding :: ErrorCode -> Encoding
  toEncoding (ErrorCode errorCode) = toEncoding errorCode

instance ToJSON SafeMessage where
  toJSON :: SafeMessage -> Value
  toJSON (SafeMessage safeMessage) = toJSON safeMessage

  toEncoding :: SafeMessage -> Encoding
  toEncoding (SafeMessage safeMessage) = toEncoding safeMessage

-- Coreのconstructor名から独立した、外部契約上のcomponent名を固定する。
componentValue :: Component -> Value
componentValue RAGScopeApp = String "ragscope_app"
componentValue AIService = String "ai_service"

instance ToJSON Component where
  toJSON :: Component -> Value
  toJSON = componentValue

  toEncoding :: Component -> Encoding
  toEncoding = toEncoding . componentValue

-- Coreのconstructor名から独立した、外部契約上のerror category名を固定する。
logErrorCategoryValue :: LogErrorCategory -> Value
logErrorCategoryValue LogInput = String "input"
logErrorCategoryValue LogResource = String "resource"
logErrorCategoryValue LogData = String "data"
logErrorCategoryValue LogDependency = String "dependency"
logErrorCategoryValue LogTimeout = String "timeout"
logErrorCategoryValue LogInternal = String "internal"

instance ToJSON LogErrorCategory where
  toJSON :: LogErrorCategory -> Value
  toJSON = logErrorCategoryValue

  toEncoding :: LogErrorCategory -> Encoding
  toEncoding = toEncoding . logErrorCategoryValue

instance ToJSON Timestamp where
  toJSON :: Timestamp -> Value
  toJSON (Timestamp timestamp) = toJSON timestamp

  toEncoding :: Timestamp -> Encoding
  toEncoding (Timestamp timestamp) = toEncoding timestamp

instance ToJSON FieldName where
  toJSON :: FieldName -> Value
  toJSON (FieldName fieldName) = toJSON fieldName

  toEncoding :: FieldName -> Encoding
  toEncoding (FieldName fieldName) = toEncoding fieldName

instance ToJSONKey FieldName where
  toJSONKey :: ToJSONKeyFunction FieldName
  toJSONKey = toJSONKeyText (\(FieldName fieldName) -> fieldName)

-- constructor tagを出さず、LogValueをJSON値そのものとして表現する。
logValueOptions :: Options
logValueOptions =
  defaultOptions
    { sumEncoding = UntaggedValue
    }

instance ToJSON LogValue where
  toJSON :: LogValue -> Value
  toJSON = genericToJSON logValueOptions

  toEncoding :: LogValue -> Encoding
  toEncoding = genericToEncoding logValueOptions

instance ToJSON Payload where
  toEncoding :: Payload -> Encoding
  toEncoding = genericToEncoding defaultOptions

-- execution/serviceの区別をscopeフィールドとして外部契約へ表現する。
eventContextValue :: EventContext -> Value
eventContextValue (ExecutionContext executionId) =
  object
    [ "scope" .= ("execution" :: Text)
    , "execution_id" .= executionId
    ]
eventContextValue ServiceContext = object ["scope" .= ("service" :: Text)]

instance ToJSON EventContext where
  toJSON :: EventContext -> Value
  toJSON = eventContextValue

  toEncoding :: EventContext -> Encoding
  toEncoding = toEncoding . eventContextValue

-- contextがNothingならnullを出さず、contextキー自体を省略する。
logErrorObject :: LogError -> Value
logErrorObject logErr =
  object $
    [ "category" .= logErr.category
    , "code" .= logErr.code
    , "message" .= logErr.message
    ]
      <> maybe
        []
        (\payload -> ["context" .= payload])
        logErr.context

instance ToJSON LogError where
  toJSON :: LogError -> Value
  toJSON = logErrorObject

  toEncoding :: LogError -> Encoding
  toEncoding = toEncoding . logErrorObject

eventSpecValue :: EventSpec -> Value
eventSpecValue eventSpec =
  case eventSpec.eventKind of
    NormalEvent event _ ->
      object
        [ "operation" .= eventSpec.operation
        , "event" .= event
        , "level" .= effectiveLogLevel eventSpec
        , "payload" .= eventSpec.payload
        ]
    FailedEvent logErrorValue ->
      object
        [ "operation" .= eventSpec.operation
        , "event" .= ("failed" :: Text)
        , "level" .= effectiveLogLevel eventSpec
        , "payload" .= eventSpec.payload
        , "error" .= logErrorValue
        ]

instance ToJSON EventSpec where
  toJSON :: EventSpec -> Value
  toJSON = eventSpecValue

  toEncoding :: EventSpec -> Encoding
  toEncoding = toEncoding . eventSpecValue

-- HaskellのcamelCase field名を外部JSON契約のsnake_caseへ変換する。
logEventOptions :: Options
logEventOptions =
  defaultOptions
    { fieldLabelModifier = \case
        "schemaVersion" -> "schema_version"
        "eventId" -> "event_id"
        field -> field
    }

instance ToJSON LogEvent where
  toJSON :: LogEvent -> Value
  toJSON = genericToJSON logEventOptions

  toEncoding :: LogEvent -> Encoding
  toEncoding = genericToEncoding logEventOptions

-- | productionコードはAesonを直接使用せずこの関数でencodeする
encodeLogEvent :: LogEvent -> LazyByteString.ByteString
encodeLogEvent = encode
