# Dependency Layers

## The rule

Code can only depend **forward** through these layers:

```
Types → Config → Core → Services → Runtime → UI
```

A layer may import from any layer to its **left**, never to its right.

## Layer definitions

| Layer | Purpose | May depend on |
|-------|---------|---------------|
| **Types** | Shared type definitions, schemas, enums | Nothing |
| **Config** | Configuration loading, env parsing, feature flags | Types |
| **Core** | Pure business logic, domain rules, utilities | Types, Config |
| **Services** | Orchestration, external API calls, data access | Types, Config, Core |
| **Runtime** | Server setup, route handlers, middleware, CLI | Types, Config, Core, Services |
| **UI** | Frontend components, views, client-side logic | Types, Config, Core, Services, Runtime |

## Cross-cutting: Providers

Auth, telemetry, database connectors, and feature flags are **Providers**.
They are injected at the Runtime layer and passed down. They do not violate
layering because they enter through a single explicit interface.

## Enforcement

This layering is enforced by structural tests in `tests/structural/architecture.sh`.
CI will reject PRs that introduce forbidden imports.

When you see this error:
```
ERROR: [structure] Layer 'services' imports from 'ui' (forbidden)
```

The fix: move the shared logic into `core/` or pass it as a parameter from `runtime/`.

## When to add a new layer

Don't. Six layers is enough. If you think you need a seventh, you likely need a
new domain instead. Create a new directory at the domain level, not a new layer.
