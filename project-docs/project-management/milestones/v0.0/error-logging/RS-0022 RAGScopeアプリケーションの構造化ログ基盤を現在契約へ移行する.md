---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 共通エラーと構造化ログによる実行追跡]]"
---
# RS-0022 RAGScopeアプリケーションの構造化ログ基盤を現在契約へ移行する

## 目的

RS-0015で実装したRAGScopeアプリケーションの`ragscope-logging`は、`ExecutionId`、`EventId`、`EventContext`、`OperationName`、通常イベントと失敗イベントの直和、`LogErrorCategory`、`ErrorCode`、`SafeMessage`など、現在の実行追跡・構造化ログ契約で置き換えられた旧論理モデルを表現している。JSON backendも同じ旧構造を既存JSON Schemaへ投影している。

[RS-0020 共通エラー・構造化ログの論理契約を再設計する](<./RS-0020 共通エラー・構造化ログの論理契約を再設計する.md>)で、1回のユースケース実行をOpenTelemetryの`trace`・`span`で追跡し、構造化ログを`TraceId`・`SpanId`で対応する`span`へ関連付ける現在契約を確定した。失敗理由は`error_type`で識別し、ログでは他の属性と同じ属性として記録する。イベント名、重要度、任意の`message`、`attributes`は互いに独立した論理情報として扱う。

このTicketでは、既存のHaskell logging基盤を現在の実行追跡・構造化ログ契約と共有JSON Contractへ追随させ、後続の機能実装が旧論理モデルへ依存せず利用できる状態にする。

## 前提

- [RS-0020 共通エラー・構造化ログの論理契約を再設計する](<./RS-0020 共通エラー・構造化ログの論理契約を再設計する.md>)が完了し、現在の実行追跡・構造化ログ設計がデフォルトブランチへ反映されている
- [RS-0021 構造化ログJSON Schemaとfixtureを現在契約へ更新する](<./RS-0021 構造化ログJSON Schemaとfixtureを現在契約へ更新する.md>)が完了し、共有JSON Contractが現在のJSON表現へ更新されている

## 完了条件

### 現在の論理契約への移行

- [ ] RAGScopeアプリケーションの構造化ログ1件を、発生時刻、発生元、イベント名、重要度、任意の`message`、任意の`attributes`、`TraceId`・`SpanId`という現在契約の情報として扱える
- [ ] `TraceId`・`SpanId`によって、構造化ログを対応するOpenTelemetry `span`へ関連付けられる
- [ ] イベント名と重要度を独立して扱え、`debug`、`info`、`warn`、`error`、`fatal`の5段階を表現できる
- [ ] `attributes`が現在の論理契約で定めるstring、number、boolean、array、objectを再帰的に扱え、論理上の`null`を導入しない
- [ ] 失敗をログで報告する場合、`error_type`を専用の共通エラーobjectではなく通常の属性として記録できる
- [ ] 同じ失敗を`span`と構造化ログの両方へ記録する境界で、同じ`error_type`を使用できる
- [ ] `ExecutionId`、`EventId`、`EventContext`、`OperationName`、通常イベントと失敗イベントの直和、固定`failed`イベント、重要度と失敗の結合など、現在契約が採用しない旧論理モデルを共通logging基盤の前提として残していない
- [ ] 既存の`AppError`などlogging以外の失敗表現は、現在の`error_type`設計と各利用境界の責務に照らして必要性を再評価し、旧共通エラー契約を維持するためだけの構造を残していない

### JSON出力と共有Contract

- [ ] HaskellのJSON serializationが現在の[構造化ログJSON表現設計](../../../../design/logging/構造化ログJSON表現設計.md)へ投影する実装になっている
- [ ] JSON出力がRS-0021で更新した共有JSON Schemaへ適合することを自動テストで確認できる
- [ ] `message`と`attributes`の省略、空文字列・空array・空objectの保持、属性値の再帰構造など、現在のJSON表現に必要な主要境界をテストで確認できる
- [ ] 構造化ログをstderrへ出力する場合、1ログ1JSON objectを1物理行へUTF-8で出力し、JSON以外の接頭辞や説明文を付加しない

