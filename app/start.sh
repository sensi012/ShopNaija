#!/bin/bash
# ============================================================
# ShopNaija — Application Startup Script
# Run this on the EC2 instance to install deps and start app
# ============================================================
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/var/log/shopnaija.log"
PORT="${APP_PORT:-8080}"

# Source environment variables written by user_data at boot
if [ -f /etc/environment ]; then
  set -a
  source /etc/environment
  set +a
fi

echo "=== ShopNaija Startup $(date) ===" | tee -a "$LOG_FILE"

PYTHON_BIN="python3.12"
if ! command -v python3.12 &>/dev/null; then
  PYTHON_BIN="python3"
fi

echo "[INFO] Installing Python dependencies using $PYTHON_BIN..." | tee -a "$LOG_FILE"
cd "$APP_DIR"
$PYTHON_BIN -m pip install -q -r requirements.txt 2>&1 | tee -a "$LOG_FILE"

# ── 2. Resolve DB host from endpoint env var ─────────────────
# DB_ENDPOINT from Terraform is hostname:port format
if [[ -n "${DB_ENDPOINT:-}" ]]; then
  export DB_HOST="${DB_ENDPOINT%%:*}"
  export DB_PORT="${DB_ENDPOINT##*:}"
fi
# Fallback defaults
export DB_HOST="${DB_HOST:-localhost}"
export DB_PORT="${DB_PORT:-5432}"

echo "[INFO] Using DB_HOST=$DB_HOST DB_PORT=$DB_PORT" | tee -a "$LOG_FILE"

# ── 3. Seed database (idempotent — skips existing rows) ──────
echo "[INFO] Running database seed..." | tee -a "$LOG_FILE"
$PYTHON_BIN seed.py 2>&1 | tee -a "$LOG_FILE" || echo "[WARN] Seed failed (may be first run)" | tee -a "$LOG_FILE"

# ── 4. Start app ─────────────────────────────────────────────
echo "[INFO] Terminating placeholder servers on port $PORT..." | tee -a "$LOG_FILE"
pkill -f 'http.server' || true
fuser -k "$PORT/tcp" || true
sleep 1

echo "[INFO] Starting ShopNaija on port $PORT..." | tee -a "$LOG_FILE"
exec $PYTHON_BIN -m uvicorn main:app \
  --host 0.0.0.0 \
  --port "$PORT" \
  --workers 2 \
  --access-log \
  --log-level info \
  2>&1 | tee -a "$LOG_FILE"
