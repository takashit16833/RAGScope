---
note_type: design
---
# RAGScopeアプリケーション実行追跡詳細設計

> [!abstract] この文書の役割
> RAGScopeアプリケーションの実行追跡を実装・レビューする開発者向けの詳細設計である。現在のHaskell実装で、Application / UseCaseが利用するObservabilityとLoggingをTracing PortおよびOpenTelemetry Adapterへどう接続するかを定義する。Tracing Portの責務、Observability公開API、current Trace Contextの管理、Application起動時のcompositionを扱う。
>
> `trace`・`span`の論理的な意味、1回のトップレベルな利用者操作を1つの`trace`とする規則、Span Status、構造化ログとTrace Contextの関係、AI推論サービスを含むコンポーネント間のTrace Context引き継ぎは[実行追跡・構造化ログ契約設計](../実行追跡・構造化ログ契約設計.md)を正本とする。具体failureから`ErrorType`への分類規則は[ErrorType変換詳細設計](../ErrorType変換詳細設計.md)、RAGScopeアプリケーションでeventから`LogSpec`・`LogRecord`へ変換する境界は[RAGScopeアプリケーション構造化ログイベント変換詳細設計](../logging/RAGScopeアプリケーション構造化ログイベント変換詳細設計.md)を正本とする。

## 1. 全体構成

利用インターフェースのhandler / UseCaseは、処理を追跡するために`RAGScope.Observability`を利用し、eventを記録するために`RAGScope.Logging`が公開する`Logger m event`を利用する。handlerはApplication側の`withOperation`で利用者操作全体を囲み、UseCaseはObservabilityの`withSpan`で自身の実行を囲む。handler / UseCaseから`RAGScope.Tracing`やOpenTelemetry SDKを直接利用しない。

Application起動時のcompositionでは、OpenTelemetry Adapterから`RAGScope.Tracing`の具体実装を作り、その同じTracing実装を使ってfailure型ごとのObservabilityとLogging Runtimeを組み立てる。

```text
composition root

RAGScope.Application.Tracing.OpenTelemetry
        ↓ makeOpenTelemetryTracing
     Tracing m
      ├────────────→ Observability Runtime
      │                  + ErrorClassifier failure
      │                  ↓
      │           Observability m failure
      │
      └─ currentTraceContext ─→ Logging Runtime
                                  ↓
                          Logger m LogSpec
                                  ↓ contramap (event -> LogSpec)
                          Logger m UseCaseEvent
```

`Tracing`自体は利用インターフェースのhandler / UseCaseが利用する能力として公開しない。Applicationのcomposition rootだけが、Observability RuntimeとLogging Runtimeを組み立てるためにTracing実装を直接扱う。Observability RuntimeはTracing Portと`ErrorClassifier failure`から`Observability m failure`を作る。Logging RuntimeにはTracing全体ではなく、現在のTrace Contextを取得するために必要な能力だけを渡す。

利用側とcomposition rootから見た依存は次のとおりである。

```text
利用インターフェースのhandler / UseCase
  ├─ Observability m failure
  └─ Logger m event

Application composition root
  ├─ Observability Runtime
  ├─ ErrorClassifier failure
  ├─ Logging Runtime
  └─ Tracing

Observability Runtime
  ├─ ErrorClassifier failure
  └─ Tracing

Logging Runtime
  └─ current Trace Context取得能力

OpenTelemetry Adapter
  └─ Tracingを実装
```

この文書はRAGScopeアプリケーション内部の実現方法だけを扱う。AI推論サービスが同じ`trace`を継続する契約や、通信でTrace Contextを引き継ぐ共通規則は上位の[実行追跡・構造化ログ契約設計](../実行追跡・構造化ログ契約設計.md)が担当する。

## 2. Tracing Port

`RAGScope.Tracing`は、Observability RuntimeとLogging Runtimeが実行追跡のために必要とするPortである。TracingはApplicationの`Either`や具体failureを解釈せず、Observability Runtimeが決定した`SpanOutcome`だけを受け取る。

Spanの観測結果は次の形で表す。

```haskell
data SpanOutcome
  = SpanSucceeded
  | SpanFailed ErrorType
```

`SpanOutcome`は、current `span`へ反映する観測上の結果だけを表す。具体failure値、UseCase failure、`OperationFailure`、`Either`、`ErrorClassifier`は保持しない。

現在の最小能力は次の4つとする。

