#!/usr/bin/env bash
set -euo pipefail

# Disable pager for gh CLI so commands never open vi/less
export GH_PAGER=""

# Ensure sane terminal settings (backspace, line editing)
# Needed when launched from shells with custom configs (oh-my-zsh, etc.)
stty sane 2>/dev/null || true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Project initialization wizard
#
# Interactive setup that configures the template for a
# new project: stack, GitHub, deploys, agent, monitoring.
#
# Usage: make init
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Colors and formatting ────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${RESET}\n"; }
info()   { echo -e "${DIM}$1${RESET}"; }
ok()     { echo -e "${GREEN}✓${RESET} $1"; }
warn()   { echo -e "${YELLOW}!${RESET} $1"; }
fail()   { echo -e "${RED}✗${RESET} $1"; }

# ── Prompt helpers ───────────────────────────────────

ask() {
  local prompt="$1" default="${2:-}"
  if [ -n "$default" ]; then
    echo -en "${BOLD}$prompt${RESET} ${DIM}[$default]${RESET}: " >&2
  else
    echo -en "${BOLD}$prompt${RESET}: " >&2
  fi
  read -r answer
  echo "${answer:-$default}"
}

confirm() {
  local prompt="$1" default="${2:-y}"
  if [ "$default" = "y" ]; then
    echo -en "${BOLD}$prompt${RESET} ${DIM}[Y/n]${RESET}: " >&2
  else
    echo -en "${BOLD}$prompt${RESET} ${DIM}[y/N]${RESET}: " >&2
  fi
  read -r answer
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy] ]]
}

choose() {
  local prompt="$1"
  shift
  local options=("$@")
  echo -e "${BOLD}$prompt${RESET}" >&2
  for i in "${!options[@]}"; do
    echo -e "  ${CYAN}$((i + 1)))${RESET} ${options[$i]}" >&2
  done
  while true; do
    echo -en "${DIM}Enter number: ${RESET}" >&2
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
      echo "${options[$((choice - 1))]}"
      return
    fi
    echo -e "${RED}Invalid choice. Pick 1-${#options[@]}.${RESET}" >&2
  done
}

# ── State ────────────────────────────────────────────
PROJECT_NAME=""
STACK=""
LINTER_CMD=""
TEST_CMD=""
E2E_CMD=""
SETUP_CMD=""
CI_SETUP_STEPS=""
PKG_INIT_CMD=""
DEPLOY_PROVIDER=""
DEPLOY_MODE=""
AGENT_CHOICE=""
MONITOR_CHOICE=""
CREATE_PROJECT=false
PROJECT_BOARD_URL=""
PROJECT_NUMBER=""
DB_ENGINE=""
DB_ENGINE_CHOICE=""
DB_ORM=""
DB_ORM_CHOICE=""
DB_HOSTING=""
DB_HOSTING_CHOICE=""
DATABASE_URL=""
DB_CLOUD_PROVIDER=""
DB_API_KEY=""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BOLD}"
echo "  ┌─────────────────────────────────────┐"
echo "  │  Project Initialization Wizard      │"
echo "  │  AI-first development template      │"
echo "  └─────────────────────────────────────┘"
echo -e "${RESET}"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "1/8  Project basics"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PROJECT_NAME=$(ask "Project name" "$(basename "$ROOT_DIR")")
PROJECT_DESC=$(ask "One-line description" "")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "2/8  Stack"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STACK_CATEGORY=$(choose "Choose a category:" \
  "Fullstack (unified — single framework handles front + back)" \
  "Fullstack (split — separate backend and frontend)" \
  "Backend / API only" \
  "Frontend only" \
  "None / I'll configure later")

STACK=""
BACKEND_STACK=""
FRONTEND_STACK=""
IS_FULLSTACK=false

case "$STACK_CATEGORY" in
  "Fullstack (unified — single framework handles front + back)")
    STACK=$(choose "Choose a framework:" \
      "Next.js (React)" \
      "Nuxt (Vue)" \
      "SvelteKit" \
      "Remix" \
      "Astro" \
      "Rails" \
      "Phoenix" \
      "Django")
    ;;
  "Fullstack (split — separate backend and frontend)")
    IS_FULLSTACK=true

    info "Pick your backend API:"
    BACKEND_STACK=$(choose "Backend:" \
      "FastAPI" \
      "Django" \
      "Flask" \
      "Hono (API)" \
      "Express (TypeScript)" \
      "Go" \
      "Axum (API)" \
      "Rails" \
      "Phoenix" \
      "Spring Boot (Kotlin)" \
      "Spring Boot (Java)")

    echo ""
    info "Pick your frontend:"
    FRONTEND_STACK=$(choose "Frontend:" \
      "Next.js (React)" \
      "SvelteKit" \
      "Nuxt (Vue)" \
      "Astro" \
      "Remix")

    STACK="${BACKEND_STACK} + ${FRONTEND_STACK}"
    ;;
  "Backend / API only")
    STACK=$(choose "Choose a framework:" \
      "FastAPI" \
      "Django" \
      "Flask" \
      "Hono (API)" \
      "Express (TypeScript)" \
      "Go" \
      "Axum (API)" \
      "Rails" \
      "Phoenix" \
      "Spring Boot (Kotlin)" \
      "Spring Boot (Java)" \
      "Node.js (TypeScript, no framework)" \
      "Node.js (JavaScript, no framework)" \
      "Rust (no framework)" \
      "Elixir (no framework)" \
      "Ruby (no framework)" \
      "Python (no framework)")
    ;;
  "Frontend only")
    STACK=$(choose "Choose a framework:" \
      "Next.js (React)" \
      "SvelteKit" \
      "Nuxt (Vue)" \
      "Astro" \
      "Remix")
    ;;
  *)
    STACK="None"
    ;;
esac

# ── Shared CI setup blocks ────────────────────────────
NODE_CI_STEPS='      - uses: actions/setup-node@v4
        with:
          node-version: "22"
      - run: if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'

PYTHON_CI_STEPS='      - uses: actions/setup-python@v5
        with:
          python-version: "3.13"
      - run: if [ -f requirements.txt ]; then pip install -r requirements.txt; fi'

GO_CI_STEPS='      - uses: actions/setup-go@v5
        with:
          go-version: "1.24"
      - run: if [ -f go.mod ]; then go mod download; fi'

RUST_CI_STEPS='      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt
      - run: if [ -f Cargo.toml ]; then cargo fetch; fi'

ELIXIR_CI_STEPS='      - uses: erlef/setup-beam@v1
        with:
          otp-version: "27"
          elixir-version: "1.18"
      - run: if [ -f mix.exs ]; then mix deps.get; fi'

RUBY_CI_STEPS='      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.3"
          bundler-cache: true
      - run: if [ -f Gemfile ]; then bundle install; fi'

JAVA_CI_STEPS='      - uses: actions/setup-java@v4
        with:
          distribution: "temurin"
          java-version: "21"
      - run: if [ -f gradlew ]; then ./gradlew dependencies; fi'

# ── generate_monitoring_sdk: emits SDK init files, adds deps, updates README
#    Args: $1=provider (sentry|datadog|grafana)  $2=family (node|python|go|…)
#         $3=framework name  $4=target dir (ROOT_DIR or ROOT_DIR/backend)
generate_monitoring_sdk() {
  local provider="$1" family="$2" framework="$3" target="$4"
  local monitor_dir="$target/monitoring"

  mkdir -p "$monitor_dir"

  case "$provider" in
    # ─────────────────────── SENTRY ───────────────────────
    sentry)
      case "$family" in
        node)
          # Determine the right Sentry package
          local sentry_pkg="@sentry/node"
          [[ "$framework" == "Next.js"* ]] && sentry_pkg="@sentry/nextjs"

          cat > "$target/sentry.config.ts" <<'SENTRY_NODE_EOF'
import * as Sentry from "__SENTRY_PKG__";

Sentry.init({
  dsn: process.env.MONITOR_DSN,
  tracesSampleRate: 1.0,
  environment: process.env.NODE_ENV || "development",
});

export default Sentry;
SENTRY_NODE_EOF
          sed -i.bak "s|__SENTRY_PKG__|${sentry_pkg}|g" "$target/sentry.config.ts"
          rm -f "$target/sentry.config.ts.bak"

          # Add dependency to package.json if it exists
          if [ -f "$target/package.json" ]; then
            cd "$target" && npm install --save "$sentry_pkg" 2>/dev/null && cd "$ROOT_DIR" || true
          fi
          ok "Generated sentry.config.ts (${sentry_pkg})"
          ;;

        python)
          # Determine framework integration
          local py_integration=""
          case "$framework" in
            FastAPI*) py_integration='from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.starlette import StarletteIntegration

INTEGRATIONS = [FastApiIntegration(), StarletteIntegration()]' ;;
            Django*)  py_integration='from sentry_sdk.integrations.django import DjangoIntegration

INTEGRATIONS = [DjangoIntegration()]' ;;
            Flask*)   py_integration='from sentry_sdk.integrations.flask import FlaskIntegration

INTEGRATIONS = [FlaskIntegration()]' ;;
            *)        py_integration='INTEGRATIONS = []' ;;
          esac

          cat > "$target/sentry_config.py" <<SENTRY_PY_EOF
import os
import sentry_sdk

${py_integration}

sentry_sdk.init(
    dsn=os.environ["MONITOR_DSN"],
    traces_sample_rate=1.0,
    integrations=INTEGRATIONS,
    environment=os.environ.get("ENVIRONMENT", "development"),
)
SENTRY_PY_EOF

          # Add dependency
          if [ -f "$target/requirements.txt" ]; then
            grep -q 'sentry-sdk' "$target/requirements.txt" || echo 'sentry-sdk' >> "$target/requirements.txt"
          fi
          ok "Generated sentry_config.py"
          ;;

        go)
          cat > "$target/sentry.go" <<'SENTRY_GO_EOF'
package main

import (
	"log"
	"os"
	"time"

	"github.com/getsentry/sentry-go"
)

func InitSentry() {
	err := sentry.Init(sentry.ClientOptions{
		Dsn:              os.Getenv("MONITOR_DSN"),
		TracesSampleRate: 1.0,
		Environment:      os.Getenv("ENVIRONMENT"),
	})
	if err != nil {
		log.Fatalf("sentry.Init: %s", err)
	}
	defer sentry.Flush(2 * time.Second)
}
SENTRY_GO_EOF

          if [ -f "$target/go.mod" ]; then
            cd "$target" && go get github.com/getsentry/sentry-go 2>/dev/null && cd "$ROOT_DIR" || true
          fi
          ok "Generated sentry.go"
          ;;

        *)
          cat > "$monitor_dir/SETUP.md" <<SENTRY_OTHER_EOF
# Sentry SDK Setup

Your stack ($framework) needs manual Sentry SDK setup.

