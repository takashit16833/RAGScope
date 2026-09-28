# 文書**（`documents`）**

このディレクトリは、[RAGScopeドメインモデル](../../RAGScopeドメインモデル.md)で定義する「文書」ドメインの機能設計の入口・索引である。

「文書」ドメイン自体の責務は[RAGScopeドメインモデル](../../RAGScopeドメインモデル.md)を正本とする。配下では、その責務を機能単位に一段具体化して設計する。

## 機能構成

```mermaid
flowchart LR
    TechnicalDocument["技術文書"]
    Ingest["文書取り込み"]
    Manage["文書・版管理"]
    Collection["文書集合"]
    Document["文書"]
    Version["文書バージョン"]
    Condition["分割条件"]
    Split["文書分割"]
    Chunk["文書チャンク"]
    Prepare["検索用データ準備"]
    SearchData["検索用データ"]

    TechnicalDocument --> Ingest
    Ingest -->|"登録"| Manage
    Manage --- Collection
    Manage --> Document
    Document --> Version
    Version --> Split
    Condition --> Split
    Split --> Chunk
    Chunk --> Prepare
    Prepare --> SearchData
```

| 設計書 | 扱う内容 |
|---|---|
| [文書取り込み設計](./文書取り込み設計.md) | 技術文書をRAGScopeへ取り込み、文書と文書バージョンとして登録する処理 |
| [文書・版管理設計](<./文書・版管理設計.md>) | 文書集合、文書、文書バージョンの識別、関係、保存、更新 |
| [文書分割設計](./文書分割設計.md) | 文書バージョンを分割条件に従って文書チャンクへ分割する処理 |
| [検索用データ準備設計](./検索用データ準備設計.md) | 文書チャンクから検索用データを生成・保持する処理 |
|
