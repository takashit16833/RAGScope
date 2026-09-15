---
note_type: adr
status: accepted
---
# ADR-0010 — RAGScopeアプリケーションの失敗を処理単位の具体型で扱う

## 背景

ADR-0006は、RAGScope共通の`RAGScopeError`やObservability専用error分類を設けず、具体的なUseCaseまたは内部処理の失敗型から利用者向け表現、実験結果、Telemetryの`error.type`へ必要な境界で直接変換する方針を決めた。ADR-0009はSeverityの判断を変更し、それ以外のADR-0006の決定を維持した。

RS-0024でLogs境界と具体的な失敗の扱いを検討すると、利用者向け表現、実験結果、Telemetryは同じ種類の変換先ではないことが明確になった。CLI / APIは利用者へ返す表現を作る責務、実験結果は実験・評価領域が保存・比較するドメインデータ、Telemetryは処理を観測する責務を持つ。これらを「具体的な失敗型の変換先」として横並びにすると、実験外のUseCaseの失敗まで実験結果へ保存するように読め、どの処理の最終失敗を実験の成功率・タイムアウト率へ含めるかも曖昧になる。

また、旧共通`AppError`で使用していた`Input`、`Resource`、`Data`、`Dependency`、`Timeout`、`Internal`のような共通分類は、失敗の原因、発生場所、時間的性質など異なる観点を1つの分類へ混ぜる。RAGScopeアプリケーションでは、各処理の呼び出し側が必要な扱いを、その処理の具体的な失敗から決める方が、型と責務を一致させやすい。

## 決定

