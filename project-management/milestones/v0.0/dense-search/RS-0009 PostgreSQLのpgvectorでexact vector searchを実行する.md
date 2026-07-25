---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 質問によるdense検索の実行]]"
---
# RS-0009 PostgreSQLのpgvectorでexact vector searchを実行する

## 目的

v0.0で質問に近い文書チャンクを取得するためには、RS-0008でHaskellから取得した質問Embeddingと、RS-0006でPostgreSQL / pgvectorへ保存した文書チャンクEmbeddingの距離を比較し、近い順に文書チャンクを取得する必要がある。

このTicketでは、v0.0で使用する距離尺度と取得件数を1つずつ固定し、HaskellからPostgreSQLへparameterized queryを実行するdense検索処理を実装する。HNSW / IVFFlatなどの近似検索indexは使用せず、保存済みのすべての対象Embeddingを比較するexact vector searchとして実行する。

検索結果は、順位、距離または類似度、元文書を識別する情報、`chunkIndex`、チャンク本文を保持し、後続のHaskell CLI表示処理から利用できる値として返す。

## 完了条件

- [ ] RS-0003で固定したEmbedding生成条件と整合する、v0.0で使用する距離尺度が1つ決定されている
- [ ] v0.0で取得する上位チャンク件数が固定値として1つ決定されている
- [ ] RS-0008で取得した質問Embeddingを、PostgreSQL / pgvectorの検索queryへ安全に渡せる
- [ ] 質問Embeddingと保存済みの文書チャンクEmbeddingを、決定した距離尺度で比較できる
- [ ] HNSW / IVFFlatなどの近似検索indexを使用せず、exact vector searchとして検索できる
- [ ] 検索結果を質問との近さに従って並べ、固定件数までの上位チャンクを取得できる
- [ ] 検索対象件数が固定取得件数より少ない場合、存在する検索結果だけを正常に取得できる
- [ ] 検索対象となる文書チャンクが存在しない場合、検索失敗ではなく空の検索結果として扱える
- [ ] 各検索結果について、1始まりの順位、距離または類似度、元文書を識別する情報、`chunkIndex`、チャンク本文をHaskellの値として取得できる
- [ ] 同じ距離の結果が存在する場合でも、定めた補助順序によって再実行可能な順序で取得できる
- [ ] 質問Embeddingのvector次元がDB schemaの次元と一致しない場合を、正常な検索と区別して扱える
- [ ] PostgreSQLへ接続できない場合とSQL実行に失敗した場合を、正常な検索と区別して扱える
- [ ] SQLへ質問Embeddingや取得件数を文字列連結で埋め込まず、parameterized queryとして実行できる
- [ ] 既知のvectorを持つテストデータをPostgreSQLへ保存し、期待する距離順、順位、取得件数、各チャンク情報をDB integration testで確認できる
- [ ] 空の検索対象、固定取得件数未満の検索対象、同距離、vector次元不一致を含む境界条件を自動テストまたはDB integration testで確認できる
- [ ] exact vector searchの距離尺度、取得件数、順位付け、検索結果が保持する情報を`docs/design/検索設計.md`へ記載できる
- [ ] 必要に応じて、検索結果の取得に関係するデータの責務や不変条件を`docs/design/データモデル設計.md`へ反映できる
- [ ] プロジェクトで定めたHaskell側とDB側のテストコマンドを実行し、追加した確認を含めて成功する

## 対象外

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
- [システムアーキテクチャ「7. 質問と実験の全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#7. 質問と実験の全体フロー>)
- [Embedding生成設計](<../../../../docs/design/Embedding生成設計.md>)
- [データモデル設計](<../../../../docs/design/データモデル設計.md>)
- [検索設計](<../../../../docs/design/検索設計.md>)（本Ticketで作成）

## 実装メモ

- dense検索の実行と検索結果の組み立てはHaskellが制御し、PostgreSQLはpgvectorによる距離計算と並べ替えを担当する。
- 距離尺度は、RS-0003で採用したモデルの推奨方法、vector正規化の有無、文書用・質問用Embeddingの互換性を確認して1つに固定する。複数方式の比較はv0.1以降で扱う。
- 取得件数もv0.0の固定条件として1つに定め、利用者が変更する設定機能は作らない。正確な定数名や配置はコードを正本とする。
- 検索queryはRS-0005で作成したDB schemaを利用し、RS-0006で保存した検索対象だけを参照する。
- exact vector searchであることは、近似検索indexを作成・使用しないことと、pgvectorの距離演算子を使用して全対象から並べ替えるqueryであることによって確認する。
- 距離が同値の場合の補助順序には、元文書を識別する値と`chunkIndex`など、保存済みの一意かつ安定した値を使用する。
- 検索結果用のHaskell型は、少なくとも順位、距離または類似度、元文書の識別情報、`chunkIndex`、本文を保持する。正確な型名とフィールド名はコードを正本とする。
- SQLの正確な構文、距離演算子、repositoryの関数名はコードを正本とし、Markdownへ複製しない。
- integration testでは、距離関係を手計算または明確に判断できる小さなvectorを使用し、モデルの検索品質へ依存せず順位付けを確認する。
- v0.0では少量の固定文書を同期的に検索し、性能測定やindex比較は行わない。

## 結果

> [!note] 完了時に記入
> - 採用した距離尺度と上位取得件数
> - 実装したexact vector searchと検索結果型
> - 使用した補助順序
> - 実行したテストコマンドと結果
> - PostgreSQL / pgvectorを使用した検索確認結果
> - 作成または更新した検索設計・データモデル設計
> - 既知の制約
> - 関連Pull Request
