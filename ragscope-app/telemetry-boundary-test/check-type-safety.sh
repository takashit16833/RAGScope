#!/bin/sh

# Run compile-time regression checks for the public EventName API.
# The fixtures are stored as .hs.txt files so HLS does not load them as
# ordinary Cabal modules. Some are intentionally invalid and must not be
# registered in other-modules.
#
# Compile temporary .hs copies independently, accepting failures only when
# GHC reports the expected diagnostic.

set -eu

cd "$(dirname "$0")/.."

tmpdir=$(mktemp -d)
trap 'rm -rf -- "$tmpdir"' EXIT

compile() {
  source=$1

  # Turn the text fixture into a temporary Haskell source file.
  generated_source="$tmpdir/$(basename "$source" .txt)"
  cp "$source" "$generated_source"

  cabal exec -- ghc \
    -XGHC2021 \
    -fno-code \
    -fforce-recomp \
    -v0 \
    -outputdir "$tmpdir" \
    -i./telemetry-boundary \
    "$generated_source"
}

expect_compile_failure() {
  label=$1
  source=$2
  expected_message=$3

  if compile "$source" > "$tmpdir/compiler.log" 2>&1; then
    printf 'FAIL: %s unexpectedly compiled\n' "$label"
    exit 1
  fi

  if ! grep -Fq "$expected_message" "$tmpdir/compiler.log"; then
    printf 'FAIL: %s failed for an unexpected reason\n' "$label"
    cat "$tmpdir/compiler.log"
    exit 1
  fi

  printf 'PASS: %s rejected as intended\n' "$label"
}

if compile \
  telemetry-boundary-test/type-check/ValidEventName.hs.txt \
  > "$tmpdir/compiler.log" 2>&1
then
  echo "PASS: non-empty EventName compiled"
else
  echo "FAIL: positive control did not compile"
  cat "$tmpdir/compiler.log"
  exit 1
fi

expect_compile_failure \
  "empty EventName" \
  telemetry-boundary-test/type-check/EmptyEventName.hs.txt \
  "EventName must not be empty"

expect_compile_failure \
  "hidden EventName constructor" \
  telemetry-boundary-test/type-check/HiddenEventNameConstructor.hs.txt \
  "does not export"

echo "All EventName compile-time checks passed."
