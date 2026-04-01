#!/usr/bin/env bash
set -euo pipefail

# Deploy a preview environment for a PR.
# Usage: ./scripts/deploy/pr-preview.sh <pr-number>
#
# Supports multiple providers via DEPLOY_PROVIDER env var.
# The preview URL is written to .deploy-artifacts/preview-url.txt
#
# Required env vars vary by provider — see docs/DEPLOY.md for details.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ -z "${1:-}" ]; then
  echo "ERROR: [deploy] Usage: make deploy-preview PR=<pr-number>"
  exit 1
fi

PR_NUMBER="$1"
PROVIDER="${DEPLOY_PROVIDER:-}"
ARTIFACT_DIR="$ROOT_DIR/.deploy-artifacts"
URL_FILE="$ARTIFACT_DIR/preview-url.txt"
BUILD_DIR="${DEPLOY_BUILD_DIR:-dist}"

mkdir -p "$ARTIFACT_DIR"

if [ -z "$PROVIDER" ]; then
  echo "No DEPLOY_PROVIDER configured. Skipping preview deploy."
  echo "See docs/DEPLOY.md for setup instructions."
  exit 0
fi

echo "Deploying PR #${PR_NUMBER} preview via ${PROVIDER}..."

# ── GitHub Deployment helpers ──────────────────────────

create_deployment() {
  local env_name="pr-${PR_NUMBER}"
  if ! command -v gh &>/dev/null; then
    echo "  gh CLI not available. Skipping GitHub Deployment status."
    return 0
  fi
  DEPLOYMENT_ID=$(gh api "repos/{owner}/{repo}/deployments" \
    -f ref="$(git rev-parse HEAD)" \
    -f environment="$env_name" \
    -f auto_merge=false \
    -f required_contexts="[]" \
    --jq '.id' 2>/dev/null || true)
  if [ -n "$DEPLOYMENT_ID" ]; then
    gh api "repos/{owner}/{repo}/deployments/${DEPLOYMENT_ID}/statuses" \
      -f state="in_progress" \
      -f description="Deploying PR #${PR_NUMBER} preview..." 2>/dev/null || true
  fi
}

update_deployment_success() {
  local url="$1"
  if [ -z "${DEPLOYMENT_ID:-}" ] || ! command -v gh &>/dev/null; then
    return 0
  fi
  gh api "repos/{owner}/{repo}/deployments/${DEPLOYMENT_ID}/statuses" \
    -f state="success" \
    -f environment_url="$url" \
    -f description="Preview deployed for PR #${PR_NUMBER}" 2>/dev/null || true
}

update_deployment_failure() {
  if [ -z "${DEPLOYMENT_ID:-}" ] || ! command -v gh &>/dev/null; then
    return 0
  fi
  gh api "repos/{owner}/{repo}/deployments/${DEPLOYMENT_ID}/statuses" \
    -f state="failure" \
    -f description="Deploy failed for PR #${PR_NUMBER}" 2>/dev/null || true
}

# ── Validation helpers ─────────────────────────────────

require_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "ERROR: [deploy] ${name} is required for ${PROVIDER} deploys."
    exit 1
  fi
}

# ── Create GitHub Deployment (in_progress) ─────────────

create_deployment

# ── Provision preview database ────────────────────────

if [ -n "${DB_ENGINE:-}" ] && [ "${DB_ORM:-none}" != "none" ]; then
  if ! "$ROOT_DIR/scripts/deploy/db-provision-preview.sh" "$PR_NUMBER"; then
    echo "ERROR: [deploy] Preview database provisioning failed."
    update_deployment_failure
    exit 1
  fi

  # Use the PR-specific DATABASE_URL for migrations and the app
  PR_DB_URL_FILE="$ARTIFACT_DIR/preview-db-url.txt"
  if [ -f "$PR_DB_URL_FILE" ]; then
    export DATABASE_URL
    DATABASE_URL=$(cat "$PR_DB_URL_FILE")
  fi

  if ! "$ROOT_DIR/scripts/deploy/db-migrate.sh"; then
    echo "ERROR: [deploy] Preview database migration failed."
    update_deployment_failure
    exit 1
  fi
fi

# ── Provider-specific deploy ───────────────────────────

deploy_failed=false

