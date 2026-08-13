-- 構造化ログのAeson変換を検査する
module RAGScope.Logging.Backend.AesonSpec (
  spec,
) where

import Data.Aeson (ToJSON (toJSON), Value (Number, String), encode)
import RAGScope.Logging.Testing (
  LogLevel (Debug, Error, Info, Warn),
  SchemaVersion (SchemaV1),
  fixedErrorCode,
  fixedEventId,
  fixedEventName,
  fixedExecutionId,
  fixedOperationName,
  fixedSafeMessage,
 )
import Test.Hspec (
  Spec,
  context,
  describe,
  it,
  shouldBe,
 )

spec :: Spec
spec = do
  describe "SchemaVersion" $ do
    context "SchemaVersionからJSONへの変換テスト" $ do
      it "SchemaV1をJSON number 1へ変換する" $ do
        toJSON SchemaV1 `shouldBe` Number 1

      it "SchemaV1をJSON number 1としてencodeする" $ do
        encode SchemaV1 `shouldBe` "1"

  describe "LogLevel" $ do
    context "LogLevelからJSONへの変換テスト" $ do
      it "DebugをJSON文字列へ変換する" $ do
        toJSON Debug `shouldBe` String "debug"

      it "DebugをJSON文字列としてencodeする" $ do
        encode Debug `shouldBe` "\"debug\""

      it "InfoをJSON文字列へ変換する" $ do
        toJSON Info `shouldBe` String "info"

      it "InfoをJSON文字列としてencodeする" $ do
        encode Info `shouldBe` "\"info\""

      it "WarnをJSON文字列へ変換する" $ do
        toJSON Warn `shouldBe` String "warn"

      it "WarnをJSON文字列としてencodeする" $ do
        encode Warn `shouldBe` "\"warn\""

      it "ErrorをJSON文字列へ変換する" $ do
        toJSON Error `shouldBe` String "error"

      it "ErrorをJSON文字列としてencodeする" $ do
        encode Error `shouldBe` "\"error\""

  describe "EventId" $ do
    context "EventIdからJSONへの変換テスト" $ do
      it "EventIdをJSON文字列へ変換する" $ do
        toJSON fixedEventId `shouldBe` String "9abcdef0-1234-5678-9abc-def012345678"

      it "EventIdをJSON文字列としてencodeする" $ do
        encode fixedEventId `shouldBe` "\"9abcdef0-1234-5678-9abc-def012345678\""

  describe "ExecutionId" $ do
    context "ExecutionIdからJSONへの変換テスト" $ do
      it "ExecutionIdをJSON文字列へ変換する" $ do
        toJSON fixedExecutionId `shouldBe` String "12345678-9abc-def0-1234-56789abcdef0"

      it "ExecutionIdをJSON文字列としてencodeする" $ do
        encode fixedExecutionId `shouldBe` "\"12345678-9abc-def0-1234-56789abcdef0\""

  describe "OperationName" $ do
    context "OperationNameからJSONへの変換テスト" $ do
      it "OperationNameをJSON文字列へ変換する" $ do
        toJSON fixedOperationName `shouldBe` String "test.operation"

      it "OperationNameをJSON文字列としてencodeする" $ do
        encode fixedOperationName `shouldBe` "\"test.operation\""

  describe "EventName" $ do
    context "EventNameからJSONへの変換テスト" $ do
      it "EventNameをJSON文字列へ変換する" $ do
        toJSON fixedEventName `shouldBe` String "test"

      it "EventNameをJSON文字列としてencodeする" $ do
        encode fixedEventName `shouldBe` "\"test\""

  describe "ErrorCode" $ do
    context "ErrorCodeからJSONへの変換テスト" $ do
      it "ErrorCodeをJSON文字列へ変換する" $ do
        toJSON fixedErrorCode `shouldBe` String "test.error"

      it "ErrorCodeをJSON文字列としてencodeする" $ do
        encode fixedErrorCode `shouldBe` "\"test.error\""

  describe "SafeMessage" $ do
    context "SafeMessageからJSONへの変換テスト" $ do
      it "SafeMessageをJSON文字列へ変換する" $ do
        toJSON fixedSafeMessage `shouldBe` String "safe message"

      it "SafeMessageをJSON文字列としてencodeする" $ do
        encode fixedSafeMessage `shouldBe` "\"safe message\""
