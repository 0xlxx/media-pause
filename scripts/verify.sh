#!/bin/bash
# Compilation test + smoke test.
# Usage: scripts/verify.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> swift build (debug)"
swift build

echo "==> swift build (release, product only)"
swift build -c release --product media-pause

echo "==> unit tests (media-pause-tests)"
swift run media-pause-tests

BIN=".build/debug/media-pause"

echo "==> smoke: --version"
"$BIN" --version | grep -q "media-pause" || { echo "version missing"; exit 1; }

echo "==> smoke: --help"
"$BIN" --help | grep -q "Usage:" || { echo "help missing"; exit 1; }

echo "==> smoke: status (no timer)"
"$BIN" status | grep -q "No timer running" || { echo "status unexpected"; exit 1; }

echo "==> smoke: stop (no timer)"
"$BIN" stop | grep -q "No timer running" || { echo "stop unexpected"; exit 1; }

echo "==> smoke: unknown browser rejected"
if "$BIN" -b not-a-browser --now >/dev/null 2>&1; then
    echo "unknown browser should fail"; exit 1
fi

echo "==> smoke: invalid duration rejected"
if "$BIN" 30x >/dev/null 2>&1; then
    echo "invalid duration should fail"; exit 1
fi

echo "All verify checks passed ✅"
