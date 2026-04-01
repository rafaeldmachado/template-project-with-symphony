#!/usr/bin/env bash
set -euo pipefail

# Clean up a PR-specific database namespace.
# Usage: ./scripts/deploy/db-cleanup-preview.sh <pr-number>
#
# Idempotent: exits 0 even if the namespace doesn't exist.

if [ -z "${1:-}" ]; then
  echo "ERROR: [db-cleanup] Usage: db-cleanup-preview.sh <pr-number>"
  exit 1
fi

PR_NUMBER="$1"
DB_ENGINE="${DB_ENGINE:-}"
DB_ORM="${DB_ORM:-none}"
DATABASE_URL="${DATABASE_URL:-}"

if [ -z "$DB_ENGINE" ] || [ "$DB_ORM" = "none" ] || [ -z "$DB_ORM" ]; then
  echo "No database configured. Skipping preview DB cleanup."
  exit 0
fi

if [ -z "$DATABASE_URL" ]; then
  echo "WARNING: [db-cleanup] DATABASE_URL not set. Skipping preview DB cleanup."
  exit 0
fi

PR_NAMESPACE="pr_${PR_NUMBER}"

echo "Cleaning up preview database namespace: ${PR_NAMESPACE}..."

case "$DB_ENGINE" in
  postgres)
    psql "$DATABASE_URL" -c "DROP SCHEMA IF EXISTS \"${PR_NAMESPACE}\" CASCADE;" 2>/dev/null || true
    echo "  Dropped PostgreSQL schema: ${PR_NAMESPACE} (or did not exist)"
    ;;

  mysql)
    DB_HOST=$(echo "$DATABASE_URL" | sed -n 's|.*@\([^:/]*\).*|\1|p')
    DB_PORT=$(echo "$DATABASE_URL" | sed -n 's|.*:\([0-9]*\)/.*|\1|p')
    DB_USER=$(echo "$DATABASE_URL" | sed -n 's|.*://\([^:]*\):.*|\1|p')
    DB_PASS=$(echo "$DATABASE_URL" | sed -n 's|.*://[^:]*:\([^@]*\)@.*|\1|p')
    mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASS" \
      -e "DROP DATABASE IF EXISTS \`${PR_NAMESPACE}\`;" 2>/dev/null || true
    echo "  Dropped MySQL database: ${PR_NAMESPACE} (or did not exist)"
    ;;

  mongodb)
    mongosh "$DATABASE_URL" --eval "db.getSiblingDB('${PR_NAMESPACE}').dropDatabase()" 2>/dev/null || true
    echo "  Dropped MongoDB database: ${PR_NAMESPACE} (or did not exist)"
    ;;

  sqlite)
    ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    rm -f "$ROOT_DIR/data/pr-${PR_NUMBER}.db" 2>/dev/null || true
    echo "  Removed SQLite file: data/pr-${PR_NUMBER}.db (or did not exist)"
    ;;

  redis)
    echo "  Redis: no per-PR cleanup needed (app should use key prefix convention)."
    ;;

  *)
    echo "  Unknown DB_ENGINE '${DB_ENGINE}'. No cleanup performed."
    ;;
esac

echo "Preview DB cleanup complete for PR #${PR_NUMBER}."
