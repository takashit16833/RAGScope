-- | production用の構造化ログ実行環境を組み立てるAPI
module RAGScope.Logging.Setup (
  Logger,
  ExecutionId,
  LoggingConfig (LoggingConfig, minimumLevel),
  LogLevel (..),
  newExecutionId,
  mkExecutionLogger,
  mkServiceLogger,
) where

import Data.Time (getCurrentTime)
import Data.UUID.V4 qualified as UUIDv4

import RAGScope.Logging.Backend.Json qualified as Json
import RAGScope.Logging.Backend.Stderr qualified as Stderr
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
  Sink,
  mkLogger,
 )

-- | LogEventをJSONへ変換し、標準エラーへ1行で出力するproduction用Sink。
stderrSink :: Sink
stderrSink logEvent =
  Stderr.writeLine (Json.encodeLogEvent logEvent)

-- | Loggerの出力設定。
newtype LoggingConfig = LoggingConfig
  { minimumLevel :: LogLevel
  }
  deriving (Eq, Show)

-- | 1回のCLI実行で共有するExecutionIdを生成する。
newExecutionId :: IO ExecutionId
newExecutionId =
  ExecutionId <$> UUIDv4.nextRandom

-- 設定とcontextからproduction用Loggerを純粋に組み立てる。
-- EventId生成と現在時刻取得は、emit時に実行されるIOアクションとして注入する。
mkConfiguredLogger ::
  LoggingConfig ->
  EventContext ->
  Logger
mkConfiguredLogger config context =
  mkLogger
    config.minimumLevel
    RAGScopeApp
    context
    newEventId
    currentTimestamp
    stderrSink

-- | execution scopeのLoggerを構築する。
mkExecutionLogger :: LoggingConfig -> ExecutionId -> Logger
mkExecutionLogger config executionId =
  mkConfiguredLogger config (ExecutionContext executionId)

-- | service scopeのLoggerを構築する。
mkServiceLogger :: LoggingConfig -> Logger
mkServiceLogger config =
  mkConfiguredLogger config ServiceContext

newEventId :: IO EventId
newEventId =
  EventId <$> UUIDv4.nextRandom

currentTimestamp :: IO Timestamp
currentTimestamp =
  Timestamp <$> getCurrentTime
