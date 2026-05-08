#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="WeReadAudiobook"
DISPLAY_NAME="微信读书朗读"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/$BUILD_CONFIG"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

PYTHON_BIN="${PYTHON_BIN:-}"

if [[ -z "$PYTHON_BIN" ]]; then
  if command -v python3.11 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3.11)"
  else
    echo "需要 Python 3.11。请先安装 python@3.11，或用 PYTHON_BIN=/path/to/python3.11 指定。" >&2
    exit 1
  fi
fi

if [[ ! -x "$ROOT_DIR/.venv-ocr/bin/python" ]]; then
  echo "未找到 OCR 环境，请先运行 scripts/setup-paddleocr.sh" >&2
  exit 1
fi

swift build -c "$BUILD_CONFIG"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/requirements-ocr.txt" "$RESOURCES_DIR/requirements-ocr.txt"
rsync -a --delete "$ROOT_DIR/scripts/" "$RESOURCES_DIR/scripts/"

"$PYTHON_BIN" -m venv --copies "$RESOURCES_DIR/.venv-ocr"
"$RESOURCES_DIR/.venv-ocr/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null
"$RESOURCES_DIR/.venv-ocr/bin/python" -m pip install -r "$RESOURCES_DIR/requirements-ocr.txt" >/dev/null

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>local.weread.audiobook</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Local build</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - --entitlements "$ROOT_DIR/WeReadAudiobook.entitlements" "$APP_DIR" >/dev/null

echo "$APP_DIR"
