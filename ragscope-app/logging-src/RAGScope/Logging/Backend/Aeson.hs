{-# OPTIONS_GHC -Wno-orphans #-}

-- | LogEventを契約どおりのJSONへ変換する。
--
-- CoreをAeson非依存に保ち、JSON instanceをこのモジュールへ集中させるため
-- 意図的にorphan instanceとする
module RAGScope.Logging.Backend.Aeson () where

import Data.Aeson (
  Encoding,
  Options (constructorTagModifier),
  ToJSON (toEncoding),
  Value (..),
  defaultOptions,
  genericToEncoding,
  genericToJSON,
  toJSON,
 )
import Data.Char (toLower)
import RAGScope.Logging.Core (
  ErrorCode (..),
  EventId (..),
  EventName (..),
  ExecutionId (..),
  LogLevel,
  OperationName (..),
  SafeMessage (..),
  SchemaVersion (SchemaV1),
 )

-- | SchemaVersionからJSONへの変換を定義する。
instance ToJSON SchemaVersion where
  toJSON :: SchemaVersion -> Value
  toJSON SchemaV1 = toJSON (1 :: Int)

  toEncoding :: SchemaVersion -> Encoding
  toEncoding SchemaV1 = toEncoding (1 :: Int)

-- | LogLevelからJSONへの変換を定義する。
logLevelOptions :: Options
logLevelOptions =
  defaultOptions
    { constructorTagModifier = map toLower
    }

instance ToJSON LogLevel where
  toJSON :: LogLevel -> Value
  toJSON = genericToJSON logLevelOptions

  toEncoding :: LogLevel -> Encoding
  toEncoding = genericToEncoding logLevelOptions

-- | EventIdからJSONへの変換を定義する。
instance ToJSON EventId where
  toJSON :: EventId -> Value
  toJSON (EventId uuid) = toJSON uuid

  toEncoding :: EventId -> Encoding
  toEncoding (EventId uuid) = toEncoding uuid

-- | ExecutionIdからJSONへの変換を定義する。
instance ToJSON ExecutionId where
  toJSON :: ExecutionId -> Value
  toJSON (ExecutionId uuid) = toJSON uuid

  toEncoding :: ExecutionId -> Encoding
  toEncoding (ExecutionId uuid) = toEncoding uuid

-- | OperationNameからJSONへの変換を定義する。
instance ToJSON OperationName where
  toJSON :: OperationName -> Value
  toJSON (OperationName operationName) = toJSON operationName

  toEncoding :: OperationName -> Encoding
  toEncoding (OperationName operationName) = toEncoding operationName

-- | EventNameからJSONへの変換を定義する。
instance ToJSON EventName where
  toJSON :: EventName -> Value
  toJSON (EventName eventName) = toJSON eventName

  toEncoding :: EventName -> Encoding
  toEncoding (EventName eventName) = toEncoding eventName

-- | ErrorCodeからJSONへの変換を定義する。
instance ToJSON ErrorCode where
  toJSON :: ErrorCode -> Value
  toJSON (ErrorCode errorCode) = toJSON errorCode

  toEncoding :: ErrorCode -> Encoding
  toEncoding (ErrorCode errorCode) = toEncoding errorCode

-- | SafeMessageからJSONへの変換を定義する。
instance ToJSON SafeMessage where
  toJSON :: SafeMessage -> Value
  toJSON (SafeMessage safeMessage) = toJSON safeMessage

  toEncoding :: SafeMessage -> Encoding
  toEncoding (SafeMessage safeMessage) = toEncoding safeMessage
