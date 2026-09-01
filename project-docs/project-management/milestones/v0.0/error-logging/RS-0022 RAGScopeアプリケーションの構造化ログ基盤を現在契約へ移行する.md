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

このTicketでは、既存のHaskell logging基盤を現在の実行追跡・構造化ログ契約へ追随させ、同じ共通モデルからJSONとSQLiteの双方へ投影できる状態にする。JSONとSQLiteを同時に実装することで、JSON固有の型、項目、serializationの都合が共通logging契約や`LogRecord`へ漏れ込んでいないことを実装とテストで検証する。既存module構成や公開APIを前提として局所修正せず、RAGScopeアプリケーションから見た責務、利用インターフェースとの実行追跡境界、Cabal package・library・module間の依存とデータの流れを先に設計し、その全体像を基準に実装を置き換える。loggingの境界を自然にするために必要であれば、`Observation`、`Result`、`AppError`など既存の周辺moduleも変更または削除の対象に含める。

OpenTelemetryはRAGScopeの要求や論理契約を決める正本ではない。RAGScopeが必要とする実行追跡を実現するために、OpenTelemetryの`trace`・`span`などの設計と実装を利用する。OpenTelemetry側の都合だけを理由にRAGScope固有の契約、責務、公開APIを追加または変更しない。

## 前提

- [RS-0020 共通エラー・構造化ログの論理契約を再設計する](<./RS-0020 共通エラー・構造化ログの論理契約を再設計する.md>)が完了し、OpenTelemetryの`trace`・`span`による実行追跡と構造化ログの基本契約が導入されている
- [RS-0021 構造化ログJSON Schemaとfixtureを現在契約へ更新する](<./RS-0021 構造化ログJSON Schemaとfixtureを現在契約へ更新する.md>)が完了している。RS-0022で論理契約を追加修正した場合は、同じ作業branchで共有JSON Contractも現在契約へ追随させる

## 現在確定した実装境界

- `error_type`をHaskellで表す`ErrorType`と、失敗値だけから`ErrorType`へ変換する`ToErrorType`は、共通local package `ragscope-error`のpublic main libraryにある`RAGScope.ErrorType`で定義する。`ragscope-error`はLogging、Tracing、Observability、Feature固有failureのいずれにも所有させない。
- 各FeatureのUseCase failureは`RAGScope.<Feature>.Failure`で定義し、その型に対する`ToErrorType` instanceも同じmoduleに置く。これにより`ToErrorType` instanceをorphanにせず、`ragscope-features`から`ragscope-error`への一方向依存とする。
- `ErrorType`を必要とする公開境界は、具体的なFeature failure型へ固定せず、`ToErrorType failure => failure`を受け取って境界内で`toErrorType`を適用できる形とする。その下位層には変換後の`ErrorType`だけを渡す。ユースケース実行`span`と利用者操作全体のroot `span`は表す処理が異なるため、Feature failureをroot `span`の失敗へ直接対応付ける旧前提は置かない。`ToErrorType`をどのObservability公開APIで適用するかは、現在の実行追跡境界に合わせてこのTicketで設計・実装する。
- 利用インターフェースが1回のトップレベルな操作について操作固有処理を開始する境界から、その操作の処理を完了または失敗として終了して外側へ制御を戻す境界までを1つの`trace`として扱える公開境界を設ける。routing・command判定、入力変換・検証、ユースケース呼び出し、ユースケース後の結果処理は、その操作に属する限り同じroot `span`の時間区間に含められるようにする。
- RAGScope Applicationがユースケースを呼び出した場合、その呼び出しからApplicationへ制御が戻るまでをroot `span`配下のユースケース実行`span`として追跡できるようにする。routingや入力検証で操作が終了してユースケースを呼び出さない場合は、ユースケース実行`span`を作らない。
- ユースケース失敗ログはFeature固有eventとして表す。検索機能であれば`SearchEvent`のユースケース失敗を表すconstructorを使い、Logging側は他のFeature eventと同様に`ToLogSpec SearchEvent`を通して`LogSpec`へ変換する。ユースケース失敗イベントはユースケース実行`span`へ関連付け、親やrootへ失敗が伝播したという理由だけで同じ失敗ログを重複して記録しない。具体的なconstructor名と保持する値は各Featureの設計・実装で確定する。
- 構造化ログの共通表現は、trace内ログとtrace外ログの両方を同じlogging基盤で扱えるようにする。特定の`span`へ属するログは`TraceId`・`SpanId`を組で持ち、特定の`span`へ属さないログは両方を持たない。片方だけを持つ状態は表現しない。
- `Port`はmodule名のsuffixではなく設計上の役割を表す語として使う。呼び出し側が必要とする抽象操作を定義し、具体実装を境界の向こう側で差し替える箇所をPortと呼ぶ。`RAGScope.Tracing`はObservability Runtimeが要求するspan操作を定義し、`RAGScope.Tracing.OpenTelemetry`がその具体実装となるためTracing Portと呼ぶ。`RAGScope.Observability`は利用インターフェース・Application・Featureから必要な実行追跡操作を利用するObservability Effect API、`RAGScope.Logging.Write`はLoggingの公開APIと呼び、単なる公開境界を一律にPortとは呼ばない。正確なAPI分割は現在のroot `span`とユースケース実行`span`の責務に合わせてこのTicketで確定する。

