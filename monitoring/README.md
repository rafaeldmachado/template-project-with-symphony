# Monitoring

Error tracking, alerting, and dashboards for observability.

## Structure

```
monitoring/
├── alerts/       # Alert rule definitions
├── dashboards/   # Dashboard configurations (Grafana JSON, Datadog YAML, etc.)
└── README.md
```

## Setup

1. Choose your monitoring provider and set `MONITOR_DSN` in `.env`
2. Add alert definitions to `monitoring/alerts/`
3. Add dashboard configs to `monitoring/dashboards/`

## Supported providers

Configure via `MONITOR_DSN` and your provider's SDK:

- **Sentry**: Error tracking + performance monitoring
- **Datadog**: Full-stack observability
- **Grafana Cloud**: Metrics, logs, traces
- **Custom**: Roll your own with OpenTelemetry

## Agent observability

For agent-driven development, the observability stack should be:
- **Ephemeral per worktree**: each agent instance gets its own logs/metrics
- **Queryable**: agents can search logs (LogQL) and metrics (PromQL)
- **Structured**: JSON logs with consistent field names

## Alerts

Define alert rules as code in `monitoring/alerts/`. Examples:

- Error rate threshold exceeded
- Latency SLO breach
- Service health check failure

## Dashboards

Store dashboard definitions as code in `monitoring/dashboards/`.
This makes them version-controlled and agent-editable.
