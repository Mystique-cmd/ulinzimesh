#!/usr/bin/env bash
# Bootstraps the full UlinziMesh dev environment

set -euo pipefail

LOG_PREFIX="[dev_bootstrap]"
ENV_FILE="${ENV_FILE:-.env}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "$LOG_PREFIX loading environment..."
if [[ -f "$REPO_ROOT/$ENV_FILE" ]]; then
  export $(grep -v '^#' "$REPO_ROOT/$ENV_FILE" | xargs -d '\n')
else
  echo "$LOG_PREFIX no .env file found at $REPO_ROOT/$ENV_FILE"
  exit 1
fi

# --- Migrations ---
echo "$LOG_PREFIX running migrations..."
bash "$REPO_ROOT/scripts/migrate_up.sh"

# --- Build agents ---
echo "$LOG_PREFIX building C agent..."
bash "$REPO_ROOT/agents/c_agent/build.sh"

echo "$LOG_PREFIX building C++ decoy..."
bash "$REPO_ROOT/agents/cpp_decoy/build.sh"

echo "$LOG_PREFIX building Assembly agent..."
bash "$REPO_ROOT/agents/asm/build.sh" || echo "$LOG_PREFIX assembly build skipped (platform mismatch)"

# --- Start collector ---
echo "$LOG_PREFIX starting Go collector..."
(cd "$REPO_ROOT/collector" && nohup go run main.go > "$REPO_ROOT/logs/collector.log" 2>&1 &)
sleep 2

# --- Start PHP API ---
echo "$LOG_PREFIX starting PHP API..."
(cd "$REPO_ROOT/web/api" && nohup php -S 127.0.0.1:8081 > "$REPO_ROOT/logs/api.log" 2>&1 &)
sleep 2

# --- Optional UI server ---
if [[ "${START_UI:-true}" == "true" ]]; then
  echo "$LOG_PREFIX starting static UI server..."
  (cd "$REPO_ROOT/web/ui" && nohup python3 -m http.server 8082 > "$REPO_ROOT/logs/ui.log" 2>&1 &)
fi

echo "$LOG_PREFIX bootstrap complete."
echo "$LOG_PREFIX services running:"
echo "  Collector:     http://127.0.0.1:9000/healthz"
echo "  PHP API:       http://127.0.0.1:8081/findings"
echo "  UI (optional): http://127.0.0.1:8082/index.html"
