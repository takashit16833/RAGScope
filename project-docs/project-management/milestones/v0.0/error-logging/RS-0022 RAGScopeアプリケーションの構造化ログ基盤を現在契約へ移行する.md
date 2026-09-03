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

- `error_type`をHaskellで表す`ErrorType`と、失敗値だけから`ErrorType`へ変換する`ToErrorType`は、共通local package `ragscope-error`のpublic main libraryにある`RAGScope.ErrorType`で定義する。`ragscope-error`はLogging、Tracing、Observability、UseCase固有failureのいずれにも所有させない。
- 各UseCaseが`UseCaseFailure`となった具体的な理由は、そのUseCase固有のfailure型で表す。failure型はそのUseCaseを所有するFeatureの`RAGScope.<Feature>.Failure`で定義し、その型に対する`ToErrorType` instanceも同じmoduleに置く。Featureはfailure型の所有単位であり、`FeatureFailure`という共通の結果区分は導入しない。これにより`ToErrorType` instanceをorphanにせず、`ragscope-features`から`ragscope-error`への一方向依存とする。
- UseCase実行の結果は概念上`UseCaseResult = UseCaseSuccess | UseCaseFailure`として扱う。HaskellのUseCase境界では`Either failure result`を使い、`Right result`を`UseCaseSuccess`、`Left failure`を`UseCaseFailure`として表す。`UseCaseSuccess`・`UseCaseFailure`は結果区分であり、具体的なresult型・failure型の名称ではない。routing・command判定、入力変換・検証、ユースケース終了後の結果処理などの失敗をUseCase固有failureへ混在させない。
- 1回のトップレベルな利用者操作全体は、必要な場合だけ`UseCaseResult`を内包する外側の結果を持ち、概念上`OperationResult = OperationSuccess | OperationFailure`として扱う。Haskellの利用者操作境界では`Either OperationFailure result`を使い、`Right result`を`OperationSuccess`、`Left operationFailure`を`OperationFailure`として表す。結果区分を表すためだけの共通`OperationResult` ADTは導入しない。
- すべてのトップレベルな利用者操作は同じ`OperationFailure`型を使う。`OperationFailure`は、`ToErrorType` instanceを持つ具体的なfailure値を`OperationFailure failure`として1つ保持する。利用者操作ごとに`DenseSearchOperationFailure`などのfailure型を定義せず、`InputFailure`、`UseCaseFailure`、`OutputFailure`のような処理段階を表すconstructorも`OperationFailure`へ追加しない。
- UseCaseが`Left useCaseFailure`を返した場合、Applicationはその具体的な`useCaseFailure`値を受け取り、利用者操作も失敗として終了する場合に`Left (OperationFailure useCaseFailure)`を返す。入力変換・検証やUseCase後の結果処理で通常のtyped failureを受け取った場合も、利用者操作を失敗として終了する場合に`Left (OperationFailure failure)`として返す。UseCaseとOperationは自身の成功・失敗を結果として返すまでを責務とし、failureを観測用表現やログ表現へ変換することを必須責務にしない。具体failureを先に`ErrorType`へ変換してから`OperationFailure`へ保持しない。
- failure型の所有側は、具体的なfailureから`ErrorType`への変換規則を`ToErrorType` instanceとして提供する。eventの所有側は、eventから`LogSpec`への変換規則を型クラスinstanceではなく名前付き純粋関数として提供する。いずれも変換規則を提供することと、実行時に変換を適用することは別の責務とし、変換後の表現を必要とする処理またはcompositionが実際の変換を行う。
- `OperationFailure`は`ragscope` packageの`ragscope-application` libraryが所有する。Featureや`ragscope-error`には置かない。`OperationFailure`の定義は個別のUseCase固有failure型をimportせず、constructorの`ToErrorType failure`制約と`ToErrorType OperationFailure` instanceのために`RAGScope.ErrorType`をimportする。このため`ragscope-application`から`ragscope-error`への直接依存を持つ。正確なmodule名はApplication実装時にコードで確定する。
- `ToErrorType OperationFailure` instanceは、`OperationFailure failure`から中の`failure`値を取り出し、その値に`toErrorType`を適用して結果を返す。同じUseCase failureをUseCase実行`span`とroot `span`の両方で`error_type`として観測する場合、UseCase実行`span`で`ErrorType`を必要とする処理は`toErrorType useCaseFailure`を適用し、root `span`で`ErrorType`を必要とする処理は`toErrorType (OperationFailure useCaseFailure)`を適用する。後者も中の同じ`useCaseFailure`値に`toErrorType`を適用するため、両方で同じ`ErrorType`を得られる。
- `OperationFailure`を受け取るOperation境界の外側では、保持されたfailure値を`DenseSearchFailure`などの具体型へ戻して処理を分岐しない。具体failureの型に応じた処理は、そのfailure値を具体型のまま受け取れるOperation内の場所で行う。Operation境界の外側で`ErrorType`が必要な処理は`toErrorType operationFailure`によって取得する。
- `ErrorType`を必要とする公開境界が具体的なfailure値を受け取る場合、具体的なUseCase固有failure型へ固定せず、`ToErrorType failure => failure`を受け取って境界内で`toErrorType`を適用できる形とする。具体failure値を必要としない下位処理には変換後の`ErrorType`を渡す。どの処理または公開APIが`ErrorType`を必要とするかは、その責務と実行追跡境界に合わせてこのTicketで設計・実装する。
- 利用インターフェースが1回のトップレベルな操作について操作固有処理を開始する境界から、その操作の処理を完了または失敗として終了して外側へ制御を戻す境界までを1つの`trace`として扱える公開境界を設ける。routing・command判定、入力変換・検証、ユースケース呼び出し、ユースケース後の結果処理は、その操作に属する限り同じroot `span`の時間区間に含められるようにする。
- RAGScope Applicationがユースケースを呼び出した場合、その呼び出しからApplicationへ制御が戻るまでをroot `span`配下のユースケース実行`span`として追跡できるようにする。routingや入力検証で操作が終了してユースケースを呼び出さない場合は、ユースケース実行`span`を作らない。
- Observabilityの利用側では、新しいトップレベルな利用者操作の`trace`を開始するscopeと、開始済み`trace`内へ`span`を追加するscopeを分ける。前者を`withTrace`、後者を`withSpan`と呼ぶ。Operation境界が`withTrace`を使い、その内側のApplication / Featureは`withSpan`を使う。
- 利用側は`TraceId`や`SpanId`を受け取ったり`withSpan`へ渡したりしない。現在のtrace / span状態はTracingの具体実装側が管理し、`withSpan`で作るspanの親はそのcurrent spanから決定する。
- `RAGScope.Tracing`の公開Haskell APIは、`newtype SpanName = SpanName Text`と、`data Tracing m = Tracing { withTrace :: forall a. SpanName -> m a -> m a, withSpan :: forall a. SpanName -> m a -> m a, observeResult :: forall failure result. ToErrorType failure => Either failure result -> m (), currentTraceContext :: m (Maybe TraceContext) }`を基本形とする。`Tracing m`の同じ値から任意の処理・結果型を扱えるようfield側で型変数を量化する。`withTrace`へ渡す名称もroot `span`の名称なので、子`span`と共通の`SpanName`を使い、別の`TraceName`型は導入しない。
- current `trace`がない状態で`withSpan spanName action`が呼ばれた場合は、暗黙のroot `span`や子`span`を作らず、`action`だけを実行して結果をそのまま返す。Tracing側の失敗を返したり例外を発生させたりせず、観測処理の都合でApplication / Feature本来の結果型を変更しない。current `span`がない状態で`observeResult result`が呼ばれた場合も、Span Statusや`error_type`を反映する対象がないため何も行わず正常に終了する。
- `observeResult`は`ToErrorType failure => Either failure result -> m ()`を受け、`Left failure`ならcurrent `span`へ`Error`と`toErrorType failure`から得た`error_type`を反映し、`Right _`なら`Unset`を反映する。Observability Runtime自身は`Either`をpattern matchしてSpan Statusを決定しない。
- `currentTraceContext`は`m (Maybe TraceContext)`であり、current `span`がある場合はその`TraceId`・`SpanId`を返し、trace外では`Nothing`を返す。current Trace Contextは`AppEnv`の固定値として保持せず、Tracingの具体実装が`withTrace` / `withSpan`の実行scopeごとに管理する。複数のトップレベル操作が並行実行されても別操作のcurrent Trace Contextを混在させず、Application全体で1個の`IORef (Maybe TraceContext)`を共有して上書きする構造は採用しない。
- Application / Featureは`RAGScope.Tracing`を直接利用せず、処理追跡には`RAGScope.Observability`、event記録には`RAGScope.Logging`が公開する`Logger m event`を利用する。composition rootではOpenTelemetry Adapterから1つのTracing実装を組み立て、そのTracing実装をObservability Runtimeへ内部依存として渡し、Logging RuntimeにはTracing全体ではなく`currentTraceContext`取得能力だけを渡す。`Tracing`自体はApplication / Featureが利用する能力として`AppEnv`へ公開しない。
- `makeOpenTelemetryTracing`はTracing実装を初期化する処理であり、それ自体では利用者操作を表す`trace`を開始しない。実際の`trace`は各トップレベル操作の境界でObservabilityの`withTrace`を呼んだときに開始する。CLIでもAPIでもこの規則を共通とし、Application起動・Tracing初期化・終了処理を1つの利用者操作の`trace`へ含めない。
- `RAGScope.Observability`は`data Observability m = Observability { withTrace :: forall failure result. ToErrorType failure => SpanName -> m (Either failure result) -> m (Either failure result), withSpan :: forall failure result. ToErrorType failure => SpanName -> m (Either failure result) -> m (Either failure result) }`を公開する。`SpanName`はTracing所有の同じ型をObservabilityから再exportし、Application / Featureは`RAGScope.Observability`だけをimportして利用できる。
- Observability RuntimeはTracingの`withTrace` / `withSpan` scope内で`action`を実行し、得た`Either failure result`をscope終了前に`observeResult`へ渡してから同じ結果を返す。`observeResult`はObservabilityの独立した公開能力として再公開せず、Application / Featureによる呼び忘れやscope終了後の観測を型とAPI境界で避ける。成功しか返さない任意の`m a`用の追加Observability APIは現時点では導入せず、具体的な必要性が生じた時点で判断する。
- `ragscope-observability`は独立local packageとし、public main libraryの`RAGScope.Observability`と、package外のcomposition rootから利用できる`runtime` libraryの`RAGScope.Observability.Runtime`だけを持つ。現在のObservability責務では`internal` libraryや`RAGScope.Observability.Runner`を設けない。
- `RAGScope.Observability.Runtime`は`makeObservability :: Monad m => Tracing m -> Observability m`を公開する。`Monad m`制約はRuntimeが`action`実行、`observeResult`、結果返却を順序づけて合成するためにだけ必要とし、`Observability m`型そのものへは置かない。
- `ragscope-observability` main libraryは公開APIの`ToErrorType failure`とTracing所有`SpanName`のために`ragscope-error` mainと`ragscope-tracing` mainへ直接依存する。`runtime` libraryは`ragscope-observability` mainと`ragscope-tracing` mainへ直接依存し、現在は`ragscope-error`、`ragscope-tracing:core`、Logging、OpenTelemetryへ直接依存しない。
- Feature / UseCaseが実行時に必要とする能力は、Application全体の環境を直接受け取るのではなく、そのFeatureが所有する依存recordへ必要な能力だけをまとめて受け取る。Application composition rootはObservability、Feature別Logger、その他そのFeatureが必要とする能力を組み立ててこの依存recordを構築し、Featureへ渡す。FeatureはApplication全体の`AppEnv`のような型をimportせず、`ragscope-application`へ依存しない。この依存recordはFeature / UseCase実行の依存だけを表し、Operation全体の依存やApplication全体の長寿命環境を表すものではない。正確な型名・field・module名は実装コードで確定する。
- `ragscope-features`は`ragscope-observability` main、`ragscope-error`、`RAGScope.Logging`を公開するlogging library、`LogSpec`を公開するlogging coreへ依存する。Featureの記録箇所はFeature所有の依存recordから`Logger m <FeatureEvent>`を受け取って`record`を利用し、`RAGScope.<Feature>.Logging`はFeature eventから`LogSpec`への純粋変換を定義する。`ragscope-observability:runtime`、`ragscope-tracing`、Logging Runtime、Sink、JSON / SQLite実装、`ragscope-application`を`build-depends`へ追加しない。
- `ragscope-application`はcomposition rootでObservability、Feature別Logger、Feature所有の依存recordを組み立てるために、`ragscope-observability` main / `runtime`、`ragscope-tracing` main、`ragscope-error`、Loggingのmain / core / Runtime境界、`contravariant`へ直接依存する。OpenTelemetry具体実装を組み立てるApplication側のlibraryはprivate `ragscope-tracing-otel`も利用する。
- `RAGScope.Logging`は`newtype Logger m event = Logger { record :: event -> m () }`を公開し、`Logger m`へ`Contravariant` instanceを定義する。Logging Runtimeは`Logger m LogSpec`を組み立て、Applicationのcomposition rootはevent所有側が提供する`event -> LogSpec`の純粋関数を`contramap`で合成して`Logger m event`を作り、Featureが必要とする他の能力とともにFeature所有の依存recordへ格納する。利用側は`record logger event`だけを呼び、`LogSpec`、`LogRecord`、Runtime、Sinkを扱わない。
- `record`はLogging RuntimeやSinkで発生したlogging failureをtyped resultとしてOperation / Featureへ返さない。logging failureだけを理由に`OperationResult`を`OperationFailure`へ変更せず、利用者操作本体が失敗している場合も`OperationResult`には操作本体のfailureだけを保持する。logging failureはLogging側の独立したfailure境界で通知・保持し、その正確な内部境界はHaskell実装へ入る前にこのTicketで確定する。
- eventから`LogSpec`への変換には`ToLogSpec`型クラスを使用しない。Feature eventに対するorphan instance、`RAGScope.Application.LoggingInstances`、instanceを有効にする`import ... ()`、1つのLogging値で任意eventを受け取るための`RankNTypes`も導入しない。Feature固有変換は`RAGScope.<Feature>.Logging`の名前付き純粋関数として明示的にimportする。
- ユースケース失敗ログはFeature固有eventとして表す。検索機能であれば`SearchEvent`のユースケース失敗を表すconstructorを使い、他のFeature eventと同じ純粋関数で`LogSpec`へ変換できるようにする。composition rootが作る`Logger m SearchEvent`をFeature所有の依存recordを通して受け取り、ユースケース実行`span`へ関連付けて記録する。親やrootへ失敗が伝播したという理由だけで同じ失敗ログを重複して記録しない。具体的なconstructor名と保持する値は各Featureの設計・実装で確定する。
- 構造化ログの共通表現は、trace内ログとtrace外ログの両方を同じlogging基盤で扱えるようにする。特定の`span`へ属するログは`TraceId`・`SpanId`を組で持ち、特定の`span`へ属さないログは両方を持たない。片方だけを持つ状態は表現しない。
- `Port`はmodule名のsuffixではなく設計上の役割を表す語として使う。呼び出し側が必要とする抽象操作を定義し、具体実装を境界の向こう側で差し替える箇所をPortと呼ぶ。`RAGScope.Tracing`は`ragscope-tracing` packageのpublic main libraryに置き、Observability Runtimeが要求するspan操作を定義するTracing Portとする。`RAGScope.Tracing.Context`は同packageのpublic `core` libraryに置き、`TraceId`、`SpanId`、`TraceContext`を公開する。
- Tracing PortのOpenTelemetry具体実装は`ragscope-tracing` packageへ置かない。`ragscope` package内のprivate `ragscope-tracing-otel` libraryに`RAGScope.Application.Tracing.OpenTelemetry`を置き、`ragscope-tracing`のpublic main / `core` libraryとOpenTelemetry SDKへ依存して`RAGScope.Tracing`を実装する。OpenTelemetry SDKへ直接依存するのはこのprivate libraryだけとし、`ragscope-tracing` package自体はOpenTelemetry SDKへ依存しない。
- `ragscope-application`はprivate `ragscope-tracing-otel` libraryを利用して本番用の`RAGScope.Tracing`実装を組み立てる。Observability RuntimeとFeatureは`RAGScope.Application.Tracing.OpenTelemetry`もOpenTelemetry SDKもimportしない。`RAGScope.Observability`は利用インターフェース・Application・Featureから必要な実行追跡操作を利用するObservability Effect API、`RAGScope.Logging`は型付き`Logger`を提供するLogging Effect APIと呼び、単なる公開境界を一律にPortとは呼ばない。

