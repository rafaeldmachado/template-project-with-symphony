#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILED=0

echo "Running structural tests..."

# ── Run structural test scripts ──────────────────────
if [ -d "$ROOT_DIR/tests/structural" ]; then
  for test_file in "$ROOT_DIR/tests/structural/"*.sh; do
    [ -f "$test_file" ] || continue
    echo "  Running $(basename "$test_file")..."
    if bash "$test_file"; then
      echo "  PASS: $(basename "$test_file")"
    else
      echo "  ERROR: [structure] $(basename "$test_file") failed"
      FAILED=1
    fi
  done
fi

if [ "$FAILED" -ne 0 ]; then
  echo "Structural tests failed."
  exit 1
else
  echo "Structural tests passed."
fi
