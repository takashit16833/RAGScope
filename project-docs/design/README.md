# 設計文書

RAGScopeの現在設計を、知りたい内容から確認するための入口である。

## 全体設計

| 文書 | 確認すること |
|---|---|
| [RAGScopeドメインモデル](./RAGScopeドメインモデル.md) | RAGScopeをどの領域に分け、それぞれが何を担当するか |
| [ユースケース設計](./ユースケース設計.md) | 利用者がRAGScopeへ依頼するトップレベルな操作 |
| [システムアーキテクチャ](./システムアーキテクチャ.md) | コンポーネント構成、責務、連携、失敗の基本的な扱い |
| [Observability設計](./observability/README.md) | Trace、Logs、Metricsをどう使うか |

RAGScopeが満たすべき要求は[RAGScope要求定義](../RAGScope要求定義.md)、正式用語は[RAGScope用語集](../RAGScope用語集.md)を参照する。

## ドメイン別設計

| ドメイン | 入口 |
|---|---|
| 文書 | [文書](./domains/documents/README.md) |
| 評価データ | [評価データ](./domains/evaluation-data/README.md) |
| 検索・回答生成 | [検索・回答生成](./domains/retrieval-generation/README.md) |
| 実験・評価 | [実験・評価](./domains/experiment-evaluation/README.md) |

正確な型、API、DB制約、設定、テストケースなど、実装で機械可読に表現できる内容はコード、Schema、migration、設定、テストを正本とする。
