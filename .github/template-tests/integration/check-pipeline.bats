#!/usr/bin/env bats
# Tests make check orchestration via scripts/checks/run-all.sh

load "../helpers/common"

setup() {
  setup_temp_repo

  # Mock all sub-check scripts to succeed by default
  for script in lint.sh test.sh structure.sh docs-freshness.sh; do
    cat > "$TEST_REPO/scripts/checks/$script" <<'MOCK'
#!/bin/bash
echo "OK"
exit 0
MOCK
    chmod +x "$TEST_REPO/scripts/checks/$script"
  done
}

teardown() {
  teardown_temp_repo
}

@test "make check calls all sub-checks" {
  run bash "$TEST_REPO/scripts/checks/run-all.sh"
  assert_success
  assert_output --partial "--- Lint ---"
  assert_output --partial "--- Structure ---"
  assert_output --partial "--- Tests ---"
  assert_output --partial "--- Docs freshness ---"
}

@test "exits 1 if any sub-check fails" {
  # Make structure.sh fail
  cat > "$TEST_REPO/scripts/checks/structure.sh" <<'MOCK'
#!/bin/bash
echo "FAIL"
exit 1
MOCK
  chmod +x "$TEST_REPO/scripts/checks/structure.sh"

  run bash "$TEST_REPO/scripts/checks/run-all.sh"
  assert_failure
  assert_output --partial "SOME CHECKS FAILED"
}

@test "exits 0 when all pass" {
  run bash "$TEST_REPO/scripts/checks/run-all.sh"
  assert_success
  assert_output --partial "ALL CHECKS PASSED"
}
