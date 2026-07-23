---
aliases:
  - RAGScopeプロジェクトダッシュボード
tags:
  - ragscope
  - project-management
note_type: moc
status: active
---
# RAGScope Project Dashboard

> [!abstract] このノートの役割
> RAGScopeのMilestone・Epic・Ticketを横断して確認する、プロジェクト管理の入口。  
> プロダクトの仕様と成功条件は[[ragscope-design|RAGScope設計書]]、作業管理の方法は[[ragscope-project-management-rules|RAGScopeプロジェクト管理規約]]に従う。

## 現在のフォーカス

| 区分 | 対象 |
|---|---|
| Milestone | [[v0.0]] |
| 最初のEpic | [[v0.0-document-ingestion]] |
| 次に着手するTicket | [[RS-0001-read-fixed-markdown]] |

> [!tip] 着手時の操作
> [[RS-0001-read-fixed-markdown]]へ着手するときに、Ticketの`status`を`draft`から`active`へ変更する。

## Milestone

### 現在

- [[v0.0]] — 固定文書のchunk化、Embedding生成・保存、exact search

### 今後

後続Milestoneは、必要になるまで詳細なEpic・Ticketへ分解しない。全体の順序は[[ragscope-design#10.2 バージョン別計画|設計書のバージョン別計画]]を参照する。

## Ticket Dashboard

> [!info] Basesについて
> 次のビューは、`project-management/milestones`以下にあるTicketノートを、`status`ごとに自動表示する。  
> Ticketノートが正本であり、Basesは一覧表示のための派生ビューとして使用する。

```base
filters:
  and:
    - file.inFolder("project-management/milestones")
    - 'note_type != "moc"'
properties:
  file.name:
    displayName: Ticket
  status:
    displayName: Status
  note_type:
    displayName: Note Type
views:
  - type: table
    name: Active
    filters:
      and:
        - 'status == "active"'
    order:
      - file.name
      - status
      - note_type
  - type: table
    name: Draft
    filters:
      and:
        - 'status == "draft"'
    order:
      - file.name
      - status
      - note_type
  - type: table
    name: Stable
    filters:
      and:
        - 'status == "stable"'
    order:
      - file.name
      - status
      - note_type
  - type: table
    name: All Tickets
    groupBy:
      property: status
      direction: ASC
    order:
      - file.name
      - status
      - note_type
```

## 主要ノート

- [[ragscope-design|RAGScope設計書]]
- [[ragscope-project-management-rules|RAGScopeプロジェクト管理規約]]
- [[obsidian-metadata-rules|Obsidianメタデータ規約]]
- [[ai-llm-rag-notes|AI・LLM・RAG基礎ノート]]

## 運用メモ

- 原則として、同時に`active`にする主要Ticketは1件とする。
- Ticketを`stable`にする前に、完了条件、検証手順、実際の結果を本文へ記録する。
- 現在のTicketで不要な将来機能は混ぜず、後続Ticket候補として記録する。
- 設計書と実装の矛盾を見つけた場合は、Ticket内へ記録し、設計書更新またはADRの要否を判断する。
