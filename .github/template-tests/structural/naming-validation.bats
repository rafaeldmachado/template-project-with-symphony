#!/usr/bin/env bats
# Tests that tests/structural/naming.sh correctly catches violations.

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

@test "passes when all scripts are executable" {
  run bash "$TEST_REPO/tests/structural/naming.sh"
  assert_success
}

@test "fails when a script is not executable" {
  cat > "$TEST_REPO/scripts/new-script.sh" <<'EOF'
#!/usr/bin/env bash
echo "hello"
EOF
  chmod -x "$TEST_REPO/scripts/new-script.sh"

  run bash "$TEST_REPO/tests/structural/naming.sh"
  assert_failure
  assert_output --partial "Script not executable"
}

@test "fails when filename contains spaces" {
  mkdir -p "$TEST_REPO/src"
  echo "content" > "$TEST_REPO/src/my file.ts"

  run bash "$TEST_REPO/tests/structural/naming.sh"
  assert_failure
  assert_output --partial "Filename contains spaces"
}
