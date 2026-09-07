---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 質問によるdense検索の実行]]"
---
# RS-0008 RAGScopeアプリケーションで質問Embeddingを取得する

## 目的

v0.0でRAGScopeアプリケーションがdense検索の処理全体を制御するためには、利用者から受け取った質問文をAI推論サービスへ渡し、RS-0007で実装した質問Embedding生成APIから検索に使用するEmbeddingを取得できる必要がある。

このTicketでは、RS-0013の初期設計とOpenAPIに従い、RAGScopeアプリケーションからHTTP / JSONでAI推論サービスへ1件の質問文を送信し、返された質問EmbeddingをHaskellの値として取得する。応答のベクトル次元と数値の妥当性を検証し、不正なEmbeddingを後続のPostgreSQL検索へ渡さない。

現在のOpenTelemetry Trace ContextをHTTP requestへinjectし、AI推論サービス側で同じTraceを継続できるようにする。

## 前提

- [RS-0013 質問によるdense検索を設計する](<./RS-0013 質問によるdense検索を設計する.md>)が完了している
- [RS-0007 AI推論サービスで質問Embeddingを生成する](<./RS-0007 AI推論サービスで質問Embeddingを生成する.md>)が完了している
- [RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する](<../error-logging/RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する.md>)が完了している
- `design/Embedding生成設計.md`とOpenAPIが質問Embeddingの実装と一致している

## 完了条件

### API request・Trace Context・質問Embeddingの取得

- [ ] RAGScopeアプリケーションからAI推論サービスの質問Embedding生成APIへHTTP / JSONでrequestを送信できる
- [ ] RAGScopeアプリケーションが保持する1件の空でない質問文を、API requestへ変換できる
- [ ] 現在のTrace ContextをHTTP requestへinjectし、AI推論サービス側で同じTraceIdを継続できる
- [ ] Trace ContextのHTTP表現はOpenTelemetry propagator / HTTP instrumentationに従い、独自追跡fieldを業務requestへ追加していない
- [ ] AI推論サービスから成功responseを受け取り、質問EmbeddingをHaskellの値として取得できる
- [ ] 元の質問文と対応するEmbeddingを保持し、後続のdense検索処理へ渡せる値を取得できる

### Embeddingの検証

- [ ] 取得した質問Embeddingが、設計で定めた文書チャンクのEmbeddingと同じベクトル次元を持つことを確認できる
- [ ] 取得した質問Embeddingに、`NaN`や無限大など利用できない値が含まれないことを確認できる
- [ ] ベクトル次元の不一致または有限値でない要素を検出し、不正なEmbeddingを後続処理へ渡さない

### 失敗・Observability

- [ ] 空文字または空白だけの質問文をAI推論サービスへ送信せず、正常なEmbedding取得と区別できる具体的なerrorとして扱える
- [ ] AI推論サービスへ接続できない場合、AI推論サービスが機能errorを返した場合、HTTP失敗status、不正JSON、必須項目欠落を正常responseと区別できる
- [ ] HTTP client Semantic Conventionと標準計装を優先し、同じrequestを表す独自Span / EventRecordを重複追加していない

### 設計反映と検証

- [ ] requestの組み立て、responseのJSON復元、入力検証、vector検証、主要な異常系を自動テストで確認できる
- [ ] test serverまたは同等の境界でTrace Contextがrequestへinjectされ、AI推論サービス側で同じTraceIdを継続できることを確認している
- [ ] 実際に起動したAI推論サービスをRAGScopeアプリケーションから呼び出し、質問文に対応する質問Embeddingを取得できることを結合テストまたは実行によって確認できる
- [ ] RAGScopeアプリケーション側の実装とOpenAPIの契約が一致している
- [ ] 実装で具体化または変更された質問Embedding取得フローが`design/Embedding生成設計.md`へ反映されている
- [ ] 実装、OpenAPI、Embedding生成設計に解消していない差異がない
- [ ] プロジェクトで定めたRAGScopeアプリケーション側のテストコマンドを実行し、追加したテストを含めて成功する

## 対象外

- AI推論サービスでのモデル選定、モデル・Tokenizerの読み込み
- AI推論サービスで質問Embeddingを生成する処理の実装
- 質問Embedding APIの契約をゼロから設計する作業
- PostgreSQL / pgvectorへの接続
- dense検索query、順位付け、上位文書チャンクの取得
- RAGScope CLIの検索コマンドと質問入力UI
- 検索結果のCLI表示
- 質問、質問Embedding、検索結果の永続化
- 全文検索、hybrid検索、`reranking`
- 生成モデルによる回答生成と引用
- 複数のEmbeddingモデルまたは生成条件の切り替え・比較
- 再試行方針、可変timeout、circuit breakerなどの本格的な障害制御
- 大規模batch、非同期job、並列request
- AWSへの配置

## 関連文書

- [RAGScope要求定義「1.3.1 検索」](<../../../../RAGScope要求定義.md#1.3.1 検索>)
- [システムアーキテクチャ「2.1 RAGScopeアプリケーション」](<../../../../design/システムアーキテクチャ.md#2.1 RAGScopeアプリケーション>)
- [システムアーキテクチャ「2.2 AI推論サービス」](<../../../../design/システムアーキテクチャ.md#2.2 AI推論サービス>)
- [システムアーキテクチャ「4.2 検索して回答を生成する」](<../../../../design/システムアーキテクチャ.md#4.2 検索して回答を生成する>)
- [システムアーキテクチャ「5. 通信と依存方向」](<../../../../design/システムアーキテクチャ.md#5. 通信と依存方向>)
- [Observability設計](../../../../design/observability/README.md)
- `design/Embedding生成設計.md`
- `design/検索設計.md`

## 実装メモ

- RAGScopeアプリケーションはRAGScopeの処理全体を制御し、AI推論サービスは質問Embeddingの生成だけを担当する。
- APIの正確なpath、request / response、項目名、型、error形式はOpenAPIを正本として使用する。
- RS-0004で実装したHTTP client、API型、vector検証処理を自然に再利用できる場合は再利用する。旧共通エラー型を再利用の前提にはしない。
- RAGScopeアプリケーション側では、API用の型とRAGScope内部で扱う質問・質問Embeddingの型を分け、境界で明示的に変換する。
- APIから返されたEmbeddingを無条件に受け入れず、後続のpgvector検索へ渡す前に次元と有限値を検証する。
- 自動テストではtest serverまたはHTTP clientの差し替えを利用し、実モデルへ毎回依存せずに正常responseと異常responseを確認してよい。
- v0.0では同期的に1件の質問を処理し、複数質問のbatch処理、並列化、再試行戦略は導入しない。
- 初期設計またはOpenAPIを変更する必要が生じた場合は、実装だけを先行させず、同じ変更で正本を更新する。

## 結果

> [!note] 完了時に記入
> - 実装したRAGScopeアプリケーション側のAPI clientとデータ変換
> - 質問文と質問Embeddingの保持方法
> - Trace Context伝播とHTTP client Spanの確認結果
> - 実行したテストコマンドと結果
> - AI推論サービスとの実接続確認結果
> - 確認した主要な異常系
> - OpenAPI・Embedding生成設計へ反映した内容
> - 既知の制約
> - 関連Pull Request
