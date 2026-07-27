---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding要求をtimeoutと安全なretryで制御する]]"
---
# RS-0017 文書チャンクのEmbedding要求に必要なretry executorとtimeout制御を実装する

## 目的

RS-0016で定義した文書チャンクのEmbedding要求向けRetry Policyとtimeout規則を、RS-0004から利用できるHaskellの実行制御として実装する必要がある。

このTicketでは、対象operationに必要な最小範囲のretry executor、timeout制御、エラー分類との接続、試行eventの構造化ログ出力を実装する。実際の文書Embedding生成APIのrequest / response変換やチャンクとEmbeddingの対応検証はRS-0004に残し、このTicketでは1回の試行を安全に制御する部品と統合境界を完成させる。

## 前提

- [RS-0016 文書チャンクのEmbedding要求に必要なretryとtimeoutを設計する](<./RS-0016 文書チャンクのEmbedding要求に必要なretryとtimeoutを設計する.md>)が完了している
- [RS-0015 Haskellの共通エラー・構造化ログ基盤を実装する](<../error-logging/RS-0015 Haskellの共通エラー・構造化ログ基盤を実装する.md>)が完了している
- `docs/design/リトライ・タイムアウト設計.md`に、対象operationのPolicy、timeout、エラー分類、ログevent、テスト方針が記載されている

## 完了条件

- [ ] 設計で定義したPolicyを表現し、文書Embedding要求向けの実行制御へ渡せるHaskell型または設定境界が実装されている
- [ ] 1回の試行を表すactionを受け取り、成功結果または共通エラーを返すretry executorが実装されている
- [ ] 設計で定義した範囲へtimeoutを適用し、規定時間内に完了しない試行またはoperationを共通エラーとして扱える
- [ ] 一時的失敗かつ再試行安全と分類された場合だけretryする
- [ ] 入力不正、契約違反、不正なresponse、永続的なモデル失敗など、設計で非retryとした失敗を再試行せず返す
- [ ] 最大試行回数、待機、backoff、jitter、時間上限など、採用したPolicyが設計どおりに適用される
- [ ] retry予定、retry後の成功、試行上限到達、timeout、retryしない失敗について、設計で定義した構造化ログeventを共通ログ基盤へ渡せる
- [ ] 同じ論理operationに属する各試行が、設計した相関情報と試行番号によって追跡できる
- [ ] 試行上限へ達した場合に、最後の失敗原因と試行経過を失わず、呼び出し元へ返せる
- [ ] retry executorから具体的なHTTP client、JSON型、Python model実装への依存が分離されている
- [ ] RS-0004が1回のHTTP requestを表すactionを渡し、独自のretry loopを持たずにexecutorを利用できる公開境界がある
- [ ] 初回成功では追加試行を行わないことを自動テストで確認できる
- [ ] 一時的失敗後に成功する場合、設計した回数と待機でretryして成功結果を返すことを自動テストで確認できる
- [ ] retryしない失敗では追加試行を行わないことを自動テストで確認できる
- [ ] 試行上限到達時に最終エラーを返すことを自動テストで確認できる
- [ ] 設計で採用した各timeoutが発生した場合の中断とエラー変換を自動テストで確認できる
- [ ] retryとtimeoutのテストが長い実待機や不安定な実時間へ過度に依存せず、安定して実行できる
- [ ] retryに関係する構造化ログeventと相関情報をテスト用sinkで確認できる
- [ ] 実装で具体化または変更された現在設計が`docs/design/リトライ・タイムアウト設計.md`と`docs/design/エラー・ログ設計.md`へ反映されている
- [ ] 実装、両設計書、共通エラー・ログ基盤に解消していない差異がない
- [ ] プロジェクトで定めたHaskell側のテストコマンドを実行し、追加したテストを含めて成功する

## 対象外

- AI推論サービスの文書Embedding生成API実装
- Haskellの文書Embedding用request / response型とJSON変換
- 入力チャンクと返却Embeddingの対応検証
- RS-0004における実HTTP clientへの統合
- 文書Embedding要求以外のoperationへのretry / timeout適用
- PostgreSQL処理のtransaction、unique constraint、upsert
- 大規模batch、並列request、非同期job
- CloudWatch固有の収集・監視設定
- tracingの正確なSpan構造と処理間Link

## 関連文書

- [RAGScope要求定義「3.3 信頼性と保守性」](<../../../../docs/RAGScope要求定義.md#3.3 信頼性と保守性>)
- [システムアーキテクチャ「3.4 共通実行基盤の責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.4 共通実行基盤の責務境界>)
- [システムアーキテクチャ「5. HaskellとAI推論サービスの通信」](<../../../../docs/design/システムアーキテクチャ.md#5. HaskellとAI推論サービスの通信>)
- [ADR-0002 — 共通実行基盤の契約とコンポーネント実装を分離する](<../../../../docs/adr/ADR-0002 共通実行基盤の契約とコンポーネント実装を分離する.md>)
- [エラー・ログ設計](../../../../docs/design/エラー・ログ設計.md)
- [リトライ・タイムアウト設計](../../../../docs/design/リトライ・タイムアウト設計.md)
- [RS-0004 Haskellから文書チャンクのEmbeddingを取得する](<../embedding-storage/RS-0004 Haskellから文書チャンクのEmbeddingを取得する.md>)

## 実装メモ

- executorは対象operationで直ちに使う能力だけを実装し、未使用のstrategyやprovider固有optionを増やさない。
- 1回のHTTP requestを表すactionの実装はRS-0004が担当し、本Ticketはactionの反復、待機、timeout、終了判断を担当する。
- 待機、時刻、乱数などをテスト可能にする方法はRS-0016の設計に従い、テストのためだけに本番APIを不必要に複雑化しない。
- エラー分類は対象operationから与えられる判断を使用し、executor自身がすべてのHTTP statusやapplication errorを知る構成にしない。

## 結果

> [!note] 完了時に記入
> - 実装したRetry Policy表現とexecutor
> - 実装したtimeout制御
> - 出力する試行eventと相関情報
> - 実行した確認コマンドと結果
> - RS-0004へ提供した利用境界
> - 設計書へ反映した内容
> - 既知の制約
> - 関連Pull Request
