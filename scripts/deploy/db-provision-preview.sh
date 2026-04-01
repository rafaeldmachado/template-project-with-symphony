#!/usr/bin/env bash
set -euo pipefail

# Provision a PR-specific database namespace for preview isolation.
# Usage: ./scripts/deploy/db-provision-preview.sh <pr-number>
#
# For SQL databases: creates a schema (PostgreSQL) or database (MySQL)
# named "pr_<number>". Outputs the PR-specific DATABASE_URL to
# .deploy-artifacts/preview-db-url.txt
#
# Requires DATABASE_URL pointing to the shared preview DB server.
# Idempotent — safe to run multiple times.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ -z "${1:-}" ]; then
  echo "ERROR: [db-provision] Usage: db-provision-preview.sh <pr-number>"
  exit 1
fi

PR_NUMBER="$1"
DB_ENGINE="${DB_ENGINE:-}"
DB_ORM="${DB_ORM:-none}"
DATABASE_URL="${DATABASE_URL:-}"
ARTIFACT_DIR="$ROOT_DIR/.deploy-artifacts"

mkdir -p "$ARTIFACT_DIR"

if [ -z "$DB_ENGINE" ] || [ "$DB_ORM" = "none" ] || [ -z "$DB_ORM" ]; then
  echo "No database configured. Skipping preview DB provisioning."
  exit 0
fi

if [ -z "$DATABASE_URL" ]; then
  echo "ERROR: [db-provision] DATABASE_URL is required for preview DB provisioning."
  exit 1
fi

PR_NAMESPACE="pr_${PR_NUMBER}"
PR_DATABASE_URL="$DATABASE_URL"

echo "Provisioning preview database namespace: ${PR_NAMESPACE}..."

case "$DB_ENGINE" in
  postgres)
    # Create a PostgreSQL schema for this PR
    psql "$DATABASE_URL" -c "CREATE SCHEMA IF NOT EXISTS \"${PR_NAMESPACE}\";" 2>&1 || {
      echo "ERROR: [db-provision] Failed to create PostgreSQL schema ${PR_NAMESPACE}"
      exit 1
    }
    # Append search_path to the DATABASE_URL
    if [[ "$DATABASE_URL" == *"?"* ]]; then
      PR_DATABASE_URL="${DATABASE_URL}&options=-csearch_path%3D${PR_NAMESPACE}"
    else
      PR_DATABASE_URL="${DATABASE_URL}?options=-csearch_path%3D${PR_NAMESPACE}"
    fi
    echo "  Created PostgreSQL schema: ${PR_NAMESPACE}"
    ;;

  mysql)
    # Create a separate MySQL database for this PR
    DB_HOST=$(echo "$DATABASE_URL" | sed -n 's|.*@\([^:/]*\).*|\1|p')
    DB_PORT=$(echo "$DATABASE_URL" | sed -n 's|.*:\([0-9]*\)/.*|\1|p')
    DB_USER=$(echo "$DATABASE_URL" | sed -n 's|.*://\([^:]*\):.*|\1|p')
    DB_PASS=$(echo "$DATABASE_URL" | sed -n 's|.*://[^:]*:\([^@]*\)@.*|\1|p')
    mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u "$DB_USER" -p"$DB_PASS" \
      -e "CREATE DATABASE IF NOT EXISTS \`${PR_NAMESPACE}\`;" 2>&1 || {
      echo "ERROR: [db-provision] Failed to create MySQL database ${PR_NAMESPACE}"
      exit 1
    }
    # Rewrite DATABASE_URL to point to the PR-specific database
    PR_DATABASE_URL=$(echo "$DATABASE_URL" | sed "s|/[^/?]*\(\?.*\)\{0,1\}$|/${PR_NAMESPACE}\1|")
    echo "  Created MySQL database: ${PR_NAMESPACE}"
    ;;

  sqlite)
    # Each preview gets its own SQLite file
    PR_DATABASE_URL="file:./data/pr-${PR_NUMBER}.db"
    mkdir -p "$ROOT_DIR/data"
    echo "  SQLite file: data/pr-${PR_NUMBER}.db"
    ;;

  mongodb)
    # MongoDB: use a separate database per PR (change DB name in URL)
    PR_DATABASE_URL=$(echo "$DATABASE_URL" | sed "s|/[^/?]*\(\?.*\)\{0,1\}$|/${PR_NAMESPACE}\1|")
    echo "  MongoDB database: ${PR_NAMESPACE}"
    ;;

  redis)
    # Redis: use key prefix convention — the app must respect the prefix env var
    echo "  Redis: using shared instance. Set REDIS_KEY_PREFIX=pr:${PR_NUMBER}: in your app."
    export REDIS_KEY_PREFIX="pr:${PR_NUMBER}:"
    PR_DATABASE_URL="$DATABASE_URL"
    ;;

  *)
    echo "WARNING: [db-provision] Unknown DB_ENGINE '${DB_ENGINE}'. Using base DATABASE_URL."
    PR_DATABASE_URL="$DATABASE_URL"
    ;;
esac

echo "$PR_DATABASE_URL" > "$ARTIFACT_DIR/preview-db-url.txt"
echo "Preview DATABASE_URL written to .deploy-artifacts/preview-db-url.txt"
