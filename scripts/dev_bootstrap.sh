#!/usr/bin/env bash
# Bootstraps the full UlinziMesh dev environment
# Supports remote agent connections - collector binds to 0.0.0.0 by default

set -euo pipefail

LOG_PREFIX="[dev_bootstrap]"
ENV_FILE="${ENV_FILE:-.env}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "$LOG_PREFIX loading environment..."
if [[ -f "$REPO_ROOT/$ENV_FILE" ]]; then
  source "$REPO_ROOT/$ENV_FILE"
else
  echo "$LOG_PREFIX no .env file found at $REPO_ROOT/$ENV_FILE"
  exit 1
fi

# --- Migrations ---
echo "$LOG_PREFIX running migrations..."
bash "$REPO_ROOT/scripts/migrate_up.sh"

# --- Build agents ---
echo "$LOG_PREFIX building C agent..."
(cd "$REPO_ROOT/agents/c_agent" && bash build.sh)

echo "$LOG_PREFIX building C++ decoy..."
(cd "$REPO_ROOT/agents/cpp_decoy" && bash build.sh)

echo "$LOG_PREFIX building Assembly agent..."
(cd "$REPO_ROOT/agents/asm" && bash build.sh) || echo "$LOG_PREFIX assembly build skipped (platform mismatch)"

# --- Start collector (binds to all interfaces for remote agents) ---
echo "$LOG_PREFIX starting Go collector..."
export COLLECTOR_BIND="${COLLECTOR_BIND:-0.0.0.0:9090}"
(cd "$REPO_ROOT/collector" && nohup env COLLECTOR_BIND="$COLLECTOR_BIND" \
  COLLECTOR_TOKEN="${COLLECTOR_TOKEN:-}" \
  PGHOST="${PGHOST:-127.0.0.1}" \
  PGPORT="${PGPORT:-5432}" \
  PGUSER="${PGUSER:-admin}" \
  PGPASSWORD="${PGPASSWORD:-admin}" \
  PGDATABASE="${PGDATABASE:-ulinzimesh}" \
  go run main.go > "$REPO_ROOT/logs/collector.log" 2>&1 &)
sleep 2

# --- Start PHP API ---
echo "$LOG_PREFIX starting PHP API..."
(cd "$REPO_ROOT/web/api" && nohup php -S 0.0.0.0:8081 > "$REPO_ROOT/logs/api.log" 2>&1 &)
sleep 2

# --- Optional UI server ---
if [[ "${START_UI:-true}" == "true" ]]; then
  echo "$LOG_PREFIX starting static UI server..."
  (cd "$REPO_ROOT/web/ui" && nohup python3 -m http.server 8082 > "$REPO_ROOT/logs/ui.log" 2>&1 &)
fi

echo "$LOG_PREFIX bootstrap complete."
echo "$LOG_PREFIX services running:"
echo "  Collector:     http://${COLLECTOR_BIND}/healthz"
echo "  PHP API:       http://0.0.0.0:8081/findings"
echo "  UI (optional): http://127.0.0.1:8082/index.html"
echo ""
echo "$LOG_PREFIX agents can now connect to the collector at: http://<this-host>:9090"
echo "$LOG_PREFIX to configure remote agents, set COLLECTOR_URL=http://<this-host>:9090/ingest/flow"

