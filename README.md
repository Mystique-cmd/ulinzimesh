# UlinziMesh — Real-World Threat Telemetry Platform

UlinziMesh is a modular cybersecurity framework that orchestrates low-level agents, a central telemetry collector, an analytics API, and an adaptive dashboard for real-time threat detection and response.

> **Production Ready** — This system is designed for real-world deployment. Agents capture live network flows, decoys report interactions to the collector, and the orchestrator runs playbook-driven threat analysis against live telemetry.

## Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  C Agent        │────▶│                  │     │  PHP API        │
│  (Linux /proc)  │     │                  │     │  (JSON REST)    │
├─────────────────┤     │   Go Collector   │────▶├─────────────────┤
│  C++ Decoy      │────▶│   (port 9090)    │     │  PostgreSQL     │
│  (Honeypot)     │     │                  │     │  ─────────────  │
├─────────────────┤     │                  │     │  hosts          │
│  PowerShell     │────▶│                  │     │  network_flows  │
│  Agent (Win)    │     │                  │     │  findings       │
├─────────────────┤     │                  │     │  indicators     │
│  ASM Probe      │────▶│                  │     │  decoys         │
│  + bash wrapper │     └──────────────────┘     └─────────────────┘
└─────────────────┘                                      │
                                                   ┌────▼────┐
                                                   │  Web UI │
                                                   │ (8082)  │
                                                   └─────────┘
```

## Components

### Collector (Go) — port `9090`
Ingests flow telemetry from agents via HTTP POST. Binds to `0.0.0.0` by default so remote agents can reach it.
- `POST /ingest/flow` — receive flow events (JSON, auth via `COLLECTOR_TOKEN`)
- `GET /healthz` — liveness check
- `GET /readyz` — readiness check (includes DB ping)

### PHP API — port `8081`
Serves REST endpoints backed by PostgreSQL. Binds to `0.0.0.0` for remote access.
- `GET /findings` — latest 100 findings
- `GET /flows` — latest 100 network flows (with hostnames)
- `GET /indicators` — latest 100 indicators

### Web UI — port `8082`
Static HTML/CSS/JS dashboard that polls the API every 5 seconds. Auto-detects same-origin `/api` or falls back to `http://127.0.0.1:8081`.

### Agents (Real Telemetry, Not Sandboxed)

| Agent | Platform | Data Source | Output |
|-------|----------|-------------|--------|
| **C Agent** | Linux | `/proc/net/tcp`, `/proc/net/udp` | Real TCP/UDP connections (JSON Lines) |
| **C++ Decoy** | Linux | Socket accept | SSH honeypot, POSTs interactions to collector |
| **PowerShell Agent** | Windows | `Get-NetTCPConnection` | Real TCP connections, posted to collector |
| **ASM Probe** | Linux x86_64 | `/proc` via assembly | Hostname/PID output + bash wrapper for `ss` data |
| **Shell Agent** | Linux | `ss` command | Real connection telemetry via bash/curl |

### Orchestrator (Python)
Runs YAML playbooks against the telemetry database to detect threats like credential stuffing.
- Connects directly to PostgreSQL
- Runs SQL queries and inserts findings based on thresholds

## Quick Start

```bash
# 1. Prerequisites
#    - Go 1.20+, PHP 8.1+ with pgsql PDO, Python 3.8+, PostgreSQL 13+
#    - psql and createdb CLI tools

# 2. Configure environment
#    Copy or edit .env at the repo root:
#      PGHOST=lpghost
#      PGPORT=5432
#      PGDATABASE=pgdatabase
#      PGUSER=pguser
#      PGPASSWORD=pgpassword
#      COLLECTOR_TOKEN="your-secret-token"

# 3. Bootstrap everything
bash scripts/dev_bootstrap.sh
```

After bootstrap:
- **Collector**: http://0.0.0.0:9090/healthz
- **PHP API**: http://0.0.0.0:8081/findings
- **Dashboard**: http://127.0.0.1:8082/index.html

## Remote Agent Configuration

Agents can connect from anywhere on the network:

```bash
# On any Linux machine with the C agent built:
export COLLECTOR_URL="http://<collector-host>:9090/ingest/flow"
bash agents/scripts/agent_linux.sh --loop

# Or run just once:
bash agents/scripts/agent_linux.sh --once
```

For Windows agents:
```powershell
$env:COLLECTOR_URL = "http://<collector-host>:9090/ingest/flow"
.\agents\scripts\agent_windows.psl
```

For the C++ decoy (honeypot):
```bash
export COLLECTOR_URL="http://<collector-host>:9090/ingest/flow"
export HOSTNAME="$(hostname)"
./agents/cpp_decoy/decoy 2222
```

## Manual Run (without bootstrap)

```bash
# 1. Run migrations
bash scripts/migrate_up.sh

# 2. Start collector
cd collector
COLLECTOR_BIND="0.0.0.0:9090" go run main.go

# 3. Start PHP API (separate terminal)
cd web/api
php -S 0.0.0.0:8081

# 4. Serve UI (separate terminal)
cd web/ui
python3 -m http.server 8082

# 5. Open http://127.0.0.1:8082/index.html
```

## Sending Test Events

```bash
# Linux/macOS
bash scripts/send_test_event.sh

# Windows (PowerShell)
.\scripts\Send-Test-Event.psl
```

## Running the Orchestrator

```bash
cd orchestrator
pip install pyyaml psycopg2-binary
python playbook_runner.py
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/findings` | Latest 100 findings |
| `GET` | `/flows` | Latest 100 flows |
| `GET` | `/indicators` | Latest 100 indicators |
| `POST` | `/ingest/flow` | Ingest a flow event (requires `Authorization: Bearer <token>`) |
| `GET` | `/healthz` | Liveness check |
| `GET` | `/readyz` | Readiness check |

## Flow Event Schema

Agents send JSON events to `POST /ingest/flow`:

```json
{
  "hostname": "server-01",
  "platform": "linux",
  "src_ip": "10.0.0.5",
  "src_port": 54321,
  "dst_ip": "8.8.8.8",
  "dst_port": 53,
  "protocol": "udp",
  "direction": "egress",
  "bytes_tx": 512,
  "bytes_rx": 1024
}
```

## Security Notes

- **CORS is permissive** — intended for internal network use. Harden with a reverse proxy (nginx, Caddy) before exposing to the internet.
- **Collector uses Bearer token auth** — set `COLLECTOR_TOKEN` in your `.env` file.
- **PostgreSQL should be firewalled** — the API is the only component that should connect to it directly.
- **No TLS by default** — use a reverse proxy for HTTPS termination in production.

## Troubleshooting

- **Logs**: `logs/collector.log`, `logs/api.log`, `logs/ui.log`
- **Port conflicts**: Default ports are 9090 (collector), 8081 (API), 8082 (UI)
- **DB unavailable**: The API degrades gracefully and returns empty lists
- **C agent won't build**: Ensure `gcc` is installed. The agent uses standard POSIX APIs.

