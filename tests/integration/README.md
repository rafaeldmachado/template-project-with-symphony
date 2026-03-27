# Integration Tests

Integration tests validate that services and components work together correctly
at their boundaries.

## Scope

- Database queries return expected results
- API endpoints accept and return correct shapes
- Service-to-service communication works
- External API integrations behave as expected (use mocks/stubs sparingly)

## Running

```bash
make test    # runs unit + integration together
```

## Conventions

- Test real boundaries, not mocks. Mocks hide integration bugs.
- Use test databases, not production data.
- Clean up after yourself — tests must be idempotent.
- Validate data shapes at boundaries (parse, don't probe).
