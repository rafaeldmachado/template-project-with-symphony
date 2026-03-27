#!/usr/bin/env bats
# Unit tests for scripts/deploy/pr-preview.sh

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

@test "fails without PR number" {
  run bash "$TEST_REPO/scripts/deploy/pr-preview.sh"
  assert_failure
  assert_output --partial "Usage"
}

@test "skips when no DEPLOY_PROVIDER" {
  unset DEPLOY_PROVIDER

  run bash "$TEST_REPO/scripts/deploy/pr-preview.sh" 123
  assert_success
  assert_output --partial "No DEPLOY_PROVIDER"
}

@test "creates .deploy-artifacts directory" {
  rm -rf "$TEST_REPO/.deploy-artifacts"
  unset DEPLOY_PROVIDER

  run bash "$TEST_REPO/scripts/deploy/pr-preview.sh" 123
  assert_success
  [ -d "$TEST_REPO/.deploy-artifacts" ]
}

@test "fails for unconfigured provider" {
  export DEPLOY_PROVIDER=vercel

  run bash "$TEST_REPO/scripts/deploy/pr-preview.sh" 123
  assert_failure
  assert_output --partial "not configured"
}
