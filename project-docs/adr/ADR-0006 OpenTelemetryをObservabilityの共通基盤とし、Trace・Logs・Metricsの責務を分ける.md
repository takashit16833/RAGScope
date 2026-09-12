---
note_type: adr
status: superseded
---
# ADR-0006 — OpenTelemetryをObservabilityの共通基盤とし、Trace・Logs・Metricsの責務を分ける

> [!note]
> 本ADRは[ADR-0009 — RAGScopeのLogs SeverityをDebug・Info・Warn・Errorに限定する](<./ADR-0009 RAGScopeのLogs SeverityをDebug・Info・Warn・Errorに限定する.md>)で置き換えられた。Severityに関する判断を変更し、それ以外の決定はADR-0009で維持している。

## 背景

ADR-0005ではOpenTelemetryのtrace・spanを実行追跡へ採用した一方、ログについてはRAGScope独自の構造化ログ契約、5段階severity、OpenTelemetryの属性名から独立した`error_type`を持つ設計を採用した。その後、RAGScope独自のLogging Runtime、LogRecord、Sink、JSON / SQLite投影を具体化すると、OpenTelemetry LogsのSDK、LogRecord、Processor / Exporter、Context連携と責務が重複することが分かった。

また、RAGScope要求では1回の実行を追跡する情報だけでなく、評価データごとの正確な性能値と、複数回の実行をまたいで観測する性能情報を区別する必要がある。TraceとLogsだけを共通設計にすると、実験結果とMetricsの役割分担が決まらない。

OpenTelemetryを単なる出力先としてRAGScope独自Observability基盤の外側へ置くのではなく、Trace・Logs・Metricsを共通基盤として利用し、RAGScopeが所有すべき処理制御、ドメイン上の結果、具体的なerror typeとの境界を決める必要がある。

## 決定

1. OpenTelemetryをRAGScopeのObservability共通基盤とし、Trace、Logs、Metricsを使用する。Traceは1回の実行内の処理関係と時間、Logsは名前付きの時点イベントと診断情報、Metricsは複数実行をまたぐ集約を担当する。評価データごとの正確な値はRAGScopeの実験結果として保持する。
2. OpenTelemetry Semantic Conventionが適用できるSpan、Event、属性、`error.type`、Metricはその定義を優先する。同じ意味を表すRAGScope独自Telemetryを重複して定義しない。
3. 処理順序、retry、timeout、fallback、成功・失敗の最終判断はRAGScopeアプリケーションが所有し、Telemetryへ委ねない。RAGScope共通の`RAGScopeError`やObservability専用error分類は設けず、具体的なUseCase / 内部処理のerror typeから利用者向け表現、実験結果、Telemetryの`error.type`へ必要な境界で直接変換する。
4. UseCaseや内部処理はOpenTelemetry SDKへ直接依存することを前提にせず、RAGScope側のTelemetry利用境界を介する。OpenTelemetry AdapterがSDKへ接続し、Context、Processor / Exporter、batching、flush / shutdown、送信をSDKへ委ねる。具体的なpackage、module、型、APIは各コンポーネントの実装を正本とする。
5. 利用インターフェースからの1回の呼び出しをInvocationとし、1 Invocationにつき独立した1 Traceを作る。APIではHTTP SERVER Span、CLIではExecutionのcallee SpanをInvocationのroot Spanとする。これらのroot Spanとは別に、Invocation全体や入力から出力までの処理を包むためだけのRAGScope独自Spanは追加しない。RAGScopeアプリケーションからAI推論サービスへは同じTrace Contextを伝播する。外部callerからAPIへ渡されたTrace ContextはInvocation Traceのparentにしない。
6. RAGScope独自の名前付きイベントはOpenTelemetry LogsのEventRecordとして記録し、RAGScope独自Span Eventは使用しない。Spanだけで同じ事実を確認できる場合や、UseCaseや内部処理が具体的なerror typeで失敗を返しただけの場合はEventRecordを重複追加しない。SeverityはOpenTelemetry SeverityNumberを使用し、RAGScope共通の固定5段階severity契約は設けない。
7. Span Statusと`error.type`は、そのSpanが表す処理自身の最終結果から決定する。retry / fallbackの途中で失敗しても最終成功した処理はErrorにせず、子Spanの失敗だけを理由に親SpanをErrorにしない。例外が処理されないままSpanの外へ伝播する場合は対応SpanをErrorとして再throwし、Logsには同じ例外を表すEventRecordを1件だけ記録する。
8. RS-0023の共通設計ではRAGScope独自Metricを定義しない。HTTP、DB、GenAIなどの標準Metricが適用できる場合に利用し、個別実行を識別する高cardinalityなIDをMetric attributesへ付与しない。
9. ローカルのTelemetry backendとしてTempo、Loki、Prometheusを使用し、Grafanaから横断して確認する。Collectorの有無と具体的な送信経路、production topology、保持期間、冗長化は、具体的な配置を実装する時点で決定する。
10. 本ADRはADR-0005の判断を置き換える。OpenTelemetryのtrace・spanによる実行追跡とTrace Context伝播という判断は維持し、RAGScope独自の構造化ログ契約、固定5段階severity、OpenTelemetryから独立した共通`error_type`契約、独自Logging Runtime / Sink / JSON外部表現を現在設計から外す。

