---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding生成と保存]]"
---
# RS-0004 Haskellから文書チャンクのEmbeddingを取得する

## 目的

v0.0で文書チャンクとEmbeddingをPostgreSQLへ保存するためには、RS-0002で生成した文書チャンクをHaskellからPython AI Serviceへ渡し、RS-0003で実装した文書Embedding生成APIから、各チャンクに対応するEmbeddingを受け取れる必要がある。

このTicketでは、RS-0012の初期設計とOpenAPIに従い、HaskellからHTTP / JSONでPython AI Serviceを呼び出す。1回のHTTP requestは、RS-0017で実装したretry executorとtimeout制御を通じて実行する。元文書を識別する情報、`chunkIndex`、本文と、Python AI Serviceから返されたEmbeddingの対応関係を検証し、後続の保存処理から利用できる値として取得する。

## 前提

- [RS-0012 文書チャンクのEmbedding生成と保存を設計する](<./RS-0012 文書チャンクのEmbedding生成と保存を設計する.md>)が完了している
- [RS-0003 Python AI Serviceで文書チャンクのEmbeddingを生成する](<./RS-0003 Python AI Serviceで文書チャンクのEmbeddingを生成する.md>)が完了している
- [RS-0017 文書チャンクのEmbedding要求に必要なretry executorとtimeout制御を実装する](<../embedding-request-reliability/RS-0017 文書チャンクのEmbedding要求に必要なretry executorとtimeout制御を実装する.md>)が完了している
- `RS-0002`が完了し、文書チャンクをHaskellの値として取得できる

## 完了条件

- [ ] HaskellからPython AI Serviceの文書Embedding生成APIへHTTP / JSONでrequestを送信できる
- [ ] 1件以上の文書チャンクについて、元文書を識別する情報、`chunkIndex`、本文をAPI requestへ変換できる
- [ ] 1回のHTTP requestを表すactionがRS-0017のexecutorへ接続され、独自のretry loopを実装していない
- [ ] 機能別設計で定めたtimeoutが実際の文書Embedding要求へ適用されている
- [ ] 一時的失敗かつ再試行安全な場合にだけ、機能別設計で定めたPolicyに従ってretryできる
- [ ] retry対象外のHTTP失敗、Python AI Serviceの明示的な失敗、不正なJSON、入力・契約違反、vector検証失敗を追加試行せず返せる
- [ ] retryを行わない失敗、retry後の成功、試行上限到達、timeoutを、共通エラーと構造化ログで区別して確認できる
- [ ] Python AI Serviceから成功応答を受け取り、各チャンクに対応するEmbeddingをHaskellの値として取得できる
- [ ] 入力したチャンク件数と返却されたEmbedding件数が一致することを確認できる
- [ ] 入力チャンクとEmbeddingの対応を、OpenAPIで定めた順序または識別子によって一意に検証できる
- [ ] 取得した各Embeddingが設計で定めたvector次元と一致し、`NaN`や無限大など利用できない値を含まないことを確認できる
- [ ] 元文書を識別する情報、`chunkIndex`、本文、対応するEmbeddingを保持し、後続の保存処理へ渡せる値を取得できる
- [ ] Python AI Serviceへ接続できない場合を、正常なEmbedding取得と区別して扱える
- [ ] Python AI ServiceがEmbedding生成失敗を返した場合を、正常なEmbedding取得と区別して扱える
- [ ] HTTPの失敗status、不正なJSON、必須項目の欠落を、それぞれ正常な応答と区別して扱える
- [ ] 件数不一致、識別子または順序の不整合、vector次元の不一致を検出し、不正な対応関係を後続処理へ渡さない
- [ ] requestの組み立て、responseのdecode、チャンクとEmbeddingの対応、vector検証、主要な異常系を自動テストで確認できる
- [ ] test serverまたは同等の制御された境界を使用し、一時的失敗後の成功、retryしない失敗、試行上限到達、timeoutをAPI clientとの統合テストで確認できる
- [ ] 実際に起動したPython AI ServiceをHaskellから呼び出し、複数の文書チャンクに対応するEmbeddingを取得できることを統合テストまたは実行によって確認できる
- [ ] Haskell側の実装とOpenAPIの契約が一致している
- [ ] 実装で具体化または変更された文書Embedding取得フローが`docs/design/Embedding生成設計.md`と`docs/design/リトライ・タイムアウト設計.md`へ反映されている
- [ ] 実装、OpenAPI、Embedding生成設計、リトライ・タイムアウト設計に解消していない差異がない
- [ ] プロジェクトで定めたHaskell側のテストコマンドを実行し、追加したテストを含めて成功する