| 能力 | 契約 |
|---|---|
| `withTrace` | 1回のトップレベルな利用者操作について新しい`trace`とroot `span`を開始し、そのscopeが終了するとroot `span`を終了する |
| `withSpan` | 開始済み`trace`のcurrent `span`を親として子`span`を開始し、そのscopeが終了すると子`span`を終了する。current `trace`がない場合は子`span`も暗黙のroot `span`も作らず、渡された処理だけをそのまま実行する |
| `observeOutcome` | `SpanSucceeded`ならcurrent `span`を`Unset`、`SpanFailed errorType`なら`Error`と対応`error_type`としてTracingへ反映する。current `span`がない場合は何も反映しない |
| `currentTraceContext` | current `span`の`TraceId`と`SpanId`を`TraceContext`として取得する。特定の`span`に属していない場合は`Nothing`を返す |

公開するHaskell APIは次の形とする。

```haskell
{-# LANGUAGE RankNTypes #-}

module RAGScope.Tracing
  ( Tracing (..)
  , SpanName (..)
  , SpanOutcome (..)
  ) where

import Data.Text (Text)
import RAGScope.ErrorType (ErrorType)
import RAGScope.Tracing.Context (TraceContext)

newtype SpanName =
  SpanName Text
  deriving (Eq, Show)

data SpanOutcome
  = SpanSucceeded
  | SpanFailed ErrorType

data Tracing m = Tracing
  { withTrace
      :: forall a
       . SpanName
      -> m a
      -> m a
  , withSpan
      :: forall a
       . SpanName
      -> m a
      -> m a
  , observeOutcome
      :: SpanOutcome
      -> m ()
  , currentTraceContext
      :: m (Maybe TraceContext)
  }
```

`withTrace`と`withSpan`は、囲む処理の結果型へ制約を加えず、同じ`Tracing m`値から任意の`m a`を追跡できるようfield側で`a`を量化する。`observeOutcome`はApplication結果型へ依存しないため型変数を持たない。

`withTrace`へ渡す名称は新しい`trace`そのものの別名ではなく、その`trace`と同時に開始するroot `span`の名称である。root `span`と子`span`はいずれも`span`なので、名称型は共通の`SpanName`を使用し、別の`TraceName`型は導入しない。

`observeOutcome SpanSucceeded`はcurrent `span`のSpan Statusを`Unset`として扱う。`observeOutcome (SpanFailed errorType)`はSpan Statusを`Error`とし、同じ`ErrorType`を`error_type`へ反映する。OpenTelemetry AdapterはこのTracing Portの契約をOpenTelemetry SDKで実装する。

`currentTraceContext`は`m (Maybe TraceContext)`である。`TraceContext`は`RAGScope.Tracing.Context`が公開する`TraceId`と`SpanId`の組であり、Logging Runtimeはこの値を使ってtrace内ログへTrace Contextを付加する。

current `trace`がない状態で`withSpan spanName action`が呼ばれた場合、Tracingは新しい`trace`、root `span`、子`span`のいずれも作らず、`action`だけを実行してその結果をそのまま返す。Tracing側の失敗を返したり例外を発生させたりせず、観測処理の都合でApplication / UseCase本来の結果型を変更しない。current `span`がない状態で`observeOutcome outcome`が呼ばれた場合も、反映対象がないため何も行わず`m ()`として正常に終了する。

利用インターフェースのhandler / UseCaseへ`TraceId`や`SpanId`を渡すAPIにはしない。

## 3. Observability公開API

`RAGScope.Observability`は、利用インターフェース・Application・UseCaseが処理を実行追跡へ関連付けるための公開Effect APIである。利用インターフェースのhandler / UseCaseへTracing Portの低レベル操作や`ErrorClassifier`をそのまま公開せず、`span`のscopeと、そのscopeが表す`Either failure result`の最終結果観測を1つの操作として提供する。

公開するHaskell APIは次の形とする。

