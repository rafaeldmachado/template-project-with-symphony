#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "Running linters..."

# ── Shell script linting ─────────────────────────────
if command -v shellcheck &>/dev/null; then
  echo "  shellcheck: checking scripts/"
  find "$ROOT_DIR/scripts" -name "*.sh" -exec shellcheck -S warning {} + 2>&1 || true
else
  echo "  shellcheck: not installed, skipping (install: brew install shellcheck)"
fi

# ── Project-specific linters ─────────────────────────
# TODO: Add your linters here. Examples:
#
# Node.js:
#   npx eslint . --max-warnings 0
#   npx prettier --check .
#
# Python:
#   ruff check .
#   ruff format --check .
#
# Go:
#   golangci-lint run
#
# Rust:
#   cargo clippy -- -D warnings
#   cargo fmt -- --check

echo "Lint complete."
