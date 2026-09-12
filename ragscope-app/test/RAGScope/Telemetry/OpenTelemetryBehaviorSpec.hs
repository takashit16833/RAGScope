{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-name-shadowing #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

module RAGScope.Telemetry.OpenTelemetryBehaviorSpec (spec) where

import Control.Exception (bracket, catch, throwIO, try)
import Control.Monad (void)
import Data.IORef (IORef)
import OpenTelemetry.Attributes (
  Attribute (AttributeValue),
  PrimitiveAttribute (TextAttribute),
  lookupAttribute,
 )
import OpenTelemetry.Exporter.InMemory.Assertions (
  assertSpanAttribute,
  assertSpanNamed,
  assertSpanStatus,
 )
import OpenTelemetry.Exporter.InMemory.Span (inMemoryListExporter)
import OpenTelemetry.Trace.Core (
  ImmutableSpan (spanHot, spanParent),
  Span,
  SpanHot (hotAttributes, hotEvents),
  SpanStatus (Error, Unset),
  Tracer,
  TracerOptions (tracerExceptionHandlerOptions),
  addAttribute,
  createTracerProvider,
  defaultSpanArguments,
  emptyTracerProviderOptions,
  getActiveSpanContext,
  getSpanContext,
  getTracerTracerProvider,
  inSpan'',
  makeTracer,
  setStatus,
  shutdownTracerProvider,
  tracerOptions,
 )
import OpenTelemetry.Trace.ExceptionHandler (ignoreExceptionType)
import OpenTelemetry.Util (appendOnlyBoundedCollectionValues)
import Test.Hspec (Spec, around, describe, it, shouldBe, shouldReturn)

import RAGScope.Telemetry.OpenTelemetryTestSupport (
  TestException (TestException),
  assertNoErrorType,
  spanEventCount,
  testExceptionTypeAttribute,
 )

spec :: Spec
spec =
  -- Run each example with an isolated TracerProvider and in-memory SpanProcessor.
  around withTestTracer $
    describe "hs-opentelemetry inSpan'" $ do
      it "makes the created span current while its body is running" $
        \(tracer, _) ->
          inSpan''
            tracer
            "current-span"
            defaultSpanArguments
            $ \span -> do
              expected <- getSpanContext span

              getActiveSpanContext
                `shouldReturn` Just expected

      it "makes the child span current and restores the parent after the child ends" $ do
        \(tracer, _) ->
          inSpan''
            tracer
            "parent-span"
            defaultSpanArguments
            $ \parentSpan -> do
              parentContext <- getSpanContext parentSpan

              inSpan''
                tracer
                "child-span"
                defaultSpanArguments
                $ \childSpan -> do
                  childContext <- getSpanContext childSpan

                  getActiveSpanContext `shouldReturn` Just childContext

              getActiveSpanContext `shouldReturn` Just parentContext

      it "exports the child span with the current span as its parent" $
        \(tracer, spansRef) ->
          inSpan''
            tracer
            "parent-span"
            defaultSpanArguments
            $ \parentSpan -> do
              parentContext <- getSpanContext parentSpan

              inSpan''
                tracer
                "child-span"
                defaultSpanArguments
                $ \_ ->
                  pure ()

              childSpan <- assertSpanNamed spansRef "child-span"

              actualParentContext <-
                traverse getSpanContext (spanParent childSpan)

              actualParentContext `shouldBe` Just parentContext

      it "leaves a successful span unset without error.type" $
        \(tracer, spansRef) -> do
          result <-
            inSpan''
              tracer
              "success-span"
              defaultSpanArguments
              $ \_ ->
                pure (42 :: Int)

          -- inSpan' must preserve the value returned by the wrapped action.
          result `shouldBe` 42

          -- The in-memory SpanProccesor exports the Span only after it ends.
          -- so it can now be inspected as an ImmutableSpan.
          successSpan <- assertSpanNamed spansRef "success-span"

          -- A normal return dois not make inSpan' mark the Span as an error.
          assertSpanStatus successSpan Unset
          assertNoErrorType successSpan

      it "does not interpret a returned Left as a span error" $
        \(tracer, spansRef) -> do
          result <-
            inSpan''
              tracer
              "returned-failure-span"
              defaultSpanArguments
              $ \_ ->
                pure (Left "expected-failure" :: Either String ())

          -- isSpan' does not interpret application-level return values.
          -- From the SDK's point of view, returning Left is still a normal return.
          result `shouldBe` Left "expected-failure"

          returnedFailureSpan <-
            assertSpanNamed spansRef "returned-failure-span"

          -- Therefore RAGScope, not inSpan', must later translate a returned
          -- domain failure into Span Status Error and error.type
          assertSpanStatus returnedFailureSpan Unset
          assertNoErrorType returnedFailureSpan

      it "marks an unhandled exceptios as error, records one event, and rethrows it" $
        \(tracer, spansRef) -> do
          result <-
            try @TestException
              $ inSpan''
                tracer
                "exception-span"
                defaultSpanArguments
              $ \_ ->
                throwIO TestException :: IO ()

          -- inSpan' must not consume the exception.
          -- The same exception is expected to escape the Span scope.
          result `shouldBe` Left TestException

          exceptionSpan <- assertSpanNamed spansRef "exception-span"

          -- With the default exception handling, hs-opentelemetry marks the
          -- Span as Error and record one "exception" Span Event automatically.
          assertSpanStatus exceptionSpan (Error "TestException")
          assertNoErrorType exceptionSpan
          spanEventCount exceptionSpan `shouldReturn` 1

      it "does not add an exception event when the exception type is ignored" $
        \(tracer, spansRef) -> do
          -- Reuse the same TracerProvider and exporter, but create a Tracer
          -- whose exception handler tells inSpan' not to record TestException.
          --
          -- This models the candidate RAGScope Adapter design:
          -- RAGScope records the desired Status/error.type itself, while
          -- hs-opentelemetry still owns Span ending and Context restoration.
          let ignoredExceptionTracer =
                makeTracer
                  (getTracerTracerProvider tracer)
                  "ragscope-test-ignore-exception"
                  tracerOptions
                    { tracerExceptionHandlerOptions =
                        [ignoreExceptionType @TestException]
                    }

          -- Capture the Context before entering the Span so we can verify that
          -- inSpan' restores it even when the body throws.
          contextBefore <- getActiveSpanContext

          result <-
            try @TestException
              $ inSpan''
                ignoredExceptionTracer
                "ignored-exception-span"
                defaultSpanArguments
              $ \span ->
                throwIO TestException
                  `catch` markTestException span ::
                  IO ()

          -- The callback rethrows the original exception, and inSpan' must
          -- propagate it after completing its Span lifecycle.
          result `shouldBe` Left TestException

          -- Ignoring automatic exception recording must not change the normal
          -- Context cleanup performed by inSpan'
          getActiveSpanContext `shouldReturn` contextBefore

          exceptionSpan <-
            assertSpanNamed spansRef "ignored-exception-span"

          -- These values were written by the callbacck before rethrowing.
          -- They must survive the later ignored-exception handling in inSpan'.
          assertSpanStatus exceptionSpan (Error "marked by callback")

          assertSpanAttribute
            exceptionSpan
            "error.type"
            testExceptionTypeAttribute

          -- This is the important characterization for the candidate Adapter:
          -- hs-opettelemetry must not add a duplacate exception Span Event.
          spanEventCount exceptionSpan `shouldReturn` 0

-- Provide each example with a fresh Tracer and a reference containing
-- the ImmutableSpans exported after they end.
withTestTracer :: ((Tracer, IORef [ImmutableSpan]) -> IO ()) -> IO ()
withTestTracer action =
  -- Always shut down the TracerProvider, even when the example fails.
  bracket
    acquire
    release
    $ \(_, tracer, spansRef) ->
      action (tracer, spansRef)
 where
  acquire = do
    -- The in-memory processor captures ended Spans without requiring
    -- an external OpenTelemetry backend.
    (processor, spansRef) <- inMemoryListExporter

    tracerProvider <-
      createTracerProvider
        [processor]
        emptyTracerProviderOptions

    let tracer =
          makeTracer
            tracerProvider
            "ragscope-test"
            tracerOptions

    pure (tracerProvider, tracer, spansRef)

  release (tracerProvider, _, _) =
    void $
      shutdownTracerProvider tracerProvider Nothing

-- Simulate the exception handling that the RAGScope Adapter may perform:
-- mark the Span, attach error.type, then rethrow the same exception.
markTestException :: Span -> TestException -> IO a
markTestException span exception = do
  setStatus span $ Error "marked by callback"

  addAttribute
    span
    "error.type"
    testExceptionTypeAttribute

  throwIO exception
