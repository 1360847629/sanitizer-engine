#!/bin/bash

# Source sanitization library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/bin/san_lib.sh"
source "$SCRIPT_DIR/bin/kafka_lib.sh"
source "$SCRIPT_DIR/bin/db_lib.sh"
source "$SCRIPT_DIR/bin/file_lib.sh"

# Configuration
QUARANTINE_DIR="./quarantine"
OUTPUT_DIR="./sanitized_output"

mkdir -p "$QUARANTINE_DIR" "$OUTPUT_DIR"

# --- Main Logic ---

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <file_path>"
    echo "Example: $0 ./samplefiles/2-log-20260316143059.log"
    exit 1
fi

FILE_PATH="$1"

if [ ! -f "$FILE_PATH" ]; then
    echo "[!] File not found: $FILE_PATH"
    exit 1
fi

FILENAME="$(basename "$FILE_PATH")"

# Expected: userid-filetype-yyyymmddhhmmss.filetype
# Capture claimed filetype from the filename and use it as TYPE.
if [[ "$FILENAME" =~ ^[^-]+-([^-]+)-[0-9]{14}\.[^.]+$ ]]; then
    TYPE="${BASH_REMATCH[1]}"
    TYPE="$(printf '%s' "$TYPE" | tr '[:lower:]' '[:upper:]')"
    echo "[*] Extracted LogType from filename: $TYPE"
else
    echo "[!] Invalid filename format: $FILENAME"
    echo "    Expected: userid-filetype-yyyymmddhhmmss.filetype"
    #mv "$FILE_PATH" "$QUARANTINE_DIR/"
    exit 1
fi

if verify_log "$FILE_PATH" "$TYPE"; then
    SANITIZED_FILE="$OUTPUT_DIR/$(basename "$FILE_PATH")"
    echo "[*] Verification PASSED. Sanitizing $FILE_PATH as type $TYPE"
    case "$TYPE" in
        PCAP|PCAPNG|CAP)
            sanitize_pcap "$FILE_PATH"
            send_file_to_topic "$SANITIZED_FILE" "networklog_in"
            ;;
        JSON)
            sanitize_json "$FILE_PATH"
            send_file_to_topic "$SANITIZED_FILE" "systemlog_in"
            ;;
        CSV|LOG|EVTX)
            sanitize_text "$FILE_PATH"
            send_file_to_topic "$SANITIZED_FILE" "systemlog_in"
            ;;
        *)
            echo "[!] Unknown LogType from filename: $TYPE"
            exit 1
            ;;
    esac
else
    echo "[!] Verification FAILED. Quarantining $FILE_PATH"
    mv "$FILE_PATH" "$QUARANTINE_DIR/"
    exit 1
fi
