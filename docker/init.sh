#!/bin/bash
set -e

SITE_NAME="${SITE_NAME:-lms.localhost}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
DEVELOPER_MODE="${DEVELOPER_MODE:-0}"
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD env not set}"

if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "Bench already exists, skipping init"
    cd frappe-bench
    exec bench start
else
    echo "Creating new bench..."
fi

export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

bench init --skip-redis-config-generation frappe-bench
cd frappe-bench

# Use containers instead of localhost
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

# Remove redis, watch from Procfile
sed -i '/redis/d' ./Procfile
sed -i '/watch/d' ./Procfile

bench get-app lms

bench new-site "${SITE_NAME}" \
  --force \
  --mariadb-root-password "${MYSQL_ROOT_PASSWORD}" \
  --admin-password "${ADMIN_PASSWORD}" \
  --no-mariadb-socket

bench --site "${SITE_NAME}" install-app lms
bench --site "${SITE_NAME}" set-config developer_mode "${DEVELOPER_MODE}"

# Optional: bind a public host if provided
if [ -n "${SITE_HOST:-}" ]; then
  bench --site "${SITE_NAME}" set-config host_name "${SITE_HOST}"
fi

bench --site "${SITE_NAME}" clear-cache
bench use "${SITE_NAME}"

exec bench start