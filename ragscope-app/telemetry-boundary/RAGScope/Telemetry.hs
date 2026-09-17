-- | Root module for the Telemetry boundary used by RAGScope's internal processing.
--
-- Keeps OpenTelemetry SDK types and APIs out of the public boundary,
-- decoupling Telemetry consumers from SDK-specific implementations.
module RAGScope.Telemetry (Telemetry (..)) where

import RAGScope.Telemetry.Logs (LogsBoundary)
import RAGScope.Telemetry.Trace (TraceBoundary)

-- | SDK-independent Telemetry capabilities assembled at startup.
--
-- Pass only the capabilities required by each use case rather than
-- passing this entire value throughout the application.
data Telemetry = Telemetry
  { telemetryTrace :: TraceBoundary
  , telemetryLogs :: LogsBoundary
  }
