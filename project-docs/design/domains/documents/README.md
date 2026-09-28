# 文書**（`documents`）**

このディレクトリは、[RAGScopeドメインモデル](../../RAGScopeドメインモデル.md)で定義する「文書」ドメインの機能設計の入口・索引である。

「文書」ドメインは、技術文書を取り込み、文書バージョンと分割条件を区別しながら文書チャンクと検索用データを準備する。質問を使った検索や回答生成そのものは「検索・回答生成」ドメインで扱う。

## 機能構成

```mermaid
flowchart TB
    subgraph UseCases["文書に関するUseCase"]
        RegisterUC["文書を登録する"]
        CollectionUC["文書集合を管理する"]
        SearchableUC["文書を検索可能にする"]
    end

    subgraph Functions["文書ドメインの機能"]
        Ingest["文書取り込み"]
        Manage["文書・文書バージョン管理"]
        Split["文書分割"]
        Prepare["検索用データ準備"]
    end

    subgraph Data["文書ドメインで扱うデータ"]
        Collection["文書集合"]
        Document["文書"]
        Version["文書バージョン"]
        Chunk["文書チャンク"]
        SearchData["検索用データ"]
    end

    RegisterUC -->|"文書形式 / 文書内容<br>登録 / 更新の指定"| Ingest
    Ingest --> Manage
    Manage --> Document
    Manage --> Version

    CollectionUC -->|"文書集合の作成<br>文書の追加 / 除外"| Manage
    Manage -->|"保存 / 取得"| Collection

    Version --> Split
    SearchableUC -->|"分割条件<br>チャンクサイズ / 重複範囲"| Split
    Split --> Chunk

    Chunk --> Prepare
    SearchableUC -->|"準備対象<br>全文検索 / dense検索<br>+ 検索方式固有条件"| Prepare
    Prepare --> SearchData

    SearchData --> Retrieval["検索・回答生成ドメイン"]
```

図の上段は[ユースケース設計「2.1 文書」](../../ユースケース設計.md#21-文書)で定義するUseCase、中段はこのディレクトリで設計する機能、下段は文書ドメインで扱う主要なデータを示す。矢印のラベルは、UseCaseから各機能へ渡す主要な入力または機能が管理・生成するデータを示す。

| 設計書 | 扱う内容 |
|---|---|
| [文書取り込み設計](./文書取り込み設計.md) | Markdown / TXTの技術文書を正規化し、文書と文書バージョンとして登録・更新する |
| [文書・文書バージョン管理設計](<./文書・文書バージョン管理設計.md>) | 文書集合、文書、文書バージョンを識別し、競合する更新で現在の文書バージョンを巻き戻さない |
| [文書分割設計](./文書分割設計.md) | 文書バージョンを分割条件に従って文書チャンクへ分割し、文書内の位置を保持する |
| [検索用データ準備設計](./検索用データ準備設計.md) | 指定された検索方式に必要な検索用データを準備し、`ready`の検索用データ準備単位だけを「検索・回答生成」ドメインで利用できるようにする |
