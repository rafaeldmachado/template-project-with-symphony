# Golden Principles

Non-negotiable, mechanically enforceable rules that keep the codebase legible
and consistent for both agents and humans.

These are opinionated and intentional. Garbage collection agents scan for
deviations on a regular cadence and open fix-up PRs.

---

## 1. Shared utilities over hand-rolled helpers

Prefer shared utility packages for repeated patterns. Centralizing invariants
prevents drift when agents replicate existing patterns.

**Violation**: duplicated helper functions across multiple files.
**Fix**: extract to a shared utility in `core/utils/`.

## 2. Parse at the boundary, don't probe

Validate and parse data shapes at system boundaries (API inputs, file reads,
env vars). Never build logic on guessed/untyped shapes.

**Violation**: accessing nested properties without validation.
**Fix**: use a schema validation library at the entry point.

## 3. Grep-friendly errors

All error messages follow the format: `ERROR: [module] description`
Single line, parseable, actionable.

**Violation**: multi-line error messages, generic "something went wrong".
**Fix**: structured single-line format with module tag and clear description.

## 4. One concern per file

Files should be focused on a single responsibility. Target under 300 lines.
Large files make it hard for agents to reason about scope.

**Violation**: files over 500 lines or mixing multiple concerns.
**Fix**: split into focused files in the appropriate layer.

## 5. Stable interfaces at boundaries

Changes to shared types, schemas, or module interfaces must update all
consumers in the same PR. No breaking changes without migration.

**Violation**: changing a shared type without updating dependents.
**Fix**: include all consumer updates in the same PR.

## 6. Structured logging

Use structured log formats (JSON or key=value). Never log unstructured strings
in production code. File-based logging preferred over stdout flooding.

**Violation**: `console.log("something happened")` in production code.
**Fix**: use the project's logging utility with structured fields.

## 7. No secrets in code

Secrets, tokens, and credentials must be in `.env` (gitignored) or environment
variables. Never hardcode them.

**Violation**: API keys or passwords in source files.
**Fix**: move to environment variables, reference via config layer.

## 8. Solve the stated problem, nothing more

Do not add configuration options, abstraction layers, extension points, or
"future-proofing" that the issue doesn't call for. Every line of code must be
traceable to an acceptance criterion. Three similar lines are better than a
premature abstraction.

**Violation**: PR introduces generic framework, feature flags, or plugin
architecture when the issue asked for a single concrete feature.
**Fix**: remove the abstraction. Implement the specific thing requested. Refactor
later when a real second use case appears.

## 9. Prefer the obvious path

Given two approaches that both work, pick the one that's easier to read and
delete. Avoid clever indirection, deep nesting, and multi-layer delegation
when a flat, direct implementation is sufficient. Complexity must be justified
by a concrete requirement, not by elegance.

**Violation**: wrapper classes that delegate to a single inner class, chains of
abstractions with only one implementation, deeply nested control flow.
**Fix**: inline the indirection. Flatten the logic. A boring function that reads
top-to-bottom is better than a clever one that requires a debugger to follow.
