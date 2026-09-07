---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 共通エラーと構造化ログによる実行追跡]]"
---
# RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する

## 目的

RAGScopeアプリケーションで、[Observability設計](../../../../design/observability/README.md)に従ってTrace、Logs、Metricsを利用できるOpenTelemetryの最小基盤を実装する。

UseCaseや内部処理をOpenTelemetry SDKへ直接依存させず、RAGScope側のTelemetry利用境界と、その外側でSDKへ接続するAdapterを設ける。SDK初期化、Context、Processor / Exporter、flush / shutdownなど、後続機能が共通して必要とする実装だけをこのTicketで整える。

## 前提

- [RS-0023](<./RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する.md>)が完了している
- [ADR-0006](<../../../../adr/ADR-0006 OpenTelemetryをObservabilityの共通基盤とし、Trace・Logs・Metricsの責務を分ける.md>)がacceptedである
- [Observability設計](../../../../design/observability/README.md)が現在設計として確定している

## 完了条件

### Telemetry利用境界

- [ ] UseCaseや内部処理からOpenTelemetry SDKの型やAPIを直接使用せずに、必要なSpan・LogRecord / EventRecord・Metric操作を呼び出せる境界が実装されている
- [ ] OpenTelemetry AdapterがRAGScope側の境界からSDKのAPIへ接続し、依存方向をコードとCabalの`build-depends`で確認できる
- [ ] 具体的なSDK型を、必要性なくUseCaseや内部処理の公開型へ漏出させていない

### SDKのライフサイクルとContext

- [ ] Trace、Logs、Metricsに必要なOpenTelemetry SDKをアプリケーション起動時に初期化し、終了時にflush / shutdownできる
- [ ] Processor / Exporterをproductionコードへ固定せず、ローカル実行と自動テストで必要な構成へ差し替えられる
- [ ] 現在のTrace Contextを子処理へ引き継ぎ、後続のHTTP通信境界からinjectできる状態にできる
- [ ] SDKのbatching、Context管理、Processor / Exporter、送信と同じ責務を持つRAGScope独自RuntimeやSinkを追加していない

### Span・Logs・Metrics

- [ ] RAGScope独自Spanを開始・終了し、その処理自身の最終結果に応じてStatusと`error.type`を設定できる
- [ ] OpenTelemetry LogsのEventRecordと通常のLogRecordを現在のTrace Contextに関連付けて記録できる
- [ ] OpenTelemetry Metricsを利用できるSDK構成を持ち、標準計装が提供するMetricを後続機能から利用できる
- [ ] RS-0023で定義していないRAGScope独自Metricを共通基盤として追加していない

### 失敗とException

- [ ] 具体的なUseCase / 内部処理のerror typeからTelemetryの`error.type`へ変換でき、共通`RAGScopeError`、`ErrorType`、`ErrorClassifier`を新設していない
- [ ] unexpected同期Exceptionが追跡対象から外へ伝播する場合、対応SpanをErrorとしてExceptionを再throwできる
- [ ] 同じunexpected同期ExceptionについてLogsのException EventRecordを1件だけ記録し、SDK helperが同じ事実のSpan Eventを重複生成する場合はAdapter側で抑制できる
- [ ] Telemetryの記録・export失敗だけを理由に、成功した機能処理を機能上の失敗へ変更しない
- [ ] Telemetry基盤自身の失敗を、失敗した同じTelemetry経路へ再帰的に記録しない

### 検証

- [ ] Contextの親子関係、Span Status / `error.type`、Logsとの関連付け、Exceptionの重複防止を自動テストで確認できる
- [ ] flush / shutdownと、制御されたExporter失敗時の挙動を自動テストまたは実行で確認できる
- [ ] プロジェクトで定めたRAGScopeアプリケーション側のテスト・品質検査を実行し、追加したテストを含めて成功する

## 対象外

- 個別UseCaseや文書処理、Embedding通信、DB処理に固有のSpan、EventRecord、属性の網羅的な実装
- RAGScope API / CLIでInvocation全体を追跡するroot Spanの具体的な実装が、そのインターフェース自体の実装と不可分な場合の先行実装
- AI推論サービス側のOpenTelemetry基盤
- Tempo、Loki、Prometheus、Grafanaのローカル構成
- OpenTelemetry Collectorの配置判断
- production環境のTelemetry backend、保持期間、冗長化、運用設定

## 関連文書

- [Observability設計](../../../../design/observability/Observability設計.md)
- [実行追跡設計](../../../../design/observability/実行追跡設計.md)
- [ログ・イベント設計](../../../../design/observability/ログ・イベント設計.md)
- [Metrics設計](../../../../design/observability/Metrics設計.md)
- [RS-0023](<./RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する.md>)

## 結果

> [!note] 完了時に記入
> - 実装したTelemetry利用境界とAdapter
> - 採用したOpenTelemetry packageとversion
> - SDK初期化、Processor / Exporter、flush / shutdownの構成
> - 実行したテスト・品質検査と結果
> - 後続機能へ提供する利用方法
> - 既知の制約
> - 関連Pull Request
