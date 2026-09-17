-- | Resource cleanup support for the OpenTelemetry Adapter.
--
-- Each cleanup step is attempted independently. The caller is responsible
-- for inspecting the outcomes and propagating any deferred interruption.
module RAGScope.Telemetry.OpenTelemetry.Lifecycle (
  CleanupResult (..),
  CleanupStep (..),
  CleanupOutcome (..),
  CleanupJournal,
  newCleanupJournal,
  readCleanupOutcomes,
  readSupersededExceptions,
  ProviderAcquisition (..),
  runCleanupSteps,
  withOwned,
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
  IORef,
  modifyIORef',
  newIORef,
  readIORef,
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

-- | Results collected during one lifecycle invocation.
--
-- The second reference retains original synchronous exceptions that are
-- superseded by asynchronous interruptions during cleanup.
data CleanupJournal = CleanupJournal
  { journalOutcomes :: IORef [CleanupOutcome]
  , journalSupersededExceptions ::
      IORef [ExceptionWithContext SomeException]
  }

-- | Create an empty journal for a single lifecycle invocation.
newCleanupJournal :: IO CleanupJournal
newCleanupJournal =
  CleanupJournal
    <$> newIORef []
    <*> newIORef []

-- | Read the cleanup outcomes in execution order.
readCleanupOutcomes :: CleanupJournal -> IO [CleanupOutcome]
readCleanupOutcomes =
  readIORef . journalOutcomes

-- | Read original exceptions superseded by cleanup interruptions.
readSupersededExceptions ::
  CleanupJournal ->
  IO [ExceptionWithContext SomeException]
readSupersededExceptions =
  readIORef . journalSupersededExceptions

-- | Describe how to acquire and release one provider.
--
-- An acquisition function must clean up resources acquired internally
-- if it fails before returning the provider.
data ProviderAcquisition resource = ProviderAcquisition
  { acquireProvider :: (CleanupOutcome -> IO ()) -> IO resource
  , providerCleanup :: resource -> [CleanupStep]
  }

-- | Append one cleanup outcome to the current journal.
recordCleanupOutcome :: CleanupJournal -> CleanupOutcome -> IO ()
recordCleanupOutcome journal outcome =
  modifyIORef'
    (journalOutcomes journal)
    (<> [outcome])

-- | Append cleanup outcomes in their execution order.
recordCleanupOutcomes :: CleanupJournal -> [CleanupOutcome] -> IO ()
recordCleanupOutcomes journal outcomes =
  modifyIORef'
    (journalOutcomes journal)
    (<> outcomes)

-- | Record an original exception displaced by a later interruption.
recordSupersededException ::
  CleanupJournal ->
  ExceptionWithContext SomeException ->
  IO ()
recordSupersededException journal exception =
  modifyIORef'
    (journalSupersededExceptions journal)
    (<> [exception])

-- | Attempt every cleanup step, retaining failures and interruptions.
--
-- This function does not decide which exception to rethrow. The outer
-- lifecycle must inspect the returned outcomes before returning to its caller.
runCleanupSteps :: [CleanupStep] -> IO [CleanupOutcome]
runCleanupSteps steps =
  mask $ \_ ->
    traverse runStep steps
 where
  runStep step = do
    result <-
      tryWithContext @SomeException $
        cleanupStepAction step

    pure
      CleanupOutcome
        { cleanupOutcomeName = cleanupStepName step
        , cleanupOutcomeResult = result
        }

-- | Acquire a resource, run its callback, and attempt all cleanup steps.
--
-- The callback runs with the previous asynchronous exception masking state.
-- Cleanup failures are recorded without replacing an ordinary callback
-- result or exception. Asynchronous interruptions retain their priority.
withOwned ::
  CleanupJournal ->
  ProviderAcquisition resource ->
  (resource -> IO a) ->
  IO a
withOwned journal acquisition use =
  mask $ \restore -> do
    resource <-
      restore $
        acquireProvider acquisition $
          recordCleanupOutcome journal

    actionResult <-
      tryWithContext @SomeException $
        restore $
          use resource

    cleanupOutcomes <-
      runCleanupSteps $
        providerCleanup acquisition resource

    recordCleanupOutcomes journal cleanupOutcomes

    case actionResult of
      Left originalException
        | isAsyncException originalException ->
            rethrowIO originalException
        | otherwise ->
            case firstAsyncException cleanupOutcomes of
              Just interruption -> do
                recordSupersededException journal originalException
                rethrowIO interruption
              Nothing ->
                rethrowIO originalException
      Right result ->
        case firstAsyncException cleanupOutcomes of
          Just interruption ->
            rethrowIO interruption
          Nothing ->
            pure result

-- | Identify an asynchronous exception without discarding its context.
isAsyncException ::
  ExceptionWithContext SomeException ->
  Bool
isAsyncException (ExceptionWithContext _ exception) =
  case fromException exception :: Maybe SomeAsyncException of
    Just _ ->
      True
    Nothing ->
      False

-- | Find the first asynchronous interruption recorded during cleanup.
firstAsyncException ::
  [CleanupOutcome] ->
  Maybe (ExceptionWithContext SomeException)
firstAsyncException [] =
  Nothing
firstAsyncException (outcome : remaining) =
  case cleanupOutcomeResult outcome of
    Left exception
      | isAsyncException exception ->
          Just exception
    _ ->
      firstAsyncException remaining
