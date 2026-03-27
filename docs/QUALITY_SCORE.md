# Quality Score

Tracks the quality grade of each domain and architectural layer.
Updated by garbage collection agents on a regular cadence.

## Grading scale

| Grade | Meaning |
|-------|---------|
| A | Excellent — well-tested, documented, clean structure |
| B | Good — minor gaps in tests or docs |
| C | Needs attention — missing tests, stale docs, or structural issues |
| D | Poor — significant technical debt, blocking issues |
| F | Critical — broken, untested, or architecturally unsound |

## Current scores

| Domain | Types | Config | Core | Services | Runtime | UI | Overall |
|--------|-------|--------|------|----------|---------|-----|---------|
| _example_ | - | - | - | - | - | - | - |

_TODO: Add domains and grades as the project grows._

## History

| Date | Change | Author |
|------|--------|--------|
| _project start_ | Initial template | setup |

## How scores are updated

1. **Garbage collection agents** run on a daily schedule (see `_github/workflows/gc.yml`)
2. They scan for pattern deviations, missing tests, and stale documentation
3. They update this file and open targeted fix-up PRs
4. Most fix-ups can be reviewed in under a minute and automerged
