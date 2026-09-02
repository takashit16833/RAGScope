---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding生成と保存]]"
---
# RS-0004 RAGScopeアプリケーションで文書チャンクのEmbeddingを取得する

## 目的

v0.0で文書チャンクとEmbeddingをPostgreSQLへ保存するためには、RS-0002で生成した文書チャンクをRAGScopeアプリケーションからAI推論サービスへ渡し、RS-0003で実装した文書チャンクEmbedding生成APIから、各文書チャンクに対応するEmbeddingを受け取れる必要がある。

このTicketでは、RS-0012の初期設計とOpenAPIに従い、RAGScopeアプリケーションからHTTP / JSONでAI推論サービスを呼び出す。1回のHTTPリクエストはRS-0017で実装した再試行の実行機構とタイムアウト制御を通じて実行する。元文書を識別する情報、`chunkIndex`、本文と、AI推論サービスから返されたEmbeddingの対応関係を検証し、後続の保存処理から利用できる値として取得する。

実行追跡では、RAGScopeアプリケーション側のcurrent `span`からTrace Contextを取得し、RS-0012で定義した通信形式でAI推論サービスへ引き継ぐ。AI推論サービス側ではそのContextから同じ`trace`を継続するため、旧`execution_id`をHTTPへ付与する実装は行わない。

## 前提

- [RS-0012 文書チャンクのEmbedding生成と保存を設計する](<./RS-0012 文書チャンクのEmbedding生成と保存を設計する.md>)が完了している
- [RS-0003 AI推論サービスで文書チャンクのEmbeddingを生成する](<./RS-0003 AI推論サービスで文書チャンクのEmbeddingを生成する.md>)が完了している
- [RS-0017 文書チャンクのEmbedding要求に必要なretry executorとtimeout制御を実装する](<../embedding-request-reliability/RS-0017 文書チャンクのEmbedding要求に必要なretry executorとtimeout制御を実装する.md>)が完了している
- `RS-0002`が完了し、文書チャンクをRAGScopeアプリケーションの値として取得できる

## 完了条件

### API requestと実行追跡

- [ ] RAGScopeアプリケーションからAI推論サービスの文書チャンクEmbedding生成APIへHTTP / JSONでrequestを送信できる
- [ ] 1件以上の文書チャンクについて、元文書を識別する情報、`chunkIndex`、本文をAPI requestへ変換できる
- [ ] current Trace ContextをRS-0012で定義した通信形式へ変換し、各HTTP requestへ付与してAI推論サービスへ引き継げる
- [ ] AI推論サービスが開始する`span`の親を特定できるTrace Contextを送信し、同じ`TraceId`の`trace`をコンポーネント境界越しに継続できる
- [ ] 再試行による各HTTP試行でも、その試行を包む現在の実行追跡境界に従って正しいTrace Contextを送信できる
- [ ] 旧`execution_id`を現在の実行追跡識別子としてrequestへ追加していない

### 再試行・タイムアウトの適用

- [ ] 1回のHTTP requestを表す処理がRS-0017の実行機構へ接続され、独自の再試行処理を実装していない
- [ ] 機能設計で定めたtimeoutが実際の文書チャンクEmbedding要求へ適用されている
- [ ] 一時的失敗かつ再試行しても安全な場合にだけ、機能設計で定めた方針に従って再試行できる
- [ ] 再試行対象外のHTTP失敗、AI推論サービスの明示的な失敗、不正JSON、入力・契約違反、ベクトル検証失敗を追加試行せず返せる
- [ ] 再試行を行わない失敗、再試行後の成功、試行上限到達、timeoutを、各処理の`span`と必要な構造化ログから区別して確認できる

### Embeddingの取得と対応検証

- [ ] AI推論サービスから成功responseを受け取り、各文書チャンクに対応するEmbeddingをRAGScopeアプリケーションの値として取得できる
- [ ] 入力した文書チャンク件数と返却されたEmbedding件数が一致することを確認できる
- [ ] 入力した文書チャンクとEmbeddingの対応を、OpenAPIで定めた順序または識別子によって一意に検証できる
- [ ] 取得した各Embeddingが設計で定めたベクトル次元と一致し、`NaN`や無限大など利用できない値を含まないことを確認できる
- [ ] 元文書を識別する情報、`chunkIndex`、本文、対応するEmbeddingを保持し、後続の保存処理へ渡せる値を取得できる
- [ ] 件数不一致、識別子または順序の不整合、ベクトル次元の不一致を検出し、不正な対応関係を後続処理へ渡さない

### 失敗・実行追跡・構造化ログ

