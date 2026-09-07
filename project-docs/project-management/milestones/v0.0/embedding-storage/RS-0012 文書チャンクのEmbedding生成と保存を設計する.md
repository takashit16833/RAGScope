---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 文書チャンクのEmbedding生成と保存]]"
---
# RS-0012 文書チャンクのEmbedding生成と保存を設計する

## 目的

このEpicでは、AI推論サービスによるEmbedding生成、RAGScopeアプリケーションとのHTTP / JSON通信、PostgreSQL / pgvectorのデータ構造、文書チャンクとEmbeddingの保存を複数の実装Ticketで構築する。これらは、採用するEmbeddingモデル、生成条件、API契約、ベクトル次元、保存するデータの関係を共有している。

このTicketでは、RS-0003からRS-0006へ着手する前に、文書チャンクのEmbedding生成から保存までの初期設計を行う。現在設計の正本として`design/Embedding生成設計.md`と`design/データモデル設計.md`を作成し、AI推論サービスの文書チャンクのEmbedding生成APIについてOpenAPIなどの機械可読な初期定義を作成する。

RAGScopeアプリケーションからAI推論サービスへ文書チャンクのEmbeddingを要求する処理の具体的な再試行・タイムアウト方針と実行機構は、RS-0016とRS-0017で別に設計・実装する。このTicketでは、後続の再試行・タイムアウト設計が判断できるよう、処理の境界、副作用、主要な失敗、HTTP契約を定義するが、具体的な試行回数や待機方式は固定しない。

Observabilityは[Observability設計](../../../../design/observability/README.md)を前提とし、コンポーネント間の追跡にはOpenTelemetry Trace Contextを使用する。APIの業務データへRAGScope独自の`execution_id`を追加しない。

初期設計では、後続Ticketが実装へ着手できる判断基準とコンポーネント間の契約を整える。正確なHaskell・Pythonの型、SQL、マイグレーションの定義は、それぞれの機械可読な正本で実装時に確定する。

## 前提

- [RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する](<../error-logging/RS-0023 OpenTelemetry Logsを前提に実行追跡・構造化ログアーキテクチャを再設計する.md>)が完了している
- `RS-0002`までに、固定Markdown文書から後続処理へ渡せる文書チャンクを生成できる見通しが立っている
- [文書処理設計](../../../../design/features/文書処理設計.md)に、文書チャンクが保持する概念上の情報と不変条件が記載されている
- [Observability設計](../../../../design/observability/README.md)と[実行追跡設計](../../../../design/observability/実行追跡設計.md)に、コンポーネント境界のTrace Context伝播と失敗のTelemetry反映規則が記載されている

## 完了条件

### 設計書と全体フロー

- [ ] `design/Embedding生成設計.md`が`note_type: design`の機能設計書として作成されている
- [ ] `design/データモデル設計.md`が`note_type: design`の機能設計書として作成されている
- [ ] RAGScopeアプリケーション、AI推論サービス、PostgreSQL / pgvectorの責務と、文書チャンクの受け渡しから保存までの全体フローが記載されている
- [ ] AI推論サービスがAI推論を担当し、RAGScopeアプリケーションが処理全体とデータの対応関係を管理する責務境界が記載されている

### Embeddingモデルと生成条件

- [ ] v0.0で使用するEmbeddingモデルが1つ選定され、モデルID、リビジョン、Tokenizer、Tokenizerのリビジョンを固定する方針が記載されている
- [ ] 採用候補について、ローカル環境での利用可能性とRAGScopeでの利用を妨げるライセンス上の問題がないことを確認できる
- [ ] 文書用・質問用の入力規則、プーリング、最大入力長、切り詰め（truncation）、ベクトル正規化の有無、出力次元が固定条件として記載されている
- [ ] 文書用と質問用のEmbeddingを比較可能に保つ互換条件が記載されている
- [ ] 生存確認、推論可能状態、使用中のモデル・リビジョン・出力次元を確認する方法が設計されている

### API契約・失敗・Trace Context

- [ ] RAGScopeアプリケーションからAI推論サービスへ文書チャンクのEmbeddingを要求する処理全体、1回のHTTP request、AI推論サービス側のEmbedding計算の概念上の境界が区別されている
- [ ] 文書チャンクのEmbedding生成APIの入力、出力、入力とEmbeddingの対応方法、主要な機能errorとHTTP error表現が設計されている
- [ ] AI推論サービスの機能error、HTTP通信失敗、不正response、入力・契約違反を、それぞれの具体的なerror typeで区別し、共通`RAGScopeError`へ集約しない方針が記載されている
- [ ] RAGScopeアプリケーションが現在のOpenTelemetry Trace ContextをHTTP境界へinjectし、AI推論サービスがextractして同じTraceを継続する責務境界が記載されている
- [ ] Trace ContextのHTTP表現は採用するOpenTelemetry propagator / HTTP instrumentationへ委ね、OpenAPIの業務requestへ独自`execution_id`を追加していない
- [ ] リクエスト検証、Webフレームワーク、モデル、Tokenizer、AIライブラリのうち、文書チャンクのEmbedding生成で扱う機能固有Exceptionを、具体的な機能errorとAPI error responseへ変換する方針が記載されている
- [ ] 文書チャンクのEmbedding生成APIの正確なrequest / responseが、OpenAPIなどの機械可読な初期定義として作成されている

