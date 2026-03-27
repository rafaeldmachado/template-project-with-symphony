#!/usr/bin/env bash
set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Self-hosted GitHub Actions runner setup
#
# Installs a runner for the current repo, registers it with
# GitHub, and starts it as a background service.
#
# Supported platforms:
#   macOS  — LaunchAgent (user context, starts on login)
#   Linux  — systemd user service
#   Windows (Git Bash / WSL) — Windows Service via PowerShell
#
# Network: The runner polls GitHub over HTTPS (outbound port 443).
#   No inbound ports, SSH, or firewall rules needed.
#   Works behind NAT, corporate firewalls, and VPNs.
#
# Usage: make setup-runner
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Colors ────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

ok()   { echo -e "${GREEN}✓${RESET} $1"; }
warn() { echo -e "${YELLOW}!${RESET} $1"; }
fail() { echo -e "${RED}✗${RESET} $1"; exit 1; }
info() { echo -e "${DIM}$1${RESET}"; }

# ── Prerequisites ─────────────────────────────────────
if ! command -v gh &>/dev/null; then
  fail "gh CLI is required. Install from: https://cli.github.com"
fi

if ! gh auth status &>/dev/null; then
  fail "gh is not authenticated. Run: gh auth login"
fi

# ── Network connectivity check ────────────────────────
# Only test hosts that respond to HTTP probes. The runner also needs
# *.actions.githubusercontent.com and *.blob.core.windows.net, but those
# use WebSocket/long-poll and don't respond to plain HTTPS GET/HEAD.
info "Checking network connectivity..."

NET_OK=true
for host in "github.com" "api.github.com"; do
  if curl -sf --max-time 5 "https://${host}" -o /dev/null 2>/dev/null || \
     curl -sf --max-time 5 -I "https://${host}" -o /dev/null 2>/dev/null; then
    ok "  $host — reachable"
  else
    warn "  $host — not reachable"
    NET_OK=false
  fi
done

# DNS-only check for hosts that don't respond to HTTP
for host in "pipelines.actions.githubusercontent.com"; do
  if host "$host" &>/dev/null || nslookup "$host" &>/dev/null 2>&1; then
    ok "  $host — resolves"
  else
    warn "  $host — DNS lookup failed"
    NET_OK=false
  fi
done

if [ "$NET_OK" = false ]; then
  echo ""
  warn "Some GitHub hosts are not reachable."
  info "The runner requires outbound HTTPS (port 443) to:"
  info "  - github.com"
  info "  - api.github.com"
  info "  - *.actions.githubusercontent.com"
  info "  - *.blob.core.windows.net (for caching)"
  echo ""
  info "No inbound ports, SSH, or firewall rules are needed."
  info "If you're behind a corporate proxy, set HTTPS_PROXY."
  echo ""
  echo -en "${BOLD}Continue anyway? [y/N]${RESET}: "
  read -r answer
  if [[ ! "${answer:-n}" =~ ^[Yy] ]]; then
    exit 1
  fi
else
  ok "Network connectivity OK (outbound HTTPS only — no inbound ports needed)"
fi

# ── Detect repo ───────────────────────────────────────
# Prefer GITHUB_REPO from .env (set by make init) over git remote,
# since the remote may still point to the template repo after cloning.
GITHUB_REPO=""
if [ -f "$ROOT_DIR/.env" ]; then
  GITHUB_REPO=$(grep -E '^GITHUB_REPO=' "$ROOT_DIR/.env" 2>/dev/null | cut -d'=' -f2- | tr -d '[:space:]' || true)
fi
if [ -z "$GITHUB_REPO" ]; then
  GITHUB_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)
fi
if [ -z "$GITHUB_REPO" ]; then
  fail "Could not detect GitHub repository. Run 'make init' first or set GITHUB_REPO in .env."
fi

echo ""
echo -e "${BOLD}Setting up self-hosted runner for ${CYAN}${GITHUB_REPO}${RESET}"
echo ""

# ── Determine platform and architecture ───────────────
RAW_OS=$(uname -s)
ARCH=$(uname -m)

case "$RAW_OS" in
  Darwin)          OS="darwin";  RUNNER_OS="osx"     ;;
  Linux)           OS="linux";   RUNNER_OS="linux"   ;;
  MINGW*|MSYS*|CYGWIN*)
    OS="windows"; RUNNER_OS="win" ;;
  *)
    # WSL reports "Linux" but check for Windows interop
    if grep -qi microsoft /proc/version 2>/dev/null; then
      OS="windows"; RUNNER_OS="win"
    else
      fail "Unsupported OS: $RAW_OS"
    fi
    ;;
