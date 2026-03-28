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

# Input: name, desc, stack_cat=5(None), deploy=5(None), agent=3(None),
#         monitoring=4(None), runner=n
INIT_INPUTS="test-project\nA test project\n5\n5\n3\n4\nn\n"

@test "removes template-specific files" {
  run_init_with_inputs "$INIT_INPUTS"

  # Template-specific files should be removed
  assert_file_not_exist "$TEST_REPO/CONTRIBUTING.md"
  assert_file_not_exist "$TEST_REPO/CODE_OF_CONDUCT.md"
  assert_file_not_exist "$TEST_REPO/SECURITY.md"
  assert_file_not_exist "$TEST_REPO/LICENSE"
  assert_file_not_exist "$TEST_REPO/.env.example"

  # README should have been replaced (no longer the template README)
  run cat "$TEST_REPO/README.md"
  refute_output --partial "template repo"
}

@test "generates project README with correct name" {
  run_init_with_inputs "$INIT_INPUTS"

  assert_file_exist "$TEST_REPO/README.md"
  run cat "$TEST_REPO/README.md"
  assert_output --partial "# test-project"
  assert_output --partial "A test project"
}

@test "replaces .github with _github contents" {
  run_init_with_inputs "$INIT_INPUTS"

  # _github/ should be gone after init
  assert_file_not_exist "$TEST_REPO/_github"
  # .github/ should exist with workflow files from _github
  assert_file_exist "$TEST_REPO/.github"
  assert_file_exist "$TEST_REPO/.github/workflows"

  run ls "$TEST_REPO/.github/workflows/"
  assert_success
}

@test ".env.example is removed after init" {
  run_init_with_inputs "$INIT_INPUTS"

  assert_file_not_exist "$TEST_REPO/.env.example"
  assert_file_exist "$TEST_REPO/.env"
}
