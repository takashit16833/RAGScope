---
note_type: design
---
# RAGScopeアプリケーション構造化ログイベント変換詳細設計

> [!abstract] この文書の役割
> RAGScopeアプリケーションの構造化ログ実装を実装・レビューする開発者向けの詳細設計である。UseCase、利用インターフェース、Application lifecycleなどの所有者が定義するeventを、型付き`Logger`、明示的な純粋変換、Logging Runtimeによって`LogRecord`へ変換する境界を定義する。
>
> 構造化ログの論理情報と記録規則は[実行追跡・構造化ログ契約設計](../実行追跡・構造化ログ契約設計.md)、具体的なfailureから共通`ErrorType`への分類は[ErrorType変換詳細設計](../ErrorType変換詳細設計.md)、具体的なeventの意味・記録条件・属性はそのeventを所有する設計、JSON・SQLiteへの投影は各外部表現設計を正本とする。

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

### 1.1 Logging中核型

`ragscope-logging`のLogging coreは、後続実装で次の型構造を採用する。ここで示す型名・constructor・fieldと保持する値の構造は現在設計として固定し、実装後の正確なexport listと定義はコードを機械可読な正本とする。

```haskell
newtype EventName =
  EventName Text

data LogLevel
  = Debug
  | Info
  | Warn
  | Error
  | Fatal

newtype AttributeName =
  AttributeName Text

data AttributeValue
  = AttributeText Text
  | AttributeNumber Scientific
  | AttributeBool Bool
  | AttributeArray [AttributeValue]
  | AttributeObject (Map AttributeName AttributeValue)

newtype Attributes =
  Attributes (Map AttributeName AttributeValue)

newtype Timestamp =
  Timestamp UTCTime

newtype Component =
  Component Text

data LogSpec =
  LogSpec
    { event :: EventName
    , level :: LogLevel
    , message :: Maybe Text
    , attributes :: Attributes
    }

data LogRecord =
  LogRecord
    { timestamp :: Timestamp
    , component :: Component
    , traceContext :: Maybe TraceContext
    , spec :: LogSpec
    }
```

`LogLevel`はイベントの重要度だけを表し、`Debug`、`Info`、`Warn`、`Error`、`Fatal`の5値を独立して持つ。通常イベントと失敗イベントの直和や、失敗variantから`Error` levelを固定的に導出する旧構造は現在設計へ持ち込まない。処理が成功したか失敗したかはOperation / UseCaseの結果とspanの`SpanOutcome`が担当し、ログ重要度とは別の情報として扱う。

`Attributes`は`Map AttributeName AttributeValue`を保持し、属性が0件の場合は空の`Map`で表す。`Maybe Attributes`にはしない。これにより「属性なし」を複数の内部状態で表さず、同じ属性名を1件のログ内で重複して保持できない構造にする。JSONへ投影するときだけ、top-levelの`Attributes`が空なら`attributes` property自体を省略する。

`AttributeValue`は文字列、数値、真偽値、array、objectを再帰的に表す。数値は`Scientific`を使用し、`null`に相当するconstructorは持たない。`AttributeArray []`と`AttributeObject Map.empty`は値として存在する空array・空objectなので保持する。objectも`Map AttributeName AttributeValue`とし、同じ名前を重複して保持しない。

`message`は`Maybe Text`とする。`Nothing`はmessageが存在しない状態、`Just ""`は空文字列のmessageが存在する状態であり、両者を区別する。

`LogRecord.traceContext`は`Maybe TraceContext`とし、`TraceId`と`SpanId`を別々の`Maybe` fieldとして持たない。`Nothing`は特定のspanへ属さないログ、`Just traceContext`は`TraceId`と`SpanId`の組を持つログを表すため、片方だけ存在する状態を内部型で表現しない。

`LogRecord`はJSON Schemaと同型にすることを目的としない。`spec.event`、`spec.level`、`spec.message`、`spec.attributes`とRuntimeが付加した共通情報を、serialization境界でJSONまたはSQLiteの外部契約へ投影する。

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

具体的なfailureを`error_type`として観測する場合は、[ErrorType変換詳細設計](../ErrorType変換詳細設計.md)で定義する名前付き`ErrorClassifier failure`によって`ErrorType`へ分類する。

```text
具体的なfailure
        │
        ├─ ErrorClassifier failure
        │        ↓
        │     ErrorType
        │
        └─ failureの詳細値
                 ↓
          event固有attributes

失敗を表すowner event
        ↓ event -> LogSpec
       LogSpec
```

Classifierは`error_type`の分類だけを担当する。failureがconstructor引数として保持する数値・文字列などの詳細値を消去したり、それらの属性をClassifierへ集約したりしない。

失敗eventが具体的なfailure値を保持する場合、`RAGScope.<UseCase>.Logging`などのevent→`LogSpec`変換は、そのfailureをpattern matchして必要な詳細値を`error_type`以外のattributesへ反映できる。同じ変換で`error_type`が必要な場合は、そのfailure所有側が提供する名前付きClassifierを利用する。

