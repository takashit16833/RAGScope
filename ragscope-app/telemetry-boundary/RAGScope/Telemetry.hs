-- | RAGScope内部処理が依存するTelemetry境界のルートモジュール。
--
-- OpenTelemetry SDKの型やAPIを公開境界へ持ち込まず、
-- Telemetryを利用する処理をSDK固有の実装から分離する。
module RAGScope.Telemetry () where
