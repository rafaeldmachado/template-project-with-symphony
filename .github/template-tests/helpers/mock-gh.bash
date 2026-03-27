# gh CLI mock for template tests.
#
# Usage in tests:
#   source helpers/mock-gh.bash
#   setup_mock_gh
#
# Control behavior via env vars:
#   MOCK_GH_LABEL_FAIL=true    — make label creation fail
#   MOCK_GH_REPO="owner/repo"  — repo returned by gh repo view

setup_mock_gh() {
  local mock_dir="$TEST_REPO/.mocks"
  mkdir -p "$mock_dir"

  cat > "$mock_dir/gh" <<'GH_MOCK'
#!/usr/bin/env bash
MOCK_DIR="$(dirname "$0")"
echo "$@" >> "$MOCK_DIR/gh.calls"

case "$1" in
  label)
    if [ "${MOCK_GH_LABEL_FAIL:-}" = "true" ]; then
      echo "error creating label" >&2
      exit 1
    fi
    exit 0
    ;;
  repo)
    case "$2" in
      view)
        echo "${MOCK_GH_REPO:-test-owner/test-repo}"
        exit 0
        ;;
    esac
    ;;
  pr)
    case "$2" in
      list)
        echo ""
        exit 0
        ;;
    esac
    ;;
  api)
    echo '{"artifacts":[]}'
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
GH_MOCK

  chmod +x "$mock_dir/gh"
  export PATH="$mock_dir:$PATH"
}
