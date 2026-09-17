-- | Lifecycle result collection and exception selection.
--
-- Provider acquisition and release are handled by Construction using bracket.
-- Cleanup operations and their outcomes are defined in Cleanup.
module RAGScope.Telemetry.OpenTelemetry.Lifecycle (
  LifecycleReport (..),
  runLifecycle,
) where

import Control.Exception (
  ExceptionWithContext (ExceptionWithContext),
  SomeAsyncException,
  SomeException,
  fromException,
  mask,
  rethrowIO,
  tryWithContext,
 )
import Data.IORef (
  modifyIORef',
  newIORef,
  readIORef,
 )
import RAGScope.Telemetry.OpenTelemetry.Cleanup (
  CleanupOutcome (..),
 )

-- | An exception together with its original exception context.
type CapturedException = ExceptionWithContext SomeException

-- | Diagnostics from one complete SDK lifecycle invocation.
data LifecycleReport = LifecycleReport
  { lifecycleOriginalException :: Maybe CapturedException
  , lifecycleCleanupOutcomes :: [CleanupOutcome]
  }

-- | Run one lifecycle, publish its cleanup report, and select its final result.
--
-- The supplied action owns acquisition, usage, and release through bracket.
-- Its release actions must capture and record cleanup failures instead of
-- allowing them to replace the original application exception.
--
-- The recording callback is internal to this invocation. It must not escape
-- to the user callback or to background worker threads.
runLifecycle ::
  ((CleanupOutcome -> IO ()) -> IO a) ->
  (LifecycleReport -> IO ()) ->
  IO a
runLifecycle acquireAndUse publish =
  mask $ \restore -> do
    outcomesRef <- newIORef []

    let record outcome =
          modifyIORef' outcomesRef (outcome :)

    original <-
      tryWithContext @SomeException $
        restore (acquireAndUse record)

    outcomes <- reverse <$> readIORef outcomesRef

    let report =
          LifecycleReport
            { lifecycleOriginalException =
                either Just (const Nothing) original
            , lifecycleCleanupOutcomes = outcomes
            }

    reporting <-
      tryWithContext @SomeException $
        publish report

    either rethrowIO pure $
      chooseExit original outcomes reporting

-- | Select the final result after cleanup and reporting have been attempted.
--
-- An original asynchronous interruption has the highest priority.
-- A later lifecycle-thread interruption takes precedence over an original
-- synchronous exception, which remains available in LifecycleReport.
-- Synchronous cleanup and reporting failures never replace the original
-- application result or exception.
chooseExit ::
  Either CapturedException a ->
  [CleanupOutcome] ->
  Either CapturedException () ->
  Either CapturedException a
chooseExit original outcomes reporting =
  case original of
    Left originalException
      | isAsyncException originalException ->
          Left originalException
    _ ->
      case firstAsyncException outcomes of
        Just interruption ->
          Left interruption
        Nothing ->
          case reporting of
            Left reportingException
              | isAsyncException reportingException ->
                  Left reportingException
            _ ->
              original

-- | Identify an asynchronous exception without discarding its context.
isAsyncException ::
  CapturedException ->
  Bool
isAsyncException (ExceptionWithContext _ exception) =
  case fromException exception :: Maybe SomeAsyncException of
    Just _ ->
      True
    Nothing ->
      False

-- | Find the first asynchronous interruption caught during cleanup.
--
-- CleanupOutcome must describe an operation executed by the lifecycle
-- thread. A Reader worker's termination result must be recorded separately,
-- not converted into a lifecycle-thread interruption.
firstAsyncException ::
  [CleanupOutcome] ->
  Maybe CapturedException
firstAsyncException [] =
  Nothing
firstAsyncException (outcome : remaining) =
  case cleanupOutcomeResult outcome of
    Left exception
      | isAsyncException exception ->
          Just exception
    _ ->
      firstAsyncException remaining
