---
note_type: ticket
status: done
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

- [x] `contracts/logging/v1/log-event.schema.json`が、現在のJSON表現で必須となる`timestamp`、`component`、`event`、`level`、`trace_id`、`span_id`と、任意の`message`、`attributes`を検証できる
- [x] `timestamp`、`trace_id`、`span_id`、`level`など、外部表現共通設計とJSON表現設計が定める正確な値形式と必須条件がSchemaに反映されている
- [x] `attributes`がstring、number、boolean、array、objectを再帰的に扱え、論理上存在しない`null`を受け入れない
- [x] `message`と`attributes`の省略、および空文字列・空array・空objectを値として保持するJSON表現を契約として検証できる
- [x] `level`で`debug`、`info`、`warn`、`error`、`fatal`を表現できる
- [x] `schema_version`、`event_id`、`context`、`execution_id`、`spec.operation`、固定的な`failed`イベント、失敗時の専用`error` objectなど、現在契約が採用しない旧構造をSchemaの契約として残していない
- [x] `error_type`やドメイン参照を共通root項目へ昇格させず、イベントを定義する正本が必要に応じて`attributes`へ配置できる
- [x] 特定コンポーネントの発生元、機能固有イベント名、機能固有`error_type`を共有Schemaの固定`enum`として持たない
- [x] 現在のJSON契約を代表するvalid fixtureと、主要な契約違反を代表するinvalid fixtureが更新されている
- [x] Schemaとfixtureを検証する既存または追加の自動検査を実行し、valid fixtureが受理され、invalid fixtureが拒否されることを確認できる
- [x] Schema・fixtureの適合検証を現在のHaskell `LogEvent`生成JSONのSchema適合検証から分離し、Haskell実装の新Schemaへの追随は[RS-0022 RAGScopeアプリケーションの構造化ログ基盤を現在契約へ移行する](<./RS-0022 RAGScopeアプリケーションの構造化ログ基盤を現在契約へ移行する.md>)で扱える状態になっている
- [x] Schema、fixture、現在の実行追跡・構造化ログ契約設計、外部表現共通設計、JSON表現設計の間に未解消な差異がない

## 対象外

- RAGScopeアプリケーションのHaskell logging実装を新しい契約へ移行すること
- `ragscope-app/test/RAGScope/Logging/SchemaSpec.hs`など、Haskell側のSchema適合テストを新しいfixtureと契約へ追随させること
- AI推論サービスのPython logging実装を作成すること
- SQLiteを本番向け外部表現として実装すること
- 機能固有のイベント、属性、`error_type`をこのTicketで決定すること

## 関連文書

- [RS-0020 共通エラー・構造化ログの論理契約を再設計する](<./RS-0020 共通エラー・構造化ログの論理契約を再設計する.md>)
- [RS-0022 RAGScopeアプリケーションの構造化ログ基盤を現在契約へ移行する](<./RS-0022 RAGScopeアプリケーションの構造化ログ基盤を現在契約へ移行する.md>)
- [実行追跡・構造化ログ契約設計](../../../../design/logging/実行追跡・構造化ログ契約設計.md)
- [構造化ログ外部表現共通設計](../../../../design/logging/構造化ログ外部表現共通設計.md)
- [構造化ログJSON表現設計](../../../../design/logging/構造化ログJSON表現設計.md)
- [構造化ログ論理契約のJSON・SQLite投影検証](../../../../experiments/構造化ログ論理契約のJSON・SQLite投影検証.md)
- [共通ログイベントJSON Schema](../../../../../contracts/logging/v1/log-event.schema.json)

## 実装メモ

既存Schemaの階層を維持すること自体を目的にしない。現在のJSON表現を機械的に検証できることを基準に置き換える。一方、属性値で`null`を認めず、string・number・boolean・array・objectを再帰的に扱う既存Contractの性質は、現在の`attributes`契約へ適用できる。

JSON object内の重複property名の拒否はJSON Schemaだけでは保証できないため、必要な検証境界は使用するparserやテストを含めて決める。正確な検証実装はコードとテストを正本とする。

## 結果

`contracts/logging/v1/log-event.schema.json`を、必須の`timestamp`、`component`、`event`、`level`、`trace_id`、`span_id`と、任意の`message`、`attributes`を持つ現在のJSON表現へ更新した。重要度5種、UTC timestamp、TraceId・SpanId、再帰的な属性値、任意項目の省略を検証し、rootの追加propertyを拒否する契約とした。特定の発生元、イベント名、`error_type`は固定`enum`へ閉じ込めていない。

valid fixtureは`complete-event.json`、`empty-values.json`、`minimal-event.json`の3件へ更新した。invalid fixtureは、必須項目、型、値形式、`null`、空のroot `attributes`、未知のroot項目、JSON object内の重複property名などを代表する21件へ更新した。

Python 3.12.13と`jsonschema` 4.26.0のDraft 2020-12 validatorを使用し、`format`検査を有効にしてSchemaとfixtureを独立に検証した。Schema自体の妥当性を確認したうえで、valid 3件をすべて受理し、invalid 21件をすべて拒否した。invalidのうち18件はSchemaで拒否し、重複property名を持つ3件は、同名propertyを拒否するJSON parser境界で拒否した。

Schemaのroot項目、必須条件、重要度、属性値の再帰構造、TraceId・SpanId・イベント名の値形式を機械的に照合した。旧契約要素も検索し、`schema_version`は拒否確認用のinvalid fixtureだけに残り、`event_id`、`execution_id`、`context`、`spec`、`operation`、専用`error` objectは共有Contractに残っていないことを確認した。`failed`は固定イベントではなくイベント名の接尾辞、`error`は重要度、`error_type`とドメイン参照は通常の属性として扱われている。

[実行追跡・構造化ログ契約設計](../../../../design/logging/実行追跡・構造化ログ契約設計.md)、[構造化ログ外部表現共通設計](../../../../design/logging/構造化ログ外部表現共通設計.md)、[構造化ログJSON表現設計](../../../../design/logging/構造化ログJSON表現設計.md)とSchema・fixtureを照合し、RS-0021の範囲に未解消な差異がないことを確認した。

JSON SchemaだけではJSON object内の重複property名を検出できないため、入力をJSON値へ変換するparser境界で一意性を検証する必要がある。Haskellファイルは変更しておらず、現在のHaskell logging実装、JSON生成、新fixture名への`SchemaSpec.hs`の追随、Haskell生成JSONのSchema適合検証は[RS-0022](<./RS-0022 RAGScopeアプリケーションの構造化ログ基盤を現在契約へ移行する.md>)で扱う。
