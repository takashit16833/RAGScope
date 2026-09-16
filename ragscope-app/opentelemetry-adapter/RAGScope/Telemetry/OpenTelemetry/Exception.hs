{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-missing-fields #-}

-- | Cross-signal OpenTelemetry handling for exceptions escaping a RAGScope
-- Span.
--
-- This module coordinates Trace state and the single Logs EventRecord that
-- represents one synchronous exception propagation.
module RAGScope.Telemetry.OpenTelemetry.Exception (
  SpanExceptionHandler,
  mkSpanExceptionHandler,
  tracerExceptionHandlers,
) where

import Control.Exception (
  AsyncException (UserInterrupt),
  Exception (displayException, fromException),
  ExceptionWithContext (ExceptionWithContext),
  SomeAsyncException,
  SomeException (..),
  catchNoPropagate,
  rethrowIO,
 )
import Control.Exception.Annotation (
  ExceptionAnnotation,
 )
import Control.Exception.Context (
  ExceptionContext,
  addExceptionAnnotation,
  getExceptionAnnotations,
 )
import Data.Data (typeOf)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import OpenTelemetry.Trace.Core (
  ExceptionHandler,
  Span,
  SpanStatus (Error),
  addAttribute,
  setStatus,
 )
import OpenTelemetry.Trace.ExceptionHandler (
  ignoreExceptionMatching,
 )

import RAGScope.Telemetry.Logs (
  EventName,
  EventRecord (..),
  EventRecordEmitter,
  EventTimestamp (EventNow),
  LogValue (LogText),
  eventNameLiteral,
 )
import RAGScope.Telemetry.Logs qualified as Logs

-- | Preserve both the original exception and its propagation context.
--
-- The context must survive nested Span boundaries so the exactly-once marker
-- is not lost while the exception propagates outward.
type CapturedException =
  ExceptionWithContext SomeException

-- | Adapter-local transport across the SDK's normal return path.
--
-- Synchronous exceptions are returned through the callback instead of
-- rethrown inside it so their ExceptionContext survives the SDK boundary.
-- Right may itself contain an application-level Left failure.
type SpanExit result =
  Either CapturedException result

-- | Handle exceptions escaping one OpenTelemetry Span.
--
-- The EventRecordEmitter is captured when this handler is constructed rather
-- than threaded through every step of Span execution.
type SpanExceptionHandler =
  forall result.
  Span ->
  IO result ->
  IO (SpanExit result)

-- | Capture the EventRecordEmitter once so Span execution only depends on an
-- exception handler, not on the logging dependency itself.
mkSpanExceptionHandler ::
  EventRecordEmitter ->
  SpanExceptionHandler
mkSpanExceptionHandler eventRecordEmitter =
  handleSynchronousException
 where
  -- Return synchronous exceptions through SpanExit so they can cross the
  -- OpenTelemetry callback without losing their ExceptionContext.
  handleSynchronousException :: SpanExceptionHandler
  handleSynchronousException otelSpan action =
    (Right <$> action)
      `catchNoPropagate` \exceptionWithContext@(ExceptionWithContext _ exception) ->
        if isSynchronousException exception
          then
            Left
              <$> observeSynchronousException
                otelSpan
                exceptionWithContext
          else
            rethrowIO exceptionWithContext

  -- Every Span escaped by the exception must be marked failed, while only the
  -- first such Span may emit the exception EventRecord.
  observeSynchronousException ::
    Span ->
    CapturedException ->
    IO CapturedException
  observeSynchronousException
    otelSpan
    exceptionWithContext@(ExceptionWithContext exceptionContext exception@(SomeException inner)) = do
      let
        exceptionMessage =
          Text.pack $
            displayException inner

        exceptionType =
          Text.pack $
            show $
              typeOf inner

      markSpanFailed
        otelSpan
        exceptionType
        exceptionMessage

      case claimExceptionEvent exceptionContext of
        Nothing ->
          pure exceptionWithContext
        Just claimedContext -> do
          eventRecordEmitter $
            exceptionEventRecord
              exceptionType
              exceptionMessage

          pure $
            ExceptionWithContext
              claimedContext
              exception

-- | Marks one exception propagation after its exception EventRecord has been
-- recorded.
--
-- The annotation belongs to ExceptionContext rather than to the exception type
-- because recording state differs between individual exception propagations.
data ExceptionEventRecorded
  = ExceptionEventRecorded
  deriving (Show)

-- The marker must participate in ExceptionContext so it follows the same
-- propagation as the exception itself.
instance ExceptionAnnotation ExceptionEventRecorded

-- | Mark each escaped Span independently because exactly-once applies only to
-- the Logs EventRecord, not to Span failure state.
markSpanFailed ::
  Span ->
  Text ->
  Text ->
  IO ()
markSpanFailed otelSpan exceptionType exceptionMessage = do
  setStatus
    otelSpan
    (Error exceptionMessage)

  addAttribute
    otelSpan
    "error.type"
    exceptionType

-- | Use ExceptionContext as the ownership token so nested Spans share one
-- exactly-once decision for the same exception propagation.
--
-- Nothing means that an inner Span already recorded the EventRecord.
claimExceptionEvent ::
  ExceptionContext ->
  Maybe ExceptionContext
claimExceptionEvent exceptionContext =
  case getExceptionAnnotations @ExceptionEventRecorded exceptionContext of
    [] ->
      Just $
        addExceptionAnnotation
          ExceptionEventRecorded
          exceptionContext
    _ ->
      Nothing

-- | Keep EventRecord construction pure so deciding what to record stays
-- separate from deciding which Span owns the single emission.
exceptionEventRecord ::
  Text ->
  Text ->
  EventRecord
exceptionEventRecord exceptionType exceptionMessage =
  EventRecord
    { eventName = exceptionEventName
    , eventTimestamp = EventNow
    , eventSeverity = Logs.Error
    , eventAttributes =
        Map.fromList
          [ ("exception.type", LogText exceptionType)
          , ("exception.message", LogText exceptionMessage)
          ]
    }

-- | Construct the fixed exception event name with compile-time validation.
exceptionEventName :: EventName
exceptionEventName =
  eventNameLiteral @"exception"

-- | Prevent the SDK from duplicating exception observation that RAGScope
-- performs itself.
--
-- RAGScope handles synchronous exceptions itself so the SDK must not add a
-- duplicate exception Span Event. UserInterrupt is an intentional
-- interruption rather than a Span failure.
tracerExceptionHandlers :: [ExceptionHandler]
tracerExceptionHandlers =
  [ ignoreSynchronousException
  , ignoreIntentionalInterruption
  ]

-- RAGScope observes synchronous exception itself so the SDK must not record
-- the same exception independently.
ignoreSynchronousException :: ExceptionHandler
ignoreSynchronousException =
  ignoreExceptionMatching
    @SomeException
    isSynchronousException

-- UserInterrupted represents intentional termination and must not turn the Span
-- into an application failure.
ignoreIntentionalInterruption :: ExceptionHandler
ignoreIntentionalInterruption =
  ignoreExceptionMatching
    @AsyncException
    (== UserInterrupt)

-- Separate asynchronous exceptions because ordinary synchronous failures
-- participate in RAGScope's exactly-once exception EventRecord policy.
isSynchronousException :: SomeException -> Bool
isSynchronousException exception =
  case fromException exception :: Maybe SomeAsyncException of
    Just _ ->
      False
    Nothing ->
      True
