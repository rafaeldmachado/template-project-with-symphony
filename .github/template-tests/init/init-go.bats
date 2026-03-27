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

# Input: name, desc, stack=4(Go), deploy=5(None), agent=3(None),
#         monitoring=4(None), scaffold=n
INIT_INPUTS="goapp\nGo app\n4\n5\n3\n4\nn\n"

@test "generates lint.sh with golangci-lint" {
  run_init_with_inputs "$INIT_INPUTS"

  assert_file_exist "$TEST_REPO/scripts/checks/lint.sh"
  run cat "$TEST_REPO/scripts/checks/lint.sh"
  assert_output --partial "golangci-lint"
}

@test "generates test.sh with go test" {
  run_init_with_inputs "$INIT_INPUTS"

  assert_file_exist "$TEST_REPO/scripts/checks/test.sh"
  run cat "$TEST_REPO/scripts/checks/test.sh"
  assert_output --partial "go test"
}

@test "generates CI workflow with go setup" {
  run_init_with_inputs "$INIT_INPUTS"

  assert_file_exist "$TEST_REPO/.github/workflows/ci.yml"
  run cat "$TEST_REPO/.github/workflows/ci.yml"
  assert_output --partial "setup-go"
}
