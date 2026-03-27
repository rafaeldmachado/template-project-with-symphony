#!/usr/bin/env bash
set -euo pipefail

# Clean branches that have been merged or are stale.
# Uses STALE_DAYS (default: 14) to determine staleness.

STALE_DAYS="${STALE_DAYS:-14}"
DRY_RUN="${DRY_RUN:-true}"

echo "Garbage collecting branches (stale > ${STALE_DAYS} days)..."

# ── Clean local branches merged into main ────────────
echo "  Cleaning merged local branches..."
MERGED=$(git branch --merged main 2>/dev/null | grep -v '^\*' | grep -v 'main' | grep -v 'master' || true)
for branch in $MERGED; do
  branch=$(echo "$branch" | xargs)
  [ -z "$branch" ] && continue
  if [ "$DRY_RUN" = "true" ]; then
    echo "    [dry-run] Would delete local branch: $branch"
  else
    echo "    Deleting local branch: $branch"
    git branch -d "$branch" 2>/dev/null || true
  fi
done

# ── Clean remote branches merged into main ───────────
echo "  Cleaning merged remote branches..."
if command -v gh &>/dev/null && [ -n "${GITHUB_TOKEN:-}" ]; then
  REMOTE_MERGED=$(git branch -r --merged main 2>/dev/null | grep 'origin/' | grep -v 'origin/main' | grep -v 'origin/master' | grep -v 'HEAD' || true)
  for branch in $REMOTE_MERGED; do
    branch=$(echo "$branch" | xargs)
    remote_branch="${branch#origin/}"
    [ -z "$remote_branch" ] && continue
    if [ "$DRY_RUN" = "true" ]; then
      echo "    [dry-run] Would delete remote branch: $remote_branch"
    else
      echo "    Deleting remote branch: $remote_branch"
      git push origin --delete "$remote_branch" 2>/dev/null || true
    fi
  done
fi

# ── Report stale unmerged branches ───────────────────
echo "  Checking for stale unmerged branches..."
STALE_DATE=$(date -v-"${STALE_DAYS}"d +%Y-%m-%d 2>/dev/null || date -d "${STALE_DAYS} days ago" +%Y-%m-%d 2>/dev/null || echo "")
if [ -n "$STALE_DATE" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "    WARN: Stale unmerged branch: $line"
  done < <(git for-each-ref --sort=committerdate --format='%(refname:short) (%(committerdate:short))' refs/heads/ | \
    grep -v 'main' | grep -v 'master' || true)
fi

echo "Branch cleanup complete."
