---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding生成と保存]]"
---
# RS-0003 AI推論サービスで文書チャンクのEmbeddingを生成する

## 目的

v0.0で文書チャンクを意味的な近さによって検索するためには、RS-0002で生成した各文書チャンクの本文を、検索に使用できるEmbeddingへ変換する必要がある。

このTicketでは、RS-0012で選定・設計したEmbeddingモデルと固定生成条件に従い、AI推論サービスへ文書チャンクEmbedding生成機能を実装する。AI推論サービスは1件以上の文書チャンク本文を受け取り、入力した各本文に対応する固定次元のEmbeddingを返す。

RAGScopeアプリケーションからの呼び出しはRS-0004、PostgreSQLへの保存はRS-0005とRS-0006で扱う。実行追跡については、RAGScopeアプリケーションから通信で引き継いだTrace Contextを使ってAI推論サービス側でも同じ`trace`を継続し、この処理依頼を表す新しい子`span`の中でEmbedding生成を実行する。

## 前提

- [RS-0012 文書チャンクのEmbedding生成と保存を設計する](<./RS-0012 文書チャンクのEmbedding生成と保存を設計する.md>)が完了している
- [RS-0018 AI推論サービスの実行追跡・構造化ログ基盤を実装する](<../error-logging/RS-0018 AI推論サービスの実行追跡・構造化ログ基盤を実装する.md>)が完了している
- RS-0012で作成したEmbedding生成設計と文書チャンクEmbedding生成APIのOpenAPI初期定義が利用できる
- `RS-0002`が完了し、Embedding生成へ渡す文書チャンクの内容が確定している

## 完了条件

### モデルとサービスの準備

- [ ] RS-0012で選定したEmbeddingモデル、リビジョン、Tokenizer、TokenizerのリビジョンをAI推論サービスから読み込める
- [ ] Pythonの依存packageと採用モデルのリビジョンが、設定ファイルやlock fileなどから再現できる形で固定されている
- [ ] AI推論サービスをローカル環境で起動し、サービスの生存状態とモデルが推論可能な状態を区別して確認できる
- [ ] 使用中のモデルID、リビジョン、Embeddingの出力次元を、設計で定めた方法から確認できる

### API入力・Trace Context・Embedding生成

- [ ] HTTP adapterがRS-0012で定義した通信契約に従ってTrace Contextを受領・検証し、AI推論サービスの実行追跡境界へ引き渡せる
- [ ] 受け取ったTrace Contextから、同じ`TraceId`を使用し、呼び出し元`SpanId`の`span`を親とする新しいAI推論サービス側`span`を開始できる
- [ ] Trace Contextが欠落または不正な場合の扱いがRS-0012で確定した通信契約と一致している
- [ ] 旧`execution_id`を実行追跡識別子として受領・保持する経路を追加していない
- [ ] AI推論サービスが1件以上の空でない文書チャンク本文を受け取り、各入力に対応するEmbeddingを返せる
- [ ] 文書用の入力規則、pooling、最大入力長、truncation、ベクトル正規化が設計どおり適用される
- [ ] 入力した文書チャンクの件数と返却されるEmbeddingの件数が一致し、入力と出力の対応をAPI契約どおり一意に確認できる
- [ ] 生成される各Embeddingが設計で定めた同じ次元を持ち、`NaN`や無限大など利用できない値を含まない

### 失敗・Span Status・構造化ログ

- [ ] 空の入力一覧、空の本文、不正なrequestを、正常なEmbedding生成と区別できる失敗として扱える
- [ ] モデルを読み込めない場合とEmbedding生成に失敗した場合を、正常終了と区別して確認できる
- [ ] この機能が所有する失敗理由をRS-0012で定めた`error_type`へ対応付けられる
- [ ] Embedding生成処理がRAGScope上のエラーとして終了する場合、この処理を表す`span`を`Error`として終了し、対応する`error_type`を関連付けられる
- [ ] Embedding生成処理がエラーとして終了しない場合、この処理を表す`span`を`Unset`のまま終了できる
- [ ] 機能設計で記録対象としたログイベントを、処理中のcurrent `span`へ`TraceId`・`SpanId`で関連付けて記録できる
- [ ] 同じ失敗を`span`と構造化ログの両方へ記録する場合は同じ`error_type`を使用する
- [ ] 元の例外メッセージ、stack trace、文書チャンク本文など記録を許可していない情報を外部レスポンスや構造化ログへ不用意に含めない

