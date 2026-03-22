#!/bin/bash
# filepath: /Users/zler/sanitizer-engine/sanitizer-engine.sh
set -o pipefail

MAX_ENTROPY="${MAX_ENTROPY:-7.5}"
POLL_INTERVAL="${POLL_INTERVAL:-2}"
BATCH_SIZE="${BATCH_SIZE:-25}"
PENDING_STATUS="${PENDING_STATUS:-PENDING}"
PROCESSING_STATUS="${PROCESSING_STATUS:-PROCESSING}"
JOB_STATUS_COMPLETE="${JOB_STATUS_COMPLETE:-COMPLETED}"
JOB_STATUS_FAILED="${JOB_STATUS_FAILED:-QUARANTINED}"
TOPIC_CLEAN="${TOPIC_CLEAN:-sanitized_stream}"
YARA_RULES="${YARA_RULES:-/app/rules/rules.yar}"

: "${DB_HOST:=localhost}"
: "${DB_USER:=user}"
: "${DB_PASSWORD:=password}"
: "${DB_NAME:=sanitizer_db}"

# Required env: KAFKA_BOOTSTRAP
trap 'rm -f /dev/shm/tmp_*' EXIT

mysql_exec() {
  mysql -N -B -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -D "$DB_NAME" -e "$1"
}

mark_failed() {
  local id="$1"
  mysql_exec "UPDATE job_request SET status='${JOB_STATUS_FAILED}' WHERE id=${id};" >/dev/null
}

while true; do
  mysql_exec "
    SELECT id,
           COALESCE(file_name, CONCAT('job_', id)),
           REPLACE(TO_BASE64(file_blob), '\n', '')
    FROM job_request
    WHERE status='${PENDING_STATUS}'
    ORDER BY id
    LIMIT ${BATCH_SIZE};
  " | while IFS=$'\t' read -r job_id file_name payload_b64; do
    [[ -z "$job_id" || -z "$payload_b64" ]] && continue

    # Optimistic lock: claim only if still PENDING.
    claimed="$(mysql_exec "
      UPDATE job_request
      SET status='${PROCESSING_STATUS}'
      WHERE id=${job_id} AND status='${PENDING_STATUS}';
      SELECT ROW_COUNT();
    " | tail -n1)"
    [[ "$claimed" != "1" ]] && continue

    # Entropy gate (stdin -> Python helper). Protocol: echo "$BASE64_DATA" | base64 -d | python3 entropy_check.py
    if ! entropy_out=$(echo "$payload_b64" | base64 -d | python3 entropy_check.py "$MAX_ENTROPY" 2>&1); then
      echo "failed(entropy): id=${job_id} msg=${entropy_out}" >&2
      mark_failed "$job_id"
      continue
    fi

    # MIME validation.
    mime_type="$(file -b --mime-type <(echo "$payload_b64" | base64 -d) 2>/dev/null || true)"
    [[ -z "$mime_type" ]] && { echo "failed(mime): id=${job_id}" >&2; mark_failed "$job_id"; continue; }

    # YARA scan (process substitution, no disk I/O).
    if ! yara_out="$(yara "$YARA_RULES" <(echo "$payload_b64" | base64 -d) 2>/dev/null)"; then
      echo "failed(yara-error): id=${job_id}" >&2
      mark_failed "$job_id"
      continue
    fi
    [[ -n "$yara_out" ]] && { echo "failed(yara-hit): id=${job_id} hit=${yara_out}" >&2; mark_failed "$job_id"; continue; }

    # Metadata scrub (Exif) for common metadata-bearing types; passthrough otherwise.
    case "$mime_type" in
      image/*|application/pdf)
        sanitized_b64="$(
          exiftool -all= -o - <(echo "$payload_b64" | base64 -d) 2>/dev/null \
          | base64 | tr -d '\n'
        )"
        ;;
      *)
        sanitized_b64="$payload_b64"
        ;;
    esac
    [[ -z "$sanitized_b64" ]] && { echo "failed(sanitize): id=${job_id}" >&2; mark_failed "$job_id"; continue; }

    # Publish only after all checks pass.
    msg="$(jq -nc \
      --arg filename "$file_name" \
      --arg payload "$sanitized_b64" \
      --arg status "$JOB_STATUS_COMPLETE" \
      '{filename:$filename, payload:$payload, status:$status}')"

    if ! echo "$msg" | kafka-console-producer --bootstrap-server "$KAFKA_BOOTSTRAP" --topic "$TOPIC_CLEAN" >/dev/null; then
      echo "failed(kafka): id=${job_id}" >&2
      mark_failed "$job_id"
      continue
    fi

    mysql_exec "UPDATE job_request SET status='${JOB_STATUS_COMPLETE}' WHERE id=${job_id};" >/dev/null
  done

  sleep "$POLL_INTERVAL"
done