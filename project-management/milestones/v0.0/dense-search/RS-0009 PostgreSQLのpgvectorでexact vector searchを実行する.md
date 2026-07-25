---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 質問によるdense検索の実行]]"
---
# RS-0009 PostgreSQLのpgvectorでexact vector searchを実行する

## 目的

v0.0で質問に近い文書チャンクを取得するためには、RS-0008でHaskellから取得した質問Embeddingと、RS-0006でPostgreSQL / pgvectorへ保存した文書チャンクEmbeddingの距離を比較し、近い順に文書チャンクを取得する必要がある。

このTicketでは、RS-0013で決定した距離尺度、上位取得件数、補助順序に従い、HaskellからPostgreSQLへparameterized queryを実行するdense検索処理を実装する。HNSW / IVFFlatなどの近似検索indexは使用せず、保存済みのすべての対象Embeddingを比較するexact vector searchとして実行する。

## 前提

- [RS-0013 質問によるdense検索を設計する](<./RS-0013 質問によるdense検索を設計する.md>)が完了している
- [RS-0008 Haskellから質問文のEmbeddingを取得する](<./RS-0008 Haskellから質問文のEmbeddingを取得する.md>)が完了している
- `RS-0006`が完了し、検索対象となる文書チャンクとEmbeddingがPostgreSQL / pgvectorへ保存されている
- `docs/design/検索設計.md`に距離尺度、上位取得件数、補助順序、検索結果の構造が記載されている

## 完了条件

- [ ] RS-0013で決定した距離尺度を使用し、質問Embeddingと保存済みの文書チャンクEmbeddingを比較できる
- [ ] RS-0013で決定した固定件数までの上位チャンクを取得できる
- [ ] 質問EmbeddingをPostgreSQL / pgvectorの検索queryへ安全に渡せる
- [ ] HNSW / IVFFlatなどの近似検索indexを使用せず、exact vector searchとして検索できる
- [ ] 検索結果を質問との近さに従って並べ、固定件数までの上位チャンクを取得できる
- [ ] 検索対象件数が固定取得件数より少ない場合、存在する検索結果だけを正常に取得できる
- [ ] 検索対象となる文書チャンクが存在しない場合、検索失敗ではなく空の検索結果として扱える
- [ ] 各検索結果について、1始まりの順位、距離または類似度、元文書を識別する情報、`chunkIndex`、チャンク本文をHaskellの値として取得できる
- [ ] 同じ距離の結果が存在する場合でも、設計で定めた補助順序によって再実行可能な順序で取得できる
- [ ] 質問Embeddingのvector次元がDB schemaの次元と一致しない場合を、正常な検索と区別して扱える
- [ ] PostgreSQLへ接続できない場合とSQL実行に失敗した場合を、正常な検索と区別して扱える
- [ ] SQLへ質問Embeddingや取得件数を文字列連結で埋め込まず、parameterized queryとして実行できる
- [ ] 既知のvectorを持つテストデータをPostgreSQLへ保存し、期待する距離順、順位、取得件数、各チャンク情報をDB integration testで確認できる
- [ ] 空の検索対象、固定取得件数未満の検索対象、同距離、vector次元不一致を含む境界条件を自動テストまたはDB integration testで確認できる
- [ ] 実装で具体化または変更されたexact vector searchの現在設計が`docs/design/検索設計.md`へ反映されている
- [ ] 必要な場合、検索結果の取得に関係するデータの責務や不変条件が`docs/design/データモデル設計.md`へ反映されている
- [ ] 実装、検索設計、データモデル設計に解消していない差異がない
- [ ] プロジェクトで定めたHaskell側とDB側のテストコマンドを実行し、追加した確認を含めて成功する

## 対象外

- 距離尺度、上位取得件数、補助順序を新たに比較・選定する作業
- Python AI Serviceで質問Embeddingを生成する処理
- HaskellからPython AI Serviceへ質問文を渡してEmbeddingを取得する処理
- PostgreSQL / pgvectorの導入、DB schema、migrationの新規作成
- 文書チャンクとEmbeddingの保存処理
- Haskell CLIの検索コマンドと質問入力UI
- 検索結果のCLI表示
- 検索結果、距離、順位、質問の永続化
- PostgreSQL全文検索、hybrid検索、reranking
- 回答生成へ渡すcontextの選択
- Generation modelによる回答生成と引用
- 検索品質の指標計算、評価データ、実験結果の保存・比較
- 距離尺度や取得件数をCLI、設定ファイル、データベースから変更する機能
- HNSW / IVFFlatなどの近似検索index
- 大量データ向けの性能最適化、query tuning、並列検索
- AWS RDSへの配置

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../docs/RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ「3.1 Haskellの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.1 Haskellの責務境界>)
- [システムアーキテクチャ「3.3 PostgreSQLの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.3 PostgreSQLの責務境界>)
- [システムアーキテクチャ「7. 質問処理の全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#7. 質問処理の全体フロー>)
- [Embedding生成設計](<../../../../docs/design/Embedding生成設計.md>)
- [データモデル設計](<../../../../docs/design/データモデル設計.md>)
- [検索設計](<../../../../docs/design/検索設計.md>)

## 実装メモ

- dense検索の実行と検索結果の組み立てはHaskellが制御し、PostgreSQLはpgvectorによる距離計算と並べ替えを担当する。
- 検索queryはRS-0005で作成したDB schemaを利用し、RS-0006で保存した検索対象だけを参照する。
- exact vector searchであることは、近似検索indexを作成・使用しないことと、pgvectorの距離演算子を使用して全対象から並べ替えるqueryであることによって確認する。
- 検索結果用のHaskell型は、設計で定めた情報を保持する。正確な型名とフィールド名はコードを正本とする。
- SQLの正確な構文、距離演算子、repositoryの関数名はコードを正本とし、Markdownへ複製しない。
- integration testでは、距離関係を手計算または明確に判断できる小さなvectorを使用し、モデルの検索品質へ依存せず順位付けを確認する。
- v0.0では少量の固定文書を同期的に検索し、性能測定やindex比較は行わない。
- 初期設計を変更する必要が生じた場合は、CLIとend-to-end確認への影響を確認してから`検索設計.md`を更新する。

## 結果

> [!note] 完了時に記入
> - 実装したexact vector searchと検索結果型
> - 使用した距離尺度、上位取得件数、補助順序
> - 実行したテストコマンドと結果
> - PostgreSQL / pgvectorを使用した検索確認結果
> - 検索設計・データモデル設計へ反映した内容
> - 既知の制約
> - 関連Pull Request
