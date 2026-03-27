#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Setting up project..."

# ── Make all scripts executable ──────────────────────
find "$ROOT_DIR/scripts" -name "*.sh" -exec chmod +x {} \;

# ── Create required directories ──────────────────────
mkdir -p "$ROOT_DIR/.worktrees"
mkdir -p "$ROOT_DIR/.deploy-artifacts"

# ── Copy environment template if needed ──────────────
if [ ! -f "$ROOT_DIR/.env" ] && [ -f "$ROOT_DIR/.env.example" ]; then
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
  echo "Created .env from .env.example — fill in your values."
fi

# ── Project-specific setup ───────────────────────────
# TODO: Add your dependency installation here. Examples:
#
# Node.js:
#   npm ci
#
# Python:
#   python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
#
# Go:
#   go mod download
#
# Rust:
#   cargo fetch

echo "Setup complete. Run 'make check' to validate."
