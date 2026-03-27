#!/usr/bin/env bats
# Unit tests for scripts/symphony/parse-config.sh

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

@test "parses minimal workflow with defaults" {
  run bash "$TEST_REPO/scripts/symphony/parse-config.sh" \
    "$BATS_TEST_DIRNAME/../helpers/fixtures/workflow-minimal.md"
  assert_success
  eval "$output"

  assert_equal "$SYMPHONY_TRACKER_KIND" "github"
  assert_equal "$SYMPHONY_AGENT" "claude"
  # Defaults
  assert_equal "$SYMPHONY_POLL_INTERVAL_MS" "900000"
  assert_equal "$SYMPHONY_WORKSPACE_ROOT" ".worktrees"
  assert_equal "$SYMPHONY_MAX_CONCURRENT" "5"
  assert_equal "$SYMPHONY_AGENT_MAX_TURNS" "50"
  assert_equal "$SYMPHONY_AGENT_MAX_BUDGET" "10"
}

@test "parses full workflow with all fields" {
  run bash "$TEST_REPO/scripts/symphony/parse-config.sh" \
    "$BATS_TEST_DIRNAME/../helpers/fixtures/workflow-full.md"
  assert_success
  eval "$output"

  assert_equal "$SYMPHONY_REPO" "test-owner/test-repo"
  assert_equal "$SYMPHONY_PROJECT_NUMBER" "42"
  assert_equal "$SYMPHONY_POLL_INTERVAL_MS" "600000"
  assert_equal "$SYMPHONY_WORKSPACE_ROOT" ".test-worktrees"
  assert_equal "$SYMPHONY_AGENT" "claude"
  assert_equal "$SYMPHONY_AGENT_MODEL" "opus"
  assert_equal "$SYMPHONY_AGENT_MAX_TURNS" "100"
  assert_equal "$SYMPHONY_AGENT_MAX_BUDGET" "25"
  assert_equal "$SYMPHONY_MAX_CONCURRENT" "3"
}

@test "parses codex agent config" {
  run bash "$TEST_REPO/scripts/symphony/parse-config.sh" \
    "$BATS_TEST_DIRNAME/../helpers/fixtures/workflow-codex.md"
  assert_success
  eval "$output"

  assert_equal "$SYMPHONY_AGENT" "codex"
  assert_equal "$SYMPHONY_AGENT_MODEL" "o3"
}

@test "extracts hooks as base64" {
  run bash "$TEST_REPO/scripts/symphony/parse-config.sh" \
    "$BATS_TEST_DIRNAME/../helpers/fixtures/workflow-full.md"
  assert_success
  eval "$output"

  local decoded
  decoded=$(echo "$SYMPHONY_HOOK_AFTER_CREATE" | base64 -d 2>/dev/null || echo "$SYMPHONY_HOOK_AFTER_CREATE" | base64 --decode 2>/dev/null)
  [[ "$decoded" == *"make setup"* ]]
}

@test "empty hooks when no hooks section" {
  run bash "$TEST_REPO/scripts/symphony/parse-config.sh" \
    "$BATS_TEST_DIRNAME/../helpers/fixtures/workflow-no-hooks.md"
  assert_success
  eval "$output"

  local decoded
  decoded=$(echo "$SYMPHONY_HOOK_AFTER_CREATE" | base64 -d 2>/dev/null || echo "$SYMPHONY_HOOK_AFTER_CREATE" | base64 --decode 2>/dev/null || true)
  [ -z "$decoded" ]
}

@test "fails when workflow file missing" {
  run bash "$TEST_REPO/scripts/symphony/parse-config.sh" \
    "/nonexistent/path/WORKFLOW.md"
  assert_failure
}

@test "reports prompt offset" {
  run bash "$TEST_REPO/scripts/symphony/parse-config.sh" \
    "$BATS_TEST_DIRNAME/../helpers/fixtures/workflow-full.md"
  assert_success
  eval "$output"

  # SYMPHONY_PROMPT_OFFSET should be a number > 0
  [[ "$SYMPHONY_PROMPT_OFFSET" =~ ^[0-9]+$ ]]
  [ "$SYMPHONY_PROMPT_OFFSET" -gt 0 ]
}
