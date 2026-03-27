#!/usr/bin/env bash
set -euo pipefail

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
FMT_CMD=""
SETUP_CMD=""
CI_SETUP_STEPS=""
PKG_INIT_CMD=""
DEPLOY_PROVIDER=""
AGENT_CHOICE=""
MONITOR_CHOICE=""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BOLD}"
echo "  ┌─────────────────────────────────────┐"
echo "  │  Project Initialization Wizard      │"
echo "  │  AI-first development template      │"
echo "  └─────────────────────────────────────┘"
echo -e "${RESET}"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "1/7  Project basics"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PROJECT_NAME=$(ask "Project name" "$(basename "$ROOT_DIR")")
PROJECT_DESC=$(ask "One-line description" "")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "2/7  Stack"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STACK=$(choose "Choose your stack:" \
  "Node.js (TypeScript)" \
  "Node.js (JavaScript)" \
  "Python" \
  "Go" \
  "Rust" \
  "Elixir" \
  "None / I'll configure later")

case "$STACK" in
  "Node.js (TypeScript)")
    LINTER_CMD='npx eslint . --max-warnings 0 && npx prettier --check .'
    FMT_CMD='npx prettier --write . && npx eslint . --fix'
    TEST_CMD='npx vitest run'
    E2E_CMD='npx playwright test'
    SETUP_CMD='npm ci'
    CI_SETUP_STEPS='      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: "npm"
      - run: npm ci'
    PKG_INIT_CMD='npm init -y && npm install -D typescript eslint prettier vitest @types/node && npx tsc --init'
    ;;
  "Node.js (JavaScript)")
    LINTER_CMD='npx eslint . --max-warnings 0 && npx prettier --check .'
    FMT_CMD='npx prettier --write . && npx eslint . --fix'
    TEST_CMD='npx vitest run'
    E2E_CMD='npx playwright test'
    SETUP_CMD='npm ci'
    CI_SETUP_STEPS='      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: "npm"
      - run: npm ci'
    PKG_INIT_CMD='npm init -y && npm install -D eslint prettier vitest'
    ;;
  "Python")
    LINTER_CMD='ruff check . && ruff format --check .'
    FMT_CMD='ruff format . && ruff check . --fix'
    TEST_CMD='pytest tests/ --ignore=tests/e2e'
    E2E_CMD='pytest tests/e2e/'
    SETUP_CMD='python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt'
    CI_SETUP_STEPS='      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: "pip"
      - run: pip install -r requirements.txt'
    PKG_INIT_CMD='python -m venv .venv && source .venv/bin/activate && pip install ruff pytest && pip freeze > requirements.txt'
    ;;
  "Go")
    LINTER_CMD='golangci-lint run ./...'
    FMT_CMD='gofmt -w .'
    TEST_CMD='go test ./...'
    E2E_CMD='go test ./tests/e2e/...'
    SETUP_CMD='go mod download'
    CI_SETUP_STEPS='      - uses: actions/setup-go@v5
        with:
          go-version: "1.23"
      - run: go mod download'
    PKG_INIT_CMD="go mod init github.com/\$(git remote get-url origin 2>/dev/null | sed 's|.*github.com[:/]||;s|\.git$||' || echo \"$PROJECT_NAME\")"
    ;;
  "Rust")
    LINTER_CMD='cargo clippy -- -D warnings && cargo fmt -- --check'
    FMT_CMD='cargo fmt'
    TEST_CMD='cargo test'
    E2E_CMD='cargo test --test e2e'
    SETUP_CMD='cargo fetch'
    CI_SETUP_STEPS='      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt
      - run: cargo fetch'
    PKG_INIT_CMD='cargo init --name '"$PROJECT_NAME"
    ;;
  "Elixir")
    LINTER_CMD='mix format --check-formatted && mix credo --strict'
    FMT_CMD='mix format'
    TEST_CMD='mix test'
    E2E_CMD='mix test tests/e2e/'
    SETUP_CMD='mix deps.get && mix compile'
    CI_SETUP_STEPS='      - uses: erlef/setup-beam@v1
        with:
          otp-version: "27"
          elixir-version: "1.17"
      - run: mix deps.get'
    PKG_INIT_CMD='mix new . --app '"$PROJECT_NAME"
    ;;
  *)
    info "Skipping stack setup. Configure scripts/checks/ manually later."
    ;;
