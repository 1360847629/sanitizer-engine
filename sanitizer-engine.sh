#!/bin/bash
# filepath: /Users/zler/sanitizer-engine/sanitizer-engine.sh
set -o pipefail

MAX_ENTROPY="${MAX_ENTROPY:-7.5}"
BATCH_SIZE="${BATCH_SIZE:-25}"
JOB_STATUS_COMPLETE="${JOB_STATUS_COMPLETE:-COMPLETED}"
JOB_STATUS_FAILED="${JOB_STATUS_FAILED:-QUARANTINED}"
TOPIC_IN="${TOPIC_IN:-sanitizer_in}"
TOPIC_CLEAN="${TOPIC_CLEAN:-sanitized_stream}"
YARA_RULES="${YARA_RULES:-/app/rules/rules.yar}"

: "${DB_HOST:=localhost}"
: "${DB_USER:=user}"
: "${DB_PASSWORD:=password}"
: "${DB_NAME:=sanitizer_db}"
: "${KAFKA_BOOTSTRAP:=localhost:9092}"

# New variables for line 27 behavior
CONSUME_TOPIC="${CONSUME_TOPIC:-$INPUT_TOPIC}"
CONSUME_TIMEOUT_MS="${CONSUME_TIMEOUT_MS:-10000}"
CONSUME_MAX_MESSAGES="${CONSUME_MAX_MESSAGES:-1}"
AIENGINE_TOPIC_IN="${AIENGINE_TOPIC_IN:-aiengine_in}"

trap 'rm -f /dev/shm/tmp_*' EXIT
source "libs/db_lib.sh"
source "libs/san_lib.sh"
source "libs/kafka_lib.sh"

# Main loop: consume, sanitize, then publish to AI Engine topic
consume_messages "$CONSUME_TOPIC" "$CONSUME_TIMEOUT_MS" "$CONSUME_MAX_MESSAGES" | while read -r msg; do
  [[ -z "$msg" ]] && continue

  if sanitized_msg="$(sanitize_message "$msg")"; then
    [[ -z "$sanitized_msg" ]] && continue
    publish_message "$AIENGINE_TOPIC_IN" "$sanitized_msg"
    echo "Published sanitized message to topic: $AIENGINE_TOPIC_IN"
  fi
done
