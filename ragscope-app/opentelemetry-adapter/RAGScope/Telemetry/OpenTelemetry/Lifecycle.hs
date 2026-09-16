-- | Resource cleanup support for the OpenTelemetry Adapter.
--
-- Each cleanup step is attempted independently. The caller is responsible
-- for inspecting the outcomes and propagating any deferred interruption.
module RAGScope.Telemetry.OpenTelemetry.Lifecycle where

import Control.Exception (
  ExceptionWithContext,
  SomeException,
  mask,
  tryWithContext,
 )
import OpenTelemetry.Internal.Common.Types (
  ExportResult,
  FlushResult,
  ShutdownResult,
 )

-- | Preserve the SDK result without converting a failure into success.
data CleanupResult
  = CleanupCompleted
  | CleanupFlushResult FlushResult
  | CleanupShutdownResult ShutdownResult
  | CleanupExportResult ExportResult

-- | A named cleanup operation.
data CleanupStep = CleanupStep
  { cleanupStepName :: String
  , cleanupSpetAction :: IO CleanupResult
  }

-- | Both the Operation name and its complete outcome are retained.
data CleanupOutcome = CleanupOutcome
  { cleanupOutcomeName :: String
  , cleanupOutcomeResult ::
      Either
        (ExceptionWithContext SomeException)
        CleanupResult
  }

-- | Attempt every cleanup step, retaining failures and interruptions.
--
-- This function does not decive which emception to rethrow. The outer
-- lifecycle must inspect the returned outcomes before returning to its caller.
runCleanupSteps :: [CleanupStep] -> IO [CleanupOutcome]
runCleanupSteps steps =
  mask $ \_ ->
    traverse runStep steps
 where
  runStep step = do
    result <-
      tryWithContext @SomeException $
        cleanupSpetAction step

    pure
      CleanupOutcome
        { cleanupOutcomeName = cleanupStepName step
        , cleanupOutcomeResult = result
        }
