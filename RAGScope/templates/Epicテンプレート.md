---
note_type: epic
status: planned
milestone: "[[vX.Y]]"
---
# {{title}}

## 能力

このEpicによって何ができるようになるかを記載する。

## Milestoneでの役割

Milestoneの完成に、この能力がどのように必要かを記載する。

## 完了条件

- [ ] Epic全体として確認可能な条件

## Ticket

```base
filters:
  and:
    - 'file.inFolder("project-management/milestones")'
    - 'note_type == "ticket"'
    - 'epic == this'
views:
  - type: table
    name: Ticket
    order:
      - file.name
      - status
```

## 関連文書

<!-- 作業に必要な要求、機能設計書、ADR、Experimentがある場合だけ相対リンクを記載し、不要ならこの節を削除する。 -->

## 結果

完了時に、実現した能力、確認方法、残った制約を記録する。