- [ ] AI推論サービスへ接続できない場合と、AI推論サービスがEmbedding生成失敗を返した場合を、正常なEmbedding取得と区別して扱える
- [ ] HTTP失敗status、不正JSON、必須項目の欠落を、それぞれ正常responseと区別して扱える
- [ ] RAGScopeアプリケーションが所有する失敗理由を機能設計で定めた`error_type`へ対応付けられる
- [ ] 文書チャンクEmbedding要求を追跡する`span`が、その処理自身の最終結果に従って`Error`または`Unset`になる
- [ ] 機能設計で記録対象とした構造化ログがcurrent `span`の`TraceId`・`SpanId`へ関連付く
- [ ] 同じ失敗を`span`と構造化ログの両方へ記録する場合は同じ`error_type`を使用する

### 設計反映と検証

- [ ] request組み立て、response JSON復元、文書チャンクとEmbeddingの対応、ベクトル検証、主要な異常系を自動テストで確認できる
- [ ] test serverまたは同等の制御された境界で、RS-0012の通信契約どおりにTrace Contextが各HTTP requestへ付与されていることを確認できる
- [ ] test serverまたは同等の制御された境界を使用し、一時的失敗後の成功、再試行しない失敗、試行上限到達、timeoutをAPI clientとの結合テストで確認できる
- [ ] 実際に起動したAI推論サービスをRAGScopeアプリケーションから呼び出し、同じ`trace`を継続した状態で複数文書チャンクのEmbeddingを取得できることを結合テストまたは実行で確認できる
- [ ] RAGScopeアプリケーション側の実装とOpenAPI・Trace Context通信契約が一致している
- [ ] 実装で具体化または変更されたEmbedding取得フローを責務を持つ設計へ反映している
- [ ] 実装、OpenAPI、Embedding生成設計、再試行・timeout設計、実行追跡・構造化ログ契約に未解消な差異がない
- [ ] プロジェクトで定めたRAGScopeアプリケーション側のテストまたは品質検査を実行し、追加したテストを含めて成功する

## 対象外

- AI推論サービスでのmodel選定、model・Tokenizer読み込み、Embedding生成APIの実装
- Embedding生成APIの契約をゼロから設計する作業
- 再試行・timeoutの方針と実行機構をゼロから設計・実装する作業
- PostgreSQL / pgvectorの導入、DB schema、migration
- 文書チャンクとEmbeddingのPostgreSQLへの保存
- 保存済みデータの読み出し
- 質問文の入力と質問Embeddingの生成
- dense検索、全文検索、hybrid検索、`reranking`
- 生成modelによる回答生成と引用
- 複数Embedding modelまたは生成条件の切り替え・比較
- 文書チャンクEmbedding要求以外の処理への再試行・timeout適用
- 大規模batch処理、非同期job、並列request
- AWSへの配置

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ](../../../../design/システムアーキテクチャ.md)
- [実行追跡・構造化ログ契約設計](../../../../design/実行追跡・構造化ログ契約設計.md)
- [RAGScopeアプリケーション実行追跡詳細設計](../../../../design/tracing/RAGScopeアプリケーション実行追跡詳細設計.md)
- [RS-0012 文書チャンクのEmbedding生成と保存を設計する](<./RS-0012 文書チャンクのEmbedding生成と保存を設計する.md>)
- [RS-0016 文書チャンクのEmbedding要求に必要なretryとtimeoutを設計する](<../embedding-request-reliability/RS-0016 文書チャンクのEmbedding要求に必要なretryとtimeoutを設計する.md>)
- [RS-0017 文書チャンクのEmbedding要求に必要なretry executorとtimeout制御を実装する](<../embedding-request-reliability/RS-0017 文書チャンクのEmbedding要求に必要なretry executorとtimeout制御を実装する.md>)

## 実装メモ

- RAGScopeアプリケーションはRAGScopeの処理全体とデータの対応関係を管理し、AI推論サービスはモデル依存計算を担当する。
- APIの正確なpath、request・response、項目名、型、失敗表現、Trace Context通信形式はOpenAPIなどRS-0012で確定した機械可読な契約を正本として使用する。
- Trace Contextの取得はRAGScopeアプリケーションの実行追跡境界から行い、この機能が`TraceId`・`SpanId`を独自生成しない。
- API用型とRAGScope内部の文書チャンク型を分け、境界で明示的に変換する。
- AI推論サービスから返されたarrayを無条件に入力文書チャンクへ`zip`せず、API契約で定めた対応を検証してから関連付ける。
- 対応付け後の値は元文書を識別する情報、`chunkIndex`、元の本文、Embeddingを失わず保持する。正確な型名やfield名はコードを正本とする。
- 自動テストではtest serverまたはHTTP client差し替えを利用し、実modelへ毎回依存せず正常responseと異常responseを確認してよい。

## 結果

> [!note] 完了時に記入
> - 実装したRAGScopeアプリケーション側API clientと変換境界
> - Trace Context伝播と分散traceの確認結果
> - 適用したretry・timeout境界
> - Embedding対応検証の内容
> - 実行したテスト・品質検査と結果
> - 設計・OpenAPIへ反映した内容
> - 既知の制約
> - 関連Pull Request
