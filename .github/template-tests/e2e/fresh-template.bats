#!/usr/bin/env bats
# End-to-end test: simulate a new user adopting the template.

load "../helpers/common"

setup() {
  setup_temp_repo_with_remote
}

teardown() {
  teardown_temp_repo
}

@test "fresh template passes structural tests" {
  run bash "$TEST_REPO/scripts/checks/structure.sh"
  assert_success
}

@test "fresh template passes docs freshness" {
  run bash "$TEST_REPO/scripts/checks/docs-freshness.sh"
  assert_success
}

@test "worktree lifecycle works on fresh template" {
  run bash -c "cd '$TEST_REPO' && bash scripts/worktree/create.sh 1"
  assert_success
  assert_dir_exists "$TEST_REPO/.worktrees/1"

  run bash -c "cd '$TEST_REPO' && printf 'y\n' | bash scripts/worktree/cleanup.sh 1"
  assert_success
  assert_file_not_exists "$TEST_REPO/.worktrees/1"
}

@test "GC handles empty state" {
  run bash -c "cd '$TEST_REPO' && DRY_RUN=true bash scripts/gc/clean-branches.sh"
  assert_success

  run bash -c "cd '$TEST_REPO' && DRY_RUN=true bash scripts/gc/clean-worktrees.sh"
  assert_success

  run bash -c "cd '$TEST_REPO' && DRY_RUN=true GITHUB_TOKEN= bash scripts/gc/clean-deploys.sh"
  assert_success

  run bash -c "cd '$TEST_REPO' && DRY_RUN=true GITHUB_TOKEN= bash scripts/gc/clean-artifacts.sh"
  assert_success
}
