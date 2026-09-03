---
note_type: ticket
status: in_progress
milestone: "[[v0.0]]"
epic: "[[v0.0 共通エラーと構造化ログによる実行追跡]]"
---
# RS-0022 RAGScopeアプリケーションの構造化ログ基盤を現在契約へ移行する

## 目的

RS-0015で実装したRAGScopeアプリケーションの`ragscope-logging`は、`ExecutionId`、`EventId`、`EventContext`、`OperationName`、通常イベントと失敗イベントの直和、`LogErrorCategory`、`ErrorCode`、`SafeMessage`など、現在の実行追跡・構造化ログ契約で置き換えられた旧論理モデルを表現している。JSON backendも同じ旧構造を既存JSON Schemaへ投影している。

[RS-0020 共通エラー・構造化ログの論理契約を再設計する](<./RS-0020 共通エラー・構造化ログの論理契約を再設計する.md>)で、OpenTelemetryの`trace`・`span`による実行追跡、`TraceId`・`SpanId`による構造化ログと`span`の関連付け、`error_type`による失敗理由の識別という基本契約を確定した。RS-0022の設計検討では、その契約を利用インターフェースからユースケース前後まで適用できるように見直し、現在は**利用インターフェースが受け付けた1回のトップレベルな操作を1つの`trace`として追跡し、ユースケース実行はroot `span`配下の子`span`として追跡する**。また、構造化ログは`trace`より広い概念とし、特定の`span`へ属するログだけが`TraceId`・`SpanId`を組で持ち、アプリケーションの起動・終了など`trace`外のイベントは両方を持たずに記録できる。失敗理由は`error_type`で識別し、ログでは他の属性と同じ属性として記録する。イベント名、重要度、任意の`message`、`attributes`は互いに独立した論理情報として扱う。

この実行追跡・構造化ログ契約はRAGScopeアプリケーションだけの契約ではなく、AI推論サービスを含むRAGScope全体の共通契約である。コンポーネント間ではTrace Contextを引き継いで同じ`trace`を継続する。RS-0022はその共通契約を変更してRAGScopeアプリケーション専用へ閉じるTicketではなく、共通契約をRAGScopeアプリケーションのHaskell実装で成立させるための詳細設計と実装を担当する。

このTicketでは、既存のHaskell logging基盤を現在の実行追跡・構造化ログ契約へ追随させ、同じ共通モデルからJSONとSQLiteの双方へ投影できる状態にする。JSONとSQLiteを同時に実装することで、JSON固有の型、項目、serializationの都合が共通logging契約や`LogRecord`へ漏れ込んでいないことを実装とテストで検証する。既存module構成や公開APIを前提として局所修正せず、RAGScopeアプリケーションから見た責務、利用インターフェースとの実行追跡境界、Cabal package・library・module間の依存とデータの流れを先に設計し、その全体像を基準に実装を置き換える。loggingの境界を自然にするために必要であれば、`Observation`、`Result`、`AppError`など既存の周辺moduleも変更または削除の対象に含める。

OpenTelemetryはRAGScopeの要求や論理契約を決める正本ではない。RAGScopeが必要とする実行追跡を実現するために、OpenTelemetryの`trace`・`span`などの設計と実装を利用する。OpenTelemetry側の都合だけを理由にRAGScope固有の契約、責務、公開APIを追加または変更しない。

## 前提

- [RS-0020 共通エラー・構造化ログの論理契約を再設計する](<./RS-0020 共通エラー・構造化ログの論理契約を再設計する.md>)が完了し、OpenTelemetryの`trace`・`span`による実行追跡と構造化ログの基本契約が導入されている
- [RS-0021 構造化ログJSON Schemaとfixtureを現在契約へ更新する](<./RS-0021 構造化ログJSON Schemaとfixtureを現在契約へ更新する.md>)が完了している。RS-0022で論理契約を追加修正した場合は、同じ作業branchで共有JSON Contractも現在契約へ追随させる

