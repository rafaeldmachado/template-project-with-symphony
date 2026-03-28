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

# ── resolve_stack: sets _LINTER, _FMT, _TEST, _E2E, _SETUP, _CI, _PKG
#    for a given framework name. Used for both single-stack and fullstack.
resolve_stack() {
  local fw="$1"
  local prefix="${2:-}"  # optional dir prefix for fullstack (e.g., "backend/")

  _LINTER="" _FMT="" _TEST="" _E2E="" _SETUP="" _CI="" _PKG=""

  case "$fw" in
    # ── JS/TS frameworks ─────────────────────────────
    "Next.js (React)")
      _LINTER='npx next lint && npx prettier --check .'
      _FMT='npx prettier --write .'
      _TEST='npx vitest run'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npx create-next-app@latest . --ts --eslint --tailwind --app --src-dir --import-alias "@/*" --use-npm && npm install -D vitest @vitejs/plugin-react playwright'
      ;;
    "SvelteKit")
      _LINTER='npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npx sv create . --template minimal --types ts --no-add-ons && npm install -D vitest playwright eslint prettier'
      ;;
    "Nuxt (Vue)")
      _LINTER='npx nuxi typecheck && npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npx nuxi@latest init . --force && npm install -D vitest @nuxt/test-utils playwright eslint prettier'
      ;;
    "Astro")
      _LINTER='npx astro check && npx prettier --check .'
      _FMT='npx prettier --write .'
      _TEST='npx vitest run'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npm create astro@latest -- . --template minimal --typescript strict --install --no-git && npm install -D vitest playwright prettier'
      ;;
    "Remix")
      _LINTER='npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npx create-remix@latest . --yes && npm install -D vitest playwright prettier'
      ;;
    "Hono (API)")
      _LINTER='npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run'
      _E2E='npx vitest run tests/e2e'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npm create hono@latest . -- --template nodejs && npm install -D typescript eslint prettier vitest @types/node'
      ;;
    "Express (TypeScript)")
      _LINTER='npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run'
      _E2E='npx vitest run tests/e2e'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npm init -y && npm install express && npm install -D typescript @types/express @types/node eslint prettier vitest tsx && npx tsc --init'
      ;;
    "Node.js (TypeScript, no framework)")
      _LINTER='npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npm init -y && npm install -D typescript eslint prettier vitest @types/node && npx tsc --init'
      ;;
    "Node.js (JavaScript, no framework)")
      _LINTER='npx eslint . --max-warnings 0 && npx prettier --check .'
      _FMT='npx prettier --write . && npx eslint . --fix'
      _TEST='npx vitest run'
      _E2E='npx playwright test'
      _SETUP='if [ -f package-lock.json ]; then npm ci; elif [ -f package.json ]; then npm install; fi'
      _CI="$NODE_CI_STEPS"
      _PKG='npm init -y && npm install -D eslint prettier vitest'
      ;;

    # ── Python frameworks ────────────────────────────
    "FastAPI")
      _LINTER='ruff check . && ruff format --check .'
      _FMT='ruff format . && ruff check . --fix'
      _TEST='pytest tests/ --ignore=tests/e2e'
      _E2E='pytest tests/e2e/'
      _SETUP='python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt'
      _CI="$PYTHON_CI_STEPS"
      _PKG='python -m venv .venv && source .venv/bin/activate && pip install fastapi uvicorn ruff pytest httpx && pip freeze > requirements.txt'
      ;;
    "Django")
      _LINTER='ruff check . && ruff format --check .'
      _FMT='ruff format . && ruff check . --fix'
      _TEST='python manage.py test'
      _E2E='pytest tests/e2e/'
      _SETUP='python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt'
      _CI="$PYTHON_CI_STEPS"
      _PKG='python -m venv .venv && source .venv/bin/activate && pip install django ruff pytest && django-admin startproject config . && pip freeze > requirements.txt'
      ;;
    "Flask")
      _LINTER='ruff check . && ruff format --check .'
      _FMT='ruff format . && ruff check . --fix'
      _TEST='pytest tests/ --ignore=tests/e2e'
      _E2E='pytest tests/e2e/'
      _SETUP='python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt'
      _CI="$PYTHON_CI_STEPS"
      _PKG='python -m venv .venv && source .venv/bin/activate && pip install flask ruff pytest && pip freeze > requirements.txt'
      ;;
    "Python (no framework)")
      _LINTER='ruff check . && ruff format --check .'
      _FMT='ruff format . && ruff check . --fix'
      _TEST='pytest tests/ --ignore=tests/e2e'
      _E2E='pytest tests/e2e/'
      _SETUP='python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt'
      _CI="$PYTHON_CI_STEPS"
      _PKG='python -m venv .venv && source .venv/bin/activate && pip install ruff pytest && pip freeze > requirements.txt'
      ;;

    # ── Go ───────────────────────────────────────────
    "Go")
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
      _LINTER='cargo clippy -- -D warnings && cargo fmt -- --check'
      _FMT='cargo fmt'
      _TEST='cargo test'
      _E2E='cargo test --test e2e'
      _SETUP='cargo fetch'
      _CI="$RUST_CI_STEPS"
      _PKG='cargo init --name '"$PROJECT_NAME"' && cargo add axum tokio --features tokio/full && cargo add -D tower-http'
      ;;
    "Rust (no framework)")
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
      _LINTER='mix format --check-formatted && mix credo --strict'
      _FMT='mix format'
      _TEST='mix test'
      _E2E='mix test tests/e2e/'
      _SETUP='mix deps.get && mix compile'
      _CI="$ELIXIR_CI_STEPS"
      _PKG='mix archive.install hex phx_new --force && mix phx.new . --app '"$PROJECT_NAME"' --no-install && mix deps.get'
      ;;
    "Elixir (no framework)")
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
      _LINTER='bundle exec rubocop'
      _FMT='bundle exec rubocop -A'
      _TEST='bundle exec rails test'
      _E2E='bundle exec rails test:system'
      _SETUP='bundle install'
      _CI="$RUBY_CI_STEPS"
      _PKG='gem install rails && rails new . --name='"$PROJECT_NAME"' --skip-git --force && bundle add rubocop --group=development'
      ;;
    "Ruby (no framework)")
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
      _LINTER='./gradlew ktlintCheck'
      _FMT='./gradlew ktlintFormat'
      _TEST='./gradlew test'
      _E2E='./gradlew e2eTest'
      _SETUP='./gradlew dependencies'
      _CI="$JAVA_CI_STEPS"
      _PKG='curl -s "https://start.spring.io/starter.tgz?type=gradle-project-kotlin&language=kotlin&bootVersion=3.4.1&groupId=com.example&artifactId='"$PROJECT_NAME"'&dependencies=web,actuator" | tar -xzf - && gradle wrapper'
      ;;
    "Spring Boot (Java)")
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
if [ "$IS_FULLSTACK" = true ]; then
  # Resolve backend
  resolve_stack "$BACKEND_STACK"
  BE_LINTER="$_LINTER"; BE_FMT="$_FMT"; BE_TEST="$_TEST"; BE_E2E="$_E2E"
  BE_SETUP="$_SETUP"; BE_CI="$_CI"; BE_PKG="$_PKG"

  # Resolve frontend
  resolve_stack "$FRONTEND_STACK"
  FE_LINTER="$_LINTER"; FE_FMT="$_FMT"; FE_TEST="$_TEST"; FE_E2E="$_E2E"
  FE_SETUP="$_SETUP"; FE_CI="$_CI"; FE_PKG="$_PKG"

  # Combine: run each tool in its subdirectory
  LINTER_CMD="(cd backend && ${BE_LINTER}) && (cd frontend && ${FE_LINTER})"
  FMT_CMD="(cd backend && ${BE_FMT}) && (cd frontend && ${FE_FMT})"
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
  LINTER_CMD="$_LINTER"; FMT_CMD="$_FMT"; TEST_CMD="$_TEST"; E2E_CMD="$_E2E"
  SETUP_CMD="$_SETUP"; CI_SETUP_STEPS="$_CI"; PKG_INIT_CMD="$_PKG"
