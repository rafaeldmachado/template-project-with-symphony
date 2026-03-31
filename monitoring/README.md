# Monitoring

Error tracking, alerting, and dashboards for observability.

## Structure

```
monitoring/
├── alerts/
│   ├── sentry-alerts.json      # Sentry alert rules
│   ├── datadog-monitors.json   # Datadog monitor definitions
│   └── grafana-alerts.json     # Grafana alerting rules (Prometheus)
├── dashboards/
│   ├── sentry-dashboard.json   # Sentry dashboard widgets
│   ├── datadog-dashboard.json  # Datadog dashboard definition
│   └── grafana-dashboard.json  # Grafana dashboard panels (Prometheus)
└── README.md
```

After running `make init`, only the configs for your chosen provider remain.

## Setup

1. Run `make init` and choose your monitoring provider
2. The init wizard stores `MONITOR_DSN` in `.env` and as a GitHub secret
3. Non-matching provider configs are removed automatically
4. Customize the remaining alert thresholds and dashboard layouts to fit your service

## Default alert rules

### Sentry (`alerts/sentry-alerts.json`)
- **High error rate** — fires when error count > 10 in a 5-minute window
- **New issue** — fires on first occurrence of a new error type
- **Regression** — fires when a previously resolved issue recurs

### Datadog (`alerts/datadog-monitors.json`)
- **High error rate** — fires when 5xx rate exceeds 5% over 5 minutes
- **High P95 latency** — fires when P95 response time exceeds 2 seconds
- **Health check failure** — fires after 3 consecutive failed health checks

### Grafana (`alerts/grafana-alerts.json`)
- **Error rate threshold** — fires when 5xx rate exceeds 5% for 5 minutes
- **Response time P95** — fires when P95 exceeds 2 seconds for 5 minutes
- **Uptime / availability** — fires when the service is unreachable for 2 minutes

## Default dashboards

### Sentry (`dashboards/sentry-dashboard.json`)
- Error trends (24h line chart)
- Most frequent issues (top 10 table)
- Affected users (unique user count over time)
- Errors by browser
- Transaction duration P95

### Datadog (`dashboards/datadog-dashboard.json`)
- Request rate (req/s)
- Error rate (errors/s + percentage)
- Latency percentiles (P50, P90, P95, P99)
- Throughput summary
- Top endpoints by error count

### Grafana (`dashboards/grafana-dashboard.json`)
- Request rate by status code (2xx, 4xx, 5xx)
- Error rate percentage with thresholds
- Response time percentiles (P50, P90, P95, P99)
- Resource utilization (CPU, memory)
- Uptime percentage (24h)
- Active connections

## Customization

All configs are starting points. Common things to adjust:

- **Thresholds** — tune error rate, latency, and uptime thresholds for your SLOs
- **Service names** — replace `{{service}}` placeholders (Datadog) or `job` labels (Grafana)
- **Notification channels** — update `@slack-alerts`, `@pagerduty` (Datadog) or contact points (Grafana)
- **Datasource UIDs** — update `datasourceUid` fields to match your Grafana datasources

## Supported providers

- **Sentry**: Error tracking + performance monitoring
- **Datadog**: Full-stack observability
- **Grafana Cloud**: Metrics, logs, traces (Prometheus-based)
- **Custom**: Roll your own with OpenTelemetry

## Agent observability

For agent-driven development, the observability stack should be:
- **Ephemeral per worktree**: each agent instance gets its own logs/metrics
- **Queryable**: agents can search logs (LogQL) and metrics (PromQL)
- **Structured**: JSON logs with consistent field names