### 設計反映と検証

- [ ] request検証、入力と出力の対応、固定生成条件、ベクトル次元、有限値、主要な異常系を自動テストで確認できる
- [ ] Trace Contextの受領、親子関係を保ったAI推論サービス側`span`の開始・終了、Span Status、current Trace Contextを使う構造化ログの関連付けを自動テストで確認できる
- [ ] 採用した実モデルを使用し、文書チャンク本文からEmbeddingを生成できることを統合テストまたは実行によって確認できる
- [ ] 実装されたAPIとOpenAPIのrequest・response、Trace Context伝播、必須条件、失敗表現が一致している
- [ ] 実装で具体化または変更された現在設計が、責務を持つEmbedding生成設計へ反映されている
- [ ] 実装、OpenAPI、Embedding生成設計、実行追跡・構造化ログ契約に解消していない差異がない
- [ ] プロジェクトで定めたAI推論サービス側のテストまたは品質検査を実行し、追加したテストを含めて成功する

## 対象外

- Embeddingモデルまたは生成条件の新たな比較・選定
- RAGScopeアプリケーションからAI推論サービスをHTTP / JSONで呼び出す処理
- RAGScopeアプリケーション内部型とAPI request・response型の変換
- PostgreSQL / pgvectorの導入、DB schema、migration
- 文書チャンク本文とEmbeddingのPostgreSQLへの保存
- 質問文の入力と質問Embeddingの生成
- dense検索、全文検索、hybrid検索、`reranking`
- 生成モデルによる回答生成と引用
- Embeddingモデルや生成条件を切り替える設定管理・version管理
- Embedding cache
- 大規模なbatch処理、非同期job、分散推論
- GPUやAWSへの配置
- この機能から独立した汎用的な子`span`・event・`error_type`の先行設計

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ](../../../../design/システムアーキテクチャ.md)
- [実行追跡・構造化ログ契約設計](../../../../design/実行追跡・構造化ログ契約設計.md)
- [実行追跡設計](../../../../design/tracing/README.md)
- [文書処理設計](../../../../design/features/文書処理設計.md)
- [RS-0018 AI推論サービスの実行追跡・構造化ログ基盤を実装する](<../error-logging/RS-0018 AI推論サービスの実行追跡・構造化ログ基盤を実装する.md>)

## 実装メモ

- AI推論サービスはモデル依存計算を担当し、文書チャンクの永続化やRAGScope全体の処理順序を管理しない。
- APIの正確なpath、項目名、型、必須条件、失敗表現、Trace Contextの通信形式はOpenAPIなどRS-0012で確定した機械可読な通信契約を正本とする。
- HTTP adapterは受領したTrace ContextをRS-0018で実装した実行追跡境界へ引き渡す。Trace Contextの表現をこのTicketで独自に追加しない。
- 機能固有例外は、このTicketで実際に使用するWeb framework、model、Tokenizer、AI libraryの境界で、機能が定める失敗理由と安全な外部表現へ変換する。将来機能の例外まで先回りして網羅しない。
- 文書用のprefixやinstructionが必要なモデルでは、呼び出し側へ組み立てを分散させず、AI推論サービス内で文書用の固定規則を適用する。
- 質問用の入力規則は互換性確保のため設計済みでも、このTicketでは質問Embeddingを生成する処理を実装しない。
- 自動テストではEmbeddingの浮動小数点値そのものの完全一致へ過度に依存せず、件数、対応、次元、有限値、失敗条件などの契約を主に確認する。
- 実モデルを毎回downloadしないようにmodel asset cacheを利用してよいが、Embedding結果を再利用する機能は実装しない。

## 結果

> [!note] 完了時に記入
> - 実装したAI推論サービスの機能とAPI
> - 使用したEmbeddingモデル、リビジョン、Tokenizer
> - 適用した固定生成条件と出力次元
> - Trace Context伝播と`span`の確認結果
> - 実行したテスト・品質検査と結果
> - 実モデルを使用したEmbedding生成の確認結果
> - OpenAPI・Embedding生成設計へ反映した内容
> - 既知の制約
> - 関連Pull Request
