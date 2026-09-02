---
note_type: design
---
# RAGScopeアプリケーション実行追跡詳細設計

> [!abstract] この文書の役割
> RAGScopeアプリケーションの実行追跡を実装・レビューする開発者向けの詳細設計である。現在のHaskell実装で、Application / Featureが利用するObservabilityとLoggingをTracing PortおよびOpenTelemetry Adapterへどう接続するかを定義する。Tracing Portの責務、Observability公開API、current Trace Contextの管理、Application起動時のcompositionを扱う。
>
> `trace`・`span`の論理的な意味、1回のトップレベルな利用者操作を1つの`trace`とする規則、Span Status、構造化ログとTrace Contextの関係、AI推論サービスを含むコンポーネント間のTrace Context引き継ぎは[実行追跡・構造化ログ契約設計](../実行追跡・構造化ログ契約設計.md)を正本とする。RAGScopeアプリケーションでeventから`LogSpec`・`LogRecord`へ変換する境界は[RAGScopeアプリケーション構造化ログイベント変換詳細設計](../logging/RAGScopeアプリケーション構造化ログイベント変換詳細設計.md)を正本とする。

## 1. 全体構成

Application / Featureは、処理を追跡するために`RAGScope.Observability`を利用し、eventを記録するために`RAGScope.Logging`を利用する。Application / Featureから`RAGScope.Tracing`やOpenTelemetry SDKを直接利用しない。

Application起動時のcompositionでは、OpenTelemetry Adapterから`RAGScope.Tracing`の具体実装を作り、その同じTracing実装を使ってObservability RuntimeとLogging Runtimeを組み立てる。

```text
composition root

RAGScope.Application.Tracing.OpenTelemetry
        ↓ makeOpenTelemetryTracing
     Tracing m
      ├────────────→ Observability Runtime
      │                  ↓
      │              Observability
      │
      └─ currentTraceContext ─→ Logging Runtime
                                  ↓
                                Logging

AppEnv
  ├─ Observability
  ├─ Logging
  └─ その他のApplicationが利用する能力
```

`Tracing`自体はApplication / Featureが利用する能力として`AppEnv`へ公開しない。Observability RuntimeはTracing Portを内部依存として保持し、Logging RuntimeにはTracing全体ではなく、現在のTrace Contextを取得するために必要な能力だけを渡す。

Application / Featureから見た依存は次のとおりである。

```text
Application / Feature
  ├─ Observability
  └─ Logging

Observability Runtime
  └─ Tracing

Logging Runtime
  └─ current Trace Context取得能力

OpenTelemetry Adapter
  └─ Tracingを実装
```

この文書はRAGScopeアプリケーション内部の実現方法だけを扱う。AI推論サービスが同じ`trace`を継続する契約や、通信でTrace Contextを引き継ぐ共通規則は上位の[実行追跡・構造化ログ契約設計](../実行追跡・構造化ログ契約設計.md)が担当する。

## 2. Tracing Port

`RAGScope.Tracing`は、Observability RuntimeとLogging Runtimeが実行追跡のために必要とするPortである。現在の最小能力は次の4つとする。

| 能力 | 契約 |
|---|---|
| `withTrace` | 1回のトップレベルな利用者操作について新しい`trace`とroot `span`を開始し、そのscopeが終了するとroot `span`を終了する |
| `withSpan` | 開始済み`trace`のcurrent `span`を親として子`span`を開始し、そのscopeが終了すると子`span`を終了する。current `trace`がない場合は子`span`も暗黙のroot `span`も作らず、渡された処理だけをそのまま実行する |
| `observeResult` | current `span`が表す処理の`Either failure result`を観測し、`Left failure`なら`Error`と`error_type`、`Right _`なら`Unset`としてTracingへ反映する。current `span`がない場合は何も反映しない |
| `currentTraceContext` | current `span`の`TraceId`と`SpanId`を`TraceContext`として取得する。特定の`span`に属していない場合は`Nothing`を返す |

公開するHaskell APIは次の形とする。

```haskell
{-# LANGUAGE RankNTypes #-}

module RAGScope.Tracing
  ( Tracing (..)
  , SpanName (..)
  ) where

import Data.Text (Text)
import RAGScope.ErrorType (ToErrorType)
import RAGScope.Tracing.Context (TraceContext)

newtype SpanName =
  SpanName Text
  deriving (Eq, Show)

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
  , observeResult
      :: forall failure result
       . ToErrorType failure
      => Either failure result
      -> m ()
  , currentTraceContext
      :: m (Maybe TraceContext)
  }
```

`withTrace`と`withSpan`は、囲む処理の結果型へ制約を加えず、同じ`Tracing m`値から任意の`m a`を追跡できるようfield側で`a`を量化する。`observeResult`も同じ`Tracing m`値から任意の`ToErrorType failure => Either failure result`を観測できるよう、`failure`と`result`をfield側で量化する。

