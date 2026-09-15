{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-name-shadowing #-}

-- | OpenTelemetry implementation of the RAGScope Trace boundary.
--
-- Manages Span lifecycle, maps RAGScope outcomes to Span status, and records
-- synchronous exceptions without duplicating exception EventRecords.
module RAGScope.Telemetry.OpenTelemetry.Trace (mkOpenTelemetryTraceBoundary) where

import Control.Exception (
  AsyncException (UserInterrupt),
  Exception (displayException, fromException),
  ExceptionWithContext (ExceptionWithContext),
  SomeAsyncException,
  SomeException (..),
  catchNoPropagate,
  mask,
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
  Tracer,
  TracerOptions (tracerExceptionHandlerOptions),
  TracerProvider,
  addAttribute,
  defaultSpanArguments,
  inSpan'',
  makeTracer,
  setStatus,
  tracerOptions,
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
  mkEventName,
 )
import RAGScope.Telemetry.Logs qualified as Logs
import RAGScope.Telemetry.Trace (
  SpanName (SpanName),
  SpanOutcome (SpanFailed, SpanSucceeded),
  SpanRunner,
  TraceBoundary,
  mkTraceBoundary,
 )

-- | Preserve the ExceptionContext carrying exception propagation state.
type CapturedException = ExceptionWithContext SomeException

-- | Carry a synchronous exception through inSpan'' as an ordinary return value.
--
-- This avoids hs-opentelemetry's SomeException rethrow path, which would lose
-- the ExceptionContext used for exactly-once EventRecord ownership.
type SpanExit result = Either CapturedException result

-- | Marks one exception propagation after its exception EventRecord has been
-- recorded.
--
-- The annotation belongs to ExceptionContext because recording state is
-- specific to each exception propagation.
data ExceptionEventRecorded
  = ExceptionEventRecorded
  deriving (Show)

instance ExceptionAnnotation ExceptionEventRecorded

-- | Build the RAGScope Trace boundary backed by OpenTelemetry.
mkOpenTelemetryTraceBoundary ::
  TracerProvider ->
  EventRecordEmitter ->
  TraceBoundary
mkOpenTelemetryTraceBoundary tracerProvider eventRecordEmitter =
  mkTraceBoundary $
    runOpenTelemetrySpan
      tracer
      eventRecordEmitter
 where
  tracer =
    makeTracer
      tracerProvider
      "ragscope"
      tracerOptions
        { tracerExceptionHandlerOptions =
            [ ignoreSynchronousException
            , ignoreIntentionalInterruption
            ]
        }

-- | Run one RAGScope action inside an OpenTelemetry Span.
runOpenTelemetrySpan ::
  Tracer ->
  EventRecordEmitter ->
  SpanRunner
runOpenTelemetrySpan tracer eventRecordEmitter (SpanName spanName) classify action =
  -- Keep exception transport masked while preserving normal async-exception
  -- behavior inside the wrapped application action.
  mask $ \restore -> do
    exit <-
      inSpan''
        tracer
        spanName
        defaultSpanArguments
        $ \span ->
          handleSynchronousException
            eventRecordEmitter
            span
            $ restore
            $ do
              result <- action

              applySpanOutcome span (classify result)

              pure result

    -- Rethrow outside inSpan'' so the ExceptionContext survives propagation.
    either rethrowIO pure exit

-- | Reflect the final RAGScope result on the Span.
applySpanOutcome ::
  Span ->
  SpanOutcome ->
  IO ()
applySpanOutcome _ SpanSucceeded =
  pure ()
applySpanOutcome span (SpanFailed errorType) = do
  setStatus span $ Error ""

  addAttribute
    span
    "error.type"
    errorType

-- | Handle a synchronous exception that propagates out of a RAGScope Span.
--
-- Synchronous exceptions become SpanExit values so inSpan'' can finish through
-- its normal return path. Async exceptions keep their normal propagation.
handleSynchronousException ::
  EventRecordEmitter ->
  Span ->
  IO result ->
  IO (SpanExit result)
handleSynchronousException eventRecordEmitter span action =
  (Right <$> action)
    `catchNoPropagate` \exceptionWithContext@(ExceptionWithContext _ exception) ->
      if isSynchronousException exception
        then
          Left
            <$> markSynchronousException
              eventRecordEmitter
              span
              exceptionWithContext
        else
          rethrowIO exceptionWithContext

-- | Mark one Span as failed by a synchronous exception.
--
-- The exception is returned rather than rethrown here so its ExceptionContext
-- does not pass through hs-opentelemetry's SomeException rethrow path.
markSynchronousException ::
  EventRecordEmitter ->
  Span ->
  CapturedException ->
  IO CapturedException
markSynchronousException
  eventRecordEmitter
  span
  exceptionWithContext@(ExceptionWithContext exceptionContext exception@(SomeException inner)) = do
    let
      exceptionMessage =
        Text.pack $
          displayException inner

      exceptionType =
        Text.pack $
          show $
            typeOf inner

    setStatus
      span
      (Error exceptionMessage)

    addAttribute
      span
      "error.type"
      exceptionType

    case claimExceptionEvent exceptionContext of
      Nothing ->
        pure exceptionWithContext
      Just claimedContext -> do
        emitExceptionEvent
          eventRecordEmitter
          exceptionType
          exceptionMessage

        pure $
          ExceptionWithContext
            claimedContext
            exception

-- | Claim EventRecord ownership for one exception propagation.
--
-- The first Span adds the marker; outer Spans see it and do not emit another
-- exception EventRecord.
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

-- | Record the generic OpenTelemetry exception EventRecord.
emitExceptionEvent ::
  EventRecordEmitter ->
  Text ->
  Text ->
  IO ()
emitExceptionEvent eventRecordEmitter exceptionType exceptionMessage =
  eventRecordEmitter $
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

-- | Generic OpenTelemetry exception EventName.
exceptionEventName :: EventName
exceptionEventName =
  case mkEventName "exception" of
    Right eventName ->
      eventName
    Left failure ->
      error $
        "exceptionEventName: failed to construct static exception EventName: "
          <> show failure

-- | Prevent hs-opentelemetry from adding a duplicate exception Span Event for
-- synchronous exceptions already handled by this adapter.
ignoreSynchronousException :: ExceptionHandler
ignoreSynchronousException =
  ignoreExceptionMatching @SomeException isSynchronousException

-- | UserInterrupt is intentional and must not be recorded as a Span error.
ignoreIntentionalInterruption :: ExceptionHandler
ignoreIntentionalInterruption =
  ignoreExceptionMatching @AsyncException (== UserInterrupt)

-- | Distinguish synchronous exceptions from asynchronous interruption.
isSynchronousException :: SomeException -> Bool
isSynchronousException exception =
  case fromException exception :: Maybe SomeAsyncException of
    Just _ ->
      False
    Nothing ->
      True
