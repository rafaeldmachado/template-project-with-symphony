#!/usr/bin/env bash
set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Self-hosted runner management (start / stop / status / remove)
#
# Supports macOS (LaunchAgent), Linux (systemd), Windows (service)
#
# Usage: ./manage.sh <start|stop|status|remove>
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ACTION="${1:-status}"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

ok()   { echo -e "${GREEN}✓${RESET} $1"; }
warn() { echo -e "${YELLOW}!${RESET} $1"; }
fail() { echo -e "${RED}✗${RESET} $1"; exit 1; }
info() { echo -e "${DIM}$1${RESET}"; }

# ── Detect platform ──────────────────────────────────
RAW_OS=$(uname -s)
case "$RAW_OS" in
  Darwin)              OS="darwin"  ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      OS="windows"
    else
      OS="linux"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
  *)                     OS="linux"   ;;
esac

# ── Find runner directory ─────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

GITHUB_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)
if [ -z "$GITHUB_REPO" ]; then
  fail "Could not detect GitHub repository. Run 'make init' first or add a git remote."
fi

REPO_SLUG="$(echo "$GITHUB_REPO" | tr '/' '-')"

if [ "$OS" = "windows" ]; then
  WIN_HOME="${USERPROFILE:-$HOME}"
  RUNNER_DIR="${WIN_HOME}/.github-runner/${REPO_SLUG}"
else
  RUNNER_DIR="$HOME/.github-runner/${REPO_SLUG}"
fi

if [ ! -d "$RUNNER_DIR" ]; then
  fail "No runner installed at $RUNNER_DIR. Run: make setup-runner"
fi

# Verify the service script exists
if [ "$OS" = "windows" ]; then
  [ -f "$RUNNER_DIR/svc.cmd" ] || fail "Runner service script not found. Run: make setup-runner"
else
  [ -f "$RUNNER_DIR/svc.sh" ] || fail "Runner service script not found. Run: make setup-runner"
fi

cd "$RUNNER_DIR"

# ── Helper: run service command per platform ──────────
svc_cmd() {
  local cmd="$1"
  if [ "$OS" = "windows" ]; then
    if command -v powershell.exe &>/dev/null; then
      powershell.exe -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c cd \"$RUNNER_DIR\" && svc.cmd $cmd' -Verb RunAs -Wait" 2>/dev/null || \
        cmd.exe /c "svc.cmd $cmd"
    else
      cmd.exe /c "svc.cmd $cmd"
    fi
  else
    ./svc.sh "$cmd"
  fi
}

# ── Execute action ────────────────────────────────────
case "$ACTION" in
  start)
    svc_cmd start
    ok "Runner started"
    ;;

  stop)
    svc_cmd stop
    ok "Runner stopped"
    ;;

  status)
    svc_cmd status || true
    echo ""
    info "Checking GitHub runner status..."
    RUNNERS=$(gh api "repos/${GITHUB_REPO}/actions/runners" \
      --jq '.runners[] | "\(.name)\t\(.status)\t\(.busy)"' 2>/dev/null || echo "")
    if [ -n "$RUNNERS" ]; then
      printf "%-30s %-10s %s\n" "NAME" "STATUS" "BUSY"
      echo "$RUNNERS" | while IFS=$'\t' read -r name status busy; do
        printf "%-30s %-10s %s\n" "$name" "$status" "$busy"
      done
    else
      warn "No runners found via API (or insufficient permissions)"
    fi
    ;;

  remove)
    echo -en "Remove runner and unregister from GitHub? [y/N]: "
    read -r answer
    if [[ "$answer" =~ ^[Yy] ]]; then
      svc_cmd stop 2>/dev/null || true
      svc_cmd uninstall 2>/dev/null || true

      REG_TOKEN=$(gh api "repos/${GITHUB_REPO}/actions/runners/registration-token" --method POST --jq '.token' 2>/dev/null || true)
      if [ -n "$REG_TOKEN" ]; then
        if [ "$OS" = "windows" ]; then
          cmd.exe /c "config.cmd remove --token $REG_TOKEN" 2>/dev/null || true
        else
          ./config.sh remove --token "$REG_TOKEN" 2>/dev/null || true
        fi
      fi

      rm -rf "$RUNNER_DIR"
      ok "Runner removed and unregistered"
    else
      info "Cancelled"
    fi
    ;;

  *)
    echo "Usage: $0 <start|stop|status|remove>"
    exit 1
    ;;
esac
