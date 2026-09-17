module RAGScope.Telemetry.OpenTelemetryLifecycleSpec (spec) where

import Control.Exception (
  AsyncException (UserInterrupt),
  throwIO,
  try,
 )
import Data.Either (
  isLeft,
  isRight,
 )
import Data.IORef (
  IORef,
  modifyIORef',
  newIORef,
  readIORef,
 )
import Data.Maybe (isJust)
import Test.Hspec (
  Spec,
  describe,
  it,
  shouldBe,
  shouldReturn,
 )

import RAGScope.Telemetry.OpenTelemetry.Construction (
  CleanupOutcome (..),
  CleanupResult (..),
  LifecycleReport (..),
  ProviderOperations (..),
  withProviders,
 )
import RAGScope.Telemetry.OpenTelemetryTestSupport (
  TestException (TestException),
 )

spec :: Spec
spec =
  describe "OpenTelemetry provider construction" $ do
    it "acquires in order, releases in reverse order, and reports outcomes" $ do
      events <- newIORef []
      reports <- newIORef []
      callbackCount <- newIORef (0 :: Int)

      result <-
        withProviders
          (mkOperations events)
          (\report -> do
            recordEvent events "report.publication.started"
            modifyIORef' reports (report :)
          )
          (\_ _ _ -> do
            recordEvent events "callback.started"
            modifyIORef' callbackCount (+ 1)
            pure (42 :: Int)
          )

      -- Preserve the callback's return value and invoke it exactly once.
      result `shouldBe` 42
      readIORef callbackCount `shouldReturn` 1

      -- Acquire Trace, Logs, Metrics; release in reverse order before reporting.
      readIORef events
        `shouldReturn` [ "trace.acquired"
                       , "logs.acquired"
                       , "metrics.acquired"
                       , "callback.started"
                       , "metrics.release.attempted"
                       , "logs.release.attempted"
                       , "trace.release.attempted"
                       , "report.publication.started"
                       ]

      savedReports <- readIORef reports

      -- Publish exactly one report for the complete lifecycle.
      length savedReports `shouldBe` 1

      -- Retain release outcomes in execution order, not acquisition order.
      map
        (map cleanupOutcomeName . lifecycleCleanupOutcomes)
        savedReports
        `shouldBe` [ [ "metrics.release"
                     , "logs.release"
                     , "trace.release"
                     ]
                   ]

      -- Each release callback must finish without throwing an exception.
      map
        (all (isRight . cleanupOutcomeResult) . lifecycleCleanupOutcomes)
        savedReports
        `shouldBe` [True]

      -- A successful callback must not be reported as an original exception.
      map
        (isJust . lifecycleOriginalException)
        savedReports
        `shouldBe` [False]

    it "releases Trace when Logs acquisition fails" $ do
      events <- newIORef []
      reports <- newIORef []
      callbackCount <- newIORef (0 :: Int)

      let operations =
            (mkOperations events)
              { acquireLogsProvider = \_ -> do
                  recordEvent events "logs.acquisition.started"
                  throwIO TestException
              }

      result <-
        try @TestException $
          withProviders
            operations
            (\report ->
              modifyIORef' reports (report :)
            )
            (\_ _ _ -> do
              modifyIORef' callbackCount (+ 1)
              pure ()
            )

      -- Propagate the Logs acquisition exception without running the callback.
      result `shouldBe` Left TestException
      readIORef callbackCount `shouldReturn` 0

      -- Release the acquired Trace provider; Logs and Metrics were not acquired.
      readIORef events
        `shouldReturn` [ "trace.acquired"
                       , "logs.acquisition.started"
                       , "trace.release.attempted"
                       ]

      savedReports <- readIORef reports

      -- Report only the release of the successfully acquired Trace provider.
      map
        (map cleanupOutcomeName . lifecycleCleanupOutcomes)
        savedReports
        `shouldBe` [["trace.release"]]

      -- Preserve the acquisition exception in the lifecycle report.
      map
        (isJust . lifecycleOriginalException)
        savedReports
        `shouldBe` [True]

    it "releases Logs and Trace when Metrics acquisition fails" $ do
      events <- newIORef []
      callbackCount <- newIORef (0 :: Int)

      let operations =
            (mkOperations events)
              { acquireMetricsProvider = \_ -> do
                  recordEvent events "metrics.acquisition.started"
                  throwIO TestException
              }

      result <-
        try @TestException $
          withProviders
            operations
            (\_ -> pure ())
            (\_ _ _ -> do
              modifyIORef' callbackCount (+ 1)
              pure ()
            )

      -- Propagate the Metrics acquisition exception without running the callback.
      result `shouldBe` Left TestException
      readIORef callbackCount `shouldReturn` 0

      -- Roll back Logs and Trace in reverse order; Metrics was not acquired.
      readIORef events
        `shouldReturn` [ "trace.acquired"
                       , "logs.acquired"
                       , "metrics.acquisition.started"
                       , "logs.release.attempted"
                       , "trace.release.attempted"
                       ]

    it "continues releasing other providers after a release exception" $ do
      events <- newIORef []
      reports <- newIORef []

      let operations =
            (mkOperations events)
              { releaseLogsProvider = \_ _ -> do
                  recordEvent events "logs.release.attempted"
                  throwIO TestException
              }

      result <-
        withProviders
          operations
          (\report ->
            modifyIORef' reports (report :)
          )
          (\_ _ _ -> pure (42 :: Int))

      -- A synchronous cleanup exception must not replace a successful result.
      result `shouldBe` 42

      -- Continue to release Trace even though releasing Logs threw an exception.
      readIORef events
        `shouldReturn` [ "trace.acquired"
                       , "logs.acquired"
                       , "metrics.acquired"
                       , "metrics.release.attempted"
                       , "logs.release.attempted"
                       , "trace.release.attempted"
                       ]

      savedReports <- readIORef reports

      -- Record only the Logs release as exceptional, preserving outcome order.
      map
        (map (isLeft . cleanupOutcomeResult) . lifecycleCleanupOutcomes)
        savedReports
        `shouldBe` [[False, True, False]]

    it "prioritizes a cleanup interruption over an original synchronous exception" $ do
      events <- newIORef []
      reports <- newIORef []

      let operations =
            (mkOperations events)
              { releaseMetricsProvider = \_ _ -> do
                  recordEvent events "metrics.release.attempted"
                  throwIO UserInterrupt
              }

      result <-
        try @AsyncException $
          withProviders
            operations
            (\report ->
              modifyIORef' reports (report :)
            )
            (\_ _ _ ->
              throwIO TestException :: IO ()
            )

      -- Prefer the cleanup interruption to the callback's synchronous exception.
      result `shouldBe` Left UserInterrupt

      -- Still attempt Logs and Trace release after the Metrics interruption.
      readIORef events
        `shouldReturn` [ "trace.acquired"
                       , "logs.acquired"
                       , "metrics.acquired"
                       , "metrics.release.attempted"
                       , "logs.release.attempted"
                       , "trace.release.attempted"
                       ]

      savedReports <- readIORef reports

      -- Retain the displaced callback exception in the report for diagnosis.
      map
        (isJust . lifecycleOriginalException)
        savedReports
        `shouldBe` [True]

      -- Record the Metrics interruption without marking other releases as failed.
      map
        (map (isLeft . cleanupOutcomeResult) . lifecycleCleanupOutcomes)
        savedReports
        `shouldBe` [[True, False, False]]

    it "preserves an application-level Left as a normal result" $ do
      events <- newIORef []

      result <-
        withProviders
          (mkOperations events)
          (\_ -> pure ())
          (\_ _ _ ->
            pure (Left "feature-failed" :: Either String ())
          )

      -- A returned Left is an application value, not an exception to replace.
      result `shouldBe` Left "feature-failed"

    it "does not replace a successful result with a reporter exception" $ do
      events <- newIORef []

      -- Ignore a synchronous reporting exception and return the callback value.
      withProviders
        (mkOperations events)
        (\_ -> throwIO TestException)
        (\_ _ _ -> pure (42 :: Int))
        `shouldReturn` 42

    it "retains recorded partial-acquisition rollback outcomes" $ do
      events <- newIORef []
      reports <- newIORef []

      let operations =
            (mkOperations events)
              { acquireMetricsProvider = \record -> do
                  recordEvent events "metrics.acquisition.started"

                  -- Simulate a rollback attempt and its completed outcome during acquisition.
                  recordEvent events "metrics.exporter.rollback.attempted"

                  record $
                    CleanupOutcome
                      "metrics.exporter.rollback"
                      (Right CleanupCompleted)

                  throwIO TestException
              }

      result <-
        try @TestException $
          withProviders
            operations
            (\report ->
              modifyIORef' reports (report :)
            )
            (\_ _ _ -> pure ())

      -- Propagate the original Metrics acquisition failure after rollback.
      result `shouldBe` Left TestException

      -- Roll back the internal Metrics resource, then release Logs and Trace.
      readIORef events
        `shouldReturn` [ "trace.acquired"
                       , "logs.acquired"
                       , "metrics.acquisition.started"
                       , "metrics.exporter.rollback.attempted"
                       , "logs.release.attempted"
                       , "trace.release.attempted"
                       ]

      savedReports <- readIORef reports

      -- Include the partial-acquisition rollback before outer release outcomes.
      map
        (map cleanupOutcomeName . lifecycleCleanupOutcomes)
        savedReports
        `shouldBe` [ [ "metrics.exporter.rollback"
                     , "logs.release"
                     , "trace.release"
                     ]
                   ]

-- | Record an in-memory test event in execution order; no telemetry is emitted.
recordEvent :: IORef [String] -> String -> IO ()
recordEvent events name =
  modifyIORef' events (<> [name])

-- | Create three test-only provider operations.
--
-- Each resource is (); the labels track execution, not OpenTelemetry events.
mkOperations ::
  IORef [String] ->
  ProviderOperations () () ()
mkOperations events =
  ProviderOperations
    { acquireTraceProvider = \_ ->
        recordEvent events "trace.acquired"
    , releaseTraceProvider = \_ _ ->
        recordEvent events "trace.release.attempted"
    , acquireLogsProvider = \_ ->
        recordEvent events "logs.acquired"
    , releaseLogsProvider = \_ _ ->
        recordEvent events "logs.release.attempted"
    , acquireMetricsProvider = \_ ->
        recordEvent events "metrics.acquired"
    , releaseMetricsProvider = \_ _ ->
        recordEvent events "metrics.release.attempted"
    }