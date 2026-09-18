{-# LANGUAGE GADTs #-}

-- | リソース取得とコールバック実行の結果をCleanup履歴とともに保持し、
-- 最後に返す値または再送出する例外を決める。
--
-- リソースの取得・解放、コールバックの実行、例外の再送出はRunnerが行う。
module RAGScope.Telemetry.OpenTelemetry.LifecycleResult (
  CapturedException,
  RunResult (..),
  LifecycleReport,
  lifecycleAcquisitionOrCallbackException,
  lifecycleCleanupOutcomes,
  toLifecycleReport,
  chooseExit,
) where

import Control.Exception (
  ExceptionWithContext (ExceptionWithContext),
  SomeAsyncException,
  SomeException,
  fromException,
 )

import RAGScope.Telemetry.OpenTelemetry.Cleanup (
  CleanupOutcome (..),
 )

-- | Cleanupとライフサイクル結果の通知コールバックが終わるまで、
-- 例外を保持するために使用する。
--
-- 捕捉時の例外コンテキストを失わずに再送出できるようにする。
type CapturedException =
  ExceptionWithContext SomeException

-- | リソース取得とコールバック実行の結果を、Cleanup履歴とは分けて保持する。
--
-- 取得に失敗した場合、コールバックは実行されない。
-- Cleanupで失敗しても、取得時の例外やコールバックの戻り値・例外を失わない。
data RunResult result = RunResult
  { acquisitionAndCallbackResult :: Either CapturedException result
  , cleanupOutcomes :: [CleanupOutcome]
  }

-- | リソース取得・コールバック実行時の例外とCleanup履歴を、
-- ライフサイクル結果の通知コールバックへ渡すための情報。
--
-- コールバックの正常な戻り値や、通知コールバック自身の実行結果は含めない。
data LifecycleReport = LifecycleReport
  { lifecycleAcquisitionOrCallbackException :: Maybe CapturedException
  , lifecycleCleanupOutcomes :: [CleanupOutcome]
  }

-- | リソース取得またはコールバック実行で捕捉した例外を通知用の値に含める。
--
-- 例外がなければNothingとし、Cleanup履歴は加工せずに引き継ぐ。
toLifecycleReport ::
  RunResult result ->
  LifecycleReport
toLifecycleReport runResult =
  LifecycleReport
    { lifecycleAcquisitionOrCallbackException =
        either
          Just
          (const Nothing)
          (acquisitionAndCallbackResult runResult)
    , lifecycleCleanupOutcomes =
        cleanupOutcomes runResult
    }

-- | Cleanupと通知コールバックの実行が終わった後、
-- 最後に返す値または例外を選ぶ。
--
-- リソース取得・コールバック実行時の非同期例外、
-- Cleanup中の最初の非同期例外、
-- ライフサイクル結果の通知コールバック実行中の非同期例外の順に優先する。
-- これらがなければ、リソース取得またはコールバック実行の結果を返す。
-- Cleanupや通知コールバックの同期例外、SDKの失敗値はその結果を置き換えない。
chooseExit ::
  RunResult result ->
  Either CapturedException () ->
  Either CapturedException result
chooseExit runResult reporting =
  case acquisitionAndCallbackResult runResult of
    Left exception
      | isAsyncException exception ->
          Left exception
    result ->
      case firstCleanupAsyncException (cleanupOutcomes runResult) of
        Just interruption ->
          Left interruption
        Nothing ->
          case reporting of
            Left reportingException
              | isAsyncException reportingException ->
                  Left reportingException
            _ ->
              result

-- | 最後に返す例外の優先順位を決めるため、非同期例外かどうかを判定する。
--
-- 例外の型を調べるだけで、発生元のスレッドは識別しない。
isAsyncException ::
  CapturedException ->
  Bool
isAsyncException (ExceptionWithContext _ exception) =
  case fromException exception :: Maybe SomeAsyncException of
    Just _ ->
      True
    Nothing ->
      False

-- | Cleanup履歴から、実行順で最初に捕捉した非同期例外を取り出す。
--
-- 履歴の順序が優先順位になるため、Runnerは結果を実行順に渡す。
firstCleanupAsyncException ::
  [CleanupOutcome] ->
  Maybe CapturedException
firstCleanupAsyncException [] =
  Nothing
firstCleanupAsyncException
  (SomeCleanupOutcome _ _ result : remaining) =
    case result of
      Left exception
        | isAsyncException exception ->
            Just exception
      _ ->
        firstCleanupAsyncException remaining
