{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-name-shadowing #-}

module RAGScope.Telemetry.OpenTelemetryBehaviorSpec (spec) where

import Control.Exception (
  catch,
  throwIO,
  try,
 )
import Data.IORef (IORef)
import OpenTelemetry.Exporter.InMemory.Assertions (
  assertSpanAttribute,
  assertSpanNamed,
  assertSpanStatus,
 )
import OpenTelemetry.Trace.Core (
  ImmutableSpan (spanParent),
  Span,
  SpanStatus (Error, Unset),
  Tracer,
  TracerOptions (tracerExceptionHandlerOptions),
  addAttribute,
  defaultSpanArguments,
  getActiveSpanContext,
  getSpanContext,
  getTracerTracerProvider,
  inSpan'',
  makeTracer,
  setStatus,
  tracerOptions,
 )
import OpenTelemetry.Trace.ExceptionHandler (
  ignoreExceptionType,
 )
import Test.Hspec (
  Spec,
  around,
  describe,
  it,
  shouldBe,
  shouldReturn,
 )

import RAGScope.Telemetry.OpenTelemetryTestSupport (
  TestException (TestException),
  assertNoErrorType,
  spanEventCount,
  testExceptionTypeAttribute,
  withTestTracerProvider,
 )

spec :: Spec
spec =
  -- Run each example with an isolated TracerProvider and in-memory
  -- SpanProcessor so examples cannot observe each other's completed Spans.
  around withTestTracer $
    describe "hs-opentelemetry inSpan''" $ do
      it "makes the created Span current while its body is running" $
        \(tracer, _) ->
          inSpan''
            tracer
            "current-span"
            defaultSpanArguments
            $ \span -> do
              expected <-
                getSpanContext span

              getActiveSpanContext
                `shouldReturn` Just expected

      it "makes the child Span current and restores the parent after the child ends" $
        \(tracer, _) ->
          inSpan''
            tracer
            "parent-span"
            defaultSpanArguments
            $ \parentSpan -> do
              parentContext <-
                getSpanContext parentSpan

              inSpan''
                tracer
                "child-span"
                defaultSpanArguments
                $ \childSpan -> do
                  childContext <-
                    getSpanContext childSpan

                  getActiveSpanContext
                    `shouldReturn` Just childContext

              getActiveSpanContext
                `shouldReturn` Just parentContext

      it "exports the child Span with the current Span as its parent" $
        \(tracer, spansRef) ->
          inSpan''
            tracer
            "parent-span"
            defaultSpanArguments
            $ \parentSpan -> do
              parentContext <-
                getSpanContext parentSpan

              inSpan''
                tracer
                "child-span"
                defaultSpanArguments
                $ \_ ->
                  pure ()

              childSpan <-
                assertSpanNamed
                  spansRef
                  "child-span"

              actualParentContext <-
                traverse
                  getSpanContext
                  (spanParent childSpan)

              actualParentContext
                `shouldBe` Just parentContext

      it "leaves a successful Span unset without error.type" $
        \(tracer, spansRef) -> do
          result <-
            inSpan''
              tracer
              "success-span"
              defaultSpanArguments
              $ \_ ->
                pure (42 :: Int)

          -- inSpan'' must preserve the value returned by the wrapped action.
          result `shouldBe` 42

          -- The in-memory SpanProcessor exports the Span only after it ends,
          -- so it can now be inspected as an ImmutableSpan.
          successSpan <-
            assertSpanNamed
              spansRef
              "success-span"

          -- A normal return does not make inSpan'' mark the Span as an error.
          assertSpanStatus
            successSpan
            Unset

          assertNoErrorType successSpan

      it "does not interpret a returned Left as a Span error" $
        \(tracer, spansRef) -> do
          result <-
            inSpan''
              tracer
              "returned-failure-span"
              defaultSpanArguments
              $ \_ ->
                pure
                  ( Left "expected-failure" ::
                      Either String ()
                  )

          -- inSpan'' does not interpret application-level return values.
          -- From the SDK's point of view, returning Left is a normal return.
          result
            `shouldBe` Left "expected-failure"

          returnedFailureSpan <-
            assertSpanNamed
              spansRef
              "returned-failure-span"

          -- Therefore RAGScope, not inSpan'', must later translate a returned
          -- application failure into Span Status Error and error.type.
          assertSpanStatus
            returnedFailureSpan
            Unset

          assertNoErrorType returnedFailureSpan

      it "marks an unhandled exception as Error, records one event, and rethrows it" $
        \(tracer, spansRef) -> do
          result <-
            try @TestException
              $ inSpan''
                tracer
                "exception-span"
                defaultSpanArguments
              $ \_ ->
                throwIO TestException :: IO ()

          -- inSpan'' must not consume the exception.
          -- The same exception is expected to escape the Span scope.
          result `shouldBe` Left TestException

          exceptionSpan <-
            assertSpanNamed
              spansRef
              "exception-span"

          -- With default exception handling, hs-opentelemetry marks the Span
          -- as Error and records one "exception" Span Event automatically.
          assertSpanStatus
            exceptionSpan
            (Error "TestException")

          assertNoErrorType exceptionSpan

          spanEventCount exceptionSpan
            `shouldReturn` 1

      it "does not add an exception event when the exception type is ignored" $
        \(tracer, spansRef) -> do
          -- Reuse the same TracerProvider and exporter, but create a Tracer
          -- whose exception handler tells inSpan'' not to record TestException.
          --
          -- This models the RAGScope Adapter design: RAGScope records the
          -- desired Status/error.type itself, while hs-opentelemetry still owns
          -- Span ending and Context restoration.
          let ignoredExceptionTracer =
                makeTracer
                  (getTracerTracerProvider tracer)
                  "ragscope-test-ignore-exception"
                  tracerOptions
                    { tracerExceptionHandlerOptions =
                        [ignoreExceptionType @TestException]
                    }

          -- Capture the Context before entering the Span so we can verify that
          -- inSpan'' restores it even when the body throws.
          contextBefore <-
            getActiveSpanContext

          result :: Either TestException () <-
            try @TestException
              $ inSpan''
                ignoredExceptionTracer
                "ignored-exception-span"
                defaultSpanArguments
              $ \span ->
                throwIO TestException
                  `catch` markTestException span

          -- The callback rethrows the original exception, and inSpan'' must
          -- propagate it after completing its Span lifecycle.
          result `shouldBe` Left TestException

          -- Ignoring automatic exception recording must not change the normal
          -- Context cleanup performed by inSpan''.
          getActiveSpanContext
            `shouldReturn` contextBefore

          exceptionSpan <-
            assertSpanNamed
              spansRef
              "ignored-exception-span"

          -- These values were written by the callback before rethrowing.
          -- They must survive ignored-exception handling in inSpan''.
          assertSpanStatus
            exceptionSpan
            (Error "marked by callback")

          assertSpanAttribute
            exceptionSpan
            "error.type"
            testExceptionTypeAttribute

          -- hs-opentelemetry must not add a duplicate exception Span Event.
          spanEventCount exceptionSpan
            `shouldReturn` 0

      it "keeps each escaping Span current while its callback handles a nested exception" $
        \(tracer, _) -> do
          result :: Either TestException () <-
            try @TestException
              $ inSpan''
                tracer
                "root-span"
                defaultSpanArguments
              $ \rootSpan ->
                inSpan''
                  tracer
                  "use-case-span"
                  defaultSpanArguments
                  ( \useCaseSpan ->
                      inSpan''
                        tracer
                        "internal-span"
                        defaultSpanArguments
                        ( \internalSpan ->
                            throwIO TestException
                              `catch` assertCurrentSpanAndRethrow internalSpan
                        )
                        `catch` assertCurrentSpanAndRethrow useCaseSpan
                  )
                  `catch` assertCurrentSpanAndRethrow rootSpan
          result
            `shouldBe` Left TestException

-- | Provide each example with a fresh Tracer built from the shared
-- TracerProvider fixture.
--
-- Tracer construction remains local because these tests deliberately exercise
-- raw hs-opentelemetry Tracer behavior rather than the RAGScope TraceBoundary.
withTestTracer ::
  ((Tracer, IORef [ImmutableSpan]) -> IO ()) ->
  IO ()
withTestTracer action =
  withTestTracerProvider $
    \(tracerProvider, spansRef) -> do
      let tracer =
            makeTracer
              tracerProvider
              "ragscope-test"
              tracerOptions

      action
        ( tracer
        , spansRef
        )

-- | Simulate the exception handling performed by the RAGScope Adapter:
-- mark the Span, attach error.type, then rethrow the same exception.
markTestException ::
  Span ->
  TestException ->
  IO result
markTestException span exception = do
  setStatus
    span
    (Error "marked by callback")

  addAttribute
    span
    "error.type"
    testExceptionTypeAttribute

  throwIO exception

-- | Verify the OpenTelemetry Context visible from a Span-local exception
-- handler, then propagate the same exception to the next outer Span.
assertCurrentSpanAndRethrow ::
  Span ->
  TestException ->
  IO result
assertCurrentSpanAndRethrow span exception = do
  expectedContext <-
    getSpanContext span

  getActiveSpanContext
    `shouldReturn` Just expectedContext

  throwIO exception