## 現在確定した実装境界

### failureと`ErrorType`

- `error_type`をHaskellで表す`ErrorType`と、具体的なfailureから`ErrorType`へ分類する能力を表す`ErrorClassifier failure`は、共通local package `ragscope-error`のpublic main libraryにある`RAGScope.ErrorType`で定義する。
- `ErrorClassifier failure`は概念上`failure -> ErrorType`を保持する名前付きの値とし、型クラスinstanceにはしない。分類規則を利用するmoduleまたはcompositionがClassifier値を明示的にimport・受け渡しする。
- `classifyError classifier failure`を適用しても、元のfailure値を`ErrorType`へ置き換えない。failureがconstructor引数として数値・文字列などの詳細値を保持する場合も、failure値自体を保持している限りその詳細値を失わない。
- 各UseCaseが`UseCaseFailure`となった具体的な理由は、そのUseCase固有のfailure型で表す。failure型は`RAGScope.<UseCase>.Failure`が所有し、このmoduleは`RAGScope.ErrorType`へ依存しない。
- UseCase固有failureに対応する名前付きClassifierは`RAGScope.<UseCase>.ErrorClassification`が所有し、`RAGScope.<UseCase>.Failure`と`RAGScope.ErrorType`をimportして`ErrorClassifier <UseCase>Failure`を定義する。
- 同じfailure型についてTracing用とLogging用に別のClassifierを定義しない。同じ失敗を`span`と構造化ログへ記録する場合は、所有側の同じ名前付きClassifierを使用して同じ`ErrorType`を得る。
- `ErrorClassifier`は構造上`Contravariant` instanceを定義できるが、現在のcompositionでその操作を必要としていないためinstanceを追加しない。実際の合成要求が生じた場合だけ再検討する。

### UseCaseとOperationのfailure

- UseCase実行の結果は概念上`UseCaseResult = UseCaseSuccess | UseCaseFailure`として扱う。HaskellのUseCase境界では`Either failure result`を使い、`Right result`を`UseCaseSuccess`、`Left failure`を`UseCaseFailure`として表す。routing・command判定、入力変換・検証、ユースケース終了後の結果処理などの失敗をUseCase固有failureへ混在させない。
- 1回のトップレベルな利用者操作全体は、必要な場合だけ`UseCaseResult`を内包する外側の結果を持ち、概念上`OperationResult = OperationSuccess | OperationFailure`として扱う。Haskellの利用者操作境界では`Either OperationFailure result`を使う。
- すべてのトップレベルな利用者操作は同じ`OperationFailure`型を使う。`OperationFailure`は、具体的なfailure値と、そのfailure型に対応する`ErrorClassifier failure`を1組保持する。

```haskell
data OperationFailure where
  OperationFailure
    :: failure
    -> ErrorClassifier failure
    -> OperationFailure
```

- UseCaseが`Left useCaseFailure`を返した場合、Applicationはその具体的な`useCaseFailure`値を受け取り、利用者操作も失敗として終了する場合に対応Classifierとともに`OperationFailure`へ保持する。入力変換・検証やUseCase後の結果処理のfailureも同じ規則で扱う。
- 具体failureを先に`ErrorType`へ分類してから`OperationFailure`へ保持しない。failureが保持する詳細値をログ属性などへ利用する処理は、そのfailureを具体型として扱える場所で行える。
- `OperationFailure`へ`InputFailure`、`UseCaseFailure`、`OutputFailure`など処理段階を表すconstructorを追加せず、利用者操作ごとの`DenseSearchOperationFailure`なども定義しない。
- `OperationFailure`は`ragscope` packageの`ragscope-application` libraryが所有し、個別UseCase failure型を参照しない。`ErrorClassifier`を保持するため`ragscope-error`へ直接依存する。
- root `span`などで`OperationFailure`から`ErrorType`を得るため、Application側は`operationFailureErrorClassifier :: ErrorClassifier OperationFailure`を提供する。このClassifierは`OperationFailure`に保存された具体failure値と対応Classifierを取り出し、同じfailure値へそのClassifierを適用する。
- `OperationFailure`を受け取るOperation境界の外側では、保持されたfailure値を`DenseSearchFailure`などの具体型へ戻して分岐しない。必要な`ErrorType`は`operationFailureErrorClassifier`によって得る。