UseCase固有failureの場合、`RAGScope.<UseCase>.ErrorClassification`が`ErrorClassifier <UseCase>Failure`を定義する。Observabilityと構造化ログは同じ名前付きClassifierを使用し、同じ具体failureから同じ`ErrorType`を得る。Tracing用とLogging用に別のClassifierを定義しない。

たとえば概念上は次の依存になる。

```text
RAGScope.<UseCase>.Failure
        ↑
        ├───────────────┐
        │               │
RAGScope.<UseCase>.ErrorClassification
        │               │
        │               ↓
        │        RAGScope.<UseCase>.Logging
        │               ↓
        │          event -> LogSpec
        │
        └─ ErrorClassifier <UseCase>Failure
```

UseCase本体は`ErrorClassifier`や`LogSpec`を直接扱わず、UseCase所有の依存recordから`Logger m <UseCaseEvent>`を受け取ってeventを記録する。

## 6. 責務と依存

| 対象 | 正本・担当する内容 |
|---|---|
| UseCase failure | `RAGScope.<UseCase>.Failure`。UseCase固有failure型と、そのconstructorが保持する詳細値 |
| UseCase failureの分類 | `RAGScope.<UseCase>.ErrorClassification`。名前付き`ErrorClassifier <UseCase>Failure` |
| UseCase event | 各UseCase設計。eventの意味、発生条件、event固有属性、必要な`error_type` |
| UseCase eventの変換関数 | `RAGScope.<UseCase>.Logging`。UseCase eventから`LogSpec`への純粋変換。失敗eventでは必要に応じて同UseCaseのClassifierを利用する |
| UseCase依存record | UseCase。UseCaseが実行時に必要とする能力だけを保持し、`Observability m <UseCase>Failure`とUseCase別`Logger m event`もこのrecordを通して受け取る |
| 利用インターフェース固有event | 各利用インターフェースの設計・実装。eventの意味、発生条件、event固有属性 |
| Application lifecycle event | Application lifecycleを担当する設計・実装。eventの意味、発生条件、event固有属性 |
| `Logger m event` / `record` / `Contravariant` instance | `RAGScope.Logging`。利用側がeventを記録する型付き能力と、その入力型を変換する合成 |
| `ErrorType` / `ErrorClassifier` | [ErrorType変換詳細設計](../ErrorType変換詳細設計.md)。具体failureから観測用`ErrorType`へ分類する共通型と規則 |
| Logging中核型 | `ragscope-logging`のLogging core。`EventName`、`LogLevel`、`AttributeName`、`AttributeValue`、`Attributes`、`Timestamp`、`Component`、`LogSpec`、`LogRecord` |
| `Logger m LogSpec` / `LogRecord`生成 | Logging Runtime。`LogSpec`へ発生時刻、発生元component、current Trace Contextを付加してSinkへ渡す |
| UseCase別LoggerとUseCase依存recordの組み立て | Application composition root。`event -> LogSpec`と`Logger m LogSpec`を`contramap`で合成し、そのUseCase用Observabilityや他の能力とともに依存recordを構築する |
| JSON / SQLiteへの投影 | 各構造化ログ外部表現設計と対応する実装 |

`RAGScope.<UseCase>.UseCase`とeventの記録箇所はUseCase所有の依存recordから`RAGScope.Logging`の`Logger m <UseCaseEvent>`を受け取り、`record`を利用する。UseCase側はApplication全体の`AppEnv`、`LogSpec`、`LogRecord`、Logging Runtime、Sink、JSON / SQLite実装をimportしない。

`RAGScope.<UseCase>.Logging`はUseCase eventとLogging coreの`LogSpec`を参照し、失敗eventで`error_type`が必要な場合は`RAGScope.<UseCase>.ErrorClassification`のClassifierも参照する。`RAGScope.<UseCase>.Failure`自体は`RAGScope.ErrorType`へ依存しない。

`ragscope-logging`のLogging coreは、`Text`のため`text`、`Map`のため`containers`、`Scientific`のため`scientific`、`UTCTime`のため`time`、`TraceContext`のため`ragscope-tracing`の`core` libraryへ直接依存する。`RAGScope.Logging`を公開するlibraryは、`Contravariant (Logger m)` instanceを定義するため`contravariant` packageへ直接依存する。composition rootで`contramap`を呼ぶlibraryも`Data.Functor.Contravariant`をimportし、`contravariant` packageへ直接依存する。

## 7. 現在固定していない実装詳細

現時点では次を固定しない。

- `EventName`、`AttributeName`、`Component`などのconstructorを公開するか、文字列表現の検証を生成APIへ閉じるかというexport / 構築API。保持する型構造は1.1で固定済み。
- 利用インターフェース固有eventとApplication lifecycle eventの変換関数・Classifierを配置する正確なmoduleと、それに伴うCabal library間の静的依存。
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
