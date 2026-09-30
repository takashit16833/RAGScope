---
note_type: design
---
# Observability設計

> [!abstract] この文書の役割
> RAGScopeでTrace、Logs、Metricsをどう使うかを定義する。

## 1. 基本方針

RAGScopeはOpenTelemetryをObservabilityの共通基盤として使用する。Telemetryは処理を観測するためのものであり、処理順序、retry、timeout、成功・失敗などの機能上の判断は変更しない。

| Signal | 主な用途 |
|---|---|
| Trace / Span | 1回の実行内の処理のつながり、所要時間、各処理の最終結果を確認する |
| Logs | Spanだけでは表しにくい出来事や診断情報を記録する |
| Metrics | 複数回の実行をまたいで時間、回数、分布を集約する |

実験や評価で再利用する正確な結果はTelemetryではなく、RAGScopeのドメインデータとして保存する。

## 2. Trace

RAGScope APIではHTTPリクエストごと、RAGScope CLIではコマンド実行ごとに独立したTraceを開始する。APIはHTTP server Span、CLIはExecution callee Spanをroot Spanとする。

UseCaseや外部依存への呼び出しは、必要に応じて子Spanとして追跡する。HTTP、DB、GenAIなどOpenTelemetry Semantic Conventionが適用できる処理では標準のSpan、属性、Metricを優先する。

RAGScopeアプリケーションからAI推論サービスへ処理を依頼するときはTrace Contextを伝播し、同じTraceとして追跡できるようにする。

Spanの成功・失敗は、そのSpanが表す処理自身の最終結果で決める。retryやfallbackで回復した子処理の失敗だけを理由に、親Spanを失敗にはしない。

## 3. Logs

RAGScope独自の名前付きイベントはOpenTelemetry LogsのEventRecordとして記録する。独自のSpan Eventは使用しない。

Spanの開始・終了・Status・属性だけで確認できる事実は、同じ内容をLogへ重複して記録しない。名前を付けて検索・集計する必要がある出来事だけをEventRecordとし、それ以外の診断情報は通常のLogRecordとして扱う。

Severityは`Debug`、`Info`、`Warn`、`Error`の4段階とする。

## 4. Metrics

標準のOpenTelemetry Metricが適用できる場合はそれを使用する。実験ID、文書ID、TraceIdなど、実行ごとに値が増える識別子をMetric attributesへ入れない。

1回の実行の正確な値はTraceやドメインデータで確認し、Metricsから復元することを前提にしない。

## 5. 失敗の観測

処理の最終結果が失敗した場合、必要に応じてSpan Statusや`error.type`へ反映する。`error.type`にはIDやメッセージなど実行ごとに変わる値を含めず、同じ種類の失敗は同じ値で表す。

Telemetry用の表現は元の失敗を置き換えない。RAGScopeアプリケーションでの失敗の扱いは[システムアーキテクチャ](../システムアーキテクチャ.md)を正本とする。

Telemetryの記録や送信が失敗しても、それだけを理由に成功した機能処理を失敗へ変更しない。

## 6. ローカル環境

ローカル環境では次を使用する。

- Trace: Tempo
- Logs: Loki
- Metrics: Prometheus
- 可視化: Grafana

Collectorの有無、送信protocol、production環境のbackendなどの配置・運用詳細は、この設計では固定しない。

## 関連文書

- [システムアーキテクチャ](../システムアーキテクチャ.md)
- [ユースケース設計](../ユースケース設計.md)
- [RAGScope要求定義](../../RAGScope要求定義.md)
- [ADR-0006 — OpenTelemetryをObservabilityの共通基盤とし、Trace・Logs・Metricsの責務を分ける](<../../adr/ADR-0006 OpenTelemetryをObservabilityの共通基盤とし、Trace・Logs・Metricsの責務を分ける.md>)
- [ADR-0009 — RAGScopeのLogs SeverityをDebug・Info・Warn・Errorに限定する](<../../adr/ADR-0009 RAGScopeのLogs SeverityをDebug・Info・Warn・Errorに限定する.md>)
- [ADR-0010 — RAGScopeアプリケーションの失敗を処理単位の具体型で扱う](<../../adr/ADR-0010 RAGScopeアプリケーションの失敗を処理単位の具体型で扱う.md>)
