#!/usr/bin/env bats

load "../helpers/common"

setup() {
  setup_temp_repo
  # Hide gh to simplify input sequence (skip GitHub config step)
  export PATH="$(path_without gh)"
}

teardown() {
  teardown_temp_repo
}

@test "Vercel sets DEPLOY_PROVIDER=vercel" {
  # Input: name, desc, stack=7(None), deploy=1(Vercel), agent=3(None), monitoring=4(None)
  local inputs="deployapp\nDeploy test\n7\n1\n3\n4\n"
  run_init_with_inputs "$inputs"

  assert_file_exist "$TEST_REPO/.env"
  run cat "$TEST_REPO/.env"
  assert_output --partial "DEPLOY_PROVIDER=vercel"
}

@test "Netlify sets DEPLOY_PROVIDER=netlify" {
  # Input: name, desc, stack=7(None), deploy=2(Netlify), agent=3(None), monitoring=4(None)
  local inputs="deployapp\nDeploy test\n7\n2\n3\n4\n"
  run_init_with_inputs "$inputs"

  assert_file_exist "$TEST_REPO/.env"
  run cat "$TEST_REPO/.env"
  assert_output --partial "DEPLOY_PROVIDER=netlify"
}

@test "None sets empty DEPLOY_PROVIDER" {
  # Input: name, desc, stack=7(None), deploy=5(None), agent=3(None), monitoring=4(None)
  local inputs="deployapp\nDeploy test\n7\n5\n3\n4\n"
  run_init_with_inputs "$inputs"

  assert_file_exist "$TEST_REPO/.env"
  run cat "$TEST_REPO/.env"
  assert_output --partial "DEPLOY_PROVIDER="
}
