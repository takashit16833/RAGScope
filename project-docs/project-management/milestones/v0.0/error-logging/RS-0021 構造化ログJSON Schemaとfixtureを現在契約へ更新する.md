---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 共通エラーと構造化ログによる実行追跡]]"
---
# RS-0021 構造化ログJSON Schemaとfixtureを現在契約へ更新する

## 目的

[RS-0020 共通エラー・構造化ログの論理契約を再設計する](<./RS-0020 共通エラー・構造化ログの論理契約を再設計する.md>)で確定した現在の実行追跡・構造化ログ契約とJSON表現に対して、既存の`contracts/logging/v1/log-event.schema.json`とfixtureが旧論理モデルを表したままになっている。

既存Contractでは`schema_version`、`event_id`、`context`、`execution_id`、`spec.operation`、固定的な`failed`イベント、失敗時の`error` objectなどを契約としており、現在の論理契約が定める`TraceId`・`SpanId`による関連付け、イベント名と重要度の独立、任意の`message`・`attributes`、`fatal`を含む重要度、属性としての`error_type`を表していない。

このTicketでは、共有JSON Contractの機械可読な正本を現在の[構造化ログJSON表現設計](../../../../design/logging/構造化ログJSON表現設計.md)へ合わせて置き換え、代表的な適合・不適合fixtureによって契約を検証できる状態にする。

## 前提

- [RS-0020 共通エラー・構造化ログの論理契約を再設計する](<./RS-0020 共通エラー・構造化ログの論理契約を再設計する.md>)が完了し、現在の実行追跡・構造化ログ設計がデフォルトブランチへ反映されている

## 完了条件

- [ ] `contracts/logging/v1/log-event.schema.json`が、現在のJSON表現で必須となる`timestamp`、`component`、`event`、`level`、`trace_id`、`span_id`と、任意の`message`、`attributes`を検証できる
- [ ] `timestamp`、`trace_id`、`span_id`、`level`など、外部表現共通設計とJSON表現設計が定める正確な値形式と必須条件がSchemaに反映されている
- [ ] `attributes`がstring、number、boolean、array、objectを再帰的に扱え、論理上存在しない`null`を受け入れない
- [ ] `message`と`attributes`の省略、および空文字列・空array・空objectを値として保持するJSON表現を契約として検証できる
- [ ] `level`で`debug`、`info`、`warn`、`error`、`fatal`を表現できる
- [ ] `schema_version`、`event_id`、`context`、`execution_id`、`spec.operation`、固定的な`failed`イベント、失敗時の専用`error` objectなど、現在契約が採用しない旧構造をSchemaの契約として残していない
- [ ] `error_type`やドメイン参照を共通root項目へ昇格させず、イベントを定義する正本が必要に応じて`attributes`へ配置できる
- [ ] 特定コンポーネントの発生元、機能固有イベント名、機能固有`error_type`を共有Schemaの固定`enum`として持たない
- [ ] 現在のJSON契約を代表するvalid fixtureと、主要な契約違反を代表するinvalid fixtureが更新されている
- [ ] Schemaとfixtureを検証する既存または追加の自動検査を実行し、valid fixtureが受理され、invalid fixtureが拒否されることを確認できる
- [ ] Schema、fixture、現在の実行追跡・構造化ログ契約設計、外部表現共通設計、JSON表現設計の間に未解消な差異がない

## 対象外

- RAGScopeアプリケーションのHaskell logging実装を新しい契約へ移行すること
- AI推論サービスのPython logging実装を作成すること
- SQLiteを本番向け外部表現として実装すること
- 機能固有のイベント、属性、`error_type`をこのTicketで決定すること

## 関連文書

- [RS-0020 共通エラー・構造化ログの論理契約を再設計する](<./RS-0020 共通エラー・構造化ログの論理契約を再設計する.md>)
- [実行追跡・構造化ログ契約設計](../../../../design/logging/実行追跡・構造化ログ契約設計.md)
- [構造化ログ外部表現共通設計](../../../../design/logging/構造化ログ外部表現共通設計.md)
- [構造化ログJSON表現設計](../../../../design/logging/構造化ログJSON表現設計.md)
- [構造化ログ論理契約のJSON・SQLite投影検証](../../../../experiments/構造化ログ論理契約のJSON・SQLite投影検証.md)
- [共通ログイベントJSON Schema](../../../../../contracts/logging/v1/log-event.schema.json)

## 実装メモ

既存Schemaの階層を維持すること自体を目的にしない。現在のJSON表現を機械的に検証できることを基準に置き換える。一方、属性値で`null`を認めず、string・number・boolean・array・objectを再帰的に扱う既存Contractの性質は、現在の`attributes`契約へ適用できる。

JSON object内の重複property名の拒否はJSON Schemaだけでは保証できないため、必要な検証境界は使用するparserやテストを含めて決める。正確な検証実装はコードとテストを正本とする。

## 結果

> [!note] 完了時に記入
> - 更新したJSON Schema
> - 更新したvalid / invalid fixture
> - 実行したSchema・fixture検証と結果
> - 現在のJSON表現設計との適合結果
> - 既知の制約
> - 関連Pull Request