### TracingとObservability

- 利用インターフェースが1回のトップレベルな操作について操作固有処理を開始する境界から、その操作の処理を完了または失敗として終了して外側へ制御を戻す境界までを1つの`trace`として扱う。Operation境界がObservabilityの`withTrace`を使う。
- RAGScope ApplicationがUseCaseを呼び出した場合、その呼び出しからApplicationへ制御が戻るまでをroot `span`配下のUseCase実行`span`として追跡する。UseCaseはObservabilityの`withSpan`を使う。
- 利用側は`TraceId`や`SpanId`を受け取ったり`withSpan`へ渡したりしない。current trace / span状態はTracingの具体実装側が管理する。
- Tracingが観測する処理結果は`SpanOutcome = SpanSucceeded | SpanFailed ErrorType`で表す。Tracingは`Either`、具体failure、`OperationFailure`、`ErrorClassifier`を扱わない。
- `RAGScope.Tracing`の公開APIは、`SpanName`、`SpanOutcome`、`Tracing m`を公開し、`withTrace :: forall a. SpanName -> m a -> m a`、`withSpan :: forall a. SpanName -> m a -> m a`、`observeOutcome :: SpanOutcome -> m ()`、`currentTraceContext :: m (Maybe TraceContext)`を提供する。
- `observeOutcome SpanSucceeded`はcurrent `span`を`Unset`として扱い、`observeOutcome (SpanFailed errorType)`は`Error`と同じ`error_type`を反映する。current `span`がない場合は何も反映しない。
- `RAGScope.Observability`はfailure型へ特殊化した`Observability m failure`を公開する。

```haskell
data Observability m failure = Observability
  { withTrace
      :: forall result
       . SpanName
      -> m (Either failure result)
      -> m (Either failure result)
  , withSpan
      :: forall result
       . SpanName
      -> m (Either failure result)
      -> m (Either failure result)
  }
```

- `RAGScope.Observability.Runtime.makeObservability`は`Tracing m`と`ErrorClassifier failure`を受けて`Observability m failure`を組み立てる。

```haskell
makeObservability
  :: Monad m
  => Tracing m
  -> ErrorClassifier failure
  -> Observability m failure
```

- Observability Runtimeが`Either failure result`をpattern matchし、`Right _`を`SpanSucceeded`、`Left failure`を`SpanFailed (classifyError classifier failure)`へ変換してTracingへ渡す。`Either`はApplication / UseCaseの結果表現であり、Tracingへ解釈を委譲しない。
- Application composition rootはUseCase固有ClassifierとTracingからUseCase向け`Observability m <UseCase>Failure`を組み立て、`operationFailureErrorClassifier`とTracingからOperation向け`Observability m OperationFailure`を組み立てる。
- UseCaseへはClassifier、`ErrorType`、`SpanOutcome`、Tracingを渡さず、UseCase所有の依存recordを通して`Observability m <UseCase>Failure`を渡す。
- current `TraceContext`は`AppEnv`の固定値として保持せず、Tracingの具体実装が`withTrace` / `withSpan`の実行scopeごとに管理する。並行するトップレベル操作間でTrace Contextを混在させない。
- `makeOpenTelemetryTracing`はTracing実装の初期化であり、それ自体では利用者操作の`trace`を開始しない。Application / process全体を1つの利用者操作`trace`として扱わない。

### package・libraryの依存

