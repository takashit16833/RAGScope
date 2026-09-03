---
note_type: design
---
# RAGScopeアプリケーション構造化ログイベント変換詳細設計

> [!abstract] この文書の役割
> RAGScopeアプリケーションの構造化ログ実装を実装・レビューする開発者向けの詳細設計である。UseCase、利用インターフェース、Application lifecycleなどの所有者が定義するeventを、型付き`Logger`、明示的な純粋変換、Logging Runtimeによって`LogRecord`へ変換する境界を定義する。
>
> 構造化ログの論理情報と記録規則は[実行追跡・構造化ログ契約設計](../実行追跡・構造化ログ契約設計.md)、具体的なfailureから共通`ErrorType`への変換は[ErrorType変換詳細設計](../ErrorType変換詳細設計.md)、具体的なeventの意味・記録条件・属性はそのeventを所有する設計、JSON・SQLiteへの投影は各外部表現設計を正本とする。

## 1. eventから`LogRecord`までの変換

構造化ログへ記録するeventは、その出来事を意味として所有するUseCase、利用インターフェース、Application lifecycleなどが定義する。Logging共通基盤は、具体的なevent名、記録条件、重要度、属性、`error_type`を所有者に代わって決めない。

RAGScopeアプリケーションでは、所有者が定義したeventを次の順序でLogging共通表現へ変換する。

```text
所有者が定義するevent
        ↓ event -> LogSpec
      LogSpec
        ↓ Logger m LogSpec
timestamp / component / current Trace Contextを付加
        ↓
     LogRecord
        ↓
       Sink
```

`LogSpec`は、event名、重要度、任意のmessage、attributesなど、eventの値から決まるログの意味を表す。失敗を報告するeventで`error_type`を記録する場合、その`error_type`もattributesの一部として`LogSpec`へ含める。

`LogRecord`は、`LogSpec`へ発生時刻、発生元component、Trace Contextを付加した構造化ログ1件のLogging内部表現である。特定の`span`へ属するログには`TraceId`と`SpanId`を組で付加し、特定の`span`へ属さないログには両方を付加しない。

`LogSpec`と`LogRecord`はJSONやSQLiteの外部表現ではない。JSON・SQLiteへの投影は、それぞれの外部表現設計に従って`LogRecord`から行う。

## 2. `Logger m event`

Application / UseCaseがeventを記録する能力は、`RAGScope.Logging`が公開する型付き`Logger`で表す。

```haskell
newtype Logger m event =
  Logger
    { record :: event -> m ()
    }
```

`Logger m SearchEvent`は`SearchEvent`を、`Logger m LifecycleEvent`は`LifecycleEvent`を記録する能力である。利用側は、自身が所有または処理するevent型に対応した`Logger m event`を受け取り、次の1操作だけを行う。

```haskell
record logger event
```

`record`はtrace内eventとtrace外eventで分けない。Logging Runtimeが記録時にcurrent Trace Contextを取得し、`Just traceContext`なら`TraceId`・`SpanId`を組で付加し、`Nothing`なら両方を付加しない。

`record`はLogging RuntimeやSinkで発生したlogging failureをtyped resultとしてOperation / UseCaseへ返さない。logging failureは利用者操作の`OperationResult`を変更せず、Logging側の独立したfailure境界で通知・保持する。利用者操作本体とlogging failureの関係は[利用者操作詳細設計](../利用者操作詳細設計.md)を正本とする。

`Logger m event`の`event`はLogger値ごとに固定される。1つのLogging値が任意のevent型を型クラス制約付きで受け取るAPIにはせず、Loggingのevent受付のために`RankNTypes`を使用しない。

## 3. `Contravariant`によるLoggerの変換

`Logger m`には`contravariant` packageの`Contravariant` instanceを定義する。

```haskell
instance Contravariant (Logger m) where
  contramap f (Logger recordB) =
    Logger (recordB . f)
```

