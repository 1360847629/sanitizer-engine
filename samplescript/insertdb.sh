#!/bin/bash
FILE="2-csv-20260316221533.csv"
DB_NAME="sanitizer_db"
PRIORITY="1"
USER_ID="2"
FILE_NAME="$(basename "$FILE")"

# Run your aiSanitizerEngine logic (e.g., masking IPs)
sed -i '' 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/[MASKED_IP]/g' "$FILE"

# Encode and insert
B64_DATA=$(base64 < "$FILE" | tr -d '\n')

mysql --protocol=TCP -h 127.0.0.1 -P 3306 -u user -D "$DB_NAME" -ppassword -e "
INSERT INTO job_request (
  file_name,
  file_content,
  file_content_content_type,
  file_type,
  status,
  request_type,
  priority,
  user_id
) VALUES (
  '$FILE_NAME',
  '$B64_DATA',
  'text/csv',
  'LOG',
  'SANITIZED',
  'SANITIZE',
  '$PRIORITY',
  '$USER_ID'
);
"