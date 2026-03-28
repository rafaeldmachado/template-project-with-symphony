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

@test "Claude selection sets agent name in WORKFLOW.md" {
  # Input: name, desc, stack_cat=5(None), deploy=5(None), agent=1(Claude),
  #         api_key=(empty), monitoring=4(None), runner=n
  local inputs="agentapp\nAgent test\n5\n5\n1\n\n4\nn\n"
  run_init_with_inputs "$inputs"

  assert_file_exist "$TEST_REPO/WORKFLOW.md"
  run cat "$TEST_REPO/WORKFLOW.md"
  assert_output --partial "name: claude"
}

@test "Codex selection sets agent name in WORKFLOW.md" {
  # Input: name, desc, stack_cat=5(None), deploy=5(None), agent=2(Codex),
  #         api_key=(empty), monitoring=4(None), runner=n
  local inputs="agentapp\nAgent test\n5\n5\n2\n\n4\nn\n"
  run_init_with_inputs "$inputs"

  assert_file_exist "$TEST_REPO/WORKFLOW.md"
  run cat "$TEST_REPO/WORKFLOW.md"
  assert_output --partial "name: codex"
}

@test "Claude sets ANTHROPIC_API_KEY in .env" {
  # Input: name, desc, stack_cat=5(None), deploy=5(None), agent=1(Claude),
  #         api_key=(empty), monitoring=4(None), runner=n
  local inputs="agentapp\nAgent test\n5\n5\n1\n\n4\nn\n"
  run_init_with_inputs "$inputs"

  assert_file_exist "$TEST_REPO/.env"
  run cat "$TEST_REPO/.env"
  assert_output --partial "ANTHROPIC_API_KEY="
}

@test "Codex sets OPENAI_API_KEY in .env" {
  # Input: name, desc, stack_cat=5(None), deploy=5(None), agent=2(Codex),
  #         api_key=(empty), monitoring=4(None), runner=n
  local inputs="agentapp\nAgent test\n5\n5\n2\n\n4\nn\n"
  run_init_with_inputs "$inputs"

  assert_file_exist "$TEST_REPO/.env"
  run cat "$TEST_REPO/.env"
  assert_output --partial "OPENAI_API_KEY="
}
