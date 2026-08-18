#!/usr/bin/env bash
set -euo pipefail

cache_dir="/home/vscode/.cache"
uv_environment="${UV_PROJECT_ENVIRONMENT:-/home/vscode/.venvs/ragscope-ai-service}"
uv_environment_parent="$(dirname "${uv_environment}")"

# Named volumeの初回作成時にroot所有となり得るディレクトリを、
# vscodeユーザーから書き込める状態にする。
sudo mkdir -p "${cache_dir}" "${uv_environment_parent}"
sudo chown -R "$(id -u):$(id -g)" "${cache_dir}" "${uv_environment_parent}"
test -w "${cache_dir}"
test -w "${uv_environment_parent}"

project_dir="$(git rev-parse --show-toplevel)/ai-service"
cd "${project_dir}"

# pyproject.tomlから開発環境を同期する。初回はuv.lockも生成する。
uv sync
