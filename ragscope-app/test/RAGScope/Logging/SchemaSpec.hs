-- 共通ログ契約へのfixtureとHaskell生成LogEventの適合性をJSON Schemaで検証する。
module RAGScope.Logging.SchemaSpec (
  spec,
) where

import Data.Aeson (ToJSON (toJSON), Value, eitherDecodeFileStrict')
import Data.JSON.JSONSchema (validateJSONSchema)
import Test.Hspec (Spec, describe, it, shouldNotSatisfy, shouldSatisfy)

import RAGScope.Logging.Testing (fixedExecutionFailedLogEvent, fixedExecutionLogEvent, fixedLogEvent, fixedPayloadTypesEvent)

decodeJsonFile :: FilePath -> IO Value
decodeJsonFile filePath = do
  result <- eitherDecodeFileStrict' filePath

  case result of
    Left err ->
      fail $ "JSONファイルをデコードできませんでした: " <> filePath <> ": " <> err
    Right value ->
      pure value

loadLogEventSchema :: IO Value
loadLogEventSchema =
  decodeJsonFile "../contracts/logging/v1/log-event.schema.json"

validFixturePath :: FilePath -> FilePath
validFixturePath fileName = "../contracts/logging/v1/fixtures/valid/" <> fileName

invalidFixturePath :: FilePath -> FilePath
invalidFixturePath fileName = "../contracts/logging/v1/fixtures/invalid/" <> fileName

itAcceptsValidFixture :: FilePath -> Spec
itAcceptsValidFixture fileName =
  it (fileName <> "がSchemaへ適合する") $ do
    schema <- loadLogEventSchema
    fixture <- decodeJsonFile $ validFixturePath fileName

    fixture `shouldSatisfy` validateJSONSchema schema

itRejectsInvalidFixture :: FilePath -> Spec
itRejectsInvalidFixture fileName =
  it (fileName <> "がSchemaから拒否される") $ do
    schema <- loadLogEventSchema
    fixture <- decodeJsonFile $ invalidFixturePath fileName

    fixture `shouldNotSatisfy` validateJSONSchema schema

spec :: Spec
spec = do
  describe "valid fixtures" $ do
    itAcceptsValidFixture "execution-succeeded.json"
    itAcceptsValidFixture "execution-failed.json"
    itAcceptsValidFixture "service-succeeded.json"

  describe "invalid fixtures" $ do
    itRejectsInvalidFixture "execution-missing-execution-id.json"
    itRejectsInvalidFixture "failed-non-error-level.json"
    itRejectsInvalidFixture "failed-without-error.json"
    itRejectsInvalidFixture "invalid-error-category.json"
    itRejectsInvalidFixture "invalid-error-code.json"
    itRejectsInvalidFixture "invalid-event-id.json"
    itRejectsInvalidFixture "invalid-timestamp.json"
    itRejectsInvalidFixture "missing-required-field.json"
    itRejectsInvalidFixture "normal-error-level.json"
    itRejectsInvalidFixture "normal-with-error.json"
    itRejectsInvalidFixture "null-payload-value.json"
    itRejectsInvalidFixture "service-with-execution-id.json"
    itRejectsInvalidFixture "unexpected-root-field.json"

  describe "Haskell generated LogEvent" $ do
    it "service通常イベントがSchemaへ適合する" $ do
      schema <- loadLogEventSchema
      toJSON fixedLogEvent `shouldSatisfy` validateJSONSchema schema

    it "execution通常イベントがSchemaへ適合する" $ do
      schema <- loadLogEventSchema
      toJSON fixedExecutionLogEvent `shouldSatisfy` validateJSONSchema schema

    it "execution失敗イベントがSchemaへ適合する" $ do
      schema <- loadLogEventSchema
      toJSON fixedExecutionFailedLogEvent `shouldSatisfy` validateJSONSchema schema

    it "全LogValue型を含むイベントがSchemaへ適合する" $ do
      schema <- loadLogEventSchema
      toJSON fixedPayloadTypesEvent `shouldSatisfy` validateJSONSchema schema