## 完了条件

### 現在の論理契約への移行

- [ ] RAGScopeアプリケーションの構造化ログ1件を、発生時刻、発生元、イベント名、重要度、任意の`message`、任意の`attributes`、条件付きの`TraceId`・`SpanId`という現在契約の情報として扱える
- [ ] 特定の`span`中で起きた構造化ログは`TraceId`・`SpanId`を組で持ち、対応するOpenTelemetry `span`へ関連付けられる。特定の`span`へ属さない構造化ログは両方を持たず、片方だけを持つ状態を作らない
- [ ] 利用インターフェースが受け付けた1回のトップレベルな操作を1つの`trace`として追跡し、routing・command判定、入力変換・検証、ユースケース呼び出し、ユースケース後の結果処理をその操作に属する範囲でroot `span`に含められる
- [ ] ユースケースを呼び出した場合はその実行をroot `span`配下の子`span`として追跡し、ユースケースを呼び出さず操作が終了した場合はユースケース実行`span`を作らない
- [ ] root `span`とユースケース実行`span`のSpan Status・`error_type`を、それぞれが表す処理自身の最終結果から独立して決められる
- [ ] コンポーネントの起動・終了など、特定の利用者操作へ属さないイベントを同じlogging基盤へtrace外ログとして渡せる
- [ ] イベント名と重要度を独立して扱え、`debug`、`info`、`warn`、`error`、`fatal`の5段階を表現できる
- [ ] `attributes`が現在の論理契約で定めるstring、number、boolean、array、objectを再帰的に扱え、論理上の`null`を導入しない
- [ ] 失敗をログで報告する場合、`error_type`を専用の共通エラーobjectではなく通常の属性として記録できる
- [ ] 同じ失敗を`span`と構造化ログの両方へ記録する境界で、同じ`error_type`を使用できる
- [ ] 子`span`の失敗が親やrootへ伝播しただけでは同じ失敗ログを階層ごとに重複記録せず、その失敗を意味として所有する処理または境界で1件記録できる
- [ ] `ExecutionId`、`EventId`、`EventContext`、`OperationName`、通常イベントと失敗イベントの直和、固定`failed`イベント、重要度と失敗の結合など、現在契約が採用しない旧論理モデルを共通logging基盤の前提として残していない
- [ ] 既存の`AppError`などlogging以外の失敗表現は、ユースケース境界と1回の利用者操作全体の境界を区別したうえで必要性を再評価し、旧共通エラー契約を維持するためだけの構造を残していない

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
- [ ] logging・tracing・observabilityなど独立した責務を別Cabal packageへ分ける場合、同一`cabal.project`内のlocal packageとして構成し、許可するpackage間依存を`build-depends`へ明示して循環や逆向き依存を作っていない
- [ ] 既存の`ragscope-logging`、`Observation`、`Result`、`AppError`の構造を維持すること自体を要件とせず、現在契約とRAGScopeアプリケーションの責務から必要性を判断している
- [ ] OpenTelemetryのAPIや内部表現の都合をRAGScope固有の論理契約や公開APIへ不要に持ち込まず、RAGScopeが採用した実行追跡を実現する境界として利用している
- [ ] 機能固有の閉じたイベント表現から共通logging表現へ変換でき、共通基盤が機能固有イベント名、属性、`error_type`を任意に決定しない
- [ ] Feature event、利用インターフェース固有event、アプリケーションライフサイクルeventなど、所有者の異なるeventを同じ共通logging境界へ渡せる一方、共通logging基盤がそれらの具体的なevent名・属性・`error_type`を所有しない
- [ ] JSON / SQLite固有の型、依存package、field / table / column、serialization / persistence処理をそれぞれの外部表現moduleへ閉じ、共通logging層を特定の外部表現へ依存させていない
- [ ] loggingのRuntimeやSinkをテストから差し替えられ、実ログ出力を必要とせず共通logging境界を検証できる
- [ ] stderr、memoryなど既存の差し替え可能なSink構造は、現在契約と衝突しない範囲で維持または同等の境界へ置き換えられている
- [ ] ログ基盤自身の失敗を、失敗した同じログ経路へ再帰的に記録しない
- [ ] コンポーネント固有の正確な内部型、発生元の値、OpenTelemetry利用方法、ログ受付・出力境界、設定、ログ基盤自身の失敗処理をコード・設定・Schema・migration・テストの正本へ置き、専用のRAGScopeアプリケーション構造化ログ設計書を作成していない
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
- [実行追跡・構造化ログ契約設計](../../../../design/logging/実行追跡・構造化ログ契約設計.md)
- [構造化ログ外部表現共通設計](../../../../design/logging/構造化ログ外部表現共通設計.md)
- [構造化ログJSON表現設計](../../../../design/logging/構造化ログJSON表現設計.md)
- [構造化ログSQLite表現設計](../../../../design/logging/構造化ログSQLite表現設計.md)
- [ADR-0005 — 実行追跡をOpenTelemetryのtrace・spanで表現し、イベントを構造化ログとして記録する](<../../../../adr/ADR-0005 実行追跡をOpenTelemetryのtrace・spanで表現し、イベントを構造化ログとして記録する.md>)

