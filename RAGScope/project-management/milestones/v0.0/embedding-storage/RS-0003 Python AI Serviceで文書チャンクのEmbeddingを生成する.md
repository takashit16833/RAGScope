---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding生成と保存]]"
---
# RS-0003 Python AI Serviceで文書チャンクのEmbeddingを生成する

## 目的

v0.0で文書チャンクを意味的な近さによって検索するためには、RS-0002で生成した各チャンクの本文を、検索に使用できるEmbeddingへ変換する必要がある。

このTicketでは、RS-0012で選定・設計したEmbedding modelと固定生成条件に従い、Python AI Serviceへ文書チャンクのEmbedding生成機能を実装する。Python AI Serviceは、1件以上の文書チャンク本文を受け取り、入力した各本文に対応する固定次元のEmbeddingを返す。

Haskellからの呼び出しはRS-0004、PostgreSQLへの保存はRS-0005とRS-0006で扱う。

## 前提

- [RS-0012 文書チャンクのEmbedding生成と保存を設計する](<./RS-0012 文書チャンクのEmbedding生成と保存を設計する.md>)が完了している
- [RS-0018 Python AI Serviceの共通エラー・構造化ログ基盤を実装する](<../error-logging/RS-0018 Python AI Serviceの共通エラー・構造化ログ基盤を実装する.md>)が完了している
- `docs/design/Embedding生成設計.md`と文書Embedding生成APIのOpenAPI初期定義が作成されている
- `RS-0002`が完了し、Embedding生成へ渡す文書チャンクの内容が確定している

## 完了条件

- [ ] RS-0012で選定したEmbedding model、revision、Tokenizer、Tokenizer revisionをPython AI Serviceからロードできる
- [ ] Pythonの依存packageと採用モデルのrevisionが、設定ファイルやlock fileなどから再現できる形で固定されている
- [ ] Python AI Serviceをローカル環境で起動し、サービスの生存状態とモデルが推論可能な状態を区別して確認できる
- [ ] HTTP adapterがOpenAPIで定めた方法で`execution_id`を受領・検証し、同じrequestに属する処理とeventが利用する共通Contextへ引き渡せる
- [ ] `execution_id`が欠落または不正なrequestを、OpenAPIで定めたエラーとして扱える
- [ ] Python AI Serviceが、1件以上の空でない文書チャンク本文を受け取り、各入力に対応するEmbeddingを返せる
- [ ] 文書用の入力規則、pooling、最大入力長、truncation、vector正規化が設計どおり適用される
- [ ] 入力した文書チャンクの件数と返却されるEmbeddingの件数が一致し、入力と出力の対応をAPI契約どおり一意に確認できる
- [ ] 生成される各Embeddingが設計で定めた同じ次元を持ち、`NaN`や無限大など利用できない値を含まない
- [ ] 使用中のmodel ID、revision、Embeddingの出力次元を、設計で定めた方法から確認できる
- [ ] 空の入力一覧、空の本文、不正なrequestを、正常なEmbedding生成と区別できるエラーとして扱える
- [ ] モデルをロードできない場合とEmbedding生成に失敗した場合を、正常終了と区別して確認できる
- [ ] request validation、Web framework、model、Tokenizer、AI libraryのうち文書Embedding生成で発生する機能固有例外が、RS-0018の共通境界を通じて共通エラーとAPI error responseへ変換される
- [ ] 機能固有例外の変換後もraw exceptionとtracebackが公開responseへ含まれず、想定外例外には共通fallbackが適用される
- [ ] requestの検証、入力と出力の対応、固定生成条件、vector次元、有限値、主要な異常系を自動テストで確認できる
- [ ] `execution_id`の受領・共通Contextへの引き渡しと、代表的な機能固有例外のmappingを自動テストで確認できる
- [ ] 採用した実モデルを使用し、文書チャンク本文からEmbeddingを生成できることを統合テストまたは実行によって確認できる
- [ ] 実装されたAPIとOpenAPIのrequest / response、必須条件、エラー形式が一致している
- [ ] 実装で具体化または変更された現在設計が`docs/design/Embedding生成設計.md`へ反映されている
- [ ] 実装、OpenAPI、Embedding生成設計に解消していない差異がない
- [ ] プロジェクトで定めたPython側のテストコマンドを実行し、追加したテストを含めて成功する

