---
note_type: design
---
# ErrorType変換詳細設計

> [!abstract] この文書の役割
> RAGScopeアプリケーションのHaskell実装で、具体的なfailure値に`toErrorType`を適用して、実行追跡・構造化ログで共有する`ErrorType`を得るための共通契約を定義する。`ToErrorType`はUseCase固有の仕組みではなく、Feature、利用インターフェース、Applicationなどが所有する具体的なfailure型に対して定義できる。
>
> `error_type`の論理的な意味と`span`・構造化ログでの利用規則は[実行追跡・構造化ログ契約設計](./実行追跡・構造化ログ契約設計.md)、各failureが表す具体的な失敗条件はそのfailureを所有する機能・利用インターフェース・Applicationの設計を正本とする。正確なHaskell型・class・instance・module・Cabal依存は実装コードと設定を機械可読な正本とする。

## 1. `ErrorType`と`ToErrorType`

`ErrorType`は、RAGScopeの処理が成立しなかった理由を、具体的なfailure型から独立して機械的に識別するためのHaskell上の共通表現である。外部の論理契約では`error_type`として扱う。

Haskell実装上の契約は、概念的には次の変換を提供する。

```haskell
class ToErrorType failure where
    toErrorType :: failure -> ErrorType
```

`toErrorType`は具体的なfailure値を1つ受け取り、その値に対応する`ErrorType`を1つ返す。この宣言は入出力を示す概念表現であり、正確なclass・関数定義は実装コードを正本とする。

`ToErrorType`はUseCase固有failureだけを対象としない。FeatureのUseCase固有failure、利用インターフェースのrouting・command判定・入力変換・検証・結果処理などのfailure、Applicationが所有するfailureなど、そのfailure値から`error_type`を得る必要がある型に対してinstanceを定義する。

failure型であることだけを理由に、すべてのfailure型へ`ToErrorType`を要求しない。

## 2. 変換規則

`toErrorType`はfailure値だけを入力として、そのfailureに対応する`ErrorType`を返す純粋な変換とする。

- 実行中のOperation、利用インターフェース、Trace Contextを入力として受け取らない。
- IOや状態参照を行わない。
- 同じfailure値には常に同じ`ErrorType`を返す。
- `ToErrorType` instanceを持つfailure型のすべての値に対して`ErrorType`を返す。

具体的なfailure型の所有側は、そのfailureから`ErrorType`への変換規則が必要な場合に`ToErrorType` instanceを定義する。instanceとして変換規則を提供することと、実行時に`toErrorType`を適用することは別の責務である。failureを生成または返す処理は、`ErrorType`を必要としない限り変換を行わない。`ErrorType`を必要とする処理が具体的なfailure値へ`toErrorType`を適用する。

`ErrorType`を必要とする公開境界が具体的なfailure値を受け取る場合、その境界を`DenseSearchFailure`など特定のfailure型へ固定せず、概念上`ToErrorType failure => failure`を受け取れる形とする。境界内で`toErrorType failure`を適用し、具体的なfailure値を必要としない下位処理には変換後の`ErrorType`を渡す。

どの処理または公開APIが`ErrorType`を必要とし、そこで変換を行うか、正確な関数名とmodule分割は各責務の設計・実装で確定する。

## 3. failure所有者とinstance

`ErrorType`と`ToErrorType`は、Logging、Tracing、Observability、個別のFeatureや利用インターフェースのいずれにも所有させず、共通local package `ragscope-error`のpublic main libraryにある`RAGScope.ErrorType`へ置く。

```text
ragscope-error
└─ public: main
   └─ RAGScope.ErrorType
      ├─ ErrorType
      └─ ToErrorType
```

具体的なfailure型に対する`ToErrorType` instanceは、そのfailure型を所有するmoduleに置く。

UseCase固有failureの場合は、failure型をそのUseCaseを所有するFeatureの`RAGScope.<Feature>.Failure`に置き、`ToErrorType` instanceも同じmoduleに置く。

```text
ragscope
└─ private: ragscope-features
   └─ RAGScope.<Feature>.Failure
      ├─ <UseCase>Failure
      └─ ToErrorType instance
```

