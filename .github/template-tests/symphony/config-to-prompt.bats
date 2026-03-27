#!/usr/bin/env bats
# Tests parse-config -> render-prompt end-to-end pipeline.

load "../helpers/common"

setup() {
  setup_temp_repo

  # Copy the full workflow fixture so the prompt template is available
  cp "$BATS_TEST_DIRNAME/../helpers/fixtures/workflow-full.md" "$TEST_REPO/WORKFLOW.md"

  # Force bash fallback by removing node from PATH
  export PATH_ORIG="$PATH"
  export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v -E '(node|nodejs|nvm)' | tr '\n' ':' | sed 's/:$//')
}

teardown() {
  export PATH="$PATH_ORIG"
  teardown_temp_repo
}

@test "parse config then render prompt produces valid output" {
  # Step 1: Parse config
  run bash "$TEST_REPO/scripts/symphony/parse-config.sh" "$TEST_REPO/WORKFLOW.md"
  assert_success
  eval "$output"

  # Step 2: Render prompt with parsed config context
  run bash "$TEST_REPO/scripts/symphony/render-prompt.sh" \
    --number 42 --title "Test issue" --body "Fix things" \
    --labels "" --blocked-by "[]" --attempt ""
  assert_success
  assert_output --partial "#42"
  assert_output --partial "Test issue"
}
