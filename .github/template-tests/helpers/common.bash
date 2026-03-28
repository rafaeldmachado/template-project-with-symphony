# Shared helpers for template tests.
# Loaded via: load "../helpers/common"

# ── Locate bats helper libraries ───────────────────────
if [ -n "${BATS_LIB_PATH:-}" ]; then
  BATS_LIBS="$BATS_LIB_PATH"
elif [ -d "${BATS_TEST_DIRNAME}/../node_modules/bats-assert" ]; then
  BATS_LIBS="${BATS_TEST_DIRNAME}/../node_modules"
else
  BATS_LIBS="$(cd "${BATS_TEST_DIRNAME}/.." && npm root 2>/dev/null || echo "${BATS_TEST_DIRNAME}/../node_modules")"
fi

load "$BATS_LIBS/bats-support/load"
load "$BATS_LIBS/bats-assert/load"

# bats-file helpers (inline — npm package is a stub)
assert_file_exists() { [ -f "$1" ] || { echo "expected file to exist: $1"; return 1; }; }
assert_file_not_exists() { [ ! -f "$1" ] || { echo "expected file NOT to exist: $1"; return 1; }; }
assert_dir_exists() { [ -d "$1" ] || { echo "expected directory to exist: $1"; return 1; }; }
# Aliases without trailing 's' (common bats-file convention)
assert_file_exist() { [ -f "$1" ] || [ -d "$1" ] || { echo "expected to exist: $1"; return 1; }; }
assert_file_not_exist() { [ ! -f "$1" ] && [ ! -d "$1" ] || { echo "expected NOT to exist: $1"; return 1; }; }

# ── Template root ──────────────────────────────────────
TEMPLATE_ROOT="${TEMPLATE_ROOT:-$(cd "${BATS_TEST_DIRNAME}/../../../" && pwd)}"
export TEMPLATE_ROOT

# ── Create a fresh temp copy of the template ───────────
# Initializes a git repo so git-dependent scripts work.
# Sets TEST_REPO to the temp directory path.
setup_temp_repo() {
  TEST_REPO="$(mktemp -d "${BATS_TMPDIR:-/tmp}/template-test-XXXXXX")"

  # Copy template contents (exclude .git and node_modules)
  rsync -a \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='.worktrees' \
    --exclude='.deploy-artifacts' \
    "$TEMPLATE_ROOT/" "$TEST_REPO/"

  # Initialize a git repo with an initial commit
  (
    cd "$TEST_REPO"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test"
    git add -A
    git commit -m "Initial commit" --no-gpg-sign
  ) >/dev/null 2>&1
}

# ── Create a temp git repo with a bare remote ──────────
# For worktree tests that need push/fetch operations.
# Sets TEST_REPO (working clone) and TEST_BARE (bare remote).
setup_temp_repo_with_remote() {
  setup_temp_repo

  TEST_BARE="$(mktemp -d "${BATS_TMPDIR:-/tmp}/template-bare-XXXXXX")"
  git clone --bare "$TEST_REPO" "$TEST_BARE" >/dev/null 2>&1

  (
    cd "$TEST_REPO"
    git remote remove origin 2>/dev/null || true
    git remote add origin "$TEST_BARE"
    git push -u origin main
  ) >/dev/null 2>&1
}

# ── Clean up temp directories ──────────────────────────
teardown_temp_repo() {
  if [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ]; then
    rm -rf "$TEST_REPO"
  fi
  if [ -n "${TEST_BARE:-}" ] && [ -d "$TEST_BARE" ]; then
    rm -rf "$TEST_BARE"
  fi
}

# ── Mock a command by putting a script on PATH ─────────
# Usage: mock_command <name> <script-body>
# The mock records each invocation to $TEST_REPO/.mocks/<name>.calls
mock_command() {
  local name="$1" body="$2"
  local mock_dir="$TEST_REPO/.mocks"
  mkdir -p "$mock_dir"

  cat > "$mock_dir/$name" <<MOCK_EOF
#!/usr/bin/env bash
echo "\$@" >> "$mock_dir/${name}.calls"
$body
MOCK_EOF
  chmod +x "$mock_dir/$name"
  export PATH="$mock_dir:$PATH"
}

# ── Build a PATH that excludes a specific command ──────
# Usage: path_without <command-name>
# Returns a colon-separated PATH with the target command removed.
# If the target lives in a directory with other essential tools (e.g. /usr/bin),
# a shadow directory with symlinks to everything EXCEPT the target is used
# so that bash, rm, cat, etc. remain available.
path_without() {
  local cmd="$1"
  local new_path=""
  local IFS=':'
  for dir in $PATH; do
    [ -z "$dir" ] && continue
    if [ ! -x "$dir/$cmd" ]; then
      new_path="${new_path:+$new_path:}$dir"
    else
      # Directory contains the target — create a shadow with everything else
      local shadow_dir
      shadow_dir="$(mktemp -d "${BATS_TMPDIR:-/tmp}/path-shadow-XXXXXX")"
      for f in "$dir"/*; do
        [ ! -f "$f" ] && continue
        local name="${f##*/}"
        [ "$name" = "$cmd" ] && continue
        ln -sf "$f" "$shadow_dir/$name" 2>/dev/null || true
      done
      new_path="${new_path:+$new_path:}$shadow_dir"
    fi
  done
  echo "$new_path"
}

# ── Pipe answers to the init wizard ────────────────────
# Usage: run_init_with_inputs "answer1\nanswer2\n..."
# Times out after 60s to prevent hangs from insufficient inputs.
run_init_with_inputs() {
  local inputs="$1"
  local timeout_cmd=""
  if command -v timeout &>/dev/null; then
    timeout_cmd="timeout 60"
  fi
  printf '%b' "$inputs" | $timeout_cmd bash "$TEST_REPO/scripts/init.sh" 2>&1
}