`withTrace`へ渡す名称は新しい`trace`そのものの別名ではなく、その`trace`と同時に開始するroot `span`の名称である。root `span`と子`span`はいずれも`span`なので、名称型は共通の`SpanName`を使用し、別の`TraceName`型は導入しない。

`observeResult`は、具体的なfailure型に固定せず、`ToErrorType failure => Either failure result -> m ()`として扱う。`Left failure`の場合に使用する`error_type`は`toErrorType failure`から得る。`Left` / `Right`をSpan Statusへどう対応付けるかという契約は`RAGScope.Tracing`側が定義し、OpenTelemetry Adapterはその契約をOpenTelemetry SDKで実装する。Observability Runtime自身は`Either`をpattern matchしてSpan Statusを決定しない。

`currentTraceContext`は`m (Maybe TraceContext)`である。`TraceContext`は`RAGScope.Tracing.Context`が公開する`TraceId`と`SpanId`の組であり、Logging Runtimeはこの値を使ってtrace内ログへTrace Contextを付加する。

current `trace`がない状態で`withSpan spanName action`が呼ばれた場合、Tracingは新しい`trace`、root `span`、子`span`のいずれも作らず、`action`だけを実行してその結果をそのまま返す。Tracing側の失敗を返したり例外を発生させたりせず、観測処理の都合でApplication / Feature本来の結果型を変更しない。current `span`がない状態で`observeResult result`が呼ばれた場合も、Span Statusや`error_type`を反映する対象がないため何も行わず`m ()`として正常に終了する。

Application / Featureへ`TraceId`や`SpanId`を渡すAPIにはしない。

## 3. Observability公開API

`RAGScope.Observability`は、利用インターフェース・Application・Featureが処理を実行追跡へ関連付けるための公開Effect APIである。Application / FeatureへTracing Portの低レベル操作をそのまま公開せず、`span`のscopeと、そのscopeが表す処理の最終結果の観測を1つの操作として提供する。

公開するHaskell APIは次の形とする。

```haskell
{-# LANGUAGE RankNTypes #-}

module RAGScope.Observability
  ( Observability (..)
  , SpanName (..)
  ) where

import RAGScope.ErrorType (ToErrorType)
import RAGScope.Tracing (SpanName (..))

data Observability m = Observability
  { withTrace
      :: forall failure result
       . ToErrorType failure
      => SpanName
      -> m (Either failure result)
      -> m (Either failure result)
  , withSpan
      :: forall failure result
       . ToErrorType failure
      => SpanName
      -> m (Either failure result)
      -> m (Either failure result)
  }
```

Observabilityの公開能力は`withTrace`と`withSpan`の2つとする。Tracing Portの`observeResult`はObservabilityから独立した公開操作として再公開しない。`TraceId`、`SpanId`、`TraceContext`、OpenTelemetry SDK型もObservabilityの利用側へ要求しない。

`SpanName`はTracingとObservabilityで別型を定義せず、`RAGScope.Tracing`が所有する同じ型を`RAGScope.Observability`から再exportする。Application / Featureは`RAGScope.Observability`だけをimportして`Observability`と`SpanName`を利用でき、`RAGScope.Tracing`を直接importしない。

`withTrace`はOperation境界の`m (Either OperationFailure result)`を囲む。`withSpan`はUseCase境界の`m (Either useCaseFailure result)`など、開始済み`trace`内で独立して結果を観測する処理を囲む。どの機能内部処理を追加の子`span`として追跡するかは各機能設計が決め、この共通詳細設計では具体的な内部`span`を先行決定しない。

Observability Runtimeは、Tracing Portのscopeを閉じる前に処理結果を`observeResult`へ渡す。概念上の処理順は次のとおりである。

```haskell
tracing.withSpan spanName $ do
  result <- action
  tracing.observeResult result
  pure result
```

`withTrace`も同じ順序で、Tracingの`withTrace` scope内で`action`を実行し、その結果を`observeResult`へ渡してから結果をそのまま返す。このため、Application / Feature自身が`observeResult`の呼び忘れや、scope終了後の観測を起こさない。

Observability Runtime自身は`Either`をpattern matchして`Left` / `Right`からSpan Statusを決めない。結果の解釈はTracing Portの`observeResult`へ委譲する。Observabilityは`action`が返した`Either failure result`を別の結果型へ変換せず、そのまま利用側へ返す。

current `trace`がない状態でObservabilityの`withSpan`が呼ばれた場合も、Tracing Portの契約に従って新しい`span`は作られない。`action`の結果に対する`observeResult`もcurrent `span`がないため何も反映せず、Observabilityは元の結果をそのまま返す。

成功しか返さない任意の`m a`を追跡するための別APIや、`observeResult`を利用側へ独立公開するAPIは現時点では追加しない。現在必要なOperation・UseCase境界は`Either`結果を持つ`withTrace` / `withSpan`で表現し、別形の内部`span`が実際に必要になった場合は、その処理を定義する正本と実装上の要求を確認して追加要否を判断する。

