#!/usr/bin/env bash
set -euo pipefail

# Clean up a worktree for a specific issue.
# Usage: ./scripts/worktree/cleanup.sh <issue-number>

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKTREE_DIR="$ROOT_DIR/.worktrees"

if [ -z "${1:-}" ]; then
  echo "ERROR: [worktree] Usage: make worktree-cleanup ISSUE=<issue-number>"
  exit 1
fi

ISSUE="$1"
BRANCH="issue/${ISSUE}"
WORKTREE_PATH="${WORKTREE_DIR}/${ISSUE}"

if [ ! -d "$WORKTREE_PATH" ]; then
  echo "No worktree found for issue $ISSUE at $WORKTREE_PATH"
  exit 0
fi

# ── Check for uncommitted changes ────────────────────
if (cd "$WORKTREE_PATH" && git status --porcelain | grep -q .); then
  echo "WARNING: Worktree has uncommitted changes:"
  (cd "$WORKTREE_PATH" && git status --short)
  echo ""
  read -rp "Remove anyway? (y/N) " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Aborted."
    exit 1
  fi
fi

# ── Remove worktree ──────────────────────────────────
echo "Removing worktree for issue $ISSUE..."
git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || rm -rf "$WORKTREE_PATH"

# ── Optionally delete branch if merged ───────────────
if git branch --merged main 2>/dev/null | grep -q "$BRANCH"; then
  echo "Branch $BRANCH is merged. Deleting..."
  git branch -d "$BRANCH" 2>/dev/null || true
else
  echo "Branch $BRANCH is NOT merged into main. Keeping it."
fi

echo "Worktree cleanup complete."
