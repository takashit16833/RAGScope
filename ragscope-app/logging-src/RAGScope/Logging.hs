-- | 型付きログイベントを記録する通常利用Facade
-- ログ基盤自身の失敗は 'LoggingFailure' として返す
module RAGScope.Logging (
  Logger,
  LoggingFailure (..),
  emit,
) where

import RAGScope.Logging.Runtime (Logger, LoggingFailure (..), emit)