## 完了条件

### 現在の論理契約への移行

- [ ] RAGScopeアプリケーションの構造化ログ1件を、発生時刻、発生元、イベント名、重要度、任意の`message`、任意の`attributes`、条件付きの`TraceId`・`SpanId`という現在契約の情報として扱える
- [ ] 特定の`span`中で起きた構造化ログは`TraceId`・`SpanId`を組で持ち、対応するOpenTelemetry `span`へ関連付けられる。特定の`span`へ属さない構造化ログは両方を持たず、片方だけを持つ状態を作らない
- [ ] 利用インターフェースが受け付けた1回のトップレベルな操作を1つの`trace`として追跡し、routing・command判定、入力変換・検証、ユースケース呼び出し、ユースケース後の結果処理をその操作に属する範囲でroot `span`に含められる
- [ ] ユースケースを呼び出した場合はその実行をroot `span`配下の子`span`として追跡し、ユースケースを呼び出さず操作が終了した場合はユースケース実行`span`を作らない
- [ ] UseCase実行を概念上`UseCaseResult = UseCaseSuccess | UseCaseFailure`として扱い、Haskellの`Either failure result`では`Right result`を`UseCaseSuccess`、`Left failure`を`UseCaseFailure`として表せる
- [ ] 1回の利用者操作全体を概念上`OperationResult = OperationSuccess | OperationFailure`として扱い、必要な場合だけ内側の`UseCaseResult`を含める。`UseCaseFailure`とUseCase前後の通常失敗を`OperationFailure`の原因として扱え、`UseCaseSuccess`だけを理由に`OperationSuccess`を確定しない
- [ ] Haskellの利用者操作境界を`Either OperationFailure result`で表し、`Right result`を`OperationSuccess`、`Left operationFailure`を`OperationFailure`として扱い、結果区分だけを表す共通`OperationResult` ADTを導入していない
- [ ] logging failureの成否と利用者操作本体の成否を分離し、利用者操作本体が成功していればlogging failureが発生しても`OperationSuccess`を維持し、利用者操作本体が失敗していればloggingの成否にかかわらず操作本体のfailureを保持した`OperationFailure`を返す
- [ ] 共通`OperationFailure`が`ToErrorType` instanceを持つ具体的なfailure値を`OperationFailure failure`として保持し、利用者操作ごとのfailure ADTやInput / UseCase / Outputなど処理段階ごとのconstructorを要求しない
- [ ] UseCaseの`Left failure`、UseCase前の通常failure、UseCase後の通常failureを、その具体型を必要とする処理が終わった後に`OperationFailure failure`として保持でき、先に`ErrorType`へ変換して具体failure値を失わない
- [ ] failure型の所有側が`ToErrorType` instanceを提供し、event所有側が`event -> LogSpec`の名前付き純粋関数を提供できる一方、UseCaseやOperation自身へ観測用表現・ログ表現への実変換を要求せず、その表現を必要とする処理またはcompositionが変換を適用できる
- [ ] `ToErrorType OperationFailure` instanceが`OperationFailure failure`から中のfailure値を取り出して`toErrorType failure`を実行し、同じUseCase failureをUseCase実行`span`とroot `span`で観測する場合に同じ`ErrorType`を得られる
- [ ] `OperationFailure`の定義が個別のUseCase固有failure型へ依存せず、`ragscope-application`が`RAGScope.ErrorType`をimportして`ragscope-error`へ直接依存する構造をCabalの`build-depends`で表現できる
- [ ] `OperationFailure`を受け取ったOperation境界の外側で具体failure型に応じた分岐を要求せず、必要な失敗理由を`toErrorType operationFailure`から取得できる
- [ ] `UseCaseFailure`という結果区分と、`DenseSearchFailure`などUseCase固有の具体的なfailure型を同一視せず、Featureは具体failure型の所有単位として扱う
- [ ] アプリケーションやプロセスの起動・終了など、利用者操作外のライフサイクル結果を`OperationResult`へ混在させない
- [ ] root `span`とユースケース実行`span`のSpan Status・`error_type`を、それぞれが表す処理自身の最終結果から独立して決められる
- [ ] コンポーネントの起動・終了など、特定の利用者操作へ属さないイベントを同じlogging基盤へtrace外ログとして渡せる
- [ ] イベント名と重要度を独立して扱え、`debug`、`info`、`warn`、`error`、`fatal`の5段階を表現できる
- [ ] `attributes`が現在の論理契約で定めるstring、number、boolean、array、objectを再帰的に扱え、論理上の`null`を導入しない
- [ ] 失敗をログで報告する場合、`error_type`を専用の共通エラーobjectではなく通常の属性として記録できる
- [ ] 同じ失敗を`span`と構造化ログの両方へ記録する境界で、同じ`error_type`を使用できる
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
- [ ] `RAGScope.Tracing`が`SpanName`と`Tracing m`を公開し、`Tracing m`のfieldとして`withTrace :: forall a. SpanName -> m a -> m a`、`withSpan :: forall a. SpanName -> m a -> m a`、`observeResult :: forall failure result. ToErrorType failure => Either failure result -> m ()`、`currentTraceContext :: m (Maybe TraceContext)`を提供する。trace外の`withSpan`はspanを作らず処理だけを実行し、trace外の`observeResult`は何も反映しない
- [ ] `RAGScope.Observability`が`Observability m`と`SpanName`を公開し、`withTrace :: forall failure result. ToErrorType failure => SpanName -> m (Either failure result) -> m (Either failure result)`と`withSpan :: forall failure result. ToErrorType failure => SpanName -> m (Either failure result) -> m (Either failure result)`の2能力を提供する。`SpanName`はTracing所有の型を再exportし、`observeResult`は利用側へ独立公開しない
- [ ] `ragscope-observability`がmainと`runtime`の2 libraryだけを持ち、mainは`RAGScope.Observability`、`runtime`は`RAGScope.Observability.Runtime`を公開する。`internal` libraryや`RAGScope.Observability.Runner`を導入していない
- [ ] `RAGScope.Observability.Runtime.makeObservability :: Monad m => Tracing m -> Observability m`がTracingのscope内で処理結果を`observeResult`へ渡してから同じ`Either`を返し、Application / FeatureにSpan Status更新順序を委ねていない
- [ ] `ragscope-observability` mainが`ragscope-error` mainと`ragscope-tracing` mainへ直接依存し、`runtime`がObservability mainと`ragscope-tracing` mainへ直接依存する。Feature側にはObservability mainだけを許可し、`runtime`と`ragscope-tracing`を直接依存させていない
- [ ] Application / FeatureはTracingを直接利用せずObservability / Loggingを通して必要な処理を行う。ただしcomposition rootを持つ`ragscope-application`はTracing実装をObservability Runtimeへ渡すため`ragscope-tracing`へ直接依存できる
- [ ] current Trace ContextをTracing実装が実行scopeごとに管理し、並行するトップレベル操作間でTrace Contextを混在させず、Logging Runtimeが注入された`currentTraceContext`取得能力からtrace内外を判定できる
- [ ] Application起動時のcompositionでOpenTelemetry AdapterからTracing実装を組み立て、その実装をObservability RuntimeとLogging Runtimeへ必要な能力だけ渡し、Tracing自体をApplication / Feature向け`AppEnv`へ公開していない
- [ ] `makeOpenTelemetryTracing`などTracing実装の初期化と、各トップレベル操作を開始する`withTrace`を分離し、Application / process全体を1つの利用者操作`trace`として扱っていない
- [ ] logging・tracing・observabilityなど独立した責務を別Cabal packageへ分ける場合、同一`cabal.project`内のlocal packageとして構成し、許可するpackage間依存を`build-depends`へ明示して循環や逆向き依存を作っていない
- [ ] `ragscope-tracing` packageが公開するのはTracing Portを持つpublic main libraryと`RAGScope.Tracing.Context`を持つpublic `core` libraryだけであり、OpenTelemetry具体実装とOpenTelemetry SDK依存を含んでいない。OpenTelemetry具体実装は`ragscope` package内のprivate `ragscope-tracing-otel` libraryに閉じ、`ragscope-application`以外のApplication / Feature / Observability実装から直接利用させていない
- [ ] 既存の`ragscope-logging`、`Observation`、`Result`、`AppError`の構造を維持すること自体を要件とせず、現在契約とRAGScopeアプリケーションの責務から必要性を判断している
- [ ] OpenTelemetryのAPIや内部表現の都合をRAGScope固有の論理契約や公開APIへ不要に持ち込まず、RAGScopeが採用した実行追跡を実現する境界として利用している
- [ ] `RAGScope.Logging`が`Logger m event`と`record :: Logger m event -> event -> m ()`を公開し、`Contravariant (Logger m)`によって`event -> LogSpec`と`Logger m LogSpec`から`Logger m event`を合成できる
- [ ] Feature / UseCaseがApplication全体の`AppEnv`を直接受けず、Feature所有の依存recordから自身に必要な能力だけを受け取る。Application composition rootがFeature別Loggerを含む依存recordを組み立て、`ragscope-features`から`ragscope-application`への逆向き依存を作っていない
- [ ] `record`がlogging failureをOperation / Featureへtyped resultとして返さず、logging failureを`OperationResult`から分離したまま、Runtime / Sinkのfailureを通知・保持するLogging内部境界を一意に追える設計になっている
- [ ] eventから`LogSpec`への変換を名前付き純粋関数として所有側が提供し、`ToLogSpec`型クラス、Feature eventのorphan instance、`RAGScope.Application.LoggingInstances`、instance読み込み専用importを導入していない
- [ ] 機能固有の閉じたイベント表現から共通logging表現へ変換でき、共通基盤が機能固有イベント名、属性、`error_type`を任意に決定しない
- [ ] Feature event、利用インターフェース固有event、アプリケーションライフサイクルeventなど、所有者の異なるeventごとに型付き`Logger m event`を組み立てて同じLogging Runtimeへ接続できる一方、共通logging基盤がそれらの具体的なevent名・属性・`error_type`を所有しない
- [ ] JSON / SQLite固有の型、依存package、field / table / column、serialization / persistence処理をそれぞれの外部表現moduleへ閉じ、共通logging層を特定の外部表現へ依存させていない
- [ ] loggingのRuntimeやSinkをテストから差し替えられ、実ログ出力を必要とせず共通logging境界を検証できる
- [ ] stderr、memoryなど既存の差し替え可能なSink構造は、現在契約と衝突しない範囲で維持または同等の境界へ置き換えられている
- [ ] ログ基盤自身の失敗を、失敗した同じログ経路へ再帰的に記録しない
- [ ] RAGScopeアプリケーション固有の実行追跡責務とevent→`LogSpec`変換責務は、それぞれ[RAGScopeアプリケーション実行追跡詳細設計](../../../../design/tracing/RAGScopeアプリケーション実行追跡詳細設計.md)と[RAGScopeアプリケーション構造化ログイベント変換詳細設計](../../../../design/logging/RAGScopeアプリケーション構造化ログイベント変換詳細設計.md)から追える。一方、正確な内部型、関数、module、Cabal依存、OpenTelemetry SDK利用方法、ログ受付・出力境界、設定、migration、具体的なテストケースはコード・設定・Schema・migration・テストを機械可読な正本とし、Markdownへ逐語的に複製していない
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

