#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

E2E=false
if [ "${1:-}" = "--e2e" ]; then
  E2E=true
fi

echo "Running tests..."

if [ "$E2E" = true ]; then
  echo "  Running e2e tests..."
  # TODO: Add your e2e test runner. Examples:
  #
  # Node.js:
  #   npx playwright test
  #   npx cypress run
  #
  # Python:
  #   pytest tests/e2e/
  #
  # Generic:
  #   ./tests/e2e/run.sh
  echo "  No e2e tests configured yet. See tests/e2e/README.md"
else
  echo "  Running unit + integration tests..."
  # TODO: Add your test runner. Examples:
  #
  # Node.js:
  #   npx vitest run
  #   npx jest
  #
  # Python:
  #   pytest tests/ --ignore=tests/e2e
  #
  # Go:
  #   go test ./...
  #
  # Rust:
  #   cargo test
  echo "  No test runner configured yet. See tests/README.md"
fi

echo "Tests complete."
