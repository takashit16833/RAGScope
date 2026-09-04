---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 共通エラーと構造化ログによる実行追跡]]"
---
# RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する

## 目的

RS-0022の設計検討では、RAGScope独自のLogging Runtime、`LogRecord`、Sink、出力失敗処理などを具体化する過程で、OpenTelemetry Logsが同種の責務をすでに提供しており、現在の実行追跡・構造化ログ契約と実装方針そのものを再評価する必要があることが分かった。現在契約への移行を前提としたRS-0022をそのまま進めると、再評価対象の設計を前提に実装を固定する可能性がある。

このTicketでは、正本リポジトリの`main`に存在する要求とシステム構造を出発点とし、**OpenTelemetry Logsを採用する方針を前提として**、RAGScopeの実行追跡・構造化ログアーキテクチャを再設計する。OpenTelemetryへRAGScope固有の意味を無条件に委ねるのではなく、RAGScopeが所有する意味・契約と、OpenTelemetryへ委ねる実行追跡・ログ記録・転送などの仕組みの境界を決定する。

OpenTelemetry Logsの採用方針は無条件の固定事項とはしない。RAGScopeの必須要求、OpenTelemetryの仕様、採用可能なHaskell / Python実装の具体的な制約を確認した結果、必要な能力を成立させられない事実が判明した場合は、その根拠を示したうえで採用判断自体を再評価する。

RS-0022の未merge branchで行った設計検討は、解決しようとした問題、比較した案、発見した制約を確認するための参考資料として利用してよい。ただし、そのbranchで導入した型、module、package、API、`ErrorType` / `ErrorClassifier`、`OperationFailure`、Observability、Logging Runtime、`LogSpec` / `LogRecord`、Sink、JSON / SQLite投影などを維持すること自体を設計上の前提または採用理由にしない。

## 完了条件

### 要求と追跡対象

- [ ] RAGScope要求定義と現在のシステム構造から、処理の進行、失敗、実験、コンポーネント間の処理関係について、後から何を識別・確認できる必要があるかを特定している
- [ ] RAGScopeアプリケーション、AI推論サービス、利用インターフェース、外部依存をまたぐ実際の処理構造を基準に、実行追跡と構造化ログが担当する範囲を決定している

### OpenTelemetryの適用範囲

- [ ] OpenTelemetry Trace / LogsのData Model、Context連携、SDK、Processor / Exporter、エラー処理など、RAGScopeの設計判断に必要な能力と制約を確認している
- [ ] RAGScopeで採用可能なHaskell / Python実装について、設計を成立させるために必要なTrace / Logs / Context連携とエラー処理を利用できるか確認している
- [ ] OpenTelemetryへ委ねる責務と、RAGScopeが独自に所有する意味・型・Port・分類規則の境界を決定している
- [ ] OpenTelemetry Logsを採用できない具体的な要求または実装制約が判明した場合は、採用判断を見直し、代替案と判断理由を正本へ反映している

### 実行追跡・構造化ログアーキテクチャ

- [ ] `trace`の単位、root / child `span`の境界、Span Status、Trace Contextの引き継ぎを、現在設計を前提にせずRAGScopeの要求と採用するOpenTelemetry構成から決定している
- [ ] どの出来事を構造化ログとして記録するか、`span`やその属性で表す情報とログで表す情報をどう分けるかについて共通判断基準を決定している
- [ ] 通常のtyped failure、unexpected同期Exception、async interruption、Observability基盤自身の失敗について、Application本体の結果とTelemetryへどう反映するかを決定している
- [ ] ローカル実行でTelemetryを確認する方法と、Exporter / Collector / backend、JSON / SQLiteなど保存・外部表現の責務をどこまでRAGScopeが所有するかを決定している

### 現在設計の再評価

- [ ] 現在の`error_type` / `ErrorType` / `ErrorClassifier`、型付き`Logger`とevent、`LogSpec` / `LogRecord`、Logging Runtime、Sink、Logging failure処理、JSON Schema、SQLite表現、Operationと`trace`の対応などを、それぞれ要求・制約・採用するOpenTelemetry構成から再評価している
- [ ] 維持する設計は「現在そうなっている」ことを理由にせず、必要な責務または制約を示して再採用している
- [ ] 変更または削除する設計について、影響する要求、ADR、設計書、Contract、Schema、Experiment、Epic、後続Ticketを特定している

### 正本と後続作業

- [ ] 採用したアーキテクチャに従い、関係するADR・設計書・Contract・プロジェクト管理文書を現在設計として整合させている
- [ ] 後続の実装Ticketが、実行追跡・構造化ログの全体アーキテクチャについて新たな設計判断を必要とせず着手できる状態になっている
- [ ] RS-0022の未merge branchは現在仕様の正本として参照せず、必要な判断だけを新しい根拠とともに現在の正本へ反映している

## 対象外

- RAGScopeアプリケーションまたはAI推論サービスの本番向けTracing / Logging実装
- OpenTelemetry CollectorやTelemetry backendの本番環境構築
- 文書処理、dense検索など個別機能の具体的な`span`、ログイベント、属性を網羅的に定義すること
- 現在のHaskell logging実装、JSON Schema、SQLite表現を、新アーキテクチャ決定前に新方式へ移行すること

採用可能性や設計上の制約を確認するために最小限のExperimentまたはPoCが必要になった場合は、本番実装と分離して実施してよい。

## 関連文書

- [RAGScope要求定義「2.3 信頼性と保守性」](<../../../../RAGScope要求定義.md#2.3 信頼性と保守性>)
- [システムアーキテクチャ](../../../../design/システムアーキテクチャ.md)
- [RS-0022 RAGScopeアプリケーションの構造化ログ基盤を現在契約へ移行する](<./RS-0022 RAGScopeアプリケーションの構造化ログ基盤を現在契約へ移行する.md>)
- [実行追跡・構造化ログ契約設計](../../../../design/logging/実行追跡・構造化ログ契約設計.md)
- [構造化ログ外部表現共通設計](../../../../design/logging/構造化ログ外部表現共通設計.md)
- [構造化ログJSON表現設計](../../../../design/logging/構造化ログJSON表現設計.md)
- [構造化ログSQLite表現設計](../../../../design/logging/構造化ログSQLite表現設計.md)
- [ADR-0005 — 実行追跡をOpenTelemetryのtrace・spanで表現し、イベントを構造化ログとして記録する](<../../../../adr/ADR-0005 実行追跡をOpenTelemetryのtrace・spanで表現し、イベントを構造化ログとして記録する.md>)

## 結果

完了時に、採用したアーキテクチャ、再評価した現在設計、OpenTelemetry Logs採用判断の結果、確認方法、後続Ticketへの引き渡しを記録する。
