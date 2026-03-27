#!/usr/bin/env bash
set -euo pipefail

# Render the WORKFLOW.md prompt template with issue data.
#
# Usage:
#   ./scripts/symphony/render-prompt.sh \
#     --number 42 \
#     --title "Fix login bug" \
#     --body "Users can't log in when..." \
#     --labels "bug,agent" \
#     --blocked-by '[{"identifier":"#10","state":"OPEN"}]' \
#     --attempt ""
#
# If Node.js is available, delegates to render-prompt.js for robust
# Liquid-like template rendering. Falls back to bash otherwise.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Prefer Node.js renderer (handles special chars, loops, filters) ─
if command -v node &>/dev/null; then
  exec node "$SCRIPT_DIR/render-prompt.js" "$@"
fi

# ── Bash fallback ─────────────────────────────────────
# Covers basic variable substitution and conditionals.
# Does NOT support {% for %} loops or filters.

ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/WORKFLOW.md"

# ── Parse arguments ──────────────────────────────────
ISSUE_NUMBER=""
ISSUE_TITLE=""
ISSUE_BODY=""
ISSUE_LABELS=""
BLOCKED_BY=""
ATTEMPT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --number)     ISSUE_NUMBER="$2"; shift 2 ;;
    --title)      ISSUE_TITLE="$2"; shift 2 ;;
    --body)       ISSUE_BODY="$2"; shift 2 ;;
    --labels)     ISSUE_LABELS="$2"; shift 2 ;;
    --blocked-by) BLOCKED_BY="$2"; shift 2 ;;
    --attempt)    ATTEMPT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# ── Extract prompt body (everything after second ---) ─
PROMPT_BODY=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$WORKFLOW_FILE")

if [ -z "$PROMPT_BODY" ]; then
  PROMPT_BODY="You are working on issue #${ISSUE_NUMBER}: ${ISSUE_TITLE}

${ISSUE_BODY}

Read AGENTS.md for project rules and conventions.
Run make check before committing."
fi

# ── Substitute template variables ────────────────────
PROMPT_BODY="${PROMPT_BODY//\{\{ issue.identifier \}\}/$ISSUE_NUMBER}"
PROMPT_BODY="${PROMPT_BODY//\{\{issue.identifier\}\}/$ISSUE_NUMBER}"
PROMPT_BODY="${PROMPT_BODY//\{\{ issue.title \}\}/$ISSUE_TITLE}"
PROMPT_BODY="${PROMPT_BODY//\{\{issue.title\}\}/$ISSUE_TITLE}"
PROMPT_BODY="${PROMPT_BODY//\{\{ issue.description \}\}/$ISSUE_BODY}"
PROMPT_BODY="${PROMPT_BODY//\{\{issue.description\}\}/$ISSUE_BODY}"

LABELS_JOINED=$(echo "$ISSUE_LABELS" | tr ',' ', ')
PROMPT_BODY="${PROMPT_BODY//\{\{ issue.labels | join: \", \" \}\}/$LABELS_JOINED}"
PROMPT_BODY="${PROMPT_BODY//\{\{issue.labels | join: \", \"\}\}/$LABELS_JOINED}"

# ── Handle conditional blocks ────────────────────────
strip_block() {
  local open_tag="$1" action="$2"
  # Determine the matching end tag
  local end_pat='{% endif %}'
  if echo "$open_tag" | grep -q 'for '; then
    end_pat='{% endfor %}'
  fi
  local tmp
  if [ "$action" = "remove" ]; then
    tmp=$(echo "$PROMPT_BODY" | awk -v pat="$open_tag" -v endpat="$end_pat" '
      $0 ~ pat {skip=1; next}
      skip && index($0, endpat) {skip=0; next}
      !skip {print}
    ')
  else
    tmp=$(echo "$PROMPT_BODY" | awk -v pat="$open_tag" -v endpat="$end_pat" '
      $0 ~ pat {found=1; next}
      found && index($0, endpat) {found=0; next}
      {print}
    ')
  fi
  PROMPT_BODY="$tmp"
}

# Blockers — check if we have any
HAS_BLOCKERS=false
if [ -n "$BLOCKED_BY" ] && [ "$BLOCKED_BY" != "[]" ]; then
  HAS_BLOCKERS=true
fi

if [ "$HAS_BLOCKERS" = true ]; then
  strip_block "{% if issue.blocked_by.size > 0 %}" keep
  # Remove the for loop tags but leave a flat list (bash can't iterate JSON)
  PROMPT_BODY=$(echo "$PROMPT_BODY" | sed '/{% for /d; /{% endfor %}/d')
  PROMPT_BODY=$(echo "$PROMPT_BODY" | sed 's/{{ blocker\.identifier }}/[see issue links]/g; s/{{ blocker\.state }}//g')
else
  strip_block "{% if issue.blocked_by.size > 0 %}" remove
fi

# Attempt
if [ -n "$ATTEMPT" ]; then
  PROMPT_BODY="${PROMPT_BODY//\{\{ attempt \}\}/$ATTEMPT}"
  PROMPT_BODY="${PROMPT_BODY//\{\{attempt\}\}/$ATTEMPT}"
  strip_block "{% if attempt %}" keep
else
  strip_block "{% if attempt %}" remove
fi

# Labels
if [ -n "$ISSUE_LABELS" ]; then
  strip_block "{% if issue.labels.size > 0 %}" keep
else
  strip_block "{% if issue.labels.size > 0 %}" remove
fi

# Clean up remaining Liquid tags
PROMPT_BODY=$(echo "$PROMPT_BODY" | sed '/^{% /d')

echo "$PROMPT_BODY"
