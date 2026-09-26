# RAGScopeアプリケーションのルートディレクトリ
APP_DIR := ragscope-app

.PHONY: format-app format-check-app check-app

# HaskellソースをFourmolu、Cabalファイルをcabal-gildで整形する
format-app:
	find "$(APP_DIR)" \
		-path "$(APP_DIR)/dist-newstyle" -prune -o \
		-type f -name "*.hs" -print0 \
		| xargs -0 -r fourmolu --mode inplace
	find "$(APP_DIR)" \
		-path "$(APP_DIR)/dist-newstyle" -prune -o \
		-type f \( -name "*.cabal" -o -name "cabal.project" \) \
		-exec cabal-gild --io={} \;

# ファイルを書き換えず、HaskellソースとCabalファイルの整形状態を確認する
format-check-app:
	find "$(APP_DIR)" \
		-path "$(APP_DIR)/dist-newstyle" -prune -o \
		-type f -name "*.hs" -print0 \
		| xargs -0 -r fourmolu --mode check
	find "$(APP_DIR)" \
		-path "$(APP_DIR)/dist-newstyle" -prune -o \
		-type f \( -name "*.cabal" -o -name "cabal.project" \) \
		-exec cabal-gild --mode=check --input={} \;

# 整形状態の確認、ビルド、テスト、Haddock生成を順に実行する
check-app: format-check-app
	cd "$(APP_DIR)" && cabal build all
	cd "$(APP_DIR)" && cabal test all
	cd "$(APP_DIR)" && cabal haddock all
