{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-name-shadowing #-}

module RAGScope.Telemetry.OpenTelemetry.Trace (mkOpenTelemetryTraceBoundary) where

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

-- | Marks one exception propagation after its exception EventRecord has been
-- recorded.
--
-- The annotation belongs to ExceptionContext rather than to the exception type
-- because recording state differs between individual exception propagations.
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
  inSpan''
    tracer
    spanName
    defaultSpanArguments
    $ \span ->
      handleSynchronousException
        eventRecordEmitter
        span
        $ do
          result <- action

          applySpanOutcome span (classify result)

          pure result

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
-- The exception context is preserved so an exception EventRecord recorded by
-- the first Span remains marked while the same exception propagates through
-- outer Span boundaries.
handleSynchronousException ::
  EventRecordEmitter ->
  Span ->
  IO result ->
  IO result
handleSynchronousException eventRecordEmitter span action =
  action `catchNoPropagate` \exceptionWithContext@(ExceptionWithContext _ exception) ->
    if isSynchronousException exception
      then
        markSynchronousException
          eventRecordEmitter
          span
          exceptionWithContext
      else
        rethrowIO exceptionWithContext

-- | Mark one Span as failed by a synchronous exception and record the
-- exception EventRecord only when this Span gets the first claim.
markSynchronousException ::
  EventRecordEmitter ->
  Span ->
  ExceptionWithContext SomeException ->
  IO result
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
        rethrowIO exceptionWithContext
      Just claimedContext -> do
        emitExceptionEvent
          eventRecordEmitter
          exceptionType
          exceptionMessage

        rethrowIO $
          ExceptionWithContext
            claimedContext
            exception

-- | Claim exception EventRecord ownership for one exception propagation.
--
-- Nothing means that another inner Span already recorded the EventRecord.
-- Just returns the ExceptionContext carrying the marker for the first claim.
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

-- | hs-opentelemetry must not automatically add another exception Span Event
-- for synchronous exceptions already handled above.
ignoreSynchronousException :: ExceptionHandler
ignoreSynchronousException =
  ignoreExceptionMatching @SomeException isSynchronousException

-- | UserInterrupt represents an intentional user interruption and must not
-- be recorded as a Span error.
ignoreIntentionalInterruption :: ExceptionHandler
ignoreIntentionalInterruption =
  ignoreExceptionMatching @AsyncException (== UserInterrupt)

isSynchronousException :: SomeException -> Bool
isSynchronousException exception =
  case fromException exception :: Maybe SomeAsyncException of
    Just _ ->
      False
    Nothing ->
      True
