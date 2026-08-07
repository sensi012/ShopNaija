#!/bin/bash
# ============================================================
# ShopNaija — Deployment Wrapper Script
# Calls Python deploy.py (cross-platform, boto3 native)
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_CMD="python3"

if ! command -v python3 &>/dev/null; then
  PYTHON_CMD="python"
fi

exec "$PYTHON_CMD" "$SCRIPT_DIR/deploy.py" "$@"
