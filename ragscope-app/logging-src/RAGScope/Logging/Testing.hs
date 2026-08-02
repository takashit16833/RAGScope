module RAGScope.Logging.Testing (
  LogLevel (Debug),
  Component (RAGScopeApp),
  EventContext (ExecutionContext),
  LogEvent (..),
  fixedClock,
  fixedEventIdSource,
  fixedExecutionId,
  fixedEventId,
  newMemoryLogger,
) where

import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Data.UUID qualified as UUID
import RAGScope.Logging.Core (
  Component (RAGScopeApp),
  EventContext (ExecutionContext),
  EventId (EventId),
  ExecutionId (ExecutionId),
  LogEvent (eventId),
  LogLevel (Debug),
  Timestamp (Timestamp),
 )
import RAGScope.Logging.Runtime (
  Clock,
  EventIdSource,
  Logger,
  Sink,
  mkLogger,
 )

fixedEventId :: EventId
fixedEventId =
  EventId $
    UUID.fromWords 0x9abcdef0 0x12345678 0x9abcdef0 0x12345678

fixedExecutionId :: ExecutionId
fixedExecutionId =
  ExecutionId $
    UUID.fromWords 0x12345678 0x9abcdef0 0x12345678 0x9abcdef0

-- | 固定のEventIdを供給する処理
fixedEventIdSource :: EventIdSource
fixedEventIdSource =
  pure fixedEventId

fixedTime :: UTCTime
fixedTime =
  UTCTime
    (fromGregorian 2026 8 1)
    (secondsToDiffTime (12 * 60 * 60 + 34 * 60 + 56))

-- | 固定時刻をTimestampとして供給する処理
fixedClock :: Clock
fixedClock = pure $ Timestamp fixedTime

newMemorySink :: IO (Sink, IO [LogEvent])
newMemorySink = do
  eventsRef <- newIORef []

  let
    sink :: Sink
    sink logEvent = do
      modifyIORef' eventsRef (logEvent :)
      pure (Right ())

    readEvents =
      reverse <$> readIORef eventsRef

  pure (sink, readEvents)

newMemoryLogger ::
  LogLevel ->
  Component ->
  EventContext ->
  EventIdSource ->
  Clock ->
  IO (Logger, IO [LogEvent])
newMemoryLogger minimumLevel component context eventIdSource clock = do
  (memorySink, readEvents) <- newMemorySink

  let logger =
        mkLogger
          minimumLevel
          component
          context
          eventIdSource
          clock
          memorySink

  pure (logger, readEvents)
