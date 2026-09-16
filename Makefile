# Root directory of the RAGScope application
APP_DIR := ragscope-app

.PHONY: format-app format-check-app check-telemetry-types check-app

# Format Haskell source files with Fourmolu
format-app:
	find "$(APP_DIR)" \
		-path "$(APP_DIR)/dist-newstyle" -prune -o \
		-type f -name "*.hs" -print0 \
		| xargs -0 -r fourmolu --mode inplace

# Check formatting without modifying files
format-check-app:
	find "$(APP_DIR)" \
		-path "$(APP_DIR)/dist-newstyle" -prune -o \
		-type f -name "*.hs" -print0 \
		| xargs -0 -r fourmolu --mode check

# Run formatting checks, build, tests, type checks, and Haddock
check-app : format-check-app
	cd "$(APP_DIR)" && cabal build all
	cd "$(APP_DIR)" && cabal test all
	$(MAKE) check-telemetry-types
	cd "$(APP_DIR)" && cabal haddock all

# Verify Telemetry boundary type constraints using both positive and negative compilation test
check-telemetry-types:
	cd "$(APP_DIR)" && sh telemetry-boundary-test/check-type-safety.sh