## 実装メモ

最初に、利用側から見たloggingの公開API、Cabal package・library・moduleごとの責務と依存方向、中心となる型、利用者操作root `span`・ユースケース実行`span`・内部`span`の関係、trace内ログとtrace外ログ、Runtime・Sink・JSON / SQLite外部表現・テスト境界、logging自身の失敗とアプリケーション実行の関係を一つの全体像として設計する。実装はその全体像を基準に進め、既存moduleへ変更を積み重ねながら後から構造を決める進め方はしない。

logging・tracing・observabilityなど独立した責務は、既存の1 package内private sublibraryへ閉じることを前提にせず、別Cabal packageとして分離することを第一候補とする。これらは別repositoryや外部公開を意味せず、`ragscope-app`配下の同一`cabal.project`から複数のlocal packageをまとめて扱う。package境界では`build-depends`によって大きな依存方向を機械的に制約し、各packageの内側では必要に応じてpublic / private libraryと`exposed-modules` / `other-modules`を使って公開範囲をさらに絞る。packageを分けること自体を目的にはせず、独立した責務・公開API・依存方向として分離する意味が薄い境界は設計の中で統合してよい。

機能固有の閉じたイベントから共通loggingへ変換する境界、時刻やTrace Contextなど実行時情報を付加する境界、JSON serializationとSQLite投影を共通モデルから分離する境界、Sinkを差し替える構造は維持候補とする。ただし、いずれも既存構造を残すこと自体を目的とせず、先に設計した全体像の中で責務が自然に分かれる場合だけ採用する。Trace Contextはすべてのログへ要求せず、特定の`span`へ属するログだけに`TraceId`・`SpanId`を組で付加する。JSONとSQLiteは同じ`LogRecord`から独立して投影し、片方の表現都合を共通モデルへ持ち込まなければもう片方を実装できない構造を避ける。

`Observation`、`Result`、`AppError`を含む既存の周辺moduleは、このTicketの変更範囲外として固定しない。ユースケース実行結果と利用者操作全体の結果を同一視せず、loggingの公開境界、root `span`とユースケース実行`span`、失敗の確定、ログ基盤自身の失敗処理を一貫した構造にするために必要であれば、責務の変更、統合、分割、削除を行う。

OpenTelemetryは、RAGScopeが採用した実行追跡を実装するための手段として利用する。`trace`・`span`・Contextなど利用する概念やHaskell実装上のAPIは確認するが、OpenTelemetryに存在する概念や制約をそのままRAGScopeの要求へ昇格させない。

ログ基盤自身の出力・serialization・persistence失敗を、利用者操作全体の失敗やユースケース失敗とどう組み合わせるかは、現在の共通論理契約では一律に定めない。RAGScopeアプリケーション固有の実装境界として、利用箇所と既存挙動を確認したうえでコードとテストを正本として確定する。失敗したlogging経路自身へ同じlogging経路を使って再帰的に失敗を記録しない。

RS-0021完了後にRS-0022の設計検討で共有JSON Contractを追加修正しているため、`SchemaSpec.hs`は現在のfixture名とSchemaへ追随させる。共有fixtureにはtrace内ログ、trace外ログ、`trace_id`だけまたは`span_id`だけを持つ不正ログを含め、現在のHaskell `LogRecord`生成JSONが同じ契約へ適合することを確認する。

## 結果

> [!note] 完了時に記入
> - 移行したHaskell logging基盤
> - 実装したOpenTelemetryによる利用者操作単位の実行追跡とログ関連付け
> - 更新したJSON serializationとSchema適合結果
> - 実装したSQLite投影・復元と往復検証結果
> - 維持・変更・削除した旧logging構造
> - 実行したテスト・品質検査と結果
> - 既知の制約
> - 関連Pull Request