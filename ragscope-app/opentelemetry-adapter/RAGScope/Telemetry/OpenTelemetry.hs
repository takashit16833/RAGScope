-- | RAGScopeのTelemetry境界をOpenTelemetryへ接続するAdapterのルートモジュール。
--
-- OpenTelemetry SDKへの依存をこのAdapter側へ隔離し、
-- RAGScope内部処理へSDKの型やAPIを公開しない。
module RAGScope.Telemetry.OpenTelemetry () where
