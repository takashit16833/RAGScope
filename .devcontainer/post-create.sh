#!/usr/bin/env bash
set -euo pipefail

# Dev Container作成後に、vscodeユーザーがCabalの設定とパッケージ索引を
# 利用できる状態へ初期化する。
cabal_dir="${CABAL_DIR:-/home/vscode/.cabal}"

# 初回作成時にroot所有となり得るCabalディレクトリを、
# コンテナ内で開発するvscodeユーザーから書き込める状態にする。
sudo mkdir -p "${cabal_dir}"
sudo chown -R "$(id -u):$(id -g)" "${cabal_dir}"
test -w "${cabal_dir}"

# 既存の利用者設定を保持し、設定ファイルがない場合だけ初期化する。
if [[ ! -f "${cabal_dir}/config" ]]; then
    cabal user-config init
fi

# コンテナ作成時点のパッケージ索引を取得し、後続のbuildを再現可能にする。
cabal update
