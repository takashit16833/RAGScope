{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-name-shadowing #-}

module RAGScope.Telemetry.OpenTelemetry.Trace (mkOpenTelemetryTraceBoundary) where

import Control.Exception (
  AsyncException (UserInterrupt),
  Exception (displayException, fromException),
  SomeAsyncException,
  SomeException (..),
  catch,
  throwIO,
 )
import Data.Data (typeOf)
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
import OpenTelemetry.Trace.ExceptionHandler (ignoreExceptionMatching)

import RAGScope.Telemetry.Trace (SpanName (SpanName), SpanOutcome (SpanFailed, SpanSucceeded), SpanRunner, TraceBoundary, mkTraceBoundary)

-- | Build the RAGScope Trace boundary backed by OpenTelemetry.
mkOpenTelemetryTraceBoundary :: TracerProvider -> TraceBoundary
mkOpenTelemetryTraceBoundary tracerProvider =
  mkTraceBoundary $
    runOpenTelemetrySpan tracer
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

-- | Run one RAGScope action inside on OpenTelemetry Span.
runOpenTelemetrySpan :: Tracer -> SpanRunner
runOpenTelemetrySpan tracer (SpanName spanName) classify action =
  inSpan''
    tracer
    spanName
    defaultSpanArguments
    $ \span ->
      handleSynchronousException span $ do
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

-- | Mark an unbandled synchronous exception on the Span and rethrow it.
--
-- Asynchronous exceptions are left ot the surrounding runtime/SDK handling.
handleSynchronousException ::
  Span ->
  IO result ->
  IO result
handleSynchronousException span action =
  action `catch` \exception ->
    if isSynchronousException exception
      then markSynchronousException span exception
      else throwIO exception

markSynchronousException ::
  Span ->
  SomeException ->
  IO result
markSynchronousException span exception@(SomeException inner) = do
  setStatus span $
    Error $
      Text.pack $
        displayException inner

  addAttribute
    span
    "error.type"
    $ Text.pack
    $ show
    $ typeOf inner

  throwIO exception

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