1. Install the Sentry SDK for your language
2. Initialize it with:
   \`\`\`
   dsn = os.environ["MONITOR_DSN"]  # or your language's equivalent
   \`\`\`
3. See https://docs.sentry.io/platforms/ for framework-specific guides
SENTRY_OTHER_EOF
          ok "Generated monitoring/SETUP.md (manual Sentry setup instructions)"
          ;;
      esac
      ;;

    # ─────────────────────── DATADOG ──────────────────────
    datadog)
      case "$family" in
        node)
          cat > "$target/dd-trace.config.ts" <<'DD_NODE_EOF'
import tracer from "dd-trace";

tracer.init({
  env: process.env.NODE_ENV || "development",
  logInjection: true,
});

export default tracer;
DD_NODE_EOF

          if [ -f "$target/package.json" ]; then
            cd "$target" && npm install --save dd-trace 2>/dev/null && cd "$ROOT_DIR" || true
          fi
          ok "Generated dd-trace.config.ts"
          ;;

        python)
          cat > "$target/ddtrace_config.py" <<'DD_PY_EOF'
import os
from ddtrace import config, tracer

config.env = os.environ.get("ENVIRONMENT", "development")

# Auto-instrumentation patches supported libraries on import.
# Run your app with: ddtrace-run python app.py
# Or import this module early in your entry point.

tracer.configure(
    hostname=os.environ.get("DD_AGENT_HOST", "localhost"),
    port=int(os.environ.get("DD_TRACE_AGENT_PORT", "8126")),
)
DD_PY_EOF

          if [ -f "$target/requirements.txt" ]; then
            grep -q 'ddtrace' "$target/requirements.txt" || echo 'ddtrace' >> "$target/requirements.txt"
          fi
          ok "Generated ddtrace_config.py"
          ;;

        go)
          cat > "$target/ddtrace.go" <<'DD_GO_EOF'
package main

import (
	"os"

	"gopkg.in/DataDog/dd-trace-go.v1/ddtrace/tracer"
)

func InitDatadog() {
	tracer.Start(
		tracer.WithEnv(os.Getenv("ENVIRONMENT")),
		tracer.WithAnalytics(true),
	)
}

func StopDatadog() {
	tracer.Stop()
}
DD_GO_EOF

          if [ -f "$target/go.mod" ]; then
            cd "$target" && go get gopkg.in/DataDog/dd-trace-go.v1 2>/dev/null && cd "$ROOT_DIR" || true
          fi
          ok "Generated ddtrace.go"
          ;;

        *)
          cat > "$monitor_dir/SETUP.md" <<DD_OTHER_EOF
# Datadog SDK Setup

Your stack ($framework) needs manual Datadog setup.

1. Install the Datadog tracing library for your language
2. Set DD_API_KEY to your MONITOR_DSN value
3. See https://docs.datadoghq.com/tracing/setup_overview/ for guides
DD_OTHER_EOF
          ok "Generated monitoring/SETUP.md (manual Datadog setup instructions)"
          ;;
      esac
      ;;

    # ─────────────────────── GRAFANA (OpenTelemetry) ──────
    grafana)
      case "$family" in
        node)
          cat > "$target/otel.config.ts" <<'OTEL_NODE_EOF'
import { NodeSDK } from "@opentelemetry/sdk-node";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { OTLPMetricExporter } from "@opentelemetry/exporter-metrics-otlp-http";
import { PeriodicExportingMetricReader } from "@opentelemetry/sdk-metrics";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";

const traceExporter = new OTLPTraceExporter({
  url: process.env.MONITOR_DSN
    ? `${process.env.MONITOR_DSN}/v1/traces`
    : "http://localhost:4318/v1/traces",
});

const metricExporter = new OTLPMetricExporter({
  url: process.env.MONITOR_DSN
    ? `${process.env.MONITOR_DSN}/v1/metrics`
    : "http://localhost:4318/v1/metrics",
});

const sdk = new NodeSDK({
  traceExporter,
  metricReader: new PeriodicExportingMetricReader({ exporter: metricExporter }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

process.on("SIGTERM", () => sdk.shutdown());

export default sdk;
OTEL_NODE_EOF

          if [ -f "$target/package.json" ]; then
            cd "$target" && npm install --save \
              @opentelemetry/sdk-node \
              @opentelemetry/exporter-trace-otlp-http \
              @opentelemetry/exporter-metrics-otlp-http \
              @opentelemetry/sdk-metrics \
              @opentelemetry/auto-instrumentations-node \
              2>/dev/null && cd "$ROOT_DIR" || true
          fi
          ok "Generated otel.config.ts (OpenTelemetry → Grafana)"
          ;;

        python)
          cat > "$target/otel_config.py" <<'OTEL_PY_EOF'
import os
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter

endpoint = os.environ.get("MONITOR_DSN", "http://localhost:4318")

# Traces
trace_provider = TracerProvider()
trace_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=f"{endpoint}/v1/traces"))
)
trace.set_tracer_provider(trace_provider)

# Metrics
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint=f"{endpoint}/v1/metrics")
)
metrics.set_meter_provider(MeterProvider(metric_readers=[metric_reader]))
OTEL_PY_EOF

          if [ -f "$target/requirements.txt" ]; then
            for pkg in opentelemetry-sdk opentelemetry-exporter-otlp-proto-http opentelemetry-api; do
              grep -q "$pkg" "$target/requirements.txt" || echo "$pkg" >> "$target/requirements.txt"
            done
          fi
          ok "Generated otel_config.py (OpenTelemetry → Grafana)"
          ;;

        go)
          cat > "$target/otel.go" <<'OTEL_GO_EOF'
package main

import (
	"context"
	"log"
	"os"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

func InitOtel(ctx context.Context, serviceName string) func() {
	endpoint := os.Getenv("MONITOR_DSN")
	if endpoint == "" {
		endpoint = "http://localhost:4318"
	}

	exporter, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpoint(endpoint),
	)
	if err != nil {
		log.Fatalf("failed to create OTLP exporter: %v", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceNameKey.String(serviceName),
		)),
	)
	otel.SetTracerProvider(tp)

	return func() { _ = tp.Shutdown(ctx) }
}
OTEL_GO_EOF

          if [ -f "$target/go.mod" ]; then
            cd "$target" && go get \
              go.opentelemetry.io/otel \
              go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp \
              go.opentelemetry.io/otel/sdk \
              2>/dev/null && cd "$ROOT_DIR" || true
          fi
          ok "Generated otel.go (OpenTelemetry → Grafana)"
          ;;

        *)
          cat > "$monitor_dir/SETUP.md" <<OTEL_OTHER_EOF
# OpenTelemetry SDK Setup (Grafana)

Your stack ($framework) needs manual OpenTelemetry setup.

1. Install the OpenTelemetry SDK for your language
2. Configure the OTLP HTTP exporter to point at:
   \`\`\`
   endpoint = os.environ["MONITOR_DSN"]  # your Grafana OTLP endpoint
   \`\`\`
3. See https://opentelemetry.io/docs/languages/ for language-specific guides
OTEL_OTHER_EOF
          ok "Generated monitoring/SETUP.md (manual OpenTelemetry setup instructions)"
          ;;
      esac
      ;;
  esac

  # ── Update monitoring/README.md with provider-specific setup ──
  local provider_label=""
  local setup_notes=""
  case "$provider" in
    sentry)
      provider_label="Sentry"
      setup_notes="- DSN is read from \`MONITOR_DSN\` environment variable
- Import the generated config file at your application's entry point
- Errors and performance data will be sent to your Sentry project automatically"
      ;;
    datadog)
      provider_label="Datadog"
      setup_notes="- API key is read from \`MONITOR_DSN\` environment variable
- For Node.js: import \`dd-trace.config.ts\` before any other imports
- For Python: run your app with \`ddtrace-run\` or import \`ddtrace_config\` early
- For Go: call \`InitDatadog()\` at startup and \`defer StopDatadog()\`"
      ;;
    grafana)
      provider_label="Grafana Cloud (OpenTelemetry)"
      setup_notes="- OTLP endpoint is read from \`MONITOR_DSN\` environment variable
- Import the generated OTel config at your application's entry point
- Traces and metrics are exported via OTLP HTTP to your Grafana endpoint"
      ;;
  esac

  cat > "$ROOT_DIR/monitoring/README.md" <<MONITOR_README_EOF
# Monitoring

Error tracking, alerting, and dashboards for observability.

## Active Provider: ${provider_label}

**Stack:** ${framework}

### Setup

${setup_notes}

### Smoke Test

Run a test event to verify your monitoring pipeline:

\`\`\`bash
make monitor-test
\`\`\`

### Environment Variables

| Variable       | Description                          | Required |
|---------------|--------------------------------------|----------|
| \`MONITOR_DSN\` | ${provider_label} DSN / API key / endpoint | Yes      |

## Structure

\`\`\`
monitoring/
├── alerts/       # Alert rule definitions
├── dashboards/   # Dashboard configurations
└── README.md
\`\`\`

## Alerts

Define alert rules as code in \`monitoring/alerts/\`.

## Dashboards

Store dashboard definitions as code in \`monitoring/dashboards/\`.
MONITOR_README_EOF
  ok "Updated monitoring/README.md for ${provider_label}"
}

# ── generate_database_layer: emits ORM config, models, migrations, seeds,
#    connection helpers, integration test, Makefile targets, and db/README.md
#    Args: $1=orm  $2=engine  $3=lang  $4=target dir  $5=framework name
#
#    Each _gen_* helper sets these variables for the orchestrator:
#      _DB_LABEL  _DB_DOCS  _DB_MIGRATE  _DB_SEED  _DB_RESET  _DB_STUDIO
#      _DB_ADD_STEPS (how to add new models)
# ─────────────────────────────────────────────────────────────────────────

_db_vars() {
  # Set orchestrator variables. Args: label docs migrate seed reset studio add_steps
  _DB_LABEL="$1"; _DB_DOCS="$2"; _DB_MIGRATE="$3"; _DB_SEED="$4"
  _DB_RESET="$5"; _DB_STUDIO="$6"; _DB_ADD_STEPS="$7"
}

_gen_prisma() {
  local engine="$1" target="$2"
  local provider=""; case "$engine" in
    postgres) provider="postgresql" ;; mysql) provider="mysql" ;;
    sqlite) provider="sqlite" ;; mongodb) provider="mongodb" ;; esac

  local id_field='id        Int      @id @default(autoincrement())'
  [ "$engine" = "mongodb" ] && id_field='id        String   @id @default(auto()) @map("_id") @db.ObjectId'

  mkdir -p "$target/prisma"
  cat > "$target/prisma/schema.prisma" <<PRISMA_EOF
generator client { provider = "prisma-client-js" }

datasource db {
  provider = "${provider}"
  url      = env("DATABASE_URL")
}

model User {
  ${id_field}
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
PRISMA_EOF

  cat > "$target/db.ts" <<'EOF'
import { PrismaClient } from "@prisma/client";
const g = globalThis as unknown as { prisma: PrismaClient };
export const prisma = g.prisma || new PrismaClient();
if (process.env.NODE_ENV !== "production") g.prisma = prisma;
export default prisma;
EOF

  cat > "$target/prisma/seed.ts" <<'EOF'
import { prisma } from "../db";
async function main() {
  await prisma.user.upsert({
    where: { email: "admin@example.com" },
    update: {},
    create: { email: "admin@example.com", name: "Admin User" },
  });
}
main().then(() => prisma.$disconnect()).catch((e) => { console.error(e); process.exit(1); });
EOF

  if [ -f "$target/package.json" ]; then
    cd "$target"
    npm install @prisma/client 2>/dev/null || true
    npm install -D prisma tsx 2>/dev/null || true
    npm pkg set scripts.db:migrate="prisma migrate dev" scripts.db:push="prisma db push" \
      scripts.db:seed="tsx prisma/seed.ts" scripts.db:studio="prisma studio" \
      scripts.db:reset="prisma migrate reset" prisma.seed="tsx prisma/seed.ts" 2>/dev/null || true
    cd "$ROOT_DIR"
  fi
  ok "Generated Prisma setup (schema, client, seed)"

  _db_vars "Prisma" "https://www.prisma.io/docs" \
    "npx prisma migrate dev" "npx prisma db seed" \
    "npx prisma migrate reset --force" "npx prisma studio" \
    "Edit prisma/schema.prisma, run npx prisma migrate dev --name <name>"
}

_gen_drizzle() {
  local engine="$1" target="$2"
  local dialect="" driver_pkg=""
  case "$engine" in
    postgres) dialect="postgresql"; driver_pkg="postgres" ;;
    mysql)    dialect="mysql";      driver_pkg="mysql2" ;;
    sqlite)   dialect="sqlite";     driver_pkg="better-sqlite3 @types/better-sqlite3" ;;
  esac

  mkdir -p "$target/db"
  cat > "$target/drizzle.config.ts" <<DCFG
import { defineConfig } from "drizzle-kit";
export default defineConfig({
  out: "./drizzle", schema: "./db/schema.ts", dialect: "${dialect}",
  dbCredentials: { url: process.env.DATABASE_URL! },
});
DCFG

  case "$engine" in
    postgres) cat > "$target/db/schema.ts" <<'EOF'
import { pgTable, serial, text, timestamp } from "drizzle-orm/pg-core";
export const users = pgTable("users", {
  id: serial("id").primaryKey(), email: text("email").notNull().unique(),
  name: text("name"), createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});
EOF
      cat > "$target/db/index.ts" <<'EOF'
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";
export const db = drizzle(postgres(process.env.DATABASE_URL!), { schema });
EOF
      ;;
    mysql) cat > "$target/db/schema.ts" <<'EOF'
import { mysqlTable, serial, varchar, timestamp } from "drizzle-orm/mysql-core";
export const users = mysqlTable("users", {
  id: serial("id").primaryKey(), email: varchar("email", { length: 255 }).notNull().unique(),
  name: varchar("name", { length: 255 }), createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});
EOF
      cat > "$target/db/index.ts" <<'EOF'
import { drizzle } from "drizzle-orm/mysql2";
import mysql from "mysql2/promise";
import * as schema from "./schema";
const connection = await mysql.createConnection(process.env.DATABASE_URL!);
export const db = drizzle(connection, { schema });
EOF
      ;;
    sqlite) cat > "$target/db/schema.ts" <<'EOF'
import { sqliteTable, integer, text } from "drizzle-orm/sqlite-core";
import { sql } from "drizzle-orm";
export const users = sqliteTable("users", {
  id: integer("id").primaryKey({ autoIncrement: true }), email: text("email").notNull().unique(),
  name: text("name"), createdAt: text("created_at").default(sql`(CURRENT_TIMESTAMP)`).notNull(),
  updatedAt: text("updated_at").default(sql`(CURRENT_TIMESTAMP)`).notNull(),
});
EOF
      cat > "$target/db/index.ts" <<'EOF'
import { drizzle } from "drizzle-orm/better-sqlite3";
import Database from "better-sqlite3";
import * as schema from "./schema";
export const db = drizzle(new Database(process.env.DATABASE_URL!.replace("file:", "")), { schema });
EOF
      ;;
  esac

  cat > "$target/db/seed.ts" <<'EOF'
import { db } from "./index";
import { users } from "./schema";
await db.insert(users).values({ email: "admin@example.com", name: "Admin User" });
console.log("Seeded users table.");
EOF

  if [ -f "$target/package.json" ]; then
    cd "$target"
    npm install drizzle-orm $driver_pkg 2>/dev/null || true
    npm install -D drizzle-kit tsx 2>/dev/null || true
    npm pkg set scripts.db:migrate="drizzle-kit push" scripts.db:generate="drizzle-kit generate" \
      scripts.db:seed="tsx db/seed.ts" scripts.db:studio="drizzle-kit studio" 2>/dev/null || true
    cd "$ROOT_DIR"
  fi
  ok "Generated Drizzle setup (config, schema, client, seed)"

  _db_vars "Drizzle" "https://orm.drizzle.team/docs/overview" \
    "npx drizzle-kit push" "npx tsx db/seed.ts" \
    "npx drizzle-kit push --force" "npx drizzle-kit studio" \
    "Add table in db/schema.ts, run npx drizzle-kit generate && npx drizzle-kit push"
}

_gen_mongoose() {
  local target="$1"
  mkdir -p "$target/db" "$target/models"

  cat > "$target/db/connection.ts" <<'EOF'
import mongoose from "mongoose";
const cached = (globalThis as any).__mongo || ((globalThis as any).__mongo = { conn: null });
export async function connectDB() {
  if (cached.conn) return cached.conn;
  cached.conn = await mongoose.connect(process.env.DATABASE_URL!);
  return cached.conn;
}
EOF

  cat > "$target/models/User.ts" <<'EOF'
import mongoose, { Schema } from "mongoose";
const UserSchema = new Schema(
  { email: { type: String, required: true, unique: true }, name: String },
  { timestamps: true }
);
export const User = mongoose.models.User || mongoose.model("User", UserSchema);
EOF

  cat > "$target/db/seed.ts" <<'EOF'
import { connectDB } from "./connection";
import { User } from "../models/User";
await connectDB();
await User.findOneAndUpdate({ email: "admin@example.com" },
  { email: "admin@example.com", name: "Admin User" }, { upsert: true });
console.log("Seeded User collection.");
process.exit(0);
EOF

  if [ -f "$target/package.json" ]; then
    cd "$target"
    npm install mongoose 2>/dev/null || true
    npm install -D tsx 2>/dev/null || true
    npm pkg set scripts.db:seed="tsx db/seed.ts" 2>/dev/null || true
    cd "$ROOT_DIR"
  fi
  ok "Generated Mongoose setup (connection, model, seed)"

  _db_vars "Mongoose" "https://mongoosejs.com/docs/guide.html" \
    "echo 'MongoDB is schema-less — no migrations needed'" "npx tsx db/seed.ts" \
    "npx tsx db/seed.ts" "echo 'Use MongoDB Compass or mongosh'" \
    "Create schema in models/, export the model — MongoDB creates collections on first write"
}

_gen_sqlalchemy() {
  local engine="$1" target="$2"
  local pip_driver=""
  case "$engine" in
    postgres) pip_driver="psycopg2-binary" ;; mysql) pip_driver="pymysql" ;;
  esac

  mkdir -p "$target/app/models" "$target/alembic/versions"

  cat > "$target/app/db.py" <<'EOF'
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

engine = create_engine(os.environ["DATABASE_URL"], pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()
EOF

  cat > "$target/app/models/__init__.py" <<'EOF'
from .base import Base
from .user import User
__all__ = ["Base", "User"]
EOF

  cat > "$target/app/models/base.py" <<'EOF'
from sqlalchemy.orm import DeclarativeBase
class Base(DeclarativeBase): pass
EOF

  cat > "$target/app/models/user.py" <<'EOF'
from datetime import datetime
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column
from .base import Base

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    name: Mapped[str | None] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(default=datetime.utcnow, onupdate=datetime.utcnow)
EOF

  cat > "$target/alembic.ini" <<'EOF'
[alembic]
script_location = alembic
sqlalchemy.url =
EOF

  cat > "$target/alembic/env.py" <<'EOF'
import os
from sqlalchemy import engine_from_config, pool
from alembic import context

config = context.config
config.set_main_option("sqlalchemy.url", os.environ["DATABASE_URL"])

from app.models import Base
target_metadata = Base.metadata

def run_migrations_offline():
    context.configure(url=config.get_main_option("sqlalchemy.url"),
                      target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction(): context.run_migrations()

def run_migrations_online():
    connectable = engine_from_config(config.get_section(config.config_ini_section, {}),
                                     prefix="sqlalchemy.", poolclass=pool.NullPool)
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction(): context.run_migrations()

if context.is_offline_mode(): run_migrations_offline()
else: run_migrations_online()
EOF

  cat > "$target/app/seed.py" <<'EOF'
"""Run with: python -m app.seed"""
from app.db import SessionLocal
from app.models.user import User

db = SessionLocal()
if not db.query(User).filter_by(email="admin@example.com").first():
    db.add(User(email="admin@example.com", name="Admin User"))
    db.commit()
    print("Seeded admin user.")
db.close()
EOF

  if [ -f "$target/requirements.txt" ]; then
    for pkg in sqlalchemy alembic $pip_driver; do
      [ -z "$pkg" ] && continue
      grep -q "$pkg" "$target/requirements.txt" || echo "$pkg" >> "$target/requirements.txt"
    done
  fi
  ok "Generated SQLAlchemy + Alembic setup"

  _db_vars "SQLAlchemy + Alembic" "https://docs.sqlalchemy.org/en/20/" \
    "alembic upgrade head" "python -m app.seed" \
    "alembic downgrade base && alembic upgrade head" \
    "echo 'Use pgAdmin, DBeaver, or your database CLI'" \
    "Create model in app/models/, import in __init__.py, run alembic revision --autogenerate -m '<desc>'"
}

_gen_django_orm() {
  local engine="$1" target="$2"
  local dj_driver=""
  case "$engine" in postgres) dj_driver="psycopg2-binary" ;; mysql) dj_driver="mysqlclient" ;; esac

  mkdir -p "$target/config"
  cat > "$target/config/db_settings.py" <<'EOF'
"""Import in settings.py: from config.db_settings import DATABASES"""
import dj_database_url
DATABASES = {"default": dj_database_url.config(default="sqlite:///db.sqlite3",
             conn_max_age=600, conn_health_checks=True)}
EOF

  # Try to patch settings.py if it exists
  if [ -f "$target/config/settings.py" ] && grep -q 'DATABASES' "$target/config/settings.py"; then
    sed -i.bak '/^DATABASES/,/^}/d' "$target/config/settings.py"
    echo 'from config.db_settings import DATABASES  # noqa: F401' >> "$target/config/settings.py"
    rm -f "$target/config/settings.py.bak"
    ok "Patched config/settings.py to use dj-database-url"
  else
    ok "Generated config/db_settings.py"
  fi

  if [ -f "$target/requirements.txt" ]; then
    for pkg in dj-database-url $dj_driver; do
      [ -z "$pkg" ] && continue
      grep -q "$pkg" "$target/requirements.txt" || echo "$pkg" >> "$target/requirements.txt"
    done
  fi

  _db_vars "Django ORM" "https://docs.djangoproject.com/en/5.0/topics/db/" \
    "python manage.py migrate" "python manage.py loaddata seed" \
    "python manage.py flush --no-input && python manage.py migrate" \
    "python manage.py dbshell" \
    "Add model in app/models.py, run python manage.py makemigrations && migrate"
}

_gen_gorm() {
  local engine="$1" target="$2"
  local driver_import="" dial_func="" go_driver=""
  case "$engine" in
    postgres) driver_import="gorm.io/driver/postgres"; dial_func="postgres.Open(dsn)"; go_driver="$driver_import" ;;
    mysql)    driver_import="gorm.io/driver/mysql";    dial_func="mysql.Open(dsn)";    go_driver="$driver_import" ;;
    sqlite)   driver_import="gorm.io/driver/sqlite";   dial_func="sqlite.Open(dsn)";   go_driver="$driver_import" ;;
  esac

  mkdir -p "$target/db" "$target/models"

  cat > "$target/db/db.go" <<GORM_EOF
package db

import (
	"log"
	"os"
	"gorm.io/gorm"
	"${driver_import}"
)

var DB *gorm.DB

func Connect() *gorm.DB {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" { log.Fatal("DATABASE_URL environment variable is not set") }
	var err error
	DB, err = gorm.Open(${dial_func}, &gorm.Config{})
	if err != nil { log.Fatalf("failed to connect to database: %v", err) }
	return DB
}
GORM_EOF

  cat > "$target/models/user.go" <<'EOF'
package models
import "time"
type User struct {
	ID    uint    `gorm:"primaryKey" json:"id"`
	Email string  `gorm:"uniqueIndex;not null;size:255" json:"email"`
	Name  *string `gorm:"size:255" json:"name,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
EOF

  cat > "$target/db/migrate.go" <<'EOF'
package db
import ("log"; "__MODULE__/models")
func Migrate() {
	if DB == nil { log.Fatal("call Connect() first") }
	if err := DB.AutoMigrate(&models.User{}); err != nil { log.Fatalf("migrate: %v", err) }
	log.Println("migration complete")
}
EOF

  if [ -f "$target/go.mod" ]; then
    local mod; mod=$(head -1 "$target/go.mod" | awk '{print $2}')
    sed -i.bak "s|__MODULE__|${mod}|g" "$target/db/migrate.go"
    rm -f "$target/db/migrate.go.bak"
    cd "$target" && go get gorm.io/gorm "$go_driver" 2>/dev/null && cd "$ROOT_DIR" || true
  fi
  ok "Generated GORM setup (connection, model, migrate)"

  _db_vars "GORM" "https://gorm.io/docs/" \
    "go run ./cmd/migrate" "go run ./cmd/seed" \
    "echo 'Drop DB and re-run: make db-migrate && make db-seed'" \
    "echo 'Use pgAdmin, DBeaver, or your database CLI'" \
    "Create struct in models/, add to AutoMigrate() in db/migrate.go"
}

_gen_activerecord() {
  local engine="$1" target="$2"
  local adapter="" gem=""
  case "$engine" in postgres) adapter="postgresql"; gem="pg" ;; mysql) adapter="mysql2"; gem="mysql2" ;; sqlite) adapter="sqlite3"; gem="sqlite3" ;; esac

  mkdir -p "$target/config" "$target/db/migrate" "$target/app/models"
  cat > "$target/config/database.yml" <<AR_EOF
default: &default
  adapter: ${adapter}
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
development: { <<: *default, url: "<%= ENV['DATABASE_URL'] %>" }
test:        { <<: *default, url: "<%= ENV['DATABASE_URL'] %>_test" }
production:  { <<: *default, url: "<%= ENV['DATABASE_URL'] %>" }
AR_EOF

  cat > "$target/db/migrate/001_create_users.rb" <<'EOF'
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
EOF

  echo 'class User < ApplicationRecord; validates :email, presence: true, uniqueness: true; end' \
    > "$target/app/models/user.rb"

  cat > "$target/db/seeds.rb" <<'EOF'
User.find_or_create_by!(email: "admin@example.com") { |u| u.name = "Admin User" }
puts "Seeded admin user."
EOF

  [ -f "$target/Gemfile" ] && ! grep -q "'${gem}'" "$target/Gemfile" && echo "gem '${gem}'" >> "$target/Gemfile"
  ok "Generated ActiveRecord setup"

  _db_vars "ActiveRecord" "https://guides.rubyonrails.org/active_record_basics.html" \
    "bundle exec rails db:migrate" "bundle exec rails db:seed" \
    "bundle exec rails db:reset" "bundle exec rails dbconsole" \
    "Run: rails generate model <Name> <fields>, then rails db:migrate"
}

