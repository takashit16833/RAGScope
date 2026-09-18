{-# LANGUAGE GADTs #-}

-- | SDKリソースの取得手順と解放方法を定義する。
--
-- リソースの取得・解放は行わず、実際の実行はRunnerに任せる。
module RAGScope.Telemetry.OpenTelemetry.ResourcePlan (
  ResourceCleanup (..),
  InitialAcquisition (..),
  Transfer (..),
  TransferChain (..),
  Build (..),
  ResourcePlan (..),
) where

import RAGScope.Telemetry.OpenTelemetry.Cleanup (
  CleanupPlan,
 )

-- | リソースの解放方法を保持する。
--
-- rollbackPlanは構築途中の失敗時、
-- closePlanは構築完了後のリソース解放に使用する。
data ResourceCleanup resource = OwnerPlans
  { rollbackPlan :: CleanupPlan resource
  , closePlan :: CleanupPlan resource
  }

-- | 最初のリソースを取得する処理と、その解放方法を保持する。
--
-- 例えばTraceではExporterの取得処理を登録する。
data InitialAcquisition resource
  = Seed
      (IO resource)
      (ResourceCleanup resource)

-- | 現在のリソースを使って次のリソースを取得する処理と、
-- 取得後のリソースの解放方法を保持する。
--
-- 取得に成功したら、Runnerは所有者を新しいリソースへ切り替える。
-- 新しいリソースが以前のリソースの解放責任も引き受けることは、
-- 登録するfactoryが満たす必要のある契約である。
data Transfer before after
  = Transfer
      (before -> IO after)
      (ResourceCleanup after)

-- | 前の取得結果を次の取得処理へ渡しながら、
-- 順番にリソースを構築するための手順を保持する。
--
-- 各Transferの出力型と次のTransferの入力型が一致する必要がある。
data TransferChain before after where
  Done :: TransferChain resource resource
  (:>>) ::
    Transfer before next ->
    TransferChain next after ->
    TransferChain before after

infixr 5 :>>

-- | 最初のリソース取得から、最終的なリソースの完成までの手順を保持する。
--
-- Seedで取得を開始し、Chainに従って次のリソースを構築する。
data Build result where
  Build ::
    InitialAcquisition first ->
    TransferChain first result ->
    Build result

-- | 複数のBuildと値を組み合わせ、最終的な結果を作る手順を表す。
--
-- Runnerはリソースを取得順に構築し、解放時は逆順に処理する。
data ResourcePlan result where
  PurePlan :: result -> ResourcePlan result
  ApplyPlan :: ResourcePlan (a -> result) -> ResourcePlan a -> ResourcePlan result
  Resource :: Build result -> ResourcePlan result

instance Functor ResourcePlan where
  fmap :: (a -> b) -> ResourcePlan a -> ResourcePlan b
  fmap f = ApplyPlan (PurePlan f)

instance Applicative ResourcePlan where
  pure :: a -> ResourcePlan a
  pure =
    PurePlan

  (<*>) :: ResourcePlan (a -> b) -> ResourcePlan a -> ResourcePlan b
  (<*>) =
    ApplyPlan
