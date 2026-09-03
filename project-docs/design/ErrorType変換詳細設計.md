---
note_type: design
---
# ErrorType変換詳細設計

> [!abstract] この文書の役割
> RAGScopeアプリケーションのHaskell実装で、具体的なfailure値を保持したまま、名前付きの`ErrorClassifier failure`を使って実行追跡・構造化ログで共有する`ErrorType`を得るための共通契約を定義する。`ErrorClassifier`は型クラスinstanceではなく値として扱い、どの分類規則を使うかを静的依存とcompositionから追えるようにする。
>
> `error_type`の論理的な意味と`span`・構造化ログでの利用規則は[実行追跡・構造化ログ契約設計](./実行追跡・構造化ログ契約設計.md)、各failureが表す具体的な失敗条件と保持する詳細値はそのfailureを所有する機能・利用インターフェース・Applicationの設計を正本とする。正確なHaskell型・関数・module・Cabal依存は実装コードと設定を機械可読な正本とする。

## 1. `ErrorType`と`ErrorClassifier`

`ErrorType`は、RAGScopeの処理が成立しなかった理由を、具体的なfailure型から独立して機械的に識別するためのHaskell上の共通表現である。外部の論理契約では`error_type`として扱う。

具体的なfailureから`ErrorType`への分類能力は、概念上次の値で表す。

```haskell
newtype ErrorClassifier failure =
  ErrorClassifier
    { classifyError :: failure -> ErrorType
    }
```

`ErrorClassifier failure`は、`failure`型の値を1つ受け取り、その値に対応する`ErrorType`を返す純粋な分類規則である。具体的なfailure値そのものを`ErrorType`へ置き換えたり、failureが保持する詳細値を破棄したりしない。

たとえばfailureがconstructor引数として数値や文字列を保持する場合、`classifyError classifier failure`を適用して`ErrorType`を得た後も、元のfailure値は呼び出し側が保持している限りその詳細値を含んだままである。失敗eventから構造化ログ属性を作る処理は、必要な詳細値を具体failureまたはeventから利用できる。

`ErrorClassifier`はUseCase固有failureだけを対象としない。UseCase固有failure、利用インターフェースのrouting・command判定・入力変換・検証・結果処理などのfailure、Applicationが所有するfailureなど、そのfailure値から`error_type`を得る必要がある型に対して名前付きClassifier値を定義できる。

failure型であることだけを理由に、すべてのfailure型へ`ErrorClassifier`を要求しない。

この設計では、次の型クラスは導入しない。

```haskell
class ToErrorType failure where
  toErrorType :: failure -> ErrorType
```

分類規則を型クラスinstanceへ隠さず、名前付きの値として定義し、利用箇所またはcompositionで明示的に参照する。

## 2. 分類規則

`classifyError`はfailure値だけを入力として、そのfailureに対応する`ErrorType`を返す純粋な変換とする。

- 実行中のOperation、利用インターフェース、Trace Contextを入力として受け取らない。
- IOや状態参照を行わない。
- 同じClassifier値と同じfailure値の組には常に同じ`ErrorType`を返す。
- 1つの名前付きClassifierは、対象failure型のすべての値に対して`ErrorType`を返す。
- `ErrorType`への分類を行っても、元のfailure値やそのconstructor引数を変更・破棄しない。

具体的なfailureから`ErrorType`への分類規則を必要とする所有側は、そのfailure型に対応する名前付き`ErrorClassifier`値を定義する。分類規則を提供することと、実行時に`classifyError`を適用することは別の責務である。failureを生成または返す処理は、`ErrorType`を必要としない限り分類を行わない。

同じfailure型について、Tracing用とLogging用に別々の分類規則を定義しない。同じ失敗を`span`と構造化ログの両方へ記録する場合は、所有側が定義した同じ名前付きClassifierを利用し、同じ`ErrorType`を得る。

`ErrorClassifier`は入力側に型変数を持つため構造上`Contravariant` instanceを定義できるが、現在のRAGScopeのcompositionではその操作を必要としていない。実際の合成要求が生じるまで`Contravariant ErrorClassifier`は定義しない。

