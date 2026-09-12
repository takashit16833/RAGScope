-- SDK-independent capabilits for recording OpenTelemetry Logs
-- from RAGScope internal processing.
--
-- This module define the values that RAGScope code may use when
-- recording ordinary diagnostic logs and named point-in-time events.
-- Conversion to OpenTelemetry SDK types and correlation with the current
-- Trace Context are responsibilities of the OhenTelemetry Adapter.
module RAGScope.Telemetry.Logs where

import Data.ByteString (ByteString)
import Data.Int (Int64)
import Data.Map.Strict (Map)
import Data.Text (Text)
import Data.Time (UTCTime)

-- | Name of a named event recorded through the RAGScope Logs boundary.
--
-- RAGScope-defined event names use the @ragscope.*@ namespace.
-- retain the name defined by that convention.
newtype EventName = EventName Text
  deriving (Eq, Show)

-- | Time when a named event occured.
--
-- 'EventNow' means that the OpenTelemetry Adapter records the current time
-- as the event timestamp.
--
-- 'EventAt' is used when the occurrence time is already know and may differ
-- from the time at which RAGScope emits the EventRecord.
data EventTimestamp
  = EventNow
  | EventAt UTCTime
  deriving (Eq, Show)

-- | Severity exposed by the RAGScope Logs boundary.
--
-- The OpenTelemetry Adapter maps these values to the corresponding
-- OpenTelemetry SeveriytyNumber.
data Severity
  = Debug
  | Info
  | Warn
  | Error
  deriving (Eq, Show)

-- | SDK-independent OpenTelemetry log value.
--
-- This value space can be used for an ordinary log body and for
-- LogRecord or EventRecord attribute.
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

-- | Attributes attached to one log or event occurrence.
type LogAttributes = Map Text LogValue

-- | Ordinary diagnostic LogRecord without a named event identity.
data LogRecord = LogRecord
  { logTimeStamp :: Maybe UTCTime
  -- ^ Time when the logged occurrence happend at its source.
  --
  -- 'Nothing' means that RAGScope does not provide an explicit source
  -- timestamp. The OpenTelemetry SDK still records its observed timestamp.
  , logSeverity :: Severity
  -- ^ Severity assigned to this diagnostic log.
  , logBody :: LogValue
  -- ^ Body of this diagnostic log.
  , logAttributes :: LogAttributes
  -- ^ Structured information associated with this occurrence.
  }
  deriving (Eq, Show)

-- | Named point-in-time event.
--
-- Feature-specific code determines when the event is recorded and defines
-- its name, timestamp semantics, severity, and attributes
data EventRecord = EventRecord
  { eventName :: EventName
  -- ^ Stable name identifying the event structure.
  , eventTimestamp :: EventTimestamp
  -- ^ Time when this event occured.
  , eventSeverity :: Severity
  -- ^ Severity assigned to this event.
  , eventAttributes :: LogAttributes
  -- ^ Structured information associated with this occurrence.
  }
  deriving (Eq, Show)

-- | Concrete implementation for recording an ordinary 'LogRecord'.
type LogRecordEmmitter =
  LogRecord ->
  IO ()

-- | Concrete implementation for recording a named 'EventRecord'.
type EventRecordEmmitter =
  EventRecord ->
  IO ()

-- | SDK-independent copobility for recording ordinary logs and named events.
data LogsBoundary
  = LogsBoundary
      LogRecordEmmitter
      EventRecordEmmitter

-- | Build a 'LogBoundary' from its concrete implementations.
mkLogsBoundary ::
  LogRecordEmmitter ->
  EventRecordEmmitter ->
  LogsBoundary
mkLogsBoundary =
  LogsBoundary

-- | Record an ordinary diagnostic 'LogRecord'.
emitLogRecord ::
  LogsBoundary ->
  LogRecord ->
  IO ()
emitLogRecord (LogsBoundary emit _) =
  emit

-- | Record a named 'EventRecord'.
emitEventRecord ::
  LogsBoundary ->
  EventRecord ->
  IO ()
emitEventRecord (LogsBoundary _ emit) =
  emit