```haskell
{-# LANGUAGE RankNTypes #-}

module RAGScope.Observability
  ( Observability (..)
  , SpanName (..)
  ) where

import RAGScope.Tracing (SpanName (..))

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

`Observability m failure`は、特定のfailure型を返す処理を観測できる能力である。たとえば`Observability m DenseSearchFailure`は`Either DenseSearchFailure result`を返す処理を追跡する。利用側へ`ErrorClassifier DenseSearchFailure`を渡す必要はない。

Observabilityの公開能力は`withTrace`と`withSpan`の2つとする。Tracing Portの`observeOutcome`はObservabilityから独立した公開操作として再公開しない。`SpanOutcome`、`ErrorType`、`ErrorClassifier`、`TraceId`、`SpanId`、`TraceContext`、OpenTelemetry SDK型もObservabilityの利用側へ要求しない。

`SpanName`はTracingとObservabilityで別型を定義せず、`RAGScope.Tracing`が所有する同じ型を`RAGScope.Observability`から再exportする。Application側の`withOperation`とUseCaseは`RAGScope.Observability`だけをimportして`Observability`と`SpanName`を利用でき、`RAGScope.Tracing`を直接importしない。

`withTrace`はApplication側の`withOperation`がOperation境界の`m (Either OperationFailure result)`を囲むために利用する。利用インターフェースのhandlerは`withTrace`を直接Operationの意味として扱わず、`withOperation`へ`Observability m OperationFailure`、root `SpanName`、操作全体のactionを渡す。`withSpan`はUseCase境界の`m (Either useCaseFailure result)`などを囲むため、各UseCaseにはそのUseCase固有failure型へ特殊化したObservabilityを渡す。

## 4. Observability Runtime

`RAGScope.Observability.Runtime`は`Tracing m`と`ErrorClassifier failure`から`Observability m failure`を組み立てる。

```haskell
module RAGScope.Observability.Runtime
  ( makeObservability
  ) where

import RAGScope.ErrorType (ErrorClassifier)
import RAGScope.Observability (Observability)
import RAGScope.Tracing (Tracing)

makeObservability
  :: Monad m
  => Tracing m
  -> ErrorClassifier failure
  -> Observability m failure
```

`Monad m`制約は、`makeObservability`が`action`を実行し、その結果を観測してから同じ結果を返す順序を合成するために必要である。`Observability m failure`型そのものへ`Monad m`制約は置かない。

RuntimeはTracingのscopeを閉じる前に`Either`をpattern matchし、成功・失敗を`SpanOutcome`へ変換する。

```haskell
tracing.withSpan spanName $ do
  result <- action

  case result of
    Right _ ->
      tracing.observeOutcome SpanSucceeded

    Left failure ->
      tracing.observeOutcome
        (SpanFailed (classifyError classifier failure))

  pure result
```

`withTrace`も同じ順序で、Tracingの`withTrace` scope内で`action`を実行し、その結果を`SpanOutcome`へ変換してから同じ`Either`を返す。

ここで`Either`はApplication / UseCase境界の結果表現であるためObservability Runtimeが解釈する。Tracing Portへ`Either`や具体failureを渡さない。`ErrorClassifier`は`Left failure`から`ErrorType`を得るためだけに使い、failure値そのものを変更・置換しない。

Application composition rootは、たとえば次のようにfailure型ごとのObservabilityを組み立てる。

```haskell
searchObservability =
  makeObservability
    tracing
    denseSearchErrorClassifier

operationObservability =
  makeObservability
    tracing
    operationFailureErrorClassifier
```

このためUseCase / 利用インターフェースのhandlerはClassifierの適用や`observeOutcome`呼び出しを担当しない。

current `trace`がない状態でObservabilityの`withSpan`が呼ばれた場合も、Tracing Portの契約に従って新しい`span`は作られない。actionはそのまま実行され、`observeOutcome`もcurrent `span`がないため何も反映せず、Observabilityは元の結果をそのまま返す。

成功しか返さない任意の`m a`を追跡するための別APIは現時点では追加しない。現在必要なOperation・UseCase境界は`Either`結果を持つ`withOperation` / `withSpan`で表現し、`withOperation`の内部ではObservabilityの`withTrace`を利用する。別形の内部`span`が実際に必要になった場合は、その処理を定義する正本と実装上の要求を確認して追加要否を判断する。

## 5. current Trace Contextの管理

current `TraceContext`は`AppEnv`が直接保持せず、Tracingの具体実装が管理する。ここでいう管理対象はApplication全体で共有する1個の固定値ではなく、現在実行している`withTrace` / `withSpan`のscopeに対応する状態である。

```text
trace外
  current = Nothing

withTrace
  current = root span

  withSpan UseCase
    current = UseCase span

    withSpan Internal
      current = Internal span

    Internal終了
    current = UseCase span

  UseCase終了
  current = root span

trace終了
  current = Nothing
