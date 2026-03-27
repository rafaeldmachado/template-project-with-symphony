# Testing

## Structure

```
tests/
├── e2e/              # End-to-end tests (run against preview deploys or local)
├── integration/      # Integration tests (test service boundaries)
└── structural/       # Architecture enforcement (validates layering, naming, conventions)
```

## Running tests

```bash
make test             # unit + integration tests
make test-e2e         # end-to-end tests
make structure        # structural/architecture tests
make check            # all checks (lint + structure + tests)
```

## Conventions

- **Test files** live next to the code they test OR in the corresponding tests/ subdirectory.
- **Naming**: `*.test.*` or `*_test.*` depending on your language conventions.
- **E2E tests** should be self-contained and idempotent.
- **Structural tests** are shell scripts that validate architecture invariants.
  They run in CI and must produce grep-friendly output: `ERROR: [module] description`.

## Structural tests

Structural tests enforce architecture mechanically. They are the safety net that prevents
drift across agent-generated code. Each test in `tests/structural/` is a bash script that
exits 0 on success and non-zero on failure.

When adding a structural test:
1. Write the test in `tests/structural/<name>.sh`
2. Include a clear error message with remediation instructions
3. The error message becomes agent context — make it actionable

Example:
```bash
# In a structural test error message:
echo "ERROR: [structure] File 'src/services/foo.sh' imports from 'ui/' layer."
echo "  Remediation: Services must not depend on UI. Move shared logic to 'core/'."
```
