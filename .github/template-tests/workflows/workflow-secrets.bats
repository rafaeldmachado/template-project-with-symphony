#!/usr/bin/env bats
# Tests that referenced secrets are documented in .env.example or docs/SETUP.md.

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

@test "referenced secrets are documented" {
  local secrets=(ANTHROPIC_API_KEY OPENAI_API_KEY DEPLOY_TOKEN PROJECT_TOKEN)

  for secret in "${secrets[@]}"; do
    local found=false

    if grep -q "$secret" "$TEST_REPO/.env.example" 2>/dev/null; then
      found=true
    fi
    if grep -q "$secret" "$TEST_REPO/docs/SETUP.md" 2>/dev/null; then
      found=true
    fi

    if [ "$found" = false ]; then
      echo "Secret $secret is not documented in .env.example or docs/SETUP.md"
      return 1
    fi
  done
}
