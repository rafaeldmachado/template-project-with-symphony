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

# Input: name, desc, stack_cat=3(Backend), framework=12(Node.js TS no framework),
#         deploy=5(None), agent=1(Claude), api_key=(empty),
#         monitoring=4(None), runner=n, scaffold=n
INIT_INPUTS="my-app\nMy app desc\n3\n12\n5\n1\n\n4\nn\nn\n"

@test "generates lint.sh with eslint and prettier" {
  run_init_with_inputs "$INIT_INPUTS"

  assert_file_exist "$TEST_REPO/scripts/checks/lint.sh"
  run cat "$TEST_REPO/scripts/checks/lint.sh"
  assert_output --partial "npx eslint"
  assert_output --partial "npx prettier"
}

@test "generates test.sh with vitest" {
  run_init_with_inputs "$INIT_INPUTS"

  assert_file_exist "$TEST_REPO/scripts/checks/test.sh"
  run cat "$TEST_REPO/scripts/checks/test.sh"
  assert_output --partial "npx vitest run"
}

@test "generates CI workflow with node setup" {
  run_init_with_inputs "$INIT_INPUTS"

  assert_file_exist "$TEST_REPO/.github/workflows/ci.yml"
  run cat "$TEST_REPO/.github/workflows/ci.yml"
  assert_output --partial "setup-node"
  assert_output --partial "npm"
}

@test "creates .env with ANTHROPIC_API_KEY" {
  run_init_with_inputs "$INIT_INPUTS"

  assert_file_exist "$TEST_REPO/.env"
  run cat "$TEST_REPO/.env"
  assert_output --partial "ANTHROPIC_API_KEY="
}