```

同じTracing実装を複数の利用者操作で共有しても、各操作のcurrent Trace Contextを混在させてはならない。APIなどで複数のトップレベル操作が並行実行される場合、それぞれの実行scopeで独立したcurrent Trace Contextを参照できる実装とする。Application全体で1個の`IORef (Maybe TraceContext)`のような値を共有し、別操作の`withTrace`によって上書きされる構造は採用しない。

`withSpan`で作る子`span`の親は、Tracing実装がその実行scopeのcurrent `span`から決定する。利用インターフェースのhandler / UseCaseは`TraceId`、`SpanId`、親`SpanId`を受け取ったり引き回したりしない。

## 6. Application起動と`withOperation`の境界

`makeOpenTelemetryTracing`はOpenTelemetry SDKを使うTracing実装を初期化する処理であり、それ自体ではRAGScopeの利用者操作を表す`trace`を開始しない。

```haskell
tracing <- makeOpenTelemetryTracing ...

let searchObservability =
      makeObservability tracing denseSearchErrorClassifier

let operationObservability =
      makeObservability tracing operationFailureErrorClassifier

let logSpecLogger =
      makeLogSpecLogger (currentTraceContext tracing) logSink

let searchLogger =
      contramap searchEventToLogSpec logSpecLogger
```

`makeLogSpecLogger`は責務と値の流れを示す概念名であり、正確な関数名はLogging実装コードを機械可読な正本とする。UseCase別ObservabilityとLoggerはUseCase所有の依存recordへまとめ、Application全体の`AppEnv`をUseCaseへ渡さない。依存能力の受け渡しは[ユースケース詳細設計](../ユースケース詳細設計.md)を正本とする。

実際の`trace`は、利用インターフェースのhandlerが1回のトップレベルな操作について操作固有処理を開始する境界でApplication側の`withOperation`を呼び、その内部からObservabilityの`withTrace`へ処理を委譲したときに開始する。CLIのプロセス起動時にTracing実装を初期化しても、設定読み込みやTracing初期化など、トップレベル操作より前の処理はその操作の`trace`へ含めない。APIでは1つのプロセスが複数のトップレベル操作を受け付けても、各操作がそれぞれ別の`withOperation` scopeを持つ。

```text
Application process
  ├─ Tracing / Loggingなどを初期化
  ├─ Operation A → withOperation → withTrace → Trace T1
  ├─ Operation B → withOperation → withTrace → Trace T2
  ├─ Operation C → withOperation → withTrace → Trace T3
  └─ 終了処理
```

## 7. ObservabilityとLoggingからの利用

Observability RuntimeはTracing Portの`withTrace`、`withSpan`、`observeOutcome`を利用する。Application側の`withOperation`とUseCaseへ公開するObservability APIは、Tracingの具体実装値、`SpanOutcome`、`ErrorClassifier`、`TraceId`、`SpanId`、OpenTelemetry SDK型を要求しない。

Logging Runtimeは`Logger m LogSpec`を組み立てる。その`record`が`LogSpec`へ実行時情報を付加して`LogRecord`を作るときに、注入された`currentTraceContext`を呼び出す。`Just traceContext`なら`TraceId`・`SpanId`を組で付加し、`Nothing`ならtrace外ログとして両方を付加しない。Logging RuntimeはTracingのspan開始・終了、Span Status更新を担当しない。

これにより、ObservabilityとLoggingは同じTracing実装が管理するcurrent Trace Contextを利用しながら、利用インターフェースのhandler / UseCaseから見た公開責務は分離したまま維持する。

## 8. package・library・moduleの依存

`ragscope-observability`は、`ragscope-app`配下でほかのRAGScopeアプリケーション用packageと同じ`cabal.project`から扱う独立local packageとする。Observabilityの利用APIと組み立てAPIをCabal library境界で分けるため、main libraryと`runtime` libraryの2つだけを持つ。現在のObservability責務では、別の`internal` libraryや`Runner` moduleは設けない。

| package / library | 公開module | 直接必要な依存 | 責務 |
|---|---|---|---|
| `ragscope-observability` main library | `RAGScope.Observability` | `ragscope-tracing` main | Application側の`withOperation` / UseCaseが利用する`Observability m failure`と、Tracing所有の`SpanName`の再export |
| `ragscope-observability:runtime` | `RAGScope.Observability.Runtime` | `ragscope-observability` main、`ragscope-tracing` main、`ragscope-error` main | `Tracing m`と`ErrorClassifier failure`から`makeObservability`で`Observability m failure`を組み立てる |

main libraryは公開APIに`ErrorType`や`ErrorClassifier`を出さないため`ragscope-error`へ直接依存しない。`ragscope-tracing` mainへ依存するのは、Tracing所有の`SpanName`を再exportするためである。

`runtime` libraryは`RAGScope.Observability`、`RAGScope.Tracing`、`RAGScope.ErrorType`をimportして`makeObservability`を実装する。`RAGScope.Tracing.Context`、Logging、OpenTelemetry Adapter、OpenTelemetry SDKを直接importしない。

`RAGScope.Observability.Runtime`は`ragscope` packageのcomposition rootから利用するため、package外から参照できるlibraryとする。一方、UseCase側のlibraryには`ragscope-observability:runtime`を`build-depends`へ追加しない。これによりUseCaseはObservabilityを利用できるが、Observability Runtimeを組み立てる責務を持たない。

利用側の直接依存は次のとおりとする。

```text
ragscope-use-cases
  ├─→ ragscope-observability main
  ├─→ ragscope-error main
  ├─→ ragscope-logging main
  └─→ ragscope-logging core

