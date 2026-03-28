#!/usr/bin/env bash
set -euo pipefail

# Parse WORKFLOW.md front matter into shell-sourceable variables.
#
# Usage:
#   eval "$(./scripts/symphony/parse-config.sh)"
#   echo "$SYMPHONY_AGENT"
#
# This extracts YAML front matter values using simple line parsing
# (no YAML library required). Complex nested values are flattened.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="${1:-$ROOT_DIR/WORKFLOW.md}"

if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "echo 'ERROR: [symphony] WORKFLOW.md not found at $WORKFLOW_FILE'" >&2
  exit 1
fi

# ── Extract front matter lines between --- markers ───
IN_FRONT_MATTER=false
FRONT_MATTER=""
LINE_NUM=0
FRONT_MATTER_END=0

while IFS= read -r line; do
  LINE_NUM=$((LINE_NUM + 1))
  if [ "$line" = "---" ]; then
    if [ "$IN_FRONT_MATTER" = true ]; then
      FRONT_MATTER_END=$LINE_NUM
      break
    else
      IN_FRONT_MATTER=true
      continue
    fi
  fi
  if [ "$IN_FRONT_MATTER" = true ]; then
    FRONT_MATTER+="$line"$'\n'
  fi
done < "$WORKFLOW_FILE"

# ── Parse key-value pairs from YAML (flat extraction) ─
# Handles: top.sub: value and top.sub entries with $VAR expansion
parse_yaml_value() {
  local key="$1" default="$2"
  local value
  # Try exact key match (handles both "key: value" and "  key: value")
  value=$(echo "$FRONT_MATTER" | grep -E "^\s*${key}:" | head -1 | sed "s/^[[:space:]]*${key}:[[:space:]]*//" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/" | xargs)
  # Resolve $VAR references
  if [[ "$value" == \$* ]]; then
    local var_name="${value#\$}"
    value="${!var_name:-}"
  fi
  echo "${value:-$default}"
}

# ── Extract config values ────────────────────────────

# Tracker
echo "SYMPHONY_TRACKER_KIND=$(parse_yaml_value 'kind' 'github')"
echo "SYMPHONY_REPO=$(parse_yaml_value 'repo' "${GITHUB_REPOSITORY:-}")"
echo "SYMPHONY_PROJECT_NUMBER=$(parse_yaml_value 'project_number' "${PROJECT_NUMBER:-}")"

# States (extract list items under a key)
extract_list() {
  local key="$1"
  echo "$FRONT_MATTER" | awk -v k="$key:" '
    $0 ~ k {found=1; next}
    found && /^[[:space:]]*-/ {gsub(/^[[:space:]]*-[[:space:]]*/, ""); vals = vals sep $0; sep = ","; next}
    found {exit}
    END {print vals}
  '
}
ACTIVE_STATES=$(extract_list 'active_states')
TERMINAL_STATES=$(extract_list 'terminal_states')
echo "SYMPHONY_ACTIVE_STATES=${ACTIVE_STATES:-ready,in-progress}"
echo "SYMPHONY_TERMINAL_STATES=${TERMINAL_STATES:-done,closed,cancelled}"

# Polling
echo "SYMPHONY_POLL_INTERVAL_MS=$(parse_yaml_value 'interval_ms' '900000')"

# Workspace
echo "SYMPHONY_WORKSPACE_ROOT=$(parse_yaml_value 'root' '.worktrees')"

# Hooks
extract_hook() {
  local hook_name="$1"
  echo "$FRONT_MATTER" | awk -v hook="$hook_name:" '
    $0 ~ hook {found=1; next}
    found && /^    / {sub(/^    /, ""); lines = lines $0 "\n"; next}
    found {exit}
    END {printf "%s", lines}
  '
}
# Export hooks as base64 to preserve newlines
echo "SYMPHONY_HOOK_AFTER_CREATE=$(extract_hook 'after_create' | base64 | tr -d '\n')"
echo "SYMPHONY_HOOK_BEFORE_RUN=$(extract_hook 'before_run' | base64 | tr -d '\n')"
echo "SYMPHONY_HOOK_AFTER_RUN=$(extract_hook 'after_run' | base64 | tr -d '\n')"

# Agent
echo "SYMPHONY_MAX_CONCURRENT=$(parse_yaml_value 'max_concurrent_agents' '5')"
echo "SYMPHONY_MAX_RETRY_BACKOFF_MS=$(parse_yaml_value 'max_retry_backoff_ms' '300000')"
echo "SYMPHONY_AGENT=$(parse_yaml_value 'name' 'claude')"
echo "SYMPHONY_AGENT_MODEL=$(parse_yaml_value 'model' '')"
echo "SYMPHONY_AGENT_MAX_TURNS=$(parse_yaml_value 'max_turns' '50')"
echo "SYMPHONY_AGENT_MAX_BUDGET=$(parse_yaml_value 'max_budget_usd' '10')"
echo "SYMPHONY_AGENT_TIMEOUT_MS=$(parse_yaml_value 'turn_timeout_ms' '3600000')"

# Prompt template line offset (for extracting the body)
echo "SYMPHONY_PROMPT_OFFSET=$FRONT_MATTER_END"
