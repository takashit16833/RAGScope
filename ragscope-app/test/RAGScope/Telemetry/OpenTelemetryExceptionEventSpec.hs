{-# LANGUAGE OverloadedStrings #-}

-- | Integrated tests for an unhandled exception crossing nested RAGScope
-- Spans.
--
-- This module verifies the Trace behavior that exactly-once exception
-- EventRecord implementation must preserve when Trace and Logs are connetced.
module RAGScope.Telemetry.OpenTelemetryExceptionEventSpec (spec) where

import Control.Exception (throwIO, try)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.Maybe (isJust)
import OpenTelemetry.Exporter.InMemory (assertSpanNamed)
import OpenTelemetry.Trace.Core (getActiveSpan, getActiveSpanContext)
import Test.Hspec (
  Spec,
  around,
  describe,
  it,
  shouldBe,
  shouldReturn,
  shouldSatisfy,
 )

import RAGScope.Telemetry.OpenTelemetryTestSupport (TestException (TestException), assertTestExceptionSpan, withTestTraceBoundary)
import RAGScope.Telemetry.Trace (SpanName (SpanName), SpanOutcome (SpanSucceeded), withSpan)

spec :: Spec
spec =
  -- The shared fixture gives each example its own real TracerProvider and
  -- in-memory Span exporter while exposing only the RAGScope TraceBoundary
  -- needed by the test.
  around withTestTraceBoundary $
    describe "OpenTelemetry unhandled exception propagation" $ do
      it "marks every Span crossed by one unhandled synchronous exception" $
        \(traceBoundary, spansRef) -> do
          contextBefore <-
            getActiveSpanContext

          -- Preserve the Context active at the actual throw site. The later
          -- EventRecord test will use this exact SpanContext to determine
          -- which Span owns the single exception record.
          throwContextRef <-
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
                throwContext <-
                  getActiveSpan

                writeIORef
                  throwContextRef
                  throwContext

                (throwIO TestException :: IO ())

          -- The exception crosses all three Span boundaries, but Trace
          -- instrumentation must preserve the original exception value.
          result
            `shouldBe` Left TestException

          -- Unwinding every nested Span must restore the Context that existed
          -- before entering the outermost Span.
          getActiveSpanContext
            `shouldReturn` contextBefore

          throwContext <-
            readIORef throwContextRef

          -- The throw must have happened with a real Span current. This saved
          -- SpanContext becomes the correlation reference when Logs are added
          -- to this integration test.
          throwContext
            `shouldSatisfy` isJust

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

          -- One exception escapes all three scopes. Each Span therefore owns
          -- its own Status/error.type representation, while the future Logs
          -- representation must still be emitted only once.
          mapM_
            assertTestExceptionSpan
            [ internalSpan
            , useCaseSpan
            , rootSpan
            ]
