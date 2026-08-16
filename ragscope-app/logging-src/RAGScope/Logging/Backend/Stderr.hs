module RAGScope.Logging.Backend.Stderr (writeLine) where

import Control.Exception (IOException, try)
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import System.IO (hFlush, stderr)

import RAGScope.Logging.Runtime (LoggingFailure (LoggingSinkFailure))

-- | 標準エラーへ1行で出力する。
--
-- IO例外はLoggingFailureへ変換する。
writeLine :: LazyByteString.ByteString -> IO (Either LoggingFailure ())
writeLine encoded = do
  result <- tryWrite encoded

  pure $
    case result of
      Left _ ->
        Left LoggingSinkFailure
      Right () -> Right ()

-- | バイト列を標準エラーへ1行で書き込み、発生したIO例外を値として返す。
tryWrite :: LazyByteString.ByteString -> IO (Either IOException ())
tryWrite encoded = do
  try $ do
    LazyByteString.hPutStrLn stderr encoded
    hFlush stderr