esac

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "3/7  GitHub"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SETUP_GITHUB=false
GITHUB_REPO=""
CREATE_LABELS=false

CREATE_REPO=false

if command -v gh &>/dev/null; then
  if confirm "Configure GitHub integration?"; then
    SETUP_GITHUB=true

    # Detect or ask for repo
    DETECTED_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)
    if [ -n "$DETECTED_REPO" ]; then
      GITHUB_REPO=$(ask "GitHub repository" "$DETECTED_REPO")
    else
      GITHUB_REPO=$(ask "GitHub repository (owner/name)" "")

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
    fi

    if [ -n "$GITHUB_REPO" ] && confirm "Create Symphony labels (ready, agent, in-progress, human-review)?"; then
      CREATE_LABELS=true
    fi
  fi
else
  warn "gh CLI not found. Skipping GitHub setup."
  info "Install from: https://cli.github.com"
  info "You can configure GitHub manually later — see docs/SETUP.md"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "4/7  Deploys"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DEPLOY_PROVIDER=$(choose "PR preview deploy provider:" \
  "Vercel" \
  "Netlify" \
  "Cloudflare Pages" \
  "Fly.io" \
  "None / I'll configure later")

DEPLOY_TOKEN=""
DEPLOY_PROJECT_ID=""

case "$DEPLOY_PROVIDER" in
  "Vercel")
    DEPLOY_PROVIDER_KEY="vercel"
    info "You can find your Vercel token at: https://vercel.com/account/tokens"
    DEPLOY_TOKEN=$(ask "Vercel token (leave empty to set later)" "")
    DEPLOY_PROJECT_ID=$(ask "Vercel project ID (leave empty to set later)" "")
    ;;
  "Netlify")
    DEPLOY_PROVIDER_KEY="netlify"
    info "You can find your Netlify token at: https://app.netlify.com/user/applications#personal-access-tokens"
    DEPLOY_TOKEN=$(ask "Netlify token (leave empty to set later)" "")
    DEPLOY_PROJECT_ID=$(ask "Netlify site ID (leave empty to set later)" "")
    ;;
  "Cloudflare Pages")
    DEPLOY_PROVIDER_KEY="cloudflare"
    info "You can find your Cloudflare API token at: https://dash.cloudflare.com/profile/api-tokens"
    DEPLOY_TOKEN=$(ask "Cloudflare API token (leave empty to set later)" "")
    DEPLOY_PROJECT_ID=$(ask "Cloudflare Pages project name (leave empty to set later)" "")
    ;;
  "Fly.io")
    DEPLOY_PROVIDER_KEY="fly"
    info "You can get a Fly.io token with: fly tokens create deploy"
    DEPLOY_TOKEN=$(ask "Fly.io deploy token (leave empty to set later)" "")
    DEPLOY_PROJECT_ID=$(ask "Fly.io app name (leave empty to set later)" "")
    ;;
  *)
    DEPLOY_PROVIDER_KEY=""
    ;;
esac

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "5/7  AI Agent (for Symphony)"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

info "Symphony dispatches AI agents to implement issues autonomously."
info "Choose which agent to use in the Symphony workflow."

AGENT_CHOICE=$(choose "AI agent for autonomous work:" \
  "Claude Code (Anthropic)" \
  "Codex (OpenAI)" \
  "None / I'll configure later")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "6/7  Monitoring"
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "7/7  Self-hosted runner"
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
  if gh repo create "$GITHUB_REPO" $VISIBILITY_FLAG --source "$ROOT_DIR" --remote origin; then
    ok "Created repository: $GITHUB_REPO ($REPO_VISIBILITY)"
  else
    warn "Failed to create repository — you can create it manually later"
    warn "  gh repo create $GITHUB_REPO $VISIBILITY_FLAG --source . --remote origin"
  fi
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

