#!/bin/bash

# Configuration
QUARANTINE_DIR="./quarantine"
OUTPUT_DIR="./sanitized_output"

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
    sed -E 's/(password|passwd|token|auth|secret)=[^ ]*/\1=REDACTED/gI' | \
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