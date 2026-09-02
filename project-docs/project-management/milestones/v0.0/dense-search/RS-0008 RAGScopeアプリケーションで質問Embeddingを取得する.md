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

実行追跡では、RAGScopeアプリケーション側のcurrent `span`からTrace Contextを取得し、RS-0013で確定した通信形式でAI推論サービスへ引き継ぐ。AI推論サービス側ではそのContextから同じ`trace`を継続する。

## 前提

- [RS-0013 質問によるdense検索を設計する](<./RS-0013 質問によるdense検索を設計する.md>)が完了している
- [RS-0007 AI推論サービスで質問Embeddingを生成する](<./RS-0007 AI推論サービスで質問Embeddingを生成する.md>)が完了している
- `design/Embedding生成設計.md`とOpenAPIが質問Embeddingの実装とTrace Context伝播を含む通信契約に一致している

## 完了条件

### APIリクエスト・Trace Context・質問Embeddingの取得

- [ ] RAGScopeアプリケーションからAI推論サービスの質問Embedding生成APIへHTTP / JSONでリクエストを送信できる
- [ ] RAGScopeアプリケーションが保持する1件の空でない質問文を、APIリクエストへ変換できる
- [ ] current Trace ContextをRS-0013で定義した通信形式へ変換し、AI推論サービスへ引き継げる
- [ ] AI推論サービスが同じ`TraceId`で呼び出し元`span`を親とする新しい`span`を開始できるTrace Contextを送信できる
- [ ] AI推論サービスから成功応答を受け取り、質問EmbeddingをHaskellの値として取得できる
- [ ] 元の質問文と対応するEmbeddingを保持し、後続のdense検索処理へ渡せる値を取得できる

### Embeddingの検証

- [ ] 取得した質問Embeddingが、設計で定めた文書チャンクのEmbeddingと同じベクトル次元を持つことを確認できる
- [ ] 取得した質問Embeddingに、`NaN`や無限大など利用できない値が含まれないことを確認できる
- [ ] ベクトル次元の不一致または有限値でない要素を検出し、不正なEmbeddingを後続処理へ渡さない

### エラー・実行追跡・構造化ログ

- [ ] 空文字または空白だけの質問文をAI推論サービスへ送信せず、正常なEmbedding取得と区別して扱える
- [ ] AI推論サービスへ接続できない場合を、正常なEmbedding取得と区別して扱える
- [ ] AI推論サービスが質問Embedding生成失敗を返した場合を、正常なEmbedding取得と区別して扱える
- [ ] HTTPの失敗ステータス、不正なJSON、必須項目の欠落を、それぞれ正常な応答と区別して扱える
- [ ] 質問Embedding要求を追跡するRAGScopeアプリケーション側`span`が、その処理自身の最終結果に従って`Error`または`Unset`になる
- [ ] 機能設計で記録対象とした構造化ログがcurrent `span`の`TraceId`・`SpanId`へ関連付く
- [ ] 同じ失敗を`span`と構造化ログの両方へ記録する場合は同じ`error_type`を使用する

### 設計反映と検証

- [ ] リクエストの組み立て、レスポンスのJSON復元、入力検証、ベクトル検証、主要な異常系を自動テストで確認できる
- [ ] test serverまたは同等の制御された境界で、RS-0013の通信契約どおりにTrace ContextがHTTP requestへ付与されていることを確認できる
- [ ] 実際に起動したAI推論サービスをRAGScopeアプリケーションから呼び出し、同じ`trace`を継続した状態で質問文に対応する質問Embeddingを取得できることを結合テストまたは実行によって確認できる
- [ ] RAGScopeアプリケーション側の実装とOpenAPIのリクエスト・レスポンス、Trace Context伝播、必須条件が一致している
- [ ] 実装で具体化または変更された質問Embedding取得フローが`design/Embedding生成設計.md`へ反映されている
- [ ] 実装、OpenAPI、Embedding生成設計、実行追跡・構造化ログ契約に解消していない差異がない
- [ ] プロジェクトで定めたRAGScopeアプリケーション側のテストコマンドを実行し、追加したテストを含めて成功する

## 対象外

- AI推論サービスでのモデル選定、モデル・Tokenizerの読み込み
- AI推論サービスで質問Embeddingを生成する処理の実装
- 質問Embedding APIの契約をゼロから設計する作業
- PostgreSQL / pgvectorへの接続
- dense検索クエリ、順位付け、上位文書チャンクの取得
- RAGScope CLIの検索コマンドと質問入力UI
- 検索結果のCLI表示
- 質問、質問Embedding、検索結果の永続化
- 全文検索、hybrid検索、`reranking`
- 生成モデルによる回答生成と引用
- 複数のEmbeddingモデルまたは生成条件の切り替え・比較
- 再試行方針、可変タイムアウト、サーキットブレーカーなどの本格的な障害制御
- 大規模なバッチ処理、非同期ジョブ、並列リクエスト
- AWSへの配置
- 共通のTrace Context意味や実行追跡契約をこのTicketで再定義すること

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../RAGScope要求定義.md#2.2 検索>)
- [システムアーキテクチャ](../../../../design/システムアーキテクチャ.md)
- [実行追跡・構造化ログ契約設計](../../../../design/実行追跡・構造化ログ契約設計.md)
- [RAGScopeアプリケーション実行追跡詳細設計](../../../../design/tracing/RAGScopeアプリケーション実行追跡詳細設計.md)
- [RS-0013 質問によるdense検索を設計する](<./RS-0013 質問によるdense検索を設計する.md>)
- [RS-0007 AI推論サービスで質問Embeddingを生成する](<./RS-0007 AI推論サービスで質問Embeddingを生成する.md>)
- `design/Embedding生成設計.md`
- `design/検索設計.md`

## 実装メモ

- RAGScopeアプリケーションはRAGScopeの処理全体を制御し、AI推論サービスは質問Embeddingの生成だけを担当する。
- APIの正確なパス、リクエスト・レスポンス、項目名、型、エラー形式、Trace Context通信形式はOpenAPIなどRS-0013で確定した機械可読な通信契約を正本として使用する。
- Trace Contextの取得はRAGScopeアプリケーションの実行追跡境界から行い、この機能が`TraceId`・`SpanId`を独自生成しない。
- RS-0004で実装したHTTPクライアント、共通のAPI型、エラー型、ベクトル検証処理を自然に再利用できる場合は再利用する。
- RAGScopeアプリケーション側では、API用の型とRAGScope内部で扱う質問・質問Embeddingの型を分け、境界で明示的に変換する。
- APIから返されたEmbeddingを無条件に受け入れず、後続のpgvector検索へ渡す前に次元と有限値を検証する。
- 自動テストではテスト用サーバーまたはHTTPクライアントの差し替えを利用し、実モデルへ毎回依存せずに正常応答と異常応答を確認してよい。
- v0.0では同期的に1件の質問を処理し、複数質問のバッチ処理、並列化、再試行戦略は導入しない。
- 初期設計またはOpenAPIを変更する必要が生じた場合は、実装だけを先行させず、同じ変更で正本を更新する。

## 結果

> [!note] 完了時に記入
> - 実装したRAGScopeアプリケーション側のAPIクライアントとデータ変換
> - Trace Context伝播と分散traceの確認結果
> - 質問文と質問Embeddingの保持方法
> - 実行したテストコマンドと結果
> - AI推論サービスとの実接続確認結果
> - 確認した主要な異常系
> - OpenAPI・Embedding生成設計へ反映した内容
> - 既知の制約
> - 関連Pull Request