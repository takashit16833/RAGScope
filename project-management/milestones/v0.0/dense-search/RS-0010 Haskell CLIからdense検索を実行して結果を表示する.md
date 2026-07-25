---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 質問によるdense検索の実行]]"
---
# RS-0010 Haskell CLIからdense検索を実行して結果を表示する

## 目的

v0.0の最小のdense検索経路を利用者が実行できる状態にするためには、Haskell CLIから質問文を入力し、質問Embeddingの取得、PostgreSQL / pgvectorでの検索、上位チャンクの表示までを一連の操作としてつなぐ必要がある。

このTicketでは、RS-0013の初期設計に従い、Haskell CLIへ検索コマンドを追加する。RS-0008の質問Embedding取得処理とRS-0009のexact vector searchを順番に呼び出し、順位付きの検索結果を人が読める形式で表示する。

さらに、前のEpicで実装した固定Markdown文書の取り込みとEmbedding保存を含め、文書取り込みから検索結果表示までをローカル環境で再実行できる手順を整え、v0.0のend-to-end動作を確認する。

## 前提

- [RS-0013 質問によるdense検索を設計する](<./RS-0013 質問によるdense検索を設計する.md>)が完了している
- [RS-0008 Haskellから質問文のEmbeddingを取得する](<./RS-0008 Haskellから質問文のEmbeddingを取得する.md>)が完了している
- [RS-0009 PostgreSQLのpgvectorでexact vector searchを実行する](<./RS-0009 PostgreSQLのpgvectorでexact vector searchを実行する.md>)が完了している
- `RS-0006`が完了し、通常の実行入口から検索対象データを保存できる

## 完了条件

- [ ] Haskell CLIへ、設計で定めた形式のdense検索commandを追加できる
- [ ] CLIから1件の空でない質問文を受け取り、Haskellの`Text`として検索処理へ渡せる
- [ ] 引数がない場合、空文字、または空白だけの質問文を、正常な検索実行と区別できる入力エラーとして扱える
- [ ] RS-0008の処理を利用し、CLIから受け取った質問文に対応する質問Embeddingを取得できる
- [ ] RS-0009の処理を利用し、質問Embeddingから固定件数までの上位チャンクを取得できる
- [ ] 質問文の入力、質問Embeddingの取得、exact vector search、検索結果の表示を、1回のCLI操作として順番に実行できる
- [ ] 各検索結果について、順位、距離または類似度、元文書を識別する情報、`chunkIndex`、チャンク本文を標準出力へ表示できる
- [ ] 複数の検索結果を順位順に区別でき、長いチャンク本文を含む場合でも結果同士の境界を確認できる表示形式になっている
- [ ] 検索結果が0件の場合、処理失敗と混同せず、該当結果がないことを利用者へ表示できる
- [ ] 入力エラー、Python AI Serviceへの接続失敗、質問Embedding生成失敗、PostgreSQL接続失敗、検索失敗を、利用者が原因の種類を確認できるエラーとして標準エラー出力へ表示できる
- [ ] 正常終了時は成功を示す終了status、入力または処理の失敗時は失敗を示す終了statusを返せる
- [ ] CLIの引数解析、処理の呼び出し順序、検索結果の整形、主要なエラー表示を自動テストで確認できる
- [ ] 実際に起動したPython AI ServiceとPostgreSQLを使用し、保存済みの文書チャンクに対してCLIから質問し、順位付きの検索結果を表示できる
- [ ] end-to-end確認では、固定Markdown文書から2件以上のチャンクを生成・保存し、複数の検索候補に対する順位付き検索を確認できる
- [ ] v0.0の確認用質問に対して、想定する関連チャンクが上位検索結果に含まれることをend-to-endの実行で確認できる
- [ ] 固定Markdown文書の読み込み、チャンク化、文書Embedding生成、PostgreSQLへの保存、CLIからの質問、検索結果表示までを、定めた手順でローカル環境から再実行できる
- [ ] v0.0をローカル環境で再実行するための最小限のsetup、起動、文書取り込み、検索command、終了方法が`README.md`へ記載されている
- [ ] CLIの正確なcommand、引数、終了statusを実装と`--help`から確認できる
- [ ] 実装で具体化または変更されたCLI検索フローと表示内容が`docs/design/検索設計.md`へ反映されている
- [ ] 実装、`--help`、README、検索設計に解消していない差異がない
- [ ] プロジェクトで定めたHaskell側のテストコマンドとend-to-end確認手順を実行し、追加した確認を含めて成功する

