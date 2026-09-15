{-# LANGUAGE OverloadedStrings #-}

module RAGScope.Telemetry.OpenTelemetryTestSupport (
  TestException (..),
  testExceptionTypeAttribute,
  withTestTracerProvider,
  withTestTraceBoundary,
  withTestLoggerProvider,
  assertTestExceptionSpan,
  assertNoErrorType,
  spanEventCount,
  assertSingleExportedLogRecord,
  assertTracingDetails,
) where

import Control.Exception (
  Exception,
  bracket,
 )
import Control.Monad (void)
import Data.IORef (
  IORef,
  readIORef,
 )
import OpenTelemetry.Attributes (
  Attribute (AttributeValue),
  PrimitiveAttribute (TextAttribute),
  lookupAttribute,
 )
import OpenTelemetry.Exporter.InMemory (
  assertSpanAttribute,
  assertSpanStatus,
  getExportedLogRecords,
  inMemoryListExporter,
  inMemoryLogRecordExporter,
 )
import OpenTelemetry.Internal.Log.Core (
  createLoggerProvider,
  emptyLoggerProviderOptions,
  forceFlushLoggerProvider,
  shutdownLoggerProvider,
 )
import OpenTelemetry.Internal.Log.Types (
  ImmutableLogRecord (logRecordTracingDetails),
  IsReadableLogRecord (readLogRecord),
  LoggerProvider,
  ReadableLogRecord,
  TracingDetails (NoTracingDetails, TracingDetails),
 )
import OpenTelemetry.Log (
  SimpleLogRecordProcessorConfig (
    SimpleLogRecordProcessorConfig,
    simpleLogRecordExportTimeoutMicros,
    simpleLogRecordExporter
  ),
  simpleLogRecordProcessor,
 )
import OpenTelemetry.Trace.Core (
  ImmutableSpan (spanHot),
  SpanContext (spanId, traceFlags, traceId),
  SpanHot (hotAttributes, hotEvents),
  SpanStatus (Error),
  TracerProvider,
  createTracerProvider,
  emptyTracerProviderOptions,
  shutdownTracerProvider,
 )
import OpenTelemetry.Util (
  appendOnlyBoundedCollectionValues,
 )
import Test.Hspec (
  expectationFailure,
  shouldBe,
  shouldReturn,
 )

import RAGScope.Telemetry.OpenTelemetry.Trace (
  mkOpenTelemetryTraceBoundary,
 )
import RAGScope.Telemetry.Trace (
  TraceBoundary,
 )

-- A small test-only exception keeps assertions independent of IOException
-- formatting and lets tests verify that the original exception value is
-- rethrown unchanged.
data TestException = TestException deriving (Eq, Show)

instance Exception TestException

-- | Expected OpenTelemetry representation of the test exception type.
testExceptionTypeAttribute :: Attribute
testExceptionTypeAttribute =
  AttributeValue $
    TextAttribute "TestException"

-- | Run a test example with an isolated TracerProvider and in-memory
-- SpanProcessor.
--
-- Provider lifecycle and exporter storage belong to test infrastructure.
-- Individual examples receive only the resources they actually need.
withTestTracerProvider ::
  ((TracerProvider, IORef [ImmutableSpan]) -> IO ()) ->
  IO ()
withTestTracerProvider =
  bracket
    acquire
    release
 where
  acquire = do
    (processor, spansRef) <-
      inMemoryListExporter

    tracerProvider <-
      createTracerProvider
        [processor]
        emptyTracerProviderOptions

    pure
      ( tracerProvider
      , spansRef
      )

  release (tracerProvider, _) =
    void $
      shutdownTracerProvider
        tracerProvider
        Nothing

-- | Run a test example with an isolated OpenTelemetry-backed TraceBoundary.
--
-- TracerProvider remains a test/setup concern. Tests exercising the RAGScope
-- boundary receive the SDK-independent TraceBoundary plus completed Spans.
withTestTraceBoundary ::
  ((TraceBoundary, IORef [ImmutableSpan]) -> IO ()) ->
  IO ()
withTestTraceBoundary action =
  withTestTracerProvider $
    \(tracerProvider, spansRef) -> do
      let traceBoundary =
            mkOpenTelemetryTraceBoundary tracerProvider

      action
        ( traceBoundary
        , spansRef
        )

-- | Run a test example with an isolated LoggerProvider and in-memory
-- LogRecord exporter.
--
-- Flushing remains explicit in assertions because LogRecord emission and
-- export are separate SDK stages.
withTestLoggerProvider ::
  ((LoggerProvider, IORef [ReadableLogRecord]) -> IO ()) ->
  IO ()
withTestLoggerProvider =
  bracket
    acquire
    release
 where
  acquire = do
    (logExporter, logRecordsRef) <-
      inMemoryLogRecordExporter

    logProcessor <-
      simpleLogRecordProcessor
        SimpleLogRecordProcessorConfig
          { simpleLogRecordExporter = logExporter
          , simpleLogRecordExportTimeoutMicros = 30000000
          }

    loggerProvider <-
      createLoggerProvider
        [logProcessor]
        emptyLoggerProviderOptions

    pure
      ( loggerProvider
      , logRecordsRef
      )

  release (loggerProvider, _) =
    void $
      shutdownLoggerProvider
        loggerProvider
        Nothing

-- | Verify the representation used for the shared test exception.
--
-- This assertion is reusable anywhere TestException escapes through a RAGScope
-- Span: Status/error.type must be present and the SDK must not add an automatic
-- exception Span Event.
assertTestExceptionSpan ::
  ImmutableSpan ->
  IO ()
assertTestExceptionSpan immutableSpan = do
  assertSpanStatus
    immutableSpan
    (Error "TestException")

  assertSpanAttribute
    immutableSpan
    "error.type"
    testExceptionTypeAttribute

  spanEventCount immutableSpan
    `shouldReturn` 0

-- | Verify absence rather than only checking Status.
--
-- A successful Span must not accidentally retain an error.type attribute.
assertNoErrorType ::
  ImmutableSpan ->
  IO ()
assertNoErrorType immutableSpan = do
  hot <-
    readIORef $
      spanHot immutableSpan

  lookupAttribute
    (hotAttributes hot)
    "error.type"
    `shouldBe` Nothing

-- | Return the number of Span Events recorded by hs-opentelemetry.
--
-- Span Events are stored in the SDK's bounded collection. These tests care
-- about the count rather than their internal collection representation.
spanEventCount ::
  ImmutableSpan ->
  IO Int
spanEventCount immutableSpan = do
  hot <-
    readIORef $
      spanHot immutableSpan

  pure $
    length $
      appendOnlyBoundedCollectionValues $
        hotEvents hot

-- | Inspect exactly one exported LogRecord after making exported state stable
-- enough for deterministic assertions.
assertSingleExportedLogRecord ::
  LoggerProvider ->
  IORef [ReadableLogRecord] ->
  (ImmutableLogRecord -> IO ()) ->
  IO ()
assertSingleExportedLogRecord loggerProvider logRecordsRef assertion = do
  -- Emission and export are separate SDK stages. Flushing removes the timing
  -- race between emitLogRecord returning and exporter state becoming visible.
  void $
    forceFlushLoggerProvider
      loggerProvider
      Nothing

  records <-
    getExportedLogRecords logRecordsRef

  case records of
    [record] ->
      -- Assertions use an immutable snapshot so they observe one stable state
      -- rather than an SDK-managed ReadableLogRecord.
      readLogRecord record >>= assertion
    _ ->
      expectationFailure $
        "expected exactly one exported LogRecord, but got "
          <> show (length records)

-- | Verify that a LogRecord refers to the exact SpanContext current when it
-- was emitted, rather than merely containing some tracing information.
assertTracingDetails ::
  SpanContext ->
  ImmutableLogRecord ->
  IO ()
assertTracingDetails spanContext record =
  case logRecordTracingDetails record of
    NoTracingDetails ->
      expectationFailure
        "expected exported LogRecord to contain tracing details"
    TracingDetails actualTraceId actualSpanId actualTraceFlags -> do
      actualTraceId
        `shouldBe` traceId spanContext

      actualSpanId
        `shouldBe` spanId spanContext

      actualTraceFlags
        `shouldBe` traceFlags spanContext
