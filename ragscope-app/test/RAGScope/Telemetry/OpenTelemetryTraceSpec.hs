{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-name-shadowing #-}

module RAGScope.Telemetry.OpenTelemetryTraceSpec (spec) where

import Control.Exception (
  AsyncException (UserInterrupt),
  throwIO,
  try,
 )
import Data.IORef (
  modifyIORef',
  newIORef,
  readIORef,
 )
import Data.Maybe (isJust)
import OpenTelemetry.Attributes (
  Attribute (AttributeValue),
  PrimitiveAttribute (TextAttribute),
 )
import OpenTelemetry.Exporter.InMemory (
  assertSpanAttribute,
  assertSpanNamed,
  assertSpanStatus,
 )
import OpenTelemetry.Trace.Core (
  ImmutableSpan (spanParent),
  SpanStatus (Error, Unset),
  getActiveSpanContext,
  getSpanContext,
 )
import Test.Hspec (
  Spec,
  around,
  describe,
  it,
  shouldBe,
  shouldNotBe,
  shouldReturn,
  shouldSatisfy,
 )

import RAGScope.Telemetry.OpenTelemetryTestSupport (
  TestException (TestException),
  assertNoErrorType,
  assertTestExceptionSpan,
  spanEventCount,
  withTestTraceBoundary,
 )
import RAGScope.Telemetry.Trace (
  SpanName (SpanName),
  SpanOutcome (SpanFailed, SpanSucceeded),
  withSpan,
 )

spec :: Spec
spec =
  -- Each example gets its own TracerProvider, TraceBoundary, and
  -- in-memory Span exporter so tests cannot affect each other.
  around withTestTraceBoundary $
    describe "OpenTelemetry TraceBoundary" $ do
      it "preserves a successful result and leaves the Span unset" $
        \(traceBoundary, spansRef) -> do
          -- RAGScope code interacts only with TraceBoundary.
          -- The test does not call OpenTelemetry's inSpan'' directly.
          result <-
            withSpan
              traceBoundary
              (SpanName "success-span")
              (const SpanSucceeded)
              (pure (42 :: Int))

          -- Trace instrumentation must not change the original result.
          result `shouldBe` 42

          -- The in-memory SpanProcessor exports the Span after withSpan ends,
          -- so we can now inspect the completed ImmutableSpan.
          span <-
            assertSpanNamed
              spansRef
              "success-span"

          -- A successful RAGScope result leaves the Span at its default
          -- OpenTelemetry status and must not attach error.type.
          assertSpanStatus
            span
            Unset

          assertNoErrorType span

      it "preserves a returned failure and reflects SpanFailed on the Span" $
        \(traceBoundary, spansRef) -> do
          -- The application result and its telemetry representation are
          -- deliberately separate. The original Left remains unchanged,
          -- while the classifier describes how it should appear on the Span.
          let classify result =
                case result of
                  Left _ ->
                    SpanFailed "test_failure"
                  Right _ ->
                    SpanSucceeded

          result <-
            withSpan
              traceBoundary
              (SpanName "failure-span")
              classify
              (pure (Left "expected-failure" :: Either String ()))

          -- Span classification must not replace or transform the original
          -- application-level result.
          result
            `shouldBe` Left "expected-failure"

          span <-
            assertSpanNamed
              spansRef
              "failure-span"

          -- SpanFailed is translated by the OpenTelemetry Adapter into
          -- Status Error plus the stable error.type supplied by RAGScope.
          assertSpanStatus
            span
            (Error "")

          assertSpanAttribute
            span
            "error.type"
            testFailureTypeAttribute

      it "marks an unhandled synchronous exception and rethrows it" $
        \(traceBoundary, spansRef) -> do
          contextBefore <-
            getActiveSpanContext

          result <-
            try @TestException $
              withSpan
                traceBoundary
                (SpanName "exception-span")
                (const SpanSucceeded)
                (throwIO TestException :: IO ())

          -- Trace instrumentation must not consume or replace the exception.
          result `shouldBe` Left TestException

          -- Leaving the Span through an exception must still restore the
          -- previous active OpenTelemetry Context.
          getActiveSpanContext
            `shouldReturn` contextBefore

          span <-
            assertSpanNamed
              spansRef
              "exception-span"

          -- Shared TestException assertions verify Status Description,
          -- error.type, and suppression of the automatic exception Span Event.
          assertTestExceptionSpan span

      it "makes nested Spans current, restores their Context, and preserves the parent relationship" $
        \(traceBoundary, spansRef) -> do
          -- Capture the Context that was active before entering the outer Span.
          contextBefore <-
            getActiveSpanContext

          (parentContext, childContext) <-
            withSpan
              traceBoundary
              (SpanName "parent-span")
              (const SpanSucceeded)
              $ do
                -- The parent Span must be current while its action runs.
                parentContext <-
                  getActiveSpanContext

                childContext <-
                  withSpan
                    traceBoundary
                    (SpanName "child-span")
                    (const SpanSucceeded)
                    $ do
                      -- The nested child Span becomes current while its own
                      -- action runs.
                      childContext <-
                        getActiveSpanContext

                      -- Parent and child must represent different Spans.
                      childContext
                        `shouldNotBe` parentContext

                      pure childContext

                -- Leaving the child restores the parent Context.
                getActiveSpanContext
                  `shouldReturn` parentContext

                pure
                  ( parentContext
                  , childContext
                  )

          -- Leaving the parent restores the Context from before withSpan.
          getActiveSpanContext
            `shouldReturn` contextBefore

          -- Each body must actually have had an active Span.
          parentContext
            `shouldSatisfy` isJust

          childContext
            `shouldSatisfy` isJust

          childSpan <-
            assertSpanNamed
              spansRef
              "child-span"

          exportedParentContext <-
            traverse
              getSpanContext
              (spanParent childSpan)

          -- The exported parent relation must agree with the Context observed
          -- while the parent Span was current.
          exportedParentContext
            `shouldBe` parentContext

      it "leaves an interrupted Span unset and rethrows the asynchronous exception" $
        \(traceBoundary, spansRef) -> do
          contextBefore <-
            getActiveSpanContext

          -- UserInterrupt is treated as an intentional interruption rather
          -- than an operation failure.
          result <-
            try @AsyncException $
              withSpan
                traceBoundary
                (SpanName "interrupted-span")
                (const SpanSucceeded)
                (throwIO UserInterrupt :: IO ())

          -- Trace instrumentation must not consume or replace the interruption.
          result `shouldBe` Left UserInterrupt

          -- Leaving the Span through an interruption must still restore the
          -- previous active OpenTelemetry Context.
          getActiveSpanContext
            `shouldReturn` contextBefore

          span <-
            assertSpanNamed
              spansRef
              "interrupted-span"

          -- An intentional interruption must not be represented as a Span error.
          assertSpanStatus
            span
            Unset

          assertNoErrorType span

          -- hs-opentelemetry must not automatically record an exception
          -- Span Event.
          spanEventCount span
            `shouldReturn` 0

      it "runs the wrapped action exactly once" $
        \(traceBoundary, _) -> do
          executionCount <-
            newIORef (0 :: Int)

          result <-
            withSpan
              traceBoundary
              (SpanName "single-execution-span")
              (const SpanSucceeded)
              $ do
                -- Trace instrumentation must not duplicate execution of the
                -- wrapped application action.
                modifyIORef'
                  executionCount
                  (+ 1)

                pure (42 :: Int)

          -- withSpan must preserve the original result.
          result `shouldBe` 42

          -- The wrapped action itself must have been evaluated exactly once.
          readIORef executionCount
            `shouldReturn` 1

-- | Expected OpenTelemetry representation of the test failure kind.
testFailureTypeAttribute :: Attribute
testFailureTypeAttribute =
  AttributeValue $
    TextAttribute "test_failure"
