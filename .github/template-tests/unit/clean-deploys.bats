#!/usr/bin/env bats
# Unit tests for scripts/gc/clean-deploys.sh

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

@test "exits cleanly when gh not available" {
  local no_gh_path
  no_gh_path="$(path_without gh)"

  run bash -c "cd '$TEST_REPO' && PATH='$no_gh_path' bash scripts/gc/clean-deploys.sh"
  assert_success
  assert_output --partial "gh CLI not available"
}

@test "exits cleanly when GITHUB_TOKEN not set" {
  mock_command gh "echo 'mock gh'"
  unset GITHUB_TOKEN

  run bash -c "cd '$TEST_REPO' && bash scripts/gc/clean-deploys.sh"
  assert_success
  assert_output --partial "GITHUB_TOKEN not set"
}