case "$PROVIDER" in
  vercel)
    require_var DEPLOY_TOKEN

    VERCEL_ARGS="--token $DEPLOY_TOKEN --yes"
    if [ "${DEPLOY_PREBUILT:-}" = "true" ]; then
      VERCEL_ARGS="$VERCEL_ARGS --prebuilt"
    fi

    if ! PREVIEW_URL=$(vercel deploy $VERCEL_ARGS 2>&1 | tail -1); then
      echo "ERROR: [deploy] Vercel deploy failed."
      deploy_failed=true
    else
      echo "$PREVIEW_URL" > "$URL_FILE"
    fi
    ;;

  netlify)
    require_var DEPLOY_TOKEN
    require_var DEPLOY_PROJECT_ID

    if ! DEPLOY_OUTPUT=$(netlify deploy \
        --dir="$BUILD_DIR" \
        --auth "$DEPLOY_TOKEN" \
        --site "$DEPLOY_PROJECT_ID" \
        --alias "pr-${PR_NUMBER}" \
        --json 2>&1); then
      echo "ERROR: [deploy] Netlify deploy failed."
      echo "$DEPLOY_OUTPUT"
      deploy_failed=true
    else
      PREVIEW_URL=$(echo "$DEPLOY_OUTPUT" | jq -r '.deploy_url')
      if [ -z "$PREVIEW_URL" ] || [ "$PREVIEW_URL" = "null" ]; then
        echo "ERROR: [deploy] Failed to parse Netlify deploy URL from output."
        deploy_failed=true
      else
        echo "$PREVIEW_URL" > "$URL_FILE"
      fi
    fi
    ;;

  cloudflare)
    require_var DEPLOY_TOKEN
    require_var DEPLOY_PROJECT_ID

    if ! DEPLOY_OUTPUT=$(CLOUDFLARE_API_TOKEN="$DEPLOY_TOKEN" \
        wrangler pages deploy "$BUILD_DIR" \
        --project-name "$DEPLOY_PROJECT_ID" \
        --branch "pr-${PR_NUMBER}" 2>&1); then
      echo "ERROR: [deploy] Cloudflare Pages deploy failed."
      echo "$DEPLOY_OUTPUT"
      deploy_failed=true
    else
      # Try to parse URL from wrangler output, fall back to convention
      PREVIEW_URL=$(echo "$DEPLOY_OUTPUT" | grep -oE 'https://[^ ]+' | tail -1 || true)
      if [ -z "$PREVIEW_URL" ]; then
        PREVIEW_URL="https://pr-${PR_NUMBER}.${DEPLOY_PROJECT_ID}.pages.dev"
      fi
      echo "$PREVIEW_URL" > "$URL_FILE"
    fi
    ;;

  fly)
    require_var DEPLOY_TOKEN
    require_var DEPLOY_PROJECT_ID

    APP_NAME="${DEPLOY_PROJECT_ID}-pr-${PR_NUMBER}"
    export FLY_API_TOKEN="$DEPLOY_TOKEN"

    # Create ephemeral app if it doesn't exist
    if ! fly apps list --json 2>/dev/null | jq -e ".[] | select(.Name == \"$APP_NAME\")" &>/dev/null; then
      echo "  Creating ephemeral Fly app: ${APP_NAME}..."
      if ! fly apps create "$APP_NAME" 2>&1; then
        echo "ERROR: [deploy] Failed to create Fly app: ${APP_NAME}"
        deploy_failed=true
      fi
    fi

    # Set DATABASE_URL secret on the ephemeral Fly app
    if [ "$deploy_failed" = "false" ] && [ -n "${DATABASE_URL:-}" ]; then
      echo "$DATABASE_URL" | fly secrets set DATABASE_URL=- --app "$APP_NAME" 2>/dev/null || true
    fi

    if [ "$deploy_failed" = "false" ]; then
      if ! fly deploy --app "$APP_NAME" --remote-only 2>&1; then
        echo "ERROR: [deploy] Fly deploy failed for app: ${APP_NAME}"
        deploy_failed=true
      else
        PREVIEW_URL="https://${APP_NAME}.fly.dev"
        echo "$PREVIEW_URL" > "$URL_FILE"
      fi
    fi
    ;;

  custom)
    # Extension point: implement your custom deploy logic here.
    # Write the preview URL to: echo "$URL" > "$URL_FILE"
    echo "ERROR: [deploy] Custom provider selected but not implemented."
    echo "  Edit scripts/deploy/pr-preview.sh and add your deploy logic in the 'custom' block."
    exit 1
    ;;

  *)
    echo "ERROR: [deploy] Unknown DEPLOY_PROVIDER: $PROVIDER"
    echo "  Supported: vercel, netlify, cloudflare, fly, custom"
    exit 1
    ;;
esac

# ── Update GitHub Deployment status ────────────────────

if [ "$deploy_failed" = "true" ]; then
  update_deployment_failure
  exit 1
fi

PREVIEW_URL=$(cat "$URL_FILE")
update_deployment_success "$PREVIEW_URL"
echo "Preview URL: $PREVIEW_URL"
