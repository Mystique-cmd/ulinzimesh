#!/usr/bin/bash

set -euo pipefail

#---------Config (env-overridable)------
COLLECTOR_URL="${COLLECTOR_URL:-http://127.0.0.1:9090/ingest/flow}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT_BIN="${AGENT_BIN:-$REPO_ROOT/agents/c_agent/agent}"
BUILD_SCRIPT="${BUILD_SCRIPT:-$REPO_ROOT/build_scripts/build_agent.sh}"
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
        if [[ -f "$BUILD_SCRIPT" ]];then
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
        --data-binary @- <<<"json"
}

spool_event(){
    local json="$1"
    local ts fname
    ts="$(date -u +'%Y%m%dT%H%M%S')"
    fname="$SPOOL_DIR/outbox/${ts}_$$.json"
    printf "%s\n" "$json" > "$fname"
    log "spooled event" -> "$fname"
}

flush_spool(){
    shopt -s nullglob
    local files=("$SPOOL_DIR"/outbox/*.json)
    ((${#files[@]} == 0 )) && return 0
    log "flushing ${#files[@]} spooled events"
    for f in "${#files[@]}"; do
        if post_json "$(cat "$f")"; then
            rm -f -- "$f"
        else    
            log "flush failed for "$f"; will retry later"
            mv "$f" "$SPOOL_DIR/failed/$(basename "$f").retry.$(date +%s)" || true
            return 1
        fi
    done
    return 0
}

run_once(){
    local json
    json="$("$AGENT_BIN")"
    if [[ -z "$json" ]]; then
        log "agent produced empty JSON; aborting"
        exit 1
    fi
    if post_json "$json"; then
        log "posted event successfully"
    else
        log "post failed; spooling"
        spool_event "$json"
    fi
}

run_loop(){
    local interval="${INTERNAL:-5}"
    local backoff=1
    while true;do
        if flush_spool; then backoff=1;fi
        if "$AGENT_BIN" | post_json; then
            log "posted event"
            backoff=1
        else
            log "post failed; reading JSON from agent and spooling"
            spool_event "$("$AGENT_BIN")"
            sleep "$backoff"; backoff=$(( backoff < 60 ? backoff * 2 : 60))
        fi
        sleep "$interval"
    done
}

usage(){
    cat << EOF
Usage: $(basename "$0")[--once|--loop][--interval N]
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
interval_set="false"
while [[ $# -gt 0 ]]; do
    case "$1" in
        (--once) mode="once"; shift ;;
        (--loop) mode="loop"; shift ;;
        (--interval) INTERVAL="$2"; interval_set="true"; shift 2 ;;
        (-h |--help) usage; exit 0 ;;
        (*) log "unknown arg: $1"; usage; exit 1 ;;
    esac
done

if [[ "$mode" == "once" ]]; then
    run_once
else
    run_loop
fi
