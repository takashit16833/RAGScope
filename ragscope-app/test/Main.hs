module Main (main) where

import Test.Hspec (hspec)

import RAGScope.Telemetry.OpenTelemetryBehaviorSpec qualified as OpenTelemetryBehaviorSpec
import RAGScope.Telemetry.OpenTelemetryLogsSpec qualified as OpenTelemetryLogsSpec
import RAGScope.Telemetry.OpenTelemetryTraceSpec qualified as OpenTelemetryTraceSpec

main :: IO ()
main =
  hspec $ do
    OpenTelemetryBehaviorSpec.spec
    OpenTelemetryTraceSpec.spec
    OpenTelemetryLogsSpec.spec
