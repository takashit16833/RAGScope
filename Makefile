# Dev Container内のリポジトリルートから、ragscope-appの
# 整形と品質検査を同じ手順で実行するための入口。
APP_DIR := ragscope-app

.PHONY: format-app format-check-app check-app

format-app:
	cd "$(APP_DIR)" && find packages -type f -name "*.hs" -print0 | xargs -0 -r fourmolu --mode inplace

format-check-app:
	cd "$(APP_DIR)" && find packages -type f -name "*.hs" -print0 | xargs -0 -r fourmolu --mode check

check-app: format-check-app
	cd "$(APP_DIR)" && cabal build all
	cd "$(APP_DIR)" && cabal test all
	cd "$(APP_DIR)" && cabal haddock all
