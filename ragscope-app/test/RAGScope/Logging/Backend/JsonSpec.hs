-- 構造化ログのJSON表現が外部契約に一致することを検査する
module RAGScope.Logging.Backend.JsonSpec (
  spec,
) where

import Data.Aeson (ToJSON (toJSON), Value (Bool, Number, String), eitherDecode, encode, object, (.=))
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Test.Hspec (
  Expectation,
  Spec,
  describe,
  it,
  shouldBe,
 )

import RAGScope.Logging.Testing (
  Component (AIService, RAGScopeApp),
  EventContext (ExecutionContext, ServiceContext),
  FieldName (FieldName),
  LogErrorCategory (LogData, LogDependency, LogInput, LogInternal, LogResource, LogTimeout),
  LogLevel (Debug, Error, Info, Warn),
  LogValue (LogArray, LogBool, LogNumber, LogObject, LogText),
  Payload (Payload),
  SchemaVersion (SchemaV1),
  fixedErrorCode,
  fixedErrorContext,
  fixedEventId,
  fixedEventName,
  fixedExecutionId,
  fixedFailedEventSpec,
  fixedFieldName,
  fixedFractionalTimestamp,
  fixedLogEvent,
  fixedNormalEventSpec,
  fixedOperationName,
  fixedSafeMessage,
  fixedTimestamp,
  logError,
 )

shouldSerializeAs :: (ToJSON a) => a -> Value -> Expectation
actual `shouldSerializeAs` expected = do
  toJSON actual `shouldBe` expected
  eitherDecode (encode actual) `shouldBe` Right expected

