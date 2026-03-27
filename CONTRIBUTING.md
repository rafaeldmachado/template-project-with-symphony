# Contributing

Thank you for your interest in contributing to the Agent-First Development Template.

## Understanding the project

This repository is a **template**, not a working application. It provides the
scaffolding, scripts, workflows, and documentation that downstream projects clone
and configure via `make init`.

When contributing, keep this distinction in mind:

- **Template files** — scripts, docs, structural tests, config templates. These live
  in the repo as-is and are used directly by downstream projects.
- **GitHub config** (`_github/`) — workflows, issue templates, PR template. These are
  stored under `_github/` and activated to `.github/` when a downstream project runs
  `make init`. This prevents workflows from triggering on the template repo itself.
- **Makefile targets** — commands like `make check`, `make worktree`, etc. are designed
  for downstream projects. For template development, run scripts directly or use
  `make check` to validate the structural tests still pass.

## Getting started

1. Fork the repository and clone it locally
2. Run `make check` to verify structural tests pass

No `make init` or `make setup` needed — those are for downstream project creation.

## How to contribute

### Reporting bugs

Open an issue describing:

- What you were doing (creating a project, running the wizard, using a specific workflow)
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, shell, tool versions)

### Suggesting features

Open an issue describing:

- The problem (what's missing or painful when using the template)
- Your proposed solution
- How it fits with the template's framework-agnostic philosophy

### Submitting code

1. **Open an issue first** — describe what you're changing and why
2. **Fork and branch** — create a feature branch from `main`
3. **Make your changes**
4. **Test** — run `make check` to verify structural tests pass.
   If you changed the wizard or setup flow, test by running `make init` in a
   fresh clone.
5. **Push and open a PR** — explain what changed and link the issue

## Areas of contribution

### High-impact areas

- **New stack presets** — add language/framework support to the `init.sh` wizard
  (lint commands, test runners, CI setup steps)
- **New deploy providers** — add provider support in `scripts/deploy/`
- **Agent integrations** — add support for new coding agents in `scripts/symphony/`
  and `_github/workflows/symphony.yml`
- **Structural tests** — expand architecture enforcement in `tests/structural/`
- **Garbage collection** — improve or add GC scripts in `scripts/gc/`
- **Issue templates** — improve templates in `_github/ISSUE_TEMPLATE/`

### Documentation

- Improving setup instructions for specific platforms or stacks
- Adding examples and guides for common project configurations
- Expanding the Symphony spec mapping in `docs/symphony-spec.md`

### What to avoid

- **Framework-specific code** — the template must remain framework-agnostic.
  Stack-specific logic belongs in the wizard's preset system, not in core scripts.
- **Breaking the wizard** — `make init` is the primary entry point for new users.
  Test any changes to `scripts/init.sh` end-to-end.
- **Active `.github/` directory** — workflow files belong in `_github/`, not `.github/`.
  The init wizard activates them for downstream projects.

## Code conventions

The template follows its own golden principles (since downstream projects inherit them):

- One concern per file, under 300 lines
- Grep-friendly errors: `ERROR: [module] description`
- Bash scripts use `set -euo pipefail`
- No hardcoded secrets — use `.env` or environment variables
- Shell scripts must work on both macOS (BSD tools) and Linux (GNU tools)

## Review process

1. A maintainer reviews the PR
2. Changes may be requested — address them and push new commits
3. Once approved, a maintainer merges the PR

## Questions?

Open a discussion or issue.
