-- interpretOutcomeがExecutionOutcomeを成功値またはExecutionFailureへ解釈する規則を検証する
module RAGScope.Execution.ResultSpec (
  spec,
) where

import Control.Exception (Exception (fromException))
import Data.Map.Strict qualified as Map
import Test.Hspec (Expectation, Spec, describe, expectationFailure, it, shouldBe)
import Test.Hspec qualified as Hspec

import RAGScope.Error.Types (
  AppError (..),
  ErrorCategory (Input),
  ErrorCode (ErrorCode),
  ErrorContext (ErrorContext),
  ErrorMessage (ErrorMessage),
  ErrorValue (ErrorText),
  FieldName (FieldName),
 )
import RAGScope.Execution.Result (
  ExecutionFailure (..),
  ExecutionOutcome (..),
  interpretOutcome,
 )
import RAGScope.Execution.Testing (TestCause (TestCause), fixedAppError)
import RAGScope.Logging (LoggingFailure (LoggingSinkFailure))

-- fixedAppErrorに設定したAppErrorの各情報が保持されていることを検査する
shouldMatchFixedAppError :: AppError -> Expectation
shouldMatchFixedAppError
  AppError
    { category = actualCategory
    , code = ErrorCode actualCode
    , message = ErrorMessage actualMessage
    , context = actualContext
    , cause = actualCause
    } = do
    actualCategory `shouldBe` Input
    actualCode `shouldBe` "error"
    actualMessage `shouldBe` "error"
    actualContext
      `shouldBe` Just
        ( ErrorContext
            (Map.fromList [(FieldName "hoge", ErrorText "fuga")])
        )

    case actualCause of
      Nothing ->
        expectationFailure "expected cause"
      Just someException ->
        case fromException someException :: Maybe TestCause of
          Just TestCause ->
            pure ()
          Nothing ->
            expectationFailure "expected TestCause"

spec :: Spec
spec = do
  describe "interpretOutcome" $ do
    Hspec.context "機能処理が成功する場合" $ do
      it "ログ記録も成功したら機能処理の値を返す" $ do
        let outcome =
              ExecutionOutcome
                { featureResult = Right ("success" :: String)
                , loggingResult = Right ()
                }

        case interpretOutcome outcome of
          Right value ->
            value `shouldBe` "success"
          Left _ ->
            expectationFailure "expected success"

      it "ログ記録が失敗したらLoggingFailedAfterSuccessを返す" $ do
        let outcome =
              ExecutionOutcome
                { featureResult = Right ("success" :: String)
                , loggingResult = Left LoggingSinkFailure
                }

        case interpretOutcome outcome of
          Right _ ->
            expectationFailure "expected LoggingFailedAfterSuccess"
          Left (FeatureFailed _) ->
            expectationFailure "expected LoggingFailedAfterSuccess"
          Left (LoggingFailedAfterSuccess LoggingSinkFailure) ->
            pure ()
          Left (FeatureFailedWithLoggingFailure _ _) ->
            expectationFailure "expected LoggingFailedAfterSuccess"

    Hspec.context "機能処理が失敗する場合" $ do
      it "ログ記録が成功したらAppErrorを保持したFeatureFailedを返す" $ do
        let outcome =
              ExecutionOutcome
                { featureResult = Left fixedAppError
                , loggingResult = Right ()
                }

        case interpretOutcome outcome of
          Right _ ->
            expectationFailure "expected FeatureFailed"
          Left (FeatureFailed appError) ->
            shouldMatchFixedAppError appError
          Left (LoggingFailedAfterSuccess _) ->
            expectationFailure "expected FeatureFailed"
          Left (FeatureFailedWithLoggingFailure _ _) ->
            expectationFailure "expected FeatureFailed"

      it "ログ記録も失敗したらAppErrorとLoggingFailureを保持したFeatureFailedWithLoggingFailureを返す" $ do
        let outcome =
              ExecutionOutcome
                { featureResult = Left fixedAppError
                , loggingResult = Left LoggingSinkFailure
                }

        case interpretOutcome outcome of
          Right _ ->
            expectationFailure "expected FeatureFailedWithLoggingFailure"
          Left (FeatureFailed _) ->
            expectationFailure "expected FeatureFailedWithLoggingFailure"
          Left (LoggingFailedAfterSuccess _) ->
            expectationFailure "expected FeatureFailedWithLoggingFailure"
          Left (FeatureFailedWithLoggingFailure appError LoggingSinkFailure) ->
            shouldMatchFixedAppError appError
