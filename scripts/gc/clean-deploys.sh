#!/usr/bin/env bash
set -euo pipefail

# Clean preview deploys for PRs that are no longer open.

DRY_RUN="${DRY_RUN:-true}"

echo "Garbage collecting orphaned deploys..."

if ! command -v gh &>/dev/null; then
  echo "  gh CLI not available. Skipping deploy cleanup."
  exit 0
fi

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "  GITHUB_TOKEN not set. Skipping deploy cleanup."
  exit 0
fi

# ── Find closed PRs that might have orphaned deploys ─
echo "  Checking for orphaned preview deploys..."
CLOSED_PRS=$(gh pr list --state closed --limit 50 --json number --jq '.[].number' 2>/dev/null || true)

for pr_number in $CLOSED_PRS; do
  [ -z "$pr_number" ] && continue
  # Check if this PR has a deploy that needs cleanup
  # This is provider-specific — implement based on your deploy platform
  #
  # Vercel:   vercel remove project-pr-${pr_number} --yes
  # Netlify:  netlify deploy --delete --alias pr-${pr_number}
  # Fly.io:   fly apps destroy pr-${pr_number} --yes
  #
  if [ "$DRY_RUN" = "true" ]; then
    echo "    [dry-run] Would clean deploy for closed PR #${pr_number}"
  else
    echo "    Checking PR #${pr_number} for orphaned deploy..."
    # TODO: Add your provider-specific cleanup here
  fi
done

echo "Deploy cleanup complete."
