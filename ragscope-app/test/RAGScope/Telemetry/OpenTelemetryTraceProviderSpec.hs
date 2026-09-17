module RAGScope.Telemetry.OpenTelemetryTraceProviderSpec (spec) where

import Control.Exception (
  throwIO,
  try,
 )
import Data.Either (isLeft)
import Data.IORef (
  IORef,
  atomicModifyIORef',
  modifyIORef',
  newIORef,
  readIORef,
 )
import Data.Maybe (isJust)
import OpenTelemetry.Exporter.Span (
  ExportResult (Success),
  SpanExporter (..),
 )
import OpenTelemetry.Processor.Span (
  FlushResult (..),
  ShutdownResult (..),
  SpanProcessor (..),
 )
import OpenTelemetry.Trace (
  TracerProvider,
  TracerProviderOptions (..),
  emptyTracerProviderOptions,
 )
import OpenTelemetry.Trace.Id.Generator.Default (
  defaultIdGenerator,
 )
import Test.Hspec (
  Spec,
  describe,
  it,
  shouldBe,
  shouldReturn,
 )

import RAGScope.Telemetry.OpenTelemetry.Construction (
  CleanupOutcome (..),
  CleanupResult (..),
  LifecycleReport (..),
  ProviderOperations (..),
  withProviders,
 )
import RAGScope.Telemetry.OpenTelemetry.TraceProvider (
  TraceProviderConfig (..),
  acquireSdkTraceProvider,
  mkTraceProviderConfig,
  releaseSdkTraceProvider,
 )
import RAGScope.Telemetry.OpenTelemetryTestSupport (
  TestException (TestException),
 )

spec :: Spec
spec = undefined

-- | Connect a real Trace provider to the existing three-provider lifecycle.
mkOperations ::
  TraceProviderConfig ->
  ProviderOperations TracerProvider () ()
mkOperations config =
  ProviderOperations
    { acquireTraceProvider = acquireSdkTraceProvider config
    , releaseTraceProvider = releaseSdkTraceProvider
    , acquireLogsProvider = \_ -> pure ()
    , releaseLogsProvider = \_ _ -> pure ()
    , acquireMetricsProvider = \_ -> pure ()
    , releaseMetricsProvider = \_ _ -> pure ()
    }

-- | Inspect a retained SDK shutdown result.
