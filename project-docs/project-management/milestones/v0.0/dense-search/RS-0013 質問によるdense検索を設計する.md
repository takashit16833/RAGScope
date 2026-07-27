---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 質問によるdense検索の実行]]"
---
# RS-0013 質問によるdense検索を設計する

## 目的

v0.0の最後のEpicでは、質問Embeddingの生成、RAGScopeアプリケーションでの取得、PostgreSQL / pgvectorによるexact vector search、RAGScope CLIでの結果表示を複数の実装Ticketで構築する。これらは、質問入力から検索結果表示までの処理フロー、文書チャンクのEmbeddingとの互換性、距離尺度、取得件数、順位付け、エラーの扱いを共有している。

このTicketでは、RS-0007からRS-0010へ着手する前に、質問によるdense検索の初期設計を行い、現在設計の正本となる`design/検索設計.md`を作成する。あわせて、質問Embeddingに関する`design/Embedding生成設計.md`とOpenAPIなどの機械可読なAPI定義を更新する。

初期設計では、後続Ticketが実装へ着手できる判断基準とコンポーネント間の契約を整える。正確なSQL、Haskell・Pythonの型、CLI parserの構成は、それぞれの機械可読な正本で実装時に確定する。

## 前提

- 「v0.0 文書チャンクのEmbedding生成と保存」Epicが完了し、検索対象となる文書チャンクとEmbeddingをPostgreSQL / pgvectorへ保存できる
- `design/Embedding生成設計.md`と`design/データモデル設計.md`が現在の実装と一致している
- 文書チャンクのEmbeddingのmodel、revision、入力規則、vector正規化、出力次元が確定している

## 完了条件

- [ ] `design/検索設計.md`が`note_type: design`の機能設計書として作成されている
- [ ] RAGScope CLIの質問入力から、AI推論サービスによる質問Embedding生成、PostgreSQL / pgvector検索、上位チャンク表示までの全体フローが記載されている
- [ ] RAGScopeアプリケーション、AI推論サービス、PostgreSQL / pgvector、CLI表示の責務境界が記載されている
- [ ] 空でない質問を1件扱い、空文字または空白だけの質問を入力エラーとする方針が記載されている
- [ ] 質問Embeddingが文書チャンクのEmbeddingと同じmodel、revision、Tokenizer、生成条件、vector次元を使用する互換条件が記載されている
- [ ] 文書用と質問用で異なるprefixまたはinstructionが必要な場合の適用責務が記載されている
- [ ] 質問Embedding生成APIの入力、出力、主要なエラー分類が設計され、OpenAPIなどの機械可読な定義へ反映されている
- [ ] v0.0で使用する距離尺度が1つ決定され、Embeddingの正規化条件との整合が記載されている
- [ ] v0.0で取得する上位チャンク件数が固定値として1つ決定されている
- [ ] HNSW / IVFFlatなどの近似検索indexを使用せず、exact vector searchを行う方針が記載されている
- [ ] 同距離時の補助順序と、再実行可能な順位付けの方針が記載されている
- [ ] 検索結果が、順位、距離または類似度、元文書を識別する情報、`chunkIndex`、チャンク本文を保持することが記載されている
- [ ] 検索対象が0件の場合、固定取得件数未満の場合、vector次元が不一致の場合の扱いが記載されている
- [ ] AI推論サービスへの接続失敗、Embedding生成失敗、PostgreSQL接続失敗、検索失敗を区別する基本方針が記載されている
- [ ] RAGScope CLIの検索コマンド、標準出力・標準エラー出力、終了status、0件時の表示について初期方針が記載されている
- [ ] 固定Markdown文書の取り込みから検索結果表示までのend-to-end確認範囲が記載されている
- [ ] SQLの正確な構文はコード、API schemaはOpenAPI、CLIの正確な引数は実装と`--help`を正本とすることが明記されている
- [ ] v0.0では扱わない検索結果の永続化、全文検索、hybrid検索、reranking、回答生成、検索品質評価、近似検索indexの境界が記載されている
- [ ] 関連する要求定義、システムアーキテクチャ、Embedding生成設計、データモデル設計に矛盾しないことを確認できる
- [ ] 所属Epicの`関連文書`から`検索設計.md`を参照できる状態になっている

## 対象外

- 質問Embeddingを生成するPythonコードの実装
- RAGScopeアプリケーションの質問Embedding API clientの実装
- PostgreSQL / pgvectorの検索queryの実装
- RAGScope CLIの実装
- 文書チャンクとEmbeddingのDB schema変更
- 検索結果や質問の永続化
- 検索品質を比較するExperiment
- SQL、Haskell・Pythonの型、CLI parserの正確な実装詳細の確定

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../RAGScope要求定義.md#2.2 検索>)
- [RAGScope要求定義「2.7 実行とレポート」](<../../../../RAGScope要求定義.md#2.7 実行とレポート>)
- [システムアーキテクチャ「3.1 RAGScopeアプリケーションの責務境界」](<../../../../design/システムアーキテクチャ.md#3.1 RAGScopeアプリケーションの責務境界>)
- [システムアーキテクチャ「3.2 AI推論サービスの責務境界」](<../../../../design/システムアーキテクチャ.md#3.2 AI推論サービスの責務境界>)
- [システムアーキテクチャ「3.3 PostgreSQLの責務境界」](<../../../../design/システムアーキテクチャ.md#3.3 PostgreSQLの責務境界>)
- [システムアーキテクチャ「5. RAGScopeアプリケーションとAI推論サービスの通信」](<../../../../design/システムアーキテクチャ.md#5. RAGScopeアプリケーションとAI推論サービスの通信>)
- [システムアーキテクチャ「7. 質問と実験の全体フロー」](<../../../../design/システムアーキテクチャ.md#7. 質問と実験の全体フロー>)
- `design/Embedding生成設計.md`
- `design/データモデル設計.md`

## 実装メモ

- 距離尺度は、採用済みEmbedding modelの推奨方法、文書用・質問用の入力規則、vector正規化の有無を確認して決定する。
- 上位取得件数はv0.0の固定値として決定し、CLI optionや設定ファイルから変更する機能は設けない。
- 質問EmbeddingのAPIは、既存の文書チャンクのEmbedding生成APIを拡張または再利用する。用途の区別方法と正確な契約はOpenAPIを正本とする。
- `検索設計.md`にはSQLやCLI引数一覧を複製せず、検索の責務、契約、順位付け、不変条件、エラー・境界条件を記載する。
- 実装によって初期設計を変更する必要が生じた場合は、該当する実装Ticketで設計書・OpenAPI・実装を同じ変更として整合させる。

## 結果

> [!note] 完了時に記入
> - 作成した検索設計の概要
> - 決定した質問Embeddingの契約
> - 決定した距離尺度、上位取得件数、補助順序
> - 更新したEmbedding生成設計とOpenAPI
> - 実装Ticketへ残した判断事項
> - 更新したEpicの関連文書
> - 既知の未決定事項
> - 関連Pull Request
