-- | Cleanup results and execution for the OpenTelemetry Adapter.
--
-- This module captures SDK results and exceptions. It does not acquire
-- resources or decide which exception the lifecycle should propagate.
module RAGScope.Telemetry.OpenTelemetry.Cleanup where

import Control.Exception (
  ExceptionWithContext,
  SomeException,
  mask_,
  tryWithContext,
 )
import OpenTelemetry.Internal.Common.Types (
  ExportResult,
  FlushResult,
  ShutdownResult,
 )

-- | Preserve the SDK result without converting a failure into success.
data CleanupResult
  = CleanupFlushResult FlushResult
  | CleanupShutdownResult ShutdownResult
  | CleanupExportResult ExportResult

-- | A named cleanup operation.
data CleanupStep = CleanupStep
  { cleanupStepName :: String
  , cleanupStepAction :: IO CleanupResult
  }

-- | Both the operation name and its complete outcome are retained.
data CleanupOutcome = CleanupOutcome
  { cleanupOutcomeName :: String
  , cleanupOutcomeResult ::
      Either
        (ExceptionWithContext SomeException)
        CleanupResult
  }

-- | Execute one operation and preserve its SDK result or exception.
captureCleanup :: String -> IO CleanupResult -> IO CleanupOutcome
captureCleanup name action = do
  result <- tryWithContext @SomeException action

  pure
    CleanupOutcome
      { cleanupOutcomeName = name
      , cleanupOutcomeResult = result
      }

-- | Execute one cleanup operation, record its outcome, and return its result.
--
-- The recording callback must be an internal, non-blocking operation.
-- Exception selection belongs to the outer lifecycle.
attemptCleanup ::
  (CleanupOutcome -> IO ()) ->
  String ->
  IO CleanupResult ->
  IO
    ( Either
        (ExceptionWithContext SomeException)
        CleanupResult
    )
attemptCleanup record name action =
  mask_ $ do
    outcome <- captureCleanup name action
    record outcome
    pure (cleanupOutcomeResult outcome)

-- | Attempt every cleanup step in order and return all outcomes.
--
-- This retains the existing interface during the module extraction.
-- The outer lifecycle will use attemptCleanup for immediate recording
-- when its resource-management implementation is replaced.
runCleanupSteps :: [CleanupStep] -> IO [CleanupOutcome]
runCleanupSteps steps =
  mask_ $
    traverse runStep steps
 where
  runStep step =
    captureCleanup
      (cleanupStepName step)
      (cleanupStepAction step)
