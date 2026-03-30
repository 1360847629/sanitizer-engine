#!/bin/bash
set -euo pipefail
set -o pipefail

FILE="samplescript/2-csv-20260316221533.csv"
DB_NAME="sanitizer_db"
PRIORITY="1"
USER_ID="2"
FILE_NAME="$(basename "$FILE")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../libs/db_lib.sh
source "${SCRIPT_DIR}/libs/db_lib.sh"
source "${SCRIPT_DIR}/libs/kafka_lib.sh"

# Encode file once
B64_DATA="$(base64 < "$FILE" | tr -d '\n')"

insert_job_request "$B64_DATA"

ROW="$(read_latest_job_request)"

if [[ -z "$ROW" ]]; then
  echo "No rows found in job_request" >&2
  exit 1
fi

IFS=$'\t' read -r JOB_ID FILE_NAME CONTENT_TYPE FILE_CONTENT_B64 <<< "$ROW"

if [[ -z "${FILE_CONTENT_B64:-}" ]]; then
  echo "Empty blob content for job_request.id=${JOB_ID}" >&2
  exit 1
fi

echo "job_id=${JOB_ID} file_name=${FILE_NAME} content_type=${CONTENT_TYPE}"

printf '%s' "$FILE_CONTENT_B64" | openssl base64 -d -A > test_output.csv
echo "Blob content written to test_output.csv"
echo "$FILE_CONTENT_B64"

json_message="$(build_message \
  "$FILE_CONTENT_B64" \
  "$INPUT_TOPIC" \
  "$MESSAGE_ORIGIN" \
  "$MESSAGE_SOURCE" \
  "$MESSAGE_TYPE")"

publish_message "$INPUT_TOPIC" "$json_message"

echo "Published message to topic: $INPUT_TOPIC"



update_job_request_status "$JOB_ID" "$STATUS_SANITIZING"
echo "Updated job_request.id=${JOB_ID} status to $STATUS_SANITIZING"


#delete_job_request_by_id "$JOB_ID"
#echo "Deleted job_request.id=${JOB_ID}"

echo ${JOB_ID}
