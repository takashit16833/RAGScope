---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding要求をtimeoutと安全なretryで制御する]]"
---
# RS-0016 文書チャンクのEmbedding要求に必要なretryとtimeoutを設計する

## 目的

RAGScopeアプリケーションの再試行は、一時的失敗かつ再試行しても安全な場合だけ適用し、具体的な利用箇所がない汎用的な実行機構を先行実装しない。

このTicketでは、RAGScopeアプリケーションからAI推論サービスへ文書チャンクのEmbeddingを要求する処理を最初の対象として、必要な再試行・タイムアウトの現在設計を`design/リトライ・タイムアウト設計.md`に定義する。RS-0012で設計したAPI契約と主要な失敗を基に、どの失敗を何の根拠で再試行するか、再実行しても安全な条件は何か、どの時間範囲を制限するかを明確にし、RS-0017とRS-0004が実装へ着手できる判断基準を整える。

再試行・タイムアウトはTelemetryとは別の実行制御として設計する。Observabilityについては[実行追跡設計](../../../../design/observability/実行追跡設計.md)と[ログ・イベント設計](../../../../design/observability/ログ・イベント設計.md)を適用し、retry状態ごとに必ずログイベントを作ることは前提にしない。

## 前提

- [RS-0012 文書チャンクのEmbedding生成と保存を設計する](<../embedding-storage/RS-0012 文書チャンクのEmbedding生成と保存を設計する.md>)が完了している
- [RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する](<../error-logging/RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する.md>)が完了している
- `design/Embedding生成設計.md`と文書チャンクのEmbedding生成APIのOpenAPI初期定義から、処理の境界と主要な失敗を確認できる

## 完了条件

### 処理境界と再試行安全性

- [ ] `design/リトライ・タイムアウト設計.md`が`note_type: design`の機能設計書として作成されている
- [ ] 対象が「RAGScopeアプリケーションからAI推論サービスへ文書チャンクのEmbeddingを要求し、応答を受け取る論理的な処理」として明確に定義されている
- [ ] 1回の論理的な処理、1回のattempt、HTTP request、AI推論サービス側のEmbedding計算の境界が区別されている
- [ ] この処理が永続的な外部副作用を生成しないこと、または再試行を安全に行うために必要な条件が記載されている
- [ ] 再試行判断をObservability共通エラー分類へ固定せず、この処理の具体的なerror typeと実行条件から決定する方針が記載されている

### 失敗分類と再試行方針

- [ ] 接続失敗、通信中断、timeout、HTTP status、AI推論サービスの明示的な機能error、不正JSON、契約違反、入力不正、vector検証失敗などを、再試行対象と非対象へ分類する判断基準が記載されている
- [ ] 判断不能な失敗を安易に再試行対象へ含めない方針と、最終的に返す具体的なerrorの扱いが記載されている
- [ ] 最大試行回数が初回試行を含むかどうかと、試行上限へ達した場合の挙動が曖昧なく定義されている
- [ ] 待機方式、backoff、jitter、最大待機、全体時間上限、HTTP responseの再試行指示を扱うかどうかが、採否と理由を含めて定義されている
- [ ] 再試行方針の具体値と単位、設定の供給方法、v0.0で採用する初期値が記載されている

### タイムアウト

- [ ] timeoutを適用する範囲と種類、時間の起算点、timeout発生時の中断・後処理・具体的なerrorへの変換が定義されている

### Observability

- [ ] retryを含む論理処理と各attemptのSpan境界が[実行追跡設計](../../../../design/observability/実行追跡設計.md)およびRS-0004のHTTP client計装と重複しない形で定義されている
- [ ] retry途中の失敗だけを理由にEventRecordを定義せず、状態遷移そのものを名前付きで後から識別する必要があり、Spanでは表せない場合だけEventRecordを定義する方針が記載されている
- [ ] EventRecordを定義する場合はEventName、記録条件、timestamp、Severity、attributesを[ログ・イベント設計](../../../../design/observability/ログ・イベント設計.md)に従って定義する
- [ ] retry途中で失敗して最終成功した論理処理のSpanを、途中失敗だけを理由にErrorへしない方針が記載されている

