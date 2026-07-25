---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding生成と保存]]"
---
# RS-0006 文書チャンクとEmbeddingを対応付けて保存する

## 目的

v0.0のdense検索で文書チャンクを検索対象として利用するためには、RS-0002で生成した文書チャンクと、RS-0004でHaskellから取得したEmbeddingを対応付け、RS-0005で作成したPostgreSQLのDB schemaへ正しく保存する必要がある。

このTicketでは、Haskellが文書チャンクのEmbedding取得からPostgreSQLへの永続化までを制御する。元文書を識別する情報、`chunkIndex`、本文、Embeddingの対応を崩さずに一括して保存し、保存後に読み出して後続のdense検索で利用できる状態であることを確認する。

Embedding生成またはDB保存の途中で失敗した場合に、不完全なチャンクとEmbeddingの対応を検索対象として残さない。

## 完了条件

- [ ] RS-0002で生成した1件以上の文書チャンクを、Embedding取得と保存を行うHaskellの処理へ渡せる
- [ ] RS-0004の処理を利用し、各文書チャンクに対応するEmbeddingをHaskellから取得できる
- [ ] 保存前に、チャンク件数とEmbedding件数、対応する識別情報、vector次元が整合していることを確認できる
- [ ] 元文書を識別する情報、`chunkIndex`、チャンク本文、対応するEmbeddingを、RS-0005で作成したDB schemaへ保存できる
- [ ] 複数の文書チャンクとEmbeddingを、対応関係を崩さずに1回の処理として保存できる
- [ ] 保存したレコードをPostgreSQLから読み出し、元文書を識別する情報、`chunkIndex`、本文、Embeddingが保存前の値と対応していることを確認できる
- [ ] 保存済みレコードを`chunkIndex`順に取得し、文書内での順序を確認できる
- [ ] 保存したEmbeddingが、後続のexact vector searchで使用できるpgvectorの値として読み出せる
- [ ] Python AI Serviceを利用できない場合またはEmbedding生成に失敗した場合に、新しい検索対象データを保存しない
- [ ] PostgreSQLへ接続できない場合を、正常な保存と区別して扱える
- [ ] DB制約違反、SQL実行失敗、transaction失敗を、正常な保存と区別して扱える
- [ ] 複数件の保存途中で失敗した場合にtransactionをrollbackし、今回の処理による一部のチャンクだけを残さない
- [ ] 同じ固定文書の取り込みを定めた手順で再実行でき、再実行によって識別不能な重複レコードが増えない
- [ ] 正常系、Embedding取得失敗、DB接続失敗、保存途中の失敗、再実行時の挙動を自動テストまたはDB integration testで確認できる
- [ ] 実際に起動したPython AI ServiceとPostgreSQLを使用し、文書チャンクの受け渡し、Embedding生成、保存、読み出しまでを一連の処理として実行できる
- [ ] 固定Markdown文書の読み込み、チャンク化、Embedding取得、PostgreSQLへの保存までを、テスト専用ではない明示的な実行入口から起動できる
- [ ] 文書チャンクとEmbeddingの保存フロー、transaction境界、再実行時の既存データの扱いを`docs/design/データモデル設計.md`へ反映できる
- [ ] プロジェクトで定めたHaskell側とDB側のテストコマンドを実行し、追加した確認を含めて成功する

## 対象外

- Python AI ServiceでのEmbedding model選定とEmbedding生成APIの実装
- HaskellとPython AI Service間のAPI clientの新規実装
- PostgreSQL / pgvectorの導入、DB schema、migrationの新規作成
- 質問文の入力と質問Embeddingの生成
- dense検索query、順位付け、上位チャンクの取得
- 検索結果のCLI表示
- PostgreSQL全文検索、hybrid検索、reranking
- Generation modelによる回答生成と引用
- 文書、文書集合、チャンク条件、Embedding条件のバージョン管理
- 複数のEmbedding modelまたは生成条件の切り替え・比較
- 検索結果、実験条件、回答、引用、評価結果の保存
- Embedding cache
- 大規模batch処理、非同期job、分散transaction
- AWSへの配置

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../docs/RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ「3.1 Haskellの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.1 Haskellの責務境界>)
- [システムアーキテクチャ「3.2 Pythonの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.2 Pythonの責務境界>)
- [システムアーキテクチャ「3.3 PostgreSQLの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.3 PostgreSQLの責務境界>)
- [システムアーキテクチャ「5. HaskellとPythonの通信」](<../../../../docs/design/システムアーキテクチャ.md#5. HaskellとPythonの通信>)
- [システムアーキテクチャ「6. 文書取り込みの全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#6. 文書取り込みの全体フロー>)
- [文書処理設計](<../../../../docs/design/文書処理設計.md>)
- [Embedding生成設計](<../../../../docs/design/Embedding生成設計.md>)
- [データモデル設計](<../../../../docs/design/データモデル設計.md>)

## 実装メモ

- Haskellが、文書チャンクのEmbedding取得、対応関係の検証、PostgreSQLへの保存順序を制御する。
- Python AI ServiceからPostgreSQLへ直接アクセスさせず、AI推論と永続化の責務境界を維持する。
- DBへ保存する前に、RS-0004で検証済みの対応関係を利用し、元文書を識別する情報、`chunkIndex`、本文、Embeddingを1つの保存対象として扱う。
- 複数件のDB書き込みは1つのtransactionで実行し、すべて成功した場合だけcommitする。
- Python AI ServiceへのrequestはDB transactionの開始前に完了させ、モデル推論中にDB transactionを長時間保持しない。
- 再実行時の既存データの扱いは、同じ元文書と`chunkIndex`を置換する、事前に対象データを削除して入れ直す、DBを初期化して再実行する、などからv0.0の最小構成に適した1つへ固定する。
- 再実行時の規則は、通常の実行手順から外れた手作業を必要とせず、検索対象の重複を曖昧にしないものとする。
- 保存処理と読み出し処理は、テストおよび後続のdense検索から利用できる関数またはrepositoryとして分離する。
- 文書取り込みの実行入口は、固定文書を取り込むCLI subcommand、専用executableなど、通常の利用手順から起動できる最小の形とする。正確なコマンド名や構成は実装時に決定する。
- integration testから内部関数を直接呼び出せることだけを、文書取り込みの実行入口が存在することの確認とはしない。
- SQLはparameterized queryを使用し、文書本文やvector値を文字列連結でqueryへ埋め込まない。
- 正確なSQL、repositoryの型、関数名、transaction APIはコードを正本とする。
- integration testでは、実際のPostgreSQLとpgvectorを使用して、保存値、対応関係、rollback、再実行時の挙動を確認する。
- v0.0では固定文書と少量チャンクを同期的に保存し、性能最適化や大量データ向けの処理は行わない。

## 結果

> [!note] 完了時に記入
> - 実装した保存・読み出し処理
> - 採用したtransaction境界
> - 採用した再実行時の既存データの扱い
> - 実装した文書取り込みの実行入口と実行方法
> - 実行したテストコマンドと結果
> - Python AI ServiceとPostgreSQLを使用した一連の実行結果
> - 正常系・主要な異常系の確認結果
> - 更新したデータモデル設計
> - 既知の制約
> - 関連Pull Request
