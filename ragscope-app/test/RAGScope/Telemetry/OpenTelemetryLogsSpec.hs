{-# LANGUAGE OverloadedStrings #-}

-- | Tests the OpenTelemetry Logs Adapter for the RAGScope Logs boundary.
--
-- These tests verify conversion of 'LogRecord' and 'EventRecord' values,
-- EventNow timestamp generation, and correlation with the current Span.
module RAGScope.Telemetry.OpenTelemetryLogsSpec (spec) where

import Control.Exception (bracket)
import Control.Monad (void)
import Data.IORef (IORef)
import Data.Map.Strict qualified as Map
import Data.Maybe (isJust)
import OpenTelemetry.Exporter.InMemory (
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
  ImmutableLogRecord (
    logRecordBody,
    logRecordEventName,
    logRecordSeverityNumber,
    logRecordTimestamp,
    logRecordTracingDetails
  ),
  IsReadableLogRecord (readLogRecord),
  LoggerProvider,
  ReadableLogRecord,
  TracingDetails (NoTracingDetails, TracingDetails),
  toBaseMaybe,
 )
import OpenTelemetry.Log (
  AnyValue (NullValue, TextValue),
  SimpleLogRecordProcessorConfig (
    SimpleLogRecordProcessorConfig,
    simpleLogRecordExportTimeoutMicros,
    simpleLogRecordExporter
  ),
  simpleLogRecordProcessor,
 )
import OpenTelemetry.Trace.Core (
  SpanContext (spanId, traceFlags, traceId),
  createTracerProvider,
  emptyTracerProviderOptions,
  getActiveSpanContext,
  shutdownTracerProvider,
 )
import Test.Hspec (
  Spec,
  around,
  describe,
  expectationFailure,
  it,
  shouldBe,
  shouldSatisfy,
 )

import RAGScope.Telemetry.Logs (
  EventName,
  EventRecord (
    EventRecord,
    eventAttributes,
    eventName,
    eventSeverity,
    eventTimestamp
  ),
  EventTimestamp (EventNow),
  LogRecord (
    LogRecord,
    logAttributes,
    logBody,
    logSeverity,
    logTimestamp
  ),
  LogValue (LogText),
  LogsBoundary,
  Severity (Info, Warn),
  emitEventRecord,
  emitLogRecord,
  mkEventName,
 )
import RAGScope.Telemetry.OpenTelemetry.Logs (mkOpenTelemetryLogsBoundary)
import RAGScope.Telemetry.OpenTelemetry.Trace (mkOpenTelemetryTraceBoundary)
import RAGScope.Telemetry.Trace (
  SpanName (SpanName),
  SpanOutcome (SpanSucceeded),
  TraceBoundary,
  withSpan,
 )

type TestLogsEnvironment =
  ( LogsBoundary
  , TraceBoundary
  , LoggerProvider
  , IORef [ReadableLogRecord]
  )

spec :: Spec
spec =
  -- LoggerProvider, TracerProvider, and exporter state must not leak between
  -- examples because that could make one example observe records or Context
  -- created by another.
  around withTestLogsEnvironment $
    describe "OpenTelemetry LogsBoundary" $ do
      it "records a LogRecord without an event name" $
        \(logsBoundary, _, loggerProvider, logRecordsRef) -> do
          emitLogRecord
            logsBoundary
            testLogRecord

          assertSingleExportedLogRecord
            loggerProvider
            logRecordsRef
            $ \record -> do
              -- Body and severity originate in RAGScope, so preserving them
              -- verifies that conversion does not change application data.
              logRecordBody record
                `shouldBe` TextValue "test-log"

              fmap fromEnum (toBaseMaybe $ logRecordSeverityNumber record)
                `shouldBe` Just 9

              -- Event name is the representation-level distinction between
              -- LogRecord and EventRecord after both become OpenTelemetry
              -- LogRecords.
              toBaseMaybe (logRecordEventName record)
                `shouldBe` Nothing

              -- RAGScope supplied no source timestamp, so the Adapter must not
              -- invent one during conversion.
              toBaseMaybe (logRecordTimestamp record)
                `shouldBe` Nothing

      it "records an EventRecord with its event name" $
        \(logsBoundary, _, loggerProvider, logRecordsRef) -> do
          emitEventRecord
            logsBoundary
            testEventRecord

          assertSingleExportedLogRecord
            loggerProvider
            logRecordsRef
            $ \record -> do
              -- EventRecord has no body field, so NullValue preserves that
              -- absence instead of inventing content during conversion.
              logRecordBody record
                `shouldBe` NullValue

              fmap fromEnum (toBaseMaybe $ logRecordSeverityNumber record)
                `shouldBe` Just 13

              -- EventName must survive conversion because it is what keeps
              -- EventRecord identifiable after conversion to LogRecord.
              toBaseMaybe (logRecordEventName record)
                `shouldBe` Just "ragscope.test.event"

      it "generates an occurrence timestamp for EventNow" $
        \(logsBoundary, _, loggerProvider, logRecordsRef) -> do
          emitEventRecord
            logsBoundary
            testEventRecord

          assertSingleExportedLogRecord
            loggerProvider
            logRecordsRef
            $ \record -> do
              -- EventNow delegates timestamp creation to the Adapter, so a
              -- missing timestamp here would mean that policy was not resolved
              -- at emission time.
              toBaseMaybe (logRecordTimestamp record)
                `shouldSatisfy` isJust

      it "correlates a LogRecord with the current Span" $
        \(logsBoundary, traceBoundary, loggerProvider, logRecordsRef) -> do
          activeSpanContext <-
            withSpan
              traceBoundary
              (SpanName "log-correlation-span")
              (const SpanSucceeded)
              $ do
                -- Capture the exact Context current at emission time so the
                -- assertion can verify identity rather than merely checking
                -- that some tracing information exists.
                activeSpanContext <- getActiveSpanContext

                emitLogRecord
                  logsBoundary
                  testLogRecord

                pure activeSpanContext

          assertSingleExportedLogRecord
            loggerProvider
            logRecordsRef
            $ \record ->
              case activeSpanContext of
                Nothing ->
                  expectationFailure
                    "expected an active SpanContext while emitting LogRecord"
                Just spanContext -> do
                  -- The Adapter deliberately leaves context unspecified, so an
                  -- exact match proves that hs-opentelemetry resolved the
                  -- current Context implicitly.
                  assertTracingDetails
                    spanContext
                    record

      it "correlates an EventRecord with the current Span" $
        \(logsBoundary, traceBoundary, loggerProvider, logRecordsRef) -> do
          activeSpanContext <-
            withSpan
              traceBoundary
              (SpanName "event-correlation-span")
              (const SpanSucceeded)
              $ do
                -- Use the Context current at the exact emission point so this
                -- test exercises the same implicit resolution as LogRecord.
                activeSpanContext <- getActiveSpanContext

                emitEventRecord
                  logsBoundary
                  testEventRecord

                pure activeSpanContext

          assertSingleExportedLogRecord
            loggerProvider
            logRecordsRef
            $ \record ->
              case activeSpanContext of
                Nothing ->
                  expectationFailure
                    "expected an active SpanContext while emitting EventRecord"
                Just spanContext -> do
                  -- LogRecord and EventRecord must use the same current-Context
                  -- mechanism; EventRecord semantics must not bypass trace
                  -- correlation.
                  assertTracingDetails
                    spanContext
                    record

-- | Provide the real OpenTelemetry environment needed to exercise Adapter
-- behavior rather than replacing SDK Context handling with test doubles.
--
-- The correlation examples need a real TracerProvider because the Logs Adapter
-- resolves the current Context implicitly. The in-memory processors avoid any
-- dependency on an external OpenTelemetry backend.
withTestLogsEnvironment ::
  (TestLogsEnvironment -> IO ()) ->
  IO ()
withTestLogsEnvironment action =
  bracket
    acquire
    release
    $ \(_, loggerProvider, logsBoundary, traceBoundary, logRecordsRef) ->
      action
        ( logsBoundary
        , traceBoundary
        , loggerProvider
        , logRecordsRef
        )
 where
  acquire = do
    -- In-memory export keeps the test focused on Adapter behavior and removes
    -- network or backend availability from the result.
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

    -- Correlation must be produced by the real OpenTelemetry Context mechanism,
    -- not by manually constructing or injecting SpanContext test data.
    (spanProcessor, _) <-
      inMemoryListExporter

    tracerProvider <-
      createTracerProvider
        [spanProcessor]
        emptyTracerProviderOptions

    let
      logsBoundary =
        mkOpenTelemetryLogsBoundary loggerProvider

      traceBoundary =
        mkOpenTelemetryTraceBoundary tracerProvider

    pure
      ( tracerProvider
      , loggerProvider
      , logsBoundary
      , traceBoundary
      , logRecordsRef
      )

  release (tracerProvider, loggerProvider, _, _, _) = do
    void $
      shutdownLoggerProvider loggerProvider Nothing

    void $
      shutdownTracerProvider tracerProvider Nothing

-- | Inspect exactly one exported LogRecord after making its exported state
-- stable enough for deterministic assertions.
assertSingleExportedLogRecord ::
  LoggerProvider ->
  IORef [ReadableLogRecord] ->
  (ImmutableLogRecord -> IO ()) ->
  IO ()
assertSingleExportedLogRecord loggerProvider logRecordRef assertion = do
  -- Emission and export are separate SDK stages. Flushing removes the timing
  -- race between emitLogRecord returning and the exporter becoming observable.
  void $
    forceFlushLoggerProvider
      loggerProvider
      Nothing

  records <-
    getExportedLogRecords logRecordRef

  case records of
    [record] ->
      -- Assertions use an immutable snapshot so they observe one stable state
      -- rather than an SDK-managed ReadableLogRecord.
      readLogRecord record >>= assertion
    _ ->
      -- Each example owns a fresh exporter and emits exactly once, so any
      -- other count represents either missing or duplicate emission.
      expectationFailure $
        "expected exactly one exported LogRecord, but got "
          <> show (length records)

-- | Verify that correlation refers to the exact SpanContext current when the
-- LogRecord was emitted, not merely to some attached tracing information.
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
      -- All propagated Context fields must agree; matching only TraceId would
      -- not prove that the LogRecord belongs to the exact current Span.
      actualTraceId
        `shouldBe` traceId spanContext

      actualSpanId
        `shouldBe` spanId spanContext

      actualTraceFlags
        `shouldBe` traceFlags spanContext

-- | Keep LogRecord test data minimal so assertions isolate Adapter behavior
-- from fields irrelevant to each example.
testLogRecord :: LogRecord
testLogRecord =
  LogRecord
    { logTimestamp = Nothing
    , logSeverity = Info
    , logBody = LogText "test-log"
    , logAttributes = Map.empty
    }

-- | Keep EventRecord test data minimal for the same reason as 'testLogRecord'.
testEventRecord :: EventRecord
testEventRecord =
  EventRecord
    { eventName = testEventName
    , eventTimestamp = EventNow
    , eventSeverity = Warn
    , eventAttributes = Map.empty
    }

-- | Construct the fixture through the public validation path because EventName
-- hides its constructor and production RAGScope code must follow the same path.
testEventName :: EventName
testEventName =
  case mkEventName "ragscope.test.event" of
    Right eventName ->
      eventName
    Left failure ->
      error $
        "testEventName: unexpected validation failure: "
          <> show failure