### データモデルと保存

- [ ] 文書チャンクとEmbeddingを保存する最小のデータ構造について、保持する情報、責務、関係、不変条件が記載されている
- [ ] 元文書を識別する情報と`chunkIndex`によってv0.0の文書チャンクを一意に扱い、文書チャンク本文とEmbeddingの対応を維持する方針が記載されている
- [ ] Embedding列が選定モデルの固定出力次元と一致し、不完全な検索対象や負の`chunkIndex`を許可しない方針が記載されている
- [ ] 複数の文書チャンクを保存するトランザクション境界と、Embedding生成中にDBトランザクションを保持しない方針が記載されている
- [ ] 同じ固定文書の取り込みを再実行した場合に、識別不能な重複を残さない初期方針が記載されている

### 再試行・タイムアウトとの境界

- [ ] 後続のRS-0016が再試行対象と再試行安全性を判断できるよう、Embedding要求の副作用と失敗時に成立する条件が記載されている
- [ ] 再試行・タイムアウトの具体的な方針と実行機構をRS-0016・RS-0017の責務として分離し、このTicketで重複して正本化していない

### 正本と整合

- [ ] DBの正確なテーブル・カラム・制約はmigration、API schemaはOpenAPI、型はコードを正本とすることが明記されている
- [ ] v0.0では導入しないモデル比較、Embedding条件のバージョン管理、Embeddingのcache、近似検索indexなどの境界が記載されている
- [ ] 関連する要求定義、システムアーキテクチャ、Observability設計、文書処理設計に矛盾しないことを確認できる
- [ ] 所属Epicの`関連文書`から、作成した設計書を参照できる状態になっている

## 対象外

- AI推論サービスの実装
- HaskellのHTTP clientの実装
- PostgreSQL / pgvectorのmigration作成
- 文書チャンクとEmbeddingの保存処理の実装
- 文書チャンクのEmbedding要求の具体的な再試行回数、待機、backoff、jitter、timeout、実行機構
- 質問Embedding生成APIの実装
- exact vector searchとCLIの設計・実装
- 複数のEmbeddingモデルを実測比較するExperiment
- Haskell・Pythonの正確な型名、関数名、package構成の確定
- DBの正確なtable名、column名、SQL、constraint名の確定

## 関連文書

- [RAGScope要求定義「1.3.1 検索」](<../../../../RAGScope要求定義.md#1.3.1 検索>)
- [RAGScope要求定義「2.3 信頼性と保守性」](<../../../../RAGScope要求定義.md#2.3 信頼性と保守性>)
- [システムアーキテクチャ「2.1 RAGScopeアプリケーション」](<../../../../design/システムアーキテクチャ.md#2.1 RAGScopeアプリケーション>)
- [システムアーキテクチャ「2.2 AI推論サービス」](<../../../../design/システムアーキテクチャ.md#2.2 AI推論サービス>)
- [システムアーキテクチャ「4.1 文書を検索可能にする」](<../../../../design/システムアーキテクチャ.md#4.1 文書を検索可能にする>)
- [システムアーキテクチャ「5. 通信と依存方向」](<../../../../design/システムアーキテクチャ.md#5. 通信と依存方向>)
- [Observability設計](../../../../design/observability/README.md)
- [実行追跡設計](../../../../design/observability/実行追跡設計.md)
- [文書処理設計](../../../../design/features/文書処理設計.md)
- [RS-0016 文書チャンクのEmbedding要求に必要なretryとtimeoutを設計する](<../embedding-request-reliability/RS-0016 文書チャンクのEmbedding要求に必要なretryとtimeoutを設計する.md>)

## 実装メモ

- モデル選定は精度比較ではなく、v0.0のローカル環境で実行できること、文書用と質問用のEmbeddingを互換に生成できること、revisionを固定できること、ライセンス上利用可能であることを基準に行う。
- 質問Embeddingの生成処理自体は後続Epicで実装するが、文書チャンクのEmbeddingとの互換性を確保するため、質問用の入力規則はこの時点で設計する。
- OpenAPIの初期定義は、RS-0003で実装する文書チャンクのEmbedding生成の業務request / responseを対象とする。Trace Context伝播はOpenTelemetry propagatorへ委ね、独自の業務fieldとして重複定義しない。
- `データモデル設計.md`にはmigrationを複製せず、保存対象の責務、関係、不変条件、transactionと再実行の方針を記載する。
- RS-0016は、本Ticketで定義したEmbedding要求の境界、API契約、主要な失敗を入力として再試行・タイムアウトを設計する。同じ方針を両方の設計書へ重複して記載しない。
- 実装によって初期設計を変更する必要が生じた場合は、該当する実装TicketでOpenAPI・設計書・実装を同じ変更として整合させる。

## 結果

> [!note] 完了時に記入
> - 選定したEmbeddingモデルと固定条件
> - 作成したEmbedding生成設計の概要
> - 作成したデータモデル設計の概要
> - 作成したOpenAPIなどのAPI初期定義
> - RS-0016へ渡したEmbedding要求の境界と主要な失敗
> - 実装Ticketへ残した判断事項
> - 更新したEpicの関連文書
> - 既知の未決定事項
> - 関連Pull Request
