-- | Acquire and release an OpenTelemetry TracerProvider.
--
-- Ownership moves from the exporter to the processor, then to the provider.
-- Only the current owner is shut down during rollback.
module RAGScope.Telemetry.OpenTelemetry.TraceProvider (
  TraceProviderConfig (..),
  mkTraceProviderConfig,
  acquireSdkTraceProvider,
  releaseSdkTraceProvider,
) where

import Control.Exception (
  SomeException,
  mask,
  rethrowIO,
  tryWithContext,
 )
import Control.Monad (void)
import OpenTelemetry.Exporter.Span (
  SpanExporter (spanExporterShutdown),
 )
import OpenTelemetry.Processor.Span (
  SpanProcessor (spanProcessorShutdown),
 )
import OpenTelemetry.Trace (
  TracerProvider,
  TracerProviderOptions,
  createTracerProvider,
  forceFlushTracerProvider,
  shutdownTracerProvider,
 )

import RAGScope.Telemetry.OpenTelemetry.Cleanup (
  CleanupOutcome,
  CleanupResult (CleanupFlushResult, CleanupShutdownResult),
  attemptCleanup,
 )

-- | Factories for the three Trace acquisition stages.
--
-- A factory that throws must clean up resources acquired only within that
-- factory. Ownership of its input moves only when the factory returns.
data TraceProviderConfig = TraceProviderConfig
  { traceExporterFactory :: IO SpanExporter
  , traceProcessorFactory :: SpanExporter -> IO SpanProcessor
  , traceProviderFactory :: SpanProcessor -> IO TracerProvider
  }

-- | Connect injectable exporter and processor factories to the real SDK.
mkTraceProviderConfig ::
  IO SpanExporter ->
  (SpanExporter -> IO SpanProcessor) ->
  TracerProviderOptions ->
  TraceProviderConfig
mkTraceProviderConfig exporterFactory processorFactory options =
  TraceProviderConfig
    { traceExporterFactory = exporterFactory
    , traceProcessorFactory = processorFactory
    , traceProviderFactory = \processor ->
        createTracerProvider [processor] options
    }

-- | Acquire the SDK provider and roll back an incomplete acquisition.
acquireSdkTraceProvider ::
  TraceProviderConfig ->
  (CleanupOutcome -> IO ()) ->
  IO TracerProvider
acquireSdkTraceProvider config record =
  mask $ \restore -> do
    exporter <-
      restore $
        traceExporterFactory config

    processorResult <-
      tryWithContext @SomeException $
        restore $
          traceProcessorFactory config exporter

    case processorResult of
      Left originalException -> do
        void $
          attemptCleanup
            record
            "trace.exporter.rollback"
            (CleanupShutdownResult <$> spanExporterShutdown exporter)

        rethrowIO originalException
      Right processor -> do
        providerResult <-
          tryWithContext @SomeException $
            restore $
              traceProviderFactory config processor

        case providerResult of
          Left originalException -> do
            void $
              attemptCleanup
                record
                "trace.processor.rollback"
                (CleanupShutdownResult <$> spanProcessorShutdown processor)

            rethrowIO originalException
          Right provider ->
            pure provider

-- | Flush and shut down the provider, retaining both SDK outcomes.
--
-- The provider owns its processors. Do not separately shut down the
-- processor or exporter after a successful provider acquisition.
releaseSdkTraceProvider ::
  (CleanupOutcome -> IO ()) ->
  TracerProvider ->
  IO ()
releaseSdkTraceProvider record provider = do
  void $
    attemptCleanup
      record
      "trace.flush"
      (CleanupFlushResult <$> forceFlushTracerProvider provider Nothing)

  void $
    attemptCleanup
      record
      "trace.shutdown"
      (CleanupShutdownResult <$> shutdownTracerProvider provider Nothing)
