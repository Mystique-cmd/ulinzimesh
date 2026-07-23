#!/usr/bin/env bash

set -euo pipefail

#---------Config (env-overridable)------
COLLECTOR_URL="${COLLECTOR_URL:-http://127.0.0.1:9090/ingest/flow}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT_BIN="${AGENT_BIN:-$REPO_ROOT/agents/c_agent/agent}"
BUILD_SCRIPT="${BUILD_SCRIPT:-$REPO_ROOT/agents/c_agent/build.sh}"
SPOOL_DIR="${SPOOL_DIR:-$REPO_ROOT/spool}"
LOG_PREFIX="[agent_linux.sh]"

#---------Helpers------
log() {
    printf "%s %s %s\n" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$LOG_PREFIX" "$*" >&2
}

need_cmd(){
    command -v "$1" > /dev/null 2>&1 || { log "missing dependency: $1"; exit 1; }
}

ensure_agent(){
    if [[ ! -x "$AGENT_BIN" ]]; then
        if [[ -f "$BUILD_SCRIPT" ]]; then
            log "agent binary missing; attempting to build via $BUILD_SCRIPT"
            bash "$BUILD_SCRIPT"
        else
            log "agent binary not found and no build script present: $AGENT_BIN"
            exit 1
        fi
    fi
}

ensure_spool(){
    mkdir -p "$SPOOL_DIR/outbox" "$SPOOL_DIR/failed"
}

post_json(){
    local json="$1"
    curl --fail --silent --show-error \
        --max-time 10 \
        -H "Content-Type: application/json" \
        -X POST "$COLLECTOR_URL" \
        --data-binary @- <<<"$json"
}

spool_event(){
    local json="$1"
    local ts fname
    ts="$(date -u +'%Y%m%dT%H%M%S')"
    fname="$SPOOL_DIR/outbox/${ts}_$$.json"
    printf "%s\n" "$json" > "$fname"
    log "spooled event -> $fname"
}

flush_spool(){
    shopt -s nullglob
    local files=("$SPOOL_DIR"/outbox/*.json)
    ((${#files[@]} == 0)) && return 0
    log "flushing ${#files[@]} spooled events"
    for f in "${files[@]}"; do
        if post_json "$(cat "$f")"; then
            rm -f -- "$f"
        else    
            log "flush failed for $f; will retry later"
            mv "$f" "$SPOOL_DIR/failed/$(basename "$f").retry.$(date +%s)" || true
            return 1
        fi
    done
    return 0
}

# Capture real network telemetry using ss (modern netstat replacement)
capture_real_flows(){
    local hostname="$1"
    local platform="$2"

    ss -tuanp 2>/dev/null | awk -v hn="$hostname" -v pl="$platform" '
    NR > 1 {
        state = $1
        local_addr = $4
        peer_addr = $5

        # Skip listening sockets
        if (state == "LISTEN" || state == "LISTEN,") next

        split(local_addr, la, ":")
        split(peer_addr, pa, ":")

        src_ip = la[1]
        src_port = la[2]
        dst_ip = pa[1]
        dst_port = pa[2]

        # Skip unconnected
        if (dst_ip == "0.0.0.0" && dst_port == "0") next
        if (dst_ip == "::" && dst_port == "0") next

        # Protocol detection
        proto = "tcp"
        if (index($0, "udp") > 0) proto = "udp"

        # Direction
        direction = "egress"
        if (state == "CLOSE-WAIT" || state == "LAST-ACK") direction = "ingress"

        printf "{\"hostname\":\"%s\",\"platform\":\"%s\",", hn, pl
        printf "\"src_ip\":\"%s\",\"src_port\":%s,", src_ip, src_port
        printf "\"dst_ip\":\"%s\",\"dst_port\":%s,", dst_ip, dst_port
        printf "\"protocol\":\"%s\",\"direction\":\"%s\",", proto, direction
        printf "\"bytes_tx\":0,\"bytes_rx\":0}"
        printf "\n"
    }' 2>/dev/null || true
}

run_once(){
    local json
    local hostname
    hostname="$(hostname 2>/dev/null || echo 'unknown')"
    local platform="linux"

    # First, capture real network flows
    local real_flows
    real_flows="$(capture_real_flows "$hostname" "$platform")"

    # Also get the C agent output for host metadata
    if [[ -x "$AGENT_BIN" ]]; then
        json="$("$AGENT_BIN")"
    fi

    # If we have real flows, post each one; otherwise fall back to agent output
    if [[ -n "$real_flows" ]]; then
        while IFS= read -r flow; do
            if [[ -n "$flow" ]]; then
                if post_json "$flow"; then
                    log "posted real flow event"
                else
                    log "post failed; spooling"
                    spool_event "$flow"
                fi
            fi
        done <<< "$real_flows"
    elif [[ -n "$json" ]]; then
        if post_json "$json"; then
            log "posted agent event successfully"
        else
            log "post failed; spooling"
            spool_event "$json"
        fi
    else
        log "no telemetry data to send"
        # Send a minimal synthetic event to keep pipeline alive
        local synthetic='{"hostname":"'"$hostname"'","platform":"linux","src_ip":"127.0.0.1","src_port":0,"dst_ip":"127.0.0.1","dst_port":0,"protocol":"tcp","direction":"egress","bytes_tx":0,"bytes_rx":0}'
        if post_json "$synthetic"; then
            log "posted synthetic event (no real data available)"
        else
            log "post failed for synthetic event; spooling"
            spool_event "$synthetic"
        fi
    fi
}

run_loop(){
    local interval="${INTERVAL:-5}"
    local backoff=1
    while true; do
        if flush_spool; then backoff=1; fi
        run_once
        sleep "$backoff"
        backoff=$(( backoff < 60 ? backoff * 2 : 60))
        sleep "$interval"
    done
}

usage(){
    cat << EOF
Usage: $(basename "$0") [--once|--loop] [--interval N]
Env:
    COLLECTOR_URL (default: $COLLECTOR_URL)
    AGENT_BIN     (default: $AGENT_BIN)
    SPOOL_DIR     (default: $SPOOL_DIR)
    INTERVAL      loop interval seconds (default: 5)
EOF
}

#-------Main ------
need_cmd curl
ensure_agent
ensure_spool
flush_spool || true

mode="once"
while [[ $# -gt 0 ]]; do
    case "$1" in
        (--once) mode="once"; shift ;;
        (--loop) mode="loop"; shift ;;
        (--interval) INTERVAL="$2"; shift 2 ;;
        (-h |--help) usage; exit 0 ;;
        (*) log "unknown arg: $1"; usage; exit 1 ;;
    esac
done

if [[ "$mode" == "once" ]]; then
    run_once
else
    run_loop
fi

