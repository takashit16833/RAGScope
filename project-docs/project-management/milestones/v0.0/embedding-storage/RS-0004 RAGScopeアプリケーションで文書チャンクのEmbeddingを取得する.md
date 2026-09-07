---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding生成と保存]]"
---
# RS-0004 RAGScopeアプリケーションで文書チャンクのEmbeddingを取得する

## 目的

RS-0002で生成した文書チャンクをRAGScopeアプリケーションからAI推論サービスへ渡し、RS-0003の文書チャンクEmbedding生成APIから各文書チャンクに対応するEmbeddingをHTTP / JSONで取得する。

1回のHTTP requestはRS-0017で実装する再試行・timeout制御を通じて実行する。RAGScopeアプリケーションは現在のOpenTelemetry Trace ContextをAI推論サービスへ伝播し、各HTTP attemptを標準HTTP client計装で追跡する。

## 前提

- [RS-0012 文書チャンクのEmbedding生成と保存を設計する](<./RS-0012 文書チャンクのEmbedding生成と保存を設計する.md>)が完了している
- [RS-0003 AI推論サービスで文書チャンクのEmbeddingを生成する](<./RS-0003 AI推論サービスで文書チャンクのEmbeddingを生成する.md>)が完了している
- [RS-0017 文書チャンクのEmbedding要求に必要なretry executorとtimeout制御を実装する](<../embedding-request-reliability/RS-0017 文書チャンクのEmbedding要求に必要なretry executorとtimeout制御を実装する.md>)が完了している
- [RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する](<../error-logging/RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する.md>)が完了している
- RS-0002が完了し、文書チャンクをHaskellの値として取得できる

## 完了条件

### API requestとTrace Context

- [ ] RAGScopeアプリケーションからAI推論サービスのEmbedding生成APIへHTTP / JSONでrequestを送信できる
- [ ] 1件以上の文書チャンクについて、元文書を識別する情報、`chunkIndex`、本文をAPI requestへ変換できる
- [ ] 現在のOpenTelemetry Trace Contextを各HTTP requestへinjectし、AI推論サービス側で同じTraceを継続できる
- [ ] Trace ContextのHTTP表現は採用するOpenTelemetry propagator / HTTP instrumentationに従い、RAGScope独自の`execution_id`を追加していない
- [ ] retryの各attemptを、適用できるHTTP client Semantic Conventionに従う個別のclient Spanとして追跡できる

### 再試行・timeout

- [ ] 1回のHTTP requestを表す処理がRS-0017の実行機構へ接続され、独自のretry loopを実装していない
- [ ] 機能設計で定めたtimeoutが実際のEmbedding requestへ適用されている
- [ ] 一時的失敗かつ再試行しても安全な場合だけ、定めた方針に従ってretryできる
- [ ] retry対象外のHTTP失敗、AI推論サービスの明示的失敗、不正JSON、入力・契約違反、vector検証失敗を追加attemptなしで返せる
- [ ] 中間attemptが失敗しても最終成功したrequest全体を失敗として扱わず、各SpanのStatusをそのSpan自身の最終結果から決定している

### Embedding取得と検証

- [ ] 成功responseから各文書チャンクに対応するEmbeddingをHaskellの値として取得できる
- [ ] 入力した文書チャンク件数と返却されたEmbedding件数が一致することを確認できる
- [ ] 文書チャンクとEmbeddingの対応をOpenAPIで定めた順序または識別子によって一意に検証できる
- [ ] 各Embeddingが設計で定めたvector次元と一致し、`NaN`や無限大を含まないことを確認できる
- [ ] 元文書を識別する情報、`chunkIndex`、本文、対応するEmbeddingを失わず後続の保存処理へ渡せる
- [ ] 件数不一致、対応不整合、vector次元不一致を検出し、不正な値を後続へ渡さない

### 失敗・Telemetry・検証

- [ ] 接続失敗、HTTP失敗status、不正JSON、AI推論サービスの機能errorを正常なEmbedding取得と区別して具体的なerror typeで扱える
- [ ] 具体的なerror typeから利用者側の失敗表現とTelemetryの`error.type`へ必要な境界で変換し、共通`RAGScopeError`を経由しない
- [ ] HTTP clientのSemantic Conventionと標準計装を優先し、同じrequestを表す独自Span / EventRecordを重複追加していない
- [ ] test serverまたは同等の境界でTrace Contextがrequestへinjectされ、AI推論サービス側で同じTraceIdを継続できることを確認している
- [ ] 一時的失敗後の成功、retryしない失敗、上限到達、timeoutをclientとの結合テストで確認できる
- [ ] 実際のAI推論サービスから複数文書チャンクのEmbeddingを取得できることを結合テストまたは実行で確認できる
- [ ] RAGScopeアプリケーション側実装とOpenAPIが一致し、設計・契約・テストに解消していない差異がない
- [ ] RAGScopeアプリケーション側のテスト・品質検査を実行し、追加したテストを含めて成功する

## 対象外

- AI推論サービスでのモデル選定・Embedding生成API実装
- retry / timeoutの共通方針と実行機構の再設計
- PostgreSQL / pgvectorへの保存
- 質問Embedding、dense検索、`reranking`、回答生成
- 文書チャンクEmbedding request以外の処理へのretry / timeout適用
- 大規模batch、非同期job、並列request
- Tempo / Loki / Prometheus / Grafanaのローカル環境構築
- AWSへの配置

## 関連文書

- [システムアーキテクチャ](../../../../design/システムアーキテクチャ.md)
- [Observability設計](../../../../design/observability/README.md)
- [実行追跡設計](../../../../design/observability/実行追跡設計.md)
- [RS-0017](<../embedding-request-reliability/RS-0017 文書チャンクのEmbedding要求に必要なretry executorとtimeout制御を実装する.md>)
- [RS-0024](<../error-logging/RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する.md>)

## 実装メモ

- APIの正確なpath、request / response、項目名、型、error形式はOpenAPIを正本とする。
- Trace ContextのHTTP表現をRAGScope独自fieldとして追加せず、採用するOpenTelemetry propagator / HTTP instrumentationへ委ねる。
- 各attemptのHTTP client Spanと、retryを含む上位処理のSpanを同一Spanへまとめない。
- 正確なHaskell型、関数、module、HTTP library、依存packageはコード・設定を正本とする。

## 結果

> [!note] 完了時に記入
> - 実装したAPI clientとデータ変換
> - Trace Context伝播とHTTP client Spanの確認結果
> - 適用したretry / timeoutと確認結果
> - 実行したテスト・品質検査
> - 既知の制約
> - 関連Pull Request
