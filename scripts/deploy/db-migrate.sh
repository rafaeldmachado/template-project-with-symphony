#!/usr/bin/env bash
set -euo pipefail

# Run database migrations for the configured ORM.
# Usage: ./scripts/deploy/db-migrate.sh
#
# Reads DB_ORM env var to determine which migration CLI to invoke.
# Requires DATABASE_URL to be set when a database is configured.
# Idempotent — safe to run multiple times.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

DB_ORM="${DB_ORM:-none}"

if [ "$DB_ORM" = "none" ] || [ -z "$DB_ORM" ]; then
  echo "No DB_ORM configured. Skipping migrations."
  exit 0
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "ERROR: [db-migrate] DATABASE_URL is required for migrations."
  exit 1
fi

echo "Running database migrations (ORM: ${DB_ORM})..."

cd "$ROOT_DIR"

case "$DB_ORM" in
  prisma)
    npx prisma migrate deploy
    ;;
  drizzle)
    npx drizzle-kit migrate
    ;;
  typeorm)
    npx typeorm migration:run -d ./dist/data-source.js
    ;;
  knex)
    npx knex migrate:latest
    ;;
  sqlalchemy)
    alembic upgrade head
    ;;
  django-orm)
    python manage.py migrate --noinput
    ;;
  tortoise)
    aerich upgrade
    ;;
  gorm)
    # GORM runs AutoMigrate in application code on startup — no CLI step needed.
    echo "  GORM: migrations run in application code at startup. Skipping."
    ;;
  sqlx)
    sqlx migrate run
    ;;
  ent)
    # Ent migrations are typically applied via a Go binary; adjust if using versioned migrations.
    echo "  Ent: migrations typically run in application code. Skipping."
    echo "  If using versioned migrations, add your command here."
    ;;
  activerecord)
    bundle exec rails db:migrate
    ;;
  diesel)
    diesel migration run
    ;;
  seaorm)
    sea-orm-cli migrate up
    ;;
  ecto)
    mix ecto.migrate
    ;;
  spring-data-jpa|jooq)
    # Flyway/Liquibase run on JVM startup — no separate CLI step needed.
    echo "  JVM: migrations run at application startup (Flyway/Liquibase). Skipping."
    ;;
  mongoose|motor|mongoengine|mongo-go-driver)
    # Document databases don't have schema migrations.
    echo "  Document database: no schema migrations to run."
    ;;
  *)
    echo "WARNING: [db-migrate] Unknown ORM '${DB_ORM}'. Skipping migrations."
    echo "  Edit scripts/deploy/db-migrate.sh to add your migration command."
    exit 0
    ;;
esac

echo "Migrations complete."