- `ragscope-observability`は独立local packageとし、public main libraryの`RAGScope.Observability`と、composition rootが利用する`runtime` libraryの`RAGScope.Observability.Runtime`だけを持つ。`internal` libraryや`RAGScope.Observability.Runner`は設けない。
- `ragscope-observability` mainは公開APIに`ErrorClassifier`を出さないため`ragscope-error`へ直接依存せず、`SpanName`を再exportするため`ragscope-tracing` mainへ依存する。
- `ragscope-observability:runtime`はObservability main、`ragscope-tracing` main、`ragscope-error` mainへ直接依存する。UseCase側はObservability mainだけを利用し、`runtime`へ依存しない。
- `ragscope-tracing` mainは`SpanOutcome`が`ErrorType`を保持するため`ragscope-error` mainへ依存するが、具体failureやClassifierを扱わない。
- `ragscope-use-cases`はObservability main、`ragscope-error` main、Logging main / coreへ依存する。`RAGScope.<UseCase>.ErrorClassification`がClassifierを定義し、`RAGScope.<UseCase>.Logging`が必要に応じて同Classifierを利用する。
- `ragscope-application`はcomposition rootでObservability、UseCase別Logger、UseCase所有の依存recordを組み立てるため、Observability main / runtime、Tracing main、`ragscope-error`、Logging main / core / Runtime境界、`contravariant`へ直接依存する。
- Tracing PortのOpenTelemetry具体実装は`ragscope-tracing` packageへ置かず、`ragscope` package内のprivate `ragscope-tracing-otel` libraryに`RAGScope.Application.Tracing.OpenTelemetry`を置く。OpenTelemetry SDKへ直接依存するのはこのprivate libraryだけとする。

### Logging

- `RAGScope.Logging`は`newtype Logger m event = Logger { record :: event -> m () }`を公開し、`Logger m`へ`Contravariant` instanceを定義する。
- Logging Runtimeは`Logger m LogSpec`を組み立て、Application composition rootはevent所有側が提供する名前付き`event -> LogSpec`純粋関数を`contramap`で合成して`Logger m event`を作る。
- eventから`LogSpec`への変換に`ToLogSpec`型クラスを使用しない。UseCase eventに対するorphan instance、`RAGScope.Application.LoggingInstances`、instance読み込み専用importも導入しない。
- UseCase失敗eventで`error_type`が必要な場合、`RAGScope.<UseCase>.Logging`は`RAGScope.<UseCase>.ErrorClassification`の名前付きClassifierを利用する。failureのconstructor引数などの詳細値を他のattributesへ記録する処理は、同じfailureまたはeventから独立して行う。
- `record`はLogging RuntimeやSinkで発生したlogging failureをtyped resultとしてOperation / UseCaseへ返さない。logging failureだけを理由に`OperationResult`を`OperationFailure`へ変更しない。
- 構造化ログの共通表現はtrace内ログとtrace外ログを同じ基盤で扱い、特定の`span`へ属するログだけが`TraceId`・`SpanId`を組で持つ。

## 完了条件

### 現在の論理契約への移行

