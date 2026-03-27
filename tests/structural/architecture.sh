#!/usr/bin/env bash
set -euo pipefail

# Structural test: validate architecture invariants.
#
# This test enforces the dependency layering rule:
#   Types → Config → Core → Services → Runtime → UI
#
# Each layer can only depend on layers to its left. Cross-cutting
# concerns enter through Providers only.
#
# Adapt the patterns below to match your project's file structure.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILED=0

echo "Validating architecture invariants..."

# ── Required files must exist ────────────────────────
REQUIRED=(
  "AGENTS.md"
  "CLAUDE.md"
  "Makefile"
  "docs/DESIGN.md"
  "docs/architecture/layers.md"
)

for file in "${REQUIRED[@]}"; do
  if [ ! -f "$ROOT_DIR/$file" ]; then
    echo "ERROR: [structure] Required file missing: $file"
    echo "  Remediation: Create this file. See AGENTS.md for the knowledge base layout."
    FAILED=1
  fi
done

# ── File size limits ─────────────────────────────────
MAX_LINES=500
while IFS= read -r file; do
  lines=$(wc -l < "$file")
  if [ "$lines" -gt "$MAX_LINES" ]; then
    relpath="${file#"$ROOT_DIR"/}"
    echo "ERROR: [structure] File too large: $relpath ($lines lines, max $MAX_LINES)"
    echo "  Remediation: Split into smaller, focused files. One concern per file."
    FAILED=1
  fi
done < <(find "$ROOT_DIR/src" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.rs" \) 2>/dev/null || true)

# ── No secrets in tracked files ──────────────────────
SECRETS_PATTERN='(PRIVATE_KEY|SECRET_KEY|API_KEY|PASSWORD|TOKEN)\s*=\s*["\x27][^"\x27]+'
while IFS= read -r match; do
  [ -z "$match" ] && continue
  echo "ERROR: [structure] Possible secret in tracked file: $match"
  echo "  Remediation: Move secrets to .env (which is gitignored). Use env vars."
  FAILED=1
done < <(git grep -rn -E "$SECRETS_PATTERN" -- ':!.env*' ':!*.example' ':!scripts/' ':!tests/' 2>/dev/null || true)

# ── TODO: Add dependency layer validation ────────────
# When your project has a src/ directory with layers, uncomment and adapt:
#
# LAYERS=("types" "config" "core" "services" "runtime" "ui")
# for i in "${!LAYERS[@]}"; do
#   layer="${LAYERS[$i]}"
#   layer_dir="$ROOT_DIR/src/$layer"
#   [ -d "$layer_dir" ] || continue
#
#   # Check that this layer doesn't import from higher layers
#   for j in $(seq $((i + 1)) $((${#LAYERS[@]} - 1))); do
#     higher="${LAYERS[$j]}"
#     violations=$(grep -rn "from.*['\"].*/$higher/" "$layer_dir" 2>/dev/null || true)
#     if [ -n "$violations" ]; then
#       echo "ERROR: [structure] Layer '$layer' imports from '$higher' (forbidden)"
#       echo "$violations" | head -5
#       echo "  Remediation: '$layer' can only import from layers to its left in:"
#       echo "    Types → Config → Core → Services → Runtime → UI"
#       FAILED=1
#     fi
#   done
# done

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi

echo "Architecture invariants passed."
