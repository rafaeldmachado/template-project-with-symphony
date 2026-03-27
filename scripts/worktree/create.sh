#!/usr/bin/env bash
set -euo pipefail

# Create a git worktree for isolated work on an issue.
# Usage: ./scripts/worktree/create.sh <issue-number>

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKTREE_DIR="$ROOT_DIR/.worktrees"

if [ -z "${1:-}" ]; then
  echo "ERROR: [worktree] Usage: make worktree ISSUE=<issue-number>"
  exit 1
fi

ISSUE="$1"
BRANCH="issue/${ISSUE}"
WORKTREE_PATH="${WORKTREE_DIR}/${ISSUE}"

# ── Check if worktree already exists ─────────────────
if [ -d "$WORKTREE_PATH" ]; then
  echo "Worktree already exists at: $WORKTREE_PATH"
  echo "Branch: $BRANCH"
  echo ""
  echo "To work in it:  cd $WORKTREE_PATH"
  echo "To remove it:   make worktree-cleanup ISSUE=$ISSUE"
  exit 0
fi

# ── Ensure we're up to date ──────────────────────────
echo "Fetching latest from origin..."
git fetch origin main 2>/dev/null || true

# ── Create worktree ──────────────────────────────────
mkdir -p "$WORKTREE_DIR"

if git show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
  echo "Branch $BRANCH already exists. Creating worktree from existing branch..."
  git worktree add "$WORKTREE_PATH" "$BRANCH"
else
  echo "Creating new branch $BRANCH from main..."
  git worktree add -b "$BRANCH" "$WORKTREE_PATH" origin/main 2>/dev/null || \
    git worktree add -b "$BRANCH" "$WORKTREE_PATH" main
fi

# ── Run setup in the worktree ────────────────────────
echo "Running setup in worktree..."
if [ -f "$WORKTREE_PATH/scripts/setup.sh" ]; then
  (cd "$WORKTREE_PATH" && bash scripts/setup.sh 2>/dev/null) || true
fi

echo ""
echo "Worktree ready:"
echo "  Path:   $WORKTREE_PATH"
echo "  Branch: $BRANCH"
echo ""
echo "  cd $WORKTREE_PATH"
