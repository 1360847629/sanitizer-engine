#!/bin/bash


# If true, run mysql inside docker compose service "db"
: "${DB_USE_DOCKER_COMPOSE:=false}"
: "${DB_SERVICE_NAME:=db}"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-user}"
DB_PASSWORD="${DB_PASSWORD:-password}"

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
