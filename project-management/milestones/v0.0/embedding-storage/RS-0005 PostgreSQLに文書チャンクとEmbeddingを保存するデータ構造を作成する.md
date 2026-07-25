---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding生成と保存]]"
---
# RS-0005 PostgreSQLに文書チャンクとEmbeddingを保存するデータ構造を作成する

## 目的

v0.0で質問に近い文書チャンクをdense検索するためには、文書チャンクの本文と、そのチャンクから生成したEmbeddingを、対応関係を保ったままPostgreSQLへ永続化できるデータ構造が必要である。

このTicketでは、ローカル環境のPostgreSQLでpgvector拡張を利用できるようにし、v0.0の検索対象となる文書チャンクとEmbeddingを保存する最小のDB schemaをmigrationとして作成する。

DB上で各チャンクの元文書と文書内での順序を識別でき、RS-0003で固定した次元のEmbeddingだけを保存できる制約を設ける。Haskellから実際の文書チャンクとEmbeddingを保存する処理はRS-0006で扱う。

## 完了条件

- [ ] ローカル環境でPostgreSQLを起動し、RAGScopeから接続するためのDBを用意できる
- [ ] 対象DBでpgvector拡張を有効化できる
- [ ] 空のDBへ適用できるmigrationとして、文書チャンクとEmbeddingを保存するDB schemaが定義されている
- [ ] DB上の各検索対象チャンクについて、元文書を識別する情報、0始まりの`chunkIndex`、チャンク本文、対応するEmbeddingを保持できる
- [ ] 元文書を識別する情報と`chunkIndex`の組み合わせなどにより、v0.0の各チャンクをDB上で一意に識別できる
- [ ] Embedding列がRS-0003で固定したvector次元に対応し、異なる次元のvectorを保存できない
- [ ] 必須となる本文、元文書を識別する情報、`chunkIndex`、Embeddingが欠落した不完全な検索対象を保存できない
- [ ] `chunkIndex`に負の値を保存できない
- [ ] 文書チャンクとEmbeddingの一対一の対応を、単一レコードまたはDB制約によって維持できる
- [ ] migrationを空のDBへ適用し、必要なpgvector拡張とDB schemaを再現できる
- [ ] schemaの構造と制約をmigrationまたはDB integration testで確認できる
- [ ] 正しい次元のvectorを持つテストデータをDB schemaへ保存でき、異なる次元や必須項目欠落などの不正なデータが拒否されることを確認できる
- [ ] DBのテーブル・カラム・制約はmigrationを正本とし、データの責務、関係、不変条件を`docs/design/データモデル設計.md`へ記載できる
- [ ] プロジェクトで定めたmigrationまたはDB testのコマンドを実行し、追加した確認を含めて成功する

## 対象外

- HaskellからPython AI Serviceを呼び出してEmbeddingを取得する処理
- Haskellから文書チャンクとEmbeddingを保存するrepository・queryの実装
- 文書取り込みからEmbedding保存までの一連の処理
- 質問Embeddingの生成
- dense検索queryと検索結果の取得
- PostgreSQL全文検索
- HNSW / IVFFlatなどの近似検索index
- 文書、文書集合、チャンク条件、Embedding条件のバージョン管理
- `Document`、`CorpusVersion`、`ChunkSet`、`EmbeddingSpec`など、後続Milestoneで必要となる完全なEntity群
- 質問、検索結果、実験条件、回答、引用、評価結果の保存
- DB backup、replication、高可用性、性能調整
- AWS RDSへの配置

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../docs/RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ「3.1 Haskellの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.1 Haskellの責務境界>)
- [システムアーキテクチャ「3.3 PostgreSQLの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.3 PostgreSQLの責務境界>)
- [システムアーキテクチャ「6. 文書取り込みの全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#6. 文書取り込みの全体フロー>)
- [文書処理設計](<../../../../docs/design/文書処理設計.md>)
- [Embedding生成設計](<../../../../docs/design/Embedding生成設計.md>)
- [データモデル設計](<../../../../docs/design/データモデル設計.md>)（本Ticketで作成）

## 実装メモ

- 正確なテーブル名、カラム名、型、主キー、外部キー、unique制約、check制約はmigrationを正本とする。
- Markdownの設計書には、DB schemaをそのまま複製せず、保存対象の責務、チャンクとEmbeddingの関係、不変条件、後続Milestoneで拡張する境界を記載する。
- v0.0では、固定Markdown文書と固定チャンク条件、固定Embedding modelによる最小の検索対象だけを保存する。
- 元文書を識別する値は、RS-0002で定めたv0.0用の識別情報を使用する。永続的な文書ID体系や文書versionは導入しない。
- 文書チャンクとEmbeddingを同じテーブルへ保存するか、関連する複数テーブルへ分けるかは、最小の責務と制約を満たす範囲で実装時に決定する。
- 複数テーブルへ分ける場合は、DB制約によってチャンクとEmbeddingの対応を一意に維持し、対応先のないEmbeddingを作らない。
- Embedding列は、RS-0003で採用したモデルの固定出力次元に合わせたpgvectorの`vector(n)`型とする。
- v0.0ではexact vector searchを行うため、HNSW / IVFFlatなどの近似検索indexを作成しない。
- migrationは、既存環境へ手作業でSQLを追加しなくても、定めたコマンドから再現できるようにする。
- DB接続情報やpasswordをソースコード、migration、Git管理対象の平文ファイルへ直接記載しない。
- PostgreSQLの起動方法は既存のローカル開発環境方針に合わせる。新しい実行方式を採用する必要が生じた場合は、その手順を適切な正本へ記載する。

## 結果

> [!note] 完了時に記入
> - 作成したmigration
> - 有効化したpgvector拡張
> - 作成したDB schemaと主要な制約
> - 採用したEmbeddingのvector次元
> - 実行したmigration・DB testコマンドと結果
> - 作成または更新したデータモデル設計
> - 既知の制約
> - 関連Pull Request
