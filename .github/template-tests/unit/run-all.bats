#!/usr/bin/env bats
# Unit tests for scripts/checks/run-all.sh

load "../helpers/common"

setup() {
  setup_temp_repo

  # Replace all subscripts with simple pass stubs
  cat > "$TEST_REPO/scripts/checks/lint.sh" <<'STUB'
#!/usr/bin/env bash
echo "lint: ok"
exit 0
STUB
  chmod +x "$TEST_REPO/scripts/checks/lint.sh"

  cat > "$TEST_REPO/scripts/checks/structure.sh" <<'STUB'
#!/usr/bin/env bash
echo "structure: ok"
exit 0
STUB
  chmod +x "$TEST_REPO/scripts/checks/structure.sh"

  cat > "$TEST_REPO/scripts/checks/test.sh" <<'STUB'
#!/usr/bin/env bash
echo "test: ok"
exit 0
STUB
  chmod +x "$TEST_REPO/scripts/checks/test.sh"

  cat > "$TEST_REPO/scripts/checks/docs-freshness.sh" <<'STUB'
#!/usr/bin/env bash
echo "docs-freshness: ok"
exit 0
STUB
  chmod +x "$TEST_REPO/scripts/checks/docs-freshness.sh"
}

teardown() {
  teardown_temp_repo
}

@test "calls lint, structure, test, and docs-freshness" {
  run bash "$TEST_REPO/scripts/checks/run-all.sh"
  assert_success
  assert_output --partial "--- Lint ---"
  assert_output --partial "--- Structure ---"
  assert_output --partial "--- Tests ---"
  assert_output --partial "--- Docs freshness ---"
}

@test "exits 1 if any check fails" {
  # Make structure.sh fail
  cat > "$TEST_REPO/scripts/checks/structure.sh" <<'STUB'
#!/usr/bin/env bash
echo "structure: FAIL"
exit 1
STUB
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
