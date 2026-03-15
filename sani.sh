#!/bin/bash

# Configuration
QUARANTINE_DIR="./quarantine"
OUTPUT_DIR="./sanitized_output"
mkdir -p "$QUARANTINE_DIR" "$OUTPUT_DIR"

# --- Verification Functions ---

verify_log() {
    local file=$1
    local type=$2
    echo "[*] Verifying $file as $type..."

    case "$type" in
        PCAP|PCAPNG|CAP)
            # Check magic bytes for pcap (0xa1b2c3d4) or pcapng (0x0a0d0d0a)
            if file "$file" | grep -qiE "capture|pcap"; then return 0; fi
            ;;
        JSON)
            if jq empty "$file" 2>/dev/null; then return 0; fi
            ;;
        CSV|LOG)
            # Ensure it is a text file and not a renamed binary
            if file "$file" | grep -qi "text"; then return 0; fi
            ;;
        EVTX)
            # Windows Event Logs start with the "ElfChnk" signature
            if head -c 4 "$file" | grep -q "Elf"; then return 0; fi
            ;;
        *)
            echo "[!] Unknown LogType: $type"
            return 1
            ;;
    esac
    return 1
}

# --- Sanitization Functions ---

sanitize_pcap() {
    local in=$1
    local out="$OUTPUT_DIR/$(basename "$1")"
    # -s 96 truncates the payload, keeping only headers (Ethernet/IP/TCP)
    # This removes PII/Data while preserving flow for anomaly detection
    tcpdump -r "$in" -w "$out" -s 96 2>/dev/null
    echo "[+] PCAP sanitized (Payloads stripped): $out"
}

sanitize_text() {
    local in=$1
    local out="$OUTPUT_DIR/$(basename "$1")"
    # 1. Strip CR characters to prevent Log Injection
    # 2. Mask IPv4 addresses (Example: 192.168.x.x -> 192.168.MASK.MASK)
    # 3. Remove known sensitive keywords (case-insensitive)
    sed -E 's/([0-9]{1,3}\.[0-9]{1,3})\.[0-9]{1,3}\.[0-9]{1,3}/\1.XXX.XXX/g' "$in" | \
    sed -Ei 's/(password|passwd|token|auth|secret)=[^ ]*/\1=REDACTED/gI' | \
    tr -d '\r' > "$out"
    echo "[+] Text log sanitized: $out"
}

sanitize_json() {
    local in=$1
    local out="$OUTPUT_DIR/$(basename "$1")"
    # Use jq to recursively delete sensitive keys regardless of depth
    jq 'walk(if type == "object" then del(.password, .token, .secret, .sessionID) else . end)' "$in" > "$out"
    echo "[+] JSON sanitized (Keys removed): $out"
}

# --- Main Logic ---

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <file_path> <LogType>"
    echo "Example: $0 network.pcap PCAP"
    exit 1
fi

FILE_PATH=$1
TYPE=$2

if verify_log "$FILE_PATH" "$TYPE"; then
    case "$TYPE" in
        PCAP|PCAPNG|CAP) sanitize_pcap "$FILE_PATH" ;;
        JSON)            sanitize_json "$FILE_PATH" ;;
        CSV|LOG|EVTX)    sanitize_text "$FILE_PATH" ;;
    esac
else
    echo "[!] Verification FAILED. Quarantining $FILE_PATH"
    mv "$FILE_PATH" "$QUARANTINE_DIR/"
    exit 1
fi