esac

case "$ARCH" in
  x86_64|amd64)  RUNNER_ARCH="x64"   ;;
  arm64|aarch64) RUNNER_ARCH="arm64" ;;
  *)             fail "Unsupported architecture: $ARCH" ;;
esac

info "Platform: ${RUNNER_OS}-${RUNNER_ARCH}"

# ── Runner directory ──────────────────────────────────
REPO_SLUG="$(echo "$GITHUB_REPO" | tr '/' '-')"

if [ "$OS" = "windows" ]; then
  # Use a Windows-native path for the service
  WIN_HOME="${USERPROFILE:-$HOME}"
  RUNNER_DIR="${WIN_HOME}/.github-runner/${REPO_SLUG}"
else
  RUNNER_DIR="$HOME/.github-runner/${REPO_SLUG}"
fi

# ── Check for existing runner ─────────────────────────
if [ -d "$RUNNER_DIR" ]; then
  RUNNER_CONFIGURED=false

  if [ -f "$RUNNER_DIR/.runner" ]; then
    RUNNER_CONFIGURED=true
    RUNNER_NAME=$(grep -o '"agentName":"[^"]*"' "$RUNNER_DIR/.runner" 2>/dev/null | cut -d'"' -f4 || echo "unknown")
    SVC_ID="actions.runner.${REPO_SLUG}.${RUNNER_NAME}"

    # Check if service is running per platform
    RUNNING=false
    case "$OS" in
      darwin)
        launchctl list 2>/dev/null | grep -q "$SVC_ID" && RUNNING=true
        ;;
      linux)
        systemctl --user is-active "${SVC_ID}.service" &>/dev/null && RUNNING=true
        ;;
      windows)
        if command -v powershell.exe &>/dev/null; then
          STATUS=$(powershell.exe -Command "Get-Service -Name '${SVC_ID}' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Status" 2>/dev/null || echo "")
          [ "$STATUS" = "Running" ] && RUNNING=true
        fi
        ;;
    esac

    if [ "$RUNNING" = true ]; then
      ok "Runner '${RUNNER_NAME}' is already installed and running at: $RUNNER_DIR"
      info "To reconfigure, first run: make runner-stop && make runner-remove"
      exit 0
    fi
  fi

  if [ "$RUNNER_CONFIGURED" = true ]; then
    warn "Runner directory exists at $RUNNER_DIR but service is not running."
    echo -en "${BOLD}Reconfigure and restart? [Y/n]${RESET}: "
    read -r answer
    if [[ "${answer:-y}" =~ ^[Nn] ]]; then
      exit 0
    fi
    # Unconfigure before reconfiguring
    REG_TOKEN=$(gh api "repos/${GITHUB_REPO}/actions/runners/registration-token" --jq '.token' 2>/dev/null || true)
    if [ -n "$REG_TOKEN" ]; then
      if [ "$OS" = "windows" ]; then
        (cd "$RUNNER_DIR" && cmd.exe /c "config.cmd remove --token $REG_TOKEN") 2>/dev/null || true
      else
        (cd "$RUNNER_DIR" && ./config.sh remove --token "$REG_TOKEN") 2>/dev/null || true
      fi
    fi
  fi
fi

# ── Get latest runner version ─────────────────────────
info "Fetching latest runner release..."
RUNNER_VERSION=$(gh api repos/actions/runner/releases/latest --jq '.tag_name' | sed 's/^v//')

if [ "$OS" = "windows" ]; then
  RUNNER_ARCHIVE="actions-runner-${RUNNER_OS}-${RUNNER_ARCH}-${RUNNER_VERSION}.zip"
else
  RUNNER_ARCHIVE="actions-runner-${RUNNER_OS}-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
fi

RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_ARCHIVE}"
ok "Runner version: ${RUNNER_VERSION}"

# ── Download and extract ──────────────────────────────
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

# Check if already extracted (presence of config script)
NEEDS_DOWNLOAD=true
if [ "$OS" = "windows" ] && [ -f "config.cmd" ]; then
  NEEDS_DOWNLOAD=false