# ── 5. Write .env ────────────────────────────────────
AGENT_KEY_NAME=""
AGENT_KEY_VALUE=""
case "$AGENT_CHOICE" in
  "Claude Code (Anthropic)")
    AGENT_KEY_NAME="ANTHROPIC_API_KEY"
    info "You can find your API key at: https://console.anthropic.com/settings/keys"
    AGENT_KEY_VALUE=$(ask "Anthropic API key (leave empty to set later)" "")
    ;;
  "Codex (OpenAI)")
    AGENT_KEY_NAME="OPENAI_API_KEY"
    info "You can find your API key at: https://platform.openai.com/api-keys"
    AGENT_KEY_VALUE=$(ask "OpenAI API key (leave empty to set later)" "")
    ;;
esac

cat > "$ROOT_DIR/.env" <<ENV_EOF
# Generated by init wizard on $(date +%Y-%m-%d)

GITHUB_REPO=${GITHUB_REPO}
GITHUB_PROJECT_NUMBER=
PROJECT_TOKEN=
DEPLOY_PROVIDER=${DEPLOY_PROVIDER_KEY}
DEPLOY_TOKEN=${DEPLOY_TOKEN}
DEPLOY_PROJECT_ID=${DEPLOY_PROJECT_ID}
MONITOR_DSN=${MONITOR_DSN}
MONITOR_ENV=development
$([ -n "$AGENT_KEY_NAME" ] && echo "${AGENT_KEY_NAME}=${AGENT_KEY_VALUE}")
ENV_EOF
ok "Created .env"

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
  find "$ROOT_DIR/scripts" -name "*.sh" -exec shellcheck -S warning {} + 2>&1 || true
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

echo "Running tests..."

if [ "\$E2E" = true ]; then
  echo "  Running e2e tests..."
  ${E2E_CMD}
else
  echo "  Running unit + integration tests..."
  ${TEST_CMD}
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

if [ ! -f "\$ROOT_DIR/.env" ] && [ -f "\$ROOT_DIR/.env.example" ]; then
  cp "\$ROOT_DIR/.env.example" "\$ROOT_DIR/.env"
  echo "Created .env from .env.example"
fi

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
        sed -i.bak 's/^  name: .*/  name: claude/' "$WORKFLOW_FILE"
        sed -i.bak 's/^  model: .*/  model: sonnet/' "$WORKFLOW_FILE"
        rm -f "${WORKFLOW_FILE}.bak"
        ok "Set agent to Claude Code in WORKFLOW.md"
        warn "Add ANTHROPIC_API_KEY to your GitHub repo secrets"
        ;;
      "Codex (OpenAI)")
        sed -i.bak 's/^  name: .*/  name: codex/' "$WORKFLOW_FILE"
        sed -i.bak 's/^  model: .*/  model: o3/' "$WORKFLOW_FILE"
        rm -f "${WORKFLOW_FILE}.bak"
        ok "Set agent to Codex in WORKFLOW.md"
        warn "Add OPENAI_API_KEY to your GitHub repo secrets"
        ;;
    esac
  fi
fi

