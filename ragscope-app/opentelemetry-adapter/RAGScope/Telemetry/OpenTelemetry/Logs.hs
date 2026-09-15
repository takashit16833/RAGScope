{-# LANGUAGE OverloadedStrings #-}

-- | OpenTelemetry Adapter for the RAGScope Logs boundary.
--
-- This module converts SDK-independent RAGScope 'Logs.LogRecord' and
-- 'Logs.EventRecord' values to OpenTelemetry LogRecords. Trace correlation is
-- delegated to OpenTelemetry by using the current Context when each record is
-- emitted.
--
-- Converted 'Logs.EventRecord' values carry the OpenTelemetry LogRecord event
-- name, while converted 'Logs.LogRecord' values do not.
module RAGScope.Telemetry.OpenTelemetry.Logs (mkOpenTelemetryLogsBoundary) where

import Control.Monad (void)
import Data.HashMap.Strict (HashMap)
import Data.HashMap.Strict qualified as HashMap
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Time (UTCTime)
import Data.Time.Clock.System (
  SystemTime (MkSystemTime),
  getSystemTime,
  utcToSystemTime,
 )
import OpenTelemetry.Common (Timestamp, mkTimestamp)
import OpenTelemetry.Log.Core (
  AnyValue,
  LogRecordArguments (..),
  Logger,
  LoggerProvider,
  SeverityNumber,
 )
import OpenTelemetry.Log.Core qualified as OpenTelemetry

import RAGScope.Telemetry.Logs qualified as Logs

-- | Build the ROGScope Logs boundary backed by OpenTelemetry.
mkOpenTelemetryLogsBoundary ::
  LoggerProvider ->
  Logs.LogsBoundary
mkOpenTelemetryLogsBoundary loggerProvider =
  Logs.mkLogsBoundary
    (emitOpenTelemetryLogRecord logger)
    (emitOpenTelemetryEventRecord logger)
 where
  logger =
    OpenTelemetry.makeLogger
      loggerProvider
      "ragscope"

-- | Record 'LogRecord' through OpenTelemetry.
emitOpenTelemetryLogRecord ::
  Logger ->
  Logs.LogRecord ->
  IO ()
emitOpenTelemetryLogRecord logger record = do
  void $
    OpenTelemetry.emitLogRecord
      logger
      (toOpenTelemetryLogRecordArguments record)

-- | Record 'EventRecord' through OpenTelemetry.
emitOpenTelemetryEventRecord ::
  Logger ->
  Logs.EventRecord ->
  IO ()
emitOpenTelemetryEventRecord logger record = do
  arguments <-
    toOpenTelemetryEventRecordArguments record

  void $
    OpenTelemetry.emitLogRecord
      logger
      arguments

-- | Convert 'LogRecord' to OpenTelemetry arguments.
toOpenTelemetryLogRecordArguments ::
  Logs.LogRecord ->
  LogRecordArguments
toOpenTelemetryLogRecordArguments record =
  LogRecordArguments
    { timestamp =
        toOpenTelemetryTimestamp <$> Logs.logTimestamp record
    , observedTimestamp = Nothing
    , context = Nothing
    , severityText = Nothing
    , severityNumber =
        Just $
          toOpenTelemetrySeverity $
            Logs.logSeverity record
    , body =
        toOpenTelemetryLogValue $
          Logs.logBody record
    , attributes =
        toOpenTelemetryAttributes $
          Logs.logAttributes record
    , eventName = Nothing
    }

-- | Convert 'EventRecord' to OpenTelemetry arguments.
toOpenTelemetryEventRecordArguments ::
  Logs.EventRecord ->
  IO LogRecordArguments
toOpenTelemetryEventRecordArguments record = do
  eventTimestamp <-
    resolveEventTimestamp $
      Logs.eventTimestamp record

  pure
    LogRecordArguments
      { timestamp = Just eventTimestamp
      , observedTimestamp = Nothing
      , context = Nothing
      , severityText = Nothing
      , severityNumber =
          Just $
            toOpenTelemetrySeverity $
              Logs.eventSeverity record
      , body = OpenTelemetry.NullValue
      , attributes =
          toOpenTelemetryAttributes $
            Logs.eventAttributes record
      , eventName =
          Just $
            Logs.eventNameText $
              Logs.eventName record
      }

-- | Resolve the occurence time of 'EventRecord'.
resolveEventTimestamp ::
  Logs.EventTimestamp ->
  IO Timestamp
resolveEventTimestamp Logs.EventNow =
  systemTimeToOpenTelemetryTimestamp <$> getSystemTime
resolveEventTimestamp (Logs.EventAt timestamp) =
  pure $
    toOpenTelemetryTimestamp timestamp

-- | Convert a RAGScope timestamp to an OpenTelemetry timestamp.
toOpenTelemetryTimestamp ::
  UTCTime ->
  Timestamp
toOpenTelemetryTimestamp timestamp =
  systemTimeToOpenTelemetryTimestamp $
    utcToSystemTime timestamp

systemTimeToOpenTelemetryTimestamp ::
  SystemTime ->
  Timestamp
systemTimeToOpenTelemetryTimestamp (MkSystemTime seconds nanoseconds) =
  mkTimestamp
    (fromIntegral seconds)
    (fromIntegral nanoseconds)

-- | Map the RAGScope severity to its OpenTelemetry severity range base.
toOpenTelemetrySeverity ::
  Logs.Severity ->
  SeverityNumber
toOpenTelemetrySeverity Logs.Debug =
  OpenTelemetry.Debug
toOpenTelemetrySeverity Logs.Info =
  OpenTelemetry.Info
toOpenTelemetrySeverity Logs.Warn =
  OpenTelemetry.Warn
toOpenTelemetrySeverity Logs.Error =
  OpenTelemetry.Error

-- | Convert an SDK-independent RAGScope log value to OpenTelemetry AnyValue.
toOpenTelemetryLogValue ::
  Logs.LogValue ->
  AnyValue
toOpenTelemetryLogValue (Logs.LogText value) =
  OpenTelemetry.TextValue value
toOpenTelemetryLogValue (Logs.LogBool value) =
  OpenTelemetry.BoolValue value
toOpenTelemetryLogValue (Logs.LogDouble value) =
  OpenTelemetry.DoubleValue value
toOpenTelemetryLogValue (Logs.LogInt value) =
  OpenTelemetry.IntValue value
toOpenTelemetryLogValue (Logs.LogBytes value) =
  OpenTelemetry.ByteStringValue value
toOpenTelemetryLogValue (Logs.LogArray values) =
  OpenTelemetry.ArrayValue $
    fmap toOpenTelemetryLogValue values
toOpenTelemetryLogValue (Logs.LogObject values) =
  OpenTelemetry.HashMapValue $
    toOpenTelemetryAttributes values
toOpenTelemetryLogValue Logs.LogNull =
  OpenTelemetry.NullValue

-- | Convert RAGScope log attributes to OpenTelemetry attributes.
toOpenTelemetryAttributes ::
  Logs.LogAttributes ->
  HashMap Text AnyValue
toOpenTelemetryAttributes attributes =
  HashMap.fromList
    [ (name, toOpenTelemetryLogValue value)
    | (name, value) <- Map.toList attributes
    ]
