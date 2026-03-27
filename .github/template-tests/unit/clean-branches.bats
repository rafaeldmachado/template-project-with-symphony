#!/usr/bin/env bats
# Unit tests for scripts/gc/clean-branches.sh

load "../helpers/common"

setup() {
  setup_temp_repo
}

teardown() {
  teardown_temp_repo
}

# Helper: create a branch, add a commit, merge it into main, and switch back
create_and_merge_branch() {
  local branch_name="$1"
  # Use a simple filename without slashes
  local safe_name="${branch_name//\//-}"
  (
    cd "$TEST_REPO"
    git checkout -b "$branch_name"
    echo "change" > "${safe_name}-file.txt"
    git add "${safe_name}-file.txt"
    git commit -m "work on $branch_name" --no-gpg-sign
    git checkout main
    git merge "$branch_name" --no-edit --no-gpg-sign
  )
}

@test "DRY_RUN=true reports but does not delete" {
  create_and_merge_branch "feature/test-dry"

  export DRY_RUN=true
  run bash -c "cd '$TEST_REPO' && bash scripts/gc/clean-branches.sh"
  assert_success
  assert_output --partial "[dry-run]"

  # Branch should still exist
  run git -C "$TEST_REPO" branch --list "feature/test-dry"
  assert_output --partial "feature/test-dry"
}

@test "DRY_RUN=false deletes merged branches" {
  create_and_merge_branch "feature/test-delete"

  export DRY_RUN=false
  run bash -c "cd '$TEST_REPO' && bash scripts/gc/clean-branches.sh"
  assert_success

  # Branch should be gone
  run git -C "$TEST_REPO" branch --list "feature/test-delete"
  refute_output --partial "feature/test-delete"
}

@test "never deletes main" {
  create_and_merge_branch "feature/test-main-safe"

  export DRY_RUN=false
  run bash -c "cd '$TEST_REPO' && bash scripts/gc/clean-branches.sh"
  assert_success
  refute_output --partial "Would delete local branch: main"
  refute_output --partial "Deleting local branch: main"

  # Verify main still exists
  run git -C "$TEST_REPO" branch --list "main"
  assert_output --partial "main"
}
