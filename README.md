# Agent-First Development Template

A framework-agnostic project template designed from the ground up for AI-assisted development.
Clone it, run the wizard, and start shipping — with AI agents doing the implementation.

Built on ideas from OpenAI's [Harness Engineering](https://openai.com/index/harness-engineering/)
article and implements the [Symphony specification](https://github.com/openai/symphony/blob/main/SPEC.md)
for autonomous agent orchestration using GitHub Actions, Issues, and Projects.

---

## Why this exists

AI coding agents (Claude Code, Codex, Cursor) are capable of writing production code — but
only when the environment is designed for them. Without structure, agents drift: they duplicate
code, violate boundaries, invent conventions, and produce work that's hard to review.

This template solves that. It provides:

- **Structural enforcement** — dependency layering, naming conventions, and architecture tests
  that reject violations before they reach review
- **Progressive disclosure** — agents start with a 60-line map (`AGENTS.md`) and follow
  pointers to deeper context only when needed
- **Automated orchestration** — issues become PRs without human intervention, using the
  Symphony cycle
- **Garbage collection** — automated cleanup of stale branches, orphaned deploys, and
  pattern drift
- **Human-in-the-loop validation** — ephemeral PR previews and CI gates ensure humans
  steer while agents execute

The philosophy: **humans steer, agents execute**. Engineers design environments, specify
intent, and build feedback loops. Agents write code, tests, documentation, and tooling.
All changes go through PRs with CI validation. No manual hotfixes.

---

## Quick start

### Prerequisites

- Git
- Bash (macOS/Linux)
- GitHub CLI (`gh`) — authenticated
- Node.js (recommended, for template rendering)
- An AI agent CLI: [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) or [Codex](https://github.com/openai/codex)

### Create a new project

```bash
git clone <this-repo-url> my-project
cd my-project
make init
```

The interactive wizard walks through:

1. **Project identity** — name, description, repository URL
2. **Stack** — language, framework, runtime (the template is framework-agnostic)
3. **GitHub** — repository settings, secrets, project board
4. **Deploys** — ephemeral PR preview provider (Vercel, Netlify, Cloudflare, Fly.io, or custom)
5. **AI agent** — Claude Code or Codex, model selection, API key
6. **Monitoring** — error tracking provider

The wizard activates the GitHub config (`_github/` → `.github/`), configures your
stack's lint/test/CI scripts, writes `.env`, and creates labels on your repo.
After the wizard, run `make setup` to install dependencies and `make check` to verify.

> **Why `_github/`?** The template stores GitHub workflows, issue templates, and PR
> templates in `_github/` (without the dot) so they don't trigger on the template
> repository itself. `make init` moves them to `.github/` in your new project.

For manual setup without the wizard, see [docs/SETUP.md](docs/SETUP.md).

---

## How it works

### Two modes of operation

#### Manual — agent in your terminal

You (or an agent in your terminal) pick an issue and work it:

```bash
make worktree ISSUE=42        # isolated workspace + branch
cd .worktrees/42
# ... implement, test, commit ...
make check                    # validate
git push && gh pr create      # deliver
```

#### Autonomous — Symphony cycle

Issues labeled `ready` + `agent` are automatically picked up, implemented by an AI agent,
and delivered as pull requests. You review and merge.

```
 ┌──────────────────────────────────────────────┐
 │            SYMPHONY WORKFLOW                  │
 │     (polls every 15 min or on event)         │
 └──────────────────┬───────────────────────────┘
                    │
 ┌──────────────────▼───────────────────────────┐
 │  1. DISCOVER                                 │
 │  Find issues with [ready] + [agent] labels   │
 │  Sort by priority: p0 > p1 > p2              │
 └──────────────────┬───────────────────────────┘
                    │
 ┌──────────────────▼───────────────────────────┐
 │  2. CLAIM                                    │
 │  Swap label: ready → in-progress             │
 └──────────────────┬───────────────────────────┘
                    │
 ┌──────────────────▼───────────────────────────┐
 │  3. WORKSPACE                                │
 │  Create branch issue/<number>                │
 │  Run project setup hooks                     │
 └──────────────────┬───────────────────────────┘
                    │
 ┌──────────────────▼───────────────────────────┐
 │  4. PROMPT                                   │
 │  Render WORKFLOW.md template with issue data  │
 └──────────────────┬───────────────────────────┘
                    │
 ┌──────────────────▼───────────────────────────┐
 │  5. EXECUTE                                  │
 │  Run coding agent (Claude Code / Codex)      │
 │  Permission bypass for CI, JSON output       │
 └──────────────────┬───────────────────────────┘
                    │
 ┌──────────────────▼───────────────────────────┐
 │  6. VALIDATE                                 │
 │  make check (lint + structure + tests)       │
 └──────────────────┬───────────────────────────┘
                    │
 ┌──────────────────▼───────────────────────────┐
 │  7. DELIVER                                  │
 │  Push branch, open PR, link issue            │
 │  Log token usage and cost metrics            │
 └──────────────────┬───────────────────────────┘
                    │
 ┌──────────────────▼───────────────────────────┐
 │  8. RECONCILE                                │
 │  Success → label [human-review]              │
 │  Failure → label [ready] (retry next cycle)  │
 └──────────────────────────────────────────────┘
```

To use Symphony:

1. Set `agent.name` to `claude` or `codex` in [WORKFLOW.md](WORKFLOW.md)
2. Add the corresponding API key as a GitHub Actions secret
3. Create an issue, add the `ready` + `agent` labels
4. The workflow picks it up, runs the agent, and delivers a PR
5. You review the preview deploy and merge

See [docs/workflows/ai-development.md](docs/workflows/ai-development.md) for a detailed walkthrough
and [docs/symphony-spec.md](docs/symphony-spec.md) for how our implementation maps to the Symphony spec.

---

## Project structure

```
.
├── AGENTS.md                    # Agent entry point — the map
├── CLAUDE.md                    # Claude Code project instructions
├── WORKFLOW.md                  # Symphony config + prompt template
├── Makefile                     # All commands go through here
├── .env.example                 # Environment template
│
├── _github/                     # GitHub config (activated to .github/ by make init)
│   ├── ISSUE_TEMPLATE/          # Structured templates (bug, feature, story)
│   ├── PULL_REQUEST_TEMPLATE.md # PR checklist
│   └── workflows/
│       ├── ci.yml               # Lint + structure + tests on every PR
│       ├── symphony.yml         # Autonomous agent orchestration
│       ├── pr-deploy.yml        # Ephemeral preview deploys
│       ├── pr-cleanup.yml       # Tear down previews on merge/close
│       └── gc.yml               # Scheduled garbage collection
│
├── docs/
│   ├── DESIGN.md                # System map and domain boundaries
│   ├── SETUP.md                 # Setup guide (manual alternative to wizard)
│   ├── DEPLOY.md                # PR preview deploy configuration
│   ├── PLANS.md                 # Active and completed execution plans
│   ├── QUALITY_SCORE.md         # Quality grades by domain
│   ├── architecture/
│   │   └── layers.md            # Dependency layering rule
│   ├── design-docs/             # Architecture decisions
│   │   ├── golden-principles.md # Non-negotiable engineering rules
│   │   └── core-beliefs.md      # Agent-first operating principles
│   ├── exec-plans/              # Active and completed plans
│   ├── product-specs/           # Product specifications
│   ├── references/              # External reference material
│   ├── workflows/
│   │   └── ai-development.md    # AI workflow deep-dive
│   └── symphony-spec.md         # Symphony spec mapping
│
├── scripts/
│   ├── init.sh                  # Interactive setup wizard
│   ├── setup.sh                 # Dependency installation
│   ├── checks/                  # Lint, test, structure checks
│   ├── deploy/                  # PR preview deploy/cleanup
│   ├── gc/                      # Garbage collection scripts
│   ├── symphony/                # Config parser, prompt renderer
│   └── worktree/                # Worktree create/cleanup
│
├── tests/
│   ├── e2e/                     # End-to-end tests
│   ├── integration/             # Integration tests
│   └── structural/              # Architecture enforcement tests
│
└── monitoring/
    ├── alerts/                  # Error tracking configuration
    └── dashboards/              # Dashboard definitions
```

---

## Architecture

The template enforces a strict dependency layering rule:

```
Types → Config → Core → Services → Runtime → UI
```

Each layer can only import from layers to its left. No upward imports.
Cross-cutting concerns (auth, telemetry, feature flags) enter through Providers only.

Structural tests in `tests/structural/` enforce this at CI time. Violations fail the build.

See [docs/architecture/layers.md](docs/architecture/layers.md) for the full rule set and
[docs/DESIGN.md](docs/DESIGN.md) for the domain map.

---

## WORKFLOW.md — the single source of truth

[WORKFLOW.md](WORKFLOW.md) is a dual-purpose file:

1. **YAML front matter** — runtime configuration for the Symphony cycle (polling interval,
   concurrency limits, agent choice, hooks, timeouts)
2. **Markdown body** — the prompt template rendered per issue, using Liquid-like syntax
   (`{{ variable }}`, `{% if %}`, `{% for %}`)

The GitHub Actions workflow reads all config from this file at runtime via
`scripts/symphony/parse-config.sh`. To change the agent, model, concurrency, or hooks —
edit WORKFLOW.md, not the workflow YAML.

### Hooks

Hooks are shell commands that run at workspace lifecycle events:

| Hook | When | Example use |
|------|------|-------------|
| `after_create` | After workspace is created | Branch setup, dependency install |
| `before_run` | Before agent starts | Rebase on main, pull latest |
| `after_run` | After agent finishes | Run `make check`, additional validation |

Hooks run in both CI (Symphony) and local (`make worktree`) modes, keeping behavior
consistent across environments.

### Prompt template

The markdown body supports:

- `{{ issue.identifier }}`, `{{ issue.title }}`, `{{ issue.description }}` — issue data
- `{{ issue.labels | join: ", " }}` — label list with join filter
- `{% if issue.blocked_by.size > 0 %}` ... `{% endif %}` — conditionals
- `{% for blocker in issue.blocked_by %}` ... `{% endfor %}` — loops
- `{{ attempt }}` — retry attempt number

The template is rendered by `scripts/symphony/render-prompt.js` (Node.js) with a
bash fallback for environments without Node.

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
| `make gc-branches` | Clean merged/stale branches |
| `make gc-worktrees` | Clean abandoned worktrees |
| `make gc-deploys` | Clean orphaned PR deploys |
| `make gc-artifacts` | Clean old CI artifacts |
| `make deploy-preview PR=N` | Deploy PR preview |
| `make deploy-cleanup PR=N` | Tear down PR preview |

---

## Issue management

### Labels

| Label | Purpose |
|-------|---------|
| `ready` | Issue is ready for agent work |
| `agent` | Issue should be handled by an AI agent |
| `in-progress` | Agent is working on it (set by Symphony) |
| `human-review` | PR created, needs human review (set by Symphony) |
| `p0` | Critical priority — dispatched first |
| `p1` | High priority |
| `p2` | Normal priority |

Issues need both `ready` + `agent` to be picked up. Priority labels control dispatch
order: `p0` > `p1` > `p2` > unlabeled.

### Issue dependencies

Symphony uses GitHub's native `blockedBy` issue relationship. If an issue has open blockers,
the agent is instructed not to proceed. Blockers are fetched via the GitHub GraphQL API
and injected into the prompt template.

### Writing issues for agents

Issues are the primary interface between humans and agents. Write them as if briefing a
new engineer who has never seen the codebase:

1. **Context** — why does this matter? Link to relevant design docs
2. **Specifics** — exact requirements, not vague goals
3. **Acceptance criteria** — testable conditions; agents use these as checklists
4. **Out of scope** — what NOT to do (prevents scope creep)
5. **Technical notes** — which layers/domains are involved, constraints

The repo includes structured issue templates for bugs, features, and user stories.

---

## Agent support

### Claude Code

Configured with `agent.name: claude` in WORKFLOW.md. In CI, runs with:
- `--dangerously-skip-permissions` for non-interactive execution
- `--output-format json` for structured output and metrics capture
- `--max-turns` and `--max-budget-usd` from WORKFLOW.md config

Project instructions live in [CLAUDE.md](CLAUDE.md).

### Codex

Configured with `agent.name: codex` in WORKFLOW.md. In CI, runs with:
- `--full-auto --quiet` for headless mode
- Auth via `OPENAI_API_KEY` environment variable

### Cursor

Project instructions live in [.cursorrules](.cursorrules). Works in manual mode
(agent in your terminal or IDE).

### Metrics

Symphony captures token usage and cost from agent JSON output and includes them in
PR descriptions and issue comments.

---

## Garbage collection

Agents replicate patterns — even suboptimal ones. Garbage collection prevents drift:

- **Branches** — deletes merged and stale branches
- **Worktrees** — cleans up abandoned worktrees
- **Deploys** — tears down orphaned PR previews
- **Artifacts** — removes old CI artifacts

Run manually with `make gc` or let the scheduled workflow handle it.

---

## Ephemeral PR deploys

Every PR can get a live preview environment. Agents open PRs; humans review
the live deploy before merging.

Supported providers: Vercel, Netlify, Cloudflare Pages, Fly.io, or custom.

See [docs/DEPLOY.md](docs/DEPLOY.md) for setup.

---

## Progressive disclosure

Agents don't need a 1,000-page manual. They need a map:

1. **[AGENTS.md](AGENTS.md)** (~60 lines) — the table of contents and rules
2. **[docs/DESIGN.md](docs/DESIGN.md)** — system overview and domain map
3. **[docs/architecture/layers.md](docs/architecture/layers.md)** — the dependency rule
4. **[docs/design-docs/](docs/design-docs/)** — deep context when needed
5. **[docs/exec-plans/](docs/exec-plans/)** — what's in flight

Agents start at AGENTS.md and follow pointers to deeper context. This layered approach
keeps context windows efficient while ensuring agents can find everything they need.

---

## Adopting individual concepts

You don't have to use the whole template. Each piece is designed to work independently:

### Just the architecture enforcement

Copy `tests/structural/` and the layering rule from `docs/architecture/layers.md`.
Add the structural test step to your CI pipeline. This alone catches a large class of
agent-introduced architecture violations.

### Just the Symphony orchestration

Copy `_github/workflows/symphony.yml` to your `.github/workflows/`, along with
`scripts/symphony/` and `WORKFLOW.md`. Adapt the prompt template to your project.
You need the GitHub labels and a configured agent API key.

### Just the worktree isolation

Copy `scripts/worktree/` and the `worktree` target from the Makefile.
This gives you per-issue isolation without any other dependencies.

### Just the garbage collection

Copy `scripts/gc/` and `_github/workflows/gc.yml` to your `.github/workflows/`.
Each GC script is self-contained and can run independently.

### Just the agent instructions pattern

Use `AGENTS.md` as a pattern for your own project. The key insight: a short, focused
entry point with pointers to deeper documentation. Keep it under 60 lines.

---

## Symphony attribution

This template implements the [Symphony specification](https://github.com/openai/symphony/blob/main/SPEC.md)
by OpenAI — an open protocol for connecting issue trackers to coding agents through
an orchestrated cycle of discovery, execution, and delivery.

Our implementation adapts Symphony to GitHub-native primitives:

| Symphony concept | Our implementation |
|-----------------|-------------------|
| Issue tracker | GitHub Issues + Projects |
| State machine | Label transitions (`ready` → `in-progress` → `human-review`) |
| Priority | `p0`, `p1`, `p2` labels |
| Dependencies | GitHub's native `blockedBy` relationship |
| Workspace | Git worktrees (local) / branches (CI) |
| Prompt template | WORKFLOW.md with Liquid-like syntax |
| Agent dispatch | Claude Code or Codex CLI |
| Validation | `make check` (lint + structure + tests) |
| Delivery | PR with linked issue |
| Reconciliation | Label swap based on success/failure |
| Hooks | Shell commands from WORKFLOW.md front matter |

See [docs/symphony-spec.md](docs/symphony-spec.md) for a detailed section-by-section mapping.

---

## Key documents

| Document | Purpose |
|----------|---------|
| [AGENTS.md](AGENTS.md) | Agent entry point and rules |
| [CLAUDE.md](CLAUDE.md) | Claude Code project instructions |
| [WORKFLOW.md](WORKFLOW.md) | Symphony config + prompt template |
| [docs/SETUP.md](docs/SETUP.md) | Setup guide |
| [docs/DESIGN.md](docs/DESIGN.md) | System design and domain map |
| [docs/DEPLOY.md](docs/DEPLOY.md) | PR preview deploy setup |
| [docs/architecture/layers.md](docs/architecture/layers.md) | Dependency layering rule |
| [docs/design-docs/golden-principles.md](docs/design-docs/golden-principles.md) | Non-negotiable engineering rules |
| [docs/design-docs/core-beliefs.md](docs/design-docs/core-beliefs.md) | Agent-first operating principles |
| [docs/workflows/ai-development.md](docs/workflows/ai-development.md) | AI workflow deep-dive |
| [docs/symphony-spec.md](docs/symphony-spec.md) | Symphony spec mapping |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guidelines |

---

## License

MIT
