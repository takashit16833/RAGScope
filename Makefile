# Dev Container内のリポジトリルートから、RAGScopeアプリケーションの
# 整形と品質検査を同じ手順で実行するための最小入口。
APP_DIR := ragscope-app

.PHONY: format format-check check

format:
	cd "$(APP_DIR)" && find app src logging-src test -type f -name "*.hs" -print0 | xargs -0 -r fourmolu --mode inplace

format-check:
	cd "$(APP_DIR)" && find app src logging-src test -type f -name "*.hs" -print0 | xargs -0 -r fourmolu --mode check

check: format-check
	cd "$(APP_DIR)" && cabal build all
	cd "$(APP_DIR)" && cabal test all
	cd "$(APP_DIR)" && cabal haddock all
