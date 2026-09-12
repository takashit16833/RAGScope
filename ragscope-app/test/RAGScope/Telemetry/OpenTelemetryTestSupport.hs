{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-name-shadowing #-}

module RAGScope.Telemetry.OpenTelemetryTestSupport (
  TestException (..),
  testExceptionTypeAttribute,
  assertNoErrorType,
  spanEventCount,
) where

import Control.Exception (Exception)
import Data.IORef (readIORef)
import OpenTelemetry.Attributes (
  Attribute (AttributeValue),
  PrimitiveAttribute (TextAttribute),
  lookupAttribute,
 )
import OpenTelemetry.Trace.Core (
  ImmutableSpan (spanHot),
  SpanHot (hotAttributes, hotEvents),
 )
import OpenTelemetry.Util (appendOnlyBoundedCollectionValues)
import Test.Hspec (shouldBe)

-- A small test-only exception keeps the assertion independent of IOException
-- formatting and lets us verify that the original exception value is rethrown.
data TestException = TestException deriving (Eq, Show)

instance Exception TestException

-- Expected OpenTelemetry representation of our test exception type.
testExceptionTypeAttribute :: Attribute
testExceptionTypeAttribute =
  AttributeValue $ TextAttribute "TestException"

-- Verify absence rather than only checking Status.
-- A successful Span must not accidentally retain an error.type attribute.
assertNoErrorType :: ImmutableSpan -> IO ()
assertNoErrorType span = do
  hot <- readIORef $ spanHot span

  lookupAttribute (hotAttributes hot) "error.type"
    `shouldBe` Nothing

-- Span events are stored in hs-opentelemetry's bounded collection.
-- For these characterization tests, only the number of recorded events matters.
spanEventCount :: ImmutableSpan -> IO Int
spanEventCount span = do
  hot <- readIORef $ spanHot span

  pure $
    length $
      appendOnlyBoundedCollectionValues $
        hotEvents hot
