# RAGScope

RAGScopeは、RAGシステムの検索結果、回答、引用、評価結果を観察し、条件の異なる実験を比較・追跡するためのアプリケーションです。

検索から回答生成、評価までの途中結果と条件を記録し、評価結果を根拠として設計判断を説明できることを中心に置きます。

## まず読む

### RAGScopeについて知りたい

RAGScopeの目的、価値、想定利用方法、満たす要求については以下を参照してください。

- [RAGScope概要](project-docs/RAGScope概要.md): RAGScopeが解決する問題、提供する価値、想定利用方法、主な能力
- [RAGScope要求定義](project-docs/RAGScope要求定義.md): RAGScopeが満たす機能、品質、制約、対象範囲

### RAGScopeを開発したい

RAGScopeの構成、開発方法、プロジェクト運用、コーディング規約については以下を参照してください。

- [システムアーキテクチャ](project-docs/design/システムアーキテクチャ.md): コンポーネント構成、責務、依存方向、主要な処理・データフロー
- [`ragscope-app/README.md`](ragscope-app/README.md): Haskellコンポーネントの開発環境と実行・検証方法
- [ロードマップ](project-docs/project-management/ロードマップ.md): RAGScopeを段階的にどこまで実現するか
- [RAGScopeプロジェクト運用ガイド](project-docs/project-management/RAGScopeプロジェクト運用ガイド.md): Milestone、Epic、Ticket、Pull Request、リリースの進め方
- [RAGScopeコーディング規約](project-docs/rules/RAGScopeコーディング規約.md): RAGScope全体へ適用するコード品質と責務分離の原則
- [Haskellコーディング規約](project-docs/rules/Haskellコーディング規約.md): `ragscope-app/`へ適用するHaskell固有の規約

### プロジェクト管理Vaultを使いたい

`project-docs/project-management/` をObsidian Vaultとして使う場合は、Config Layerをセットアップします。

```bash
bash Scripts/setup-project-vault.sh
```

Config Layer本体は `Vendor/obsidian-config-layer` のsubmoduleとして管理し、ビルド成果物だけをVaultの `.obsidian/plugins/config-layer/` へ配置します。Vault固有の `.obsidian` はGit管理しません。

## リポジトリ構成

- [`ragscope-app/`](ragscope-app/README.md): RAGScopeアプリケーションを実装するHaskellコンポーネント
- [`contracts/`](contracts/): コンポーネント間で共有する機械可読な契約
- [`project-docs/`](project-docs/): 要求、設計、ADR、プロジェクト管理、開発規約
- [`Vendor/obsidian-config-layer/`](Vendor/obsidian-config-layer/): プロジェクト管理Vaultで利用するConfig Layerのsubmodule

システム全体のコンポーネント構成と責務は[システムアーキテクチャ](project-docs/design/システムアーキテクチャ.md)を正本とします。
