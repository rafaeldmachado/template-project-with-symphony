#!/usr/bin/env bats
# Unit tests for scripts/symphony/render-prompt.sh (bash fallback path)

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

@test "substitutes issue variables" {
  run bash "$TEST_REPO/scripts/symphony/render-prompt.sh" \
    --number 42 --title "Fix bug" --body "Description here" \
    --labels "" --blocked-by "[]" --attempt ""
  assert_success
  assert_output --partial "#42"
  assert_output --partial "Fix bug"
  assert_output --partial "Description here"
}

@test "joins labels" {
  run bash "$TEST_REPO/scripts/symphony/render-prompt.sh" \
    --number 42 --title "Fix bug" --body "Desc" \
    --labels "bug,agent,p0" --blocked-by "[]" --attempt ""
  assert_success
  assert_output --partial "bug, agent, p0"
}

@test "includes blocker section when present" {
  run bash "$TEST_REPO/scripts/symphony/render-prompt.sh" \
    --number 42 --title "Fix bug" --body "Desc" \
    --labels "" --blocked-by '[{"identifier":"#10","state":"OPEN"}]' --attempt ""
  assert_success
  assert_output --partial "Blocked by"
}

@test "excludes blocker section when empty" {
  run bash "$TEST_REPO/scripts/symphony/render-prompt.sh" \
    --number 42 --title "Fix bug" --body "Desc" \
    --labels "" --blocked-by "[]" --attempt ""
  assert_success
  refute_output --partial "Blocked by"
}

@test "includes retry section with attempt" {
  run bash "$TEST_REPO/scripts/symphony/render-prompt.sh" \
    --number 42 --title "Fix bug" --body "Desc" \
    --labels "" --blocked-by "[]" --attempt "2"
  assert_success
  assert_output --partial "attempt 2"
}

@test "excludes retry section without attempt" {
  run bash "$TEST_REPO/scripts/symphony/render-prompt.sh" \
    --number 42 --title "Fix bug" --body "Desc" \
    --labels "" --blocked-by "[]" --attempt ""
  assert_success
  refute_output --partial "attempt"
}

@test "handles missing optional args" {
  run bash "$TEST_REPO/scripts/symphony/render-prompt.sh" \
    --number 42 --title "Fix"
  assert_success
}
