# Core Beliefs

Operating principles for an agent-first development workflow.

## 1. The repository is the single source of truth

Anything the agent can't access from the repository effectively doesn't exist.
Knowledge that lives in Slack threads, Google Docs, or people's heads must be
encoded into the repo as versioned artifacts (code, markdown, schemas, plans).

## 2. Agents are most effective with strict boundaries

Predictable structure and enforced boundaries allow agents to move fast without
architectural drift. Constraints are multipliers, not limitations.

## 3. Enforce invariants, not implementations

We prescribe _what_ must hold (data shapes, layer boundaries, error formats)
but not _how_ to achieve it. Agents have freedom within the constraints.

## 4. Corrections are cheap, waiting is expensive

In a high-throughput agent workflow, fixing forward is often better than blocking.
Short-lived PRs, minimal blocking merge gates, and follow-up runs over
indefinite waits.

## 5. Human taste is captured once, then enforced continuously

Review comments, refactoring PRs, and user-facing bugs become documentation
updates or lint rules. When documentation falls short, promote the rule into code.

## 6. Technical debt is a high-interest loan

Pay it down continuously in small increments via garbage collection agents
rather than letting it compound. Daily sweeps over Friday cleanups.

## 7. Make things legible to agents

Optimize code organization, error messages, and documentation for agent
comprehension — just as you would for a new hire joining the team.
Grep-friendly errors, structured logging, predictable file layouts.
