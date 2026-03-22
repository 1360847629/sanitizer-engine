#!/bin/bash
set -o pipefail

# --- Configuration (Defaults from copilot-instructions.md) ---
: "${DB_HOST:=localhost}"
: "${DB_USER:=user}"
: "${DB_PASSWORD:=password}"
: "${DB_NAME:=sanitizer_db}"
: "${MAX_ENTROPY:=7.5}"
: "${JOB_STATUS_COMPLETE:=COMPLETED}"
: "${JOB_STATUS_FAILED:=QUARANTINED}"
: "${PENDING_STATUS:=PENDING}"
: "${PYTHON_SCRIPT:=entropy_check.py}"

# Ensure cleanup on exit
trap 'rm -f /dev/shm/tmp_*' EXIT

# --- Database Helper ---
mysql_exec() {
    local sql="$1"
    mysql -N -B -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -D "$DB_NAME" -e "$sql"
}

# --- Main Processing Loop ---
echo "[*] Starting Entropy Processor..."
echo "[*] DB: $DB_HOST | Max Entropy: $MAX_ENTROPY"

while true; do
    # Poll for pending jobs
    # Instructions specify 'file_blob' column.
    # We use TO_BASE64 to safely transport binary data via shell variables.
    records=$(mysql_exec "SELECT id, TO_BASE64(file_blob) FROM job_request WHERE status='${PENDING_STATUS}' LIMIT 10")

    if [[ -z "$records" ]]; then
        sleep 2
        continue
    fi

    echo "$records" | while read -r job_id blob_b64; do
        [[ -z "$job_id" ]] && continue
        
        echo "[*] Processing Job ID: $job_id"

        # Python Integration Protocol:
        # 1. Pipe Base64 decoded data to Python stdin
        # 2. Capture stdout (result message)
        # 3. Check exit code: 0 = Success, 1 = Threat
        if output=$(echo "$blob_b64" | base64 -d | python3 "$PYTHON_SCRIPT" "$MAX_ENTROPY" 2>&1); then
            # Success
            echo "[+] Entropy Check Passed: $output"
            mysql_exec "UPDATE job_request SET status='${JOB_STATUS_COMPLETE}' WHERE id=${job_id};"
        else
            # Threat Detected
            echo "[!] Entropy Check Failed: $output"
            mysql_exec "UPDATE job_request SET status='${JOB_STATUS_FAILED}' WHERE id=${job_id};"
        fi
    done
done