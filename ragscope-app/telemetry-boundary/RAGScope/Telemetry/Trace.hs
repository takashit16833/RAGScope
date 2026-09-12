module RAGScope.Telemetry.Trace (
  TraceBoundary,
  SpanName (..),
  SpanOutcome (..),
  mkTraceBoundary,
  withSpan,
  SpanRunner,
) where

import Data.Text (Text)

-- | Name of a Span created through the RAGScope Trace boundary.
newtype SpanName = SpanName Text
  deriving (Eq, Show)

-- | How the final result of an RAGScope operation should be represented
-- on its Span.
--
-- This does not replace the original operation result.
-- It only tells the Trace implementation how to reflect that result
-- in telemetry.
data SpanOutcome
  = SpanSucceeded
  | SpanFailed Text
  deriving (Eq, Show)

-- | A polymorphic furction for running an IO action inside a Span.
--
-- One SpanRunner value can wrap actions returning any result type.
-- The classifier maps returned result to the telemetry-only SpanOutcome,
-- while the original result is preserved and returned unchanged.
type SpanRunner =
  forall result.
  SpanName ->
  (result -> SpanOutcome) ->
  IO result ->
  IO result

-- | SDK-independent capability for running an IO action inside a Span.
--
-- The implementation is polymorphic in the action result, so one
-- TraceBoundary value can wrap actions returning any result type.
newtype TraceBoundary = TraceBoundary SpanRunner

-- | Build a TraceBoundary from its concrete implementation.
mkTraceBoundary :: SpanRunner -> TraceBoundary
mkTraceBoundary = TraceBoundary

-- | Run an action inside a Span through the configured Trace implementation.
withSpan :: TraceBoundary -> SpanRunner
withSpan (TraceBoundary run) = run
