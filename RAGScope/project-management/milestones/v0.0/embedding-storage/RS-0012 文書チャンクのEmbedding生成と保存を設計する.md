---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding生成と保存]]"
---
# RS-0012 文書チャンクのEmbedding生成と保存を設計する

## 目的

このEpicでは、Python AI ServiceによるEmbedding生成、HaskellとのHTTP / JSON通信、PostgreSQL / pgvectorのデータ構造、文書チャンクとEmbeddingの保存を複数の実装Ticketで構築する。これらは、採用するEmbedding model、生成条件、API契約、vector次元、保存するデータの関係を共有している。

このTicketでは、RS-0003からRS-0006へ着手する前に、文書チャンクのEmbedding生成から保存までの初期設計を行う。現在設計の正本として`docs/design/Embedding生成設計.md`と`docs/design/データモデル設計.md`を作成し、Python AI Serviceの文書Embedding生成APIについてOpenAPIなどの機械可読な初期定義を作成する。

初期設計では、後続Ticketが実装へ着手できる判断基準とコンポーネント間の契約を整える。正確なHaskell・Pythonの型、SQL、migrationの定義は、それぞれの機械可読な正本で実装時に確定する。

## 前提

- `RS-0002`までに、固定Markdown文書から後続処理へ渡せる文書チャンクを生成できる見通しが立っている
- `docs/design/文書処理設計.md`に、文書チャンクが保持する概念上の情報と不変条件が記載されている

## 完了条件

- [ ] `docs/design/Embedding生成設計.md`が`note_type: design`の機能設計書として作成されている
- [ ] `docs/design/データモデル設計.md`が`note_type: design`の機能設計書として作成されている
- [ ] Haskell、Python AI Service、PostgreSQL / pgvectorの責務と、文書チャンクの受け渡しから保存までの全体フローが記載されている
- [ ] v0.0で使用するEmbedding modelが1つ選定され、model ID、revision、Tokenizer、Tokenizer revisionを固定する方針が記載されている
- [ ] 採用候補について、ローカル環境での利用可能性とRAGScopeでの利用を妨げるライセンス上の問題がないことを確認できる
- [ ] 文書用・質問用の入力規則、pooling、最大入力長、truncation、vector正規化の有無、出力次元が固定条件として記載されている
- [ ] 文書用と質問用のEmbeddingを比較可能に保つ互換条件が記載されている
- [ ] Python AI ServiceがAI推論を担当し、Haskellが処理全体とデータの対応関係を管理する責務境界が記載されている
- [ ] 文書Embedding生成APIの入力、出力、入力とEmbeddingの対応方法、主要なエラー分類が設計されている
- [ ] 文書Embedding生成APIの正確なrequest / responseがOpenAPIなどの機械可読な初期定義として作成されている
- [ ] 生存確認、推論可能状態、使用中のmodel・revision・出力次元を確認する方法が設計されている
- [ ] 文書チャンクとEmbeddingを保存する最小のデータ構造について、保持する情報、責務、関係、不変条件が記載されている
- [ ] 元文書を識別する情報と`chunkIndex`によってv0.0のチャンクを一意に扱い、チャンク本文とEmbeddingの対応を維持する方針が記載されている
- [ ] Embedding列が選定モデルの固定出力次元と一致し、不完全な検索対象や負の`chunkIndex`を許可しない方針が記載されている
- [ ] 複数チャンクの保存におけるtransaction境界と、Embedding生成中にDB transactionを保持しない方針が記載されている
- [ ] 同じ固定文書の取り込みを再実行した場合に、識別不能な重複を残さない初期方針が記載されている
- [ ] DBの正確なテーブル・カラム・制約はmigration、API schemaはOpenAPI、型はコードを正本とすることが明記されている
- [ ] v0.0では導入しないmodel比較、Embedding条件のversion管理、Embedding cache、近似検索indexなどの境界が記載されている
- [ ] 関連する要求定義、システムアーキテクチャ、文書処理設計に矛盾しないことを確認できる
- [ ] 所属Epicの`関連文書`から、作成した設計書を参照できる状態になっている

## 対象外

- Python AI Serviceの実装
- HaskellのHTTP clientの実装
- PostgreSQL / pgvectorのmigration作成
- 文書チャンクとEmbeddingの保存処理の実装
- 質問Embedding生成APIの実装
- exact vector searchとCLIの設計・実装
- 複数のEmbedding modelを実測比較するExperiment
- Haskell・Pythonの正確な型名、関数名、package構成の確定
- DBの正確なテーブル名、カラム名、SQL、制約名の確定

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../docs/RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ「3.1 Haskellの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.1 Haskellの責務境界>)
- [システムアーキテクチャ「3.2 Pythonの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.2 Pythonの責務境界>)
- [システムアーキテクチャ「3.3 PostgreSQLの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.3 PostgreSQLの責務境界>)
- [システムアーキテクチャ「5. HaskellとPythonの通信」](<../../../../docs/design/システムアーキテクチャ.md#5. HaskellとPythonの通信>)
- [システムアーキテクチャ「6. 文書取り込みの全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#6. 文書取り込みの全体フロー>)
- [文書処理設計](<../../../../docs/design/文書処理設計.md>)

## 実装メモ

- モデル選定は精度比較ではなく、v0.0のローカル環境で実行できること、文書用と質問用のEmbeddingを互換に生成できること、revisionを固定できること、ライセンス上利用可能であることを基準に行う。
- 質問Embeddingの生成処理自体は後続Epicで実装するが、文書Embeddingとの互換性を確保するため、質問用の入力規則はこの時点で設計する。
- OpenAPIの初期定義は、RS-0003で実装する文書Embedding生成の契約を対象とする。質問Embeddingに必要な契約は、後続Epicの初期設計Ticketで追加または更新する。
- `データモデル設計.md`にはmigrationを複製せず、保存対象の責務、関係、不変条件、transactionと再実行の方針を記載する。
- 実装によって初期設計を変更する必要が生じた場合は、該当する実装TicketでOpenAPI・設計書・実装を同じ変更として整合させる。

## 結果

> [!note] 完了時に記入
> - 選定したEmbedding modelと固定条件
> - 作成したEmbedding生成設計の概要
> - 作成したデータモデル設計の概要
> - 作成したOpenAPIなどのAPI初期定義
> - 実装Ticketへ残した判断事項
> - 更新したEpicの関連文書
> - 既知の未決定事項
> - 関連Pull Request
