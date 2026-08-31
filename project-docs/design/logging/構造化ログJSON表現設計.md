---
note_type: design
---
# 構造化ログJSON表現設計

> [!abstract] この文書の役割
> [実行追跡・構造化ログ契約設計](./実行追跡・構造化ログ契約設計.md)で定義する構造化ログ1件を、[構造化ログ外部表現共通設計](./構造化ログ外部表現共通設計.md)の共通情報と属性の規則を使ってJSONへどう配置するかを定義する。イベントや属性の意味・記録条件は、それらを定義する正本を参照し、この文書はJSON固有の階層、JSON上の値型、省略規則、出力単位を担当する。

## 1. JSON表現の全体像

構造化ログ1件を1つのJSON objectとして表す。次は特定の`span`へ関連付くログのJSON上の形を示す例であり、`example_component`、イベント名、属性名を各機能の現在仕様として定めるものではない。

```json
{
  "timestamp": "2026-08-26T00:00:02Z",
  "component": "example_component",
  "event": "example.process.succeeded",
  "level": "info",
  "message": "処理が完了した",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "attributes": {
    "source_id": "example-1",
    "score": 0.87,
    "cache_hit": true,
    "items": ["a", 2, false],
    "detail": {
      "attempt": 2,
      "label": "example"
    }
  }
}
```

特定の`span`へ属さないログでは`trace_id`と`span_id`を両方省略する。

```json
{
  "timestamp": "2026-08-26T00:00:00Z",
  "component": "example_component",
  "event": "example.lifecycle.started",
  "level": "info"
}
```

## 2. 論理情報からJSONへの対応

### 2.1 共通情報

[構造化ログ外部表現共通設計](./構造化ログ外部表現共通設計.md)で定める共通外部項目を、同名のJSON propertyとしてroot objectへ置く。

`timestamp`、`component`、`event`、`level`は必須である。`message`、`trace_id`、`span_id`の扱いは4章で定める。

### 2.2 属性

[構造化ログ外部表現共通設計](./構造化ログ外部表現共通設計.md)で定める属性を、1件につき1つのpropertyとして`attributes` objectへ置く。property名には論理上の属性名をそのまま使用し、property値は3章の規則で表す。

属性の順序は論理契約に意味がないため、`attributes` objectのproperty順も契約に含めない。

## 3. 属性値の表現

### 3.1 文字列・数値・真偽値

文字列、数値、真偽値は次のJSON値として表す。

| 論理上の属性値 | JSON上の値 |
|---|---|
| 文字列 | JSON string |
| 数値 | JSON number |
| 真偽値 | JSON boolean |

文字列中の改行やTABなど、JSONでescapeが必要な文字はJSONの文字列規則に従ってescapeする。属性値としてJSON `null`は使用しない。

### 3.2 array

arrayはJSON arrayとして表す。各要素には3章の属性値の表現を再帰的に適用し、論理上の要素順をそのまま維持する。

### 3.3 object

objectはJSON objectとして表す。論理上の名前をproperty名として使用し、各property値には3章の属性値の表現を再帰的に適用する。objectのproperty順には意味を持たせない。

## 4. 任意情報とTrace Context

`message`、`attributes`、Trace Contextは、論理上存在しない場合に`null`を入れず、対応するproperty自体を省略する。

- `message`が存在しない場合は`message`を省略する。
- `message`が空文字列として存在する場合は`"message": ""`として残す。
- 属性が0件の場合は`attributes`を省略する。
- その属性を定義する正本の記録条件を満たさず属性が存在しない場合は、そのpropertyを作らない。
- 属性値として空のarrayまたはobjectが存在する場合は、`[]`または`{}`としてpropertyを残す。
- Trace Contextが存在する場合は`trace_id`と`span_id`を両方記録する。
- Trace Contextが存在しない場合は`trace_id`と`span_id`を両方省略する。
- `trace_id`だけ、または`span_id`だけを持つJSON objectは有効な構造化ログとして扱わない。

この規則により、「情報が存在しないこと」と「空文字列・空array・空objectという値が存在すること」、および「特定の`span`へ関連付かないこと」を区別したまま論理情報へ戻せる。

## 5. 復元

JSONから論理ログへ戻すときは、root objectの共通外部項目を共通情報へ戻し、`attributes` objectの各propertyを属性名と属性値の組へ戻す。属性値はJSONの値型に従って3章の対応を逆にたどり、arrayとobjectは再帰的に復元する。

`trace_id`と`span_id`が両方存在する場合はTrace Contextが存在する論理ログへ戻し、両方存在しない場合はTrace Contextを持たない論理ログへ戻す。片方だけが存在するJSON objectは復元対象として受け入れない。

JSON objectに同じproperty名が複数存在する場合は、論理契約の名前の一意性を満たさないため復元対象として受け入れない。この規則は、root object、`attributes` object、属性値として使用するobjectのすべてに適用する。

`message`と`attributes`の項目が存在しない場合は論理上も存在しないものとして扱い、空文字列・空array・空objectは値として保持する。

## 6. 出力単位

構造化ログとして複数件を出力する場合は、1件につき1つのJSON objectを1物理行へUTF-8で出力する。複数件を1つのJSON arrayへまとめない。

1件の前後へJSON以外の接頭辞、色制御文字、説明文を付加しない。

具体的な出力先、buffering、IO失敗時の扱いは、各コンポーネントのコード・設定・テストを正本とする。

## 7. 責務と正本

| 正本 | 担当すること |
|---|---|
| [実行追跡・構造化ログ契約設計](./実行追跡・構造化ログ契約設計.md) | 構造化ログ1件が持つ論理情報、属性、イベント、重要度、`error_type`、Trace Contextを持つ条件、`TraceId`・`SpanId`の意味 |
| [構造化ログ外部表現共通設計](./構造化ログ外部表現共通設計.md) | 外部表現で共通する項目名と値表現、Trace Contextの存在・不存在、属性名と論理上の型・値を形式間で維持する規則 |
| イベント・属性・`error_type`を定義する正本 | 具体的なイベント、記録条件、既定の重要度、属性名・属性値、`error_type` |
| この文書 | 共通情報と属性をJSONへ配置する階層、JSON上の値型、Trace Contextを含む任意情報の省略規則、1件の出力単位 |
| 各コンポーネントのコード・設定・テスト | JSON表現へ投影する実装境界、具体的な出力先、buffering、ログ基盤自身のIO失敗の扱い |
| JSON Schema | JSONの正確な項目、型、必須条件、項目間の存在条件、文字列形式を機械的に検証する契約 |

## 関連文書

- [実行追跡・構造化ログ契約設計](./実行追跡・構造化ログ契約設計.md)
- [構造化ログ外部表現共通設計](./構造化ログ外部表現共通設計.md)
- [ADR-0005 — 実行追跡をOpenTelemetryのtrace・spanで表現し、イベントを構造化ログとして記録する](<../../adr/ADR-0005 実行追跡をOpenTelemetryのtrace・spanで表現し、イベントを構造化ログとして記録する.md>)
