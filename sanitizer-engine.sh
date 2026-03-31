#!/bin/bash
# filepath: /Users/zler/sanitizer-engine/sanitizer-engine.sh
set -o pipefail

MAX_ENTROPY="${MAX_ENTROPY:-7.5}"
TOPIC_IN="${TOPIC_IN:-sanitizer_in}"
AIENGINE_TOPIC_IN="${AIENGINE_TOPIC_IN:-aiengine_in}"

: "${DB_HOST:=localhost}"
: "${DB_USER:=user}"
: "${DB_PASSWORD:=password}"
: "${DB_NAME:=sanitizer_db}"
: "${KAFKA_BOOTSTRAP:=localhost:9092}"
: "${SANITIZER_TMP_BASE:=/tmp/sanitizer_engine}"
trap 'rm -rf "${SANITIZER_TMP_BASE%/}"/job_* 2>/dev/null' EXIT
source "libs/db_lib.sh"
source "libs/san_lib.sh"
source "libs/kafka_lib.sh"

# Main loop: consume from Kafka topic
msg="$(consume_messages "$TOPIC_IN" 10000 1 || true)"

if [[ -z "$msg" ]]; then
  echo "No message received from topic: $TOPIC_IN"
  exit 0
fi

#echo "Received message: $msg"
sanitized_msg="$(sanitize_message "$msg")"
echo "Sanitized message: $sanitized_msg"
json="$(printf '%s' $sanitized_msg)"
publish_message "$AIENGINE_TOPIC_IN" "$json"
echo "Published sanitized message to topic: $AIENGINE_TOPIC_IN"

