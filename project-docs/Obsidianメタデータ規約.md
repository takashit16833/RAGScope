---
note_type: reference
---
# Obsidianメタデータ規約

> [!abstract] この文書の役割
> RAGScopeのObsidian Vaultで使用するFrontmatterのプロパティ、型、許容値を定義する。  
> 文書の配置と責務は[RAGScope文書管理規約](./RAGScope文書管理規約.md)、Milestone・Epic・Ticketの運用は[RAGScopeプロジェクト管理規約](./RAGScopeプロジェクト管理規約.md)に従う。

## 1. 適用範囲

次の場所にある、人が管理するMarkdownノートへ適用する。

```text
- Vault直下の各種規約文書
- `docs/`
- `project-management/`
```

リポジトリルートの`README.md`と`.github/`配下のGitHub用ファイル、RAGScopeが機械的に生成する`reports/`配下の出力、`templates/`配下のObsidianテンプレート、その他の外部ツールが管理するファイルには適用しない。

`templates/`配下のMarkdownは、ノートへ挿入するFrontmatterと本文の雛形であり、テンプレートファイル自体をMilestone・Epic・Ticketとして管理しない。

## 2. 絶対規則

> [!important] 許可リスト
> **本規約に定義されたプロパティと許容値だけを使用する。**

- 利用する検索・一覧・絞り込み・自動処理が存在しないプロパティは追加しない。
- 必要性を認識した場合でも、未登録のプロパティや許容値をファイルへ追加してはならない。
- 未登録項目が必要な場合は、理由と影響範囲を示し、承認を得て本規約を先に変更する。

## 3. プロパティ定義

| プロパティ | 型 | 使用条件 | 許容値・形式 |
|---|---|---|---|
| `aliases` | List | 実際に別名リンク・検索を使用する場合のみ | 文字列のリスト |
| `note_type` | Text | 管理対象ノートで必須 | 3.1で定義した値 |
| `status` | Text | ADR・Milestone・Epic・Ticketで必須 | 3.2で定義した値 |
| `milestone` | Text | Epic・Ticketで必須 | 所属MilestoneへのObsidian内部リンク1件 |
| `epic` | Text | Ticketで必須 | 所属EpicへのObsidian内部リンク1件 |

### 3.1 `note_type`

ノートの役割を表す。1ノートにつき1つだけ指定する。

| 値 | 用途 |
|---|---|
| `overview` | RAGScopeの目的、価値、主な能力、対象外 |
| `requirements` | 機能要件、非機能要件、制約、対象外 |
| `design` | システムまたは機能の設計 |
| `adr` | Architecture Decision Record |
| `experiment` | 仮説、条件、結果、考察を伴う実験記録 |
| `reference` | 規約、テンプレート、参照資料 |
| `roadmap` | バージョン全体の計画 |
| `milestone` | 1つのリリース可能なバージョン |
| `epic` | Milestone内で実現する能力 |
| `ticket` | Epicの能力を実現する具体的な作業 |

### 3.2 `status`

`status`は、ADR・Milestone・Epic・Ticketだけに使用する。

#### ADR

| 値 | 意味 |
|---|---|
| `proposed` | 提案中 |
| `accepted` | 採用済み |
| `superseded` | 後続ADRによって置き換えられた |
| `rejected` | 検討したが不採用 |

#### Milestone・Epic・Ticket

| 値 | 意味 |
|---|---|
| `planned` | 内容を定義済みだが未着手 |
| `in_progress` | 作業中 |
| `done` | 完了条件を確認済み |
| `cancelled` | 実施しないと決定した |

### 3.3 `milestone`

Epic・Ticketが所属するMilestoneへのObsidian内部リンクを、Text型の値として1件指定する。

```yaml
milestone: "[[v0.0]]"
```

- Obsidianに`Wiki Link`というプロパティ型は存在しない。
- 1つのEpic・Ticketを複数のMilestoneへ所属させない。
- 所属フォルダを変更した場合は、同じ変更内で更新する。
- フォルダ階層と不一致の場合は、フォルダ階層を正として修正する。

### 3.4 `epic`

Ticketが所属するEpicへのObsidian内部リンクを、Text型の値として1件指定する。

```yaml
epic: "[[v0.0 固定Markdown文書の取り込みとチャンク化]]"
```

- 1つのTicketを複数のEpicへ所属させない。
- 所属フォルダを変更した場合は、同じ変更内で更新する。
- EpicからTicketへの逆方向一覧は、Bases・検索・フォルダ表示から導出する。

### 3.5 `aliases`

実際に別名でリンクまたは検索する必要がある場合だけ指定する。

- ファイル名やタイトルだけで識別できる場合は使用しない。
- 表記揺れを無制限に登録しない。

## 4. リンクとの使い分け

- 本文中のノート間リンクには、GitHubでも解決できる標準Markdownの相対リンクを使用する。
- 一覧・絞り込みに使用する所属関係だけは、`milestone`・`epic`へObsidian内部リンク形式で記録する。

## 5. Frontmatter例

### 設計書

```yaml
---
note_type: design
---
```

### ADR

```yaml
---
note_type: adr
status: proposed
---
```

### Milestone

```yaml
---
note_type: milestone
status: planned
---
```

### Epic

```yaml
---
note_type: epic
status: planned
milestone: "[[v0.0]]"
---
```

### Ticket

```yaml
---
note_type: ticket
status: planned
milestone: "[[v0.0]]"
epic: "[[v0.0 固定Markdown文書の取り込みとチャンク化]]"
---
```

`aliases`は、実際の利用目的がある場合だけ追加する。

## 6. 規約変更

新しいプロパティや許容値が必要になった場合は、次の順序で対応する。

1. 使用する検索・一覧・自動処理と、既存項目で代替できない理由を示す。
2. 承認後、本規約を変更する。
3. 必要な既存ノートを移行し、不整合がないことを確認する。

規約変更が完了する前に、新しいプロパティや値を使用してはならない。