Logging Runtimeは、共通表現を記録できる基礎Loggerを組み立てる。次は責務と型を示す概念例であり、関数名は固定しない。

```haskell
logSpecLogger :: Logger m LogSpec
```

event所有側は、所有するeventから`LogSpec`への純粋関数を提供する。たとえばdense検索UseCaseでは、概念上次の形とする。

```haskell
searchEventToLogSpec
  :: SearchEvent
  -> LogSpec
```

Applicationのcomposition rootは、この純粋関数と基礎Loggerを`contramap`で合成し、UseCaseへ渡すLoggerを作る。

```haskell
searchLogger :: Logger m SearchEvent
searchLogger =
  contramap searchEventToLogSpec logSpecLogger
```

composition rootは、作成したUseCase別LoggerをそのUseCaseが所有する依存recordへ他の必要な能力とともに格納し、その依存recordをUseCaseへ渡す。UseCaseへApplication全体の`AppEnv`を渡してそこからLoggerを取り出させる構造にはしない。UseCaseが必要とする依存能力の受け渡し全体は[ユースケース詳細設計](../ユースケース詳細設計.md)を正本とする。

この合成により、UseCase本体やevent記録箇所は`LogSpec`、`LogRecord`、Logging Runtime、Sinkを扱わず、自身のevent型と対応する`Logger m event`だけを扱う。変換関数を実行時に適用する責務は、UseCaseの各記録箇所ではなく、composition時に作られたLogger値へ閉じる。

## 4. eventから`LogSpec`への純粋変換

eventから`LogSpec`への変換は、`ToLogSpec`型クラスではなく、event所有側が提供する名前付き純粋関数で表す。

変換関数はevent値だけを入力として、そのeventに対応する`LogSpec`を返す。発生時刻、発生元component、Trace Contextは入力にせず、Logging Runtimeが`LogRecord`を完成するときに付加する。

変換関数はeventを構造化ログへ記録するかどうかを決めない。どの条件でeventを発生させて`record`へ渡すかは、そのeventを所有する設計で定める。変換関数は、渡されたeventをどのevent名、重要度、message、attributesとして表すかだけを担当する。

UseCase eventの変換関数は、UseCase固有のeventとLogging共通表現の境界を担当する`RAGScope.<UseCase>.Logging`へ置く。Applicationは変換規則を定義せず、composition rootからその関数を明示的にimportして対応するLogger値を組み立てる。

この設計では`ToLogSpec`型クラスとinstanceを定義しない。したがって、UseCase eventに対するorphan instanceと、それを有効にするための`RAGScope.Application.LoggingInstances`や`import ... ()`も使用しない。

## 5. failureと失敗event

具体的なfailure型そのものには、failureであることだけを理由に構造化ログ用の変換を要求しない。失敗を構造化ログへ記録する場合は、その失敗を意味として表すeventを失敗の所有者側で定義し、そのeventから`LogSpec`への純粋関数を提供する。

具体的なfailureを`error_type`として観測する場合は、[ErrorType変換詳細設計](../ErrorType変換詳細設計.md)の共通`ToErrorType`契約によって`ErrorType`へ変換する。

```text
具体的なfailure
        ↓ ToErrorType
     ErrorType

失敗を表すowner event
        ↓ event -> LogSpec
       LogSpec
```

失敗eventが具体的なfailure値を元に`error_type`属性を生成する場合、`LogSpec`には共通`ToErrorType`契約で得られる`ErrorType`に対応する値を反映する。eventへどのfailure情報を保持させるか、`toErrorType`をどの変換関数で適用するか、どの`error_type`を属性として記録するかは、event所有者の設計で定める。

UseCase失敗の場合も同じ契約を使う。UseCase固有failure型自身には構造化ログ用の変換を要求せず、その失敗を表すUseCase eventをUseCase側で定義する。

## 6. 責務と依存