# ── 11. Create GitHub labels ────────────────────────
if [ "$CREATE_LABELS" = true ] && [ -n "$GITHUB_REPO" ]; then
  echo ""
  info "Creating labels on $GITHUB_REPO..."

  gh label create "ready"         --repo "$GITHUB_REPO" --color "0E8A16" --description "Issue is ready for agent work"   2>/dev/null && ok "Label: ready"         || info "Label 'ready' already exists"
  gh label create "agent"         --repo "$GITHUB_REPO" --color "5319E7" --description "Handle with AI agent"            2>/dev/null && ok "Label: agent"         || info "Label 'agent' already exists"
  gh label create "in-progress"   --repo "$GITHUB_REPO" --color "FBCA04" --description "Agent is working on this"        2>/dev/null && ok "Label: in-progress"   || info "Label 'in-progress' already exists"
  gh label create "human-review"  --repo "$GITHUB_REPO" --color "0075CA" --description "PR ready for human review"       2>/dev/null && ok "Label: human-review"  || info "Label 'human-review' already exists"
  gh label create "p0"            --repo "$GITHUB_REPO" --color "B60205" --description "Critical priority"               2>/dev/null && ok "Label: p0"            || info "Label 'p0' already exists"
  gh label create "p1"            --repo "$GITHUB_REPO" --color "D93F0B" --description "High priority"                   2>/dev/null && ok "Label: p1"            || info "Label 'p1' already exists"
  gh label create "p2"            --repo "$GITHUB_REPO" --color "FBCA04" --description "Normal priority"                 2>/dev/null && ok "Label: p2"            || info "Label 'p2' already exists"
  gh label create "story"         --repo "$GITHUB_REPO" --color "C5DEF5" --description "User story"                      2>/dev/null && ok "Label: story"         || info "Label 'story' already exists"
fi

# ── 12. Initialize stack package manager ─────────────
if [ -n "$PKG_INIT_CMD" ]; then
  echo ""
  if confirm "Initialize $STACK project scaffolding now?"; then
    info "Running: $PKG_INIT_CMD"
    cd "$ROOT_DIR"
    eval "$PKG_INIT_CMD" && ok "Project scaffolded" || warn "Scaffolding had issues — check output above"
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
      CI_SETUP_STEPS_AWK="$CI_SETUP_STEPS" awk -v marker="$MARKER" '
        $0 ~ marker {
          print ENVIRON["CI_SETUP_STEPS_AWK"]
          # Skip the commented examples that follow
          while (getline > 0 && /^      # /) {}
          print
          next
        }
        { print }
      ' "$SYMPHONY_FILE" > "$TEMP_FILE"
      mv "$TEMP_FILE" "$SYMPHONY_FILE"
      ok "Configured Symphony CI setup steps"
    fi
  fi
fi

# ── 14. Set up self-hosted runner ─────────────────────
if [ "$SETUP_RUNNER" = true ]; then
  echo ""
  "$SCRIPT_DIR/runner/setup.sh" || warn "Runner setup had issues — you can retry with: make setup-runner"
fi

# ── 15. Commit and push ───────────────────────────────
echo ""
info "Committing configuration..."
cd "$ROOT_DIR"
git add -A
git commit -m "Initialize project: ${PROJECT_NAME}

Stack: ${STACK}
Agent: ${AGENT_CHOICE}
Deploy: ${DEPLOY_PROVIDER}
Monitoring: ${MONITOR_CHOICE}"
ok "Changes committed"

if git remote get-url origin &>/dev/null; then
  CURRENT_BRANCH=$(git branch --show-current)
  info "Pushing to origin/${CURRENT_BRANCH}..."
  if git push origin "$CURRENT_BRANCH"; then
    ok "Pushed to origin/${CURRENT_BRANCH}"
  else
    warn "Push failed — you can push manually with: git push origin ${CURRENT_BRANCH}"
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
echo -e "  Agent:      ${CYAN}${AGENT_CHOICE}${RESET}"
echo -e "  Deploy:     ${CYAN}${DEPLOY_PROVIDER}${RESET}"
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
  echo "  4. Read: docs/DEPLOY.md           (configure $DEPLOY_PROVIDER deploys)"
  echo "  5. Edit: scripts/deploy/pr-preview.sh  (uncomment $DEPLOY_PROVIDER_KEY block)"
fi

echo ""
echo "  Then: create an issue, add labels 'ready' + 'agent', and watch Symphony work."
echo ""