- [ ] RAGScopeアプリケーションの構造化ログ1件を、発生時刻、発生元、イベント名、重要度、任意の`message`、任意の`attributes`、条件付きの`TraceId`・`SpanId`という現在契約の情報として扱える
- [ ] 特定の`span`中で起きた構造化ログは`TraceId`・`SpanId`を組で持ち、対応するOpenTelemetry `span`へ関連付けられる。特定の`span`へ属さない構造化ログは両方を持たず、片方だけを持つ状態を作らない
- [ ] 利用インターフェースが受け付けた1回のトップレベルな操作を1つの`trace`として追跡し、routing・command判定、入力変換・検証、ユースケース呼び出し、ユースケース後の結果処理をその操作に属する範囲でroot `span`に含められる
- [ ] ユースケースを呼び出した場合はその実行をroot `span`配下の子`span`として追跡し、ユースケースを呼び出さず操作が終了した場合はユースケース実行`span`を作らない
- [ ] UseCase実行を`Either failure result`、利用者操作全体を`Either OperationFailure result`で表し、結果区分だけを表す共通ADTを追加していない
- [ ] logging failureの成否と利用者操作本体の成否を分離し、logging failureだけを理由に`OperationResult`を変更しない
- [ ] `ErrorType`と`ErrorClassifier failure`を`ragscope-error`の共通契約として定義し、failure所有側の名前付きClassifierで具体failureから`ErrorType`を得られる
- [ ] UseCase固有failure型とその`ErrorClassifier`を別moduleへ分離し、failure型自身が`ErrorType`へ依存していない
- [ ] 共通`OperationFailure`が具体的なfailure値と対応`ErrorClassifier failure`を保持し、failureのconstructor引数を含む詳細値を先に`ErrorType`へ変換して失っていない
- [ ] `OperationFailure`が個別UseCase failure型やInput / UseCase / Outputなど処理段階ごとのconstructorを要求しない
- [ ] `operationFailureErrorClassifier`が`OperationFailure`に保存されたClassifierを同じ具体failure値へ適用し、同じUseCase failureをUseCase実行`span`とroot `span`で観測するとき同じ`ErrorType`を得られる
- [ ] 同じfailure型に対するTracing用とLogging用の分類規則を分離せず、同じ名前付きClassifierを共有できる
- [ ] failureの詳細値を`error_type`以外の構造化ログ属性へ反映する必要がある場合、Classifierとは別に具体failureまたはeventからその値を利用できる
- [ ] `ErrorClassifier`へ実際に不要な`Contravariant` instanceを追加していない
- [ ] Application / UseCaseはTracingを直接利用せず、failure型へ特殊化したObservabilityと型付きLoggerを利用する
- [ ] Tracingが`Either`、具体failure、`OperationFailure`、`ErrorClassifier`を扱わず、`SpanOutcome`だけからSpan Statusと`error_type`を反映できる
- [ ] Observability Runtimeが`Either failure result`を解釈し、`ErrorClassifier failure`で`SpanOutcome`へ変換してTracingへ渡せる
- [ ] root `span`とユースケース実行`span`のSpan Status・`error_type`を、それぞれが表す処理自身の最終結果から独立して決められる
- [ ] コンポーネントの起動・終了など、特定の利用者操作へ属さないイベントを同じlogging基盤へtrace外ログとして渡せる
- [ ] イベント名と重要度を独立して扱え、`debug`、`info`、`warn`、`error`、`fatal`の5段階を表現できる
- [ ] `attributes`が現在の論理契約で定めるstring、number、boolean、array、objectを再帰的に扱え、論理上の`null`を導入しない
- [ ] 失敗をログで報告する場合、`error_type`を専用の共通エラーobjectではなく通常の属性として記録できる
- [ ] 子`span`の失敗が親やrootへ伝播しただけでは同じ失敗ログを階層ごとに重複記録せず、その失敗を意味として所有する処理または境界で1件記録できる
- [ ] `ExecutionId`、`EventId`、`EventContext`、`OperationName`、通常イベントと失敗イベントの直和、固定`failed`イベント、重要度と失敗の結合など、現在契約が採用しない旧論理モデルを共通logging基盤の前提として残していない
- [ ] 既存の`AppError`などlogging以外の失敗表現は、`UseCaseResult`と`OperationResult`の包含関係を区別したうえで必要性を再評価し、旧共通エラー契約を維持するためだけの構造を残していない

### JSON・SQLite外部表現と共有Contract

