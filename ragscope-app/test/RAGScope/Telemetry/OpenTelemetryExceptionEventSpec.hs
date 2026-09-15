{-# LANGUAGE OverloadedStrings #-}

-- | Integrated tests for exception EventRecords crossing RAGScope Span
-- boundaries.
--
-- These tests verify that one synchronous exception can mark every Span it
-- escapes while producing exactly one Logs EventRecord correlated with the
-- first escaped Span.
module RAGScope.Telemetry.OpenTelemetryExceptionEventSpec (spec) where

import Control.Exception (
  catch,
  throwIO,
  try,
 )
import Data.IORef (
  IORef,
  newIORef,
  readIORef,
  writeIORef,
 )
import OpenTelemetry.Exporter.InMemory.Assertions (
  assertSpanNamed,
  assertSpanStatus,
 )
import OpenTelemetry.Internal.Log.Types (
  ImmutableLogRecord (logRecordEventName),
  LoggerProvider,
  ReadableLogRecord,
  toBaseMaybe,
 )
import OpenTelemetry.Trace.Core (
  ImmutableSpan,
  SpanContext,
  SpanStatus (Unset),
  getActiveSpanContext,
 )
import Test.Hspec (
  Spec,
  around,
  describe,
  expectationFailure,
  it,
  shouldBe,
  shouldReturn,
 )

import RAGScope.Telemetry.Logs (
  emitEventRecord,
 )
import RAGScope.Telemetry.OpenTelemetry.Logs (
  mkOpenTelemetryLogsBoundary,
 )
import RAGScope.Telemetry.OpenTelemetry.Trace (
  mkOpenTelemetryTraceBoundary,
 )
import RAGScope.Telemetry.OpenTelemetryTestSupport (
  TestException (TestException),
  assertNoErrorType,
  assertSingleExportedLogRecord,
  assertTestExceptionSpan,
  assertTracingDetails,
  withTestLoggerProvider,
  withTestTracerProvider,
 )
import RAGScope.Telemetry.Trace (
  SpanName (SpanName),
  SpanOutcome (SpanSucceeded),
  TraceBoundary,
  withSpan,
 )

type TestExceptionEventEnvironment =
  ( TraceBoundary
  , IORef [ImmutableSpan]
  , LoggerProvider
  , IORef [ReadableLogRecord]
  )

spec :: Spec
spec =
  around withTestExceptionEventEnvironment $
    describe "OpenTelemetry exception EventRecord" $ do
      it "records one EventRecord on the first Span escaped by an unhandled exception" $
        \(traceBoundary, spansRef, loggerProvider, logRecordsRef) -> do
          contextBefore <-
            getActiveSpanContext

          ownerContextRef <-
            newIORef Nothing

          result <-
            try @TestException
              $ withSpan
                traceBoundary
                (SpanName "root-span")
                (const SpanSucceeded)
              $ withSpan
                traceBoundary
                (SpanName "use-case-span")
                (const SpanSucceeded)
              $ withSpan
                traceBoundary
                (SpanName "internal-span")
                (const SpanSucceeded)
              $ do
                ownerContext <-
                  getActiveSpanContext

                writeIORef
                  ownerContextRef
                  ownerContext

                (throwIO TestException :: IO ())

          -- Telemetry must not replace or consume the application exception.
          result
            `shouldBe` Left TestException

          -- All nested Span scopes must restore the Context that was active
          -- before entering the root Span.
          getActiveSpanContext
            `shouldReturn` contextBefore

          internalSpan <-
            assertSpanNamed
              spansRef
              "internal-span"

          useCaseSpan <-
            assertSpanNamed
              spansRef
              "use-case-span"

          rootSpan <-
            assertSpanNamed
              spansRef
              "root-span"

          -- The same exception escaped all three Span boundaries, so every
          -- Span represents its own failed execution.
          mapM_
            assertTestExceptionSpan
            [ internalSpan
            , useCaseSpan
            , rootSpan
            ]

          ownerContext <-
            readIORef ownerContextRef

          -- The exception itself is represented in Logs only once. Because the
          -- first escape occurred at internal-span, that EventRecord must carry
          -- the internal Span's tracing details.
          assertSingleExceptionEvent
            loggerProvider
            logRecordsRef
            ownerContext

      it "keeps the first-escape EventRecord when an outer Span catches and recovers" $
        \(traceBoundary, spansRef, loggerProvider, logRecordsRef) -> do
          ownerContextRef <-
            newIORef Nothing

          result <-
            withSpan
              traceBoundary
              (SpanName "root-span")
              (const SpanSucceeded)
              $ withSpan
                traceBoundary
                (SpanName "use-case-span")
                (const SpanSucceeded)
              $ do
                withSpan
                  traceBoundary
                  (SpanName "internal-span")
                  (const SpanSucceeded)
                  ( do
                      ownerContext <-
                        getActiveSpanContext

                      writeIORef
                        ownerContextRef
                        ownerContext

                      throwIO TestException
                  )
                  `catch` \TestException ->
                    pure ()

          -- The application handled the exception and recovered successfully.
          result
            `shouldBe` ()

          internalSpan <-
            assertSpanNamed
              spansRef
              "internal-span"

          useCaseSpan <-
            assertSpanNamed
              spansRef
              "use-case-span"

          rootSpan <-
            assertSpanNamed
              spansRef
              "root-span"

          -- The exception escaped internal-span before application code caught
          -- it, so that Span remains an error and owns the EventRecord.
          assertTestExceptionSpan internalSpan

          -- The exception never escaped these outer Span boundaries because
          -- the UseCase application logic recovered from it.
          assertSpanStatus
            useCaseSpan
            Unset

          assertNoErrorType useCaseSpan

          assertSpanStatus
            rootSpan
            Unset

          assertNoErrorType rootSpan

          ownerContext <-
            readIORef ownerContextRef

          assertSingleExceptionEvent
            loggerProvider
            logRecordsRef
            ownerContext

-- | Build the real Trace and Logs Adapter environment used by the exception
-- integration tests.
--
-- The Trace Adapter receives only the EventRecord emission capability it needs;
-- normal LogRecord emission remains outside its dependency surface.
withTestExceptionEventEnvironment ::
  (TestExceptionEventEnvironment -> IO ()) ->
  IO ()
withTestExceptionEventEnvironment action =
  withTestTracerProvider $
    \(tracerProvider, spansRef) ->
      withTestLoggerProvider $
        \(loggerProvider, logRecordsRef) -> do
          let
            logsBoundary =
              mkOpenTelemetryLogsBoundary loggerProvider

            traceBoundary =
              mkOpenTelemetryTraceBoundary
                tracerProvider
                (emitEventRecord logsBoundary)

          action
            ( traceBoundary
            , spansRef
            , loggerProvider
            , logRecordsRef
            )

-- | Verify the single exception EventRecord and its first-escape correlation.
assertSingleExceptionEvent ::
  LoggerProvider ->
  IORef [ReadableLogRecord] ->
  Maybe SpanContext ->
  IO ()
assertSingleExceptionEvent loggerProvider logRecordsRef ownerContext =
  assertSingleExportedLogRecord
    loggerProvider
    logRecordsRef
    $ \record -> do
      -- This is the generic OpenTelemetry exception event rather than an
      -- ordinary unnamed LogRecord.
      toBaseMaybe
        (logRecordEventName record)
        `shouldBe` Just "exception"

      case ownerContext of
        Nothing ->
          expectationFailure
            "expected a SpanContext at the first exception escape"
        Just spanContext ->
          assertTracingDetails
            spanContext
            record
