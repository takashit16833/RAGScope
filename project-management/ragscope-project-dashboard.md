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
> RAGScopeのプロジェクト管理の入口。  
> Ticketの状態は各Ticketの`status`を正本とし、一覧はBasesから自動表示する。

## 主要ノート

- [[ragscope-design|RAGScope設計書]]
- [[ragscope-project-management-rules|RAGScopeプロジェクト管理規約]]
- [[obsidian-metadata-rules|Obsidianメタデータ規約]]

## Milestone

- [[v0.0|RAGScope v0.0]]

## Ticket

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
```
