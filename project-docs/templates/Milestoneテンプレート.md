---
note_type: milestone
status: planned
---
# {{title}} — （完了後の状態を記載）

## 目標

このバージョンで実現する状態を記載する。

## 対象範囲

## 対象外

## 対象要求

<!--
要求IDは、挿入先のMilestoneノートからRAGScope要求定義の該当節へ相対リンクする。
要求本文を複製せず、このMilestoneで実現する範囲だけを記載する。
複数のMilestoneにまたがる要求は、今回の担当範囲だけを書く。

例：
| [`REQ-DOC-001`](<../../../RAGScope要求定義.md#2.1 文書の取り込みと追跡>) | 固定Markdown文書を取り込む。 |
-->

| 要求ID | このMilestoneで実現する範囲 |
|---|---|
|  |  |

## 成功条件

- [ ] 実際に実行または検証できる条件

## Epic別Ticket

```base
filters:
  and:
    - 'file.inFolder("project-management/milestones")'
    - 'note_type == "ticket"'
    - 'milestone == this'
views:
  - type: table
    name: すべて
    groupBy:
      property: epic
      direction: ASC
    order:
      - file.name
      - epic
      - status
  - type: table
    name: 未完了
    filters:
      or:
        - 'status == "planned"'
        - 'status == "in_progress"'
    groupBy:
      property: epic
      direction: ASC
    order:
      - file.name
      - epic
      - status
```

## リリース結果

完了時に、実現した内容、確認方法、既知の制約を記録する。
