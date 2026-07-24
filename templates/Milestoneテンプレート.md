---
note_type: milestone
status: planned
---
# {{title}} — （完了後の状態を記載）

## 目標

このバージョンで実現する状態を記載する。

## 対象範囲

## 対象外

## 成功条件

- [ ] 実際に実行または検証できる条件

## Epic

```base
filters:
  and:
    - 'file.inFolder("project-management/milestones")'
    - 'note_type == "epic"'
    - 'milestone == this'
views:
  - type: table
    name: Epic
    order:
      - file.name
      - status
```

## リリース結果

完了時に、実現した内容、確認方法、既知の制約を記録する。
