#!/usr/bin/env bats
# Tests that all documented Makefile targets exist.

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

@test "all documented targets exist in Makefile" {
  local targets=(help init setup check lint test test-e2e structure
    worktree worktree-cleanup gc gc-branches gc-worktrees gc-deploys
    gc-artifacts deploy-preview deploy-cleanup test-template)
  for target in "${targets[@]}"; do
    grep -qE "^${target}:" "$TEST_REPO/Makefile" || {
      echo "Missing target: $target"
      return 1
    }
  done
}

@test "make help produces output" {
  run make -C "$TEST_REPO" help
  assert_success
  assert_output --partial "help"
}
