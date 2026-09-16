{-# LANGUAGE OverloadedStrings #-}

-- | OpenTelemetry Adapter for the RAGScope Trace boundary.
--
-- This module owns Span lifecycle and reflects returned RAGScope outcomes on
-- OpenTelemetry Spans. Exception-specific observation is delegated to the
-- adapter-private exception module.
module RAGScope.Telemetry.OpenTelemetry.Trace (mkOpenTelemetryTraceBoundary) where

import Control.Exception (
  mask,
  rethrowIO,
 )
import OpenTelemetry.Trace.Core (
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

import RAGScope.Telemetry.Logs (
  EventRecordEmitter,
 )
import RAGScope.Telemetry.OpenTelemetry.Exception qualified as Exception
import RAGScope.Telemetry.Trace (
  SpanName (SpanName),
  SpanOutcome (SpanFailed, SpanSucceeded),
  SpanRunner,
  TraceBoundary,
  mkTraceBoundary,
 )

-- | Build the RAGScope Trace boundary backed by OpenTelemetry.
mkOpenTelemetryTraceBoundary ::
  TracerProvider ->
  EventRecordEmitter ->
  TraceBoundary
mkOpenTelemetryTraceBoundary tracerProvider eventRecordEmitter =
  mkTraceBoundary $
    runOpenTelemetrySpan
      tracer
      exceptionHandler
 where
  tracer =
    makeTracer
      tracerProvider
      "ragscope"
      tracerOptions
        { tracerExceptionHandlerOptions =
            Exception.tracerExceptionHandlers
        }

  exceptionHandler =
    Exception.mkSpanExceptionHandler
      eventRecordEmitter

-- | Run one RAGScope action inside an OpenTelemetry Span.
runOpenTelemetrySpan ::
  Tracer ->
  Exception.SpanExceptionHandler ->
  SpanRunner
runOpenTelemetrySpan tracer handleException (SpanName spanName) classify action =
  mask $ \restore -> do
    spanExit <-
      inSpan''
        tracer
        spanName
        defaultSpanArguments
        $ \otelSpan ->
          handleException
            otelSpan
            $ restore
            $ do
              result <- action

              applySpanOutcome
                otelSpan
                (classify result)

              pure result

    either rethrowIO pure spanExit

-- | Reflect the final RAGScope result on the Span.
applySpanOutcome ::
  Span ->
  SpanOutcome ->
  IO ()
applySpanOutcome _ SpanSucceeded =
  pure ()
applySpanOutcome otelSpan (SpanFailed errorType) = do
  setStatus
    otelSpan
    (Error "")

  addAttribute
    otelSpan
    "error.type"
    errorType
