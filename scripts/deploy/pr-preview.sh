#!/usr/bin/env bash
set -euo pipefail

# Deploy a preview environment for a PR.
# Usage: ./scripts/deploy/pr-preview.sh <pr-number>
#
# Supports multiple providers via DEPLOY_PROVIDER env var.
# The preview URL is written to .deploy-artifacts/preview-url.txt
#
# To configure: uncomment the deploy command for your provider below
# and set the required env vars in .env / GitHub secrets.
# See docs/DEPLOY.md for details.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ -z "${1:-}" ]; then
  echo "ERROR: [deploy] Usage: make deploy-preview PR=<pr-number>"
  exit 1
fi

PR_NUMBER="$1"
PROVIDER="${DEPLOY_PROVIDER:-}"
ARTIFACT_DIR="$ROOT_DIR/.deploy-artifacts"
URL_FILE="$ARTIFACT_DIR/preview-url.txt"

mkdir -p "$ARTIFACT_DIR"

if [ -z "$PROVIDER" ]; then
  echo "No DEPLOY_PROVIDER configured. Skipping preview deploy."
  echo "See docs/DEPLOY.md for setup instructions."
  exit 0
fi

echo "Deploying PR #${PR_NUMBER} preview via ${PROVIDER}..."

case "$PROVIDER" in
  vercel)
    # Requires: DEPLOY_TOKEN (Vercel token)
    # Uncomment and adjust:
    # PREVIEW_URL=$(npx vercel --token "$DEPLOY_TOKEN" --yes 2>&1 | tail -1)
    # echo "$PREVIEW_URL" > "$URL_FILE"
    echo "ERROR: [deploy] Vercel provider selected but deploy command not configured."
    echo "  Edit scripts/deploy/pr-preview.sh and uncomment the vercel block."
    exit 1
    ;;
  netlify)
    # Requires: DEPLOY_TOKEN (Netlify token), DEPLOY_PROJECT_ID (site ID)
    # Uncomment and adjust:
    # PREVIEW_URL=$(npx netlify deploy --alias "pr-${PR_NUMBER}" --auth "$DEPLOY_TOKEN" --site "$DEPLOY_PROJECT_ID" --json | jq -r '.deploy_url')
    # echo "$PREVIEW_URL" > "$URL_FILE"
    echo "ERROR: [deploy] Netlify provider selected but deploy command not configured."
    echo "  Edit scripts/deploy/pr-preview.sh and uncomment the netlify block."
    exit 1
    ;;
  cloudflare)
    # Requires: DEPLOY_TOKEN (CF API token), DEPLOY_PROJECT_ID (project name)
    # Uncomment and adjust:
    # npx wrangler pages deploy dist --project-name "$DEPLOY_PROJECT_ID" --branch "pr-${PR_NUMBER}"
    # echo "https://pr-${PR_NUMBER}.$DEPLOY_PROJECT_ID.pages.dev" > "$URL_FILE"
    echo "ERROR: [deploy] Cloudflare provider selected but deploy command not configured."
    echo "  Edit scripts/deploy/pr-preview.sh and uncomment the cloudflare block."
    exit 1
    ;;
  fly)
    # Requires: DEPLOY_TOKEN (Fly auth token)
    # Uncomment and adjust:
    # fly deploy --app "your-project-pr-${PR_NUMBER}" --remote-only
    # echo "https://your-project-pr-${PR_NUMBER}.fly.dev" > "$URL_FILE"
    echo "ERROR: [deploy] Fly provider selected but deploy command not configured."
    echo "  Edit scripts/deploy/pr-preview.sh and uncomment the fly block."
    exit 1
    ;;
  custom)
    # Implement your custom deploy logic here.
    # Write the preview URL to: echo "$URL" > "$URL_FILE"
    echo "ERROR: [deploy] Custom provider selected but not implemented."
    echo "  Edit scripts/deploy/pr-preview.sh and add your deploy logic."
    exit 1
    ;;
  *)
    echo "ERROR: [deploy] Unknown DEPLOY_PROVIDER: $PROVIDER"
    echo "  Supported: vercel, netlify, cloudflare, fly, custom"
    exit 1
    ;;
esac

echo "Preview URL: $(cat "$URL_FILE")"
