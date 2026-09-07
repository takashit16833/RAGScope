---
note_type: ticket
status: done
milestone: "[[v0.0]]"
epic: "[[v0.0 共通エラーと構造化ログによる実行追跡]]"
---
# RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する

## 目的

RS-0022の設計検討で明らかになったRAGScope独自Logging Runtime、`LogRecord`、Sink、出力失敗処理とOpenTelemetry Logsの責務重複を解消し、正本リポジトリの要求とシステム構造を基準にObservability全体を再設計する。

OpenTelemetryを単なる出力AdapterではなくTrace / Logs / Metricsの共通基盤として利用し、RAGScopeが所有する処理制御、ドメイン結果、具体的なerror typeと、OpenTelemetryへ委ねるContext・SDK・Processor / Exporter・送信の境界を確定する。

## 完了条件

### 要求と追跡対象

- [x] RAGScope要求定義と現在のシステム構造から、処理の進行、失敗、実験、コンポーネント間の処理関係について、後から識別・確認する対象を特定している
- [x] RAGScopeアプリケーション、AI推論サービス、利用インターフェース、外部依存をまたぐ処理構造を基準に、Trace、Logs、Metricsが担当する範囲を決定している

### OpenTelemetryの適用範囲

- [x] Trace / Logs / Metrics、Context、SDK、Processor / Exporter、エラー処理について、RAGScopeの設計判断に必要な能力と制約を確認している
- [x] Haskell / Pythonで、後続実装に必要なTrace / Logs / Metrics / Context連携を実現できる前提を確認している
- [x] OpenTelemetryへ委ねる責務と、RAGScopeが所有する処理制御・具体的なerror type・Telemetry利用境界を決定している
- [x] OpenTelemetry Logsを採用できない必須要求または実装制約は確認されず、採用を確定している

### 実行追跡・Logs・Metricsアーキテクチャ

- [x] 1 Invocation = 1 Trace、API / CLIでInvocation全体を追跡するroot Span、UseCase Span、標準Span、Span Status、Trace Context伝播を決定している
- [x] Span、attributes、EventRecord、通常LogRecordの使い分けと、重複記録を避ける判断基準を決定している
- [x] typed failure、例外、中断・キャンセル、Telemetry基盤自身の失敗をApplication結果とTelemetryへどう反映するか決定している
- [x] 実験結果、Trace / Span、Metricsの役割を分け、RS-0023では独自Metricを定義しないことを決定している
- [x] ローカルbackendとしてTempo、Loki、Prometheus、Grafanaを使用し、Collectorの有無と具体的な送信経路はローカル配置実装へ委ねることを決定している

### これまでの設計の再評価

- [x] 共通`error_type` / `ErrorType` / `ErrorClassifier`をObservability共通契約として維持せず、具体的なerror typeからTelemetryの`error.type`へ直接変換する設計へ変更している
- [x] 型付き`Logger`、独自`LogRecord`、Logging Runtime、Sink、独自JSON / SQLite投影をOpenTelemetry Logsと並行する共通基盤として維持しないことを決定している
- [x] RAGScope独自の固定5段階severity契約を廃止し、OpenTelemetry SeverityNumberを使用することを決定している
- [x] `execution_id`をTraceと並行する共通追跡IDとして維持せず、TraceId / SpanIdで実行追跡することを決定している
- [x] 変更の影響先としてADR-0005、設計書、RS-0018、RS-0003、RS-0004、後続実装Ticketを特定して反映している

### 正本と後続作業

- [x] ADR-0006をacceptedとし、ADR-0005を`superseded`へ変更している
- [x] `design/observability/`、システムアーキテクチャ、ユースケース設計、RAGScope用語集を現在設計として整合させている
- [x] このwork branchには現在利用する構造化ログContract / Schemaが存在しないため、旧独自JSON契約を新Observability共通契約として再作成していない
- [x] RS-0024、RS-0025、RS-0026へコンポーネント最小基盤とローカル確認環境を分解し、RS-0003 / RS-0004へ実際のHTTP Trace Context伝播を割り当てている
- [x] RS-0022の未merge branchを現在仕様の正本として使用せず、採用した判断を現在branchの正本へ反映している

## 対象外

- RAGScopeアプリケーションまたはAI推論サービスのOpenTelemetry本番実装
- OpenTelemetry CollectorやTelemetry backendのproduction環境構築
- 文書処理、dense検索など個別機能の具体的なSpan、EventRecord、attributesの網羅的な定義

## 関連文書

- [RAGScope要求定義「2.3 信頼性と保守性」](<../../../../RAGScope要求定義.md#2.3 信頼性と保守性>)
- [システムアーキテクチャ](../../../../design/システムアーキテクチャ.md)
- [Observability設計](../../../../design/observability/README.md)
- [ADR-0006](<../../../../adr/ADR-0006 OpenTelemetryをObservabilityの共通基盤とし、Trace・Logs・Metricsの責務を分ける.md>)
- [RS-0022](<./RS-0022 RAGScopeアプリケーションの構造化ログ基盤を現在契約へ移行する.md>)
- [RS-0024](<./RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する.md>)
- [RS-0025](<./RS-0025 AI推論サービスへOpenTelemetry Observability最小基盤を実装する.md>)
- [RS-0026](<./RS-0026 ローカルObservability環境でTrace・Logs・Metricsを確認する.md>)

## 結果

OpenTelemetry Logsを採用し、OpenTelemetryをTrace / Logs / MetricsのObservability共通基盤とする。1つのInvocationを1つの独立Traceとして追跡し、APIではHTTP SERVER Span、CLIではExecution callee SpanをInvocationのroot Spanとする。UseCaseを呼ぶ場合だけUseCase Spanを作り、PostgreSQL、HTTP、GenAIなどはSemantic Conventionに従う標準Spanを優先する。

RAGScope独自の名前付きイベントはOpenTelemetry LogsのEventRecordとして扱い、同じ事実をSpanとEventRecordへ重複記録しない。typed failureやretry途中の失敗だけを理由にEventRecordを生成しない。例外が処理されないままSpanの外へ伝播する場合は対応SpanをErrorとして再throwし、Logsへ同じ例外を表すEventRecordを1件だけ記録する。

共通`RAGScopeError`やObservability専用の`ErrorType` / `ErrorClassifier`は設けず、具体的なUseCase / 内部処理のerror typeからAPI / CLI表現、実験結果、Telemetryの`error.type`へ必要な境界で直接変換する。旧独自Logging Runtime、Sink、共有`LogRecord`、固定5段階severity、独自JSON / SQLiteログ表現はObservability共通基盤として維持しない。

性能情報は、評価データごとの正確な値を実験結果、1回の処理内訳をTrace / Span、複数回の集約をMetricsとして扱う。RS-0023ではRAGScope独自Metricを追加せず、適用できるHTTP、DB、GenAIの標準Metricを利用する。

ローカルbackendはTempo、Loki、Prometheus、Grafanaとする。Collectorの有無と具体的な送信経路はRS-0026で現在のSDK・backend制約に基づいて構成として確定する。

後続は、RAGScopeアプリケーションの最小基盤をRS-0024、AI推論サービスの最小基盤をRS-0025、ローカル横断確認環境をRS-0026が担当する。実際のRAGScopeアプリケーション→AI推論サービスHTTP通信でのTrace Context inject / extractはRS-0004 / RS-0003へ反映した。
