# Observability設計

RAGScopeのObservabilityについて、確認したい内容ごとの正本を示す索引である。

| 文書 | 確認したいこと |
|---|---|
| [Observability設計](./Observability設計.md) | OpenTelemetryをどこまで利用し、RAGScopeとOpenTelemetryが何を担当するか |
| [実行追跡設計](./実行追跡設計.md) | 1回の呼び出しをどのTrace・Spanで追跡し、失敗をどう反映するか |
| [ログ・イベント設計](./ログ・イベント設計.md) | Span・属性・EventRecord・通常のLogRecordをどう使い分けるか |
| [Metrics設計](./Metrics設計.md) | 実験結果・Trace / Span・Metricsをどう使い分けるか |

OpenTelemetryのTrace、Span、LogRecord、EventRecord、Metric、Semantic Conventionなど一般技術用語の定義はOpenTelemetryを正本とし、RAGScope固有の意味へ読み替えない。

RAGScope全体のコンポーネント構成とローカル実行環境は[システムアーキテクチャ](../システムアーキテクチャ.md)、利用者操作とユースケース実行の境界は[ユースケース設計](../ユースケース設計.md)を参照する。
