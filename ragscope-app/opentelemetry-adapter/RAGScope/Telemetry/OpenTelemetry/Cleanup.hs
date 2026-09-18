{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeApplications #-}

-- | OpenTelemetry SDKの終了処理を実行し、各操作の結果を記録する。
module RAGScope.Telemetry.OpenTelemetry.Cleanup () where

import Control.Exception (
  ExceptionWithContext,
  SomeException,
  evaluate,
  mask_,
  tryWithContext,
 )
import OpenTelemetry.Internal.Common.Types (
  ExportResult,
  FlushResult,
  ShutdownResult,
 )

-- | 終了処理を識別する名前。
newtype StepId = StepId String

-- | SDK操作の種類と戻り値の型を対応付ける。
data CleanupOp result where
  FlushOp :: CleanupOp FlushResult
  ShutdownOp :: CleanupOp ShutdownResult
  ExportOp :: CleanupOp ExportResult

-- | リソースを受け取って実行するSDK操作。
--
-- 関数として保持することで、リソース取得前に終了処理を定義できる。
data CleanupAction resource where
  CleanupAction ::
    StepId ->
    CleanupOp result ->
    (resource -> IO result) ->
    CleanupAction resource

-- | 同じリソースに対する終了処理を実行順にまとめたもの。
newtype CleanupPlan resource
  = CleanupPlan [CleanupAction resource]

-- | 実行した操作とその結果を保持する。
--
-- SDKが返した失敗値はRightに保持し、例外による失敗と区別する。
data SomeCleanupOutcome where
  SomeCleanupOutcome ::
    StepId ->
    CleanupOp result ->
    Either
      (ExceptionWithContext SomeException)
      result ->
    SomeCleanupOutcome

cleanupPlan ::
  [CleanupAction resource] ->
  CleanupPlan resource
cleanupPlan =
  CleanupPlan

-- | 各操作を順番に実行し、結果を実行順に返す。
--
-- flushで例外が発生してもshutdownを試せるよう、
-- 操作ごとに例外を捕捉してから次の操作へ進む。
runCleanupPlan ::
  resource ->
  CleanupPlan resource ->
  IO [SomeCleanupOutcome]
runCleanupPlan resource (CleanupPlan actions) =
  mask_ $
    traverse (captureAction resource) actions

-- | SDK操作の実行と戻り値の評価をまとめて捕捉する。
--
-- 戻り値をWHNFまで評価し、遅延していた例外が
-- 正常な返却値として記録されることを防ぐ。
captureAction ::
  resource ->
  CleanupAction resource ->
  IO SomeCleanupOutcome
captureAction
  resource
  (CleanupAction stepId operation action) = do
    captured <-
      tryWithContext @SomeException $ do
        sdkResult <- action resource
        evaluate sdkResult

    pure $
      SomeCleanupOutcome
        stepId
        operation
        captured
