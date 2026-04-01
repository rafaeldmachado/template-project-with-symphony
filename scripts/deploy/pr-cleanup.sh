#!/usr/bin/env bash
set -euo pipefail

# Tear down a preview environment for a closed PR.
# Usage: ./scripts/deploy/pr-cleanup.sh <pr-number>
#
# Idempotent: exits 0 even if the preview no longer exists.

if [ -z "${1:-}" ]; then
  echo "ERROR: [deploy] Usage: make deploy-cleanup PR=<pr-number>"
  exit 1
fi

PR_NUMBER="$1"
PROVIDER="${DEPLOY_PROVIDER:-}"

if [ -z "$PROVIDER" ]; then
  echo "No DEPLOY_PROVIDER configured. Nothing to clean up."
  exit 0
fi

echo "Tearing down PR #${PR_NUMBER} preview (${PROVIDER})..."

# ── Mark GitHub Deployment as inactive ─────────────────

deactivate_deployment() {
  if ! command -v gh &>/dev/null; then
    return 0
  fi
  local env_name="pr-${PR_NUMBER}"
  # Find deployments for this environment
  DEPLOYMENT_IDS=$(gh api "repos/{owner}/{repo}/deployments?environment=${env_name}" \
    --jq '.[].id' 2>/dev/null || true)
  for dep_id in $DEPLOYMENT_IDS; do
    gh api "repos/{owner}/{repo}/deployments/${dep_id}/statuses" \
      -f state="inactive" \
      -f description="Preview torn down for PR #${PR_NUMBER}" 2>/dev/null || true
  done
}

# ── Clean up preview database ─────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/db-cleanup-preview.sh" "$PR_NUMBER" || true

# ── Provider-specific cleanup ──────────────────────────
# Most providers (Vercel, Netlify, Cloudflare) manage preview lifecycle
# automatically — previews are immutable and auto-expire. Only Fly.io
# creates a real ephemeral app that needs explicit destruction.
# In all cases the GitHub Deployment is deactivated below.

case "$PROVIDER" in
  vercel|netlify|cloudflare)
    echo "  ${PROVIDER} preview deploys auto-expire. No active teardown needed."
    ;;

  fly)
    APP_NAME="${DEPLOY_PROJECT_ID:?ERROR: [deploy] DEPLOY_PROJECT_ID required for Fly cleanup}-pr-${PR_NUMBER}"
    if [ -n "${DEPLOY_TOKEN:-}" ]; then
      export FLY_API_TOKEN="$DEPLOY_TOKEN"
      echo "  Destroying Fly app: ${APP_NAME}..."
      fly apps destroy "$APP_NAME" --yes 2>/dev/null || true
      echo "  Fly app ${APP_NAME} destroyed (or did not exist)."
    else
      echo "  DEPLOY_TOKEN not set. Skipping Fly cleanup."
    fi
    ;;

  custom)
    # Extension point: implement your custom cleanup logic here.
    # Must be idempotent — exit 0 even if already cleaned up.
    echo "  Custom cleanup not implemented. Edit scripts/deploy/pr-cleanup.sh."
    ;;

  *)
    echo "ERROR: [deploy] Unknown DEPLOY_PROVIDER: $PROVIDER"
    exit 1
    ;;
esac

# ── Deactivate GitHub Deployments ──────────────────────

deactivate_deployment

echo "Preview cleanup complete for PR #${PR_NUMBER}."