### 実装境界・テスト・整合

- [ ] RS-0017が実装する実行機構の責務と、RS-0004が担当するHTTP request / response変換、Trace Context inject、Embedding対応検証の責務が区別されている
- [ ] 正常成功、一時的失敗後の成功、再試行しない失敗、試行上限到達、各timeoutを確認するテスト方針が記載されている
- [ ] テストが長い実待機や不安定な実時間へ過度に依存しないための境界が記載されている
- [ ] 後続の処理へ適用する際は、副作用と再試行安全性を個別に再評価することが明記されている
- [ ] batch処理・非同期jobやDB更新に固有の再実行・重複防止方式を、この処理へ先回りして導入していない
- [ ] 正確なHaskell型、関数、設定形式はコード、具体的なテストケースはテストコードを正本とすることが明記されている
- [ ] 所属EpicとEmbedding生成Epicの`関連文書`から`リトライ・タイムアウト設計.md`を参照できる状態になっている
- [ ] 関連する要求定義、システムアーキテクチャ、Observability設計、Embedding生成設計、OpenAPIに矛盾しないことを確認できる

## 対象外

- 文書読み込み、チャンク化、DB保存、質問Embedding、検索など、ほかの処理へ適用する再試行・タイムアウト方針
- AI推論サービスのEmbedding生成API実装
- Haskellの実HTTP clientとrequest / response変換
- 再試行の実行機構とtimeout制御の実装
- PostgreSQLのtransaction、`unique`制約、`upsert`による重複防止の具体化
- 大規模batch、並列request、非同期job
- OpenTelemetry共通基盤そのものの設計・実装
- CloudWatch固有の収集・監視設定

## 関連文書

- [RAGScope要求定義「2.3 信頼性と保守性」](<../../../../RAGScope要求定義.md#2.3 信頼性と保守性>)
- [システムアーキテクチャ「2.1 RAGScopeアプリケーション」](<../../../../design/システムアーキテクチャ.md#2.1 RAGScopeアプリケーション>)
- [システムアーキテクチャ「5. 通信と依存方向」](<../../../../design/システムアーキテクチャ.md#5. 通信と依存方向>)
- [Observability設計](../../../../design/observability/README.md)
- [実行追跡設計](../../../../design/observability/実行追跡設計.md)
- [ログ・イベント設計](../../../../design/observability/ログ・イベント設計.md)
- `design/Embedding生成設計.md`
- [RS-0012 文書チャンクのEmbedding生成と保存を設計する](<../embedding-storage/RS-0012 文書チャンクのEmbedding生成と保存を設計する.md>)
- [RS-0004 RAGScopeアプリケーションで文書チャンクのEmbeddingを取得する](<../embedding-storage/RS-0004 RAGScopeアプリケーションで文書チャンクのEmbeddingを取得する.md>)

## 実装メモ

- 本設計は対象のEmbedding要求に対する安全な実行制御を正本とし、一般的な再試行の解説書にはしない。
- 共通化はRS-0004で直ちに利用する範囲に限定し、将来の処理を想定した未使用の選択肢を増やさない。
- API固有のHTTP statusとerror内容はOpenAPI・Embedding生成設計を参照し、同じ定義を重複して正本化しない。
- 方針の値は根拠なく一般的な推奨値を採用せず、ローカルのAI推論サービス、モデル処理時間、v0.0の処理量を踏まえて決定する。

## 結果

> [!note] 完了時に記入
> - 対象のEmbedding要求と再試行安全性
> - 再試行対象・非対象の分類
> - 採用したtimeoutと再試行方針
> - Observabilityへ反映する情報
> - RS-0017とRS-0004の責務境界
> - テスト方針
> - 既知の制約
> - 関連Pull Request