ragscope-application
  ├─→ ragscope-observability main
  ├─→ ragscope-observability:runtime
  ├─→ ragscope-tracing main
  ├─→ ragscope-error main
  ├─→ ragscope-logging main / core / Runtime境界
  └─→ contravariant
```

`ragscope-use-cases`は`RAGScope.Observability`をimportして`withSpan`を利用し、`RAGScope.Logging`から`Logger`と`record`を利用する。`RAGScope.<UseCase>.ErrorClassification`は`RAGScope.<UseCase>.Failure`と`RAGScope.ErrorType`をimportして名前付きClassifierを定義する。`RAGScope.<UseCase>.Logging`はUseCase event、UseCaseのClassifier、Logging coreの`LogSpec`をimportして純粋変換を定義する。一方、`RAGScope.Observability.Runtime`、`RAGScope.Tracing`、`RAGScope.Tracing.Context`、Logging Runtime、Sink、JSON / SQLite実装は直接importしない。

`ragscope-application`はcomposition rootで`RAGScope.Tracing`値と名前付きClassifierを`RAGScope.Observability.Runtime.makeObservability`へ渡して本番用Observabilityを組み立てるため、Observabilityのmain / `runtime` library、`ragscope-tracing` main、`ragscope-error` mainへ直接依存する。Application側の`withOperation`はObservability mainの`withTrace`へ委譲し、`OperationFailure`と`operationFailureErrorClassifier`は`ragscope-error`の`ErrorClassifier`を利用する。Logging Runtimeから得た`Logger m LogSpec`とUseCase固有の純粋変換を`contramap`で合成するため、Loggingのmain / core / Runtime境界と`contravariant`へ直接依存する。OpenTelemetry具体実装を組み立てるApplication側のlibraryは、別途private `ragscope-tracing-otel` libraryを利用する。

Tracing側は次の責務を維持する。

- `RAGScope.Tracing`は`ragscope-tracing` packageのpublic main libraryに置き、`SpanName`、`SpanOutcome`、Tracing Portを公開する。
- `RAGScope.Tracing.Context`は同packageのpublic `core` libraryに置き、`TraceId`、`SpanId`、`TraceContext`を公開する。
- `SpanOutcome`の`SpanFailed`が`ErrorType`を保持するため、Tracing Portを持つmain libraryは`ragscope-error`の`RAGScope.ErrorType`へ依存する。具体failure、`ErrorClassifier`、`Either`は扱わない。
- `RAGScope.Application.Tracing.OpenTelemetry`は`ragscope` package内のprivate `ragscope-tracing-otel` libraryに置き、`ragscope-tracing`のpublic main / `core` libraryとOpenTelemetry SDKへ依存してTracing Portを実装する。
- Observability RuntimeはOpenTelemetry AdapterやOpenTelemetry SDKを直接importしない。

Logging RuntimeはTrace Contextを扱うために必要な公開型と、composition時に注入されるcurrent Trace Context取得能力だけを利用し、Tracingのspan操作やOpenTelemetry Adapterへ依存しない。

正確なCabal stanza、`visibility`、`build-depends`の記法、`hs-source-dirs`、実装ファイルの配置は、実装時にCabal設定とコードを機械可読な正本として確定する。この設計で固定するのは、package / library / moduleの責務と、許可する直接依存の方向である。

## 関連文書

- [実行追跡・構造化ログ契約設計](../実行追跡・構造化ログ契約設計.md)
- [RAGScopeアプリケーション構造化ログイベント変換詳細設計](../logging/RAGScopeアプリケーション構造化ログイベント変換詳細設計.md)
- [ErrorType変換詳細設計](../ErrorType変換詳細設計.md)
- [利用者操作詳細設計](../利用者操作詳細設計.md)
- [ユースケース詳細設計](../ユースケース詳細設計.md)
