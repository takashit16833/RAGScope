---
note_type: design
---
# Metrics設計

> [!abstract] この文書の役割
> RAGScopeの実験結果、Trace / Span、OpenTelemetry Metricsの役割を分け、どの性能情報をどこで扱うかを定義する。

## 1. 役割分担

| 情報 | 正本・観測手段 |
|---|---|
| 1件の評価データについて再評価・比較に必要な正確な値 | 評価データごとの実行結果 |
| 1回のInvocation内部の処理時間と親子関係 | Trace / Span |
| 複数回の実行をまたぐ時間・回数・分布の集約 | OpenTelemetry Metrics |

Metricsは実験結果を置き換えない。個別の実行結果をMetricsから復元することを前提にしない。

## 2. Metricの選択

RS-0023の共通設計ではRAGScope独自Metricを定義しない。HTTP、PostgreSQL、GenAIなどOpenTelemetry Semantic Conventionで利用できる標準Metricがあり、実装から必要な値を取得できる場合はそのMetricを使用する。

実験ID、評価データID、文書ID、文書チャンクID、TraceId、SpanIdのように、実行ごとにほぼ異なる値になる識別子はMetric attributesへ付与しない。こうした値を入れると、Metricが実行ごとに異なる属性値の組み合わせを大量に持つことになり、high cardinalityになるためである。

## 3. 性能値の配置

| 性能値 | 評価データごとの実行結果 | Trace / Span | Metrics |
|---|---|---|---|
| 検索全体の処理時間 | 正確な値を保存する | 対応する処理Spanで確認する | 共通のRAGScope独自Metricは作らない |
| `reranking`全体の処理時間 | 正確な値を保存する | 対応する処理Spanで確認する | 共通のRAGScope独自Metricは作らない |
| 回答生成全体の処理時間 | 正確な値を保存する | 対応する処理Spanで確認する | HTTP / GenAIの標準Metricが適用できる部分だけ利用する |
| TTFT | 1件ごとの正確な値を保存する | 生成開始から最初のtoken生成までをTrace上でも確認できる情報を保持する | 適用できる場合は`gen_ai.server.time_to_first_token`を使用する |
| 生成token数 | 1件ごとの正確な値を保存する | 必要なSpan属性が標準規約で定義される場合は従う | 正確な値を取得できる場合は`gen_ai.client.token.usage`を使用する |
| DB client処理時間 | 実験上必要な場合だけ結果として保存する | DB client Span | `db.client.operation.duration`が適用できる場合に利用する |
| HTTP client処理時間 | 実験上必要な場合だけ結果として保存する | HTTP client Span | `http.client.request.duration`が適用できる場合に利用する |

TTFTをTrace / Span上でどの属性として表すかは、この共通設計では固定しない。機能固有のSpanや属性を設計するときに、適用できるOpenTelemetry Semantic Conventionと実装から取得できる値を確認して決定する。

TTFTの実験上の正確な値は、AI推論サービスが生成を開始してから最初のtokenを生成するまでを基準とし、RAGScopeアプリケーションが最初のHTTP chunkを受信するまでの時間とは区別する。AI推論サービスからこの値やtoken数をどの通信項目で返すかは、回答生成通信を設計するときの機械可読な契約で定義する。

## 4. 後続で決定するもの

runtime、host、acceleratorなどのMetricは、具体的な監視要求と配置が確定した時点で必要性を判断する。将来必要になる可能性だけを理由に共通Metricやattributesを先行定義しない。

## 関連文書

- [Observability設計](./Observability設計.md)
- [実行追跡設計](./実行追跡設計.md)
- [RAGScope要求定義](../../RAGScope要求定義.md)
- [システムアーキテクチャ](../システムアーキテクチャ.md)
