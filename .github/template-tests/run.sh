#!/usr/bin/env bash
set -euo pipefail

# Template test runner.
# Installs bats-core if needed, then runs the test suites.
#
# Usage:
#   ./run.sh              # run all tests
#   ./run.sh unit         # run only unit tests
#   ./run.sh init         # run only init wizard tests
#   ./run.sh e2e          # run only end-to-end tests
#   ./run.sh <dir>        # run tests in a specific subdirectory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Install bats if needed ─────────────────────────────
BATS=""
if command -v bats &>/dev/null; then
  BATS="bats"
elif [ -x "$SCRIPT_DIR/node_modules/.bin/bats" ]; then
  BATS="$SCRIPT_DIR/node_modules/.bin/bats"
else
  echo "Installing bats-core..."
  [ -f "$SCRIPT_DIR/package.json" ] || echo '{"private":true}' > "$SCRIPT_DIR/package.json"
  (cd "$SCRIPT_DIR" && npm install --save-dev bats bats-assert bats-support 2>/dev/null)
  BATS="$SCRIPT_DIR/node_modules/.bin/bats"
fi

if [ ! -x "$BATS" ] && ! command -v "$BATS" &>/dev/null; then
  echo "ERROR: Could not find or install bats. Install it manually:"
  echo "  npm install -g bats bats-assert bats-support"
  exit 1
fi

# ── Resolve bats helper library paths ──────────────────
# Try npm-installed location first, then system locations
for candidate in \
  "$SCRIPT_DIR/node_modules" \
  "$(npm root -g 2>/dev/null || true)" \
  "/usr/lib" \
  "/usr/local/lib"; do
  if [ -d "$candidate/bats-assert" ]; then
    export BATS_LIB_PATH="$candidate"
    break
  fi
done

export TEMPLATE_ROOT="$ROOT_DIR"

# ── Select test directories ────────────────────────────
SUITE="${1:-all}"

case "$SUITE" in
  all)
    DIRS=(
      "$SCRIPT_DIR/unit"
      "$SCRIPT_DIR/init"
      "$SCRIPT_DIR/worktree"
      "$SCRIPT_DIR/structural"
      "$SCRIPT_DIR/integration"
      "$SCRIPT_DIR/symphony"
      "$SCRIPT_DIR/workflows"
      "$SCRIPT_DIR/e2e"
    )
    ;;
  unit|init|worktree|structural|integration|symphony|workflows|e2e)
    DIRS=("$SCRIPT_DIR/$SUITE")
    ;;
  *)
    if [ -d "$SCRIPT_DIR/$SUITE" ]; then
      DIRS=("$SCRIPT_DIR/$SUITE")
    else
      echo "Unknown suite: $SUITE"
      echo "Usage: $0 [all|unit|init|worktree|structural|integration|symphony|workflows|e2e]"
      exit 1
    fi
    ;;
esac

# ── Filter to directories that have .bats files ────────
RUN_DIRS=()
for dir in "${DIRS[@]}"; do
  if [ -d "$dir" ] && compgen -G "$dir/*.bats" >/dev/null 2>&1; then
    RUN_DIRS+=("$dir")
  fi
done

if [ ${#RUN_DIRS[@]} -eq 0 ]; then
  echo "No test files found for suite: $SUITE"
  exit 0
fi

# ── Run tests ──────────────────────────────────────────
echo "Running template tests ($SUITE)..."
echo ""

"$BATS" --formatter tap "${RUN_DIRS[@]}"
