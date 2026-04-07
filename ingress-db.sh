#!/bin/bash
set -euo pipefail

PRIORITY="1"
USER_ID="2"
: "${POLL_INTERVAL:=5}"
: "${STATUS_AI_PROCESSING_PENDING:=AI_PROCESSING_PENDING}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../libs/db_lib.sh
source "${SCRIPT_DIR}/libs/db_lib.sh"
source "${SCRIPT_DIR}/libs/kafka_lib.sh"
source "${SCRIPT_DIR}/libs/san_lib.sh"

trap 'rm -f /dev/shm/tmp_*' EXIT

# Process one pending job from job_request.
# Returns 0 if a job was found and processed (success or error), 1 if no pending jobs exist.
process_pending_job() {
  local ROW
  ROW="$(read_latest_job_request)" || return 1

  if [[ -z "$ROW" ]]; then
    return 1
  fi

  local JOB_ID FILE_NAME CONTENT_TYPE FILE_CONTENT_B64
  IFS=$'\t' read -r JOB_ID FILE_NAME CONTENT_TYPE FILE_CONTENT_B64 <<< "$ROW"

  update_job_request_status "$JOB_ID" "$STATUS_SANITIZING"

  if [[ -z "${FILE_CONTENT_B64:-}" ]]; then
    echo "Empty blob content for job_request.id=${JOB_ID}" >&2
    update_job_request_status "$JOB_ID" "$STATUS_COMPLETED_WITH_WARNINGS"
    insert_job_execution_log "$STATUS_COMPLETED_WITH_WARNINGS" "Empty blob content for job_request.id=${JOB_ID}" "$JOB_ID"
    return 0
  fi

  echo "job_id=${JOB_ID} file_name=${FILE_NAME} content_type=${CONTENT_TYPE}"
  insert_job_execution_log "$STATUS_SANITIZING" "Started sanitizing job_request.id=${JOB_ID}" "$JOB_ID"

  local sanitized_msg
  if ! sanitized_msg="$(sanitize_base64 "$FILE_CONTENT_B64" "$JOB_ID" "$CONTENT_TYPE")"; then
    echo "Sanitization failed for job_request.id=${JOB_ID}" >&2
    update_job_request_status "$JOB_ID" "$STATUS_ERROR"
    insert_job_execution_log "$STATUS_ERROR" "Sanitization failed for job_request.id=${JOB_ID}" "$JOB_ID"
    return 0
  fi

  echo "Sanitized message: $sanitized_msg"

  local json_message
  if ! json_message="$(build_message \
    "$sanitized_msg" \
    "$INPUT_TOPIC" \
    "$MESSAGE_ORIGIN" \
    "$MESSAGE_SOURCE" \
    "$MESSAGE_TYPE" \
    "$JOB_ID" \
    "$CONTENT_TYPE" \
    "$FILE_NAME")"; then
    echo "Failed to build message for job_request.id=${JOB_ID}" >&2
    update_job_request_status "$JOB_ID" "$STATUS_ERROR"
    insert_job_execution_log "$STATUS_ERROR" "Failed to build message for job_request.id=${JOB_ID}" "$JOB_ID"
    return 0
  fi

  if ! publish_message "$INPUT_TOPIC" "$json_message"; then
    echo "Failed to publish message for job_request.id=${JOB_ID}" >&2
    update_job_request_status "$JOB_ID" "$STATUS_ERROR"
    insert_job_execution_log "$STATUS_ERROR" "Failed to publish message to topic: $INPUT_TOPIC for job_request.id=${JOB_ID}" "$JOB_ID"
    return 0
  fi

  echo "Published message to topic: $INPUT_TOPIC"
  echo "Message meta: origin=$MESSAGE_ORIGIN, source=$MESSAGE_SOURCE, type=$CONTENT_TYPE"
  insert_job_execution_log "$STATUS_SANITIZING" "Published message to topic: $INPUT_TOPIC with meta: origin=$MESSAGE_ORIGIN, source=$MESSAGE_SOURCE, type=$MESSAGE_TYPE" "$JOB_ID"
  echo "Pretty-printed message:"
  pretty_print_message "$json_message"

  update_job_request_status "$JOB_ID" "$STATUS_AI_PROCESSING_PENDING"
  echo "Updated job_request.id=${JOB_ID} status to $STATUS_AI_PROCESSING_PENDING"
  insert_job_execution_log "$STATUS_SANITIZING" "Updated job_request.id=${JOB_ID} status to $STATUS_AI_PROCESSING_PENDING" "$JOB_ID"
}

echo "[*] Starting ingress-db monitor (poll interval: ${POLL_INTERVAL}s)..."

while true; do
  if ! process_pending_job; then
    echo "[*] No pending jobs. Sleeping ${POLL_INTERVAL}s..."
    sleep "$POLL_INTERVAL"
  fi
done