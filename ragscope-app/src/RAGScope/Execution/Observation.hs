-- | 機能処理と、その結果を必須ログとして記録する処理を順番に実行し、'AppAction' へ合成する。
--
-- 機能処理の成否にかかわらずログ記録を1回試行し、2つの結果の解釈は
-- @RAGScope.Execution.Result@ の規則へ委ねる。
module RAGScope.Execution.Observation (observe) where

import Control.Monad.IO.Class (MonadIO (liftIO))
import Control.Monad.Trans.Except (except)

import RAGScope.Error.Types (AppError)
import RAGScope.Execution.Result (AppAction, ExecutionOutcome (ExecutionOutcome), interpretOutcome)
import RAGScope.Logging (LoggingFailure)

-- | 機能処理を1回実行し、その結果を変更せず記録処理へ1回渡す。
--
-- 機能処理が失敗しても記録処理を実行する。
-- 記録処理が失敗した場合、この関数自身は同じログ経路への再出力を行わない。
-- 最終結果は @ExecutionOutcome@ を 'interpretOutcome' で解釈した 'AppAction' として返す。
observe ::
  IO (Either AppError a) ->
  (Either AppError a -> IO (Either LoggingFailure ())) ->
  AppAction a
observe featureAction recordResult = do
  featureResult <- liftIO featureAction
  loggingResult <- liftIO $ recordResult featureResult

  let outcome = ExecutionOutcome featureResult loggingResult

  except $ interpretOutcome outcome
