---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 共通エラーと構造化ログによる実行追跡]]"
---
# RS-0026 ローカルObservability環境でTrace・Logs・Metricsを確認する

## 目的

ローカル環境にTempo、Loki、Prometheus、Grafanaを構成し、RAGScopeアプリケーションとAI推論サービスがOpenTelemetryで生成したTelemetryを横断して確認できる状態にする。

[システムアーキテクチャ](../../../../design/システムアーキテクチャ.md)ではbackendの役割までを固定し、Collectorの有無やSDKからbackendまでの具体的な送信経路は固定していない。このTicketで、現在利用するOpenTelemetry SDKと各backendの具体的制約に基づき、ローカル環境の構成定義としてその経路を確定する。

## 前提

- [RS-0024](<./RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する.md>)が完了している
- [RS-0025](<./RS-0025 AI推論サービスへOpenTelemetry Observability最小基盤を実装する.md>)が完了している
- [RS-0003 AI推論サービスで文書チャンクのEmbeddingを生成する](<../embedding-storage/RS-0003 AI推論サービスで文書チャンクのEmbeddingを生成する.md>)が完了し、AI推論サービスへ実際のHTTP requestを送れるendpointが存在する
- [RS-0004 RAGScopeアプリケーションで文書チャンクのEmbeddingを取得する](<../embedding-storage/RS-0004 RAGScopeアプリケーションで文書チャンクのEmbeddingを取得する.md>)が完了し、コンポーネント境界でTrace Contextを伝播できる

## 完了条件

### ローカル構成

- [ ] Tempo、Loki、Prometheus、Grafanaをローカルで再現可能に起動できる構成定義が正本リポジトリに存在する
- [ ] RAGScopeアプリケーションとAI推論サービスからTrace、Logs、Metricsを各backendへ届ける具体的な送信経路が構成として定義されている
- [ ] OpenTelemetry Collectorを使用する場合は、その必要性と担当する受信・処理・exportの範囲が構成から確認できる
- [ ] 正常なCLI出力・HTTP応答とTelemetryの送信先を分離している

### TraceとLogsの横断確認

- [ ] 1つのInvocationから開始したTraceを、RAGScopeアプリケーションからAI推論サービスの処理まで同じTraceIdで確認できる
- [ ] RAGScopeアプリケーションとAI推論サービスで記録したLogsを対応するTrace / Spanへ関連付けて確認できる
- [ ] retryや失敗を含む代表的な実行で、Spanの親子関係と各処理自身の最終Statusが[実行追跡設計](../../../../design/observability/実行追跡設計.md)と一致する

### MetricsとGrafana

- [ ] HTTP、DB、GenAIなど実際に標準Metricを生成する計装が存在する範囲で、PrometheusからMetricを確認できる
- [ ] Metric attributesへTraceId、SpanId、文書IDなど個別実行の高cardinality IDを追加していない
- [ ] GrafanaからTempo、Loki、Prometheusを参照し、Trace、Logs、Metricsを同じローカル環境で確認できる

### 検証と手順

- [ ] ローカル構成の起動、RAGScopeの実行、Grafanaでの確認、終了までの再現手順が記載されている
- [ ] 構成ファイルの妥当性検査または実際の起動によって、追加した設定が利用可能であることを確認している

## 対象外

- production環境のCollector / backend構成
- AWS固有のTelemetry収集、保持、alarm
- production向けの可用性、冗長化、長期保持、容量設計
- RAGScope独自Metricの追加
- 個別機能の性能目標やalert thresholdの決定

## 関連文書

- [システムアーキテクチャ](../../../../design/システムアーキテクチャ.md)
- [Observability設計](../../../../design/observability/Observability設計.md)
- [実行追跡設計](../../../../design/observability/実行追跡設計.md)
- [ログ・イベント設計](../../../../design/observability/ログ・イベント設計.md)
- [Metrics設計](../../../../design/observability/Metrics設計.md)

## 結果

> [!note] 完了時に記入
> - 採用したローカルTelemetry送信経路
> - Tempo / Loki / Prometheus / Grafanaの構成
> - Trace / Logs / Metricsの確認結果
> - 再現手順と実行した検査
> - 既知の制約
> - 関連Pull Request
