#!/usr/bin/env bash
set -euo pipefail

# Tear down a preview environment for a closed PR.
# Usage: ./scripts/deploy/pr-cleanup.sh <pr-number>

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

case "$PROVIDER" in
  vercel)
    # vercel remove "your-project-pr-${PR_NUMBER}" --token "$DEPLOY_TOKEN" --yes
    echo "TODO: Implement Vercel cleanup"
    ;;
  netlify)
    # No built-in alias deletion in Netlify; deploys expire or can be manually removed
    echo "TODO: Implement Netlify cleanup"
    ;;
  cloudflare)
    # Cloudflare Pages branch deploys are cleaned automatically
    echo "Cloudflare Pages auto-cleans branch deploys."
    ;;
  fly)
    # fly apps destroy "your-project-pr-${PR_NUMBER}" --yes
    echo "TODO: Implement Fly.io cleanup"
    ;;
  custom)
    echo "TODO: Implement custom cleanup"
    ;;
  *)
    echo "ERROR: [deploy] Unknown DEPLOY_PROVIDER: $PROVIDER"
    exit 1
    ;;
esac

echo "Preview cleanup complete for PR #${PR_NUMBER}."
