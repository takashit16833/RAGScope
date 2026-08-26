---
note_type: experiment
---
# 構造化ログ論理契約のJSON・SQLite投影検証

## 仮説

[実行追跡・構造化ログ契約設計](../design/logging/実行追跡・構造化ログ契約設計.md)と[構造化ログ外部表現共通設計](../design/logging/構造化ログ外部表現共通設計.md)で定義した論理ログは、JSONとSQLiteのどちらか一方の物理構造を前提にせず、それぞれへ直接投影して元の論理ログへ復元できる。

この仮説が成立するなら、JSONのobject階層やSQLiteのtable・local keyなど、形式固有の都合を論理契約へ追加する必要はない。

## 検証条件

検証対象は`RS-0020/json-sqlite-projection` branchの`5e9ee1daf7ee7ac74a2d7603263c7b0316a5b9b4`を開始点とした現在設計である。

参照した設計は次のとおりである。

- [実行追跡・構造化ログ契約設計](../design/logging/実行追跡・構造化ログ契約設計.md)
- [構造化ログ外部表現共通設計](../design/logging/構造化ログ外部表現共通設計.md)
- [構造化ログJSON表現設計](../design/logging/構造化ログJSON表現設計.md)
- [構造化ログSQLite表現設計](../design/logging/構造化ログSQLite表現設計.md)
- [`document.file_not_found`を定義する文書処理設計](../design/features/文書処理設計.md)

試作は`logging-json-sqlite-projection/`へ責務ごとに分け、[verify.py](./logging-json-sqlite-projection/verify.py)を実行入口とした。Python標準ライブラリだけを使用し、検証時の環境はPython 3.13.5、SQLite 3.46.1である。

既存の`contracts/logging/v1/log-event.schema.json`は、現在の論理契約より前の`operation`、`execution_id`、通常・失敗イベントの結合を表すため、本検証の入力契約として使用していない。本検証は現在の論理契約と外部表現設計そのものを対象とする。

## 論理fixtureと同値判定

試作内では、JSON objectやSQLite rowをfixtureの正本にせず、構造化ログ1件と属性値を独立した論理値として定義した。

構造化ログ1件は次を持つ。

- `timestamp`
- `component`
- `event`
- `level`
- 任意の`message`
- `trace_id`
- `span_id`
- 0件以上の属性

属性値は`string`、`number`、`boolean`、`array`、`object`の5種類とし、arrayとobjectは再帰的に同じ属性値を持つ。`number`は二進浮動小数点への変換で値を失わないよう、試作上の論理値では`Decimal`として保持した。

論理ログの同値判定では次を適用した。

- 共通情報と`message`は同じ値であることを要求する。
- `message`が存在しないことと空文字列で存在することを区別する。
- 属性の並び順には意味を持たせない。
- object memberの並び順には意味を持たせない。
- arrayの要素順には意味を持たせる。
- 同じ属性名または同じobject member名を複数持つ論理値は作成できない。

### fixture

| fixture | 主な確認内容 |
|---|---|
| 1 | `message`あり、制御文字、`error_type=document.file_not_found`、ドメイン参照を模した属性、2^53を超える整数、高精度小数、真偽値、mixed array、nested array / object、empty array / object |
| 2 | `message`なし、属性0件 |
| 3 | 空文字列の`message`、空文字列属性、改行・復帰・TABを含む文字列 |

fixture 1の`document_version_id`はドメイン参照の値を属性として往復できることを確認するための検証用属性名であり、現在仕様の具体的な属性名として採用するものではない。

## 投影方法

### JSON

論理ログから[構造化ログJSON表現設計](../design/logging/構造化ログJSON表現設計.md)へ直接投影した。

- 共通情報はroot objectへ置く。
- `message`が存在しない場合はpropertyを省略し、空文字列なら残す。
- 属性0件では`attributes`を省略する。
- 属性値のstring、number、boolean、array、objectを対応するJSON値へ再帰的に投影する。
- JSON numberは論理上の10進値を失わない文字列表現からJSON number tokenを生成し、復元時は`Decimal`として読む。
- 復元時にJSON objectの同名memberと属性値の`null`を拒否する。

JSONからSQLiteへの変換は行っていない。

### SQLite

同じ論理fixtureから[構造化ログSQLite表現設計](../design/logging/構造化ログSQLite表現設計.md)へ直接投影した。

