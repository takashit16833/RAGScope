---
note_type: design
---
# 構造化ログJSON表現設計

> [!abstract] この文書の役割
> [構造化ログ設計](./構造化ログ設計.md)で定義した構造化ログの共通の意味を、v1 JSONのどの項目と値として表現するかを定義する。
>
> このJSON契約はRAGScopeアプリケーションとAI推論サービスで共通に使用する。各コンポーネント内部の型、JSONへの変換処理、出力IOの実装は本設計では定義しない。

## 1. v1 JSONの全体像

構造化ログ1件を1つのJSON objectとして表現する。ルートには契約、記録時刻、生成元、関連する処理の情報を置き、`spec`には処理種別、イベント名、ログレベル、補助情報、失敗時のエラー情報をまとめる。

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

v1の`schema_version`は`1`とする。`component`は、RAGScopeアプリケーションを`ragscope_app`、AI推論サービスを`ai_service`として表現する。

具体的な`operation`、通常イベント名、`payload`の内容は各機能設計を正本とする。失敗時に記録できる情報は[エラー設計](../エラー設計.md)と各機能設計に従う。

## 3. CLI実行とサービス状態の表現

| 関連先 | `context.scope` | `context.execution_id` |
|---|---|---|
| 1回のCLI実行 | `execution` | そのCLI実行を識別する値を記録する |
| 特定のCLI実行に属さないサービス状態 | `service` | 含めない |

同じCLI実行に属する構造化ログでは、生成したコンポーネントにかかわらず同じ`execution_id`を使用する。

## 4. 通常イベントと失敗イベント

共通設計で定義した通常イベントと失敗イベントを、v1 JSONでは次の形として表現する。

| 種類 | `spec.event` | `spec.level` | `spec.error` |
|---|---|---|---|
| 通常イベント | 各機能設計で定めた通常イベント名 | `debug` / `info` / `warn` | 含めない |
| 失敗イベント | `failed` | `error` | 必須 |

通常イベントでは`failed`を通常イベント名として使用しない。失敗イベントでは、処理が失敗したことを`spec.event = failed`、ログレベルを`spec.level = error`として表し、安全なエラー情報を`spec.error`へ記録する。

通常イベントと失敗イベントの許可形は相互排他的とする。

## 5. `payload`と`error`

`spec.payload`には、各機能設計で記録を許可した安全な補助情報をJSON objectとして記録する。補助情報がない場合は空objectを使用する。

失敗イベントの`spec.error`は、[エラー設計](../エラー設計.md)で構造化ログへの記録を許可した共通エラー情報を次のように表現する。

| 共通エラーの情報 | v1 JSONでの表現 |
|---|---|
| エラー分類 | `spec.error.category` |
| 安定したエラーコード | `spec.error.code` |
| 安全なメッセージ | `spec.error.message` |
| 記録を許可した補助情報 | `spec.error.context` |
| 内部原因 | JSONへ含めない |

通常イベントでは`spec.error`を含めない。失敗イベントでもエラー固有の補助情報がない場合は`spec.error.context`を含めない。

`spec.payload`と`spec.error.context`の内部では`null`を使用せず、値を記録しない項目は含めない。

## 6. 責務分担と正確な契約

| 定義・実装する場所 | 担当する内容 |
|---|---|
| [構造化ログ設計](./構造化ログ設計.md) | 構造化ログの共通の意味と保証 |
| 本設計 | 共通の意味をv1 JSONの項目と値へ対応付ける規則 |
| [`log-event.schema.json`](../../../contracts/logging/v1/log-event.schema.json) | JSON項目、型、必須条件、列挙値、文字列形式、通常イベントと失敗イベントの正確な許可形 |
| 各機能設計 | 具体的な`operation`、通常イベント名、`payload`、機能固有のエラー情報 |
| 各コンポーネントの設計とコード | 内部表現からv1 JSONへの変換と出力IO |

各コンポーネントは、自身が記録する構造化ログをこの共通JSON契約へ変換する。変換前の内部表現をv1 JSONと同じ構造にすることは要求しない。

fixtureはSchemaへの適合・不適合を検証する入力であり、JSON契約の正本として扱わない。

## 7. 出力単位

v1のローカル構造化ログでは、構造化ログ1件を1行のJSONとして出力する。1件の前後へJSON以外の接頭辞、色制御文字、説明文を付加しない。

具体的な出力先とIO失敗の扱いは各コンポーネントの設計・実装が担当する。

## 関連文書

- [構造化ログ設計](./構造化ログ設計.md)
- [システムアーキテクチャ](../システムアーキテクチャ.md)
- [エラー設計](../エラー設計.md)
- [RAGScopeアプリケーション構造化ログ設計](./RAGScopeアプリケーション構造化ログ設計.md)
- [ADR-0004 — 構造化ログの内部イベントモデルを通常イベントと失敗イベントの直和として表現する](<../../adr/ADR-0004 構造化ログの内部イベントモデルを通常イベントと失敗イベントの直和として表現する.md>)