利用者操作全体の通常failureは、Application側の共通`OperationFailure`で保持する。`OperationFailure`は、`ToErrorType` instanceを持つ具体的なfailure値を1つ保持する。

```haskell
data OperationFailure where
  OperationFailure
    :: ToErrorType failure
    => failure
    -> OperationFailure
```

`OperationFailure`自身の`ToErrorType` instanceは、constructorから中の`failure`値を取り出し、その値に`toErrorType`を適用して結果を返す。

```haskell
instance ToErrorType OperationFailure where
  toErrorType (OperationFailure failure) =
    toErrorType failure
```

たとえば`OperationFailure denseSearchFailure`へ`toErrorType`を適用すると、上のinstanceは`denseSearchFailure`を取り出して`toErrorType denseSearchFailure`を実行する。利用者操作ごとに`DenseSearchOperationFailure`などの型や、その型専用の`ToErrorType` instanceは定義しない。

`OperationFailure`は`ragscope` packageの`ragscope-application` libraryが所有する。Featureや`ragscope-error`には置かない。`ragscope-application`は`OperationFailure`のconstructor制約とinstanceで`ToErrorType`を使うため、`RAGScope.ErrorType`をimportし、`ragscope-error`へ直接依存する。正確な`OperationFailure`のmodule名はApplication実装時にコードで確定する。

`ragscope-tracing`のpublic main libraryは、`RAGScope.Tracing.observeResult`の`ToErrorType failure`制約のため`ragscope-error` mainへ直接依存する。`ragscope-observability`のpublic main libraryも、公開する`withTrace` / `withSpan`の`ToErrorType failure`制約のため`ragscope-error` mainへ直接依存する。`ragscope-observability`のruntime libraryはObservability mainと`ragscope-tracing` mainを通して必要な契約を利用し、`ragscope-error`へは直接依存しない。Loggingが`ragscope-error`へ直接依存するかは、Loggingの公開APIと内部表現を設計するときに確定する。

`ErrorType`の内部表現と具体的な値は、この文書では固定せず、実装コードを正本とする。

## 4. 各設計との関係

| 対象 | この共通契約との関係 |
|---|---|
| UseCase | UseCase固有failure型の所有側が`ToErrorType` instanceを定義する。UseCase本体はfailure値を返し、UseCase実行`span`などで`ErrorType`を必要とする処理が、その具体的なfailure値へ`toErrorType`を適用する。UseCase境界でのfailureの受け渡しは[ユースケース詳細設計](./ユースケース詳細設計.md)を正本とする |
| 利用者操作 | UseCase前・UseCase・UseCase後で受け取った具体的なfailure値を`OperationFailure failure`として保持する。root `span`などで`ErrorType`を必要とする処理が`toErrorType operationFailure`を適用し、`ToErrorType OperationFailure` instanceが中のfailure値に`toErrorType`を適用する。`OperationFailure`のHaskell表現は[利用者操作詳細設計](./利用者操作詳細設計.md)を正本とする |
| 構造化ログ | 失敗eventが具体的なfailureを元に`error_type`を生成する場合、その変換を必要とするeventから`LogSpec`への変換処理がfailure値へ`toErrorType`を適用し、得た`ErrorType`を`LogSpec`へ入れる。eventから`LogSpec`への変換は[RAGScopeアプリケーション構造化ログイベント変換詳細設計](./logging/RAGScopeアプリケーション構造化ログイベント変換詳細設計.md)を正本とする |
| 実行追跡 | 失敗した`span`へ付ける`error_type`の論理的な意味と、同じ失敗をログと共有する規則は[実行追跡・構造化ログ契約設計](./実行追跡・構造化ログ契約設計.md)を正本とする |

## 関連文書

- [ユースケース詳細設計](./ユースケース詳細設計.md)
- [利用者操作基本設計](./利用者操作基本設計.md)
- [利用者操作詳細設計](./利用者操作詳細設計.md)
- [実行追跡・構造化ログ契約設計](./実行追跡・構造化ログ契約設計.md)
- [RAGScopeアプリケーション構造化ログイベント変換詳細設計](./logging/RAGScopeアプリケーション構造化ログイベント変換詳細設計.md)
