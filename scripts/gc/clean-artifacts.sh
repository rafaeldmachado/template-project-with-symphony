#!/usr/bin/env bash
set -euo pipefail

# Clean old CI artifacts beyond the retention period.

RETENTION_DAYS="${RETENTION_DAYS:-7}"
DRY_RUN="${DRY_RUN:-true}"

echo "Garbage collecting CI artifacts (retention: ${RETENTION_DAYS} days)..."

if ! command -v gh &>/dev/null; then
  echo "  gh CLI not available. Skipping artifact cleanup."
  exit 0
fi

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "  GITHUB_TOKEN not set. Skipping artifact cleanup."
  exit 0
fi

# ── Resolve repo from git remote or env ──────────────
REPO="${GITHUB_REPOSITORY:-}"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)
fi
if [ -z "$REPO" ]; then
  echo "  ERROR: [gc] Could not determine repository. Set GITHUB_REPOSITORY or run inside a git repo."
  exit 1
fi

# ── List and delete old artifacts ────────────────────
echo "  Fetching artifact list for $REPO..."
ARTIFACTS=$(gh api "repos/$REPO/actions/artifacts" \
  --jq ".artifacts[] | select(.expired == false) | select((.created_at | fromdateiso8601) < (now - ($RETENTION_DAYS * 86400))) | .id" \
  2>/dev/null || true)

COUNT=0
for artifact_id in $ARTIFACTS; do
  [ -z "$artifact_id" ] && continue
  COUNT=$((COUNT + 1))
  if [ "$DRY_RUN" = "true" ]; then
    echo "    [dry-run] Would delete artifact: $artifact_id"
  else
    echo "    Deleting artifact: $artifact_id"
    gh api -X DELETE "repos/$REPO/actions/artifacts/$artifact_id" 2>/dev/null || true
  fi
done

echo "Artifact cleanup complete. Processed: $COUNT"
