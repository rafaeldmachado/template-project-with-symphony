#!/usr/bin/env bats
# Unit tests for scripts/gc/clean-worktrees.sh

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

@test "exits cleanly when no worktree directory exists" {
  rm -rf "$TEST_REPO/.worktrees"

  run bash -c "cd '$TEST_REPO' && bash scripts/gc/clean-worktrees.sh"
  assert_success
  assert_output --partial "No worktree directory found"
}

@test "DRY_RUN=true reports but doesn't remove" {
  mkdir -p "$TEST_REPO/.worktrees/42"

  export DRY_RUN=true
  run bash -c "cd '$TEST_REPO' && bash scripts/gc/clean-worktrees.sh"
  assert_success
  assert_output --partial "[dry-run]"

  # Directory should still exist
  [ -d "$TEST_REPO/.worktrees/42" ]
}
