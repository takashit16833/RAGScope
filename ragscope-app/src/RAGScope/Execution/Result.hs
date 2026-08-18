-- | 機能処理と必須ログ記録の結果を、アプリケーション実行結果へ解釈する型と純粋関数を定義する。
--
-- 機能処理とログ記録は独立した事実として @ExecutionOutcome@ に保持し、
-- 'interpretOutcome' が成功値または 'ExecutionFailure' へ解釈する。
-- IOの実行順序やログ記録の試行は、このモジュールでは扱わない。
module RAGScope.Execution.Result (
  interpretOutcome,
  AppAction,
  ExecutionOutcome (..),
  ExecutionFailure (..),
) where

import Control.Monad.Trans.Except (ExceptT)

import RAGScope.Error.Types (AppError)
import RAGScope.Logging (LoggingFailure)

-- | 機能処理と必須ログ記録を含むアプリケーション実行。
--
-- 失敗時は 'ExecutionFailure' で短絡し、成功時は機能処理の値を返す。
type AppAction a =
  ExceptT ExecutionFailure IO a

-- | 機能処理結果と必須ログ記録結果を独立に保持する。
data ExecutionOutcome a
  = -- | 1回の機能処理と、その結果に対応するログ記録の結果。
    ExecutionOutcome
    { featureResult :: Either AppError a
    -- ^ 機能処理が返した結果。
    , loggingResult :: Either LoggingFailure ()
    -- ^ 機能処理結果を記録した必須ログ処理の結果。
    }

-- | 機能処理と必須ログ記録を合成したアプリケーション実行の失敗。
data ExecutionFailure
  = -- | 機能処理だけが失敗し、必須ログ記録は成功した。
    FeatureFailed AppError
  | -- | 機能処理は成功したが、必須ログ記録が失敗した。
    LoggingFailedAfterSuccess LoggingFailure
  | -- | 機能処理と必須ログ記録の両方が失敗した。
    FeatureFailedWithLoggingFailure AppError LoggingFailure

-- | @ExecutionOutcome@ を成功値または 'ExecutionFailure' へ解釈する。
--
-- 機能処理が成功していても必須ログ記録が失敗した場合は失敗とする。
-- 両方が失敗した場合は、両方の失敗値を 'FeatureFailedWithLoggingFailure' に保持する。
interpretOutcome ::
  ExecutionOutcome a ->
  Either ExecutionFailure a
interpretOutcome
  (ExecutionOutcome (Right value) (Right ())) =
    Right value
interpretOutcome
  (ExecutionOutcome (Right _) (Left loggingFailure)) =
    Left $ LoggingFailedAfterSuccess loggingFailure
interpretOutcome
  (ExecutionOutcome (Left appError) (Right ())) =
    Left $ FeatureFailed appError
interpretOutcome
  (ExecutionOutcome (Left appError) (Left loggingFailure)) =
    Left $ FeatureFailedWithLoggingFailure appError loggingFailure
