---
note_type: design
---
# ErrorType変換詳細設計

> [!abstract] この文書の役割
> RAGScopeアプリケーションのHaskell実装で、具体的なfailure値を、実行追跡・構造化ログで共有する観測用の`ErrorType`へ変換する共通契約を定義する。`ToErrorType`はUseCase固有の仕組みではなく、Feature、利用インターフェース、Applicationなどが所有する具体的な失敗理由を共通`ErrorType`へ接続するための契約である。
>
> `error_type`の論理的な意味と`span`・構造化ログでの利用規則は[実行追跡・構造化ログ契約設計](./logging/実行追跡・構造化ログ契約設計.md)、各failureが表す具体的な失敗条件はそのfailureを所有する機能・利用インターフェース・Applicationの設計を正本とする。正確なHaskell型・class・instance・module・Cabal依存は実装コードと設定を機械可読な正本とする。

## 1. `ErrorType`と`ToErrorType`

`ErrorType`は、RAGScopeの処理が成立しなかった理由を、具体的なfailure型から独立して機械的に識別するためのHaskell上の共通表現である。外部の論理契約では`error_type`として扱う。

具体的なfailure値から`ErrorType`への変換を`ToErrorType`で表す。

```text
具体的なfailure
       │
       │ ToErrorType
       ▼
    ErrorType
       │
       └─ span / 構造化ログの error_type
```

Haskell実装上の契約は、概念的には次の変換を提供する。

```haskell
class ToErrorType failure where
    toErrorType :: failure -> ErrorType
```

この宣言は責務と入出力を示すための概念表現であり、正確なclass・関数定義は実装コードを正本とする。

`ToErrorType`はUseCase固有failureだけを対象とする契約ではない。FeatureのUseCase固有failure、利用インターフェースのrouting・command判定・入力変換・検証・結果処理などのfailure、Applicationが所有するfailureなど、**その具体的な失敗理由を`error_type`として観測するfailure型**に対して使用する。

failure型であることだけを理由に、すべてのfailure型へ`ToErrorType`を要求しない。そのfailureを`error_type`の元となる具体的な失敗理由として扱う場合に、この契約へ接続する。

## 2. 変換規則

`ToErrorType`はfailure値だけを入力として、そのfailureに対応する`ErrorType`を返す純粋な変換とする。

- 実行中のOperation、利用インターフェース、Trace Contextを入力として受け取らない。
- IOや状態参照を行わない。
- 同じfailure値には常に同じ`ErrorType`を返す。
- `ToErrorType` instanceを持つfailure型のすべての値に対して`ErrorType`を返す。

`ErrorType`を必要とする公開境界が具体的なfailure値を受け取る場合、その境界を`DenseSearchFailure`など特定のfailure型へ固定せず、概念上`ToErrorType failure => failure`を受け取れる形とする。境界内で`toErrorType`を適用し、それより下位のObservability、Tracing、Logging側の処理へ具体的なfailure値を渡さず、変換後の`ErrorType`を渡す。

どのObservability公開APIが変換境界を担当するか、正確な関数名とmodule分割はこの文書では固定しない。

## 3. failure所有者とinstance

`ErrorType`と`ToErrorType`は、Logging、Tracing、Observability、個別のFeatureや利用インターフェースのいずれにも所有させず、共通local package `ragscope-error`のpublic main libraryにある`RAGScope.ErrorType`へ置く。

```text
ragscope-error
└─ public: main
   └─ RAGScope.ErrorType
      ├─ ErrorType
      └─ ToErrorType
```

具体的なfailure型に対する`ToErrorType` instanceは、そのfailure型を所有するmoduleに置く。これにより、failureの所有者自身が共通`ErrorType`への分類を定義し、instanceをorphanにしない。

UseCase固有failureの場合は、failure型をそのUseCaseを所有するFeatureの`RAGScope.<Feature>.Failure`に置き、`ToErrorType` instanceも同じmoduleに置く。

```text
ragscope
└─ private: ragscope-features
   └─ RAGScope.<Feature>.Failure
      ├─ <UseCase>Failure
      └─ ToErrorType instance
```

`ToErrorType` instanceを定義するlibraryは`RAGScope.ErrorType`をimportするため`ragscope-error`へ依存する。Observability、Tracing、Loggingの各packageが`ragscope-error`へ直接依存するかは、各packageの公開APIと内部表現を設計するときに確定する。

`ErrorType`の内部表現と具体的な値は、この文書では固定せず、実装コードを正本とする。

## 4. 各設計との関係

| 対象 | この共通契約との関係 |
|---|---|
| UseCase | UseCase固有failureをFeatureが所有し、そのfailureから`ErrorType`へ変換できるようにする。UseCase境界でのfailureの受け渡しは[ユースケース詳細設計](./ユースケース詳細設計.md)を正本とする |
| 利用者操作 | UseCase前・UseCase・UseCase後の具体的なfailureのうち、root `span`などで`error_type`として観測するfailureをこの契約へ接続する。`OperationFailure`の構造は[利用者操作基本設計](./利用者操作基本設計.md)を正本とする |
| 構造化ログ | 失敗eventが具体的なfailureを元に`error_type`を生成する場合、この契約で得た`ErrorType`を`LogSpec`へ反映する。eventから`LogSpec`への変換は[構造化ログイベント変換設計](./logging/構造化ログイベント変換設計.md)を正本とする |
| 実行追跡 | 失敗した`span`へ付ける`error_type`の論理的な意味と、同じ失敗をログと共有する規則は[実行追跡・構造化ログ契約設計](./logging/実行追跡・構造化ログ契約設計.md)を正本とする |

## 関連文書

- [ユースケース詳細設計](./ユースケース詳細設計.md)
- [利用者操作基本設計](./利用者操作基本設計.md)
- [実行追跡・構造化ログ契約設計](./logging/実行追跡・構造化ログ契約設計.md)
- [構造化ログイベント変換設計](./logging/構造化ログイベント変換設計.md)
