-- | SDK-independent capability for recording OpenTelemetry Logs
-- from RAGScope internal processing.
--
-- This module defines the values that RAGScope code may use when
-- recording @LogRecord@ and @EventRecord@ values.
-- Conversion to OpenTelemetry SDK types and correlation with the current
-- Trace Context are responsibilities of the OpenTelemetry Adapter.
module RAGScope.Telemetry.Logs (
  LogsBoundary,
  LogRecord (..),
  EventRecord (..),
  EventName,
  EventNameValidationFailure (..),
  mkEventName,
  eventNameText,
  EventTimestamp (..),
  Severity (..),
  LogValue (..),
  LogAttributes,
  LogRecordEmitter,
  EventRecordEmitter,
  mkLogsBoundary,
  emitLogRecord,
  emitEventRecord,
) where

import Data.ByteString (ByteString)
import Data.Int (Int64)
import Data.Map.Strict (Map)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime)

-- | Name carried by @EventRecord@.
--
-- OpenTelemetry Semantic Convention event names may be used directly.
-- RAGScope-defined event names use the @ragscope.*@ namespace.
--
-- The constructor is intentionally hidden so that an @EventName@ always
-- contains a non-empty name.
newtype EventName = EventName Text
  deriving (Eq, Show)

-- | Reason why an @EventName@ could not be constructed.
data EventNameValidationFailure
  = EmptyEventName
  deriving (Eq, Show)

-- | Build an @EventName@.
--
-- The event name must be non-empty. The @ragscope.*@ namespace is not
-- enforced here because standard OpenTelemetry event names are also valid.
mkEventName ::
  Text ->
  Either EventNameValidationFailure EventName
mkEventName name
  | Text.null name =
      Left EmptyEventName
  | otherwise =
      Right (EventName name)

-- | Return the underlying OpenTelemetry event name.
eventNameText :: EventName -> Text
eventNameText (EventName name) =
  name

-- | Occurrence time carried by @EventRecord@.
--
-- @EventNow@ means that the OpenTelemetry Adapter records the current time
-- as the event timestamp.
--
-- @EventAt@ is used when the occurrence time is already known and may differ
-- from the time at which RAGScope emits the @EventRecord@.
data EventTimestamp
  = EventNow
  | EventAt UTCTime
  deriving (Eq, Show)

-- | Severity exposed by the RAGScope Logs boundary.
--
-- The OpenTelemetry Adapter maps these values to the corresponding
-- OpenTelemetry @SeverityNumber@.
data Severity
  = Debug
  | Info
  | Warn
  | Error
  deriving (Eq, Show)

-- | SDK-independent OpenTelemetry log value.
--
-- This value space can be used as @LogRecord@ body and for
-- @LogRecord@ or @EventRecord@ attributes.
data LogValue
  = LogText Text
  | LogBool Bool
  | LogDouble Double
  | LogInt Int64
  | LogBytes ByteString
  | LogArray [LogValue]
  | LogObject (Map Text LogValue)
  | LogNull
  deriving (Eq, Show)

-- | Attributes attached to @LogRecord@ or @EventRecord@.
type LogAttributes = Map Text LogValue

-- | RAGScope record without an event name.
data LogRecord = LogRecord
  { logTimestamp :: Maybe UTCTime
  -- ^ Time when the logged occurrence happened at its source.
  --
  -- @Nothing@ means that RAGScope does not provide an explicit source
  -- timestamp. The OpenTelemetry SDK still records its observed timestamp.
  , logSeverity :: Severity
  -- ^ Severity assigned to this @LogRecord@.
  , logBody :: LogValue
  -- ^ Body of this @LogRecord@.
  , logAttributes :: LogAttributes
  -- ^ Structured information associated with this occurrence.
  }
  deriving (Eq, Show)

-- | RAGScope record with a stable event name.
--
-- Feature-specific code determines when the @EventRecord@ is recorded and
-- defines its name, timestamp semantics, severity, and attributes.
data EventRecord = EventRecord
  { eventName :: EventName
  -- ^ Stable non-empty name identifying the @EventRecord@ structure.
  , eventTimestamp :: EventTimestamp
  -- ^ Occurrence time carried by this @EventRecord@.
  , eventSeverity :: Severity
  -- ^ Severity assigned to this @EventRecord@.
  , eventAttributes :: LogAttributes
  -- ^ Structured information associated with this occurrence.
  }
  deriving (Eq, Show)

-- | Emitter for @LogRecord@ values.
type LogRecordEmitter =
  LogRecord ->
  IO ()

-- | Emitter for @EventRecord@ values.
type EventRecordEmitter =
  EventRecord ->
  IO ()

-- | SDK-independent capability for recording @LogRecord@ and @EventRecord@.
data LogsBoundary
  = LogsBoundary
      LogRecordEmitter
      EventRecordEmitter

-- | Build a @LogsBoundary@ from its concrete implementations.
mkLogsBoundary ::
  LogRecordEmitter ->
  EventRecordEmitter ->
  LogsBoundary
mkLogsBoundary =
  LogsBoundary

-- | Record @LogRecord@.
emitLogRecord ::
  LogsBoundary ->
  LogRecord ->
  IO ()
emitLogRecord (LogsBoundary emit _) =
  emit

-- | Record @EventRecord@.
emitEventRecord ::
  LogsBoundary ->
  EventRecord ->
  IO ()
emitEventRecord (LogsBoundary _ emit) =
  emit
