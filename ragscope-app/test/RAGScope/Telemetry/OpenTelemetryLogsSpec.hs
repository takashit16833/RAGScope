{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Tests the OpenTelemetry Logs Adapter for the RAGScope Logs boundary.
--
-- These tests verify conversion of 'LogRecord' and 'EventRecord' values,
-- EventNow timestamp generation, and correlation with the current Span.
module RAGScope.Telemetry.OpenTelemetryLogsSpec (spec) where

import Data.IORef (IORef)
import Data.Map.Strict qualified as Map
import Data.Maybe (isJust)
import OpenTelemetry.Internal.Log.Types (
  ImmutableLogRecord (
    logRecordBody,
    logRecordEventName,
    logRecordSeverityNumber,
    logRecordTimestamp
  ),
  LoggerProvider,
  ReadableLogRecord,
  toBaseMaybe,
 )
import OpenTelemetry.Log (
  AnyValue (NullValue, TextValue),
 )
import OpenTelemetry.Trace.Core (
  getActiveSpanContext,
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
  eventNameLiteral,
 )
import RAGScope.Telemetry.OpenTelemetry.Logs (
  mkOpenTelemetryLogsBoundary,
 )
import RAGScope.Telemetry.OpenTelemetryTestSupport (
  assertSingleExportedLogRecord,
  assertTracingDetails,
  withTestLoggerProvider,
  withTestTraceBoundary,
 )
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

              fmap
                fromEnum
                (toBaseMaybe $ logRecordSeverityNumber record)
                `shouldBe` Just 9

              -- Event name is the representation-level distinction between
              -- LogRecord and EventRecord after both become OpenTelemetry
              -- LogRecords.
              toBaseMaybe
                (logRecordEventName record)
                `shouldBe` Nothing

              -- RAGScope supplied no source timestamp, so the Adapter must not
              -- invent one during conversion.
              toBaseMaybe
                (logRecordTimestamp record)
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

              fmap
                fromEnum
                (toBaseMaybe $ logRecordSeverityNumber record)
                `shouldBe` Just 13

              -- EventName must survive conversion because it is what keeps
              -- EventRecord identifiable after conversion to LogRecord.
              toBaseMaybe
                (logRecordEventName record)
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
              toBaseMaybe
                (logRecordTimestamp record)
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
                activeSpanContext <-
                  getActiveSpanContext

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
                Just spanContext ->
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
                activeSpanContext <-
                  getActiveSpanContext

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
                Just spanContext ->
                  -- LogRecord and EventRecord must use the same current-Context
                  -- mechanism; EventRecord semantics must not bypass trace
                  -- correlation.
                  assertTracingDetails
                    spanContext
                    record

-- | Provide the real OpenTelemetry environment needed to exercise Adapter
-- behavior rather than replacing SDK Context handling with test doubles.
--
-- Trace and Logs Provider lifecycle is shared test infrastructure. This helper
-- only composes those resources into the boundaries required by these tests.
withTestLogsEnvironment ::
  (TestLogsEnvironment -> IO ()) ->
  IO ()
withTestLogsEnvironment action =
  withTestTraceBoundary $
    \(traceBoundary, _) ->
      withTestLoggerProvider $
        \(loggerProvider, logRecordsRef) -> do
          let logsBoundary =
                mkOpenTelemetryLogsBoundary loggerProvider

          action
            ( logsBoundary
            , traceBoundary
            , loggerProvider
            , logRecordsRef
            )

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

-- | Construct the fixed test event name through the public literal API.
testEventName :: EventName
testEventName =
  eventNameLiteral @"ragscope.test.event"
