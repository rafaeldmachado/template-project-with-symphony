#!/usr/bin/env bats
# Unit tests for scripts/setup.sh

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

@test "makes scripts executable" {
  # Remove execute permission from a script
  chmod -x "$TEST_REPO/scripts/checks/run-all.sh"

  run bash "$TEST_REPO/scripts/setup.sh"
  assert_success

  # Verify the script is executable again
  [ -x "$TEST_REPO/scripts/checks/run-all.sh" ]
}

@test "creates required directories" {
  rm -rf "$TEST_REPO/.worktrees"
  rm -rf "$TEST_REPO/.deploy-artifacts"

  run bash "$TEST_REPO/scripts/setup.sh"
  assert_success

  [ -d "$TEST_REPO/.worktrees" ]
  [ -d "$TEST_REPO/.deploy-artifacts" ]
}

@test "copies .env.example to .env when missing" {
  # Ensure .env.example exists and .env does not
  echo "MY_VAR=example" > "$TEST_REPO/.env.example"
  rm -f "$TEST_REPO/.env"

  run bash "$TEST_REPO/scripts/setup.sh"
  assert_success

  [ -f "$TEST_REPO/.env" ]
}

@test "does not overwrite existing .env" {
  echo "MY_VAR=example" > "$TEST_REPO/.env.example"
  echo "KEEP_THIS=preserved" > "$TEST_REPO/.env"

  run bash "$TEST_REPO/scripts/setup.sh"
  assert_success

  run cat "$TEST_REPO/.env"
  assert_output --partial "KEEP_THIS=preserved"
}