- [ ] 同じ`LogRecord`をJSONとSQLiteの双方へ投影でき、JSONのobject構造やSQLiteのtable・column・local keyなど、外部表現固有の都合を共通logging契約や`LogRecord`の前提にしていない
- [ ] HaskellのJSON serializationが現在の[構造化ログJSON表現設計](../../../../design/logging/構造化ログJSON表現設計.md)へ投影する実装になっている
- [ ] JSON出力が現在の共有JSON Schemaへ適合することを自動テストで確認できる
- [ ] `ragscope-app/test/RAGScope/Logging/SchemaSpec.hs`を現在のfixture名と契約へ追随させ、trace内ログ、trace外ログ、`trace_id`・`span_id`片方だけの不正表現を含む共有fixtureのSchema適合・不適合検証を成功させる
- [ ] `message`と`attributes`の省略、空文字列・空array・空objectの保持、属性値の再帰構造など、現在のJSON表現に必要な主要境界をテストで確認できる
- [ ] 構造化ログをstderrへ出力する場合、1ログ1JSON objectを1物理行へUTF-8で出力し、JSON以外の接頭辞や説明文を付加しない
- [ ] HaskellのSQLite投影が現在の[構造化ログSQLite表現設計](../../../../design/logging/構造化ログSQLite表現設計.md)に従い、`log_record`と属性・再帰値を対応するtableへ保存できる
- [ ] SQLite表現を実装するmigrationで、table、column、foreign key、`STRICT`、`CHECK`など実装に必要な正確な制約を機械可読に定義する
- [ ] SQLiteへの1 `LogRecord`の書き込みを1 transactionとして扱い、途中で失敗した場合にそのログ1件の変更をcommitしない
- [ ] SQLiteへ投影した構造化ログを論理情報へ復元し、`message`の不存在と空文字列、属性の不存在、空array・空object、再帰的なarray / object、数値、boolean、Trace Contextの存在・不存在を失わず往復できることを自動テストで確認できる
- [ ] SQLite固有の`record_id` / `value_id`、table・column名、SQLite接続型やSQL実装詳細を`ragscope-logging-core`へ持ち込んでいない

### 実装境界と検証