else
  info "Skipping stack setup. Configure scripts/checks/ manually later."
fi

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

  # Update origin before creating so --source doesn't conflict with existing remote
  PROJECT_URL="https://github.com/${GITHUB_REPO}.git"
  if git remote get-url origin &>/dev/null; then
    git remote set-url origin "$PROJECT_URL"
  else
    git remote add origin "$PROJECT_URL"
  fi

  CREATE_EXIT=0
  CREATE_OUTPUT=$(gh repo create "$GITHUB_REPO" $VISIBILITY_FLAG --source "$ROOT_DIR" --remote origin 2>&1) || CREATE_EXIT=$?
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
        if grep -q '^  name: ' "$WORKFLOW_FILE" && grep -q '^  model: ' "$WORKFLOW_FILE"; then
          sed -i.bak 's/^  name: .*/  name: claude/' "$WORKFLOW_FILE"
          sed -i.bak 's/^  model: .*/  model: sonnet/' "$WORKFLOW_FILE"
          rm -f "${WORKFLOW_FILE}.bak"
          ok "Set agent to Claude Code in WORKFLOW.md"
        else
          warn "Could not find agent name/model fields in WORKFLOW.md — update manually"
        fi
        warn "Add ANTHROPIC_API_KEY to your GitHub repo secrets"
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
        warn "Add OPENAI_API_KEY to your GitHub repo secrets"
        ;;
    esac
  fi
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
echo ""
info "Committing configuration..."
cd "$ROOT_DIR"
git add -A

if git diff --cached --quiet; then
  info "No changes to commit"
else
  if git commit -m "Initialize project: ${PROJECT_NAME}

Stack: ${STACK}
Agent: ${AGENT_CHOICE}
Deploy: ${DEPLOY_PROVIDER}
Monitoring: ${MONITOR_CHOICE}"; then
    ok "Changes committed"
  else
    fail "Git commit failed — check the output above"
    info "You can commit manually: git add -A && git commit -m 'Initialize project'"
  fi
fi

if git remote get-url origin &>/dev/null; then
  CURRENT_BRANCH=$(git branch --show-current)
  info "Pushing to origin/${CURRENT_BRANCH}..."
  PUSH_EXIT=0
  PUSH_OUTPUT=$(git push -u origin "$CURRENT_BRANCH" 2>&1) || PUSH_EXIT=$?
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
