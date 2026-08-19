# Dev Container内のリポジトリルートから、各コンポーネントの
# 整形と品質検査を同じ手順で実行するための最小入口。
APP_DIR := ragscope-app
AI_DIR := ai-service

.PHONY: format-app format-check-app check-app format-ai format-check-ai check-ai

format-app:
	cd "$(APP_DIR)" && find app src logging-src test -type f -name "*.hs" -print0 | xargs -0 -r fourmolu --mode inplace

format-check-app:
	cd "$(APP_DIR)" && find app src logging-src test -type f -name "*.hs" -print0 | xargs -0 -r fourmolu --mode check

check-app: format-check-app
	cd "$(APP_DIR)" && cabal build all
	cd "$(APP_DIR)" && cabal test all
	cd "$(APP_DIR)" && cabal haddock all

format-ai:
	cd "$(AI_DIR)" && uv run ruff check --fix .
	cd "$(AI_DIR)" && uv run ruff format .

format-check-ai:
	cd "$(AI_DIR)" && uv run ruff format --check .
	cd "$(AI_DIR)" && uv run ruff check .

check-ai: format-check-ai
	cd "$(AI_DIR)" && uv run pyright
	cd "$(AI_DIR)" && uv run pytest
