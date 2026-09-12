---
note_type: adr
status: accepted
---
# ADR-0009 — RAGScopeのLogs SeverityをDebug・Info・Warn・Errorに限定する

## 背景

ADR-0006では、RAGScope独自の固定5段階severity契約を廃止し、OpenTelemetry `SeverityNumber`を使用することを決定した。この判断によって、RAGScope独自のLogging RuntimeやLogRecord、SinkとOpenTelemetry Logsの責務を二重に持つ構造を避けた。

RS-0024でRAGScopeアプリケーションのSDK非依存Logs境界を具体化すると、OpenTelemetry `SeverityNumber`が持つ24段階をRAGScopeの利用側へそのまま公開する必要性は確認できなかった。現在のRAGScope要求と設計には、同じseverity range内の`Info2`、`Info3`、`Info4`のような細かな差を機能ごとに使い分ける規則がない。

24段階や1〜24の数値をそのまま選べるようにすると、同じ意味の記録でも呼び出し側ごとに異なるlevelを選べるため、Severityの意味が揃わなくなる。一方、RAGScopeが実際に区別する必要があるのは、診断用の詳細、正常な記録、注意が必要な状態、失敗の4種類である。

## 決定

1. ADR-0006の決定のうちSeverityに関する部分を変更し、それ以外の決定は維持する。
2. RAGScopeのTelemetry利用境界で扱うSeverityは、`Debug`、`Info`、`Warn`、`Error`の4段階とする。
3. `Debug`は診断や調査のための詳細情報、`Info`は正常な処理や出来事として残す情報、`Warn`は処理は継続できるが注意が必要な異常や劣化を示す情報、`Error`は失敗を示す情報として扱う。
4. OpenTelemetryの24段階の`SeverityNumber`や任意の数値をRAGScopeの利用側へ公開しない。OpenTelemetry AdapterがRAGScopeの4段階Severityを対応するOpenTelemetry `SeverityNumber`へ変換する。
5. severityを指定しない状態はSeverityとは別に扱い、`Default`というSeverityは設けない。
6. `Trace`や`Fatal`は、現在のRAGScopeでは`Debug`または`Error`と区別して扱う具体的な要求がないため設けない。将来その区別が必要になった場合は、要求と利用条件を確認したうえでSeverityへ追加する。
7. Severityだけを理由にSpan StatusやRAGScopeの処理結果を変更しない。

## 検討した選択肢

### OpenTelemetry `SeverityNumber`の24段階をそのまま公開する

OpenTelemetryの全levelを変換なしで指定できる。一方、現在のRAGScopeには24段階を使い分ける規則がなく、`Info2`と`Info4`のような差を呼び出し側が任意に選べる。RAGScopeの記録でSeverityの意味を揃えにくくなるため採用しない。

### 1〜24を受け取るSDK非依存の数値型を定義する

OpenTelemetry SDK型への依存は避けられ、24段階すべてを表現できる。しかし、正しい範囲へ制限しても、どの数値を選ぶべきかという意味上の問題は残る。RAGScopeが必要としていない選択肢を利用側へ公開するため採用しない。

### `Debug`、`Info`、`Warn`、`Error`の4段階に限定する

現在のRAGScopeで使い分ける意味を定義できる範囲だけを公開できる。呼び出し側はOpenTelemetry固有の細かなlevelを判断する必要がなく、Adapterが標準の`SeverityNumber`へ変換できるため採用する。

### `Trace`、`Fatal`、`Default`も含める

`Trace`は`Debug`より細かな診断情報、`Fatal`は`Error`より強い失敗を表せる。しかし、現在のRAGScopeにはそれらを別のlevelとして使い分ける具体的な要求がない。`Default`はseverityを指定しない状態と意味が重なる。必要性が確認できていない選択肢を共通境界へ先に追加しないため採用しない。

## 結果と影響

- RAGScopeの利用側は4段階の意味だけを選び、OpenTelemetryの24段階や数値を直接扱わない。
- RAGScopeアプリケーションとAI推論サービスのOpenTelemetry Adapterは、4段階Severityを対応するOpenTelemetry `SeverityNumber`へ変換する。
- `Trace`、`Fatal`、またはより細かなseverityが必要になった場合は、具体的な利用要求を根拠に共通境界を拡張する。
- ADR-0006は`superseded`とし、本ADRがSeverityに関する判断を置き換える。ADR-0006のSeverity以外の決定は維持する。
- 現在のSeverityの使い分けは[ログ・イベント設計](../design/observability/ログ・イベント設計.md)を正本とする。正確な型とOpenTelemetryへの変換は各コンポーネントのコードとテストを正本とする。

## 関連文書

- [ADR-0006 — OpenTelemetryをObservabilityの共通基盤とし、Trace・Logs・Metricsの責務を分ける](<./ADR-0006 OpenTelemetryをObservabilityの共通基盤とし、Trace・Logs・Metricsの責務を分ける.md>)
- [ログ・イベント設計](../design/observability/ログ・イベント設計.md)
- [RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する](<../project-management/milestones/v0.0/error-logging/RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する.md>)
- [RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する](<../project-management/milestones/v0.0/error-logging/RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する.md>)