- 共通情報は`log_record`へ置く。
- 属性は`log_attribute`、各論理値は`log_value`へ置く。
- arrayは`log_array_item`、objectは`log_object_member`のrelationで再帰構造を表す。
- `number_value`は`TEXT`として論理上の10進値を保持する。
- `record_id`と`value_id`はSQLite内のrelationだけに使用し、復元した論理ログへ含めない。
- `STRICT` tableとforeign key enforcementを使用する。
- 1件の論理ログは1 transactionで投影する。

SQLite内にはJSON文字列やJSON object階層を保存していない。SQLiteからJSONへの変換も行っていない。

## 実測結果

検証スクリプトを次のように実行した。

```text
python3 project-docs/experiments/logging-json-sqlite-projection/verify.py
```

結果は`ALL CHECKS PASSED`となった。

### 往復

3件すべてのfixtureで次を確認した。

| 検証 | 結果 |
|---|---|
| 論理ログ → JSON → 論理ログ | 同値に復元できた |
| JSON出力 | 1件が1物理行になった |
| 論理ログ → SQLite → 論理ログ | 同値に復元できた |
| SQLiteの`record_id` / `value_id` | 復元した論理ログへ入らなかった |

fixture 1に含めた`9007199254740993`と`0.123456789012345678901234567890`も、JSONとSQLiteの両方から同じ論理上の数値へ復元できた。

### 順序と任意情報

| 検証 | 結果 |
|---|---|
| 属性順だけを入れ替える | 同値と判定した |
| object member順だけを入れ替える | 同値と判定した |
| array要素順を入れ替える | 非同値と判定した |
| `message`なしと空文字列の`message` | 非同値と判定した |

### 不正表現

次の不正な表現を拒否できることも確認した。

| 不正表現 | 確認方法 | 結果 |
|---|---|---|
| JSON objectの同名member | JSON復元 | 拒否 |
| JSON属性値の`null` | JSON復元 | 拒否 |
| SQLiteの同一record内の同名属性 | `PRIMARY KEY` | 拒否 |
| SQLiteの同一object内の同名member | `PRIMARY KEY` | 拒否 |
| SQLite array indexの欠番 | SQLite復元 | 拒否 |
| `value_kind`とscalar columnの不整合 | `CHECK` | 拒否 |
| array/object relationのparent kind不整合 | SQLite復元 | 拒否 |
| 値relationの循環 | SQLite復元 | 拒否 |
| 数値として読めない`number_value` | SQLite復元 | 拒否 |

## 判明したこと

### 論理契約を外部形式へ寄せる必要はない

検証範囲では、同じ論理fixtureをJSONとSQLiteへ独立に投影し、両方から同じ論理ログへ復元できた。JSONのobject階層をSQLiteへ持ち込む必要はなく、SQLiteの`record_id`、`value_id`、table構造を論理契約へ持ち込む必要もなかった。

`error_type`とドメイン参照も通常の属性と同じ仕組みで往復でき、外部形式共通のroot項目へ昇格させる必要はなかった。

### SQLiteの妥当性には復元境界で確認する規則がある

`PRIMARY KEY`、foreign key、`CHECK`だけで、SQLite表現のすべての妥当性を直接保証できるわけではない。今回の試作では、次を復元時に確認した。

- array indexが0から隙間なく並ぶこと
- relationのparentが対応する`value_kind`であること
- 値relationが循環しないこと
- `number_value`が有限の論理数値として読めること

これはSQLite固有の検証責務であり、論理契約へ補助項目を追加する理由にはならない。

## 検証範囲外

本検証では次を扱っていない。

- 既存のJSON Schemaを新しいJSON表現へ更新すること
- SQLiteを本番の構造化ログ出力として実装すること
- SQLiteの永続file、同時書き込み、index、rotation、保持期間の設計
- HaskellまたはPythonの本番用内部型を新しい論理契約へ更新すること
- OpenTelemetry SDKやOTLPを介した実行追跡の実装
- 各機能で今後追加されるすべてのイベント・属性値の網羅

## 結論

仮説は、今回の代表fixtureと不正表現の検証範囲で支持された。

現在の論理契約と共通外部表現は、JSONとSQLiteのどちらにも直接投影して同じ論理ログへ復元できる。今回確認した範囲では、特定の外部形式の都合を理由に[実行追跡・構造化ログ契約設計](../design/logging/実行追跡・構造化ログ契約設計.md)または[構造化ログ外部表現共通設計](../design/logging/構造化ログ外部表現共通設計.md)を変更する必要はない。

後続作業では、現在設計と食い違っている既存Schema・実装を、それぞれの正本の責務で見直す。