## 3. 所有者とmodule境界

`ErrorType`と`ErrorClassifier`型は、Logging、Tracing、Observability、個別のUseCaseや利用インターフェースのいずれにも所有させず、共通local package `ragscope-error`のpublic main libraryにある`RAGScope.ErrorType`へ置く。

```text
ragscope-error
└─ public: main
   └─ RAGScope.ErrorType
      ├─ ErrorType
      └─ ErrorClassifier failure
```

UseCase固有failureの場合、failure型そのものはそのUseCaseが所有する`RAGScope.<UseCase>.Failure`へ置く。対応する名前付きClassifierは、failure型と`RAGScope.ErrorType`の境界を担当する`RAGScope.<UseCase>.ErrorClassification`へ置く。

```text
ragscope
└─ private: ragscope-use-cases
   ├─ RAGScope.<UseCase>.Failure
   │    └─ <UseCase>Failure
   └─ RAGScope.<UseCase>.ErrorClassification
        └─ <useCase>ErrorClassifier
             :: ErrorClassifier <UseCase>Failure
```

`RAGScope.<UseCase>.Failure`は`ErrorType`や`ErrorClassifier`をimportしない。`RAGScope.<UseCase>.ErrorClassification`がfailure型と`RAGScope.ErrorType`をimportして分類規則を定義する。これによりfailure型自身へ観測基盤の依存を持ち込まない。

利用インターフェースやApplicationが所有するfailureについても同じ原則を適用し、failure型そのものと`ErrorType`への分類規則を必要に応じて分離する。正確なmodule名は各所有者の設計・実装で確定する。

## 4. `OperationFailure`

利用者操作全体の通常failureは、Application側の共通`OperationFailure`で保持する。`OperationFailure`は、具体的なfailure値と、そのfailure型に対応する`ErrorClassifier failure`を組で保持する。

```haskell
data OperationFailure where
  OperationFailure
    :: failure
    -> ErrorClassifier failure
    -> OperationFailure
```

`OperationFailure failure classifier`を構築した後も、`failure`値そのものは保持される。failureがconstructor引数として詳細値を持つ場合も、その値を含んだ具体failureを保持する。`ErrorType`を得るためにfailureを先に変換してから保持する構造にはしない。

`OperationFailure`を受け取る側は、中のfailureを`DenseSearchFailure`などの具体型へ戻して分岐しない。root `span`などで`ErrorType`が必要な場合は、Application側が次のClassifierを提供する。

```haskell
operationFailureErrorClassifier
  :: ErrorClassifier OperationFailure

operationFailureErrorClassifier =
  ErrorClassifier $ \(OperationFailure failure classifier) ->
    classifyError classifier failure
```

このClassifierは`OperationFailure`に保存されたfailure値と対応Classifierを取り出し、同じfailure値へそのClassifierを適用する。そのため、UseCase実行`span`とroot `span`が同じ具体failureに由来する場合は同じ`ErrorType`を得られる。

`OperationFailure`と`operationFailureErrorClassifier`は`ragscope` packageの`ragscope-application` libraryが所有する。UseCase側や`ragscope-error`には置かない。`OperationFailure`の型定義は個別のUseCase固有failure型を参照しない。

個々のOperationが`OperationFailure`を構築するときは、具体failure値をその型として扱える場所で、failure所有側が提供する対応Classifierを使用する。UseCase failureであれば`RAGScope.<UseCase>.ErrorClassification`の名前付きClassifierを利用する。Operation側の依存をrecordへまとめるかどうかとは独立して、`OperationFailure`構築に使う分類規則はこの名前付きClassifierを正本とする。

## 5. Observability・Tracing・Loggingからの利用

Observability Runtimeは、対象failure型の`ErrorClassifier failure`をcomposition時に受け取り、`Either failure result`の`Left failure`を観測用`ErrorType`へ分類する。Operation / UseCaseが利用する`Observability m failure`自体は`ErrorClassifier`を公開しない。

