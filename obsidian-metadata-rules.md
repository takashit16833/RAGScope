---
aliases:
  - Obsidianメタデータ規約
  - RAGScopeプロパティ規約
tags:
  - obsidian
  - metadata
  - ragscope
note_type: reference
status: stable
---
# Obsidianメタデータ規約

> [!abstract] 目的
> RAGScope関連のObsidianノートで使用するプロパティとタグの命名・用途を統一する。  
> 主な参照者はAIとし、ノートの作成・更新時には本規約を必ず適用する。

## 1. 基本原則

> [!important] 最重要原則
> **検索、一覧表示、絞り込み、並べ替え、自動処理のいずれにも使用しない情報は、プロパティとして追加しない。**

- プロパティは必要最小限にする。
- 本文、ファイルパス、Gitなどから確実に取得できる情報を重複して保存しない。
- 同じ意味のプロパティを別名で追加しない。
- プロパティ名だけでなく、値と型も統一する。
- 新しいプロパティは、本規約のプロパティ台帳へ追加してから使用する。
- 将来使う可能性だけを理由にプロパティを追加しない。

> [!tip] 判断基準
> **No query, no property.**  
> そのプロパティを利用する検索・一覧・自動処理を説明できない場合は追加しない。

## 2. プロパティ名の命名規則

### 2.1 Obsidian標準プロパティ

次の標準名は、そのまま使用する。

```yaml
aliases:
tags:
cssclasses:
```

- `alias`ではなく`aliases`を使う。
- `tag`ではなく`tags`を使う。
- 標準プロパティを独自名称へ置き換えない。

### 2.2 独自プロパティ

独自プロパティ名は`lower_snake_case`で統一する。

```yaml
note_type:
source_url:
created_at:
```

次の形式は使用しない。

```yaml
note-type:
noteType:
NoteType:
document-type:
doc-type:
```

## 3. 使用するプロパティ

| 名前 | 型 | 必須 | 用途 |
|---|---|---:|---|
| `aliases` | List | 任意 | ノートの別名、Wikiリンク候補 |
| `tags` | Tags | 任意 | ノートが扱うテーマによる検索・絞り込み |
| `note_type` | Text | 必須 | ノート自体の種類による分類 |
| `status` | Text | 任意 | 文書の状態管理 |
| `cssclasses` | List | 任意 | 明確な表示上の用途がある場合のみ使用 |

> [!warning] 未登録プロパティ
> 上表にないプロパティは、既存プロパティで表現できないか確認する。  
> 必要な場合は、先に本規約へ用途・型・許容値を追加してから使用する。

## 4. 各プロパティの規則

### 4.1 `aliases`

ノートの別名として実際にWikiリンクや検索で使用する名称だけを指定する。

```yaml
aliases:
  - RAGScope設計書
```

- ファイル名と完全に同じ値は原則として追加しない。
- 表記揺れを無制限に登録しない。
- 略称や日本語名など、実際に参照する別名だけを登録する。

### 4.2 `tags`

`tags`は、ノートが**何について書かれているか**を表す。

```yaml
tags:
  - rag
  - evaluation
  - information-retrieval
```

- 小文字で記述する。
- 複数単語はハイフンでつなぐ。
- 単数形・複数形を混在させない。
- 同義語や表記揺れを新しいタグとして追加しない。
- ノートの種類は`tags`ではなく`note_type`で表す。

使用しない例：

```yaml
tags:
  - RAG
  - information_retrieval
  - designs
  - Design
```

### 4.3 `note_type`

`note_type`は、ノートが**どの種類の文書か**を表す。

許容値は次のとおり。

| 値 | 用途 |
|---|---|
| `design` | システムや機能の設計書 |
| `concept` | 一般概念・用語の解説 |
| `adr` | Architecture Decision Record |
| `experiment` | 実験条件、結果、考察 |
| `implementation` | 実装手順や実装上の記録 |
| `reference` | 規約、参照資料、一覧 |
| `moc` | Map of Content、複数ノートへの入口 |

```yaml
note_type: design
```

- 1ノートにつき1つだけ指定する。
- 必要な値がない場合、似た語を勝手に追加しない。
- 新しい値が必要な場合は、本規約の許容値へ追加してから使用する。

### 4.4 `status`

`status`は、文書の現在の状態を表す。

許容値は次のとおり。

| 値 | 意味 |
|---|---|
| `draft` | 作成中であり、内容が確定していない |
| `active` | 現在使用・更新している |
| `stable` | 内容が安定し、通常は大きく変更しない |
| `deprecated` | 非推奨だが、参照のため残している |
| `archived` | 現在は使用せず、履歴として保存している |

