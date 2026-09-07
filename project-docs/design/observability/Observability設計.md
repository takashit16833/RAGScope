---
note_type: design
---
# Observability設計

> [!abstract] この文書の役割
> OpenTelemetryをRAGScopeのObservability共通基盤としてどこまで使用し、Trace・Logs・Metricsをどう分担し、RAGScopeとOpenTelemetryの責務をどこで分けるかを定義する。

## 1. 基本方針

RAGScopeはOpenTelemetryをObservabilityの共通基盤として使用する。Trace、Logs、Metricsは同じ実行を観測するために連携させるが、同じ情報を3種類へ重複して記録するためには使用しない。

| Signal / 保存先 | RAGScopeで担当すること |
|---|---|
| Trace / Span | 1回の実行内の処理のつながり、親子関係、所要時間、各処理自身の最終結果を確認する |
| Logs | Spanだけでは表せない、名前を持つ時点イベントや状態遷移と、必要な診断情報を記録する |
| Metrics | 複数回の実行をまたいで集約した時間・回数・分布などを観測する |
| 実験結果 | 1件の評価データについて再評価や比較に必要な正確な結果・性能値を保存する |

実験結果はTelemetryではなくRAGScopeのドメインデータである。Metricsから個別実行の正確な値を復元することを前提にしない。

## 2. RAGScopeとOpenTelemetryの責務境界

RAGScopeアプリケーションは、処理順序、再試行、タイムアウト、fallback、処理継続・終了を決定する。Telemetryはこれらを観測するが、処理制御を決定しない。AI推論サービスも、RAGScopeアプリケーションから依頼されたモデル・Tokenizer依存の処理結果を返し、Telemetryを理由に機能処理の結果を変更しない。

OpenTelemetryのSemantic Conventionが対象の処理・イベント・Metricに適用できる場合は、その名前、属性、Status、`error.type`、Metricを優先する。RAGScope独自のSpan、EventRecord、属性、Metricを、同じ意味を重複して表す目的では追加しない。

RAGScopeのUseCaseや内部処理を実装するmoduleは、OpenTelemetry SDKを直接利用することを前提にしない。RAGScope側にはTelemetryを使用する境界を置き、その外側のOpenTelemetry AdapterがSDKへ接続する。具体的なpackage、module、型、関数名、公開APIは実装時のコードを正本とする。

OpenTelemetry SDKへ次を委ねる。

- Contextの保持と伝播
- Span / LogRecord / MetricのSDK上の記録
- Processor / Exporter
- batching
- flush / shutdown
- Telemetryの送信

RAGScope独自のLogging Runtime、Sink、送信キューなど、OpenTelemetry SDKと同じ責務の実行基盤は設けない。

## 3. 失敗の扱い

RAGScope共通の`RAGScopeError`やObservability専用の共通エラー分類は設けない。UseCaseや内部処理が持つ具体的なerror typeから、必要な利用境界へ直接変換する。

```text
具体的なUseCase / 内部処理のerror type
├─ RAGScope API / CLIの利用者向け表現
├─ 実験結果へ保存する失敗表現
└─ Telemetryのerror.type
```

RAGScope独自SpanやEventRecordで`error.type`が必要な場合は、具体的なerror typeの値から予測可能で低cardinalityな値へ変換する。詳細な失敗理由やcauseを`error.type`へ詰め込まず、元の具体的なerror値を失わない。

Telemetryの記録・export失敗は、成功していた機能処理を機能上の失敗へ変更しない。Telemetry基盤自身の失敗を、失敗した同じTelemetry経路へ再帰的に記録しない。具体的なSDK呼び出しの失敗処理とshutdown時の扱いは、各コンポーネントの実装・設定・テストを正本とする。

## 4. ローカルでの確認

ローカルで採用するTelemetry backendは次のとおりである。

- Trace: Tempo
- Logs: Loki
- Metrics: Prometheus
- 横断的な検索・可視化: Grafana

RAGScopeアプリケーションとAI推論サービスはOpenTelemetryでTelemetryを生成し、同じTrace Contextを利用してコンポーネント境界をまたぐ処理を関連付ける。ローカル環境のコンポーネント配置は[システムアーキテクチャ](../システムアーキテクチャ.md)を正本とする。

consoleなどのExporterは開発・テスト時の補助確認に使用してよいが、ローカルで一連のTelemetryを確認する主たるbackendにはしない。

## 5. この設計で固定しないもの

次は、Observability全体の意味・責務を変えず、具体的な実装または配置を行う時点で決定する。

- Collectorを配置するかどうかと、その具体的な配置
- SDKからbackendまでの具体的な送信経路・protocol設定
- production環境のTelemetry backend、保持期間、冗長化、運用設定
- Haskell / Pythonで使用する具体的なpackage version、module構成、型、関数
- 機能固有のSpan、EventRecord、属性、具体的なerror typeの変換値

## 関連文書

- [実行追跡設計](./実行追跡設計.md)
- [ログ・イベント設計](./ログ・イベント設計.md)
- [Metrics設計](./Metrics設計.md)
- [システムアーキテクチャ](../システムアーキテクチャ.md)
- [ユースケース設計](../ユースケース設計.md)
- [RAGScope要求定義](../../RAGScope要求定義.md)
