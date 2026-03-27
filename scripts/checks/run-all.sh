#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0

echo "=== Running all checks ==="

echo ""
echo "--- Lint ---"
if "$SCRIPT_DIR/lint.sh"; then
  echo "PASS: lint"
else
  echo "ERROR: [lint] Linting failed"
  FAILED=1
fi

echo ""
echo "--- Structure ---"
if "$SCRIPT_DIR/structure.sh"; then
  echo "PASS: structure"
else
  echo "ERROR: [structure] Structural tests failed"
  FAILED=1
fi

echo ""
echo "--- Tests ---"
if "$SCRIPT_DIR/test.sh"; then
  echo "PASS: tests"
else
  echo "ERROR: [tests] Tests failed"
  FAILED=1
fi

echo ""
echo "--- Docs freshness ---"
if "$SCRIPT_DIR/docs-freshness.sh"; then
  echo "PASS: docs-freshness"
else
  echo "ERROR: [docs] Documentation freshness check failed"
  FAILED=1
fi

echo ""
if [ "$FAILED" -ne 0 ]; then
  echo "=== SOME CHECKS FAILED ==="
  exit 1
else
  echo "=== ALL CHECKS PASSED ==="
fi
