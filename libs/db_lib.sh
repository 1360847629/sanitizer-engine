#!/bin/bash

# If true, run mysql inside docker compose service "db"
: "${DB_USE_DOCKER_COMPOSE:=false}"
: "${DB_SERVICE_NAME:=db}"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-user}"
DB_PASSWORD="${DB_PASSWORD:-password}"
DB_NAME="${DB_NAME:-CyberClinic}"

# Initial States
declare -r STATUS_PENDING="PENDING"
declare -r STATUS_QUEUED="QUEUED"

# Security & Preparation
declare -r STATUS_SANITIZING="SANITIZING"
declare -r STATUS_SANITIZED="SANITIZED"
declare -r STATUS_FAILED_SANITIZATION="FAILED_SANITIZATION"

# Execution
declare -r STATUS_IN_PROGRESS="IN_PROGRESS"
declare -r STATUS_RETRYING="RETRYING"

# Final States
declare -r STATUS_COMPLETED="COMPLETED"
declare -r STATUS_COMPLETED_WITH_WARNINGS="COMPLETED_WITH_WARNINGS"
declare -r STATUS_ERROR="ERROR"
declare -r STATUS_CANCELLED="CANCELLED"

# Usage Example:
current_status=$STATUS_PENDING

run_mysql() {
  local sql="$1"
  MYSQL_PWD="$DB_PASSWORD" mysql --protocol=TCP \
    -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -D "$DB_NAME" \
    --batch --raw --skip-column-names \
    -e "$sql"
}

insert_job_request() {
  local b64_data="$1"
  run_mysql "
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
      FROM_BASE64('$b64_data'),
      'text/csv',
      'LOG',
      'PENDING',
      'SANITIZE',
      '$PRIORITY',
      '$USER_ID'
    );
  "
}

read_latest_job_request() {
  run_mysql  "
      SELECT
        id,
        COALESCE(file_name, ''),
        COALESCE(file_content_content_type, ''),
        REPLACE(TO_BASE64(file_content), '\n', '')
      FROM job_request
      WHERE status = '${STATUS_PENDING}'
      ORDER BY id DESC
      LIMIT 1;
    "
}

delete_job_request_by_id() {
  local job_id="$1"
  run_mysql "
    DELETE FROM job_request
    WHERE id = ${job_id}
    LIMIT 1;
  "
}

update_job_request_status() {
  local job_id="$1"
  local status="$2"
  run_mysql "
    UPDATE job_request
    SET status = '$status'
    WHERE id = ${job_id};
  "
}
insert_job_execution_log() {
  local status="$1"
  local execution_log="$2"
  local job_request_id="$3"

  # 1. Validation
  if [[ ! "$job_request_id" =~ ^[0-9]+$ ]]; then
    echo "insert_job_execution_log: job_request_id must be numeric" >&2
    return 1
  fi

  # 2. Manual Escaping (Basic protection for single quotes)
  local status_esc execution_log_esc
  status_esc="${status//\'/\'\'}"
  execution_log_esc="${execution_log//\'/\'\'}"

  # 3. Logic: Determine if we should set an end_time
  # You can expand this list based on your specific status names
  local end_time_val="NULL"
  if [[ "$status" =~ ^(COMPLETED|FAILED|CANCELLED)$ ]]; then
    end_time_val="NOW(6)"
  fi

  # 4. Pure Insert (New record every time)
  run_mysql "
    INSERT INTO job_execution_report (
      start_time,
      end_time,
      execution_log,
      status,
      job_request_id,
      user_id
    )
    SELECT
      NOW(6),
      ${end_time_val},
      '${execution_log_esc}',
      '${status_esc}',
      jr.id,
      jr.user_id
    FROM job_request jr
    WHERE jr.id = ${job_request_id};
  "
}