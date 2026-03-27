#!/usr/bin/env bats
# Unit tests for scripts/checks/structure.sh

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

@test "runs all structural test scripts" {
  # The template ships with default structural tests in tests/structural/
  run bash "$TEST_REPO/scripts/checks/structure.sh"
  assert_success
}

@test "reports PASS for passing tests" {
  run bash "$TEST_REPO/scripts/checks/structure.sh"
  assert_success
  assert_output --partial "PASS:"
}

@test "exits 1 if a structural test fails" {
  # Add a failing structural test
  cat > "$TEST_REPO/tests/structural/always-fail.sh" <<'STUB'
#!/usr/bin/env bash
echo "This test always fails"
exit 1
STUB
  chmod +x "$TEST_REPO/tests/structural/always-fail.sh"

  run bash "$TEST_REPO/scripts/checks/structure.sh"
  assert_failure
}