| 対象 | 正本・担当する内容 |
|---|---|
| UseCase event | 各UseCase設計。eventの意味、発生条件、event固有属性、必要な`error_type` |
| UseCase eventの変換関数 | `RAGScope.<UseCase>.Logging`。UseCase eventから`LogSpec`への純粋変換 |
| UseCase依存record | UseCase。UseCaseが実行時に必要とする能力だけを保持し、UseCase別`Logger m event`もこのrecordを通して受け取る |
| 利用インターフェース固有event | 各利用インターフェースの設計・実装。eventの意味、発生条件、event固有属性 |
| Application lifecycle event | Application lifecycleを担当する設計・実装。eventの意味、発生条件、event固有属性 |
| `Logger m event` / `record` / `Contravariant` instance | `RAGScope.Logging`。利用側がeventを記録する型付き能力と、その入力型を変換する合成 |
| `ErrorType` / `ToErrorType` | [ErrorType変換詳細設計](../ErrorType変換詳細設計.md)。具体的なfailureから観測用`ErrorType`へ変換する共通契約 |
| `LogSpec` | Logging。event値から決まるログの意味を表す共通内部表現 |
| `Logger m LogSpec` / `LogRecord`生成 | Logging Runtime。`LogSpec`へ発生時刻、発生元component、current Trace Contextを付加してSinkへ渡す |
| UseCase別LoggerとUseCase依存recordの組み立て | Application composition root。`event -> LogSpec`と`Logger m LogSpec`を`contramap`で合成し、UseCaseに必要な他の能力とともに依存recordを構築する |
| JSON / SQLiteへの投影 | 各構造化ログ外部表現設計と対応する実装 |

`RAGScope.<UseCase>.UseCase`とeventの記録箇所はUseCase所有の依存recordから`RAGScope.Logging`の`Logger m <UseCaseEvent>`を受け取り、`record`を利用する。UseCase側はApplication全体の`AppEnv`、`LogSpec`、`LogRecord`、Logging Runtime、Sink、JSON / SQLite実装をimportしない。`RAGScope.<UseCase>.Logging`だけがUseCase eventと`LogSpec`を参照して純粋変換を定義する。

`ragscope-logging`の`RAGScope.Logging`を公開するlibraryは、`Contravariant (Logger m)` instanceを定義するため`contravariant` packageへ直接依存する。composition rootで`contramap`を呼ぶlibraryも`Data.Functor.Contravariant`をimportし、`contravariant` packageへ直接依存する。

## 7. 現在固定していない実装詳細

現時点では次を固定しない。

- `LogSpec`、`LogRecord`、属性値型の正確なHaskell定義。
- 利用インターフェース固有eventとApplication lifecycle eventの変換関数を配置する正確なmoduleと、それに伴うCabal library間の静的依存。
- UseCase所有の依存recordの正確な型名・field・module名。UseCaseへApplication全体の`AppEnv`を渡さず、UseCaseが必要な能力だけを依存recordで受け取ることは固定する。
- `Logger m LogSpec`を組み立てる関数名とLogging Runtimeのmodule分割。
- Sink自身を含むlogging failureをどのLogging内部境界へ通知・保持するか。logging failureをOperation / UseCaseへtyped resultとして返さず、`OperationResult`を変更しないことは固定する。

実装後の正確な型、関数、module、Cabal `build-depends`はコードとCabal設定を機械可読な正本とする。

## 関連文書

- [実行追跡・構造化ログ契約設計](../実行追跡・構造化ログ契約設計.md)
- [RAGScopeアプリケーション実行追跡詳細設計](../tracing/RAGScopeアプリケーション実行追跡詳細設計.md)
- [ErrorType変換詳細設計](../ErrorType変換詳細設計.md)
- [ユースケース詳細設計](../ユースケース詳細設計.md)
- [利用者操作詳細設計](../利用者操作詳細設計.md)
- [構造化ログ外部表現共通設計](./構造化ログ外部表現共通設計.md)
- [構造化ログJSON表現設計](./構造化ログJSON表現設計.md)
- [構造化ログSQLite表現設計](./構造化ログSQLite表現設計.md)
