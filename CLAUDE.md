# Project Instructions

## Overview

This repository is designed for AI-assisted development. Every convention, script, and workflow
exists to make autonomous agent work reliable and verifiable.

**First time?** Run `make init` for the interactive setup wizard, or see [docs/SETUP.md](docs/SETUP.md) for the manual guide.

## Architecture

See [docs/DESIGN.md](docs/DESIGN.md) for the system map and [docs/architecture/](docs/architecture/) for details.

**Dependency layers** (strict — no upward imports):

```text
Types → Config → Core → Services → Runtime → UI
```

Structural tests in `tests/structural/` enforce this layering. CI will fail on violations.

## Development Workflow

### Starting work on an issue

```bash
make worktree ISSUE=<issue-number>   # creates isolated worktree
```

This creates a git worktree at `.worktrees/<issue-number>/` with a branch named
`issue/<issue-number>`. Work there, commit, push, and open a PR.

### Running checks

```bash
make check          # runs all checks (lint + structure + tests)
make lint           # lint only
make test           # tests only
make test-e2e       # e2e tests only
make structure      # structural/architecture tests only
```

All checks must pass before a PR can merge. The CI pipeline runs these automatically.

### PR workflow

1. Push your branch
2. CI runs all checks
3. An ephemeral preview deploy is created if configured (see [docs/DEPLOY.md](docs/DEPLOY.md))
4. Human reviews the preview + code
5. On merge, preview is torn down automatically

### Symphony (autonomous mode)

Issues labeled `ready` + `agent` are automatically picked up by the Symphony workflow,
implemented by an AI agent, and delivered as PRs. See [docs/workflows/ai-development.md](docs/workflows/ai-development.md).

### Garbage collection

Stale branches, orphaned deploys, and abandoned worktrees are cleaned automatically on a schedule.
You can also run manually:

```bash
make gc             # run all garbage collection
make gc-branches    # clean merged/stale branches
make gc-worktrees   # clean abandoned worktrees
make gc-deploys     # clean orphaned PR deploys
make gc-artifacts   # clean old CI artifacts
```

## Conventions

- **One concern per file.** Keep files focused and under 300 lines when possible.
- **Grep-friendly errors.** Use `ERROR: [reason]` on single lines for easy parsing.
- **File-based logging.** Prefer writing logs to files over flooding stdout.
- **Stable interfaces.** Keep data structures at module boundaries stable. Changes to shared
  types require updating all consumers in the same PR.
- **No manual hotfixes.** All changes go through PRs with CI validation.

## Testing

- `tests/e2e/` — End-to-end tests. Run against preview deploys or local environment.
- `tests/integration/` — Integration tests. Test service boundaries.
- `tests/structural/` — Architecture enforcement. Validates layering, naming, and conventions.

See [tests/README.md](tests/README.md) for testing conventions.

## Monitoring

- Error tracking config lives in `monitoring/alerts/`
- Dashboard definitions in `monitoring/dashboards/`
- See [monitoring/README.md](monitoring/README.md) for setup.

## Scripts

All automation lives in `scripts/`. See the [Makefile](Makefile) for the full command reference.
Do not run scripts directly — always use `make` targets so flags and environment are consistent.