## 4. current Trace Contextの管理

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

`withSpan`で作る子`span`の親は、Tracing実装がその実行scopeのcurrent `span`から決定する。Application / Featureは`TraceId`、`SpanId`、親`SpanId`を受け取ったり引き回したりしない。

## 5. Application起動と`withTrace`の境界

`makeOpenTelemetryTracing`はOpenTelemetry SDKを使うTracing実装を初期化する処理であり、それ自体ではRAGScopeの利用者操作を表す`trace`を開始しない。

```haskell
tracing <- makeOpenTelemetryTracing ...

let observability = makeObservability tracing
let logging = makeLogging (currentTraceContext tracing) logSink

let env =
      AppEnv
        { observability = observability
        , logging = logging
        , ...
        }
```

このコードはcompositionの概念例であり、`AppEnv`、`makeObservability`、`makeLogging`、`makeOpenTelemetryTracing`の正確な型・関数名は実装コードを正本とする。

実際の`trace`は、利用インターフェースが1回のトップレベルな操作について操作固有処理を開始する境界でObservabilityの`withTrace`を呼んだときに開始する。CLIのプロセス起動時にTracing実装を初期化しても、設定読み込みやTracing初期化など、トップレベル操作より前の処理はその操作の`trace`へ含めない。APIでは1つのプロセスが複数のトップレベル操作を受け付けても、各操作がそれぞれ別の`withTrace` scopeを持つ。

```text
Application process
  ├─ Tracing / Loggingなどを初期化
  ├─ Operation A → withTrace → Trace T1
  ├─ Operation B → withTrace → Trace T2
  ├─ Operation C → withTrace → Trace T3
  └─ 終了処理
```

## 6. ObservabilityとLoggingからの利用

Observability RuntimeはTracing Portの`withTrace`、`withSpan`、`observeResult`を利用する。Application / Featureへ公開するObservability APIは、Tracingの具体実装値、`TraceId`、`SpanId`、OpenTelemetry SDK型を要求しない。

Logging Runtimeは、`LogSpec`へ実行時情報を付加して`LogRecord`を作るときに、注入された`currentTraceContext`を呼び出す。`Just traceContext`なら`TraceId`・`SpanId`を組で付加し、`Nothing`ならtrace外ログとして両方を付加しない。Logging RuntimeはTracingのspan開始・終了、Span Status更新を担当しない。

これにより、ObservabilityとLoggingは同じTracing実装が管理するcurrent Trace Contextを利用しながら、Application / Featureから見た公開責務は分離したまま維持する。

## 7. package・moduleの依存

- `RAGScope.Tracing`は`ragscope-tracing` packageのpublic main libraryに置き、上記Tracing Portを公開する。
- `RAGScope.Tracing.Context`は同packageのpublic `core` libraryに置き、`TraceId`、`SpanId`、`TraceContext`を公開する。
- `observeResult`が`ToErrorType`を利用するため、Tracing Portを持つlibraryは`ragscope-error`の`RAGScope.ErrorType`へ依存する。`ErrorType` / `ToErrorType`の所有はTracingへ移さない。
- `RAGScope.Observability`は`Observability m`とTracing所有の`SpanName`を公開し、Observability RuntimeはTracing Portへ依存する。Application / FeatureはObservabilityを通して実行追跡を利用し、Tracingを直接importしない。
- `RAGScope.Application.Tracing.OpenTelemetry`は`ragscope` package内のprivate `ragscope-tracing-otel` libraryに置き、`ragscope-tracing`のpublic main / `core` libraryとOpenTelemetry SDKへ依存してTracing Portを実装する。
- Observability RuntimeはOpenTelemetry AdapterやOpenTelemetry SDKを直接importしない。
- Logging RuntimeはTrace Contextを扱うために必要な公開型と、composition時に注入されるcurrent Trace Context取得能力だけを利用し、Tracingのspan操作やOpenTelemetry Adapterへ依存しない。
- `ragscope-application`はcomposition rootでOpenTelemetry AdapterからTracing実装を作り、Observability RuntimeとLogging Runtimeを組み立てる。

正確なCabal package・library名、`build-depends`、moduleのexpose範囲、Observability Runtimeの組み立て関数名、実装コード上の定義は、実装時にCabal設定とコードを機械可読な正本として確定する。

## 関連文書

- [実行追跡・構造化ログ契約設計](../実行追跡・構造化ログ契約設計.md)
- [RAGScopeアプリケーション構造化ログイベント変換詳細設計](../logging/RAGScopeアプリケーション構造化ログイベント変換詳細設計.md)
- [ErrorType変換詳細設計](../ErrorType変換詳細設計.md)
- [利用者操作詳細設計](../利用者操作詳細設計.md)
- [ユースケース詳細設計](../ユースケース詳細設計.md)