-- | 機能固有の閉じたログイベントを、共通EventSpecへ変換するためのAPI
--
-- 通常の機能処理ではなく、RAGScope.*.Loggingモジュールから利用する
module RAGScope.Logging.EventSpec (
  ErrorCode (..),
  EventName (..),
  EventSpec,
  FieldName (..),
  LogError,
  LogErrorCategory (..),
  LogValue (..),
  OperationName (..),
  Payload,
  SafeMessage (..),
  ToEventSpec (..),
  debugEventSpec,
  emptyPayload,
  failedEventSpec,
  infoEventSpec,
  logError,
  payloadFromList,
  warnEventSpec,
) where

import RAGScope.Logging.Core (
  ErrorCode (..),
  EventName (..),
  EventSpec,
  FieldName (..),
  LogError,
  LogErrorCategory (..),
  LogValue (..),
  OperationName (..),
  Payload,
  SafeMessage (..),
  ToEventSpec (..),
  debugEventSpec,
  emptyPayload,
  failedEventSpec,
  infoEventSpec,
  logError,
  payloadFromList,
  warnEventSpec,
 )
