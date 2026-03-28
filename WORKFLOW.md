---
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Symphony workflow contract
# https://github.com/openai/symphony/blob/main/SPEC.md
#
# This file is the single source of truth for the Symphony
# orchestration cycle. The GitHub Actions workflow reads all
# config from this front matter at runtime.
#
# Two sections:
#   1. YAML front matter — runtime configuration
#   2. Markdown body — prompt template rendered per issue
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── Tracker ────────────────────────────────────────────
# Uses GitHub Issues + Projects. Issues need [ready] + [agent]
# labels to be picked up by the orchestrator.
tracker:
  kind: github
  repo: $GITHUB_REPO
  project_number: $PROJECT_NUMBER
  active_states:
    - ready
    - in-progress
  terminal_states:
    - done
    - closed
    - cancelled

# ── Polling ────────────────────────────────────────────
# How often the orchestrator checks for new work.
# Maps to the cron schedule in symphony.yml.
polling:
  interval_ms: 900000

# ── Workspace ──────────────────────────────────────────
# Each issue gets an isolated branch (CI) or worktree (local).
workspace:
  root: .worktrees

# ── Hooks ──────────────────────────────────────────────
# Shell scripts run at workspace lifecycle events.
hooks:
  after_create: |
    git checkout -b "issue/${ISSUE_NUMBER}" 2>/dev/null || git checkout "issue/${ISSUE_NUMBER}"
    make setup 2>/dev/null || true
  before_run: |
    git pull --rebase origin main 2>/dev/null || true
  after_run: |
    make check 2>/dev/null || true

# ── Agent ──────────────────────────────────────────────
# Which coding agent to dispatch and concurrency limits.
agent:
  # claude | codex
  name: claude
  model: sonnet
  max_turns: 50
  max_budget_usd: 10
  max_concurrent_agents: 5
  max_retry_backoff_ms: 300000
  turn_timeout_ms: 3600000
  stall_timeout_ms: 300000
---

You are working on issue **#{{ issue.identifier }}**: *{{ issue.title }}*

## Context

Read these before starting:
1. `AGENTS.md` — project rules and knowledge map
2. `docs/DESIGN.md` — system design and domain boundaries
3. `docs/architecture/layers.md` — dependency layering rule

## Issue

{{ issue.description }}

{% if issue.labels.size > 0 %}
**Labels:** {{ issue.labels | join: ", " }}
{% endif %}

{% if issue.blocked_by.size > 0 %}
**Blocked by:**
{% for blocker in issue.blocked_by %}
- {{ blocker.identifier }} ({{ blocker.state }})
{% endfor %}
Do not proceed until blockers are resolved.
{% endif %}

{% if attempt %}
**This is retry attempt {{ attempt }}.** The previous run failed.
Review the error output and try a different approach.
Do not repeat the same steps that failed.
{% endif %}

## Code quality rules

- **Dependency layering**: `Types → Config → Core → Services → Runtime → UI`. No upward imports.
- **One concern per file**, under 300 lines.
- **Shared utilities over hand-rolled helpers** — check `core/utils/` before writing new ones.
- **Parse at the boundary** — validate data shapes at entry points, not inline.
- **Grep-friendly errors**: `ERROR: [module] description` on single lines.
- **Structured logging** — JSON or key=value, never bare strings. Prefer file-based logging.
- **No secrets in code** — use `.env` or environment variables.
- **Solve the stated problem, nothing more** — no config options, abstractions, or extension points the issue doesn't ask for. Three similar lines beat a premature abstraction.
- **Prefer the obvious path** — pick the approach that's easier to read and delete. Avoid clever indirection when a flat implementation works.

See `docs/design-docs/golden-principles.md` for the full rationale behind each rule.

## Your task

1. Implement the changes described in the issue above.
2. Follow the code quality rules above.
3. Write or update tests. Match existing test patterns.
4. Update docs if your changes affect behavior, commands, or configuration. Docs are first-class — README.md, docs/, CLAUDE.md, and AGENTS.md must stay accurate.
5. Run `make check` and fix any failures.
6. Commit with message: `#{{ issue.identifier }}: <what changed and why>`
7. If acceptance criteria are listed in the issue, verify each one.
