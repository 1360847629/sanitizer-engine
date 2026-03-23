Sanitizer Engine: Project Rules & Context
## Tech Stack & Environment
Orchestrator: Bash / Shell Script (#!/bin/bash)

Logic Helpers: Python 3.x (using sys.stdin.buffer for binary handling)

Database: MySQL (Table: job_request, Column: file_blob)

Messaging: Apache Kafka (JSON wrapped Base64 payloads)

Security Utilities: yara, exiftool, jq, openssl, kcat

Infrastructure: Docker Compose (Debian-slim base)

## System Parameters & Configuration
Always use environment variables for system-wide constants:

DB_HOST: Address of the MySQL instance (default: localhost).

MAX_ENTROPY: Threshold for Shannon Entropy (default: 7.5).

TOPIC_CLEAN: Destination Kafka topic for sanitized data.

JOB_STATUS_COMPLETE: Value to update job_request.status after success (e.g., COMPLETED).

JOB_STATUS_FAILED: Value to update job_request.status on threat detection (e.g., QUARANTINED).

## Python Integration Protocol
When Bash requires advanced analysis (Entropy, Math, YARA-python), use Standard Input (stdin) handoff:

No Disk I/O: Pipe Base64 or Binary strings directly into Python.

Data Handoff: echo "$BASE64_DATA" | base64 -d | python3 entropy_check.py

Return Values: Capture Python's stdout into a Bash variable: RESULT=$(... | python3 helper.py).

Exit Codes: Python must return sys.exit(0) for success and sys.exit(1) for threat detection.

## Sanitization Logic (In-Memory / Pipe-First)
To maintain security and speed, avoid writing sensitive data to the physical disk:

RAM Disk: If a tool strictly requires a file path (e.g., exiftool), use /dev/shm/ as a temporary buffer.

Process Substitution: Use <() to treat command output as a file: yara rules.yar <(echo "$PAYLOAD" | base64 -d).

Entropy Check: Use the Python helper to calculate Shannon Entropy. If > $MAX_ENTROPY, flag as suspicious.

Metadata Scrubbing: Use exiftool to strip all tags and output binary to stdout: exiftool -all= -o - <(echo "$BINARY").

Validation: Always verify the MIME type via file -b --mime-type before choosing the sanitization path.

## Data Pipeline Flow (Job Request)
Poll: Query job_request for records where status = 'PENDING'.

Fetch: Extract the file_blob and store as Base64 in a Bash variable.

Analyze: - Pipe to Python for Entropy calculation.

Pipe to YARA for malware signature scanning.

Clean: Pipe binary to exiftool to strip metadata.

Finalize: Re-encode clean binary to Base64 and wrap in a JSON object.

Publish: Send JSON to the TOPIC_CLEAN Kafka topic.

Update: Set job_request.status to the success or failure constant in MySQL.

## Coding Standards
Error Propagation: Use set -o pipefail to ensure piped errors are caught.

Atomicity: A file must pass all checks to be published.

Cleanup: Always use a trap to clear /dev/shm/ on script exit: trap 'rm -f /dev/shm/tmp_*' EXIT.