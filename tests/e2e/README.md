# End-to-End Tests

E2E tests validate complete user journeys against a running application.

## Setup

Configure your E2E test framework in `scripts/checks/test.sh` (the `--e2e` branch).

Recommended frameworks by stack:
- **Node.js**: Playwright, Cypress
- **Python**: pytest + requests, Selenium
- **Go**: httptest, testcontainers
- **Generic**: curl-based scripts

## Running

```bash
make test-e2e
```

## Writing E2E tests

1. Each test should represent a complete user journey
2. Tests must be idempotent — safe to run multiple times
3. Tests should work against both local dev and preview deploys
4. Use the `BASE_URL` env var to target different environments:
   - Local: `http://localhost:3000`
   - Preview: read from `.deploy-artifacts/preview-url.txt`

## Placeholder

Add your first E2E test here. A good starting point is a health check:

```bash
#!/usr/bin/env bash
# tests/e2e/health.sh
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:3000}"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health")
if [ "$STATUS" != "200" ]; then
  echo "ERROR: [e2e] Health check failed. Expected 200, got $STATUS"
  exit 1
fi
echo "PASS: Health check"
```
