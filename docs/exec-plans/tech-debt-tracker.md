# Technical Debt Tracker

Known technical debt, tracked here so agents can address it incrementally
during garbage collection sweeps.

## Active debt

| ID | Description | Severity | Domain | Added |
|----|-------------|----------|--------|-------|
| _example_ | _description_ | low/medium/high | _domain_ | _date_ |

_No tracked debt yet._

## Resolved debt

| ID | Description | Resolved | PR |
|----|-------------|----------|----|

_None yet._

## Process

1. When you discover tech debt during development, add it here
2. Garbage collection agents pick up items and open fix-up PRs
3. Move resolved items to the "Resolved" table with the PR link
4. High-severity items should also be tracked as GitHub issues
