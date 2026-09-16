# RAGScopeアプリケーションのルート
APP_DIR := ragscope-app

.PHONY: format-app format-check-app check-telemetry-types check-app

# HaskellソースをFourmoluで整形する
format-app:
	find "$(APP_DIR)" \
		-path "$(APP_DIR)/dist-newstyle" -prune -o \
		-type f -name "*.hs" -print0 \
		| xargs -0 -r fourmolu --mode inplace

# 整形済みか確認する。ファイルは変更しない
format-check-app:
	find "$(APP_DIR)" \
		-path "$(APP_DIR)/dist-newstyle" -prune -o \
		-type f -name "*.hs" -print0 \
		| xargs -0 -r fourmolu --mode check

# 整形、ビルド、テスト、型制約、Haddockをまとめて確認する
check-app : format-check-app
	cd "$(APP_DIR)" && cabal build all
	cd "$(APP_DIR)" && cabal test all
	$(MAKE) check-telemetry-types
	cd "$(APP_DIR)" && cabal haddock all

# Telemetry境界の型制約をコンパイル成功・失敗の両方で検証する
check-telemetry-types:
	cd "$(APP_DIR)" && sh telemetry-boundary-test/check-type-safety.sh
