-- | 型付きログイベントを記録する通常利用API
module RAGScope.Logging (
  Logger,
  LoggingFailure (..),
  emit,
) where

import RAGScope.Logging.Runtime (Logger, LoggingFailure (..), emit)
