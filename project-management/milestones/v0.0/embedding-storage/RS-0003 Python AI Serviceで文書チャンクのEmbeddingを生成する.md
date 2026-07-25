---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding生成と保存]]"
---
# RS-0003 Python AI Serviceで文書チャンクのEmbeddingを生成する

## 目的

v0.0で文書チャンクを意味的な近さによって検索するためには、RS-0002で生成した各チャンクの本文を、検索に使用できるEmbeddingへ変換する必要がある。

このTicketでは、v0.0で使用するEmbedding modelを1つ決定し、そのモデルとTokenizerをPython AI Serviceからローカル環境でロードできるようにする。Python AI Serviceは、1件以上の文書チャンク本文を受け取り、入力した各本文に対応する固定次元のEmbeddingを返す。

文書用と質問用のEmbeddingを後続のdense検索で比較できるように、model ID・revisionだけでなく、入力の組み立て、pooling、正規化、最大入力長など、Embeddingの意味を決める生成条件もv0.0の固定条件として定める。このTicketでは文書チャンクのEmbedding生成までを実装し、Haskellからの呼び出しはRS-0004で扱う。

## 完了条件

- [ ] v0.0で使用するEmbedding modelが1つ決定され、model IDとrevisionを固定して確認できる
- [ ] 採用したモデルに対応するTokenizerを含め、必要なモデル資産をPython AI Serviceからローカル環境でロードできる
- [ ] 採用したモデルが文書検索用のEmbeddingを生成でき、RAGScopeでのローカル利用を妨げるライセンス上の問題がないことを確認できる
- [ ] 文書用・質問用の入力規則、pooling、最大入力長、truncation、vector正規化の有無、出力次元が、v0.0で使用する固定条件として定められている
- [ ] Python AI Serviceをローカル環境で起動し、必要なモデルが処理可能な状態までロードされたことを確認できる
- [ ] Python AI Serviceが、1件以上の空でない文書チャンク本文を受け取り、各入力に対応するEmbeddingを返せる
- [ ] 入力した文書チャンクの件数と返却されるEmbeddingの件数が一致し、入力と出力の対応を順序または識別子によって一意に確認できる
- [ ] 生成される各Embeddingが、採用したモデルで定めた同じ次元を持ち、数値として利用できない値を含まないことを確認できる
- [ ] 使用中のmodel ID、revision、Embeddingの出力次元を、APIの応答またはモデル情報を返す処理から確認できる
- [ ] 空の入力一覧、空の本文、不正なrequestを、正常なEmbedding生成と区別できるエラーとして扱える
- [ ] モデルをロードできない場合とEmbedding生成に失敗した場合を、正常終了と区別して確認できる
- [ ] requestの検証、入力と出力の対応、vector次元、主要な異常系を自動テストで確認できる
- [ ] 採用した実モデルを使用し、文書チャンク本文からEmbeddingを生成できることを統合テストまたは実行によって確認できる
- [ ] Embedding生成APIの正確なrequest / responseをOpenAPIなどの機械可読な定義へ記載できる
- [ ] v0.0で固定したEmbedding生成条件と、文書用・質問用Embeddingの互換性を保つ規則を`docs/design/Embedding生成設計.md`へ記載できる
- [ ] プロジェクトで定めたPython側のテストコマンドを実行し、追加したテストを含めて成功する

## 対象外

- HaskellからPython AI ServiceをHTTP / JSONで呼び出す処理
- Haskellの文書チャンク型とAPI request / response型の変換
- PostgreSQL / pgvectorの導入、DB schema、migration
- 文書チャンク本文とEmbeddingのPostgreSQLへの保存
- 質問文の入力と質問Embeddingの生成
- dense検索、全文検索、hybrid検索、reranking
- Generation modelによる回答生成と引用
- 複数のEmbedding modelまたは生成条件の精度比較
- Embedding modelや生成条件を切り替える設定管理・バージョン管理
- Embedding cache
- 大規模batch処理、非同期job、分散推論
- GPUやAWSへの配置

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../docs/RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ「3.2 Pythonの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.2 Pythonの責務境界>)
- [システムアーキテクチャ「5. HaskellとPythonの通信」](<../../../../docs/design/システムアーキテクチャ.md#5. HaskellとPythonの通信>)
- [システムアーキテクチャ「6. 文書取り込みの全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#6. 文書取り込みの全体フロー>)
- [文書処理設計](<../../../../docs/design/文書処理設計.md>)
- [Embedding生成設計](<../../../../docs/design/Embedding生成設計.md>)（本Ticketで作成）

## 実装メモ

- Python AI ServiceはAI推論だけを担当し、文書チャンクの永続化やRAGScope全体の処理順序を管理しない。
- Embedding生成には`POST /embeddings`を使用する。正確なパス、項目名、型、必須条件、エラー形式は、OpenAPIなどの機械可読な定義を正本とする。
- サービスの生存確認と、モデルをロードして推論可能な状態の確認は区別する。必要に応じて`GET /health`と`GET /ready`を実装する。
- 使用中のmodel ID、revision、能力、出力次元は、`GET /models`またはEmbedding生成の応答から確認できるようにする。
- 文書用prefixやinstructionが必要なモデルでは、呼び出し側へ組み立てを分散させず、Python AI Service内で文書用の固定規則を適用する。
- 後続の質問Embeddingと互換性を保つため、質問用prefixやinstructionもこの時点で決定して設計へ記載する。ただし、質問Embeddingを生成する処理自体は後続Epicで実装する。
- pooling、最大入力長、truncation、vector正規化は、採用したモデルの推奨方法を確認したうえで1つに固定する。v0.0では利用者が切り替える機能を設けない。
- 複数件を受け取る場合は、返却順を入力順と一致させるか、各入力を識別する値を応答へ含め、チャンクとEmbeddingの対応を曖昧にしない。
- 自動テストでは、Embeddingの浮動小数点値そのものの完全一致へ過度に依存せず、件数、対応、次元、有限値、エラー分類などの契約を主に確認する。
- 実モデルを毎回ダウンロードしないように、モデル資産のcacheを利用してよい。ただし、Embedding結果を再利用する機能としてのEmbedding cacheはこのTicketでは実装しない。
- Pythonの依存パッケージと採用モデルのrevisionは、設定ファイルやlock fileなどから再現できるように固定する。
- モデル候補の精度比較は行わない。v0.0をローカル環境で実行できること、文書用と質問用のEmbeddingに互換性があること、ライセンス上利用可能であることを基準に1モデルを採用する。

## 結果

> [!note] 完了時に記入
> - 採用したEmbedding model、revision、Tokenizer
> - 固定したEmbedding生成条件と出力次元
> - 実装したPython AI Serviceの機能とAPI
> - 実行したテストコマンドと結果
> - 実モデルを使用したEmbedding生成の確認結果
> - 作成または更新したOpenAPI・設計文書
> - 既知の制約
> - 関連Pull Request
