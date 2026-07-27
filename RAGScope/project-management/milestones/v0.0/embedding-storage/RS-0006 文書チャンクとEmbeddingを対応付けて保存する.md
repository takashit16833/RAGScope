---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding生成と保存]]"
---
# RS-0006 文書チャンクとEmbeddingを対応付けて保存する

## 目的

v0.0のdense検索で文書チャンクを検索対象として利用するためには、RS-0002で生成した文書チャンクと、RS-0004でRAGScopeアプリケーションが取得したEmbeddingを対応付け、RS-0005で作成したPostgreSQLのDB schemaへ正しく保存する必要がある。

このTicketでは、RS-0012の初期設計に従い、RAGScopeアプリケーションが文書チャンクのEmbedding取得からPostgreSQLへの永続化までを制御する。元文書を識別する情報、`chunkIndex`、本文、Embeddingの対応を崩さずに保存し、保存後に読み出して後続のdense検索で利用できる状態であることを確認する。

## 前提

- [RS-0012 文書チャンクのEmbedding生成と保存を設計する](<./RS-0012 文書チャンクのEmbedding生成と保存を設計する.md>)が完了している
- `RS-0002`が完了し、文書チャンクを生成できる
- [RS-0004 RAGScopeアプリケーションで文書チャンクのEmbeddingを取得する](<./RS-0004 RAGScopeアプリケーションで文書チャンクのEmbeddingを取得する.md>)が完了している
- [RS-0005 PostgreSQLに文書チャンクとEmbeddingを保存するデータ構造を作成する](<./RS-0005 PostgreSQLに文書チャンクとEmbeddingを保存するデータ構造を作成する.md>)が完了している

## 完了条件

- [ ] 1件以上の文書チャンクを、Embedding取得と保存を行うRAGScopeアプリケーションの処理へ渡せる
- [ ] RS-0004の処理を利用し、RAGScopeアプリケーションで各文書チャンクに対応するEmbeddingを取得できる
- [ ] 保存前に、チャンク件数とEmbedding件数、対応する識別情報、vector次元が整合していることを確認できる
- [ ] 元文書を識別する情報、`chunkIndex`、チャンク本文、対応するEmbeddingを、RS-0005で作成したDB schemaへ保存できる
- [ ] 複数の文書チャンクとEmbeddingを、対応関係を崩さずに1回の処理として保存できる
- [ ] 保存したrecordをPostgreSQLから読み出し、元文書を識別する情報、`chunkIndex`、本文、Embeddingが保存前の値と対応していることを確認できる
- [ ] 保存済みrecordを`chunkIndex`順に取得し、文書内での順序を確認できる
- [ ] 保存したEmbeddingが、後続のexact vector searchで使用できるpgvectorの値として読み出せる
- [ ] AI推論サービスを利用できない場合またはEmbedding生成に失敗した場合に、新しい検索対象データを保存しない
- [ ] PostgreSQLへ接続できない場合を、正常な保存と区別して扱える
- [ ] DB制約違反、SQL実行失敗、transaction失敗を、正常な保存と区別して扱える
- [ ] 複数件の保存途中で失敗した場合にtransactionをrollbackし、今回の処理による一部のチャンクだけを残さない
- [ ] AI推論サービスへのrequestをDB transactionの開始前に完了し、モデル推論中にtransactionを保持しない
- [ ] 同じ固定文書の取り込みを設計で定めた方法により再実行でき、識別不能な重複recordが増えない
- [ ] 正常系、Embedding取得失敗、DB接続失敗、保存途中の失敗、再実行時の挙動を自動テストまたはDB integration testで確認できる
- [ ] 実際に起動したAI推論サービスとPostgreSQLを使用し、文書チャンクの受け渡し、Embedding生成、保存、読み出しまでを一連の処理として実行できる
- [ ] 固定Markdown文書の読み込み、チャンク化、Embedding取得、PostgreSQLへの保存までを、テスト専用ではない明示的な実行入口から起動できる
- [ ] 実装で具体化または変更された保存フロー、transaction境界、再実行時の扱いが`docs/design/データモデル設計.md`へ反映されている
- [ ] 実装とデータモデル設計に解消していない差異がない
- [ ] プロジェクトで定めたRAGScopeアプリケーション側とDB側のテストコマンドを実行し、追加した確認を含めて成功する

## 対象外

- AI推論サービスでのEmbedding model選定とEmbedding生成APIの新規実装
- RAGScopeアプリケーションとAI推論サービス間のAPI clientの新規実装
- PostgreSQL / pgvectorの導入、DB schema、migrationの新規作成
- 質問文の入力と質問Embeddingの生成
- dense検索query、順位付け、上位チャンクの取得
- 検索結果のCLI表示
- PostgreSQL全文検索、hybrid検索、reranking
- Generation modelによる回答生成と引用
- 文書、文書集合、チャンク条件、Embedding条件のversion管理
- 複数のEmbedding modelまたは生成条件の切り替え・比較
- 検索結果、実験条件、回答、引用、評価結果の保存
- Embedding cache
- 大規模batch処理、非同期job、分散transaction
- AWSへの配置

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../docs/RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ「3.1 RAGScopeアプリケーションの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.1 RAGScopeアプリケーションの責務境界>)
- [システムアーキテクチャ「3.2 AI推論サービスの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.2 AI推論サービスの責務境界>)
- [システムアーキテクチャ「3.3 PostgreSQLの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.3 PostgreSQLの責務境界>)
- [システムアーキテクチャ「5. RAGScopeアプリケーションとAI推論サービスの通信」](<../../../../docs/design/システムアーキテクチャ.md#5. RAGScopeアプリケーションとAI推論サービスの通信>)
- [システムアーキテクチャ「6. 文書取り込みの全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#6. 文書取り込みの全体フロー>)
- [文書処理設計](<../../../../docs/design/文書処理設計.md>)
- [Embedding生成設計](<../../../../docs/design/Embedding生成設計.md>)
- [データモデル設計](<../../../../docs/design/データモデル設計.md>)

## 実装メモ

- RAGScopeアプリケーションが、文書チャンクのEmbedding取得、対応関係の検証、PostgreSQLへの保存順序を制御する。
- AI推論サービスからPostgreSQLへ直接アクセスさせず、AI推論と永続化の責務境界を維持する。
- 複数件のDB書き込みは1つのtransactionで実行し、すべて成功した場合だけcommitする。
- 再実行時の既存データの扱いは、データモデル設計で定めた初期方針に従う。通常の実行手順から外れた手作業を必要としないものとする。
- 保存処理と読み出し処理は、テストおよび後続のdense検索から利用できる関数またはrepositoryとして分離する。
- 文書取り込みの実行入口は、固定文書を取り込むCLI subcommand、専用executableなど、通常の利用手順から起動できる最小の形とする。正確なcommand名や構成は実装時に決定する。
- SQLはparameterized queryを使用し、文書本文やvector値を文字列連結でqueryへ埋め込まない。
- 正確なSQL、repositoryの型、関数名、transaction APIはコードを正本とする。
- 初期設計を変更する必要が生じた場合は、後続の検索処理への影響を確認してから`データモデル設計.md`を更新する。

## 結果

> [!note] 完了時に記入
> - 実装した保存・読み出し処理
> - transaction境界と再実行時の扱い
> - 実装した文書取り込みの実行入口
> - 実行したテストコマンドと結果
> - AI推論サービス・PostgreSQLを使用した一連の確認結果
> - データモデル設計へ反映した内容
> - 既知の制約
> - 関連Pull Request
