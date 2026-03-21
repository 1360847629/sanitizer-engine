#!/bin/bash
# --- Verification Functions ---
verify_log() {
    local file=$1
    local type=$2
    echo "[*] Verifying $file as $type..."

    case "$type" in
        PCAP|PCAPNG|CAP)
            if file "$file" | grep -qiE "capture|pcap"; then return 0; fi
            ;;
        JSON)
            if jq empty "$file" 2>/dev/null; then return 0; fi
            ;;
        CSV|LOG)
            if file "$file" | grep -qi "text"; then return 0; fi
            ;;
        EVTX)
            if head -c 4 "$file" | grep -q "Elf"; then return 0; fi
            ;;
        *)
            echo "[!] Unknown LogType: $type"
            return 1
            ;;
    esac
    return 1
}