_gen_ecto() {
  local engine="$1" target="$2" pname="$3"
  local adapter=""; case "$engine" in postgres) adapter="Ecto.Adapters.Postgres" ;; mysql) adapter="Ecto.Adapters.MyXQL" ;; sqlite) adapter="Ecto.Adapters.SQLite3" ;; esac
  local app_mod; app_mod=$(echo "$pname" | sed 's/[^a-zA-Z0-9]//g; s/^\(.\)/\U\1/')
  local app_atom; app_atom=$(echo "$pname" | tr '[:upper:]' '[:lower:]')

  mkdir -p "$target/lib/${app_atom}" "$target/config" "$target/priv/repo/migrations"

  cat > "$target/lib/${app_atom}/repo.ex" <<ECTO_EOF
defmodule ${app_mod}.Repo do
  use Ecto.Repo, otp_app: :${app_atom}, adapter: ${adapter}
end
ECTO_EOF

  [ -f "$target/config/dev.exs" ] && cat >> "$target/config/dev.exs" <<ECTO_DEV
config :${app_atom}, ${app_mod}.Repo, url: System.get_env("DATABASE_URL"), pool_size: 10
ECTO_DEV

  [ -f "$target/config/runtime.exs" ] && cat >> "$target/config/runtime.exs" <<ECTO_RT
config :${app_atom}, ${app_mod}.Repo,
  url: System.get_env("DATABASE_URL") || raise("DATABASE_URL not set"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
ECTO_RT

  cat > "$target/priv/repo/migrations/001_create_users.exs" <<ECTO_MIG
defmodule ${app_mod}.Repo.Migrations.CreateUsers do
  use Ecto.Migration
  def change do
    create table(:users) do
      add :email, :string, null: false
      add :name, :string
      timestamps()
    end
    create unique_index(:users, [:email])
  end
end
ECTO_MIG

  cat > "$target/priv/repo/seeds.exs" <<ECTO_SEED
${app_mod}.Repo.insert!(%${app_mod}.User{email: "admin@example.com", name: "Admin User"})
IO.puts("Seeded admin user.")
ECTO_SEED
  ok "Generated Ecto setup"

  _db_vars "Ecto" "https://hexdocs.pm/ecto/Ecto.html" \
    "mix ecto.migrate" "mix run priv/repo/seeds.exs" \
    "mix ecto.reset" "echo 'Use iex -S mix for interactive queries'" \
    "Run: mix phx.gen.schema <Schema> <table> <fields>, then mix ecto.migrate"
}

_gen_spring_data_jpa() {
  local engine="$1" target="$2"
  local driver="" dialect="" fallback_url=""
  case "$engine" in
    postgres) driver="org.postgresql.Driver"; dialect="org.hibernate.dialect.PostgreSQLDialect"; fallback_url="jdbc:postgresql://localhost:5432/dbname" ;;
    mysql)    driver="com.mysql.cj.jdbc.Driver"; dialect="org.hibernate.dialect.MySQLDialect"; fallback_url="jdbc:mysql://localhost:3306/dbname" ;;
    sqlite)   driver="org.sqlite.JDBC"; dialect="org.hibernate.community.dialect.SQLiteDialect"; fallback_url="jdbc:sqlite:dev.db" ;;
  esac

  mkdir -p "$target/src/main/resources/db/migration" \
           "$target/src/main/java/com/example/model" \
           "$target/src/main/java/com/example/repository"

  cat > "$target/src/main/resources/application.properties" <<SPRING_EOF
spring.datasource.url=\${DATABASE_URL:${fallback_url}}
spring.datasource.driver-class-name=${driver}
spring.jpa.hibernate.ddl-auto=validate
spring.jpa.properties.hibernate.dialect=${dialect}
spring.flyway.enabled=true
spring.flyway.locations=classpath:db/migration
SPRING_EOF

  cat > "$target/src/main/java/com/example/model/User.java" <<'EOF'
package com.example.model;
import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name = "users")
public class User {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(nullable = false, unique = true) private String email;
    private String name;
    @Column(name = "created_at") private Instant createdAt = Instant.now();
    @Column(name = "updated_at") private Instant updatedAt = Instant.now();

    public Long getId() { return id; }
    public String getEmail() { return email; }
    public void setEmail(String e) { this.email = e; }
    public String getName() { return name; }
    public void setName(String n) { this.name = n; }
    @PreUpdate public void preUpdate() { this.updatedAt = Instant.now(); }
}
EOF

  cat > "$target/src/main/java/com/example/repository/UserRepository.java" <<'EOF'
package com.example.repository;
import com.example.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
}
EOF

  cat > "$target/src/main/resources/db/migration/V1__create_users.sql" <<'EOF'
CREATE TABLE users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE, name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
  ok "Generated Spring Data JPA setup"

  _db_vars "Spring Data JPA" "https://spring.io/projects/spring-data-jpa" \
    "./gradlew flywayMigrate" "echo 'Add seed data via Flyway migration or CommandLineRunner'" \
    "./gradlew flywayClean flywayMigrate" "echo 'Use your IDE database tools'" \
    "Create @Entity in model/, JpaRepository in repository/, Flyway migration in db/migration/"
}

# ── Orchestrator ─────────────────────────────────────

generate_database_layer() {
  local orm="$1" engine="$2" lang="$3" target="$4" framework="$5"

  _DB_LABEL="" _DB_DOCS="" _DB_MIGRATE="" _DB_SEED="" _DB_RESET="" _DB_STUDIO="" _DB_ADD_STEPS=""

  case "$orm" in
    prisma)          _gen_prisma "$engine" "$target" ;;
    drizzle)         _gen_drizzle "$engine" "$target" ;;
    mongoose)        _gen_mongoose "$target" ;;
    sqlalchemy)      _gen_sqlalchemy "$engine" "$target" ;;
    django-orm)      _gen_django_orm "$engine" "$target" ;;
    gorm)            _gen_gorm "$engine" "$target" ;;
    activerecord)    _gen_activerecord "$engine" "$target" ;;
    ecto)            _gen_ecto "$engine" "$target" "$PROJECT_NAME" ;;
    spring-data-jpa) _gen_spring_data_jpa "$engine" "$target" ;;
    *) warn "No code generator for ORM '$orm' — configure manually." ; return ;;
  esac

  # ── db/README.md (uses _DB_* vars set by helpers) ──
  mkdir -p "$target/db"
  cat > "$target/db/README.md" <<DB_README
# Database

**Engine:** ${engine} | **ORM:** ${_DB_LABEL}

## Commands

