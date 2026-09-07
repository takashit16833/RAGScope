# 設計文書

RAGScopeの現在設計を、知りたい内容から参照するための索引である。

## 設計文書の一覧

| 文書・設計領域 | 確認したいこと |
|---|---|
| [RAGScopeドメインモデル](./RAGScopeドメインモデル.md) | RAGScopeの問題領域をどの領域に分け、それぞれが何を担当するか |
| [RAGScope要求定義](../RAGScope要求定義.md) | RAGScopeは何をできなければならないか |
| [ユースケース設計](./ユースケース設計.md) | 利用者のトップレベルな操作は何で、1回の実行はどこからどこまでか |
| [システムアーキテクチャ](./システムアーキテクチャ.md) | どのコンポーネントが何を担当し、どうつながるか |
| [Observability設計](./observability/README.md) | 実行・イベント・集約値をTrace・Logs・Metricsでどう観測し、OpenTelemetryとRAGScopeの責務をどう分けるか |
| [機能設計](./features/README.md) | 個別機能はどの処理規則、入出力、失敗時の扱いで動くか |

## 全体の関係

矢印は、リンクの向きではなく、後段の設計が前段の設計内容を前提にする方向を表す。

```mermaid
flowchart TD
    Domain["RAGScopeドメインモデル<br>問題領域と各領域の責務"]
    Requirements["RAGScope要求定義<br>RAGScopeが満たすべき要求"]

    subgraph Core["RAGScope全体の設計"]
        UseCase["ユースケース設計<br>トップレベルな操作と1回の実行境界"]
        Architecture["システムアーキテクチャ<br>コンポーネント構成・責務・連携"]
        Observability["Observability設計<br>Trace・Logs・Metricsの共通規則"]
        UseCase --> Architecture
        Architecture --> Observability
    end

    subgraph Features["機能設計"]
        FeatureDesigns["各機能設計<br>個別機能の処理規則・入出力・失敗時の扱い"]
    end

    Domain --> UseCase
    Requirements --> UseCase
    Domain --> Architecture
    Requirements --> Architecture
    Requirements --> Observability

    Architecture --> Features
    Observability --> Features
```

## 読み分け

利用者がRAGScopeへ何を依頼し、その1回の操作をどこまでユースケース実行として扱うかは[ユースケース設計](./ユースケース設計.md)を確認する。その処理をどのコンポーネントが担当し、AI推論サービスやデータベースとどう連携するかは[システムアーキテクチャ](./システムアーキテクチャ.md)を確認する。

1回の外部呼び出しをどのTrace・Spanで追跡し、LogsとMetricsをどう使い分けるかは[Observability設計](./observability/README.md)を確認する。個別機能の具体的なSpan、EventRecord、属性、失敗条件は、その機能を担当する[機能設計](./features/README.md)で具体化する。

正確な項目名、型、必須条件、API Schema、DB制約、具体的なテストケースは、コード、JSON Schema、OpenAPI、migration、テストなどの機械可読な正本を参照する。
