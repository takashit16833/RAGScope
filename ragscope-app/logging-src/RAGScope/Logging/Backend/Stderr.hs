module RAGScope.Logging.Backend.Stderr (writeLine) where

import Control.Exception (IOException, try)
import Data.Bifunctor (Bifunctor (first))
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import System.IO (hFlush, stderr)

import RAGScope.Logging.Runtime (LoggingFailure (LoggingSinkFailure))

-- | 標準エラーへ1行で出力する。
--
-- 書き込みまたはflushで発生したIO例外はLoggingSinkFailureへ変換する。
writeLine :: LazyByteString.ByteString -> IO (Either LoggingFailure ())
writeLine encoded = first (const LoggingSinkFailure) <$> tryWrite encoded

-- 書き込みとflushを1回のIO処理として試行し、IOExceptionを値として返す。
tryWrite :: LazyByteString.ByteString -> IO (Either IOException ())
tryWrite encoded = do
  try $ do
    LazyByteString.hPutStrLn stderr encoded
    hFlush stderr
