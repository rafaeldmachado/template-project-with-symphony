# Agent Instructions

This file is a map. It tells you where to look — not everything you need to know.

## Architecture

See [docs/DESIGN.md](docs/DESIGN.md) for system design and domain boundaries.
See [docs/architecture/layers.md](docs/architecture/layers.md) for the dependency rule:

```
Types → Config → Core → Services → Runtime → UI
```

Cross-cutting concerns (auth, telemetry, feature flags) enter through Providers only.
Structural tests in `tests/structural/` enforce this. CI will reject violations.

## Knowledge Base

| What                        | Where                              |
|-----------------------------|------------------------------------|
| Design decisions & beliefs  | `docs/design-docs/`               |
| Active execution plans      | `docs/exec-plans/active/`         |
| Completed plans             | `docs/exec-plans/completed/`      |
| Technical debt              | `docs/exec-plans/tech-debt-tracker.md` |
| Product specifications      | `docs/product-specs/`             |
| Quality grades by domain    | `docs/QUALITY_SCORE.md`           |
| Reference material (llms.txt)| `docs/references/`               |
| Golden principles           | `docs/design-docs/golden-principles.md` |

## Rules

1. Run `make check` before every commit.
2. One branch per issue, one PR per branch. Use `make worktree ISSUE=<n>`.
3. Write tests for new functionality. Match existing patterns.
4. Do not modify `scripts/checks/`, `tests/structural/`, or CI workflows without approval.
5. Do not add dependencies without documenting the reason in the PR.
6. Use grep-friendly errors: `ERROR: [module] description` on single lines.
7. Keep files focused and under 300 lines.
8. Parse data shapes at boundaries — no YOLO probing of untyped data.
9. Prefer shared utilities over hand-rolled helpers for repeated patterns.

## Development

```bash
make worktree ISSUE=42    # isolated worktree + branch
make check                # all checks (lint + structure + tests)
make gc                   # garbage collection (branches, worktrees, deploys)
```

See [CLAUDE.md](CLAUDE.md) for tool-specific instructions.
See [.cursorrules](.cursorrules) for Cursor-specific instructions.
See [WORKFLOW.md](WORKFLOW.md) for Symphony orchestration config.
