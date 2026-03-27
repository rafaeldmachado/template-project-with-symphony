# Execution Plans

Plans are first-class artifacts. They are versioned and co-located in the repository
so agents can operate without relying on external context.

## Active plans

<!-- When adding a plan, link it here: -->
<!-- - [Plan name](exec-plans/active/plan-name.md) -->

_No active plans._

## Completed plans

<!-- Link to finished plans for historical context -->

_No completed plans yet._

## How to create a plan

1. Create a new file in `docs/exec-plans/active/<name>.md`
2. Use the template below
3. Update this index
4. When complete, move to `docs/exec-plans/completed/` and update this index

## Plan template

```markdown
# Plan: <title>

## Goal
What are we trying to achieve?

## Context
Why now? What prompted this?

## Approach
Step-by-step breakdown of the work.

## Progress
- [ ] Step 1
- [ ] Step 2

## Decision log
| Date | Decision | Rationale |
|------|----------|-----------|

## Acceptance criteria
How do we know this is done?
```