```yaml
status: active
```

次のような独自表現は使用しない。

```yaml
status: WIP
status: work-in-progress
status: completed
status: 作成中
```

### 4.5 `cssclasses`

`cssclasses`は、ノートへ固有の表示スタイルを適用する場合だけ使用する。

```yaml
cssclasses:
  - wide-table
```

- 見た目の用途が実装されていない値は追加しない。
- 分類や状態管理には使用しない。

## 5. 原則として使用しないプロパティ

次のプロパティは、明確な利用方法が決まるまで使用しない。

```yaml
related:
created:
updated:
author:
project:
version:
```

理由：

- `related`は、本文中のWikiリンクとバックリンクで代替できる。
- `created`、`updated`は、手動管理すると信頼できない情報になりやすい。
- `author`は、現状のRAGScopeノートでは管理用途がない。
- `project`は、フォルダや保管場所から判別できる場合は重複情報になる。
- `version`は、Gitや本文中のバージョン定義と競合する可能性がある。

必要になった場合は、用途・型・更新方法を本規約へ追加してから導入する。

## 6. 本文リンクとプロパティの使い分け

ノート同士の関係は、原則として本文中のWikiリンクで表す。

```markdown
一般的なAI・LLM・RAGの知識は
[[ai-llm-rag-notes|AI・LLM・RAG基礎ノート]]
で管理する。
```

- 文脈を説明できる関係は本文へ記載する。
- 単なる関連性を`related`へ重複保存しない。
- Wikiリンクとバックリンクを関連ノートの基本機能として使う。

## 7. 推奨Frontmatter

### 設計書

```yaml
---
aliases:
  - RAGScope設計書
tags:
  - rag
note_type: design
status: active
---
```

### 基礎知識の入口

```yaml
---
aliases:
  - AI・LLM・RAG基礎ノート
  - RAG基礎用語集
tags:
  - ai
  - llm
  - rag
  - information-retrieval
note_type: moc
status: active
---
```

### ADR

```yaml
---
aliases:
  - ADRの日本語名
tags:
  - architecture
note_type: adr
status: active
---
```

## 8. 新しいプロパティを追加する手順

AIまたは人間が新しいプロパティを必要と判断した場合、次の順序で対応する。

1. 既存プロパティや本文リンクで代替できないか確認する。
2. 検索、一覧表示、自動処理の具体的な用途を示す。
3. プロパティ名を`lower_snake_case`で決定する。
4. 型を決定する。
5. 列挙値を使う場合は、許容値をすべて定義する。
6. 更新主体と更新タイミングを決定する。
7. 本規約のプロパティ台帳へ追加する。
8. 既存ノートへ適用する。

> [!danger] 禁止
> 台帳を更新せず、個別ノートだけに新しいプロパティや値を追加してはならない。

## 9. AI向け適用ルール

AIがRAGScope関連のMarkdownを作成・更新する場合、次を守る。

- 作業前に本規約を参照する。
- 既存のプロパティ名、型、許容値を優先する。
- 未登録プロパティを推測で追加しない。
- タグの表記揺れや類義語を勝手に作らない。
- ノートの種類は`note_type`、テーマは`tags`へ記録する。
- 関連ノートは本文のWikiリンクで接続する。
- 使用目的のないメタデータを追加しない。
- 規約と既存ノートが矛盾する場合は、勝手に統一せず矛盾を報告する。
- 新しいプロパティが必要な場合は、規約の変更案を先に提示する。
- Frontmatterを変更した場合は、本文との整合性も確認する。

## 10. プロパティ台帳

| 名前 | 型 | 必須 | 許容値・形式 | 主な用途 |
|---|---|---:|---|---|
| `aliases` | List | 任意 | 文字列のリスト | 別名からのリンク・検索 |
| `tags` | Tags | 任意 | 小文字、複数単語はハイフン | テーマ検索・絞り込み |
| `note_type` | Text | 必須 | `design` / `concept` / `adr` / `experiment` / `implementation` / `reference` / `moc` | ノート種類の分類 |
| `status` | Text | 任意 | `draft` / `active` / `stable` / `deprecated` / `archived` | 文書状態の管理 |
| `cssclasses` | List | 任意 | 実装済みCSS class名 | 表示スタイルの適用 |

## 11. 規約変更

- プロパティや許容値を追加・変更した場合は、本規約を先に更新する。
- 変更後は、既存ノートとの表記・型・値の不整合を確認する。
- 廃止したプロパティは、すぐに別名へ置換せず、移行方法を決める。
- AIは規約の変更を独断で行わず、変更理由と影響範囲を提示する。
