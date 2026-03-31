#!/usr/bin/env bash
set -euo pipefail

# Deploy to production.
# Usage: ./scripts/deploy/production.sh
#
# Reads DEPLOY_PROVIDER to pick the right CLI command.
# Creates/updates GitHub Deployment status for 'production' environment.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PROVIDER="${DEPLOY_PROVIDER:-}"
BUILD_DIR="${DEPLOY_BUILD_DIR:-dist}"

if [ -z "$PROVIDER" ]; then
  echo "No DEPLOY_PROVIDER configured. Skipping production deploy."
  echo "See docs/DEPLOY.md for setup instructions."
  exit 0
fi

echo "Deploying to production via ${PROVIDER}..."

# ── GitHub Deployment helpers ──────────────────────────

DEPLOYMENT_ID=""

create_deployment() {
  if ! command -v gh &>/dev/null; then
    echo "  gh CLI not available. Skipping GitHub Deployment status."
    return 0
  fi
  DEPLOYMENT_ID=$(gh api "repos/{owner}/{repo}/deployments" \
    -f ref="$(git rev-parse HEAD)" \
    -f environment="production" \
    -f auto_merge=false \
    -f required_contexts="[]" \
    --jq '.id' 2>/dev/null || true)
  if [ -n "$DEPLOYMENT_ID" ]; then
    gh api "repos/{owner}/{repo}/deployments/${DEPLOYMENT_ID}/statuses" \
      -f state="in_progress" \
      -f description="Deploying to production..." 2>/dev/null || true
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
    -f description="Production deploy complete" 2>/dev/null || true
}

update_deployment_failure() {
  if [ -z "${DEPLOYMENT_ID:-}" ] || ! command -v gh &>/dev/null; then
    return 0
  fi
  gh api "repos/{owner}/{repo}/deployments/${DEPLOYMENT_ID}/statuses" \
    -f state="failure" \
    -f description="Production deploy failed" 2>/dev/null || true
}

# ── Validation helpers ─────────────────────────────────

require_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "ERROR: [deploy] ${name} is required for ${PROVIDER} production deploys."
    exit 1
  fi
}

# ── Create GitHub Deployment (in_progress) ─────────────

create_deployment

# ── Provider-specific deploy ───────────────────────────

PROD_URL=""
deploy_failed=false

case "$PROVIDER" in
  vercel)
    require_var DEPLOY_TOKEN

    VERCEL_ARGS="--token $DEPLOY_TOKEN --prod --yes"
    if [ "${DEPLOY_PREBUILT:-}" = "true" ]; then
      VERCEL_ARGS="$VERCEL_ARGS --prebuilt"
    fi

    if ! PROD_URL=$(vercel deploy $VERCEL_ARGS 2>&1 | tail -1); then
      echo "ERROR: [deploy] Vercel production deploy failed."
      deploy_failed=true
    fi
    ;;

  netlify)
    require_var DEPLOY_TOKEN
    require_var DEPLOY_PROJECT_ID

    if ! DEPLOY_OUTPUT=$(netlify deploy \
        --dir="$BUILD_DIR" \
        --auth "$DEPLOY_TOKEN" \
        --site "$DEPLOY_PROJECT_ID" \
        --prod \
        --json 2>&1); then
      echo "ERROR: [deploy] Netlify production deploy failed."
      echo "$DEPLOY_OUTPUT"
      deploy_failed=true
    else
      PROD_URL=$(echo "$DEPLOY_OUTPUT" | jq -r '.deploy_url // .url')
      if [ -z "$PROD_URL" ] || [ "$PROD_URL" = "null" ]; then
        echo "ERROR: [deploy] Failed to parse Netlify production URL from output."
        deploy_failed=true
      fi
    fi
    ;;

  cloudflare)
    require_var DEPLOY_TOKEN
    require_var DEPLOY_PROJECT_ID

    if ! DEPLOY_OUTPUT=$(CLOUDFLARE_API_TOKEN="$DEPLOY_TOKEN" \
        wrangler pages deploy "$BUILD_DIR" \
        --project-name "$DEPLOY_PROJECT_ID" \
        --branch main 2>&1); then
      echo "ERROR: [deploy] Cloudflare Pages production deploy failed."
      echo "$DEPLOY_OUTPUT"
      deploy_failed=true
    else
      PROD_URL=$(echo "$DEPLOY_OUTPUT" | grep -oE 'https://[^ ]+' | tail -1 || true)
      if [ -z "$PROD_URL" ]; then
        PROD_URL="https://${DEPLOY_PROJECT_ID}.pages.dev"
      fi
    fi
    ;;

  fly)
    require_var DEPLOY_TOKEN
    require_var DEPLOY_PROJECT_ID

    export FLY_API_TOKEN="$DEPLOY_TOKEN"

    if ! fly deploy --app "$DEPLOY_PROJECT_ID" --remote-only 2>&1; then
      echo "ERROR: [deploy] Fly production deploy failed."
      deploy_failed=true
    else
      PROD_URL="https://${DEPLOY_PROJECT_ID}.fly.dev"
    fi
    ;;

  custom)
    # Extension point: implement your custom production deploy here.
    # Set PROD_URL to the production URL after deploying.
    echo "ERROR: [deploy] Custom provider selected but not implemented."
    echo "  Edit scripts/deploy/production.sh and add your deploy logic in the 'custom' block."
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

update_deployment_success "$PROD_URL"
echo "Production deploy complete: $PROD_URL"
