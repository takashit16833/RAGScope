---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 共通エラーと構造化ログによる実行追跡]]"
---
# RS-0025 AI推論サービスへOpenTelemetry Observability最小基盤を実装する

## 目的

AI推論サービスで、[Observability設計](../../../../design/observability/README.md)に従ってTrace、Logs、Metricsを利用できるOpenTelemetryの最小基盤を実装する。

AI推論サービスのproduction Python実装がまだ存在しないため、このTicketでOpenTelemetry基盤を自動テストできる最小のPythonプロジェクト構成とテスト入口も整える。モデル、Tokenizer、Webフレームワーク固有処理より先に、Telemetry利用境界、SDK Adapter、Context、Processor / Exporter、flush / shutdownを実装する。

本Ticketは、旧共通エラー・構造化ログ契約を前提としていた[RS-0018](<./RS-0018 AI推論サービスの共通エラー・構造化ログ基盤を実装する.md>)を置き換える。

## 前提

- [RS-0023](<./RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する.md>)が完了している
- [ADR-0006](<../../../../adr/ADR-0006 OpenTelemetryをObservabilityの共通基盤とし、Trace・Logs・Metricsの責務を分ける.md>)がacceptedである

## 完了条件

### Python実装・テスト基盤

- [ ] AI推論サービスのproduction Pythonコードと自動テストを正本リポジトリで管理できる最小構成が作成されている
- [ ] モデル、Tokenizer、Webフレームワークを必要とせずOpenTelemetry基盤を自動テストできる
- [ ] Python依存packageとversionを設定・lockfileなどの正本から再現できる

### Telemetry利用境界とSDK

- [ ] 機能処理からOpenTelemetry SDKの型やAPIを必要以上に直接使用せず、Telemetry利用境界とSDK Adapterが分離されている
- [ ] Trace、Logs、Metricsに必要なSDKを初期化し、終了時にflush / shutdownできる
- [ ] Processor / Exporterをローカル実行・自動テストの構成へ差し替えられる
- [ ] 現在のTrace Contextを扱い、後続のHTTP server境界で受信Contextをextractできる能力が用意されている
- [ ] SDKと重複する独自Logging Runtime、Sink、送信queue、共有LogRecord modelを実装していない

### Span・Logs・Metricsと失敗

- [ ] RAGScope独自Spanを開始・終了し、その処理自身の最終結果に応じてStatusと`error.type`を設定できる
- [ ] EventRecordと通常のLogRecordを現在のTrace Contextに関連付けて記録できる
- [ ] 標準計装が提供するMetricを利用できるSDK構成を持ち、RS-0023で定義していない独自Metricを共通基盤として追加していない
- [ ] 具体的な機能error typeからTelemetryの`error.type`へ変換でき、共通`RAGScopeError`やObservability専用error分類を設けていない
- [ ] unexpected同期Exceptionを対応SpanへErrorとして反映し、LogsのException EventRecordを重複なく1件記録して再throwできる
- [ ] Telemetry基盤自身の失敗が機能処理の成功・失敗を置き換えず、失敗したTelemetry経路へ再帰的に記録されない

### 検証

- [ ] Context、Span、Logs、Exception、Exporter失敗、flush / shutdownの主要な正常系・異常系を自動テストで確認できる
- [ ] AI推論サービス側のプロジェクト共通テスト・品質検査入口を実行し、追加したテストを含めて成功する

## 対象外

- Webフレームワーク、HTTP endpoint、HTTP error responseの具体実装
- Embeddingモデル、Tokenizer、生成条件、モデル固有例外の変換
- 文書チャンクEmbedding生成など機能固有のSpan、EventRecord、属性
- RAGScopeアプリケーション側のOpenTelemetry基盤
- Tempo、Loki、Prometheus、Grafanaのローカル構成
- production環境のTelemetry backendと運用設定

## 関連文書

- [Observability設計](../../../../design/observability/Observability設計.md)
- [実行追跡設計](../../../../design/observability/実行追跡設計.md)
- [ログ・イベント設計](../../../../design/observability/ログ・イベント設計.md)
- [Metrics設計](../../../../design/observability/Metrics設計.md)
- [RS-0018](<./RS-0018 AI推論サービスの共通エラー・構造化ログ基盤を実装する.md>)
- [RS-0023](<./RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する.md>)

## 結果

> [!note] 完了時に記入
> - 作成したPythonプロジェクトとテスト入口
> - 実装したTelemetry利用境界とAdapter
> - 採用したOpenTelemetry packageとversion
> - SDK初期化、Processor / Exporter、flush / shutdownの構成
> - 実行したテスト・品質検査と結果
> - 既知の制約
> - 関連Pull Request
