-- | Construct and release the three OpenTelemetry provider resources.
--
-- This module owns resource lifetime through bracket.
-- Lifecycle records outcomes and selects the final result or exception.
module RAGScope.Telemetry.OpenTelemetry.Construction (
  ProviderOperations (..),
  LifecycleReport (..),
  CleanupOutcome (..),
  CleanupResult (..),
  withProviders,
) where

import Control.Exception (bracket)
import Control.Monad (void)

import RAGScope.Telemetry.OpenTelemetry.Cleanup (
  CleanupOutcome (..),
  CleanupResult (..),
  attemptCleanup,
 )
import RAGScope.Telemetry.OpenTelemetry.Lifecycle (
  LifecycleReport (..),
  runLifecycle,
 )

-- | Acquisition and release operations for the three provider resources.
--
-- Every acquisition function is responsible for rolling back resources
-- acquired internally if it fails before returning its provider.
--
-- Every release function must attempt its required cleanup operations
-- independently and record their outcomes.
data ProviderOperations trace logs metrics = ProviderOperations
  { acquireTraceProvider ::
      (CleanupOutcome -> IO ()) -> IO trace
  , releaseTraceProvider ::
      (CleanupOutcome -> IO ()) -> trace -> IO ()
  , acquireLogsProvider ::
      (CleanupOutcome -> IO ()) -> IO logs
  , releaseLogsProvider ::
      (CleanupOutcome -> IO ()) -> logs -> IO ()
  , acquireMetricsProvider ::
      (CleanupOutcome -> IO ()) -> IO metrics
  , releaseMetricsProvider ::
      (CleanupOutcome -> IO ()) -> metrics -> IO ()
  }

-- | Acquire Trace, Logs, and Metrics, then run the callback.
--
-- Nested bracket scopes release successfully acquired providers in
-- reverse order, including when a later acquisition or the callback fails.
withProviders ::
  ProviderOperations trace logs metrics ->
  (LifecycleReport -> IO ()) ->
  (trace -> logs -> metrics -> IO a) ->
  IO a
withProviders operations publish use =
  runLifecycle
    ( \record ->
        bracket
          (acquireTraceProvider operations record)
          ( releaseSafely
              record
              "trace.release"
              (releaseTraceProvider operations)
          )
          $ \trace ->
            bracket
              (acquireLogsProvider operations record)
              ( releaseSafely
                  record
                  "logs.release"
                  (releaseLogsProvider operations)
              )
              $ \logs ->
                bracket
                  (acquireMetricsProvider operations record)
                  ( releaseSafely
                      record
                      "metrics.release"
                      (releaseMetricsProvider operations)
                  )
                  $ \metrics ->
                    use trace logs metrics
    )
    publish

-- | Capture an unexpected release exception so outer brackets can continue.
--
-- Individual SDK operations must still be captured and recorded inside
-- the supplied release function. A completed release action does not
-- imply that every SDK cleanup operation succeeded.
releaseSafely ::
  (CleanupOutcome -> IO ()) ->
  String ->
  ((CleanupOutcome -> IO ()) -> resource -> IO ()) ->
  resource ->
  IO ()
releaseSafely record name release resource =
  void $
    attemptCleanup record name $ do
      release record resource
      pure CleanupCompleted
