#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/debug"
OBJECT_DIR="$BUILD_DIR/WeReadAudiobook.build"
CHECK_BIN="$ROOT_DIR/.build/checks"

cd "$ROOT_DIR"
swift build >/dev/null

if rg -n "TextCorrector|textCorrection|AI 纠错|LLM 文本纠错|\\[纠错\\]" "$ROOT_DIR/Sources" "$ROOT_DIR/Tests"; then
  echo "check failed: OCR text must go directly to TTS without LLM correction" >&2
  exit 1
fi

if rg -n "SettingsWindowController" "$ROOT_DIR/Sources" "$ROOT_DIR/Tests"; then
  echo "check failed: settings must open inside the menu bar panel" >&2
  exit 1
fi

if rg -n "VNRecognizeTextRequest|VNImageRequestHandler|import Vision" "$ROOT_DIR/Sources/WeReadAudiobook/TextRecognition.swift"; then
  echo "check failed: TextRecognition must use PaddleOCR instead of macOS Vision OCR" >&2
  exit 1
fi

if rg -n "linkedFramework\\(\"Vision\"\\)" "$ROOT_DIR/Package.swift"; then
  echo "check failed: Package.swift must not link the old Vision OCR framework" >&2
  exit 1
fi

if ! rg -n "DEFAULT_MODEL_PROFILE = \"quality\"" "$ROOT_DIR/scripts/paddle_ocr_worker.py" >/dev/null; then
  echo "check failed: PaddleOCR must default to the quality profile" >&2
  exit 1
fi

if ! rg -n "\"quality\"|PP-OCRv5_mobile_det|PP-OCRv5_server_rec" "$ROOT_DIR/scripts/paddle_ocr_worker.py" >/dev/null; then
  echo "check failed: quality OCR profile must use mobile detection and server recognition" >&2
  exit 1
fi

if ! rg -n "\"accurate\"|PP-OCRv5_server_det|PP-OCRv5_server_rec" "$ROOT_DIR/scripts/paddle_ocr_worker.py" >/dev/null; then
  echo "check failed: server OCR models should remain available as an opt-in profile" >&2
  exit 1
fi

if ! rg -n "\"balanced\"|PP-OCRv5_mobile_rec" "$ROOT_DIR/scripts/paddle_ocr_worker.py" >/dev/null; then
  echo "check failed: lower-memory balanced OCR profile should remain available" >&2
  exit 1
fi

if ! rg -n "preprocess_image|ImageEnhance|ImageOps" "$ROOT_DIR/scripts/paddle_ocr_worker.py" >/dev/null; then
  echo "check failed: OCR input images must be preprocessed before recognition" >&2
  exit 1
fi

if ! rg -n "BrokenPipeError|ClientDisconnected" "$ROOT_DIR/scripts/paddle_ocr_worker.py" >/dev/null; then
  echo "check failed: PaddleOCR worker must exit cleanly when the app disconnects" >&2
  exit 1
fi

if rg -n "\\[(TTS|Audio|Log)\\]|最终段落|OCR 原文|原始文本:" "$ROOT_DIR/Sources"; then
  echo "check failed: app logs should only output raw OCR text" >&2
  exit 1
fi

if rg -n "print\\(" "$ROOT_DIR/Sources/WeReadAudiobook/TTSService.swift" "$ROOT_DIR/Sources/WeReadAudiobook/AudioManager.swift"; then
  echo "check failed: TTS and audio code should not print runtime logs" >&2
  exit 1
fi

if ! rg -n "process.standardError = FileHandle.nullDevice" "$ROOT_DIR/Sources/WeReadAudiobook/PaddleOCRClient.swift" >/dev/null; then
  echo "check failed: PaddleOCR stderr should not be forwarded to app logs" >&2
  exit 1
fi

if ! rg -n "Bundle\\.main\\.resourceURL" "$ROOT_DIR/Sources/WeReadAudiobook/ProjectPaths.swift" >/dev/null; then
  echo "check failed: packaged app must be able to locate bundled OCR resources" >&2
  exit 1
fi

if [[ ! -x "$ROOT_DIR/scripts/package-app.sh" ]]; then
  echo "check failed: package-app.sh must exist and be executable" >&2
  exit 1
fi

for geo_file in \
  "$ROOT_DIR/README.md" \
  "$ROOT_DIR/llms.txt" \
  "$ROOT_DIR/llms-full.txt" \
  "$ROOT_DIR/docs/GEO.md" \
  "$ROOT_DIR/docs/projects/weread-audiobook.md" \
  "$ROOT_DIR/docs/api/project.json"; do
  if [[ ! -f "$geo_file" ]]; then
    echo "check failed: missing GEO file $geo_file" >&2
    exit 1
  fi
done

python3 -m json.tool "$ROOT_DIR/docs/api/project.json" >/dev/null

if ! rg -n "WeReadAudiobook|PaddleOCR|MiMo" "$ROOT_DIR/llms.txt" "$ROOT_DIR/llms-full.txt" "$ROOT_DIR/docs/projects/weread-audiobook.md" >/dev/null; then
  echo "check failed: GEO documents must describe the actual project" >&2
  exit 1
fi

objects=()
for object in "$OBJECT_DIR"/*.swift.o; do
  case "$(basename "$object")" in
    App.swift.o) ;;
    *) objects+=("$object") ;;
  esac
done

swiftc \
  -I "$BUILD_DIR/Modules" \
  "$ROOT_DIR/Tests/checks.swift" \
  "${objects[@]}" \
  -o "$CHECK_BIN"

"$CHECK_BIN"