## 検討した選択肢

### ADR-0005の論理契約を維持し、OpenTelemetry Logsを出力Adapterとして追加する

既存の`error_type`、severity、LogRecord、JSON表現を維持できる。一方、Context、LogRecord、Processor / Exporter、batching、送信などOpenTelemetry Logsと同じ責務をRAGScope側にも残し、両者の変換契約と失敗処理を継続して保守する必要があるため採用しない。

### TraceとLogsだけをOpenTelemetryへ統合し、Metricsは別途検討する

RS-0023の直接の発端であるLogging責務の重複は解消できる。一方、RAGScope要求にある正確な実験性能値と、複数回の実行をまたぐ観測値の役割分担が未決定のまま残り、後続実装でObservability全体の判断が再度必要になるため採用しない。

### OpenTelemetryを共通基盤とし、Trace・Logs・Metricsの責務を分ける

OpenTelemetryが提供するContextと各SignalのSDKを共通して利用しつつ、RAGScopeは処理制御、具体的なerror type、実験結果の意味を所有できる。Semantic Conventionを優先することで標準計装との重複も避けられ、後続機能が同じ判断基準から計装を具体化できるため採用する。

## 結果と影響

- 現在のObservability設計は[Observability設計](../design/observability/Observability設計.md)、[実行追跡設計](../design/observability/実行追跡設計.md)、[ログ・イベント設計](../design/observability/ログ・イベント設計.md)、[Metrics設計](../design/observability/Metrics設計.md)を正本とする。
- RAGScopeアプリケーションの既存Logging基盤は、OpenTelemetry SDKと責務が重なる部分を新しい最小基盤へ置き換える。AI推論サービスは旧共通ログ契約を実装せず、最初から新しいObservability設計へ従う。
- RAGScopeアプリケーションとAI推論サービスの具体的なTelemetry利用境界、Adapter、SDK初期化、設定は、それぞれの後続実装Ticketでコード・設定・テストを正本として具体化する。
- コンポーネント間の具体的なTrace Contextの通信表現は、各通信方式を実装するTicketと機械可読な契約へ置く。
- ローカルTempo / Loki / Prometheus / Grafanaの具体的な構成と送信経路は、ローカルObservability環境を実装する後続Ticketで確定する。
- ADR-0005を`superseded`へ変更する。

## 関連文書

- [RAGScope要求定義](../RAGScope要求定義.md)
- [システムアーキテクチャ](../design/システムアーキテクチャ.md)
- [Observability設計](../design/observability/Observability設計.md)
- [実行追跡設計](../design/observability/実行追跡設計.md)
- [ログ・イベント設計](../design/observability/ログ・イベント設計.md)
- [Metrics設計](../design/observability/Metrics設計.md)
- [ADR-0005 — 実行追跡をOpenTelemetryのtrace・spanで表現し、イベントを構造化ログとして記録する](<./ADR-0005 実行追跡をOpenTelemetryのtrace・spanで表現し、イベントを構造化ログとして記録する.md>)
- [RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する](<../project-management/milestones/v0.0/error-logging/RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する.md>)