Tracing Portは具体failure、`Either`、`ErrorClassifier`を扱わず、Observability Runtimeから渡された`SpanOutcome`だけを扱う。`SpanFailed ErrorType`を受け取るため、`ragscope-tracing` mainは`ragscope-error` mainへ直接依存する。

構造化ログでは、失敗eventから`LogSpec`への名前付き純粋変換が、必要な場合にfailure所有側の同じ名前付きClassifierを利用する。failureが保持する詳細値を`error_type`以外のattributesへ反映する場合は、eventまたは具体failureからその値を取得する。Classifierは`error_type`の分類だけを担当し、詳細属性を代替しない。

依存方向は次のとおりである。

```text
RAGScope.<UseCase>.Failure
        ↑
        │
RAGScope.<UseCase>.ErrorClassification ──→ RAGScope.ErrorType
        ↑                                      ↑
        │                                      │
UseCase Logging変換                    Observability Runtime / Tracing
```

`ragscope-observability`のpublic main libraryは公開APIに`ErrorClassifier`を出さないため`ragscope-error`へ直接依存しない。`RAGScope.Observability.Runtime.makeObservability`が`ErrorClassifier failure`を受け取るため、`runtime` libraryは`ragscope-error` mainへ直接依存する。

## 6. 各設計との関係

| 対象 | この共通契約との関係 |
|---|---|
| UseCase | UseCase固有failure型は`RAGScope.<UseCase>.Failure`が所有し、`RAGScope.<UseCase>.ErrorClassification`が名前付き`ErrorClassifier <UseCase>Failure`を提供する。UseCase本体はfailure値を返し、Classifierや`ErrorType`を直接扱わない。UseCase境界でのfailureの受け渡しは[ユースケース詳細設計](./ユースケース詳細設計.md)を正本とする |
| 利用者操作 | UseCase前・UseCase・UseCase後で受け取った具体的なfailure値と対応Classifierを`OperationFailure`へ保持する。root `span`では`operationFailureErrorClassifier`が保存されたClassifierを同じfailure値へ適用する。`OperationFailure`のHaskell表現は[利用者操作詳細設計](./利用者操作詳細設計.md)を正本とする |
| 構造化ログ | 失敗eventが具体failureを元に`error_type`を生成する場合、eventから`LogSpec`への変換処理が所有側の名前付きClassifierを利用する。failureの詳細値を他のattributesへ反映する処理とは分離する。eventから`LogSpec`への変換は[RAGScopeアプリケーション構造化ログイベント変換詳細設計](./logging/RAGScopeアプリケーション構造化ログイベント変換詳細設計.md)を正本とする |
| 実行追跡 | Observability Runtimeが`Either failure result`を解釈し、Classifierで`ErrorType`へ分類して`SpanOutcome`をTracingへ渡す。Span Statusと`error_type`の論理規則は[実行追跡・構造化ログ契約設計](./実行追跡・構造化ログ契約設計.md)を正本とする |

## 7. 現在の未決定事項

`RAGScope.ErrorType`の公開exportについて、`ErrorClassifier`のconstructorを公開するか、constructorを非公開にして`failure -> ErrorType`から`ErrorClassifier failure`を構築する公開APIを設けるかは未決定である。

どちらの場合も、failure所有側の`RAGScope.<UseCase>.ErrorClassification`やApplication側など、`RAGScope.ErrorType`の外部moduleが名前付きClassifier値を定義できる必要がある。この未決定事項はClassifierの分類規則、所有責務、`OperationFailure`やObservability Runtimeとの値の流れを変更するものではなく、`RAGScope.ErrorType`が公開する構築境界だけを対象とする。

## 関連文書

- [ユースケース詳細設計](./ユースケース詳細設計.md)
- [利用者操作基本設計](./利用者操作基本設計.md)
- [利用者操作詳細設計](./利用者操作詳細設計.md)
- [実行追跡・構造化ログ契約設計](./実行追跡・構造化ログ契約設計.md)
- [RAGScopeアプリケーション構造化ログイベント変換詳細設計](./logging/RAGScopeアプリケーション構造化ログイベント変換詳細設計.md)
