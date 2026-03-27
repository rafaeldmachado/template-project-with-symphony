#!/usr/bin/env bats
# Tests that tests/structural/architecture.sh correctly catches violations.

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

@test "passes on valid template repo" {
  run bash -c "cd '$TEST_REPO' && bash tests/structural/architecture.sh"
  assert_success
}

@test "fails when required file is missing" {
  rm -f "$TEST_REPO/AGENTS.md"

  run bash -c "cd '$TEST_REPO' && bash tests/structural/architecture.sh"
  assert_failure
  assert_output --partial "Required file missing: AGENTS.md"
}

@test "fails when source file exceeds 500 lines" {
  mkdir -p "$TEST_REPO/src"
  seq 501 | sed 's/.*/ /' > "$TEST_REPO/src/big.ts"

  (cd "$TEST_REPO" && git add -A && git commit -m "add big file" --no-gpg-sign) >/dev/null 2>&1

  run bash -c "cd '$TEST_REPO' && bash tests/structural/architecture.sh"
  assert_failure
  assert_output --partial "File too large"
}

@test "detects secrets in tracked files" {
  mkdir -p "$TEST_REPO/src"
  # Build the secret pattern dynamically to avoid this test file itself triggering detection
  local key="API_KEY"
  local val="sk-secret123"
  echo "${key}=\"${val}\"" > "$TEST_REPO/src/config.ts"

  (cd "$TEST_REPO" && git add -A && git commit -m "add secret" --no-gpg-sign) >/dev/null 2>&1

  run bash -c "cd '$TEST_REPO' && bash tests/structural/architecture.sh"
  assert_failure
  assert_output --partial "Possible secret"
}
