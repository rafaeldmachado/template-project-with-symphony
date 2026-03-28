# Agent-First Development Template

A project template designed for AI-assisted development.
Clone it, run the wizard, and start shipping — with AI agents doing the implementation.

Built on ideas from OpenAI's [Harness Engineering](https://openai.com/index/harness-engineering/)
article and implements the [Symphony specification](https://github.com/openai/symphony/blob/main/SPEC.md)
for autonomous agent orchestration using GitHub Actions, Issues, and Projects.

## Why this exists

AI coding agents (Claude Code, Codex, Cursor) can write production code — but only when the
environment is designed for them. Without structure, agents drift: they duplicate code, violate
boundaries, invent conventions, and produce work that's hard to review.

This template provides structural enforcement, automated orchestration, garbage collection,
and human-in-the-loop validation so that **humans steer and agents execute**.

---

## Tutorial: from clone to your first agent PR

This walkthrough takes you from zero to a working project where an AI agent implements
an issue and delivers a pull request. Follow it in order.

### Prerequisites

- Git and Bash (macOS, Linux, or Windows via Git Bash/WSL)
- [GitHub CLI](https://cli.github.com/) (`gh`) — installed and authenticated
- An AI agent: [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) or [Codex](https://github.com/openai/codex)

### Step 1: Clone and run the wizard

```bash
git clone <this-repo-url> my-project
cd my-project
make init
```

The wizard walks you through seven screens:

| Screen | What it asks | What it does |
|--------|-------------|--------------|
| 1. Project basics | Name, description | Replaces template README, removes template files |
| 2. Stack | Language/framework | Writes lint, test, and CI scripts for your stack |
| 3. GitHub | Repo URL, labels | Creates repo (if needed) and Symphony labels |
| 4. Deploys | Preview provider | Sets `DEPLOY_PROVIDER` and token in `.env` |
| 5. AI Agent | Claude or Codex | Configures `WORKFLOW.md` and API key in `.env` |
| 6. Monitoring | Error tracker | Sets `MONITOR_DSN` in `.env` |
| 7. Self-hosted runner | Use local machine for CI | Installs GitHub Actions runner, configures fallback |

After the wizard finishes, the template's own `.github/` (CI for the template itself)
is replaced with your project's GitHub config from `_github/`. Template files like
`CONTRIBUTING.md`, `LICENSE`, and `CODE_OF_CONDUCT.md` are removed — your project starts clean.

> **Don't have `gh` installed?** The wizard skips the GitHub step. You can configure
> GitHub manually later — see [docs/SETUP.md](docs/SETUP.md).

### Step 2: Install dependencies and verify

```bash
make setup    # install your stack's dependencies
make check    # run lint + structural tests + unit tests
```

All checks should pass on a fresh project. If something fails, check the wizard output
for warnings. See [docs/SETUP.md](docs/SETUP.md) for troubleshooting.

### Step 3: Set up GitHub

#### 3a. Configure repository settings

Go to your repo's **Settings > Actions > General**:

- Set workflow permissions to **"Read and write permissions"**
- Check **"Allow GitHub Actions to create and approve pull requests"**

#### 3b. Add secrets

Go to **Settings > Secrets and variables > Actions** and add the secret for your agent:

| Agent | Secret name | Value |
|-------|------------|-------|
| Claude Code | `ANTHROPIC_API_KEY` | Your Anthropic API key |
| Codex | `OPENAI_API_KEY` | Your OpenAI API key |

For the full list of secrets and variables (deploy tokens, project board sync, etc.),
see [docs/SETUP.md](docs/SETUP.md#secrets-and-variables).

#### 3c. Create a GitHub Project board (optional but recommended)

Symphony can track issue state transitions on a Project board:

1. Create a new Project at your org or user's **Projects** tab
2. Add a **Status** field with these values: `Ready`, `In Progress`, `Human Review`, `Done`
3. Note the project number from the URL (e.g., `/projects/3` → `3`)
4. Add `PROJECT_URL` (full URL, e.g. `https://github.com/users/you/projects/3`) and `PROJECT_NUMBER` as repo variables
5. Create a [PAT](https://github.com/settings/tokens) with `project` scope and add it as the `PROJECT_TOKEN` secret

### Step 4: Write your first issue

Create an issue in your repo. Use the **Story** template (it's pre-installed by the wizard).

Write it as if briefing an engineer who has never seen the codebase:

```markdown
## Context
We need a health check endpoint so the load balancer can verify the service is running.

## Requirements
- GET /health returns 200 with { "status": "ok" }
- Response includes the current timestamp
- No authentication required

## Acceptance criteria
- [ ] GET /health returns 200
- [ ] Response body is valid JSON with "status" and "timestamp" fields
- [ ] Unit test covers the endpoint
- [ ] `make check` passes

## Out of scope
- Detailed dependency health checks (database, cache) — that's a separate issue
```

Good agent issues have: **context** (why), **specifics** (what exactly), **acceptance criteria**
(testable conditions), and **out of scope** (what NOT to do).

### Step 5: Try manual mode first

Before enabling autonomous mode, run the agent yourself to see the workflow:

```bash
make worktree ISSUE=1           # creates .worktrees/1/ with branch issue/1
cd .worktrees/1
```

Now run your agent in this worktree:

```bash
# Claude Code
claude

# Codex
codex
```

The agent reads `AGENTS.md` as its entry point, follows pointers to design docs, implements
the issue, writes tests, and runs `make check`. When it's done:

```bash
git push -u origin issue/1
gh pr create --fill
```

Review the PR. If you set up a deploy provider, you'll get an ephemeral preview URL.
Merge when satisfied.

Clean up the worktree:

```bash
cd ../..
make worktree-cleanup ISSUE=1
```

### Step 6: Go autonomous with Symphony

Now that you've seen the manual flow, let Symphony do it automatically.

1. **Create another issue** (or use an existing one)
2. **Add two labels**: `ready` + `agent`
3. **Optionally add a priority label**: `p0` (critical), `p1` (high), or `p2` (normal)

That's it. Symphony polls every 15 minutes (configurable in `WORKFLOW.md`). On the next poll:

1. It discovers your labeled issue
2. Claims it by swapping `ready` → `in-progress`
3. Creates a branch and workspace
4. Renders the prompt from `WORKFLOW.md` with your issue data
5. Runs the agent (Claude Code or Codex)
6. Validates with `make check`
7. Pushes and opens a PR linked to the issue
8. On success: labels the PR `human-review`. On failure: labels the issue `ready` for retry.

You review the PR and preview deploy, then merge. The preview environment is torn down
automatically on merge.

### Step 7: Customize and iterate

Now that the core flow works, tailor the template to your project:

| What to customize | Where |
|-------------------|-------|
| Agent prompt and behavior | [WORKFLOW.md](WORKFLOW.md) — edit the markdown body |
| Agent concurrency and budget | [WORKFLOW.md](WORKFLOW.md) — `agent.max_concurrent_agents`, `agent.max_budget_usd` |
| Lifecycle hooks | [WORKFLOW.md](WORKFLOW.md) — `hooks.after_create`, `hooks.before_run`, `hooks.after_run` |
| Architecture rules | [docs/architecture/layers.md](docs/architecture/layers.md) |
| Structural tests | [tests/structural/](tests/structural/) — add project-specific invariants |
| System design | [docs/DESIGN.md](docs/DESIGN.md) — fill in your domains and boundaries |
| Deploy provider | [docs/DEPLOY.md](docs/DEPLOY.md) — configure your preview environment |

---

## Commands

All automation runs through `make`. Do not run scripts directly.

| Command | What it does |
|---------|-------------|
| `make init` | Interactive setup wizard |
| `make setup` | Install dependencies |
| `make check` | Run all checks (lint + structure + tests) |
| `make lint` | Linters only |
| `make test` | Unit and integration tests |
| `make test-e2e` | End-to-end tests |
| `make structure` | Architecture enforcement tests |
| `make worktree ISSUE=N` | Create isolated worktree for issue N |
| `make worktree-cleanup ISSUE=N` | Clean up worktree for issue N |
| `make gc` | Run all garbage collection |
| `make deploy-preview PR=N` | Deploy PR preview |
| `make deploy-cleanup PR=N` | Tear down PR preview |
| `make setup-runner` | Install self-hosted GitHub Actions runner |
| `make runner-start` | Start the runner service |
| `make runner-stop` | Stop the runner service |
| `make runner-status` | Show runner status |
| `make runner-remove` | Unregister and remove the runner |

---

## How Symphony works

Issues labeled `ready` + `agent` are automatically picked up, implemented by an AI agent,
and delivered as pull requests. You review and merge.

```
              ┌─────────────────────────────────────┐
              │         SYMPHONY WORKFLOW            │
              │    (polls every 15 min or on event)  │
              └──────────────┬──────────────────────┘
                             │
              ┌──────────────▼──────────────────────┐
              │  1. DISCOVER                        │
              │  Find issues with [ready] + [agent] │
              │  Sort by priority: p0 > p1 > p2     │
              └──────────────┬──────────────────────┘
                             │
              ┌──────────────▼──────────────────────┐
              │  2. CLAIM                           │
              │  Swap label: ready → in-progress    │
              └──────────────┬──────────────────────┘
                             │
              ┌──────────────▼──────────────────────┐
              │  3. WORKSPACE                       │
              │  Create branch issue/<number>       │
              │  Run project setup hooks            │
              └──────────────┬──────────────────────┘
                             │
              ┌──────────────▼──────────────────────┐
              │  4. PROMPT                          │
              │  Render WORKFLOW.md with issue data  │
              └──────────────┬──────────────────────┘
                             │
              ┌──────────────▼──────────────────────┐
              │  5. EXECUTE                         │
              │  Run coding agent (Claude / Codex)  │
              └──────────────┬──────────────────────┘
                             │
              ┌──────────────▼──────────────────────┐
              │  6. VALIDATE                        │
              │  make check (lint + structure + tests)│
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

[WORKFLOW.md](WORKFLOW.md) is the single source of truth for Symphony configuration.
The YAML front matter controls the agent, polling, hooks, and concurrency.
The markdown body is the prompt template. See [docs/workflows/ai-development.md](docs/workflows/ai-development.md)
for a deep dive and [docs/symphony-spec.md](docs/symphony-spec.md) for how our implementation
maps to the Symphony spec.

---

## Adopting individual pieces

You don't have to use the whole template. Each piece works independently:

| What you want | What to copy |
|---------------|-------------|
| Architecture enforcement | `tests/structural/` + `docs/architecture/layers.md` → add to your CI |
| Symphony orchestration | `_github/workflows/symphony.yml` + `scripts/symphony/` + `WORKFLOW.md` |
| Worktree isolation | `scripts/worktree/` + the `worktree` Makefile target |
| Garbage collection | `scripts/gc/` + `_github/workflows/garbage-collector.yml` |
| Self-hosted runner with fallback | `scripts/runner/` + the `pick-runner` job pattern from `ci.yml` |
| Agent instructions pattern | Use `AGENTS.md` as a template — short entry point with pointers to deeper docs |

---

## Project structure

```
.
├── AGENTS.md                    # Agent entry point — the 60-line map
├── CLAUDE.md                    # Claude Code project instructions
├── WORKFLOW.md                  # Symphony config + prompt template
├── Makefile                     # All commands go through here
│
├── _github/                     # GitHub config (activated to .github/ by make init)
│   ├── ISSUE_TEMPLATE/          # Structured templates (bug, feature, story)
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── workflows/               # CI, Symphony, deploys, GC
│
├── docs/
│   ├── SETUP.md                 # Detailed setup guide
│   ├── DESIGN.md                # System map and domain boundaries
│   ├── DEPLOY.md                # PR preview deploy configuration
│   ├── architecture/layers.md   # Dependency layering rule
│   ├── design-docs/             # Architecture decisions and principles
│   ├── exec-plans/              # Active and completed plans
│   └── workflows/               # AI workflow deep-dive
│
├── scripts/
│   ├── init.sh                  # Setup wizard
│   ├── checks/                  # Lint, test, structure checks
│   ├── deploy/                  # PR preview deploy/cleanup
│   ├── gc/                      # Garbage collection
│   ├── runner/                  # Self-hosted runner setup/management
│   ├── symphony/                # Config parser, prompt renderer
│   └── worktree/                # Worktree create/cleanup
│
├── tests/structural/            # Architecture enforcement tests
│
└── monitoring/                  # Alerts and dashboards
```

---

## Key documents

| Document | Purpose |
|----------|---------|
| [AGENTS.md](AGENTS.md) | Agent entry point and rules |
| [CLAUDE.md](CLAUDE.md) | Claude Code project instructions |
| [WORKFLOW.md](WORKFLOW.md) | Symphony config + prompt template |
| [docs/SETUP.md](docs/SETUP.md) | Detailed setup guide |
| [docs/DESIGN.md](docs/DESIGN.md) | System design and domain map |
| [docs/DEPLOY.md](docs/DEPLOY.md) | PR preview deploy setup |
| [docs/architecture/layers.md](docs/architecture/layers.md) | Dependency layering rule |
| [docs/design-docs/golden-principles.md](docs/design-docs/golden-principles.md) | Non-negotiable engineering rules |
| [docs/workflows/ai-development.md](docs/workflows/ai-development.md) | AI workflow deep-dive |
| [docs/symphony-spec.md](docs/symphony-spec.md) | Symphony spec mapping |

---

## License

MIT
