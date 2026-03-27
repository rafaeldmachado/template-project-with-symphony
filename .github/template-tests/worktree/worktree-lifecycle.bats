#!/usr/bin/env bats
# Tests for scripts/worktree/create.sh and scripts/worktree/cleanup.sh

load "../helpers/common"

setup() {
  setup_temp_repo_with_remote
}

teardown() {
  teardown_temp_repo
}

@test "creates worktree with correct branch" {
  run bash -c "cd '$TEST_REPO' && bash scripts/worktree/create.sh 42"
  assert_success

  assert_dir_exists "$TEST_REPO/.worktrees/42"

  run git -C "$TEST_REPO" branch --list
  assert_output --partial "issue/42"
}

@test "duplicate creation exits 0 with message" {
  run bash -c "cd '$TEST_REPO' && bash scripts/worktree/create.sh 42"
  assert_success

  run bash -c "cd '$TEST_REPO' && bash scripts/worktree/create.sh 42"
  assert_success
  assert_output --partial "already exists"
}

@test "create fails without issue number" {
  run bash -c "cd '$TEST_REPO' && bash scripts/worktree/create.sh"
  assert_failure
  assert_output --partial "Usage"
}

@test "cleanup removes worktree" {
  run bash -c "cd '$TEST_REPO' && bash scripts/worktree/create.sh 42"
  assert_success
  assert_dir_exists "$TEST_REPO/.worktrees/42"

  run bash -c "cd '$TEST_REPO' && printf 'y\n' | bash scripts/worktree/cleanup.sh 42"
  assert_success

  assert_file_not_exists "$TEST_REPO/.worktrees/42"
}

@test "cleanup of nonexistent worktree exits 0" {
  run bash -c "cd '$TEST_REPO' && bash scripts/worktree/cleanup.sh 999"
  assert_success
  assert_output --partial "No worktree found"
}
