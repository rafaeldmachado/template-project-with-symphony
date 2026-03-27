#!/usr/bin/env bats
# Tests that all workflow YAML files are syntactically valid.

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

@test "all workflow YAML files are valid" {
  for file in "$TEST_REPO/_github/workflows/"*.yml; do
    [ -f "$file" ] || continue
    if command -v python3 &>/dev/null; then
      run python3 -c "import yaml; yaml.safe_load(open('$file'))"
      assert_success
    else
      # Fallback: check that the file is non-empty and starts with valid YAML
      run head -1 "$file"
      assert_success
      refute_output ""
    fi
  done
}

@test "template CI workflow is valid YAML" {
  local ci_file="$TEMPLATE_ROOT/.github/workflows/template-tests.yml"
  [ -f "$ci_file" ] || skip "template-tests.yml not found"

  if command -v python3 &>/dev/null; then
    run python3 -c "import yaml; yaml.safe_load(open('$ci_file'))"
    assert_success
  else
    # Fallback: basic non-empty check
    run head -1 "$ci_file"
    assert_success
    refute_output ""
  fi
}