spec :: Spec
spec = do
  describe "SchemaVersion" $ do
    it "SchemaV1を1として表現する" $ do
      SchemaV1 `shouldSerializeAs` Number 1

  describe "LogLevel" $ do
    it "Debugを\"debug\"として表現する" $ do
      Debug `shouldSerializeAs` String "debug"

    it "Infoを\"info\"として表現する" $ do
      Info `shouldSerializeAs` String "info"

    it "Warnを\"warn\"として表現する" $ do
      Warn `shouldSerializeAs` String "warn"

    it "Errorを\"error\"として表現する" $ do
      Error `shouldSerializeAs` String "error"

  describe "EventId" $ do
    it "UUIDを文字列として表現する" $ do
      fixedEventId `shouldSerializeAs` String "9abcdef0-1234-4678-9abc-def012345678"

  describe "ExecutionId" $ do
    it "UUIDを文字列として表現する" $ do
      fixedExecutionId `shouldSerializeAs` String "12345678-9abc-4ef0-8234-56789abcdef0"

  describe "OperationName" $ do
    it "名前を文字列として表現する" $ do
      fixedOperationName `shouldSerializeAs` String "test.operation"

  describe "EventName" $ do
    it "名前を文字列として表現する" $ do
      fixedEventName `shouldSerializeAs` String "test"

  describe "ErrorCode" $ do
    it "コードを文字列として表現する" $ do
      fixedErrorCode `shouldSerializeAs` String "test.error"

  describe "SafeMessage" $ do
    it "メッセージを文字列として表現する" $ do
      fixedSafeMessage `shouldSerializeAs` String "safe message"

  describe "Component" $ do
    it "RAGScopeAppを\"ragscope_app\"として表現する" $ do
      RAGScopeApp `shouldSerializeAs` String "ragscope_app"

    it "AIServiceを\"ai_service\"として表現する" $ do
      AIService `shouldSerializeAs` String "ai_service"

  describe "LogErrorCategory" $ do
    it "LogInputを\"input\"として表現する" $ do
      LogInput `shouldSerializeAs` String "input"

    it "LogResourceを\"resource\"として表現する" $ do
      LogResource `shouldSerializeAs` String "resource"

    it "LogDataを\"data\"として表現する" $ do
      LogData `shouldSerializeAs` String "data"

    it "LogDependencyを\"dependency\"として表現する" $ do
      LogDependency `shouldSerializeAs` String "dependency"

    it "LogTimeoutを\"timeout\"として表現する" $ do
      LogTimeout `shouldSerializeAs` String "timeout"

    it "LogInternalを\"internal\"として表現する" $ do
      LogInternal `shouldSerializeAs` String "internal"

  describe "Timestamp" $ do
    it "UTC時刻をISO 8601形式の文字列として表現する" $ do
      fixedTimestamp `shouldSerializeAs` String "2026-08-01T12:34:56Z"

    it "小数秒を保持してISO 8601形式の文字列として表現する" $ do
      fixedFractionalTimestamp `shouldSerializeAs` String "2026-08-01T12:34:56.123Z"

  describe "FieldName" $ do
    it "フィールド名を文字列として表現する" $ do
      fixedFieldName `shouldSerializeAs` String "test_field"

    it "MapのキーではJSON object keyとして表現する" $ do
      encode (Map.singleton fixedFieldName (1 :: Int)) `shouldBe` "{\"test_field\":1}"

  describe "LogValue" $ do
    it "LogTextを文字列値として表現する" $ do
      LogText "log_text" `shouldSerializeAs` String "log_text"

    it "LogNumberを数値として表現する" $ do
      LogNumber 1 `shouldSerializeAs` Number 1

    it "LogBoolを真偽値として表現する" $ do
      LogBool True `shouldSerializeAs` Bool True

    it "LogArrayをarrayとして表現する" $ do
      LogArray [LogText "hoge", LogText "fuga"] `shouldSerializeAs` toJSON (["hoge", "fuga"] :: [Text])

    it "LogObjectをobjectとして表現する" $ do
      LogObject (Payload (Map.fromList [(FieldName "hoge", LogText "fuga")]))
        `shouldSerializeAs` object ["hoge" .= ("fuga" :: Text)]

  describe "Payload" $ do
    it "FieldNameとLogValueをJSON objectとして表現する" $ do
      Payload (Map.fromList [(FieldName "hoge", LogText "fuga")])
        `shouldSerializeAs` object ["hoge" .= ("fuga" :: Text)]

  describe "EventContext" $ do
    it "ExecutionContextをscopeとexecution_idを持つobjectとして表現する" $ do
      ExecutionContext fixedExecutionId
        `shouldSerializeAs` object ["scope" .= ("execution" :: Text), "execution_id" .= String "12345678-9abc-4ef0-8234-56789abcdef0"]

    it "ServiceContextをscopeだけを持つobjectとして表現する" $ do
      ServiceContext `shouldSerializeAs` object ["scope" .= ("service" :: Text)]

  describe "LogError" $ do
    it "contextがない場合はcontextキーを省略する" $ do
      logError LogInput fixedErrorCode fixedSafeMessage Nothing
        `shouldSerializeAs` object
          [ "category" .= ("input" :: Text)
          , "code" .= String "test.error"
          , "message" .= String "safe message"
          ]

    it "contextがある場合はcontextをobjectとして含める" $ do
      logError LogInput fixedErrorCode fixedSafeMessage (Just fixedErrorContext)
        `shouldSerializeAs` object
          [ "category" .= ("input" :: Text)
          , "code" .= String "test.error"
          , "message" .= String "safe message"
          , "context" .= object ["model_id" .= String "example-embedding-model"]
          ]

  describe "EventSpec" $ do
    it "通常イベントではerrorキーを含めない" $ do
      fixedNormalEventSpec
        `shouldSerializeAs` object
          [ "operation" .= fixedOperationName
          , "event" .= fixedEventName
          , "level" .= Debug
          , "payload"
              .= object
                [ "byte_count" .= Number 2048
                , "duration_ms" .= Number 12
                ]
          ]

    it "失敗イベントではerrorを含める" $ do
      fixedFailedEventSpec
        `shouldSerializeAs` object
          [ "operation" .= fixedOperationName
          , "event" .= String "failed"
          , "level" .= Error
          , "payload"
              .= object
                [ "duration_ms" .= Number 12
                ]
          , "error"
              .= object
                [ "category" .= ("input" :: Text)
                , "code" .= String "test.error"
                , "message" .= String "safe message"
                ]
          ]

  describe "LogEvent" $ do
    it "共通項目とspecを持つobjectとして表現する" $ do
      fixedLogEvent
        `shouldSerializeAs` object
          [ "schema_version" .= SchemaV1
          , "event_id" .= fixedEventId
          , "timestamp" .= fixedTimestamp
          , "component" .= RAGScopeApp
          , "context" .= ServiceContext
          , "spec"
              .= object
                [ "operation" .= fixedOperationName
                , "event" .= fixedEventName
                , "level" .= Debug
                , "payload"
                    .= object
                      [ "byte_count" .= Number 2048
                      , "duration_ms" .= Number 12
                      ]
                ]
          ]