- [ ] Haskell実装へ着手する前に、loggingの利用側から見た公開API、Cabal package・library・moduleごとの責務と依存方向、利用インターフェースからroot `span`を開始・終了する境界、ユースケース実行`span`との関係、ログ生成からSinkまでのデータの流れ、logging自身の失敗処理を一つの全体像として設計し、その設計を基準に実装している
- [ ] `RAGScope.Tracing`が`SpanName`、`SpanOutcome`、`Tracing m`を公開し、`withTrace`、`withSpan`、`observeOutcome`、`currentTraceContext`を提供する。trace外の`withSpan`はspanを作らず処理だけを実行し、trace外の`observeOutcome`は何も反映しない
- [ ] `RAGScope.Observability`が`Observability m failure`と`SpanName`を公開し、failure型へ特殊化した`withTrace` / `withSpan`の2能力を提供する。`SpanOutcome`とClassifierを利用側へ公開しない
- [ ] `ragscope-observability`がmainと`runtime`の2 libraryだけを持ち、mainは`RAGScope.Observability`、`runtime`は`RAGScope.Observability.Runtime`を公開する。`internal` libraryや`RAGScope.Observability.Runner`を導入していない
- [ ] `RAGScope.Observability.Runtime.makeObservability :: Monad m => Tracing m -> ErrorClassifier failure -> Observability m failure`がTracingのscope内で`Either`を`SpanOutcome`へ変換してから同じ結果を返し、Application / UseCaseにSpan Status更新順序を委ねていない
- [ ] `ragscope-observability` mainが`ragscope-tracing` mainへ直接依存し、`runtime`がObservability main、`ragscope-tracing` main、`ragscope-error` mainへ直接依存する。UseCase側にはObservability mainだけを許可し、`runtime`と`ragscope-tracing`を直接依存させていない
- [ ] current Trace ContextをTracing実装が実行scopeごとに管理し、並行するトップレベル操作間でTrace Contextを混在させず、Logging Runtimeが注入された`currentTraceContext`取得能力からtrace内外を判定できる
- [ ] Application起動時のcompositionでOpenTelemetry AdapterからTracing実装を組み立て、その実装とfailure型ごとのClassifierからObservabilityを組み立て、Logging RuntimeにはTracing全体ではなく必要なTrace Context取得能力だけを渡す
- [ ] logging・tracing・observabilityなど独立した責務を別Cabal packageへ分ける場合、同一`cabal.project`内のlocal packageとして構成し、許可するpackage間依存を`build-depends`へ明示して循環や逆向き依存を作っていない
- [ ] `ragscope-tracing` packageが公開するのはTracing Portを持つpublic main libraryと`RAGScope.Tracing.Context`を持つpublic `core` libraryであり、OpenTelemetry具体実装とOpenTelemetry SDK依存を含んでいない
- [ ] `RAGScope.Logging`が`Logger m event`と`record :: Logger m event -> event -> m ()`を公開し、`Contravariant (Logger m)`によって`event -> LogSpec`と`Logger m LogSpec`から`Logger m event`を合成できる
- [ ] UseCaseがApplication全体の`AppEnv`を直接受けず、UseCase所有の依存recordから`Observability m <UseCase>Failure`、`Logger m <UseCaseEvent>`など自身に必要な能力だけを受け取る
- [ ] `record`がlogging failureをOperation / UseCaseへtyped resultとして返さず、logging failureを`OperationResult`から分離したまま、Runtime / Sinkのfailureを通知・保持するLogging内部境界を一意に追える設計になっている
- [ ] eventから`LogSpec`への変換を名前付き純粋関数として所有側が提供し、`ToLogSpec`型クラス、UseCase eventのorphan instance、`RAGScope.Application.LoggingInstances`、instance読み込み専用importを導入していない
- [ ] UseCase failureのClassifier、失敗event、event→`LogSpec`変換を所有側のmoduleから追え、共通基盤が機能固有イベント名・詳細属性・`error_type`を任意に決定しない
- [ ] JSON / SQLite固有の型、依存package、field / table / column、serialization / persistence処理をそれぞれの外部表現moduleへ閉じ、共通logging層を特定の外部表現へ依存させていない
- [ ] loggingのRuntimeやSinkをテストから差し替えられ、実ログ出力を必要とせず共通logging境界を検証できる
- [ ] ログ基盤自身の失敗を、失敗した同じログ経路へ再帰的に記録しない
- [ ] RAGScopeアプリケーション固有の実行追跡責務とevent→`LogSpec`変換責務を各詳細設計から追え、正確な実装定義はコード・Cabal・Schema・migration・テストを機械可読な正本とする
- [ ] 関係するHaskellテスト、JSON Schema適合テスト、SQLite投影・復元テスト、プロジェクトの品質検査を実行し、追加・更新したテストを含めて成功する
- [ ] Haskell実装、共有JSON Contract、SQLite表現、現在の実行追跡・構造化ログ設計の間に未解消な差異がない

## 対象外

- 機能固有の子`span`、ログイベント、属性、`error_type`をこのTicketで先行して決定すること
- 文書処理など各機能へ具体的なログイベントや`error_type`を適用すること
- RAGScope API / RAGScope CLI固有の具体的なログイベント、属性、利用者向けエラー表現をこのTicketで先行して決定すること
- RAGScopeアプリケーションやAI推論サービスの具体的なライフサイクルイベント名・属性を、実際の起動・終了処理から独立して先行決定すること
- AI推論サービスのPython logging基盤を実装すること
- OpenTelemetry Collector、CloudWatchなどの運用基盤を構築すること
- SQLiteを本番Sinkとして採用するためのdatabase file配置、rotation、保持期間、同時書き込み、query用index、bufferingなどの運用設計

## 関連文書