### 実装境界と検証

- [ ] 機能固有の閉じたイベント表現から共通logging表現へ変換でき、共通基盤が機能固有イベント名、属性、`error_type`を任意に決定しない
- [ ] loggingのRuntimeやSinkをテストから差し替えられ、実ログ出力を必要とせず共通logging境界を検証できる
- [ ] stderr、memoryなど既存の差し替え可能なSink構造は、現在契約と衝突しない範囲で維持または同等の境界へ置き換えられている
- [ ] ログ基盤自身の失敗を、失敗した同じログ経路へ再帰的に記録しない
- [ ] コンポーネント固有の正確な内部型、発生元の値、OpenTelemetry利用方法、ログ受付・出力境界、設定、ログ基盤自身の失敗処理をコード・設定・Schema・テストの正本へ置き、専用のRAGScopeアプリケーション構造化ログ設計書を作成していない
- [ ] 関係するHaskellテスト、Schema適合テスト、プロジェクトの品質検査を実行し、追加・更新したテストを含めて成功する
- [ ] Haskell実装、共有JSON Contract、現在の実行追跡・構造化ログ設計の間に未解消な差異がない

## 対象外

- 機能固有の子`span`、ログイベント、属性、`error_type`をこのTicketで先行して決定すること
- 文書処理など各機能へ具体的なログイベントや`error_type`を適用すること
- AI推論サービスのPython logging基盤を実装すること
- HTTPやCLIの利用者向けエラー表現を決定すること
- OpenTelemetry Collector、CloudWatchなどの運用基盤を構築すること
- SQLiteを本番向け外部表現として実装すること

## 関連文書

- [RS-0015 RAGScopeアプリケーションの共通エラー・構造化ログ基盤を実装する](<./RS-0015 RAGScopeアプリケーションの共通エラー・構造化ログ基盤を実装する.md>)
- [RS-0020 共通エラー・構造化ログの論理契約を再設計する](<./RS-0020 共通エラー・構造化ログの論理契約を再設計する.md>)
- [RS-0021 構造化ログJSON Schemaとfixtureを現在契約へ更新する](<./RS-0021 構造化ログJSON Schemaとfixtureを現在契約へ更新する.md>)
- [実行追跡・構造化ログ契約設計](../../../../design/logging/実行追跡・構造化ログ契約設計.md)
- [構造化ログ外部表現共通設計](../../../../design/logging/構造化ログ外部表現共通設計.md)
- [構造化ログJSON表現設計](../../../../design/logging/構造化ログJSON表現設計.md)
- [ADR-0005 — 実行追跡をOpenTelemetryのtrace・spanで表現し、イベントを構造化ログとして記録する](<../../../../adr/ADR-0005 実行追跡をOpenTelemetryのtrace・spanで表現し、イベントを構造化ログとして記録する.md>)

## 実装メモ

共通logging基盤をprivate sublibraryとして機能実装から分離すること、機能固有の閉じたイベントから共通loggingへ変換する境界、時刻やSinkを注入するRuntime、JSON serializationを共通モデルから分離する境界、Sinkを差し替える構造は、現在契約と衝突しないため維持候補とする。正確な型・module構成は既存構造を機械的に維持せず、実装時にコードとテストで決定する。

ログ基盤自身の出力・serialization失敗を機能失敗とどう組み合わせるかは、現在の共通論理契約では一律に定めない。RAGScopeアプリケーション固有の実装境界として、利用箇所と既存挙動を確認したうえでコードとテストを正本として確定する。

## 結果

> [!note] 完了時に記入
> - 移行したHaskell logging基盤
> - 実装したOpenTelemetryによる実行追跡・ログ関連付け
> - 更新したJSON serializationとSchema適合結果
> - 維持・変更・削除した旧logging構造
> - 実行したテスト・品質検査と結果
> - 既知の制約
> - 関連Pull Request
