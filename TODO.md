# TODO: Remove Sandboxing → Real-World Production Readiness

## Step 1: Collector - Bind to `0.0.0.0` for remote agent access
- [x] Change default `COLLECTOR_BIND` from `127.0.0.1:9090` to `0.0.0.0:9090`

## Step 2: C Agent - Real network flow capture
- [x] Fix platform detection bug (`strstr` writes to hostname instead of platform)
- [x] Replace dummy data with real `/proc/net/tcp` & `/proc/net/udp` parsing

## Step 3: C++ Decoy - Send real interactions to collector
- [x] Add HTTP POST capability to send decoy interactions to collector
- [x] Add configurable collector URL via env var `COLLECTOR_URL`

## Step 4: ASM Agent - Add wrapper for real telemetry
- [x] Too low-level for HTTP, add bash wrapper that pipes output + real net data

## Step 5: PowerShell Agent - Real TCP connection capture
- [x] Replace dummy data with `Get-NetTCPConnection` for real flows

## Step 6: Agent Linux Script - Fix bugs + real capture
- [x] Fix `post_json` bug: `<<<"json"` → `<<<"$json"`
- [x] Fix spool flush glob: `"${#files[@]}"` → `"${files[@]}"`
- [x] Fix `run_loop` double-execution bug
- [x] Add real telemetry capture using `ss` command

## Step 7: Test Event Script - Fix protocol field + field names
- [x] Change protocol from `17` (UDP number) to `"udp"` (string)
- [x] Fix `dest_ip`/`dest_port` → `dst_ip`/`dst_port` in Send-Test-Event.psl
- [x] Fix `https://` → `http://` in Send-Test-Event.psl

## Step 8: Orchestrator - Fix tuple bug
- [x] Fix `context["suspicious_ips"]` assigned as tuple → list of dicts
- [x] Fix insert SQL syntax error (extra quote + missing opening paren)
- [x] Fix unused `dest_ip` var → use `sensitive_ports` var

## Step 9: Credential alignment across all files
- [x] `config.php`: defaults → admin/admin/ulinzimesh
- [x] `playbook_runner.py`: defaults → admin/admin/ulinzimesh
- [x] `cred_stuffing.yaml`: login → admin/admin/ulinzimesh + env-based PGHOST
- [x] `migrate_down.sh`: defaults → admin/admin/ulinzimesh
- [x] `collector/main.go`: mustOpenDB defaults → admin/admin/ulinzimesh
- [x] Fix direction validation bug: `"ingeress"` → `"ingress"` in collector

## Step 10: Bootstrap - Allow remote collector URL configuration
- [x] Pass `COLLECTOR_BIND`, `PG*`, `COLLECTOR_TOKEN` env vars through to collector
- [x] PHP API now binds to `0.0.0.0:8081` for remote access
- [x] Add informative output about remote agent configuration

