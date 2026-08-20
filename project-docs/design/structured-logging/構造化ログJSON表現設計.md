---
note_type: design
---
# 構造化ログJSON表現設計

> [!abstract] この文書の役割
> [構造化ログ設計](./構造化ログ設計.md)で定義した構造化ログの共通の意味を、v1 JSONのどの項目と値として表現するかを定義する。
>
> このJSON契約はRAGScopeアプリケーションとAI推論サービスで共通に使用する。正確なJSON項目、型、必須条件、列挙値、文字列形式は[`log-event.schema.json`](../../../contracts/logging/v1/log-event.schema.json)を正本とする。各コンポーネント内部の型、変換処理、出力IOの実装は本設計では定義しない。

## 1. v1 JSONの全体像

構造化ログ1件を1つのJSON objectとして表現する。共通設計で区別した「何の処理で起きたか」「何が起きたか」「補助情報」「失敗情報」は`spec`へまとめる。

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

## 2. 共通設計の意味とJSON項目の対応

| 構造化ログで表す意味 | v1 JSONでの表現 |
|---|---|
| どの構造化ログ契約に従うか | `schema_version` |
| どの記録か | `event_id` |
| いつ記録されたか | `timestamp` |
| どこで生成されたか | `component` |
| どの処理に属するか | `context` |
| 何の処理で起きたか | `spec.operation` |
| 何が起きたか | `spec.event` |
| ログレベル | `spec.level` |
| 出来事の安全な補助情報 | `spec.payload` |
| 失敗時の安全なエラー情報 | `spec.error` |

具体的な`operation`、通常イベント名、`payload`の内容は各機能設計を正本とする。失敗時に記録できる情報は[エラー設計](../エラー設計.md)と各機能設計に従う。

## 3. CLI実行との関連付け

同じCLI実行に属する構造化ログは、`context.scope`を`execution`とし、`context.execution_id`へ同じCLI実行識別子を記録する。

特定のCLI実行に属さない構造化ログは、`context.scope`を`service`とし、`execution_id`を含めない。

`context`の正確な許可形と`execution_id`の形式はJSON Schemaを正本とする。

## 4. 通常イベントと失敗イベント

共通設計で定義した通常イベントと失敗イベントを、v1 JSONでは次の形として表現する。

| 種類 | `spec.event` | `spec.level` | `spec.error` |
|---|---|---|---|
| 通常イベント | 各機能設計で定めた通常イベント名 | `debug` / `info` / `warn` | 含めない |
| 失敗イベント | `failed` | `error` | 必須 |

通常イベントでは`failed`を通常イベント名として使用しない。失敗イベントでは、処理が失敗したことを`spec.event = failed`、失敗用ログレベルを`spec.level = error`として表し、安全なエラー情報を`spec.error`へ記録する。

通常イベントと失敗イベントの許可形は相互排他的とし、JSON Schemaで機械的に検証する。

## 5. `payload`、`error`と`null`

`spec.payload`には、各機能設計で記録を許可した安全な補助情報をJSON objectとして記録する。補助情報がない場合は空objectを使用する。

通常イベントでは`spec.error`を含めない。失敗イベントの`spec.error`には安全なエラー情報を記録し、エラー固有の補助情報がある場合だけ`spec.error.context`を含める。

`spec.payload`と`spec.error.context`の内部では`null`を使用せず、値を記録しない項目は含めない。正確な許可形はJSON Schemaを正本とする。

## 6. 各コンポーネントとの責務分担

RAGScopeアプリケーションとAI推論サービスは、それぞれ自身が記録する構造化ログを本設計のv1 JSONへ変換する処理を実装する。

本設計は変換後のJSON表現を共通契約として定義し、変換前の内部型、モジュール構造、変換関数、出力IOの構成は各コンポーネントの設計とコードへ委ねる。内部表現をv1 JSONと同じ構造にすることは要求しない。

JSON契約への適合性は[`log-event.schema.json`](../../../contracts/logging/v1/log-event.schema.json)で検証する。

## 7. 出力単位

v1のローカル構造化ログでは、構造化ログ1件を1行のJSONとして出力する。1件の前後へJSON以外の接頭辞、色制御文字、説明文を付加しない。

具体的な出力先とIO失敗の扱いは各コンポーネントの設計・実装が担当する。

## 8. 機械可読な正本

JSON契約の正確な項目、型、必須条件、列挙値、文字列形式、通常イベントと失敗イベントの許可形は[`log-event.schema.json`](../../../contracts/logging/v1/log-event.schema.json)を正本とする。

fixtureはSchemaへ適合する例・適合しない例を表す検証入力であり、Schemaと同格の仕様正本として扱わない。

## 関連文書

- [構造化ログ設計](./構造化ログ設計.md)
- [システムアーキテクチャ](../システムアーキテクチャ.md)
- [エラー設計](../エラー設計.md)
- [RAGScopeアプリケーション構造化ログ設計](./RAGScopeアプリケーション構造化ログ設計.md)
- [ADR-0004 — 構造化ログの内部イベントモデルを通常イベントと失敗イベントの直和として表現する](<../../adr/ADR-0004 構造化ログの内部イベントモデルを通常イベントと失敗イベントの直和として表現する.md>)