elif [ "$OS" != "windows" ] && [ -f "config.sh" ]; then
  NEEDS_DOWNLOAD=false
fi

if [ "$NEEDS_DOWNLOAD" = true ]; then
  info "Downloading runner..."
  curl -sL "$RUNNER_URL" -o "$RUNNER_ARCHIVE"

  if [ "$OS" = "windows" ]; then
    if command -v unzip &>/dev/null; then
      unzip -oq "$RUNNER_ARCHIVE"
    elif command -v powershell.exe &>/dev/null; then
      powershell.exe -Command "Expand-Archive -Path '$RUNNER_ARCHIVE' -DestinationPath '.' -Force"
    else
      fail "Cannot extract .zip — install unzip or use PowerShell"
    fi
  else
    tar xzf "$RUNNER_ARCHIVE"
  fi

  rm -f "$RUNNER_ARCHIVE"
  ok "Runner extracted to $RUNNER_DIR"
else
  info "Runner binary already exists, skipping download"
fi

# ── Get registration token ───────────────────────────
info "Requesting registration token..."
REG_TOKEN=$(gh api "repos/${GITHUB_REPO}/actions/runners/registration-token" --jq '.token')

if [ -z "$REG_TOKEN" ]; then
  fail "Failed to get registration token. Ensure you have admin access to $GITHUB_REPO."
fi

ok "Registration token obtained"

# ── Configure runner ──────────────────────────────────
RUNNER_NAME="${HOSTNAME:-$(hostname)}"
RUNNER_LABELS="self-hosted,${RUNNER_OS},${RUNNER_ARCH}"

info "Configuring runner as '${RUNNER_NAME}' with labels: ${RUNNER_LABELS}"

if [ "$OS" = "windows" ]; then
  cmd.exe /c "config.cmd --url https://github.com/${GITHUB_REPO} --token ${REG_TOKEN} --name ${RUNNER_NAME} --labels ${RUNNER_LABELS} --work _work --replace --unattended"
else
  ./config.sh \
    --url "https://github.com/${GITHUB_REPO}" \
    --token "$REG_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --work "_work" \
    --replace \
    --unattended
fi

ok "Runner configured"

# ── Install and start service ─────────────────────────
echo ""

case "$OS" in
  darwin)
    info "Installing LaunchAgent (starts automatically on login)..."
    ./svc.sh install
    ./svc.sh start
    ok "Runner service started (macOS LaunchAgent)"
    echo ""
    info "Service location: ~/Library/LaunchAgents/actions.runner.*.plist"
    info "The runner starts automatically when you log in."
    ;;

  linux)
    info "Installing systemd user service..."
    ./svc.sh install
    ./svc.sh start
    ok "Runner service started (systemd user service)"
    echo ""
    info "To persist across reboots without login: loginctl enable-linger \$USER"
    ;;

  windows)
    info "Installing Windows Service (runs in background, starts on boot)..."
    if command -v powershell.exe &>/dev/null; then
      # Windows service installation requires admin — use PowerShell
      powershell.exe -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c cd \"$RUNNER_DIR\" && svc.cmd install && svc.cmd start' -Verb RunAs -Wait" 2>/dev/null || {
        warn "Automatic service install requires admin privileges."
        echo ""
        info "To install manually, open an admin terminal and run:"
        info "  cd $RUNNER_DIR"
        info "  .\\svc.cmd install"
        info "  .\\svc.cmd start"
        echo ""
        info "Alternatively, run the runner in the foreground:"
        info "  cd $RUNNER_DIR"
        info "  .\\run.cmd"
      }
    else
      warn "PowerShell not available — install the service manually."
      info "Open an admin terminal and run:"
      info "  cd $RUNNER_DIR"
      info "  .\\svc.cmd install"
      info "  .\\svc.cmd start"
    fi
    ok "Runner configured for Windows"
    ;;
esac

echo ""
info "Service management:"
info "  Start:   make runner-start"
info "  Stop:    make runner-stop"
info "  Status:  make runner-status"
info "  Remove:  make runner-remove"

echo ""
ok "Self-hosted runner is ready for ${GITHUB_REPO}"
echo ""
info "How it works:"
info "  - The runner polls GitHub over HTTPS (outbound only)"
info "  - No SSH, no open ports, no firewall rules needed"
info "  - When this machine is online, CI runs here (free)"
info "  - When offline, CI falls back to GitHub-hosted runners"
