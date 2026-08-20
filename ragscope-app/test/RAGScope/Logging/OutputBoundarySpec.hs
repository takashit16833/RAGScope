-- stdout/stderrの実出力境界を検証する
module RAGScope.Logging.OutputBoundarySpec (
  spec,
) where

import Control.Exception (bracket, finally)
import Data.Aeson (Value, eitherDecode)
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.Either (isRight)
import GHC.IO.Handle (SeekMode (AbsoluteSeek), hClose, hDuplicate, hDuplicateTo, hFlush, hGetContents', hSeek)
import System.IO (stderr, stdout)
import System.IO.Temp (withSystemTempFile)
import Test.Hspec (Spec, describe, it, shouldBe, shouldNotContain, shouldSatisfy)

import RAGScope.Logging (LoggingFailure (LoggingSinkFailure), emit)
import RAGScope.Logging.Setup (LoggingConfig (LoggingConfig), mkServiceLogger)
import RAGScope.Logging.Testing (
  Component (RAGScopeApp),
  EventContext (ExecutionContext),
  LogLevel (NormalLevel),
  NormalLogLevel (Debug),
  TestEvent (TestDebugEvent),
  fixedClock,
  fixedEventIdSource,
  fixedExecutionId,
  newCountingFailureLogger,
 )

-- action実行中だけstdout/stderrをテンポラリファイルへ差し替え、両方の出力を返す。
captureStdoutAndStderr :: IO a -> IO (a, String, String)
captureStdoutAndStderr action =
  withSystemTempFile "ragscope-stdout.tmp" $ \_ tempStdoutHandle ->
    withSystemTempFile "ragscope-stderr.tmp" $ \_ tempStderrHandle -> do
      bracket (hDuplicate stdout) hClose $ \originalStdout ->
        bracket (hDuplicate stderr) hClose $ \originalStderr -> do
          -- actionが例外終了しても、捕捉済み出力をflushして標準ハンドルを必ず復元する。
          result <-
            ( do
                hDuplicateTo tempStdoutHandle stdout
                hDuplicateTo tempStderrHandle stderr

                action
            )
              `finally` ( do
                            hFlush stdout
                            hFlush stderr
                        )
              `finally` ( do
                            hDuplicateTo originalStdout stdout
                            hDuplicateTo originalStderr stderr
                        )

          -- 書き込んだ先頭から捕捉結果を読み直す。
          hSeek tempStdoutHandle AbsoluteSeek 0
          hSeek tempStderrHandle AbsoluteSeek 0

          capturedStdout <- hGetContents' tempStdoutHandle
          capturedStderr <- hGetContents' tempStderrHandle

          pure (result, capturedStdout, capturedStderr)

isSingleJsonLine :: String -> Bool
isSingleJsonLine output =
  case lines output of
    [line] ->
      isRight (eitherDecode (LazyByteString.pack line) :: Either String Value)
    _ ->
      False

spec :: Spec
spec = do
  describe "output boundary" $ do
    it "正常結果をstdoutへ、構造化ログをstderrへ分離する" $ do
      let logger = mkServiceLogger (LoggingConfig (NormalLevel Debug))

      (result, capturedStdout, capturedStderr) <-
        captureStdoutAndStderr $ do
          putStrLn "normal-result"
          emit logger TestDebugEvent

      result `shouldBe` Right ()
      capturedStdout `shouldBe` "normal-result\n"
      capturedStderr `shouldSatisfy` isSingleJsonLine
      capturedStdout `shouldNotContain` "\"schema_version\""
      capturedStderr `shouldNotContain` "normal-result"

    it "Sink失敗時に同じログ経路へ再出力しない" $ do
      (logger, readSinkCallCount) <-
        newCountingFailureLogger
          (NormalLevel Debug)
          RAGScopeApp
          (ExecutionContext fixedExecutionId)
          fixedEventIdSource
          fixedClock

      result <- emit logger TestDebugEvent
      result `shouldBe` Left LoggingSinkFailure

      sinkCallCount <- readSinkCallCount
      sinkCallCount `shouldBe` 1
