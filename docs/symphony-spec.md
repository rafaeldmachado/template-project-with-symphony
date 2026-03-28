# Symphony Spec — Implementation Parallel

How our GitHub Actions implementation maps to the
[Symphony Service Specification](https://github.com/openai/symphony/blob/main/SPEC.md).

Symphony was designed as a long-running daemon with Linear as the tracker and Codex as the agent.
We adapt it to run on **GitHub Actions** (scheduler), **GitHub Issues + Projects** (tracker),
and **Claude Code or Codex CLI** (agent). This document maps each spec section to our
concrete implementation, noting what we implement, what we adapt, and what we intentionally skip.

---

## 3. System Overview — Component Mapping

The spec defines 8 components. Here is how each maps to our implementation:

| # | Spec Component | Our Implementation | Where |
|---|---|---|---|
| 1 | **Workflow Loader** | `parse-config.sh` parses YAML front matter; `render-prompt.sh` extracts the prompt body | `scripts/symphony/parse-config.sh`, `render-prompt.sh` |
| 2 | **Config Layer** | Shell variables exported by `parse-config.sh` (`SYMPHONY_*`), consumed by the workflow as job outputs | `scripts/symphony/parse-config.sh` |
| 3 | **Issue Tracker Client** | `gh issue list` / `gh issue view` via GitHub CLI. Filters by labels (`ready` + `agent`) instead of Linear project+states | `symphony.yml` → discover job |
| 4 | **Orchestrator** | GitHub Actions scheduler: cron poll, `workflow_dispatch`, `issues.labeled` event. Concurrency via `strategy.max-parallel`. State via issue labels | `symphony.yml` → triggers + concurrency group |
| 5 | **Workspace Manager** | `actions/checkout` + `git checkout -b issue/<N>`. In local mode: `make worktree ISSUE=N` creates git worktrees | `symphony.yml` → workspace steps; `scripts/worktree/` |
| 6 | **Agent Runner** | Conditional step: installs and runs either `claude` CLI or `codex` CLI based on `agent.name` from WORKFLOW.md | `symphony.yml` → Execute steps |
| 7 | **Status Surface** | GitHub Actions UI (run logs, matrix job names like `#42 — Fix bug`). Issue comments on reconcile serve as status updates | `symphony.yml` → reconcile steps |
| 8 | **Logging** | GitHub Actions step logs (structured by step name). No separate log sink | Native to GitHub Actions |

### Abstraction Layers Parallel

| Spec Layer | Our Layer |
|---|---|
| Policy (repo-defined) | `WORKFLOW.md` prompt body, `AGENTS.md`, `CLAUDE.md` |
| Configuration (typed getters) | `parse-config.sh` → `SYMPHONY_*` variables → job outputs |
| Coordination (orchestrator) | GitHub Actions: cron schedule, concurrency group, matrix strategy, label state machine |
| Execution (workspace + agent) | checkout + branch creation + CLI agent invocation |
| Integration (tracker adapter) | `gh` CLI talking to GitHub Issues API (replaces Linear GraphQL) |
| Observability (logs + status) | Actions logs + issue comments + PR body metadata |

---

## 4. Core Domain Model — Entity Mapping

### Issue

| Spec Field | Our Equivalent | Source |
|---|---|---|
| `id` | Issue number (int) | `gh issue view --json number` |
| `identifier` | `#<number>` | Same as `id` for GitHub |
| `title` | Issue title | `--json title` |
| `description` | Issue body (markdown) | `--json body` |
| `priority` | Derived from labels: `p0`=0, `p1`=1, `p2`=2 | Discover step sorts by priority label (lower = higher priority) |
| `state` | Derived from labels: `ready`, `in-progress`, `human-review` | `--json labels` |
| `branch_name` | `issue/<number>` | Convention, not tracker metadata |
| `url` | Issue URL | Available via `gh` but not used in prompt |
| `labels` | Label names array | `--json labels --jq '[.labels[].name]'` |
| `blocked_by` | `blockedBy` GraphQL field | Fetched via `gh api graphql` per issue. Rendered in prompt template |
| `created_at` | Used as tiebreaker in sorting | Issues sorted by priority then number |

### Workflow Definition

Identical structure: YAML front matter = config, markdown body = prompt template.
Parsed by `parse-config.sh` (config) and `render-prompt.sh` (prompt).

### Workspace

| Spec Field | Our Equivalent |
|---|---|
| `path` | CI: `$GITHUB_WORKSPACE` (checkout root). Local: `.worktrees/<number>/` |
| `workspace_key` | Issue number (already safe for filenames) |
| `created_now` | Always true in CI (fresh checkout per run) |

### Run Attempt

| Spec Field | Our Equivalent |
|---|---|
| `issue_id` | `matrix.number` |
| `attempt` | Passed to `render-prompt.sh --attempt`. Currently always empty (first run). Retries happen on next poll, not within the same run |
| `workspace_path` | `$GITHUB_WORKSPACE` |
| `started_at` | GitHub Actions job start time |
| `status` | Derived from step outcomes |

### Live Session / Retry Entry / Orchestrator State

These are daemon-specific concepts (in-memory maps, timer handles, token counters).
**Not applicable** — GitHub Actions is stateless between runs. Equivalent behavior:

| Spec Concept | Our Adaptation |
|---|---|
| `running` map | Jobs currently executing in the matrix |
| `claimed` set | Issues with `in-progress` label |
| `retry_attempts` | Issues returned to `ready` label; re-discovered on next poll |
| Token accounting | Captured from agent JSON output (`--output-format json` for Claude). Input/output tokens and cost are logged and included in PR body and issue comments |

---

## 5. Workflow Specification — Repository Contract

### File Discovery

| Spec Rule | Our Implementation |
|---|---|
| Default path: `WORKFLOW.md` in cwd | Same. `parse-config.sh` defaults to `$ROOT_DIR/WORKFLOW.md` |
| Missing file → `missing_workflow_file` error | `parse-config.sh` exits with error and message to stderr |

### File Format

Fully implemented. Front matter between `---` markers parsed as YAML. Remainder is prompt template.
`parse-config.sh` extracts the front matter line by line (no YAML library needed).
`render-prompt.sh` extracts the body via `awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}'`.

### Front Matter Schema

| Spec Key | Our Key | Notes |
|---|---|---|
| `tracker.kind` | `tracker.kind` | `github` instead of `linear` |
| `tracker.endpoint` | N/A | GitHub API is implicit via `gh` CLI |
| `tracker.api_key` | N/A | Auth via `GITHUB_TOKEN` (automatic in Actions) |
| `tracker.project_slug` | `tracker.project_number` | GitHub Projects use numeric IDs |
| `tracker.active_states` | `tracker.active_states` | Labels: `ready`, `in-progress` |
| `tracker.terminal_states` | `tracker.terminal_states` | Labels: `done`, `closed`, `cancelled` |
| `polling.interval_ms` | `polling.interval_ms` | Informational — actual interval is the cron schedule in `symphony.yml` |
| `workspace.root` | `workspace.root` | Used by `make worktree`. CI uses checkout |
| `hooks.after_create` | `hooks.after_create` | Runs in both CI (decoded from base64, executed as bash) and local (`make worktree`) |
| `hooks.before_run` | `hooks.before_run` | Runs in both CI and local |
| `hooks.after_run` | `hooks.after_run` | Runs in both CI and local. CI also has a separate validate step |
| `agent.max_concurrent_agents` | `agent.max_concurrent_agents` | Maps to `strategy.max-parallel` |
| `agent.max_retry_backoff_ms` | `agent.max_retry_backoff_ms` | Informational — retry is label-driven, not timer-driven |
| `codex.command` | N/A | We use CLI directly, not app-server protocol |
| `codex.approval_policy` | N/A | Claude: not applicable. Codex: `--full-auto` mode |
| `codex.turn_timeout_ms` | `agent.turn_timeout_ms` | Maps to `timeout-minutes` on the job |
| `codex.stall_timeout_ms` | `agent.stall_timeout_ms` | Informational — GitHub Actions has no stall detection. The job timeout is the backstop |

**Added fields** (not in spec):

| Field | Purpose |
|---|---|
| `agent.name` | `claude` or `codex` — selects which CLI to run |
| `agent.model` | Model override passed to the agent CLI |
| `agent.max_turns` | `--max-turns` for Claude Code |
| `agent.max_budget_usd` | `--max-budget-usd` for Claude Code |

### Prompt Template

Liquid-compatible rendering via `render-prompt.js` (Node.js) with bash fallback:

| Spec Requirement | Status |
|---|---|
| `{{ issue.identifier }}` | Implemented |
| `{{ issue.title }}` | Implemented |
| `{{ issue.description }}` | Implemented |
| `{{ issue.labels \| join: ", " }}` | Implemented (join filter) |
| `{{ attempt }}` | Implemented |
| `{% if issue.blocked_by.size > 0 %}` | Implemented — blockers fetched via GitHub GraphQL `blockedBy` field |
| `{% for blocker in issue.blocked_by %}` | Implemented in Node.js renderer |
| `{% if attempt %}` | Implemented |
| Strict unknown variable checking | Not enforced — unknown tags are cleaned up |
| Fallback prompt if body empty | Implemented — minimal default in both renderers |

---

## 6. Configuration — Resolution and Reload

### Source Precedence

| Spec Level | Our Implementation |
|---|---|
| 1. Runtime setting | `workflow_dispatch.inputs.issue_number` can override auto-discovery |
| 2. YAML front matter | `parse-config.sh` reads all config from WORKFLOW.md |
| 3. `$VAR` environment indirection | `parse-config.sh` resolves `$VAR` references (e.g., `repo: $GITHUB_REPO`) |
| 4. Built-in defaults | Hardcoded in `parse-config.sh` (`parse_yaml_value 'key' 'default'`) |

### Dynamic Reload

**Not applicable in CI** — each workflow run reads WORKFLOW.md fresh from the repo. Changes to
WORKFLOW.md take effect on the next commit + next poll/trigger. This is simpler than the daemon
model but achieves the same "config changes apply without restart" goal since there is no persistent
process to restart.

### Dispatch Preflight Validation

| Spec Check | Our Check |
|---|---|
| Workflow file loadable | `parse-config.sh` exits 1 if WORKFLOW.md missing |
| `tracker.kind` present | Defaults to `github` |
| `tracker.api_key` present | `GITHUB_TOKEN` is automatic in Actions |
| Agent command present | Agent CLI is installed inline; failure = step failure |

---

## 7. Orchestration State Machine

### Issue States — Label-Based Equivalent

The spec uses an in-memory claim model. We use **GitHub labels as persisted state**:

| Spec State | Our Label(s) | Transition |
|---|---|---|
| `Unclaimed` | `ready` + `agent` | Issue has both labels, waiting for next poll |
| `Claimed` | `in-progress` | Discover job found it; execute job swaps `ready` → `in-progress` |
| `Running` | `in-progress` | Agent is executing (job in progress) |
| `RetryQueued` | `ready` (returned) | On failure/no-changes, `in-progress` → `ready`. Next poll re-discovers |
| `Released` / terminal | `human-review` or issue closed | PR created → `human-review`. Human merges and closes issue |

### State Machine Diagram

```
                  [ready] + [agent]
                         │
            ┌────────────▼────────────┐
            │   DISCOVER (poll/event)  │
            └────────────┬────────────┘
                         │
            ┌────────────▼────────────┐
            │   CLAIM                  │
            │   ready → in-progress    │
            └────────────┬────────────┘
                         │
            ┌────────────▼────────────┐
            │   EXECUTE agent          │
            └────────┬───────┬────────┘
                     │       │
              success│       │failure / no changes
                     │       │
        ┌────────────▼──┐ ┌──▼────────────┐
        │ DELIVER PR    │ │ RECONCILE     │
        │ human-review  │ │ → ready       │
        └───────────────┘ │ (retry next   │
                          │  poll cycle)  │
                          └───────────────┘
```

### Run Attempt Lifecycle

| Spec Phase | Our Equivalent | Step |
|---|---|---|
| `PreparingWorkspace` | Checkout + branch creation | "Workspace: create branch" |
| `BuildingPrompt` | Render WORKFLOW.md template | "Prompt: render WORKFLOW.md template" |
| `LaunchingAgentProcess` | Install + invoke CLI | "Execute: Claude Code" / "Execute: Codex" |
| `StreamingTurn` | Agent running (opaque to us) | Same step, agent streams internally |
| `Finishing` | Agent exits | Step completes |
| `Succeeded` | Step exit 0 + changes produced | "Deliver: push and open PR" |
| `Failed` | Step exit non-zero | `if: failure()` → reconcile |
| `TimedOut` | `timeout-minutes` exceeded | GitHub Actions cancels the job |
| `Stalled` | No equivalent | Covered by `timeout-minutes` as backstop |
| `CanceledByReconciliation` | No equivalent | Would require issue state polling mid-run |

### Retry Semantics

| Spec Behavior | Our Behavior |
|---|---|
| Exponential backoff timers | Not applicable — no persistent process. Retry = return to `ready` label and wait for next cron poll (15 min default) |
| Continuation retry (1s) | Not applicable — each run is independent. Issue stays `ready` + `agent` so next poll picks it up |
| `attempt` counter | Currently always null (first attempt). Could be tracked via issue metadata or label suffixes in a future iteration |
| Max retry cap | Implicit — human notices repeated failures in issue comments and intervenes |

---

## 8. Polling, Scheduling, and Reconciliation

### Poll Loop

| Spec Step | Our Implementation |
|---|---|
| Schedule tick | Cron `*/15 * * * *` (every 15 min). Also triggers on `workflow_dispatch` and `issues.labeled` events |
| Reconcile running | Not applicable mid-tick — each run is atomic. But reconcile steps at the end of each job do label cleanup |
| Validate config | `parse-config.sh` runs at start of discover job |
| Fetch candidates | `gh issue list --label ready --label agent --state open --limit $MAX` |
| Sort by priority | Implemented — issues sorted by priority labels (`p0` > `p1` > `p2`) then by issue number |
| Dispatch eligible | Matrix strategy: each discovered issue becomes a parallel job |

### Candidate Selection

| Spec Rule | Our Rule |
|---|---|
| Has `id`, `identifier`, `title`, `state` | `gh issue list --json number,title,body,labels` ensures these fields exist |
| State in `active_states` | Filtered by `--label "ready"` + `--label "agent"` |
| Not in `running` | The `in-progress` label excludes it from the `ready` query. Concurrency group `symphony-dispatch` prevents overlapping discover jobs |
| Global concurrency slots | `strategy.max-parallel: ${{ max_concurrent }}` limits parallel matrix jobs |
| Per-state concurrency | Not implemented — all issues share the global pool |
| Blocker rule | Blockers fetched via GraphQL `blockedBy` field and included in prompt. No dispatch-time blocking — agent sees blockers in context but is not prevented from running |

### Concurrency Control

```yaml
concurrency:
  group: symphony-dispatch       # prevents overlapping poll cycles
  cancel-in-progress: false      # don't cancel running work

strategy:
  max-parallel: ${{ max_concurrent }}   # from WORKFLOW.md agent.max_concurrent_agents
  fail-fast: false                       # one failure doesn't cancel siblings
```

This maps to the spec's `available_slots = max(max_concurrent_agents - running_count, 0)`:
GitHub Actions enforces the slot limit natively via `max-parallel`.

### Reconciliation

The spec's active-run reconciliation (stall detection + tracker state refresh) is replaced by
**end-of-job reconcile steps**:

| Scenario | Reconcile Action |
|---|---|
| PR created successfully | `in-progress` → `human-review` + issue comment with PR link |
| Agent ran but no changes | `in-progress` → `ready` + issue comment (eligible for retry) |
| Job failed (any step) | `in-progress` → `ready` + issue comment with failure logs link |

There is no mid-run reconciliation (checking if a human closed the issue while the agent runs).
The job timeout (`timeout-minutes` from `agent.turn_timeout_ms`) is the only mid-run safety net.

---

## 10. Agent Runner Protocol

The spec defines a JSON-RPC app-server protocol (Codex-specific). We take a **CLI-first approach**
that works with any agent that accepts a prompt on the command line.

### Launch Contract

| Spec | Claude Code | Codex CLI |
|---|---|---|
| Command | `claude` | `codex` |
| Invocation | Direct CLI, not `bash -lc` | Direct CLI, not `bash -lc` |
| Working dir | `$GITHUB_WORKSPACE` | `$GITHUB_WORKSPACE` |
| Protocol | None — fire-and-forget CLI | None — fire-and-forget CLI |
| Auth | `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` env var | `OPENAI_API_KEY` env var |

### Session Startup

No handshake. Each agent is invoked as a one-shot CLI command with full permission bypass:

**Claude Code:**
```bash
claude -p "$(cat /tmp/symphony-prompt.md)" \
  --dangerously-skip-permissions \
  --allowedTools "Bash,Read,Edit,Write,Glob,Grep" \
  --output-format json \
  --model "$MODEL" \
  --max-turns "$MAX_TURNS" \
  --max-budget-usd "$MAX_BUDGET"
```

- `--dangerously-skip-permissions` — bypasses all permission prompts (required for CI)
- `--allowedTools` — restricts which tools the agent can use
- `--output-format json` — structured output with token usage and cost metrics

**Codex:**
```bash
codex --full-auto --quiet \
  --model "$MODEL" \
  "$(cat /tmp/symphony-prompt.md)"
```

- `--full-auto` — auto-approves all actions (equivalent to "yolo mode")

### Metrics Capture

Agent output is captured to `/tmp/agent-output.json` via `tee`. A metrics step parses:
- `input_tokens` / `output_tokens` — token consumption
- `cost_usd` — dollar cost of the run

These are included in the PR body and the issue reconciliation comment, providing
per-issue cost visibility.

### Spec Concepts Not Applicable to CLI Mode

| Spec Concept | Why N/A |
|---|---|
| `thread/start`, `turn/start` handshake | App-server protocol; we use CLI mode |
| Continuation turns on same `threadId` | Each run is a single CLI invocation. The agent manages its own turns internally |
| `turn_completed` / `turn_failed` events | Exit code is our only signal (0 = success, non-zero = failure) |
| Stall detection via `last_codex_timestamp` | No event stream. `timeout-minutes` is the backstop |
| `approval_policy` / `sandbox` | Claude: `--dangerously-skip-permissions` + `--allowedTools`. Codex: `--full-auto` |
| `linear_graphql` tool extension | Not applicable — we use GitHub, not Linear |
| User input required → hard fail | CLI mode: agents don't request user input. If they hang, `timeout-minutes` kills the job |

---

## 11. Issue Tracker Integration — GitHub Adapter

The spec defines a Linear GraphQL adapter. We replace it with **GitHub CLI** (`gh`).

### Required Operations

| Spec Operation | Our Implementation |
|---|---|
| `fetch_candidate_issues()` | `gh issue list --label ready --label agent --state open --limit $MAX --json number,title,body,labels` |
| `fetch_issues_by_states(terminal)` | Not needed — terminal cleanup is handled by the GC workflow (`garbage-collector.yml`) |
| `fetch_issue_states_by_ids(ids)` | Not needed — no mid-run reconciliation. Each job reconciles its own issue at completion |

### Query Semantics

| Spec (Linear) | Our Equivalent (GitHub) |
|---|---|
| `project.slugId` filter | Label filter: `--label ready --label agent` |
| `active_states` filter | `--state open` + label presence |
| Pagination (cursor, pageSize 50) | `--limit $MAX` (single page, bounded by `max_concurrent_agents`) |
| Auth: `Authorization` header | `GITHUB_TOKEN` env var (automatic in Actions) |
| GraphQL → normalized issue | JSON output via `--json` + `--jq` for field selection |

### Normalization

| Spec Field | GitHub Source |
|---|---|
| `labels` → lowercase | GitHub labels are case-sensitive but we control them (all lowercase by convention) |
| `blocked_by` → inverse relations | `blockedBy` GraphQL field, fetched via `gh api graphql` per issue in the prompt step |
| `priority` → integer | Derived from labels: `p0`=0, `p1`=1, `p2`=2. Discover step sorts by priority then issue number |
| `created_at` → ISO-8601 | Available via `--json createdAt` |

### Tracker Writes (Important Boundary)

The spec says Symphony is a **reader** — ticket writes are done by the agent. Our implementation
is slightly different:

| Write Operation | Who Does It |
|---|---|
| Label transitions (`ready` ↔ `in-progress` ↔ `human-review`) | **Workflow** (symphony.yml steps), not the agent |
| Issue comments (status updates) | **Workflow** (reconcile steps) |
| PR creation | **Workflow** (deliver step) |
| Code changes + commits | **Agent** (during execute step) |
| Issue close | **Human** (on PR merge, via `Resolves #N`) |

This is a pragmatic choice: the workflow has `GITHUB_TOKEN` with write permissions, while the
agent is sandboxed to code-related tools (`Bash,Read,Edit,Write,Glob,Grep`).

---

## 12. Prompt Construction and Context Assembly

### Inputs

| Spec Input | Our Source |
|---|---|
| `workflow.prompt_template` | Markdown body of `WORKFLOW.md` (after front matter) |
| `issue` object | `matrix.number`, `matrix.title`, `matrix.body`, `matrix.labels` from discover job |
| `attempt` | `--attempt` flag to `render-prompt.sh`. Currently empty (first run) |

### Rendering

`render-prompt.js` (Node.js, with bash fallback in `render-prompt.sh`) implements:

- Variable substitution: `{{ issue.identifier }}`, `{{ issue.title }}`, `{{ issue.description }}`
- Filter: `{{ issue.labels | join: ", " }}`
- Conditionals: `{% if issue.labels.size > 0 %}`, `{% if attempt %}`, `{% if issue.blocked_by.size > 0 %}`
- Loops: `{% for blocker in issue.blocked_by %}...{% endfor %}`
- Cleanup of remaining Liquid tags

### Spec Compliance

| Spec Rule | Status |
|---|---|
| Strict template engine | Partial — unknown variables are silently cleaned, not rejected |
| Unknown variables fail rendering | Not enforced |
| Unknown filters fail rendering | Not enforced (unknown filters are left as-is then cleaned) |
| `attempt` null on first run | Implemented — passed as empty string |
| Fallback prompt if body empty | Implemented — minimal default generated |
| Template errors fail the run | YAML parse errors exit 1. Template errors are mostly silent |

---

## 13. Logging, Status, and Observability

### Logging

| Spec Requirement | Our Implementation |
|---|---|
| Structured logs with `issue_id` + `issue_identifier` | Step names include issue number: `"#42 — Fix login bug"` |
| `session_id` context | Not applicable — CLI mode has no session ID |
| `key=value` phrasing | Config step prints `agent=claude model=sonnet max_concurrent=5 timeout=60m` |
| Operator visibility | GitHub Actions UI: step logs, job status, matrix view |

### Status Surface

| Spec Surface | Our Equivalent |
|---|---|
| Terminal dashboard | GitHub Actions UI — matrix jobs show per-issue status |
| `/api/v1/state` JSON endpoint | Not applicable — no HTTP server. Equivalent: `gh run list --workflow=symphony.yml` |
| `/api/v1/<issue>` endpoint | `gh run view <run-id>` shows per-issue job details |
| `/api/v1/refresh` trigger | `gh workflow run symphony.yml` or `workflow_dispatch` with `issue_number` input |

### Issue Comments as Status

Each reconcile step posts a structured comment to the issue:

```markdown
**Symphony** created a PR: https://github.com/acme/app/pull/43

| | |
|---|---|
| Agent | `claude` |
| Checks | `true` |
| Run | [logs](https://github.com/acme/app/actions/runs/123456) |

Moving to **human-review**.
```

This serves as both a status update and an audit trail — visible in the issue timeline, filterable
via GitHub search.

### Token Accounting

Tracked per run via agent JSON output:

- Claude Code: `--output-format json` captures input/output tokens and cost
- Codex: output captured to file for parsing
- A metrics step parses the JSON and exposes `input_tokens`, `output_tokens`, `total_cost`
- These appear in the PR body and the issue reconciliation comment
- Budget enforcement: Claude Code `--max-budget-usd` flag; Codex via provider billing limits

---

## 14. Failure Model and Recovery

### Failure Classes

| Spec Class | Our Equivalent | Behavior |
|---|---|---|
| **Workflow/Config** | `parse-config.sh` fails, WORKFLOW.md missing | Discover job fails → no matrix dispatched → no work done. Visible in Actions UI |
| **Workspace** | Checkout fails, branch creation fails | Execute job fails → reconcile returns issue to `ready` |
| **Agent Session** | CLI exits non-zero, timeout, OOM | Execute step fails → reconcile returns issue to `ready` |
| **Tracker** | `gh` CLI fails (API error, auth issue) | Discover or reconcile step fails → visible in Actions logs |
| **Observability** | Issue comment fails to post | Non-fatal — comment posting is guarded. Label transitions and PR creation are the critical path and fail hard |

### Recovery Behavior

| Spec Recovery | Our Recovery |
|---|---|
| Dispatch validation failure → skip dispatch | Discover job fails → `has_work=false` → execute job skipped |
| Worker failure → exponential backoff retry | Job failure → `in-progress` → `ready` → re-discovered on next 15-min poll |
| Tracker fetch failure → skip this tick | `gh issue list` failure → discover job fails → retried on next cron |
| Dashboard failure → don't crash | Not applicable — Actions UI is external |

### Restart Recovery

The spec's daemon requires tracker-driven restart recovery because in-memory state is lost.
**We have no restart problem** — GitHub Actions is inherently stateless. Each run:

1. Reads WORKFLOW.md fresh
2. Queries current issue state via labels
3. Dispatches only for issues labeled `ready` + `agent`
4. Reconciles labels at job completion

Stale `in-progress` labels (from killed/timed-out runs) are the one risk. Mitigation options:
- The GC workflow (`garbage-collector.yml`) could scan for `in-progress` issues with no active
  workflow run and return them to `ready`
- `workflow_dispatch` with a specific `issue_number` can manually re-trigger

### Operator Intervention

| Spec Method | Our Method |
|---|---|
| Edit `WORKFLOW.md` | Same — commit changes, they take effect on next poll |
| Change issue state in tracker | Change labels: remove `agent` to stop Symphony from picking it up; add `ready` to re-enable |
| Restart service | Not needed. Trigger manually: `gh workflow run symphony.yml` |
| Force re-dispatch | `workflow_dispatch` with `issue_number` input |

---

## Summary: What We Implement vs. Adapt vs. Skip

### Fully Implemented

- WORKFLOW.md as single source of truth (front matter + prompt template)
- Config parsing with `$VAR` expansion and defaults
- Issue discovery with label-based filtering
- Priority dispatch via `p0`/`p1`/`p2` labels
- Blocker detection via GitHub GraphQL `blockedBy` field
- Concurrency limits via matrix strategy
- Workspace isolation (branch per issue)
- Prompt rendering with Node.js Liquid-like engine (bash fallback)
- Hooks (`after_create`, `before_run`, `after_run`) in both CI and local
- Multi-agent support (Claude Code + Codex) with permission bypass
- Token/cost metrics captured from agent JSON output
- Reconciliation with label state transitions
- Observability via issue comments (with metrics) and Actions logs

### Adapted (Different Mechanism, Same Intent)

- **Scheduler**: Cron + event triggers instead of daemon poll loop
- **State machine**: GitHub labels instead of in-memory maps
- **Retry**: Return to `ready` + next poll instead of exponential backoff timers
- **Concurrency**: `strategy.max-parallel` instead of slot counting
- **Agent protocol**: CLI invocation instead of JSON-RPC app-server
- **Tracker**: `gh` CLI + GraphQL instead of Linear GraphQL

### Intentionally Skipped

- **In-memory orchestrator state**: Not needed — Actions is stateless
- **Stall detection**: `timeout-minutes` is the only backstop
- **HTTP status API / dashboard**: GitHub Actions UI serves this role
- **Per-state concurrency limits**: All issues share the global pool
- **Dynamic config reload**: Each run reads config fresh (inherent)
- **`codex.read_timeout_ms`**: No app-server handshake
- **`linear_graphql` tool extension**: We use GitHub, not Linear
