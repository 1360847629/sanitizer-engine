#!/bin/bash

# Kafka defaults (override with env vars if needed)
: "${KAFKA_BOOTSTRAP_SERVER:=localhost:9092}"
: "${KAFKA_USE_DOCKER_COMPOSE:=true}"   # true|false
: "${KAFKA_SERVICE_NAME:=kafka}"         # compose service name

kafka_topic_for_type() {
    local type="${1^^}"     # uppercase
    local direction="${2,,}" # lowercase: in|out
    case "$type:$direction" in
        SYSTEMLOG:in)   echo "systemlog_in" ;;
        SYSTEMLOG:out)  echo "systemlog_out" ;;
        NETWORKLOG:in)  echo "networklog_in" ;;
        NETWORKLOG:out) echo "network_out" ;;
        ERROR:*)        echo "error" ;;
        *)              return 1 ;;
    esac
}

_kafka_producer_cmd() {
    local topic="$1"
    if [[ "$KAFKA_USE_DOCKER_COMPOSE" == "true" ]]; then
        # for local compose setup
        echo "docker compose exec -T $KAFKA_SERVICE_NAME kafka-console-producer --bootstrap-server kafka:29092 --topic $topic"
    else
        # for native/local kafka cli
        echo "kafka-console-producer --bootstrap-server $KAFKA_BOOTSTRAP_SERVER --topic $topic"
    fi
}

send_line_to_topic() {
    local topic="$1"
    local line="$2"

    [[ -z "$topic" || -z "$line" ]] && return 1
    local cmd
    cmd="$(_kafka_producer_cmd "$topic")"

    printf '%s\n' "$line" | eval "$cmd" >/dev/null
}

send_file_to_topic() {
    local file_path="$1"
    local topic="$2"

    [[ ! -f "$file_path" ]] && { echo "[!] File not found: $file_path"; return 1; }
    [[ -z "$topic" ]] && { echo "[!] Topic is required"; return 1; }

    local cmd
    cmd="$(_kafka_producer_cmd "$topic")"

    cat "$file_path" | eval "$cmd" >/dev/null
    echo "[+] Sent file to topic: $topic ($file_path)"
}

send_json_to_topic() {
    local file_path="$1"
    local topic="$2"

    [[ ! -f "$file_path" ]] && { echo "[!] File not found: $file_path"; return 1; }
    [[ -z "$topic" ]] && { echo "[!] Topic is required"; return 1; }

    if ! command -v jq >/dev/null 2>&1; then
        echo "[!] jq is required for JSON send"
        return 1
    fi

    local cmd
    cmd="$(_kafka_producer_cmd "$topic")"

    # If JSON array => send each element as one message
    # If JSON object => send single compact object
    if jq -e 'type=="array"' "$file_path" >/dev/null 2>&1; then
        jq -c '.[]' "$file_path" | eval "$cmd" >/dev/null
    else
        jq -c '.' "$file_path" | eval "$cmd" >/dev/null
    fi

    echo "[+] Sent JSON to topic: $topic ($file_path)"
}