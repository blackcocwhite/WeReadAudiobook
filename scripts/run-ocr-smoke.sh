#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/debug"
OBJECT_DIR="$BUILD_DIR/WeReadAudiobook.build"
SMOKE_BIN="$ROOT_DIR/.build/ocr-smoke"

cd "$ROOT_DIR"
swift build >/dev/null

objects=()
for object in "$OBJECT_DIR"/*.swift.o; do
  case "$(basename "$object")" in
    App.swift.o) ;;
    *) objects+=("$object") ;;
  esac
done

swiftc \
  -I "$BUILD_DIR/Modules" \
  "$ROOT_DIR/Tests/ocr_smoke.swift" \
  "${objects[@]}" \
  -o "$SMOKE_BIN"

"$SMOKE_BIN"
