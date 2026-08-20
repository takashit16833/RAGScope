---
note_type: design
---
# 構造化ログJSON表現設計

> [!abstract] この文書の役割
> [構造化ログ設計](./構造化ログ設計.md)で定義した`LogEvent`の意味を、v1の外部JSONとしてどのように表現するかを定義する。
>
> 本設計はJSON表現だけを扱い、各コンポーネントの内部型やモジュール構造を定義しない。正確なJSON項目、型、必須条件、形式は[`log-event.schema.json`](../../../contracts/logging/v1/log-event.schema.json)を正本とする。

## 1. JSON表現の全体像

1つの`LogEvent`を1つのJSON objectとして表現し、イベントの意味を表す情報は`spec`へまとめる。

```json
{
  "schema_version": 1,
  "event_id": "1fda6e26-b16c-4dd5-a6db-7a39675cb722",
  "timestamp": "2026-08-19T10:00:00Z",
  "component": "ragscope_app",
  "context": {
    "scope": "execution",
    "execution_id": "dd28491c-cc69-4b29-b860-92f40e3badf4"
  },
  "spec": {
    "operation": "document.load",
    "event": "completed",
    "level": "info",
    "payload": {}
  }
}
```

この階層はJSON上の表現であり、構造化ログの意味モデルや各コンポーネントの内部型を同じ構造にすることは要求しない。

## 2. 意味モデルからJSONへの対応

| 構造化ログの意味 | JSON上の表現 |
|---|---|
| 契約バージョン | `schema_version` |
| ログイベントの識別子 | `event_id` |
| 記録時刻 | `timestamp` |
| 生成コンポーネント | `component` |
| 実行上の文脈 | `context` |
| 処理種別 | `spec.operation` |
| 実効イベント名 | `spec.event` |
| 実効ログレベル | `spec.level` |
| イベント固有情報 | `spec.payload` |
| 失敗時の安全なエラー情報 | `spec.error` |

正確な文字列表現、列挙値、形式、必須条件はJSON Schemaを正本とし、本設計へ重複して定義しない。

## 3. 通常イベントと失敗イベントの表現

[ADR-0004](<../../adr/ADR-0004 構造化ログの内部イベントモデルを通常イベントと失敗イベントの直和として表現する.md>)に従い、意味モデル上のNormalEventとFailedEventを、JSONでは次の相互排他的な形として表現する。

| 種類 | `spec.event` | `spec.level` | `spec.error` |
|---|---|---|---|
| 通常イベント | `failed`以外 | `debug` / `info` / `warn` | 含めない |
| 失敗イベント | `failed` | `error` | 必須 |

失敗イベントの`event = failed`と`level = error`は、意味モデル上のFailedEventから導出した結果として表現する。外部表現にこれらの項目が存在することを理由に、各コンポーネントの内部モデルで独立した入力として保持しない。

## 4. 任意項目と`null`

- 通常イベントでは`spec.error`を`null`にせず、キー自体を省略する。
- エラー固有の安全な補助情報がない場合は、`spec.error.context`を`null`にせず、キー自体を省略する。
- `spec.payload`とエラーの`context`へ格納する値には`null`を使用しない。情報が不要な場合は項目自体を省略する。

これらの許可形はJSON Schemaで機械的に検証する。

## 5. serialization境界

各コンポーネントは、意味上有効な完成済み`LogEvent`をserialization境界でこのJSON表現へ投影する。

- 内部モデルとJSON構造を同型にすることを要求しない。
- JSONの項目構造やGeneric serializationの都合を、内部モデルの設計理由にしない。
- 意味上有効な`LogEvent`からJSONへの変換はtotalな純粋変換として扱う。
- JSON契約への不適合は、実行時の回復処理ではなく、各コンポーネントの型・変換テストとJSON Schema適合テストで検出する。
- JSON objectの項目順を契約に含めない。

## 6. 出力単位

v1のローカル構造化ログでは、1つの`LogEvent`を1行のJSONとして出力する。1イベントの前後へJSON以外の接頭辞、色制御文字、説明文を付加しない。

具体的な出力先とIO失敗の扱いは各コンポーネントの設計・実装が担当し、本設計では定義しない。

## 7. 正確な契約の正本

JSON契約の正確な項目、型、必須条件、列挙値、文字列形式、通常・失敗イベントの許可形は[`log-event.schema.json`](../../../contracts/logging/v1/log-event.schema.json)を正本とする。

fixtureはSchemaへ適合する例・適合しない例を表す検証入力であり、Schemaと同格の仕様正本として扱わない。

## 関連文書

- [構造化ログ設計](./構造化ログ設計.md)
- [ADR-0003 — 構造化ログのJSON構造をログモデルの型構造と整合させる](<../../adr/ADR-0003 構造化ログのJSON構造をログモデルの型構造と整合させる.md>)
- [ADR-0004 — 構造化ログの内部イベントモデルを通常イベントと失敗イベントの直和として表現する](<../../adr/ADR-0004 構造化ログの内部イベントモデルを通常イベントと失敗イベントの直和として表現する.md>)
