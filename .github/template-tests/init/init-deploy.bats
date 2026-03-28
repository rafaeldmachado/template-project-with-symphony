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
  # Input: name, desc, stack_cat=5(None), deploy=1(Vercel), token=(empty),
  #         project_id=(empty), agent=3(None), monitoring=4(None), runner=n
  local inputs="deployapp\nDeploy test\n5\n1\n\n\n3\n4\nn\n"
  run_init_with_inputs "$inputs"

  assert_file_exist "$TEST_REPO/.env"
  run cat "$TEST_REPO/.env"
  assert_output --partial "DEPLOY_PROVIDER=vercel"
}

@test "Netlify sets DEPLOY_PROVIDER=netlify" {
  # Input: name, desc, stack_cat=5(None), deploy=2(Netlify), token=(empty),
  #         site_id=(empty), agent=3(None), monitoring=4(None), runner=n
  local inputs="deployapp\nDeploy test\n5\n2\n\n\n3\n4\nn\n"
  run_init_with_inputs "$inputs"

  assert_file_exist "$TEST_REPO/.env"
  run cat "$TEST_REPO/.env"
  assert_output --partial "DEPLOY_PROVIDER=netlify"
}

@test "None sets empty DEPLOY_PROVIDER" {
  # Input: name, desc, stack_cat=5(None), deploy=5(None), agent=3(None),
  #         monitoring=4(None), runner=n
  local inputs="deployapp\nDeploy test\n5\n5\n3\n4\nn\n"
  run_init_with_inputs "$inputs"

  assert_file_exist "$TEST_REPO/.env"
  run cat "$TEST_REPO/.env"
  assert_output --partial "DEPLOY_PROVIDER="
}
