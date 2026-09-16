# ragscope-app

RAGScopeアプリケーションを実装するHaskellコンポーネントです。

## 開発環境

VS Codeでは、リポジトリルートの`.devcontainer/devcontainer.json`を使用してDev Containerを開きます。

Dev Container作成後は`post-create.sh`によってCabalの利用者設定を必要に応じて初期化し、パッケージ索引を更新します。

## 開発中によく使うコマンド

整形と品質検査の共通入口は、リポジトリルートの`Makefile`です。

### 整形

リポジトリルートから実行します。

```bash
make format-app
```

FourmoluでHaskellコードを整形します。

### 整形状態の確認

```bash
make format-check-app
```

ファイルを書き換えず、Fourmoluの整形状態を確認します。

### 品質検査

```bash
make check-app
```

`make check-app`では、整形状態の確認、ビルド、テスト、Telemetry境界のコンパイル時検査、Haddock生成を順に実行します。

Telemetry境界のコンパイル時検査では、正常なコードがコンパイルできることに加え、空のEventNameや非公開コンストラクタの使用が期待した理由で拒否されることを確認します。意図的にコンパイルできないfixtureを使用するため、この検査は`cabal test all`には含まれません。`make check-app`を実行してください。

## Cabalコマンドを個別に実行する

`ragscope-app/`から実行します。

### ビルド

```bash
cabal build all
```

### テスト

```bash
cabal test all
```

### Haddock生成

```bash
cabal haddock all
```

### CLIの実行

```bash
cabal run ragscope
```

## 開発規約

実装時は次の規約を参照してください。

- [RAGScopeコーディング規約](../project-docs/rules/RAGScopeコーディング規約.md)
- [Haskellコーディング規約](../project-docs/rules/Haskellコーディング規約.md)

システム全体での責務と依存関係は[システムアーキテクチャ](../project-docs/design/システムアーキテクチャ.md)を参照してください。
