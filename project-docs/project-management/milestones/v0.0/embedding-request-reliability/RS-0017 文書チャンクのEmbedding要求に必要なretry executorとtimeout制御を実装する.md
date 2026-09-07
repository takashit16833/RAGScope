---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding要求をtimeoutと安全なretryで制御する]]"
---
# RS-0017 文書チャンクのEmbedding要求に必要なretry executorとtimeout制御を実装する

## 目的

RS-0016で定義した文書チャンクのEmbedding要求向けの再試行方針とtimeout規則を、RS-0004から利用できるRAGScopeアプリケーションの実行制御としてHaskellで実装する。

このTicketでは、対象のEmbedding要求に必要な最小範囲の再試行の実行機構、timeout制御、具体的なerror分類との接続を実装する。実際のEmbedding生成APIのrequest / response変換、Trace Context inject、各HTTP attemptのclient Span、文書チャンクとEmbeddingの対応検証はRS-0004に残す。このTicketでは、attemptの反復、待機、timeout、終了判断と統合境界を完成させる。

## 前提

- [RS-0016 文書チャンクのEmbedding要求に必要なretryとtimeoutを設計する](<./RS-0016 文書チャンクのEmbedding要求に必要なretryとtimeoutを設計する.md>)が完了している
- [RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する](<../error-logging/RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する.md>)が完了している
- `design/リトライ・タイムアウト設計.md`に、対象のEmbedding要求の方針、timeout、error分類、Observabilityへの反映、テスト方針が記載されている

## 完了条件

### 方針と実行機構

- [ ] 設計で定義した方針を表現し、文書チャンクのEmbedding要求向けの実行制御へ渡せるHaskell型または設定境界が実装されている
- [ ] 1回のattemptを表す処理を受け取り、その処理の成功値または具体的なerror値を失わず返す再試行の実行機構が実装されている
- [ ] 設計で定義した範囲へtimeoutを適用し、規定時間内に完了しないattemptまたは論理処理を設計で定めた具体的なerrorとして扱える
- [ ] 一時的失敗かつ再試行しても安全と分類された場合だけ再試行する
- [ ] 入力不正、契約違反、不正response、永続的なモデル失敗など、設計で再試行しないとした失敗を追加attemptなしで返す
- [ ] 最大試行回数、待機、backoff、jitter、時間上限など、採用した方針が設計どおりに適用される
- [ ] 共通`RAGScopeError`、`ErrorType`、`ErrorClassifier`をretry executorのために新設していない

### Observabilityと最終エラー

- [ ] retry executorがTelemetryを理由に再試行・終了判断を変更していない
- [ ] 各HTTP attemptのclient SpanはRS-0004へ委ね、retry executorが同じHTTP処理を表す重複Spanを追加していない
- [ ] retryを含む上位処理のSpanを扱う場合、そのStatusと`error.type`を途中attemptではなく最終結果から決定できる
- [ ] retry予定、retry後の成功、試行上限到達、timeout、再試行しない失敗について、RS-0016がEventRecordを必要と判断した状態遷移だけをTelemetry利用境界へ渡せる。RS-0016で定義していない共通EventRecordを実装側で追加していない
- [ ] 試行上限へ達した場合に、最後の具体的な失敗原因と試行経過を失わず呼び出し元へ返せる

### RS-0004との統合境界

- [ ] 再試行の実行機構から、具体的なHTTP client、JSON型、Pythonモデル実装への依存が分離されている
- [ ] RS-0004が1回のHTTP requestを表す処理を渡し、独自のretry loopを持たずに実行機構を利用できる公開境界がある
- [ ] Trace ContextのinjectとHTTP client Spanの生成はRS-0004側の1 attempt処理に含まれ、retry executorはその処理を反復するだけである

### テスト・設計反映・整合

- [ ] 初回成功では追加attemptを行わないことを自動テストで確認できる
- [ ] 一時的失敗後に成功する場合、設計した回数と待機で再試行して成功結果を返すことを自動テストで確認できる
- [ ] 再試行しない失敗では追加attemptを行わないことを自動テストで確認できる
- [ ] 試行上限到達時に最終errorを返すことを自動テストで確認できる
- [ ] 設計で採用した各timeoutが発生した場合の中断とerror変換を自動テストで確認できる
- [ ] 再試行とtimeoutのテストが長い実待機や不安定な実時間へ過度に依存せず、安定して実行できる
- [ ] RS-0016で定義したTelemetryがある場合、その記録条件と値をテスト用Telemetry境界で確認できる
- [ ] 実装で具体化または変更された現在設計が`design/リトライ・タイムアウト設計.md`へ反映されている
- [ ] 実装、設計書、RS-0024のTelemetry利用境界に解消していない差異がない
- [ ] プロジェクトで定めたRAGScopeアプリケーション側のテストコマンドを実行し、追加したテストを含めて成功する

## 対象外

- AI推論サービスの文書チャンクのEmbedding生成API実装
- 文書チャンクのEmbedding要求に使用するHaskellのrequest / response型とJSON変換
- 入力した文書チャンクと返却されたEmbeddingの対応検証
- RS-0004における実HTTP clientへの統合
- 文書チャンクのEmbedding要求以外の処理への再試行・timeout適用
- PostgreSQL処理のtransaction、`unique`制約、`upsert`
- 大規模batch、並列request、非同期job
- Tempo / Loki / Prometheus / Grafanaの構成

## 関連文書

- [RAGScope要求定義「2.3 信頼性と保守性」](<../../../../RAGScope要求定義.md#2.3 信頼性と保守性>)
- [システムアーキテクチャ「2.1 RAGScopeアプリケーション」](<../../../../design/システムアーキテクチャ.md#2.1 RAGScopeアプリケーション>)
- [システムアーキテクチャ「5. 通信と依存方向」](<../../../../design/システムアーキテクチャ.md#5. 通信と依存方向>)
- [Observability設計](../../../../design/observability/README.md)
- [実行追跡設計](../../../../design/observability/実行追跡設計.md)
- [ログ・イベント設計](../../../../design/observability/ログ・イベント設計.md)
- `design/リトライ・タイムアウト設計.md`
- [RS-0004 RAGScopeアプリケーションで文書チャンクのEmbeddingを取得する](<../embedding-storage/RS-0004 RAGScopeアプリケーションで文書チャンクのEmbeddingを取得する.md>)
- [RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する](<../error-logging/RS-0024 RAGScopeアプリケーションへOpenTelemetry Observability最小基盤を実装する.md>)

## 実装メモ

- 実行機構は対象のEmbedding要求で直ちに使う能力だけを実装し、未使用の戦略や提供元固有の選択肢を増やさない。
- 1回のHTTP requestを表す処理の実装はRS-0004が担当し、本Ticketはその処理の反復、待機、timeout、終了判断を担当する。
- 待機、時刻、乱数などをテスト可能にする方法はRS-0016の設計に従い、テストのためだけに本番APIを不必要に複雑化しない。
- error分類は対象のEmbedding要求から与えられる判断を使用し、実行機構自身がすべてのHTTP statusやApplication errorを知る構成にしない。

## 結果

> [!note] 完了時に記入
> - 実装した再試行方針の表現と実行機構
> - 実装したtimeout制御
> - Observabilityへの反映と確認結果
> - 実行した確認コマンドと結果
> - RS-0004へ提供した利用境界
> - 設計書へ反映した内容
> - 既知の制約
> - 関連Pull Request
