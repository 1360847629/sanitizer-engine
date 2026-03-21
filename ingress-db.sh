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

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <file_path> <LogType>"
    echo "Example: $0 network.pcap PCAP"
    exit 1
fi

FILE_PATH=$1
TYPE=$2

if verify_log "$FILE_PATH" "$TYPE"; then
    SANITIZED_FILE="$OUTPUT_DIR/$(basename "$FILE_PATH")"

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
            echo "[!] Unknown LogType: $TYPE"
            return 1
            ;;
    esac
else
    echo "[!] Verification FAILED. Quarantining $FILE_PATH"
    mv "$FILE_PATH" "$QUARANTINE_DIR/"
    exit 1
fi
