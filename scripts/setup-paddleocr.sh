#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-}"

if [[ -z "$PYTHON_BIN" ]]; then
  if command -v python3.11 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3.11)"
  else
    echo "需要 Python 3.11。请先安装 python@3.11，或用 PYTHON_BIN=/path/to/python3.11 指定。" >&2
    exit 1
  fi
fi

"$PYTHON_BIN" -m venv "$ROOT_DIR/.venv-ocr"
"$ROOT_DIR/.venv-ocr/bin/python" -m pip install --upgrade pip setuptools wheel
"$ROOT_DIR/.venv-ocr/bin/python" -m pip install -r "$ROOT_DIR/requirements-ocr.txt"
"$ROOT_DIR/.venv-ocr/bin/python" "$ROOT_DIR/scripts/paddle_ocr_worker.py" --self-test
