#!/usr/bin/env bats
# Tests GC scripts run without error in dry-run mode.

load "../helpers/common"

setup() {
  setup_temp_repo_with_remote
}

teardown() {
  teardown_temp_repo
}

@test "gc-branches runs in dry-run mode" {
  run bash -c "cd '$TEST_REPO' && DRY_RUN=true bash scripts/gc/clean-branches.sh"
  assert_success
  assert_output --partial "Branch cleanup complete"
}

@test "gc-worktrees runs in dry-run mode" {
  run bash -c "cd '$TEST_REPO' && DRY_RUN=true bash scripts/gc/clean-worktrees.sh"
  assert_success
  assert_output --partial "Garbage collecting worktrees"
}

@test "gc-deploys skips gracefully without gh token" {
  run bash -c "cd '$TEST_REPO' && DRY_RUN=true GITHUB_TOKEN= bash scripts/gc/clean-deploys.sh"
  assert_success
  assert_output --partial "Skipping deploy cleanup"
}

@test "gc-artifacts skips gracefully without gh token" {
  run bash -c "cd '$TEST_REPO' && DRY_RUN=true GITHUB_TOKEN= bash scripts/gc/clean-artifacts.sh"
  assert_success
  assert_output --partial "Skipping artifact cleanup"
}
