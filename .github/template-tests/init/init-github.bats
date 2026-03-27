#!/usr/bin/env bats

load "../helpers/common"
load "../helpers/mock-gh"

setup() {
  setup_temp_repo
  setup_mock_gh
}

teardown() {
  teardown_temp_repo
}

@test "creates labels when gh available and user confirms" {
  # Input: name, desc, stack=7(None), GitHub=y, repo=accept default, labels=y,
  #         deploy=5(None), agent=3(None), monitoring=4(None)
  local inputs="ghapp\nGH test\n7\ny\n\ny\n5\n3\n4\n"
  run_init_with_inputs "$inputs"

  assert_file_exist "$TEST_REPO/.mocks/gh.calls"
  run cat "$TEST_REPO/.mocks/gh.calls"
  assert_output --partial "label create ready"
}

@test "skips GitHub when user declines" {
  # Input: name, desc, stack=7(None), GitHub=n,
  #         deploy=5(None), agent=3(None), monitoring=4(None)
  local inputs="ghapp\nGH test\n7\nn\n5\n3\n4\n"
  run_init_with_inputs "$inputs"

  if [ -f "$TEST_REPO/.mocks/gh.calls" ]; then
    run cat "$TEST_REPO/.mocks/gh.calls"
    refute_output --partial "label create"
  fi
}
