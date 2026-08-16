-- | 構造化ログの実行環境を初期化するAPI
module RAGScope.Logging.Setup (
  Logger,
  ExecutionId,
  LoggingConfig (LoggingConfig, minimumLevel),
  LogLevel (..),
  newExecutionId,
  newExecutionLogger,
  newServiceLogger,
) where

import Data.Time (getCurrentTime)
import Data.UUID.V4 qualified as UUIDv4
import RAGScope.Logging.Backend.JsonStderr (
  aesonStderrSink,
 )
import RAGScope.Logging.Core (
  Component (RAGScopeApp),
  EventContext (..),
  EventId (..),
  ExecutionId (..),
  LogLevel (..),
  Timestamp (..),
 )
import RAGScope.Logging.Runtime (
  Logger,
  mkLogger,
 )

-- | Loggerの出力設定。
newtype LoggingConfig = LoggingConfig
  { minimumLevel :: LogLevel
  }
  deriving (Eq, Show)

-- | 1回のCLI実行で共有するExecutionIdを生成する。
newExecutionId :: IO ExecutionId
newExecutionId =
  ExecutionId <$> UUIDv4.nextRandom

-- | execution scopeのLoggerを構築する。
newExecutionLogger ::
  LoggingConfig ->
  ExecutionId ->
  IO Logger
newExecutionLogger config executionId =
  pure $
    mkLogger
      config.minimumLevel
      RAGScopeApp
      (ExecutionContext executionId)
      newEventId
      currentTimestamp
      aesonStderrSink

-- | service scopeのLoggerを構築する。
newServiceLogger ::
  LoggingConfig ->
  IO Logger
newServiceLogger config =
  pure $
    mkLogger
      config.minimumLevel
      RAGScopeApp
      ServiceContext
      newEventId
      currentTimestamp
      aesonStderrSink

newEventId :: IO EventId
newEventId =
  EventId <$> UUIDv4.nextRandom

currentTimestamp :: IO Timestamp
currentTimestamp =
  Timestamp <$> getCurrentTime
