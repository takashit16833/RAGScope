-- | 機能固有の型付きログイベントを記録するための通常利用Facade。
--
-- 機能処理は、このモジュールから 'Logger' と 'emit' を利用し、
-- イベントID・時刻・共通contextの付加、ログレベルによる出力判定、
-- 出力先への受け渡しといった内部処理には依存しない。
--
-- ログ基盤自身の失敗は 'LoggingFailure' として呼び出し元へ返す。
module RAGScope.Logging (
  Logger,
  LoggingFailure (..),
  emit,
) where

import RAGScope.Logging.Runtime (Logger, LoggingFailure (..), emit)
