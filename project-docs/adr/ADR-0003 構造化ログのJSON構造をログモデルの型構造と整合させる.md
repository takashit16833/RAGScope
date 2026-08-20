---
note_type: adr
status: superseded
---
# ADR-0003 — 構造化ログのJSON構造をログモデルの型構造と整合させる

> [!note] 後続ADR
> 本判断は[ADR-0004 — 構造化ログの内部イベントモデルを通常イベントと失敗イベントの直和として表現する](<./ADR-0004 構造化ログの内部イベントモデルを通常イベントと失敗イベントの直和として表現する.md>)により置き換えられた。JSON上の`spec`への集約、外部表現をHaskellのconstructor名から独立させること、JSON SchemaをJSON契約の正本とすることはADR-0004で引き継ぐ一方、内部モデルを外部表現と同型にすること自体は設計目標としない。

## 背景

RAGScopeアプリケーションの構造化ログでは、Haskell内部で`LogEvent`、`EventContext`、`EventSpec`、`Payload`、`LogError`として意味ごとに構造を分けている。一方、現在のJSON契約では`EventSpec`に属する`operation`、`event`、`level`、`payload`、`error`をルートへ展開しており、内部モデルとJSON契約の構造差を`AesonStderr`の手書き変換で吸収している。

RS-0015でSchema適合テストを追加する前に、JSON契約も意味上の構造を保つ形へ整理し、Haskell側でAesonのGeneric導出を自然に利用できるようにする。

## 決定

1. 構造化ログのJSON契約は、ログモデルで意味上まとまりを持つ構造を可能な範囲でそのまま表現する。
2. `EventSpec`に属する情報はJSONでも`spec`としてまとめ、`LogEvent`の型構造との不要なflatten差をなくす。
3. Haskell側では、構造がJSON契約と対応する型にAesonのGeneric導出を利用する。
4. `SchemaV1 -> 1`、`RAGScopeApp -> "ragscope_app"`、時刻形式など、外部表現として独自の値が必要な箇所は型ごとの`ToJSON`またはAesonの設定で表現する。Haskellのconstructor名やGenericのデフォルト表現を、そのままJSON契約へ露出させない。
5. JSON Schemaは引き続きJSON契約の正本とし、ADR-0002で決定した実装技術に依存しない共通契約とコンポーネント実装の分離を維持する。

## 検討した選択肢

### 現在のJSON構造を維持する

既存Schemaを変更せずに済む一方、Haskell内部の意味上の構造との差を手書きのJSON変換で継続して吸収する必要があるため採用しない。

### ログモデルの型構造とJSON構造を整合させる

意味上の構造をHaskellとJSONで共有でき、手続的な構造変換を減らしてGenericと型ごとの`ToJSON`による宣言的なserializationへ寄せられるため採用する。

## 結果と影響

- `log-event.schema.json`とvalid / invalid fixtureを新しいJSON構造へ更新する。
- RAGScopeアプリケーションのJSON変換を、Generic導出と必要最小限の型別変換を中心とした実装へ整理する。
- 現在設計を[構造化ログ設計](../design/structured-logging/構造化ログ設計.md)、[RAGScopeアプリケーション構造化ログ設計](../design/structured-logging/RAGScopeアプリケーション構造化ログ設計.md)、[構造化ログJSON表現設計](../design/structured-logging/構造化ログJSON表現設計.md)の責務へ分けて管理する。
- RS-0015のSchema適合テストは、更新後のSchemaとfixtureを対象に実装する。

## 関連文書

- [ADR-0002 — 共通実行基盤の契約とコンポーネント実装を分離する](<./ADR-0002 共通実行基盤の契約とコンポーネント実装を分離する.md>)
- [構造化ログ設計](../design/structured-logging/構造化ログ設計.md)
- [RAGScopeアプリケーション構造化ログ設計](../design/structured-logging/RAGScopeアプリケーション構造化ログ設計.md)
- [構造化ログJSON表現設計](../design/structured-logging/構造化ログJSON表現設計.md)
- [RS-0015 RAGScopeアプリケーションの共通エラー・構造化ログ基盤を実装する](<../project-management/milestones/v0.0/error-logging/RS-0015 RAGScopeアプリケーションの共通エラー・構造化ログ基盤を実装する.md>)
