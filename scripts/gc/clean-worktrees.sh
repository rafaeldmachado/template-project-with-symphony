#!/usr/bin/env bash
set -euo pipefail

# Clean git worktrees whose branches have been merged or deleted.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKTREE_DIR="$ROOT_DIR/.worktrees"
DRY_RUN="${DRY_RUN:-true}"

echo "Garbage collecting worktrees..."

if [ ! -d "$WORKTREE_DIR" ]; then
  echo "  No worktree directory found. Nothing to clean."
  exit 0
fi

# ── Prune worktrees with missing directories ─────────
echo "  Pruning stale worktree references..."
git worktree prune 2>/dev/null || true

# ── Check each worktree directory ────────────────────
for dir in "$WORKTREE_DIR"/*/; do
  [ -d "$dir" ] || continue
  issue_dir=$(basename "$dir")
  branch="issue/${issue_dir}"

  # Check if the branch still exists
  if ! git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    if [ "$DRY_RUN" = "true" ]; then
      echo "    [dry-run] Would remove worktree: $issue_dir (branch gone)"
    else
      echo "    Removing worktree: $issue_dir (branch gone)"
      git worktree remove "$dir" --force 2>/dev/null || rm -rf "$dir"
    fi
    continue
  fi

  # Check if the branch has been merged into main
  if git branch --merged main 2>/dev/null | grep -q "$branch"; then
    if [ "$DRY_RUN" = "true" ]; then
      echo "    [dry-run] Would remove worktree: $issue_dir (branch merged)"
    else
      echo "    Removing worktree: $issue_dir (branch merged)"
      git worktree remove "$dir" --force 2>/dev/null || rm -rf "$dir"
      git branch -d "$branch" 2>/dev/null || true
    fi
  fi
done

echo "Worktree cleanup complete."
