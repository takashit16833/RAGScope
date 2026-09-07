---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding生成と保存]]"
---
# RS-0003 AI推論サービスで文書チャンクのEmbeddingを生成する

## 目的

v0.0で文書チャンクを意味的な近さによって検索するため、RS-0002で生成した各文書チャンク本文を、検索に使用できるEmbeddingへ変換するAI推論サービスのHTTP APIを実装する。

RS-0012で選定・設計したEmbeddingモデルと固定生成条件に従い、1件以上の文書チャンク本文を受け取り、入力した各本文に対応する固定次元のEmbeddingを返す。RAGScopeアプリケーションからの呼び出しはRS-0004、PostgreSQLへの保存はRS-0005とRS-0006で扱う。

## 前提

- [RS-0012 文書チャンクのEmbedding生成と保存を設計する](<./RS-0012 文書チャンクのEmbedding生成と保存を設計する.md>)が完了している
- [RS-0025 AI推論サービスへOpenTelemetry Observability最小基盤を実装する](<../error-logging/RS-0025 AI推論サービスへOpenTelemetry Observability最小基盤を実装する.md>)が完了している
- `design/Embedding生成設計.md`と文書チャンクのEmbedding生成APIのOpenAPI初期定義が作成されている
- RS-0002が完了し、Embedding生成へ渡す文書チャンクの内容が確定している

## 完了条件

### モデルとサービスの準備

- [ ] RS-0012で選定したEmbeddingモデル、revision、Tokenizer、Tokenizer revisionをAI推論サービスから読み込める
- [ ] Pythonの依存packageと採用モデルのrevisionが設定・lockfileなどから再現できる
- [ ] AI推論サービスをローカルで起動し、サービスの生存状態とモデルが推論可能な状態を区別して確認できる
- [ ] 使用中のモデルID、revision、Embedding出力次元を設計で定めた方法から確認できる

### HTTP入力・Trace Context・Embedding生成

- [ ] HTTP adapterが受信requestからOpenTelemetry Trace Contextをextractし、RAGScopeアプリケーション側のcaller Spanと同じTraceを継続するSERVER Spanを開始できる
- [ ] Trace ContextのextractとSERVER Spanの作成は採用するOpenTelemetry propagator / HTTP instrumentationに従い、RAGScope独自の`execution_id`を要求しない
- [ ] 1件以上の空でない文書チャンク本文を受け取り、各入力に対応するEmbeddingを返せる
- [ ] 文書用の入力規則、pooling、最大入力長、truncation、ベクトル正規化が設計どおり適用される
- [ ] 入力した文書チャンク件数と返却するEmbedding件数が一致し、入力と出力の対応をAPI契約どおり一意に確認できる
- [ ] 各Embeddingが設計で定めた次元を持ち、`NaN`や無限大など利用できない値を含まない

### 失敗・Telemetry

- [ ] 空の入力一覧、空本文、不正requestを正常なEmbedding生成と区別できる具体的な機能errorとして扱える
- [ ] モデルを読み込めない場合とEmbedding生成に失敗した場合を正常終了と区別できる具体的な機能errorとして扱える
- [ ] 機能errorをHTTP responseへ変換する境界とTelemetryの`error.type`へ変換する境界を区別し、共通`RAGScopeError`を経由しない
- [ ] SERVER Spanとモデル / GenAI処理に適用できるSemantic Conventionを優先し、同じ処理を表すRAGScope独自SpanやEventRecordを重複して追加していない
- [ ] 例外が処理されないままSpanの外へ伝播する場合は、RS-0025の共通境界に従ってSpanとLogsへ反映したうえで再throwされる

### 設計反映と検証

- [ ] request検証、入力と出力の対応、固定生成条件、ベクトル次元、有限値、主要な異常系を自動テストで確認できる
- [ ] validなTrace Contextを持つrequestでcaller側と同じTraceIdを継続することを自動テストまたは結合テストで確認できる
- [ ] 採用した実モデルで文書チャンク本文からEmbeddingを生成できることを統合テストまたは実行で確認できる
- [ ] 実装されたAPIとOpenAPIのrequest / response、必須条件、error形式が一致している
- [ ] 実装で具体化・変更された現在設計を責務を持つ機能設計と機械可読な契約へ反映している
- [ ] AI推論サービス側のテスト・品質検査を実行し、追加したテストを含めて成功する

## 対象外

- Embeddingモデルまたは生成条件の新たな比較・選定
- RAGScopeアプリケーションからAI推論サービスを呼び出すclient処理
- PostgreSQL / pgvectorの導入と保存
- 質問Embedding、dense検索、`reranking`、回答生成
- 大規模batch、非同期job、分散推論
- Tempo / Loki / Prometheus / Grafanaのローカル環境構築
- GPUやAWSへの配置

## 関連文書

- [システムアーキテクチャ](../../../../design/システムアーキテクチャ.md)
- [Observability設計](../../../../design/observability/README.md)
- [実行追跡設計](../../../../design/observability/実行追跡設計.md)
- [RS-0025](<../error-logging/RS-0025 AI推論サービスへOpenTelemetry Observability最小基盤を実装する.md>)

## 実装メモ

- APIの正確なpath、項目名、型、必須条件、error形式はOpenAPIを正本とする。
- Trace ContextのHTTP上の表現をRAGScope独自fieldとして追加せず、採用するOpenTelemetry propagator / HTTP instrumentationへ委ねる。
- 具体的なモデル・Tokenizer・AI libraryのExceptionは、実際の発生境界で機能errorへ変換する。将来機能のExceptionまで先回りして分類しない。
- 正確なPython型、関数、module、依存packageはコード・設定・lockfileを正本とする。

## 結果

> [!note] 完了時に記入
> - 実装したAI推論サービスの機能とAPI
> - 使用したモデル、revision、Tokenizer
> - Trace Contextの受信・SERVER Spanの確認結果
> - 実行したテスト・品質検査
> - 既知の制約
> - 関連Pull Request
