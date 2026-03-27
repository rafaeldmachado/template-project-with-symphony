# AI-Assisted Development Workflow

How this repository is designed to work with AI coding agents.

## Philosophy

**Humans steer. Agents execute.**

Engineers design environments, specify intent, and build feedback loops.
Agents write code, tests, documentation, and tooling. All changes go through
PRs with CI validation. No manual hotfixes.

## Two modes of operation

### Manual — agent per session

You (or an agent in your terminal) pick an issue and work it:

```bash
make worktree ISSUE=42        # isolated workspace + branch
cd .worktrees/42
# ... implement, test, commit ...
make check                    # validate
git push && gh pr create      # deliver
```

### Autonomous — Symphony cycle

Symphony runs as a GitHub Actions workflow (`_github/workflows/symphony.yml`, activated
to `.github/workflows/symphony.yml` by `make init`).
It implements the [Symphony spec](https://github.com/openai/symphony/blob/main/SPEC.md)
using GitHub Issues as the tracker.

The cycle:

```
                    ┌─────────────────────────────────────┐
                    │         SYMPHONY WORKFLOW            │
                    │    (polls every 15 min or on event)  │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │  1. DISCOVER                        │
                    │  Find issues with [ready] + [agent] │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │  2. CLAIM                           │
                    │  Move label: ready → in-progress    │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │  3. WORKSPACE                       │
                    │  Create branch issue/<number>       │
                    │  Run project setup                  │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │  4. PROMPT                          │
                    │  Render WORKFLOW.md with issue data  │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │  5. EXECUTE                         │
                    │  Run coding agent (Claude/Codex/…)  │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │  6. VALIDATE                        │
                    │  make check                         │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │  7. DELIVER                         │
                    │  Push branch, open PR, link issue   │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │  8. RECONCILE                       │
                    │  Success → label [human-review]     │
                    │  Failure → label [ready] (retry)    │
                    └─────────────────────────────────────┘
```

**To use Symphony**: add the `ready` and `agent` labels to any issue.
Add `p0`, `p1`, or `p2` for priority (higher priority issues are dispatched first).
The workflow picks it up on the next poll, runs an agent, and delivers a PR.
You review the preview deploy and merge.

**Configuration**: [WORKFLOW.md](../../WORKFLOW.md) is the single source of truth.
The YAML front matter controls polling, concurrency, hooks, and agent settings.
The markdown body is the prompt template rendered per issue.

**Agent choice**: Set `agent.name` to `claude` or `codex` in WORKFLOW.md.
The workflow reads this at runtime — no need to edit symphony.yml.

**Hooks**: The `after_create`, `before_run`, and `after_run` hooks defined in
WORKFLOW.md run in both CI (Symphony) and local (`make worktree`) modes.
Customize them to add project-specific setup or validation.

**Runner**: Both CI and Symphony workflows include a `pick-runner` job that checks
for an online self-hosted runner. If available, work runs locally on your machine (free).
If not, it falls back to GitHub-hosted runners (`ubuntu-latest`). Set up a self-hosted
runner with `make setup-runner`. See [SETUP.md](../SETUP.md#5-self-hosted-runner-optional)
for details.

See [symphony-spec.md](../symphony-spec.md) for how our implementation maps to the Symphony spec.

## Issue writing for agents

Issues are the primary interface between humans and agents. Write them as if
briefing a new engineer who has never seen the codebase:

1. **Context**: Why does this matter? Link to relevant design docs.
2. **Specifics**: Exact requirements, not vague goals.
3. **Acceptance criteria**: Testable conditions. Agents use these as checklists.
4. **Out of scope**: What NOT to do (prevents scope creep).
5. **Technical notes**: Which layers/domains are involved. Constraints.

## Worktree isolation

Each issue gets its own git worktree (`.worktrees/<issue>/`). This means:
- Agents can work on multiple issues in parallel without conflicts
- Each worktree has its own branch (`issue/<number>`)
- The app can boot independently per worktree
- Observability (logs, metrics) is isolated per worktree

## Garbage collection

Agents replicate patterns — even suboptimal ones. Garbage collection
prevents drift:

- **Daily**: Branch cleanup, worktree cleanup, deploy cleanup
- **Weekly** (when configured): Doc gardening, quality score updates, pattern deviation scans
- **Per PR**: Structural tests catch layer violations, naming issues, and secrets

## Progressive disclosure

Agents don't need a 1,000-page manual. They need a map:

1. **AGENTS.md** (~60 lines) — the table of contents
2. **docs/DESIGN.md** — system overview and domain map
3. **docs/architecture/layers.md** — the dependency rule
4. **docs/design-docs/** — deep context when needed
5. **docs/exec-plans/** — what's in flight

Agents start at AGENTS.md and are taught where to look next.
