#!/usr/bin/env bats
# Tests hook base64 round-trip encoding.

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

@test "hooks survive base64 round-trip" {
  run bash "$TEST_REPO/scripts/symphony/parse-config.sh" \
    "$BATS_TEST_DIRNAME/../helpers/fixtures/workflow-full.md"
  assert_success
  eval "$output"

  local decoded
  decoded=$(echo "$SYMPHONY_HOOK_AFTER_CREATE" | base64 -d 2>/dev/null || \
            echo "$SYMPHONY_HOOK_AFTER_CREATE" | base64 --decode 2>/dev/null)
  [[ "$decoded" == *"make setup"* ]]
}

@test "empty hooks decode to empty string" {
  run bash "$TEST_REPO/scripts/symphony/parse-config.sh" \
    "$BATS_TEST_DIRNAME/../helpers/fixtures/workflow-no-hooks.md"
  assert_success
  eval "$output"

  local decoded
  decoded=$(echo "$SYMPHONY_HOOK_AFTER_CREATE" | base64 -d 2>/dev/null || \
            echo "$SYMPHONY_HOOK_AFTER_CREATE" | base64 --decode 2>/dev/null || true)
  [ -z "$decoded" ]
}
