---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding要求をtimeoutと安全なretryで制御する]]"
---
# RS-0016 文書チャンクのEmbedding要求に必要なretryとtimeoutを設計する

## 目的

[ADR-0002](<../../../../docs/adr/ADR-0002 共通実行基盤の契約とコンポーネント実装を分離する.md>)では、retryを一時的失敗かつ再試行安全な場合だけ適用し、operation固有のPolicyと実装を具体的な利用箇所へ着手する段階で決定する方針を採用している。

このTicketでは、HaskellからPython AI Serviceへ文書チャンクのEmbeddingを要求するoperationを最初の対象として、必要なretry / timeoutの現在設計を`docs/design/リトライ・タイムアウト設計.md`に定義する。RS-0012で設計したAPI契約と主要な失敗を基に、どの失敗を何の根拠で再試行するか、再実行しても安全な条件は何か、どの時間範囲を制限するかを明確にし、RS-0017とRS-0004が実装へ着手できる判断基準を整える。

## 前提

- [RS-0015 Haskellの共通エラー・構造化ログ基盤を実装する](<../error-logging/RS-0015 Haskellの共通エラー・構造化ログ基盤を実装する.md>)が完了している
- [RS-0012 文書チャンクのEmbedding生成と保存を設計する](<../embedding-storage/RS-0012 文書チャンクのEmbedding生成と保存を設計する.md>)が完了している
- `docs/design/Embedding生成設計.md`と文書Embedding生成APIのOpenAPI初期定義から、operationの境界と主要な失敗を確認できる

## 完了条件

- [ ] `docs/design/リトライ・タイムアウト設計.md`が`note_type: design`の機能設計書として作成されている
- [ ] 対象operationが「HaskellからPython AI Serviceへ文書チャンクのEmbeddingを要求し、応答を受け取る処理」として明確に定義されている
- [ ] 1回の論理operation、1回の試行、HTTP request、Python側のEmbedding計算の境界が区別されている
- [ ] このoperationが永続的な外部副作用を生成しないこと、またはretryを安全に行うために必要な条件が記載されている
- [ ] retryの判断を共通エラー全体へ固定せず、このoperationのエラー分類と実行Contextから決定する方針が記載されている
- [ ] 接続失敗、通信中断、timeout、HTTP status、Python AI Serviceの明示的な失敗、不正なJSON、契約違反、入力不正、vector検証失敗などを、retry対象と非対象へ分類する判断基準が記載されている
- [ ] 判断不能な失敗を安易にretry対象へ含めない方針と、最終的に返すエラーの扱いが記載されている
- [ ] timeoutを適用する範囲と種類、時間の起算点、timeout発生時の中断・後処理・エラー変換が定義されている
- [ ] 最大試行回数が初回試行を含むかどうか、試行上限へ達した場合の挙動が曖昧なく定義されている
- [ ] 待機方式、backoff、jitter、最大待機、全体時間上限、HTTP responseのretry指示を扱うかどうかが、採否と理由を含めて定義されている
- [ ] Policyの具体値と単位、設定の供給方法、v0.0で採用する初期値が記載されている
- [ ] retryを予定した時、retry後に成功した時、試行上限へ達した時、timeoutした時に出力する構造化ログeventと必要なcontextが定義されている
- [ ] 同じ論理operationの各試行を、v0.0の相関情報を用いて追跡する方法が定義されている
- [ ] RS-0017が実装するexecutorの責務と、RS-0004が担当するHTTP request・response変換・Embedding対応検証の責務が区別されている
- [ ] 正常成功、一時的失敗後の成功、retryしない失敗、試行上限到達、各timeoutを確認するテスト方針が記載されている
- [ ] テストが長い実待機や不安定な実時間へ過度に依存しないための境界が記載されている
- [ ] 後続operationへ適用する際は、副作用と再試行安全性を個別に再評価することが明記されている
- [ ] batch・非同期jobやDB更新に固有の再実行・重複防止方式を、このoperationへ先回りして導入していない
- [ ] 正確なHaskell型、関数、設定形式はコード、具体的なテストケースはテストコードを正本とすることが明記されている
- [ ] 所属EpicとEmbedding生成Epicの`関連文書`から`リトライ・タイムアウト設計.md`を参照できる状態になっている
- [ ] 関連する要求定義、システムアーキテクチャ、ADR、エラー・ログ設計、Embedding生成設計、OpenAPIに矛盾しないことを確認できる

## 対象外

- 文書読み込み、チャンク化、DB保存、質問Embedding、検索など、ほかのoperationへ適用するretry / timeout Policy
- Python AI ServiceのEmbedding生成API実装
- Haskellの実HTTP clientとrequest / response変換
- retry executorとtimeout制御の実装
- PostgreSQL transaction、unique constraint、upsertによる重複防止の具体化
- 大規模batch、並列request、非同期job
- tracingの正確なSpan構造と処理間Link
- CloudWatch固有の収集・監視設定

## 関連文書

- [RAGScope要求定義「3.3 信頼性と保守性」](<../../../../docs/RAGScope要求定義.md#3.3 信頼性と保守性>)
- [システムアーキテクチャ「3.4 共通実行基盤の責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.4 共通実行基盤の責務境界>)
- [システムアーキテクチャ「5. HaskellとPythonの通信」](<../../../../docs/design/システムアーキテクチャ.md#5. HaskellとPythonの通信>)
- [ADR-0002 — 共通実行基盤の契約とコンポーネント実装を分離する](<../../../../docs/adr/ADR-0002 共通実行基盤の契約とコンポーネント実装を分離する.md>)
- [エラー・ログ設計](../../../../docs/design/エラー・ログ設計.md)
- [Embedding生成設計](../../../../docs/design/Embedding生成設計.md)
- [RS-0012 文書チャンクのEmbedding生成と保存を設計する](<../embedding-storage/RS-0012 文書チャンクのEmbedding生成と保存を設計する.md>)
- [RS-0004 Haskellから文書チャンクのEmbeddingを取得する](<../embedding-storage/RS-0004 Haskellから文書チャンクのEmbeddingを取得する.md>)

## 実装メモ

- 本設計は対象operationの安全な実行制御を正本とし、一般的なretryの解説書にはしない。
- 共通化はRS-0004で直ちに利用する範囲に限定し、将来のoperationを想定した未使用optionを増やさない。
- API固有のHTTP statusとエラーpayloadはOpenAPI・Embedding生成設計を参照し、同じ定義を重複して正本化しない。
- Policy値は根拠なく一般的な推奨値を採用せず、ローカルのPython AI Service、モデル処理時間、v0.0の処理量を踏まえて決定する。

## 結果

> [!note] 完了時に記入
> - 対象operationと再試行安全性
> - retry対象・非対象の分類
> - 採用したtimeoutとRetry Policy
> - 定義した構造化ログevent
> - RS-0017とRS-0004の責務境界
> - テスト方針
> - 既知の制約
> - 関連Pull Request
