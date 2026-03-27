# System Design

This is the top-level design document. It provides an overview of the system's
domains, boundaries, and how they connect.

## Domains

<!-- List each business domain and its purpose. Example: -->
<!-- - **Auth**: User authentication and session management -->
<!-- - **Billing**: Subscription and payment handling -->

_TODO: Define your domains here when you start building._

## Domain Map

```
┌─────────────────────────────────────────────┐
│                  Providers                   │
│  (auth, telemetry, feature flags, connectors)│
├──────────┬──────────┬───────────┬───────────┤
│ Domain A │ Domain B │ Domain C  │    ...    │
│          │          │           │           │
│ Types    │ Types    │ Types     │           │
│ Config   │ Config   │ Config    │           │
│ Core     │ Core     │ Core      │           │
│ Services │ Services │ Services  │           │
│ Runtime  │ Runtime  │ Runtime   │           │
│ UI       │ UI       │ UI        │           │
└──────────┴──────────┴───────────┴───────────┘
```

Each domain follows the same layer structure. See [architecture/layers.md](architecture/layers.md)
for the dependency rules.

## Cross-cutting concerns

Cross-cutting concerns (auth, telemetry, feature flags, database connectors)
enter through **Providers** — a single explicit interface at the top of each domain.
Direct cross-domain imports are not allowed.

## Key documents

| Document | Purpose |
|----------|---------|
| [architecture/layers.md](architecture/layers.md) | Dependency layer rules |
| [design-docs/golden-principles.md](design-docs/golden-principles.md) | Non-negotiable engineering rules |
| [design-docs/core-beliefs.md](design-docs/core-beliefs.md) | Agent-first operating principles |
| [QUALITY_SCORE.md](QUALITY_SCORE.md) | Quality grades by domain |
| [PLANS.md](PLANS.md) | Active and completed execution plans |
| [exec-plans/tech-debt-tracker.md](exec-plans/tech-debt-tracker.md) | Known technical debt |
