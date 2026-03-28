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

# Input: name, desc, stack_cat=3(Backend), framework=1(FastAPI), deploy=5(None),
#         agent=3(None), monitoring=4(None), runner=n, scaffold=n
INIT_INPUTS="pyapp\nPython app\n3\n1\n5\n3\n4\nn\nn\n"

@test "generates lint.sh with ruff" {
  run_init_with_inputs "$INIT_INPUTS"

  assert_file_exist "$TEST_REPO/scripts/checks/lint.sh"
  run cat "$TEST_REPO/scripts/checks/lint.sh"
  assert_output --partial "ruff check"
  assert_output --partial "ruff format"
}

@test "generates test.sh with pytest" {
  run_init_with_inputs "$INIT_INPUTS"

  assert_file_exist "$TEST_REPO/scripts/checks/test.sh"
  run cat "$TEST_REPO/scripts/checks/test.sh"
  assert_output --partial "pytest"
}

@test "generates CI workflow with python setup" {
  run_init_with_inputs "$INIT_INPUTS"

  assert_file_exist "$TEST_REPO/.github/workflows/ci.yml"
  run cat "$TEST_REPO/.github/workflows/ci.yml"
  assert_output --partial "setup-python"
  assert_output --partial "python-version"
}