## 対象外

- Python AI Serviceで質問Embeddingを生成する処理の新規実装
- Haskellから質問Embeddingを取得するAPI clientの新規実装
- PostgreSQL / pgvectorのdense検索queryの新規実装
- 文書チャンクとEmbeddingのDB schemaおよび保存処理の新規実装
- 対話形式で複数の質問を連続入力するREPL
- Web UI、REST API、認証、ストリーミング
- 質問、質問Embedding、検索結果、実行履歴の永続化
- 検索結果を回答生成用のcontextとして選択する処理
- Generation modelによる回答生成と引用
- PostgreSQL全文検索、hybrid検索、reranking
- 検索品質の指標計算、評価データ、実験結果の保存・比較、Markdown / CSV report
- 距離尺度、上位取得件数、Embedding modelをCLI optionから変更する機能
- 複数質問のbatch処理、非同期job、並列検索
- HNSW / IVFFlatなどの近似検索index
- AWSへの配置

## 関連文書

- [README](../../../../README.md)
- [RAGScope要求定義「2.2 検索」](<../../../../docs/RAGScope要求定義.md#2.2 検索>)
- [RAGScope要求定義「2.7 実行とレポート」](<../../../../docs/RAGScope要求定義.md#2.7 実行とレポート>)
- [システムアーキテクチャ「3.1 Haskellの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.1 Haskellの責務境界>)
- [システムアーキテクチャ「5. HaskellとPythonの通信」](<../../../../docs/design/システムアーキテクチャ.md#5. HaskellとPythonの通信>)
- [システムアーキテクチャ「7. 質問処理の全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#7. 質問処理の全体フロー>)
- [システムアーキテクチャ「10.1 ローカル構成」](<../../../../docs/design/システムアーキテクチャ.md#10.1 ローカル構成>)
- [Embedding生成設計](<../../../../docs/design/Embedding生成設計.md>)
- [データモデル設計](<../../../../docs/design/データモデル設計.md>)
- [検索設計](<../../../../docs/design/検索設計.md>)

## 実装メモ

- CLIは利用者向けの入口と処理の組み立てだけを担当し、質問Embedding生成やDB検索の詳細を重複実装しない。
- 検索commandはRS-0008とRS-0009で分離した処理をアプリケーション層から順番に呼び出す。
- v0.0では質問文をcommand引数として1件受け取る。正確なcommandと引数は実装と`--help`を正本とする。
- 正常な検索結果は標準出力、入力エラーや外部service・DBの失敗は標準エラー出力へ表示する。
- エラー表示には内部例外や認証情報をそのまま露出させず、利用者が失敗した処理段階を識別できる情報を含める。
- 検索結果の本文は省略せず表示してよい。結果同士を見出しや区切り線などで分け、順位とmetadataの対応を曖昧にしない。
- READMEにはv0.0を再実行するために必要な最小手順だけを記載し、CLIの正確な仕様を重複管理しない。
- end-to-end確認では、RS-0001からRS-0009までで実装した処理を通常の手順で使用する。テストのためだけのDB直接登録を再実行手順に含めない。
- 関連チャンクが上位に含まれることは、v0.0の経路が意味的な検索として接続されたことを確認するsmoke testとし、検索品質が十分または最適であるとは主張しない。
- 初期設計を変更する必要が生じた場合は、READMEと`--help`への影響を確認してから`検索設計.md`を更新する。

## 結果

> [!note] 完了時に記入
> - 実装したCLI commandと入力形式
> - 検索結果の表示形式
> - 実行したテストコマンドと結果
> - Python AI Service・PostgreSQLを使用したend-to-end確認結果
> - end-to-end確認で生成・保存したチャンク件数
> - 使用した確認用質問と上位検索結果
> - READMEへ記載した再実行手順
> - 検索設計へ反映した内容
> - 既知の制約
> - 関連Pull Request