## 対象外

- Python AI Serviceでのモデル選定、モデル・Tokenizerのロード、Embedding生成APIの実装
- Embedding生成APIの契約をゼロから設計する作業
- retry / timeoutのPolicyとexecutorをゼロから設計・実装する作業
- PostgreSQL / pgvectorの導入、DB schema、migration
- 文書チャンクとEmbeddingのPostgreSQLへの保存
- 保存済みデータの読み出し
- 質問文の入力と質問Embeddingの生成
- dense検索、全文検索、hybrid検索、reranking
- Generation modelによる回答生成と引用
- 複数のEmbedding modelまたは生成条件の切り替え・比較
- 文書Embedding要求以外のoperationへのretry / timeout適用
- 文書Embedding要求以外のoperationに固有の再実行・重複防止
- 大規模batch処理、非同期job、並列request
- AWSへの配置

## 関連文書

- [RAGScope要求定義「2.2 検索」](<../../../../docs/RAGScope要求定義.md#2.2 検索>)
- [RAGScope要求定義「3.3 信頼性と保守性」](<../../../../docs/RAGScope要求定義.md#3.3 信頼性と保守性>)
- [システムアーキテクチャ「3.1 Haskellの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.1 Haskellの責務境界>)
- [システムアーキテクチャ「3.2 Pythonの責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.2 Pythonの責務境界>)
- [システムアーキテクチャ「3.4 共通実行基盤の責務境界」](<../../../../docs/design/システムアーキテクチャ.md#3.4 共通実行基盤の責務境界>)
- [システムアーキテクチャ「5. HaskellとPythonの通信」](<../../../../docs/design/システムアーキテクチャ.md#5. HaskellとPythonの通信>)
- [システムアーキテクチャ「6. 文書取り込みの全体フロー」](<../../../../docs/design/システムアーキテクチャ.md#6. 文書取り込みの全体フロー>)
- [ADR-0002 — 共通実行基盤の契約とコンポーネント実装を分離する](<../../../../docs/adr/ADR-0002 共通実行基盤の契約とコンポーネント実装を分離する.md>)
- [エラー・ログ設計](../../../../docs/design/エラー・ログ設計.md)
- [リトライ・タイムアウト設計](../../../../docs/design/リトライ・タイムアウト設計.md)
- [文書処理設計](<../../../../docs/design/文書処理設計.md>)
- [Embedding生成設計](<../../../../docs/design/Embedding生成設計.md>)
- [データモデル設計](<../../../../docs/design/データモデル設計.md>)
- [RS-0016 文書チャンクのEmbedding要求に必要なretryとtimeoutを設計する](<../embedding-request-reliability/RS-0016 文書チャンクのEmbedding要求に必要なretryとtimeoutを設計する.md>)
- [RS-0017 文書チャンクのEmbedding要求に必要なretry executorとtimeout制御を実装する](<../embedding-request-reliability/RS-0017 文書チャンクのEmbedding要求に必要なretry executorとtimeout制御を実装する.md>)

## 実装メモ

- HaskellはRAGScopeの処理全体とデータの対応関係を管理し、Python AI ServiceはAI推論だけを担当する。
- APIの正確なpath、request / response、項目名、型、エラー形式はOpenAPIを正本として使用する。
- Haskell側では、API用の型とRAGScope内部の文書チャンク型を分け、境界で明示的に変換する。
- Python AI Serviceから返された配列を無条件に入力チャンクへ`zip`せず、API契約で定めた対応を検証してから関連付ける。
- 対応付け後の値は、元文書を識別する情報、`chunkIndex`、元の本文、Embeddingを失わずに保持する。正確な型名やフィールド名はコードを正本とする。
- 自動テストではtest serverまたはHTTP clientの差し替えを利用し、実モデルへ毎回依存せずに正常応答と異常応答を確認してよい。
- 1回のHTTP requestを表すactionだけをこのTicketで実装し、試行の反復、待機、timeout、終了判断はRS-0017のexecutorへ委ねる。
- 初期設計、OpenAPI、retry / timeout設計を変更する必要が生じた場合は、実装だけを先行させず、同じ変更で正本を更新する。

## 結果

> [!note] 完了時に記入
> - 実装したHaskell側のAPI clientとデータ変換
> - チャンクとEmbeddingの対応方法
> - 適用したretry / timeoutと確認結果
> - 実行したテストコマンドと結果
> - Python AI Serviceとの実接続確認結果
> - 確認した主要な異常系
> - OpenAPI・Embedding生成設計・リトライ・タイムアウト設計へ反映した内容
> - 既知の制約
> - 関連Pull Request
