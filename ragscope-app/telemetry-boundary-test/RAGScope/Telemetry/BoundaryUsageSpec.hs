{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Werror=incomplete-patterns #-}

-- | Verify that feature code can use the Telemetry boundaries without
-- importing the OpenTelemetry SDK or Adapter.
module RAGScope.Telemetry.BoundaryUsageSpec (spec) where

import Data.IORef (
  modifyIORef',
  newIORef,
  readIORef,
 )
import Data.Int (Int64)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Test.Hspec (
  Spec,
  describe,
  it,
  shouldBe,
 )

import RAGScope.Telemetry.Logs (
  EventRecord (..),
  EventTimestamp (EventNow),
  LogValue (LogInt, LogText),
  LogsBoundary,
  Severity (Error, Info),
  emitEventRecord,
  eventNameLiteral,
  eventNameText,
  mkLogsBoundary,
 )
import RAGScope.Telemetry.Trace (
  SpanName (SpanName),
  SpanOutcome (SpanFailed, SpanSucceeded),
  mkTraceBoundary,
  withSpan,
 )

-- | Example feature-specific events.
-- This is test data, not a production feature contract.
data SampleEvent
  = SampleLoaded Text Int64
  | SampleRejected Text Text

-- | Convert each feature event to its Telemetry representation.
-- The conversion has no IO or SDK dependency.
toSampleEventRecord ::
  SampleEvent ->
  EventRecord
toSampleEventRecord (SampleLoaded documentId chunkCount) =
  EventRecord
    { eventName =
        eventNameLiteral @"ragscope.test.document.loaded"
    , eventTimestamp =
        EventNow
    , eventSeverity =
        Info
    , eventAttributes =
        Map.fromList
          [ ("document.id", LogText documentId)
          , ("chunk.count", LogInt chunkCount)
          ]
    }
toSampleEventRecord (SampleRejected documentId reason) =
  EventRecord
    { eventName =
        eventNameLiteral @"ragscope.test.document.rejected"
    , eventTimestamp =
        EventNow
    , eventSeverity =
        Error
    , eventAttributes =
        Map.fromList
          [ ("document.id", LogText documentId)
          , ("reason", LogText reason)
          ]
    }

-- | Example feature-specific capability.
-- The feature does not need to receive LogsBoundary or EventRecordEmitter.
newtype SampleEventObserver
  = SampleEventObserver
  { observeSampleEvent ::
      SampleEvent -> IO ()
  }

-- | Assemble the feature capability at the boundary.
-- Capture LogsBoundary once rather than passing it through feature functions.
mkSampleEventObserver ::
  LogsBoundary ->
  SampleEventObserver
mkSampleEventObserver logsBoundary =
  SampleEventObserver
    (emitEventRecord logsBoundary . toSampleEventRecord)

spec :: Spec
spec = do
  describe "feature event mapping" $ do
    it "maps a loaded event to its complete EventRecord" $ do
      let record =
            toSampleEventRecord
              (SampleLoaded "document-1" 3)

      eventNameText (eventName record)
        `shouldBe` "ragscope.test.document.loaded"

      eventTimestamp record
        `shouldBe` EventNow

      eventSeverity record
        `shouldBe` Info

      eventAttributes record
        `shouldBe` Map.fromList
          [ ("document.id", LogText "document-1")
          , ("chunk.count", LogInt 3)
          ]

    it "maps a rejected event to its complete EventRecord" $ do
      let record =
            toSampleEventRecord
              (SampleRejected "document-2" "invalid-format")

      eventNameText (eventName record)
        `shouldBe` "ragscope.test.document.rejected"

      eventTimestamp record
        `shouldBe` EventNow

      eventSeverity record
        `shouldBe` Error

      eventAttributes record
        `shouldBe` Map.fromList
          [ ("document.id", LogText "document-2")
          , ("reason", LogText "invalid-format")
          ]

    it "keeps the event name stable when attribute values change" $ do
      let
        first =
          toSampleEventRecord
            (SampleLoaded "document-1" 3)

        second =
          toSampleEventRecord
            (SampleLoaded "document-2" 10)

      eventName first
        `shouldBe` eventName second

  describe "feature-specific observer" $ do
    it "composes the pure mapping with the injected LogsBoundary" $ do
      recordsRef <- newIORef []

      let
        logsBoundary =
          mkLogsBoundary
            (\_ -> pure ())
            (\record -> modifyIORef' recordsRef (record :))

        observer =
          mkSampleEventObserver logsBoundary

        events =
          [ SampleLoaded "document-1" 3
          , SampleRejected "document-2" "invalid-format"
          ]

      mapM_
        (observeSampleEvent observer)
        events

      recorded <- readIORef recordsRef

      reverse recorded
        `shouldBe` map toSampleEventRecord events

  describe "SDK-independent TraceBoundary" $
    it "preserves different result types and observes their final outcomes" $ do
      outcomesRef <- newIORef []
      actionCountRef <- newIORef (0 :: Int)

      let traceBoundary =
            mkTraceBoundary $
              \spanName classify action -> do
                result <- action

                modifyIORef'
                  outcomesRef
                  ((spanName, classify result) :)

                pure result

      success <-
        withSpan
          traceBoundary
          (SpanName "sample.success")
          ( either
              (const (SpanFailed "sample.failed"))
              (const SpanSucceeded)
          )
          (pure (Right 42 :: Either Text Int))

      success
        `shouldBe` Right 42

      failure <-
        withSpan
          traceBoundary
          (SpanName "sample.failure")
          ( either
              (const (SpanFailed "sample.failed"))
              (const SpanSucceeded)
          )
          ( do
              modifyIORef' actionCountRef (+ 1)
              pure (Left "invalid" :: Either Text ())
          )

      failure
        `shouldBe` Left "invalid"

      actionCount <- readIORef actionCountRef

      actionCount
        `shouldBe` 1

      outcomes <- readIORef outcomesRef

      reverse outcomes
        `shouldBe` [ (SpanName "sample.success", SpanSucceeded)
                   , (SpanName "sample.failure", SpanFailed "sample.failed")
                   ]
