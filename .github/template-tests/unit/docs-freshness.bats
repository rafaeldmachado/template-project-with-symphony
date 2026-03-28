#!/usr/bin/env bats
# Unit tests for scripts/checks/docs-freshness.sh

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

@test "passes when all required docs exist" {
  run bash "$TEST_REPO/scripts/checks/docs-freshness.sh"
  assert_success
}

@test "fails when a required doc is missing" {
  rm -f "$TEST_REPO/CLAUDE.md"

  run bash "$TEST_REPO/scripts/checks/docs-freshness.sh"
  assert_failure
  assert_output --partial "Missing required doc: CLAUDE.md"
}

@test "detects broken internal links" {
  # Create a markdown file with a broken link
  cat > "$TEST_REPO/docs/broken-links-test.md" <<'EOF'
# Test document

See [this guide](nonexistent.md) for details.
EOF

  run bash "$TEST_REPO/scripts/checks/docs-freshness.sh"
  assert_output --partial "Broken link"
}