\`\`\`bash
make db-migrate    # ${_DB_MIGRATE}
make db-seed       # ${_DB_SEED}
make db-reset      # ${_DB_RESET}
make db-studio     # ${_DB_STUDIO}
\`\`\`

Set \`DATABASE_URL\` in \`.env\` (see \`.env.example\` for format).

## Adding Models

${_DB_ADD_STEPS}

## Docs

${_DB_DOCS}
DB_README
  ok "Generated db/README.md"

  # ── Integration test (one per language) ────────────
  mkdir -p "$target/tests/integration"
  case "$lang" in
    node) cat > "$target/tests/integration/db-connection.test.ts" <<'EOF'
import { describe, it, expect } from "vitest";
describe("Database connection", () => {
  it("should connect", async () => {
    // Import your db client (prisma, drizzle, mongoose) and run a trivial query
    expect(process.env.DATABASE_URL).toBeTruthy();
  });
});
EOF
      ;;
    python) cat > "$target/tests/integration/test_db_connection.py" <<'EOF'
import os, pytest
@pytest.mark.skipif(not os.environ.get("DATABASE_URL"), reason="DATABASE_URL not set")
def test_db_connection():
    from sqlalchemy import text
    from app.db import engine
    with engine.connect() as conn:
        assert conn.execute(text("SELECT 1")).scalar() == 1
EOF
      ;;
    go) cat > "$target/tests/integration/db_connection_test.go" <<'EOF'
package integration
import ("os"; "testing"; "__MODULE__/db")
func TestDatabaseConnection(t *testing.T) {
	if os.Getenv("DATABASE_URL") == "" { t.Skip("DATABASE_URL not set") }
	conn := db.Connect()
	sqlDB, _ := conn.DB()
	if err := sqlDB.Ping(); err != nil { t.Fatalf("ping: %v", err) }
}
EOF
      if [ -f "$target/go.mod" ]; then
        local mod; mod=$(head -1 "$target/go.mod" | awk '{print $2}')
        sed -i.bak "s|__MODULE__|${mod}|g" "$target/tests/integration/db_connection_test.go"
        rm -f "$target/tests/integration/db_connection_test.go.bak"
      fi
      ;;
    ruby) cat > "$target/tests/integration/db_connection_test.rb" <<'EOF'
require "test_helper"
class DatabaseConnectionTest < ActiveSupport::TestCase
  test("database is reachable") { assert ActiveRecord::Base.connection.active? }
end
EOF
      ;;
    elixir) cat > "$target/tests/integration/db_connection_test.exs" <<'EOF'
defmodule DatabaseConnectionTest do
  use ExUnit.Case
  test "database is reachable" do
    {:ok, result} = Ecto.Adapters.SQL.query(Repo, "SELECT 1", [])
    assert result.num_rows == 1
  end
end
EOF
      ;;
    java) mkdir -p "$target/src/test/java/com/example/integration"
      cat > "$target/src/test/java/com/example/integration/DatabaseConnectionTest.java" <<'EOF'
package com.example.integration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import javax.sql.DataSource;
import static org.junit.jupiter.api.Assertions.assertNotNull;

@SpringBootTest class DatabaseConnectionTest {
    @Autowired private DataSource ds;
    @Test void connect() throws Exception { try (var c = ds.getConnection()) { assertNotNull(c); } }
}
EOF
      ;;
  esac
  ok "Generated database integration test"

  # ── Makefile targets (uses _DB_* vars) ─────────────
  local p=""; [ "$IS_FULLSTACK" = true ] && p="cd backend && "
  sed -i.bak 's/^\(\.PHONY:.*\)/\1 \\\n       db-migrate db-seed db-reset db-studio/' "$ROOT_DIR/Makefile"
  rm -f "$ROOT_DIR/Makefile.bak"

  cat >> "$ROOT_DIR/Makefile" <<MKEOF

# ──────────────────────────────────────────────
# Database
# ──────────────────────────────────────────────

db-migrate: ## Run database migrations
	@${p}${_DB_MIGRATE}

db-seed: ## Seed the database
	@${p}${_DB_SEED}

db-reset: ## Reset the database (drop + migrate + seed)
	@${p}${_DB_RESET}

db-studio: ## Open database GUI / studio
	@${p}${_DB_STUDIO}
MKEOF
  ok "Added database targets to Makefile"

  # ── SQLite + serverless warning ────────────────────
  if [ "$engine" = "sqlite" ]; then
    case "${DEPLOY_PROVIDER:-}" in
      *Vercel*|*Netlify*|*Cloudflare*|*"AWS Lambda"*)
        warn "SQLite won't work in production with ${DEPLOY_PROVIDER} (ephemeral filesystem)."
        warn "Consider PostgreSQL or Turso (cloud SQLite) for production."
        ;;
    esac
  fi
}

# ── resolve_stack: sets _LINTER, _FMT, _TEST, _E2E, _SETUP, _CI, _PKG
#    for a given framework name. Used for both single-stack and fullstack.
resolve_stack() {
  local fw="$1"

  _LINTER="" _FMT="" _TEST="" _E2E="" _SETUP="" _CI="" _PKG=""

  # Also classify the stack "family" for monitoring SDK generation
  _FAMILY=""

  case "$fw" in
    # ── JS/TS frameworks ─────────────────────────────
    "Next.js (React)")
      _FAMILY="node"
      _LINTER='npm run lint && npx prettier --check .'
      _FMT='npx prettier --write .'
      _TEST='npx vitest run --passWithNoTests'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npx create-next-app@latest . --ts --eslint --tailwind --app --src-dir --import-alias "@/*" --use-npm && npm install -D vitest @vitejs/plugin-react playwright'
      ;;
    "SvelteKit")
      _FAMILY="node"
      _LINTER='npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run --passWithNoTests'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npx sv create . --template minimal --types ts --no-add-ons && npm install -D vitest playwright eslint prettier'
      ;;
    "Nuxt (Vue)")
      _FAMILY="node"
      _LINTER='npx nuxi typecheck && npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run --passWithNoTests'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npx nuxi@latest init . --force && npm install -D vitest @nuxt/test-utils playwright eslint prettier'
      ;;
    "Astro")
      _FAMILY="node"
      _LINTER='npx astro check && npx prettier --check .'
      _FMT='npx prettier --write .'
      _TEST='npx vitest run --passWithNoTests'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npm create astro@latest -- . --template minimal --typescript strict --install --no-git && npm install -D vitest playwright prettier'
      ;;
    "Remix")
      _FAMILY="node"
      _LINTER='npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run --passWithNoTests'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npx create-remix@latest . --yes && npm install -D vitest playwright prettier'
      ;;
    "Hono (API)")
      _FAMILY="node"
      _LINTER='npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run --passWithNoTests'
      _E2E='npx vitest run tests/e2e'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npm create hono@latest . -- --template nodejs && npm install -D typescript eslint prettier vitest @types/node'
      ;;
    "Express (TypeScript)")
      _FAMILY="node"
      _LINTER='npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run --passWithNoTests'
      _E2E='npx vitest run tests/e2e'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npm init -y && npm install express && npm install -D typescript @types/express @types/node eslint prettier vitest tsx && npx tsc --init'
      ;;
    "Node.js (TypeScript, no framework)")
      _FAMILY="node"
      _LINTER='npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run --passWithNoTests'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npm init -y && npm install -D typescript eslint prettier vitest @types/node && npx tsc --init'
      ;;
    "Node.js (JavaScript, no framework)")
      _FAMILY="node"
      _LINTER='npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run --passWithNoTests'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npm init -y && npm install -D eslint prettier vitest'
      ;;

    # ── Python frameworks ────────────────────────────
    "FastAPI")
      _FAMILY="python"
      _LINTER='ruff check . && ruff format --check .'
      _FMT='ruff format . && ruff check . --fix'
      _TEST='pytest tests/ --ignore=tests/e2e || [ $? -eq 5 ]'
      _E2E='pytest tests/e2e/'
      _SETUP='python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt'
      _CI="$PYTHON_CI_STEPS"
      _PKG='python -m venv .venv && source .venv/bin/activate && pip install fastapi uvicorn ruff pytest httpx && pip freeze > requirements.txt'
      ;;
    "Django")
      _FAMILY="python"
      _LINTER='ruff check . && ruff format --check .'
      _FMT='ruff format . && ruff check . --fix'
      _TEST='python manage.py test'
      _E2E='pytest tests/e2e/'
      _SETUP='python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt'
      _CI="$PYTHON_CI_STEPS"
      _PKG='python -m venv .venv && source .venv/bin/activate && pip install django ruff pytest && django-admin startproject config . && pip freeze > requirements.txt'
      ;;
    "Flask")
      _FAMILY="python"
      _LINTER='ruff check . && ruff format --check .'
      _FMT='ruff format . && ruff check . --fix'
      _TEST='pytest tests/ --ignore=tests/e2e || [ $? -eq 5 ]'
      _E2E='pytest tests/e2e/'
      _SETUP='python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt'
      _CI="$PYTHON_CI_STEPS"
      _PKG='python -m venv .venv && source .venv/bin/activate && pip install flask ruff pytest && pip freeze > requirements.txt'
      ;;
    "Python (no framework)")
      _FAMILY="python"
      _LINTER='ruff check . && ruff format --check .'
      _FMT='ruff format . && ruff check . --fix'
      _TEST='pytest tests/ --ignore=tests/e2e || [ $? -eq 5 ]'
      _E2E='pytest tests/e2e/'
      _SETUP='python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt'
      _CI="$PYTHON_CI_STEPS"
      _PKG='python -m venv .venv && source .venv/bin/activate && pip install ruff pytest && pip freeze > requirements.txt'
      ;;

    # ── Go ───────────────────────────────────────────
    "Go")
      _FAMILY="go"
      _LINTER='golangci-lint run ./...'
      _FMT='gofmt -w .'
      _TEST='go test ./...'
      _E2E='go test ./tests/e2e/...'
      _SETUP='go mod download'
      _CI="$GO_CI_STEPS"
      _PKG="go mod init github.com/${GITHUB_REPO:-$PROJECT_NAME}"
      ;;

    # ── Rust ─────────────────────────────────────────
    "Axum (API)")
      _FAMILY="rust"
      _LINTER='cargo clippy -- -D warnings && cargo fmt -- --check'
      _FMT='cargo fmt'
      _TEST='cargo test'
      _E2E='cargo test --test e2e'
      _SETUP='cargo fetch'
      _CI="$RUST_CI_STEPS"
      _PKG='cargo init --name '"$PROJECT_NAME"' && cargo add axum tokio --features tokio/full && cargo add -D tower-http'
      ;;
    "Rust (no framework)")
      _FAMILY="rust"
      _LINTER='cargo clippy -- -D warnings && cargo fmt -- --check'
      _FMT='cargo fmt'
      _TEST='cargo test'
      _E2E='cargo test --test e2e'
      _SETUP='cargo fetch'
      _CI="$RUST_CI_STEPS"
      _PKG='cargo init --name "'"$PROJECT_NAME"'"'
      ;;

    # ── Elixir / Phoenix ─────────────────────────────
    "Phoenix")
      _FAMILY="elixir"
      _LINTER='mix format --check-formatted && mix credo --strict'
      _FMT='mix format'
      _TEST='mix test'
      _E2E='mix test tests/e2e/'
      _SETUP='mix deps.get && mix compile'
      _CI="$ELIXIR_CI_STEPS"
      _PKG='mix archive.install hex phx_new --force && mix phx.new . --app '"$PROJECT_NAME"' --no-install && mix deps.get'
      ;;
    "Elixir (no framework)")
      _FAMILY="elixir"
      _LINTER='mix format --check-formatted && mix credo --strict'
      _FMT='mix format'
      _TEST='mix test'
      _E2E='mix test tests/e2e/'
      _SETUP='mix deps.get && mix compile'
      _CI="$ELIXIR_CI_STEPS"
      _PKG='mix new . --app '"$PROJECT_NAME"
      ;;

    # ── Ruby / Rails ─────────────────────────────────
    "Rails")
      _FAMILY="ruby"
      _LINTER='bundle exec rubocop'
      _FMT='bundle exec rubocop -A'
      _TEST='bundle exec rails test'
      _E2E='bundle exec rails test:system'
      _SETUP='bundle install'
      _CI="$RUBY_CI_STEPS"
      _PKG='gem install rails && rails new . --name='"$PROJECT_NAME"' --skip-git --force && bundle add rubocop --group=development'
      ;;
    "Ruby (no framework)")
      _FAMILY="ruby"
      _LINTER='bundle exec rubocop'
      _FMT='bundle exec rubocop -A'
      _TEST='bundle exec rake test'
      _E2E='bundle exec rake test:e2e'
      _SETUP='bundle install'
      _CI="$RUBY_CI_STEPS"
      _PKG='bundle init && bundle add rubocop minitest --group=development'
      ;;

    # ── Java / Kotlin (Spring Boot) ──────────────────
    "Spring Boot (Kotlin)")
      _FAMILY="java"
      _LINTER='./gradlew ktlintCheck'
      _FMT='./gradlew ktlintFormat'
      _TEST='./gradlew test'
      _E2E='./gradlew e2eTest'
      _SETUP='./gradlew dependencies'
      _CI="$JAVA_CI_STEPS"
      _PKG='curl -s "https://start.spring.io/starter.tgz?type=gradle-project-kotlin&language=kotlin&bootVersion=3.4.1&groupId=com.example&artifactId='"$PROJECT_NAME"'&dependencies=web,actuator" | tar -xzf - && gradle wrapper'
      ;;
    "Spring Boot (Java)")
      _FAMILY="java"
      _LINTER='./gradlew checkstyleMain checkstyleTest'
      _FMT='./gradlew spotlessApply'
      _TEST='./gradlew test'
      _E2E='./gradlew e2eTest'
      _SETUP='./gradlew dependencies'
      _CI="$JAVA_CI_STEPS"
      _PKG='curl -s "https://start.spring.io/starter.tgz?type=gradle-project&language=java&bootVersion=3.4.1&groupId=com.example&artifactId='"$PROJECT_NAME"'&dependencies=web,actuator" | tar -xzf - && gradle wrapper'
      ;;
  esac
}

# ── Apply stack configuration ─────────────────────────
STACK_FAMILY=""
if [ "$IS_FULLSTACK" = true ]; then
  # Resolve backend
  resolve_stack "$BACKEND_STACK"
  BE_LINTER="$_LINTER"; BE_FMT="$_FMT"; BE_TEST="$_TEST"; BE_E2E="$_E2E"
  BE_SETUP="$_SETUP"; BE_CI="$_CI"; BE_PKG="$_PKG"; BE_FAMILY="$_FAMILY"

  # Resolve frontend
  resolve_stack "$FRONTEND_STACK"
  FE_LINTER="$_LINTER"; FE_FMT="$_FMT"; FE_TEST="$_TEST"; FE_E2E="$_E2E"
  FE_SETUP="$_SETUP"; FE_CI="$_CI"; FE_PKG="$_PKG"; FE_FAMILY="$_FAMILY"

  # Use backend family for monitoring (primary app logic lives there)
  STACK_FAMILY="$BE_FAMILY"

  # Combine: run each tool in its subdirectory
  LINTER_CMD="(cd backend && ${BE_LINTER}) && (cd frontend && ${FE_LINTER})"
  TEST_CMD="(cd backend && ${BE_TEST}) && (cd frontend && ${FE_TEST})"
  E2E_CMD="(cd backend && ${BE_E2E}) && (cd frontend && ${FE_E2E})"
  SETUP_CMD="(cd backend && ${BE_SETUP}) && (cd frontend && ${FE_SETUP})"
  PKG_INIT_CMD="mkdir -p backend frontend && (cd backend && ${BE_PKG}) && (cd frontend && ${FE_PKG})"

  # Combine CI steps (deduplicate Node setup if both use it)
  if [ "$BE_CI" = "$FE_CI" ]; then
    CI_SETUP_STEPS="$BE_CI"
  else
    CI_SETUP_STEPS="${BE_CI}
${FE_CI}"
  fi
elif [ "$STACK" != "None" ] && [ -n "$STACK" ]; then
  resolve_stack "$STACK"
  LINTER_CMD="$_LINTER"; TEST_CMD="$_TEST"; E2E_CMD="$_E2E"
  SETUP_CMD="$_SETUP"; CI_SETUP_STEPS="$_CI"; PKG_INIT_CMD="$_PKG"
  STACK_FAMILY="$_FAMILY"
else
  info "Skipping stack setup. Configure scripts/checks/ manually later."
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "3/8  Database & ORM"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── 3a. Database engine ───────────────────────────
DB_ENGINE_CHOICE=$(choose "Choose a database:" \
  "PostgreSQL" \
  "MySQL / MariaDB" \
  "SQLite" \
  "MongoDB" \
  "Redis (as primary data store)" \
  "None (skip database setup)")

case "$DB_ENGINE_CHOICE" in
  "PostgreSQL")                    DB_ENGINE="postgres" ;;
  "MySQL / MariaDB")               DB_ENGINE="mysql" ;;
  "SQLite")                        DB_ENGINE="sqlite" ;;
  "MongoDB")                       DB_ENGINE="mongodb" ;;
  "Redis (as primary data store)") DB_ENGINE="redis" ;;
  *)                               DB_ENGINE="" ;;
esac

if [ -n "$DB_ENGINE" ]; then
  # ── 3b. ORM / query layer ───────────────────────
  # Determine the effective backend stack for ORM selection
  EFFECTIVE_STACK="$STACK"
  [ "$IS_FULLSTACK" = true ] && EFFECTIVE_STACK="$BACKEND_STACK"

  # Classify the stack language
  STACK_LANG=""
  case "$EFFECTIVE_STACK" in
    "Next.js (React)"|"Nuxt (Vue)"|"SvelteKit"|"Astro"|"Remix"|"Hono (API)"|"Express (TypeScript)"|"Node.js (TypeScript, no framework)"|"Node.js (JavaScript, no framework)")
      STACK_LANG="node" ;;
    "FastAPI"|"Django"|"Flask"|"Python (no framework)")
      STACK_LANG="python" ;;
    "Go")
      STACK_LANG="go" ;;
    "Rails"|"Ruby (no framework)")
      STACK_LANG="ruby" ;;
    "Axum (API)"|"Rust (no framework)")
      STACK_LANG="rust" ;;
    "Phoenix"|"Elixir (no framework)")
      STACK_LANG="elixir" ;;
    "Spring Boot (Kotlin)"|"Spring Boot (Java)")
      STACK_LANG="java" ;;
  esac

  IS_SQL=true
  [[ "$DB_ENGINE" == "mongodb" || "$DB_ENGINE" == "redis" ]] && IS_SQL=false

  # Offer ORM choices based on stack language and database type
  if [ "$STACK_LANG" = "node" ] && [ "$IS_SQL" = true ]; then
    DB_ORM_CHOICE=$(choose "ORM / query layer:" \
      "Prisma (recommended)" \
      "Drizzle" \
      "TypeORM" \
      "Knex.js (query builder only)" \
      "None (raw driver)")
  elif [ "$STACK_LANG" = "node" ] && [ "$DB_ENGINE" = "mongodb" ]; then
    DB_ORM_CHOICE=$(choose "ORM / query layer:" \
      "Mongoose" \
      "Prisma" \
      "None (native driver)")
  elif [ "$STACK_LANG" = "python" ] && [ "$IS_SQL" = true ]; then
    if [ "$EFFECTIVE_STACK" = "Django" ]; then
      DB_ORM_CHOICE="Django ORM (auto-selected)"
      info "Django ORM auto-selected for Django projects."
    else
      DB_ORM_CHOICE=$(choose "ORM / query layer:" \
        "SQLAlchemy (recommended)" \
        "Tortoise ORM" \
        "None (raw driver)")
    fi
  elif [ "$STACK_LANG" = "python" ] && [ "$DB_ENGINE" = "mongodb" ]; then
    DB_ORM_CHOICE=$(choose "ORM / query layer:" \
      "Motor (async) / PyMongo" \
      "MongoEngine" \
      "None")
  elif [ "$STACK_LANG" = "go" ] && [ "$IS_SQL" = true ]; then
    DB_ORM_CHOICE=$(choose "ORM / query layer:" \
      "GORM" \
      "sqlx" \
      "Ent" \
      "None (database/sql)")
  elif [ "$STACK_LANG" = "go" ] && [ "$DB_ENGINE" = "mongodb" ]; then
    DB_ORM_CHOICE=$(choose "ORM / query layer:" \
      "mongo-go-driver" \
      "None")
  elif [ "$STACK_LANG" = "ruby" ] && [ "$IS_SQL" = true ]; then
    DB_ORM_CHOICE="ActiveRecord (auto-selected)"
    info "ActiveRecord auto-selected for Ruby projects."
  elif [ "$STACK_LANG" = "rust" ] && [ "$IS_SQL" = true ]; then
    DB_ORM_CHOICE=$(choose "ORM / query layer:" \
      "Diesel" \
      "SQLx" \
      "SeaORM")
  elif [ "$STACK_LANG" = "elixir" ] && [ "$IS_SQL" = true ]; then
    DB_ORM_CHOICE="Ecto (auto-selected)"
    info "Ecto auto-selected for Elixir projects."
  elif [ "$STACK_LANG" = "java" ] && [ "$IS_SQL" = true ]; then
    DB_ORM_CHOICE=$(choose "ORM / query layer:" \
      "Spring Data JPA / Hibernate (auto-selected)" \
      "jOOQ")
  else
    DB_ORM_CHOICE="None"
    info "No predefined ORM options for this stack/database combination."
    info "Configure your ORM manually after setup."
  fi

  # Normalize ORM key
  case "$DB_ORM_CHOICE" in
    "Prisma (recommended)"|"Prisma")                    DB_ORM="prisma" ;;
    "Drizzle")                                          DB_ORM="drizzle" ;;
    "TypeORM")                                          DB_ORM="typeorm" ;;
    "Knex.js (query builder only)")                     DB_ORM="knex" ;;
    "Mongoose")                                         DB_ORM="mongoose" ;;
    "SQLAlchemy (recommended)")                         DB_ORM="sqlalchemy" ;;
    "Django ORM (auto-selected)")                       DB_ORM="django-orm" ;;
    "Tortoise ORM")                                     DB_ORM="tortoise" ;;
    "Motor (async) / PyMongo")                          DB_ORM="motor" ;;
    "MongoEngine")                                      DB_ORM="mongoengine" ;;
    "GORM")                                             DB_ORM="gorm" ;;
    "sqlx")                                             DB_ORM="sqlx" ;;
    "Ent")                                              DB_ORM="ent" ;;
    "mongo-go-driver")                                  DB_ORM="mongo-go-driver" ;;
    "ActiveRecord (auto-selected)")                     DB_ORM="activerecord" ;;
    "Diesel")                                           DB_ORM="diesel" ;;
    "SQLx")                                             DB_ORM="sqlx" ;;
    "SeaORM")                                           DB_ORM="seaorm" ;;
    "Ecto (auto-selected)")                             DB_ORM="ecto" ;;
    "Spring Data JPA / Hibernate (auto-selected)")      DB_ORM="spring-data-jpa" ;;
    "jOOQ")                                             DB_ORM="jooq" ;;
    *)                                                  DB_ORM="none" ;;
  esac

  # ── 3c. Database hosting mode ───────────────────
  DB_HOSTING_CHOICE=$(choose "Database hosting mode:" \
    "Cloud-hosted (recommended)" \
    "Self-hosted" \
    "Local only (dev/prototype)")

  case "$DB_HOSTING_CHOICE" in
    "Cloud-hosted (recommended)")
      DB_HOSTING="cloud"

      # Offer provider options based on database engine
      case "$DB_ENGINE" in
        "postgres")
          DB_CLOUD_PROVIDER=$(choose "PostgreSQL cloud provider:" \
            "Supabase" \
            "Neon" \
            "Railway" \
            "Render" \
            "AWS RDS" \
            "GCP Cloud SQL")
          ;;
        "mysql")
          DB_CLOUD_PROVIDER=$(choose "MySQL cloud provider:" \
            "PlanetScale" \
            "Railway" \
            "AWS RDS" \
            "GCP Cloud SQL")
          ;;
        "mongodb")
          DB_CLOUD_PROVIDER=$(choose "MongoDB cloud provider:" \
            "MongoDB Atlas" \
            "Cosmos DB")
          ;;
        "redis")
          DB_CLOUD_PROVIDER=$(choose "Redis cloud provider:" \
            "Upstash" \
            "Redis Cloud" \
            "AWS ElastiCache")
          ;;
        "sqlite")
          info "SQLite is a local file-based database — cloud hosting is not applicable."
          info "Consider Turso (libSQL) for a cloud-hosted SQLite-compatible database."
          DB_HOSTING="local"
          ;;
      esac

      if [ "$DB_HOSTING" = "cloud" ]; then
        info "Provider: $DB_CLOUD_PROVIDER"

        # Prompt for connection string with format hint
        case "$DB_ENGINE" in
          "postgres") info "Format: postgres://user:password@host:5432/dbname" ;;
          "mysql")    info "Format: mysql://user:password@host:3306/dbname" ;;
          "mongodb")  info "Format: mongodb+srv://user:password@cluster.example.net/dbname" ;;
          "redis")    info "Format: redis://user:password@host:6379" ;;
        esac

        DATABASE_URL=$(ask "Connection string / URL (leave empty to set later)" "")

        # Validate connection string format if provided
        if [ -n "$DATABASE_URL" ]; then
          VALID_FORMAT=true
          case "$DB_ENGINE" in
            "postgres")
              [[ "$DATABASE_URL" =~ ^postgres(ql)?:// ]] || VALID_FORMAT=false ;;
            "mysql")
              [[ "$DATABASE_URL" =~ ^mysql:// ]] || VALID_FORMAT=false ;;
            "mongodb")
              [[ "$DATABASE_URL" =~ ^mongodb(\+srv)?:// ]] || VALID_FORMAT=false ;;
            "redis")
              [[ "$DATABASE_URL" =~ ^redis(s)?:// ]] || VALID_FORMAT=false ;;
          esac
          if [ "$VALID_FORMAT" = false ]; then
            warn "Connection string doesn't match expected format for $DB_ENGINE."
            info "Saving as-is — verify it's correct before deploying."
          fi
        fi

        # Ask for provider-specific API keys
        case "$DB_CLOUD_PROVIDER" in
          "Supabase")
            DB_API_KEY=$(ask "Supabase API key (leave empty to set later)" "") ;;
          "Neon")
            DB_API_KEY=$(ask "Neon API key (leave empty to set later)" "") ;;
          "PlanetScale")
            DB_API_KEY=$(ask "PlanetScale service token (leave empty to set later)" "") ;;
          "MongoDB Atlas")
            DB_API_KEY=$(ask "Atlas API key (leave empty to set later)" "") ;;
          "Upstash")
            DB_API_KEY=$(ask "Upstash REST token (leave empty to set later)" "") ;;
        esac
      fi
      ;;

    "Self-hosted")
      DB_HOSTING="self-hosted"
      info "The database will be deployed alongside your app."
      info "Provisioning details depend on your deploy provider (selected next)."
      echo ""
      info "  Fly.io:      Fly Postgres (managed) — provisioned automatically after deploy setup"
      info "  Docker:      docker-compose service"
      info "  Serverless:  Vercel/Netlify/Cloudflare do NOT support self-hosted databases."
      info "               If you pick a serverless provider, use a cloud-hosted database instead."
      ;;

    "Local only (dev/prototype)")
      DB_HOSTING="local"

      case "$DB_ENGINE" in
        "sqlite")
          info "SQLite database file will be created in the project directory."
          DATABASE_URL="file:./dev.db"
          ;;
        *)
          info "A local Docker container will be used for $DB_ENGINE_CHOICE."
          info "Make sure Docker is installed: https://docs.docker.com/get-docker/"
          ;;
      esac
      ;;
  esac

  # ── Summary ──────────────────────────────────────
  echo ""
  ok "Database configuration:"
  echo -e "  Engine:  ${CYAN}${DB_ENGINE_CHOICE}${RESET}"
  echo -e "  ORM:     ${CYAN}${DB_ORM_CHOICE}${RESET}"
  echo -e "  Hosting: ${CYAN}${DB_HOSTING_CHOICE}${RESET}"
  [ -n "${DB_CLOUD_PROVIDER:-}" ] && echo -e "  Provider: ${CYAN}${DB_CLOUD_PROVIDER}${RESET}"
  [ -n "$DATABASE_URL" ] && echo -e "  URL:     ${DIM}(configured)${RESET}"
  echo ""
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "4/8  GitHub"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

GITHUB_REPO=""
CREATE_LABELS=false

CREATE_REPO=false

if command -v gh &>/dev/null; then
  if confirm "Configure GitHub integration?"; then
    # Detect current remote as default, but always let user override
    DETECTED_REPO=""
    if DETECTED_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>&1); then
      : # success — DETECTED_REPO is set
    else
      DETECTED_REPO=""  # not a GitHub repo or not authenticated
    fi
    GITHUB_REPO=$(ask "GitHub repository (owner/name)" "$DETECTED_REPO")

    # Check if the repo exists; offer to create it if not
    if [ -n "$GITHUB_REPO" ]; then
      if ! gh repo view "$GITHUB_REPO" &>/dev/null; then
        info "Repository $GITHUB_REPO does not exist yet."
        if confirm "Create it now?"; then
          CREATE_REPO=true

          REPO_VISIBILITY=$(choose "Repository visibility:" \
            "Private" \
            "Public")
        fi
      fi
    fi

    if [ -n "$GITHUB_REPO" ] && confirm "Create Symphony labels (ready, agent, in-progress, human-review)?"; then
      CREATE_LABELS=true
    fi

    CREATE_PROJECT=false
    if [ -n "$GITHUB_REPO" ] && confirm "Create a GitHub Project board for issue tracking?"; then
      CREATE_PROJECT=true
    fi
  fi
else
  warn "gh CLI not found. Skipping GitHub setup."
  info "Install from: https://cli.github.com"
  info "You can configure GitHub manually later — see docs/SETUP.md"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "5/8  Deploys"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── Step 4a: Choose deploy provider ─────────────────
DEPLOY_PROVIDER=$(choose "Deploy provider:" \
  "Vercel" \
  "Netlify" \
  "Cloudflare Pages" \
  "Fly.io" \
  "Custom" \
  "None / I'll configure later")

DEPLOY_TOKEN=""
DEPLOY_PROJECT_ID=""

case "$DEPLOY_PROVIDER" in
  "Vercel"|"Netlify"|"Cloudflare Pages"|"Fly.io")
    # Set provider key
    case "$DEPLOY_PROVIDER" in
      "Vercel")           DEPLOY_PROVIDER_KEY="vercel" ;;
      "Netlify")          DEPLOY_PROVIDER_KEY="netlify" ;;
      "Cloudflare Pages") DEPLOY_PROVIDER_KEY="cloudflare" ;;
      "Fly.io")           DEPLOY_PROVIDER_KEY="fly" ;;
    esac

    # ── Step 4b: Choose deploy mode ──────────────────
    echo ""
    if [ "$DEPLOY_PROVIDER" = "Fly.io" ]; then
      warn "Fly.io has limited native Git integration."
      info "  Native mode: only production deploys on main are automatic."
      info "  PR previews require GitHub Actions mode."
      echo ""
    fi

    info "Deploy mode options:"
    echo -e "  ${CYAN}Native:${RESET}  The service's own Git hooks handle production deploys"
    echo -e "           on main and preview deploys on PRs automatically."
    echo -e "  ${CYAN}Scripts:${RESET} Full control via GitHub Actions. Use for custom build"
    echo -e "           steps, multi-service orchestration, or env-specific logic."
    echo ""

    DEPLOY_MODE_CHOICE=$(choose "Deploy mode:" \
      "Native service integration (recommended)" \
      "GitHub Actions scripts")

    case "$DEPLOY_MODE_CHOICE" in
      "Native service integration"*) DEPLOY_MODE="native" ;;
      "GitHub Actions scripts"*)     DEPLOY_MODE="scripts" ;;
    esac

    # ── Collect credentials ────────────────────────────
    echo ""
    case "$DEPLOY_PROVIDER" in
      "Vercel")
        info "You can find your Vercel token at: https://vercel.com/account/tokens"
        DEPLOY_TOKEN=$(ask "Vercel token (leave empty to set later)" "")
        if [ "$DEPLOY_MODE" = "scripts" ]; then
          DEPLOY_PROJECT_ID=$(ask "Vercel project ID (leave empty to set later)" "")
        fi
        ;;
      "Netlify")
        info "You can find your Netlify token at: https://app.netlify.com/user/applications#personal-access-tokens"
        DEPLOY_TOKEN=$(ask "Netlify token (leave empty to set later)" "")
        DEPLOY_PROJECT_ID=$(ask "Netlify site ID (leave empty to set later)" "")
        ;;
      "Cloudflare Pages")
        info "You can find your Cloudflare API token at: https://dash.cloudflare.com/profile/api-tokens"
        DEPLOY_TOKEN=$(ask "Cloudflare API token (leave empty to set later)" "")
        DEPLOY_PROJECT_ID=$(ask "Cloudflare Pages project name (leave empty to set later)" "")
        ;;
      "Fly.io")
        info "You can get a Fly.io token with: fly tokens create deploy"
        DEPLOY_TOKEN=$(ask "Fly.io deploy token (leave empty to set later)" "")
        DEPLOY_PROJECT_ID=$(ask "Fly.io app name (leave empty to set later)" "")
        ;;
    esac
    ;;
  "Custom")
    DEPLOY_PROVIDER_KEY="custom"
    DEPLOY_MODE="custom"
    info "Custom provider selected. Script stubs will be kept for you to configure."
    info "See docs/DEPLOY.md for the contract your scripts must follow."
    ;;
  *)
    DEPLOY_PROVIDER_KEY=""
    DEPLOY_MODE="none"
    ;;
esac

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "6/8  AI Agent (for Symphony)"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

info "Symphony dispatches AI agents to implement issues autonomously."
info "Choose which agent to use in the Symphony workflow."

AGENT_CHOICE=$(choose "AI agent for autonomous work:" \
  "Claude Code (Anthropic)" \
  "Codex (OpenAI)" \
  "None / I'll configure later")

AGENT_KEY_NAME=""
AGENT_KEY_VALUE=""
CLAUDE_AUTH_METHOD=""
case "$AGENT_CHOICE" in
  "Claude Code (Anthropic)")
    CLAUDE_AUTH_METHOD=$(choose "Claude Code authentication method:" \
      "OAuth token (Max/Teams/Enterprise subscription — run 'claude setup-token' to get one)" \
      "API key (Anthropic Console — console.anthropic.com)")
    if [[ "$CLAUDE_AUTH_METHOD" == OAuth* ]]; then
      AGENT_KEY_NAME="CLAUDE_CODE_OAUTH_TOKEN"
      info "Run 'claude setup-token' in your terminal to generate a long-lived OAuth token."
      AGENT_KEY_VALUE=$(ask "OAuth token (leave empty to set later)" "")
    else
      AGENT_KEY_NAME="ANTHROPIC_API_KEY"
      info "You can find your API key at: https://console.anthropic.com/settings/keys"
      AGENT_KEY_VALUE=$(ask "Anthropic API key (leave empty to set later)" "")
    fi
    ;;
  "Codex (OpenAI)")
    AGENT_KEY_NAME="OPENAI_API_KEY"
    info "You can find your API key at: https://platform.openai.com/api-keys"
    AGENT_KEY_VALUE=$(ask "OpenAI API key (leave empty to set later)" "")
    ;;
esac

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "7/8  Monitoring"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

MONITOR_CHOICE=$(choose "Error/performance monitoring:" \
  "Sentry" \
  "Datadog" \
  "Grafana" \
  "None / I'll configure later")

MONITOR_DSN=""

case "$MONITOR_CHOICE" in
  "Sentry")
    info "You can find your Sentry DSN at: Settings > Projects > [project] > Client Keys (DSN)"
    MONITOR_DSN=$(ask "Sentry DSN (leave empty to set later)" "")
    ;;
  "Datadog")
    info "You can find your Datadog API key at: https://app.datadoghq.com/organization-settings/api-keys"
    MONITOR_DSN=$(ask "Datadog API key (leave empty to set later)" "")
    ;;
  "Grafana")
    info "You'll need your Grafana Cloud OTLP endpoint for metrics/traces."
    MONITOR_DSN=$(ask "Grafana endpoint or API key (leave empty to set later)" "")
    ;;
esac

# Validate DSN format if provided
if [ -n "$MONITOR_DSN" ]; then
  DSN_VALID=true
  case "$MONITOR_CHOICE" in
    "Sentry")
      # Sentry DSN: https://<key>@<host>/<project-id>
      if ! echo "$MONITOR_DSN" | grep -qE '^https://[a-f0-9]+@[^/]+/[0-9]+$'; then
        warn "Sentry DSN doesn't match expected format: https://<key>@<host>/<project-id>"
        if ! confirm "Continue with this value anyway?"; then
          MONITOR_DSN=""
          DSN_VALID=false
        fi
      fi
      ;;
    "Datadog")
      # Datadog API key: 32-character hex string
      if ! echo "$MONITOR_DSN" | grep -qE '^[a-f0-9]{32}$'; then
        warn "Datadog API key doesn't look like a valid 32-character hex key"
        if ! confirm "Continue with this value anyway?"; then
          MONITOR_DSN=""
          DSN_VALID=false
        fi
      fi
      ;;
    "Grafana")
      # Grafana endpoint: should be a valid URL
      if ! echo "$MONITOR_DSN" | grep -qE '^https?://'; then
        warn "Grafana endpoint doesn't look like a valid URL (expected https://...)"
        if ! confirm "Continue with this value anyway?"; then
          MONITOR_DSN=""
          DSN_VALID=false
        fi
      fi
      ;;
  esac
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "8/8  Self-hosted runner"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SETUP_RUNNER=false

info "Use your machine as a GitHub Actions runner to save CI minutes."
info "When your machine is offline, jobs automatically fall back to GitHub-hosted runners."

if confirm "Set up a self-hosted runner on this machine?"; then
  SETUP_RUNNER=true
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "Applying configuration..."
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── 0. Create GitHub repository if requested ──────────
if [ "$CREATE_REPO" = true ] && [ -n "$GITHUB_REPO" ]; then
  VISIBILITY_FLAG="--private"
  [ "$REPO_VISIBILITY" = "Public" ] && VISIBILITY_FLAG="--public"

  info "Creating repository $GITHUB_REPO..."

  # Update origin before creating so --source doesn't conflict with existing remote
  PROJECT_URL="https://github.com/${GITHUB_REPO}.git"
  if git remote get-url origin &>/dev/null; then
    git remote set-url origin "$PROJECT_URL"
  else
    git remote add origin "$PROJECT_URL"
  fi

  CREATE_EXIT=0
  CREATE_ARGS=("$GITHUB_REPO" $VISIBILITY_FLAG --source "$ROOT_DIR" --remote origin)
  if [ -n "${PROJECT_DESC:-}" ]; then
    CREATE_ARGS+=(--description "${PROJECT_DESC}")
  fi
  CREATE_OUTPUT=$(gh repo create "${CREATE_ARGS[@]}" 2>&1) || CREATE_EXIT=$?
  if [ $CREATE_EXIT -eq 0 ]; then
    ok "Created repository: $GITHUB_REPO ($REPO_VISIBILITY)"
  elif gh repo view "$GITHUB_REPO" &>/dev/null; then
    # gh repo create may fail on --remote but still create the repo
    ok "Created repository: $GITHUB_REPO ($REPO_VISIBILITY)"
  else
    fail "Failed to create repository: $CREATE_OUTPUT"
    warn "Create it manually: gh repo create $GITHUB_REPO $VISIBILITY_FLAG"
  fi
fi

# ── 0b. Enable GitHub Actions PR creation ─────────────
# Symphony needs Actions to create PRs. This is off by default in new repos.
if [ -n "$GITHUB_REPO" ] && gh repo view "$GITHUB_REPO" &>/dev/null; then
  gh api --method PUT "repos/${GITHUB_REPO}/actions/permissions/workflow" \
    --field can_approve_pull_request_reviews=true \
    --field default_workflow_permissions="write" >/dev/null 2>&1 && \
    ok "Enabled GitHub Actions to create PRs and write permissions" || \
    warn "Could not update Actions permissions. Enable manually: repo Settings > Actions > General > 'Allow GitHub Actions to create and approve pull requests'"
fi

# ── 1. Clean up template-specific files ────────────────
# These files belong to the template repo itself, not to
# projects created from it. Removing them so your project
# starts with a clean slate.
info "Removing template-specific files..."
info "These belong to the template repo — your project starts fresh."
echo ""

for f in README.md CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md LICENSE .env.example; do
  if [ -f "$ROOT_DIR/$f" ]; then
    rm "$ROOT_DIR/$f"
    ok "Removed $f (template file)"
  fi
done

# Generate a fresh project README
cat > "$ROOT_DIR/README.md" <<README_EOF
# ${PROJECT_NAME}

${PROJECT_DESC}

## Development

\`\`\`bash
make setup    # install dependencies
make check    # run all checks
\`\`\`

See [docs/SETUP.md](docs/SETUP.md) for full setup guide.
README_EOF
ok "Created project README.md"

# ── 2. Activate GitHub config ──────────────────────────
# The template ships _github/ (inactive) to avoid workflows
# triggering on the template repo itself. Replace any
# template-specific .github/ (CI, tests) with the project config.
if [ -d "$ROOT_DIR/_github" ]; then
  if [ -d "$ROOT_DIR/.github" ]; then
    info "Replacing template .github/ with project config from _github/"
    rm -rf "$ROOT_DIR/.github"
  fi
  mv "$ROOT_DIR/_github" "$ROOT_DIR/.github"
  ok "Activated .github/ (workflows, issue templates, PR template)"
else
  if [ -d "$ROOT_DIR/.github" ]; then
    info ".github/ already active"
  else
    warn "_github/ not found — GitHub config will need manual setup"
  fi
fi

# ── 3. Make scripts executable ───────────────────────
find "$ROOT_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
find "$ROOT_DIR/tests/structural" -name "*.sh" -exec chmod +x {} \;
ok "Scripts made executable"

# ── 4. Create directories ────────────────────────────
mkdir -p "$ROOT_DIR/.worktrees"
mkdir -p "$ROOT_DIR/.deploy-artifacts"
mkdir -p "$ROOT_DIR/src"
ok "Directories created"

# ── 5. Persist database configuration ──────────────
if [ -n "$DB_ENGINE" ]; then
  echo ""

  # Store DATABASE_URL as GitHub secret
  if [ -n "$DATABASE_URL" ] && [ -n "$GITHUB_REPO" ] && gh repo view "$GITHUB_REPO" &>/dev/null; then
    echo "$DATABASE_URL" | gh secret set DATABASE_URL --repo "$GITHUB_REPO" 2>/dev/null && \
      ok "Set repo secret DATABASE_URL" || \
      warn "Failed to set DATABASE_URL secret — set it manually in repo Settings > Secrets"
  elif [ -n "$DATABASE_URL" ]; then
    warn "Add DATABASE_URL to your GitHub repo secrets"
  fi

  # Store provider API key as GitHub secret
  if [ -n "${DB_API_KEY:-}" ] && [ -n "$GITHUB_REPO" ] && gh repo view "$GITHUB_REPO" &>/dev/null; then
    echo "$DB_API_KEY" | gh secret set DB_API_KEY --repo "$GITHUB_REPO" 2>/dev/null && \
      ok "Set repo secret DB_API_KEY" || \
      warn "Failed to set DB_API_KEY secret — set it manually in repo Settings > Secrets"
  fi

  # Set GitHub repo variables
  if [ -n "$GITHUB_REPO" ] && gh repo view "$GITHUB_REPO" &>/dev/null; then
    gh variable set DB_ENGINE --body "$DB_ENGINE" --repo "$GITHUB_REPO" 2>/dev/null && \
      ok "Set repo variable DB_ENGINE=$DB_ENGINE" || \
      warn "Failed to set DB_ENGINE variable"

    gh variable set DB_ORM --body "$DB_ORM" --repo "$GITHUB_REPO" 2>/dev/null && \
      ok "Set repo variable DB_ORM=$DB_ORM" || \
      warn "Failed to set DB_ORM variable"

    gh variable set DB_HOSTING --body "$DB_HOSTING" --repo "$GITHUB_REPO" 2>/dev/null && \
      ok "Set repo variable DB_HOSTING=$DB_HOSTING" || \
      warn "Failed to set DB_HOSTING variable"
  else
    warn "Set GitHub repo variables manually: DB_ENGINE=$DB_ENGINE, DB_ORM=$DB_ORM, DB_HOSTING=$DB_HOSTING"
  fi

  # Write .env with DATABASE_URL if provided
  if [ -n "$DATABASE_URL" ]; then
    echo "DATABASE_URL=$DATABASE_URL" >> "$ROOT_DIR/.env"
    ok "Wrote DATABASE_URL to .env"
    # Make sure .env is gitignored
    if [ -f "$ROOT_DIR/.gitignore" ] && ! grep -q '^\.env$' "$ROOT_DIR/.gitignore"; then
      echo ".env" >> "$ROOT_DIR/.gitignore"
    fi
  fi

  # Write .env.example with placeholder
  DB_URL_PLACEHOLDER=""
  case "$DB_ENGINE" in
    "postgres") DB_URL_PLACEHOLDER="postgres://user:password@localhost:5432/dbname" ;;
    "mysql")    DB_URL_PLACEHOLDER="mysql://user:password@localhost:3306/dbname" ;;
    "sqlite")   DB_URL_PLACEHOLDER="file:./dev.db" ;;
    "mongodb")  DB_URL_PLACEHOLDER="mongodb+srv://user:password@cluster.example.net/dbname" ;;
    "redis")    DB_URL_PLACEHOLDER="redis://localhost:6379" ;;
  esac
  echo "DATABASE_URL=$DB_URL_PLACEHOLDER" >> "$ROOT_DIR/.env.example"
  ok "Wrote DATABASE_URL placeholder to .env.example"

  # ── 5b. Generate database layer (ORM config, models, migrations) ──
  if [ "$DB_ORM" != "none" ] && [ -n "$DB_ORM" ]; then
    echo ""
    info "Generating database layer for ${DB_ORM_CHOICE}..."

    DB_TARGET="$ROOT_DIR"
    [ "$IS_FULLSTACK" = true ] && DB_TARGET="$ROOT_DIR/backend"

    generate_database_layer "$DB_ORM" "$DB_ENGINE" "$STACK_LANG" "$DB_TARGET" "$EFFECTIVE_STACK"
  fi

  # Generate docker-compose.yml for local/self-hosted database
  if { [ "$DB_HOSTING" = "local" ] || [ "$DB_HOSTING" = "self-hosted" ]; } && [ "$DB_ENGINE" != "sqlite" ]; then
    if [ ! -f "$ROOT_DIR/docker-compose.yml" ]; then
      case "$DB_ENGINE" in
        postgres)
          cat > "$ROOT_DIR/docker-compose.yml" <<'DC_EOF'
services:
  db:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: app
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dev -d app"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
DC_EOF
          DATABASE_URL="${DATABASE_URL:-postgres://dev:dev@localhost:5432/app}"
          ok "Generated docker-compose.yml (PostgreSQL 16)"
          ;;
        mysql)
          cat > "$ROOT_DIR/docker-compose.yml" <<'DC_EOF'
services:
  db:
    image: mysql:8
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: dev
      MYSQL_DATABASE: app
      MYSQL_USER: dev
      MYSQL_PASSWORD: dev
    ports:
      - "3306:3306"
    volumes:
      - mysqldata:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  mysqldata:
DC_EOF
          DATABASE_URL="${DATABASE_URL:-mysql://dev:dev@localhost:3306/app}"
          ok "Generated docker-compose.yml (MySQL 8)"
          ;;
        mongodb)
          cat > "$ROOT_DIR/docker-compose.yml" <<'DC_EOF'
services:
  db:
    image: mongo:7
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: dev
      MONGO_INITDB_ROOT_PASSWORD: dev
    ports:
      - "27017:27017"
    volumes:
      - mongodata:/data/db
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  mongodata:
DC_EOF
          DATABASE_URL="${DATABASE_URL:-mongodb://dev:dev@localhost:27017/app}"
          ok "Generated docker-compose.yml (MongoDB 7)"
          ;;
        redis)
          cat > "$ROOT_DIR/docker-compose.yml" <<'DC_EOF'
services:
  db:
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  redisdata:
DC_EOF
          DATABASE_URL="${DATABASE_URL:-redis://localhost:6379}"
          ok "Generated docker-compose.yml (Redis 7)"
          ;;
      esac
      info "Run 'make db-up' to start the database, 'make db-down' to stop."
    fi
  fi
fi

# ── 6. Configure lint script ────────────────────────
if [ -n "$LINTER_CMD" ]; then
  cat > "$ROOT_DIR/scripts/checks/lint.sh" <<'LINT_HEADER'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "Running linters..."

LINT_HEADER

  # Append shellcheck
  cat >> "$ROOT_DIR/scripts/checks/lint.sh" <<'SHELLCHECK_BLOCK'
if command -v shellcheck &>/dev/null; then
  echo "  shellcheck: checking scripts/"
  find "$ROOT_DIR/scripts" -name "*.sh" -exec shellcheck -S warning {} + 2>&1 || {
    echo "WARNING: shellcheck found issues (see output above)"
  }
fi

SHELLCHECK_BLOCK

  # Append stack-specific linter
  cat >> "$ROOT_DIR/scripts/checks/lint.sh" <<LINT_BODY
echo "  Running project linter..."
cd "\$ROOT_DIR"
${LINTER_CMD}

echo "Lint complete."
LINT_BODY

  chmod +x "$ROOT_DIR/scripts/checks/lint.sh"
  ok "Configured lint script: $LINTER_CMD"
fi

# ── 7. Configure test script ────────────────────────
if [ -n "$TEST_CMD" ]; then
  cat > "$ROOT_DIR/scripts/checks/test.sh" <<TEST_EOF
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
cd "\$ROOT_DIR"

E2E=false
if [ "\${1:-}" = "--e2e" ]; then
  E2E=true
fi

# Check if any test files exist (common patterns across frameworks)
has_tests() {
  local dir="\${1:-.}"
  find "\$dir" -type f \\( \
    -name "*.test.*" -o -name "*.spec.*" -o -name "*_test.*" -o \
    -name "test_*" -o -name "*Test.*" -o -name "*_test.go" \
  \\) 2>/dev/null | head -1 | grep -q .
}

echo "Running tests..."

if [ "\$E2E" = true ]; then
  echo "  Running e2e tests..."
  ${E2E_CMD}
elif has_tests; then
  echo "  Running unit + integration tests..."
  ${TEST_CMD}
else
  echo "  No test files found — skipping (write tests in tests/)"
fi

echo "Tests complete."
TEST_EOF

  chmod +x "$ROOT_DIR/scripts/checks/test.sh"
  ok "Configured test script: $TEST_CMD"
fi

# ── 8. Configure CI workflow ─────────────────────────
if [ -n "$CI_SETUP_STEPS" ]; then
  cat > "$ROOT_DIR/.github/workflows/ci.yml" <<CI_EOF
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ci-\${{ github.ref }}
  cancel-in-progress: true

jobs:
  checks:
    name: All checks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

${CI_SETUP_STEPS}

      - name: Run all checks
        run: ./scripts/checks/run-all.sh
CI_EOF
  ok "Configured CI workflow"
fi

# ── 9. Configure setup.sh ───────────────────────────
cat > "$ROOT_DIR/scripts/setup.sh" <<SETUP_EOF
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="\$(cd "\$SCRIPT_DIR/.." && pwd)"

echo "Setting up project..."

find "\$ROOT_DIR/scripts" -name "*.sh" -exec chmod +x {} \\;
find "\$ROOT_DIR/tests/structural" -name "*.sh" -exec chmod +x {} \\;

mkdir -p "\$ROOT_DIR/.worktrees"
mkdir -p "\$ROOT_DIR/.deploy-artifacts"

SETUP_EOF

  if [ -n "$SETUP_CMD" ]; then
    cat >> "$ROOT_DIR/scripts/setup.sh" <<SETUP_STACK
echo "Installing dependencies..."
cd "\$ROOT_DIR"
${SETUP_CMD}

SETUP_STACK
  fi

  cat >> "$ROOT_DIR/scripts/setup.sh" <<'SETUP_TAIL'
echo "Setup complete. Run 'make check' to validate."
SETUP_TAIL

  chmod +x "$ROOT_DIR/scripts/setup.sh"
  ok "Configured setup script"

# ── 10. Configure agent in WORKFLOW.md ────────────────
if [ "$AGENT_CHOICE" != "None / I'll configure later" ]; then
  WORKFLOW_FILE="$ROOT_DIR/WORKFLOW.md"
  if [ -f "$WORKFLOW_FILE" ]; then
    case "$AGENT_CHOICE" in
      "Claude Code (Anthropic)")
        if grep -q '^  name: ' "$WORKFLOW_FILE" && grep -q '^  model: ' "$WORKFLOW_FILE"; then
          sed -i.bak 's/^  name: .*/  name: claude/' "$WORKFLOW_FILE"
          sed -i.bak 's/^  model: .*/  model: sonnet/' "$WORKFLOW_FILE"
          rm -f "${WORKFLOW_FILE}.bak"
          ok "Set agent to Claude Code in WORKFLOW.md"
        else
          warn "Could not find agent name/model fields in WORKFLOW.md — update manually"
        fi

        # Set agent secret on the repo if value was provided
        if [ -n "$AGENT_KEY_VALUE" ] && [ -n "$GITHUB_REPO" ]; then
          echo "$AGENT_KEY_VALUE" | gh secret set "$AGENT_KEY_NAME" --repo "$GITHUB_REPO" 2>/dev/null && \
            ok "Set repo secret $AGENT_KEY_NAME" || \
            warn "Failed to set $AGENT_KEY_NAME secret — set it manually in repo Settings > Secrets"
        else
          warn "Add $AGENT_KEY_NAME to your GitHub repo secrets"
          if [[ "$CLAUDE_AUTH_METHOD" == OAuth* ]]; then
            info "Generate a token with: claude setup-token"
          fi
        fi
        ;;
      "Codex (OpenAI)")
        if grep -q '^  name: ' "$WORKFLOW_FILE" && grep -q '^  model: ' "$WORKFLOW_FILE"; then
          sed -i.bak 's/^  name: .*/  name: codex/' "$WORKFLOW_FILE"
          sed -i.bak 's/^  model: .*/  model: o3/' "$WORKFLOW_FILE"
          rm -f "${WORKFLOW_FILE}.bak"
          ok "Set agent to Codex in WORKFLOW.md"
        else
          warn "Could not find agent name/model fields in WORKFLOW.md — update manually"
        fi

        if [ -n "$AGENT_KEY_VALUE" ] && [ -n "$GITHUB_REPO" ]; then
          echo "$AGENT_KEY_VALUE" | gh secret set OPENAI_API_KEY --repo "$GITHUB_REPO" 2>/dev/null && \
            ok "Set repo secret OPENAI_API_KEY" || \
            warn "Failed to set OPENAI_API_KEY secret — set it manually in repo Settings > Secrets"
        else
          warn "Add OPENAI_API_KEY to your GitHub repo secrets"
        fi
        ;;
    esac
  fi
fi

# ── 10b. Configure monitoring ──────────────────────
if [ "$MONITOR_CHOICE" != "None / I'll configure later" ]; then
  echo ""

  # Store MONITOR_CHOICE as a GitHub repo variable
  if [ -n "$GITHUB_REPO" ]; then
    MONITOR_CHOICE_VALUE=""
    case "$MONITOR_CHOICE" in
      "Sentry")  MONITOR_CHOICE_VALUE="sentry" ;;
      "Datadog") MONITOR_CHOICE_VALUE="datadog" ;;
      "Grafana") MONITOR_CHOICE_VALUE="grafana" ;;
    esac

    gh variable set MONITOR_CHOICE --body "$MONITOR_CHOICE_VALUE" --repo "$GITHUB_REPO" 2>/dev/null && \
      ok "Set repo variable MONITOR_CHOICE=$MONITOR_CHOICE_VALUE" || \
      warn "Failed to set MONITOR_CHOICE variable — set it manually in repo Settings > Variables"
  fi

  # Store MONITOR_DSN as a GitHub secret and write to .env
  if [ -n "$MONITOR_DSN" ] && [ -n "$GITHUB_REPO" ]; then
    echo "$MONITOR_DSN" | gh secret set MONITOR_DSN --repo "$GITHUB_REPO" 2>/dev/null && \
      ok "Set repo secret MONITOR_DSN" || \
      warn "Failed to set MONITOR_DSN secret — set it manually in repo Settings > Secrets"
  elif [ -z "$MONITOR_DSN" ]; then
    warn "No DSN provided — add MONITOR_DSN to your GitHub repo secrets later"
  fi

  # Write MONITOR_DSN to .env (actual value or placeholder)
  ENV_FILE="$ROOT_DIR/.env"
  if [ -n "$MONITOR_DSN" ]; then
    echo "MONITOR_DSN=$MONITOR_DSN" >> "$ENV_FILE"
    ok "Wrote MONITOR_DSN to .env"
  else
    echo "MONITOR_DSN=" >> "$ENV_FILE"
    ok "Wrote MONITOR_DSN placeholder to .env (fill in later)"
  fi

  # Copy provider-specific alert and dashboard configs, remove others
  MONITOR_DIR="$ROOT_DIR/monitoring"
  ALERT_PREFIX=""
  DASH_PREFIX=""
  case "$MONITOR_CHOICE" in
    "Sentry")  ALERT_PREFIX="sentry"; DASH_PREFIX="sentry" ;;
    "Datadog") ALERT_PREFIX="datadog"; DASH_PREFIX="datadog" ;;
    "Grafana") ALERT_PREFIX="grafana"; DASH_PREFIX="grafana" ;;
  esac

  if [ -n "$ALERT_PREFIX" ]; then
    # Remove non-matching provider configs from alerts/
    for f in "$MONITOR_DIR/alerts/"*.json; do
      [ -f "$f" ] || continue
      case "$(basename "$f")" in
        ${ALERT_PREFIX}*) ;; # keep
        *) rm -f "$f" ;;
      esac
    done
    # Remove non-matching provider configs from dashboards/
    for f in "$MONITOR_DIR/dashboards/"*.json; do
      [ -f "$f" ] || continue
      case "$(basename "$f")" in
        ${DASH_PREFIX}*) ;; # keep
        *) rm -f "$f" ;;
      esac
    done
    ok "Kept ${MONITOR_CHOICE} monitoring configs, removed other providers"
  fi

  echo ""
  info "Monitoring configured: ${MONITOR_CHOICE}"
  [ -n "$MONITOR_DSN" ] && info "DSN stored as GitHub secret and in .env"

  # ── 10c. Generate monitoring SDK init code ──────────
  MONITOR_PROVIDER_KEY=""
  case "$MONITOR_CHOICE" in
    "Sentry")  MONITOR_PROVIDER_KEY="sentry" ;;
    "Datadog") MONITOR_PROVIDER_KEY="datadog" ;;
    "Grafana") MONITOR_PROVIDER_KEY="grafana" ;;
  esac

  if [ -n "$MONITOR_PROVIDER_KEY" ] && [ -n "$STACK_FAMILY" ]; then
    echo ""
    info "Generating ${MONITOR_CHOICE} SDK initialization code..."

    if [ "$IS_FULLSTACK" = true ]; then
      # For fullstack: generate monitoring in the backend directory
      generate_monitoring_sdk "$MONITOR_PROVIDER_KEY" "$BE_FAMILY" "$BACKEND_STACK" "$ROOT_DIR/backend"
      # Also generate for frontend if it's a different family
      if [ "$FE_FAMILY" != "$BE_FAMILY" ]; then
        generate_monitoring_sdk "$MONITOR_PROVIDER_KEY" "$FE_FAMILY" "$FRONTEND_STACK" "$ROOT_DIR/frontend"
      fi
    else
      generate_monitoring_sdk "$MONITOR_PROVIDER_KEY" "$STACK_FAMILY" "$STACK" "$ROOT_DIR"
    fi
  elif [ -n "$MONITOR_PROVIDER_KEY" ]; then
    # Unknown stack family — generate manual instructions
    generate_monitoring_sdk "$MONITOR_PROVIDER_KEY" "unknown" "${STACK:-None}" "$ROOT_DIR"
  fi

  # ── 10d. Generate smoke-test script ──────────────────
  info "Generating monitoring smoke-test script..."
  mkdir -p "$ROOT_DIR/scripts/monitoring"
  cat > "$ROOT_DIR/scripts/monitoring/smoke-test.sh" <<'SMOKE_HEADER'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "Running monitoring smoke test..."

if [ -z "${MONITOR_DSN:-}" ]; then
  if [ -f "$ROOT_DIR/.env" ]; then
    # shellcheck disable=SC1091
    set -a; source "$ROOT_DIR/.env"; set +a
  fi
fi

if [ -z "${MONITOR_DSN:-}" ]; then
  echo "ERROR: MONITOR_DSN is not set. Set it in .env or as an environment variable."
  exit 1
fi

echo "  MONITOR_DSN is configured"

SMOKE_HEADER

  # Append provider-specific smoke test
  case "$MONITOR_PROVIDER_KEY" in
    sentry)
      cat >> "$ROOT_DIR/scripts/monitoring/smoke-test.sh" <<'SMOKE_SENTRY'
echo "  Sending test event to Sentry..."

# Extract the Sentry API endpoint from the DSN
# DSN format: https://<key>@<host>/<project-id>
SENTRY_KEY=$(echo "$MONITOR_DSN" | sed -n 's|https://\([^@]*\)@.*|\1|p')
SENTRY_HOST=$(echo "$MONITOR_DSN" | sed -n 's|https://[^@]*@\([^/]*\)/.*|\1|p')
SENTRY_PROJECT=$(echo "$MONITOR_DSN" | sed -n 's|.*/\([0-9]*\)$|\1|p')

if [ -z "$SENTRY_KEY" ] || [ -z "$SENTRY_HOST" ] || [ -z "$SENTRY_PROJECT" ]; then
  echo "ERROR: Could not parse Sentry DSN. Check the format: https://<key>@<host>/<project-id>"
  exit 1
fi

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://${SENTRY_HOST}/api/${SENTRY_PROJECT}/store/" \
  -H "Content-Type: application/json" \
  -H "X-Sentry-Auth: Sentry sentry_version=7,sentry_key=${SENTRY_KEY}" \
  -d '{
    "event_id": "'$(uuidgen 2>/dev/null | tr -d '-' | tr '[:upper:]' '[:lower:]' || python3 -c "import uuid; print(uuid.uuid4().hex)")'",
    "message": "Monitoring smoke test from make monitor-test",
    "level": "info",
    "platform": "other"
  }')

if [ "$RESPONSE" -eq 200 ]; then
  echo "  ✓ Test event sent successfully. Check your Sentry dashboard."
else
  echo "  ✗ Sentry returned HTTP $RESPONSE. Verify your DSN."
  exit 1
fi
SMOKE_SENTRY
      ;;
    datadog)
      cat >> "$ROOT_DIR/scripts/monitoring/smoke-test.sh" <<'SMOKE_DD'
echo "  Sending test event to Datadog..."

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://api.datadoghq.com/api/v1/events" \
  -H "Content-Type: application/json" \
  -H "DD-API-KEY: ${MONITOR_DSN}" \
  -d '{
    "title": "Monitoring smoke test",
    "text": "Test event from make monitor-test",
    "priority": "low",
    "alert_type": "info"
  }')

if [ "$RESPONSE" -eq 202 ]; then
  echo "  ✓ Test event sent successfully. Check your Datadog Events dashboard."
else
  echo "  ✗ Datadog returned HTTP $RESPONSE. Verify your API key."
  exit 1
fi
SMOKE_DD
      ;;
    grafana)
      cat >> "$ROOT_DIR/scripts/monitoring/smoke-test.sh" <<'SMOKE_GRAFANA'
echo "  Checking OTLP endpoint connectivity..."

OTEL_ENDPOINT="${MONITOR_DSN%/}"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  "${OTEL_ENDPOINT}/v1/traces" \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[]}' \
  2>/dev/null || echo "000")

if [ "$RESPONSE" -eq 200 ] || [ "$RESPONSE" -eq 204 ]; then
  echo "  ✓ OTLP endpoint is reachable. Monitoring pipeline is ready."
elif [ "$RESPONSE" -eq 000 ]; then
  echo "  ✗ Could not reach OTLP endpoint at ${OTEL_ENDPOINT}. Check your MONITOR_DSN."
  exit 1
else
  echo "  ⚠ OTLP endpoint returned HTTP $RESPONSE. It may still work — check your Grafana dashboard."
fi
SMOKE_GRAFANA
      ;;
  esac

  cat >> "$ROOT_DIR/scripts/monitoring/smoke-test.sh" <<'SMOKE_FOOTER'

echo ""
echo "Smoke test complete."
SMOKE_FOOTER

  chmod +x "$ROOT_DIR/scripts/monitoring/smoke-test.sh"
  ok "Generated scripts/monitoring/smoke-test.sh"
fi

# ── 11. Create GitHub labels ────────────────────────
if [ "$CREATE_LABELS" = true ] && [ -n "$GITHUB_REPO" ]; then
  echo ""
  # Verify the repo exists before trying to create labels
  if ! gh repo view "$GITHUB_REPO" &>/dev/null; then
    warn "Repository $GITHUB_REPO not found on GitHub — skipping label creation"
    info "Create labels later with: make setup  (or manually in Settings > Labels)"
  else
    info "Creating labels on $GITHUB_REPO..."

    create_label() {
      local name="$1" color="$2" desc="$3"
      local exit_code=0
      OUTPUT=$(gh label create "$name" --repo "$GITHUB_REPO" --color "$color" --description "$desc" 2>&1) || exit_code=$?
      if [ $exit_code -eq 0 ]; then
        ok "Label: $name"
      elif echo "$OUTPUT" | grep -qi "already exists"; then
        info "Label '$name' already exists"
      else
        warn "Failed to create label '$name': $OUTPUT"
      fi
    }

    create_label "ready"        "0E8A16" "Issue is ready for agent work"
    create_label "agent"        "5319E7" "Handle with AI agent"
    create_label "in-progress"  "FBCA04" "Agent is working on this"
    create_label "human-review" "0075CA" "PR ready for human review"
    create_label "p0"           "B60205" "Critical priority"
    create_label "p1"           "D93F0B" "High priority"
    create_label "p2"           "FBCA04" "Normal priority"
    create_label "story"        "C5DEF5" "User story"
  fi
fi

# ── 11b. Create GitHub Project board ─────────────────
if [ "$CREATE_PROJECT" = true ] && [ -n "$GITHUB_REPO" ]; then
  echo ""
  OWNER=$(echo "$GITHUB_REPO" | cut -d/ -f1)

  # Detect account type (Organization vs User) for correct project URL
  ACCOUNT_TYPE=$(gh api "users/$OWNER" --jq '.type' 2>/dev/null || echo "User")
  if [ "$ACCOUNT_TYPE" = "Organization" ]; then
    PROJECT_URL_PREFIX="orgs"
  else
    PROJECT_URL_PREFIX="users"
  fi
  info "Account type: $ACCOUNT_TYPE ($PROJECT_URL_PREFIX)"

  # Ensure gh CLI has project scopes
  SCOPES=$(gh auth status 2>&1 || true)
  if ! echo "$SCOPES" | grep -q "project"; then
    info "Your gh CLI token needs 'project' scopes to create and manage projects."
    info "This will open a browser to approve the additional permissions."
    if confirm "Grant project permissions now?"; then
      gh auth refresh -s project,read:project 2>&1 || {
        warn "Failed to refresh scopes. Run manually: gh auth refresh -s project,read:project"
      }
      # gh auth refresh can corrupt terminal settings (interactive browser flow)
      stty sane 2>/dev/null || true
    else
      warn "Skipping project creation — missing required scopes."
      warn "Run later: gh auth refresh -s project,read:project"
      CREATE_PROJECT=false
    fi
  fi
fi

if [ "$CREATE_PROJECT" = true ] && [ -n "$GITHUB_REPO" ]; then
  # Create the project
  PROJECT_CREATE_EXIT=0
  PROJECT_NUMBER=$(gh project create --owner "$OWNER" --title "$PROJECT_NAME" --format json --jq '.number' 2>&1) || PROJECT_CREATE_EXIT=$?

  if [ $PROJECT_CREATE_EXIT -eq 0 ] && [ -n "$PROJECT_NUMBER" ]; then
    PROJECT_BOARD_URL="https://github.com/${PROJECT_URL_PREFIX}/${OWNER}/projects/${PROJECT_NUMBER}"
    ok "Created GitHub Project #${PROJECT_NUMBER}: $PROJECT_BOARD_URL"

    # Set repo variables (GITHUB_ prefix is reserved by Actions, so use PROJECT_)
    gh variable set PROJECT_URL --body "$PROJECT_BOARD_URL" --repo "$GITHUB_REPO" 2>/dev/null && \
      ok "Set repo variable PROJECT_URL" || \
      warn "Failed to set PROJECT_URL variable — set it manually in repo Settings > Variables"

    gh variable set PROJECT_NUMBER --body "$PROJECT_NUMBER" --repo "$GITHUB_REPO" 2>/dev/null && \
      ok "Set repo variable PROJECT_NUMBER=$PROJECT_NUMBER" || \
      warn "Failed to set PROJECT_NUMBER variable — set it manually in repo Settings > Variables"

    # Set PROJECT_TOKEN secret using the current gh CLI token (which now has project scopes)
    GH_TOKEN=$(gh auth token 2>/dev/null || true)
    if [ -n "$GH_TOKEN" ]; then
      info "Your current gh CLI token (with project scopes) can be used as PROJECT_TOKEN."
      if confirm "Set your gh CLI token as the PROJECT_TOKEN repo secret?"; then
        echo "$GH_TOKEN" | gh secret set PROJECT_TOKEN --repo "$GITHUB_REPO" 2>/dev/null && \
          ok "Set repo secret PROJECT_TOKEN" || \
          warn "Failed to set PROJECT_TOKEN secret — set it manually in repo Settings > Secrets"
      else
        warn "Set PROJECT_TOKEN manually: repo Settings > Secrets > New repository secret"
        info "Create a PAT at github.com/settings/tokens with 'project' scope"
      fi
    else
      warn "Could not read gh CLI token."
      warn "Set PROJECT_TOKEN manually: repo Settings > Secrets > New repository secret"
      info "Create a PAT at github.com/settings/tokens with 'project' scope"
    fi

    # Set up Status field columns to match our label workflow.
    # New projects have a default "Status" field — update its options via GraphQL.
    info "Configuring project board columns..."

    STATUS_FIELD_ID=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json \
      --jq '.fields[] | select(.name == "Status") | .id' 2>/dev/null || true)

    if [ -n "$STATUS_FIELD_ID" ]; then
      gh api graphql -f query="
        mutation {
          updateProjectV2Field(input: {
            fieldId: \"$STATUS_FIELD_ID\"
            singleSelectOptions: [
              {name: \"Backlog\", color: GRAY, description: \"Not yet scheduled\"}
              {name: \"Ready\", color: GREEN, description: \"Ready for work\"}
              {name: \"In Progress\", color: YELLOW, description: \"Being worked on\"}
              {name: \"Under Review\", color: BLUE, description: \"PR open, awaiting review\"}
              {name: \"Done\", color: PURPLE, description: \"Complete\"}
            ]
          }) {
            projectV2Field { ... on ProjectV2SingleSelectField { name } }
          }
        }" >/dev/null 2>&1 && \
        ok "Status columns: Backlog → Ready → In Progress → Under Review → Done" || \
        warn "Failed to configure Status columns — set them manually in the project"
    else
      warn "Status field not found on project — configure columns manually"
    fi
  else
    fail "Failed to create GitHub Project: $PROJECT_NUMBER"
    info "Create one manually at https://github.com/${PROJECT_URL_PREFIX}/${OWNER}/projects"
    PROJECT_BOARD_URL=""
  fi
fi

# ── 11c. Configure deploy mode ──────────────────────
if [ -n "$DEPLOY_PROVIDER_KEY" ] && [ "$DEPLOY_MODE" != "custom" ] && [ "$DEPLOY_MODE" != "none" ]; then
  echo ""

  case "$DEPLOY_MODE" in
    native)
      # ── Native mode: service handles deploys via Git integration ──
      info "Configuring native ${DEPLOY_PROVIDER} integration..."

      # Store DEPLOY_TOKEN as GitHub secret
      if [ -n "$DEPLOY_TOKEN" ] && [ -n "$GITHUB_REPO" ]; then
        SECRET_NAME="DEPLOY_TOKEN"
        [ "$DEPLOY_PROVIDER_KEY" = "fly" ] && SECRET_NAME="FLY_API_TOKEN"
        echo "$DEPLOY_TOKEN" | gh secret set "$SECRET_NAME" --repo "$GITHUB_REPO" 2>/dev/null && \
          ok "Set repo secret $SECRET_NAME" || \
          warn "Failed to set $SECRET_NAME — set it manually in repo Settings > Secrets"
      elif [ -n "$GITHUB_REPO" ]; then
        SECRET_NAME="DEPLOY_TOKEN"
        [ "$DEPLOY_PROVIDER_KEY" = "fly" ] && SECRET_NAME="FLY_API_TOKEN"
        warn "Add $SECRET_NAME to your GitHub repo secrets"
      fi

      # Store DEPLOY_MODE as GitHub repo variable
      if [ -n "$GITHUB_REPO" ]; then
        gh variable set DEPLOY_MODE --body "native" --repo "$GITHUB_REPO" 2>/dev/null && \
          ok "Set repo variable DEPLOY_MODE=native" || \
          warn "Failed to set DEPLOY_MODE variable"
      fi

      # Run provider-specific link/init CLI
      case "$DEPLOY_PROVIDER_KEY" in
        vercel)
          if command -v vercel &>/dev/null; then
            if confirm "Run 'vercel link' to connect this repo to Vercel?"; then
              VERCEL_LINK_ARGS=""
              [ -n "$DEPLOY_TOKEN" ] && VERCEL_LINK_ARGS="--token $DEPLOY_TOKEN"
              vercel link $VERCEL_LINK_ARGS --yes 2>&1 || warn "vercel link failed — run it manually later"
            fi
          else
            warn "Vercel CLI not found. Install with: npm i -g vercel"
            info "Then run: vercel link"
          fi

          # Generate vercel.json
          if [ ! -f "$ROOT_DIR/vercel.json" ]; then
            if [ -n "$DB_ENGINE" ] && [ "${DB_ORM:-none}" != "none" ]; then
              cat > "$ROOT_DIR/vercel.json" <<'VERCEL_NATIVE_EOF'
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "buildCommand": "./scripts/deploy/db-migrate.sh && npm run build",
  "outputDirectory": "dist",
  "installCommand": "npm ci"
}
VERCEL_NATIVE_EOF
              ok "Generated vercel.json with migration in buildCommand"
              info "Set DATABASE_URL in Vercel project environment variables."
            else
              cat > "$ROOT_DIR/vercel.json" <<'VERCEL_NATIVE_EOF'
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "installCommand": "npm ci"
}
VERCEL_NATIVE_EOF
              ok "Generated vercel.json (edit buildCommand/outputDirectory for your stack)"
            fi
          fi
          ;;

        netlify)
          if command -v netlify &>/dev/null; then
            if confirm "Run 'netlify init' to connect this repo to Netlify?"; then
              [ -n "$DEPLOY_TOKEN" ] && export NETLIFY_AUTH_TOKEN="$DEPLOY_TOKEN"
              netlify init 2>&1 || warn "netlify init failed — run it manually later"
            fi
          else
            warn "Netlify CLI not found. Install with: npm i -g netlify-cli"
            info "Then run: netlify init"
          fi

          # Generate netlify.toml if not created by netlify init
          if [ ! -f "$ROOT_DIR/netlify.toml" ]; then
            if [ -n "$DB_ENGINE" ] && [ "${DB_ORM:-none}" != "none" ]; then
              cat > "$ROOT_DIR/netlify.toml" <<'NETLIFY_NATIVE_EOF'
[build]
  command = "./scripts/deploy/db-migrate.sh && npm run build"
  publish = "dist"

[build.environment]
  NODE_VERSION = "22"

# PR deploy previews are handled automatically by Netlify's Git integration
NETLIFY_NATIVE_EOF
              ok "Generated netlify.toml with migration in build command"
              info "Set DATABASE_URL in Netlify site environment variables."
            else
              cat > "$ROOT_DIR/netlify.toml" <<'NETLIFY_NATIVE_EOF'
[build]
  command = "npm run build"
  publish = "dist"

[build.environment]
  NODE_VERSION = "22"

# PR deploy previews are handled automatically by Netlify's Git integration
NETLIFY_NATIVE_EOF
              ok "Generated netlify.toml (edit command/publish for your stack)"
            fi
          fi
          ;;

        cloudflare)
          if command -v wrangler &>/dev/null; then
            if confirm "Run 'wrangler pages project create' to set up Cloudflare Pages?"; then
              [ -n "$DEPLOY_TOKEN" ] && export CLOUDFLARE_API_TOKEN="$DEPLOY_TOKEN"
              CF_PROJECT="${DEPLOY_PROJECT_ID:-$PROJECT_NAME}"
              wrangler pages project create "$CF_PROJECT" --production-branch main 2>&1 || \
                warn "wrangler pages project create failed — run it manually later"
            fi
          else
            warn "Wrangler CLI not found. Install with: npm i -g wrangler"
            info "Then run: wrangler pages project create ${DEPLOY_PROJECT_ID:-$PROJECT_NAME}"
          fi

          # Generate wrangler.toml
          if [ ! -f "$ROOT_DIR/wrangler.toml" ]; then
            CF_PROJECT="${DEPLOY_PROJECT_ID:-$PROJECT_NAME}"
            cat > "$ROOT_DIR/wrangler.toml" <<WRANGLER_NATIVE_EOF
name = "${CF_PROJECT}"
compatibility_date = "$(date +%Y-%m-%d)"
pages_build_output_dir = "dist"

# Cloudflare Pages handles PR previews and production deploys via Git integration
WRANGLER_NATIVE_EOF
            ok "Generated wrangler.toml (edit pages_build_output_dir for your stack)"
          fi
          ;;

        fly)
          if command -v fly &>/dev/null; then
            if confirm "Run 'fly launch' to set up your Fly.io app?"; then
              [ -n "$DEPLOY_TOKEN" ] && export FLY_API_TOKEN="$DEPLOY_TOKEN"
              fly launch --no-deploy 2>&1 || warn "fly launch failed — run it manually later"
            fi
          else
            warn "Fly CLI not found. Install from: https://fly.io/docs/hands-on/install-flyctl/"
            info "Then run: fly launch --no-deploy"
          fi

          # Add release_command for migrations if fly.toml exists
          if [ -n "$DB_ENGINE" ] && [ "${DB_ORM:-none}" != "none" ] && [ -f "$ROOT_DIR/fly.toml" ]; then
            if ! grep -q 'release_command' "$ROOT_DIR/fly.toml"; then
              cat >> "$ROOT_DIR/fly.toml" <<'FLY_NATIVE_RELEASE_EOF'

[deploy]
  release_command = "./scripts/deploy/db-migrate.sh"
FLY_NATIVE_RELEASE_EOF
              ok "Added release_command for migrations to fly.toml"
            fi
          fi

          echo ""
          warn "Fly.io native mode: only production deploys on main are automatic."
          info "PR preview deploys are not available in native mode."
          if [ -n "$DB_ENGINE" ] && [ "${DB_ORM:-none}" != "none" ]; then
            info "PR preview DB isolation requires scripts mode. Consider switching if needed."
          fi
          ;;
      esac

      # Remove deploy workflows (not needed in native mode)
      for wf in pr-deploy.yml pr-cleanup.yml deploy-production.yml; do
        if [ -f "$ROOT_DIR/.github/workflows/$wf" ]; then
          rm "$ROOT_DIR/.github/workflows/$wf"
        fi
      done
      ok "Removed deploy workflows (native mode — service handles deploys)"

      # Replace deploy scripts with stubs (not needed)
      for script in pr-preview.sh pr-cleanup.sh production.sh; do
        if [ -f "$ROOT_DIR/scripts/deploy/$script" ]; then
          cat > "$ROOT_DIR/scripts/deploy/$script" <<NATIVE_STUB_EOF
#!/usr/bin/env bash
# Deploy mode: native
# ${DEPLOY_PROVIDER} handles deploys via its Git integration.
# This script is not used. See docs/DEPLOY.md for details.
echo "Deploy mode is 'native'. ${DEPLOY_PROVIDER} handles deploys automatically."
echo "See docs/DEPLOY.md for details."
exit 0
NATIVE_STUB_EOF
          chmod +x "$ROOT_DIR/scripts/deploy/$script"
        fi
      done
      ok "Replaced deploy scripts with stubs (not needed in native mode)"

      # Summary
      echo ""
      echo -e "  ${BOLD}Deploy summary (native mode):${RESET}"
      echo -e "    Provider: ${CYAN}${DEPLOY_PROVIDER}${RESET}"
      echo -e "    Mode:     ${CYAN}native — service handles deploys via Git integration${RESET}"
      echo -e "    Workflows removed: pr-deploy.yml, pr-cleanup.yml, deploy-production.yml"
      case "$DEPLOY_PROVIDER_KEY" in
        vercel)     [ -f "$ROOT_DIR/vercel.json" ] && echo -e "    Config:   vercel.json" ;;
        netlify)    [ -f "$ROOT_DIR/netlify.toml" ] && echo -e "    Config:   netlify.toml" ;;
        cloudflare) [ -f "$ROOT_DIR/wrangler.toml" ] && echo -e "    Config:   wrangler.toml" ;;
        fly)        [ -f "$ROOT_DIR/fly.toml" ] && echo -e "    Config:   fly.toml" ;;
      esac
      ;;

    scripts)
      # ── Scripts mode: GitHub Actions handle deploys ──
      info "Configuring GitHub Actions deploy mode for ${DEPLOY_PROVIDER}..."

      # Store DEPLOY_TOKEN as GitHub secret
      if [ -n "$DEPLOY_TOKEN" ] && [ -n "$GITHUB_REPO" ]; then
        echo "$DEPLOY_TOKEN" | gh secret set DEPLOY_TOKEN --repo "$GITHUB_REPO" 2>/dev/null && \
          ok "Set repo secret DEPLOY_TOKEN" || \
          warn "Failed to set DEPLOY_TOKEN — set it manually in repo Settings > Secrets"
      elif [ -n "$GITHUB_REPO" ]; then
        warn "Add DEPLOY_TOKEN to your GitHub repo secrets"
      fi

      # Store DEPLOY_PROVIDER and DEPLOY_PROJECT_ID as GitHub repo variables
      if [ -n "$GITHUB_REPO" ]; then
        gh variable set DEPLOY_PROVIDER --body "$DEPLOY_PROVIDER_KEY" --repo "$GITHUB_REPO" 2>/dev/null && \
          ok "Set repo variable DEPLOY_PROVIDER=$DEPLOY_PROVIDER_KEY" || \
          warn "Failed to set DEPLOY_PROVIDER variable"

        if [ -n "$DEPLOY_PROJECT_ID" ]; then
          gh variable set DEPLOY_PROJECT_ID --body "$DEPLOY_PROJECT_ID" --repo "$GITHUB_REPO" 2>/dev/null && \
            ok "Set repo variable DEPLOY_PROJECT_ID=$DEPLOY_PROJECT_ID" || \
            warn "Failed to set DEPLOY_PROJECT_ID variable"
        fi

        gh variable set DEPLOY_MODE --body "scripts" --repo "$GITHUB_REPO" 2>/dev/null && \
          ok "Set repo variable DEPLOY_MODE=scripts" || \
          warn "Failed to set DEPLOY_MODE variable"
      fi

      # Uncomment build step in deploy workflows if CI steps are known
      if [ -n "$CI_SETUP_STEPS" ]; then
        for wf in pr-deploy.yml deploy-production.yml; do
          WF_FILE="$ROOT_DIR/.github/workflows/$wf"
          if [ -f "$WF_FILE" ]; then
            DEPLOY_WF_MARKER="      # TODO: Uncomment and configure for your"
            if grep -q "$DEPLOY_WF_MARKER" "$WF_FILE" 2>/dev/null; then
              DEPLOY_WF_TEMP=$(mktemp)
              if CI_SETUP_STEPS_AWK="$CI_SETUP_STEPS" awk -v marker="$DEPLOY_WF_MARKER" '
                $0 ~ marker {
                  print ENVIRON["CI_SETUP_STEPS_AWK"]
                  while (getline > 0 && /^      # /) {}
                  print
                  next
                }
                { print }
              ' "$WF_FILE" > "$DEPLOY_WF_TEMP" && [ -s "$DEPLOY_WF_TEMP" ]; then
                mv "$DEPLOY_WF_TEMP" "$WF_FILE"
              else
                rm -f "$DEPLOY_WF_TEMP"
              fi
            fi
          fi
        done
        ok "Configured build steps in deploy workflows"
      fi

      # Optionally generate provider config file
      case "$DEPLOY_PROVIDER_KEY" in
        vercel)
          if [ ! -f "$ROOT_DIR/vercel.json" ] && confirm "Generate vercel.json with defaults?"; then
            cat > "$ROOT_DIR/vercel.json" <<'VERCEL_SCRIPTS_EOF'
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "installCommand": "npm ci"
}
VERCEL_SCRIPTS_EOF
            ok "Generated vercel.json"
          fi
          ;;
        netlify)
          if [ ! -f "$ROOT_DIR/netlify.toml" ] && confirm "Generate netlify.toml with defaults?"; then
            cat > "$ROOT_DIR/netlify.toml" <<'NETLIFY_SCRIPTS_EOF'
[build]
  command = "npm run build"
  publish = "dist"

[build.environment]
  NODE_VERSION = "22"
NETLIFY_SCRIPTS_EOF
            ok "Generated netlify.toml"
          fi
          ;;
        cloudflare)
          if [ ! -f "$ROOT_DIR/wrangler.toml" ] && confirm "Generate wrangler.toml with defaults?"; then
            CF_PROJECT_S="${DEPLOY_PROJECT_ID:-$PROJECT_NAME}"
            cat > "$ROOT_DIR/wrangler.toml" <<WRANGLER_SCRIPTS_EOF
name = "${CF_PROJECT_S}"
compatibility_date = "$(date +%Y-%m-%d)"
pages_build_output_dir = "dist"
WRANGLER_SCRIPTS_EOF
            ok "Generated wrangler.toml"
          fi
          ;;
        fly)
          FLY_APP_S="${DEPLOY_PROJECT_ID:-$PROJECT_NAME}"
          if [ ! -f "$ROOT_DIR/fly.toml" ] && confirm "Generate fly.toml with defaults?"; then
            cat > "$ROOT_DIR/fly.toml" <<FLY_SCRIPTS_EOF
app = "${FLY_APP_S}"
primary_region = "iad"

[build]

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = "stop"
  auto_start_machines = true
  min_machines_running = 0
FLY_SCRIPTS_EOF

            # Add release_command for database migrations
            if [ -n "$DB_ENGINE" ] && [ "${DB_ORM:-none}" != "none" ]; then
              cat >> "$ROOT_DIR/fly.toml" <<'FLY_RELEASE_EOF'

[deploy]
  release_command = "./scripts/deploy/db-migrate.sh"
FLY_RELEASE_EOF
              ok "Generated fly.toml with release_command for migrations"
            else
              ok "Generated fly.toml"
            fi
          fi

          # Provision Fly Postgres if self-hosted DB was selected
          if [ "$DB_HOSTING" = "self-hosted" ] && [ "$DB_ENGINE" = "postgres" ]; then
            echo ""
            if command -v fly &>/dev/null; then
              if confirm "Create a Fly Postgres cluster for this app?"; then
                FLY_DB_NAME="${FLY_APP_S}-db"
                [ -n "${DEPLOY_TOKEN:-}" ] && export FLY_API_TOKEN="$DEPLOY_TOKEN"
                if fly postgres create --name "$FLY_DB_NAME" --region iad 2>&1; then
                  ok "Created Fly Postgres cluster: ${FLY_DB_NAME}"
                  if fly postgres attach "$FLY_DB_NAME" --app "$FLY_APP_S" 2>&1; then
                    ok "Attached ${FLY_DB_NAME} to ${FLY_APP_S}"
                    info "DATABASE_URL has been set as a Fly secret automatically."
                  else
                    warn "Failed to attach Postgres — run: fly postgres attach ${FLY_DB_NAME} --app ${FLY_APP_S}"
                  fi
                else
                  warn "Failed to create Fly Postgres — run: fly postgres create --name ${FLY_DB_NAME}"
                fi
              fi
            else
              info "Install Fly CLI to provision Fly Postgres: https://fly.io/docs/hands-on/install-flyctl/"
              info "Then run: fly postgres create --name ${FLY_APP_S}-db && fly postgres attach ${FLY_APP_S}-db --app ${FLY_APP_S}"
            fi
          fi
          ;;
      esac

      ok "Deploy workflows active: pr-deploy.yml, pr-cleanup.yml, deploy-production.yml"

      # Summary
      echo ""
      echo -e "  ${BOLD}Deploy summary (scripts mode):${RESET}"
      echo -e "    Provider: ${CYAN}${DEPLOY_PROVIDER}${RESET}"
      echo -e "    Mode:     ${CYAN}scripts — GitHub Actions handle deploys${RESET}"
      echo -e "    Workflows: pr-deploy.yml, pr-cleanup.yml, deploy-production.yml"
      echo -e "    Scripts:   scripts/deploy/pr-preview.sh, pr-cleanup.sh, production.sh"
      ;;
  esac

elif [ "$DEPLOY_MODE" = "custom" ]; then
  # ── Custom: keep stubs, print instructions ──
  echo ""
  info "Custom deploy provider: script stubs and workflows kept for manual configuration."
  info "Edit scripts/deploy/pr-preview.sh and pr-cleanup.sh with your deploy logic."
  info "Contract: write the preview URL to .deploy-artifacts/preview-url.txt"

  if [ -n "$GITHUB_REPO" ]; then
    gh variable set DEPLOY_PROVIDER --body "custom" --repo "$GITHUB_REPO" 2>/dev/null && \
      ok "Set repo variable DEPLOY_PROVIDER=custom" || true
    gh variable set DEPLOY_MODE --body "scripts" --repo "$GITHUB_REPO" 2>/dev/null && \
      ok "Set repo variable DEPLOY_MODE=scripts" || true
  fi

  echo ""
  echo -e "  ${BOLD}Deploy summary (custom):${RESET}"
  echo -e "    Provider: ${CYAN}Custom${RESET}"
  echo -e "    Workflows and script stubs kept — configure manually"

elif [ "$DEPLOY_MODE" = "none" ]; then
  # ── None: remove deploy workflows and scripts ──
  echo ""
  info "No deploy provider selected. Removing deploy workflows and scripts..."

  for wf in pr-deploy.yml pr-cleanup.yml deploy-production.yml; do
    if [ -f "$ROOT_DIR/.github/workflows/$wf" ]; then
      rm "$ROOT_DIR/.github/workflows/$wf"
    fi
  done

  for script in pr-preview.sh pr-cleanup.sh production.sh; do
    if [ -f "$ROOT_DIR/scripts/deploy/$script" ]; then
      cat > "$ROOT_DIR/scripts/deploy/$script" <<'NONE_STUB_EOF'
#!/usr/bin/env bash
# No deploy provider configured.
# Run 'make init' again or configure manually — see docs/DEPLOY.md
echo "No deploy provider configured. See docs/DEPLOY.md for setup."
exit 0
NONE_STUB_EOF
      chmod +x "$ROOT_DIR/scripts/deploy/$script"
    fi
  done

  ok "Removed deploy workflows and cleared deploy scripts"
fi

# ── 12. Initialize stack package manager ─────────────
if [ -n "$PKG_INIT_CMD" ]; then
  echo ""
  if confirm "Initialize $STACK project scaffolding now?"; then
    # Many scaffold tools (create-next-app, cargo init, etc.) refuse to run
    # in a non-empty directory. Work around this by scaffolding into a temp
    # directory first, then merging generated files into the project root
    # without overwriting existing files.
    # Use the project name (lowercased, sanitized) as the temp dir name.
    # Tools like create-next-app derive the npm package name from the directory
    # name, and npm rejects uppercase letters.
    SAFE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]-' '-' | sed 's/^-//;s/-$//')
    SCAFFOLD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/${SAFE_NAME:-scaffold}-XXXXXX")
    # Rename the temp dir to use the clean project name (no random suffix)
    SCAFFOLD_NAMED="${SCAFFOLD_DIR%/*}/${SAFE_NAME}"
    if [ ! -d "$SCAFFOLD_NAMED" ]; then
      mv "$SCAFFOLD_DIR" "$SCAFFOLD_NAMED"
      SCAFFOLD_DIR="$SCAFFOLD_NAMED"
    fi
    info "Scaffolding into temp directory..."
    info "Running: $PKG_INIT_CMD"

    SCAFFOLD_EXIT=0
    (cd "$SCAFFOLD_DIR" && eval "$PKG_INIT_CMD") || SCAFFOLD_EXIT=$?

    if [ $SCAFFOLD_EXIT -eq 0 ]; then
      # Merge scaffolded files into project root (don't overwrite existing)
      MERGED=0
      SKIPPED=0
      while IFS= read -r -d '' file; do
        rel="${file#$SCAFFOLD_DIR/}"
        dest="$ROOT_DIR/$rel"
        if [ -d "$file" ] && [ ! -f "$file" ]; then
          continue  # directories are created as needed
        fi
        # Skip build artifacts and virtual environments
        case "$rel" in
          .venv/*|node_modules/*|__pycache__/*|target/*|.git/*|_build/*|deps/*) continue ;;
        esac
        mkdir -p "$(dirname "$dest")"
        if [ -f "$dest" ]; then
          SKIPPED=$((SKIPPED + 1))
        else
          cp "$file" "$dest"
          MERGED=$((MERGED + 1))
        fi
      done < <(find "$SCAFFOLD_DIR" -not -name '.' -print0)
      ok "Project scaffolded ($MERGED files added, $SKIPPED existing files kept)"

      # Copy lock files and config that SHOULD overwrite (dependency manifests)
      for f in package.json package-lock.json yarn.lock pnpm-lock.yaml \
               requirements.txt Pipfile.lock go.mod go.sum Cargo.toml Cargo.lock \
               Gemfile Gemfile.lock mix.exs mix.lock build.gradle build.gradle.kts \
               settings.gradle settings.gradle.kts gradlew gradlew.bat tsconfig.json; do
        if [ -f "$SCAFFOLD_DIR/$f" ]; then
          cp "$SCAFFOLD_DIR/$f" "$ROOT_DIR/$f"
        fi
      done

      # Copy gradle wrapper directory if present
      if [ -d "$SCAFFOLD_DIR/gradle" ]; then
        cp -r "$SCAFFOLD_DIR/gradle" "$ROOT_DIR/"
      fi

      # Merge knowledge files: if the scaffold generated docs that also exist
      # in the project (AGENTS.md, CLAUDE.md, README.md), append the scaffold's
      # content as a framework-specific section instead of discarding it.
      FRAMEWORK_LABEL="$STACK"
      [ "$IS_FULLSTACK" = true ] && FRAMEWORK_LABEL="$BACKEND_STACK + $FRONTEND_STACK"

      for doc in AGENTS.md CLAUDE.md README.md; do
        SCAFFOLD_DOC="$SCAFFOLD_DIR/$doc"
        PROJECT_DOC="$ROOT_DIR/$doc"
        if [ -f "$SCAFFOLD_DOC" ] && [ -f "$PROJECT_DOC" ]; then
          # Only append if the scaffold version has meaningful content
          SCAFFOLD_LINES=$(wc -l < "$SCAFFOLD_DOC" | tr -d ' ')
          if [ "$SCAFFOLD_LINES" -gt 2 ]; then
            {
              echo ""
              echo "---"
              echo ""
              echo "## ${FRAMEWORK_LABEL} — framework notes"
              echo ""
              echo "> Merged from scaffold-generated \`${doc}\`."
              echo ""
              cat "$SCAFFOLD_DOC"
            } >> "$PROJECT_DOC"
            ok "Merged scaffold ${doc} into project ${doc}"
          fi
        fi
      done
    else
      echo ""
      fail "Scaffolding failed (exit code $SCAFFOLD_EXIT). Check the output above."
      info "You can retry manually: cd $ROOT_DIR && $PKG_INIT_CMD"
    fi

    rm -rf "$SCAFFOLD_DIR"
  else
    info "Skipped. Run manually later:"
    info "  cd $(basename "$ROOT_DIR") && $PKG_INIT_CMD"
  fi
fi

# ── 13. Configure Symphony CI setup steps ────────────
if [ -n "$CI_SETUP_STEPS" ]; then
  SYMPHONY_FILE="$ROOT_DIR/.github/workflows/symphony.yml"
  if [ -f "$SYMPHONY_FILE" ]; then
    # Replace the TODO setup comment block with actual setup steps
    MARKER="      # TODO: Uncomment for your stack"
    if grep -q "$MARKER" "$SYMPHONY_FILE"; then
      # Use a temp file approach for multi-line replacement
      # (ENVIRON avoids awk -v breaking on embedded newlines)
      TEMP_FILE=$(mktemp)
      if CI_SETUP_STEPS_AWK="$CI_SETUP_STEPS" awk -v marker="$MARKER" '
        $0 ~ marker {
          print ENVIRON["CI_SETUP_STEPS_AWK"]
          # Skip the commented examples that follow
          while (getline > 0 && /^      # /) {}
          print
          next
        }
        { print }
      ' "$SYMPHONY_FILE" > "$TEMP_FILE" && [ -s "$TEMP_FILE" ]; then
        mv "$TEMP_FILE" "$SYMPHONY_FILE"
        ok "Configured Symphony CI setup steps"
      else
        rm -f "$TEMP_FILE"
        warn "Failed to update Symphony workflow CI steps — update .github/workflows/symphony.yml manually"
      fi
    fi
  fi
fi

# ── 14. Set up self-hosted runner ─────────────────────
if [ "$SETUP_RUNNER" = true ]; then
  echo ""
  # Runner needs a GitHub repo to register against
  if [ -n "$GITHUB_REPO" ] && gh repo view "$GITHUB_REPO" &>/dev/null; then
    if ! "$SCRIPT_DIR/runner/setup.sh"; then
      echo ""
      fail "Runner setup failed. See the output above for details."
      info "Retry later with: make setup-runner"
    fi
  else
    warn "Runner setup skipped — GitHub repository not accessible yet."
    info "Set up the runner after repo creation: make setup-runner"
  fi
fi

# ── 15. Update origin remote ──────────────────────────
# The origin may still point to the template repo after cloning.
# Update it to the project repo before committing and pushing.
if [ -n "$GITHUB_REPO" ]; then
  PROJECT_URL="https://github.com/${GITHUB_REPO}.git"
  CURRENT_URL=$(git remote get-url origin 2>/dev/null || true)

  if [ -n "$CURRENT_URL" ] && [ "$CURRENT_URL" != "$PROJECT_URL" ]; then
    info "Updating origin remote: $CURRENT_URL → $PROJECT_URL"
    git remote set-url origin "$PROJECT_URL"
    ok "Origin remote updated to ${GITHUB_REPO}"
  elif [ -z "$CURRENT_URL" ]; then
    git remote add origin "$PROJECT_URL"
    ok "Origin remote set to ${GITHUB_REPO}"
  fi
fi

# ── 16. Commit and push ───────────────────────────────
# Start fresh — squash all template history into a single initial commit
# so the new project doesn't carry the template repo's git log.
echo ""
info "Creating clean initial commit (squashing template history)..."
cd "$ROOT_DIR"

CURRENT_BRANCH=$(git branch --show-current)
git checkout --orphan _init_clean
git add -A

if git commit -m "Initialize project: ${PROJECT_NAME}

Stack: ${STACK}
Database: ${DB_ENGINE_CHOICE:-None}
Agent: ${AGENT_CHOICE}
Deploy: ${DEPLOY_PROVIDER}
Monitoring: ${MONITOR_CHOICE}"; then
  # Replace the current branch with the orphan (single commit)
  git branch -M "$CURRENT_BRANCH"
  ok "Created clean initial commit (template history removed)"
else
  # Fall back to the original branch if commit fails
  git checkout "$CURRENT_BRANCH" 2>/dev/null
  git branch -D _init_clean 2>/dev/null || true
  fail "Git commit failed — check the output above"
  info "You can commit manually: git add -A && git commit -m 'Initialize project'"
fi

if git remote get-url origin &>/dev/null; then
  info "Pushing to origin/${CURRENT_BRANCH}..."
  PUSH_EXIT=0
  PUSH_OUTPUT=$(git push --force -u origin "$CURRENT_BRANCH" 2>&1) || PUSH_EXIT=$?
  if [ $PUSH_EXIT -eq 0 ]; then
    ok "Pushed to origin/${CURRENT_BRANCH}"
  else
    fail "Push failed: $PUSH_OUTPUT"
    info "Push manually with: git push -u origin ${CURRENT_BRANCH}"
  fi
else
  warn "No remote 'origin' configured — skipping push"
  info "Add a remote and push manually: git remote add origin <url> && git push -u origin main"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "Done!"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo -e "${BOLD}$PROJECT_NAME${RESET} is configured."
echo ""
echo -e "  Stack:      ${CYAN}${STACK}${RESET}"
echo -e "  Database:   ${CYAN}${DB_ENGINE_CHOICE:-None}${RESET}"
[ -n "$DB_ORM" ] && [ "$DB_ORM" != "none" ] && echo -e "  ORM:        ${CYAN}${DB_ORM_CHOICE}${RESET}"
[ -n "$DB_HOSTING" ] && echo -e "  DB Hosting: ${CYAN}${DB_HOSTING}${RESET}"
echo -e "  Agent:      ${CYAN}${AGENT_CHOICE}${RESET}"
if [ -n "$DEPLOY_PROVIDER_KEY" ]; then
  echo -e "  Deploy:     ${CYAN}${DEPLOY_PROVIDER} (${DEPLOY_MODE} mode)${RESET}"
else
  echo -e "  Deploy:     ${CYAN}${DEPLOY_PROVIDER}${RESET}"
fi
echo -e "  Monitoring: ${CYAN}${MONITOR_CHOICE}${RESET}"
echo -e "  Runner:     ${CYAN}$([ "$SETUP_RUNNER" = true ] && echo "self-hosted (with fallback)" || echo "GitHub-hosted only")${RESET}"
[ -n "$GITHUB_REPO" ] && echo -e "  GitHub:     ${CYAN}${GITHUB_REPO}${RESET}"
echo ""

echo "Next steps:"
echo ""
[ -n "$SETUP_CMD" ] && echo "  1. Run:  make setup"
echo "  2. Run:  make check              (verify everything works)"
echo "  3. Read: docs/SETUP.md           (finish GitHub secrets/variables)"

if [ -n "$DEPLOY_PROVIDER_KEY" ]; then
  echo "  4. Read: docs/DEPLOY.md           (deploy reference)"
  if [ "$DEPLOY_MODE" = "native" ]; then
    echo "     → Native mode: ${DEPLOY_PROVIDER} handles deploys via Git integration"
  elif [ "$DEPLOY_MODE" = "scripts" ]; then
    echo "     → Scripts mode: GitHub Actions handle deploys via scripts/deploy/"
  elif [ "$DEPLOY_MODE" = "custom" ]; then
    echo "     → Custom mode: edit scripts/deploy/ with your deploy logic"
  fi
fi

if [ "${MONITOR_CHOICE:-}" != "None / I'll configure later" ] && [ -n "${MONITOR_CHOICE:-}" ]; then
  echo "  6. Run:  make monitor-test        (verify ${MONITOR_CHOICE} integration)"
fi

if [ -n "$DB_ORM" ] && [ "$DB_ORM" != "none" ]; then
  echo "  7. Run:  make db-migrate          (run initial database migration)"
  echo "  8. Read: db/README.md             (database setup and ORM guide)"
fi

echo ""
echo "  Then: create an issue, add labels 'ready' + 'agent', and watch Symphony work."
echo ""