1. RAGScopeアプリケーションのUseCaseや内部処理は、その処理が結果を作れなかったときに呼び出し側が必要な扱いを行えるよう、具体的な失敗型を持つ。アプリケーション全体の失敗を1つの`AppError`、`RAGScopeError`、共通`ErrorCategory`へ正規化しない。UseCaseまたは内部処理がその処理の契約として具体的な失敗型の値で呼び出し元へ伝える失敗は、[RAGScope用語集](../RAGScope用語集.md#処理失敗)で定義する`処理失敗`として扱う。
2. HTTP client、DB driver、SDKなど外部library固有のerror値や例外は、外部依存へ接続するAdapterで利用側の具体的な処理失敗へ変換する。ただし、対象libraryの契約で想定されている既知のerror値や同期例外だけを変換対象とし、async exceptionや意図された中断・キャンセルは処理失敗へ変換しない。想定外例外も既知の失敗constructorへ一律に押し込まない。
3. retry、timeout、fallback、継続・終了という実行制御はRAGScopeアプリケーションコンポーネントが所有する。コンポーネント内部のどのUseCase、module、処理が実際の判断と実行を担当するかは対象機能の設計で決める。UseCaseの失敗は、そのUseCase実行に適用される実行制御を経ても定義した結果を作れなかった場合の[最終失敗](../RAGScope用語集.md#最終失敗)を表す。
4. UseCase専用の失敗型を形式上必須にはしない。[内部処理の失敗](../RAGScope用語集.md#内部処理の失敗)をUseCaseの最終失敗としてそのまま利用できるのは、その型がUseCase呼び出し側へ公開する意味を持ち、その型を定義するmodule / private libraryへの静的依存が妥当であり、UseCaseの内部実装詳細を漏らさない場合に限る。単に失敗が1種類だけであることは十分な理由としない。
5. CLI / API、実験・評価、Telemetryは、共通error表現の同種の変換先として扱わない。CLI / APIは利用者向け表現を作り、実験・評価は自身が実行した処理の最終結果から実験の実行結果として保存する情報を決め、Telemetryは観測に必要なSpan Status、`error.type`、属性などを作る。
6. 実験結果へ任意の失敗をまとめて保存しない。評価データごとの実行結果へどの失敗を保存し、成功率・タイムアウト率へどの最終結果を含めるかは、実験・評価側の設計で決める。retry途中だけで回復した内部処理の失敗、実験が呼び出していない処理の失敗、Telemetryの失敗を自動的に実験結果へ含めない。
7. Telemetry用の`error.type`は具体的な失敗から作る観測用の表現であり、元の失敗を置き換えない。失敗型を定義するmoduleへTelemetry都合の責務を持たせず、汎用のTelemetry boundaryやOpenTelemetry Adapterから個別のFeature private libraryで定義するUseCaseまたは内部処理の失敗型へ依存させない。具体的な変換moduleやprivate libraryは、実際のimportと`build-depends`を確認して各機能の実装時に決める。Telemetryの記録・export失敗だけを理由に、成功した観測対象の処理結果またはUseCase実行結果を失敗へ変更しない。
8. DIのためだけにアプリケーション全体の`AppError` type classを設けない。複数の失敗型へ同じ操作を多相的に適用する必要が実際に生じた場合は、retry判断など必要な操作だけを表す狭い契約を、その用途の設計で検討する。
9. ADR-0009で採用した`Debug`、`Info`、`Warn`、`Error`の4段階Severityと、そのほかADR-0006から維持されたObservabilityの決定は変更しない。本ADRは、ADR-0009がADR-0006から引き継いでいた失敗の扱いを本ADRの決定へ置き換える。

## 検討した選択肢

### アプリケーション共通の`AppError`へ正規化する

CLI / API、実験、Telemetryなど複数の利用先で同じ型を扱いやすい。一方、処理固有の失敗を共通分類へ早い段階で潰すと、retryやfallbackなど呼び出し側が必要とする情報と、利用者向け表示やTelemetryが必要とする情報を1つの型へ混ぜやすい。外部依存や新機能が増えるほど共通型が機能間の静的な結合点になるため採用しない。

### 具体的な失敗からCLI / API、実験結果、Telemetryへ一律に直接変換する

共通`AppError`を作らずに済み、ADR-0006の方針をそのまま維持できる。一方、実験結果は任意の失敗の表示形式ではなく、実験・評価領域が意味を持たせるドメインデータである。実験外の失敗まで変換先として見えてしまい、評価対象の処理失敗と事前準備・実験基盤・Telemetryの失敗を区別できないため採用しない。

### 処理単位の具体的な失敗を保ち、利用側の責務を分ける

UseCaseや内部処理は呼び出し側が必要とする具体的な処理失敗を返し、外部library固有の失敗はAdapterで変換する。CLI / API、実験・評価、Telemetryはそれぞれの責務に必要な情報だけを具体的な処理失敗または処理の最終結果から作る。

失敗の意味を処理の境界に保ったまま、利用者向け表現、ドメインデータ、観測情報を分離できる。feature libraryから具体的なAdapterや外部packageへの不要な依存も避けやすいため、この案を採用する。

## 結果と影響

- 現在の失敗の扱いは[RAGScopeアプリケーション失敗設計](../design/RAGScopeアプリケーション失敗設計.md)を正本とする。
- Observability設計から、CLI / APIと実験結果をTelemetryと同列の失敗変換先として扱う記述を外す。
- 個別featureの設計・実装では、必要な具体的な失敗型と、外部依存からその処理失敗へ変換するAdapter境界を定める。
- 実験・評価の設計では、評価データごとの実行結果として保存する失敗と、成功率・タイムアウト率へ含める最終結果を具体化する。これらをObservability設計や本ADRで先取りしない。
- async exceptionや意図された中断・キャンセルは処理失敗へ変換せず、対象runtimeと機能の実行制御に従って扱う。
- ADR-0009は`superseded`とする。ADR-0009で決めたSeverityの4段階と、ADR-0006から引き継いだ本ADRと衝突しないObservabilityの決定は維持する。
- 正確なHaskellの型、constructor、module、private libraryの依存はコード、`ragscope.cabal`、テストを機械可読な正本とする。

## 関連文書

- [RAGScope用語集](../RAGScope用語集.md)
- [RAGScope要求定義](../RAGScope要求定義.md)
- [RAGScopeアプリケーション失敗設計](../design/RAGScopeアプリケーション失敗設計.md)
- [ユースケース設計](../design/ユースケース設計.md)
- [Observability設計](../design/observability/Observability設計.md)
- [ADR-0008 — RAGScopeアプリケーションの機能実装をprivate libraryへ分け、main libraryをFacadeとする](<./ADR-0008 RAGScopeアプリケーションの機能実装をprivate libraryへ分け、main libraryをFacadeとする.md>)
- [ADR-0009 — RAGScopeのLogs SeverityをDebug・Info・Warn・Errorに限定する](<./ADR-0009 RAGScopeのLogs SeverityをDebug・Info・Warn・Errorに限定する.md>)
