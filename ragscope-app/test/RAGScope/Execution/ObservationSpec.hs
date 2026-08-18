-- observeが機能処理とログ記録をAppActionへ合成する境界を検証する
module RAGScope.Execution.ObservationSpec (
  spec,
) where

import Control.Monad.IO.Class (MonadIO (liftIO))
import Control.Monad.Trans.Except (runExceptT)
import Data.IORef (modifyIORef', newIORef, readIORef, writeIORef)
import Test.Hspec (Spec, describe, expectationFailure, it, shouldBe)
import Test.Hspec qualified as Hspec

import RAGScope.Error.Types (AppError (..), ErrorMessage (ErrorMessage))
import RAGScope.Execution.Observation (observe)
import RAGScope.Execution.Result (ExecutionFailure (FeatureFailedWithLoggingFailure))
import RAGScope.Execution.Testing (fixedAppError)
import RAGScope.Logging (LoggingFailure (LoggingSinkFailure))

successfulFeatureAction :: IO (Either AppError String)
successfulFeatureAction = pure $ Right "success"

failingFeatureAction :: IO (Either AppError a)
failingFeatureAction = pure $ Left fixedAppError

type RecordResult a =
  Either AppError a -> IO (Either LoggingFailure ())

newCapturingRecordResult ::
  Either LoggingFailure () ->
  IO (RecordResult a, IO [Either AppError a])
newCapturingRecordResult loggingResult = do
  capturedResultsRef <- newIORef []

  let recordResult featureResult = do
        modifyIORef' capturedResultsRef (featureResult :)
        pure loggingResult

  pure (recordResult, reverse <$> readIORef capturedResultsRef)

spec :: Spec
spec = do
  describe "observe" $ do
    Hspec.context "機能処理が成功する場合" $ do
      it "成功結果をrecordResultへそのまま渡す" $ do
        (recordResult, readCapturedResults) <- newCapturingRecordResult (Right ())

        _ <- runExceptT $ observe successfulFeatureAction recordResult

        capturedResults <- readCapturedResults

        case capturedResults of
          [Right value] ->
            value `shouldBe` "success"
          _ ->
            expectationFailure "成功結果が1件だけ記録されることを期待しました"

    Hspec.context "機能処理が失敗する場合" $ do
      it "失敗結果をrecordResultへそのまま渡し、ログ記録を1回だけ試行する" $ do
        (recordResult, readCapturedResults) <- newCapturingRecordResult (Right ())

        _ <- runExceptT $ observe failingFeatureAction recordResult

        capturedResults <- readCapturedResults

        case capturedResults of
          [Left (AppError _ _ (ErrorMessage actualMessage) _ _)] ->
            actualMessage `shouldBe` "error"
          _ ->
            expectationFailure "失敗結果が1件だけ記録されることを期待しました"

    Hspec.context "ログ記録が失敗する場合" $ do
      it "AppActionを失敗させ、後続処理を実行しない" $ do
        (recordResult, _) <- newCapturingRecordResult (Left LoggingSinkFailure)

        continuationExecutedRef <- newIORef False

        let actionWithContinuation = do
              _ <- observe successfulFeatureAction recordResult
              liftIO $ writeIORef continuationExecutedRef True

        executionResult <- runExceptT actionWithContinuation

        continuationExecuted <- readIORef continuationExecutedRef

        case executionResult of
          Left _ -> pure ()
          _ -> expectationFailure "AppActionの失敗を期待しました"

        continuationExecuted `shouldBe` False

    Hspec.context "機能処理とログ記録が失敗する場合" $ do
      it "元のAppErrorをExecutionFailureに保持する" $ do
        (recordResult, _) <- newCapturingRecordResult (Left LoggingSinkFailure)

        executionResult <- runExceptT $ observe failingFeatureAction recordResult

        case executionResult of
          Left (FeatureFailedWithLoggingFailure (AppError _ _ (ErrorMessage actualMessage) _ _) _) ->
            actualMessage `shouldBe` "error"
          _ -> expectationFailure "AppErrorとLoggingFailureを保持した失敗を期待しました"
