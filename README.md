UlinziMesh — Run and Develop

This repo contains a minimal end‑to‑end sandbox:
- Collector (Go) that can ingest/send telemetry
- PHP API serving JSON endpoints
- Static Web UI that polls the API and renders tables
- Sample agents and orchestrator stubs

Quick start (one command)
1) Install prerequisites
   - Git, Bash
   - Go 1.20+ (for the collector)
   - PHP 8.1+ (CLI) with pgsql PDO extension
   - Python 3.8+ (for the simple static server)
   - PostgreSQL 13+

2) Configure environment
   - Copy or edit .env at the repo root. Example already provided:
     PGHOST=localhost
     PGPORT=5432
     PGDATABASE=ulinzimesh
     PGUSER=admin
     PGPASSWORD=admin
     COLLECTOR_TOKEN="admin"
   - Ensure this database and user exist in your local PostgreSQL, or adjust the values to match your setup.

3) Bootstrap everything (migrations, builds, services)
   bash scripts/dev_bootstrap.sh

This script will:
- Run database migrations
- Build agents (C, C++, asm where possible)
- Start the Go collector in background
- Start the PHP API at http://127.0.0.1:8081
- Start a static UI server at http://127.0.0.1:8082 (unless START_UI=false)

Open the dashboard
- Visit http://127.0.0.1:8082/index.html
- The UI polls the API every 5s. If reachable, tables will populate; otherwise they show a clear empty state.

Manual run (if you don’t want the bootstrap script)
1) Run migrations
   bash scripts/migrate_up.sh

2) Start the collector
   cd collector
   go run main.go
   # In a separate terminal, continue with the steps below

3) Start the API (PHP built‑in server)
   cd web/api
   php -S 127.0.0.1:8081

4) Serve the UI (simple Python static server)
   cd web/ui
   python3 -m http.server 8082

5) Open http://127.0.0.1:8082/index.html

Notes on the UI/API URLs
- The UI first tries same‑origin /api/* (e.g., http://127.0.0.1:8082/api/findings). If that isn’t present, it automatically falls back to http://127.0.0.1:8081/*.
- The PHP API also accepts either /findings or /api/findings paths.

Database migrations
- Up:   scripts/migrate_up.sh
- Down: scripts/migrate_down.sh
- SQL files live in db/migrations/

Sending test events
- Use the helper scripts to push sample data into the system:
  - Linux/macOS: scripts/send_test_event.sh
  - Windows (PowerShell): scripts/Send-Test-Event.psl

Troubleshooting
- Ports already in use
  - UI server: 8082
  - API server: 8081
  - If you see “Address already in use,” either stop the existing process or change the port.
  - To change the UI port manually: python3 -m http.server 9090 (then open http://127.0.0.1:9090)
  - To change the API port manually: php -S 127.0.0.1:9091 (the UI will still fall back to 8081 unless you add a reverse proxy or serve /api on the same origin)

- Logs (check these when something looks off)
  - logs/ui.log (Python static server output)
  - logs/api.log (PHP built‑in server output)
  - logs/collector.log (Go collector output)

- Database unavailable
  - The API degrades gracefully and returns empty lists instead of 500 errors.
  - Verify your .env and that PostgreSQL is running and accessible.

Stopping background services started by the bootstrap
- Find processes by port and kill them, e.g.:
  - lsof -i :8081; kill <PID>   # API
  - lsof -i :8082; kill <PID>   # UI
  - lsof -i :9000; kill <PID>   # Collector (if applicable)

API endpoints
- GET /findings
- GET /flows
- GET /indicators
- With the built‑in PHP server, these are available at http://127.0.0.1:8081/<endpoint>

Security note
- This project is a development sandbox. CORS is permissive and services are intended for local use. Do not expose these components directly to the internet without hardening.

Questions
- If you get stuck, open an issue with your OS, runtime versions, ports in use, and any relevant lines from logs/*.log.
