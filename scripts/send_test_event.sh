#! /usr/bin/env bash

set -euo pipefail

# ------ Configuration ------
COLLECTOR_URL="${COLLECTOR_URL:-http://127.0.0.1:9090/ingest/flow}"
HOSTNAME="${HOSTNAME:-test-host}"
PLATFORM="${PLATFORM:-linux}"
COLLECTOR_TOKEN="${COLLECTOR_TOKEN:-}"

#------Dummy flow data------
SRC_IP="10.0.0.5"
DST_IP="8.8.8.8"
SRC_PORT="12345"
DST_PORT="53"
PROTO="udp"
DIRECTION="egress"
BYTES_TX="512"
BYTES_RX="1024"

#------Build JSON payload------
EVENT=$(jq -n \
   --arg hn "$HOSTNAME" \
   --arg pf "$PLATFORM" \
   --arg si "$SRC_IP" \
   --arg di "$DST_IP" \
   --arg sp "$SRC_PORT" \
   --arg dp "$DST_PORT" \
   --arg pr "$PROTO" \
   --arg dr "$DIRECTION" \
   --arg btx "$BYTES_TX" \
   --arg brx "$BYTES_RX" \
   '{
      hostname: $hn,
      platform: $pf,
      src_ip: $si,
      dst_ip: $di,
      src_port: ($sp | tonumber),
      dst_port: ($dp | tonumber),
      protocol: $pr,
      direction: $dr,
      bytes_tx: ($btx | tonumber),
      bytes_rx: ($brx | tonumber),
    }'
)

#------Send event to collector------
echo "$EVENT" | curl -sS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $COLLECTOR_TOKEN" -d @- "$COLLECTOR_URL"
echo -e "\nEvent sent to $COLLECTOR_URL"