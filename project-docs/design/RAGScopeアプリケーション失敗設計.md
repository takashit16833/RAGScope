---
note_type: design
---
# RAGScopeアプリケーション失敗設計

> [!abstract] この文書の役割
> RAGScopeアプリケーションで、UseCaseや内部処理が失敗をどの単位で表し、外部依存の失敗をどこで変換し、CLI / API、実験・評価、Telemetryがその失敗をどう利用するかを定義する。

## 1. 基本方針

RAGScopeアプリケーションでは、アプリケーション全体の失敗を1つの共通`AppError`や`RAGScopeError`へ集約しない。UseCaseや内部処理は、その処理が結果を作れなかったときに、呼び出し側が必要な扱いを行えるように具体的な失敗型を返す。この設計では、UseCaseまたは内部処理がその処理の契約として具体的な失敗型の値で呼び出し元へ伝える失敗を[処理失敗](../RAGScope用語集.md#処理失敗)と呼ぶ。

失敗型は、原因をアプリケーション全体の共通分類へ当てはめるための型ではない。呼び出し側は、その処理の具体的な失敗からretry、fallback、終了、利用者への返却など、自身が担当する扱いを決める。

このため、`Input`、`Dependency`、`Timeout`のように異なる観点を1つの共通`ErrorCategory`へまとめない。たとえば外部サービスへのrequestがtimeoutした失敗は、「外部依存で発生した」という観点と「時間内に完了しなかった」という観点を同時に持ち得る。必要な扱いは、各処理の具体的な失敗から決める。

UseCaseの成功・失敗は[ユースケース設計](./ユースケース設計.md)に従う。内部処理で一度失敗しても、RAGScopeアプリケーションの実行制御によるretryやfallbackを経てUseCaseが定義した結果を最終的に作れた場合、そのUseCaseは成功である。

## 2. 処理ごとの失敗型

UseCaseや内部処理は、それぞれが呼び出し側へ返す必要がある[処理失敗](../RAGScope用語集.md#処理失敗)だけを具体的な失敗型として表す。

```text
内部処理の実行
├─ 成功値を返す
└─ 内部処理の失敗を返す

UseCaseの実行
├─ 定義した結果を返す、または必要な状態を作る
└─ 最終的に結果を作れない場合だけUseCaseの最終失敗を返す
```

UseCase専用の失敗型を必ず作るとはしない。[内部処理の失敗](../RAGScope用語集.md#内部処理の失敗)をUseCaseの[最終失敗](../RAGScope用語集.md#最終失敗)としてそのまま利用してよいのは、次をすべて満たす場合である。

- その失敗型自体が、UseCaseの呼び出し側へ公開する意味を持つ
- その失敗型を定義するmoduleまたはprivate libraryへの静的依存が、UseCaseの依存方向として妥当である
- HTTP client、DB driver、SDKなど、UseCaseの内部実装を変更しただけでUseCase契約まで変わるような実装詳細を漏らさない

これらを満たさない場合は、内部処理の失敗が1種類だけであっても、UseCaseの呼び出し側へ公開する失敗へ変換する。複数の内部処理の失敗を区別・統合する必要がある場合も、UseCase固有の失敗型を定義する理由になる。

retryやfallbackの途中で発生した内部処理の失敗を、機械的に呼び出し元の処理の失敗として残さない。呼び出し元の処理が回復した場合、その失敗は呼び出し元の処理の最終失敗ではない。

## 3. 外部依存とAdapter

HTTP client、DB driver、SDKなど外部library固有の例外やerror型を、必要性なくUseCaseや内部処理の境界から内側へ漏らさない。

外部依存へ接続するAdapterは、対象libraryの契約で想定されている既知のerror値や同期例外を、そのAdapterを利用する処理の具体的な処理失敗へ変換する。async exceptionや意図された中断・キャンセルは処理失敗へ変換せず、その実行制御の規則に従って呼び出し元へ伝播させる。想定外の同期例外も、既知の失敗constructorへ一律に押し込まない。

具体的にどのerror値や同期例外を処理失敗へ変換するかは、対象となる外部依存と機能の契約に応じて各Adapterの実装・テストで定める。

Boundaryをfeature library内に置くか、必要に応じてfeature固有または複数featureで共有する別private libraryへ分けるかは、実際に利用するmodule、型、関数/API、外部package依存とCabalの`build-depends`に応じて決める。同じpackage内にあることや将来利用する可能性だけを理由に依存を追加しない。

RAGScopeアプリケーションでは、[ADR-0008](<../adr/ADR-0008 RAGScopeアプリケーションの機能実装をprivate libraryへ分け、main libraryをFacadeとする.md>)に従い、分離したprivate library間の静的依存をCabalの`build-depends`で制約する。外部依存を隔離するAdapterを別private libraryへ分ける場合、feature libraryからAdapter libraryへ依存させず、Adapter libraryが利用境界と外部packageへ依存する方向にする。

依存注入の具体的なHaskell表現は、この設計では固定しない。現在はアプリケーション全体の失敗型へ共通して要求する多相操作がないため、失敗を統一する`AppError` type classは設けない。将来、複数の失敗型へ同じ操作を多相的に適用する必要が生じた場合は、その用途で必要な操作だけを表す契約を検討する。

## 4. UseCaseの最終失敗

retry、timeout、fallback、継続・終了という実行制御は、[システムアーキテクチャ](./システムアーキテクチャ.md)で定義するRAGScopeアプリケーションコンポーネントが所有する。RAGScopeアプリケーション内部のどのUseCase、module、処理がその判断と実行を担当するかは、対象機能の設計で定める。UseCaseの外側に共通の実行制御層を置くことは、この設計では要求しない。

UseCaseは、内部処理の失敗が発生した時点で直ちに最終失敗とはならない。そのUseCase実行に適用されるretry、timeout、fallback、継続・終了の制御を経ても[ユースケース設計](./ユースケース設計.md)で定義した結果を作れない場合に、そのUseCaseの最終失敗となる。

```text
内部処理の失敗
        ↓
対象機能で定めた実行制御
retry / timeout / fallback / 継続・終了
        ↓
    ┌───┴───┐
    │       │
  回復     回復不能
    │       │
UseCase成功  UseCaseの最終失敗
```

この区別により、1回のHTTP attemptがtimeoutしたがretryで成功した場合と、UseCaseが最終的に必要な結果を作れず最終失敗を返した場合を同じ失敗として扱わない。

`timeout`という名前だけで失敗の扱いを決めない。どの処理が時間内に完了しなかったか、その失敗が呼び出し元の処理の最終結果へどう影響したかを処理境界ごとに判断する。retry対象のattemptのtimeout、UseCaseの最終失敗として返すtimeout、実験基盤やTelemetryで発生したtimeoutは、同じ失敗として扱わない。実験・評価でどのtimeoutを保存・集計するかは5.2のとおり実験・評価側で具体化する。

## 5. 失敗を利用する境界

処理失敗を受け取る側は、それぞれ自身の責務に必要な情報だけを作る。CLI / API、実験・評価、Telemetryを、1つの共通error表現から派生する同種の「変換先」として扱わない。

### 5.1 CLI / API

CLIやAPIは、UseCase実行後に返された最終失敗を、利用者へ返す表現へ変換する。CLIのexit code、表示文、HTTP status、HTTP responseなどは利用インターフェース側で決め、UseCaseの失敗型へ持ち込まない。

変換のためだけに失敗を共通`AppError`へ正規化しない。利用インターフェースが具体的な失敗から必要な表現を直接作る。

### 5.2 実験・評価

実験結果は、任意の失敗をまとめて保存する場所ではない。[RAGScopeドメインモデル](./RAGScopeドメインモデル.md)で定義する実験・評価領域が、実験として実行した処理の結果を評価、保存、集計、比較するためのドメインデータである。

実験・評価の処理は、自身が呼び出した検索・回答生成などの最終結果を受け取り、評価データごとの実行結果として何を保存するかを実験・評価側の設計で決める。要求定義の`REQ-EXP-003`、`REQ-EXP-006`、`REQ-EVAL-007`にある状態、エラー、成功率、タイムアウト率についても、どの処理のどの最終失敗を対象にするかはこの設計では決めず、実験・評価側で具体化する。

次は、存在する失敗を理由に自動的に実験結果へ保存しない。

- retryやfallbackの途中だけで発生し、対象処理が最終的に成功した失敗
- 実験が呼び出していない事前準備や別UseCaseの失敗
- Telemetryの記録・送信に関する失敗

これにより、評価対象の検索・回答生成が完遂できなかった事実と、実験外の処理や観測基盤の障害を同じ「エラー」として集計しない。

### 5.3 Telemetry

Telemetryは失敗の意味や処理結果を決めない。処理自身の最終結果が失敗であり、観測に必要な場合に、その具体的な失敗からSpan Status、OpenTelemetryの`error.type`、必要な属性などのTelemetry表現を作る。

Telemetry用の`error.type`は観測用の表現であり、元の失敗を置き換えない。`error.type`へ変換した後も、UseCaseや内部処理は元の失敗値を保持する。

Telemetry表現への変換は、具体的な失敗型とTelemetry利用境界の両方を参照できる側に置く。失敗型を定義するmoduleへTelemetry都合の責務を持たせず、汎用のTelemetry boundaryやOpenTelemetry Adapterから個別のfeature private libraryで定義するUseCaseまたは内部処理の失敗型へ依存させない。正確な変換moduleやprivate libraryの配置は、実際のimportと`build-depends`を確認して各機能の実装時に決める。

Telemetryの記録やexportの失敗は、観測対象の処理またはUseCase実行の失敗とは別に扱う。Telemetryだけが失敗したことを理由に、成功していた観測対象の処理結果またはUseCase実行結果を失敗へ変更しない。詳細は[Observability設計](./observability/Observability設計.md)を正本とする。

## 6. 例外、中断、起動・終了時の失敗

外部依存の例外を処理失敗へ変換する条件は3章に従う。RAGScope内部の想定外例外も、既知の失敗constructorへ一律に変換しない。未処理例外として呼び出し元へ伝播する場合のTelemetry上の扱いは[実行追跡設計](./observability/実行追跡設計.md)に従う。

async exceptionや意図された中断・キャンセルは処理失敗と同一視しない。各runtimeでどの例外や機構を中断・キャンセルとして扱うかは、その処理を実装するコードとテストを正本とする。

起動時の初期化失敗や終了時のshutdown失敗は処理失敗に含めず、個別UseCaseの失敗へも含めない。起動・終了全体として成功・失敗をどう決め、processの終了状態へどう反映するかは現在の正本では決めておらず、ライフサイクルを具体化する設計で決める。正確なHaskellの型は、その実装時のコードとテストを正本とする。

## 7. 機械可読な正本

具体的なHaskellの失敗型、constructor、関数、module、private libraryの`build-depends`は、実装した時点のコード、`ragscope.cabal`、テストを正本とする。

この設計書は、具体的な処理失敗をどの処理が所有するか、外部依存をどこで処理失敗へ変換するか、呼び出し元の処理の最終失敗をどう決めるか、各利用先が何を担当するかを正本として扱う。

## 関連文書

- [RAGScope用語集](../RAGScope用語集.md)
- [RAGScope要求定義](../RAGScope要求定義.md)
- [RAGScopeドメインモデル](./RAGScopeドメインモデル.md)
- [ユースケース設計](./ユースケース設計.md)
- [システムアーキテクチャ](./システムアーキテクチャ.md)
- [Observability設計](./observability/Observability設計.md)
- [ADR-0008 — RAGScopeアプリケーションの機能実装をprivate libraryへ分け、main libraryをFacadeとする](<../adr/ADR-0008 RAGScopeアプリケーションの機能実装をprivate libraryへ分け、main libraryをFacadeとする.md>)
- [ADR-0010 — RAGScopeアプリケーションの失敗を処理単位の具体型で扱う](<../adr/ADR-0010 RAGScopeアプリケーションの失敗を処理単位の具体型で扱う.md>)