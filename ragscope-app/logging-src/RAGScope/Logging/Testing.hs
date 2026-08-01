module RAGScope.Logging.Testing (
  test,
  LogEvent,
  mkLogger,
  LogLevel (Debug),
  Component (RAGScopeApp),
  EventContext (ExecutionContext),
  fixedClock,
  fixedEventIdSource,
  fixedExecutionId,
  TestEventType (..),
  emit,
  LogEvent (..),
  EventId (EventId),
  fixedUuid2,
) where

import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Data.UUID qualified as UUID
import RAGScope.Logging.Core (
  Component (RAGScopeApp),
  EventContext (ExecutionContext),
  EventId (EventId),
  EventName (EventName),
  EventSpec (level),
  ExecutionId (ExecutionId),
  LogEvent (..),
  LogLevel (Debug),
  OperationName (OperationName),
  Timestamp (Timestamp),
  ToEventSpec (toEventSpec),
  debugEventSpec,
  emptyPayload,
  failedEventSpec,
 )
import RAGScope.Logging.Runtime (
  Clock,
  EventIdSource,
  Sink,
  emit,
  mkLogger,
 )

fixedUuid1 :: UUID.UUID
fixedUuid1 = UUID.fromWords 0x12345678 0x9abcdef0 0x12345678 0x9abcdef0

fixedUuid2 :: UUID.UUID
fixedUuid2 = UUID.fromWords 0x9abcdef0 0x12345678 0x9abcdef0 0x12345678

fixedExecutionId :: ExecutionId
fixedExecutionId = ExecutionId fixedUuid1

-- | 固定のEventIdを供給する処理
fixedEventIdSource :: EventIdSource
fixedEventIdSource =
  pure $ EventId fixedUuid2

fixedTime :: UTCTime
fixedTime =
  UTCTime
    (fromGregorian 2026 8 1)
    (secondsToDiffTime (12 * 60 * 60 + 34 * 60 + 56))

-- | 固定時刻をTimestampとして供給する処理
fixedClock :: Clock
fixedClock = pure $ Timestamp fixedTime

newtype TestEventType = TestEventType String

instance ToEventSpec TestEventType where
  toEventSpec (TestEventType level) =
    case level of
      _ ->
        debugEventSpec
          (OperationName "operation")
          (EventName "event")
          emptyPayload

test :: IO [LogEvent]
test = do
  ref <- newIORef ([] :: [LogEvent])

  let
    memorySink :: Sink
    memorySink logEvent = do
      modifyIORef' ref (logEvent :)
      pure (Right ())
    logger =
      mkLogger
        Debug
        RAGScopeApp
        (ExecutionContext fixedExecutionId)
        fixedEventIdSource
        fixedClock
        memorySink

  result <- emit logger (TestEventType "debug")

  case result of
    Right () -> reverse <$> readIORef ref
    Left _ -> pure []