- [RS-0015 RAGScopeアプリケーションの共通エラー・構造化ログ基盤を実装する](<./RS-0015 RAGScopeアプリケーションの共通エラー・構造化ログ基盤を実装する.md>)
- [RS-0020 共通エラー・構造化ログの論理契約を再設計する](<./RS-0020 共通エラー・構造化ログの論理契約を再設計する.md>)
- [RS-0021 構造化ログJSON Schemaとfixtureを現在契約へ更新する](<./RS-0021 構造化ログJSON Schemaとfixtureを現在契約へ更新する.md>)
- [システムアーキテクチャ](../../../../design/システムアーキテクチャ.md)
- [ユースケース基本設計](../../../../design/ユースケース基本設計.md)
- [ユースケース詳細設計](../../../../design/ユースケース詳細設計.md)
- [利用者操作基本設計](../../../../design/利用者操作基本設計.md)
- [利用者操作詳細設計](../../../../design/利用者操作詳細設計.md)
- [ErrorType変換詳細設計](../../../../design/ErrorType変換詳細設計.md)
- [実行追跡・構造化ログ契約設計](../../../../design/実行追跡・構造化ログ契約設計.md)
- [実行追跡設計](../../../../design/tracing/README.md)
- [RAGScopeアプリケーション実行追跡詳細設計](../../../../design/tracing/RAGScopeアプリケーション実行追跡詳細設計.md)
- [構造化ログ設計](../../../../design/logging/README.md)
- [RAGScopeアプリケーション構造化ログイベント変換詳細設計](../../../../design/logging/RAGScopeアプリケーション構造化ログイベント変換詳細設計.md)
- [構造化ログ外部表現共通設計](../../../../design/logging/構造化ログ外部表現共通設計.md)
- [構造化ログJSON表現設計](../../../../design/logging/構造化ログJSON表現設計.md)
- [構造化ログSQLite表現設計](../../../../design/logging/構造化ログSQLite表現設計.md)
- [ADR-0005 — 実行追跡をOpenTelemetryのtrace・spanで表現し、イベントを構造化ログとして記録する](<../../../../adr/ADR-0005 実行追跡をOpenTelemetryのtrace・spanで表現し、イベントを構造化ログとして記録する.md>)

## 実装メモ

最初に、利用側から見たloggingの公開API、Cabal package・library・moduleごとの責務と依存方向、中心となる型、利用者操作root `span`・ユースケース実行`span`・内部`span`の関係、trace内ログとtrace外ログ、Runtime・Sink・JSON / SQLite外部表現・テスト境界、logging自身の失敗とアプリケーション実行の関係を一つの全体像として設計する。実装はその全体像を基準に進め、既存moduleへ変更を積み重ねながら後から構造を決める進め方はしない。

UseCase固有failureは`RAGScope.<UseCase>.Failure`、その`ErrorType`分類は`RAGScope.<UseCase>.ErrorClassification`の名前付き`ErrorClassifier`、失敗eventから`LogSpec`への変換は`RAGScope.<UseCase>.Logging`が担当する。Application composition rootは同じClassifierをObservability Runtimeへ渡して`Observability m <UseCase>Failure`を組み立てる。Logging変換も同じClassifierを`error_type`の生成に使用し、failureが保持する詳細値は必要な他のattributesへ独立して反映する。

UseCase固有の閉じたeventから共通loggingへは、所有側の`event -> LogSpec`純粋関数と`Contravariant`な`Logger m event`で接続する。Logging Runtimeは`Logger m LogSpec`を作り、Application composition rootが`contramap`で利用側ごとのLoggerを組み立てる。UseCaseへはApplication全体の`AppEnv`を渡さず、composition rootがUseCase別Logger、UseCase向けObservability、その他そのUseCaseに必要な能力だけをUseCase所有の依存recordへまとめて渡す。

Operation側の依存をどの型へまとめるか、Application全体の長寿命環境として`AppEnv`を導入するかは別の設計判断とし、このUseCase依存recordやClassifierの採用だけを理由には決めない。時刻やTrace Contextなど実行時情報を付加する境界、JSON serializationとSQLite投影を共通モデルから分離する境界、Sinkを差し替える構造は維持する。
