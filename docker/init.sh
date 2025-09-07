#!/bin/bash
set -e

SITE_NAME="${SITE_NAME:-lms.localhost}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
DEVELOPER_MODE="${DEVELOPER_MODE:-0}"
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD env not set}"

# Guard NVM path
if [ -n "${NVM_DIR:-}" ] && [ -d "$NVM_DIR" ]; then
  export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP:-}/bin/:${PATH}"
fi

# Fast-fail if root auth mismatches existing DB volume
if ! mysqladmin ping -h mariadb -uroot -p"${MYSQL_ROOT_PASSWORD}" --silent; then
  echo "[init] ERROR: Cannot auth to MariaDB with MYSQL_ROOT_PASSWORD."
  echo "[init] Fix docker/.env to match the existing volume, or remove the DB volume to re-init."
  exit 1
fi

if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
  echo "[init] Bench already exists, starting..."
  cd frappe-bench
  exec bench start
fi

echo "[init] Creating new bench..."
bench init --skip-redis-config-generation frappe-bench
cd frappe-bench

# Use service hostnames with full Redis URLs
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

# Remove redis/watch from Procfile
sed -i '/redis/d' ./Procfile || true
sed -i '/watch/d' ./Procfile || true

bench get-app lms

bench new-site "${SITE_NAME}" \
  --force \
  --mariadb-root-password "${MYSQL_ROOT_PASSWORD}" \
  --admin-password "${ADMIN_PASSWORD}" \
  --no-mariadb-socket

bench --site "${SITE_NAME}" install-app lms
bench --site "${SITE_NAME}" set-config developer_mode "${DEVELOPER_MODE}"

# Optional: include https:// in host_name if you prefer absolute URLs
if [ -n "${SITE_HOST:-}" ]; then
  bench --site "${SITE_NAME}" set-config host_name "https://${SITE_HOST}"
fi

bench --site "${SITE_NAME}" clear-cache
bench use "${SITE_NAME}"

exec bench start