logging・tracing・observabilityなど独立した責務は、既存の1 package内private sublibraryへ閉じることを前提にせず、別Cabal packageとして分離することを第一候補とする。これらは別repositoryや外部公開を意味せず、`ragscope-app`配下の同一`cabal.project`から複数のlocal packageをまとめて扱う。package境界では`build-depends`によって大きな依存方向を機械的に制約し、各packageの内側では必要に応じてpublic / private libraryと`exposed-modules` / `other-modules`を使って公開範囲をさらに絞る。packageを分けること自体を目的にはせず、独立した責務・公開API・依存方向として分離する意味が薄い境界は設計の中で統合してよい。Observabilityについては`ragscope-observability`を独立local packageとし、mainと`runtime`の2 libraryだけを設けることを確定した。OpenTelemetry AdapterはTracing Portの契約ではなくRAGScopeアプリケーションの本番用具体実装なので、この原則の例外ではなく適用結果として`ragscope` package内のprivate `ragscope-tracing-otel` libraryへ置く。

機能固有の閉じたeventから共通loggingへは、所有側の`event -> LogSpec`純粋関数と`Contravariant`な`Logger m event`で接続する。Logging Runtimeは`Logger m LogSpec`を作り、Application composition rootが`contramap`で利用側ごとのLoggerを組み立てる。Feature / UseCaseへはApplication全体の`AppEnv`を渡さず、composition rootがFeature別Logger、Observability、その他そのFeatureに必要な能力だけをFeature所有の依存recordへまとめて渡す。Operation側の依存をどの型へまとめるか、Application全体の長寿命環境として`AppEnv`を導入するかは別の設計判断とし、このFeature依存recordの採用だけを理由には決めない。時刻やTrace Contextなど実行時情報を付加する境界、JSON serializationとSQLite投影を共通モデルから分離する境界、Sinkを差し替える構造は維持する。Trace Contextはすべてのログへ要求せず、特定の`span`へ属するログだけに`TraceId`・`SpanId`を組で付加する。JSONとSQLiteは同じ`LogRecord`から独立して投影し、片方の表現都合を共通モデルへ持ち込まなければもう片方を実装できない構造を避ける。