#!/bin/bash
set -euo pipefail
set -o pipefail

FILE="2-csv-20260316221533.csv"
DB_NAME="sanitizer_db"
PRIORITY="1"
USER_ID="2"
FILE_NAME="$(basename "$FILE")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../libs/db_lib.sh
source "${SCRIPT_DIR}/../libs/db_lib.sh"


# Run your aiSanitizerEngine logic (e.g., masking IPs)
sed -i '' 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/[MASKED_IP]/g' "$FILE"

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


update_job_request_status "$JOB_ID" "COMPLETED"
echo "Updated job_request.id=${JOB_ID} status to COMPLETED"


delete_job_request_by_id "$JOB_ID"
echo "Deleted job_request.id=${JOB_ID}"

echo ${JOB_ID}
