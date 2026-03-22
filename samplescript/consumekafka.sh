#!/bin/bash

set -euo pipefail
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/Users/zler/sanitizer-engine/samplescript/lib/kafka_lib.sh
source "$SCRIPT_DIR/libs/kafka_lib.sh"

CONSUME_TOPIC="${CONSUME_TOPIC:-sanitizer_in}"
DECODE_PAYLOAD="${DECODE_PAYLOAD:-false}"

usage() {
  echo "Usage:"
  echo "  $0 [topic] [max_messages] [timeout_seconds]"
  echo ""
  echo "Environment overrides:"
  echo "  CONSUME_TOPIC         Topic to consume from  (default: sanitizer_in)"
  echo "  CONSUME_MAX_MESSAGES  Max messages to read   (default: $CONSUME_MAX_MESSAGES)"
  echo "  CONSUME_TIMEOUT       Timeout in seconds     (default: $CONSUME_TIMEOUT)"
  echo "  DECODE_PAYLOAD        Decode base64 payload  (default: false)"
  echo "  KAFKA_BOOTSTRAP_SERVERS                      (default: localhost:9092)"
}

main() {
  require_cmd jq
  require_cmd kcat
  require_cmd python3
  require_cmd base64

  local topic="${1:-$CONSUME_TOPIC}"
  local max_messages="${2:-$CONSUME_MAX_MESSAGES}"
  local timeout="${3:-$CONSUME_TIMEOUT}"
  local count=0

  echo "[INFO] Consuming from topic: $topic"
  echo "[INFO] Bootstrap: $KAFKA_BOOTSTRAP_SERVERS"
  echo "[INFO] Max messages: $max_messages | Timeout: ${timeout}s"
  echo "---"

  while IFS= read -r raw_message; do
    [[ -z "$raw_message" ]] && continue

    count=$((count + 1))
    echo "[MSG #$count]"

    pretty_print_message "$raw_message"

    if [[ "$DECODE_PAYLOAD" == "true" ]]; then
      echo ""
      echo "[DECODED PAYLOAD #$count]"
      if ! decode_payload "$raw_message"; then
        echo "[WARN] Could not decode payload for message #$count" >&2
      fi
    fi

    echo "---"
  done < <(consume_messages "$topic" "$timeout" "$max_messages")

  echo "[INFO] Consumed $count message(s) from topic: $topic"
}

main "$@"