## 対象外

- Embedding modelまたは生成条件の新たな比較・選定
- HaskellからPython AI ServiceをHTTP / JSONで呼び出す処理
- Haskellの文書チャンク型とAPI request / response型の変換
- PostgreSQL / pgvectorの導入、DB schema、migration
- 文書チャンク本文とEmbeddingのPostgreSQLへの保存
- 質問文の入力と質問Embeddingの生成
- dense検索、全文検索、hybrid検索、reranking
- Generation modelによる回答生成と引用
- Embedding modelや生成条件を切り替える設定管理・version管理
- Embedding cache
- 大規模batch処理、非同期job、分散推論
- GPUやAWSへの配置

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../docs/RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ「3.2 Pythonの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.2 Pythonの責務境界>)
- [システムアーキテクチャ「5. HaskellとPythonの通信」](<../../../../docs/design/システムアーキテクチャ.md#5. HaskellとPythonの通信>)
- [システムアーキテクチャ「6. 文書取り込みの全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#6. 文書取り込みの全体フロー>)
- [文書処理設計](<../../../../docs/design/文書処理設計.md>)
- [Embedding生成設計](<../../../../docs/design/Embedding生成設計.md>)
- [データモデル設計](<../../../../docs/design/データモデル設計.md>)
- [ADR-0002 — 共通実行基盤の契約とコンポーネント実装を分離する](<../../../../docs/adr/ADR-0002 共通実行基盤の契約とコンポーネント実装を分離する.md>)
- [エラー・ログ設計](../../../../docs/design/エラー・ログ設計.md)
- [RS-0018 Python AI Serviceの共通エラー・構造化ログ基盤を実装する](<../error-logging/RS-0018 Python AI Serviceの共通エラー・構造化ログ基盤を実装する.md>)

## 実装メモ

- Python AI ServiceはAI推論だけを担当し、文書チャンクの永続化やRAGScope全体の処理順序を管理しない。
- APIの正確なpath、項目名、型、必須条件、エラー形式はOpenAPIを正本とする。
- HTTP adapterはOpenAPIに従って`execution_id`を受領し、RS-0018で実装した共通Contextへ引き渡す。`execution_id`のHTTP上の表現をこのTicketで独自に追加しない。
- 機能固有例外は、文書Embedding生成で実際に使用するframework、model、Tokenizer、AI libraryの境界でmappingする。将来機能の例外まで先回りして網羅しない。
- 文書用prefixやinstructionが必要なモデルでは、呼び出し側へ組み立てを分散させず、Python AI Service内で文書用の固定規則を適用する。
- 質問用の入力規則は互換性確保のため設計済みだが、このTicketでは質問Embeddingを生成する処理を実装しない。
- 自動テストでは、Embeddingの浮動小数点値そのものの完全一致へ過度に依存せず、件数、対応、次元、有限値、エラー分類などの契約を主に確認する。
- 実モデルを毎回ダウンロードしないようにモデル資産のcacheを利用してよいが、Embedding結果を再利用する機能は実装しない。
- 初期設計またはOpenAPIを変更する必要が生じた場合は、実装だけを先行させず、同じ変更で正本を更新する。

## 結果

> [!note] 完了時に記入
> - 実装したPython AI Serviceの機能とAPI
> - 使用したEmbedding model、revision、Tokenizer
> - 適用した固定生成条件と出力次元
> - 実行したテストコマンドと結果
> - 実モデルを使用したEmbedding生成の確認結果
> - OpenAPI・Embedding生成設計へ反映した内容
> - 既知の制約
> - 関連Pull Request
